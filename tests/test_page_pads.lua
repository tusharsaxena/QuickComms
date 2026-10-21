-- tests/test_page_pads.lua — settings/Pads.lua (spec §10.2-§10.4, §13.1): the pad picker and New pad,
-- General's acts, the Groups priority list, Layout with the X/Y position, and the styled tabs. Driven headlessly
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
    P.show("Pad")
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
    P.find(w, "Dropdown", "Button style"):__fire("OnValueChanged", "label")
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

test("pads page: General's visibility reaches the pad's state driver", function()
    local NS, m, P = open()
    local w = P.tab("pads", "General")
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
    -- red under: draw state.previewAs on the pad's General tab again (it lives in General › Master controls)
    assertTrue(P.find(w, "Dropdown", "Preview as") == nil, "Preview as is in General › Master controls")
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

test("pads page: [window tabs] the strip reads General first, then Layout, Pad header, Section header, Window, Buttons, Icons", function()
    local NS = open()
    local order, seen = {}, {}
    for _, row in ipairs(NS.addon.Settings.RowsForPage("pads")) do
        if row.group and not seen[row.group] then
            seen[row.group] = true
            order[#order + 1] = row.group
        end
    end
    -- red under: a General row (Visibility's) ahead of Name moving no tab, but a Window row left ahead
    -- of the header tabs (the library orders tabs by each group's first row), or the one Window tab
    -- (2026-10-20, owner request)
    assertEqual(table.concat(order, ","), "General,Groups,Layout,Pad header,Section header,Window,Buttons,Icons")
end)

test("pads page: [window tabs] Pad header carries Size, Font, Background and Border under their headings", function()
    local NS, _, P = open()
    local w = P.tab("pads", "Pad header")
    for _, heading in ipairs({ "Size", "Font", "Background", "Border" }) do
        -- red under: the host's own h.Section above each subgroup (the library draws it from the rows)
        assertEqual(#P.all(w, "Heading", heading), 1, heading .. " drawn once")
    end
    assertEqual(#P.all(w, "CheckBox", "Use class color"), 3, "a companion beside each swatch (options-ui-§17)")
    assertTrue(P.find(w, "ColorPicker", "Font color") ~= nil)
    assertTrue(P.find(w, "ColorPicker", "Border color") ~= nil)
    assertTrue(P.find(w, "ColorPicker", "Background") ~= nil)
    P.find(w, "CheckBox", "Font shadow"):__fire("OnValueChanged", false)
    assertFalse(NS.db.profile.pads.p1.header.fontShadow)
    P.find(w, "Slider", "Header height"):__fire("OnMouseUp", 30)
    assertEqual(NS.db.profile.pads.p1.header.height, 30)
    assertEqual(NS.Pad.Instance("p1").header.__h, 30, "the pad's header row follows")
end)

test("pads page: [window tabs] Section header carries Size, Font, Background and Border, and writes the section table", function()
    local NS, _, P = open()
    local w = P.tab("pads", "Section header")
    for _, heading in ipairs({ "Size", "Font", "Background", "Border" }) do
        assertEqual(#P.all(w, "Heading", heading), 1, heading .. " drawn once")
    end
    assertEqual(#P.all(w, "CheckBox", "Use class color"), 3, "font, background and border")
    P.find(w, "CheckBox", "Font shadow"):__fire("OnValueChanged", false)
    assertFalse(NS.db.profile.pads.p1.section.fontShadow)
    -- red under: no pad.section.height row
    P.find(w, "Slider", "Section header height (0 = automatic)"):__fire("OnMouseUp", 22)
    assertEqual(NS.db.profile.pads.p1.section.height, 22)
end)

test("pads page: [window tabs] Window carries Background and Border, and no font and no Visibility", function()
    local NS, _, P = open()
    local w = P.tab("pads", "Window")
    for _, heading in ipairs({ "Background", "Border" }) do
        assertEqual(#P.all(w, "Heading", heading), 1, heading .. " drawn once")
    end
    assertNil(P.find(w, "ColorPicker", "Font color"), "no font on the Window (owner's call)")
    assertNil(P.find(w, "CheckBox", "Font shadow"))
    -- red under: the Visibility rows left on the Window tab (they moved to General, owner request)
    assertEqual(#P.all(w, "Heading", "Visibility"), 0, "Visibility is on General")
    assertNil(P.find(w, "Slider", "Faded alpha"))
    assertEqual(#P.all(w, "CheckBox", "Use class color"), 2, "background and border")
    P.find(w, "CheckBox", "Use class color"):__fire("OnValueChanged", true)
    assertTrue(NS.db.profile.pads.p1.look.useClassColorBackground, "the first companion is the background's")
end)

test("pads page: General carries Visibility, Fade and Faded alpha under a Visibility heading, before its buttons", function()
    local NS, _, P = open()
    local w = P.tab("pads", "General")
    -- red under: the Visibility rows left on the Window tab
    assertEqual(#P.all(w, "Heading", "Visibility"), 1, "Visibility drawn once")
    assertTrue(P.find(w, "Dropdown", "Fade") ~= nil)
    P.find(w, "Slider", "Faded alpha"):__fire("OnMouseUp", 0.5)
    assertEqual(NS.db.profile.pads.p1.look.fadeAlpha, 0.5, "the path is still pad.look.fadeAlpha")
    assertTrue(P.find(w, "Button", "Delete pad") ~= nil, "Unlock and Delete stay on General")
end)

-- ── the Buttons tab (2026-10-20) ───────────────────────────────────────────────────────────────

test("pads page: [button] Buttons carries Size, Color, Border, Font and Glow, and Button width left Layout for it", function()
    local NS, _, P = open()
    local w = P.tab("pads", "Buttons")
    for _, heading in ipairs({ "Size", "Color", "Border", "Font", "Glow" }) do
        assertEqual(#P.all(w, "Heading", heading), 1, heading .. " drawn once")
    end
    assertEqual(#P.all(w, "CheckBox", "Use class color"), 7, "background, border, font, glow, then the shine's tint and two blooms (options-ui-§17)")
    assertTrue(P.find(w, "Slider", "Glow style") == nil, "a dropdown, not a slider")
    -- red under: the Glow style row without its disabledIf
    assertTrue(P.find(w, "Dropdown", "Glow style").disabled, "the glow is off by default")
    P.find(w, "Slider", "Button width"):__fire("OnMouseUp", 140)
    P.find(w, "CheckBox", "Glow"):__fire("OnValueChanged", true)
    assertEqual(NS.db.profile.pads.p1.button.width, 140)
    assertTrue(NS.db.profile.pads.p1.button.glowEnabled)
    assertFalse(P.find(P.tab("pads", "Buttons"), "Dropdown", "Glow style").disabled)
    assertNil(P.find(P.tab("pads", "Layout"), "Slider", "Button width"), "moved to the Buttons tab")
    assertNil(NS.db.profile.pads.p1.layout.width, "and out of the layout table")
end)

test("page pads: [shine] the Buttons tab has a Shine heading", function()
    local NS, _, P = open()
    local rows = {}
    for _, r in ipairs(NS.addon.Settings.RowsForPage("pads")) do rows[r.path] = r end
    -- red under: no shine rows in settings/SchemaMembers.lua buttonRows
    for path, want in pairs({ ["pad.button.shineLook"] = "Shine look", ["pad.button.shineStrength"] = "Shine strength",
        ["pad.button.shineTint"] = "Shine tint", ["pad.button.shineBloomA"] = "Bloom color A",
        ["pad.button.shineBloomB"] = "Bloom color B" }) do
        local r = rows[path]
        assertTrue(r ~= nil, path)
        assertEqual(r.label, want, path .. " label")
        assertEqual(r.group, "Buttons", path .. " tab")
        assertEqual(r.subgroup, "Shine", path .. " heading")
    end
    for _, c in ipairs({ "useClassColorShineTint", "useClassColorShineBloomA", "useClassColorShineBloomB" }) do
        assertTrue(rows["pad.button." .. c] ~= nil, c .. ": each color with its class color")
    end
    local look = rows["pad.button.shineLook"]
    local ids = {}
    for i, v in ipairs(look.values) do ids[i] = v.value end
    assertEqual(table.concat(ids, ","), "none,gloss,glossfade,orb,frost,fluid,bevel,rim",
        "the eight choices, in order (Gloss fade after Gloss cap, owner 2026-10-21)")
    assertEqual(look.default, "none")
    local st = rows["pad.button.shineStrength"]
    assertEqual(table.concat({ st.min, st.max, st.step, st.default }, ","), "0,100,5,85")
    local button = NS.db.profile.pads.p1.button
    assertEqual(button.shineLook, "none", "a new pad draws no shine")
    assertEqual(button.shineStrength, 85)
    local w = P.tab("pads", "Buttons")
    assertEqual(#P.all(w, "Heading", "Shine"), 1, "Shine drawn once")
    assertEqual(#P.all(w, "CheckBox", "Use class color"), 7, "four, then the tint's and the two blooms'")
    -- red under: no disabledIf on the shine rows
    assertTrue(P.find(w, "Slider", "Shine strength").disabled, "None grays Strength")
    assertTrue(P.find(w, "ColorPicker", "Shine tint").disabled, "and Tint")
    assertTrue(P.find(w, "ColorPicker", "Bloom color A").disabled, "and the blooms")
    P.find(w, "Dropdown", "Shine look"):__fire("OnValueChanged", "orb")
    assertEqual(NS.db.profile.pads.p1.button.shineLook, "orb")
    w = P.tab("pads", "Buttons")
    assertFalse(P.find(w, "Slider", "Shine strength").disabled)
    assertFalse(P.find(w, "ColorPicker", "Shine tint").disabled)
    assertTrue(P.find(w, "ColorPicker", "Bloom color A").disabled, "the blooms are Fluid glass's only")
    assertTrue(P.find(w, "ColorPicker", "Bloom color B").disabled)
    NS.SchemaRuntime.Set("pad.button.shineLook", "fluid", "p1")
    w = P.tab("pads", "Buttons")
    assertFalse(P.find(w, "ColorPicker", "Bloom color A").disabled)
    assertFalse(P.find(w, "ColorPicker", "Bloom color B").disabled)
    assertFalse(NS.SchemaRuntime.Set("pad.button.shineLook", "satin", "p1"), "Satin sheen is not a look")
    NS.SchemaRuntime.Set("pad.button.shineStrength", 140, "p1")
    assertEqual(NS.db.profile.pads.p1.button.shineStrength, 100, "Strength stops at 100")
end)

-- ── the Icons tab (B9) ──────────────────────────────────────────────────────────────────────

local ICON_HEADINGS = { "Size and crop", "Color", "Border", "Glow", "Offset" }
local STYLE_HEADINGS = { pixel = "Pixel border", autocast = "Auto cast sparkles", button = "Button (rotating rays)",
    proc = "Proc (flipbook)" }

-- The style headings `w` draws, as a sorted comma list.
local function styleHeadings(P, w)
    local out = {}
    for _, heading in pairs(STYLE_HEADINGS) do
        if #P.all(w, "Heading", heading) > 0 then out[#out + 1] = heading end
    end
    table.sort(out)
    return table.concat(out, ",")
end

-- The index of the first widget of `wtype` labeled `label` in draw order, or nil.
local function indexOf(w, wtype, label)
    for i, x in ipairs(w) do
        if x.type == wtype and (x.labelText == label or x.text == label) then return i end
    end
    return nil
end

test("pads page: [B9] Icons carries its headings once each, a companion beside each swatch, and writes the pad", function()
    local NS, _, P = open()
    local w = P.tab("pads", "Icons")
    for _, heading in ipairs(ICON_HEADINGS) do
        -- red under: the host's own h.Section above each subgroup (the library draws it from the rows)
        assertEqual(#P.all(w, "Heading", heading), 1, heading .. " drawn once")
    end
    -- red under: the Icons tab drawn through renderStyled (every knob row)
    assertEqual(styleHeadings(P, w), "", "the glow is off by default: no style's knobs")
    assertEqual(#P.all(w, "CheckBox", "Use class color"), 3, "tint, border and glow (options-ui-§17)")
    assertTrue(P.find(w, "ColorPicker", "Tint") ~= nil)
    assertTrue(P.find(w, "ColorPicker", "Glow color") ~= nil)
    assertTrue(P.find(w, "CheckBox", "Show border") ~= nil, "the composed Border block")
    P.find(w, "Slider", "Icon size"):__fire("OnMouseUp", 30)
    P.find(w, "CheckBox", "Glow"):__fire("OnValueChanged", true)
    assertEqual(NS.db.profile.pads.p1.icon.size, 30)
    assertTrue(NS.db.profile.pads.p1.icon.glowEnabled)
end)

test("pads page: [B9] the offsets are grayed out while the glow is off or in Button; its color never is", function()
    local NS, _, P = open()
    local w = P.tab("pads", "Icons")
    assertTrue(P.find(w, "Slider", "Glow X offset").disabled, "the glow is off by default, and Offset still shows")
    assertTrue(P.find(w, "Slider", "Glow Y offset").disabled)
    assertFalse(P.find(w, "ColorPicker", "Glow color").disabled)
    assertTrue(P.find(w, "Slider", "Border thickness (px)").disabled, "the border is off by default")
    NS.SchemaRuntime.Set("pad.icon.glowEnabled", true, "p1")
    NS.SchemaRuntime.Set("pad.icon.borderShow", true, "p1")
    w = P.tab("pads", "Icons")
    assertFalse(P.find(w, "Slider", "Lines").disabled, "pixel, the default style")
    assertFalse(P.find(w, "Slider", "Glow X offset").disabled)
    assertFalse(P.find(w, "Slider", "Border thickness (px)").disabled)
    NS.SchemaRuntime.Set("pad.icon.glowType", "button", "p1")
    w = P.tab("pads", "Icons")
    assertFalse(P.find(w, "Slider", "Ray speed").disabled)
    assertTrue(P.find(w, "Slider", "Glow X offset").disabled, "Button ignores the offsets")
    assertTrue(P.find(w, "Slider", "Glow Y offset").disabled)
end)

test("pads page: [glow knobs] only the selected style's knobs show, and none while the glow is off", function()
    local NS, _, P = open()
    NS.SchemaRuntime.Set("pad.icon.glowEnabled", true, "p1")
    for style, heading in pairs(STYLE_HEADINGS) do
        NS.SchemaRuntime.Set("pad.icon.glowType", style, "p1")
        local w = P.tab("pads", "Icons")
        -- red under: Settings.ShownIconRows answering every row
        assertEqual(styleHeadings(P, w), heading, style)
    end
    NS.SchemaRuntime.Set("pad.icon.glowType", "pixel", "p1")
    local w = P.tab("pads", "Icons")
    assertTrue(P.find(w, "Slider", "Lines") ~= nil)
    assertNil(P.find(w, "Slider", "Ray speed"), "a button knob under the pixel style is not drawn")
    assertNil(P.find(w, "CheckBox", "Start animation"))
    NS.SchemaRuntime.Set("pad.icon.glowEnabled", false, "p1")
    w = P.tab("pads", "Icons")
    assertEqual(styleHeadings(P, w), "", "the glow off: no style's knobs")
    assertNil(P.find(w, "Slider", "Lines"))
    assertTrue(P.find(w, "Slider", "Glow X offset") ~= nil, "Offset always shows")
    -- The rows stay in the schema: /qc set and Defaults still reach a hidden knob.
    assertTrue(NS.SchemaRuntime.Set("pad.icon.procDuration", 2, "p1"))
    assertEqual(NS.db.profile.pads.p1.icon.procDuration, 2)
end)

test("pads page: [glow knobs] Offset comes right after Glow color, in the schema and on the tab", function()
    local NS, _, P = open()
    local paths = {}
    for _, row in ipairs(NS.addon.Settings.RowsForPage("pads")) do
        if row.group == "Icons" then paths[#paths + 1] = row.path end
    end
    local at
    for i, p in ipairs(paths) do
        if p == "pad.icon.useClassColorGlow" then at = i end
    end
    assertTrue(at ~= nil)
    -- red under: the knob loop in the knob table's order (the offsets last)
    assertEqual(paths[at + 1], "pad.icon.xOffset")
    assertEqual(paths[at + 2], "pad.icon.yOffset")
    assertEqual(paths[at + 3], "pad.icon.pixelLines", "then the styles' knobs")
    NS.SchemaRuntime.Set("pad.icon.glowEnabled", true, "p1")
    local w = P.tab("pads", "Icons")
    local color, offset, pixel = indexOf(w, "ColorPicker", "Glow color"), indexOf(w, "Heading", "Offset"),
        indexOf(w, "Heading", "Pixel border")
    assertTrue(color < offset and offset < pixel, "Glow color, then Offset, then the style's knobs")
end)

test("pads page: [glow knobs] a Glow or Glow style write repaints the tab, so the right knobs appear", function()
    local NS, _, P = open()
    local Ed = NS.addon.Settings.Editors
    for _, path in ipairs({ "pad.icon.glowEnabled", "pad.icon.glowType", "dial.icon.glowEnabled",
        "dial.icon.glowType" }) do
        assertTrue(Ed.STRUCTURAL[path], path .. " is structural")
    end
    local w = P.tab("pads", "Icons")
    P.find(w, "CheckBox", "Glow"):__fire("OnValueChanged", true)
    assertTrue(Ed.Pending(), "a structural repaint is asked for")
    -- red under: drop pad.icon.glowEnabled from Ed.STRUCTURAL (the write refreshes in place only)
    w = P.during(P.flush)
    assertEqual(styleHeadings(P, w), "Pixel border", "the repaint draws the default style's knobs")
    P.find(w, "Dropdown", "Glow style"):__fire("OnValueChanged", "proc")
    -- red under: drop pad.icon.glowType from Ed.STRUCTURAL
    w = P.during(P.flush)
    assertEqual(styleHeadings(P, w), "Proc (flipbook)")
    P.find(w, "CheckBox", "Glow"):__fire("OnValueChanged", false)
    w = P.during(P.flush)
    assertEqual(styleHeadings(P, w), "")
    assertTrue(P.find(w, "Slider", "Glow X offset") ~= nil)
end)

test("pads page: [B9] Defaults puts the Icons rows back too, and its tooltip names them", function()
    local NS, _, P = open()
    NS.SchemaRuntime.Set("pad.icon.zoom", 0.2, "p1")
    NS.SchemaRuntime.Set("pad.icon.glowEnabled", true, "p1")
    P.ctx("pads").panel.defaultsOnClick()
    assertEqual(NS.db.profile.pads.p1.icon.zoom, 0)
    assertFalse(NS.db.profile.pads.p1.icon.glowEnabled)
    assertTrue(P.ctx("pads").panel.defaultsTooltip:find("icons", 1, true) ~= nil)
end)

-- ── renames (dial polish T7) ──────────────────────────────────────────────────────────────
test("page pads: [polish] the page is titled Pad", function()
    local NS, m = T.enableAddon()
    -- red under: settings/Pads.lua still registering the page as L["Comms Pad"]
    assertTrue(m.__subcategories["Pad"] ~= nil, "the sidebar reads Pad")
    assertNil(m.__subcategories["Comms Pad"], "no Comms Pad page")
    -- the default member's name is unchanged (a page title only)
    assertEqual(NS.db.profile.pads.p1.name, "Comms Pad")
end)

test("page pads: [polish] no user-facing string sends the player to a Comms Pad or Comms Dial page", function()
    -- red under: any L[...] key or value still naming "the Comms Pad page", "Comms Pad > ..." etc.
    local fh = assert(io.open(T.root .. "/locales/enUS.lua", "rb"))
    local src = fh:read("*a")
    fh:close()
    for line in src:gmatch("[^\n]+") do
        if line:find("^L%[") then
            for _, stale in ipairs({ "Comms Pad page", "Comms Dial page", "Comms Pad >", "Comms Dial >",
                                     "Comms Pad or Comms Dial page" }) do
                assertNil(line:find(stale, 1, true), "stale page name in: " .. line)
            end
        end
    end
end)
