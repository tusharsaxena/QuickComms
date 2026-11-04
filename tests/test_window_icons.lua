-- tests/test_window_icons.lua — game icon art in Quick Comms' windows and settings pages (R5-ICON,
-- Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND5, owner item 7, the lead's call 9; the rule is
-- LibKa0s docs/api/README.md "Icon art: the rule"):
--   - every Blizzard icon art a window or a settings page draws is cropped at least 0.07 a side, so no
--     native bevel shows (the icon browser's cells and its footer preview, the icon chooser's preview,
--     a reorder row's and a table row's icon);
--   - and edged 1 physical px in icon.outline (S.IconBorder, no `hud`), on a frame of this addon's own
--     laid over the art: never on an AceGUI widget's image, which AceGUI pools across every addon;
--     handed back when the widget is released. The edge follows the settings page's Scope as the
--     library's id list does (OptionsIdList: no edge while the owner ignores its settings panel);
--   - a LibKa0s glyph and a raid marker are exempt: uncropped, no edge (IconStyle.NativeEdge).
-- The HUD's icons are tests/test_icon_style.lua's (R4-ZOOM, icon.border).

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local OWNER = "QuickComms"
local GAME = 136116
local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"

local function boot()
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return {} end
    NS.Situation.RefreshNow("test")
    local P = dofile("tests/page_helpers.lua")(NS, m)
    m.SettingsPanel:Show()
    m.macroIcons, m.macroItemIcons = { GAME, 2 }, {}
    return NS, m, P, m.LibStub("LibKa0s-Skin-1.0")
end

local function crop(coords, what)
    assertTrue(type(coords) == "table", what .. ": cropped")
    assertEqual(table.concat(coords, ","), "0.07,0.93,0.07,0.93", what .. ": 0.07 a side")
end

local function whole(coords, what)
    assertTrue(coords == nil or table.concat(coords, ",") == "0,1,0,1", what .. ": the whole art")
end

--- `holder`'s edge frame, shown and painted as a window icon's (icon.outline, no hud, no zoom). The
--- icon browser's cells keep it on `ibIconEdge` (LibKa0s IconBrowserWindow.lua's W.Edge), this
--- addon's own holders on `qcIconEdge` (modules/IconStyle.lua's WindowEdge): `field` picks.
local function assertEdged(Skin, holder, what, field)
    local e = holder[field or "qcIconEdge"]
    assertTrue(e ~= nil and e:IsShown(), what .. ": an edge frame of the addon's own")
    local rec = Skin.painted[e]
    local call = rec and rec.calls.IconBorder
    assertTrue(call ~= nil, what .. ": S.IconBorder painted it")
    local opts = call[1]
    assertTrue(opts.fromSkin == true and not opts.hud, what .. ": icon.outline, a window's edge")
end

local function assertBare(holder, what, field)
    local e = holder[field or "qcIconEdge"]
    assertTrue(e == nil or not e:IsShown(), what .. ": no edge")
end

local function cellFor(B, icon)
    for _, c in ipairs(B.cells) do
        if c:IsShown() and c.ibIcon == icon then return c end
    end
    return nil
end

local function openBrowser(B, icon)
    assertTrue(B.Open({ icon = icon, owner = "test", onChoose = function() end }))
end

-- ── the icon browser ──────────────────────────────────────────────────────────────────────────────

test("window icons: a game icon in the browser's grid is cropped and edged; a glyph and a marker are not", function()
    local NS, _, _, Skin = boot()
    Skin:SetIgnore(OWNER, false, nil)   -- the settings page skinned: the edge draws
    local B = NS.addon.Settings.IconBrowser
    openBrowser(B, nil)
    B.SetTab("game")
    local cell = cellFor(B, GAME)
    assertTrue(cell ~= nil, "the game icon is drawn")
    -- red under: cell.icon:SetTexture(v) alone, the full 0..1 art and its native bevel, no edge
    crop(cell.icon.__texCoord, "a game icon")
    assertEdged(Skin, cell, "a game icon", "ibIconEdge")
    B.SetTab("markers")
    local marker = cellFor(B, SKULL)
    whole(marker.icon.__texCoord, "a raid marker")
    assertBare(marker, "a raid marker", "ibIconEdge")
    B.SetTab("glyphs")
    local glyph = cellFor(B, NS.Icon("star"))
    whole(glyph.icon.__texCoord, "a glyph")
    assertBare(glyph, "a glyph", "ibIconEdge")
    B.Cancel()
end)

test("window icons: the browser's footer preview of a game icon is cropped and edged", function()
    local NS, _, _, Skin = boot()
    Skin:SetIgnore(OWNER, false, nil)
    local B = NS.addon.Settings.IconBrowser
    openBrowser(B, GAME)
    local preview = B.Widgets().preview
    crop(preview.__texCoord, "the preview")
    assertEdged(Skin, { qcIconEdge = B.Widgets().previewEdge }, "the preview")
    B.Select(NS.Icon("star"))
    whole(preview.__texCoord, "a glyph's preview")
    assertBare({ qcIconEdge = B.Widgets().previewEdge }, "a glyph's preview")
    B.Cancel()
end)

test("window icons: under the Scope's Ignore settings panel (the default) a game icon is cropped, not edged", function()
    local NS = boot()
    local B = NS.addon.Settings.IconBrowser
    openBrowser(B, nil)
    B.SetTab("game")
    local cell = cellFor(B, GAME)
    crop(cell.icon.__texCoord, "a game icon")
    -- as the library's id list: a stock settings page wears no Ka0s edge
    assertBare(cell, "a game icon on a stock page", "ibIconEdge")
    B.Cancel()
end)

-- ── the AceGUI images (the icon chooser, a reorder row, a table row) ──────────────────────────────

test("window icons: an AceGUI image of a game icon is cropped through SetImage and edged on a frame of the addon's own", function()
    local NS, _, _, Skin = boot()
    Skin:SetIgnore(OWNER, false, nil)
    local Ed = NS.addon.Settings.Editors
    local AceGUI = NS.addon.Settings.Helpers.AceGUI
    for _, kind in ipairs({ "Label", "Icon" }) do
        local w = AceGUI:Create(kind)
        -- red under: no Ed.FramedImage (widget:SetImage(icon) alone)
        Ed.FramedImage(w, GAME)
        assertEqual(w.image[1], GAME, kind .. ": the art")
        crop({ w.image[2], w.image[3], w.image[4], w.image[5] }, kind)
        assertEdged(Skin, w, kind)
        local e = w.qcIconEdge
        assertTrue(Skin.painted[w.image] == nil, kind .. ": nothing recorded on AceGUI's pooled image")
        Ed.FramedImage(w, NS.Icon("star"))
        assertNil(w.image[2], kind .. ": a glyph is not cropped")
        assertBare(w, kind .. ": a glyph")
        Ed.FramedImage(w, GAME)
        w:Release()
        assertBare(w, kind .. ": released, the edge is handed back")
        assertFalse(e:IsShown(), kind .. ": and hidden")
    end
end)

test("window icons: the callout popup's icon chooser frames a game icon", function()
    local NS, _, P, Skin = boot()
    Skin:SetIgnore(OWNER, false, nil)
    local Pop = NS.addon.Settings.CalloutPopup
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local w = P.during(function() Pop.Open(gid) end)
    local B = NS.addon.Settings.IconBrowser
    P.find(w, "Button", "Choose icon…"):__fire("OnClick")
    B.Select(GAME)
    assertTrue(B.Choose())
    local icon = P.find(w, "Icon")
    -- red under: preview:SetImage(icon) alone in Ed.IconChooser
    assertEqual(icon.image[1], GAME)
    crop({ icon.image[2], icon.image[3], icon.image[4], icon.image[5] }, "the chooser")
    assertEdged(Skin, icon, "the chooser")
end)
