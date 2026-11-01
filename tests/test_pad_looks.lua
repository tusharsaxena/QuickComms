-- tests/test_pad_looks.lua — the Comms Pad's look in each skin (the owner's in-game findings of
-- 2026-11-01): WoW Default's white bands and maroon buttons, the thick band edges of the skins whose
-- window edge is more than a hairline, Ka0s Default's fuller buttons and a shine a third lighter. Read
-- off what reaches NS.ApplySkin and the drawing setters.
--
-- Each case runs twice: on the library this repo vendors, and on the values LibKa0s v1.85.0 changes
-- (the skin's own bar.bg, bar.border, icon.border, glow.color, cover.dim, a real bar.borderStyle in four
-- skins, and a skin's None deferring to the stored style). `newerValues` lays those over the vendored
-- skins, so a fix that holds on one only goes red on the other. A later re-vendor retires it.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local D = dofile("tests/dial_helpers.lua")
local OWNER = "QuickComms"

local function hex(s, a)
    return { tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255, a or 1 }
end

-- SkinDefsOthers minor 7's tables (LibKa0s v1.85.0, 2ad1a50), ember's and forever's included.
local NEWER = {
    obsidian = { bg = hex("141416", 0.8), edge = hex("2a2a30"), icon = hex("34343b"), glow = hex("4db8ff"), dim = hex("050506", 0.7) },
    azeroth = { bg = hex("1a110a", 0.8), edge = hex("6b4a22"), icon = hex("8a6a36"), glow = hex("e2b659"), dim = hex("1a110a", 0.7),
        style = "Solid", size = 1 },
    glass = { bg = { 1, 1, 1, 0.08 }, edge = { 1, 1, 1, 0.22 }, icon = { 1, 1, 1, 0.18 }, glow = hex("b69cff"),
        dim = { 18 / 255, 22 / 255, 34 / 255, 0.6 } },
    contrast = { bg = hex("1a1a1a", 0.85), edge = hex("ffffff"), icon = hex("e0e0e0"), glow = hex("ffe600"), dim = hex("000000", 0.8),
        style = "Solid", size = 1 },
    ember = { bg = hex("140a07", 0.8), edge = hex("8a3c1c"), icon = hex("6a2e17"), glow = hex("ff7a33"), dim = hex("140a07", 0.7) },
    wow = { bg = hex("1e1c19", 0.7), edge = hex("6e6e6e"), icon = hex("9a9a9a"), glow = hex("e0b040"), dim = hex("1e1c19", 0.7),
        style = "Blizzard Tooltip", size = 2 },
    midnight = { bg = hex("08091a", 0.8), edge = hex("b08a3e"), icon = hex("5a4a26"), glow = hex("b48cff"), dim = hex("08091a", 0.7),
        style = "Solid", size = 1 },
    forever = { bg = hex("0a0908", 0.8), edge = hex("48433d"), icon = hex("3a3530"), glow = hex("c9a07a"), dim = hex("0a0908", 0.65) },
}

local BAR_EDGE = { ["bar.borderStyle"] = true, ["bar.borderSize"] = true }

--- The vendored library, answering v1.85.0's values: each skin re-registered, and Skin:Resolve's
--- deferral (minor 15) on the facade every paint reads.
local function newerValues(NS, m)
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    for key, v in pairs(NEWER) do
        local def = Skin:GetSkin(key)
        def.tokens["bar.bg"], def.tokens["bar.border"], def.tokens["icon.border"] = v.bg, v.edge, v.icon
        def.tokens["glow.color"], def.tokens["cover.dim"] = v.glow, v.dim
        if v.style then def.tokens["bar.borderStyle"], def.tokens["bar.borderSize"] = v.style, v.size end
        Skin:RegisterSkin(def)
    end
    local resolve = NS.Skin.Resolve
    NS.Skin.Resolve = function(kind, value, fromSkin)
        if fromSkin == true and value ~= nil and BAR_EDGE[kind] and NS.Skin.Token("bar.borderStyle") == "None" then
            return value
        end
        return resolve(kind, value, fromSkin)
    end
end

local function both(name, fn)
    test("pad looks: " .. name, function() fn(false) end)
    test("pad looks (v1.85.0 values): " .. name, function() fn(true) end)
end

-- The media library answering every name: the mock's knows none, and "" names no file.
local function anyMedia(NS)
    NS.MediaFetch = function(_, name)
        if name == nil or name == "" then return nil end
        return "media:" .. name
    end
end

-- A live pad under skin `key`, and every skin table NS.ApplySkin took, by frame.
local function padUnder(key, newer)
    local NS, m = D.live()
    if newer then newerValues(NS, m) end
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

both("WoW Default's bands and window edge are no client art's white tint", function(newer)
    local _, _, drawn, inst = padUnder("wow", newer)
    -- red under: qc.bandEdge and the window's edge following win.border, the white a dialog art multiplies by
    notWhite(drawn[inst.header].border, "the header's edge")
    notWhite(drawn[inst.root].border, "the window's edge")
end)

both("WoW Default's bands keep a hairline, not the dialog art's size", function(newer)
    local _, _, drawn, inst = padUnder("wow", newer)
    -- red under: qc.bandEdgeSize following win.borderSize, 32 for the art, clamped to a solid 16 px bar
    assertTrue(drawn[inst.header].edgeSize <= 2, "the header's edge: " .. tostring(drawn[inst.header].edgeSize))
end)

both("WoW Default's buttons are the skin's red, no bar texture dimming it", function(newer)
    local NS, _, drawn, _, btn = padUnder("wow", newer)
    local r, g, b, a = NS.Skin.Color("btn.bg")
    -- red under: the Blizzard status bar art, a dim gray, multiplying the red down to maroon
    assertColor(btn.qcBg.__color, { r, g, b, a }, "a button's body")
    anyMedia(NS)
    assertNil(NS.PadRender.ButtonLook(NS.db.profile.pads.p1.button).texture, "a flat body")
    assertColor(drawn[btn.qcEdge].border, { NS.Skin.Color("btn.border") }, "a button's edge")
end)

both("a dial's page dots take no white ring under WoW Default", function(newer)
    local NS, m = D.live()
    if newer then newerValues(NS, m) end
    m.LibStub("LibKa0s-Skin-1.0"):SetChoice(OWNER, "ka0s", "wow")
    notWhite({ NS.Skin.Color("qc.pageDotEdge") }, "the dot's edge")
end)

both("the Skin tab's texture override still reaches a button under WoW Default", function(newer)
    local NS, m = padUnder("wow", newer)
    m.LibStub("LibKa0s-Skin-1.0"):SetOverride(OWNER, false, "Ka0s Matte")
    assertTrue(NS.SchemaRuntime.Set("skin.texture", "Ka0s Matte"))
    anyMedia(NS)
    assertEqual(NS.PadRender.ButtonLook(NS.db.profile.pads.p1.button).texture, "media:Ka0s Matte")
end)

-- ── the edges ──

for _, key in ipairs({ "glass", "midnight", "contrast" }) do
    both(key .. "'s bands and buttons draw a 1 px edge", function(newer)
        local _, _, drawn, inst, btn = padUnder(key, newer)
        -- red under: qc.bandEdgeSize following win.borderSize (Glass's 8, the others' 2)
        assertEqual(drawn[inst.header].edgeSize, 1, "the header's band")
        assertEqual(drawn[btn.qcEdge].edgeSize, 1, "a button")
        assertEqual(drawn[inst.root].edgeSize, 1, "the window")
    end)
end

both("a section band draws the same 1 px edge as the header's", function(newer)
    local NS = padUnder("glass", newer)
    local sl = NS.PadRender.SectionLook(NS.db.profile.pads.p1.section)
    assertEqual(sl.skin.edgeSize, 1)
end)

both("Ka0s Default's bands stay undrawn", function(newer)
    local _, _, drawn, inst = padUnder("ka0s", newer)
    assertEqual(drawn[inst.header].edgeSize, 0, "no edge")
    assertNil(drawn[inst.header].edgeFile, "no art")
end)

-- ── Ka0s Default's buttons ──

both("Ka0s Default's buttons are the fuller body, edge, texture and gloss", function(newer)
    local NS, _, drawn, _, btn = padUnder("ka0s", newer)
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

both("every skin's shine is a third lighter, a button's and a slice's alike", function(newer)
    local NS, m = D.live()
    if newer then newerValues(NS, m) end
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

both("a player's stored Strength stands with the companion off", function(newer)
    local NS, m = D.live()
    if newer then newerValues(NS, m) end
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
