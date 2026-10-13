-- tests/test_profile.lua — defaults/Profile.lua and the Behavior rows (spec §5.1).

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

test("profile: behavior defaults match spec §5.1", function()
    local NS = T.bootAddon()
    local b = NS.db.profile.behavior
    assertEqual(b.soloFallback, "none")
    assertEqual(b.spamGuard, 1.0)
    assertEqual(b.dropNotes, true)
    assertEqual(b.whyTooltips, true)
    assertEqual(b.lockdownChip, true)
    assertEqual(b.sounds, false)
    assertEqual(b.autoPromote, false)
end)

test("profile: collections exist; default nextId is 1, 3 after boot", function()
    local NS0 = T.newAddon()
    assertEqual(NS0.C.PROFILE.nextId, 1)
    local NS = T.bootAddon()
    local p = NS.db.profile
    assertEqual(p.nextId, 3)
    for _, key in ipairs({ "callouts", "groups", "builtins", "pads", "dials", "padOrder", "dialOrder" }) do
        assertEqual(type(p[key]), "table", key)
    end
end)

test("profile: every behavior row resolves through the seam", function()
    local NS = T.bootAddon()
    assertEqual(NS.Setting("behavior.spamGuard"), 1.0)
    NS.SchemaRuntime.Set("behavior.spamGuard", 1.5)
    assertEqual(NS.Setting("behavior.spamGuard"), 1.5)
    NS.SchemaRuntime.Set("behavior.soloFallback", "say")
    assertEqual(NS.Setting("behavior.soloFallback"), "say")
end)

test("profile: the spam guard clamps to 0.6-2.0 and fallback refuses unknown values", function()
    local NS = T.bootAddon()
    NS.SchemaRuntime.Set("behavior.spamGuard", 9)
    assertTrue(NS.Setting("behavior.spamGuard") <= 2.0, "clamped high")
    NS.SchemaRuntime.Set("behavior.soloFallback", "guild")
    assertEqual(NS.Setting("behavior.soloFallback"), "none")
end)

test("profile: schema version target is 1", function()
    local NS = T.bootAddon()
    assertEqual(NS.SCHEMA_VERSION, 1)
    assertEqual(NS.db.global.schemaVersion, 1)
end)
