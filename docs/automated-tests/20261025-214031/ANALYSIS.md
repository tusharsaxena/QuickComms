# Analysis — 20261025-214031

- **Addon:** QuickComms 0.1.0
- **Verdict:** green
- **Commit:** `a3afba3` (master), dirty
- **Previous run:** `20261025-200510` (`aacdc1d`)

## Headline

All four suites pass ([`manifest.json`](manifest.json)), and nothing moved except one new test case
and 27 lines of code. The tree was **dirty**: the two in-game perf bundles under
`docs/perf-analysis/` and their README index were staged but not committed. None of the four suites
reads `docs/`, so the measured bytes are those of `a3afba3`, but the row stays labeled dirty, as the
record requires. Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261025-200510 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 140 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 1176 passed, 1 skipped, 0 failed, 1177 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +1 case (1175 → 1176 passed) |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | bytes/iter unchanged in every scenario |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | +27 NLOC, +3 functions; averages unchanged |

**Complexity in full**, from `manifest.json`'s `suites.complexity`:

| Metric | Value |
|---|---|
| Total NLOC | 35391 |
| Functions | 3903 |
| Avg NLOC / function | 8.1 |
| Avg CCN | 2.6 |
| Max CCN | 15 |
| Avg tokens / function | 78.4 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 7 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The run is sighted (`blindFiles` 0) and `lizard` raised on nothing (`crashedFiles` 0), so every
function was measured.

Every suite is a clean pass, so there is no failure paragraph to write.

## What moved

- **lint:** 140 files, 0/0, as before.
- **tests:** 1176 → 1177 total, 1175 → 1176 passed, the one declared skip unchanged
  ([`tests.txt`](tests.txt)). The new case is the shine-folder test that came with the
  `media/textures/` reorganization (`shine: [folders] …` in [`test-cases.md`](test-cases.md)). One
  more case was renamed, not added: the TOC case now names the CurseForge id.
- **perf:** bytes/iter identical to the previous run for all six scenarios ([`perf.json`](perf.json)):
  `padRebuild12` 66191.4, `dialOpenClose` 1984.9, `situationRefresh` 2016.0, both dial-pointer
  scenarios 224.0, `bracketCaptureOff` 0.0. Notes/iter unchanged. The texture move changed paths, not
  work, and the figures agree.
- **complexity:** NLOC 35364 → 35391, functions 3900 → 3903, avg tokens 78.3 → 78.4; avg NLOC, avg
  CCN, max CCN, warnings, band and over-cap counts, and blind and crashed files all unchanged. The
  three new functions are `Sh.Folder` in `modules/Shine.lua`, the new test's `dir` helper and the
  new test itself ([`complexity.txt`](complexity.txt)).

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `locales/enUS.lua` | 1348 | Accepted (carried forward) |
| 1000–1500 (on notice) | `modules/Library.lua` | 1340 | On notice by design (carried forward) |
| 1000–1500 (on notice) | `tests/test_dial.lua` | 1472 | Peel next (carried forward) |
| 1000–1500 (on notice) | `tests/test_library.lua` | 1057 | Accepted (carried forward) |
| 1000–1500 (on notice) | `tests/test_pad.lua` | 1030 | Accepted (carried forward) |
| 1000–1500 (on notice) | `tests/test_page_groups.lua` | 1131 | Accepted (carried forward) |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1024 | Accepted (carried forward) |

The same seven files at the same line counts as the previous run. Nothing newly crossed, so every
disposition carried forward unchanged. None is near the three-release shelf life: v0.1.0 has not
been released, so no release run has carried any of them.

## Actions

1. `tests/test_dial.lua`: still the one to split before it takes another case, carried from the
   previous run's actions.
