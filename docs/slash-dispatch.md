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
| `lock` / `unlock` | reserved (slash-commands-§8) | no (refused while disabled) | `NS.SlashVerbs.SetLocked`, writing `locked` through the seam; the Lock frame row and the launcher's Locked entry write the same path |
| `version` | reserved | yes | the library |
| `list` / `get` / `set` / `reset` / `resetall` | reserved | yes | the library over the schema seam; `reset` takes a path, `resetall` asks first |
| `profile` | reserved | yes (added to the live list) | the library's profile verb |
| `debug` | reserved | yes | `DebugVerb` (diagnostics first, then on/off), else the console toggle |
| `diagnostics` | reserved | yes | `NS.DebugLog:RunDiagnostics` |
| `perf` | reserved | yes | `NS.Perf.OnCommand`, lines printed by the addon |
| `check <id>` | feature | no (refused while disabled) | `NS.SlashVerbs.Check` in `settings/SlashVerbs.lua`: prints the callout's baked line under the current situation (`id -> /p text`), then its channel and the whole line's byte count (prefix included, live tokens at a nominal 12), then any lock, then the tokens it leaves out: the baked ones (`{me}`, `{spec}`, ...) as "baked at send time", since check passes no send-time values, and any unknown ones. A refusal prints its reason (`startsWithSlash`, `tooLong`, ...); a smart channel while solo with the `self` fallback says it would print locally; an unknown id says so. It never sends (spec §14, D12). |
| `test` | feature | no (refused while disabled) | `NS.Preview.ToggleTestMode`; refused in combat with one line; the Test mode row and the launcher entry call the same switch |

While disabled, a verb that is not live prints the one refusal line, `Ka0s Quick Comms is disabled —
enable it with /qc enable`, and does nothing else. The gate reads the stored `enabled`, not the
latch, so a perf capture never refuses a verb.

The design's other verbs (spec §14), `preview` and `why`, are added with the tasks that own them. The verb bodies live in
`settings/SlashVerbs.lua`; the rows in `settings/Slash.lua` only call them.

With the library absent, the stub in `settings/Slash.lua` dispatches the same table, keeps the
same live list, and the schema CLI verbs say the library is missing.
