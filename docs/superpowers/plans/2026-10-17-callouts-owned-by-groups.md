# Callouts owned by groups: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the Callouts settings page. Each user callout belongs to one user group, and callouts are created, reused (copied), edited and removed from Groups > Callouts through a Save/Cancel popup drawn with the settings panel's own building blocks.

**Architecture:** `modules/Library.lua` (the only registry writer) enforces one-owner ownership: on every write, in Prepare on every load, and in Import. A new `settings/CalloutPopup.lua` edits a draft and saves it as one `Library.Batch`. `settings/Groups.lua`'s Callouts tab hosts the entry points. `Ed.ReorderRows` gains glyph buttons that every list uses.

**Tech Stack:** Lua 5.1 (WoW Retail 12.1.5), Ace3/AceGUI, LibKa0s v1.71.0 (vendored), headless harness `lua tests/run.lua`, `luacheck .`.

**Spec:** `docs/superpowers/specs/2026-10-17-callouts-owned-by-groups-design.md`. Read it first; it holds every owner ruling and builder call.

## Global Constraints

- Ka0s WoW Addon Standard: if a change would deviate, STOP and raise it (CLAUDE.md). Do not record a deviation yourself.
- Green gate before every commit: `lua tests/run.lua` passes, and `luacheck .` reports 0 warnings / 0 errors.
- Never edit `libs/` or `tests/_kit/`. Never bump the version. Never merge to `main`.
- Every new string goes through `L[...]` with its enUS key in `locales/enUS.lua`.
- Every member field write goes through the seam (`NS.SchemaRuntime.Set`), and membership goes through `Library` (anti-pattern #78).
- Each test that pins a fix carries a `-- red under: <what to undo>` comment, as the existing suites do.
- Each task updates `docs/test-cases.md` for the cases it adds, removes or renames: the per-file heading counts, the bottom table and the total. Task 7 owns the README badge.
- Work in the worktree's branch `feat/callouts-owned-by-groups`. Commit per task, with the session's attribution trailer.

## Review Focus

1. **Cancel on a new callout leaves nothing behind.** No `profile.callouts` entry, no group entry, and no `nextId` consumed. Task 4 test.
2. **Prepare on a profile where `c1` sits in `g1` and `g2` and `c9` sits in no group.** Afterwards `g2` holds a fresh copy with equal fields, `c9` is gone, and running Prepare a second time changes nothing. Task 1 tests.
3. **Remove from a pad's group list does not delete the group, and asks nothing.** Removing a callout from a group asks first, then deletes the callout. Task 3 and Task 5 tests.
4. **The popup's callout is deleted under it** (`/qc` or an import) while the popup is open. The popup closes, and a late Save writes nothing. Task 4 test.
5. **Save with an invalid name** (empty, or more than 32 characters). The popup stays open and names the field, and nothing is written. Task 4 test.

---

### Task 1: Library ownership rules, Prepare and Import

**Files:**
- Modify: `modules/Library.lua` (`AddToGroup`/`addToGroup` ~477-502, `RemoveFromGroup` ~504, `DeleteGroup` ~443, `DuplicateGroup` ~470, `repairGroups` ~879, `importMembers` ~984; delete `UsedBy` ~117 and `DuplicateCallout` ~401 if nothing else calls them after Tasks 4 and 5, so revisit them in Task 5)
- Modify: `modules/Share.lua` only if the import plan must count loose callouts as left out (`ignored`/dangling tally)
- Test: `tests/test_library.lua`, `tests/test_share.lua`, `tests/test_profile.lua`

**Interfaces:**
- Produces:
  - `Library.AddToGroup(gid, cid, index) -> newId|nil, reason`, which always adds a **copy**. A user callout's copy keeps its name unchanged (no "(copy)" suffix). It is one act (`Batch`).
  - `Library.RemoveFromGroup(gid, index) -> boolean`, which deletes the removed callout.
  - `Library.DeleteGroup(id)`, which deletes the group's callouts with it.
  - `Library.DuplicateGroup(id) -> newGid`, whose callouts are fresh copies.
  - `Library.CreateCalloutIn(gid, fields, index) -> cid|nil, reason`, which creates and inserts as one act (`Batch`). The popup's Save uses it.
  - `Library.OwnerOf(cid) -> gid|nil`.

- [ ] Write the failing tests in `tests/test_library.lua`:
  - `library: adding a user callout to a group adds a copy`. The new id differs from the source, the fields are equal, and the source is untouched.
  - `library: removing a callout from its group deletes it`
  - `library: deleting a group deletes its callouts`
  - `library: duplicating a group copies its callouts`. No id is shared between the two groups.
  - `library: CreateCalloutIn makes and places a callout in one act`. There is exactly one LIBRARY_CHANGED.
  - `library: OwnerOf names the one group`.
- [ ] Write the failing tests in `tests/test_profile.lua` (Prepare):
  - `prepare: a callout held by two groups is split into a copy`
  - `prepare: a callout held by no group is dropped`. The `repaired` tally counts it.
  - `prepare: is idempotent after a split`.
- [ ] Write the failing tests in `tests/test_share.lua`:
  - `share import: groups sharing a callout each get their own copy`
  - `share import: a callout in no imported group is not imported`.
- [ ] Run `lua tests/run.lua`. Expect the new cases to FAIL.
- [ ] Implement the changes. Prepare runs the split before the dangling-id repair and drops orphans after it. Existing tests that create a free-standing callout and then call `AddToGroup` must now read the returned id. Fix those call sites in the tests and in `Library.Customize` (`modules/Library.lua:560` already copies).
- [ ] Run `lua tests/run.lua` and `luacheck .`. Expect all green.
- [ ] Commit: `Library: one group owns each callout (copy on add, delete on remove, split and drop in Prepare and Import)`.

### Task 2: The seam and slash, with no Callouts page

**Files:**
- Modify: `settings/Schema.lua:130-160` (`NO_MEMBER.callout`, `Settings.EditingId`)
- Modify: `settings/SchemaMembers.lua` (the `callout.*` rows keep `page = "callouts"`; check every desc that names the Callouts page)
- Modify: `settings/Slash.lua` (descriptions that name the Callouts page)
- Test: `tests/test_schema.lua`, `tests/test_slash.lua`, `tests/test_members.lua`

**Interfaces:**
- Produces: `Settings.EditingId("callout")` always returns `nil`. A `callout.*` write with no id is refused with `L["Name the callout id: /qc set callout.<field> <id> <value>."]` (adjust the wording to the slash grammar in `settings/Slash.lua`). `NS.State.editing.callout` is no longer read.

- [ ] Write the failing test `schema: a callout write that names no id is refused, even with callouts present`.
- [ ] Run it and confirm it FAILS.
- [ ] Implement the refusal and drop the callout selection fallback.
- [ ] Run the full gate and confirm it is green.
- [ ] Commit: `Seam: a callout write must name its id now the Callouts page is going`.

### Task 3: Glyph buttons in `Ed.ReorderRows`

**Files:**
- Modify: `settings/Editors.lua:337-376` (`Ed.ReorderRows`)
- Modify: `settings/Pads.lua:~173` and `settings/Dials.lua:~290` (the entries they pass)
- Test: `tests/test_editors.lua`, `tests/test_page_pads.lua`, `tests/test_page_dials.lua`, `tests/wow_mock.lua` only if the AceGUI mock lacks the widget you use (the mock is the addon's own file, not `tests/_kit/`)

**Interfaces:**
- Produces: the entry shape `{ id, label, icon = texture|nil, edit = fn|nil, editTooltip = string|nil, remove = fn|nil, removeTooltip = string|nil }`.
  - The edit glyph is `NS.Icon("edit")`.
  - The remove glyph is the atlas `transmog-icon-remove` (the same mark Consumable Master uses, `../ConsumableMaster/settings/Category.lua:603`).
  - Each glyph is a 22px clickable icon with a tooltip, right-aligned in the row, and no red button remains.
  - `icon`, when set, draws a small texture between the handle gutter and the label.
  - Tests find the glyphs by tooltip or by a stable widget field. Add `P.glyph(widget, "remove"|"edit", rowIndex)` to `tests/page_helpers.lua` if it helps.

- [ ] Write the failing tests:
  - `editors: a row's remove is a glyph, not a button`
  - `editors: a row with edit shows the edit glyph and fires it`
  - `pads page: the remove glyph takes a group off the pad without asking and keeps the group`
  - The same for dials.
- [ ] Run them and confirm they FAIL.
- [ ] Implement. AceGUI's `Icon` widget sets a texture path. For the atlas, call `widget.image:SetAtlas(...)` after `SetImage`, or build a minimal glyph through `h.AceGUI`. Keep the row height `Ed.ROW_H` and the ReorderList registration unchanged.
- [ ] Run the full gate and confirm it is green.
- [ ] Commit: `Editors: reorder rows carry edit/remove glyphs; pads and dials use the remove glyph`.

### Task 4: The callout popup

**Files:**
- Create: `settings/CalloutPopup.lua` (TOC: after `settings/Callouts.lua`, with a `# LOAD-BEARING:` comment as its neighbours have)
- Modify: `settings/Callouts.lua`. Delete the page (`Ed.RegisterPage`, `render`, the tabs, `Create`, `Duplicate`, `Delete`, `OpenGroup`, `Entries`). Keep `C.TOKENS`, `C.TokensFor` and `C.PreviewLines`, and rewrite its header comment to say it now holds the callout helpers the popup and the Groups Preview tab use.
- Modify: `QuickComms.toc`, `settings/Panel.lua` (the page list or the order, if the Callouts page is named there), `locales/enUS.lua`
- Test: replace `tests/test_page_callouts.lua` with `tests/test_callout_popup.lua`, keeping any `C.TokensFor` and `C.PreviewLines` cases; register the new suite in `tests/run.lua`'s ordered list.

**Interfaces:**
- Consumes: `Library.CreateCalloutIn` (Task 1). The seam rows `callout.name|text|channel|icon` by id.
- Produces:
  - `Settings.CalloutPopup.Open(gid, cid|nil)`. A nil `cid` means Add. It replaces any open popup.
  - `Settings.CalloutPopup.Save() -> ok, reason`
  - `Settings.CalloutPopup.Cancel()`
  - `Settings.CalloutPopup.IsOpen() -> boolean`
  - `Settings.CalloutPopup.Draft() -> table` (for tests)
  - `Settings.CalloutPopup.frame` (for tests)

Behavior (spec "The callout popup"):
- **The draft.** `{ name, text, channel, icon }`. For Add it is `{ name = "", text = "", channel = "smartGroup", icon = nil }`. For edit it is a copy of the callout, and the copy is also kept as the baseline.
- **The rows.** Render the four fields as rows with `get`/`set` against the draft. Rows with no path that carry `get`/`set` route to custom functions (`libs/LibKa0s/OptionsWidgets.lua:422-442`). Reuse the member rows' labels, descs and `values` from `Ed.Row("callout.<field>")`.
- **The rest of the body.** Then *Insert a token* (the draft's channel), *Choose an icon* (`Ed.IconPicker` variant writing the draft), the section *What it sends here* (`C.PreviewLines(draft)`, refreshed on each draft write), and then `InlineButtonPair` Save / Cancel.
- **Look.** The settings panel's building blocks (`Settings.Helpers`), the settings window's backdrop and title style, and a close control through `NS.MakeCloseButton`. It must not be the debug console's or copy window's chrome. To find how to render Helpers into a container that is not a panel page, look at `settings/Panel.lua`'s `Helpers.BuildMainContent(ctx)` and LibKa0s `OptionsScroll.lua`, then build a `ctx` for the popup's own AceGUI scroll.
- **Modal.** A full-screen click-catcher sits under the popup and over the settings window (strata above `SettingsPanel`). Escape is Cancel (`UISpecialFrames` or an `OnKeyDown`). It closes as Cancel when `SettingsPanel` hides, on the addon's profile-changed message, and on `LIBRARY_CHANGED` when the edited callout no longer exists.
- **Save.**
  - Validate the draft: `Library.ValidName`, `Library.ValidIcon`, a channel in the row's values, and text within the row's limit. A failure prints the field's reason in the popup (a red `TextRow` under the buttons), and the popup stays open.
  - On edit, inside one `Library.Batch`, `SchemaRuntime.Set("callout.<f>", v, cid)` for each field that differs from the baseline.
  - On Add, `Library.CreateCalloutIn(gid, draft)` (end of the group).
  - Then close. A Save after the callout vanished returns `false, "noCallout"` and writes nothing.

- [ ] Write the failing tests in `tests/test_callout_popup.lua`:
  - `popup: Add opens blank with Smart group`
  - `popup: edit opens filled in`
  - `popup: typing changes the draft only, and the preview follows`
  - `popup: Save on Add creates the callout at the end of the group, one LIBRARY_CHANGED`
  - `popup: Cancel on Add creates nothing and consumes no id` (Review Focus 1)
  - `popup: Save on edit writes only the changed fields through the seam`
  - `popup: Cancel on edit writes nothing`
  - `popup: Save with an empty name stays open and writes nothing` (Review Focus 5)
  - `popup: the callout deleted under an open popup closes it; a late Save writes nothing` (Review Focus 4)
  - `popup: closing the settings window cancels`
  - `popup: Insert a token appends to the draft's text`
  - `popup: Choose an icon writes the draft's icon`
  - `popup: its close control is the shared close mark` (assert it was made through `NS.MakeCloseButton`)
  - `settings: there is no Callouts page`
- [ ] Run them and confirm they FAIL.
- [ ] Implement.
- [ ] Run the full gate and confirm it is green. The `options-ui` and `surface-parity` kit suites may pin the page list. Update the addon-side facts (`tests/run.lua`'s consumer facts), never `tests/_kit/`.
- [ ] Commit: `Callout popup: Save/Cancel draft editor in the settings panel's style; the Callouts page goes`.

### Task 5: The Groups > Callouts tab

**Files:**
- Modify: `settings/Groups.lua` (`renderCallouts` ~218, `AddableCallouts` ~134, `G.AddCallout`, the General tab's Delete and Duplicate tooltips, `G.Delete`'s confirm text)
- Modify: `settings/Editors.lua`, only if `Ed.ConfirmDelete` needs a variant text ("Delete '%s' and its callouts?")
- Modify: `modules/Library.lua`: delete `UsedBy` and `DuplicateCallout` if they are now unused (grep first)
- Test: `tests/test_page_groups.lua`

**Interfaces:**
- Consumes: `CalloutPopup.Open` (Task 4), the `Ed.ReorderRows` entry shape (Task 3), and `Library.AddToGroup` copying and `RemoveFromGroup` deleting (Task 1).
- Produces: `G.ReusableCallouts(gid) -> { {id, label} }`.
  - It lists every user callout labelled `L["%s: %s"]:format(ownerGroupName, calloutName)`, sorted by that label case-insensitively, then the built-in callouts exactly as `AddableCallouts` labels them today.
  - It includes the current group's own callouts.
  - It replaces `AddableCallouts`.

Layout, top to bottom on a user group:
1. `Add callout`, a full-width button that calls `CalloutPopup.Open(gid)`.
2. A pair row: `Reuse existing callout`, a plain dropdown (selection only, no act on pick), and `Add`, a button that copies the selection to the end of the group and clears the dropdown. With nothing selected it is disabled.
3. The list:
   - Each entry: icon = the callout's icon, label = `calloutLabel(cid)`.
   - `edit` opens `CalloutPopup.Open(gid, cid)`.
   - `remove` runs `Ed.ConfirmDelete(name, function() Library.RemoveFromGroup(gid, i) end)`.
   - Empty text: `L["No callouts in this group yet. Add one above."]`.

The built-in group's tab is unchanged.

- [ ] Write the failing tests:
  - `groups page: Add callout opens the popup for this group`
  - `groups page: Reuse lists callouts as <group>: <callout> and built-ins as <set>: <callout>`
  - `groups page: Reuse + Add puts an independent copy at the end` (edit the copy's text, and the source is unchanged)
  - `groups page: picking in Reuse alone adds nothing`
  - `groups page: the edit glyph opens the popup filled in`
  - `groups page: the remove glyph asks, then deletes the callout` (Review Focus 3)
  - `groups page: deleting a group deletes its callouts`
  - Rewrite the existing `[exit]` test (`tests/test_page_groups.lua:22`) to add the callout through the popup.
- [ ] Run them and confirm they FAIL.
- [ ] Implement.
- [ ] Run the full gate and confirm it is green.
- [ ] Commit: `Groups > Callouts: Add callout, Reuse + Add, and an edit/remove glyph list`.

### Task 6: Share export without callout checkboxes

**Files:**
- Modify: `settings/Share.lua` (`KINDS` ~40, `NS.State.share.pick` ~59, the help text ~96)
- Modify: `modules/Share.lua`'s `Collect`, only if it reads `pick.callout`
- Test: `tests/test_page_share.lua`, `tests/test_share.lua`

- [ ] Write the failing test `share page: Export lists groups, pads and dials, and no callouts; a ticked group brings its callouts`.
- [ ] Run it and confirm it FAILS.
- [ ] Implement. The help text becomes `L["Tick what to share. A group brings its callouts with it, and a pad or a dial brings its groups. A pad or a dial travels without its key and its position."]` (unchanged if it already says this).
- [ ] Run the full gate and confirm it is green.
- [ ] Commit: `Share: callouts travel inside their group; Export drops the callout checkboxes`.

### Task 7: Docs and final sweep

**Files:**
- Modify: `docs/ARCHITECTURE.md` (Module Map, Settings Schema member-rows paragraph, Known Limitations if any change, Documentation map if a doc is added)
- Modify: `docs/settings-panel.md`, `docs/schema.md`, `docs/module-map.md`, `docs/data-flow.md`, `docs/common-tasks.md`, `docs/smoke-tests.md` (smoke steps for the popup, Reuse, the glyphs, and Cancel)
- Modify: `docs/test-cases.md` (check that the counts equal `lua tests/run.lua` output), and the README page list and its Tests badge
- Modify: `docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md` §5.2, §13.1 and §15: one line each, `*Superseded 2026-10-17 by 2026-10-17-callouts-owned-by-groups-design.md: …*`
- Modify: `locales/enUS.lua`: delete keys no code uses any more (grep each)

- [ ] Run `lua tests/run.lua --list` and confirm it equals the body of `docs/test-cases.md` (the suite that checks this is in the harness).
- [ ] Grep for `Callouts page`, `CalloutsPanel`, `Used by`, `UsedBy` and `DuplicateCallout` outside `docs/brainstorm`, `docs/audits`, `docs/reviews`, `docs/automated-tests` and `docs/superpowers`. Expect no stale hit.
- [ ] Run the full gate and confirm it is green.
- [ ] Commit: `Docs: callouts belong to groups; the popup replaces the Callouts page`.

## Checkpoints (resume here)

Record each task's commit hash in the ledger below as it lands. To resume, read the ledger, check that `git log feat/callouts-owned-by-groups` contains those hashes, and start at the first unchecked task.

| Task | Status | Commit |
|---|---|---|
| 1 Library | pending | |
| 2 Seam/slash | pending | |
| 3 Glyphs | pending | |
| 4 Popup | pending | |
| 5 Groups tab | pending | |
| 6 Share | pending | |
| 7 Docs | pending | |

Order: Tasks 1, 2, 3 and 6 are independent. Task 4 needs Task 1. Task 5 needs Tasks 1, 3 and 4. Task 7 comes last. Push to origin after Task 4 and after Task 7. Do not merge.
