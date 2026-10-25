# Analysis — 20261025-213356

- **Addon:** QuickComms 0.1.0 (record schema 2, client interface 120105)
- **Captured:** 2026-10-25 21:33 local (the dump's `timestamp`, when the report was printed; the run began 21:30), label `2026-10-25 21:30`
- **Who / where:** Sacrìlege-Frostmourne, level 90 Protection Paladin · Murder Row (no subzone) · party (5) / party
- **Delta:** +0.61 ms/frame — just above the ~0.5 ms/frame floor; the buckets account for about 0.3% of it
- **Previous capture:** [`20261025-212400`](../20261025-212400/ANALYSIS.md)

## Headline

This is the capture that exercised the addon: in arm A the player pressed pad buttons and dial
slices, and three buckets fired. Six sends, six echo matches and 223 frames of the dial's pointer
update cost **0.123 ms per second of combat** in all ([`dump.json`](dump.json)). That is 0.002 ms per
frame, against a frame-time delta of 0.61 ms/frame. The delta sits just above the floor, and almost
none of it is the addon's measured code. Nothing here needs acting on.

## The arms

Both figures come from [`dump.json`](dump.json)'s `fps` block; the rounded forms are in
[`report.md`](report.md).

| Arm | Seconds | Frames | Avg fps | ms/frame |
|---|---|---|---|---|
| active (addon running) | 56.2870 | 3456 | 61.3996 | 16.2867 |
| suspended (addon inert) | 59.8660 | 3819 | 63.7925 | 15.6758 |
| **delta** | | | | **+0.6109** |

At +0.61 ms/frame the delta is only just past the ~0.5 ms/frame line where the instrument starts to
resolve anything, so it is a borderline reading rather than a clear one. Its sign is the expected
one (the suspended arm was faster). The buckets put the addon's own Lua at 0.002 ms/frame, so whatever
the 0.61 is, the bracketed code is not most of it. Two things the buckets cannot see could sit in
the remainder:
- the cost of drawing the pad and the open dial, which the client spends on frames being on screen
  rather than in any Lua function;
- the difference between the two fights.

This capture cannot tell those two apart. The arms ran 56.3 s and 59.9 s, roughly a minute apart,
against different pulls.

## The buckets — what the addon actually cost

Every figure from [`dump.json`](dump.json)'s `buckets`; `ms/s` is `totalMs` over the **active** arm's
56.2870 seconds, as [`report.md`](report.md) computes it. Buckets nest — **do not sum the column**.
None of these three declares or was observed with a parent, so their total below is a plain sum.

| Bucket | Calls | Total ms | ms/s | Max ms | Parent |
|---|---|---|---|---|---|
| `dialRender` | 223 | 5.9627 | 0.1059 | 0.2272 | none declared |
| `sendClick` | 6 | 0.6305 | 0.0112 | 0.1303 | none declared |
| `echoMatch` | 6 | 0.3438 | 0.0061 | 0.0667 | none declared |

**Total accounted cost: 6.9370 ms over the arm, 0.1232 ms per second of combat.** The per-call
ratios survive a change of arm length:

- **`dialRender`:** 0.0267 ms per call. It is the dial's pointer update and runs once per frame
  while a dial is open, so 223 calls is about 3.6 s of the dial on screen at the arm's average 61.4
  fps (an estimate: frame times vary within the arm). The worst single frame cost 0.227 ms.
- **`sendClick`:** 0.105 ms per press, worst 0.130 ms. Six presses.
- **`echoMatch`:** 0.057 ms per matched echo, and six echoes for six presses, so every line was
  heard back. No drop note was due.

**Absent, so never fired:**
- **`coordsRebake`:** no callout with a `{coordinates}` token was pressed.
- **`glowStart`:** no icon glow started. Either the Icons tab's hover and after-sending glows were
  off, or nothing triggered one; the capture can't say which.
- **`situationRefresh`, `padLayout`, `bakeSurface` and `resolverResolve`:** nothing changed the
  situation, and a rebuild requested in combat waits until combat ends. `resolverResolve`'s declared
  parent, `bakeSurface`, therefore stays unverified.

## What the capture did not hold constant

From the report's context block and [`report.md`](report.md)'s run log:

- **Same:** the zone (Murder Row, no subzone), the group (`party (5) / party`) and the character,
  spec and level.
- **Different:**
  - **The fights.** Arm A recorded from 21:30:34 and arm B from 21:32:53, against separate pulls.
  - **Arm length.** 56.3 s against 59.9 s, so B is 6% longer.
  - **The gap between arms.** A ended at 21:31:31 and the addon was suspended at 21:32:46. Nothing
    else was logged in those 75 seconds, and no `/reload` came between the arms.
- **Interaction:** by design, the player pressed buttons and opened the dial in arm A only. That is
  what the capture set out to measure, and it is also one more way the arms differ.
- **Suspension:** confirmed. `addon SUSPENDED — inert` precedes arm B, and `addon RESUMED` follows
  the run.

## What moved

Against [`20261025-212400`](../20261025-212400/ANALYSIS.md), where nothing was pressed:

- **Buckets.** That capture recorded none. This one records three, so every bucket figure above is
  its first reading rather than a change.
- **The suspended arms barely moved:** 15.7052 → 15.6758 ms/frame (63.6732 → 63.7925 fps). The
  suspended arm is the cleanest reading of the environment, so the two sessions had a very similar
  background.
- **The active arm got faster:** 17.1596 → 16.2867 ms/frame (58.2763 → 61.3996 fps), even though the
  addon did more work this time (0 → 0.1232 ms/s accounted). The delta fell from +1.4544 to +0.6109.
  So the earlier, idle capture's larger delta was not the addon's: its active arm carried
  0.87 ms/frame more than this one with no bucket firing. That is the environment moving between
  fights, the reading the previous analysis gave.

## Actions

None needed for cost: 0.12 ms per second of combat is negligible, and no single call came near a
frame's budget (the worst was 0.227 ms).

1. **Optional, for coverage** (new here; no issue owns it): the next capture could press one
   `{coordinates}` callout and turn on a hover or after-sending glow, so that `coordsRebake` and
   `glowStart` get a first reading. `resolverResolve` within `bakeSurface` can only be observed by a
   rebuild outside combat, which a combat-gated arm never records. That is a limit of the protocol,
   not a gap in the brackets.
