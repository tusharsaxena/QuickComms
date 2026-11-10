local _, NS = ...
-- defaults/GameIds_Clients.lua — the per-client game data (clients-§5; QFE-F3), picked once at load by
-- Compat.ClientKey(). DATA ONLY: ids and tokens, never a name (localization-§4). defaults/GameIds.lua
-- and defaults/GameIds_Instances.lua hold Retail's lists. This file keeps them as BY_CLIENT.retail,
-- holds WoW Forever's beside them, and puts the client's own under the names every reader uses
-- (G.DUNGEONS, G.RAIDS, G.INSTANCES, G.ARENAS), so no reader asks which client it is.
--   DUNGEONS, RAIDS     Preview as...'s lists: Retail's season, Forever's classic-era dungeons and raids.
--   INSTANCES, ARENAS   the When editor's suggestions.
--   HIDDEN_CONTENT      the content kinds the When editor and Preview as... do not offer. The classify
--                       step is the same on both clients, and a stored When that names one still loads
--                       and matches: hiding is UI and seeds only (owner ruling R1, Claude's call C3).
--   HIDDEN_ROWS         the When rows the editor does not draw (the key level, the difficulty, whose
--                       Forever ids are unknown until probed, and the arena list).
--   HIDDEN_TOKENS       the callout tokens the text's help does not offer ({dungeon} and {key} are
--                       Mythic+ only).
--   SKIP_BUILTINS       the shipped top-level sets this client does not seed or restore.
--   BUILTIN_WHEN        the When a shipped group is seeded and restored with on this client, by shipped
--                       id, in place of the one it declares (BuiltIns.WhenOf). Seeds only: a copy
--                       already stored keeps the When it has.
--   BATTLEGROUND_SETS   the battleground sets seeded, by key (bi.bg.<key>); nil seeds every one.
-- WoW Forever's ids are MATCHED, NOT CONFIRMED IN GAME: each is a classic-era map id taken from
-- Retail's own lists (its CLIENT_MAPS row in tests/test_gameids.lua), on the reading that Forever
-- keeps the classic map ids (owner ruling R2: map ids, then the probe). The probe and smoke checks
-- FOREVER-12 to FOREVER-17 confirm them; this note says CONFIRMED only after those pass. Left out
-- until the probe names their Forever ids, because Retail lists only their remakes: Scarlet
-- Monastery (classic 189; Retail 1004), Scholomance (classic 289; Retail 1007) and Zul'Gurub's raid
-- (classic 309; Retail 859, the dungeon).

NS.GameIds = NS.GameIds or {}
local G = NS.GameIds

local FOREVER_DUNGEONS = {
    389,  -- Ragefire Chasm
    36,   -- Deadmines
    43,   -- Wailing Caverns
    33,   -- Shadowfang Keep
    48,   -- Blackfathom Deeps
    34,   -- Stormwind Stockade
    90,   -- Gnomeregan
    47,   -- Razorfen Kraul
    129,  -- Razorfen Downs
    70,   -- Uldaman
    209,  -- Zul'Farrak
    349,  -- Maraudon
    109,  -- Sunken Temple
    230,  -- Blackrock Depths
    229,  -- Lower Blackrock Spire (classic Blackrock Spire, both halves)
    429,  -- Dire Maul
    329,  -- Stratholme
}

-- A new list of raids for Forever (owner ruling R1), by their Retail map ids.
local FOREVER_RAIDS = {
    409,  -- Molten Core
    249,  -- Onyxia's Lair
    469,  -- Blackwing Lair
    509,  -- Ruins of Ahn'Qiraj
    531,  -- Temple of Ahn'Qiraj
    533,  -- Naxxramas
}

local function concat(a, b)
    local out = {}
    for _, id in ipairs(a) do out[#out + 1] = id end
    for _, id in ipairs(b) do out[#out + 1] = id end
    return out
end

local function set(list)
    local out = {}
    for _, v in ipairs(list) do out[v] = true end
    return out
end

G.BY_CLIENT = {
    retail = {
        DUNGEONS = G.DUNGEONS, RAIDS = G.RAIDS, INSTANCES = G.INSTANCES, ARENAS = G.ARENAS,
        HIDDEN_CONTENT = {}, HIDDEN_ROWS = {}, HIDDEN_TOKENS = {}, SKIP_BUILTINS = {}, BUILTIN_WHEN = {},
        BATTLEGROUND_SETS = nil,
    },
    forever = {
        DUNGEONS = FOREVER_DUNGEONS, RAIDS = FOREVER_RAIDS,
        INSTANCES = concat(FOREVER_DUNGEONS, FOREVER_RAIDS),
        ARENAS = {},
        HIDDEN_CONTENT = set({ "mythicPlus", "delve", "scenario", "arena", "housing" }),
        HIDDEN_ROWS = set({ "difficulty", "keyLevel", "arena" }),
        HIDDEN_TOKENS = set({ "{dungeon}", "{key}" }),
        -- the Arena set (Claude's call C3)
        SKIP_BUILTINS = set({ "bi.arena" }),
        -- the Dungeon set (bi.mplus) matches the content kind dungeon alone: Forever has no Mythic+ and
        -- no key level (the lead's call C7)
        BUILTIN_WHEN = { ["bi.mplus"] = { content = { dungeon = true } } },
        -- Warsong Gulch, Arathi Basin and Alterac Valley, with the ids and callouts Retail's sets carry
        BATTLEGROUND_SETS = set({ "wsg", "ab", "av" }),
    },
}

-- Every name a client's table sets, so a pick replaces the other client's whole (Retail's
-- BATTLEGROUND_SETS is nil).
local KEYS = { "DUNGEONS", "RAIDS", "INSTANCES", "ARENAS", "HIDDEN_CONTENT", "HIDDEN_ROWS", "HIDDEN_TOKENS",
    "SKIP_BUILTINS", "BUILTIN_WHEN", "BATTLEGROUND_SETS" }

--- Put client `key`'s data ("retail" | "forever"; anything else is Retail) under the names every
--- reader uses. Called once below. The headless harness calls it once more after a load, with
--- "retail", so the suites that pin Retail's seeds run alike under both kit profiles; a case that
--- pins the client's own data opts out (tests/run.lua, `clientData`).
function G.UseClient(key)
    G.CLIENT = G.BY_CLIENT[key] and key or "retail"
    local pick = G.BY_CLIENT[G.CLIENT]
    for _, name in ipairs(KEYS) do G[name] = pick[name] end
end

G.UseClient(NS.Compat.ClientKey())
