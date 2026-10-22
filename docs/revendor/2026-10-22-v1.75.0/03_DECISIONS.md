# 03 — Decisions (LibKa0s v1.74.0 -> v1.75.0)

Every decision below is the owner's or the run lead's, recorded in Ka0sAddonsCommonTasks
`docs/2026-10-22-LIBKA0S_ISSUES_45_58/inputs/OWNER_SCOPE.md` section A. The re-vendor ran in the
run's M2, which is non-interactive: no interview was held and no GitHub issue was filed for any
decline.

| Candidate | Decision | Source | Issue |
|---|---|---|---|
| `LibKa0s-Glow-1.0` | **adopt** (QC-01) | OWNER_SCOPE A #56 (owner: promotion; adopters DropWatcher, QuickComms, KickCD) | none |
| `W.SearchBox` | not adopted | OWNER_SCOPE A #52 (adopters LootHistory, BankLedger, DropWatcher); no filter-bar window here | none filed |
| `W.TestStrip` | not adopted | OWNER_SCOPE A #48 (adopters LootHistory, BankLedger, MultiMeters, DropWatcher); the marker lives on the drag strip and dial hub | none filed |
| `LibKa0s-Sim-1.0` | not adopted | OWNER_SCOPE A #54 (simulators in LootHistory, BankLedger, DropWatcher); no simulator here | none filed |
| `Item.BonusIDsFromLink` | not adopted | OWNER_SCOPE A #51 (adopters BankLedger, LootHistory); no bonus-id read here | none filed |
| `W.StepPanel` | not a candidate | LK-11 outcome B: Sim-private, not shipped as a Widgets surface | n/a |

The `LibKa0s icons: all (icon browser).` line and the `H.__releaseChrome` stub removal are not
adoption decisions: both are required by v1.75.0 itself (library-stack-§7) and land in the re-vendor
commit (OWNER_SCOPE A #57 and G).
