# 02 — Candidates (LibKa0s v1.74.0 -> v1.75.0)

Sources: `git -C ../LibKa0s log --oneline v1.74.0..v1.75.0`, the tag's `CHANGELOG.md` `## v1.75.0`
block (lines 13-) and the moved majors' `docs/api/` documents. The run's
`inputs/OWNER_SCOPE.md` section A pre-decides each one; nothing here was put to an interview.

## Class A — delivered on the copy, no host change

- **Library-drawn art stays drawn.** Core 11, DebugLog 20 and OptionsIdList 5 say a pruned copy draws
  `close` / `copy` / `clear` / `info` blank. QuickComms declares `all`, so every one ships.
- **OptionsTabs 9 drops `O.__releaseChrome`** (LibKa0s#45). Nothing in the addon called it; the stub
  mirror is removed in the re-vendor commit (01_DELTA 3g (d)).
- **DebugLogDiagnostics 3**: the identity header lists Glow and Sim when present.
- **Kit 40/41**: the icon declaration gate, the unexported kit `__` helpers, and a crashed lizard run
  counted as a complexity fail.

## Class B / C — candidates

| Candidate | Class | Evidence | Would touch | Recommendation | Blast radius |
|---|---|---|---|---|---|
| `LibKa0s-Glow-1.0` (Glow minor 1), the stateless LibCustomGlow driver | C (new major) | CHANGELOG v1.75.0, *Glow minor 1*; `docs/api/Glow/`; OWNER_SCOPE A #56 names QuickComms an adopter | `modules/Glow.lua`, a new setup seam | **Adopt** (implemented as QC-01) | Replaces code the addon owns (its LibCustomGlow calls) |
| `W.SearchBox` (Widgets 13) | B | CHANGELOG v1.75.0, *Widgets minor 13: W.SearchBox (#52)*; `docs/api/Widgets/version-13.1.4.3.2-docs.md` | none | Not adopted: OWNER_SCOPE A #52 names LootHistory, BankLedger and DropWatcher; QuickComms has no filter-bar window | n/a |
| `W.TestStrip` (Widgets 13) | B | CHANGELOG v1.75.0, *Widgets minor 13: W.TestStrip (#48)*; same document | none | Not adopted: OWNER_SCOPE A #48 names LootHistory, BankLedger, MultiMeters and DropWatcher; QuickComms' test-mode marker is on the pads' drag strip and the dial hub, which preview mode already accepts | n/a |
| `W.StepPanel` | — | Not shipped at v1.75.0: LK-11 outcome B made the step panel Sim-private (`SimPanel.lua`) | none | Not a candidate | n/a |
| `LibKa0s-Sim-1.0` (Sim, SimTimeline, SimPanel minor 1) | C (new major) | CHANGELOG v1.75.0; `docs/api/Sim/`; OWNER_SCOPE A #53/#54 names LootHistory, BankLedger and DropWatcher | none | Not adopted: QuickComms has no simulator | n/a |
| `Item.BonusIDsFromLink` (Item 3) | B | CHANGELOG v1.75.0, *Item minor 3*; OWNER_SCOPE A #51 names BankLedger and LootHistory | none | Not adopted: QuickComms reads no bonus ids (Item is vendored and unwired) | n/a |
