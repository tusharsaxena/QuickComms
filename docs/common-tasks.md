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

The worked example is `ping` and `marker` (#17, #18): `Library.TEMPLATES.callout` gives each `false`
(none), `Lib.ValidPing` and `Lib.ValidMarker` in `modules/Library.lua` are the validators, the
`callout.ping` and `callout.marker` rows in `settings/SchemaMembers.lua` take a `normalize` (so `/qc set
callout.ping <id> none` and `... 0` clear it) and a `validate` that also keeps the callout's last action
(`keepsAction`); `copyCallout`, `CreateCallout`, the seed (`BI.Callout`'s `extra`, `defaults/BuiltIns.lua`)
and migration step 6 (`modules/Library_Migrate.lua`) carry them; the popup has them in `DRAFT` and
`FIELDS`, draws them as one line of two dropdowns (`h.RenderField`, `split()`, `alignField()`), gives the
blank draft `ping = nil, marker = nil`, and checks them with `checkPing` and `checkMarker`.

## Add a callout action

A callout's actions are a fixed set, one of each kind, baked in a fixed order (D1): the Line, the emote,
the ping, the marker. A fifth kind is a member field (above) plus each reader of an action:

1. **Bake.** An entry builder in `modules/Bake.lua` that returns `{ kind, line, reason, length, value }`
   (and `chatType` and `lock` when the line is chat), from a fixed table and never from typed text, so no
   data byte follows a newline; add it to `B.BakeActions` in its place in the order. A command the client
   may lack (`Compat.PingCommand`) bakes nothing, with a reason of its own (`noPing`), and drops only
   that action. The Line's share of `B.MAX_MACRO` (`holdLine`) then leaves room for it.
2. **The action rule.** Count it in `Lib.HasAction` (`modules/Library.lua`).
3. **The reasons.** Its skipped reason's words in `PadRender.REASON_TEXT` and its kind's skipped row in
   `PadRender.SKIPPED_TEXT` (`modules/Pad_Render.lua`), both read by the tooltip and the editor.
4. **The press.** A chat action gets an echo entry for free (its `chatType`); a press-time note (no
   target, no rights) goes in `SE.PressNotes` (`modules/SendEngine.lua`), read in `PreClick` from plain
   Compat answers only.
5. **The readers.** Its echo line in `Preview.SlotEcho` (`modules/Preview.lua`), its rows in
   `Callouts.PreviewLines` (`settings/Callouts.lua`: the summary's short form and its own row), its
   Groups suffix (`settings/Groups.lua`), and `/qc check`'s row (`settings/SlashVerbs.lua`, by its
   `kind`).
6. **Tests and docs.** The order and the newline in `tests/test_bake.lua`, the press in
   `tests/test_sendengine.lua`, each reader's suite, and a smoke check (the ACTION, PING and MARK
   checks in `smoke-tests.md` are the pattern).

## Add an editor page

A file under `settings/` that calls `Settings.Editors.RegisterPage(pageKey, title, frameSuffix, render, defaults, hooks)` (`hooks`, optional, `{ onShow, onHide }`, run on the page's canvas each time it shows or hides; the Groups page's edit preview uses them), listed in the TOC above `settings\SlashVerbs.lua`. `render(ctx)` draws `PageBanner` (the picker and the create action; `PageHeader` instead when the band holds another page-wide control too, as the Groups page's Preview while editing), then `Settings.Editors.Tabs(ctx, pageKey, tabs)`. Keep the selection with `Ed.Heal`/`Ed.Select`, draw lists with `Ed.ReorderRows` (each entry `{ id, label, icon, iconColor, edit, editTooltip, remove, removeTooltip }`: an `edit` function adds the edit glyph, `remove` the remove glyph; a remove that deletes asks first, one that only takes a member off a surface does not), delete through `Ed.ConfirmDelete`, and write only through Library or the seam. A member's icon is chosen with `Ed.IconChooser(ctx, spec)` (its `choose` writes icon and color as one act, `Library.SetIcon`; see `G.IconSpec` in `settings/Groups.lua`), and any texture you draw for one is tinted with `Library.IconTint(icon, color)`, white included. Drive it in a suite through `tests/page_helpers.lua`.

## Change what the dial does in combat

The dial's in-combat behavior is the restricted snippets in `modules/Dial_Secure.lua` (`ONCLICK`, `OPEN`, `DISPLAY`, `SHOW`, `CLOSE`, `WEDGE_PRE`, `WEDGE_POST`). `DISPLAY` (`qc-display`) is the insecure open test mode and Preview as… use: the same open, but it binds no key, so Escape and 1–8 stay free while the settings window is open; a change to `OPEN` or `SHOW` must keep it so. `OPEN` closes every other open dial first (the `sibling<n>` frame refs `DialSecure.Link` writes), so one dial at a time holds Escape, the wheel and 1–8. A snippet may show, hide, anchor and bind, and reads attributes; it never writes one (the firewall greps the file). Anything it needs to know arrives as an attribute written by `DialSecure.Load` out of combat. Pin the change in `tests/test_dial_secure.lua`, in and out of combat; `tests/wow_mock.lua` runs the snippets in the header's own environment.

## Draw a color, a face or a border

Every color a surface draws is a skin token, never a literal: read it through `NS.Skin.Color` or
`NS.SkinColor(name)` (a settings page's colored line through `NS.SkinMarkup(name, text)`), and a HUD
face or border style through `NS.Skin.Resolve` beside the block's `<picker>FromSkin` companion. When
no library token holds the Ka0s Default value exactly, add an owner token to `NS.SKIN_TOKENS` in
`core/SkinSetup.lua` (named `qc.*`, its `default` today's value, `follow` its nearest library role
token), and add every library token you read to `NS.SKIN_FALLBACK` there in the same change.
`tests/test_skin_windows.lua`'s literal gate fails on a color literal in a scanned file, and
`tests/test_skinsetup.lua` holds the host copy to the library ([ARCHITECTURE.md → Skins](ARCHITECTURE.md#skins)).

## Regenerate the test inventory

```sh
lua tests/run.lua --list > docs/test-cases.md
```

Then update the README's `[tests]` badge to the new Total, in the same commit.

## Re-derive the client-data extractions

`tests/test_gameids.lua`'s `CLIENT_MAPS`, `defaults/GameIds.lua`'s dungeon and raid lists, `defaults/GameIds_Instances.lua`'s `INSTANCES` (every journal dungeon and raid) and `ARENAS` come from the client's own tables, as wago.tools exports them. A generator re-derives them and checks the repository against them (layout-§1: it lives under `tools/`, is never loaded, and is `.pkgmeta`-ignored); it needs Python 3 and nothing else, download into a new scratch directory, and exit non-zero on any mismatch:

```sh
D="$(mktemp -d)/tables"
python3 -I tools/derive-gameids.py --fetch "$D" && python3 -I tools/derive-gameids.py "$D"
```

For a new season or patch: change `SEASON`, `LAUNCH` (and `CURRENT_TIER` if the journal renumbers it) at the top of `tools/derive-gameids.py`, run it, and read every `MISMATCH:`, `NOT SHIPPED:` and `DROPPED:` line (`DROPPED_ARENAS` at the top of the script lists the legacy arena maps left out; a new arena map that shares a shipped one's name fails until it is listed there or replaces it); change the shipped lists and the test's rows to match only after reading them, then run it again until it prints `OK`. A new shipped id gets its `CLIENT_MAPS` row from the block the script prints (an `INSTANCES` or `ARENAS` id without one is a `MISMATCH:` line carrying the row to paste). Update the build named in the headers (`defaults/GameIds.lua`, `defaults/GameIds_Instances.lua`, `tests/test_gameids.lua`) with the build `--fetch` printed. A match is not an in-game confirmation: the headers say "matched" until smoke checks BG-2 and IDS-1 pass.

WoW Forever's lists (`defaults/GameIds_Clients.lua`'s `FOREVER_DUNGEONS` and `FOREVER_RAIDS`, and the Forever map ids its battleground sets carry) and `tests/test_gameids.lua`'s `FOREVER_MAPS` come from Forever's own tables the same way. `--forever` fetches them at the build `FOREVER_BUILD` names (wago.tools serves product `wowf` by `?build=`; an export of any other build fails) and checks them:

```sh
D="$(mktemp -d)/forever"
python3 -I tools/derive-gameids.py --forever --fetch "$D" && python3 -I tools/derive-gameids.py --forever "$D"
```

The id source is Forever's group finder (the forever-ids design's D5): GroupFinderActivity joined to Map on its MapID column, with no name join. It fails on a `FOREVER_MAPS` row that differs from Map, on a dungeon list that is not exactly the party maps (Map InstanceType 1) the group finder lists, on a raid list that is not exactly its raid maps (2), on a battleground map it lists that no set carries and `NOT_SHIPPED_PVP` at the top of the script does not name (or a stale `NOT_SHIPPED_PVP` entry), on a battleground id of the wrong kind, and on any arena map (D4). A raid-sized activity on a party map (Blackfathom Deeps, Gnomeregan, Sunken Temple in the Raids category) stays a dungeon, because the map's instance type classifies it. It prints the `NOT_SHIPPED_PVP` maps (Darkspear Islands, 2997) and, for information only, every party, raid and battleground map Map holds that is neither shipped nor listed as `NOT SHIPPED:`, and a set's newer Retail map id as `RETAIL ONLY:`. For a new Forever build: change `FOREVER_BUILD`, run it, read every line, change the lists and `FOREVER_MAPS` (from the block it prints) only after reading them, and update the build named in `defaults/GameIds_Clients.lua` and `tests/test_gameids.lua`. The in-game check is `/qc probe ids` (smoke checks FOREVER-16 and FOREVER-25): it needs no travel, and its record in Forever's `QuickComms.lua` (`global.probes.forever`, `kind = "ids"`) is diffed against the extraction: each `FOREVER_MAPS` id should carry the same name in its `maps`, and each `groupFinder` activity's `mapID` should be a shipped id, a zone (`maxNumPlayers` 0) or one the script printed as `NOT SHIPPED:`; the chat's group finder line says the same. A build the client runs that wago.tools does not serve yet can be checked from that record alone.

The generators leave a `__pycache__/` beside them; `.gitignore` keeps it out of the repository.

