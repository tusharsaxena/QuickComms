-- tests/test_probe.lua — `/qc probe` and `/qc probe clear` (QFE-F5, the Forever port design §4.5,
-- owner-rulings C4): a record of the place, the situation, the role, the spec, the talent groups and
-- the client's emote tokens, kept in QuickCommsDB.global.probes by client key, never a new
-- SavedVariables global. Out of combat only. Both kit profiles.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

-- Molten Core as GetInstanceInfo answers it, all ten values; two emote tokens with a gap between.
local function place(env)
    env.IsInInstance = function() return true, "raid" end
    env.GetInstanceInfo = function()
        return "Molten Core", "raid", 9, "40 Player", 40, 0, false, 409, 40, nil
    end
    env.GetServerTime = function() return 1762790400 end
    env.MAXEMOTEINDEX = 5
    env.EMOTE1_TOKEN = "AGREE"
    env.EMOTE4_TOKEN = "POINT"
    env.EMOTE9_TOKEN = "PAST_THE_INDEX"
end

local function roleLib(m) return m.LibStub("LibKa0s-Role-1.0") end

test("probe: records the place, the situation, the role, the spec, the talent groups and the emotes", function()
    local NS, env, m = T.enableAddon()
    place(env)
    roleLib(m).Resolve = function() return "TANK", "talents", "Protection" end
    roleLib(m).Groups = function()
        return { { index = 1, id = 11, name = "Arms", spent = 0 }, { index = 2, id = 12, name = "Protection", spent = 31 } }
    end
    m.prints = {}
    NS.addon:OnSlashCommand("probe")
    local list = NS.db.global.probes[NS.Compat.ClientKey()]
    -- red under: no `probe` row in settings/Slash.lua
    assertEqual(#list, 1)
    local rec = list[1]
    assertEqual(rec.client, NS.Compat.ClientKey())
    assertEqual(rec.time, 1762790400)
    local i = rec.instance
    assertEqual(i.name, "Molten Core"); assertEqual(i.instanceType, "raid"); assertEqual(i.difficultyID, 9)
    assertEqual(i.difficultyName, "40 Player"); assertEqual(i.maxPlayers, 40); assertEqual(i.instanceID, 409)
    assertEqual(i.isDynamic, false); assertEqual(i.instanceGroupSize, 40); assertNil(i.lfgDungeonID)
    assertEqual(i.inInstance, true); assertEqual(i.inInstanceType, "raid")
    assertEqual(rec.content, "raid", "the classified kind")
    assertEqual(rec.situation.instanceID, 409)
    assertEqual(rec.role.role, "TANK"); assertEqual(rec.role.source, "talents"); assertEqual(rec.role.detail, "Protection")
    assertEqual(#rec.groups, 2); assertEqual(rec.groups[2].name, "Protection"); assertEqual(rec.groups[2].spent, 31)
    -- red under: a scan that stops at the first missing index (EMOTE2_TOKEN), or one past MAXEMOTEINDEX
    assertEqual(rec.emotes.count, 2)
    assertEqual(table.concat(rec.emotes.tokens, ","), "AGREE,POINT")
    assertTrue(rec.spec ~= nil and rec.spec.id == rec.situation.specID, "the spec the situation read")
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("Probe 1 saved for " .. rec.client, 1, true) ~= nil, text)
    assertTrue(text:find("place: Molten Core, type raid, difficulty 9 (40 Player), 40 players, instance 409", 1, true) ~= nil, text)
    assertTrue(text:find("content: raid", 1, true) ~= nil, text)
    assertTrue(text:find("role: Tank, from your talents: Protection", 1, true) ~= nil, text)
    assertTrue(text:find("talent groups: Arms 0, Protection 31; emotes: 2", 1, true) ~= nil, text)
    assertEqual(#m.prints, 4, "a short summary, not the record")
end)

test("probe: probes append in order, keep the newest PROBE_KEEP, and clear empties every client", function()
    local NS, env, m = T.enableAddon()
    place(env)
    NS.addon:OnSlashCommand("probe")
    NS.addon:OnSlashCommand("probe")
    local key = NS.Compat.ClientKey()
    assertEqual(#NS.db.global.probes[key], 2)
    NS.db.global.probes.other = { {}, {}, {} }
    local keep = NS.SlashVerbs.PROBE_KEEP
    NS.SlashVerbs.PROBE_KEEP = 2
    env.GetServerTime = function() return 1762790500 end
    NS.addon:OnSlashCommand("probe")
    NS.SlashVerbs.PROBE_KEEP = keep
    local list = NS.db.global.probes[key]
    -- red under: no cap (the list grows to 3)
    assertEqual(#list, 2)
    assertEqual(list[2].time, 1762790500, "the newest is last")
    m.prints = {}
    NS.addon:OnSlashCommand("probe clear")
    assertNil(NS.db.global.probes)
    assertTrue(m.prints[1]:find("Probes cleared: 5 removed.", 1, true) ~= nil, m.prints[1])
    m.prints = {}
    NS.addon:OnSlashCommand("probe clear")
    assertTrue(m.prints[1]:find("Probes cleared: 0 removed.", 1, true) ~= nil, m.prints[1])
end)

test("probe: refused in combat with one line, recording nothing; an unknown word names the forms", function()
    local NS, env, m = T.enableAddon()
    place(env)
    m.inCombat = true
    m.prints = {}
    NS.addon:OnSlashCommand("probe")
    -- red under: drop the combat check in settings/SlashVerbs.lua ProbeLines
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("not available in combat", 1, true) ~= nil, m.prints[1])
    assertNil(NS.db.global.probes)
    m.inCombat = false
    m.prints = {}
    NS.addon:OnSlashCommand("probe bogus")
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("/qc probe clear", 1, true) ~= nil, m.prints[1])
    assertNil(NS.db.global.probes)
end)

test("probe: never a new SavedVariables global, and the TOC lists none for it", function()
    local NS, env = T.enableAddon()
    place(env)
    NS.addon:OnSlashCommand("probe")
    -- db.sv is the raw SavedVariables table AceDB was handed (QuickCommsDB)
    assertTrue(type(NS.db.sv.global.probes) == "table", "in QuickCommsDB")
    local toc = assert(io.open("QuickComms.toc", "rb")):read("*a")
    local sv = toc:match("## SavedVariables:%s*([^\r\n]*)")
    -- red under: a QuickCommsProbeDB (or any third) SavedVariables global
    assertEqual(sv, "QuickCommsDB, QuickCommsPerfDB")
end)

test("probe: secret or missing client answers are stored as nil, never as the value", function()
    local NS, env = T.enableAddon()
    env.IsInInstance = nil
    env.GetInstanceInfo = nil
    env.GetServerTime = nil
    env.MAXEMOTEINDEX = nil
    NS.addon:OnSlashCommand("probe")
    local rec = NS.db.global.probes[NS.Compat.ClientKey()][1]
    assertNil(rec.time)
    assertNil(rec.instance.name)
    assertNil(rec.instance.inInstance)
    assertEqual(rec.emotes.count, 0)
    assertEqual(rec.content, "openWorld")
end)
