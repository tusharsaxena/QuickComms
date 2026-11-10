local _, NS = ...
-- defaults/GameIds_Clients.lua — the per-client game data (clients-§5; QFE-F3), picked once at load by
-- Compat.ClientKey(). DATA ONLY: ids and tokens, never a name (localization-§4). defaults/GameIds.lua
-- and defaults/GameIds_Instances.lua hold Retail's lists. This file keeps them as BY_CLIENT.retail,
-- holds WoW Forever's beside them, and puts the client's own under the names every reader uses
-- (G.DUNGEONS, G.RAIDS, G.INSTANCES, G.ARENAS), so no reader asks which client it is.
--   DUNGEONS, RAIDS     Preview as...'s lists: Retail's season, Forever's own dungeons and raids.
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
-- WoW Forever's ids are derived from Forever's own GroupFinderActivity and Map tables (build
-- 1.60.1.70862), joined on map id (the forever-ids design, D3-R and D5, QuickComms#21): each is a Map
-- row of its kind (its FOREVER_MAPS row in tests/test_gameids.lua), the dungeons are exactly the party
-- maps the group finder lists and the raids exactly its raid maps. tools/derive-gameids.py --forever
-- re-derives and checks them (docs/common-tasks.md). The in-game check is `/qc probe ids`. Darkspear
-- Islands, a battleground the group finder lists, gets no built-in set (the battleground kind still
-- matches it). Forever has no arena map, so no arena list (D4).

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
    189,  -- Scarlet Monastery (D1)
    129,  -- Razorfen Downs
    70,   -- Uldaman
    209,  -- Zul'Farrak
    349,  -- Maraudon
    109,  -- Sunken Temple
    230,  -- Blackrock Depths
    229,  -- Blackrock Spire (the group finder's Lower and Upper Blackrock Spire)
    429,  -- Dire Maul (the group finder's East, West and North)
    289,  -- Scholomance (D1)
    329,  -- Stratholme
    -- Forever's own dungeons, which its group finder lists (D2), by map id
    2959, -- City of Dalaran
    2970, -- The Drowned City
    2974, -- Blackmaw Hold
    2994, -- Alcaz Prison
    2998, -- Excavation Site: Wetlands
    2999, -- Ruins of Lordaeron
    3001, -- The Shaper's Terrace
    3039, -- Krol'dok Stronghold
    3065, -- The Hall of Thanes
    -- the other party maps the group finder lists (D3-R), in its order
    2784, -- Demon Fall Canyon
    2875, -- Karazhan Crypts
}

-- A new list of raids for Forever (owner ruling R1), by Forever's map ids.
local FOREVER_RAIDS = {
    409,  -- Molten Core
    249,  -- Onyxia's Lair
    469,  -- Blackwing Lair
    309,  -- Zul'Gurub (D1)
    509,  -- Ruins of Ahn'Qiraj
    531,  -- Temple of Ahn'Qiraj
    533,  -- Naxxramas
    -- the other raid maps the group finder lists (D3-R), in its order
    2791, -- Storm Cliffs
    2789, -- The Tainted Scar
    2804, -- The Crystal Vale
    2832, -- Nightmare Grove
    2856, -- Scarlet Enclave
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
