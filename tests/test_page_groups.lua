-- tests/test_page_groups.lua — settings/Groups.lua (spec §13.1, §13.2): the picker and New group, a
-- group's General, Callouts, When and Preview tabs (a seeded built-in set's the same as any group's,
-- 2026-10-18-builtins-as-groups-design.md), and Restore built-in groups. Driven headlessly through
-- tests/page_helpers.lua. Nested groups, the Preview table, Inherit when conditions and a pad
-- title's right-click are tests/test_page_groups_nesting.lua (split at the layout-§1 cap).

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
    P.drawer(w, "Content"):__fire("OnClick")
    w = P.tab("groups", "When")
    P.find(w, "CheckBox", "M+"):__fire("OnValueChanged", true)
    assertTrue(NS.db.profile.groups[gid].when.content.mythicPlus)
    -- Leaving the page ends Preview while editing, so the pad is the live one again.
    local panel = P.ctx("groups").panel
    panel:Hide()
    panel:__fire("OnHide")
    local plan = NS.Surfaces.Plans().p1
    assertEqual(plan.order[1], gid)
    assertEqual(NS.Pad.ButtonsFor("p1", cid)[1]:GetAttribute("macrotext"), "/p Incoming")
    -- and not in the open world
    NS.Situation.ReadInputs = function() return {} end
    NS.Situation.RefreshNow("test")
    assertTrue(NS.Pad.ButtonsFor("p1", cid)[1] == nil)
end)

test("groups page: the picker lists every group by name, a seeded set among them, active ones dotted", function()
    local NS = open(MPLUS)
    local zed = NS.Library.CreateGroup({ name = "Zed" })
    local alpha = NS.Library.CreateGroup({ name = "Alpha" })
    local entries = NS.addon.Settings.Groups.Entries()
    local at = {}
    for i, e in ipairs(entries) do at[e.id] = i end
    local mplus = T.seeded(NS, "bi.mplus")
    -- red under: list the seeded sets after the user groups, as the built-ins were
    assertTrue(at[alpha] < at[mplus] and at[mplus] < at[zed], "one list, by name")
    local label = entries[at[mplus]].label
    assertTrue(label:find("Indicator-Green", 1, true) ~= nil, "active in a key")
    -- red under: the dot before the name ("<dot> Dungeon")
    assertEqual(label, "Dungeon" .. NS.addon.Settings.Editors.ACTIVE_DOT, "the dot after the name")
    assertTrue(label:find("(built-in)", 1, true) == nil, "no built-in tag")
    for _, e in ipairs(entries) do assertTrue(e.id:match("^bi%.") == nil, "no shipped id: " .. e.id) end
end)

-- Every band widget AceGUI makes from here on records the frame it was parented to; the stub frame
-- answers SetParent with itself and keeps nothing. And it is handed out hidden, as AceGUI's pool
-- hands back a released widget, while a SimpleGroup does what AceGUI's container does for a child
-- (the kit's fake does neither): AddChild shows it, and a Flow layout gives each child its relative
-- share of the group's width (SetWidth). Only a widget that goes through the block is shown and sized.
local function recordParents(m)
    local ace = m.LibStub("AceGUI-3.0")
    local create = ace.Create
    ace.Create = function(fake, wtype, ...)
        local w = create(fake, wtype, ...)
        if w.frame then
            rawset(w.frame, "SetParent", function(self, p) self.qcParent = p; return self end)
            w.frame:Hide()
        end
        if wtype == "SimpleGroup" then
            local add, layout = w.AddChild, w.DoLayout
            function w.AddChild(self, child)
                if child.frame then child.frame:Show() end
                return add(self, child)
            end
            function w.DoLayout(self)
                if self.layout == "Flow" and type(self.width) == "number" then
                    for _, child in ipairs(self.children) do
                        if child.relativeWidth then child:SetWidth(child.relativeWidth * self.width) end
                    end
                end
                return layout(self)
            end
        end
        return w
    end
    return function() ace.Create = create end
end

-- The band as AceGUI would draw it: one SimpleGroup under the header frame, shown, laid out by
-- Flow, holding the picker, New group and the checkbox on ONE row (item 020, QUI-L34; options-ui-§14).
local BAND_WIDTHS = { 0.4, 0.25, 0.35 }
local function assertBand(band, label)
    assertTrue(band ~= nil and band.block ~= nil, label .. ": a block")
    local block = band.block
    assertEqual(block.type, "SimpleGroup", label)
    assertEqual(block.layout, "Flow", label)
    assertTrue(block.frame.qcParent ~= nil, label .. ": parented to the header frame")
    assertTrue(block.frame:IsShown(), label .. ": the block shown, as AceGUI's pool will not")
    assertFalse(block.__released == true, label)
    local kids = {}
    for i, w in ipairs(block.children) do kids[i] = w end
    assertTrue(kids[1] == band.picker and kids[2] == band.action and kids[3] == band.toggle,
        label .. ": picker, New group, then the checkbox, each the block's child")
    for i, w in ipairs(kids) do
        assertFalse(w.__released == true, label .. ": " .. w.type .. " live")
        assertEqual(w.relativeWidth, BAND_WIDTHS[i], label .. ": " .. w.type .. "'s share of the one row")
        assertTrue(w.frame:IsShown(), label .. ": " .. w.type .. " shown, by the block's AddChild")
        if type(block.width) == "number" then
            assertEqual(w.width, BAND_WIDTHS[i] * block.width, label .. ": " .. w.type .. " sized by the block's layout")
        end
    end
end

test("groups page: [band] the picker, New group and Preview while editing are one SimpleGroup's, after a group switch too", function()
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return {} end
    NS.Situation.RefreshNow("test")
    local P = dofile("tests/page_helpers.lua")(NS, m)
    local restore = recordParents(m)
    local first = NS.Library.CreateGroup({ name = "First" })
    local second = NS.Library.CreateGroup({ name = "Second" })
    pick(NS, first)
    P.show("Groups")
    local ctx = P.ctx("groups")
    local band = ctx.qcBand
    -- red under: place the widgets in the header frame by hand again (no block, no AddChild)
    assertBand(band, "first render")
    local header = band.block.frame.qcParent
    -- The header's width reaches the layout: the block is a SimpleGroup laid out at 300 otherwise.
    header:__setGeom(640, 72)
    local laid = band.block.layoutCount or 0
    header:__fire("OnSizeChanged", 640, 72)
    assertEqual(band.block.width, 640, "the band's width, through SetWidth")
    assertTrue((band.block.layoutCount or 0) > laid, "and laid out again")
    assertBand(band, "after the header's width arrived")
    header:__fire("OnSizeChanged", 640, 80)
    assertEqual(band.block.layoutCount, laid + 1, "a height change alone lays out nothing")
    -- A group switch through the picker redraws the page on the next frame.
    band.picker:__fire("OnValueChanged", second)
    P.flush()
    local again = ctx.qcBand
    assertTrue(again ~= band, "a new band")
    assertBand(again, "after a group switch")
    assertEqual(again.picker.value, second)
    assertTrue(again.block.frame.qcParent == header, "the same header frame")
    assertEqual(again.block.width, 640, "a header that has a width passes it on at the build")
    assertTrue(band.block.__released == true, "the last render's block went back to AceGUI")
    -- a released block's hook is not the band's any more
    local w = band.block.width
    header:__fire("OnSizeChanged", 700, 72)
    assertEqual(band.block.width, w)
    assertEqual(again.block.width, 700)
    restore()
end)

test("groups page: General draws the group's rows, no Preview as; Duplicate and Delete act", function()
    local NS, _, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    pick(NS, gid)
    local w = P.redraw("groups")
    -- red under: draw state.previewAs on the group's General tab again
    assertTrue(P.find(w, "Dropdown", "Preview as") == nil, "Preview as is in General › Master controls")
    local tip = P.ctx("groups").panel.defaultsTooltip
    -- red under: keep "turn Preview as off" in the Defaults tooltip (the row left the page)
    assertTrue(tip:find("Preview as", 1, true) == nil, "Defaults no longer reaches Preview as")
    P.find(w, "EditBox", "Name"):__fire("OnEnterPressed", "Kicks")
    assertEqual(NS.db.profile.groups[gid].name, "Kicks")
    P.find(w, "CheckBox", "Enable this group"):__fire("OnValueChanged", false)
    assertFalse(NS.db.profile.groups[gid].enabled)
    P.find(w, "Button", "Duplicate group"):__fire("OnClick")
    local copy = NS.State.editing.group
    assertTrue(copy ~= gid and NS.db.profile.groups[copy] ~= nil)
    w = P.redraw("groups")
    P.find(w, "Button", "Delete group…"):__fire("OnClick")
    P.accept()
    assertNil(NS.db.profile.groups[copy])
end)

test("groups page: Callouts drags to reorder, removes, and copies a seeded callout in (P2)", function()
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
    local lust = T.seeded(NS, "bi.mplus.lust")
    P.find(w, "Dropdown", "Reuse callout"):__fire("OnValueChanged", lust)
    P.find(w, "Button", "Add"):__fire("OnClick")
    local copied = NS.db.profile.groups[gid].callouts[2]
    assertTrue(copied:match("^c%d+$") ~= nil and copied ~= lust, "a copy, never the seeded callout itself")
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

test("groups page: Reuse lists every callout as <group>: <callout>, a seeded one too", function()
    local NS, _, P = open()
    local gid, kick, _, lust = withCallouts(NS)
    local byId = {}
    for _, e in ipairs(NS.addon.Settings.Groups.ReusableCallouts(gid)) do byId[e.id] = e end
    -- red under: label a user callout by its name alone
    assertEqual(byId[lust].plain, "Other: Lust")
    assertEqual(byId[T.seeded(NS, "bi.mplus.lust")].plain, NS.BuiltIns.groups["bi.mplus"].name .. ": Lust")
    assertNil(byId["bi.mplus.lust"], "no shipped id is offered")
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

test("groups page: Reuse on a seeded group leaves out its own callouts; another group offers them", function()
    local NS = open()
    local G = NS.addon.Settings.Groups
    local mplus, lust = T.seeded(NS, "bi.mplus"), T.seeded(NS, "bi.mplus.lust")
    local function offered(gid, id)
        for _, e in ipairs(G.ReusableCallouts(gid)) do if e.id == id then return true end end
        return false
    end
    assertFalse(offered(mplus, lust), "the set's own callouts are already its")
    local other = NS.Library.CreateGroup({ name = "Other" })
    assertTrue(offered(other, lust), "another group still offers them")
end)

test("groups page: Reuse draws the group part in muted gold and the callout name in white", function()
    local NS = open()
    local _, kick, other = withCallouts(NS)
    local G = NS.addon.Settings.Groups
    local byId = {}
    for _, e in ipairs(G.ReusableCallouts(other)) do byId[e.id] = e end
    -- red under: leave the Reuse labels uncolored
    assertEqual(G.MutedGold(), "|cffc9a66b", "the skin's log.tag, exact under Ka0s Default")
    assertEqual(byId[kick].label, "|cffc9a66bMine|r: Kick")
    -- a seeded node is a group like any other: its own name is the group part
    assertEqual(byId[T.seeded(NS, "bi.bg.ab.stables.attack")].label, "|cffc9a66bArathi Basin: Stables|r: Attack")
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

test("groups page: [characterization] Reuse's fallbacks: a nameless group or callout by its id, a callout no group holds", function()
    local NS = open()
    local p = NS.db.profile
    local gid, kick, other, lust = withCallouts(NS)
    local nameless = NS.Library.CreateCalloutIn(other, { name = "Zap", text = "z", channel = "party" })
    p.callouts[nameless].name = nil
    p.groups[gid].name = nil
    p.callouts.orphan = { name = "Stray", text = "s", channel = "party" }
    local byId, order = {}, {}
    for i, e in ipairs(NS.addon.Settings.Groups.ReusableCallouts(other)) do byId[e.id], order[e.id] = e, i end
    -- red under: G.ReusableCallouts' helpers losing a fallback or the group-less entry (performance-§11)
    assertEqual(byId[kick].plain, gid .. ": Kick", "a nameless group reads as its id")
    assertEqual(byId[kick].label, NS.addon.Settings.Groups.MutedGold() .. gid .. "|r: Kick")
    assertEqual(byId.orphan.plain, "Stray", "a callout no group holds has no group part")
    assertEqual(byId.orphan.label, "Stray", "and no color")
    assertEqual(order.orphan, 1, "no group sorts as the empty group, first")
    assertNil(byId[lust], "the group's own")
    assertNil(byId[nameless], "the group's own, nameless too")
    byId = {}
    for _, e in ipairs(NS.addon.Settings.Groups.ReusableCallouts(gid)) do byId[e.id] = e end
    assertEqual(byId[nameless].plain, "Other: " .. nameless, "a nameless callout reads as its id")
    assertNil(byId[kick])
    assertTrue(byId[kick] == nil and byId[lust].group == nil and byId[lust].name == nil, "only id, label, plain")
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

test("groups page: [review] Reuse names a node's callout with its battleground, so two sets' Farm nodes read apart", function()
    local NS = open()
    local abFarm, dwgFarm = T.seeded(NS, "bi.bg.ab.farm"), T.seeded(NS, "bi.bg.dwg.farm")
    local a, d = NS.Library.Group(abFarm).callouts[1], NS.Library.Group(dwgFarm).callouts[1]
    local mine = NS.Library.CreateGroup({ name = "Mine" })
    local labels = {}
    for _, e in ipairs(NS.addon.Settings.Groups.ReusableCallouts(mine)) do labels[e.id] = e.plain end
    local name = NS.Library.Callout(a).name
    -- red under: label a child group's callouts with the child's name alone in G.ReusableCallouts
    assertEqual(labels[a], "Arathi Basin: Farm: " .. name)
    assertEqual(labels[d], "Deepwind Gorge: Farm: " .. NS.Library.Callout(d).name)
    assertTrue(labels[a] ~= labels[d])
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
    local delete = P.find(w, "Button", "Delete group…")
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

test("groups page: a seeded set's General is any group's: Name, Enable this group, the icon, Parent group, Duplicate, Delete group", function()
    local NS, _, P = open()
    local raid = T.seeded(NS, "bi.raid")
    pick(NS, raid)
    local w = P.redraw("groups")
    -- red under: draw a seeded group's General as the built-ins' read-only one
    assertTrue(not P.hasText(w, "is a built-in set"))
    assertNil(P.find(w, "Button", "Customize"))
    P.find(w, "EditBox", "Name"):__fire("OnEnterPressed", "Raid night")
    assertEqual(NS.db.profile.groups[raid].name, "Raid night")
    P.find(w, "CheckBox", "Enable this group"):__fire("OnValueChanged", false)
    assertFalse(NS.db.profile.groups[raid].enabled)
    assertTrue(P.find(w, "Dropdown", "Parent group") ~= nil)
    assertTrue(P.find(w, "Button", "Choose icon…") ~= nil)
    assertTrue(P.find(w, "Button", "Duplicate group") ~= nil)
    P.find(w, "Button", "Delete group…"):__fire("OnClick")
    P.accept()
    assertNil(NS.db.profile.groups[raid], "a seeded group is deleted as any other")
end)

test("groups page: a seeded set's Callouts tab is the callout table: Add callout, Reuse, a row per callout", function()
    local NS, _, P = open()
    local lists = P.reorderSpy()
    local mplus = T.seeded(NS, "bi.mplus")
    pick(NS, mplus)
    local w = P.tab("groups", "callouts")
    -- red under: draw a seeded group's Callouts tab as the built-ins' show/hide checkboxes
    assertNil(P.find(w, "CheckBox", "Pulling"), "no show/hide checkboxes")
    assertTrue(P.find(w, "Button", "Add callout") ~= nil)
    assertTrue(P.find(w, "Dropdown", "Reuse callout") ~= nil)
    assertEqual(lists[#lists].rows, #NS.BuiltIns.groups["bi.mplus"].callouts)
    lists[#lists].opts.onMove(1, 2)
    assertEqual(NS.db.profile.groups[mplus].callouts[2], T.seeded(NS, "bi.mplus.pull"), "dragged")
    w = P.tab("groups", "callouts")
    P.glyph(w, "remove", 1):__fire("OnClick")
    P.accept()
    assertEqual(#NS.db.profile.groups[mplus].callouts, #NS.BuiltIns.groups["bi.mplus"].callouts - 1)
end)

test("groups page: a seeded set's When tab edits it as any group's; Preview bakes each callout", function()
    local NS, _, P = open(MPLUS)
    local mplus = T.seeded(NS, "bi.mplus")
    pick(NS, mplus)
    local w = P.tab("groups", "When")
    assertTrue(P.hasText(w, "Active now."))
    -- red under: describe a seeded group's When as read-only text, as the built-ins' was
    assertTrue(not P.hasText(w, "conditions are fixed"))
    P.drawer(w, "Content"):__fire("OnClick")
    w = P.tab("groups", "When")
    local raid = P.find(w, "CheckBox", "Raid")
    assertTrue(raid ~= nil, "the Content row's choices, as a user group's")
    raid:__fire("OnValueChanged", true)
    assertTrue(NS.db.profile.groups[mplus].when.content.raid)
    assertTrue(NS.db.profile.groups[mplus].when.content.mythicPlus)
    local cid = NS.Library.CreateCallout({ name = "Pull", text = "Pulling", channel = "party" })
    local gid = NS.Library.CreateGroup({ name = "Mine", callouts = { cid } })
    pick(NS, gid)
    w = P.tab("groups", "preview")
    assertTrue(P.find(w, "Label", "Sends: /p Pulling") ~= nil)
end)

test("groups page: [review 5] the When tab refuses an upside-down key-level range", function()
    local NS, m, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine", when = { keyLevel = { min = 12 } } })
    pick(NS, gid)
    NS.State.whenOpen[gid] = { keyLevel = true }
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

test("groups page: [review] a child's Defaults keeps it inside its parent; a named reset takes it out", function()
    local NS, _, P = open()
    local a = NS.Library.CreateGroup({ name = "Raid night" })
    local b = NS.Library.CreateGroup({ name = "Boss 1" })
    assertTrue(NS.SchemaRuntime.Set("group.parent", a, b))
    pick(NS, b)
    P.redraw("groups")
    -- red under: drop group.parent from settings/Schema.lua resetExempt
    P.ctx("groups").panel.defaultsOnClick()
    assertEqual(NS.db.profile.groups[b].parent, a, "the page's Defaults keeps the parent, as it keeps the icon")
    NS.addon:OnSlashCommand("reset group.parent " .. b)
    assertFalse(NS.Library.IsChild(b), "a named reset makes it top-level")
end)

test("groups page: [inherit] a child's Defaults ticks Inherit when conditions again and keeps its own When", function()
    local NS, _, P = open()
    local a = NS.Library.CreateGroup({ name = "Raid night", when = { content = { raid = true } } })
    local b = NS.Library.CreateGroup({ name = "Boss 1", when = { role = { TANK = true } } })
    assertTrue(NS.SchemaRuntime.Set("group.parent", a, b))
    assertTrue(NS.SchemaRuntime.Set("group.inheritWhen", false, b))
    pick(NS, b)
    P.redraw("groups")
    -- red under: exempt group.inheritWhen from the page's Defaults
    P.ctx("groups").panel.defaultsOnClick()
    local g = NS.db.profile.groups[b]
    assertTrue(g.inheritWhen == true, "the page's Defaults turns Inherit when conditions back on")
    assertTrue(g.when.role.TANK, "the child's own When is kept")
    assertNil(g.when.content, "and not replaced by the parent's")
    assertEqual(g.parent, a, "still inside its parent")
end)

test("groups page: [restore] Restore built-in groups brings back a deleted set and says so; again, nothing is missing", function()
    local NS, m, P = open()
    local old = T.seeded(NS, "bi.raid")
    NS.Library.DeleteGroup(old)
    pick(NS, T.seeded(NS, "bi.mplus"))
    local w = P.redraw("groups")
    local restore = P.find(w, "Button", "Restore built-in groups")
    -- red under: no Restore built-in groups button on General
    assertTrue(restore ~= nil)
    m.prints = {}
    restore:__fire("OnClick")
    local raid = T.seeded(NS, "bi.raid")
    assertTrue(raid ~= nil and raid ~= old)
    local pad = NS.db.profile.pads.p1.groups
    assertEqual(pad[#pad], raid, "at the end of the pad")
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("1 groups and 8 callouts came back", 1, true) ~= nil, text)
    m.prints = {}
    P.flush()
    P.find(P.redraw("groups"), "Button", "Restore built-in groups"):__fire("OnClick")
    assertTrue(table.concat(m.prints, "\n"):find("nothing to restore", 1, true) ~= nil)
end)

test("groups page: [restore] with every group deleted, General still offers Restore built-in groups", function()
    local NS, _, P = open()
    for id in pairs(NS.db.profile.groups) do
        if NS.db.profile.groups[id] then NS.Library.DeleteGroup(id) end
    end
    assertTrue(next(NS.db.profile.groups) == nil)
    local w = P.redraw("groups")
    assertTrue(P.hasText(w, "No groups yet"))
    P.find(w, "Button", "Restore built-in groups"):__fire("OnClick")
    assertEqual(#NS.db.profile.pads.p1.groups, #NS.BuiltIns.order, "every set is back on the pad")
    assertTrue(T.seeded(NS, "bi.bg.ab.stables") ~= nil, "nodes too")
end)

test("groups page: [final 12] Duplicate says the copy is on no pad yet", function()
    local NS, m, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    pick(NS, gid)
    local w = P.redraw("groups")
    m.prints = {}
    -- red under: drop the printed line from G.Duplicate
    P.find(w, "Button", "Duplicate group"):__fire("OnClick")
    assertTrue(table.concat(m.prints, "\n"):find("the copy is on no pad yet", 1, true) ~= nil)
end)

test("groups page: [nesting] a child's Duplicate tooltip says the copy sits in the same parent", function()
    local NS, m, P = open()
    local a = NS.Library.CreateGroup({ name = "Parent" })
    local c = NS.Library.CreateGroup({ name = "Child" })
    NS.SchemaRuntime.Set("group.parent", a, c)
    pick(NS, c)
    local w = P.redraw("groups")
    P.find(w, "Button", "Duplicate group"):__fire("OnEnter")
    local said = {}
    for _, line in ipairs(m.GameTooltip.__lines) do said[#said + 1] = line[1] end
    said = table.concat(said, "\n")
    -- red under: the top-level group's tooltip on a child
    assertTrue(said:find("sits in the same parent group", 1, true) ~= nil, said)
    assertTrue(said:find("on no pad", 1, true) == nil, said)
    pick(NS, a)
    w = P.redraw("groups")
    P.find(w, "Button", "Duplicate group"):__fire("OnEnter")
    said = {}
    for _, line in ipairs(m.GameTooltip.__lines) do said[#said + 1] = line[1] end
    assertTrue(table.concat(said, "\n"):find("on no pad", 1, true) ~= nil, "a top-level group's is unchanged")
end)

test("groups page: [drawers] the When tab draws one drawer per condition, closed, each with its summary", function()
    local NS, _, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine", when = { content = { raid = true, dungeon = true } } })
    pick(NS, gid)
    local w = P.tab("groups", "When")
    assertTrue(P.hasText(w, "Not active now"), "the live line stays on top")
    assertTrue(P.hasText(w, "Every condition you set must match. A condition left as Any does not limit the group."))
    -- red under: keep the enable checkbox per condition
    assertNil(P.find(w, "CheckBox", "Content"), "no enable checkbox")
    assertEqual(table.concat(P.drawers(w), ","),
        "Content,Instance,Difficulty,Key level,Group,Leader or assist,Class,Specialization,Role,Character,Battleground,Arena")
    local content = P.drawer(w, "Content")
    assertTrue(content.__ka0sDrawerSet, "a set condition reads gold")
    assertEqual(content.__ka0sDrawerSummary, "Dungeon, Raid")
    assertFalse(content.__ka0sDrawerOpen)
    local role = P.drawer(w, "Role")
    assertFalse(role.__ka0sDrawerSet)
    assertEqual(role.__ka0sDrawerSummary, "Any")
    -- red under: draw the choices of a set condition with its drawer closed
    assertNil(P.find(w, "CheckBox", "Raid"), "closed: the choices are not drawn")
end)

test("groups page: [drawers] a header opens and closes its drawer; the open set is per group and survives a repaint", function()
    local NS, _, P = open()
    local a = NS.Library.CreateGroup({ name = "A" })
    local b = NS.Library.CreateGroup({ name = "B" })
    pick(NS, a)
    local w = P.tab("groups", "When")
    P.drawer(w, "Content"):__fire("OnClick")
    P.drawer(w, "Role"):__fire("OnClick")
    -- red under: an onToggle that stores nothing in NS.State.whenOpen
    assertTrue(NS.State.whenOpen[a].content)
    w = P.redraw("groups")
    assertTrue(P.drawer(w, "Content").__ka0sDrawerOpen, "still open after a repaint")
    assertTrue(P.drawer(w, "Role").__ka0sDrawerOpen, "several open at once")
    assertTrue(P.find(w, "CheckBox", "Raid") ~= nil, "the Content choices")
    assertTrue(P.find(w, "CheckBox", "Healer") ~= nil, "the Role choices")
    assertEqual(#P.all(w, "Button", "Select all"), 2)
    assertEqual(#P.all(w, "Button", "Clear (Any)"), 2)
    pick(NS, b)
    w = P.tab("groups", "When")
    assertFalse(P.drawer(w, "Content").__ka0sDrawerOpen, "another group's drawers are its own")
    pick(NS, a)
    w = P.tab("groups", "When")
    P.drawer(w, "Content"):__fire("OnClick")
    w = P.tab("groups", "When")
    assertFalse(P.drawer(w, "Content").__ka0sDrawerOpen)
    assertNil(P.find(w, "CheckBox", "Raid"))
end)

test("groups page: [drawers] Select all ticks every value; Clear (Any) unsets the condition and keeps the drawer open", function()
    local NS, _, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine", when = { content = { raid = true } } })
    pick(NS, gid)
    NS.State.whenOpen[gid] = { content = true }
    local w = P.tab("groups", "When")
    -- red under: a Select all that writes nothing
    P.find(w, "Button", "Select all"):__fire("OnClick")
    for _, token in ipairs(NS.Resolver.TOKENS.content) do
        assertTrue(NS.db.profile.groups[gid].when.content[token], token)
    end
    w = P.tab("groups", "When")
    -- red under: a Clear (Any) that writes nothing
    P.find(w, "Button", "Clear (Any)"):__fire("OnClick")
    assertNil(NS.db.profile.groups[gid].when.content, "unset")
    assertTrue(NS.State.whenOpen[gid].content, "the drawer stays open")
    w = P.tab("groups", "When")
    assertEqual(P.drawer(w, "Content").__ka0sDrawerSummary, "Any")
end)

test("groups page: [drawers] an id or key-level drawer has Clear (Any) alone, and Clear unsets it", function()
    local NS, _, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine",
        when = { instances = { [2526] = true }, keyLevel = { min = 10 } } })
    pick(NS, gid)
    NS.State.whenOpen[gid] = { instances = true }
    local w = P.tab("groups", "When")
    -- red under: offer Select all on an id list
    assertNil(P.find(w, "Button", "Select all"))
    assertTrue(P.find(w, "EditBox", "Add an instance") ~= nil, "the id list is in the drawer")
    assertEqual(P.drawer(w, "Key level").__ka0sDrawerSummary, "10 or higher")
    P.find(w, "Button", "Clear (Any)"):__fire("OnClick")
    assertNil(NS.db.profile.groups[gid].when.instances)
    NS.State.whenOpen[gid] = { keyLevel = true }
    w = P.tab("groups", "When")
    assertTrue(P.find(w, "EditBox", "Lowest key level") ~= nil)
    assertNil(P.find(w, "Button", "Select all"))
    P.find(w, "Button", "Clear (Any)"):__fire("OnClick")
    assertNil(NS.db.profile.groups[gid].when.keyLevel)
end)

local DUNGEON = { inInstance = true, instanceType = "party", difficultyID = 2, instanceID = 2526, inGroup = true }

test("groups page: [final 20] the Instances row adds a typed id, removes one, and refuses a fraction or a negative", function()
    local NS, _, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    pick(NS, gid)
    local w = P.tab("groups", "When")
    P.drawer(w, "Instance"):__fire("OnClick")
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
    Ed.Select("group", T.seeded(NS, "bi.mplus"))
    w = P.redraw("groups")
    assertTrue(P.find(w, "Button", "Choose icon…") ~= nil, "a seeded group's icon is chosen as any group's")
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

-- The row's label (B5): the name in gold, the channel's short label in its chat color, then the
-- text in muted white, cut at 40 characters.
local function calloutRow(P, w, icon)
    for _, label in ipairs(P.all(w, "Label")) do
        if label.image and label.image[1] == icon then return label end
    end
    return nil
end

test("groups page: [rows] a callout row reads gold name, the channel in its chat color, then the text", function()
    local NS, _, P = open()
    local lists = P.reorderSpy()
    local star = NS.Icon("star")
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.Library.CreateCalloutIn(gid, { name = "Star", text = "go", channel = "party", icon = star })
    NS.Library.CreateCalloutIn(gid, { name = "Warn", text = "move", channel = "raidWarning", icon = star })
    pick(NS, gid)
    local w = P.tab("groups", "callouts")
    local rows = {}
    for _, label in ipairs(P.all(w, "Label")) do
        if label.image and label.image[1] == star then rows[#rows + 1] = label end
    end
    -- red under: calloutLabel's old "%s  |cff808080%s|r" (the raw kind id in gray)
    assertEqual(rows[1].text, "|cffffd100Star|r  |cffababffParty|r  |cffb3b3b3go|r")
    assertEqual(rows[2].text, "|cffffd100Warn|r  |cffff4700Raid warning|r  |cffb3b3b3move|r")
    -- red under: Ed.ReorderRows' ghostText without entry.ghost
    assertEqual(lists[#lists].specs[1].ghostText, "Star", "the drag copy carries the plain name")
end)

test("groups page: [rows] a callout row cuts its text at 40 characters, escapes |, and shows the fallback icon", function()
    local NS, _, P = open()
    local Ed = NS.addon.Settings.Editors
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.Library.CreateCalloutIn(gid, { name = "Long", text = "a|b" .. ("x"):rep(50), channel = "smartGroup" })
    pick(NS, gid)
    local w = P.tab("groups", "callouts")
    -- red under: the row's icon only when the callout has one
    local row = calloutRow(P, w, Ed.NO_ICON)
    assertTrue(row ~= nil, "a callout with no icon shows the question mark")
    -- solo: a smart kind resolves to nothing and takes PARTY's color
    assertEqual(row.text, "|cffffd100Long|r  |cffababffSmart group|r  |cffb3b3b3a||b" .. ("x"):rep(37) .. "…|r")
end)

test("groups page: [rows] a callout row's text cut counts UTF-8 characters, not bytes", function()
    local NS, _, P = open()
    local Ed = NS.addon.Settings.Editors
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.Library.CreateCalloutIn(gid, { name = "Uni", text = ("é"):rep(45), channel = "say" })
    pick(NS, gid)
    local row = calloutRow(P, P.tab("groups", "callouts"), Ed.NO_ICON)
    assertEqual(row.text, "|cffffd100Uni|r  |cffffffffSay|r  |cffb3b3b3" .. ("é"):rep(40) .. "…|r")
    -- a text at the limit is not cut
    local exact = NS.Library.CreateCalloutIn(gid, { name = "Exact", text = ("y"):rep(40), channel = "say" })
    assertTrue(exact ~= nil)
    local found
    for _, label in ipairs(P.all(P.tab("groups", "callouts"), "Label")) do
        if label.text == "|cffffd100Exact|r  |cffffffffSay|r  |cffb3b3b3" .. ("y"):rep(40) .. "|r" then found = true end
    end
    assertTrue(found, "40 characters exactly: no ellipsis")
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
