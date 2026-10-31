# Analysis — 20261101-011157

- **Addon:** QuickComms 1.0.0
- **Verdict:** green
- **Commit:** `7519cd5` (feat/2026-10-31-findings-remediation)
- **Previous run:** `20261031-213820` (`e63dad2`)

## Headline

The LibKa0s v1.84.0 adoption run is green on a clean tree: all four suites pass ([`manifest.json`](manifest.json)).
The case count rose by five, all of them passing, and complexity held. One figure moved the wrong way:
`padRebuild12` allocations rose from 65505.4 to 65745.4 bytes per iteration ([`perf.json`](perf.json)), under the
70656 ceiling in `tests/perf.lua`, and this run does not say which commit caused it.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261031-213820 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 151 files | [`lint.txt`](lint.txt) | nothing moved |
| tests | pass | 1303 passed, 1 skipped, 0 failed, 1304 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 1299 → 1304; the same one skip |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 6 scenarios; `padRebuild12` bytes up, see below |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC and functions up slightly, averages unchanged |

**Complexity is reported in full**, from `manifest.json`'s `suites.complexity`:

| Metric | Value |
|---|---|
| Total NLOC | 37829 |
| Functions | 4230 |
| Avg NLOC / function | 8.0 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 77.3 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 6 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**tests** is a pass with one case-level skip, the same case as the previous run: the diagnostics contract case
for an addon that opts out, which does not apply because this addon keeps the default ([`tests.txt`](tests.txt)).
The skip is counted in neither the passed nor the failed figure. It is a pre-existing condition.

## What moved

- **lint:** did not move: 151 files, 0/0 both times.
- **tests:** 1299 → 1304 cases, 1298 → 1303 passed, 0 failed both times, skip count unchanged at 1. By case name
  against the previous [`tests.txt`](../20261031-213820/tests.txt), five names are net new: the four `layout:
  [position]` cases and `pads page: [shine] the blooms show only under Fluid glass, through the library
  (LibKa0s#67)`. Three `[glow knobs]` names were reworded, one on the dials page and two on the pads page. No
  coverage was lost by name.
- **perf:** the same 6 scenarios ([`perf.json`](perf.json)). `padRebuild12` allocations 65505.4 → 65745.4 bytes/iter,
  a rise of 240.0 and the one allocation that moved. Every other `bytes/iter` and every `notes/iter` is unchanged.
  Five of the six timings rose: `dialPointerCaptureOff` 0.00308 → 0.00336, `dialPointerNoHarness` 0.00272 → 0.00389,
  `padRebuild12` 0.40603 → 0.50343, `dialOpenClose` 0.03311 → 0.05095 and `situationRefresh` 0.00673 → 0.00823
  ms/iter; `bracketCaptureOff` stayed at 0.00002. Every suite took longer as well (tests 88632 → 93990 ms, complexity
  3363 → 3464 ms, perf 644 → 720 ms, lint 5153 → 5518 ms), so the timing rise reads as machine load, not as code
  getting dearer, and only the byte figure is evidence of a change. Perf is recorded, not thresholded.
- **complexity:** NLOC 37776 → 37829 and functions 4226 → 4230. Avg NLOC 8.0, avg CCN 2.5 and avg tokens 77.3 did
  not move. Max CCN stays 15 and warnings stay 0. Band count stays 6, over cap stays 0, blind and crashed files
  stay 0.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `locales/enUS.lua` | 1383 | Accepted, carried forward |
| 1000–1500 (on notice) | `modules/Library.lua` | 1340 | On notice, carried forward |
| 1000–1500 (on notice) | `tests/test_library.lua` | 1057 | Accepted, carried forward |
| 1000–1500 (on notice) | `tests/test_pad.lua` | 1037 | Accepted, carried forward |
| 1000–1500 (on notice) | `tests/test_page_groups.lua` | 1131 | Accepted, carried forward |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1024 | Accepted, carried forward |

Nothing newly crossed and no Disposition arrived blank; the full text of each is in `RESULTS.md`. This is not a
release run, so no Accepted entry advanced toward the three-run limit.

## Actions

1. New here: attribute the 240.0 bytes/iter `padRebuild12` rise to a commit between `e63dad2` and `7519cd5`
   before the next `tests/perf.lua` re-measure. It sits under the ceiling, so nothing needs to change until the
   cause is known. The range holds the v1.84.0 re-vendor and the `QC-ADOPT` and `QC-67` settings commits; no
   bisect was run here.
