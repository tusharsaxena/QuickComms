-- tests/test_resolver.lua — modules/Resolver.lua (spec §5.3, §7).

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function res() return T.newAddon().Resolver end
local MPLUS = { content = "mythicPlus", instanceID = 2526, difficulty = "keystone", keyLevel = 14,
    group = "party", instanceGroup = false, leader = true, assist = false, classFile = "WARLOCK",
    specID = 265, role = "DAMAGER", character = "Traxex-Area52" }

test("resolver: an empty When always matches", function()
    local ok, matched = res().Matches({}, MPLUS)
    assertTrue(ok) assertEqual(#matched, 0)
    assertTrue((res().Matches(nil, MPLUS)))
end)

test("resolver: each row matches and fails on its own", function()
    local R = res()
    local CASES = {
        { { content = { mythicPlus = true } }, true },
        { { content = { raid = true } }, false },
        { { instances = { [2526] = true } }, true },
        { { instances = { [1] = true } }, false },
        { { difficulty = { keystone = true } }, true },
        { { keyLevel = { min = 10 } }, true },
        { { keyLevel = { min = 15 } }, false },
        { { keyLevel = { max = 12 } }, false },
        { { group = { party = true } }, true },
        { { group = { instance = true } }, false },
        { { leadership = { leader = true } }, true },
        { { leadership = { assist = true } }, false },
        { { class = { WARLOCK = true } }, true },
        { { spec = { [266] = true } }, false },
        { { role = { DAMAGER = true } }, true },
        { { characters = { ["Traxex-Area52"] = true } }, true },
        { { battleground = { [2107] = true } }, false },
    }
    for n, c in ipairs(CASES) do assertEqual((R.Matches(c[1], MPLUS)), c[2], "case " .. n) end
end)

test("resolver: rows AND, values OR, empty rows ignored", function()
    local R = res()
    assertTrue((R.Matches({ content = { raid = true, mythicPlus = true }, role = { DAMAGER = true }, class = {} }, MPLUS)))
    local ok, _, failed = R.Matches({ content = { mythicPlus = true }, role = { HEALER = true } }, MPLUS)
    assertFalse(ok) assertEqual(failed, "role")
end)

test("resolver: keyLevel never matches outside M+", function()
    assertFalse((res().Matches({ keyLevel = { min = 2 } }, { content = "dungeon", group = "party" })))
end)

test("resolver: ActiveGroups unions enabled matches", function()
    local groups = {
        a = { enabled = true, when = { content = { mythicPlus = true } } },
        b = { enabled = true, when = { instances = { [2526] = true } } },
        c = { enabled = false, when = {} },
        d = { enabled = true, when = { content = { raid = true } } },
    }
    local active = res().ActiveGroups(groups, MPLUS)
    assertTrue(active.a ~= nil) assertTrue(active.b ~= nil)
    assertTrue(active.c == nil) assertTrue(active.d == nil)
    assertEqual(active.a.matched[1], "content")
end)

test("resolver: SurfaceOrder keeps the surface's order; autoPromote floats narrower groups", function()
    local R = res()
    local groups = {
        mplus = { enabled = true, when = { content = { mythicPlus = true } } },
        spire = { enabled = true, when = { content = { mythicPlus = true }, instances = { [2526] = true } } },
        always = { enabled = true, when = {} },
        raid = { enabled = true, when = { content = { raid = true } } },
    }
    local active = R.ActiveGroups(groups, MPLUS)
    local list = { "always", "mplus", "raid", "spire", "ghost" }
    local plain = R.SurfaceOrder(list, active, groups, false)
    assertEqual(table.concat(plain, ","), "always,mplus,spire")
    local promoted = R.SurfaceOrder(list, active, groups, true)
    assertEqual(table.concat(promoted, ","), "spire,mplus,always")
end)

test("resolver: Explain names the matched rows", function()
    local R = res()
    assertEqual(R.Explain("M+", { matched = { "content", "keyLevel" } }), "M+: Content, Key level")
    assertEqual(R.Explain("Always", { matched = {} }), "Always: always on")
end)

test("resolver: [final] a non-number keyLevel bound is unset, never raises", function()
    local R = res()
    local s = { content = "mythicPlus", group = "party", keyLevel = 14 }
    local ok, matched = R.Matches({ keyLevel = { min = "10" } }, s)
    assertTrue(ok, "a string bound reads as unset")
    assertEqual(#matched, 0)
    assertTrue((R.Matches({ keyLevel = { min = "x", max = 15 } }, s)), "the number bound still applies")
    assertFalse((R.Matches({ keyLevel = { min = "x", max = 12 } }, s)))
    assertEqual(R.Narrowness({ keyLevel = { min = {} } }), 0)
end)
