# Automated test results

<!-- Regenerated whole by tests/_kit/run-automated-tests.sh on every run. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->
<!-- Everything here is generated EXCEPT the watch list's Disposition column. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

**`lint` and `tests` gate the run and gate the commit** (`testing-§4`).
**`perf` and `complexity` never fail a run and never block a commit** — they are recorded,
read and compared, not thresholded (`performance-§9`, `performance-§10`).

**The tag is gated on all four suites at `pass`, plus zero functions above CCN 15**
(`automated-tests-§3`, *The release gate*), evaluated by `/dev-copilot:bump-version` from the
`manifest.json` the release run writes — not by this script, whose exit code is unchanged.

A `skip` is a suite that did not run at all. It is never a pass, and at the release gate it is
**NOT EVALUATED** rather than passed: install the tool and re-run. A `—` is a suite that was
not selected, which is a different fact again.

The **Tests** cell reads `passed/skipped/total`.

**Commit** is the short sha the run measured and **Tree** is whether that tree was clean at the
time. Both are read from git by the runner; neither is ever typed. A **dirty** row measured bytes
that no sha can bring back, so it is kept as an experiment honestly labeled rather than dropped —
and a release record is refused outright on a dirty tree, so no release row can be one.

A row reading `unknown` in both cells was recorded before the runner emitted them. That is what
the record holds about those runs — it is not `clean`, and it is not reconstructed from git
archaeology, for the same reason a skip is never a pass (`automated-tests-§4`).

| Run | Commit | Tree | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20261014-002540`](20261014-002540/) | `6cc22be` | clean | 0.1.0 | 0/0 | 109 | 686/1/687 | pass | 19073 | 2364 | 7.2 | 2.5 | 15 | 0 | **green** |
| [`20261013-094801`](20261013-094801/) | `fdf7756` | clean | 0.1.0 → 0.1.0 | 0/0 | 37 | 136/1/137 | pass | 2632 | 477 | 4.4 | 2.0 | 13 | 0 | **green** |

## Test suite

**687 cases** — 686 passed, 0 failed, 1 skipped. The generated inventory
[`20261014-002540/test-cases.md`](20261014-002540/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **137 → 687** since the previous run.

**1 case(s) reported a `skip`.** A skip is counted in the total and never in `passed`, and at
the release gate it is NOT EVALUATED rather than passed (`automated-tests-§3`).

## Lint

**0 warnings / 0 errors over 109 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` excludes 7 path(s) from it — `libs/`, `docs/audits/`, `docs/reviews/`, `docs/revendor/`, `docs/brainstorm/`, `_dev/`, `tests/_kit/` —
so nothing under them is in the count above. A `0/0` that never moves is partly a statement about
what was never looked at, which is why the exclusions are NAMED here on every run rather than left
to whoever thinks to open `.luacheckrc`.

## Perf

**6 scenarios** from `tests/perf.lua`; the measurements are in
[`20261014-002540/perf.json`](20261014-002540/perf.json).

| `scenario` | `iters` | `ms/iter` | `notes/iter` | `bytes/iter` |
|---|---|---|---|---|
| `bracketCaptureOff` | 1000 | 0.00002 | 0.00 | 0.0 |
| `dialPointerCaptureOff` | 1000 | 0.00143 | 0.00 | 120.0 |
| `dialPointerNoHarness` | 1000 | 0.00152 | 0.00 | 120.0 |
| `padRebuild12` | 200 | 0.35704 | 3.00 | 69960.4 |
| `dialOpenClose` | 200 | 0.01252 | 1.00 | 1159.3 |
| `situationRefresh` | 500 | 0.00592 | 1.00 | 1376.0 |

`perf` never fails a run and never blocks a commit — it is recorded, read and compared, not
thresholded (`performance-§9`). It does gate the **tag** (`automated-tests-§3`).

## Complexity watch list

Current as of [`20261014-002540`](20261014-002540/) — **this run's measurement, not its diff.** Max CCN **15** across 2364
functions, **0** of them warned on; 1 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Library.lua` | 1017 | On notice: the registry writer holds every membership, order, id and reference write by design (architecture-§5), and phase 5 added Import and the Look's defaults; no peel planned for v0.1.0. If it nears 1,500, peel the import section (`newSurface`, `importMembers`, `importSurface`, `Lib.Import`) into `modules/Library_Import.lua`. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

