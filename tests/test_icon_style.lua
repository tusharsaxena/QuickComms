-- tests/test_icon_style.lua — the Icons tab's look (B9, modules/IconStyle.lua): a Comms Pad button's
-- and a Comms Dial wedge's icon, its size (a button's feeds the button's geometry), crop, desaturation,
-- alpha, tint (multiplied with a glyph's own color) and border (a square backdrop on a button, a round
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
    return NS.Pad.ButtonsFor("p1", T.seeded(NS, "bi.mplus.pull"))[1]
end

local function set(NS, path, v, id)
    local ok, err, why = NS.SchemaRuntime.Set(path, v, id or "p1")
    assertTrue(ok, tostring(why or err))
end

local function csv(t) return table.concat(t, ",") end

test("icon style: the defaults draw the owner's look on a button and on a wedge", function()
    local NS = live()
    local button = rebuild(NS)
    local tex = button.qcIcon
    -- red under: a default zoom other than 0 (the icons would be cropped)
    assertEqual(csv(tex.__texCoord), "0,1,0,1")
    assertFalse(tex.__desaturated)
    assertEqual(tex:GetAlpha(), 1)
    assertEqual(csv(tex.__size), "16,16", "the owner's 16-pixel button icon")
    assertNil(button.qcBorder, "no border by default")
    local w, h = NS.PadLayout.CellSize({ style = "iconLabel", width = 100 }, 10, 16)
    assertEqual(w .. "x" .. h, "100x24", "the shipped button")
    assertEqual(button.__h, 24)
    local d = NS.db.profile.dials
    local did = NS.db.profile.dialOrder[1]
    assertEqual(d[did].icon.size, 0, "automatic: 48 at the default radius")
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

test("icon style: a pad's icon size feeds the button's geometry", function()
    local NS = live()
    local PL = NS.PadLayout
    local _, h = PL.CellSize({ style = "iconLabel", width = 100 }, 10, 36)
    assertEqual(h, 40, "a 36 icon makes a 40-pixel button")
    assertEqual(select(1, PL.CellSize({ style = "icon" }, 10, 36)), 44, "an icon-only button stays square around it")
    assertEqual(select(1, PL.CellSize({ style = "icon" }, 10)), PL.ICON_ONLY, "no size: the shipped square")
    set(NS, "pad.icon.size", 36)
    local button = rebuild(NS)
    assertEqual(csv(button.qcIcon.__size), "36,36")
    assertEqual(button.__h, 40)
    assertTrue(NS.PadRender.LabelRoom(100, "iconLabel", 36) < NS.PadRender.LabelRoom(100, "iconLabel", 20),
        "a bigger icon leaves the label less room")
end)

test("icon style: a button's border is off by default; on, it is a backdrop over the icon in its color", function()
    local NS = live()
    local button = rebuild(NS)
    assertNil(button.qcIconFrame and button.qcIconFrame.__backdrop)
    set(NS, "pad.icon.borderShow", true)
    set(NS, "pad.icon.borderSize", 3)
    set(NS, "pad.icon.borderColor", { r = 1, g = 0, b = 0, a = 1 })
    button = rebuild(NS)
    assertEqual(csv(button.qcBorder), "1,0,0,1")
    assertEqual(button.qcBorderSize, 3)
    set(NS, "pad.icon.borderShow", false)
    button = rebuild(NS)
    assertNil(button.qcBorder, "off again")
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
    assertEqual(w.qcRing.__texture, NS.DialSlices.DISC, "the dial's own disc, not the portrait mask")
    -- red under: a square backdrop on the round wedge
    assertEqual(csv(w.qcRing.__size), "34,34")
    assertEqual(csv(w.qcBorder), "0,0,0,1")
    assertEqual(csv(w.qcIcon.__size), "30,30")
    set(NS, "dial.icon.borderShow", false, did)
    assertTrue(NS.Dial.Apply(1, did, plan))
    assertFalse(w.qcRing:IsShown())
end)

test("icon style: a wedge's ring never grows past the wedge, so it cannot reach the next wedge or its label", function()
    local NS = live()
    local did = NS.db.profile.dialOrder[1]
    set(NS, "dial.icon.borderShow", true, did)
    set(NS, "dial.icon.borderSize", 16, did)
    set(NS, "dial.icon.size", 40, did)
    local snap = NS.Situation.Current()
    local plan = NS.Surfaces.BuildDialPlan(did, NS.db.profile.dials[did], snap, NS.Surfaces.Deps(snap))
    assertTrue(NS.Dial.Apply(1, did, plan))
    local w = NS.Dial.RingWedges(did, 1)[1]
    local d = NS.DialLayout.WEDGE
    -- red under: size the ring icon + 2 x thickness unclamped (72 around a 44 px wedge)
    assertEqual(csv(w.qcRing.__size), d .. "," .. d)
    assertEqual(csv(w.qcIcon.__size), "40,40")
end)

test("icon style: a pad saved before the Icons tab reads like a new one (fillShape backfills `icon`)", function()
    local NS = live()
    NS.db.profile.pads.p1.icon = nil
    local did = NS.db.profile.dialOrder[1]
    NS.db.profile.dials[did].icon = { zoom = 0.2 }
    NS.Library.Prepare()
    assertEqual(NS.db.profile.pads.p1.icon.size, 16, "the default size")
    assertEqual(NS.db.profile.dials[did].icon.zoom, 0.2, "a stored field is kept")
    assertEqual(NS.db.profile.dials[did].icon.size, 0, "automatic")
end)

test("icon style: [polish] dial icon size reaches 128, pad stays 40", function()
    local NS = live()
    -- red under: D.SIZE.dial.max left at 40
    assertEqual(NS.IconDefaults.SIZE.dial.max, 128)
    assertEqual(NS.IconDefaults.SIZE.pad.max, 40, "pads unchanged")
    local did = NS.db.profile.dialOrder[1]
    set(NS, "dial.icon.size", 128, did)
    assertEqual(NS.db.profile.dials[did].icon.size, 128)
    set(NS, "dial.icon.size", 200, did)
    assertEqual(NS.db.profile.dials[did].icon.size, 128, "stops at 128")
    assertEqual(NS.IconStyle.Config({ size = 128 }, "dial").size, 128, "drawn at 128")
    assertEqual(NS.IconStyle.Config({ size = 128 }, "pad").size, 40, "a pad's stops at 40")
    set(NS, "pad.icon.size", 60)
    assertEqual(NS.db.profile.pads.p1.icon.size, 40)
    local max
    for _, row in ipairs(NS.addon.Settings.RowsForPage("dials")) do
        if row.path == "dial.icon.size" then max = row.max end
    end
    assertEqual(max, 128, "the slider reaches 128")
end)

test("icon style: [autofit] a dial's icon size 0 is automatic: it scales with the ring radius", function()
    local NS = live()
    local did = NS.db.profile.dialOrder[1]
    local function drawn(radius)
        set(NS, "dial.radius", radius, did)
        local snap = NS.Situation.Current()
        local plan = NS.Surfaces.BuildDialPlan(did, NS.db.profile.dials[did], snap, NS.Surfaces.Deps(snap))
        assertTrue(NS.Dial.Apply(1, did, plan))
        return csv(NS.Dial.RingWedges(did, 1)[1].qcIcon.__size)
    end
    -- red under: a new dial's icon size left at 32
    assertEqual(NS.db.profile.dials[did].icon.size, 0, "a new dial's icons are automatic")
    assertEqual(drawn(120), "48,48", "the default radius draws the default")
    assertEqual(drawn(100), "40,40")
    -- red under: IconStyle.Config clamps 0 up to the row's minimum (16)
    assertEqual(drawn(150), "60,60")
    assertEqual(drawn(180), "72,72")
    set(NS, "dial.icon.size", 40, did)
    assertEqual(drawn(150), "40,40", "a manual size is kept at any radius")
    assertEqual(drawn(100), "40,40")
    assertEqual(NS.IconStyle.Config({ size = 0 }, "dial", 48).size, 48)
    assertEqual(NS.IconStyle.Config({ size = 0 }, "dial").size, 48, "no wheel to read: the default")
    assertEqual(NS.IconStyle.Config({ size = 0 }, "pad").size, 12, "a pad has no automatic size")
    local row
    for _, r in ipairs(NS.addon.Settings.RowsForPage("dials")) do
        if r.path == "dial.icon.size" then row = r end
    end
    assertEqual(row.min .. "," .. row.max .. "," .. tostring(row.default), "0,128,0")
    assertEqual(row.zeroText, NS.L["Automatic"])
    set(NS, "dial.icon.size", 5, did)
    assertEqual(NS.db.profile.dials[did].icon.size, 16, "under the minimum but not automatic: the minimum")
    set(NS, "dial.icon.size", 0, did)
    assertEqual(NS.db.profile.dials[did].icon.size, 0)
end)
