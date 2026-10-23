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

-- The SavedVariables write targets and the Blizzard tables the addon writes to.
globals = {
  "QuickCommsDB",       -- AceDB
  "QuickCommsPerfDB",   -- the diagnostics capture ring (performance-§5)
  "StaticPopupDialogs",
  -- settings/ModalWindow.lua: Escape closes the callout popup and the icon browser (special frames,
  -- by name); settings/IconBrowser.lua lifts the popup's out while the browser is open.
  "UISpecialFrames",
  -- modules/Dial.lua: the key bindings menu's header for Bindings.xml, which the client reads by this
  -- name (spec §9.4). Its four entry labels hold a space and a colon, so they are rawset beside a
  -- comment instead of declared here.
  "BINDING_HEADER_QUICKCOMMS",
}

read_globals = {
  "_G", "LibStub", "C_AddOns",
  "STANDARD_TEXT_FONT",
  "InCombatLockdown", "debugprofilestop",
  "Settings", "StaticPopup_Show", "YES", "NO",
  -- core/Compat.lua: the client readers, all guarded for absence at call time.
  "issecretvalue", "C_ChallengeMode", "C_Map", "C_Spell", "C_Housing", "C_SpecializationInfo", "GetInstanceInfo",
  "GetNormalizedRealmName", "GetSpecialization", "GetSpecializationInfo", "IsInGroup", "IsInInstance",
  "IsInRaid", "LE_PARTY_CATEGORY_INSTANCE", "UnitClass", "UnitFullName", "UnitGroupRolesAssigned",
  "UnitIsGroupAssistant", "UnitIsGroupLeader",
  -- modules/Restrictions.lua via core/Compat.lua: the 12.0 restriction APIs.
  "C_ChatInfo", "C_RestrictedActions", "Enum",
  -- modules/SendEngine.lua: the secure frame API (the firewall test keeps it in that one file).
  "CreateFrame", "UIParent", "RegisterStateDriver", "UnregisterStateDriver", "GetTime",
  "C_CVar", "GetCVarBool", "UnitGUID", "UnitName", "UnitExists",
  -- modules/Pad_Render.lua and core/Compat.lua: the button tooltip and the chat colors.
  "GameTooltip", "ChatTypeInfo",
  -- settings/Editors.lua: the color picker a swatch of ours opened goes with the swatch.
  "ColorPickerFrame",
  -- modules/Pad.lua: the sent-button sound.
  "PlaySound", "SOUNDKIT",
  -- modules/Dial_Render.lua: the pointer follows the cursor.
  "GetCursorPosition",
  -- core/Compat.lua: whether chat channel 1 (General) is joined (QF-04).
  "GetChannelName",
  -- core/Compat.lua: the editors' display names (shown, never matched).
  "GetRealZoneText", "GetSpecializationInfoByID", "LOCALIZED_CLASS_NAMES_MALE",
  -- core/Compat.lua: a dial's key is WoW's own binding of its Open Comms Dial entry: read, set, saved
  -- (the action a key had before, shown when the key is taken from it).
  "GetBindingAction", "GetBindingKey", "SetBinding", "SaveBindings", "GetCurrentBindingSet",
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

-- EllesmereUI (## OptionalDeps), read only by its bridge: lint keeps every other file off it.
files["core/EUIBridge.lua"] = {
  read_globals = { "EllesmereUI" },
}

-- Compat.HasTemplate: whether the client has an XML template (the callout popup's window). Scoped
-- here so no feature file reads it directly (compat).
-- Compat.MacroIcons: the macro icon selector's lists (the icon browser's Game icons tab).
files["core/Compat.lua"] = {
  read_globals = { "C_XMLUtil", "GetMacroIcons", "GetMacroItemIcons", "GetLooseMacroIcons",
    "GetLooseMacroItemIcons" },
}

-- QC:SlashEnabled and QC:OnSlashCommand are methods on the addon object by calling convention;
-- neither body reads the receiver.
files["settings/Slash.lua"] = {
  ignore = { "212/self" },
}
