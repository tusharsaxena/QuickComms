-- tests/test_dial_layout.lua — modules/Dial_Layout.lua (spec §11.1, §11.3): the rings a dial's groups
-- make (Categories, Flat, open-into, pages behind More) and the wedges' geometry. Pure.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertNil = T.test, T.assertEqual, T.assertNil

local function DL() return T.newAddon().DialLayout end

local function slots(prefix, n)
    local out = {}
    for i = 1, n do out[i] = { calloutId = prefix .. i, name = prefix .. " " .. i } end
    return out
end

local function titles(ring)
    local out = {}
    for i, item in ipairs(ring.items) do out[i] = item.title end
    return table.concat(out, ",")
end

-- Arathi Basin as a dial plan hands it over: five nodes, four callouts each, open-into on.
local function ab()
    local children = {}
    for i, node in ipairs({ "Stables", "Lumber Mill", "Blacksmith", "Gold Mine", "Farm" }) do
        local s = {}
        for k, word in ipairs({ "Attack", "Defend", "INC", "Clear" }) do
            s[k] = { calloutId = node .. k, name = word, line = "/i " .. word .. " " .. node }
        end
        children[i] = { id = "n" .. i, title = node, slots = s }
    end
    return { id = "bi.bg.ab", title = "Arathi Basin", openInto = true, children = children }
end

test("dial layout: four wedges sit on N, E, S and W, clockwise from the top", function()
    local L = DL()
    local pts = {}
    for i = 1, 4 do
        local w = L.Wedge(i, 4)
        pts[i] = w.x .. "," .. w.y
    end
    assertEqual(table.concat(pts, " "), "0,92 92,0 0,-92 -92,0")
    assertEqual(L.Wedge(2, 4).lx, L.WEDGE / 2 + L.LABEL_GAP, "the label sits outward from the wedge")
    assertEqual(L.Direction(1, 4) .. L.Direction(2, 4) .. L.Direction(3, 4) .. L.Direction(4, 4), "NESW")
    assertEqual(L.Direction(2, 8), "NE")
end)

test("dial layout: slices are 4, 6, 8 or 12, and 12 only on a ring with no children", function()
    local L = DL()
    assertEqual(L.ClampSlices(6), 6)
    assertEqual(L.ClampSlices(5), 4)
    assertEqual(L.ClampSlices(nil), 4)
    assertEqual(L.RingSize(12, false), 12)
    assertEqual(L.RingSize(12, true), 8)
    assertEqual(L.RingSize(6, true), 6)
end)

test("dial layout: [review 5] more items than wedges go on pages: size-1 each, the rest on the last", function()
    local L = DL()
    local pages = L.Paginate({ 1, 2, 3, 4, 5, 6, 7, 8 }, 4)
    assertEqual(#pages, 3)
    assertEqual(table.concat(pages[1], ","), "1,2,3")
    assertEqual(table.concat(pages[2], ","), "4,5,6")
    assertEqual(table.concat(pages[3], ","), "7,8")
    assertEqual(#L.Paginate({ 1, 2, 3, 4 }, 4), 1, "a full ring needs no More")
end)

test("dial layout: [exit] Categories in Arathi Basin opens on the node ring; Lumber Mill, then INC", function()
    local L = DL()
    local generic = { id = "bi.bg", title = "Battleground (generic)", slots = slots("g", 6) }
    local rings, open = L.Rings({ ab(), generic }, { mode = "categories", slices = 4, title = "Comms Dial" })
    assertEqual(rings[1].title, "Comms Dial")
    assertEqual(titles(rings[1]), "Arathi Basin,Battleground (generic)")
    -- red under: drop the open-into branch at the end of DL.Rings
    assertEqual(rings[open].title, "Arathi Basin", "open-into: the first active group has the flag")
    assertEqual(rings[open].parent, 1, "the hub goes up to the group ring")
    assertEqual(titles(rings[open]), "Stables,Lumber Mill,Blacksmith,More")
    local mill = rings[rings[open].items[2].target]
    assertEqual(mill.title, "Lumber Mill")
    assertEqual(titles(mill), "Attack,Defend,INC,Clear", "four rows fill a four-wedge ring: no More")
    assertEqual(mill.items[3].slot.line, "/i INC Lumber Mill")
    assertEqual(rings[rings[open].items[4].target].prev, open, "More's page goes back")
end)

test("dial layout: without the flag first, Categories opens on the group ring; one group opens straight on it", function()
    local L = DL()
    local mplus = { id = "bi.mplus", title = "M+", slots = slots("m", 3) }
    local mine = { id = "g1", title = "Mine", slots = slots("c", 2) }
    local rings, open = L.Rings({ mine, mplus }, { slices = 4 })
    assertEqual(open, 1)
    assertEqual(rings[1].items[1].kind, "ring")
    assertEqual(rings[rings[1].items[2].target].title, "M+")
    rings, open = L.Rings({ mplus }, { slices = 4 })
    assertEqual(rings[open].title, "M+", "a single group: no stroke for a ring of one")
    assertEqual(rings[open].parent, 1)
end)

test("dial layout: [review 5] Flat puts every callout on the first ring, highest group first, with More pages", function()
    local L = DL()
    local rings, open = L.Rings({ ab(), { id = "x", title = "X", slots = slots("x", 2) } },
        { mode = "flat", slices = 8, title = "D" })
    assertEqual(open, 1)
    -- red under: title a Flat node callout with slot.name alone (five wedges would read "Attack")
    assertEqual(rings[1].items[1].title, "Attack · Stables", "a node's callout names its node")
    assertEqual(rings[1].items[1].slot.name, "Attack", "the slot itself is unchanged")
    assertEqual(rings[1].items[8].title, "More")
    assertEqual(rings[1].next, 2)
    assertEqual(rings[2].prev, 1)
    assertEqual(rings[2].parent, 1, "the hub goes back a page")
    local total = 0
    for _, r in ipairs(rings) do
        for _, item in ipairs(r.items) do
            if item.kind == "send" then total = total + 1 end
        end
    end
    assertEqual(total, 22, "every callout reachable")
end)

test("dial layout: [phase 4] a node set below another active group is three rings deep, and named for the warning", function()
    local L = DL()
    local mine = { id = "g1", title = "Mine", slots = slots("c", 2) }
    local rings, open = L.Rings({ mine, ab() }, { slices = 4, title = "D" })
    assertEqual(open, 1, "the first group has no open-into")
    assertEqual(rings[1].depth, 1)
    -- red under: answer {} from DL.DeepGroups
    assertEqual(table.concat(L.DeepGroups(rings, open), ","), "Arathi Basin", "named once, though paged")
    rings, open = L.Rings({ ab(), mine }, { slices = 4 })
    assertEqual(#L.DeepGroups(rings, open), 0, "open-into: the nodes are the ring it opens on")
    rings, open = L.Rings({ mine, ab() }, { mode = "flat", slices = 4 })
    assertEqual(#L.DeepGroups(rings, open), 0, "Flat has no depth")
end)

test("dial layout: nothing to show is no ring at all; an empty group is left out", function()
    local L = DL()
    local rings, open = L.Rings({}, {})
    assertEqual(#rings, 0)
    assertEqual(open, 0)
    rings = L.Rings({ { id = "e", title = "Empty", slots = {} } }, {})
    assertEqual(#rings, 0)
end)

test("dial layout: the pointer follows the cursor outside the dead zone", function()
    local L = DL()
    assertNil((L.Pointer(100, 100, 102, 101)))
    local a, x, y = L.Pointer(100, 100, 200, 100)
    assertEqual(math.floor(a * 1000 + 0.5), 1571, "east is a quarter turn clockwise")
    assertEqual(x, L.POINTER)
    assertEqual(y, 0)
end)

test("dial layout: [final 6] a label is anchored by its side, clear of its wedge; the ring title clears the N label", function()
    local L = DL()
    local edge = L.WEDGE / 2 + L.LABEL_GAP
    local want = { { "BOTTOM", 0, edge }, { "LEFT", edge, 0 }, { "TOP", 0, -edge }, { "RIGHT", -edge, 0 } }
    for i = 1, 4 do
        local w = L.Wedge(i, 4)
        -- red under: center every label at DL.LABEL outward
        assertEqual(w.anchor .. " " .. w.lx .. "," .. w.ly, want[i][1] .. " " .. want[i][2] .. "," .. want[i][3], i)
    end
    assertEqual(L.Wedge(2, 12).anchor, "LEFT", "1 o'clock reads to the right")
    assertEqual(L.Wedge(12, 12).anchor, "RIGHT")
    T.assertTrue(L.TITLE >= L.RADIUS + edge + L.LINE, "the title sits above the N wedge's label")
end)

test("dial layout: [final 20] past eight wedges each gets its own direction, as a clock position", function()
    local L = DL()
    local seen, words = {}, {}
    for i = 1, 12 do
        local d = L.Direction(i, 12)
        -- red under: round 12 slices onto the eight winds (2 and 3 are both NE)
        assertNil(seen[d], d)
        seen[d] = true
        words[i] = d
    end
    assertEqual(table.concat(words, " "), "12 1 2 3 4 5 6 7 8 9 10 11")
    assertEqual(L.Direction(2, 8), "NE", "eight or fewer keep the winds")
end)

-- Arathi Basin with its nodes' winds, as defaults/BuiltIns_Battlegrounds.lua ships them.
local AB_WINDS = { "NW", "SW", "middle", "NE", "SE" }
local function abPinned()
    local g = ab()
    for i, c in ipairs(g.children) do c.compass = AB_WINDS[i] end
    return g
end

test("dial layout: [phase 5] a node set's nodes sit on their compass winds; the middle node takes N", function()
    local L = DL()
    local rings, open = L.Rings({ abPinned() }, { mode = "categories", slices = 4, title = "Comms Dial" })
    local ring = rings[open]
    assertEqual(ring.title, "Arathi Basin")
    assertEqual(ring.size, 8, "eight winds, whatever the dial's slices")
    assertEqual(ring.pages, 1, "never paged: no More")
    local at = {}
    for _, item in ipairs(ring.items) do at[#at + 1] = item.title .. "@" .. L.Direction(item.wedge, ring.size) end
    assertEqual(table.concat(at, ","), "Blacksmith@N,Gold Mine@NE,Farm@SE,Lumber Mill@SW,Stables@NW")
    local mill = rings[ring.items[4].target]
    assertEqual(mill.title, "Lumber Mill")
    assertEqual(mill.size, 4, "a node's own ring keeps the dial's slices")
    assertEqual(mill.items[3].slot.line, "/i INC Lumber Mill", "still two clicks to INC Lumber Mill")
end)

test("dial layout: [polish] a node set's own callouts take one wedge on the first free wind; the nodes stay pinned", function()
    local L = DL()
    local g = abPinned()
    g.slots = {}
    for k, word in ipairs({ "Hold", "Zerg", "Ninja", "Rotate", "Ahead" }) do
        g.slots[k] = { calloutId = "own" .. k, name = word, line = "/i " .. word }
    end
    local rings, open = L.Rings({ g }, { mode = "categories", slices = 4 })
    local ring = rings[open]
    -- red under: put a parent's own callouts first on an unpinned ring in modules/Dial_Layout.lua
    assertEqual(ring.size, 8, "still the eight winds")
    local at = {}
    for _, item in ipairs(ring.items) do at[#at + 1] = item.title .. "@" .. L.Direction(item.wedge, ring.size) end
    assertEqual(table.concat(at, ","), "Blacksmith@N,Gold Mine@NE,Arathi Basin@E,Farm@SE,Lumber Mill@SW,Stables@NW")
    local own = rings[ring.items[3].target]
    assertEqual(own.title, "Arathi Basin")
    assertEqual(own.items[1].slot.line, "/i Hold", "the set's own callouts, on the dial's slices")
end)

test("dial layout: [review 6] [phase 5] nodes that cannot all be pinned keep their shipped order", function()
    local L = DL()
    assertNil(L.PinNodes({ { wind = "N" }, { wind = "N" } }), "two on one wind")
    assertNil(L.PinNodes({ { wind = "N" }, { wind = "up" } }), "an unknown wind")
    assertNil(L.PinNodes({ { wind = "N" }, {} }), "a node with none")
    assertNil(L.PinNodes({}), "none")
    local g = abPinned()
    g.children[2].compass = nil
    local rings, open = L.Rings({ g }, { slices = 4 })
    assertEqual(titles(rings[open]), "Stables,Lumber Mill,Blacksmith,More")
    local two = L.PinNodes({ { wind = "middle", name = "mid" }, { wind = "N", name = "north" } })
    assertEqual(two[1].name .. two[1].wedge .. "," .. two[2].name .. two[2].wedge, "north1,mid2",
        "N is taken, so the middle node takes NE")
end)

test("dial layout: [bg subgroups] a free node takes a wind left after the middle ones; the set's own wedge keeps its place", function()
    local L = DL()
    local g = abPinned()
    g.slots = slots("own", 3)
    for _, name in ipairs({ "Our base", "Enemy base" }) do
        g.children[#g.children + 1] = { id = name, title = name, compass = "free", slots = slots(name, 2) }
    end
    local rings, open = L.Rings({ g }, { mode = "categories", slices = 4 })
    local ring = rings[open]
    -- red under: drop the `free` wind from modules/Dial_Layout.lua PinNodes (the set unpins)
    assertEqual(ring.size, 8, "still pinned")
    local at = {}
    for _, item in ipairs(ring.items) do at[#at + 1] = item.title .. "@" .. L.Direction(item.wedge, ring.size) end
    assertEqual(table.concat(at, ","),
        "Blacksmith@N,Gold Mine@NE,Arathi Basin@E,Farm@SE,Our base@S,Lumber Mill@SW,Enemy base@W,Stables@NW")
    assertNil(L.PinNodes({ { wind = "free" }, { wind = "free" }, { wind = "free" }, { wind = "free" },
        { wind = "free" }, { wind = "free" }, { wind = "free" }, { wind = "free" }, { wind = "free" } }),
        "nine cannot all be pinned")
end)

test("dial layout: [bg subgroups] a set with more children than winds falls back to its unpinned, paged ring", function()
    local L = DL()
    local children = {}
    for i = 1, 19 do
        children[i] = { id = "av" .. i, title = "Node " .. i, slots = slots("n" .. i .. "x", 2) }
    end
    local g = { id = "bi.bg.av", title = "Alterac Valley", openInto = true, children = children, slots = slots("own", 4) }
    local rings, open = L.Rings({ g }, { mode = "categories", slices = 4 })
    local ring = rings[open]
    -- red under: pin a set whose children carry no winds in modules/Dial_Layout.lua groupEntry
    assertEqual(ring.title, "Alterac Valley", "opens into the set")
    assertEqual(ring.size, 4, "the dial's slices: not the eight winds")
    assertEqual(titles(ring), "own 1,own 2,own 3,More", "its own callouts first")
    -- 4 own + 19 nodes = 23 items: seven pages of three and a More, then the last two
    assertEqual(ring.pages, 8)
    local page, seen = ring, {}
    while true do
        for _, item in ipairs(page.items) do
            if item.kind == "ring" and not item.more then seen[#seen + 1] = item.title end
        end
        local last = page.items[#page.items]
        if not last.more then break end
        page = rings[last.target]
    end
    assertEqual(#seen, 19, "every node is reachable")
    assertEqual(seen[1] .. "," .. seen[19], "Node 1,Node 19", "in the set's order")
    local two = rings[ring.items[#ring.items].target]
    assertEqual(titles(two), "own 4,Node 1,Node 2,More", "the nodes follow the set's own callouts")
    local node = two.items[2]
    assertEqual(rings[node.target].items[2].slot.name, "n1x 2", "two clicks past the page to Defend")
end)

test("dial layout: [review 6] a pinned ring ignores the dial's slices; Flat keeps its paging", function()
    local L = DL()
    for _, slices in ipairs({ 4, 6 }) do
        local rings, open = L.Rings({ abPinned() }, { mode = "categories", slices = slices })
        assertEqual(rings[open].size, 8, slices .. " slices: the pinned ring has eight wedges")
        assertEqual(#rings[open].items, 5, slices .. " slices: every node on the one ring, no More")
    end
    -- red under: make shape() answer the pinned shape for every ring in modules/Dial_Layout.lua
    local rings, open = L.Rings({ abPinned() }, { mode = "flat", slices = 4 })
    assertEqual(rings[open].size, 4, "Flat lists the callouts on the dial's own slices")
    assertEqual(rings[open].pages > 1, true, "and pages them behind More")
    for _, item in ipairs(rings[open].items) do assertNil(item.wedge, "nothing in Flat is pinned") end
end)

test("dial layout: [icons] a ring entry carries its group's icon color, a send entry its callout's", function()
    local L = DL()
    local group = { id = "g", title = "G", icon = "glyph", iconColor = "ff0000",
        slots = { { calloutId = "c", name = "C", icon = "glyph", iconColor = "00ff00" } } }
    local rings = L.Rings({ group, { id = "x", title = "X", slots = slots("x", 1) } }, { slices = 8, title = "D" })
    local ring, send
    for _, r in ipairs(rings) do
        for _, item in ipairs(r.items) do
            if item.kind == "ring" and item.title == "G" then ring = item end
            if item.kind == "send" and item.title == "C" then send = item end
        end
    end
    -- red under: ringEntry / sendEntries without iconColor
    assertEqual(ring and ring.iconColor, "ff0000")
    assertEqual(send and send.iconColor, "00ff00")
end)
