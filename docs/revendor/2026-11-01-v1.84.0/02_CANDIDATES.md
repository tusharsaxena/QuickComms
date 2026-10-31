# 02 — Candidates (LibKa0s v1.83.0 -> v1.84.0)

Sources: `git -C ../LibKa0s log --oneline v1.83.0..v1.84.0`, the tag's `CHANGELOG.md` `## v1.84.0` block,
and the Options API document of the new key. The item spec (Ka0sAddonsCommonTasks
`docs/2026-10-31-FINDINGS_REMEDIATION/`, M2 step 7) pre-decides each one; nothing was put to an interview.

## Class A — delivered on the copy, no host change

- **WidgetsDragHandle minors 9 and 10:** the pad strip measures its title at its own scale, writes the
  measured text fresh and repeats its fit on show. `ApplyLevel` allocates nothing.
- **The peels:** pure moves, no pixel moves.
- **WoW Default's Friz guard** (LibKa0s#69): no size moved.
- **DebugLogDiagnostics minor 6:** the report's identity header names Charts.

## Class B / C — candidates

| Candidate | Class | Evidence | Would touch | Recommendation | Blast radius |
|---|---|---|---|---|---|
| `O.PositionBlock` (#59) | B | `OptionsCompose.lua` minor 15, `O.PositionBlock` | `settings/Pads.lua`, `settings/Dials.lua`, `settings/Editors.lua`, `settings/SchemaMembers.lua` | adopt: the item spec names it | replaces the hand-built block |
| `opts.afterSubgroup` | B | `OptionsFlow.lua` minor 2 | same | adopt: the Position block's Reset hook needs it | additive |
| `shownWhen` sweep (#67) | B | options-ui §22; `OptionsSwitch.lua` | `settings/SchemaIcons.lua`, `settings/SchemaMembers.lua`, `settings/Editors.lua` | adopt: the item spec names it | replaces the host filter |
| `note` row | B | `OptionsFlow.lua` minor 2 | none named | declined: nothing here draws a dim line by hand on a schema page that this run touches | additive |
| `PageBanner{ acts }` | B | `OptionsTabs.lua` minor 13 | `settings/Pads.lua`, `settings/Dials.lua` | declined: one action is all either banner holds | additive |
| `opts.beforeGroup` | B | `OptionsFlow.lua` minor 2 | none named | declined: no line introduces a group here | additive |
| `LibKa0s-Charts-1.0` | C | `docs/api/Charts/version-1.1-docs.md` | none | declined: the addon draws no chart | additive |
