-- tests/test_client_data.lua — the per-client game data (QFE-F3; defaults/GameIds_Clients.lua): the
-- content kinds the When editor and Preview as... offer, the rows the editor draws, the place lists,
-- the token help and the built-in sets seeded, each pinned for the kit profile the suite runs under.
-- Every case boots with `clientData = true`, so the addon keeps the client's own data (tests/run.lua
-- pins Retail's for every other suite). Under the retail profile each case pins Retail unchanged;
-- under forever, WoW Forever's lists, hidden kinds and seeds. Classify is the same on both clients
-- and hiding is UI and seeds only, so a profile copied from Retail still loads and matches.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local FOREVER = dofile("tests/_kit/mock_client.lua").current() == "forever"
local CLIENT = FOREVER and "forever" or "retail"

local ALL_KINDS = { "openWorld", "dungeon", "mythicPlus", "raid", "delve", "scenario", "battleground", "arena", "housing" }
local FOREVER_KINDS = { "openWorld", "dungeon", "raid", "battleground" }
local FOREVER_BGS = { "bi.bg.ab", "bi.bg.av", "bi.bg.wsg" }

local function values(list, field)
    local out = {}
    for i, v in ipairs(list) do out[i] = v[field] end
    return out
end

local function joined(list) return table.concat(list, ",") end

local function sorted(list)
    local out = {}
    for i, v in ipairs(list) do out[i] = v end
    table.sort(out)
    return out
end

local function origins(p)
    local out = {}
    for _, g in pairs(p.groups) do
        if type(g.origin) == "string" then out[g.origin] = true end
    end
    return out
end

test("client data: [QFE-F3] the lists are the client's, picked once by ClientKey", function()
    local NS = T.newAddon({ clientData = true })
    local G = NS.GameIds
    assertEqual(G.CLIENT, CLIENT)
    for _, name in ipairs({ "DUNGEONS", "RAIDS", "INSTANCES", "ARENAS" }) do
        -- red under: GameIds_Clients.lua always picking Retail's (or never picking)
        assertTrue(G[name] == G.BY_CLIENT[CLIENT][name], name .. " is " .. CLIENT .. "'s")
    end
    if FOREVER then
        assertEqual(#G.DUNGEONS, 17, "the classic-era dungeons Retail lists")
        assertEqual(joined(G.RAIDS), "409,249,469,509,531,533", "Forever's raids (ruling R1)")
        assertEqual(#G.INSTANCES, #G.DUNGEONS + #G.RAIDS, "the classic-era subset")
        assertEqual(#G.ARENAS, 0, "no arena")
    else
        assertEqual(#G.DUNGEONS, 8, "the season's eight, unchanged")
        assertEqual(#G.INSTANCES, 201, "every journal dungeon and raid, unchanged")
        assertNil(G.BATTLEGROUND_SETS, "every battleground set")
    end
end)

test("client data: [QFE-F3] UseClient replaces the whole pick, BATTLEGROUND_SETS included", function()
    local NS = T.newAddon({ clientData = true })
    local G = NS.GameIds
    G.UseClient("forever")
    assertTrue(G.BATTLEGROUND_SETS ~= nil and G.SKIP_BUILTINS["bi.arena"] == true)
    assertTrue(G.BUILTIN_WHEN["bi.mplus"] ~= nil, "Forever's Dungeon When")
    G.UseClient("retail")
    -- red under: a loop over the picked table's pairs, which leaves Forever's nil-in-Retail key behind
    assertNil(G.BATTLEGROUND_SETS)
    assertNil(G.SKIP_BUILTINS["bi.arena"])
    assertNil(G.BUILTIN_WHEN["bi.mplus"], "Retail's Dungeon When is the declared one")
    G.UseClient("classic")
    assertEqual(G.CLIENT, "retail", "an unknown key is Retail")
end)

test("client data: [QFE-F3] the When editor's content kinds and drawers are the client's", function()
    local NS = T.bootAddon({ clientData = true })
    local W = NS.addon.Settings.GroupsWhen
    local kinds = values(W.Values("content", {}), "value")
    -- red under: contentValues offering NS.Resolver.TOKENS.content whole on Forever
    assertEqual(joined(kinds), joined(FOREVER and FOREVER_KINDS or ALL_KINDS))
    local all = W.SelectAll({}, "content").content
    assertEqual(all.mythicPlus, (not FOREVER) or nil, "Select all ticks only what is offered")
    local rows = joined(W.Rows())
    if FOREVER then
        assertFalse(rows:find("difficulty") ~= nil, "no Difficulty drawer")
        assertFalse(rows:find("keyLevel") ~= nil, "no Key level drawer")
        assertFalse(rows:find("arena") ~= nil, "no Arena drawer")
        assertTrue(rows:find("battleground") ~= nil and rows:find("instances") ~= nil)
    else
        assertEqual(rows, joined(W.ROWS), "every drawer")
    end
    -- the token list is the same on both: a stored hidden kind is still a valid When value
    assertEqual(joined(NS.Resolver.TOKENS.content), joined(ALL_KINDS))
end)

test("client data: [QFE-F3] Preview as... offers the client's dungeons, raids and battlegrounds", function()
    local NS = T.enableAddon({ clientData = true })
    local G, keys, labels = NS.GameIds, {}, {}
    for _, e in ipairs(NS.Preview.Presets()) do
        keys[e.key] = e
        labels[#labels + 1] = e.label
    end
    local bgs = {}
    for key in pairs(keys) do
        if key:match("^bg:") then bgs[#bgs + 1] = "bi.bg." .. key:sub(4) end
    end
    if FOREVER then
        for _, id in ipairs(G.DUNGEONS) do
            local e = keys["dungeon:" .. id]
            -- red under: Presets building every dungeon as an M+ key on Forever
            assertTrue(e ~= nil, "dungeon " .. id)
            assertEqual(e.snapshot.content, "dungeon")
            assertNil(keys["mplus:" .. id])
        end
        for _, id in ipairs(G.RAIDS) do
            local e = keys["raid:" .. id]
            assertTrue(e ~= nil, "raid " .. id)
            assertFalse(e.label:find("Mythic") ~= nil, "no difficulty named: " .. e.label)
        end
        assertNil(keys.arena, "no Arena")
        assertEqual(joined(sorted(bgs)), joined(FOREVER_BGS))
        for _, label in ipairs(labels) do assertFalse(label:find("M%+") ~= nil, label) end
    else
        for _, id in ipairs(G.DUNGEONS) do assertTrue(keys["mplus:" .. id] ~= nil, "mplus " .. id) end
        assertTrue(keys.arena ~= nil, "Arena")
        assertEqual(#bgs, 14, "every battleground set")
    end
end)

test("client data: [QFE-F3] a fresh profile seeds the client's sets: no Arena set on Forever", function()
    local NS = T.bootAddon({ clientData = true })
    local p, BI = NS.db.profile, NS.BuiltIns
    local have = origins(p)
    -- red under: seedNew walking BuiltIns.order whole on Forever
    assertEqual(have["bi.arena"], (not FOREVER) or nil, "the Arena set")
    assertTrue(have["bi.mplus"], "the Dungeon set, on both clients (C7)")
    assertTrue(have["bi.raid"] and have["bi.world"] and have["bi.bg"] and have["bi.group"], "the rest")
    local bgs = {}
    for origin in pairs(have) do
        if origin:match("^bi%.bg%.[^%.]+$") then bgs[#bgs + 1] = origin end
    end
    if FOREVER then
        assertEqual(joined(sorted(bgs)), joined(FOREVER_BGS), "Warsong Gulch, Arathi Basin, Alterac Valley")
        assertTrue(have["bi.bg.wsg.ourflag"] and have["bi.bg.av.vanndar"] and have["bi.bg.ab.stables"],
            "with their objective callouts")
    else
        assertEqual(#bgs, 14, "every battleground set")
    end
    assertEqual(#p.pads[p.padOrder[1]].groups, #BI.Seeded(), "the pad holds each seeded set")
    -- Restore brings back what the client ships and nothing else
    local n = NS.Library.RestoreBuiltins()
    assertEqual(n.groups, 0, "nothing missing")
    assertEqual(origins(p)["bi.arena"], (not FOREVER) or nil, "Restore seeds no Arena set on Forever")
end)

-- The Dungeon set's When (C7): Retail's matches any dungeon, a keystone run included; Forever has no
-- Mythic+, so its copy matches the content kind dungeon alone, with no key level.
local function dungeonWhen(when)
    local kinds = {}
    for kind, on in pairs(when.content or {}) do
        if on then kinds[#kinds + 1] = kind end
    end
    local rows = {}
    for row in pairs(when) do rows[#rows + 1] = row end
    return joined(sorted(kinds)) .. "|" .. joined(sorted(rows))
end

test("client data: [QFE-C7] the Dungeon set seeds on both clients, dungeon only on Forever", function()
    local NS = T.bootAddon({ clientData = true })
    local p, Lib = NS.db.profile, NS.Library
    local gid = T.seeded(NS, "bi.mplus")
    assertTrue(gid ~= nil, "a fresh profile holds the Dungeon set")
    -- red under: seedGroup copying the declared When on Forever (dungeon + mythicPlus)
    local want = FOREVER and "dungeon|content" or "dungeon,mythicPlus|content"
    assertEqual(dungeonWhen(p.groups[gid].when), want, "its When")
    assertTrue(NS.Resolver.Matches(p.groups[gid].when, { content = "dungeon" }), "a dungeon matches")
    assertEqual(NS.Resolver.Matches(p.groups[gid].when, { content = "mythicPlus" }) == true, not FOREVER,
        "a keystone run matches only on Retail")
    assertEqual(#p.groups[gid].callouts, #NS.BuiltIns.groups["bi.mplus"].callouts, "every callout")
    -- the shipped declaration is never changed by the per-client When
    assertEqual(dungeonWhen(NS.BuiltIns.groups["bi.mplus"].when), "dungeon,mythicPlus|content")
    -- deleted, Restore brings it back with the client's When
    assertTrue(Lib.DeleteGroup(gid))
    assertNil(T.seeded(NS, "bi.mplus"))
    assertEqual(Lib.RestoreBuiltins().groups >= 1, true, "Restore brings it back")
    local back = T.seeded(NS, "bi.mplus")
    assertTrue(back ~= nil)
    assertEqual(dungeonWhen(p.groups[back].when), want, "Restore's copy has the client's When too")
    -- a seeded copy's When is its own table, not the override's
    p.groups[back].when.content.raid = true
    assertNil((NS.GameIds.BUILTIN_WHEN["bi.mplus"] or NS.BuiltIns.groups["bi.mplus"].when).content.raid)
end)

test("client data: [QFE-F3] a set held from Retail still loads, matches and keeps its callouts on Forever", function()
    local NS = T.bootAddon({ clientData = true })
    local G, p, Lib = NS.GameIds, NS.db.profile, NS.Library
    -- a profile copied from Retail: Retail's Restore gives it the Arena set
    G.UseClient("retail")
    Lib.RestoreBuiltins()
    local arena = T.seeded(NS, "bi.arena")
    assertTrue(arena ~= nil, "a Retail profile's Arena set")
    G.UseClient("forever")
    local n = Lib.RestoreBuiltins()
    assertEqual(n.groups, 0, "nothing new on Forever")
    assertTrue(p.groups[arena] ~= nil, "the set is kept")
    local ok = NS.Resolver.Matches(p.groups[arena].when, { content = "arena" })
    assertTrue(ok, "a hidden kind still matches")
end)

test("client data: [QFE-F3] the battleground row suggests the seeded sets' maps", function()
    local NS = T.bootAddon({ clientData = true })
    local W = NS.addon.Settings.GroupsWhen
    assertEqual(W.ResolveValue("battleground", "Alterac Valley"), 30, "Alterac Valley by name on both")
    local twin = W.ResolveValue("battleground", "Twin Peaks")
    -- red under: battlegroundIds offering every set's maps on Forever
    assertEqual(twin ~= nil, not FOREVER, "Twin Peaks only where it is seeded")
    assertEqual(W.BattlegroundName(726), "Twin Peaks", "a stored id of another set is still named")
end)

test("client data: [QFE-F3] the token help leaves {dungeon} and {key} out on Forever", function()
    local NS = T.bootAddon({ clientData = true })
    local C = NS.addon.Settings.Callouts
    local tokens = joined(C.TokensFor("party"))
    -- red under: TokensFor offering C.TOKENS whole on Forever
    assertEqual(tokens:find("{dungeon}", 1, true) ~= nil, not FOREVER)
    -- red under: HIDDEN_TOKENS naming {dungeon} alone ({key} is Mythic+ only too, C7)
    assertEqual(tokens:find("{key}", 1, true) ~= nil, not FOREVER)
    assertTrue(tokens:find("{spec}", 1, true) ~= nil, "the rest stay")
    local help = {}
    for _, row in ipairs(C.TokenHelp("party")) do help[#help + 1] = row[1] end
    assertEqual(joined(help):find("{dungeon}", 1, true) ~= nil, not FOREVER)
    assertEqual(joined(help):find("{key}", 1, true) ~= nil, not FOREVER)
end)
