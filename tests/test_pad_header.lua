-- tests/test_pad_header.lua — the Comms Pad's header row as Loot History's title band (R5-QC1,
-- Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND5, owner item 4, images 40 and 41, the lead's call 5;
-- the skeptic's corrections to inputs/INVESTIGATION.md "quickcomms-header" win where they differ).
--
-- What the owner saw: under Ka0s Default the header drew nothing (it shared the section bands'
-- qc.bandBg, clear there), and in every other skin it drew the same flat title.bg box with a hairline
-- as each section band ("Solo"), so the pad read as two stacked boxes and no header. The ruling:
--   - the header wears the library's title band (S.TitleBar: title.bg, or the title.bgTop / bgBottom
--     gradient), on its own frame: two painters sharing the header's one backdrop would clobber each
--     other (the skeptic). The band sits at root + 1 and the header, clear and edgeless, at root + 2,
--     so nothing ties with the root's own backdrop;
--   - on its own tokens (R.HEADER_TOKENS), never the section bands';
--   - a borderless band in every skin, WoW Default included;
--   - flush inside the window edge (past Core's inner rule where the 1 px edge draws one), so the edge
--     and the rule show around it as Loot History's do; at the bottom for up growth, the same gradient;
--   - section bands draw no band in any skin, so the header is the only band;
--   - the text stays left (the pad is compact), every header child on the band's middle;
--   - the band stands down when the header stops following the skin (Use the skin's background off, a
--     class color, or a stored border), and the stored look draws as before.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local D = dofile("tests/dial_helpers.lua")
local OWNER = "QuickComms"

local function applyPad(NS)
    local snap = NS.Situation.Current()
    assertTrue(NS.Pad.Apply("p1", NS.Surfaces.BuildPlan("p1", NS.db.profile.pads.p1, snap, NS.Surfaces.Deps(snap))))
    return NS.Pad.Instance("p1")
end

--- A live pad, every skin table NS.ApplySkin took (by frame), and the skin library.
local function live()
    local NS, m = D.live()
    local drawn, apply = {}, NS.ApplySkin
    NS.ApplySkin = function(frame, skin)
        drawn[frame] = skin
        return apply(frame, skin)
    end
    -- The pad was dressed at enable, before the spy: a look only a change repaints (test_pad_looks).
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    Skin:SetChoice(OWNER, "ka0s", "glass")
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
    local inst = applyPad(NS)
    NS.Surfaces.ApplyAll("test")
    return NS, m, Skin, drawn, NS.Pad.Instance("p1") or inst
end

local function switch(NS, Skin, key)
    Skin:SetChoice(OWNER, "ka0s", key)
    NS.Surfaces.ApplyAll("test")
    return NS.Pad.Instance("p1")
end

local function skinKeys(Skin)
    local out = {}
    for _, def in ipairs(Skin:Skins()) do out[#out + 1] = def.key end
    return out
end

--- True when the library holds a TitleBar record of this owner's on `frame` (so a switch repaints it).
local function titleBarOn(Skin, frame)
    local rec = Skin.painted[frame]
    return rec ~= nil and rec.owner == OWNER and rec.calls.TitleBar ~= nil
end

--- The px the header stands in from the window's edge: the root's background inset, plus the inner
--- rule's pixel where the root draws one (read off the skin table the root was dressed in).
local function edgeOf(rootSkin)
    local inner = rootSkin.innerBorder
    local rule = type(inner) == "table" and (inner[4] or 1) > 0
    return rootSkin.insets.left + (rule and 1 or 0)
end

local function point(f, name)
    for _, p in ipairs(f.__points or {}) do
        if p[1] == name then return p end
    end
    return nil
end

local function assertAt(f, name, rel, x, y, what)
    local p = point(f, name)
    assertTrue(p ~= nil, what .. ": a " .. name .. " anchor")
    assertTrue(p[2] == rel and p[3] == name, what .. ": on its frame's own " .. name)
    assertEqual(p[4] .. "," .. p[5], x .. "," .. y, what)
end

-- ── the band ──────────────────────────────────────────────────────────────────────────────────────

test("pad header: the header is the library's title band in every skin, borderless, the header itself clear", function()
    local NS, _, Skin, drawn = live()
    for _, key in ipairs(skinKeys(Skin)) do
        local inst = switch(NS, Skin, key)
        local band = inst.headBand
        -- red under: the header painted flat on R.BAND_TOKENS (qc.bandBg: clear under Ka0s Default,
        -- title.bg with a hairline elsewhere), with no band of the library's at all
        assertTrue(band ~= nil, key .. ": the header has a band frame")
        assertTrue(titleBarOn(Skin, band), key .. ": the band is the library's TitleBar, repainted on a switch")
        assertTrue(band:IsShown(), key .. ": the band shows")
        assertAt(band, "TOPLEFT", inst.header, 0, 0, key .. ": the band is the header's rect")
        assertAt(band, "BOTTOMRIGHT", inst.header, 0, 0, key .. ": the band is the header's rect")
        local hs = drawn[inst.header]
        assertEqual(hs.bg[4], 0, key .. ": the header's own backdrop draws no fill over the band")
        -- red under: WoW Default's Blizzard Tooltip art at 2 and the other skins' bar.borderSize hairline
        assertTrue(hs.edgeFile == nil, key .. ": the header draws no edge (Loot History's band has none)")
    end
end)

test("pad header: the band and the header sit over the root, never level with its backdrop", function()
    local _, _, _, _, inst = live()
    local root = inst.root:GetFrameLevel()
    -- red under: no band frame; or one at the root's own level, which ties with the root's backdrop
    assertEqual(inst.headBand:GetFrameLevel(), root + 1, "the band one over the root")
    assertEqual(inst.header:GetFrameLevel(), root + 2, "the header, its texts and its button over the band")
end)

-- ── where it sits ─────────────────────────────────────────────────────────────────────────────────

test("pad header: the header sits flush inside the window edge, down growth and up, in every skin", function()
    local NS, _, Skin, drawn = live()
    for _, key in ipairs(skinKeys(Skin)) do
        local inst = switch(NS, Skin, key)
        local e = edgeOf(drawn[inst.root])
        -- red under: the header at the root's TOPLEFT 0,0, over the window's edge and its inner rule
        assertAt(inst.header, "TOPLEFT", inst.root, e, -e, key .. ": inside the edge on top")
        assertAt(inst.header, "TOPRIGHT", inst.root, -e, -e, key .. ": inside the edge on top")
    end
    local inst = switch(NS, Skin, "ka0s")
    assertEqual(edgeOf(drawn[inst.root]), 2, "Ka0s Default: past the 1 px edge and its inner rule")
    NS.db.profile.pads.p1.layout.growth = "rightUp"
    inst = applyPad(NS)
    assertAt(inst.header, "BOTTOMLEFT", inst.root, 2, 2, "growing up, the band is the bottom row, inside the edge")
    assertAt(inst.header, "BOTTOMRIGHT", inst.root, -2, 2, "growing up, inside the edge")
    -- The media library answering every name (the mock's knows none), so WoW Default's dialog art is
    -- drawn and its background inset is a quarter of its 16 px.
    NS.MediaFetch = function(_, name) return (name and name ~= "") and ("media:" .. name) or nil end
    inst = switch(NS, Skin, "wow")
    assertEqual(edgeOf(drawn[inst.root]), 4, "WoW Default: inside the dialog art's inset")
end)

test("pad header: the rows start under the band, and a collapsed pad is the band and its edges", function()
    local NS, _, _, drawn, inst = live()
    local e, hh = edgeOf(drawn[inst.root]), inst.hlook.height
    local top
    for _, fs in ipairs(inst.titles.active) do
        local p = point(fs.qcBand, "TOPLEFT")
        if p and (top == nil or -p[5] < top) then top = -p[5] end
    end
    assertTrue(top ~= nil, "the pad draws a section title")
    -- red under: the rows laid from the header's old 0..hh, one px over the band's foot
    assertEqual(top, e + hh + NS.PadLayout.PAD, "the first row the pad's padding under the band")
    assertTrue(NS.Pad.ToggleCollapsed("p1"))
    inst = NS.Pad.Instance("p1")
    -- red under: a collapsed pad hh tall, the inset band hanging over its bottom edge
    assertEqual(inst.root.__h, hh + 2 * e, "collapsed: the band plus the edge above and below it")
    local w = NS.PadRender.HeaderMinWidth(inst.header)
    assertTrue(inst.root.__w >= w + 2 * e, "the pad is as wide as the row needs, inside its edges")
end)

test("pad header: the text stays left, the collapse button right, each on the band's middle", function()
    local _, _, _, _, inst = live()
    local h = inst.header
    assertAt(h.qcSituation, "LEFT", h, 4, 0, "the situation text at the left, on the middle")
    assertAt(h.qcCollapse, "RIGHT", h, -2, 0, "the collapse button at the right, on the middle")
end)

-- ── the section bands ─────────────────────────────────────────────────────────────────────────────

test("pad header: a section band draws no band in any skin, so the header is the only band", function()
    local NS, _, Skin, drawn = live()
    for _, key in ipairs(skinKeys(Skin)) do
        local inst = switch(NS, Skin, key)
        assertTrue(#inst.titles.active > 0, key .. ": the pad draws a section title")
        for _, fs in ipairs(inst.titles.active) do
            local s = drawn[fs.qcBand]
            -- red under: qc.bandBg following title.bg and qc.bandEdgeSize bar.borderSize (round 4)
            assertEqual(s.bg[4], 0, key .. ": no fill behind a section title")
            assertTrue(s.edgeFile == nil, key .. ": no edge around a section title")
        end
    end
end)

test("pad header: a section band the player dresses still draws what was stored", function()
    local NS, _, _, drawn = live()
    local sec = NS.db.profile.pads.p1.section
    sec.backgroundFromSkin, sec.background = false, { r = 0.2, g = 0.3, b = 0.4, a = 1 }
    sec.borderStyleFromSkin, sec.borderStyle, sec.borderSize = false, "None", 1
    local inst = applyPad(NS)
    local s = drawn[inst.titles.active[1].qcBand]
    assertEqual(s.bg[3], 0.4, "the stored fill")
    assertEqual(s.edgeSize, 1, "the stored thickness")
end)

-- ── standing down ─────────────────────────────────────────────────────────────────────────────────

test("pad header: the band stands down when the header stops following the skin, and comes back", function()
    local NS, _, _, drawn = live()
    local hdr = NS.db.profile.pads.p1.header
    hdr.backgroundFromSkin, hdr.background = false, { r = 0.2, g = 0.3, b = 0.4, a = 1 }
    local inst = applyPad(NS)
    -- red under: a band that keeps its gradient under the stored color (no teardown)
    assertFalse(inst.headBand:IsShown(), "Use the skin's background off: no band")
    assertEqual(drawn[inst.header].bg[3], 0.4, "the stored fill draws on the header")
    hdr.backgroundFromSkin, hdr.useClassColorBackground = true, true
    inst = applyPad(NS)
    assertFalse(inst.headBand:IsShown(), "a class color: no band")
    hdr.useClassColorBackground = false
    hdr.borderStyleFromSkin, hdr.borderStyle, hdr.borderSize = false, "None", 2
    inst = applyPad(NS)
    assertFalse(inst.headBand:IsShown(), "a stored border: the stored look, no band")
    assertEqual(drawn[inst.header].edgeSize, 2, "the stored thickness draws")
    hdr.borderStyleFromSkin = true
    inst = applyPad(NS)
    assertTrue(inst.headBand:IsShown(), "following again: the band is back")
    assertEqual(drawn[inst.header].bg[4], 0, "the header clear over it again")
end)
