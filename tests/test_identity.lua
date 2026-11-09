-- tests/test_identity.lua — the player's identity on both clients (QFE-F4, the Forever port design
-- §4.4): the character key and names through LibKa0s Compat's name helpers (Name-Realm on Retail,
-- "First Surname" where names are unique per region, as on WoW Forever), the role through LibKa0s
-- Role over this character's db.char.role, the General page's Role row, the spec row's list, and the
-- role's source in /qc why and the diagnostics. Regional names are switched on per case by the
-- client's own feature test (RegionalUniqueNamesEnabled), never by the kit profile, so every case
-- runs the same under both.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

-- WoW Forever's name shape: names unique per region, UnitName's second value the surname.
local function regional(env, first, surname)
    env.RegionalUniqueNamesEnabled = function() return true end
    env.UnitNameUnmodified = nil
    env.UnitName = function(unit)
        if unit == "player" then return first, surname end
        if unit == "target" then return "Other", "Person" end
        return nil
    end
end

local function roleLib(m) return m.LibStub("LibKa0s-Role-1.0") end

local function report(NS)
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    return table.concat(NS.DebugLog.buffer, "\n")
end

-- ── names ───────────────────────────────────────────────────────────────────────────────────

test("identity: without regional names the character is Name-Realm and the names carry no realm", function()
    local NS, env = T.newAddon()
    env.UnitFullName = function() return "Kaos", "Silvermoon" end
    env.UnitName = function() return "Kaos", "Silvermoon" end
    local C = NS.Compat
    assertFalse(C.RegionalNames())
    assertEqual(C.CharacterKey(), "Kaos-Silvermoon")
    local _, _, _, character = C.PlayerIdentity()
    assertEqual(character, "Kaos-Silvermoon", "the form every saved When holds")
    -- red under: PlayerName joining UnitName's second value
    assertEqual(C.PlayerName(), "Kaos")
end)

test("identity: with regional names the character, {me} and a unit are First Surname, never a realm", function()
    local NS, env = T.newAddon()
    regional(env, "Traxex", "Silentshot")
    env.UnitFullName = function() return "Traxex", "Silentshot" end   -- its second value is the surname
    env.GetNormalizedRealmName = function() return "Ignored" end
    env.__unitExists.target = true
    local C = NS.Compat
    assertTrue(C.RegionalNames())
    -- red under: PlayerIdentity reading UnitFullName ("Traxex-Silentshot")
    local _, _, _, character = C.PlayerIdentity()
    assertEqual(character, "Traxex Silentshot")
    assertEqual(C.PlayerName(), "Traxex Silentshot")
    assertEqual(C.UnitDisplayName("target"), "Other Person")
    regional(env, "Solo", nil)
    assertEqual(C.CharacterKey(), "Solo", "no surname: the first name alone")
end)

test("identity: with regional names a chat sender is the player by the long form alone", function()
    local NS, env = T.newAddon()
    regional(env, "Traxex", "Silentshot")
    local C = NS.Compat
    assertTrue(C.SenderIsPlayer("Someone Else", env.playerGUID), "the GUID still decides first")
    -- red under: split the sender on whitespace or a hyphen and compare the first name
    assertTrue(C.SenderIsPlayer("Traxex Silentshot", nil))
    assertFalse(C.SenderIsPlayer("Traxex", nil), "a first name alone is someone else")
    assertFalse(C.SenderIsPlayer("Traxex Other", nil))
    env.UnitName = function() return nil end
    assertNil(C.SenderIsPlayer("Traxex Silentshot", nil), "the player's name unreadable: unknown")
end)

test("identity: the When editor takes and shows the long form where names are regional", function()
    local NS, env = T.newAddon()
    local W = NS.addon.Settings.GroupsWhen
    assertEqual(W.Tip("characters"), "Specific characters, as Name-Realm.")
    regional(env, "Traxex", "Silentshot")
    -- red under: W.CharacterId refusing a space (Retail's Name-Realm rule)
    assertEqual(W.CharacterId("  traxex   silentshot ", {}), "Traxex Silentshot")
    assertEqual(W.CharacterId("Traxex", {}), "Traxex")
    assertNil(W.CharacterId("Traxex-Area52", {}), "no realm on a regional client")
    assertNil(W.CharacterId("one two three", {}))
    assertNil(W.CharacterId("", {}))
    assertEqual(W.Tip("characters"), "Specific characters, by first name and surname.")
    local _, why = W.ResolveValue("characters", "a-b")
    assertEqual(why, "A character is a first name and surname.")
    assertTrue((NS.Resolver.Matches({ characters = { ["traxex silentshot"] = true } },
        { character = "Traxex Silentshot" })), "matched without regard to case")
end)

-- ── the role ────────────────────────────────────────────────────────────────────────────────

test("identity: the role is LibKa0s Role's answer over db.char.role; an override wins and is saved", function()
    local NS, env = T.bootAddon()
    local C = NS.Compat
    env.UnitGroupRolesAssigned = function() return "HEALER" end
    local _, _, role, _, source = C.PlayerIdentity()
    assertEqual(role, "HEALER")
    assertEqual(source, "assigned")
    assertEqual(NS.db.char.role.last.role, "HEALER", "the library saves the last answer per character")
    assertTrue(C.SetRoleOverride("TANK"))
    assertEqual(NS.db.char.role.override, "TANK")
    _, _, role, _, source = C.PlayerIdentity()
    assertEqual(role, "TANK")
    assertEqual(source, "override")
    local auto, autoSource = C.AutomaticRole()
    assertEqual(auto, "HEALER", "Automatic sets the pick aside")
    assertEqual(autoSource, "assigned")
    assertEqual(NS.db.char.role.override, "TANK", "and keeps it")
    assertFalse(C.SetRoleOverride("BOGUS"))
    assertTrue(C.SetRoleOverride(nil))
    assertNil(C.RoleOverride())
end)

test("identity: the snapshot carries the role's source and detail; the signature does not", function()
    local NS, _, m = T.bootAddon()
    roleLib(m).Resolve = function() return "TANK", "talents", "Protection" end
    NS.Situation.RefreshNow("test")
    local s = NS.Situation.Current()
    assertEqual(s.role, "TANK")
    assertEqual(s.roleSource, "talents")
    assertEqual(s.roleDetail, "Protection")
    local sig = NS.Situation.Signature(s)
    roleLib(m).Resolve = function() return "TANK", "spec", "Protection" end
    NS.Situation.RefreshNow("test")
    -- red under: roleSource in SIGNATURE_FIELDS
    assertEqual(NS.Situation.Signature(NS.Situation.Current()), sig)
    assertEqual(NS.Situation.DescribeRole("TANK", "talents", "Protection"), "Tank, from your talents: Protection")
    assertEqual(NS.Situation.DescribeRole("HEALER", "override"), "Healer, your choice on the General page")
    assertEqual(NS.Situation.DescribeRole(nil), "not known yet")
end)

test("identity: without LibKa0s Role the role still reads: the pick, the group's, then the spec's", function()
    local NS, env = T.bootAddon({ skip = { "libs/LibKa0s/Role.lua" } })
    local C = NS.Compat
    env.UnitGroupRolesAssigned = function() return "NONE" end
    env.C_SpecializationInfo = {
        GetSpecialization = function() return 1 end,
        GetSpecializationInfo = function() return 73, "Protection", "", 0, "TANK" end,
    }
    local _, specID, role, _, source, detail = C.PlayerIdentity()
    assertEqual(specID, 73)
    assertEqual(role, "TANK")
    assertEqual(source, "spec")
    assertEqual(detail, "Protection")
    assertTrue(C.SetRoleOverride("DAMAGER"))
    _, _, role, _, source = C.PlayerIdentity()
    assertEqual(role, "DAMAGER")
    assertEqual(source, "override")
end)

-- ── the Role row ────────────────────────────────────────────────────────────────────────────

test("identity: the General page's Role row writes this character's pick and refreshes the situation", function()
    local NS, env = T.enableAddon()
    local S = NS.SchemaRuntime
    env.UnitGroupRolesAssigned = function() return "HEALER" end
    NS.Situation.RefreshNow("test")
    assertEqual(S.Get("role"), "auto")
    local row = S.FindRow("role")
    assertEqual(row.page, "general")
    assertEqual(row.subgroup, "Your role")
    local values = row.values()
    assertEqual(values[1].value, "auto")
    -- red under: a static Automatic label
    assertEqual(values[1].text, "Automatic (Healer, the role your group gave you)")
    assertTrue(row.tooltip:find("Automatic now: Healer, the role your group gave you.", 1, true) ~= nil, row.tooltip)
    assertTrue((S.Set("role", "TANK")))
    assertEqual(NS.db.char.role.override, "TANK")
    assertEqual(S.Get("role"), "TANK")
    -- red under: a pick that waits for the next situation event
    assertEqual(NS.Situation.Current().role, "TANK")
    assertEqual(NS.Situation.Current().roleSource, "override")
    assertFalse((S.Set("role", "BOGUS")), "a choice the row does not list is refused")
    NS.addon.db:SetProfile("Other")
    assertEqual(S.Get("role"), "TANK", "per character: a profile switch leaves it")
    assertTrue((S.Set("role", "auto")))
    assertNil(NS.db.char.role.override)
    assertEqual(NS.Situation.Current().role, "HEALER")
    assertNil(NS.addon.db.profile.role, "never a profile key")
end)

test("identity: /qc why opens with the role and where it came from; the diagnostics print both", function()
    local NS, _, m = T.enableAddon()
    roleLib(m).Resolve = function() return "TANK", "talents", "Protection" end
    NS.Situation.RefreshNow("test")
    m.prints = {}
    NS.addon:OnSlashCommand("why")
    -- red under: WhyLines without the role line
    assertTrue(m.prints[1]:find("Your role: Tank, from your talents: Protection.", 1, true) ~= nil, m.prints[1])
    local text = report(NS)
    assertTrue(text:find("role=TANK", 1, true) ~= nil, text)
    assertTrue(text:find("roleSource=talents roleDetail=Protection override=auto", 1, true) ~= nil, text)
end)

-- ── the spec row ────────────────────────────────────────────────────────────────────────────

test("identity: the spec row lists the client's specs through LibKa0s Role, else the shipped seed", function()
    local NS, _, m = T.bootAddon()
    local W = NS.addon.Settings.GroupsWhen
    local seeded = W.Values("spec", { class = { WARRIOR = true } })
    assertEqual(#seeded, #NS.GameIds.SPECS.WARRIOR, "nothing from the client: GameIds.SPECS")
    roleLib(m).SpecsForClass = function(cf)
        if cf == "WARRIOR" then return { { id = 1001, name = "Warrior", role = "DAMAGER" } } end
        return {}
    end
    -- red under: specValues reading NS.GameIds.SPECS alone (Forever's one spec per class unlisted)
    local live = W.Values("spec", { class = { WARRIOR = true } })
    assertEqual(#live, 1)
    assertEqual(live[1].value, 1001)
    assertEqual(live[1].text, "Warrior")
end)
