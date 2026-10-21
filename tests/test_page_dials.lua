-- tests/test_page_dials.lua — settings/Dials.lua (spec §11, §13.1): the dial picker and New dial,
-- General's acts, Groups (Categories or Flat, the priority list), Wheel with the ring radius and the
-- X/Y position, Labels, and the Preview tab. No Binding tab: the key is set in Options -> Keybindings. Driven headlessly through
-- tests/page_helpers.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }
local AB = { inInstance = true, instanceType = "pvp", instanceID = 2107, inGroup = true, inRaid = true,
    inInstanceGroup = true }

local function open(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or MPLUS end
    NS.Situation.RefreshNow("test")
    local P = dofile("tests/page_helpers.lua")(NS, m)
    P.show("Comms Dial")
    NS.addon.Settings.Editors.Select("dial", "d2")
    return NS, m, P
end

test("dials page: New dial makes a second dial holding every built-in, selects it, and builds QuickCommsDial2", function()
    local NS, _, P = open()
    P.bannerAction(P.ctx("dials")):__fire("OnClick")
    P.flush()
    local id = NS.State.editing.dial
    assertTrue(id ~= "d2" and NS.db.profile.dials[id] ~= nil)
    assertEqual(NS.db.profile.dials[id].name, "Comms Dial 2")
    assertEqual(#NS.db.profile.dials[id].groups, #NS.BuiltIns.order)
    assertEqual(NS.Dial.Instance(id).header:GetName(), "QuickCommsDial2")
end)

test("dials page: New dial takes the lowest free number, so a delete never leads to two names alike", function()
    local NS = open()
    local Dials = NS.addon.Settings.Dials
    local two = Dials.Create()
    local three = Dials.Create()
    assertEqual(NS.db.profile.dials[three].name, "Comms Dial 3")
    NS.Library.DeleteSurface("dial", two)
    -- red under: name a new dial after the dial count ("Comms Dial 3" twice)
    local again = Dials.Create()
    assertEqual(NS.db.profile.dials[again].name, "Comms Dial 2")
end)

test("dials page: General has no Preview as (it is in Master controls); Enabled off takes the dial down", function()
    local NS, _, P = open()
    local w = P.redraw("dials")
    -- red under: draw state.previewAs on the dial's General tab again
    assertTrue(P.find(w, "Dropdown", "Preview as") == nil, "Preview as is in General › Master controls")
    P.find(w, "CheckBox", "Enabled"):__fire("OnValueChanged", false)
    assertFalse(NS.db.profile.dials.d2.enabled)
    assertNil(NS.Dial.Instance("d2"), "a disabled dial is not built")
end)

test("dials page: Wheel writes wedges per ring and where it opens; X and Y move the dial; Reset puts it back", function()
    local NS, _, P = open()
    local w = P.tab("dials", "Wheel")
    assertEqual(NS.db.profile.dials.d2.slices, 0, "Auto by default")
    P.find(w, "Dropdown", "Wedges per ring"):__fire("OnValueChanged", 8)
    w = P.tab("dials", "Wheel")
    P.find(w, "Slider", "Ring radius"):__fire("OnMouseUp", 140)
    assertEqual(NS.db.profile.dials.d2.radius, 140)
    assertEqual(NS.Surfaces.DialPlans().d2.radius, 140, "the dial rebuilds at its new radius")
    w = P.tab("dials", "Wheel")
    P.find(w, "Dropdown", "Open at"):__fire("OnValueChanged", "cursor")
    assertEqual(NS.db.profile.dials.d2.slices, 8)
    assertEqual(NS.db.profile.dials.d2.openAt, "cursor")
    w = P.tab("dials", "Wheel")
    P.find(w, "EditBox", "Y offset"):__fire("OnEnterPressed", "120")
    assertEqual(table.concat(NS.db.profile.dials.d2.point, ","), "CENTER,CENTER,0,120")
    assertEqual(select(5, NS.Dial.Instance("d2").header:GetPoint(1)), 120)
    w = P.tab("dials", "Wheel")
    P.find(w, "Button", "Reset this dial's position"):__fire("OnClick")
    assertNil(NS.db.profile.dials.d2.point)
end)

test("dials page: a refused X or Y says why and puts the box back to the stored offset", function()
    local NS, m, P = open()
    P.find(P.tab("dials", "Wheel"), "EditBox", "X offset"):__fire("OnEnterPressed", "40")
    local xbox = P.find(P.tab("dials", "Wheel"), "EditBox", "X offset")
    m.prints = {}
    xbox:SetText("90000")   -- as the player's typing leaves it
    xbox:__fire("OnEnterPressed", "90000")
    assertEqual(NS.db.profile.dials.d2.point[3], 40, "off the screen: refused")
    assertTrue(table.concat(m.prints, "\n"):find("off the screen", 1, true) ~= nil, "with its reason")
    -- red under: leave a refused box holding the refused text
    assertEqual(xbox.text, "40")
end)

test("dials page: Defaults puts the dial's rows back as one act, and keeps its key and position", function()
    local NS, m, P = open()
    local S = NS.SchemaRuntime
    S.Set("dial.slices", 8, "d2")
    S.Set("dial.radius", 150, "d2")
    S.Set("dial.label.show", false, "d2")
    S.Set("dial.mode", "flat", "d2")
    m.SetBinding("G", "CLICK QuickCommsDial1:Toggle")
    S.Set("dial.point", { "CENTER", "CENTER", 0, 120 }, "d2")
    local applied = 0
    local apply = NS.Surfaces.ApplyAll
    NS.Surfaces.ApplyAll = function(...) applied = applied + 1 return apply(...) end
    P.ctx("dials").panel.defaultsOnClick()
    NS.Surfaces.ApplyAll = apply
    assertEqual(NS.db.profile.dials.d2.slices, 0)
    assertEqual(NS.db.profile.dials.d2.radius, 100)
    assertTrue(NS.db.profile.dials.d2.label.show)
    assertEqual(NS.db.profile.dials.d2.mode, "categories")
    -- red under: drop Library.Batch from the page's Defaults (one rebuild per row)
    assertEqual(applied, 1)
    -- red under: drop dial.point from settings/Schema.lua's resetExempt
    assertEqual(m.bindingActions.G, "CLICK QuickCommsDial1:Toggle", "WoW's binding: no row, nothing to reset")
    assertEqual(table.concat(NS.db.profile.dials.d2.point, ","), "CENTER,CENTER,0,120")
end)

test("dials page: [dial rework] no Binding tab: the key is set in Options -> Keybindings alone", function()
    local NS, _, P = open()
    -- red under: keep { key = BINDING, render = renderBinding } in settings/Dials.lua
    assertEqual(#P.all(P.tab("dials", "Binding"), "Keybinding", "Key"), 0, "no key capture anywhere")
    assertNil(NS.addon.Settings.Dials.SetKey)
end)


test("dials page: Groups switches Categories and Flat, and reorders the dial's groups", function()
    local NS, _, P = open()
    local lists = P.reorderSpy()
    local w = P.tab("dials", "Groups")
    P.find(w, "Dropdown", "Show groups as"):__fire("OnValueChanged", "flat")
    assertEqual(NS.db.profile.dials.d2.mode, "flat")
    local groups = NS.db.profile.dials.d2.groups
    local count, last = #groups, groups[#groups]
    P.tab("dials", "Groups")
    lists[#lists].opts.onMove(count, 1)
    assertEqual(NS.db.profile.dials.d2.groups[1], last)
end)

test("dials page: the remove glyph takes a group off the dial without asking and keeps the group", function()
    local NS, m, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.Library.AddGroupToSurface("dial", "d2", gid)
    P.flush()
    local groups = NS.db.profile.dials.d2.groups
    local count, asked = #groups, #m.popupsShown
    local w = P.tab("dials", "Groups")
    assertNil(P.find(w, "Button", "Remove"), "no red button remains")
    assertNil(P.glyph(w, "edit"), "a dial's group row has no edit glyph")
    -- red under: draw the remove as the red L["Remove"] Button in Ed.ReorderRows
    P.glyph(w, "remove", count):__fire("OnClick")
    assertEqual(#NS.db.profile.dials.d2.groups, count - 1)
    assertEqual(#m.popupsShown, asked, "it does not ask first")
    assertTrue(NS.Library.Group(gid) ~= nil, "the group is kept")
end)


test("dials page: Preview lists the rings wedge by wedge, marking the one the dial opens on", function()
    local NS, _, P = open(AB)
    local w = P.tab("dials", "preview")
    -- dial rework: In Group is active in a battleground too, so the dial opens on the groups (Auto: W
    -- first, clockwise)
    assertTrue(P.hasText(w, "Comms Dial (opens here)"), table.concat(NS.addon.Settings.Dials.PreviewLines("d2"), "\n"))
    assertTrue(P.hasText(w, "  1 W: Arathi Basin, opens a ring"))
    -- phase 5: the nodes are pinned to their winds, on one eight-wedge ring (spec §12.1); the set's
    -- own map-wide callouts take the first free wind (groups polish)
    assertTrue(P.hasText(w, "  3 E: Arathi Basin, opens a ring"))
    assertTrue(P.hasText(w, "  5 SW: Lumber Mill, opens a ring"))
end)

test("dials page: [final 20] at 12 wedges per ring the Preview names each wedge by its clock position", function()
    local NS, _, P = open()
    assertTrue(NS.SchemaRuntime.Set("dial.mode", "flat", "d2"))
    assertTrue(NS.SchemaRuntime.Set("dial.slices", 12, "d2"))
    -- M+ alone (In Group's twelve would page the ring, and a paged ring holds eight)
    assertTrue(NS.SchemaRuntime.Set("group.enabled", false, T.seeded(NS, "bi.group")))
    local w = P.tab("dials", "preview")
    -- red under: start fixed counts at N in modules/Dial_Layout.lua PageShape (wedge 2 at 1 o'clock)
    assertTrue(P.hasText(w, "  1 9 o'clock: "), "wedge 1 at W, 9 o'clock")
    assertTrue(P.hasText(w, "  2 10 o'clock: "), "wedge 2 at 10 o'clock")
    assertTrue(P.hasText(w, "  3 11 o'clock: "))
end)

test("dials page: Delete dial asks, then the dial is gone, its header released, and the page heals", function()
    local NS, _, P = open()
    local id = NS.addon.Settings.Dials.Create()
    P.flush()
    assertTrue(NS.Dial.Instance(id) ~= nil)
    local w = P.redraw("dials")
    P.find(w, "Button", "Delete dial"):__fire("OnClick")
    assertTrue(NS.db.profile.dials[id] ~= nil, "asks first")
    P.accept()
    assertNil(NS.db.profile.dials[id])
    assertNil(NS.Dial.Instance(id), "released by Dial.Sync")
    P.flush()
    P.redraw("dials")
    assertEqual(NS.State.editing.dial, "d2")
end)

-- ── final review fixes ──────────────────────────────────────────────────────────────────────



test("dials page: [final 11] the page's own plan builds are not timed as a surface's bake", function()
    local NS = open(AB)
    local Dials = NS.addon.Settings.Dials
    local notes = 0
    NS.Perf.on = true
    local note = NS.Perf.Note
    NS.Perf.Note = function(k, ...)
        if k == "bakeSurface" then notes = notes + 1 end
        return note(k, ...)
    end
    local ok, err = pcall(function()
        NS.Library.MoveGroupOnSurface("dial", "d2", #NS.db.profile.dials.d2.groups, 1)
        notes = 0
        Dials.PreviewLines("d2")
    end)
    NS.Perf.Note, NS.Perf.on = note, false
    assertTrue(ok, tostring(err))
    -- red under: build the page's plans through S.BuildDialPlan's bracket
    assertEqual(notes, 0)
end)

-- ── the Icons tab (B9) ──────────────────────────────────────────────────────────────────────

test("dials page: [B9] Icons follows Wheel, carries its headings once each, and writes the dial", function()
    local NS, _, P = open()
    local w = P.tab("dials", "Icons")
    for _, heading in ipairs({ "Size and crop", "Color", "Border", "Glow", "Offset" }) do
        assertEqual(#P.all(w, "Heading", heading), 1, heading .. " drawn once")
    end
    -- red under: Dials' renderIcons without Settings.ShownIconRows
    assertEqual(#P.all(w, "Heading", "Pixel border"), 0, "the glow is off by default: no style's knobs")
    assertEqual(#P.all(w, "CheckBox", "Use class color"), 3)
    local order, seen = {}, {}
    for _, row in ipairs(NS.addon.Settings.RowsForPage("dials")) do
        if row.group and not seen[row.group] then seen[row.group] = true order[#order + 1] = row.group end
    end
    assertEqual(table.concat(order, ","), "General,Groups,Wheel,Slices,Paging,Labels,Icons", "the rows' tabs, in order")
    P.find(w, "Slider", "Icon size"):__fire("OnMouseUp", 24)
    P.find(w, "CheckBox", "Show border"):__fire("OnValueChanged", true)
    assertEqual(NS.db.profile.dials.d2.icon.size, 24)
    assertTrue(NS.db.profile.dials.d2.icon.borderShow)
    NS.SchemaRuntime.Set("dial.icon.zoom", 0.1, "d2")
    P.ctx("dials").panel.defaultsOnClick()
    assertEqual(NS.db.profile.dials.d2.icon.zoom, 0)
    assertTrue(P.ctx("dials").panel.defaultsTooltip:find("icons", 1, true) ~= nil)
end)

test("dials page: [glow knobs] only the selected style's knobs show, and a Glow or Glow style write repaints", function()
    local _, _, P = open()
    local w = P.tab("dials", "Icons")
    P.find(w, "CheckBox", "Glow"):__fire("OnValueChanged", true)
    w = P.during(P.flush)
    assertEqual(#P.all(w, "Heading", "Pixel border"), 1, "the repaint draws the default style's knobs")
    assertEqual(#P.all(w, "Heading", "Auto cast sparkles"), 0)
    P.find(w, "Dropdown", "Glow style"):__fire("OnValueChanged", "autocast")
    w = P.during(P.flush)
    assertEqual(#P.all(w, "Heading", "Auto cast sparkles"), 1)
    assertEqual(#P.all(w, "Heading", "Pixel border"), 0)
    assertEqual(#P.all(w, "Heading", "Offset"), 1, "Offset always shows")
end)

-- ── the Labels tab (dial rework, 2026-10-21) ────────────────────────────────────────────────

test("dials page: [labels] Labels shows or hides the wedges' names and styles them; off grays the font", function()
    local NS, _, P = open()
    local w = P.tab("dials", "Labels")
    for _, label in ipairs({ "Show labels", "Use class color" }) do assertTrue(P.find(w, "CheckBox", label) ~= nil, label) end
    local wedge = NS.Dial.RingWedges("d2", 1)[1]
    assertTrue(wedge.qcLabel:IsShown())
    P.find(w, "CheckBox", "Show labels"):__fire("OnValueChanged", false)
    assertFalse(NS.db.profile.dials.d2.label.show)
    -- red under: drop SetShown from R.PaintWedge's label
    assertFalse(NS.Dial.RingWedges("d2", 1)[1].qcLabel:IsShown(), "the dial rebuilt without names")
    w = P.tab("dials", "Labels")
    assertTrue(P.find(w, "Slider", "Font size").disabled, "the font block waits for labels")
    assertTrue(NS.SchemaRuntime.Set("dial.label.show", true, "d2"))
    assertTrue(NS.SchemaRuntime.Set("dial.label.fontSize", 18, "d2"))
    assertEqual(NS.Dial.RingWedges("d2", 1)[1].qcLabel.__font[2], 18)
end)

test("dials page: [slices] Slices writes the fill, gap, highlight and pointer, each color with its class color", function()
    local NS, _, P = open()
    local w = P.tab("dials", "Slices")
    for _, heading in ipairs({ "Background", "Gap", "Highlight", "Pointer" }) do
        assertEqual(#P.all(w, "Heading", heading), 1, heading .. " drawn once")
    end
    -- red under: no Hub rows (dial polish T5 adds backdrop, border and circle)
    assertEqual(#P.all(w, "CheckBox", "Use class color"), 6, "fill, highlight, hub backdrop, border, circle and pointer")
    P.find(w, "Slider", "Slice gap"):__fire("OnMouseUp", 3)
    assertEqual(NS.db.profile.dials.d2.slice.gap, 3)
    w = P.tab("dials", "Slices")
    P.find(w, "CheckBox", "Show pointer"):__fire("OnValueChanged", false)
    w = P.tab("dials", "Slices")
    -- red under: no disabledIf on the pointer rows
    assertTrue(P.find(w, "Slider", "Pointer size").disabled)
    local l = P.tab("dials", "Labels")
    P.find(l, "Dropdown", "Tooltip side"):__fire("OnValueChanged", "right")
    assertEqual(NS.db.profile.dials.d2.label.tooltipSide, "right")
    P.ctx("dials").panel.defaultsOnClick()
    assertEqual(NS.db.profile.dials.d2.slice.gap, 0)
    assertTrue(NS.db.profile.dials.d2.slice.pointerShow)
    assertEqual(NS.db.profile.dials.d2.label.tooltipSide, "top")
end)

test("page dials: [polish] Slices tab has Slice gap and no Border heading", function()
    local NS, _, P = open()
    local w = P.tab("dials", "Slices")
    -- red under: keep the Border rows in settings/SchemaMembers.lua sliceRows
    assertEqual(#P.all(w, "Heading", "Border"), 0, "the Border heading is gone")
    assertNil(P.find(w, "Slider", "Border size"), "and its size")
    -- red under: no dial.slice.gap row
    local gap = P.find(w, "Slider", "Slice gap")
    assertTrue(gap ~= nil, "Slice gap is drawn")
    gap:__fire("OnMouseUp", 20)
    assertEqual(NS.db.profile.dials.d2.slice.gap, 20)
    NS.SchemaRuntime.Set("dial.slice.gap", 21, "d2")
    assertEqual(NS.db.profile.dials.d2.slice.gap, 20, "the gap stops at 20")
    assertFalse((NS.SchemaRuntime.Set("dial.slice.borderSize", 2, "d2")), "the retired row is refused")
end)

test("page dials: [polish] Hub heading rows on the Slices tab", function()
    local NS, _, P = open()
    local w = P.tab("dials", "Slices")
    -- red under: no hubRows() in settings/SchemaMembers.lua sliceRows
    assertEqual(#P.all(w, "Heading", "Hub"), 1, "the Hub heading, drawn once")
    for _, label in ipairs({ "Hub size", "Circle size", "Line width", "Hub border size" }) do
        assertTrue(P.find(w, "Slider", label) ~= nil, label)
    end
    local style = P.find(w, "Dropdown", "Hub style")
    assertTrue(style ~= nil, "Hub style")
    -- red under: no disabledIf on Line width (the solid circle has no line)
    assertTrue(P.find(w, "Slider", "Line width").disabled, "solid: no line width")
    style:__fire("OnValueChanged", "target")
    assertEqual(NS.db.profile.dials.d2.hub.style, "target")
    w = P.tab("dials", "Slices")
    assertFalse(P.find(w, "Slider", "Line width").disabled, "target: line width")
    P.find(w, "Slider", "Hub size"):__fire("OnMouseUp", 60)
    assertEqual(NS.db.profile.dials.d2.hub.size, 60)
    assertEqual(NS.Dial.Instance("d2").header.__w, 60, "the dial rebuilt with the hub")
    NS.SchemaRuntime.Set("dial.hub.size", 200, "d2")
    assertEqual(NS.db.profile.dials.d2.hub.size, 80, "the hub stops at 80")
    assertFalse((NS.SchemaRuntime.Set("dial.hub.style", "square", "d2")), "an unknown style is refused")
    P.ctx("dials").panel.defaultsOnClick()
    assertEqual(NS.db.profile.dials.d2.hub.style, "solid")
    assertEqual(NS.db.profile.dials.d2.hub.size, 40)
end)

test("dials page: [slices] every slice texture the dial names ships under media/textures", function()
    local NS = open()
    for n = 2, 12 do
        local rel = NS.DialSlices.SectorTexture(n):gsub("^Interface\\AddOns\\QuickComms\\", ""):gsub("\\", "/")
        local fh = io.open(T.root .. "/" .. rel .. ".tga", "rb")
        -- red under: a sector count tools/gen-dial-textures.py does not write
        assertTrue(fh ~= nil, rel)
        if fh then fh:close() end
    end
    local pill = NS.DialSlices.PILL:gsub("^Interface\\AddOns\\QuickComms\\", ""):gsub("\\", "/")
    assertTrue(io.open(T.root .. "/" .. pill .. ".tga", "rb") ~= nil, pill)
end)

test("dials page: [paging] Paging sizes, spaces and colors the arrows and page indicators; the dial follows", function()
    local NS, _, P = open()
    local w = P.tab("dials", "Paging")
    for _, heading in ipairs({ "Position", "Arrows", "Page indicator" }) do
        assertEqual(#P.all(w, "Heading", heading), 1, heading .. " drawn once")
    end
    assertEqual(#P.all(w, "CheckBox", "Use class color"), 4, "arrow, background, current and other pages")
    P.find(w, "Slider", "Arrow size"):__fire("OnMouseUp", 36)
    assertEqual(NS.db.profile.dials.d2.page.arrowSize, 36)
    -- red under: size the arrows from DL.ARROW in modules/Dial.lua placeArrows
    local ring = NS.Dial.Instance("d2").rings.active[1]
    assertEqual(ring.qcPrev.qcPlate.__size[1], 36)
    w = P.tab("dials", "Paging")
    P.find(w, "Slider", "Dot size"):__fire("OnMouseUp", 9)
    assertEqual(NS.db.profile.dials.d2.page.dotSize, 9)
    P.ctx("dials").panel.defaultsOnClick()
    assertEqual(NS.db.profile.dials.d2.page.arrowSize, 24)
end)

test("dials page: [wheel] Icon offset moves the icons in or out; 0 is the ring radius", function()
    local NS, _, P = open()
    local w = P.tab("dials", "Wheel")
    P.find(w, "Slider", "Icon offset (0 = automatic)"):__fire("OnMouseUp", 70)
    assertEqual(NS.db.profile.dials.d2.iconOffset, 70)
    local wedge = NS.Dial.RingWedges("d2", 1)[1]
    local _, _, _, x, y = wedge:GetPoint(1)
    -- red under: drop `at` from DL.Wedge (the icon stays on the radius)
    assertEqual(math.floor(math.sqrt(x * x + y * y) + 0.5), 70)
end)
