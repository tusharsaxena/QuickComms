# Summary (QuickComms)

LibKa0s v1.86.0 -> v1.89.0 (tag `df00e5f`), item `V89-QC`. The base is the `CLAUDE.md` provenance
line (v1.86.0), which agreed with the last payload commit `7398649`; Step 0 read `ok`, so no base
correction. No span bundle: every tag vendored since 2026-10-22 has a bundle.

| File | Old | New |
|---|---|---|
| `Toast.lua` | 3 | 4 |
| `Widgets.lua` | 22 | 23 |
| kit `framework.lua` (`Kit.VERSION`) | 50 | 51 |

- **For free (class A):** kit 51's CallbackHandler unregister guard (a flake fix in the suite's mock);
  Widgets 23's `CloseMenu` closing every cascade level, which `modules/PreviewWindow.lua` already
  calls; `W.Dropdown` unchanged.
- **Blockers:** none. No Toast stub here, no `__Attach*` site, no `__releaseChrome` mirror, no
  whole-catalog icon test.
- **Icons:** `LibKa0s icons: all (icon browser).` kept. Prune: "declares all icons (icon browser);
  nothing removed". No provenance split, no README provenance line, no credit change (no `media/` file
  moved in the range).
- **Adopted:** nothing in this item; the plan names no adoption for QuickComms.
- **Declined:** nothing; no issue filed. Cascading-menu fields and the Toast stack are not applicable
  (`03_DECISIONS.md`).
- **Unreached / undecided:** none.
- **Diffs after the copy:** content and bytes empty for `libs/LibKa0s/` against the tag and for
  `tests/_kit/` against `testkit/`.
- **Gate:** `ka0s-bounded luacheck .` 0 warnings / 0 errors in 164 files; `ka0s-bounded lua
  tests/run.lua` 1706 passed, 0 failed, 1 skipped (the diagnostics opt-out case, which this addon does
  not take), 1707 total (16 shards). Largest own file `locales/enUS.lua` at 1383 lines, under the
  1500 cap.
