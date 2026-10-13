local _, NS = ...
-- modules/Surfaces.lua — the surfaces' plans and their rebuild (spec §4.3, §7, §10).
--
-- THE PLAN (this half): for one pad and one snapshot, the active groups in the pad's own order
-- (Resolver, D6), one section per group (a built-in with children, the node battlegrounds, gives
-- one section per child), and one slot per callout: baked to its single macro line, or refused
-- with the reason its chip's tooltip shows (Bake, §8.3; §18 "a baked line fails validation"). A
-- locked slot keeps its line and carries the lock (§8.4). Library, Resolver and Bake are reached
-- through `deps`, so a test can hand in any snapshot. Test mode's plan is placeholder slots that
-- carry no line, drawn through the same render path (preview-mode). A "Preview as…" plan is a real
-- plan for the previewed snapshot, marked so every chip is disarmed (spec §13.3).
--
-- A Comms Dial's plan (spec §11) is the same resolve and bake in rings: its active groups in its
-- order, a node set's children as nodes, each slot baked, then modules/Dial_Layout.lua's Rings.
--
-- THE EDGE (below): one entry point, Request, for everything that changes what a pad or a dial
-- draws: the situation, the library, the profile, test mode, a settings write and the stand-up. Out
-- of combat it rebuilds every enabled pad and dial from the CURRENT snapshot at once (the dials'
-- rebuild also re-binds their keys); in combat it files one keyed entry ("surfaces") in
-- SendEngine's combat-end queue, shows each pad's and dial hub's stale hint and sends
-- SURFACE_REBUILT (id, true); the drain rebuilds from the snapshot as it is THEN, and
-- COMBAT_QUEUE_DRAINED clears the hints (spec §9.1, §18). A profile switch first drops the old
-- profile's rebuild and positions entries; a held drag's stop stays queued. RESTRICTION_CHANGED only
-- re-reads the locks, the lockdown chip and the fade, which are insecure and change in combat too.
-- The stand-down hands the secure half (hide every pad, release every dial, disarm every send
-- button, unbind every key) to SendEngine.Teardown, which holds it to combat end if need be.

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

--- The baked token values (spec §8.1), read out of combat. A previewed dungeon has no challenge map
--- id; its {dungeon} is the name the preview carries.
function S.BakeContext(snap)
    snap = type(snap) == "table" and snap or {}
    local C = NS.Compat
    return {
        me = C.PlayerName(),
        spec = C.SpecName(),
        role = ROLE[snap.role],
        key = type(snap.keyLevel) == "number" and tostring(snap.keyLevel) or nil,
        dungeon = C.DungeonName(snap.challengeMapID) or snap.previewDungeon,
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
        lockdownChip = false, hasActive = #order > 0, active = active }
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

-- Test mode's placeholder slots for one section or group: they carry no line and send nothing.
local function testSlots(surfaceId, s)
    local slots = {}
    for i = 1, S.TEST_SLOTS do
        slots[i] = { calloutId = ("test.%d.%d"):format(s, i), surfaceId = surfaceId,
            name = L["Callout %d"]:format(i), reason = "testMode",
            concrete = (i % 2 == 1) and "party" or "raid" }
    end
    return slots
end

--- Test mode's plan: placeholder chips that send nothing (spec §10.4).
function S.TestPlan(surfaceId)
    local sections = {}
    for s = 1, S.TEST_SECTIONS do
        sections[s] = { groupId = "test." .. s, title = L["Test group %d"]:format(s), slots = testSlots(surfaceId, s) }
    end
    return { surfaceId = surfaceId, snapshot = {}, order = {}, sections = sections, lockdownChip = false,
        hasActive = true, test = true }
end

--- Test mode's dial plan: placeholder groups and wedges that send nothing, laid out as the dial's own
--- (spec §11.4: test mode shows dial 1 open).
function S.TestDialPlan(surfaceId, dial)
    dial = type(dial) == "table" and dial or {}
    local groups = {}
    for s = 1, S.TEST_SECTIONS do
        groups[s] = { id = "test." .. s, title = L["Test group %d"]:format(s), slots = testSlots(surfaceId, s) }
    end
    local rings, open = NS.DialLayout.Rings(groups, { mode = dial.mode, slices = dial.slices, title = dial.name })
    return { kind = "dial", surfaceId = surfaceId, snapshot = {}, order = {}, rings = rings, openRing = open,
        lockdownChip = false, hasActive = true, test = true }
end

--- A "Preview as…" plan (spec §13.3): drawn like test mode (always shown, the header says so) but from
--- the groups the previewed snapshot resolves to. Every slot keeps its line for the tooltip and is
--- disarmed by the pad, so a previewed chip sends nothing.
function S.MarkPreview(plan, key)
    plan.test, plan.preview = true, key
    S.EachSlot(plan, function(slot) slot.preview = true end)
    return plan
end

--- Every slot of a pad's plan (its sections) or a dial's (its rings' callout items).
function S.EachSlot(plan, fn)
    for _, sec in ipairs(plan.sections or {}) do
        for _, slot in ipairs(sec.slots) do fn(slot) end
    end
    for _, ring in ipairs(plan.rings or {}) do
        for _, item in ipairs(ring.items) do
            if item.slot then fn(item.slot) end
        end
    end
end

--- One dial's plan (spec §11): its active groups in its order (D6), a node set's children as nodes,
--- each slot baked, then the rings (Dial_Layout.Rings, Categories or Flat, open-into, pages).
--- @param dial table profile.dials[surfaceId]
--- @return table plan
function S.BuildDialPlan(surfaceId, dial, snap, deps)
    local t0 = Perf.on and debugprofilestop()
    dial = type(dial) == "table" and dial or {}
    local active = NS.Resolver.ActiveGroups(deps.groups, snap)
    local order = NS.Resolver.SurfaceOrder(dial.groups, active, deps.groups, deps.autoPromote)
    local opts = { soloFallback = deps.soloFallback, ctx = deps.ctx }
    local plan = { kind = "dial", surfaceId = surfaceId, snapshot = snap, order = order, active = active,
        lockdownChip = false, hasActive = #order > 0 }
    local function slotsOf(ids)
        local out = {}
        for _, cid in ipairs(ids or {}) do
            local slot = S.Slot(cid, deps.callout(cid), snap, opts)
            slot.surfaceId = surfaceId
            if slot.lock == "lockdown" then plan.lockdownChip = true end
            out[#out + 1] = slot
        end
        return out
    end
    local groups = {}
    for _, gid in ipairs(order) do
        local g = deps.group(gid)
        local entry = { id = gid, title = g.name, icon = g.icon, openInto = g.openInto == true }
        if type(g.children) == "table" and #g.children > 0 then
            entry.children = {}
            for _, child in ipairs(g.children) do
                local c = deps.group(child)
                if c then
                    entry.children[#entry.children + 1] = { id = child, title = c.name, icon = c.icon,
                        slots = slotsOf(c.callouts) }
                end
            end
        else
            entry.slots = slotsOf(g.callouts)
        end
        groups[#groups + 1] = entry
    end
    plan.rings, plan.openRing = NS.DialLayout.Rings(groups, { mode = dial.mode, slices = dial.slices, title = dial.name })
    if t0 then Perf.Note("bake.surface", debugprofilestop() - t0) end
    return plan
end

--- "Why is this showing?" for one pad or dial (spec §13.3): the groups it shows, in priority order,
--- each with the When rows that matched (Resolver.Explain), then every lock in effect on its slots.
--- Read from the last plan, so in combat it explains what is on screen.
--- @return string[]
function S.WhyLines(id)
    local plan = S.Plans()[id] or S.DialPlans()[id]
    if not plan then
        local p = NS.db and NS.db.profile
        if p and p.dials[id] then return { L["This dial has not been built yet."] } end
        return { L["This pad has not been built yet."] }
    end
    if plan.test and not plan.preview then
        if plan.kind == "dial" then return { L["Test mode: placeholder wedges that send nothing."] } end
        return { L["Test mode: placeholder chips that send nothing."] }
    end
    local out = {}
    if plan.preview then out[1] = L["Preview as: %s"]:format(NS.Preview.Label(plan.preview)) end
    if #plan.order == 0 then out[#out + 1] = L["No group matches this situation."] end
    for _, gid in ipairs(plan.order) do
        local g = NS.Library.Group(gid)
        local name = g and g.name or gid
        if NS.Library.IsBuiltin(gid) then name = L["%s (built-in)"]:format(name) end
        out[#out + 1] = NS.Resolver.Explain(name, plan.active and plan.active[gid])
    end
    local locks, seen = {}, {}
    S.EachSlot(plan, function(slot)
        if slot.lock and not seen[slot.lock] then
            seen[slot.lock] = true
            locks[#locks + 1] = slot.lock
        end
    end)
    table.sort(locks)
    for _, lock in ipairs(locks) do out[#out + 1] = NS.PadRender.LOCK_TEXT[lock] or tostring(lock) end
    return out
end

-- ── the edge: one rebuild request, queued in combat (spec §9.1, §18) ────────────────────────

local State = NS.State
local TAG = "Pad"

-- The enabled pads, or dials, in their order.
local function enabledIds(kind)
    local p = NS.db and NS.db.profile
    local out = {}
    if not p then return out end
    local set = kind == "pad" and p.pads or p.dials
    for _, id in ipairs(kind == "pad" and p.padOrder or p.dialOrder) do
        local s = set[id]
        if type(s) == "table" and s.enabled ~= false then out[#out + 1] = id end
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

function S.DialPlans()
    return State.dialPlans or {}
end

--- Rebuild every enabled pad and dial from the current snapshot, and re-bind the dials' keys. Out of
--- combat (RunOrQueue's caller).
--- @return number surfaces rebuilt
function S.ApplyAll(reason)
    if NS.IsStoodDown() or not State.situation then return 0 end
    local preview = NS.Preview.PreviewSnapshot()
    local snap = preview or NS.Situation.Current()
    local deps = S.Deps(snap)
    local test = preview == nil and NS.Preview.IsTestMode()
    local p = NS.db.profile
    local plans, dialPlans, n = {}, {}, 0
    State.surfaceOrder = State.surfaceOrder or {}
    local function done(id, plan)
        if preview then S.MarkPreview(plan, NS.Preview.PreviewAs()) end
        n = n + 1
        local sig = table.concat(plan.order, ",")
        if sig ~= State.surfaceOrder[id] then
            State.surfaceOrder[id] = sig
            NS.addon:SendMessage(NS.MSG.ACTIVE_GROUPS_CHANGED, id)
        end
        return plan
    end
    for _, id in ipairs(enabledIds("pad")) do
        plans[id] = done(id, test and S.TestPlan(id) or S.BuildPlan(id, p.pads[id], snap, deps))
    end
    for _, id in ipairs(enabledIds("dial")) do
        dialPlans[id] = done(id, test and S.TestDialPlan(id, p.dials[id]) or S.BuildDialPlan(id, p.dials[id], snap, deps))
    end
    State.surfacePlans, State.dialPlans = plans, dialPlans
    local stale = staleSet()
    for id in pairs(stale) do stale[id] = nil end
    NS.Pad.Sync(plans)
    NS.Dial.Sync(dialPlans, p.dialOrder)
    for _, id in ipairs(enabledIds("pad")) do NS.addon:SendMessage(NS.MSG.SURFACE_REBUILT, id, false) end
    for _, id in ipairs(enabledIds("dial")) do NS.addon:SendMessage(NS.MSG.SURFACE_REBUILT, id, false) end
    NS.Debug(TAG, "rebuilt %s surface(s) (%s)", n, tostring(reason))
    return n
end

--- Ask for a rebuild: now, or at the end of combat with the stale hint showing meanwhile.
--- Nothing is built before the first situation read, or while stood down.
--- @return boolean ranNow
function S.Request(reason)
    if NS.IsStoodDown() or not State.situation then return false end
    if NS.SendEngine.RunOrQueue("surfaces", function() S.ApplyAll(reason) end) then return true end
    local stale = staleSet()
    local function mark(ids, setStale)
        for _, id in ipairs(ids) do
            if not stale[id] then
                stale[id] = true
                setStale(id, true)
                NS.addon:SendMessage(NS.MSG.SURFACE_REBUILT, id, true)
            end
        end
    end
    mark(NS.Pad.Ids(), NS.Pad.SetStale)
    mark(NS.Dial.Ids(), NS.Dial.SetStale)
    NS.Debug(TAG, "rebuild held for combat (%s)", tostring(reason))
    return false
end

--- Re-read every slot's lock (spec §8.4), the lockdown chip and the pads' fade. Insecure: runs in combat.
function S.RefreshLocks()
    local plans, dialPlans = State.surfacePlans, State.dialPlans
    if not (plans or dialPlans) then return end
    NS.Situation.Restamp()
    local snap = NS.Situation.Current()
    local showChip = NS.Setting("behavior.lockdownChip") ~= false
    local function relock(plan)
        if plan.test then return false end
        plan.lockdownChip = false
        S.EachSlot(plan, function(slot)
            if slot.concrete then slot.lock = NS.Channels.LockState(slot.concrete, snap) end
            if slot.lock == "lockdown" then plan.lockdownChip = true end
        end)
        return true
    end
    for id, plan in pairs(plans or {}) do
        if relock(plan) then NS.Pad.RefreshLocks(id, plan.lockdownChip and showChip) end
        NS.Pad.ApplyAlpha(id)
    end
    for id, plan in pairs(dialPlans or {}) do
        if relock(plan) then NS.Dial.RefreshLocks(id, plan.lockdownChip and showChip) end
    end
end

--- Master controls' Reset position (spec §10.4): every pad and every dial back to its default place.
function S.ResetPositions()
    NS.Pad.ResetPositions(true)
    NS.Dial.ResetPositions()
    NS.Print(L["Pad and dial positions reset."])
end

local function onDrained()
    local stale = State.surfaceStale
    if not stale then return end
    for id in pairs(stale) do
        stale[id] = nil
        NS.Pad.SetStale(id, false)
        NS.Dial.SetStale(id, false)
    end
end

local function onProfileChanged()
    NS.SendEngine.Drop("profile", { "surfaces", "positions", "dialPositions" })
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
    State.surfacePlans, State.dialPlans, State.surfaceOrder, State.surfaceStale = nil, nil, nil, nil
    NS.SendEngine.Teardown(function()
        NS.Pad.HideAll()
        NS.Dial.HideAll()
    end)
    if receiver and not NS.Bus.tracked then
        for _, h in ipairs(HANDLERS) do receiver:UnregisterMessage(h[1]) end
    end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
    S.Request("standUp")
end
