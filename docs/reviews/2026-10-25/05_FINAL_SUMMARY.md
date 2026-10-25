# 05 — Final summary (written as if every check in `03_SMOKE_TESTS.md` passed)

> This is the forward-looking "what shipped" record for the 2026-10-25 review-and-fix cycle. Its numbers marked *expected* are targets from `02_PROPOSED_CHANGES.md`. Replace each with the measured figure from the run that implements it before this text is used in a PR or changelog.

## Headline

This cycle got Ka0s Quick Comms ready to tag v0.1.0. Today the project's own release gate fails on two counts: the offline perf ceilings and the complexity limit. The cycle cut the measurable cost behind the perf failure, so the pad buttons repaint their shine only when it changes. It brought all 19 over-limit functions under the limit without changing behavior, each pinned by a test first. It also fixed one player-visible bug: after a Mythic+ key or a boss kill, Say and Yell buttons could keep a padlock and warn that a successful callout "may not have been sent". Finally, it swept docs that still described today's removed Share feature, tightened lint, and moved the addon onto the LibKa0s version its sibling LootHistory already ships.

## Counts

`Critical fixed: 0, High fixed: 0, Medium fixed: 3, Low fixed: 8`

- **Medium:** F-001, F-002, F-003.
- **Low:** F-004, F-005, F-006, F-007, F-008, F-009, F-010, F-011.
- **Deferral candidate:** F-006 (C-06) is marked optional before v0.1.0, because it touches the secure release path. If it is deferred, the count reads Low fixed: 7, and F-006 moves to Known follow-ups.

## Changes by theme

### T1 — The release gate tells the truth

- **What changed:** pad button shine painting is guarded, and the offline perf ceilings were re-measured and recorded with a dated reason wherever one was raised. Nineteen functions were refactored under CCN 15, using module-level tables, dispatch and named helpers, each pinned first by a characterization test. The docs no longer claim a green gate.
- **Why it mattered:** automated-tests-§3 refuses a release unless `perf` passes and no function exceeds CCN 15. Both failed on `18a2b55`.
- **Findings / changes:** F-001, F-002, F-004 / C-01, C-02, C-04, C-09.
- **Files:**
  - `modules/Pad_Render.lua`, `tests/perf.lua`, `docs/performance.md`
  - `modules/Library.lua`, `modules/Surfaces.lua`, `modules/Pad.lua`, `modules/Dial.lua`, `modules/Dial_Secure.lua`, `modules/Dial_Render.lua`
  - `modules/Preview.lua`, `modules/Pad_Layout.lua`, `modules/Tokens.lua`, `modules/Library_Migrate.lua`
  - `settings/Groups_When.lua`, `settings/Groups.lua`, `settings/SlashVerbs.lua`
  - `tests/test_dial_shine.lua`, `tools/render-shine-preview.lua`
  - `tests/test_page_groups.lua`, `tests/test_page_groups_when.lua`, `tests/run.lua`
  - `docs/ARCHITECTURE.md`, `docs/module-map.md`, `docs/schema.md`, `docs/scope.md`

### T2 — Restriction lifts are heard

- **What changed:** the restriction tracker re-reads the client when an encounter ends (`ENCOUNTER_END`, a new registration) and when a key completes (`CHALLENGE_MODE_COMPLETED`, forwarded from the situation edge that already owns it), and once more half a second later. The stand-down cancels that late read.
- **Why it mattered:** a lockdown that cleared after the last restriction event left Say, Yell and General slots padlocked, with a false "may not have been sent" note on a press that did send. The test named for this scenario never exercised it.
- **Findings / changes:** F-003 / C-03.
- **Files:** `modules/Restrictions.lua`, `modules/Situation.lua`, `tests/test_restrictions.lua`, `tests/test_disabled.lua`.

### T3 — Pay for the look only when it changes

- **What changed:** child groups sort on precomputed keys. Optionally (C-06), a rebuild no longer disarms buttons it is about to re-arm with the same line.
- **Why it mattered:** these removed per-rebuild work the code claimed not to do.
- **Findings / changes:** F-006, F-011 / C-06, C-10.
- **Files:** `modules/Library.lua`, `modules/Pad.lua`, `modules/Dial.lua`, `modules/SendEngine.lua`, `tests/test_sendengine.lua`.

### T4 — Hygiene

- **What changed:** the lint whitelist no longer admits the retired key editor's binding writers. The General channel kind only claims General when channel 1 is General. Helpers with no shipped caller were wired or removed.
- **Findings / changes:** F-005, F-007, F-008 / C-05, C-07, C-08.
- **Files:** `.luacheckrc`, `core/Compat.lua`, `modules/Tokens.lua`, `modules/Restrictions.lua`, `modules/Library.lua`, `settings/Groups_When.lua`, `tests/test_tokens.lua`.

### T5 — Cross-addon convergence

- **What changed:** LibKa0s was re-vendored to v1.78.0 as a whole-folder copy.
- **Why it mattered:** with LootHistory installed, QuickComms was already running v1.78.0 code for five majors that its own suite had never measured.
- **Findings / changes:** F-010 / C-11.
- **Files:** `libs/LibKa0s/`, `tests/_kit/`, `CLAUDE.md`, `DEPENDENCIES.md`.

## API / behavior changes

- **New event registration:** `ENCOUNTER_END`, in `NS.FEATURE_EVENTS`, unregistered by the stand-down.
- **General channel kind:** sends to channel 1 only when it is General; otherwise it resolves as Say. If C-07's label option was chosen instead, the kind is labeled "Channel 1" (a locale key change).
- **Slash verbs, settings paths, defaults, SavedVariables:** no slash verb, settings path, default or SavedVariables key changed. Schema version stays 9.

## Saved-variable / migration notes

None. No stored shape changed.

## Deprecated-API migrations

None. No deprecated API was found in shipped code.

## Performance impact

Offline mock, `ka0s-bounded lua5.1 tests/perf.lua`, compared within one run on one machine:

| Scenario | Before (`18a2b55`) | After | Record |
|---|---|---|---|
| `padRebuild12` | 87026.8 B/iter | *expected ≈ 66290.8 B/iter* (the shine-off floor) | the C-01 commit's perf run |
| `dialOpenClose` | 2317.1 B/iter | *per T2.2's finding* | the T2.2 commit's perf run |

No in-client capture existed before this cycle. If the `/qc perf` capture in `03_SMOKE_TESTS.md` was recorded, cite its `docs/perf-analysis/<run>/` bundle's `padLayout`, `bakeSurface` and `dialRender` buckets here.

## Test and complexity movement

- **Pass count:** 1157 before. After: 1157 + the new C-03 cases + the characterization tests − the C-08 asserts removed (*fill in from the final `--list`*).
- **Inventory and badge:** `docs/test-cases.md` and the README `[tests]` badge move in each commit that moves the count.
- **Watch list:** all 19 entries are expected to leave the `docs/automated-tests/RESULTS.md` watch list. That is confirmed by the release run's regeneration, not by hand.

## Known follow-ups

- **F-006 (C-06):** if deferred, re-evaluate after v0.1.0. It is a secure-path change with low measured benefit.
- **Dial `dialOpenClose`:** if T2.2 ends in a justified raise rather than a fix, track the shine-overlay layer creation at dial open as a candidate for a lazy path.
- **First in-client perf capture:** no `docs/perf-analysis/` bundle existed at review time.
- **Standard v2.89.0:** the review cross-checked against v2.88.0. Re-check the changes once the sibling's v2.89.0 is on `origin/master`.

## Verification evidence

- `docs/reviews/2026-10-25/03_SMOKE_TESTS.md`, with its sign-off table filled in.
- Commit range: *`18a2b55..<last commit of M6>` on `feat/2026-10-25-review-audit-fixes`* (fill in).
- The release run's bundle: *`docs/automated-tests/<run>/`* (fill in, from `/dev-copilot:wow-automated-tests`).

## Suggested PR description

```
Review fixes before v0.1.0 (review 2026-10-25)

The release gate was red on 18a2b55: two offline perf ceilings exceeded and
19 functions above CCN 15. This change brings both back within the gate and
fixes one player-visible bug.

- Restrictions re-read on ENCOUNTER_END and CHALLENGE_MODE_COMPLETED (plus a
  late read), so a lockdown that lifts quietly no longer leaves Say/Yell/General
  padlocked with a false "may not have been sent" note (F-003).
- Pad buttons repaint their shine only when its look or size changes; perf
  ceilings re-measured and recorded (F-001).
- 19 functions refactored under CCN 15, each with a characterization test first
  (F-002); the Groups page suite split at the 1500-line cap (F-009).
- Docs swept of the removed Share feature and retired node pinning (F-004);
  lint whitelist pruned (F-005); General channel kind checks channel 1 (F-007);
  dead helpers removed or wired (F-008); Children sorts on precomputed keys (F-011).
- LibKa0s re-vendored to v1.78.0 (F-010).

Tests: <before> -> <after>; luacheck 0/0; perf 0 failed; complexity 0 warnings.
Smoke: docs/reviews/2026-10-25/03_SMOKE_TESTS.md signed off.
```
