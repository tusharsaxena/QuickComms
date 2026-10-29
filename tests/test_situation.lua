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
    -- Only this module's handle: the stand-down also cancels the first-run skin picker's login
    -- timer (core/SkinSetup.lua), scheduled by OnEnable before the stub above.
    NS.addon.CancelTimer = function(_, h) if h == "handle-1" then canceled[#canceled + 1] = h end end
    NS.addon.SendMessage = function() sent = sent + 1 end
    NS.Situation.Refresh("GROUP_ROSTER_UPDATE")
    NS.StandDown()
    assertEqual(#canceled, 1)
    assertEqual(canceled[1], "handle-1")
    assertNil(NS.State.situationTimer)
    assertEqual(sent, 0)
end)

test("situation: snapshot.lockdown mirrors Restrictions.ActiveSet", function()
    local NS = T.enableAddon()
    NS.Restrictions.ActiveSet = function() return { encounter = true, chatLockdown = true } end
    NS.Situation.ReadInputs = function() return {} end
    NS.Situation.RefreshNow("test")
    local s = NS.Situation.Current()
    assertTrue(s.lockdown.encounter)
    assertTrue(s.lockdown.chat)
    assertFalse(s.lockdown.pvpMatch)
end)

-- Counts every SITUATION_CHANGED while letting each message through, so the bus still runs.
local function countSituation(NS)
    local real, n = NS.addon.SendMessage, { 0 }
    NS.addon.SendMessage = function(self, name, ...)
        if name == NS.MSG.SITUATION_CHANGED then n[1] = n[1] + 1 end
        return real(self, name, ...)
    end
    return n
end

test("situation: [final 1] a restriction or combat edge after the refresh reaches Current()", function()
    local NS, m = T.enableAddon()
    local RT, RS = m.Enum.AddOnRestrictionType, m.Enum.AddOnRestrictionState
    m.inCombat = false
    NS.Situation.RefreshNow("test")
    local sent = countSituation(NS)
    local sig = NS.State.situationSignature
    m.__fire("ADDON_RESTRICTION_STATE_CHANGED", RT.Encounter, RS.Activating)
    m.__fire("PLAYER_REGEN_DISABLED")
    local s = NS.Situation.Current()
    -- red under: drop Situation's RESTRICTION_CHANGED receiver
    assertTrue(s.lockdown.encounter, "the encounter merged into the snapshot")
    assertTrue(s.inCombat, "the combat edge merged into the snapshot")
    assertEqual(sent[1], 0, "lockdown and combat never send SITUATION_CHANGED")
    assertEqual(NS.State.situationSignature, sig, "the signature did not move")
    m.__fire("PLAYER_REGEN_ENABLED")
    m.__fire("ADDON_RESTRICTION_STATE_CHANGED", RT.Encounter, RS.Inactive)
    s = NS.Situation.Current()
    assertFalse(s.lockdown.encounter)
    assertFalse(s.inCombat)
    assertEqual(sent[1], 0)
end)

test("situation: [final 1] Current() before the first refresh reads the combat edge", function()
    local NS, m = T.enableAddon()
    m.inCombat = false
    NS.State.situation = nil
    NS.Restrictions.OnCombatEdge(true)
    NS.State.situation = nil
    assertTrue(NS.Situation.Current().inCombat, "the edge wins over the lagging flag")
end)

test("situation: [final 1] stood down, the receiver is down; stood up, it hears again", function()
    local NS, m = T.enableAddon()
    local RT, RS = m.Enum.AddOnRestrictionType, m.Enum.AddOnRestrictionState
    NS.addon:OnSlashCommand("disable")
    NS.State.situation = NS.Situation.Classify({})
    NS.addon:SendMessage(NS.MSG.RESTRICTION_CHANGED, "encounter", false)
    m.restrictionStates[RT.Encounter] = RS.Active
    NS.addon:SendMessage(NS.MSG.RESTRICTION_CHANGED, "encounter", false)
    assertFalse(NS.State.situation.lockdown.encounter == true, "nothing heard while stood down")
    NS.addon:OnSlashCommand("enable")
    assertTrue(NS.Situation.Current().lockdown.encounter, "the stand-up merged it")
    m.restrictionStates[RT.Encounter] = nil
    NS.Restrictions.Refresh("test")
    assertFalse(NS.Situation.Current().lockdown.encounter, "heard again after the stand-up")
end)

test("situation: [final 1] on the degraded bus the module takes its own receiver down and up", function()
    local NS, m = T.enableAddon{ skip = T.loadAddon.libFiles }
    assertFalse(NS.Bus.tracked)
    local RT, RS = m.Enum.AddOnRestrictionType, m.Enum.AddOnRestrictionState
    NS.Situation.RefreshNow("test")
    NS.addon:OnSlashCommand("disable")
    NS.State.situation = NS.Situation.Classify({})
    m.restrictionStates[RT.Encounter] = RS.Active
    NS.addon:SendMessage(NS.MSG.RESTRICTION_CHANGED, "encounter", false)
    assertFalse(NS.State.situation.lockdown.encounter == true, "unregistered by the stand-down")
    NS.addon:OnSlashCommand("enable")
    m.restrictionStates[RT.Encounter] = nil
    NS.addon:SendMessage(NS.MSG.RESTRICTION_CHANGED, nil, true)
    assertFalse(NS.Situation.Current().lockdown.encounter, "registered again by the stand-up")
end)

test("situation: [final 1b] both combat edges reach Current() even under the Combat restriction type", function()
    local NS, m = T.enableAddon()
    local RT, RS = m.Enum.AddOnRestrictionType, m.Enum.AddOnRestrictionState
    m.inCombat = false
    NS.Situation.RefreshNow("test")
    m.__fire("ADDON_RESTRICTION_STATE_CHANGED", RT.Combat, RS.Activating)
    assertFalse(NS.Situation.Current().inCombat, "the type alone is not the edge")
    m.__fire("PLAYER_REGEN_DISABLED")
    -- red under: an announce signature built from the active set alone
    assertTrue(NS.Situation.Current().inCombat, "REGEN_DISABLED under the Combat type")
    m.__fire("PLAYER_REGEN_ENABLED")
    assertFalse(NS.Situation.Current().inCombat, "REGEN_ENABLED under the Combat type")
end)

test("situation: [arena] an arena snapshot carries its instanceID, which the arena row matches", function()
    local NS = T.newAddon()
    local s = NS.Situation.Classify(inputs({ inInstance = true, instanceType = "arena", instanceID = 1505, inGroup = true }))
    assertEqual(s.content, "arena")
    assertEqual(s.instanceID, 1505)
    assertTrue((NS.Resolver.Matches({ arena = { [1505] = true } }, s)))
end)

test("situation: [QF-04] the snapshot reads General from channel 1 and a join or leave moves the signature", function()
    local NS, m = T.enableAddon()
    m.generalChannel = 1
    -- red under: ReadInputs or Classify without general
    assertTrue(NS.Situation.Classify(NS.Situation.ReadInputs()).general)
    m.generalChannel = nil
    assertFalse(NS.Situation.Classify(NS.Situation.ReadInputs()).general)
    local joined = NS.Situation.Classify(inputs({ general = true }))
    local left = NS.Situation.Classify(inputs())
    -- red under: general not in SIGNATURE_FIELDS
    assertTrue(NS.Situation.Signature(joined) ~= NS.Situation.Signature(left))
end)

test("situation: [F-007] a channel 1 that is not the zone's General leaves general off", function()
    local NS, m = T.enableAddon()
    m.generalChannel = 3
    -- red under: GeneralJoined matching channel 1 by number or by name, not the client's General id
    assertFalse(NS.Situation.Classify(NS.Situation.ReadInputs()).general)
    NS.Situation.RefreshNow("test")
    local c = { name = "Thanks", text = "Thanks!", channel = "general" }
    local line = NS.Bake.Bake(c, NS.Situation.Current())
    assertTrue(line:find("^/s ") ~= nil, "falls back to Say, as when General is not joined: " .. tostring(line))
end)

test("situation: [QF-04] CHANNEL_UI_UPDATE and CHAT_MSG_CHANNEL_NOTICE are situation events", function()
    local NS = T.newAddon()
    local declared = {}
    for _, row in ipairs(NS.FEATURE_EVENTS) do declared[row[1]] = row[2] end
    assertEqual(declared.CHANNEL_UI_UPDATE, "OnSituationEvent")
    assertEqual(declared.CHAT_MSG_CHANNEL_NOTICE, "OnSituationEvent")
end)

test("situation: [QF-04] a channel notice after the automatic join refreshes the snapshot to General", function()
    local NS, m = T.enableAddon()
    m.generalChannel = nil
    NS.Situation.RefreshNow("test")
    assertFalse(NS.Situation.Current().general)
    m.generalChannel = 1
    -- red under: no CHAT_MSG_CHANNEL_NOTICE in EVENTS (no CHANNEL_UI_UPDATE fired here)
    m.__fire("CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", "", "", "1. General - Dornogal", "", "", 1, 1, "General")
    m.__fireTimers()
    assertTrue(NS.Situation.Current().general)
end)
