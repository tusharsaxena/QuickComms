-- tests/test_skin_outline.lua — the Font outline (LibKa0s v1.82.0, Skin minor 9; QC-01 of
-- Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-06): stored as skin.outline
-- ("all", the default, "hud", "off"), written only through the skin write seam (NS.WriteSkinChoice's
-- `media.outline`), and applied with Skin:SetOutline at load, on every profile event and on the row's
-- own write. Modeled on LibKa0sSkinTester's tests/test_skin_outline.lua, the reference adopter.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "QuickComms"

local function lib(mock) return mock.LibStub("LibKa0s-Skin-1.0") end
local function profileSkin(NS) return NS.addon.db.profile.skin end

test("outline: a fresh profile stores All text, the library's default", function()
    local NS, _, mock = T.bootAddon()
    assertEqual(profileSkin(NS).outline, "all")
    assertEqual(profileSkin(NS).outline, lib(mock).OUTLINE_DEFAULT)
    assertEqual(NS.SkinOutline(), "all")
    assertEqual(lib(mock):GetOutline(OWNER), "all")
end)

test("outline: the schema row offers the library's three modes, in its order", function()
    local NS, _, mock = T.bootAddon()
    local row = NS.SchemaRuntime.FindRow("skin.outline")
    assertTrue(row ~= nil, "a skin.outline row")
    assertTrue(row.skipRender == true, "the Skin tab draws it")
    local got = {}
    for _, opt in ipairs(row.values) do got[#got + 1] = opt.value end
    assertEqual(table.concat(got, ","), table.concat(lib(mock).OUTLINE_MODES, ","))
end)

test("outline: the write seam stores media.outline, and leaves it alone when it is nil", function()
    -- red under: WriteSkinChoice dropping media.outline (the Skin tab's Font outline and the copy
    -- would move the look and never store it).
    local NS = T.bootAddon()
    NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false, outline = "hud" })
    assertEqual(profileSkin(NS).outline, "hud")
    NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false })
    assertEqual(profileSkin(NS).outline, "hud", "a media without outline leaves it")
    NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false, outline = "off" })
    assertEqual(profileSkin(NS).outline, "off")
end)

test("outline: another addon's copy reaches the store through WriteChoice", function()
    local NS, _, mock = T.bootAddon()
    lib(mock):WriteChoice(OWNER, "ka0s", "ember", nil, { font = false, texture = false, outline = "off" })
    assertEqual(profileSkin(NS).outline, "off")
end)

test("outline: the row's write applies the mode live", function()
    local NS, _, mock = T.bootAddon()
    NS.SchemaRuntime.Set("skin.outline", "hud")
    assertEqual(lib(mock):GetOutline(OWNER), "hud")
    assertEqual(NS.Skin.Token("font.outline"), "", "window text loses its outline")
    assertEqual(NS.Skin.Token("hud.outline"), "OUTLINE", "the HUD keeps it")
    NS.SchemaRuntime.Set("skin.outline", "off")
    assertEqual(NS.Skin.Token("hud.outline"), "", "Off takes both")
    NS.SchemaRuntime.Set("skin.outline", "all")
    assertEqual(NS.Skin.Token("font.outline"), "OUTLINE")
end)

test("outline: /qc set refuses a mode the library does not know", function()
    local NS = T.bootAddon()
    NS.addon:OnSlashCommand("set skin.outline thick")
    assertEqual(profileSkin(NS).outline, "all")
end)

test("outline: the stored mode is applied at load", function()
    -- red under: ApplySkinChoice's whole-pair path not applying the stored outline.
    local first = T.bootAddon()
    first.SchemaRuntime.Set("skin.outline", "off")
    local sv = _G.QuickCommsDB
    local _, _, mock = T.bootAddon{ sv = sv }
    assertEqual(lib(mock):GetOutline(OWNER), "off")
end)

test("outline: a profile switch applies the incoming profile's mode, and back", function()
    local NS, _, mock = T.bootAddon()
    NS.SchemaRuntime.Set("skin.outline", "hud")
    NS.addon.db:SetProfile("Alt")
    assertEqual(lib(mock):GetOutline(OWNER), "all", "Alt keeps the default")
    NS.addon.db:SetProfile("Default")
    assertEqual(lib(mock):GetOutline(OWNER), "hud", "Default's is back")
end)

test("outline: without the skin engine the apply is a quiet no-op", function()
    local NS = T.bootAddon{ skip = { "libs/LibKa0s/Skin.lua" } }
    assertEqual(NS.ApplySkinOutline(), false)
    NS.SchemaRuntime.Set("skin.outline", "off")
    assertEqual(profileSkin(NS).outline, "off", "the store still takes the write")
end)
