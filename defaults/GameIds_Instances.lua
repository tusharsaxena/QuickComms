local _, NS = ...
-- defaults/GameIds_Instances.lua — the When editor's place lists (2026-10-19 plan, B6). DATA ONLY.
-- Every entry is a map id (GetInstanceInfo's 8th return), never a name (localization-§4): the
-- editor names each through the client (core/Compat.lua InstanceName) and matches the id alone.
--   INSTANCES  every Encounter Journal dungeon and raid: the instance row's suggestions and typed
--              names. defaults/GameIds.lua's DUNGEONS and RAIDS stay the season's lists (Preview as…,
--              and the season checks), and win a name two maps share.
--   ARENAS     every arena map, one per arena: the arena row's suggestions and typed names. Not
--              shipped (legacy copies a newer map of the same arena replaced): 559 Nagrand Arena
--              (old) and 562 zzOldBlade's Edge Arena, as the client's Map table names them.
-- MATCHED, NOT YET CONFIRMED IN GAME: derived from the client's own data tables as exported from
-- build 12.1.5.70340 by wago.tools (2026-10-19): INSTANCES from JournalInstance (a Map row of
-- instance type 1 or 2, world-boss entries skipped), ARENAS from Map (instance type 4).
-- tools/derive-gameids.py re-derives both and fails on any difference; tests/test_gameids.lua holds
-- each id's CLIENT_MAPS row. The names beside the ids are the client's, for review only.

NS.GameIds = NS.GameIds or {}
local G = NS.GameIds

G.INSTANCES = {
    33,  -- Shadowfang Keep
    34,  -- Stormwind Stockade
    36,  -- Deadmines
    43,  -- Wailing Caverns
    47,  -- Razorfen Kraul
    48,  -- Blackfathom Deeps
    70,  -- Uldaman
    90,  -- Gnomeregan
    109,  -- Sunken Temple
    129,  -- Razorfen Downs
    209,  -- Zul'Farrak
    229,  -- Lower Blackrock Spire
    230,  -- Blackrock Depths
    249,  -- Onyxia's Lair
    269,  -- Opening of the Dark Portal
    329,  -- Stratholme
    349,  -- Maraudon
    389,  -- Ragefire Chasm
    409,  -- Molten Core
    429,  -- Dire Maul
    469,  -- Blackwing Lair
    509,  -- Ruins of Ahn'Qiraj
    531,  -- Ahn'Qiraj Temple
    532,  -- Karazhan
    533,  -- Naxxramas
    534,  -- The Battle for Mount Hyjal
    540,  -- Hellfire Citadel: The Shattered Halls
    542,  -- Hellfire Citadel: The Blood Furnace
    543,  -- Hellfire Citadel: Ramparts
    544,  -- Magtheridon's Lair
    545,  -- Coilfang: The Steamvault
    546,  -- Coilfang: The Underbog
    547,  -- Coilfang: The Slave Pens
    548,  -- Coilfang: Serpentshrine Cavern
    550,  -- Tempest Keep
    552,  -- Tempest Keep: The Arcatraz
    553,  -- Tempest Keep: The Botanica
    554,  -- Tempest Keep: The Mechanar
    555,  -- Auchindoun: Shadow Labyrinth
    556,  -- Auchindoun: Sethekk Halls
    557,  -- Auchindoun: Mana-Tombs
    558,  -- Auchindoun: Auchenai Crypts
    560,  -- The Escape from Durnholde
    564,  -- Black Temple
    565,  -- Gruul's Lair
    568,  -- Zul'Aman
    574,  -- Utgarde Keep
    575,  -- Utgarde Pinnacle
    576,  -- The Nexus
    578,  -- The Oculus
    580,  -- The Sunwell
    585,  -- Magisters' Terrace
    595,  -- The Culling of Stratholme
    599,  -- Halls of Stone
    600,  -- Drak'Tharon Keep
    601,  -- Azjol-Nerub
    602,  -- Halls of Lightning
    603,  -- Ulduar
    604,  -- Gundrak
    608,  -- Violet Hold
    615,  -- The Obsidian Sanctum
    616,  -- The Eye of Eternity
    619,  -- Ahn'kahet: The Old Kingdom
    624,  -- Vault of Archavon
    631,  -- Icecrown Citadel
    632,  -- The Forge of Souls
    643,  -- Throne of the Tides
    644,  -- Halls of Origination
    645,  -- Blackrock Caverns
    649,  -- Trial of the Crusader
    650,  -- Trial of the Champion
    657,  -- The Vortex Pinnacle
    658,  -- Pit of Saron
    668,  -- Halls of Reflection
    669,  -- Blackwing Descent
    670,  -- Grim Batol
    671,  -- The Bastion of Twilight
    720,  -- Firelands
    724,  -- The Ruby Sanctum
    725,  -- The Stonecore
    754,  -- Throne of the Four Winds
    755,  -- Lost City of the Tol'vir
    859,  -- Zul'Gurub
    938,  -- End Time
    939,  -- Well of Eternity
    940,  -- Hour of Twilight
    959,  -- Shado-Pan Monastery
    960,  -- Temple of the Jade Serpent
    961,  -- Stormstout Brewery
    962,  -- Gate of the Setting Sun
    967,  -- Dragon Soul
    994,  -- Mogu'shan Palace
    996,  -- Terrace of Endless Spring
    1001,  -- Scarlet Halls
    1004,  -- Scarlet Monastery
    1007,  -- Scholomance
    1008,  -- Mogu'shan Vaults
    1009,  -- Heart of Fear
    1011,  -- Siege of Niuzao Temple
    1098,  -- Throne of Thunder
    1136,  -- Siege of Orgrimmar
    1175,  -- Bloodmaul Slag Mines
    1176,  -- Shadowmoon Burial Grounds
    1182,  -- Auchindoun
    1195,  -- Iron Docks
    1205,  -- Blackrock Foundry
    1208,  -- Grimrail Depot
    1209,  -- Skyreach
    1228,  -- Highmaul
    1279,  -- The Everbloom
    1358,  -- Upper Blackrock Spire
    1448,  -- Hellfire Citadel
    1456,  -- Eye of Azshara
    1458,  -- Neltharion's Lair
    1466,  -- Darkheart Thicket
    1477,  -- Halls of Valor
    1492,  -- Maw of Souls
    1493,  -- Vault of the Wardens
    1501,  -- Black Rook Hold
    1516,  -- The Arcway
    1520,  -- The Emerald Nightmare
    1530,  -- The Nighthold
    1544,  -- Assault on Violet Hold
    1571,  -- Court of Stars
    1592,  -- Sporefall
    1594,  -- The MOTHERLODE!!
    1648,  -- Trial of Valor
    1651,  -- Return to Karazhan
    1676,  -- Tomb of Sargeras
    1677,  -- Cathedral of Eternal Night
    1712,  -- Antorus, the Burning Throne
    1753,  -- Seat of the Triumvirate
    1754,  -- Freehold
    1762,  -- Kings' Rest
    1763,  -- Atal'Dazar
    1771,  -- Tol Dagor
    1822,  -- Siege of Boralus
    1841,  -- The Underrot
    1861,  -- Uldir
    1862,  -- Waycrest Manor
    1864,  -- Shrine of the Storm
    1877,  -- Temple of Sethraliss
    2070,  -- Battle of Dazar'alor
    2096,  -- Crucible of Storms
    2097,  -- Operation: Mechagon
    2164,  -- The Eternal Palace
    2217,  -- Ny'alotha, the Waking City
    2284,  -- Sanguine Depths
    2285,  -- Spires of Ascension
    2286,  -- The Necrotic Wake
    2287,  -- Halls of Atonement
    2289,  -- Plaguefall
    2290,  -- Mists of Tirna Scithe
    2291,  -- De Other Side
    2293,  -- Theater of Pain
    2296,  -- Castle Nathria
    2441,  -- Tazavesh, the Veiled Market
    2450,  -- Sanctum of Domination
    2451,  -- Uldaman: Legacy of Tyr
    2481,  -- Sepulcher of the First Ones
    2515,  -- The Azure Vault
    2516,  -- The Nokhud Offensive
    2519,  -- Neltharus
    2520,  -- Brackenhide Hollow
    2521,  -- Ruby Life Pools
    2522,  -- Vault of the Incarnates
    2526,  -- Algeth'ar Academy
    2527,  -- Halls of Infusion
    2549,  -- Amirdrassil, the Dream's Hope
    2569,  -- Aberrus, the Shadowed Crucible
    2579,  -- Dawn of the Infinite
    2648,  -- The Rookery
    2649,  -- Priory of the Sacred Flame
    2651,  -- Darkflame Cleft
    2652,  -- The Stonevault
    2657,  -- Nerub-ar Palace
    2660,  -- Ara-Kara, City of Echoes
    2661,  -- Cinderbrew Meadery
    2662,  -- The Dawnbreaker
    2669,  -- City of Threads
    2769,  -- Liberation of Undermine
    2773,  -- Operation: Floodgate
    2792,  -- Blackrock Depths
    2805,  -- Windrunner Spire
    2810,  -- Manaforge Omega
    2811,  -- Magisters' Terrace
    2813,  -- Murder Row
    2825,  -- Den of Nalorakk
    2830,  -- Eco-Dome Al'dani
    2859,  -- The Blinding Vale
    2874,  -- Maisara Caverns
    2912,  -- The Voidspire
    2913,  -- March on Quel'Danas
    2915,  -- Nexus-Point Xenas
    2923,  -- Voidscar Arena
    2939,  -- The Dreamrift
    2987,  -- The Tidebound Grotto
    2993,  -- Altar of Fangs
    3004,  -- The Venomous Abyss
    3029,  -- Keystone Dungeons
    3095,  -- The Unbinding of Kith'ix
}

G.ARENAS = {
    572,  -- Ruins of Lordaeron
    617,  -- Dalaran Sewers
    980,  -- Tol'Viron Arena
    1134,  -- The Tiger's Peak
    1504,  -- Black Rook Hold Arena
    1505,  -- Nagrand Arena
    1552,  -- Ashamane's Fall
    1672,  -- Blade's Edge Arena
    1825,  -- Hook Point
    1911,  -- Mugambala
    2167,  -- The Robodrome
    2373,  -- Empyrean Domain
    2509,  -- Maldraxxus Coliseum
    2547,  -- Enigma Crucible
    2563,  -- Nokhudon Proving Grounds
    2759,  -- Cage of Carnage
}
