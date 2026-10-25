# Architecture — Ka0s Quick Comms

The hub: what this addon is, in ten mandated sections, each a summary with a link to its topic doc.
The design it is being built to is
[`superpowers/specs/2026-10-11-quickcomms-v1-design.md`](superpowers/specs/2026-10-11-quickcomms-v1-design.md),
as amended by
[`superpowers/specs/2026-10-17-callouts-owned-by-groups-design.md`](superpowers/specs/2026-10-17-callouts-owned-by-groups-design.md)
(each callout owned by one group, edited in a popup; built by
[`superpowers/plans/2026-10-17-callouts-owned-by-groups.md`](superpowers/plans/2026-10-17-callouts-owned-by-groups.md))
and by
[`superpowers/specs/2026-10-18-icon-browser-design.md`](superpowers/specs/2026-10-18-icon-browser-design.md)
(the icon browser, the game icons and the tinted glyphs; built by
[`superpowers/plans/2026-10-18-icon-browser.md`](superpowers/plans/2026-10-18-icon-browser.md))
and by
[`superpowers/specs/2026-10-18-builtins-as-groups-design.md`](superpowers/specs/2026-10-18-builtins-as-groups-design.md)
(the built-in sets seeded as ordinary groups, groups nested one level, the Preview tab as a table;
built by [`superpowers/plans/2026-10-18-builtins-as-groups.md`](superpowers/plans/2026-10-18-builtins-as-groups.md))
and by
[`superpowers/specs/2026-10-18-when-drawers-design.md`](superpowers/specs/2026-10-18-when-drawers-design.md)
(the When tab as drawers, Inherit when conditions, the icon browser's search; built by
[`superpowers/plans/2026-10-18-when-drawers.md`](superpowers/plans/2026-10-18-when-drawers.md)),
and the build order is
[`superpowers/plans/2026-10-11-quickcomms-phase-0-1.md`](superpowers/plans/2026-10-11-quickcomms-phase-0-1.md),
[`superpowers/plans/2026-10-13-quickcomms-phase-2.md`](superpowers/plans/2026-10-13-quickcomms-phase-2.md),
[`superpowers/plans/2026-10-13-quickcomms-phase-3.md`](superpowers/plans/2026-10-13-quickcomms-phase-3.md),
[`superpowers/plans/2026-10-13-quickcomms-phase-4.md`](superpowers/plans/2026-10-13-quickcomms-phase-4.md)
and [`superpowers/plans/2026-10-13-quickcomms-phase-5.md`](superpowers/plans/2026-10-13-quickcomms-phase-5.md);
this page describes what exists.

## Overview

A Retail addon that puts context-aware group callouts on a Comms Pad and a Comms Dial and sends them
through secure buttons, so they work during chat lockdown in Mythic+ keys, boss pulls and PvP
matches ([`scope.md`](scope.md)). At the end of phase 5 the data layer feeds the secure send engine, the
Comms Pads and the Comms Dials, and the player edits groups (with their When, their callouts, each group owning its own, and an
optional parent group, one level deep), pads (with their Window, Header, Section titles, Buttons and Icons styling) and dials on the Groups, Comms Pad and Comms Dial
pages. The shipped built-in sets are seed data: each
profile is given them once as ordinary groups, a battleground's nodes as groups inside its set, and
Restore built-in groups brings back any the player deleted; "Preview as…" draws the surfaces in another
situation and "Why is this showing?" explains them. A dial opens on its
key in Relaxed mode: click a wedge to send. The key is WoW's own binding of the dial's `Bindings.xml`
entry (Open Comms Dial 1-4, the dial's place in the order), set in Options →
Keybindings → Ka0s Quick Comms or on the General page's Keybindings tab, account-wide unless the
player ticks Character Specific Keybindings; a Toggle Comms Pads binding, listed first, runs
`/qc toggle`'s handler.

Ace3 (AceAddon, AceDB, AceEvent, AceTimer, AceConsole, AceGUI, AceConfig, AceDBOptions),
LibSharedMedia, LibDataBroker, LibDBIcon
and LibCustomGlow-1.0 (the Icons tab's glows, resolved at call time by LibKa0s-Glow-1.0 and optional; versions and
licenses in `DEPENDENCIES.md`) are vendored under `libs/`, and so is the whole
LibKa0s v1.77.0 payload, of which fourteen majors are wired, one setup file each (`DEPENDENCIES.md`
lists the toolchain):

| Major | Setup file | Gives |
|---|---|---|
| Core | `core/CoreSetup.lua` | the `[QC]` printer, secret-safe stringifier, SafeRegister family, the skin, the close mark, the resize grip, and the class-color resolver (`NS.ResolveColor`) |
| Media | `core/MediaSetup.lua` | the icon catalog and the monospace face, and `NS.MediaFetch` (a LibSharedMedia entry by name) |
| Env | `core/EnvSetup.lua` | the addon's own TOC metadata and version |
| Pool | `core/PoolSetup.lua` | the frame pool (one array pool per pad for its buttons; per dial, one for its ring containers and one per container for its wedges) |
| Glow | `core/GlowSetup.lua` | the stateless LibCustomGlow-1.0 driver (`NS.GlowLib`): `modules/Glow.lua` starts and stops the icon and button glows through it under its two keys |
| Widgets | `core/WidgetsSetup.lua` | the drag strip (`NS.MakeDragHandle`) above each pad, and the reorder lists on the editor pages (`ReorderList`) and the icon browser's Wowhead address window (`NS.MakeCopyWindow`, the library's `CopyWindow`) |
| Bus | `core/Bus.lua` | the strict message catalog and the tracked receivers |
| Lifecycle | `core/LifecycleSetup.lua` | the stand-down latch |
| Perf | `core/PerfSetup.lua` | the performance harness |
| DebugLog | `core/DebugLogSetup.lua` | the debug console and the diagnostics report |
| Launcher | `core/LauncherSetup.lua` | the minimap button and broker plugin, one object |
| Schema | `settings/SchemaSetup.lua` | the write seam's runtime |
| Options | `settings/OptionsSetup.lua` | the settings panel, the When tab's drawers among its rows (`H.Drawer`, `OptionsDrawer.lua`, since v1.73.0) |
| Slash | `settings/Slash.lua` | the `/qc` dispatcher |

`LibKa0s-Compat-1.0` is wired for its two secret guards only (`IsSecret`, `IsSafeKey`, assigned in
`core/Compat.lua` with a library-absent body); `LibKa0s-Item-1.0` is vendored and not wired; and of the Widgets major
`DragHandle`, `ReorderList` and `CopyWindow` are used. Each
setup file holds a descriptor and a degradation stub, and `tests/test_surface_parity.lua` holds every
stub to the live surface.

On screen: the settings panel, the editor pages, the minimap button, the Comms Pad and the Comms Dial (when its key opens it).

## Module Map

Every file, its kind, its TOC position and what it does is in [`module-map.md`](module-map.md). In
short: `core/` holds the identity, eleven of the setup files, the session state, the addon object and
its lifecycle, and the migration runner; `defaults/` the default values and the shipped built-in sets
(seed data); `modules/` the modules and the diagnostics sections; `settings/` the schema, the panel
pages and the slash table and its verb bodies. `Bindings.xml` sits at the root, beside the TOC, and is
not a TOC line: the client reads it there, and the standard allows it (layout-§1, toc-file-§4
(standard v2.80.0)).

The modules come in a few kinds. Pure ones (`Tokens`, `Channels`, `Bake`, `Resolver`, `Pad_Layout`,
`Dial_Layout`, `SendEngine_Guard`) take inputs and return answers. Edges read the client or the
registry and announce a change: `Restrictions`, `Situation` and `Surfaces`, which plans every pad and
dial and owns the one rebuild request. `Library` is the one registry writer. `SendEngine` is the one
secure writer, and `Dial_Secure` holds the dial's restricted snippets as text and asks SendEngine for
every write. The render modules (`Pad_Render`, `Dial_Render`, `Dial_Slices`, `IconStyle`, `Glow`,
`Shine`) paint insecure visuals, and the frame modules (`Pad`, `Dial`, `PreviewWindow`) own the
frames and pools. `Preview` holds test mode and the two previews as session state, and the settings
files build the panel pages, the callout popup and the icon browser.

## Settings Schema

One write seam, `NS.SchemaRuntime.Set` (LibKa0s-Schema), reached by the panel, the CLI, the launcher
and the host verbs alike; the rows are `settings/Schema.lua`'s `Settings.Schema` array: the composed
Master controls rows (`enabled`, `visibility`, `scale`, `alpha` and `locked`, defaults `true`,
`always`, 1, 1 and `false`; the session rows `state.debugConsole`, `state.testMode` and
`state.previewAs`; the minimap row), then the Behavior rows (`behavior.*`, spliced in by
`settings/SchemaRows.lua`), then the member rows (`callout.*`, `group.*`, `pad.*`, `dial.*`,
`settings/SchemaMembers.lua`), each addressed through `Library.Member`. Every module reads a setting
through `NS.Setting(path)`, which answers the row's default before the database exists; the shared
reactions are `Settings.REACTIONS`, and `enabled` is `writeThrough` so `/qc enable|disable` still
lands on a load where the composers are hollow (options-ui-§1 route (a)).

The structural registry (membership and order of the callouts, groups, pads and dials, `nextId`, the
seeding records) has one writer, `modules/Library.lua`, with its schemaVersion steps in
`modules/Library_Migrate.lua`; each user callout sits in exactly one user group. The shipped sets are
seed data, given to each profile once as ordinary groups. `Library.Prepare` is the load pass after the
migrations: it seeds, normalizes, drops dangling ids and keeps the ownership rule. The rows, every
default, the member rows' addressing, the migrations and the one list of named non-setting state
(each key's owner module and every writer) are in [`schema.md`](schema.md); the panel is in
[`settings-panel.md`](settings-panel.md).

## Message Bus

`core/Bus.lua` declares the catalog once, `NS.MSG`, as `Ka0s_QuickComms_<Event>` wire names with one
named sender each. With LibKa0s-Bus present the table is the strict `Catalog` copy, so a mistyped
key raises. Receivers take their own `NS.Bus:NewTarget()`; `NS.StandDown` / `NS.StandUp` take every
tracked registration down and replay it.

| `NS.MSG` key | Wire suffix | Sender | Payload | Consumers |
|---|---|---|---|---|
| `PROFILE_CHANGED` | `ProfileChanged` | `core/QuickComms.lua` `reloadProfile` (every AceDB profile event) | none | Surfaces (`Request`, after dropping the queued `surfaces` and `positions` entries; a held drag's stop stays); the editor pages (`settings/Editors.lua`, one deferred repaint); the icon browser (closes as Cancel) |
| `SITUATION_CHANGED` | `SituationChanged` | `modules/Situation.lua`, only when the signature moves | snapshot, previous | Surfaces (`Request`); the editor pages (`settings/Editors.lua`, one deferred repaint) |
| `RESTRICTION_CHANGED` | `RestrictionChanged` | `modules/Restrictions.lua`, when the set of blocking reasons (combat included) moves | reason, canSendChat | Situation (merges lockdown and combat into the snapshot in place); Surfaces (`RefreshLocks`: padlocks, the lockdown chip, the fade); Preview (ends test mode, Preview as and the edit preview at the combat edge); the Groups page (`settings/Groups.lua` `SyncEditPreview(true)`: the edit preview back once combat ends, while the page is on screen, with no start line); Pad (ends a drag at the combat edge); SendEngine (drains the combat-end queue) |
| `LIBRARY_CHANGED` | `LibraryChanged` | `modules/Library.lua`, on every registry write, and `Library.Touch` for every member row the seam writes; inside `Library.Batch` (New group, OfferGroup, Restore built-in groups, a Parent group write and the surfaces it leaves, an icon with its color, the callout popup's Save, a page's Defaults) one per act, its kind the kinds touched joined by commas, with no id and no field | kind, id, field | Surfaces (`Request`); the editor pages (`settings/Editors.lua`, one deferred repaint); the icon browser (closes as Cancel when its opener's member is gone) |
| `ACTIVE_GROUPS_CHANGED` | `ActiveGroupsChanged` | `modules/Surfaces.lua` `ApplyAll`, when a pad's or a dial's ordered active groups change | surfaceId (a pad's or a dial's) | none (Surfaces rebuilds pads and dials itself) |
| `SURFACE_REBUILT` | `SurfaceRebuilt` | `modules/Surfaces.lua`: `true` when a rebuild is held for combat, `false` when it ran | surfaceId (a pad's or a dial's), stale | none |
| `SEND_RESULT` | `SendResult` | `modules/SendEngine.lua`: `guarded` at the press, then `sent` or `dropped` from the echo, so one press can yield two | calloutId, surfaceId, result | `modules/Pad.lua` (the flash, the sound); `modules/Dial.lua` (the wedges' flash) |
| `COMBAT_QUEUE_DRAINED` | `CombatQueueDrained` | `modules/SendEngine.lua` `Drain` | count | `modules/Surfaces.lua` (clears the stale hints) |
| `TEST_MODE_CHANGED` | `TestModeChanged` | `modules/Preview.lua` `SetTestMode`, `SetPreviewAs` and `SetEditPreview` | on (test mode, Preview as… or the edit preview) | `modules/Surfaces.lua` (`Request`, and opens dial 1); the editor pages (repaint). The preview window is not a listener: Preview calls `PreviewWindow.Sync` directly beside every send, and at the silent stand-down |

## Slash Commands

`/qc`, alias `/quickcomms`. The reserved verbs (`help config enable disable lock unlock version list
get set reset resetall profile debug diagnostics perf`; `lock` and `unlock` are slash-commands-§8's,
the Lock frame row's path through the seam) and the feature verbs `check <id>`, which prints the
line a callout would send under the current situation and never sends, `test` (test mode), `toggle` (hide or show every Comms Pad, remembered per character in `db.char.padsHidden`, also the launcher's Show window entry), `preview` ("Preview as…": bare opens the preview window on where you are, or keeps the preview on; a name switches it, `off` ends it and `list` prints the menu) and `why` ("Why is this showing?", for every built pad and dial). The full table, the live-while-disabled set
and the handlers are in [`slash-dispatch.md`](slash-dispatch.md). `enable` and `disable` call the
same handler as the Master controls row and the launcher entry.

## Event Subscriptions

Every game event is declared in `NS.FEATURE_EVENTS` and registered through `NS.SafeRegisterEvent`,
so `OnEnable` and the stand-up register exactly that list and the stand-down unregisters it. The list
holds the situation and restriction edges' rows (zone, key, group, spec and restriction events, and
the two combat edges, which `Restrictions` owns; `CHANNEL_UI_UPDATE` and `CHAT_MSG_CHANNEL_NOTICE`
refresh the snapshot's `general`, QF-04), and the send engine's ten `CHAT_MSG_*` rows (say, yell,
party and its leader, raid and its leader, raid warning, instance and its leader, and channel), whose
handler matches an echo to a press without reading the text. `CHAT_MSG_CHANNEL` fires for every
channel the player is in, so the handler drops a line whose channel index (the 8th payload field) is
readable and not 1 (`SendGuard.IsGeneralEcho`) before matching. The one registration outside
`NS.FEATURE_EVENTS` is `SendEngine`'s private `PLAYER_REGEN_ENABLED` target, which exists only while
a stand-down is held in combat and is released when it fires (slash-commands-§7).

`Restrictions` also owns `ENCOUNTER_END`: it re-reads the client at the event and once more 1 s later
(`RefreshAfterLift`, one pending re-read that the stand-down cancels), because a chat lockdown can
clear after its own event. Situation's `CHALLENGE_MODE_COMPLETED` row forwards the same lift to
`Restrictions.RefreshAfterLift` rather than registering the event twice, since AceEvent keeps one
handler per event per object. Every feature handler in `Restrictions` and `Situation` returns at once
while the addon is stood down, so a dispatch that reaches one after the stand-down arms nothing
(`tests/test_disabled.lua` fires every registered event at its handler to prove it).

The combat edge also re-arms the `{coordinates}` buttons (QF-03): on `RESTRICTION_CHANGED` into combat
(Restrictions says combat while `InCombatLockdown()` is still false, at `PLAYER_REGEN_DISABLED`),
`SendEngine.RefreshRebakes` re-bakes every button whose meta carries `rebake` once, so a press in
combat sends the position at the pull rather than the last rebuild's.

AceDB's `OnProfileChanged`, `OnProfileCopied` and `OnProfileReset` callbacks are setup and stay up
while disabled. Events the client refuses are kept in `NS.rejectedEvents` and reported by the
`[Init]` summary and the diagnostics report.

## Taint Notes

Every secure rule lives in `modules/SendEngine.lua`, the only code that makes a `Secure*` frame,
calls `SetAttribute` or registers a state driver, and `tests/test_sendengine.lua` greps every other
shipped file to keep it so. Send buttons are armed with one baked macro line, only out of combat; a
rebuild asked for in combat waits in a keyed combat-end queue; the click and `PreClick` hooks are
insecure and cannot cancel a click, so the spam guard is soft. The Comms Dial is one secure header
per dial whose restricted snippets alone act in combat, with one secure catcher per ring and a
full-screen catcher on a key open. The settings panel, the callout popup and the icon browser are
refused or locked in combat. The full notes, frame by frame: [`taint.md`](taint.md).

Every strata and frame level the addon sets is named once, in `core/Constants.lua`
`NS.Constants.LAYERS`, whose header comment records the whole stack; `tests/test_layers.lua` pins it.

## Known Limitations

The spam guard is soft and an echo can be masked; a rebuild waits for combat, so a button keeps the
line it last held; General is sent only when the client confirms channel 1 is General, else Say; a
lockdown that clears late can keep its padlock until the next event; the dial is Relaxed only and its
key belongs to its place in the dial order; a few battleground and instance names are ours or
ambiguous; and another Ka0s addon carrying a newer LibKa0s runs its newer modules inside this one.
Each, with why: [`known-limitations.md`](known-limitations.md).

## Documentation map

Every `.md` under `docs/` appears in exactly one table below. Out of scope and named once each as
directories, never row by row: `docs/audits/`, `docs/reviews/`, `docs/automated-tests/<run>/`,
`docs/perf-analysis/<run>/`, `docs/revendor/<date>-v<tag>/`, `docs/superpowers/` (the design spec and
the implementation plan) and `docs/investigations/`. This addon's own frozen store, `docs/brainstorm/`,
is registered once, as a store, in the Tier 3 table; the documents under it get no row each.

### Required (documentation-§3, Tier 1)

| Doc | Covers |
|---|---|
| `scope.md` | What the addon is for, what exists at this version, and what it deliberately does not do |
| `module-map.md` | Every non-vendored file, its responsibility, and the TOC load order |
| `schema.md` | The SavedVariables shape, every default, and the migration path |
| `settings-panel.md` | The `Page \| Covers` table and the page → tab → row tree |
| `data-flow.md` | How a setting and the stand-down flow today, and the design's callout pipeline |
| `common-tasks.md` | Recipes for the changes made most often here |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `perf-analysis/README.md` | Present | The performance harness is wired (`core/PerfSetup.lua`) |
| `slash-dispatch.md` | Present | 21 commands in `NS.COMMANDS` |
| `profiles.md` | Present | The Profiles page ships in the options UI |
| `debug.md` | Present | The diagnostics dump ships in every addon (debug-logging-§14) |
| `midnight-quirks.md` | Not applicable | The addon carries no client-version workaround of its own yet |
| `compat-layer.md` | Present | `core/Compat.lua` publishes three or more shims (the count and its grep are in the page) |
| `taint.md` | Present | The hub's Taint Notes passed ~60 lines (documentation-§3 spill) |
| `known-limitations.md` | Present | The hub's Known Limitations passed ~60 lines (documentation-§3 spill) |
| `message-bus.md` | Not applicable | 9 messages are defined, not more than ten; the table is in this page's Message Bus section |

### Verification and record (documentation-§3)

| Doc | Covers |
|---|---|
| `testing.md` | How to run the harness and lint; the green commit gate and the release gate |
| `smoke-tests.md` | The in-game smoke-test suite |
| `test-cases.md` | The generated case inventory (authoritative pass count) |
| `performance.md` | The addon performance page |
| `automated-tests/README.md` | What the automated-test record is and how to produce it |
| `automated-tests/RESULTS.md` | One row per run; generated by the runner, never hand-edited apart from the watch list's `Disposition` column (automated-tests-§4) |

### Addon-specific (documentation-§3, Tier 3)

| Doc | Covers |
|---|---|
| `brainstorm/` | The pre-scaffold record, kept as history: the research notes, the brainstorm and its decisions D1–D12, the clickable UX mockup and the in-game go/no-go test with its harness and screenshots |

## Documented deviations

The single home for a ratified deviation from the Ka0s WoW Addon Standard (documentation-§3). A
deviation not in this table is not ratified.

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `standalone-windows`, `library-stack-§8` | One wrapper, and every close control goes through it: the callout popup, and the icon browser built from the same window (`settings/ModalWindow.lua`, since 2026-10-18), close with the X of Blizzard's `SettingsFrameTemplate` (`ClosePanelButton`), not with `NS.MakeCloseButton`; its click is a Cancel. The wrapper stays in `core/CoreSetup.lua`, because the same section requires it, and the fallback window (a client without the template) still draws the shared mark through it, so `grep -rn 'MakeCloseButton(' --include='*.lua' \| grep -v '/libs/'` returns the wrapper's definition and calls to `NS.MakeCloseButton` (the fallback window in `settings/ModalWindow.lua` and `tests/test_setup.lua`), and nothing else | The popup is built from Blizzard's `SettingsFrameTemplate` to match the settings window exactly, and that template brings its own close; the browser reuses the popup's chrome; decided by the owner | 2026-10-17 | The standard ruling on Blizzard-template windows, or the popup and the browser leaving the template |
| `standalone-windows` | The window edge: the callout popup's edge and frame, and the icon browser's (the same `settings/ModalWindow.lua` window, since 2026-10-18), are Blizzard's `SettingsFrameTemplate` (its NineSlice and `Bg`), not the Ka0s window edge through `ApplySkin`; on a client without the template, the fallback window uses the `UI-DialogBox-Border` backdrop | Built from Blizzard's settings template so the popup matches the settings window exactly, as the owner asked; the browser reuses the popup's chrome (icon browser spec); decided by the owner | 2026-10-18 | The standard ruling on Blizzard-template or modal windows, or the popup and the browser leaving the template |
| `localization-§1` | The icon browser's Glyphs tab labels (`settings/IconBrowser_Sources.lua`, `Src.GlyphLabel`) are derived from the LibKa0s catalog keys and are not routed through `NS.L` | The catalog keys are data that change with the library, and enUS is the only locale; decided by the owner | 2026-10-18 | The first non-enUS locale file, or LibKa0s publishing icon labels |
| `testing` (the vendored kit owns the AceDB fake) | `tests/run.lua` wraps the kit's AceDB fake once per load to add AceDB's `char` section (`db.char`, the SavedVariables root's `char["Tester - Realm"]`, filled from the `char` defaults), and `bootAddon` takes `opts.sv` to replay a saved root as a /reload would | The kit's fake (`tests/_kit/mock_record.lua`) models only `profile` and `global`, and the Comms Pads' hidden state is genuinely per-character (`db.char.padsHidden`); `tests/_kit/` is never edited here | 2026-10-21 | A kit revision whose AceDB fake models `char` (then drop the shim and re-vendor) |
| `library-stack-§7`, anti-pattern #47 | The restriction tracker (`modules/Restrictions.lua`: the event hints, the chat lockdown and combat folded into `Snapshot` (reason, canSendChat) and `InCombat`, announced on the reason set plus a combat flag) and its four readers (`core/Compat.lua` `InChatMessagingLockdown`, `RestrictionTypes`, `IsRestrictionStateActive`, `IsRestrictionActive`) are copied from DropWatcher, not taken from LibKa0s | [LibKa0s#49](https://github.com/tusharsaxena/LibKa0s/issues/49) rejected the tracker under bar 3 (a same-author copy under ten days old whose edges already diverged: the two copies' announce edges, answer sets and combat-edge ownership differ, this one signing the full reason set plus a combat flag against DropWatcher's four answers) and deferred the readers (guards, not readers: promotion removes no host line; the first to promote, as Compat minor 2). Recorded in the standard's `standards/standards/open-evolutions.md`, *Further `LibKa0s` modules*, *Recorded rejections, LibKa0s#46–#58* | 2026-10-22 (the LibKa0s v1.75.0 run) | From the record. The tracker: at least two of these hold: a third addon, not a copy, needs a restriction answer set; the two copies converge on one announce edge and one answer set; 12.2 ships with no change to `Enum.AddOnRestrictionType`, the event payload or the chat-blocking classification. The readers: a non-copy addon needs the absent and secret answers and the three readers reconcile |
| `frame-layering-§1` (the secure fixed point), `frame-layering-§4` (windows are toplevel) | The Comms Dial's secure header is `DIALOG` (`LAYERS.STRATA.HUD_POPUP`), above the tier a HUD popup takes; the preview window, the callout popup and the icon browser sit at `FULLSCREEN` and the confirms are lifted to `FULLSCREEN_DIALOG`; the preview window is not toplevel and is never `Raise()`d; and the callout popup and the icon browser (`settings/ModalWindow.lua` `MW.Build`) are clamped to the screen but not toplevel | The header's strata is protected in combat, so it is fixed first and every insecure frame that must sit over it moves a tier up (`69719ca`, `0901b8c`): the hub front at header + 20 would win any level race in `DIALOG`. A raise would lift the preview window over a modal's catcher in the same strata. A toplevel window is raised to the top of its strata on every mouse-down, so the click on the popup's Choose icon… would lift the popup over the browser's `MODAL_OVER` band as the browser opens; each modal's full-screen catcher already makes it the only clickable frame in `FULLSCREEN`, so a raise gains nothing (`36e6cd3`). The standard's own documented exception, recorded here as it requires | 2026-10-24 (item 030; `69719ca`, `0901b8c`, 2026-10-23); widened 2026-10-25 (`36e6cd3`, the modals clamped, audit QC-21; the dial screen catcher, named here by `772b5bf`, moved to a row of its own the same day) | The dial header ceasing to be secure, or the standard ruling a strata option for the library's tool windows (STRATA_MODEL LK-05); the modals leaving the catcher-and-band model, or the client no longer raising toplevel frames on click |
| `frame-layering-§4` (no full-screen catcher behind a transient popup) | A Comms Dial opened from its key shows a hidden full-screen catcher (`SendEngine.NewDialScreen`, `LAYERS.STRATA.DIAL_SCREEN`, `HIGH`) under the dial, so any click outside it closes it, in combat too; the catcher is the only thing the click reaches (a second press is needed for a world or action-bar click, `docs/known-limitations.md`) | The dial is a secure HUD popup, not a transient popup: in combat no insecure `GLOBAL_MOUSE_DOWN` listener can close it, and the catcher is a secure frame the header's restricted snippet shows and hides. The owner ruled the catcher allowed (2026-10-25; audit QC-30) | 2026-10-25 (owner; first named by `772b5bf` in the row above) | The standard ruling on full-screen catchers behind a secure HUD popup, or the client giving secure code another way to close on an outside click |
| `library-stack-§7` | `modules/IconStyle.lua` (the Icons tab's look: `Config`, `ApplyIcon`, `IconFrame`, `PaintBorder`, `PaintRing`) and the glow lifecycle in `modules/Glow.lua` (the signature gate, the proc burst, the triggers) stay in the addon, copied from DropWatcher; only the stateless driver is taken from LibKa0s (`LibKa0s-Glow-1.0`, `core/GlowSetup.lua`) | [LibKa0s#56](https://github.com/tusharsaxena/LibKa0s/issues/56) promoted only the stateless driver and rejected IconStyle (bars 1 and 2: every consumer means something different), the lifecycle and signature layer (bars 1 to 3: disagreeing no-op policies, and it writes LibCustomGlow's private state), the published `GLOW_STYLES` / `GLOW_KNOBS` defaults and catalogs (profile-owned, and the hosts disagree) and the LibSharedMedia `"Solid"` registration (frequency alone). Recorded in the standard's `standards/standards/open-evolutions.md`, *Further `LibKa0s` modules*, *Recorded rejections, LibKa0s#46–#58* | 2026-10-22 (the LibKa0s v1.75.0 run) | From the record. IconStyle: two hosts converge on one icon look with the same semantics. The lifecycle: two hosts share one change-detection key, or LibCustomGlow publishes a supported burst suppression. The defaults and catalogs: a fourth host copies the knob table, or the ranges drift apart. `"Solid"`: an addon registers `"Solid"` with a different texture |
| `options-ui-§17` (no `disabledIf` on a color row), anti-pattern #74 | Eleven color pairs gray out while their feature's own switch is off: the Shine tint and both bloom pairs on Buttons and Slices, Pointer color, Dot border color, Indicator background, and the font color inside the Slice labels and Group labels font blocks (`settings/SchemaMembers.lua`) | A color that cannot be seen while its feature is off reads as broken when it stays live; graying it on the feature's own switch is the owner's choice, and the proposal to permit exactly that is open upstream as [WowAddonStandards#13](https://github.com/tusharsaxena/WowAddonStandards/issues/13). Issue [#11](https://github.com/tusharsaxena/QuickComms/issues/11) (drop the gray-outs) is declined pending it. Decided by the owner | 2026-10-25 (audit QC-18) | WowAddonStandards#13 ruled: if it permits the gate, drop this row; if it refuses, take `disabledIf` off the color rows |

### Files over the 1500-line cap

The layout-§1 census of authored `.lua` files over the 1500-line cap. Vendored code (`libs/`,
`tests/_kit/`) is out of scope; the tools under `tools/` (the Python generators and the shine preview's
`render-shine-preview.lua`) are authored and under the cap, and
the repository has no generated data file.

Nothing is over the cap today. `tests/test_page_groups.lua` reached it exactly and was split along its
own section headings (`80a0fbb`, 2026-10-25): 1131 lines now, beside `tests/test_page_groups_nesting.lua`
at 418. Seven files sit in the 1000-1500 band (`tests/test_dial.lua` 1472, `locales/enUS.lua` 1348,
`modules/Library.lua` 1340, `tests/test_page_groups.lua` 1131, `tests/test_library.lua` 1057,
`tests/test_pad.lua` 1030, `tests/wow_mock.lua` 1024); the automated-test record's watch list gives
each its disposition.
