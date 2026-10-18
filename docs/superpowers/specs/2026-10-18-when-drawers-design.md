# When drawers, Inherit when conditions, icon search: design

Date: 2026-10-18. Status: approved by the owner 2026-10-18 (mockup
https://claude.ai/artifact/Gu2RSYuRCqZpQ3PJpJBbCE approved; four questions answered). Builder calls
are recorded under "Builder calls" as each task makes them.

## Why

- The When tab is a long column of checkboxes that unfold in place; it is hard to see what is set.
  The owner wants each condition to read as a group header that opens a drawer, with the choices
  boxed inside it (behavior like DropWatcher's expanded cards, look of the settings panel).
- Seeded battleground nodes have an empty When, so they match everywhere and show a green "active"
  dot in every situation. A sub-group should be able to take its parent's conditions.
- The icon browser holds ~30k game icons and many glyphs with no way to search them.

## Goals

### 1. When tab as drawers (owner: approved mockup, Main artboard)

- One **header bar** per condition (`W.ROWS` order: Content, Instance, Difficulty, Key level, Group,
  Leader or assist, Class, Specialization, Role, Character, Battleground). The header carries a
  chevron (right when closed, down when open), the condition's name (gold while the condition is
  set, white otherwise) and, right-aligned, a **summary**: "Any" in grey while unset, else the
  chosen values, comma-separated and truncated with an ellipsis (an id list or the key level gets a
  short phrase, e.g. "2 instances", "10 or higher", "10 to 15").
- Clicking the header opens or closes its **drawer**: a box joined under the header (the header's
  bottom corners square off while open), holding the condition's choices:
  - checkbox conditions: the values in a three-column grid;
  - Key level: the Lowest and Highest boxes;
  - Instance, Character, Battleground: the existing IdList (add box with suggestions, one line per
    entry with remove) and the "Add the … you are in" button.
- Under the choices, right-aligned: **Select all** (checkbox conditions only) and **Clear (Any)**.
  Clear unsets the condition. Select all ticks every value the drawer lists.
- **No enable checkbox (owner).** A condition is set when it has values; unset reads "Any". The
  session-only "open with nothing chosen" state (`NS.State.whenOpen`) becomes the drawer's open
  state: several drawers may be open at once (owner approved the mockup's behavior); the open set is
  per group, per session, and survives a repaint.
- The "Active now." line stays on top; under it one grey line: "Every condition you set must match.
  A condition left as Any does not limit the group."
- Looks like the settings panel (fonts, gold, dark fills, thin borders); DropWatcher is a
  behavioral reference only (owner).

### 2. The Drawer is a LibKa0s component (owner)

- A new LibKa0s widget (AceGUI container) draws the header bar and the drawer body, built in the
  LibKa0s repo on branch `feat/drawer-widget`, released per `docs/releasing.md` (minor bump of the
  file(s) it lands in, `tests/majors.lua` if it is a new file of an existing major, CHANGELOG
  block, `docs/api/` document, tests), then re-vendored into Quick Comms (`libs/LibKa0s/`,
  `tests/_kit/` only if the kit changes), which also takes in LibKa0s v1.72.0's changes.
- API (builder settles exact names): label, summary text, a "set" flag (gold label), open state +
  an on-toggle callback, and a body the host fills with ordinary AceGUI children; plus a
  helper-level wrapper the Options flow can call (as `IdList` is), so a host renders a drawer the
  way it renders any row.
- **Standard flag:** `library-stack-§7` asks for two consumers before promotion. The owner chose
  the LibKa0s route for one consumer (Quick Comms); record it as a row in LibKa0s `CLAUDE.md`'s
  `## Documented deviations` (as the LineChart row is), re-check trigger "a second addon uses the
  drawer, or one release passes with none".

### 3. Inherit when conditions (owner)

- New group setting **Inherit when conditions** on the General tab, beside Parent group (a member
  row, `group.inheritWhen`, boolean). Greyed out while Parent group is None.
- **Meaning (owner): the parent's conditions instead of its own.** While ticked and the group has a
  parent, the Resolver judges the group by its parent's When; its own stored When is kept but not
  used. The parent's Enabled and When still gate the whole family as before.
- **Default on (owner)** for every sub-group, seeded or made by the player: an absent field means
  on; unticking stores `false`.
- The When tab of an inheriting group shows the parent's conditions, read-only (drawers open/close
  but the choices are disabled, no Select all / Clear), under a gold line: "Uses <parent>'s
  conditions. Untick Inherit when conditions on the General tab to set this group's own."
- The Group picker's dot, the pad, the dial, Preview as and every "why not active" line follow it.

### 4. Icon browser search

- A **search box** (magnifier glyph, clear mark) on the browser's filter row, beside the All /
  Spells / Items filter, with a count "N of M icons". It filters the current tab as you type
  (case-insensitive substring):
  - Glyphs: by glyph name (the catalog key and its shown label);
  - Game icons: by texture id (digits of the file id; a texture path string, when the macro list
    gives one, matches by its name);
  - Markers: by marker name.
- WoW has no API to read a game icon's name from its file id, so (owner) Game icons search by id
  only, and the tab shows a hint row: "Search by texture id. To find an icon by its name (e.g.
  ability_cheapshot), look it up on Wowhead and type its id here." with a button that shows
  `https://www.wowhead.com/icons` in the addon's existing copy box (WoW cannot open a URL).
- The search text is per session; switching tabs keeps it and re-filters.

## Non-goals

- No change to the When data model (other than `inheritWhen`), the Resolver's row checks, the
  bake/send path, the callout popup, or the icon catalogs.
- No icon name table shipped (owner).

## Standard check

Raise anything that breaks a Ka0s rule before committing. Settings writes go through the seam
(`group.inheritWhen` and `group.when` member rows); Library stays the only registry writer; the
LibKa0s change follows `docs/releasing.md`; `libs/` is only ever re-vendored, never hand-edited.

## Builder calls

- **[L1] Where the drawer lives.** A new eleventh file of the Options major,
  `LibKa0s/OptionsDrawer.lua` (`DRAWER_MINOR` 1), paired on the shell's minor like `OptionsNav.lua`,
  not a Widgets-major file (the Options major does not depend on Widgets) and not an append to
  `OptionsWidgets.lua` (its census trigger is "the next maker added"). `Options.lua` goes to minor
  29 for the guarded attach and one `RefreshPanel` read. Options key **29.2.34.2.4.8.1.7.4.2.1**;
  LibKa0s **v1.73.0** on `feat/drawer-widget`, not tagged, no release run (both wait on the owner).
- **[L1] Not a registered AceGUI widget type.** AceGUI's widget registry is process-global, so the
  drawer is three AceGUI `SimpleGroup`s (the drawer, its header, its box) decorated on their frames
  and handed back clean on release (the header's button hidden and deaf, the box's patched
  `OnWidthSet` / `OnHeightSet` / `LayoutFinished` and content anchors restored). The box is the
  AceGUI container the host fills.
- **[L1] API.** `H.Drawer(ctx, spec)`, `spec = { label, summary, set, tooltip, open, onToggle, body,
  actions, disabled }`; returns `{ group, header, head, body, ctx, actions, open }`. `summary` and
  `set` may be functions read at draw. `set` true: gold name, pale-gold summary; else white name,
  gray summary. The host words "Any" itself.
- **[L1] Open state is the host's.** A header click calls `onToggle(not open)` and then
  `RefreshPanel(page, true)`; refused in combat (`drawer <label>`). Q2 keeps the per-group,
  per-session open set in `NS.State.whenOpen` and passes `open` / `onToggle`; it needs no refresh of
  its own on a toggle.
- **[L1] The body ctx.** `spec.body(ctx, box)` gets a view whose `scroll` is the box, so
  `RenderGrid`, `IdList`, `TextRow`, `InlineButtonPair` draw into the box unchanged, and whose every
  other field reads and writes through to the page (so `Ed.Live(ctx, fn)` and `ctx.refreshers` land
  on the page ctx `Ed.built` holds). `RefreshPanel` on a view refreshes its page (Options minor 29).
  Never `ClearScroll` a view.
- **[L1] Select all / Clear (Any)** are `spec.actions = { { text, tooltip, onClick, disabled } }`:
  buttons on the box's last line, right-aligned behind a filler, `0.22` of the line each, `onClick`
  pcall'd and refused in combat. Q2 passes both for a checkbox condition and Clear alone otherwise.
- **[L1] Read-only (Q3's inheriting group).** `spec.disabled` draws the body under the page's
  `__renderDisabled` flag (restored after) and disables every action; the header still opens and
  closes. The library's own rows honor the flag, but Groups_When.lua's bespoke `checkbox` and key
  level `make` items do not: Q2/Q3 must call `SetDisabled` on them itself (or omit `actions`, as the
  spec's read-only view does).
- **[L1] Look.** Header 26px; chevron `Interface\ChatFrame\ChatFrameExpandArrow`, rotated a quarter
  turn while open; the name `GameFontNormal` at x=26, the summary `GameFontHighlightSmall`
  right-aligned, one line, ellipsis; header fill/edge warmer and gold-edged while open; the box joins
  under it (no top edge) with padding 26 / 10 / 8 / 8, so its rows line up under the name; 4px after
  each drawer. File-local constants (not `lib.LAYOUT`).
- **[L1] The library-stack-§7 one-consumer row** is in LibKa0s `CLAUDE.md` -> `## Documented
  deviations`, trigger "a second addon draws a drawer, or one release passes after v1.73.0 with no
  second consumer named, or a breaking API change".
- **[L1] For Q1.** The re-vendor takes v1.73.0 (and v1.72.0's Perf 15 and kit revision 39). Quick
  Comms' Options degradation stub (`settings/OptionsSetup.lua`, pinned by name in
  `tests/test_surface_parity.lua`) needs `H.Drawer = function() end` beside `H.NavRail`. The vendor
  gate resolves the provenance line's tag in `../LibKa0s`, and `v1.73.0` is not tagged.
- **[L1] Follow-ups, not done.** `docs/api/CONSUMERS.md` keeps its v1.71.0 stamp until Quick Comms
  calls `O.Drawer`; the standard's `library-stack-§7` counts (fifteen majors across thirty-four
  files, ten Options files) need an upstream recount for the thirty-fifth file. LibKa0s README's
  standard pointer moved v2.81.0 -> v2.83.0 (neither v2.82.0 nor v2.83.0 binds the payload).
- **[Q1] The re-vendor.** Both payloads copied whole from the LibKa0s worktree at `4d1c8d1`
  (v1.73.0, unreleased): `libs/LibKa0s/` gains `OptionsDrawer.lua` and moves `Options.lua`,
  `Perf.lua` and `LibKa0s.xml`; `tests/_kit/` moves to kit revision 39 (`latch.lua` added). Every
  blob matches `4d1c8d1` (`git hash-object` against the sibling's tree, 0 mismatches). The
  provenance line (CLAUDE.md), `docs/ARCHITECTURE.md`, `docs/module-map.md` and `docs/testing.md`
  (kit revision 39) say so. No `docs/revendor/` record: this repo has never kept one.
- **[Q1] The Options stub** (`settings/OptionsSetup.lua`) gains `H.Drawer = function() end` beside
  `H.NavRail`; `tests/test_surface_parity.lua` was red without it.
- **[Q1] Kit 39 and step 6.** Kit revision 39's `__fireUnconditional` now reaches a method-name
  handler after a stand-down, so `tests/test_disabled.lua`'s step-6 case went red on
  `OnRestrictionRegenDisabled` (it answered 1, the case asserted 0). The case now asserts the live
  fires reach nothing and the direct fire reaches the handler (1) while nothing is written, printed
  or shown, as DropWatcher's step-6 case does; it is renamed, so `docs/test-cases.md` moves by that
  one line (Total 837 unchanged).
- **[Q1] The vendor gate stays red until v1.73.0 is tagged.** `tests/test_vendor_sync.lua`
  resolves the provenance line's tag in `../LibKa0s`; v1.73.0 is not tagged and tagging is the
  owner's, so its two pair cases fail on the missing tag alone.
- **[Q2] The drawers.** `W.Render` draws the live line, the grey line ("Every condition you set
  must match. A condition left as Any does not limit the group."), then one `H.Drawer` per `W.ROWS`
  entry: `label` the Resolver's label, `tooltip` `W.TIP`, `summary` / `set` functions read fresh
  from the profile at draw, `open` from `NS.State.whenOpen[gid][row]`, `onToggle` storing it (nil
  when closed), `body` the row's choices. No refresh of its own on a toggle (the library's
  `RefreshPanel`); a write still repaints through `group.when` being structural (Ed.STRUCTURAL), so
  the summary follows the next frame. The enable checkbox and its `Ed.RequestRefresh` are gone.
- **[Q2] Closed by default.** A drawer is open only while the player opened it this session, a set
  condition included (its summary says what is set); the open set is per group, survives a repaint
  and is cleared on a profile switch (Editors' existing `whenOpen` loop).
- **[Q2] The summary** is `W.Summary(row, when)` (pure, tested): "Any" while unset; checkbox rows
  list the chosen labels in `W.Values` order joined by ", " (the drawer cuts it with an ellipsis);
  an id row names its one entry (`KIND.info`) or counts several ("2 instances", "2 battlegrounds",
  "2 characters"); the key level reads "10 or higher", "15 or lower", "10 to 15", or "12" when both
  ends are equal.
- **[Q2] Three columns** are one wide `RenderGrid` item per line of up to three `CheckBox`es at
  relative width 0.32 (RenderGrid pairs its cells two to a line; 0.32 keeps a line under 1 for the
  ScrollFrame's clip). The checkboxes and the key-level boxes call `SetDisabled(true)` under
  `ctx.__renderDisabled`, so Q3's read-only drawer (`spec.disabled`) needs nothing more from them.
- **[Q2] Select all / Clear (Any)** are the drawer's `actions`: Select all (checkbox rows only)
  writes `W.SelectAll` (pure, tested: every value `W.Values` lists, so the specialization row ticks
  the specs it offers and no other); Clear (Any) writes `W.ClearRow` on every row and leaves the
  drawer open. Both read the profile at the click. Neither is disabled while it would do nothing.
- **[Q2] Tests.** `tests/page_helpers.lua` gains `P.drawer(widgets, label)` (the header button,
  for `__fire("OnClick")` and its `__ka0sDrawer*` dress) and `P.drawers(widgets)`; the four page
  cases that switched a row on through its enable checkbox now open its drawer. Total 837 -> 844.
- **[Q2] Not committed.** The Q1 re-vendor sits uncommitted in the worktree and the gate's two
  vendor-pair cases stay red on the untagged v1.73.0 alone (Q1's note), so Q2 is left uncommitted
  on top of it rather than committed against a red gate or without the drawer it calls.
- **[Q3] Q1 and Q2 committed first.** v1.73.0 is now tagged in the LibKa0s worktree (not by this
  task), so the vendor-pair cases pass and the gate is green. Q1 and Q2 were committed as their own
  commits (`77a6ef2` re-vendor, `8341da0` drawers), each gated green on its own tree
  (`docs/test-cases.md` and the badge regenerated per commit: 837, then 844), before Q3 on top.
- **[Q3] One seam: `Resolver.WhenOf(groups, id)`.** It answers the When that judges a group and
  whose it is: the parent's while the group's `parent` names one of `groups` and its `inheritWhen`
  is not false (absent is on), else its own. `ActiveGroups` and `SurfaceOrder`'s narrowness read
  it, so the pad, the dial, the Group picker's dot, Preview as, the diagnostics and every "why" line
  follow without their own change. The parent's Enabled and its place on the surface still gate the
  family (modules/Surfaces.lua unchanged).
- **[Q3] Stored true on create, absent read as on.** `Library.TEMPLATES.group.inheritWhen = true`
  (the row's default); `CreateGroup` stores `fields.inheritWhen ~= false` (so `DuplicateGroup` and
  an import pass it on), and `seedGroup` stores `true`, so `/qc get group.inheritWhen` prints a
  value for every group made from now on. A profile from before the setting has no field, which
  the Resolver and the checkbox read as on; the CLI prints nil for such a group until it is written.
  Top-level groups carry `true` too; it is idle until the group takes a parent.
- **[Q3] The member row.** `group.inheritWhen` (bool, default `T.group.inheritWhen`, page groups,
  tab General) in settings/SchemaMembers.lua, validated as a boolean (`badChoice`), announced through
  Library.Touch like any field. It is not reset-exempt: a page's Defaults turns it back on.
  `Ed.STRUCTURAL` gains it, so a write repaints the When tab, the picker's dots and the grayed-out box.
- **[Q3] The checkbox** is drawn by hand beside Parent group (`inheritItem`, one RenderGrid line
  with `parentItem`), as Parent group is, because the seam reads an absent field as nil and the box
  must read it as on (`G.InheritState`: checked unless false; disabled while `Library.IsChild` is
  false). The row is in `UNDRAWN` so RenderRows does not draw it twice. Tooltip: the row's desc.
- **[Q3] The read-only When tab.** `W.Source(gid)` (WhenOf through Library.AllGroups) names the
  group whose When the tab shows. For an inheriting group: the live line, then the line "Uses
  <parent>'s conditions. Untick Inherit when conditions on the General tab to set this group's
  own." in the muted gold `c9a66b` (the approved mockup's color, Groups.lua's MUTED_GOLD), then the
  gray line, then the drawers with `summary` / `set` / `body` read from the parent's When,
  `disabled = true` and no `actions`. The open set stays the viewed group's. `W.ActiveText` judges
  by the same When (`W.ActiveLine` itself is unchanged and pure).
- **[Q3] Share.** An export writes `inheritWhen = m.inheritWhen ~= false` on every group; the check
  keeps `g.inheritWhen ~= false` (an older string without it arrives on); Library.Import hands it to
  CreateGroup.
- **[Q3] Tests (Total 844 -> 855).** Resolver (three: the child judged by the parent's When, WhenOf,
  narrowness), Library (seeded nodes, create, untick, Duplicate, the template), members (the row,
  its refusal, the CLI), Share (round trip; an old string), Surfaces (a child with its own arena When
  shows in a key under an M+ parent), When (`ActiveText`), page (no green dot on a seeded
  battleground's nodes in the open world; the checkbox beside Parent group, grayed out with no
  parent, absent read as on, untick stores false; the read-only When tab and back). The three
  existing Surfaces nesting cases whose children carry their own When now create them with
  `inheritWhen = false`. Mutation-checked: each change reverted turns its case red.
- **[Q4] The match is `Src.Search(list, tab, query)`** (settings/IconBrowser_Sources.lua, pure,
  tested): trimmed, lowercased, plain substring (`find(q, 1, true)`, so `%` or `[` is text), a blank
  or nil query answers the list itself. A marker reads its name; a glyph its catalog key and its
  shown label (the label map now keeps path -> key beside path -> label); a game icon its texture
  id's digits, and a texture path in the game list its file name only (not the folder).
- **[Q4] The box** is an AceGUI `EditBox` with no label and its Okay button off (`DisableButton`),
  kept for the browser's life like the filter and the swatch; `OnTextChanged` calls the new
  `B.SetSearch(text)`. The LibKa0s `search` glyph (muted gold `c9a66b`) sits inside its left edge
  and a `close` glyph button (gray) inside its right, shown while there is text, which empties it;
  the input's text insets clear both (on AceGUI's `editbox` when present). It sits after the filter
  (Game icons) or the swatch (Glyphs), both now 180 wide, at x=190, 190 wide; at the left edge on
  Markers. Tooltip: "Markers by name, glyphs by name, game icons by texture id. Not case-sensitive."
- **[Q4] Session text.** `search` is module-local and not reset by `B.Open`: a tab switch and a
  later open in the session keep it and filter again (the box shows it). A search change shows the
  results from the top; it does not scroll to the selection (a tab switch or an open still does,
  when the searched list holds it). A stored icon the search hides stays selected in the footer.
- **[Q4] The count** reads "N of M icons" while a non-blank search narrows the tab and "N icons"
  otherwise (the unsearched wording kept). With no match the grid says "No icon matches your
  search."; a list the client has not loaded keeps its own line first. `B.State()` gains `search`
  and `total`; `B.Widgets()` gains `search`, `clear`, `hint`, `hintText`, `link`.
- **[Q4] The hint row** is a box under the grid (`HINT_GAP` 8, `HINT_H` 36, the grid's and the
  scrollbar's width, the drawer box's fill and edge colors), shown on Game icons only, with the
  spec's words and a "Copy wowhead.com/icons" button. HEIGHT 550 -> 594 to fit it above the footer;
  on Markers and Glyphs the band is empty.
- **[Q4] The copy window.** "The addon's existing copy box" is read as its maker,
  `NS.MakeCopyWindow` (the LibKa0s CopyWindow the Share page's export window is), as its own handle
  `B.LinkWindow()` (`QuickCommsIconLinkWindow`, title "Quick Comms: Wowhead icons", 420 x 120,
  anchored on the browser), not the Share window itself (its title names a share string). The
  library builds it in FULLSCREEN, the browser's own strata, where the browser's catcher would lie
  over it, so the browser sets its frame to FULLSCREEN_DIALOG once at build (the filter's pull-out
  and the color picker live there too). It hides when the browser closes. It is in UISpecialFrames:
  an Escape while its box has focus closes it alone; with no focus Escape closes it and the browser.
- **[Q4] Tests (Total 855 -> 859)** in tests/test_icon_browser.lua: Src.Search (marker, glyph key
  and label, game id digits, a path's name, plain text), the box (filters as typed, N of M, from the
  top, the clear mark, no match), the session text (across tabs and opens), the hint and the copy
  window (Game icons only, under the grid, the address, FULLSCREEN_DIALOG, closed with the browser).
  Mutation-checked: label-only or key-only glyph match, the old count, a reset in Open, the strata
  and the hide each turn a case red.
- **[Q5] The docs.** `docs/settings-panel.md` (the General diagram and an Inherit when conditions
  paragraph; the When tab rewritten as drawers, with a diagram; the icon browser at 594 high, its
  search box, count, hint row and copy window), `docs/schema.md` (`inheritWhen` on the groups row,
  the `group.inheritWhen` member row, `whenOpen` as open drawers, the browser's session search text,
  "no schema step for Inherit when conditions"), `docs/ARCHITECTURE.md` (this spec and plan in the
  amended-by list; the Options, Widgets, Resolver, Groups, GroupsWhen and IconBrowser rows; the
  member-rows paragraph; the session-state lines; the "cannot search" limitation rewritten as search
  by texture id only, and a new one: inheriting is all or nothing, an old group reads as on and the
  CLI prints nil), `docs/smoke-tests.md` (EDIT-1, 2 and 19 rewritten for the drawers and the default
  inherit; EDIT-22 the drawers, EDIT-23 Inherit when conditions, EDIT-24 the search; IDS-1's two
  When steps; the index and the sign-off row), README (the browser's search, a child's conditions,
  the drawers). The LibKa0s version mentions were Q1's (v1.73.0).
- **[Q5] Beyond the listed files.** `docs/data-flow.md` (the family's gate names inheriting; the
  structural writes list Parent group and Inherit when conditions) and `docs/module-map.md` (the
  Resolver, Groups_When, Groups, SchemaMembers, IconBrowser and test rows) drifted with Q2-Q4 and
  are brought in line.
- **[Q5] No Quick Comms deviation.** Nothing in Q1-Q4 departs from the standard beyond what this
  spec records; the one-consumer drawer (`library-stack-§7`) is ratified in LibKa0s `CLAUDE.md`, not
  here, so `## Documented deviations` is unchanged.
- **[Q5] `docs/test-cases.md` and the badge** already matched (`--list` equal after CRLF; Total 859,
  badge 859/859): Q5 adds no test.
- **[Q5] Not done (code, not docs).** The `group.when` row's tooltip still says "Every condition you
  turn on must match" (`locales/enUS.lua`), wording from the enable checkbox the drawers removed. The
  LibKa0s `docs/api/CONSUMERS.md` census keeps its v1.71.0 stamp (L1's follow-up): Quick Comms now
  calls `O.Drawer`, but the census is a collection-wide re-run.
