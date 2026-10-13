-- tests/test_groups_when.lua — settings/Groups_When.lua (spec §5.3, §13.2): the When editor's pure half
-- (toggle, clear, the key-level range, the values a row offers, the description, the active-now line)
-- and its write through the seam. The tab itself is driven in tests/test_page_groups.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function boot()
    local NS = T.bootAddon()
    return NS, NS.addon.Settings.GroupsWhen
end

test("when: Toggle adds and removes one value, drops an emptied row, and never mutates its input", function()
    local _, W = boot()
    local w0 = {}
    local w1 = W.Toggle(w0, "content", "mythicPlus", true)
    assertTrue(w1.content.mythicPlus)
    assertNil(w0.content, "a copy")
    local w2 = W.Toggle(w1, "content", "raid", true)
    assertTrue(w2.content.raid and w2.content.mythicPlus)
    local w3 = W.Toggle(W.Toggle(w2, "content", "raid", false), "content", "mythicPlus", false)
    assertNil(w3.content, "an emptied row is no row")
    assertTrue(w2.content.raid, "the earlier copy is untouched")
    assertNil(W.ClearRow(w2, "content").content)
end)

test("when: [review 5] the key-level range refuses lowest above highest; clearing both drops the row", function()
    local _, W = boot()
    local w, why = W.SetKeyLevel({}, 12, 10)
    assertNil(w)
    assertEqual(why, "badRange")
    w = W.SetKeyLevel({}, 10, nil)
    assertEqual(w.keyLevel.min, 10)
    assertNil(w.keyLevel.max)
    assertNil(W.SetKeyLevel(w, nil, nil).keyLevel)
    assertTrue(W.IsSet({ keyLevel = { max = 5 } }, "keyLevel"))
    assertFalse(W.IsSet({ keyLevel = {} }, "keyLevel"))
    assertFalse(W.IsSet({ content = {} }, "content"))
end)

test("when: [review 5] a typed key level is refused when the range would be upside down, and nothing is stored", function()
    local NS, W = boot()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    assertTrue(W.SetKeyField(gid, "min", "12"))
    assertEqual(NS.db.profile.groups[gid].when.keyLevel.min, 12)
    assertFalse(W.SetKeyField(gid, "max", "10"))
    assertNil(NS.db.profile.groups[gid].when.keyLevel.max)
    assertFalse(W.SetKeyField(gid, "max", "ten"))
    assertTrue(W.SetKeyField(gid, "min", ""))
    assertNil(NS.db.profile.groups[gid].when.keyLevel, "both ends empty: no row")
end)

test("when: the specialization row offers the player's class, or the classes the class row picked", function()
    local NS, W = boot()
    NS.Situation.Current = function() return { classFile = "MAGE" } end
    local function values(when)
        local out = {}
        for i, v in ipairs(W.Values("spec", when)) do out[i] = v.value end
        return table.concat(out, ",")
    end
    assertEqual(values({}), "62,63,64")
    assertEqual(values({ class = { PRIEST = true } }), "256,257,258")
    assertEqual(values({ spec = { [265] = true } }), "62,63,64,265", "a picked spec of another class stays listed")
    assertEqual(#W.Values("content", {}), 9)
    assertEqual(W.Values("role", {})[1].value, "TANK")
end)

test("when: Describe reads a When back as lines, and ActiveLine names the row that does not match", function()
    local NS, W = boot()
    assertEqual(W.Describe({})[1], "Always: this group has no conditions.")
    local lines = W.Describe({ content = { mythicPlus = true }, keyLevel = { min = 10 } })
    assertEqual(lines[1], "Content: M+")
    assertEqual(lines[2], "Key level: 10 to any")
    local snap = NS.Situation.Classify({ inInstance = true, instanceType = "raid", difficultyID = 15 })
    assertTrue(W.ActiveLine({ when = { content = { raid = true } } }, snap):find("Active now", 1, true) ~= nil)
    local line = W.ActiveLine({ when = { content = { mythicPlus = true } } }, snap)
    assertTrue(line:find("Content does not match", 1, true) ~= nil, line)
    line = W.ActiveLine({ when = {} }, snap, "Arena")
    assertTrue(line:find("In the preview (Arena)", 1, true) ~= nil, line)
end)

test("when: [phase 3] a group turned off never reads Active now, as the picker's dot does not", function()
    local NS, W = boot()
    local snap = NS.Situation.Classify({ inInstance = true, instanceType = "raid", difficultyID = 15 })
    -- red under: drop the `enabled == false` branch from W.ActiveLine
    local line = W.ActiveLine({ enabled = false, when = { content = { raid = true } } }, snap)
    assertTrue(line:find("Off: this group is turned off.", 1, true) ~= nil, line)
    NS.Library.SetBuiltinEnabled("bi.raid", false)
    line = W.ActiveLine(NS.Library.Group("bi.raid"), snap)
    assertTrue(line:find("Active now", 1, true) == nil, line)
end)

test("when: CharacterId takes Name-Realm as typed and gives a bare name the player's realm", function()
    local _, W = boot()
    local live = { character = "Me-Area52" }
    assertEqual(W.CharacterId("Traxex", live), "Traxex-Area52")
    assertEqual(W.CharacterId("  Traxex-Other  ", live), "Traxex-Other")
    assertNil(W.CharacterId("two words", live))
    assertNil(W.CharacterId("Traxex", {}), "no realm to add")
    assertNil(W.CharacterId("", live))
end)

test("when: [phase 3] the open rows are session state that a profile switch clears", function()
    local NS = T.enableAddon()
    NS.State.whenOpen.g1 = { content = true }
    NS.addon.db:SetProfile("Other")
    -- red under: drop the whenOpen loop from Editors' onProfileChanged
    assertNil(NS.State.whenOpen.g1)
end)

test("when: Write stores a user group's When through the seam and refuses a built-in with its reason", function()
    local NS, W = boot()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    assertTrue(W.Write(gid, { content = { arena = true } }))
    assertTrue(NS.db.profile.groups[gid].when.content.arena)
    assertFalse(W.Write("bi.mplus", { content = { arena = true } }))
    assertTrue(NS.BuiltIns.groups["bi.mplus"].when.content.mythicPlus)
end)

test("when: the battleground names come from the shipped sets, by instanceID", function()
    local _, W = boot()
    assertEqual(W.BattlegroundName(2107), "Arathi Basin")
    assertEqual(W.BattlegroundName(489), "Warsong Gulch")
    assertEqual(W.InstanceName(99999), "Instance 99999")
end)
