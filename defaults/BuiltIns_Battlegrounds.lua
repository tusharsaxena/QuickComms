local _, NS = ...
-- defaults/BuiltIns_Battlegrounds.lua — the generic battleground set and one set per
-- battleground (spec §12). Faction-neutral wording (D11). Matched on instanceID (the client's Map
-- id); every id below is a battleground map in the client's own Map table (build 12.1.5.70340,
-- matched by tools/derive-gameids.py and tests/test_gameids.lua); in-game confirmation is smoke check
-- BG-2. Node
-- battlegrounds nest one ring per node with INC 1/2/3/Many/Clear/Help and open into their ring.
-- The generic set is declared last, below every per-battleground set.

local BI, L = NS.BuiltIns, NS.L
local BG = { content = "battleground", group = "raid", instanceGroup = true, lockdown = { pvpMatch = true } }

local INC = {
    { "inc1",  L["INC 1"],    L["INC 1 %s"] },
    { "inc2",  L["INC 2"],    L["INC 2 %s"] },
    { "inc3",  L["INC 3"],    L["INC 3 %s"] },
    { "many",  L["INC many"], L["INC many %s"] },
    { "clear", L["Clear"],    L["%s is clear"] },
    { "help",  L["Help"],     L["Need help at %s"] },
}

local function idSet(ids)
    local set = {}
    for _, id in ipairs(ids) do set[id] = true end
    return set
end

-- A battleground whose callouts are one ring per node.
local function nodeBattleground(key, name, ids, nodes)
    local id = "bi.bg." .. key
    local children = {}
    for n, node in ipairs(nodes) do
        local nodeId = id .. "." .. node[1]
        local rows = {}
        for i, r in ipairs(INC) do rows[i] = { r[1], r[2], r[3]:format(node[2]) } end
        BI.Group(nodeId, { name = node[2], parent = id, callouts = BI.Callouts(nodeId, "smartGroup", rows) })
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
    { "stables", L["Stables"] }, { "lumbermill", L["Lumber Mill"] }, { "blacksmith", L["Blacksmith"] },
    { "mine", L["Gold Mine"] }, { "farm", L["Farm"] },
})
nodeBattleground("eots", L["Eye of the Storm"], { 566, 968 }, {
    { "felreaver", L["Fel Reaver Ruins"] }, { "bloodelf", L["Blood Elf Tower"] },
    { "draenei", L["Draenei Ruins"] }, { "magetower", L["Mage Tower"] }, { "flag", L["the flag"] },
})
nodeBattleground("bfg", L["Battle for Gilneas"], { 761 }, {
    { "lighthouse", L["Lighthouse"] }, { "waterworks", L["Waterworks"] }, { "mines", L["Mines"] },
})
nodeBattleground("dwg", L["Deepwind Gorge"], { 1105, 2245 }, {
    { "market", L["Market"] }, { "farm", L["Farm"] }, { "quarry", L["Quarry"] },
})
nodeBattleground("ioc", L["Isle of Conquest"], { 628 }, {
    { "docks", L["Docks"] }, { "hangar", L["Hangar"] }, { "workshop", L["Workshop"] },
    { "quarry", L["Quarry"] }, { "refinery", L["Refinery"] },
})

flatBattleground("wsg", L["Warsong Gulch"], { 489, 2106 }, {
    { "efcmid",   L["EFC mid"],        L["EFC mid"] },
    { "efctun",   L["EFC tunnel"],     L["EFC in the tunnel"] },
    { "efcroof",  L["EFC roof"],       L["EFC on the roof"] },
    { "fcheals",  L["FC needs heals"], L["Our FC needs heals"] },
    { "killefc",  L["Kill EFC"],       L["Kill the EFC %t"] },
    { "fcsafe",   L["FC safe"],        L["FC is safe"] },
})
flatBattleground("tp", L["Twin Peaks"], { 726 }, {
    { "efcmid",   L["EFC mid"],        L["EFC mid"] },
    { "efcwater", L["EFC water"],      L["EFC in the water"] },
    { "fcheals",  L["FC needs heals"], L["Our FC needs heals"] },
    { "killefc",  L["Kill EFC"],       L["Kill the EFC %t"] },
    { "fcsafe",   L["FC safe"],        L["FC is safe"] },
})
flatBattleground("ssm", L["Silvershard Mines"], { 727 }, {
    { "escort",   L["Escort"],         L["Escort the cart"] },
    { "contest",  L["Contest"],        L["Contest the cart"] },
    { "help",     L["Cart help"],      L["Need help at a cart"] },
})
flatBattleground("tok", L["Temple of Kotmogu"], { 998 }, {
    { "heals",    L["Orb heals"],      L["Orb carrier needs heals"] },
    { "kill",     L["Kill orb"],       L["Kill orb carrier %t"] },
    { "mid",      L["Go mid"],         L["Orbs to the middle"] },
})
flatBattleground("ss", L["Seething Shore"], { 1803 }, {
    { "here",     L["Azerite here"],   L["Azerite spawning here"] },
    { "next",     L["Next node"],      L["Moving to the next node"] },
    { "help",     L["Need help"],      L["Need help at the azerite"] },
})
flatBattleground("dhr", L["Deephaul Ravine"], { 2656 }, {
    { "crystal",  L["Crystal"],        L["Need help at the crystal"] },
    { "cart",     L["Cart"],           L["Cart is moving"] },
    { "defend",   L["Defend"],         L["Defend the cart"] },
})
flatBattleground("av", L["Alterac Valley"], { 30 }, {
    { "general",  L["Defend general"], L["Defend our general"] },
    { "push",     L["Push general"],   L["Push the general"] },
    { "gy",       L["Graveyard"],      L["Take the graveyard"] },
    { "tower",    L["Tower"],          L["Tower under attack"] },
})
flatBattleground("ashran", L["Ashran"], { 1191 }, {
    { "road",     L["Road"],           L["Push the road"] },
    { "event",    L["Event"],          L["Event is up, go"] },
    { "regroup",  L["Regroup"],        L["Regroup at the base"] },
})
flatBattleground("wg", L["Wintergrasp"], { 2118 }, {
    { "walls",    L["Walls"],          L["Defend the walls"] },
    { "siege",    L["Siege"],          L["Siege engine incoming"] },
    { "workshop", L["Workshop"],       L["Take the workshop"] },
})

-- The generic set comes last (phase 4): a battleground's own set is then the first active group on a
-- default dial, so the dial opens straight on its nodes (D9). Migration step 2 moves it on stored
-- profiles (modules/Library.lua MoveGenericBattlegroundLast).
BI.Group("bi.bg", {
    name = L["Battleground (generic)"], icon = "Interface\\Icons\\Achievement_BG_winWSG",
    when = { content = { battleground = true } },
    callouts = BI.Callouts("bi.bg", "smartGroup", {
        { "help",    L["Need help"],  L["Need help here"] },
        { "inc",     L["INC"],        L["INC {rt8}"] },
        { "hold",    L["Hold"],       L["Hold this"] },
        { "capping", L["Capping"],    L["Capping"] },
        { "defend",  L["Defend"],     L["Defend"] },
        { "push",    L["Push"],       L["Push now"] },
    }),
})
BI.SNAPSHOTS["bi.bg"] = BG
