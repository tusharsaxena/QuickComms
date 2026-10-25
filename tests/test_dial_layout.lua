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

test("dial layout: every ring carries its key, the path of group and node ids down to it", function()
    local L = DL()
    local function some(n)
        local out = {}
        for i = 1, n do out[i] = { name = "c" .. i } end
        return out
    end
    local rings = L.Rings({ { id = "g1", title = "One", slots = some(2) },
        { id = "g2", title = "Two", slots = some(9), children = { { id = "n1", title = "Node", slots = some(1) } } } },
        { slices = 4 })
    local keys = {}
    for r, ring in ipairs(rings) do keys[r] = ring.key .. "#" .. ring.page end
    assertEqual(table.concat(keys, " "), "root#1 root/g1#1 root/g2#1 root/g2/g2#1 root/g2/g2#2 root/g2/g2#3 root/g2/n1#1")
end)

test("dial layout: four wedges sit on N, E, S and W, clockwise from the top", function()
    local L = DL()
    local pts = {}
    for i = 1, 4 do
        local w = L.Wedge(i, 4, 100, nil, nil, nil, 40)
        pts[i] = w.x .. "," .. w.y
    end
    assertEqual(table.concat(pts, " "), "0,100 100,0 0,-100 -100,0", "radius 100 on a 40 hub")
    assertEqual(L.Wedge(2, 4).x, L.IconReach(L.RADIUS, 0), "the default radius")
    -- automatic Icon offset: the radius at 100 on a 40 hub, the same place in the slice elsewhere
    assertEqual(L.Wedge(2, 4, 80).x, L.IconReach(80, 0), "the dial's own radius")
    assertEqual(L.Wedge(2, 4, 999).x, L.IconReach(L.RADIUS_MAX, 0), "clamped to the row's range")
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

test("dial layout: [auto] one wedge per item, evenly spaced clockwise from N", function()
    local L = DL()
    local function at(n)
        local size, start = L.PageShape(L.AUTO, 12, n)
        local out = {}
        for i = 1, n do out[i] = L.Direction(i, size, start) end
        return table.concat(out, " ")
    end
    -- red under: START at W (270) in modules/Dial_Layout.lua (owner, 2026-10-22: from N)
    assertEqual(at(1), "N")
    assertEqual(at(2), "N S")
    -- red under: three items on a four-wedge ring (N, E, S, W empty)
    assertEqual(at(3), "N SE SW", "thirds: N, 120 and 240 degrees")
    assertEqual(select(1, L.PageShape(L.AUTO, 12, 3)), 3, "three take a three-wedge ring")
    assertEqual(at(4), "N E S W")
    assertEqual(at(8), "N NE E SE S SW W NW", "evenly spaced, clockwise from N")
    assertEqual(select(1, L.PageShape(L.AUTO, 12, 7)), 7, "one wedge per item")
    local size, start = L.PageShape(6, 6, 2)
    assertEqual(size .. "," .. start, "6,0", "a fixed count keeps its wedges and starts at N")
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

test("dial layout: [hit] the Icon offset moves the wedges in; a bigger pointer sits further out", function()
    local L = DL()
    local w = L.Wedge(2, 4, 100, 0, nil, 60)
    assertEqual(w.x, 60, "the icon sits at its offset, the disc keeps the radius")
    -- red under: keep DL.HitSize (the wedges' grown hit squares retired with the ring catcher)
    assertNil(L.HitSize, "no hit square: the ring's catcher clicks every point of a slice")
    T.assertTrue(L.PointerReach(30) > L.PointerReach(16), "a bigger pointer sits further out")
end)

test("dial layout: [exit] Categories with several groups opens on the ring of groups; a group wedge opens its ring", function()
    local L = DL()
    local generic = { id = "bi.bg", title = "Battleground", slots = slots("g", 6) }
    local rings, open = L.Rings({ ab(), generic }, { mode = "categories", slices = 4, title = "Comms Dial" })
    -- red under: open on the first group's ring in DL.Rings
    assertEqual(open, 1, "two groups: the selector first")
    assertEqual(rings[1].title, "Comms Dial")
    assertEqual(titles(rings[1]), "Arathi Basin,Battleground")
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

test("dial layout: a node set's ring has one slice per item under Auto: no empty slices", function()
    local L = DL()
    local rings, open = L.Rings({ ab() }, { mode = "categories", slices = 0, title = "Comms Dial" })
    local ring = rings[open]
    assertEqual(ring.title, "Arathi Basin")
    -- red under: pin the nodes on eight winds (until 2026-10-25: three of eight slices empty)
    assertEqual(ring.size, 5, "five nodes, five slices")
    assertEqual(ring.pages, 1)
    for i, item in ipairs(ring.items) do assertEqual(item.wedge, i, "places in order from N") end
    assertEqual(titles(ring), "Stables,Lumber Mill,Blacksmith,Gold Mine,Farm", "the plan's child order")
    local mill = rings[ring.items[2].target]
    assertEqual(mill.title, "Lumber Mill")
    assertEqual(mill.items[3].slot.line, "/i INC Lumber Mill", "still two clicks to INC Lumber Mill")
end)

test("dial layout: a node set's own callouts take one wedge, first, titled as the set", function()
    local L = DL()
    local g = ab()
    g.slots = {}
    for k, word in ipairs({ "Hold", "Zerg", "Ninja", "Rotate", "Ahead" }) do
        g.slots[k] = { calloutId = "own" .. k, name = word, line = "/i " .. word }
    end
    local rings, open = L.Rings({ g }, { mode = "categories", slices = 0 })
    local ring = rings[open]
    -- red under: a parent's own callouts one wedge each, before its nodes
    assertEqual(ring.size, 6, "the set's own wedge and five nodes")
    assertEqual(titles(ring), "Arathi Basin,Stables,Lumber Mill,Blacksmith,Gold Mine,Farm")
    local own = rings[ring.items[1].target]
    assertEqual(own.title, "Arathi Basin")
    assertEqual(own.items[1].slot.line, "/i Hold", "the set's own callouts, on their own ring")
    assertEqual(own.size, 5)
    local bare = { id = "g", title = "Plain", slots = slots("p", 3), children = { { id = "c", title = "Empty", slots = {} } } }
    local r2, o2 = L.Rings({ bare }, { slices = 0 })
    assertEqual(titles(r2[o2]), "p 1,p 2,p 3", "no child shown: a plain group, its callouts a wedge each")
end)

test("dial layout: a fixed slice count pages a node set's ring like any ring", function()
    local L = DL()
    local g = ab()
    g.slots = slots("own", 2)
    local rings, open = L.Rings({ g }, { mode = "categories", slices = 4 })
    local ring = rings[open]
    assertEqual(ring.size, 4, "the dial's slices")
    assertEqual(ring.pages, 2, "own wedge and five nodes: two pages of four")
    assertEqual(titles(ring), "Arathi Basin,Stables,Lumber Mill,Blacksmith")
    assertEqual(titles(rings[ring.next]), "Gold Mine,Farm")
    local rings6, open6 = L.Rings({ g }, { slices = 6 })
    assertEqual(rings6[open6].pages, 1, "six slices hold all six")
    -- Flat keeps its paging
    local flat, fo = L.Rings({ ab() }, { mode = "flat", slices = 4 })
    assertEqual(flat[fo].size, 4, "Flat lists the callouts on the dial's own slices")
    assertEqual(flat[fo].pages > 1, true, "and pages them")
end)

test("dial layout: [bg subgroups] a set with many children pages its ring, its own wedge first", function()
    local L = DL()
    local children = {}
    for i = 1, 19 do
        children[i] = { id = "av" .. i, title = "Node " .. i, slots = slots("n" .. i .. "x", 2) }
    end
    local g = { id = "bi.bg.av", title = "Alterac Valley", children = children, slots = slots("own", 4) }
    local rings, open = L.Rings({ g }, { mode = "categories", slices = 0 })
    local ring = rings[open]
    assertEqual(ring.title, "Alterac Valley", "opens into the set")
    assertEqual(ring.size, 8, "Auto: at most eight on a ring that holds rings")
    assertEqual(ring.items[1].title, "Alterac Valley", "its own callouts, one wedge, first")
    -- 1 own wedge + 19 nodes = 20 items: pages of eight, eight and four
    assertEqual(ring.pages, 3)
    local page, seen = ring, {}
    while page do
        for _, item in ipairs(page.items) do
            if item.title ~= "Alterac Valley" then seen[#seen + 1] = item.title end
        end
        page = page.next > 0 and rings[page.next] or nil
    end
    assertEqual(#seen, 19, "every node is reachable")
    assertEqual(seen[1] .. "," .. seen[19], "Node 1,Node 19", "in the plan's child order")
    local last = rings[rings[ring.next].next]
    assertEqual(last.size, 4, "the last page has one slice per item")
    assertEqual(rings[ring.items[2].target].items[2].slot.name, "n1x 2", "two clicks to Defend")
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

test("dial layout: [polish] fixed 4 places 1-4 items N; N,S; N,E,S; N,E,S,W", function()
    local L = DL()
    local want = { { 1 }, { 1, 3 }, { 1, 2, 3 }, { 1, 2, 3, 4 } }
    local dirs = { "N", "N S", "N E S", "N E S W" }
    for count = 1, 4 do
        local size, start, places = L.PageShape(4, 4, count)
        assertEqual(size .. "," .. start, "4,0", count .. ": four wedges from N")
        -- red under: give a fixed 4 ring places 1..count (two items at N and E)
        assertEqual(table.concat(places, ","), table.concat(want[count], ","), count .. " items' places")
        local out = {}
        for k = 1, count do out[k] = L.Direction(places[k], size, start) end
        assertEqual(table.concat(out, " "), dirs[count], count .. " items' directions")
    end
end)

test("dial layout: [polish] auto keeps its shapes from N", function()
    local L = DL()
    -- red under: a fixed-4 places table for Auto's two items (a four-wedge ring)
    assertEqual(select(1, L.PageShape(L.AUTO, 12, 1)), 1, "one item: the whole disc")
    local size, start, places = L.PageShape(L.AUTO, 12, 2)
    assertEqual(size .. "," .. start, "2,0")
    assertEqual(L.Direction(places[1], size, start) .. " " .. L.Direction(places[2], size, start), "N S")
    local three, _, placed = L.PageShape(L.AUTO, 12, 3)
    assertEqual(three, 3, "three take a three-wedge ring")
    assertEqual(table.concat(placed, ","), "1,2,3")
    size, start, places = L.PageShape(L.AUTO, 12, 5)
    assertEqual(size .. "," .. start, "5,0")
    assertEqual(table.concat(places, ","), "1,2,3,4,5")
end)

test("dial layout: [polish] fixed 8 with 2 items fills N then clockwise", function()
    local L = DL()
    local size, start, places = L.PageShape(8, 8, 2)
    assertEqual(size, 8, "a fixed count is never shrunk")
    assertEqual(table.concat(places, ","), "1,2")
    -- red under: START at W (270)
    assertEqual(L.Direction(places[1], size, start) .. " " .. L.Direction(places[2], size, start), "N NE")
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
    assertEqual(L.AutoCap(70, 0, 128, 20), 3, "automatic reach at 70 sits a little out of the radius")
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
    -- red under: leave an unpinned item's wedge nil in DL.Rings (two items at N and E)
    assertEqual(ring.items[1].wedge .. "," .. ring.items[2].wedge, "1,3", "N and S")
    assertEqual(ring.start, 0)
end)

-- ── crisp dial art (shine T1, 2026-10-21) ───────────────────────────────────────────────────────

test("dial layout: [art] DL.ARC is gone; every dial texture the dial modules name ships", function()
    local NS = T.newAddon()
    -- red under: DL.ARC kept for the hub's segment rings
    assertNil(NS.DialLayout.ARC, "no segment count")
    local function exists(path)
        local rel = path:gsub("^Interface\\AddOns\\QuickComms\\", ""):gsub("\\", "/")
        local fh = io.open(T.root .. "/" .. rel .. ".tga", "rb")
        if fh then fh:close() end
        return fh ~= nil, rel
    end
    local named = 0
    for _, mod in ipairs({ "Dial_Layout", "Dial_Slices", "Dial_Render", "Dial" }) do
        local fh = assert(io.open(T.root .. "/modules/" .. mod .. ".lua", "rb"))
        local src = fh:read("*a")
        fh:close()
        for name in src:gmatch('"(dial%-[%w%-]+)"') do
            named = named + 1
            local ok, rel = exists(NS.DialSlices.MEDIA .. name)
            T.assertTrue(ok, mod .. " names " .. rel)
        end
    end
    T.assertTrue(named >= 1, "the modules name their art")
    for n = 1, 12 do
        local ok, rel = exists(NS.DialSlices.SectorTexture(n))
        T.assertTrue(ok, rel)
    end
    for k = 1, #NS.DialRender.RING_STEPS do
        local ok, rel = exists(NS.DialRender.RingTexture(100, 99 * NS.DialRender.RING_STEPS[k]))
        T.assertTrue(ok, rel)
        T.assertTrue(rel:find("dial%-ring%-" .. k .. "$") ~= nil, "step " .. k .. ": " .. rel)
    end
    T.assertTrue(not exists(NS.DialSlices.MEDIA .. "dial-pill"), "the pill is retired")
end)

test("dial layout: [autofit] automatic Icon offset keeps the icon's place in the slice at any radius", function()
    local L = DL()
    -- the band an icon sits in: from the hub's edge to the disc's edge
    local function rel(radius, hub)
        hub = hub or L.HUB
        local edge = L.Geometry(radius).disc / 2
        return (L.IconReach(radius, 0, hub) - hub / 2) / (edge - hub / 2)
    end
    assertEqual(L.IconReach(100, 0, 40), 100, "radius 100 on a 40 hub keeps its place")
    -- red under: ICON_SHARE anchored on DL.RADIUS (the icons move out when the default radius did)
    assertEqual(L.IconReach(120, 0, 40), 113.11, "120 on a 40 hub: where its icons sat before it was the default")
    -- red under: ICON_SHARE anchored on DL.HUB (the band's share moves when the default hub did)
    assertEqual(L.IconReach(120, 0), 111.74, "the default 120 on the default 32 hub: the same share of the band")
    local ref = rel(100)
    for _, r in ipairs({ 70, 150, 180 }) do
        -- red under: automatic is the ring radius (rel 0.76 at 150, 0.78 at 180)
        T.assertTrue(math.abs(rel(r) - ref) < 0.005, ("radius %d: %.3f, want %.3f"):format(r, rel(r), ref))
    end
    T.assertTrue(L.IconReach(150, 0) < 140, "well inside the outer edge at 150")
    T.assertTrue(math.abs(rel(150, 80) - ref) < 0.005, "measured from the Hub size's edge")
    assertEqual(L.IconReach(150, 60), 60, "a manual offset is kept")
    assertEqual(L.Wedge(2, 4, 150).x, L.IconReach(150, 0), "the wedge sits on the automatic reach")
    assertEqual(L.Wedge(2, 4, 150, 0, nil, 0, 80).x, L.IconReach(150, 0, 80), "with the dial's hub")
    assertEqual(L.Wedge(2, 4, 150, 0, nil, 90).x, 90, "a manual offset places the wedge")
end)

test("dial layout: [autofit] automatic icon size scales with the ring and clamps", function()
    local L = DL()
    -- red under: no DL.AutoIconSize
    -- red under: the 32-at-100 default (owner, 2026-10-22: 48 at 120, 0.4 of the radius)
    assertEqual(L.AutoIconSize(L.RADIUS), 48, "the default radius keeps the default size")
    assertEqual(L.AutoIconSize(100), 40)
    assertEqual(L.AutoIconSize(150), 60)
    assertEqual(L.AutoIconSize(180), 72)
    assertEqual(L.AutoIconSize(70), 28)
    assertEqual(L.AutoIconSize(999), 72, "the radius is clamped first")
    -- a fixed count caps it to the slice's arc at the icon reach, less the gap and FIT_MARGIN
    local arc = 2 * math.pi * L.IconReach(100, 0) / 12
    assertEqual(L.AutoIconSize(100, nil, 12, 30), math.floor(arc - 30 - L.FIT_MARGIN + 0.5), "the arc caps it, rounded")
    assertEqual(L.AutoIconSize(70, nil, 12, 40), 16, "never below the row's minimum")
    assertEqual(L.AutoIconSize(100, nil, 0, 30), 40, "Auto slices page instead of shrinking")
    assertEqual(L.ResolveIconSize(0, 150), 60, "0 is automatic")
    assertEqual(L.ResolveIconSize(40, 150), 40, "a manual size is kept")
    assertEqual(L.ResolveIconSize(nil, 150), 60, "unset reads as the default, automatic")
end)

test("dial layout: [autofit] auto cap reads the automatic reach and icon size", function()
    local L = DL()
    assertEqual(L.AutoCap(L.RADIUS, 0, L.AutoIconSize(L.RADIUS), 0), 12, "the default dial: no change")
    assertEqual(L.AutoCap(180, 0, L.AutoIconSize(180), 0), 12, "a bigger wheel's bigger icons still fit twelve")
end)
