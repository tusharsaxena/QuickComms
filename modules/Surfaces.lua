local _, NS = ...
-- modules/Surfaces.lua — the surfaces' plans and their rebuild (spec §4.3, §7, §10).
--
-- THE PLAN (this half): for one pad and one snapshot, the active groups in the pad's own order
-- (Resolver, D6), one section per group (a built-in with children, the node battlegrounds, gives
-- one section per child), and one slot per callout: baked to its single macro line, or refused
-- with the reason its chip's tooltip shows (Bake, §8.3; §18 "a baked line fails validation"). A
-- locked slot keeps its line and carries the lock (§8.4). Library, Resolver and Bake are reached
-- through `deps`, so a test can hand in any snapshot. Test mode's plan is placeholder slots that
-- carry no line, drawn through the same render path (preview-mode).
--
-- THE EDGE (below): one entry point, Request, for everything that changes what a pad draws: the
-- situation, the library, the profile, test mode, a settings write and the stand-up. Out of combat
-- it rebuilds every enabled pad from the CURRENT snapshot at once; in combat it files one keyed
-- entry ("surfaces") in SendEngine's combat-end queue, shows each pad's stale hint and sends
-- SURFACE_REBUILT (id, true); the drain rebuilds from the snapshot as it is THEN, and
-- COMBAT_QUEUE_DRAINED clears the hints (spec §9.1, §18). A profile switch first drops the old
-- profile's rebuild and positions entries; a held drag's stop stays queued. RESTRICTION_CHANGED only re-reads the locks, the lockdown chip and the fade,
-- which are insecure and change in combat too. The stand-down hands the secure half (hide every
-- pad, disarm every chip) to SendEngine.Teardown, which holds it to combat end if need be.

NS.Surfaces = NS.Surfaces or {}
local S = NS.Surfaces
local L = NS.L
local Perf = NS.Perf

local ROLE = { TANK = L["Tank"], HEALER = L["Healer"], DAMAGER = L["Damage"] }

S.TEST_SECTIONS, S.TEST_SLOTS = 2, 4

--- A group's sections: itself, or one per child for a built-in with children.
--- @param groupOf function Library.Group
function S.Sections(groupId, groupOf)
    local g = groupOf(groupId)
    if not g then return {} end
    local out = {}
    if type(g.children) == "table" and #g.children > 0 then
        for _, child in ipairs(g.children) do
            local c = groupOf(child)
            if c then out[#out + 1] = { groupId = child, title = c.name, callouts = c.callouts or {} } end
        end
    else
        out[1] = { groupId = groupId, title = g.name, callouts = g.callouts or {} }
    end
    return out
end

--- One chip's slot: the baked line, or the reason there is none.
function S.Slot(calloutId, callout, snap, opts)
    local slot = { calloutId = calloutId }
    if type(callout) ~= "table" then
        slot.reason = "noCallout"
        return slot
    end
    slot.name, slot.icon = callout.name, callout.icon
    local line, reason, info = NS.Bake.Bake(callout, snap, opts)
    slot.line, slot.reason = line, reason
    slot.concrete, slot.lock = info.concrete, info.lock
    if line then slot.chatType = NS.Channels.ChatType(info.concrete) end
    if not line and reason == "solo" and info.selfPrint then slot.selfText = NS.Bake.Sanitize(callout.text) end
    return slot
end

--- The baked token values (spec §8.1), read out of combat.
function S.BakeContext(snap)
    snap = type(snap) == "table" and snap or {}
    local C = NS.Compat
    return {
        me = C.PlayerName(),
        spec = C.SpecName(),
        role = ROLE[snap.role],
        key = type(snap.keyLevel) == "number" and tostring(snap.keyLevel) or nil,
        dungeon = C.DungeonName(snap.challengeMapID),
        spellLink = C.SpellLink,
    }
end

--- Everything BuildPlan reads, from the live addon.
function S.Deps(snap)
    return {
        groups = NS.Library.AllGroups(),
        group = NS.Library.Group,
        callout = NS.Library.Callout,
        soloFallback = NS.Setting("behavior.soloFallback"),
        autoPromote = NS.Setting("behavior.autoPromote"),
        ctx = S.BakeContext(snap),
    }
end

--- One pad's plan.
--- @param pad table profile.pads[surfaceId]
--- @param snap table the situation snapshot
--- @param deps table from S.Deps (or a test)
--- @return table plan
function S.BuildPlan(surfaceId, pad, snap, deps)
    local t0 = Perf.on and debugprofilestop()
    local active = NS.Resolver.ActiveGroups(deps.groups, snap)
    local order = NS.Resolver.SurfaceOrder(pad and pad.groups, active, deps.groups, deps.autoPromote)
    local opts = { soloFallback = deps.soloFallback, ctx = deps.ctx }
    local plan = { surfaceId = surfaceId, snapshot = snap, order = order, sections = {},
        lockdownChip = false, hasActive = #order > 0 }
    for _, gid in ipairs(order) do
        for _, sec in ipairs(S.Sections(gid, deps.group)) do
            local slots = {}
            for _, cid in ipairs(sec.callouts) do
                local slot = S.Slot(cid, deps.callout(cid), snap, opts)
                slot.surfaceId = surfaceId
                if slot.lock == "lockdown" then plan.lockdownChip = true end
                slots[#slots + 1] = slot
            end
            plan.sections[#plan.sections + 1] = { groupId = sec.groupId, title = sec.title, slots = slots }
        end
    end
    if t0 then Perf.Note("bake.surface", debugprofilestop() - t0) end
    return plan
end

--- Test mode's plan: placeholder chips that send nothing (spec §10.4).
function S.TestPlan(surfaceId)
    local sections = {}
    for s = 1, S.TEST_SECTIONS do
        local slots = {}
        for i = 1, S.TEST_SLOTS do
            slots[i] = { calloutId = ("test.%d.%d"):format(s, i), surfaceId = surfaceId,
                name = L["Callout %d"]:format(i), reason = "testMode",
                concrete = (i % 2 == 1) and "party" or "raid" }
        end
        sections[s] = { groupId = "test." .. s, title = L["Test group %d"]:format(s), slots = slots }
    end
    return { surfaceId = surfaceId, snapshot = {}, order = {}, sections = sections, lockdownChip = false,
        hasActive = true, test = true }
end

-- ── the edge: one rebuild request, queued in combat (spec §9.1, §18) ────────────────────────

local State = NS.State
local TAG = "Pad"

local function enabledPadIds()
    local p = NS.db and NS.db.profile
    local out = {}
    if not p then return out end
    for _, id in ipairs(p.padOrder) do
        local pad = p.pads[id]
        if type(pad) == "table" and pad.enabled ~= false then out[#out + 1] = id end
    end
    return out
end

local function staleSet()
    State.surfaceStale = State.surfaceStale or {}
    return State.surfaceStale
end

function S.Plans()
    return State.surfacePlans or {}
end

--- Rebuild every enabled pad from the current snapshot. Out of combat (RunOrQueue's caller).
--- @return number pads rebuilt
function S.ApplyAll(reason)
    if NS.IsStoodDown() or not State.situation then return 0 end
    local snap = NS.Situation.Current()
    local deps = S.Deps(snap)
    local test = NS.Preview.IsTestMode()
    local pads = NS.db.profile.pads
    local plans, n = {}, 0
    State.surfaceOrder = State.surfaceOrder or {}
    for _, id in ipairs(enabledPadIds()) do
        local plan = test and S.TestPlan(id) or S.BuildPlan(id, pads[id], snap, deps)
        plans[id] = plan
        n = n + 1
        local sig = table.concat(plan.order, ",")
        if sig ~= State.surfaceOrder[id] then
            State.surfaceOrder[id] = sig
            NS.addon:SendMessage(NS.MSG.ACTIVE_GROUPS_CHANGED, id)
        end
    end
    State.surfacePlans = plans
    local stale = staleSet()
    for id in pairs(stale) do stale[id] = nil end
    NS.Pad.Sync(plans)
    for id in pairs(plans) do NS.addon:SendMessage(NS.MSG.SURFACE_REBUILT, id, false) end
    NS.Debug(TAG, "rebuilt %s pad(s) (%s)", n, tostring(reason))
    return n
end

--- Ask for a rebuild: now, or at the end of combat with the stale hint showing meanwhile.
--- Nothing is built before the first situation read, or while stood down.
--- @return boolean ranNow
function S.Request(reason)
    if NS.IsStoodDown() or not State.situation then return false end
    if NS.SendEngine.RunOrQueue("surfaces", function() S.ApplyAll(reason) end) then return true end
    local stale = staleSet()
    for _, id in ipairs(NS.Pad.Ids()) do
        if not stale[id] then
            stale[id] = true
            NS.Pad.SetStale(id, true)
            NS.addon:SendMessage(NS.MSG.SURFACE_REBUILT, id, true)
        end
    end
    NS.Debug(TAG, "rebuild held for combat (%s)", tostring(reason))
    return false
end

--- Re-read every slot's lock (spec §8.4), the lockdown chip and the fade. Insecure: runs in combat.
function S.RefreshLocks()
    local plans = State.surfacePlans
    if not plans then return end
    NS.Situation.Restamp()
    local snap = NS.Situation.Current()
    local showChip = NS.Setting("behavior.lockdownChip") ~= false
    for id, plan in pairs(plans) do
        if not plan.test then
            plan.lockdownChip = false
            for _, sec in ipairs(plan.sections) do
                for _, slot in ipairs(sec.slots) do
                    if slot.concrete then slot.lock = NS.Channels.LockState(slot.concrete, snap) end
                    if slot.lock == "lockdown" then plan.lockdownChip = true end
                end
            end
            NS.Pad.RefreshLocks(id, plan.lockdownChip and showChip)
        end
        NS.Pad.ApplyAlpha(id)
    end
end

local function onDrained()
    local stale = State.surfaceStale
    if not stale then return end
    for id in pairs(stale) do
        stale[id] = nil
        NS.Pad.SetStale(id, false)
    end
end

local function onProfileChanged()
    NS.SendEngine.Drop("profile", { "surfaces", "positions" })
    State.surfaceOrder = nil
    S.Request("profile")
end

local HANDLERS = {
    { NS.MSG.SITUATION_CHANGED, function() S.Request("situation") end },
    { NS.MSG.LIBRARY_CHANGED, function() S.Request("library") end },
    { NS.MSG.TEST_MODE_CHANGED, function() S.Request("testMode") end },
    { NS.MSG.PROFILE_CHANGED, onProfileChanged },
    { NS.MSG.RESTRICTION_CHANGED, function() S.RefreshLocks() end },
    { NS.MSG.COMBAT_QUEUE_DRAINED, onDrained },
}

-- Its own target (core/Bus.lua); one target holds several different messages.
local receiver
local function listen()
    receiver = receiver or NS.Bus:NewTarget()
    if not receiver then return end
    for _, h in ipairs(HANDLERS) do receiver:RegisterMessage(h[1], h[2]) end
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    State.surfacePlans, State.surfaceOrder, State.surfaceStale = nil, nil, nil
    NS.SendEngine.Teardown(function() NS.Pad.HideAll() end)
    if receiver and not NS.Bus.tracked then
        for _, h in ipairs(HANDLERS) do receiver:UnregisterMessage(h[1]) end
    end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
    S.Request("standUp")
end
