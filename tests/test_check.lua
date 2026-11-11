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
    env.SLASH_TARGET_MARKER1 = nil
    lines = NS.SlashVerbs.CheckLines(mark)
    assertEqual(#lines, 1)
    assertEqual(lines[1], mark .. " -> not sent here (noMarker)")
end)
