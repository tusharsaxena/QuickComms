-- tests/test_page_groups.lua — settings/Groups.lua (spec §13.1, §13.2, §12.2): the picker and New group,
-- a user group's General, Callouts, When and Preview tabs, and a built-in's read-only General with
-- Customize and its hidden-callouts editor. Driven headlessly through tests/page_helpers.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function open(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or {} end
    NS.Situation.RefreshNow("test")
    local P = dofile("tests/page_helpers.lua")(NS, m)
    P.show("Groups")
    return NS, m, P
end

local function pick(NS, gid) NS.addon.Settings.Editors.Select("group", gid) end

test("groups page: [exit] a new group with a callout and a When shows first on the pad in that situation", function()
    local NS, _, P = open(MPLUS)
    local cid = NS.Library.CreateCallout({ name = "Inc", text = "Incoming", channel = "smartGroup" })
    P.bannerAction(P.ctx("groups")):__fire("OnClick")
    P.flush()
    local gid = NS.State.editing.group
    assertTrue(NS.db.profile.groups[gid] ~= nil)
    assertEqual(NS.db.profile.pads.p1.groups[1], gid, "offered to the top of the pad")
    local w = P.tab("groups", "callouts")
    P.find(w, "Dropdown", "Add a callout"):__fire("OnValueChanged", cid)
    assertEqual(NS.db.profile.groups[gid].callouts[1], cid)
    w = P.tab("groups", "When")
    P.find(w, "CheckBox", "Content"):__fire("OnValueChanged", true)
    P.flush()
    w = P.tab("groups", "When")
    P.find(w, "CheckBox", "M+"):__fire("OnValueChanged", true)
    assertTrue(NS.db.profile.groups[gid].when.content.mythicPlus)
    local plan = NS.Surfaces.Plans().p1
    assertEqual(plan.order[1], gid)
    assertEqual(NS.Pad.ChipsFor("p1", cid)[1]:GetAttribute("macrotext"), "/p Incoming")
    -- and not in the open world
    NS.Situation.ReadInputs = function() return {} end
    NS.Situation.RefreshNow("test")
    assertTrue(NS.Pad.ChipsFor("p1", cid)[1] == nil)
end)

test("groups page: the picker lists user groups by name, then the built-ins, active ones dotted", function()
    local NS = open(MPLUS)
    NS.Library.CreateGroup({ name = "Zed" })
    NS.Library.CreateGroup({ name = "Alpha" })
    local entries = NS.addon.Settings.Groups.Entries()
    assertTrue(entries[1].label:find("Alpha", 1, true) ~= nil)
    assertTrue(entries[2].label:find("Zed", 1, true) ~= nil)
    assertEqual(entries[3].id, NS.BuiltIns.order[1])
    local mplus
    for _, e in ipairs(entries) do if e.id == "bi.mplus" then mplus = e end end
    assertTrue(mplus.label:find("Indicator-Green", 1, true) ~= nil, "active in a key")
    assertTrue(mplus.label:find("(built-in)", 1, true) ~= nil)
end)

test("groups page: General draws Preview as first, then the group's rows; Duplicate and Delete act", function()
    local NS, _, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    pick(NS, gid)
    local w = P.redraw("groups")
    assertTrue(P.find(w, "Dropdown", "Preview as") ~= nil)
    P.find(w, "EditBox", "Name"):__fire("OnEnterPressed", "Kicks")
    assertEqual(NS.db.profile.groups[gid].name, "Kicks")
    P.find(w, "CheckBox", "Enabled"):__fire("OnValueChanged", false)
    assertFalse(NS.db.profile.groups[gid].enabled)
    P.find(w, "Button", "Duplicate"):__fire("OnClick")
    local copy = NS.State.editing.group
    assertTrue(copy ~= gid and NS.db.profile.groups[copy] ~= nil)
    w = P.redraw("groups")
    P.find(w, "Button", "Delete"):__fire("OnClick")
    P.accept()
    assertNil(NS.db.profile.groups[copy])
end)

test("groups page: Callouts drags to reorder, removes, and copies a built-in callout in (P2)", function()
    local NS, _, P = open()
    local lists = P.reorderSpy()
    local a = NS.Library.CreateCallout({ name = "A", text = "a", channel = "party" })
    local b = NS.Library.CreateCallout({ name = "B", text = "b", channel = "party" })
    local gid = NS.Library.CreateGroup({ name = "Mine", callouts = { a, b } })
    pick(NS, gid)
    P.tab("groups", "callouts")
    local list = lists[#lists]
    assertEqual(list.rows, 2)
    list.opts.onMove(1, 2)
    assertEqual(table.concat(NS.db.profile.groups[gid].callouts, ","), b .. "," .. a)
    local w = P.tab("groups", "callouts")
    P.all(w, "Button", "Remove")[1]:__fire("OnClick")
    assertEqual(table.concat(NS.db.profile.groups[gid].callouts, ","), a)
    w = P.tab("groups", "callouts")
    P.find(w, "Dropdown", "Add a callout"):__fire("OnValueChanged", "bi.mplus.lust")
    local copied = NS.db.profile.groups[gid].callouts[2]
    assertTrue(copied:match("^c%d+$") ~= nil, "a copy, never the built-in id")
    assertEqual(NS.db.profile.callouts[copied].name, "Lust")
end)

test("groups page: [review 4] a built-in is read-only; Customize puts the copy in its place and selects it", function()
    local NS, _, P = open()
    pick(NS, "bi.raid")
    local w = P.redraw("groups")
    assertTrue(P.hasText(w, "is a built-in set"))
    assertNil(P.find(w, "EditBox", "Name"), "no name box for a built-in")
    local enabled = P.find(w, "CheckBox", "Enabled")
    enabled:__fire("OnValueChanged", false)
    assertFalse(NS.db.profile.builtins["bi.raid"].enabled, "the overlay row, through the seam")
    enabled:__fire("OnValueChanged", true)
    local at
    for i, g in ipairs(NS.db.profile.pads.p1.groups) do if g == "bi.raid" then at = i end end
    w = P.redraw("groups")
    P.find(w, "Button", "Customize"):__fire("OnClick")
    local copy = NS.State.editing.group
    assertTrue(copy ~= "bi.raid" and NS.db.profile.groups[copy] ~= nil)
    assertEqual(NS.db.profile.pads.p1.groups[at], copy, "in the built-in's place")
    assertFalse(NS.db.profile.builtins["bi.raid"].enabled)
    w = P.redraw("groups")
    assertTrue(P.find(w, "EditBox", "Name") ~= nil, "the copy is editable")
end)

test("groups page: a built-in's Callouts tab hides and shows its callouts, a node's named with its node", function()
    local NS, _, P = open()
    pick(NS, "bi.bg.ab")
    local w = P.tab("groups", "callouts")
    local box = P.find(w, "CheckBox", "Stables: INC 1")
    assertTrue(box ~= nil and box.value == true)
    box:__fire("OnValueChanged", false)
    assertTrue(NS.db.profile.builtins["bi.bg.ab"].hidden["bi.bg.ab.stables.inc1"])
    for _, cid in ipairs(NS.Library.Group("bi.bg.ab.stables").callouts) do
        assertTrue(cid ~= "bi.bg.ab.stables.inc1", "hidden from the merged set")
    end
end)

test("groups page: the When tab of a built-in describes it; a user group's edits it; Preview bakes each callout", function()
    local NS, _, P = open(MPLUS)
    pick(NS, "bi.mplus")
    local w = P.tab("groups", "When")
    assertTrue(P.hasText(w, "Content: M+"))
    assertTrue(P.hasText(w, "Active now."))
    local cid = NS.Library.CreateCallout({ name = "Pull", text = "Pulling", channel = "party" })
    local gid = NS.Library.CreateGroup({ name = "Mine", callouts = { cid } })
    pick(NS, gid)
    w = P.tab("groups", "preview")
    assertTrue(P.hasText(w, "Pull: Sends: /p Pulling"))
end)

test("groups page: [phase 3] a built-in's Defaults turns it back on: the Enabled row its General draws", function()
    local NS, _, P = open()
    pick(NS, "bi.raid")
    P.redraw("groups")
    NS.Library.SetBuiltinEnabled("bi.raid", false)
    P.ctx("groups").panel.defaultsOnClick()
    -- red under: make the Groups page's Defaults plain RestoreDefaults("groups") (builtin.enabled's page is share)
    assertTrue(NS.db.profile.builtins["bi.raid"].enabled)
end)

test("groups page: [review 5] the When tab refuses an upside-down key-level range", function()
    local NS, m, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine", when = { keyLevel = { min = 12 } } })
    pick(NS, gid)
    local w = P.tab("groups", "When")
    m.prints = {}
    local box = P.find(w, "EditBox", "Highest key level")
    box:SetText("10")   -- as the player's typing leaves it
    box:__fire("OnEnterPressed", "10")
    assertTrue(table.concat(m.prints, "\n"):find("The lowest key level is above the highest.", 1, true) ~= nil)
    assertNil(NS.db.profile.groups[gid].when.keyLevel.max)
    -- red under: leave a refused box holding the refused number
    assertEqual(box.text, "", "[final 27] the box shows the stored end again")
end)

local function countApply(NS)
    local n = { applied = 0 }
    local apply = NS.Surfaces.ApplyAll
    NS.Surfaces.ApplyAll = function(...) n.applied = n.applied + 1 return apply(...) end
    n.stop = function() NS.Surfaces.ApplyAll = apply end
    return n
end

test("groups page: [final 16] New group rebuilds the pads once, however many pads there are", function()
    local NS = open()
    NS.Library.CreateSurface("pad", "Two")
    NS.Library.CreateSurface("pad", "Three")
    local n = countApply(NS)
    -- red under: drop Library.Batch from G.Create and Lib.OfferGroup (one rebuild per surface, plus one)
    local gid = NS.addon.Settings.Groups.Create()
    n.stop()
    assertEqual(NS.db.profile.pads.p1.groups[1], gid)
    assertEqual(n.applied, 1)
end)

test("groups page: [final 3, 25] a user group's Defaults: Enabled on, Open the dial off, the rest kept, one rebuild", function()
    local NS, _, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine", icon = 136012, when = { content = { raid = true } },
        enabled = false, openInto = true })
    local other = NS.Library.CreateGroup({ name = "Other", enabled = false })
    pick(NS, gid)
    P.redraw("groups")
    local n = countApply(NS)
    P.ctx("groups").panel.defaultsOnClick()
    n.stop()
    local g = NS.db.profile.groups[gid]
    assertTrue(g.enabled)
    assertFalse(g.openInto)
    -- red under: give group.name, group.icon or group.when a default the page's Defaults reaches
    assertEqual(g.name, "Mine")
    assertEqual(g.icon, 136012)
    assertTrue(g.when.content.raid)
    assertFalse(NS.db.profile.groups[other].enabled, "another group is untouched")
    -- red under: drop Library.Batch from G.RestoreDefaults (one rebuild per row)
    assertEqual(n.applied, 1)
end)

test("groups page: [final 8] Customize of a set on no pad says the copy is on none", function()
    local NS, m = open()
    NS.Library.RemoveGroupFromSurface("pad", "p1", "bi.raid")
    for _, sid in ipairs(NS.db.profile.dialOrder) do NS.Library.RemoveGroupFromSurface("dial", sid, "bi.raid") end
    m.prints = {}
    -- red under: print "took its place on every pad" whatever Library.Customize placed
    NS.addon.Settings.Groups.Customize("bi.raid")
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("The set was on no pad", 1, true) ~= nil, text)
    assertTrue(text:find("took its place", 1, true) == nil, text)
end)

test("groups page: [final 12] Duplicate says the copy is on no pad yet", function()
    local NS, m, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    pick(NS, gid)
    local w = P.redraw("groups")
    m.prints = {}
    -- red under: drop the printed line from G.Duplicate
    P.find(w, "Button", "Duplicate"):__fire("OnClick")
    assertTrue(table.concat(m.prints, "\n"):find("the copy is on no pad yet", 1, true) ~= nil)
end)

local DUNGEON = { inInstance = true, instanceType = "party", difficultyID = 2, instanceID = 2526, inGroup = true }

test("groups page: [final 20] the Instances row adds a typed id, removes one, and refuses a fraction or a negative", function()
    local NS, _, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    pick(NS, gid)
    local w = P.tab("groups", "When")
    P.find(w, "CheckBox", "Instance"):__fire("OnValueChanged", true)
    P.flush()
    w = P.tab("groups", "When")
    local box = P.find(w, "EditBox", "Add an instance")
    assertTrue(box ~= nil)
    -- red under: an IdList onAdd that writes nothing
    box:__fire("OnEnterPressed", "2526")
    assertTrue(NS.db.profile.groups[gid].when.instances[2526])
    for _, typed in ipairs({ "1.5", "-3" }) do
        w = P.tab("groups", "When")
        P.find(w, "EditBox", "Add an instance"):__fire("OnEnterPressed", typed)
    end
    -- red under: idKind.resolve takes any tonumber (1.5 and -3 are stored and never match)
    assertNil(NS.db.profile.groups[gid].when.instances[1.5])
    assertNil(NS.db.profile.groups[gid].when.instances[-3])
    w = P.tab("groups", "When")
    local remove = P.find(w, "Button", "Remove")
    assertTrue(remove ~= nil, "each entry has Remove")
    -- red under: an IdList onRemove that writes nothing
    remove:__fire("OnClick")
    assertNil(NS.db.profile.groups[gid].when.instances, "the emptied row is dropped")
end)

test("groups page: [final 18] Add the instance you are in reads the instance at the click, not at the draw", function()
    local NS, m, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    pick(NS, gid)
    NS.State.whenOpen[gid] = { instances = true }
    local w = P.tab("groups", "When")
    local here = P.find(w, "Button", "Add the instance you are in")
    -- red under: draw the button only when the player is in an instance as the tab is drawn
    assertTrue(here ~= nil, "drawn in the open world too")
    m.prints = {}
    here:__fire("OnClick")
    assertTrue(table.concat(m.prints, "\n"):find("You are not in an instance.", 1, true) ~= nil)
    assertNil(NS.db.profile.groups[gid].when.instances)
    NS.Situation.ReadInputs = function() return DUNGEON end
    NS.Situation.RefreshNow("test")
    -- red under: capture the instance when the tab is drawn (the button adds nothing, or the old one)
    here:__fire("OnClick")
    assertTrue(NS.db.profile.groups[gid].when.instances[2526])
end)

test("groups page: [phase 5] Choose an icon sets a user group's icon; a built-in set offers no picker", function()
    local NS, _, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local Ed = NS.addon.Settings.Editors
    Ed.Select("group", gid)
    local w = P.redraw("groups")
    local wanted = "Interface\\Icons\\Achievement_Boss_Ragnaros"
    for _, icon in ipairs(P.all(w, "Icon")) do
        if icon.image and icon.image[1] == wanted then icon:__fire("OnClick") end
    end
    assertEqual(NS.db.profile.groups[gid].icon, wanted)
    Ed.Select("group", "bi.mplus")
    w = P.redraw("groups")
    assertEqual(#P.all(w, "Icon"), 0, "built-ins are read-only")
end)
