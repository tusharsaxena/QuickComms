# Research 03: How Quick Comms fits the Ka0s standard

Quick Comms is a Ka0s addon, so the [Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards) (v2.78.3 at time of writing) applies in full. This note lists what the standard already decides, so the brainstorm can concentrate on what it leaves open.

## Already decided by the standard

| Area | What applies to Quick Comms |
|---|---|
| Identity | TOC title `Ka0s Quick Comms`, folder and repo `QuickComms`, MIT, Retail only, own 128×128 TGA icon, SavedVariables `QuickCommsDB` (AceDB, profiles) |
| Slash | `/qc` (collision check pending) plus `/quickcomms`. Reserved verbs: help, get, set, list, reset, resetall, config, version, debug, enable, disable, perf, diagnostics. Chat tag `|cff00ffff[QC]|r` |
| Stack | Ace3 (AceAddon, AceDB, LDB, LibDBIcon, plus AceEvent/AceTimer/AceGUI when used) and LibKa0s vendored whole. Export/import uses LibSerialize + LibDeflate |
| Settings | Blizzard Settings canvas with raw AceGUI via LibKa0s-Options. A **landing page** (logo, tagline, slash list), then **General**, whose first tab is **Master controls** (Enable / Visibility, Scale / Alpha, Lock / Debug, Minimap / Test mode, Reset position / Reset all). Breadcrumb `Ka0s Quick Comms ▸ Page`. A **nav rail** for editing one item out of many. Settings can't open in combat. |
| Widgets | LibKa0s `ReorderList` (*required* for any ordered setting, which covers callout order in a group and group priority in a layout), `Dropdown`, `Autocomplete`, `DragHandle`, `CopyWindow` (export strings) |
| Icons | Around 110 Open Iconic TGAs in LibKa0s (`chat`, `speech-bubble`, `people`, `target`, `warning`, `shield`, `heart`, `map-marker`…), plus any game icon by fileID chosen in the editor |
| Windows | Plain non-secure frame, `UISpecialFrames`, the Ka0s window edge, a gold title, lazily built tabs, title-bar icon buttons |
| Movable displays | Need a **preview / test mode** with placeholder content (TEST MODE label) and a LibKa0s `DragHandle` when unlocked |
| Combat | Secure writes gated on `InCombatLockdown()` and replayed on `PLAYER_REGEN_ENABLED`. Protected APIs (macros, bindings) live in **one** module. Secret values go through `SafeToString`. |
| Required plumbing | Launcher (left-click settings, right-click toggles), debug console, `/qc diagnostics`, perf harness, total disabled state, enUS locale table, ID-based matching |

## Precedents to reuse

- **DropWatcher `modules/Situations.lua`:** a pure classifier for instance type, difficulty, M+, delve, group and PvP that broadcasts `SITUATION_CHANGED`. This is almost exactly the situation engine Quick Comms needs.
- **DropWatcher `modules/Messaging.lua`:** template tokens, a length check, a send queue. `core/Compat.lua` sends through `C_ChatInfo.SendChatMessage` inside a pcall.
- **MultiMeters `EXPORT_CHANNELS`:** one row per channel, default SELF, and AUTO removed. Its lesson is to make "who will see this" obvious before anything is sent.
- **KickCD `IconGrid*`:** a pooled, movable icon grid split into Layout, Render and Visibility. A natural base for the Comms Pad.
- **PanelMaster `settings/PanelEditor.lua`:** a picker plus a create box above a tabbed editor, which fits the callout and group editors.
- **PanelMaster `modules/Unlock.lua`:** unlocking in combat is deferred and replayed after combat.
- **LootHistory `modules/Browser.lua`:** the reference skinned window (gold active tab, grey idle tab).

## What the standard leaves open

These are the questions this brainstorm has to answer:
- how the data model is shaped
- what the dial feels like
- how the pad looks
- how situations resolve
- what happens during lockdown
