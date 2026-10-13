-- .luacheckrc — lint config for Ka0s Quick Comms (lint).
-- `luacheck .` must report 0 warnings / 0 errors before every commit.

std = "lua51"
max_line_length = false
codes = true

-- libs/ is vendored (LibKa0s is linted in its own repo); tests/_kit/ is a byte copy of the
-- library's testkit/. Under docs/ only the frozen bundle stores are excluded. Everything else under
-- tests/ is ours and is linted. docs/brainstorm/ holds the go/no-go harness, a throwaway addon kept
-- as history and never loaded by this one.
exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "docs/revendor/", "docs/brainstorm/", "_dev/",
  "tests/_kit/" }

-- No top-level `ignore`: a blanket suppression reaches every file (lint).

-- The SavedVariables write targets and the one Blizzard table the addon writes to.
globals = {
  "QuickCommsDB",       -- AceDB
  "QuickCommsPerfDB",   -- the diagnostics capture ring (performance-§5)
  "StaticPopupDialogs",
}

read_globals = {
  "_G", "LibStub", "C_AddOns",
  "STANDARD_TEXT_FONT",
  "InCombatLockdown", "debugprofilestop",
  "Settings", "StaticPopup_Show", "YES", "NO",
  -- core/Compat.lua: the client readers, all guarded for absence at call time.
  "issecretvalue", "C_ChallengeMode", "C_Housing", "C_SpecializationInfo", "GetInstanceInfo",
  "GetNormalizedRealmName", "GetSpecialization", "GetSpecializationInfo", "IsInGroup", "IsInInstance",
  "IsInRaid", "LE_PARTY_CATEGORY_INSTANCE", "UnitClass", "UnitFullName", "UnitGroupRolesAssigned",
  "UnitIsGroupAssistant", "UnitIsGroupLeader",
}

-- The harness global, declared for tests/ only so no shipped file can reach for it. The
-- SavedVariables names are cleared by tests/loader.lua before each instance.
files["tests/"] = {
  globals = {
    "_G.QUICKCOMMS_TEST",
    "_G.QuickCommsDB",
    "_G.QuickCommsPerfDB",
  },
}

-- QC:SlashEnabled and QC:OnSlashCommand are methods on the addon object by calling convention;
-- neither body reads the receiver.
files["settings/Slash.lua"] = {
  ignore = { "212/self" },
}
