# Compat layer — Ka0s Quick Comms

`core/Compat.lua` is the only file that names a version-variant, deprecated or optional client API
(compat). Feature modules call `NS.Compat.X`; none reads those client globals itself. It loads in
`# Core` right after `core/CoreSetup.lua`, needs `LibStub` (optional) at
load, and is read inside functions only. There is one family file; no `core/Compat<Topic>.lua`
exists.

**Thirteen shims**, counted the way documentation-§3 counts them
(`cat core/Compat*.lua | grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.'` answers `13`). The two
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
| `InCombat()` | `InCombatLockdown` | none (a plain boolean) | `false` | `Situation`, `Restrictions` |
| `InChatMessagingLockdown()` | `C_ChatInfo.InChatMessagingLockdown` | a secret answer reads as **locked** | `false` | `Restrictions` |
| `RestrictionTypes()` | `Enum.AddOnRestrictionType` | none | `{}` | `Restrictions` |
| `IsRestrictionStateActive(state)` | `Enum.AddOnRestrictionState` (anything but `Inactive` is active, so `Activating` counts; a boolean answers itself) | a secret state is **active** | `false` for nil | `Restrictions` |
| `IsRestrictionActive(rtype)` | `C_RestrictedActions.IsAddOnRestrictionActive`, else `GetAddOnRestrictionState` | a secret answer is **active** | `false` | `Restrictions` |

The restriction shims are copied from DropWatcher's `core/Compat.lua`. `tests/test_compat.lua`
drives the plain readers (secrets dropped, a secret `instanceID` read as `nil`) and the restriction
readers.
