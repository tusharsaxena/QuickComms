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
