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
| `preview [name\|off]` | feature | no (refused while disabled) | `NS.SlashVerbs.Preview`: no name lists the menu with the one on now; a name switches "Preview as…" on; `off` (or `current`) switches it off. Refused in combat with one line, as the panel row is. |
| `why` | feature | no (refused while disabled) | `NS.SlashVerbs.Why`: each built pad, then each built dial, then `Surfaces.WhyLines` (the groups shown, each with the When rows that matched, then the locks) |

`/qc set dial.key shift-g` (or `none`) binds or frees a dial's key on the CLI; `/qc set dial.point x y` moves it.

The member rows are CLI rows too. A callout's rows name the callout by its id after the path: `/qc set callout.text <id> <value>`, `/qc get callout.name <id>`, `/qc reset callout.icon <id>` (no page selects a callout: each belongs to a group and is edited in its popup). A write or a reset that names no id is refused with a line naming that form, one that names a gone id says so, and `list` prints `(nothing to edit)` for the callout rows. The other kinds' rows write the member their page has selected, else the first that page lists; with none of that kind the write is refused with a line naming the page. A built-in set's rows (`builtin.*`) address only the set the Groups page has selected. The three table-valued rows have text forms (the descriptor's `parse` and `format`, slash-commands-§6): `pad.point` takes `x y` or `POINT RELATIVEPOINT x y`; `group.when` takes `<condition> <value>[,<value>…]`, several separated by `;` (the condition alone clears it; `keyLevel` takes `min-max`, either end empty; `always` clears every condition) and prints the same syntax, `content mythicPlus,raid; keyLevel 10-`, so a printed When types back in. A value is matched to its condition's token without regard to case (`role tank` stores `TANK`), an instance or battleground by its id or listed name, and a value the condition can never match is refused with what it takes; `builtin.hidden` takes callout ids or `none`. `/qc reset pad.point` puts a pad back in its default place and `/qc reset callout.icon <id>` (or `group.icon`) clears an icon; a page's Defaults keeps both. An offset larger than the screen is refused.

While disabled, a verb that is not live prints the one refusal line, `Ka0s Quick Comms is disabled —
enable it with /qc enable`, and does nothing else. The gate reads the stored `enabled`, not the
latch, so a perf capture never refuses a verb.

Every verb of spec §14 now exists. The verb bodies live in
`settings/SlashVerbs.lua`; the rows in `settings/Slash.lua` only call them.

With the library absent, the stub in `settings/Slash.lua` dispatches the same table, keeps the
same live list, and the schema CLI verbs say the library is missing.
