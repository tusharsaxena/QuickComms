local _, NS = ...
-- defaults/BuiltIns_Battlegrounds.lua — the generic battleground set and one set per
-- battleground (spec §12). Faction-neutral wording (D11). Matched on instanceID (the client's Map
-- id); every id below is a battleground map in the client's own Map table (build 12.1.5.70340,
-- matched by tools/derive-gameids.py and tests/test_gameids.lua); in-game confirmation is smoke check
-- BG-2. Node
-- battlegrounds nest one ring per node with INC 1/2/3/Many/Clear/Help and open into their ring, and
-- hold a few map-wide callouts of their own (groups polish), which take one wedge on the ring's first
-- free wind (modules/Dial_Layout.lua). Every set and node carries a catalog glyph named for it.
-- The generic set is declared last, below every per-battleground set.

local BI, L = NS.BuiltIns, NS.L
local C = BI.COLOR
local BG = { content = "battleground", group = "raid", instanceGroup = true, lockdown = { pvpMatch = true } }

local INC = {
    { "inc1",  L["INC 1"],    L["INC 1 %s"],        "gi:person",       C.orange },
    { "inc2",  L["INC 2"],    L["INC 2 %s"],        "gi:two-shadows",  C.orange },
    { "inc3",  L["INC 3"],    L["INC 3 %s"],        "gi:three-friends", C.orange },
    { "many",  L["INC many"], L["INC many %s"],     "gi:meeple-army",  C.red },
    { "clear", L["Clear"],    L["%s is clear"],     "gi:check-mark",   C.green },
    { "help",  L["Help"],     L["Need help at %s"], "gi:megaphone",    C.orange },
}

local function idSet(ids)
    local set = {}
    for _, id in ipairs(ids) do set[id] = true end
    return set
end

-- The map-wide callouts a base-capture battleground holds besides its nodes' rings.
local BASES = {
    { "hold",   L["Hold our bases"], L["Hold what we have, defend our bases"], "gi:checked-shield", C.blue },
    { "zerg",   L["Zerg next"],      L["Zerg the next base together"], "gi:meeple-army", C.red },
    { "ninja",  L["Ninja a base"],   L["Ninja an open base, it is unguarded"], "gi:hooded-assassin", C.purple },
    { "rotate", L["Rotate"],         L["Rotate to the base under attack"], "gi:cycle", C.orange },
    { "ahead",  L["We're ahead"],    L["We're ahead on points, play it safe"], "gi:podium-winner", C.gold },
}

-- A battleground whose callouts are one ring per node, plus its own map-wide `rows` (the same shape as
-- a flat battleground's). Each node is { key, name, wind, glyph, color }: the wind is
-- the node's compass direction on the map (N, NE … NW, or "middle"), which pins its wedge on the dial
-- (spec §12.1; modules/Dial_Layout.lua PinNodes). The winds are derived from the client's own AreaPOI
-- table (build 12.1.5.70340, via wago.tools, 2026-10-13) by tools/derive-winds.py, which also checks
-- the lists below: each node's map position against the center of the battleground's nodes, north up;
-- a node within a third of the farthest node's distance from that center is the middle. Smoke check
-- BG-1 confirms them in game. The glyph and color are the node's icon.
local function nodeBattleground(key, name, icon, ids, nodes, rows)
    local id = "bi.bg." .. key
    local children = {}
    for n, node in ipairs(nodes) do
        local nodeId = id .. "." .. node[1]
        local inc = {}
        for i, r in ipairs(INC) do inc[i] = { r[1], r[2], r[3]:format(node[2]), r[4], r[5] } end
        BI.Group(nodeId, { name = node[2], parent = id, compass = node[3], glyph = node[4], color = node[5],
            callouts = BI.Callouts(nodeId, "smartGroup", inc) })
        children[n] = nodeId
    end
    BI.Group(id, { name = name, glyph = icon[1], color = icon[2], openInto = true, children = children,
        when = { content = { battleground = true }, battleground = idSet(ids) },
        callouts = BI.Callouts(id, "smartGroup", rows) })
    BI.SNAPSHOTS[id] = BG
end

-- A battleground with a flat list of callouts; `icon` is { glyph, color }.
local function flatBattleground(key, name, icon, ids, rows)
    local id = "bi.bg." .. key
    BI.Group(id, { name = name, glyph = icon[1], color = icon[2],
        when = { content = { battleground = true }, battleground = idSet(ids) },
        callouts = BI.Callouts(id, "smartGroup", rows) })
    BI.SNAPSHOTS[id] = BG
end

nodeBattleground("ab", L["Arathi Basin"], { "gi:wheat", C.gold }, { 529, 2107, 1681 }, {
    { "stables", L["Stables"], "NW", "gi:horse-head-lorc", C.white },
    { "lumbermill", L["Lumber Mill"], "SW", "gi:wood-axe", C.green },
    { "blacksmith", L["Blacksmith"], "middle", "gi:anvil", C.orange },
    { "mine", L["Gold Mine"], "NE", "gi:gold-mine", C.gold },
    { "farm", L["Farm"], "SE", "gi:barn", C.red },
}, BASES)
nodeBattleground("eots", L["Eye of the Storm"], { "gi:tornado", C.purple }, { 566, 968 }, {
    { "felreaver", L["Fel Reaver Ruins"], "SW", "gi:castle-ruins", C.green },
    { "bloodelf", L["Blood Elf Tower"], "SE", "gi:tower-flag", C.red },
    { "draenei", L["Draenei Ruins"], "NE", "gi:crystal-growth", C.purple },
    { "magetower", L["Mage Tower"], "NW", "gi:wizard-staff", C.blue },
    { "flag", L["the flag"], "middle", "gi:flying-flag", C.gold },
}, {
    BASES[1], BASES[2], BASES[3],
    { "flagcap", L["Cap the flag"],  L["Take the flag to a tower we hold"], "gi:flying-flag", C.gold },
    { "flagkill", L["Kill the EFC"], L["Kill their flag carrier %t"], "gi:bloody-sword", C.red },
})
nodeBattleground("bfg", L["Battle for Gilneas"], { "gi:wolf-howl", C.blue }, { 761 }, {
    { "lighthouse", L["Lighthouse"], "W", "gi:lighthouse", C.gold },
    { "waterworks", L["Waterworks"], "SE", "gi:water-mill", C.blue },
    { "mines", L["Mines"], "NE", "gi:mining", C.orange },
}, BASES)
-- Deepwind Gorge has five nodes on its current map (2245): Shrine and Ruins joined Market, Farm and
-- Quarry (the client's AreaPOI table, as above).
nodeBattleground("dwg", L["Deepwind Gorge"], { "gi:whirlwind", C.cyan }, { 1105, 2245 }, {
    { "market", L["Market"], "middle", "gi:shop", C.gold },
    { "farm", L["Farm"], "NE", "gi:wheat", C.green },
    { "quarry", L["Quarry"], "NW", "gi:stone-block", C.white },
    { "shrine", L["Shrine"], "SE", "gi:shinto-shrine", C.red },
    { "ruins", L["Ruins"], "SW", "gi:ancient-ruins", C.purple },
}, BASES)
nodeBattleground("ioc", L["Isle of Conquest"], { "gi:siege-tower", C.red }, { 628 }, {
    { "docks", L["Docks"], "W", "gi:anchor", C.blue },
    { "hangar", L["Hangar"], "E", "gi:airplane", C.white },
    { "workshop", L["Workshop"], "middle", "gi:gear-hammer", C.orange },
    { "quarry", L["Quarry"], "SE", "gi:stone-pile", C.white },
    { "refinery", L["Refinery"], "NW", "gi:oil-drum", C.gold },
}, {
    { "siege",    L["Siege engine"], L["Escort our siege engine"], "gi:siege-ram", C.orange },
    { "gates",    L["Gate down"],    L["Their gate is down, push in"], "gi:broken-wall", C.red },
    { "vehicles", L["Vehicles"],     L["Grab the vehicles at the workshop"], "gi:catapult", C.gold },
    { "boss",     L["Push boss"],    L["Everyone push their boss"], "gi:crowned-skull", C.red },
    { "defgate",  L["Defend gate"],  L["Defend our gate, they are on it"], "gi:stone-wall", C.blue },
})

flatBattleground("wsg", L["Warsong Gulch"], { "gi:tusks-flag", C.red }, { 489, 2106 }, {
    { "efcmid",   L["EFC mid"],        L["EFC mid"], "gi:flying-flag", C.orange },
    { "efctun",   L["EFC tunnel"],     L["EFC in the tunnel"], "gi:flying-flag", C.orange },
    { "efcroof",  L["EFC roof"],       L["EFC on the roof"], "gi:flying-flag", C.orange },
    { "fcheals",  L["FC needs heals"], L["Our FC needs heals"], "gi:heart-plus", C.green },
    { "killefc",  L["Kill EFC"],       L["Kill the EFC %t"], "gi:bloody-sword", C.red },
    { "fcsafe",   L["FC safe"],        L["FC is safe"], "gi:checked-shield", C.green },
})
flatBattleground("tp", L["Twin Peaks"], { "gi:peaks", C.green }, { 726 }, {
    { "efcmid",   L["EFC mid"],        L["EFC mid"], "gi:flying-flag", C.orange },
    { "efcwater", L["EFC water"],      L["EFC in the water"], "gi:water-splash", C.blue },
    { "fcheals",  L["FC needs heals"], L["Our FC needs heals"], "gi:heart-plus", C.green },
    { "killefc",  L["Kill EFC"],       L["Kill the EFC %t"], "gi:bloody-sword", C.red },
    { "fcsafe",   L["FC safe"],        L["FC is safe"], "gi:checked-shield", C.green },
})
flatBattleground("ssm", L["Silvershard Mines"], { "gi:mine-wagon", C.gold }, { 727 }, {
    { "escort",   L["Escort"],         L["Escort the cart"], "gi:mine-wagon", C.blue },
    { "contest",  L["Contest"],        L["Contest the cart"], "gi:crossed-swords", C.red },
    { "help",     L["Cart help"],      L["Need help at a cart"], "gi:megaphone", C.orange },
})
flatBattleground("tok", L["Temple of Kotmogu"], { "gi:crystal-ball", C.purple }, { 998 }, {
    { "heals",    L["Orb heals"],      L["Orb carrier needs heals"], "gi:heart-plus", C.green },
    { "kill",     L["Kill orb"],       L["Kill orb carrier %t"], "gi:bloody-sword", C.red },
    { "mid",      L["Go mid"],         L["Orbs to the middle"], "gi:orb-direction", C.cyan },
})
flatBattleground("ss", L["Seething Shore"], { "gi:wave-crest", C.blue }, { 1803 }, {
    { "here",     L["Azerite here"],   L["Azerite spawning here"], "gi:crystal-cluster", C.gold },
    { "next",     L["Next node"],      L["Moving to the next node"], "gi:sprint", C.cyan },
    { "help",     L["Need help"],      L["Need help at the azerite"], "gi:megaphone", C.orange },
})
flatBattleground("dhr", L["Deephaul Ravine"], { "gi:cave-entrance", C.orange }, { 2656 }, {
    { "crystal",  L["Crystal"],        L["Need help at the crystal"], "gi:crystal-shine", C.purple },
    { "cart",     L["Cart"],           L["Cart is moving"], "gi:mine-truck", C.gold },
    { "defend",   L["Defend"],         L["Defend the cart"], "gi:checked-shield", C.blue },
})
flatBattleground("av", L["Alterac Valley"], { "gi:snowflake-2", C.blue }, { 30 }, {
    { "general",  L["Defend general"], L["Defend our general"], "gi:king", C.gold },
    { "push",     L["Push general"],   L["Push the general"], "gi:rally-the-troops", C.red },
    { "gy",       L["Graveyard"],      L["Take the graveyard"], "gi:graveyard", C.white },
    { "tower",    L["Tower"],          L["Tower under attack"], "gi:watchtower", C.orange },
})
flatBattleground("ashran", L["Ashran"], { "gi:sword-clash", C.red }, { 1191 }, {
    { "road",     L["Road"],           L["Push the road"], "gi:road", C.cyan },
    { "event",    L["Event"],          L["Event is up, go"], "gi:ringing-bell", C.gold },
    { "regroup",  L["Regroup"],        L["Regroup at the base"], "gi:campfire", C.orange },
})
flatBattleground("wg", L["Wintergrasp"], { "gi:frozen-orb", C.cyan }, { 2118 }, {
    { "walls",    L["Walls"],          L["Defend the walls"], "gi:stone-wall", C.blue },
    { "siege",    L["Siege"],          L["Siege engine incoming"], "gi:siege-ram", C.orange },
    { "workshop", L["Workshop"],       L["Take the workshop"], "gi:anvil", C.white },
})

-- The generic set comes last (phase 4): a battleground's own set is then the first active group on a
-- default dial, so the dial opens straight on its nodes (D9). Migration step 2 moves it on stored
-- profiles (modules/Library.lua MoveGenericBattlegroundLast).
BI.Group("bi.bg", {
    name = L["Battleground (generic)"], glyph = "gi:flag-objective", color = C.gold,
    when = { content = { battleground = true } },
    callouts = BI.Callouts("bi.bg", "smartGroup", {
        { "help",    L["Need help"],  L["Need help here"], "gi:megaphone", C.orange },
        { "inc",     L["INC"],        L["INC {rt8}"], "gi:charging", C.red },
        { "hold",    L["Hold"],       L["Hold this"], "gi:guarded-tower", C.blue },
        { "capping", L["Capping"],    L["Capping"], "gi:flying-flag", C.gold },
        { "defend",  L["Defend"],     L["Defend"], "gi:checked-shield", C.blue },
        { "push",    L["Push"],       L["Push now"], "gi:rally-the-troops", C.red },
    }),
})
BI.SNAPSHOTS["bi.bg"] = BG
