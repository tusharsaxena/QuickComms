# Analysis — 20261025-212400

- **Addon:** QuickComms 0.1.0 (record schema 2, client interface 120105)
- **Captured:** 2026-10-25 21:24 local (the dump's `timestamp`, when the report was printed; the run began 21:19), label `2026-10-25 21:19`
- **Who / where:** Sacrìlege-Frostmourne, level 90 Protection Paladin · Murder Row (no subzone) · party (5) / party
- **Delta:** +1.45 ms/frame — above the resolution floor, but not attributable to the addon (no bucket fired)
- **Previous capture:** none — this is the first

## Headline

The first in-game capture of Quick Comms: two combat-gated arms in Murder Row with a party of five.
**No bucket recorded a single call** ([`dump.json`](dump.json): `"buckets":{}`), so the addon's
instrumented code did nothing in combat on this run. That's expected, because nobody pressed a
callout or opened the dial. The +1.45 ms/frame frame-time delta is numerically above the floor, but
the two arms were different fights, and nothing the addon measures ran in either, so it reads as the
environment rather than the addon. The action is a second capture that presses callouts and opens the
dial during arm A.

## The arms

Both figures come from [`dump.json`](dump.json)'s `fps` block; the rounded forms are in
[`report.md`](report.md).

| Arm | Seconds | Frames | Avg fps | ms/frame |
|---|---|---|---|---|
| active (addon running) | 57.7250 | 3364 | 58.2763 | 17.1596 |
| suspended (addon inert) | 66.0560 | 4206 | 63.6732 | 15.7052 |
| **delta** | | | | **+1.4544** |

The delta is 1.45 ms/frame, which is about three times the ~0.5 ms/frame floor, so the frame-time
instrument did see a difference between the arms. Its sign is the expected one: the suspended arm was
faster. Seeing a difference is not the same as attributing it, though. The arms ran 57.7 s and 66.1 s,
two minutes apart, against different pulls, and in the active arm the addon's bracketed paths
recorded zero calls (below). The difference therefore cannot be read as Quick Comms' cost. Combat
gating equalizes when an arm starts recording. It doesn't equalize what the fight in that arm
contains.

## The buckets — what the addon actually cost

Every figure would come from [`dump.json`](dump.json)'s `buckets`; it is empty.

| Bucket | Calls | Total ms | ms/s | Max ms | Parent |
|---|---|---|---|---|---|

None. All nine declared buckets (`core/PerfSetup.lua`) are absent: `situationRefresh`,
`bakeSurface`, `resolverResolve` (declared within `bakeSurface`; not observed, since neither fired),
`sendClick`, `padLayout`, `echoMatch`, `dialRender`, `glowStart` and `coordsRebake`.

**The addon's total accounted cost in combat was 0 ms/s.** That is a statement about what the run
exercised, not a measured upper bound for normal play. Each bucket waits on something that did not
happen during arm A:

- **`sendClick`, `echoMatch`, `coordsRebake`:** a press of a pad button or a dial slice.
- **`dialRender`:** the dial being open. Its pointer update is the addon's only per-frame code.
- **`padLayout`, `bakeSurface`, `resolverResolve`:** a rebuild. A rebuild asked for in combat waits
  for combat to end.
- **`situationRefresh`:** a zone, group, spec or restriction change.
- **`glowStart`:** a glow starting, either on hover or after sending.

So a combat arm with no interaction is the addon's idle floor, and on this capture that floor was
nothing.

## What the capture did not hold constant

From the report's context block and [`report.md`](report.md)'s run log:

- **Same:** the zone (Murder Row, no subzone), the group (`party (5) / party`) and the character,
  spec and level, both at start and in the capture block.
- **Different:**
  - **The fights.** Arm A began recording at 21:19:36 and arm B at 21:22:48, against separate
    pulls; the log does not record what was fought.
  - **Arm length.** 57.7 s against 66.1 s, so B is 14% longer.
  - **The gap between arms.** A ended at 21:20:34 and the addon was suspended at 21:22:36. Nothing
    else was logged in those two minutes, and no `/reload` came between the arms: the run reads as
    one continuous session, from `run started` to `RESUMED`.
- **Suspension:** confirmed. `addon SUSPENDED — inert` precedes arm B's arming, and
  `addon RESUMED — events and frames restored` follows the run.

## What moved

First capture: nothing to diff against. Every figure above is a baseline reading.

## Actions

1. **Take a second capture that exercises the addon** (new here; no issue or finding owns it yet).
   During arm A, press pad callouts, include one with a `{coordinates}` token, and open the dial on its
   key and move the pointer for a while. Do the same in arm B, where the presses do nothing. Ideally
   use the same pull type at the same target count, back to back. That capture is what puts numbers
   on `sendClick`, `echoMatch`, `coordsRebake` and `dialRender`, and it observes or refutes the
   `resolverResolve` within `bakeSurface` nesting.
2. **Hold the environment closer** on that run: arms of similar length against the same kind of
   fight. With the addon idle, this capture cannot tell a +1.45 ms/frame gap between two different
   fights apart from the environment.
