# Analysis — 20261101-210705

- **Addon:** QuickComms 1.0.0
- **Verdict:** green
- **Commit:** `32bf98d` (feat/2026-11-01-full-skinning)
- **Previous run:** `20261101-203759` (`00db040`)

## Headline

Green on a clean tree: all four suites pass ([`manifest.json`](manifest.json)). This run records `FS-QC-FIX`, the owner's pad looks merged onto the re-cut LibKa0s v1.85.0. Max CCN stays at 15: the merge put `Sh.Resolve` at 16, so its Strength read moved into a helper before this run. Nothing else moved past a threshold.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-203759 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 161 files | [`lint.txt`](lint.txt) | 160 → 161 files |
| tests | pass | 1710 passed, 1 skipped, 0 failed, 1711 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1691 → 1711 cases |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | no `bytes/iter` moved |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 4851 → 4878 functions, avg CCN 2.4 unchanged |

**Complexity is reported in full**, from `manifest.json`'s `suites.complexity`:

| Metric | Value |
|---|---|
| Total NLOC | 43181 |
| Functions | 4878 |
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

**tests** is a pass with one case-level skip, the same case as the previous run: the diagnostics contract case for an addon that opts out ([`tests.txt`](tests.txt)). It is counted in neither the passed nor the failed figure. The two vendor-sync cases pass ([`tests.txt`](tests.txt), lines 1633 and 1634).

## What moved

- **lint:** 160 → 161 files, the new `tests/test_pad_looks.lua`; 0/0 both times.
- **tests:** 1691 → 1711 cases, none failing. `tests/test_pad_looks.lua` accounts for the rise, one pass over the vendored library now that its double run is gone.
- **perf:** every scenario kept its `bytes/iter`: `dialOpenClose` 46028.1 and `padRebuild12` 67969.5, so `dialOpenClose` stays 51.9 bytes/iter under its ceiling. Timing moved with the run, not the code: `dialOpenClose` 0.24392 → 0.27787 ms/iter, `padRebuild12` 0.38732 → 0.47121 ms/iter.
- **complexity:** NLOC 42988 → 43181 and 4851 → 4878 functions, avg CCN 2.4, avg NLOC 8.0 and avg tokens 78.2 unchanged. The addon grew and did not get denser. Warnings 0, band files 7, over cap 0, blind and crashed files 0.

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
| 1000–1500 (on notice) | `tests/test_skin_flip.lua` | 1062 | Carried forward, 1061 → 1062 |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1077 | Accepted, carried forward |

The full text of each is in `RESULTS.md`.

## Actions

1. `dialOpenClose` is 51.9 bytes/iter under its ceiling: read the next rise before moving that ceiling, since a pin must not move bare. Carried.
2. Carried from `20261101-030530`: the 240.0 bytes/iter `padRebuild12` rise before this branch stays unattributed.
3. Owner smoke: PLOOK-1 to PLOOK-11, BUTTON-1 and SHINE-1 are owed on top of the FSKIN, SKIN and ANIM checks (`docs/smoke-tests.md`).
