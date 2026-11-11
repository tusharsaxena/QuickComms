-- tests/test_bake.lua — modules/Bake.lua (spec §8.3; combined actions §3): one macro line per action,
-- never a command, <= 255 bytes each, and never a newline from data: only code joins the action lines.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertNil, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertNil, T.assertTrue, T.assertFalse

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
    for _, t in ipairs({ "/run x()", "  /script y", "\t/dump 1", "\n/cast Fireball", "\1/run x" }) do
        local line, reason = B.Bake(callout(t), PARTY)
        assertNil(line, t)
        assertEqual(reason, "startsWithSlash", t)
    end
end)

test("bake: [review 1] newlines and control characters in data flatten: the Line is one line", function()
    local line = bake().Bake(callout("hi\n/script y\r\nok\tthere"), PARTY)
    assertEqual(line, "/p hi /script y ok there")
    assertTrue(not line:find("\n"), "no newline")
end)

test("bake: pipes are escaped, spell links are not", function()
    local ctx = { spellLink = function() return "|cff71d5ff|Hspell:2825|h[Bloodlust]|h|r" end }
    local line = bake().Bake(callout("a|b {spell:2825}"), PARTY, { ctx = ctx })
    assertEqual(line, "/p a||b |cff71d5ff|Hspell:2825|h[Bloodlust]|h|r")
end)

test("bake: [final minor 5] the 255-byte boundary counts the whole line: prefix, space, text, live tokens", function()
    local B = bake()
    local e = "\195\169"                                   -- é is two bytes
    local ok = callout(string.rep(e, 126))                 -- "/p " + 252 bytes = 255
    local over = callout(string.rep(e, 126) .. "x")        -- "/p " + 253 bytes = 256
    local line, _, info = B.Bake(ok, PARTY)
    assertTrue(line ~= nil, "255 passes")
    assertEqual(#line, 255)
    assertEqual(info.length, 255)
    -- red under: a check that counts the text alone
    local reason
    line, reason = B.Bake(over, PARTY)
    assertNil(line) assertEqual(reason, "tooLong")
    local liveOk = callout(string.rep("a", 237) .. " {target}")    -- "/p " + 240 bytes + 12 nominal = 255
    local liveOver = callout(string.rep("a", 238) .. " {target}")  -- 256
    assertTrue(B.Bake(liveOk, PARTY) ~= nil, "255 with a live token passes")
    line, reason = B.Bake(liveOver, PARTY)
    assertNil(line) assertEqual(reason, "tooLong")
    local rw = { group = "raid", leader = true, instanceGroup = false, lockdown = {} }
    assertTrue(B.Bake(callout(string.rep("a", 251), "raidWarning"), rw) ~= nil, "/rw + 251 = 255")
    assertNil((B.Bake(callout(string.rep("a", 252), "raidWarning"), rw)), "/rw + 252 = 256")
    assertEqual(B.Length("abc", 2), 3 + 2 * 12)
    assertEqual(B.Length("abc", 0, "/p"), 2 + 1 + 3)
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

test("bake: the lock rides along without blocking the bake", function()
    local B = bake()
    local line, _, info = B.Bake(callout("inc", "say"), { group = "party", lockdown = { encounter = true } })
    assertEqual(line, "/s inc")
    assertEqual(info.lock, "lockdown")
end)

test("bake: unknown channel and non-table callout refuse", function()
    local B = bake()
    local line, reason = B.Bake(callout("hi", "guild"), PARTY)
    assertNil(line) assertEqual(reason, "badChannel")
    line, reason = B.Bake(nil, PARTY)
    assertNil(line) assertEqual(reason, "badCallout")
end)

test("bake: baked token values are sanitized; spell links are not", function()
    local ctx = { me = "a\0b\1c\127d\ne|Hitem:1|h[x]|h",
        spellLink = function() return "|cff71d5ff|Hspell:2825|h[Bloodlust]|h|r" end }
    local line = bake().Bake(callout("{me} {spell:2825}"), PARTY, { ctx = ctx })
    assertEqual(line, "/p a b c d e||Hitem:1||h[x]||h |cff71d5ff|Hspell:2825|h[Bloodlust]|h|r")
    assertTrue(not line:find("%c"), "no control byte")
end)

test("bake: a typed %t counts as live", function()
    local line, reason = bake().Bake(callout(string.rep("a", 241) .. " %t"), PARTY)
    assertNil(line) assertEqual(reason, "tooLong")
end)

test("bake: [phase 5] CleanText is the sanitizer short of the escape; Sanitize is CleanText, then the escape", function()
    local B = bake()
    assertEqual(B.CleanText("  a|b\n c  "), "a|b c")
    assertEqual(select(2, B.CleanText("\t/run x")), "startsWithSlash")
    assertEqual(select(2, B.CleanText("  ")), "empty")
    assertEqual(select(2, B.CleanText(42)), "empty")
    assertEqual(B.Sanitize("  a|b\n c  "), "a||b c")
end)

-- ── B.BakeActions (CA-M1-7, combined actions §3): one line per set action, joined by code ──────

local function actions(plantEmotes)
    local NS, env, m = T.newAddon()
    if plantEmotes ~= false then
        env.MAXEMOTEINDEX = 80
        env.EMOTE73_TOKEN, env.EMOTE73_CMD1 = "POINT", "/point"
        NS.Emotes.Reset()
    end
    return NS.Bake, m
end
local function none(over)
    local c = { name = "x", text = "", channel = "gameEmote", emote = false, ping = false, marker = false }
    for k, v in pairs(over or {}) do c[k] = v end
    return c
end

test("bake: [CA-M1-7] BakeActions bakes a Line-only callout to today's Bake line", function()
    local B = actions()
    local c = callout("Lust on this pack {rt8}")
    -- red under: no B.BakeActions
    local macro, reason, info = B.BakeActions(c, PARTY)
    local line, _, linfo = B.Bake(c, PARTY)
    assertEqual(macro, line)
    assertNil(reason)
    assertEqual(#info.actions, 1) assertEqual(#info.baked, 1)
    local a = info.actions[1]
    assertEqual(a.kind, "line") assertEqual(a.line, line) assertNil(a.reason)
    assertEqual(a.concrete, "party") assertEqual(a.chatType, "PARTY")
    assertEqual(a.length, linfo.length) assertEqual(info.total, linfo.length)
    assertEqual(a.lock, linfo.lock)
end)

test("bake: [CA-M1-7] a Line that does not bake keeps today's reason, and the macro is nil", function()
    local B = actions()
    local macro, reason, info = B.BakeActions(callout("/run x()"), PARTY)
    assertNil(macro) assertEqual(reason, "startsWithSlash")
    assertEqual(#info.actions, 1) assertEqual(#info.baked, 0)
    assertEqual(info.actions[1].reason, "startsWithSlash")
    local SOLO = { group = "solo", lockdown = {} }
    macro, reason, info = B.BakeActions(callout("hi"), SOLO, { soloFallback = "self" })
    assertNil(macro) assertEqual(reason, "solo") assertTrue(info.actions[1].selfPrint)
end)

test("bake: [CA-M1-R1] HasLine is the Library's rule: whitespace or control-only text is no Line", function()
    local B = actions()
    assertFalse(B.HasLine({ text = "  ", channel = "party" }))
    assertFalse(B.HasLine({ text = "\t\n", channel = "party" }))
    assertFalse(B.HasLine({ text = "go", channel = "gameEmote" }))
    assertTrue(B.HasLine({ text = "go", channel = "party" }))
    assertTrue(B.HasLine({ text = "/run x()", channel = "party" }), "a slash line is a Line its bake refuses")
    -- red under: Bake's hasLine reading `text ~= ""` (a phantom Line ahead of the ping)
    local macro, reason, info = B.BakeActions({ name = "x", text = "   ", channel = "party", ping = "attack" }, PARTY)
    assertEqual(macro, "/ping [@target,exists] 1") assertNil(reason)
    assertEqual(#info.actions, 1) assertEqual(info.actions[1].kind, "ping")
end)

test("bake: [CA-M1-7] the emote line is the client's command, on the TEXT_EMOTE chat type and the gameEmote lock", function()
    local B = actions()
    local macro, reason, info = B.BakeActions(none{ emote = "POINT" }, { group = "party", lockdown = { encounter = true } })
    assertEqual(macro, "/point") assertNil(reason)
    local a = info.baked[1]
    assertEqual(a.kind, "emote") assertEqual(a.chatType, "TEXT_EMOTE")
    assertEqual(a.lock, "lockdown") assertEqual(a.length, #"/point")
    -- an emote this client lacks drops only that action
    macro, reason, info = B.BakeActions(none{ emote = "FROMRETAIL" }, PARTY)
    assertNil(macro) assertEqual(reason, "unknownEmote") assertEqual(info.actions[1].reason, "unknownEmote")
end)

test("bake: [CA-M1-7] a ping bakes /ping [@target,exists] with its numeric keyword, no chat type and no lock", function()
    local B = actions()
    local want = { attack = "1", warning = "2", onmyway = "3", assist = "4" }
    for ping, n in pairs(want) do
        local macro, reason, info = B.BakeActions(none{ ping = ping }, { group = "party", lockdown = { encounter = true } })
        assertEqual(macro, "/ping [@target,exists] " .. n, ping) assertNil(reason)
        local a = info.baked[1]
        assertEqual(a.kind, "ping") assertNil(a.chatType) assertNil(a.lock)
        assertEqual(a.length, #macro) assertEqual(info.total, #macro)
    end
end)

test("bake: [CA-M1-7] a marker bakes /tm [@target,exists] !N, which never toggles a mark off", function()
    local B = actions()
    for n = 1, 8 do
        local macro, reason, info = B.BakeActions(none{ marker = n }, PARTY)
        assertEqual(macro, "/tm [@target,exists] !" .. n) assertNil(reason)
        assertEqual(info.baked[1].kind, "marker") assertNil(info.baked[1].chatType) assertNil(info.baked[1].lock)
    end
end)

test("bake: [CA-M1-7] a localized client's commands bake; an absent one gives noPing or noMarker and drops only that action", function()
    local B, m = actions()
    m.SLASH_PING1, m.SLASH_TARGET_MARKER1 = "/aviso", "/mo"
    assertEqual((B.BakeActions(none{ ping = "attack" }, PARTY)), "/aviso [@target,exists] 1")
    assertEqual((B.BakeActions(none{ marker = 8 }, PARTY)), "/mo [@target,exists] !8")
    m.SLASH_PING1, m.SLASH_TARGET_MARKER1 = nil, nil
    local macro, reason, info = B.BakeActions(none{ ping = "attack" }, PARTY)
    assertNil(macro) assertEqual(reason, "noPing")
    assertEqual(#info.actions, 1) assertEqual(#info.baked, 0) assertEqual(info.actions[1].kind, "ping")
    macro, reason = B.BakeActions(none{ marker = 8 }, PARTY)
    assertNil(macro) assertEqual(reason, "noMarker")
    -- a Line beside the dropped ping still bakes (the join and the budget are CA-M2-2's)
    macro, reason = B.BakeActions(callout("go"), PARTY)
    assertEqual(macro, "/p go") assertNil(reason)
    m.C_Ping = nil
    m.SLASH_PING1 = "/ping"
    assertEqual(select(2, B.BakeActions(none{ ping = "attack" }, PARTY)), "noPing", "no ping system")
end)

test("bake: [CA-M1-7] no action is noAction; a non-table is badCallout; Bake's contract is unchanged", function()
    local B = actions()
    local macro, reason, info = B.BakeActions(none(), PARTY)
    assertNil(macro) assertEqual(reason, "noAction") assertEqual(#info.actions, 0) assertEqual(info.total, 0)
    macro, reason = B.BakeActions(nil, PARTY)
    assertNil(macro) assertEqual(reason, "badCallout")
    -- the game-emote kind with no emote, as Bake has always answered it
    assertEqual(select(2, B.Bake(none(), PARTY)), "noEmote")
    assertEqual((B.Bake(none{ emote = "POINT" }, PARTY)), "/point")
end)
