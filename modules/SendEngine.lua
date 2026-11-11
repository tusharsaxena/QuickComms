local _, NS = ...
-- modules/SendEngine.lua — THE ONLY SECURE WRITER (spec §9, events-frames-taint-§2/§4). It alone
-- creates frames from a Secure* template, calls SetAttribute, registers or unregisters state
-- drivers, and (phase 4, the Comms Dial) sets a header's frame
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
-- the click hook below, because the client's wrap replaces the script and would drop the hook), each
-- ring's catcher (a secure button over the disc, wrapped by the header's catcher snippet, that
-- forwards a click to the wedge under the cursor), its screen catcher (a full-screen secure button
-- under the dial whose wrapped click closes it), and every attribute, frame ref and snippet run. A dial's key is WoW's own binding of its header's
-- Bindings.xml entry since 2026-10-20, set in Options -> Keybindings or on General > Keybindings (the library's tab, which writes it with SetBinding), so no binding is written
-- here.
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
--
-- The press-time re-bake (QF-03): every button also carries one insecure PreClick HOOK. A position
-- moves while the plan does not, so for a button whose meta carries `rebake` (Pad's arm: an armed
-- live slot whose text uses {coordinates}) it re-bakes the line, OUT OF COMBAT ONLY, and re-arms
-- through Arm when the line changed; the secure handler that runs next sends the fresh line. In
-- combat it returns at once and writes nothing, so the button sends what it last held. The
-- RESTRICTION_CHANGED edge into combat (still writable at PLAYER_REGEN_DISABLED) re-arms every such
-- button once (RefreshRebakes), so a press in combat sends the position at the pull. PreClick is the
-- client's place to adjust a secure action button's attributes before it acts; the line is written
-- by addon code exactly as Arm writes it at a rebuild, only later. The same hook, in and out of combat,
-- reads the press-time notes (SE.PressNotes: no target, no marking rights, pings off or cooling down)
-- before the macro runs; it only reads, and press() prints them once.

NS.SendEngine = NS.SendEngine or {}
local SE = NS.SendEngine
local G = NS.SendGuard
local State = NS.State
local L = NS.L
local Perf = NS.Perf
local LAYERS = NS.Constants.LAYERS

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
    b:HookScript("PreClick", function(...) SE.PreClick(...) end)
    b.qcOnPress = onPress
    b.qcArmed = false
    buttons[#buttons + 1] = b
    return b
end

--- Auto-thank's Thank button (#19, D4): a send button that acts on a left click alone, so a
--- right-click (the toast's dismiss) never runs its macro. Its press is pressThank's. Nil in combat.
--- @param parent table the toast frame it sits in
--- @param onPress function|nil onPress(button), called after a press that sent something
--- @return table|nil
function SE.NewThankButton(parent, onPress)
    local b = SE.NewButton(parent, onPress)
    if not b then return nil end
    b:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    b.qcLeftOnly = true
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
--- still use, such as a solo fallback's local print or a previewed slot's echo. Out of combat only.
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

-- Re-arm `b` with its macro re-baked now (QF-03), when it carries a `rebake` and is armed. Out of
-- combat only. The re-bake answers BakeActions' macro, reason, info: a macro refreshes the meta's
-- actions, chat types, locks and skipped ones (combined actions §3), so the echo never waits for a
-- Line the new position pushed over the macro's budget, and the press says why that Line dropped
-- (meta.lineNote). Nothing baked keeps the old macro and meta; an unchanged macro writes nothing.
local function rebake(b)
    local meta = b.qcMeta
    if not (b.qcArmed and meta and meta.rebake) or inCombat() then return false end
    local t0 = Perf.on and debugprofilestop()
    local macro, _, info = meta.rebake()
    local changed = false
    if type(macro) == "string" and type(info) == "table" then
        NS.Surfaces.ApplyActions(meta, info)
        local line = info.actions[1]
        meta.lineNote = line and line.kind == "line" and line.reason == "tooLong"
            and L["%s: the line is too long to send with its other actions."]:format(tostring(meta.name)) or nil
        changed = macro ~= b:GetAttribute("macrotext")
        if changed then SE.Arm(b, macro, meta) end
    end
    if t0 then Perf.Note("coordsRebake", debugprofilestop() - t0) end
    return changed
end

--- Re-arm every re-baking button once (the combat edge). Out of combat only.
--- @return number re-armed
function SE.RefreshRebakes()
    local n = 0
    for _, b in ipairs(buttons) do
        if rebake(b) then n = n + 1 end
    end
    if n > 0 then NS.Debug(TAG_S, "re-baked %s at the combat edge", n) end
    return n
end

function SE.ArmedButtons()
    local out = {}
    for _, b in ipairs(buttons) do
        if b.qcArmed then out[#out + 1] = b end
    end
    return out
end

--- A button's baked macro with its pipes doubled, for display (spec §16: shown escaped), and each
--- "\n" between its actions shown as " \n " (combined actions §3), so a combined macro stays one row.
function SE.Escaped(b)
    local text = b:GetAttribute("macrotext")
    if type(text) ~= "string" then return "" end
    return (text:gsub("|", "||"):gsub("\n", " \\n "))
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
    -- The secure fixed point (core/Constants.lua LAYERS): chosen first, never moved, since a secure
    -- frame's strata is protected in combat; what must sit over the dial is a band up in it, or a tier.
    h:SetFrameStrata(LAYERS.STRATA.HUD_POPUP)
    h:SetFrameLevel(UIParent:GetFrameLevel() + LAYERS.LEVEL.DIAL)
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

--- One ring's catcher (dial polish, 2026-10-21): a SecureActionButtonTemplate button in `ring` that
--- Dial.lua sizes to the disc, registered for the up edge only, its click wrapped by the header's
--- catcher snippet, which forwards a left click to the wedge whose slice is under the cursor
--- (`*type-w<j> = "click"`, the any-modifier form, written by DialSecure.Load), and runs the hub's
--- action inside the hub's circle. The wedges above it and the header (the hub) take no mouse, so every
--- mouse click on the disc, the hub's included, lands here. Nil in combat.
function SE.NewDialCatcher(header, ring, pre)
    if inCombat() then return nil end
    local c = CreateFrame("Button", nil, ring, "SecureActionButtonTemplate")
    c:RegisterForClicks("AnyUp")
    header:WrapScript(c, "OnClick", pre)
    c:SetAttribute("useOnKeyDown", false)
    -- Under its own ring (DIAL_CATCHER, -1), deliberately: the ring container draws no region, so
    -- nothing of the ring covers it, and the wedges over it take no mouse.
    c:SetFrameLevel(math.max(0, (header:GetFrameLevel() or 0) + LAYERS.LEVEL.DIAL_CATCHER))
    return c
end

--- A dial's screen catcher (dial polish, 2026-10-21): a SecureActionButtonTemplate child of `header`
--- over the whole screen (SetAllPoints(UIParent)), registered for the up edge only, its click wrapped
--- by the header's screen snippet, which closes the dial and lets nothing through (it has no type).
--- It sits under the dial in the dial's strata (#14), so it also covers a pad, at DIAL_SCREEN: below the
--- ring catchers' level (the header's - 1), which it would tie with one higher. The modals and the
--- preview window are bands over the dial, so a click on one reaches it, not this. The header's
--- show snippet shows it only on a key open, its close snippet hides it. Hidden. Nil in combat.
function SE.NewDialScreen(header, pre)
    if inCombat() then return nil end
    local s = CreateFrame("Button", nil, header, "SecureActionButtonTemplate")
    s:SetFrameLevel(math.max(0, (header:GetFrameLevel() or 0) + LAYERS.LEVEL.DIAL_SCREEN))
    s:SetAllPoints(UIParent)
    s:RegisterForClicks("AnyUp")
    header:WrapScript(s, "OnClick", pre)
    s:SetAttribute("useOnKeyDown", false)
    s:Hide()
    return s
end

--- Write several attributes (a header's snippets and ring layout, a wedge's target), and set each key
--- in `clear` (a list, optional: a catcher's empty places) to nil. Out of combat.
--- @return boolean written
function SE.SetAttributes(frame, attrs, clear)
    if inCombat() then
        NS.Debug("Dial", "attributes refused: in combat")
        return false
    end
    for _, k in ipairs(clear or {}) do frame:SetAttribute(k, nil) end
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

--- Whether an entry is waiting under `key`, so a caller on a hot path files it once.
--- @return boolean
function SE.Queued(key)
    local q = State.sendQueue
    return q ~= nil and q.fns[key] ~= nil
end

--- The pending keys, for diagnostics.
function SE.Snapshot()
    local q = State.sendQueue
    return q and G.Keys(q) or {}
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

-- A drop note names the callout, and the emote when that is what dropped (CA-M2-4).
local DROP_NOTE = {
    emote = L["%s (emote) may not have been sent."],
}

local function expire()
    local e = State.sendEcho
    if not e then return end
    for _, p in ipairs(G.Expire(e, GetTime())) do
        result(p.meta, "dropped")
        if NS.Setting("behavior.dropNotes") then
            local note = DROP_NOTE[p.kind] or L["%s may have been dropped by the game (sent too soon after another message)."]
            NS.Print(note:format(tostring(p.meta.name)))
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

local function hasActions(meta)
    return type(meta.actions) == "table" and #meta.actions > 0
end

-- A disarmed button's echo: one print per entry (Preview.SlotEcho's list), never a newline inside one.
local function printNotes(notes)
    for _, note in ipairs(notes or {}) do NS.Print(note) end
end

local function printEcho(echo)
    if type(echo) ~= "table" then echo = { echo } end
    for _, e in ipairs(echo) do NS.Print(NS.Preview.FillEcho(e)) end
end

-- A press's baked chat actions, split by their live lock (combined actions §4 step 6): the open ones
-- await an echo, each locked one prints its note ("may not have been sent", with why) and awaits none.
-- The lock is read at the press from the current snapshot (CA-M2-R1), never the bake's copy: a
-- press-time or combat-edge re-bake gives the meta its own action tables, which S.RefreshLocks never
-- reaches, so a lockdown that came on after it would otherwise be tracked as a send. An action with no
-- concrete channel (a test's hand-built meta) keeps the lock it carries. Safe in combat: plain reads.
local function chatActions(meta)
    local open, locked, snap = {}, {}, nil
    for _, a in ipairs(meta.actions) do
        if a.chatType then
            local lock = a.lock
            if a.concrete then
                snap = snap or NS.Situation.Current()
                lock = NS.Channels.LockState(a.concrete, snap)
            end
            if lock then locked[#locked + 1] = lock else open[#open + 1] = a end
        end
    end
    return open, locked
end

local function lockNotes(meta, locked)
    if not NS.Setting("behavior.dropNotes") then return end
    for _, lock in ipairs(locked) do
        local why = meta.lockText and meta.lockText(lock) or tostring(lock)
        NS.Print(L["%s may not have been sent. %s"]:format(tostring(meta.name), why))
    end
end

-- One entry per open chat action, all sharing one press, so the press reports one result (D7); with
-- none to await, "sent" at once (D16: the flash is not a confirmation).
local function track(meta, open, now)
    if not open[1] then
        result(meta, "sent")
        return
    end
    local p = { need = #open, got = 0, done = false }
    for _, a in ipairs(open) do G.Record(echoState(), now, a.chatType, meta, p, a.kind) end
    scheduleExpiry()
end

-- Why a Thank action is locked now, or nil: the whisper under the chat lockdown, the emote by the
-- game emote's own lock. Plain reads, safe in combat.
local function thankLock(a)
    if a.kind == "whisper" then
        return NS.Compat.InChatMessagingLockdown() and "whisperLockdown" or nil
    end
    return NS.Channels.LockState("gameEmote", NS.Situation.Current())
end

-- A Thank press (#19, spec §9 The Thank button): its own path, with no G.Decide and no lastSendAt
-- stamp, so a Thank click never marks the next pad press as guarded. Each locked action prints its
-- note and awaits no echo; each open one is one pending entry of the press, which reports one
-- result under the toast's key on the "thank" surface, a surface no pad or dial owns.
local function pressThank(b, meta)
    if not (b.qcArmed and hasActions(meta)) then return end
    local open, locked = {}, {}
    for _, a in ipairs(meta.actions) do
        local lock = thankLock(a)
        if lock then locked[#locked + 1] = lock else open[#open + 1] = a end
    end
    lockNotes(meta, locked)
    if #locked == #meta.actions then return end
    track(meta, open, GetTime())
    if b.qcOnPress then b.qcOnPress(b) end
end

-- The armed half of a press: the press-time notes, the lock notes, then one G.Decide, one lastSendAt
-- stamp and one qcOnPress for the open actions.
local function pressArmed(b, meta, notes)
    if not (b.qcArmed and hasActions(meta)) then return end
    -- Why a ping or a mark cannot land (D15): read in PreClick, before the macro ran, printed once;
    -- and why the press-time re-bake dropped the Line (CA-M2-3).
    printNotes(notes)
    if meta.lineNote then NS.Print(meta.lineNote) end
    -- A padlocked action stays in the armed macro (spec §8.4), but the game is expected to refuse it:
    -- it prints its note and awaits no echo. When every action is a locked chat action, no guard is
    -- stamped either, so a refusal is never blamed on the spam guard.
    local open, locked = chatActions(meta)
    lockNotes(meta, locked)
    if #locked == #meta.actions then return end
    local now = GetTime()
    local window = NS.Setting("behavior.spamGuard")
    local verdict = G.Decide(now, State.lastSendAt, window)
    State.lastSendAt = now
    if verdict == "guarded" then result(meta, "guarded") end
    track(meta, open, now)
    if b.qcOnPress then b.qcOnPress(b, verdict, window) end
end

-- The press (combined actions §4). One G.Decide, one lastSendAt stamp and one qcOnPress per press,
-- however many actions it has (D7).
local function press(b)
    local meta, notes = b.qcMeta, b.qcPressNotes
    b.qcPressNotes = nil
    if not meta or NS.IsStoodDown() then return end
    if meta.kind == "thank" then return pressThank(b, meta) end
    NS.Debug(TAG_S, "press %s on %s -> %s%s", tostring(meta.calloutId), tostring(meta.surfaceId),
        table.concat(meta.chatTypes or {}, "+"), b.qcArmed and "" or " (disarmed)")
    -- A previewed button or wedge (disarmed, spec §13.3) or a test placeholder: the line it would have
    -- sent, its tokens filled at the click (NS.Preview.FillEcho, QC-07), or why it would send
    -- nothing, printed locally and nothing more. No attribute is read or written, no guard stamped
    -- and no echo awaited, so a press in combat stays safe. It comes before the self line, so a
    -- previewed press prints what every action would do and never acts.
    if meta.echo then
        printEcho(meta.echo)
        return
    end
    -- The solo self line (the Line's "self" fallback): printed, and the press goes on only for the
    -- other actions that baked.
    if meta.selfText then
        NS.Print(meta.selfText)
        if not hasActions(meta) then return end
    end
    return pressArmed(b, meta, notes)
end

-- Whether this click edge is the one a press acts on. A catcher's forward clicks a wedge with its
-- place's name ("w3"): a left click, as the wedge's pre snippet takes it.
local function actingPress(b, mouseButton, down)
    if b.qcLeftOnly and mouseButton ~= "LeftButton" and not tostring(mouseButton):match("^w%d+$") then return false end
    return G.IsActingEdge(down, useKeyDown(b))
end

--- The OnClick hook every send button carries. Acts once per press, on the edge the secure
--- template acts on.
function SE.OnClick(b, mouseButton, down)
    if not actingPress(b, mouseButton, down) then return end
    local t0 = Perf.on and debugprofilestop()
    press(b)
    if t0 then Perf.Note("sendClick", debugprofilestop() - t0) end
end

local PING_NOTE = { off = L["%s: pings are turned off."], cooldown = L["%s: your ping is on cooldown."] }

local function markerNotes(out, name, C)
    local target = C.TargetExists()
    if target == false then
        out[#out + 1] = L["%s: no target to mark."]:format(name)
    elseif target and C.CanMark("target") == false then
        out[#out + 1] = L["%s: that target cannot be marked."]:format(name)
    end
    if C.MarkerRights() == "noRights" then
        out[#out + 1] = L["%s: you need leader or assist to mark in a raid."]:format(name)
    end
end

local function pingNotes(out, name, C)
    if C.TargetExists() == false then out[#out + 1] = L["%s: no target to ping."]:format(name) end
    local note = PING_NOTE[C.PingState()]
    if note then out[#out + 1] = note:format(name) end
end

--- Why a press's baked pings and marks cannot land (D15): no target, a target that cannot be marked,
--- no marking rights in a raid, pings off or cooling down. Plain Compat reads only, safe in combat;
--- an unknown (secret) answer gives no note. Reads, never writes an attribute.
--- @param meta table the button's meta (actions, name)
--- @return table|nil notes, each text named with meta.name; nil when there is nothing to say
function SE.PressNotes(meta)
    if not (meta and hasActions(meta)) then return nil end
    local C, name, out = NS.Compat, tostring(meta.name), {}
    for _, a in ipairs(meta.actions) do
        if a.kind == "ping" then pingNotes(out, name, C)
        elseif a.kind == "marker" then markerNotes(out, name, C) end
    end
    return out[1] and out or nil
end

--- The PreClick hook every send button carries, on the edge the secure template acts on. In and out
--- of combat it reads the press-time notes (before the macro runs, so a press's own ping never reads
--- as a cooldown); out of combat only, a re-baking button's line is re-armed with where you are.
function SE.PreClick(b, mouseButton, down)
    if not (b.qcMeta and actingPress(b, mouseButton, down)) then return end
    b.qcPressNotes = b.qcArmed and SE.PressNotes(b.qcMeta) or nil
    if inCombat() or not b.qcMeta.rebake then return end
    rebake(b)
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
    -- A channel line other than General's (/2 Trade, a custom channel) is never the echo (QF-04).
    if event == "CHAT_MSG_CHANNEL" and G.IsGeneralEcho(NS.Compat.PlainNumber((select(8, ...)))) == false then
        return
    end
    local t0 = Perf.on and debugprofilestop()
    -- A whisper's echo names the recipient as its sender: it is the player's own (D4).
    local fromMe = true
    if event ~= "CHAT_MSG_WHISPER_INFORM" then fromMe = NS.Compat.SenderIsPlayer(select(2, ...), select(12, ...)) end
    local hit = G.Match(e, G.CHAT_TYPE_BY_EVENT[event], GetTime(), fromMe)
    if hit and G.Settle(hit) then result(hit.meta, "sent") end
    if t0 then Perf.Note("echoMatch", debugprofilestop() - t0) end
end

-- Stood down, no echo can arrive: the timers are canceled and the presses forgotten.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    for handle in pairs(State.echoTimers or {}) do NS.addon:CancelTimer(handle) end
    State.echoTimers, State.sendEcho, State.lastSendAt = nil, nil, nil
end

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

-- Out of lockdown: drain the queue. On the edge into combat (Restrictions says combat while
-- InCombatLockdown() does not yet), re-arm the re-baking buttons once (QF-03).
local function onRestrictionChanged()
    if inCombat() then return end
    SE.Drain("RESTRICTION_CHANGED")
    if NS.Restrictions.InCombat() then SE.RefreshRebakes() end
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
