-- tests/test_check.lua — /qc check <id> (spec §14, P8): prints the baked line, never sends.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function boot()
    local NS, env = T.enableAddon()
    NS.Situation.Current = function()
        return { content = "mythicPlus", group = "party", instanceGroup = false, lockdown = { chat = true } }
    end
    return NS, env
end

test("check: a seeded callout prints its line and channel", function()
    local NS = boot()
    local lust = T.seeded(NS, "bi.mplus.lust")
    local lines = NS.SlashVerbs.CheckLines(lust)
    assertEqual(lines[1], lust .. " -> /p Lust on this pack")
    assertTrue(lines[2]:find("party", 1, true) ~= nil)
end)

test("check: a refused callout prints the reason", function()
    local NS = boot()
    local id = NS.Library.CreateCallout({ name = "Bad", text = "/run x", channel = "party" })
    local lines = NS.SlashVerbs.CheckLines(id)
    assertTrue(lines[1]:find("startsWithSlash", 1, true) ~= nil)
end)

test("check: an unknown id says so", function()
    local NS = boot()
    local lines = NS.SlashVerbs.CheckLines("c999")
    assertEqual(#lines, 1)
    assertTrue(lines[1]:find("c999", 1, true) ~= nil)
end)

test("check: never calls SendChatMessage", function()
    local NS, env = boot()
    local called = false
    env.C_ChatInfo = env.C_ChatInfo or {}
    env.C_ChatInfo.SendChatMessage = function() called = true end
    env.SendChatMessage = function() called = true end
    NS.SlashVerbs.Check(T.seeded(NS, "bi.mplus.lust"))
    assertTrue(not called, "check must not send")
end)

test("check: [final minor 4] unknown and send-time tokens are listed", function()
    local NS = boot()
    local id = NS.Library.CreateCallout({ name = "T", text = "{me} on {bogus}", channel = "party" })
    local text = table.concat(NS.SlashVerbs.CheckLines(id), "\n")
    -- red under: a CheckLines that ignores info.missing / info.unknown
    assertTrue(text:find("baked at send time: {me}", 1, true) ~= nil, text)
    assertTrue(text:find("unknown tokens: {bogus}", 1, true) ~= nil, text)
end)

test("check: [final minor 4] solo with soloFallback=self says it would print locally", function()
    local NS = T.enableAddon()
    NS.Situation.Current = function() return { content = "openWorld", group = "solo", lockdown = {} } end
    NS.SchemaRuntime.Set("behavior.soloFallback", "self")
    local lines = NS.SlashVerbs.CheckLines(T.seeded(NS, "bi.mplus.lust"))
    assertTrue(lines[1]:find("would print locally", 1, true) ~= nil, lines[1])
end)

-- ── a ping or a marker action (CA-M1-12) ───────────────────────────────────────────────────────

test("check: [CA-M1-12] a ping-only or marker-only callout prints its line and bytes", function()
    local NS, env = boot()
    local ping = NS.Library.CreateCallout({ name = "Ping", text = "", channel = "gameEmote", ping = "attack" })
    local lines = NS.SlashVerbs.CheckLines(ping)
    -- red under: CheckLines baking only the Line (a ping-only callout reads "not sent here (noEmote)")
    assertEqual(lines[1], ping .. " -> /ping [@target,exists] 1")
    assertEqual(lines[2], "  action: ping, 24 of 255 bytes")
    local mark = NS.Library.CreateCallout({ name = "Skull", text = "", channel = "gameEmote", marker = 8 })
    lines = NS.SlashVerbs.CheckLines(mark)
    assertEqual(lines[1], mark .. " -> /tm [@target,exists] !8")
    assertEqual(lines[2], "  action: marker, 23 of 255 bytes")
    -- red under: a whitespace-only text read as a Line ahead of the ping ("not sent here (empty)")
    local blank = NS.Library.CreateCallout({ name = "Blank", text = "   ", channel = "party", ping = "attack" })
    lines = NS.SlashVerbs.CheckLines(blank)
    assertEqual(lines[1], blank .. " -> /ping [@target,exists] 1")
    env.SLASH_TARGET_MARKER1 = nil
    lines = NS.SlashVerbs.CheckLines(mark)
    assertEqual(#lines, 1)
    assertEqual(lines[1], mark .. " -> not sent here (noMarker)")
end)

-- ── one row per action (CA-M2-10, combined actions §7) ─────────────────────────────────────────

test("check: [CA-M2-10] a combined callout prints each action with its bytes, then the macro total", function()
    local NS, env = boot()
    env.MAXEMOTEINDEX, env.EMOTE73_TOKEN, env.EMOTE73_CMD1 = 80, "POINT", "/point"
    NS.Emotes.Reset()
    local id = NS.Library.CreateCallout({ name = "Kick", text = "Kick on me", channel = "party", emote = "POINT",
        ping = "attack", marker = 8 })
    local _, _, info = NS.Bake.BakeActions(NS.Library.Callout(id), NS.Situation.Current())
    local lines = NS.SlashVerbs.CheckLines(id)
    -- red under: CheckLines printing the Line alone
    assertEqual(lines[1], id .. " -> 4 actions")
    assertEqual(lines[2], "  line: /p Kick on me, 13 of 255 bytes")
    assertEqual(lines[3], "  channel: party")
    assertEqual(lines[4], "  emote: /point, 6 of 255 bytes")
    assertEqual(lines[5], "  ping: /ping [@target,exists] 1, 24 of 255 bytes")
    assertEqual(lines[6], "  marker: /tm [@target,exists] !8, 23 of 255 bytes")
    assertEqual(lines[7], ("  macro: %d of 255 bytes"):format(info.total))
    assertEqual(info.total, 13 + 6 + 24 + 23 + 3)
end)

test("check: [CA-M2-10] a skipped action says why; a locked Line names its lock", function()
    local NS = boot()
    local id = NS.Library.CreateCallout({ name = "Long", text = ("x"):rep(250), channel = "party", ping = "attack" })
    local lines = NS.SlashVerbs.CheckLines(id)
    assertEqual(lines[1], id .. " -> 2 actions")
    assertEqual(lines[2], "  line: not sent here (tooLong)")
    assertEqual(lines[3], "  ping: /ping [@target,exists] 1, 24 of 255 bytes")
    assertEqual(lines[4], "  macro: 24 of 255 bytes")
    id = NS.Library.CreateCallout({ name = "Stack", text = "Go", channel = "raid", ping = "attack" })
    lines = NS.SlashVerbs.CheckLines(id)
    assertEqual(lines[2], "  line: /raid Go, 8 of 255 bytes")
    assertEqual(lines[3], "  channel: raid")
    -- red under: a combined callout's Line printed without its lock
    assertEqual(lines[4], "  locked: notInRaid")
end)
