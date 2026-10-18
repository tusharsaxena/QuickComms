-- tests/test_page_share.lua — settings/Share.lua (spec §13.1, §15): the Export and Import tabs
-- (phase 5); a seeded built-in set is exported as any group is (2026-10-18-builtins-as-groups-design.md).
-- Defaults clears the page's own session state. Driven headlessly through tests/page_helpers.lua.

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

test("share page: two tabs, and a seeded set is ticked and exported as any group, its nodes with it", function()
    local NS, _, P = open()
    local w = P.tab("share", "Export")
    local box = P.find(w, "CheckBox", "Arathi Basin")
    -- red under: leave the seeded sets off the Export tab, as the built-ins were
    assertTrue(box ~= nil)
    box:__fire("OnValueChanged", true)
    local payload = NS.Share.Collect(NS.State.share.pick)
    local ab = T.seeded(NS, "bi.bg.ab")
    assertTrue(payload.groups[ab] ~= nil)
    assertEqual(payload.groups[ab].origin, nil, "no origin travels")
    local n = 0
    for _ in pairs(payload.groups) do n = n + 1 end
    assertEqual(n, 1 + #NS.Library.Children(ab), "its nodes come with it")
end)

test("share page: Defaults unticks everything and forgets the checked string; nothing in the profile changes", function()
    local NS, _, P = open()
    local SHP = NS.addon.Settings.Share
    local gid = T.seeded(NS, "bi.mplus")
    SHP.Pick("group", gid, true)
    SHP.Check(NS.Share.Encode(NS.Share.Collect({ group = { [gid] = true } })))
    local changes = 0
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.LIBRARY_CHANGED, function() changes = changes + 1 end)
    -- red under: keep SH.RestoreAll (the built-in overlay's reset) as the page's Defaults
    P.ctx("share").panel.defaultsOnClick()
    assertFalse(SHP.Picked("group", gid))
    assertNil(NS.State.share.import)
    assertEqual(changes, 0, "session state only")
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

test("share page: Export lists groups, pads and dials, and no callouts; a ticked group brings its callouts", function()
    local NS, _, P = open()
    local gid = mine(NS)
    local w = P.tab("share", "Export")
    -- red under: the callout row back in KINDS in settings/Share.lua
    assertNil(P.find(w, "Heading", "Callouts"), "no Callouts heading")
    assertNil(P.find(w, "CheckBox", "Kick"), "no checkbox for a callout")
    assertNil(P.find(w, "CheckBox", "Lust"), "no checkbox for a callout")
    assertTrue(P.find(w, "Heading", "Groups") ~= nil)
    assertTrue(P.find(w, "Heading", "Comms Pads") ~= nil)
    assertTrue(P.find(w, "Heading", "Comms Dials") ~= nil)
    assertNil(NS.State.share.pick.callout, "the ticks hold no callout kind")
    P.find(w, "CheckBox", "My keys"):__fire("OnValueChanged", true)
    assertTrue(P.hasText(w, "The string will hold 2 callouts, 1 group."), "the group brings its callouts")
    local payload = NS.Share.Collect(NS.State.share.pick)
    assertEqual(#payload.groups[gid].callouts, 2)
end)

test("share page: [phase 5] Export with nothing ticked says so and opens nothing", function()
    local NS, m, P = open()
    local shown = spyWindow(NS)
    local w = P.tab("share", "Export")
    m.prints = {}
    P.find(w, "Button", "Export"):__fire("OnClick")
    assertNil(shown.text)
    assertTrue(table.concat(m.prints, "\n"):find("Tick at least one group, pad or dial", 1, true) ~= nil)
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
