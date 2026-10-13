-- tests/test_diagnostics.lua — the addon's own sections of the diagnostics report
-- (debug-logging-§14). The contract around them (both forms, append, the run turning logging on,
-- the markers, no alias) is the kit's test_diagnostics_contract.lua, run against this dispatcher.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function report(NS)
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    return table.concat(NS.DebugLog.buffer, "\n")
end

test("diagnostics: the sections are the addon's, in report order", function()
    local NS = T.newAddon()
    local names = {}
    for i, s in ipairs(NS.Diagnostics.Sections()) do names[i] = s[1] end
    assertEqual(table.concat(names, ","),
        "identity,settings,registration,integrations,situation,restrictions,library,surfaces,send")
end)

test("diagnostics: the report names the schema, the profile, the holds and the launcher", function()
    local NS = T.enableAddon()
    local text = report(NS)
    assertTrue(text:find("schema stored=1 code=1", 1, true) ~= nil, "identity")
    assertTrue(text:find("profile=Default", 1, true) ~= nil, text)
    assertTrue(text:find("feature events registered=true", 1, true) ~= nil, "registration")
    assertTrue(text:find("launcher: registered=true", 1, true) ~= nil, "integrations")
end)

test("diagnostics: it runs while stood down and says so, without acting", function()
    local NS = T.enableAddon()
    NS.addon:OnSlashCommand("disable")
    local text = report(NS)
    assertTrue(text:find("stoodDown=true", 1, true) ~= nil)
    assertTrue(text:find("holds disabled", 1, true) ~= nil, text)
    assertTrue(NS.IsStoodDown(), "the report changed nothing")
end)

test("diagnostics: `enabled` is always listed, and a hidden minimap button is listed", function()
    local NS = T.enableAddon()
    NS.SchemaRuntime.Set("global.minimap.shown", false)
    local text = report(NS)
    assertTrue(text:find("enabled", 1, true) ~= nil)
    assertTrue(text:find("global.minimap.shown", 1, true) ~= nil, text)
end)

test("diagnostics: the situation and library sections report the snapshot and the registry", function()
    local NS = T.enableAddon()
    local text = report(NS)
    assertTrue(text:find("lockdown=", 1, true) ~= nil, "situation")
    assertTrue(text:find("callouts=", 1, true) ~= nil and text:find("active=", 1, true) ~= nil, "library")
end)

test("diagnostics: [final 1] the restriction section names the active reasons and canSendChat", function()
    local NS, m = T.enableAddon()
    m.restrictionStates[m.Enum.AddOnRestrictionType.Encounter] = m.Enum.AddOnRestrictionState.Active
    m.chatLockdown = true
    local text = report(NS)
    assertTrue(text:find("active=chatLockdown,encounter reason=encounter canSendChat=false", 1, true) ~= nil, text)
end)

test("diagnostics: the surfaces and send sections name the pads, the armed chips and the guard", function()
    local NS = T.enableAddon()
    NS.Situation.ReadInputs = function()
        return { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
            keyLevel = 12, inGroup = true }
    end
    NS.Situation.RefreshNow("test")
    local text = report(NS)
    assertTrue(text:find("p1 active=bi.mplus stale=false", 1, true) ~= nil, text)
    assertTrue(text:find("buttons=8 armed=8", 1, true) ~= nil, text)
    assertTrue(text:find("p1:bi.mplus.pull /p Pulling next pack", 1, true) ~= nil, text)
    assertTrue(text:find("pending -", 1, true) ~= nil, "no queued keys")
    assertTrue(text:find("window=1", 1, true) ~= nil, "the guard")
    assertTrue(text:find("sent=0 dropped=0", 1, true) ~= nil, "the echo counts")
end)
