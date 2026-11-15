# Seed validation — Ka0s Quick Comms

The seed-validation contract `/dev-copilot:validate-seeds QuickComms <flavor>` runs. The command
supplies the loop (clean tree, one date, status, derive, rule, apply, gate, hand-back) and its
standing rules. This file supplies Quick Comms' procedure: the tool, the files it writes, the
precedent a ruling follows and each client's nuances. The headings below are the interface the
command reads, so keep their names.

The tool is `tools/seeds/seeds.py` (Python 3.8+, standard library only; its docstring is the
reference), with its offline tests beside it in `tools/seeds/test_seeds.py`. Each run ends in a
frozen bundle under `docs/seed-research/<date>-<flavor>/`: `raw/*.csv.gz` (the tables read, at one
build), `SOURCES.md`, `candidates.json`, `RULINGS.md` and a hand-written `ANALYSIS.md`. The first
runs are `docs/seed-research/2026-11-15-retail/` and `docs/seed-research/2026-11-15-forever/`.

## Flavors

| Flavor | Source | Seed files | Tools |
| --- | --- | --- | --- |
| `retail` | wago.tools product `wow` (Retail live): `Map`, `JournalInstance`, `LFGDungeons`, `ChrClasses`, `ChrSpecialization` | `defaults/GameIds.lua` (`DUNGEONS`, `RAIDS`, `CLASSES`, `SPECS`), `defaults/GameIds_Instances.lua` (`INSTANCES`, `ARENAS`) | `tools/seeds/seeds.py --flavor retail` |
| `forever` | wago.tools product `wowf` (WoW Forever): `Map`, `GroupFinderActivity`, `ChrClasses` | `defaults/GameIds_Clients.lua` (`BY_CLIENT.forever`: `FOREVER_DUNGEONS`, `FOREVER_RAIDS`, whose concatenation is its `INSTANCES`), and the shared `CLASSES` in `defaults/GameIds.lua` | `tools/seeds/seeds.py --flavor forever` |

## Rules

- **What the tool writes.** `apply` writes the accepted ids and the ruled removals into the seed
  files, keeping each file's CRLF and its row layout; nothing else edits a list's ids. A seed
  file's comments stay hand-written: the header notes, and a review comment a `renamed` flag says
  to fix. `apply` refuses, and the change is made by hand with the owner, for a list that has no
  table of its own to write into: Forever's arenas (`ARENAS = {}`, D4) and `CLASSES` under the
  `forever` flavor (one list both clients read; a removal there would remove it from Retail).
- **Rulings are data.** They live in `tools/seeds/retail_rulings.json` and
  `tools/seeds/forever_rulings.json`, and `seeds.py rule` is their only writer. A ruling is keyed
  `<list>:<id>` for a candidate (`accept` or `reject`) or `shipped:<kind>:<list>:<id>` for a flag
  (`keep` or `remove`), never by build, and it stays until the thing it ruled on stops being
  proposed.
- **Precedent, in this order, never re-litigated:**
  1. a ruling already in the flavor's rulings file;
  2. the seed files' own headers: `defaults/GameIds.lua` (the season's dungeons and raids, the
     later-season raids and Sporefall left out by owner ruling R4), `defaults/GameIds_Instances.lua`
     (every journal dungeon and raid, world-boss entries skipped; the two legacy arena copies 559
     and 562 not shipped) and `defaults/GameIds_Clients.lua` (Forever's lists are exactly the
     group finder's maps of each instance type, D3-R and D5; no arena list, D4; Darkspear Islands
     gets no set);
  3. the forever-ids design and its rulings (QuickComms#21, `docs/ARCHITECTURE.md` →
     *Per-client features*), and `tools/derive-gameids.py`'s `DROPPED_ARENAS` and
     `NOT_SHIPPED_PVP`.
- **Season lists are a choice, not a derivation.** `DUNGEONS` (the current Mythic+ season) and
  `RAIDS` (the raid tier) get existence, name and instance-type checks only and **no candidates**:
  which dungeons a season runs is Blizzard's pick, read off `MythicPlusSeasonTrackedMap` by
  `tools/derive-gameids.py`, and which raids ship is the owner's.
- **What "accept" means here.** An id is accepted when the build's data shows it belongs in the
  list under the list's own header rule: a journal dungeon or raid for `INSTANCES`, an arena map
  that is not a legacy copy for `ARENAS`, a playable class, a specialization a player picks, a map
  of the right instance type Forever's group finder lists. When in doubt, reject with
  `needs owner review: <why>`.
- **Evidence.** The bundle's `raw/*.csv.gz` (read the row's own columns), the seed headers,
  `tests/test_gameids.lua`'s `CLIENT_MAPS` and `FOREVER_MAPS`, and a `/qc probe ids` record when
  one exists (`docs/common-tasks.md`). DB2 says what exists, not what a player sees in game: an
  accepted id still gets a smoke check.
- **Privacy.** No player name, realm or GUID goes into a bundle, a ruling or a commit.

## Flavor: retail

### Status

```sh
python3 -I tools/seeds/seeds.py status --flavor retail
```

Prints `CURRENT <build> (<bundle>)`, or `NEW <build> (last ruled <build>, <bundle>)`, comparing the
live `wow` build with the newest `*-retail` bundle.

### Freeze and derive

```sh
python3 -I tools/seeds/seeds.py derive --flavor retail --bundle docs/seed-research/<date>-retail --date <date> --build <build>
```

Fetches the five tables at `?build=<build>` (cached in `tools/seeds/.cache/<build>/`, about 600 KB),
freezes them gzipped into the bundle's `raw/` (about 140 KB) and writes `SOURCES.md` and
`candidates.json`. A missing column, an export of another build or a missing sentinel (Molten
Core, Deadmines, Ruins of Lordaeron, Arms) **fails the run: stop**. `--replay` re-derives from the
bundle's `raw/` alone. Report the per-list counts it prints: shipped, candidates, flags, unruled.

### Rule

```sh
python3 -I tools/seeds/seeds.py check --bundle docs/seed-research/<date>-retail
python3 -I tools/seeds/seeds.py rule --tsv <scratchpad>/retail.tsv --bundle docs/seed-research/<date>-retail
```

`check` lists every unruled key and must print `OK` after `rule`.

- **Candidates** (`accept` or `reject`):
  - `instances` (`journal`): a `JournalInstance` on a party or raid map, its world-boss bit
    (`Flags & 2`) clear, that `INSTANCES` lacks;
  - `arenas` (`map`): an arena map (`InstanceType` 4) `ARENAS` lacks. 559 and 562 are rejected
    by the header's exclusion;
  - `classes` (`chrclasses`): a `ChrClasses` token `CLASSES` lacks. Adventurer and TRAVELER are
    not playable classes (rejected 2026-11-15);
  - `specs` (`chrspec`): a `ChrSpecialization` row of a shipped class that `SPECS` lacks. The 13
    `Initial` rows (`OrderIndex` 4) are not a spec a player picks (rejected 2026-11-15).
- **Flags** (`keep` or `remove`):
  - `gone`: the build has no row. Remove, unless the header records why it ships;
  - `renamed`: the Map name differs from the comment. The same map: keep, and fix the comment by
    hand. A reused id: remove;
  - `kind`: the instance type no longer fits the list, or a spec is another class's. Remove, or
    move it by hand when it belongs in another list;
  - `unjournaled`: an `INSTANCES` map no journal entry names. Remove, unless the header keeps it;
  - `unlisted`: no `LFGDungeons` row is on the map. Information for the ruling: 3029 Keystone
    Dungeons is a journal entry the header's rule admits (kept 2026-11-15).

### Apply

```sh
python3 -I tools/seeds/seeds.py report --bundle docs/seed-research/<date>-retail --date <date>
python3 -I tools/seeds/seeds.py apply  --bundle docs/seed-research/<date>-retail --date <date>
```

`report` comes before `apply`, while the run's candidates still include what is about to ship.
`apply` refuses while anything is unruled, and a second `apply` changes nothing.

### After

- A new or removed map id: run `tools/derive-gameids.py` (`docs/common-tasks.md`, "Re-derive the
  client-data extractions") and paste the `CLIENT_MAPS` row it prints into
  `tests/test_gameids.lua`, so the extraction and the list agree.
- Roll the `RE-VALIDATED against` line in the header of each seed file the flavor read
  (`defaults/GameIds.lua`, `defaults/GameIds_Instances.lua`) to the build, the date and the bundle.
- Write the bundle's `ANALYSIS.md` by hand, in the 2026-11-15 bundle's shape: what changed between
  the builds, what was proposed, accepted and rejected and why, what a later run should re-check.
- Add a smoke check to `docs/smoke-tests.md`'s *Instance ids* section, plus its *Pending sign-off* note, for
  every list that changed. A run that changes no list adds none.

### Stage

`defaults/GameIds.lua`, `defaults/GameIds_Instances.lua`, `tools/seeds/retail_rulings.json`,
`docs/seed-research/<date>-retail`, plus any `tests/test_gameids.lua`, smoke or citation edits.
Commit message: `Seeds (retail): re-validated against <build> (<date>)`.

## Flavor: forever

### Status

```sh
python3 -I tools/seeds/seeds.py status --flavor forever
```

Prints `CURRENT <build> (<bundle>)` or `NEW <build> (...)`, comparing the live `wowf` build with the
newest `*-forever` bundle.

### Freeze and derive

```sh
python3 -I tools/seeds/seeds.py derive --flavor forever --bundle docs/seed-research/<date>-forever --date <date> --build <build>
```

Forever's own tables at its own build, never Retail's filtered (clients-§5). About 15 KB frozen.
The sentinels are Molten Core, Deadmines, a group finder activity on Molten Core and the Warrior;
a missing one **fails the run: stop**. Report the per-list counts it prints.

### Rule

```sh
python3 -I tools/seeds/seeds.py check --bundle docs/seed-research/<date>-forever
python3 -I tools/seeds/seeds.py rule --tsv <scratchpad>/forever.tsv --bundle docs/seed-research/<date>-forever
```

Nuances:

- **The group finder is the source (D5).** `dungeons` and `raids` candidates (`groupfinder`) are
  the party and raid maps `GroupFinderActivity` lists that the lists lack, joined to `Map` on
  `MapID`, with no name join. A map the group finder does not list is not proposed, and a shipped
  one it stops listing is flagged `unlisted`.
- **No journal, no dungeon finder.** Forever has no `JournalInstance` (HTTP 400), and its
  `LFGDungeons` rows all sit on map 0 (76 rows on 1.60.1.70938), so neither is read.
- **Arenas (D4).** Any arena map in Forever's `Map` is proposed; there are none today. An accepted
  one needs a hand change (a Forever `ARENAS` list, the Arena set, `HIDDEN_ROWS`), so `apply`
  refuses it.
- **CLASSES is shared.** Under this flavor `CLASSES` is checked against Forever's `ChrClasses`. The
  four Retail-only tokens (DEATHKNIGHT, MONK, DEMONHUNTER, EVOKER) are flagged `gone` and kept
  pending the owner (2026-11-15): a per-client list is a code change, not a seed edit.
- **SPECS is not checked here.** Forever's spec row reads the client (`Role.SpecsForClass`, C2),
  and `SPECS` is Retail's fallback.

### Apply

```sh
python3 -I tools/seeds/seeds.py report --bundle docs/seed-research/<date>-forever --date <date>
python3 -I tools/seeds/seeds.py apply  --bundle docs/seed-research/<date>-forever --date <date>
```

The same order and refusals as Retail.

### After

- A new or removed map id: run `tools/derive-gameids.py --forever` and paste the `FOREVER_MAPS`
  row it prints into `tests/test_gameids.lua`; update `docs/ARCHITECTURE.md`'s *Place lists* row
  (its counts and names).
- Roll the `RE-VALIDATED against` line in `defaults/GameIds_Clients.lua`'s header.
- Write the bundle's `ANALYSIS.md` by hand, in the 2026-11-15 bundle's shape.
- Add a FOREVER smoke check (`/qc probe ids`) for every list that changed, plus its *Pending
  sign-off* note. A run that changes no list adds none.

### Stage

`defaults/GameIds_Clients.lua`, `tools/seeds/forever_rulings.json`,
`docs/seed-research/<date>-forever`, plus any `tests/test_gameids.lua`, `docs/ARCHITECTURE.md`,
smoke or citation edits. Commit message: `Seeds (forever): re-validated against <build> (<date>)`.

## Gate

```sh
~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua
KA0S_KIT_CLIENT=forever ~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua
~/.claude/dev-copilot/bin/ka0s-bounded luacheck .
python3 -m pytest -q tools/seeds
```

luacheck must report 0 warnings and 0 errors, and every suite 0 failed.

## Notes

- **Two tools, two jobs.** `tools/seeds/seeds.py` is this loop: flags on what ships, candidates,
  rulings, apply. `tools/derive-gameids.py` stays the extraction check: `tests/test_gameids.lua`'s
  `CLIENT_MAPS` and `FOREVER_MAPS`, the Mythic+ season's maps (`SEASON`), the raid tier
  (`CURRENT_TIER`, `LAUNCH`) and the battleground sets. Run both when a list changes.
- **Bundle size.** About 140 KB for Retail and 15 KB for Forever; one bundle per patch.
- **Not covered.** `THANK_RAID_BUFFS` (spell ids) and the battleground sets' map ids
  (`defaults/BuiltIns_Battlegrounds.lua`) are outside this contract today; `HIDDEN_CONTENT` and the
  other `BY_CLIENT` keys hold content kinds, rows and tokens, not DB2 ids.
- **Shared helper.** Whether the build pin, cache, bundle and rulings move into a shared helper is
  LibKa0s#91.
