# 03 — Decisions (LibKa0s v1.76.0 -> v1.77.0)

Every decision below comes from the QC-RV item spec of Ka0sAddonsCommonTasks
`docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/plan-data/items.json` ("the adoptions this run needs are
the QC-KB and QC-ZS items, so record every other candidate as 'deferred (run 2026-10-24)' in the
bundle and file nothing"). The re-vendor ran in the run's M2, which is non-interactive: no interview
was held and no GitHub issue was filed.

| Candidate | Decision | Source | Issue |
|---|---|---|---|
| Keybindings tab (`KeybindingsTab`, `KeybindRows`, `KEYBINDS_UNCHANGED`) | adopt in QC-KB | item spec; OWNER_SCOPE 015 | none filed |
| Kit `mock_bindings.lua`, `assertBindingsXml`, `keybindThroughTab` | adopt in QC-KB | item spec | none filed |
| DragHandle `level` / `ignoreParentAlpha` / `ApplyLevel` | as QC-ZS decides (held for the owner) | item spec; OWNER_SCOPE 030 | none filed |
| Kit `mock_layers.lua` | as QC-ZS decides | item spec | none filed |
| `O.StrataTooltip` | deferred (run 2026-10-24) | item spec | none filed |
| `Core.RaiseStaticPopups()` | deferred (run 2026-10-24) | item spec | none filed |
| `LibKa0s-Sim-1.0` | not adopted (settled) | `2026-10-22-v1.75.0/03_DECISIONS.md` | none filed |

The four Options degradation stub members are not a decision: they are 3g's blocker, fixed in the
re-vendor commit.
