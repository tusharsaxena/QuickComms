# Performance — Ka0s Quick Comms

How much this addon costs, and how to find out. The shared protocol, the record contract and the
step panel are `LibKa0s-Perf-1.0`'s and are documented in the library repo's `docs/api/Perf/`; this
page covers what is this addon's.

## The harness

`core/PerfSetup.lua` builds one instance at load (performance-§1): `QuickCommsPerfDB` is the
capture ring, the latch from `core/LifecycleSetup.lua` is handed over so Suspend and Resume take and
release its `perf` hold, and the `perf` verb is the addon's (`settings/Slash.lua`), printing the
lines the library returns. A suspended addon is inert through the same stand-down the disabled
state uses.

The harness is wired from the scaffold rather than exempted: the design sends from secure buttons
during combat and runs an `OnUpdate` while the dial is open, so performance-§12's no-combat-path
exemption will never apply.

## The buckets

Five are declared in `core/PerfSetup.lua`, in report order, each with the file that brackets it:

| Bucket | Bracketed in | Measures |
|---|---|---|
| `bake.surface` | `modules/Surfaces.lua` | one pad's or dial's plan: resolve, order, bake every slot (and, for a dial, the ring layout) |
| `send.click` | `modules/SendEngine.lua` | the `OnClick` hook on a send button |
| `pad.layout` | `modules/Pad.lua` | one pad's rebuild: geometry, chips, arm |
| `echo.match` | `modules/SendEngine.lua` | a `CHAT_MSG_*` echo while a press waits |
| `dial.render` | `modules/Dial_Render.lua` | the pointer's `OnUpdate` while a dial is open: one cursor read, one angle, one texture move |

`Situation.Refresh` has no bucket: a pass coalesced to one read 0.1 s after a burst of zone, roster,
spec and keystone events runs a handful of times a pull at most, so a bucket on it would read near
`0.000` (bucket coverage is a SHOULD, performance-§3); the resolver runs inside `bake.surface`. The
design's other buckets (spec §16: `situation.refresh`, `resolver.resolve`) are
declared together with the bracket that reaches each one, and `tests/test_setup.lua` fails if a
declared bucket has no bracket, or a bracket no bucket. Every
bracket is the gated form (performance-§2): one upvalue read, one field read and one boolean test
when capture is off.

## Offline scenarios

`lua tests/perf.lua`, outside the green gate (performance-§9), asserting bytes per iteration and
notes per iteration, never time:

| Scenario | What it shows | Ceiling |
|---|---|---|
| `bracketCaptureOff` | the gated bracket shape, against the live harness with capture off, notes nothing and allocates nothing (zero overhead) | 0 bytes, 0 notes |

The design's scenarios (a 12-chip pad rebuild, a full dial open and close) arrive with phase 5's
`tests/perf.lua`.

## In game

`/qc perf` opens the step panel; [`perf-analysis/README.md`](perf-analysis/README.md) is the
capture store and says how a capture becomes a bundle.
