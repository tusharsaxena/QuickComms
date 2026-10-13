local _, NS = ...
-- modules/SendEngine.lua — THE ONLY SECURE WRITER (spec §9, events-frames-taint-§2/§4). It alone
-- creates frames from a Secure* template, calls SetAttribute, registers or unregisters state
-- drivers, sets and clears override bindings, and (phase 4, the Comms Dial) sets a header's frame
-- refs, wraps a button's click in a header's snippets and runs a header's snippet;
-- tests/test_sendengine.lua greps every other shipped file for those calls. Every write is
-- made out of combat. A caller asks through RunOrQueue, which runs the work now or, in combat
-- (InCombatLockdown(), never UnitAffectingCombat), files it under a key in the combat-end queue,
-- replacing an earlier entry under that key. The queue drains on PLAYER_REGEN_ENABLED, which
-- Restrictions owns and hands over (R.OnCombatEdge calls Drain), and on any RESTRICTION_CHANGED
-- once InCombatLockdown() agrees combat is over; then COMBAT_QUEUE_DRAINED (count) is sent. Drop
-- empties it on stand-down; a profile switch drops only the keys it supersedes.
--
-- Send buttons (spec §9.1): SecureActionButtonTemplate, RegisterForClicks("AnyUp", "AnyDown") as the
-- go/no-go test needed for type=macro, named QuickCommsSend<n>. Arm writes type=macro and the baked
-- line as macrotext; Disarm writes both to nil and never calls :Disable() (the WhatGroup pattern).
-- Frames are never destroyed: the pads reuse them through NS.Pool. The shapes are ConsumableMaster's:
-- modules/MacroBarButton.lua `BB.Create` (built once, out of combat), modules/MacroManager.lua
-- `queueForCombat` / `M.FlushPending` (a keyed, last-write-wins queue flushed after combat), and
-- core/LifecycleSetup.lua `standDown` for the held teardown below.
--
-- The Comms Dial (spec §11.2, Relaxed mode): modules/Dial_Secure.lua holds the snippet text and asks
-- here for the header (a SecureHandlerClickTemplate button named QuickCommsDial<n>), its ring
-- containers (SecureFrameTemplate), its wedges (send buttons wrapped by the header's snippets BEFORE
-- the click hook below, because the client's wrap replaces the script and would drop the hook), and
-- every attribute, frame ref and snippet run. The dials' keys are override bindings on one owner
-- frame, replaced as a set at each rebuild and cleared by the stand-down (spec §9.4).
--
-- Stand-down (spec §9.5, slash-commands-§7): Teardown(fn) runs the secure half now or, in combat,
-- holds it in the one registration a disabled addon may keep: a private AceEvent target listening
-- for PLAYER_REGEN_ENABLED, released the moment it fires. Its own target, because AceEvent keys a
-- handler by (event, object) and Restrictions holds PLAYER_REGEN_ENABLED on NS.addon.
--
-- The click (spec §9.2, §9.3): every button carries one insecure OnClick HOOK, which never taints the
-- secure path and cannot cancel it. On the acting edge it runs the soft guard (SEND_RESULT
-- "guarded" inside the window; onPress dims the pads), records the press for the echo tracker and
-- schedules its expiry. The CHAT_MSG_* rows below match echoes without reading their text.

NS.SendEngine = NS.SendEngine or {}
local SE = NS.SendEngine
local G = NS.SendGuard
local State = NS.State
local L = NS.L
local Perf = NS.Perf

local TAG_Q, TAG_S = "Queue", "Send"

local buttons = {}   -- every send button built this session, in build order
local seq = 0

local function inCombat() return NS.Compat.InCombat() end

local function queue()
    State.sendQueue = State.sendQueue or G.NewQueue()
    return State.sendQueue
end

-- ── send buttons ────────────────────────────────────────────────────────────────────────────

--- A new secure send button, or nil in combat (building a secure frame is out of combat only).
--- @param parent table the frame it belongs to (a pad's root, a dial's ring)
--- @param onPress function|nil onPress(button, verdict, window), called by the click hook
--- @param wrap table|nil a dial wedge: { header, pre, post }, the header's snippets around its click
--- @return table|nil
function SE.NewButton(parent, onPress, wrap)
    if inCombat() then
        NS.Debug(TAG_S, "button refused: in combat")
        return nil
    end
    seq = seq + 1
    local b = CreateFrame("Button", "QuickCommsSend" .. seq, parent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    if wrap then
        -- Wrapped before the hook below: the client's wrap replaces the script, dropping any earlier
        -- hook. A wedge acts on the up edge, so its pre snippet can tell the edges apart, and only a
        -- left click (a number key clicks with LeftButton) is a press: a right click closes the dial.
        wrap.header:WrapScript(b, "OnClick", wrap.pre, wrap.post)
        b:SetAttribute("useOnKeyDown", false)
        b.qcLeftOnly = true
    end
    b:HookScript("OnClick", function(...) SE.OnClick(...) end)
    b.qcOnPress = onPress
    b.qcArmed = false
    buttons[#buttons + 1] = b
    return b
end

function SE.ButtonCount()
    return #buttons
end

--- Arm a button with one baked line. Out of combat only; an unchanged line rewrites nothing.
--- @return boolean armed
function SE.Arm(b, line, meta)
    if inCombat() then
        NS.Debug(TAG_S, "arm refused: in combat")
        return false
    end
    if b.qcArmed and b:GetAttribute("macrotext") == line then
        b.qcMeta = meta
        return true
    end
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", line)
    b.qcArmed, b.qcMeta = true, meta
    return true
end

--- Disarm a button: nothing it does reaches chat. `meta` (optional) is what the click hook may
--- still use, such as a solo fallback's local print. Out of combat only.
--- @return boolean disarmed
function SE.Disarm(b, meta)
    if inCombat() then
        NS.Debug(TAG_S, "disarm refused: in combat")
        return false
    end
    if b.qcArmed or b:GetAttribute("type") ~= nil then
        b:SetAttribute("type", nil)
        b:SetAttribute("macrotext", nil)
    end
    b.qcArmed, b.qcMeta = false, meta
    return true
end

function SE.ArmedButtons()
    local out = {}
    for _, b in ipairs(buttons) do
        if b.qcArmed then out[#out + 1] = b end
    end
    return out
end

--- A button's baked line with its pipes doubled, for display (spec §16: shown escaped).
function SE.Escaped(b)
    local text = b:GetAttribute("macrotext")
    if type(text) ~= "string" then return "" end
    return (text:gsub("|", "||"))
end

-- ── visibility (spec §10.3): a state driver, never an insecure Show/Hide in combat ─────────

function SE.SetVisibility(frame, expression)
    if inCombat() then return false end
    RegisterStateDriver(frame, "visibility", expression)
    frame.qcDriver = expression
    return true
end

function SE.ClearVisibility(frame)
    if inCombat() then return false end
    if frame.qcDriver then
        UnregisterStateDriver(frame, "visibility")
        frame.qcDriver = nil
    end
    frame:Hide()
    return true
end

-- ── the Comms Dial's secure frames (spec §11.2): Dial_Secure asks, this file writes ─────────

--- A dial's header: a named SecureHandlerClickTemplate button (Bindings.xml and the dial's key click
--- it by name), registered for the down edge only, hidden until its snippet opens it. Nil in combat.
function SE.NewDialHeader(name)
    if inCombat() then
        NS.Debug("Dial", "header refused: in combat")
        return nil
    end
    local h = CreateFrame("Button", name, UIParent, "SecureHandlerClickTemplate")
    h:RegisterForClicks("AnyDown")
    h:SetFrameStrata("DIALOG")
    h:Hide()
    return h
end

--- One ring's container under a dial's header: explicitly protected, so the header's snippets can show
--- and hide it in combat. Hidden. Nil in combat.
function SE.NewDialRing(header)
    if inCombat() then return nil end
    local r = CreateFrame("Frame", nil, header, "SecureFrameTemplate")
    r:Hide()
    return r
end

--- Write several attributes (a header's snippets and ring layout, a wedge's target). Out of combat.
--- @return boolean written
function SE.SetAttributes(frame, attrs)
    if inCombat() then
        NS.Debug("Dial", "attributes refused: in combat")
        return false
    end
    for k, v in pairs(attrs) do frame:SetAttribute(k, v) end
    return true
end

--- Hand a header a frame its snippets reach by name. Out of combat.
--- @return boolean set
function SE.SetFrameRef(header, name, frame)
    if inCombat() then return false end
    header:SetFrameRef(name, frame)
    return true
end

--- Run one of a header's snippets now (a rebuild closes the dial; test mode opens it). Out of combat.
--- @return boolean ran
function SE.RunSnippet(header, attr)
    if inCombat() then return false end
    header:Execute(("self:RunAttribute(%q)"):format(attr))
    return true
end

-- ── the combat-end queue (spec §9.1) ────────────────────────────────────────────────────────

function SE.Queue(key, fn)
    local replaced = G.Put(queue(), key, fn)
    NS.Debug(TAG_Q, "%s %s (%s pending)", replaced and "replaced" or "queued", key, G.Count(queue()))
end

--- Run `fn` now, or queue it under `key` until combat ends.
--- @return boolean ranNow
function SE.RunOrQueue(key, fn)
    if inCombat() then
        SE.Queue(key, fn)
        return false
    end
    fn()
    return true
end

--- Run every queued entry, in filing order, then send COMBAT_QUEUE_DRAINED. A failing entry is
--- reported on one line and the others still run.
--- @return number count
function SE.Drain(cause)
    if inCombat() then return 0 end
    local q = State.sendQueue
    if not q or G.Count(q) == 0 then return 0 end
    local entries = G.Take(q)
    for _, e in ipairs(entries) do
        local ok, err = pcall(e.fn)
        if not ok then NS.Print(L["A deferred update failed (%s): %s"]:format(e.key, tostring(err))) end
    end
    NS.Debug(TAG_Q, "drained %s (%s)", #entries, tostring(cause))
    NS.addon:SendMessage(NS.MSG.COMBAT_QUEUE_DRAINED, #entries)
    return #entries
end

--- Forget queued entries: every one (stand-down), or only those under `keys` (a profile switch
--- supersedes the rebuild and the positions, never a held drag's stop).
--- @param keys table|nil the keys to forget; nil forgets all
--- @return number dropped
function SE.Drop(reason, keys)
    local q = State.sendQueue
    local n = 0
    if q and keys then
        for _, key in ipairs(keys) do
            if G.Remove(q, key) then n = n + 1 end
        end
    else
        n = q and G.Count(q) or 0
        State.sendQueue = nil
    end
    if n > 0 then NS.Debug(TAG_Q, "dropped %s (%s)", n, tostring(reason)) end
    return n
end

--- The pending keys, for diagnostics.
function SE.Snapshot()
    local q = State.sendQueue
    return q and G.Keys(q) or {}
end

-- ── the override bindings (spec §9.4): the dials' keys ──────────────────────────────────────

local bindOwner          -- a plain frame; every override binding this addon holds is its
local bound, boundSig = {}, nil

--- Bind each { key, name, button } as an override click, replacing every binding this addon held.
--- Out of combat only: the client refuses override bindings in combat. Logged only on a change.
--- @return boolean applied
function SE.BindKeys(list)
    if inCombat() then
        NS.Debug("Bind", "bindings refused: in combat")
        return false
    end
    bindOwner = bindOwner or CreateFrame("Frame")
    ClearOverrideBindings(bindOwner)
    bound = {}
    local parts = {}
    for _, b in ipairs(list or {}) do
        SetOverrideBindingClick(bindOwner, true, b.key, b.name, b.button)
        bound[#bound + 1] = { key = b.key, name = b.name, button = b.button }
        parts[#parts + 1] = b.key .. "=" .. b.name
    end
    local sig = table.concat(parts, ",")
    if sig ~= boundSig then
        boundSig = sig
        NS.Debug("Bind", "bound %s", sig ~= "" and sig or "nothing")
    end
    return true
end

--- Release every key this addon bound. Out of combat only.
function SE.ClearKeys()
    return SE.BindKeys({})
end

--- The bindings in force, for diagnostics and the Binding tab: { key, name, button } each, a copy.
function SE.Bindings()
    local out = {}
    for i, b in ipairs(bound) do out[i] = { key = b.key, name = b.name, button = b.button } end
    return out
end

-- ── the held stand-down (spec §9.5) ─────────────────────────────────────────────────────────

local pending   -- the private target; built on first use

local function releasePending()
    if pending then pending:UnregisterEvent("PLAYER_REGEN_ENABLED") end
end

local function onRegenEnabled()
    releasePending()
    local held = State.pendingTeardown
    State.pendingTeardown = nil
    if held then held() end
    NS.Debug(TAG_Q, "held stand-down finished")
end

--- Run the secure half of a stand-down now, or hold it until combat ends.
--- @return boolean ranNow
function SE.Teardown(fn)
    if not inCombat() then
        fn()
        return true
    end
    State.pendingTeardown = fn
    pending = pending or LibStub("AceEvent-3.0"):Embed({})
    -- Through the SafeRegister family (events-frames-taint-§1). A refusal cannot happen on a real
    -- client (the event exists); if it did, the event is listed in NS.rejectedEvents (diagnostics)
    -- and the teardown stays held in State.pendingTeardown, which the next stand-up cancels.
    if not NS.SafeRegisterEvent(pending, "PLAYER_REGEN_ENABLED", onRegenEnabled, NS.rejectedEvents) then
        NS.Debug(TAG_Q, "stand-down held, but PLAYER_REGEN_ENABLED was refused")
        return false
    end
    NS.Debug(TAG_Q, "stand-down held until combat ends")
    return false
end

--- A stand-up while a stand-down is held: the held half must not run any more.
function SE.CancelTeardown()
    if State.pendingTeardown == nil then return end
    State.pendingTeardown = nil
    releasePending()
end

-- ── the click, the soft guard and the echo tracker (spec §9.2, §9.3) ────────────────────────

local function echoState()
    State.sendEcho = State.sendEcho or G.NewEcho()
    return State.sendEcho
end

local function result(meta, what)
    NS.Debug(what == "guarded" and "Guard" or "Echo", "%s %s on %s", meta.calloutId, what, meta.surfaceId)
    NS.addon:SendMessage(NS.MSG.SEND_RESULT, meta.calloutId, meta.surfaceId, what)
end

local function expire()
    local e = State.sendEcho
    if not e then return end
    for _, p in ipairs(G.Expire(e, GetTime())) do
        result(p.meta, "dropped")
        if NS.Setting("behavior.dropNotes") then
            NS.Print(L["%s may have been dropped by the game (sent too soon after another message)."]
                :format(tostring(p.meta.name)))
        end
    end
end

local function scheduleExpiry()
    State.echoTimers = State.echoTimers or {}
    local handle
    handle = NS.addon:ScheduleTimer(function()
        State.echoTimers[handle] = nil
        expire()
    end, G.ECHO_WINDOW + 0.05)
    State.echoTimers[handle] = true
end

local function useKeyDown(b)
    local v = b:GetAttribute("useOnKeyDown")
    if v == nil then return NS.Compat.UseKeyDown() end
    return v == true
end

local function press(b)
    local meta = b.qcMeta
    if not meta or NS.IsStoodDown() then return end
    if meta.selfText then
        NS.Print(meta.selfText)
        return
    end
    if not (b.qcArmed and meta.chatType) then return end
    -- A padlocked chip stays armed (spec §8.4), but the game is expected to refuse it: no echo is
    -- awaited and no guard stamped, so a refusal is never blamed on the spam guard.
    local lockText = meta.lockText and meta.lockText()
    if lockText then
        if NS.Setting("behavior.dropNotes") then
            NS.Print(L["%s may not have been sent. %s"]:format(tostring(meta.name), lockText))
        end
        return
    end
    local now = GetTime()
    local window = NS.Setting("behavior.spamGuard")
    local verdict = G.Decide(now, State.lastSendAt, window)
    State.lastSendAt = now
    G.Record(echoState(), now, meta.chatType, meta)
    scheduleExpiry()
    if verdict == "guarded" then result(meta, "guarded") end
    if b.qcOnPress then b.qcOnPress(b, verdict, window) end
end

--- The OnClick hook every send button carries. Acts once per press, on the edge the secure
--- template acts on.
function SE.OnClick(b, mouseButton, down)
    if b.qcLeftOnly and mouseButton ~= "LeftButton" then return end
    if not G.IsActingEdge(down, useKeyDown(b)) then return end
    local t0 = Perf.on and debugprofilestop()
    press(b)
    if t0 then Perf.Note("send.click", debugprofilestop() - t0) end
end

function SE.GuardState()
    local window = NS.Setting("behavior.spamGuard")
    return { window = window, last = State.lastSendAt, remaining = G.Remaining(GetTime(), State.lastSendAt, window) }
end

function SE.EchoState()
    local e = State.sendEcho or G.NewEcho()
    return { pending = #e.pending, sent = e.sent, dropped = e.dropped, unknown = e.unknown, ignored = e.ignored }
end

for _, event in ipairs(G.ECHO_EVENTS) do
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { event, "OnSendEcho" }
end

-- CHAT_MSG_* (text, sender, ..., guid as the 12th payload field). The text is never read (F7).
function NS.addon.OnSendEcho(_, event, ...)
    local e = State.sendEcho
    if not (e and e.pending[1]) then return end
    local t0 = Perf.on and debugprofilestop()
    local sender = select(2, ...)
    local guid = select(12, ...)
    local hit = G.Match(e, G.CHAT_TYPE_BY_EVENT[event], GetTime(), NS.Compat.SenderIsPlayer(sender, guid))
    if hit then result(hit.meta, "sent") end
    if t0 then Perf.Note("echo.match", debugprofilestop() - t0) end
end

-- Stood down, no echo can arrive: the timers are canceled and the presses forgotten.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    for handle in pairs(State.echoTimers or {}) do NS.addon:CancelTimer(handle) end
    State.echoTimers, State.sendEcho, State.lastSendAt = nil, nil, nil
end

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

local function onRestrictionChanged()
    if not inCombat() then SE.Drain("RESTRICTION_CHANGED") end
end

-- Its own target (core/Bus.lua). On the tracked bus the stand-down and stand-up take it down and
-- replay it; on the degraded bus this module does both itself.
local receiver
local function listen()
    receiver = receiver or NS.Bus:NewTarget()
    if receiver then receiver:RegisterMessage(NS.MSG.RESTRICTION_CHANGED, onRestrictionChanged) end
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    SE.Drop("standDown")
    if receiver and not NS.Bus.tracked then receiver:UnregisterMessage(NS.MSG.RESTRICTION_CHANGED) end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    SE.CancelTeardown()
    if not NS.Bus.tracked then listen() end
end
