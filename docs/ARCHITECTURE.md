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
optional parent group, one level deep), pads (with their Pad header, Section header, Window, Buttons and Icons styling) and dials on the Groups, Comms Pad, Comms Dial and Share
pages, and shares any of them as a `!QC1!` string. The shipped built-in sets are seed data: each
profile is given them once as ordinary groups, a battleground's nodes as groups inside its set, and
Restore built-in groups brings back any the player deleted; "Preview as…" draws the surfaces in another
situation and "Why is this showing?" explains them. A dial opens on its
key in Relaxed mode: click a wedge to send. The key is WoW's own binding of the dial's `Bindings.xml`
entry (Open Comms Dial 1-4, the dial's place in the order), set in Options →
Keybindings, account-wide unless the player ticks Character Specific Keybindings; a Toggle Comms Pads
binding beside them runs `/qc toggle`'s handler.

Ace3 (AceAddon, AceDB, AceEvent, AceTimer, AceConsole, AceGUI, AceConfig, AceDBOptions),
LibSharedMedia, LibDataBroker, LibDBIcon, LibDeflate and LibSerialize (the share string, spec §15),
and LibCustomGlow-1.0 (the Icons tab's glows, resolved at call time and optional; versions and
licenses in `DEPENDENCIES.md`) are vendored under `libs/`, and so is the whole
LibKa0s v1.74.0 payload, of which thirteen majors are wired, one setup file each (`DEPENDENCIES.md`
lists the toolchain):

| Major | Setup file | Gives |
|---|---|---|
| Core | `core/CoreSetup.lua` | the `[QC]` printer, secret-safe stringifier, SafeRegister family, the skin, the close mark, the resize grip, and the class-color resolver (`NS.ResolveColor`) |
| Media | `core/MediaSetup.lua` | the icon catalog and the monospace face, and `NS.MediaFetch` (a LibSharedMedia entry by name) |
| Env | `core/EnvSetup.lua` | the addon's own TOC metadata and version |
| Pool | `core/PoolSetup.lua` | the frame pool (one array pool per pad for its buttons; per dial, one for its ring containers and one per container for its wedges) |
| Widgets | `core/WidgetsSetup.lua` | the drag strip (`NS.MakeDragHandle`) above each pad, and the reorder lists on the editor pages (`ReorderList`), and the Share page's export window and the icon browser's Wowhead address window (`NS.MakeCopyWindow`, the library's `CopyWindow`) |
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

Every file, its kind and its TOC position is in [`module-map.md`](module-map.md). In short: `core/`
holds the identity, ten of the setup files, the session state, the addon object and its lifecycle,
and the migration runner; `defaults/` the default values and the shipped built-in sets (seed data); `modules/`
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
| `Resolver` | pure | When rules to the active group set (`WhenOf`: a child that inherits is judged by its parent's When; `ID_ROWS`: the place rows, instances, battleground and arena), surface order, the "why" lines |
| `Library` | registry writer | membership, order, ids, references and seeding of the profile's callouts, groups, pads and dials: the shipped sets seeded once per profile as ordinary groups (`SeedFromOverlay` for migration step 3), `RestoreBuiltins`, and the one-level nesting rules (`ValidParent`, `SettleParent`, `Children`); member fields go through the seam (member rows); `Prepare`; `Batch` (one act, one announce); and `Import`, the one writer of what a share string brings; sends `LIBRARY_CHANGED` |
| `Share` | pure + edge | `modules/Share.lua`: pure codec and checks (the `!QC1!` string, the version gate, the schema checks, the sanitizer over every text field, the report), and the edge: Collect, Export (the copy window), Apply (through `Library.Import`); both acts refused in combat |
| `BuiltIns` | data | `defaults/BuiltIns*.lua`: the shipped sets, as seed data: `Library` copies them into each profile once as ordinary groups and callouts, and after that they are read only for names (the Preview as menu's battlegrounds, the When editor's battleground list) |
| `core/WidgetsSetup.lua` | setup | the drag-strip seam: `NS.MakeDragHandle` over LibKa0s-Widgets' `DragHandle`, nil when the library is absent |
| `modules/SendEngine_Guard.lua` | pure | the soft guard's timing, the acting click edge, the echo tracker and the keyed combat-end queue |
| `modules/SendEngine.lua` | secure writer | the only secure writer: send buttons, arm and disarm, the combat-end queue, the click hook, the echo events, the held stand-down; and the dial headers and rings, the wedge wrap, frame refs, snippet runs (no override binding since 2026-10-20: a dial's key is WoW's own binding); sends `SEND_RESULT` and `COMBAT_QUEUE_DRAINED` |
| `modules/Preview.lua` | session state | test mode and "Preview as…" (its second flavor: the menu, the synthetic snapshot): refused in combat, ended at the combat edge; sends `TEST_MODE_CHANGED` |
| `modules/Pad_Layout.lua` | pure | pad geometry (the header row's height, `HeaderHeight`; the Buttons tab's button size, `CellSize`; up growth puts the header at the bottom; the pad is pinned by its growth edge), the sections each groups-as mode draws, the visibility expression, the fade |
| `modules/Surfaces.lua` | edge | each pad's plan (active groups, sections, baked or refused slots), each dial's plan (the same active groups, its ring radius) and rebuild beside the pads, and the one rebuild request, queued in combat with the stale hint; sends `ACTIVE_GROUPS_CHANGED` and `SURFACE_REBUILT` |
| `modules/IconStyle.lua` | render | the Icons tab's look on a button's or a wedge's icon (B9): `Config` reads a surface's `icon` table once per rebuild; size, crop (`SetTexCoord`), desaturation, alpha, the tint multiplied with a glyph's own color, and the border (a backdrop on a plain child frame over a button's icon; a round ring behind a wedge's) |
| `modules/Glow.lua` | render | the Icons tab's glow, and the Buttons tab's (`Glow.Button`: around the whole button, on the button's edge frame under its own key, always on while enabled): LibCustomGlow-1.0's four styles with DropWatcher's knob table, started on the icon's plain child frame; the trigger Always, On hover or After sending (`SEND_SECONDS`, 1.5 s from the send result; on a dial, which the send closes, again from the next open within `Dial.DROP_SECONDS`); a stand-down puts out a running send glow itself; an unchanged rebuild restarts nothing, and a button or wedge no longer drawn stops its glow |
| `modules/Pad_Render.lua` | render | insecure button and header visuals: icon (styled by `IconStyle` and `Glow`), label, padlock, the tooltip's line and channel, guard veil, hover, flashes, the header's buttons and hints; the Window tab's skin (`SkinFor`), the Section header tab's look (`SectionLook`: the titles' font, `TitleFont`, their row height and the band behind each, `ApplySectionBand`), the header's look (`HeaderLook`: height, font, background, edge; its text on the titles' left edge; `HeaderMinWidth`, the width the row needs, is the pad's floor) and the Buttons tab's (`ButtonLook`: body, an edge on a plain child over the button, label font, glow) |
| `modules/Pad.lua` | frames | the pad's frames: pooled secure buttons, the header, the drag strip (as wide as the pad; its label the pad's name, then PREVIEW or TEST MODE) and lock, the saved position through `Library`, tabs, collapse (the header's button or a left click anywhere on the row), the send feedback, and a plain hit frame over each section title whose right-click opens the Groups page on that group (`QC:EditGroup`) |
| `DialLayout` | pure | `modules/Dial_Layout.lua`: the dial's rings, pages (and their arrow, pill and dot row), Auto's wedge shapes and the one placement rule from W (`PageShape`), the slice gap's shift (`SliceShift`), Auto's icon-fit cap (`AutoCap`), the slice under a point (`SliceAt`, shared by the tracker and the catcher's snippet), the lone-group open, the geometry at the dial's radius (the labels' and icons' own offsets from the center: `Geometry`'s `reach`, `IconReach`), the pointer's reach and the page row sized by the Paging tab (`Nav`, `PAGING`) |
| `DialSecure` | secure snippets | `modules/Dial_Secure.lua`: the header's restricted snippets (the ring catcher's and the screen catcher's among them, dial polish 2026-10-21) and the ring wiring; asks SendEngine for every write |
| `DialSlices` | render | `modules/Dial_Slices.lua`: a ring drawn as its slices (2026-10-21): a tinted pie-slice fill per wedge place (`media/textures/dial-sector-<n>.tga`, written by `tools/gen-dial-textures.py`), each slice moved out along its middle line by the Slice gap and shrunk to stay on the disc (`Dial_Layout.SliceShift`; dial polish 2026-10-21, which retired the border's spokes and rim), the slice the cursor points into lit whole anywhere on the disc outside the hub's circle (`Track`, through `Dial_Layout.SliceAt`, the math the ring's secure catcher repeats), the page row's pill and dots in the Paging tab's sizes and colors |
| `DialRender` | render | `modules/Dial_Render.lua`: the dial's insecure paint (the title in the Group labels tab's font, the page arrows' plates and chevrons, the wedges' icons with no backdrop, and their labels outside the disc in the Slice labels tab's font), the hub (its backdrop, rim and circle in the Hub style, `PaintHubLook`; the circle brightens while hovered; the red close mark retired in the dial polish, 2026-10-21), its status text and the pointer on a mouse-off front frame raised over every ring (`RaiseFront`), the pointer (the Slices tab's glyph, size, color and offset) and its per-frame update, which also tracks the lit slice and gives it its wedge's hover, glow and tooltip (`HoverWedge`), and the dial's tooltips, placed outside it on the Slice labels tab's side |
| `Dial` | frames | `modules/Dial.lua`: the dial's frames and pools (each ring with its two page arrows), and its key: `KeyOf` reads WoW's own binding of the place's Open Comms Dial entry, set only in Options → Keybindings |
| `Editors` | settings | `settings/Editors.lua`: the pages' shared frame: the selection, the one deferred repaint, the reorder lists (each row's edit and remove glyphs, a glyph drawn in its color), the table rows (`Ed.TableRows`: a header, then a boxed row per entry, its name beside its text; the Groups page's Preview), the delete popup, the icon chooser (under its Icon label: the icon as drawn, Choose icon… and the glyph's color swatch; no Icon text box), and `Ed.OpenPage` (the settings window opened on one page's own category through `Settings.OpenToCategory`; in combat `QC:OpenSettings` prints the settings refusal) |
| `Callouts` | settings | `settings/Callouts.lua`: the callout helpers the editors share: the tokens a channel offers and one line of help for each, and what a callout sends here |
| `ModalWindow` | settings | `settings/ModalWindow.lua`: the modal window the callout popup and the icon browser are each built in: a full-screen click-catcher with a dim, Blizzard's `SettingsFrameTemplate` window (or the fallback window) in the caller's strata, and a settings page's header and body inside it |
| `IconBrowserSources` | settings | `settings/IconBrowser_Sources.lua`: what each icon browser tab offers (Markers, Game icons through `Compat.MacroIcons`, every LibKa0s glyph through `NS.IconNames`, each list built once per session, filtered All or one icon set through `NS.IconSets`) and what each icon is called, a set's prefix stripped from its label, with its set and a Game-icons mark's author (`NS.IconAuthor`) for the tooltip |
| `IconBrowser` | settings | `settings/IconBrowser.lua`: the icon browser, modal over whatever opened it (the callout popup, a group's General tab): three tabs (Markers, Game icons, Glyphs), a virtualized grid, the search box, the Game icons filter and its Wowhead hint, the Glyphs set filter and color swatch, Choose and Cancel ([`settings-panel.md`](settings-panel.md)) |
| `CalloutPopup` | settings | `settings/CalloutPopup.lua`: the callout popup, modal over the settings window: one user group's callout, new or listed, edited as a draft and written on Save as one act; Name and Channel, then Text across both columns, then the icon chooser, laid out in two aligned columns; its window is Blizzard's `SettingsFrameTemplate`, sized to its body, with no scrollbar ([`settings-panel.md`](settings-panel.md)) |
| `CalloutPopupSkin` | settings | `settings/CalloutPopup_Skin.lua`: the optional EllesmereUI skin of the popup's window and the icon browser's, each painted as EllesmereUI paints the settings window when EllesmereUI, its Blizzard Skin module, its third-party skinning and this addon's entry are all on |
| `EUIBridge` | bridge | `core/EUIBridge.lua`: the only reader of EllesmereUI's state (optional, in `## OptionalDeps`): the skin's conditions (the suite and its Blizzard Skin child present, and the facade's `S.IsEnabled()`; never EllesmereUI's SavedVariables) and its presence-guarded `RegisterSkin`, every read at call time |
| `Groups` | settings page | `settings/Groups.lua`: the Groups page, the same tabs for every group, a seeded built-in set among them (General with Parent group, Inherit when conditions and Restore built-in groups, Callouts with Add callout, Reuse and the glyph list, When, Preview as a table); `G.Edit` / `QC:EditGroup` select a group and open the page on it, keeping the tab |
| `GroupsWhen` | settings page | `settings/Groups_When.lua`: the When editor, one drawer per condition (`H.Drawer`: a header with its summary, the choices boxed under it, Select all and Clear (Any)), the id lists, the active-now line, and an inheriting group's read-only view of its parent's When |
| `Pads` | settings page | `settings/Pads.lua`: the Pad page (titled Comms Pad until the dial polish, 2026-10-21; General, Groups priority list, Layout with X/Y, Pad header, Section header, Window, Buttons, Icons) |
| `Dials` | settings page | `settings/Dials.lua`: the Dial page (titled Comms Dial until the dial polish, 2026-10-21; General, Groups, Wheel with ring radius and X/Y, Slices, Hub (the Hub and Pointer headings, on Slices until the dial polish), Paging, Slice labels, Group labels, Icons with Icon offset first, Preview) |
| `SchemaIcons` | settings | `settings/SchemaIcons.lua`: the Icons tab's rows for each kind (`Settings.IconRows`), which `settings/SchemaMembers.lua` splices into its member rows |
| `Share` | settings page | `settings/Share.lua`: the Share page: Export, Import |

## Settings Schema

One write seam, `NS.SchemaRuntime.Set` (LibKa0s-Schema), reached by the panel, the CLI, the launcher
and the host verbs alike; the rows are `settings/Schema.lua`'s `Settings.Schema` array: the composed
Master controls rows, then the Behavior rows (`behavior.*`, spliced in by `settings/SchemaRows.lua`).
The Master controls rows are `enabled`, `visibility`, `scale`, `alpha` and `locked` (defaults
`true`, `always`, 1, 1, `true`), the session rows `state.debugConsole` and `state.testMode`, the
minimap row, and the block's one `extra` row, the session row `state.previewAs` (Preview as…, options-ui-§15 as amended in v2.84.0). Every module reads a setting through `NS.Setting(path)`, which answers the row's default before the
database exists. The reactions every surface shares are
`Settings.REACTIONS`. The path `enabled` is declared `writeThrough` so `/qc enable|disable` still
lands on a load where the composers are hollow (options-ui-§1 route (a)). Shape, defaults and
migrations: [`schema.md`](schema.md); the panel: [`settings-panel.md`](settings-panel.md).

**Member rows** (`settings/SchemaMembers.lua`): every field a player sets on a member is a row whose path starts with the member's kind (`callout.*`, `group.*`, `pad.*`, `dial.*`). The seam's `resolveRoot` hands it to `Library.Member(kind, id)`; the id is the instance argument, or the member that kind's editor page has selected (`NS.State.editing`). Each row's `onChange` is `Library.Touch`. With nothing selected, the seam addresses the first member the page lists (`Settings.EditingId`). A callout is addressed by its id alone (`Settings.BY_ID_KINDS`): no page selects one, so a `callout.*` write that names no id is refused with a line naming the id form (`/qc set callout.<field> <id> <value>`). The `callout.*` rows keep `page = "callouts"`, which no registered page renders: it is the heading `/qc list` groups them under, and the popup draws them against its draft. Member rows are no AceDB default: each resolves against `Library.TEMPLATES` at the boot check, and the profile reset's count leaves them out. The structured rows (`pad.point`, `dial.point`, `group.when`) hold tables: their pages draw their own controls, and `settings/Slash.lua`'s descriptor `parse` and `format` hooks type and print them on the CLI. A dial's key is no row (2026-10-20; it was `dial.key`, the `key` type): it is WoW's own binding of the dial's Open Comms Dial entry, set only in Options → Keybindings, out of the profile. The dial rework (2026-10-21) adds the Wheel tab's `dial.radius` (Ring radius, 70 to 180, default 100), `dial.iconOffset` (Icon offset, 0 to 250, 0 automatic: the ring radius; the disc keeps its size; an Icons tab row since the dial polish, its path kept) and `dial.slices`' Auto (0, a new dial's default), and the Labels tab's (Slice labels since the dial polish, a UI rename; the paths kept) `dial.label.show`, `dial.label.offset` (Label offset, 0 to 300, 0 automatic: just past the disc) with its composed Font block `dial.label.font|fontSize|fontColor|useClassColorFont|fontFlags|fontShadow` (flat leaves of a top-level `label` table; defaults in `defaults/PadStyle.lua` `DialLabel`; the font rows and the offset gray out while Show labels is off) and its Tooltip heading's `dial.label.tooltipSide|tooltipOffset`. The Paging tab (2026-10-21) is `dial.page.*`, flat leaves of a top-level `page` table (defaults `DialPage`): `offset`, `arrowSize`, `arrowGap`, `dotSize`, `pillWidth`, `dotGap` and the composed swatch pairs `arrowColor|useClassColorArrow`, `plateColor|useClassColorPlate`, `currentColor|useClassColorCurrent`, `dotColor|useClassColorDot`, and (dial polish) the indicators' background `dotBackShow`, `dotBackPadding` (0 to 20) and `dotBackColor|useClassColorDotBack` (a rounded strip behind the row, three pieces: the halves of `dial-disc.tga` either side of a flat middle, so its caps stay round) and border `dotBorder` (0 to 4, 0 none) and `dotBorderColor|useClassColorDotBorder` (a larger copy of each indicator's texture behind it); `fillShape` fills them in a dial saved before them. The Slices tab (2026-10-21) is `dial.slice.*` (its pointer rows on the Hub tab since the dial polish, the paths kept), flat leaves of a top-level `slice` table (defaults `DialSlice`): the composed swatch pairs `background|useClassColorBackground`, `highlight|useClassColorHighlight` and `pointerColor|useClassColorPointer`, and `gap` (Slice gap, 0 to 20 pixels, default 0), `pointerShow`, `pointerSize`, `pointerOffset` (0 to 150, 0 automatic: just outside the hub; the pointer rows gray out while Show pointer is off). The dial polish (2026-10-21) retired its Border heading (`borderSize`, `borderColor|useClassColorBorder`; migration step 9 drops them) for the Slice gap, and added the Hub heading (on the Slices tab, until a Hub tab after Slices took it and the Pointer heading, the paths kept), `dial.hub.*`, flat leaves of a top-level `hub` table (defaults `DialHub`): `style` (Solid circle, the default; Hollow ring; Target; Rimmed disc), `size` (Hub size, 24 to 80, default 40: the hub's geometry, the slices' and pointer's inner edge), `circleSize` (4 to 60, default 22), `lineWidth` (1 to 6, grayed out under Solid circle), `borderSize` (0 to 6) and the composed pairs `background|useClassColorBackground`, `borderColor|useClassColorBorder`, `circleColor|useClassColorCircle`; and the Group labels tab, `dial.title.*`, a top-level `title` table (defaults `DialTitle`): `show` (Show group labels, default on) and the ring title's composed Font block, grayed out while off. The dial's Icon size goes to 128 (`IconDefaults.SIZE.dial.max`; a pad's stays 40), and Auto pages sooner when big icons no longer fit their slices (`Dial_Layout.AutoCap`). The pad's three window tabs (one Window tab until 2026-10-20, the Look tab before; owner request), each under its own headings: Window's `pad.look.borderStyle|borderSize|borderColor|useClassColorBorder|background|useClassColorBackground` (Main window until 2026-10-20, when its visibility, fade and faded alpha moved to the General tab under a Visibility heading; the paths kept; no font), Pad header's `pad.header.*` (its height, then a font, background and border block of its own), Section header's `pad.section.*` (its height, 0 automatic, then the section titles' font block, gold by default, and the background and border of the band behind each title), and the Buttons tab's `pad.button.*` (the Buttons tab until 2026-10-20, a UI rename only; width, height, a background pair, a border block, a font block, the glow toggle, style and color pair; defaults in `defaults/PadStyle.lua`) are composed by the options library (its font, border and color groups) and stamped as pad member rows; the colors are the `color` row type. A glyph's color is the `callout.iconColor` and `group.iconColor` rows (six lowercase hex digits, `false` for none; only a member whose icon is a LibKa0s glyph takes one, and an icon write that leaves a colored member without a glyph clears its color in the same act); `Library.SetIcon` writes a member's icon and its color as one act, through the seam. The two rows are reset-exempt, like the icon rows: a named `/qc reset` clears a color, a page's Defaults keeps it. `group.parent` (a group id, `false` for none; `/qc` also takes `none`) is the one-level nesting: its validator is `Library.ValidParent` (a top-level user group other than the group itself, and none for a group that holds groups), its `onChange` takes the group off every pad and dial in the same act (`Library.SettleParent`), and it is reset-exempt too. `group.inheritWhen` (bool, default `true`, absent read as on) is Inherit when conditions: a child judged by its parent's When instead of its own; the Resolver's one seam for it is `Resolver.WhenOf`, and it is structural (`Editors.STRUCTURAL`), so a write repaints the editor pages. The Icons tab's rows (B9) are `pad.icon.*` and `dial.icon.*`, flat leaves of a top-level `icon` table (so `fillShape` backfills a surface saved before them; defaults in `defaults/Icons.lua`): size, zoom, desaturate, alpha, the Tint color pair, the composed Border block with its Show border toggle, and Glow (on or off, when, style, the Glow color pair, and DropWatcher's knob table). They are made by `settings/SchemaIcons.lua` and spliced in by `settings/SchemaMembers.lua`: a pad's after its Window and Button rows, a dial's after its Group labels rows, led by Icon offset, so each Icons tab sits there.

**State written outside the seam** (architecture-§5): `global.minimap.minimapPos` is LibDBIcon's own
write into the table the launcher hands it. The structural registry has one writer, `modules/Library.lua` (its schemaVersion steps in `modules/Library_Migrate.lua`, the same `NS.Library`; the last, step 9 of the dial polish, `MigrateSliceBorder`, drops every stored dial's retired slice border leaves):
membership (create, delete, duplicate, restore) of `profile.callouts`, `groups`, `pads` and `dials`,
with the ownership rule that each user callout sits in exactly one user group's `callouts` list
(adding a callout to a group copies it, removing it or deleting the group deletes it, duplicating a
group copies its callouts), the order lists (`padOrder`, `dialOrder`, each group's callouts and each
surface's groups), `nextId`, `seeded`, `seededSets` and the seeded members' `origin` and `compass`.
A child group is never on a surface itself (it shows wherever its parent is), so taking a parent
takes the group off every pad and dial, and deleting a parent puts its children, as top-level groups,
in its place on every pad and dial. Panel pages and slash verbs call it or the seam; they never write those keys. What a share string
makes is written by `Library.Import` alone: fresh ids, the order lists, the references remapped (a
parent is kept only when the string carries it and it is top-level there), and the surfaces'
fields through the seam (`modules/Share.lua` only decodes and checks). The shipped sets
(`NS.BuiltIns`) are seed data: each profile is given them once as ordinary user groups and callouts
under fresh ids, a battleground's nodes as groups inside its set, each seeded member keeping its
shipped id as `origin` (neither a tag nor a lock; only Library reads it: Restore) and a node its compass
wind; `profile.seededSets` records the shipped sets and nodes the profile was given. Restore
built-in groups (`Library.RestoreBuiltins`, one act) puts back, as fresh members, every seeded set,
node and callout whose origin the profile no longer has, and changes nothing the player has. The
load pass is `Library.Prepare`: `OnInitialize` and `reloadProfile` run it after `RunMigrations`; it
makes the default pad and dial once and then seeds the sets into them, seeds a set a later version
ships at the end of every pad and dial (a node shipped after its set goes inside the set's group),
never seeds again a set the player deleted (that is Restore's), normalizes malformed shapes, drops
dangling ids, malformed glyph colors and a parent that breaks the one-level rule, takes any child off
every surface, and keeps the ownership rule: a callout a second group holds is replaced there by a
fresh copy, and a callout no group holds is deleted, each counted as a repair. `Library.Import`
does the same for a string (one copy per group, a loose callout left out and reported).

**Named non-setting state:** the pad's active tab and collapsed state are session-only (`NS.State`).
Whether `/qc toggle` hid the Comms Pads is per character and saved: `db.char.padsHidden` (AceDB's
`char` section, `defaults/Profile.lua` `CHAR_DEFAULTS`), so a /reload or the next login restores it
and a profile switch leaves it alone.
The editors' selection (`NS.State.editing`; no callout is ever selected) and the When editor's open
drawers (`NS.State.whenOpen`, per group) are session-only. So is the edit preview
(`NS.State.editPreview`, the group the Groups page shows alone on every pad and dial while Preview
while editing is on; `behavior.previewOnEdit` is the saved switch). The callout popup's draft is local to
`settings/CalloutPopup.lua` and dropped whenever the popup closes. The icon browser's open request,
its tab, filter, selection and color are local to `settings/IconBrowser.lua` and dropped whenever it
closes; its search text is local there too and kept for the session; its game icon lists are kept for the session once the client answers with icons. The Share page's session state, `NS.State.share`: `pick` (the members ticked for
export, per kind) and `import` (the last checked string's result); a profile switch clears both, and
neither is ever saved.

## Message Bus

`core/Bus.lua` declares the catalog once, `NS.MSG`, as `Ka0s_QuickComms_<Event>` wire names with one
named sender each. With LibKa0s-Bus present the table is the strict `Catalog` copy, so a mistyped
key raises. Receivers take their own `NS.Bus:NewTarget()`; `NS.StandDown` / `NS.StandUp` take every
tracked registration down and replay it.

| `NS.MSG` key | Wire suffix | Sender | Payload | Consumers |
|---|---|---|---|---|
| `PROFILE_CHANGED` | `ProfileChanged` | `core/QuickComms.lua` `reloadProfile` (every AceDB profile event) | none | Surfaces (`Request`, after dropping the queued `surfaces` and `positions` entries; a held drag's stop stays); the editor pages (`settings/Editors.lua`, one deferred repaint); the icon browser (closes as Cancel) |
| `SITUATION_CHANGED` | `SituationChanged` | `modules/Situation.lua`, only when the signature moves | snapshot, previous | Surfaces (`Request`); the editor pages (`settings/Editors.lua`, one deferred repaint) |
| `RESTRICTION_CHANGED` | `RestrictionChanged` | `modules/Restrictions.lua`, when the set of blocking reasons (combat included) moves | reason, canSendChat | Situation (merges lockdown and combat into the snapshot in place); Surfaces (`RefreshLocks`: padlocks, the lockdown chip, the fade); Preview (ends test mode, Preview as and the edit preview at the combat edge); the Groups page (`settings/Groups.lua` `SyncEditPreview`: the edit preview back once combat ends, while the page is on screen); Pad (ends a drag at the combat edge); SendEngine (drains the combat-end queue) |
| `LIBRARY_CHANGED` | `LibraryChanged` | `modules/Library.lua`, on every registry write, and `Library.Touch` for every member row the seam writes; inside `Library.Batch` (New group, OfferGroup, Restore built-in groups, a Parent group write and the surfaces it leaves, an icon with its color, the callout popup's Save, a page's Defaults, an import) one per act, its kind the kinds touched joined by commas, with no id and no field | kind, id, field | Surfaces (`Request`); the editor pages (`settings/Editors.lua`, one deferred repaint); the icon browser (closes as Cancel when its opener's member is gone) |
| `ACTIVE_GROUPS_CHANGED` | `ActiveGroupsChanged` | `modules/Surfaces.lua` `ApplyAll`, when a pad's or a dial's ordered active groups change | surfaceId (a pad's or a dial's) | none (Surfaces rebuilds pads and dials itself) |
| `SURFACE_REBUILT` | `SurfaceRebuilt` | `modules/Surfaces.lua`: `true` when a rebuild is held for combat, `false` when it ran | surfaceId (a pad's or a dial's), stale | none |
| `SEND_RESULT` | `SendResult` | `modules/SendEngine.lua`: `guarded` at the press, then `sent` or `dropped` from the echo, so one press can yield two | calloutId, surfaceId, result | `modules/Pad.lua` (the flash, the sound); `modules/Dial.lua` (the wedges' flash) |
| `COMBAT_QUEUE_DRAINED` | `CombatQueueDrained` | `modules/SendEngine.lua` `Drain` | count | `modules/Surfaces.lua` (clears the stale hints) |
| `TEST_MODE_CHANGED` | `TestModeChanged` | `modules/Preview.lua` `SetTestMode`, `SetPreviewAs` and `SetEditPreview` | on (test mode, Preview as… or the edit preview) | `modules/Surfaces.lua` (`Request`, and opens dial 1); the editor pages (repaint) |

## Slash Commands

`/qc`, alias `/quickcomms`. The reserved verbs (`help config enable disable lock unlock version list
get set reset resetall profile debug diagnostics perf`; `lock` and `unlock` are slash-commands-§8's,
the Lock frame row's path through the seam) and the feature verbs `check <id>`, which prints the
line a callout would send under the current situation and never sends, `test` (test mode), `toggle` (hide or show every Comms Pad, remembered per character in `db.char.padsHidden`, also the launcher's Show window entry), `preview` ("Preview as…") and `why` ("Why is this showing?", for every built pad and dial). The full table, the live-while-disabled set
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

Every secure rule lives in one file. `modules/SendEngine.lua` is the only code that creates a frame from a `Secure*` template, calls `SetAttribute` or registers a state driver; `tests/test_sendengine.lua` greps every other shipped file for `Secure*Template`, `SecureHandler`, `SetAttribute` (called or named as a string), the state-driver and override-binding calls, and for `SendChatMessage` (D12: the secure button is the one send path). Send buttons are `SecureActionButtonTemplate`, named `QuickCommsSend<n>`, registered for `AnyUp` and `AnyDown`, armed with `type=macro` and one baked `macrotext` line, and only out of combat (`InCombatLockdown()`, events-frames-taint-§2). A pad's root becomes protected in combat because its buttons are secure: its visibility is a `visibility` state driver, and its geometry is set only out of combat, through `RunOrQueue` (rebuilds, which also re-anchor it from the active profile, the end of a drag, Reset position). A rebuild asked for in combat is filed in SendEngine's keyed combat-end queue (one entry per key, the last write winning) and drained at `PLAYER_REGEN_ENABLED`, which `Restrictions` owns and hands to `SendEngine.Drain`, and on any later `RESTRICTION_CHANGED` out of combat. The click hook is an insecure `HookScript("OnClick")`: it cannot cancel the secure click, so the spam guard is soft (spec §9.2), and it never reads chat text. A stand-down in combat holds its secure half in one private `PLAYER_REGEN_ENABLED` registration, released when it fires. Tabs and collapse are refused in combat. The Comms Dial (Relaxed mode) is one `SecureHandlerClickTemplate` header per dial, `QuickCommsDial<n>`, created by SendEngine; its ring containers are `SecureFrameTemplate` frames, its wedges are send buttons, and each ring's two page arrows are send buttons that never arm, wrapped by the arrow snippet (a left click shows the page before or after, or does nothing at an end). `modules/Dial_Secure.lua` holds the header's restricted snippets as text and hands them, every attribute and every frame ref to SendEngine out of combat; the snippets themselves write no attribute (the ring on screen is a global in the header's restricted environment; `tests/test_dial_secure.lua`'s firewall case checks the snippet text, and the firewall grep, whose list now includes a header's `SetFrameRef`, `WrapScript` and `Execute`, covers the file). In combat only the snippets act: they show and hide the rings and the hub, anchor the hub at the cursor, and bind Escape, the wheel, 1–8 and (on a paged ring) the Left and Right arrow keys with `SetBindingClick` while the dial is open from its key, releasing them with `ClearBindings`; an open from the insecure side (test mode, Preview as…, `qc-display`) binds nothing. Each wedge's click is wrapped by the header before SendEngine hooks it (the client's wrap replaces the script, which would drop an earlier hook); a wedge acts on the up edge and only a left click (or a catcher's forwarded `w<n>`) is a press. Since the dial polish (2026-10-21) a wedge takes no mouse (`EnableMouse(false)`, set at a rebuild out of combat; `Dial_Layout.HitSize` and the hit insets retired): each ring has one secure catcher button over its disc (`SendEngine.NewDialCatcher`, a `SecureActionButtonTemplate` registered for `AnyUp` only), whose header-wrapped pre-click snippet reads the cursor with the restricted `GetMousePosition`, works out the slice from the ring's `qc-size`, `qc-start`, `qc-hub` and `qc-disc` attributes (written by `DS.Load` out of combat, the math of `Dial_Layout.SliceAt`) and returns `w<n>`, which the catcher's `*type-w<n> = click` and `*clickbutton-w<n>` forward to that wedge (the any-modifier form: with Shift, Ctrl or Alt held the client reads `shift-type-w<n>` and then `*type-w<n>`, never the plain key, so a modified click still sends); inside the hub's circle (`Dial_Layout.InHub`) the snippet runs the header's `qc-up` snippet (up a ring, or close on the first ring; the header's own left click runs it too) and returns nothing, any modifier held; an empty place or past the rim returns nothing. The header itself takes no mouse (`EnableMouse(false)`, set at a rebuild out of combat; round hub, 2026-10-21): it is a square button and the hub is drawn round, so the catcher, centered on the hub, is the only mouse target there and the hub starts and ends at its circle in every direction; the keys still click the header by name (`SetBindingClick`, `CLICK QuickCommsDial<n>:Toggle`). Each header also has a hidden full-screen catcher (`SendEngine.NewDialScreen`, a child of the header set over `UIParent` in the HIGH strata, `AnyUp`): the header's show snippet shows it on a key open (never on an insecure open) and the close snippet hides it, so any click outside the dial runs `qc-close` and does nothing else. The slices, the lit slice, the page row, the pointer and the tooltip's place are insecure textures and anchors on the ring containers and the header (`modules/Dial_Slices.lua`, `modules/Dial_Render.lua`); the hub's backdrop and circle and the pointer sit on a plain, mouse-off front frame whose level is raised over the rings (an insecure call). The lit slice follows the cursor's bearing from the hub in the pointer's per-frame update, and the hub's hover (its circle brightened, its "Why is this showing?" tooltip) follows the cursor inside the hub's circle in the same update (`DialRender.HoverHub`, no header `OnEnter`), so both work in combat with no protected call. The dials' keys are WoW's own key bindings of the `CLICK QuickCommsDial<n>:Toggle` entries, set only in Options → Keybindings (the Dial page's Binding tab retired in the dial rework, 2026-10-21); `Dial.KeyOf` reads one through `Compat.BindingKey`. No override binding is made, so a stand-down or a rebuild leaves them alone. `Bindings.xml` adds those entries and `CLICK QuickCommsTogglePads:LeftButton` (Toggle Comms Pads) to WoW's own key bindings menu; its labels are client-read globals: the header declared in `.luacheckrc` `globals`, the five entry labels (not identifiers) set with `rawset` (the four dials' in `modules/Dial.lua`, Toggle Comms Pads' in `settings/SlashVerbs.lua`). Opening the settings panel stays refused in combat by the options library, and the callout popup is locked with it: its ctx is a panel ctx, so the library's combat cover lies over its page and refuses Save and every draft write; Escape and the window's close X (outside the page) still cancel. The icon browser is locked the same way (its ctx is a panel ctx too) and refuses Choose in combat, so nothing it picks is written in combat. The popup's window and the icon browser's are Blizzard's `SettingsFrameTemplate` (`settings/ModalWindow.lua`), an insecure template with no protected child, each built on its first Open; the browser sits in the `FULLSCREEN` strata, above the popup's `DIALOG`, and its swatch raises Blizzard's own `ColorPickerFrame` (AceGUI's ColorPicker widget) above it. While the browser is open the popup's name is taken out of `UISpecialFrames` (put back on the next frame after the browser closes), so Escape closes the browser only. The EllesmereUI skin paints only those two windows with alpha-only primitives, never another Blizzard frame. The editor pages touch no frame of a pad: every write reaches a pad through `LIBRARY_CHANGED` → `Surfaces.Request`, so a write made in combat (a CLI `set`, a popup accepted after the pull) waits for combat end behind the stale hint. Sharing writes no frame. An export reads the profile and shows a plain copy window; an import is data, written by `Library.Import` through the seam, and reaches the surfaces as any write does (`LIBRARY_CHANGED` → `Surfaces.Request`, queued in combat behind the stale hint). Both acts also refuse in combat. Nothing in a share string is executed: every text field is sanitized when it is checked, and `Bake` refuses a leading `/` again at every bake. The Icons tab's border frame and LibCustomGlow-1.0's effect frames are plain (unprotected) children of a button's or a wedge's icon: made out of combat at a rebuild, they can be shown, anchored and animated in combat, so a hover or an After sending glow starts and stops in combat with no protected call (`tests/test_glow.lua` checks the mock's refusal list stays empty); an Icons tab write changes button geometry (the icon size), so it reaches the surfaces through the rebuild, queued behind combat like any write. `modules/Glow.lua` resolves the library at call time and draws nothing without it. A pad's section titles each carry a plain (non-secure) hit frame, a child of the pad's root made, placed and sized at a rebuild out of combat; its right-click reaches `QC:EditGroup`, which in combat opens nothing and prints the settings refusal. The PREVIEW and TEST MODE marker is the drag strip's label text, set at a rebuild; the strip is not protected.

## Known Limitations

- The spam guard is soft: insecure code cannot cancel a secure click, so a press inside the window still reaches the game. A boss may drop it; the echo tracker then reports the drop (spec §9.2, the C5 upgrade).
- Another player's message on the same channel can mask a drop, and an unreadable sender counts as the player's own echo (spec §9.3, C6).
- In combat a rebuild waits for combat to end: buttons keep the lines baked at the last rebuild out of combat (a stale `/p` after leaving a group, spec §18).
- Disabled in combat, a pad stays on screen, and its buttons still send, until combat ends and the held stand-down finishes. Those presses are not tracked: no guard, no echo timer, no note.
- The mouse wheel over a pad belongs to the pad (spec §10.2): with groups as tabs it switches the tab, otherwise it does nothing there, so the camera does not zoom while the cursor is over a pad.
- Rebuilding between pulls inside a key assumes `SetAttribute` works out of combat in a key (C4, unverified).
- A member row written from the CLI addresses the member its page has selected, else the first that page lists; the echo does not name which member it was. A callout row is the exception: it names its callout by id.
- A `/qc set` to the callout the popup has open is not merged into the draft: Save writes the fields the draft changed, measured against the values the popup opened with, so it overwrites the slash write on those fields and keeps it on the rest.
- The Midnight dungeon and raid ids, spec 1480 and the battleground ids are matched against the client's data tables and confirmed in game by smoke checks IDS-1 and BG-2 (2026-10-21); Sporefall (1592) is left out (owner ruling R4). So are the When editor's place lists (`defaults/GameIds_Instances.lua`: every journal dungeon and raid, every arena less two legacy copies), checked by IDS-1.
- Two journal instances share a client name with another map (Blackrock Depths 230 and 2792; Magisters' Terrace 585 and 2811): a typed name for the first pair is refused as ambiguous (pick it from the suggestions, or type the id), and for the second the season's 2811 wins.
- The Comms Dial is Relaxed only: the hold, flick and release dial, its draw delay and tap action wait for C7 (spec §11.2).
- A slice clicks anywhere from the hub's circle to the rim through the ring's catcher, and the hub clicks inside its circle through the same catcher (the header takes no mouse, so the hub is round like its drawing; `Dial_Layout.InHub` and `Dial_Layout.SliceAt` are the one rule the tracker and the catcher share), which reads the cursor with the restricted `GetMousePosition` (dial polish, 2026-10-21): that API was the C7 item the go/no-go record never verified, and DIAL-28 passed in game on 2026-10-21, the in-combat click and the hub's included (the fallback it kept in reserve was forwarding tiles). A point in a slice gap belongs to the slice whose bearing it is in.
- While a dial is open from its key, its full-screen catcher takes every click outside it (it closes the dial and does nothing else), so a world click or an action-bar click needs a second press.
- A dial whose groups are all inactive opens nothing when its key is pressed (there is no empty ring).
- A dial's key belongs to its place in the dial order, not to the dial (2026-10-20): it is WoW's binding of Open Comms Dial <n>, so deleting or reordering dials hands a key to the dial that takes the place, and a dial past the fourth place has no key. The key lives in WoW's bindings, not the profile: a profile switch, copy, reset or share string never moves it, and a stand-down or a disabled dial leaves it bound and opening nothing rather than giving it back to the game. It is set only in Options → Keybindings, which the game itself keeps out of combat.
- The Toggle Comms Pads binding and the dials' entries are CLICK bindings on buttons registered for the down edge; a plain (insecure) button's CLICK binding fires on the key press (KEY-3 passed, 2026-10-21).
- The Buttons tab's glow has no trigger: it is on around every button while enabled, at the Icons tab's knob defaults (only its style and color are settings).
- Open at the cursor relies on the restricted `SetPoint` accepting `$cursor` (DIAL-7 passed, 2026-10-21); the fallback, if a patch breaks it, is opening at the dial's place.
- A dial closes on a send, so its guard dim and its drop flash show only on the next open: the dim for the guard window, a drop's red for 5 s; the chat note reports a drop either way.
- Disabled in combat, a dial keeps working (and its key keeps opening it) until combat ends and the held stand-down finishes.
- Test mode or Preview as… ended by a combat whose lockdown began first leaves dial 1 open, its placeholder wedges sending nothing and holding no key, until combat ends (the hub or its key closes it sooner).
- Battleground node sets are pinned to compass winds derived from the client's map data, not yet checked in game (smoke check BG-1); Flat mode is not pinned.
- Alterac Valley's 19 objective groups cannot sit on the eight compass winds, so its dial ring is unpinned and paged: its own four callouts first, then the objectives north to south a few wedges a page, turned by the arrows under the dial (six pages on a four-slice dial, three on Auto). Its pad sets the objectives two to a row, still about 560 px tall beside the generic set on a default pad; groups as tabs, or switching the generic set off, shortens it (smoke check BG-3).
- A battleground's objective groups have no faction condition (owner ruling, 2026-10-20): "Our base" and "Enemy base", "Our flag" and "Enemy flag" read the same for either side, so nothing names Alliance or Horde, and a group is not hidden for the side it does not fit. Seething Shore's groups are the node in front of you and the next spawn, not its dozen sites, because its azerite erupts at random among them.
- Silvershard Mines' and Temple of Kotmogu's groups take free winds (bg buttons, 2026-10-20): the client's AreaPOI table holds no point on the mines' map and does not tell the orbs' colors apart, so nothing pins them. The mines' tracks are named Lava, Water and North as players call them, not from client data (smoke check BG-8).
- In Group (party, raid or instance group, no content condition) is active in every dungeon, raid and battleground beside the content's own set, and it is always on the pad there. It ships last, after the generic battleground set, so a content set stays the first active group on the pad. On a dial it is one more group (the dial rework retired Skip on the dial in content, 2026-10-21): with the content's set active too, a dungeon, raid or battleground dial opens on the ring of groups, so a battleground's node callouts sit three rings deep (groups, the set's nodes, a node's callouts).
- A grid pad packs a parent's child sections side by side only while consecutive ones fit its columns; a lone or wide child keeps a row of its own, and horizontal and vertical pads never pack.
- The Profiles page builds only where AceDBOptions and AceConfigDialog resolve, which the headless
  mock does not model; PROFILE-1 is its in-game check.
- A share string carries at most 500 members and 50,000 characters; a larger collection is shared in parts.
- A hostile share string can still make the client inflate up to about 25 MB once when Accept is clicked (LibDeflate has no output cap, so the 50,000-character limit bounds the input, not the output); that is a hitch of about a second, after which the string is refused as damaged because its payload is over 512 KiB, and nothing reads it.
- An imported callout's text is limited to 255 bytes, while the editor's Text box counts 255 characters: a non-Latin text the box accepts can be refused on import, and could never have baked.
- Midnight's Slayer's Rise (map 2799) has no battleground set of its own; the generic set covers it.
- The shipped raids are the current tier's three; a later tier joins `defaults/GameIds.lua` when it is current (the When editor adds the instance you are in meanwhile).
- Node winds come from the client's map data as of build 12.1.5.70340; a battleground a patch redraws needs its winds re-read (`docs/common-tasks.md`).
- `tests/perf.lua`'s byte ceilings are the headless mock's figures (its catch-all methods allocate per call); compare them run to run, never with the client.
- The callout popup has no scrollbar: its window is as tall as its content, so on a screen too short for it (a very large UI scale) it runs past the top and bottom edges, Cancel and Save included; Escape still cancels.
- The callout popup's EllesmereUI skin follows EllesmereUI's third-party switches (its third-party skinning and Quick Comms' entry in its Third-Party Addons list) and its third-party style, a majority vote over all its window styles. It does not follow EllesmereUI's Settings-window skin or its window-skin kill switch, which the public API does not expose. So the popup can differ from the settings window behind it: with window skins killed or the Settings window skin off, the popup wears EllesmereUI's shell over a stock settings window; with the settings window on one style and most windows on the other, the two backdrops differ.
- The callout popup's EllesmereUI skin (and the icon browser's, the same skin on the same window) is one-way, as EllesmereUI's skins are: turning it off in EllesmereUI takes effect after a reload. It is painted whether or not Quick Comms is enabled: both windows belong to the settings panel, which stays up while the addon is disabled (slash-commands-§7, "What MUST survive"); until 2026-10-18 a disabled addon left them stock. A client without `SettingsFrameTemplate` gets the popup's older look (a plain frame with Blizzard's dialog edge and the shared close mark) instead of the settings window's, and the EllesmereUI skin leaves that fallback window as it is.
- The icon browser searches game icons by texture id only: the client gives them as texture ids, with no names, and has no API that names one, so a game icon is named by its id and a name is looked up on Wowhead (the tab's hint; the game cannot open a web page, so the address is shown to copy). No icon name table is shipped. Its game icon lists are read once the client has loaded its own; on a first open before that the Game icons tab says so and fills on a later visit.
- A glyph's color applies to LibKa0s glyphs only (white on transparent); a raid marker, a game icon or a typed texture is drawn as it is, and choosing one clears the member's color.
- Inherit when conditions is all or nothing: an inheriting group takes its parent's whole When, with no way to add a condition of its own on top (untick it to set its own instead). A group stored before the setting reads as inheriting; `/qc get group.inheritWhen` prints nil for it until it is written.
- Groups nest one level only: a group inside another cannot hold groups, and a group that holds groups cannot go inside another. A group's children are drawn, listed and offered in the order they were made in; there is no control to reorder them yet.
- A battleground set's ring is pinned to the compass winds only while every group inside it is a seeded node (the wind is not a member field) and a wind is left free for the set's own callouts (its map-wide ones, which take one wedge on the first free wind): a group the player puts inside it unpins the ring, and a set that arrives in a share string brings its nodes unpinned.
- Restore built-in groups puts back only what is missing (a seeded set, node or callout no member keeps the origin of); it never resets a seeded group the player changed. To get a stock set back, delete its group and restore. A copy (Duplicate, Reuse, an import) keeps no origin, so it never stands in for the stock set.
- A pad's saved point is read as its growth edge's (its top for down growth, its bottom for up growth, B2). Before 2026-10-19 a saved point named whatever point the client returned, and a never-dragged pad's default `CENTER 0 -150` was its center's; such a pad moves once on its first load, by half its height or its whole height; a drag saves the edge point and it stays put from then on. No migration converts the old point, which would need the pad's drawn height (the addon is unreleased, so only pre-release profiles carry one).
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

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `standalone-windows`, `library-stack-§8` | One wrapper, and every close control goes through it: the callout popup, and the icon browser built from the same window (`settings/ModalWindow.lua`, since 2026-10-18), close with the X of Blizzard's `SettingsFrameTemplate` (`ClosePanelButton`), not with `NS.MakeCloseButton`; its click is a Cancel. The wrapper stays in `core/CoreSetup.lua`, because the same section requires it, and the fallback window (a client without the template) still draws the shared mark through it, so `grep -rn 'MakeCloseButton(' --include='*.lua' \| grep -v '/libs/'` returns the wrapper's definition and calls to `NS.MakeCloseButton` (the fallback window in `settings/ModalWindow.lua` and `tests/test_setup.lua`), and nothing else | The popup is built from Blizzard's `SettingsFrameTemplate` to match the settings window exactly, and that template brings its own close; the browser reuses the popup's chrome; decided by the owner | 2026-10-17 | The standard ruling on Blizzard-template windows, or the popup and the browser leaving the template |
| `standalone-windows` | The window edge: the callout popup's edge and frame, and the icon browser's (the same `settings/ModalWindow.lua` window, since 2026-10-18), are Blizzard's `SettingsFrameTemplate` (its NineSlice and `Bg`), not the Ka0s window edge through `ApplySkin`; on a client without the template, the fallback window uses the `UI-DialogBox-Border` backdrop | Built from Blizzard's settings template so the popup matches the settings window exactly, as the owner asked; the browser reuses the popup's chrome (icon browser spec); decided by the owner | 2026-10-18 | The standard ruling on Blizzard-template or modal windows, or the popup and the browser leaving the template |
| `localization-§1` | The icon browser's Glyphs tab labels (`settings/IconBrowser_Sources.lua`, `Src.GlyphLabel`) are derived from the LibKa0s catalog keys and are not routed through `NS.L` | The catalog keys are data that change with the library, and enUS is the only locale; decided by the owner | 2026-10-18 | The first non-enUS locale file, or LibKa0s publishing icon labels |
| `testing` (the vendored kit owns the AceDB fake) | `tests/run.lua` wraps the kit's AceDB fake once per load to add AceDB's `char` section (`db.char`, the SavedVariables root's `char["Tester - Realm"]`, filled from the `char` defaults), and `bootAddon` takes `opts.sv` to replay a saved root as a /reload would | The kit's fake (`tests/_kit/mock_record.lua`) models only `profile` and `global`, and the Comms Pads' hidden state is genuinely per-character (`db.char.padsHidden`); `tests/_kit/` is never edited here | 2026-10-21 | A kit revision whose AceDB fake models `char` (then drop the shim and re-vendor) |

### Files over the 1500-line cap

The layout-§1 census of authored `.lua` files over the 1500-line cap. Vendored code (`libs/`,
`tests/_kit/`) is out of scope; the generators under `tools/` are authored Python, under the cap, and
the repository has no generated data file.

Nothing is over the cap today.
