local _, NS = ...
-- modules/AutoThank_Toast.lua — auto-thank's toast host (#19, spec §9 The toast): a candidate from
-- modules/AutoThank.lua (AT.Offer) becomes a "buffed you" toast in LibKa0s-Toast-1.0 (the seam,
-- core/ToastSetup.lua), paced and stacked.
--
-- The throttle: a cooldown per caster and spell (AT.Stamp, at the offer), at least C.THANK.GAP
-- between two Show calls through the host's own pump, at most C.THANK.STACK on screen and the
-- library's maxQueue dropping the oldest waiting toast. The toast's frame carries the Thank
-- button, a secure child (SendEngine's, D4), so no toast may be on screen in combat: every host
-- Show and every step of the pump is gated on lockdown, and a payload offered in combat waits in
-- the host's own list; the toast itself is held through combat and released after it. The strata is the
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
local BUTTON_W, BUTTON_H = 64, 22

-- The icon, the line and the note under it (why the Thank button is not armed), made once per pool
-- frame and re-used on every draw. The line and the note wear the skin (SD-SK-QC.1, LibKa0s#97): the
-- skin's body face, the line in text.body and the note in text.disabled; the library's toast paints
-- only its frame, and records both strings here so a skin switch repaints them.
local function regions(frame)
    if frame.qcText then return end
    frame.qcIcon = frame:CreateTexture(nil, "ARTWORK")
    frame.qcIcon:SetSize(ICON, ICON)
    frame.qcIcon:SetPoint("LEFT", frame, "LEFT", INSET, 0)
    frame.qcText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.qcText:SetPoint("LEFT", frame.qcIcon, "RIGHT", INSET / 2, 0)
    frame.qcText:SetPoint("RIGHT", frame, "RIGHT", -(INSET * 2 + BUTTON_W), 0)
    frame.qcText:SetJustifyH("LEFT")
    frame.qcNote = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.qcNote:SetPoint("TOPLEFT", frame.qcText, "BOTTOMLEFT", 0, -2)
    frame.qcNote:SetPoint("RIGHT", frame.qcText, "RIGHT", 0, 0)
    frame.qcNote:SetJustifyH("LEFT")
    NS.Skin.Text(frame.qcText, "body")
    NS.Skin.Text(frame.qcNote, "disabled")
end

-- ── the Thank button (D4) ───────────────────────────────────────────────────────────────────────
-- SendEngine's secure button, made once per pool frame on its first draw and attached to the toast
-- once (Attach hooks the button, so attaching it on every reuse would pile hooks up). Each draw
-- arms it with AT.Macro's macro for the payload's caster and buff, or disarms it and says why. It is
-- the owner's push button (SD-SK-QC.2, LibKa0s#97): S.Button draws its body and edge in btn.* and
-- its label (`Text`, the field it reads) in btn.text and the body face, btn.hover under the pointer.
-- S.Button adds a backdrop and hooks OnEnter, OnLeave, OnEnable and OnDisable, never a click
-- script, and it runs at the build, which SE.NewButton allows only out of combat.

TH.LOCK_TEXT = { whisperLockdown = L["Locked: whispers are blocked right now."] }

local function lockText(lock)
    return lock and (TH.LOCK_TEXT[lock] or NS.PadRender.LOCK_TEXT[lock] or tostring(lock))
end

-- A click that sent something: its toast goes, when the toast may be touched.
local function onThank(b)
    local key = b.qcMeta and b.qcMeta.calloutId
    if key == nil then return end
    NS.SendEngine.RunOrQueue("thank.remove", function() TH.toast:Remove(key) end)
end

local function thankButton(frame)
    if frame.qcThank then return frame.qcThank end
    local b = NS.SendEngine.NewThankButton(frame, onThank)
    if not b then return nil end
    b:SetSize(BUTTON_W, BUTTON_H)
    b:SetPoint("RIGHT", frame, "RIGHT", -INSET, 0)
    b.qcLabel = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.qcLabel:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.qcLabel:SetText(L["Thank"])
    b.Text = b.qcLabel
    NS.Skin.Button(b)
    frame.qcThank = b
    TH.toast:Attach(b)
    return b
end

-- The actions a Thank macro carries, for the press's echo and lock reads (AT.Macro says whether a
-- whisper line is in, so no newline is read as one).
local function actionsOf(send, whisper)
    local actions = {}
    if send ~= "line" then actions[#actions + 1] = { kind = "emote", chatType = "TEXT_EMOTE" } end
    if whisper then actions[#actions + 1] = { kind = "whisper", chatType = "WHISPER" } end
    return actions
end

-- The test-mode sample's Thank button: a plain button (no secure child, so the sample's frame never
-- needs one and the combat edge can always take it down), drawn as the owner's push button. A click
-- prints the placeholder echo every test-mode placeholder prints, and sends nothing. Made once per
-- pool frame, shown only while that frame carries the sample.
local function sampleButton(frame)
    if frame.qcSample then return frame.qcSample end
    local b = CreateFrame("Button", nil, frame)
    b:SetSize(BUTTON_W, BUTTON_H)
    b:SetPoint("RIGHT", frame, "RIGHT", -INSET, 0)
    b.qcLabel = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.qcLabel:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.qcLabel:SetText(L["Thank"])
    b.Text = b.qcLabel
    NS.Skin.Button(b)
    b:SetScript("OnClick", function() NS.Print(NS.Preview.TestEcho(L["Thank"])) end)
    frame.qcSample = b
    return b
end

-- The sample (payload.test): its plain button up and the secure one, when the frame already has one
-- from an earlier real toast, disarmed and hidden. Out of combat only, as every Build is.
local function showSample(frame)
    frame.qcNote:SetText(L["Test mode: sends nothing."])
    if frame.qcThank then
        NS.SendEngine.Disarm(frame.qcThank)
        frame.qcThank:Hide()
    end
    sampleButton(frame):Show()
end

-- Arm the frame's Thank button for `payload`, or disarm it with the reason on the toast. The test-mode
-- sample is never armed (showSample).
local function armThank(frame, payload)
    if payload.test then return showSample(frame) end
    if frame.qcSample then frame.qcSample:Hide() end
    local b = thankButton(frame)
    if b then b:Show() end
    local settings = thankSettings() or {}
    local macro, why, whisper = AT.Macro(payload.caster, payload.buff, settings)
    NS.Debug("Thank", "arm %s: send=%s button=%s macro=[%s] why=%s", tostring(payload.key),
        tostring(settings.send), tostring(b ~= nil), NS.SendEngine.DebugMacro(macro), tostring(why))
    frame.qcNote:SetText(macro and "" or (AT.REASON[why] or ""))
    if not b then return end
    if not macro then
        NS.SendEngine.Disarm(b)
        return
    end
    local actions = actionsOf(settings.send or "emote", whisper)
    local chatTypes = {}
    for i, a in ipairs(actions) do chatTypes[i] = a.chatType end
    NS.SendEngine.Arm(b, macro, {
        kind = "thank", name = L["Thank"], calloutId = payload.key, surfaceId = "thank",
        actions = actions, chatTypes = chatTypes, lockText = lockText,
    })
end

-- ── the fade (D26) ──────────────────────────────────────────────────────────────────────────────
-- The library has no fade, so an unclicked toast fades here over its last C.THANK.FADE seconds and
-- the library's own timer hides it at the same moment. The pointer holds it as the library's hover
-- pause does (the button sits inside the frame, so IsMouseOver covers it), pushing the due time by
-- what it held; leaving with under a second left gives one second, the library's MIN_RESUME. A drag
-- on any toast holds every toast on screen (the library's onDragStart pauses each), so TH.dragging,
-- set from each pool frame's OnDragStart and cleared by its OnDragStop (or by the combat edge's Hold
-- and the stand-down, which end a drag without that script), holds every fade the same way.
-- OnUpdate runs only while the frame is shown, and does nothing in combat.

local MIN_LEFT = 1

local function fade(frame, elapsed)
    if NS.Compat.InCombat() or not frame.qcDue then return end
    local now = GetTime()
    if TH.dragging or frame:IsMouseOver() then
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

local function dragStart() TH.dragging = true end
local function dragStop() TH.dragging = nil end

-- Hooked once per pool frame, on its first draw; every draw starts the fade's clock again. The
-- test-mode sample is sticky and keeps no clock, so it stays at full alpha until test mode ends.
local function startFade(frame, sticky)
    if not frame.qcFadeHooked then
        frame.qcFadeHooked = true
        frame:HookScript("OnUpdate", fade)
        frame:HookScript("OnDragStart", dragStart)
        frame:HookScript("OnDragStop", dragStop)
    end
    frame.qcDue = not sticky and GetTime() + C.THANK.DURATION or nil
    frame.qcHovered = nil
    frame:SetAlpha(1)
end

--- Draw `payload` ({ key, caster, name, buff, icon }) on the toast's `frame`: the aura's icon,
--- L["%s buffed you with %s"] and the Thank button armed for the caster, at full alpha with its
--- fade's clock started. Runs only from the library's present, so only out of combat. Keeps the
--- library's size.
function TH.Build(frame, payload)
    regions(frame)
    startFade(frame, payload.test)
    armThank(frame, payload)
    frame.qcIcon:SetTexture(payload.icon)
    frame.qcText:SetText(L["%s buffed you with %s"]:format(payload.name or "", payload.buff or ""))
    return nil, nil
end

--- The toast's dragged spot ({ point, relativePoint, x, y }, or nil for the library's own), written
--- through the schema seam as the `thank.position` row, the way a pad's drag writes `pad.point`
--- (Library.SetSurfacePoint), so the row's ValidPoint refuses a malformed or off-screen point.
--- @return boolean stored
function TH.SavePosition(point)
    local ok, err = NS.SchemaRuntime.Set("thank.position", point or false)
    if not ok then NS.Debug("Thank", "toast move refused: %s", tostring(err)) end
    return ok == true
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
    setPosition = function(point) TH.SavePosition(point) end,
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

-- ── the test-mode sample (FB-QC-02, owner feedback 2026-11-24) ────────────────────────────────
-- /qc test puts up one sample "buffed you" toast so the toast can be seen and placed, whether
-- Auto-thank is on or off (a preview writes nothing). It goes through the library's Toast:Preview:
-- sticky, at the head, under Toast.PREVIEW, presented directly, so the pump, the GAP, the cooldown
-- stamps and the host's pending list are never touched. Its Thank button is disarmed (armThank) and
-- its note says it is a placeholder. Only test mode proper shows it: Preview as and the edit preview
-- do not. Test mode is refused in combat and ends at the combat edge while secure writes are still
-- allowed, so the sample's secure child is never on screen in lockdown.

-- The sample's caster is a stranger, so it is the first of LibKa0s-Sim-1.0's seeded crowd (Sim.SampleCrowd,
-- minor 5), beyond the five protagonists that stand for the player's own party: every Ka0s addon draws its
-- sample people from the library (LibKa0s#104, FB2-QC-01), never a name of its own. It reads as a real
-- caster's name does (Compat.AuraCaster): the bare name on Retail, "First Surname" where names are
-- regional. Without the library's Sim major (a degraded install) the toast says L["A stranger"].

TH.SAMPLE_ICON = 134400   -- INV_Misc_QuestionMark: a sample, not any real buff
TH.SAMPLE_SEED = 1        -- the crowd's seed: the same stranger on every run
TH.PREVIEW_KEY = NS.TOAST_PREVIEW

--- The sample caster's name: the library crowd's first person on this client, or the plain label.
--- @return string
function TH.SampleName()
    local Sim = LibStub and LibStub("LibKa0s-Sim-1.0", true)
    if not (Sim and Sim.SampleCrowd) then return L["A stranger"] end
    local client = NS.Compat.ClientKey()
    local ok, crowd = pcall(Sim.SampleCrowd, client, 1, TH.SAMPLE_SEED)
    local row = ok and type(crowd) == "table" and crowd[1] or nil
    if not row then return L["A stranger"] end
    return client == "forever" and row.fullName or row.name
end

--- The sample's payload: a stranger from the library's crowd and a sample buff, flagged `test`.
function TH.SamplePayload()
    local who = TH.SampleName()
    return { key = TH.PREVIEW_KEY, test = true, caster = { name = who }, name = who,
        buff = L["a sample buff"], icon = TH.SAMPLE_ICON }
end

--- Put the sample up while test mode is on and the toast may be shown. Answers whether it did.
function TH.ShowTest()
    if not (NS.Preview and NS.Preview.IsTestMode()) or not canShow() then return false end
    TH.toast:Preview(TH.SamplePayload())
    return true
end

--- Take the sample down (from the screen and from the queue a Hold sent it back to).
function TH.HideTest()
    TH.toast:Remove(TH.PREVIEW_KEY)
end

local function onTestModeChanged()
    if NS.Preview.IsTestMode() then TH.ShowTest() else TH.HideTest() end
end

-- RESTRICTION_CHANGED (reason, canSendChat): fighting holds the toast; with the fight over and
-- lockdown false it is released, then a dirty known set is diffed, which also covers a restriction
-- that lifts outside combat. The Hold takes every toast down, which ends a drag in the library
-- without the frame's OnDragStop, so the host's drag flag goes with it.
local function onRestrictionChanged()
    if NS.Restrictions.InCombat() then
        TH.toast:Hold()
        TH.dragging = nil
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
    if receiver then
        receiver:RegisterMessage(NS.MSG.RESTRICTION_CHANGED, onRestrictionChanged)
        receiver:RegisterMessage(NS.MSG.TEST_MODE_CHANGED, onTestModeChanged)
    end
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
    TH.dragging = nil
    lastShowAt = nil
    TH.toast:Clear()
    if receiver and not NS.Bus.tracked then
        receiver:UnregisterMessage(NS.MSG.RESTRICTION_CHANGED)
        receiver:UnregisterMessage(NS.MSG.TEST_MODE_CHANGED)
    end
end
