local _, NS = ...
-- modules/SendEngine.lua — THE ONLY SECURE WRITER (spec §9, events-frames-taint-§2/§4). It alone
-- creates frames from a Secure* template, calls SetAttribute and registers or unregisters state
-- drivers; tests/test_sendengine.lua greps every other shipped file for those calls. Every write is
-- made out of combat. A caller asks through RunOrQueue, which runs the work now or, in combat
-- (InCombatLockdown(), never UnitAffectingCombat), files it under a key in the combat-end queue,
-- replacing an earlier entry under that key. The queue drains when RESTRICTION_CHANGED says the
-- combat edge has passed and InCombatLockdown() agrees (Restrictions owns PLAYER_REGEN_*), then
-- COMBAT_QUEUE_DRAINED (count) is sent. Drop empties it on stand-down and on a profile switch.
--
-- Send buttons (spec §9.1): SecureActionButtonTemplate, RegisterForClicks("AnyUp", "AnyDown") as the
-- go/no-go test needed for type=macro, named QuickCommsSend<n>. Arm writes type=macro and the baked
-- line as macrotext; Disarm writes both to nil and never calls :Disable() (the WhatGroup pattern).
-- Frames are never destroyed: the pads reuse them through NS.Pool. The shapes are ConsumableMaster's:
-- modules/MacroBarButton.lua `BB.Create` (built once, out of combat), modules/MacroManager.lua
-- `queueForCombat` / `M.FlushPending` (a keyed, last-write-wins queue flushed after combat), and
-- core/LifecycleSetup.lua `standDown` for the held teardown below.
--
-- Stand-down (spec §9.5, slash-commands-§7): Teardown(fn) runs the secure half now or, in combat,
-- holds it in the one registration a disabled addon may keep: a private AceEvent target listening
-- for PLAYER_REGEN_ENABLED, released the moment it fires. Its own target, because AceEvent keys a
-- handler by (event, object) and Restrictions holds PLAYER_REGEN_ENABLED on NS.addon.

NS.SendEngine = NS.SendEngine or {}
local SE = NS.SendEngine
local G = NS.SendGuard
local State = NS.State
local L = NS.L

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
--- @param parent table the frame it belongs to (a pad's root)
--- @param onPress function|nil onPress(button, verdict, window), called by the click hook
--- @return table|nil
function SE.NewButton(parent, onPress)
    if inCombat() then
        NS.Debug(TAG_S, "button refused: in combat")
        return nil
    end
    seq = seq + 1
    local b = CreateFrame("Button", "QuickCommsSend" .. seq, parent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
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

--- Forget every queued entry (stand-down, profile switch).
--- @return number dropped
function SE.Drop(reason)
    local q = State.sendQueue
    local n = q and G.Count(q) or 0
    State.sendQueue = nil
    if n > 0 then NS.Debug(TAG_Q, "dropped %s (%s)", n, tostring(reason)) end
    return n
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

--- Run the secure half of a stand-down now, or hold it until combat ends.
--- @return boolean ranNow
function SE.Teardown(fn)
    if not inCombat() then
        fn()
        return true
    end
    State.pendingTeardown = fn
    pending = pending or LibStub("AceEvent-3.0"):Embed({})
    pending:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        releasePending()
        local held = State.pendingTeardown
        State.pendingTeardown = nil
        if held then held() end
        NS.Debug(TAG_Q, "held stand-down finished")
    end)
    NS.Debug(TAG_Q, "stand-down held until combat ends")
    return false
end

--- A stand-up while a stand-down is held: the held half must not run any more.
function SE.CancelTeardown()
    if State.pendingTeardown == nil then return end
    State.pendingTeardown = nil
    releasePending()
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
