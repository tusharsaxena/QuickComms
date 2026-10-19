-- tests/test_database.lua — the defaults tree and the migration runner (savedvariables-§1).

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

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
    local target = NS.SCHEMA_VERSION + 1
    NS.addon.db.global.schemaVersion = NS.SCHEMA_VERSION
    local seen = {}
    NS.MIGRATIONS[#NS.MIGRATIONS + 1] = { to = target, perProfile = true,
        run = function(_, profile) seen[#seen + 1] = profile end }
    NS.addon:RunMigrations()
    NS.MIGRATIONS[#NS.MIGRATIONS] = nil
    assertEqual(#seen, 2, "Default and Second")
    assertEqual(NS.addon.db.global.schemaVersion, target)
end)

test("database: [phase 4] step 2 moves the generic battleground set below the per-battleground sets", function()
    local NS = T.bootAddon()
    local p = NS.addon.db.profile
    p.pads[p.padOrder[1]].groups = { "bi.mplus", "bi.bg", "bi.bg.ab", "bi.bg.wsg" }
    NS.addon.db.global.schemaVersion = 1
    NS.addon:RunMigrations()
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
    -- Step 3 leaves this profile alone: it was given its seeded groups at boot (seededSets).
    assertEqual(table.concat(p.pads[p.padOrder[1]].groups, ","), "bi.mplus,bi.bg.ab,bi.bg.wsg,bi.bg")
end)

-- A profile as builds before step 3 stored it: built-in references on its pad and dial, an overlay
-- with one set off and a callout hidden, a customized set whose copy took its place, a node and a
-- stale id on the pad, and no seeded groups.
local function overlayProfile(NS)
    local seen = {}
    for _, top in ipairs(NS.BuiltIns.order) do seen[top] = true end
    return {
        seeded = true, nextId = 6,
        callouts = { c3 = { name = "Bloodlust", text = "Bloodlust now", channel = "raid" } },
        groups = { g4 = { name = "Raid (custom)", callouts = { "c3" }, when = {} } },
        builtins = { ["bi.arena"] = { enabled = false, hidden = { ["bi.arena.cc"] = true } },
                     ["bi.raid"] = { enabled = false, hidden = {}, customizedAs = "g4" } },
        pads = { p1 = { name = "Comms Pad", seenBuiltins = seen,
            groups = { "g4", "bi.arena", "bi.bg.ab", "bi.bg.ab.stables", "bi.gone" } } },
        dials = { d2 = { name = "Comms Dial", groups = { "bi.mplus", "bi.raid" } } },
        padOrder = { "p1" }, dialOrder = { "d2" },
    }
end

local function originOf(p, origin)
    for id, g in pairs(p.groups) do
        if g.origin == origin then return id, g end
    end
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

test("database: step 3 turns the built-in overlay into seeded groups, each in its set's place", function()
    local NS = T.bootAddon()
    local db = NS.addon.db
    db.sv.profiles.Old = overlayProfile(NS)
    db.global.schemaVersion = 2
    NS.addon:RunMigrations()
    assertEqual(db.global.schemaVersion, NS.SCHEMA_VERSION)
    local p = db.sv.profiles.Old
    -- red under: run = function() end for step 3 in core/Database.lua
    assertNil(p.builtins, "the overlay is gone")
    local arena, ag = originOf(p, "bi.arena")
    local ab = originOf(p, "bi.bg.ab")
    assertEqual(table.concat(p.pads.p1.groups, ","), table.concat({ "g4", arena, ab }, ","),
        "each set in its place; a node and a stale id left out")
    assertNil(p.pads.p1.seenBuiltins)
    assertEqual(table.concat(p.dials.d2.groups, ","), originOf(p, "bi.mplus"), "a customized set's reference goes")
    assertTrue(ag.enabled == false, "a set that was off is a group that is off")
    assertEqual(#ag.callouts, #NS.BuiltIns.groups["bi.arena"].callouts - 1, "its hidden callout is left out")
    for _, cid in ipairs(ag.callouts) do assertTrue(p.callouts[cid].origin ~= "bi.arena.cc") end
    assertNil(originOf(p, "bi.raid"), "a customized set is not seeded: its copy stands in")
    assertTrue(p.seededSets["bi.raid"] == true, "and it counts as given")
    assertEqual(p.groups.g4.name, "Raid (custom)", "the copy is kept as it was")
    local _, stables = originOf(p, "bi.bg.ab.stables")
    assertEqual(stables.parent, ab, "a node sits inside its set")
    assertEqual(stables.compass, "NW")
    assertTrue(p.nextId > 6 and p.callouts.c3.name == "Bloodlust", "fresh ids: nothing stored is overwritten")
end)

test("database: [review] step 3 puts a set the pad has not seen at the pad's end", function()
    local NS = T.bootAddon()
    local db = NS.addon.db
    local old = overlayProfile(NS)
    old.pads.p1.seenBuiltins["bi.mplus"] = nil
    db.sv.profiles.Old = old
    db.global.schemaVersion = 2
    NS.addon:RunMigrations()
    local p = db.sv.profiles.Old
    local mplus = originOf(p, "bi.mplus")
    -- red under: drop the seenBuiltins append from Lib.SeedFromOverlay
    assertEqual(p.pads.p1.groups[#p.pads.p1.groups], mplus, "a set shipped after the pad last loaded")
    assertEqual(#p.pads.p1.groups, 4, "and only that one: every other set was seen")
    assertNil(p.pads.p1.seenBuiltins)
    assertEqual(table.concat(p.dials.d2.groups, ","), mplus, "a surface with no seenBuiltins gets nothing more")
end)

test("database: [review] step 3 lifts a stale id counter before it seeds", function()
    local NS = T.bootAddon()
    local db = NS.addon.db
    local old = overlayProfile(NS)
    old.nextId = 2
    db.sv.profiles.Old = old
    db.global.schemaVersion = 2
    NS.addon:RunMigrations()
    local p = db.sv.profiles.Old
    -- red under: drop liftNextId from Lib.SeedFromOverlay
    assertEqual(p.callouts.c3.name, "Bloodlust", "a stored callout is not overwritten")
    assertEqual(p.callouts.c3.origin, nil)
    assertEqual(p.groups.g4.name, "Raid (custom)", "a stored group is not overwritten")
    for _, key in ipairs({ "callouts", "groups" }) do
        for id, m in pairs(p[key]) do
            if m.origin then assertTrue(tonumber(id:match("%d+")) > 4, "seeded id " .. id .. " is above 4") end
        end
    end
end)

test("database: step 3 runs once, and the profile loads without duplicates", function()
    local NS = T.bootAddon()
    local db = NS.addon.db
    db.sv.profiles.Old = overlayProfile(NS)
    db.global.schemaVersion = 2
    NS.addon:RunMigrations()
    local p = db.sv.profiles.Old
    local groups, callouts = count(p.groups), count(p.callouts)
    db.global.schemaVersion = 2
    NS.addon:RunMigrations()
    assertEqual(count(p.groups), groups, "a second run seeds nothing")
    db:SetProfile("Old")
    assertEqual(count(NS.db.profile.groups), groups, "Prepare seeds nothing more on load")
    assertEqual(count(NS.db.profile.callouts), callouts)
end)

test("database: step 3 leaves a profile never prepared to Prepare, which seeds it once", function()
    local NS = T.bootAddon()
    local db = NS.addon.db
    db.sv.profiles.Fresh = { builtins = { ["bi.mplus"] = { enabled = false } } }
    db.global.schemaVersion = 2
    NS.addon:RunMigrations()
    local p = db.sv.profiles.Fresh
    assertNil(p.builtins)
    assertNil(p.groups, "nothing seeded by the step")
    db:SetProfile("Fresh")
    local _, mplus = originOf(NS.db.profile, "bi.mplus")
    assertTrue(mplus ~= nil and mplus.enabled, "Prepare seeds it as a new profile is seeded")
end)

test("database: the profile defaults carry the Master controls value, and no debug flag", function()
    local NS = T.bootAddon()
    local p = NS.addon.db.profile
    assertEqual(p.enabled, true)
    -- The debug flag is session-only (debug-logging-§5).
    assertTrue(p.debug == nil and p.state == nil)
    assertEqual(NS.addon.db.global.minimap.hide, false)
end)

test("database: [B2] step 4 rewrites a pad's retired Upward growth as Right and up, once", function()
    local NS = T.bootAddon()
    local db = NS.addon.db
    db.sv.profiles.Old = { pads = { p1 = { layout = { growth = "up", columns = 3 } },
        p2 = { layout = { growth = "left" } }, p3 = {}, p4 = { layout = "damaged" } } }
    db.global.schemaVersion = 3
    NS.addon:RunMigrations()
    local p = db.sv.profiles.Old
    -- red under: no step 4 in core/Database.lua
    assertEqual(p.pads.p1.layout.growth, "rightUp")
    assertEqual(p.pads.p1.layout.columns, 3, "nothing else moves")
    assertEqual(p.pads.p2.layout.growth, "left")
    assertNil(p.pads.p3.layout, "a pad with no layout stays without one")
    assertEqual(p.pads.p4.layout, "damaged")
    assertTrue(db.global.schemaVersion >= 4)
    p.pads.p2.layout.growth = "leftUp"
    db.global.schemaVersion = 3
    NS.addon:RunMigrations()
    assertEqual(p.pads.p1.layout.growth, "rightUp", "a second run changes nothing")
    assertEqual(p.pads.p2.layout.growth, "leftUp")
    local fresh = {}
    NS.Library.MigrateGrowth(fresh)
    assertNil(next(fresh), "a fresh profile is left as it is")
end)
