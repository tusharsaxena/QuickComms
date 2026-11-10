Delta: LibKa0s v1.93.0 -> v1.95.0

Recorded before anything was committed. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.95.0 LibKa0s testkit tools` (tag commit e4493aa, local annotated tag, not yet pushed). Run under the QuickComms Forever port, item QFE-F1 (Ka0sAddonsCommonTasks docs/2026-11-10-QUICKCOMMS_FOREVER_EMOTES).

## 3a Base
- `grep -ioE 'Bundles \[LibKa0s\]\(...\) v...' CLAUDE.md` named v1.93.0 before the roll.
- Last payload commit before this run, `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 2f042d2; its CLAUDE.md names v1.93.0. They agree.
- Payload before the copy equalled the library at v1.93.0: `diff -rq --strip-trailing-cr` of both payloads against a v1.93.0 extract printed nothing (payload-matches).
- Library range: `git -C ../LibKa0s log --oneline v1.93.0..v1.95.0` is 7 commits (W1-LK-01, W1-LK-02, QFE-LK1, QFE-LK2 twice, and two merges).

## 3b/3c Per-file minors that moved (old = this addon, new = v1.95.0)
```
Skin.lua                 old: 17    new: 18
Compat.lua               old: 3     new: 4
DebugLogDiagnostics.lua  old: 7     new: 8
Role.lua                 old: none  new: 1
LibKa0s.xml              loads Role.lua after Compat.lua
```
Every file not listed matched v1.93.0 before the copy, so there is no cross-major skew.

## 3d Diffs
Post-copy, `diff -r --strip-trailing-cr` of both payloads against the v1.95.0 extract is empty; the icon declaration is `all`, so nothing was pruned. `tests/test_vendor_sync.lua` is green.

## 3e Consumption map
```
core/Bus.lua:17:LibStub("LibKa0s-Bus-1.0", true)
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
core/WidgetsSetup.lua:13:LibStub("LibKa0s-Widgets-1.0", true)
modules/Library_Migrate.lua:253:LibStub("LibKa0s-Skin-1.0", true)
modules/Library_Migrate.lua:444:LibStub("LibKa0s-Skin-1.0", true)
modules/PreviewWindow.lua:50:LibStub("LibKa0s-Widgets-1.0", true)
settings/Editors.lua:442:LibStub("LibKa0s-Widgets-1.0", true)
settings/OptionsSetup.lua:11:LibStub("LibKa0s-Options-1.0", true)
settings/SchemaMembers.lua:365:LibStub("LibKa0s-Core-1.0", true)
settings/SchemaSetup.lua:213:LibStub("LibKa0s-Schema-1.0", true)
settings/Slash.lua:76:LibStub("LibKa0s-Slash-1.0", true)
```
Majors in the payload with no lookup in this addon: LibKa0s-Charts-1.0 LibKa0s-Item-1.0 LibKa0s-Role-1.0 LibKa0s-Sim-1.0 LibKa0s-Toast-1.0 (Role is adopted by QFE-F4).

## 3f Kit revision
```
old: 20:Kit.VERSION = 53
new: 20:Kit.VERSION = 53
```
The kit is byte-identical between the two tags; both payloads are still copied whole in one commit.

## 3g Contract delta and Blockers
`git diff -U0 v1.93.0 v1.95.0 -- LibKa0s/`:
- Skin minor 18: `lib.CLIENT_DEFAULTS` and `lib:DefaultSkin()`. A choice with no skin, and an unregistered owner's `GetChoice`, now answer the client's default (WoW Forever on Forever) where they answered `lib.DEFAULT`. Same signatures, a changed answer on Forever. This addon always registers and always stores a skin, so the change reaches it only through its own default, which this commit names per client (`NS.DEFAULT_SKIN`).
- Compat minor 4: `RegionalNames`, `UnitCharacterName`, `CharacterKey`, `RealmKey`, added; no existing member changed.
- Role minor 1: a new major, `LibKa0s-Role-1.0`.
- DebugLogDiagnostics minor 8: Role joins the census roster.

Host-supplied members, `__Attach*` sites in this addon:
```
none
```
**Blockers: none.**

## 3h Unrecorded vendored tags
```
(empty)
```
v1.94.0 was never vendored here (wave 1 did not include QuickComms), so the range is recorded in this one bundle and no span bundle is owed.

## 3i Icon declaration
- `grep -n 'LibKa0s icons:' CLAUDE.md`: 45:LibKa0s icons: all (icon browser).
- Kept as written; the tag's `tools/prune-icons.lua` reported "declares all icons (icon browser); nothing removed".

## 3j Tests that assume the whole icon folder
```
none
```

## Dead stub mirrors
`grep -rn '__releaseChrome'` outside libs and the kit: none
