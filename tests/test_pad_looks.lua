-- tests/test_pad_looks.lua — the Comms Pad's look in each skin (the owner's in-game findings of
-- 2026-11-01): WoW Default's white bands and maroon buttons, the thick band edges of the skins whose
-- window edge is more than a hairline, Ka0s Default's fuller buttons and a shine a third lighter. Read
-- off what reaches NS.ApplySkin and the drawing setters, on the skins' own values as vendored.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local D = dofile("tests/dial_helpers.lua")
local OWNER = "QuickComms"

-- The media library answering every name: the mock's knows none, and "" names no file.
local function anyMedia(NS)
    NS.MediaFetch = function(_, name)
        if name == nil or name == "" then return nil end
        return "media:" .. name
    end
end

-- A live pad under skin `key`, and every skin table NS.ApplySkin took, by frame.
local function padUnder(key)
    local NS, m = D.live()
    local drawn, apply = {}, NS.ApplySkin
    NS.ApplySkin = function(frame, skin)
        drawn[frame] = skin
        return apply(frame, skin)
    end
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    if key == "ka0s" then Skin:SetChoice(OWNER, "ka0s", "glass") end   -- a look only a change repaints
    Skin:SetChoice(OWNER, "ka0s", key)
    local snap = NS.Situation.Current()
    assertTrue(NS.Pad.Apply("p1", NS.Surfaces.BuildPlan("p1", NS.db.profile.pads.p1, snap, NS.Surfaces.Deps(snap))))
    NS.Surfaces.ApplyAll("test")
    local inst = NS.Pad.Instance("p1")
    return NS, m, drawn, inst, inst.buttons.active[1]
end

local function near(a, b) return math.abs((a or 1) - (b or 1)) < 1e-6 end

local function assertColor(got, want, what)
    for i = 1, 4 do
        assertTrue(near(got and got[i], want and want[i]),
            ("%s[%d]: got %s, want %s"):format(what, i, tostring(got and got[i]), tostring(want and want[i])))
    end
end

local function notWhite(c, what)
    assertFalse(c[1] == 1 and c[2] == 1 and c[3] == 1, what .. " is white")
end

-- ── WoW Default ──

test("pad looks: WoW Default's bands and window edge are no client art's white tint", function()
    local NS, _, drawn, inst = padUnder("wow")
    -- red under: qc.bandEdge, qc.headEdge and the window's edge following win.border, the white a dialog
    -- art multiplies by. The header and the section bands draw no edge while they follow (R5-QC1), so
    -- their tint is for a border the player stores.
    notWhite({ NS.Skin.Color("qc.bandEdge") }, "a section band's stored edge")
    notWhite({ NS.Skin.Color("qc.headEdge") }, "the header's stored edge")
    notWhite(drawn[inst.root].border, "the window's edge")
end)

test("pad looks: WoW Default's bands never take the dialog art's size", function()
    local _, _, drawn, inst = padUnder("wow")
    -- red under: a band edge following win.borderSize, 32 for the art, clamped to a solid 16 px bar.
    -- Since R5-QC1 a following band draws none at all.
    assertEqual(drawn[inst.header].edgeSize, 0, "the header's edge")
end)

test("pad looks: WoW Default's window wears the dialog border art the Skin Tester shows, no other skin does (SF-QC-3)", function()
    local NS, m = padUnder("wow")
    anyMedia(NS)
    local look = { borderStyle = "None", borderSize = 1, borderStyleFromSkin = true }
    local skin = NS.PadRender.SkinFor(look, false, NS.PadRender.WINDOW_TOKENS)
    assertEqual(skin.edgeFile, "media:Blizzard Dialog", "the art")
    assertTrue(skin.edgeSize >= 8, "a thickness that shows it: " .. tostring(skin.edgeSize))
    -- a band takes none of it: while it follows it draws no edge (R5-QC1)
    assertEqual(NS.PadRender.SkinFor(look, true, NS.PadRender.BAND_TOKENS).edgeSize, 0)
    -- a pad that does not follow the skin keeps its own border
    local own = NS.PadRender.SkinFor({ borderStyle = "None", borderSize = 1, borderStyleFromSkin = false }, false,
        NS.PadRender.WINDOW_TOKENS)
    assertEqual(own.edgeSize, 1)
    m.LibStub("LibKa0s-Skin-1.0"):SetChoice(OWNER, "ka0s", "glass")
    local glass = NS.PadRender.SkinFor(look, false, NS.PadRender.WINDOW_TOKENS)
    assertTrue(glass.edgeFile ~= "media:Blizzard Dialog", "only WoW Default")
end)

test("pad looks: WoW Default's buttons are the skin's red, no bar texture dimming it", function()
    local NS, _, drawn, _, btn = padUnder("wow")
    local r, g, b, a = NS.Skin.Color("btn.bg")
    -- red under: the Blizzard status bar art, a dim gray, multiplying the red down to maroon
    assertColor(btn.qcBg.__color, { r, g, b, a }, "a button's body")
    anyMedia(NS)
    assertNil(NS.PadRender.ButtonLook(NS.db.profile.pads.p1.button).texture, "a flat body")
    assertColor(drawn[btn.qcEdge].border, { NS.Skin.Color("btn.border") }, "a button's edge")
end)

test("pad looks: a dial's page dots take no white ring under WoW Default", function()
    local NS, m = D.live()
    m.LibStub("LibKa0s-Skin-1.0"):SetChoice(OWNER, "ka0s", "wow")
    notWhite({ NS.Skin.Color("qc.pageDotEdge") }, "the dot's edge")
end)

test("pad looks: the Skin tab's texture override still reaches a button under WoW Default", function()
    local NS, m = padUnder("wow")
    m.LibStub("LibKa0s-Skin-1.0"):SetOverride(OWNER, false, "Ka0s Matte")
    assertTrue(NS.SchemaRuntime.Set("skin.texture", "Ka0s Matte"))
    anyMedia(NS)
    assertEqual(NS.PadRender.ButtonLook(NS.db.profile.pads.p1.button).texture, "media:Ka0s Matte")
end)

-- WoW Default's bar.borderStyle is a real style, the tooltip's art at 2: tinted by the owner tokens,
-- that art draws no white. A button wears it; the header and the section bands, borderless bands in
-- every skin WoW Default included (R5-QC1, the lead's call 5), do not, unless the player stores one.
test("pad looks: WoW Default's real border style paints no white band", function()
    local NS, m, drawn, inst, btn = padUnder("wow")
    local tokens = m.LibStub("LibKa0s-Skin-1.0"):ResolveSkin("wow")
    assertEqual(tokens["bar.borderStyle"], "Blizzard Tooltip", "the style this case is about")
    assertEqual(tokens["bar.borderSize"], 2, "and its thickness")
    local gray, edge = { 0x6E / 255, 0x6E / 255, 0x6E / 255, 1 }, { 0x9A / 255, 0x9A / 255, 0x9A / 255, 1 }
    assertColor(drawn[inst.root].border, edge, "the window's art")
    -- red under the round 4 band: the header wearing the tooltip art at 2
    assertTrue(drawn[inst.header].edgeFile == nil, "the header is a borderless band")
    assertEqual(drawn[btn.qcEdge].edgeSize, 2, "a button at the skin's thickness")
    notWhite(drawn[btn.qcEdge].border, "a button's art")
    anyMedia(NS)
    local R = NS.PadRender
    local p = NS.db.profile.pads.p1
    assertTrue(R.SectionLook(p.section).skin.edgeFile == nil, "a section band is borderless too")
    -- a border the player stores on the header draws, in the header's own tint
    local stored = { borderStyle = "Blizzard Tooltip", borderSize = 2, borderStyleFromSkin = false,
        borderColorFromSkin = true }
    local header = R.SkinFor(stored, true, R.HEADER_TOKENS)
    assertEqual(header.edgeFile, "media:Blizzard Tooltip", "the stored art")
    assertColor(header.border, gray, "tinted qc.headEdge, no white")
end)

-- ── the edges ──

for _, key in ipairs({ "glass", "midnight", "contrast", "obsidian", "azeroth" }) do
    test("pad looks: " .. key .. "'s bands and buttons draw a 1 px edge", function()
        local _, _, drawn, inst, btn = padUnder(key)
        -- red under: a band edge following win.borderSize (Glass's 8, the others' 2). The header is a
        -- borderless band since R5-QC1 (round 4 drew it a 1 px hairline).
        assertEqual(drawn[inst.header].edgeSize, 0, "the header's band")
        assertEqual(drawn[btn.qcEdge].edgeSize, 1, "a button")
        assertEqual(drawn[inst.root].edgeSize, 1, "the window")
    end)
end

test("pad looks: a section band draws no edge while it follows, as the header draws none", function()
    local NS = padUnder("glass")
    local sl = NS.PadRender.SectionLook(NS.db.profile.pads.p1.section)
    -- red under the round 4 hairline (qc.bandEdgeSize): the section band boxed like a second header
    assertEqual(sl.skin.edgeSize, 0)
end)

test("pad looks: Ka0s Default's bands stay undrawn", function()
    local _, _, drawn, inst = padUnder("ka0s")
    assertEqual(drawn[inst.header].edgeSize, 0, "no edge")
    assertNil(drawn[inst.header].edgeFile, "no art")
end)

test("pad looks: a following band draws no edge in any skin; a border the player stores draws as stored", function()
    local NS, m, drawn, inst = padUnder("obsidian")
    assertTrue(NS.SchemaRuntime.Set("pad.header.borderSize", 4, "p1"))
    NS.Surfaces.ApplyAll("test")
    -- R5-QC1: while the border follows the skin the header is a borderless band, whatever thickness is
    -- stored under it (round 4 drew that thickness under a skin's None, the skin's under a real style)
    assertEqual(drawn[inst.header].edgeSize, 0, "following: no edge")
    NS.db.profile.pads.p1.header.borderStyleFromSkin = false
    NS.Surfaces.ApplyAll("test")
    assertEqual(drawn[inst.header].edgeSize, 4, "stored: the player's")
    m.LibStub("LibKa0s-Skin-1.0"):SetChoice(OWNER, "ka0s", "azeroth")
    NS.Surfaces.ApplyAll("test")
    assertEqual(drawn[inst.header].edgeSize, 4, "stored: the player's in every skin")
end)

-- ── Ka0s Default's buttons ──

test("pad looks: Ka0s Default's buttons are the fuller body, edge, texture and gloss", function()
    local NS, _, drawn, _, btn = padUnder("ka0s")
    anyMedia(NS)
    local cl = NS.PadRender.ButtonLook(NS.db.profile.pads.p1.button)
    -- red under: the #3F3F3F wash at 25% and the near-black gloss the owner called vanilla
    assertColor(cl.bg, { 0.10, 0.10, 0.12, 0.90 }, "the body")
    assertColor(drawn[btn.qcEdge].border, { 0.24, 0.24, 0.27, 0.90 }, "the edge")
    assertEqual(cl.texture, "media:Ka0s Default", "the gradient")
    assertEqual(cl.shine.look, "glossfade")
    assertTrue(near(cl.shine.tint[1], 0x80 / 255), "a gloss that reads")
end)

-- ── the shine ──

local function shineOf(NS)
    local p, d = NS.db.profile.pads.p1.button, NS.PadDefaults.DialSlice()
    return NS.Shine.Resolve(p, "qc.btnShine", "qc.btnShineTint", "qc.btnShineStrength"),
        NS.Shine.Resolve(d, "qc.sliceShine", "qc.sliceShineTint", "qc.sliceShineStrength")
end

test("pad looks: every skin's shine is a third lighter, a button's and a slice's alike", function()
    local NS, m = D.live()
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    for _, def in ipairs(Skin:Skins()) do
        Skin:SetChoice(OWNER, "ka0s", def.key)
        local pad, slice = shineOf(NS)
        -- red under: Strength read from the store while the look follows (80, 85)
        assertEqual(pad.alpha, 0.55, def.key .. "'s button")
        assertEqual(slice.alpha, 0.55, def.key .. "'s slice")
    end
end)

test("pad looks: what reaches a button and a slice is the lighter strength", function()
    local NS = padUnder("obsidian")
    local cl = NS.PadRender.ButtonLook(NS.db.profile.pads.p1.button)
    assertEqual(cl.shine.alpha, 0.55, "a button")
    local dial = NS.db.profile.dials.d2
    assertEqual(NS.DialRender.Look(120, dial.label, dial.slice, dial).shine.alpha, 0.55, "a slice")
end)

test("pad looks: a player's stored Strength stands with the companion off", function()
    local NS, m = D.live()
    local S = NS.SchemaRuntime
    assertTrue(S.Set("pad.button.shineFromSkin", false, "p1"))
    assertTrue(S.Set("pad.button.shineStrength", 90, "p1"))
    assertTrue(S.Set("dial.slice.shineFromSkin", false, "d2"))
    assertTrue(S.Set("dial.slice.shineStrength", 15, "d2"))
    m.LibStub("LibKa0s-Skin-1.0"):SetChoice(OWNER, "ka0s", "glass")
    assertEqual(NS.PadRender.ButtonLook(NS.db.profile.pads.p1.button).shine.alpha, 0.9, "a button")
    local dial = NS.db.profile.dials.d2
    assertEqual(NS.DialRender.Look(120, dial.label, dial.slice, dial).shine.alpha, 0.15, "a slice")
end)

test("pad looks: a stored Strength with no strength token is as stored", function()
    local NS = D.live()
    assertEqual(NS.Shine.Resolve({ shineFromSkin = true, shineLook = "orb", shineStrength = 40 }, "qc.btnShine",
        "qc.btnShineTint").alpha, 0.4)
end)

test("pad looks: with the library absent a button stays flat and its stored Strength draws", function()
    local NS = T.enableAddon{ skip = T.loadAddon.libFiles }
    assertTrue(NS.Skin.IsEnabled() == false, "the degraded facade")
    anyMedia(NS)
    -- red under: the degraded S.Token answering qc.btnTexture's "Ka0s Default", and qc.btnShineStrength's 55
    assertNil(NS.PadRender.ButtonLook({ textureFromSkin = true }).texture, "no texture")
    assertEqual(NS.Shine.Resolve({ shineFromSkin = true, shineLook = "orb", shineStrength = 40 }, "qc.btnShine",
        "qc.btnShineTint", "qc.btnShineStrength").alpha, 0.4, "the stored Strength")
end)
