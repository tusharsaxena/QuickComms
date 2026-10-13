# 05 — Execution plan

The hand-off to the remediation session. Every step names its deviation ID (`02_DEVIATIONS.md`) and
its design (`04_TECHNICAL_DESIGN.md`). Each sprint ends on the green gate:
`ka0s-bounded lua tests/run.lua` (all green) and `ka0s-bounded luacheck .` (0/0). Regenerate
`docs/test-cases.md` and move the README `[tests]` badge in the same change whenever the case count
moves (testing-§5). Commit only on green and only when the owner asks. Headline: **15 roots
(1 Medium, 10 Low, 4 Info), 9 of them MUST failures**, no dependents.

## Sprint 1 — the reset act (QC-01, QC-04)

- [ ] **QC-04** Add the blast-radius case to `tests/test_schema.lua`: two callouts, a group and a pad
      created, a second profile present, a tracked `PROFILE_CHANGED` receiver. Run it against today's
      code and confirm it passes (it pins behavior, not wording).
- [ ] **QC-01** Add an assertion that `StaticPopupDialogs.QUICKCOMMS_RESET_ALL.text` equals the
      canonical options-ui-§12 sentence. Watch it go **red**.
- [ ] **QC-01** Replace the key and value at `locales/enUS.lua:63-64` and the `text` at
      `settings/Schema.lua:333` with the canonical sentence ("…configured or added in it…").
      Green.
- [ ] Gate, inventory, badge.

## Sprint 2 — combat and registration correctness (QC-02, QC-06, QC-05)

- [ ] **QC-02** Write the combat case for `Ed.Open` in `tests/test_editors.lua` (in combat it returns
      `false`, prints one line, never calls `Settings.OpenToCategory`). Red.
- [ ] **QC-02** Gate `Ed.Open` (`settings/Editors.lua:435`) on `NS.Compat.InCombat()` with the
      canonical refusal; move `Ed.RequestRefresh()` below the gate. Green.
- [ ] **QC-06** Route `modules/SendEngine.lua:330` through `NS.SafeRegisterEvent(pending, …,
      NS.rejectedEvents)`; keep `releasePending` and the held-teardown tests green.
- [ ] **QC-05** Write the degraded case in `tests/test_slash.lua` (`T.enableAddon{ skip = NO_LIBKA0S }`:
      `debug on` flips `NS.State.debug` and acks; `debug diagnostics` prints the library-absent line
      for `/qc diagnostics`). Red.
- [ ] **QC-05** Replace the stub's `DebugVerb` (`core/DebugLogSetup.lua:73`) with the routing body.
      Green; the parity suite stays green.
- [ ] Gate, inventory, badge.

## Sprint 3 — marks (QC-07)

- [ ] **QC-07** `modules/Pad_Render.lua:131` → `NS.Icon("lock") or LOCK_ICON`;
      `modules/Dial_Render.lua:175` → `NS.Icon("lock") or LOCK_ICON`;
      `modules/Dial_Render.lua:65` → `NS.Icon("close") or CLOSE_ICON`; tint the white art.
- [ ] **QC-07** Decide `MORE_ICON` / `POINTER_ICON` against `chevron-right` and an arrow (optional).
- [ ] **QC-07** Add a PAD and a DIAL step to `docs/smoke-tests.md` for the new padlock and close glyph.
- [ ] Gate.

## Sprint 4 — the conformance suite (QC-03)

Runs after Sprints 2–3 so it pins the final shapes.

- [ ] **QC-03** Step 1: capture `R_on` with messages, `T_on`, `F_on` on `T.enableAddon()`.
- [ ] **QC-03** Step 3: add the message half (`-- red under: drop NS.Bus:StandDown() in NS.StandDown`).
- [ ] **QC-03** Step 5: every frame in `F_on` hidden.
- [ ] **QC-03** Step 6: fire every `R_on` event, `PLAYER_REGEN_DISABLED` by name; zero SV writes, prints
      and shows (`-- red under:` comment); re-assert zero timers (step 4).
- [ ] **QC-03** Step 7: iterate `NS.COMMANDS` plus the bare `/qc`; pin the six real feature verbs'
      one-line refusal and no write.
- [ ] **QC-03** Step 8: left-click opens the panel with zero writes; right-click grays *Locked* and
      *Test mode*.
- [ ] **QC-03** Step 9: a setting changed while disabled comes back on stand-up.
- [ ] **QC-03** Step 10: `perf` and `disabled` holds in both orders (`-- red under:` comment).
- [ ] For each new negative case, mutate the implementation named in its comment and watch it go
      red, then restore from a `cp` backup (testing-§12). Never `git checkout` mid-change.
- [ ] Gate, inventory, badge.

## Sprint 5 — documentation and conventions (QC-08, QC-09, QC-10, QC-11, QC-12, QC-13, QC-15)

- [ ] **QC-08** Re-run the compat count (27 today); fix `docs/compat-layer.md:9-10` and
      `docs/ARCHITECTURE.md:232`; add the `BindingLabel` and `BindingKey` rows; correct
      `docs/ARCHITECTURE.md:47` (Compat wired for its guards).
- [ ] **QC-09** Add the guard-arm comment at `core/Compat.lua:9-17`.
- [ ] **QC-10** Rewrite `QuickComms.toc:48`, `QuickComms.toc:54` and `core/QuickComms.lua:18-19`.
      Comments only; no line moves.
- [ ] **QC-11** Replace `boundSig` (`modules/SendEngine.lua:293-297`) with `NS.DebugChanged`.
- [ ] **QC-12** Rename the seven bucket keys to lowerCamelCase across `core/PerfSetup.lua`, the call
      sites, the `within`, the tests and `docs/performance.md`, in one change.
- [ ] **QC-13** Pass `colorDecode` / `colorEncode` in `settings/OptionsSetup.lua`, if the library's
      codec signature allows a plain identity.
- [ ] **QC-15** Comment out or delete `.pkgmeta:13` (`.playwright-mcp`).
- [ ] Gate.

## At release (QC-14)

- [ ] **QC-14** In the 0.1.0 release change, before the tag: run the full four-suite bundle on a clean
      tree, write its `ANALYSIS.md`, and give `modules/Library.lua` a band disposition in
      `docs/automated-tests/RESULTS.md`. The release gate needs all four suites at `pass`, zero CCN > 15,
      `blindFiles` 0.

## Not in scope of this plan

No re-vendor is owed: the payload is byte-identical to `v1.71.0`. No register row is owed: nothing
here is a ratified deviation, and every item above is a fix. If the owner chooses to keep any item
as-is (QC-12 is the likeliest), record it as a row in `docs/ARCHITECTURE.md` →
`## Documented deviations` with its `filename-§N` rule, reason, date and re-check trigger, rather than
leaving it to the next audit to re-file.
