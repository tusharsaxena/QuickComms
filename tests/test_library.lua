-- tests/test_library.lua — modules/Library.lua (spec §5): the only writer of the registry, and the
-- seeding of the shipped sets (2026-10-18-builtins-as-groups-design.md, goal 1).

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function boot()
    local NS = T.bootAddon()
    local sent = {}
    NS.addon.SendMessage = function(_, name, kind, id) sent[#sent + 1] = { name, kind, id } end
    return NS, NS.Library, NS.db.profile, sent
end

-- A booted profile with its seeded groups and callouts taken away (and so off every surface), for a
-- case about the player's own members alone. seededSets stays, so Prepare seeds nothing back.
local function bare()
    local NS, Lib, p, sent = boot()
    for id in pairs(p.groups) do p.groups[id] = nil end
    for id in pairs(p.callouts) do p.callouts[id] = nil end
    for _, s in pairs(p.pads) do s.groups = {} end
    for _, s in pairs(p.dials) do s.groups = {} end
    return NS, Lib, p, sent
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

test("library: Prepare seeds every shipped set as a group, on one pad and one dial, once", function()
    local NS, Lib, p = boot()
    assertTrue(p.seeded)
    assertEqual(#p.padOrder, 1)
    assertEqual(#p.dialOrder, 1)
    assertEqual(p.padOrder[1] .. p.dialOrder[1], "p1d2", "made before the sets: the first ids")
    local pad = p.pads[p.padOrder[1]]
    assertEqual(#pad.groups, #NS.BuiltIns.order)
    for i, gid in ipairs(pad.groups) do
        -- red under: seed the pad with NS.BuiltIns.order (the shipped ids) as before
        assertTrue(gid:match("^g%d+$") ~= nil, "a user group: " .. gid)
        assertEqual(p.groups[gid].origin, NS.BuiltIns.order[i], "in shipped order")
    end
    assertEqual(table.concat(p.dials.d2.groups, ","), table.concat(pad.groups, ","))
    assertEqual(count(p.groups), count(NS.BuiltIns.groups), "a group per set and per node")
    assertEqual(count(p.callouts), count(NS.BuiltIns.callouts))
    local groups = count(p.groups)
    local again = Lib.Prepare()
    assertFalse(again.seeded)
    assertEqual(again.appended, 0)
    assertEqual(#p.padOrder, 1)
    assertEqual(count(p.groups), groups, "seeded once")
end)

test("library: a seeded group is an ordinary group: its fields, When, callouts and origin", function()
    local NS, Lib, p = boot()
    local gid = T.seeded(NS, "bi.mplus")
    local g, def = p.groups[gid], NS.BuiltIns.groups["bi.mplus"]
    assertEqual(g.name, def.name)
    assertEqual(g.icon, def.icon)
    -- red under: seedGroup drops iconColor (polish)
    assertTrue(def.iconColor ~= nil, "the shipped set is tinted")
    assertEqual(g.iconColor, def.iconColor)
    assertTrue(g.when.content.mythicPlus)
    assertTrue(g.when ~= def.when, "a copy of the shipped When")
    assertTrue(g.enabled)
    assertEqual(#g.callouts, #def.callouts)
    local lust = T.seeded(NS, "bi.mplus.lust")
    assertEqual(g.callouts[2], lust, "the shipped order")
    assertEqual(p.callouts[lust].text, "Lust on this pack")
    assertEqual(p.callouts[lust].channel, "smartGroup")
    assertEqual(p.callouts[lust].origin, "bi.mplus.lust")
    -- red under: seedCallout drops iconColor (B7)
    local shipped = NS.BuiltIns.callouts["bi.mplus.lust"]
    assertEqual(p.callouts[lust].icon, shipped.icon)
    assertTrue(shipped.iconColor ~= nil, "the shipped lust is tinted")
    assertEqual(p.callouts[lust].iconColor, shipped.iconColor)
    assertTrue(p.callouts[lust].glyph == nil, "the catalog name is seed data only")
    -- every write a user group takes, through the seam
    assertTrue((NS.SchemaRuntime.Set("group.name", "Keys", gid)))
    assertTrue((NS.SchemaRuntime.Set("group.when", { content = { raid = true } }, gid)))
    assertTrue(Lib.CreateCalloutIn(gid, { name = "Mine", text = "x", channel = "party" }) ~= nil)
    assertTrue(Lib.RemoveFromGroup(gid, 1))
    assertEqual(g.name, "Keys")
    assertTrue(Lib.DeleteGroup(gid))
    assertNil(p.groups[gid])
end)

test("library: a seeded battleground set holds its nodes as groups inside it, A-Z by name", function()
    local NS, Lib, p = boot()
    local ab = T.seeded(NS, "bi.bg.ab")
    assertEqual(#p.groups[ab].callouts, #NS.BuiltIns.groups["bi.bg.ab"].callouts, "its map-wide callouts")
    local kids = Lib.Children(ab)
    local def = NS.BuiltIns.groups["bi.bg.ab"]
    assertEqual(#kids, #def.children)
    local names = {}
    for i, kid in ipairs(kids) do
        names[i] = p.groups[kid].name
        assertEqual(p.groups[kid].parent, ab)
        assertTrue(Lib.IsChild(kid))
    end
    -- red under: Children in made order (the shipped Stables, Lumber Mill, Blacksmith, ...)
    assertEqual(table.concat(names, ","), "Blacksmith,Farm,Gold Mine,Lumber Mill,Stables")
    local stables = T.seeded(NS, "bi.bg.ab.stables")
    assertEqual(p.callouts[p.groups[stables].callouts[3]].text, "INC Stables")
    assertFalse(Lib.AddGroupToSurface("pad", "p1", kids[1]), "a node shows with its set, never by itself")
end)

test("library: callouts validate on create", function()
    local _, Lib = boot()
    assertNil((Lib.CreateCallout({ name = "", text = "x", channel = "party" })))
    assertNil((Lib.CreateCallout({ name = "A", text = "x", channel = "guild" })))
    assertNil((Lib.CreateCallout({ name = "A", text = 5, channel = "party" })))
    local id = Lib.CreateCallout({ name = "Lust", text = "Lust {rt8}", channel = "smartGroup" })
    assertTrue(id:match("^c%d+$") ~= nil)
end)

test("library: whisper channels are refused (owner, issue #7)", function()
    local _, Lib = boot()
    local id, err = Lib.CreateCallout({ name = "W", text = "x", channel = "whisperTarget" })
    assertNil(id) assertEqual(err, "badChannel")
end)

test("library: [review 4] deleting a callout clears its group", function()
    local _, Lib, p = boot()
    local g1 = Lib.CreateGroup({ name = "One" })
    local g2 = Lib.CreateGroup({ name = "Two" })
    local c = Lib.CreateCalloutIn(g1, { name = "Lust", text = "Lust", channel = "party" })
    local other = Lib.CreateCalloutIn(g2, { name = "Kick", text = "Kick", channel = "party" })
    assertTrue(Lib.DeleteCallout(c))
    assertEqual(#p.groups[g1].callouts, 0)
    assertEqual(table.concat(p.groups[g2].callouts, ","), other)
    assertNil(p.callouts[c])
end)

test("library: [review 4] deleting a group clears every surface", function()
    local _, Lib, p = boot()
    local g = Lib.CreateGroup({ name = "Mine" })
    local pad = p.padOrder[1]
    assertTrue(Lib.AddGroupToSurface("pad", pad, g, 1))
    assertTrue(Lib.DeleteGroup(g))
    for _, gid in ipairs(p.pads[pad].groups) do assertTrue(gid ~= g) end
end)

test("library: adding a seeded callout copies it (P2); the copy keeps no origin", function()
    local NS, Lib, p = boot()
    local g = Lib.CreateGroup({ name = "Mine" })
    local lust = T.seeded(NS, "bi.mplus.lust")
    local added = Lib.AddToGroup(g, lust)
    assertTrue(added:match("^c%d+$") ~= nil and added ~= lust)
    assertEqual(p.callouts[added].text, "Lust on this pack")
    assertNil(p.callouts[added].origin, "a copy is the player's, not a seeded callout")
    assertEqual(p.groups[g].callouts[1], added)
    assertEqual(T.seeded(NS, "bi.mplus.lust"), lust)
end)

test("library: [review 5] a newly shipped set is seeded once, at the end of every surface; a deleted one stays deleted", function()
    local NS, Lib, p = boot()
    local pad = p.pads[p.padOrder[1]]
    NS.BuiltIns.Group("bi.test", { name = "New set", when = {} })
    local r = Lib.Prepare()
    assertEqual(r.appended, 2)                        -- the pad and the dial
    local new = T.seeded(NS, "bi.test")
    assertEqual(pad.groups[#pad.groups], new)
    assertEqual(p.groups[new].name, "New set")
    Lib.Prepare()
    local n = 0
    for _, g in pairs(p.groups) do if g.origin == "bi.test" then n = n + 1 end end
    assertEqual(n, 1)
    local arena = T.seeded(NS, "bi.arena")
    Lib.RemoveGroupFromSurface("pad", p.padOrder[1], arena)
    Lib.Prepare()
    for _, gid in ipairs(pad.groups) do assertTrue(gid ~= arena, "a set taken off a pad stays off") end
    Lib.DeleteGroup(arena)
    Lib.Prepare()
    -- red under: seedNew judging by origin (Restore's test) instead of seededSets
    assertNil(T.seeded(NS, "bi.arena"), "a deleted set is not seeded again")
end)

test("library: a node shipped after its set was seeded goes inside the set's group", function()
    local NS, Lib, p = boot()
    local ab = T.seeded(NS, "bi.bg.ab")
    NS.BuiltIns.Group("bi.bg.ab.new", { name = "New node", parent = "bi.bg.ab", compass = "N",
        callouts = NS.BuiltIns.Callouts("bi.bg.ab.new", "smartGroup", { { "inc1", "INC 1", "INC 1 New" } }) })
    table.insert(NS.BuiltIns.groups["bi.bg.ab"].children, "bi.bg.ab.new")
    Lib.Prepare()
    local node = T.seeded(NS, "bi.bg.ab.new")
    assertEqual(p.groups[node].parent, ab)
    local kids = Lib.Children(ab)
    assertEqual(kids[5], node, "in its place by name, among the nodes already there")
    Lib.Prepare()
    assertEqual(#Lib.Children(ab), #kids, "once")
end)

test("library: [review] a set whose stored parent dangles still takes a node shipped after it", function()
    local NS, Lib, p = boot()
    local ab = T.seeded(NS, "bi.bg.ab")
    p.groups[ab].parent = "g999"
    NS.BuiltIns.Group("bi.bg.ab.new", { name = "New node", parent = "bi.bg.ab", compass = "N",
        callouts = NS.BuiltIns.Callouts("bi.bg.ab.new", "smartGroup", { { "inc1", "INC 1", "INC 1 New" } }) })
    table.insert(NS.BuiltIns.groups["bi.bg.ab"].children, "bi.bg.ab.new")
    Lib.Prepare()
    -- red under: seedNew judging the set by its truthy stored parent, with repairParents after it
    local node = T.seeded(NS, "bi.bg.ab.new")
    assertTrue(node ~= nil, "the node is seeded, not only marked given")
    assertEqual(p.groups[node].parent, ab)
    assertFalse(Lib.IsChild(ab), "the dangling parent is dropped")
end)

test("library: [review] ValidParent takes a parent whose own stored parent dangles", function()
    local _, Lib, p = boot()
    local a = Lib.CreateGroup({ name = "Top" })
    local b = Lib.CreateGroup({ name = "Inside" })
    p.groups[a].parent = "g999"
    -- red under: ValidParent testing groups[parent].parent instead of IsChild(parent)
    assertTrue((Lib.ValidParent(a, b)), "a parent that is no child is top-level")
end)

test("library: Prepare repairs dangling ids", function()
    local _, Lib, p = boot()
    local g = Lib.CreateGroup({ name = "Mine" })
    p.groups[g].callouts = { "c999" }
    p.pads[p.padOrder[1]].groups[#p.pads[p.padOrder[1]].groups + 1] = "g999"
    local r = Lib.Prepare()
    assertEqual(r.repaired, 2)
    assertEqual(#p.groups[g].callouts, 0)
end)

test("library: AllGroups is every user group, a seeded node among them", function()
    local NS, Lib, p = boot()
    local all = Lib.AllGroups()
    assertEqual(count(all), count(p.groups))
    assertTrue(all[T.seeded(NS, "bi.bg.ab.stables")] ~= nil)
    assertNil(all["bi.bg.ab"], "no shipped id")
end)

test("library: every mutation announces LIBRARY_CHANGED", function()
    local NS, Lib, _, sent = boot()
    Lib.CreateCallout({ name = "A", text = "a", channel = "party" })
    assertEqual(sent[#sent][1], NS.MSG.LIBRARY_CHANGED)
    assertEqual(sent[#sent][2], "callout")
end)

test("library: no shipped id is a member any more", function()
    local _, Lib, p = boot()
    assertNil(Lib.Group("bi.mplus"))
    assertNil(Lib.Callout("bi.mplus.lust"))
    assertNil(Lib.Member("group", "bi.mplus"))
    assertFalse(Lib.AddGroupToSurface("pad", p.padOrder[1], "bi.mplus"))
    assertNil((Lib.AddToGroup(Lib.CreateGroup({ name = "G" }), "bi.mplus.lust")))
end)

test("library: Prepare survives malformed groups and surfaces", function()
    local _, Lib, p = boot()
    local g = Lib.CreateGroup({ name = "Mine" })
    p.groups[g].callouts = nil
    p.pads[p.padOrder[1]].groups = nil
    p.groups.gbad = "junk"
    local r = Lib.Prepare()
    assertEqual(#p.groups[g].callouts, 0)
    assertEqual(type(p.pads[p.padOrder[1]].groups), "table")
    assertNil(p.groups.gbad)
    assertTrue(r.repaired >= 1)
end)

test("library: Prepare repairs the order lists", function()
    local _, Lib, p = boot()
    p.padOrder[#p.padOrder + 1] = "p999"
    local id = p.padOrder[1]
    p.padOrder = { "p999" }
    local r = Lib.Prepare()
    assertEqual(r.repaired, 2)
    assertEqual(#p.padOrder, 1)
    assertEqual(p.padOrder[1], id)
end)

test("library: MoveInGroup with a nil target returns false", function()
    local _, Lib = boot()
    local c = Lib.CreateCallout({ name = "A", text = "a", channel = "party" })
    local g = Lib.CreateGroup({ name = "G" })
    Lib.AddToGroup(g, c)
    assertFalse(Lib.MoveInGroup(g, 1, nil))
end)

test("library: [final 2] a callout whose copy fails validation is refused cleanly, with no hole", function()
    local _, Lib, p = boot()
    p.callouts.c9001 = { name = string.rep("a", 40), text = "x", channel = "party" }
    local g = Lib.CreateGroup({ name = "G" })
    local ok = Lib.AddToGroup(g, Lib.CreateCallout({ name = "A", text = "x", channel = "party" }))
    local id, why = Lib.AddToGroup(g, "c9001", 1)
    -- red under: `id = Lib.CreateCallout(...)` unchecked in AddToGroup
    assertNil(id)
    assertEqual(why, "badName")
    assertEqual(#p.groups[g].callouts, 1, "nothing inserted")
    assertEqual(p.groups[g].callouts[1], ok)
end)

test("library: [final 2] the name cap counts characters, not bytes", function()
    local _, Lib = boot()
    local cyrillic = string.rep("\208\150", 20)   -- 20 characters, 40 bytes
    assertTrue(Lib.CreateCallout({ name = cyrillic, text = "x", channel = "party" }) ~= nil, "20 characters fit")
    assertTrue(Lib.CreateCallout({ name = string.rep("\208\150", 32), text = "x", channel = "party" }) ~= nil, "32 fit")
    assertNil((Lib.CreateCallout({ name = string.rep("\208\150", 33), text = "x", channel = "party" })), "33 do not")
end)

test("library: [final minor 2] Prepare lifts a stale nextId above every existing id", function()
    local _, Lib, p = boot()
    p.callouts.c4100 = { name = "A", text = "x", channel = "party" }
    p.groups.g700 = { name = "G", callouts = { "c4100" }, when = {} }
    p.nextId = 3
    Lib.Prepare()
    -- red under: a Prepare that leaves nextId alone
    assertTrue(p.nextId >= 4101, tostring(p.nextId))
    assertTrue(Lib.CreateCallout({ name = "B", text = "y", channel = "party" }) ~= "c4100")
    assertEqual(p.callouts.c4100.name, "A", "the old callout survived")
end)

test("library: [final minor 3] Prepare repairs corrupt top-level registry keys", function()
    local NS, Lib, p = boot()
    p.groups, p.callouts, p.pads, p.padOrder, p.seededSets = 5, "x", true, 7, "junk"
    local ok, result = pcall(Lib.Prepare)
    assertTrue(ok, tostring(result))
    for _, key in ipairs({ "callouts", "groups", "seededSets", "pads", "dials", "padOrder", "dialOrder" }) do
        assertEqual(type(p[key]), "table", key)
    end
    assertEqual(result.repaired, 5 + #NS.BuiltIns.order, "five top-level keys, and the dial's references to the lost groups")
    assertTrue(T.seeded(NS, "bi.mplus") ~= nil, "with seededSets lost, the sets are seeded again")
end)

test("library: SetSurfacePoint stores a copy of a plain anchor, announces it, and nil clears it", function()
    local NS = T.bootAddon()
    local heard = {}
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.LIBRARY_CHANGED, function(_, kind, id) heard[#heard + 1] = kind .. ":" .. id end)
    local pt = { "TOPLEFT", "TOPLEFT", 40, -60 }
    T.assertTrue(NS.Library.SetSurfacePoint("pad", "p1", pt))
    pt[3] = 999
    T.assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "TOPLEFT,TOPLEFT,40,-60", "a copy")
    T.assertTrue(NS.Library.SetSurfacePoint("pad", "p1", nil))
    T.assertNil(NS.db.profile.pads.p1.point)
    T.assertEqual(table.concat(heard, ","), "pad:p1,pad:p1")
end)

test("library: SetSurfacePoint refuses an unknown surface or a malformed anchor, and stores nothing", function()
    local NS = T.bootAddon()
    local pt = { "CENTER", "CENTER", 0, 0 }
    T.assertFalse(NS.Library.SetSurfacePoint("pad", "p99", pt))
    T.assertFalse(NS.Library.SetSurfacePoint("nope", "p1", pt))
    T.assertFalse(NS.Library.SetSurfacePoint("pad", "d2", pt), "d2 is a dial, not a pad")
    T.assertFalse(NS.Library.SetSurfacePoint("pad", "p1", { "CENTER" }))
    T.assertFalse(NS.Library.SetSurfacePoint("pad", "p1", { "CENTER", "CENTER", "0", 0 }))
    T.assertFalse(NS.Library.SetSurfacePoint("pad", "p1", "CENTER"))
    T.assertNil(NS.db.profile.pads.p1.point)
    T.assertTrue(NS.Library.SetSurfacePoint("dial", "d2", pt), "the dial's anchor has the same writer")
end)

test("library: [phase 3] a copy's name stays within the 32-character cap, counted in characters", function()
    local _, Lib = boot()
    local long = string.rep("\195\169", 30)          -- thirty two-byte characters
    local name = Lib.CopyName(long)
    assertEqual(select(2, name:gsub("[^\128-\191]", "")), Lib.NAME_MAX)
    assertTrue(name:sub(-7) == " (copy)")
    assertTrue(Lib.ValidName(name))
end)

test("library: duplicating a group copies its callouts", function()
    local _, Lib, p = boot()
    local gid = Lib.CreateGroup({ name = "Mine", when = { content = { raid = true } } })
    Lib.CreateCalloutIn(gid, { name = "A", text = "a", channel = "party" })
    Lib.CreateCalloutIn(gid, { name = "B", text = "b", channel = "say", icon = 136012 })
    local copy = Lib.DuplicateGroup(gid)
    assertEqual(p.groups[copy].name, "Mine (copy)")
    local ids, srcs = p.groups[copy].callouts, p.groups[gid].callouts
    assertEqual(#ids, 2)
    for i, cid in ipairs(ids) do
        -- red under: DuplicateGroup passing the callouts by reference (the old D8)
        assertTrue(cid ~= srcs[i], "no id is shared between the two groups")
        local c, src = p.callouts[cid], p.callouts[srcs[i]]
        assertEqual(c.name .. "|" .. c.text .. "|" .. c.channel, src.name .. "|" .. src.text .. "|" .. src.channel,
            "equal fields, the name kept")
    end
    assertEqual(p.callouts[ids[2]].icon, 136012)
    assertTrue(p.groups[copy].when.content.raid)
    p.groups[copy].when.content.raid = nil
    assertTrue(p.groups[gid].when.content.raid, "a copy, not an alias")
    for _, pad in pairs(p.pads) do
        for _, g in ipairs(pad.groups) do assertTrue(g ~= copy, "not offered to a surface") end
    end
    assertNil((Lib.DuplicateGroup("bi.mplus")), "a shipped id is no group")
end)

test("library: [phase 3] CreateGroup keeps only existing user callouts, and validates the When", function()
    local _, Lib, p = boot()
    local cid = Lib.CreateCallout({ name = "A", text = "a", channel = "party" })
    local gid = Lib.CreateGroup({ name = "G", callouts = { cid, "c9999", "bi.mplus.lust" } })
    assertEqual(#p.groups[gid].callouts, 1)
    assertEqual(p.groups[gid].callouts[1], cid)
    local bad, why = Lib.CreateGroup({ name = "G", when = { nope = { x = true } } })
    assertNil(bad)
    assertEqual(why, "badWhen")
    assertNil((Lib.CreateGroup({ name = "   " })), "a blank name is no name")
end)

test("library: CreateGroup takes a callout no group holds, and copies one a group holds", function()
    local _, Lib, p = boot()
    local loose = Lib.CreateCallout({ name = "A", text = "a", channel = "party" })
    local g1 = Lib.CreateGroup({ name = "One", callouts = { loose, loose } })
    local held = p.groups[g1].callouts
    assertEqual(held[1], loose, "a callout in no group is taken as it is")
    -- red under: CreateGroup copying a list by reference (one callout in two places)
    assertTrue(held[2] ~= loose and p.callouts[held[2]].name == "A", "a repeat is a copy")
    local g2 = Lib.CreateGroup({ name = "Two", callouts = { loose } })
    assertTrue(p.groups[g2].callouts[1] ~= loose, "a callout another group holds is copied")
    assertEqual(p.groups[g1].callouts[1], loose, "the first group still holds the original")
end)

test("library: [phase 3] OfferGroup puts a user group first on every pad and dial, once", function()
    local _, Lib, p = boot()
    local gid = Lib.CreateGroup({ name = "Mine" })
    assertEqual(Lib.OfferGroup(gid), 2, "the default pad and the default dial")
    assertEqual(p.pads.p1.groups[1], gid)
    assertEqual(p.dials.d2.groups[1], gid)
    assertEqual(Lib.OfferGroup(gid), 0, "already on both")
    assertEqual(Lib.OfferGroup("bi.mplus"), 0, "a shipped id is no group")
    assertEqual(Lib.OfferGroup("g999"), 0)
end)

test("library: [phase 3] MoveGroupOnSurface reorders a surface's groups and announces it", function()
    local NS, Lib, p, sent = boot()
    local first, second = p.pads.p1.groups[1], p.pads.p1.groups[2]
    assertTrue(Lib.MoveGroupOnSurface("pad", "p1", 1, 2))
    assertEqual(p.pads.p1.groups[1], second)
    assertEqual(p.pads.p1.groups[2], first)
    assertEqual(sent[#sent][1], NS.MSG.LIBRARY_CHANGED)
    assertEqual(sent[#sent][2], "pad")
    assertFalse(Lib.MoveGroupOnSurface("pad", "p1", 99, 1))
    assertFalse(Lib.MoveGroupOnSurface("pad", "p9", 1, 2))
    assertFalse(Lib.MoveGroupOnSurface("pad", "p1", 1, nil))
end)

test("library: [phase 3] Member answers the live member of each kind", function()
    local NS, Lib, p = boot()
    local cid = Lib.CreateCallout({ name = "A", text = "a", channel = "party" })
    assertTrue(Lib.Member("callout", cid) == p.callouts[cid])
    assertTrue(Lib.Member("pad", "p1") == p.pads.p1)
    assertTrue(Lib.Member("dial", "d2") == p.dials.d2)
    local gid = T.seeded(NS, "bi.mplus")
    assertTrue(Lib.Member("group", gid) == p.groups[gid], "a seeded group is the live table")
    assertNil(Lib.Member("builtin", "bi.mplus"), "no overlay kind")
    assertNil(Lib.Member("callout", nil))
    assertNil(Lib.Member("pad", "d2"))
    assertNil(Lib.Member("nope", "p1"))
end)

test("library: [phase 3] Touch announces the member it is handed, and the field", function()
    local NS, Lib = boot()
    local sent = {}   -- boot's recorder keeps three arguments; this one keeps the field too
    NS.addon.SendMessage = function(_, name, kind, id, field) sent[#sent + 1] = { name, kind, id, field } end
    Lib.Touch("callout", "c7", "callout.text")
    assertEqual(sent[#sent][1], NS.MSG.LIBRARY_CHANGED)
    assertEqual(sent[#sent][2], "callout")
    assertEqual(sent[#sent][3], "c7")
    -- red under: drop the `field` argument from Lib.Touch's announce
    assertEqual(sent[#sent][4], "callout.text")
    Lib.CreateCallout({ name = "A", text = "a", channel = "party" })
    assertNil(sent[#sent][4], "a membership change names no field")
end)

test("library: [phase 3] MemberIds lists each kind in its picker's order", function()
    local _, Lib, p = bare()
    assertEqual(#Lib.MemberIds("callout"), 0)
    local b = Lib.CreateCallout({ name = "beta", text = "b", channel = "party" })
    local a = Lib.CreateCallout({ name = "Alpha", text = "a", channel = "party" })
    assertEqual(table.concat(Lib.MemberIds("callout"), ","), a .. "," .. b, "by name, case-insensitive")
    local m = Lib.CreateGroup({ name = "Mine" })
    local k = Lib.CreateGroup({ name = "keys" })
    -- red under: MemberIds appending the shipped ids after the user groups
    assertEqual(table.concat(Lib.MemberIds("group"), ","), k .. "," .. m, "by name, and nothing else")
    assertEqual(table.concat(Lib.MemberIds("pad"), ","), table.concat(p.padOrder, ","))
    assertEqual(#Lib.MemberIds("nope"), 0)
end)

test("library: [phase 3] ValidWhen accepts every shipped When and refuses bad shapes", function()
    local NS, Lib = boot()
    for id, def in pairs(NS.BuiltIns.groups) do
        if def.when then assertTrue(Lib.ValidWhen(def.when), id) end
    end
    assertTrue(Lib.ValidWhen({}))
    assertTrue(Lib.ValidWhen({ instances = { [2526] = true }, keyLevel = { min = 10 } }))
    assertFalse(Lib.ValidWhen({ combat = { yes = true } }), "not a v0.1.0 condition (spec P1)")
    assertFalse(Lib.ValidWhen({ content = { raid = 1 } }))
    assertFalse(Lib.ValidWhen({ content = "raid" }))
    local ok, why = Lib.ValidWhen({ keyLevel = { min = 12, max = 10 } })
    assertFalse(ok)
    assertEqual(why, "badRange")
    assertFalse(Lib.ValidWhen("x"))
end)

test("library: [final] a surface's offsets are bounded at its smallest scale, not at 1", function()
    local NS, Lib = boot()
    local real = NS.Compat.ScreenSize
    NS.Compat.ScreenSize = function() return 1920, 1080 end
    -- red under: the bound is the bare screen size, so a pad drawn at 0.3 and dragged to the far
    -- right (its own units: about 1.2x the width) is refused and snaps back
    local ok = Lib.ValidPoint({ "CENTER", "CENTER", 2304, -1296 })
    local far, why = Lib.ValidPoint({ "CENTER", "CENTER", 7000, 0 })
    NS.Compat.ScreenSize = real
    assertTrue(ok, "an on-screen drag of a scaled-down pad")
    assertFalse(far, "past the screen at the smallest scale")
    assertEqual(why, "offScreen")
end)

test("library: [phase 3] the point and icon validators", function()
    local _, Lib = boot()
    assertTrue(Lib.ValidPoint(nil), "nil is the default place")
    assertTrue(Lib.ValidPoint({ "TOPLEFT", "TOPLEFT", 1, -2 }))
    assertFalse(Lib.ValidPoint({ "TOPLEFT", "TOPLEFT", "1", -2 }))
    assertFalse(Lib.ValidPoint("CENTER"))
    assertFalse(Lib.ValidPoint({ "FOO", "BAR", 1, 2 }), "an unknown anchor name")
    assertFalse(Lib.ValidPoint({ "CENTER", "CENTER", 0/0, 0 }), "a NaN offset")
    assertFalse(Lib.ValidPoint({ "CENTER", "CENTER", 0, math.huge }), "an infinite offset")
    assertTrue(Lib.ValidIcon(nil))
    assertTrue(Lib.ValidIcon(false))
    assertTrue(Lib.ValidIcon(136012))
    assertTrue(Lib.ValidIcon("Interface\\Icons\\Spell_Nature_Bloodlust"))
    assertFalse(Lib.ValidIcon(""))
    assertFalse(Lib.ValidIcon({}))
end)

test("library: [phase 3] every member template holds a value at every field", function()
    local _, Lib = boot()
    assertEqual(Lib.TEMPLATES.callout.channel, "smartGroup")
    assertEqual(Lib.TEMPLATES.pad.layout.style, "iconLabel")
    assertEqual(Lib.TEMPLATES.pad.look.visibility, "always")
    assertTrue(Lib.TEMPLATES.pad.point == false, "false: the default place, and a value the boot check can see")
    assertNil(Lib.TEMPLATES.builtin, "no overlay kind")
end)

test("library: [phase 3] Batch holds the announces and sends one per kind it touched", function()
    local NS, Lib, _, sent = boot()
    local before = #sent
    local S = NS.SchemaRuntime
    Lib.Batch(function()
        S.Set("group.enabled", false, T.seeded(NS, "bi.raid"))
        S.Set("group.enabled", false, T.seeded(NS, "bi.arena"))
        Lib.Batch(function() S.Set("group.enabled", false, T.seeded(NS, "bi.mplus")) end)
    end)
    -- red under: announce inside Lib.Batch as usual (three messages)
    assertEqual(#sent - before, 1)
    assertEqual(sent[#sent][1], NS.MSG.LIBRARY_CHANGED)
    assertEqual(sent[#sent][2], "group")
    assertNil(sent[#sent][3], "no id: several members changed")
    assertFalse(NS.db.profile.groups[T.seeded(NS, "bi.mplus")].enabled)
    S.Set("group.enabled", true, T.seeded(NS, "bi.raid"))
    assertEqual(#sent - before, 2, "announces flow again after the batch")
end)

test("library: [final 1] Restore, AddToGroup and OfferGroup each send one LIBRARY_CHANGED", function()
    local NS, Lib, p, sent = boot()
    Lib.DeleteGroup(T.seeded(NS, "bi.mplus"))
    Lib.DeleteGroup(T.seeded(NS, "bi.bg.ab"))
    local before = #sent
    -- red under: drop Lib.Batch from Lib.RestoreBuiltins (one message per group, callout and surface)
    Lib.RestoreBuiltins()
    assertEqual(#sent - before, 1)
    assertEqual(sent[#sent][1], NS.MSG.LIBRARY_CHANGED)
    assertEqual(sent[#sent][2], "callout,dial,group,pad", "the kinds it touched")
    local g = Lib.CreateGroup({ name = "Mine" })
    before = #sent
    -- red under: drop Lib.Batch from Lib.AddToGroup (the copy and the insert announce apart)
    Lib.AddToGroup(g, T.seeded(NS, "bi.mplus.lust"))
    assertEqual(#sent - before, 1)
    Lib.CreateSurface("pad", "Two")
    before = #sent
    -- red under: drop Lib.Batch from Lib.OfferGroup (one per surface)
    assertEqual(Lib.OfferGroup(g), #p.padOrder + #p.dialOrder)
    assertEqual(#sent - before, 1)
end)

test("library: [final 1] one Restore click rebuilds the pads once", function()
    local NS = T.enableAddon()
    NS.Situation.ReadInputs = function() return { inInstance = true, instanceType = "party", difficultyID = 8,
        keystoneActive = true, keyLevel = 12, inGroup = true } end
    NS.Situation.RefreshNow("test")
    NS.Library.DeleteGroup(T.seeded(NS, "bi.bg.ab"))
    NS.Library.DeleteGroup(T.seeded(NS, "bi.mplus"))
    local applied = 0
    local apply = NS.Surfaces.ApplyAll
    NS.Surfaces.ApplyAll = function(...) applied = applied + 1 return apply(...) end
    NS.Library.RestoreBuiltins()
    NS.Surfaces.ApplyAll = apply
    assertEqual(applied, 1, "one rebuild for the whole restore")
end)

test("library: [final 2] ValidWhen refuses a value its row can never match, and names the row and value", function()
    local _, Lib = boot()
    -- red under: Lib.ValidWhen checks only that each key is a string or a number
    local ok, why, row, value = Lib.ValidWhen({ role = { tank = true } })
    assertFalse(ok)
    assertEqual(why, "badValue")
    assertEqual(row, "role")
    assertEqual(value, "tank")
    assertFalse(Lib.ValidWhen({ instances = { ["Ara-Kara"] = true } }), "a name, not an instanceID")
    assertFalse(Lib.ValidWhen({ instances = { [1.5] = true } }), "a fraction")
    assertFalse(Lib.ValidWhen({ battleground = { [-3] = true } }), "a negative id")
    assertFalse(Lib.ValidWhen({ class = { warrior = true } }), "a classFile is upper case")
    assertFalse(Lib.ValidWhen({ difficulty = { [16] = true } }), "a difficulty is a token")
    assertFalse(Lib.ValidWhen({ content = { mplus = true } }))
    assertFalse(Lib.ValidWhen({ spec = { abc = true } }))
    assertFalse(Lib.ValidWhen({ characters = { bob = true } }), "a character is Name-Realm")
    -- [review] red under: ValidWhenValue's old characters pattern (any byte but a space or a minus)
    assertFalse(Lib.ValidWhen({ characters = { ["Bob|T1:99|t-Area52"] = true } }), "no escape character")
    assertFalse(Lib.ValidWhen({ characters = { ["Bo\1b-Area52"] = true } }), "no control character")
    assertFalse(Lib.ValidWhen({ characters = { [string.rep("a", 60) .. "-" .. string.rep("b", 60)] = true } }), "at most 96 bytes")
    assertTrue(Lib.ValidWhen({ characters = { ["\208\154\208\176\208\190\209\129-\208\147\208\190\209\128\208\180\209\131\208\189\208\189"] = true } }), "a Cyrillic Name-Realm")
    assertTrue(Lib.ValidWhen({ role = { TANK = true }, class = { WARRIOR = true }, spec = { [71] = true },
        difficulty = { mythic = true }, group = { instance = true }, leadership = { assist = true },
        instances = { [2526] = true }, battleground = { [2107] = true }, characters = { ["Bob-Area52"] = true },
        content = { housing = true } }))
end)

test("library: [phase 4] the generic battleground set moves below the per-battleground sets, once", function()
    local _, Lib = boot()
    local profile = { pads = { p1 = { groups = { "g1", "bi.bg", "bi.bg.ab", "bi.mplus", "bi.bg.wsg" } } },
        dials = { d2 = { groups = { "bi.bg.ab", "bi.bg" } } } }
    assertEqual(Lib.MoveGenericBattlegroundLast(profile), 1)
    assertEqual(table.concat(profile.pads.p1.groups, ","), "g1,bi.bg.ab,bi.mplus,bi.bg.wsg,bi.bg")
    assertEqual(table.concat(profile.dials.d2.groups, ","), "bi.bg.ab,bi.bg", "already below: untouched")
    assertEqual(Lib.MoveGenericBattlegroundLast(profile), 0, "idempotent")
    assertEqual(Lib.MoveGenericBattlegroundLast({ pads = "junk" }), 0)
end)

test("library: [phase 5] Prepare gives a pad saved before the Look groups every field it lacks", function()
    local NS, Lib, p = boot()
    local pad = p.pads[p.padOrder[1]]
    pad.look = { visibility = "never" }
    pad.button, pad.section, pad.header = nil, nil, { height = 30 }
    Lib.Prepare()
    assertEqual(pad.look.visibility, "never", "a stored value is kept")
    assertNil(pad.look.font, "the section titles' font left the Main window (2026-10-20)")
    assertEqual(pad.section.font, "Friz Quadrata TT", "the Section header tab, filled whole")
    assertEqual(pad.section.height, 0, "automatic")
    assertEqual(pad.look.background.a, 0.92)
    assertEqual(pad.button.width, 100, "the Buttons tab, filled whole")
    assertEqual(pad.header.height, 30, "a stored header height is kept")
    assertEqual(pad.header.fontSize, 16, "and the header's other fields filled with the owner's defaults")
    assertTrue(pad.look.background ~= NS.Library.TEMPLATES.pad.look.background, "a copy, never the template")
end)

-- ── one owner per callout (2026-10-17-callouts-owned-by-groups-design.md) ──────────────────

test("library: adding a user callout to a group adds a copy", function()
    local NS, Lib, p, sent = boot()
    local g1 = Lib.CreateGroup({ name = "One" })
    local g2 = Lib.CreateGroup({ name = "Two" })
    local src = Lib.CreateCalloutIn(g1, { name = "Kick", text = "Kick {rt8}", channel = "party", icon = 136012 })
    local before = #sent
    local copy = Lib.AddToGroup(g2, src)
    -- red under: addToGroup inserting a user callout by reference
    assertTrue(copy ~= nil and copy ~= src, "a fresh id")
    assertEqual(p.groups[g2].callouts[1], copy)
    local c = p.callouts[copy]
    assertEqual(c.name .. "|" .. c.text .. "|" .. c.channel .. "|" .. c.icon, "Kick|Kick {rt8}|party|136012",
        "equal fields, the name kept with no (copy)")
    c.text = "changed"
    assertEqual(p.callouts[src].text, "Kick {rt8}", "the source is untouched")
    assertEqual(table.concat(p.groups[g1].callouts, ","), src)
    assertEqual(#sent - before, 1, "the copy and the insert are one act")
    assertEqual(sent[#sent][1], NS.MSG.LIBRARY_CHANGED)
    assertNil((Lib.AddToGroup(g2, "c999")))
end)

test("library: removing a callout from its group deletes it", function()
    local _, Lib, p = boot()
    local g = Lib.CreateGroup({ name = "Mine" })
    local a = Lib.CreateCalloutIn(g, { name = "A", text = "a", channel = "party" })
    local b = Lib.CreateCalloutIn(g, { name = "B", text = "b", channel = "party" })
    assertTrue(Lib.RemoveFromGroup(g, 1))
    -- red under: RemoveFromGroup only taking the id out of the list
    assertNil(p.callouts[a])
    assertEqual(table.concat(p.groups[g].callouts, ","), b)
    assertFalse(Lib.RemoveFromGroup(g, 5))
    assertTrue(p.callouts[b] ~= nil)
end)

test("library: deleting a group deletes its callouts", function()
    local _, Lib, p = boot()
    local g = Lib.CreateGroup({ name = "Mine" })
    local keep = Lib.CreateGroup({ name = "Other" })
    local a = Lib.CreateCalloutIn(g, { name = "A", text = "a", channel = "party" })
    local b = Lib.CreateCalloutIn(keep, { name = "B", text = "b", channel = "party" })
    assertTrue(Lib.DeleteGroup(g))
    -- red under: DeleteGroup leaving its callouts in profile.callouts
    assertNil(p.callouts[a])
    assertTrue(p.callouts[b] ~= nil, "another group's callout stays")
end)

test("library: CreateCalloutIn makes and places a callout in one act", function()
    local NS, Lib, p, sent = boot()
    local g = Lib.CreateGroup({ name = "Mine" })
    local first = Lib.CreateCalloutIn(g, { name = "A", text = "a", channel = "party" })
    local before = #sent
    local id = Lib.CreateCalloutIn(g, { name = "B", text = "b", channel = "smartGroup" })
    -- red under: drop Lib.Batch from Lib.CreateCalloutIn (the create and the insert announce apart)
    assertEqual(#sent - before, 1)
    assertEqual(sent[#sent][1], NS.MSG.LIBRARY_CHANGED)
    assertEqual(table.concat(p.groups[g].callouts, ","), first .. "," .. id, "at the end by default")
    local front = Lib.CreateCalloutIn(g, { name = "C", text = "c", channel = "say" }, 1)
    assertEqual(p.groups[g].callouts[1], front)
    local nextId = p.nextId
    local none, why = Lib.CreateCalloutIn(g, { name = "", text = "x", channel = "party" })
    assertNil(none)
    assertEqual(why, "badName")
    none, why = Lib.CreateCalloutIn("g999", { name = "D", text = "d", channel = "party" })
    assertNil(none)
    assertEqual(why, "noGroup")
    assertNil((Lib.CreateCalloutIn("bi.mplus", { name = "D", text = "d", channel = "party" })), "a shipped id is no group")
    assertEqual(p.nextId, nextId, "a refusal consumes no id")
end)


-- ── a glyph's color (icon browser spec, "Data model") ───────────────────────────────────────

test("library: [icons] IsGlyph names a catalog icon by its path; ValidIconColor takes none or rrggbb", function()
    local NS, Lib = boot()
    assertEqual(Lib.IsGlyph(NS.Icon("star")), "star")
    assertNil(Lib.IsGlyph("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"), "a raid marker is no glyph")
    assertNil(Lib.IsGlyph(136012))
    assertNil(Lib.IsGlyph(false))
    -- review focus 4: a path a saved icon carried before the three icon sets
    -- (LibKa0s v1.74.0) still reads as the same glyph, and a prefixed set's mark resolves to its name
    assertEqual(Lib.IsGlyph("Interface\\AddOns\\QuickComms\\libs\\LibKa0s\\media\\icons\\star"), "star")
    assertEqual(Lib.IsGlyph("Interface\\AddOns\\QuickComms\\libs\\LibKa0s\\media\\icons\\phosphor\\arrow-up"),
        "ph:arrow-up")
    assertEqual(Lib.IsGlyph(NS.Icon("gi:sword-wound")), "gi:sword-wound")
    for _, ok in ipairs({ false, "ff8000", "00aa99" }) do assertTrue(Lib.ValidIconColor(ok), tostring(ok)) end
    assertTrue(Lib.ValidIconColor(nil))
    for _, bad in ipairs({ "FF8000", "#ff8000", "ff800", "ff80000", "ff80zz", 16744448, true, {} }) do
        assertFalse(Lib.ValidIconColor(bad), tostring(bad))
    end
    assertEqual(Lib.IconColorValue("  #FF8000 "), "ff8000")
    assertTrue(Lib.IconColorValue("") == false and Lib.IconColorValue(nil) == false)
end)

test("library: [icons] a new member keeps a glyph's color, drops it on any other icon, refuses a bad one", function()
    local NS, Lib, p = boot()
    local star = NS.Icon("star")
    local cid = Lib.CreateCallout({ name = "A", text = "a", channel = "say", icon = star, iconColor = "ff0000" })
    -- red under: CreateCallout storing the four fields only
    assertEqual(p.callouts[cid].iconColor, "ff0000")
    local plain = Lib.CreateCallout({ name = "B", text = "b", channel = "say", icon = 136012, iconColor = "ff0000" })
    assertNil(p.callouts[plain].iconColor, "a game icon takes no color")
    local id, why = Lib.CreateCallout({ name = "C", text = "c", channel = "say", icon = star, iconColor = "red" })
    assertNil(id)
    assertEqual(why, "badIconColor")
    local gid = Lib.CreateGroup({ name = "G", icon = star, iconColor = "00ff00" })
    assertEqual(p.groups[gid].iconColor, "00ff00")
    assertNil(Lib.CreateGroup({ name = "H", icon = star, iconColor = 5 }))
    assertNil(p.groups[Lib.CreateGroup({ name = "I", iconColor = "00ff00" })].iconColor, "no icon, no color")
end)

test("library: [icons] a copy keeps the color: AddToGroup, DuplicateGroup and a held callout's copy", function()
    local NS, Lib, p = boot()
    local star = NS.Icon("star")
    local g1 = Lib.CreateGroup({ name = "One", icon = star, iconColor = "00ff00" })
    local cid = Lib.CreateCalloutIn(g1, { name = "A", text = "a", channel = "say", icon = star, iconColor = "ff0000" })
    local g2 = Lib.CreateGroup({ name = "Two" })
    -- red under: copyCallout without iconColor
    assertEqual(p.callouts[Lib.AddToGroup(g2, cid)].iconColor, "ff0000")
    local dup = Lib.DuplicateGroup(g1)
    assertEqual(p.groups[dup].iconColor, "00ff00")
    assertEqual(p.callouts[p.groups[dup].callouts[1]].iconColor, "ff0000")
end)

test("library: [icons] Prepare drops a malformed stored color and keeps a good one", function()
    local NS, Lib, p = boot()
    local star = NS.Icon("star")
    local gid = Lib.CreateGroup({ name = "G", icon = star, iconColor = "00ff00" })
    local good = Lib.CreateCalloutIn(gid, { name = "A", text = "a", channel = "say", icon = star, iconColor = "ff0000" })
    local bad = Lib.CreateCalloutIn(gid, { name = "B", text = "b", channel = "say", icon = star })
    p.callouts[bad].iconColor = "#ZZZ"
    p.groups[gid].iconColor = { 1, 0, 0 }
    -- red under: drop dropBadColors from Lib.Prepare
    local r = Lib.Prepare()
    assertEqual(r.repaired, 2)
    assertNil(p.callouts[bad].iconColor)
    assertNil(p.groups[gid].iconColor)
    assertEqual(p.callouts[good].iconColor, "ff0000")
    assertEqual(Lib.Prepare().repaired, 0, "idempotent")
end)

test("library: [icons] IconTint draws a glyph's color as r, g, b; no color, a bad one or no glyph is white", function()
    local NS, Lib = boot()
    local star = NS.Icon("star")
    local r, g, b = Lib.IconTint(star, "ff8000")
    -- red under: IconTint answering white for every color
    assertEqual(r .. "," .. g .. "," .. b, "1," .. (128 / 255) .. ",0")
    assertEqual(table.concat({ Lib.IconTint(star, nil) }, ","), "1,1,1", "untinted")
    assertEqual(table.concat({ Lib.IconTint(star, false) }, ","), "1,1,1", "false is none")
    assertEqual(table.concat({ Lib.IconTint(star, "#zz0000") }, ","), "1,1,1", "a malformed color draws white")
    -- red under: tint any icon that carries a color, glyph or not
    assertEqual(table.concat({ Lib.IconTint(136012, "ff0000") }, ","), "1,1,1", "a game icon is never tinted")
    assertEqual(table.concat({ Lib.IconTint("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", "ff0000") }, ","),
        "1,1,1", "nor a raid marker")
end)

-- ── nested groups (2026-10-18-builtins-as-groups-design.md, goal 2) ──────────────────────────

local function setParent(NS, gid, parent)
    return NS.SchemaRuntime.Set("group.parent", parent, gid)
end

test("library: [nesting] a group takes a top-level group as its parent and leaves every surface", function()
    local NS, Lib, p = boot()
    local parent = Lib.CreateGroup({ name = "Raid night" })
    local child = Lib.CreateGroup({ name = "Boss 1" })
    assertTrue(Lib.AddGroupToSurface("pad", p.padOrder[1], child, 1))
    assertTrue(Lib.AddGroupToSurface("dial", p.dialOrder[1], child, 1))
    local ok = setParent(NS, child, parent)
    assertTrue(ok)
    assertEqual(p.groups[child].parent, parent)
    assertEqual(table.concat(Lib.Children(parent), ","), child)
    -- red under: the group.parent row's onChange only announcing (no Lib.SettleParent)
    for _, gid in ipairs(p.pads[p.padOrder[1]].groups) do assertTrue(gid ~= child, "off the pad") end
    for _, gid in ipairs(p.dials[p.dialOrder[1]].groups) do assertTrue(gid ~= child, "off the dial") end
    assertFalse(Lib.AddGroupToSurface("pad", p.padOrder[1], child), "a child is never placed by itself")
    assertTrue(Lib.IsChild(child))
    assertFalse(Lib.IsChild(parent))
end)

test("library: [nesting] one level only: self, a child, a parent with children, a stranger and a shipped id are refused", function()
    local NS, Lib, p = boot()
    local a = Lib.CreateGroup({ name = "A" })
    local b = Lib.CreateGroup({ name = "B" })
    local c = Lib.CreateGroup({ name = "C" })
    assertTrue((setParent(NS, b, a)))
    assertFalse((setParent(NS, a, a)), "not itself")
    assertEqual(select(2, Lib.ValidParent(a, a)), "selfParent")
    -- red under: ValidParent not checking the parent's own parent
    assertFalse((setParent(NS, c, b)), "b is inside a")
    assertEqual(select(2, Lib.ValidParent(b, c)), "parentIsChild")
    assertFalse((setParent(NS, a, c)), "a holds b")
    assertEqual(select(2, Lib.ValidParent(c, a)), "hasChildren")
    assertFalse((setParent(NS, c, "g999")), "no such group")
    assertFalse((setParent(NS, c, "bi.mplus")), "a shipped id is no parent")
    assertEqual(select(2, Lib.ValidParent("bi.mplus", c)), "badParent")
    assertFalse((setParent(NS, "bi.mplus", a)), "a shipped id takes no parent")
    assertNil(p.groups[c].parent)
    assertNil(p.groups[a].parent)
end)

test("library: [nesting] none clears the parent: false, empty text and 'none' all do", function()
    local NS, Lib, p = boot()
    local a = Lib.CreateGroup({ name = "A" })
    local b = Lib.CreateGroup({ name = "B" })
    for _, none in ipairs({ false, "", " none ", "NONE" }) do
        assertTrue((setParent(NS, b, a)))
        assertTrue((setParent(NS, b, none)), tostring(none))
        assertFalse(p.groups[b].parent, tostring(none))
        assertEqual(#Lib.Children(a), 0)
    end
end)

test("library: [nesting] a group's children are A-Z by name; MemberIds lists them under it", function()
    local NS, Lib = bare()
    local z = Lib.CreateGroup({ name = "Zed" })
    local a = Lib.CreateGroup({ name = "Alpha" })
    local y = Lib.CreateGroup({ name = "Yak" })
    local b = Lib.CreateGroup({ name = "Bee" })
    setParent(NS, y, z)
    setParent(NS, b, z)
    -- red under: made order (Yak, then Bee; until 2026-10-25)
    assertEqual(table.concat(Lib.Children(z), ","), b .. "," .. y, "names, not made order")
    local twin = Lib.CreateGroup({ name = "bee" })
    setParent(NS, twin, z)
    assertEqual(table.concat(Lib.Children(z), ","), b .. "," .. twin .. "," .. y, "case-insensitive, then made order")
    local ids = Lib.MemberIds("group")
    -- red under: MemberIds sorting every user group by name, children among them
    assertEqual(table.concat(ids, ","), a .. "," .. z .. "," .. b .. "," .. twin .. "," .. y)
end)

test("library: [nesting] deleting a parent makes its children top-level groups in its place on every surface", function()
    local NS, Lib, p = boot()
    local parent = Lib.CreateGroup({ name = "Raid night" })
    local c1 = Lib.CreateGroup({ name = "Boss 1" })
    local c2 = Lib.CreateGroup({ name = "Boss 2" })
    setParent(NS, c1, parent)
    setParent(NS, c2, parent)
    local pad = p.pads[p.padOrder[1]]
    Lib.AddGroupToSurface("pad", p.padOrder[1], parent, 2)
    local before = pad.groups[1]
    assertTrue(Lib.DeleteGroup(parent))
    -- red under: DeleteGroup leaving the children's parent pointing at the deleted group
    assertFalse(p.groups[c1].parent)
    assertFalse(p.groups[c2].parent)
    assertEqual(pad.groups[1], before)
    assertEqual(pad.groups[2], c1, "in the parent's place")
    assertEqual(pad.groups[3], c2)
    local dial = p.dials[p.dialOrder[1]]
    for _, gid in ipairs(dial.groups) do assertTrue(gid ~= c1, "the parent was on no dial") end
end)

test("library: [nesting] Duplicate keeps a child inside its parent; a parent's copy holds no children", function()
    local NS, Lib, p = boot()
    local parent = Lib.CreateGroup({ name = "Raid night" })
    local child = Lib.CreateGroup({ name = "Boss 1" })
    setParent(NS, child, parent)
    local copy = Lib.DuplicateGroup(child)
    assertEqual(p.groups[copy].parent, parent)
    local pcopy = Lib.DuplicateGroup(parent)
    assertFalse(p.groups[pcopy].parent)
    assertEqual(#Lib.Children(pcopy), 0)
    assertEqual(#Lib.Children(parent), 2)
end)

test("library: [nesting] Prepare drops a bad parent (gone, itself, a chain, a cycle) and takes a child off every surface", function()
    local _, Lib, p = boot()
    local function raw(name, parent) local id = Lib.CreateGroup({ name = name }) p.groups[id].parent = parent return id end
    local top = raw("Top")
    local kid = raw("Kid", top)
    local gone = raw("Gone", "g999")
    local self = raw("Self")
    p.groups[self].parent = self
    local deep = raw("Deep", kid)
    local x = raw("X")
    local y = raw("Y", x)
    p.groups[x].parent = y
    local num = raw("Num", 5)
    local pad = p.pads[p.padOrder[1]]
    table.insert(pad.groups, 1, kid)
    local r = Lib.Prepare()
    assertEqual(p.groups[kid].parent, top, "a good parent stays")
    -- red under: Prepare without the parent repair
    assertNil(p.groups[gone].parent)
    assertNil(p.groups[self].parent)
    assertNil(p.groups[deep].parent, "kid is inside top: no chain")
    assertNil(p.groups[x].parent, "a cycle is no nesting")
    assertNil(p.groups[y].parent)
    assertNil(p.groups[num].parent)
    for _, gid in ipairs(pad.groups) do assertTrue(gid ~= kid, "a child is off the pad") end
    assertTrue(r.repaired >= 7)
    assertEqual(Lib.Prepare().repaired, 0, "idempotent")
end)

-- ── restore built-in groups (2026-10-18-builtins-as-groups-design.md, goal 1) ────────────────

test("library: [restore] a deleted set comes back once, as fresh groups at the end of every surface", function()
    local NS, Lib, p = boot()
    local old = T.seeded(NS, "bi.mplus")
    Lib.DeleteGroup(old)
    local n = Lib.RestoreBuiltins()
    local new = T.seeded(NS, "bi.mplus")
    assertTrue(new ~= nil and new ~= old, "a fresh group")
    assertEqual(n.groups, 1)
    assertEqual(n.callouts, #NS.BuiltIns.groups["bi.mplus"].callouts)
    assertEqual(p.pads.p1.groups[#p.pads.p1.groups], new, "at the end of the pad")
    assertEqual(p.dials.d2.groups[#p.dials.d2.groups], new, "and of the dial")
    local again = Lib.RestoreBuiltins()
    -- red under: RestoreBuiltins re-seeding every set, present or not
    assertEqual(again.groups + again.callouts, 0, "a second run adds nothing")
    assertEqual(#p.pads.p1.groups, #NS.BuiltIns.order)
end)

test("library: [restore] a deleted node comes back inside its set; a deleted callout at the end of its group", function()
    local NS, Lib, p = boot()
    local ab = T.seeded(NS, "bi.bg.ab")
    local mine = T.seeded(NS, "bi.bg.ab.mine")
    Lib.DeleteGroup(mine)
    local mplus = T.seeded(NS, "bi.mplus")
    Lib.RemoveFromGroup(mplus, 2)   -- Lust
    NS.SchemaRuntime.Set("callout.text", "Pulling NOW", T.seeded(NS, "bi.mplus.pull"))
    local n = Lib.RestoreBuiltins()
    assertEqual(n.groups, 1)
    assertEqual(n.callouts, 1 + #NS.BuiltIns.groups["bi.bg.ab.mine"].callouts)
    local node = T.seeded(NS, "bi.bg.ab.mine")
    assertEqual(p.groups[node].parent, ab, "inside its set")
    local list = p.groups[mplus].callouts
    assertEqual(p.callouts[list[#list]].origin, "bi.mplus.lust", "at the end of its group")
    assertEqual(p.callouts[T.seeded(NS, "bi.mplus.pull")].text, "Pulling NOW", "an edited callout is kept as it is")
    for _, gid in ipairs(p.pads.p1.groups) do assertTrue(gid ~= node, "a node is placed on no surface") end
    assertEqual(Lib.RestoreBuiltins().groups, 0)
end)

test("library: [restore] a set deleted with its nodes kept brings back only what is missing", function()
    local NS, Lib, p = boot()
    local ab = T.seeded(NS, "bi.bg.ab")
    local stables = T.seeded(NS, "bi.bg.ab.stables")
    Lib.DeleteGroup(ab)   -- its nodes become top-level groups
    assertTrue(not p.groups[stables].parent)
    local n = Lib.RestoreBuiltins()
    assertEqual(n.groups, 1, "the set alone: its nodes are still the player's")
    local new = T.seeded(NS, "bi.bg.ab")
    assertEqual(#Lib.Children(new), 0)
    assertTrue(not p.groups[stables].parent, "a group the player has is not moved")
end)

test("library: [restore] a set nested in another group keeps its place; its nodes stay out", function()
    local NS, Lib, p = boot()
    local ab = T.seeded(NS, "bi.bg.ab")
    for _, kid in ipairs(Lib.Children(ab)) do Lib.DeleteGroup(kid) end
    local mine = Lib.CreateGroup({ name = "Mine" })
    assertTrue((NS.SchemaRuntime.Set("group.parent", mine, ab)))
    local n = Lib.RestoreBuiltins()
    -- red under: drop the ValidParent check before a node is seeded into its set
    assertEqual(n.groups, 0, "a node cannot go inside a group that is inside another")
    assertEqual(p.groups[ab].parent, mine)
    assertEqual(#Lib.Children(ab), 0)
end)

test("library: [restore] a new pad holds the seeded sets still top-level, in shipped order", function()
    local NS, Lib, p = boot()
    Lib.DeleteGroup(T.seeded(NS, "bi.raid"))
    local mine = Lib.CreateGroup({ name = "Mine" })
    NS.SchemaRuntime.Set("group.parent", mine, T.seeded(NS, "bi.arena"))
    local id = Lib.CreateSurface("pad", "Two")
    local want = {}
    for _, top in ipairs(NS.BuiltIns.order) do
        local gid = T.seeded(NS, top)
        if gid and not Lib.IsChild(gid) then want[#want + 1] = gid end
    end
    assertEqual(#want, #NS.BuiltIns.order - 2)
    assertEqual(table.concat(p.pads[id].groups, ","), table.concat(want, ","))
end)

-- ── Inherit when conditions (2026-10-18-when-drawers-design.md §3) ─────────────────────────

test("library: [inherit] a new or seeded group inherits its parent's When; Duplicate and an untick keep false", function()
    local NS, Lib, p = boot()
    local ab = T.seeded(NS, "bi.bg.ab")
    -- red under: seedGroup storing no inheritWhen (or false) on a node
    for _, kid in ipairs(Lib.Children(ab)) do assertTrue(p.groups[kid].inheritWhen, "a seeded node inherits") end
    local parent = Lib.CreateGroup({ name = "Raid night", when = { content = { raid = true } } })
    local child = Lib.CreateGroup({ name = "Boss 1" })
    setParent(NS, child, parent)
    assertTrue(p.groups[child].inheritWhen, "default on")
    assertTrue(NS.SchemaRuntime.Set("group.inheritWhen", false, child))
    assertEqual(p.groups[child].inheritWhen, false, "unticking stores false")
    local copy = Lib.DuplicateGroup(child)
    -- red under: DuplicateGroup not passing inheritWhen on
    assertEqual(p.groups[copy].inheritWhen, false, "the copy keeps the untick")
    assertTrue(Lib.TEMPLATES.group.inheritWhen, "the row's default is on")
end)

test("library: [all] ValidWhen takes all on the instance and battleground rows, and on no other", function()
    local NS = T.bootAddon()
    local Lib = NS.Library
    -- red under: an id row that takes positive whole ids only
    assertTrue((Lib.ValidWhen({ battleground = { all = true } })))
    assertTrue((Lib.ValidWhen({ instances = { all = true, [2526] = true } })))
    assertFalse((Lib.ValidWhen({ spec = { all = true } })))
    assertFalse((Lib.ValidWhen({ characters = { all = true } })))
end)

test("library: [arena] ValidWhen takes arena ids and all on the arena row", function()
    local NS = T.bootAddon()
    local Lib = NS.Library
    -- red under: an arena row the Resolver does not know (badWhen)
    assertTrue((Lib.ValidWhen({ arena = { all = true } })))
    assertTrue((Lib.ValidWhen({ arena = { [1505] = true, [572] = true } })))
    assertFalse((Lib.ValidWhen({ arena = { ["Nagrand Arena"] = true } })), "a name, not an id")
    assertFalse((Lib.ValidWhen({ arena = { [-1] = true } })))
    local _, _, why = NS.SchemaRuntime.Set("group.when", { arena = { nope = true } }, NS.Library.CreateGroup({ name = "Mine" }))
    assertTrue(tostring(why):find("an instance id", 1, true) ~= nil, tostring(why))
end)
