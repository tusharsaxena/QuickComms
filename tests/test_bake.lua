-- tests/test_bake.lua — modules/Bake.lua (spec §8.3): one macro line, never a command, <= 255 bytes.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertNil, assertTrue = T.test, T.assertEqual, T.assertNil, T.assertTrue

local function bake() return T.newAddon().Bake end
local PARTY = { group = "party", instanceGroup = false, lockdown = {} }
local function callout(text, channel) return { name = "x", text = text, channel = channel or "smartGroup" } end

test("bake: a plain callout bakes to prefix + text", function()
    local line, reason, info = bake().Bake(callout("Lust on this pack {rt8}"), PARTY)
    assertEqual(line, "/p Lust on this pack {rt8}")
    assertNil(reason)
    assertEqual(info.concrete, "party")
end)

test("bake: [review 1] a leading slash is refused, even after whitespace", function()
    local B = bake()
    for _, t in ipairs({ "/run x()", "  /script y", "\t/dump 1", "\n/cast Fireball" }) do
        local line, reason = B.Bake(callout(t), PARTY)
        assertNil(line, t)
        assertEqual(reason, "startsWithSlash", t)
    end
end)

test("bake: [review 1] newlines and control characters flatten to one line", function()
    local line = bake().Bake(callout("hi\n/script y\r\nok\tthere"), PARTY)
    assertEqual(line, "/p hi /script y ok there")
    assertTrue(not line:find("\n"), "no newline")
end)

test("bake: pipes are escaped, spell links are not", function()
    local ctx = { spellLink = function() return "|cff71d5ff|Hspell:2825|h[Bloodlust]|h|r" end }
    local line = bake().Bake(callout("a|b {spell:2825}"), PARTY, { ctx = ctx })
    assertEqual(line, "/p a||b |cff71d5ff|Hspell:2825|h[Bloodlust]|h|r")
end)

test("bake: [review 2] the 255-byte boundary counts bytes and live tokens", function()
    local B = bake()
    local e = "\195\169"                                   -- é is two bytes
    local ok = callout(string.rep(e, 127) .. "x")          -- 255 bytes
    local over = callout(string.rep(e, 128))               -- 256 bytes
    assertTrue(B.Bake(ok, PARTY) ~= nil, "255 passes")
    local line, reason = B.Bake(over, PARTY)
    assertNil(line) assertEqual(reason, "tooLong")
    local live = callout(string.rep("a", 241) .. " {target}")  -- 244 bytes + 12 nominal = 256
    line, reason = B.Bake(live, PARTY)
    assertNil(line) assertEqual(reason, "tooLong")
    assertEqual(B.Length("abc", 2), 3 + 2 * 12)
end)

test("bake: empty or whitespace-only text is refused", function()
    local B = bake()
    for _, t in ipairs({ "", "   ", "\n\t" }) do
        local line, reason = B.Bake(callout(t), PARTY)
        assertNil(line) assertEqual(reason, "empty")
    end
    local line, reason = B.Bake(callout("{me}"), PARTY, { ctx = {} })
    assertNil(line) assertEqual(reason, "empty")
end)

test("bake: solo smart callouts follow the fallback", function()
    local B = bake()
    local SOLO = { group = "solo", lockdown = {} }
    local line, reason, info = B.Bake(callout("hi"), SOLO, { soloFallback = "self" })
    assertNil(line) assertEqual(reason, "solo") assertTrue(info.selfPrint)
    line = B.Bake(callout("hi"), SOLO, { soloFallback = "say" })
    assertEqual(line, "/s hi")
end)

test("bake: locks and warnings ride along without blocking the bake", function()
    local B = bake()
    local line, _, info = B.Bake(callout("inc", "say"), { group = "party", lockdown = { encounter = true } })
    assertEqual(line, "/s inc")
    assertEqual(info.lock, "lockdown")
    _, _, info = B.Bake(callout("hi", "whisperTarget"), { group = "party", lockdown = { chat = true } })
    assertEqual(info.warning, "whisperInstanceOnly")
end)

test("bake: unknown channel and non-table callout refuse", function()
    local B = bake()
    local line, reason = B.Bake(callout("hi", "guild"), PARTY)
    assertNil(line) assertEqual(reason, "badChannel")
    line, reason = B.Bake(nil, PARTY)
    assertNil(line) assertEqual(reason, "badCallout")
end)
