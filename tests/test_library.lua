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

test("library: whisper channels are refused (owner, issue #7)", function()
    local _, Lib = boot()
    local id, err = Lib.CreateCallout({ name = "W", text = "x", channel = "whisperTarget" })
    assertNil(id) assertEqual(err, "badChannel")
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

test("library: [final 2] a built-in whose copy fails validation is refused cleanly, with no hole", function()
    local NS, Lib, p = boot()
    NS.BuiltIns.callouts["bi.test.long"] = { name = string.rep("a", 40), text = "x", channel = "party" }
    local g = Lib.CreateGroup({ name = "G" })
    local ok = Lib.AddToGroup(g, Lib.CreateCallout({ name = "A", text = "x", channel = "party" }))
    local id, why = Lib.AddToGroup(g, "bi.test.long", 1)
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

test("library: [final 2] Customize skips a copy that fails and reports it, leaving no hole", function()
    local NS, Lib, p = boot()
    local top = NS.BuiltIns.order[1]
    local first = NS.BuiltIns.groups[top].callouts[1]
    NS.BuiltIns.callouts[first] = { name = string.rep("a", 40), text = "x", channel = "party" }
    local id, why, skipped = Lib.Customize(top)
    assertTrue(id ~= nil, tostring(why))
    assertEqual(skipped, 1)
    local list = p.groups[id].callouts
    for i = 1, #list do assertTrue(p.callouts[list[i]] ~= nil, "slot " .. i) end
    local n = 0
    for _ in pairs(list) do n = n + 1 end
    assertEqual(n, #list, "a sequence, no hole")
end)

test("library: [final minor 2] Prepare lifts a stale nextId above every existing id", function()
    local _, Lib, p = boot()
    p.callouts.c41 = { name = "A", text = "x", channel = "party" }
    p.groups.g7 = { name = "G", callouts = {}, when = {} }
    p.nextId = 3
    Lib.Prepare()
    -- red under: a Prepare that leaves nextId alone
    assertTrue(p.nextId >= 42, tostring(p.nextId))
    assertTrue(Lib.CreateCallout({ name = "B", text = "y", channel = "party" }) ~= "c41")
    assertEqual(p.callouts.c41.name, "A", "the old callout survived")
end)

test("library: [final minor 3] Prepare repairs corrupt top-level registry keys and builtins entries", function()
    local _, Lib, p = boot()
    p.groups, p.callouts, p.pads, p.padOrder, p.builtins = 5, "x", true, 7, { ["bi.a"] = 3, ["bi.b"] = { enabled = false } }
    local ok, result = pcall(Lib.Prepare)
    assertTrue(ok, tostring(result))
    for _, key in ipairs({ "callouts", "groups", "builtins", "pads", "dials", "padOrder", "dialOrder" }) do
        assertEqual(type(p[key]), "table", key)
    end
    assertNil(p.builtins["bi.a"])
    assertTrue(p.builtins["bi.b"] ~= nil)
    assertEqual(result.repaired, 5, "four top-level keys and one builtins entry")
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

test("library: [phase 3] DuplicateCallout copies every field under a '(copy)' name", function()
    local _, Lib, p = boot()
    local id = Lib.CreateCallout({ name = "Lust", text = "Lust {rt8}", channel = "party", icon = 136012 })
    local copy = Lib.DuplicateCallout(id)
    assertTrue(copy ~= id)
    local c = p.callouts[copy]
    assertEqual(c.name, "Lust (copy)")
    assertEqual(c.text, "Lust {rt8}")
    assertEqual(c.channel, "party")
    assertEqual(c.icon, 136012)
    assertNil((Lib.DuplicateCallout("c999")))
end)

test("library: [phase 3] a copy's name stays within the 32-character cap, counted in characters", function()
    local _, Lib = boot()
    local long = string.rep("\195\169", 30)          -- thirty two-byte characters
    local name = Lib.CopyName(long)
    assertEqual(select(2, name:gsub("[^\128-\191]", "")), Lib.NAME_MAX)
    assertTrue(name:sub(-7) == " (copy)")
    assertTrue(Lib.ValidName(name))
end)

test("library: [phase 3] DuplicateGroup shares the callouts (D8) and copies the When, on no surface", function()
    local _, Lib, p = boot()
    local cid = Lib.CreateCallout({ name = "A", text = "a", channel = "party" })
    local gid = Lib.CreateGroup({ name = "Mine", when = { content = { raid = true } } })
    Lib.AddToGroup(gid, cid)
    local copy = Lib.DuplicateGroup(gid)
    assertEqual(p.groups[copy].name, "Mine (copy)")
    assertEqual(p.groups[copy].callouts[1], cid, "the same callout, by reference")
    assertTrue(p.groups[copy].when.content.raid)
    p.groups[copy].when.content.raid = nil
    assertTrue(p.groups[gid].when.content.raid, "a copy, not an alias")
    for _, pad in pairs(p.pads) do
        for _, g in ipairs(pad.groups) do assertTrue(g ~= copy, "not offered to a surface") end
    end
    assertNil((Lib.DuplicateGroup("bi.mplus")), "a built-in is customized, never duplicated")
end)

test("library: [phase 3] CreateGroup keeps only existing user callouts, and validates the When", function()
    local _, Lib, p = boot()
    local cid = Lib.CreateCallout({ name = "A", text = "a", channel = "party" })
    local gid = Lib.CreateGroup({ name = "G", callouts = { cid, "c999", "bi.mplus.lust" } })
    assertEqual(#p.groups[gid].callouts, 1)
    assertEqual(p.groups[gid].callouts[1], cid)
    local bad, why = Lib.CreateGroup({ name = "G", when = { nope = { x = true } } })
    assertNil(bad)
    assertEqual(why, "badWhen")
    assertNil((Lib.CreateGroup({ name = "   " })), "a blank name is no name")
end)

test("library: [phase 3] OfferGroup puts a user group first on every pad and dial, once", function()
    local _, Lib, p = boot()
    local gid = Lib.CreateGroup({ name = "Mine" })
    assertEqual(Lib.OfferGroup(gid), 2, "the default pad and the default dial")
    assertEqual(p.pads.p1.groups[1], gid)
    assertEqual(p.dials.d2.groups[1], gid)
    assertEqual(Lib.OfferGroup(gid), 0, "already on both")
    assertEqual(Lib.OfferGroup("bi.mplus"), 0, "built-ins are seeded, never offered")
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

test("library: [phase 3] Member answers the live member of each kind, and a built-in group's copy", function()
    local NS, Lib, p = boot()
    local cid = Lib.CreateCallout({ name = "A", text = "a", channel = "party" })
    assertTrue(Lib.Member("callout", cid) == p.callouts[cid])
    assertTrue(Lib.Member("pad", "p1") == p.pads.p1)
    assertTrue(Lib.Member("dial", "d2") == p.dials.d2)
    local g = Lib.Member("group", "bi.mplus")
    assertEqual(g.name, NS.BuiltIns.groups["bi.mplus"].name)
    g.name = "changed"
    assertTrue(NS.BuiltIns.groups["bi.mplus"].name ~= "changed", "a copy: the shipped set never changes")
    assertTrue(Lib.Member("builtin", "bi.bg.ab.stables") == p.builtins["bi.bg.ab"], "a node's overlay is its battleground's")
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
    local NS, Lib, p = boot()
    assertEqual(#Lib.MemberIds("callout"), 0)
    local b = Lib.CreateCallout({ name = "beta", text = "b", channel = "party" })
    local a = Lib.CreateCallout({ name = "Alpha", text = "a", channel = "party" })
    assertEqual(table.concat(Lib.MemberIds("callout"), ","), a .. "," .. b, "by name, case-insensitive")
    local g = Lib.CreateGroup({ name = "Mine" })
    local groups = Lib.MemberIds("group")
    assertEqual(groups[1], g, "user groups first")
    assertEqual(groups[2], NS.BuiltIns.order[1], "then the built-in sets in shipped order")
    assertEqual(#groups, 1 + #NS.BuiltIns.order)
    assertEqual(table.concat(Lib.MemberIds("pad"), ","), table.concat(p.padOrder, ","))
    assertEqual(#Lib.MemberIds("nope"), 0)
end)

test("library: [phase 3] Customize shortens a long set name instead of refusing it", function()
    local NS, Lib, p = boot()
    NS.BuiltIns.groups["bi.mplus"].name = string.rep("x", 30)
    local id = Lib.Customize("bi.mplus")
    assertTrue(id ~= nil, "a copy, whatever the set's name")
    local name = p.groups[id].name
    assertTrue(Lib.ValidName(name))
    assertEqual(name:sub(-9), " (custom)")
end)

test("library: [phase 3] Customize changes nothing when the copy cannot be made", function()
    local _, Lib, p = boot()
    local before = table.concat(p.pads.p1.groups, ",")
    Lib.CreateGroup = function() return nil, "badWhen" end
    local id, why = Lib.Customize("bi.mplus")
    -- red under: drop the `if not id then return nil, why end` guard from Lib.Customize
    assertNil(id)
    assertEqual(why, "badWhen")
    assertEqual(table.concat(p.pads.p1.groups, ","), before, "no hole where the set was")
    local o = p.builtins["bi.mplus"]
    assertTrue(o == nil or o.enabled ~= false, "the set stays on")
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

test("library: [phase 3] the point, icon and hidden-set validators", function()
    local _, Lib = boot()
    assertTrue(Lib.ValidPoint(nil), "nil is the default place")
    assertTrue(Lib.ValidPoint({ "TOPLEFT", "TOPLEFT", 1, -2 }))
    assertFalse(Lib.ValidPoint({ "TOPLEFT", "TOPLEFT", "1", -2 }))
    assertFalse(Lib.ValidPoint("CENTER"))
    assertTrue(Lib.ValidIcon(nil))
    assertTrue(Lib.ValidIcon(false))
    assertTrue(Lib.ValidIcon(136012))
    assertTrue(Lib.ValidIcon("Interface\\Icons\\Spell_Nature_Bloodlust"))
    assertFalse(Lib.ValidIcon(""))
    assertFalse(Lib.ValidIcon({}))
    assertTrue(Lib.ValidHidden("bi.bg.ab", { ["bi.bg.ab.stables.inc1"] = true }))
    assertTrue(Lib.ValidHidden("bi.mplus", {}))
    assertFalse(Lib.ValidHidden("bi.mplus", { ["bi.raid.wipe"] = true }), "another set's callout")
    assertFalse(Lib.ValidHidden("bi.mplus", { ["bi.mplus.nope"] = true }), "no such callout")
    assertFalse(Lib.ValidHidden("bi.mplus", { ["bi.mplus.lust"] = 1 }))
    assertFalse(Lib.ValidHidden(nil, {}))
end)

test("library: [phase 3] every member template holds a value at every field", function()
    local _, Lib = boot()
    assertEqual(Lib.TEMPLATES.callout.channel, "smartGroup")
    assertEqual(Lib.TEMPLATES.pad.layout.style, "iconLabel")
    assertEqual(Lib.TEMPLATES.pad.look.visibility, "always")
    assertTrue(Lib.TEMPLATES.pad.point == false, "false: the default place, and a value the boot check can see")
    assertTrue(Lib.TEMPLATES.builtin.enabled)
    assertTrue(Lib.IsBuiltin("bi.raid"))
    assertFalse(Lib.IsBuiltin("g3"))
    assertEqual(Lib.TopOf("bi.bg.ab.stables"), "bi.bg.ab")
end)
