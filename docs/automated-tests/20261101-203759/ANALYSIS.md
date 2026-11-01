# Analysis — 20261101-203759

- **Addon:** QuickComms 1.0.0
- **Verdict:** green
- **Commit:** `00db040` (feat/2026-11-01-full-skinning)
- **Previous run:** `20261101-160020` (`12afcd3`)

## Headline

Green on a clean tree: all four suites pass ([`manifest.json`](manifest.json)). This run closes `FS-QC-GATE`: the re-cut LibKa0s v1.85.0 and kit revision 50, with the kit's typed-value check and probe-skin switch test adopted. Eleven commits landed since the previous run, the rest of them #13's dial animation styles and the review's mutation pins. Two things to read: `dialOpenClose` sits 51.9 bytes/iter under its 46080 ceiling, and `tests/test_skin_flip.lua` entered the 1000–1500 band.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-160020 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 160 files | [`lint.txt`](lint.txt) | 157 → 160 files |
| tests | pass | 1690 passed, 1 skipped, 0 failed, 1691 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1421 → 1691 cases |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | `dialOpenClose` rose, `padRebuild12` fell, below |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 4552 → 4851 functions, avg CCN 2.5 → 2.4 |

**Complexity is reported in full**, from `manifest.json`'s `suites.complexity`:

| Metric | Value |
|---|---|
| Total NLOC | 42988 |
| Functions | 4851 |
| Avg NLOC / function | 8.0 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 78.2 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 7 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**tests** is a pass with one case-level skip, the same case as the previous run: the diagnostics contract case for an addon that opts out ([`tests.txt`](tests.txt)). It is counted in neither the passed nor the failed figure.

## What moved

- **lint:** 157 → 160 files, 0/0 both times.
- **tests:** 1421 → 1691 cases, none failing. The kit's `test_skin_values` and `test_skin_switch` joined, and #13's styles and the mutation pins account for most of the rest.
- **perf:** `dialOpenClose` 43116.8 → 46028.1 bytes/iter and 0.19556 → 0.24392 ms/iter. `padRebuild12` 68305.4 → 67969.5 bytes/iter and under its 70656 ceiling; the shadow no longer builds a table per block once it goes by `shadowToken`. This run cannot split the `dialOpenClose` rise between #13's new styles and the re-vendor, so it is not attributed here. The other four scenarios kept their `bytes/iter`, but for run-to-run timing.
- **complexity:** NLOC 40490 → 42988 and 4552 → 4851 functions, avg CCN 2.5 → 2.4, avg NLOC 8.0 unchanged, avg tokens 77.5 → 78.2. The addon grew and did not get denser. Warnings 0, band files 6 → 7, over cap 0, blind and crashed files 0.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `locales/enUS.lua` | 1433 | Accepted, carried forward |
| 1000–1500 (on notice) | `modules/Library.lua` | 1342 | On notice, carried forward |
| 1000–1500 (on notice) | `tests/test_library.lua` | 1057 | Accepted, carried forward |
| 1000–1500 (on notice) | `tests/test_pad.lua` | 1041 | Accepted, carried forward |
| 1000–1500 (on notice) | `tests/test_page_groups.lua` | 1131 | Accepted, carried forward |
| 1000–1500 (on notice) | `tests/test_skin_flip.lua` | 1061 | Newly crossed: case count, not tangle; split at its section rules if it nears 1,400 |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1077 | Accepted, carried forward |

The full text of each is in `RESULTS.md`.

## Actions

1. `dialOpenClose` is 51.9 bytes/iter under its ceiling: read the next rise before moving that ceiling, since a pin must not move bare.
2. Carried from `20261101-030530`: the 240.0 bytes/iter `padRebuild12` rise before this branch stays unattributed.
3. Owner smoke: SKIN-6 and FSKIN-12 are new or changed by this run's gate, on top of the FSKIN, SKIN and ANIM checks already owed (`docs/smoke-tests.md`).
