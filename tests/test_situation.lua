-- tests/test_situation.lua — modules/Situation.lua (spec §6): the classifier's truth table, the
-- signature, the edge (secret and loading-screen safety), coalescing and the message.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function inputs(over)
    local i = { inInstance = false, inGroup = false, inRaid = false, inInstanceGroup = false }
    for k, v in pairs(over or {}) do i[k] = v end
    return i
end

local TRUTH = {
    { "open world solo",     inputs(),                                                    "openWorld",    "solo" },
    { "open world party",    inputs({ inGroup = true }),                                  "openWorld",    "party" },
    { "heroic dungeon",      inputs({ inInstance = true, instanceType = "party", difficultyID = 2, inGroup = true }), "dungeon", "party" },
    { "M+ by flag",          inputs({ inInstance = true, instanceType = "party", difficultyID = 23, keystoneActive = true, inGroup = true }), "mythicPlus", "party" },
    { "M+ by difficulty",    inputs({ inInstance = true, instanceType = "party", difficultyID = 8, inGroup = true }), "mythicPlus", "party" },
    { "LFR",                 inputs({ inInstance = true, instanceType = "raid", difficultyID = 17, inGroup = true, inRaid = true, inInstanceGroup = true }), "raid", "raid" },
    { "delve",               inputs({ inInstance = true, instanceType = "scenario", difficultyID = 208 }), "delve", "solo" },
    { "scenario",            inputs({ inInstance = true, instanceType = "scenario" }),    "scenario",     "solo" },
    { "battleground",        inputs({ inInstance = true, instanceType = "pvp", inGroup = true, inRaid = true, inInstanceGroup = true }), "battleground", "raid" },
    { "arena",               inputs({ inInstance = true, instanceType = "arena", inGroup = true, inInstanceGroup = true }), "arena", "party" },
    { "housing",             inputs({ inHousing = true }),                                "housing",      "solo" },
    { "unknown type inside", inputs({ inInstance = true, instanceType = "neighborhood" }), "openWorld",   "solo" },
    { "empty inputs",        {},                                                           "openWorld",    "solo" },
}

test("situation: classifier truth table (content, group)", function()
    local NS = T.newAddon()
    for _, row in ipairs(TRUTH) do
        local s = NS.Situation.Classify(row[2])
        assertEqual(s.content, row[3], row[1] .. " content")
        assertEqual(s.group, row[4], row[1] .. " group")
    end
end)

test("situation: non-table input classifies as open world solo", function()
    local NS = T.newAddon()
    local s = NS.Situation.Classify(nil)
    assertEqual(s.content, "openWorld")
    assertEqual(s.group, "solo")
end)

test("situation: difficulty names by id", function()
    local NS = T.newAddon()
    local function d(id, itype) return NS.Situation.Classify(inputs({ inInstance = true, instanceType = itype, difficultyID = id })).difficulty end
    assertEqual(d(1, "party"), "normal")
    assertEqual(d(2, "party"), "heroic")
    assertEqual(d(23, "party"), "mythic")
    assertEqual(d(8, "party"), "keystone")
    assertEqual(d(205, "party"), "follower")
    assertEqual(d(17, "raid"), "lfr")
    assertEqual(d(14, "raid"), "normal")
    assertEqual(d(15, "raid"), "heroic")
    assertEqual(d(16, "raid"), "mythic")
    assertEqual(d(220, "raid"), "story")
    assertNil(d(999, "party"))
end)

test("situation: key level and map only inside M+", function()
    local NS = T.newAddon()
    local s = NS.Situation.Classify(inputs({ inInstance = true, instanceType = "party", difficultyID = 8, keyLevel = 14, challengeMapID = 556 }))
    assertEqual(s.keyLevel, 14)
    assertEqual(s.challengeMapID, 556)
    local h = NS.Situation.Classify(inputs({ inInstance = true, instanceType = "party", difficultyID = 2, keyLevel = 14 }))
    assertNil(h.keyLevel)
end)

test("situation: signature ignores combat and lockdown", function()
    local NS = T.newAddon()
    local a = NS.Situation.Classify(inputs({ inGroup = true }))
    local b = NS.Situation.Classify(inputs({ inGroup = true, inCombat = true }))
    b.lockdown = { chat = true }
    assertEqual(NS.Situation.Signature(a), NS.Situation.Signature(b))
    local c = NS.Situation.Classify(inputs({ inGroup = true, inRaid = true }))
    assertTrue(NS.Situation.Signature(a) ~= NS.Situation.Signature(c))
end)

test("situation: RefreshNow sends SITUATION_CHANGED only when the signature moves", function()
    local NS = T.enableAddon()
    local sent = {}
    NS.addon.SendMessage = function(_, name, snap) sent[#sent + 1] = { name, snap } end
    NS.Situation.ReadInputs = function() return inputs({ inGroup = true }) end
    assertTrue(NS.Situation.RefreshNow("test"))
    assertFalse(NS.Situation.RefreshNow("test"))
    NS.Situation.ReadInputs = function() return inputs({ inGroup = true, inRaid = true }) end
    assertTrue(NS.Situation.RefreshNow("test"))
    assertEqual(#sent, 2)
    assertEqual(sent[1][1], NS.MSG.SITUATION_CHANGED)
    assertEqual(sent[2][2].group, "raid")
end)

test("situation: Refresh coalesces a burst into one read", function()
    local NS = T.enableAddon()
    local scheduled, reads = {}, 0
    NS.addon.ScheduleTimer = function(_, fn) scheduled[#scheduled + 1] = fn return #scheduled end
    NS.Situation.ReadInputs = function() reads = reads + 1 return inputs() end
    NS.Situation.Refresh("PLAYER_ENTERING_WORLD")
    NS.Situation.Refresh("ZONE_CHANGED_NEW_AREA")
    NS.Situation.Refresh("GROUP_ROSTER_UPDATE")
    assertEqual(#scheduled, 1)
    scheduled[1]()
    assertEqual(reads, 1)
end)

test("situation: ReadInputs survives a loading screen", function()
    local NS, env = T.enableAddon()
    env.IsInInstance = function() return nil end
    env.GetInstanceInfo = function() return nil end
    local s = NS.Situation.Classify(NS.Situation.ReadInputs())
    assertEqual(s.content, "openWorld")
end)

test("situation: stand-down cancels a pending coalesced refresh", function()
    local NS = T.enableAddon()
    local canceled, sent = {}, 0
    NS.addon.ScheduleTimer = function() return "handle-1" end
    NS.addon.CancelTimer = function(_, h) canceled[#canceled + 1] = h end
    NS.addon.SendMessage = function() sent = sent + 1 end
    NS.Situation.Refresh("GROUP_ROSTER_UPDATE")
    NS.StandDown()
    assertEqual(#canceled, 1)
    assertEqual(canceled[1], "handle-1")
    assertNil(NS.State.situationTimer)
    assertEqual(sent, 0)
end)
