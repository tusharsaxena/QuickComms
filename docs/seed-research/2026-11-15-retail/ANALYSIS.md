# Analysis: Retail seed validation, 2026-11-15 (build 12.1.5.70783)

The first run of `tools/seeds/seeds.py` on Retail, under `docs/validate-seeds.md`, tracked by
Ka0sAddonsCommonTasks#1. It re-checks every id in `defaults/GameIds.lua` (`DUNGEONS`, `RAIDS`,
`CLASSES`, `SPECS`) and `defaults/GameIds_Instances.lua` (`INSTANCES`, `ARENAS`) against the live
Retail build on wago.tools (product `wow`, 12.1.5.70783). The lists were last matched on
12.1.5.70340 (2026-10-13 for the season lists, 2026-10-19 for the instance and arena lists, by
`tools/derive-gameids.py`). Every candidate and flag is ruled in `tools/seeds/retail_rulings.json`;
`RULINGS.md` beside this file lists each with its reason.

## What changed between the builds

Nothing that touches these lists:

| Check | Result on 12.1.5.70783 |
| --- | --- |
| Shipped ids checked | 281: 8 dungeons, 3 raids, 201 instances, 16 arenas, 13 classes, 40 specs |
| Ids the build has no row for | 0 |
| Map names that disagree with the comment | 0 |
| Ids whose instance type no longer fits the list | 0 |
| `INSTANCES` maps no journal entry names | 0 |
| Specs filed under the wrong class | 0 |
| Journal dungeons and raids not shipped | 0 |

No list changed. `apply` wrote nothing; the only seed-file edit is the `RE-VALIDATED against`
line in the two headers.

## What the run proposed

17 candidates and 1 flag, all ruled:

| List | Proposed | Ruled | Why |
| --- | --- | --- | --- |
| `arenas` | 559 Nagrand Arena (old), 562 zzOldBlade's Edge Arena | rejected | The header's exclusion: legacy copies the current 1505 and 1672 replaced (`DROPPED_ARENAS`) |
| `classes` | Adventurer (14), TRAVELER (15) | rejected | Not playable classes: Adventurer's only spec is the placeholder 1478, TRAVELER has none |
| `specs` | the 13 `Initial` rows (1444 to 1465) | rejected | The pre-specialization placeholder every class has (`OrderIndex` 4), not a spec a player picks |
| flag `unlisted` | 3029 Keystone Dungeons (`INSTANCES`) | kept | Journal entry 1319, which the header's rule admits; it is the journal's Mythic+ overview, so no `LFGDungeons` row is on it |

`DUNGEONS` and `RAIDS` are the season's choice and were checked, not proposed against
(`docs/validate-seeds.md`, Rules).

## What a later run should re-check

- **3029 Keystone Dungeons.** The journal's rule ships it as a When editor suggestion. Whether
  the editor should offer a Mythic+ overview entry at all is the owner's call; the flag is kept so
  the question stays visible.
- **757 Baradin Hold.** A raid map whose journal entry (75) carries the world-boss bit
  (`Flags & 2`), so the header's rule skips it, along with the four expansion world-boss entries
  (2559, 2574, 2774, 2930, each named after its continent). If the owner wants Baradin Hold suggested, that is a
  rule change, not a ruling.
- **The season lists.** The run checks that each `DUNGEONS` and `RAIDS` id still exists as a map
  of its kind. A new Mythic+ season or raid tier is `tools/derive-gameids.py`'s `SEASON`,
  `CURRENT_TIER` and `LAUNCH`, then a ruling by the owner.
- **The in-game confirmation.** The header still reads MATCHED, NOT YET CONFIRMED IN GAME until
  smoke checks IDS-1 and BG-2 pass; this run does not change that.
