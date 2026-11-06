# Decisions (QuickComms, LibKa0s v1.86.0 -> v1.89.0)

No interview: the owner decided upfront for the whole run. Source for every row:
`Ka0sAddonsCommonTasks/docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/00_PLAN.md`, *Decisions (owner,
2026-11-06, asked upfront)*. No GitHub issue is filed (the plan files issues only for real not-now
candidates, and this addon has none).

| Candidate | Decision | Source row |
|---|---|---|
| Widgets 23 cascading-menu fields (`submenu`, `radio`, `selected`, `opts.check`) | not applicable, no `W.ContextMenu` use site; no issue | "Cascading-menu fields / addons with no `W.ContextMenu` use site" |
| Toast 4 stack | not applicable, this addon consumes no Toast major; no issue | plan names the stack only for DpsRace (settled) and Drop Watcher; QuickComms has no toast |
| IconBrowser | already adopted at v1.86.0; no minor moved, nothing owed | the "IconBrowser" row covers addons without an icon chooser; QuickComms has one and is the major's origin |

Adoptions for this repo in the plan: none (the three `V89A-*` items are DpsRace, MultiMeters and
DropWatcher). Undecided candidates: none.
