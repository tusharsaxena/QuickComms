# 04 — Execution plan

The re-vendor commit `AF-RV-QC` carries:

- both payloads copied whole from the v1.107.0 extract, then the tag's `tools/prune-icons.lua` (every icon kept under `all`, 362 voice-pack files removed);
- `CLAUDE.md`'s provenance line rolled to v1.107.0, the `LibKa0s icons:` line kept;
- the standard reference refreshed to v2.115.0 (the vendored quirks block in `docs/midnight-quirks.md`, replaced whole; it was stamped v2.103.1);
- this bundle and the v1.106.0 span bundle.

Then, as their own commits: AF-STRIP-QC (the strip's `onClose` and `closeTooltip`) and AF-HDR-QC (the pad header's lock, settings and close).

Gate: `lua tests/run.lua` and `KA0S_KIT_CLIENT=forever lua tests/run.lua` through `ka0s-bounded` (0 failed), `ka0s-bounded luacheck .` 0/0, every Lua file at 1500 lines or fewer.
