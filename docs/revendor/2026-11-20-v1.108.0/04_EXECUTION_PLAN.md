# 04 — Execution plan

The re-vendor commit `SD-RV-QC` carries:

- both payloads copied whole from the v1.108.0 extract, then the tag's `tools/prune-icons.lua` (every icon kept under `all`, 362 voice-pack files removed);
- `CLAUDE.md`'s provenance line rolled to v1.108.0, the `LibKa0s icons:` line kept;
- the 3g blockers' fixes: `colorFromSkin = false` on the Shine swatches (`settings/SchemaMembers.lua`) and the kit revision 58 `Kit.skinValues` rows (`tests/run.lua`);
- the standard reference refreshed to v2.116.0 (the vendored quirks block in `docs/midnight-quirks.md`, its body unchanged since v2.115.0, restamped);
- this bundle.

Then, as its own commits: SD-SK-QC (SD-SK-QC.1, SD-SK-QC.2, U-28, the pad window's `skinBands`, R-2 and the guard declarations).

Gate: `lua tests/run.lua` and `KA0S_KIT_CLIENT=forever lua tests/run.lua` through `ka0s-bounded` (0 failed), `ka0s-bounded luacheck .` 0/0, every Lua file at 1500 lines or fewer.
