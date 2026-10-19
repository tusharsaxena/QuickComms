-- tests/test_icon_style.lua — the Icons tab's look (B9, modules/IconStyle.lua): a Comms Pad chip's
-- and a Comms Dial wedge's icon, its size (a chip's feeds the chip's geometry), crop, desaturation,
-- alpha, tint (multiplied with a glyph's own color) and border (a square backdrop on a chip, a round
-- ring behind a wedge's icon). Every default draws the icon as it was drawn before the tab existed.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function live()
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    return NS, m
end

local function planFor(NS)
    local snap = NS.Situation.Current()
    return NS.Surfaces.BuildPlan("p1", NS.db.profile.pads.p1, snap, NS.Surfaces.Deps(snap))
end

local function rebuild(NS)
    assertTrue(NS.Pad.Apply("p1", planFor(NS)))
    return NS.Pad.ChipsFor("p1", T.seeded(NS, "bi.mplus.pull"))[1]
end

local function set(NS, path, v, id)
    local ok, err, why = NS.SchemaRuntime.Set(path, v, id or "p1")
    assertTrue(ok, tostring(why or err))
end

local function csv(t) return table.concat(t, ",") end

test("icon style: the defaults keep today's look on a chip and on a wedge", function()
    local NS = live()
    local chip = rebuild(NS)
    local tex = chip.qcIcon
    -- red under: a default zoom other than 0 (the icons would be cropped)
    assertEqual(csv(tex.__texCoord), "0,1,0,1")
    assertFalse(tex.__desaturated)
    assertEqual(tex:GetAlpha(), 1)
    assertEqual(csv(tex.__size), "20,20")
    assertNil(chip.qcBorder, "no border by default")
    local w, h = NS.PadLayout.CellSize({ style = "iconLabel", width = 100 }, 10, 20)
    assertEqual(w .. "x" .. h, "100x24", "the shipped chip")
    assertEqual(chip.__h, 24)
    local d = NS.db.profile.dials
    local did = NS.db.profile.dialOrder[1]
    assertEqual(d[did].icon.size, 32)
    assertEqual(d[did].icon.glowEnabled, false)
end)

test("icon style: zoom crops through SetTexCoord, desaturate and alpha reach the texture", function()
    local NS = live()
    set(NS, "pad.icon.zoom", 0.1)
    set(NS, "pad.icon.desaturate", true)
    set(NS, "pad.icon.alpha", 0.5)
    local tex = rebuild(NS).qcIcon
    assertEqual(csv(tex.__texCoord), "0.1,0.9,0.1,0.9")
    assertTrue(tex.__desaturated)
    assertEqual(tex:GetAlpha(), 0.5)
    set(NS, "pad.icon.zoom", 0.9)
    assertEqual(NS.db.profile.pads.p1.icon.zoom, 0.25, "clamped to a quarter off each side")
end)

test("icon style: the tint multiplies a glyph's own color; white keeps it", function()
    local NS, m = live()
    local IS = NS.IconStyle
    local tex = m.CreateFrame("Frame", "QuickCommsIconTest", m.UIParent):CreateTexture()
    local icon = NS.IconDefaults.For("pad")
    IS.ApplyIcon(tex, IS.Config(icon, "pad"), 1, 0, 0)
    assertEqual(csv(tex.__color), "1,0,0", "a red glyph under the white tint")
    icon.tint = { r = 0.5, g = 1, b = 1, a = 0.5 }
    IS.ApplyIcon(tex, IS.Config(icon, "pad"), 1, 0.5, 0)
    -- red under: the tint replacing the glyph's color instead of multiplying it
    assertEqual(csv(tex.__color), "0.5,0.5,0")
    assertEqual(tex:GetAlpha(), 0.5, "the tint's alpha with the icon's")
end)

test("icon style: a pad's icon size feeds the chip's geometry", function()
    local NS = live()
    local PL = NS.PadLayout
    local _, h = PL.CellSize({ style = "iconLabel", width = 100 }, 10, 36)
    assertEqual(h, 40, "a 36 icon makes a 40-pixel chip")
    assertEqual(select(1, PL.CellSize({ style = "icon" }, 10, 36)), 44, "an icon-only chip stays square around it")
    assertEqual(select(1, PL.CellSize({ style = "icon" }, 10)), PL.ICON_ONLY, "no size: the shipped square")
    set(NS, "pad.icon.size", 36)
    local chip = rebuild(NS)
    assertEqual(csv(chip.qcIcon.__size), "36,36")
    assertEqual(chip.__h, 40)
    assertTrue(NS.PadRender.LabelRoom(100, "iconLabel", 0, 36) < NS.PadRender.LabelRoom(100, "iconLabel", 0, 20),
        "a bigger icon leaves the label less room")
end)

test("icon style: a chip's border is off by default; on, it is a backdrop over the icon in its color", function()
    local NS = live()
    local chip = rebuild(NS)
    assertNil(chip.qcIconFrame and chip.qcIconFrame.__backdrop)
    set(NS, "pad.icon.borderShow", true)
    set(NS, "pad.icon.borderSize", 3)
    set(NS, "pad.icon.borderColor", { r = 1, g = 0, b = 0, a = 1 })
    chip = rebuild(NS)
    assertEqual(csv(chip.qcBorder), "1,0,0,1")
    assertEqual(chip.qcBorderSize, 3)
    set(NS, "pad.icon.borderShow", false)
    chip = rebuild(NS)
    assertNil(chip.qcBorder, "off again")
end)

test("icon style: a wedge's border is a round ring behind its icon, icon plus twice the thickness", function()
    local NS = live()
    local did = NS.db.profile.dialOrder[1]
    set(NS, "dial.icon.borderShow", true, did)
    set(NS, "dial.icon.borderSize", 2, did)
    set(NS, "dial.icon.size", 30, did)
    local snap = NS.Situation.Current()
    local plan = NS.Surfaces.BuildDialPlan(did, NS.db.profile.dials[did], snap, NS.Surfaces.Deps(snap))
    assertTrue(NS.Dial.Apply(1, did, plan))
    local w = NS.Dial.RingWedges(did, 1)[1]
    assertTrue(w.qcRing ~= nil and w.qcRing:IsShown())
    -- red under: a square backdrop on the round wedge
    assertEqual(csv(w.qcRing.__size), "34,34")
    assertEqual(csv(w.qcBorder), "0,0,0,1")
    assertEqual(csv(w.qcIcon.__size), "30,30")
    set(NS, "dial.icon.borderShow", false, did)
    assertTrue(NS.Dial.Apply(1, did, plan))
    assertFalse(w.qcRing:IsShown())
end)

test("icon style: a pad saved before the Icons tab reads like a new one (fillShape backfills `icon`)", function()
    local NS = live()
    NS.db.profile.pads.p1.icon = nil
    local did = NS.db.profile.dialOrder[1]
    NS.db.profile.dials[did].icon = { zoom = 0.2 }
    NS.Library.Prepare()
    assertEqual(NS.db.profile.pads.p1.icon.size, 20)
    assertEqual(NS.db.profile.dials[did].icon.zoom, 0.2, "a stored field is kept")
    assertEqual(NS.db.profile.dials[did].icon.size, 32)
end)
