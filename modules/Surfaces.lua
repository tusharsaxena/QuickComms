local _, NS = ...
-- modules/Surfaces.lua — the surfaces' plans and their rebuild (spec §4.3, §7, §10).
--
-- THE PLAN (this half): for one pad and one snapshot, the active groups in the pad's own order
-- (Resolver, D6), one section per group (a parent, a seeded battleground's set among them, gives
-- its own callouts' section when it has any, then one section per child whose When matches; the
-- parent's When gates the whole), and one slot per callout: baked to its single macro line, or refused
-- with the reason its button's tooltip shows (Bake, §8.3; §18 "a baked line fails validation"). A
-- locked slot keeps its line and carries the lock (§8.4). Library, Resolver and Bake are reached
-- through `deps`, so a test can hand in any snapshot. Test mode's plan is placeholder slots that
-- carry no line, drawn through the same render path (preview-mode): four groups of 4, 8, 12 and 16
-- (owner, 2026-10-21), each slot wearing a shipped callout's name and icon, read from the seed table
-- (NS.BuiltIns), never from or into the profile. A "Preview as…" plan is a real
-- plan for the previewed snapshot, marked so every button is disarmed (spec §13.3). An edit preview's
-- plan (`deps.only`, the group the Groups page edits) skips the Resolver: that group alone, with
-- every group inside it, whatever their When, marked and disarmed the same way.
--
-- A Comms Dial's plan (spec §11) is the same resolve and bake in rings: its active groups in its
-- order, a group's children as nodes (each gated by its own When, as on a pad), each slot baked, then
-- modules/Dial_Layout.lua's Rings.
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

S.TEST_COUNTS = { 4, 8, 12, 16 }   -- test mode's groups, by how many callouts each holds

-- A group's children: `opts.children` (Library.Children) when given, else the group's own
-- `children` list (a test's hand-made group).
local function childrenOf(groupId, g, opts)
    if opts and opts.children then return opts.children(groupId) end
    return type(g.children) == "table" and g.children or {}
end

-- Whether a child shows: always without `opts.active`; else a child the Resolver judged (one of
-- `opts.groups`, a user group) only while it is active, its own When and Enabled. A child the
-- Resolver was not handed (a test's hand-made group) always shows.
local function childShown(child, opts)
    if not (opts and opts.active) then return true end
    if not (opts.groups and opts.groups[child]) then return true end
    return opts.active[child] ~= nil
end

--- A group's sections: itself; or, for a group with children, its own callouts' section when it has
--- any, then one per child that shows (childShown), each naming its parent (`parentId`: a grid pad
--- sets a parent's small child sections side by side, Pad_Layout).
--- @param groupOf function Library.Group
--- @param opts table|nil { children = Library.Children, active = Resolver.ActiveGroups' answer,
--- groups = the Resolver's input }
function S.Sections(groupId, groupOf, opts)
    local g = groupOf(groupId)
    if not g then return {} end
    local own = { groupId = groupId, title = g.name, callouts = g.callouts or {} }
    local kids = childrenOf(groupId, g, opts)
    if #kids == 0 then return { own } end
    local out = {}
    if #own.callouts > 0 then out[1] = own end
    for _, child in ipairs(kids) do
        local c = childShown(child, opts) and groupOf(child)
        if c then out[#out + 1] = { groupId = child, title = c.name, callouts = c.callouts or {}, parentId = groupId } end
    end
    return out
end

--- One button's slot: the baked line, or the reason there is none.
function S.Slot(calloutId, callout, snap, opts)
    local slot = { calloutId = calloutId }
    if type(callout) ~= "table" then
        slot.reason = "noCallout"
        return slot
    end
    slot.name, slot.icon, slot.iconColor = callout.name, callout.icon, callout.iconColor
    local line, reason, info = NS.Bake.Bake(callout, snap, opts)
    slot.line, slot.reason = line, reason
    slot.concrete, slot.lock = info.concrete, info.lock
    if line then slot.chatType = NS.Channels.ChatType(info.concrete) end
    if not line and reason == "solo" and info.selfPrint then slot.selfText = NS.Bake.Sanitize(callout.text) end
    -- {coordinates} moves while the plan does not (QF-03): the slot's line, re-baked with the position
    -- as it is now, for SendEngine's press-time re-bake. Pad's arm hands it on only for an armed live
    -- slot. Nil when the line does not bake (over 255 bytes): the button keeps what it holds.
    if line and NS.Tokens.UsesCoordinates(callout.text) then
        opts = type(opts) == "table" and opts or {}
        local base = type(opts.ctx) == "table" and opts.ctx or {}
        slot.rebake = function()
            local ctx = {}
            for k, v in pairs(base) do ctx[k] = v end
            ctx.coordinates = NS.Compat.Coordinates()
            return (NS.Bake.Bake(callout, snap, { soloFallback = opts.soloFallback, ctx = ctx }))
        end
    end
    return slot
end

--- The baked token values (spec §8.1), read out of combat. A previewed dungeon has no challenge map
--- id; its {dungeon} is the name the preview carries. {coordinates} is your position, for the live
--- snapshot only, known by identity (QF-03): Preview as Current answers that same table
--- (Preview.PreviewSnapshot), and so does the edit preview of a group with no content
--- (Preview.EditSnapshot); a synthetic preset's snapshot is not where you are, so it has none.
function S.BakeContext(snap)
    local liveSnap = snap ~= nil and snap == NS.Situation.Current()
    snap = type(snap) == "table" and snap or {}
    local C = NS.Compat
    return {
        me = C.PlayerName(),
        spec = C.SpecName(),
        role = ROLE[snap.role],
        key = type(snap.keyLevel) == "number" and tostring(snap.keyLevel) or nil,
        dungeon = C.DungeonName(snap.challengeMapID) or snap.previewDungeon,
        coordinates = liveSnap and C.Coordinates() or nil,
        spellLink = C.SpellLink,
    }
end

--- Everything BuildPlan reads, from the live addon.
function S.Deps(snap)
    return {
        groups = NS.Library.AllGroups(),
        group = NS.Library.Group,
        children = NS.Library.Children,
        callout = NS.Library.Callout,
        soloFallback = NS.Setting("behavior.soloFallback"),
        autoPromote = NS.Setting("behavior.autoPromote"),
        ctx = S.BakeContext(snap),
    }
end

-- A surface's active groups and its order of them (spec §7), bracketed as resolverResolve inside
-- bakeSurface (spec §16), and gated as bakeSurface is: an editor's look at a plan
-- (deps.unmeasured, settings/Dials.lua) notes neither, because a child noted under a parent that was
-- never noted would skew performance-§3's within-parent figures.
local function resolve(list, snap, deps)
    -- An edit preview: the one group, judged by nobody (no active set, so every child shows).
    if deps.only then return nil, { deps.only } end
    local t0 = Perf.on and not deps.unmeasured and debugprofilestop()
    local active = NS.Resolver.ActiveGroups(deps.groups, snap)
    local order = NS.Resolver.SurfaceOrder(list, active, deps.groups, deps.autoPromote)
    if t0 then Perf.Note("resolverResolve", debugprofilestop() - t0, "bakeSurface") end
    return active, order
end

--- One pad's plan.
--- @param pad table profile.pads[surfaceId]
--- @param snap table the situation snapshot
--- @param deps table from S.Deps (or a test)
--- @return table plan
function S.BuildPlan(surfaceId, pad, snap, deps)
    local t0 = Perf.on and debugprofilestop()
    local active, order = resolve(pad and pad.groups, snap, deps)
    local opts = { soloFallback = deps.soloFallback, ctx = deps.ctx }
    local plan = { surfaceId = surfaceId, snapshot = snap, order = order, sections = {},
        lockdownChip = false, hasActive = false, active = active }
    local nest = { children = deps.children, active = active, groups = deps.groups }
    for _, gid in ipairs(order) do
        for _, sec in ipairs(S.Sections(gid, deps.group, nest)) do
            local slots = {}
            for _, cid in ipairs(sec.callouts) do
                local slot = S.Slot(cid, deps.callout(cid), snap, opts)
                slot.surfaceId = surfaceId
                if slot.lock == "lockdown" then plan.lockdownChip = true end
                slots[#slots + 1] = slot
            end
            plan.sections[#plan.sections + 1] = { groupId = sec.groupId, title = sec.title, slots = slots,
                parentId = sec.parentId }
        end
    end
    -- What is drawn, not what is active: a parent with no callouts of its own whose children all
    -- fail their When is in the order and yields no section, and a "whenActive" pad hides for it.
    plan.hasActive = #plan.sections > 0
    if t0 then Perf.Note("bakeSurface", debugprofilestop() - t0) end
    return plan
end

-- The shipped callouts in the seed table's order (each top-level set's own, then its children's,
-- depth first), each name once: what test mode's placeholders wear. Read only; built once.
local samples
local function testSamples()
    if samples then return samples end
    samples = {}
    local BI, seen = NS.BuiltIns or {}, {}
    local function walk(id)
        local g = BI.groups and BI.groups[id]
        if type(g) ~= "table" then return end
        for _, cid in ipairs(g.callouts or {}) do
            local c = BI.callouts[cid]
            if c and c.name and not seen[c.name] then
                seen[c.name] = true
                samples[#samples + 1] = c
            end
        end
        for _, child in ipairs(g.children or {}) do walk(child) end
    end
    for _, id in ipairs(BI.order or {}) do walk(id) end
    return samples
end

-- Test mode's placeholder slots for group s: they carry no line and send nothing. Each wears the
-- next shipped callout's name and icon (group 1 the first four, group 2 the next eight, and so on);
-- past the seed table's end, "Callout N" with no icon.
local function testSlots(surfaceId, s)
    local pool, first = testSamples(), 0
    for k = 1, s - 1 do first = first + S.TEST_COUNTS[k] end
    local slots = {}
    for i = 1, S.TEST_COUNTS[s] do
        local c = pool[first + i]
        slots[i] = { calloutId = ("test.%d.%d"):format(s, i), surfaceId = surfaceId,
            name = c and c.name or L["Callout %d"]:format(i), icon = c and c.icon, iconColor = c and c.iconColor,
            reason = "testMode", concrete = (i % 2 == 1) and "party" or "raid" }
        slots[i].echo = NS.Preview.TestEcho(slots[i].name)
    end
    return slots
end

--- Test mode's plan: placeholder buttons that send nothing (spec §10.4), in four groups.
function S.TestPlan(surfaceId)
    local sections = {}
    for s = 1, #S.TEST_COUNTS do
        sections[s] = { groupId = "test." .. s, title = L["Test group %d"]:format(s), slots = testSlots(surfaceId, s) }
    end
    return { surfaceId = surfaceId, snapshot = {}, order = {}, sections = sections, lockdownChip = false,
        hasActive = true, test = true }
end

-- What Auto's icon fit reads off a dial (Dial_Layout.AutoCap, dial polish): its radius, Icon offset,
-- icon size (0 or unset: automatic, Dial_Layout.ResolveIconSize), Slice gap and Hub size.
local function dialFit(dial)
    local icon, slice = type(dial.icon) == "table" and dial.icon or {}, type(dial.slice) == "table" and dial.slice or {}
    local hub = type(dial.hub) == "table" and tonumber(dial.hub.size) or nil
    local gap = slice.gap or 0
    return { radius = dial.radius, iconOffset = dial.iconOffset, gap = gap, hub = hub,
        iconSize = NS.DialLayout.ResolveIconSize(icon.size, dial.radius, hub, dial.slices, gap) }
end

--- Test mode's dial plan: placeholder groups and wedges that send nothing, laid out as the dial's own
--- (spec §11.4: test mode shows dial 1 open).
function S.TestDialPlan(surfaceId, dial)
    dial = type(dial) == "table" and dial or {}
    local groups = {}
    for s = 1, #S.TEST_COUNTS do
        groups[s] = { id = "test." .. s, title = L["Test group %d"]:format(s), slots = testSlots(surfaceId, s) }
    end
    local rings, open = NS.DialLayout.Rings(groups, { mode = dial.mode, slices = dial.slices, title = dial.name,
        fit = dialFit(dial) })
    return { kind = "dial", surfaceId = surfaceId, snapshot = {}, order = {}, rings = rings, openRing = open,
        radius = NS.DialLayout.ClampRadius(dial.radius), lockdownChip = false, hasActive = true, test = true }
end

--- A "Preview as…" plan (spec §13.3): drawn like test mode (always shown, the header says so) but from
--- the groups the previewed snapshot resolves to. Every slot keeps its line for the tooltip and is
--- disarmed by the pad, so a previewed button sends nothing; its click prints its `echo` (QC-07,
--- NS.Preview.SlotEcho: the line with missing tokens mocked, or why it sends nothing).
function S.MarkPreview(plan, key)
    plan.test, plan.preview = true, key
    S.EachSlot(plan, function(slot)
        slot.preview = true
        slot.echo = NS.Preview.SlotEcho(slot, NS.Library.Callout(slot.calloutId), plan.snapshot)
    end)
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

--- One dial's plan (spec §11): its active groups in its order (D6), a group's children as nodes
--- (each one that shows, childShown) after its own callouts, each slot baked, then the rings
--- (Dial_Layout.Rings, Categories or Flat, a lone group opened into, pages).
--- @param dial table profile.dials[surfaceId]
--- @return table plan
function S.BuildDialPlan(surfaceId, dial, snap, deps)
    -- deps.unmeasured: an editor's look at a plan (settings/Dials.lua), not a surface's bake.
    local t0 = Perf.on and not deps.unmeasured and debugprofilestop()
    dial = type(dial) == "table" and dial or {}
    local active, order = resolve(dial.groups, snap, deps)
    local opts = { soloFallback = deps.soloFallback, ctx = deps.ctx }
    local plan = { kind = "dial", surfaceId = surfaceId, snapshot = snap, order = order, active = active,
        radius = NS.DialLayout.ClampRadius(dial.radius), lockdownChip = false, hasActive = false }
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
    local nest = { children = deps.children, active = active, groups = deps.groups }
    local groups = {}
    for _, gid in ipairs(order) do
        local g = deps.group(gid)
        local entry = { id = gid, title = g.name, icon = g.icon, iconColor = g.iconColor }
        local kids = childrenOf(gid, g, nest)
        if #kids > 0 then
            entry.children = {}
            for _, child in ipairs(kids) do
                local c = childShown(child, nest) and deps.group(child)
                if c then
                    entry.children[#entry.children + 1] = { id = child, title = c.name, icon = c.icon,
                        iconColor = c.iconColor, slots = slotsOf(c.callouts) }
                end
            end
            if #(g.callouts or {}) > 0 then entry.slots = slotsOf(g.callouts) end
        else
            entry.slots = slotsOf(g.callouts)
        end
        groups[#groups + 1] = entry
    end
    plan.rings, plan.openRing = NS.DialLayout.Rings(groups, { mode = dial.mode, slices = dial.slices, title = dial.name,
        fit = dialFit(dial) })
    -- As a pad's: what is drawn (a ring), not what is active.
    plan.hasActive = #plan.rings > 0
    if t0 then Perf.Note("bakeSurface", debugprofilestop() - t0) end
    return plan
end

-- The answer for a surface with no plan yet.
local function unbuiltLines(id)
    local p = NS.db and NS.db.profile
    if p and p.dials[id] then return { L["This dial has not been built yet."] } end
    return { L["This pad has not been built yet."] }
end

-- A group's name as the why lines show it.
local function whyName(gid)
    local g = NS.Library.Group(gid)
    return g and g.name or gid
end

-- Every distinct lock on the plan's slots, sorted, as its tooltip line, appended to `out`.
local function lockLines(plan, out)
    local locks, seen = {}, {}
    S.EachSlot(plan, function(slot)
        if slot.lock and not seen[slot.lock] then
            seen[slot.lock] = true
            locks[#locks + 1] = slot.lock
        end
    end)
    table.sort(locks)
    for _, lock in ipairs(locks) do out[#out + 1] = NS.PadRender.LOCK_TEXT[lock] or tostring(lock) end
end

--- "Why is this showing?" for one pad or dial (spec §13.3): the groups it shows, in priority order,
--- each with the When rows that matched (Resolver.Explain), then every lock in effect on its slots.
--- Read from the last plan, so in combat it explains what is on screen.
--- @return string[]
function S.WhyLines(id)
    local plan = S.Plans()[id] or S.DialPlans()[id]
    if not plan then return unbuiltLines(id) end
    if plan.test and not plan.preview then
        if plan.kind == "dial" then return { L["Test mode: placeholder wedges that send nothing."] } end
        return { L["Test mode: placeholder buttons that send nothing."] }
    end
    if plan.editGroup then
        local out = { L["Editing: %s"]:format(whyName(plan.editGroup)),
            L["Shown alone while you edit it in the settings. Nothing on it sends."] }
        lockLines(plan, out)
        return out
    end
    local out = {}
    if plan.preview then out[1] = L["Preview as: %s"]:format(NS.Preview.Label(plan.preview)) end
    if #plan.order == 0 then out[#out + 1] = L["No group matches this situation."] end
    for _, gid in ipairs(plan.order) do
        out[#out + 1] = NS.Resolver.Explain(whyName(gid), plan.active and plan.active[gid])
    end
    lockLines(plan, out)
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

-- What this rebuild bakes under: the snapshot, its deps, and which of the edit preview, Preview as and
-- test mode holds. The edit preview sits over Preview as and test mode, and bakes under its group's own
-- situation (Preview.EditSnapshot, the preset the selector window shows). `n` counts the plans settled.
local function rebuildContext()
    local preview = NS.Preview.PreviewSnapshot()
    local edit = NS.Preview.EditGroup()
    if edit and not NS.Library.Group(edit) then edit = nil end
    local snap = (edit and NS.Preview.EditSnapshot()) or preview or NS.Situation.Current()
    local deps = S.Deps(snap)
    deps.only = edit
    return { preview = preview, edit = edit, snap = snap, deps = deps, n = 0,
        test = not edit and preview == nil and NS.Preview.IsTestMode() }
end

-- One built plan, marked as the edit preview's or Preview as's when one holds, counted, and announced
-- (ACTIVE_GROUPS_CHANGED) when its group order moved.
local function settle(ctx, id, plan)
    if ctx.edit then
        S.MarkPreview(plan, NS.Preview.EDIT)
        plan.editGroup = ctx.edit
    elseif ctx.preview then
        S.MarkPreview(plan, NS.Preview.PreviewAs())
    end
    ctx.n = ctx.n + 1
    local sig = table.concat(plan.order, ",")
    if sig ~= State.surfaceOrder[id] then
        State.surfaceOrder[id] = sig
        NS.addon:SendMessage(NS.MSG.ACTIVE_GROUPS_CHANGED, id)
    end
    return plan
end

-- Every enabled pad's and dial's plan, test mode's placeholders while it holds.
local function buildPlans(ctx, p)
    local plans, dialPlans = {}, {}
    for _, id in ipairs(enabledIds("pad")) do
        plans[id] = settle(ctx, id, ctx.test and S.TestPlan(id) or S.BuildPlan(id, p.pads[id], ctx.snap, ctx.deps))
    end
    for _, id in ipairs(enabledIds("dial")) do
        dialPlans[id] = settle(ctx, id, ctx.test and S.TestDialPlan(id, p.dials[id])
            or S.BuildDialPlan(id, p.dials[id], ctx.snap, ctx.deps))
    end
    return plans, dialPlans
end

-- What each enabled surface of `kind` shows, to the debug log under `tag`.
local function logShows(kind, tag, plans)
    for _, id in ipairs(enabledIds(kind)) do
        local plan = plans[id]
        if plan then NS.Debug(tag, "%s shows %s", id, #plan.order > 0 and table.concat(plan.order, ",") or "nothing") end
    end
end

--- Rebuild every enabled pad and dial from the current snapshot, and re-bind the dials' keys. Out of
--- combat (RunOrQueue's caller).
--- @return number surfaces rebuilt
function S.ApplyAll(reason)
    if NS.IsStoodDown() or not State.situation then return 0 end
    local ctx = rebuildContext()
    local p = NS.db.profile
    State.surfaceOrder = State.surfaceOrder or {}
    local plans, dialPlans = buildPlans(ctx, p)
    State.surfacePlans, State.dialPlans = plans, dialPlans
    local stale = staleSet()
    for id in pairs(stale) do stale[id] = nil end
    NS.Pad.Sync(plans)
    NS.Dial.Sync(dialPlans, p.dialOrder)
    for _, id in ipairs(enabledIds("pad")) do NS.addon:SendMessage(NS.MSG.SURFACE_REBUILT, id, false) end
    for _, id in ipairs(enabledIds("dial")) do NS.addon:SendMessage(NS.MSG.SURFACE_REBUILT, id, false) end
    NS.Debug(TAG, "rebuilt %s surface(s) (%s)", ctx.n, tostring(reason))
    logShows("pad", TAG, plans)
    logShows("dial", "Dial", dialPlans)
    return ctx.n
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
