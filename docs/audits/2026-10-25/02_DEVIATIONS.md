# 02 — Deviations: Ka0s Quick Comms

Audited against the Ka0s WoW Addon Standard **v2.88.0** (network fetch of published `master`
`36da4ef`; see `01_CURRENT_STATE.md`) at commit `18a2b55`. Prefix **`QC-`**, kept from the first
audit (2026-10-13); recurring deviations keep their IDs and new ones continue at QC-16. Grades are by
impact (`AUDIT.md` step 5): a doc-, test- or config-only failure is Low or Info even where the rule is
a MUST, and each entry still names the rule's strength.

## Tally

| | High | Medium | Low | Info | Total |
|---|---|---|---|---|---|
| **Headline (roots only)** | 0 | 0 | 16 | 2 | **18** |
| **Total including dependents** | 0 | 0 | 16 | 2 | **18** |
| **MUST failures (roots)** | 0 | 0 | 14 | 0 | **14** |
| **MUST failures (incl. dependents)** | 0 | 0 | 14 | 0 | **14** |

Basis: the headline counts root deviations only. No finding in this run is filed as a `derived from`
dependent, so the two rows agree; QC-26 names six TOC positions and is filed as one root because one
labelling decision produced all six (toc-file-§5's own grading would count six rows; the positions
are listed in `03_EVIDENCE.md` E-26). Of the 16 Low roots, 14 fail a MUST, one a SHOULD (QC-28) and
one a convention (QC-29); the two Info roots (QC-14, QC-30) are observations. **Excluded from every
row above:** the seven recorded deviations QC-R1..QC-R7, each covered by a ratified register row
(Info, accepted, listed at the end), and the twelve prior IDs this run verified closed.

**Verdict: minor deviations.** Nothing reachable by a player is broken; every finding is a doc,
test, label or config gap, most of them owed by the 0.1.0 release rather than late.

## Catalog

| ID | Rule | Grade | Strength | Description | Fix direction |
|---|---|---|---|---|---|
| QC-03 | `slash-commands-§7` (*The conformance test every addon ships*, steps 6 and 8), `testing-§12`, `launcher-§6` | Low | MUST | Recurring, narrowed. `tests/test_disabled.lua` now walks all ten steps, but step 6 fires the 25 `R_on` game events and the bus messages through the live `__fire` / `SendMessage` (which reach nothing once stood down) and proves reach with `__fireUnconditional` for `PLAYER_REGEN_DISABLED` alone; step 8 never presses the Toggle Comms Pads key while **disabled** (only under the `perf` hold, and the both-holds case calls `V.TogglePads` directly, not the button). | Fire every `R_on` event through `__fireUnconditional(NS.addon, event)` and assert ≥ 1 per event with zero writes, prints and shows; add the disabled key press through `m.__pressKey` (zero writes, zero shows, exactly the refusal line). Keep the `-- red under:` comments. |
| QC-08 | `documentation-§5`, `documentation-§3` (Tier 2 trigger row) | Low | MUST | Recurring. `docs/compat-layer.md` and the hub's Conditional row say 27 shims; the documented grep answers **31**, the page's table has 30 rows and omits `Compat.UnitDisplayName`. | Re-run the grep, write the number in both places, add the `UnitDisplayName` row. |
| QC-14 | `automated-tests-§4`, `automated-tests-§3` (release gate), `layout-§1` (band) | Info | — | Recurring. The newest bundle (`20261014-002540`, `6cc22be`) is 294 commits behind HEAD: it records 0 functions above CCN 15 and one band file; the sighted run today finds **19** above CCN 15 (max 30) and **six** files in the 1000–1500 band. Each of the 19 blocks the 0.1.0 tag. Unreleased, so owed at the release run, not late. | Before tagging, cut the full four-suite release bundle; refactor (performance-§11) or rule on each of the 19; give the five new band files a disposition. |
| QC-16 | `documentation-§1` (CurseForge renderer, angle brackets) | Low | MUST | `README.md` ships three angle-bracket placeholders inside backticks — `` `<key> +1` `` (line 37), `` `<target>` `` (81), `` `[QC] /p <text>` `` (85) — which CurseForge strips as unknown HTML, so the player reads `` ` +1` ``, nothing, and `[QC] /p`. | Write them bare (`KEY +1`, `target`, `[QC] /p your text`) or in words; run the de-AI pass on the edit. |
| QC-17 | `slash-commands-§1` (the stub MUST NOT copy `FormatRow`) | Low | MUST | The library-absent Slash stub's help row is `SLASH .. " " .. name .. " — " .. desc` (`settings/Slash.lua:277`): a degraded row MUST print `cmd  desc` plainly, with no em dash. | Two spaces in place of the em dash in `helpRow`; pin the degraded help-row shape in `tests/test_slash.lua`. |
| QC-18 | `options-ui-§17` (*`disabledIf` on a color row is forbidden*), anti-pattern #74 | Low | MUST | Eleven color pairs gray out on their feature's switch: the Shine tint and both bloom pairs on Buttons and Slices (`settings/SchemaMembers.lua:492`), Pointer color (`:632`), Dot border color (`:694`), Indicator background (`:707`), and the font color inside the Slice labels and Group labels font blocks (`:741`, `:777`). The proposal to permit exactly this (gating on the feature's own switch) is open upstream, WowAddonStandards#13, unruled at v2.88.0; issue #11 here is `state:untriaged`. | Either drop `disabledIf` from the color rows (issue #11's proposal), or triage #11 as a decline and file a register row citing WowAddonStandards#13 with its ruling as the re-check trigger. |
| QC-19 | `options-ui-§21` (*Acts on an instance*; *A button that opens a confirmation ends in '…'*) | Low | MUST | `Delete group`, `Delete pad` and `Delete dial` open a StaticPopup and do not end in '…'; the Groups page's `Duplicate` names no noun. Owed at the 0.1.0 release. | `Delete group…`, `Delete pad…`, `Delete dial…`, `Duplicate group` (keys in `locales/enUS.lua`, uses in `settings/Groups.lua`, `Pads.lua`, `Dials.lua`); tests that pin the labels follow. |
| QC-20 | `packaging` (template entry binds where the file exists), `layout-§4` | Low | MUST | `.pkgmeta` ignores `media/logos/*.png` but not `media/logos/*.jpg`; the committed 1,605,114-byte `quickcomms.logo.jpg` ships in every download and the client cannot load it. | Add `  - media/logos/*.jpg   # a .jpg render of the logo, for the project page; same reason`. |
| QC-21 | `frame-layering-§4` (*Modals and tool windows sit at DIALOG, toplevel, clamped*) | Low | MUST | The callout popup and the icon browser (`settings/ModalWindow.lua` `MW.Build`) are neither toplevel nor clamped; no `SetToplevel` call exists anywhere in the addon. The register row QC-R6 covers their `FULLSCREEN` strata and the preview window's non-toplevel state, not the modals'. Owed at the 0.1.0 release. | `window:SetToplevel(true)` and `SetClampedToScreen(true)` in `MW.Build`, pinned in `tests/test_layers.lua`; or, if the level bands make toplevel harmful, widen row QC-R6 to say so. |
| QC-22 | `documentation-§3` (hub spill MUST, ~60 lines; Tier 2 accounting; file SHOULD ~400) | Low | MUST | The hub is 387 lines but 81,866 bytes, 1,047 lines wrapped at 100 columns: Module Map (201 wrapped), Settings Schema (159), Taint Notes (120, on one line) and Known Limitations (168) carry their full bodies rather than a summary and one link. `taint.md` and `known-limitations.md` are owed (their trigger is the section passing ~60 lines) and the Conditional table has **no row** for either. | Spill Taint Notes to `docs/taint.md` and Known Limitations to `docs/known-limitations.md`; cut Module Map and Settings Schema to a summary plus one link; add both Tier 2 rows. |
| QC-23 | `architecture-§5` (named non-setting state: owner module and every writer), `documentation-§3` (names never split) | Low | MUST | `db.char.padsHidden` is named (hub `:170`, `schema.md:83`) but neither names its owner module or its writer (`V.TogglePads`, `settings/SlashVerbs.lua:72-76`); `previewWindow`'s writer is named only in `schema.md:41` while the hub's named-state paragraph points there (`:179`), so the list is split across the two. Doc-only. | One named-state list, complete in one home (with QC-22's spill, `schema.md`): each key, its owner module, every writer function. |
| QC-24 | `documentation-§5` | Low | MUST | Docs drifted from code: the hub gives `locked` a default of `true` (`:134-135`) where `defaults/Profile.lua:20` and `schema.md:22` say `false`; `schema.md:21` and `settings-panel.md:26,33` still call the row *Master alpha* (the composer draws *Master opacity* since v1.77.0); today's Share removal left "share string" in the hub (`:281`) and `schema.md` (`:36-39`, `:47`) and "the Share … window" in `module-map.md:127`. | One sync pass (`/dev-copilot:sync-docs`) over the hub, `schema.md`, `settings-panel.md` and `module-map.md`. |
| QC-25 | `audit-review-history` (*every row's trigger evaluated and every evidence id resolved*) | Low | MUST | Register row `frame-layering-§1`/`§4` (QC-R6, hub `:377`) names "the Share window", removed today, and cites "QC-06, 2026-10-18": the commits carrying that id are `69719ca` / `0901b8c` of 2026-10-23, while `QC-06` resolves under `docs/audits/` to an unrelated 2026-10-13 finding (the held stand-down's `SafeRegisterEvent`). Run-plan IDs reuse the audit prefix (test names `[QC-05]` and `[audit QC-05]` mean different things). | Drop the Share window from the row; cite the commit SHAs (or the plan bundle) instead of a bare `QC-06`; give run-plan items a prefix that cannot collide with audit IDs. |
| QC-26 | `toc-file-§5` (kind (b): an append to a TOC-ordered table) | Low | MUST | The six `defaults\BuiltIns_*.lua` lines append each set to `NS.BuiltIns.order` (`defaults/BuiltIns.lua:47`), which seeding walks in order (`modules/Library.lua:782`) and `tests/test_builtins.lua:8-20` pins — yet every one is labeled `# Conventional: data` (`QuickComms.toc:89-99`), `BuiltIns_Group`'s even while naming the constraint. | Re-label the six as LOAD-BEARING (b), naming `NS.BuiltIns.order` and the order each must hold (In Group last, after the generic battleground set: D9). |
| QC-27 | `frame-layering-§5` (*`docs/ARCHITECTURE.md` points at the table in one line rather than copying it*) | Low | MUST | The hub's `## Frame layering` (`:239-263`, 25 lines) restates the tier stack — each tier with its strata and its frames — beside the `LAYERS` header comment it says it does not copy. | Reduce the section to one line pointing at `core/Constants.lua` `NS.Constants.LAYERS` (or fold that line into Taint Notes). |
| QC-28 | `testing-§14` (*SHOULD switch `--jobs` on past ~10 s*; *SHOULD record the figure*) | Low | SHOULD | The green gate now runs 1,158 cases serially at **41.8 s of CPU** (31.6 user + 10.2 system), four times the ~10 s mark noted borderline last audit; `tests/run.lua` sets no `jobs` and `RESULTS.md` records no gate time. | Measure where the time goes (testing-§14's MUST before acting), then opt into `Kit.run{ jobs = "auto" }` after a serial/sharded agreement check. |
| QC-29 | `lint` (no unfalsifiable config), `options-ui-§20` / anti-pattern #98 (no `SetBinding` / `SaveBindings` in addon code) | Low | Convention | `.luacheckrc:58-60` still grants top-level `read_globals` for `GetBindingAction`, `SetBinding`, `SaveBindings` and `GetCurrentBindingSet` under a comment describing the retired dial key box; no shipped file calls them, and the grant would let a reintroduced private key editor lint clean. | Drop the four names (keep `GetBindingKey`, which `core/Compat.lua` reads) and fix the comment. |
| QC-30 | `frame-layering-§4` (transient popup, no full-screen catcher) — scope question | Info | — | A key-opened dial shows a hidden full-screen catcher (`SendEngine.NewDialScreen`, `HIGH`) so any outside click closes it; `frame-layering-§4` forbids a catcher behind a **transient popup** (T8) but says nothing for a secure **HUD popup** (T3) that cannot use a `GLOBAL_MOUSE_DOWN` listener in combat. Recorded in the KL (hub `:279`) and the layers comment, not in the register. | Ask upstream whether T3 secure popups are in scope of the no-catcher rule; until then name the catcher in row QC-R6. |

## Recorded deviations (ratified register rows; accepted, excluded from the tallies)

Each row was read in `docs/ARCHITECTURE.md` → `## Documented deviations` (`:370-378`), its cited rule
checked against v2.88.0 and its trigger evaluated against this tree. None has fired.

| ID | Rule (row) | Decided | Status at this run |
|---|---|---|---|
| QC-R1 | `standalone-windows`, `library-stack-§8` — the callout popup and icon browser close with `SettingsFrameTemplate`'s `ClosePanelButton`, not the wrapper | 2026-10-17 | Accepted. It is a ratified row, not the four-condition terminal decline (condition 2, the catalog `close` mark, does not hold). Trigger (a ruling on Blizzard-template windows) not fired. |
| QC-R2 | `standalone-windows` — the same two windows wear the template's edge, not the Ka0s edge | 2026-10-18 | Accepted; trigger not fired. |
| QC-R3 | `localization-§1` — Glyphs tab labels derived from catalog keys, not routed | 2026-10-18 | Accepted; enUS is the only locale and LibKa0s publishes no icon labels. |
| QC-R4 | `testing` — `tests/run.lua` wraps the kit's AceDB fake to add `char` | 2026-10-21 | Accepted; kit revision 42's `mock_record.lua` still models no `char`. |
| QC-R5 | `library-stack-§7`, anti-pattern #47 — the restriction tracker copied from DropWatcher | 2026-10-22 | Accepted; LibKa0s#49 resolves (closed, rejected); none of the trigger conditions holds. |
| QC-R6 | `frame-layering-§1`, `frame-layering-§4` — dial header `DIALOG`; preview window and modals `FULLSCREEN`; preview window not toplevel | 2026-10-24 | Accepted in substance; its text is stale (QC-25) and it does not cover the modals' toplevel state (QC-21). |
| QC-R7 | `library-stack-§7` — IconStyle and the glow lifecycle kept in the addon; only the stateless Glow driver adopted | 2026-10-22 | Accepted; LibKa0s#56 resolves (closed); no trigger fired. |

## Checked and not filed

- **The disabled state is compliant in code**: one latch, every feature event unregistered, tracked
  receivers stood down, timers canceled, one held `PLAYER_REGEN_ENABLED` through `SafeRegisterEvent`
  (QC-06 closed). QC-03 is a gap in the suite, not a draw gate.
- **Slash surface while disabled**: every reserved verb, the schema CLI and `profile` answer; feature
  verbs refuse on one line; the perf hold alone gets the capture line. Conforms to v2.57.0's restored
  §2, not v2.56.0's narrowing.
- **Launcher**: one object, library clicks and tooltip, `label = NS.BRAND`, menu entries match
  `ADDONS.md`; Show window binding shaped per v2.88.0 and `Kit.assertBindingsXml` in
  `tests/test_dial.lua`.
- **Vendoring**: both diffs empty; provenance and icon lines correct; README carries no inventory;
  standard badge bare; re-vendor bundles cover every tag since the store opened.
- **Line endings**: pin, carve-outs, 20 binary marks, body byte-identical, 0 stragglers, kit EOL gate
  wired. (The playbook's literal `grep … $` checks return nothing on this CRLF-checked-out file; run on
  a CR-stripped copy they all pass — `03_EVIDENCE.md` E-LE.)
- **Retired notation**: the `§N.M` sweep returns only citations of the addon's own design spec
  (`spec §9.2` and the like), none of the standard; 353 `filename-§N` citations (84 distinct) are all
  in range.
- **Bus, events, compat applicability, public API**: no literal message names; registration isolated
  per event with a player-reachable rejected list; no `NS.API`.
- **Settings**: tab strips on every flow-rendered page, `Master controls` first and composed, no
  hand-written font/border/bar group, no `SetBinding`/`Keybinding` widget in addon code, Keybindings
  tab last, page jump combat-gated against `:GetID()`.
- **`lock` / `unlock`** (slash-commands-§8, a MAY) exist and write the Lock frame row through the seam.
- **`## Screenshots`** absent: a SHOULD that becomes a MUST once published; not filed pre-publish.
- **`midnight-quirks.md` *Not applicable***: the client-template fallback in `core/Compat.lua`
  (`HasTemplate`) reads as an optional-API presence check rather than a version workaround; left as the
  repo states it.
