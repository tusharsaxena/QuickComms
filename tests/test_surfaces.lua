-- tests/test_surfaces.lua — modules/Surfaces.lua: a pad's plan (spec §7, §8, §10) and, from Task 11,
-- the rebuild edge: queued in combat, the stale hint, the stand-down.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

-- A keyed dungeon in a party: the M+ built-in is active and smart channels resolve to /p.
local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }
-- Arathi Basin (instanceID 2107) in its instance group: the generic battleground set and the node set.
local AB = { inInstance = true, instanceType = "pvp", instanceID = 2107, inGroup = true, inRaid = true,
    inInstanceGroup = true }

local function live(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or MPLUS end
    NS.Situation.RefreshNow("test")
    return NS, m
end

local function planFor(NS, snap)
    snap = snap or NS.Situation.Current()
    return NS.Surfaces.BuildPlan("p1", NS.db.profile.pads.p1, snap, NS.Surfaces.Deps(snap))
end

-- A user group (an empty When is always active) holding one new callout, first on the default pad.
local function userCallout(NS, fields)
    local cid = assert(NS.Library.CreateCallout(fields))
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.Library.AddToGroup(gid, cid)
    NS.Library.AddGroupToSurface("pad", "p1", gid, 1)
    return cid, gid
end

local function slotOf(plan, cid)
    for _, sec in ipairs(plan.sections) do
        for _, slot in ipairs(sec.slots) do
            if slot.calloutId == cid then return slot end
        end
    end
    return nil
end

test("surfaces: in a key the default pad's plan is the M+ set, baked to /p", function()
    local NS = live()
    local plan = planFor(NS)
    assertEqual(table.concat(plan.order, ","), "bi.mplus")
    assertTrue(plan.hasActive)
    assertEqual(plan.sections[1].title, "M+ (generic)")
    assertEqual(#plan.sections[1].slots, 8)
    local pull = plan.sections[1].slots[1]
    assertEqual(pull.calloutId, "bi.mplus.pull")
    assertEqual(pull.line, "/p Pulling next pack")
    assertEqual(pull.chatType, "PARTY")
    assertEqual(pull.surfaceId, "p1")
    assertEqual(pull.name, "Pulling")
end)

test("surfaces: [review 5] a refused callout is a slot with its reason and no line", function()
    local NS = live()
    local cid = userCallout(NS, { name = "Bad", text = "/run x", channel = "party" })
    local slot = slotOf(planFor(NS), cid)
    assertNil(slot.line)
    assertNil(slot.chatType)
    assertEqual(slot.reason, "startsWithSlash")
    assertEqual(slotOf(planFor(NS), "bi.mplus.pull").line, "/p Pulling next pack", "the others still bake")
end)

test("surfaces: a node battleground gives one section per node, baked to /i", function()
    local NS = live(AB)
    local plan = planFor(NS)
    assertEqual(table.concat(plan.order, ","), "bi.bg,bi.bg.ab")
    assertEqual(#plan.sections, 6)
    assertEqual(plan.sections[1].title, "Battleground (generic)")
    assertEqual(plan.sections[3].title, "Lumber Mill")
    assertEqual(plan.sections[3].slots[3].line, "/i INC 3 Lumber Mill")
end)

test("surfaces: a Say callout locked by an encounter lights the plan's lockdown chip", function()
    local NS = live()
    local cid = userCallout(NS, { name = "Shout", text = "Go go", channel = "say" })
    local snap = { content = "mythicPlus", group = "party", instanceGroup = false, lockdown = { encounter = true } }
    local plan = planFor(NS, snap)
    assertEqual(slotOf(plan, cid).lock, "lockdown")
    assertEqual(slotOf(plan, cid).line, "/s Go go", "locked, still baked")
    assertTrue(plan.lockdownChip)
end)

test("surfaces: solo with the self fallback, a smart callout carries the text to print", function()
    local NS = live({})
    NS.SchemaRuntime.Set("behavior.soloFallback", "self")
    local cid = userCallout(NS, { name = "Hi", text = "Hello {rt8}", channel = "smartGroup" })
    local slot = slotOf(planFor(NS), cid)
    assertNil(slot.line)
    assertEqual(slot.reason, "solo")
    assertEqual(slot.selfText, "Hello {rt8}")
end)

test("surfaces: the bake context fills {me} from the client", function()
    local NS = live()
    local cid = userCallout(NS, { name = "Me", text = "{me} pulling", channel = "party" })
    assertEqual(slotOf(planFor(NS), cid).line, "/p Testchar pulling")
end)

test("surfaces: a disabled built-in leaves the plan", function()
    local NS = live()
    NS.Library.SetBuiltinEnabled("bi.mplus", false)
    local plan = planFor(NS)
    assertEqual(#plan.order, 0)
    assertFalse(plan.hasActive)
    assertEqual(#plan.sections, 0)
end)

test("surfaces: the test plan is placeholder chips that carry no line", function()
    local NS = live()
    local plan = NS.Surfaces.TestPlan("p1")
    assertTrue(plan.test)
    assertTrue(plan.hasActive)
    assertEqual(#plan.sections, 2)
    for _, sec in ipairs(plan.sections) do
        assertEqual(#sec.slots, 4)
        for _, slot in ipairs(sec.slots) do
            assertNil(slot.line)
            assertEqual(slot.reason, "testMode")
        end
    end
end)
