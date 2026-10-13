-- tests/test_page_share.lua — settings/Share.lua (spec §13.1, §12.2): the Built-in tab. Each shipped set
-- is one line: Enabled, Customize, Choose callouts. Defaults turns every set back on. Driven headlessly
-- through tests/page_helpers.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

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
    local w = P.redraw("share")
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
    local w = P.redraw("share")
    local buttons = P.all(w, "Button", "Customize")
    local index
    for i, gid in ipairs(NS.BuiltIns.order) do if gid == "bi.mplus" then index = i end end
    buttons[index]:__fire("OnClick")
    local copy = NS.State.editing.group
    assertTrue(NS.db.profile.groups[copy] ~= nil)
    assertEqual(NS.db.profile.pads.p1.groups[1], copy, "bi.mplus was first; the copy is first")
    assertFalse(NS.db.profile.builtins["bi.mplus"].enabled)
    assertEqual(opened, 3)
    w = P.redraw("share")
    assertTrue(P.find(w, "Button", "Edit the copy") ~= nil)
end)

test("share page: Choose callouts opens the set on the Groups page's Callouts tab", function()
    local NS, _, P = open()
    local w = P.redraw("share")
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
