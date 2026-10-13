# Settings panel — Ka0s Quick Comms

Built on LibKa0s-Options from the descriptor in `settings/OptionsSetup.lua`. The category registers
eagerly at `OnEnable`; each page's body builds on its first show (options-ui-§1/§5).

| Page | Covers |
|---|---|
| Ka0s Quick Comms (landing) | The logo, the TOC notes line and the slash command list, drawn by the library's `BuildLandingPage` |
| General | `Master controls`, `Behavior` |
| Callouts | One callout: `General`, `Used by` |
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

## Callouts

`settings/Callouts.lua`, one callout at a time.

```
band     [ Callout v (picker)        ][ New callout ]
strip    [ General ][ Used by ]
General  Name, Text, Channel, Icon (the member rows, settings/SchemaMembers.lua), Insert a
         token, Choose an icon (settings/Editors.lua's picker), then what it sends here (the
         baked line and its bytes, or why it sends nothing, and any lock), then Duplicate and
         Delete
Used by  every group that holds it, each a link to the Groups page
```

The token picker offers `{group1}`…`{group8}` only when the channel can resolve to Raid. The byte
count follows each committed write (Enter in the Text box), not each keystroke. Built-in callouts
are not listed: a group copies one when it takes it, and the copy is edited here.

## Groups

`settings/Groups.lua`, one group at a time, a user group or a built-in set.

```
band      [ Group v (picker; a green dot marks a group active now) ][ New group ]
strip     [ General ][ Callouts ][ When ][ Preview ]
General   Preview as (page-wide, first), then Name, Icon, Enabled, Open the dial on this group,
          Choose an icon (settings/Editors.lua's picker), then Duplicate and Delete. A built-in: what it is, its Enabled row, and Customize.
Callouts  a user group's callouts as a drag-to-reorder list with Remove, then Add a callout (a
          built-in callout is copied in first). A built-in: a Show checkbox per callout, the
          hidden-callouts editor.
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

## Comms Pad

`settings/Pads.lua`, one pad at a time.

```
band     [ Pad v (picker) ][ New pad ]
strip    [ General ][ Groups ][ Layout ][ Look ]
General  Preview as (page-wide, first), Name, Enabled, then Unlock (or Lock) pads and Delete pad
Groups   Show groups as, then the pad's groups as a drag-to-reorder list with Remove (its
         priority order), then Add a group
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
         groups as a drag-to-reorder list with Remove (its priority order, spec §7), then Add a
         group
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
Export    what travels; a checkbox per callout, group, Comms Pad and Comms Dial, under a heading
          per kind; what the string will hold; Export (the string opens, selected, in the copy
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
