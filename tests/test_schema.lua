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
    -- Preview as is the composer's one extra (options-ui-§15 as amended in v2.84.0): after the
    -- canonical set, before the Behavior rows.
    -- red under: leave state.previewAs in settings/SchemaRows.lua on the Groups page
    assertEqual(paths[9], "state.previewAs")
    assertEqual(paths[10], "behavior.soloFallback")
end)

test("schema: Preview as sits in Master controls on the General page, after Test mode, on a line of its own", function()
    local NS = T.newAddon()
    local Settings = NS.addon.Settings
    local master = {}
    for _, row in ipairs(Settings.RowsForPage("general")) do
        if row.group == Settings.Helpers.MASTER_GROUP then master[#master + 1] = row end
    end
    assertEqual(master[#master - 1].path, "state.testMode")
    local row = master[#master]
    assertEqual(row.path, "state.previewAs")
    assertTrue(row.sessionOnly == true, "never saved")
    assertTrue(row.startsLine == true, "the Minimap button / Test mode line is full")
    assertEqual(row.default, "off")
    for _, r in ipairs(Settings.RowsForPage("groups")) do
        assertTrue(r.path ~= "state.previewAs", "no longer a Groups page row")
    end
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
    local general = Settings.RowsForPage("general")
    assertTrue(#general > 0)
    for _, row in ipairs(general) do assertEqual(row.page, "general") end
    assertTrue(#Settings.RowsForPage("callouts") > 0, "the member rows draw on their own pages")
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

test("schema: [audit QC-04] the global reset takes every created member back to a fresh profile, and only this one", function()
    local NS = T.enableAddon()
    local Lib, db = NS.Library, NS.addon.db
    local fresh = {}
    for _, kind in ipairs({ "callouts", "groups", "pads", "dials" }) do
        local n = 0
        for _ in pairs(db.profile[kind]) do n = n + 1 end
        fresh[kind] = n
    end
    local c1 = Lib.CreateCallout({ name = "One", text = "one", channel = "party" })
    local c2 = Lib.CreateCallout({ name = "Two", text = "two", channel = "party" })
    assertTrue(Lib.CreateGroup({ name = "Mine", callouts = { c1, c2 } }) ~= nil)
    assertTrue(Lib.CreateSurface("pad", "Extra") ~= nil)
    local current = db:GetCurrentProfile()
    db:SetProfile("Second")
    db:SetProfile(current)
    local profiles = table.concat(db:GetProfiles(), ",")
    NS.SchemaRuntime.Set("state.testMode", true)
    local target = NS.Bus:NewTarget()
    local heard = 0
    target:RegisterMessage(NS.MSG.PROFILE_CHANGED, function() heard = heard + 1 end)
    -- red under: route RestoreAllDefaults back through the row-by-row walk (no db:ResetProfile())
    NS.addon.Settings.Helpers.RestoreAllDefaults()
    for kind, n in pairs(fresh) do
        local now = 0
        for _ in pairs(db.profile[kind]) do now = now + 1 end
        assertEqual(now, n, kind .. " back to a fresh profile's")
    end
    assertEqual(table.concat(db:GetProfiles(), ","), profiles, "the profile list is untouched")
    assertEqual(db:GetCurrentProfile(), current, "the active profile is still active")
    assertFalse(NS.State.testMode == true, "the session rows are swept")
    assertEqual(heard, 1, "PROFILE_CHANGED published once")
end)

test("schema: [audit QC-01] the reset confirmation is options-ui-§12's sentence, verbatim", function()
    local NS, _, m = T.enableAddon()
    NS.addon:OnSlashCommand("resetall")
    local popup = m.StaticPopupDialogs.QUICKCOMMS_RESET_ALL or _G.StaticPopupDialogs.QUICKCOMMS_RESET_ALL
    -- red under: drop "or added" from the key in locales/enUS.lua and settings/Schema.lua
    assertEqual(popup.text, "Reset this profile to the addon's defaults? Everything you have configured or added"
        .. " in it is discarded \226\128\148 your other profiles are not affected.")
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
    assertFalse(D.SchemaRuntime.Set("locked", true))
    assertEqual(D.addon.db.profile.locked, false, "nothing stored: the default stands")
end)

test("schema: [fix wave] the Behavior rows that rebuild the pads resolve Settings.RebuildSurfaces when they run", function()
    local NS = T.enableAddon()
    local heard = {}
    NS.addon.Settings.RebuildSurfaces = function() heard[#heard + 1] = true end
    -- red under: capture Settings.RebuildSurfaces in a file-scope upvalue in settings/SchemaRows.lua
    NS.SchemaRuntime.Set("behavior.soloFallback", "say")
    NS.SchemaRuntime.Set("behavior.lockdownChip", false)
    NS.SchemaRuntime.Set("behavior.autoPromote", true)
    assertEqual(#heard, 3)
end)

test("schema: [audit QC-13] the panel's color codec is written out for the stored { r, g, b, a } shape", function()
    local NS = T.newAddon()
    local codec = NS.addon.Settings.ColorCodec
    -- red under: drop colorDecode / colorEncode from the descriptor in settings/OptionsSetup.lua
    assertTrue(codec ~= nil, "published beside the descriptor that takes it")
    local r, g, b, a = codec.decode({ r = 0.1, g = 0.2, b = 0.3 })
    assertEqual(r, 0.1); assertEqual(g, 0.2); assertEqual(b, 0.3); assertEqual(a, 1)
    r, g, b, a = codec.decode(nil)
    assertEqual(r + g + b + a, 4, "a missing color reads as opaque white")
    local c = codec.encode(0.4, 0.5, 0.6)
    assertEqual(c.r, 0.4); assertEqual(c.g, 0.5); assertEqual(c.b, 0.6); assertEqual(c.a, 1)
end)

test("schema: a callout write that names no id is refused, even with callouts present", function()
    local NS = T.bootAddon()
    local S, Lib = NS.SchemaRuntime, NS.Library
    local a = Lib.CreateCallout({ name = "Alpha", text = "a", channel = "party" })
    local b = Lib.CreateCallout({ name = "Beta", text = "b", channel = "party" })
    NS.State.editing.callout = b   -- a selection left in session state is not read either
    -- red under: put the Library.MemberIds fallback, or the NS.State.editing read, back in
    -- Settings.EditingId for callouts (settings/Schema.lua)
    assertEqual(NS.addon.Settings.EditingId("callout"), nil)
    local ok, err = S.Set("callout.text", "lands nowhere")
    assertFalse(ok)
    assertEqual(err, "Name the callout id: /qc set callout.<field> <id> <value>.")
    assertEqual(NS.db.profile.callouts[a].text, "a")
    assertEqual(NS.db.profile.callouts[b].text, "b")
    assertEqual(S.Get("callout.text"), nil, "a read with no id addresses nothing")
    -- By id it still lands, and a gone id is named.
    assertTrue(S.Set("callout.text", "by id", b))
    assertEqual(NS.db.profile.callouts[b].text, "by id")
    ok, err = S.Set("callout.text", "x", "c999")
    assertFalse(ok)
    assertEqual(err, "No callout with id c999.")
end)

test("schema: [phase 3] a fresh profile has no row off its default; the member rows are not counted", function()
    local NS = T.bootAddon()
    local Settings = NS.addon.Settings
    -- red under: drop `and not row.instance` from Settings.CountedByProfileReset (the member rows count)
    assertEqual(NS.SchemaRuntime.CountOffDefault(Settings.CountedByProfileReset), 0)
end)
