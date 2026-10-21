-- tests/test_dial_layout.lua — modules/Dial_Layout.lua (spec §11.1, §11.3): the rings a dial's groups
-- make (Categories, Flat, a lone group opened into, pages turned by the arrows), Auto's wedge shapes
-- and the wedges' geometry. Pure.

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

-- Arathi Basin as a dial plan hands it over: five nodes, four callouts each.
local function ab()
    local children = {}
    for i, node in ipairs({ "Stables", "Lumber Mill", "Blacksmith", "Gold Mine", "Farm" }) do
        local s = {}
        for k, word in ipairs({ "Attack", "Defend", "INC", "Clear" }) do
            s[k] = { calloutId = node .. k, name = word, line = "/i " .. word .. " " .. node }
        end
        children[i] = { id = "n" .. i, title = node, slots = s }
    end
    return { id = "bi.bg.ab", title = "Arathi Basin", children = children }
end

test("dial layout: four wedges sit on N, E, S and W, clockwise from the top", function()
    local L = DL()
    local pts = {}
    for i = 1, 4 do
        local w = L.Wedge(i, 4)
        pts[i] = w.x .. "," .. w.y
    end
    assertEqual(table.concat(pts, " "), "0,100 100,0 0,-100 -100,0", "the default radius")
    assertEqual(L.Wedge(2, 4, 80).x, 80, "the dial's own radius")
    assertEqual(L.Wedge(2, 4, 999).x, L.RADIUS_MAX, "clamped to the row's range")
    assertEqual(L.Direction(1, 4) .. L.Direction(2, 4) .. L.Direction(3, 4) .. L.Direction(4, 4), "NESW")
    assertEqual(L.Direction(2, 8), "NE")
end)

test("dial layout: slices are Auto, 4, 6, 8 or 12; a page is 12 at most, 8 on a ring that holds rings", function()
    local L = DL()
    assertEqual(L.ClampSlices(6), 6)
    assertEqual(L.ClampSlices(5), L.AUTO, "anything else is Auto")
    assertEqual(L.ClampSlices(nil), L.AUTO)
    assertEqual(L.PageSize(12, false), 12)
    assertEqual(L.PageSize(12, true), 8)
    assertEqual(L.PageSize(6, true), 6)
    assertEqual(L.PageSize(L.AUTO, false), 12, "Auto spreads up to twelve")
    assertEqual(L.PageSize(L.AUTO, true), 8)
end)

test("dial layout: [auto] one wedge is W, two W and E, three W, N and E, four W, N, E and S; more spread from W", function()
    local L = DL()
    local function at(n)
        local size, start = L.PageShape(L.AUTO, 12, n)
        local out = {}
        for i = 1, n do out[i] = L.Direction(i, size, start) end
        return table.concat(out, " ")
    end
    -- red under: start Auto at N in modules/Dial_Layout.lua PageShape
    assertEqual(at(1), "W")
    assertEqual(at(2), "W E")
    -- red under: give three items a three-wedge ring (W, NE, SE)
    assertEqual(at(3), "W N E", "S is left empty")
    assertEqual(select(1, L.PageShape(L.AUTO, 12, 3)), 4, "three take a four-wedge ring")
    assertEqual(at(4), "W N E S")
    assertEqual(at(8), "W NW N NE E SE S SW", "evenly spaced, clockwise from W")
    assertEqual(select(1, L.PageShape(L.AUTO, 12, 7)), 7, "one wedge per item past four")
    local size, start = L.PageShape(6, 6, 2)
    -- red under: start fixed counts at N in modules/Dial_Layout.lua PageShape
    assertEqual(size .. "," .. start, "6,270", "a fixed count keeps its wedges and starts at W")
end)

test("dial layout: [review 5] more items than wedges go on plain pages, the rest on the last", function()
    local L = DL()
    local pages = L.Paginate({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 4)
    assertEqual(#pages, 3)
    -- red under: keep the last wedge of each page for More in DL.Paginate
    assertEqual(table.concat(pages[1], ","), "1,2,3,4")
    assertEqual(table.concat(pages[2], ","), "5,6,7,8")
    assertEqual(table.concat(pages[3], ","), "9")
    assertEqual(#L.Paginate({ 1, 2, 3, 4 }, 4), 1, "a full ring is one page")
end)

test("dial layout: [nav] a paged ring's pill, dots and arrows sit in one row under the disc and its labels", function()
    local L = DL()
    local g = L.Geometry(100)
    local nav = L.Nav(3, 2, g)
    local P = L.PAGING
    -- red under: give every page the same width in DL.Nav
    assertEqual(table.concat(nav.widths, ","), P.dotSize .. "," .. P.pillWidth .. "," .. P.dotSize, "this page is the pill")
    assertEqual(nav.dots[2], 0, "centered")
    assertEqual(nav.dots[1], -nav.dots[3])
    T.assertTrue(nav.arrow > nav.dots[3] + P.dotSize, "the arrows clear the indicators")
    T.assertTrue(-nav.y - P.arrowSize / 2 >= g.disc / 2 + L.LABEL_GAP + L.LINE, "below the S wedge's label")
    T.assertTrue(L.Nav(3, 1, L.Geometry(100, 0)).y > nav.y, "with no labels the row comes up to the disc")
    T.assertTrue(L.Nav(3, 1, L.Geometry(150)).y < nav.y, "a bigger dial pushes it down")
    local pg = { offset = 30, arrowSize = 40, arrowGap = 25, dotSize = 10, pillWidth = 30, dotGap = 12 }
    local big = L.Nav(3, 1, g, pg)
    -- red under: read DL.PAGING in DL.Nav whatever the dial's Paging tab says
    assertEqual(big.y, -(g.below + 30 + 20), "the Paging tab's offset and arrow size")
    assertEqual(big.widths[1] .. "," .. big.widths[2], "30,10")
    assertEqual(big.arrow, (30 + 10 + 10 + 2 * 12) / 2 + 25 + 20)
end)

test("dial layout: [hit] a wedge's hit square fills its slice without reaching the hub or a neighbor", function()
    local L = DL()
    for _, n in ipairs({ 2, 4, 6, 8, 12 }) do
        local side = L.HitSize(n, 100)
        T.assertTrue(side >= L.WEDGE, n .. ": never under the wedge")
        T.assertTrue(100 - side / 2 >= L.HUB / 2, n .. ": clear of the hub")
        local a, b = L.Wedge(1, n, 100), L.Wedge(2, n, 100)
        T.assertTrue(math.max(math.abs(a.x - b.x), math.abs(a.y - b.y)) >= side, n .. ": clear of its neighbor")
    end
    -- the Icon offset moves the wedges in; the square still clears the hub and the rim
    local w = L.Wedge(2, 4, 100, 0, nil, 60)
    assertEqual(w.x, 60, "the icon sits at its offset, the disc keeps the radius")
    T.assertTrue(60 - L.HitSize(4, 100, 0, 60) / 2 >= L.HUB / 2, "clear of the hub at the offset")
    -- red under: answer DL.WEDGE from DL.HitSize (the old 44-pixel target)
    T.assertTrue(L.HitSize(4, 100) > L.WEDGE + 20, "a quarter slice gets a big square")
    T.assertTrue(L.PointerReach(30) > L.PointerReach(16), "a bigger pointer sits further out")
end)

test("dial layout: [exit] Categories with several groups opens on the ring of groups; a group wedge opens its ring", function()
    local L = DL()
    local generic = { id = "bi.bg", title = "Battleground (generic)", slots = slots("g", 6) }
    local rings, open = L.Rings({ ab(), generic }, { mode = "categories", slices = 4, title = "Comms Dial" })
    -- red under: open on the first group's ring in DL.Rings
    assertEqual(open, 1, "two groups: the selector first")
    assertEqual(rings[1].title, "Comms Dial")
    assertEqual(titles(rings[1]), "Arathi Basin,Battleground (generic)")
    local set = rings[rings[1].items[1].target]
    assertEqual(set.title, "Arathi Basin")
    assertEqual(set.parent, 1, "the hub goes up to the group ring")
    assertEqual(titles(set), "Stables,Lumber Mill,Blacksmith,Gold Mine")
    local mill = rings[set.items[2].target]
    assertEqual(mill.title, "Lumber Mill")
    assertEqual(titles(mill), "Attack,Defend,INC,Clear")
    assertEqual(mill.items[3].slot.line, "/i INC Lumber Mill")
    local two = rings[set.next]
    assertEqual(titles(two), "Farm", "the fifth node on page 2, no More wedge")
    assertEqual(two.prev, rings[1].items[1].target)
    assertEqual(two.parent, 1, "every page goes up to the same ring")
end)

test("dial layout: several groups open on the group ring; one group opens straight on it", function()
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
    rings, open = L.Rings({ mplus, { id = "e", title = "Empty", slots = {} } }, {})
    assertEqual(rings[open].title, "M+", "an empty group is not a second group")
end)

test("dial layout: [review 5] Flat puts every callout on the first ring, highest group first, paged", function()
    local L = DL()
    local rings, open = L.Rings({ ab(), { id = "x", title = "X", slots = slots("x", 2) } },
        { mode = "flat", slices = 8, title = "D" })
    assertEqual(open, 1)
    -- red under: title a Flat node callout with slot.name alone (five wedges would read "Attack")
    assertEqual(rings[1].items[1].title, "Attack · Stables", "a node's callout names its node")
    assertEqual(rings[1].items[1].slot.name, "Attack", "the slot itself is unchanged")
    assertEqual(#rings[1].items, 8, "a full page, no More wedge")
    assertEqual(rings[1].next, 2)
    assertEqual(rings[2].prev, 1)
    assertEqual(rings[2].parent, 0, "the hub closes from any page of the first ring")
    local total = 0
    for _, r in ipairs(rings) do
        for _, item in ipairs(r.items) do
            if item.kind == "send" then total = total + 1 end
        end
    end
    assertEqual(total, 22, "every callout reachable")
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

test("dial layout: [final 6] a label is anchored by its side, wholly outside the disc; the ring title clears the N label", function()
    local L = DL()
    local g = L.Geometry(100)
    local want = { "BOTTOM", "LEFT", "TOP", "RIGHT" }
    for i = 1, 4 do
        local w = L.Wedge(i, 4)
        assertEqual(w.anchor, want[i], i)
        -- red under: anchor the label just past the wedge's edge (inside the disc)
        local d = math.sqrt((w.x + w.lx) ^ 2 + (w.y + w.ly) ^ 2)
        T.assertTrue(d >= g.disc / 2 + L.LABEL_GAP - 0.5, "label anchor outside the disc: " .. i)
    end
    assertEqual(L.Wedge(2, 12).anchor, "LEFT", "1 o'clock reads to the right")
    assertEqual(L.Wedge(12, 12).anchor, "RIGHT")
    T.assertTrue(g.title >= g.disc / 2 + L.LABEL_GAP + L.LINE, "the title sits above the N wedge's label")
    T.assertTrue(L.Geometry(100, 20).title > g.title, "a bigger label font lifts the title")
    T.assertTrue(L.Geometry(140).disc > g.disc, "the disc grows with the radius")
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
    assertEqual(ring.pages, 1, "never paged")
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
    assertEqual(titles(rings[open]), "Stables,Lumber Mill,Blacksmith,Gold Mine")
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
    local g = { id = "bi.bg.av", title = "Alterac Valley", children = children, slots = slots("own", 4) }
    local rings, open = L.Rings({ g }, { mode = "categories", slices = 4 })
    local ring = rings[open]
    -- red under: pin a set whose children carry no winds in modules/Dial_Layout.lua groupEntry
    assertEqual(ring.title, "Alterac Valley", "opens into the set")
    assertEqual(ring.size, 4, "the dial's slices: not the eight winds")
    assertEqual(titles(ring), "own 1,own 2,own 3,own 4", "its own callouts first")
    -- 4 own + 19 nodes = 23 items: five pages of four, then the last three
    assertEqual(ring.pages, 6)
    local page, seen = ring, {}
    while page do
        for _, item in ipairs(page.items) do
            if item.kind == "ring" then seen[#seen + 1] = item.title end
        end
        page = page.next > 0 and rings[page.next] or nil
    end
    assertEqual(#seen, 19, "every node is reachable")
    assertEqual(seen[1] .. "," .. seen[19], "Node 1,Node 19", "in the set's order")
    local two = rings[ring.next]
    assertEqual(titles(two), "Node 1,Node 2,Node 3,Node 4", "the nodes follow the set's own callouts")
    assertEqual(rings[two.items[1].target].items[2].slot.name, "n1x 2", "two clicks past the page to Defend")
end)

test("dial layout: [review 6] a pinned ring ignores the dial's slices; Flat keeps its paging", function()
    local L = DL()
    for _, slices in ipairs({ 4, 6 }) do
        local rings, open = L.Rings({ abPinned() }, { mode = "categories", slices = slices })
        assertEqual(rings[open].size, 8, slices .. " slices: the pinned ring has eight wedges")
        assertEqual(#rings[open].items, 5, slices .. " slices: every node on the one ring, one page")
    end
    -- red under: make shape() answer the pinned shape for every ring in modules/Dial_Layout.lua
    local rings, open = L.Rings({ abPinned() }, { mode = "flat", slices = 4 })
    assertEqual(rings[open].size, 4, "Flat lists the callouts on the dial's own slices")
    assertEqual(rings[open].pages > 1, true, "and pages them")
    for i, item in ipairs(rings[open].items) do assertEqual(item.wedge, i, "nothing in Flat is pinned: places in order") end
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

test("dial layout: [polish] fixed 4 places 1-4 items W; W,E; W,N,E; W,N,E,S", function()
    local L = DL()
    local want = { { 1 }, { 1, 3 }, { 1, 2, 3 }, { 1, 2, 3, 4 } }
    local dirs = { "W", "W E", "W N E", "W N E S" }
    for count = 1, 4 do
        local size, start, places = L.PageShape(4, 4, count)
        assertEqual(size .. "," .. start, "4,270", count .. ": four wedges from W")
        -- red under: give a fixed 4 ring places 1..count (two items at W and N)
        assertEqual(table.concat(places, ","), table.concat(want[count], ","), count .. " items' places")
        local out = {}
        for k = 1, count do out[k] = L.Direction(places[k], size, start) end
        assertEqual(table.concat(out, " "), dirs[count], count .. " items' directions")
    end
end)

test("dial layout: [polish] auto keeps its shapes from W", function()
    local L = DL()
    -- red under: a fixed-4 places table for Auto's two items (a four-wedge ring)
    assertEqual(select(1, L.PageShape(L.AUTO, 12, 1)), 1, "one item: the whole disc")
    local size, start, places = L.PageShape(L.AUTO, 12, 2)
    assertEqual(size .. "," .. start, "2,270")
    assertEqual(L.Direction(places[1], size, start) .. " " .. L.Direction(places[2], size, start), "W E")
    local three, _, placed = L.PageShape(L.AUTO, 12, 3)
    assertEqual(three, 4, "three take a four-wedge ring")
    assertEqual(table.concat(placed, ","), "1,2,3")
    size, start, places = L.PageShape(L.AUTO, 12, 5)
    assertEqual(size .. "," .. start, "5,270")
    assertEqual(table.concat(places, ","), "1,2,3,4,5")
end)

test("dial layout: [polish] fixed 8 with 2 items fills W then clockwise", function()
    local L = DL()
    local size, start, places = L.PageShape(8, 8, 2)
    assertEqual(size, 8, "a fixed count is never shrunk")
    assertEqual(table.concat(places, ","), "1,2")
    -- red under: start fixed counts at N in modules/Dial_Layout.lua PageShape
    assertEqual(L.Direction(places[1], size, start) .. " " .. L.Direction(places[2], size, start), "W NW")
end)

test("dial layout: [polish] slice shift", function()
    local L = DL()
    -- red under: shift a slice by the whole gap (no 1/sin(pi/n))
    assertEqual(L.SliceShift(0, 4), 0, "no gap, no shift")
    assertEqual(L.SliceShift(10, 1), 0, "one slice has no gap")
    T.assertTrue(math.abs(L.SliceShift(10, 2) - 5) < 0.01, "two halves move gap/2 apart each")
    T.assertTrue(math.abs(L.SliceShift(10, 4) - 5 / math.sin(math.pi / 4)) < 0.01, "a quarter along its bisector")
end)

test("dial layout: [polish] auto cap", function()
    local L = DL()
    -- red under: ignore the icon size in DL.AutoCap (always MAX_SLICES)
    assertEqual(L.AutoCap(100, 0, 32, 0), 12, "today's defaults: no change")
    assertEqual(L.AutoCap(100, 0, 128, 0), 4, "128 px icons: four a page")
    -- red under: leave the gap out of DL.AutoCap
    assertEqual(L.AutoCap(100, 0, 32, 20), 11, "the gap eats into the arc")
    assertEqual(L.AutoCap(70, 0, 128, 20), 2)
    assertEqual(L.AutoCap(70, 0, 128, 300), 1, "never below one")
end)

test("dial layout: [polish] auto cap at 128 px pages the ring", function()
    local L = DL()
    local rings, open = L.Rings({ { id = "g", title = "G", slots = slots("c", 9) } },
        { slices = 0, fit = { radius = 100, iconOffset = 0, iconSize = 128, gap = 0 } })
    local ring = rings[open]
    -- red under: drop opts.fit in DL.Rings (one page of nine)
    assertEqual(ring.pages, 3, "nine items at four a page")
    assertEqual(#ring.items .. "," .. #rings[ring.next].items, "4,4")
    local three = rings[rings[ring.next].next]
    assertEqual(#three.items, 1)
    assertEqual(three.size, 1, "the last page's one item takes the whole disc")
    local plain = L.Rings({ { id = "g", title = "G", slots = slots("c", 9) } }, { slices = 0 })
    assertEqual(plain[1].pages, 1, "no fit: no cap")
end)

test("dial layout: [polish] SliceAt", function()
    local L = DL()
    local function at(angle, dist) return L.SliceAt(angle, dist, 4, 270, 40, 300) end
    -- red under: measure SliceAt's bearing from N instead of from the ring's start
    assertEqual(at(3 * math.pi / 2, 30), 1, "W")
    assertEqual(at(0, 30), 2, "N")
    assertEqual(at(math.pi / 2, 30), 3, "E")
    -- red under: no hub check in DL.SliceAt
    assertNil(at(0, 15), "inside the hub")
    assertNil(at(0, 151), "past the disc")
    assertEqual(at(7 * math.pi / 4 + 0.01, 30), 2, "just past the W/N boundary")
end)

test("dial layout: [polish] Rings gives every unpinned item its place", function()
    local L = DL()
    local rings, open = L.Rings({ { id = "g", title = "G", slots = slots("c", 2) } }, { slices = 4 })
    local ring = rings[open]
    -- red under: leave an unpinned item's wedge nil in DL.Rings (two items at W and N)
    assertEqual(ring.items[1].wedge .. "," .. ring.items[2].wedge, "1,3", "W and E")
    assertEqual(ring.start, 270)
end)
