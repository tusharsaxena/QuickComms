# Analysis — 20261013-094801

- **Addon:** QuickComms 0.1.0
- **Verdict:** green
- **Commit:** fdf7756 (main)
- **Previous run:** none — this is the first

## Headline

The first recorded run, taken on the freshly scaffolded tree: all four suites pass, nothing is
warned on, and no file is near the line cap. It is the baseline every later release diffs against.
Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since none |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 37 files | [`lint.txt`](lint.txt) | first run |
| tests | pass | 136 passed, 1 skipped, 0 failed, 137 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | first run |
| perf | pass | 1 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | first run |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | first run |

| Metric | Value |
|---|---|
| Total NLOC | 2632 |
| Functions | 477 |
| Avg NLOC / function | 4.4 |
| Avg CCN | 2.0 |
| Max CCN | 13 |
| Avg tokens / function | 34.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

The one skipped case is the kit's diagnostics-contract opt-out case, which applies only to an
addon that sets `diagnosticsEnablesLogging = false`; this addon keeps the default, and the case
beside it covers that path ([`tests.txt`](tests.txt)). It is a declared skip, not a gap.

`perf` ran one scenario, `bracketCaptureOff`: the gated bracket against the live harness with capture
off, at 0.0 bytes and 0.00 notes per iteration ([`perf.txt`](perf.txt)). The scaffold has no hot path
yet, so this is the zero-overhead baseline only.

The highest CCN, 13, is `NS.RunMigrations` in `core/Database.lua` ([`complexity.txt`](complexity.txt)):
under the 15 gate, and mostly `and`/`or` guards rather than branching. The complexity figures include
the go/no-go harness under `docs/brainstorm/` (lizard's own scope), whose two functions score 12.

## What moved

First run — nothing to diff against; every figure below is a baseline reading.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|

None.

## Actions

None.
