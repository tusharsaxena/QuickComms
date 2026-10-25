# 03 — In-client smoke tests (review of 2026-10-25)

Run these **in the game client**, after the changes in `02_PROPOSED_CHANGES.md` have landed. Headless suites are not repeated here. After the changes land, re-run them once from the repo root as pre-flight:

```
~/.claude/dev-copilot/bin/ka0s-bounded lua5.1 tests/run.lua      # 0 failed; count equals docs/test-cases.md Total
~/.claude/dev-copilot/bin/ka0s-bounded luacheck .                # 0 warnings / 0 errors
~/.claude/dev-copilot/bin/ka0s-bounded lua5.1 tests/perf.lua     # 0 assertions failed (C-01)
```

## Pre-flight (in client)

- **Client:** Retail, `## Interface: 120105` (12.1.5).
- **Install:** QuickComms installed through the AddOns symlink.
- **Errors visible:** `/console scriptErrors 1`, then `/reload`. Keep BugSack or the default error frame visible.
- **Debug log:** `/qc debug on`, so the `RES`, `Situation`, `Pad`, `Dial` and `Queue` lines are in the console (`/qc debug` opens it).
- **Character:** one with a current-season Mythic+ key, plus a raid group or LFR access for REV-3B. A level-capped character for the battleground-free checks.
- **Profile:** default, with the shipped looks: pad button shine "Gloss fade", dial slice shine "Glass orb".

## Per-change tests

### REV-1 — C-01: the pad shine paint is guarded

- **Change covered:** C-01. The pad button shine repaints only when its look or size changes.
- **Setup:** default profile, one pad showing at least 8 buttons (for example In Group while grouped).
- **Steps:**
  1. Open the settings, go to Pad → Buttons → Shine, and set the look to **Bevel**. Look at the pad.
  2. Set it to **Gloss fade**. Look at the pad.
  3. Set Buttons → Width to 140, then back to 100.
  4. Join or leave a group, so the situation changes and the pad rebuilds.
  5. `/reload`.
- **Expected:** each step shows the selected shine across the whole of every button, with no stale look left on any button. After step 3 the shine spans the new width, then the old one. After step 4 the shine is still present on every button, including buttons that are new in the rebuilt layout. No Lua error.
- **Pass / Fail:** pass if every button wears the selected look at the right width after every step.

### REV-2 — C-02: complexity refactors are behavior-preserving

- **Change covered:** C-02. 19 functions are refactored under CCN 15.
- **Setup:** default profile.
- **Steps:**
  1. `/qc preview list`. Then `/qc preview` with each of: one `mplus:` key, one `raid:` key, one battleground key, `arena`, `world`, then `off`. This exercises `P.EditPresetKey` and `V.PreviewLines`.
  2. On the Groups page, select a seeded raid group and turn Preview while editing on. The preview window's dropdown shows the raid preset (`P.EditPresetKey`). Then select In Group: the dropdown shows Current.
  3. Open a dial with its key, then turn the mouse wheel on a paged ring (`DS.Load`, `Dial.Apply`, `R.PointerUpdate`). Hover each slice.
  4. On the Groups page When tab, open the Difficulty and Instances drawers and read each summary line (`W.Summary`). Type an instance name in the When CLI: `/qc set group.when instances Magisters' Terrace` (`W.ResolveValue`).
  5. On the Groups page Callouts tab, press Reuse (`G.ReusableCallouts`).
  6. Create a callout whose text is `{rt8} {coords} {me} {spell:2825}`, then `/qc check <id>` (`expandOne`).
- **Expected:** the same outputs as before the change. Preset labels, summary lines, Reuse lists and `/qc check` lines are identical to a pre-change run (capture both). No Lua error.
- **Pass / Fail:** pass if no output differs from the pre-change capture.

### REV-3A — C-03: a Mythic+ key completion clears the padlocks

- **Change covered:** C-03. Restrictions re-read on `CHALLENGE_MODE_COMPLETED`.
- **Setup:** a pad and a dial holding a **Say** or **Yell** callout. Enter a Mythic+ key.
- **Steps:**
  1. During the key, confirm the Say button shows its padlock and the header shows the lockdown chip.
  2. Kill the last boss and complete the key. Stay out of combat afterwards.
  3. Within 2 s of the completion banner, look at the pad and the dial (open it with its key).
  4. Press the Say button once.
- **Expected:**
  - By step 3 the padlock and the lockdown chip are gone.
  - The debug console shows a `RES` line with cause `CHALLENGE_MODE_COMPLETED` or `CHALLENGE_MODE_COMPLETED+late`.
  - Step 4 sends the line, which appears in /say, and prints **no** "may not have been sent" note.
- **Pass / Fail:** pass if the padlock clears without any other event and the press is tracked as a send.

### REV-3B — C-03: a boss kill clears the encounter lock

- **Change covered:** C-03. Restrictions re-read on `ENCOUNTER_END`.
- **Setup:** a raid or LFR boss, with the same Say callout as REV-3A.
- **Steps:** pull the boss and kill it. After `PLAYER_REGEN_ENABLED`, wait 1 s and look at the pad.
- **Expected:** no padlock and no lockdown chip. The debug console shows a `RES` line with cause `ENCOUNTER_END` (or `+late`) whenever the regen edge alone did not clear it.
- **Pass / Fail:** pass if the lock clears. Record whether `ENCOUNTER_END` or the regen edge cleared it, because that tells us how often F-003 was reachable before the fix.

### REV-3C — C-03: disabling stops the new event and timer

- **Change covered:** C-03 under slash-commands-§7.
- **Steps:** `/qc disable`, then `/etrace`. Kill a training dummy encounter, or zone into an instance and leave.
- **Expected:** `/etrace` shows `ENCOUNTER_END` firing, but no QuickComms handler runs, and no `RES` line is logged. `/qc enable` restores the behavior.
- **Pass / Fail:** pass if nothing is logged while disabled.

### REV-4 — C-04 and C-05: docs and lint

- No in-client test. Headless pre-flight only (`luacheck .` 0/0).

### REV-5 — C-06: unchanged buttons stay armed across a rebuild

- **Change covered:** C-06. Release no longer disarms buttons that are about to be re-armed.
- **Setup:** a pad with 6 or more live callouts, in a party.
- **Steps:**
  1. Change an unrelated setting, such as the pad's Window border, so the pad rebuilds. Press each button.
  2. Switch the pad to groups as tabs, so fewer buttons show, then back.
  3. With tabs showing a shorter group, `/run for i=1,200 do local b=_G["QuickCommsSend"..i] if b and not b:IsVisible() and b:GetAttribute("type") then print("ARMED HIDDEN", i) end end`.
  4. Enter combat with a training dummy and press each visible button.
- **Expected:** every press in steps 1 and 4 sends its line once. Step 3 prints nothing. There is no `ADDON_ACTION_BLOCKED` and no "Interface action failed because of an AddOn".
- **Pass / Fail:** pass if no hidden button is armed and every visible one sends.

### REV-6 — C-07: General only when channel 1 is General

- **Change covered:** C-07.
- **Setup:** a callout on the General channel kind, out of any instance.
- **Steps:**
  1. With default channels, press it.
  2. `/leave 1`, then `/join QCTest` so that a custom channel takes slot 1. Check with `/chatlist`, then press it.
  3. `/leave QCTest`, then `/join General` (or re-zone).
- **Expected:** step 1 sends to General. Step 2 sends to **Say** (or, if the label option was chosen, the UI and tooltip say "Channel 1" and it sends to QCTest as labeled). In no case does a "General" callout reach a custom channel silently.
- **Pass / Fail:** pass per the option chosen in C-07.

### REV-7 — C-08: dead helpers removed or wired

- **If `UsesGroupToken` was wired:** in a party (not a raid), a callout containing `{g1}` shows its raid-only note in the tooltip. In a raid it has none.
- Otherwise, headless only.

### REV-8 — C-10: child groups still sort A–Z

- **Steps:** open Alterac Valley's set on the Groups page and on a pad (`/qc preview` with the Alterac Valley key).
- **Expected:** children are listed A–Z, case-insensitive, identically on the page, the pad and the dial ring.
- **Pass / Fail:** pass if the order is identical across all three.

### REV-9 — C-11: re-vendor v1.78.0, then cross-addon

- **Setup:** QuickComms on LibKa0s v1.78.0, LootHistory installed and enabled.
- **Steps:**
  1. Type `/qc`, `/quickcomms`, and each other installed roster addon's root. Each reaches its own addon.
  2. Open Settings → AddOns. Ka0s Quick Comms appears once, with its pages (General, Groups, Comms Pad, Comms Dial, Profiles) once each.
  3. `/qc diagnostics`. The library line reports the v1.78.0 minors.
  4. With LootHistory disabled and `/reload`, repeat 2 and 3.
- **Expected:** identical behavior in both sessions. No Lua error.
- **Pass / Fail:** pass if every root dispatches to its own addon and the pages appear once each.

## Regression suite

1. `/reload` cleanly, with no error. `[Init]` appears in the debug console with `schema v9`.
2. Log out and in: the pads restore their positions; the `padsHidden` state from `/qc toggle` persists per character.
3. Enter combat with a pad and a dial open: presses send, and the dial opens and sends from its key in combat. Leave combat: a rebuild held for combat drains (`Queue … drained`) and the stale hint clears.
4. Switch profiles with `/qc profile <other>` and back: surfaces rebuild from each profile.
5. Open every settings page and tab once. Toggle Master controls Enabled off and on: disabling hides every pad and dial (in combat, at combat end), and re-enabling rebuilds from current settings.
6. Turn test mode on with `/qc test`, then off. Turn Preview as on and off.

## Taint-specific tests

Required because C-06 touches the secure release path.

- In combat, press pad buttons and dial wedges 20 times. Then `/qc test` (refused in combat).
- **Expected:** no "Interface action failed because of an AddOn" and no `ADDON_ACTION_BLOCKED` for QuickComms.

## Performance spot-checks

Required because of C-01, C-06 and C-10.

- **Offline evidence:** the pre-flight `tests/perf.lua` run, comparing `padRebuild12`, `dialOpenClose` and `situationRefresh` against today's figures (87026.8 / 2317.1 / 2016.0 B/iter), same machine.
- **In client:** `/qc perf`, following the standard's two-arm capture protocol.
  1. Clean arm first, then the suspend arm, with no `/reload` between arms and the same addon set.
  2. Windows opened on the player's combat state; include several pad rebuilds (group join and leave) and a dial held open for 30 s.
  3. Read the **bucket** figures for `padLayout`, `bakeSurface` and `dialRender`, not the frame-time delta.
  4. Record it as a frozen bundle under `docs/perf-analysis/<YYYYMMDD-HHMMSS>/` through `/dev-copilot:wow-perf-analysis`. That would be the first in-client capture for this addon.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| REV-1 (C-01) | | | |
| REV-2 (C-02) | | | |
| REV-3A (C-03) | | | |
| REV-3B (C-03) | | | |
| REV-3C (C-03) | | | |
| REV-4 (C-04, C-05) | | | headless only |
| REV-5 (C-06) | | | |
| REV-6 (C-07) | | | |
| REV-7 (C-08) | | | |
| REV-8 (C-10) | | | |
| REV-9 (C-11) | | | |
| Regression 1-6 | | | |
| Taint | | | |
| Perf capture | | | |
