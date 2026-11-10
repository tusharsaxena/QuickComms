-- tests/test_builtins.lua — defaults/BuiltIns*.lua (spec §12): integrity and the bake audit.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local function bi() local NS = T.newAddon() return NS, NS.BuiltIns end

-- The Emotes set's fixture (tests/emote_tokens.lua) and the client this kit profile runs.
local EMOTES = dofile("tests/emote_tokens.lua")
local CLIENT = dofile("tests/_kit/mock_client.lua").current() == "forever" and "forever" or "retail"

-- The client's EMOTEn_TOKEN and EMOTEn_CMD1 globals for the seeded tokens, from the fixture.
local function plantEmotes(NS, env)
    env.MAXEMOTEINDEX = 628
    for token, i in pairs(EMOTES[CLIENT]) do
        env["EMOTE" .. i .. "_TOKEN"], env["EMOTE" .. i .. "_CMD1"] = token, EMOTES.commands[i]
    end
    NS.Emotes.Reset()
end

test("builtins: the expected top-level sets exist in order", function()
    local _, BI = bi()
    assertEqual(BI.order[1], "bi.mplus")
    assertEqual(BI.order[2], "bi.raid")
    assertEqual(BI.order[3], "bi.arena")
    assertEqual(BI.order[4], "bi.world")
    -- red under: no defaults/BuiltIns_Emotes.lua after BuiltIns_World.lua in the TOC (QFE-E3)
    assertEqual(BI.order[5], "bi.emotes", "Emotes after the World set")
    -- A battleground's own set comes before the generic one, so the dial opens into it (D9, phase 4).
    assertEqual(BI.order[6], "bi.bg.ab")
    -- the generic battleground set after every battleground's own, and In Group after it (bg
    -- buttons): in a battleground the map's own set is the first active group (D9)
    assertEqual(BI.order[#BI.order - 1], "bi.bg")
    assertEqual(BI.order[#BI.order], "bi.group")
    for i = 6, #BI.order - 2 do assertTrue(BI.order[i]:match("^bi%.bg%.") ~= nil, BI.order[i]) end
    assertTrue(#BI.order >= 20, "generic sets plus one per battleground")
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

test("builtins: node sets nest one level", function()
    local _, BI = bi()
    local ab = BI.groups["bi.bg.ab"]
    assertNil(ab.openInto, "no group carries the retired Open into (dial rework)")
    assertEqual(#ab.children, 5)
    assertTrue(#ab.callouts >= 4, "and map-wide callouts of its own")
    local stables = BI.groups[ab.children[1]]
    assertEqual(#stables.callouts, 4)
    assertEqual(BI.callouts[stables.callouts[3]].text, "INC Stables")
end)

test("builtins: bake audit, every callout bakes under its set's snapshot", function()
    local NS, env = T.newAddon()
    local BI = NS.BuiltIns
    plantEmotes(NS, env)
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

test("builtins: [phase 5] the node sets, Deepwind Gorge's five nodes included; no node carries a wind", function()
    local _, BI = bi()
    local sets = 0
    for _, gid in ipairs(BI.order) do
        local def = BI.groups[gid]
        if def.children then
            sets = sets + 1
            for _, child in ipairs(def.children) do
                -- red under: a node row keeping its compass wind (retired 2026-10-25)
                assertNil(BI.groups[child].compass, child)
            end
        end
    end
    -- the five node sets, the seven with objectives (bg subgroups), Silvershard Mines and Temple of
    -- Kotmogu (bg buttons)
    assertEqual(sets, 14)
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

test("builtins: [B7] the generic dungeon set is Dungeon, active in a dungeon and in M+", function()
    local _, BI = bi()
    local g = BI.groups["bi.mplus"]
    assertEqual(g.name, "Dungeon")
    assertTrue(g.when.content.dungeon and g.when.content.mythicPlus)
end)

-- The white the glyphs draw when no color is set; a set must not be all of it.
local WHITE = "ffffff"

test("builtins: [polish] Solo is a solo open-world set of General (/1) callouts", function()
    local NS, BI = bi()
    local g = BI.groups["bi.world"]
    -- red under: no defaults/BuiltIns_World.lua
    assertTrue(g ~= nil, "the set exists")
    assertEqual(g.name, "Solo")
    assertTrue(g.when.content.openWorld and g.when.group.solo, "World, Solo")
    assertTrue(#g.callouts >= 7, "about seven callouts")
    for _, cid in ipairs(g.callouts) do
        -- red under: Solo still on say (owner, 2026-10-23: General /1 instead of say)
        assertEqual(BI.callouts[cid].channel, "general", cid)
    end
    assertEqual(BI.SNAPSHOTS["bi.world"].content, "openWorld", "the bake audit checks it solo")
    assertEqual(BI.SNAPSHOTS["bi.world"].group, "solo")
    assertTrue(BI.SNAPSHOTS["bi.world"].general, "the bake audit has channel 1 joined")
    local line = NS.Bake.Bake(BI.callouts["bi.world.thanks"], BI.SNAPSHOTS["bi.world"], { ctx = {} })
    assertEqual(line, "/1 Thanks for the help!")
    local off = { content = "openWorld", group = "solo", instanceGroup = false, lockdown = {} }
    line = NS.Bake.Bake(BI.callouts["bi.world.thanks"], off, { ctx = {} })
    assertEqual(line, "/s Thanks for the help!", "Say when channel 1 is not joined")
end)

test("builtins: [QF-05] Solo's place lines carry {coordinates}", function()
    local _, BI = bi()
    -- red under: the Solo texts without @ {coordinates} (owner, 2026-10-23: "{target} @ {coordinates}")
    assertEqual(BI.callouts["bi.world.rare"].text, "Rare spotted: {target} @ {coordinates}")
    assertEqual(BI.callouts["bi.world.elite"].text, "Can anyone help with this elite? {target} @ {coordinates}")
    assertEqual(BI.callouts["bi.world.boss"].text, "World boss up: {target} @ {coordinates}")
    assertEqual(BI.callouts["bi.world.event"].text, "World event starting @ {coordinates}, come join")
    assertEqual(BI.callouts["bi.world.quest"].text, "Anyone want to group up for this quest?", "no fixed place")
end)

test("builtins: [QF-05] the owner's edits are the shipped look, with no schema step", function()
    local NS, BI = bi()
    -- red under: Chain pull still red, Hello still gold (owner's SavedVariables, 2026-10-23)
    assertEqual(BI.COLOR.yellow, "fff468")
    assertEqual(BI.COLOR.sky, "3fc7eb")
    assertEqual(BI.callouts["bi.mplus.chain"].iconColor, "fff468")
    assertEqual(BI.callouts["bi.group.hello"].iconColor, "3fc7eb")
    assertEqual(BI.callouts["bi.group.hello"].text, "Hello!", "the owner's exception: not Hello there!")
    -- red under: no bi.group.stone in defaults/BuiltIns_Group.lua
    local stone = BI.callouts["bi.group.stone"]
    assertTrue(stone ~= nil, "At Stone is shipped")
    assertEqual(stone.channel, "smartGroup")
    assertEqual(stone.glyph, "gi:tombstone-sbed")
    assertEqual(stone.iconColor, "b07cff")
    assertEqual(BI.groups["bi.group"].callouts[2], "bi.group.stone", "2nd in In Group")
    -- red under: a migration step added for the prebuilts (D4c: no migration). Step 10 is QC-03's
    -- reset onto the skin and step 11 the Font flags' move to From skin (LibKa0s v1.82.0); neither
    -- touches a prebuilt, nor does step 18, the Friz move (R3-FRIZ), nor step 19, which only adds the
    -- new Emotes set (QFE-E3).
    assertEqual(NS.MIGRATIONS[#NS.MIGRATIONS].to, 19)
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
    local _, BI = bi()
    local av = BI.groups["bi.bg.av"]
    -- red under: Alterac Valley declared flat in defaults/BuiltIns_Battlegrounds.lua
    assertEqual(#(av.children or {}), 19)
    assertEqual(childNames(BI, "bi.bg.av"), "Vanndar,DB North Bunker,Stormpike GY,Aid Station,DB South Bunker,"
        .. "Icewing Bunker,Stonehearth GY,Balinda,Stonehearth Bunker,Snowfall GY,Iceblood GY,Galvangar,"
        .. "Iceblood Tower,Tower Point,Frostwolf GY,FW West Tower,FW East Tower,Relief Hut,Drek'Thar")
    for _, child in ipairs(av.children) do
        local g = BI.groups[child]
        assertEqual(#g.callouts, 2, child .. " has exactly two")
        local attack, defend = BI.callouts[g.callouts[1]], BI.callouts[g.callouts[2]]
        assertEqual(attack.name .. "/" .. defend.name, "Attack/Defend", child)
        assertTrue(attack.text:match("^Attack %S") ~= nil and defend.text:match("^Defend %S") ~= nil, child)
        assertEqual(attack.text:sub(8), defend.text:sub(8), child .. " names one objective")
    end
    assertEqual(BI.callouts["bi.bg.av.ibtower.attack"].text, "Attack Iceblood Tower")
    assertEqual(BI.callouts["bi.bg.av.wfw.defend"].text, "Defend West Frostwolf Tower", "the message names it in full")
    assertEqual(BI.callouts["bi.bg.av.drekthar.attack"].text, "Attack Drek'Thar")
    assertEqual(BI.callouts["bi.bg.av.balinda.defend"].text, "Defend Balinda Stonehearth")
    assertEqual(BI.callouts["bi.bg.av.general"].text, "Defend our general", "the map-wide callouts stay")
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
        assertTrue(#BI.groups[gid].callouts >= 3, gid .. " keeps its map-wide callouts")
        for _, child in ipairs(BI.groups[gid].children) do
            local n = #BI.groups[child].callouts
            assertTrue(n >= 2 and n <= 6, child .. " has two to six callouts")
        end
    end
    assertEqual(BI.callouts["bi.bg.wsg.ourflag.inc"].text, "INC our flag room")
    assertEqual(BI.callouts["bi.bg.tp.mid.inc"].text, "INC bridge")
    assertEqual(BI.callouts["bi.bg.wg.westspark.attack"].text, "Attack Westspark")
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
    -- red under: Attack red and Defend blue, which read as Horde and Alliance beside the locations
    assertEqual(BI.callouts["bi.bg.ab.farm.attack"].iconColor, BI.COLOR.crimson)
    assertEqual(BI.callouts["bi.bg.ab.farm.defend"].iconColor, BI.COLOR.cyan)
    assertEqual(BI.callouts["bi.bg.ab.farm.inc"].iconColor, BI.COLOR.orange)
    assertEqual(BI.callouts["bi.bg.ab.farm.clear"].iconColor, BI.COLOR.green)
    assertEqual(BI.callouts["bi.bg.ab.hold"].text, "Hold what we have, defend our bases", "the map-wide callouts stay")
end)

test("builtins: [bg buttons] Silvershard Mines has its three tracks and the switches, each with four", function()
    local _, BI = bi()
    -- red under: Silvershard Mines left flat in defaults/BuiltIns_Battlegrounds.lua
    assertEqual(childNames(BI, "bi.bg.ssm"), "Lava track,Water track,North track,Switches")
    assertEqual(rows(BI, "bi.bg.ssm.lava"), "Contest=Contest their cart on the lava track|"
        .. "Escort=Escort our cart on the lava track|INC=INC on the lava track|Clear=Clear on the lava track")
    assertEqual(rows(BI, "bi.bg.ssm.switch"), "Flip switch=Flip the track switch|Hold switch=Hold the track switch|"
        .. "INC=INC at the track switch|Clear=The track switch is clear")
    assertEqual(BI.callouts["bi.bg.ssm.escort"].text, "Escort the cart", "the map-wide callouts stay")
end)

test("builtins: [bg buttons] Temple of Kotmogu has its four orbs and the center", function()
    local NS, BI = bi()
    -- red under: Temple of Kotmogu left flat in defaults/BuiltIns_Battlegrounds.lua
    assertEqual(childNames(BI, "bi.bg.tok"), "Orange orb,Blue orb,Green orb,Purple orb,Center")
    assertEqual(rows(BI, "bi.bg.tok.blue"), "Take orb=Take the blue orb|Peel=Peel for our blue orb carrier|"
        .. "Kill carrier=Kill their blue orb carrier {target}|Heals=Our blue orb carrier needs heals")
    assertEqual(rows(BI, "bi.bg.tok.center"), "Go center=Bring the orbs to the center|Hold center=Hold the center|"
        .. "INC=INC center|Clear=The center is clear")
    for _, color in ipairs({ "orange", "blue", "green", "purple" }) do
        assertEqual(BI.groups["bi.bg.tok." .. color].iconColor, BI.COLOR[color], color .. " orb draws its color")
    end
    -- the {target} a row's %s fill leaves for the bake
    local line = NS.Bake.Bake(BI.callouts["bi.bg.tok.green.kill"], BI.SNAPSHOTS["bi.bg.tok"],
        { ctx = { target = "Traxex" } })
    assertTrue(line:find("Kill their green orb carrier", 1, true) ~= nil, line)
    assertEqual(BI.callouts["bi.bg.tok.mid"].text, "Orbs to the middle", "the map-wide callouts stay")
end)

test("builtins: no shipped callout types a raw %t or %f: each uses the {target} / {focus} chip", function()
    local _, BI = bi()
    local raw = {}
    for cid, c in pairs(BI.callouts) do
        -- red under: a shipped text with a typed %t (owner, 2026-10-22: {target})
        if c.text:find("%%[tf]") then raw[#raw + 1] = cid end
    end
    table.sort(raw)
    assertEqual(table.concat(raw, ","), "", "every target token is the chip")
end)

test("builtins: [bg buttons] In Group is a party, raid and instance group set of short smart-group lines", function()
    local NS, BI = bi()
    local g = BI.groups["bi.group"]
    -- red under: no defaults/BuiltIns_Group.lua (or no TOC line for it)
    assertTrue(g ~= nil, "the set exists")
    assertEqual(g.name, "In Group")
    assertTrue(g.when.group.party and g.when.group.raid and g.when.group.instance, "Party, Raid, Instance group")
    assertNil(g.when.group.solo)
    assertNil(g.when.content, "no content condition")
    assertEqual(rows(BI, "bi.group"), "Hello=Hello!|At Stone=At stone, WM off.|Summon=Summon please!|Buffs please=Buffs please!|"
        .. "Healthstone=Healthstone please!|tyff=tyff|brb=brb|Ready=Ready|GLHF=GLHF!|ggty=ggty|ggnt=ggnt")
    for _, cid in ipairs(g.callouts) do assertEqual(BI.callouts[cid].channel, "smartGroup", cid) end
    assertEqual(g.glyph, "ph:users-three")
    local snap = BI.SNAPSHOTS["bi.group"]
    assertEqual(snap.group, "party", "the bake audit checks it in a party")
    assertEqual(NS.Bake.Bake(BI.callouts["bi.group.glhf"], snap, { ctx = {} }), "/p GLHF!")
    -- active in a party, a raid and a battleground's instance group; not solo
    local R = NS.Resolver
    assertTrue(R.Matches(g.when, { group = "party" }))
    assertTrue(R.Matches(g.when, { group = "raid" }))
    assertTrue(R.Matches(g.when, { group = "raid", instanceGroup = true, content = "battleground" }))
    assertTrue(not R.Matches(g.when, { group = "solo" }), "not solo")
end)

test("builtins: a faction-themed battleground's locations take the faction's color, neutral ones gold", function()
    local _, BI = bi()
    local C = BI.COLOR
    assertEqual(C.alliance, "2aa2ff")
    assertEqual(C.horde, "ff4040")
    assertEqual(C.neutral, "ffd100")
    local function color(id) return BI.groups[id].iconColor end
    local want = {
        alliance = { "vanndar", "balinda", "dbnorth", "dbsouth", "icewing", "shbunker", "spgy", "shgy", "aidstation" },
        horde = { "drekthar", "galvangar", "ibtower", "towerpoint", "wfw", "efw", "ibgy", "fwgy", "reliefhut" },
        neutral = { "snowfall" },
    }
    local n = 0
    for side, keys in pairs(want) do
        for _, key in ipairs(keys) do
            n = n + 1
            -- red under: an Alterac Valley location left white or green
            assertEqual(color("bi.bg.av." .. key), C[side], key)
        end
    end
    assertEqual(n, #BI.groups["bi.bg.av"].children, "every Alterac Valley location is themed")
    assertEqual(color("bi.bg.eots.draenei"), C.alliance)
    assertEqual(color("bi.bg.eots.bloodelf"), C.horde)
    assertEqual(color("bi.bg.eots.felreaver"), C.horde, "Horde-owned")
    assertEqual(color("bi.bg.eots.magetower"), C.alliance, "Alliance-owned")
    assertEqual(color("bi.bg.ashran.glory"), C.neutral)
    -- the actions under a location keep their own tints
    assertEqual(BI.callouts["bi.bg.av.dbnorth.attack"].iconColor, C.crimson)
    assertEqual(BI.callouts["bi.bg.av.dbnorth.defend"].iconColor, C.cyan)
end)

test("builtins: a neutral battleground's locations take a color for what they are, never white", function()
    local _, BI = bi()
    local C = BI.COLOR
    local function color(id) return BI.groups[id].iconColor end
    assertEqual(color("bi.bg.ab.stables"), C.brown, "a horse")
    assertEqual(color("bi.bg.dwg.quarry"), C.stone)
    assertEqual(color("bi.bg.ioc.quarry"), C.stone)
    assertEqual(color("bi.bg.ioc.hangar"), C.sky, "an airplane")
    assertEqual(color("bi.bg.wsg.mid"), C.brown, "a road")
    assertEqual(color("bi.bg.tp.mid"), C.stone, "a stone bridge")
    for id, g in pairs(BI.groups) do
        -- red under: any battleground location shipped white
        if id:match("^bi%.bg%.") then assertTrue(g.iconColor ~= C.white, id) end
    end
    for id, c in pairs(BI.callouts) do
        if id:match("^bi%.bg%.") then assertTrue(c.iconColor ~= C.white, id) end
    end
end)

-- ── the Emotes set (QFE-E3, QuickComms#15, design 5.3) ──────────────────────────────────────

-- The seed, voice then social (design 5.3), by token.
local VOICE = { "INCOMING", "CHARGE", "ATTACKMYTARGET", "OPENFIRE", "OOM", "HEALME", "HELPME", "FLEE", "WAIT",
    "FOLLOW" }
local SOCIAL = { "WAVE", "HELLO", "THANK", "CHEER", "BOW", "POINT", "DANCE", "READY", "LAUGH", "BYE" }

test("builtins: [QFE-E3] Emotes is an open-world set of game emotes, voice then social, no text", function()
    local _, BI = bi()
    local g = BI.groups["bi.emotes"]
    -- red under: no defaults/BuiltIns_Emotes.lua
    assertTrue(g ~= nil, "the set exists")
    assertEqual(g.name, "Emotes")
    assertTrue(g.when.content.openWorld, "the open world")
    assertNil(g.when.group, "in any group size")
    assertEqual(#g.callouts, #VOICE + #SOCIAL)
    for n, cid in ipairs(g.callouts) do
        local c = BI.callouts[cid]
        assertEqual(c.emote, n <= #VOICE and VOICE[n] or SOCIAL[n - #VOICE], cid)
        assertEqual(c.channel, "gameEmote", cid)
        assertEqual(c.text, "", cid .. ": one action, no text (R7)")
    end
end)

test("builtins: [QFE-E3] every seeded emote token exists on both clients; the voice ones are speech emotes", function()
    local _, BI = bi()
    local speech = {}
    for _, token in ipairs(EMOTES.speech) do speech[token] = true end
    for n, cid in ipairs(BI.groups["bi.emotes"].callouts) do
        local token = BI.callouts[cid].emote
        -- red under: a token only one client's ChatEmoteConstants.lua has (ATTACKTARGET, LOL)
        assertTrue(EMOTES.retail[token] ~= nil, token .. " on Retail")
        assertTrue(EMOTES.forever[token] ~= nil, token .. " on WoW Forever")
        assertEqual(EMOTES.retail[token], EMOTES.forever[token], token .. " at the same index")
        if n <= #VOICE then assertTrue(speech[token], token .. " plays a voice line") end
    end
end)

test("builtins: [QFE-E3] each seeded emote bakes to the client's own command", function()
    local NS, env = T.newAddon()
    plantEmotes(NS, env)
    local BI, snap = NS.BuiltIns, NS.BuiltIns.SNAPSHOTS["bi.emotes"]
    for _, cid in ipairs(BI.groups["bi.emotes"].callouts) do
        local c = BI.callouts[cid]
        local line = NS.Bake.Bake(c, snap, { ctx = {} })
        assertEqual(line, EMOTES.commands[EMOTES[CLIENT][c.emote]], cid)
    end
    assertEqual(NS.Bake.Bake(BI.callouts["bi.emotes.oom"], snap, { ctx = {} }), "/oom")
    assertEqual(NS.Bake.Bake(BI.callouts["bi.emotes.follow"], snap, { ctx = {} }), "/followme", "FOLLOW's own first command")
end)

test("builtins: [QFE-E3] a fresh profile seeds Emotes after Solo; Restore built-in groups brings it back", function()
    local NS = T.enableAddon()
    local p, Lib = NS.db.profile, NS.Library
    local id, world = T.seeded(NS, "bi.emotes"), T.seeded(NS, "bi.world")
    assertTrue(id ~= nil, "seeded")
    local list = p.pads[p.padOrder[1]].groups
    local at, worldAt
    for i, gid in ipairs(list) do
        if gid == id then at = i elseif gid == world then worldAt = i end
    end
    assertEqual(at, worldAt + 1, "right after the World set on the pad")
    assertEqual(p.callouts[p.groups[id].callouts[1]].emote, "INCOMING", "the callout keeps its token")
    assertTrue(Lib.DeleteGroup(id))
    Lib.Prepare()
    assertNil(T.seeded(NS, "bi.emotes"), "deleted stays deleted")
    local n = Lib.RestoreBuiltins()
    -- red under: Restore walking a list that leaves bi.emotes out
    assertEqual(n.groups, 1, "the one set back")
    local back = T.seeded(NS, "bi.emotes")
    assertTrue(back ~= nil, "back")
    assertEqual(#p.groups[back].callouts, #VOICE + #SOCIAL, "with every callout")
    assertEqual(p.callouts[p.groups[back].callouts[#VOICE + #SOCIAL]].emote, "BYE")
end)

-- ── extra action fields and the integrity row (CA-M1-6, spec §2) ──────────────────────────────

-- One line per shipped callout of `prefix`, every field in key order, for a byte-for-byte pin.
local function fingerprint(BI, prefix)
    local ids = {}
    for id in pairs(BI.callouts) do if id:sub(1, #prefix) == prefix then ids[#ids + 1] = id end end
    table.sort(ids)
    local lines = {}
    for _, id in ipairs(ids) do
        local c, keys = BI.callouts[id], {}
        for k in pairs(c) do keys[#keys + 1] = k end
        table.sort(keys)
        local parts = { id }
        for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(c[k]) end
        lines[#lines + 1] = table.concat(parts, ";")
    end
    local text = table.concat(lines, "\n")
    local a, b = 1, 0
    for i = 1, #text do a = (a + text:byte(i)) % 65521; b = (b + a) % 65521 end
    return #ids, #text, b * 65536 + a
end

test("builtins: [CA-M1-6] BI.Callout takes extra action fields, and BI.Callouts rows take them as r[6]", function()
    local _, BI = bi()
    -- red under: BI.Callout without its `extra` argument
    local id = BI.Callout("bi.test", "ping", "Ping", "", "gameEmote", nil, nil, { ping = "attack", marker = 8 })
    assertEqual(BI.callouts[id].ping, "attack")
    assertEqual(BI.callouts[id].marker, 8)
    local ids = BI.Callouts("bi.test", "gameEmote", { { "wave", "Wave", "", nil, nil, { emote = "WAVE" } } })
    assertEqual(BI.callouts[ids[1]].emote, "WAVE")
    assertNil(BI.callouts[ids[1]].extra, "the fields, not the table")
    BI.callouts[id], BI.callouts[ids[1]] = nil, nil
end)

test("builtins: [CA-M1-6] the Emotes set's data is as it shipped", function()
    local _, BI = bi()
    local n, len, sum = fingerprint(BI, "bi.emotes.")
    -- red under: any change to a shipped emote callout's fields (the move to `extra` changes none)
    -- Taken before the move, on both kit profiles (the icon paths are one catalog's).
    assertEqual(n .. "/" .. len .. "/" .. sum, "20/3604/676677894")
end)

test("builtins: [CA-M1-6] every shipped callout passes the callout check and holds an action", function()
    local NS, BI = bi()
    for id, c in pairs(BI.callouts) do
        -- red under: a shipped callout with no Line, emote, ping or marker, or a bad ping or marker
        local ok, why = NS.Library.ValidCallout(c)
        assertTrue(ok, id .. ": " .. tostring(why))
        assertTrue(NS.Library.HasAction(c), id .. " holds an action")
        assertTrue(NS.Library.ValidPing(c.ping) and NS.Library.ValidMarker(c.marker), id)
    end
end)

test("builtins: [CA-M1-6] no seeded callout keeps the catalog glyph name", function()
    local NS = T.bootAddon()
    for id, c in pairs(NS.db.profile.callouts) do
        assertNil(c.glyph, id)
    end
end)
