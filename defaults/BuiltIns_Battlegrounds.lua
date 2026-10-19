local _, NS = ...
-- defaults/BuiltIns_Battlegrounds.lua — the generic battleground set and one set per
-- battleground (spec §12). Faction-neutral wording (D11). Matched on instanceID (the client's Map
-- id); every id below is a battleground map in the client's own Map table (build 12.1.5.70340,
-- matched by tools/derive-gameids.py and tests/test_gameids.lua); in-game confirmation is smoke check
-- BG-2. Node
-- battlegrounds nest one ring per node with INC 1/2/3/Many/Clear/Help and open into their ring.
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

-- A battleground whose callouts are one ring per node. Each node is { key, name, wind }: the wind is
-- the node's compass direction on the map (N, NE … NW, or "middle"), which pins its wedge on the dial
-- (spec §12.1; modules/Dial_Layout.lua PinNodes). The winds are derived from the client's own AreaPOI
-- table (build 12.1.5.70340, via wago.tools, 2026-10-13) by tools/derive-winds.py, which also checks
-- the lists below: each node's map position against the center of the battleground's nodes, north up;
-- a node within a third of the farthest node's distance from that center is the middle. Smoke check
-- BG-1 confirms them in game.
local function nodeBattleground(key, name, ids, nodes)
    local id = "bi.bg." .. key
    local children = {}
    for n, node in ipairs(nodes) do
        local nodeId = id .. "." .. node[1]
        local rows = {}
        for i, r in ipairs(INC) do rows[i] = { r[1], r[2], r[3]:format(node[2]), r[4], r[5] } end
        BI.Group(nodeId, { name = node[2], parent = id, compass = node[3],
            callouts = BI.Callouts(nodeId, "smartGroup", rows) })
        children[n] = nodeId
    end
    BI.Group(id, { name = name, openInto = true, children = children,
        when = { content = { battleground = true }, battleground = idSet(ids) } })
    BI.SNAPSHOTS[id] = BG
end

-- A battleground with a flat list of callouts.
local function flatBattleground(key, name, ids, rows)
    local id = "bi.bg." .. key
    BI.Group(id, { name = name, when = { content = { battleground = true }, battleground = idSet(ids) },
        callouts = BI.Callouts(id, "smartGroup", rows) })
    BI.SNAPSHOTS[id] = BG
end

nodeBattleground("ab", L["Arathi Basin"], { 529, 2107, 1681 }, {
    { "stables", L["Stables"], "NW" }, { "lumbermill", L["Lumber Mill"], "SW" },
    { "blacksmith", L["Blacksmith"], "middle" }, { "mine", L["Gold Mine"], "NE" }, { "farm", L["Farm"], "SE" },
})
nodeBattleground("eots", L["Eye of the Storm"], { 566, 968 }, {
    { "felreaver", L["Fel Reaver Ruins"], "SW" }, { "bloodelf", L["Blood Elf Tower"], "SE" },
    { "draenei", L["Draenei Ruins"], "NE" }, { "magetower", L["Mage Tower"], "NW" }, { "flag", L["the flag"], "middle" },
})
nodeBattleground("bfg", L["Battle for Gilneas"], { 761 }, {
    { "lighthouse", L["Lighthouse"], "W" }, { "waterworks", L["Waterworks"], "SE" }, { "mines", L["Mines"], "NE" },
})
-- Deepwind Gorge has five nodes on its current map (2245): Shrine and Ruins joined Market, Farm and
-- Quarry (the client's AreaPOI table, as above).
nodeBattleground("dwg", L["Deepwind Gorge"], { 1105, 2245 }, {
    { "market", L["Market"], "middle" }, { "farm", L["Farm"], "NE" }, { "quarry", L["Quarry"], "NW" },
    { "shrine", L["Shrine"], "SE" }, { "ruins", L["Ruins"], "SW" },
})
nodeBattleground("ioc", L["Isle of Conquest"], { 628 }, {
    { "docks", L["Docks"], "W" }, { "hangar", L["Hangar"], "E" }, { "workshop", L["Workshop"], "middle" },
    { "quarry", L["Quarry"], "SE" }, { "refinery", L["Refinery"], "NW" },
})

flatBattleground("wsg", L["Warsong Gulch"], { 489, 2106 }, {
    { "efcmid",   L["EFC mid"],        L["EFC mid"], "gi:flying-flag" },
    { "efctun",   L["EFC tunnel"],     L["EFC in the tunnel"], "gi:flying-flag" },
    { "efcroof",  L["EFC roof"],       L["EFC on the roof"], "gi:flying-flag" },
    { "fcheals",  L["FC needs heals"], L["Our FC needs heals"], "gi:heart-plus", C.green },
    { "killefc",  L["Kill EFC"],       L["Kill the EFC %t"], "gi:bloody-sword", C.red },
    { "fcsafe",   L["FC safe"],        L["FC is safe"], "gi:checked-shield", C.green },
})
flatBattleground("tp", L["Twin Peaks"], { 726 }, {
    { "efcmid",   L["EFC mid"],        L["EFC mid"], "gi:flying-flag" },
    { "efcwater", L["EFC water"],      L["EFC in the water"], "gi:water-splash", C.blue },
    { "fcheals",  L["FC needs heals"], L["Our FC needs heals"], "gi:heart-plus", C.green },
    { "killefc",  L["Kill EFC"],       L["Kill the EFC %t"], "gi:bloody-sword", C.red },
    { "fcsafe",   L["FC safe"],        L["FC is safe"], "gi:checked-shield", C.green },
})
flatBattleground("ssm", L["Silvershard Mines"], { 727 }, {
    { "escort",   L["Escort"],         L["Escort the cart"], "gi:mine-wagon" },
    { "contest",  L["Contest"],        L["Contest the cart"], "gi:crossed-swords" },
    { "help",     L["Cart help"],      L["Need help at a cart"], "gi:megaphone", C.orange },
})
flatBattleground("tok", L["Temple of Kotmogu"], { 998 }, {
    { "heals",    L["Orb heals"],      L["Orb carrier needs heals"], "gi:heart-plus", C.green },
    { "kill",     L["Kill orb"],       L["Kill orb carrier %t"], "gi:bloody-sword", C.red },
    { "mid",      L["Go mid"],         L["Orbs to the middle"], "gi:orb-direction" },
})
flatBattleground("ss", L["Seething Shore"], { 1803 }, {
    { "here",     L["Azerite here"],   L["Azerite spawning here"], "gi:crystal-cluster" },
    { "next",     L["Next node"],      L["Moving to the next node"], "gi:sprint" },
    { "help",     L["Need help"],      L["Need help at the azerite"], "gi:megaphone", C.orange },
})
flatBattleground("dhr", L["Deephaul Ravine"], { 2656 }, {
    { "crystal",  L["Crystal"],        L["Need help at the crystal"], "gi:crystal-shine" },
    { "cart",     L["Cart"],           L["Cart is moving"], "gi:mine-truck" },
    { "defend",   L["Defend"],         L["Defend the cart"], "gi:checked-shield" },
})
flatBattleground("av", L["Alterac Valley"], { 30 }, {
    { "general",  L["Defend general"], L["Defend our general"], "gi:king" },
    { "push",     L["Push general"],   L["Push the general"], "gi:rally-the-troops" },
    { "gy",       L["Graveyard"],      L["Take the graveyard"], "gi:graveyard" },
    { "tower",    L["Tower"],          L["Tower under attack"], "gi:watchtower" },
})
flatBattleground("ashran", L["Ashran"], { 1191 }, {
    { "road",     L["Road"],           L["Push the road"], "gi:road" },
    { "event",    L["Event"],          L["Event is up, go"], "gi:ringing-bell" },
    { "regroup",  L["Regroup"],        L["Regroup at the base"], "gi:campfire" },
})
flatBattleground("wg", L["Wintergrasp"], { 2118 }, {
    { "walls",    L["Walls"],          L["Defend the walls"], "gi:stone-wall" },
    { "siege",    L["Siege"],          L["Siege engine incoming"], "gi:siege-ram" },
    { "workshop", L["Workshop"],       L["Take the workshop"], "gi:anvil" },
})

-- The generic set comes last (phase 4): a battleground's own set is then the first active group on a
-- default dial, so the dial opens straight on its nodes (D9). Migration step 2 moves it on stored
-- profiles (modules/Library.lua MoveGenericBattlegroundLast).
BI.Group("bi.bg", {
    name = L["Battleground (generic)"], icon = "Interface\\Icons\\Achievement_BG_winWSG",
    when = { content = { battleground = true } },
    callouts = BI.Callouts("bi.bg", "smartGroup", {
        { "help",    L["Need help"],  L["Need help here"], "gi:megaphone", C.orange },
        { "inc",     L["INC"],        L["INC {rt8}"], "gi:charging", C.red },
        { "hold",    L["Hold"],       L["Hold this"], "gi:guarded-tower" },
        { "capping", L["Capping"],    L["Capping"], "gi:flying-flag" },
        { "defend",  L["Defend"],     L["Defend"], "gi:checked-shield" },
        { "push",    L["Push"],       L["Push now"], "gi:rally-the-troops" },
    }),
})
BI.SNAPSHOTS["bi.bg"] = BG
