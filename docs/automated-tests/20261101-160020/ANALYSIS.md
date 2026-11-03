# Analysis — 20261101-160020

- **Addon:** QuickComms 1.0.0
- **Verdict:** green
- **Commit:** `12afcd3` (feat/2026-11-01-full-skinning)
- **Previous run:** `20261101-030530` (`d16c027`)

## Headline

Green on a clean tree: all four suites pass ([`manifest.json`](manifest.json)). This is the first run over LibKa0s
v1.85.0, the animations (#13), the raised pads (#14) and the full skin (FS-QC-FLIP, FS-QC-FIX). Two things to read: the
`dialOpenClose` ceiling moved to the ghost's measured cost, and `R.SkinFor` reached CCN 16 on an unkept run of this same
branch, fixed in `12afcd3` before this one, so max CCN stands at the release ceiling of 15.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-030530 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 157 files | [`lint.txt`](lint.txt) | 151 → 157 files |
| tests | pass | 1420 passed, 1 skipped, 0 failed, 1421 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1304 → 1421 cases |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | `dialOpenClose` and `padRebuild12` rose, below |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 4230 → 4552 functions, averages flat |

**Complexity is reported in full**, from `manifest.json`'s `suites.complexity`:

| Metric | Value |
|---|---|
| Total NLOC | 40490 |
| Functions | 4552 |
| Avg NLOC / function | 8.0 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 77.5 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 6 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**tests** is a pass with one case-level skip, the case the previous run also skipped: the diagnostics contract case for
an addon that opts out ([`tests.txt`](tests.txt)). It is counted in neither the passed nor the failed figure.

## What moved

- **lint:** 151 → 157 files, 0/0 both times. The new files are this branch's new suites and modules.
- **tests:** 1304 → 1421 cases, none failing: the animation suites, `test_anim_ghost.lua`, `test_skin_flip.lua` and kit
  revision 49's own cases.
- **perf:** `dialOpenClose` 1984.9 → 43116.8 bytes/iter and 0.05175 → 0.19556 ms/iter: two ghost captures per open and
  close, #13's, and it now sits under the raised 46080 ceiling (`tests/perf.lua` says why). `padRebuild12` 65745.4 →
  68305.4 bytes/iter, S.HudFont's calls and the flip's token reads, under its 70656 ceiling with one refilled opts table.
  The other four scenarios kept their `bytes/iter`, but for run-to-run timing.
- **complexity:** NLOC 37829 → 40490 and 4230 → 4552 functions, avg CCN 2.5 and avg NLOC 8.0 unchanged, avg tokens 77.3 →
  77.5: the addon grew, it did not get denser. Warnings 0, band files 6, over cap 0, blind and crashed files 0.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `locales/enUS.lua` | 1418 | Accepted, carried forward |
| 1000–1500 (on notice) | `modules/Library.lua` | 1344 | On notice, carried forward |
| 1000–1500 (on notice) | `tests/test_library.lua` | 1057 | Accepted, carried forward |
| 1000–1500 (on notice) | `tests/test_pad.lua` | 1041 | Accepted, carried forward |
| 1000–1500 (on notice) | `tests/test_page_groups.lua` | 1131 | Accepted, carried forward |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1063 | Accepted, carried forward |

Nothing newly crossed and no Disposition arrived blank; the full text of each is in `RESULTS.md`.

## Actions

1. Carried from `20261101-030530`: the 240.0 bytes/iter `padRebuild12` rise before this branch stays unattributed. This
   run's larger rise is the flip's.
2. Owner smoke: FSKIN-1 to FSKIN-11, SKIN-5, SKIN-11, SKIN-12, SKIN-13, ANIM-1 to ANIM-10 and LAYER-6 to LAYER-9
   (`docs/smoke-tests.md`).
