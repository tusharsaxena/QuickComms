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
