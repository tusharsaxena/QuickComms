-- tests/test_resolver.lua — modules/Resolver.lua (spec §5.3, §7).

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

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

-- ── Inherit when conditions (2026-10-18-when-drawers-design.md §3) ─────────────────────────

local RAID = { content = "raid", group = "raid", classFile = "WARLOCK", role = "DAMAGER" }

test("resolver: [inherit] a child that inherits is judged by its parent's When, not its own", function()
    local R = res()
    local groups = {
        top = { enabled = true, when = { content = { raid = true } } },
        kid = { enabled = true, parent = "top", when = { content = { mythicPlus = true } } },
        own = { enabled = true, parent = "top", inheritWhen = false, when = { content = { mythicPlus = true } } },
        bare = { enabled = true, parent = "top", inheritWhen = true, when = {} },
    }
    -- red under: R.ActiveGroups reading g.when for a child that inherits
    local active = R.ActiveGroups(groups, MPLUS)
    assertNil(active.kid, "absent means on: the parent's raid When, so not in M+")
    assertNil(active.bare, "an empty When of its own no longer matches everywhere")
    assertTrue(active.own ~= nil, "unticked: its own M+ When")
    active = R.ActiveGroups(groups, RAID)
    assertTrue(active.kid ~= nil) assertTrue(active.bare ~= nil)
    assertNil(active.own)
    assertEqual(active.kid.matched[1], "content", "the parent's rows are the ones matched")
end)

test("resolver: [inherit] WhenOf names the When that judges a group, and whose it is", function()
    local R = res()
    local groups = {
        top = { when = { content = { raid = true } } },
        kid = { parent = "top", when = { role = { TANK = true } } },
        mine = { parent = "top", inheritWhen = false, when = { role = { TANK = true } } },
        lost = { parent = "ghost", when = { role = { HEALER = true } } },
    }
    local when, from = R.WhenOf(groups, "kid")
    assertTrue(when.content.raid) assertEqual(from, "top")
    when, from = R.WhenOf(groups, "mine")
    assertTrue(when.role.TANK) assertEqual(from, "mine")
    when, from = R.WhenOf(groups, "lost")
    assertTrue(when.role.HEALER, "a parent that is gone: its own") assertEqual(from, "lost")
    when, from = R.WhenOf(groups, "top")
    assertTrue(when.content.raid) assertEqual(from, "top")
    assertNil((R.WhenOf(groups, "nobody")))
end)

test("resolver: [inherit] SurfaceOrder's narrowness reads the When that judges the group", function()
    local R = res()
    local groups = {
        top = { enabled = true, when = { content = { raid = true }, instances = { [1] = true } } },
        kid = { enabled = true, parent = "top", when = {} },
        wide = { enabled = true, when = { content = { raid = true } } },
    }
    local s = { content = "raid", instanceID = 1 }
    local active = R.ActiveGroups(groups, s)
    -- red under: Narrowness of the child's own (empty) When
    assertEqual(table.concat(R.SurfaceOrder({ "wide", "kid" }, active, groups, true), ","), "kid,wide")
end)

test("resolver: [all] All battlegrounds and All dungeons and raids match the whole kind, the listed ids aside", function()
    local R = res()
    local bg = { battleground = { all = true, [2107] = true } }
    -- red under: a battleground row that only matches its listed ids
    assertTrue((R.Matches(bg, { content = "battleground", instanceID = 727 })), "any battleground")
    assertFalse((R.Matches(bg, { content = "arena", instanceID = 1505 })), "not an arena")
    assertFalse((R.Matches(bg, { content = "openWorld" })), "not the open world")
    local inst = { instances = { all = true } }
    assertTrue((R.Matches(inst, MPLUS)), "a key")
    assertTrue((R.Matches(inst, { content = "dungeon", instanceID = 1 })), "a dungeon")
    assertTrue((R.Matches(inst, { content = "raid", instanceID = 2 })), "a raid")
    assertFalse((R.Matches(inst, { content = "delve", instanceID = 3 })), "not a delve")
    assertFalse((R.Matches(inst, { content = "openWorld" })), "not the open world")
    -- A whole kind is a condition like any other row, not a specific place.
    assertEqual(R.Narrowness({ battleground = { all = true, [2107] = true } }), 1)
    assertEqual(R.Narrowness({ battleground = { [2107] = true } }), 101)
end)

test("resolver: [arena] the arena row matches only in an arena: its listed ids, or all of them", function()
    local R = res()
    -- red under: no arena row (an unknown row is never read, so it matched everywhere)
    assertTrue(R.LABEL.arena ~= nil)
    local one = { arena = { [1505] = true } }
    assertTrue((R.Matches(one, { content = "arena", instanceID = 1505 })))
    assertFalse((R.Matches(one, { content = "arena", instanceID = 572 })), "another arena")
    assertFalse((R.Matches(one, { content = "battleground", instanceID = 1505 })), "not outside an arena")
    local all = { arena = { all = true, [1505] = true } }
    assertTrue((R.Matches(all, { content = "arena", instanceID = 572 })), "any arena")
    assertFalse((R.Matches(all, { content = "battleground", instanceID = 727 })), "not a battleground")
    assertFalse((R.Matches(all, { content = "openWorld" })))
    assertFalse((R.Matches({ arena = { [1505] = true } }, MPLUS)))
    assertEqual(R.Narrowness(all), 1, "a whole kind is one condition")
    assertEqual(R.Narrowness(one), 101, "a specific arena moves up")
    assertTrue(R.ID_ROWS.arena and R.ID_ROWS.instances and R.ID_ROWS.battleground)
    assertNil(R.ID_ROWS.spec, "a specialization id is no place")
end)
