-- tests/test_restrictions.lua — modules/Restrictions.lua (spec §8.4 and §9): the answers
-- (ActiveReason, CanSendChat, InCombat) from the restriction event's hints, the client's
-- restriction and chat-lockdown answers and the combat edges; RESTRICTION_CHANGED; the secret
-- payloads; and the stand-down.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local EVENT = "ADDON_RESTRICTION_STATE_CHANGED"

-- An enabled instance with a receiver recording every RESTRICTION_CHANGED as { reason, canSend }.
local function live()
    local NS, _, m = T.enableAddon()
    local heard = {}
    local rx = NS.Bus:NewTarget()
    rx:RegisterMessage(NS.MSG.RESTRICTION_CHANGED, function(_, reason, canSend)
        heard[#heard + 1] = { reason, canSend }
    end)
    return NS, m, heard, m.Enum.AddOnRestrictionType, m.Enum.AddOnRestrictionState
end

-- The kit's secret simulator, installed on the client so the guards see it.
local function installSecrets(m)
    m.issecretvalue = T.isSecret
    m.canaccessvalue = function(v) return not T.isSecret(v) end
end

local function answers(R)
    return ("%s %s %s"):format(tostring(R.ActiveReason()), tostring(R.CanSendChat()), tostring(R.InCombat()))
end

test("restrictions: nothing restricted, everything allowed and nothing announced", function()
    local NS, m, heard = live()
    assertEqual(answers(NS.Restrictions), "nil true false")
    assertTrue(m.__fire(EVENT, 4, 0) > 0, "the event is registered")
    assertEqual(#heard, 0)
end)

test("restrictions: an encounter stops chat and is the reason; its lift is announced", function()
    local NS, m, heard, RT, RS = live()
    m.__fire(EVENT, RT.Encounter, RS.Activating)
    assertEqual(answers(NS.Restrictions), "encounter false false", "Activating counts at once")
    assertEqual(#heard, 1)
    assertEqual(heard[1][1], "encounter"); assertFalse(heard[1][2])
    m.restrictionStates[RT.Encounter] = RS.Active
    m.__fire(EVENT, RT.Encounter, RS.Active)
    assertEqual(#heard, 1, "no change, no message")
    m.restrictionStates[RT.Encounter] = nil
    m.__fire(EVENT, RT.Encounter, RS.Inactive)
    assertEqual(answers(NS.Restrictions), "nil true false")
    assertEqual(#heard, 2)
    assertNil(heard[2][1]); assertTrue(heard[2][2], "the lift says chat may be sent")
end)

test("restrictions: a lift the client does not confirm yet keeps the restriction", function()
    local NS, m, _, RT, RS = live()
    m.restrictionStates[RT.Encounter] = RS.Active
    m.__fire(EVENT, RT.Encounter, RS.Inactive)
    assertFalse(NS.Restrictions.CanSendChat(), "the client still says Active")
    m.restrictionStates[RT.Encounter] = nil
    assertTrue(NS.Restrictions.CanSendChat(), "read live, so the next ask sees the lift")
end)

test("restrictions: the event's boolean payload is read too", function()
    local NS, m, heard, RT = live()
    m.__fire(EVENT, RT.ChallengeMode, true)
    assertEqual(NS.Restrictions.ActiveReason(), "challengeMode")
    m.__fire(EVENT, RT.ChallengeMode, false)
    assertNil(NS.Restrictions.ActiveReason())
    assertEqual(#heard, 2)
end)

test("restrictions: each type gives its reason; Map blocks nothing", function()
    local NS, m, _, RT, RS = live()
    local R = NS.Restrictions
    local CASES = {
        { "Encounter", "encounter false false" },
        { "ChallengeMode", "challengeMode false false" },
        { "PvPMatch", "pvpMatch false false" },
        { "Chat", "chat false false" },
        { "Combat", "combat true false" },
        { "Map", "nil true false" },
    }
    for _, c in ipairs(CASES) do
        m.restrictionStates = { [RT[c[1]]] = RS.Active }
        assertEqual(answers(R), c[2], c[1])
    end
    m.restrictionStates = { [RT.Map] = RS.Active }
    assertTrue(R.ActiveSet().map, "Map is tracked for the report")
end)

test("restrictions: the reason is the highest in priority", function()
    local NS, m, _, RT, RS = live()
    local R = NS.Restrictions
    m.restrictionStates = { [RT.Combat] = RS.Active, [RT.Chat] = RS.Active, [RT.Encounter] = RS.Active }
    assertEqual(R.ActiveReason(), "encounter")
    m.restrictionStates[RT.Encounter] = nil
    assertEqual(R.ActiveReason(), "chat")
    m.restrictionStates[RT.Chat] = nil
    m.chatLockdown = true
    assertEqual(R.ActiveReason(), "chatLockdown")
    m.chatLockdown = false
    assertEqual(R.ActiveReason(), "combat")
end)

test("restrictions: a type the client adds later is reported by name and blocks nothing", function()
    local NS, m, _, RT, RS = live()
    RT.Housing = 9
    m.restrictionStates[9] = RS.Active
    assertTrue(NS.Restrictions.ActiveSet().Housing)
    assertEqual(answers(NS.Restrictions), "nil true false")
end)

test("restrictions: the chat lockdown stops chat, a secret answer too", function()
    local NS, m = live()
    installSecrets(m)
    m.chatLockdown = true
    assertEqual(answers(NS.Restrictions), "chatLockdown false false")
    m.chatLockdown = T.secret(false)
    assertFalse(NS.Restrictions.CanSendChat(), "a secret lockdown reads as locked")
    m.chatLockdown = false
    assertTrue(NS.Restrictions.CanSendChat())
end)

test("restrictions: the combat edges set InCombat, ahead of the client's flag", function()
    local NS, m, heard = live()
    local R = NS.Restrictions
    m.inCombat = false
    assertTrue(m.__fire("PLAYER_REGEN_DISABLED") > 0)
    assertEqual(answers(R), "combat true true", "the edge wins over a lagging flag")
    assertEqual(#heard, 1)
    assertEqual(heard[1][1], "combat"); assertTrue(heard[1][2], "combat alone leaves chat open")
    m.inCombat = true
    m.__fire("PLAYER_REGEN_ENABLED")
    assertEqual(answers(R), "nil true false")
    assertEqual(#heard, 2)
end)

test("restrictions: before any edge, the client's combat flag decides", function()
    local NS, m = live()
    m.inCombat = true
    assertTrue(NS.Restrictions.InCombat())
    assertEqual(NS.Restrictions.ActiveReason(), "combat")
end)

test("restrictions: combat under an encounter announces the change of what is allowed", function()
    local NS, m, heard, RT, RS = live()
    m.__fire(EVENT, RT.Encounter, RS.Active)
    m.__fire("PLAYER_REGEN_DISABLED")
    -- red under: a signature of the top reason and canSendChat only
    assertEqual(#heard, 2, "the reason stays encounter, but the set gained combat")
    assertEqual(heard[2][1], "encounter")
    assertTrue(NS.Restrictions.InCombat())
    m.__fire("PLAYER_REGEN_ENABLED")
    assertEqual(#heard, 3)
end)

test("restrictions: a secret payload never raises; a secret state reads as active", function()
    local NS, m, heard, RT = live()
    installSecrets(m)
    m.__fire(EVENT, RT.Encounter, T.secret(0))
    assertEqual(NS.Restrictions.ActiveReason(), "encounter")
    m.__fire(EVENT, T.secret(RT.Chat), T.secret(2))
    assertEqual(NS.Restrictions.ActiveReason(), "encounter", "a secret type keys no hint")
    m.__fire(EVENT, nil, nil)
    assertEqual(#heard, 1)
end)

test("restrictions: a client without the restriction APIs restricts nothing but combat", function()
    local NS, m = live()
    m.C_RestrictedActions, m.Enum.AddOnRestrictionType = nil, nil
    m.C_ChatInfo = nil
    assertEqual(answers(NS.Restrictions), "nil true false")
    m.__fire("PLAYER_REGEN_DISABLED")
    assertEqual(NS.Restrictions.ActiveReason(), "combat")
end)

-- A lockdown held, announced through the restriction event, for the lift cases below.
local function lockedThenCleared(m, heard)
    m.chatLockdown = true
    m.__fire(EVENT, nil, nil)
    assertEqual(#heard, 1, "the lockdown is announced")
    m.chatLockdown = false
end

test("restrictions: ENCOUNTER_END re-reads a lockdown the client cleared after the last event", function()
    local NS, m, heard = live()
    lockedThenCleared(m, heard)
    -- red under: drop the ENCOUNTER_END row from modules/Restrictions.lua
    assertTrue(m.__fire("ENCOUNTER_END") > 0, "the event is registered")
    assertEqual(#heard, 2, "the lift no event reported is announced")
    assertNil(heard[2][1]); assertTrue(heard[2][2], "chat may be sent")
    assertTrue(NS.Restrictions.Snapshot().canSendChat)
end)

test("restrictions: CHALLENGE_MODE_COMPLETED re-reads, through Situation's row", function()
    local _, m, heard = live()
    lockedThenCleared(m, heard)
    -- red under: drop the CHALLENGE_MODE_COMPLETED forward in modules/Situation.lua's OnSituationEvent
    assertTrue(m.__fire("CHALLENGE_MODE_COMPLETED") > 0)
    assertEqual(#heard, 2, "the lift is announced")
    assertTrue(heard[2][2])
end)

test("restrictions: a lockdown that clears just after the encounter ends is announced by the late re-read", function()
    local _, m, heard = live()
    m.chatLockdown = true
    m.__fire(EVENT, nil, nil)
    m.__fire("ENCOUNTER_END")
    assertEqual(#heard, 1, "still locked at the event: nothing moved")
    m.chatLockdown = false
    m.__fire("ENCOUNTER_END")
    assertEqual(#heard, 2, "a second end reads now")
    m.chatLockdown = true
    m.__fire(EVENT, nil, nil)
    m.chatLockdown = false
    -- red under: drop the ScheduleTimer in R.RefreshAfterLift
    assertTrue(m.__fireTimers() >= 1, "one late re-read was pending")
    assertEqual(#heard, 4, "and it announced the lift")
    assertTrue(heard[4][2])
    assertEqual(m.__fireTimers(), 0, "one re-read per window, not one per end")
end)

test("restrictions: the late re-read is canceled by the stand-down", function()
    local NS, m = live()
    m.__fire("ENCOUNTER_END")
    assertTrue(NS.State.restrictionLiftTimer ~= nil, "the late re-read is armed")
    NS.addon:OnSlashCommand("disable")
    assertNil(NS.State.restrictionLiftTimer)
    -- red under: drop the CancelTimer from Restrictions' STAND_DOWN step
    assertEqual(#m.__timers(), 0, "nothing armed while stood down")
end)

test("restrictions: stood down, nothing is heard; the stand-up announces what is in effect", function()
    local NS, m, heard, RT, RS = live()
    m.__fire(EVENT, RT.Encounter, RS.Active)
    NS.addon:OnSlashCommand("disable")
    assertNil(NS.State.restrictionHints, "the stand-down drops the stale hints")
    assertNil(NS.State.restrictionSignature)
    assertEqual(m.__fire(EVENT, RT.Chat, RS.Active), 0, "the event is down")
    m.restrictionStates[RT.Chat] = RS.Active
    local before = #heard
    NS.addon:OnSlashCommand("enable")
    assertEqual(#heard, before + 1, "the replayed receiver heard the stand-up")
    assertEqual(heard[#heard][1], "chat")
end)

test("restrictions: [final 1] a lockdown lifting under a higher one is announced", function()
    local NS, m, heard, RT, RS = live()
    m.__fire(EVENT, RT.Encounter, RS.Active)
    m.__fire(EVENT, RT.ChallengeMode, RS.Active)
    assertEqual(#heard, 2, "challengeMode joined under encounter")
    m.__fire(EVENT, RT.ChallengeMode, RS.Inactive)
    assertEqual(#heard, 3, "and its lift is announced, though the reason stays encounter")
    assertEqual(heard[3][1], "encounter")
    assertFalse(NS.Restrictions.ActiveSet().challengeMode == true)
end)
