# Slash dispatch — Ka0s Quick Comms

`/qc` (alias `/quickcomms`), registered through AceConsole in `OnInitialize`. The dispatcher is
LibKa0s-Slash's; `NS.COMMANDS` in `settings/Slash.lua` is passed in as ordered positional triples
`{ name, desc, fn }`, where `fn(rest)` receives the text after the verb. The bare command opens the
settings panel.

| Verb | Kind | Live while disabled | Handler |
|---|---|---|---|
| `help` | reserved | yes | the library's index |
| `config` | reserved | yes | `QC:OpenSettings` |
| `enable` / `disable` | reserved | yes | `runEnabled`, writing `enabled` through the seam |
| `version` | reserved | yes | the library |
| `list` / `get` / `set` / `reset` / `resetall` | reserved | yes | the library over the schema seam; `reset` takes a path, `resetall` asks first |
| `profile` | reserved | yes (added to the live list) | the library's profile verb |
| `debug` | reserved | yes | `DebugVerb` (diagnostics first, then on/off), else the console toggle |
| `diagnostics` | reserved | yes | `NS.DebugLog:RunDiagnostics` |
| `perf` | reserved | yes | `NS.Perf.OnCommand`, lines printed by the addon |

While disabled, a verb that is not live prints the one refusal line, `Ka0s Quick Comms is disabled —
enable it with /qc enable`, and does nothing else. The gate reads the stored `enabled`, not the
latch, so a perf capture never refuses a verb.

The design's other verbs (spec §14) are added with the tasks that own them: `lock` and `unlock`
(reserved once a surface can be locked), `test`, `preview`, `check` and `why`.

With the library absent, the stub in `settings/Slash.lua` dispatches the same table, keeps the
same live list, and the schema CLI verbs say the library is missing.
