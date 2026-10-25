-- tests/test_page_groups_nesting.lua — settings/Groups.lua, split off tests/test_page_groups.lua at
-- the layout-§1 cap (RA-09): nested groups and the Parent group row, the Preview table
-- (2026-10-18-builtins-as-groups-design.md, goals 2 and 3), Inherit when conditions
-- (2026-10-18-when-drawers-design.md §3) and a pad title's right-click landing on the Groups page
-- (groups polish R4). Driven headlessly through tests/page_helpers.lua, as its parent suite is.

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

-- The seeded groups and callouts taken away (and so off every surface), for a case about the
-- player's own groups alone. seededSets stays, so nothing is seeded back.
local function bare(NS)
    local p = NS.db.profile
    for id in pairs(p.groups) do p.groups[id] = nil end
    for id in pairs(p.callouts) do p.callouts[id] = nil end
    for _, s in pairs(p.pads) do s.groups = {} end
    for _, s in pairs(p.dials) do s.groups = {} end
end

-- ── nested groups (2026-10-18-builtins-as-groups-design.md, goal 2) ──────────────────────────

test("groups page: [nesting] General's Parent group offers the top-level groups but itself; a pick nests the group", function()
    local NS, _, P = open()
    bare(NS)
    local Lib = NS.Library
    local a = Lib.CreateGroup({ name = "Alpha" })
    local b = Lib.CreateGroup({ name = "Bravo" })
    local c = Lib.CreateGroup({ name = "Charlie" })
    NS.SchemaRuntime.Set("group.parent", a, c)
    pick(NS, b)
    local w = P.redraw("groups")
    local dd = P.find(w, "Dropdown", "Parent group")
    -- red under: no Parent group dropdown on General
    assertTrue(dd ~= nil)
    local G = NS.addon.Settings.Groups
    assertEqual(table.concat(dd.order, ","), G.NO_PARENT .. "," .. a, "none, then Alpha: not itself, not a child")
    assertEqual(dd.list[G.NO_PARENT], "None")
    assertEqual(dd.value, G.NO_PARENT)
    assertFalse(dd.disabled)
    dd:__fire("OnValueChanged", a)
    assertEqual(NS.db.profile.groups[b].parent, a)
    P.flush()
    w = P.redraw("groups")
    dd = P.find(w, "Dropdown", "Parent group")
    assertEqual(dd.value, a)
    dd:__fire("OnValueChanged", G.NO_PARENT)
    assertFalse(NS.db.profile.groups[b].parent, "None takes it out again")
end)

test("groups page: [nesting] a group that holds groups cannot take a parent: the dropdown is idle and says why", function()
    local NS, _, P = open()
    local Lib = NS.Library
    local a = Lib.CreateGroup({ name = "Alpha" })
    local c = Lib.CreateGroup({ name = "Charlie" })
    NS.SchemaRuntime.Set("group.parent", a, c)
    pick(NS, a)
    local w = P.redraw("groups")
    local dd = P.find(w, "Dropdown", "Parent group")
    -- red under: the dropdown live on a parent
    assertTrue(dd.disabled)
    assertTrue(NS.addon.Settings.Groups.ParentTooltip(a):find("Charlie", 1, true) ~= nil, "names the groups it holds")
end)

test("groups page: [nesting] the picker lists each child indented under its parent", function()
    local NS = open()
    bare(NS)
    local Lib = NS.Library
    local z = Lib.CreateGroup({ name = "Zed" })
    local a = Lib.CreateGroup({ name = "Alpha" })
    local k = Lib.CreateGroup({ name = "Kid" })
    NS.SchemaRuntime.Set("group.parent", z, k)
    local entries = NS.addon.Settings.Groups.Entries()
    assertEqual(entries[1].id, a)
    assertEqual(entries[2].id, z)
    assertEqual(entries[3].id, k)
    local indent = NS.addon.Settings.Groups.CHILD_INDENT
    -- red under: Entries drawing a child's label like a top-level group's
    assertEqual(entries[3].label:sub(1, #indent), indent)
    assertTrue(entries[3].label:find("Kid", 1, true) ~= nil)
    assertTrue(entries[2].label:sub(1, #indent) ~= indent, "a top-level group is not indented")
end)

test("groups page: [nesting] deleting a parent asks, saying its groups become top-level groups in its place", function()
    local NS, m, P = open()
    local Lib = NS.Library
    local a = Lib.CreateGroup({ name = "Alpha" })
    local c = Lib.CreateGroup({ name = "Charlie" })
    NS.SchemaRuntime.Set("group.parent", a, c)
    pick(NS, a)
    local w = P.redraw("groups")
    P.find(w, "Button", "Delete group…"):__fire("OnClick")
    local which = m.popupsShown[#m.popupsShown][1]
    -- red under: G.Delete asking with the plain group text
    assertTrue(m.StaticPopupDialogs[which].text:find("top-level", 1, true) ~= nil)
    P.accept()
    assertNil(NS.db.profile.groups[a])
    assertFalse(NS.db.profile.groups[c].parent)
end)

test("groups page: [nesting] a pad's and a dial's Add group leave out a child", function()
    local NS = open()
    local Lib = NS.Library
    local a = Lib.CreateGroup({ name = "Alpha" })
    local c = Lib.CreateGroup({ name = "Charlie" })
    NS.SchemaRuntime.Set("group.parent", a, c)
    local S = NS.addon.Settings
    local function has(list, id)
        for _, e in ipairs(list) do if e.id == id then return true end end
        return false
    end
    -- red under: AddableGroups listing every user group
    assertFalse(has(S.Pads.AddableGroups("p1"), c))
    assertFalse(has(S.Dials.AddableGroups("d2"), c))
    assertTrue(has(S.Pads.AddableGroups("p1"), a))
end)

-- ── the Preview table (2026-10-18-builtins-as-groups-design.md, goal 3) ──────────────────────

-- The widget among `widgets` whose children hold `child`.
local function rowOf(widgets, child)
    for _, x in ipairs(widgets) do
        for _, c in ipairs(x.children or {}) do if c == child then return x end end
    end
    return nil
end

test("groups page: [preview table] Preview is the active-now line, then a table: each callout's name beside what it sends", function()
    local NS, _, P = open(MPLUS)
    local lists = P.reorderSpy()
    local pull = NS.Library.CreateCallout({ name = "Pull", text = "Pulling", channel = "party" })
    local lust = NS.Library.CreateCallout({ name = "Lust", text = "Lust now", channel = "party" })
    local gid = NS.Library.CreateGroup({ name = "Mine", callouts = { pull, lust } })
    pick(NS, gid)
    local w = P.tab("groups", "preview")
    assertTrue(P.hasText(w, "Active now."))
    -- red under: one "<name>: <preview>" line per callout, as before
    assertFalse(P.hasText(w, "Pull: Sends"))
    assertTrue(P.find(w, "Label", "Callout") ~= nil, "the name column's header")
    assertTrue(P.find(w, "Label", "What it sends here") ~= nil, "the preview column's header")
    local name, sends = P.find(w, "Label", "Pull"), P.find(w, "Label", "Sends: /p Pulling")
    assertTrue(name ~= nil and sends ~= nil)
    local row = rowOf(w, name)
    assertEqual(row.children[2], sends, "one row: the name, then what it sends")
    assertTrue(P.find(w, "Label", "Lust") ~= nil)
    assertTrue(P.find(w, "Label", "Sends: /p Lust now") ~= nil)
    assertEqual(lists[#lists].rows, 2, "a boxed row per callout")
    assertEqual(lists[#lists].specs[1].draggable, false, "nothing to drag")
end)

test("groups page: [preview table] a group holding groups shows a titled table for its own callouts, then one per child", function()
    local NS, _, P = open(MPLUS)
    local function callout(name) return NS.Library.CreateCallout({ name = name, text = name, channel = "party" }) end
    local top = NS.Library.CreateGroup({ name = "Top", callouts = { callout("Own") } })
    local a = NS.Library.CreateGroup({ name = "Node A", callouts = { callout("A1") } })
    local b = NS.Library.CreateGroup({ name = "Node B", callouts = { callout("B1"), callout("B2") } })
    NS.SchemaRuntime.Set("group.parent", top, a)
    NS.SchemaRuntime.Set("group.parent", top, b)
    pick(NS, top)
    local lists = P.reorderSpy()
    local w = P.tab("groups", "preview")
    for _, title in ipairs({ "Top", "Node A", "Node B" }) do
        assertTrue(P.find(w, "Heading", title) ~= nil, "a section for " .. title)
    end
    assertEqual(#P.all(w, "Label", "Callout"), 3, "each table has its header")
    assertTrue(P.find(w, "Label", "Sends: /p B2") ~= nil)
    -- red under: a list per table (the page keeps one, so the others' boxes would never be reclaimed)
    assertEqual(#lists, 1, "one box list for the tab")
    assertEqual(lists[1].rows, 4, "a box per callout, across the tables")
end)

test("groups page: [review] a parent with no callouts of its own and one child titles the child's table", function()
    local NS, _, P = open(MPLUS)
    local top = NS.Library.CreateGroup({ name = "Top" })
    local kid = NS.Library.CreateGroup({ name = "Only child",
        callouts = { NS.Library.CreateCallout({ name = "K1", text = "K1", channel = "party" }) } })
    NS.SchemaRuntime.Set("group.parent", top, kid)
    pick(NS, top)
    local w = P.tab("groups", "preview")
    -- red under: title a block only when there are several sections (G.PreviewBlocks)
    assertTrue(P.find(w, "Heading", "Only child") ~= nil, "the one table is the child's, and says so")
    assertTrue(P.find(w, "Label", "K1") ~= nil)
    pick(NS, kid)
    w = P.tab("groups", "preview")
    assertNil(P.find(w, "Heading", "Only child"), "a group's own table has no title")
end)

test("groups page: [preview table] a situation change rewrites a row's text in place and lays the table out again", function()
    local NS, _, P = open(MPLUS)
    local pull = NS.Library.CreateCallout({ name = "Pull", text = "Pulling", channel = "smartGroup" })
    local gid = NS.Library.CreateGroup({ name = "Mine", callouts = { pull } })
    pick(NS, gid)
    local w = P.tab("groups", "preview")
    local sends = P.find(w, "Label", "Sends: /p Pulling")
    local scroll = NS.addon.Settings.Helpers.EnsureScroll(P.ctx("groups"))
    local before = scroll.layoutCount or 0
    local solo = {}
    for k, v in pairs(MPLUS) do solo[k] = v end
    solo.inGroup = false
    NS.Situation.ReadInputs = function() return solo end
    NS.Situation.RefreshNow("test")
    NS.addon.Settings.Editors.RefreshLive()
    -- red under: no Ed.Live for the rows (the text would stay what it was when drawn)
    assertTrue(sends.text ~= "Sends: /p Pulling", "the row says what it sends now")
    assertTrue(sends.text:find("Sends nothing here", 1, true) ~= nil)
    -- red under: set the text without a layout (a taller text would spill out of its box)
    assertTrue((scroll.layoutCount or 0) > before, "the table laid out again")
end)

test("groups page: [preview table] a group with no callouts says so, with no table", function()
    local NS, _, P = open()
    local lists = P.reorderSpy()
    local gid = NS.Library.CreateGroup({ name = "Empty" })
    pick(NS, gid)
    local w = P.tab("groups", "preview")
    assertTrue(P.hasText(w, "This group has no callouts yet."))
    assertNil(P.find(w, "Label", "Callout"), "no header for an empty table")
    assertEqual(#lists, 0, "no box list")
end)

-- ── Inherit when conditions (2026-10-18-when-drawers-design.md §3) ─────────────────────────

test("groups page: [inherit] a seeded battleground's nodes carry no green dot in the open world", function()
    local NS = open()
    local ab = T.seeded(NS, "bi.bg.ab")
    local kids = NS.Library.Children(ab)
    assertTrue(#kids > 0)
    local dotted = {}
    for _, e in ipairs(NS.addon.Settings.Groups.Entries()) do
        dotted[e.id] = e.label:find("Indicator-Green", 1, true) ~= nil
    end
    -- red under: R.ActiveGroups judging a node by its own empty When (active everywhere)
    for _, kid in ipairs(kids) do assertFalse(dotted[kid], NS.db.profile.groups[kid].name) end
    assertFalse(dotted[ab])
end)

test("groups page: [inherit] When's Inherit when conditions sits at the top of the tab, grayed out with no parent", function()
    local NS, _, P = open()
    bare(NS)
    local Lib = NS.Library
    local top = Lib.CreateGroup({ name = "Raid night" })
    local kid = Lib.CreateGroup({ name = "Boss 1" })
    pick(NS, top)
    local w = P.tab("groups", "When")
    local cb = P.find(w, "CheckBox", "Inherit when conditions")
    -- red under: no Inherit when conditions checkbox on When (item 020, QUI-L03: it was on General)
    assertTrue(cb ~= nil)
    assertTrue(cb.disabled, "a group with no parent has nothing to inherit")
    assertTrue(cb.value, "on by default")
    NS.SchemaRuntime.Set("group.parent", top, kid)
    pick(NS, kid)
    w = P.tab("groups", "When")
    cb = P.find(w, "CheckBox", "Inherit when conditions")
    assertFalse(cb.disabled)
    assertTrue(cb.value)
    NS.db.profile.groups[kid].inheritWhen = nil   -- a profile from before the setting
    w = P.tab("groups", "When")
    assertTrue(P.find(w, "CheckBox", "Inherit when conditions").value, "absent reads as on")
    P.find(w, "CheckBox", "Inherit when conditions"):__fire("OnValueChanged", false)
    assertEqual(NS.db.profile.groups[kid].inheritWhen, false, "unticking stores false")
    assertTrue(NS.addon.Settings.Editors.STRUCTURAL["group.inheritWhen"], "the When tab and the dots repaint")
end)

test("groups page: [inherit] an inheriting group's When tab shows its parent's conditions, read-only", function()
    local NS, _, P = open()
    bare(NS)
    local Lib = NS.Library
    local top = Lib.CreateGroup({ name = "Raid night", when = { content = { raid = true } } })
    local kid = Lib.CreateGroup({ name = "Boss 1", when = { role = { TANK = true } } })
    NS.SchemaRuntime.Set("group.parent", top, kid)
    pick(NS, kid)
    NS.State.whenOpen[kid] = { content = true, role = true }
    local w = P.tab("groups", "When")
    -- red under: draw the group's own When for an inheriting group
    assertTrue(P.hasText(w, "Uses Raid night's conditions. Untick Inherit when conditions above to set this group's own."))
    assertEqual(P.drawer(w, "Content").__ka0sDrawerSummary, "Raid", "the parent's")
    assertEqual(P.drawer(w, "Role").__ka0sDrawerSummary, "Any", "its own is kept but not shown")
    assertTrue(P.find(w, "CheckBox", "Raid").value)
    assertTrue(P.find(w, "CheckBox", "Raid").disabled, "read-only")
    assertNil(P.find(w, "Button", "Select all"))
    assertNil(P.find(w, "Button", "Clear (Any)"))
    assertTrue(P.hasText(w, "Not active now"), "judged by the parent's raid When")
    P.drawer(w, "Content"):__fire("OnClick")
    assertNil(NS.State.whenOpen[kid].content, "the drawers still open and close")
    NS.SchemaRuntime.Set("group.inheritWhen", false, kid)
    w = P.tab("groups", "When")
    assertTrue(not P.hasText(w, "Uses Raid night's conditions"))
    assertEqual(P.drawer(w, "Role").__ka0sDrawerSummary, "Tank", "its own again")
    assertFalse(P.find(w, "CheckBox", "Tank").disabled)
    assertTrue(P.find(w, "Button", "Select all") ~= nil)
    assertTrue(NS.db.profile.groups[kid].when.role.TANK, "its own When was kept")
end)

test("groups page: [all] the battleground drawer's All battlegrounds dims and locks the list, which it keeps", function()
    local NS, _, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine", when = { battleground = { [2107] = true } } })
    pick(NS, gid)
    NS.State.whenOpen[gid] = { battleground = true, instances = true, characters = true }
    local w = P.tab("groups", "When")
    -- red under: an id drawer with no whole-kind checkbox
    local all = P.find(w, "CheckBox", "All battlegrounds")
    assertTrue(all ~= nil, "the checkbox, on top of the drawer")
    assertFalse(all.value and true or false)
    assertFalse(P.find(w, "EditBox", "Add a battleground").disabled and true or false)
    assertTrue(P.find(w, "CheckBox", "All dungeons and raids") ~= nil, "the instance drawer has one")
    assertNil(P.find(w, "CheckBox", "All characters"), "the character drawer has none")
    all:__fire("OnValueChanged", true)
    assertTrue(NS.db.profile.groups[gid].when.battleground.all)
    assertTrue(NS.db.profile.groups[gid].when.battleground[2107], "the pick is kept")
    w = P.tab("groups", "When")
    assertTrue(P.find(w, "CheckBox", "All battlegrounds").value)
    assertEqual(P.drawer(w, "Battleground").__ka0sDrawerSummary, "All battlegrounds")
    assertTrue(P.find(w, "EditBox", "Add a battleground").disabled, "the list is locked")
    assertTrue(P.find(w, "Button", "Add the battleground you are in").disabled)
    assertFalse(P.find(w, "EditBox", "Add an instance").disabled and true or false, "the other drawers are not")
    assertFalse(P.find(w, "CheckBox", "All battlegrounds").disabled and true or false, "the checkbox itself stays live")
end)

test("groups page: [all] a gap separates the Every condition line from the first drawer", function()
    local NS, _, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    pick(NS, gid)
    local w = P.tab("groups", "When")
    local after
    for i, x in ipairs(w) do
        if (x.type == "Label" or x.type == "InteractiveLabel") and x.text and x.text:find("Every condition", 1, true) then
            after = w[i + 1]
        end
    end
    -- red under: the first drawer straight under the line
    assertTrue(after ~= nil and after.type == "SimpleGroup" and after.height == NS.addon.Settings.Helpers.ROW_VSPACER,
        "a row spacer comes first")
end)

test("groups page: [arena] the arena drawer's All arenas dims and locks the list, which it keeps", function()
    local NS, _, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine", when = { arena = { [1505] = true } } })
    pick(NS, gid)
    NS.State.whenOpen[gid] = { arena = true }
    local w = P.tab("groups", "When")
    -- red under: no arena drawer
    local all = P.find(w, "CheckBox", "All arenas")
    assertTrue(all ~= nil, "the checkbox, on top of the drawer")
    assertFalse(P.find(w, "EditBox", "Add an arena").disabled and true or false)
    assertTrue(P.find(w, "Button", "Add the arena you are in") ~= nil)
    all:__fire("OnValueChanged", true)
    assertTrue(NS.db.profile.groups[gid].when.arena.all)
    assertTrue(NS.db.profile.groups[gid].when.arena[1505], "the pick is kept")
    w = P.tab("groups", "When")
    assertEqual(P.drawer(w, "Arena").__ka0sDrawerSummary, "All arenas")
    assertTrue(P.find(w, "EditBox", "Add an arena").disabled, "the list is locked")
end)


-- ── groups polish (2026-10-19) R4: a pad title's right-click lands here ─────────────────────

local function categoryOpens(NS, m)
    local opened = {}
    NS.addon.Settings.Editors.categories.groups = { GetID = function() return 42 end }
    m.Settings.OpenToCategory = function(id) opened[#opened + 1] = id end
    return opened
end

test("groups page: [R4] EditGroup opens the Groups page on that group and keeps the tab it was on", function()
    local NS, m, P = open()
    local opened = categoryOpens(NS, m)
    local a = NS.Library.CreateGroup({ name = "Alpha" })
    local b = NS.Library.CreateGroup({ name = "Beta" })
    pick(NS, a)
    P.tab("groups", "callouts")
    -- red under: no EditGroup
    assertTrue(NS.addon:EditGroup(b))
    P.flush()
    assertEqual(NS.State.editing.group, b, "the page's own selection")
    assertEqual(P.ctx("groups").activeTab, "callouts", "the tab is remembered across groups")
    assertEqual(P.banner(P.ctx("groups")).value, b, "the dropdown reads the group")
    assertEqual(opened[#opened], 42, "the Groups category, not the main page")
end)

test("groups page: [R4] EditGroup in combat prints the settings refusal and changes nothing", function()
    local NS, m, P = open()
    local opened = categoryOpens(NS, m)
    local a = NS.Library.CreateGroup({ name = "Alpha" })
    local b = NS.Library.CreateGroup({ name = "Beta" })
    pick(NS, a)
    P.flush()
    m.__fire("PLAYER_REGEN_DISABLED")
    m.__setCombat(true)
    m.prints = {}
    assertFalse(NS.addon:EditGroup(b))
    assertEqual(NS.State.editing.group, a)
    assertEqual(#opened, 0)
    assertTrue(table.concat(m.prints, "\n"):find("cannot open settings during combat", 1, true) ~= nil)
    m.__setCombat(false)
    m.__fire("PLAYER_REGEN_ENABLED")
end)

test("groups page: [R4] EditGroup of a group that is gone opens nothing", function()
    local NS, m = open()
    local opened = categoryOpens(NS, m)
    assertFalse(NS.addon:EditGroup("nope"))
    assertFalse(NS.addon:EditGroup("test.1"))
    assertEqual(#opened, 0)
end)
