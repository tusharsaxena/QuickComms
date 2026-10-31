# Analysis — 20261031-202243

- **Addon:** QuickComms 1.0.0
- **Verdict:** green
- **Commit:** `15dde36` (feat/2026-10-31-font-pickers-skin-faces)
- **Previous run:** `20261026-113818` (`cdfb373`)

## Headline

The pre-merge run for the font pickers and skin faces branch is green on a clean tree: all four suites
pass ([`manifest.json`](manifest.json)). No function is above CCN 15, no file is over the 1500 cap, and
`lizard` saw every file (`blindFiles` 0, `crashedFiles` 0), so there are no CCN or NLOC flags to fix and
no code changed. Tests rose from 1177 to 1298 cases and the addon grew while its average CCN and average
function length both fell. The perf timings rose but the allocations did not, which reads as machine load.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261026-113818 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 148 files | [`lint.txt`](lint.txt) | files 140 → 148; still clean |
| tests | pass | 1297 passed, 1 skipped, 0 failed, 1298 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 1177 → 1298; the same one skip |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 6 scenarios; timings up, see below |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC and functions up, averages down |

**Complexity is reported in full**, from `manifest.json`'s `suites.complexity`:

| Metric | Value |
|---|---|
| Total NLOC | 37722 |
| Functions | 4221 |
| Avg NLOC / function | 8.0 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 77.3 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 7 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**tests** is a pass with one case-level skip, the same case as the previous run: the diagnostics contract
case for an addon that opts out, which does not apply because this addon keeps the default
([`tests.txt`](tests.txt)). The skip is counted in neither the passed nor the failed figure. It is a
pre-existing condition.

## What moved

- **lint:** 140 → 148 files, 0/0 both times. The `.luacheckrc` exclusions are the seven paths
  `RESULTS.md` lists.
- **tests:** 1177 → 1298 cases, 1176 → 1297 passed, 0 failed both times, skip count unchanged at 1. By case
  name against the previous [`tests.txt`](../20261026-113818/tests.txt), 132 cases are new and 11 are gone; ten of the
  removed ones are the `eui skin:` family, replaced by the `skin` cases, and one is a `profile` case.
- **perf:** the same 6 scenarios ([`perf.json`](perf.json)). `bracketCaptureOff` did not move (0.00004
  ms/iter, 0 bytes). `dialPointerCaptureOff` 0.00281 → 0.00533, `dialPointerNoHarness` 0.00294 → 0.00535,
  `padRebuild12` 0.44247 → 0.75827, `dialOpenClose` 0.06220 → 0.09640 and `situationRefresh` 0.00689 →
  0.01327 ms/iter. Allocations held: every `bytes/iter` is unchanged except `padRebuild12`, 66191.4 →
  66528.4, and `notes/iter` did not move. Every suite took longer too (tests 89108 → 128909 ms, complexity
  3298 → 7552 ms), and this run shared the machine with parallel batteries, so the timing rise reads as
  load and not as a code path getting heavier. Perf is recorded, not thresholded.
- **complexity:** NLOC 35391 → 37722 and functions 3903 → 4221, while avg NLOC 8.1 → 8.0, avg CCN 2.6 →
  2.5 and avg tokens 78.4 → 77.3. The growth is size, not density. Max CCN stays 15 and warnings stay 0.
  Band count stays 7, over cap stays 0.

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
| 1000–1500 (on notice) | `tests/test_dial.lua` | 1471 | Peel next, carried forward |
| 1000–1500 (on notice) | `tests/test_library.lua` | 1057 | Accepted, carried forward |
| 1000–1500 (on notice) | `tests/test_pad.lua` | 1037 | Accepted, carried forward |
| 1000–1500 (on notice) | `tests/test_page_groups.lua` | 1131 | Accepted, carried forward |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1024 | Accepted, carried forward |

Nothing newly crossed and no Disposition arrived blank; the full text of each is in `RESULTS.md`. Only two
release runs exist (0.1.0 and 1.0.0), so no Accepted entry has reached the three-run limit.

## Actions

1. `tests/test_dial.lua`: split it along its groupings before it takes another case. This action carries
   over from the previous run. The file is at 1471 lines, so its disposition's "28 lines under the cap"
   is now one line out; the ruling itself still holds.
