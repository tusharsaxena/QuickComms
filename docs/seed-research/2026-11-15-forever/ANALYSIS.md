# Analysis: WoW Forever seed validation, 2026-11-15 (build 1.60.1.70938)

The first run of `tools/seeds/seeds.py` on WoW Forever, under `docs/validate-seeds.md`, tracked by
Ka0sAddonsCommonTasks#1. It re-checks `defaults/GameIds_Clients.lua`'s `FOREVER_DUNGEONS` and
`FOREVER_RAIDS` (`BY_CLIENT.forever`; its `INSTANCES` is the two concatenated) and the shared
`CLASSES` against Forever's own tables on wago.tools (product `wowf`, 1.60.1.70938), never a
filtered Retail list. The lists were derived on 1.60.1.70862 from `GroupFinderActivity` joined to
`Map` (the forever-ids design's D3-R and D5, QuickComms#21). Every flag is ruled in
`tools/seeds/forever_rulings.json`; `RULINGS.md` beside this file lists each with its reason.

## What changed between the builds

Nothing that touches the lists:

| Check | Result on 1.60.1.70938 |
| --- | --- |
| Shipped ids checked | 55: 30 dungeons, 12 raids, 13 class tokens |
| Map ids the build has no row for | 0 |
| Instance types that no longer fit the list | 0 |
| Shipped maps the group finder stopped listing | 0 |
| Party or raid maps the group finder lists that are not shipped | 0 |
| Arena maps (D4) | 0 |

No list changed. `apply` wrote nothing. Two hand edits follow the rulings: 531's review comment
now reads `Ahn'Qiraj Temple`, the name Forever's `Map` and group finder both give it, and the
header carries a `RE-VALIDATED against` line.

## What the run proposed

No candidates, and 5 flags:

| Flag | Id | Ruled | Why |
| --- | --- | --- | --- |
| `renamed` | 531 (`FOREVER_RAIDS`) | kept | The same map; the comment said `Temple of Ahn'Qiraj`, the client says `Ahn'Qiraj Temple`. Comment corrected by hand |
| `gone` | DEATHKNIGHT, DEMONHUNTER, EVOKER, MONK (`CLASSES`) | kept, needs owner review | Forever's `ChrClasses` holds nine classes. `CLASSES` is one list both clients read, so Forever's class row offers four classes it has no players of |

`SPECS` is not checked on Forever: its spec row reads the client (`Role.SpecsForClass`, C2).
`LFGDungeons` is not read: on this build all 76 of its rows sit on map 0, so it names no instance.
`JournalInstance` does not exist on Forever (HTTP 400).

## What a later run should re-check

- **The four Retail-only class tokens.** Making `CLASSES` per client (a `CLASSES` key in
  `BY_CLIENT` and `KEYS`) is a code change for the owner. Until then the flags stay kept and come
  back each run. The class row's names come from the client (`Compat.ClassName`), so how Forever
  draws the four is worth a look in game.
- **Maps the group finder does not list.** Forever's `Map` holds 13 party or raid maps that are
  neither shipped nor listed (Caverns of Time 269, Emerald Dream 169, the party-typed Naxxramas
  2921, Manor Mistmantle 3109 and others). D5 leaves them out. One that a later build's group
  finder lists comes back as a candidate.
- **The in-game check.** `/qc probe ids` (FOREVER-16, FOREVER-25) on the live client compares the
  shipped ids with the group finder's own activities.
