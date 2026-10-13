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

-- Arathi Basin as a dial plan hands it over: five nodes, six callouts each, open-into on.
local function ab()
    local children = {}
    for i, node in ipairs({ "Stables", "Lumber Mill", "Blacksmith", "Gold Mine", "Farm" }) do
        local s = {}
        for k, word in ipairs({ "INC 1", "INC 2", "INC 3", "INC many", "Clear", "Help" }) do
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
    assertEqual(L.Wedge(2, 4).lx, 40, "the label sits outward from the wedge")
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

test("dial layout: [exit] Categories in Arathi Basin opens on the node ring; Lumber Mill, then INC 3", function()
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
    assertEqual(titles(mill), "INC 1,INC 2,INC 3,More")
    assertEqual(mill.items[3].slot.line, "/i INC 3 Lumber Mill")
    assertEqual(rings[mill.items[4].target].prev, rings[open].items[2].target, "More's page goes back")
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
    -- red under: title a Flat node callout with slot.name alone (five wedges would read "INC 1")
    assertEqual(rings[1].items[1].title, "INC 1 · Stables", "a node's callout names its node")
    assertEqual(rings[1].items[1].slot.name, "INC 1", "the slot itself is unchanged")
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
    assertEqual(total, 32, "every callout reachable")
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
