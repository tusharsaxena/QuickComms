-- tests/test_gameids.lua — the shipped instance ids (spec §12.1, §13.2: "phase 5 confirms their
-- instance IDs"), matched against the client's own data. CLIENT_MAPS below is an EXTRACTION, not
-- authored data: the Map table's InstanceType (1 party, 2 raid, 3 battleground) and whether a
-- MapChallengeMode row names the map (a Mythic+ dungeon), for every id defaults/ ships, as exported
-- from client build 12.1.5.70340 by wago.tools on 2026-10-13. tools/derive-gameids.py re-derives
-- every row from those tables and fails on any difference, so an id typed wrong here and in defaults/
-- alike is still caught (docs/common-tasks.md says how to run it). Adding an id to defaults/ means
-- adding its row here and running the generator; smoke checks BG-2 and IDS-1 confirm the ids in game.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local PARTY, RAID, PVP = 1, 2, 3

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
