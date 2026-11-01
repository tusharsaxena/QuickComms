# Open and close animations (#13): plan

Spec: `docs/superpowers/specs/2026-11-01-open-close-animations-design.md`. Branch `feat/2026-11-01-full-skinning`, this checkout. Subjects start `#13: `. Each checkpoint ends green (`lua tests/run.lua`, `ka0s-bounded luacheck .`). Git is the state: a checkpoint is done when its commit exists.

- [ ] **T1 Spec and plan** committed.
- [ ] **T2 Schema:** `D.PadAnim`, `D.DialAnim`, templates, rows, pins, Animation tabs, migration 12. Tests first.
- [ ] **T3 State machine:** `modules/Anim.lua`, tests for poses, easing, reversal, stand-down.
- [ ] **T4 Ghost:** `modules/Anim_Ghost.lua`, mock regions and children, capture tests.
- [ ] **T5 Dial:** hooks, silent rebuilds, emphasis, tests incl. combat and one-switch independence.
- [ ] **T6 Pad:** hooks, alpha hold, tests.
- [ ] **T7 Docs:** ARCHITECTURE, schema, module map, taint, performance, settings-panel, smoke tests, test-cases, badge.
