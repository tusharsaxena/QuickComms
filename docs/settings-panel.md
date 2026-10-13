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

## Still to come

The design's other pages (spec §13.1): General → Behavior, Callouts, Groups, Pads (with each pad's
X/Y rows), Dials and Share. Each
page renders through the tabbed renderer, and every row carries a `group`.
