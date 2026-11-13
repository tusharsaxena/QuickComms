# 03 — Smoke tests (review of 2026-11-11)

These are the in-client checks for this review's changes. The branch's own feature checks (ACTION-*,
PING-*, MARK-*, EMOTE-9/10, THANK-*, FOREVER-26) live in `docs/smoke-tests.md` under Pending sign-off
and are not repeated here.

## Pre-flight

- Retail (Interface 120105) and WoW Forever (16001), the addon symlinked into each client's AddOns.
- `/console scriptErrors 1`. Have BugSack or the default error frame visible.
- Headless, after the fixes land: `lua tests/run.lua`, `KA0S_KIT_CLIENT=forever lua tests/run.lua`,
  `luacheck .` and `lua tests/perf.lua` (0 failed assertions).
- A second player, or a friendly stranger in a city, who can cast a long buff on you (Power Word:
  Fortitude, Arcane Intellect, Mark of the Wild) for the toast checks.

## Per-change tests

### S-1 — C-01: the pad still bakes every action

- **Setup:** a pad with a callout that has a Line, an emote and a marker, and one that has a ping alone.
- **Steps:** 1. `/reload`. 2. Hover each button. 3. Target a mob, press each one.
- **Expected:** the tooltip lists every action. The press sends the line, plays the emote and marks or
  pings the target. No Lua error.
- **Pass:** all three are true on both clients.

### S-2 — C-04: the toast's place is kept

- **Setup:** auto-thank on, open world.
- **Steps:** 1. Get buffed by a stranger. 2. Drag the toast to a corner. 3. `/reload`. 4. Get buffed again.
  5. `/qc reset thank.position`, then get buffed again.
- **Expected:** step 4's toast appears in the corner. Step 5's toast appears at the default place
  (top centre, below the pad).
- **Pass:** both places are right, with no error.

### S-3 — C-05: auras in combat still thank after the fight

- **Setup:** auto-thank on, open world, a target dummy or a mob.
- **Steps:** 1. Enter combat. 2. Get buffed by a stranger during the fight. 3. Leave combat.
- **Expected:** no toast in combat. One toast for the buff within a second or two of leaving combat.
- **Pass:** exactly one toast after combat, none during it.

### S-4 — C-06: a drag cut short by combat

- **Setup:** a thank toast on screen.
- **Steps:** 1. Start dragging the toast and keep the mouse button held. 2. Get pulled into combat (have
  a mob hit you). 3. Release the button. 4. Leave combat and get buffed again.
- **Expected:** step 4's toast fades over its last seconds and does not just vanish at full alpha.
- **Pass:** the fade is visible. Also note whether the toast frame got `OnDragStop` after it was hidden
  (this settles F-006's "plausible").

## Regression suite

- `/reload` cleanly; login to first-time defaults on a fresh profile; no errors from ADDON_LOADED
  through PLAYER_ENTERING_WORLD.
- Enter and leave combat with a pad, a dial and a thank toast on screen: the toast hides at combat
  start and comes back after, and the pad still sends in combat.
- `/qc disable` then `/qc enable`: no toast while disabled. Auto-thank works again after enable.
- Open the Auto-thank settings page, toggle every row once, then Defaults: the toast's position is kept.

## Cross-addon

Type each roster addon's root that is installed (`/qc`, `/quickcomms` and the others) and confirm each
reaches its own addon. Open Settings > AddOns and confirm each addon appears once, and each multi-page
addon's pages appear once each.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| S-1 (C-01) | | | |
| S-2 (C-04) | | | |
| S-3 (C-05) | | | |
| S-4 (C-06) | | | |
| Regression | | | |
| Cross-addon | | | |
