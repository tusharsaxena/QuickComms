# Confirming the WoW Forever ids without travel (QuickComms#21)

The owner, 2026-11-10: "i wont be able to visit every dungeon manually, so we'll need to find a different way",
then "Do #1 and #2". #1 is an in-game sweep that needs no travel. #2 is reading the client's own data tables
offline.

## What #2 already found (wago.tools, Forever build 1.60.1.70862, the build the owner's client runs)

wago.tools exports product `wowf`, and its build_config `5ada9542…` matches the local `.build.info`.

- **Map** (80 rows) holds every id in `defaults/GameIds_Clients.lua` under the expected name and instance
  type: the 17 dungeons (party), the 6 raids (raid), and battlegrounds 30, 489 and 529 (pvp).
- **The classic ids that were left out exist:** Scarlet Monastery 189 (party), Scholomance 289 (party) and
  Zul'Gurub 309 (raid, 20 players).
- **Forever's own dungeons:** LFGDungeons (TypeID 0) queues nine dungeons with Forever map ids. They are
  City of Dalaran 2959, The Drowned City 2970, Blackmaw Hold 2974, Alcaz Prison 2994, Excavation Site:
  Wetlands 2998, Ruins of Lordaeron 2999, The Shaper's Terrace 3001, Krol'dok Stronghold 3039 and The Hall of
  Thanes 3065.
- **Maps that exist but that the dungeon finder does not queue:**
  - Raids 2789 The Tainted Scar, 2791 Storm Cliffs, 2804 The Crystal Vale, 2832 Nightmare Grove and 2856
    Scarlet Enclave, plus 169 Emerald Dream, an old test map.
  - Party maps 2784 Demon Fall Canyon, 2875 Karazhan Crypts, 269 Caverns of Time and event maps.
- **Battlegrounds:** BattlemasterList adds Darkspear Islands (map 2997) and Battle for Gilneas (map 3005).
  Arena exists only as Mak'gora Arena (BattlemasterList 1169), which has no arena-type map.
- LFGDungeons' MapID column is 0 on every Forever row, so the Map table, joined by name, is the id source.

## Decisions

- **D1 (the lead's call).** Add 189 and 289 to `FOREVER_DUNGEONS`, and 309 to `FOREVER_RAIDS`.
- **D2 (the lead's call).** Add the nine dungeons the dungeon finder queues to `FOREVER_DUNGEONS`. The
  owner's ruling R1 asks for Forever's own lists, and a queueable dungeon is live content.
- **D3 (the lead's call, cheap to reverse).** Leave out the raid and party maps the dungeon finder does not
  queue. A map row alone does not prove the content is live. `/qc probe ids` reports them so the owner can
  rule. Darkspear Islands and Battle for Gilneas get no built-in sets, because they still classify as
  battleground. They are named in docs and the probe output.
- **D4.** Arena stays hidden on Forever: there is no arena map.

## #2 in the repo: a Forever extraction, checked by the generator

- `tests/test_gameids.lua` (or a new `tests/test_gameids_forever.lua` if the file nears the cap) holds
  `FOREVER_MAPS`. It is an extraction of the Map table's InstanceType and name for every id the Forever
  lists ship, from build 1.60.1.70862. It is not authored data.
  - The test that checked Forever ids against Retail's `CLIENT_MAPS` now checks them against
    `FOREVER_MAPS`. Each dungeon is party, each raid is raid, and each battleground set's ids are pvp.
- `tools/client_tables.py` and `tools/derive-gameids.py` gain a Forever mode. It fetches the tables with
  `?build=<Forever build>` (product `wowf`), re-derives every `FOREVER_MAPS` row and fails on a difference.
  It also checks that `FOREVER_DUNGEONS` equals the party maps that LFGDungeons TypeID 0 names (joined by
  name). It prints the not-shipped raid and party candidates as NOT SHIPPED, so the owner's ruling decides,
  never the script.
- `defaults/GameIds_Clients.lua`'s header changes from "MATCHED, NOT CONFIRMED IN GAME" to "derived from
  Forever's own Map and LFGDungeons tables (build 1.60.1.70862)". The in-game check is `/qc probe ids`.

## #1 in game: `/qc probe ids`

- A new form of the existing verb. Like `probe`, it is refused in combat and while the addon is stood down.
  It reads with no travel:
  - `GetRealZoneText(id)` for every id 0..4000, keeping the non-empty names;
  - `GetLFGDungeonInfo` over the dungeon finder's list (name, type, the 22nd return `lfgMapID`);
  - `GetNumBattlegroundTypes` / `GetBattlegroundInfo` (name and battleground id).
- Every read is guarded through `core/Compat.lua` (absent API → empty), and values go through the Plain
  readers, as the existing probe does.
- It stores one record `{ kind = "ids", client, time, maps = { [id] = name }, lfg = {...}, battlegrounds =
  {...} }` in `global.probes[<client>]`, under the same 50-record cap. It prints a short summary:
  - how many map names it read;
  - each id in the client's own DUNGEONS / RAIDS / battleground sets that the client does not name (none
    expected);
  - each dungeon-finder name that no shipped id carries.
- The full record lives in the SavedVariables file, for the lead to diff against the offline extraction.

## Done when

- Both kit profiles are green, luacheck is 0/0, and every file is under 1500 lines. The generator's Forever
  mode passes against a fresh fetch.
- Docs are updated: ARCHITECTURE per-client rows, schema (the `ids` record), slash-dispatch, smoke-tests,
  docs/common-tasks.md (how to run the Forever derivation), and test-cases regenerated.
- FOREVER-16 and FOREVER-22 are rewritten around `/qc probe ids`, plus a new check for the sweep itself.
  All are owed.

## Revision 2026-11-10 (group finder)

New evidence, verified by the lead: WoW Forever (game type camelot) loads neither Blizzard_GroupFinder
nor Blizzard_PVPUI. Its group finder is Blizzard_GroupFinder_VanillaStyle, which walks
`C_LFGList.GetAvailableCategories()`, then `C_LFGList.GetAvailableActivities(categoryID, groupID)`,
then `C_LFGList.GetActivityInfoTable(activityID)` (its `GroupFinderActivityInfo` has `fullName`,
`maxNumPlayers`, `isPvpActivity` and `mapID`). The dungeon finder that LFGDungeons describes is not
the one Forever's players see.

Forever's GroupFinderActivity table (build 1.60.1.70862, 114 rows) has a populated MapID column. Joined
to Map on it, with Map.InstanceType classifying each map (1 party, 2 raid, 3 pvp, 0 world), it lists
every shipped id, and also these, as live group finder activities:

- party: 2784 Demon Fall Canyon, 2875 Karazhan Crypts;
- raid: 2789 The Tainted Scar, 2791 Storm Cliffs, 2804 The Crystal Vale, 2832 Nightmare Grove,
  2856 Scarlet Enclave;
- pvp: 2997 Darkspear Islands.

Battle for Gilneas (3005) is not in the group finder. Some activities are raid-sized versions on party
maps (Blackfathom Deeps, Gnomeregan and Sunken Temple in the Raids category); those maps stay dungeons,
because classification is by Map.InstanceType. World and zone activities have InstanceType 0 and
`maxNumPlayers` 0.

- **D3-R (the lead's call; D3 is reversed).** A place Forever's own group finder lists is live
  content. `FOREVER_DUNGEONS` gains 2784 and 2875, and `FOREVER_RAIDS` gains 2791, 2789, 2804, 2832 and
  2856, each in its own commented block in the group finder's order (order index, then name). That is
  30 dungeons and 12 raids. Darkspear Islands gets no built-in set: the battleground content kind
  already matches it.
- **D5 (the lead's call).** The id source is GroupFinderActivity joined to Map on MapID, with no name
  join. `FOREVER_DUNGEONS` must equal the distinct InstanceType 1 maps the group finder lists, and
  `FOREVER_RAIDS` the distinct InstanceType 2 maps. Every pvp map it lists must be carried by a
  battleground set, except those `tools/derive-gameids.py` names as not shipped (`NOT_SHIPPED_PVP`:
  2997). The generator's Forever mode reads GroupFinderActivity in place of LFGDungeons, drops the name
  join (`LFG_NAMES`), fails on any difference, and prints the party, raid and pvp maps that Map holds
  and the group finder does not list as `NOT SHIPPED:`, for information only.
- **In game.** `/qc probe ids` also reads the group finder (`Compat.ProbeGroupFinder`: each category,
  each activity once, at most 2000, each `{ id, name, categoryID, mapID, maxNumPlayers, isPvp }`) and
  stores it as `groupFinder` in the ids record. It prints a fifth line: how many activities, the shipped
  ids it does not list, and the maps it lists (zones left out) that no shipped id carries. Expected on
  build 1.60.1.70862: about 114 activities; shipped ids it does not list: none; maps it lists that no
  shipped id carries: Darkspear Islands (2997). An empty list reads *not checked*. The dungeon finder
  line may read *not checked* on Forever.
