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

None is declared yet. Phase 1's only event-driven path is `Situation.Refresh`, a pass coalesced to
one read 0.1 s after a burst of zone, roster, spec and keystone events: it runs a handful of times a
pull at most and never per frame or per combat-log event, so a bucket on it would read near `0.000`
(bucket coverage is a SHOULD, performance-§3). `situation.refresh` is declared in phase 2, with the
resolver edge and the surface bake that run inside the same pass. The design's buckets (spec §16:
`situation.refresh`, `resolver.resolve`, `bake.surface`, `pad.layout`, `dial.render`, `send.click`,
`echo.match`) are declared in `core/PerfSetup.lua` together with the bracket that reaches each one,
and `tests/test_setup.lua` fails if a declared bucket has no bracket, or a bracket no bucket. Every
bracket is the gated form (performance-§2): one upvalue read, one field read and one boolean test
when capture is off.

## Offline scenarios

`lua tests/perf.lua`, outside the green gate (performance-§9), asserting bytes per iteration and
notes per iteration, never time:

| Scenario | What it shows | Ceiling |
|---|---|---|
| `bracketCaptureOff` | the gated bracket shape, against the live harness with capture off, notes nothing and allocates nothing (zero overhead) | 0 bytes, 0 notes |

The design's scenarios (a 12-chip pad rebuild, a full dial open and close) arrive with the code they
measure.

## In game

`/qc perf` opens the step panel; [`perf-analysis/README.md`](perf-analysis/README.md) is the
capture store and says how a capture becomes a bundle.
