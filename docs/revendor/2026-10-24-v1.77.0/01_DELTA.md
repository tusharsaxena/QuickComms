Delta: LibKa0s v1.76.0 -> v1.77.0

# 01 — Delta

Re-vendor of LibKa0s into QuickComms, run 2026-10-24 as item QC-RV of the cross-repo run
"keybindings (015), settings layout (020), frame strata (030)" (Ka0sAddonsCommonTasks
`docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/`). The procedure is the installed dev-copilot 2.4.0
`/dev-copilot:wow-revendor-libka0s`, run without its interview: the item spec pre-decides every
adoption (QC-KB and QC-ZS adopt; everything else is deferred), and M2 files no GitHub issues.

The new tag is a LOCAL tag on the run branch (not pushed at the time of this record;
`git -C ../LibKa0s ls-remote --tags origin v1.77.0` prints nothing):

```sh
git -C ../LibKa0s rev-parse v1.77.0              # 7380d3662be0568acf9a0d224a6aef8ac6df93ce (tag object)
git -C ../LibKa0s rev-parse 'v1.77.0^{commit}'   # 78240f7b2d69df27b74fc9280cbfbf7b95dd4f1f
git -C ../LibKa0s rev-parse 'v1.76.0^{commit}'   # e69249146e9c2d81f7e2663744ab0c622c4f3b25
git -C ../LibKa0s archive v1.77.0 LibKa0s testkit tools | tar -x -C <scratch>
```

## Step 0. Pre-flight

The newest single-tag bundle, `2026-10-23-v1.76.0`, states base v1.75.2; the provenance line before
its re-vendor commit `77e8ff0` named v1.75.2. **ok**, no correction.

## 3a. Claimed version (the base)

```sh
grep -n '[Bb]undles' CLAUDE.md
# 42:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.76.0 (MIT).
git log -1 --format='%h %s' -- libs/LibKa0s tests/_kit
# 3c81ba3 QC-RV2: refresh vendored LibKa0s from the moved local tag v1.76.0
git -C ../LibKa0s archive v1.76.0 LibKa0s testkit | tar -x -C <scratch>/claimed
diff -rq <scratch>/claimed/LibKa0s libs/LibKa0s && diff -rq <scratch>/claimed/testkit tests/_kit && echo payload-matches
# payload-matches
```

The base is **v1.76.0**.

```sh
git -C ../LibKa0s log --oneline v1.76.0..v1.77.0
# 78240f7 LK-90: close v1.77.0 with its release record (20261024-074358)
# 3c2bb20 LK-90: split three functions over CCN 15 that the release run found
# ea2cb09 LK-90: close v1.77.0: version block, pointers, consumers, band
# 0a5807d LK-13: Sync the Keybindings tab with Options -> Keybindings
# 9ab9d37 LK-12: Add the Keybindings tab, OptionsKeybinds minor 2
# 0b10ad3 LK-11: address review — refuse BUTTON1/BUTTON2 on the client chord route
# 88dfa8a LK-11: Add OptionsKeybinds.lua minor 1, the key binding model
# 66b7bd4 LK-20: Add O.StrataTooltip, the one shared strata-row tooltip
# 7de587b LK-04: Close the IdList suggestion list at the start of combat
# f452d69 LK-03: Clamp the dropdown menu and the autocomplete list to the screen
# dda3ff9 LK-02: Add DragHandle level offset, ApplyLevel and ignoreParentAlpha
# 665bf63 LK-01: Make the tool windows toplevel and re-raise shown StaticPopups
# 8173cdb LK-10: Kit revision 42: binding mock, layer recorder, Bindings.xml check
# 0a1683a LK-00: Open v1.77.0 with an unreleased CHANGELOG section
# 9df6df8 Merge branch 'feat/2026-10-23-sim-preview-mode-strips'
```

## 3b. Actual version

The minors under `libs/LibKa0s/` before the copy were exactly v1.76.0's (the `payload-matches` above).

## 3c. Per-file minor delta

The 3c loop over the tag's `LibKa0s/LibKa0s.xml`, filtered to files whose constant moved:

| File | v1.76.0 | v1.77.0 |
|---|---|---|
| `Core.lua` | `MINOR = 11` | `MINOR = 12` |
| `Widgets.lua` | `MINOR = 14` | `MINOR = 15` |
| `WidgetsDragHandle.lua` | `DRAG_MINOR = 4` | `DRAG_MINOR = 5` |
| `WidgetsAutocomplete.lua` | `AUTOCOMPLETE_MINOR = 2` | `AUTOCOMPLETE_MINOR = 3` |
| `DebugLog.lua` | `MINOR = 20` | `MINOR = 21` |
| `Options.lua` | `MINOR = 29` | `MINOR = 30` |
| `OptionsIds.lua` | `IDS_MINOR = 2` | `IDS_MINOR = 3` |
| `OptionsCombat.lua` | `COMBAT_MINOR = 1` | `COMBAT_MINOR = 2` |
| `OptionsCompose.lua` | `COMPOSE_MINOR = 7` | `COMPOSE_MINOR = 8` |
| `OptionsKeybinds.lua` | (new) | `KEYBINDS_MINOR = 3` |
| `PerfPanel.lua` | `PANEL_MINOR = 8` | `PANEL_MINOR = 9` |
| `SimPanel.lua` | `SIM_PANEL_MINOR = 5` | `SIM_PANEL_MINOR = 6` |

Every other file is at its v1.76.0 minor. One file is new (`OptionsKeybinds.lua`, the twelfth
Options file, listed in the tag's `LibKa0s.xml`; `tests/loader.lua` reads that XML, so the harness
loads it with no edit). None is removed. No cross-major skew.

## 3d. Both diffs

Before the copy, `diff -rq <scratch>/LibKa0s libs/LibKa0s` named the eleven changed files above plus
`LibKa0s.xml`, and `Only in <scratch>/LibKa0s: OptionsKeybinds.lua`; `diff -rq <scratch>/testkit
tests/_kit` named `README.md` and `framework.lua` and three new files (`bindings_xml.lua`,
`mock_bindings.lua`, `mock_layers.lua`). After `cp -r`, all four diffs (with and without
`--strip-trailing-cr`, both payloads) were empty, before the prune. No `Only in libs/LibKa0s` line:
nothing to delete.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

Glow, Env, Media, Compat, Launcher, Lifecycle, Core, Bus, DebugLog, Perf, Widgets, Pool
(`core/*Setup.lua`, `core/Bus.lua`, `core/Compat.lua`), Widgets again in `settings/Editors.lua` and
`modules/PreviewWindow.lua`, Options (`settings/OptionsSetup.lua`), Core again in
`settings/SchemaMembers.lua`, Schema (`settings/SchemaSetup.lua`), Slash (`settings/Slash.lua`). Of
the moved majors, **Core, Widgets, DebugLog, Options and Perf** are consumed; **Sim** is not.

## 3f. Kit revision

`Kit.VERSION = 42` in the tag's `testkit/framework.lua`; `tests/_kit/framework.lua` was at 41. The
two payloads move together (the pairing rule), so `tests/_kit/` was re-copied whole in the same
commit as `libs/LibKa0s/`. The three new kit files are opt-in; this commit installs none of them
(QC-KB installs `mock_bindings.lua` and calls `T.assertBindingsXml` / `T.keybindThroughTab`; QC-ZS
installs `mock_layers.lua`).

## 3g. Contract delta

Read for the consumed moved majors, against the tag's documents:
`docs/api/Core/version-12-docs.md`, `docs/api/Widgets/version-15.1.5.3.3-docs.md`,
`docs/api/DebugLog/version-21.3.1-docs.md`, `docs/api/Perf/version-15.1.1.9-docs.md`,
`docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md` (each with its v1.76.0 predecessor), and
the tag's `CHANGELOG.md` `## v1.77.0` block, *What a consumer owes*.

```sh
grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit
# (no hit): QuickComms hands no host member to an __Attach* seam
```

- **Core 12** adds `RaiseStaticPopups()` (`docs/api/Core/version-12-docs.md:24`); the debug console,
  perf panel and sim panel become toplevel and re-raise a shown StaticPopup on show. Additive; the
  CHANGELOG's line for it reads "What a consumer owes: nothing". The copy window stays
  FULLSCREEN and not toplevel, so QuickComms' FULLSCREEN modal band (XS-12) is not covered on show.
  Whether QuickComms' own surfaces at DIALOG or above note in their LAYERS comment that the console
  can cover them is QC-ZS's.
- **Widgets 15 / DragHandle 5 / Autocomplete 3**: popups clamped to screen (delivered); `spec.level`,
  `spec.ignoreParentAlpha` and `handle:ApplyLevel()` are opt-in (**Since DragHandle 5**,
  `docs/api/Widgets/version-15.1.5.3.3-docs.md:39`, `:45`). With neither field passed the strip is
  minor 4's exactly. QuickComms' pad strip (`modules/Pad.lua:296`) passes neither.
- **DebugLog 21, PerfPanel 9**: the toplevel and re-raise above; nothing owed.
- **Options 30 / Ids 3 / Combat 2 / Compose 8 / Keybinds 3**: the suggestion list closing at combat
  start is `__`-only and delivered on the copy. **Four new public instance members**,
  `KeybindingsTab`, `KeybindRows`, `KEYBINDS_UNCHANGED` (`version-30…-docs.md:1539-1541`) and
  `StrataTooltip` (`:86`), are opt-in, but the CHANGELOG states that every Options degradation stub
  gains them, because `Kit.assertSurfaceParity` compares the stub with the live instance.

### Blockers

One, of the surface-parity kind rather than a call-site move:

- **The Options degradation stub lacked four members.** After the copy, `lua tests/run.lua` failed
  exactly one case, `parity: the Options helpers stub carries the whole live surface`
  (`tests/_kit/asserts.lua:330`: "KEYBINDS_UNCHANGED is missing (live: string); KeybindRows is
  missing (live: function); KeybindingsTab is missing (live: function); StrataTooltip is missing
  (live: function)"). Fixed in this commit in `settings/OptionsSetup.lua`'s library-absent branch:
  `KeybindingsTab` answers nil (no tab entry), `KeybindRows` nil (the live instance's degraded
  answer), `KEYBINDS_UNCHANGED` `""` and `StrataTooltip` `""`, since no panel renders there. The
  same shape BankLedger and LootHistory took in this run.

No host-supplied member's call site moved.

## 3h. Span bundle

The 3h listing (`vendored.txt` = v1.75.0, v1.75.1, v1.75.2, v1.76.0; `recorded.txt` covers all four)
prints nothing. No span bundle.

## 3i. The icon declaration

`CLAUDE.md:43` `LibKa0s icons: all (icon browser).`, directly under the provenance line at
`CLAUDE.md:42`. Kept, as the item spec decides. The tag's prune: `prune-icons: . declares all icons
(icon browser); nothing removed`. The owner's in-client smoke stays the backstop for any icon the
gate cannot see.

## 3j. Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`: no hit.

## Dead stub mirrors

`grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`: no hit.
