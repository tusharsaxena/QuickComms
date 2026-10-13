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
    assertTrue(C.SenderIsPlayer("Testchar-Testrealm", nil), "the name, realm stripped")
    assertFalse(C.SenderIsPlayer("Other-Testrealm", nil))
    assertNil(C.SenderIsPlayer(T.secret("Testchar"), T.secret("guid")), "secret is unknown")
    assertNil(C.SenderIsPlayer(nil, nil))
end)
