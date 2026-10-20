-- tests/test_dial_yield.lua — Skip on the dial in content (group.dialYield): a top-level group a
-- Comms Dial leaves out while another group on it names content (modules/Surfaces.lua
-- S.BuildDialPlan). In Group ships with it on, so in a dungeon, raid, arena or battleground the dial
-- opens on that content's set; the pad still shows In Group, and so does the dial in the open world.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- A keyed dungeon in a party, Arathi Basin in its instance group, and a party in the open world.
local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }
local AB = { inInstance = true, instanceType = "pvp", instanceID = 2107, inGroup = true, inRaid = true,
    inInstanceGroup = true }
local PARTY = { inGroup = true }

local function live(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or MPLUS end
    NS.Situation.RefreshNow("test")
    return NS, m
end

local function dialOrder(NS, deps)
    local snap = NS.Situation.Current()
    deps = deps or NS.Surfaces.Deps(snap)
    return table.concat(NS.Surfaces.BuildDialPlan("d2", NS.db.profile.dials.d2, snap, deps).order, ",")
end

local function padOrder(NS)
    local snap = NS.Situation.Current()
    return table.concat(NS.Surfaces.BuildPlan("p1", NS.db.profile.pads.p1, snap, NS.Surfaces.Deps(snap)).order, ",")
end

test("dial yield: In Group is seeded skipping the dial in content; the other seeded sets are not", function()
    local NS = live()
    local p = NS.db.profile
    -- red under: seedGroup leaving dialYield behind, or In Group's def without it
    assertTrue(p.groups[T.seeded(NS, "bi.group")].dialYield)
    assertFalse(p.groups[T.seeded(NS, "bi.mplus")].dialYield)
    assertFalse(p.groups[T.seeded(NS, "bi.bg.ab")].dialYield)
    assertEqual(NS.Library.TEMPLATES.group.dialYield, false, "a new group does not skip")
    assertEqual(p.groups[NS.Library.CreateGroup({ name = "Mine" })].dialYield, false)
end)

test("dial yield: in a key the dial leaves In Group out; the pad keeps it", function()
    local NS = live()
    -- red under: S.BuildDialPlan without dialOrder
    assertEqual(dialOrder(NS), T.seeded(NS, "bi.mplus"))
    assertEqual(padOrder(NS), T.seeded(NS, "bi.mplus") .. "," .. T.seeded(NS, "bi.group"))
end)

test("dial yield: in a battleground the dial leaves In Group out behind the map's sets", function()
    local NS = live(AB)
    assertEqual(dialOrder(NS), T.seeded(NS, "bi.bg.ab") .. "," .. T.seeded(NS, "bi.bg"))
    assertEqual(padOrder(NS), T.seeded(NS, "bi.bg.ab") .. "," .. T.seeded(NS, "bi.bg") .. ","
        .. T.seeded(NS, "bi.group"))
end)

test("dial yield: in an open-world party In Group stays on the dial, beside a group-only user group", function()
    local NS = live(PARTY)
    local gid = NS.Library.CreateGroup({ name = "Party night", when = { group = { party = true } } })
    NS.Library.CreateCalloutIn(gid, { name = "Go", text = "go", channel = "party" })
    NS.Library.AddGroupToSurface("dial", "d2", gid, 1)
    -- red under: a group condition counted as content
    assertEqual(dialOrder(NS), gid .. "," .. T.seeded(NS, "bi.group"))
end)

test("dial yield: the skip never empties the dial, and a skipping content group triggers nothing", function()
    local NS = live()
    NS.SchemaRuntime.Set("group.enabled", false, T.seeded(NS, "bi.mplus"))
    assertEqual(dialOrder(NS), T.seeded(NS, "bi.group"), "In Group alone stays")
    local gid = NS.Library.CreateGroup({ name = "Keys", when = { content = { mythicPlus = true } }, dialYield = true })
    NS.Library.AddGroupToSurface("dial", "d2", gid, 1)
    -- red under: a group that skips the dial itself counted as the content that triggers the skip
    assertEqual(dialOrder(NS), gid .. "," .. T.seeded(NS, "bi.group"))
    NS.SchemaRuntime.Set("group.dialYield", false, gid)
    assertEqual(dialOrder(NS), gid, "once it shows, it sends In Group off the dial")
end)

test("dial yield: a place row names content as a content row does", function()
    local NS = live(AB)
    NS.SchemaRuntime.Set("group.enabled", false, T.seeded(NS, "bi.bg.ab"))
    NS.SchemaRuntime.Set("group.enabled", false, T.seeded(NS, "bi.bg"))
    assertEqual(dialOrder(NS), T.seeded(NS, "bi.group"), "no content set left: In Group shows")
    local all = NS.Library.CreateGroup({ name = "Any BG", when = { battleground = { all = true } } })
    NS.Library.AddGroupToSurface("dial", "d2", all, 1)
    -- red under: namesContent reading the content row alone
    assertEqual(dialOrder(NS), all, "All battlegrounds names content")
end)

test("dial yield: an open-world content row names no content", function()
    local NS = live(PARTY)
    local gid = NS.Library.CreateGroup({ name = "Outdoors", when = { content = { openWorld = true } } })
    NS.Library.AddGroupToSurface("dial", "d2", gid, 1)
    assertEqual(dialOrder(NS), gid .. "," .. T.seeded(NS, "bi.group"))
end)

test("dial yield: in the open world a group naming open world and a dungeon keeps In Group on the dial", function()
    local NS = live(PARTY)
    local gid = NS.Library.CreateGroup({ name = "Out and in", when = { content = { openWorld = true, dungeon = true } } })
    NS.Library.AddGroupToSurface("dial", "d2", gid, 1)
    -- red under: dialOrder scanning the Whens without asking whether the place is content
    assertEqual(dialOrder(NS), gid .. "," .. T.seeded(NS, "bi.group"))
end)

test("dial yield: an edit preview of In Group still shows it on the dial", function()
    local NS = live()
    local snap = NS.Situation.Current()
    local deps = NS.Surfaces.Deps(snap)
    deps.only = T.seeded(NS, "bi.group")
    -- red under: dialOrder ignoring deps.only
    assertEqual(dialOrder(NS, deps), T.seeded(NS, "bi.group"))
end)

test("dial yield: the row is written through the seam and refuses a non-bool", function()
    local NS = live()
    local S = NS.SchemaRuntime
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    assertTrue(S.Set("group.dialYield", true, gid))
    assertTrue(NS.db.profile.groups[gid].dialYield)
    assertFalse(S.Set("group.dialYield", "yes", gid))
    assertTrue(S.Set("group.dialYield", false, gid))
    assertFalse(NS.db.profile.groups[gid].dialYield)
end)

test("dial yield: General's Skip on the dial in content sits by Open into, grayed out for a child", function()
    local NS, m = live()
    local P = dofile("tests/page_helpers.lua")(NS, m)
    P.show("Groups")
    local Lib = NS.Library
    local top = Lib.CreateGroup({ name = "Raid night" })
    local kid = Lib.CreateGroup({ name = "Boss 1" })
    NS.SchemaRuntime.Set("group.parent", top, kid)
    NS.addon.Settings.Editors.Select("group", top)
    local w = P.redraw("groups")
    local cb = P.find(w, "CheckBox", "Skip on the dial in content")
    -- red under: no group.dialYield row
    assertTrue(cb ~= nil)
    assertFalse(cb.disabled and true or false, "a top-level group may skip")
    NS.addon.Settings.Editors.Select("group", kid)
    w = P.redraw("groups")
    -- red under: the row without its disabledIf
    assertTrue(P.find(w, "CheckBox", "Skip on the dial in content").disabled, "a child rides its parent's ring")
    assertFalse(P.find(w, "CheckBox", "Open the dial on this group").disabled and true or false)
end)

test("dial yield: the setting travels in a shared string; an old string's group does not skip", function()
    local NS = T.bootAddon()
    local SH, Lib = NS.Share, NS.Library
    local yes = Lib.CreateGroup({ name = "Chatter", dialYield = true })
    local no = Lib.CreateGroup({ name = "Keys" })
    local payload = SH.Collect({ group = { [yes] = true, [no] = true } })
    -- red under: exportMember leaving dialYield out
    assertTrue(payload.groups[yes].dialYield)
    assertFalse(payload.groups[no].dialYield)
    payload.groups[no].dialYield = nil   -- a string made before the field
    local _, map = Lib.Import(SH.Validate(SH.Decode(SH.Encode(payload))))
    local p = NS.db.profile
    -- red under: groupEntry / importMembers dropping the field
    assertTrue(p.groups[map[yes]].dialYield, "the tick arrives")
    assertFalse(p.groups[map[no]].dialYield, "absent reads as off")
    payload.groups[no].dialYield = "yes"
    _, map = Lib.Import(SH.Validate(SH.Decode(SH.Encode(payload))))
    assertFalse(p.groups[map[no]].dialYield, "anything but true arrives off")
end)
