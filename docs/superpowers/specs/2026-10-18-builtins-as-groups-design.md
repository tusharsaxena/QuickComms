# Built-in sets as ordinary groups, nested groups, and a Preview table: design

Date: 2026-10-18. Status: approved by the owner 2026-10-18 (two questions answered; builder calls
marked). Supersedes the "built-ins stay read-only" non-goal of
`2026-10-17-callouts-owned-by-groups-design.md` and the v0.1.0 spec's built-in overlay model
(§12.2: enabled/hidden overlay, Customize).

## Why

A built-in set's Callouts tab is a grid of show/hide checkboxes and its When tab is read-only text,
while a user group has the callout table (Add callout, Reuse callout, edit, remove, drag) and an
editable When. The owner wants one model: every group looks and works like a user group.

## Goals

1. **Built-ins are seeded as ordinary groups (owner ruling).** The shipped sets in `defaults/`
   become seed data. Each profile is seeded with them as ordinary user groups and user callouts
   (fresh ids, the built-in's name, icon, channel, text and When), placed wherever the built-in sets
   are placed by default on pads and dials. From then on they are fully editable like any group:
   callouts table, Add/Reuse, editable When, rename, icon, delete, duplicate. The "(built-in)" tag,
   the overlay (`profile.builtins`: enabled, hidden), the show/hide checkboxes and Customize go away.
   - Seeding happens once per profile (a new profile, a reset profile, and, for the owner's existing
     profiles, on the next load: Prepare or a migration step converts every built-in reference and
     any customized copy; v0.1.0 is unreleased, so only the owner's profiles are touched).
   - **Restore built-in groups** (Groups page): re-adds any seeded set the player deleted, as fresh
     ordinary groups; it never overwrites a group the player still has. Builder call: whether it also
     offers "reset to stock" per set; if offered, it asks first.
   - Each seeded group may remember which set it came from (an origin key) so Restore knows what is
     missing; the origin is not shown as a tag and does not make the group read-only.
   - Reuse callout's list: the built-in section goes (every callout is now a user callout, listed as
     `<group>: <callout>`). Restore is how a deleted stock callout comes back.
   - Share: the Built-in export tab goes or becomes moot; seeded groups export like any group.
2. **Nested groups in every group (owner ruling).** A group has an optional **Parent group**
   setting on its General tab: default none for new groups. Seeded battleground sets are modelled
   correctly: each node ("Arathi Basin" → "Stables", "Mine", …) is its own group with the set as its
   parent. Builder calls:
   - One level only: a group that has a parent cannot be a parent, and a group with children cannot
     take a parent (the dial draws one level of node rings, spec §11.3). The dropdown offers only
     top-level groups other than itself, and is disabled with a tooltip when the group has children.
   - A child shows wherever its parent is placed: the pad draws one section per child (today's
     built-in-with-children behaviour), the dial a node ring per child. A child is not placed on a
     surface by itself (the surfaces' Add a group lists top-level groups).
   - A child's When gates its own section/node; the parent's When gates the whole.
   - Deleting a parent asks first and says what happens to its children (builder: they become
     top-level groups, or are deleted with it; pick one, say it in the confirm).
   - The Group dropdown on the Groups page lists children indented under their parent.
   - Validation lives in Library (sole registry writer): parent must exist, be top-level, not self,
     no cycles; Prepare repairs a bad parent (drops it); Share carries `parent` and remaps ids on
     import.
3. **Preview tab as a table (owner).** For every group, the Preview tab shows the active-now line,
   then a table with one row per callout: the callout's name in its own column, the preview text
   (what it sends here, or why not) in the other, visually separated like the Callouts tab's table
   rows (same row boxes, same left/right edges).
4. The Callouts and When tabs of a seeded group are identical to any user group's (owner's
   screenshots: 24 vs 25, 26 vs 29).

## Non-goals

- No change to the bake/send path, tokens, channels, the callout popup or the icon browser.
- No nesting deeper than one level.

## Standard check

Raise anything that breaks a Ka0s rule before committing (CLAUDE.md). The Library stays the only
registry writer; settings writes go through the seam; a schema change that needs a migration uses
the standard's migration mechanism (`NS.MIGRATIONS`).

## Left to the builder

Ids for seeded groups and callouts, the origin key's shape, where Restore lives (a button on the
Groups page, or under its Defaults), migration vs Prepare, the Preview table's widget composition.

## Builder calls

Recorded as each task makes them (plan ledger task in brackets).

- [T1] **Delete a parent: its children become top-level groups** (not deleted with it), each put
  in the parent's place on every pad and dial the parent was on, in the children's order; the
  confirm says so ("The groups inside it become top-level groups, in its place on every pad and
  dial").
- [T1] **Child order** on a pad, a dial and the Group dropdown is the order the children were made
  in (their id numbers), so a seeded set keeps its shipped node order; there is no reorder control
  for children yet.
- [T1] **A parent may hold callouts of its own.** On a pad they are a section titled with the parent's
  name, before the children's sections; on a dial they come first in the parent's ring, before the
  child rings (such a ring is not pinned to compass winds). A parent with neither own callouts nor a
  child whose When matches draws nothing.
- [T1] **Taking a parent takes the group off every pad and dial** (Library.SettleParent, in the same
  act as the write); clearing the parent does not put it back, the player adds it under Comms Pad >
  Groups. Prepare also takes any child off every surface, and Add a group (pads, dials) lists only
  top-level groups.
- [T1] **Children gate on their own When and Enabled**: a child's section or ring shows only while
  the Resolver finds it active; the parent's When and Enabled gate the whole family. A built-in node
  has no When of its own and always shows with its set.
- [T1] **group.parent is a member row** (`/qc` takes a group id, or `none` / empty for none; default
  none; a page's Defaults keeps it, as it keeps the icon). The General tab draws it as its own
  dropdown (None, then the top-level user groups but itself, in picker order), idle while the group
  holds groups, with a tooltip naming them. Built-in sets are neither parents nor children in T1
  (T2 seeds them as user groups).
- [T1] **Duplicate**: a child's copy sits in the same parent (the chat line says so); a parent's copy
  holds no children (they are not copied).
- [T1] **Share**: picking a parent (directly or through a pad or dial) brings its children; a child
  picked alone travels without its parent and arrives top-level. On import a parent is kept only
  when the string carries it and it has no parent of its own (judged on the string as written, so a
  chain or cycle keeps nothing); any other is counted with the dropped references.
- [T1] **Prepare's parent repair** is judged on the parents as stored, not in walk order: a parent
  that is no user group, the group itself, or a group with a parent of its own is dropped. No
  migration step: a group without `parent` is top-level, so old profiles need nothing.
- [T1] **Group dropdown indent**: a child's entry starts with four spaces (Groups.CHILD_INDENT),
  listed right after its parent (Library.MemberIds), which also orders the Share page's group list.
- [T2] **Seeded ids are ordinary user ids** (`c<n>`, `g<n>`, from the profile's `nextId`). A fresh
  profile makes its default pad and dial first (so they keep `p1` and `d2`), then seeds the sets in
  shipped order: each group's callouts take their ids before it, a set's nodes after it, so the
  nodes keep their shipped order (Library.Children sorts by id).
- [T2] **Origin key: `origin`, the shipped id** (`"bi.mplus"`, `"bi.mplus.lust"`), on every seeded
  group and callout; a seeded node also keeps its `compass` wind, so the dial still pins node
  wedges to their winds. Neither is a member row, a tag or a lock: Library writes them when it
  seeds and only Library reads `origin` (RestoreBuiltins, and Library.SeededBattleground for the
  dial's depth warning; review round 1 replaced the test-only Library.ByOrigin with it). A Duplicate, a Reuse copy and an
  import keep neither, and Share does not carry them (an exported set's nodes arrive unpinned).
- [T2] **`profile.seededSets`** (`{ [shipped id] = true }`, sets and nodes) replaces the overlay
  (`profile.builtins`) and every surface's `seenBuiltins`. Prepare seeds a shipped set the profile
  was never given at the end of every pad and dial (a set a later version ships), and a node
  shipped after its set inside the set's group while that is top-level; a seeded group the player
  deleted is never seeded again by Prepare (that is Restore's).
- [T2] **Both a migration and Prepare.** Schema step 3 (`NS.MIGRATIONS`, per profile,
  Library.SeedFromOverlay) converts a stored profile that has its surfaces: every set is seeded and
  takes the set's place on every pad and dial that listed it; a set that was off is a group that is
  off; its hidden callouts are left out (Restore brings them back); a customized set is not seeded,
  its copy (a user group already) keeps its place and the set counts as given; a node or stale
  `bi.` reference on a surface is dropped; the overlay and `seenBuiltins` go. A profile never
  prepared is left to Prepare (which seeds it as a new one), and one that already has `seededSets`
  is left alone, so the step runs once and is idempotent.
- [T2] **Restore built-in groups lives on the Groups page's General tab**, as its last row (and on
  the empty "No groups yet" General), not under Defaults, which stays the selected group's reset
  (options-ui-§13). It does not ask first: it changes nothing the player has. It puts back every
  shipped set, node and callout whose origin the profile no longer has: a set as a top-level group
  at the end of every pad and dial, a node inside its set's group while that is top-level (else it
  stays out), a callout at the end of its seeded group. A set deleted while its nodes were kept
  (they became top-level groups) comes back without them. One chat line says how many groups and
  callouts came back, or that nothing was missing. **No "reset to stock"** per set: deleting the
  group and restoring does it.
- [T2] **A new pad or dial** holds the seeded sets the profile still has as top-level groups, in
  shipped order (what a new surface held as built-ins before).
- [T2] **Share's Built-in tab is removed**; the page's Defaults now unticks everything and forgets
  the checked string (session state only). A `bi.` reference in a string (one made before the sets
  were seeded) is a dropped reference. An imported group the string nests is no longer counted as
  "on no pad or dial" (it shows with its parent).
- [T2] **Removed with the overlay**: the `builtin` member kind and its rows (`builtin.enabled`,
  `builtin.hidden`), the `idset` row type and its CLI parse and format, Customize, the "(built-in)"
  tag (picker, Add a group, the why lines), Reuse's built-in section, the built-ins' read-only
  General, Callouts and When branches on the Groups page, and Groups_When's W.Describe (only the
  built-in When tab used it). Settings.Editors.Open stays (a tested, combat-gated page jump), with
  no caller now.
- [T2] **The dial's three-rings-deep warning** knows a seeded battleground set by its origin
  (`bi.bg.<key>`, read through Library.SeededBattleground) while it holds groups.
- [T3] **Groups page parity needed no new code in T3**: T2 already removed every built-in branch
  (General, Callouts, When), so a seeded group draws the same tab set as any group; the existing
  page tests (a seeded set's General, Callouts table with Add/Reuse/drag/remove, editable When)
  stand as the parity check.
- [T3] **The Preview table is Ed.TableRows** (settings/Editors.lua), shared widget composition
  beside Ed.ReorderRows: a gold header row ("Callout", "What it sends here"), then one row per
  callout with its icon (in its color) and name in a 220px cell and its first preview line in the
  cell filling the rest. The rows sit in the library's row box (a ReorderList whose rows have no
  handle, `draggable = false`), so fill, border and left and right edges are the Callouts table's;
  the header row has no box. The preview text is the first line only, as before (bytes, lock and
  token notes stay in the callout popup's preview).
- [T3] **A row has its own AceGUI layout** (`QuickCommsTableRow`, Ed.LayoutTableRow, registered
  with AceGUI at load), not AceGUI's Table: a wrapped text needs its width set before its height is
  read, which the Table layout does not do for a fill cell. The row is never shorter than the
  Callouts table's (ROW_H, 30px) and grows with a wrapped text (6px above and below); both cells are
  centered in it. A live refresh that changes a text lays the page out again, so the row resizes.
- [T3] **A group holding groups** shows a titled table per section (its own callouts when it has
  any, then each child), each with its header; a group with no callouts keeps the one line ("This
  group has no callouts yet.") and draws no table.
- [T4] **Docs only, no behavior change.** ARCHITECTURE (overview, module map, schema, the
  registry paragraph, the bus row, known limitations), schema.md (the `seededSets`, `origin`,
  `compass` and `parent` keys, migration step 3), module-map.md, settings-panel.md, data-flow.md (new
  "the built-in sets are seeded" and "a group inside another" sections), scope.md, slash-dispatch.md
  (`group.parent`'s text form; the `builtin.*` rows gone) and the README describe what T1-T3 built.
  No deviation from the Ka0s standard was found: Restore built-in groups on General (not Defaults)
  follows options-ui-§13.
- [T4] **Smoke checks are rewritten in place, not retired**: EDIT-2 (now "a built-in set is an
  ordinary group", the owner's screenshots 24 vs 25 and 26 vs 29) and EDIT-6 (now Restore built-in
  groups) keep their numbers; EDIT-4, 5, 11, 14 and ICON-1 lose the "(built-in)" tag and the built-in
  Reuse section; EDIT-19 (nested groups), EDIT-20 (the Preview table) and EDIT-21 (an older profile
  converts once) are added.
- [T4] **Known limitations added**: one level of nesting and no reorder control for children; a
  battleground ring is pinned only while every group inside it is a seeded node and the set holds no
  callouts of its own (the wind is not a member field, so an imported set's nodes arrive unpinned);
  Restore puts back only what is missing and never resets an edited group, and a copy (Duplicate,
  Reuse, import, a customized set converted by step 3) keeps no origin, so Restore adds the stock set
  beside such a copy.
- [T4] **Older specs carry italic "Superseded" notes in place** (the 2026-10-17 pattern): the v1
  spec's §5.1, §12.1 (user nesting), §12.2, §13.1 and §15, and the 2026-10-17 spec's built-in
  non-goal. Their text is otherwise unchanged.
- [T4] `defaults/Profile.lua`'s comment on `callouts` (a fresh profile has none) was stale and is
  corrected, comment only. The README's unreleased 0.1.0 Version History row names the editable
  built-in groups and nested groups; no version bump.
