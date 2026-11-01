Delta: LibKa0s v1.84.0 -> v1.85.0

Base taken from the provenance line: `grep -n Bundles CLAUDE.md` read v1.84.0, and the last payload commit `79f827f` (M4-RV) carries it. v1.84.0 was re-cut once (`docs/revendor/2026-11-01-v1.84.0-recut`).

Tag: v1.85.0 is local, at `9776130` (`git -C ../LibKa0s rev-parse "v1.85.0^{commit}"`); `git ls-remote --tags origin v1.85.0` prints nothing. It is taken here at its last cut, so this bundle needs no refresh.

## Per-file minors

From the tag's `LibKa0s.xml` and each file's `[A-Z_]*MINOR` constant:

| File | Old | New |
|---|---|---|
| `Glow.lua` | 1 | 2 |
| `Toast.lua` | 1 | 2 |
| `Skin.lua` | 11 | 14 |
| `SkinDefs.lua` | 19 | 24 |
| `SkinDefsOthers.lua` | 1 | 6 |
| `SkinPaint.lua` | 13 | 16 |
| `SkinPaintExtras.lua` | 7 | 15 |
| `SkinPaintControls.lua` | 11 | 14 |
| `SkinEUI.lua` | 2 | 3 |
| `SkinAce.lua` | 6 | 9 |
| `Widgets.lua` | 17 | 20 |
| `WidgetsReorder.lua` | 3 | 5 |
| `WidgetsDragHandle.lua` | 10 | 12 |
| `WidgetsLineChart.lua` | 5 | 6 |
| `WidgetsAutocomplete.lua` | 5 | 6 |
| `WidgetsCopyWindow.lua` | 2 | 4 |
| `DebugLogWindow.lua` | 2 | 3 |
| `Launcher.lua` | 5 | 6 |
| `OptionsWidgets.lua` | 41 | 44 |
| `OptionsIds.lua` | 6 | 7 |
| `OptionsIdList.lua` | 7 | 8 |
| `OptionsTabs.lua` | 13 | 15 |
| `OptionsCompose.lua` | 16 | 17 |
| `OptionsScroll.lua` | 10 | 13 |
| `OptionsNav.lua` | 4 | 5 |
| `OptionsDrawer.lua` | 4 | 5 |
| `OptionsKeybinds.lua` | 6 | 7 |
| `OptionsAppearance.lua` | 5 | 6 |
| `OptionsSkinPicker.lua` | 5 | 7 |
| `OptionsMedia.lua` | 3 | 4 |
| `PerfPanel.lua` | 11 | 12 |
| `SimPanel.lua` | 9 | 10 |
| `SimPanelRender.lua` | 1 | 2 |

Kit revision 47 -> 49 (`grep -n Kit.VERSION`), in the same commit as the bytes.

## Blockers

- The degradation stubs: `core/SkinSetup.lua`'s facade gains `Mark`, `MarkText`, `HudTextColor`, `HudLabelColor`, `BarFillColor`, `HudShadow`, `BarGloss` and `HudFont` (Options doc, *Moving to this version* section 7), and `settings/OptionsSetup.lua`'s stub `O.LabelFont` (`docs/releasing.md`, step 8 for v1.85.0). Fixed in this commit.

## Icons

`LibKa0s icons: all (icon browser).` stays: it covers the owed `chevron-down, chevron-up, close, confirm, info, move, reset, volume-high`, decided by the plan. Nothing pruned, no credit moves.
