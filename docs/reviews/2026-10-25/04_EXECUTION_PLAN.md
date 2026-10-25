# 04 — Execution plan (review of 2026-10-25)

Ground rules for every task:

- The green gate before each commit is `ka0s-bounded lua5.1 tests/run.lua` (0 failed) plus `ka0s-bounded luacheck .` (0/0).
- No edits under `libs/` or `tests/_kit/`. No version bump.
- Nothing is staged, committed or pushed without the owner's instruction (`CLAUDE.md`).
- Any change that moves the pass count regenerates `docs/test-cases.md` (`lua tests/run.lua --list > docs/test-cases.md`) and updates the README `[tests]` badge **in the same commit** (testing-§5).

## Milestones

### M1 — Correctness: restriction lifts (F-003)

**Done when:** the C-03 cases are green, each with a `-- red under:` line that was proved red. `PINNED` in `tests/test_disabled.lua` includes `ENCOUNTER_END`. The gate is green, and the inventory and badge have moved.

| Task | Role | Implements | Files |
|---|---|---|---|
| T1.1 | lua-engineer | C-03 (F-003) | `modules/Restrictions.lua`, `modules/Situation.lua` |
| T1.2 | test-author | C-03 cases | `tests/test_restrictions.lua`, `tests/test_disabled.lua`, `docs/test-cases.md`, `README.md` |

### M2 — Perf: pay for the look only when it changes (F-001, F-011)

**Done when:** `ka0s-bounded lua5.1 tests/perf.lua` reports 0 failed assertions. Any ceiling still raised carries a dated "Raised …" note in `tests/perf.lua` naming the commit and the cause, and `docs/performance.md:57-58` matches the new ceilings.

| Task | Role | Implements | Files |
|---|---|---|---|
| T2.1 | lua-engineer | C-01 pad shine guard | `modules/Pad_Render.lua` |
| T2.2 | perf-investigator | C-01 dial rise: bisect `66feba4..064f4ea` with `git archive` into scratch, then fix or justify | `modules/Dial_Slices.lua` or `modules/Dial_Render.lua` (as found) |
| T2.3 | lua-engineer | C-10 (F-011) | `modules/Library.lua` (`Lib.Children` only) |
| T2.4 | perf-recorder | C-01 ceilings and doc | `tests/perf.lua`, `docs/performance.md` |

### M3 — Complexity: zero above CCN 15 (F-002)

**Done when:** a scratch run of `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` reports **0 warnings**. Every refactored function that lacked coverage has a characterization test that was green against the unrefactored code (testing-§13). The gate is green.

| Task | Role | Implements | Files |
|---|---|---|---|
| T3.0 | test-author | C-09 split at the cap | `tests/test_page_groups.lua` → plus `tests/test_page_groups_when.lua`; `tests/run.lua` suite list; `docs/test-cases.md` |
| T3.1 | lua-refactorer | `Lib.SeedFromOverlay`, `Lib.ValidWhenValue` | `modules/Library.lua` |
| T3.2 | lua-refactorer | `S.ApplyAll` | `modules/Surfaces.lua` |
| T3.3 | lua-refactorer | `Pad.Apply`, `R.SkinFor` | `modules/Pad.lua`, `modules/Pad_Render.lua` |
| T3.4 | lua-refactorer | `Dial.Apply`, `DS.Load`, `R.Look`, `R.PointerUpdate` | `modules/Dial.lua`, `modules/Dial_Secure.lua`, `modules/Dial_Render.lua` |
| T3.5 | lua-refactorer | `P.EditPresetKey`, `PL.Compute`, `expandOne`, `oldDungeonWhen` | `modules/Preview.lua`, `modules/Pad_Layout.lua`, `modules/Tokens.lua`, `modules/Library_Migrate.lua` |
| T3.6 | lua-refactorer | `W.Summary`, `W.ResolveValue`, `G.ReusableCallouts`, `V.PreviewLines` | `settings/Groups_When.lua`, `settings/Groups.lua`, `settings/SlashVerbs.lua` |
| T3.7 | lua-refactorer | `tests/test_dial_shine.lua` anonymous, `encode` | `tests/test_dial_shine.lua`, `tools/render-shine-preview.lua` |

### M4 — Hygiene (F-004, F-005, F-007, F-008)

**Done when:** the doc sweep greps come back clean (`grep -n 'share string\|Share window\|PinNodes\|release gate is green' docs/ARCHITECTURE.md docs/module-map.md docs/schema.md docs/scope.md` prints nothing), lint is 0/0 with the pruned whitelist, and the gate is green.

| Task | Role | Implements | Files |
|---|---|---|---|
| T4.1 | docs-editor | C-04 | `docs/ARCHITECTURE.md`, `docs/module-map.md`, `docs/schema.md`, `docs/scope.md` |
| T4.2 | lint-keeper | C-05 | `.luacheckrc` |
| T4.3 | lua-engineer | C-07 | `core/Compat.lua` (plus `locales/enUS.lua` if the label option is chosen; Known Limitations line in `docs/ARCHITECTURE.md`) |
| T4.4 | lua-engineer | C-08 | `modules/Tokens.lua`, `modules/Restrictions.lua`, `modules/Library.lua`, `settings/Groups_When.lua`, `tests/test_tokens.lua`, `docs/test-cases.md` |

### M5 — Secure-path optimization (F-006), optional before v0.1.0

**Done when:** the C-06 case "every button outside the active set has no `type` after `Pad.Apply`" is green, and the taint spot-checks in `03_SMOKE_TESTS.md` pass in client.

| Task | Role | Implements | Files |
|---|---|---|---|
| T5.1 | secure-path engineer | C-06 | `modules/Pad.lua`, `modules/Dial.lua`, `modules/SendEngine.lua` (comment), `tests/test_sendengine.lua` |

### M6 — Cross-addon convergence (F-010)

**Done when:** QuickComms vendors LibKa0s v1.78.0 as one re-vendor commit. Vendor sync against the `v1.78.0` tag is empty, the `CLAUDE.md` provenance line reads v1.78.0, and the gate is green on the new payload.

| Task | Role | Implements | Files |
|---|---|---|---|
| T6.1 | revendor (`/dev-copilot:wow-revendor-libka0s`) | C-11 | `libs/LibKa0s/` (whole folder), `tests/_kit/` (whole folder), `CLAUDE.md`, `DEPENDENCIES.md`, `docs/ARCHITECTURE.md` (version mention) |

### M7 — Release run (owner)

**Done when:** `/dev-copilot:wow-automated-tests` records a bundle with all four suites at `pass`, complexity warnings 0 and `blindFiles` 0, and the owner has signed off `03_SMOKE_TESTS.md`. Then `/dev-copilot:bump-version`, only on the owner's word.

## Critical path and concurrency map

**Files touched by more than one task (these must serialize):**

- `modules/Library.lua`: T2.3, T3.1, T4.4. Order: T3.1 → T2.3 → T4.4 (refactor first, then behavior changes in their own commits, per performance-§11).
- `modules/Pad_Render.lua`: T2.1 and T3.3. Order: T2.1 → T3.3 (the shine guard changes `R.ApplyButtonLook`; `R.SkinFor` is refactored after).
- `modules/Pad.lua`: T3.3 and T5.1. Order: T3.3 → T5.1.
- `modules/Dial.lua`, `modules/Dial_Render.lua`: T2.2 (if the dial cause lands there) and T3.4. Order: T2.2 → T3.4.
- `modules/Restrictions.lua`: T1.1 and T4.4 (`CanSendChat`/`ActiveReason`). Order: T1.1 → T4.4.
- `modules/Tokens.lua`: T3.5 (`expandOne`) and T4.4 (`UsesGroupToken`). Order: T3.5 → T4.4.
- `settings/Groups_When.lua`: T3.6 and T4.4 (`W.HasAll`). Order: T3.6 → T4.4.
- `docs/test-cases.md` and `README.md` (badge): every task that adds or removes a case (T1.2, T3.0, the characterization tests in T3.x, T4.4, T5.1). One owner regenerates per commit, so commits serialize on this file.
- `docs/ARCHITECTURE.md`: T4.1, T4.3, T6.1. Order: T4.1 → T4.3 → T6.1.
- `tests/perf.lua`, `docs/performance.md`: T2.4 only, after T2.1 to T2.3.

**Parallelizable (disjoint file sets):**

- T1.1/T1.2 ∥ T2.1 ∥ T3.2 ∥ T3.6 ∥ T4.1 ∥ T4.2.
- Within M3: T3.2 ∥ T3.4 ∥ T3.6 ∥ T3.7 once T3.0 has landed, apart from the shared `docs/test-cases.md` regeneration, which is done at commit time by one agent.

**Critical path:** T1.1 → T1.2 → (T2.1 → T2.4) → M3 (T3.1 longest) → T4.4 → T6.1 → M7.

## Checkpoints

1. **After M1:** a human reads the C-03 diff, especially the stand-down timer cancel, and confirms the `PINNED` change is a behavior move, not a weakened test.
2. **After M2:** compare the perf figures within one run against today's (87026.8 / 2317.1). Approve any ceiling raise and its note.
3. **Before M3:** confirm the characterization tests ran green on the **unrefactored** code (CI log or the commit order shows it).
4. **After M3:** a scratch complexity run shows 0 warnings. Spot-check `S.ApplyAll` and `DS.Load` diffs for behavior drift.
5. **After M5 (if done):** run the in-client taint checks before anything else lands.
6. **After M6:** vendor sync against the v1.78.0 tag is empty, and REV-9 passes in client.

## Incremental commit strategy

One commit per task. Messages follow the repo's plain-sentence style, for example:

- `Restrictions re-read when an encounter or key ends (F-003)`
- `Tests: the restriction lift reaches Refresh through ENCOUNTER_END and CHALLENGE_MODE_COMPLETED`
- `Pad buttons repaint their shine only when its look or size changes (F-001)`
- `Perf: ceilings re-measured after the shine guard; performance.md in step`
- `Library: Children sorts on precomputed keys (F-011)`
- `Split the Groups page suite at the 1500-line cap (F-009)`
- `Refactor <function> under CCN 15 (F-002), characterization test first`, one per function, or per file where the functions are tightly related
- `Docs: drop Share and pinned-node leftovers; the release gate is the release run's (F-004)`
- `Lint: drop the retired key editor's binding writers from read_globals (F-005)`
- `General is channel 1 only when channel 1 is General (F-007)`
- `Remove helpers no shipped code calls (F-008)`
- `Re-vendor LibKa0s v1.78.0` (its own commit, by the re-vendor command)

End each commit message with the session's attribution lines.
