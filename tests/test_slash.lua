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
    assertTrue(text:find("  M+ (generic) (built-in): Content", 1, true) ~= nil, text)
end)
