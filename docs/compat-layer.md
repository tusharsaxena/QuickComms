# Compat layer — Ka0s Quick Comms

`core/Compat.lua` is the only file that names a version-variant, deprecated or optional client API
(compat). Feature modules call `NS.Compat.X`; none reads those client globals itself. It loads in
`# Core` right after `core/CoreSetup.lua`, needs `LibStub` (optional) at
load, and is read inside functions only. There is one family file; no `core/Compat<Topic>.lua`
exists.

**Thirty-one shims**, counted the way documentation-§3 counts them
(`cat core/Compat*.lua | grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.'` answers `31`, recounted
2026-10-25), one row each below. The two
secret guards, `IsSecret` and `IsSafeKey`, are `LibKa0s-Compat-1.0`'s members, wired by assignment
with a library-absent body and not counted; their contract is LibKa0s
`docs/api/Compat/version-1-docs.md`.

## The rules every shim keeps

- Client globals are read **bare, at call time**, never captured at load.
- A value that may be secret meets nothing but `IsSecret` (or `type()`) before it is compared,
  matched or concatenated. Every reader returns a plain value or nil (or a documented absent
  value), never a secret.
- A restriction answer that is secret reads as **active** or **locked**: the client is restricting
  something, so the addon never assumes it is free.
- A missing API never raises; each shim answers its absent value, listed below.

## The shims

| Shim | Wraps | Secret handling | Absent answer | Callers |
|---|---|---|---|---|
| `PlainNumber(v)` | none (pure) | a secret or non-number is `nil` | `nil` | the shims below |
| `PlainString(v)` | none (pure) | a secret or non-string is `nil` | `nil` | the shims below |
| `InstanceInfo()` | `IsInInstance`, `GetInstanceInfo` | each field plain or `nil` | `false, nil, nil, nil` | `Situation` |
| `ActiveKeystone()` | `C_ChallengeMode.IsChallengeModeActive`, `GetActiveKeystoneInfo`, `GetActiveChallengeMapID` | plain number or `nil`; a secret flag is `false` | `false, nil, nil` | `Situation` |
| `GroupShape()` | `IsInGroup`, `IsInRaid`, `LE_PARTY_CATEGORY_INSTANCE` | a secret flag is `false` | `false, false, false` | `Situation` |
| `Leadership()` | `UnitIsGroupLeader`, `UnitIsGroupAssistant` | a secret flag is `false` | `false, false` | `Situation` |
| `PlayerIdentity()` | `UnitClass`, `C_SpecializationInfo` (else `GetSpecialization*`), `UnitGroupRolesAssigned`, `UnitFullName`, `GetNormalizedRealmName` | each field plain or `nil`; a role of `NONE` falls back to the spec's role | `nil` per field | `Situation` |
| `InHousing()` | `C_Housing.IsInsideHouseOrPlot` | a secret answer is `false` | `false` | `Situation` |
| `InCombat()` | `InCombatLockdown` | none (a plain boolean) | `false` | `Situation`, `Restrictions`, `SendEngine`, `Preview`, `Pad`, `IconBrowser` (Choose is refused in combat) |
| `InChatMessagingLockdown()` | `C_ChatInfo.InChatMessagingLockdown` | a secret answer reads as **locked** | `false` | `Restrictions` |
| `RestrictionTypes()` | `Enum.AddOnRestrictionType` | none | `{}` | `Restrictions` |
| `IsRestrictionStateActive(state)` | `Enum.AddOnRestrictionState` (anything but `Inactive` is active, so `Activating` counts; a boolean answers itself) | a secret state is **active** | `false` for nil | `Restrictions` |
| `IsRestrictionActive(rtype)` | `C_RestrictedActions.IsAddOnRestrictionActive`, else `GetAddOnRestrictionState` | a secret answer is **active** | `false` | `Restrictions` |
| `UseKeyDown()` | the `ActionButtonUseKeyDown` cvar (`C_CVar.GetCVarBool`, else `GetCVarBool`) | a secret answer is `true` | `true` | `SendEngine` (the acting click edge) |
| `SenderIsPlayer(sender, guid)` | `UnitGUID`, `UnitFullName` / `UnitName`, `GetNormalizedRealmName` | a secret GUID or name is unreadable; neither readable answers `nil` (unknown, never a drop). Without the GUID the full name decides: a cross-realm namesake is `false`, and a sender with a realm when the player's realm cannot be read is `nil` | `nil` | `SendEngine` (the echo tracker) |
| `PlayerName()` | `UnitName` | plain or `nil` | `nil` | `Surfaces` (bakes `{me}`) |
| `UnitDisplayName(unit)` | `UnitExists`, `UnitName` | the name without the realm, plain or `nil`; an empty name is `nil`; reads only, so a click in combat may call it | `nil` (no such unit, or either API absent) | `Preview` (the click preview's `%t` and `%f`, QC-07) |
| `SpecName()` | `C_SpecializationInfo.GetSpecializationInfo`, else `GetSpecializationInfo` | plain or `nil` | `nil` | `Surfaces` (bakes `{spec}`) |
| `DungeonName(mapID)` | `C_ChallengeMode.GetMapUIInfo` | plain or `nil` | `nil` | `Surfaces` (bakes `{dungeon}`), `Pad` (the situation chip) |
| `SpellLink(id)` | `C_Spell.GetSpellLink` | plain or `nil` | `nil` | `Surfaces` (bakes `{spell:ID}`) |
| `GeneralJoined()` | `C_ChatInfo.GetGeneralChannelLocalID` (true only when it answers a plain 1: the zone General channel is `/1`; never the channel's localized name) | a secret id is not General | `false` (no API or no `C_ChatInfo`; General not joined (nil) or not at `/1`) | `Situation` (the snapshot's `general`, which `Channels.Resolve` reads for the `general` kind) (QF-04) |
| `PlayerMapPosition()` | `C_Map.GetBestMapForUnit("player")`, `C_Map.GetPlayerMapPosition(mapID, "player")`, its `GetXY` | every value plain; a secret map id, position or coordinate is `nil`; 0, 0 is `nil` | `nil` (no `C_Map`, no map, a restricted map such as an instance) | `Coordinates` |
| `Coordinates()` | `PlayerMapPosition` | `"45.2, 61.8"` (x, y in percent, one decimal) or `nil`; reads only, so a click in combat may call it | `nil` | `Surfaces` (bakes `{coordinates}`, and its press-time re-bake), `Preview` (the echo, filled at the click) (QF-03) |
| `InstanceName(id)` | `GetRealZoneText` | plain or `nil`; an empty name is `nil` | `nil` | `Preview`, `GroupsWhen` |
| `SpecInfoByID(id)` | `GetSpecializationInfoByID` | name and icon plain or `nil` | `nil` | `GroupsWhen` |
| `ClassName(classFile)` | `LOCALIZED_CLASS_NAMES_MALE` | an unsafe key or a secret name is `nil` | `nil` | `GroupsWhen` |
| `BindingKey(command)` | `GetBindingKey` | an unsafe command, or a secret or empty key, is `nil` | `nil` | `modules/Dial.lua` (`KeyOf`: a dial's key, set in Options → Keybindings or on General → Keybindings), `modules/Diagnostics.lua` |
| `ScreenSize()` | `UIParent:GetWidth`, `GetHeight` | either one secret, unknown or not positive is `nil` | `nil` | `Library` (an offset off the screen is refused) |
| `ChatColor(chatType)` | `ChatTypeInfo` | an unsafe key, or a secret or missing color component, is `nil` | `nil` | `Pad_Render` (a button's channel in its tooltip; a callout row's channel) |
| `HasTemplate(name)` | `C_XMLUtil.GetTemplateInfo` | `type()` only: a table answer is `true`, anything else (or a raise) `false` | `nil` (unknown: the caller tries `CreateFrame` under `pcall`) | `settings/ModalWindow.lua` (whether to build the callout popup's and the icon browser's window from `SettingsFrameTemplate`) |
| `MacroIcons(kind)` | `GetLooseMacroIcons` then `GetMacroIcons` (`"spells"`), `GetLooseMacroItemIcons` then `GetMacroItemIcons` (`"items"`), in the order Blizzard's IconDataProvider reads them, each filling the table it is handed (or returning one); a reader that is absent or raises adds nothing | each entry through `PlainNumber`: a secret or non-number entry is dropped | `{}` (the reader absent or raising, an unknown kind, or the client's list not loaded yet) | `settings/IconBrowser_Sources.lua` (the Game icons tab) |

The restriction shims are copied from DropWatcher's `core/Compat.lua`. LibKa0s#49 deferred them;
see `ARCHITECTURE.md` -> `## Documented deviations`. `tests/test_compat.lua` drives the plain
readers (secrets dropped, a secret `instanceID` read as `nil`) and the restriction readers.
