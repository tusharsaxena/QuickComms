# 02 — Proposed changes (review of 2026-11-11)

Standard: **Ka0s WoW Addon Standard v2.107.0 (2026-11-10)**, read from the sibling
`../WowAddonStandards` checkout at `a96a7db`. The checkout was clean and equal to `origin/master`.
No change below adds a deviation. `docs/ARCHITECTURE.md` `## Documented deviations` gains no row.

## HLD

| Theme | Findings | Rationale |
|---|---|---|
| T1. Give the per-slot action tables back | F-001 | The combined-actions bake added several tables per slot, made on every rebuild. Re-measure, bisect the rise, and cut what it does not need, such as the `slot.locks or {}` empty table. If the rest is the design's real cost, raise the ceiling the way `tests/perf.lua` already records each rise: dated, with the commit and the cause. |
| T2. Move the inventory with the count | F-002 | Regenerate `docs/test-cases.md` from `--list` and set the badge to the fresh Total (testing-§5). |
| T3. Hold every function at CCN 15 | F-003 | Split the four new functions along real decision lines. The plan's CA-M5-3 owns this. |
| T4. One write seam for the toast's place | F-004 | Write `thank.position` through the schema seam, the way the pads write `pad.point`. |
| T5. Quiet the in-combat aura path | F-005 | File the after-combat entry once per fight, with a hoisted function. |
| T6. Clear the drag flag wherever a drag can end | F-006 | Clear `TH.dragging` wherever the library can end a drag without the frame's script. |

Alternatives rejected:

- **F-001: just raise the ceiling.** `tests/perf.lua:28` forbids a raise without re-measuring and saying
  why. A raise is allowed only after the bisect, for the part that is the design's real cost.
- **F-004: a private validator in the toast host.** That would be a second copy of the row's
  `validate`. The seam is the single write path (savedvariables, options-ui schema seam).
- **F-006: patching `libs/LibKa0s/Toast.lua` to fire `OnDragStop`.** That edits vendored code
  (library-stack-§5). The host owns the flag, so the host clears it. A library hook that reports
  "drag ended" would be an additive upstream ask, not needed for this fix.

No `[upstream]` findings.

## LLD

### C-01 (F-001) — the per-slot action tables

- Files: `modules/Surfaces.lua`, `modules/Bake.lua`, `tests/perf.lua`, `docs/performance.md`.
- Bisect first: measure `padRebuild12` at `45c3b01` (CA-M1-7), `737931b` (CA-M1-8), `ab731e3` (CA-M2-1), `f2b1106` (CA-M2-2), `6bbc3f4`, `9be1564`
  and `9e8f327` (CA-M2-11) with `git archive` into scratch. Name the commit that moved it.
- Cheap cuts that change no behavior:
  - `S.SlotLockdown`: iterate `slot.locks` only when it is a table, with no `or {}` allocation.
  - `B.BakeActions`: build `lines` only when more than one action baked. One baked line is the macro
    itself.
- Then re-measure. If the figure is still over 70656, raise the ceiling to the measured figure rounded
  up to the next KiB, with a dated `Raised 2026-11-…` note naming the commit and the cause (the
  per-action tables are the combined-actions design, spec §3). Update `docs/performance.md`'s
  `padRebuild12` row to match.
- Risk: low. The cuts are allocation-only, and `tests/test_bake.lua` / `tests/test_surfaces.lua` pin the
  shapes. Pass count unchanged.

### C-02 (F-002) — the inventory and badge

- Files: `docs/test-cases.md`, `README.md`.
- `lua tests/run.lua --list > docs/test-cases.md`. Set the badge to `Tests-<Total>%2F<Total>_passing`.
  Fold this into the last commit of this review's fixes that moves the count, so it moves once.

### C-03 (F-003) — CCN 15

- Files: `modules/SendEngine.lua` (`press`), `settings/Callouts.lua` (`actionRows`),
  `tests/test_locale.lua` (`scan`), `tests/wow_mock.lua` (`M.CreateFrame`), and, so the release gate is
  zero, `settings/SlashVerbs.lua` (`groupFinderLine`).
- `press`: lift the echo and self-line preamble (`meta.echo`, `meta.selfText`) into a named
  `pressLocalOnly(b, meta)` that answers whether the press goes on. Lift the guard stamp and track into
  `stampAndTrack(b, meta, open)`. The press order (spec §4) stays as it is.
- `actionRows`: split the baked and the skipped branches into `bakedRows(out, a, alone)` and
  `skippedRows(out, a, alone)`.
- `groupFinderLine`: lift the shipped-ids pass and the extra-maps pass into two named helpers.
- `scan` / `M.CreateFrame`: split along their existing comment blocks.
- Characterization first: each function's existing cases must cover it. Where a branch has no case,
  add one before the split (anti-pattern #52: no `part2` helpers). The plan's CA-M5-3 owns this.

### C-04 (F-004) — the toast's place through the seam

- File: `modules/AutoThank_Toast.lua`, plus a case in `tests/test_autothank.lua`.
- Before: `if t then t.position = point or false end`.
- After: write through the schema runtime, resolved at call time, falling back to the direct write
  when no row exists (the degraded load registers none, `settings/AutoThank.lua:89`):

```lua
setPosition = function(point)
    local v = point or false
    local S = NS.SchemaRuntime
    if S and S.FindRow and S.FindRow("thank.position") then
        S.Set("thank.position", v)
    else
        local t = thankSettings()
        if t then t.position = v end
    end
end,
```

- Check first that `S.Set` takes `false` for a `point` row (the row's `validate` is
  `NS.Library.ValidPoint`, which may refuse `false`). If it refuses, the reset value goes through
  `S.ApplyDefault` instead.
- Test: a drag's `setPosition` with a malformed point stores nothing (red under: the direct write), and
  a well-formed one stores it. Pass count +1 or +2.

### C-05 (F-005) — one after-combat entry per fight

- File: `modules/AutoThank.lua`, plus a case in `tests/test_autothank.lua`.
- Hoist `local function diffAfterCombat() AT.OnCombatEnd() end` to file scope. In `AT.OnAura`'s fighting
  branch, file it only when `State.thankDirty` was not already set:
  `if not State.thankDirty then State.thankDirty = true; NS.SendEngine.Queue("thank.diff", diffAfterCombat) end`.
- Careful: `thankDirty` is also set out of combat by a secret payload (`:265`, `:269`) without filing an
  entry. Gate on a separate `State.thankQueued` flag instead, set when filed and cleared in
  `AT.OnCombatEnd`, or the first in-combat aura after an out-of-combat secret payload files nothing.
  `RESTRICTION_CHANGED` still covers that case, but a login in combat may never send it (the
  comment at `:244-247`).
- Test: two in-combat `UNIT_AURA`s file one queue entry and allocate one function (the queue's entry
  `fn` is the same value both times).

### C-06 (F-006) — the drag flag

- File: `modules/AutoThank_Toast.lua`, plus a case in `tests/test_autothank.lua`.
- Clear `TH.dragging` in the combat-edge `Hold` branch of `onRestrictionChanged`, and in `TH.Build`
  when nothing else is on screen. Better still, hook each pool frame's `OnHide` once (in `startFade`,
  beside the other hooks) to clear it, since every library take-down hides the frame.
- Test: start a drag (`OnDragStart`), take the toast down through the library's `Hold`, show a new
  toast: its fade runs (alpha below 1 inside the fade window). Red under: no `OnHide` clear.

## Standards conformance

| Change | Conformance |
|---|---|
| C-01 | performance-§9: the runner asserts deterministic allocation only. A ceiling moves only by re-measuring, with a recorded cause. |
| C-02 | testing-§5. |
| C-03 | automated-tests (zero functions above CCN 15 at release); anti-pattern #52 (no meaningless helpers). No commit-time complexity gate is added. |
| C-04 | the single write seam (savedvariables; options-ui schema seam). No new stored key. |
| C-05 | performance (no allocation on a hot event path). |
| C-06 | library-stack-§5: no edit under `libs/`. The host clears its own flag. |
