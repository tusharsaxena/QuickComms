# Analysis — 20261101-030530

- **Addon:** QuickComms 1.0.0
- **Verdict:** green
- **Commit:** `d16c027` (feat/2026-10-31-findings-remediation)
- **Previous run:** `20261101-011157` (`7519cd5`)

## Headline

The final pre-merge run is green on a clean tree: all four suites pass ([`manifest.json`](manifest.json)). It is the
first run over the re-cut LibKa0s v1.84.0 and the `Ka0sMedia_*`-only media picker docs. No gated or complexity figure
moved, and no test case changed by name ([`tests.txt`](tests.txt)). One action carries over: the `padRebuild12` rise
the previous run recorded is still unattributed.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-011157 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 151 files | [`lint.txt`](lint.txt) | nothing moved |
| tests | pass | 1303 passed, 1 skipped, 0 failed, 1304 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | nothing moved; same case names, the same one skip |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 6 scenarios; `bytes/iter` and `notes/iter` unchanged, timings moved both ways |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | nothing moved |

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

**tests** is a pass with one case-level skip, the same case as the previous run: the diagnostics contract case for
an addon that opts out, which does not apply because this addon keeps the default ([`tests.txt`](tests.txt)). The
skip is counted in neither the passed nor the failed figure. It is a pre-existing condition.

## What moved

- **lint:** did not move: 151 files, 0/0 both times.
- **tests:** did not move: 1304 cases, 1303 passed, 1 skipped, 0 failed both times. The sorted case lines of
  [`tests.txt`](tests.txt) match the previous [`tests.txt`](../20261101-011157/tests.txt) exactly, and
  [`test-cases.md`](test-cases.md) is identical to the previous inventory.
- **perf:** the same 6 scenarios ([`perf.json`](perf.json)). Every `bytes/iter` and `notes/iter` is unchanged,
  including `padRebuild12` at 65745.4. Three timings fell: `dialPointerNoHarness` 0.00389 → 0.00374, `padRebuild12`
  0.50343 → 0.44362 and `situationRefresh` 0.00823 → 0.00646 ms/iter. Two rose: `dialPointerCaptureOff` 0.00336 →
  0.00393 and `dialOpenClose` 0.05095 → 0.05175 ms/iter. `bracketCaptureOff` stayed at 0.00002. With allocations flat
  and timings moving both ways, this reads as run-to-run variation, not a code change. Perf is recorded, not
  thresholded.
- **complexity:** did not move: NLOC 37829, 4230 functions, avg NLOC 8.0, avg CCN 2.5, max CCN 15, avg tokens 77.3,
  warnings 0, band files 6, over cap 0, blind and crashed files 0.

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

Nothing newly crossed and no Disposition arrived blank; the full text of each is in `RESULTS.md`.

## Actions

1. Carried from `20261101-011157`: attribute the 240.0 bytes/iter `padRebuild12` rise to a commit between `e63dad2`
   and `7519cd5` before the next `tests/perf.lua` re-measure. It sits under the 70656 ceiling, and this run did not
   move it. No bisect was run here.
