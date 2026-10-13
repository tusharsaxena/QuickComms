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

| `behavior.soloFallback` | `"none"` | the Behavior rows, `/qc set` | what a smart channel does when solo: `none`, `self` or `say` |
| `behavior.spamGuard` | `1.0` | Behavior | seconds between sends, 0.6-2.0 (phase 2's send engine; no hard guard in combat, spec §9.2) |
| `behavior.dropNotes`, `whyTooltips`, `lockdownChip` | `true` | Behavior | the `[QC]` drop note, the why tooltips, the lockdown chip |
| `behavior.sounds`, `autoPromote` | `false` | Behavior | sounds; a narrower When floats up within a surface's order |
| `nextId` | `1` | `Library.NewId` | the id counter for user callouts and groups |
| `callouts` | `{}` | `Library` only | user callouts keyed by id: name, text, channel, icon |
| `groups` | `{}` | `Library` only | user groups keyed by id: name, icon, callouts, when, openInto, enabled |
| `builtins` | `{}` | `Library` only | the overlay on the shipped sets, keyed on the top-level built-in id: enabled, hidden |
| `pads`, `dials` | `{}` | `Library` only | surfaces keyed by id: groups (ordered), `seenBuiltins`, and the surface's own settings |
| `padOrder`, `dialOrder` | `{}` | `Library` only | display order of the surfaces |
| `seeded` | `false` | `Library.Prepare` | true once the default pad and dial exist |

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
own closure.

## Migrations

`core/Database.lua`: `NS.MIGRATIONS` is a list of steps `{ to = n, run = fn }`, plus
`perProfile = true` for a step that must run once for every stored profile (`db.sv.profiles`), and
`NS.SCHEMA_VERSION` is the last step's `to`. Step 1 is the stamp itself (0 → 1, nothing to reshape); the phase 1 keys needed no step, because
`Library.Prepare` makes a profile that predates them whole.
The runner runs in `OnInitialize` before anything reads the profile, and again on every profile
event; it advances the stamp only after a step returns. A stored-value type change adds a step and
raises the target; the default stays `0`.
