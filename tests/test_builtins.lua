-- tests/test_builtins.lua — defaults/BuiltIns*.lua (spec §12): integrity and the bake audit.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local function bi() local NS = T.newAddon() return NS, NS.BuiltIns end

test("builtins: the expected top-level sets exist in order", function()
    local _, BI = bi()
    assertEqual(BI.order[1], "bi.mplus")
    assertEqual(BI.order[2], "bi.raid")
    assertEqual(BI.order[3], "bi.arena")
    assertEqual(BI.order[4], "bi.world")
    -- A battleground's own set comes before the generic one, so the dial opens into it (D9, phase 4).
    assertEqual(BI.order[5], "bi.bg.ab")
    assertEqual(BI.order[#BI.order], "bi.bg")
    assertTrue(#BI.order >= 19, "generic sets plus one per battleground")
end)

test("builtins: ids are unique, referenced and well formed", function()
    local _, BI = bi()
    local seen = {}
    for id, g in pairs(BI.groups) do
        assertTrue(id:match("^bi%.[%w%.]+$") ~= nil, "group id " .. id)
        for _, cid in ipairs(g.callouts or {}) do
            assertTrue(BI.callouts[cid] ~= nil, id .. " -> " .. cid)
            assertTrue(not seen[cid], "callout in two groups: " .. cid)
            seen[cid] = true
        end
        for _, child in ipairs(g.children or {}) do
            assertEqual(BI.groups[child].parent, id, "parent of " .. child)
        end
    end
    for cid in pairs(BI.callouts) do assertTrue(seen[cid], "orphan callout " .. cid) end
end)

test("builtins: only top-level groups are in the order, and every top-level group is", function()
    local _, BI = bi()
    local inOrder = {}
    for _, id in ipairs(BI.order) do inOrder[id] = true assertTrue(BI.groups[id].parent == nil, id) end
    for id, g in pairs(BI.groups) do if g.parent == nil then assertTrue(inOrder[id], "missing " .. id) end end
end)

test("builtins: node sets open into their ring and nest one level", function()
    local _, BI = bi()
    local ab = BI.groups["bi.bg.ab"]
    assertTrue(ab.openInto)
    assertEqual(#ab.children, 5)
    assertTrue(#ab.callouts >= 4, "and map-wide callouts of its own")
    local stables = BI.groups[ab.children[1]]
    assertEqual(#stables.callouts, 4)
    assertEqual(BI.callouts[stables.callouts[3]].text, "INC Stables")
end)

test("builtins: bake audit, every callout bakes under its set's snapshot", function()
    local NS, BI = bi()
    local function topOf(id) local g = BI.groups[id] while g.parent do id = g.parent g = BI.groups[id] end return id end
    for gid, g in pairs(BI.groups) do
        local snap = BI.SNAPSHOTS[topOf(gid)]
        assertTrue(snap ~= nil, "snapshot for " .. topOf(gid))
        for _, cid in ipairs(g.callouts or {}) do
            local line, reason, info = NS.Bake.Bake(BI.callouts[cid], snap, { ctx = { me = "Traxex" } })
            assertTrue(line ~= nil, cid .. ": " .. tostring(reason))
            assertTrue(info.length <= 255, cid .. " length")
            assertTrue(#(info.unknown or {}) == 0, cid .. " unknown token")
            assertTrue(info.lock == nil, cid .. " locked under its own snapshot: " .. tostring(info.lock))
        end
    end
end)

test("builtins: battlegrounds use smart group; arena uses party; raid lead uses smart lead", function()
    local _, BI = bi()
    for cid, c in pairs(BI.callouts) do
        if cid:match("^bi%.bg") then assertEqual(c.channel, "smartGroup", cid) end
        if cid:match("^bi%.arena") then assertEqual(c.channel, "party", cid) end
    end
    assertEqual(BI.callouts["bi.raid.pull10"].channel, "smartLead")
end)

test("builtins: [phase 5] every node set pins each node to a wind, at most eight, Deepwind Gorge's five included", function()
    local NS, BI = bi()
    local sets = 0
    for _, gid in ipairs(BI.order) do
        local def = BI.groups[gid]
        if def.children then
            sets = sets + 1
            local nodes = {}
            for i, child in ipairs(def.children) do nodes[i] = { wind = BI.groups[child].compass } end
            -- its own callouts take one wedge too (modules/Dial_Layout.lua groupEntry)
            if #def.callouts > 0 then nodes[#nodes + 1] = { wind = NS.DialLayout.MIDDLE } end
            -- red under: drop one node's wind from defaults/BuiltIns_Battlegrounds.lua
            if gid ~= "bi.bg.av" then assertTrue(NS.DialLayout.PinNodes(nodes) ~= nil, gid .. " pins every node") end
        end
    end
    -- the five node sets, the seven with objectives (bg subgroups), Silvershard Mines and Temple of
    -- Kotmogu (bg buttons)
    assertEqual(sets, 14)
    assertEqual(BI.groups["bi.bg.ab.lumbermill"].compass, "SW")
    assertEqual(#BI.groups["bi.bg.dwg"].children, 5)
    assertEqual(BI.callouts["bi.bg.dwg.shrine.inc"].text, "INC Shrine")
end)

test("builtins: [B7] every callout ships a catalog glyph, with a color only where it is a glyph", function()
    local NS, BI = bi()
    local Lib = NS.Library
    for cid, c in pairs(BI.callouts) do
        -- red under: a callout row without its glyph name in defaults/BuiltIns_*.lua
        assertTrue(type(c.glyph) == "string", cid .. " names a glyph")
        assertTrue(NS.Icon(c.glyph) ~= nil, cid .. ": the vendored catalog carries " .. tostring(c.glyph))
        assertEqual(c.icon, NS.Icon(c.glyph), cid .. " stores the glyph's path")
        assertEqual(Lib.IsGlyph(c.icon), c.glyph, cid .. " reads back as its glyph")
        assertTrue(Lib.ValidIconColor(c.iconColor), cid .. " color")
    end
    assertEqual(BI.callouts["bi.arena.kill"].iconColor, "ff4040", "a kill is red")
    assertEqual(BI.callouts["bi.bg.ab.stables.clear"].iconColor, "40d040", "a node clear is green")
    assertEqual(BI.callouts["bi.mplus.lust"].glyph, "gi:enrage")
end)

test("builtins: [B7] the generic dungeon set is Dungeon (generic), active in a dungeon and in M+", function()
    local _, BI = bi()
    local g = BI.groups["bi.mplus"]
    assertEqual(g.name, "Dungeon (generic)")
    assertTrue(g.when.content.dungeon and g.when.content.mythicPlus)
end)

-- The white the glyphs draw when no color is set; a set must not be all of it.
local WHITE = "ffffff"

test("builtins: [polish] World (solo) is a solo open-world set of say callouts", function()
    local NS, BI = bi()
    local g = BI.groups["bi.world"]
    -- red under: no defaults/BuiltIns_World.lua
    assertTrue(g ~= nil, "the set exists")
    assertEqual(g.name, "World (solo)")
    assertTrue(g.when.content.openWorld and g.when.group.solo, "World, Solo")
    assertTrue(#g.callouts >= 8, "about eight callouts")
    for _, cid in ipairs(g.callouts) do
        local ch = BI.callouts[cid].channel
        assertTrue(ch == "say" or ch == "yell", cid .. " speaks out loud, as a solo player can")
    end
    assertEqual(BI.SNAPSHOTS["bi.world"].content, "openWorld", "the bake audit checks it solo")
    assertEqual(BI.SNAPSHOTS["bi.world"].group, "solo")
    local line = NS.Bake.Bake(BI.callouts["bi.world.thanks"], BI.SNAPSHOTS["bi.world"], { ctx = {} })
    assertEqual(line, "/s Thanks for the help!")
end)

test("builtins: [polish] every battleground node set has map-wide callouts of its own", function()
    local _, BI = bi()
    for _, key in ipairs({ "ab", "eots", "bfg", "dwg", "ioc" }) do
        local g = BI.groups["bi.bg." .. key]
        -- red under: a node set with no `callouts` rows in defaults/BuiltIns_Battlegrounds.lua
        assertTrue(#g.callouts >= 4 and #g.callouts <= 6, key .. " has four to six")
        for _, cid in ipairs(g.callouts) do assertEqual(BI.callouts[cid].channel, "smartGroup", cid) end
    end
    assertEqual(BI.callouts["bi.bg.ioc.siege"].text, "Escort our siege engine")
end)

test("builtins: [polish] every callout icon has a color, and no group is white only", function()
    local _, BI = bi()
    for cid, c in pairs(BI.callouts) do
        -- red under: a callout row without its color in defaults/BuiltIns_*.lua
        assertTrue(type(c.iconColor) == "string", cid .. " has a color")
    end
    for gid, g in pairs(BI.groups) do
        local colors, n = {}, 0
        for _, cid in ipairs(g.callouts) do
            local color = BI.callouts[cid].iconColor
            if not colors[color] then colors[color], n = true, n + 1 end
        end
        if #g.callouts > 1 then
            assertTrue(n >= 2, gid .. " uses more than one color")
            assertTrue(not (n == 1 and colors[WHITE]), gid .. " is not white only")
        end
    end
    assertEqual(BI.callouts["bi.mplus.pull"].iconColor, BI.COLOR.orange, "a pull is an alarm")
    assertEqual(BI.callouts["bi.raid.stack"].iconColor, WHITE, "white is one of the colors")
end)

test("builtins: [polish] every group has a colored catalog glyph for its icon", function()
    local NS, BI = bi()
    local Lib = NS.Library
    for gid, g in pairs(BI.groups) do
        -- red under: a group declared without `glyph` in defaults/BuiltIns_*.lua
        assertTrue(type(g.glyph) == "string", gid .. " names a glyph")
        assertTrue(NS.Icon(g.glyph) ~= nil, gid .. ": the vendored catalog carries " .. tostring(g.glyph))
        assertEqual(g.icon, NS.Icon(g.glyph), gid .. " stores the glyph's path")
        assertEqual(Lib.IsGlyph(g.icon), g.glyph, gid .. " reads back as its glyph")
        assertTrue(type(g.iconColor) == "string" and Lib.ValidIconColor(g.iconColor), gid .. " color")
    end
    assertEqual(BI.groups["bi.bg.bfg.lighthouse"].glyph, "gi:lighthouse", "a node's icon is its name")
    assertEqual(BI.groups["bi.world"].glyph, "gi:world")
end)

-- ── battleground sub-groups (2026-10-20) ─────────────────────────────────────────────────────

local function childNames(BI, gid)
    local out = {}
    for i, child in ipairs(BI.groups[gid].children or {}) do out[i] = BI.groups[child].name end
    return table.concat(out, ",")
end

test("builtins: [bg subgroups] Alterac Valley has every general, captain, bunker, tower and graveyard, north to south", function()
    local NS, BI = bi()
    local av = BI.groups["bi.bg.av"]
    -- red under: Alterac Valley declared flat in defaults/BuiltIns_Battlegrounds.lua
    assertEqual(#(av.children or {}), 19)
    assertTrue(av.openInto, "opens into its ring, as a node set does")
    assertEqual(childNames(BI, "bi.bg.av"), "Vanndar,DB North Bunker,Stormpike GY,Aid Station,DB South Bunker,"
        .. "Icewing Bunker,Stonehearth GY,Balinda,Stonehearth Bunker,Snowfall GY,Iceblood GY,Galvangar,"
        .. "Iceblood Tower,Tower Point,Frostwolf GY,West FW Tower,East FW Tower,Relief Hut,Drek'Thar")
    for _, child in ipairs(av.children) do
        local g = BI.groups[child]
        assertEqual(#g.callouts, 2, child .. " has exactly two")
        local attack, defend = BI.callouts[g.callouts[1]], BI.callouts[g.callouts[2]]
        assertEqual(attack.name .. "/" .. defend.name, "Attack/Defend", child)
        assertTrue(attack.text:match("^Attack %S") ~= nil and defend.text:match("^Defend %S") ~= nil, child)
        assertEqual(attack.text:sub(8), defend.text:sub(8), child .. " names one objective")
        assertNil(g.compass, child .. ": nineteen cannot sit on the eight winds")
    end
    assertEqual(BI.callouts["bi.bg.av.ibtower.attack"].text, "Attack Iceblood Tower")
    assertEqual(BI.callouts["bi.bg.av.wfw.defend"].text, "Defend West Frostwolf Tower", "the message names it in full")
    assertEqual(BI.callouts["bi.bg.av.drekthar.attack"].text, "Attack Drek'Thar")
    assertEqual(BI.callouts["bi.bg.av.balinda.defend"].text, "Defend Balinda Stonehearth")
    assertEqual(BI.callouts["bi.bg.av.general"].text, "Defend our general", "the map-wide callouts stay")
    local nodes = {}
    for i, child in ipairs(av.children) do nodes[i] = { wind = BI.groups[child].compass } end
    assertNil(NS.DialLayout.PinNodes(nodes), "the dial draws it unpinned")
end)

test("builtins: [bg subgroups] Isle of Conquest gains Our base and Enemy base beside its five nodes", function()
    local _, BI = bi()
    -- red under: no base children on Isle of Conquest in defaults/BuiltIns_Battlegrounds.lua
    assertEqual(childNames(BI, "bi.bg.ioc"), "Docks,Hangar,Workshop,Quarry,Refinery,Our base,Enemy base")
    local function texts(gid)
        local out = {}
        for i, cid in ipairs(BI.groups[gid].callouts) do out[i] = BI.callouts[cid].text end
        return table.concat(out, "|")
    end
    assertEqual(texts("bi.bg.ioc.base"), "Fight at our base|Defend our base|INC our base|Our base is clear")
    assertEqual(texts("bi.bg.ioc.enemybase"),
        "Attack the enemy base|Hold the enemy base|INC at the enemy base|The enemy base is clear")
    assertEqual(BI.groups["bi.bg.ioc.base"].compass, "free", "no fixed place a neutral callout can name")
    assertEqual(BI.groups["bi.bg.ioc.docks"].compass, "W", "the nodes keep their winds")
end)

test("builtins: [bg subgroups] the flag maps, Wintergrasp, Ashran, Deephaul Ravine and Seething Shore have objective children", function()
    local _, BI = bi()
    local want = {
        ["bi.bg.wsg"] = "Our flag,Enemy flag,Our FC,Midfield",
        ["bi.bg.tp"] = "Our flag,Enemy flag,Our FC,Bridge",
        ["bi.bg.wg"] = "Fortress,Broken Temple,Sunken Ring,Westspark,Eastspark,Towers",
        ["bi.bg.ashran"] = "Road of Glory,Our base,Enemy base,Events,Bosses",
        ["bi.bg.dhr"] = "Crystal,Carts",
        ["bi.bg.ss"] = "Azerite node,New nodes",
    }
    for gid, names in pairs(want) do
        -- red under: a set left flat in defaults/BuiltIns_Battlegrounds.lua
        assertEqual(childNames(BI, gid), names, gid)
        assertTrue(BI.groups[gid].openInto, gid .. " opens into its ring")
        assertTrue(#BI.groups[gid].callouts >= 3, gid .. " keeps its map-wide callouts")
        for _, child in ipairs(BI.groups[gid].children) do
            local n = #BI.groups[child].callouts
            assertTrue(n >= 2 and n <= 6, child .. " has two to six callouts")
        end
    end
    assertEqual(BI.callouts["bi.bg.wsg.ourflag.inc"].text, "INC our flag room")
    assertEqual(BI.callouts["bi.bg.tp.mid.inc"].text, "INC bridge")
    assertEqual(BI.callouts["bi.bg.wg.westspark.attack"].text, "Attack Westspark")
    assertEqual(BI.groups["bi.bg.wg.fortress"].compass, "N", "Wintergrasp's objectives keep their winds")
    assertEqual(BI.groups["bi.bg.wg.towers"].compass, "S")
end)

test("builtins: [bg subgroups] no callout names a faction", function()
    local _, BI = bi()
    for cid, c in pairs(BI.callouts) do
        if cid:match("^bi%.bg") then
            -- red under: a callout reading "Alliance" or "Horde" in defaults/BuiltIns_Battlegrounds.lua
            assertTrue(not (c.text:find("Alliance") or c.text:find("Horde")), cid .. " is faction neutral")
        end
    end
end)

-- ── bg buttons (2026-10-20): Attack, Defend, INC and Clear on every base-capture node ─────────

-- A group's callouts as "name=text" pairs, joined.
local function rows(BI, gid)
    local out = {}
    for i, cid in ipairs(BI.groups[gid].callouts) do
        local c = BI.callouts[cid]
        out[i] = c.name .. "=" .. c.text
    end
    return table.concat(out, "|")
end

test("builtins: [bg buttons] every base-capture node has Attack, Defend, INC and Clear, as Wintergrasp's workshops do", function()
    local _, BI = bi()
    for _, key in ipairs({ "ab", "eots", "bfg", "dwg", "ioc" }) do
        for _, child in ipairs(BI.groups["bi.bg." .. key].children) do
            local g = BI.groups[child]
            -- red under: a node still on the INC 1/2/3/Many/Clear/Help rows in defaults/BuiltIns_Battlegrounds.lua
            assertEqual(#g.callouts, 4, child .. " has exactly four")
            local want = { attack = "gi:crossed-swords", defend = "gi:checked-shield", inc = "gi:charging",
                clear = "gi:check-mark" }
            for i, short in ipairs({ "attack", "defend", "inc", "clear" }) do
                assertEqual(g.callouts[i], child .. "." .. short, child)
                assertEqual(BI.callouts[g.callouts[i]].glyph, want[short], child .. " " .. short)
            end
        end
    end
    assertEqual(rows(BI, "bi.bg.ab.lumbermill"),
        "Attack=Attack Lumber Mill|Defend=Defend Lumber Mill|INC=INC Lumber Mill|Clear=Lumber Mill is clear")
    assertEqual(rows(BI, "bi.bg.eots.flag"),
        "Take flag=Take the flag|Defend flag=Defend the flag|INC=INC the flag|Clear=The flag is clear")
    assertEqual(BI.callouts["bi.bg.wg.eastspark.clear"].text, "Eastspark is clear", "Wintergrasp shares the template")
    assertEqual(BI.callouts["bi.bg.ab.farm.attack"].iconColor, BI.COLOR.red)
    assertEqual(BI.callouts["bi.bg.ab.farm.defend"].iconColor, BI.COLOR.blue)
    assertEqual(BI.callouts["bi.bg.ab.farm.inc"].iconColor, BI.COLOR.orange)
    assertEqual(BI.callouts["bi.bg.ab.farm.clear"].iconColor, BI.COLOR.green)
    assertEqual(BI.callouts["bi.bg.ab.hold"].text, "Hold what we have, defend our bases", "the map-wide callouts stay")
end)

test("builtins: [bg buttons] Silvershard Mines has its three tracks and the switches, each with four", function()
    local _, BI = bi()
    -- red under: Silvershard Mines left flat in defaults/BuiltIns_Battlegrounds.lua
    assertEqual(childNames(BI, "bi.bg.ssm"), "Lava track,Water track,North track,Switches")
    assertTrue(BI.groups["bi.bg.ssm"].openInto)
    assertEqual(rows(BI, "bi.bg.ssm.lava"), "Contest=Contest their cart on the lava track|"
        .. "Escort=Escort our cart on the lava track|INC=INC on the lava track|Clear=Clear on the lava track")
    assertEqual(rows(BI, "bi.bg.ssm.switch"), "Flip switch=Flip the track switch|Hold switch=Hold the track switch|"
        .. "INC=INC at the track switch|Clear=The track switch is clear")
    for _, child in ipairs(BI.groups["bi.bg.ssm"].children) do
        assertEqual(BI.groups[child].compass, "free", child .. ": no AreaPOI point to pin")
    end
    assertEqual(BI.callouts["bi.bg.ssm.escort"].text, "Escort the cart", "the map-wide callouts stay")
end)

test("builtins: [bg buttons] Temple of Kotmogu has its four orbs and the center", function()
    local NS, BI = bi()
    -- red under: Temple of Kotmogu left flat in defaults/BuiltIns_Battlegrounds.lua
    assertEqual(childNames(BI, "bi.bg.tok"), "Orange orb,Blue orb,Green orb,Purple orb,Center")
    assertEqual(rows(BI, "bi.bg.tok.blue"), "Take orb=Take the blue orb|Peel=Peel for our blue orb carrier|"
        .. "Kill carrier=Kill their blue orb carrier %t|Heals=Our blue orb carrier needs heals")
    assertEqual(rows(BI, "bi.bg.tok.center"), "Go center=Bring the orbs to the center|Hold center=Hold the center|"
        .. "INC=INC center|Clear=The center is clear")
    for _, color in ipairs({ "orange", "blue", "green", "purple" }) do
        assertEqual(BI.groups["bi.bg.tok." .. color].iconColor, BI.COLOR[color], color .. " orb draws its color")
    end
    -- the %t a row's %s fill leaves for the bake
    local line = NS.Bake.Bake(BI.callouts["bi.bg.tok.green.kill"], BI.SNAPSHOTS["bi.bg.tok"],
        { ctx = { target = "Traxex" } })
    assertTrue(line:find("Kill their green orb carrier", 1, true) ~= nil, line)
    assertEqual(BI.callouts["bi.bg.tok.mid"].text, "Orbs to the middle", "the map-wide callouts stay")
end)
