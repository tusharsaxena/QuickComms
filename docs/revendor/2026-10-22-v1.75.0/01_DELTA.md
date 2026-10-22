Delta: LibKa0s v1.74.0 -> v1.75.0

# 01 — Delta

Re-vendor of LibKa0s into QuickComms, run 2026-10-22 as item QC-RV of the cross-repo run
"LibKa0s issues #45-#58" (Ka0sAddonsCommonTasks `docs/2026-10-22-LIBKA0S_ISSUES_45_58/`). The
procedure is the installed dev-copilot 2.4.0 `/dev-copilot:wow-revendor-libka0s`, run without its
interview: the run's `inputs/OWNER_SCOPE.md` section A pre-decides every adoption, and M2 files no
GitHub issues.

The new tag is a LOCAL tag on the run branch (not pushed at the time of this record):

```sh
git -C ../LibKa0s rev-parse v1.75.0            # eae0ee52aab423e82e4d37e46c4b98f50d0c5032 (tag object)
git -C ../LibKa0s rev-parse 'v1.75.0^{commit}' # 265a89eba3db44f2d85e61287d1691cca6b1effd
git -C ../LibKa0s rev-parse 'v1.74.0^{commit}' # 290ad6b2b623f3bab38588459e76bfc146aaa515
```

The payload was taken from the tag, never from the LibKa0s working tree:

```sh
git -C ../LibKa0s archive v1.75.0 LibKa0s testkit tools | tar -x -C <scratch>
```

## 3a. Claimed version (the base)

```sh
grep -n '[Bb]undles' CLAUDE.md
# 42:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.74.0 (MIT).
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)
# 610f0d4f060081d04570b3537f61bed2d21e1fa1  "Vendor LibKa0s v1.74.0 (three icon sets, Media minor 5)"
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+'
# Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.74.0
```

Both agree: the base is **v1.74.0**. Cross-check that the payload before this run was v1.74.0's:

```sh
git -C ../LibKa0s archive v1.74.0 LibKa0s testkit | tar -x -C <scratch>/claimed
diff -rq --strip-trailing-cr <scratch>/claimed/LibKa0s libs/LibKa0s && \
diff -rq --strip-trailing-cr <scratch>/claimed/testkit tests/_kit && echo payload-matches
# payload-matches
```

Range: `git -C ../LibKa0s log --oneline v1.74.0..v1.75.0` lists 36 commits. `git -C ../LibKa0s diff
--stat v1.74.0 v1.75.0 -- LibKa0s testkit`: 18 files, 2975 insertions, 92 deletions.

Step 0 pre-flight: QuickComms has no `docs/revendor/` store before this bundle, so there is no
earlier base to check (`no store`).

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` before the copy
matched the v1.74.0 minors exactly (the "old" column below); the line and the bytes agreed.

## 3c. Per-file minor delta

Produced by the 3c loop over the tag's `LibKa0s/LibKa0s.xml` (old = the addon's copy before the
copy; new = `git -C ../LibKa0s show v1.75.0:LibKa0s/<file>`). Moved files only; every other file
is unchanged.

| File | v1.74.0 | v1.75.0 | What moved |
|---|---|---|---|
| Core.lua | Core 10 | Core 11 | comment-only (a declared-but-pruned `close` draws blank, LibKa0s#57) |
| Item.lua | Item 2 | Item 3 | `Item.BonusIDsFromLink` (#51) |
| Glow.lua | (new) | Glow 1 | new major `LibKa0s-Glow-1.0` (#56) |
| Widgets.lua | Widgets 12 | Widgets 13 | `W.SearchBox` (#52), `W.TestStrip` (#48) |
| DebugLog.lua | DebugLog 19 | DebugLog 20 | comment-only (`close, copy, clear` are the host's to declare) |
| DebugLogDiagnostics.lua | DIAG 2 | DIAG 3 | the identity header's MAJORS list adds Glow and Sim |
| OptionsIdList.lua | IDLIST 4 | IDLIST 5 | comment-only (LK-02: the help mark's art is the host's to declare) |
| OptionsTabs.lua | TABS 8 | TABS 9 | `O.__releaseChrome` no longer exported (LibKa0s#45) |
| PerfPanel.lua | PANEL 6 | PANEL 7 | comment-only (Sim's private copy of the renderer, #53) |
| Sim.lua | (new) | Sim 1 | new major `LibKa0s-Sim-1.0` (#54) |
| SimTimeline.lua | (new) | TIMELINE 1 | Sim's step machine |
| SimPanel.lua | (new) | SIM_PANEL 1 | Sim's docked step panel (Sim-private; LK-11 outcome B) |

`W.StepPanel` / `WidgetsStepPanel.lua` does **not** ship at v1.75.0: the run's LK-11 took outcome B,
which made the step panel Sim-private inside `SimPanel.lua`. No consumer was behind on any file
after the copy (no cross-major skew).

## 3d. Both diffs

Run after `cp -r <scratch>/LibKa0s/. libs/LibKa0s/` and `cp -r <scratch>/testkit/. tests/_kit/`,
before the prune:

```sh
diff -r --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   # empty
diff -r                     <scratch>/LibKa0s libs/LibKa0s   # empty
diff -r --strip-trailing-cr <scratch>/testkit tests/_kit     # empty
diff -r                     <scratch>/testkit tests/_kit     # empty
```

No `Only in libs/LibKa0s` or `Only in tests/_kit` line: v1.75.0 removes no file, so nothing was
deleted. New files: `Glow.lua`, `Sim.lua`, `SimTimeline.lua`, `SimPanel.lua`.
`tests/_kit/run-automated-tests.sh` keeps mode 100755 (`git diff --summary` shows no mode change).

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

Thirteen majors wired, one setup file each: Core (`core/CoreSetup.lua:19`), Media
(`core/MediaSetup.lua:10`), Env (`core/EnvSetup.lua:7`), Pool (`core/PoolSetup.lua:9`), Widgets
(`core/WidgetsSetup.lua:13`; also `settings/Editors.lua:407`), Bus (`core/Bus.lua:17`), Lifecycle
(`core/LifecycleSetup.lua:10`), Perf (`core/PerfSetup.lua:15`), DebugLog (`core/DebugLogSetup.lua:10`),
Launcher (`core/LauncherSetup.lua:11`), Schema (`settings/SchemaSetup.lua:213`), Options
(`settings/OptionsSetup.lua:11`), Slash (`settings/Slash.lua:71`). Compat is looked up at
`core/Compat.lua:7` for `IsSecret` / `IsSafeKey` only. `settings/SchemaMembers.lua:347` is a second
Core lookup. Item is vendored and unwired. Glow and Sim are new and unwired (Glow is adopted in QC-01).

## 3f. Kit revision and the pairing rule

```sh
grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua
# <scratch>/testkit/framework.lua:20:Kit.VERSION = 41
# tests/_kit/framework.lua:20:Kit.VERSION = 39      (before the copy)
```

Kit 39 -> 41, in the same commit as the library payload (both payloads are copied whole, so the
pairing holds by construction). Kit 40: `vendor_sync.lua` holds `media/icons/` to the
`LibKa0s icons:` declaration. Kit 41: `Kit.__deviationRows` / `Kit.__declineFor` are no longer
exported (LibKa0s#45), and a lizard run that crashed or hit its bound is a complexity **fail** with a
separate `crashedFiles` bucket named by a per-file retry (LibKa0s#46, #47).

## 3g. Contract delta, and Blockers

Majors that moved a minor AND that QuickComms looks up: Core, Widgets, DebugLog, Options
(OptionsIdList, OptionsTabs), Perf (PerfPanel). Read with
`git -C ../LibKa0s diff v1.74.0 v1.75.0 -- LibKa0s/<file>`:

- **Library-drawn art is the host's to declare** (Core 11 doc comment on `MakeCloseButton`, DebugLog
  20 on its icon button, OptionsIdList 5 on the id-list help mark): a host whose copy lacks the art
  now draws a blank control, not the fallback. Under `all` nothing is pruned, so this changes nothing
  here.
- **OptionsTabs 9 drops `O.__releaseChrome`.** No `__Attach*` call in the addon
  (`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` finds
  none), and no addon code called `O.__releaseChrome`. The only addon mention was the Options stub
  mirror, handled under (d).
- Widgets 13 is additive. PerfPanel 7 is comment-only.

No host-supplied member's call site moved. Blockers, each checked:

- **(a) Options stub Drawer parity:** already present (`settings/OptionsSetup.lua:76`
  `H.Drawer = function() end`, line 77 before this commit's deletion). No change.
- **(b) kit-39 `__fireUnconditional` stand-down cases:** QuickComms is already on the kit-39 shape
  (`tests/test_disabled.lua:99`, `:295-299`). No change. The `:295-298` comments stay; they describe
  the red-under, which is still true at kit 41.
- **(c) whole-catalog icon tests / `info.tga` tests:** under `all` nothing is pruned.
  `tests/test_icon_browser.lua:211` enumerates `NS.IconNames()` and stays.
  `grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` finds
  nothing, and `grep -rn 'media/icons\|media\\\\icons\|info.tga' tests/*.lua` finds only
  `tests/test_library.lua:846-847`, which pass path *strings* to `Lib.IsGlyph` and open no file. No
  test reads art from disk. No change.
- **(d) OWNER_SCOPE G / LibKa0s#45, the dead stub mirror:** deleted the one line
  `settings/OptionsSetup.lua:60` `H.__releaseChrome = function() end`. The sibling `__` mirrors stay
  (v1.75.0 still exports them; `parityProblems` iterates live keys). Check:
  `grep -rn __releaseChrome --exclude-dir=libs --exclude-dir=_kit --exclude-dir=automated-tests --exclude-dir=audits .`
  returns nothing. The frozen `docs/automated-tests/*/complexity.txt` mentions are not edited.
- **(e) Stale kit-revision mentions:** `docs/testing.md:23` revision 39 -> 41; `docs/testing.md:85`'s
  complexity row gains the kit-41 clause (a crashed or bounded lizard run is a complexity fail,
  `crashedFiles` 0 at release; automated-tests-§3).
- **(f) Version pointers:** `docs/ARCHITECTURE.md:50` v1.74.0 -> v1.75.0 (still thirteen majors
  wired); `docs/module-map.md:4` now reads `LibKa0s v1.75.0 (media/icons held to CLAUDE.md's
  LibKa0s icons: line, all)`. `tests/test_icon_browser.lua:795` and `tests/test_library.lua:845` are
  left alone: they date when the icon sets arrived.

## 3h. Unrecorded vendored tags

None to back-fill. This is the store's first bundle; per the command's step 3h a store with no
bundle has no horizon, so no span bundle is written for the earlier v1.73.0 / v1.74.0 re-vendors.

## 3i. The icon declaration

Decided by the run (item QC-RV spec, OWNER brief), not re-asked: `CLAUDE.md:43`, directly under the
provenance line at `:42`, exactly

    LibKa0s icons: all (icon browser).

`all` is justified because the addon enumerates the whole catalog for a player-facing chooser. Line
42 was already its own paragraph (blank line 41), so no split was needed. Draw-site census
(verified 2026-10-22):

- **Whole catalog:** `settings/IconBrowser_Sources.lua:68,77` (`NS.IconSets()`), `:101`, `:117`
  (every `NS.IconNames()` name); `settings/IconBrowser.lua:437` (each cell); `modules/Library.lua:267`
  (`Lib.IsGlyph` over every name: any glyph a player picked).
- **Host-named via `NS.Icon`** (`core/MediaSetup.lua:16`): `help` `core/WidgetsSetup.lua:23` (the drag
  strip's help mark); `info` `settings/CalloutPopup.lua:238`; `lock` `modules/Pad_Render.lua:167` and
  `modules/Dial_Render.lua:466`; `segment` `settings/Editors.lua:411`; `edit` `settings/Editors.lua:429`;
  `ph:caret-left` / `ph:caret-right` `modules/Dial_Render.lua:42-43` (drawn at `:388`); `ph:caret-up`
  `:44` (drawn at `:192`).
- **Data:** the built-in sets' glyphs through `BI.Callout` / `BI.Group` (`defaults/BuiltIns.lua:26`,
  `:37`): `grep -rhoE '"(ph|gi):[a-z0-9-]+"' defaults | sort -u | wc -l` counts **133** distinct
  `gi:` / `ph:` names (the item spec estimated about 90).
- **Library-drawn** (the tag's `docs/releasing.md` table): `close` (`Core.MakeCloseButton` given the
  addon name through `NS.MakeCloseButton`, `core/CoreSetup.lua:106`, used by
  `settings/ModalWindow.lua:72`; the DebugLog console; PerfPanel; the copy window behind
  `NS.MakeCopyWindow`), `copy` and `clear` (the DebugLog console, wired by `core/DebugLogSetup.lua`),
  `info` (the Options id list: `settings/Groups_When.lua:589` `h.IdList` passes no `helpIcon`).
- QuickComms hosts no `W.TestStrip`.

Everything is covered by `all`. Hand lists have drifted before (KickCD
`tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`); the owner's in-client
smoke (SM-QC-1, SM-QC-2) is the backstop.

The prune, with the tag's own tool, after the diffs above:

```sh
git -C ../LibKa0s show v1.75.0:tools/prune-icons.lua   # extracted with tools/ above
lua <scratch>/tools/prune-icons.lua /mnt/d/Profile/Users/Tushar/Documents/GIT/QuickComms
# prune-icons: /mnt/d/Profile/Users/Tushar/Documents/GIT/QuickComms declares all icons (icon browser); nothing removed
```

Removed: 0 (Open Iconic 0, Phosphor 0, Game-icons 0). All license files stay:
`media/icons/LICENSE-open-iconic.txt`, `phosphor/LICENSE-phosphor.txt`,
`game-icons/LICENSE-game-icons.txt`, `game-icons/AUTHORS.txt`.

## 3j. Tests that assume the whole icon folder

See 3g (c): none needs a change under `all`.

## Credits

`README.md` `## Credits` (lines 145-157) already meets documentation-§1 item 12: Game-icons CC BY 3.0
with authors, link and the modification note (MUST), Open Iconic and Phosphor with author, MIT and link
(SHOULD), all three sets ship. Author list checked against the tag:

```sh
grep '^gi:' libs/LibKa0s/media/icons/game-icons/AUTHORS.txt | cut -f2 | sort -u   # 35 names
# diff against the 35 names at README.md:151-155: identical
```

No edit.

## Complexity (informational, not fixed here)

`bash tests/_kit/run-automated-tests.sh --suite complexity` through the bounded runner, on the
post-copy tree (kit 41): status `pass` (non-gating), `crashedFiles` 0, `blindFiles` 0, 33657 NLOC /
3666 functions, avg CCN 2.6, max 30, 17 functions above CCN 15. The bundle it wrote was not kept
(it is a record of an uncommitted tree). The functions above 15:

| CCN | Function | File |
|---|---|---|
| 30 | Lib.SeedFromOverlay@1098-1141 | modules/Library.lua |
| 26 | S.ApplyAll@403-454 | modules/Surfaces.lua |
| 26 | (anonymous)@97-140 | tests/test_dial_shine.lua |
| 24 | G.ReusableCallouts@255-291 | settings/Groups.lua |
| 22 | R.Look@244-277 | modules/Dial_Render.lua |
| 20 | SH.ReportLines@565-595 | modules/Share.lua |
| 19 | W.Summary@471-496 | settings/Groups_When.lua |
| 19 | PL.Compute@281-308 | modules/Pad_Layout.lua |
| 19 | DS.Load@316-342 | modules/Dial_Secure.lua |
| 18 | Pad.Apply@360-408 | modules/Pad.lua |
| 17 | W.ResolveValue@542-567 | settings/Groups_When.lua |
| 17 | R.PointerUpdate@102-128 | modules/Dial_Render.lua |
| 17 | Dial.Apply@248-301 | modules/Dial.lua |
| 16 | oldDungeonWhen@39-48 | modules/Library_Migrate.lua |
| 16 | encode@108-145 | tools/render-shine-preview.lua |
| 16 | R.SkinFor@303-317 | modules/Pad_Render.lua |
| 16 | Lib.ValidWhenValue@378-391 | modules/Library.lua |
