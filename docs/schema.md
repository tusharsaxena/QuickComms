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

The design's data model (spec §5.1: callouts, groups, pads, dials, behavior) is added by the
profile task, each key with its default here and, where a shape changes, its step.

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
`NS.SCHEMA_VERSION` is the last step's `to`. Step 1 is the stamp itself (0 → 1, nothing to reshape).
The runner runs in `OnInitialize` before anything reads the profile, and again on every profile
event; it advances the stamp only after a step returns. A stored-value type change adds a step and
raises the target; the default stays `0`.
