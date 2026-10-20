# Settings panel — Ka0s Quick Comms

Built on LibKa0s-Options from the descriptor in `settings/OptionsSetup.lua`. The category registers
eagerly at `OnEnable`; each page's body builds on its first show (options-ui-§1/§5).

| Page | Covers |
|---|---|
| Ka0s Quick Comms (landing) | The logo, the TOC notes line and the slash command list, drawn by the library's `BuildLandingPage` |
| General | `Master controls`, `Behavior` |
| Groups | One group (a seeded built-in set is one too): `General`, `Callouts`, `When`, `Preview` |
| Comms Pad | One pad: `General`, `Groups`, `Layout`, `Window`, `Chip`, `Icons` |
| Comms Dial | One dial: `General`, `Groups`, `Wheel`, `Icons`, `Binding`, `Preview` |
| Share | `Export`, `Import` |
| Profiles | AceDBOptions: switch, copy, reset and delete profiles |

## General → Master controls

Composed by `Helpers.MasterControls` from one declaration (`settings/Panel.lua`), canonical rows in
canonical order (options-ui-§15). The Comms Pad is positionable, so the block is the full framed
set, in order: Enable, General visibility, Master scale, Master alpha, Lock frame, Debug console,
Minimap button, Test mode, then the block's one extra row, Preview as, then the Reset position and
Reset all settings buttons.

| Left | Right |
|---|---|
| Enable Ka0s Quick Comms (`enabled`) | General visibility (`visibility`) |
| Master scale (`scale`, 0.5-2) | Master alpha (`alpha`) |
| Lock frame (`locked`) | Debug console (`state.debugConsole`, session) |
| Minimap button (`global.minimap.shown`) | Test mode (`state.testMode`, session) |
| Preview as (`state.previewAs`, session; its own line) | |
| Reset position (button: every pad and dial back to its default place, one chat line) | Reset all settings (button, asks first) |

Lock frame, `/qc lock|unlock` and the launcher's Locked entry write the same path; Test mode,
`/qc test` and the launcher's Test mode entry call the same switch (`Preview.SetTestMode`), which is
refused in combat. The launcher's Show window entry and the Toggle Comms Pads key binding (Options →
Keybindings → Ka0s Quick Comms) call `/qc toggle`'s handler (`SlashVerbs.TogglePads`), which hides
or shows every Comms Pad for the session.

Preview as is passed through the composer's `extra` slot, so it lands after the canonical rows and
before the button pair, never among them: options-ui-§15 as amended in v2.84.0 sanctions that slot
for page-wide host rows. It draws every pad, and opens dial 1, as another situation would (nothing
sends); `/qc preview` writes the same session row, and the page follows it (`Preview.announce`
repaints). It is page-wide, so no editor page draws it, and no page's Defaults reaches it; Reset all
settings ends it with the other session rows.

Every row writes through the one seam (`NS.SchemaRuntime.Set`), and its reaction is the same one
the CLI, the launcher and the host verbs trigger (`Settings.REACTIONS` in `settings/Schema.lua`).
The header's Defaults button and Reset all settings both open the confirmation popup; the global
reset is a profile reset and never touches the minimap button (options-ui-§12, launcher-§3).

## Groups

`settings/Groups.lua`, one group at a time. Every group draws the same tabs: a seeded built-in set
is an ordinary group (2026-10-18-builtins-as-groups-design.md), with no tag, no lock and no
read-only branch.

```
band      [ Group v (picker; a green dot after its name marks a group active now; a group inside another is
          listed, indented, right after it) ][ New group ]
          [x] Preview while editing (under the picker)
strip     [ General ][ Callouts ][ When ][ Preview ]
General   Name, Enabled, Open the dial on this group, then
          Parent group (None, or a top-level group) beside Inherit when conditions (grayed out
          with no parent), then the icon under an Icon label with Choose icon…, the clear glyph
          and its color swatch (settings/Editors.lua's chooser, no Icon text box), then
          Duplicate and Delete, then Restore built-in groups (page-wide)
Callouts  Add callout (the callout popup, blank; across the row), Reuse callout
          with Add at the right edge (both 2px short of it), then its callouts as a drag-to-reorder list, each row the handle,
          the icon (the question mark when none), the name in gold, the channel's short label in
          its chat color (a smart kind resolved against the snapshot; PARTY's when solo) and the
          text in muted white cut at 40 characters with "…", then an edit glyph and a remove glyph
          at the right edge
When      settings/Groups_When.lua
Preview   the active-now line, then a table: a gold header row (Callout, What it sends here), then
          one boxed row per callout, its icon and name beside its first preview line
```

**Parent group** (General, the `group.parent` row): a dropdown of None, then every top-level group
but this one, in the picker's order. A group inside another shows wherever that group is placed (a
pad draws a section for it, a dial a node ring), gated by its own Enabled and its When (its
parent's while it inherits, below), while the parent's gate the whole; it is never placed on a pad
or a dial itself, so picking a parent takes it off every pad and dial in the same act, and None does not put it back (Comms Pad → Groups → Add a
group does). Groups go one level deep: the dropdown is idle while this group holds groups, and its
tooltip names them. A group's children are listed in the order they were made in. Delete on a
parent asks first and says what happens: the groups inside it become top-level groups, in its place
on every pad and dial. Duplicate of a child puts the copy in the same parent (the chat line says
so); a parent's copy holds no children. The page's Defaults keeps the parent, as it keeps the icon.

**Inherit when conditions** (General, beside Parent group, the `group.inheritWhen` row): while it is
ticked, a group inside another is judged by its parent's When instead of its own
(`Resolver.WhenOf`); its own stored When is kept, unused, for when it is unticked. It is on for every
group, a seeded battleground node or one of yours, and a group stored before the setting (no field)
reads as on; unticking stores `false`. The box is grayed out while Parent group is None, since a
top-level group has no parent to take a When from. The Group picker's dot, the pad, the dial,
Preview as, the Preview tab and every "why" line follow it. A write repaints the page (the row is
structural), and the page's Defaults ticks it again. Tooltip: "Use the parent group's When instead
of this group's own. This group's own conditions are kept for when you untick it. Only a group
inside another group inherits."

**Restore built-in groups** (General's last row, page-wide, and on the empty "No groups yet"
General): puts back every shipped set, node and callout the profile no longer has, as new ordinary
members: a set at the end of every pad and dial, a node inside its set's group (while that group is
top-level), a callout at the end of its seeded group. It never changes, moves or overwrites what the
player has, so it does not ask first, and a second click adds nothing; one chat line says how many
groups and callouts came back, or that nothing was missing. There is no per-set reset to stock:
delete the group, then restore. It is not under the header's Defaults, which resets the selected
group (options-ui-§13).

**Preview while editing** (the band, under the picker, the `behavior.previewOnEdit` row; on by
default, saved): drawn through `O.PageHeader`, the band a picker with another page-wide control
takes (options-ui-§14), with New group level with the picker's control as PageBanner places it.
The three are one AceGUI SimpleGroup's children, laid out by Flow (the picker and New group each
half the band, the checkbox under the picker), so AceGUI shows and sizes them; widgets placed in
the header frame by hand drew only the picker's label in the client.
While the Groups page is on screen with it ticked, every enabled pad and dial shows only the selected
group, with the groups inside it, whatever their When and Enabled (`Preview.SetEditPreview`,
`Surfaces` `deps.only`): drawn and disarmed as a Preview as plan, `Preview: <group>` on the header,
dial 1 open. Clicking a chip or a wedge sends nothing and prints the line it would have sent
(`[QC] /p Pulling next pack`). It follows the picker, and ends when the page hides, the settings window closes,
combat starts (one "Preview ended" line) or the addon stands down; it never starts in combat,
and it comes back once combat ends while the Groups page is still on screen.
Preview as and test mode wait behind it and come back when it ends. The page's Defaults ticks it
again.

**Opened from a pad** (groups polish R4): right-clicking a pad's section title (in tabs mode, the
tab's title) runs `QC:EditGroup(gid)` (`G.Edit`): the page's own selection moves to that group, as
the picker does, so the tab the page was on stays (the library keeps a page's active tab for the
session), and the settings window opens on the Groups page itself (`Ed.OpenPage`, the host's
`Settings.OpenToCategory` wrapper on the page's category). In combat the window cannot open: the
library's settings refusal is printed and the selection is kept. A group the profile no longer has
(or test mode's placeholder groups, which draw no hit frame) opens nothing.

**Preview** (`Ed.TableRows`, shared with no other page yet): the active-now line, then a table. A
gold header row, "Callout" and "What it sends here", sits outside the boxes; each callout's row is a
box like the Callouts tab's (the same fill, border and left and right edges; a reorder list's row
with no handle), its icon (in its color) and name in a 220px cell, and its first preview line (what
it sends under the current or previewed situation, or why it sends nothing) filling the rest. A row
is never shorter than the Callouts tab's 30px and grows with a wrapped line, both cells centered in
it; it has its own AceGUI layout (`Ed.LayoutTableRow`), since AceGUI's Table does not set a filling
cell's text width before reading its height. A group holding groups shows a titled table for its
own callouts (when it has any), then one per child; a group with no callouts keeps the one line
"This group has no callouts yet." and draws no table. A situation change rewrites each row's text in
place and lays the page out again, so a row resizes. The bytes, the lock and the token notes stay in
the callout popup's preview.

**When** (`settings/Groups_When.lua`): the active-now line, then the gray line "Every condition you
set must match. A condition left as Any does not limit the group.", a row's gap, then one drawer per condition
(the library's `O.Drawer`, LibKa0s `OptionsDrawer.lua` since v1.73.0), in this order: Content,
Instance, Difficulty, Key level, Group, Leader or assist, Class, Specialization, Role, Character,
Battleground, Arena.

```
header   > Content                                                      Any
header   v Difficulty                                        Heroic, Mythic
drawer     [ ] Normal          [x] Heroic          [x] Mythic
           [ ] Mythic Keystone [ ] LFR             [ ] Story
           [ ] Follower
                                               [ Select all ][ Clear (Any) ]
header   > Key level                                               10 to 15
```

- **The header**: a chevron (right while closed, down while open), the condition's name (gold while
  it is set, white otherwise) and, at the right, a summary on one line: "Any" in gray while unset,
  else the chosen values in list order, comma-separated and cut with an ellipsis; an id list names
  its one entry or counts several ("2 instances", "2 battlegrounds", "2 arenas", "2 characters"), or
  reads "All dungeons and raids" / "All battlegrounds" / "All arenas" while its whole-kind checkbox
  is ticked; the key level
  reads "10 or higher", "15 or lower", "10 to 15", or "12" when both ends are equal. Hovering it
  shows the condition's tooltip. A click opens or closes its drawer (refused in combat).
- **The drawer**: a box joined under the header (the header's bottom corners square off and its
  edge goes gold while it is open), its rows lined up under the condition's name. Content,
  difficulty, group, leadership, class, specialization (the classes picked, else the player's) and
  role are checkboxes in three columns; the key level is a Lowest and a Highest box; instances,
  battlegrounds, arenas and characters (`Name-Realm`) are the library's IdList, each with an
  add-the-one-you-are-in button, which reads where the player is at the click and says so when that
  is nowhere; a typed id is a positive whole number, and a typed character takes the client's case
  (`bob` reads `Bob-<your realm>`). The Instance list suggests and names every Encounter Journal
  dungeon and raid (`NS.GameIds.INSTANCES`, so Murder Row as well as the season's), the Arena list
  every arena (`NS.GameIds.ARENAS`), the Battleground list the shipped sets' maps; a name two maps
  share is refused (pick it from the suggestions, or type the id), except that the season's dungeon
  or raid wins on the Instance list.
- **The whole-kind checkbox**, on top of the Instance drawer ("All dungeons and raids": any dungeon,
  Mythic+ key or raid), the Battleground drawer ("All battlegrounds": any battleground) and the Arena
  drawer ("All arenas": any arena). While it
  is ticked the list and its buttons under it are drawn dimmed and inert, and keep their entries,
  unused, for an untick; it stores `all` in the row beside the ids (`Resolver.ALL`), which
  `/qc set group.when battleground all` types too. The Character drawer has none: every character
  is what Any already means. Clear (Any) unticks it with the rest.
- **Select all and Clear (Any)**, right-aligned under the choices: Select all (checkbox conditions
  only) ticks every value the drawer lists (the specialization row, the specs it offers); Clear (Any)
  unsets the condition and leaves the drawer open. Both read the profile at the click.
- **No enable checkbox**: a condition is set while it has values. Drawers start closed, a set
  condition's too (its summary says what is set), and several can be open at once; which are open is
  per group and per session (`NS.State.whenOpen`): it survives the repaint a write brings and
  switching groups, and a profile switch closes them all.
- **An inheriting group** (Inherit when conditions, above) shows its parent's conditions here,
  read-only: the active-now line, then the muted gold line "Uses <parent>'s conditions. Untick
  Inherit when conditions on the General tab to set this group's own.", then the gray line, then the
  parent's When in the same drawers. They open and close (the open set is this group's own), the
  choices are grayed out, and there is no Select all or Clear (Any).

A refused key level or X/Y offset prints its reason and the box goes back to the stored value; a
refused Name (any field the library draws) prints its reason too. A seeded set's When is edited as
any group's.

**The icon** (General): under an **Icon** label, the icon as the pad and the dial draw
it (a glyph in its color, a question mark for none), **Choose icon…**, a **clear** glyph (the
`transmog-icon-remove` atlas, tooltip *Clear icon*) and the **Icon color** swatch.
There is no Icon text box: the icon is picked only here, and stored as a texture path or id
(`group.icon`, which `/qc set` still reaches). A
click on the icon or on Choose icon… opens the icon browser (below) over the settings window; its
Choose writes the group's icon and color as one act (`Library.SetIcon`), so a game icon or a marker
chosen over a colored glyph clears the color in the same write. The swatch opens Blizzard's color
picker and writes `group.iconColor` through the seam; it is live only while the icon is a glyph
(white is none). The color is drawn with the icon, never as a text box of its own. The clear glyph
is the one way back to no icon (the browser has no "none" cell): it calls the spec's choose with no
icon and no color, so the group's icon and color go as one act (`Library.SetIcon` with `false`); it
is idle while there is no icon. The callout popup draws the same chooser (`Ed.IconChooser`), where
the clear glyph empties the draft's icon and color and Save stores none.

**Callouts**: the group owns its callouts. Each user callout sits in exactly one
user group, so there is no Callouts page and no shared callout.

- **Add callout** opens the callout popup with blank fields (an empty name and text, Smart group,
  no icon). Save puts the new callout at the end of the group; Cancel makes nothing. The button
  spans the row (an AceGUI Table layout: a filling cell, then a 2px cell, `G.EDGE_INSET`), so it
  ends where Reuse's Add does, 2px short of the content's right edge: the scroll content fills the
  ScrollFrame's clip rect exactly, and options-ui-§8 insets a cell-filling button so its right
  border is not shaved.
- **Reuse callout** is a dropdown of every callout the player could copy, each as
  `<group>: <callout>` (a group inside another as `<parent>: <group>: <callout>`, so two
  battlegrounds' same-named nodes read apart; a seeded set's callouts among them; there is no
  built-in section), less
  this group's own callouts, as one list sorted by group, then callout, ignoring case (on the
  plain text). A stock callout the player deleted comes back through Restore built-in groups, not
  here. The group part is drawn in a muted gold (`c9a66b`, LibKa0s' debug-tag tone), the
  callout's name in white; entries that would read alike are numbered (`<callout> (2)`). Picking
  alone adds nothing; **Add** puts an independent copy at the end of this group
  (`Library.AddToGroup` always copies), so editing the copy leaves the original as it is. The row
  is an AceGUI Table layout: the dropdown fills what a 6px gap cell, Add's fixed 120px cell and the
  2px inset cell (`G.EDGE_INSET`, as under Add callout) leave, and Add is 26px tall, the label-less
  dropdown's height. The gap is a cell rather than the layout's `spaceH`, which would also fall
  between Add and the inset cell.
- **The list** is the drag-to-reorder list (`Ed.ReorderRows`, shared with Comms Pad → Groups and
  Comms Dial → Groups). The edit glyph (the catalog's `edit` mark) opens the popup filled in; the
  remove glyph (the `transmog-icon-remove` atlas) asks first, then deletes the callout, since
  nothing else holds it. Both carry a tooltip. Each row is an AceGUI Table layout
  (`Ed.RowColumns`): the handle's gutter, the label filling what is left, a 24px cell per 16px
  glyph and a 3px pad, so the glyphs sit at the box's right edge (the last one's art 7px in).
  Every fixed column is an explicit `{ width = n }`, since the layout reads a bare number from 1 to
  under 10 as a weight;
  `Ed.RowAlignV` centers every widget in the 30px row.
- Delete (General) deletes the group's callouts with it, and Duplicate gives the copy copies of them.

## The callout popup

`settings/CalloutPopup.lua`: one callout of one user group, new or listed. It is not a page (no
sidebar entry, no banner, no Defaults). It looks like the settings window: the window is Blizzard's
own `SettingsFrameTemplate` (its background, its border with the window title "Ka0s Quick Comms",
and its close X), and inside it the pages' own building blocks draw the rest (the library's panel
factory for the header and its gold rule, the Helpers' rows and red button pair, `Ed.IconChooser`).
The window and its catcher are `settings/ModalWindow.lua`'s, which the icon browser is built from too.
The body is laid out in a plain AceGUI container, not a scroll frame: the popup has **no
scrollbar**, and the window's height follows the laid-out body, measured again after every draft
write, situation change and error line. The settings pages keep their always-visible scrollbar.
A client without the template gets the popup's old look: a plain frame with Blizzard's dialog edge
and the shared close mark (`NS.MakeCloseButton`). The template's own close X instead of the shared
mark is a documented deviation (`ARCHITECTURE.md` → Documented deviations). The window's border,
title bar and background come from the template, and its `Bg` is lifted over the click-catcher's dim (the
template declares it at absolute frame level 0), so the popup is as bright as the settings window.

```
window   Blizzard's settings window, titled Ka0s Quick Comms                 (its close X)
header   New callout / Edit callout, the gold rule under it
body     [Name          ] [Channel       ]   the callout.* member rows' labels and help
         [Text  (i)                       ]   across both columns; (i) is the token glyph
         Icon                                 the chooser's label
         [icon] [Choose icon…] [x] Icon color the icon as drawn, the button, the color swatch
         ---------- Preview ----------         the baked line and its bytes, or why it sends
                                              nothing, and any lock
         (a gap)
         [Cancel        ] [Save          ]
         the line that names a field Save refused
```

- **The layout.** Two columns, each the library's button-pair width (`Helpers.BUTTON_PAIR_REL` of
  the body, the width `InlineButtonPair` gives Cancel and Save, options-ui-§8), with the whole pixels
  the pair leaves (8 px) as the gutter between them: Name and Channel, the icon with Choose icon…
  and the clear glyph, and the swatch, Cancel and Save each fill one, so their outer edges meet the Text box's and the Preview rule's,
  and the right column starts at the same place on every line. The pair keeps its width; the popup
  only puts the gutter between its two buttons. The fields are
  drawn by the library's field maker (`RenderField`) into the popup's own lines, not by
  `RenderRows`' half-and-half lines, so the gutter exists. AceGUI draws an EditBox's box and a
  Button's art 2 px in from the widget's edges, so 2 px in is where every visible left edge sits:
  each field's label is moved 2 px in, the Channel dropdown's art 2 px left, the icon 2 px in, the
  Preview rule 2 px in from both sides (AceGUI's Heading draws it 3 in), and the preview and error
  lines 2 px in. Every anchor the popup moves is put back when AceGUI takes the widget back (an
  `OnRelease` callback per widget), so a pooled frame reaches another addon as AceGUI made it. The
  Preview heading keeps a section's gap above it (`O.Section`'s 10 px): the popup sets
  `ctx.lastGroup` to the fields' group after drawing them, as `RenderRows` would.
- **No Icon box.** The icon is chosen only with the chooser; the draft still carries it as a
  texture path or id, Save writes it to `callout.icon`, and that row still answers `/qc`.

- **The draft.** The popup edits a plain copy of the callout's four fields and its icon's glyph
  color (blank for Add). Choose icon… opens the icon browser over the popup; its Choose writes the
  draft's icon and color, the clear glyph empties both, and the swatch writes the draft's color.
  An icon that is no glyph drops the draft's color. Every control writes the draft, never the
  profile, and Preview bakes the draft, so it follows each edit before anything is saved. A text
  box commits to the draft on Enter
  (or its Okay button), as on every page; what a box shows that Enter did not commit is taken into
  the draft before any other draft write, before a seam write's refresh and by Save, so clicking
  Save commits it and a pick never wipes it.
- **The token glyph.** The library catalog's `info` mark, right of the Text label, as tall as the
  label's letters (its font's size, 10 to 12 px) and vertically centered on it. Its tooltip lists every token the
  draft's channel offers, one line each (`Settings.Callouts.TokenHelp`), read when it shows, so it
  follows a channel picked since: `{group1} … {group8}` is one line, only when the channel can
  resolve to Raid, and `{spell:ID}` is last. Tokens are typed into the text; nothing inserts them.
  The glyph is kept on the Text box's frame and reused, re-anchored on every render, and hidden
  when the box is released (an `OnRelease` callback, the library's landing-logo pattern), so a
  frame AceGUI hands to another EditBox never shows it.
- **Save** checks the draft with the member rows' own validators (the name, the text and its
  length, the channel, the icon, the icon's color). A field that fails keeps the popup open and names the field
  (an icon that is no texture names the chooser: "Icon: … Click Choose icon… and pick another.");
  otherwise Save writes one act (`Library.Batch`): for a listed callout, each field that differs
  from the copy taken when the popup opened, through the seam by id; for Add,
  `Library.CreateCalloutIn` at the end of the group. Then the popup closes.
- **Cancel**, the close X and Escape drop the draft and write nothing; so do the settings window
  hiding, a profile change, the stand-down, and the callout or its group ceasing to exist (a `/qc`
  write or an import under it), after which a late Save writes nothing. An icon browser opened from
  the popup closes with it, as Cancel.
- **Fully modal:** a full-screen click-catcher in the `DIALOG` strata covers the settings window, so
  the page underneath cannot change while a draft is open. Only one popup exists.
- **EllesmereUI.** With EllesmereUI and its Blizzard Skin module loaded, its third-party skinning on
  and Quick Comms on in its Third-Party Addons list (as the facade's `S.IsEnabled()` reports them;
  Quick Comms never reads EllesmereUI's SavedVariables), `settings/CalloutPopup_Skin.lua` paints the
  window in EllesmereUI's third-party look: its shell, the border faded, the background
  hidden and its close X; the page's controls stay stock, as the settings window's do. Quick Comms
  has no switch of its own for it: EllesmereUI's per-addon entry is the switch, and a skin comes off
  only with a reload. The fallback window (a client without the template) is not painted: the skin
  is the settings window's, and that window is not it. The skin does not wait for Quick Comms to
  be enabled: the popup and the browser are the settings panel's, which stays up while the addon is
  disabled (slash-commands-§7), so they open in EllesmereUI's look either way. `/qc diagnostics`
  says why the skin is or is not on (its `why=`, `docs/debug.md`).
  The skin follows EllesmereUI's third-party switches and its third-party style (a majority vote
  over all its window styles), not its Settings-window skin or its window-skin kill switch, which
  its public API does not expose. So the popup matches the settings window behind it only when
  EllesmereUI's Settings window skin is on and its style is the third-party style; otherwise the
  two can differ (a known limitation, `ARCHITECTURE.md` -> `## Known Limitations`).

## The icon browser

`settings/IconBrowser.lua`: where an icon is picked, opened by Choose icon… (or a click on the icon)
in the callout popup and on a group's General tab. It is not a page. Its window is the popup's
(`settings/ModalWindow.lua`: Blizzard's `SettingsFrameTemplate`, titled "Ka0s Quick Comms", its close
X, the gold header), 560 × 594, with its own full-screen catcher in the `FULLSCREEN` strata, above the
popup and the popup's catcher (`DIALOG`): it is modal to whatever opened it. Only one browser exists,
built on its first open. The EllesmereUI skin paints it as it paints the popup.

```
window   Blizzard's settings window, titled Ka0s Quick Comms                 (its close X)
header   Choose an icon, the gold rule under it
tabs     [ Markers ][ Game icons ][ Glyphs ]   (the library's tab strip)
toolbar  Game icons: Show (All / Spells / Items). Glyphs: Show (All / Open Iconic / Phosphor /
         Game-icons), then Icon color (the swatch). Then the search box (narrower on
         Glyphs; a magnifier inside its left edge, a clear mark at its right while it holds
         text). At the right, how many icons the tab holds, or "N of M icons" while a search
         narrows it.
grid     12 × 7 icons and a scrollbar, 10px under the toolbar; the mouse wheel scrolls it
hint     Game icons only: the search hint and Copy wowhead.com/icons, in a box under the grid
footer   the selected icon (a glyph in the color) and its name, then Choose and Cancel
```

- **Markers**: the eight raid target markers. **Game icons**: every
  icon the macro icon selector offers (the loose lists and then `GetMacroIcons` for spells, the
  same for items, through `Compat.MacroIcons`), as texture ids, each once, filtered All / Spells / Items; until the client has
  loaded its own icon list the tab says so, and the list is read again on the next visit. **Glyphs**:
  every icon of the LibKa0s catalog (`NS.IconNames`, about 5,800 marks in three sets: Open Iconic,
  Phosphor `ph:`, Game-icons `gi:`), named from its catalog key without the set's prefix
  ("arrow-circle-down" reads "Arrow circle down", "ph:arrow-up" "Arrow up"; the curated glyphs keep
  their localized labels), filtered All or one set (the sets read from `NS.IconSets`; each open
  starts on All, a tab switch keeps the choice). A glyph's tooltip adds its set's name, and a
  Game-icons mark its author ("Game-icons, by Lorc", as CC BY 3.0 asks; README `## Credits`). Each
  set's list is built once for the session, so a keystroke re-filters it without rebuilding it.
- **The grid is virtualized**: 84 cells are built once and re-dressed from the tab's list as it
  scrolls, so the thousands of game icons cost no more frames than a short tab.
- **Search**: the box filters the shown tab as you type, not case-sensitive, as plain text (`%` or
  `[` is a letter): Markers by name; Glyphs by catalog key or shown label (`arrow-circle` and
  `arrow circle` both find "Arrow circle down"); Game icons by the texture id's digits (a texture
  path the macro list gives, by its file name). The results show from the top; with nothing matching
  the grid says "No icon matches your search.". The text lasts the session: a tab switch and a later
  open keep it (the box shows it) and filter again, and the clear mark empties it. A stored icon the
  search hides stays selected in the footer. Tooltip: "Markers by name, glyphs by name, game icons
  by texture id. Not case-sensitive."
- **The Wowhead hint** (Game icons only): the client has no API that names a game icon from its file
  id, so the tab searches by id alone and says so: "Search by texture id. To find an icon by its name
  (e.g. ability_cheapshot), look it up on Wowhead and type its id here." Its button, **Copy
  wowhead.com/icons**, shows `https://www.wowhead.com/icons` in a small copy window (the library's
  `CopyWindow`, as the Share page's export is: `QuickCommsIconLinkWindow`, titled "Quick Comms:
  Wowhead icons", 420 × 120, over the browser), selected for Ctrl+C; the game cannot open a web
  page. It closes with the browser; Escape with its box focused closes it alone.
- **Pick**: hovering an icon names it (its label, or "Texture id N" for a game icon); a click selects
  it (gold behind it, named in the footer); a double-click or **Choose** chooses it. The stored icon
  is preselected, and its tab opened and scrolled to it. No icon, or one no tab lists (a seeded
  set's spell icon, a typed texture path), opens Markers, the first tab, with nothing selected: no
  cell could show such an icon selected, and Choose waits for a click.
- **Icon color**: the swatch opens Blizzard's color picker (above the browser); every glyph in the
  grid and the footer is drawn in the color. Choose hands a glyph its color (white is none) and any
  other icon none.
- **Cancel**, the close X and Escape close it and change nothing. Escape over the popup closes the
  browser only: the popup's own Escape entry is taken out while the browser is open and put back
  after it closes. It also closes as Cancel when its opener closes (the popup), the settings window
  hides, the profile changes, the opener's group or callout is gone, or on a stand-down.
- **Combat**: the library's combat cover lies over its page, as over every settings page, and Choose
  is refused with one line; nothing is written in combat.

## Comms Pad

`settings/Pads.lua`, one pad at a time.

```
band     [ Pad v (picker) ][ New pad ]
strip    [ General ][ Groups ][ Layout ][ Window ][ Chip ][ Icons ]
General  Name, Enabled, then Unlock (or Lock) pads and Delete pad
Groups   Show groups as, then the pad's groups as a drag-to-reorder list with a remove glyph
         (its priority order; it takes the group off the pad and asks nothing), then Add a group
         (the top-level groups the pad does not hold: a group inside another shows with it)
Layout   orientation, grid columns, growth, chip style, scale, spacing (a chip's label runs to
         its right edge, or to the padlock on a locked chip: no channel letter there, the chip's
         tooltip names the channel), then Position: X and Y and Reset this pad's position
Window   visibility, fade and faded alpha; then Header (Header height, then a font block, a
         Background with Use class color and a border block, all for the pad's top row, the one
         that names the situation: World, M+, Raid), Section titles (face, size, color with Use
         class color, flags, shadow: the gold group titles), Border (style, thickness, color with
         Use class color) and Background (its color with Use class color), each composed by the
         options library (options-ui-§16, §17) under its own heading
Chip     the chips themselves: Size (Chip width, Chip height with 0 automatic), Color (the chip's
         Background with Use class color), Border (the composed block), Font (the chips' labels:
         face, size, color with Use class color, flags, shadow) and Glow (Glow, Glow style, Glow
         color with Use class color)
Icons    the chips' icons (B9): Size and crop (Icon size, Zoom), Color (Desaturate, Icon opacity,
         Tint with Use class color), Border (the composed block: Show border, style, thickness,
         color with Use class color) and Glow (Glow, Glow when, Glow style, Glow color with Use
         class color), then one heading per style's knobs and Offset
```

The Window tab was the Look tab until 2026-10-20, and its own rows keep their `pad.look.*` paths; its
Header block is `pad.header.*`. Every Header default draws the header as it was (GameFontNormalSmall's
face, 10 points, gold, its shadow, over no background and no edge) except its height, 22 where it was
18 (owner: "make the header slightly larger"). The header's text starts at the section titles' left
edge (`PadLayout.PAD`) in every growth direction; the lockdown chip and the stale hint take the
header's face, size, flags and shadow and keep their own red and gray, and the collapse button is two
points larger in the header's color. Section titles are the Window tab's Font block, gold by default,
now that the chips and the header have their own.

The Chip tab's rows are `pad.chip.*` (settings/SchemaMembers.lua). Chip width moved there from Layout
(`pad.layout.width` is gone). Chip height 0 is automatic, the height a chip always had (grown to hold
its font and its icon); above 0 a labeled chip is that tall, never shorter than its icon and 4 pixels
beside an icon. An icon-only chip stays square around its icon whatever the size says. The chip's edge
is drawn on a plain child laid over it, so it never hides the icon or label; its glow (off by default)
is LibCustomGlow's effect around the whole chip in one of the Icons tab's four styles, at that tab's
knob defaults, on its own key beside the icon's glow, always on while enabled. Every Chip default draws
the chip as it was: the 0.10, 0.10, 0.12, 0.90 body, no edge, the small white label. Glow style is
grayed out while the glow is off; the color pairs never are.

The Icons tab's rows are `pad.icon.*` (settings/SchemaIcons.lua). Every color pair sits on one line and is
never grayed out; Border style and thickness are grayed out while Show border is off; Glow when, Glow style
and every knob while the glow is off, and a knob also while the glow is in a style it does not apply to.
Glow when is Always, On hover or After sending (1.5 s from the send result; a dial closes on the send,
so its wedge glows for 1.5 s from the next open, if that comes within 5 s). The page's Defaults puts the
Window, Chip and Icons rows back too.

X and Y write the whole `pad.point` row, the same one the drag strip writes; a drag on screen
updates the boxes. A new pad holds the seeded sets the profile still has as top-level groups, in
shipped order.

## Comms Dial

`settings/Dials.lua`, one dial at a time.

```
band     [ Dial v (picker) ][ New dial ]
strip    [ General ][ Groups ][ Wheel ][ Icons ][ Binding ][ Preview ]
General  Name, Enabled, then Delete dial
Groups   Show groups as (Categories or Flat), the depth-3 warning (spec §11.3), then the dial's
         groups as a drag-to-reorder list with a remove glyph (its priority order, spec §7; it
         takes the group off the dial and asks nothing), then Add a group (top-level groups only)
Wheel    wedges per ring, open at, then Position: X and Y and Reset this dial's position
Icons    the wedges' icons, as the Comms Pad page's Icons tab (a wedge's border is a round ring,
         never wider than the wedge; its icon size keeps the wedge's own size)
Binding  how Relaxed mode works, the key capture (WoW's own binding of the dial's Open Comms
         Dial entry), the key's line, and the dial's place in WoW's key bindings (spec §9.4)
Preview  each ring as the current or previewed situation builds it, wedge by wedge
```

- **General:** Name and Enabled are the `dial.name` and `dial.enabled` rows; Delete dial asks first and keeps the dial's groups and
  callouts (the key belongs to the place, so the dial that moves up takes it).
- **Groups:** Show groups as is `dial.mode` (Categories or Flat). The warning names each battleground
  node set that would open three rings deep because a group above it is active there too
  (`Dial_Layout.DeepGroups`, built under that battleground's preview); it knows a seeded
  battleground set by its origin (`bi.bg.<key>`) while the set holds groups. The list is the dial's
  priority order; Add a group appends one.
- **Wheel:** Wedges per ring is `dial.slices` (4, 6, 8 or 12; a ring that holds a ring takes 8 on a
  12-wedge dial), Open at is `dial.openAt` (its place or the cursor). X and Y write the whole
  `dial.point` row; a refused offset says why and puts the box back. There is no depth control
  (owner ruling R5): depth is spec §11.3's limit, warned about on the Groups tab.
- **Binding:** a line on how Relaxed mode works; the Key capture box (AceGUI's `Keybinding`; Escape
  in it clears the key). Since 2026-10-20 the key is no profile field: it is WoW's own binding of the
  dial's Bindings.xml entry, Open Comms Dial <n>, n the dial's place in the dial list. The box shows
  that entry's key (`Compat.BindingKey`, GetBindingKey) and sets it through `Dial.BindKey`
  (`Compat.SetBinding`, the old key unbound, then `Compat.SaveBindings` in the set in force), so
  Options → Keybindings → Ka0s Quick Comms shows the same key and a key set there shows here (the
  page re-reads it each time it is shown). It is account-wide unless the player ticks Character
  Specific Keybindings there. A key taken from another WoW binding prints one line naming it by its
  menu label (`Compat.BindingLabel`). Out of combat only: in combat the box refuses with one line and
  goes back. A key the open dial uses (Escape, the mouse buttons and wheel, 1–8 without a modifier)
  is refused the same way. The key's line says what the key does: opens and closes this dial, or
  nothing while the dial is off or Quick Comms is stood down, or that there is no key yet. A place
  line names the Open Comms Dial entry (it moves when a dial above it is deleted) and that the key is
  for every character unless Character Specific Keybindings is ticked. A dial past the fourth place
  has no entry: its box is disabled and the line says to move it into the first four.
- **Preview:** each ring, wedge by wedge, with its compass word (a clock position past eight
  wedges), marking the ring the dial opens on
  and the wedges that open a ring. It is a listing (owner ruling R3); the drawn dial is the
  in-game preview (test mode, Preview as…).

The page's Defaults puts groups-as, wedges per ring and open at back to their defaults and turns the
dial on, in one act (`Library.Batch`); the name, groups and position are kept, and the key, WoW's
own binding, is never touched.

## Share

`settings/Share.lua`.

```
strip     [ Export ][ Import ]
Export    what travels; a checkbox per group, Comms Pad and Comms Dial, under a heading per
          kind (a callout travels inside its group); what the string will hold; Export (the string opens, selected, in the copy
          window) and Clear
Import    a paste box (its Accept checks the string); the report (spec §15 step 5); Import and
          Clear
```

The ticks and the checked string are session state, cleared by a profile switch. Export and Import
refuse in combat with one line (the panel is locked in combat anyway). Defaults unticks everything
and forgets the checked string; nothing in the profile changes. A seeded set is ticked and exported
as any group; ticking a parent (directly, or through a pad or a dial) brings its children, and a
child ticked alone travels without its parent and arrives top-level.

## Still to come

Quick mode's delay and tap action with the C7 upgrade.
