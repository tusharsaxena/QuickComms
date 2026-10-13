-- tests/test_builtins.lua — defaults/BuiltIns*.lua (spec §12): integrity and the bake audit.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function bi() local NS = T.newAddon() return NS, NS.BuiltIns end

test("builtins: the expected top-level sets exist in order", function()
    local _, BI = bi()
    assertEqual(BI.order[1], "bi.mplus")
    assertEqual(BI.order[2], "bi.raid")
    assertEqual(BI.order[3], "bi.arena")
    -- A battleground's own set comes before the generic one, so the dial opens into it (D9, phase 4).
    assertEqual(BI.order[4], "bi.bg.ab")
    assertEqual(BI.order[#BI.order], "bi.bg")
    assertTrue(#BI.order >= 18, "generic sets plus one per battleground")
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
    local stables = BI.groups[ab.children[1]]
    assertEqual(#stables.callouts, 6)
    assertEqual(BI.callouts[stables.callouts[3]].text, "INC 3 Stables")
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
            -- red under: drop one node's wind from defaults/BuiltIns_Battlegrounds.lua
            assertTrue(NS.DialLayout.PinNodes(nodes) ~= nil, gid .. " pins every node")
        end
    end
    assertEqual(sets, 5)
    assertEqual(BI.groups["bi.bg.ab.lumbermill"].compass, "SW")
    assertEqual(#BI.groups["bi.bg.dwg"].children, 5)
    assertEqual(BI.callouts["bi.bg.dwg.shrine.inc2"].text, "INC 2 Shrine")
end)
