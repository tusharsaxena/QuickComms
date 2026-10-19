-- tests/test_pad_layout.lua — modules/Pad_Layout.lua (spec §10.2, §10.3): geometry, the sections a
-- pad draws for each groups-as mode, the visibility expression and the fade. Pure truth tables.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function PL() return T.newAddon().PadLayout end

local function slots(n)
    local out = {}
    for i = 1, n do out[i] = { calloutId = "c" .. i } end
    return out
end

local function chips(box)
    local out = {}
    for _, it in ipairs(box.items) do if it.kind == "chip" then out[#out + 1] = it end end
    return out
end

local H = { orientation = "horizontal", columns = 4, growth = "right", style = "iconLabel", spacing = 4, width = 140 }

test("layout: horizontal puts a section's chips on one row under the header", function()
    local pl = PL()
    local box = pl.Compute({ { slots = slots(3) } }, H)
    local c = chips(box)
    assertEqual(#c, 3)
    assertEqual(c[1].x, 4)
    assertEqual(c[2].x, 148)
    assertEqual(c[3].x, 292)
    assertEqual(c[1].y, 22)
    assertEqual(c[1].w, 140)
    assertEqual(c[1].h, 24)
    assertEqual(box.width, 436)
    assertEqual(box.height, 54)
end)

test("layout: a titled section draws its label row first", function()
    local pl = PL()
    local box = pl.Compute({ { title = "M+", slots = slots(1) } }, H)
    assertEqual(box.items[1].kind, "title")
    assertEqual(box.items[1].y, 22)
    assertEqual(box.items[2].y, 36)
    assertEqual(box.height, 68)
end)

test("layout: grid wraps at its column count; vertical is one column", function()
    local pl = PL()
    local grid = { orientation = "grid", columns = 2, style = "iconLabel", spacing = 4, width = 140 }
    local c = chips(pl.Compute({ { slots = slots(3) } }, grid))
    assertEqual(c[3].col, 0)
    assertEqual(c[3].row, 1)
    assertEqual(c[3].y, 50)
    local v = chips(pl.Compute({ { slots = slots(3) } }, { orientation = "vertical", spacing = 4 }))
    assertEqual(v[3].x, 4)
    assertEqual(v[3].row, 2)
end)

test("layout: the style sets the cell", function()
    local pl = PL()
    local w, h = pl.CellSize({ style = "icon" })
    assertEqual(w, 28)
    assertEqual(h, 28)
    w, h = pl.CellSize({ style = "label", width = 160 })
    assertEqual(w, 160)
    assertEqual(h, 22)
    -- red under: PL.CellSize clamping a chip to the pad's minimum (120)
    w = pl.CellSize({ style = "iconLabel", width = 60 })
    assertEqual(w, 60, "a chip may be narrower than the pad's minimum")
    assertEqual((pl.CellSize({ style = "iconLabel", width = 1 })), 1, "down to one pixel")
    assertEqual((pl.CellSize({ style = "iconLabel", width = 0 })), 1, "never below one")
    assertEqual((pl.CellSize({ style = "iconLabel" })), 100, "the default chip width is 100")
end)

test("layout: [B3] narrow chips never make the pad narrower than its header needs", function()
    local pl = PL()
    local narrow = { orientation = "horizontal", growth = "right", style = "iconLabel", spacing = 4, width = 10 }
    local box = pl.Compute({ { slots = slots(2) } }, narrow)
    assertEqual(box.width, 120, "the pad's own minimum")
    assertEqual(chips(box)[2].x, 18, "the chips keep their own width")
end)

test("layout: [B1] a section title equal to the header's situation is not drawn; a tab's title is", function()
    local pl = PL()
    local box = pl.Compute({ { title = "World", slots = slots(1) } }, H, { situation = " world " })
    -- red under: PL.Compute ignoring opts.situation
    assertEqual(box.items[1].kind, "chip", "no title row")
    assertEqual(box.items[1].y, 22, "the chip moves up into its place")
    local other = pl.Compute({ { title = "World", slots = slots(1) } }, H, { situation = "M+ +12" })
    assertEqual(other.items[1].kind, "title", "a different situation keeps the title")
    local tab = pl.Compute({ { title = "World", slots = slots(1), tabIndex = 1, tabCount = 2 } }, H,
        { situation = "World" })
    assertEqual(tab.items[1].kind, "title", "a tab's title names its place, so it stays")
end)

test("layout: [review] a larger Look font grows the chip and title rows; the default size changes nothing", function()
    local pl = PL()
    local sections = { { title = "One", slots = slots(2) }, { title = "Two", slots = slots(1) } }
    local base = pl.Compute(sections, H)
    local same = pl.Compute(sections, H, { fontSize = 10 })
    assertEqual(same.height, base.height, "the default font keeps the shipped geometry")
    local big = pl.Compute(sections, H, { fontSize = 24 })
    local title, chip
    for _, it in ipairs(big.items) do
        if it.kind == "title" and not title then title = it end
        if it.kind == "chip" and not chip then chip = it end
    end
    -- red under: PL.CellSize and sectionBlock in modules/Pad_Layout.lua ignoring the font size
    assertTrue(chip.h >= 24 + 8, "a chip holds a 24-point label: " .. chip.h)
    assertTrue(title.h >= 24, "a title row holds a 24-point title: " .. title.h)
    assertTrue(chip.y >= title.y + title.h, "the first chip row starts below its title")
    assertTrue(big.height > base.height)
    local _, lh = pl.CellSize({ style = "label" }, 32)
    assertTrue(lh >= 32 + 8, "a label-only chip too")
    local iw, ih = pl.CellSize({ style = "icon" }, 32)
    assertEqual(iw .. "x" .. ih, "28x28", "an icon-only chip draws no text")
end)

test("layout: leftward growth mirrors the row; collapsed is the header alone", function()
    local pl = PL()
    local left = { orientation = "horizontal", growth = "left", style = "iconLabel", spacing = 4, width = 140 }
    local c = chips(pl.Compute({ { slots = slots(2) } }, left))
    assertEqual(c[1].x, 148)
    assertEqual(c[2].x, 4)
    local box = pl.Compute({ { slots = slots(2) } }, H, { collapsed = true })
    assertEqual(#box.items, 0)
    assertEqual(box.height, 18)
    assertEqual(box.width, 120)
end)

test("layout: [B2] upward growth puts the header at the bottom and stacks the sections up from it", function()
    local pl = PL()
    local up = { orientation = "grid", columns = 2, growth = "rightUp", style = "iconLabel", spacing = 4, width = 140 }
    local box = pl.Compute({ { title = "A", slots = slots(3) }, { title = "B", slots = slots(1) } }, up)
    local byText, chipsOf, cur = {}, {}, nil
    for _, it in ipairs(box.items) do
        if it.kind == "title" then
            cur = it.text
            byText[cur] = it
            chipsOf[cur] = {}
        else
            table.insert(chipsOf[cur], it)
        end
    end
    for _, name in ipairs({ "A", "B" }) do
        for _, c in ipairs(chipsOf[name]) do
            assertTrue(byText[name].y < c.y, name .. "'s title sits above its chips")
        end
    end
    assertEqual(box.height, 22 + 14 + 24 + 4 + 14 + 24 + 4 + 24 + 4 + 4)
    -- red under: the header pinned on top for every growth (the old "up" only reversed the sections)
    assertTrue(box.up == true, "the box says the pad grows up")
    assertEqual(box.headerY, box.height - 18, "the header row is the pad's bottom row")
    assertEqual(byText["B"].y, 8, "the last section is on top")
    assertTrue(byText["A"].y > chipsOf["B"][1].y, "section A sits below section B")
    local a = chipsOf["A"]
    assertTrue(a[3].y < a[1].y, "the first chip row sits nearest the header")
    assertEqual(a[1].y + a[1].h + 4, box.headerY, "the first row sits just above the header")
    local left = pl.Compute({ { slots = slots(2) } }, { orientation = "horizontal", growth = "leftUp",
        style = "iconLabel", spacing = 4, width = 140 })
    local c = chips(left)
    assertEqual(c[1].x, 148, "Left and up mirrors the row too")
    assertEqual(left.headerY, left.height - 18)
    local down = pl.Compute({ { slots = slots(1) } }, H)
    assertEqual(down.headerY, 0, "down growth keeps the header on top")
    assertTrue(not down.up)
    assertTrue(pl.GrowsUp("rightUp") and pl.GrowsUp("leftUp") and not pl.GrowsUp("right") and not pl.GrowsUp("left"))
end)

test("layout: [B2] the pad's anchor is its growth edge; a drop is converted to that edge exactly", function()
    local pl = PL()
    local p, y = pl.EdgePoint("CENTER", -150, nil, false)
    assertEqual(p .. "," .. y, "TOP,-150", "a stored point is read as the growth edge")
    p, y = pl.EdgePoint("TOPLEFT", -35, nil, true)
    assertEqual(p .. "," .. y, "BOTTOMLEFT,-35")
    p, y = pl.EdgePoint("TOPLEFT", -35, 100, true)
    assertEqual(p .. "," .. y, "BOTTOMLEFT,-135", "the frame's bottom edge, 100 below its top")
    p, y = pl.EdgePoint("CENTER", 0, 100, false)
    assertEqual(p .. "," .. y, "TOP,50")
    p, y = pl.EdgePoint("BOTTOMRIGHT", 10, 60, false)
    assertEqual(p .. "," .. y, "TOPRIGHT,70")
    p, y = pl.EdgePoint("RIGHT", 0, 60, true)
    assertEqual(p .. "," .. y, "BOTTOMRIGHT,-30")
end)

test("layout: groups-as picks the sections: sections, merged, one tab at a time", function()
    local pl = PL()
    local secs = { { title = "A", slots = slots(2) }, { title = "B", slots = slots(1) } }
    assertEqual(#pl.VisibleSections(secs, "sections"), 2)
    local merged = pl.VisibleSections(secs, "merged")
    assertEqual(#merged, 1)
    assertEqual(#merged[1].slots, 3)
    assertTrue(merged[1].title == nil)
    local tab = pl.VisibleSections(secs, "tabs", 2)
    assertEqual(#tab, 1)
    assertEqual(tab[1].title, "B")
    assertEqual(tab[1].tabIndex, 2)
    assertEqual(tab[1].tabCount, 2)
    assertEqual(pl.VisibleSections(secs, "tabs", 9)[1].title, "B", "clamped")
    assertEqual(#pl.VisibleSections({}, "tabs", 1), 0)
end)

test("layout: the wheel steps tabs and wraps both ways", function()
    local pl = PL()
    assertEqual(pl.NextTab(1, 3, -1), 2)
    assertEqual(pl.NextTab(3, 3, -1), 1)
    assertEqual(pl.NextTab(1, 3, 1), 3)
    assertEqual(pl.NextTab(nil, 0, 1), 1)
end)

test("layout: the visibility expression combines the master and the pad", function()
    local pl = PL()
    local V = pl.VisibilityDriver
    assertEqual(V("always", "always", true, false), "show")
    assertEqual(V("never", "always", true, false), "hide")
    assertEqual(V("always", "never", true, false), "hide")
    assertEqual(V("inCombat", "always", true, false), "[combat] show; hide")
    assertEqual(V("always", "outOfCombat", true, false), "[combat] hide; show")
    assertEqual(V("inCombat", "outOfCombat", true, false), "hide")
    assertEqual(V("always", "whenActive", false, false), "hide")
    assertEqual(V("always", "whenActive", true, false), "show")
    assertEqual(V("never", "never", false, true), "show", "test mode shows the display")
    assertEqual(V(nil, nil, true, false), "show")
end)

test("layout: the fade follows combat and the mouse, under the master alpha", function()
    local pl = PL()
    local A = pl.Alpha
    assertEqual(A(1, { fade = "none" }, false, false), 1)
    assertEqual(A(1, { fade = "outOfCombat", fadeAlpha = 0.4 }, false, false), 0.4)
    assertEqual(A(1, { fade = "outOfCombat", fadeAlpha = 0.4 }, true, false), 1)
    assertEqual(A(1, { fade = "mouseover", fadeAlpha = 0.5 }, true, false), 0.5)
    assertEqual(A(1, { fade = "mouseover", fadeAlpha = 0.5 }, true, true), 1)
    assertEqual(A(0.5, { fade = "none" }, false, false), 0.5)
    assertEqual(A(nil, nil, false, false), 1)
end)

test("layout: the channel tag names the resolved channel", function()
    local pl = PL()
    assertEqual(pl.Tag("party"), "P")
    assertEqual(pl.Tag("instance"), "I")
    assertEqual(pl.Tag("raidWarning"), "RW")
    assertTrue(pl.Tag(nil) == nil)
end)
