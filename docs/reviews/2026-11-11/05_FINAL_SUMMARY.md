# 05 — Final summary (review of 2026-11-11)

This summary is written as if the fixes in `04_EXECUTION_PLAN.md` have landed and `03_SMOKE_TESTS.md`
has passed. Until then it is the target, not a record.

## Headline

The whole-branch review of combined actions, pings, markers, the message-and-emote built-ins and
auto-thank (#16 to #20) found nothing on taint, secret values or migration safety. It found six
smaller problems. A pad rebuild got 35% more expensive, the test inventory lagged four cases, four new
functions crossed the complexity gate, and the toast's position skipped the write seam. Auto-thank also
filed work on every in-combat aura change, and a drag cut short by combat could stop later toasts from
fading. The fix cycle brings the perf runner back to green, the complexity run to zero warnings and the
inventory to the true count.

## Counts

Critical fixed: 0, High fixed: 0, Medium fixed: 5 (F-001 to F-005), Low fixed: 1 (F-006). Nothing is
deferred by design. Any finding skipped in CA-M5-2 is listed with its reason in that task's checkpoint
notes.

## Changes by theme

| Theme | What changed | Why it mattered | Findings / changes | Files |
|---|---|---|---|---|
| T1 per-slot tables | Fewer tables per rebuild; any remaining rise recorded in `tests/perf.lua` with its cause | about 23 KB more garbage per pad rebuild | F-001 / C-01 | `modules/Surfaces.lua`, `modules/Bake.lua`, `tests/perf.lua`, `docs/performance.md` |
| T2 inventory | `docs/test-cases.md` and the badge equal the suite | the authoritative count was wrong | F-002 / C-02 | `docs/test-cases.md`, `README.md` |
| T3 complexity | Five functions split at real decision points | the release gate is zero above CCN 15 | F-003 / C-03 | `modules/SendEngine.lua`, `settings/Callouts.lua`, `settings/SlashVerbs.lua`, `tests/test_locale.lua`, `tests/wow_mock.lua` |
| T4 write seam | The toast's dragged spot is written through the schema seam | a malformed point could be stored unchecked | F-004 / C-04 | `modules/AutoThank_Toast.lua` |
| T5 in-combat aura | One after-combat entry per fight, no closure per event | allocation on the hottest event in combat | F-005 / C-05 | `modules/AutoThank.lua` |
| T6 drag flag | The drag flag clears when a toast hides | toasts could stop fading after a drag cut short by combat | F-006 / C-06 | `modules/AutoThank_Toast.lua` |

## API and behavior changes

None visible to the player. No new slash verbs, settings, locale keys, saved-variable keys or
migrations.

## Saved-variable and migration notes

None. Step 20 is unchanged.

## Performance impact

Fill this in from today's `lua tests/perf.lua` after C-01: `padRebuild12` before (91773.6 B/iter on
this branch, 68156.2 B on `master`) and after.

## Test and complexity movement

2018 cases before the fixes. The count after the fixes is the fresh `--list` Total, and the
inventory and badge move in the same commit. The complexity run goes from 5 warnings to 0. The
`docs/automated-tests/RESULTS.md` watch list is regenerated at release, not here.

## Known follow-ups

- The cross-addon class-2 split (the roster spans LibKa0s v1.93.0, v1.94.0 and v1.95.0) closes with the
  collection's re-vendor sweep. It needs no change in QuickComms.

## Verification evidence

The completed `03_SMOKE_TESTS.md` sign-off table, and the `CA-M5-2` / `CA-M5-3` commits on
`feat/2026-11-10-combined-actions`.

## Suggested commit message

```
CA-M5-2: Review fixes for the combined-actions branch (F-001..F-006)

Pad rebuild allocation back under its ceiling or its rise recorded (F-001), the inventory and badge
moved with the count (F-002), the toast's place through the schema seam (F-004), one after-combat
entry per fight (F-005), the drag flag cleared on hide (F-006). CA-M5-3 splits the five functions over
CCN 15 (F-003).
```
