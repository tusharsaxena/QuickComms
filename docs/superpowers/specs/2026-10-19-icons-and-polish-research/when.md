## Scout report: When-tab Instance, Battleground and a new Arena drawer

Scope note: the relayed user request is about adding new icons to LibKa0s and vendoring that version into QC. This task (the When drawers) touches none of that. The only LibKa0s overlap is that `IdList` already handles everything needed here, so no library change is required for this area.

### 1. How the id drawers work now (settings/Groups_When.lua)

- **Drawer order:** `W.ROWS` at :34-35. Battleground is last. The Resolver's row order (`R.ROWS`, modules/Resolver.lua:11-12) is a separate list and has battleground third.
- **Rendering:** `renderDrawer` :623 calls `H().Drawer`. For an id row, `renderChoices` :601 goes to `renderIdRow` :544, then `renderIdList` :560, then `h.IdList` (LibKa0s/OptionsIdList.lua; resolution and suggestions in LibKa0s/OptionsIds.lua).
- **The tables each id row needs an entry in:**
  - `KIND` :384, built by `idKind(nameFn, noun, plural)` :372
  - `CANDIDATES` :398
  - `ADD` :409 (add-box label, tooltip, "Add the X you are in")
  - `ALL` :420 (the whole-kind checkbox: label and tooltip)
  - `COUNT` :439
  - `NOT_HERE` :492
  - `here(row)` :484
  - `W.TIP` :48
- **Summary on the drawer header:** `W.Summary` :446.
  - Unset row: "Any".
  - Id row with `ALL` ticked: the `ALL` label.
  - One id: its name via `KIND[row]().info`.
  - Several ids: the `COUNT` format.
- **Typed values from the CLI:** `W.ResolveValue` :515 accepts "all" for rows in `ALL` :522, otherwise `kind.resolve(text, CANDIDATES[row])` :525.

**Battleground "autocomplete":** there is no special widget. Every IdList shows the same suggestion popup, built from `candidates()` and named through `kind.info`:
- Matching is a substring match with word-start tiers (`OptionsIds.lua:589-594`).
- It needs at least 2 characters (`SUGGEST_MIN_NAME` :415).
- It shows 10 rows (`SUGGEST_ROWS` :413).
- It indexes at most 2000 candidates (`SUGGEST_INDEX_CAP` :419).

Battleground candidates come from `battlegroundIds()` :125, which reads the shipped built-in sets: every `NS.BuiltIns.groups[*].when.battleground` id (defaults/BuiltIns_Battlegrounds.lua:47,54; 14 sets). Names come from each set's `def.name` (`battlegroundNames` :109), falling back to `W.InstanceName`. It looks like a full catalogue only because every battleground has a built-in set.

### 2. Why "Murder Row" is refused (root cause, confirmed in code)

1. `CANDIDATES.instances` :399-404 returns only `NS.GameIds.DUNGEONS` and `NS.GameIds.RAIDS` (defaults/GameIds.lua:25-39). That is 8 Mythic+ season-34 dungeons and 3 launch raids.
2. `idKind.resolve` :376 takes a whole number first; otherwise `byName` :352 does an exact, case-insensitive compare of `W.InstanceName(id)` (= `Compat.InstanceName`, which is `GetRealZoneText(mapID)`, core/Compat.lua:237) over those 11 ids only.
3. Murder Row is not one of them, so the result is `"notFound"`. The library then prints `ID_TEXT.notFound = "No {noun} named '{text}'."` (OptionsIds.lua:193).

The lists are deliberately limited to the current season. tools/derive-gameids.py:95-101 asserts that `DUNGEONS` equals exactly the maps of `MythicPlusSeasonTrackedMap` with `DisplaySeasonID == SEASON(34)`. :103-120 asserts `RAIDS` are type-2 maps in `JournalTier 505` under `LAUNCH 149388`. The header at GameIds.lua:17-19 says unlisted instances are added by "Add the instance you are in" or a typed id.

**`DUNGEONS` is also read by Preview.** modules/Preview.lua:117 builds one "Preview as… M+ · X" entry per id. So the instance candidate list cannot simply be widened by enlarging `DUNGEONS`. It needs a new table.

**Fix shape:**
- Add a new shipped list, e.g. `G.INSTANCES` (every dungeon and raid map id), and maybe `G.ARENAS`, in defaults/GameIds.lua or a new defaults/ file listed in the TOC.
- Point `CANDIDATES.instances` at it, keeping `DUNGEONS`/`RAIDS` for Preview and the season checks.
- Names stay client-side through `GetRealZoneText(id)`. Only ids are matched, which keeps to localization-§4.

**Data source (wago.tools CSVs, already fetched by `ct.fetch`; `TABLES` at derive-gameids.py:26):**
- **Recommended: `JournalInstance`.** Take `MapID` where `Map[MapID].InstanceType` is 1 (party) or 2 (raid), and skip `Flags & WORLD_BOSSES(2)` (already coded at :103-111, minus the tier and condition filter). This gives the player-facing Encounter Journal set and avoids test, legacy and scenario maps that `Map` alone would bring in.
- **Alternative:** every `Map` row with `InstanceType` in {1,2}. Larger and noisier, with many duplicate names, which makes `byName` return "ambiguous" (:357).
- Murder Row's map id was not verified (no CSVs are cached locally). The planner should check it appears in the derived set.

**Generator changes (derive-gameids.py):**
- Add a mode or check that emits the full list for review and asserts the shipped list equals the derivation.
- Keep the existing habits: fail loudly with `ct.fail`, a `MISMATCH:` line plus exit 1, and print the block for diffing (layout-§1, "A non-Lua generator…" SHOULDs).
- The shipped output is loaded by the client, so the carve-out for generated non-shipping data does **not** apply (layout-§1 :69, second condition). The file is ordinary source under the 1500-line cap. Pack several ids per line if needed.
- Note the provenance header (build, date) as GameIds.lua:11-16 does.

### 3. Battleground drawer end to end (template for Arena)

| Layer | Where | What |
|---|---|---|
| Stored value | `group.when.battleground = { [mapID]=true, all=true? }` | written via `W.Write`, which calls `NS.SchemaRuntime.Set("group.when", …)` (Groups_When.lua:267; member row in settings/SchemaMembers.lua) |
| Validation | modules/Library.lua:379 `ID_ROWS`, :388 the `ALL` clause for `instances`/`battleground`, :417 the known rows come from `Resolver.ROWS` | |
| Refusal wording | settings/SchemaMembers.lua:107 `whenTakes` | |
| CLI | settings/Slash.lua:124 `knownCondition` (from `Resolver.ROWS`), :142 `valuesOf` (splits on commas for instances and battleground), :228 `formatWhen` | |
| Resolver | Resolver.lua:11 `ROWS`, :14-19 `LABEL`, :35 `R.ALL="all"`, :64-67 `CHECK.battleground` (requires `s.content=="battleground"`, then `ALL` or `v[s.instanceID]`), :131 `Narrowness` (+101 for a specific row) | |
| Situation | modules/Situation.lua:28 `instanceType "arena"` → `content="arena"`; :55 `instanceID` is passed for every content; Compat.lua:44 takes the 8th return of `GetInstanceInfo` | **Arena needs no Situation change** |
| UI | Groups_When.lua :34 `ROWS`, :59 `TIP`, :384-440 `KIND`/`CANDIDATES`/`ADD`/`ALL`/`COUNT`, :487 `here`, :494 `NOT_HERE` | |
| Names | `W.BattlegroundName` :121 | |

**Arena drawer:** add `"arena"` to each layer above.
- `CHECK.arena`: `s.content=="arena" and (v.all or v[s.instanceID])`.
- Update every `row=="instances" or row=="battleground"` literal: Library.lua:388, SchemaMembers.lua:107, Slash.lua:142, Resolver.lua:131. Consider making `Library.ID_ROWS` and an `R.ID_ROWS` set the single source.
- Candidates: a new `NS.GameIds.ARENAS`. There are no per-arena built-in sets; defaults/BuiltIns_Arena.lua has only the generic `content={arena=true}` set. Names use `W.InstanceName`.
- `here("arena")`: `live.content=="arena" and live.instanceID`.
- **Locale keys to add (locales/enUS.lua):** "All arenas", its tooltip, "Specific arenas.", "Add an arena", "Type an arena's id or name, then press Enter or Add.", "Add the arena you are in", "You are not in an arena.", "%d arenas", "arena", "arenas". `L["Arena"]` already exists (:309) and can serve as the label.
- **Arena data source:** `Map.db2` `InstanceType == 4`. `JournalInstance` does not cover arenas.
  - Expect legacy and brawl duplicates (for example several Nagrand Arena / Blade's Edge maps) whose identical names make `byName` ambiguous.
  - The generator should print them, and the owner should rule which ship, in the same style as the R4 note at GameIds.lua:19.
  - Every shipped id gets a `type = 4` row in `CLIENT_MAPS`.

### 4. Tests that cover the area and how they assert

- **tests/test_groups_when.lua** (boots the addon; pure W functions):
  - :122 `BattlegroundName(2107)=="Arathi Basin"`; `InstanceName(99999)=="Instance 99999"`. The mock has no `GetRealZoneText`, so name-based tests must stub it as test_compat.lua:118 does.
  - :141 `ResolveValue` (instances "2526" → 2526; "Nowhere" → nil).
  - :169 `Summary` for id rows.
  - :209 `SetAll`, `HasAll`, `ResolveValue "all"`.
  - Add: `CANDIDATES` reach. It is local, so either expose it as `W.Candidates(row)` or assert through `ResolveValue("instances", <stubbed name>)`. Add arena cases mirroring :209.
- **tests/test_gameids.lua:**
  - `CLIENT_MAPS` :15-46 is an extraction (`type` 1/2/3 plus `challenge`) checked by the generator's `fixture_rows` (derive-gameids.py:57).
  - :62 every battleground id is type 3, with exactly 14 sets.
  - :80 `DUNGEONS` are type 1 with a challenge map; `RAIDS` are type 2; counts are 8 and 3.
  - Add: a constant `ARENA=4`; assert every `INSTANCES` id is type 1 or 2 and every `ARENAS` id is type 4 (each needs its `CLIENT_MAPS` row, so a large `INSTANCES` list makes this fixture large); no duplicates.
- **tests/test_resolver.lua:**
  - :37 a battleground row does not match outside a battleground.
  - :154-170 `ALL` matching (already asserts a battleground row does not match `content="arena", instanceID=1505`).
  - :168 `Narrowness`.
  - Add the arena twins.
- **tests/test_library.lua:** :596, :609, :1208 `ValidWhen` with `battleground {all=true}`. Add arena.
- **tests/test_page_groups.lua:**
  - :640-641 asserts the exact drawer label order `"Content,Instance,…,Character,Battleground"`. It must change with `W.ROWS`.
  - :701-729 instance drawer edit box.
  - :1219-1240 the All-battlegrounds dims-and-locks flow. Clone it for arenas.
- **tests/test_situation.lua:** :23 the battleground classification. An arena row there would confirm `instanceID` is carried through.

### 5. Constraints from the standard and the docs

- **localization-§4:** store and match ids only; names only for display or to resolve to an id.
- **layout-§1:** the generator lives in `tools/`, is `.pkgmeta`-ignored, and fails loudly. The loaded data file is capped at 1500 lines.
- **documentation-§7:** DEPENDENCIES.md already names Python for derive-gameids (:84).
- **Docs to update:**
  - docs/common-tasks.md:85-90 (regeneration procedure)
  - docs/module-map.md:33 (the GameIds row)
  - docs/ARCHITECTURE.md:229 (known limitation: ids matched but not confirmed in game) and its schema section
  - docs/settings-panel.md, docs/smoke-tests.md (IDS-1/BG-2; add an arena check), docs/test-cases.md
- **CLAUDE.md gate:** `lua tests/run.lua` plus `luacheck .` at 0 warnings and 0 errors. Never edit `libs/` or `tests/_kit/`.