# 02 — Deviations: Ka0s Quick Comms

Audited against the Ka0s WoW Addon Standard **v2.80.0** (local `WowAddonStandards` working tree,
`8aad69d`; see `01_CURRENT_STATE.md`). Prefix **`QC-`**, assigned on this first audit. Grades are by
impact (`AUDIT.md` step 5): a doc-only or test-only failure is Low or Info even where the rule is a
MUST, and each entry still names the rule's strength.

## Tally

| | High | Medium | Low | Info | Total |
|---|---|---|---|---|---|
| **Headline (roots only)** | 0 | 1 | 10 | 4 | **15** |
| **Total including dependents** | 0 | 1 | 10 | 4 | **15** |
| **MUST failures (roots)** | 0 | 1 | 8 | 0 | **9** |
| **MUST failures (incl. dependents)** | 0 | 1 | 8 | 0 | **9** |

Basis: the headline counts root deviations only; no finding in this run is a `derived from` dependent,
so the two rows agree. The remaining six are SHOULD or convention failures (QC-11, QC-12, QC-13) and
observations (QC-10, QC-14, QC-15). Nothing is filed as *accepted*: the register reads "None." and the
issue store holds no decline.

**Verdict: minor deviations.**

## Catalog

| ID | Rule | Grade | Strength | Description | Fix direction |
|---|---|---|---|---|---|
| QC-01 | `options-ui-§12` | **Medium** | MUST | The global-reset confirmation drops "or added" from the verbatim canonical text, so in an addon whose profile holds the player's own callouts, groups, pads and dials the warning does not say those are deleted. | Use the canonical sentence exactly: key and value in `locales/enUS.lua`, the `text` in `settings/Schema.lua`; pin it in a test. |
| QC-02 | `options-ui-§2` | Low | MUST | `Ed.Open` calls `Settings.OpenToCategory` for a page jump with no `InCombatLockdown()` gate. The page-jump carve-out requires the open to be combat-gated; today only the library's combat cover keeps its three callers out of combat. | Refuse in `Ed.Open` itself under `InCombatLockdown()`, with the canonical gray refusal line, and add a test. |
| QC-03 | `slash-commands-§7` (*The conformance test every addon ships*), `testing-§12` | Low | MUST | `tests/test_disabled.lua` asserts steps 1–4 and parts of 7–9. It skips step 5 (frames hidden), step 6 (fire every `R_on` event, combat entry by name; zero writes, prints, shows), step 7 in full (every `NS.COMMANDS` entry, the bare `/qc`, the real feature verbs), step 8's left-click and grayed entries, step 9's setting changed while disabled, step 10 (both hold orders), and the message half of step 3. Only step 3 carries a falsification comment. | Extend the suite to all ten steps against the real addon (not only the probe), with `-- red under:` on steps 3, 6 and 10. |
| QC-04 | `options-ui-§12` (*Testing*) | Low | MUST | No case proves the global reset's blast radius: two or more created members back to the shipped set, the profile list and active profile unchanged, session rows swept, `PROFILE_CHANGED` published. | Add one case to `tests/test_schema.lua` that builds two callouts, a group and a pad, resets, and asserts all four. |
| QC-05 | `debug-logging-§7`, `debug-logging-§14` | Low | MUST | The DebugLog stub's `DebugVerb` always answers `false`, so on a library-absent load `/qc debug on`/`off` falls through to `Toggle()`: the flag is not flipped and no ack is printed. `/qc debug diagnostics` prints the console-unavailable line instead of the library-absent `/qc diagnostics` line. | Give the stub a `DebugVerb` that routes `diagnostics` to `RunDiagnostics`, `on`/`off` to `SetEnabled`, and answers `false` otherwise; add a degraded case. |
| QC-06 | `events-frames-taint-§1` | Low | MUST | The held stand-down registers `PLAYER_REGEN_ENABLED` with a direct `pending:RegisterEvent`, bypassing the `SafeRegisterEvent` family every other registration uses. | Register through `NS.SafeRegisterEvent(pending, …, NS.rejectedEvents)` and handle a refusal by running the teardown at the next out-of-combat edge. |
| QC-07 | `library-stack-§8`, anti-pattern #63 | Low | MUST | The pads and dials draw Blizzard textures for marks the shared catalog carries: the padlock (`PetBattle-LockIcon`, twice) and the dial hub's close (`UI-StopButton`), where the catalog has `lock` and `close`. | Draw them through `NS.Icon("lock")` / `NS.Icon("close")`, keeping the Blizzard texture as the `nil` fallback. |
| QC-08 | `documentation-§5`, `documentation-§3` (Tier 2 trigger row) | Low | MUST | Docs drifted from code. `docs/compat-layer.md` and the hub's Conditional row say 25 shims; the documented grep returns 27, and the compat table has no rows for `BindingLabel` or `BindingKey`. The hub says `LibKa0s-Compat-1.0` is "vendored and not wired", but `core/Compat.lua` resolves it for `IsSecret`/`IsSafeKey`. | Re-run the count and update both docs; add the two rows; correct the hub's wiring sentence. |
| QC-09 | `options-ui-§1` (Compat's guard arm) | Low | MUST | `Compat.IsSecret` and `Compat.IsSafeKey` carry library-absent guard-arm bodies with no comment naming the Compat API document's *Degradation* section, which the guard-arm shape requires. | Add the one-line comment citing `LibKa0s docs/api/Compat/version-1-docs.md`, *Degradation*. |
| QC-10 | `toc-file-§5` | Info | — | Three comments misdescribe the code: the TOC calls `core\Compat.lua` LOAD-BEARING because it "needs NS.SafeToString", which it never reads (no later file captures `NS.Compat` either); the TOC says `core\State.lua` is read "at call time" when seven modules and two settings files capture `NS.State` at load (pinned anyway by folder order); and `core/QuickComms.lua:18` still says "None yet" about feature events. No load-bearing position goes unannotated, so this is not a MUST row. | Rewrite the three comments to say what actually resolves. |
| QC-11 | `debug-logging-§9` | Low | SHOULD | `SendEngine.BindKeys` keeps a hand-rolled log-on-change memo (`boundSig`) where `NS.DebugChanged` exists, and no `onClear` re-arms it, so the line stays silent after a console Clear. | Replace with `NS.DebugChanged("bind", "Bind", "bound %s", …)` and drop `boundSig`. |
| QC-12 | `naming-cheatsheet` (Perf buckets) | Low | Convention | The seven perf bucket keys are dotted (`situation.refresh`, `bake.surface`) rather than lowerCamelCase named for the path they time. | Rename to `situationRefresh`, `bakeSurface` and the rest in the descriptor, the call sites, the `within` and `docs/performance.md`, in one change. |
| QC-13 | `options-ui-§1` | Info | SHOULD | The Options descriptor supplies no `colorDecode`/`colorEncode`. The stored shape matches the library default `{r,g,b,a}`, so only the SHOULD to write the contract out is missed. | Pass the two identity functions with a comment naming the stored shape. |
| QC-14 | `automated-tests-§4`, `layout-§1` (1000–1500 band) | Info | — | The only record (`20261013-094801`, `fdf7756`) is 110 commits behind HEAD: 137 cases and 2632 NLOC there, 665 and 18,663 now. `modules/Library.lua` (1017 lines) has entered the on-notice band since, unrecorded. Unreleased, so this is owed at the 0.1.0 release run rather than late. | At release, run the full four-suite bundle and give `modules/Library.lua` a band disposition. |
| QC-15 | `packaging` | Info | — | `.pkgmeta` ignores `.playwright-mcp`, which does not exist in this checkout, so the line asserts something false. | Drop the line, or comment it out as the template does for absent folders, until the directory exists. |

## Notes on what was checked and not filed

- **The disabled state is compliant in code**: one latch, every feature event unregistered through
  `NS.StandDown`, tracked bus receivers taken down, timers canceled, the secure half held to one
  `PLAYER_REGEN_ENABLED` registration released when it fires. QC-03 is a gap in the **suite**, not a
  draw gate.
- **`Bindings.xml`** meets every v2.80.0 condition. Against `origin/master` (v2.79.x) it would have
  been a `layout-§1` finding.
- **`lock` / `unlock`** are registered and write the Lock frame row through the seam
  (`slash-commands-§8`, a MAY).
- **No `## Screenshots`**: a SHOULD that becomes a MUST once published. Not filed for an unpublished
  addon.
- **`docs/brainstorm/` excluded from lint**: it is this repo's declared frozen store (one go/no-go
  harness Lua file) and not a test-tree exclusion, so `lint`'s narrowing MUST is not breached.
- **Gate speed**: 10.8 s wall serial, at the ~10 s point where `testing-§14` suggests `--jobs`. A
  borderline SHOULD, recorded here and not filed.
