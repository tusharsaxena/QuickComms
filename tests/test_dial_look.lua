-- tests/test_dial_look.lua — split off tests/test_dial.lua at the layout-§1 band (FX-QC-SIZE): how a dial
-- is drawn. The page indicators, the hub over the slices, the tooltip's side, the pointer, the labels, the
-- hub styles, the group labels and the crisp art.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local D = dofile("tests/dial_helpers.lua")
local live, planOf, near =
    D.live, D.planOf, D.near

-- ── the page indicators' background and border (dial polish, 2026-10-21) ─────────────────────

test("dial: [paging] the indicators sit on a rounded background sized to the row; off hides it", function()
    local NS = live()
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local ring = NS.Dial.Instance("d2").rings.active[2]   -- page 1 of 2: the pill (18), a dot (8), a gap (6)
    local back = ring.qcDotBack
    -- red under: no background in modules/Dial_Slices.lua paintDots
    assertTrue(back ~= nil, "the background is drawn")
    local w, y = 0, select(5, ring.qcDots[1]:GetPoint(1))
    for _, k in ipairs({ "left", "mid", "right" }) do
        local t = back[k]
        assertTrue(t:IsShown(), k .. " shown by default")
        assertEqual(t.__texture, k == "mid" and "Interface\\Buttons\\WHITE8x8" or NS.DialSlices.DISC,
            k .. " is a pill piece")
        assertEqual(t.__size[2], 8 + 2 * 2 + 2 * 4, k .. ": the dot, its border and the padding, tall")
        assertEqual(select(5, t:GetPoint(1)), y, k .. " centered on the row")
        assertEqual(table.concat(t.__color, ","), "0.06,0.06,0.08,0.8", k .. " in the plates' color")
        assertEqual(t.__sublevel, -2, k .. " under the borders")
        w = w + t.__size[1]
    end
    assertEqual(w, 32 + 2 * 2 + 2 * 4, "the row, its border and the padding, wide")
    assertEqual(back.left.__size[1], back.left.__size[2] / 2, "a round cap: half its height wide")
    assertEqual(table.concat(back.left.__texCoord, ","), "0,0.5,0,1", "the disc's left half")
    assertTrue(NS.SchemaRuntime.Set("dial.page.dotBackPadding", 10, "d2"))
    assertTrue(NS.SchemaRuntime.Set("dial.page.dotBackColor", { r = 0, g = 0, b = 1, a = 0.5 }, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    assertEqual(back.mid.__size[2], 8 + 4 + 20, "the padding grows it")
    assertEqual(table.concat(back.mid.__color, ","), "0,0,1,0.5", "in its color")
    assertTrue(NS.SchemaRuntime.Set("dial.page.dotBackShow", false, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    for _, k in ipairs({ "left", "mid", "right" }) do assertFalse(back[k]:IsShown(), k .. " hidden while off") end
    assertFalse(NS.Dial.Instance("d2").rings.active[1].qcDotBack.mid:IsShown(), "a ring of one page has none")
end)

test("dial: [paging] every dot and the pill has a border, its size plus twice the Dot border; 0 draws none", function()
    local NS = live()
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local ring = NS.Dial.Instance("d2").rings.active[2]
    -- red under: no border textures in modules/Dial_Slices.lua paintDots
    local edges = ring.qcDotEdges
    assertTrue(edges ~= nil and edges[1] ~= nil, "a border per indicator")
    assertEqual(table.concat(edges[1].__size, ","), "10,12", "the pill (18 x 8) and 2 each side: its middle")
    assertEqual(edges[1].__size[1] + 2 * ring.qcDotEdgeCaps[1].left.__size[1], 22, "and its caps")
    assertEqual(table.concat(edges[2].__size, ","), "12,12", "the dot (8) and 2 each side")
    assertEqual(ring.qcDotEdgeCaps[1].left.__texture, NS.DialSlices.DISC, "the pill's own shape")
    assertEqual(edges[2].__texture, ring.qcDots[2].__texture, "the dot's own shape")
    assertEqual(table.concat(edges[2].__color, ","), "0,0,0,0.9", "near black")
    assertEqual(edges[2].__sublevel, -1, "over the background, under the dot")
    assertEqual(select(4, edges[2]:GetPoint(1)), select(4, ring.qcDots[2]:GetPoint(1)), "behind its dot")
    assertTrue(NS.SchemaRuntime.Set("dial.page.dotBorder", 3, "d2"))
    assertTrue(NS.SchemaRuntime.Set("dial.page.dotBorderColor", { r = 1, g = 0, b = 0, a = 1 }, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    assertEqual(table.concat(edges[1].__size, ","), "10,14")
    assertEqual(edges[1].__size[1] + 2 * ring.qcDotEdgeCaps[1].left.__size[1], 24)
    assertEqual(table.concat(edges[2].__color, ","), "1,0,0,1", "in its color")
    assertTrue(edges[1]:IsShown() and edges[2]:IsShown())
    assertTrue(NS.SchemaRuntime.Set("dial.page.dotBorder", 0, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    assertFalse(edges[1]:IsShown() or edges[2]:IsShown(), "0 draws no border")
    assertFalse(ring.qcDotEdgeCaps[1].left:IsShown() or ring.qcDotEdgeCaps[1].right:IsShown(), "nor its caps")
    assertEqual(ring.qcDotBack.mid.__size[2], 8 + 8, "nor counts one in the background")
end)

test("dial: [front] the hub, its circle and the pointer draw over the slices", function()
    local NS = live()
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local inst = NS.Dial.Instance("d2")
    local front = inst.header.qcPointer
    -- red under: the hub's backdrop and circle on the header, under the rings' fills
    assertTrue(inst.header.qcHub:GetParent() == front and inst.header.qcHubDot:GetParent() == front)
    for _, ring in ipairs(inst.rings.active) do
        assertTrue(front:GetFrameLevel() > ring:GetFrameLevel(), "above every ring")
        for _, w in ipairs(ring.qcWedges.active) do assertTrue(front:GetFrameLevel() > w:GetFrameLevel()) end
    end
end)

test("dial: [tooltip] a wedge's tooltip sits outside the dial: above by default, on the Labels tab's side", function()
    local NS, m = live()
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local h = NS.Dial.Instance("d2").header
    local w = NS.Dial.RingWedges("d2", 2)[1]
    NS.DialRender.EnterWedge(w)   -- the tracker's hover (wedges take no mouse since dial polish)
    local tip = m.GameTooltip
    -- red under: R.ShowTooltip through PadRender.ShowLines (ANCHOR_TOP, over the dial)
    assertEqual(tip.__anchor, "ANCHOR_NONE")
    local p, rel, _, x, y = tip:GetPoint(1)
    local g = NS.DialLayout.Geometry(NS.DialLayout.RADIUS)
    assertEqual(p .. "," .. tostring(rel == h) .. "," .. x, "BOTTOM,true,0")
    assertTrue(y >= g.title + 8, "above the ring title, by the offset")
    assertTrue(NS.SchemaRuntime.Set("dial.label.tooltipSide", "left", "d2"))
    assertTrue(NS.SchemaRuntime.Set("dial.label.tooltipOffset", 20, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    NS.DialRender.EnterWedge(w)
    p, _, _, x = tip:GetPoint(1)
    assertEqual(p, "RIGHT")
    assertTrue(x <= -(g.disc / 2 + 20), "left of the disc and its labels, by the offset")
end)

test("dial: [pointer] the pointer is a catalog glyph, sized, colored and placed by the Slices tab, and can be off", function()
    local NS = live()
    assertTrue(NS.SchemaRuntime.Set("dial.slice.pointerSize", 30, "d2"))
    assertTrue(NS.SchemaRuntime.Set("dial.slice.pointerColor", { r = 0, g = 0, b = 1, a = 1 }, "d2"))
    assertEqual(NS.db.profile.dials.d2.slice.pointerOffset, 24, "a new dial's pointer sits 24 out (owner, 2026-10-22)")
    assertTrue(NS.SchemaRuntime.Set("dial.slice.pointerOffset", 0, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local h = NS.Dial.Instance("d2").header
    local arrow = h.qcPointer.qcArrow
    assertEqual(arrow.__size[1], 30)
    assertEqual(arrow.__color[3], 1)
    assertEqual(h.qcReach, NS.DialLayout.PointerReach(30, 32), "automatic: pushed out to clear the 32 hub")
    assertTrue(NS.SchemaRuntime.Set("dial.slice.pointerOffset", 70, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    -- red under: ignore pointerOffset in R.PaintPointer
    assertEqual(h.qcReach, 70, "the Pointer offset, from the center")
    assertTrue(NS.SchemaRuntime.Set("dial.slice.pointerShow", false, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    h:Show()
    NS.DialRender.PointerUpdate(h.qcPointer)
    assertFalse(h.qcPointer.qcArrow:IsShown(), "off: never drawn (the update still lights slices)")
end)

test("dial: [labels] the Label offset moves every label out from the center; the title and the page row follow", function()
    local NS = live()
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local w = NS.Dial.RingWedges("d2", 2)[2]   -- E (places from N: N, E, S, W)
    local _, _, _, x0 = w.qcLabel:GetPoint(1)
    local _, _, _, wx = w:GetPoint(1)
    local g = NS.DialLayout.Geometry(NS.DialLayout.RADIUS)
    assertEqual(wx + x0, g.reach, "automatic: just past the disc")
    assertTrue(NS.SchemaRuntime.Set("dial.label.offset", 220, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local _, _, _, x1 = w.qcLabel:GetPoint(1)
    -- red under: drop `reach` from DL.Wedge
    assertEqual(wx + x1, 220, "220 pixels from the center")
    local ring = NS.Dial.Instance("d2").rings.active[2]
    local _, _, _, _, ty = ring.qcTitle:GetPoint(1)
    assertTrue(ty >= 220 + 14, "the title clears the N label")
end)

-- ── hub styles (dial polish T5): a backdrop disc and a circle mark ─────────────────────────────

-- The default dial applied with `hub` written to its dial.hub rows; answers its header.
local function hubWith(NS, hub)
    for k, v in pairs(hub or {}) do assertTrue(NS.SchemaRuntime.Set("dial.hub." .. k, v, "d2"), k) end
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    return NS.Dial.Instance("d2").header
end

-- The distance from the header's center of a region's one anchor.
local function reachOf(t)
    local _, _, _, x, y = t:GetPoint(1)
    return math.sqrt((x or 0) ^ 2 + (y or 0) ^ 2)
end

test("dial: [polish] default hub is a solid gold circle of 24 on a 32 backdrop with a 1 px rim, no red X", function()
    local NS = live()
    local h = hubWith(NS)
    -- red under: keep R.DressHub's qcClose (the red stop mark)
    assertNil(h.qcClose, "the red X is gone")
    assertEqual(h.__w, 32, "the header is the hub's size")
    assertTrue(h.qcHub:IsShown())
    assertEqual(h.qcHub.__size[1], 32, "the backdrop, 32 across")
    assertEqual(h.qcHub.__color[1], 0.12)
    -- red under: no qcHubDot / no R.PaintHubLook in Dial.Apply
    assertTrue(h.qcHubDot:IsShown(), "solid: the circle")
    assertEqual(h.qcHubDot.__size[1], 24)
    assertEqual(h.qcHubDot.__color[1] .. "," .. h.qcHubDot.__color[2], "1,0.82", "gold")
    assertFalse(h.qcHubRing:IsShown(), "no hollow ring")
    assertTrue(h.qcHubRim:IsShown(), "the backdrop's 1 px border")
    assertEqual(h.qcHubRim.__texture, NS.DialRender.RingTexture(32, 1))
    local rest = h.qcHubDot.__color[4]
    NS.DialRender.HoverHub(h, true)
    -- red under: no brightening in R.HoverHub
    assertTrue(h.qcHubDot.__color[4] > rest, "hovered, the circle brightens")
    NS.DialRender.HoverHub(h, false)
    assertEqual(h.qcHubDot.__color[4], rest, "and dims back")
end)

test("dial: [polish] hub style solid draws the backdrop rim when its border size is set", function()
    local NS = live()
    local h = hubWith(NS, { style = "solid", borderSize = 3, borderColor = { r = 0, g = 0, b = 1, a = 1 } })
    assertTrue(h.qcHubDot:IsShown())
    -- red under: draw the backdrop rim only for the rimmed style
    assertTrue(h.qcHubRim:IsShown(), "any style draws the backdrop's border")
    local rim = h.qcHubRim
    assertEqual(rim.__texture, NS.DialRender.RingTexture(32, 3), "border size thick")
    assertEqual(rim.__color[3], 1, "in the border color")
    assertEqual(rim.__size[1], 32, "the backdrop across")
    assertTrue(reachOf(rim) < 0.01, "centered on the hub")
end)

test("dial: [polish] hub style ring is a hollow ring of the circle size and line width", function()
    local NS = live()
    local h = hubWith(NS, { style = "ring", circleSize = 30, lineWidth = 4, borderSize = 0 })
    -- red under: PaintHubLook ignoring the style (solid always)
    assertFalse(h.qcHubDot:IsShown(), "no filled circle")
    assertTrue(h.qcHubRing:IsShown())
    assertEqual(h.qcHubRing.__texture, NS.DialRender.RingTexture(30, 4), "line width thick")
    assertEqual(h.qcHubRing.__size[1], 30, "the circle size across")
    assertEqual(h.qcHubRing.__color[2], 0.82, "in the circle color")
    assertFalse(h.qcHubRim:IsShown())
end)

test("dial: [polish] hub style target is a ring with a center dot", function()
    local NS = live()
    local h = hubWith(NS, { style = "target", circleSize = 32 })
    -- red under: target drawn as the ring alone
    assertTrue(h.qcHubRing:IsShown())
    assertTrue(h.qcHubDot:IsShown())
    assertEqual(h.qcHubDot.__size[1], 8, "a quarter of the circle size")
    h = hubWith(NS, { circleSize = 8 })
    assertEqual(h.qcHubDot.__size[1], 4, "never under 4")
end)

test("dial: [polish] hub style rimmed is a filled circle on a backdrop with its own rim", function()
    local NS = live()
    local h = hubWith(NS, { style = "rimmed", borderSize = 0 })
    assertTrue(h.qcHubDot:IsShown())
    assertEqual(h.qcHubDot.__size[1], 24)
    -- red under: the rimmed style drawn without its rim at border size 0
    assertTrue(h.qcHubRim:IsShown(), "rimmed at border size 0: a 2 px rim")
    assertEqual(h.qcHubRim.__texture, NS.DialRender.RingTexture(32, 2))
    assertFalse(h.qcHubRing:IsShown())
    h = hubWith(NS, { borderSize = 5 })
    assertEqual(h.qcHubRim.__texture, NS.DialRender.RingTexture(32, 5), "the border size when larger")
end)

test("dial: [polish] hub size moves the inner edge everywhere", function()
    local NS = live()
    assertTrue(NS.SchemaRuntime.Set("dial.slice.pointerOffset", 0, "d2"))   -- automatic: it follows the hub
    local h = hubWith(NS, { size = 60 })
    -- red under: header:SetSize(DL.HUB, DL.HUB) in Dial.build
    assertEqual(h.__w .. "x" .. h.__h, "60x60", "the header is the hub")
    assertEqual(h.qcHub.__size[1], 60, "the backdrop")
    local ring = NS.Dial.Instance("d2").rings.active[2]
    -- red under: shape.hub = DL.HUB in Dial.Apply
    assertEqual(ring.qcCatcher:GetAttribute("qc-hub"), 60, "the catcher's inner edge")
    -- red under: DL.HUB in Slices.Track
    NS.DialSlices.Track(ring, 0, 29)
    assertNil(ring.qcLit, "inside the hub: nothing")
    NS.DialSlices.Track(ring, 0, 31)
    assertEqual(ring.qcLit, 1, "just past it: N")
    -- red under: DL.PointerReach reading DL.HUB
    assertTrue(h.qcReach > 30, "the pointer sits outside the hub")
end)

-- ── group labels (dial polish T6): the ring title in its own font ────────────────────────────

test("dial: [polish] group labels take their font and hide when off", function()
    local NS = live()
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local ring = NS.Dial.Instance("d2").rings.active[1]
    local title = ring.qcTitle
    -- red under: R.PaintRing without the title font (the GameFontNormal template alone)
    assertEqual(title.__font and title.__font[2], 16, "the owner's look: 16 points (2026-10-22)")
    assertEqual(title.__font[3], "OUTLINE", "outlined")
    assertEqual(title.__color[1] .. "," .. title.__color[2] .. "," .. title.__color[3], "1,0.82,0", "gold")
    assertTrue(title:IsShown())
    local g = NS.DialLayout.Geometry(NS.DialLayout.RADIUS)
    local header = NS.Dial.Instance("d2").header
    assertEqual(header.qcTipAt[3], g.title + 18 + 8, "the tooltip clears an 18-pixel title")
    assertTrue(NS.SchemaRuntime.Set("dial.title.fontSize", 20, "d2"))
    assertTrue(NS.SchemaRuntime.Set("dial.title.fontColor", { r = 0, g = 1, b = 0, a = 1 }, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    assertEqual(title.__font[2], 20)
    assertEqual(title.__color[2], 1, "its own color")
    -- red under: DL.Geometry without the title's own line height (titleLine)
    assertEqual(NS.DialLayout.Geometry(NS.DialLayout.RADIUS, nil, nil, 22).top, g.title + 22)
    assertEqual(header.qcTipAt[3], g.title + 22 + 8, "the tooltip clears the bigger title")
    assertEqual(NS.Dial.RingWedges("d2", 1)[1].qcLabel.__font[2], 12, "the slice labels keep theirs")
    assertTrue(NS.SchemaRuntime.Set("dial.title.show", false, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    -- red under: R.PaintRing leaving the title shown while Show group labels is off
    assertFalse(title:IsShown(), "off: no title")
    assertEqual(header.qcTipAt[3], g.title + 8, "and the tooltip takes its place")
end)

-- ── crisp dial art (shine T1, 2026-10-21): the disc, the ring ladder, the three-piece pill ──────

local PORTRAIT = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

-- The ring step k whose line-to-diameter ratio is nearest `frac` in log space.
local function nearestStep(steps, frac)
    local best, bestD
    for k, s in ipairs(steps) do
        local d = math.abs(math.log(frac) - math.log(s))
        if not bestD or d < bestD then best, bestD = k, d end
    end
    return best
end

test("dial: [art] RingTexture picks the nearest step", function()
    local NS = live()
    local R, S = NS.DialRender, NS.DialSlices
    -- red under: no R.RING_STEPS / R.RingTexture in modules/Dial_Render.lua
    assertEqual(#R.RING_STEPS, 12, "twelve steps")
    near(R.RING_STEPS[1], 0.0125, "step 1")
    near(R.RING_STEPS[12], 0.5, "step 12")
    local k = nearestStep(R.RING_STEPS, 2 / 22)
    assertTrue(R.RingTexture(22, 2):sub(-#("dial-ring-" .. k)) == "dial-ring-" .. k, R.RingTexture(22, 2))
    assertTrue(R.RingTexture(80, 1):sub(-#"dial-ring-1") == "dial-ring-1", "a thin line on a big ring: step 1")
    assertTrue(S.DISC ~= nil and S.DISC:find("dial%-disc$") ~= nil, "the disc's path")
    assertEqual(R.RingTexture(4, 6), S.DISC, "a line half the diameter or more: the solid disc")
    assertEqual(R.RingTexture(40, 20), S.DISC, "exactly half: the disc")
end)

test("dial: [art] the hub draws textures, not segments", function()
    local NS = live()
    local R, S = NS.DialRender, NS.DialSlices
    local function isRing(t) return type(t.__texture) == "string" and t.__texture:find("dial%-ring%-%d+$") ~= nil end
    for _, style in ipairs({ "solid", "ring", "target", "rimmed" }) do
        local h = hubWith(NS, { style = style, borderSize = 0 })
        -- red under: qcHubRing / qcHubRim kept as lists of DL.ARC segments
        assertTrue(h.qcHubRing.SetTexture ~= nil and h.qcHubRim.SetTexture ~= nil, style .. ": single textures")
        local ringed = style == "ring" or style == "target"
        assertEqual(h.qcHubRing:IsShown(), ringed, style .. ": the hollow ring")
        if ringed then
            assertTrue(isRing(h.qcHubRing), style .. ": a ring texture")
            assertEqual(h.qcHubRing.__texture, R.RingTexture(24, NS.PadDefaults.DialHub().lineWidth),
                style .. ": circle size and line width")
            assertEqual(h.qcHubRing.__size[1], 24, style .. ": the circle size across")
        end
        assertEqual(h.qcHubRim:IsShown(), style == "rimmed", style .. ": the rim at border size 0")
        if style == "rimmed" then
            assertEqual(h.qcHubRim.__texture, R.RingTexture(32, 2), "a 2 px rim on the 32 backdrop")
            assertEqual(h.qcHubRim.__size[1], 32)
        end
        assertEqual(h.qcHub.__texture, S.DISC, style .. ": the backdrop is the disc")
        assertEqual(h.qcHubDot.__texture, S.DISC, style .. ": the circle is the disc")
        for _, t in ipairs({ h.qcHub, h.qcHubDot, h.qcHubRing, h.qcHubRim }) do
            assertTrue(t.__texture ~= PORTRAIT, style .. ": no portrait mask on the hub")
        end
    end
    local h = hubWith(NS, { style = "solid", borderSize = 3, borderColor = { r = 0, g = 0, b = 1, a = 1 } })
    assertTrue(h.qcHubRim:IsShown(), "any style draws the backdrop's border")
    assertEqual(h.qcHubRim.__texture, R.RingTexture(32, 3))
    assertEqual(h.qcHubRim.__color[3], 1, "in the border color")
    local ring = NS.Dial.Instance("d2").rings.active[2]
    local w = NS.Dial.RingWedges("d2", 2)[1]
    for _, t in ipairs({ w.qcDim, w.qcCool, w.qcFlash }) do
        assertEqual(t.__texture, S.DISC, "the wedge's discs")
    end
    assertTrue(ring ~= nil)
end)

test("dial: [art] the pill is three pieces with round ends", function()
    local NS = live()
    local S = NS.DialSlices
    local WHITE = "Interface\\Buttons\\WHITE8x8"
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local ring = NS.Dial.Instance("d2").rings.active[2]   -- page 1 of 2: the pill (18 x 8)
    -- red under: S.PILL, one stretched texture per indicator
    assertNil(S.PILL, "dial-pill.tga is retired")
    local function threePiece(left, mid, right, w, h, what)
        assertEqual(left.__texture, S.DISC, what .. ": the left cap is the disc")
        assertEqual(table.concat(left.__texCoord, ","), "0,0.5,0,1", what .. ": its left half")
        assertEqual(right.__texture, S.DISC, what .. ": the right cap is the disc")
        assertEqual(table.concat(right.__texCoord, ","), "0.5,1,0,1", what .. ": its right half")
        assertEqual(mid.__texture, WHITE, what .. ": a flat middle")
        assertEqual(table.concat(left.__size, ","), (h / 2) .. "," .. h, what .. ": a round cap")
        assertEqual(table.concat(right.__size, ","), (h / 2) .. "," .. h, what .. ": a round cap")
        assertEqual(table.concat(mid.__size, ","), (w - h) .. "," .. h, what .. ": the middle")
        local _, _, _, mx = mid:GetPoint(1)
        near(select(4, left:GetPoint(1)), mx - (w - h) / 2 - h / 4, what .. ": the left cap abuts the middle")
        near(select(4, right:GetPoint(1)), mx + (w - h) / 2 + h / 4, what .. ": the right cap abuts it")
    end
    local caps, ecaps = ring.qcDotCaps[1], ring.qcDotEdgeCaps[1]
    threePiece(caps.left, ring.qcDots[1], caps.right, 18, 8, "the pill")
    threePiece(ecaps.left, ring.qcDotEdges[1], ecaps.right, 22, 12, "the pill's border")
    local back = ring.qcDotBack
    threePiece(back.left, back.mid, back.right, 32 + 4 + 8, 8 + 4 + 8, "the background")
    assertEqual(ring.qcDots[2].__texture, S.DISC, "a dot is the disc")
    assertFalse(ring.qcDotCaps[2].left:IsShown() or ring.qcDotCaps[2].right:IsShown(), "a dot has no caps")
    assertTrue(caps.left:IsShown() and caps.right:IsShown(), "the pill shows its caps")
end)
