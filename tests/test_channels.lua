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
    for _, k in ipairs({ "say", "yell", "party", "raid", "instance", "raidWarning", "whisperTarget", "whisperFocus" }) do
        assertEqual((Ch.Resolve(k, snap())), k, k)
    end
    local c, reason = Ch.Resolve("guild", snap())
    assertNil(c) assertEqual(reason, "badChannel")
end)

test("channels: prefixes and chat types", function()
    local Ch = ch()
    assertEqual(Ch.Prefix("party"), "/p")
    assertEqual(Ch.Prefix("instance"), "/i")
    assertEqual(Ch.Prefix("raidWarning"), "/rw")
    assertEqual(Ch.Prefix("whisperTarget"), "/w %t")
    assertEqual(Ch.Prefix("whisperFocus"), "/w %f")
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
    assertNil(Ch.LockState("whisperTarget", snap({ lockdown = { encounter = true } })))
    assertEqual(Ch.SoftWarning("whisperTarget", snap({ lockdown = { chat = true } })), "whisperInstanceOnly")
end)
