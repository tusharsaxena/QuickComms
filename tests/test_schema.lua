-- tests/test_schema.lua — the one write seam, its reactions, and the resets (architecture-§5,
-- options-ui-§1/§12, launcher-§3).

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local NO_LIBKA0S = T.loadAddon.libFiles

test("schema: every row validates against the defaults", function()
    local NS = T.bootAddon()
    assertEqual(NS.addon.Settings.Helpers.ValidateSchema(), 0)
end)

test("schema: a stored row whose path has no default is counted, not passed vacuously", function()
    local NS = T.bootAddon()
    local rows = NS.addon.Settings.Schema
    rows[#rows + 1] = { path = "nope.noDefault", type = "bool", label = "No default", group = "x" }
    local count = NS.addon.Settings.Helpers.ValidateSchema()
    rows[#rows] = nil
    assertTrue(count > 0, "the unresolved path is reported")
end)

test("schema: the Minimap button row's backing key resolves against the global defaults", function()
    local NS = T.bootAddon()
    local mm = NS.C.GLOBAL_DEFAULTS.minimap
    local saved = mm.hide
    mm.hide = nil
    local count = NS.addon.Settings.Helpers.ValidateSchema()
    mm.hide = saved
    assertEqual(count, 1)
end)

test("schema: the Master controls rows are the framed canonical set, in the canonical order", function()
    local NS = T.newAddon()
    local paths = {}
    for i, row in ipairs(NS.addon.Settings.Schema) do paths[i] = row.path end
    -- red under: put `frameless = true` back in settings/Panel.lua (the pad has a frame to lock)
    -- The Master controls block leads; the Behavior rows (settings/SchemaRows.lua) follow it.
    assertEqual(table.concat(paths, ",", 1, 8),
        "enabled,visibility,scale,alpha,locked,state.debugConsole,global.minimap.shown,state.testMode")
    assertEqual(paths[9], "behavior.soloFallback")
end)

test("schema: NS.Setting reads through the seam, and answers the default before the db exists", function()
    local NS = T.newAddon()
    assertEqual(NS.Setting("enabled"), true, "the row's default, no db yet")
    NS.addon:OnInitialize()
    NS.SchemaRuntime.Set("enabled", false)
    assertEqual(NS.Setting("enabled"), false)
end)

test("schema: a page's rows are the rows whose page is its key", function()
    local NS = T.newAddon()
    local Settings = NS.addon.Settings
    assertEqual(#Settings.RowsForPage("general"), #Settings.Schema)
    assertEqual(#Settings.RowsForPage("nope"), 0)
end)

test("schema: an unknown path is refused and stores nothing", function()
    local NS = T.bootAddon()
    local ok = NS.SchemaRuntime.Set("nope.never", 1)
    assertFalse(ok)
    assertTrue(NS.addon.db.profile.nope == nil)
end)

test("schema: the Minimap button row inverts onto LibDBIcon's own hide, with no shown key", function()
    local NS, _, m = T.enableAddon()
    NS.SchemaRuntime.Set("global.minimap.shown", false)
    assertEqual(NS.addon.db.global.minimap.hide, true)
    assertTrue(NS.addon.db.global.minimap.shown == nil, "no shown twin")
    assertFalse(m.minimapButtons.QuickComms.shown, "LibDBIcon hid the button")
    assertEqual(NS.SchemaRuntime.Get("global.minimap.shown"), false)
end)

test("schema: neither reset touches the minimap button (launcher-§3)", function()
    local NS = T.enableAddon()
    NS.SchemaRuntime.Set("global.minimap.shown", false)
    NS.SchemaRuntime.Set("enabled", false)
    -- red under: drop resetExempt from settings/Schema.lua and route reset all through ApplyDefault
    NS.addon.Settings.Helpers.RestoreAllDefaults()
    assertEqual(NS.addon.db.global.minimap.hide, true, "Reset all settings left it hidden")
    assertEqual(NS.addon.db.profile.enabled, true, "and did reset the profile")
    assertFalse(NS.IsStoodDown(), "the reset profile's `enabled` reached the latch")
end)

test("schema: Reset all asks first, through the confirmation popup", function()
    local NS, _, m = T.enableAddon()
    NS.addon:OnSlashCommand("resetall")
    assertEqual(m.popupsShown[#m.popupsShown][1], "QUICKCOMMS_RESET_ALL")
    local popup = m.StaticPopupDialogs.QUICKCOMMS_RESET_ALL or _G.StaticPopupDialogs.QUICKCOMMS_RESET_ALL
    assertTrue(popup ~= nil)
    -- red under: a popup without preferredIndex: slot 3, clear of Blizzard's own
    assertEqual(popup.preferredIndex, 3)
end)

test("schema: degraded, `enabled` is written through and still reacts", function()
    local D = T.enableAddon{ skip = NO_LIBKA0S }
    -- red under: drop `writeThrough` from settings/Schema.lua (the composed rows do not exist here)
    assertTrue(D.SchemaRuntime.Set("enabled", false))
    assertEqual(D.addon.db.profile.enabled, false)
    assertTrue(D.IsStoodDown(), "the reaction ran from announce")
    assertTrue(D.SchemaRuntime.Set("enabled", true))
    assertFalse(D.IsStoodDown())
end)

test("schema: degraded, a row-less path not in the list is still refused", function()
    local D = T.bootAddon{ skip = NO_LIBKA0S }
    assertFalse(D.SchemaRuntime.Set("locked", false))
    assertEqual(D.addon.db.profile.locked, true, "nothing stored: the default stands")
end)
