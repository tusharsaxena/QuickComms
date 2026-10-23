# 06 — Refresh (QuickComms): the local v1.76.0 tag moved

The local annotated tag v1.76.0 moved after this bundle's first copy (QC-RV, recorded in 01..05 at
`9949368`): to `7e81ff7` (LK-91: step-panel labels bounded before the command column, so a long
label truncates with an ellipsis instead of running under the slash command) and then to `e692491`
(LK-92: README only, no payload change). `e692491` is the tag's position at this refresh; its
payload equals `7e81ff7`'s. The record of each move is the run bundle's `99_EXECUTION_RECORD.md`.

This file is added rather than editing 01..05, which stay frozen as the record of the first copy.

**How.** The same copy as QC-RV: `git -C ../LibKa0s archive v1.76.0 LibKa0s testkit`, both
payloads replaced whole, then the tag's `tools/prune-icons.lua` against the unchanged
`LibKa0s icons: all (icon browser).` line, which removed nothing. The provenance line stays
v1.76.0. `diff -r` of both payloads against the tag copy is empty.

**Files that changed** (old `9949368` -> new `e692491`):

| File | Minor | Change |
|---|---|---|
| `libs/LibKa0s/PerfPanel.lua` | `PANEL_MINOR` 7 -> 8 | step-row label anchored LEFT and RIGHT (`LABEL_GAP` short of the command), word wrap off |
| `libs/LibKa0s/SimPanel.lua` | `SIM_PANEL_MINOR` 5 (unchanged inside the unreleased tag) | Sim's private step panel gets the same bound via `anchorLabel` |

No other library file changed, and `tests/_kit/` is byte-identical to the previous copy (kit
revision 41). QuickComms does not load or wire Sim, does not open the perf step panel from its own
code, and none of its own tests or docs pins a PerfPanel or SimPanel minor, so nothing outside the
payload changed.

**Gates.** `lua tests/run.lua` (bounded): 1123 passed, 0 failed, 1 skipped (1124 total), with
`test_vendor_sync` green against `e692491`. `luacheck .`: 0 warnings / 0 errors in 137 files. No
authored `.lua` file is above 1500 lines (largest `tests/test_page_groups.lua`, 1499).
