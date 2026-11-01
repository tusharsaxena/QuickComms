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
    local _, _, drawn, inst = padUnder("wow")
    -- red under: qc.bandEdge and the window's edge following win.border, the white a dialog art multiplies by
    notWhite(drawn[inst.header].border, "the header's edge")
    notWhite(drawn[inst.root].border, "the window's edge")
end)

test("pad looks: WoW Default's bands keep a hairline, not the dialog art's size", function()
    local _, _, drawn, inst = padUnder("wow")
    -- red under: qc.bandEdgeSize following win.borderSize, 32 for the art, clamped to a solid 16 px bar
    assertTrue(drawn[inst.header].edgeSize <= 2, "the header's edge: " .. tostring(drawn[inst.header].edgeSize))
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
-- that art draws no white.
test("pad looks: WoW Default's real border style paints no white band", function()
    local NS, m, drawn, inst, btn = padUnder("wow")
    local tokens = m.LibStub("LibKa0s-Skin-1.0"):ResolveSkin("wow")
    assertEqual(tokens["bar.borderStyle"], "Blizzard Tooltip", "the style this case is about")
    assertEqual(tokens["bar.borderSize"], 2, "and its thickness")
    local gray, edge = { 0x6E / 255, 0x6E / 255, 0x6E / 255, 1 }, { 0x9A / 255, 0x9A / 255, 0x9A / 255, 1 }
    -- red under: a band's art tinted win.border, the white WoW Default's dialog art is multiplied by
    assertColor(drawn[inst.header].border, gray, "the header's art")
    assertColor(drawn[inst.root].border, edge, "the window's art")
    assertEqual(drawn[inst.header].edgeSize, 2, "the header at the skin's thickness")
    assertEqual(drawn[btn.qcEdge].edgeSize, 2, "a button too")
    notWhite(drawn[btn.qcEdge].border, "a button's art")
    notWhite(drawn[inst.header].bg, "the header's fill")
    anyMedia(NS)
    local R = NS.PadRender
    local p = NS.db.profile.pads.p1
    local header = R.SkinFor(p.header, true, R.BAND_TOKENS)
    assertEqual(header.edgeFile, "media:Blizzard Tooltip", "the art is the skin's, not the flat edge")
    assertColor(header.border, gray, "and the header's tint stays on it")
    assertColor(R.SectionLook(p.section).skin.border, gray, "a section band's")
end)

-- ── the edges ──

for _, key in ipairs({ "glass", "midnight", "contrast", "obsidian", "azeroth" }) do
    test("pad looks: " .. key .. "'s bands and buttons draw a 1 px edge", function()
        local _, _, drawn, inst, btn = padUnder(key)
        -- red under: qc.bandEdgeSize following win.borderSize (Glass's 8, the others' 2)
        assertEqual(drawn[inst.header].edgeSize, 1, "the header's band")
        assertEqual(drawn[btn.qcEdge].edgeSize, 1, "a button")
        assertEqual(drawn[inst.root].edgeSize, 1, "the window")
    end)
end

test("pad looks: a section band draws the same 1 px edge as the header's", function()
    local NS = padUnder("glass")
    local sl = NS.PadRender.SectionLook(NS.db.profile.pads.p1.section)
    assertEqual(sl.skin.edgeSize, 1)
end)

test("pad looks: Ka0s Default's bands stay undrawn", function()
    local _, _, drawn, inst = padUnder("ka0s")
    assertEqual(drawn[inst.header].edgeSize, 0, "no edge")
    assertNil(drawn[inst.header].edgeFile, "no art")
end)

test("pad looks: a band's stored thickness defers under a skin's None, and a real style wins", function()
    local NS, m, drawn, inst = padUnder("obsidian")
    assertEqual(m.LibStub("LibKa0s-Skin-1.0"):ResolveSkin("obsidian")["bar.borderStyle"], "None", "no border of its own")
    assertTrue(NS.SchemaRuntime.Set("pad.header.borderSize", 4, "p1"))
    NS.Surfaces.ApplyAll("test")
    -- red under: the hairline token over a thickness the player stored
    assertEqual(drawn[inst.header].edgeSize, 4, "None: the player's")
    m.LibStub("LibKa0s-Skin-1.0"):SetChoice(OWNER, "ka0s", "azeroth")
    NS.Surfaces.ApplyAll("test")
    assertEqual(drawn[inst.header].edgeSize, 1, "a real style: the skin's")
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
