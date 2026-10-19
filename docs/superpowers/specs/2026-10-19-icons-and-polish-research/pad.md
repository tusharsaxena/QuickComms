## Comms Pad scout report (read-only)

### (1) "World" shows twice on the pad

**Root cause:** this is not a nesting or duplication bug in the section code. The two lines come from two separate sources that happen to print the same word.
- **Header row, "World  -":** `R.PaintHeader` (modules/Pad_Render.lua:292-299) writes the situation text, and `R.SituationText` (Pad_Render.lua:52-60) returns `R.CONTENT[snap.content] or R.CONTENT.openWorld`. `openWorld = L["World"]` is at Pad_Render.lua:48. The "-" is the collapse button (`qcCollapse`, Pad_Render.lua:279-284 and 298). Pad.lua `headerState` at 224-225 passes the situation in.
- **Line above the chips, "World":** this is the section title. `S.Sections` (modules/Surfaces.lua:60-73) uses `title = g.name`, `BuildPlan` copies it into `plan.sections[].title` (Surfaces.lua:152), `PL.sectionBlock` adds a `kind="title"` item (Pad_Layout.lua:104-108), and `place` draws it (Pad.lua:155-160).
- No shipped group is called "World": a grep of defaults/*.lua finds nothing. So the owner has a user group named "World", most likely with When content openWorld.
- **Nesting:** it cannot produce a duplicate. A parent's own section appears only when the parent has callouts of its own (Surfaces.lua:66-67), and every child gets its own title. The duplicate is header situation + section title.
- **Fix options (owner decides):**
  - Leave out the section title when the pad draws only one section (`groupsAs ~= "tabs"`). It already disappears in merged mode (`VisibleSections`, Pad_Layout.lua:54-61).
  - Or leave out a title that equals the situation text.
  - Or change the header text.
- **Tests:** test_pad_render.lua:121-124 (`SituationText(nil) == "World"`), test_pad.lua:59 (`qcSituation:GetText()`), test_pad_layout.lua:38 ("a titled section draws its label row first").

### (2) Chip width slider: min 1, default 100, label truncates instead of wrapping

**Where the values live today:**
- **Schema row:** settings/SchemaMembers.lua:269-271 has `min = 120, max = 300, step = 10` and `normalize = clamp(120, 300, true)`. `clamp` is at SchemaMembers.lua:61-67.
- **Default:** 140, not 120. It comes from `SURFACE_DEFAULTS.pad.layout.width = 140` (modules/Library.lua:877-878) through `T.pad.layout.width`. The owner probably reads 120 because the slider sits at its minimum.
- **Second clamp, in layout:** `PL.CellSize` (Pad_Layout.lua:81) does `math.max(PL.MIN_W, width or PL.DEFAULT_W)`. `PL.MIN_W = 120` and `PL.DEFAULT_W = 140` (lines 20-21).
- **`MIN_W` has two jobs:** it is also the narrowest pad (`width = math.max(PL.MIN_W, contentW + 2*PAD)`, line 180). It has to be split, for example a `MIN_PAD_W` that stays 120 (the header needs room for the situation text and the collapse button) and a chip minimum of 1.

**Changes for min 1 / default 100:**
- Schema row: `min=1`, `step=1` (with step 10 the slider would land on 1, 11, 21, ...), `normalize = clamp(1, 300, true)`.
- `Library.lua:878`: `width = 100`.
- `PL.DEFAULT_W = 100`.
- The CellSize clamp, split from the pad minimum as above.

**Label wrapping:**
- `R.Paint` (Pad_Render.lua:163-172) anchors `qcLabel` LEFT to the icon's RIGHT +4 (or to the button's LEFT +4 in label style), and RIGHT to `qcTag`'s LEFT -2. It calls `SetWordWrap(false)`.
- `qcTag` is anchored RIGHT -4 (line 129). The icon is a fixed `PL.ICON=20` at LEFT+2 (lines 124-125).
- Label room is therefore `w - 2 - 20 - 4 - 2 - tagW - 4`. At a narrow width that goes to zero or negative, and a FontString with a negative anchored width does not truncate reliably. I could not check this in-game; it is the likely cause of the wrap.
- **Fix:** add `SetMaxLines(1)`, and hide the label (or set it to an empty string) when the room is ≤ 0. Optionally hide the icon or tag below some width.
- `R.ApplyFont` runs after `Paint` (Pad.lua:149-150). `SetFont` does not reset the wrap setting.

**Icon tile interplay:** in icon style `CellSize` returns `ICON_ONLY` (28) whatever the width (Pad_Layout.lua:80). The width row has no `disabledIf` for icon style; adding one is optional (the `columns` row at SchemaMembers.lua:254 shows the pattern).

**Tests to update:**
- test_pad_layout.lua:67-68 asserts `CellSize({width=60}) == 120`, "never narrower than MIN_W". This must change.
- test_pad_layout.lua:34 (`box.width 436`) and :103 (collapsed `width 120`) depend on the pad minimum. Keep those.
- Add a test in test_pad_render.lua for single-line or hidden labels.

### (3) Growth: add Right and up / Left and up; Upward is broken

**Stored values:** `GROWTH` (SchemaMembers.lua:142) is `right` "Right and down", `left` "Left and down", `up` "Upward". The row is at :256-258 with `validate = oneOf(GROWTH)`. Locale strings are in locales/enUS.lua (around 406-407, plus the choice labels).

**Root cause of the broken Upward (Pad_Layout.lua:170-185, Pad.lua:178-212):**
1. **The header is pinned to the top.** `stackBlocks` always starts at `y = PL.HEADER_H + PL.PAD` (line 142), and Pad.lua anchors the header `TOPLEFT/TOPRIGHT` at y=0 (179-180). `up` only reverses the section order (line 144) and flips chip rows inside each block (line 117). So the body is always drawn below the header.
2. **The drag strip ("Comms Pad") is pinned above.** It is `SetPoint("BOTTOM", root, "TOP", 0, NS.DRAG_GAP)` (Pad.lua:212), so it always sits above the root.
3. **The root has no growth edge.** `applyPoint` (Pad.lua:60-65) anchors at the stored `point`, `DEFAULT_POINT = CENTER,CENTER,0,-150` (line 42). `SetSize` (line 253) grows a CENTER-anchored frame both ways. No growth direction pins an edge: "down" is not really down from the anchor either.
4. **`left` is not exclusive of "up".** `layout.growth == "left"` mirrors the chips (line 182), but there is no way to combine left with up.

The current test (test_pad_layout.lua:106-131) asserts this exact behaviour: section B's title at y=22, "under the header". It pins the bug and must be rewritten.

**Fix shape:**
- Split growth into a horizontal flag (`right`/`left`: mirror) and a vertical flag (`down`/`up`).
- For `up`: header row at the bottom of the root, blocks stacked upward from it, drag strip `TOP` to `root BOTTOM`, header anchored `BOTTOMLEFT/BOTTOMRIGHT`.
- Pin the root by its growth edge so a resize keeps the anchor edge in place. Either convert the stored point to a BOTTOM- or TOP-based one at apply time, or re-anchor by the edge before `SetSize`.
- `savePoint` uses `GetPoint(1)` after `StopMovingOrSizing`, and the client may rewrite that point. KickCD keeps anchor and grow orthogonal (KickCD modules/IconGrid.lua:406-407, IconGrid_Layout.lua:146) and is the precedent to copy.
- `Compute` would need to return a header position and the handle side, or Pad.lua derives them from `layout.growth`.

**Values:** for example `right` (Right and down), `left` (Left and down), `rightUp`, `leftUp`, with `up` retired.
- **Migration mechanism:** core/Database.lua:16-27. `NS.MIGRATIONS` is a list of `{to, perProfile, run(sv, profile)}`. The runner advances `global.schemaVersion` only after a step returns, a `perProfile` step walks every stored profile in `db.sv.profiles`, and each step must be idempotent against a fresh default profile (savedvariables-§1). It is at `to = 3` today.
- Add `{ to = 4, perProfile = true, run = ... }` rewriting `pads[*].layout.growth == "up"` to `"rightUp"`. v0.1.0 is unreleased, so the owner may waive this, but dev profiles hold `up`.
- **Share import is affected:** it validates each field through the row (modules/Share.lua:332). An old string carrying `up` would be dropped. Either keep `up` as an accepted alias or map it in `migrate` (Share.lua:407).
- Tests: test_database.lua for the migration step; test_share for the alias.

**Tests to touch:** test_pad_layout.lua:94-131 (left mirror, upward). Add a test in test_pad.lua for header and handle anchors under `up`; mock frames record SetPoint.

**Docs:** ARCHITECTURE.md:97 and module-map.md:45 ("upward growth stacks whole sections"), settings-panel.md:376, test-cases.md:824-825 (regenerated with `lua tests/run.lua --list`, docs/testing.md:74-75).

### (4) `/qc toggle`: show or hide all Comms Pads for the session

**Verb table:**
- `NS.COMMANDS` is in settings/Slash.lua:25-66, as positional triples. Put the new row next to lock/unlock/test.
- The body goes in settings/SlashVerbs.lua, for example `V.TogglePads()`, and the file header (line 3) lists the verbs.
- The verb is not in `LIVE` (Slash.lua:289-291), so while disabled it gets the refusal line automatically. test_disabled.lua:310-330 checks every COMMANDS entry and will cover it.
- DropWatcher precedent: DropWatcher/settings/Slash.lua:64, `{"toggle", L["Show or hide the window"], ...}`.

**How pads show and hide:**
- `Surfaces.ApplyAll` (Surfaces.lua:349-382) builds plans for the enabled pads, then `Pad.Sync`.
- `Pad.Apply` sets the secure driver: `SendEngine.SetVisibility(root, PL.VisibilityDriver(master, look.visibility, hasActive, test))` (Pad.lua:259-260). `PL.VisibilityDriver` is at Pad_Layout.lua:190-203.
- `SetVisibility` and `ClearVisibility` are refused in combat (SendEngine.lua:142-156).

**Where the flag belongs:** core/State.lua, the session-only state that resets on /reload, next to `State.testMode` and `State.previewAs`. Name it e.g. `State.padsHidden`. Two ways to apply it:
- (a) Have `ApplyAll` skip pads when the flag is set, so `Sync` releases them.
- (b) Pass the flag into `VisibilityDriver` so it returns "hide".

Either way, toggle through `S.Request("padsHidden")`. That queues behind combat through `RunOrQueue` and shows the stale hint (Surfaces.lua:388-405); alternatively refuse in combat with one line, as test mode does (Preview.lua:48-50).
- **Owner decides:** whether test mode or preview overrides the hidden flag, and whether dials are affected ("all Comms Pads", so pads only).

**Standard constraints:**
- slash-commands-§2: `toggle` is not a reserved verb. It is a feature verb, so the refuse-while-disabled SHOULD applies, and QC already implements it.
- slash-commands-§8: the "toggle" there is a lock alias that must write `locked`. Using `toggle` for visibility is a different meaning. It is allowed, because `toggle` is not reserved, but worth noting.
- **launcher-§2 (launcher.md:48-55): flag for the owner.** The options menu has a "Show window" entry (`isWindowShown`/`toggleWindow`) that must appear "exactly when the addon has the state". Pads are arguably the addon's primary display. Either wire `toggleWindow` in core/LauncherSetup.lua (around 61-66) to the same handler, or record a row in docs/ARCHITECTURE.md → `## Documented deviations`. Per CLAUDE.md, stop and ask.
- Every surface must call the one handler (Slash.lua header lines 7-8).

**Tests:** test_slash.lua (pattern at :116-150, the `why` tests, using `m.prints`). Add a test that toggle hides the pads (the driver is "hide" or the pad is released), shows them again, and the flag resets on a fresh addon.

**Docs:**
- docs/slash-dispatch.md table (lines 8-23).
- README.md:22 (the lock/unlock/test sentence).
- docs/ARCHITECTURE.md:196 (verb list).
- docs/smoke-tests.md (add a step).
- The landing page renders `NS.COMMANDS` automatically (settings/Panel.lua:4, 21-22), so it needs nothing.
- Regenerate docs/test-cases.md and the README test badge.

**Gate:** `lua tests/run.lua` and `luacheck .` must both pass with 0 errors and 0 warnings. Never edit libs/ or tests/_kit/.