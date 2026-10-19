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

-- A profile as builds before step 5 stored it: the generic dungeon set under its old name and M+
-- only When, and the seeded callouts with the icons they shipped with then (none, or a game icon).
local OLD_LUST = "Interface\\Icons\\Spell_Nature_Bloodlust"
local function preIconProfile()
    return {
        groups = {
            g1 = { name = "M+ (generic)", when = { content = { mythicPlus = true } }, origin = "bi.mplus" },
            g2 = { name = "My keys", when = { content = { mythicPlus = true } }, origin = "bi.mplus" },
            g3 = { name = "M+ (generic)", when = { content = { mythicPlus = true }, keyLevel = { min = 10 } },
                origin = "bi.mplus" },
            g4 = { name = "M+ (generic)", when = { content = { mythicPlus = true } } },
        },
        callouts = {
            c1 = { name = "Lust", text = "x", origin = "bi.mplus.lust", icon = OLD_LUST },
            c2 = { name = "Pulling", text = "x", origin = "bi.mplus.pull" },
            c3 = { name = "Kill", text = "x", origin = "bi.arena.kill", icon = false },
            c4 = { name = "Kick", text = "x", origin = "bi.mplus.kicks", icon = 136012 },
            c5 = { name = "Mine", text = "x", icon = OLD_LUST },
            c6 = { name = "Gone", text = "x", origin = "bi.nothing" },
            c7 = { name = "Res", text = "x", origin = "bi.mplus.res", icon = "Interface\\Icons\\Spell_Nature_Reincarnation" },
        },
    }
end

test("database: [B7] step 5 renames the dungeon set, widens its When and gives seeded callouts their glyphs, once", function()
    local NS = T.bootAddon()
    local db = NS.addon.db
    local BI = NS.BuiltIns
    db.sv.profiles.Old = preIconProfile()
    db.global.schemaVersion = 4
    NS.addon:RunMigrations()
    local p = db.sv.profiles.Old
    -- red under: no step 5 in core/Database.lua
    assertEqual(p.groups.g1.name, "Dungeon (generic)", "an un-renamed set takes the new name")
    assertTrue(p.groups.g1.when.content.dungeon and p.groups.g1.when.content.mythicPlus, "and the wider When")
    assertEqual(p.groups.g2.name, "My keys", "a renamed set keeps its name")
    assertTrue(p.groups.g2.when.content.dungeon, "its unedited When still widens")
    assertEqual(p.groups.g3.name, "Dungeon (generic)")
    assertNil(p.groups.g3.when.content.dungeon, "an edited When is the player's")
    assertEqual(p.groups.g4.name, "M+ (generic)", "a group of the player's own is not the shipped set")
    assertNil(p.groups.g4.when.content.dungeon)
    local lust, pull, res = BI.callouts["bi.mplus.lust"], BI.callouts["bi.mplus.pull"], BI.callouts["bi.mplus.res"]
    assertEqual(p.callouts.c1.icon, lust.icon, "the old shipped icon becomes the glyph")
    assertEqual(p.callouts.c1.iconColor, lust.iconColor)
    assertEqual(p.callouts.c2.icon, pull.icon, "no icon becomes the glyph")
    assertEqual(p.callouts.c7.icon, res.icon)
    assertTrue(p.callouts.c3.icon == false, "a cleared icon stays cleared")
    assertNil(p.callouts.c3.iconColor)
    assertEqual(p.callouts.c4.icon, 136012, "a picked icon is the player's")
    assertEqual(p.callouts.c5.icon, OLD_LUST, "a callout of the player's own is untouched")
    assertNil(p.callouts.c6.icon, "an origin no longer shipped is left alone")
    assertTrue(db.global.schemaVersion >= 5)
    -- a second run changes nothing, edits since included
    p.groups.g1.name = "Keys"
    p.callouts.c2.iconColor = "123456"
    db.global.schemaVersion = 4
    NS.addon:RunMigrations()
    assertEqual(p.groups.g1.name, "Keys")
    assertEqual(p.callouts.c2.iconColor, "123456")
    assertEqual(p.callouts.c1.icon, lust.icon)
    local fresh = {}
    NS.Library.MigrateBuiltins(fresh)
    assertNil(next(fresh), "a fresh profile is left as it is")
    NS.Library.MigrateBuiltins({ groups = "damaged", callouts = { c1 = "damaged" } })
end)

-- A profile as builds before step 6 stored it: the seeded sets' game icons and uncolored glyphs, and
-- Arathi Basin's set with no callouts of its own.
local function prePolishProfile(BI)
    local pull = BI.callouts["bi.mplus.pull"]
    return {
        nextId = 9,
        groups = {
            g1 = { name = "Dungeon (generic)", icon = "Interface\\Icons\\INV_Relics_Hourglass", origin = "bi.mplus",
                callouts = { "c1", "c2", "c3", "c4" } },
            g2 = { name = "Raid", icon = 136012, origin = "bi.raid", callouts = {} },
            g3 = { name = "Arathi Basin", origin = "bi.bg.ab", callouts = {} },
            g4 = { name = "Eye", origin = "bi.bg.eots", icon = false, callouts = { "c5" } },
            g5 = { name = "Stables", origin = "bi.bg.ab.stables", parent = "g3", callouts = {} },
            g8 = { name = "Mine", callouts = {} },
        },
        callouts = {
            c1 = { name = "Pulling", text = "x", origin = "bi.mplus.pull", icon = pull.icon },
            c2 = { name = "Kick", text = "x", origin = "bi.mplus.kicks", icon = BI.callouts["bi.mplus.kicks"].icon,
                iconColor = "123456" },
            c3 = { name = "Skip", text = "x", origin = "bi.mplus.skip", icon = false },
            c4 = { name = "Lust", text = "x", origin = "bi.mplus.lust", icon = 136012 },
            c5 = { name = "Flag", text = "x", origin = "bi.bg.eots.flagcap" },
        },
    }
end

test("database: [polish] step 6 colors untouched seeded icons and adds the node sets' own callouts, once", function()
    local NS = T.bootAddon()
    local db = NS.addon.db
    local BI = NS.BuiltIns
    db.sv.profiles.Old = prePolishProfile(BI)
    db.global.schemaVersion = 5
    NS.addon:RunMigrations()
    local p = db.sv.profiles.Old
    -- red under: no step 6 in core/Database.lua
    assertTrue(db.global.schemaVersion >= 6)
    local mplus, ab = BI.groups["bi.mplus"], BI.groups["bi.bg.ab"]
    assertEqual(p.groups.g1.icon, mplus.icon, "the old shipped game icon becomes the glyph")
    assertEqual(p.groups.g1.iconColor, mplus.iconColor)
    assertEqual(p.groups.g2.icon, 136012, "a picked icon is the player's")
    assertNil(p.groups.g2.iconColor)
    assertEqual(p.groups.g3.icon, ab.icon, "no icon becomes the glyph")
    assertTrue(p.groups.g4.icon == false, "a cleared icon stays cleared")
    assertEqual(p.groups.g5.icon, BI.groups["bi.bg.ab.stables"].icon, "a node takes its glyph")
    assertNil(p.groups.g8.icon, "a group of the player's own is untouched")
    assertEqual(p.callouts.c1.iconColor, BI.callouts["bi.mplus.pull"].iconColor, "an uncolored glyph takes its color")
    assertEqual(p.callouts.c2.iconColor, "123456", "a picked color is the player's")
    assertTrue(p.callouts.c3.icon == false and p.callouts.c3.iconColor == nil, "a cleared icon takes no color")
    assertNil(p.callouts.c4.iconColor, "a picked icon takes no color")
    -- Arathi Basin's own callouts arrive at the end of its group, each once, under fresh ids.
    assertEqual(#p.groups.g3.callouts, #ab.callouts)
    for i, cid in ipairs(p.groups.g3.callouts) do
        assertEqual(p.callouts[cid].origin, ab.callouts[i], "in shipped order")
        assertEqual(p.callouts[cid].text, BI.callouts[ab.callouts[i]].text)
        assertEqual(p.callouts[cid].iconColor, BI.callouts[ab.callouts[i]].iconColor)
        assertTrue(cid:match("^c%d+$") and tonumber(cid:sub(2)) >= 9, "a fresh id: " .. cid)
    end
    local eots = BI.groups["bi.bg.eots"].callouts
    assertEqual(#p.groups.g4.callouts, #eots, "one already held is not added twice")
    assertEqual(p.groups.g4.callouts[1], "c5")
    assertEqual(#p.groups.g5.callouts, 0, "a node gains nothing")
    for _, g in pairs(p.groups) do assertTrue(g.origin ~= "bi.bg.dwg", "a deleted set is not brought back") end
    assertNil(p.groups.g6)
    assertTrue(p.nextId > 9)
    -- a second run changes nothing, edits since included
    local held = #p.groups.g3.callouts
    p.groups.g3.iconColor = "654321"
    db.global.schemaVersion = 5
    NS.addon:RunMigrations()
    assertEqual(#p.groups.g3.callouts, held, "nothing is added twice")
    assertEqual(p.groups.g3.iconColor, "654321")
    local fresh = {}
    NS.Library.MigrateBuiltinsPolish(fresh)
    assertNil(next(fresh), "a fresh profile is left as it is")
    NS.Library.MigrateBuiltinsPolish({ groups = { g1 = { origin = "bi.bg.ab", callouts = "damaged" } },
        callouts = "damaged" })
    NS.Library.MigrateBuiltinsPolish({ groups = "damaged", callouts = { c1 = "damaged" } })
end)
