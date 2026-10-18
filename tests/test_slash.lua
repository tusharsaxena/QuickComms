-- tests/test_slash.lua — the verb table and the host verbs (slash-commands-§1/§2/§3).

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local NO_LIBKA0S = T.loadAddon.libFiles

local RESERVED = { "help", "config", "enable", "disable", "version", "list", "get", "set", "reset",
    "resetall", "profile", "debug", "diagnostics", "perf" }

local function verbs(NS)
    local out = {}
    for _, entry in ipairs(NS.COMMANDS) do out[entry[1]] = entry end
    return out
end

test("slash: NS.COMMANDS is positional triples, every reserved verb present", function()
    local NS = T.newAddon()
    for _, entry in ipairs(NS.COMMANDS) do
        -- red under: write one entry as { name = ..., desc = ..., fn = ... }
        assertTrue(type(entry[1]) == "string" and type(entry[2]) == "string" and type(entry[3]) == "function",
            "positional triple: " .. tostring(entry[1]))
    end
    local v = verbs(NS)
    for _, name in ipairs(RESERVED) do assertTrue(v[name] ~= nil, "reserved verb " .. name) end
end)

test("slash: `diagnostics` has no alias of any kind (debug-logging-§14)", function()
    local NS = T.newAddon()
    local v = verbs(NS)
    assertTrue(v.diag == nil and v.dump == nil and v.dx == nil)
end)

test("slash: both chat commands are registered through AceConsole, and both dispatch", function()
    local _, _, m = T.bootAddon()
    local AC = m.LibStub("AceConsole-3.0")
    assertTrue(AC.commands.qc ~= nil and AC.commands.quickcomms ~= nil, "qc and quickcomms")
    m.prints = {}
    AC:__slash("quickcomms", "version")
    assertTrue(m.prints[1]:find("0.1.0", 1, true) ~= nil, tostring(m.prints[1]))
end)

test("slash: the bare command opens the settings panel", function()
    local NS = T.enableAddon()
    local opened = 0
    local H = NS.addon.Settings.Helpers
    local real = H.OpenOptionsPanel
    H.OpenOptionsPanel = function() opened = opened + 1 end
    NS.addon:OnSlashCommand("")
    H.OpenOptionsPanel = real
    assertEqual(opened, 1)
end)

test("slash: enable and disable write `enabled` through the seam and move the latch", function()
    local NS = T.enableAddon()
    NS.addon:OnSlashCommand("disable")
    assertEqual(NS.addon.db.profile.enabled, false)
    assertTrue(NS.IsStoodDown())
    NS.addon:OnSlashCommand("enable")
    assertEqual(NS.addon.db.profile.enabled, true)
    assertFalse(NS.IsStoodDown())
end)

test("slash: `perf` is the addon's verb and prints the harness's lines", function()
    local NS, _, m = T.enableAddon()
    m.prints = {}
    NS.addon:OnSlashCommand("perf")
    assertTrue(#m.prints > 0, "the library returned lines and the addon printed them")
end)

test("slash: `reset` with no path explains itself rather than resetting everything", function()
    local NS, _, m = T.enableAddon()
    NS.SchemaRuntime.Set("enabled", false)
    m.prints = {}
    NS.addon:OnSlashCommand("reset")
    assertEqual(NS.addon.db.profile.enabled, false)
    assertTrue(m.prints[1]:find("takes a setting path", 1, true) ~= nil)
end)

test("slash: `debug on` turns logging on without opening the console", function()
    local NS = T.enableAddon()
    NS.addon:OnSlashCommand("debug on")
    assertTrue(NS.State.debug)
    assertFalse(NS.DebugLog:IsShown())
    NS.addon:OnSlashCommand("debug off")
    assertFalse(NS.State.debug)
end)

test("slash: degraded, enable and disable still work and the CLI names the missing library", function()
    local D, _, m = T.enableAddon{ skip = NO_LIBKA0S }
    m.prints = {}
    D.addon:OnSlashCommand("list")
    assertTrue(m.prints[#m.prints]:find("settings CLI is unavailable", 1, true) ~= nil)
    D.addon:OnSlashCommand("disable")
    assertEqual(D.addon.db.profile.enabled, false)
    assertTrue(D.IsStoodDown())
    D.addon:OnSlashCommand("enable")
    assertFalse(D.IsStoodDown())
end)

test("slash: [audit QC-05] degraded, `debug on`/`off` flip the flag and ack, and `debug diagnostics` routes", function()
    local D, _, m = T.enableAddon{ skip = NO_LIBKA0S }
    m.prints = {}
    -- red under: put back the stub's `DebugVerb = function() return false end` in core/DebugLogSetup.lua
    D.addon:OnSlashCommand("debug on")
    assertTrue(D.State.debug == true, "the flag flipped")
    assertTrue(table.concat(m.prints, "\n"):find("debug logging", 1, true) ~= nil, "the ON ack printed")
    D.addon:OnSlashCommand("debug off")
    assertTrue(D.State.debug == false)
    m.prints = {}
    D.addon:OnSlashCommand("debug diagnostics")
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("/qc diagnostics is unavailable", 1, true) ~= nil, m.prints[1])
end)

test("slash: [phase 3] `why` prints each built pad and why its groups show", function()
    local NS, _, m = T.enableAddon()
    NS.Situation.ReadInputs = function()
        return { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true, keyLevel = 12,
            inGroup = true }
    end
    NS.Situation.RefreshNow("test")
    m.prints = {}
    NS.addon:OnSlashCommand("why")
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("Comms Pad (p1):", 1, true) ~= nil, text)
    assertTrue(text:find("  M+ (generic): Content", 1, true) ~= nil, text)
end)
test("slash: [phase 4] `why` covers the dials too", function()
    local NS, _, m = T.enableAddon()
    NS.Situation.ReadInputs = function()
        return { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true, keyLevel = 12,
            inGroup = true }
    end
    NS.Situation.RefreshNow("test")
    m.prints = {}
    NS.addon:OnSlashCommand("why")
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("Comms Pad (p1):", 1, true) ~= nil, text)
    assertTrue(text:find("Comms Dial (d2):", 1, true) ~= nil, text)
end)

test("slash: [final 16] `why` with nothing built speaks of pads and dials", function()
    local NS, _, m = T.enableAddon()
    NS.Surfaces.Plans = function() return {} end
    NS.Surfaces.DialPlans = function() return {} end
    m.prints = {}
    NS.addon:OnSlashCommand("why")
    -- red under: keep the pads-only empty line in settings/SlashVerbs.lua
    assertTrue(table.concat(m.prints, "\n"):find("Nothing is showing: no pad or dial has been built yet.", 1, true) ~= nil)
end)

test("slash: a callout's rows take its id after the path; with none the write is refused and names the form", function()
    local NS, _, m = T.enableAddon()
    local Lib = NS.Library
    local a = Lib.CreateCallout({ name = "Alpha", text = "a", channel = "party" })
    local b = Lib.CreateCallout({ name = "Beta", text = "b", channel = "party", icon = 136012 })
    m.prints = {}
    -- red under: route `set` straight to Sl:CliSet in settings/Slash.lua (the id is read as text)
    NS.addon:OnSlashCommand("set callout.text " .. b .. " Lust now {rt8}")
    assertEqual(NS.db.profile.callouts[b].text, "Lust now {rt8}")
    assertEqual(NS.db.profile.callouts[a].text, "a")
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("Lust now {rt8}", 1, true) ~= nil, "the echo reads the callout it wrote: " .. text)
    m.prints = {}
    NS.addon:OnSlashCommand("get callout.name " .. b)
    text = table.concat(m.prints, "\n")
    assertTrue(text:find("Beta", 1, true) ~= nil, text)
    NS.addon:OnSlashCommand("reset callout.icon " .. b)
    assertTrue(NS.db.profile.callouts[b].icon == false, "reset by id")
    m.prints = {}
    NS.addon:OnSlashCommand("set callout.text")
    text = table.concat(m.prints, "\n")
    assertTrue(text:find("Name the callout id: /qc set callout.<field> <id> <value>.", 1, true) ~= nil, text)
    m.prints = {}
    NS.addon:OnSlashCommand("set callout.text Lust now")   -- no id: "Lust" is not a callout
    assertEqual(NS.db.profile.callouts[a].text, "a")
    assertEqual(NS.db.profile.callouts[b].text, "Lust now {rt8}")
    text = table.concat(m.prints, "\n")
    assertTrue(text:find("No callout with id Lust.", 1, true) ~= nil, text)
    -- The other kinds keep the page's selection: a group row takes no id.
    local gid = Lib.CreateGroup({ name = "Mine" })
    NS.State.editing.group = gid
    NS.addon:OnSlashCommand("set group.name Two words")
    assertEqual(NS.db.profile.groups[gid].name, "Two words")
end)

test("slash: [final 9] test and preview's help, and the Preview as row, speak of the dials too", function()
    local NS, _, m = T.enableAddon()
    m.prints = {}
    NS.addon:OnSlashCommand("help")
    local text = table.concat(m.prints, "\n")
    -- red under: keep the pads-and-chips-only lines in settings/Slash.lua
    assertTrue(text:find("Turn test mode on or off (placeholder chips and wedges; it opens dial 1; combat ends it)", 1, true) ~= nil, text)
    assertTrue(text:find("Preview the pads and dials as another situation", 1, true) ~= nil, text)
    local row = NS.SchemaRuntime.FindRow("state.previewAs")
    do
        assertEqual(row.desc, "Draw every pad, and open dial 1, as it would look in another situation. Nothing on them sends. It ends when the settings close or combat starts.")
    end
end)
