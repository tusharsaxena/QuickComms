Delta: LibKa0s v1.95.0 -> v1.105.0

Recorded for item RV-QC of the cross-repo run `feat/2026-11-16-libka0s-75-plus` (Ka0sAddonsCommonTasks
`docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS`, design section 5). The payload comes from the local tag, never the
sibling tree: `git -C ../LibKa0s archive v1.105.0 LibKa0s testkit tools` (tag commit 79b1d9c4). The tag is local
and not yet on origin (`git -C ../LibKa0s ls-remote --tags origin v1.105.0` prints nothing); the lead pushes it.
This run is the copy and bundle half of `/dev-copilot:wow-revendor-libka0s` only. The adoption interview and its
GitHub issue filing are phase [3] of the run (see 02_CANDIDATES.md).

## Step 0 pre-flight
The newest single-tag bundle, `2026-11-10-v1.95.0`, states base v1.93.0. The provenance line before the commit
that vendored v1.95.0 named v1.93.0 (that bundle's own 3a, payload commit 2f042d2). Result: ok, no correction.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` named v1.95.0 before the roll (line 45).
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 48c8d25. Its CLAUDE.md names v1.95.0. They agree.
- Before the copy, `diff -rq --strip-trailing-cr` of both payloads against a v1.95.0 extract printed nothing
  (payload-matches).
- `git -C ../LibKa0s log --oneline v1.95.0..v1.105.0` is 105 commits. `git -C ../LibKa0s diff --stat v1.95.0
  v1.105.0 -- LibKa0s testkit`: 415 files changed, 9622 insertions(+), 622 deletions(-).

## 3b/3c Per-file minors that moved (old = this addon at v1.95.0, new = v1.105.0)
The file list is the tag's `LibKa0s.xml`; each constant comes from the one `[A-Z_]*MINOR` grep. Every file not
listed matched before the copy, so there is no cross-major skew.
```
Core.lua                         old: 17    new: 18
Tooltip.lua                      old: none  new: 1
Callout.lua                      old: none  new: 4
CalloutSettings.lua              old: none  new: 5
WaypointArrow.lua                old: none  new: 2
WaypointArrowSettings.lua        old: none  new: 2
Charts.lua                       old: 1     new: 2
Media.lua                        old: 12    new: 13
SkinDefs.lua                     old: 27    new: 28
SkinDefsOthers.lua               old: 8     new: 10
Widgets.lua                      old: 26    new: 27
WidgetsDropdown.lua              old: 1     new: 2
WidgetsReorder.lua               old: 6     new: 7
WidgetsDragHandle.lua            old: 13    new: 14
WidgetsDragHandleTip.lua         old: none  new: 1
WidgetsCopyWindow.lua            old: 5     new: 6
WidgetsHeader.lua                old: none  new: 1
WidgetsBar.lua                   old: none  new: 1
DebugLog.lua                     old: 22    new: 23
DebugLogDiagnostics.lua          old: 8     new: 11
DebugLogWindow.lua               old: 4     new: 5
Launcher.lua                     old: 10    new: 11
OptionsWidgets.lua               old: 45    new: 46
OptionsNav.lua                   old: 6     new: 7
OptionsSkinPicker.lua            old: 11    new: 12
OptionsSkinPickerQueue.lua       old: none  new: 1
IconBrowserWindow.lua            old: 1     new: 2
IconBrowser.lua                  old: 1     new: 2
PerfPanel.lua                    old: 13    new: 14
Sim.lua                          old: 2     new: 3
SimPanel.lua                     old: 10    new: 11
SimPanelRender.lua               old: 3     new: 4
```

## 3d Diffs
After the copy and before the prune, `diff -r --strip-trailing-cr` and `diff -r` of both payloads against the
v1.105.0 extract are both empty (content and bytes clean). The icon declaration is `all`, so the icon prune keeps
every icon. There is no `LibKa0s sounds:` line, so the sound prune removed all 362 files under
`media/sounds/callout/` (`prune-icons: .: sounds none (no LibKa0s sounds: line); kept 0 file(s), removed 362`).
No file was removed upstream in this range, so no `Only in libs/LibKa0s` line appeared. `tests/test_vendor_sync.lua`
is green.

New payload files: `Tooltip.lua`, `Callout.lua`, `CalloutSettings.lua`, `WaypointArrow.lua`,
`WaypointArrowSettings.lua`, `WidgetsDragHandleTip.lua`, `WidgetsHeader.lua`, `WidgetsBar.lua`,
`OptionsSkinPickerQueue.lua`, the fonts Bebas Neue and Russo One with their OFL texts, `media/waypoint/`, and the
kit's `mock_screen.lua` (opt-in). This addon's harness loads the library through `LibKa0s.xml`, so it needs no
loader lines.

## 3e Consumption map
`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' core modules settings --include='*.lua'`:
```
core/Bus.lua:17:LibStub("LibKa0s-Bus-1.0", true)
core/Compat.lua:115:LibStub("LibKa0s-Role-1.0", true)
core/Compat.lua:7:LibStub("LibKa0s-Compat-1.0", true)
core/CoreSetup.lua:19:LibStub("LibKa0s-Core-1.0", true)
core/DebugLogSetup.lua:10:LibStub("LibKa0s-DebugLog-1.0", true)
core/EnvSetup.lua:7:LibStub("LibKa0s-Env-1.0", true)
core/GlowSetup.lua:10:LibStub("LibKa0s-Glow-1.0", true)
core/IconBrowserSetup.lua:16:LibStub("LibKa0s-IconBrowser-1.0", true)
core/LauncherSetup.lua:11:LibStub("LibKa0s-Launcher-1.0", true)
core/LifecycleSetup.lua:10:LibStub("LibKa0s-Lifecycle-1.0", true)
core/MediaSetup.lua:10:LibStub("LibKa0s-Media-1.0", true)
core/PerfSetup.lua:15:LibStub("LibKa0s-Perf-1.0", true)
core/PoolSetup.lua:9:LibStub("LibKa0s-Pool-1.0", true)
core/SkinSetup.lua:113:LibStub("LibKa0s-Skin-1.0", true)
core/ToastSetup.lua:13:LibStub("LibKa0s-Toast-1.0", true)
core/WidgetsSetup.lua:18:LibStub("LibKa0s-Widgets-1.0", true)
modules/Library_Migrate.lua:255:LibStub("LibKa0s-Skin-1.0", true)
modules/Library_Migrate.lua:446:LibStub("LibKa0s-Skin-1.0", true)
settings/OptionsSetup.lua:11:LibStub("LibKa0s-Options-1.0", true)
settings/SchemaMembers.lua:444:LibStub("LibKa0s-Core-1.0", true)
settings/SchemaSetup.lua:213:LibStub("LibKa0s-Schema-1.0", true)
settings/Slash.lua:78:LibStub("LibKa0s-Slash-1.0", true)
```
Majors in the payload with no lookup here: LibKa0s-Callout-1.0, LibKa0s-Charts-1.0, LibKa0s-Item-1.0,
LibKa0s-Sim-1.0, LibKa0s-Tooltip-1.0 (new), LibKa0s-WaypointArrow-1.0.

## 3f Kit revision
```
old: tests/_kit/framework.lua:20:Kit.VERSION = 54
new: testkit/framework.lua:20:Kit.VERSION = 57
```
Both payloads are copied whole in one commit, so the kit pairing rule holds by construction. Kit 57 holds a frame
with a raw event registration until it unregisters (#75). No suite here relied on a collection dropping a frame:
both profiles are green with the same totals as before.

## 3g Contract delta and Blockers
Read from the tag's `CHANGELOG.md` blocks v1.96.0 to v1.105.0 ("What a consumer owes"), intersected with the
majors this addon looks up.
- **Stub members (the only red tests).** `tests/test_surface_parity.lua` checks two stubs by name. The DebugLog
  instance gained `Report` and `Serialize` (DebugLog minor 23, DebugLogDiagnostics minor 11). The Options
  instance gained `SideTabs` (OptionsNav minor 7, v1.100.0). Fixed in the re-vendor commit: `core/DebugLogSetup.lua`
  and `settings/OptionsSetup.lua` stubs.
- **Kit 57 vendor gate, `LIBRARY_MARKS` gains `settings`.** This addon declares `all`, so it already ships it.
- **Media minor 13** adds two faces (35). No font-list pin here went red.
- **OptionsWidgets minor 46** reverts slider-box junk text on Enter and on focus loss. This is a visible change on
  every number row, with no test change. It is a smoke line.
- **SkinDefs 28 and SkinDefsOthers 10** move Ka0s Default's list stripe, hover and selection and seven skins'
  `icon.hot`. This addon copies no Ka0s Default fallback value and pins no `icon.hot`. It is a smoke line.
- **Callout minor 3's boolean `glow`** does not apply: this addon does not consume Callout.
- **Header marks (#86), tooltip placers (#92), console footer (#90), plain Copy (#79)** reach the library's own
  windows from the copy alone (class A). They are smoke lines.

Blockers: none. No `__Attach*` call site exists outside `libs/` and `tests/_kit/`.

## 3h Span
The vendored-tag walk (`AUDIT.md` re-vendor check plus provenance rolls since the store's first bundle) lists
v1.75.0 to v1.95.0. Each one has a bundle. Unrecorded: none. No span bundle is owed.

## 3i Icon declaration
`grep -n 'LibKa0s icons:' CLAUDE.md` gives line 46, `LibKa0s icons: all (icon browser).`, the next non-blank line
after the provenance line. It is kept as written. The icon tree is unchanged between the two tags
(`diff -rq` of `media/icons` empty, `game-icons/AUTHORS.txt` identical), so the README credits stay as they are.

## 3j Whole-folder icon tests
`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` finds nothing.
Dead stub mirrors: `grep -rn '__releaseChrome'` outside `libs/` and `tests/_kit/` finds nothing.
