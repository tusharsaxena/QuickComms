-- tests/test_database.lua — the defaults tree and the migration runner (savedvariables-§1).

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

test("database: the defaults stamp schemaVersion 0, and the runner moves it to the code's target", function()
    local NS = T.newAddon()
    local defaults = NS.addon.Settings.BuildDefaults()
    -- red under: default schemaVersion to NS.SCHEMA_VERSION (AceDB would strip it at logout)
    assertEqual(defaults.global.schemaVersion, 0)
    NS.addon:OnInitialize()
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
end)

test("database: the target is the last step's `to`, and the steps climb in order", function()
    local NS = T.newAddon()
    assertEqual(NS.SCHEMA_VERSION, NS.MIGRATIONS[#NS.MIGRATIONS].to)
    local last = 0
    for i, step in ipairs(NS.MIGRATIONS) do
        assertTrue(type(step.run) == "function", "step " .. i .. " runs")
        assertTrue(step.to > last, "step " .. i .. " climbs")
        last = step.to
    end
end)

test("database: the runner is idempotent, and a stored stamp at the target runs no step", function()
    local NS = T.bootAddon()
    local ran = 0
    local step = NS.MIGRATIONS[1]
    local real = step.run
    step.run = function(...) ran = ran + 1; return real(...) end
    NS.addon:RunMigrations()
    NS.addon:RunMigrations()
    step.run = real
    assertEqual(ran, 0)
end)

test("database: a step that raises leaves the stamp where it was", function()
    local NS = T.newAddon()
    local step = NS.MIGRATIONS[1]
    local real = step.run
    step.run = function() error("boom") end
    -- red under: stamp the version before running the step
    T.assertError(function() NS.addon:OnInitialize() end, "the step's error propagates")
    step.run = real
    assertEqual(NS.addon.db.global.schemaVersion, 0)
end)

test("database: a perProfile step runs once for every stored profile", function()
    local NS = T.bootAddon()
    NS.addon.db:SetProfile("Second")
    NS.addon.db.global.schemaVersion = 1
    local seen = {}
    NS.MIGRATIONS[#NS.MIGRATIONS + 1] = { to = 2, perProfile = true,
        run = function(_, profile) seen[#seen + 1] = profile end }
    NS.addon:RunMigrations()
    NS.MIGRATIONS[#NS.MIGRATIONS] = nil
    assertEqual(#seen, 2, "Default and Second")
    assertEqual(NS.addon.db.global.schemaVersion, 2)
end)

test("database: the profile defaults carry the Master controls value, and no debug flag", function()
    local NS = T.bootAddon()
    local p = NS.addon.db.profile
    assertEqual(p.enabled, true)
    -- The debug flag is session-only (debug-logging-§5).
    assertTrue(p.debug == nil and p.state == nil)
    assertEqual(NS.addon.db.global.minimap.hide, false)
end)
