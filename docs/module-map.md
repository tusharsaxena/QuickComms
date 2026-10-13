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
| 6 | `core/State.lua` | state | session-only state: the debug flag |
| 7 | `core/EnvSetup.lua` | setup | LibKa0s-Env: `NS.Meta`, `NS.Version` |
| 8 | `core/PoolSetup.lua` | setup | LibKa0s-Pool: `NS.Pool` (for the surfaces, from the surface tasks) |
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
| 16c | `modules/Restrictions.lua` | edge | what the client's addon restrictions allow; `RESTRICTION_CHANGED` |
| 16d | `modules/Situation.lua` | classifier + edge | the situation snapshot; `SITUATION_CHANGED` |
| 16e | `modules/Tokens.lua` | pure | token expansion |
| 16f | `modules/Channels.lua` | pure | channel kinds, resolution, lock state |
| 16g | `modules/Bake.lua` | pure | callout + snapshot to one macro line |
| 16h | `modules/Resolver.lua` | pure | When rules to active groups |
| 16i | `modules/Library.lua` | registry writer | the one writer of the structural registry; `Prepare` |
| 17 | `modules/Diagnostics.lua` | sections | the addon's sections of `/qc diagnostics` (identity, settings, registration, integrations, situation, library) |
| 18 | `settings/SchemaSetup.lua` | setup | LibKa0s-Schema, or the host's documented stub of it |
| 19 | `settings/Schema.lua` | settings | the rows, the write seam (`NS.SchemaRuntime`), `NS.Setting`, the shared reactions, the defaults tree, the global reset |
| 20 | `settings/OptionsSetup.lua` | setup | LibKa0s-Options: the panel descriptor |
| 21 | `settings/Panel.lua` | settings | the landing page and the General page (Master controls) |
| 21a | `settings/SlashVerbs.lua` | verbs | `NS.SlashVerbs`: the bodies of the feature verbs (`check`) |
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
| `tests/perf.lua` | the offline scenarios, outside the gate |
