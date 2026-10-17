# Icon browser Implementation Plan

> **For agentic workers:** resumable: read the ledger, continue at the first row not `done`. Each task ends green (`ka0s-bounded lua tests/run.lua`, `ka0s-bounded luacheck .` 0/0) and with one commit on `feat/icon-browser`.

**Goal:** an icon browser window over the callout popup with Suggested / Markers / Game icons / Glyphs tabs, and per-member glyph tint drawn everywhere.

**Spec:** `docs/superpowers/specs/2026-10-18-icon-browser-design.md`

## Global constraints

- Lua 5.1, WoW Retail 12.1.5; LibKa0s v1.71.0 vendored (never edit `libs/` or `tests/_kit/`).
- Library is the only registry writer; member fields go through `NS.SchemaRuntime.Set`.
- Files CRLF (.gitattributes); `docs/test-cases.md` equals `lua tests/run.lua --list`; README badge equals its Total.
- No version bump; no push or merge by agents.

## Review focus

1. A stored glyph with a color, then a game icon chosen: the color must be cleared in the same act.
2. Game icon list empty or not loaded yet on first open (`GetMacroIcons` returns nothing until the client loads it).
3. Browser opened from the popup: Escape closes the browser only, not the popup.
4. Popup closes (profile change, settings hidden, combat cover) while the browser is open: the browser closes as Cancel.
5. Import of an old string (no `iconColor`) and of a bad color.

## Ledger

| Task | What | Status | Commit |
|---|---|---|---|
| T1 | Data model: `iconColor` on callouts and groups (validator, member rows, Prepare, Share, popup draft) + tests | done | a437c65 |
| T2 | Tint drawn everywhere the icon is drawn (pads, dials, settings lists, previews) + tests | todo | |
| T3 | Icon browser window (tabs, virtualized grid, Spell/Item filter, swatch + ColorPickerFrame, Choose/Cancel, stacking, combat); editors show icon + Choose icon… + swatch; inline grid removed + tests | todo | |
| T4 | Docs: ARCHITECTURE, settings-panel, schema, data-flow, smoke-tests (new EDIT steps), test-cases + badge, locales | todo | |
