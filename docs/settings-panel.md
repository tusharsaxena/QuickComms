# Settings panel — Ka0s Quick Comms

Built on LibKa0s-Options from the descriptor in `settings/OptionsSetup.lua`. The category registers
eagerly at `OnEnable`; each page's body builds on its first show (options-ui-§1/§5).

| Page | Covers |
|---|---|
| Ka0s Quick Comms (landing) | The logo, the TOC notes line and the slash command list, drawn by the library's `BuildLandingPage` |
| General | `Master controls`, `Behavior`, `Keybindings` (last) |
| Groups | One group (a seeded built-in set is one too): `General`, `Callouts`, `When`, `What it sends` |
| Pad | One pad (the Comms Pad page until the dial polish, 2026-10-21): `General`, `Groups`, `Layout`, `Window`, `Header`, `Section titles`, `Buttons`, `Icons` |
| Dial | One dial (the Comms Dial page until the dial polish, 2026-10-21): `General`, `Groups`, `Layout`, `Slices`, `Hub`, `Paging`, `Labels`, `Icons`, `Ring map` |

Item 020 (2026-10-24, the settings layout) moved, regrouped and relabeled rows across these pages; no
setting's stored path, default, range or behavior changed (`tests/test_schema.lua`'s layout guard
pins every row against `tests/schema_pins.lua`). The renamed tabs: the Groups page's Preview is
*What it sends*; the Pad page's Pad header and Section header are *Header* and *Section titles*, and
Window moved ahead of them (outside in); the Dial page's Wheel is *Layout*, Slice labels and Group
labels are one *Labels* tab, and Preview is *Ring map*.
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
| Preview as (`state.previewAs`, session; its own line: Off first, then every preset) | |
| Reset position (button: every pad and dial back to its default place, one chat line) | Reset all settings (button, asks first) |

Lock frame, `/qc lock|unlock` and the launcher's Locked entry write the same path; Test mode,
`/qc test` and the launcher's Test mode entry call the same switch (`Preview.SetTestMode`), which is
refused in combat. The launcher's Show window entry and the Toggle Comms Pads key binding (Options →
Keybindings → Ka0s Quick Comms, or General → Keybindings in this addon's settings) call `/qc toggle`'s handler (`SlashVerbs.TogglePads`), which hides
or shows every Comms Pad and remembers it per character (`db.char.padsHidden`), through a /reload
and the next login.

Preview as is passed through the composer's `extra` slot, so it lands after the canonical rows and
before the button pair, never among them: options-ui-§15 as amended in v2.84.0 sanctions that slot
for page-wide host rows. It draws every pad, and opens dial 1, as another situation would (nothing
sends); its choices are Off first, then Current (a live preview of where you are) and every preset.
A pick other than Off opens the preview window (`modules/PreviewWindow.lua`), the same window
`/qc preview` opens, and closing the settings window no longer ends it: End preview, Escape or the
window's close mark do. `/qc preview` writes the same session row, and the page follows it
(`Preview.announce` repaints). It is page-wide, so no editor page draws it, and no page's Defaults reaches it; Reset all
settings ends it with the other session rows.

Every row writes through the one seam (`NS.SchemaRuntime.Set`), and its reaction is the same one
the CLI, the launcher and the host verbs trigger (`Settings.REACTIONS` in `settings/Schema.lua`).
The header's Defaults button and Reset all settings both open the confirmation popup; the global
reset is a profile reset. That confirm, like every delete's, is shown in `FULLSCREEN_DIALOG`, over the
preview dial and an open callout popup (`ModalWindow.LiftConfirm`, QC-06), and its shared Blizzard
dialog goes back to its own strata when it hides. The global reset never touches the minimap button (options-ui-§12, launcher-§3).
The Defaults tooltip is the library's Reset all settings tooltip (`O.ResetAllTooltip`, read from the
same descriptor Master controls' button uses, so one act is described one way), then *Key bindings
are not changed.* (`O.KEYBINDS_UNCHANGED`, options-ui-§12, §20; item 020, QUI-L-new2).

## General → Behavior

`settings/SchemaRows.lua`, under two headings (item 020, QUI-L01, L02; options-ui-§7), the rows in
this order, which `/qc list` follows:

| Heading | Left | Right |
|---|---|---|
| Sending | When you are solo (`behavior.soloFallback`) | Spam guard (seconds) (`behavior.spamGuard`) |
| | Play a sound on send (`behavior.sounds`) | Note dropped callouts in chat (`behavior.dropNotes`) |
| Pads and dials | Put instance-specific groups first (`behavior.autoPromote`) | Show the LOCKDOWN tag (`behavior.lockdownChip`) |
| | Explain why groups show (tooltips) (`behavior.whyTooltips`) | |

Put instance-specific groups first was *Promote specific groups*, Explain why groups show (tooltips)
was *Explain why groups show*, and Show the LOCKDOWN tag was *Show the lockdown tag*; the tooltips
are unchanged.

## General → Keybindings

The General page's **last** tab (item 015, options-ui-§20), drawn by the library: `settings/Panel.lua`
hands `O.KeybindingsTab({ bindings = NS.BINDINGS, intro = ... })` to `RenderTabbedSchema`'s `opts.tabs`
with no `before`, so it lands after every group tab. `NS.BINDINGS` (`settings/SlashVerbs.lua`) is
`Bindings.xml` in order, one row each:

| Row | Command | Tooltip |
|---|---|---|
| Toggle Comms Pads | `CLICK QuickCommsTogglePads:LeftButton` | Hides or shows every Comms Pad on this character, as /qc toggle does. |
| Open Comms Dial 1 to 4 | `CLICK QuickCommsDial<n>:Toggle` | Opens or closes the dial at place <n> in the dial list. |

Each row is the client's `BINDING_NAME_` label, one key button and Clear. The button binds the
action's first key (left-click to listen, Escape or a second click cancels, right-click removes that
key and a second one moves up) and shows it; when the game's Options → Keybindings page holds a
second key for the action, the button reads `<key> +1` and its tooltip names every key and says where
the others were set. Clear removes every key from the action. The library's fixed intro heads it
(*Key bindings are saved by the game, not in your profile. Defaults and Reset all settings leave them
alone.*), then this addon's one line: *A dial's key follows its place in the dial list: Open Comms
Dial 1 opens the first dial, and a dial past the fourth has no key.* Under the rows the set line says
which binding set is in force (all characters, or this character only after Character Specific
Keybindings), then the outcome line.

The tab and WoW's Options → Keybindings → Ka0s Quick Comms read and write the client's one store
(`SetBinding`, then `SaveBindings(GetCurrentBindingSet())`), so a key set in either shows in the
other: the tab repaints on `UPDATE_BINDINGS` while it is on screen and re-reads on the page's show.
Nothing is kept in the profile, so Defaults, Reset all settings and a profile switch
never move a key. In combat every write is refused and a capture in progress is canceled.

This brings back an in-panel key editor: the Dial page's Binding tab (2026-10-20) was retired in the
dial rework (2026-10-21, `b902e35`), and the owner's item 015 (2026-10-24) supersedes that removal,
through the library's surface (`LibKa0s v1.77.0`) rather than the retired `Dial.BindKey`.

## Groups

`settings/Groups.lua`, one group at a time. Every group draws the same tabs: a seeded built-in set
is an ordinary group (2026-10-18-builtins-as-groups-design.md), with no tag, no lock and no
read-only branch.

```
band      [ Group v (picker; a green dot after its name marks a group active now; a group inside another is
          listed, indented, right after it) ][ New group ][x] Preview while editing   (one row)
strip     [ General ][ Callouts ][ When ][ What it sends ]
General   Name, Enable this group, then the icon under an Icon label with Choose icon…, the clear
          glyph and its color swatch (settings/Editors.lua's chooser, no Icon text box), then
          Parent group (None, or a top-level group) alone, then Duplicate and Delete group, then a
          gap, a gray line ("Adds back the built-in groups and callouts you deleted. Changes
          nothing you have.") and Restore built-in groups (page-wide)
Callouts  Add callout (the callout popup, blank; across the row), Reuse callout
          with Add at the right edge (both 2px short of it), then its callouts as a drag-to-reorder list, each row the handle,
          the icon (the question mark when none), the name in gold, the channel's short label in
          its chat color (a smart kind resolved against the snapshot; PARTY's when solo) and the
          text in muted white cut at 40 characters with "…", then an edit glyph and a remove glyph
          at the right edge
When      settings/Groups_When.lua: the active-now line, then Inherit when conditions (grayed out
          with no parent), then the drawers
What it sends  the active-now line, then a table: a gold header row (Callout, What it sends here), then
          one boxed row per callout, its icon and name beside its first preview line
```

**Parent group** (General, the `group.parent` row): a dropdown of None, then every top-level group
but this one, in the picker's order. A group inside another shows wherever that group is placed (a
pad draws a section for it, a dial a node ring), gated by its own Enabled and its When (its
parent's while it inherits, below), while the parent's gate the whole; it is never placed on a pad
or a dial itself, so picking a parent takes it off every pad and dial in the same act, and None does not put it back (Pad → Groups → Add a
group does). Groups go one level deep: the dropdown is idle while this group holds groups, and its
tooltip names them. A group's children are listed A–Z by name (2026-10-25), here, on the pads and on the dials. Delete on a
parent asks first and says what happens: the groups inside it become top-level groups, in its place
on every pad and dial. Duplicate of a child puts the copy in the same parent (the chat line says
so); a parent's copy holds no children. The page's Defaults keeps the parent, as it keeps the icon.

**Inherit when conditions** (When, at the top of the tab under the active-now line, the
`group.inheritWhen` row; on General beside Parent group until item 020, QUI-L03, so a group's own
conditions are now chosen and written on one tab): while it is
ticked, a group inside another is judged by its parent's When instead of its own
(`Resolver.WhenOf`); its own stored When is kept, unused, for when it is unticked. It is on for every
group, a seeded battleground node or one of yours, and a group stored before the setting (no field)
reads as on; unticking stores `false`. The box is grayed out while Parent group is None, since a
top-level group has no parent to take a When from. The Group picker's dot, the pad, the dial,
Preview as, the What it sends tab and every "why" line follow it. A write repaints the page (the row
is structural), and the page's Defaults ticks it again. Tooltip: "Use the parent group's When
instead of this group's own. This group's own conditions are kept for when you untick it. Only a
group inside another group inherits. Set the parent on the General tab."

**Restore built-in groups** (General's last row, page-wide, and on the empty "No groups yet"
General; set apart from the group's own acts by a gap and a gray line, not a heading, since it acts
on the library, item 020, QUI-L05): puts back every shipped set, node and callout the profile no longer has, as new ordinary
members: a set at the end of every pad and dial, a node inside its set's group (while that group is
top-level), a callout at the end of its seeded group. It never changes, moves or overwrites what the
player has, so it does not ask first, and a second click adds nothing; one chat line says how many
groups and callouts came back, or that nothing was missing. There is no per-set reset to stock:
delete the group, then restore. It is not under the header's Defaults, which resets the selected
group (options-ui-§13).

**Preview while editing** (the band, beside New group, the `behavior.previewOnEdit` row; on by
default, saved; QF-02: its start prints `Previewing: <group> (editing)` and puts the preview window
up, titled with the group, its dropdown on the group's own situation (`Preview.EditPresetKey`) and
the whole window grayed out with its controls off and a tooltip naming this page (QF-07, owner
2026-10-23); its Escape ends the preview for the session with the box left ticked): drawn through `O.PageHeader`, the band a picker with another page-wide control
takes (options-ui-§14), with New group level with the picker's control as PageBanner places it.
The three are one AceGUI SimpleGroup's children, laid out by Flow on ONE row (options-ui-§14, "The
band is ONE ROW"; item 020, QUI-L34: two rows until then): the picker 0.4 of the band, New group 0.25
and the checkbox the remaining 0.35 (`G.BAND_WIDTHS`), the band 44 pixels tall (`G.BAND_H`, the
library's `O.BANNER_H`, as the Pad and Dial bands), so the three editor pages start their strips at
one height. AceGUI shows and sizes them; widgets placed in the header frame by hand drew only the
picker's label in the client.
While the Groups page is on screen with it ticked, every enabled pad and dial shows only the selected
group, with the groups inside it, whatever their When and Enabled (`Preview.SetEditPreview`,
`Surfaces` `deps.only`): drawn and disarmed as a Preview as plan, `Preview: <group>` on the header,
dial 1 open. Clicking a button or a wedge sends nothing and prints the line it would have sent
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

**What it sends** (the Preview tab until item 020, QUI-L08: "Preview" is kept for the drawn
previews; `Ed.TableRows`, shared with no other page yet): the active-now line, then a table. A
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
  read-only: the active-now line, the Inherit when conditions box, then the muted gold line "Uses
  <parent>'s conditions. Untick Inherit when conditions above to set this group's own.", then the gray line, then the
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
- **The list** is the drag-to-reorder list (`Ed.ReorderRows`, shared with Pad → Groups and
  Dial → Groups). The edit glyph (the catalog's `edit` mark) opens the popup filled in; the
  remove glyph (the `transmog-icon-remove` atlas) asks first, then deletes the callout, since
  nothing else holds it. Both carry a tooltip. Each row is an AceGUI Table layout
  (`Ed.RowColumns`): the handle's gutter, the label filling what is left, a 24px cell per 16px
  glyph and a 3px pad, so the glyphs sit at the box's right edge (the last one's art 7px in).
  Every fixed column is an explicit `{ width = n }`, since the layout reads a bare number from 1 to
  under 10 as a weight;
  `Ed.RowAlignV` centers every widget in the 30px row.
- Delete group (General; *Delete* until item 020, QUI-L04) deletes the group's callouts with it, and
  Duplicate gives the copy copies of them.
- The page's Defaults tooltip: "Turn the selected group back on, turn Inherit when conditions back
  on, and turn Preview while editing back on. Its name, icon, parent, callouts and own When are
  kept." (item 020, QUI-L06: it promised the reset of the retired Open the dial on this group).

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
         ------- What it sends -------         the baked line and its bytes, or why it sends
                                              nothing, and any lock
         (a gap)
         [Cancel        ] [Save          ]
         the line that names a field Save refused
```

- **The layout.** Two columns, each the library's button-pair width (`Helpers.BUTTON_PAIR_REL` of
  the body, the width `InlineButtonPair` gives Save and Cancel, options-ui-§8), with the whole pixels
  the pair leaves (8 px) as the gutter between them: Name and Channel, the icon with Choose icon…
  and the clear glyph, and the swatch, Save (left, since 2026-10-22) and Cancel each fill one, so their outer edges meet the Text box's and the What it sends rule's,
  and the right column starts at the same place on every line. The pair keeps its width; the popup
  only puts the gutter between its two buttons. The fields are
  drawn by the library's field maker (`RenderField`) into the popup's own lines, not by
  `RenderRows`' half-and-half lines, so the gutter exists. AceGUI draws an EditBox's box and a
  Button's art 2 px in from the widget's edges, so 2 px in is where every visible left edge sits:
  each field's label is moved 2 px in, the Channel dropdown's art 2 px left, the icon 2 px in, the
  What it sends rule 2 px in from both sides (AceGUI's Heading draws it 3 in), and the preview and error
  lines 2 px in. Every anchor the popup moves is put back when AceGUI takes the widget back (an
  `OnRelease` callback per widget), so a pooled frame reaches another addon as AceGUI made it. The
  What it sends heading (*Preview* until item 020, QUI-L08: the Groups page's term for the same
  line) keeps a section's gap above it (`O.Section`'s 10 px): the popup sets
  `ctx.lastGroup` to the fields' group after drawing them, as `RenderRows` would.
- **No Icon box.** The icon is chosen only with the chooser; the draft still carries it as a
  texture path or id, Save writes it to `callout.icon`, and that row still answers `/qc`.

- **The draft.** The popup edits a plain copy of the callout's four fields and its icon's glyph
  color (blank for Add). Choose icon… opens the icon browser over the popup; its Choose writes the
  draft's icon and color, the clear glyph empties both, and the swatch writes the draft's color.
  An icon that is no glyph drops the draft's color. Every control writes the draft, never the
  profile, and What it sends bakes the draft, so it follows each edit before anything is saved. A text
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
  write under it), after which a late Save writes nothing. An icon browser opened from
  the popup closes with it, as Cancel.
- **Fully modal:** a full-screen click-catcher in the `FULLSCREEN` strata covers the settings window, so
  the page underneath cannot change while a draft is open. Only one popup exists. `FULLSCREEN` is one
  strata over the Comms Dial's `DIALOG`, so an open preview dial's hub (its dot and pointer, raised
  over the dial's header by level) draws under the popup, not over it (QC-06).
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
X, the gold header), 560 × 594, with its own full-screen catcher in the popup's `FULLSCREEN` strata,
above the popup and the popup's catcher by a band of levels of its own (`ModalWindow.LEVEL_OVER`, far
over the popup's `LEVEL`): it is modal to whatever opened it. `FULLSCREEN_DIALOG` stays above it for
its pull-outs, the color picker and the Wowhead link window. Only one browser exists,
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
  `CopyWindow`: `QuickCommsIconLinkWindow`, titled "Quick Comms:
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

## Pad

`settings/Pads.lua`, one pad at a time.

```
band     [ Pad v (picker) ][ New pad ]
strip    [ General ][ Groups ][ Layout ][ Window ][ Header ][ Section titles ][ Buttons ][ Icons ]
General  Name, Enable this pad, Visibility (visibility, fade and faded opacity, under its heading),
         then Unlock (or Lock) all pads and Delete pad
Groups   Show groups as, then Add group (the top-level groups the pad does not hold: a group
         inside another shows with it), then the pad's groups as a drag-to-reorder list with a
         remove glyph (its priority order; it takes the group off the pad and asks nothing)
Layout   orientation, grid columns, growth, button style, pad scale, button spacing (a button's
         label runs to its right edge, or to the padlock on a locked button: no channel letter
         there, the button's tooltip names the channel), then Position: X and Y and Reset this
         pad's position
Window          the pad itself: Background (Background color) and Border; no font
Header          the pad's top row, the one that names the situation ("Quick Comms: World", M+, Raid): Size
                (Header height), Font (face, size, color with Use class color, flags, shadow),
                Background (its color with Use class color) and Border (style, thickness, color with
                Use class color), the blocks composed by the options library (options-ui-§16, §17),
                each under its own heading
Section titles  each section title's row (the gold group titles): Size (Section title height, 0
                automatic), Font, and the Background and Border of the band behind each title
Buttons  the buttons themselves: Size (Button width, Button height with 0 automatic), Font (the
         labels: face, size, color with Use class color, flags, shadow), Background (the button's
         Background color with Use class color), Border (the composed block), Button glow (Glow,
         Glow style, Glow color with Use class color) and Shine (Shine look, Shine strength, Shine
         tint, Bloom color A and B, each color with Use class color)
Icons    the buttons' icons (B9): Size and crop (Icon size, Zoom), Color (Desaturate, Icon opacity,
         Tint with Use class color), Border (the composed block: Show border, style, thickness,
         color with Use class color), Icon glow (Glow, Glow when, Glow style, Glow color with Use
         class color, then Glow X offset and Glow Y offset, always drawn), then the selected Glow
         style's knobs under its heading (none while the glow is off)
```

Item 020 (2026-10-24) reordered and relabeled this page, and changed no setting. The strip runs
outside in, Window, Header, Section titles, Buttons, Icons (QUI-L09; Header and Section titles were
*Pad header* and *Section header*, QUI-L10). Every styled tab runs its blocks Size, Font, Background,
Border, then effects, and labels its swatch *Background color* (QUI-L12; the Buttons tab's
background block was headed *Color*). The Buttons tab's glow is *Button glow* and the Icons tab's
*Icon glow*, which also holds the two glow offsets (no Offset heading; QUI-L13, L14). The Buttons
tab's Glow style tooltip ends "Drawn at the Icons tab's default knobs." General's *Enable this pad*
was *Enabled* and *Faded opacity* was *Faded alpha* (QUI-L-new3, L-new1); *Unlock all pads* / *Lock
all pads* (the master lock, the same switch as Lock frame on the General page > Master controls) was
*Unlock pads* / *Lock pads* (QUI-L15). On Groups, *Add group* (was *Add a group*, below the list) sits
above the list, as the Callouts tab's add controls do (QUI-L07). On Layout, *Pad scale* and *Button
spacing* were *Scale* and *Spacing*; Pad scale's tooltip says it is multiplied by Master scale on the
General page > Master controls (QUI-L36).

Header, Section titles and Window were one Window tab until 2026-10-20 (the Look tab before
that); the owner split it into three, each under its own headings. The third was Main window, with
Visibility, Fade and Faded opacity, until the owner moved those to General and renamed it Window
(2026-10-20); the Buttons tab was the Chip tab until then, and its rows were `pad.chip.*` until the internal
rename to `pad.button.*` (2026-10-20; no migration: profiles are reset). The options library orders a page's
tabs by each group's first row (options-ui-§13), so the three tabs' rows sit after Layout's and before
the Buttons tab's in `settings/SchemaMembers.lua`; General's Visibility rows sit after Name and
Enabled, so General stays first. Window's and the Visibility rows keep their `pad.look.*` paths; Header's
are `pad.header.*`, Section titles' `pad.section.*`. The Header defaults are the owner's
(2026-10-20): 24 pixels tall (it
was 18), Friz Quadrata at 16 points, gold, outlined, with its shadow, over no background and no edge
(its edge color white, for when a thickness is set). The header's text starts at the section titles' left
edge (`PadLayout.PAD`) in every growth direction; the LOCKDOWN tag and the stale hint take the
header's face, size, flags and shadow and keep their own red and gray, and the collapse button is two
points larger in the header's color. The section titles take the Section titles tab's Font block (it
was the Window tab's Section titles block, `pad.look.font*`); by default (the owner's, 2026-10-20) 12
points, gold, outlined, with their shadow. Section title height 0 is automatic, the height a title row
always had (grown with its font); above 0 every title row is that tall, its text centered in it. The
tab's Background and Border draw a band behind each title across its row (a packed child's title: its
block's width, as its right-click frame), with the text kept clear of the edge; by default there is
none, and the text sits on the titles' left edge as before.

The Buttons tab's rows are `pad.button.*` (settings/SchemaMembers.lua). Button width moved there from Layout
(`pad.layout.width` is gone). Button height 0 is automatic, the height a button always had (grown to hold
its font and its icon); above 0 a labeled button is that tall, never shorter than its icon and 4 pixels
beside an icon. An icon-only button stays square around its icon whatever the size says. The button's edge
is drawn on a plain child laid over it, so it never hides the icon or label; its glow (off by default)
is LibCustomGlow's effect around the whole button in one of the Icons tab's four styles, at that tab's
knob defaults, on its own key beside the icon's glow, always on while enabled. The Buttons defaults are
the owner's (2026-10-20): a #3F3F3F body at 25% opacity, a flat 1-pixel #EAEAEA edge at 10% (Border
style None is no border art, so the thickness draws a plain line), the small white label, the
automatic height. The Icons tab's Icon size defaults to 16 on a pad (an icon-only button is 24 square).
Glow style is
grayed out while the glow is off; the color pairs never are.

The Shine heading (shine overlay, 2026-10-21) follows Button glow: `pad.button.shineLook|shineStrength` and the
pairs `shineTint`, `shineBloomA`, `shineBloomB` with their Use class color boxes. Shine look is None (the
default), Gloss cap, Gloss fade, Glass orb, Frosted glass, Fluid glass, Bevel or Rim light: one overlay over the
whole of every button (`NS.Shine.Apply`; owner, 2026-10-21: the plate, the icon and the label's chip,
whatever the Button style), in three pieces so a wide button keeps the look's thin edges and an
icon-only button is the art whole, above the icon and below the padlock, the label, the send flash and
the hover.
Shine strength (0 to 100, step 5, default 85) is its opacity and Shine tint colors its light (its shade
stays dark). Strength and Tint are grayed out at None; Bloom color A and B (pink and mint) color Fluid
glass's two blooms and are grayed out under every other look. Each pad keeps its own; the Dial page's
Slices tab has the same heading for a dial.

The Icons tab's rows are `pad.icon.*` (settings/SchemaIcons.lua). Every color pair sits on one line and is
never grayed out; Border style and thickness are grayed out while Show border is off; Glow when, Glow style
and the offsets while the glow is off, and the offsets also under Button, which ignores them. The
offsets sit right after Glow color, under Icon glow, and always show. A style's knobs (Pixel border, Auto cast sparkles, Button
(rotating rays), Proc (flipbook)) show only while the glow is on and in that style (owner request,
2026-10-20; until then every style's knobs showed, grayed out under the others): the tab's render filters
them (`Settings.ShownIconRows`), the rows stay in the schema, so Defaults and `/qc set`
still reach every knob. Glow and Glow style are structural (`Editors.STRUCTURAL`): a write repaints the
tab on the next frame, its scroll kept, so the right heading appears at once. The Dial page's
Icons tab does the same.
Glow when is Always, On hover or After sending (1.5 s from the send result; a dial closes on the send,
so its wedge glows for 1.5 s from the next open, if that comes within 5 s). The page's Defaults puts the
Window, Header, Section titles, Buttons and Icons rows back too, and its tooltip names every tab it
reaches: "Put the selected pad's visibility, groups-as, layout, header, section titles, window,
buttons and icons back to their defaults, and turn it on. Its name, groups and position are kept."
(QUI-L18).

X and Y write the whole `pad.point` row, the same one the drag strip writes; a drag on screen
updates the boxes. A new pad holds the seeded sets the profile still has as top-level groups, in
shipped order.

## Dial

`settings/Dials.lua`, one dial at a time.

```
band     [ Dial v (picker) ][ New dial ]
strip    [ General ][ Groups ][ Layout ][ Slices ][ Hub ][ Paging ][ Labels ][ Icons ][ Ring map ]
General  Name, Enable this dial, a gray line ("Set this dial's key on the General page >
         Keybindings. A dial's key follows its place in the dial order."), then Delete dial
Groups   Show groups as (Categories or Flat), then Add group (top-level groups only), then the
         dial's groups as a drag-to-reorder list with a remove glyph (its priority order, spec §7;
         it takes the group off the dial and asks nothing)
Layout   slices per ring (Auto by default), ring radius, then slice gap alone, then Position:
         open at, X and Y and Reset this dial's position
Slices   Colors (Slice color, the slices' fill; Highlight color, the hovered slice's fill) and
         Shine (Shine look, Shine strength, Shine tint, Bloom color A and B), each color with Use
         class color
Hub      Hub (Hub style, Hub size, Backdrop color), Hub border (Hub border size, Hub border
         color), Hub circle (Circle size, Line width, Circle color) and Pointer (Show pointer,
         size, offset, color), each color with Use class color
Paging   a paged ring's row under the dial: Page row (Distance below labels), Arrows (size,
         spacing, arrow color, arrow background), Page indicator (dot size, current page width,
         dot spacing, current page color, other pages color), Indicator border (dot border, dot
         border color) and Indicator background (Show indicator background, Background padding,
         Indicator background), each color with Use class color
Labels   Slice labels (Show slice labels, label offset, then the labels' Font block: font, size,
         outline, color, Use class color, shadow; grayed out while slice labels are off), Group
         labels (Show group labels, the ring's title above the dial, then its Font block, grayed
         out while off) and Tooltip (side, offset)
Icons    the slices' icons, as the Pad page's Icons tab, under Size, offset and crop: Icon size |
         Icon offset, then Zoom (a slice's border is a round ring, never wider than the slice; its
         icon size, up to 128 or 0 automatic, keeps the slice's own size)
Ring map each ring as the current or previewed situation builds it, slice by slice
```

Item 020 (2026-10-24) reordered and relabeled this page, and changed no setting: Wheel is *Layout*,
the Pad page's name for the same tab (QUI-L22); Slice labels and Group labels are one *Labels* tab
under two headings, with Tooltip last (QUI-L19); Preview is *Ring map* (QUI-L08), since "Preview"
names the drawn previews; the Slice gap moved from its own Gap heading on Slices to Layout, beside
the Auto count it feeds, and Open at to the top of Position (QUI-L21); Slices' Background and
Highlight headings are one *Colors* heading (QUI-L23); Hub splits into Hub, Hub border and Hub circle,
each size beside its color (QUI-L24); Paging's Position heading is *Page row*, its Offset *Distance
below labels* (QUI-L25), and Page indicator splits into Page indicator, Indicator border and Indicator
background, the padding beside its toggle (QUI-L26); Icons heads its first block *Size, offset and
crop*, Icon size beside Icon offset (QUI-L27). *Slices per ring* was *Wedges per ring*, *Show slice
labels* was *Show labels* and *Enable this dial* was *Enabled*; the Dial page's tooltips say slice for
wedge (QUI-L35). Add group moved above the list (QUI-L07), and General's gray line points at the
General page > Keybindings, with no key box and no readout (QUI-L29).

- **General:** Name and Enable this dial are the `dial.name` and `dial.enabled` rows; Delete dial asks first and keeps the dial's groups and
  callouts (the key belongs to the place, so the dial that moves up takes it).
- **Groups:** Show groups as is `dial.mode` (Categories or Flat). The list is the dial's priority
  order; Add group appends one. A dial opens straight on its one active group's ring, or on the
  ring of its active groups when there are several (the dial rework, 2026-10-21, retired the Groups
  page's Open the dial on this group and Skip on the dial in content, and with them this tab's
  three-rings-deep warning: a battleground's node callouts now sit three rings deep by design,
  since In Group is active beside the map's set).
- **Layout:** Slices per ring is `dial.slices`: Auto (0, a new dial's default) gives each page one
  wedge per item from N, clockwise, evenly spaced (owner, 2026-10-22; from W since the dial polish
  before): one is the whole disc, its icon at N; two are halves, N and S; three are thirds, N then
  120 and 240 degrees; and so on, up to 12, and fewer
  when the icons no longer fit their slices at the icon reach (the Slice gap counted; 128-pixel icons
  at radius 100 hold about four a page); or a fixed 4, 6, 8 or 12, from N: a fixed 4 places one
  item N, two N and S, three N, E and S, four N, E, S and W, and a fixed 6, 8 or 12 fills its places
  from N clockwise, the rest drawn empty (never lit, never clicked). The gap never changes a fixed count.
  A ring that holds rings takes at most 8 either way, and a node set pinned to its winds keeps its
  eight. A ring with more items is paged: two arrows under the dial (dimmed at an end, no wrap), the
  Left and Right arrow keys (bound only while a paged ring is shown) and the mouse wheel turn its
  pages; under them a gold pill marks the page shown and a gray dot each other page, and each arrow
  is a round plate in the slices' fill with a chevron, dimmed at an end. Ring radius is `dial.radius` (70 to 180
  pixels, default 120 since 2026-10-22, 100 before): the wedges' distance from the middle; the disc grows with it, keeping 20
  pixels between a wedge's edge and its own. Slice gap (from Slices, item 020) is
  `dial.slice.gap`, below. Open at is `dial.openAt` (its place or the cursor), the first row under
  Position. X and Y write the whole `dial.point` row; a refused offset says why and puts the box back. There is
  no depth control (owner ruling R5).
- **Labels > Slice labels** (the Labels tab until the dial polish, 2026-10-21, then its own Slice
  labels tab until item 020 merged it back; the `dial.label.*` paths kept): Show slice labels is `dial.label.show`: each wedge's name, drawn wholly outside the disc (off
  shows the icons alone; the tooltip still names them). Label offset is `dial.label.offset` (0 to
  300 pixels, 0 automatic: 4 pixels past the disc, 2 until 2026-10-22), each label's distance from the middle; the ring's
  title and the page row move out with it, and it grays out with the font. The Font block is composed by the options
  library as the Buttons tab's (`dial.label.font|fontSize|fontColor|useClassColorFont|fontFlags|fontShadow`;
  defaults white Friz Quadrata 12 with its shadow, `PadDefaults.DialLabel`), grayed out while Show
  slice labels is off. A bigger font lifts the ring's title and drops the page row to clear the labels.
  Under the tab's last heading, Tooltip, Tooltip side is `dial.label.tooltipSide` (Above, the default; Below,
  Left, Right) and Tooltip offset `dial.label.tooltipOffset` (0 to 80 pixels, default 8): every
  dial tooltip (a wedge's, a page arrow's, the hub's Why is this showing?) sits outside the dial,
  that far above the ring's title, below the page row, or beside the disc past its widest label.
- **Labels > Group labels** (dial polish, 2026-10-21; its own tab until item 020): Show group labels is `dial.title.show` (on by default):
  the ring's title above the dial ("Solo", "Comms Dial"). Its Font block is composed as the
  slice labels' (`dial.title.font|fontSize|fontColor|useClassColorFont|fontFlags|fontShadow`;
  defaults gold Friz Quadrata 12 with its shadow, `PadDefaults.DialTitle`), grayed out while off; the
  title is measured with its own line height, so a bigger font lifts it and the tooltip above it.
- **Icons:** Icon offset (a Wheel row until the dial polish, 2026-10-21; `dial.iconOffset` kept) sits
  beside Icon size under Size, offset and crop (it led the tab under Size and crop until item 020): 0 to 250 pixels, 0 automatic, the icons' own distance from the
  middle, the disc keeping its size. Automatic keeps each icon in the same place in its slice at any
  ring radius (owner, 2026-10-21): the share of the band from the hub's edge to the disc's edge that
  the ring radius takes at 100 (the radius itself there; about 113 at the default 120, about 126 at 140, 133 at 150,
  152 at 180). Icon size (0 = automatic) reaches 128 on a dial (a pad's stays 40, with no
  automatic): a game icon is 64-pixel art, so past 64 it is upscaled and softer; at the default ring
  radius icons past about 70 pixels crowd their neighbors, and at 128 a ring wants a radius near 180.
  0 (a new dial's default) is automatic: 48 at the default radius, 0.4 of the radius (owner,
  2026-10-22; 28 at 70, 40 at 100, 60 at 150, 72 at 180), held under a fixed wedge count to the slice's arc less the Slice gap, and within
  16 to 128; a value typed under 16 that is not 0 is 16. The rest is the Pad page's Icons tab.
- **Slices** (2026-10-21): each heading's colors are composed swatch pairs with Use class color.
  Under Colors, Slice color is `dial.slice.background`, each slice's fill (dark, as the disc was).
  The Slice gap, on Layout since item 020, is `dial.slice.gap` (0 to 20 pixels, default 0; the dial
  polish, 2026-10-21, retired the Border heading): each slice moves out along its middle line and shrinks so its outer edge stays on the
  disc and a clear strip that wide parts it from its neighbors (one slice has none). Highlight color is
  `dial.slice.highlight`, the fill the slice the cursor points into takes (gold, faint), anywhere on
  the disc outside the hub's circle, moving with its slice; a click anywhere in a used slice, the
  hub's edge to the rim, sends it, and a click inside the hub's circle goes up a ring or closes (a point in a gap belongs to the slice whose bearing it is in).
  Shine (shine overlay, 2026-10-21) is `dial.slice.shine*`, the Buttons tab's heading for the dial's
  slices, with the same looks, range, defaults and gray-outs: each slice takes its own copy of the look,
  placed and turned with its fill (so it follows the gap, the W/E layouts and every slice count), under
  the slices' icons. Each look is the spec's "Dial slices": whole-disc art, Glass orb's bead and Fluid
  glass's blooms are cut to each slice with a mask, the bead kept round at every slice count, with no
  specular dots; Bevel raises every slice the same way, in the slice's own frame (owner, 2026-10-21). A
  dial's look and a pad's are separate settings.
- **Hub** (dial polish, 2026-10-21: its Hub and Pointer headings sat on Slices until then; the
  paths are kept, so saved settings are untouched; the tab follows Slices). Hub, Hub border and Hub
  circle are `dial.hub.*`, each sub-part's size beside its color: Hub style (Solid circle, the default; Hollow ring; Target, a ring with a dot; Rimmed
  disc, a filled circle on a rimmed backdrop), Hub size (24 to 80, default 32 since 2026-10-22: the backdrop's width,
  where the slices and the pointer start), Circle size (4 to 60, default 24), Line width (1 to 6,
  grayed out under Solid circle), Backdrop color, Hub border size (0 to 6, default 1; Rimmed disc
  always draws one), Hub border color and Circle color, each with Use class color; the circle
  brightens while the cursor is on the hub. Pointer is
  `dial.slice.pointerShow`, `pointerSize` (10 to 48, default 20), `pointerOffset` (0 to 150, 0
  automatic: just outside the hub) and `pointerColor`: the chevron that turns toward the cursor
  (`ph:caret-up`), grayed out while Show pointer is off. The hub and the pointer always draw over the
  slices.
- **Paging** (2026-10-21): a paged ring's row under the dial. Page row's Distance below labels is
  `dial.page.offset` (0 to 80 pixels, default 6) under the labels. Arrows: Arrow size `arrowSize` (12 to 48, default
  24), Arrow spacing `arrowGap` (0 to 60, default 10) from the indicators, Arrow color `arrowColor`
  (the chevron, gold) and Arrow background `plateColor` (the round plate, the slices' fill). Page
  indicator: Dot size `dotSize` (2 to 20, default 6; the pill's height too), Current page width
  `pillWidth` (2 to 60, default 18; the dot size makes it a plain dot), Dot spacing `dotGap` (0 to
  30, default 6), Current page color `currentColor` (gold) and Other pages color `dotColor` (gray);
  then, under Indicator background (dial polish, 2026-10-21, so the row reads on a busy scene), Show indicator background
  `dotBackShow` (default on), Indicator background `dotBackColor` (the plates' fill) and Background
  padding `dotBackPadding` (0 to 20, default 4): a rounded strip behind the row, as wide and tall as
  the indicators and their borders plus the padding each side, its color and padding grayed out
  while off; under Indicator border, Dot border `dotBorder` (0 to 4 pixels, default 1, 0 shows None and draws none) and Dot
  border color `dotBorderColor` (near black, grayed out at 0): an outline around every dot and the
  pill. Each color is a composed swatch pair with Use class color.
- **No Binding tab** (the dial rework, 2026-10-21): the key is WoW's own binding of the dial's
  Bindings.xml entry, Open Comms Dial <n>, n the dial's place in the dial list, set in Options →
  Keybindings → Ka0s Quick Comms or on the General page > Keybindings (item 015, 2026-10-24), which
  the Dial General tab's gray line points at (item 020, QUI-L29); it is
  account-wide unless the player ticks Character Specific Keybindings there, and a dial past the
  fourth place has no entry.
- **Ring map** (the Preview tab until item 020, QUI-L08): each ring, slice by slice, with its compass word (a clock position past eight
  wedges; the first wedge is W, under Auto and, since the dial polish, a fixed count), marking the ring the dial opens on
  and the wedges that open a ring. It is a listing (owner ruling R3); the drawn dial is the
  in-game preview (test mode, Preview as…).

The page's Defaults puts groups-as, the Layout, Slices, Hub, Paging, Labels (with the tooltip
placement) and Icons tabs back to their defaults (tooltip: "Put the selected dial's groups-as, layout,
slices, hub, paging, labels, tooltip placement and icons back to their defaults, and turn it on. Its
name, groups, position and key are kept.", QUI-L28) and turns the dial on, in one act (`Library.Batch`); the name, groups
and position are kept, and the key, WoW's own binding, is never touched.

## Still to come

Quick mode's delay and tap action with the C7 upgrade.
