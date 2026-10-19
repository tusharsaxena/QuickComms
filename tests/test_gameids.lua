-- tests/test_gameids.lua — the shipped instance ids (spec §12.1, §13.2: "phase 5 confirms their
-- instance IDs"), matched against the client's own data. CLIENT_MAPS below is an EXTRACTION, not
-- authored data: the Map table's InstanceType (1 party, 2 raid, 3 battleground, 4 arena) and whether a
-- MapChallengeMode row names the map (a Mythic+ dungeon), for every id defaults/ ships, as exported
-- from client build 12.1.5.70340 by wago.tools on 2026-10-13. tools/derive-gameids.py re-derives
-- every row from those tables and fails on any difference, so an id typed wrong here and in defaults/
-- alike is still caught (docs/common-tasks.md says how to run it). Adding an id to defaults/ means
-- adding its row here and running the generator; smoke checks BG-2 and IDS-1 confirm the ids in game.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local PARTY, RAID, PVP, ARENA = 1, 2, 3, 4

local CLIENT_MAPS = {
    [529] = { type = 3, challenge = false },   -- Classic Arathi Basin
    [2107] = { type = 3, challenge = false },  -- Arathi Basin
    [1681] = { type = 3, challenge = false },  -- Arathi Basin Winter
    [566] = { type = 3, challenge = false },   -- Eye of the Storm
    [968] = { type = 3, challenge = false },   -- Rated Eye of the Storm
    [761] = { type = 3, challenge = false },   -- The Battle for Gilneas
    [1105] = { type = 3, challenge = false },  -- Deepwind Gorge (Legacy)
    [2245] = { type = 3, challenge = false },  -- Deepwind Gorge
    [628] = { type = 3, challenge = false },   -- Isle of Conquest
    [489] = { type = 3, challenge = false },   -- Classic Warsong Gulch
    [2106] = { type = 3, challenge = false },  -- Warsong Gulch
    [726] = { type = 3, challenge = false },   -- Twin Peaks
    [727] = { type = 3, challenge = false },   -- Silvershard Mines
    [998] = { type = 3, challenge = false },   -- Temple of Kotmogu
    [1803] = { type = 3, challenge = false },  -- Seething Shore
    [2656] = { type = 3, challenge = false },  -- Deephaul Ravine
    [30] = { type = 3, challenge = false },    -- Alterac Valley
    [1191] = { type = 3, challenge = false },  -- Ashran
    [2118] = { type = 3, challenge = false },  -- Battle for Wintergrasp
    [2526] = { type = 1, challenge = true },   -- Algeth'ar Academy
    [658] = { type = 1, challenge = true },    -- Pit of Saron
    [1753] = { type = 1, challenge = true },   -- Seat of the Triumvirate
    [1209] = { type = 1, challenge = true },   -- Skyreach
    [2805] = { type = 1, challenge = true },   -- Windrunner Spire
    [2811] = { type = 1, challenge = true },   -- Magisters' Terrace
    [2915] = { type = 1, challenge = true },   -- Nexus-Point Xenas
    [2874] = { type = 1, challenge = true },   -- Maisara Caverns
    [2912] = { type = 2, challenge = false },  -- The Voidspire
    [2939] = { type = 2, challenge = false },  -- The Dreamrift
    [2913] = { type = 2, challenge = false },  -- March on Quel'Danas
    -- the rest of defaults/GameIds_Instances.lua's INSTANCES (every journal dungeon and raid) and ARENAS
    [33] = { type = 1, challenge = false },  -- Shadowfang Keep
    [34] = { type = 1, challenge = false },  -- Stormwind Stockade
    [36] = { type = 1, challenge = false },  -- Deadmines
    [43] = { type = 1, challenge = false },  -- Wailing Caverns
    [47] = { type = 1, challenge = false },  -- Razorfen Kraul
    [48] = { type = 1, challenge = false },  -- Blackfathom Deeps
    [70] = { type = 1, challenge = false },  -- Uldaman
    [90] = { type = 1, challenge = false },  -- Gnomeregan
    [109] = { type = 1, challenge = false },  -- Sunken Temple
    [129] = { type = 1, challenge = false },  -- Razorfen Downs
    [209] = { type = 1, challenge = false },  -- Zul'Farrak
    [229] = { type = 1, challenge = false },  -- Lower Blackrock Spire
    [230] = { type = 1, challenge = false },  -- Blackrock Depths
    [249] = { type = 2, challenge = false },  -- Onyxia's Lair
    [269] = { type = 1, challenge = false },  -- Opening of the Dark Portal
    [329] = { type = 1, challenge = false },  -- Stratholme
    [349] = { type = 1, challenge = false },  -- Maraudon
    [389] = { type = 1, challenge = false },  -- Ragefire Chasm
    [409] = { type = 2, challenge = false },  -- Molten Core
    [429] = { type = 1, challenge = false },  -- Dire Maul
    [469] = { type = 2, challenge = false },  -- Blackwing Lair
    [509] = { type = 2, challenge = false },  -- Ruins of Ahn'Qiraj
    [531] = { type = 2, challenge = false },  -- Ahn'Qiraj Temple
    [532] = { type = 2, challenge = false },  -- Karazhan
    [533] = { type = 2, challenge = false },  -- Naxxramas
    [534] = { type = 2, challenge = false },  -- The Battle for Mount Hyjal
    [540] = { type = 1, challenge = false },  -- Hellfire Citadel: The Shattered Halls
    [542] = { type = 1, challenge = false },  -- Hellfire Citadel: The Blood Furnace
    [543] = { type = 1, challenge = false },  -- Hellfire Citadel: Ramparts
    [544] = { type = 2, challenge = false },  -- Magtheridon's Lair
    [545] = { type = 1, challenge = false },  -- Coilfang: The Steamvault
    [546] = { type = 1, challenge = false },  -- Coilfang: The Underbog
    [547] = { type = 1, challenge = false },  -- Coilfang: The Slave Pens
    [548] = { type = 2, challenge = false },  -- Coilfang: Serpentshrine Cavern
    [550] = { type = 2, challenge = false },  -- Tempest Keep
    [552] = { type = 1, challenge = false },  -- Tempest Keep: The Arcatraz
    [553] = { type = 1, challenge = false },  -- Tempest Keep: The Botanica
    [554] = { type = 1, challenge = false },  -- Tempest Keep: The Mechanar
    [555] = { type = 1, challenge = false },  -- Auchindoun: Shadow Labyrinth
    [556] = { type = 1, challenge = false },  -- Auchindoun: Sethekk Halls
    [557] = { type = 1, challenge = false },  -- Auchindoun: Mana-Tombs
    [558] = { type = 1, challenge = false },  -- Auchindoun: Auchenai Crypts
    [560] = { type = 1, challenge = false },  -- The Escape from Durnholde
    [564] = { type = 2, challenge = false },  -- Black Temple
    [565] = { type = 2, challenge = false },  -- Gruul's Lair
    [568] = { type = 1, challenge = false },  -- Zul'Aman
    [574] = { type = 1, challenge = false },  -- Utgarde Keep
    [575] = { type = 1, challenge = false },  -- Utgarde Pinnacle
    [576] = { type = 1, challenge = false },  -- The Nexus
    [578] = { type = 1, challenge = false },  -- The Oculus
    [580] = { type = 2, challenge = false },  -- The Sunwell
    [585] = { type = 1, challenge = false },  -- Magisters' Terrace
    [595] = { type = 1, challenge = false },  -- The Culling of Stratholme
    [599] = { type = 1, challenge = false },  -- Halls of Stone
    [600] = { type = 1, challenge = false },  -- Drak'Tharon Keep
    [601] = { type = 1, challenge = false },  -- Azjol-Nerub
    [602] = { type = 1, challenge = false },  -- Halls of Lightning
    [603] = { type = 2, challenge = false },  -- Ulduar
    [604] = { type = 1, challenge = false },  -- Gundrak
    [608] = { type = 1, challenge = false },  -- Violet Hold
    [615] = { type = 2, challenge = false },  -- The Obsidian Sanctum
    [616] = { type = 2, challenge = false },  -- The Eye of Eternity
    [619] = { type = 1, challenge = false },  -- Ahn'kahet: The Old Kingdom
    [624] = { type = 2, challenge = false },  -- Vault of Archavon
    [631] = { type = 2, challenge = false },  -- Icecrown Citadel
    [632] = { type = 1, challenge = false },  -- The Forge of Souls
    [643] = { type = 1, challenge = true },  -- Throne of the Tides
    [644] = { type = 1, challenge = false },  -- Halls of Origination
    [645] = { type = 1, challenge = false },  -- Blackrock Caverns
    [649] = { type = 2, challenge = false },  -- Trial of the Crusader
    [650] = { type = 1, challenge = false },  -- Trial of the Champion
    [657] = { type = 1, challenge = true },  -- The Vortex Pinnacle
    [668] = { type = 1, challenge = false },  -- Halls of Reflection
    [669] = { type = 2, challenge = false },  -- Blackwing Descent
    [670] = { type = 1, challenge = true },  -- Grim Batol
    [671] = { type = 2, challenge = false },  -- The Bastion of Twilight
    [720] = { type = 2, challenge = false },  -- Firelands
    [724] = { type = 2, challenge = false },  -- The Ruby Sanctum
    [725] = { type = 1, challenge = true },  -- The Stonecore
    [754] = { type = 2, challenge = false },  -- Throne of the Four Winds
    [755] = { type = 1, challenge = false },  -- Lost City of the Tol'vir
    [859] = { type = 1, challenge = false },  -- Zul'Gurub
    [938] = { type = 1, challenge = false },  -- End Time
    [939] = { type = 1, challenge = false },  -- Well of Eternity
    [940] = { type = 1, challenge = false },  -- Hour of Twilight
    [959] = { type = 1, challenge = true },  -- Shado-Pan Monastery
    [960] = { type = 1, challenge = true },  -- Temple of the Jade Serpent
    [961] = { type = 1, challenge = true },  -- Stormstout Brewery
    [962] = { type = 1, challenge = true },  -- Gate of the Setting Sun
    [967] = { type = 2, challenge = false },  -- Dragon Soul
    [994] = { type = 1, challenge = true },  -- Mogu'shan Palace
    [996] = { type = 2, challenge = false },  -- Terrace of Endless Spring
    [1001] = { type = 1, challenge = true },  -- Scarlet Halls
    [1004] = { type = 1, challenge = true },  -- Scarlet Monastery
    [1007] = { type = 1, challenge = true },  -- Scholomance
    [1008] = { type = 2, challenge = false },  -- Mogu'shan Vaults
    [1009] = { type = 2, challenge = false },  -- Heart of Fear
    [1011] = { type = 1, challenge = true },  -- Siege of Niuzao Temple
    [1098] = { type = 2, challenge = false },  -- Throne of Thunder
    [1136] = { type = 2, challenge = false },  -- Siege of Orgrimmar
    [1175] = { type = 1, challenge = true },  -- Bloodmaul Slag Mines
    [1176] = { type = 1, challenge = true },  -- Shadowmoon Burial Grounds
    [1182] = { type = 1, challenge = true },  -- Auchindoun
    [1195] = { type = 1, challenge = true },  -- Iron Docks
    [1205] = { type = 2, challenge = false },  -- Blackrock Foundry
    [1208] = { type = 1, challenge = true },  -- Grimrail Depot
    [1228] = { type = 2, challenge = false },  -- Highmaul
    [1279] = { type = 1, challenge = true },  -- The Everbloom
    [1358] = { type = 1, challenge = true },  -- Upper Blackrock Spire
    [1448] = { type = 2, challenge = false },  -- Hellfire Citadel
    [1456] = { type = 1, challenge = true },  -- Eye of Azshara
    [1458] = { type = 1, challenge = true },  -- Neltharion's Lair
    [1466] = { type = 1, challenge = true },  -- Darkheart Thicket
    [1477] = { type = 1, challenge = true },  -- Halls of Valor
    [1492] = { type = 1, challenge = true },  -- Maw of Souls
    [1493] = { type = 1, challenge = true },  -- Vault of the Wardens
    [1501] = { type = 1, challenge = true },  -- Black Rook Hold
    [1516] = { type = 1, challenge = true },  -- The Arcway
    [1520] = { type = 2, challenge = false },  -- The Emerald Nightmare
    [1530] = { type = 2, challenge = false },  -- The Nighthold
    [1544] = { type = 1, challenge = false },  -- Assault on Violet Hold
    [1571] = { type = 1, challenge = true },  -- Court of Stars
    [1592] = { type = 2, challenge = false },  -- Sporefall
    [1594] = { type = 1, challenge = true },  -- The MOTHERLODE!!
    [1648] = { type = 2, challenge = false },  -- Trial of Valor
    [1651] = { type = 1, challenge = true },  -- Return to Karazhan
    [1676] = { type = 2, challenge = false },  -- Tomb of Sargeras
    [1677] = { type = 1, challenge = true },  -- Cathedral of Eternal Night
    [1712] = { type = 2, challenge = false },  -- Antorus, the Burning Throne
    [1754] = { type = 1, challenge = true },  -- Freehold
    [1762] = { type = 1, challenge = true },  -- Kings' Rest
    [1763] = { type = 1, challenge = true },  -- Atal'Dazar
    [1771] = { type = 1, challenge = true },  -- Tol Dagor
    [1822] = { type = 1, challenge = true },  -- Siege of Boralus
    [1841] = { type = 1, challenge = true },  -- The Underrot
    [1861] = { type = 2, challenge = false },  -- Uldir
    [1862] = { type = 1, challenge = true },  -- Waycrest Manor
    [1864] = { type = 1, challenge = true },  -- Shrine of the Storm
    [1877] = { type = 1, challenge = true },  -- Temple of Sethraliss
    [2070] = { type = 2, challenge = false },  -- Battle of Dazar'alor
    [2096] = { type = 2, challenge = false },  -- Crucible of Storms
    [2097] = { type = 1, challenge = true },  -- Operation: Mechagon
    [2164] = { type = 2, challenge = false },  -- The Eternal Palace
    [2217] = { type = 2, challenge = false },  -- Ny'alotha, the Waking City
    [2284] = { type = 1, challenge = true },  -- Sanguine Depths
    [2285] = { type = 1, challenge = true },  -- Spires of Ascension
    [2286] = { type = 1, challenge = true },  -- The Necrotic Wake
    [2287] = { type = 1, challenge = true },  -- Halls of Atonement
    [2289] = { type = 1, challenge = true },  -- Plaguefall
    [2290] = { type = 1, challenge = true },  -- Mists of Tirna Scithe
    [2291] = { type = 1, challenge = true },  -- De Other Side
    [2293] = { type = 1, challenge = true },  -- Theater of Pain
    [2296] = { type = 2, challenge = false },  -- Castle Nathria
    [2441] = { type = 1, challenge = true },  -- Tazavesh, the Veiled Market
    [2450] = { type = 2, challenge = false },  -- Sanctum of Domination
    [2451] = { type = 1, challenge = true },  -- Uldaman: Legacy of Tyr
    [2481] = { type = 2, challenge = false },  -- Sepulcher of the First Ones
    [2515] = { type = 1, challenge = true },  -- The Azure Vault
    [2516] = { type = 1, challenge = true },  -- The Nokhud Offensive
    [2519] = { type = 1, challenge = true },  -- Neltharus
    [2520] = { type = 1, challenge = true },  -- Brackenhide Hollow
    [2521] = { type = 1, challenge = true },  -- Ruby Life Pools
    [2522] = { type = 2, challenge = false },  -- Vault of the Incarnates
    [2527] = { type = 1, challenge = true },  -- Halls of Infusion
    [2549] = { type = 2, challenge = false },  -- Amirdrassil, the Dream's Hope
    [2569] = { type = 2, challenge = false },  -- Aberrus, the Shadowed Crucible
    [2579] = { type = 1, challenge = true },  -- Dawn of the Infinite
    [2648] = { type = 1, challenge = true },  -- The Rookery
    [2649] = { type = 1, challenge = true },  -- Priory of the Sacred Flame
    [2651] = { type = 1, challenge = true },  -- Darkflame Cleft
    [2652] = { type = 1, challenge = true },  -- The Stonevault
    [2657] = { type = 2, challenge = false },  -- Nerub-ar Palace
    [2660] = { type = 1, challenge = true },  -- Ara-Kara, City of Echoes
    [2661] = { type = 1, challenge = true },  -- Cinderbrew Meadery
    [2662] = { type = 1, challenge = true },  -- The Dawnbreaker
    [2669] = { type = 1, challenge = true },  -- City of Threads
    [2769] = { type = 2, challenge = false },  -- Liberation of Undermine
    [2773] = { type = 1, challenge = true },  -- Operation: Floodgate
    [2792] = { type = 2, challenge = false },  -- Blackrock Depths
    [2810] = { type = 2, challenge = false },  -- Manaforge Omega
    [2813] = { type = 1, challenge = true },  -- Murder Row
    [2825] = { type = 1, challenge = true },  -- Den of Nalorakk
    [2830] = { type = 1, challenge = true },  -- Eco-Dome Al'dani
    [2859] = { type = 1, challenge = true },  -- The Blinding Vale
    [2923] = { type = 1, challenge = true },  -- Voidscar Arena
    [2987] = { type = 2, challenge = false },  -- The Tidebound Grotto
    [2993] = { type = 1, challenge = true },  -- Altar of Fangs
    [3004] = { type = 2, challenge = false },  -- The Venomous Abyss
    [3029] = { type = 1, challenge = false },  -- Keystone Dungeons
    [3095] = { type = 2, challenge = false },  -- The Unbinding of Kith'ix
    [572] = { type = 4, challenge = false },  -- Ruins of Lordaeron
    [617] = { type = 4, challenge = false },  -- Dalaran Sewers
    [980] = { type = 4, challenge = false },  -- Tol'Viron Arena
    [1134] = { type = 4, challenge = false },  -- The Tiger's Peak
    [1504] = { type = 4, challenge = false },  -- Black Rook Hold Arena
    [1505] = { type = 4, challenge = false },  -- Nagrand Arena
    [1552] = { type = 4, challenge = false },  -- Ashamane's Fall
    [1672] = { type = 4, challenge = false },  -- Blade's Edge Arena
    [1825] = { type = 4, challenge = false },  -- Hook Point
    [1911] = { type = 4, challenge = false },  -- Mugambala
    [2167] = { type = 4, challenge = false },  -- The Robodrome
    [2373] = { type = 4, challenge = false },  -- Empyrean Domain
    [2509] = { type = 4, challenge = false },  -- Maldraxxus Coliseum
    [2547] = { type = 4, challenge = false },  -- Enigma Crucible
    [2563] = { type = 4, challenge = false },  -- Nokhudon Proving Grounds
    [2759] = { type = 4, challenge = false },  -- Cage of Carnage
}

-- Every battleground set's ids: { setId = { id, ... } }.
local function battlegroundIds(NS)
    local out = {}
    for _, gid in ipairs(NS.BuiltIns.order) do
        local def = NS.BuiltIns.groups[gid]
        local ids = def.when and def.when.battleground
        if ids then
            out[gid] = {}
            for id in pairs(ids) do out[gid][#out[gid] + 1] = id end
        end
    end
    return out
end

test("game ids: every battleground set matches only battleground maps, and no map is two sets'", function()
    local NS = T.newAddon()
    local owner, sets = {}, 0
    for gid, ids in pairs(battlegroundIds(NS)) do
        sets = sets + 1
        assertTrue(#ids > 0, gid .. " lists an id")
        for _, id in ipairs(ids) do
            local row = CLIENT_MAPS[id]
            -- red under: change one of defaults/BuiltIns_Battlegrounds.lua's ids to a typo (e.g. 2017)
            assertTrue(row ~= nil, gid .. ": " .. id .. " is not in the client's Map table extraction")
            assertEqual(row.type, PVP, gid .. ": " .. id .. " is a battleground map")
            assertTrue(owner[id] == nil, id .. " is listed by " .. tostring(owner[id]) .. " and " .. gid)
            owner[id] = gid
        end
    end
    assertEqual(sets, 14, "the 14 battlegrounds of brainstorm §8 (spec §12.1)")
end)

test("game ids: the shipped dungeons are Mythic+ dungeons and the shipped raids are raids", function()
    local NS = T.newAddon()
    for _, id in ipairs(NS.GameIds.DUNGEONS) do
        local row = CLIENT_MAPS[id]
        assertTrue(row ~= nil and row.type == PARTY and row.challenge, id .. " is a dungeon with a challenge map")
    end
    for _, id in ipairs(NS.GameIds.RAIDS) do
        local row = CLIENT_MAPS[id]
        assertTrue(row ~= nil and row.type == RAID, id .. " is a raid map")
    end
    assertEqual(#NS.GameIds.DUNGEONS, 8, "the season's eight")
    assertEqual(#NS.GameIds.RAIDS, 3, "the tier's three (four, with Sporefall 1592 and its CLIENT_MAPS row, if ruling R4 ships it)")
end)

-- No id twice in a list: a duplicate would draw one place twice in the suggestions.
local function noDuplicates(list, what)
    local seen = {}
    for _, id in ipairs(list) do
        assertTrue(seen[id] == nil, what .. " lists " .. id .. " twice")
        seen[id] = true
    end
end

test("game ids: [instances] INSTANCES are dungeons and raids, cover the season's, and reach past it", function()
    local NS = T.newAddon()
    local G = NS.GameIds
    -- red under: no INSTANCES list (the When editor offered the season's 11 only)
    assertTrue(type(G.INSTANCES) == "table", "INSTANCES is shipped")
    local has = {}
    for _, id in ipairs(G.INSTANCES) do
        local row = CLIENT_MAPS[id]
        assertTrue(row ~= nil, id .. " has its CLIENT_MAPS row")
        assertTrue(row.type == PARTY or row.type == RAID, id .. " is a dungeon or raid map")
        has[id] = true
    end
    noDuplicates(G.INSTANCES, "INSTANCES")
    for _, id in ipairs(G.DUNGEONS) do assertTrue(has[id], "the season's dungeon " .. id) end
    for _, id in ipairs(G.RAIDS) do assertTrue(has[id], "the tier's raid " .. id) end
    assertTrue(has[2813], "Murder Row, which is not a season dungeon")
    assertEqual(#G.INSTANCES, 201, "every journal dungeon and raid of build 12.1.5.70340")
end)

test("game ids: [arena] ARENAS are arena maps, one per arena", function()
    local NS = T.newAddon()
    local G = NS.GameIds
    assertTrue(type(G.ARENAS) == "table", "ARENAS is shipped")
    for _, id in ipairs(G.ARENAS) do
        local row = CLIENT_MAPS[id]
        assertTrue(row ~= nil and row.type == ARENA, id .. " is an arena map")
    end
    noDuplicates(G.ARENAS, "ARENAS")
    assertEqual(#G.ARENAS, 16, "the client's 18 arena maps, less the two legacy copies")
end)
