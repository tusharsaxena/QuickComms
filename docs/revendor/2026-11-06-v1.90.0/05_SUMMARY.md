# Summary (QuickComms)

LibKa0s v1.89.0 -> v1.90.0 (local tag `4485b8f`), item `SF1-RV-QC`. The base is the `CLAUDE.md`
provenance line (v1.89.0), which agreed with the last payload commit `5b24443`; Step 0 read `ok`, so no
base correction. No span bundle: every tag vendored since 2026-10-22 has a bundle.

| File | Old | New |
|---|---|---|
| `Core.lua` | 15 | 16 |
| `Skin.lua` | 16 | 17 |
| `SkinPaint.lua` | 18 | 19 |
| `SkinPaintExtras.lua` | 17 | 18 |
| `Widgets.lua` | 23 | 24 |
| `WidgetsAutocomplete.lua` | 7 | 8 |
| `OptionsAppearance.lua` | 6 | 7 |
| kit `framework.lua` (`Kit.VERSION`) | 51 | 51 |

- **For free (class A):** the preview window's `W.Dropdown` and its menu draw a one-physical-pixel edge
  at any UI scale (`SF1-L1`); Core's and the skin painter's pixel internals behind it.
- **Blockers:** none. No member a host owes moved, no `__Attach*` site, no `__releaseChrome` mirror, no
  whole-catalog icon test.
- **Icons:** `LibKa0s icons: all (icon browser).` kept. Prune: "declares all icons (icon browser);
  nothing removed". No provenance split, no README provenance line, no credit change (no `media/` file
  moved in the range).
- **Adopted:** nothing in this item.
- **Declined:** nothing; no issue filed. `keepScope` is not applicable (`03_DECISIONS.md`).
- **Unreached / undecided:** none.
- **Diffs after the copy:** content and bytes empty for `libs/LibKa0s/` against the tag and for
  `tests/_kit/` against `testkit/`.
- **Gate:** `ka0s-bounded luacheck .` 0 warnings / 0 errors in 164 files; `ka0s-bounded lua
  tests/run.lua` 1706 passed, 0 failed, 1 skipped (the diagnostics opt-out case, which this addon does
  not take), 1707 total (16 shards). Largest own file `locales/enUS.lua` at 1383 lines, under the 1500
  cap. No own Lua changed, so no function's complexity moved.
