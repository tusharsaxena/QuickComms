# Architecture — Ka0s Quick Comms

The hub: what this addon is, in ten mandated sections, each a summary with a link to its topic doc.
The design it is being built to is
[`superpowers/specs/2026-10-11-quickcomms-v1-design.md`](superpowers/specs/2026-10-11-quickcomms-v1-design.md),
as amended by
[`superpowers/specs/2026-10-17-callouts-owned-by-groups-design.md`](superpowers/specs/2026-10-17-callouts-owned-by-groups-design.md)
(each callout owned by one group, edited in a popup; built by
[`superpowers/plans/2026-10-17-callouts-owned-by-groups.md`](superpowers/plans/2026-10-17-callouts-owned-by-groups.md)),
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
Comms Pads and the Comms Dials, and the player edits groups (with their When and their callouts, each group owning its own), pads (with
their Look), dials and the built-in sets on the Groups, Comms Pad, Comms Dial and Share
pages, and shares any of them as a `!QC1!` string; "Preview as…" draws the surfaces in another
situation and "Why is this showing?" explains them. A dial opens on its
key (or on WoW's key bindings menu, through `Bindings.xml`) in Relaxed mode: click a wedge to send.

Ace3 (AceAddon, AceDB, AceEvent, AceTimer, AceConsole, AceGUI, AceConfig, AceDBOptions),
LibSharedMedia, LibDataBroker, LibDBIcon, LibDeflate and LibSerialize (the share string, spec §15;
versions and licenses in `DEPENDENCIES.md`) are vendored under `libs/`, and so is the whole
LibKa0s v1.71.0 payload, of which thirteen majors are wired, one setup file each (`DEPENDENCIES.md`
lists the toolchain):

| Major | Setup file | Gives |
|---|---|---|
| Core | `core/CoreSetup.lua` | the `[QC]` printer, secret-safe stringifier, SafeRegister family, the skin, the close mark, the resize grip, and the class-color resolver (`NS.ResolveColor`) |
| Media | `core/MediaSetup.lua` | the icon catalog and the monospace face, and `NS.MediaFetch` (a LibSharedMedia entry by name) |
| Env | `core/EnvSetup.lua` | the addon's own TOC metadata and version |
| Pool | `core/PoolSetup.lua` | the frame pool (one array pool per pad for its chips; per dial, one for its ring containers and one per container for its wedges) |
| Widgets | `core/WidgetsSetup.lua` | the drag strip (`NS.MakeDragHandle`) above each pad, and the reorder lists on the editor pages (`ReorderList`), and the Share page's export window (`NS.MakeCopyWindow`, the library's `CopyWindow`) |
| Bus | `core/Bus.lua` | the strict message catalog and the tracked receivers |
| Lifecycle | `core/LifecycleSetup.lua` | the stand-down latch |
| Perf | `core/PerfSetup.lua` | the performance harness |
| DebugLog | `core/DebugLogSetup.lua` | the debug console and the diagnostics report |
| Launcher | `core/LauncherSetup.lua` | the minimap button and broker plugin, one object |
| Schema | `settings/SchemaSetup.lua` | the write seam's runtime |
| Options | `settings/OptionsSetup.lua` | the settings panel |
| Slash | `settings/Slash.lua` | the `/qc` dispatcher |

`LibKa0s-Compat-1.0` is wired for its two secret guards only (`IsSecret`, `IsSafeKey`, assigned in
`core/Compat.lua` with a library-absent body); `LibKa0s-Item-1.0` is vendored and not wired; and of the Widgets major
`DragHandle`, `ReorderList` and `CopyWindow` are used. Each
setup file holds a descriptor and a degradation stub, and `tests/test_surface_parity.lua` holds every
stub to the live surface.

On screen: the settings panel, the editor pages, the minimap button, the Comms Pad and the Comms Dial (when its key opens it).

## Module Map

Every file, its kind and its TOC position is in [`module-map.md`](module-map.md). In short: `core/`
holds the identity, ten of the setup files, the session state, the addon object and its lifecycle,
and the migration runner; `defaults/` the default values and the shipped built-in sets; `modules/`
the modules below plus the diagnostics sections; `settings/` the schema, the panel pages and
the slash table and its verb bodies. `Bindings.xml` sits at the root, beside the TOC, and is not a TOC
line: the client reads it there, and the standard allows it (layout-§1, toc-file-§4 (standard v2.80.0)).

| Module | Kind | Does |
|---|---|---|
| `Restrictions` | edge | what Blizzard's addon restrictions allow now (chat, combat, encounter, key, PvP match); owns `PLAYER_REGEN_DISABLED` / `ENABLED`; sends `RESTRICTION_CHANGED` |
| `Situation` | classifier + edge | `Classify(inputs)` is pure; the edge reads the client through `core/Compat.lua`, coalesces bursts 0.1 s and sends `SITUATION_CHANGED`; `Current()` is the snapshot |
| `Tokens` | pure | `{rt1}`-style marks and the live `%t` / `%f` tokens; `Expand` |
| `Channels` | pure | the eight kinds (`smartGroup`, `smartLead`, `party`, `raid`, `instance`, `raidWarning`, `say`, `yell`); `Resolve`, `Prefix`, `LockState` |
| `Bake` | pure | callout + snapshot to one macro line or a named refusal; sanitizes the text and baked token values, counts typed `%t` / `%f` as live |
| `Resolver` | pure | When rules to the active group set, surface order, the "why" lines |
| `Library` | registry writer | membership, order, ids, references and seeding of the profile's callouts, groups, pads, dials and overlay; member fields go through the seam (member rows); `Prepare`; `Batch` (one act, one announce); and `Import`, the one writer of what a share string brings; sends `LIBRARY_CHANGED` |
| `Share` | pure + edge | `modules/Share.lua`: pure codec and checks (the `!QC1!` string, the version gate, the schema checks, the sanitizer over every text field, the report), and the edge: Collect, Export (the copy window), Apply (through `Library.Import`); both acts refused in combat |
| `BuiltIns` | data | `defaults/BuiltIns*.lua`: the shipped sets, as data, never copied into the profile |
| `core/WidgetsSetup.lua` | setup | the drag-strip seam: `NS.MakeDragHandle` over LibKa0s-Widgets' `DragHandle`, nil when the library is absent |
| `modules/SendEngine_Guard.lua` | pure | the soft guard's timing, the acting click edge, the echo tracker and the keyed combat-end queue |
| `modules/SendEngine.lua` | secure writer | the only secure writer: send buttons, arm and disarm, the combat-end queue, the click hook, the echo events, the held stand-down; and the dial headers and rings, the wedge wrap, frame refs, snippet runs and the override bindings; sends `SEND_RESULT` and `COMBAT_QUEUE_DRAINED` |
| `modules/Preview.lua` | session state | test mode and "Preview as…" (its second flavor: the menu, the synthetic snapshot): refused in combat, ended at the combat edge; sends `TEST_MODE_CHANGED` |
| `modules/Pad_Layout.lua` | pure | pad geometry (upward growth stacks whole sections), the sections each groups-as mode draws, the visibility expression, the fade |
| `modules/Surfaces.lua` | edge | each pad's plan (active groups, sections, baked or refused slots), each dial's plan and rebuild beside the pads, and the one rebuild request, queued in combat with the stale hint; sends `ACTIVE_GROUPS_CHANGED` and `SURFACE_REBUILT` |
| `modules/Pad_Render.lua` | render | insecure chip and header visuals: icon, label, channel tag, padlock, guard veil, hover, flashes, the header's chips and hints |
| `modules/Pad.lua` | frames | the pad's frames: pooled secure chips, the header, the drag strip and lock, the saved position through `Library`, tabs, collapse, the send feedback |
| `DialLayout` | pure | `modules/Dial_Layout.lua`: the dial's rings, pages, open-into and geometry |
| `DialSecure` | secure snippets | `modules/Dial_Secure.lua`: the header's restricted snippets and the ring wiring; asks SendEngine for every write |
| `DialRender` | render | `modules/Dial_Render.lua`: the dial's insecure paint and pointer |
| `Dial` | frames | `modules/Dial.lua`: the dial's frames, pools and keys |
| `Editors` | settings | `settings/Editors.lua`: the pages' shared frame: the selection, the one deferred repaint, the reorder lists (each row's edit and remove glyphs), the delete popup, the icon picker |
| `Callouts` | settings | `settings/Callouts.lua`: the callout helpers the editors share: the token picker's list for a channel, and what a callout sends here |
| `CalloutPopup` | settings | `settings/CalloutPopup.lua`: the callout popup, modal over the settings window: one user group's callout, new or listed, edited as a draft and written on Save as one act |
| `Groups` | settings page | `settings/Groups.lua`: the Groups page (General, Callouts with Add callout, Reuse and the glyph list, When, Preview; built-ins read-only with Customize) |
| `GroupsWhen` | settings page | `settings/Groups_When.lua`: the When editor, one row per condition, the id lists, the active-now line |
| `Pads` | settings page | `settings/Pads.lua`: the Comms Pad page (General, Groups priority list, Layout with X/Y, Look) |
| `Dials` | settings page | `settings/Dials.lua`: the Comms Dial page (General, Groups, Wheel with X/Y, Binding, Preview) |
| `Share` | settings page | `settings/Share.lua`: the Share page: Export, Import, Built-in |

## Settings Schema

One write seam, `NS.SchemaRuntime.Set` (LibKa0s-Schema), reached by the panel, the CLI, the launcher
and the host verbs alike; the rows are `settings/Schema.lua`'s `Settings.Schema` array: the composed
Master controls rows, then the Behavior rows (`behavior.*`, spliced in by `settings/SchemaRows.lua`).
The Master controls rows are `enabled`, `visibility`, `scale`, `alpha` and `locked` (defaults
`true`, `always`, 1, 1, `true`), the session rows `state.debugConsole`, `state.testMode` and `state.previewAs`, and the
minimap row. Every module reads a setting through `NS.Setting(path)`, which answers the row's default before the
database exists. The reactions every surface shares are
`Settings.REACTIONS`. The path `enabled` is declared `writeThrough` so `/qc enable|disable` still
lands on a load where the composers are hollow (options-ui-§1 route (a)). Shape, defaults and
migrations: [`schema.md`](schema.md); the panel: [`settings-panel.md`](settings-panel.md).

**Member rows** (`settings/SchemaMembers.lua`): every field a player sets on a member is a row whose path starts with the member's kind (`callout.*`, `group.*`, `pad.*`, `dial.*`, `builtin.*`). The seam's `resolveRoot` hands it to `Library.Member(kind, id)`; the id is the instance argument, or the member that kind's editor page has selected (`NS.State.editing`). Each row's `onChange` is `Library.Touch`. With nothing selected, the seam addresses the first member the page lists (`Settings.EditingId`). A callout is addressed by its id alone (`Settings.BY_ID_KINDS`): no page selects one, so a `callout.*` write that names no id is refused with a line naming the id form (`/qc set callout.<field> <id> <value>`). The `callout.*` rows keep `page = "callouts"`, which no registered page renders: it is the heading `/qc list` groups them under, and the popup draws them against its draft. Member rows are no AceDB default: each resolves against `Library.TEMPLATES` at the boot check, and the profile reset's count leaves them out. The structured rows (`pad.point`, `dial.point`, `group.when`, `builtin.hidden`, and `dial.key`, the `key` type) hold tables or a key: their pages draw their own controls, and `settings/Slash.lua`'s descriptor `parse` and `format` hooks type and print them on the CLI. The pad's Look rows, `pad.look.font|fontSize|fontColor|useClassColorFont|fontFlags|fontShadow|borderStyle|borderSize|borderColor|useClassColorBorder|background|useClassColorBackground`, are composed by the options library (its font, border and color groups) and stamped as pad member rows; the colors are the `color` row type.

**State written outside the seam** (architecture-§5): `global.minimap.minimapPos` is LibDBIcon's own
write into the table the launcher hands it. The structural registry has one writer, `modules/Library.lua`:
membership (create, delete, duplicate, Customize) of `profile.callouts`, `groups`, `pads`, `dials`
and the built-in overlay, with the ownership rule that each user callout sits in exactly one user
group's `callouts` list (adding a callout to a group copies it, removing it or deleting the group
deletes it, duplicating a group copies its callouts), the order lists (`padOrder`, `dialOrder`, each group's callouts and each
surface's groups), `nextId`, `seeded` and the overlay's `customizedAs`. Panel pages and slash verbs call it or the seam; they never write those keys. What a share string
makes is written by `Library.Import` alone: fresh ids, the order lists, the references remapped,
every shipped built-in marked seen (`seenBuiltins`) on each imported pad and dial, and the surfaces'
fields through the seam (`modules/Share.lua` only decodes and checks). Built-ins are shipped data in `NS.BuiltIns`; the profile
holds only the overlay, keyed on the top-level built-in id. The load pass is `Library.Prepare`:
`OnInitialize` and `reloadProfile` run it after `RunMigrations`; it seeds the default pad and dial
once, appends newly shipped built-ins once per surface, normalizes malformed shapes, drops
dangling ids, and keeps the ownership rule: a callout a second group holds is replaced there by a
fresh copy, and a callout no group holds is deleted, each counted as a repair. `Library.Import`
does the same for a string (one copy per group, a loose callout left out and reported).

**Named non-setting state:** the pad's active tab and collapsed state are session-only (`NS.State`).
The editors' selection (`NS.State.editing`; no callout is ever selected) and the When editor's open
rows (`NS.State.whenOpen`) are session-only. The callout popup's draft is local to
`settings/CalloutPopup.lua` and dropped whenever the popup closes. The Share page's session state, `NS.State.share`: `pick` (the members ticked for
export, per kind) and `import` (the last checked string's result); a profile switch clears both, and
neither is ever saved.

## Message Bus

`core/Bus.lua` declares the catalog once, `NS.MSG`, as `Ka0s_QuickComms_<Event>` wire names with one
named sender each. With LibKa0s-Bus present the table is the strict `Catalog` copy, so a mistyped
key raises. Receivers take their own `NS.Bus:NewTarget()`; `NS.StandDown` / `NS.StandUp` take every
tracked registration down and replay it.

| `NS.MSG` key | Wire suffix | Sender | Payload | Consumers |
|---|---|---|---|---|
| `PROFILE_CHANGED` | `ProfileChanged` | `core/QuickComms.lua` `reloadProfile` (every AceDB profile event) | none | Surfaces (`Request`, after dropping the queued `surfaces` and `positions` entries; a held drag's stop stays); the editor pages (`settings/Editors.lua`, one deferred repaint) |
| `SITUATION_CHANGED` | `SituationChanged` | `modules/Situation.lua`, only when the signature moves | snapshot, previous | Surfaces (`Request`); the editor pages (`settings/Editors.lua`, one deferred repaint) |
| `RESTRICTION_CHANGED` | `RestrictionChanged` | `modules/Restrictions.lua`, when the set of blocking reasons (combat included) moves | reason, canSendChat | Situation (merges lockdown and combat into the snapshot in place); Surfaces (`RefreshLocks`: padlocks, the lockdown chip, the fade); Preview (ends test mode at the combat edge); Pad (ends a drag at the combat edge); SendEngine (drains the combat-end queue) |
| `LIBRARY_CHANGED` | `LibraryChanged` | `modules/Library.lua`, on every registry write, and `Library.Touch` for every member row the seam writes; inside `Library.Batch` (Customize, New group, OfferGroup, a page's Defaults, Share's Defaults, an import) one per act, its kind the kinds touched joined by commas, with no id and no field | kind, id, field | Surfaces (`Request`); the editor pages (`settings/Editors.lua`, one deferred repaint) |
| `ACTIVE_GROUPS_CHANGED` | `ActiveGroupsChanged` | `modules/Surfaces.lua` `ApplyAll`, when a pad's or a dial's ordered active groups change | surfaceId (a pad's or a dial's) | none (Surfaces rebuilds pads and dials itself) |
| `SURFACE_REBUILT` | `SurfaceRebuilt` | `modules/Surfaces.lua`: `true` when a rebuild is held for combat, `false` when it ran | surfaceId (a pad's or a dial's), stale | none |
| `SEND_RESULT` | `SendResult` | `modules/SendEngine.lua`: `guarded` at the press, then `sent` or `dropped` from the echo, so one press can yield two | calloutId, surfaceId, result | `modules/Pad.lua` (the flash, the sound); `modules/Dial.lua` (the wedges' flash) |
| `COMBAT_QUEUE_DRAINED` | `CombatQueueDrained` | `modules/SendEngine.lua` `Drain` | count | `modules/Surfaces.lua` (clears the stale hints) |
| `TEST_MODE_CHANGED` | `TestModeChanged` | `modules/Preview.lua` `SetTestMode` and `SetPreviewAs` | on (test mode or Preview as…) | `modules/Surfaces.lua` (`Request`, and opens dial 1); the editor pages (repaint) |

## Slash Commands

`/qc`, alias `/quickcomms`. The reserved verbs (`help config enable disable lock unlock version list
get set reset resetall profile debug diagnostics perf`; `lock` and `unlock` are slash-commands-§8's,
the Lock frame row's path through the seam) and the feature verbs `check <id>`, which prints the
line a callout would send under the current situation and never sends, `test` (test mode), `preview` ("Preview as…") and `why` ("Why is this showing?", for every built pad and dial). The full table, the live-while-disabled set
and the handlers are in [`slash-dispatch.md`](slash-dispatch.md). `enable` and `disable` call the
same handler as the Master controls row and the launcher entry.

## Event Subscriptions

Every game event is declared in `NS.FEATURE_EVENTS` and registered through `NS.SafeRegisterEvent`,
so `OnEnable` and the stand-up register exactly that list and the stand-down unregisters it. The list
holds the situation and restriction edges' rows (zone, key, group, spec and restriction events, and
the two combat edges, which `Restrictions` owns), and the send engine's nine `CHAT_MSG_*` rows (say,
yell, party and its leader, raid and its leader, raid warning, instance and its leader), whose
handler matches an echo to a press without reading the text. The one registration outside
`NS.FEATURE_EVENTS` is `SendEngine`'s private `PLAYER_REGEN_ENABLED` target, which exists only while
a stand-down is held in combat and is released when it fires (slash-commands-§7).

AceDB's `OnProfileChanged`, `OnProfileCopied` and `OnProfileReset` callbacks are setup and stay up
while disabled. Events the client refuses are kept in `NS.rejectedEvents` and reported by the
`[Init]` summary and the diagnostics report.

## Taint Notes

Every secure rule lives in one file. `modules/SendEngine.lua` is the only code that creates a frame from a `Secure*` template, calls `SetAttribute` or registers a state driver; `tests/test_sendengine.lua` greps every other shipped file for `Secure*Template`, `SecureHandler`, `SetAttribute` (called or named as a string), the state-driver and override-binding calls, and for `SendChatMessage` (D12: the secure button is the one send path). Send buttons are `SecureActionButtonTemplate`, named `QuickCommsSend<n>`, registered for `AnyUp` and `AnyDown`, armed with `type=macro` and one baked `macrotext` line, and only out of combat (`InCombatLockdown()`, events-frames-taint-§2). A pad's root becomes protected in combat because its chips are secure: its visibility is a `visibility` state driver, and its geometry is set only out of combat, through `RunOrQueue` (rebuilds, which also re-anchor it from the active profile, the end of a drag, Reset position). A rebuild asked for in combat is filed in SendEngine's keyed combat-end queue (one entry per key, the last write winning) and drained at `PLAYER_REGEN_ENABLED`, which `Restrictions` owns and hands to `SendEngine.Drain`, and on any later `RESTRICTION_CHANGED` out of combat. The click hook is an insecure `HookScript("OnClick")`: it cannot cancel the secure click, so the spam guard is soft (spec §9.2), and it never reads chat text. A stand-down in combat holds its secure half in one private `PLAYER_REGEN_ENABLED` registration, released when it fires. Tabs and collapse are refused in combat. The Comms Dial (Relaxed mode) is one `SecureHandlerClickTemplate` header per dial, `QuickCommsDial<n>`, created by SendEngine; its ring containers are `SecureFrameTemplate` frames and its wedges are send buttons. `modules/Dial_Secure.lua` holds the header's restricted snippets as text and hands them, every attribute and every frame ref to SendEngine out of combat; the snippets themselves write no attribute (the ring on screen is a global in the header's restricted environment; `tests/test_dial_secure.lua`'s firewall case checks the snippet text, and the firewall grep, whose list now includes a header's `SetFrameRef`, `WrapScript` and `Execute`, covers the file). In combat only the snippets act: they show and hide the rings and the hub, anchor the hub at the cursor, and bind Escape, the wheel and 1–8 with `SetBindingClick` while the dial is open from its key, releasing them with `ClearBindings`; an open from the insecure side (test mode, Preview as…, `qc-display`) binds nothing. Each wedge's click is wrapped by the header before SendEngine hooks it (the client's wrap replaces the script, which would drop an earlier hook); a wedge acts on the up edge and only a left click is a press. The dials' keys are override bindings (`SetOverrideBindingClick`) on one SendEngine owner frame, replaced as a set at every rebuild out of combat and cleared by the stand-down (held to combat end if need be). `Bindings.xml` adds `CLICK QuickCommsDial<n>:Toggle` entries to WoW's own key bindings menu; its labels are client-read globals: the header declared in `.luacheckrc` `globals`, the four entry labels (not identifiers) set with `rawset`. Opening the settings panel stays refused in combat by the options library, and the callout popup is locked with it: its ctx is a panel ctx, so the library's combat cover lies over it and refuses Save and every draft write; Escape still cancels. The editor pages touch no frame of a pad: every write reaches a pad through `LIBRARY_CHANGED` → `Surfaces.Request`, so a write made in combat (a CLI `set`, a popup accepted after the pull) waits for combat end behind the stale hint. Sharing writes no frame. An export reads the profile and shows a plain copy window; an import is data, written by `Library.Import` through the seam, and reaches the surfaces as any write does (`LIBRARY_CHANGED` → `Surfaces.Request`, queued in combat behind the stale hint). Both acts also refuse in combat. Nothing in a share string is executed: every text field is sanitized when it is checked, and `Bake` refuses a leading `/` again at every bake.

## Known Limitations

- The spam guard is soft: insecure code cannot cancel a secure click, so a press inside the window still reaches the game. A boss may drop it; the echo tracker then reports the drop (spec §9.2, the C5 upgrade).
- Another player's message on the same channel can mask a drop, and an unreadable sender counts as the player's own echo (spec §9.3, C6).
- In combat a rebuild waits for combat to end: chips keep the lines baked at the last rebuild out of combat (a stale `/p` after leaving a group, spec §18).
- Disabled in combat, a pad stays on screen, and its chips still send, until combat ends and the held stand-down finishes. Those presses are not tracked: no guard, no echo timer, no note.
- The mouse wheel over a pad belongs to the pad (spec §10.2): with groups as tabs it switches the tab, otherwise it does nothing there, so the camera does not zoom while the cursor is over a pad.
- Rebuilding between pulls inside a key assumes `SetAttribute` works out of combat in a key (C4, unverified).
- A member row written from the CLI addresses the member its page has selected, else the first that page lists; the echo does not name which member it was. A callout row is the exception: it names its callout by id.
- A `/qc set` to the callout the popup has open is not merged into the draft: Save writes the fields the draft changed, measured against the values the popup opened with, so it overwrites the slash write on those fields and keeps it on the rest.
- The Midnight dungeon and raid ids, spec 1480 and the battleground ids are matched against the client's data tables, not yet confirmed in game (smoke checks IDS-1 and BG-2); Sporefall (1592) is left out (owner ruling R4).
- The Comms Dial is Relaxed only: the hold, flick and release dial, its draw delay and tap action wait for C7 (spec §11.2).
- A dial whose groups are all inactive opens nothing when its key is pressed (there is no empty ring).
- Open at the cursor relies on the restricted `SetPoint` accepting `$cursor` (unverified until DIAL-7); the fallback is opening at the dial's place.
- A dial closes on a send, so its guard dim and its drop flash show only on the next open: the dim for the guard window, a drop's red for 5 s; the chat note reports a drop either way.
- Disabled in combat, a dial keeps working (and its key keeps opening it) until combat ends and the held stand-down finishes.
- Test mode or Preview as… ended by a combat whose lockdown began first leaves dial 1 open, its placeholder wedges sending nothing and holding no key, until combat ends (the hub or its key closes it sooner).
- Battleground node sets are pinned to compass winds derived from the client's map data, not yet checked in game (smoke check BG-1); Flat mode is not pinned.
- The Profiles page builds only where AceDBOptions and AceConfigDialog resolve, which the headless
  mock does not model; PROFILE-1 is its in-game check.
- A share string carries at most 500 members and 50,000 characters; a larger collection is shared in parts.
- A hostile share string can still make the client inflate up to about 25 MB once when Accept is clicked (LibDeflate has no output cap, so the 50,000-character limit bounds the input, not the output); that is a hitch of about a second, after which the string is refused as damaged because its payload is over 512 KiB, and nothing reads it.
- An imported callout's text is limited to 255 bytes, while the editor's Text box counts 255 characters: a non-Latin text the box accepts can be refused on import, and could never have baked.
- Midnight's Slayer's Rise (map 2799) has no battleground set of its own; the generic set covers it.
- The shipped raids are the current tier's three; a later tier joins `defaults/GameIds.lua` when it is current (the When editor adds the instance you are in meanwhile).
- Node winds come from the client's map data as of build 12.1.5.70340; a battleground a patch redraws needs its winds re-read (`docs/common-tasks.md`).
- `tests/perf.lua`'s byte ceilings are the headless mock's figures (its catch-all methods allocate per call); compare them run to run, never with the client.
- The logo is a placeholder generated for the scaffold; the owner may replace the art (regenerate
  the TGAs with the recipe in `DEPENDENCIES.md`).

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
| `slash-dispatch.md` | Present | 20 commands in `NS.COMMANDS` |
| `profiles.md` | Present | The Profiles page ships in the options UI |
| `debug.md` | Present | The diagnostics dump ships in every addon (debug-logging-§14) |
| `midnight-quirks.md` | Not applicable | The addon carries no client-version workaround of its own yet |
| `compat-layer.md` | Present | `core/Compat.lua` publishes 27 shims, three or more |
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

None.

### Files over the 1500-line cap

The layout-§1 census of authored `.lua` files over the 1500-line cap. Vendored code (`libs/`,
`tests/_kit/`) is out of scope; the generators under `tools/` are authored Python, under the cap, and
the repository has no generated data file.

Nothing is over the cap today.
