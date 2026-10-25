# 05 — Execution plan: 2026-10-25 audit remediation

Ordered, checkable steps for the separate remediation engagement, each tied to its deviation ID
(`02_DEVIATIONS.md`) and its design (`04_TECHNICAL_DESIGN.md` section). Green gate after every commit:
`lua tests/run.lua` and `luacheck .` (0/0), both through `ka0s-bounded`. Work on a
`feat/<date>-audit-fixes` branch; nothing is merged, pushed, tagged or version-bumped without the
owner's word.

Counts quoted here match `02_DEVIATIONS.md`: 18 root deviations (16 Low, 2 Info), 14 MUST failures,
plus 7 accepted register rows needing no action beyond QC-25's row edit.

## Sprint 1 — quick, mechanical (one commit each)

- [ ] **QC-20** (E) Add `media/logos/*.jpg` to `.pkgmeta`'s ignore list with its reason comment.
- [ ] **QC-29** (E) Drop the four unused binding names from `.luacheckrc` `read_globals`, fix the comment; `luacheck .` stays 0/0.
- [ ] **QC-17** (C) Plain two-space help row in the library-absent Slash stub; add the degraded-row test (`-- red under:` the em dash).
- [ ] **QC-26** (F) Re-label the six `defaults\BuiltIns_*.lua` TOC positions LOAD-BEARING (b), naming `NS.BuiltIns.order`.
- [ ] **QC-16** (A) Replace the three README angle-bracket placeholders (lines 37, 81, 85); de-AI pass on the edit.

## Sprint 2 — settings surface (owner call first for QC-18)

- [ ] **QC-19** (B) `Delete group…`, `Delete pad…`, `Delete dial…`, `Duplicate group`: locale keys, the three page files, any test asserting the old labels, `docs/settings-panel.md`.
- [ ] **QC-18** (B) Owner chooses: (a) drop `disabledIf` from the eleven color pairs and pin "no color row carries `disabledIf`" in a schema test, closing issue #11 as `state:done`; or (b) triage #11 as a decline **and** add an `options-ui-§17` register row whose trigger is WowAddonStandards#13's ruling.
- [ ] **QC-21** (G) `SetToplevel(true)` and `SetClampedToScreen(true)` in `MW.Build`, pinned in `tests/test_layers.lua`; or record the modals in row QC-R6 if the owner keeps them as they are.

## Sprint 3 — tests

- [ ] **QC-03** (D) Step 6: `__fireUnconditional(NS.addon, event) >= 1` per `R_on` event, zero writes/prints/shows, `-- red under:` kept; messages delivered to their receivers or shown to have no live receiver.
- [ ] **QC-03** (D) Step 8: the Toggle Comms Pads key pressed while **disabled** through `m.__pressKey` — zero writes, `padsHidden` unchanged, zero shows, exactly the refusal line.
- [ ] Regenerate `docs/test-cases.md` (`lua tests/run.lua --list > docs/test-cases.md`) and move the README `[tests]` badge in the same commit.

## Sprint 4 — docs and register (one sync commit, or one per bullet)

- [ ] **QC-22** (A.1) Spill Taint Notes → `docs/taint.md`, Known Limitations → `docs/known-limitations.md`; cut Module Map and Settings Schema to a summary plus one link; add both rows to `### Conditional`.
- [ ] **QC-23** (A.2) One named-non-setting-state list in `schema.md`: `previewWindow`, `padsHidden`, `minimapPos`, each with owner module and every writer.
- [ ] **QC-27** (A.3) `## Frame layering` reduced to one line pointing at `NS.Constants.LAYERS`.
- [ ] **QC-08** (A.4) Compat count from the command (31 today) in `compat-layer.md` and the hub row; add `UnitDisplayName`.
- [ ] **QC-24** (A.5) `locked` default `false` in the hub; *Master opacity* in `schema.md` and `settings-panel.md`; no "share string" / Share window left outside frozen stores and history lines.
- [ ] **QC-25** (A.6) Row QC-R6: no Share window, SHAs in place of the bare `QC-06`, the dial screen catcher named (**QC-30**); adopt a non-colliding prefix for run-plan IDs.
- [ ] Re-run the checks that found these: the hub fold measurement, `ls docs/known-limitations.md docs/taint.md`, the compat grep, `grep -rn 'Master alpha\|share string\|Share window' docs/*.md`.

## Sprint 5 — gate speed

- [ ] **QC-28** (H) Measure the gate (wall, CPU, the dominant cost) and write the figure down; then `Kit.run{ jobs = "auto" }` once a sharded run matches the serial 1157 passed / 1 skipped / 1158 and its exit code.

## At the 0.1.0 release (owner-triggered)

- [ ] **QC-14** (H) Refactor or rule on each of the 19 functions above CCN 15 (characterization tests first, module-level defaults tables, `== nil` for falsy user choices), then `bash tests/_kit/run-automated-tests.sh --release 0.1.0`; confirm `blindFiles` 0, `crashedFiles` 0, zero CCN > 15; write band dispositions; write `## Preview and simulation data` in the release run's `ANALYSIS.md` (preview-mode, *Kept current at every release*).
- [ ] Re-check every v2.88.0 "commences at the next release" item against the tagged tree (launcher-§6 shape, options-ui-§20/§21, frame-layering) — Sprints 1-4 close the ones this audit found.

## Not to do

- Do not edit `libs/` or `tests/_kit/`; both diffs against v1.77.0 are empty and must stay so.
- Do not file register rows for QC-16, QC-17, QC-19, QC-20, QC-26 or QC-29: each is a plain fix.
- Do not re-word the seven accepted rows beyond QC-25's edit; a ratified row is changed by its owner.
