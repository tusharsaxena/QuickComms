# Module map — Ka0s Quick Comms

Every non-vendored file, its responsibility, and the TOC load order. `libs/` (Ace3, LibSharedMedia,
LibDataBroker, LibDBIcon, LibDeflate, LibSerialize, LibCustomGlow-1.0, LibKa0s v1.74.0 whole) and `tests/_kit/` are vendored and never edited.

## Load order (the TOC)

The TOC loads `libs\LibDeflate\lib.xml` and `libs\LibSerialize\lib.xml` after LibKa0s; `modules/Share.lua` takes both at load. `libs\LibCustomGlow-1.0\LibCustomGlow-1.0.xml` loads before LibKa0s; `modules/Glow.lua` resolves it at call time.

| # | File | Kind | Responsibility |
|---|---|---|---|
| 1 | `locales/enUS.lua` | data | `NS.L`, the metatable fallback; the key is the English string |
| 2 | `core/Namespace.lua` | data | name, version, brand, the cyan `[QC]` tag, the slash and its alias |
| 3 | `core/CoreSetup.lua` | setup | LibKa0s-Core: the printer, the secret-safe stringifier, the SafeRegister family, the skin, the close-button wrapper, the resize grip, the class-color resolver |
| 3a | `core/Compat.lua` | compat | `NS.Compat`: the only caller of version-variant or optional client APIs (the macro icon lists among them), and the secret guards ([`compat-layer.md`](compat-layer.md)) |
| 3b | `core/EUIBridge.lua` | bridge | `NS.EUIBridge`: the only reader of EllesmereUI's state (an optional suite): the skin's two conditions (the suite and its Blizzard Skin child present; the facade's `S.IsEnabled()`, never EllesmereUI's SavedVariables) and its presence-guarded `RegisterSkin`; every read at call time |
| 4 | `core/MediaSetup.lua` | setup | LibKa0s-Media: `NS.Icon`, `NS.MediaFont`, the one RegisterLSM call, `NS.MediaFetch` |
| 5 | `core/Constants.lua` | data | `FONT_MONO`, the Ka0s gold |
| 6 | `core/State.lua` | state | session-only state (`NS.State`): the debug flag; the modules add their own fields (test mode, plans, the queue, the echo, the pad's tab and collapse) |
| 7 | `core/EnvSetup.lua` | setup | LibKa0s-Env: `NS.Meta`, `NS.Version` |
| 8 | `core/PoolSetup.lua` | setup | LibKa0s-Pool: `NS.Pool` (one array pool per pad for its chips; per dial, its ring containers and each container's wedges) |
| 8a | `core/WidgetsSetup.lua` | setup | LibKa0s-Widgets: the drag-strip seam, `NS.MakeDragHandle`, and the export window, `NS.MakeCopyWindow` |
| 9 | `core/Bus.lua` | setup | LibKa0s-Bus: `NS.MSG` (the strict catalog) and `NS.Bus` (tracked receivers) |
| 10 | `core/LifecycleSetup.lua` | setup | LibKa0s-Lifecycle: the stand-down latch, `NS.IsStoodDown` |
| 11 | `core/PerfSetup.lua` | setup | LibKa0s-Perf: `NS.Perf`, the declared buckets |
| 12 | `core/DebugLogSetup.lua` | setup | LibKa0s-DebugLog: the console, `NS.Debug` and its gates, the diagnostics descriptor |
| 13 | `core/QuickComms.lua` | lifecycle | AceAddon registration (`NS.addon`), `NS.FEATURE_EVENTS`, `NS.STAND_DOWN` / `NS.STAND_UP`, `NS.StandDown` / `NS.StandUp`, the profile callbacks |
| 14 | `core/Database.lua` | data | `NS.MIGRATIONS` (step 3 turns the built-in overlay into seeded groups; step 4 retires the Upward growth; step 5 renames the dungeon set and gives seeded callouts their glyphs; step 6 colors the seeded glyphs and adds the node sets' map-wide callouts; step 7 brings the battleground objective groups to stored profiles and opens the formerly flat sets into their ring), `NS.SCHEMA_VERSION` and the schemaVersion migration runner |
| 15 | `core/LauncherSetup.lua` | setup | LibKa0s-Launcher: the one LDB object, registered twice |
| 16 | `defaults/Profile.lua` | data | every default value (`NS.C`) |
| 16a | `defaults/BuiltIns.lua` | data | `NS.BuiltIns`: the registry of shipped sets and the declaring helpers; seed data, copied into each profile once as ordinary groups by `Library` |
| 16b | `defaults/BuiltIns_MythicPlus.lua`, `_Raid.lua`, `_Arena.lua`, `_World.lua`, `_Battlegrounds.lua`, `_Group.lua` | data | the shipped sets (spec §12; World (solo), groups polish; In Group, bg buttons, declared last so a content set stays first), a battleground's nodes as groups inside its set, each base-capture node with Attack, Defend, INC and Clear (bg buttons), and its objectives too (bg subgroups: Alterac Valley's 19, Isle of Conquest's bases, the flag maps', Wintergrasp's, Ashran's, Deephaul Ravine's and Seething Shore's; bg buttons: Silvershard Mines' tracks and switches, Temple of Kotmogu's orbs and center, each with its own callouts); every set, node and callout carries a colored catalog glyph |
| 16b1 | `defaults/Icons.lua` | data | `NS.IconDefaults`: the Icons tab's defaults (`For(kind)`), size ranges, glow styles, triggers and DropWatcher's knob table; `modules/Library.lua` reads it at load |
| 16b1a | `defaults/PadStyle.lua` | data | `NS.PadDefaults`: the Window tab's Header block (`Header()`, the header height range `HEADER_H`, default 22) and the Chip tab's defaults (`Chip()`, the chip height range `CHIP_H`, 0 automatic); `modules/Library.lua` and `modules/Pad_Layout.lua` read it at load |
| 16b2 | `defaults/GameIds.lua` | data | the shipped ids: the season's dungeons and raids, classes, specializations (matched against the client's data by `tools/derive-gameids.py` and `tests/test_gameids.lua`; confirmed in game by IDS-1) |
| 16b3 | `defaults/GameIds_Instances.lua` | data | the When editor's place lists: `INSTANCES` (every Encounter Journal dungeon and raid) and `ARENAS` (every arena, one per arena), derived and checked by `tools/derive-gameids.py` |
| 16c | `modules/Restrictions.lua` | edge | what the client's addon restrictions allow; `RESTRICTION_CHANGED` |
| 16d | `modules/Situation.lua` | classifier + edge | the situation snapshot; `SITUATION_CHANGED` |
| 16e | `modules/Tokens.lua` | pure | token expansion |
| 16f | `modules/Channels.lua` | pure | channel kinds, resolution, lock state |
| 16g | `modules/Bake.lua` | pure | callout + snapshot to one macro line |
| 16h | `modules/Resolver.lua` | pure | When rules to active groups; `WhenOf` (a child that inherits is judged by its parent's When); `ID_ROWS` (the place rows: instances, battleground, arena) |
| 16i | `modules/Library.lua` | registry writer | the one writer of the structural registry; `Prepare`; `SetSurfacePoint`; `SetIcon` (a member's icon and its glyph color, one act); the glyph helpers (`IsGlyph`, `ValidIconColor`, `IconTint`, `IconColorFrom`); seeding the shipped sets as ordinary groups, `RestoreBuiltins` and `SeededBattleground`; nesting (`ValidParent`, `SettleParent`, `Children`, `IsChild`); `MoveGenericBattlegroundLast` (migration step 2), `SeedFromOverlay` (migration step 3) and `SeedNewNodes` (the node half of Prepare's seeding, which migration step 7 runs on every stored profile) |
| 16i1 | `modules/Library_Migrate.lua` | registry writer | the registry writer's schemaVersion steps, beside Library (at its line budget): `MigrateGrowth` (migration step 4), `MigrateBuiltins` (step 5), `MigrateBuiltinsPolish` (step 6), `MigrateBattlegroundNodes` (step 7) |
| 16i2 | `modules/Share.lua` | pure + edge | the share string: codec, checks, report; Collect, Export, Apply |
| 16j | `modules/SendEngine_Guard.lua` | pure | `NS.SendGuard`: the soft guard's timing, the acting click edge, the echo tracker, the keyed queue |
| 16k | `modules/SendEngine.lua` | secure writer | the only secure writer: send buttons, arm and disarm, the combat-end queue, the click hook, the echo events, the held stand-down; the dial headers and rings, the wedge wrap, frame refs, snippet runs and the override bindings (`BindKeys`) |
| 16l | `modules/Preview.lua` | session state | test mode and "Preview as…": refused in combat, ended at the combat edge; `TEST_MODE_CHANGED` |
| 16m | `modules/Pad_Layout.lua` | pure | `NS.PadLayout`: pad geometry (the header row's height, `HeaderHeight`; the Chip tab's size, `CellSize`; up growth puts the header at the bottom; the pad is pinned by its growth edge; a grid pad sets a parent's small child sections side by side), visibility, fade |
| 16m1 | `modules/IconStyle.lua` | render | `NS.IconStyle`: the Icons tab's look on an icon (`Config`, `ApplyIcon`, `PaintBorder`, `PaintRing`, `IconFrame`); `GlowConfig`, which the Chip tab's glow reads too |
| 16m2 | `modules/Glow.lua` | render | `NS.Glow`: the Icons tab's glow (LibCustomGlow-1.0 at call time): `Bind`, `SetHover`, `Sent`, `Release`, `ReleaseFree`; the Chip tab's glow around the whole chip (`Chip`, its own key); the `glowStart` perf bucket |
| 16n | `modules/Surfaces.lua` | edge | the pads' and dials' plans (a group holding groups draws its own callouts, then a section, or a node ring, per child whose When matches) and the one rebuild request, queued in combat with the stale hint |
| 16o | `modules/Pad_Render.lua` | render | `NS.PadRender`: insecure chip and header visuals; the Window tab's skin and Section titles font, the header's look (`HeaderLook`, `ApplyHeaderLook`) and the Chip tab's (`ChipLook`, `ApplyChipLook`) |
| 16p | `modules/Pad.lua` | frames | the pad's frames: pooled secure chips, header, drag strip (as wide as the pad) and lock, position via `Library`, tabs, collapse, feedback |
| 16q | `modules/Dial_Layout.lua` | pure | `NS.DialLayout`: a dial's rings, pages, open-into, depth (`DeepGroups`) and wedge geometry; a node set pinned to its compass winds (`PinNodes`: `middle` and `free` nodes take the winds left over), else its paged ring |
| 16r | `modules/Dial_Secure.lua` | secure snippets | `NS.DialSecure`: the header's restricted snippets (text) and the ring wiring (`Load`); every write goes through SendEngine |
| 16s | `modules/Dial_Render.lua` | render | `NS.DialRender`: the dial's insecure paint (disc, hub, spokes, wedges) and the pointer's `OnUpdate` |
| 16t | `modules/Dial.lua` | frames | `NS.Dial`: the dial's header, ring and wedge pools, arming, `Sync`, the feedback; the key (`BindKey`, `KeyOf`, `Command`, `PlaceOf`: WoW's own binding of the place's Open Comms Dial entry); the key bindings menu's labels |
| 17 | `modules/Diagnostics.lua` | sections | the addon's sections of `/qc diagnostics` (identity, settings, registration, integrations, situation, restrictions, library, surfaces, dials, bindings, send) |
| 18 | `settings/SchemaSetup.lua` | setup | LibKa0s-Schema, or the host's documented stub of it |
| 19 | `settings/Schema.lua` | settings | the rows, the write seam (`NS.SchemaRuntime`), `NS.Setting`, the shared reactions, the defaults tree, the global reset |
| 20 | `settings/OptionsSetup.lua` | setup | LibKa0s-Options: the panel descriptor |
| 20a | `settings/SchemaRows.lua` | settings | the hand-written Behavior rows, spliced after the Master controls |
| 20a2 | `settings/SchemaIcons.lua` | settings | `Settings.IconRows(kind, checks)`: the Icons tab's `pad.icon.*` / `dial.icon.*` rows, spliced in by `settings/SchemaMembers.lua` |
| 20b | `settings/SchemaMembers.lua` | settings | the member rows (`callout.*`, `group.*`, `pad.*`, `dial.*`; `group.parent` and `group.inheritWhen` among them), addressed through `Library.Member` |
| 21 | `settings/Panel.lua` | settings | the landing page and the General page (Master controls) |
| 21a | `settings/Editors.lua` | settings | the editor pages' shared frame: selection, repaint, reorder lists (with their edit and remove glyphs, a glyph drawn in its color), the table rows (`Ed.TableRows`, the Groups page's Preview, with its own AceGUI row layout, `Ed.TABLE_LAYOUT` / `Ed.LayoutTableRow`), delete, the icon chooser (`Ed.IconChooser`: under its Icon label, the icon as drawn, Choose icon…, the glyph's color swatch) |
| 21b | `settings/Callouts.lua` | settings | the callout helpers (`Settings.Callouts`): the tokens a channel offers and one line of help for each, and what a callout sends here |
| 21b2 | `settings/ModalWindow.lua` | settings | `Settings.ModalWindow`: the modal window (click-catcher and dim, Blizzard's `SettingsFrameTemplate` or the fallback window, a page's header and body) the callout popup and the icon browser are each built in |
| 21b3 | `settings/IconBrowser_Sources.lua` | settings | `Settings.IconBrowserSources`: each icon browser tab's list (Markers, Game icons, Glyphs, the last per icon set) and each icon's name and credit |
| 21b4 | `settings/IconBrowser.lua` | settings | the icon browser (`Settings.IconBrowser`): modal over its opener, three tabs (Markers, Game icons, Glyphs), a virtualized grid, the search box, the Game icons filter and its Wowhead hint (a copy window), the Glyphs set filter and color swatch, Choose and Cancel |
| 21b5 | `settings/CalloutPopup.lua` | settings | the callout popup (`Settings.CalloutPopup`): a user group's callout, new or listed, edited as a draft, saved as one act, modal over the settings window; Blizzard's `SettingsFrameTemplate` window, sized to its body, with no scrollbar |
| 21b6 | `settings/CalloutPopup_Skin.lua` | settings | `Settings.CalloutPopupSkin`: the optional EllesmereUI skin of the popup's window and the icon browser's, registered at file load, each painted when it is built and every condition holds |
| 21c | `settings/Groups_When.lua` | settings | the Groups page's When editor: a drawer per condition (`H.Drawer`), Select all and Clear (Any), an inheriting group's read-only view |
| 21d | `settings/Groups.lua` | settings | the Groups page, the same for every group, a seeded built-in set among them (General: Parent group, Inherit when conditions, Restore built-in groups; Callouts: Add callout, Reuse callout, the glyph list; Preview as a table) |
| 21e | `settings/Pads.lua` | settings | the Comms Pad page |
| 21e2 | `settings/Dials.lua` | settings | the Comms Dial page (General, Groups, Wheel, Icons, Binding, Preview) |
| 21f | `settings/Share.lua` | settings | the Share page (Export, Import) |
| 21g | `settings/SlashVerbs.lua` | verbs | `NS.SlashVerbs`: the verb bodies (`check`, `SetLocked` for `lock` / `unlock`, `TogglePads` for `toggle`, `preview`, `why`); the Toggle Comms Pads binding's hidden `QuickCommsTogglePads` button and label |
| 22 | `settings/Slash.lua` | setup | `NS.COMMANDS` and the LibKa0s-Slash descriptor |
| 23 | `settings/Profiles.lua` | settings | the Profiles page (AceDBOptions) |

`Bindings.xml` (root, not a TOC line): Open Comms Dial 1–4 in WoW's key bindings menu, each a
`CLICK QuickCommsDial<n>:Toggle` binding (a dial's key is this binding since 2026-10-20), and Toggle
Comms Pads, `CLICK QuickCommsTogglePads:LeftButton`. The client reads it from the addon's root by
name, and the standard allows it there (layout-§1, toc-file-§4 (standard v2.80.0)); the dials' labels
are set in `modules/Dial.lua`, Toggle Comms Pads' in `settings/SlashVerbs.lua`.

`tools/` holds the dev-only generators (`derive-gameids.py`, `derive-winds.py` and their shared
`client_tables.py`): Python, never loaded by the client or the TOC, `.pkgmeta`-ignored (layout-§1).

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
| `tests/test_mock_secure.lua` | the mock's secure half: protected calls refused in combat are recorded, a click acts on one edge, a visibility driver follows combat; the secure handlers (snippets, wraps, frame refs) and key bindings |
| `tests/test_send_guard.lua` | `SendEngine_Guard`: the guard's timing, the acting edge, the echo tracker, the keyed queue (pure) |
| `tests/test_sendengine.lua` | `SendEngine`: buttons, arm and disarm, the queue, the held stand-down, and the firewall grep (no secure call or `SendChatMessage` elsewhere) |
| `tests/test_preview.lua` | test mode: session-only, refused in combat, ended at the combat edge, ended by the stand-down |
| `tests/test_master.lua` | the lock and test mode through one handler from the row, the verb and the launcher entry |
| `tests/test_pad_layout.lua` | `Pad_Layout`: geometry, the sections per groups-as mode, the visibility expression, the fade |
| `tests/test_surfaces.lua` | `Surfaces`: a pad's plan (a parent's own callouts and a section per child that is active), and the rebuild queued in combat with the stale hint |
| `tests/test_pad_render.lua` | `Pad_Render`: what a chip and the header show (no channel letter: the label runs to the chip's edge, or the padlock's while locked; the tooltip names the channel), and the drag-strip seam |
| `tests/test_icon_style.lua` | `IconStyle`: the defaults keep today's look; zoom, desaturate, alpha, the tint times a glyph's color; a pad's icon size feeds the chip's geometry; the chip's border and the wedge's round ring, never wider than the wedge; `fillShape` backfills `icon` |
| `tests/test_glow.lua` | `Glow`: off by default; each style's call and knobs (a fake LibCustomGlow-1.0); an unchanged rebuild calls nothing; On hover and After sending; unused and released chips stop; no protected call in combat and the Icons write held to combat end; a wedge's glow; a dial's send glow from the next open within `DROP_SECONDS`; the stand-down puts out a send glow whose release is held |
| `tests/test_pad.lua` | `Pad`: armed or disarmed chips, the visibility driver, the drag strip shown while unlocked (it will not drag while locked or in combat) |
| `tests/test_members.lua` | the member rows: addressed by instance, selection or the first listed member (a callout by its id alone); a seeded group read and written as any group, a shipped id refused; `Library.Touch` announces each write; the CLI text forms |
| `tests/test_editors.lua` | `settings/Editors.lua`: the selection heals and a profile switch clears it, one structural repaint per frame, none for a scalar write, the delete confirmation, the jump, the reorder rows' edit and remove glyphs, the table rows (the Preview table) |
| `tests/test_icon_browser.lua` | the icon browser: its chrome and stacking above the popup, the tabs and what each offers, select, double-click and Choose, the hover names, the game list's filter and its not-loaded state, the search (`Src.Search`, the box, the count, the session text) and the Wowhead hint and its copy window, the virtualized grid, the glyph color swatch, Escape over the popup, what closes it (the popup, a stand-down), Choose refused in combat, `Compat.MacroIcons` and `Library.IconColorFrom` |
| `tests/test_callout_popup.lua` | the callout popup: Add and Edit, the draft rows (the icon's glyph color with them), the token glyph and its tooltip, Choose icon… and the browser's Choose on the draft, the Preview heading and the Cancel-then-Save pair, the preview on the draft, Save's checks and its one act, Cancel and what else closes it, the settings-window template and its close X, its background over the catcher's dim, the template asked of `C_XMLUtil` where it can answer, the fallback window and its close mark, no scrollbar and the height that follows the body (pinned to the library's layout keys), no Callouts page, and the helpers' token list, token help and preview lines |
| `tests/test_eui_skin.lua` | the popup's EllesmereUI skin on a mocked EllesmereUI: painted as the settings window is when every condition holds, at the build or at a late callback, once (the icon browser's window too); not when any condition fails; never raising without EllesmereUI; a changed facade left stock; painted while the addon is disabled; the fallback window left unpainted; the diagnostics report's line and its `why=` reason |
| `tests/test_groups_when.lua` | the When editor's pure half (toggle, clear, select all, key-level range, the values offered, the summary, the active-now line, an inheriting group's) and its write through the seam |
| `tests/test_page_groups.lua` | the Groups page: the band (the picker, New group and Preview while editing one SimpleGroup's children, shown and sized, after a group switch too), picker (children indented, the green dot after the name) and New group, a group's tabs, a seeded set's the same as any (General's Parent group, icon chooser and the browser's writes, Restore built-in groups; Inherit when conditions beside Parent group; the Callouts tab's Add callout, Reuse and glyph list; the When drawers, Select all and Clear (Any), and an inheriting group's read-only When; no green dot on a seeded battleground's nodes in the open world; the Preview table), deleting a parent |
| `tests/test_page_pads.lua` | the Comms Pad page: picker and New pad, General's acts, the Groups priority list, Layout with X/Y, the Window tab (its Header block), the Chip tab, the Icons tab |
| `tests/test_dial_layout.lua` | `Dial_Layout`: rings, pages, open-into, geometry |
| `tests/test_dial_secure.lua` | `Dial_Secure`: the snippets on a hand-built dial, in and out of combat |
| `tests/test_dial.lua` | `Dial`: the frames, the rebuild, the keys as WoW's own bindings (`BindKey`), the three exit paths, `Bindings.xml` and the Toggle Comms Pads binding |
| `tests/test_page_dials.lua` | the Comms Dial page |
| `tests/test_page_share.lua` | the Share page: the Export tab (ticks, what they bring, the string in the copy window) and the Import tab (Accept, the report, Import, the combat refusals), and Defaults |
| `tests/test_share.lua` | `Share`: the codec, the checks, the sanitizer, the report (pure); a parent and its children travel together, and an import nests them under the new copy |
| `tests/test_gameids.lua` | the shipped instance and arena ids (`GameIds.lua`, `GameIds_Instances.lua`) against an extraction of the client's Map tables |
| `tests/page_helpers.lua` | a helper, not a suite: drives an editor page through the kit's AceGUI recorder |
| `tests/perf.lua` | the six offline scenarios, outside the gate |
