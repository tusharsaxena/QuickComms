# Analysis — 20261014-002540

- **Addon:** QuickComms 0.1.0
- **Verdict:** green
- **Commit:** 6cc22be (feat/phase-5-share-release)
- **Previous run:** 20261013-094801

## Headline

The phase 5 release-gate run, a release **candidate** record (label `phase-5-release-gate`, not a
`--release` run: the version is unbumped and no tag is cut). All four suites pass on a clean tree,
no function is above CCN 15 and no file is blind, so the release gate's conditions hold at this
commit ([`manifest.json`](manifest.json)). One file, `modules/Library.lua`, newly entered the
1000–1500 on-notice band and has its disposition below; nothing else is owed.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261013-094801 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 109 files | [`lint.txt`](lint.txt) | files 37 → 109; still 0/0 |
| tests | pass | 686 passed, 1 skipped, 0 failed, 687 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 137 → 687; skipped 1 → 1 |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | scenarios 1 → 6 |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | see What moved |

| Metric | Value |
|---|---|
| Total NLOC | 19073 |
| Functions | 2364 |
| Avg NLOC / function | 7.2 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 65.1 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

Complexity is sighted (`blindFiles` 0 in [`manifest.json`](manifest.json)) and passes. The maximum,
15, sits exactly at the gate, not above it: seven functions score 15 in
[`complexity.txt`](complexity.txt) — `R.SkinFor` (`modules/Pad_Render.lua`), `Pad.Apply`
(`modules/Pad.lua`), `S.ApplyAll` (`modules/Surfaces.lua`), `groupEntry` (`modules/Share.lua`),
`Lib.MoveGenericBattlegroundLast` (`modules/Library.lua`), `W.Describe`
(`settings/Groups_When.lua`) and an anonymous test body in `tests/test_members.lua`. None is
warned on; they are the first to cross if they grow, so a change to any of them should be read
against the gate.

The one skipped case is the same declared skip as the previous run: the kit's diagnostics-contract
opt-out case, which applies only to an addon that sets `diagnosticsEnablesLogging = false`; this
addon keeps the default and the case beside it covers that path ([`tests.txt`](tests.txt)).

`perf` ran six scenarios ([`perf.txt`](perf.txt)). The two capture-off brackets
(`bracketCaptureOff` at 0.0 bytes and 0.00 notes per iteration, `dialPointerCaptureOff`) and the
no-harness pointer (`dialPointerNoHarness`, 120.0 bytes per iteration like the captured one) pin the
zero-overhead path; `padRebuild12` (69960.4 bytes per iteration), `dialOpenClose` and
`situationRefresh` pin the pad rebuild, the dial and the situation refresh. Timings are for
orientation only.

## What moved

- **lint** — still 0 / 0, over 109 files against 37: the addon grew from the scaffold through
  phases 2 to 5; the `.luacheckrc` exclusions are unchanged (seven paths, named in `RESULTS.md`).
- **tests** — 137 → 687 cases, 0 failures both runs; the one skip is unchanged.
- **perf** — 1 → 6 scenarios. `bracketCaptureOff` is unchanged at 0.0 bytes and 0.00 notes per
  iteration; the other five are new and are baselines here.
- **complexity** — total NLOC 2632 → 19073 and functions 477 → 2364 (growth). Avg NLOC per
  function 4.4 → 7.2, avg CCN 2.0 → 2.5 and avg tokens 34.6 → 65.1: functions got somewhat denser,
  as real logic replaced scaffold stubs, but the average stays low. Max CCN 13 → 15, warnings 0 → 0,
  blind files 0 → 0.
- **band** — 0 → 1 file in the 1000–1500 band: `modules/Library.lua` at 1017 lines, newly crossed.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Library.lua` | 1017 | **Newly crossed.** On notice: the registry writer holds every membership, order, id and reference write by design (architecture-§5), and phase 5 added Import and the Look's defaults; no peel planned for v0.1.0. If it nears 1,500, peel the import section (`newSurface`, `importMembers`, `importSurface`, `Lib.Import`) into `modules/Library_Import.lua`. |

## Actions

None. The `modules/Library.lua` band entry is ruled on above (on notice, with a named peel if it
nears the cap). The owner's release step (`/dev-copilot:bump-version 0.1.0`) makes its own release
run; this bundle is not that record.
