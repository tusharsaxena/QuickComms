# Review and audit fixes (2026-10-25) — plan

Spec: `docs/superpowers/specs/2026-10-25-review-audit-fixes-design.md`. Branch:
`feat/2026-10-25-review-audit-fixes`. Every RA item there maps to exactly one track below.

## How it runs

One Workflow (ultracode). Four code tracks run in parallel, each in its own git worktree, on its own
branch `ra/<track>` cut from the feature branch's HEAD, owning a **disjoint file set**. A track commits
on its branch with the gate green and never pushes; it does not touch `docs/`, the README or the TOC
(except `docs/performance.md` for track A), and returns the doc notes its change needs instead. An
integration stage merges the four branches into the feature branch, then a docs-and-config track
applies every doc note plus the doc and config items, regenerates `docs/test-cases.md` and the README
badge, and runs the gate. A verify stage checks the result against every RA item adversarially; gaps
loop back as fix agents. The automated-test bundle is cut last.

Shared files no track may edit: `docs/**` (bar A's `docs/performance.md`), `README.md`,
`QuickComms.toc`, `docs/test-cases.md`, `tests/run.lua` (track C may add its new suite name only),
`.luacheckrc`, `.pkgmeta`, `libs/`, `tests/_kit/`.

## Tracks

| Track | Branch | Owns | Items |
|---|---|---|---|
| A — perf and the secure path | `ra/perf` | `modules/Pad_Render.lua`, `modules/Pad.lua`, `modules/Dial.lua`, `modules/Dial_Slices.lua`, `modules/Dial_Render.lua`, `modules/Dial_Secure.lua`, `modules/SendEngine.lua`, `modules/Surfaces.lua`, `modules/Shine.lua`, `tests/perf.lua`, `docs/performance.md`, `tools/render-shine-preview.lua`, `tests/test_pad*.lua`, `tests/test_dial*.lua`, `tests/test_sendengine.lua`, `tests/test_surfaces.lua`, `tests/test_shine.lua` | RA-01, RA-06; RA-02 for `R.SkinFor`, `R.Look`, `R.PointerUpdate`, `Pad.Apply`, `Dial.Apply`, `DS.Load`, `S.ApplyAll`, the anonymous function in `tests/test_dial_shine.lua`, `encode` in `tools/render-shine-preview.lua` |
| B — library and data | `ra/library` | `modules/Library.lua`, `modules/Library_Migrate.lua`, `modules/Preview.lua`, `modules/Tokens.lua`, `modules/Pad_Layout.lua`, `tests/test_library.lua`, `tests/test_database.lua`, `tests/test_preview*.lua`, `tests/test_tokens.lua`, `tests/test_pad_layout.lua`, `tests/test_edit_preview.lua` | RA-10; RA-08 for `Tok.UsesGroupToken`, `Lib.DeleteCallout`; RA-02 for `Lib.SeedFromOverlay`, `Lib.ValidWhenValue`, `oldDungeonWhen`, `P.EditPresetKey`, `expandOne`, `PL.Compute` |
| C — settings and labels | `ra/settings` | `settings/*.lua`, `locales/enUS.lua`, `tests/test_page_*.lua` (and the split-off suite), `tests/test_groups_when.lua`, `tests/test_slash.lua`, `tests/test_layers.lua`, `tests/test_callout_popup.lua`, `tests/test_icon_browser.lua`, `tests/test_keybinds.lua`, `tests/test_layout.lua`; `tests/run.lua` (the new suite's name only) | RA-09 (split), RA-14, RA-16, RA-18 (code part); RA-08 for `W.HasAll`; RA-02 for `G.ReusableCallouts`, `W.Summary`, `W.ResolveValue`, `V.PreviewLines` |
| D — situation, restrictions, channels, disable | `ra/situation` | `modules/Restrictions.lua`, `modules/Situation.lua`, `modules/Channels.lua`, `core/Compat.lua`, `core/QuickComms.lua`, `core/LifecycleSetup.lua`, `tests/test_restrictions.lua`, `tests/test_situation.lua`, `tests/test_channels.lua`, `tests/test_compat.lua`, `tests/test_disabled.lua`, `tests/wow_mock.lua` | RA-03, RA-07, RA-12; RA-08 for `R.CanSendChat`, `R.ActiveReason` |
| E — docs and config (after integration) | feature branch | `docs/**`, `README.md`, `QuickComms.toc`, `.luacheckrc`, `.pkgmeta`, `tests/run.lua` (jobs) | RA-04, RA-05, RA-11, RA-13, RA-15, RA-17, RA-18 (register part, if needed), RA-19, RA-20, RA-21, RA-22, RA-23, every track's doc notes, `docs/test-cases.md` regenerated, README badge |
| F — record | feature branch | `docs/automated-tests/` | RA-24 (fresh bundle, band dispositions), issue #11 triaged (RA-15) |

A conflict at integration is resolved by the integration agent in favor of both changes; a conflict it
cannot resolve stops the run.

## Checkpoints

Update this table as each lands (commit SHA, or the workflow run id while in flight). To resume: read
it, `git branch --list 'ra/*'`, and restart from the first row not marked done (the workflow resumes
from its run id with cached results).

| # | Step | Status | Evidence |
|---|---|---|---|
| 0 | Smoke pass recorded; review and audit bundles committed; spec and plan committed | done | `18a2b55`, `6f396c7`, this commit |
| 1 | Tracks A, B, C, D on `ra/*`, each gate-green | pending | |
| 2 | Integration: four branches merged into the feature branch, gate green | pending | |
| 3 | Track E: docs and config, test inventory and badge, gate green | pending | |
| 4 | Verify: every RA item checked against the tree; gaps fixed | pending | |
| 5 | Push the feature branch | pending | |
| 6 | Track F: automated-test bundle, issue #11 | pending | |
| 7 | Owner go-ahead → merge, push, delete `ra/*` and the feature branch, worktrees and stashes | pending | |
