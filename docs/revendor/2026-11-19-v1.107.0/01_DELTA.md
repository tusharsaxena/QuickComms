Delta: LibKa0s v1.106.0 -> v1.107.0

Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.107.0 LibKa0s testkit tools` (tag object 427e108d, commit 5e963659). The tag is local only (`git -C ../LibKa0s ls-remote --tags origin v1.107.0` prints nothing), which is expected: the lead pushes it at finalize. Run as item AF-RV-QC of the cross-repo run `feat/2026-11-19-adoption-feedback` (Ka0sAddonsCommonTasks `docs/2026-11-19-ADOPTION_FEEDBACK/`, plan M2). That run takes the copy, provenance, declaration and prune half of `/dev-copilot:wow-revendor-libka0s` only: its adoption interview is skipped and no GitHub issue is filed here.

## Step 0 pre-flight
The newest single-tag bundle `2026-11-16-v1.105.0` states base v1.95.0; the provenance line before the commit that vendored v1.105.0 named v1.95.0. `ok`. No correction is owed.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` -> `45:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.106.0 (MIT).`
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = b03d817 (Re-vendor LibKa0s v1.106.0); its CLAUDE.md names v1.106.0. They agree.
- `diff -rq --strip-trailing-cr <v1.106.0 extract>/LibKa0s libs/LibKa0s` lists only the pruned sounds (`media/sounds/callout`); `diff -rq <v1.106.0 extract>/testkit tests/_kit` is empty. The payload was v1.106.0's.
- Range: `git -C ../LibKa0s log --oneline v1.106.0..v1.107.0` lists 7 commits.

## 3b/3c Per-file minors that moved
```
WidgetsDragHandle.lua     DRAG_MINOR 14 -> 15
WidgetsDragHandleTip.lua  DRAGTIP_MINOR 1 -> 2
```
`diff -rq` of the two extracts' `LibKa0s/` names only these two files, and their `testkit/` trees are identical. No file is added or removed. No cross-major skew.

## 3d Diffs
After the copy, before the prune: `diff -rq --strip-trailing-cr <extract>/LibKa0s libs/LibKa0s` and `diff -rq <extract>/testkit tests/_kit` are both empty. After the prune, the only difference is `Only in <extract>/LibKa0s/media/sounds…` (no `LibKa0s sounds:` line, so none ship). The icon folder ships whole (`all`).

## 3e Consumption
This addon draws one `DragHandle` per Comms Pad through `NS.MakeDragHandle` (core/WidgetsSetup.lua, called at modules/Pad.lua:336). It already passes `settings` (a function opening `NS.addon:OpenSettings`) and `settingsTooltip`, and passes no `tooltipPlace` and no `onClose`.

## 3f Kit
`Kit.VERSION = 57` at both tags; the testkit is unchanged.

## 3g Blockers
None that break on the copy: no signature moved and the gate is green on both clients with the payload alone. The release's "What a consumer owes" list binds strip hosts: an `onClose` on every strip (the close appears only with it), the `settings` icon declared (this addon declares `all`), and no strip `tooltipPlace` hook (this addon has none). The `onClose` is owed by the run's own item AF-STRIP-QC, in the commit after this one, so it is recorded here and not done here.

## 3h Span
v1.106.0 was vendored by `b03d817` with no bundle; recorded in the span bundle `../2026-11-19-v1.106.0-v1.106.0/`.

## 3i Icon declaration
`LibKa0s icons: all (icon browser).` kept unchanged, the next non-blank line under the provenance line. `settings` is in the catalog it ships. The prune refused nothing: it kept every icon and removed 362 voice-pack sound files (`sounds none`).

## 3j Tests assuming the whole icon folder
None new.
