# 04 Execution plan

Nothing was adopted, so there is no adoption plan in this bundle. The re-vendor commit carries only what the copy
forces:

1. Both payloads copied whole from the v1.105.0 extract, the provenance line rolled (CLAUDE.md:45), the
   declaration kept (CLAUDE.md:46), and the tag's `tools/prune-icons.lua` run (sounds: 362 removed; icons: all kept).
2. `core/DebugLogSetup.lua`: the library-absent stub gains `Report` (streams the body to chat, no pointer line)
   and `Serialize` (one line, never walks a table).
3. `settings/OptionsSetup.lua`: the library-absent Options stub gains `SideTabs` (draws nothing).
4. Docs: `docs/ARCHITECTURE.md:51` and `docs/known-limitations.md:295,297` name v1.105.0.
5. Gate under both kit profiles and luacheck, then one commit, `RV-QC: ...`.
