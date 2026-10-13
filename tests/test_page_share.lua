-- tests/test_page_share.lua — settings/Share.lua (spec §13.1, §15, §12.2): the Export and Import tabs
-- (phase 5) and the Built-in tab. Each shipped set is one line: Enabled, Customize, Choose callouts.
-- Defaults turns every set back on. Driven headlessly through tests/page_helpers.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function open()
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    local P = dofile("tests/page_helpers.lua")(NS, m)
    P.show("Share")
    return NS, m, P
end

test("share page: every shipped set has a line; turning M+ off takes it off the pad", function()
    local NS, _, P = open()
    local w = P.tab("share", "Built-in")
    assertEqual(#P.all(w, "Button", "Customize"), #NS.BuiltIns.order)
    local box = P.find(w, "CheckBox", "M+ (generic)")
    assertTrue(box ~= nil and box.value == true)
    box:__fire("OnValueChanged", false)
    assertFalse(NS.db.profile.builtins["bi.mplus"].enabled)
    assertTrue(NS.Pad.ChipsFor("p1", "bi.mplus.pull")[1] == nil, "the pad dropped the set")
end)

test("share page: [review 4] Customize puts the copy in the set's place, selects it and opens the Groups page", function()
    local NS, m, P = open()
    local opened
    m.Settings.OpenToCategory = function(id) opened = id end
    NS.addon.Settings.Editors.categories.groups = { GetID = function() return 3 end }
    local w = P.tab("share", "Built-in")
    local buttons = P.all(w, "Button", "Customize")
    local index
    for i, gid in ipairs(NS.BuiltIns.order) do if gid == "bi.mplus" then index = i end end
    buttons[index]:__fire("OnClick")
    local copy = NS.State.editing.group
    assertTrue(NS.db.profile.groups[copy] ~= nil)
    assertEqual(NS.db.profile.pads.p1.groups[1], copy, "bi.mplus was first; the copy is first")
    assertFalse(NS.db.profile.builtins["bi.mplus"].enabled)
    assertEqual(opened, 3)
    w = P.tab("share", "Built-in")
    assertTrue(P.find(w, "Button", "Edit the copy") ~= nil)
end)

test("share page: Choose callouts opens the set on the Groups page's Callouts tab", function()
    local NS, _, P = open()
    local w = P.tab("share", "Built-in")
    P.all(w, "Button", "Choose callouts")[1]:__fire("OnClick")
    assertEqual(NS.State.editing.group, NS.BuiltIns.order[1])
    assertEqual(NS.addon.Settings.Editors.pages.groups.activeTab, "callouts")
end)

test("share page: Defaults turns every set back on and shows all of their callouts, as one act", function()
    local NS, _, P = open()
    NS.Library.SetBuiltinEnabled("bi.raid", false)
    NS.Library.SetBuiltinCalloutHidden("bi.mplus", "bi.mplus.lust", true)
    local changes, rebuilds = 0, 0
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.LIBRARY_CHANGED, function() changes = changes + 1 end)
    local request = NS.Surfaces.Request
    NS.Surfaces.Request = function(...) rebuilds = rebuilds + 1 return request(...) end
    P.ctx("share").panel.defaultsOnClick()
    NS.Surfaces.Request = request
    assertTrue(NS.db.profile.builtins["bi.raid"].enabled)
    assertTrue(next(NS.db.profile.builtins["bi.mplus"].hidden) == nil)
    -- red under: drop Lib.Batch from SH.RestoreAll (one announce, and one rebuild, per set and field)
    assertEqual(changes, 1)
    assertTrue(rebuilds <= 1, "one pad rebuild")
end)

-- ── Export and Import (phase 5) ─────────────────────────────────────────────────────────────

-- A group of two callouts of the player's own, on no surface.
local function mine(NS)
    local Lib = NS.Library
    local a = Lib.CreateCallout({ name = "Kick", text = "Kick on me {rt8}", channel = "party" })
    local b = Lib.CreateCallout({ name = "Lust", text = "Lust now", channel = "smartGroup" })
    return Lib.CreateGroup({ name = "My keys", callouts = { a, b } }), a, b
end

-- The copy window, recorded: the export's string lands in `shown.text`.
local function spyWindow(NS)
    local shown = {}
    NS.Share.Window = function() return { Show = function(_, text) shown.text = text end } end
    return shown
end

test("share page: [phase 5] Export ticks a group; its callouts come along, and the string opens in the copy window", function()
    local NS, _, P = open()
    local gid = mine(NS)
    local shown = spyWindow(NS)
    local w = P.tab("share", "Export")
    assertTrue(P.find(w, "Heading", "Groups") ~= nil)
    P.find(w, "CheckBox", "My keys"):__fire("OnValueChanged", true)
    assertTrue(P.hasText(w, "The string will hold 2 callouts, 1 group."), "the summary follows the tick in place")
    P.find(w, "Button", "Export"):__fire("OnClick")
    assertEqual(shown.text:sub(1, 5), "!QC1!")
    local payload = NS.Share.Decode(shown.text)
    assertEqual(payload.groups[gid].name, "My keys")
    assertEqual(#payload.groups[gid].callouts, 2)
end)

test("share page: [phase 5] Export with nothing ticked says so and opens nothing", function()
    local NS, m, P = open()
    local shown = spyWindow(NS)
    local w = P.tab("share", "Export")
    m.prints = {}
    P.find(w, "Button", "Export"):__fire("OnClick")
    assertNil(shown.text)
    assertTrue(table.concat(m.prints, "\n"):find("Tick at least one callout", 1, true) ~= nil)
end)

test("share page: [phase 5] Import checks a pasted string, reports it, then adds it as new members", function()
    local NS, m, P = open()
    local gid = mine(NS)
    local text = NS.Share.Encode(NS.Share.Collect({ group = { [gid] = true } }))
    local before = 0
    for _ in pairs(NS.db.profile.groups) do before = before + 1 end
    local w = P.tab("share", "Import")
    P.find(w, "MultiLineEditBox", "Share string"):__fire("OnEnterPressed", "\n" .. text .. "\n")
    assertTrue(P.hasText(w, "Ready to import: 2 callouts, 1 group."), "the report, in place")
    m.prints = {}
    P.find(w, "Button", "Import"):__fire("OnClick")
    local after = 0
    for _ in pairs(NS.db.profile.groups) do after = after + 1 end
    assertEqual(after, before + 1, "a copy, beside the original")
    assertTrue(table.concat(m.prints, "\n"):find("Imported 2 callouts, 1 group.", 1, true) ~= nil)
    assertNil(NS.State.share.import, "the checked string is spent")
end)

test("share page: [review] editing the box after Accept forgets the check: Import never adds the old string", function()
    local NS, m, P = open()
    local gid = mine(NS)
    local text = NS.Share.Encode(NS.Share.Collect({ group = { [gid] = true } }))
    local w = P.tab("share", "Import")
    local box = P.find(w, "MultiLineEditBox", "Share string")
    box:__fire("OnEnterPressed", text)
    assertTrue(P.hasText(w, "Ready to import: 2 callouts, 1 group."))
    local before = 0
    for _ in pairs(NS.db.profile.groups) do before = before + 1 end
    -- a different string pasted over it, Accept not clicked
    box:__fire("OnTextChanged", "!QC1!somethingElse")
    -- red under: no OnTextChanged callback on the box in settings/Share.lua
    assertNil(NS.State.share.import, "the old check is forgotten")
    assertTrue(P.hasText(w, "click Accept to check it"), "the report asks for Accept again")
    m.prints = {}
    P.find(w, "Button", "Import"):__fire("OnClick")
    local after = 0
    for _ in pairs(NS.db.profile.groups) do after = after + 1 end
    assertEqual(after, before, "the old string's members never arrive")
end)

test("share page: [phase 5] an imported dial says it has no key yet", function()
    local NS, m, P = open()
    NS.SchemaRuntime.Set("dial.key", "G", "d2")
    local text = NS.Share.Encode(NS.Share.Collect({ dial = { d2 = true } }))
    P.tab("share", "Import")
    NS.addon.Settings.Share.Check(text)
    m.prints = {}
    local tally = NS.addon.Settings.Share.Import()
    assertEqual(tally.dials, 1)
    assertTrue(table.concat(m.prints, "\n"):find("An imported dial has no key yet", 1, true) ~= nil)
    assertEqual(NS.db.profile.dials.d2.key, "G", "the original keeps its key")
end)

test("share page: [phase 5] an imported group no shared pad or dial lists says where to add it", function()
    local NS, m, P = open()
    local gid = mine(NS)
    local text = NS.Share.Encode(NS.Share.Collect({ group = { [gid] = true } }))
    P.tab("share", "Import")
    NS.addon.Settings.Share.Check(text)
    m.prints = {}
    assertTrue(NS.addon.Settings.Share.Import() ~= nil)
    -- red under: drop the looseGroups line from SH.Import in settings/Share.lua
    assertTrue(table.concat(m.prints, "\n"):find("is on no pad or dial yet", 1, true) ~= nil)
    m.prints = {}
    NS.addon.Settings.Share.Check(NS.Share.Encode(NS.Share.Collect({ dial = { d2 = true } })))
    NS.addon.Settings.Share.Import()
    assertTrue(table.concat(m.prints, "\n"):find("is on no pad or dial yet", 1, true) == nil, "a dial with no group of its own")
end)

test("share page: [phase 5] export and import are refused in combat; nothing is made or added", function()
    local NS, m = open()
    local gid = mine(NS)
    local SHP = NS.addon.Settings.Share
    SHP.Pick("group", gid, true)
    SHP.Check(NS.Share.Encode(NS.Share.Collect({ group = { [gid] = true } })))
    local shown = spyWindow(NS)
    m.inCombat = true
    m.prints = {}
    assertNil(SHP.Export())
    assertNil(SHP.Import())
    assertNil(shown.text)
    assertTrue(table.concat(m.prints, "\n"):find("Export and import are not available in combat.", 1, true) ~= nil)
    assertTrue(NS.State.share.import ~= nil, "the checked string waits for combat to end")
    m.inCombat = false
    assertTrue(SHP.Import() ~= nil)
end)

test("share page: [phase 5] a profile switch forgets the ticks and the checked string", function()
    local NS = open()
    local gid = mine(NS)
    local SHP = NS.addon.Settings.Share
    SHP.Pick("group", gid, true)
    SHP.Check("!QC1!nope")
    NS.addon.db:SetProfile("Other")
    assertFalse(SHP.Picked("group", gid))
    assertNil(NS.State.share.import)
end)

test("share page: [phase 5] the export window is the LibKa0s copy window, built once and named for the addon", function()
    local NS, m = open()
    local win = NS.Share.Window()
    assertTrue(win ~= nil and win == NS.Share.Window(), "built once")
    local f = win:Show("!QC1!abc")
    assertTrue(f:IsShown())
    assertEqual(m.__named.QuickCommsShareWindow, f)
end)
