# Review and audit fixes (2026-10-25) — design

## Intent

The owner ran `/dev-copilot:review all` (`docs/reviews/2026-10-25/`, findings F-001..F-011) and
`/dev-copilot:wow-standards-audit` (`docs/audits/2026-10-25/`, findings QC-03..QC-30 against
standard v2.88.0) on `18a2b55` and asked for **every** finding to be fixed before the v0.1.0 tag.
Nothing a player hits rates above Medium; the run exists to make the release gate true (perf and
complexity), close one real correctness gap (the restriction lift) and clear the doc, label, test and
config drift both passes found.

Run items are prefixed `RA-` so they never collide with audit ids (QC-25 asked for that).

## Goals

- Every finding below closed: fixed, or (where the owner ruled) recorded as a ratified deviation.
- The headless gate green after every commit: `lua tests/run.lua` and `luacheck .` (0/0), both
  through `ka0s-bounded`.
- `tests/perf.lua` green; zero functions above CCN 15 in the sighted lizard shadow.
- A fresh automated-test bundle cut at the end, so `docs/automated-tests/RESULTS.md` is current.

## Non-goals and anti-goals

- No version bump, no tag, no CHANGELOG (the owner's, through `/dev-copilot:bump-version`).
- No LibKa0s re-vendor (owner, 2026-10-25: stay on v1.77.0). `libs/` and `tests/_kit/` are never edited.
- No behavior change inside a complexity refactor (performance-§11): a refactor commit moves code only.
- No raised perf ceiling without first removing the avoidable cost, and never without the dated
  "raised because" note `tests/perf.lua` requires.
- No hand-edited generated doc: `docs/test-cases.md` comes from `lua tests/run.lua --list`, the
  automated-test record from the runner.

## Owner decisions (2026-10-25)

- **QC-18 (color rows grayed on their feature's switch): keep the behavior and record it.** Add a
  `## Documented deviations` row (`options-ui-§17` / anti-pattern #74) citing WowAddonStandards#13 as
  the pending upstream ruling and its ruling as the re-check trigger; triage issue #11 as
  `state:will-not-do` with a comment pointing at the row.
- **F-007 (General is whatever /1 is): verify, else Say.** Treat channel 1 as General only when the
  client says it is the zone General channel, by id or token, never by its localized name
  (localization-§4); otherwise the `general` kind falls back to Say exactly as it does today when
  General is not joined.
- **F-010 (LootHistory's newer LibKa0s v1.78.0 runs inside Quick Comms): stay on v1.77.0.** Record it
  as a Known Limitation (which module minors win when another Ka0s addon carries a newer LibKa0s).

## Items

| RA | Source | What | Decision / approach |
|---|---|---|---|
| RA-01 | F-001 | `padRebuild12` 87026.8 B/iter > 70656; `dialOpenClose` 2317.1 > 2048 | Guard the pad button shine paint (`modules/Pad_Render.lua` `NS.Shine.Apply`) on the look's identity and size, like `qcLookSig`; bisect the dial rise (`239b665..71c85f2`) and remove its avoidable cost the same way; re-measure; raise a ceiling only for a measured remainder, with the dated note; `docs/performance.md` follows. |
| RA-02 | F-002, QC-14 | 19 functions above CCN 15 (list in F-002) | Refactor each with performance-§11's shapes (data table + loop; module-level dispatch; named helpers); characterization test first where none covers it (testing-§13); no behavior change. |
| RA-03 | F-003 | Restrictions never re-read on `ENCOUNTER_END` / `CHALLENGE_MODE_COMPLETED` | Restrictions owns `ENCOUNTER_END` through `NS.FEATURE_EVENTS`; Situation's row forwards `CHALLENGE_MODE_COMPLETED`; refresh now and once more after a short delay (the flag can lag its event); the timer is canceled on the stand-down; new tests through the mock's event fire; header comment corrected. |
| RA-04 | F-004, QC-24, QC-25 | Share and `PinNodes` leftovers; `locked` default; *Master alpha*; scope.md says the gate is green; register row QC-R6 names the Share window and a colliding `QC-06` | One doc sweep; QC-R6 drops the Share window and cites commits, not a bare id. |
| RA-05 | F-005, QC-29 | `.luacheckrc` whitelists four retired binding globals | Drop `GetBindingAction`, `SetBinding`, `SaveBindings`, `GetCurrentBindingSet`; keep `GetBindingKey`; fix the comment. |
| RA-06 | F-006 | `SE.Arm`'s unchanged-line fast path never fires (every rebuild disarms first) | Release parks without disarming; only buttons and wedges the pool does not re-acquire are disarmed after placement; a hidden button is never clickable; pinned by a test that every button outside the active set has no `type`. |
| RA-07 | F-007 | `general` sends to whatever /1 is | Owner decision above. |
| RA-08 | F-008 | Test-only shipped functions | Delete `Tok.UsesGroupToken`, `R.CanSendChat`, `R.ActiveReason`, `Lib.DeleteCallout`, `W.HasAll` and their test asserts (no feature asks for them). |
| RA-09 | F-009, QC-14 (band) | `tests/test_page_groups.lua` exactly at the 1500-line cap; six files in the 1000-1500 band | Split `test_page_groups.lua` along its groupings (new suite registered in `tests/run.lua`); give each band file a disposition in the automated-test record. |
| RA-10 | F-011 | `Library.Children` lowercases inside its comparator | Precompute the keys once per call. |
| RA-11 | F-010 | Newer LibKa0s from another addon | Known Limitation (owner decision above). |
| RA-12 | QC-03 | Disabled test proves reach for one event only; no disabled key press | Fire every `R_on` event through `__fireUnconditional` (reach ≥ 1, zero writes, prints, shows); press the Toggle Comms Pads key while disabled through `m.__pressKey`. |
| RA-13 | QC-16 | README angle-bracket placeholders CurseForge strips (lines 37, 81, 85) | Write them bare or in words; de-AI pass on the edit. |
| RA-14 | QC-17 | Library-absent slash stub help row uses an em dash | Two spaces; pin the degraded row in `tests/test_slash.lua`. |
| RA-15 | QC-18 | Color rows gray out | Owner decision above (register row, issue #11 declined). |
| RA-16 | QC-19 | `Delete group/pad/dial` lack "…"; `Duplicate` names no noun | `Delete group…`, `Delete pad…`, `Delete dial…`, `Duplicate group`; tests follow. |
| RA-17 | QC-20 | `.pkgmeta` ships `media/logos/*.jpg` | Ignore it, with the reason. |
| RA-18 | QC-21 | Modals neither toplevel nor clamped | `SetClampedToScreen(true)` in `MW.Build`; `SetToplevel(true)` unless it breaks the level bands (a toplevel raise can lift the popup over the browser's band), in which case widen register row QC-R6 to say why; pinned in `tests/test_layers.lua`. |
| RA-19 | QC-26 | Six `BuiltIns_*` TOC lines labeled Conventional though they append to `NS.BuiltIns.order` | Relabel LOAD-BEARING (b), naming the order each holds (In Group last). |
| RA-20 | QC-28 | Gate runs serially at 41.8 s CPU | Measure where the time goes (testing-§14), then opt into `Kit.run{ jobs = "auto" }` after a serial/sharded agreement check; record the gate time. |
| RA-21 | QC-30 (Info) | Key-opened dial's full-screen catcher vs frame-layering-§4 | Name the catcher in register row QC-R6 until upstream rules on T3 secure popups. |
| RA-22 | QC-22, QC-23, QC-27 | Hub 82 KB; named state split; Frame layering restated | Spill Taint Notes to `docs/taint.md` and Known Limitations to `docs/known-limitations.md` (both registered as Tier 2 rows); cut Module Map and Settings Schema to summary + link; one complete named-state list in `docs/schema.md` (owner module and every writer, `db.char.padsHidden` and `previewWindow` included); Frame layering becomes one line pointing at `NS.Constants.LAYERS`. |
| RA-23 | QC-08 | Compat shim count 27 vs 31; `Compat.UnitDisplayName` missing | Re-run the documented grep; fix both places; add the row. |
| RA-24 | QC-14 | Automated-test record 294 commits stale | Cut a fresh bundle at the end of the run (`/dev-copilot:wow-automated-tests`); band dispositions authored. |

## Constraints

- Green gate before every commit; `libs/` and `tests/_kit/` untouched; files keep the CRLF the repo
  declares (`.gitattributes`).
- Test-count moves land with `docs/test-cases.md` regenerated and the README badge in the same commit
  (testing-§5) — done once, at integration, for the parallel tracks.
- Secure-path changes (RA-06, the refactors of `S.ApplyAll`, `Pad.Apply`, `Dial.Apply`, `DS.Load`)
  keep every attribute write out of combat and pin the write order before moving code.

## Left to the builder

The exact refactor shapes, the RA-03 delay value, the RA-07 identity source (the client API that
names a zone channel), the RA-18 toplevel outcome and the RA-20 shard decision, each recorded in the
commit that makes it.
