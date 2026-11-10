-- tests/test_probe.lua — `/qc probe` and `/qc probe clear` (QFE-F5, the Forever port design §4.5,
-- owner-rulings C4): a record of the place, the situation, the role, the spec, the talent groups and
-- the client's emote tokens, kept in QuickCommsDB.global.probes by client key, never a new
-- SavedVariables global. Out of combat only. Both kit profiles.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

-- Molten Core as GetInstanceInfo answers it, all ten values; two emote tokens with a gap between.
local function place(env)
    env.IsInInstance = function() return true, "raid" end
    env.GetInstanceInfo = function()
        return "Molten Core", "raid", 9, "40 Player", 40, 0, false, 409, 40, nil
    end
    env.GetServerTime = function() return 1762790400 end
    env.MAXEMOTEINDEX = 5
    env.EMOTE1_TOKEN = "AGREE"
    env.EMOTE4_TOKEN = "POINT"
    env.EMOTE9_TOKEN = "PAST_THE_INDEX"
end

local function roleLib(m) return m.LibStub("LibKa0s-Role-1.0") end

test("probe: records the place, the situation, the role, the spec, the talent groups and the emotes", function()
    local NS, env, m = T.enableAddon()
    place(env)
    roleLib(m).Resolve = function() return "TANK", "talents", "Protection" end
    roleLib(m).Groups = function()
        return { { index = 1, id = 11, name = "Arms", spent = 0 }, { index = 2, id = 12, name = "Protection", spent = 31 } }
    end
    m.prints = {}
    NS.addon:OnSlashCommand("probe")
    local list = NS.db.global.probes[NS.Compat.ClientKey()]
    -- red under: no `probe` row in settings/Slash.lua
    assertEqual(#list, 1)
    local rec = list[1]
    assertEqual(rec.client, NS.Compat.ClientKey())
    assertEqual(rec.time, 1762790400)
    local i = rec.instance
    assertEqual(i.name, "Molten Core"); assertEqual(i.instanceType, "raid"); assertEqual(i.difficultyID, 9)
    assertEqual(i.difficultyName, "40 Player"); assertEqual(i.maxPlayers, 40); assertEqual(i.instanceID, 409)
    assertEqual(i.isDynamic, false); assertEqual(i.instanceGroupSize, 40); assertNil(i.lfgDungeonID)
    assertEqual(i.inInstance, true); assertEqual(i.inInstanceType, "raid")
    assertEqual(rec.content, "raid", "the classified kind")
    assertEqual(rec.situation.instanceID, 409)
    assertEqual(rec.role.role, "TANK"); assertEqual(rec.role.source, "talents"); assertEqual(rec.role.detail, "Protection")
    assertEqual(#rec.groups, 2); assertEqual(rec.groups[2].name, "Protection"); assertEqual(rec.groups[2].spent, 31)
    -- red under: a scan that stops at the first missing index (EMOTE2_TOKEN), or one past MAXEMOTEINDEX
    assertEqual(rec.emotes.count, 2)
    assertEqual(table.concat(rec.emotes.tokens, ","), "AGREE,POINT")
    assertTrue(rec.spec ~= nil and rec.spec.id == rec.situation.specID, "the spec the situation read")
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("Probe 1 saved for " .. rec.client, 1, true) ~= nil, text)
    assertTrue(text:find("place: Molten Core, type raid, difficulty 9 (40 Player), 40 players, instance 409", 1, true) ~= nil, text)
    assertTrue(text:find("content: raid", 1, true) ~= nil, text)
    assertTrue(text:find("role: Tank, from your talents: Protection", 1, true) ~= nil, text)
    assertTrue(text:find("talent groups: Arms 0, Protection 31; emotes: 2", 1, true) ~= nil, text)
    assertEqual(#m.prints, 4, "a short summary, not the record")
end)

test("probe: probes append in order, keep the newest PROBE_KEEP, and clear empties every client", function()
    local NS, env, m = T.enableAddon()
    place(env)
    NS.addon:OnSlashCommand("probe")
    NS.addon:OnSlashCommand("probe")
    local key = NS.Compat.ClientKey()
    assertEqual(#NS.db.global.probes[key], 2)
    NS.db.global.probes.other = { {}, {}, {} }
    local keep = NS.SlashVerbs.PROBE_KEEP
    NS.SlashVerbs.PROBE_KEEP = 2
    env.GetServerTime = function() return 1762790500 end
    NS.addon:OnSlashCommand("probe")
    NS.SlashVerbs.PROBE_KEEP = keep
    local list = NS.db.global.probes[key]
    -- red under: no cap (the list grows to 3)
    assertEqual(#list, 2)
    assertEqual(list[2].time, 1762790500, "the newest is last")
    m.prints = {}
    NS.addon:OnSlashCommand("probe clear")
    assertNil(NS.db.global.probes)
    assertTrue(m.prints[1]:find("Probes cleared: 5 removed.", 1, true) ~= nil, m.prints[1])
    m.prints = {}
    NS.addon:OnSlashCommand("probe clear")
    assertTrue(m.prints[1]:find("Probes cleared: 0 removed.", 1, true) ~= nil, m.prints[1])
end)

test("probe: refused in combat with one line, recording nothing; an unknown word names the forms", function()
    local NS, env, m = T.enableAddon()
    place(env)
    m.inCombat = true
    m.prints = {}
    NS.addon:OnSlashCommand("probe")
    -- red under: drop the combat check in settings/SlashVerbs.lua ProbeLines
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("not available in combat", 1, true) ~= nil, m.prints[1])
    assertNil(NS.db.global.probes)
    m.inCombat = false
    m.prints = {}
    NS.addon:OnSlashCommand("probe bogus")
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("/qc probe clear", 1, true) ~= nil, m.prints[1])
    assertNil(NS.db.global.probes)
end)

test("probe: never a new SavedVariables global, and the TOC lists none for it", function()
    local NS, env = T.enableAddon()
    place(env)
    NS.addon:OnSlashCommand("probe")
    -- db.sv is the raw SavedVariables table AceDB was handed (QuickCommsDB)
    assertTrue(type(NS.db.sv.global.probes) == "table", "in QuickCommsDB")
    local toc = assert(io.open("QuickComms.toc", "rb")):read("*a")
    local sv = toc:match("## SavedVariables:%s*([^\r\n]*)")
    -- red under: a QuickCommsProbeDB (or any third) SavedVariables global
    assertEqual(sv, "QuickCommsDB, QuickCommsPerfDB")
end)

test("probe: missing client APIs are stored as nil", function()
    local NS, env = T.enableAddon()
    env.IsInInstance = nil
    env.GetInstanceInfo = nil
    env.GetServerTime = nil
    env.MAXEMOTEINDEX = nil
    NS.addon:OnSlashCommand("probe")
    local rec = NS.db.global.probes[NS.Compat.ClientKey()][1]
    assertNil(rec.time)
    assertNil(rec.instance.name)
    assertNil(rec.instance.inInstance)
    assertEqual(rec.emotes.count, 0)
    assertEqual(rec.content, "openWorld")
end)

test("probe: [QFE-REV] secret client answers are stored as nil, never as the value; plain ones are kept", function()
    local NS, env = T.enableAddon()
    place(env)
    env.issecretvalue = T.isSecret   -- nothing installs the global by default (kit secrets.lua)
    env.IsInInstance = function() return T.secret(true), "raid" end
    env.GetInstanceInfo = function()
        return T.secret("Molten Core"), "raid", T.secret(9), "40 Player", T.secret(40), 0, T.secret(false), 409,
            40, nil
    end
    env.GetServerTime = function() return T.secret(1762790400) end
    NS.addon:OnSlashCommand("probe")
    local rec = NS.db.global.probes[NS.Compat.ClientKey()][1]
    local i = rec.instance
    -- red under: a probe that stores GetInstanceInfo's or GetServerTime's values without the plain readers
    assertNil(rec.time)
    assertNil(i.inInstance); assertNil(i.name); assertNil(i.difficultyID); assertNil(i.maxPlayers); assertNil(i.isDynamic)
    assertEqual(i.inInstanceType, "raid")
    assertEqual(i.instanceType, "raid")
    assertEqual(i.difficultyName, "40 Player")
    assertEqual(i.instanceID, 409)
    for k, v in pairs(i) do assertTrue(not T.isSecret(v), "no secret under " .. k) end
end)

-- ── /qc probe ids (QuickComms#21, the forever-ids design "#1 in game") ───────────────────────
--
-- The client's own names, read with no travel: GetRealZoneText over map ids 0..4000, the dungeon
-- finder's list through GetLFGDungeonInfo, and the battlegrounds through C_PvP.GetBattlegroundInfo.
-- One `ids` record in the same store and under the same cap; the chat gets a short summary.

-- This client's shipped battleground sets that carry ids, in seeding order: { { key, ids }, ... }.
local function shippedSets(NS)
    local out = {}
    for _, gid in ipairs(NS.BuiltIns.Seeded()) do
        local def = NS.BuiltIns.groups[gid]
        local ids = def.when and def.when.battleground
        if ids then
            local list = {}
            for id in pairs(ids) do list[#list + 1] = id end
            table.sort(list)
            out[#out + 1] = { key = gid:match("^bi%.bg%.(.+)$"), ids = list }
        end
    end
    return out
end

-- The group finder's two categories, as fake C_LFGList answers them: { [categoryID] = { activity ids } }
-- and { [activityID] = GroupFinderActivityInfo }. Category 2 lists an activity for every shipped
-- dungeon, then a zone (maxNumPlayers 0, mapID 0) and the first raid's activity again; category 114 an
-- activity for every shipped raid, one for each battleground set's first id and one for a raid map no
-- shipped id carries (Sky Vault, 3500).
local function groupFinder(NS)
    local G = NS.GameIds
    local cats, acts = { [2] = {}, [114] = {} }, {}
    local function add(cat, id, name, mapID, players, pvp)
        acts[id] = { fullName = name, shortName = name, categoryID = cat, mapID = mapID, maxNumPlayers = players,
            isPvpActivity = pvp or false, orderIndex = 0 }
        table.insert(cats[cat], id)
    end
    for i, id in ipairs(G.DUNGEONS) do add(2, 1000 + i, "Map " .. id, id, 5) end
    for i, id in ipairs(G.RAIDS) do add(114, 2000 + i, "Map " .. id, id, 40) end
    for i, s in ipairs(shippedSets(NS)) do add(114, 3000 + i, s.key, s.ids[1], 10, true) end
    add(2, 4001, "Elwynn Forest", 0, 0)
    table.insert(cats[2], 2001)
    add(114, 4002, "Sky Vault", 3500, 40)
    return cats, acts
end

local function fakeLFGList(cats, acts)
    return {
        GetAvailableCategories = function() return { 2, 114 } end,
        GetAvailableActivities = function(cat) return cats[cat] end,
        GetActivityInfoTable = function(id) return acts[id] end,
    }
end

-- A client that names every id this client ships ("Map <id>"), plus two maps it does not ship, and
-- lists three dungeon finder entries (one a shipped dungeon's name, one no shipped id's, one random),
-- two battlegrounds and the group finder's activities (groupFinder). Answers the names table, the
-- GetRealZoneText call log and the group finder's categories and activities.
local function idsClient(NS, env)
    local G = NS.GameIds
    local zones = { [0] = "Eastern Kingdoms", [4000] = "The Last Map" }
    for _, id in ipairs(G.DUNGEONS) do zones[id] = "Map " .. id end
    for _, id in ipairs(G.RAIDS) do zones[id] = "Map " .. id end
    for _, s in ipairs(shippedSets(NS)) do
        for _, id in ipairs(s.ids) do zones[id] = "Map " .. id end
    end
    local calls = {}
    env.GetRealZoneText = function(id)
        calls[#calls + 1] = id
        return zones[id] or ""
    end
    local lfg = {
        [101] = { "Map " .. G.DUNGEONS[1], 1, 1 },
        [102] = { "Nowhere Keep", 1, 1, 3333 },
        [900] = { "Random Dungeon", 6, 1 },
    }
    env.GetLFDChoiceOrder = function() return { 101, 102, -1 } end
    env.GetNumRandomDungeons = function() return 1 end
    env.GetLFGRandomDungeonInfo = function(i) if i == 1 then return 900, "Random Dungeon" end end
    env.GetLFGDungeonInfo = function(id)
        local r = lfg[id]
        if not r then return nil end
        -- name, typeID, subtypeID, then 18 values the probe does not keep, then lfgMapID (the 22nd)
        return r[1], r[2], r[3], 10, 20, 15, 10, 20, 0, 0, "", 1, 5, "", false, 0, 0, false, "", 0, false, r[4]
    end
    env.GetNumBattlegroundTypes = function() return 2 end
    env.C_PvP = { GetBattlegroundInfo = function(i)
        if i == 1 then return { name = "Warsong Gulch", battlegroundID = 2, mapID = 489, isRandom = false } end
        if i == 2 then return { name = "Random Battleground", battlegroundID = 32, isRandom = true } end
    end }
    env.GetServerTime = function() return 1762790400 end
    local cats, acts = groupFinder(NS)
    env.C_LFGList = fakeLFGList(cats, acts)
    return zones, calls, cats, acts
end

local function idsRecord(NS)
    local list = NS.db.global.probes[NS.Compat.ClientKey()]
    return list and list[#list]
end

test("probe ids: sweeps map names 0..4000, the dungeon finder and the battlegrounds into one ids record", function()
    local NS, env, m = T.enableAddon()
    local zones, calls = idsClient(NS, env)
    m.prints = {}
    NS.addon:OnSlashCommand("probe ids")
    local rec = idsRecord(NS)
    -- red under: no `ids` form (the bare probe runs, or the usage line prints)
    assertTrue(rec ~= nil and rec.kind == "ids", "an ids record")
    assertEqual(rec.client, NS.Compat.ClientKey())
    assertEqual(rec.time, 1762790400)
    -- red under: a sweep that starts at 1 or stops short of 4000
    assertEqual(#calls, 4001, "every id 0..4000, once")
    assertEqual(calls[1], 0); assertEqual(calls[#calls], 4000)
    local named, expected = 0, 0
    for id, name in pairs(rec.maps) do
        named = named + 1
        assertEqual(name, zones[id], "map " .. id)
    end
    for _ in pairs(zones) do expected = expected + 1 end
    -- red under: storing the client's empty answers
    assertEqual(named, expected, "the non-empty names only")
    assertEqual(#rec.lfg, 3, "the two listed dungeons and the random one; -1 is not an id")
    assertEqual(rec.lfg[1].id, 101); assertEqual(rec.lfg[1].name, "Map " .. NS.GameIds.DUNGEONS[1])
    assertEqual(rec.lfg[1].typeID, 1); assertEqual(rec.lfg[1].subtypeID, 1); assertNil(rec.lfg[1].mapID)
    -- red under: reading lfgMapID from any return but the 22nd
    assertEqual(rec.lfg[2].mapID, 3333, "GetLFGDungeonInfo's 22nd return")
    assertNil(rec.lfg[2].random)
    assertEqual(rec.lfg[3].id, 900); assertEqual(rec.lfg[3].random, true); assertEqual(rec.lfg[3].name, "Random Dungeon")
    assertEqual(#rec.battlegrounds, 2)
    local bg = rec.battlegrounds[1]
    assertEqual(bg.index, 1); assertEqual(bg.name, "Warsong Gulch"); assertEqual(bg.battlegroundID, 2)
    assertEqual(bg.mapID, 489); assertEqual(bg.isRandom, false)
    assertEqual(rec.battlegrounds[2].isRandom, true); assertNil(rec.battlegrounds[2].mapID)
    assertNil(rec.instance, "the ids record is not a place record")
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("Ids probe 1 saved for " .. rec.client, 1, true) ~= nil, text)
    assertTrue(text:find(("map names read: %d of ids 0 to 4000; dungeon finder: 3 entries; battlegrounds: 2"):format(expected), 1, true) ~= nil, text)
    assertTrue(text:find("shipped ids the client does not name: none", 1, true) ~= nil, text)
    -- red under: a comparison that lists the random entry, or the name a shipped dungeon carries
    assertTrue(text:find("dungeon finder names no shipped id carries: Nowhere Keep", 1, true) ~= nil, text)
    assertEqual(#m.prints, 5, "a short summary, not the record")
end)

test("probe ids: [FID-4] records the group finder's activities, each once, with the fields the check reads", function()
    local NS, env, m = T.enableAddon()
    local G = NS.GameIds
    local _, _, cats = idsClient(NS, env)
    m.prints = {}
    NS.addon:OnSlashCommand("probe ids")
    local gf = idsRecord(NS).groupFinder
    -- red under: no groupFinder reader (the record has no list)
    assertTrue(type(gf) == "table", "a groupFinder list")
    -- red under: a walk that stores the duplicated activity 2001 twice
    assertEqual(#gf, #cats[2] - 1 + #cats[114], "every activity once")
    local byId, seen = {}, 0
    for _, a in ipairs(gf) do
        assertNil(byId[a.id], "activity " .. a.id .. " once")
        byId[a.id], seen = a, seen + 1
    end
    assertEqual(gf[1].id, 1001, "in category order")
    local d = byId[1001]
    assertEqual(d.name, "Map " .. G.DUNGEONS[1]); assertEqual(d.categoryID, 2); assertEqual(d.mapID, G.DUNGEONS[1])
    assertEqual(d.maxNumPlayers, 5); assertEqual(d.isPvp, false)
    assertEqual(byId[2001].categoryID, 114, "the category the activity's info names")
    assertEqual(byId[3001].isPvp, true)
    assertEqual(byId[4001].maxNumPlayers, 0); assertEqual(byId[4001].mapID, 0)
    local text = table.concat(m.prints, "\n")
    -- red under: a comparison that counts the zone (maxNumPlayers 0) or a shipped id as uncarried
    assertTrue(text:find(("group finder: %d activities; shipped ids it does not list: none; maps it lists that no "
        .. "shipped id carries: Sky Vault (3500)"):format(seen), 1, true) ~= nil, text)
end)

test("probe ids: [FID-4] the group finder line names shipped ids it does not list, and reads none when all match", function()
    local NS, env, m = T.enableAddon()
    local G = NS.GameIds
    local _, _, cats, acts = idsClient(NS, env)
    local sets = shippedSets(NS)
    -- the last dungeon, the second raid and the first battleground set are not listed
    table.remove(cats[2], #G.DUNGEONS)
    acts[2002] = nil
    acts[3001] = nil
    -- a non-shipped map with no player count (nil) is still listed; a second activity on it adds no name
    acts[4003] = { fullName = "Odd Hollow", categoryID = 2, mapID = 3600 }
    acts[4004] = { fullName = "Odd Hollow (Heroic)", categoryID = 2, mapID = 3600, maxNumPlayers = 5 }
    table.insert(cats[2], 4003); table.insert(cats[2], 4004)
    m.prints = {}
    NS.addon:OnSlashCommand("probe ids")
    local text = table.concat(m.prints, "\n")
    local want = ("shipped ids it does not list: dungeon %d, raid %d, battleground set %s (%s); maps it lists that no "
        .. "shipped id carries: Odd Hollow (3600), Sky Vault (3500)"):format(G.DUNGEONS[#G.DUNGEONS], G.RAIDS[2],
        sets[1].key, table.concat(sets[1].ids, ", "))
    -- red under: no shipped-id check against the group finder, or one that drops a nil player count
    assertTrue(text:find(want, 1, true) ~= nil, text)
    -- everything listed, the extra raid gone: none and none
    table.insert(cats[2], 1000 + #G.DUNGEONS)
    acts[2002] = { fullName = "Map " .. G.RAIDS[2], categoryID = 114, mapID = G.RAIDS[2], maxNumPlayers = 40 }
    acts[3001] = { fullName = sets[1].key, categoryID = 114, mapID = sets[1].ids[#sets[1].ids], maxNumPlayers = 10 }
    acts[4002], acts[4003], acts[4004] = nil, nil, nil
    m.prints = {}
    NS.addon:OnSlashCommand("probe ids")
    text = table.concat(m.prints, "\n")
    assertTrue(text:find("shipped ids it does not list: none; maps it lists that no shipped id carries: none", 1, true)
        ~= nil, text)
end)

test("probe ids: [FID-4] an empty, missing, throwing, wrong-shape or secret group finder reads as no activities", function()
    local NS, env, m = T.enableAddon()
    idsClient(NS, env)
    local function line()
        m.prints = {}
        NS.addon:OnSlashCommand("probe ids")
        return table.concat(m.prints, "\n")
    end
    local notChecked = "  group finder: not checked, the group finder listed no activities"
    local cases = {
        { "missing", nil },
        { "empty", { GetAvailableCategories = function() return {} end } },
        { "throwing", { GetAvailableCategories = function() error("no finder") end } },
        { "wrong shape", { GetAvailableCategories = function() return "2,114" end,
            GetAvailableActivities = function() return 7 end } },
        { "a secret table", T.secret({}) },
        { "secret answers", { GetAvailableCategories = function() return { T.secret(2) } end } },
        { "a secret activity list", { GetAvailableCategories = function() return { 2 } end,
            GetAvailableActivities = function() return T.secret({ 1 }) end } },
        { "a secret info table", { GetAvailableCategories = function() return { 2 } end,
            GetAvailableActivities = function() return { 1 } end,
            GetActivityInfoTable = function() return T.secret({ fullName = "X" }) end } },
        { "a throwing info read", { GetAvailableCategories = function() return { 2 } end,
            GetAvailableActivities = function() return { 1 } end,
            GetActivityInfoTable = function() error("no activity") end } },
    }
    env.issecretvalue = T.isSecret
    for _, c in ipairs(cases) do
        env.C_LFGList = c[2]
        local text = line()
        -- red under: an unguarded reader (the verb errors), or an empty list reading as "none"
        assertEqual(#idsRecord(NS).groupFinder, 0, c[1])
        assertTrue(text:find(notChecked, 1, true) ~= nil, c[1] .. ": " .. text)
    end
    -- secret fields are stored as nil, never as the value
    env.C_LFGList = { GetAvailableCategories = function() return { 2 } end,
        GetAvailableActivities = function() return { 1, T.secret(5) } end,
        GetActivityInfoTable = function() return { fullName = T.secret("Hidden"), mapID = 36, maxNumPlayers = T.secret(5),
            categoryID = 2, isPvpActivity = T.secret(true) } end }
    line()
    local gf = idsRecord(NS).groupFinder
    assertEqual(#gf, 1, "the secret activity id is skipped")
    assertEqual(gf[1].id, 1); assertEqual(gf[1].mapID, 36); assertEqual(gf[1].categoryID, 2)
    assertNil(gf[1].name); assertNil(gf[1].maxNumPlayers); assertNil(gf[1].isPvp)
end)

test("probe ids: [FID-4] the group finder walk stops at GROUP_FINDER_MAX activities", function()
    local NS, env = T.enableAddon()
    idsClient(NS, env)
    local function many(cat)
        local out = {}
        for i = 1, 1500 do out[i] = cat * 10000 + i end
        return out
    end
    env.C_LFGList = { GetAvailableCategories = function() return { 2, 114 } end,
        GetAvailableActivities = many,
        GetActivityInfoTable = function(id) return { fullName = "A" .. id, mapID = 0, maxNumPlayers = 0 } end }
    NS.addon:OnSlashCommand("probe ids")
    -- red under: no cap (3000 distinct activities), or one per category
    assertEqual(#idsRecord(NS).groupFinder, 2000)
end)

test("probe ids: the summary names each shipped id the client does not name, and a set none of whose ids it names", function()
    local NS, env, m = T.enableAddon()
    local zones = idsClient(NS, env)
    local G = NS.GameIds
    local d, r = G.DUNGEONS[#G.DUNGEONS], G.RAIDS[1]
    zones[d], zones[r] = nil, nil
    local sets = shippedSets(NS)
    local first, second = sets[1], sets[2]
    for _, id in ipairs(first.ids) do zones[id] = nil end
    -- one id of the second set unnamed is not a mismatch: a set also carries the other client's ids
    zones[second.ids[1]] = nil
    m.prints = {}
    NS.addon:OnSlashCommand("probe ids")
    local text = table.concat(m.prints, "\n")
    local want = ("shipped ids the client does not name: dungeon %d, raid %d, battleground set %s (%s)"):format(d, r,
        first.key, table.concat(first.ids, ", "))
    -- red under: no unnamed-id check, or one that reads the record before the sweep stored it
    assertTrue(text:find(want, 1, true) ~= nil, text)
    if #second.ids > 1 then
        assertTrue(text:find("battleground set " .. second.key .. " ", 1, true) == nil, text)
    end
    -- the shipped dungeon the finder names is still carried by name when the client names it
    assertTrue(text:find("carries: Nowhere Keep", 1, true) ~= nil, text)
    zones[G.DUNGEONS[1]] = nil
    m.prints = {}
    NS.addon:OnSlashCommand("probe ids")
    text = table.concat(m.prints, "\n")
    assertTrue(text:find("carries: Map " .. G.DUNGEONS[1] .. ", Nowhere Keep", 1, true) ~= nil, text)
end)

test("probe ids: a dungeon finder entry whose lfgMapID is a shipped id is carried, whatever its name", function()
    local NS, env, m = T.enableAddon()
    idsClient(NS, env)
    local shipped = NS.GameIds.DUNGEONS[2]
    local old = env.GetLFGDungeonInfo
    env.GetLFGDungeonInfo = function(id)
        if id == 102 then
            return "Lower Somewhere", 1, 1, 0, 0, 0, 0, 0, 0, 0, "", 1, 5, "", false, 0, 0, false, "", 0, false, shipped
        end
        return old(id)
    end
    m.prints = {}
    NS.addon:OnSlashCommand("probe ids")
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("dungeon finder names no shipped id carries: none", 1, true) ~= nil, text)
end)

test("probe ids: missing or failing client APIs leave empty lists, and the record is still stored", function()
    local NS, env, m = T.enableAddon()
    for _, name in ipairs({ "GetRealZoneText", "GetLFDChoiceOrder", "GetNumRandomDungeons", "GetLFGRandomDungeonInfo",
        "GetLFGDungeonInfo", "GetNumBattlegroundTypes", "C_PvP", "GetServerTime" }) do
        env[name] = nil
    end
    m.prints = {}
    NS.addon:OnSlashCommand("probe ids")
    local rec = idsRecord(NS)
    -- red under: an unguarded read (the verb errors and stores nothing)
    assertTrue(rec ~= nil and rec.kind == "ids", "stored")
    assertNil(rec.time)
    assertNil(next(rec.maps)); assertEqual(#rec.lfg, 0); assertEqual(#rec.battlegrounds, 0)
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("map names read: 0 of ids 0 to 4000; dungeon finder: 0 entries; battlegrounds: 0", 1, true) ~= nil, text)
    -- red under: an empty finder list passing the name check as "none" (WoW Forever's UI never calls these APIs)
    assertTrue(text:find("dungeon finder names no shipped id carries: not checked, the dungeon finder listed no entries", 1, true)
        ~= nil, text)
    -- an API that is there but throws, or answers the wrong shape, is the same as absent
    env.GetRealZoneText = function(id) if id == 5 then return "Five" end error("no map") end
    env.GetLFDChoiceOrder = function() return "not a list" end
    env.GetNumRandomDungeons = function() error("no finder") end
    env.GetNumBattlegroundTypes = function() return 1 end
    env.C_PvP = { GetBattlegroundInfo = function() error("no battlegrounds") end }
    NS.addon:OnSlashCommand("probe ids")
    rec = idsRecord(NS)
    assertEqual(rec.maps[5], "Five")
    local n = 0
    for _ in pairs(rec.maps) do n = n + 1 end
    assertEqual(n, 1)
    assertEqual(#rec.lfg, 0); assertEqual(#rec.battlegrounds, 0)
    env.C_PvP = {}
    NS.addon:OnSlashCommand("probe ids")
    assertEqual(#idsRecord(NS).battlegrounds, 0, "C_PvP without GetBattlegroundInfo")
end)

-- Every value under `t`, keys too, is plain.
local function assertNoSecret(t, path)
    for k, v in pairs(t) do
        assertTrue(not T.isSecret(k), "no secret key under " .. path)
        if type(v) == "table" then assertNoSecret(v, path .. "." .. tostring(k))
        else assertTrue(not T.isSecret(v), "no secret under " .. path .. "." .. tostring(k)) end
    end
end

test("probe ids: secret client answers are left out or stored as nil, never as the value", function()
    local NS, env = T.enableAddon()
    idsClient(NS, env)
    env.issecretvalue = T.isSecret   -- nothing installs the global by default (kit secrets.lua)
    local plain = env.GetRealZoneText
    env.GetRealZoneText = function(id)
        if id == 0 then return T.secret("Eastern Kingdoms") end
        return plain(id)
    end
    env.GetLFDChoiceOrder = function() return { 101, T.secret(102) } end
    local old = env.GetLFGDungeonInfo
    env.GetLFGDungeonInfo = function(id)
        if id == 101 then
            return T.secret("Hidden"), 1, T.secret(1), 0, 0, 0, 0, 0, 0, 0, "", 1, 5, "", false, 0, 0, false, "", 0,
                false, T.secret(36)
        end
        return old(id)
    end
    env.GetNumRandomDungeons = function() return T.secret(1) end
    env.GetNumBattlegroundTypes = function() return 2 end
    env.C_PvP = { GetBattlegroundInfo = function(i)
        if i == 1 then return { name = T.secret("Warsong Gulch"), battlegroundID = 2, mapID = T.secret(489) } end
        return T.secret({})
    end }
    NS.addon:OnSlashCommand("probe ids")
    local rec = idsRecord(NS)
    -- red under: reads that skip the Plain readers
    assertNil(rec.maps[0], "a secret name is left out")
    assertEqual(#rec.lfg, 1, "the secret id and the secret random count are skipped")
    assertEqual(rec.lfg[1].id, 101); assertNil(rec.lfg[1].name); assertNil(rec.lfg[1].subtypeID)
    assertNil(rec.lfg[1].mapID); assertEqual(rec.lfg[1].typeID, 1)
    assertEqual(#rec.battlegrounds, 1, "a secret info table is skipped")
    assertNil(rec.battlegrounds[1].name); assertNil(rec.battlegrounds[1].mapID)
    assertEqual(rec.battlegrounds[1].battlegroundID, 2)
    assertNoSecret(rec, "rec")
end)

test("probe ids: refused in combat and while disabled with one line, reading and recording nothing", function()
    local NS, env, m = T.enableAddon()
    local _, calls = idsClient(NS, env)
    m.inCombat = true
    m.prints = {}
    NS.addon:OnSlashCommand("probe ids")
    -- red under: an ids form that skips the combat check
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("not available in combat", 1, true) ~= nil, m.prints[1])
    assertEqual(#calls, 0, "no sweep")
    assertNil(NS.db.global.probes)
    m.inCombat = false
    NS.addon:OnSlashCommand("disable")
    m.prints = {}
    NS.addon:OnSlashCommand("probe ids")
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find(NS.SlashCommands:DisabledLine(), 1, true) ~= nil, m.prints[1])
    assertEqual(#calls, 0, "no sweep")
    assertNil(NS.db.global.probes)
end)

test("probe ids: ids and place records share one list and the PROBE_KEEP cap; clear removes both", function()
    local NS, env, m = T.enableAddon()
    place(env)
    idsClient(NS, env)
    local keep = NS.SlashVerbs.PROBE_KEEP
    NS.SlashVerbs.PROBE_KEEP = 2
    NS.addon:OnSlashCommand("probe")
    NS.addon:OnSlashCommand("probe ids")
    NS.addon:OnSlashCommand("probe ids")
    NS.SlashVerbs.PROBE_KEEP = keep
    local list = NS.db.global.probes[NS.Compat.ClientKey()]
    -- red under: an ids store of its own, or one past the cap
    assertEqual(#list, 2)
    assertEqual(list[1].kind, "ids"); assertEqual(list[2].kind, "ids")
    m.prints = {}
    NS.addon:OnSlashCommand("probe clear")
    assertTrue(m.prints[1]:find("Probes cleared: 2 removed.", 1, true) ~= nil, m.prints[1])
    assertNil(NS.db.global.probes)
end)

test("probe ids: the usage line and the help row name the three forms", function()
    local NS, _, m = T.enableAddon()
    m.prints = {}
    NS.addon:OnSlashCommand("probe bogus")
    assertEqual(#m.prints, 1)
    -- red under: a usage line that leaves out the ids form
    for _, form in ipairs({ "/qc probe records", "/qc probe ids", "/qc probe clear" }) do
        assertTrue(m.prints[1]:find(form, 1, true) ~= nil, form .. ": " .. m.prints[1])
    end
    local help
    for _, row in ipairs(NS.COMMANDS) do if row[1] == "probe" then help = row[2] end end
    assertTrue(help ~= nil and help:find("`/qc probe ids`", 1, true) ~= nil, tostring(help))
end)
