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

## Re-vendor after the tag moved (M3)

- **Tag moved:** the local annotated tag v1.77.0 was re-closed by LK-95 for the M3 settings-layout
  surfaces. Old target commit `78240f7b2d69df27b74fc9280cbfbf7b95dd4f1f`; new target commit
  `afae2f75cb7ff61c57156d9a3d8a6b2b9f4c5e10` (tag object `b2b8ee25c5f9fa26db146254bf786b366dec986b`).
  Payload commits in between: LK-30 (`2c744ef`), LK-31 (`e1485fd`, `1e83c89`), LK-32 (`e8adf35`).
- **Minors moved:** OptionsCompose 8 -> 11. Every other file is byte-identical; the test kit is
  unchanged (revision 42).
- **Copy:** `libs/LibKa0s/` and `tests/_kit/` replaced whole from `git archive v1.77.0`. The
  `CLAUDE.md` provenance line stays `v1.77.0` (it records no sha or kit revision). The tag's
  `prune-icons.lua` removed nothing (`LibKa0s icons: all (icon browser).`); README credits unchanged.
- **Contract blocker:** one. The kit's Options surface-parity case failed on the new
  `ResetAllTooltip`; the library-absent branch of `settings/OptionsSetup.lua` now carries it as an
  inert member returning `""`.
- **Adopted here:** nothing. The layout surfaces (OptionsCompose 9-11) are QC-LY's.
- **Standards:** no drift; the addon's three-place reference names the standard without a version.
- **Gates:** `luacheck .` 0 warnings / 0 errors in 141 files; `lua tests/run.lua` 1189 passed,
  0 failed, 1 skipped (1190 total), `test_vendor_sync` green against the moved tag; no authored `.lua`
  file above 1500 lines (largest `tests/test_page_groups.lua`, 1499).

## Re-vendor after the tag moved again (one key button)

- **Tag moved:** LK-96 re-closed the local annotated tag v1.77.0 for the owner's follow-up to item
  015 (one key button and Clear per Keybindings row). Old target commit
  `afae2f75cb7ff61c57156d9a3d8a6b2b9f4c5e10`; new target commit
  `2f2b2e22b4c9219cd8a4101d7e894681c7aea16e` (tag object `e9b126d961c2970e5b14d0566480f7c1d8b5e5e8`).
  Payload commits in between: LK-40 (`f627436`, `7790dca`).
- **Minors moved:** OptionsKeybinds 3 -> 4. Every other library file is byte-identical. The test kit
  stays at revision 42; `bindings_xml.lua` (`Kit.keybindThroughTab` writes slot 2 through the model
  on a one-button row) and its README row changed.
- **Copy:** `libs/LibKa0s/` and `tests/_kit/` replaced whole from `git archive v1.77.0`. The
  `CLAUDE.md` provenance line stays `v1.77.0`. The tag's `prune-icons.lua` removed nothing
  (`LibKa0s icons: all (icon browser).`); README credits unchanged.
- **Contract blocker:** none. No public Options member was added, so the degradation stub in
  `settings/OptionsSetup.lua` is unchanged and the kit's surface-parity case stays green. No addon
  test drove slot 2 through the tab (`test_keybinds` binds slot 1 only).
- **Docs:** the tab's row is described as one key button and Clear, with `<key> +1` and a tooltip
  when the game's page holds a second key, in `README.md`, `docs/settings-panel.md`,
  `docs/smoke-tests.md` (KEY-5 and KEY-6 rewritten, pending) and the comment in `settings/Panel.lua`.
  `Bindings.xml`, `NS.BINDINGS` and the labels are untouched.
