-- tests/test_page_pads.lua — settings/Pads.lua (spec §10.2-§10.4, §13.1): the pad picker and New pad,
-- General's acts, the Groups priority list, Layout with the X/Y position, and Look. Driven headlessly
-- through tests/page_helpers.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function open(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or MPLUS end
    NS.Situation.RefreshNow("test")
    local P = dofile("tests/page_helpers.lua")(NS, m)
    P.show("Comms Pad")
    NS.addon.Settings.Editors.Select("pad", "p1")
    return NS, m, P
end

local function pointOf(inst)
    local p, _, rel, x, y = inst.root:GetPoint(1)
    return table.concat({ tostring(p), tostring(rel), tostring(x), tostring(y) }, ",")
end

test("pads page: New pad makes a second pad holding every built-in, selects it, and the pad is built", function()
    local NS, _, P = open()
    P.bannerAction(P.ctx("pads")):__fire("OnClick")
    P.flush()
    local id = NS.State.editing.pad
    assertTrue(id ~= "p1" and NS.db.profile.pads[id] ~= nil)
    assertEqual(NS.db.profile.pads[id].name, "Comms Pad 2")
    assertEqual(#NS.db.profile.pads[id].groups, #NS.BuiltIns.order)
    assertTrue(NS.Pad.Instance(id) ~= nil, "built by the rebuild LIBRARY_CHANGED asked for")
end)

test("pads page: the Layout rows write the selected pad", function()
    local NS, _, P = open()
    local w = P.tab("pads", "Layout")
    P.find(w, "Dropdown", "Orientation"):__fire("OnValueChanged", "vertical")
    P.find(w, "Dropdown", "Chip style"):__fire("OnValueChanged", "label")
    P.find(w, "Slider", "Scale"):__fire("OnMouseUp", 1.5)
    local layout = NS.db.profile.pads.p1.layout
    assertEqual(layout.orientation, "vertical")
    assertEqual(layout.style, "label")
    assertEqual(layout.scale, 1.5)
end)

test("pads page: Grid columns is grayed out unless the orientation is Grid", function()
    local NS, _, P = open()
    assertEqual(NS.db.profile.pads.p1.layout.orientation, "grid", "a new pad is a grid")
    local w = P.tab("pads", "Layout")
    assertFalse(P.find(w, "Slider", "Grid columns").disabled)
    P.find(w, "Dropdown", "Orientation"):__fire("OnValueChanged", "horizontal")
    -- red under: drop the columns row's disabledIf
    assertTrue(P.find(w, "Slider", "Grid columns").disabled, "the write's refresh grays it in place")
    w = P.tab("pads", "Layout")
    assertTrue(P.find(w, "Slider", "Grid columns").disabled, "and a fresh draw does too")
end)

test("pads page: X and Y move the pad through its pad.point row; Reset puts it back", function()
    local NS, m, P = open()
    local inst = NS.Pad.Instance("p1")
    local w = P.tab("pads", "Layout")
    P.find(w, "EditBox", "X offset"):__fire("OnEnterPressed", "40")
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "CENTER,CENTER,40,-150")
    w = P.tab("pads", "Layout")
    P.find(w, "EditBox", "Y offset"):__fire("OnEnterPressed", "-60")
    assertEqual(pointOf(inst), "TOP,CENTER,40,-60", "the rebuild re-anchors the pad by its growth edge")
    m.prints = {}
    w = P.tab("pads", "Layout")
    local xbox = P.find(w, "EditBox", "X offset")
    xbox:SetText("left")   -- as the player's typing leaves it
    xbox:__fire("OnEnterPressed", "left")
    assertTrue(table.concat(m.prints, "\n"):find("A position is a number of pixels.", 1, true) ~= nil)
    assertEqual(NS.db.profile.pads.p1.point[3], 40)
    -- red under: leave a refused box holding the refused text
    assertEqual(xbox.text, "40", "[final 27] the box shows the stored offset again")
    m.prints = {}
    xbox:SetText("90000")
    xbox:__fire("OnEnterPressed", "90000")
    assertEqual(NS.db.profile.pads.p1.point[3], 40, "[final 4] off the screen: refused")
    assertTrue(table.concat(m.prints, "\n"):find("off the screen", 1, true) ~= nil, "with its reason")
    assertEqual(xbox.text, "40")
    w = P.tab("pads", "Layout")
    P.find(w, "Button", "Reset this pad's position"):__fire("OnClick")
    assertNil(NS.db.profile.pads.p1.point)
    assertEqual(pointOf(inst), "TOP,CENTER,0,-150")
end)

test("pads page: Look's visibility reaches the pad's state driver", function()
    local NS, m, P = open()
    local w = P.tab("pads", "Look")
    P.find(w, "Dropdown", "Visibility"):__fire("OnValueChanged", "never")
    assertEqual(NS.db.profile.pads.p1.look.visibility, "never")
    assertEqual(m.stateDrivers[NS.Pad.Instance("p1").root].visibility, "hide")
end)

test("pads page: Groups lists the pad's groups; remove one, add it back at the end, drag to reorder", function()
    local NS, _, P = open()
    local lists = P.reorderSpy()
    local groups = NS.db.profile.pads.p1.groups
    local first, count = groups[1], #groups
    local w = P.tab("pads", "Groups")
    assertEqual(lists[#lists].rows, count)
    P.glyph(w, "remove", 1):__fire("OnClick")
    assertEqual(#NS.db.profile.pads.p1.groups, count - 1)
    w = P.tab("pads", "Groups")
    P.find(w, "Dropdown", "Add a group"):__fire("OnValueChanged", first)
    assertEqual(NS.db.profile.pads.p1.groups[count], first, "added back at the end")
    P.tab("pads", "Groups")
    lists[#lists].opts.onMove(count, 1)
    assertEqual(NS.db.profile.pads.p1.groups[1], first, "dragged to the top")
end)

test("pads page: the remove glyph takes a group off the pad without asking and keeps the group", function()
    local NS, m, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.Library.AddGroupToSurface("pad", "p1", gid)
    P.flush()
    local groups = NS.db.profile.pads.p1.groups
    local count, asked = #groups, #m.popupsShown
    local w = P.tab("pads", "Groups")
    assertNil(P.find(w, "Button", "Remove"), "no red button remains")
    assertNil(P.glyph(w, "edit"), "a pad's group row has no edit glyph")
    -- red under: draw the remove as the red L["Remove"] Button in Ed.ReorderRows
    P.glyph(w, "remove", count):__fire("OnClick")
    assertEqual(#NS.db.profile.pads.p1.groups, count - 1)
    assertEqual(#m.popupsShown, asked, "it does not ask first")
    assertTrue(NS.Library.Group(gid) ~= nil, "the group is kept")
end)

test("pads page: Delete pad asks, then the pad is gone, its frame released, and the page heals", function()
    local NS, _, P = open()
    local id = NS.addon.Settings.Pads.Create()
    P.flush()
    assertTrue(NS.Pad.Instance(id).live)
    local w = P.redraw("pads")
    P.find(w, "Button", "Delete pad"):__fire("OnClick")
    assertTrue(NS.db.profile.pads[id] ~= nil, "asks first")
    P.accept()
    assertNil(NS.db.profile.pads[id])
    assertFalse(NS.Pad.Instance(id).live, "released by Pad.Sync")
    P.flush()
    P.redraw("pads")
    assertEqual(NS.State.editing.pad, "p1")
end)

test("pads page: General's Unlock pads toggles the one lock", function()
    local NS, _, P = open()
    local w = P.redraw("pads")
    assertTrue(P.find(w, "Dropdown", "Preview as") ~= nil, "Preview as is page-wide, first")
    P.find(w, "Button", "Unlock pads"):__fire("OnClick")
    assertFalse(NS.Setting("locked"))
    P.flush()
    w = P.redraw("pads")
    P.find(w, "Button", "Lock pads"):__fire("OnClick")
    assertTrue(NS.Setting("locked"))
end)

test("pads page: [final 3, 15] Defaults puts the pad's rows back as one act: one rebuild", function()
    local NS, _, P = open()
    local S = NS.SchemaRuntime
    S.Set("pad.layout.style", "label", "p1")
    S.Set("pad.layout.scale", 1.5, "p1")
    S.Set("pad.look.fade", "outOfCombat", "p1")
    local applied = 0
    local apply = NS.Surfaces.ApplyAll
    NS.Surfaces.ApplyAll = function(...) applied = applied + 1 return apply(...) end
    P.ctx("pads").panel.defaultsOnClick()
    NS.Surfaces.ApplyAll = apply
    assertEqual(NS.db.profile.pads.p1.layout.style, "iconLabel")
    assertEqual(NS.db.profile.pads.p1.layout.scale, 1)
    assertEqual(NS.db.profile.pads.p1.look.fade, "none")
    -- red under: drop Library.Batch from the page's Defaults (one rebuild per row)
    assertEqual(applied, 1)
end)

test("pads page: [final 4] Defaults keeps the pad's position", function()
    local NS, _, P = open()
    NS.SchemaRuntime.Set("pad.point", { "CENTER", "CENTER", 40, -60 }, "p1")
    NS.SchemaRuntime.Set("pad.layout.style", "label", "p1")
    P.ctx("pads").panel.defaultsOnClick()
    assertEqual(NS.db.profile.pads.p1.layout.style, "iconLabel")
    -- red under: drop pad.point from settings/Schema.lua's resetExempt
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "CENTER,CENTER,40,-60")
end)

test("pads page: [final 26] New pad takes the lowest free number, so a delete never leads to two names alike", function()
    local NS = open()
    local Pads = NS.addon.Settings.Pads
    local two = Pads.Create()
    local three = Pads.Create()
    assertEqual(NS.db.profile.pads[three].name, "Comms Pad 3")
    NS.Library.DeleteSurface("pad", two)
    -- red under: name a new pad after the pad count ("Comms Pad 3" twice)
    local again = Pads.Create()
    assertEqual(NS.db.profile.pads[again].name, "Comms Pad 2")
    assertEqual(NS.db.profile.pads[Pads.Create()].name, "Comms Pad 4")
end)

test("pads page: [phase 5] Look carries the composed Font, Border and Background groups under their headings", function()
    local NS, _, P = open()
    local w = P.tab("pads", "Look")
    for _, heading in ipairs({ "Font", "Border", "Background" }) do
        assertTrue(P.find(w, "Heading", heading) ~= nil, heading)
    end
    assertEqual(#P.all(w, "CheckBox", "Use class color"), 3, "a companion beside each swatch (options-ui-§17)")
    assertTrue(P.find(w, "ColorPicker", "Font color") ~= nil)
    assertTrue(P.find(w, "ColorPicker", "Border color") ~= nil)
    assertTrue(P.find(w, "ColorPicker", "Background") ~= nil)
    P.find(w, "CheckBox", "Font shadow"):__fire("OnValueChanged", false)
    assertFalse(NS.db.profile.pads.p1.look.fontShadow)
end)
