# 06 — Refresh (QuickComms): the local v1.75.0 tag moved

The local annotated tag v1.75.0 moved twice after this bundle's first copy (QC-RV, recorded in
01..05 at `265a89e`): to `6bf5f3e` (LK-26: `LibKa0s-Sim-1.0` minor 2, SimTimeline minor 2) and then
to `9e5c4e2` (LK-27: SimPanel minor 2, the picker reads its scenario at use; LibKa0s#54). `9e5c4e2`
is the tag's final position. The record of each move is the run bundle's `99_EXECUTION_RECORD.md`
("The local tag v1.75.0").

This file is added rather than editing 01..05, which stay frozen as the record of the first copy.

**How.** The same copy as QC-RV: `git -C ../LibKa0s archive v1.75.0 LibKa0s testkit`, both
payloads replaced whole, then the tag's `tools/prune-icons.lua` against the unchanged
`LibKa0s icons: all (icon browser).` line, which removed nothing. The provenance line stays
v1.75.0.

**Files that changed** (old `265a89e` -> new `9e5c4e2`):

| File | Minor |
|---|---|
| `libs/LibKa0s/Sim.lua` | `LibKa0s-Sim-1.0` 1 -> 2 |
| `libs/LibKa0s/SimTimeline.lua` | `TIMELINE_MINOR` 1 -> 2 |
| `libs/LibKa0s/SimPanel.lua` | `SIM_PANEL_MINOR` 1 -> 2 |

No other library file changed, and `tests/_kit/` is byte-identical to the previous copy (kit
revision 41). QuickComms does not load or wire Sim, and none of its own tests or docs pins a Sim,
SimTimeline or SimPanel minor, so nothing outside the payload changed.

**Gates.** `lua tests/run.lua` (bounded): 1102 passed, 0 failed, 1 skipped (1103 total), with
`test_vendor_sync` green against `9e5c4e2`. `luacheck .`: 0 warnings / 0 errors in 135 files. No
authored `.lua` file is above 1500 lines (largest `tests/test_page_groups.lua`, 1499).
