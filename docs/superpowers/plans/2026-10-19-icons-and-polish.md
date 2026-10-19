# Icons and polish (2026-10-19) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One batch of owner feedback: a much larger glyph catalog in LibKa0s (Open Iconic complete, Phosphor Fill, Game-icons) vendored into Quick Comms, per-surface icon styling with glows, and a dozen pad / settings / When fixes.

**Architecture:** Three repos on one branch name, `feat/2026-10-19-icons-and-polish`: LibKa0s (glyph generator + catalog, release v1.74.0 tagged locally on the branch tip), WowAddonStandards (options-ui-§15 sanctions composer extras, v2.84.0), QuickComms (everything else). QC tasks run sequentially on one tree; the LibKa0s and standards chains run in parallel with QC tasks Q1–Q5. Q6 onward needs the LibKa0s tag.

**Tech Stack:** Lua 5.1 (WoW), LibKa0s, Ace3, LibCustomGlow-1.0 (new to QC, copied from DropWatcher), Python 3 + Pillow + numpy + `resvg-py` (pip, in a venv) for the glyph generator, wago.tools DB2 CSVs for game ids.

**Spec:** this plan *is* the spec — owner requests of 2026-10-19 plus the owner's answers below. Per-area research (file:line maps, root causes): `docs/superpowers/specs/2026-10-19-icons-and-polish-research/{pad,pages,builtins,when,glyphs,iconstyle}.md`. Every implementer reads the research file(s) named in their task.

## Owner decisions (2026-10-19)

- Icon sets: complete **Open Iconic** (223), **Phosphor Fill** (MIT, minus `*-logo` brand marks), **Game-icons.net** (CC BY 3.0, all ~4,000, authors attributed). All **64×64**. All go **into LibKa0s** directly; vendor the new LibKa0s **into QuickComms only** (owner re-vendors the others later; attribution in consumers is tracked by LibKa0s#55).
- `/qc toggle` = show/hide every Comms Pad for the session.
- "M+ (generic)" → **"Dungeon (generic)"**, When content = **Dungeon + M+**.
- Preview as → General › Master controls via the composer's `extra` slot, treated as a **sanctioned extension**, and options-ui-§15 is amended upstream to say so.
- Glow trigger: selectable per pad / per dial — **Always / On hover / After sending**; glow off by default.

## Builder calls (made here; recorded so a reviewer can challenge them)

- B1 "World" twice: the header shows the *situation* ("World"), the line above the chips is the *section title* (a group the owner named "World"). Fix: a section title is not drawn when it equals the header's situation text (case-insensitive, trimmed). Nothing else changes.
- B2 Growth values: `right` (Right and down), `left` (Left and down), `rightUp` (Right and up), `leftUp` (Left and up). `up` is retired: migration `to=4` rewrites it to `rightUp`; Share import maps `up`→`rightUp`. For up-growth the header row sits at the **bottom** of the pad, blocks stack upward, the "Comms Pad" drag strip sits **below** the pad, and the root is pinned by its **bottom** edge so a resize grows upward from the strip; down-growth pins the **top** edge (today's CENTER anchor drifts both ways — fixed for both). KickCD IconGrid is the precedent for orthogonal anchor/grow.
- B3 Chip width: min 1, max 300, step 1, default 100. The pad minimum (120, for header room) is split from the chip minimum. Label is single line (`SetWordWrap(false)`, `SetMaxLines(1)`), truncates, hidden when its room ≤ 0.
- B4 `/qc toggle` also backs the launcher's "Show window" entry (launcher-§2: `isWindowShown`/`toggleWindow`) — one handler. Session flag `State.padsHidden`, applied through the visibility driver; queued behind combat like other surface requests. Test mode shows pads regardless (it is an explicit preview).
- B5 Callouts tab row: `[icon] Name(gold #FFD100)  channel-label(in its chat color)  text preview(muted white #B3B3B3, 40 UTF-8 chars + "…")`. Fallback icon = `Ed.NO_ICON`. Smart kinds resolve against the live snapshot; when they resolve to nothing (solo) they take PARTY color. User text is escaped with `NS.Share.Literal`. Short channel labels get new locale keys.
- B6 Instances: new `NS.GameIds.INSTANCES` = every Encounter-Journal dungeon and raid (`JournalInstance` → `Map.InstanceType` 1|2, skip world bosses), derived by `tools/derive-gameids.py`; `CANDIDATES.instances` reads it; `DUNGEONS`/`RAIDS` stay (Preview + season checks). Arena: new `NS.GameIds.ARENAS` from `Map.InstanceType==4`, one id per distinct name (prefer the id in current rated rotation; drop brawl/legacy duplicates; the dropped ids are listed in a comment). Data files stay under 1,500 lines (pack ids per line).
- B7 Built-in callout icons come from the new glyph catalog (best semantic match across all three sets), with an `iconColor` where color carries meaning (red kill, green clear, etc.). `BI.Callout`/`BI.Callouts`/`seedCallout` learn `iconColor`. Migration `to=5` (perProfile, idempotent): rename an un-renamed `bi.mplus` group, widen an unedited When, and give seeded callouts whose icon is nil or the old shipped icon the new icon/color; a `false` (cleared) icon stays cleared.
- B8 Icon styling lives in **QC** (modelled on DropWatcher `IconStyle.lua`/`Glow.lua`), not a new LibKa0s major — a new major would need its own standard change; a LibKa0s issue proposes promotion later. QC vendors `libs/LibCustomGlow-1.0` (copy DropWatcher's folder whole), TOC line before `LibKa0s.xml`, `## OptionalDeps`, DEPENDENCIES.md.
- B9 Icon settings rows are flat leaves under new top-level `pad.icon.*` and `dial.icon.*` (`fillShape` backfills one level). Set: `size` (pad 12–40 def 20 feeding chip geometry; dial 16–40 def 32 inside the fixed 44 wedge), `zoom` 0–0.25 def 0, `desaturate` def false, `alpha` 0.1–1 def 1, `tint` ColorPair (multiplies with a glyph's own color; default white = today's look), Border via `O.BorderGroup{show=true, prefix=...}` default off (dial border is a round ring: a masked disc behind the icon, icon+2×thickness), Glow: `glowEnabled` def false, `glowWhen` always|hover|send def always, `glowType` button|proc|pixel|autocast, `glowColor` ColorPair, DW's knob table (same names/ranges/defaults). "After sending" glows ~1.5 s from the send result flash. Rendered on a new **Icons** tab: pad editor `General/Groups/Layout/Look/Icons`, dial editor after `Wheel`.
- B10 LibKa0s catalog: existing 113 names/paths never move. New Open Iconic marks flat under upstream names. Phosphor `ph:<name>` → `media\icons\phosphor\<name>`, Game-icons `gi:<name>` → `media\icons\game-icons\<name>` (collision across authors → `gi:<name>-<author>`). `lib.ICONS` stays the one enumerable list; new `lib.ICON_SETS = {{id,prefix,dir,label,license}...}`. The generated name lists live in a new generated file `MediaIcons.lua` (packed strings split at load, under 1,500 lines, US spelling — the generator renames/aliases any name the prose gate rejects). Game-icons background square removed (alpha from luminance, assert corner alpha 0). License + `AUTHORS.txt` (name→author) + statement of changes ship beside the art. Media minor 5 (+ the new file's minor per releasing.md).
- B11 QC icon browser: cache `Src.Glyphs()` for the session (today rebuilt per keystroke), labels strip the set prefix, a Glyphs set filter (All / Open Iconic / Phosphor / Game-icons) read from `ICON_SETS`, Game-icons tooltip names the author. README gets `## Credits` (Open Iconic MIT, Phosphor MIT, Game-icons CC BY 3.0 + authors).

## Global Constraints

- Ka0s WoW Addon Standard governs; a deviation not ratified in `docs/ARCHITECTURE.md` › `## Documented deviations` must be raised, not shipped.
- Green gate before every commit, each repo: QC `lua tests/run.lua` + `luacheck .` (0/0). LibKa0s `lua tests/run.lua` + `luacheck .`. Standards `bash scripts/check-standard.sh` exits 0.
- Never edit QC `libs/` or `tests/_kit/` by hand — re-vendor whole from the LibKa0s tag; roll QC CLAUDE.md "Bundles LibKa0s vX" line in the same commit.
- Shipping `.lua` ≤ 1,500 lines (QC `modules/Library.lua` is at ~1,450 — new code goes in a new file, e.g. `modules/Library_Migrate.lua`, listed in the TOC).
- US English; strings through `locales/enUS.lua`; QC CRLF per its `.gitattributes`, standards repo LF.
- No QC version bump. LibKa0s v1.74.0 release commit + tag are created **locally on the branch** (tag pushed only at merge). Never merge to master without owner go-ahead. Push feature branches at milestones.
- Regenerate `docs/test-cases.md` (`lua tests/run.lua --list`, CRLF) and the README test badge when tests change.
- Commit messages end with the attribution lines from the session.

## Review Focus

1. A profile from before this batch (growth `up`, old "M+ (generic)", seeded callouts without icons, renamed groups, cleared icons) — loads, migrates once, and a second run changes nothing. → Q1 and Q7 migration tests.
2. Up-growth pad dragged and reloaded — the strip stays put and the pad grows upward from it, not drifting. → Q1 Pad anchor test (mock SetPoint record).
3. Combat: `/qc toggle`, an Icons-tab write, or a glow start while in combat on secure chips/wedges — no protected call outside RunOrQueue; glows are unprotected children. → Q2 and Q8 combat tests.
4. Share strings made before this batch (growth `up`, glyph paths) still import. → Q1 share alias test; Q6 old glyph path still `IsGlyph`.
5. Icon browser with ~5,800 glyphs — search keystrokes don't rebuild the list; no cell growth. → Q6 same-table test.

---

## Status ledger (update on every task commit)

| Task | Repo | Status | Commit |
|---|---|---|---|
| L1 Glyph generator + catalog | LibKa0s | todo | |
| L2 Release v1.74.0 (local tag) | LibKa0s | todo | |
| S1 options-ui-§15 extras | WowAddonStandards | todo | |
| Q1 Pad: title, chip width, growth | QC | done | ea04cd1 |
| Q2 /qc toggle | QC | done | e71b428 |
| Q3 Look headings + Callouts rows | QC | done | 6a34bf7 |
| Q4 Preview as → Master controls | QC | todo | |
| Q5 Instances + Arena drawers | QC | todo | |
| Q6 Vendor LibKa0s v1.74.0 + icon browser | QC | todo | |
| Q7 Dungeon (generic) + built-in icons | QC | todo | |
| Q8 Icon styling + glows | QC | todo | |
| Q9 Docs sync + final review | QC (+all) | todo | |

---

### Task L1: Glyph generator + catalog (LibKa0s)

Research: `glyphs.md`. **Files:** Modify `tools/artwork/icon_cleaner.py`, `LibKa0s/Media.lua`, `LibKa0s/LibKa0s.xml`, `tests/test_media.lua`, `tests/majors.lua`, `DEPENDENCIES.md`, `README.md` (credits); Create `LibKa0s/MediaIcons.lua` (generated), `LibKa0s/media/icons/phosphor/*.tga` + `LICENSE-phosphor.txt`, `LibKa0s/media/icons/game-icons/*.tga` + `LICENSE-game-icons.txt` + `AUTHORS.txt`, the 111 new Open Iconic TGAs, `docs/api/Media/version-5…-docs.md` + members json via `lua tools/gen-api-members.lua`.

**Interfaces — Produces:** `lib.ICONS` (all names), `lib.ICON_SETS` (array of `{id="open-iconic"|"phosphor"|"game-icons", prefix=""|"ph:"|"gi:", dir=""|"phosphor"|"game-icons", label, license}`), `lib.Icon(addonName, name, vendorPath)` resolves prefixed names, nil for unknown/unknown prefix; `lib.IconAuthor(name)` → author string for `gi:` names, else nil.

- [ ] Write failing tests in `tests/test_media.lua`: per-set both-direction file↔name check (recursing via ICON_SETS dirs); each set's license file exists; `Icon(_, "ph:sword")` ends `media\icons\phosphor\sword`; `Icon(_, "zz:sword")==nil`; `#ICONS > 5000`; no duplicate names; `close` path unchanged; `IconAuthor("gi:<some>")` non-nil.
- [ ] Extend the generator: `--fetch` shallow-clones phosphor-icons/core and game-icons/icons into `.cache` (pin commit SHAs, recorded in the file), renders SVG via `resvg_py.svg_to_bytes(svg_string=..., width=64, height=64)` into the existing recolor→solidify→fit→normalize→tga_rle chain; Game-icons alpha from luminance; asserts corner alpha 0; drops Phosphor `*-logo`; writes `MediaIcons.lua` and `AUTHORS.txt`; renames names the prose gate rejects.
- [ ] Run it (venv: `python3 -m venv .venv && .venv/bin/pip install resvg-py pillow numpy`; note in DEPENDENCIES.md), inspect a sample of renders (read a few TGAs as PNG) for orientation, whiteness and no background.
- [ ] Media minor 5 + new-file minor per `docs/releasing.md`; api docs; green gate; commit.

### Task L2: Release v1.74.0 (LibKa0s, local tag)

- [ ] Follow `docs/releasing.md` exactly: CHANGELOG block, provenance template → v1.74.0, `docs/test-cases.md`, clean-tree `tests/_kit/run-automated-tests.sh --release 1.74.0` bundle commit, then `git tag v1.74.0` on the branch tip. Do NOT merge to master; push the branch (not the tag).
- [ ] Measure QC's `tests/test_vendor_sync.lua` runtime impact later in Q6 (payload ~21 MB).

### Task S1: options-ui-§15 sanctions composer extras (WowAddonStandards)

- [ ] Amend `standards/standards/options-ui.md` §15: an addon MAY append its own rows after the canonical Master-controls set through the composer's `extra` slot (never interleaved, never reordering/renaming the set, before the Reset pair); cite Quick Comms' Preview as as the case. Ripple to `EXECUTIVE_SUMMARY.md`/`NEW_ADDON_CONTEXT.md` if they restate §15; bump version to v2.84.0 + date 2026-10-19, move the previous changelog entry to `standards/CHANGELOG.md`; `bash scripts/check-standard.sh` → 0; commit; push branch.

### Task Q1: Pad — duplicate title, chip width, growth (QC)

Research: `pad.md` §1–3. **Files:** `modules/Pad.lua`, `modules/Pad_Layout.lua`, `modules/Pad_Render.lua`, `settings/SchemaMembers.lua`, `modules/Library.lua` (default width 100 only), `modules/Share.lua` (alias), `core/Database.lua` (+ migration to=4, body in a new `modules/Library_Migrate.lua` if Library.lua lacks room), `locales/enUS.lua`, tests `test_pad_layout.lua`, `test_pad.lua`, `test_pad_render.lua`, `test_database.lua`, `test_share.lua`.

- [ ] Failing tests: title equal to situation not drawn (B1); `CellSize({width=60})` → 60 wide; default width 100; label `SetMaxLines(1)` and hidden at room ≤ 0; `rightUp`/`leftUp` Compute puts header at bottom and blocks above, and Pad anchors header BOTTOM, strip TOP→root BOTTOM, root pinned by BOTTOM edge; down pins TOP; migration rewrites `up`→`rightUp` once, idempotent on fresh profile; Share import of `up` lands `rightUp`.
- [ ] Implement per B1–B3; rewrite the test that pinned the old upward bug (`test_pad_layout.lua:106-131`).
- [ ] Green gate; commit.

### Task Q2: `/qc toggle` (QC)

Research: `pad.md` §4. **Files:** `settings/Slash.lua`, `settings/SlashVerbs.lua`, `core/State.lua`, `modules/Pad_Layout.lua` (`VisibilityDriver` takes the flag), `modules/Surfaces.lua`, `core/LauncherSetup.lua`, `locales/enUS.lua`, `tests/test_slash.lua`, launcher test, README/`docs/slash-dispatch.md`/ARCHITECTURE verb list, `docs/smoke-tests.md`.

- [ ] Failing tests: toggle hides (driver "hide"), toggles back, flag absent on a fresh addon, refused while disabled (covered by test_disabled), launcher "Show window" uses the same handler and reflects state, combat queues.
- [ ] Implement per B4; green gate; commit.

### Task Q3: Look headings + Callouts rows (QC)

Research: `pages.md` §1, §3. **Files:** `settings/Pads.lua`, `settings/Groups.lua`, `settings/Editors.lua` (optional `entry.ghost`), `modules/Channels.lua` or `Pad_Render.lua` (export the tag color helper), `modules/Library.lua` (export `firstChars` if used — mind the cap), `locales/enUS.lua`, `tests/test_page_pads.lua`, `tests/test_page_groups.lua`.

- [ ] Failing tests: each Look heading occurs exactly once (`#P.all(w,"Heading",h)==1`); Callouts row label carries gold name escape, the channel's color escape + short label, text truncated at 40 chars with "…", `|` escaped, fallback icon when none.
- [ ] Implement (single `h.RenderRows(... noHeadings)` call; delete `PD.LOOK_GROUPS`/`PD.LookRows`); B5; green gate; commit.

### Task Q4: Preview as → General › Master controls (QC)

Research: `pages.md` §2. **Files:** `settings/Panel.lua`, `settings/SchemaRows.lua`, `settings/Pads.lua`, `settings/Dials.lua`, `settings/Groups.lua`, `locales/enUS.lua`, tests `test_schema.lua`, `test_page_pads.lua`, `test_page_dials.lua`, `test_page_groups.lua`, a General-page test; docs `settings-panel.md`, ARCHITECTURE.

- [ ] Failing tests: `state.previewAs` is in Master controls after `state.testMode` (via `Settings.RowsForPage("general")`/schema order); the dropdown is absent from the Pads/Dials/Groups General tabs; Groups Defaults tooltip no longer claims it stops Preview.
- [ ] Implement via `MasterControls{ extra = {...} }`; cite options-ui-§15 as amended by S1 (v2.84.0) in the code comment; green gate; commit.

### Task Q5: Instances + Arena drawers (QC)

Research: `when.md`. **Files:** `tools/derive-gameids.py`, `defaults/GameIds.lua` (or new `defaults/GameIds_Instances.lua` in the TOC), `settings/Groups_When.lua`, `modules/Resolver.lua`, `modules/Library.lua` (ID_ROWS/ALL clause — prefer one shared `ID_ROWS` set), `settings/SchemaMembers.lua`, `settings/Slash.lua`, `locales/enUS.lua`; tests `test_gameids.lua`, `test_groups_when.lua`, `test_resolver.lua`, `test_library.lua`, `test_page_groups.lua`, `test_situation.lua`; docs common-tasks/module-map/ARCHITECTURE/settings-panel/smoke-tests.

- [ ] Fetch CSVs (`ct.fetch`), derive INSTANCES + ARENAS (B6); confirm Murder Row's map id is in INSTANCES; generator asserts shipped == derived.
- [ ] Failing tests: instance candidates include a non-season dungeon (stub `GetRealZoneText`, resolve by name); arena row: `CHECK.arena` matches only in arena content, `all` works, Summary/COUNT/ALL/here/NOT_HERE, drawer order updated, CLI `formatWhen`/`valuesOf` accept arena, ValidWhen accepts `arena {all=true}`.
- [ ] Implement; green gate; commit; **push QC branch (milestone 1)**.

### Task Q6: Vendor LibKa0s v1.74.0 + icon browser (QC) — needs L2

Research: `glyphs.md` §5. **Files:** `libs/LibKa0s/**`, `tests/_kit/**` (copied whole from the tag), `CLAUDE.md` provenance line, `settings/IconBrowser.lua`, `settings/IconBrowser_Sources.lua`, `locales/enUS.lua`, `README.md` (`## Credits`), tests `test_icon_browser.lua`, `test_library.lua`.

- [ ] Re-vendor exactly per LibKa0s `docs/releasing.md` "Re-vendoring consumers" (both `diff -r` checks), roll the CLAUDE.md line; vendor_sync green (note its runtime).
- [ ] Failing tests: `Src.Glyphs()` returns the same table across `SetSearch` calls; `ph:arrow-up` label reads "Arrow up"; set filter narrows to one set; a Game-icons tooltip names its author; old glyph path still `IsGlyph`.
- [ ] Implement B11; green gate; commit.

### Task Q7: Dungeon (generic) + built-in callout icons (QC) — needs Q6

Research: `builtins.md`. **Files:** `defaults/BuiltIns.lua`, `defaults/BuiltIns_*.lua`, `modules/Library.lua` (`seedCallout` copies iconColor — mind the cap), migration step to=5 (in `modules/Library_Migrate.lua`), `core/Database.lua`, `locales/enUS.lua`; tests `test_builtins.lua`, `test_database.lua`, `test_library.lua` + every test pinning "M+ (generic)" (list in research); `docs/smoke-tests.md`.

- [ ] Failing tests: every built-in callout has an icon and each glyph name resolves via `NS.Icon`; `bi.mplus` name "Dungeon (generic)", When content `{dungeon=true, mythicPlus=true}`; seeded callouts copy `iconColor`; migration to=5 cases (unrenamed → renamed; renamed untouched; edited When untouched; nil/old icon → new; false kept; idempotent).
- [ ] Choose the icon per callout (B7), implement; green gate; commit.

### Task Q8: Icon styling + glows (QC)

Research: `iconstyle.md`. **Files:** Create `libs/LibCustomGlow-1.0/` (copy DropWatcher's whole), `modules/IconStyle.lua`, `modules/Glow.lua`, `settings/Icons.lua` (or rows in SchemaMembers + tab render in Pads.lua/Dials.lua — keep files under cap); Modify `QuickComms.toc`, `modules/Pad_Render.lua`, `modules/Pad_Layout.lua` (icon size → chip geometry), `modules/Pad.lua` (release stops glow), `modules/Dial_Render.lua`, `modules/Dial.lua`, `modules/SendEngine*.lua` hook for "after sending" (no new protected calls), `modules/Library.lua` (`SURFACE_DEFAULTS`/`TEMPLATES` leaves only), `settings/SchemaMembers.lua`, `settings/Pads.lua`, `settings/Dials.lua`, `locales/enUS.lua`, `tests/wow_mock.lua` (record SetTexCoord/SetDesaturated/SetAlpha), new `tests/test_icon_style.lua`, `tests/test_glow.lua`, `test_page_pads.lua`, `test_page_dials.lua`, `test_share.lua`/`test_profile.lua` backfill; `DEPENDENCIES.md`, ARCHITECTURE (libs, taint notes), schema/settings-panel/module-map/smoke-tests/performance docs.

- [ ] Failing tests (DW's patterns: fake LibCustomGlow minor 24 recording calls): defaults keep today's look; zoom→TexCoord; desaturate; alpha; tint multiplies glyph color; pad size changes CellSize; border off by default, BorderGroup rows composed; dial ring border; glow styles call the right START/STOP with knobs; unchanged repaint makes no calls; glowWhen hover starts/stops on enter/leave; send glow starts then stops after ~1.5 s (AceTimer/C_Timer mock); released chip stops glow; combat write is queued; Icons tab exists on both editors with the expected headings once each; Defaults tooltips name the rows.
- [ ] Implement B8/B9; perf bucket for glow; green gate; commit; **push QC branch (milestone 2)**.
- [ ] File a LibKa0s GitHub issue proposing promotion of IconStyle/Glow to a LibKa0s major (consumers: DropWatcher, QuickComms).

### Task Q9: Docs sync + whole-branch review (QC + all)

- [ ] `docs/test-cases.md` regen, README test badge, ARCHITECTURE (module map, deviations unchanged unless a task added one), schema/settings-panel/smoke-tests rows for every change (new smoke steps: growth up both ways, toggle, Icons tab, glow triggers, arena drawer, instance autocomplete, icon browser sets/credits).
- [ ] Whole-branch review across the three repos; fix findings; green gates; push all three branches. Stop at the merge gate.
