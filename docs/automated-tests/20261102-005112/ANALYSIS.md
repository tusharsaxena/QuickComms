# Analysis — 20261102-005112

- **Addon:** QuickComms 1.0.0
- **Verdict:** green
- **Commit:** `e015b6d` (feat/2026-11-01-full-skinning)
- **Previous run:** `20261101-210705` (`32bf98d`)

## Headline

Green: all four suites pass ([`manifest.json`](manifest.json)). This run records SF-QC-1 to SF-QC-3: Scale in and out merged into Scale (schema step 17), the spiral labels swapped, and the WoW Default pad window on the dialog border art.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-210705 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 161 files | [`lint.txt`](lint.txt) | none |
| tests | pass | 1698 passed, 1 skipped, 0 failed, 1699 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1711 → 1699 cases |
| perf | pass | 6 scenarios (recorded, non-gating) | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | `bytes/iter` unchanged |
| complexity | pass | 0 warnings (recorded, non-gating) | [`complexity.txt`](complexity.txt) | see below |

| Metric | Value |
|---|---|
| Total NLOC | 43233 |
| Functions | 4880 |
| Avg NLOC / function | 8.0 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 78.3 |
| Warnings (CCN > 15) | 0 |
| Warning rate | 0.00 / 0.00 |
| Files in the 1000–1500 band | 7 |
| Files over the 1500 cap | 0 |
| Blind files | 0 |
| Crashed files | 0 |

The one skipped case is the same diagnostics opt-out case as before.

## What moved

- **tests:** 1711 → 1699. The scaleOut and scaleOutFade style cases went with the retired styles; step 17 and the WoW window border gained cases.
- **perf:** `padRebuild12` 67969.5 and `dialOpenClose` 46028.1 bytes/iter, both as before. Timing moved with the run.
- **complexity:** NLOC 43181 → 43233, functions 4878 → 4880, avg CCN 2.4 unchanged: grown, not denser.

## Complexity watch list

No function warned. The file bands are in [`RESULTS.md`](RESULTS.md) and unchanged: seven on notice, none over the cap.
