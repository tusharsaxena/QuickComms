# Summary (QuickComms)

LibKa0s v1.85.0 -> v1.86.0 (tag `cad1609`), kit 50 unchanged, by hand for Task 2.1 of OutfitterReborn's
`docs/superpowers/plans/2026-11-04-sheet-window-feedback.md` (M2). Minors are in `01_DELTA.md`.
`libs/LibKa0s/` and `tests/_kit/` are exact copies, and the icon declaration is `all`, so nothing is
pruned. The adoption is the plan's, an owner ruling (the spec's G6), so this run interviewed no one and
wrote no candidates file.

- **Adopted: `LibKa0s-IconBrowser-1.0`.** `core/IconBrowserSetup.lua` is its seam (`NS.IconBrowserLib`).
  `settings/IconBrowser.lua` is now the adapter: it builds the one browser with `IB:New` (the brand,
  `LAYERS` MODAL / MODAL_OVER / POPUP, the Options instance, `NS.Print`, `Compat.InCombat`, AceTimer,
  `NS.MakeCopyWindow` under the old window names, `LINK_TITLE` from `L`, the editors' picker tracking)
  and keeps `Settings.IconBrowser`'s calls and fields, so the callout popup and the editors did not
  change. The settings window's hide, `PROFILE_CHANGED`, `LIBRARY_CHANGED` (`Revalidate`) and the
  stand-down (`StandDown` / `StandUp`) stay the host's.
- **Retired with it:** `settings/IconBrowser_Sources.lua`, `Compat.MacroIcons`, `IconStyle.WindowIcon`,
  `NS.IconNames` / `NS.IconSets` / `NS.IconAuthor`, the `qc.selStrong`, `qc.markGray` and `qc.note`
  tokens (the library's `ib.*` carry the same values), the browser's locale strings (the library's
  English is the same words), both `Kit.skinValues` rows and the skin-windows allow row, and the
  `localization-§1` deviation row on the Glyphs labels, which are the library's now.
- **Aliases:** `Library.IsGlyph`, `ValidIconColor`, `IconTint` and `IconColorFrom` call the major;
  `ValidIconColor` keeps this addon's `badIconColor` reason. `IsGlyph` now also reads a glyph path at
  another Ka0s addon's folder, the library's rule.
- **Tests:** `tests/test_icon_browser.lua` went from 37 cases to 13, the adapter's; the browser's own
  cases are the library's. 1705 pass, luacheck 0/0.
- No issue was filed: nothing was declined.
