# 05 — Summary (LibKa0s v1.75.2 -> v1.76.0)

- **Tag:** v1.75.2 -> v1.76.0 (local tag, commit `9949368df8db12e51c9c51e403738989c87709a5`). Base
  from `CLAUDE.md:42`, cross-checked against `4116872`, the last payload commit, and a payload diff
  against v1.75.2.
- **Minors moved:** Widgets 13 -> 14, SimTimeline 2 -> 3, SimPanel 4 -> 5. Kit revision 41
  unchanged. Table in `01_DELTA.md` 3c.
- **Span bundle:** `2026-10-23-v1.75.1-v1.75.2/`, two tags (v1.75.1, v1.75.2), both carried by
  sweep with nothing adopted. No base correction: the v1.75.0 bundle's base is right.
- **Delivered for free (class A):** Widgets 14's re-paired attach files; no surface this addon calls
  changed what it draws.
- **Contract blockers:** none. Widgets 14 is additive (`opts.kind`, `strip.kind`), and this addon
  does not call `TestStrip` or look up Sim.
- **Icons:** `LibKa0s icons: all (icon browser).` kept at `CLAUDE.md:43`; the tag's
  `prune-icons.lua` removed nothing (0 Open Iconic, 0 Phosphor, 0 Game-icons). No provenance split.
- **Credits:** README `## Credits` unchanged; the shipped sets are the same three.
- **Dead stub mirrors:** none.
- **Adopted:** nothing.
- **Not adopted (no issue filed; M2 is non-interactive, OWNER_SCOPE decides):** `W.TestStrip`
  `kind = "sim"`, `LibKa0s-Sim-1.0` auto-run.
- **Gates:** `luacheck .` 0 warnings / 0 errors in 135 files; `lua tests/run.lua` 1102 passed,
  0 failed, 1 skipped (1103 total), `test_vendor_sync` green against v1.76.0; no authored `.lua`
  file above 1500 lines (largest `tests/test_page_groups.lua`, 1499).
- **Smoke:** none owed by this re-vendor; the run's QuickComms smoke checks belong to QC-02 to QC-04.
