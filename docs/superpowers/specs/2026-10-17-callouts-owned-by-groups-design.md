# Callouts owned by groups, edited in a popup: design

Date: 2026-10-17. Status: approved by the owner 2026-10-17 (questions answered; builder calls marked). Amends the v0.1.0 design spec
(`2026-10-11-quickcomms-v1-design.md`) §5.2, §5.4, §13.1 and §15.

## Why

The Callouts page is a second place to manage callouts, separate from the groups that show them. The
owner wants one place: **Groups > Callouts**. A callout is made, edited, reused and removed there, and
it belongs to the group it sits in. Shared callouts (one callout in several groups, edited once for
all) go away. Reusing a callout now means making an independent copy.

## Goals

- Remove the Callouts settings page.
- Each user callout belongs to exactly one user group. No callout sits in two groups or in none.
- A user group's Callouts tab reads, top to bottom:

  ```
  [ Add callout ]
  [ Reuse existing callout  v ] [ Add ]
  ≡ (icon) Name   channel                         (edit) (remove)
  ≡ (icon) Name   channel                         (edit) (remove)
  ```

  - **Add callout** opens the callout popup with blank fields: an empty name and text, channel Smart
    group, no icon. These are the same defaults `Settings.Callouts.Create` uses today, apart from the
    name.
  - **Reuse existing callout** is a dropdown of every callout the player could copy, namespaced so
    each entry is unambiguous: user callouts as `<group name>: <callout name>`, then built-in callouts
    as `<set>: <callout>` (and `<set>: <child>: <callout>`), as `Groups.AddableCallouts` labels them
    today. The current group's own callouts are included because copying within a group is legitimate.
    **Add** puts an independent **copy** of the picked callout at the end of this group. Picking alone
    does nothing.
  - **The list** is the existing drag-to-reorder list (`Ed.ReorderRows`, LibKa0s `ReorderList`,
    options-ui-§18). Each row is the handle, the callout's icon, its name and channel, then two glyph
    buttons at the right in place of the red *Remove* button:
    - **Edit**: the catalog's `edit` mark (`NS.Icon("edit")`). Opens the popup filled in.
    - **Remove**: Blizzard's `transmog-icon-remove` atlas (the red no-entry sign), the same mark
      Consumable Master uses for the same act, which the owner pointed at (builder call: the catalog's
      `ban` is a white mark and would not match that reference; the settings panel is outside
      library-stack-§8's scope). Asks first (`Ed.ConfirmDelete`), then deletes the callout, since
      nothing else holds it.

    Both glyphs carry a tooltip, as Consumable Master's do.

    **Owner ruling (2026-10-17): the glyph remove applies everywhere `Ed.ReorderRows` draws**, so the
    Comms Pad and Comms Dial *Groups* lists lose their red Remove button too. There, remove only takes
    the group off that surface, so it does not ask first and there is no edit glyph.
- **The callout popup** holds what the old Callouts page's General tab held: Name, Text, Channel,
  Icon, Insert a token, Choose an icon, and *What it sends here*. Duplicate and Delete go: removing is
  the list's job, and copying is Reuse's. The *Used by* tab goes too.
  - **Save and Cancel.** The popup edits a **draft**: a plain copy of the callout's four fields (a
    blank one for Add). Every control writes the draft. *What it sends here* and the token list bake
    the draft, so the preview follows the edit before anything is saved.
  - **Save** checks the draft with the member rows' own validators (`Library.ValidName`,
    `Library.ValidIcon`, the channel's values, the text's length). If a field fails, the popup stays
    open and names the field. Otherwise Save writes everything as **one act**
    (`Library.Batch`): for an edit, each changed field through the seam (`SchemaRuntime.Set("callout.<field>",
    v, id)`); for a new callout, `Library.CreateCallout` then the insert at the end of the group.
    Then the popup closes.
  - **Cancel**, the close mark and Escape all discard the draft. Cancelling Add creates nothing.
  - **Look and feel match the settings panel (owner, 2026-10-17).** The popup is drawn with the
    settings panel's own building blocks: the same AceGUI widgets through `Settings.Helpers`
    (`RenderRows`, `RenderGrid`, `Section` headings with the gold rule, `InlineButtonPair` red
    buttons), the same icon picker (`Ed.IconPicker`), and a header and backdrop that read as part of
    the panel. It must **not** look like the debug console or the copy window. Its close control goes
    through the one `NS.MakeCloseButton` wrapper (standalone-windows).
  - The popup sits above the settings window and is **fully modal** to it (builder call): a
    click-catcher covers the settings window, so the page underneath cannot change while a draft is
    open. Only one popup exists. It closes (as Cancel) when the settings window hides, on a profile
    change, and when the callout it edits stops existing (a `/qc` write or an import under it). A
    slash write to the same callout while the popup is open is not merged: Save writes the fields the
    draft changed against the values captured when the popup opened.

## Data model (amends spec §5.2)

`profile.callouts` and `group.callouts` keep their shape. Only the rule changes: **each user callout
id appears in exactly one user group's `callouts` list.** `Library` keeps the rule as the only
registry writer (architecture-§5, anti-pattern #78):

- `Library.AddToGroup(gid, cid)` **always copies**: a built-in callout as today, and now a user
  callout too (`DuplicateCallout`'s fields and name, without the "copy" suffix: the copy lives in a
  different group, or the player can rename it). The copy and the insert are one act.
- `Library.RemoveFromGroup(gid, index)` deletes the callout it removes.
- `Library.DeleteGroup(id)` deletes the group's callouts with it. Its confirmation and tooltip change
  from "its callouts are kept" to say they are deleted.
- `Library.DuplicateGroup(id)` copies the group's callouts into the new group.
- `Library.Customize(builtinId)` already copies each built-in callout; unchanged.
- `Library.UsedBy` and `DuplicateCallout` lose their last panel callers; delete them if nothing else
  calls them (no dead exports).
- **Prepare** (the load pass) enforces the rule on every profile load. A callout held by a second
  group is replaced in that group by a fresh copy. **A callout held by no group is deleted (owner
  ruling, 2026-10-17)**, counted in Prepare's `repaired` tally like any other repair.
- **Import** (`Library.Import`) does the same: a string whose groups share a callout id gets one copy
  per group. A loose callout (in no imported group) is not imported; the report counts it as left
  out, like a dangling reference.

A **migration step 3** (`perProfile`, `NS.SCHEMA_VERSION` 3) is not needed if Prepare carries the
rule on every load, since Prepare already runs for every profile. The builder chooses; Prepare alone
is preferred because a hand-edited or imported profile can break the rule again at any time.

## Share (amends spec §15)

- Export drops the **Callouts** checkboxes. A callout travels inside its group. The payload format
  (`v = 1`, `callouts` + `groups`) is unchanged, so old strings still import.
- Built-in tab: *Choose callouts* still opens Groups > Callouts on the set. Unchanged.

## Slash surface

The `callout.*` member rows stay: `/qc set callout.text <id> …` and `/qc check <id>` still work, by
id. Builder calls:

- The rows **keep `page = "callouts"`**. No registered page renders it any more; it is the heading
  `/qc list` groups them under. Moving them to `groups` would draw them on the group's General tab and
  put them under the Groups page's Defaults (`settings/Groups.lua:186-190`, `:312`). Nothing in the
  standard or the code requires a row's page to be a registered panel page
  (`settings/Schema.lua:252-255` passes no page set). If the build finds a rule that does, stop and
  raise it.
- A `callout.*` write that names **no id is refused** with a line naming the id form, instead of
  falling back to an arbitrary callout (`settings/Schema.lua:140-155`). The editors' `callout`
  selection (`NS.State.editing.callout`) goes away.
- The per-callout Defaults (channel back to Smart group) is dropped with the page; the popup has
  Save and Cancel instead.
- `settings/Slash.lua`'s descriptions that mention the Callouts page are updated. No verb is added
  or removed.

## Non-goals

- No change to built-in sets: a built-in's Callouts tab stays the Show-checkbox editor, and built-ins
  stay read-only.
- No change to pads, dials, the When editor, or the bake/send path.
- No new share format version.

## Anti-goals

- The popup must not look like a different addon's window (the debug console's chrome).
- A Cancel must never leave a half-saved callout or an empty callout behind.

## Standard check

- No rule of the Ka0s standard governs a modal editor inside the settings panel. It stays within the
  panel's rules: raw AceGUI, writes through the single seam, combat-gated like the panel. *Built:* the popup's ctx is a panel ctx, so the library's
  combat cover lies over it and refuses Save and every draft write; Escape still cancels.
- library-stack-§8 leaves the settings panel out of scope for catalog marks; the glyph buttons follow
  Consumable Master's precedent (catalog mark first, with the Blizzard mark where the catalog has none).
- options-ui-§14's banner rule covers pages; the popup is not a page, so it carries no banner.
- **If the builder finds a rule this breaks**, stop and raise it (CLAUDE.md). Nothing is recorded as a
  deviation yet.

## What changes, by file (guide, not a plan)

- `settings/Callouts.lua`: the page registration goes; the file becomes the popup (or a new
  `settings/CalloutPopup.lua` takes over and this file goes). `C.TOKENS`, `C.TokensFor` and
  `C.PreviewLines` are kept; the latter's caller in the Groups Preview tab still needs it.
- `settings/Groups.lua`: the Callouts tab as above; delete and duplicate wording.
- `settings/Editors.lua`: `Ed.ReorderRows` takes glyph buttons (edit, remove) and an icon per row.
- `modules/Library.lua`: the rules above, plus Prepare.
- `modules/Share.lua`, `settings/Share.lua`: the export checkboxes; the import split.
- `settings/SchemaMembers.lua`: the callout rows' page.
- The TOC, `locales/enUS.lua`, `settings/Panel.lua` page list.
- Tests: `test_page_callouts.lua` is rewritten for the popup; `test_page_groups.lua`,
  `test_library.lua`, `test_page_share.lua`, `test_profile.lua`, `test_schema.lua` follow.
- Docs: ARCHITECTURE.md (module map, page list), `settings-panel.md`, `schema.md`, `smoke-tests.md`,
  `test-cases.md`, README's page list, and the v0.1.0 spec's §5.2, §13.1 and §15 get a "superseded by"
  note pointing here.

## Left to the builder

- Popup geometry, and whether it is a new file or the old `Callouts.lua` reworked.
- The draft's validation messages' exact wording.
- Whether the channel column stays on the list rows.

## Owner rulings (2026-10-17)

1. Callouts in no group (an existing profile or an import) are **dropped**. Nothing has shipped
   (v0.1.0 is unreleased), so this only touches the owner's own profiles and strings.
2. The glyph remove applies to **every** `Ed.ReorderRows` list (Groups' callouts, Pads' and Dials'
   groups).
3. The popup has **Save and Cancel**, and editing a listed callout opens the same popup filled in.
4. The popup **looks like the settings panel** (its building blocks), not the debug console.

## Already answered by the code

- Export: a picked group already brings its callouts (`modules/Share.lua:545`).
- Draft fields: LibKa0s rows with no path that carry `get`/`set` route to custom functions
  (`libs/LibKa0s/OptionsWidgets.lua:422-442`), so the popup can render rows against the draft.
- Nothing outside `group.callouts` stores a callout id (the pads' and dials' `byCallout` maps and
  `SEND_RESULT` are runtime only), so which group keeps the original id in Prepare does not matter.
- `Library.Customize` copies through `AddToGroup` with built-in ids (`modules/Library.lua:560`).
