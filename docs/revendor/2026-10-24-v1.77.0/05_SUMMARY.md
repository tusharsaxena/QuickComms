# 05 — Summary (LibKa0s v1.76.0 -> v1.77.0)

- **Tag:** v1.76.0 -> v1.77.0 (local tag, commit `78240f7b2d69df27b74fc9280cbfbf7b95dd4f1f`). Base
  from `CLAUDE.md:42`, cross-checked against `3c81ba3`, the last payload commit, and a payload diff
  against v1.76.0.
- **Minors moved:** Core 11 -> 12, Widgets 14 -> 15, WidgetsDragHandle 4 -> 5, WidgetsAutocomplete
  2 -> 3, DebugLog 20 -> 21, Options 29 -> 30, OptionsIds 2 -> 3, OptionsCombat 1 -> 2,
  OptionsCompose 7 -> 8, OptionsKeybinds new at 3, PerfPanel 8 -> 9, SimPanel 5 -> 6. Kit revision
  41 -> 42. Table in `01_DELTA.md` 3c.
- **Span bundle:** none needed. No base correction: the v1.76.0 bundle's base is right.
- **Delivered for free (class A):** toplevel debug console and perf panel with the StaticPopup
  re-raise, dropdown menus and autocomplete lists clamped to screen, the ID suggestion list closed
  at combat start.
- **Contract blockers:** one. The Options degradation stub lacked `KeybindingsTab`, `KeybindRows`,
  `KEYBINDS_UNCHANGED` and `StrataTooltip`, which the kit's surface-parity case failed on; added in
  the re-vendor commit (`settings/OptionsSetup.lua`).
- **Icons:** `LibKa0s icons: all (icon browser).` kept at `CLAUDE.md:43`; the tag's
  `prune-icons.lua` removed nothing (0 Open Iconic, 0 Phosphor, 0 Game-icons). No provenance split.
- **Credits:** README `## Credits` unchanged; the shipped sets are the same three.
- **Dead stub mirrors:** none.
- **Adopted here:** nothing. Adopted later in the run: the Keybindings tab and kit 42's binding
  surfaces (QC-KB); DragHandle 5 and `mock_layers.lua` as QC-ZS decides.
- **Deferred (run 2026-10-24), no issue filed:** `O.StrataTooltip`, `Core.RaiseStaticPopups()`.
  Sim stays settled as not adopted.
- **Gates:** `luacheck .` 0 warnings / 0 errors in 139 files; `lua tests/run.lua` 1173 passed,
  0 failed, 1 skipped (1174 total), `test_vendor_sync` green against v1.77.0; no authored `.lua`
  file above 1500 lines (largest `tests/test_page_groups.lua`, 1499).
- **Smoke:** none owed by this re-vendor; QC-KB and QC-ZS write their own.
