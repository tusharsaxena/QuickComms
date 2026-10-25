local _, NS = ...
-- defaults/BuiltIns_Battlegrounds.lua — the generic battleground set and one set per
-- battleground (spec §12). Faction-neutral wording (D11). Matched on instanceID (the client's Map
-- id); every id below is a battleground map in the client's own Map table (build 12.1.5.70340,
-- matched by tools/derive-gameids.py and tests/test_gameids.lua); in-game confirmation is smoke check
-- BG-2. Node
-- battlegrounds nest one ring per node with Attack/Defend/INC/Clear (bg buttons, 2026-10-20: the four
-- Wintergrasp's workshops had, in place of INC 1/2/3/Many/Clear/Help) and open into their ring, and
-- hold a few map-wide callouts of their own (groups polish), which take one wedge, first on the ring
-- (modules/Dial_Layout.lua). Every set and node carries a catalog glyph named for it.
-- Objective battlegrounds (bg subgroups, 2026-10-20) nest one ring per objective too, each with its own
-- callout rows: Alterac Valley's generals, captains, bunkers, towers and graveyards (Attack and Defend
-- each), the flag maps' flags, carrier and middle, and Wintergrasp's, Ashran's, Deephaul Ravine's and
-- Seething Shore's objectives, Silvershard Mines' tracks and switches and Temple of Kotmogu's
-- orbs and center (bg buttons). Every callout reads the same for either faction (owner ruling: our and
-- enemy base, our and enemy flag carrier; no faction condition).
-- The generic set is declared last, below every per-battleground set.

local BI, L = NS.BuiltIns, NS.L
local C = BI.COLOR
local BG = { content = "battleground", group = "raid", instanceGroup = true, lockdown = { pvpMatch = true } }

-- A node's or objective's four callouts (bg buttons, 2026-10-20): short names, since the section
-- title names the node; the message names it ("Attack Stables", "Stables is clear"). Every base-capture
-- node and Wintergrasp's workshops take them.
local NODE = {
    { "attack", L["Attack"], L["Attack %s"],   "gi:crossed-swords", C.crimson },
    { "defend", L["Defend"], L["Defend %s"],   "gi:checked-shield", C.cyan },
    { "inc",    L["INC"],    L["INC %s"],      "gi:charging",       C.orange },
    { "clear",  L["Clear"],  L["%s is clear"], "gi:check-mark",     C.green },
}

local function idSet(ids)
    local set = {}
    for _, id in ipairs(ids) do set[id] = true end
    return set
end

-- The map-wide callouts a base-capture battleground holds besides its nodes' rings.
local BASES = {
    { "hold",   L["Hold our bases"], L["Hold what we have, defend our bases"], "gi:checked-shield", C.cyan },
    { "zerg",   L["Zerg next"],      L["Zerg the next base together"], "gi:meeple-army", C.red },
    { "ninja",  L["Ninja a base"],   L["Ninja an open base, it is unguarded"], "gi:hooded-assassin", C.purple },
    { "rotate", L["Rotate"],         L["Rotate to the base under attack"], "gi:cycle", C.orange },
    { "ahead",  L["We're ahead"],    L["We're ahead on points, play it safe"], "gi:podium-winner", C.gold },
}

-- Callout rows with `what` put into each one's text: the four rows for a node, the Attack and Defend
-- rows for an objective, a track's or an orb's. Only the %s is filled, so a chip ({target}) is left
-- for the bake.
local function rowsFor(template, what)
    local out, plain = {}, (what:gsub("%%", "%%%%"))
    for i, r in ipairs(template) do out[i] = { r[1], r[2], (r[3]:gsub("%%s", plain)), r[4], r[5] } end
    return out
end

-- An Alterac Valley objective's two callouts: short names, since the section title names the
-- objective; the message names it in full ("Attack Iceblood Tower").
local OBJECTIVE = {
    { "attack", L["Attack"], L["Attack %s"], "gi:crossed-swords", C.crimson },
    { "defend", L["Defend"], L["Defend %s"], "gi:checked-shield", C.cyan },
}
local function objective(fullName) return rowsFor(OBJECTIVE, fullName) end

-- A battleground whose callouts are one ring per node, plus its own map-wide `rows` (the same shape as
-- a flat battleground's). Each node is { key, name, glyph, color[, rows] }: the glyph and color are the
-- node's icon. A node's callouts are the four NODE rows named for it, unless it carries its own `rows`
-- (an objective's, bg subgroups). The dial places the nodes like any ring's items, A-Z by name (owner,
-- 2026-10-25: until then each node carried its compass wind, derived from the client's AreaPOI table,
-- which pinned its wedge on an eight-wedge ring).
local function nodeBattleground(key, name, icon, ids, nodes, rows)
    local id = "bi.bg." .. key
    local children = {}
    for n, node in ipairs(nodes) do
        local nodeId = id .. "." .. node[1]
        BI.Group(nodeId, { name = node[2], parent = id, glyph = node[3], color = node[4],
            callouts = BI.Callouts(nodeId, "smartGroup", node[5] or rowsFor(NODE, node[2])) })
        children[n] = nodeId
    end
    BI.Group(id, { name = name, glyph = icon[1], color = icon[2], children = children,
        when = { content = { battleground = true }, battleground = idSet(ids) },
        callouts = BI.Callouts(id, "smartGroup", rows) })
    BI.SNAPSHOTS[id] = BG
end

nodeBattleground("ab", L["Arathi Basin"], { "gi:wheat", C.gold }, { 529, 2107, 1681 }, {
    { "stables", L["Stables"], "gi:horse-head-lorc", C.brown },
    { "lumbermill", L["Lumber Mill"], "gi:wood-axe", C.green },
    { "blacksmith", L["Blacksmith"], "gi:anvil", C.orange },
    { "mine", L["Gold Mine"], "gi:gold-mine", C.gold },
    { "farm", L["Farm"], "gi:barn", C.red },
}, BASES)
nodeBattleground("eots", L["Eye of the Storm"], { "gi:tornado", C.purple }, { 566, 968 }, {
    { "felreaver", L["Fel Reaver Ruins"], "gi:castle-ruins", C.neutral },
    { "bloodelf", L["Blood Elf Tower"], "gi:tower-flag", C.horde },
    { "draenei", L["Draenei Ruins"], "gi:crystal-growth", C.alliance },
    { "magetower", L["Mage Tower"], "gi:wizard-staff", C.neutral },
    -- The flag in the middle is no base: its four rows say what a flag wants.
    { "flag", L["Flag"], "gi:flying-flag", C.gold, {
        { "attack", L["Take flag"],   L["Take the flag"],     "gi:crossed-swords", C.crimson },
        { "defend", L["Defend flag"], L["Defend the flag"],   "gi:checked-shield", C.cyan },
        { "inc",    L["INC"],         L["INC the flag"],      "gi:charging",       C.orange },
        { "clear",  L["Clear"],       L["The flag is clear"], "gi:check-mark",     C.green },
    } },
}, {
    BASES[1], BASES[2], BASES[3],
    { "flagcap", L["Cap the flag"],  L["Take the flag to a tower we hold"], "gi:flying-flag", C.gold },
    { "flagkill", L["Kill the EFC"], L["Kill their flag carrier {target}"], "gi:bloody-sword", C.red },
})
nodeBattleground("bfg", L["Battle for Gilneas"], { "gi:wolf-howl", C.blue }, { 761 }, {
    { "lighthouse", L["Lighthouse"], "gi:lighthouse", C.gold },
    { "waterworks", L["Waterworks"], "gi:water-mill", C.blue },
    { "mines", L["Mines"], "gi:mining", C.orange },
}, BASES)
-- Deepwind Gorge has five nodes on its current map (2245): Shrine and Ruins joined Market, Farm and
-- Quarry (the client's AreaPOI table, as above).
nodeBattleground("dwg", L["Deepwind Gorge"], { "gi:whirlwind", C.cyan }, { 1105, 2245 }, {
    { "market", L["Market"], "gi:shop", C.gold },
    { "farm", L["Farm"], "gi:wheat", C.green },
    { "quarry", L["Quarry"], "gi:stone-block", C.stone },
    { "shrine", L["Shrine"], "gi:shinto-shrine", C.red },
    { "ruins", L["Ruins"], "gi:ancient-ruins", C.purple },
}, BASES)
nodeBattleground("ioc", L["Isle of Conquest"], { "gi:siege-tower", C.red }, { 628 }, {
    { "docks", L["Docks"], "gi:anchor", C.blue },
    { "hangar", L["Hangar"], "gi:airplane", C.sky },
    { "workshop", L["Workshop"], "gi:gear-hammer", C.orange },
    { "quarry", L["Quarry"], "gi:stone-pile", C.stone },
    { "refinery", L["Refinery"], "gi:oil-drum", C.gold },
    -- The two bases take the same four buttons, worded for whose base it is.
    { "base", L["Our base"], "gi:castle-lorc", C.blue, {
        { "attack", L["Attack"], L["Fight at our base"],  "gi:crossed-swords", C.crimson },
        { "defend", L["Defend"], L["Defend our base"],    "gi:checked-shield", C.cyan },
        { "inc",    L["INC"],    L["INC our base"],       "gi:charging",       C.orange },
        { "clear",  L["Clear"],  L["Our base is clear"],  "gi:check-mark",     C.green },
    } },
    { "enemybase", L["Enemy base"], "gi:castle-delapouite", C.red, {
        { "attack", L["Attack"], L["Attack the enemy base"],      "gi:crossed-swords", C.crimson },
        { "defend", L["Defend"], L["Hold the enemy base"],        "gi:checked-shield", C.cyan },
        { "inc",    L["INC"],    L["INC at the enemy base"],      "gi:charging",       C.orange },
        { "clear",  L["Clear"],  L["The enemy base is clear"],    "gi:check-mark",     C.green },
    } },
}, {
    { "siege",    L["Siege engine"], L["Escort our siege engine"], "gi:siege-ram", C.orange },
    { "gates",    L["Gate down"],    L["Their gate is down, push in"], "gi:broken-wall", C.red },
    { "vehicles", L["Vehicles"],     L["Grab the vehicles at the workshop"], "gi:catapult", C.gold },
    { "boss",     L["Push boss"],    L["Everyone push their boss"], "gi:crowned-skull", C.red },
    { "defgate",  L["Defend gate"],  L["Defend our gate, they are on it"], "gi:stone-wall", C.blue },
})

-- A flag map's children (Warsong Gulch, Twin Peaks): our flag, their flag, our carrier and the middle,
-- which `mid` names ({ title, its "INC" form, "Push", "clear", "Help", and a fifth row; `color`, its tint }).
local function flagChildren(mid)
    return {
        { "ourflag", L["Our flag"], "ph:flag-banner", C.blue, {
            { "inc",      L["INC flag room"], L["INC our flag room"], "gi:charging", C.orange },
            { "taken",    L["Flag taken"],    L["Our flag is taken"], "gi:black-flag", C.red },
            { "dropped",  L["Flag dropped"],  L["Our flag is dropped, return it"], "gi:corner-flag", C.orange },
            { "returned", L["Flag returned"], L["Our flag is returned"], "gi:return-arrow", C.green },
            { "clear",    L["Room clear"],    L["Our flag room is clear"], "gi:check-mark", C.green },
        } },
        { "enemyflag", L["Enemy flag"], "gi:pirate-flag", C.red, {
            { "go",      L["Get their flag"], L["Go get their flag"], "gi:crossed-swords", C.crimson },
            { "have",    L["We have it"],     L["We have their flag"], "gi:flying-flag", C.gold },
            { "dropped", L["Flag dropped"],   L["Their flag is dropped, grab it"], "gi:corner-flag", C.orange },
            { "clear",   L["Room clear"],     L["Their flag room is clear, grab it"], "gi:check-mark", C.green },
        } },
        { "ourfc", L["Our FC"], "gi:sprint", C.green, {
            { "peel",   L["Peel for FC"], L["Peel for our FC"], "gi:shield-reflect", C.blue },
            { "escort", L["Escort FC"],   L["Escort our FC home"], "gi:guards", C.blue },
            { "cap",    L["Cap ready"],   L["Cap ready, return our flag"], "gi:checkered-flag", C.gold },
            { "hiding", L["FC hiding"],   L["Our FC is hiding in our base"], "gi:hooded-assassin", C.purple },
        } },
        { "mid", mid[1], mid[2], mid.color, {
            { "inc",   mid[3], mid[4], "gi:charging", C.orange },
            { "push",  mid[5], mid[6], "gi:rally-the-troops", C.red },
            { "clear", mid[7], mid[8], "gi:check-mark", C.green },
            { "help",  mid[9], mid[10], "gi:megaphone", C.orange },
            mid[11],
        } },
    }
end

nodeBattleground("wsg", L["Warsong Gulch"], { "gi:tusks-flag", C.red }, { 489, 2106 }, flagChildren({
    L["Midfield"], "gi:road", L["INC mid"], L["INC mid"], L["Push mid"], L["Push mid"],
    L["Mid clear"], L["Mid is clear"], L["Help mid"], L["Need help mid"],
    { "regroup", L["Regroup mid"], L["Regroup mid"], "gi:cycle", C.cyan },
    color = C.brown,
}), {
    { "efcmid",   L["EFC mid"],        L["EFC mid"], "gi:flying-flag", C.orange },
    { "efctun",   L["EFC tunnel"],     L["EFC in the tunnel"], "gi:flying-flag", C.orange },
    { "efcroof",  L["EFC roof"],       L["EFC on the roof"], "gi:flying-flag", C.orange },
    { "fcheals",  L["FC needs heals"], L["Our FC needs heals"], "gi:heart-plus", C.green },
    { "killefc",  L["Kill EFC"],       L["Kill the EFC {target}"], "gi:bloody-sword", C.red },
    { "fcsafe",   L["FC safe"],        L["FC is safe"], "gi:checked-shield", C.green },
})
nodeBattleground("tp", L["Twin Peaks"], { "gi:peaks", C.green }, { 726 }, flagChildren({
    L["Bridge"], "gi:stone-bridge", L["INC bridge"], L["INC bridge"], L["Push bridge"], L["Push the bridge"],
    L["Bridge clear"], L["The bridge is clear"], L["Help bridge"], L["Need help at the bridge"],
    { "hold", L["Hold bridge"], L["Hold the bridge"], "gi:checked-shield", C.cyan },
    color = C.stone,
}), {
    { "efcmid",   L["EFC mid"],        L["EFC mid"], "gi:flying-flag", C.orange },
    { "efcwater", L["EFC water"],      L["EFC in the water"], "gi:water-splash", C.blue },
    { "fcheals",  L["FC needs heals"], L["Our FC needs heals"], "gi:heart-plus", C.green },
    { "killefc",  L["Kill EFC"],       L["Kill the EFC {target}"], "gi:bloody-sword", C.red },
    { "fcsafe",   L["FC safe"],        L["FC is safe"], "gi:checked-shield", C.green },
})
-- Silvershard Mines (bg buttons, 2026-10-20): carts spawn in the middle and roll down three tracks to
-- their depots, known by the lava, the water and the north (the community's names: the client's
-- AreaPOI table holds no point on this map), and two switches turn a cart onto another track. A track's
-- four rows are the node buttons worded for a cart.
local TRACK = {
    { "attack", L["Contest"], L["Contest their cart on %s"], "gi:crossed-swords", C.crimson },
    { "defend", L["Escort"],  L["Escort our cart on %s"],    "gi:guards",         C.blue },
    { "inc",    L["INC"],     L["INC on %s"],                "gi:charging",       C.orange },
    { "clear",  L["Clear"],   L["Clear on %s"],              "gi:check-mark",     C.green },
}
nodeBattleground("ssm", L["Silvershard Mines"], { "gi:mine-wagon", C.gold }, { 727 }, {
    { "lava",  L["Lava track"],  "gi:lava",       C.orange, rowsFor(TRACK, L["the lava track"]) },
    { "water", L["Water track"], "gi:waterfall",  C.blue,   rowsFor(TRACK, L["the water track"]) },
    { "north", L["North track"], "gi:mine-truck", C.gold,   rowsFor(TRACK, L["the north track"]) },
    { "switch", L["Switches"],   "gi:lever",      C.cyan, {
        { "flip",  L["Flip switch"],  L["Flip the track switch"],      "gi:lever",          C.cyan },
        { "hold",  L["Hold switch"],  L["Hold the track switch"],      "gi:checked-shield", C.cyan },
        { "inc",   L["INC"],          L["INC at the track switch"],    "gi:charging",       C.orange },
        { "clear", L["Clear"],        L["The track switch is clear"],  "gi:check-mark",     C.green },
    } },
}, {
    { "escort",   L["Escort"],         L["Escort the cart"], "gi:mine-wagon", C.blue },
    { "contest",  L["Contest"],        L["Contest the cart"], "gi:crossed-swords", C.crimson },
    { "help",     L["Cart help"],      L["Need help at a cart"], "gi:megaphone", C.orange },
})
-- Temple of Kotmogu (bg buttons): an orb waits in each corner of the temple, orange, blue, green and
-- purple, and a carrier scores most in the center.
local ORB = {
    { "take",  L["Take orb"],     L["Take the %s"],              "gi:grab",           C.gold },
    { "peel",  L["Peel"],         L["Peel for our %s carrier"],  "gi:shield-reflect", C.blue },
    { "kill",  L["Kill carrier"], L["Kill their %s carrier {target}"], "gi:bloody-sword",   C.red },
    { "heals", L["Heals"],        L["Our %s carrier needs heals"], "gi:heart-plus",     C.green },
}
nodeBattleground("tok", L["Temple of Kotmogu"], { "gi:crystal-ball", C.purple }, { 998 }, {
    { "orange", L["Orange orb"], "gi:concentration-orb", C.orange, rowsFor(ORB, L["orange orb"]) },
    { "blue",   L["Blue orb"],   "gi:concentration-orb", C.blue,   rowsFor(ORB, L["blue orb"]) },
    { "green",  L["Green orb"],  "gi:concentration-orb", C.green,  rowsFor(ORB, L["green orb"]) },
    { "purple", L["Purple orb"], "gi:concentration-orb", C.purple, rowsFor(ORB, L["purple orb"]) },
    { "center", L["Center"],     "gi:triorb",            C.cyan, {
        { "go",    L["Go center"],   L["Bring the orbs to the center"], "gi:orb-direction",  C.cyan },
        { "hold",  L["Hold center"], L["Hold the center"],              "gi:checked-shield", C.cyan },
        { "inc",   L["INC"],         L["INC center"],                   "gi:charging",       C.orange },
        { "clear", L["Clear"],       L["The center is clear"],          "gi:check-mark",     C.green },
    } },
}, {
    { "heals",    L["Orb heals"],      L["Orb carrier needs heals"], "gi:heart-plus", C.green },
    { "kill",     L["Kill orb"],       L["Kill orb carrier {target}"], "gi:bloody-sword", C.red },
    { "mid",      L["Go mid"],         L["Orbs to the middle"], "gi:orb-direction", C.cyan },
})
-- Seething Shore's azerite erupts at random among a dozen sites, three at a time, so its children are
-- the node in front of you and the next spawn, not the sites.
nodeBattleground("ss", L["Seething Shore"], { "gi:wave-crest", C.blue }, { 1803 }, {
    { "node", L["Azerite node"], "gi:crystal-cluster", C.gold, {
        { "capping", L["Capping"],    L["Capping this azerite node"], "gi:flying-flag", C.gold },
        { "inc",     L["INC node"],   L["INC this azerite node"], "gi:charging", C.orange },
        { "clear",   L["Node clear"], L["This azerite node is clear"], "gi:check-mark", C.green },
        { "help",    L["Node help"],  L["Need help at this azerite node"], "gi:megaphone", C.orange },
        { "contest", L["Contest"],    L["Contest their azerite node"], "gi:crossed-swords", C.crimson },
    } },
    { "spawn", L["New nodes"], "gi:radar-sweep", C.cyan, {
        { "new",     L["New node"],  L["New azerite node up, check the map"], "gi:radar-sweep", C.cyan },
        { "split",   L["Split up"],  L["Split up and take two nodes"], "gi:split-arrows", C.cyan },
        { "group",   L["Group up"],  L["Group up and take one node together"], "gi:meeple-army", C.red },
        { "powerup", L["Power-up"],  L["Power-up dropping here"], "gi:parachute", C.gold },
    } },
}, {
    { "here",     L["Azerite here"],   L["Azerite spawning here"], "gi:crystal-cluster", C.gold },
    { "next",     L["Next node"],      L["Moving to the next node"], "gi:sprint", C.cyan },
    { "help",     L["Need help"],      L["Need help at the azerite"], "gi:megaphone", C.orange },
})
-- Deephaul Ravine: a crystal in the middle, carried to a capture point, and two mine carts on their
-- tracks.
nodeBattleground("dhr", L["Deephaul Ravine"], { "gi:cave-entrance", C.orange }, { 2656 }, {
    { "crystalnode", L["Crystal"], "gi:crystal-shine", C.purple, {
        { "grab",    L["Grab crystal"],    L["Grab the crystal in the middle"], "gi:crystal-shine", C.gold },
        { "escort",  L["Escort carrier"],  L["Escort our crystal carrier to a capture point"], "gi:guards", C.blue },
        { "heals",   L["Carrier heals"],   L["Our crystal carrier needs heals"], "gi:heart-plus", C.green },
        { "kill",    L["Kill carrier"],    L["Kill their crystal carrier {target}"], "gi:bloody-sword", C.red },
        { "dropped", L["Crystal dropped"], L["The crystal is dropped, grab it"], "gi:crystal-cluster", C.orange },
    } },
    { "carts", L["Carts"], "gi:mine-truck", C.gold, {
        { "escort",  L["Escort cart"],  L["Escort our cart"], "gi:guards", C.blue },
        { "contest", L["Contest cart"], L["Contest their cart"], "gi:crossed-swords", C.crimson },
        { "inc",     L["INC cart"],     L["INC our cart"], "gi:charging", C.orange },
        { "clear",   L["Cart clear"],   L["Our cart is clear"], "gi:check-mark", C.green },
        { "help",    L["Cart help"],    L["Need help at the cart"], "gi:megaphone", C.orange },
    } },
}, {
    { "crystal",  L["Crystal"],        L["Need help at the crystal"], "gi:crystal-shine", C.purple },
    { "cart",     L["Cart"],           L["Cart is moving"], "gi:mine-truck", C.gold },
    { "defend",   L["Defend"],         L["Defend the cart"], "gi:checked-shield", C.cyan },
})
-- Alterac Valley: every general, captain, bunker, tower and graveyard, declared north (Dun Baldar) to
-- south (Frostwolf Keep); they show A-Z by name. A long name is shortened in the title, never in the message.
nodeBattleground("av", L["Alterac Valley"], { "gi:snowflake-2", C.blue }, { 30 }, {
    { "vanndar",    L["Vanndar"],            "gi:dwarf-king",     C.alliance,   objective(L["Vanndar Stormpike"]) },
    { "dbnorth",    L["DB North Bunker"],    "gi:guarded-tower",  C.alliance,  objective(L["Dun Baldar North Bunker"]) },
    { "spgy",       L["Stormpike GY"],       "gi:graveyard",      C.alliance,  objective(L["Stormpike Graveyard"]) },
    { "aidstation", L["Aid Station"],        "gi:first-aid-kit",      C.alliance,  objective(L["Stormpike Aid Station"]) },
    { "dbsouth",    L["DB South Bunker"],    "gi:guarded-tower",  C.alliance,  objective(L["Dun Baldar South Bunker"]) },
    { "icewing",    L["Icewing Bunker"],     "gi:guarded-tower",  C.alliance,  objective(L["Icewing Bunker"]) },
    { "shgy",       L["Stonehearth GY"],     "gi:graveyard",      C.alliance,  objective(L["Stonehearth Graveyard"]) },
    { "balinda",    L["Balinda"],            "gi:visored-helm",   C.alliance, objective(L["Balinda Stonehearth"]) },
    { "shbunker",   L["Stonehearth Bunker"], "gi:guarded-tower",  C.alliance,  objective(L["Stonehearth Bunker"]) },
    { "snowfall",   L["Snowfall GY"],        "gi:graveyard",      C.neutral,  objective(L["Snowfall Graveyard"]) },
    { "ibgy",       L["Iceblood GY"],        "gi:graveyard",      C.horde,  objective(L["Iceblood Graveyard"]) },
    { "galvangar",  L["Galvangar"],          "gi:brutal-helm",    C.horde, objective(L["Galvangar"]) },
    { "ibtower",    L["Iceblood Tower"],     "gi:watchtower",     C.horde,  objective(L["Iceblood Tower"]) },
    { "towerpoint", L["Tower Point"],        "gi:watchtower",     C.horde,  objective(L["Tower Point"]) },
    { "fwgy",       L["Frostwolf GY"],       "gi:graveyard",      C.horde,  objective(L["Frostwolf Graveyard"]) },
    { "wfw",        L["West FW Tower"],      "gi:watchtower",     C.horde,  objective(L["West Frostwolf Tower"]) },
    { "efw",        L["East FW Tower"],      "gi:watchtower",     C.horde,  objective(L["East Frostwolf Tower"]) },
    { "reliefhut",  L["Relief Hut"],         "gi:hut",            C.horde,  objective(L["Frostwolf Relief Hut"]) },
    { "drekthar",   L["Drek'Thar"],          "gi:orc-head",       C.horde,   objective(L["Drek'Thar"]) },
}, {
    { "general",  L["Defend general"], L["Defend our general"], "gi:king", C.gold },
    { "push",     L["Push general"],   L["Push the general"], "gi:rally-the-troops", C.red },
    { "gy",       L["Graveyard"],      L["Take the graveyard"], "gi:graveyard", C.green },
    { "tower",    L["Tower"],          L["Tower under attack"], "gi:watchtower", C.orange },
})
-- Ashran: the Road of Glory's towers fall one at a time toward a base, and the side events and bosses
-- run beside it.
nodeBattleground("ashran", L["Ashran"], { "gi:sword-clash", C.red }, { 1191 }, {
    { "glory", L["Road of Glory"], "gi:road", C.neutral, {
        { "push",  L["Push road"],   L["Push the road to the next tower"], "gi:rally-the-troops", C.red },
        { "hold",  L["Hold road"],   L["Hold the road, defend our tower"], "gi:checked-shield", C.cyan },
        { "taken", L["Tower taken"], L["We took the tower, push on"], "gi:tower-flag", C.gold },
        { "lost",  L["Tower lost"],  L["We lost a tower, regroup at the next one"], "gi:tower-fall", C.orange },
        { "inc",   L["INC road"],    L["INC on the road"], "gi:charging", C.orange },
    } },
    { "base", L["Our base"], "gi:castle-lorc", C.blue, {
        { "defend", L["Defend base"],   L["Defend our base"], "gi:checked-shield", C.cyan },
        { "leader", L["Defend leader"], L["Defend our leader"], "gi:king", C.gold },
        { "inc",    L["INC base"],      L["INC our base"], "gi:charging", C.orange },
        { "clear",  L["Base clear"],    L["Our base is clear"], "gi:check-mark", C.green },
    } },
    { "enemybase", L["Enemy base"], "gi:castle-delapouite", C.red, {
        { "attack",   L["Attack base"],   L["Attack the enemy base"], "gi:crossed-swords", C.crimson },
        { "leader",   L["Kill leader"],   L["Kill their leader"], "gi:crowned-skull", C.red },
        { "generals", L["Kill generals"], L["Kill their generals"], "gi:bloody-sword", C.orange },
    } },
    { "events", L["Events"], "gi:ringing-bell", C.gold, {
        { "ring",    L["Ring of Conquest"], L["Event at the Ring of Conquest, go"], "gi:double-ringed-orb", C.purple },
        { "race",    L["Amphitheater"],     L["The Race at the Amphitheater of Annihilation, go"], "gi:sprint", C.cyan },
        { "fires",   L["Brute's Rise"],     L["Ogre Fires at Brute's Rise, go"], "gi:campfire", C.orange },
        { "spirits", L["Ashmaul"],          L["Risen Spirits at Ashmaul Burial Grounds, go"], "gi:graveyard", C.green },
        { "ore",     L["Molten Quarry"],    L["Empowered Ore at Molten Quarry, go"], "gi:mining", C.gold },
    } },
    { "bosses", L["Bosses"], "gi:ogre", C.purple, {
        { "korlok",   L["Kor'lok"],  L["To Kor'lok, kill their champion"], "gi:ogre", C.purple },
        { "guardian", L["Guardian"], L["Their guardian is coming, focus it"], "gi:crowned-skull", C.red },
        { "captain",  L["Captain"],  L["Kill their captain {target}"], "gi:bloody-sword", C.red },
        { "artifact", L["Artifact"], L["The Ancient Artifact is up, get it"], "gi:relic-blade", C.gold },
    } },
}, {
    { "road",     L["Road"],           L["Push the road"], "gi:road", C.cyan },
    { "event",    L["Event"],          L["Event is up, go"], "gi:ringing-bell", C.gold },
    { "regroup",  L["Regroup"],        L["Regroup at the base"], "gi:campfire", C.orange },
})
-- Wintergrasp: attack and defense swap each battle, so every objective has both. The fortress is
-- north, its two near workshops either side of it, the two far ones and the three towers south.
nodeBattleground("wg", L["Wintergrasp"], { "gi:frozen-orb", C.cyan }, { 2118 }, {
    { "fortress", L["Fortress"], "gi:castle-lorc", C.blue, {
        { "attack",   L["Attack walls"], L["Attack the fortress walls"], "gi:crossed-swords", C.crimson },
        { "defend",   L["Defend walls"], L["Defend the fortress walls"], "gi:checked-shield", C.cyan },
        { "walldown", L["Wall down"],    L["A fortress wall is down"], "gi:broken-wall", C.orange },
        { "gatedown", L["Gate down"],    L["The fortress gate is down"], "gi:open-gate", C.red },
        { "relic",    L["Relic"],        L["Everyone to the relic"], "gi:holy-grail", C.gold },
    } },
    { "brokentemple", L["Broken Temple"], "gi:ancient-ruins", C.purple, rowsFor(NODE, L["Broken Temple"]) },
    { "sunkenring", L["Sunken Ring"], "gi:double-ringed-orb", C.cyan, rowsFor(NODE, L["Sunken Ring"]) },
    { "westspark", L["Westspark"], "gi:anvil", C.orange, rowsFor(NODE, L["Westspark"]) },
    { "eastspark", L["Eastspark"], "gi:anvil", C.gold, rowsFor(NODE, L["Eastspark"]) },
    { "towers", L["Towers"], "gi:tower-fall", C.red, {
        { "attack", L["Attack towers"], L["Attack the southern towers"], "gi:crossed-swords", C.crimson },
        { "defend", L["Defend towers"], L["Defend the southern towers"], "gi:checked-shield", C.cyan },
        { "down",   L["Tower down"],    L["A southern tower is down"], "gi:tower-fall", C.gold },
        { "help",   L["Help towers"],   L["Need help at the southern towers"], "gi:megaphone", C.orange },
    } },
}, {
    { "walls",    L["Walls"],          L["Defend the walls"], "gi:stone-wall", C.blue },
    { "siege",    L["Siege"],          L["Siege engine incoming"], "gi:siege-ram", C.orange },
    { "workshop", L["Workshop"],       L["Take the workshop"], "gi:anvil", C.orange },
})

-- The generic set comes last (phase 4): a battleground's own set is then the first active group on a
-- default dial, so the dial opens straight on its nodes (D9). Migration step 2 moves it on stored
-- profiles (modules/Library.lua MoveGenericBattlegroundLast).
BI.Group("bi.bg", {
    name = L["Battleground"], glyph = "gi:flag-objective", color = C.gold,
    when = { content = { battleground = true } },
    callouts = BI.Callouts("bi.bg", "smartGroup", {
        { "help",    L["Need help"],  L["Need help here"], "gi:megaphone", C.orange },
        { "inc",     L["INC"],        L["INC {rt8}"], "gi:charging", C.red },
        { "hold",    L["Hold"],       L["Hold this"], "gi:guarded-tower", C.blue },
        { "capping", L["Capping"],    L["Capping"], "gi:flying-flag", C.gold },
        { "defend",  L["Defend"],     L["Defend"], "gi:checked-shield", C.cyan },
        { "push",    L["Push"],       L["Push now"], "gi:rally-the-troops", C.red },
    }),
})
BI.SNAPSHOTS["bi.bg"] = BG
