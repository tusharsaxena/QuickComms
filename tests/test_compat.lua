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
