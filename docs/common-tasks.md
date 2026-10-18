# Common tasks — Ka0s Quick Comms

## Add a setting

1. Add its default to `defaults/Profile.lua` (`NS.C.PROFILE`).
2. Declare the row in its page file under `settings/` with `path`, `type`, `default`, `page`,
   `group`, `label` and `desc` (or `tooltip`), and splice it in with `NS.SchemaRuntime.AddRows`.
3. Add every new `label` and `desc` string to `locales/enUS.lua`, the value equal to the key.
4. React in the row's `onChange` (or in `Settings.REACTIONS` when other surfaces write the same
   path). Never write the profile directly; read the value back with `NS.Setting(path)`.
5. Run `lua tests/run.lua`: `test_schema` validates the row against the defaults.

## Add a slash verb

Add a positional triple `{ "name", L["description"], function(rest) ... end }` to `NS.COMMANDS` in
`settings/Slash.lua`, calling the same handler as any other surface that does the same thing. A
feature verb is refused while disabled by the dispatcher itself. Put the body in
`settings/SlashVerbs.lua` (`NS.SlashVerbs`) so a test can call it. Update `docs/slash-dispatch.md`.

## Add a game event

Append `{ "EVENT_NAME", "HandlerMethod" }` to `NS.FEATURE_EVENTS` from the owning file, and define
`NS.addon.HandlerMethod`. The stand-up registers it, the stand-down unregisters it, and
`test_disabled` pins the addon's own list by name: add the event to `PINNED` there too. A module's
teardown and rebuild go in `NS.STAND_DOWN` / `NS.STAND_UP`.

## Add a bus message

Add `KEY = "Ka0s_QuickComms_Event"` to the catalog in `core/Bus.lua`, with its one sender in the
comment, and a row to the Message Bus table in `docs/ARCHITECTURE.md`. Receivers take their own
target, `NS.Bus:NewTarget()`, and use `NS.MSG.KEY`, never the literal.

## Add a migration step

Append `{ to = n, run = function(sv, profile) ... end }` to `NS.MIGRATIONS` in `core/Database.lua`
(`perProfile = true` to run it for every stored profile). `NS.SCHEMA_VERSION` follows the last step.
Make the step idempotent against a fresh default profile, and document it in `docs/schema.md`.

## Add a source file

List it in `QuickComms.toc` under its `#` section, with a `# LOAD-BEARING:` or `# Conventional:`
comment on the line above it (a TOC line carries the path alone; anything after it becomes part of
the file name). Open it with `local addonName, NS = ...` (or `local _, NS = ...`) and a comment naming
its path and purpose.

## Add a perf bucket

Declare `{ key = "..." }` in `core/PerfSetup.lua` and bracket the hot path with the gated form
(performance-§2). `test_setup` fails until a `Perf.Note("<key>", ...)` bracket exists for it; add an
offline scenario to `tests/perf.lua` when the path is hot.

## Add a diagnostics section

Add a `{ "name", function(out) ... end }` entry to `NS.Diagnostics.Sections()`. Read state only and
pass raw values to `out:add`. Document it in `docs/debug.md`.

## Add a member field

Add the field to `Library.TEMPLATES[kind]` (its shape and default), and a row to `settings/SchemaMembers.lua` with `instance = "<kind>"`, a `page` and a `group` (the tab), a `validate` that names its reason, (the file's closing loop gives it `onChange = Library.Touch(kind, id, path)`). If Library creates or copies the member, write the field there too (a create writes the member whole). If a write to it changes what a page draws (a label, a dot), add its path to `Editors.STRUCTURAL`. The page's tab draws it through `RenderRows`; a table-valued field gets a structured `type`, a bespoke control that writes the whole value with `NS.SchemaRuntime.Set(path, value, id)`, and a text form in `settings/Slash.lua`'s `PARSE` and `FORMAT`.

A callout field has no page: the callout popup is its editor. Add it to `DRAFT` in `settings/CalloutPopup.lua` (the draft, the baseline and Save's changed-field writes follow from it, in that order), and to `FIELDS` and `renderFields` too when the popup draws it as a row of its own, in one of its two columns or across both (the icon and its color are drawn by the icon chooser instead), give the blank draft in `Pop.Open` its default, and check it in the popup's `check` with the row's own validator; `copyCallout` in `modules/Library.lua` (the copy `AddToGroup`, `CreateGroup` and `DuplicateGroup` make) must carry it too (Prepare's split copies the stored table whole, so it needs nothing). Pin it in `tests/test_callout_popup.lua`.

## Add an editor page

A file under `settings/` that calls `Settings.Editors.RegisterPage(pageKey, title, frameSuffix, render, defaults)`, listed in the TOC above `settings\SlashVerbs.lua`. `render(ctx)` draws `PageBanner` (the picker and the create action), then `Settings.Editors.Tabs(ctx, pageKey, tabs)`. Keep the selection with `Ed.Heal`/`Ed.Select`, draw lists with `Ed.ReorderRows` (each entry `{ id, label, icon, iconColor, edit, editTooltip, remove, removeTooltip }`: an `edit` function adds the edit glyph, `remove` the remove glyph; a remove that deletes asks first, one that only takes a member off a surface does not), delete through `Ed.ConfirmDelete`, and write only through Library or the seam. A member's icon is chosen with `Ed.IconChooser(ctx, spec)` (its `choose` writes icon and color as one act, `Library.SetIcon`; see `G.IconSpec` in `settings/Groups.lua`), and any texture you draw for one is tinted with `Library.IconTint(icon, color)`, white included. Drive it in a suite through `tests/page_helpers.lua`.

## Change what the dial does in combat

The dial's in-combat behavior is the restricted snippets in `modules/Dial_Secure.lua` (`ONCLICK`, `OPEN`, `DISPLAY`, `SHOW`, `CLOSE`, `WEDGE_PRE`, `WEDGE_POST`). `DISPLAY` (`qc-display`) is the insecure open test mode and Preview as… use: the same open, but it binds no key, so Escape and 1–8 stay free while the settings window is open; a change to `OPEN` or `SHOW` must keep it so. `OPEN` closes every other open dial first (the `sibling<n>` frame refs `DialSecure.Link` writes), so one dial at a time holds Escape, the wheel and 1–8. A snippet may show, hide, anchor and bind, and reads attributes; it never writes one (the firewall greps the file). Anything it needs to know arrives as an attribute written by `DialSecure.Load` out of combat. Pin the change in `tests/test_dial_secure.lua`, in and out of combat; `tests/wow_mock.lua` runs the snippets in the header's own environment.

## Regenerate the test inventory

```sh
lua tests/run.lua --list > docs/test-cases.md
```

Then update the README's `[tests]` badge to the new Total, in the same commit.

## Re-derive the client-data extractions

`tests/test_gameids.lua`'s `CLIENT_MAPS`, `defaults/GameIds.lua`'s dungeon and raid lists, and the node winds in `defaults/BuiltIns_Battlegrounds.lua` come from the client's own tables, as wago.tools exports them. Two generators re-derive them and check the repository against them (layout-§1: they live under `tools/`, are never loaded, and are `.pkgmeta`-ignored); both need Python 3 and nothing else, download into a new scratch directory, and exit non-zero on any mismatch:

```sh
D="$(mktemp -d)/tables"
python3 -I tools/derive-gameids.py --fetch "$D" && python3 -I tools/derive-gameids.py "$D"
P="$(mktemp -d)/poi"
python3 -I tools/derive-winds.py --fetch "$P" && python3 -I tools/derive-winds.py "$P"
```

For a new season or patch: change `SEASON`, `LAUNCH` (and `CURRENT_TIER` if the journal renumbers it) at the top of `tools/derive-gameids.py`, run it, and read every `MISMATCH:` and `NOT SHIPPED:` line; change the shipped lists and the test's rows to match only after reading them, then run it again until it prints `OK`. A new shipped id gets its `CLIENT_MAPS` row from the block the script prints. For a battleground a patch redraws, change its entry in `NODES` at the top of `tools/derive-winds.py` (the AreaPOI id and the name that row must carry) and copy the winds it prints into `defaults/BuiltIns_Battlegrounds.lua`. Update the build named in the headers (`defaults/GameIds.lua`, `defaults/BuiltIns_Battlegrounds.lua`, `tests/test_gameids.lua`) with the build `--fetch` printed. A match is not an in-game confirmation: the headers say "matched" until smoke checks BG-1, BG-2 and IDS-1 pass.

The generators leave a `__pycache__/` beside them; `.gitignore` keeps it out of the repository.

## Change what a share string carries

A new member row of a pad or a dial travels with it on its own (`Share.Portable`: every row of its kind but its name, Enabled, position and key). A new callout or group field needs three places: `exportMember` in `modules/Share.lua`, the kind's entry check above it (`calloutEntry`, `groupEntry`), and `importMembers` in `modules/Library.lua`; pin it in `tests/test_share.lua` and `tests/test_library.lua`. Raise `Share.VERSION` only when an older Quick Comms would misread the new string, and add `MIGRATIONS[old]` lifting an old payload one step.
