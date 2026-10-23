-- tests/test_tokens.lua — modules/Tokens.lua (spec §8.1): chips to engine tokens and baked values.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function tok() return T.newAddon().Tokens end

test("tokens: target and focus become engine tokens and count as live", function()
    local out, unknown, missing, live = tok().Expand("Kick {target} then {focus}")
    assertEqual(out, "Kick %t then %f")
    assertEqual(#unknown, 0)
    assertEqual(#missing, 0)
    assertEqual(live, 2)
end)

test("tokens: raid markers by number and name, any case", function()
    local Tok = tok()
    assertEqual((Tok.Expand("{rt8} {Skull} {STAR} {x}")), "{rt8} {rt8} {rt1} {rt7}")
end)

test("tokens: group tokens map to {gN}", function()
    local Tok = tok()
    assertEqual((Tok.Expand("{group3} soak, {g1} stack")), "{g3} soak, {g1} stack")
    assertTrue(Tok.UsesGroupToken("stack {group2}"))
    assertTrue(Tok.UsesGroupToken("{g8}"))
    assertFalse(Tok.UsesGroupToken("{rt8}"))
end)

test("tokens: baked values come from ctx; absent ones are missing", function()
    local out, _, missing = tok().Expand("{me} at +{key} in {dungeon} as {spec}/{role}",
        { me = "Traxex", key = 14, dungeon = "Windrunner Spire", spec = "Destruction" })
    assertEqual(out, "Traxex at +14 in Windrunner Spire as Destruction/")
    assertEqual(#missing, 1)
    assertEqual(missing[1], "role")
end)

test("tokens: spell links bake through ctx.spellLink; unknown ids are missing", function()
    local ctx = { spellLink = function(id) if id == 2825 then return "|cff71d5ff|Hspell:2825|h[Bloodlust]|h|r" end end }
    local out, _, missing = tok().Expand("{spell:2825} now, {spell:1}", ctx)
    assertEqual(out, "|cff71d5ff|Hspell:2825|h[Bloodlust]|h|r now, ")
    assertEqual(missing[1], "spell:1")
end)

test("tokens: unknown chips stay as typed and are reported", function()
    local out, unknown = tok().Expand("{location} help")
    assertEqual(out, "{location} help")
    assertEqual(unknown[1], "location")
end)

test("tokens: typed %t and %f count as live, chips are not double counted", function()
    local Tok = tok()
    assertEqual(select(4, Tok.Expand("hi %t and %f")), 2)
    assertEqual(select(4, Tok.Expand("{target} %t")), 2)
end)

test("tokens: non-string text expands to empty", function()
    assertEqual((tok().Expand(nil)), "")
end)

test("tokens: a mock fills a baked value missing here, and only when given (the preview echo, QC-07)", function()
    local Tok = tok()
    local mock = function(name) return "<" .. name .. ">" end
    local out, _, missing = Tok.Expand("+{key} {spell:99} {me} {target}", { me = "Ann" }, mock)
    assertEqual(out, "+<key> <spell:99> Ann %t")
    assertEqual(#missing, 2, "still reported missing")
    assertEqual((Tok.Expand("+{key} {me}", { me = "Ann" })), "+ Ann", "no mock: dropped, as a send does")
end)

test("tokens: [QF-03] {coordinates} and {coords} bake from ctx.coordinates; missing is dropped and listed, or mocked", function()
    local Tok = tok()
    local ctx = { coordinates = "45.2, 61.8" }
    -- red under: no `coordinates` in Tokens' BAKED (it stays as an unknown chip)
    local out, unknown, missing = Tok.Expand("{target} @ {coordinates}", ctx)
    assertEqual(out, "%t @ 45.2, 61.8")
    assertEqual(#unknown, 0)
    assertEqual(#missing, 0)
    -- red under: no `coords` alias
    assertEqual((Tok.Expand("at {Coords}", ctx)), "at 45.2, 61.8")
    local _
    out, _, missing = Tok.Expand("{target} @ {coordinates}", {})
    assertEqual(out, "%t @ ", "dropped, as a send does")
    assertEqual(missing[1], "coordinates")
    local asked
    out = Tok.Expand("{target} @ {coords}", {}, function(name) asked = name return "<" .. name .. ">" end)
    assertEqual(out, "%t @ <coordinates>")
    assertEqual(asked, "coordinates", "the alias asks the mock by the token's own name")
    assertTrue(Tok.UsesCoordinates("{target} @ {COORDINATES}"))
    assertTrue(Tok.UsesCoordinates("at {coords}"))
    assertFalse(Tok.UsesCoordinates("{dungeon} +{key}"))
    assertFalse(Tok.UsesCoordinates(nil))
end)
