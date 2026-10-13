# Settings panel — Ka0s Quick Comms

Built on LibKa0s-Options from the descriptor in `settings/OptionsSetup.lua`. The category registers
eagerly at `OnEnable`; each page's body builds on its first show (options-ui-§1/§5).

| Page | Covers |
|---|---|
| Ka0s Quick Comms (landing) | The logo, the TOC notes line and the slash command list, drawn by the library's `BuildLandingPage` |
| General | `Master controls` |
| Profiles | AceDBOptions: switch, copy, reset and delete profiles |

## General → Master controls

Composed by `Helpers.MasterControls` from one declaration (`settings/Panel.lua`), canonical rows in
canonical order (options-ui-§15). Nothing positionable exists yet, so the block is `frameless`
(Master scale, Master alpha, Lock frame and Reset position are omitted) and General visibility is
omitted too: there is no display for it to show or hide.

| Left | Right |
|---|---|
| Enable Ka0s Quick Comms (`enabled`) | Debug console (`state.debugConsole`, session) |
| Minimap button (`global.minimap.shown`) | |
| Reset all settings (button, asks first) | |

Every row writes through the one seam (`NS.SchemaRuntime.Set`), and its reaction is the same one
the CLI, the launcher and the host verbs trigger (`Settings.REACTIONS` in `settings/Schema.lua`).
The header's Defaults button and Reset all settings both open the confirmation popup; the global
reset is a profile reset and never touches the minimap button (options-ui-§12, launcher-§3).

## Still to come

The Comms Pad brings back General visibility, the frame rows and Test mode (spec §10.3/§10.4). The
design's other pages (spec §13.1): General → Behavior, Callouts, Groups, Pads, Dials and Share. Each
page renders through the tabbed renderer, and every row carries a `group`.
