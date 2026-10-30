-- tests/test_profile.lua — defaults/Profile.lua and the Behavior rows (spec §5.1), and the one-owner
-- rule Library.Prepare carries on every profile load.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

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

test("profile: collections exist; default nextId is 1, past every seeded id after boot", function()
    local NS0 = T.newAddon()
    assertEqual(NS0.C.PROFILE.nextId, 1)
    local NS = T.bootAddon()
    local p = NS.db.profile
    -- p1 and d2, then one id per seeded callout and group
    local n = 2
    for _ in pairs(NS.BuiltIns.groups) do n = n + 1 end
    for _ in pairs(NS.BuiltIns.callouts) do n = n + 1 end
    assertEqual(p.nextId, n + 1)
    assertNil(p.builtins, "the built-in overlay is gone")
    for _, key in ipairs({ "callouts", "groups", "seededSets", "pads", "dials", "padOrder", "dialOrder" }) do
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

test("profile: schema version target is 11 (the Font flags' move to From skin)", function()
    local NS = T.bootAddon()
    -- red under: no step 11 in core/Database.lua (LibKa0s v1.82.0, D-07: a stored OUTLINE moves to
    -- From skin once); step 10 is QC-03's reset onto the skin (O2)
    assertEqual(NS.SCHEMA_VERSION, 11)
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
end)

-- ── Prepare keeps one owner per callout (2026-10-17-callouts-owned-by-groups-design.md) ────

-- A booted profile where c1 sits in g1 and g2 (a shared callout, as earlier builds stored one) and
-- c999 sits in no group (seeded ids are low numbers, so these never collide).
local function broken()
    local NS = T.bootAddon()
    local p = NS.db.profile
    p.callouts.c1 = { name = "Kick", text = "Kick {rt8}", channel = "party", icon = 136012 }
    p.callouts.c999 = { name = "Loose", text = "x", channel = "say" }
    p.groups.g1 = { name = "One", callouts = { "c1" }, when = {} }
    p.groups.g2 = { name = "Two", callouts = { "c1" }, when = {} }
    return NS, p
end

-- Every user callout and group list, and the id counter, as one line.
local function shape(p)
    local out = {}
    for _, key in ipairs({ "callouts", "groups" }) do
        local ids = {}
        for id in pairs(p[key]) do ids[#ids + 1] = id end
        table.sort(ids)
        for _, id in ipairs(ids) do
            local v = p[key][id]
            out[#out + 1] = id .. "=" .. (key == "groups" and table.concat(v.callouts, ",") or (v.name .. "/" .. v.text))
        end
    end
    return table.concat(out, ";") .. ";next=" .. tostring(p.nextId)
end

test("prepare: a callout held by two groups is split into a copy", function()
    local NS, p = broken()
    local result = NS.Library.Prepare()
    local a, b = p.groups.g1.callouts[1], p.groups.g2.callouts[1]
    assertEqual(a, "c1", "the first group by id keeps the original")
    -- red under: drop the split from Lib.Prepare
    assertTrue(b ~= nil and b ~= "c1", "the second holds a fresh copy")
    local c = p.callouts[b]
    assertEqual(c.name .. "|" .. c.text .. "|" .. c.channel .. "|" .. c.icon, "Kick|Kick {rt8}|party|136012")
    assertTrue(result.repaired >= 1)
end)

test("prepare: a split copy of a seeded callout keeps no origin", function()
    local NS, p = broken()
    p.callouts.c1.origin = "bi.mplus.lust"
    NS.Library.Prepare()
    local b = p.groups.g2.callouts[1]
    assertEqual(p.callouts.c1.origin, "bi.mplus.lust", "the original keeps it")
    -- red under: splitShared copying the callout with its origin
    assertTrue(b ~= "c1" and p.callouts[b] ~= nil)
    assertNil(p.callouts[b].origin)
end)

test("prepare: a callout held by no group is dropped", function()
    local NS = T.bootAddon()
    local p = NS.db.profile
    p.callouts.c999 = { name = "Loose", text = "x", channel = "say" }
    local result = NS.Library.Prepare()
    -- red under: drop the orphan pass from Lib.Prepare
    assertNil(p.callouts.c999)
    assertEqual(result.repaired, 1, "the repaired tally counts it")
end)

test("prepare: is idempotent after a split", function()
    local NS, p = broken()
    NS.Library.Prepare()
    assertNil(p.callouts.c999)
    local after = shape(p)
    local again = NS.Library.Prepare()
    assertEqual(again.repaired, 0)
    assertEqual(shape(p), after, "a second Prepare changes nothing")
end)
