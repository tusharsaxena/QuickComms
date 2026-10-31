Delta: LibKa0s v1.80.0 -> v1.83.0 (span: v1.80.0 v1.81.0 v1.82.0 v1.83.0)

# 01 — Delta (consolidated span)

Four LibKa0s tags this addon vendored after its v1.77.0 bundle without a bundle of their own. Each
arrived as an item of a cross-repo run, whose plan holds the reasoning. v1.78.0 and v1.79.0 were never
vendored here: the addon went from v1.77.0 to v1.80.0 in one copy.

| Tag | Commit there | Commit here | Kit | Run (Ka0sAddonsCommonTasks `docs/`) |
|---|---|---|---|---|
| v1.80.0 | `912f1b4` | `6b0b9c7` | 44 | `2026-10-29-SKINNING_ROLLOUT/` |
| v1.81.0 | `aefeba9` | `d1b79d1` | 44 | `2026-10-30-SKIN_LIBRARY_FOLLOWUPS/` |
| v1.82.0 | `277081f` | `2f68eb0` | 45 | `2026-10-30-SKIN_FONTS_AND_FEEDBACK/` |
| v1.83.0 | `6c816fd` | `f291948` (at `3122d87`), re-cuts `73370ed`, `3051fa0`, `15dde36` | 46 | `2026-10-31-FONT_PICKERS_AND_SKIN_FACES/` |

The v1.83.0 tag moved three times while its run was open, and each move was re-vendored here: `73370ed`
took LK-A1 and LK-A2 (`ec41b22`), `3051fa0` took the picker rows of LK-A3 (`bd4fb11`, five payload
files) and `15dde36` took the event-free wake of LK-A3 (`6c816fd`, `OptionsSkinPicker.lua` only).
`6c816fd` is where the tag stands, and the addon's payload matches it (`tests/test_vendor_sync.lua`).

What moved in the library, by file and LibStub minor, for what this addon wires:

| Tag | New files | Minors moved that this addon wires |
|---|---|---|
| v1.80.0 | `Skin.lua`, `SkinAce.lua`, `SkinDefs.lua`, `SkinEUI.lua`, `SkinPaint.lua`, `SkinPaintControls.lua`, `SkinPaintExtras.lua`, `OptionsAppearance.lua`, `OptionsSkinPicker.lua`, `DebugLogWindow.lua`, `Toast.lua`, `WidgetsCopyWindow.lua` | Core 12 -> 13, Media 5 -> 9, Options 30 -> 34, DebugLog 21 -> 22, Widgets 15 -> 16 |
| v1.81.0 | none | Core 13 -> 14, Skin 7 -> 8, Widgets 16 -> 17 |
| v1.82.0 | `OptionsSwitch.lua` | Media 9 -> 10, Skin 8 -> 9, `OptionsWidgets.lua` 36 -> 37 |
| v1.83.0 | `OptionsMedia.lua` | Media 10 -> 11, Skin 9 -> 10, `OptionsWidgets.lua` 37 -> 38 |

Found on 2026-10-31 by reading `CLAUDE.md`'s provenance line at each commit that touched `libs/LibKa0s`,
against the tags `docs/revendor/` holds (v1.75.0, v1.75.1, v1.76.0, v1.77.0).

Vendored and unrecorded: v1.80.0, v1.81.0, v1.82.0, v1.83.0.
