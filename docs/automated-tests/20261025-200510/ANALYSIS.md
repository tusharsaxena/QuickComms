# Analysis — 20261025-200510

- **Addon:** QuickComms 0.1.0
- **Verdict:** green
- **Commit:** `aacdc1d` (feat/2026-10-25-review-audit-fixes)
- **Previous run:** `20261014-002540` (`6cc22be`)

## Headline

All four suites pass on a clean tree ([`manifest.json`](manifest.json)): lint 0/0 over 140 files,
1175 of 1176 cases passed with 1 declared skip, six perf scenarios recorded, and **no function above
CCN 15**. The record was 338 commits stale before this run, so nearly every figure moved; the
movement is growth (3900 functions, up from 2364), not density: average CCN rose only from 2.5 to 2.6.
Seven files sit in the 1000–1500 band; `tests/test_dial.lua` is 28 lines from the cap and is the one
to split next.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261014-002540 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 140 files | [`lint.txt`](lint.txt) | 109 → 140 files; still 0/0 |
| tests | pass | 1175 passed, 1 skipped, 0 failed, 1176 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 687 → 1176 cases; skips unchanged at 1 |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same six scenarios; bytes/iter moved (below) |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 0 warnings both runs; band files 1 → 7 |

**Complexity is reported in full**, from `manifest.json`'s `suites.complexity`:

| Metric | Value |
|---|---|
| Total NLOC | 35364 |
| Functions | 3900 |
| Avg NLOC / function | 8.1 |
| Avg CCN | 2.6 |
| Max CCN | 15 |
| Avg tokens / function | 78.3 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 7 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The run is sighted (`blindFiles` 0) and nothing crashed (`crashedFiles` 0), so every function was
measured. The zero warnings are the result of this branch's refactor work: the review of 2026-10-25
(`docs/reviews/2026-10-25/01_FINDINGS.md`, F-002) measured 19 functions above 15, max 30, on
`18a2b55`; the four code tracks split each one into named helpers or a data table with no behavior
change (RA-02).

Every suite is a clean pass, so there is no failure paragraph to write.

## What moved

- **lint:** in-scope files 109 → 140 ([`lint.txt`](lint.txt)); still 0 warnings / 0 errors.
- **tests:** 687 → 1176 cases ([`tests.txt`](tests.txt)), 686 → 1175 passed; the one declared skip
  is unchanged. The jump spans 338 commits of feature work (the callout popup, the icon browser,
  nested groups, the dial rework, the shine overlay, keybindings, the settings layout and this
  branch's fixes) less the Share suites removed on 2026-10-25.
- **perf** ([`perf.json`](perf.json) against the previous bundle's `perf.json`): `padRebuild12`
  69960.4 → 66191.4 bytes/iter, `dialOpenClose` 1159.3 → 1984.9, `situationRefresh` 1376.0 → 2016.0,
  both dial-pointer scenarios 120.0 → 224.0; `bracketCaptureOff` 0.0 both runs; notes/iter unchanged
  for every scenario. Every scenario is under the ceiling `tests/perf.lua` asserts (the runner passed).
  The pad figure fell because a rebuild no longer repaints an unchanged button shine, and the dial's
  because a reopen no longer re-places an unmoved slice highlight (RA-01); the rises against the
  2026-10-14 run are the features added since (`docs/performance.md`, the re-measure note).
- **complexity:** NLOC 19073 → 35364, functions 2364 → 3900, avg NLOC 7.2 → 8.1, avg CCN 2.5 → 2.6,
  avg tokens 65.1 → 78.3, max CCN 15 both runs, warnings 0 both runs, band files 1 → 7, over-cap 0
  both runs, blind files 0 both runs. The previous manifest has no `crashedFiles` field (an older kit).

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `locales/enUS.lua` | 1348 | Accepted: flat data, one key per player-facing string, no logic. |
| 1000–1500 (on notice) | `modules/Library.lua` | 1340 | On notice by design (the registry writer); peel the seeding and restore section if it nears 1,500. |
| 1000–1500 (on notice) | `tests/test_dial.lua` | 1472 | Peel next: split along its groupings before it takes another case. |
| 1000–1500 (on notice) | `tests/test_library.lua` | 1057 | Accepted: case count, not tangle. |
| 1000–1500 (on notice) | `tests/test_pad.lua` | 1030 | Accepted: case count, not tangle. |
| 1000–1500 (on notice) | `tests/test_page_groups.lua` | 1131 | Accepted: split on 2026-10-25 from 1,500. |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1024 | Accepted: one stub per client API the addon reads. |

Six of the seven are newly in the band since the previous run (only `modules/Library.lua` was there);
their dispositions are ruled in `RESULTS.md` for the first time with this run.

## Actions

1. `tests/test_dial.lua`: split it along its own groupings before it takes another case (new here; no
   review finding or deviation id owns it yet).
