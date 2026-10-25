-- tests/test_channels.lua — modules/Channels.lua (spec §8.2, §8.4).

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertNil, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertNil, T.assertTrue, T.assertFalse

local function ch() return T.newAddon().Channels end
local function snap(over)
    local s = { group = "solo", instanceGroup = false, leader = false, assist = false, lockdown = {} }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
end

test("channels: smartGroup prefers instance, then raid, then party", function()
    local Ch = ch()
    assertEqual((Ch.Resolve("smartGroup", snap({ group = "raid", instanceGroup = true }))), "instance")
    assertEqual((Ch.Resolve("smartGroup", snap({ group = "raid" }))), "raid")
    assertEqual((Ch.Resolve("smartGroup", snap({ group = "party" }))), "party")
end)

test("channels: smartGroup solo follows the fallback", function()
    local Ch = ch()
    local c, reason, selfPrint = Ch.Resolve("smartGroup", snap(), "none")
    assertNil(c) assertEqual(reason, "solo") assertFalse(selfPrint)
    c, reason, selfPrint = Ch.Resolve("smartGroup", snap(), "self")
    assertNil(c) assertEqual(reason, "solo") assertTrue(selfPrint)
    assertEqual((Ch.Resolve("smartGroup", snap(), "say")), "say")
end)

test("channels: smartLead is RW for raid leader/assist and in a home party", function()
    local Ch = ch()
    assertEqual((Ch.Resolve("smartLead", snap({ group = "raid", leader = true }))), "raidWarning")
    assertEqual((Ch.Resolve("smartLead", snap({ group = "raid", assist = true }))), "raidWarning")
    assertEqual((Ch.Resolve("smartLead", snap({ group = "raid" }))), "raid")
    assertEqual((Ch.Resolve("smartLead", snap({ group = "party" }))), "raidWarning")
    assertEqual((Ch.Resolve("smartLead", snap({ group = "party", instanceGroup = true }))), "instance")
end)

test("channels: fixed kinds pass through; unknown kinds refuse", function()
    local Ch = ch()
    for _, k in ipairs({ "say", "yell", "party", "raid", "instance", "raidWarning" }) do
        assertEqual((Ch.Resolve(k, snap())), k, k)
    end
    local c, reason = Ch.Resolve("guild", snap())
    assertNil(c) assertEqual(reason, "badChannel")
end)

test("channels: the whisper kinds are not kinds (owner, issue #7)", function()
    local Ch = ch()
    assertEqual(Ch.IsKind("whisperTarget"), false)
    assertEqual(Ch.IsKind("whisperFocus"), false)
    local c, reason = Ch.Resolve("whisperTarget", snap())
    assertNil(c) assertEqual(reason, "badChannel")
    assertNil(Ch.Prefix("whisperFocus"))
end)

test("channels: prefixes and chat types", function()
    local Ch = ch()
    assertEqual(Ch.Prefix("party"), "/p")
    assertEqual(Ch.Prefix("instance"), "/i")
    assertEqual(Ch.Prefix("raidWarning"), "/rw")
    assertEqual(Ch.ChatType("instance"), "INSTANCE_CHAT")
    assertEqual(Ch.ChatType("raidWarning"), "RAID_WARNING")
end)

test("channels: the lock matrix", function()
    local Ch = ch()
    assertEqual(Ch.LockState("raid", snap({ group = "party" })), "notInRaid")
    assertNil(Ch.LockState("raid", snap({ group = "raid" })))
    assertEqual(Ch.LockState("raidWarning", snap({ group = "raid" })), "notLeader")
    assertNil(Ch.LockState("raidWarning", snap({ group = "party" })))
    assertEqual(Ch.LockState("raidWarning", snap()), "notInGroup")
    assertEqual(Ch.LockState("party", snap()), "notInGroup")
    assertEqual(Ch.LockState("instance", snap({ group = "party" })), "notInInstanceGroup")
    assertEqual(Ch.LockState("say", snap({ lockdown = { encounter = true } })), "lockdown")
    assertEqual(Ch.LockState("yell", snap({ lockdown = { pvpMatch = true } })), "lockdown")
    assertNil(Ch.LockState("say", snap({ lockdown = { challengeMode = true } })))
end)

test("channels: [phase 5] the lock matrix has no row for an unknown channel, and reads a missing snapshot as solo", function()
    local Ch = ch()
    assertNil(Ch.LockState("guild", snap({ group = "raid" })))
    assertNil(Ch.LockState(nil, nil))
    assertEqual(Ch.LockState("party", nil), "notInGroup")
    assertNil(Ch.LockState("say", nil), "no lockdown table is no lockdown")
end)

-- ── General (/1), QF-04 (2026-10-23 preview follow-ups, D4b) ─────────────────────────────────

test("channels: [QF-04] general resolves to General when channel 1 is joined, else to Say", function()
    local Ch = ch()
    -- red under: no general kind (Resolve answers badChannel)
    assertTrue(Ch.IsKind("general"))
    assertEqual((Ch.Resolve("general", snap({ general = true }))), "general")
    local c, reason, selfPrint = Ch.Resolve("general", snap(), "none")
    assertEqual(c, "say", "not joined: the Say fallback, whatever the solo fallback")
    assertNil(reason) assertFalse(selfPrint)
    assertEqual((Ch.Resolve("general", snap({ general = false, group = "party" }))), "say")
    assertEqual(Ch.KINDS[#Ch.KINDS], "general", "listed after yell")
end)

test("channels: [QF-04] general's prefix, chat type, color type and locks are Say's", function()
    local Ch = ch()
    assertEqual(Ch.Prefix("general"), "/1")
    assertEqual(Ch.ChatType("general"), "CHANNEL")
    -- red under: the color asked by ChatType ("CHANNEL" has no color of its own)
    assertEqual(Ch.ColorType("general"), "CHANNEL1")
    assertEqual(Ch.ColorType("party"), "PARTY")
    assertNil(Ch.ColorType("guild"))
    assertEqual(Ch.LockState("general", snap({ lockdown = { encounter = true } })), "lockdown")
    assertEqual(Ch.LockState("general", snap({ lockdown = { pvpMatch = true } })), "lockdown")
    assertNil(Ch.LockState("general", snap({ lockdown = { challengeMode = true } })))
end)

test("channels: [QF-04] a general callout bakes /1 with channel 1 joined and /s without", function()
    local NS = T.newAddon()
    local c = { name = "Thanks", text = "Thanks!", channel = "general" }
    local line, reason, info = NS.Bake.Bake(c, snap({ general = true }))
    assertEqual(line, "/1 Thanks!")
    assertNil(reason)
    assertEqual(info.concrete, "general")
    line = NS.Bake.Bake(c, snap())
    assertEqual(line, "/s Thanks!")
end)

test("channels: [QF-04] the channel row offers General with its label; the seam accepts it", function()
    local NS = T.bootAddon()
    local found
    for _, v in ipairs(NS.SchemaRuntime.FindRow("callout.channel").values) do
        if v.value == "general" then found = v.text end
    end
    -- red under: no CHANNEL_LABEL.general (the row shows the raw id)
    assertEqual(found, "General (/1; Say when not joined)")
    local cid = NS.Library.CreateCallout({ name = "Hi", text = "Hi", channel = "say" })
    assertTrue((NS.SchemaRuntime.Set("callout.channel", "general", cid)))
    assertEqual(NS.db.profile.callouts[cid].channel, "general")
end)

test("channels: [QF-04] a Groups row names General in channel 1's color", function()
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return { general = true } end
    NS.Situation.RefreshNow("test")
    local P = dofile("tests/page_helpers.lua")(NS, m)
    P.show("Groups")
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.Library.CreateCalloutIn(gid, { name = "Wave", text = "o/", channel = "general" })
    NS.addon.Settings.Editors.Select("group", gid)
    local want = "|cffffd100Wave|r  |cffffbfbfGeneral|r  |cffb3b3b3o/|r"
    local found
    for _, label in ipairs(P.all(P.tab("groups", "callouts"), "Label")) do
        if label.text == want then found = true end
    end
    -- red under: no SHORT_CHANNEL.general, or the row's color asked by ChatType
    assertTrue(found, "the General row")
end)
