# Data flow — Ka0s Quick Comms

## Today: a setting changes

```
panel checkbox ─┐
/qc set|enable ─┼─> NS.SchemaRuntime.Set(path, v) ─> store ─> [Set] line ─> row.onChange ─> announce
launcher entry ─┘                                                   │                    │
                                                    Settings.REACTIONS[path]       panel refresh
                                                    (enabled → the latch's `disabled` hold)
```

Every module reads a setting back through `NS.Setting(path)`.

## Today: enable and disable

`enabled = false` → `Lifecycle:Set("disabled", true)` → `NS.StandDown`: every `NS.FEATURE_EVENTS`
row unregistered, tracked bus registrations taken down, each module's `NS.STAND_DOWN` step run. The
stand-up re-registers and runs each `NS.STAND_UP` step from current settings. The perf harness's
suspend takes the same latch's `perf` hold.

## Today: a profile event

AceDB's switch, copy or reset → `reloadProfile` (`core/QuickComms.lua`): the migrations,
`Library.Prepare()` (seed, append newly shipped built-ins, repair the registry, lift `nextId`), a panel
refresh, the latch re-read from the incoming profile's `enabled`, then `NS.MSG.PROFILE_CHANGED`.

## Today: a restriction or combat edge

`ADDON_RESTRICTION_STATE_CHANGED` or a `PLAYER_REGEN` edge → `Restrictions` (it owns both
`PLAYER_REGEN` rows) → when the set of blocking reasons moves, `RESTRICTION_CHANGED (reason,
canSendChat)` → Situation refreshes the snapshot's `lockdown` and `inCombat` in place. The signature
does not move and no `SITUATION_CHANGED` is sent. `PLAYER_REGEN_ENABLED` also drains SendEngine's
combat-end queue directly, whether or not the restriction set moved.

## Today: `/qc check <id>`

```
/qc check ─> Library.Callout(id) ─> Situation.Current() ─> Bake.Bake(callout, snapshot, {soloFallback})
                                                                 │  tokens, channel, sanitize
                                                                 ▼
                                              line, channel, bytes, lock  ─> NS.Print   (never sends)
```

The verb bakes the line the pad would arm, and never sends it.

## Today: a callout is pressed

The chip is a secure button armed with one baked line. The game sends the line (the secure path; nothing in Lua sends). The button's `OnClick` hook runs on the acting edge: `SendEngine` classifies the press against the last one (`guarded` inside `behavior.spamGuard`, reported at once), records it for the echo tracker, and dims every chip for the window. A `CHAT_MSG_*` of the same chat type from the player within 1.5 s makes it `sent`; none makes it `dropped`, with one `[QC]` note. `SEND_RESULT` flashes the chip.

## Today: something changes that a pad draws

`SITUATION_CHANGED`, `LIBRARY_CHANGED`, `PROFILE_CHANGED`, `TEST_MODE_CHANGED` and the settings reactions all call `Surfaces.Request`. Out of combat it rebuilds every enabled pad from the current snapshot (`BuildPlan` → `Pad.Sync`). In combat it files one `surfaces` entry in the combat-end queue, shows the stale hint and sends `SURFACE_REBUILT (id, true)`; at combat end the queue drains, the pads rebuild from the snapshot as it is then, and `COMBAT_QUEUE_DRAINED` clears the hints. `RESTRICTION_CHANGED` re-reads only the padlocks, the lockdown chip and the fade, which change in combat too.

## Today: test mode

The checkbox, `/qc test` and the launcher entry call `Preview.SetTestMode`. It is refused in combat and stood down, and `RESTRICTION_CHANGED` with the combat edge ends it. `TEST_MODE_CHANGED` makes `Surfaces` draw each pad from `TestPlan`: placeholder chips, disarmed, that send nothing.

## The design's callout pipeline (spec §4.1)

```
 game events ─► Situation ──SITUATION_CHANGED──► Resolver ──ACTIVE_GROUPS_CHANGED──► Surfaces
 (zone, key,    (classify the                 (When rules → active           (Pad, Dial:
  group, spec,   snapshot)                     groups, per-surface order)      layout, render)
  restriction)                                     ▲                                │ slot plans
 Library (the registry writer) ──LIBRARY_CHANGED───┘                                ▼
                                                              Bake (tokens, channel, sanitize →
                                                              one macro line, out of combat)
                                                                                    │
                                                                                    ▼
                                         SendEngine (the only secure-attribute writer: button pool,
                                         combat-end queue, bindings, spam guard, echo tracker)
```

The README's `## How the callouts work` is the same pipeline told for players. Every stage exists
apart from the Dial and the bindings (phase 4); today `Surfaces` resolves and bakes inside its own
rebuild, and `ACTIVE_GROUPS_CHANGED` is sent from there.
