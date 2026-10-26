# Analysis — 20261026-113818

- **Addon:** QuickComms 0.1.0 (release run for 1.0.0)
- **Verdict:** green
- **Commit:** `cdfb373` (master)
- **Previous run:** `20261025-214031` (`a3afba3`)

## Headline

This is the release run for v1.0.0, the first release. All four suites pass on a clean tree
([`manifest.json`](manifest.json)): no function is above CCN 15, and `lizard` saw every file
(`blindFiles` 0, `crashedFiles` 0), so the release gate holds. Nothing moved since the previous run
apart from timing noise in two perf scenarios. Their bytes per iteration are identical. Nothing to act
on beyond the standing `tests/test_dial.lua` split.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261025-214031 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 140 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 1176 passed, 1 skipped, 0 failed, 1177 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | bytes/iter unchanged; ms/iter noise |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | unchanged |

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
- **tests:** 1177 cases, 1176 passed, the one declared skip unchanged ([`tests.txt`](tests.txt)).
  The two commits since the previous run (`fc088e1`, `cdfb373`) changed only docs and the README.
- **perf:** bytes/iter and notes/iter identical in all six scenarios ([`perf.json`](perf.json)).
  `padRebuild12` went from 0.36685 to 0.44247 ms/iter and `dialOpenClose` from 0.03457 to
  0.06220. No code changed between the two runs, so this is host timing noise and not a regression.
  The bytes figures, which do not depend on the host, agree.
- **complexity:** every figure unchanged: NLOC, functions, all averages, max CCN, warnings, the band
  and over-cap counts, and blind and crashed files ([`complexity.txt`](complexity.txt)).

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None. A passing release gate leaves this table empty by construction.

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

The same seven files at the same line counts. Nothing newly crossed. This is the first release run, so
each Accepted entry has been carried through one release run, well inside the three-release shelf
life. The `modules/Library.lua` disposition in `RESULTS.md` now says v1.0.0 where it said v0.1.0,
because the planned release was renumbered.

## Preview and simulation data

- **Answer:** Current
- **Asked:** 2026-10-26, by `/dev-copilot:bump-version`
- **Files reviewed:** test-mode and preview data in `modules/Preview.lua`, `modules/PreviewWindow.lua`,
  `modules/Surfaces.lua` (`TestPlan`, `TestDialPlan`, `TEST_COUNTS`) and `settings/Groups.lua`. Their
  suites are `tests/test_preview.lua`, `tests/test_edit_preview.lua` and `tests/test_preview_window.lua`.
  The addon has no simulator. `tools/render-shine-preview.lua` and `.py` matched by name but are
  offline art tooling, so they were left out.
- **Commits since the previous release touching them:** 88. There is no earlier release or tag, so
  this counts the whole history, during which 277 commits touched `core/`, `modules/` or `settings/`.
- **Note:** The owner confirmed the data current. The 2026-10-25 work set Preview as to the season's
  dungeons and raids and test mode to four groups of 4, 8, 12 and 16.

## Actions

1. `tests/test_dial.lua`: split it along its groupings before it takes another case. This action
   carries over from the previous run.
