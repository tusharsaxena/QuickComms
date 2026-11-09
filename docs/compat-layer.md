# Compat layer — Ka0s Quick Comms

`core/Compat.lua` is the only file that names a version-variant, deprecated or optional client API
(compat). Feature modules call `NS.Compat.X`; none reads those client globals itself. It loads in
`# Core` right after `core/CoreSetup.lua`, needs `LibStub` (optional) at
load, and is read inside functions only. There is one family file; no `core/Compat<Topic>.lua`
exists.

**Thirty-two shims**, counted the way documentation-§3 counts them
(`cat core/Compat*.lua | grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.'` answers `32`, recounted
2026-11-01), one row each below. The two
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
| `PlayerIdentity()` | `UnitClass`, LibKa0s Role (`Spec`, `Resolve`), `CharacterKey()` below | classFile, specID, role, character, then the role's source and detail; each plain or `nil` | `nil` per field | `Situation` |
| `RegionalNames()` | LibKa0s Compat `RegionalNames` (`RegionalUniqueNamesEnabled`) | none | `false` (Name-Realm forms) | `CharacterKey`, `SenderIsPlayer`, the When editor's Character row |
| `CharacterKey()` | with regional names LibKa0s Compat `CharacterKey` ("First Surname"); otherwise `UnitFullName`, `GetNormalizedRealmName` ("Name-Realm", the form saved Whens hold) | plain or `nil` | `nil` | `PlayerIdentity` |
| `PlayerRole()` / `AutomaticRole()` | LibKa0s Role `Resolve` over `db.char.role` (`RoleStore()`); `AutomaticRole` sets the pick aside on a copy | role, source, detail | the pick, `UnitGroupRolesAssigned`, then the spec's role | `PlayerIdentity`, the Role row |
| `RoleOverride()` / `SetRoleOverride(role)` | LibKa0s Role `SetOverride` | an unknown role is refused (`false`) | `store.override` written directly | the Role row (`settings/Schema.lua` `CHAR`) |
| `SpecsForClass(classFile)` | LibKa0s Role `SpecsForClass` (`GetNumSpecializationsForClassID` / `GetSpecializationInfoForClassID`) | ids plain and positive | `{}` (the editor falls back to `GameIds.SPECS`) | the When editor's Specialization row |
| `InHousing()` | `C_Housing.IsInsideHouseOrPlot` | a secret answer is `false` | `false` | `Situation` |
| `InCombat()` | `InCombatLockdown` | none (a plain boolean) | `false` | `Situation`, `Restrictions`, `SendEngine`, `Preview`, `Pad`, `IconBrowser` (Choose is refused in combat) |
| `InChatMessagingLockdown()` | `C_ChatInfo.InChatMessagingLockdown` | a secret answer reads as **locked** | `false` | `Restrictions` |
| `RestrictionTypes()` | `Enum.AddOnRestrictionType` | none | `{}` | `Restrictions` |
| `IsRestrictionStateActive(state)` | `Enum.AddOnRestrictionState` (anything but `Inactive` is active, so `Activating` counts; a boolean answers itself) | a secret state is **active** | `false` for nil | `Restrictions` |
| `IsRestrictionActive(rtype)` | `C_RestrictedActions.IsAddOnRestrictionActive`, else `GetAddOnRestrictionState` | a secret answer is **active** | `false` | `Restrictions` |
| `UseKeyDown()` | the `ActionButtonUseKeyDown` cvar (`C_CVar.GetCVarBool`, else `GetCVarBool`) | a secret answer is `true` | `true` | `SendEngine` (the acting click edge) |
| `SenderIsPlayer(sender, guid)` | `UnitGUID`, `UnitFullName` / `UnitName`, `GetNormalizedRealmName`; with regional names LibKa0s Compat `UnitCharacterName` | a secret GUID or name is unreadable; neither readable answers `nil` (unknown, never a drop). Without the GUID the full name decides: a cross-realm namesake is `false`, and a sender with a realm when the player's realm cannot be read is `nil`; with regional names the sender must equal the player's "First Surname" | `nil` | `SendEngine` (the echo tracker) |
| `PlayerName()` | LibKa0s Compat `UnitCharacterName` (else `UnitName`) | plain or `nil`; "First Surname" with regional names | `nil` | `Surfaces` (bakes `{me}`) |
| `UnitDisplayName(unit)` | `UnitExists`, LibKa0s Compat `UnitCharacterName` (else `UnitName`) | the name without the realm ("First Surname" with regional names), plain or `nil`; an empty name is `nil`; reads only, so a click in combat may call it | `nil` (no such unit, or either API absent) | `Preview` (the click preview's `%t` and `%f`, QC-07) |
| `SpecName()` | LibKa0s Role `Spec` (else `C_SpecializationInfo.GetSpecializationInfo`, then `GetSpecializationInfo`) | plain or `nil` | `nil` | `Surfaces` (bakes `{spec}`) |
| `DungeonName(mapID)` | `C_ChallengeMode.GetMapUIInfo` | plain or `nil` | `nil` | `Surfaces` (bakes `{dungeon}`), `Pad` (the situation chip) |
| `SpellLink(id)` | `C_Spell.GetSpellLink` | plain or `nil` | `nil` | `Surfaces` (bakes `{spell:ID}`) |
| `GeneralJoined()` | `C_ChatInfo.GetGeneralChannelLocalID` (true only when it answers a plain 1: the zone General channel is `/1`; never the channel's localized name) | a secret id is not General | `false` (no API or no `C_ChatInfo`; General not joined (nil) or not at `/1`) | `Situation` (the snapshot's `general`, which `Channels.Resolve` reads for the `general` kind) (QF-04) |
| `FrameStrata(frame, fallback)` | `frame:GetFrameStrata()` | a secret strata (WoW Forever), a non-string or a frame with no reader is `fallback` | `fallback` | `AnimGhost` (the ghost takes the dial's strata, else `HUD_POPUP`), `ModalWindow` (`LiftConfirm` keeps the strata a confirm came in, else Blizzard's `DIALOG`) (QFE-F1) |
| `PlayerMapPosition()` | `C_Map.GetBestMapForUnit("player")`, `C_Map.GetPlayerMapPosition(mapID, "player")`, its `GetXY` | every value plain; a secret map id, position or coordinate is `nil`; 0, 0 is `nil` | `nil` (no `C_Map`, no map, a restricted map such as an instance) | `Coordinates` |
| `Coordinates()` | `PlayerMapPosition` | `"45.2, 61.8"` (x, y in percent, one decimal) or `nil`; reads only, so a click in combat may call it | `nil` | `Surfaces` (bakes `{coordinates}`, and its press-time re-bake), `Preview` (the echo, filled at the click) (QF-03) |
| `InstanceName(id)` | `GetRealZoneText` | plain or `nil`; an empty name is `nil` | `nil` | `Preview`, `GroupsWhen` |
| `SpecInfoByID(id)` | `GetSpecializationInfoByID` | name and icon plain or `nil` | `nil` | `GroupsWhen` |
| `ClassName(classFile)` | `LOCALIZED_CLASS_NAMES_MALE` | an unsafe key or a secret name is `nil` | `nil` | `GroupsWhen` |
| `BindingKey(command)` | `GetBindingKey` | an unsafe command, or a secret or empty key, is `nil` | `nil` | `modules/Dial.lua` (`KeyOf`: a dial's key, set in Options → Keybindings or on General → Keybindings), `modules/Diagnostics.lua` |
| `ScreenSize()` | `UIParent:GetWidth`, `GetHeight` | either one secret, unknown or not positive is `nil` | `nil` | `Library` (an offset off the screen is refused) |
| `ChatColor(chatType)` | `ChatTypeInfo` | an unsafe key, or a secret or missing color component, is `nil` | `nil` | `Pad_Render` (a button's channel in its tooltip; a callout row's channel) |
| `HasTemplate(name)` | `C_XMLUtil.GetTemplateInfo` | `type()` only: a table answer is `true`, anything else (or a raise) `false` | `nil` (unknown: the caller tries `CreateFrame` under `pcall`) | `settings/ModalWindow.lua` (whether to build the callout popup's window from `SettingsFrameTemplate`; the icon browser's window is LibKa0s-IconBrowser-1.0's since v1.86.0, which asks the client itself) |
| `VertexScaleAnimation(fs)` | `Enum.FontStringScaleAnimationMode.Vertex`, `FontString:SetScaleAnimationMode` (12.0), `CreateAnimationGroup`, a Scale animation's setters | none: it reads no game state and passes a plain Enum constant | `nil` when any piece is missing: the string fades in place | `AnimGhost` |

The restriction shims are copied from DropWatcher's `core/Compat.lua`. LibKa0s#49 deferred them;
see `ARCHITECTURE.md` -> `## Documented deviations`. `tests/test_compat.lua` drives the plain
readers (secrets dropped, a secret `instanceID` read as `nil`) and the restriction readers.
