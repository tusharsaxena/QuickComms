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
