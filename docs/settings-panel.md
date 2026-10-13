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
| Share | `Built-in` (Export and Import in phase 5) |
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
| Reset position (button: every pad back to its default place; the dials join in phase 4) | Reset all settings (button, asks first) |

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
         token, then what it sends here (the baked line and its bytes, or why it sends
         nothing, and any lock), then Duplicate and Delete
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
          then Duplicate and Delete. A built-in: what it is, its Enabled row, and Customize.
Callouts  a user group's callouts as a drag-to-reorder list with Remove, then Add a callout (a
          built-in callout is copied in first). A built-in: a Show checkbox per callout, the
          hidden-callouts editor.
When      settings/Groups_When.lua
Preview   the active-now line, then every callout baked for the current or previewed situation
```

**When** (`settings/Groups_When.lua`): one row per condition, each with an enable checkbox. Content,
difficulty, group, leadership, class, specialization (the classes picked, else the player's) and
role are checkbox rows; the key level is a lowest and highest box; instances, battlegrounds and
characters (`Name-Realm`) are the library's IdList, each with an add-the-one-you-are-in button. The
tab ends with the active-now line. A built-in group is read-only: its group rows refuse every write,
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
Look     visibility, fade and faded alpha
```

X and Y write the whole `pad.point` row, the same one the drag strip writes; a drag on screen
updates the boxes.

## Share

`settings/Share.lua`. Phase 3 ships the Built-in tab; Export and Import join it, ahead of it, in
phase 5.

```
strip     [ Built-in ]
Built-in  one line per shipped set: an Enabled checkbox named after the set, then Customize (or
          Edit the copy) and Choose callouts
```

The page edits no single instance, so its band has no picker. Choose callouts opens the set on the
Groups page's Callouts tab. Defaults turns every set back on and shows all of their callouts.

## Still to come

The Comms Dial page (phase 4) and Share's Export and Import tabs (phase 5).
