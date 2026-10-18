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
    P.bannerAction(P.ctx("groups")):__fire("OnClick")
    P.flush()
    local gid = NS.State.editing.group
    assertTrue(NS.db.profile.groups[gid] ~= nil)
    assertEqual(NS.db.profile.pads.p1.groups[1], gid, "offered to the top of the pad")
    local w = P.tab("groups", "callouts")
    local pop = P.during(function() P.find(w, "Button", "Add callout"):__fire("OnClick") end)
    P.find(pop, "EditBox", "Name"):__fire("OnEnterPressed", "Inc")
    P.find(pop, "EditBox", "Text"):__fire("OnEnterPressed", "Incoming")
    P.find(pop, "Dropdown", "Channel"):__fire("OnValueChanged", "party")
    P.find(pop, "Button", "Save"):__fire("OnClick")
    P.flush()
    local cid = NS.db.profile.groups[gid].callouts[1]
    assertTrue(cid ~= nil, "the popup's Save put the callout in the group")
    assertEqual(NS.db.profile.callouts[cid].text, "Incoming")
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
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local a = NS.Library.CreateCalloutIn(gid, { name = "A", text = "a", channel = "party" })
    local b = NS.Library.CreateCalloutIn(gid, { name = "B", text = "b", channel = "party" })
    pick(NS, gid)
    P.tab("groups", "callouts")
    local list = lists[#lists]
    assertEqual(list.rows, 2)
    list.opts.onMove(1, 2)
    assertEqual(table.concat(NS.db.profile.groups[gid].callouts, ","), b .. "," .. a)
    local w = P.tab("groups", "callouts")
    P.glyph(w, "remove", 1):__fire("OnClick")
    P.accept()
    assertEqual(table.concat(NS.db.profile.groups[gid].callouts, ","), a)
    w = P.tab("groups", "callouts")
    P.find(w, "Dropdown", "Reuse callout"):__fire("OnValueChanged", "bi.mplus.lust")
    P.find(w, "Button", "Add"):__fire("OnClick")
    local copied = NS.db.profile.groups[gid].callouts[2]
    assertTrue(copied:match("^c%d+$") ~= nil, "a copy, never the built-in id")
    assertEqual(NS.db.profile.callouts[copied].name, "Lust")
end)

local function withCallouts(NS)
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local kick = NS.Library.CreateCalloutIn(gid, { name = "Kick", text = "Kick it", channel = "party" })
    local other = NS.Library.CreateGroup({ name = "Other" })
    local lust = NS.Library.CreateCalloutIn(other, { name = "Lust", text = "Lust now", channel = "raid" })
    return gid, kick, other, lust
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

test("groups page: Add callout opens the popup for this group", function()
    local NS, _, P = open()
    local Pop = NS.addon.Settings.CalloutPopup
    local gid = withCallouts(NS)
    pick(NS, gid)
    local w = P.tab("groups", "callouts")
    local add = P.find(w, "Button", "Add callout")
    -- red under: draw no Add callout button on a user group's Callouts tab
    assertTrue(add ~= nil)
    local before = count(NS.db.profile.callouts)
    local pop = P.during(function() add:__fire("OnClick") end)
    assertTrue(Pop.IsOpen())
    assertEqual(Pop.Draft().name, "", "blank, as Add")
    assertEqual(Pop.Draft().channel, "smartGroup")
    assertEqual(count(NS.db.profile.callouts), before, "opening creates nothing")
    P.find(pop, "EditBox", "Name"):__fire("OnEnterPressed", "Pull")
    P.find(pop, "EditBox", "Text"):__fire("OnEnterPressed", "Pulling")
    assertTrue(Pop.Save())
    local list = NS.db.profile.groups[gid].callouts
    assertEqual(#list, 2)
    assertEqual(NS.db.profile.callouts[list[2]].name, "Pull", "saved into this group, at the end")
end)

test("groups page: Reuse lists callouts as <group>: <callout> and built-ins as <set>: <callout>", function()
    local NS, _, P = open()
    local gid, kick, _, lust = withCallouts(NS)
    local byId = {}
    for _, e in ipairs(NS.addon.Settings.Groups.ReusableCallouts(gid)) do byId[e.id] = e end
    -- red under: label a user callout by its name alone
    assertEqual(byId[lust].plain, "Other: Lust")
    assertEqual(byId["bi.mplus.lust"].plain, NS.BuiltIns.groups["bi.mplus"].name .. ": Lust")
    pick(NS, gid)
    local w = P.tab("groups", "callouts")
    local dd = P.find(w, "Dropdown", "Reuse callout")
    -- red under: keep the old "Reuse existing callout" prompt
    assertTrue(dd ~= nil, "the dropdown reads Reuse callout")
    assertEqual(dd.list[lust], byId[lust].label)
    -- red under: offer the selected group's own callouts in its Reuse list
    assertEqual(byId[kick], nil, "the group's own callouts are not offered")
    assertEqual(dd.list[kick], nil)
end)

test("groups page: Reuse leaves out the built-in set the group was customized from", function()
    local NS = open()
    local G = NS.addon.Settings.Groups
    local copy = NS.Library.Customize("bi.mplus")
    assertTrue(copy ~= nil, "customized")
    local function offered(gid, id)
        for _, e in ipairs(G.ReusableCallouts(gid)) do if e.id == id then return true end end
        return false
    end
    -- red under: drop the CustomizedAs check in G.ReusableCallouts
    assertFalse(offered(copy, "bi.mplus.lust"), "the set's own callouts are already the copy's")
    local other = NS.Library.CreateGroup({ name = "Other" })
    assertTrue(offered(other, "bi.mplus.lust"), "another group still offers them")
end)

test("groups page: Reuse draws the group part in muted gold and the callout name in white", function()
    local NS = open()
    local _, kick, other = withCallouts(NS)
    local G = NS.addon.Settings.Groups
    local byId = {}
    for _, e in ipairs(G.ReusableCallouts(other)) do byId[e.id] = e end
    -- red under: leave the Reuse labels uncolored
    assertEqual(G.MUTED_GOLD, "|cffc9a66b")
    assertEqual(byId[kick].label, "|cffc9a66bMine|r: Kick")
    -- a node's whole "<set>: <node>" prefix is the group part
    local node
    for _, e in ipairs(G.ReusableCallouts(other)) do
        if e.id:match("^bi%.") and select(2, e.plain:gsub(": ", "")) == 2 then node = e break end
    end
    assertTrue(node ~= nil, "a built-in node's callout is offered")
    local prefix, name = node.plain:match("^(.*): ([^:]*)$")
    assertEqual(node.label, "|cffc9a66b" .. prefix .. "|r: " .. name)
end)

test("groups page: Reuse sorts the whole list by group, then callout, ignoring case", function()
    local NS = open()
    local L = NS.Library
    local zed = L.CreateGroup({ name = "zed" })
    L.CreateCalloutIn(zed, { name = "b", text = "b", channel = "party" })
    L.CreateCalloutIn(zed, { name = "A", text = "a", channel = "party" })
    local alpha = L.CreateGroup({ name = "Alpha" })
    L.CreateCalloutIn(alpha, { name = "Zulu", text = "z", channel = "party" })
    local entries = NS.addon.Settings.Groups.ReusableCallouts()
    -- red under: list the user callouts first, then the built-ins in their own order
    local function key(e)
        local group, name = e.plain:match("^(.*): ([^:]*)$")
        return (group or ""):lower(), (name or e.plain):lower()
    end
    for i = 2, #entries do
        local g1, n1 = key(entries[i - 1])
        local g2, n2 = key(entries[i])
        assertTrue(g1 < g2 or (g1 == g2 and n1 <= n2),
            ("sorted: %q before %q"):format(entries[i - 1].plain, entries[i].plain))
    end
    assertEqual(entries[1].plain, "Alpha: Zulu")
    assertEqual(entries[#entries - 1].plain, "zed: A")
    assertEqual(entries[#entries].plain, "zed: b")
end)

test("groups page: Reuse numbers same-named copies so each entry is unambiguous", function()
    local NS = open()
    local gid, kick, other = withCallouts(NS)
    local copy = NS.Library.AddToGroup(gid, kick)
    local labels, colored = {}, {}
    for _, e in ipairs(NS.addon.Settings.Groups.ReusableCallouts(other)) do labels[e.id], colored[e.id] = e.plain, e.label end
    -- red under: drop the repeat numbering in G.ReusableCallouts
    assertEqual(labels[kick], "Mine: Kick")
    assertEqual(labels[copy], "Mine: Kick (2)")
    assertEqual(colored[copy], "|cffc9a66bMine|r: Kick (2)")
end)

test("groups page: the Reuse row stretches the dropdown and puts Add at the right edge, as tall as it", function()
    local NS, _, P = open()
    local G = NS.addon.Settings.Groups
    local gid = withCallouts(NS)
    pick(NS, gid)
    local w = P.tab("groups", "callouts")
    local dd, add = P.find(w, "Dropdown", "Reuse callout"), P.find(w, "Button", "Add")
    local row
    for _, x in ipairs(w) do
        if x.children and x.children[1] == dd then row = x end
    end
    assertTrue(row ~= nil, "the dropdown and Add share a row")
    -- red under: lay the row out in Flow with relative widths
    assertEqual(row.layout, "Table")
    local cols = row.userdata.table.columns
    assertEqual(#cols, 4)
    assertEqual(cols[1].weight, 1)
    assertEqual(cols[1].alignH, "fill", "the dropdown fills what Add leaves")
    assertEqual(cols[2].width, G.REUSE_GAP, "the gap is a cell, not spaceH")
    assertNil(row.userdata.table.spaceH, "no spaceH: it would also sit between Add and the inset")
    assertEqual(cols[3], G.REUSE_ADD_W, "Add's fixed cell")
    -- red under: end Add's cell on the content's right edge (options-ui-§8's clip)
    assertEqual(cols[4].width, G.EDGE_INSET, "Add ends EDGE_INSET short of the right edge")
    assertEqual(G.EDGE_INSET, 2)
    assertEqual(row.children[3], add)
    assertEqual(row.children[2].width, G.REUSE_GAP)
    assertEqual(row.children[4].width, G.EDGE_INSET, "the inset cell's filler")
    assertEqual(add.width, G.REUSE_ADD_W)
    -- red under: leave Add at AceGUI's 24px Button height
    assertEqual(add.height, 26, "as tall as a label-less dropdown")
end)

test("groups page: Add callout spans the row to EDGE_INSET short of the right edge, as Reuse's Add", function()
    local NS, _, P = open()
    local G = NS.addon.Settings.Groups
    pick(NS, (withCallouts(NS)))
    local w = P.tab("groups", "callouts")
    local add = P.find(w, "Button", "Add callout")
    local row
    for _, x in ipairs(w) do
        if x.children and x.children[1] == add then row = x end
    end
    assertTrue(row ~= nil)
    -- red under: leave Add callout at the button pair's half width, or full width on the clip edge
    assertEqual(row.layout, "Table")
    local cols = row.userdata.table.columns
    assertEqual(#cols, 2)
    assertEqual(cols[1].alignH, "fill", "the button fills the row")
    assertEqual(cols[2].width, G.EDGE_INSET, "and ends where Reuse's Add does")
    assertNil(row.userdata.table.spaceH)
    assertEqual(row.children[2].width, G.EDGE_INSET)
    assertNil(add.fullWidth, "not anchored to the content's right edge")
    assertNil(add.relativeWidth)
end)

test("groups page: Reuse + Add puts an independent copy at the end", function()
    local NS, _, P = open()
    local gid, kick, _, lust = withCallouts(NS)
    pick(NS, gid)
    local w = P.tab("groups", "callouts")
    P.find(w, "Dropdown", "Reuse callout"):__fire("OnValueChanged", lust)
    P.find(w, "Button", "Add"):__fire("OnClick")
    local list = NS.db.profile.groups[gid].callouts
    assertEqual(#list, 2)
    assertEqual(list[1], kick)
    local copy = list[2]
    -- red under: put the picked id itself in this group (a shared callout)
    assertTrue(copy ~= lust, "a copy, not the callout itself")
    assertEqual(NS.db.profile.callouts[copy].name, "Lust")
    assertEqual(NS.db.profile.callouts[copy].text, "Lust now")
    NS.SchemaRuntime.Set("callout.text", "Changed", copy)
    assertEqual(NS.db.profile.callouts[lust].text, "Lust now", "the source is untouched")
    -- copying within the group is allowed too
    w = P.tab("groups", "callouts")
    P.find(w, "Dropdown", "Reuse callout"):__fire("OnValueChanged", kick)
    P.find(w, "Button", "Add"):__fire("OnClick")
    assertEqual(#NS.db.profile.groups[gid].callouts, 3)
end)

test("groups page: picking in Reuse alone adds nothing", function()
    local NS, _, P = open()
    local gid, _, _, lust = withCallouts(NS)
    pick(NS, gid)
    local w = P.tab("groups", "callouts")
    local add = P.find(w, "Button", "Add")
    -- red under: leave Add enabled with nothing picked
    assertTrue(add.disabled, "Add waits for a pick")
    local before = count(NS.db.profile.callouts)
    -- red under: act on the pick (Ed.ActionDropdown) instead of on Add
    P.find(w, "Dropdown", "Reuse callout"):__fire("OnValueChanged", lust)
    assertEqual(#NS.db.profile.groups[gid].callouts, 1)
    assertEqual(count(NS.db.profile.callouts), before)
    assertFalse(add.disabled, "a pick enables Add")
end)

test("groups page: the edit glyph opens the popup filled in", function()
    local NS, _, P = open()
    local Pop = NS.addon.Settings.CalloutPopup
    local gid, kick = withCallouts(NS)
    pick(NS, gid)
    local w = P.tab("groups", "callouts")
    local edit = P.glyph(w, "edit", 1)
    -- red under: pass no edit to the callout list's entries
    assertTrue(edit ~= nil)
    edit:__fire("OnClick")
    assertTrue(Pop.IsOpen())
    assertEqual(Pop.Draft().name, "Kick")
    assertEqual(Pop.Draft().text, "Kick it")
    Pop.Draft().text = "Kick now"
    assertTrue(Pop.Save())
    assertEqual(NS.db.profile.callouts[kick].text, "Kick now", "the edit saves to the listed callout")
end)

test("groups page: [review 3] the remove glyph asks, then deletes the callout", function()
    local NS, m, P = open()
    local gid, kick = withCallouts(NS)
    local second = NS.Library.CreateCalloutIn(gid, { name = "Stun", text = "Stun", channel = "party" })
    pick(NS, gid)
    local w = P.tab("groups", "callouts")
    local shown = #m.popupsShown
    P.glyph(w, "remove", 1):__fire("OnClick")
    -- red under: remove at once, without Ed.ConfirmDelete
    assertEqual(#m.popupsShown, shown + 1, "asks first")
    assertTrue(NS.db.profile.callouts[kick] ~= nil, "nothing is removed before the answer")
    assertEqual(m.popupsShown[#m.popupsShown][2], "Kick")
    -- the list moves under the open question: the answer still removes the callout it asked about
    NS.Library.MoveInGroup(gid, 1, 2)
    P.accept()
    -- red under: remove by the index the row was drawn at
    assertEqual(table.concat(NS.db.profile.groups[gid].callouts, ","), second)
    assertNil(NS.db.profile.callouts[kick], "the callout is deleted, as nothing else holds it")
end)

test("groups page: deleting a group deletes its callouts", function()
    local NS, m, P = open()
    local gid, kick, _, lust = withCallouts(NS)
    pick(NS, gid)
    local w = P.redraw("groups")
    local delete = P.find(w, "Button", "Delete")
    delete:__fire("OnClick")
    -- red under: keep the confirmation's "This cannot be undone." alone (it says nothing of the callouts)
    local which = m.popupsShown[#m.popupsShown][1]
    assertTrue(m.StaticPopupDialogs[which].text:find("and its callouts", 1, true) ~= nil)
    P.accept()
    assertNil(NS.db.profile.groups[gid])
    assertNil(NS.db.profile.callouts[kick])
    assertTrue(NS.db.profile.callouts[lust] ~= nil, "another group's callouts are kept")
    -- and a plain delete elsewhere still asks with the plain text
    NS.addon.Settings.Editors.ConfirmDelete("x", function() end)
    assertEqual(m.StaticPopupDialogs[which].text, "Delete '%s'? This cannot be undone.")
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

test("groups page: [icons] General shows the icon, Choose icon… and the swatch; the browser's Choose writes the group's icon", function()
    local NS, _, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local Ed = NS.addon.Settings.Editors
    local B = NS.addon.Settings.IconBrowser
    Ed.Select("group", gid)
    local w = P.redraw("groups")
    local choose = P.find(w, "Button", "Choose icon…")
    -- red under: keep the inline grid (Ed.IconPicker) on the General tab
    assertTrue(choose ~= nil, "the chooser's button")
    local preview = P.find(w, "Icon")
    assertEqual(preview.image[1], Ed.NO_ICON, "no icon yet: the question mark")
    assertTrue(P.find(w, "ColorPicker", "Icon color").disabled, "no glyph, no color")
    choose:__fire("OnClick")
    assertTrue(B.IsOpen())
    assertEqual(B.State().owner, "group")
    local wanted = "Interface\\Icons\\Achievement_Boss_Ragnaros"
    B.Select(wanted)
    assertTrue(B.Choose())
    assertEqual(NS.db.profile.groups[gid].icon, wanted)
    assertEqual(preview.image[1], wanted, "the chooser's icon is put back in place")
    Ed.Select("group", "bi.mplus")
    w = P.redraw("groups")
    assertNil(P.find(w, "Button", "Choose icon…"), "built-ins are read-only")
end)

test("groups page: [icons] General's clear glyph takes the group's icon and color off; idle with no icon", function()
    local NS, _, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local Ed = NS.addon.Settings.Editors
    assertTrue(NS.Library.SetIcon("group", gid, NS.Icon("star"), "ff8000"))
    Ed.Select("group", gid)
    local w = P.redraw("groups")
    local clear = P.glyph(w, "clear")
    -- red under: draw no clear glyph in Ed.IconChooser (only /qc set could take an icon off)
    assertTrue(clear ~= nil, "a clear glyph beside Choose icon…")
    assertFalse(clear.disabled, "an icon to take off")
    assertEqual(clear.image.atlas, "transmog-icon-remove")
    clear:__fire("OnClick")
    assertTrue(not NS.db.profile.groups[gid].icon, "the icon is gone")
    assertTrue(not NS.db.profile.groups[gid].iconColor, "and its color with it")
    assertEqual(P.find(w, "Icon").image[1], Ed.NO_ICON, "the chooser shows the question mark")
    assertTrue(clear.disabled, "nothing left to take off")
end)

test("groups page: [icons] General has no Icon box: the icon is chosen under an Icon label alone", function()
    local NS, _, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine", icon = NS.Icon("star") })
    NS.addon.Settings.Editors.Select("group", gid)
    local w = P.redraw("groups")
    -- red under: drop group.icon from UNDRAWN in settings/Groups.lua
    assertNil(P.find(w, "EditBox", "Icon"), "no Icon text box")
    assertTrue(P.find(w, "EditBox", "Name") ~= nil, "the other rows still draw")
    local label = P.find(w, "Label", "Icon")
    assertTrue(label ~= nil, "the chooser's own Icon label")
    assertEqual(label.fontObject, _G.GameFontNormalSmall)
    assertTrue(label.fullWidth, "no inset on a page: its labels sit at the left edge")
    assertEqual(P.find(w, "Icon").image[1], NS.Icon("star"), "the stored path still draws")
    assertEqual(P.find(w, "Button", "Choose icon…").relativeWidth, 0.4, "a page's relative widths")
    -- the row stays for /qc
    assertTrue(NS.SchemaRuntime.Set("group.icon", "136012", gid))
    assertEqual(NS.db.profile.groups[gid].icon, 136012)
end)

test("groups page: [icons] a glyph's swatch writes the group's color; a game icon chosen clears it in the same act", function()
    local NS, _, P = open()
    local star = NS.Icon("star")
    local gid = NS.Library.CreateGroup({ name = "Mine", icon = star, iconColor = "ff0000" })
    local B = NS.addon.Settings.IconBrowser
    pick(NS, gid)
    local w = P.redraw("groups")
    local preview, swatch = P.find(w, "Icon"), P.find(w, "ColorPicker", "Icon color")
    assertEqual(table.concat(preview.image.vertexColor, ","), "1,0,0", "the icon drawn in its color")
    assertFalse(swatch.disabled, "a glyph takes a color")
    assertEqual(swatch.color.r .. "," .. swatch.color.g .. "," .. swatch.color.b, "1,0,0")
    swatch:__fire("OnValueConfirmed", 0, 0, 1, 1)
    assertEqual(NS.db.profile.groups[gid].iconColor, "0000ff")
    assertEqual(table.concat(preview.image.vertexColor, ","), "0,0,1")
    swatch:__fire("OnValueConfirmed", 1, 1, 1, 1)
    assertTrue(not NS.db.profile.groups[gid].iconColor, "white is none")
    NS.SchemaRuntime.Set("group.iconColor", "00ff00", gid)
    -- review focus 1: the stored glyph has a color; a game icon chosen clears it in the same act
    local changes = 0
    local send = NS.addon.SendMessage
    NS.addon.SendMessage = function(self, name, ...)
        if name == NS.MSG.LIBRARY_CHANGED then changes = changes + 1 end
        return send(self, name, ...)
    end
    P.find(w, "Button", "Choose icon…"):__fire("OnClick")
    assertEqual(B.State().tab, "glyphs", "the stored glyph's tab")
    assertEqual(B.State().color, "00ff00")
    B.SetTab("game")
    B.Select(136243)
    assertTrue(B.Choose())
    local g = NS.db.profile.groups[gid]
    assertEqual(g.icon, 136243)
    assertTrue(not g.iconColor, "the color is cleared")
    assertEqual(changes, 1, "icon and color in one act")
    assertTrue(swatch.disabled, "a game icon takes no color")
    -- and back to a glyph with a color: both land, as one act
    P.find(w, "Button", "Choose icon…"):__fire("OnClick")
    B.SetTab("glyphs")
    B.Select(star)
    B.SetColor("ff8000")
    assertTrue(B.Choose())
    -- red under: write the icon through the seam alone in G.IconSpec's choose (no Library.SetIcon)
    assertEqual(g.icon, star)
    assertEqual(g.iconColor, "ff8000")
    assertEqual(changes, 2)
end)

test("groups page: [icons] the browser closes as Cancel when the settings window hides or the group is deleted", function()
    local NS, m, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local B = NS.addon.Settings.IconBrowser
    pick(NS, gid)
    local w = P.redraw("groups")
    P.find(w, "Button", "Choose icon…"):__fire("OnClick")
    m.SettingsPanel:__fire("OnHide")
    -- red under: drop the SettingsPanel OnHide hook in settings/IconBrowser.lua's build
    assertFalse(B.IsOpen())
    P.find(w, "Button", "Choose icon…"):__fire("OnClick")
    B.Select(NS.Icon("star"))
    NS.Library.DeleteGroup(gid)
    -- red under: drop the `valid` check in settings/IconBrowser.lua's onLibraryChanged
    assertFalse(B.IsOpen(), "its group is gone")
    assertTrue(NS.db.profile.groups[gid] == nil)
end)

test("groups page: [icons] a callout row in the Callouts tab draws its glyph in the callout's color", function()
    local NS, _, P = open()
    local star = NS.Icon("star")
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.Library.CreateCalloutIn(gid, { name = "Star", text = "go", channel = "party", icon = star, iconColor = "00ff00" })
    pick(NS, gid)
    local w = P.tab("groups", "callouts")
    local row
    for _, label in ipairs(P.all(w, "Label")) do
        if label.image and label.image[1] == star then row = label end
    end
    assertTrue(row ~= nil, "the callout's row shows its icon")
    -- red under: the Callouts tab's entries without iconColor
    assertEqual(table.concat(row.image.vertexColor, ","), "0,1,0")
end)

test("groups page: [icons] a tinted callout row puts its image back to white when released (AceGUI's shared pool)", function()
    local NS, m, P = open()
    local star = NS.Icon("star")
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.Library.CreateCalloutIn(gid, { name = "Star", text = "go", channel = "party", icon = star, iconColor = "00ff00" })
    pick(NS, gid)
    local w = P.tab("groups", "callouts")
    local row
    for _, label in ipairs(P.all(w, "Label")) do
        if label.image and label.image[1] == star then row = label end
    end
    assertEqual(table.concat(row.image.vertexColor, ","), "0,1,0")
    m.LibStub("AceGUI-3.0"):Release(row)
    -- red under: drop the row label's OnRelease in Ed.ReorderRows
    assertEqual(table.concat(row.image.vertexColor, ","), "1,1,1", "the pooled image is white for its next owner")
end)

test("groups page: [icons] the swatch writes on a drag tick (OnValueChanged) with no confirm, as OK leaves it", function()
    local NS, _, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine", icon = NS.Icon("star"), iconColor = "ff0000" })
    pick(NS, gid)
    local w = P.redraw("groups")
    local swatch = P.find(w, "ColorPicker", "Icon color")
    swatch:__fire("OnValueChanged", 0, 0, 1, 1)
    -- red under: listen for OnValueConfirmed alone in Ed.IconChooser
    assertEqual(NS.db.profile.groups[gid].iconColor, "0000ff")
    swatch:__fire("OnValueConfirmed", 1, 0, 0, 1)   -- Cancel confirms the old color
    assertEqual(NS.db.profile.groups[gid].iconColor, "ff0000", "Cancel puts the old color back")
end)
