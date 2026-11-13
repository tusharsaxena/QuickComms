# 04 — Execution plan (review of 2026-11-11)

These tasks map onto the branch plan (`docs/superpowers/plans/2026-11-10-combined-actions.md`):
CA-M5-2 carries R1 to R5, and CA-M5-3 carries R6.

Ground rules for every task:

- The green gate before each commit: `lua tests/run.lua`, `KA0S_KIT_CLIENT=forever lua tests/run.lua`,
  `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0/0).
- No edits under `libs/` or `tests/_kit/`. No version bump.
- TDD: the failing case first, each with a `-- red under:` line.
- A commit that moves the pass count regenerates `docs/test-cases.md` and the README badge in the same
  commit (testing-§5).

## Milestones

### RM1 — Review fixes (plan task CA-M5-2)

**Done when:** R1 to R5 are committed, `lua tests/perf.lua` reports 0 failed assertions, and the
inventory and badge equal the fresh Total.

| Task | Role | Implements | Files |
|---|---|---|---|
| R1 | test-author | C-02 (F-002) | `docs/test-cases.md`, `README.md` |
| R2 | lua-engineer | C-05 (F-005) | `modules/AutoThank.lua`, `tests/test_autothank.lua` |
| R3 | lua-engineer | C-06 (F-006) | `modules/AutoThank_Toast.lua`, `tests/test_autothank.lua` |
| R4 | lua-engineer | C-04 (F-004) | `modules/AutoThank_Toast.lua`, `tests/test_autothank.lua` |
| R5 | perf-investigator | C-01 (F-001) | `modules/Surfaces.lua`, `modules/Bake.lua`, `tests/perf.lua`, `docs/performance.md` |

### RM2 — Complexity (plan task CA-M5-3)

**Done when:** the sighted complexity run reports 0 warnings, with blindFiles and crashedFiles both 0.

| Task | Role | Implements | Files |
|---|---|---|---|
| R6 | lua-refactorer | C-03 (F-003) | `modules/SendEngine.lua`, `settings/Callouts.lua`, `settings/SlashVerbs.lua`, `tests/test_locale.lua`, `tests/wow_mock.lua` |

## Critical path and concurrency

- R2, R3 and R4 all touch `tests/test_autothank.lua`, and R3 and R4 both touch
  `modules/AutoThank_Toast.lua`. Serialize them: R2, then R3, then R4.
- R5 is disjoint from R2 to R4 and can run in parallel.
- R6 touches `modules/SendEngine.lua`, which no RM1 task touches. It runs after RM1 so the complexity
  run measures the final tree.
- R1 is folded into the last count-moving commit of RM1. If no task moves the count, it stands alone
  as the first commit.

## Checkpoints

- After RM1: re-run `lua tests/perf.lua` and the inventory diff.
- After RM2: re-run the sighted complexity suite. Then the plan's CA-M5-4 docs sync.

## Commit strategy

One commit per task, subject `CA-M5-2: <fix>` for R1 to R5 and `CA-M5-3: Hold every function at CCN 15
or under` for R6, each ending with the session's attribution lines.
