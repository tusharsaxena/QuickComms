# Settings panel — Ka0s Quick Comms

Built on LibKa0s-Options from the descriptor in `settings/OptionsSetup.lua`. The category registers
eagerly at `OnEnable`; each page's body builds on its first show (options-ui-§1/§5).

| Page | Covers |
|---|---|
| Ka0s Quick Comms (landing) | The logo, the TOC notes line and the slash command list, drawn by the library's `BuildLandingPage` |
| General | `Master controls`, `Behavior` |
| Groups | One group or built-in set: `General`, `Callouts`, `When`, `Preview` |
| Comms Pad | One pad: `General`, `Groups`, `Layout`, `Look` |
| Comms Dial | One dial: `General`, `Groups`, `Wheel`, `Binding`, `Preview` |
| Share | `Export`, `Import`, `Built-in` |
| Profiles | AceDBOptions: switch, copy, reset and delete profiles |

## General → Master controls

Composed by `Helpers.MasterControls` from one declaration (`settings/Panel.lua`), canonical rows in
canonical order (options-ui-§15). The Comms Pad is positionable, so the block is the full framed
set, in order: Enable, General visibility, Master scale, Master alpha, Lock frame, Debug console,
Minimap button, Test mode, then the Reset position and Reset all settings buttons.

| Left | Right |
|---|---|
| Enable Ka0s Quick Comms (`enabled`) | General visibility (`visibility`) |
| Master scale (`scale`, 0.5-2) | Master alpha (`alpha`) |
| Lock frame (`locked`) | Debug console (`state.debugConsole`, session) |
| Minimap button (`global.minimap.shown`) | Test mode (`state.testMode`, session) |
| Reset position (button: every pad and dial back to its default place, one chat line) | Reset all settings (button, asks first) |

Lock frame, `/qc lock|unlock` and the launcher's Locked entry write the same path; Test mode,
`/qc test` and the launcher's Test mode entry call the same switch (`Preview.SetTestMode`), which is
refused in combat.

Every row writes through the one seam (`NS.SchemaRuntime.Set`), and its reaction is the same one
the CLI, the launcher and the host verbs trigger (`Settings.REACTIONS` in `settings/Schema.lua`).
The header's Defaults button and Reset all settings both open the confirmation popup; the global
reset is a profile reset and never touches the minimap button (options-ui-§12, launcher-§3).

## Groups

`settings/Groups.lua`, one group at a time, a user group or a built-in set.

```
band      [ Group v (picker; a green dot marks a group active now) ][ New group ]
strip     [ General ][ Callouts ][ When ][ Preview ]
General   Preview as (page-wide, first), then Name, Icon, Enabled, Open the dial on this group,
          the icon with Choose icon… and its color swatch (settings/Editors.lua's chooser), then
          Duplicate and Delete. A built-in: what it is, its Enabled row, and Customize.
Callouts  a user group's: Add callout (the callout popup, blank), Reuse existing callout with
          Add, then its callouts as a drag-to-reorder list, each row the handle, the icon, the
          name and channel, an edit glyph and a remove glyph. A built-in: a Show checkbox per
          callout, the hidden-callouts editor.
When      settings/Groups_When.lua
Preview   the active-now line, then every callout baked for the current or previewed situation
```

**When** (`settings/Groups_When.lua`): one row per condition, each with an enable checkbox. Content,
difficulty, group, leadership, class, specialization (the classes picked, else the player's) and
role are checkbox rows; the key level is a lowest and highest box; instances, battlegrounds and
characters (`Name-Realm`) are the library's IdList, each with an add-the-one-you-are-in button, which
reads where the player is at the click and says so when that is nowhere; a typed id is a positive
whole number, and a typed character takes the client's case (`bob` reads `Bob-<your realm>`). The
tab starts with the active-now line. A refused key level or X/Y offset prints its reason and the box
goes back to the stored value; a refused Name (any field the library draws) prints its reason too.
A built-in group is read-only: its group rows refuse every write,
so the page draws only its overlay and offers Customize.

**The icon** (General, a user group): under the Icon box, the icon as the pad and the dial draw it (a
glyph in its color, a question mark for none), **Choose icon…** and the **Icon color** swatch. A
click on the icon or on Choose icon… opens the icon browser (below) over the settings window; its
Choose writes the group's icon and color as one act (`Library.SetIcon`), so a game icon or a marker
chosen over a colored glyph clears the color in the same write. The swatch opens Blizzard's color
picker and writes `group.iconColor` through the seam; it is live only while the icon is a glyph
(white is none). The color is drawn with the icon, never as a text box of its own.

**Callouts** (a user group): the group owns its callouts. Each user callout sits in exactly one
user group, so there is no Callouts page and no shared callout.

- **Add callout** opens the callout popup with blank fields (an empty name and text, Smart group,
  no icon). Save puts the new callout at the end of the group; Cancel makes nothing.
- **Reuse existing callout** is a dropdown of every callout the player could copy: the user
  callouts as `<group>: <callout>` (this group's own included), then the built-in ones as
  `<set>: <callout>` or `<set>: <child>: <callout>`. Picking alone adds nothing; **Add** puts an
  independent copy at the end of this group (`Library.AddToGroup` always copies), so editing the
  copy leaves the original as it is.
- **The list** is the drag-to-reorder list (`Ed.ReorderRows`). The edit glyph (the catalog's `edit`
  mark) opens the popup filled in; the remove glyph (the `transmog-icon-remove` atlas) asks first,
  then deletes the callout, since nothing else holds it. Both carry a tooltip.
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
body     Name, Text, Channel, Icon (the callout.* member rows' labels and help), an info
         glyph right of the Text label (its tooltip lists the tokens), the icon (as drawn) with
         Choose icon… and its color swatch, Preview (the baked line and its bytes, or why it
         sends nothing, and any lock), a gap, then Cancel and Save, and under them the line
         that names a field Save refused
```

- **The draft.** The popup edits a plain copy of the callout's four fields and its icon's glyph
  color (blank for Add). Choose icon… opens the icon browser over the popup; its Choose writes the
  draft's icon and color, and the swatch writes the draft's color. An icon that is no glyph (chosen,
  or typed in the Icon box) drops the draft's color. Every control writes the draft, never the
  profile, and Preview bakes the draft, so it follows each edit before anything is saved. A text
  box commits to the draft on Enter
  (or its Okay button), as on every page; what a box shows that Enter did not commit is taken into
  the draft before any other draft write, before a seam write's refresh and by Save, so clicking
  Save commits it and a pick never wipes it.
- **The token glyph.** The library catalog's `info` mark, right of the Text label, sized to the
  label's font (14 to 16 px) and vertically centered on it. Its tooltip lists every token the
  draft's channel offers, one line each (`Settings.Callouts.TokenHelp`), read when it shows, so it
  follows a channel picked since: `{group1} … {group8}` is one line, only when the channel can
  resolve to Raid, and `{spell:ID}` is last. Tokens are typed into the text; nothing inserts them.
  The glyph is kept on the Text box's frame and reused, re-anchored on every render, and hidden
  when the box is released (an `OnRelease` callback, the library's landing-logo pattern), so a
  frame AceGUI hands to another EditBox never shows it.
- **Save** checks the draft with the member rows' own validators (the name, the text and its
  length, the channel, the icon, the icon's color). A field that fails keeps the popup open and names the field;
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
in the callout popup and on a user group's General tab. It is not a page. Its window is the popup's
(`settings/ModalWindow.lua`: Blizzard's `SettingsFrameTemplate`, titled "Ka0s Quick Comms", its close
X, the gold header), 560 × 550, with its own full-screen catcher in the `FULLSCREEN` strata, above the
popup and the popup's catcher (`DIALOG`): it is modal to whatever opened it. Only one browser exists,
built on its first open. The EllesmereUI skin paints it as it paints the popup.

```
window   Blizzard's settings window, titled Ka0s Quick Comms                 (its close X)
header   Choose an icon, the gold rule under it
tabs     [ Markers ][ Game icons ][ Glyphs ]   (the library's tab strip)
toolbar  Game icons: Show (All / Spells / Items). Glyphs: Icon color (the swatch). At the
         right, how many icons the tab holds.
grid     12 × 7 icons and a scrollbar, 10px under the toolbar; the mouse wheel scrolls it
footer   the selected icon (a glyph in the color) and its name, then Choose and Cancel
```

- **Markers**: the eight raid target markers. **Game icons**: every
  icon the macro icon selector offers (the loose lists and then `GetMacroIcons` for spells, the
  same for items, through `Compat.MacroIcons`), as texture ids, each once, filtered All / Spells / Items; until the client has
  loaded its own icon list the tab says so, and the list is read again on the next visit. **Glyphs**:
  every icon of the LibKa0s catalog (`NS.IconNames`), named from its catalog key ("arrow-circle-down"
  reads "Arrow circle down"; the curated glyphs keep their localized labels).
- **The grid is virtualized**: 84 cells are built once and re-dressed from the tab's list as it
  scrolls, so the thousands of game icons cost no more frames than a short tab.
- **Pick**: hovering an icon names it (its label, or "Texture id N" for a game icon); a click selects
  it (gold behind it, named in the footer); a double-click or **Choose** chooses it. The stored icon
  is preselected, and its tab opened and scrolled to it. No icon, or one no tab lists (a built-in
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
strip    [ General ][ Groups ][ Layout ][ Look ]
General  Preview as (page-wide, first), Name, Enabled, then Unlock (or Lock) pads and Delete pad
Groups   Show groups as, then the pad's groups as a drag-to-reorder list with a remove glyph
         (its priority order; it takes the group off the pad and asks nothing), then Add a group
Layout   orientation, grid columns, growth, chip style, scale, spacing, chip width, then
         Position: X and Y and Reset this pad's position
Look     visibility, fade and faded alpha; then Font (face, size, color with Use class color,
         flags, shadow), Border (style, thickness, color with Use class color) and Background
         (its color with Use class color), each composed by the options library (options-ui-§16,
         §17) under its own heading
```

X and Y write the whole `pad.point` row, the same one the drag strip writes; a drag on screen
updates the boxes.

## Comms Dial

`settings/Dials.lua`, one dial at a time.

```
band     [ Dial v (picker) ][ New dial ]
strip    [ General ][ Groups ][ Wheel ][ Binding ][ Preview ]
General  Preview as (page-wide, first), Name, Enabled, then Delete dial
Groups   Show groups as (Categories or Flat), the depth-3 warning (spec §11.3), then the dial's
         groups as a drag-to-reorder list with a remove glyph (its priority order, spec §7; it
         takes the group off the dial and asks nothing), then Add a group
Wheel    wedges per ring, open at, then Position: X and Y and Reset this dial's position
Binding  how Relaxed mode works, the key capture, and the key's line (what it opens, or the WoW
         binding it shares, spec §9.4 / §18)
Preview  each ring as the current or previewed situation builds it, wedge by wedge
```

- **General:** Preview as… draws dial 1 in another situation (its wedges disarmed); Name and Enabled
  are the `dial.name` and `dial.enabled` rows; Delete dial asks first, keeps the dial's groups and
  callouts, and releases its key.
- **Groups:** Show groups as is `dial.mode` (Categories or Flat). The warning names each battleground
  node set that would open three rings deep because a group above it is active there too
  (`Dial_Layout.DeepGroups`, built under that battleground's preview). The list is the dial's
  priority order; Add a group appends one.
- **Wheel:** Wedges per ring is `dial.slices` (4, 6, 8 or 12; a ring that holds a ring takes 8 on a
  12-wedge dial), Open at is `dial.openAt` (its place or the cursor). X and Y write the whole
  `dial.point` row; a refused offset says why and puts the box back. There is no depth control
  (owner ruling R5): depth is spec §11.3's limit, warned about on the Groups tab.
- **Binding:** a line on how Relaxed mode works; the Key capture box (AceGUI's `Keybinding`, the
  `dial.key` row; Escape in it clears the key); the key's line, which says what the key opens or
  names the WoW binding it shares by its menu label (`Compat.BindingAction`, then
  `Compat.BindingLabel`; the dial's key still wins while the addon is enabled); for a dial that is
  off, or with Quick Comms stood down, it says the key opens nothing; with no key of its own it names
  a key bound to the dial's Open Comms Dial entry (`Compat.BindingKey`). A place line names which
  Open Comms Dial entry this dial is (its place in the dial list, so it moves when a dial above it is
  deleted), or says a dial past the fourth has none.
  A key another dial has, or one the open dial uses (Escape, the mouse buttons and wheel, 1–8
  without a modifier), is refused, and the box goes back to the stored key.
- **Preview:** each ring, wedge by wedge, with its compass word (a clock position past eight
  wedges), marking the ring the dial opens on
  and the wedges that open a ring. It is a listing (owner ruling R3); the drawn dial is the
  in-game preview (test mode, Preview as…).

The page's Defaults puts groups-as, wedges per ring and open at back to their defaults and turns the
dial on, in one act (`Library.Batch`); the name, groups, key and position are kept.

## Share

`settings/Share.lua`.

```
strip     [ Export ][ Import ][ Built-in ]
Export    what travels; a checkbox per group, Comms Pad and Comms Dial, under a heading per
          kind (a callout travels inside its group); what the string will hold; Export (the string opens, selected, in the copy
          window) and Clear
Import    a paste box (its Accept checks the string); the report (spec §15 step 5); Import and
          Clear
Built-in  one line per shipped set: an Enabled checkbox named after the set, then Customize (or
          Edit the copy) and Choose callouts
```

The ticks and the checked string are session state, cleared by a profile switch. Export and Import
refuse in combat with one line (the panel is locked in combat anyway). Defaults resets the Built-in
tab only.

## Still to come

Quick mode's delay and tap action with the C7 upgrade.
