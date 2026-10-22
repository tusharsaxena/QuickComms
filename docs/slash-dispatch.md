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
| `toggle` | feature | no (refused while disabled; a perf capture alone: the capture line) | `NS.SlashVerbs.TogglePads`: flips this character's `db.char.padsHidden` (saved per character, so a /reload or the next login restores it, and a profile switch leaves it alone) and rebuilds through `Surfaces.Request`, so in combat it waits for combat to end. The pads' visibility driver then says `hide`; test mode still shows them; dials are not affected. It prints nothing to chat (2026-10-21, owner): the pads going or coming back is the answer, and the debug log's `Pads` tag records it. The launcher's Show window entry and the Toggle Comms Pads key binding (Bindings.xml) call the same handler (launcher-§2) |
| `version` | reserved | yes | the library |
| `list` / `get` / `set` / `reset` / `resetall` | reserved | yes | the library over the schema seam; `reset` takes a path, `resetall` asks first |
| `profile` | reserved | yes (added to the live list) | the library's profile verb |
| `debug` | reserved | yes | `DebugVerb` (diagnostics first, then on/off), else the console toggle |
| `diagnostics` | reserved | yes | `NS.DebugLog:RunDiagnostics` |
| `perf` | reserved | yes | `NS.Perf.OnCommand`, lines printed by the addon |
| `check <id>` | feature | no (refused while disabled) | `NS.SlashVerbs.Check` in `settings/SlashVerbs.lua`: prints the callout's baked line under the current situation (`id -> /p text`), then its channel and the whole line's byte count (prefix included, live tokens at a nominal 12), then any lock, then the tokens it leaves out: the baked ones (`{me}`, `{spec}`, ...) as "baked at send time", since check passes no send-time values, and any unknown ones. A refusal prints its reason (`startsWithSlash`, `tooLong`, ...); a smart channel while solo with the `self` fallback says it would print locally; an unknown id says so. It never sends (spec §14, D12). |
| `test` | feature | no (refused while disabled; a perf capture alone: the capture line) | `NS.Preview.ToggleTestMode`; refused in combat with one line; the Test mode row and the launcher entry call the same switch |
| `preview [name\|off]` | feature | no (refused while disabled; a perf capture alone: the capture line) | `NS.SlashVerbs.Preview`: no name lists the menu with the one on now; a name switches "Preview as…" on; `off` (or `current`) switches it off. Refused in combat with one line, as the panel row is. |
| `why` | feature | no (refused while disabled) | `NS.SlashVerbs.Why`: each built pad, then each built dial, then `Surfaces.WhyLines` (the groups shown, each with the When rows that matched, then the locks) |

`/qc set dial.point x y` moves a dial. A dial's key has no CLI row (2026-10-20): it is WoW's own binding of the dial's Open Comms Dial entry, set only in Options → Keybindings → Ka0s Quick Comms (the Dial page's Binding tab retired in the dial rework, 2026-10-21). The Toggle Comms Pads binding there runs `/qc toggle`'s handler (`SlashVerbs.TogglePads`) through a CLICK on the plain, hidden `QuickCommsTogglePads` button.

The member rows are CLI rows too. A callout's rows name the callout by its id after the path: `/qc set callout.text <id> <value>`, `/qc get callout.name <id>`, `/qc reset callout.icon <id>` (no page selects a callout: each belongs to a group and is edited in its popup). A write or a reset that names no id is refused with a line naming that form, one that names a gone id says so, and `list` prints `(nothing to edit)` for the callout rows. The other kinds' rows write the member their page has selected, else the first that page lists; with none of that kind the write is refused with a line naming the page. The structured rows have text forms (the descriptor's `parse` and `format`, slash-commands-§6): `pad.point` (and `dial.point`) takes `x y` or `POINT RELATIVEPOINT x y`; `group.when` takes `<condition> <value>[,<value>…]`, several separated by `;` (the condition alone clears it; `keyLevel` takes `min-max`, either end empty; `always` clears every condition) and prints the same syntax, `content mythicPlus,raid; keyLevel 10-`, so a printed When types back in. A value is matched to its condition's token without regard to case (`role tank` stores `TANK`), an instance or battleground by its id or listed name, and a value the condition can never match is refused with what it takes. `group.parent` takes a group id (a top-level group other than the selected one), or `none` or nothing for none; a parent is refused for a group that holds groups. `/qc reset pad.point` puts a pad back in its default place and `/qc reset callout.icon <id>` (or `group.icon`) clears an icon; a page's Defaults keeps both. An offset larger than the screen is refused.

While disabled, a verb that is not live prints the one refusal line, `Ka0s Quick Comms is disabled —
enable it with /qc enable`, and does nothing else. The gate reads the stored `enabled`, not the
latch, so a perf capture never refuses at the dispatcher. The feature verbs that would act on a
stood-down addon (`toggle`, `test`, `preview`, and the Toggle Comms Pads key and the launcher's Show
window and Test mode entries through the same handlers) refuse by hold through
`NS.StoodDownRefusal` (`core/LifecycleSetup.lua`): under the perf hold alone they answer `Not
available during a performance capture.`, since `/qc enable` would do nothing; with the `disabled`
hold taken they print the disabled line above (slash-commands-§7, launcher-§6).

Every verb of spec §14 now exists. The verb bodies live in
`settings/SlashVerbs.lua`; the rows in `settings/Slash.lua` only call them.

With the library absent, the stub in `settings/Slash.lua` dispatches the same table, keeps the
same live list, and the schema CLI verbs say the library is missing.
