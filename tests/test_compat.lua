-- tests/test_compat.lua — core/Compat.lua: secret guards and readers return plain values or nil.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertNil, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertNil, T.assertTrue, T.assertFalse

test("compat: plain readers pass plain values and drop secrets", function()
    local NS, env = T.newAddon()
    env.issecretvalue = T.isSecret   -- nothing installs the global by default (kit secrets.lua)
    local C = NS.Compat
    assertEqual(C.PlainNumber(5), 5)
    assertNil(C.PlainNumber("5"))
    assertNil(C.PlainNumber(T.secret(5)))
    assertEqual(C.PlainString("party"), "party")
    assertNil(C.PlainString(T.secret("party")))
    assertFalse(C.IsSafeKey(nil))
    assertFalse(C.IsSafeKey(T.secret(1)))
    assertTrue(C.IsSafeKey(1))
end)

test("compat: InstanceInfo with a secret instanceID reads nil, never raises", function()
    local NS, env = T.newAddon()
    env.issecretvalue = T.isSecret
    env.IsInInstance = function() return true, "party" end
    env.GetInstanceInfo = function() return "X", "party", 8, "Mythic Keystone", 5, 0, false, T.secret(2526) end
    local inInstance, itype, diff, id = NS.Compat.InstanceInfo()
    assertTrue(inInstance)
    assertEqual(itype, "party")
    assertEqual(diff, 8)
    assertNil(id)
end)

test("compat: InstanceInfo during a loading screen (all nil) reads safely", function()
    local NS, env = T.newAddon()
    env.IsInInstance = function() return nil end
    env.GetInstanceInfo = function() return nil end
    local inInstance, itype, diff, id = NS.Compat.InstanceInfo()
    assertFalse(inInstance)
    assertNil(itype) assertNil(diff) assertNil(id)
end)

test("compat: [final] an empty-string realm falls back to the normalized realm name", function()
    local NS, env = T.newAddon()
    env.UnitFullName = function() return "Kaos", "" end
    env.GetNormalizedRealmName = function() return "Silvermoon" end
    local _, _, _, character = NS.Compat.PlayerIdentity()
    -- red under: `if not realm` alone
    assertEqual(character, "Kaos-Silvermoon")
end)

test("compat: UseKeyDown reads the cvar, and defaults on when it cannot", function()
    local NS, env = T.newAddon()
    assertTrue(NS.Compat.UseKeyDown())
    env.cvars.ActionButtonUseKeyDown = "0"
    assertFalse(NS.Compat.UseKeyDown())
    env.C_CVar, env.GetCVarBool = nil, nil
    assertTrue(NS.Compat.UseKeyDown())
end)

test("compat: SenderIsPlayer answers by GUID, then by name, and nil when it cannot read either", function()
    local NS, env = T.newAddon()
    env.issecretvalue = T.isSecret
    local C = NS.Compat
    assertTrue(C.SenderIsPlayer("Someone", env.playerGUID), "the GUID decides")
    assertFalse(C.SenderIsPlayer("Testchar", "Player-1-99999999"), "a readable other GUID")
    env.GetNormalizedRealmName = function() return "Testrealm" end
    assertTrue(C.SenderIsPlayer("Testchar-Testrealm", nil), "the full name")
    assertTrue(C.SenderIsPlayer("Testchar", nil), "a same-realm sender carries no realm")
    assertFalse(C.SenderIsPlayer("Other-Testrealm", nil))
    assertNil(C.SenderIsPlayer(T.secret("Testchar"), T.secret("guid")), "secret is unknown")
    assertNil(C.SenderIsPlayer(nil, nil))
end)

test("compat: [fix wave] SenderIsPlayer: a cross-realm namesake is not the player; an unreadable realm is unknown", function()
    local NS, env = T.newAddon()
    local C = NS.Compat
    env.UnitFullName = function() return "Testchar", "Testrealm" end
    -- red under: compare the bare name with the realm stripped
    assertFalse(C.SenderIsPlayer("Testchar-Otherrealm", nil), "a namesake from another realm")
    assertTrue(C.SenderIsPlayer("Testchar-Testrealm", nil))
    env.UnitFullName = function() return "Testchar", nil end
    env.GetNormalizedRealmName = nil
    assertNil(C.SenderIsPlayer("Testchar-Testrealm", nil), "the realm cannot be read: unknown")
    assertFalse(C.SenderIsPlayer("Other-Testrealm", nil), "another name is never the player")
    assertTrue(C.SenderIsPlayer("Testchar", nil))
end)

test("compat: HasTemplate answers where C_XMLUtil can, and nil where it cannot", function()
    local NS, env = T.newAddon()
    local C = NS.Compat
    -- red under: answer false (or true) without C_XMLUtil; the popup then never tries CreateFrame
    assertNil(C.HasTemplate("SettingsFrameTemplate"), "no C_XMLUtil: unknown")
    env.C_XMLUtil = { GetTemplateInfo = function(name)
        if name == "SettingsFrameTemplate" then return { type = "Frame" } end
    end }
    assertTrue(C.HasTemplate("SettingsFrameTemplate"))
    assertFalse(C.HasTemplate("NoSuchTemplate"), "GetTemplateInfo answers nil: the client lacks it")
    assertNil(C.HasTemplate(nil))
    env.C_XMLUtil.GetTemplateInfo = function() error("changed API") end
    assertFalse(C.HasTemplate("SettingsFrameTemplate"), "a raising API never escapes")
end)

test("compat: ChatColor reads the client's chat colors and declines what it cannot read", function()
    local NS, env = T.newAddon()
    local r, g, b = NS.Compat.ChatColor("PARTY")
    assertEqual(r, 0.67)
    assertEqual(g, 0.67)
    assertEqual(b, 1.0)
    assertNil(NS.Compat.ChatColor("NOPE"))
    assertNil(NS.Compat.ChatColor(nil))
    env.ChatTypeInfo = nil
    assertNil(NS.Compat.ChatColor("PARTY"))
end)

test("compat: [phase 3] InstanceName reads the client's name; a secret, empty or missing one is nil", function()
    local NS, env = T.newAddon()
    env.issecretvalue = T.isSecret
    env.GetRealZoneText = function(id)
        if id == 2526 then return "Algeth'ar Academy" end
        if id == 2 then return "" end
        return T.secret("x")
    end
    assertEqual(NS.Compat.InstanceName(2526), "Algeth'ar Academy")
    assertNil(NS.Compat.InstanceName(1))
    assertNil(NS.Compat.InstanceName(2))
    assertNil(NS.Compat.InstanceName("2526"))
    env.GetRealZoneText = nil
    assertNil(NS.Compat.InstanceName(2526))
end)

test("compat: [phase 3] SpecInfoByID and ClassName read display names; secret or missing ones are nil", function()
    local NS, env = T.newAddon()
    env.issecretvalue = T.isSecret
    env.GetSpecializationInfoByID = function(id)
        if id == 265 then return 265, "Affliction", "", 136145, "DAMAGER", "WARLOCK" end
        return id, T.secret("x")
    end
    env.LOCALIZED_CLASS_NAMES_MALE = { WARLOCK = "Warlock", MAGE = T.secret("Mage") }
    local name, icon = NS.Compat.SpecInfoByID(265)
    assertEqual(name, "Affliction")
    assertEqual(icon, 136145)
    assertNil((NS.Compat.SpecInfoByID(62)))
    assertEqual(NS.Compat.ClassName("WARLOCK"), "Warlock")
    assertNil(NS.Compat.ClassName("MAGE"))
    assertNil(NS.Compat.ClassName("NOPE"))
    env.GetSpecializationInfoByID, env.LOCALIZED_CLASS_NAMES_MALE = nil, nil
    assertNil((NS.Compat.SpecInfoByID(265)))
    assertNil(NS.Compat.ClassName("WARLOCK"))
end)

test("compat: [final 8] BindingKey reads a command's key; a secret or a missing API is nil", function()
    local NS, m = T.newAddon()
    m.bindingKeys["CLICK QuickCommsDial1:Toggle"] = "F"
    assertEqual(NS.Compat.BindingKey("CLICK QuickCommsDial1:Toggle"), "F")
    T.assertNil(NS.Compat.BindingKey("CLICK QuickCommsDial2:Toggle"))
    m.issecretvalue = T.isSecret
    m.bindingKeys["CLICK QuickCommsDial1:Toggle"] = T.secret("F")
    T.assertNil(NS.Compat.BindingKey("CLICK QuickCommsDial1:Toggle"))
    m.GetBindingKey = nil
    T.assertNil(NS.Compat.BindingKey("CLICK QuickCommsDial1:Toggle"))
end)


test("compat: [QFE-F1] FrameStrata answers a plain strata, else the fallback (a secret on WoW Forever)", function()
    local NS, m = T.newAddon()
    m.issecretvalue = T.isSecret
    local C = NS.Compat
    local function f(v) return { GetFrameStrata = function() return v end } end
    -- red under: no Compat.FrameStrata, or one that hands a secret strata back
    assertEqual(C.FrameStrata(f("HIGH"), "DIALOG"), "HIGH")
    assertEqual(C.FrameStrata(f(T.secret("HIGH")), "DIALOG"), "DIALOG", "a secret strata")
    assertEqual(C.FrameStrata(f(nil), "DIALOG"), "DIALOG", "no strata")
    assertEqual(C.FrameStrata(f(7), "DIALOG"), "DIALOG", "not a string")
    assertEqual(C.FrameStrata({}, "DIALOG"), "DIALOG", "no GetFrameStrata")
    assertEqual(C.FrameStrata(nil, "DIALOG"), "DIALOG", "no frame")
end)

test("compat: [QF-03] Coordinates reads the map position as x, y in percent, one decimal, or nil", function()
    local NS, m = T.newAddon()
    m.issecretvalue = T.isSecret
    local C = NS.Compat
    m.playerMap, m.playerPos = 2393, { 0.452, 0.618 }
    -- red under: no Compat.Coordinates (or a format other than "%.1f, %.1f")
    assertEqual(C.Coordinates(), "45.2, 61.8")
    local x, y = C.PlayerMapPosition()
    assertEqual(("%.1f"):format(x), "45.2")
    assertEqual(("%.1f"):format(y), "61.8")
    m.playerMap = nil
    assertNil(C.Coordinates(), "no map id (an instance)")
    m.playerMap, m.playerPos = 2393, nil
    assertNil(C.Coordinates(), "no position on that map")
    m.playerPos = { 0, 0 }
    assertNil(C.Coordinates(), "0, 0 is no position")
    m.playerPos = { T.secret(0.4), 0.5 }
    assertNil(C.Coordinates(), "a secret value")
    m.playerPos = { 0.4, 0.5 }
    m.playerMap = T.secret(2393)
    assertNil(C.Coordinates(), "a secret map id")
    m.playerMap = 2393
    m.C_Map = nil
    assertNil(C.Coordinates(), "no C_Map")
end)

test("compat: [QF-04] GeneralJoined is true only when the client names channel 1 as General", function()
    local NS, m = T.newAddon()
    m.issecretvalue = T.isSecret
    local C = NS.Compat
    -- red under: no Compat.GeneralJoined
    assertTrue(C.GeneralJoined())
    m.generalChannel = nil
    assertFalse(C.GeneralJoined(), "not joined")
    -- red under: GeneralJoined reading GetChannelName(1)'s id (any channel 1 counts)
    m.generalChannel = 2
    assertFalse(C.GeneralJoined(), "General moved to /2: channel 1 is some other channel")
    m.C_ChatInfo.GetGeneralChannelLocalID = function() return T.secret(1) end
    assertFalse(C.GeneralJoined(), "a secret id")
    m.C_ChatInfo.GetGeneralChannelLocalID = nil
    assertFalse(C.GeneralJoined(), "no API")
    m.C_ChatInfo = nil
    assertFalse(C.GeneralJoined(), "no C_ChatInfo")
end)

-- ── pings and raid target markers (CA-M1-2, spec §4 step 5, §5, §6) ────────────────────────────

test("compat: [CA-M1-2] PingCommand and MarkerCommand read the localized commands, nil when absent or secret", function()
    local NS, m = T.newAddon()
    m.issecretvalue = T.isSecret
    local C = NS.Compat
    -- red under: no Compat.PingCommand / Compat.MarkerCommand
    assertEqual(C.PingCommand(), "/ping")
    assertEqual(C.MarkerCommand(), "/tm")
    m.SLASH_PING1, m.SLASH_TARGET_MARKER1 = "/aviso", "/mo"
    assertEqual(C.PingCommand(), "/aviso", "a localized client's command")
    assertEqual(C.MarkerCommand(), "/mo")
    m.SLASH_PING1, m.SLASH_TARGET_MARKER1 = T.secret("/ping"), T.secret("/tm")
    assertNil(C.PingCommand(), "a secret command")
    assertNil(C.MarkerCommand())
    m.SLASH_PING1, m.SLASH_TARGET_MARKER1 = nil, nil
    assertNil(C.PingCommand(), "no global")
    assertNil(C.MarkerCommand())
    m.SLASH_PING1 = "/ping"
    m.C_Ping = nil
    assertNil(C.PingCommand(), "no C_Ping: the client has no ping system")
end)

test("compat: [CA-M1-2] PingState answers off, cooldown or ok, and nil when it cannot read", function()
    local NS, m = T.newAddon()
    m.issecretvalue = T.isSecret
    local C = NS.Compat
    assertEqual(C.PingState(), "ok")
    m.pingEnabled = false
    assertEqual(C.PingState(), "off", "the system is off")
    m.pingEnabled = true
    m.cvars.enablePings = "0"
    assertEqual(C.PingState(), "off", "the player turned pings off")
    m.cvars.enablePings = "1"
    m.__now = 10
    m.pingCooldownEndMs = 10500
    -- red under: comparing endTimeMs with GetTime() in seconds (Blizzard_PingUI's base is ms)
    assertEqual(C.PingState(), "cooldown")
    m.pingCooldownEndMs = 9000
    assertEqual(C.PingState(), "ok", "a cooldown that has ended")
    m.pingCooldownEndMs = T.secret(10500)
    assertEqual(C.PingState(), "ok", "a secret end time is not a known cooldown")
    m.pingCooldownEndMs = 0
    m.pingEnabled = T.secret(false)
    assertNil(C.PingState(), "a secret enabled flag is unknown")
    m.pingEnabled = true
    m.C_Ping = nil
    assertNil(C.PingState(), "no ping system")
end)

test("compat: [CA-M1-2] TargetExists and CanMark are plain booleans, nil on a secret or a missing API", function()
    local NS, m = T.newAddon()
    m.issecretvalue = T.isSecret
    local C = NS.Compat
    assertFalse(C.TargetExists())
    m.__unitExists.target = true
    assertTrue(C.TargetExists())
    m.__unitExists.target = T.secret(false)
    -- red under: `not UnitExists("target")` (a secret is truthy here and raises in the client)
    assertNil(C.TargetExists(), "a secret is unknown")
    assertTrue(C.CanMark("target"))
    m.raidTargetable = false
    assertFalse(C.CanMark("target"))
    m.raidTargetable = T.secret(false)
    assertNil(C.CanMark("target"), "a secret is unknown")
    m.CanBeRaidTarget = nil
    assertNil(C.CanMark("target"), "no API")
end)

test("compat: [CA-M1-2] InRaid and EveryoneAssistant are plain, a secret reads false", function()
    local NS, m = T.newAddon()
    m.issecretvalue = T.isSecret
    local C = NS.Compat
    assertFalse(C.InRaid())
    assertFalse(C.EveryoneAssistant())
    m.__context.inRaid, m.everyoneAssist = true, true
    assertTrue(C.InRaid())
    assertTrue(C.EveryoneAssistant())
    m.__context.inRaid, m.everyoneAssist = T.secret(true), T.secret(true)
    assertFalse(C.InRaid())
    assertFalse(C.EveryoneAssistant())
    m.IsEveryoneAssistant = nil
    assertFalse(C.EveryoneAssistant(), "no API")
end)

test("compat: [CA-M1-2] MarkerRights: a raid needs leader, assist or everyone-assistant; a party may mark", function()
    local NS, m = T.newAddon()
    m.issecretvalue = T.isSecret
    local C = NS.Compat
    assertEqual(C.MarkerRights(), "ok", "solo")
    m.__context.inGroup = true
    assertEqual(C.MarkerRights(), "ok", "a party")
    m.__context.inRaid = true
    assertEqual(C.MarkerRights(), "noRights", "a raid member without leader or assist")
    m.isAssist = true
    -- red under: `not Compat.Leadership()` (reads only the first return: an assistant has no rights)
    assertEqual(C.MarkerRights(), "ok", "an assistant")
    m.isAssist, m.isLeader = false, true
    assertEqual(C.MarkerRights(), "ok", "the leader")
    m.isLeader, m.everyoneAssist = false, true
    assertEqual(C.MarkerRights(), "ok", "everyone is an assistant")
end)

test("compat: [CA-M1-R3] MarkerRights: a secret leader, assist or everyone-assistant answer is unknown, never noRights", function()
    local NS, m = T.newAddon()
    m.issecretvalue = T.isSecret
    local C = NS.Compat
    m.__context.inGroup, m.__context.inRaid = true, true
    m.isLeader = T.secret(true)
    -- red under: MarkerRights reading Leadership's plainTrue (a secret leader reads as no rights)
    assertNil(C.MarkerRights(), "a secret leader answer")
    m.isLeader, m.isAssist = false, T.secret(true)
    assertNil(C.MarkerRights(), "a secret assist answer")
    m.isAssist, m.everyoneAssist = false, T.secret(true)
    assertNil(C.MarkerRights(), "a secret everyone-assistant answer")
    m.isAssist = true
    assertEqual(C.MarkerRights(), "ok", "a plain assist answers ok whatever else is secret")
    m.isAssist, m.everyoneAssist = false, false
    assertEqual(C.MarkerRights(), "noRights", "every answer plainly false")
end)

-- ── the aura, GUID, friend and guild surfaces (CA-M4-1) ────────────────────────────────────────

test("mock: [CA-M4-1] the player's auras answer by instance id, their casters by GUID, and the helpful id list", function()
    local _, m = T.newAddon()
    assertEqual(#m.C_UnitAuras.GetUnitAuraInstanceIDs("player", "HELPFUL"), 0, "no aura by default")
    local a = m.addAura{ casterGUID = "Player-2-0000000A" }
    local b = m.addAura{ spellId = 21562, isHelpful = false }
    assertEqual(a.auraInstanceID, 1)
    assertEqual(b.auraInstanceID, 2)
    assertEqual(m.C_UnitAuras.GetAuraDataByAuraInstanceID("player", 1), a)
    assertNil(m.C_UnitAuras.GetAuraDataByAuraInstanceID("target", 1), "only the player's auras are modeled")
    assertEqual(m.C_UnitAuras.GetAuraCasterGUID("player", 1), "Player-2-0000000A")
    assertNil(m.C_UnitAuras.GetAuraCasterGUID("player", 2))
    local ids = m.C_UnitAuras.GetUnitAuraInstanceIDs("player", "HELPFUL")
    assertEqual(#ids, 1, "a harmful aura is not helpful")
    assertEqual(ids[1], 1)
    assertTrue(a.isFromPlayerOrPlayerPet)
    assertEqual(a.duration, 3600)
    local s = T.secret(5)
    m.auraInstanceIDs = { 1, s }
    assertTrue(T.isSecret(m.C_UnitAuras.GetUnitAuraInstanceIDs("player", "HELPFUL")[2]), "a planted secret is handed back")
end)

test("mock: [CA-M4-1] auraUpdate builds a UNIT_AURA payload, and secretAuraUpdate wraps it", function()
    local _, m = T.newAddon()
    local u = m.auraUpdate{ addedAuras = { { auraInstanceID = 3 } }, removedAuraInstanceIDs = { 1 } }
    assertFalse(u.isFullUpdate)
    assertEqual(u.addedAuras[1].auraInstanceID, 3)
    assertEqual(u.removedAuraInstanceIDs[1], 1)
    assertNil(u.updatedAuraInstanceIDs)
    assertTrue(m.auraUpdate{ isFullUpdate = true }.isFullUpdate)
    assertTrue(T.isSecret(m.secretAuraUpdate{ isFullUpdate = true }))
end)

test("mock: [CA-M4-1] GUIDs, player info, group, friend and guild answers are settable", function()
    local _, m = T.newAddon()
    assertEqual(m.UnitGUID("player"), m.playerGUID)
    assertNil(m.UnitGUID("target"))
    m.unitGUIDs.target = "Player-2-0000000B"
    assertEqual(m.UnitGUID("target"), "Player-2-0000000B")
    assertNil(m.GetPlayerInfoByGUID("Player-2-0000000B"))
    m.players["Player-2-0000000B"] = { name = "Bob", realm = "Argent Dawn", classToken = "MAGE" }
    local _, token, _, _, _, name, realm = m.GetPlayerInfoByGUID("Player-2-0000000B")
    assertEqual(token, "MAGE")
    assertEqual(name, "Bob")
    assertEqual(realm, "Argent Dawn")
    assertFalse(m.C_PartyInfo.IsGUIDInGroup("Player-2-0000000B"))
    assertFalse(m.C_FriendList.IsFriend("Player-2-0000000B"))
    assertFalse(m.IsGuildMember("Player-2-0000000B"))
    m.groupGUIDs["Player-2-0000000B"] = true
    m.friendGUIDs["Player-2-0000000B"] = true
    m.guildGUIDs["Player-2-0000000B"] = true
    assertTrue(m.C_PartyInfo.IsGUIDInGroup("Player-2-0000000B"))
    assertTrue(m.C_FriendList.IsFriend("Player-2-0000000B"))
    assertTrue(m.IsGuildMember("Player-2-0000000B"))
    assertEqual(m.SLASH_WHISPER1, "/w")
end)

test("mock: [CA-M4-1] every frame answers its alpha and whether the cursor is over it", function()
    local _, m = T.newAddon()
    local f = m.CreateFrame("Frame")
    assertEqual(f:GetAlpha(), 1)
    f:SetAlpha(0.5)
    assertEqual(f:GetAlpha(), 0.5)
    assertFalse(f:IsMouseOver())
    f.__mouseOver = true
    assertTrue(f:IsMouseOver())
end)

-- ── an aura's caster, the player's helpful auras and a whisper name (CA-M4-2, spec §9) ──────────

local STRANGER = "Player-2-0000000B"

local function stranger(m, fields)
    m.players[STRANGER] = { name = "Bob", realm = "Argent Dawn" }
    return m.addAura(fields or { casterGUID = STRANGER })
end

test("compat: [CA-M4-2] AuraCaster reads the caster's GUID first, then the aura's sourceUnit, and drops when neither reads", function()
    local NS, m = T.newAddon()
    m.issecretvalue = T.isSecret
    local C = NS.Compat
    local a = stranger(m)
    local c = C.AuraCaster(a.auraInstanceID, a)
    assertEqual(c.guid, STRANGER)
    assertEqual(c.name, "Bob")
    assertEqual(c.whisperName, "Bob-ArgentDawn")
    assertEqual(c.emoteName, "Bob", "the emote names the bare name (CA-THX-2)")
    assertFalse(c.known)
    local b = m.addAura{ sourceUnit = "target" }
    m.unitGUIDs.target = STRANGER
    -- red under: reading only GetAuraCasterGUID
    assertEqual(C.AuraCaster(b.auraInstanceID, b).guid, STRANGER, "the sourceUnit fallback")
    m.auraCasters[a.auraInstanceID] = T.secret(STRANGER)
    a.sourceUnit = nil
    assertNil(C.AuraCaster(a.auraInstanceID, a), "a secret GUID and no sourceUnit")
    m.unitGUIDs.target = nil
    assertNil(C.AuraCaster(b.auraInstanceID, b), "a sourceUnit with no GUID")
    assertNil(C.AuraCaster(b.auraInstanceID, T.secret(b)), "a secret aura is never indexed")
end)

test("compat: [CA-M4-2] AuraCaster rejects an NPC, a pet, the player and a group member (a secret answer reads as in group)", function()
    local NS, m = T.newAddon()
    m.issecretvalue = T.isSecret
    local C = NS.Compat
    local a = stranger(m)
    m.auraCasters[a.auraInstanceID] = "Creature-0-1-2-3-4-5"
    assertNil(C.AuraCaster(a.auraInstanceID, a), "an NPC")
    m.auraCasters[a.auraInstanceID] = "Pet-0-1-2-3-4-5"
    assertNil(C.AuraCaster(a.auraInstanceID, a), "a pet")
    m.auraCasters[a.auraInstanceID] = m.playerGUID
    m.players[m.playerGUID] = { name = "Testchar", realm = "" }
    assertNil(C.AuraCaster(a.auraInstanceID, a), "the player")
    m.auraCasters[a.auraInstanceID] = STRANGER
    m.groupGUIDs[STRANGER] = true
    assertNil(C.AuraCaster(a.auraInstanceID, a), "a group member")
    m.groupGUIDs[STRANGER] = T.secret(false)
    -- red under: plainTrue(IsGUIDInGroup) (a secret reads as not in group)
    assertNil(C.AuraCaster(a.auraInstanceID, a), "a secret group answer is the safe side")
    m.groupGUIDs[STRANGER] = nil
    assertEqual(C.AuraCaster(a.auraInstanceID, a).guid, STRANGER)
end)

test("compat: [CA-M4-2] AuraCaster drops an unreadable name, and marks a friend or a guildmate known", function()
    local NS, m = T.newAddon()
    m.issecretvalue = T.isSecret
    local C = NS.Compat
    local a = stranger(m)
    m.players[STRANGER].name = T.secret("Bob")
    assertNil(C.AuraCaster(a.auraInstanceID, a), "a secret name")
    m.players[STRANGER] = nil
    assertNil(C.AuraCaster(a.auraInstanceID, a), "no player info")
    m.players[STRANGER] = { name = "Bob", realm = "" }
    assertEqual(C.AuraCaster(a.auraInstanceID, a).whisperName, "Bob", "a same-realm stranger")
    m.friendGUIDs[STRANGER] = true
    assertTrue(C.AuraCaster(a.auraInstanceID, a).known, "a friend")
    m.friendGUIDs[STRANGER] = nil
    m.guildGUIDs[STRANGER] = true
    assertTrue(C.AuraCaster(a.auraInstanceID, a).known, "a guildmate")
    m.guildGUIDs[STRANGER] = T.secret(true)
    assertFalse(C.AuraCaster(a.auraInstanceID, a).known, "a secret guild answer is not known")
end)

test("compat: [CA-M4-2] AuraByInstance answers the player's plain aura, nil when secret or gone", function()
    local NS, m = T.newAddon()
    m.issecretvalue = T.isSecret
    local C = NS.Compat
    local a = m.addAura{}
    assertEqual(C.AuraByInstance(a.auraInstanceID), a)
    assertNil(C.AuraByInstance(99), "an expired aura")
    m.auras[a.auraInstanceID] = T.secret(a)
    assertNil(C.AuraByInstance(a.auraInstanceID), "a secret aura")
    m.C_UnitAuras = nil
    assertNil(C.AuraByInstance(a.auraInstanceID), "no API")
end)

test("compat: [CA-M4-2] HelpfulAuraIds lists the player's helpful aura ids, nil when any is secret", function()
    local NS, m = T.newAddon()
    m.issecretvalue = T.isSecret
    local C = NS.Compat
    assertEqual(#C.HelpfulAuraIds(), 0)
    m.addAura{}
    m.addAura{}
    local ids = C.HelpfulAuraIds()
    assertEqual(#ids, 2)
    assertEqual(ids[1], 1)
    assertEqual(ids[2], 2)
    m.auraInstanceIDs = { 1, T.secret(2) }
    -- red under: skipping a secret element (the snapshot would miss an aura and toast it later)
    assertNil(C.HelpfulAuraIds(), "a secret element")
    m.auraInstanceIDs = T.secret({ 1 })
    assertNil(C.HelpfulAuraIds(), "a secret list")
    m.C_UnitAuras = nil
    assertNil(C.HelpfulAuraIds(), "no API")
end)

test("compat: [CA-M4-2] WhisperName is Name-Realm with the realm normalized, the name alone on the same realm", function()
    local NS = T.newAddon()
    local C = NS.Compat
    assertFalse(C.RegionalNames())
    assertEqual(C.WhisperName("Bob", "Argent Dawn"), "Bob-ArgentDawn")
    assertEqual(C.WhisperName("Bob", "Azjol-Nerub"), "Bob-AzjolNerub")
    assertEqual(C.WhisperName("Bob", ""), "Bob")
    assertNil(C.WhisperName("Bob", nil), "an unreadable realm")
    assertNil(C.WhisperName(T.secret("Bob"), ""), "a secret name")
    assertNil(C.WhisperName("", ""), "an empty name")
end)

test("compat: [CA-M4-2] WhisperName with regional names is First-Surname, whatever the realm", function()
    local NS, m = T.newAddon()
    m.RegionalUniqueNamesEnabled = function() return true end
    local C = NS.Compat
    assertTrue(C.RegionalNames())
    -- red under: choosing the form by the client rather than by Compat.RegionalNames()
    assertEqual(C.WhisperName("Traxex Silentshot", "Anything"), "Traxex-Silentshot")
    assertEqual(C.WhisperName("Solo", nil), "Solo", "a name with no surname")
end)
