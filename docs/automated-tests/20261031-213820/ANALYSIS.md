# Analysis — 20261031-213820

- **Addon:** QuickComms 1.0.0
- **Verdict:** green
- **Commit:** `e63dad2` (feat/2026-10-31-findings-remediation)
- **Previous run:** `20261031-202243` (`15dde36`)

## Headline

The post-remediation run is green on a clean tree: all four suites pass ([`manifest.json`](manifest.json)).
The two findings the previous run left open both moved the right way: `padRebuild12` allocations fell from
66528.4 to 65505.4 bytes per iteration ([`perf.json`](perf.json)), and `tests/test_dial.lua` left the
1000–1500 band, taking it from 7 files to 6. Nothing is left to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261031-202243 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 151 files | [`lint.txt`](lint.txt) | files 148 → 151; still clean |
| tests | pass | 1298 passed, 1 skipped, 0 failed, 1299 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 1298 → 1299; the same one skip |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 6 scenarios; `padRebuild12` bytes down, see below |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC and functions up slightly, averages unchanged, band 7 → 6 |

**Complexity is reported in full**, from `manifest.json`'s `suites.complexity`:

| Metric | Value |
|---|---|
| Total NLOC | 37776 |
| Functions | 4226 |
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

**tests** is a pass with one case-level skip, the same case as the previous run: the diagnostics contract
case for an addon that opts out, which does not apply because this addon keeps the default
([`tests.txt`](tests.txt)). The skip is counted in neither the passed nor the failed figure. It is a
pre-existing condition.

## What moved

- **lint:** 148 → 151 files, 0/0 both times. The three new files are `tests/dial_helpers.lua`,
  `tests/test_dial_catcher.lua` and `tests/test_dial_look.lua`, from the dial suite split.
- **tests:** 1298 → 1299 cases, 1297 → 1298 passed, 0 failed both times, skip count unchanged at 1. By case
  name against the previous [`tests.txt`](../20261031-202243/tests.txt), one case is new and none is gone: `skin
  hud: a pad's window is repainted when its look or the skin moved, and at no other rebuild`. The dial split
  moved cases between files without changing any case's name.
- **perf:** the same 6 scenarios ([`perf.json`](perf.json)). `padRebuild12` allocations 66528.4 → 65505.4
  bytes/iter, the one allocation that moved, and the result of `aa5be55`, which keeps a pad window's skin while
  its look holds. Every other `bytes/iter` and every `notes/iter` is unchanged. All six timings fell:
  `bracketCaptureOff` 0.00004 → 0.00002, `dialPointerCaptureOff` 0.00533 → 0.00308, `dialPointerNoHarness`
  0.00535 → 0.00272, `padRebuild12` 0.75827 → 0.40603, `dialOpenClose` 0.09640 → 0.03311 and
  `situationRefresh` 0.01327 → 0.00673 ms/iter. Every suite ran faster as well (tests 128909 → 88632 ms,
  complexity 7552 → 3363 ms), so the timing fall reads as machine load, not as code getting cheaper, and only
  the byte figure is evidence of a change. Perf is recorded, not thresholded.
- **complexity:** NLOC 37722 → 37776 and functions 4221 → 4226. Avg NLOC 8.0, avg CCN 2.5 and avg tokens 77.3
  did not move. Max CCN stays 15 and warnings stay 0. Band count 7 → 6, over cap stays 0, blind and crashed
  files stay 0.

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

Nothing newly crossed and no Disposition arrived blank; the full text of each is in `RESULTS.md`. This is not
a release run, so no Accepted entry advanced toward the three-run limit.

## Actions

None. The previous run's one action, splitting `tests/test_dial.lua`, is done: the file is out of the band.
