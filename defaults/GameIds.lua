local _, NS = ...
-- defaults/GameIds.lua — the shipped game-id tables "Preview as…" and the When editor list (spec
-- §13.2, §13.3). DATA ONLY. Every entry is an id or a token, never a name (localization-§4): a name
-- is read from the client at display time (core/Compat.lua) and never matched.
--   DUNGEONS  the current Mythic+ season's instanceIDs (GetInstanceInfo's 8th return). Only the ids
--             confirmed when this table was written are listed: the season's returning dungeons.
--             The Midnight dungeons and raids join when their ids are confirmed in game (phase 5,
--             with the battleground ids); until then the When editor adds the instance you are in,
--             or a typed id.
--   RAIDS     the current raid tier's instanceIDs (none confirmed yet).
--   CLASSES   classFile tokens, in the client's class order.
--   SPECS     specIDs per classFile. 1480 is the Demon Hunter's Devourer (Midnight), confirmed in
--             game with the rest in phase 5.

NS.GameIds = NS.GameIds or {}
local G = NS.GameIds

G.DUNGEONS = {
    2526,   -- Algeth'ar Academy
    658,    -- Pit of Saron
    1753,   -- Seat of the Triumvirate
    1209,   -- Skyreach
}
G.RAIDS = {}

G.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE",
    "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }

G.SPECS = {
    WARRIOR = { 71, 72, 73 }, PALADIN = { 65, 66, 70 }, HUNTER = { 253, 254, 255 },
    ROGUE = { 259, 260, 261 }, PRIEST = { 256, 257, 258 }, DEATHKNIGHT = { 250, 251, 252 },
    SHAMAN = { 262, 263, 264 }, MAGE = { 62, 63, 64 }, WARLOCK = { 265, 266, 267 },
    MONK = { 268, 270, 269 }, DRUID = { 102, 103, 104, 105 }, DEMONHUNTER = { 577, 581, 1480 },
    EVOKER = { 1467, 1468, 1473 },
}
