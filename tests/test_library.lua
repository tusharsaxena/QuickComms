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

test("library: adding a built-in callout copies it (P2)", function()
    local _, Lib, p = boot()
    local g = Lib.CreateGroup({ name = "Mine" })
    local added = Lib.AddToGroup(g, "bi.mplus.lust")
    assertTrue(added:match("^c%d+$") ~= nil)
    assertEqual(p.callouts[added].text, "Lust on this pack {rt8}")
    assertEqual(p.groups[g].callouts[1], added)
end)

test("library: [review 4] Customize swaps the copy in place; deleting the copy puts the set back, on", function()
    local NS, Lib, p = boot()
    local pad = p.pads[p.padOrder[1]]
    local pos
    for i, gid in ipairs(pad.groups) do if gid == "bi.mplus" then pos = i end end
    local copy, _, skipped, placed = Lib.Customize("bi.mplus")
    assertEqual(pad.groups[pos], copy)
    assertEqual(skipped, 0)
    assertEqual(placed, 2, "the pad and the dial")
    assertFalse(Lib.Group("bi.mplus").enabled)
    assertEqual(#p.groups[copy].callouts, 8)
    assertTrue(p.groups[copy].callouts[1]:match("^c%d+$") ~= nil)
    Lib.DeleteGroup(copy)
    -- red under: Lib.DeleteGroup only removes the copy (the set is on no pad and stays off)
    assertEqual(pad.groups[pos], "bi.mplus", "the set is back in the copy's place")
    for _, gid in ipairs(pad.groups) do assertTrue(gid ~= copy) end
    assertTrue(Lib.Group("bi.mplus").enabled, "and turned back on")
    assertNil(NS.db.profile.builtins["bi.mplus"].customizedAs)
    local again, _, _, placedAgain = Lib.Customize("bi.mplus")
    assertEqual(pad.groups[pos], again, "a second Customize takes the set's place again")
    assertEqual(placedAgain, 2)
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
    p.groups.g7 = { name = "G", callouts = { "c41" }, when = {} }
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

test("library: [phase 3] the point, icon and hidden-set validators", function()
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

test("library: [phase 3] Batch holds the announces and sends one per kind it touched", function()
    local NS, Lib, _, sent = boot()
    local before = #sent
    Lib.Batch(function()
        Lib.SetBuiltinEnabled("bi.raid", false)
        Lib.SetBuiltinEnabled("bi.arena", false)
        Lib.Batch(function() Lib.SetBuiltinEnabled("bi.mplus", false) end)
    end)
    -- red under: announce inside Lib.Batch as usual (three messages)
    assertEqual(#sent - before, 1)
    assertEqual(sent[#sent][1], NS.MSG.LIBRARY_CHANGED)
    assertEqual(sent[#sent][2], "builtin")
    assertNil(sent[#sent][3], "no id: several members changed")
    assertFalse(NS.db.profile.builtins["bi.mplus"].enabled)
    Lib.SetBuiltinEnabled("bi.raid", true)
    assertEqual(#sent - before, 2, "announces flow again after the batch")
end)

test("library: [final 8] a set on no surface is customized onto none, and Customize says how many it reached", function()
    local _, Lib, p = boot()
    for _, sid in ipairs(p.padOrder) do Lib.RemoveGroupFromSurface("pad", sid, "bi.mplus") end
    for _, sid in ipairs(p.dialOrder) do Lib.RemoveGroupFromSurface("dial", sid, "bi.mplus") end
    local copy, _, _, placed = Lib.Customize("bi.mplus")
    assertTrue(p.groups[copy] ~= nil)
    assertEqual(placed, 0)
end)

test("library: [final 24] Customize puts the copy in the set's place on every pad and dial", function()
    local _, Lib, p = boot()
    local second = Lib.CreateSurface("pad", "Two")
    Lib.MoveGroupOnSurface("pad", second, #p.pads[second].groups, 1)
    local where = {}
    for _, kind in ipairs({ "pad", "dial" }) do
        local set = kind == "pad" and p.pads or p.dials
        for _, s in pairs(set) do
            for i, gid in ipairs(s.groups) do if gid == "bi.mplus" then where[#where + 1] = { s, i } end end
        end
    end
    assertEqual(#where, 3, "two pads and a dial hold the set")
    local copy = Lib.Customize("bi.mplus")
    -- red under: narrow the swap loop in Lib.Customize to the first surface
    for _, w in ipairs(where) do assertEqual(w[1].groups[w[2]], copy) end
end)

test("library: [final 1] Customize, AddToGroup with a built-in, and OfferGroup each send one LIBRARY_CHANGED", function()
    local NS, Lib, p, sent = boot()
    local before = #sent
    -- red under: drop Lib.Batch from Lib.Customize (19 messages for M+, 63 for a 30-callout battleground)
    Lib.Customize("bi.mplus")
    assertEqual(#sent - before, 1)
    assertEqual(sent[#sent][1], NS.MSG.LIBRARY_CHANGED)
    assertEqual(sent[#sent][2], "builtin,callout,group", "the kinds it touched")
    before = #sent
    Lib.Customize("bi.bg.ab")
    assertEqual(#sent - before, 1)
    local g = Lib.CreateGroup({ name = "Mine" })
    before = #sent
    -- red under: drop Lib.Batch from Lib.AddToGroup (the copy and the insert announce apart)
    Lib.AddToGroup(g, "bi.mplus.lust")
    assertEqual(#sent - before, 1)
    Lib.CreateSurface("pad", "Two")
    before = #sent
    -- red under: drop Lib.Batch from Lib.OfferGroup (one per surface)
    assertEqual(Lib.OfferGroup(g), #p.padOrder + #p.dialOrder)
    assertEqual(#sent - before, 1)
end)

test("library: [final 1] one Customize click rebuilds the pads once", function()
    local NS = T.enableAddon()
    NS.Situation.ReadInputs = function() return { inInstance = true, instanceType = "party", difficultyID = 8,
        keystoneActive = true, keyLevel = 12, inGroup = true } end
    NS.Situation.RefreshNow("test")
    local applied = 0
    local apply = NS.Surfaces.ApplyAll
    NS.Surfaces.ApplyAll = function(...) applied = applied + 1 return apply(...) end
    NS.Library.Customize("bi.bg.ab")
    NS.Library.Customize("bi.mplus")
    NS.Surfaces.ApplyAll = apply
    assertEqual(applied, 2, "one rebuild per Customize")
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

test("library: [phase 4] keys: upper-cased, none is false; what the open dial uses is reserved", function()
    local _, Lib = boot()
    assertEqual(Lib.KeyValue(" shift-g "), "SHIFT-G")
    assertEqual(Lib.KeyValue("none"), false)
    assertEqual(Lib.KeyValue(""), false)
    assertTrue(Lib.ValidKey("SHIFT--"), "the minus key with a modifier")
    assertTrue(Lib.ValidKey(false))
    T.assertFalse((Lib.ValidKey("ESCAPE")))
    T.assertFalse((Lib.ValidKey("ALT-BUTTON2")))
    -- red under: drop MOUSEWHEELUP from RESERVED_KEYS (the open dial turns its pages with it)
    T.assertFalse((Lib.ValidKey("SHIFT-MOUSEWHEELUP")))
    -- red under: drop RESERVED_BARE (an open dial's 1-8 pick its wedges)
    T.assertFalse((Lib.ValidKey("3")))
    assertTrue(Lib.ValidKey("CTRL-3"), "a modified number is another key")
    assertTrue(Lib.ValidKey("9"))
    T.assertFalse((Lib.ValidKey("SHIFT G")))
end)

test("library: [final 3] a key is one base key with known modifiers, none twice; a bare or dangling modifier is no key", function()
    local _, Lib = boot()
    -- red under: take everything before the last '-' on trust in Lib.ValidKey
    for _, bad in ipairs({ "SHIFT", "shift-", "CTRL-", "FOO-G", "SHIFT-SHIFT-G", "LSHIFT", "ALT-RCTRL", "-G",
        "CTRL---", "SHIFT--G" }) do
        local ok, why = Lib.ValidKey(bad)
        T.assertFalse(ok, bad)
        assertEqual(why, "badKey", bad)
    end
    assertTrue(Lib.ValidKey("-"), "the minus key")
    assertTrue(Lib.ValidKey("CTRL--"), "the minus key with a modifier")
    assertTrue(Lib.ValidKey("META-G"))
    assertTrue(Lib.ValidKey("ALT-CTRL-SHIFT-F1"))
end)

test("library: [final 4] modifiers are stored in the client's order, ALT-CTRL-SHIFT-META", function()
    local _, Lib = boot()
    -- red under: only trim and upper-case in Lib.KeyValue
    assertEqual(Lib.KeyValue("shift-ctrl-g"), "CTRL-SHIFT-G")
    assertEqual(Lib.KeyValue("META-SHIFT-ALT-X"), "ALT-SHIFT-META-X")
    assertEqual(Lib.KeyValue("shift--"), "SHIFT--")
    assertEqual(Lib.KeyValue("FOO-G"), "FOO-G", "not a key: kept as typed, for ValidKey to refuse")
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

-- ── import (phase 5) ────────────────────────────────────────────────────────────────────────

-- A share result for two callouts, a group holding both, a pad and a dial listing the group and a
-- built-in set, checked by modules/Share.lua as an import is.
local function shared(NS)
    return NS.Share.Validate({ v = 1, addon = "QuickComms", kind = "bundle",
        callouts = { c1 = { name = "Kick", text = "Kick on me", channel = "party" },
            c2 = { name = "Lust", text = "Lust now", channel = "smartGroup", icon = 136012 } },
        groups = { g1 = { name = "Mine", callouts = { "c2", "c1" }, when = { content = { mythicPlus = true } } } },
        pads = { p1 = { name = "Their pad", groups = { "g1", "bi.mplus" },
            fields = { ["pad.layout.columns"] = 6, ["pad.layout.spacing"] = 999 } } },
        dials = { d2 = { name = "Their dial", groups = { "g1" }, fields = { ["dial.mode"] = "flat" } } },
    })
end

test("library: [phase 5] Import makes every member under a fresh id, its references pointing at the copies", function()
    local NS, Lib, p = boot()
    local tally, map = Lib.Import(shared(NS))
    assertEqual(tally.callouts .. tally.groups .. tally.pads .. tally.dials, "2111")
    local gid = map.g1
    assertTrue(gid ~= "g1" and p.groups[gid] ~= nil)
    assertEqual(p.groups[gid].callouts[1], map.c2, "the group's order is kept, pointing at the new copies")
    assertEqual(p.groups[gid].callouts[2], map.c1)
    assertTrue(p.groups[gid].when.content.mythicPlus)
    assertEqual(p.callouts[map.c2].icon, 136012)
    local pad = p.pads[map.p1]
    assertEqual(table.concat(pad.groups, ","), gid .. ",bi.mplus")
    assertEqual(pad.layout.columns, 6)
    assertEqual(pad.layout.spacing, 20, "the seam clamps what it would clamp for a player")
    assertEqual(p.padOrder[#p.padOrder], map.p1, "at the end of the pad order")
    assertEqual(p.dials[map.d2].mode, "flat")
end)

test("library: [review 3] importing the same string twice makes two copies; nothing that existed changes", function()
    local NS, Lib, p = boot()
    local mine = Lib.CreateCallout({ name = "Kick", text = "Mine", channel = "say" })
    -- the fixture's p1 and d2 are the ids of this profile's own default pad and dial
    local pad, dial = p.pads.p1, p.dials.d2
    assertTrue(pad ~= nil and dial ~= nil, "the seeded pad p1 and dial d2")
    local function shape(s) return s.name .. "|" .. table.concat(s.groups, ",") end
    local padBefore, dialBefore, padColumns = shape(pad), shape(dial), pad.layout.columns
    local orderBefore = table.concat(p.padOrder, ",")
    local _, first = Lib.Import(shared(NS))
    local _, second = Lib.Import(shared(NS))
    assertTrue(first.c1 ~= second.c1 and first.c1 ~= mine and second.c1 ~= mine)
    assertTrue(first.p1 ~= "p1" and first.d2 ~= "d2" and first.p1 ~= second.p1 and first.d2 ~= second.d2,
        "an overlapping id is never reused")
    assertTrue(p.pads.p1 == pad and p.dials.d2 == dial, "the same tables")
    assertEqual(shape(pad), padBefore, "the default pad p1 is unchanged")
    assertEqual(pad.layout.columns, padColumns)
    assertEqual(shape(dial), dialBefore, "the default dial d2 is unchanged")
    assertEqual(table.concat(p.padOrder, ","), orderBefore .. "," .. first.p1 .. "," .. second.p1, "p1 once in the order")
    assertEqual(p.callouts[mine].text, "Mine")
    assertEqual(p.callouts[first.c1].name, "Kick", "a name may repeat")
    assertEqual(p.callouts[second.c1].name, "Kick")
    assertEqual(p.groups[second.g1].callouts[1], second.c2, "each copy points at its own callouts")
end)

test("library: [review 4] an imported pad and dial arrive unbound: no key, the default place, no built-in re-added", function()
    local NS, Lib, p = boot()
    local res = shared(NS)
    -- a hand-made result that slipped a key and a position past the checks is still refused them
    res.dials[1].fields["dial.key"] = "G"
    res.pads[1].fields["pad.point"] = { "TOPLEFT", "TOPLEFT", 10, -10 }
    local tally, map = Lib.Import(res)
    local dial, pad = p.dials[map.d2], p.pads[map.p1]
    -- red under: drop the Share.Portable check from importSurface (the seam itself takes a key)
    assertTrue(dial.key == nil or dial.key == false, "no key: " .. tostring(dial.key))
    assertTrue(pad.point == nil or pad.point == false, "the default place")
    assertEqual(tally.ignored, 2)
    Lib.Prepare()
    assertEqual(#pad.groups, 2, "every built-in was already marked seen")
end)

test("library: [review] an imported Look keeps a bool a bool and a color its four channels", function()
    local NS, Lib, p = boot()
    local res = NS.Share.Validate({ v = 1, addon = "QuickComms", kind = "bundle",
        pads = { p1 = { name = "Junk look", fields = {
            ["pad.look.fontShadow"] = "yes", ["pad.look.useClassColorFont"] = { 1, 2, 3 },
            ["pad.look.useClassColorBackground"] = 7, ["pad.look.useClassColorBorder"] = true,
            ["pad.look.fontColor"] = { r = 0.5, g = 0.5, b = 0.5, junk = { a = { b = "x" } } },
            ["pad.look.background"] = { 0.1, 0.2, 0.3 } } } } })
    local tally, map = Lib.Import(res)
    local look = p.pads[map.p1].look
    -- red under: no validate on the four bool rows in lookChecks (settings/SchemaMembers.lua)
    assertEqual(look.fontShadow, true, "the default stands")
    assertEqual(look.useClassColorFont, false)
    assertEqual(look.useClassColorBackground, false)
    assertEqual(look.useClassColorBorder, true)
    assertEqual(tally.ignored, 3)
    -- red under: no normalize on the color rows (the junk subtree is stored and exported again)
    local keys = {}
    for k in pairs(look.fontColor) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    assertEqual(table.concat(keys, ","), "a,b,g,r")
    assertEqual(look.fontColor.r, 0.5)
    assertEqual(look.fontColor.a, 1)
    assertEqual(look.background.r .. "," .. look.background.b .. "," .. look.background.a, "0.1,0.3,1")
end)

test("library: [phase 5] Import is one act: one LIBRARY_CHANGED; a refused result imports nothing", function()
    local NS, Lib, _, sent = boot()
    local res = shared(NS)
    for i = #sent, 1, -1 do sent[i] = nil end
    Lib.Import(res)
    local n = 0
    for _, s in ipairs(sent) do if s[1] == NS.MSG.LIBRARY_CHANGED then n = n + 1 end end
    -- red under: drop Lib.Batch from Lib.Import (one announce per member and per field)
    assertEqual(n, 1)
    assertEqual(sent[#sent][2], "callout,dial,group,pad")
    assertNil(Lib.Import({ ok = false, reason = "newer" }))
    assertNil(Lib.Import(nil))
end)

test("library: [phase 5] Prepare gives a pad saved before the Look groups every field it lacks", function()
    local NS, Lib, p = boot()
    local pad = p.pads[p.padOrder[1]]
    pad.look = { visibility = "never" }
    pad.layout.width = nil
    Lib.Prepare()
    assertEqual(pad.look.visibility, "never", "a stored value is kept")
    assertEqual(pad.look.font, "Friz Quadrata TT")
    assertEqual(pad.look.background.a, 0.92)
    assertEqual(pad.layout.width, 140)
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
    assertNil((Lib.CreateCalloutIn("bi.mplus", { name = "D", text = "d", channel = "party" })), "a built-in is read-only")
    assertEqual(p.nextId, nextId, "a refusal consumes no id")
end)


-- ── a glyph's color (icon browser spec, "Data model") ───────────────────────────────────────

test("library: [icons] IsGlyph names a catalog icon by its path; ValidIconColor takes none or rrggbb", function()
    local NS, Lib = boot()
    assertEqual(Lib.IsGlyph(NS.Icon("star")), "star")
    assertNil(Lib.IsGlyph("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"), "a raid marker is no glyph")
    assertNil(Lib.IsGlyph(136012))
    assertNil(Lib.IsGlyph(false))
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

test("library: [icons] an import carries a glyph's color into the fresh copies", function()
    local NS, Lib, p = boot()
    local star = NS.Icon("star")
    local res = NS.Share.Validate({ v = 1, addon = "QuickComms", kind = "bundle",
        callouts = { c1 = { name = "A", text = "a", channel = "say", icon = star, iconColor = "ff0000" } },
        groups = { g1 = { name = "G", icon = star, iconColor = "00ff00", callouts = { "c1" } } } })
    local _, map = Lib.Import(res)
    -- red under: importMembers building the group without iconColor
    assertEqual(p.groups[map.g1].iconColor, "00ff00")
    assertEqual(p.callouts[map.c1].iconColor, "ff0000")
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
