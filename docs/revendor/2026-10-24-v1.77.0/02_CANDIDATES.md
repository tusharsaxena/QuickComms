# 02 — Candidates (LibKa0s v1.76.0 -> v1.77.0)

Sources: `git -C ../LibKa0s log --oneline v1.76.0..v1.77.0`, the tag's `CHANGELOG.md` `## v1.77.0`
block, and the tag's `docs/api/` documents named in `01_DELTA.md` 3g. The item spec (QC-RV of
Ka0sAddonsCommonTasks `docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/`) pre-decides each one; nothing here
was put to an interview.

## Class A — delivered on the copy, no host change

- **Toplevel tool windows and the StaticPopup re-raise** (Core 12, DebugLog 21, PerfPanel 9,
  SimPanel 6): the debug console and the perf panel rise among their DIALOG peers on a click and keep
  a shown confirmation on top.
- **Popups clamped to screen** (Widgets 15, WidgetsAutocomplete 3): every `lib.Dropdown` menu and
  autocomplete list QuickComms opens stays on screen near an edge.
- **The ID suggestion list closes at combat start** (OptionsIds 3, OptionsCombat 2).
- **Kit revision 42** arrives with the copy; its three new files are opt-in.

## Class B / C — candidates

| Candidate | Class | Evidence | Would touch | Recommendation | Blast radius |
|---|---|---|---|---|---|
| `O.KeybindingsTab` / `O.KeybindRows` / `O.KEYBINDS_UNCHANGED` (OptionsKeybinds 2-3) | B | CHANGELOG v1.77.0, *OptionsKeybinds minor 2*; `docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md:61`, `:1539-1541` | `settings/`, `Bindings.xml`, tests | Adopt, in **QC-KB** (item 015) | additive |
| Kit `mock_bindings.lua`, `Kit.assertBindingsXml`, `Kit.keybindThroughTab` (kit 42) | B | `docs/api/testkit/version-42-docs.md:26` | `tests/` | Adopt, in **QC-KB** | additive (tests) |
| DragHandle `spec.level`, `spec.ignoreParentAlpha`, `handle:ApplyLevel()` (DragHandle 5) | B | `docs/api/Widgets/version-15.1.5.3.3-docs.md:39`, `:45` | `modules/Pad.lua:296` | Adopt only as **QC-ZS** (item 030, held for the owner) decides; not here | replaces a hand re-level |
| Kit `mock_layers.lua` (kit 42) | B | `docs/api/testkit/version-42-docs.md:82` | `tests/` | As **QC-ZS** decides | additive (tests) |
| `O.StrataTooltip` (OptionsCompose 8) | B | CHANGELOG v1.77.0, *OptionsCompose minor 8*; `version-30…-docs.md:86` | none (no player strata row) | deferred (run 2026-10-24); the CHANGELOG names AuraMaster, MultiMeters, PanelMaster and PartyFrameEnhanced as its adopters | n/a |
| `Core.RaiseStaticPopups()` (Core 12) | B | `docs/api/Core/version-12-docs.md:24` | none | deferred (run 2026-10-24); the library's own windows already call it | n/a |
| `LibKa0s-Sim-1.0` (SimPanel 6) | C (unconsumed major) | CHANGELOG v1.77.0 | none | Not adopted: settled at v1.75.0 (`2026-10-22-v1.75.0/03_DECISIONS.md`), no simulator here; v1.77.0 changes no premise | n/a |
