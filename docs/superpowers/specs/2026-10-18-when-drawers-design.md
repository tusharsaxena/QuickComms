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

