# Summary (QuickComms)

LibKa0s v1.90.0 -> v1.91.0 (local tag `55bfbb4`), item `FU-RV-QC`. The base is the `CLAUDE.md`
provenance line (v1.90.0), which agreed with the last payload commit `71321d6`. Step 0 was skipped
collection-wide (its roster regex matches nothing in the installed skill, fixed upstream as `FU-DC1`);
this addon's own row read `ok`, so no base correction. No span bundle: every tag vendored since
2026-10-22 has a bundle.

| File | Old | New |
|---|---|---|
| `Core.lua` | 16 | 17 |
| `CorePixel.lua` | new | 1 |
| `SkinPaintExtras.lua` | 18 | 19 |
| `SkinPaintHud.lua` | new | 1 |
| `SkinAceConfirm.lua` | new | 1 |
| `Widgets.lua` | 25 | 26 |
| `WidgetsDropdown.lua` | new | 1 |
| `WidgetsLineChart.lua` | 6 | 7 |
| kit `framework.lua` (`Kit.VERSION`) | 51 | 51 |

- **For free (class A):** the line chart's physical-pixel lines (`FU-L1`; QuickComms draws no chart),
  and the four peels (`FU-L2`), pure moves under unchanged members.
- **Blockers:** none. `tests/loader.lua` reads the library list from `LibKa0s.xml`, so the four new
  files load in the tag's order with no edit; no test pins an exact library minor; no stub mirrors a
  moved member; no `__Attach*` site; no `__releaseChrome` mirror; no whole-catalog icon test.
- **Icons:** `LibKa0s icons: all (icon browser).` kept. Prune: "declares all icons (icon browser);
  nothing removed". No provenance split, no README provenance line, no credit change (no `media/` file
  moved in the range).
- **Adopted:** nothing. **Declined:** nothing; no issue filed. **Unreached / undecided:** none.
- **Diffs after the copy:** content and bytes empty for `libs/LibKa0s/` against the tag and for
  `tests/_kit/` against `testkit/`.
- **Gate:** `ka0s-bounded luacheck .` 0 warnings / 0 errors in 164 files; `ka0s-bounded lua
  tests/run.lua` 1706 passed, 0 failed, 1 skipped (the diagnostics opt-out case, which this addon does
  not take), 1707 total (16 shards). Largest own file `locales/enUS.lua` at 1383 lines, under the 1500
  cap. No own Lua changed, so no function's complexity moved.
