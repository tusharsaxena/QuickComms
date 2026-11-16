# 02 Candidates (owed in phase [3], not interviewed in this run)

This re-vendor is the copy and bundle half only. The candidates below are listed for the run's phase [3]
adoption plan (Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/03_ADOPTION_PLAN.md`). Each one
binds this addon when it adopts the feature, under WowAddonStandards v2.113.0, not at this re-vendor (the owner's
ruling Q6 of 2026-11-16). Site counts come from the run's research note R8 and a re-read on 2026-11-16. The
adoption run re-checks them.

| Issue | Surface | Class | What this addon would change | Sites today |
|---|---|---|---|---|
| LibKa0s#92 | `LibKa0s-Tooltip-1.0` placers (`PlaceBeside`, `PlaceAttached`) | C (new major) | Every `GameTooltip:SetOwner` site, with the corner anchors removed | 8: `modules/Dial_Render.lua:398`, `modules/Pad_Render.lua:309,324`, `modules/PreviewWindow.lua:99,126`, `modules/Pad.lua:579`, `settings/CalloutPopup.lua:289`, `settings/Groups_When.lua:380` |
| LibKa0s#79 | `D:Report` and `D:Serialize` | B | Move the multi-line report verbs onto the seam (confirm each against its handler) | `check`, `why`, `probe` (`settings/Slash.lua:65,71,73`) |
| LibKa0s#86 | `W.HeaderButtons` with the settings mark | B | The addon's own windows' title marks onto the strip | `modules/PreviewWindow.lua`, `settings/ModalWindow.lua` (own close) |
| LibKa0s#87 | `Sim.SAMPLE`, `Sim.Sample(client)` | C | Shared sample characters where the addon shows made-up people | Likely none: test mode's placeholders are the shipped callouts (`modules/Surfaces.lua:254`), not names. Confirm at adoption |
| LibKa0s#85 | `LibKa0s-Callout-1.0` | C | Evaluate as a consumer | The plan recommends **not now** |
| LibKa0s#82 | Host `*.hot` tokens at the contrast floors | B | Check the addon's own hot aliases | None found in `core/SkinSetup.lua`. Confirm at adoption |

Not owed here: LibKa0s#88 (docked strip) and LibKa0s#89 (`W.Footer`). The addon has no test strip and no window
footer. LibKa0s#80 (`W.Bar`) and LibKa0s#81 (`extraEntries`) are Ka0s Skill Master's alone, by the owner's
ruling Q1.

Delivered on the copy alone (class A): header marks on every library window (debug console, copy window, perf
panel, skin picker, icon browser window), the library's own tooltips placed by the placers, the console's 24 px
footer and plain-text Copy, the skin color moves (#82, #84) and the slider-box revert (OptionsWidgets 46).
