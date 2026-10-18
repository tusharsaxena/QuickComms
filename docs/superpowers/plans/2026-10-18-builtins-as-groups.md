# Built-ins as groups Implementation Plan

> **For agentic workers:** resumable: read the ledger, continue at the first row not `done`. Each task ends green (`ka0s-bounded lua tests/run.lua`, `ka0s-bounded luacheck .` 0/0, docs/test-cases.md == `--list`, README badge == Total) and with commits on `feat/builtins-as-groups`; tick the row with the commit hash.

**Goal:** every group (seeded built-ins included) is an ordinary editable group; groups nest one level through a Parent group setting; the Preview tab is a table.

**Spec:** `docs/superpowers/specs/2026-10-18-builtins-as-groups-design.md`

## Global constraints

- Lua 5.1, WoW Retail 12.1.5; LibKa0s v1.71.0 vendored (never edit `libs/` or `tests/_kit/`).
- Library is the only registry writer; member fields go through `NS.SchemaRuntime.Set`.
- Files CRLF; no version bump; agents never push or merge.

## Review focus

1. A fresh profile: seeded groups appear on the default pads/dials exactly where built-ins did, with the battleground nodes as children.
2. The owner's existing profile (built-in refs on surfaces, hidden callouts, a customized copy) loads without loss or duplicates, once.
3. Restore after deleting a seeded set (and a child) re-adds it once; running it twice adds nothing.
4. Parent rules: self, a child as parent, a parent with children taking a parent, a deleted parent, an import with parents.
5. Preview table with long text, zero callouts, and a group that is not active.

## Ledger

| Task | What | Status | Commit |
|---|---|---|---|
| T1 | Nested groups: `parent` member field, Library rules, Prepare, Share, surfaces (pad sections / dial node rings from user children), Groups page Parent dropdown + indented Group list, delete-parent behaviour + tests | done | 9f0785d |
| T2 | Seeding: built-ins become seed data; seed on new/reset profile; convert existing profiles (surface refs, hidden, customizedAs) once; remove overlay, Customize, "(built-in)", built-in Reuse section and Share built-in tab; Restore built-in groups + tests | todo | |
| T3 | Groups page parity: one tab set for every group; Preview tab as a two-column table (name, preview) matching the Callouts table's rows + tests | todo | |
| T4 | Docs: ARCHITECTURE (module map, schema, data flow, limitations), schema.md, settings-panel.md, data-flow.md, scope.md, smoke-tests (rewrite built-in steps, new nesting/restore/preview steps), README, superseded notes in older specs, test-cases + badge | todo | |
