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
    w = pl.CellSize({ style = "iconLabel", width = 60 })
    assertEqual(w, 120, "never narrower than MIN_W")
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

test("layout: upward growth stacks the sections bottom-up, each title above its chips", function()
    local pl = PL()
    local up = { orientation = "grid", columns = 2, growth = "up", style = "iconLabel", spacing = 4, width = 140 }
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
    assertEqual(byText["B"].y, 22, "the last section is on top, under the header")
    assertTrue(byText["A"].y > chipsOf["B"][1].y, "section A sits below section B")
    local a = chipsOf["A"]
    assertTrue(a[3].y < a[1].y, "the first chip row sits nearest the anchor")
    assertEqual(box.height, 22 + 14 + 24 + 4 + 14 + 24 + 4 + 24 + 4 + 4)
    assertEqual(a[1].y + a[1].h + 4 + 4, box.height, "the first row sits on the bottom edge")
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
