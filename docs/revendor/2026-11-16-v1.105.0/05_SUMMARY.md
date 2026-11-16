# 05 Summary

- Tag moved v1.95.0 -> v1.105.0. The base comes from the CLAUDE.md provenance line and agrees with the last
  payload commit (48c8d25). Kit revision 54 -> 57. The per-file minor table is in 01_DELTA.md (32 files moved,
  9 of them new).
- Span bundle: none owed. Base correction: none.
- Delivered for free (class A): header marks on the library's windows, the library's tooltips on the placers,
  the console footer and plain Copy, the skin color moves, the slider-box revert.
- Contract blockers: none. The red tests were stub parity only: DebugLog `Report` and `Serialize`, Options
  `SideTabs`. Both stubs gained the members in this commit.
- `LibKa0s icons: all (icon browser).` kept. The prune kept every icon and removed 362 sound files (no
  `LibKa0s sounds:` line). No provenance split.
- README credits: unchanged (the icon sets and `game-icons/AUTHORS.txt` did not move). Dead stub mirrors: none.
- Refresh file: none.
- Adopted: nothing. Declined: nothing. Unreached (phase [3]): LibKa0s#92, #79, #86, #87, #85, #82 (02_CANDIDATES.md).
- Gate (both before the commit): `ka0s-bounded lua tests/run.lua` 2030 passed, 0 failed, 1 skipped, 2031 total
  (16 shards); `KA0S_KIT_CLIENT=forever` the same; `ka0s-bounded luacheck .` 0 warnings / 0 errors in 180 files.
  Before the stub fixes, both profiles had 2 failures (the two parity cases).
