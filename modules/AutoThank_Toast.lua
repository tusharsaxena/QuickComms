local _, NS = ...
-- modules/AutoThank_Toast.lua — auto-thank's toast host (#19, spec §9 The toast): a candidate from
-- modules/AutoThank.lua (AT.Offer) becomes a "buffed you" toast in LibKa0s-Toast-1.0 (the seam,
-- core/ToastSetup.lua), paced and stacked.
--
-- The throttle: a cooldown per caster and spell (AT.Stamp, at the offer), at least C.THANK.GAP
-- between two Show calls through the host's own pump, at most C.THANK.STACK on screen and the
-- library's maxQueue dropping the oldest waiting toast. The toast's frame will carry the Thank
-- button, a secure child (CA-M4-12), so no toast may be on screen in combat: every host Show and
-- every step of the pump is gated on lockdown, and a payload offered in combat waits in the host's
-- own list; the toast itself is held through combat and released after it. The strata is the
-- library's HIGH (core/Constants.lua C.LAYERS); none is set here.

NS.AutoThankToast = NS.AutoThankToast or {}
local TH = NS.AutoThankToast
local AT = NS.AutoThank
local L = NS.L
local C = NS.Constants

-- The payloads waiting for the pump, oldest first: what the library has not been handed yet.
TH.pending = TH.pending or {}
-- The pump's armed timer handle, or nil.
TH.pumpTimer = nil
local lastShowAt

-- The host's own list holds no more than the library could take from it.
local PENDING_CAP = C.THANK.STACK + C.THANK.MAX_QUEUE

local function thankSettings()
    local db = NS.db
    return db and db.profile and db.profile.thank
end

-- ── the builder ─────────────────────────────────────────────────────────────────────────────────

local ICON = 32
local INSET = 12

-- The icon and the line, made once per pool frame and re-used on every draw.
local function regions(frame)
    if frame.qcText then return end
    frame.qcIcon = frame:CreateTexture(nil, "ARTWORK")
    frame.qcIcon:SetSize(ICON, ICON)
    frame.qcIcon:SetPoint("LEFT", frame, "LEFT", INSET, 0)
    frame.qcText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.qcText:SetPoint("LEFT", frame.qcIcon, "RIGHT", INSET / 2, 0)
    frame.qcText:SetPoint("RIGHT", frame, "RIGHT", -INSET * 2, 0)
    frame.qcText:SetJustifyH("LEFT")
end

-- ── the fade (D26) ──────────────────────────────────────────────────────────────────────────────
-- The library has no fade, so an unclicked toast fades here over its last C.THANK.FADE seconds and
-- the library's own timer hides it at the same moment. The pointer holds it as the library's hover
-- pause does (the button sits inside the frame, so IsMouseOver covers it), pushing the due time by
-- what it held; leaving with under a second left gives one second, the library's MIN_RESUME.
-- OnUpdate runs only while the frame is shown, and does nothing in combat.

local MIN_LEFT = 1

local function fade(frame, elapsed)
    if NS.Compat.InCombat() or not frame.qcDue then return end
    local now = GetTime()
    if frame:IsMouseOver() then
        frame.qcDue = frame.qcDue + (elapsed or 0)
        frame.qcHovered = true
        frame:SetAlpha(1)
        return
    end
    if frame.qcHovered then
        frame.qcHovered = nil
        if frame.qcDue - now < MIN_LEFT then frame.qcDue = now + MIN_LEFT end
    end
    frame:SetAlpha(math.max(0, math.min(1, (frame.qcDue - now) / C.THANK.FADE)))
end

-- Hooked once per pool frame, on its first draw; every draw starts the fade's clock again.
local function startFade(frame)
    if not frame.qcFadeHooked then
        frame.qcFadeHooked = true
        frame:HookScript("OnUpdate", fade)
    end
    frame.qcDue = GetTime() + C.THANK.DURATION
    frame.qcHovered = nil
    frame:SetAlpha(1)
end

--- Draw `payload` ({ key, name, buff, icon }) on the toast's `frame`: the aura's icon and
--- L["%s buffed you with %s"], at full alpha with its fade's clock started. Runs only from the
--- library's present, so only out of combat. The Thank button is CA-M4-12's. Keeps the library's
--- size.
function TH.Build(frame, payload)
    regions(frame)
    startFade(frame)
    frame.qcIcon:SetTexture(payload.icon)
    frame.qcText:SetText(L["%s buffed you with %s"]:format(payload.name or "", payload.buff or ""))
    return nil, nil
end

TH.toast = TH.toast or NS.NewToast{
    name = "QuickCommsThankToast",
    build = function(frame, payload) return TH.Build(frame, payload) end,
    duration = C.THANK.DURATION,
    stack = C.THANK.STACK,
    stackGrow = "UP",
    maxQueue = C.THANK.MAX_QUEUE,
    draggable = true,
    getPosition = function()
        local t = thankSettings()
        return t and type(t.position) == "table" and t.position or nil
    end,
    setPosition = function(point)
        local t = thankSettings()
        if t then t.position = point or false end
    end,
    -- The library's point form, { point, relativePoint, x, y }: clear of the default pad (CENTER 0,-150).
    defaultPosition = { "TOP", "TOP", 0, -180 },
}

-- ── the pump ────────────────────────────────────────────────────────────────────────────────────

local function canShow()
    return not NS.Compat.InCombat() and not NS.IsStoodDown()
end

local function arm(delay)
    if TH.pumpTimer then return end
    TH.pumpTimer = NS.addon:ScheduleTimer(function()
        TH.pumpTimer = nil
        TH.Pump()
    end, delay)
end

--- Hand the oldest waiting payload to the toast when C.THANK.GAP has passed since the last Show,
--- and arm the next step while more wait. Does nothing in lockdown or stood down: what waits stays
--- in the host's list until the pump runs again.
function TH.Pump()
    if #TH.pending == 0 or not canShow() then return end
    local now = GetTime()
    local wait = lastShowAt and (lastShowAt + C.THANK.GAP - now) or 0
    if wait > 0 then
        arm(wait)
        return
    end
    local payload = table.remove(TH.pending, 1)
    lastShowAt = now
    TH.toast:Show(payload, { key = payload.key })
    if #TH.pending > 0 then arm(C.THANK.GAP) end
end

--- Take a candidate ({ aura, caster, key }, AT.OnAura's or AT.Diff's): its caster's cooldown for
--- the spell starts now, and its payload waits for the pump. Nothing is taken while stood down.
function TH.Offer(candidate)
    if NS.IsStoodDown() then return end
    local aura, caster = candidate.aura, candidate.caster
    local spellId = NS.Compat.PlainNumber(aura.spellId)
    if spellId then AT.Stamp(caster, spellId, GetTime()) end
    local pending = TH.pending
    pending[#pending + 1] = {
        key = candidate.key, caster = caster, aura = aura, name = caster.name,
        buff = NS.Compat.PlainString(aura.name), icon = NS.Compat.PlainNumber(aura.icon),
    }
    while #pending > PENDING_CAP do table.remove(pending, 1) end
    TH.Pump()
end

AT.Offer = function(candidate) TH.Offer(candidate) end

-- ── combat: Hold and Release (spec §9 The toast, F4c) ──────────────────────────────────────────
-- The Thank button is a secure child of the toast's frame, and the library hides, moves and drags
-- that frame on its own, so no toast is on screen in combat. At the PLAYER_REGEN_DISABLED edge,
-- still writable, the toast is held with no keepShown: every toast on screen goes back to the queue
-- with its full time. Hold(true) and Pause() are never used. After the fight the toast is released
-- before the after-combat diff's own shows, from this receiver or from R.OnCombatEdge(false)'s hook
-- (AT.OnCombatEnd), since a login or /reload in combat may never send RESTRICTION_CHANGED.

--- Release the toast and pump what the host held through the fight. Nothing while fighting: in
--- lockdown, or on the combat edge before lockdown reads true.
function TH.Release()
    if NS.Restrictions.InCombat() or NS.Compat.InCombat() then return end
    TH.toast:Release()
    TH.Pump()
end

AT.ReleaseToast = function() TH.Release() end

-- RESTRICTION_CHANGED (reason, canSendChat): fighting holds the toast; with the fight over and
-- lockdown false it is released, then a dirty known set is diffed, which also covers a restriction
-- that lifts outside combat.
local function onRestrictionChanged()
    if NS.Restrictions.InCombat() then
        TH.toast:Hold()
    elseif not NS.Compat.InCombat() then
        TH.Release()
        if NS.State.thankDirty then AT.Diff() end
    end
end

-- Its own target (core/Bus.lua): on the tracked bus the stand-down and stand-up take it down and
-- replay it, on the degraded bus this module does both itself.
local receiver
local function listen()
    receiver = receiver or NS.Bus:NewTarget()
    if receiver then receiver:RegisterMessage(NS.MSG.RESTRICTION_CHANGED, onRestrictionChanged) end
end
listen()

NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end

-- ── the stand-down ──────────────────────────────────────────────────────────────────────────────

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if TH.pumpTimer then
        NS.addon:CancelTimer(TH.pumpTimer)
        TH.pumpTimer = nil
    end
    TH.pending = {}
    lastShowAt = nil
    TH.toast:Clear()
    if receiver and not NS.Bus.tracked then receiver:UnregisterMessage(NS.MSG.RESTRICTION_CHANGED) end
end
