# 05 — Summary (LibKa0s v1.74.0 -> v1.75.0)

- **Tag:** v1.74.0 -> v1.75.0 (local tag, commit `265a89eba3db44f2d85e61287d1691cca6b1effd`). Base
  from `CLAUDE.md:42`, cross-checked against `610f0d4`, the last payload commit.
- **Minors moved:** Core 10->11, Item 2->3, Widgets 12->13, DebugLog 19->20, DebugLogDiagnostics
  2->3, OptionsIdList 4->5, OptionsTabs 8->9, PerfPanel 6->7; new Glow 1, Sim 1, SimTimeline 1,
  SimPanel 1. Kit revision 39 -> 41. Table in `01_DELTA.md` 3c.
- **Span bundle:** none. This is the store's first bundle, so there is no horizon to back-fill from.
- **Delivered for free (class A):** the unexported `O.__releaseChrome`, DebugLogDiagnostics' Glow/Sim
  rows, kit 40's icon gate and kit 41's complexity-crash rule.
- **Contract blockers:** none needed a host change. The library-drawn-art contract (Core 11,
  DebugLog 20, OptionsIdList 5) is met by `all`.
- **Icons:** `LibKa0s icons: all (icon browser).` written at `CLAUDE.md:43`; the tag's
  `prune-icons.lua` removed nothing (0 Open Iconic, 0 Phosphor, 0 Game-icons). No provenance split.
- **Credits:** README `## Credits` unchanged; the 35 Game-icons authors match the tag's `AUTHORS.txt`.
- **Dead stub mirror removed:** `settings/OptionsSetup.lua:60` `H.__releaseChrome` (LibKa0s#45).
- **Adopted:** `LibKa0s-Glow-1.0`, as QC-01 (a later commit).
- **Not adopted (no issue filed; M2 is non-interactive, OWNER_SCOPE A decides):** `W.SearchBox`,
  `W.TestStrip`, `LibKa0s-Sim-1.0`, `Item.BonusIDsFromLink`. `W.StepPanel` did not ship.
- **Gates:** `luacheck .` 0 warnings / 0 errors in 134 files; `lua tests/run.lua` 1095 passed,
  0 failed, 1 skipped (1096 total), `test_vendor_sync` green against v1.75.0; no authored `.lua` file
  above 1500 lines (largest `tests/test_page_groups.lua`, 1499). `docs/test-cases.md` regenerated
  and unchanged (Total 1095), so the README badge stays. Complexity (informational): pass,
  `crashedFiles` 0, 17 functions above CCN 15, listed in `01_DELTA.md`.
- **Smoke (owner's, not run here):** the run's SM-QC-1 and SM-QC-2, written as ICON-2 and ICON-3 in `docs/smoke-tests.md`
  and listed under its Pending sign-off.
