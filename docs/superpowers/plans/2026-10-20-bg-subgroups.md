# Battleground sub-groups (2026-10-20) Implementation Plan

**Goal:** Owner batch of 2026-10-20: child groups for every Alterac Valley general, captain, bunker, tower and graveyard (Attack and Defend each), Our base and Enemy base for Isle of Conquest, and objective child groups for Deephaul Ravine, Ashran, Twin Peaks, Warsong Gulch, Wintergrasp and Seething Shore.

**Architecture:** QuickComms only, branch `feat/2026-10-20-groups-fixes` (pushed; carries the preview-echo fix 929760c and its follow-ups). No LibKa0s change: the glyph catalog of v1.74.0 is already vendored. Not merged here.

**Spec:** this plan. The previous batch, for the model this builds on: `docs/superpowers/plans/2026-10-19-groups-polish.md`.

## Owner decisions

- Faction: NEUTRAL wording. A callout reads the same for either faction (our or enemy base, our or enemy flag carrier), and every Alterac Valley objective gets both Attack and Defend. No faction condition.
- Alterac Valley captains (Balinda Stonehearth, Galvangar) are included: 19 child groups.
- Isle of Conquest gets two children beside its five nodes: Our base (Defend our base, Walls down at our base) and Enemy base (Attack the enemy base, Walls down at the enemy base).

## Builder calls

- B1 Data. `defaults/BuiltIns_Battlegrounds.lua` gains a helper for a set whose children carry their own callout rows (the AV, flag-map and Ashran shapes); the node sets keep the INC rows. A child's callout names are short ("Attack", "Defend"); its message names the objective ("Attack Iceblood Tower"). Shipped ids stay stable: a flat set's existing callouts stay its own map-wide callouts, and every new id hangs off `bi.bg.<set>.<child>`.
- B2 Winds. A child with a real place on the map keeps its derived wind (the AreaPOI table, `tools/derive-winds.py`); one with no fixed place (Our base, Enemy base, a flag map's children, Ashran's, Deephaul's, Seething Shore's) takes the new `free` wind, which fills the first wind left after the middle entries, so Isle of Conquest's map-wide wedge stays on NE. Alterac Valley's 19 children cannot be pinned and take the unpinned ring.
- B3 Pad. Consecutive child sections of one parent sit side by side in a grid pad when their columns fit, so Alterac Valley's 19 two-chip sections take ten rows instead of nineteen.
- B4 Migration step 7. Every stored profile gets the newly shipped nodes inside its set's copy by origin (Library.SeedNewNodes, the node half of Prepare's seeding, now shared: seededSets, so a deleted node or set never comes back, and nothing held is touched), and each copy of a set that shipped flat turns on Open into while it still holds the shipped off.
- B5 Docs: README feature line and Version History row, scope.md, schema.md, module-map.md, smoke-tests.md (AV, IoC bases, one flag map), ARCHITECTURE known limitations, test-cases.md and the test badge.

## Global constraints

- Ka0s WoW Addon Standard; flag a deviation instead of shipping it.
- Green gate before every commit: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua` and `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0/0).
- Never edit `libs/` or `tests/_kit/`. No version bump. Shipping `.lua` at most 1,500 lines. US English; strings through `locales/enUS.lua`; CRLF.

## Status ledger

| Task | What | Status | Commit |
|---|---|---|---|
| T0 | This plan | done | (this commit) |
| T1 | `free` wind in Dial_Layout PinNodes, tested | done | e0585a6 |
| T2 | Built-in data: AV, IoC bases, WSG, TP, WG, Ashran, DHR, SS children; locale strings; integrity tests | done | 0a73916 |
| T3 | Migration step 7 (new nodes by origin, Open into) and its tests | done | a9ed826 |
| T4 | Dial fallback test for AV (in T1); pad packing of child sections | done | 5a5c808 |
| T5 | derive-winds covers Wintergrasp (and parses the current data again); docs, test-cases, badge | done | 20c0180 |
| T6 | Review fixes: Kor'lok callout says champion; step 7 leaves a nested copy's Open into alone (asserted); BG-5 notes free-wind order is not geography | done | (this commit) |
