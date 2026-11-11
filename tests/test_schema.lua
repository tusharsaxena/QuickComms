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
    -- red under: leave it in Blizzard's DIALOG, under an open callout popup's FULLSCREEN catcher
    -- (QC-06: `/qc resetall` typed while the popup is open) and in a level race with the dial
    local d = { strata = "DIALOG", SetFrameStrata = function(self, v) self.strata = v end,
        GetFrameStrata = function(self) return self.strata end }
    popup.OnShow(d)
    assertEqual(d.strata, "FULLSCREEN_DIALOG")
    popup.OnHide(d)
    assertEqual(d.strata, "DIALOG")
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

-- ── item 020's guard (QC-LY): the layout moves rows, never settings ─────────────────────────────

local function pinValue(v)
    local t = type(v)
    if t == "table" then
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local parts = {}
        for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. pinValue(v[k]) end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif t == "number" then return ("%.6g"):format(v)
    elseif t == "string" then return ("%q"):format(v)
    end
    return tostring(v)
end

local function pinLine(row)
    local d = row.default
    if type(d) == "function" then d = "<fn>" end
    local vals = "nil"
    if type(row.values) == "table" then
        local vs = {}
        for i, e in ipairs(row.values) do vs[i] = pinValue(type(e) == "table" and e.value or e) end
        vals = "[" .. table.concat(vs, ",") .. "]"
    elseif type(row.values) == "function" then
        vals = "<fn>"
    end
    return table.concat({ tostring(row.type), pinValue(d), pinValue(row.min), pinValue(row.max), pinValue(row.step),
        vals, tostring(row.sessionOnly == true) }, "|")
end

test("schema: [layout guard] every stored path, default, range and choice set is as item 020 found it", function()
    -- The client's own default skin (tests/schema_pins.lua pins skin.skin per kit profile).
    local NS = T.newAddon({ clientSkin = true })
    local pins = dofile("tests/schema_pins.lua")
    local seen, count = {}, 0
    for _, row in ipairs(NS.addon.Settings.Schema) do
        -- red under: change any row's default, min, max, step or choices, or rename its path
        assertTrue(pins[row.path] ~= nil, "a row item 020 did not find: " .. row.path)
        assertEqual(pinLine(row), pins[row.path], row.path)
        assertFalse(seen[row.path] == true, "one row per path: " .. row.path)
        seen[row.path], count = true, count + 1
    end
    local want = 0
    for path in pairs(pins) do
        want = want + 1
        assertTrue(seen[path] == true, "a row item 020 lost: " .. path)
    end
    assertEqual(count, want, "the set of settings is unchanged")
end)

-- ── the ping and marker member rows (CA-M1-5, spec §2) ────────────────────────────────────────

-- A user callout whose only action is `fields`' (no Line), for a case about the action rows.
local function actionOnly(NS, fields)
    fields.name, fields.text, fields.channel = fields.name or "Act", "", "gameEmote"
    return NS.Library.CreateCallout(fields)
end

test("schema: [CA-M1-5] callout.ping is a string row, none by default, with none and the four types", function()
    local NS = T.bootAddon()
    local row = NS.SchemaRuntime.FindRow("callout.ping")
    -- red under: no callout.ping row in settings/SchemaMembers.lua
    assertTrue(row ~= nil, "the row")
    assertEqual(row.type, "string")
    assertTrue(row.default == false, "none by default")
    assertEqual(row.instance, "callout")
    local vals = {}
    for i, v in ipairs(row.values) do vals[i] = tostring(v.value) .. "=" .. v.text end
    assertEqual(table.concat(vals, ","), "none=None,attack=Attack,warning=Warning,onmyway=On my way,assist=Assist")
    assertTrue(type(row.normalize) == "function" and type(row.validate) == "function")
    assertTrue(row.normalize("") == false and row.normalize("none") == false and row.normalize("None") == false)
    assertEqual(row.normalize("attack"), "attack")
    assertFalse((row.validate("threat")), "a type /ping does not take")
end)

test("schema: [CA-M1-5] callout.marker is a number row, none by default, with none and 1 to 8 drawn as their icons", function()
    local NS = T.bootAddon()
    local row = NS.SchemaRuntime.FindRow("callout.marker")
    -- red under: no callout.marker row in settings/SchemaMembers.lua
    assertTrue(row ~= nil, "the row")
    assertEqual(row.type, "number")
    assertTrue(row.default == false, "none by default")
    assertEqual(#row.values, 9)
    assertEqual(row.values[1].value, 0)
    assertEqual(row.values[1].text, "None")
    for n = 1, 8 do
        assertEqual(row.values[n + 1].value, n)
        assertEqual(row.values[n + 1].text, "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. n .. ":0|t")
    end
    assertTrue(row.normalize(0) == false, "0 is none")
    assertEqual(row.normalize(8), 8)
    assertFalse((row.validate(9)))
    assertFalse((row.validate(1.5)))
end)

test("schema: [CA-M1-5] the seam sets and clears a ping and a marker, and neither row is reset-exempt", function()
    local NS = T.bootAddon()
    local S, p = NS.SchemaRuntime, NS.db.profile
    local cid = actionOnly(NS, { ping = "attack" })
    assertTrue((S.Set("callout.ping", "warning", cid)))
    assertEqual(p.callouts[cid].ping, "warning")
    local ok, _, why = S.Set("callout.ping", "threat", cid)
    assertFalse(ok)
    assertEqual(why, "A ping is attack, warning, onmyway or assist, or none.")
    assertFalse((S.Set("callout.ping", "none", cid)), "the ping is its only action (CA-M1-3)")
    local mid = actionOnly(NS, { marker = 8 })
    assertTrue((S.Set("callout.marker", 3, mid)))
    assertEqual(p.callouts[mid].marker, 3)
    ok, _, why = S.Set("callout.marker", 9, mid)
    assertFalse(ok)
    assertEqual(why, "A marker is a number from 1 (star) to 8 (skull), or 0 for none.")
    -- a Line beside it: then none clears the ping (the Line keeps the callout's action)
    local line = NS.Library.CreateCallout({ name = "Line", text = "Kick", channel = "party" })
    assertTrue((S.Set("callout.ping", "none", line)))
    assertTrue(p.callouts[line].ping == false)
    assertTrue((S.Set("callout.marker", 0, line)))
    assertTrue(p.callouts[line].marker == false)
    -- the CLI
    NS.addon:OnSlashCommand("set callout.marker " .. line .. " 8")
    assertEqual(p.callouts[line].marker, 8, "a marker beside the Line (CA-M2-1: actions combine)")
    local blank = actionOnly(NS, { emote = "POINT" })
    p.callouts[blank].emote = false
    NS.addon:OnSlashCommand("set callout.marker " .. blank .. " 8")
    assertEqual(p.callouts[blank].marker, 8, "/qc set callout.marker <id> 8")
    p.callouts[blank].marker = false
    NS.addon:OnSlashCommand("set callout.ping " .. blank .. " attack")
    assertEqual(p.callouts[blank].ping, "attack", "/qc set callout.ping <id> attack")
    -- D11: an action field is no more reset-exempt than the emote is: a sweep resets it
    p.callouts[line].ping = "assist"
    S.BulkBegin()
    local swept = S.ApplyDefault(S.FindRow("callout.ping"), line)
    S.BulkEnd()
    assertTrue(swept, "a sweep reaches callout.ping")
    assertTrue(p.callouts[line].ping == false)
    p.callouts[line].marker = 5
    S.BulkBegin()
    swept = S.ApplyDefault(S.FindRow("callout.marker"), line)
    S.BulkEnd()
    assertTrue(swept, "a sweep reaches callout.marker")
    assertTrue(p.callouts[line].marker == false)
end)

test("schema: [CA-M1-5] callout.emote is reworded: an emote is one of a callout's actions", function()
    local NS = T.bootAddon()
    local row = NS.SchemaRuntime.FindRow("callout.emote")
    assertEqual(row.label, "Game emote")
    -- red under: the old desc ("a Game emote callout performs")
    assertEqual(row.desc, "The game emote this callout performs, by its token (POINT) or command (/point), after its chat line if it has one. It acts on your target, as the game's own emote does.")
end)

-- ── the auto-thank rows (CA-M4-13, spec §9 Settings page, §10) ────────────────────────────────

-- Every thank.* row, by path.
local function thankRows(NS)
    local out = {}
    for _, row in ipairs(NS.addon.Settings.Schema) do
        if row.path:find("^thank%.") then out[row.path] = row end
    end
    return out
end

test("schema: [CA-M4-13] every thank.* row's default is NS.C.PROFILE.thank's, on the Auto-thank page", function()
    local NS = T.bootAddon()
    local D = NS.C.PROFILE.thank
    local rows = thankRows(NS)
    -- red under: no settings/AutoThank.lua rows
    for _, leaf in ipairs({ "enabled", "send", "text", "mute", "raidBuffsOnly", "position" }) do
        local row = rows["thank." .. leaf]
        assertTrue(row ~= nil, "a row for thank." .. leaf)
        assertEqual(row.default, D[leaf], "thank." .. leaf)
    end
    -- every kind on every client: the page, not the schema, leaves out the ones a client lacks
    for _, kind in ipairs(NS.Resolver.TOKENS.content) do
        local row = rows["thank.content." .. kind]
        assertTrue(row ~= nil, "a row for thank.content." .. kind)
        assertEqual(row.default, D.content[kind], kind)
        assertEqual(row.label, NS.PadRender.CONTENT[kind], kind)
    end
    for path, row in pairs(rows) do assertEqual(row.page, "autothank", path) end
    assertEqual(NS.addon.Settings.Helpers.ValidateSchema(), 0)
end)

test("schema: [CA-M4-13] /qc set thank.send line works, and a send kind it does not know is refused", function()
    local NS = T.bootAddon()
    local p = NS.db.profile
    NS.addon:OnSlashCommand("set thank.send line")
    -- red under: no thank.send row
    assertEqual(p.thank.send, "line")
    assertFalse((NS.SchemaRuntime.Set("thank.send", "shout")))
    assertEqual(p.thank.send, "line")
    assertFalse((NS.SchemaRuntime.Set("thank.mute", "everyone")))
    assertTrue((NS.SchemaRuntime.Set("thank.mute", "known")))
    assertEqual(p.thank.mute, "known")
    assertTrue((NS.SchemaRuntime.Set("thank.text", "Ty {name}")))
    assertEqual(p.thank.text, "Ty {name}")
    assertTrue((NS.SchemaRuntime.Set("thank.content.dungeon", true)))
    assertTrue(p.thank.content.dungeon == true)
    assertTrue(p.thank.content.openWorld == true, "a sibling kind is kept")
end)

test("schema: [CA-M4-13] the toast's position is reset-exempt: a page's Defaults keeps it, a named reset clears it", function()
    local NS = T.bootAddon()
    local S, p = NS.SchemaRuntime, NS.db.profile
    p.thank.position = { "TOP", "TOP", 10, -200 }
    S.BulkBegin()
    local swept = S.ApplyDefault(S.FindRow("thank.position"))
    S.BulkEnd()
    -- red under: no thank.position in settings/Schema.lua resetExempt
    assertFalse(swept, "a sweep keeps it")
    assertEqual(p.thank.position[3], 10)
    p.thank.send = "both"
    S.BulkBegin()
    S.ApplyDefault(S.FindRow("thank.send"))
    S.BulkEnd()
    assertEqual(p.thank.send, "emote", "the sweep resets the rest")
    NS.addon:OnSlashCommand("reset thank.position")
    assertTrue(p.thank.position == false, "a named reset reaches it")
end)

test("schema: [CA-M4-13] every thank.* write re-runs AT.Rewire, the only wire", function()
    local NS = T.bootAddon()
    local calls = 0
    local real = NS.AutoThank.Rewire
    NS.AutoThank.Rewire = function() calls = calls + 1 end
    local S = NS.SchemaRuntime
    S.Set("thank.enabled", false)
    -- red under: a thank.* row with no onChange
    assertEqual(calls, 1, "thank.enabled")
    S.Set("thank.content.dungeon", true)
    assertEqual(calls, 2, "a content kind")
    S.Set("thank.send", "both")
    S.Set("thank.mute", "strangers")
    S.Set("thank.raidBuffsOnly", true)
    S.Set("thank.text", "Thanks!")
    assertEqual(calls, 6, "the rest")
    NS.AutoThank.Rewire = real
end)

test("schema: [CA-M4-13] switching auto-thank off through the seam takes the frame's UNIT_AURA down", function()
    local NS = T.enableAddon()
    NS.Situation.ReadInputs = function() return {} end
    NS.Situation.RefreshNow("test")
    local units = function()
        local u = NS.AutoThank.frame.__unitEvents.UNIT_AURA
        return u and table.concat(u, ",") or ""
    end
    assertEqual(units(), "player")
    NS.addon:OnSlashCommand("set thank.enabled false")
    assertEqual(units(), "", "off")
    NS.addon:OnSlashCommand("set thank.content.openWorld false")
    NS.addon:OnSlashCommand("set thank.enabled true")
    assertEqual(units(), "", "on, but not in the open world")
    NS.addon:OnSlashCommand("set thank.content.openWorld true")
    assertEqual(units(), "player")
end)
