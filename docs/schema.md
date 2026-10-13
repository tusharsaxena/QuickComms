# Schema — Ka0s Quick Comms

The SavedVariables shape, every default, and the migration path. Defaults live in
`defaults/Profile.lua` (`NS.C`); `settings/Schema.lua`'s `Settings.BuildDefaults` merges them with
every stored schema row's own default and hands the tree to AceDB.

## SavedVariables

Exactly two (savedvariables-§4):

- `QuickCommsDB` — AceDB, with profiles.
- `QuickCommsPerfDB` — LibKa0s-Perf's capture ring, outside the profile tree (performance-§5).

## `QuickCommsDB.profile`

| Key | Default | Set by | What it is |
|---|---|---|---|
| `enabled` | `true` | the Enable row, `/qc enable|disable`, the launcher | the master switch; `false` takes the latch's `disabled` hold |
| `visibility` | `"always"` | the General visibility row | the master visibility, applied on top of each pad's own |
| `scale` | `1.0` | the Master scale row | multiplied into every pad's own scale |
| `alpha` | `1.0` | the Master alpha row | the ceiling of every pad's fade |
| `locked` | `true` | the Lock frame row, `/qc lock|unlock`, the launcher's Locked entry | pads start locked; unlocked, each shows its drag strip |
| `behavior.soloFallback` | `"none"` | the Behavior rows, `/qc set` | what a smart channel does when solo: `none`, `self` or `say` |
| `behavior.spamGuard` | `1.0` | Behavior | seconds between sends, 0.6-2.0 (phase 2's send engine; no hard guard in combat, spec §9.2) |
| `behavior.dropNotes`, `whyTooltips`, `lockdownChip` | `true` | Behavior | the `[QC]` drop note, the why tooltips, the lockdown chip |
| `behavior.sounds`, `autoPromote` | `false` | Behavior | sounds; a narrower When floats up within a surface's order |
| `nextId` | `1` | `Library.NewId` | the id counter for user callouts and groups |
| `callouts` | `{}` | `Library` (membership and order); member fields through the seam (member rows) | user callouts keyed by id: name, text, channel, icon |
| `groups` | `{}` | `Library` (membership and order); member fields through the seam (member rows) | user groups keyed by id: name, icon, callouts, when, openInto, enabled |
| `builtins` | `{}` | `Library` (membership and order); member fields through the seam (member rows) | the overlay on the shipped sets, keyed on the top-level built-in id: enabled, hidden |
| `pads` | `{}` | `Library` (membership and order); member fields through the seam (member rows) | surfaces keyed by id: groups (ordered), `seenBuiltins`, and the surface's own settings |
| `dials` | `{}` | `Library` (membership and order); member fields through the seam (`dial.name\|enabled\|mode\|slices\|openAt\|point\|key`) | surfaces keyed by id: groups (ordered), `seenBuiltins`, and the dial's own settings; a new dial stores `interaction = "relaxed"`, and `delay`, `tapAction` and `depth` are kept but nothing reads them |
| `pads[id].point` | absent (the pad sits 150 px below the center) | the `pad.point` member row: the drag strip, the X/Y boxes, Reset position | the saved anchor, the positional array `{ point, relativePoint, x, y }` |
| `dials[id].point` | absent (the dial opens at the center) | the `dial.point` member row: the X/Y boxes, Reset position | the saved anchor, the positional array `{ point, relativePoint, x, y }` |
| `dials[id].key` | absent (`false`: no key) | the `dial.key` member row: the Comms Dial page's key capture, `/qc set dial.key` | the dial's key, upper-case (`SHIFT-G`); bound as an override binding, never in WoW's own bindings |
| `padOrder`, `dialOrder` | `{}` | `Library` only | display order of the surfaces |
| `seeded` | `false` | `Library.Prepare` | true once the default pad and dial exist |

**Member rows** address a member's fields through the seam (`settings/SchemaMembers.lua`): `callout.name|text|channel|icon`, `group.name|icon|enabled|openInto|when`, `pad.name|enabled|groupsAs`, `pad.layout.orientation|columns|growth|style|scale|spacing|width`, `pad.point`, `pad.look.visibility|fade|fadeAlpha`, `dial.name|enabled|mode|slices|openAt|point|key`, `builtin.enabled|hidden`. They are not AceDB defaults; `Library.TEMPLATES` is their shape.

`modules/Library.lua` is the one writer of every structural key above (architecture-§5); built-ins
are shipped data in `NS.BuiltIns`, never copied into the profile. `Library.Prepare` is the load
pass, run after `RunMigrations` on `OnInitialize` and on every profile event: it seeds, appends new
built-ins once per surface, normalizes malformed shapes and repairs `padOrder` / `dialOrder`.

## `QuickCommsDB.global`

| Key | Default | What it is |
|---|---|---|
| `schemaVersion` | `0` | the migration stamp; the runner owns it |
| `minimap.hide` | `false` | LibDBIcon's own key; the Minimap button row inverts onto it, and no `shown` twin exists (launcher-§3) |
| `minimap.minimapPos` | absent | LibDBIcon's own write |

## Session-only (never saved)

`NS.State.debug` (the logging flag). The Debug console row is `sessionOnly` and stores through its
own closure. The phase 2 modules add, all reset by `/reload`: `testMode` (test mode, the Test mode
row's store), `padTab` and `padCollapsed` (per pad: the active tab, the collapsed state),
`surfacePlans`, `surfaceOrder` and `surfaceStale` (the plans, the floated order, the stale hints),
`sendQueue` (the combat-end queue), `sendEcho` (the presses awaiting an echo), `lastSendAt` (the
guard's last press) and `pendingTeardown` (a stand-down held for combat's end), plus the timer
handles (`echoTimers`, `padCoolTimer`, `padFlashTimers`). Phase 3 adds `previewAs` (the "Preview as…"
situation), `editing` (each editor page's selected member) and `whenOpen` (the When editor's open rows).

## Migrations

`core/Database.lua`: `NS.MIGRATIONS` is a list of steps `{ to = n, run = fn }`, plus
`perProfile = true` for a step that must run once for every stored profile (`db.sv.profiles`), and
`NS.SCHEMA_VERSION` is the last step's `to`. Step 1 is the stamp itself (0 → 1, nothing to reshape); the phase 1 keys needed no step, because
`Library.Prepare` makes a profile that predates them whole.
Step 2 (phase 4, `perProfile`): the generic battleground set below the per-battleground sets on every
pad and dial (`Library.MoveGenericBattlegroundLast`), so a battleground's node set can be the first
active group and the dial opens into it. `NS.SCHEMA_VERSION` is 2.
The runner runs in `OnInitialize` before anything reads the profile, and again on every profile
event; it advances the stamp only after a step returns. A stored-value type change adds a step and
raises the target; the default stays `0`.
