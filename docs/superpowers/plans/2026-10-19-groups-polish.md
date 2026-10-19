# Groups polish (2026-10-19) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Second owner batch of 2026-10-19: default callouts for empty groups, coloured icons on every built-in callout and group, preview-while-editing a group, PREVIEW/TEST MODE in the pad's anchor strip, right-click a pad's group title to edit it.

**Architecture:** QuickComms only, branch `feat/2026-10-19-groups-polish`, tasks run in order on one tree. No LibKa0s change (glyph catalog v1.74.0 is already vendored).

**Spec:** this plan (owner requests + answers below). Previous batch plan for context: `docs/superpowers/plans/2026-10-19-icons-and-polish.md`.

## Owner decisions

- New built-in group **"World (solo)"** (When: content openWorld, group solo — matching Preview as "World · Solo") with useful solo/open-world callouts, and general map-wide callouts on the five battleground parent groups that have none of their own (Arathi Basin, Eye of the Storm, Battle for Gilneas, Deepwind Gorge, Isle of Conquest).
- Every built-in callout icon gets a color (white may be one of the colors, never the only one); every built-in group gets an icon relevant to its name.
- Editing a group previews **only that group**: the pads and dials show that group's callouts (and its child groups') and nothing else, whatever its When says. A toggle **below the Group dropdown** on the Groups page turns this on/off, **default on**.
- "PREVIEW" moves into the pad's anchor strip (where it says "Comms Pad").
- Right-clicking a group header on a pad opens settings on the Groups page with that group selected. The Groups page remembers its last tab across groups (on Callouts, a right-click only changes the dropdown).

## Builder calls

- C1 World (solo) callouts: about 8, e.g. rare spotted (with location token if one exists), need a hand with an elite, thanks for the help, group up for this quest, world boss/event here, AFK a moment, back, invite please — use `say`/`yell`/whisper-free channels that make sense solo (check `modules/Channels.lua` and `modules/Tokens.lua` for what exists; no token the bake audit rejects). Add a solo open-world snapshot to the bake audit (`BI.SNAPSHOTS`) so the set is checked. Battleground parent callouts: about 4–6 map-wide ones each (e.g. AB/EotS/BfG/DWG: "Go for X bases", "Zerg next", "Defend what we have", "Ninja X"; IoC: siege, gates, vehicles, boss push), channel as the sibling BG sets use. New ids follow `defaults/BuiltIns.lua` id rules; ids are stable once shipped.
- C2 Colors: a deliberate palette per meaning (red attack/kill/danger, green heal/clear/safe, blue mana/defend, gold/yellow lust/loot/achievement, purple CC/magic, orange incoming/warning, white neutral). `iconColor` is only kept on glyphs (Library rule) — every built-in callout icon is already a glyph; any non-glyph built-in icon is switched to a glyph. Group icons: a glyph + `iconColor` for every built-in group (generic sets, each battleground parent, each node). Groups take `iconColor` today (check `Library.lua` group create/seed path copies it; if seeding does not copy a group's iconColor, add it).
- C3 Migration (next schema step, perProfile, idempotent, in `modules/Library_Migrate.lua`): seeded callouts/groups whose icon and iconColor still equal what was shipped before this batch get the new icon/color; a player-changed or cleared (`false`) one is left alone. New callouts on existing seeded parent groups are added (by origin; never duplicated); the new World (solo) set seeds through the normal `seedNew` path. A group the player deleted is not resurrected (respect `seededSets`).
- C4 Preview while editing: a saved global setting (schema row, e.g. `behavior.previewOnEdit`, default true) drawn as a checkbox directly below the Group dropdown in the Groups page band. While the Groups page is shown with a selected group and the setting is on, every built pad and dial shows only that group (+ children) in preview (sends nothing, PREVIEW marker, same visual treatment as Preview as), regardless of the pad's group list and the group's When. It updates when the dropdown changes, and ends when the Groups page hides or settings close, restoring whatever Preview as / live state was before. Combat: follows the existing Preview rules (combat ends preview; requests queue behind combat). Test mode and Preview as precedence: edit preview wins while active; Preview as resumes after.
- C5 Anchor strip: the "Comms Pad" drag strip reads `<pad name>  PREVIEW` (PREVIEW in the existing green), and the header's centered PREVIEW text is removed; `TEST MODE` moves the same way for consistency. Strip width grows to fit. Dials are unchanged.
- C6 Right-click: a section title row (and, in tabbed group mode, a group tab) accepts right-click → `Settings` open on the Groups page with that group selected (through the page's own selection setter, so the remembered tab stays). The Groups page remembers its last tab for the session across group changes. In combat the settings panel cannot open: print the existing combat refusal line. Left-click behaviour of titles/tabs is unchanged. The hit frame is a plain (non-secure) frame created out of combat with the layout. Tooltip on the title: "Right-click to edit this group".

## Global constraints
- Ka0s WoW Addon Standard; flag any uncovered deviation instead of shipping it.
- Green gate before every commit: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua` and `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0/0).
- Never edit `libs/` or `tests/_kit/`. No version bump. Shipping `.lua` ≤ 1,500 lines. US English; strings through `locales/enUS.lua`; CRLF.
- Regenerate `docs/test-cases.md` and the README test badge when tests change; update schema/settings-panel/smoke-tests/ARCHITECTURE as rows and behaviour change.

## Review focus
1. A profile from before this batch: migration adds parent callouts once, re-colors only untouched icons, never resurrects deleted groups, idempotent.
2. Edit preview while combat starts, while Preview as is set, and when the settings window is closed with the X — the live state comes back.
3. Right-click a title in combat; in tabbed mode; on a nested child group.
4. Strip text with a long pad name and PREVIEW/TEST MODE.

## Status ledger

| Task | Status | Commit |
|---|---|---|
| R1 Built-ins: World (solo), BG parent callouts, group icons, icon colors, migration | done | d79bb09 |
| R2 Preview while editing a group | done | 47f29c7 |
| R3 PREVIEW / TEST MODE in the anchor strip | todo | |
| R4 Right-click a group title to edit it | todo | |
| R5 Docs sync + whole-branch review | todo | |
