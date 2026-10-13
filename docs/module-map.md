# Module map — Ka0s Quick Comms

Every non-vendored file, its responsibility, and the TOC load order. `libs/` (Ace3, LibSharedMedia,
LibDataBroker, LibDBIcon, LibKa0s v1.71.0 whole) and `tests/_kit/` are vendored and never edited.

## Load order (the TOC)

| # | File | Kind | Responsibility |
|---|---|---|---|
| 1 | `locales/enUS.lua` | data | `NS.L`, the metatable fallback; the key is the English string |
| 2 | `core/Namespace.lua` | data | name, version, brand, the cyan `[QC]` tag, the slash and its alias |
| 3 | `core/CoreSetup.lua` | setup | LibKa0s-Core: the printer, the secret-safe stringifier, the SafeRegister family, the skin, the close-button wrapper, the resize grip |
| 3a | `core/Compat.lua` | compat | `NS.Compat`: the only caller of version-variant or optional client APIs, and the secret guards ([`compat-layer.md`](compat-layer.md)) |
| 4 | `core/MediaSetup.lua` | setup | LibKa0s-Media: `NS.Icon`, `NS.MediaFont`, the one RegisterLSM call |
| 5 | `core/Constants.lua` | data | `FONT_MONO`, the Ka0s gold |
| 6 | `core/State.lua` | state | session-only state (`NS.State`): the debug flag; the modules add their own fields (test mode, plans, the queue, the echo, the pad's tab and collapse) |
| 7 | `core/EnvSetup.lua` | setup | LibKa0s-Env: `NS.Meta`, `NS.Version` |
| 8 | `core/PoolSetup.lua` | setup | LibKa0s-Pool: `NS.Pool` (one array pool per pad for its chips) |
| 8a | `core/WidgetsSetup.lua` | setup | LibKa0s-Widgets: the drag-strip seam, `NS.MakeDragHandle` |
| 9 | `core/Bus.lua` | setup | LibKa0s-Bus: `NS.MSG` (the strict catalog) and `NS.Bus` (tracked receivers) |
| 10 | `core/LifecycleSetup.lua` | setup | LibKa0s-Lifecycle: the stand-down latch, `NS.IsStoodDown` |
| 11 | `core/PerfSetup.lua` | setup | LibKa0s-Perf: `NS.Perf`, the declared buckets |
| 12 | `core/DebugLogSetup.lua` | setup | LibKa0s-DebugLog: the console, `NS.Debug` and its gates, the diagnostics descriptor |
| 13 | `core/QuickComms.lua` | lifecycle | AceAddon registration (`NS.addon`), `NS.FEATURE_EVENTS`, `NS.STAND_DOWN` / `NS.STAND_UP`, `NS.StandDown` / `NS.StandUp`, the profile callbacks |
| 14 | `core/Database.lua` | data | `NS.MIGRATIONS`, `NS.SCHEMA_VERSION` and the schemaVersion migration runner |
| 15 | `core/LauncherSetup.lua` | setup | LibKa0s-Launcher: the one LDB object, registered twice |
| 16 | `defaults/Profile.lua` | data | every default value (`NS.C`) |
| 16a | `defaults/BuiltIns.lua` | data | `NS.BuiltIns`: the registry of shipped sets and the declaring helpers |
| 16b | `defaults/BuiltIns_MythicPlus.lua`, `_Raid.lua`, `_Arena.lua`, `_Battlegrounds.lua` | data | the four shipped sets (spec §12) |
| 16b2 | `defaults/GameIds.lua` | data | the shipped ids: dungeons, raids, classes, specializations |
| 16c | `modules/Restrictions.lua` | edge | what the client's addon restrictions allow; `RESTRICTION_CHANGED` |
| 16d | `modules/Situation.lua` | classifier + edge | the situation snapshot; `SITUATION_CHANGED` |
| 16e | `modules/Tokens.lua` | pure | token expansion |
| 16f | `modules/Channels.lua` | pure | channel kinds, resolution, lock state |
| 16g | `modules/Bake.lua` | pure | callout + snapshot to one macro line |
| 16h | `modules/Resolver.lua` | pure | When rules to active groups |
| 16i | `modules/Library.lua` | registry writer | the one writer of the structural registry; `Prepare`; `SetSurfacePoint` |
| 16j | `modules/SendEngine_Guard.lua` | pure | `NS.SendGuard`: the soft guard's timing, the acting click edge, the echo tracker, the keyed queue |
| 16k | `modules/SendEngine.lua` | secure writer | the only secure writer: send buttons, arm and disarm, the combat-end queue, the click hook, the echo events, the held stand-down |
| 16l | `modules/Preview.lua` | session state | test mode and "Preview as…": refused in combat, ended at the combat edge; `TEST_MODE_CHANGED` |
| 16m | `modules/Pad_Layout.lua` | pure | `NS.PadLayout`: pad geometry (upward growth stacks whole sections), visibility, fade |
| 16n | `modules/Surfaces.lua` | edge | the pads' plans and the one rebuild request, queued in combat with the stale hint |
| 16o | `modules/Pad_Render.lua` | render | `NS.PadRender`: insecure chip and header visuals |
| 16p | `modules/Pad.lua` | frames | the pad's frames: pooled secure chips, header, drag strip and lock, position via `Library`, tabs, collapse, feedback |
| 17 | `modules/Diagnostics.lua` | sections | the addon's sections of `/qc diagnostics` (identity, settings, registration, integrations, situation, restrictions, library, surfaces, send) |
| 18 | `settings/SchemaSetup.lua` | setup | LibKa0s-Schema, or the host's documented stub of it |
| 19 | `settings/Schema.lua` | settings | the rows, the write seam (`NS.SchemaRuntime`), `NS.Setting`, the shared reactions, the defaults tree, the global reset |
| 20 | `settings/OptionsSetup.lua` | setup | LibKa0s-Options: the panel descriptor |
| 20a | `settings/SchemaRows.lua` | settings | the hand-written Behavior rows, spliced after the Master controls |
| 20b | `settings/SchemaMembers.lua` | settings | the member rows (`callout.*`, `group.*`, `pad.*`, `builtin.*`), addressed through `Library.Member` |
| 21 | `settings/Panel.lua` | settings | the landing page and the General page (Master controls) |
| 21a | `settings/Editors.lua` | settings | the editor pages' shared frame: selection, repaint, reorder lists, delete |
| 21b | `settings/Callouts.lua` | settings | the Callouts page |
| 21c | `settings/Groups_When.lua` | settings | the Groups page's When editor |
| 21d | `settings/Groups.lua` | settings | the Groups page |
| 21e | `settings/Pads.lua` | settings | the Comms Pad page |
| 21f | `settings/Share.lua` | settings | the Share page (the Built-in tab) |
| 21g | `settings/SlashVerbs.lua` | verbs | `NS.SlashVerbs`: the verb bodies (`check`, `SetLocked` for `lock` / `unlock`, `preview`, `why`) |
| 22 | `settings/Slash.lua` | setup | `NS.COMMANDS` and the LibKa0s-Slash descriptor |
| 23 | `settings/Profiles.lua` | settings | the Profiles page (AceDBOptions) |

Why each position is load-bearing or conventional is written on the comment line above its entry in
`QuickComms.toc` (toc-file-§5); a TOC line carries the file path alone. The planned modules and the
files they add are listed in design spec §4.2.

## Tests

| File | What it is |
|---|---|
| `tests/run.lua` | the three factories, the kit facts and the suite list |
| `tests/loader.lua` | the instance factory: TOC files plus `LibKa0s.xml`'s files, isolated per case |
| `tests/wow_mock.lua` | the thin extender over `tests/_kit/mock_base.lua` |
| `tests/prose_waivers.lua` | the per-file, per-word British-spelling waivers for `docs/brainstorm/` |
| `tests/test_*.lua` | one suite per subject (phase 1 added `test_compat`, `test_restrictions`, `test_situation`, `test_tokens`, `test_channels`, `test_bake`, `test_resolver`, `test_builtins`, `test_library`, `test_check`) (see [`testing.md`](testing.md)) |
| `tests/test_mock_secure.lua` | the mock's secure half: protected calls refused in combat are recorded, a click acts on one edge, a visibility driver follows combat |
| `tests/test_send_guard.lua` | `SendEngine_Guard`: the guard's timing, the acting edge, the echo tracker, the keyed queue (pure) |
| `tests/test_sendengine.lua` | `SendEngine`: buttons, arm and disarm, the queue, the held stand-down, and the firewall grep (no secure call or `SendChatMessage` elsewhere) |
| `tests/test_preview.lua` | test mode: session-only, refused in combat, ended at the combat edge, ended by the stand-down |
| `tests/test_master.lua` | the lock and test mode through one handler from the row, the verb and the launcher entry |
| `tests/test_pad_layout.lua` | `Pad_Layout`: geometry, the sections per groups-as mode, the visibility expression, the fade |
| `tests/test_surfaces.lua` | `Surfaces`: a pad's plan, and the rebuild queued in combat with the stale hint |
| `tests/test_pad_render.lua` | `Pad_Render`: what a chip and the header show, and the drag-strip seam |
| `tests/test_pad.lua` | `Pad`: armed or disarmed chips, the visibility driver, the drag strip shown while unlocked (it will not drag while locked or in combat) |
| `tests/test_members.lua` | the member rows: addressed by instance, selection or the first listed member; built-ins refused; `Library.Touch` announces each write; the CLI text forms |
| `tests/test_editors.lua` | `settings/Editors.lua`: the selection heals and a profile switch clears it, one structural repaint per frame, none for a scalar write, the delete confirmation, the jump |
| `tests/test_page_callouts.lua` | the Callouts page: picker and New callout, the General rows, token insert, the live line, the acts, Used by |
| `tests/test_groups_when.lua` | the When editor's pure half (toggle, clear, key-level range, the values offered, the active-now line) and its write through the seam |
| `tests/test_page_groups.lua` | the Groups page: picker and New group, a user group's tabs, a built-in's read-only General with Customize and its hidden-callouts editor |
| `tests/test_page_pads.lua` | the Comms Pad page: picker and New pad, General's acts, the Groups priority list, Layout with X/Y, Look |
| `tests/test_page_share.lua` | the Share page's Built-in tab: Enabled, Customize, Choose callouts per set, and Defaults |
| `tests/page_helpers.lua` | a helper, not a suite: drives an editor page through the kit's AceGUI recorder |
| `tests/perf.lua` | the offline scenarios, outside the gate |
