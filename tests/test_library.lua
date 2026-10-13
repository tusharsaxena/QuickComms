-- tests/test_library.lua — modules/Library.lua (spec §5, §12.2): the only writer of the registry.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function boot()
    local NS = T.bootAddon()
    local sent = {}
    NS.addon.SendMessage = function(_, name, kind, id) sent[#sent + 1] = { name, kind, id } end
    return NS, NS.Library, NS.db.profile, sent
end

test("library: Prepare seeds one pad and one dial with every built-in, once", function()
    local NS, Lib, p = boot()
    assertTrue(p.seeded)
    assertEqual(#p.padOrder, 1)
    assertEqual(#p.dialOrder, 1)
    local pad = p.pads[p.padOrder[1]]
    assertEqual(#pad.groups, #NS.BuiltIns.order)
    local again = Lib.Prepare()
    assertFalse(again.seeded)
    assertEqual(#p.padOrder, 1)
end)

test("library: callouts validate on create", function()
    local _, Lib = boot()
    assertNil((Lib.CreateCallout({ name = "", text = "x", channel = "party" })))
    assertNil((Lib.CreateCallout({ name = "A", text = "x", channel = "guild" })))
    assertNil((Lib.CreateCallout({ name = "A", text = 5, channel = "party" })))
    local id = Lib.CreateCallout({ name = "Lust", text = "Lust {rt8}", channel = "smartGroup" })
    assertTrue(id:match("^c%d+$") ~= nil)
end)

test("library: [review 4] deleting a shared callout clears every group", function()
    local _, Lib, p = boot()
    local c = Lib.CreateCallout({ name = "Lust", text = "Lust", channel = "party" })
    local g1 = Lib.CreateGroup({ name = "One" })
    local g2 = Lib.CreateGroup({ name = "Two" })
    Lib.AddToGroup(g1, c) Lib.AddToGroup(g2, c)
    assertEqual(#Lib.UsedBy(c), 2)
    assertTrue(Lib.DeleteCallout(c))
    assertEqual(#p.groups[g1].callouts, 0)
    assertEqual(#p.groups[g2].callouts, 0)
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

test("library: adding a built-in callout copies it (P2)", function()
    local _, Lib, p = boot()
    local g = Lib.CreateGroup({ name = "Mine" })
    local added = Lib.AddToGroup(g, "bi.mplus.lust")
    assertTrue(added:match("^c%d+$") ~= nil)
    assertEqual(p.callouts[added].text, "Lust on this pack {rt8}")
    assertEqual(p.groups[g].callouts[1], added)
end)

test("library: [review 4] Customize swaps the copy in place, then deleting it leaves neither", function()
    local _, Lib, p = boot()
    local pad = p.pads[p.padOrder[1]]
    local pos
    for i, gid in ipairs(pad.groups) do if gid == "bi.mplus" then pos = i end end
    local copy = Lib.Customize("bi.mplus")
    assertEqual(pad.groups[pos], copy)
    assertFalse(Lib.Group("bi.mplus").enabled)
    assertEqual(#p.groups[copy].callouts, 8)
    assertTrue(p.groups[copy].callouts[1]:match("^c%d+$") ~= nil)
    Lib.DeleteGroup(copy)
    for _, gid in ipairs(pad.groups) do assertTrue(gid ~= copy and gid ~= "bi.mplus") end
end)

test("library: hidden built-in callouts drop out of the merged group", function()
    local _, Lib = boot()
    Lib.SetBuiltinCalloutHidden("bi.mplus", "bi.mplus.gg", true)
    local g = Lib.Group("bi.mplus")
    for _, cid in ipairs(g.callouts) do assertTrue(cid ~= "bi.mplus.gg") end
    assertTrue(Lib.Callout("bi.mplus.gg").builtin)
end)

test("library: [review 5] a newly shipped built-in is appended once; a removed one stays removed", function()
    local NS, Lib, p = boot()
    local pad = p.pads[p.padOrder[1]]
    NS.BuiltIns.Group("bi.test", { name = "New set", when = {} })
    local r = Lib.Prepare()
    assertEqual(r.appended, 2)                        -- the pad and the dial
    assertEqual(pad.groups[#pad.groups], "bi.test")
    Lib.Prepare()
    local count = 0
    for _, gid in ipairs(pad.groups) do if gid == "bi.test" then count = count + 1 end end
    assertEqual(count, 1)
    Lib.RemoveGroupFromSurface("pad", p.padOrder[1], "bi.arena")
    Lib.Prepare()
    for _, gid in ipairs(pad.groups) do assertTrue(gid ~= "bi.arena") end
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

test("library: AllGroups is top-level only and merges the overlay", function()
    local _, Lib = boot()
    Lib.SetBuiltinEnabled("bi.raid", false)
    local all = Lib.AllGroups()
    assertTrue(all["bi.bg.ab"] ~= nil)
    assertNil(all["bi.bg.ab.stables"])
    assertFalse(all["bi.raid"].enabled)
end)

test("library: every mutation announces LIBRARY_CHANGED", function()
    local NS, Lib, _, sent = boot()
    Lib.CreateCallout({ name = "A", text = "a", channel = "party" })
    assertEqual(sent[#sent][1], NS.MSG.LIBRARY_CHANGED)
    assertEqual(sent[#sent][2], "callout")
end)

test("library: overlay writers resolve child ids to the top-level overlay", function()
    local _, Lib, p = boot()
    local child = "bi.bg.ab.stables"
    local cid = Lib.Group(child).callouts[1]
    assertTrue(Lib.SetBuiltinCalloutHidden(child, cid, true))
    for _, x in ipairs(Lib.Group(child).callouts) do assertTrue(x ~= cid) end
    assertNil(p.builtins[child])
    assertTrue(p.builtins["bi.bg.ab"].hidden[cid])
    assertFalse(Lib.AddGroupToSurface("pad", p.padOrder[1], child))
end)

test("library: Customize twice is refused until the copy is deleted", function()
    local _, Lib = boot()
    local copy = Lib.Customize("bi.raid")
    assertTrue(copy ~= nil)
    local again, why = Lib.Customize("bi.raid")
    assertNil(again)
    assertEqual(why, "alreadyCustomized")
    Lib.DeleteGroup(copy)
    assertTrue(Lib.Customize("bi.raid") ~= nil)
end)

test("library: Customize copies openInto and flattens node callouts", function()
    local _, Lib, p = boot()
    local copy = Lib.Customize("bi.bg.ab")
    assertTrue(p.groups[copy].openInto)
    assertEqual(#p.groups[copy].callouts, 30)
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
