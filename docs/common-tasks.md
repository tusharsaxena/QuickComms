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
feature verb is refused while disabled by the dispatcher itself. Update `docs/slash-dispatch.md`.

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

## Regenerate the test inventory

```sh
lua tests/run.lua --list > docs/test-cases.md
```

Then update the README's `[tests]` badge to the new Total, in the same commit.
