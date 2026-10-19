local _, NS = ...
-- defaults/GameIds.lua — the shipped game-id tables "Preview as…" and the When editor list (spec
-- §13.2, §13.3; the When editor's full instance and arena lists are defaults/GameIds_Instances.lua). DATA ONLY. Every entry is an id or a token, never a name (localization-§4): a name
-- is read from the client at display time (core/Compat.lua) and never matched.
--   DUNGEONS  the current Mythic+ season's instanceIDs (GetInstanceInfo's 8th return, which is the
--             client's Map id): the season's four returning dungeons and Midnight's four new ones.
--   RAIDS     the current raid tier's instanceIDs: Midnight's three launch raids.
--   CLASSES   classFile tokens, in the client's class order.
--   SPECS     specIDs per classFile. 1480 is the Demon Hunter's Devourer (Midnight): matched in the
--             client's ChrSpecialization table (class 12); in game, smoke check IDS-1.
-- MATCHED (phase 5), NOT YET CONFIRMED IN GAME: matched against the client's own data tables as
-- exported from build 12.1.5.70340 by wago.tools (2026-10-13). Each dungeon is a map of Mythic+
-- display season 34 (MythicPlusSeasonTrackedMap, through MapChallengeMode, to a Map row of instance
-- type 1); each raid a Map row of instance type 2 in the journal's Current Season tier under the
-- launch season's condition. tools/derive-gameids.py re-derives all of it and checks this file and
-- tests/test_gameids.lua's extraction. In-game confirmation is smoke check IDS-1 (and BG-2 for the
-- battlegrounds); this note says CONFIRMED only after the phase 5 smoke test records them as passed.
-- Not listed: the raids the client gates behind a later season (The Tidebound Grotto, The Venomous
-- Abyss, The Unbinding of Kith'ix) and Sporefall (1592; owner ruling R4): the When editor still
-- offers each through INSTANCES, which lists every journal dungeon and raid.

NS.GameIds = NS.GameIds or {}
local G = NS.GameIds

G.DUNGEONS = {
    2526,   -- Algeth'ar Academy
    658,    -- Pit of Saron
    1753,   -- Seat of the Triumvirate
    1209,   -- Skyreach
    2805,   -- Windrunner Spire
    2811,   -- Magisters' Terrace
    2915,   -- Nexus-Point Xenas
    2874,   -- Maisara Caverns
}
G.RAIDS = {
    2912,   -- The Voidspire
    2939,   -- The Dreamrift
    2913,   -- March on Quel'Danas
}

G.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE",
    "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }

G.SPECS = {
    WARRIOR = { 71, 72, 73 }, PALADIN = { 65, 66, 70 }, HUNTER = { 253, 254, 255 },
    ROGUE = { 259, 260, 261 }, PRIEST = { 256, 257, 258 }, DEATHKNIGHT = { 250, 251, 252 },
    SHAMAN = { 262, 263, 264 }, MAGE = { 62, 63, 64 }, WARLOCK = { 265, 266, 267 },
    MONK = { 268, 270, 269 }, DRUID = { 102, 103, 104, 105 }, DEMONHUNTER = { 577, 581, 1480 },
    EVOKER = { 1467, 1468, 1473 },
}
