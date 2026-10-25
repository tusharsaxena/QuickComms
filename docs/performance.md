# Performance — Ka0s Quick Comms

How much this addon costs, and how to find out. The shared protocol, the record contract and the
step panel are `LibKa0s-Perf-1.0`'s and are documented in the library repo's `docs/api/Perf/`; this
page covers what is this addon's.

## The harness

`core/PerfSetup.lua` builds one instance at load (performance-§1): `QuickCommsPerfDB` is the
capture ring, the latch from `core/LifecycleSetup.lua` is handed over so Suspend and Resume take and
release its `perf` hold, and the `perf` verb is the addon's (`settings/Slash.lua`), printing the
lines the library returns. A suspended addon is inert through the same stand-down the disabled
state uses. During a capture, `/qc toggle`, `/qc test`, `/qc preview` and the Toggle Comms Pads key
answer `Not available during a performance capture.` rather than the disabled line
(`NS.StoodDownRefusal`).

The harness is wired from the scaffold rather than exempted: the design sends from secure buttons
during combat and runs an `OnUpdate` while the dial is open, so performance-§12's no-combat-path
exemption will never apply.

## The buckets

Nine are declared, the design's seven, the Icons tab's `glowStart` and the `{coordinates}` re-bake's `coordsRebake`, in `core/PerfSetup.lua`, in report order, each with the file that brackets it:

| Bucket | Bracketed in | Measures |
|---|---|---|
| `situationRefresh` | `modules/Situation.lua` | one situation read: inputs, classify, signature. The `SITUATION_CHANGED` publish runs after the bracket closes; the rebuild it triggers is in `bakeSurface`, `resolverResolve` and `padLayout` |
| `bakeSurface` | `modules/Surfaces.lua` | one pad's or dial's plan: resolve, order, bake every slot (and, for a dial, the ring layout); the Dial page's own looks at a plan (`deps.unmeasured`) are not counted |
| `resolverResolve` | `modules/Surfaces.lua` | a plan's active groups and their order; declared and noted within `bakeSurface` |
| `sendClick` | `modules/SendEngine.lua` | the `OnClick` hook on a send button |
| `padLayout` | `modules/Pad.lua` | one pad's rebuild: geometry, buttons, arm |
| `echoMatch` | `modules/SendEngine.lua` | a `CHAT_MSG_*` echo while a press waits. Since QF-04 the handler hears every channel line (`CHAT_MSG_CHANNEL`: General, Trade, custom channels); with no press waiting it returns at its first test, a table lookup, and a waiting press reads the channel index before the bracket, so a line on another channel is dropped unmeasured |
| `dialRender` | `modules/Dial_Render.lua` | the pointer's `OnUpdate` while a dial is open: one cursor read, one angle, one texture move |
| `glowStart` | `modules/Glow.lua` | one icon glow's start (the Icons tab, B9): an effect started or restarted on a button's or a wedge's icon; an unchanged rebuild starts none. The pixel and auto cast styles then run LibCustomGlow-1.0's own `OnUpdate` on every glowing icon while it shows, which this addon does not bracket; smoke step ICONS-2 watches the frame rate with a full pad glowing |
| `coordsRebake` | `modules/SendEngine.lua` | a `{coordinates}` button's press-time re-bake in its `PreClick` hook, and each one at the combat edge (QF-03): one position read, one bake, at most one re-arm; only buttons whose text uses the token, and never in combat |

Keys are lowerCamelCase, named for the path they time (naming-cheatsheet); until audit QC-12 they
were dotted (`situation.refresh`, `bake.surface`, …), and no capture under `docs/perf-analysis/` names
the old form. The `situationRefresh` scenario below shares its bucket's name because it times that
bucket's path alone.

Each bucket is declared together with the bracket that reaches it, and `tests/test_setup.lua` fails
if a declared bucket has no bracket, or a bracket no bucket. Every
bracket is the gated form (performance-§2): one upvalue read, one field read and one boolean test
when capture is off.

## Offline scenarios

`lua tests/perf.lua`, outside the green gate (performance-§9), asserting bytes per iteration and
notes per iteration, never time:

| Scenario | What it shows | Ceiling | Measured 2026-10-25 |
|---|---|---|---|
| `bracketCaptureOff` | the gated bracket shape, capture off, notes nothing and allocates nothing | 0 bytes, 0 notes | 0.0 B |
| `dialPointerCaptureOff` | the hottest bracketed path, the open dial's pointer `OnUpdate`, capture off | 1 KiB, 0 notes | 224.0 B |
| `dialPointerNoHarness` | the same path on an instance with no Perf library; the run fails if capture off allocates more (zero overhead, performance-§9) | 1 KiB, 0 notes | 224.0 B |
| `padRebuild12` | a 12-button pad built from its plan and applied, capture on | 69 KiB, 3 notes (raised from 68 KiB when the rows began to follow the Look's font size) | 66290.8 B |
| `dialOpenClose` | the default dial opened, one pointer frame (which lights a slice and shows its wedge's tooltip), closed | 2 KiB, 1 note | 1997.1 B |
| `situationRefresh` | a situation read whose signature did not move | 2 KiB, 1 note | 2016.0 B |

The ceilings are the headless mock's figures, rounded up to the next KiB; its catch-all methods allocate a closure per call, so compare runs with runs, never with the client.

**The 2026-10-25 re-measure (review F-001).** Both rebuild scenarios had crept over their ceilings
without a note. `padRebuild12` stood at 87026.8 B: the shipped Gloss fade shine (owner, 2026-10-22)
was repainted on every button at every rebuild, outside the look signature. `R.ApplyButtonLook` now
paints it only when the shine table (reused while the button look's signature holds) or the button's
drawn size moved, which took the scenario back to 66290.8 B, the figure with the shine off.
`dialOpenClose` stood at 2317.1 B. Bisected over `239b665..71c85f2`, the rise came from the dial polish
work rather than the shine merge: `22283b7` (+320 B, the slice gap's placement) and `c8a8994` (+720 B,
the pointer's per-frame tracking, which now lights the slice under the cursor and hovers its wedge,
tooltip included). `DialSlices.Track` now moves the highlight only to another slice or another ring
shape, so the scenario is 1997.1 B; the wedge tooltip it builds is the feature's own cost. No ceiling
was raised.

A rebuild also stopped disarming every button and wedge before arming it again (review F-006): a
released one is parked armed, and only the ones the rebuild does not take back are disarmed, so an
unchanged line costs no secure write. The mock's `SetAttribute` allocates nothing, so the byte
figures above do not show it; `tests/test_pad.lua` and `tests/test_dial.lua` count the writes.

## In game

`/qc perf` opens the step panel; [`perf-analysis/README.md`](perf-analysis/README.md) is the
capture store and says how a capture becomes a bundle.
