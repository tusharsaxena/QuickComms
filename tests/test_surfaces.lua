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
    assertEqual(table.concat(plan.order, ","), "bi.bg.ab,bi.bg")
    assertEqual(#plan.sections, 6)
    assertEqual(plan.sections[2].title, "Lumber Mill")
    assertEqual(plan.sections[2].slots[3].line, "/i INC 3 Lumber Mill")
    assertEqual(plan.sections[6].title, "Battleground (generic)")
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

-- ── the rebuild edge (Task 11) ──────────────────────────────────────────────────────────────

local function combat(m, on)
    if on then
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_DISABLED")
        m.__setCombat(true)
    else
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_ENABLED")
    end
end

local function pull(NS) return NS.Pad.ChipsFor("p1", "bi.mplus.pull")[1] end
local function staleShown(NS) return NS.Pad.Instance("p1").header.qcStale:IsShown() end

local function nonMessages(m)
    local out = {}
    for _, r in ipairs(m.__registrations()) do
        if r.kind ~= "message" then out[#out + 1] = r.event end
    end
    table.sort(out)
    return table.concat(out, ",")
end

local function withInputs(base, extra)
    local i = {}
    for k, v in pairs(base) do i[k] = v end
    for k, v in pairs(extra) do i[k] = v end
    return i
end

test("surfaces: the first situation read builds the default pad, armed and shown", function()
    local NS = live()
    local inst = NS.Pad.Instance("p1")
    assertTrue(inst ~= nil)
    assertTrue(inst.root:IsShown())
    assertEqual(pull(NS):GetAttribute("macrotext"), "/p Pulling next pack")
end)

test("surfaces: ACTIVE_GROUPS_CHANGED is sent once per real change of a pad's active groups", function()
    local NS = live()
    local heard = {}
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.ACTIVE_GROUPS_CHANGED, function(_, id) heard[#heard + 1] = id end)
    NS.Library.CreateCallout({ name = "Loose", text = "hi", channel = "party" })
    assertEqual(#heard, 0, "a library write that moves no group")
    NS.Situation.ReadInputs = function() return AB end
    NS.Situation.RefreshNow("test")
    assertEqual(table.concat(heard, ","), "p1,d2", "the pad, then the dial")
    NS.Surfaces.Request("again")
    NS.Surfaces.Request("and again")
    -- red under: drop the `sig ~= State.surfaceOrder[id]` check in S.ApplyAll
    assertEqual(table.concat(heard, ","), "p1,d2", "a rebuild with the same groups sends nothing")
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    assertEqual(table.concat(heard, ","), "p1,d2,p1,d2", "back to M+ is a second real change")
end)

test("surfaces: [review 1] a situation change in combat queues: nothing blocked, stale shows, combat end rebuilds", function()
    local NS, m = live()
    local chip = pull(NS)
    local rebuilt = {}
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.SURFACE_REBUILT, function(_, id, stale) rebuilt[#rebuilt + 1] = id .. ":" .. tostring(stale) end)
    combat(m, true)
    NS.Situation.ReadInputs = function() return withInputs(MPLUS, { inInstanceGroup = true }) end
    NS.Situation.RefreshNow("test")
    assertEqual(#m.blocked, 0)
    assertEqual(chip:GetAttribute("macrotext"), "/p Pulling next pack", "frozen in combat")
    assertTrue(staleShown(NS))
    assertEqual(table.concat(rebuilt, ","), "p1:true,d2:true")
    combat(m, false)
    -- red under: drop the RunOrQueue in S.Request (the rebuild would run, and be blocked, in combat)
    assertEqual(pull(NS):GetAttribute("macrotext"), "/i Pulling next pack")
    assertFalse(staleShown(NS))
    assertEqual(table.concat(rebuilt, ","), "p1:true,d2:true,p1:false,d2:false")
    assertEqual(#m.blocked, 0)
end)

test("surfaces: [review 1] a profile switch in combat queues the new profile's pads", function()
    local NS, m = live()
    -- "Other" differs from Default: a group of its own, first on the pad, and a saved position.
    NS.addon.db:SetProfile("Other")
    local cid = userCallout(NS, { name = "Theirs", text = "Other line", channel = "party" })
    NS.Library.SetSurfacePoint("pad", "p1", { "TOPLEFT", "TOPLEFT", 40, -60 })
    NS.addon.db:SetProfile("Default")
    local root = NS.Pad.Instance("p1").root
    assertEqual(#NS.Pad.ChipsFor("p1", cid), 0, "Default does not carry Other's group")
    assertEqual((root:GetPoint(1)), "CENTER")
    combat(m, true)
    NS.addon.db:SetProfile("Other")
    assertEqual(#m.blocked, 0)
    assertTrue(staleShown(NS))
    assertEqual(pull(NS):GetAttribute("macrotext"), "/p Pulling next pack", "the chips keep their old lines")
    assertEqual(#NS.Pad.ChipsFor("p1", cid), 0, "nothing of the new profile until combat ends")
    assertEqual((root:GetPoint(1)), "CENTER")
    combat(m, false)
    assertEqual(#m.blocked, 0)
    assertEqual(NS.Pad.ChipsFor("p1", cid)[1]:GetAttribute("macrotext"), "/p Other line")
    -- red under: drop the applyPoint in Pad.Apply (the pad keeps Default's place)
    local p, _, rel, x, y = root:GetPoint(1)
    assertEqual(table.concat({ p, rel, x, y }, ","), "TOPLEFT,TOPLEFT,40,-60")
    assertFalse(staleShown(NS))
end)

test("surfaces: [fix wave] enabled in combat (a /reload mid-pull): combat end builds the pad, the queue empties", function()
    local NS, _, m = T.bootAddon()
    m.__setCombat(true)
    NS.addon:OnEnable()
    m.__fire("PLAYER_ENTERING_WORLD")
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    assertEqual(table.concat(NS.SendEngine.Snapshot(), ","), "surfaces")
    assertNil(NS.Pad.Instance("p1"))
    m.__setCombat(false)
    m.__fire("PLAYER_REGEN_ENABLED")
    -- red under: drain only on a RESTRICTION_CHANGED (the edge's signature equals the unseeded default)
    assertEqual(#NS.SendEngine.Snapshot(), 0)
    assertEqual(pull(NS):GetAttribute("macrotext"), "/p Pulling next pack")
    assertTrue(NS.Pad.Instance("p1").root:IsShown())
    assertEqual(#m.blocked, 0)
end)

test("surfaces: a setting written in combat waits for combat end, with the stale hint", function()
    local NS, m = live()
    combat(m, true)
    NS.SchemaRuntime.Set("behavior.autoPromote", true)
    assertTrue(staleShown(NS))
    combat(m, false)
    assertFalse(staleShown(NS))
    assertEqual(#m.blocked, 0)
end)

test("surfaces: an encounter lockdown in combat padlocks a Say chip and lights the chip, nothing blocked", function()
    local NS, m = live()
    local cid = userCallout(NS, { name = "Shout", text = "Go go", channel = "say" })
    local chip = NS.Pad.ChipsFor("p1", cid)[1]
    assertFalse(chip.qcLock:IsShown())
    combat(m, true)
    local enc = m.Enum.AddOnRestrictionType.Encounter
    m.restrictionStates[enc] = m.Enum.AddOnRestrictionState.Active
    m.__fire("ADDON_RESTRICTION_STATE_CHANGED", enc, m.Enum.AddOnRestrictionState.Active)
    assertTrue(chip.qcLock:IsShown())
    assertTrue(NS.Pad.Instance("p1").header.qcLockdown:IsShown())
    assertEqual(chip:GetAttribute("macrotext"), "/s Go go", "a lock never disarms")
    assertEqual(#m.blocked, 0)
end)

test("surfaces: test mode draws placeholders that send nothing; combat start brings the live chips back", function()
    local NS, m = live()
    NS.Preview.SetTestMode(true)
    local inst = NS.Pad.Instance("p1")
    assertTrue(inst.header.qcTest:IsShown())
    assertEqual(#NS.SendEngine.ArmedButtons(), 0, "placeholders are disarmed")
    m.__click(NS.Pad.ChipsFor("p1", "test.1.1")[1])
    assertEqual(#m.sentMacros, 0)
    combat(m, true)
    assertFalse(NS.Preview.IsTestMode())
    assertFalse(inst.header.qcTest:IsShown())
    assertEqual(pull(NS):GetAttribute("macrotext"), "/p Pulling next pack")
    assertEqual(#m.blocked, 0)
end)

test("surfaces: if lockdown has already begun at the combat edge, test mode's end is queued, not blocked", function()
    local NS, m = live()
    NS.Preview.SetTestMode(true)
    m.__setCombat(true)                    -- InCombatLockdown() is already true when the edge fires
    m.__fire("PLAYER_REGEN_DISABLED")
    assertFalse(NS.Preview.IsTestMode())
    assertEqual(#m.blocked, 0)
    assertTrue(staleShown(NS))
    assertEqual(#NS.SendEngine.ArmedButtons(), 0, "the placeholders stay, disarmed, until combat ends")
    combat(m, false)
    assertEqual(pull(NS):GetAttribute("macrotext"), "/p Pulling next pack")
    assertFalse(staleShown(NS))
    assertFalse(NS.Pad.Instance("p1").header.qcTest:IsShown())
end)

test("surfaces: disabled out of combat, every pad hides and every chip disarms; enabled, they return", function()
    local NS = live()
    local inst = NS.Pad.Instance("p1")
    NS.SchemaRuntime.Set("enabled", false)
    assertFalse(inst.root:IsShown())
    assertEqual(#NS.SendEngine.ArmedButtons(), 0)
    NS.SchemaRuntime.Set("enabled", true)
    assertTrue(inst.root:IsShown())
    assertEqual(pull(NS):GetAttribute("macrotext"), "/p Pulling next pack")
end)

test("surfaces: [review 2] disabled mid-combat: nothing blocked, one held registration, finished at combat end", function()
    local NS, m = live()
    local inst = NS.Pad.Instance("p1")
    combat(m, true)
    NS.SchemaRuntime.Set("enabled", false)
    assertTrue(NS.IsStoodDown())
    assertEqual(#m.blocked, 0)
    assertTrue(inst.root:IsShown(), "held: no protected call in combat")
    -- red under: register the held teardown on NS.addon instead of SendEngine's own target
    assertEqual(nonMessages(m), "PLAYER_REGEN_ENABLED", "the one permitted registration")
    -- A click on the still-armed pad: the game may send it, the addon tracks and reports nothing.
    local heard = 0
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.SEND_RESULT, function() heard = heard + 1 end)
    local timers = #m.__timers
    m.prints = {}
    m.__click(pull(NS))
    -- red under: drop the IsStoodDown check in SendEngine's press
    assertEqual(#m.__timers, timers, "no timer from a disabled addon")
    assertEqual(NS.SendEngine.EchoState().pending, 0)
    assertEqual(heard, 0)
    assertEqual(#m.prints, 0)
    combat(m, false)
    assertFalse(inst.root:IsShown())
    assertEqual(#NS.SendEngine.ArmedButtons(), 0)
    assertEqual(nonMessages(m), "", "released the moment it fired")
    assertEqual(#m.blocked, 0)
end)

test("surfaces: [fix wave] disabled then enabled inside one combat: the pad is shown and armed after it", function()
    local NS, m = live()
    local inst = NS.Pad.Instance("p1")
    combat(m, true)
    NS.SchemaRuntime.Set("enabled", false)
    NS.SchemaRuntime.Set("enabled", true)
    assertEqual(#m.blocked, 0)
    local regen = 0
    for ev in nonMessages(m):gmatch("[^,]+") do
        if ev == "PLAYER_REGEN_ENABLED" then regen = regen + 1 end
    end
    -- red under: drop SendEngine.CancelTeardown from the stand-up (the held hide stays registered)
    assertEqual(regen, 1, "Restrictions' edge only: the held stand-down is released")
    assertNil(NS.State.pendingTeardown)
    combat(m, false)
    assertTrue(inst.root:IsShown())
    assertEqual(pull(NS):GetAttribute("macrotext"), "/p Pulling next pack")
    assertEqual(#m.blocked, 0)
end)

test("surfaces: [phase 3] WhyLines names each shown group in order, built-ins marked, then the locks", function()
    local NS = live({})
    local cid = userCallout(NS, { name = "Ask", text = "Raid stack", channel = "raid" })
    local lines = NS.Surfaces.WhyLines("p1")
    -- the open world, solo: only the user group (an empty When) is active, and /raid is locked
    assertEqual(lines[1], "Mine: always on")
    assertEqual(lines[#lines], "Locked: you are not in a raid.")
    assertTrue(cid ~= nil)
end)

test("surfaces: [phase 3] WhyLines in a key explains the built-in's matched row; a preview says so", function()
    local NS = live()
    assertEqual(NS.Surfaces.WhyLines("p1")[1], "M+ (generic) (built-in): Content")
    NS.Preview.SetPreviewAs("arena")
    local lines = NS.Surfaces.WhyLines("p1")
    assertEqual(lines[1], "Preview as: Arena")
    assertEqual(lines[2], "Arena (generic) (built-in): Content")
    NS.Preview.SetPreviewAs("current")
    NS.Preview.SetTestMode(true)
    assertEqual(NS.Surfaces.WhyLines("p1")[1], "Test mode: placeholder chips that send nothing.")
    assertEqual(NS.Surfaces.WhyLines("p9")[1], "This pad has not been built yet.")
end)
