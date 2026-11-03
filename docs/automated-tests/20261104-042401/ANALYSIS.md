# Analysis — 20261104-042401

- **Addon:** QuickComms 1.0.0
- **Verdict:** green
- **Commit:** `7455a75` (feat/2026-11-01-full-skinning), clean
- **Previous run:** `20261102-005112` (`e015b6d`)

## Headline

Green: all four suites pass ([`manifest.json`](manifest.json)). This is the round 6 finish run (R6-AT) of the full skinning branch, 27 commits after the previous record: rounds 3 to 6 of skin fixes (window header bands, icon crop and edge, the skin picker's preview eye, the README rename) and five LibKa0s v1.85.0 re-cuts. Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261102-005112 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 164 files | [`lint.txt`](lint.txt) | 161 → 164 files, still 0/0 |
| tests | pass | 1729 passed, 1 skipped, 0 failed, 1730 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1699 → 1730 cases |
| perf | pass | 6 scenarios (recorded; gates the tag, not the commit) | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | `padRebuild12` bytes/iter 67969.5 → 68081.5; the rest unchanged |
| complexity | pass | 0 warnings (recorded; gates the tag, not the commit) | [`complexity.txt`](complexity.txt) | see below |

| Metric | Value |
|---|---|
| Total NLOC | 44043 |
| Functions | 4977 |
| Avg NLOC / function | 8.0 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 78.3 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 7 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The one skipped case is the same diagnostics opt-out case as in every earlier run: this addon keeps the default (`Kit.diagnostics.enablesLogging` is not false), so the opt-out branch does not apply ([`tests.txt`](tests.txt)).

## What moved

- **lint:** 161 → 164 files in scope, 0/0 unchanged. The new files are the round 4 and 5 test files (for example `tests/test_window_icons.lua`).
- **tests:** 1699 → 1730 (+31). The cases come from the window header bands, the icon crop and edge checks, the no-line-under-the-title checks, the skin picker preview eye (R6-PV) and the cases repinned by the LibKa0s re-cuts.
- **perf:** `padRebuild12` 67969.5 → 68081.5 bytes/iter (+112, about 0.2 percent, consistent with the pad's header band from R5-QC1). `dialOpenClose` 46028.1, `situationRefresh` 2016.0 and both dial-pointer scenarios at 224.0 are unchanged. `bracketCaptureOff` stays at 0 bytes. Timing moved with the host, as usual ([`perf.json`](perf.json)).
- **complexity:** NLOC 43233 → 44043, functions 4880 → 4977, avg NLOC 8.0 and avg CCN 2.4 unchanged, max CCN 15 unchanged. The addon grew without getting denser.

## Complexity watch list

No function warned.

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `locales/enUS.lua` | 1431 | Accepted: flat data, one key per player-facing string. |
| 1000–1500 (on notice) | `modules/Library.lua` | 1342 | On notice: registry writer by design; peel plan named in `RESULTS.md`. |
| 1000–1500 (on notice) | `tests/test_library.lua` | 1057 | Accepted: case count, not tangle. |
| 1000–1500 (on notice) | `tests/test_pad.lua` | 1047 | Accepted: case count, not tangle (1041 → 1047). |
| 1000–1500 (on notice) | `tests/test_page_groups.lua` | 1131 | Accepted: split on 2026-10-25 (RA-09). |
| 1000–1500 (on notice) | `tests/test_skin_flip.lua` | 1064 | Accepted: case count, not tangle (1062 → 1064). No longer newly crossed, so `RESULTS.md` now says Accepted. |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1084 | Accepted: one client API per stub (1077 → 1084). |

Same seven files on notice and none over the cap. No file is near 1,400.

## Actions

None.
