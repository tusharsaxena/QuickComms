# Ka0s Quick Comms: phase 3 implementation plan (the editors)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the player build their own comms: a Callouts page, a Groups page (with the When editor and a Preview tab), a Comms Pad page, a Share page with the Built-in tab (enable, hide, Customize), "Preview as…" on the pads, and "Why is this showing?" on the pad header and in `/qc why`.

**Architecture:**
- **Every member field is a schema row.** A callout's text, a group's When, a pad's layout and position, a built-in set's overlay: each is an instance-relative row (`callout.text`, `group.when`, `pad.layout.style`, `builtin.enabled`) in `settings/SchemaMembers.lua`, written through the one seam (`NS.SchemaRuntime.Set(path, value, id)`). The seam resolves the member from the instance argument, or, without one, from the member its editor page has selected (`NS.State.editing`, session-only), or, with nothing selected, the first member that page lists (`Settings.EditingId`), so the CLI works before a page was ever opened. The three table-valued rows are typed and printed on the CLI through the Slash descriptor's `parse` and `format` hooks. `modules/Library.lua` stays the registry writer: membership (create, delete, duplicate, Customize), the order of every list, the references a group and a surface hold, the ids and the seeding. Its old field writers (`SetBuiltinEnabled`, `SetBuiltinCalloutHidden`, `SetSurfacePoint`) keep their names and now go through the seam. Each row's `onChange` is `Library.Touch`, so `LIBRARY_CHANGED` keeps its one sender and the pads rebuild through the existing `Surfaces.Request` path (queued in combat, with the stale hint).
- **Pages are thin.** `settings/Editors.lua` holds what the four pages share: the selection, one deferred and coalesced structural repaint on a `LIBRARY_CHANGED` that changes a page's shape, a `SITUATION_CHANGED` that changes the set of active groups, `TEST_MODE_CHANGED` and `PROFILE_CHANGED` (every other change refreshes in place: the library's refreshers and the pages' live lines), the delete confirmation, the drag-to-reorder lists (LibKa0s-Widgets `ReorderList`, options-ui-§18) and page registration. Each page is a banner picker plus its create action (options-ui-§14), and a tab strip drawn by the library's `RenderTabbedSchema` with host tabs for what is not a plain row.
- **Preview as… is test mode's second flavor.** `modules/Preview.lua` builds a synthetic snapshot from a short menu (Current, M+, each shipped dungeon, each raid difficulty, Arena, each battleground, World solo). `Surfaces.ApplyAll` builds the pads from it, marks the plan as a preview, and every previewed chip is disarmed. It is session-only, exclusive with the placeholder test mode, refused in combat, ended at the combat edge, by the stand-down and when the settings window closes.

**Tech stack:**
- Lua 5.1, against the WoW Retail 12.1 client (Interface `120100`)
- Ace3 (AceAddon, AceDB, AceEvent, AceTimer, AceConsole, AceGUI)
- LibKa0s v1.71.0 (Options `PageBanner`, `TabStrip`, `RenderTabbedSchema` with host tabs and `rerender`, `RenderRows`, `RenderGrid`, `IdList`, `InlineButtonPair`, `TextRow`, `Section`, `RestoreDefaults`, `RefreshPanel`; Widgets `ReorderList`; Schema instance resolution and `BulkRun`; the Slash descriptor's `parse` and `format` hooks, slash-commands-§6)
- the LibKa0s headless test kit (`tests/_kit/`), with its AceGUI recorder (`__created`, `__fire`) and the Settings registrars (`__subcategories`)
- luacheck

**Spec:** [`docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md`](../specs/2026-10-11-quickcomms-v1-design.md) (amended 2026-10-13). Read it alongside this plan; section numbers below (§n) refer to it. The Ka0s WoW Addon Standard is at `../WowAddonStandards/standards/` (v2.79.x); section names below (options-ui-§14, architecture-§5) refer to it.

**Scope note:** this plan covers **phase 3 only** (§19 row 3). Out of scope:
- the Comms Dial, its page, `Bindings.xml` and override key bindings (phase 4)
- Share's Export and Import tabs, the import report and `LibSerialize` / `LibDeflate` (phase 5)
- the perf scenarios in `tests/perf.lua`, the battleground and Midnight instance ID confirmation (phase 5)
- an open-world built-in set (declined by the owner)

**Precedents copied, by file and symbol:**

| What | Copied from |
|---|---|
| A page that edits one instance of many: banner picker plus create action, a `General` first tab holding the acts | AuraMaster `settings/Containers.lua` (`BAND`, `doNew`, `doDuplicate`, the delete popup) |
| Instance-relative schema paths resolved by the seam (`container.name` against the selected container) | AuraMaster `settings/Schema.lua` `resolveRoot`, `defaultsRoot` (`NS.CONTAINER_TEMPLATE`) |
| A drag-to-reorder list built from `RenderGrid` wide items, the controller canceled first | KickCD `settings/Spells.lua` `newReorder`, `spellItems`, `fillRows`, `renderRows` |
| Driving a settings page headlessly (show, find a widget by label, click a tab, the banner widgets) | AuraMaster `tests/page_helpers.lua` |
| A popup accepted after combat started | AuraMaster `settings/Containers.lua` `AURAMASTER_DELETE_CONTAINER` |
| Test mode's switch, refusal and combat end (Preview as… is its second flavor) | this addon's `modules/Preview.lua` (phase 2) |

## Global Constraints

These apply to every task.

**Carried from phases 0–1** (phase 2's block, word for word; the named-frame list is extended with this phase's frames, and the line-ending and Git lines are amended as marked):
- Interface `120100`. Lua 5.1 syntax only: no `goto`, no integer division, no `//`.
- LibKa0s **v1.71.0** as vendored; never edit `libs/` or `tests/_kit/`.
- Title `Ka0s Quick Comms`; folder `QuickComms`; saved variables exactly `QuickCommsDB` and `QuickCommsPerfDB`; chat tag `|cff00ffff[QC]|r`; slash `/qc`, alias `/quickcomms`; bus names `Ka0s_QuickComms_<PascalCaseEvent>` declared once in `core/Bus.lua` (all nine already exist).
- Every authored `.lua` opens with `local addonName, NS = ...` (or `local _, NS = ...`), with a comment naming the file's path and purpose directly beneath it.
- No new globals except the named frames the client requires (`QuickCommsSend<n>`, `QuickCommsPad<id>`, and from this phase the editor pages' canvases `QuickComms<Callouts|Groups|Pads|Share>Panel` and the `QUICKCOMMS_DELETE_MEMBER` entry in `StaticPopupDialogs`), no `print()` (use `NS.Print` / `NS.Debug`), no `_G[addonName]`.
- Modules publish idempotently (`NS.X = NS.X or {}`) and never call another module's table at file load, except a load-time upvalue the TOC marks `# LOAD-BEARING:`.
- Match game data by ID or token, never by a localized name.
- US English in all code, comments and strings. Every user-facing string goes through `NS.L["English text"]`; each task adds its new keys to `locales/enUS.lua` (a key that file already defines is not added twice).
- **Secret values:** anything read from the client goes through `NS.Compat` and becomes a plain value or nil. Never compare, concatenate or format a value that might be secret. The echo tracker never reads chat text.
- **Commit gate:** before every commit, `lua tests/run.lua` exits 0 **and** `luacheck .` reports 0 warnings and 0 errors.
- **Suite and TOC bookkeeping:** every new `tests/test_*.lua` joins the `suites` list in `tests/run.lua`. Every new `.lua` file is listed in `QuickComms.toc`, with its `# LOAD-BEARING:` or `# Conventional:` comment on **its own line directly above** the entry (a trailing comment breaks the file name).
- **Line endings:** CRLF (`.gitattributes` is `* text=auto eol=crlf`); let git normalize, never hand-write LF-only files into the index. *(Amended for phase 3:* after `git add`, refresh the working tree from the index so the files on disk carry CRLF: `git add <files> && git checkout -- <files>`; the checkout rewrites only the paths just added.)
- **Git:** ~~commit on `main` only after the gate passes. Do not push unless the owner asks.~~ *(Amended for phase 3:* commit on the current branch, `feat/phase-3-editors`, after the gate passes. Never commit to `main`, never merge, never bump the version. A task's executor never pushes; the controller pushes the branch to `origin` at each milestone checkpoint (the owner's run instructions), and merging waits for the owner's word.)

**Refinements this phase adds to that block:**
- Game data is matched by ID or token, never by a localized name (localization-§4). A display name read from the client (an instance, a class, a specialization) is for display only.
- Each task adds its locale keys under a comment naming the file; each task's key list below was checked against `locales/enUS.lua` as it stood when this plan was written. If an earlier task already added one, skip it.
- `tests/page_helpers.lua` is a helper, not a suite (no `test_` prefix), and is not listed in `tests/run.lua`.

**Carried from phase 2** (still binding; this phase edits `Pad.arm`, `Surfaces.ApplyAll`, the pad's drag and the preview's combat-edge end):
- **One secure writer (§9).** Only `modules/SendEngine.lua` calls `SetAttribute`, `RegisterStateDriver` / `UnregisterStateDriver`, `SetOverrideBinding*` / `ClearOverrideBindings`, or names a `Secure*` template. Its grep test (phase 2, Task 3) stays green.
- **Never a protected write in combat** (events-frames-taint-§2). The guard is `NS.Compat.InCombat()` (`InCombatLockdown()`), never `UnitAffectingCombat`. Protected-frame `Show` / `Hide` / `SetPoint` / `SetSize` / `SetScale` and every attribute or driver write run inside `SendEngine.RunOrQueue` or a function only it calls. In combat the work is queued and the surface shows its stale hint.
- **One send path (D12).** No `SendChatMessage` / `C_ChatInfo.SendChatMessage` anywhere in shipped code; a callout reaches chat only as a secure button's `macrotext`.
- **The soft spam guard (§9.2)** and **the echo tracker (§9.3)** are unchanged; one press can yield two `SEND_RESULT`s (`guarded`, then `sent` or `dropped`). A previewed or placeholder chip yields none.
- **Never rely on `InCombatLockdown()` being false inside a `PLAYER_REGEN_DISABLED` handler.** Work started from the combat edge (test mode's or the preview's end, a rebuild) goes through `SendEngine.RunOrQueue`, which queues when lockdown has already begun. Tests drive both orders.
- **The registry writer, as amended for phase 3** (architecture-§5, spec §5). Phase 2's "`modules/Library.lua` is the only writer of `profile.pads` / `profile.dials`; the pad writes its anchor only through `Library.SetSurfacePoint`" becomes: **membership, order, ids, references and seeding** of every registry collection are written only by `modules/Library.lua`; **a member's own fields** are written only through the seam (`NS.SchemaRuntime.Set`, the member rows of Task 3a). The pad still writes its anchor only by asking `Library.SetSurfacePoint`, which hands it to the seam's `pad.point` row. The `[registry]` grep test in `tests/test_pad.lua` still pins that no file but Library assigns `.point`. The active tab and the collapsed state stay session state in `NS.State`.
- **No second `PLAYER_REGEN_*` feature row.** `Restrictions` owns both; AceEvent keys handlers by (event, object). Combat edges are consumed through `RESTRICTION_CHANGED` plus `NS.Restrictions.InCombat()`. The single exception is SendEngine's private pending-teardown target (slash-commands-§7).
- **Frames are never destroyed.** Chips are pooled per pad with `NS.Pool`; a deleted pad's frame is released to its pool, never destroyed. The pad's look comes from `NS.ApplySkin`; no host copy of the skin.
- **Perf (performance-§2/§3).** Shape A brackets with the load-time `local Perf = NS.Perf`. This phase adds no bucket; a bucket added later is declared in `core/PerfSetup.lua` in the same task as its bracket.
- **Disabled is total (slash-commands-§7).** Stood down, every pad is hidden and every chip disarmed (held to `PLAYER_REGEN_ENABLED` if in combat), every timer canceled, every event and message unregistered. Every new bus receiver is torn down and replayed by the stand-down and stand-up; every new timer is canceled by the stand-down.
- **Test mode** is session-only (`NS.State.testMode`), refused in combat, ended at the start of combat, ended by Reset all settings, and renders placeholder chips that send nothing. From this phase "Preview as…" is its second flavor (`NS.State.previewAs`), with the same rules.

**From the spec (phase 3):**
- **The panel refuses to open in combat, and the library locks any page shown in combat** (§13.1). No page adds a combat guard of its own (options-ui-§2, §13). A popup accepted after combat started may still write data: data writes are allowed in combat, and the pads pick them up at combat end.
- **Setters that rebuild secure frames gate on `InCombatLockdown()` and queue through SendEngine** (§13.1): every member write reaches the pads only through `LIBRARY_CHANGED` → `Surfaces.Request`, which is `SendEngine.RunOrQueue` with the stale hint. Protected calls only via `SendEngine.RunOrQueue`; no page touches a pad frame.
- **Member fields go through the seam** (architecture-§5: "a member field a row addresses goes through the helper even when the registry writer is the caller"; the registry-writer constraint above, as amended). Panel code and slash handlers call Library or the seam; they never append to, splice or `table.remove` a stored collection, and never assign a member field directly.
- **Built-ins are read-only** (§12.2): every group row refuses to write a built-in id with a reason; the overlay rows (`builtin.enabled`, `builtin.hidden`) are the only writable part of a built-in, and Customize is the way to edit one.
- **Every page has a tab strip, and every row has a `group`** (§13.1, options-ui-§13). The band above the strip carries the picker and the create action only (options-ui-§14); a page's acts live on its first tab, named `General`.
- **"Preview as…" and test mode are session-only** (`NS.State`), never saved; both are refused in combat and while stood down, ended at the start of combat, ended by the stand-down; a previewed or placeholder chip sends nothing and prints nothing.
- **A re-rendering refresh only when the layout changes** (options-ui-§11): an editor page is torn down and redrawn only when what it draws changes shape (membership, order, the selection, a name, a group's When or Enabled, Customize, a profile switch, the preview switch, a change in the set of active groups). A scalar member write refreshes in place.

## Review Focus

These are the inputs most likely to hurt a real player that no feature test would naturally cover. Each one has a pinning test, tagged `[review n]`, in the task named in brackets.

1. **Editing a callout while in combat** (`/qc set callout.text …` mid-pull, or a delete popup accepted after the pull started): the write lands, no protected call is attempted, the chip keeps its old line, the stale hint shows, and at combat end the pad rebuilds with the new line and the hint clears. [Task 3b]
2. **The member an open editor is showing is deleted from somewhere else** (the Groups page deletes a callout the Callouts page has selected, a profile switch, a Customize that turns a built-in off): no Lua error, the page heals to the next member, and no later write lands on the stale id. [Tasks 6 and 7]
3. **"Preview as…" left on** when combat starts, the addon is disabled or the settings window closes: the preview ends, the live chips come back armed, and a previewed chip never sends, prints or reports anything (the solo self-line included). [Task 4a]
4. **A built-in selected in an editor**: every write to it is refused with a reason (the panel draws it read-only, the CLI prints the reason, nothing reaches `NS.BuiltIns` or the overlay), and Customize puts an editable copy in the built-in's place on every pad and selects it. [Tasks 3a, 3b, 9 and 11]
5. **Bad input from the panel or the CLI** (an empty or 33-character name, an unknown channel, a key-level range whose lowest is above its highest, a callout whose text starts with `/`): refused with the reason and nothing stored, or, for the `/` text, stored and shown at once as "sends nothing here" with the bake's reason. [Tasks 3a, 7 and 8]

## Milestones

Each milestone ends green and is a resume point: the plan's checkboxes and `git log` say where the work stands.

- **Milestone 1: the data layer and the pads (Tasks 1, 2, 3a, 3b, 4a, 4b, 5).** The parked phase-2 fix, Library's new writer operations, every member field as a schema row, "Preview as…" and "Why is this showing?" on the pads and in the CLI. Everything is drivable from the CLI and tested headlessly; no page exists yet. Checkpoint: `lua tests/run.lua` and `luacheck .` green; commits on `feat/phase-3-editors`; the controller pushes the branch.
- **Milestone 2: the editor pages (Tasks 6–11).** The shared editor frame and the page test helpers, then the Callouts page, the When editor, the Groups page, the Comms Pad page and the Share page's Built-in tab. Checkpoint: green; every page renders headlessly and its suite drives it through the AceGUI recorder; the controller pushes the branch.
- **Milestone 3: docs and the owner's smoke test (Tasks 12–13).** The spec's rulings, ARCHITECTURE and the maps, the new smoke checks EDIT-1..8, then the owner's in-game run. The plan ends with Task 13; merging is the owner's call.

## Standard deviations to raise

None. One was considered and avoided: architecture-§5 says the schema **MUST** drive `/<slash> get|set|list|reset` for every row, and three member rows hold tables (`pad.point`, `group.when`, `builtin.hidden`). The vendored LibKa0s-Slash already takes a per-row `parse` (handed the row, the text and the resolver) and `format(row, storedValue)` on its descriptor (`libs/LibKa0s/Slash.lua` lines 407-415, wired at 482 and 511), and slash-commands-§6 lets an addon with an exotic row type supply its own parser there. Task 3b adds both to `settings/Slash.lua`, switching on `row.type` and handing every other type to the library, so every member row is listed, read and written from the CLI and the register stays empty.

Four spec lines that disagreed with the standard are ruled toward the standard instead, and Task 12 records each in the spec (not in the deviation register, because the addon then conforms):
- §4.3 and the phase brief say Library is "the only module that writes those collections" and that editors "write ONLY through modules/Library.lua"; architecture-§5 requires member preferences to be rows written through the seam. Library keeps membership, order, ids, references and seeding; member fields are rows.
- §13.1 gives the Groups, Comms Pad and Comms Dial pages "a nav rail of groups / pads / dials"; options-ui-§14 says "the rail is not a picker" and "the banner is the ONLY picker". Each page has a banner picker and no rail.
- §13.1 puts the Callouts page's acts on a "Message" tab; options-ui-§14 requires the acts' tab to be first and named `General`. The tabs are General and Used by.
- §13.3 makes "Preview as…" "a banner dropdown"; options-ui-§14 keeps the band to one row holding the picker and the create action. "Preview as…" is the first row of the General tab of the Groups and Comms Pad pages (a session row, `state.previewAs`), and `/qc preview` sets it from the command line.

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `modules/Pad.lua` | modify | Task 1: a held drag never sticks. Task 3b: the point comments; publishes `Pad.DEFAULT_POINT`. Task 4a: previewed chips disarmed (no line, self-line or lock text), the header names the preview. Task 5: the header's "why" tooltip. |
| `modules/Library.lua` | modify | Task 2: templates, `Member`, `MemberIds`, `Touch` (with the field), validators, `CopyName`, Duplicate, OfferGroup, MoveGroupOnSurface, Customize's name and guard. Task 3b: its field writers go through the seam. Task 11: `Batch`. |
| `core/State.lua` | modify | Task 3a: `State.editing`. Task 4a: `State.previewAs`. Task 8: `State.whenOpen`. All session-only. |
| `settings/SchemaMembers.lua` | create | Task 3a: every member row (callout, group, pad, built-in overlay). |
| `settings/Schema.lua` | modify | Task 3a: instance resolution and `EditingId`, the member rows' defaults root, the structured types, the profile reset's predicate. Task 4b: the `state.previewAs` session storage. |
| `settings/Slash.lua` | modify | Task 3b: the descriptor's `parse` and `format` for the structured rows. Tasks 4b and 5: the `preview` and `why` verbs. |
| `defaults/GameIds.lua` | create | Task 4b: the shipped id tables (dungeons, raids, classes, specializations). |
| `core/Compat.lua` | modify | Task 4b: `InstanceName`. Task 8: `SpecInfoByID`, `ClassName`. |
| `modules/Preview.lua` | modify | Task 4a: "Preview as…": presets, the switch, its ends. Task 4b: the dungeon presets. |
| `modules/Surfaces.lua` | modify | Task 4a: the preview plan. Task 5: `plan.active`, `WhyLines`. |
| `modules/Pad_Render.lua` | modify | Task 4a: the preview tooltip line and header label. Task 5: `ShowLines`. |
| `modules/Resolver.lua` | modify | Task 8: publishes `R.LABEL`. |
| `modules/Diagnostics.lua` | modify | Task 4b: the preview line. |
| `settings/SchemaRows.lua` | modify | Task 3a: the degraded-load comment. Task 4b: the `state.previewAs` row. |
| `settings/SlashVerbs.lua` | modify | Tasks 4b and 5: `Preview`, `Why`. |
| `settings/Panel.lua` | modify | Task 4a: the settings window's hide ends the preview. |
| `settings/Editors.lua` | create | Task 6: what the editor pages share. Task 8: a profile switch clears `whenOpen`. |
| `settings/Callouts.lua` | create | Task 7: the Callouts page. |
| `settings/Groups_When.lua` | create | Task 8: the When editor. |
| `settings/Groups.lua` | create | Task 9: the Groups page. |
| `settings/Pads.lua` | create | Task 10: the Comms Pad page. |
| `settings/Share.lua` | create | Task 11: the Share page and its Built-in tab. |
| `tests/page_helpers.lua` | create | Task 6: drive a page headlessly (not a suite). |
| `tests/test_members.lua` | create | Task 3a (Task 3b appends) |
| `tests/test_editors.lua` | create | Task 6 |
| `tests/test_page_callouts.lua` | create | Task 7 |
| `tests/test_groups_when.lua` | create | Task 8 |
| `tests/test_page_groups.lua` | create | Task 9 |
| `tests/test_page_pads.lua` | create | Task 10 |
| `tests/test_page_share.lua` | create | Task 11 |
| `tests/test_setup.lua` | modify | Task 3a: the degraded load's schema holds only member rows. |
| `tests/test_pad.lua`, `test_library.lua`, `test_schema.lua`, `test_preview.lua`, `test_surfaces.lua`, `test_pad_render.lua`, `test_slash.lua`, `test_compat.lua`, `test_diagnostics.lua` | modify | the tasks named in each |
| `QuickComms.toc`, `tests/run.lua`, `locales/enUS.lua`, `.luacheckrc` | modify | bookkeeping, per task |
| `docs/…`, `README.md` | modify | Task 12 |

The TOC order this plan ends with (new lines marked `+`):

```
defaults\BuiltIns_Battlegrounds.lua
+ defaults\GameIds.lua
...
settings\SchemaRows.lua
+ settings\SchemaMembers.lua
settings\Panel.lua
+ settings\Editors.lua
+ settings\Callouts.lua
+ settings\Groups_When.lua
+ settings\Groups.lua
+ settings\Pads.lua
+ settings\Share.lua
settings\SlashVerbs.lua
settings\Slash.lua
settings\Profiles.lua
```

The settings sidebar then reads: Ka0s Quick Comms (landing), General, Callouts, Groups, Comms Pad, Share, Profiles.

---
### Task 1: Pad: a held drag never sticks (the parked phase-2 minor)

When combat starts mid-drag, `endDrags` marks the pad `dragHeld` and files the stop under `padDrag`. A stand-down in that combat drops the whole queue (`SendEngine.Drop("standDown")`) and holds the teardown; if the player re-enables inside the same combat, the stand-up cancels the teardown, so `Pad.Release` (which clears `dragHeld`) never runs. The flag then sticks for the session: `Pad.Apply` skips `applyPoint` while it is set, so the pad never re-anchors again, and the root is never stopped. Two fixes: a new drag clears any stale held stop, and the stand-up re-files the stop for a pad still held.

**Files:**
- Modify: `modules/Pad.lua` (the strip's `onDragStart` in `build`; the `NS.STAND_UP` step at the end of the file)
- Test: `tests/test_pad.lua` (append two cases at the end)

**Interfaces:**
- Consumes: `NS.SendEngine.RunOrQueue(key, fn)`, `applyPoint(inst)` (file-local), `pads` (file-local), the existing test helpers in `tests/test_pad.lua`: `applied()`, `startDrag(NS, m)`, `countStops(inst)`, `combat(m, on)`, `pointOf(inst)`, `planFor(NS)`.
- Produces: no new member; `inst.dragHeld` is now always cleared by a new drag or by the drained stop.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_pad.lua`:
```lua
test("pad: [phase 3] a held drag whose stand-down is canceled in the same combat is stopped at combat end", function()
    local NS, m = applied()
    local inst = startDrag(NS, m)
    local stops = countStops(inst)
    m.__setCombat(true)
    m.__fire("PLAYER_REGEN_DISABLED")
    NS.SchemaRuntime.Set("enabled", false)   -- the stand-down drops `padDrag` and holds the teardown
    NS.SchemaRuntime.Set("enabled", true)    -- the stand-up cancels the held teardown
    assertTrue(inst.dragHeld == true, "still held while combat lasts")
    combat(m, false)
    -- red under: drop refileHeldDrags from Pad's NS.STAND_UP step (dragHeld sticks; the root is never stopped)
    assertEqual(stops[1], 1)
    assertNil(inst.dragHeld)
    assertEqual(#m.blocked, 0)
    assertEqual(pointOf(inst), "CENTER,CENTER,0,-150", "the drop was never saved: back to the saved point")
end)

test("pad: [phase 3] a new drag clears a stale held stop, so the next rebuild re-anchors", function()
    local NS, m = applied()
    local inst = NS.Pad.Instance("p1")
    inst.dragHeld = true
    startDrag(NS, m)
    -- red under: drop `inst.dragHeld = nil` from the strip's onDragStart in modules/Pad.lua
    assertNil(inst.dragHeld)
    inst.handle:__fire("OnDragStop")
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "TOPLEFT,TOPLEFT,25,-35")
    NS.Library.SetSurfacePoint("pad", "p1", { "TOPLEFT", "TOPLEFT", 40, -60 })
    NS.Pad.Apply("p1", planFor(NS))
    assertEqual(pointOf(inst), "TOPLEFT,TOPLEFT,40,-60")
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `lua tests/run.lua`
Expected: FAIL on both new cases (the first: `stops[1]` is 0 and `dragHeld` stays true; the second: `dragHeld` is still true after the new drag).

- [ ] **Step 3: Clear the flag on a new drag**

In `modules/Pad.lua`, `build`, replace
```lua
        onDragStart = function() inst.dragging = true end,
```
with
```lua
        -- A new drag supersedes any stop still held for an earlier one (endDrags).
        onDragStart = function()
            inst.dragHeld = nil
            inst.dragging = true
        end,
```

- [ ] **Step 4: Re-file a held stop at the stand-up**

In `modules/Pad.lua`, replace the last block
```lua
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
```
with
```lua
-- A held drag whose stop the stand-down dropped (it drops the whole combat-end queue) and whose
-- teardown the stand-up then canceled inside the same combat would keep `dragHeld` for good, and
-- Apply would never re-anchor the pad again. The stand-up files the stop again: it runs now out of
-- combat, else at combat end, and the frame goes back to its saved point, because the player
-- disabled the addon mid-drag and the drop was never saved.
local function refileHeldDrags()
    local held = {}
    for _, inst in pairs(pads) do
        if inst.dragHeld then held[#held + 1] = inst end
    end
    if #held == 0 then return end
    NS.SendEngine.RunOrQueue("padDrag", function()
        for _, inst in ipairs(held) do
            if inst.dragHeld then
                inst.dragHeld = nil
                inst.root:StopMovingOrSizing()
                applyPoint(inst)
            end
        end
    end)
end

NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
    refileHeldDrags()
end
```
In `modules/Pad.lua`'s file header, after the sentence ending "keeps the cursor's place." add: "A held stop the stand-down dropped is filed again by the stand-up, and a new drag clears it."

- [ ] **Step 5: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS, 0 warnings / 0 errors, the kit's `test_prose` included (US spelling: "canceled", never the British double-l form, in the test name and the comment).

- [ ] **Step 6: Commit**

```bash
git add modules/Pad.lua tests/test_pad.lua && git checkout -- modules/Pad.lua tests/test_pad.lua
git commit -m "Pad: a held drag never sticks when its stand-down is canceled in the same combat"
```

---

### Task 2: Library: the writer operations the editors call

The editors need operations the registry writer does not have yet: duplicate a callout or a group, offer a new group to every surface, reorder a surface's groups, read the member a row addresses, and the per-kind template every member row resolves against. Each is a membership, order or identity operation (architecture-§5), so it belongs to Library. The field validators live here too, because the rows (Task 3a) and Library's own create paths share them; so does the order each editor page's picker lists its members in (`MemberIds`), which the seam's fallback shares.

**Files:**
- Modify: `modules/Library.lua`
- Test: `tests/test_library.lua` (append)

**Interfaces:**
- Consumes: `NS.Resolver.ROWS` (read at call time), `NS.BuiltIns.groups / callouts / order`, the file-locals `P`, `announce`, `indexOf`, `copyTable`, `isBuiltin`, `topOf`, `overlay`, `chars`, `surface`, `SURFACE_DEFAULTS`.
- Produces (later tasks rely on these exact names):
  - `Lib.IsBuiltin(id) -> boolean`, `Lib.TopOf(id) -> string|nil`
  - `Lib.ValidName(v) -> true | false, "badName"`; `Lib.ValidIcon(v) -> true | false, "badIcon"`; `Lib.ValidPoint(v) -> true | false, "badPoint"` (nil is valid: the default place); `Lib.ValidWhen(w) -> true | false, "badWhen"|"badRange"`; `Lib.ValidHidden(top, set) -> true | false, "badHidden"`
  - `Lib.CopyName(name[, suffix]) -> string` (`"<name> (copy)"`, or `<name>` plus `suffix`, at most `Lib.NAME_MAX` characters)
  - `Lib.TEMPLATES = { callout = {…}, group = {…}, pad = {…}, builtin = {…} }`
  - `Lib.Member(kind, id) -> table|nil` (kind `"callout" | "group" | "pad" | "dial" | "builtin"`)
  - `Lib.Touch(kind, id, field)` (sends `LIBRARY_CHANGED (kind, id, field)`; `field` is the member row's path, so a listener can tell a field write from a membership or order change, which sends no field)
  - `Lib.MemberIds(kind) -> string[]` (kind `"callout" | "group" | "pad"`): every member in the order its editor page's picker lists them (user callouts and user groups by name, case-insensitive, then id; the built-in sets after the user groups, in shipped order; pads in `padOrder`)
  - `Lib.DuplicateCallout(id) -> id|nil, reason`; `Lib.DuplicateGroup(id) -> id|nil, reason`
  - `Lib.OfferGroup(groupId) -> number` (surfaces it was added to)
  - `Lib.MoveGroupOnSurface(kind, surfaceId, from, to) -> boolean`
  - `Lib.CreateGroup(fields)` now also takes `fields.callouts` (user callout ids, copied in order; unknown ids dropped) and validates `name` with `ValidName` and `when` with `ValidWhen`.
  - `Lib.Customize(builtinId)` names its copy with `Lib.CopyName(name, " (custom)")`, so a long (or translated) set name is shortened, never refused; and it returns `nil, reason` with nothing changed if `CreateGroup` still refuses.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_library.lua`:
```lua
test("library: [phase 3] DuplicateCallout copies every field under a '(copy)' name", function()
    local _, Lib, p = boot()
    local id = Lib.CreateCallout({ name = "Lust", text = "Lust {rt8}", channel = "party", icon = 136012 })
    local copy = Lib.DuplicateCallout(id)
    assertTrue(copy ~= id)
    local c = p.callouts[copy]
    assertEqual(c.name, "Lust (copy)")
    assertEqual(c.text, "Lust {rt8}")
    assertEqual(c.channel, "party")
    assertEqual(c.icon, 136012)
    assertNil((Lib.DuplicateCallout("c999")))
end)

test("library: [phase 3] a copy's name stays within the 32-character cap, counted in characters", function()
    local _, Lib = boot()
    local long = string.rep("\195\169", 30)          -- thirty two-byte characters
    local name = Lib.CopyName(long)
    assertEqual(select(2, name:gsub("[^\128-\191]", "")), Lib.NAME_MAX)
    assertTrue(name:sub(-7) == " (copy)")
    assertTrue(Lib.ValidName(name))
end)

test("library: [phase 3] DuplicateGroup shares the callouts (D8) and copies the When, on no surface", function()
    local _, Lib, p = boot()
    local cid = Lib.CreateCallout({ name = "A", text = "a", channel = "party" })
    local gid = Lib.CreateGroup({ name = "Mine", when = { content = { raid = true } } })
    Lib.AddToGroup(gid, cid)
    local copy = Lib.DuplicateGroup(gid)
    assertEqual(p.groups[copy].name, "Mine (copy)")
    assertEqual(p.groups[copy].callouts[1], cid, "the same callout, by reference")
    assertTrue(p.groups[copy].when.content.raid)
    p.groups[copy].when.content.raid = nil
    assertTrue(p.groups[gid].when.content.raid, "a copy, not an alias")
    for _, pad in pairs(p.pads) do
        for _, g in ipairs(pad.groups) do assertTrue(g ~= copy, "not offered to a surface") end
    end
    assertNil((Lib.DuplicateGroup("bi.mplus")), "a built-in is customized, never duplicated")
end)

test("library: [phase 3] CreateGroup keeps only existing user callouts, and validates the When", function()
    local _, Lib, p = boot()
    local cid = Lib.CreateCallout({ name = "A", text = "a", channel = "party" })
    local gid = Lib.CreateGroup({ name = "G", callouts = { cid, "c999", "bi.mplus.lust" } })
    assertEqual(#p.groups[gid].callouts, 1)
    assertEqual(p.groups[gid].callouts[1], cid)
    local bad, why = Lib.CreateGroup({ name = "G", when = { nope = { x = true } } })
    assertNil(bad)
    assertEqual(why, "badWhen")
    assertNil((Lib.CreateGroup({ name = "   " })), "a blank name is no name")
end)

test("library: [phase 3] OfferGroup puts a user group first on every pad and dial, once", function()
    local _, Lib, p = boot()
    local gid = Lib.CreateGroup({ name = "Mine" })
    assertEqual(Lib.OfferGroup(gid), 2, "the default pad and the default dial")
    assertEqual(p.pads.p1.groups[1], gid)
    assertEqual(p.dials.d2.groups[1], gid)
    assertEqual(Lib.OfferGroup(gid), 0, "already on both")
    assertEqual(Lib.OfferGroup("bi.mplus"), 0, "built-ins are seeded, never offered")
    assertEqual(Lib.OfferGroup("g999"), 0)
end)

test("library: [phase 3] MoveGroupOnSurface reorders a surface's groups and announces it", function()
    local NS, Lib, p, sent = boot()
    local first, second = p.pads.p1.groups[1], p.pads.p1.groups[2]
    assertTrue(Lib.MoveGroupOnSurface("pad", "p1", 1, 2))
    assertEqual(p.pads.p1.groups[1], second)
    assertEqual(p.pads.p1.groups[2], first)
    assertEqual(sent[#sent][1], NS.MSG.LIBRARY_CHANGED)
    assertEqual(sent[#sent][2], "pad")
    assertFalse(Lib.MoveGroupOnSurface("pad", "p1", 99, 1))
    assertFalse(Lib.MoveGroupOnSurface("pad", "p9", 1, 2))
    assertFalse(Lib.MoveGroupOnSurface("pad", "p1", 1, nil))
end)

test("library: [phase 3] Member answers the live member of each kind, and a built-in group's copy", function()
    local NS, Lib, p = boot()
    local cid = Lib.CreateCallout({ name = "A", text = "a", channel = "party" })
    assertTrue(Lib.Member("callout", cid) == p.callouts[cid])
    assertTrue(Lib.Member("pad", "p1") == p.pads.p1)
    assertTrue(Lib.Member("dial", "d2") == p.dials.d2)
    local g = Lib.Member("group", "bi.mplus")
    assertEqual(g.name, NS.BuiltIns.groups["bi.mplus"].name)
    g.name = "changed"
    assertTrue(NS.BuiltIns.groups["bi.mplus"].name ~= "changed", "a copy: the shipped set never changes")
    assertTrue(Lib.Member("builtin", "bi.bg.ab.stables") == p.builtins["bi.bg.ab"], "a node's overlay is its battleground's")
    assertNil(Lib.Member("callout", nil))
    assertNil(Lib.Member("pad", "d2"))
    assertNil(Lib.Member("nope", "p1"))
end)

test("library: [phase 3] Touch announces the member it is handed, and the field", function()
    local NS, Lib = boot()
    local sent = {}   -- boot's recorder keeps three arguments; this one keeps the field too
    NS.addon.SendMessage = function(_, name, kind, id, field) sent[#sent + 1] = { name, kind, id, field } end
    Lib.Touch("callout", "c7", "callout.text")
    assertEqual(sent[#sent][1], NS.MSG.LIBRARY_CHANGED)
    assertEqual(sent[#sent][2], "callout")
    assertEqual(sent[#sent][3], "c7")
    -- red under: drop the `field` argument from Lib.Touch's announce
    assertEqual(sent[#sent][4], "callout.text")
    Lib.CreateCallout({ name = "A", text = "a", channel = "party" })
    assertNil(sent[#sent][4], "a membership change names no field")
end)

test("library: [phase 3] MemberIds lists each kind in its picker's order", function()
    local NS, Lib, p = boot()
    assertEqual(#Lib.MemberIds("callout"), 0)
    local b = Lib.CreateCallout({ name = "beta", text = "b", channel = "party" })
    local a = Lib.CreateCallout({ name = "Alpha", text = "a", channel = "party" })
    assertEqual(table.concat(Lib.MemberIds("callout"), ","), a .. "," .. b, "by name, case-insensitive")
    local g = Lib.CreateGroup({ name = "Mine" })
    local groups = Lib.MemberIds("group")
    assertEqual(groups[1], g, "user groups first")
    assertEqual(groups[2], NS.BuiltIns.order[1], "then the built-in sets in shipped order")
    assertEqual(#groups, 1 + #NS.BuiltIns.order)
    assertEqual(table.concat(Lib.MemberIds("pad"), ","), table.concat(p.padOrder, ","))
    assertEqual(#Lib.MemberIds("nope"), 0)
end)

test("library: [phase 3] Customize shortens a long set name instead of refusing it", function()
    local NS, Lib, p = boot()
    NS.BuiltIns.groups["bi.mplus"].name = string.rep("x", 30)
    local id = Lib.Customize("bi.mplus")
    assertTrue(id ~= nil, "a copy, whatever the set's name")
    local name = p.groups[id].name
    assertTrue(Lib.ValidName(name))
    assertEqual(name:sub(-9), " (custom)")
end)

test("library: [phase 3] Customize changes nothing when the copy cannot be made", function()
    local _, Lib, p = boot()
    local before = table.concat(p.pads.p1.groups, ",")
    Lib.CreateGroup = function() return nil, "badWhen" end
    local id, why = Lib.Customize("bi.mplus")
    -- red under: drop the `if not id then return nil, why end` guard from Lib.Customize
    assertNil(id)
    assertEqual(why, "badWhen")
    assertEqual(table.concat(p.pads.p1.groups, ","), before, "no hole where the set was")
    local o = p.builtins["bi.mplus"]
    assertTrue(o == nil or o.enabled ~= false, "the set stays on")
end)

test("library: [phase 3] ValidWhen accepts every shipped When and refuses bad shapes", function()
    local NS, Lib = boot()
    for id, def in pairs(NS.BuiltIns.groups) do
        if def.when then assertTrue(Lib.ValidWhen(def.when), id) end
    end
    assertTrue(Lib.ValidWhen({}))
    assertTrue(Lib.ValidWhen({ instances = { [2526] = true }, keyLevel = { min = 10 } }))
    assertFalse(Lib.ValidWhen({ combat = { yes = true } }), "not a v0.1.0 condition (spec P1)")
    assertFalse(Lib.ValidWhen({ content = { raid = 1 } }))
    assertFalse(Lib.ValidWhen({ content = "raid" }))
    local ok, why = Lib.ValidWhen({ keyLevel = { min = 12, max = 10 } })
    assertFalse(ok)
    assertEqual(why, "badRange")
    assertFalse(Lib.ValidWhen("x"))
end)

test("library: [phase 3] the point, icon and hidden-set validators", function()
    local _, Lib = boot()
    assertTrue(Lib.ValidPoint(nil), "nil is the default place")
    assertTrue(Lib.ValidPoint({ "TOPLEFT", "TOPLEFT", 1, -2 }))
    assertFalse(Lib.ValidPoint({ "TOPLEFT", "TOPLEFT", "1", -2 }))
    assertFalse(Lib.ValidPoint("CENTER"))
    assertTrue(Lib.ValidIcon(nil))
    assertTrue(Lib.ValidIcon(false))
    assertTrue(Lib.ValidIcon(136012))
    assertTrue(Lib.ValidIcon("Interface\\Icons\\Spell_Nature_Bloodlust"))
    assertFalse(Lib.ValidIcon(""))
    assertFalse(Lib.ValidIcon({}))
    assertTrue(Lib.ValidHidden("bi.bg.ab", { ["bi.bg.ab.stables.inc1"] = true }))
    assertTrue(Lib.ValidHidden("bi.mplus", {}))
    assertFalse(Lib.ValidHidden("bi.mplus", { ["bi.raid.wipe"] = true }), "another set's callout")
    assertFalse(Lib.ValidHidden("bi.mplus", { ["bi.mplus.nope"] = true }), "no such callout")
    assertFalse(Lib.ValidHidden("bi.mplus", { ["bi.mplus.lust"] = 1 }))
    assertFalse(Lib.ValidHidden(nil, {}))
end)

test("library: [phase 3] every member template holds a value at every field", function()
    local _, Lib = boot()
    assertEqual(Lib.TEMPLATES.callout.channel, "smartGroup")
    assertEqual(Lib.TEMPLATES.pad.layout.style, "iconLabel")
    assertEqual(Lib.TEMPLATES.pad.look.visibility, "always")
    assertTrue(Lib.TEMPLATES.pad.point == false, "false: the default place, and a value the boot check can see")
    assertTrue(Lib.TEMPLATES.builtin.enabled)
    assertTrue(Lib.IsBuiltin("bi.raid"))
    assertFalse(Lib.IsBuiltin("g3"))
    assertEqual(Lib.TopOf("bi.bg.ab.stables"), "bi.bg.ab")
end)
```
(`bi.raid.wipe` is the raid set's "Wipe" lead callout, `defaults/BuiltIns_Raid.lua`.)

- [ ] **Step 2: Run the tests to check they fail**

Run: `lua tests/run.lua`
Expected: FAIL (`DuplicateCallout`, `CopyName`, `OfferGroup`, `MoveGroupOnSurface`, `Member`, `Touch`, the validators and `TEMPLATES` do not exist).

- [ ] **Step 3: Export the built-in helpers**

In `modules/Library.lua`, directly after the `topOf` function, add:
```lua
--- Whether an id names a shipped built-in (a dotted `bi.` id).
Lib.IsBuiltin = isBuiltin
--- A built-in id's top-level set (a node resolves to its battleground), or nil.
Lib.TopOf = topOf
```

- [ ] **Step 4: The validators and the copy name**

In `modules/Library.lua`, replace the whole `validCallout` function with:
```lua
--- Whether `v` is a member name: a string with a visible character, at most NAME_MAX characters.
--- @return boolean ok, string|nil reason
function Lib.ValidName(v)
    if type(v) ~= "string" or not v:match("%S") or chars(v) > Lib.NAME_MAX then return false, "badName" end
    return true
end

--- Whether `v` is an icon: none (nil or false), a texture id, or a texture path.
function Lib.ValidIcon(v)
    if v == nil or v == false or type(v) == "number" then return true end
    if type(v) == "string" and v ~= "" then return true end
    return false, "badIcon"
end

--- Whether `v` is a surface anchor: nil (the default place) or { point, relativePoint, x, y }.
function Lib.ValidPoint(v)
    if v == nil then return true end
    if type(v) ~= "table" or type(v[1]) ~= "string" or type(v[2]) ~= "string"
        or type(v[3]) ~= "number" or type(v[4]) ~= "number" then
        return false, "badPoint"
    end
    return true
end

-- A When's keyLevel: { min, max }, either end a number or absent, the lowest not above the highest.
local function validRange(v)
    local lo, hi = v.min, v.max
    if (lo ~= nil and type(lo) ~= "number") or (hi ~= nil and type(hi) ~= "number") then
        return false, "badWhen"
    end
    if lo and hi and lo > hi then return false, "badRange" end
    return true
end

-- Any other When row: a set of ids or tokens, each mapped to true.
local function validSet(v)
    for key, on in pairs(v) do
        if on ~= true or (type(key) ~= "string" and type(key) ~= "number") then return false, "badWhen" end
    end
    return true
end

--- Whether `w` is a When (spec §5.3): rows the Resolver knows, each a set of ids or tokens mapped to
--- true, and keyLevel a { min, max } range whose lowest is not above its highest.
--- @return boolean ok, string|nil reason ("badWhen" | "badRange")
function Lib.ValidWhen(w)
    if type(w) ~= "table" then return false, "badWhen" end
    local known = {}
    for _, row in ipairs(NS.Resolver.ROWS) do known[row] = true end
    for row, v in pairs(w) do
        if not known[row] or type(v) ~= "table" then return false, "badWhen" end
        local ok, why
        if row == "keyLevel" then ok, why = validRange(v) else ok, why = validSet(v) end
        if not ok then return false, why end
    end
    return true
end

--- Whether `set` is a hidden-callout set for the top-level built-in `top` (spec §12.2): its own
--- callouts (a node's included) mapped to true.
function Lib.ValidHidden(top, set)
    if type(top) ~= "string" or type(set) ~= "table" then return false, "badHidden" end
    local prefix = top .. "."
    for cid, on in pairs(set) do
        if on ~= true or type(cid) ~= "string" or cid:sub(1, #prefix) ~= prefix or not NS.BuiltIns.callouts[cid] then
            return false, "badHidden"
        end
    end
    return true
end

local function validCallout(f)
    if type(f) ~= "table" then return false, "badCallout" end
    if not Lib.ValidName(f.name) then return false, "badName" end
    if type(f.text) ~= "string" then return false, "badText" end
    if not NS.Channels.IsKind(f.channel) then return false, "badChannel" end
    if not Lib.ValidIcon(f.icon) then return false, "badIcon" end
    return true
end

-- The first `n` UTF-8 characters of `s`.
local function firstChars(s, n)
    local out, count = {}, 0
    for ch in s:gmatch("[%z\1-\127\192-\253][\128-\191]*") do
        if count == n then break end
        count = count + 1
        out[count] = ch
    end
    return table.concat(out)
end

--- A copy's name: "<name> (copy)", or `<name>` plus `suffix`, the original shortened so the whole
--- stays within NAME_MAX (counted in characters).
function Lib.CopyName(name, suffix)
    suffix = suffix or L[" (copy)"]
    return firstChars(tostring(name or ""), Lib.NAME_MAX - chars(suffix)) .. suffix
end
```
(`chars` and `Lib.NAME_MAX` are declared just above `validCallout` and stay where they are. `validRange` and `validSet` keep `Lib.ValidWhen` under the collection's CCN 15 line, which lizard checks at release.)

- [ ] **Step 5: Duplicate, and CreateGroup's callouts**

In `modules/Library.lua`, after `Lib.DeleteCallout`, add:
```lua
--- Copy a user callout under a "(copy)" name. The copy is in no group.
--- @return string|nil id, string|nil reason
function Lib.DuplicateCallout(id)
    local c = P().callouts[id]
    if not c then return nil, "noCallout" end
    return Lib.CreateCallout({ name = Lib.CopyName(c.name), text = c.text, channel = c.channel, icon = c.icon })
end
```
Replace the whole `Lib.CreateGroup` with:
```lua
--- Create a user group. `fields.callouts` (optional) are user callout ids, copied in order; an id
--- that is not a user callout is dropped.
--- @return string|nil id, string|nil reason
function Lib.CreateGroup(fields)
    if type(fields) ~= "table" or not Lib.ValidName(fields.name) then return nil, "badName" end
    if fields.when ~= nil and not Lib.ValidWhen(fields.when) then return nil, "badWhen" end
    local p = P()
    local callouts = {}
    for _, cid in ipairs(type(fields.callouts) == "table" and fields.callouts or {}) do
        if p.callouts[cid] then callouts[#callouts + 1] = cid end
    end
    local id = Lib.NewId("g")
    p.groups[id] = { name = fields.name, icon = fields.icon, callouts = callouts, when = copyTable(fields.when) or {},
        openInto = fields.openInto == true, enabled = fields.enabled ~= false }
    announce("group", id)
    return id
end
```
After `Lib.DeleteGroup`, add:
```lua
--- Copy a user group: the same callouts by reference (D8), a copy of its When. On no surface.
--- @return string|nil id, string|nil reason
function Lib.DuplicateGroup(id)
    local g = P().groups[id]
    if not g then return nil, "noGroup" end
    return Lib.CreateGroup({ name = Lib.CopyName(g.name), icon = g.icon, when = g.when, openInto = g.openInto,
        enabled = g.enabled, callouts = g.callouts })
end
```
In `Lib.Customize`, replace
```lua
    local id = Lib.CreateGroup({ name = def.name .. " " .. L["(custom)"], icon = def.icon, when = def.when,
        openInto = def.openInto == true })
```
with
```lua
    -- The copy's name is shortened to fit, never refused (a translated set name may run long); a copy
    -- CreateGroup still refuses changes nothing: no surface loses the set, and the set stays on.
    local id, why = Lib.CreateGroup({ name = Lib.CopyName(def.name, " " .. L["(custom)"]), icon = def.icon,
        when = def.when, openInto = def.openInto == true })
    if not id then return nil, why end
```

- [ ] **Step 6: Surfaces: offer, move**

In `modules/Library.lua`, after `Lib.RemoveGroupFromSurface`, add:
```lua
--- Put a new user group at the top of every pad's and dial's list (the editors' New group): the
--- player's own groups come before the shipped sets. A surface that already lists it is skipped.
--- @return number surfaces it was added to
function Lib.OfferGroup(groupId)
    if not P().groups[groupId] then return 0 end
    local n = 0
    for _, kind in ipairs({ "pad", "dial" }) do
        local ids = {}
        for sid in pairs(surfaces()[kind]) do ids[#ids + 1] = sid end
        table.sort(ids)
        for _, sid in ipairs(ids) do
            if Lib.AddGroupToSurface(kind, sid, groupId, 1) then n = n + 1 end
        end
    end
    return n
end

--- Move one of a surface's groups from position `from` to position `to` (clamped to the list).
function Lib.MoveGroupOnSurface(kind, sid, from, to)
    local s = surface(kind, sid)
    if not (s and s.groups[from]) or type(to) ~= "number" then return false end
    to = math.max(1, math.min(to, #s.groups))
    table.insert(s.groups, to, table.remove(s.groups, from))
    announce(kind, sid)
    return true
end
```

- [ ] **Step 7: Templates, Member, Touch**

In `modules/Library.lua`, directly after the `SURFACE_DEFAULTS` table, add:
```lua
--- The shape of one member of each kind: what every member row's path resolves against (the
--- architecture-§5 boot check) and what a member row resets to. `icon` and `point` are false, not
--- nil, so the boot check can see the key: false is "none" and "the default place".
Lib.TEMPLATES = {
    callout = { name = "", text = "", channel = "smartGroup", icon = false },
    group = { name = "", icon = false, enabled = true, openInto = false, when = {} },
    pad = { name = "", enabled = true, groupsAs = SURFACE_DEFAULTS.pad.groupsAs, point = false,
        layout = copyTable(SURFACE_DEFAULTS.pad.layout), look = copyTable(SURFACE_DEFAULTS.pad.look) },
    builtin = { enabled = true, hidden = {} },
}
```
At the end of the `-- ── reads` section (after `Lib.UsedBy`), add:
```lua
--- The live member a member row addresses (settings/SchemaMembers.lua): a user callout, group, pad
--- or dial, or the overlay of a built-in set (a node's is its battleground's). A built-in group
--- answers its merged copy, so its fields read; the group rows refuse to write one. Nil without a
--- database, an id or such a member.
--- @param kind string "callout" | "group" | "pad" | "dial" | "builtin"
--- @return table|nil
function Lib.Member(kind, id)
    if id == nil or not (NS.db and NS.db.profile) then return nil end
    local p = P()
    if kind == "callout" then return p.callouts[id] end
    if kind == "group" then
        if isBuiltin(id) then return Lib.Group(id) end
        return p.groups[id]
    end
    if kind == "pad" then return p.pads[id] end
    if kind == "dial" then return p.dials[id] end
    if kind == "builtin" then
        local top = topOf(id)
        return top and overlay(top) or nil
    end
    return nil
end

--- A member row's reaction: the seam stored the field; Library, LIBRARY_CHANGED's one sender
--- (spec §17), announces it, naming the field (the row's path), so a listener can tell a field
--- write from a membership or order change (settings/Editors.lua repaints only for some fields).
function Lib.Touch(kind, id, field)
    announce(kind, id, field)
end

--- Every member of a kind, in the order its editor page's picker lists them: user callouts and user
--- groups by name (case-insensitive, then id), the built-in sets after the user groups in shipped
--- order, the pads in the pad order. The seam's fallback when a page has selected nothing
--- (settings/Schema.lua Settings.EditingId), and the pages' picker order.
--- @param kind string "callout" | "group" | "pad"
--- @return string[]
function Lib.MemberIds(kind)
    if not (NS.db and NS.db.profile) then return {} end
    local p = P()
    local out = {}
    if kind == "pad" then
        for _, id in ipairs(p.padOrder) do
            if p.pads[id] then out[#out + 1] = id end
        end
        return out
    end
    local source = (kind == "callout" and p.callouts) or (kind == "group" and p.groups) or nil
    if not source then return out end
    local list = {}
    for id, m in pairs(source) do list[#list + 1] = { id = id, key = tostring(m.name or id):lower() } end
    table.sort(list, function(a, b)
        if a.key ~= b.key then return a.key < b.key end
        return a.id < b.id
    end)
    for i, e in ipairs(list) do out[i] = e.id end
    if kind == "group" then
        for _, id in ipairs(NS.BuiltIns.order) do out[#out + 1] = id end
    end
    return out
end
```
Replace the file-local `announce` at the top of `modules/Library.lua` with:
```lua
local function announce(kind, id, field)
    NS.Debug(TAG, "%s %s%s", kind, tostring(id), field and (" " .. field) or "")
    NS.addon:SendMessage(NS.MSG.LIBRARY_CHANGED, kind, id, field)
end
```
`overlay` is declared at the top of the reads section, before `Lib.Callout`, so `Lib.Member` can call it.

Update the file header's first sentence to: "THE registry writer (architecture-§5, spec §5, §12.2): membership (create, delete, duplicate, Customize), the order of every list, the references a group and a surface hold, the ids and the seeding. A member's own fields (a callout's text, a pad's layout) are schema rows written through the seam (settings/SchemaMembers.lua); Library resolves the member for the seam (Member) and announces the write (Touch)."

- [ ] **Step 8: Locale keys**

In `locales/enUS.lua`, under a new comment `-- Library (modules/Library.lua)`:
```lua
L[" (copy)"] = " (copy)"
```

- [ ] **Step 9: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS, including every existing `test_library` case (Customize still builds its copy through `CreateGroup`; `CopyName` keeps every shipped name whole, the longest, `Battleground (generic) (custom)`, being 31 characters).

- [ ] **Step 10: Commit**

```bash
git add modules/Library.lua tests/test_library.lua locales/enUS.lua && git checkout -- modules/Library.lua tests/test_library.lua locales/enUS.lua
git commit -m "Library: duplicate, offer and move operations, member templates and the field validators"
```

---
### Task 3a: Member rows: every member field through the one seam

architecture-§5: "a preference the player sets on a member … is a setting, and a setting with no row is a missing row", and "a member field a row addresses goes through the helper even when the registry writer is the caller". This task declares a row for every field the editors set and makes the seam address a member. A member row's path starts with its kind (`callout.text`, `group.when`, `pad.layout.style`, `builtin.enabled`). The seam's `resolveRoot` hands the write to `Library.Member(kind, id)`: `id` is the instance argument; without one, it is `Settings.EditingId(kind)`, the member the kind's editor page has selected (`NS.State.editing[kind]`, the AuraMaster `container.*` model) while it exists, else the first member that page lists (`Library.MemberIds`), so a CLI write works before the page was ever opened. A built-in set's overlay has no such fallback: it is only ever the set the Groups page shows. A row's `onChange` calls `Library.Touch(kind, id, path)`, so `LIBRARY_CHANGED` and the pads' rebuild (queued in combat) are unchanged. Member rows are not AceDB defaults: each resolves against `Library.TEMPLATES` at the boot check, and the profile reset's count leaves them out. Three structured rows hold tables (`pad.point`, `group.when`, `builtin.hidden`); Task 3b teaches the CLI to type and print them. Task 3b also routes Library's own field writers through these rows.

**Files:**
- Create: `settings/SchemaMembers.lua`
- Modify: `settings/Schema.lua` (`resolveRoot`, `Settings.EditingId`, `Settings.BuildDefaults`, the validation's `defaultsRoot` and `VALID_TYPES`, the profile reset's predicate)
- Modify: `settings/SchemaRows.lua` (the comment on the degraded load)
- Modify: `core/State.lua` (`State.editing`)
- Modify: `QuickComms.toc` (the new file, after `settings\SchemaRows.lua`)
- Create: `tests/test_members.lua`; Modify: `tests/run.lua` (add `"test_members",` after `"test_library",`), `tests/test_schema.lua` (one case replaced, one added), `tests/test_setup.lua` (the degraded load's schema assertion)
- Modify: `locales/enUS.lua`

**Interfaces:**
- Consumes: Task 2's `Lib.TEMPLATES`, `Lib.Member`, `Lib.MemberIds`, `Lib.Touch`, `Lib.IsBuiltin`, `Lib.TopOf`, `Lib.ValidName`, `Lib.ValidIcon`, `Lib.ValidPoint`, `Lib.ValidWhen`, `Lib.ValidHidden`; `NS.Channels.KINDS`, `NS.Channels.IsKind`; `NS.SchemaRuntime.AddRows`.
- Produces:
  - Member rows (each with `instance = "<kind>"`, a `page` and a `group`). Callouts page (`page = "callouts"`, group `General`): `callout.name`, `callout.text`, `callout.channel`, `callout.icon`. Groups page (`page = "groups"`): `group.name`, `group.icon`, `group.enabled`, `group.openInto` (group `General`), `group.when` (group `When`, type `when`). Comms Pad page (`page = "pads"`): `pad.name`, `pad.enabled` (`General`); `pad.groupsAs` (`Groups`); `pad.layout.orientation`, `pad.layout.columns`, `pad.layout.growth`, `pad.layout.style`, `pad.layout.scale`, `pad.layout.spacing`, `pad.layout.width`, `pad.point` (`Layout`; type `point`); `pad.look.visibility`, `pad.look.fade`, `pad.look.fadeAlpha` (`Look`). Share page (`page = "share"`, group `Built-in`): `builtin.enabled`, `builtin.hidden` (type `idset`).
  - `NS.State.editing = { callout?, group?, pad?, builtin? }` (session-only).
  - `Settings.INSTANCE_KINDS = { callout = true, group = true, pad = true, builtin = true }`.
  - `Settings.EditingId(kind) -> id|nil` (the selection while it exists, else `Library.MemberIds(kind)[1]`; `builtin` has no fallback).
  - `Settings.CountedByProfileReset(row) -> boolean` (the rows a profile reset counts: not global, not a member row).
  - `NS.SchemaRuntime.Set("<kind>.<field>", value[, id])` writes a member field; a refusal answers `false, err, why` with `why` the reason text below; no member to address answers `false, "<No … to edit …>"`.
  - The group-row refusal text for a built-in: `L["Built-in groups are read-only. Customize makes an editable copy."]`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_members.lua`:
```lua
-- tests/test_members.lua — the member rows (architecture-§5, settings/SchemaMembers.lua). Every field a
-- player sets on a callout, a group, a Comms Pad or a built-in set goes through the one seam, addressed
-- by an instance argument, by the member its editor page has selected (NS.State.editing), or by the
-- first member that page lists. Library keeps membership and announces every field write; the pads
-- pick a write up through Surfaces.Request, queued in combat.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function heard(NS)
    local out = {}
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.LIBRARY_CHANGED, function(_, kind, id) out[#out + 1] = tostring(kind) .. ":" .. tostring(id) end)
    return out
end

local function boot()
    local NS = T.bootAddon()
    return NS, NS.SchemaRuntime, NS.Library
end

test("members: a callout field is written through the seam by instance id, and announced once", function()
    local NS, S, Lib = boot()
    local cid = Lib.CreateCallout({ name = "Lust", text = "Lust", channel = "party" })
    local out = heard(NS)
    assertTrue(S.Set("callout.text", "Lust now {rt8}", cid))
    assertEqual(NS.db.profile.callouts[cid].text, "Lust now {rt8}")
    assertEqual(S.Get("callout.text", cid), "Lust now {rt8}")
    -- red under: drop the onChange loop at the end of settings/SchemaMembers.lua
    assertEqual(table.concat(out, ","), "callout:" .. cid)
end)

test("members: with no id the seam writes the selected member, else the first the page lists, else refuses", function()
    local NS, S, Lib = boot()
    local ok, err = S.Set("callout.name", "Other")
    assertFalse(ok)
    assertTrue(tostring(err):find("No callout to edit", 1, true) ~= nil, tostring(err))
    local b = Lib.CreateCallout({ name = "Beta", text = "b", channel = "party" })
    local a = Lib.CreateCallout({ name = "Alpha", text = "a", channel = "party" })
    -- red under: drop the Library.MemberIds fallback from Settings.EditingId (nothing selected is a refusal)
    assertTrue(S.Set("callout.text", "first"))
    assertEqual(NS.db.profile.callouts[a].text, "first", "the first callout the page lists, by name")
    NS.State.editing.callout = b
    assertTrue(S.Set("callout.name", "Hero"))
    assertEqual(NS.db.profile.callouts[b].name, "Hero")
    assertEqual(S.Get("callout.name"), "Hero")
    NS.State.editing.callout = "c999"   -- a stale selection falls back too; nothing lands on it
    assertTrue(S.Set("callout.text", "again"))
    assertEqual(NS.db.profile.callouts[a].text, "again")
    assertNil(NS.db.profile.callouts.c999)
    assertNil(NS.addon.Settings.EditingId("builtin"), "a built-in overlay is never a fallback")
end)

test("members: [review 5] a bad name or channel is refused with its reason and stores nothing", function()
    local NS, S, Lib = boot()
    local cid = Lib.CreateCallout({ name = "Lust", text = "Lust", channel = "party" })
    local ok, _, why = S.Set("callout.name", "", cid)
    assertFalse(ok)
    assertEqual(why, "A name is 1 to 32 characters.")
    assertFalse((S.Set("callout.name", string.rep("x", 33), cid)))
    ok, _, why = S.Set("callout.channel", "guild", cid)
    assertFalse(ok)
    assertEqual(why, "That is not a channel Quick Comms sends on.")
    local c = NS.db.profile.callouts[cid]
    assertEqual(c.name, "Lust")
    assertEqual(c.channel, "party")
end)

test("members: an icon typed as digits is stored as a texture id; empty text clears it", function()
    local NS, S, Lib = boot()
    local cid = Lib.CreateCallout({ name = "Lust", text = "Lust", channel = "party" })
    assertTrue(S.Set("callout.icon", "136012", cid))
    assertEqual(NS.db.profile.callouts[cid].icon, 136012)
    assertTrue(S.Set("callout.icon", "Interface\\Icons\\Spell_Nature_Bloodlust", cid))
    assertEqual(NS.db.profile.callouts[cid].icon, "Interface\\Icons\\Spell_Nature_Bloodlust")
    assertTrue(S.Set("callout.icon", "", cid))
    assertTrue(NS.db.profile.callouts[cid].icon == false)
end)

test("members: [review 4] a built-in group's fields read, and every write to them is refused", function()
    local NS, S = boot()
    NS.State.editing.group = "bi.mplus"
    assertEqual(S.Get("group.name"), NS.BuiltIns.groups["bi.mplus"].name)
    local ok, _, why = S.Set("group.name", "Mine")
    assertFalse(ok)
    -- red under: drop the built-in refusal from the group rows' validate
    assertEqual(why, "Built-in groups are read-only. Customize makes an editable copy.")
    assertFalse((S.Set("group.enabled", false, "bi.mplus")))
    assertFalse((S.Set("group.when", { content = { raid = true } }, "bi.mplus")))
    assertEqual(NS.BuiltIns.groups["bi.mplus"].name, "M+ (generic)")
    assertTrue(NS.BuiltIns.groups["bi.mplus"].when.content.mythicPlus)
    local o = NS.db.profile.builtins["bi.mplus"]
    assertTrue(o == nil or o.enabled ~= false, "the overlay is untouched")
end)

test("members: a group's When is one structured row: a valid When stores, a bad one is refused", function()
    local NS, S, Lib = boot()
    local gid = Lib.CreateGroup({ name = "Mine" })
    assertTrue(S.Set("group.when", { content = { mythicPlus = true }, keyLevel = { min = 10 } }, gid))
    assertTrue(NS.db.profile.groups[gid].when.content.mythicPlus)
    local ok, _, why = S.Set("group.when", { keyLevel = { min = 12, max = 10 } }, gid)
    assertFalse(ok)
    assertEqual(why, "The lowest key level is above the highest.")
    assertFalse((S.Set("group.when", { combat = { yes = true } }, gid)))
    assertEqual(NS.db.profile.groups[gid].when.keyLevel.min, 10)
end)

test("members: member rows are not AceDB defaults, and each resolves against its template", function()
    local NS = T.bootAddon()
    local d = NS.addon.Settings.BuildDefaults()
    -- red under: drop `not def.instance` from Settings.BuildDefaults
    assertNil(d.profile.callout)
    assertNil(d.profile.pad)
    assertNil(d.profile.group)
    assertNil(d.profile.builtin)
    -- red under: drop the instance branch from the validation's defaultsRoot
    assertEqual(NS.addon.Settings.Helpers.ValidateSchema(), 0)
end)
```
In `tests/test_schema.lua`, replace the case `"schema: a page's rows are the rows whose page is its key"` with:
```lua
test("schema: a page's rows are the rows whose page is its key", function()
    local NS = T.newAddon()
    local Settings = NS.addon.Settings
    local general = Settings.RowsForPage("general")
    assertTrue(#general > 0)
    for _, row in ipairs(general) do assertEqual(row.page, "general") end
    assertTrue(#Settings.RowsForPage("callouts") > 0, "the member rows draw on their own pages")
    assertEqual(#Settings.RowsForPage("nope"), 0)
end)
```
and append:
```lua
test("schema: [phase 3] a fresh profile has no row off its default; the member rows are not counted", function()
    local NS = T.bootAddon()
    local Settings = NS.addon.Settings
    -- red under: drop `and not row.instance` from Settings.CountedByProfileReset (the member rows count)
    assertEqual(NS.SchemaRuntime.CountOffDefault(Settings.CountedByProfileReset), 0)
end)
```
In `tests/test_setup.lua`, in the case `"options: the degraded load completes, and the panel says once that it is unavailable"`, replace
```lua
    assertTrue(#D.addon.Settings.Schema == 0, "the composers are hollow ({}), never a host copy")
```
with
```lua
    -- The composers are hollow ({}), never a host copy: the degraded schema holds the member rows
    -- (settings/SchemaMembers.lua, which Library's writers need on every load) and nothing else.
    assertTrue(#D.addon.Settings.Schema > 0, "the member rows")
    for _, row in ipairs(D.addon.Settings.Schema) do
        -- red under: a composed or hand-written page row added on the degraded load
        assertTrue(row.instance ~= nil, "only member rows: " .. tostring(row.path))
    end
```
In `tests/run.lua`, add `"test_members",` after `"test_library",`.

- [ ] **Step 2: Run the tests to check they fail**

Run: `lua tests/run.lua`
Expected: FAIL (no `callout.*` rows: `Setting not found`; `NS.State.editing` is nil; `Settings.CountedByProfileReset` is nil).

- [ ] **Step 3: The selection**

In `core/State.lua`, append:
```lua

-- The member each editor page has selected (settings/Editors.lua): { callout, group, pad, builtin }.
-- A member row written with no instance argument writes this member, else the first member its page
-- lists (settings/Schema.lua Settings.EditingId).
State.editing = {}
```

- [ ] **Step 4: The seam addresses a member**

In `settings/Schema.lua`, directly above `-- ── the write seam`, add:
```lua
-- ── members (architecture-§5) ───────────────────────────────────────────────────────────────

-- A member's own fields are rows whose path starts with the member's kind (settings/SchemaMembers.lua).
-- The seam addresses the member by the instance argument or, without one, by Settings.EditingId: the
-- member that kind's editor page has selected, else the first member that page lists, so the panel's
-- widgets and the CLI write the member the page shows (or would show when opened); the drag and
-- Library's built-in writers name theirs. Library resolves the id. With no member to address (none
-- of that kind exists, or a named id is gone) there is no root, and the write is refused with a line
-- saying where to make one.
local INSTANCE = { callout = true, group = true, pad = true, builtin = true }
Settings.INSTANCE_KINDS = INSTANCE

local NO_MEMBER = {
    callout = L["No callout to edit: make one on the Callouts page."],
    group   = L["No group to edit: make one on the Groups page."],
    pad     = L["No pad to edit: make one on the Comms Pad page."],
    builtin = L["No built-in set is selected: pick one on the Groups page."],
}

--- The member a kind's rows address when a write names none: the page's selection while it exists,
--- else the first member the page lists (Library.MemberIds). A built-in set's overlay has no
--- fallback: it is only ever the set the Groups page shows.
--- @return string|nil
function Settings.EditingId(kind)
    local id = NS.State.editing[kind]
    if id ~= nil and NS.Library.Member(kind, id) then return id end
    if kind == "builtin" then return nil end
    return NS.Library.MemberIds(kind)[1]
end

local function resolveRoot(parts, id)
    local kind = parts and parts[1]
    if INSTANCE[kind] then
        if not QC.db then return nil, NO_MEMBER[kind] end
        if id == nil then id = Settings.EditingId(kind) end
        local member = id ~= nil and NS.Library.Member(kind, id) or nil
        if member then return member, 2, id end
        return nil, NO_MEMBER[kind]
    end
    return QC.db and QC.db.profile, 1
end
```
In the `Settings.SchemaLib:New{ … }` call, replace
```lua
    resolveRoot  = function() return QC.db and QC.db.profile, 1 end,
```
with
```lua
    resolveRoot  = resolveRoot,
```
Replace `local VALID_TYPES = { bool = true, number = true, string = true }` with:
```lua
-- `point`, `when` and `idset` are the structured member rows (settings/SchemaMembers.lua): a table
-- each, drawn by their own controls on the editor pages and typed and printed on the CLI by
-- settings/Slash.lua's parse and format hooks.
local VALID_TYPES = { bool = true, number = true, string = true, point = true, when = true, idset = true }
```
In `defaultsRootFor`, add the member branch after the get/set branch:
```lua
local function defaultsRootFor(profileDefaults)
    return function(_, row)
        if row and type(row.get) == "function" and type(row.set) == "function" then return nil end
        -- A member row resolves against its kind's template, from the segment after the kind.
        if row and row.instance then return NS.Library.TEMPLATES[row.instance], 2 end
        return profileDefaults, 1
    end
end
```
In `Settings.BuildDefaults`, change the row loop's condition to:
```lua
        if def.path and not def.sessionOnly and not GLOBAL[def.path] and not def.instance then
```
and add one sentence to its doc comment: "A member row (`instance`) is no default: its member's fields are written whole when Library creates it."

Replace
```lua
local function notGlobal(row) return not GLOBAL[row.path] end
```
with
```lua
-- The rows a profile reset counts (debug-logging-§10's N): not a global row, and not a member row,
-- which addresses whichever member is selected and has no profile default of its own.
local function notGlobal(row) return not GLOBAL[row.path] and not row.instance end
Settings.CountedByProfileReset = notGlobal
```

- [ ] **Step 5: The member rows**

Create `settings/SchemaMembers.lua`:
```lua
local _, NS = ...
-- settings/SchemaMembers.lua — the member rows (architecture-§5): every field a player sets on a
-- callout, a group, a Comms Pad or a built-in set's overlay is a schema row whose path starts with
-- the member's kind. settings/Schema.lua resolves the member from the instance argument, or from the
-- one its editor page has selected (NS.State.editing), so the panel, the CLI, the pad's drag and
-- Library's own built-in writers all write through NS.SchemaRuntime.Set. modules/Library.lua keeps
-- what is not a field: membership (create, delete, duplicate, Customize), the order of every list,
-- the references a group and a surface hold, the ids and the seeding. Each row's onChange hands the
-- write to Library.Touch, which sends LIBRARY_CHANGED, so the pads rebuild (in combat, at combat
-- end, with the stale hint), naming the field so the editor pages repaint only when what they draw
-- changes shape. Paths resolve against Library.TEMPLATES at the boot check; member rows are no AceDB
-- default. Three rows hold a table (a pad's point, a group's When, a set's hidden callouts): their
-- pages draw their own controls, and settings/Slash.lua's parse and format hooks type and print them
-- on the command line. Added on every load, the degraded one included: Library's writers need them
-- (tests/test_setup.lua pins that a degraded load's schema holds these rows and nothing else).

local L   = NS.L
local Lib = NS.Library
local T   = Lib.TEMPLATES

local GENERAL = L["General"]

-- A Library validator's reason code, as the line the seam hands back as its `why`.
local WHY = {
    badName   = L["A name is 1 to 32 characters."],
    badText   = L["Callout text must be text."],
    badChannel = L["That is not a channel Quick Comms sends on."],
    badIcon   = L["An icon is a texture id or a texture path."],
    badPoint  = L["A position is two anchor points and two numbers."],
    badWhen   = L["That condition is not one Quick Comms knows."],
    badRange  = L["The lowest key level is above the highest."],
    badHidden = L["Only this set's own callouts can be hidden."],
    builtin   = L["Built-in groups are read-only. Customize makes an editable copy."],
    badChoice = L["That is not one of the choices."],
}

local function check(fn)
    return function(v, id)
        local ok, code = fn(v, id)
        if ok then return true end
        return false, WHY[code] or tostring(code)
    end
end

-- Built-ins are read-only (spec §12.2): every group row refuses a built-in id, whatever the value.
local function userGroup(inner)
    return check(function(v, id)
        if Lib.IsBuiltin(id) then return false, "builtin" end
        if inner then return inner(v, id) end
        return true
    end)
end

local function oneOf(list)
    local set = {}
    for _, item in ipairs(list) do set[item.value] = true end
    return check(function(v) return set[v] == true, "badChoice" end)
end

local function isNumber(v) return type(v) == "number" and v == v end
local function clamp(lo, hi, whole)
    return function(v)
        v = math.max(lo, math.min(hi, v))
        if whole then v = math.floor(v + 0.5) end
        return v
    end
end
local NUMBER = check(function(v) return isNumber(v), "badChoice" end)

-- An icon typed into a text box: digits are a texture id, nothing is "no icon" (false, a value the
-- seam stores; nil would be a refusal), anything else a texture path.
local function iconValue(v)
    if type(v) ~= "string" then return v end
    local trimmed = v:match("^%s*(.-)%s*$")
    if trimmed == "" then return false end
    return tonumber(trimmed:match("^(%d+)$")) or trimmed
end

local function isText(v) return type(v) == "string", "badText" end

local CHANNEL_LABEL = {
    smartGroup = L["Smart group (instance, raid or party)"],
    smartLead = L["Smart lead (raid warning when you can)"],
    party = L["Party"], raid = L["Raid"], instance = L["Instance"], raidWarning = L["Raid warning"],
    say = L["Say"], yell = L["Yell"],
}
local CHANNELS = {}
for i, kind in ipairs(NS.Channels.KINDS) do CHANNELS[i] = { value = kind, text = CHANNEL_LABEL[kind] or kind } end

local function choices(pairsList)
    local out = {}
    for i, p in ipairs(pairsList) do out[i] = { value = p[1], text = p[2] } end
    return out
end

local GROUPS_AS = choices({ { "sections", L["Sections"] }, { "merged", L["One list"] }, { "tabs", L["Tabs (the mouse wheel switches)"] } })
local ORIENTATION = choices({ { "horizontal", L["Horizontal"] }, { "vertical", L["Vertical"] }, { "grid", L["Grid"] } })
local GROWTH = choices({ { "right", L["Right and down"] }, { "left", L["Left and down"] }, { "up", L["Upward"] } })
local STYLE = choices({ { "iconLabel", L["Icon and label"] }, { "icon", L["Icon only"] }, { "label", L["Label only"] } })
local VISIBILITY = choices({ { "always", L["Always"] }, { "inCombat", L["Only in combat"] },
    { "outOfCombat", L["Only out of combat"] }, { "whenActive", L["When a group is active"] }, { "never", L["Never"] } })
local FADE = choices({ { "none", L["Never"] }, { "outOfCombat", L["Out of combat"] }, { "mouseover", L["Until the mouse is over it"] } })

local ROWS = {
    -- Callouts page (spec §13.1). Name and text have no default: a reset never blanks them.
    { path = "callout.name", instance = "callout", type = "string", dialogControl = "EditBox",
      maxLetters = Lib.NAME_MAX, page = "callouts", group = GENERAL, label = L["Name"],
      desc = L["What the chip and the lists call this callout. Press Enter to apply."],
      validate = check(Lib.ValidName) },
    { path = "callout.text", instance = "callout", type = "string", dialogControl = "EditBox",
      maxLetters = 255, page = "callouts", group = GENERAL, label = L["Text"],
      desc = L["What is sent. Tokens in braces are filled in: {target}, {focus}, {skull}, {me}, {spec}, {key}, {dungeon}, {spell:ID}; in a raid, {group1} to {group8}. Press Enter to apply."],
      validate = check(isText) },
    { path = "callout.channel", instance = "callout", type = "string", default = T.callout.channel,
      values = CHANNELS, page = "callouts", group = GENERAL, label = L["Channel"],
      desc = L["Where it is sent. Smart group picks instance, raid or party chat for the group you are in when the pad is built."],
      validate = check(function(v) return NS.Channels.IsKind(v), "badChannel" end) },
    { path = "callout.icon", instance = "callout", type = "string", dialogControl = "EditBox",
      page = "callouts", group = GENERAL, label = L["Icon"],
      desc = L["A texture id (a number) or a texture path (a LibKa0s icon by its path). Leave it empty for the default icon. Press Enter to apply."],
      normalize = iconValue, validate = check(function(v) return type(v) == "string", "badIcon" end) },

    -- Groups page (spec §13.1, §13.2).
    { path = "group.name", instance = "group", type = "string", dialogControl = "EditBox",
      maxLetters = Lib.NAME_MAX, page = "groups", group = GENERAL, label = L["Name"],
      desc = L["What the pad's section and the lists call this group. Press Enter to apply."],
      validate = userGroup(Lib.ValidName) },
    { path = "group.icon", instance = "group", type = "string", dialogControl = "EditBox",
      page = "groups", group = GENERAL, label = L["Icon"],
      desc = L["A texture id (a number) or a texture path (a LibKa0s icon by its path). Leave it empty for the default icon. Press Enter to apply."],
      normalize = iconValue, validate = userGroup(function(v) return type(v) == "string", "badIcon" end) },
    { path = "group.enabled", instance = "group", type = "bool", default = T.group.enabled,
      page = "groups", group = GENERAL, label = L["Enabled"],
      desc = L["Show this group wherever its When matches. Off keeps the group and its place on every pad."],
      validate = userGroup() },
    { path = "group.openInto", instance = "group", type = "bool", default = T.group.openInto,
      page = "groups", group = GENERAL, label = L["Open the dial on this group"],
      desc = L["When this is the first active group on a Comms Dial, the dial opens on its callouts. The Comms Dial arrives in a later build."],
      validate = userGroup() },
    { path = "group.when", instance = "group", type = "when",
      page = "groups", group = L["When"], label = L["When"],
      desc = L["The conditions under which this group is active. Every condition you turn on must match; within a condition, any value may."],
      validate = userGroup(Lib.ValidWhen) },

    -- Comms Pad page (spec §10.2, §10.3, §13.1).
    { path = "pad.name", instance = "pad", type = "string", dialogControl = "EditBox", maxLetters = Lib.NAME_MAX,
      page = "pads", group = GENERAL, label = L["Name"],
      desc = L["What the drag strip and the lists call this pad. Press Enter to apply."],
      validate = check(Lib.ValidName) },
    { path = "pad.enabled", instance = "pad", type = "bool", default = T.pad.enabled,
      page = "pads", group = GENERAL, label = L["Enabled"],
      desc = L["Draw this pad. A disabled pad keeps its groups and its settings."] },
    { path = "pad.groupsAs", instance = "pad", type = "string", default = T.pad.groupsAs, values = GROUPS_AS,
      page = "pads", group = L["Groups"], label = L["Show groups as"],
      desc = L["Sections under small headings, one merged list, or one group at a time (the mouse wheel over the pad switches; not in combat)."],
      validate = oneOf(GROUPS_AS) },
    { path = "pad.layout.orientation", instance = "pad", type = "string", default = T.pad.layout.orientation,
      values = ORIENTATION, page = "pads", group = L["Layout"], label = L["Orientation"],
      desc = L["One row, one column, or a grid."], validate = oneOf(ORIENTATION) },
    { path = "pad.layout.columns", instance = "pad", type = "number", default = T.pad.layout.columns,
      min = 1, max = 12, step = 1, page = "pads", group = L["Layout"], label = L["Grid columns"],
      desc = L["Chips per row when the orientation is Grid."],
      validate = NUMBER, normalize = clamp(1, 12, true) },
    { path = "pad.layout.growth", instance = "pad", type = "string", default = T.pad.layout.growth,
      values = GROWTH, page = "pads", group = L["Layout"], label = L["Growth"],
      desc = L["Which way the chips fill from the pad's anchor."], validate = oneOf(GROWTH) },
    { path = "pad.layout.style", instance = "pad", type = "string", default = T.pad.layout.style,
      values = STYLE, page = "pads", group = L["Layout"], label = L["Chip style"],
      desc = L["Icon only puts the callout's name in its tooltip."], validate = oneOf(STYLE) },
    { path = "pad.layout.scale", instance = "pad", type = "number", default = T.pad.layout.scale,
      min = 0.5, max = 2, step = 0.05, page = "pads", group = L["Layout"], label = L["Scale"],
      desc = L["This pad's size, on top of the master scale."],
      validate = NUMBER, normalize = clamp(0.5, 2) },
    { path = "pad.layout.spacing", instance = "pad", type = "number", default = T.pad.layout.spacing,
      min = 0, max = 20, step = 1, page = "pads", group = L["Layout"], label = L["Spacing"],
      desc = L["Pixels between chips."], validate = NUMBER, normalize = clamp(0, 20, true) },
    { path = "pad.layout.width", instance = "pad", type = "number", default = T.pad.layout.width,
      min = 120, max = 300, step = 10, page = "pads", group = L["Layout"], label = L["Chip width"],
      desc = L["How wide a labeled chip is."], validate = NUMBER, normalize = clamp(120, 300, true) },
    { path = "pad.point", instance = "pad", type = "point",
      page = "pads", group = L["Layout"], label = L["Position"],
      desc = L["Where the pad sits. Drag it while unlocked, or type an offset."],
      validate = check(Lib.ValidPoint) },
    { path = "pad.look.visibility", instance = "pad", type = "string", default = T.pad.look.visibility,
      values = VISIBILITY, page = "pads", group = L["Look"], label = L["Visibility"],
      desc = L["When this pad shows. General visibility applies on top. When a group is active is decided at the last change out of combat."],
      validate = oneOf(VISIBILITY) },
    { path = "pad.look.fade", instance = "pad", type = "string", default = T.pad.look.fade,
      values = FADE, page = "pads", group = L["Look"], label = L["Fade"],
      desc = L["Fade the pad out of combat, or until the mouse is over it."],
      validate = oneOf(FADE) },
    { path = "pad.look.fadeAlpha", instance = "pad", type = "number", default = T.pad.look.fadeAlpha,
      min = 0, max = 1, step = 0.05, page = "pads", group = L["Look"], label = L["Faded alpha"],
      desc = L["How visible a faded pad is."], validate = NUMBER, normalize = clamp(0, 1) },

    -- A built-in set's overlay (spec §12.2): the only writable part of a shipped set.
    { path = "builtin.enabled", instance = "builtin", type = "bool", default = T.builtin.enabled,
      page = "share", group = L["Built-in"], label = L["Enabled"],
      desc = L["Show this built-in set wherever it matches. Off keeps it, and its place on every pad."] },
    { path = "builtin.hidden", instance = "builtin", type = "idset",
      page = "share", group = L["Built-in"], label = L["Hidden callouts"],
      desc = L["The set's callouts that no pad shows."],
      validate = check(function(v, id) return Lib.ValidHidden(Lib.TopOf(id), v) end) },
}

-- Every member row's reaction: Library.Touch announces the write (LIBRARY_CHANGED, the pads' rebuild),
-- naming the row's path as the field.
for _, row in ipairs(ROWS) do
    local kind, path = row.instance, row.path
    row.onChange = function(_, id) Lib.Touch(kind, id, path) end
end

NS.SchemaRuntime.AddRows(ROWS)
```

In `QuickComms.toc`, after the `settings\SchemaRows.lua` entry, add:
```
# LOAD-BEARING: reads NS.Library.TEMPLATES, NS.Channels.KINDS and NS.SchemaRuntime.AddRows at file scope.
settings\SchemaMembers.lua
```
In `settings/SchemaRows.lua`, replace the comment
```lua
-- On a load where the Options composers are hollow (LibKa0s absent) the schema stays empty
-- (settings/Panel.lua adds no rows either); the Behavior rows are drawn by that library.
```
with
```lua
-- On a load where the Options composers are hollow (LibKa0s absent) this file and settings/Panel.lua
-- add no rows; the Behavior rows are drawn by that library. The schema then holds only the member
-- rows (settings/SchemaMembers.lua), which Library's writers need on every load.
```

- [ ] **Step 6: Locale keys**

In `locales/enUS.lua`, under a new comment `-- Member rows (settings/SchemaMembers.lua, settings/Schema.lua)`:
```lua
L["No callout to edit: make one on the Callouts page."] = "No callout to edit: make one on the Callouts page."
L["No group to edit: make one on the Groups page."] = "No group to edit: make one on the Groups page."
L["No pad to edit: make one on the Comms Pad page."] = "No pad to edit: make one on the Comms Pad page."
L["No built-in set is selected: pick one on the Groups page."] = "No built-in set is selected: pick one on the Groups page."
L["A name is 1 to 32 characters."] = "A name is 1 to 32 characters."
L["Callout text must be text."] = "Callout text must be text."
L["That is not a channel Quick Comms sends on."] = "That is not a channel Quick Comms sends on."
L["An icon is a texture id or a texture path."] = "An icon is a texture id or a texture path."
L["A position is two anchor points and two numbers."] = "A position is two anchor points and two numbers."
L["That condition is not one Quick Comms knows."] = "That condition is not one Quick Comms knows."
L["The lowest key level is above the highest."] = "The lowest key level is above the highest."
L["Only this set's own callouts can be hidden."] = "Only this set's own callouts can be hidden."
L["Built-in groups are read-only. Customize makes an editable copy."] = "Built-in groups are read-only. Customize makes an editable copy."
L["That is not one of the choices."] = "That is not one of the choices."
L["Smart group (instance, raid or party)"] = "Smart group (instance, raid or party)"
L["Smart lead (raid warning when you can)"] = "Smart lead (raid warning when you can)"
L["Party"] = "Party"
L["Raid warning"] = "Raid warning"
L["Say"] = "Say"
L["Yell"] = "Yell"
L["Sections"] = "Sections"
L["One list"] = "One list"
L["Tabs (the mouse wheel switches)"] = "Tabs (the mouse wheel switches)"
L["Horizontal"] = "Horizontal"
L["Vertical"] = "Vertical"
L["Grid"] = "Grid"
L["Right and down"] = "Right and down"
L["Left and down"] = "Left and down"
L["Upward"] = "Upward"
L["Icon and label"] = "Icon and label"
L["Icon only"] = "Icon only"
L["Label only"] = "Label only"
L["Always"] = "Always"
L["Only in combat"] = "Only in combat"
L["Only out of combat"] = "Only out of combat"
L["When a group is active"] = "When a group is active"
L["Never"] = "Never"
L["Out of combat"] = "Out of combat"
L["Until the mouse is over it"] = "Until the mouse is over it"
L["Name"] = "Name"
L["What the chip and the lists call this callout. Press Enter to apply."] = "What the chip and the lists call this callout. Press Enter to apply."
L["Text"] = "Text"
L["What is sent. Tokens in braces are filled in: {target}, {focus}, {skull}, {me}, {spec}, {key}, {dungeon}, {spell:ID}; in a raid, {group1} to {group8}. Press Enter to apply."] = "What is sent. Tokens in braces are filled in: {target}, {focus}, {skull}, {me}, {spec}, {key}, {dungeon}, {spell:ID}; in a raid, {group1} to {group8}. Press Enter to apply."
L["Channel"] = "Channel"
L["Where it is sent. Smart group picks instance, raid or party chat for the group you are in when the pad is built."] = "Where it is sent. Smart group picks instance, raid or party chat for the group you are in when the pad is built."
L["Icon"] = "Icon"
L["A texture id (a number) or a texture path (a LibKa0s icon by its path). Leave it empty for the default icon. Press Enter to apply."] = "A texture id (a number) or a texture path (a LibKa0s icon by its path). Leave it empty for the default icon. Press Enter to apply."
L["What the pad's section and the lists call this group. Press Enter to apply."] = "What the pad's section and the lists call this group. Press Enter to apply."
L["Enabled"] = "Enabled"
L["Show this group wherever its When matches. Off keeps the group and its place on every pad."] = "Show this group wherever its When matches. Off keeps the group and its place on every pad."
L["Open the dial on this group"] = "Open the dial on this group"
L["When this is the first active group on a Comms Dial, the dial opens on its callouts. The Comms Dial arrives in a later build."] = "When this is the first active group on a Comms Dial, the dial opens on its callouts. The Comms Dial arrives in a later build."
L["When"] = "When"
L["The conditions under which this group is active. Every condition you turn on must match; within a condition, any value may."] = "The conditions under which this group is active. Every condition you turn on must match; within a condition, any value may."
L["What the drag strip and the lists call this pad. Press Enter to apply."] = "What the drag strip and the lists call this pad. Press Enter to apply."
L["Draw this pad. A disabled pad keeps its groups and its settings."] = "Draw this pad. A disabled pad keeps its groups and its settings."
L["Groups"] = "Groups"
L["Show groups as"] = "Show groups as"
L["Sections under small headings, one merged list, or one group at a time (the mouse wheel over the pad switches; not in combat)."] = "Sections under small headings, one merged list, or one group at a time (the mouse wheel over the pad switches; not in combat)."
L["Layout"] = "Layout"
L["Orientation"] = "Orientation"
L["One row, one column, or a grid."] = "One row, one column, or a grid."
L["Grid columns"] = "Grid columns"
L["Chips per row when the orientation is Grid."] = "Chips per row when the orientation is Grid."
L["Growth"] = "Growth"
L["Which way the chips fill from the pad's anchor."] = "Which way the chips fill from the pad's anchor."
L["Chip style"] = "Chip style"
L["Icon only puts the callout's name in its tooltip."] = "Icon only puts the callout's name in its tooltip."
L["Scale"] = "Scale"
L["This pad's size, on top of the master scale."] = "This pad's size, on top of the master scale."
L["Spacing"] = "Spacing"
L["Pixels between chips."] = "Pixels between chips."
L["Chip width"] = "Chip width"
L["How wide a labeled chip is."] = "How wide a labeled chip is."
L["Position"] = "Position"
L["Where the pad sits. Drag it while unlocked, or type an offset."] = "Where the pad sits. Drag it while unlocked, or type an offset."
L["Look"] = "Look"
L["Visibility"] = "Visibility"
L["When this pad shows. General visibility applies on top. When a group is active is decided at the last change out of combat."] = "When this pad shows. General visibility applies on top. When a group is active is decided at the last change out of combat."
L["Fade"] = "Fade"
L["Fade the pad out of combat, or until the mouse is over it."] = "Fade the pad out of combat, or until the mouse is over it."
L["Faded alpha"] = "Faded alpha"
L["How visible a faded pad is."] = "How visible a faded pad is."
L["Built-in"] = "Built-in"
L["Show this built-in set wherever it matches. Off keeps it, and its place on every pad."] = "Show this built-in set wherever it matches. Off keeps it, and its place on every pad."
L["Hidden callouts"] = "Hidden callouts"
L["The set's callouts that no pad shows."] = "The set's callouts that no pad shows."
```

- [ ] **Step 7: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS. In particular: `test_schema`'s "every row validates against the defaults" (member rows resolve against their templates) and the new count case, `test_setup`'s degraded case (member rows only), and every `test_library` case (Library's writers are unchanged until Task 3b).

- [ ] **Step 8: Commit**

```bash
git add core/State.lua settings/SchemaMembers.lua settings/Schema.lua settings/SchemaRows.lua QuickComms.toc tests/test_members.lua tests/test_schema.lua tests/test_setup.lua tests/run.lua locales/enUS.lua
git checkout -- core/State.lua settings/SchemaMembers.lua settings/Schema.lua settings/SchemaRows.lua QuickComms.toc tests/test_members.lua tests/test_schema.lua tests/test_setup.lua tests/run.lua locales/enUS.lua
git commit -m "Settings: every member field is a schema row written through the one seam"
```

---
### Task 3b: Library's field writers through the seam, and the structured rows on the CLI

Library's own field writers (`SetBuiltinEnabled`, `SetBuiltinCalloutHidden`, Customize's turning the set off, `SetSurfacePoint` for a pad) keep their names and go through Task 3a's rows, so a member field has one writer. The three table-valued rows (`pad.point`, `group.when`, `builtin.hidden`) are typed and printed on the CLI through the Slash descriptor's `parse` and `format` hooks (slash-commands-§6; `libs/LibKa0s/Slash.lua` lines 407-415), which switch on `row.type` and hand every other row back to the library, so every member row is listed, read and written from `/qc` (architecture-§5) and no deviation is needed.

**Files:**
- Modify: `modules/Library.lua` (`SetBuiltinEnabled`, `SetBuiltinCalloutHidden`, `Customize`, `SetSurfacePoint` through the seam)
- Modify: `modules/Pad.lua` (two comments: the point is now a member row; publish `Pad.DEFAULT_POINT`)
- Modify: `settings/Slash.lua` (the descriptor's `parse` and `format`)
- Test: `tests/test_members.lua` (append)
- Modify: `locales/enUS.lua`

**Interfaces:**
- Consumes: Task 3a's rows and `Settings.EditingId`; `lib.ParseValue(row, text, textOf)`, `lib.FormatValue(row, value)`; `NS.Resolver.ROWS`.
- Produces:
  - `NS.Pad.DEFAULT_POINT` (read only).
  - The CLI forms: `pad.point` takes `x y` (keeps the pad's anchor points; the default place's when it has none) or `POINT RELATIVEPOINT x y`; `group.when` takes `<condition> <value>[,<value>…]` (replaces that condition; the condition alone clears it; `keyLevel` takes `min-max`, either end empty, or one level); `builtin.hidden` takes callout ids or `none`. `get` and `list` print `pad.point` as `POINT RELATIVEPOINT x y` (or "the default place"), `group.when` as `content=mythicPlus,raid; keyLevel=10..any` (or "always"), `builtin.hidden` as its ids (or "none"), and a member row with no member to address as "(nothing to edit)".

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_members.lua`:
```lua
local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function combat(m, on)
    if on then
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_DISABLED")
        m.__setCombat(true)
    else
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_ENABLED")
    end
end

test("members: [review 4] the CLI prints the built-in refusal", function()
    local NS, m = T.enableAddon()
    NS.State.editing.group = "bi.mplus"
    m.prints = {}
    NS.addon:OnSlashCommand("set group.name Mine")
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("Built-in groups are read-only", 1, true) ~= nil, text)
end)

test("members: Library's built-in writers and the pad point go through the seam, one announce each", function()
    local NS, S, Lib = boot()
    local out = heard(NS)
    assertTrue(Lib.SetBuiltinEnabled("bi.raid", false))
    assertFalse(NS.db.profile.builtins["bi.raid"].enabled)
    assertTrue(Lib.SetBuiltinCalloutHidden("bi.bg.ab.stables", "bi.bg.ab.stables.inc1", true))
    assertTrue(NS.db.profile.builtins["bi.bg.ab"].hidden["bi.bg.ab.stables.inc1"])
    assertTrue(Lib.SetSurfacePoint("pad", "p1", { "TOPLEFT", "TOPLEFT", 4, -4 }))
    assertEqual(table.concat(out, ","), "builtin:bi.raid,builtin:bi.bg.ab,pad:p1")
    -- a set's hidden list holds only its own callouts
    assertFalse((S.Set("builtin.hidden", { ["bi.mplus.lust"] = true }, "bi.raid")))
    -- Each writer reaches the seam, by path and instance argument.
    local paths = {}
    local set = S.Set
    S.Set = function(path, value, id)
        paths[#paths + 1] = path .. "@" .. tostring(id)
        return set(path, value, id)
    end
    Lib.SetBuiltinEnabled("bi.raid", true)
    Lib.SetBuiltinCalloutHidden("bi.bg.ab", "bi.bg.ab.stables.inc1", false)
    Lib.SetSurfacePoint("pad", "p1", nil)
    Lib.Customize("bi.arena")
    S.Set = set
    -- red under: assign the field directly in any of the four writers in modules/Library.lua
    assertEqual(table.concat(paths, ","),
        "builtin.enabled@bi.raid,builtin.hidden@bi.bg.ab,pad.point@p1,builtin.enabled@bi.arena")
end)

test("members: the structured rows are typed and printed on the CLI through the descriptor's parse and format", function()
    local NS, m = T.enableAddon()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.State.editing.group = gid
    NS.addon:OnSlashCommand("set group.when content mythicPlus,raid")
    -- red under: drop `parse` from the descriptor in settings/Slash.lua (the library refuses the type)
    assertTrue(NS.db.profile.groups[gid].when.content.mythicPlus)
    assertTrue(NS.db.profile.groups[gid].when.content.raid)
    NS.addon:OnSlashCommand("set group.when keyLevel 10-")
    assertEqual(NS.db.profile.groups[gid].when.keyLevel.min, 10)
    assertNil(NS.db.profile.groups[gid].when.keyLevel.max)
    m.prints = {}
    NS.addon:OnSlashCommand("get group.when")
    local text = table.concat(m.prints, "\n")
    -- red under: drop `format` from the descriptor (a table address prints)
    assertTrue(text:find("content=mythicPlus,raid; keyLevel=10..any", 1, true) ~= nil, text)
    NS.addon:OnSlashCommand("set group.when content")
    assertNil(NS.db.profile.groups[gid].when.content, "the condition alone clears it")
    m.prints = {}
    NS.addon:OnSlashCommand("set group.when keyLevel 12-10")
    text = table.concat(m.prints, "\n")
    assertTrue(text:find("The lowest key level is above the highest.", 1, true) ~= nil, text)
    NS.State.editing.pad = "p1"
    NS.addon:OnSlashCommand("set pad.point 40 -60")
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "CENTER,CENTER,40,-60")
    NS.addon:OnSlashCommand("set pad.point topleft topleft 5 -5")
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "TOPLEFT,TOPLEFT,5,-5")
    NS.addon:OnSlashCommand("set pad.point left")
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "TOPLEFT,TOPLEFT,5,-5", "refused: nothing stored")
    NS.State.editing.builtin = "bi.mplus"
    NS.addon:OnSlashCommand("set builtin.hidden bi.mplus.lust")
    assertTrue(NS.db.profile.builtins["bi.mplus"].hidden["bi.mplus.lust"])
    NS.addon:OnSlashCommand("set builtin.hidden none")
    assertTrue(next(NS.db.profile.builtins["bi.mplus"].hidden) == nil)
    NS.State.editing.builtin = nil
    m.prints = {}
    NS.addon:OnSlashCommand("list")
    text = table.concat(m.prints, "\n")
    assertTrue(text:find("table: ", 1, true) == nil, "no table address printed")
    assertTrue(text:find("pad.point", 1, true) ~= nil, "every member row is listed")
    -- red under: drop the "(nothing to edit)" branch from the descriptor's format (builtin.* print nil)
    assertTrue(text:find("(nothing to edit)", 1, true) ~= nil, text)
end)

test("members: [review 1] a callout edited from the CLI in combat waits for combat end, with the stale hint", function()
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    local Lib = NS.Library
    local cid = Lib.CreateCallout({ name = "Inc", text = "Incoming", channel = "party" })
    local gid = Lib.CreateGroup({ name = "Mine" })
    Lib.AddToGroup(gid, cid)
    Lib.AddGroupToSurface("pad", "p1", gid, 1)
    assertEqual(NS.Pad.ChipsFor("p1", cid)[1]:GetAttribute("macrotext"), "/p Incoming")
    NS.State.editing.callout = cid
    combat(m, true)
    NS.addon:OnSlashCommand("set callout.text Incoming {rt8}")
    assertEqual(NS.db.profile.callouts[cid].text, "Incoming {rt8}", "the write lands in combat")
    assertEqual(#m.blocked, 0, "no protected call")
    assertEqual(NS.Pad.ChipsFor("p1", cid)[1]:GetAttribute("macrotext"), "/p Incoming", "the chip keeps its line")
    assertTrue(NS.Pad.Instance("p1").header.qcStale:IsShown(), "the stale hint")
    combat(m, false)
    assertEqual(NS.Pad.ChipsFor("p1", cid)[1]:GetAttribute("macrotext"), "/p Incoming {rt8}")
    assertFalse(NS.Pad.Instance("p1").header.qcStale:IsShown())
    assertEqual(#m.blocked, 0)
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `lua tests/run.lua`
Expected: FAIL (Library's writers assign the fields directly; the library's parser answers `ERR_TYPE` for `when`, `point` and `idset`, and its formatter prints `table: 0x…`).

- [ ] **Step 3: Library's field writers through the seam**

In `modules/Library.lua`, replace `Lib.SetBuiltinEnabled` and `Lib.SetBuiltinCalloutHidden` with:
```lua
--- Turn a built-in set on or off: the `builtin.enabled` member row, through the seam.
function Lib.SetBuiltinEnabled(id, on)
    local top = topOf(id)
    if not top then return false end
    return (NS.SchemaRuntime.Set("builtin.enabled", on and true or false, top)) == true
end

--- Hide or show one of a built-in set's callouts: the whole `builtin.hidden` row, through the seam.
function Lib.SetBuiltinCalloutHidden(groupId, calloutId, hidden)
    local top = topOf(groupId)
    if not top then return false end
    local set = copyTable(overlay(top).hidden) or {}
    set[calloutId] = hidden and true or nil
    return (NS.SchemaRuntime.Set("builtin.hidden", set, top)) == true
end
```
In `Lib.Customize`, replace
```lua
    overlay(builtinId).enabled = false
```
with
```lua
    NS.SchemaRuntime.Set("builtin.enabled", false, builtinId)
```
Replace `Lib.SetSurfacePoint` with:
```lua
--- Set, or with nil clear, a surface's saved anchor (spec §5.1). A pad's is the `pad.point` member
--- row, through the seam: the drag, the X/Y boxes and Reset position all write it there. A dial's has
--- no row until the dial's page (phase 4) and stays Library's write. A plain copy is stored, so the
--- caller's table never aliases the profile.
--- @param point table|nil { point, relativePoint, x, y }: two strings, then two numbers
--- @return boolean
function Lib.SetSurfacePoint(kind, sid, point)
    if kind == "pad" then return (NS.SchemaRuntime.Set("pad.point", point, sid)) == true end
    local s = kind == "dial" and surface(kind, sid)
    if not s or not Lib.ValidPoint(point) then return false end
    s.point = point and { point[1], point[2], point[3], point[4] } or nil
    announce(kind, sid)
    return true
end
```
`NS.SchemaRuntime` is read at call time: settings/ loads after modules/, and nothing calls these writers at file load.

In `modules/Pad.lua`, the comments that call the point registry data change with it, and the default place is published for the CLI's `x y` form (and, in Task 10, the X/Y boxes):
- in the file header, "(the named non-setting state, spec §5.1)" becomes "(a member row since phase 3, spec §5.1)", and the sentence "It is registry data, so the drag and Reset position write it only through Library.SetSurfacePoint (architecture-§5)" (it wraps across two comment lines) becomes "It is the `pad.point` member row (settings/SchemaMembers.lua): the drag and Reset position write it through Library.SetSurfacePoint, which hands it to the seam (architecture-§5)";
- the comment above `savePoint`, "The point is registry data: Library is its only writer (architecture-§5); the pad only asks.", becomes "The point is the `pad.point` member row: Library.SetSurfacePoint writes it through the seam; the pad only asks.";
- after `local DEFAULT_POINT = { "CENTER", "CENTER", 0, -150 }`, add:
```lua
Pad.DEFAULT_POINT = DEFAULT_POINT   -- read, never written, by settings/Slash.lua and settings/Pads.lua
```


- [ ] **Step 4: The structured rows on the CLI**

In `settings/Slash.lua`, directly above `if not lib then`, add:
```lua
-- ── the structured member rows on the command line (slash-commands-§6) ──────────────────────
--
-- Three member rows hold a table (settings/SchemaMembers.lua). The library parses and prints bool,
-- number, string and color; the descriptor's `parse` and `format` hooks teach it these three and
-- hand every other row back to it:
--   pad.point       `x y` (keeps the pad's anchor points) or `POINT RELATIVEPOINT x y`
--   group.when      `<condition> <value>[,<value>...]` replaces that one condition; the condition
--                   alone clears it; keyLevel takes `min-max`, either end empty, or one level
--   builtin.hidden  callout ids, or `none`
-- A row is written to the member Settings.EditingId addresses, as every member row is. A member row
-- with no member to address prints "(nothing to edit)" instead of nil.

local function wordsOf(text)
    local out = {}
    for w in (text or ""):gmatch("[^%s,]+") do out[#out + 1] = w end
    return out
end

local function parsePoint(text)
    local w = wordsOf(text)
    local x, y = tonumber(w[#w - 1] or ""), tonumber(w[#w] or "")
    if not (x and y) or (#w ~= 2 and #w ~= 4) then
        return nil, L["A position is `x y` or `POINT RELATIVEPOINT x y`."]
    end
    if #w == 4 then return { w[1]:upper(), w[2]:upper(), x, y } end
    local current = NS.SchemaRuntime.Get("pad.point")
    local base = type(current) == "table" and current or NS.Pad.DEFAULT_POINT
    return { base[1], base[2], x, y }
end

local function knownCondition(name)
    for _, row in ipairs(NS.Resolver.ROWS) do
        if row == name then return true end
    end
    return false
end

-- `min-max`, `min-`, `-max` or one level.
local function parseKeyLevel(text)
    local lo, dash, hi = text:match("^(%d*)%s*(%-?)%s*(%d*)$")
    if not lo or (lo == "" and hi == "") or (dash == "" and hi ~= "") then return nil end
    if dash == "" then hi = lo end
    return { min = tonumber(lo), max = tonumber(hi) }
end

local function parseWhen(text)
    local name, rest = (text or ""):match("^%s*(%S+)%s*(.-)%s*$")
    if not (name and knownCondition(name)) then
        return nil, L["Name a condition: %s."]:format(table.concat(NS.Resolver.ROWS, ", "))
    end
    local current = NS.SchemaRuntime.Get("group.when")
    local when = {}
    for k, v in pairs(type(current) == "table" and current or {}) do when[k] = v end
    if rest == "" then
        when[name] = nil
    elseif name == "keyLevel" then
        when.keyLevel = parseKeyLevel(rest)
        if not when.keyLevel then return nil, L["A key level is `min-max`; either end may be empty."] end
    else
        local set = {}
        for _, v in ipairs(wordsOf(rest)) do set[tonumber(v) or v] = true end
        when[name] = set
    end
    return when
end

local function parseIdSet(text)
    local w = wordsOf(text)
    if #w == 0 then return nil, L["Name the callout ids to hide, or none."] end
    local set = {}
    if not (#w == 1 and w[1]:lower() == "none") then
        for _, id in ipairs(w) do set[id] = true end
    end
    return set
end

local PARSE = { point = parsePoint, when = parseWhen, idset = parseIdSet }

local function sortedKeys(set)
    local keys = {}
    for k in pairs(set) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    return keys
end

local function formatWhen(when)
    local parts = {}
    for _, row in ipairs(NS.Resolver.ROWS) do
        local v = type(when) == "table" and when[row] or nil
        if row == "keyLevel" and type(v) == "table" and (v.min or v.max) then
            parts[#parts + 1] = ("keyLevel=%s..%s"):format(v.min and tostring(v.min) or L["any"],
                v.max and tostring(v.max) or L["any"])
        elseif row ~= "keyLevel" and type(v) == "table" and next(v) then
            parts[#parts + 1] = row .. "=" .. table.concat(sortedKeys(v), ",")
        end
    end
    if #parts == 0 then return L["always"] end
    return table.concat(parts, "; ")
end

local FORMAT = {
    point = function(v)
        if type(v) ~= "table" then return L["the default place"] end
        return ("%s %s %s %s"):format(tostring(v[1]), tostring(v[2]), tostring(v[3]), tostring(v[4]))
    end,
    when = formatWhen,
    idset = function(v)
        if type(v) ~= "table" or next(v) == nil then return L["none"] end
        return table.concat(sortedKeys(v), ", ")
    end,
}

local function memberExists(kind)
    local id = QC.Settings.EditingId(kind)
    return id ~= nil and NS.Library.Member(kind, id) ~= nil
end
```
In the `lib:New({ … })` descriptor, after `groupKey`, add:
```lua
        -- The structured member rows' text forms; every other row is the library's (see above).
        parse        = function(row, text, textOf)
            local fn = row and PARSE[row.type]
            if fn then return fn(text) end
            return lib.ParseValue(row, text, textOf)
        end,
        format       = function(row, value)
            if row and row.instance and value == nil and not memberExists(row.instance) then
                return L["(nothing to edit)"]
            end
            local fn = row and FORMAT[row.type]
            if fn then return fn(value) end
            return lib.FormatValue(row, value)
        end,
```
Change the file header's sentence "The dispatcher, help renderer, formatters and value parser are the library's (slash-commands-§1)." to "The dispatcher, help renderer, formatters and value parser are the library's (slash-commands-§1); the structured member rows' text forms are this file's, through the descriptor's `parse` and `format` hooks (slash-commands-§6)."

- [ ] **Step 5: Locale keys**

In `locales/enUS.lua`, under a new comment `-- Member rows on the command line (settings/Slash.lua)`:
```lua
L["A position is `x y` or `POINT RELATIVEPOINT x y`."] = "A position is `x y` or `POINT RELATIVEPOINT x y`."
L["Name a condition: %s."] = "Name a condition: %s."
L["A key level is `min-max`; either end may be empty."] = "A key level is `min-max`; either end may be empty."
L["Name the callout ids to hide, or none."] = "Name the callout ids to hide, or none."
L["any"] = "any"
L["always"] = "always"
L["the default place"] = "the default place"
L["none"] = "none"
L["(nothing to edit)"] = "(nothing to edit)"
```

- [ ] **Step 6: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS. In particular: every `test_library` case that writes the overlay or a point (their announce counts are unchanged: the seam's `onChange` is the one announce), `test_pad`'s drag and Reset position cases and its `[registry]` grep (the point now goes through the seam; `settings/Slash.lua` builds a new table and never assigns `.point`), and `test_slash`'s `list` cases (every member row now lists, each through the library's formatter or this file's).

- [ ] **Step 7: Commit**

```bash
git add modules/Library.lua modules/Pad.lua settings/Slash.lua tests/test_members.lua locales/enUS.lua
git checkout -- modules/Library.lua modules/Pad.lua settings/Slash.lua tests/test_members.lua locales/enUS.lua
git commit -m "Settings: Library's field writers go through the seam; the structured member rows on the CLI"
```

---
### Task 4a: Preview as…: the engine, the disarmed chips and its ends

Spec §13.3: "Preview as…" "builds a synthetic snapshot and turns on test mode for the surfaces, so they render the resolved groups live. It is session-only, and switches off when the panel closes or combat starts." This task makes it test mode's second flavor in `modules/Preview.lua` (one switch at a time with the placeholders), builds each pad from the previewed snapshot in `Surfaces.ApplyAll`, disarms every previewed chip (no line, no self-line, no lock text), names the preview on the header and in the chip tooltip, and ends it at the start of combat, at the stand-down and when the settings window closes. The menu here is the generic entries; Task 4b adds the shipped dungeons, the `state.previewAs` row, `/qc preview` and the diagnostics line.

**Files:**
- Modify: `core/State.lua` (`State.previewAs`)
- Modify: `modules/Preview.lua`, `modules/Surfaces.lua` (`ApplyAll`, `MarkPreview`), `modules/Pad.lua` (`arm`, `headerState`), `modules/Pad_Render.lua` (`TooltipLines`, `PaintHeader`)
- Modify: `settings/Panel.lua` (`Settings.Register`)
- Test: `tests/test_preview.lua`, `tests/test_pad_render.lua`
- Modify: `locales/enUS.lua`

**Interfaces:**
- Consumes: `NS.BuiltIns.order / groups` (each battleground set's `when.battleground`), `NS.Situation.Current()`, `NS.Compat.SpecName()`, `Surfaces.BuildPlan`, `Surfaces.TestPlan`, Pad's `arm` / `headerState`, `R.SituationText`.
- Produces:
  - `NS.State.previewAs` (declared in `core/State.lua`; a preset key or nil).
  - `NS.Preview.CURRENT = "current"`; `Presets() -> { { key, label, snapshot? } … }`; `FindPreset(key) -> entry|nil`; `Label(key) -> string`; `Choices() -> { { value, text } … }`; `PreviewAs() -> key|nil`; `PreviewSnapshot() -> snapshot|nil`; `SetPreviewAs(key) -> boolean` (`nil`, `""`, `"off"` and `"current"` turn it off); `WatchPanel(frame) -> boolean`
  - Preset keys from this task: `current`, `mplus`, `raid:lfr|normal|heroic|mythic`, `arena`, `bg:<key>` per battleground set (`bi.bg.ab` -> `bg:ab`), `world`.
  - `TEST_MODE_CHANGED (on)`: `on` is true while either flavor is on.
  - `NS.Surfaces.MarkPreview(plan, key) -> plan` (sets `plan.test = true`, `plan.preview = key`, and `slot.preview = true` on every slot)

- [ ] **Step 1: Write the failing tests**

In `tests/test_preview.lua`, add below the existing `heard` helper:
```lua
local WORLD = { inGroup = false }
local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function live(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or WORLD end
    NS.Situation.RefreshNow("test")
    return NS, m
end

local function arenaChip(NS)
    return NS.Pad.ChipsFor("p1", NS.Library.Group("bi.arena").callouts[1])[1]
end
```
and append:
```lua
test("preview: [phase 3] Preview as Arena builds the pad from the arena snapshot, every chip disarmed", function()
    local NS = live()
    local out = heard(NS)
    assertTrue(NS.Preview.SetPreviewAs("arena"))
    assertEqual(table.concat(out, ","), "true")
    local plan = NS.Surfaces.Plans().p1
    assertEqual(plan.preview, "arena")
    assertEqual(plan.order[1], "bi.arena")
    local chip = arenaChip(NS)
    assertTrue(chip ~= nil, "the arena set is drawn in the open world")
    -- red under: drop `and not slot.preview` from Pad's arm (the previewed chip is armed)
    assertTrue(chip:GetAttribute("macrotext") == nil)
    local header = NS.Pad.Instance("p1").header
    assertEqual(header.qcSituation:GetText(), "Preview: Arena")
    assertTrue(header.qcTest:IsShown())
    assertEqual(header.qcTest:GetText(), "PREVIEW")
end)

test("preview: [review 3] a previewed chip sends nothing and reports nothing", function()
    local NS, m = live()
    NS.Preview.SetPreviewAs("arena")
    local results = 0
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.SEND_RESULT, function() results = results + 1 end)
    local before = #m.sentMacros
    m.__click(arenaChip(NS))
    assertEqual(#m.sentMacros, before)
    assertEqual(results, 0)
end)

test("preview: [review 3] a previewed solo chip prints nothing, even with the self fallback", function()
    local NS, m = live()
    NS.SchemaRuntime.Set("behavior.soloFallback", "self")
    local Lib = NS.Library
    local cid = Lib.CreateCallout({ name = "Inc", text = "Incoming", channel = "smartGroup" })
    local gid = Lib.CreateGroup({ name = "Mine", callouts = { cid } })
    Lib.AddGroupToSurface("pad", "p1", gid, 1)
    assertTrue(NS.Preview.SetPreviewAs("world"))
    local chip = NS.Pad.ChipsFor("p1", cid)[1]
    assertTrue(chip ~= nil, "the user group (an empty When) shows in the previewed open world")
    m.prints = {}
    m.__click(chip)
    -- red under: keep `slot.selfText` in a previewed chip's meta (modules/Pad.lua arm)
    assertEqual(#m.prints, 0)
end)

test("preview: [review 3] combat ends it with one line, and the live chips come back armed", function()
    local NS, m = live(MPLUS)
    NS.Preview.SetPreviewAs("arena")
    m.prints = {}
    combat(m, true)
    -- red under: drop the preview branch from Preview's onRestrictionChanged
    assertTrue(NS.Preview.PreviewAs() == nil)
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("Preview ended: you entered combat.", 1, true) ~= nil, m.prints[1])
    assertEqual(NS.Pad.ChipsFor("p1", "bi.mplus.pull")[1]:GetAttribute("macrotext"), "/p Pulling next pack")
    assertEqual(#m.blocked, 0)
end)

test("preview: [phase 3] refused in combat and while disabled, with one line each", function()
    local NS, m = live()
    combat(m, true)
    m.prints = {}
    assertFalse(NS.Preview.SetPreviewAs("arena"))
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("Preview is not available in combat.", 1, true) ~= nil, m.prints[1])
    combat(m, false)
    NS.addon:OnSlashCommand("disable")
    m.prints = {}
    assertFalse(NS.Preview.SetPreviewAs("arena"))
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("is disabled", 1, true) ~= nil, m.prints[1])
end)

test("preview: [review 3] the stand-down ends it silently, and so does closing the settings window", function()
    local NS, m = live()
    NS.Preview.SetPreviewAs("arena")
    NS.SchemaRuntime.Set("enabled", false)
    assertTrue(NS.Preview.PreviewAs() == nil)
    NS.SchemaRuntime.Set("enabled", true)
    assertTrue(NS.Preview.SetPreviewAs("arena"))
    -- red under: drop the WatchPanel call from Settings.Register in settings/Panel.lua
    m.SettingsPanel:__fire("OnHide")
    assertTrue(NS.Preview.PreviewAs() == nil)
    assertTrue(arenaChip(NS) == nil, "back to the open world, where the arena set is not active")
end)

test("preview: [phase 3] test mode and Preview as are one switch at a time", function()
    local NS = live()
    local P = NS.Preview
    P.SetPreviewAs("arena")
    assertTrue(P.SetTestMode(true))
    assertTrue(P.PreviewAs() == nil, "test mode replaces the preview")
    assertTrue(P.SetPreviewAs("world"))
    assertFalse(P.IsTestMode(), "the preview replaces test mode")
    assertEqual(NS.Surfaces.Plans().p1.preview, "world")
    assertTrue(P.SetPreviewAs("current"))
    assertTrue(P.PreviewAs() == nil)
    assertFalse(P.SetPreviewAs("nope"))
end)
```
Append to `tests/test_pad_render.lua`:
```lua
test("pad render: [phase 3] a previewed slot's tooltip shows its line and says it sends nothing", function()
    local NS = T.newAddon()
    local lines = NS.PadRender.TooltipLines({ name = "Lust", line = "/p Lust", preview = true })
    assertEqual(lines[2], "/p Lust")
    assertEqual(lines[#lines], "Preview: this chip sends nothing.")
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `lua tests/run.lua`
Expected: FAIL (`SetPreviewAs`, `PreviewAs` and `MarkPreview` do not exist; a previewed slot's tooltip has no preview line).

- [ ] **Step 3: The session field**

In `core/State.lua`, append:
```lua

-- "Preview as…" (modules/Preview.lua, spec §13.3): the preset key the pads are drawn as, or nil.
-- Session-only; test mode's second flavor, so it is never on with State.testMode.
State.previewAs = nil
```

- [ ] **Step 4: Preview as… in modules/Preview.lua**

Replace the file header's sentence "Phase 2 owns the switch; "Preview as…" (spec §13.3) joins this file in phase 3." with "It holds both flavors of test mode: placeholders, and "Preview as…" (spec §13.3), which builds the pads from a synthetic snapshot. They are one switch at a time."

Add, directly above `function P.IsTestMode()`:
```lua
-- Both flavors announce through TEST_MODE_CHANGED: `on` is true while either is on.
local function announce()
    NS.addon:SendMessage(NS.MSG.TEST_MODE_CHANGED, State.testMode == true or State.previewAs ~= nil)
    refreshPanel()
end
```
In `P.SetTestMode`, replace
```lua
    State.testMode = on
    NS.Debug("Pad", "test mode %s", on and "on" or "off")
    NS.addon:SendMessage(NS.MSG.TEST_MODE_CHANGED, on)
    refreshPanel()
    return true
```
with
```lua
    State.testMode = on
    if on then State.previewAs = nil end
    NS.Debug("Pad", "test mode %s", on and "on" or "off")
    announce()
    return true
```
Directly above `local function onRestrictionChanged()`, add:
```lua
-- ── Preview as… (spec §13.3) ────────────────────────────────────────────────────────────────
--
-- Test mode's second flavor: the pads are built from a synthetic snapshot instead of placeholders,
-- so they show the groups that situation resolves to (modules/Surfaces.lua marks the plan, and every
-- previewed chip is disarmed). Only where you are changes: the class, specialization, role and
-- character are the live ones. Session-only (NS.State.previewAs).

P.CURRENT = "current"
local DOT = " \194\183 "

local RAID = { { "lfr", 17, L["LFR"] }, { "normal", 14, L["Normal"] }, { "heroic", 15, L["Heroic"] },
    { "mythic", 16, L["Mythic"] } }

local function base(fields)
    local live = NS.Situation.Current()
    local s = { classFile = live.classFile, specID = live.specID, role = live.role, character = live.character,
        leader = true, assist = false, inCombat = false, lockdown = {} }
    for k, v in pairs(fields) do s[k] = v end
    return s
end

local function mplus(instanceID)
    return base({ content = "mythicPlus", instanceID = instanceID, difficultyID = 8, difficulty = "keystone",
        keyLevel = 10, group = "party", instanceGroup = false, lockdown = { challengeMode = true } })
end

-- One entry per battleground set: its key ("bi.bg.ab" -> "bg:ab"), its name, its lowest instanceID.
local function battlegrounds()
    local out = {}
    for _, gid in ipairs(NS.BuiltIns.order) do
        local def = NS.BuiltIns.groups[gid]
        local ids = def.when and def.when.battleground
        local short = gid:match("^bi%.bg%.(.+)$")
        if short and type(ids) == "table" then
            local first
            for id in pairs(ids) do
                if not first or id < first then first = id end
            end
            out[#out + 1] = { key = "bg:" .. short, label = def.name, instanceID = first }
        end
    end
    return out
end

--- The "Preview as…" menu, in order (spec §13.3): { key, label, snapshot }; Current has none. Task 4b
--- adds one M+ entry per shipped dungeon after the generic one.
function P.Presets()
    local out = { { key = P.CURRENT, label = L["Current"] } }
    local spec = NS.Compat.SpecName()
    out[#out + 1] = { key = "mplus", label = spec and (L["M+"] .. DOT .. spec) or L["M+"], snapshot = mplus(nil) }
    for _, r in ipairs(RAID) do
        out[#out + 1] = { key = "raid:" .. r[1], label = L["Raid"] .. DOT .. r[3], snapshot = base({ content = "raid",
            difficultyID = r[2], difficulty = r[1], group = "raid", instanceGroup = r[1] == "lfr" }) }
    end
    out[#out + 1] = { key = "arena", label = L["Arena"], snapshot = base({ content = "arena", group = "party",
        instanceGroup = false, lockdown = { pvpMatch = true } }) }
    for _, bg in ipairs(battlegrounds()) do
        out[#out + 1] = { key = bg.key, label = bg.label, snapshot = base({ content = "battleground",
            instanceID = bg.instanceID, group = "raid", instanceGroup = true, lockdown = { pvpMatch = true } }) }
    end
    out[#out + 1] = { key = "world", label = L["World"] .. DOT .. L["Solo"], snapshot = base({ content = "openWorld",
        group = "solo", leader = false }) }
    return out
end

function P.FindPreset(key)
    for _, e in ipairs(P.Presets()) do
        if e.key == key then return e end
    end
    return nil
end

function P.Label(key)
    local e = P.FindPreset(key)
    return e and e.label or tostring(key)
end

--- The menu as a row's `values` list.
function P.Choices()
    local out = {}
    for i, e in ipairs(P.Presets()) do out[i] = { value = e.key, text = e.label } end
    return out
end

function P.PreviewAs()
    return State.previewAs
end

--- The previewed snapshot, or nil when "Preview as…" is off.
function P.PreviewSnapshot()
    local key = State.previewAs
    if not key then return nil end
    local e = P.FindPreset(key)
    return e and e.snapshot or nil
end

--- Preview the pads as `key`, or turn the preview off (nil, "", "off" or "current"). A start is
--- refused, with one line, while stood down or in combat.
--- @return boolean changed
function P.SetPreviewAs(key)
    if key == nil or key == "" or key == "off" then key = P.CURRENT end
    if not P.FindPreset(key) then return false end
    local want = key ~= P.CURRENT and key or nil
    if want == State.previewAs then return false end
    if want then
        if NS.IsStoodDown() then
            NS.Print(NS.SlashCommands:DisabledLine())
            return false
        end
        if fighting() then
            NS.Print(L["Preview is not available in combat."])
            return false
        end
        State.testMode = nil
    end
    State.previewAs = want
    NS.Debug("Pad", "preview %s", want or "off")
    announce()
    return true
end

local watched = setmetatable({}, { __mode = "k" })

--- End the preview when the settings window closes (spec §13.3). settings/Panel.lua hands it the
--- client's SettingsPanel once; the hook is insecure and runs only when that window hides.
function P.WatchPanel(frame)
    if type(frame) ~= "table" or type(frame.HookScript) ~= "function" or watched[frame] then return false end
    watched[frame] = true
    frame:HookScript("OnHide", function()
        if State.previewAs then P.SetPreviewAs(nil) end
    end)
    return true
end
```
Replace `onRestrictionChanged` with:
```lua
local function onRestrictionChanged()
    if not NS.Restrictions.InCombat() then return end
    if P.IsTestMode() then
        P.SetTestMode(false)
        NS.Print(L["Test mode ended: you entered combat."])
    end
    if State.previewAs then
        P.SetPreviewAs(nil)
        NS.Print(L["Preview ended: you entered combat."])
    end
end
```
Replace the whole stand-down step at the end of the file (by now `P.SetPreviewAs` above it also contains a `State.testMode = nil` line, so do not search for that line alone):
```lua
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    State.testMode = nil
    if receiver and not NS.Bus.tracked then receiver:UnregisterMessage(NS.MSG.RESTRICTION_CHANGED) end
end
```
with
```lua
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    State.testMode, State.previewAs = nil, nil
    if receiver and not NS.Bus.tracked then receiver:UnregisterMessage(NS.MSG.RESTRICTION_CHANGED) end
end
```

- [ ] **Step 5: Surfaces builds the preview plan**

In `modules/Surfaces.lua`, after `S.TestPlan`, add:
```lua
--- A "Preview as…" plan (spec §13.3): drawn like test mode (always shown, the header says so) but from
--- the groups the previewed snapshot resolves to. Every slot keeps its line for the tooltip and is
--- disarmed by the pad, so a previewed chip sends nothing.
function S.MarkPreview(plan, key)
    plan.test, plan.preview = true, key
    for _, sec in ipairs(plan.sections) do
        for _, slot in ipairs(sec.slots) do slot.preview = true end
    end
    return plan
end
```
In `S.ApplyAll`, replace
```lua
    local snap = NS.Situation.Current()
    local deps = S.Deps(snap)
    local test = NS.Preview.IsTestMode()
```
with
```lua
    local preview = NS.Preview.PreviewSnapshot()
    local snap = preview or NS.Situation.Current()
    local deps = S.Deps(snap)
    local test = preview == nil and NS.Preview.IsTestMode()
```
and replace
```lua
        local plan = test and S.TestPlan(id) or S.BuildPlan(id, pads[id], snap, deps)
```
with
```lua
        local plan = test and S.TestPlan(id) or S.BuildPlan(id, pads[id], snap, deps)
        if preview then S.MarkPreview(plan, NS.Preview.PreviewAs()) end
```
Add to the file header, after "Test mode's plan is placeholder slots that carry no line, drawn through the same render path (preview-mode).": "A "Preview as…" plan is a real plan for the previewed snapshot, marked so every chip is disarmed (spec §13.3)."

- [ ] **Step 6: The pad disarms a previewed chip and names the preview**

In `modules/Pad.lua`, replace the whole `arm` function with:
```lua
-- A previewed chip (spec §13.3) keeps its line for the tooltip and is disarmed, and carries neither
-- the solo self-line nor the lock text: a previewed chip sends, prints and reports nothing.
local function arm(btn, slot)
    local preview = slot.preview == true
    local meta = { calloutId = slot.calloutId, surfaceId = slot.surfaceId, name = slot.name,
        chatType = slot.chatType, selfText = (not preview) and slot.selfText or nil,
        lockText = (not preview) and function() return slot.lock and (R.LOCK_TEXT[slot.lock] or tostring(slot.lock)) end or nil }
    if slot.line and slot.chatType and not preview then
        NS.SendEngine.Arm(btn, slot.line, meta)
    else
        meta.chatType = nil
        NS.SendEngine.Disarm(btn, meta)
    end
end
```

In `headerState`, replace
```lua
        situation = plan.test and L["Test mode"] or R.SituationText(snap, NS.Compat.DungeonName(snap.challengeMapID)),
```
with
```lua
        situation = plan.preview and L["Preview: %s"]:format(R.SituationText(snap, NS.Compat.DungeonName(snap.challengeMapID)))
            or plan.test and L["Test mode"] or R.SituationText(snap, NS.Compat.DungeonName(snap.challengeMapID)),
        testText = plan.preview and L["PREVIEW"] or nil,
```

In `modules/Pad_Render.lua`, `R.TooltipLines`, before `return lines`, add:
```lua
    if slot.preview then lines[#lines + 1] = L["Preview: this chip sends nothing."] end
```
and in `R.PaintHeader`, after `header.qcTest:SetShown(state.test == true)`, add:
```lua
    header.qcTest:SetText(state.testText or L["TEST MODE"])
```

- [ ] **Step 7: The settings window's hide ends it**

In `settings/Panel.lua`, `Settings.Register`, after `Helpers.CreateOptionsPanel()`, add:
```lua
    -- "Preview as…" ends when the settings window closes (spec §13.3).
    if NS.Preview then NS.Preview.WatchPanel(_G.SettingsPanel) end
```

- [ ] **Step 8: Locale keys**

In `locales/enUS.lua`, under a new comment `-- Preview as… (modules/Preview.lua, modules/Pad.lua, modules/Pad_Render.lua)`:
```lua
L["Current"] = "Current"
L["LFR"] = "LFR"
L["Normal"] = "Normal"
L["Heroic"] = "Heroic"
L["Mythic"] = "Mythic"
L["Solo"] = "Solo"
L["Preview is not available in combat."] = "Preview is not available in combat."
L["Preview ended: you entered combat."] = "Preview ended: you entered combat."
L["Preview: %s"] = "Preview: %s"
L["PREVIEW"] = "PREVIEW"
L["Preview: this chip sends nothing."] = "Preview: this chip sends nothing."
```

- [ ] **Step 9: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS, including the phase-2 preview cases ("announcing each edge once" still hears `true,false`) and the kit's `test_prose`.

- [ ] **Step 10: Commit**

```bash
git add core/State.lua modules/Preview.lua modules/Surfaces.lua modules/Pad.lua modules/Pad_Render.lua settings/Panel.lua locales/enUS.lua tests/test_preview.lua tests/test_pad_render.lua
git checkout -- core/State.lua modules/Preview.lua modules/Surfaces.lua modules/Pad.lua modules/Pad_Render.lua settings/Panel.lua locales/enUS.lua tests/test_preview.lua tests/test_pad_render.lua
git commit -m "Preview: Preview as… builds the pads from a synthetic situation; previewed chips send nothing"
```

---
### Task 4b: Preview as…: the dungeons, the row, `/qc preview` and diagnostics

The rest of "Preview as…": the menu's dungeon entries from a new shipped id table, `defaults/GameIds.lua` (the When editor, Task 8, reads it too), labeled `M+ · <dungeon> · <spec>` as spec §13.3 lists them; the instance name reader; the `state.previewAs` session row the Groups and Comms Pad pages draw first on their General tab; the `/qc preview` verb; and a diagnostics line.

**Files:**
- Create: `defaults/GameIds.lua`; Modify: `QuickComms.toc` (after `defaults\BuiltIns_Battlegrounds.lua`)
- Modify: `core/Compat.lua` (`InstanceName`), `.luacheckrc` (`GetRealZoneText`)
- Modify: `modules/Preview.lua` (the dungeon entries), `modules/Diagnostics.lua` (one line)
- Modify: `settings/Schema.lua` (`SESSION`), `settings/SchemaRows.lua` (the row), `settings/Slash.lua` (the verb), `settings/SlashVerbs.lua` (`Preview`)
- Test: `tests/test_preview.lua`, `tests/test_compat.lua`, `tests/test_diagnostics.lua`
- Modify: `locales/enUS.lua`

**Interfaces:**
- Consumes: Task 4a's `Preview.*`; `NS.Compat.SpecName()`.
- Produces:
  - `NS.GameIds = { DUNGEONS = {instanceID…}, RAIDS = {}, CLASSES = {classFile…}, SPECS = { [classFile] = {specID…} } }`
  - `NS.Compat.InstanceName(id) -> string|nil`
  - Preset keys `mplus:<instanceID>` per `GameIds.DUNGEONS`, labeled `M+ · <dungeon> · <spec>` (`M+ · <dungeon>` when the spec is unknown).
  - Session row `state.previewAs` (page `groups`, group `General`, values `Preview.Choices()`, default `"current"`).
  - `NS.SlashVerbs.PreviewLines(rest) -> string[]`, `NS.SlashVerbs.Preview(rest)`; the `preview` verb.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_preview.lua`:
```lua
test("preview: [phase 3] the menu: Current, M+, each dungeon, each raid difficulty, Arena, each battleground, World", function()
    local NS = live()
    local P = NS.Preview
    assertEqual(P.Presets()[1].key, "current")
    for _, key in ipairs({ "mplus", "mplus:2526", "raid:lfr", "raid:normal", "raid:heroic", "raid:mythic",
        "arena", "bg:ab", "bg:wsg", "world" }) do
        assertTrue(P.FindPreset(key) ~= nil, key)
    end
    assertEqual(P.FindPreset("bg:ab").snapshot.instanceID, 529, "the battleground's lowest id")
    assertEqual(P.FindPreset("raid:heroic").snapshot.difficulty, "heroic")
    assertEqual(P.FindPreset("mplus:2526").snapshot.instanceID, 2526)
    assertTrue(P.FindPreset("nope") == nil)
end)

test("preview: [phase 3] a dungeon entry reads M+ · <dungeon> · <spec> (spec §13.3)", function()
    local NS = live()
    NS.Compat.SpecName = function() return "Frost" end
    NS.Compat.InstanceName = function(id) return id == 2526 and "Algeth'ar Academy" or nil end
    local DOT = " \194\183 "
    assertEqual(NS.Preview.FindPreset("mplus:2526").label, "M+" .. DOT .. "Algeth'ar Academy" .. DOT .. "Frost")
end)

test("preview: [phase 3] the Preview as row and `/qc preview` drive the same switch", function()
    local NS, m = live()
    local S = NS.SchemaRuntime
    assertEqual(S.Get("state.previewAs"), "current")
    assertTrue(S.Set("state.previewAs", "arena"))
    assertEqual(NS.Preview.PreviewAs(), "arena")
    assertFalse((S.Set("state.previewAs", "nope")), "not a situation")
    m.prints = {}
    NS.addon:OnSlashCommand("preview off")
    assertTrue(NS.Preview.PreviewAs() == nil)
    assertTrue(m.prints[#m.prints]:find("Preview off.", 1, true) ~= nil, m.prints[#m.prints])
    m.prints = {}
    NS.addon:OnSlashCommand("preview")
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("raid:heroic", 1, true) ~= nil, text)
    NS.addon:OnSlashCommand("preview bg:ab")
    assertEqual(NS.Preview.PreviewAs(), "bg:ab")
    m.prints = {}
    NS.addon:OnSlashCommand("preview nope")
    assertTrue(m.prints[1]:find("No situation named nope", 1, true) ~= nil, m.prints[1])
end)
```
Append to `tests/test_compat.lua`:
```lua
test("compat: [phase 3] InstanceName reads the client's name; a secret, empty or missing one is nil", function()
    local NS, env = T.newAddon()
    env.issecretvalue = T.isSecret
    env.GetRealZoneText = function(id)
        if id == 2526 then return "Algeth'ar Academy" end
        if id == 2 then return "" end
        return T.secret("x")
    end
    assertEqual(NS.Compat.InstanceName(2526), "Algeth'ar Academy")
    assertNil(NS.Compat.InstanceName(1))
    assertNil(NS.Compat.InstanceName(2))
    assertNil(NS.Compat.InstanceName("2526"))
    env.GetRealZoneText = nil
    assertNil(NS.Compat.InstanceName(2526))
end)
```
Append to `tests/test_diagnostics.lua`:
```lua
test("diagnostics: [phase 3] the surfaces section names the preview", function()
    local NS = T.enableAddon()
    NS.Situation.RefreshNow("test")
    assertTrue(report(NS):find("previewAs=off", 1, true) ~= nil)
    NS.Preview.SetPreviewAs("arena")
    assertTrue(report(NS):find("previewAs=arena", 1, true) ~= nil)
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `lua tests/run.lua`
Expected: FAIL (no `mplus:2526` entry; `InstanceName` does not exist; no `state.previewAs` row; no `preview` verb).

- [ ] **Step 3: The shipped ids**

Create `defaults/GameIds.lua`:
```lua
local _, NS = ...
-- defaults/GameIds.lua — the shipped game-id tables "Preview as…" and the When editor list (spec
-- §13.2, §13.3). DATA ONLY. Every entry is an id or a token, never a name (localization-§4): a name
-- is read from the client at display time (core/Compat.lua) and never matched.
--   DUNGEONS  the current Mythic+ season's instanceIDs (GetInstanceInfo's 8th return). Only the ids
--             confirmed when this table was written are listed: the season's returning dungeons.
--             The Midnight dungeons and raids join when their ids are confirmed in game (phase 5,
--             with the battleground ids); until then the When editor adds the instance you are in,
--             or a typed id.
--   RAIDS     the current raid tier's instanceIDs (none confirmed yet).
--   CLASSES   classFile tokens, in the client's class order.
--   SPECS     specIDs per classFile. 1480 is the Demon Hunter's Devourer (Midnight), confirmed in
--             game with the rest in phase 5.

NS.GameIds = NS.GameIds or {}
local G = NS.GameIds

G.DUNGEONS = {
    2526,   -- Algeth'ar Academy
    658,    -- Pit of Saron
    1753,   -- Seat of the Triumvirate
    1209,   -- Skyreach
}
G.RAIDS = {}

G.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE",
    "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }

G.SPECS = {
    WARRIOR = { 71, 72, 73 }, PALADIN = { 65, 66, 70 }, HUNTER = { 253, 254, 255 },
    ROGUE = { 259, 260, 261 }, PRIEST = { 256, 257, 258 }, DEATHKNIGHT = { 250, 251, 252 },
    SHAMAN = { 262, 263, 264 }, MAGE = { 62, 63, 64 }, WARLOCK = { 265, 266, 267 },
    MONK = { 268, 270, 269 }, DRUID = { 102, 103, 104, 105 }, DEMONHUNTER = { 577, 581, 1480 },
    EVOKER = { 1467, 1468, 1473 },
}
```
In `QuickComms.toc`, after `defaults\BuiltIns_Battlegrounds.lua`, add:
```
# Conventional: data (the editors' and Preview as's shipped ids), read at call time
defaults\GameIds.lua
```

- [ ] **Step 4: The instance name reader**

In `core/Compat.lua`, after `Compat.SpellLink`, add:
```lua
-- ── Display names for the editors (spec §13.2, §13.3): shown, never matched ─────────────────

--- An instance's display name from its instanceID (GetRealZoneText takes a map id), or nil.
function Compat.InstanceName(id)
    if not (PlainNumber(id) and GetRealZoneText) then return nil end
    local name = PlainString(GetRealZoneText(id))
    if name == "" then return nil end
    return name
end
```
In `.luacheckrc`, add to `read_globals`, after the `"PlaySound", "SOUNDKIT",` line:
```lua
  -- core/Compat.lua: the editors' display names (shown, never matched).
  "GetRealZoneText",
```

- [ ] **Step 5: The dungeon entries**

In `modules/Preview.lua`, `P.Presets`, after the generic M+ entry (`out[#out + 1] = { key = "mplus", … }`), add:
```lua
    -- One entry per shipped dungeon (defaults/GameIds.lua), labeled as spec §13.3 lists it.
    for _, id in ipairs(NS.GameIds.DUNGEONS) do
        local name = NS.Compat.InstanceName(id) or L["Instance %d"]:format(id)
        local label = L["M+"] .. DOT .. name
        if spec then label = label .. DOT .. spec end
        out[#out + 1] = { key = "mplus:" .. id, label = label, snapshot = mplus(id) }
    end
```
and drop the "Task 4b adds one M+ entry per shipped dungeon after the generic one." sentence from the function's doc comment.

- [ ] **Step 6: The session row and its storage**

In `settings/Schema.lua`, add to the `SESSION` table, after `["state.testMode"]`:
```lua
    -- Preview as… (spec §13.3): modules/Preview.lua owns the switch; "current" is off.
    ["state.previewAs"] = {
        get = function() return NS.Preview ~= nil and NS.Preview.PreviewAs() or "current" end,
        set = function(v) if NS.Preview then NS.Preview.SetPreviewAs(v) end end,
    },
```
At the end of `settings/SchemaRows.lua` (after its early `return` on the degraded load, so a degraded schema still holds only the member rows that `tests/test_setup.lua` pins), add:
```lua

-- Preview as… (spec §13.3): a session row, never saved, read and written through modules/Preview.lua
-- (settings/Schema.lua SESSION). The Groups and Comms Pad pages draw it first on their General tab:
-- the band above the strip holds only each page's picker and its create action (options-ui-§14).
local PREVIEW_ROWS = {
    { path = "state.previewAs", type = "string", sessionOnly = true, default = "current",
      page = "groups", group = L["General"], label = L["Preview as"],
      desc = L["Draw every pad as it would look in another situation. Its chips send nothing. It ends when the settings close or combat starts."],
      values = function() return NS.Preview.Choices() end,
      validate = function(v) return NS.Preview.FindPreset(v) ~= nil end },
}
NS.addon.Settings.StampClosureRows(PREVIEW_ROWS)
NS.SchemaRuntime.AddRows(PREVIEW_ROWS)
```

- [ ] **Step 7: The verb**

In `settings/Slash.lua`, `COMMANDS`, after the `test` row, add:
```lua
    {"preview",  L["Preview the pads as another situation — `/qc preview <name>` or `off`; `/qc preview` lists them"],
        function(rest) NS.SlashVerbs.Preview(rest) end},
```
In `settings/SlashVerbs.lua`, add (and change the header's "Today: `check`, `lock` and `unlock`." to "Today: `check`, `lock`, `unlock`, `preview` and `why`."):
```lua
--- The lines `/qc preview [name|off]` prints (spec §14): the menu with the one on now, or the result
--- of switching. A refused start prints its own line from Preview.SetPreviewAs.
--- @return string[]
function V.PreviewLines(rest)
    local P = NS.Preview
    local key = (rest or ""):match("^%s*(%S+)")
    if not key then
        local out = { L["Preview as (now: %s):"]:format(P.Label(P.PreviewAs() or P.CURRENT)) }
        for _, e in ipairs(P.Presets()) do out[#out + 1] = L["  %s: %s"]:format(e.key, e.label) end
        return out
    end
    if key == "off" then key = P.CURRENT end
    if not P.FindPreset(key) then
        return { L["No situation named %s. Type /qc preview for the list."]:format(key) }
    end
    local want = key ~= P.CURRENT and key or nil
    if P.PreviewAs() ~= want and not P.SetPreviewAs(key) then return {} end
    if want then return { L["Previewing: %s"]:format(P.Label(key)) } end
    return { L["Preview off."] }
end

function V.Preview(rest)
    for _, line in ipairs(V.PreviewLines(rest)) do NS.Print(line) end
end
```

- [ ] **Step 8: The diagnostics line**

In `modules/Diagnostics.lua`, `surfaces`, after the `testMode=%s` line, add:
```lua
    out:add("Pad", "previewAs=%s", NS.Preview.PreviewAs() or "off")
```

- [ ] **Step 9: Locale keys**

In `locales/enUS.lua`, under a new comment `-- Preview as… (modules/Preview.lua, settings/SchemaRows.lua, settings/SlashVerbs.lua)`:
```lua
L["Instance %d"] = "Instance %d"
L["Preview as"] = "Preview as"
L["Draw every pad as it would look in another situation. Its chips send nothing. It ends when the settings close or combat starts."] = "Draw every pad as it would look in another situation. Its chips send nothing. It ends when the settings close or combat starts."
L["Preview the pads as another situation — `/qc preview <name>` or `off`; `/qc preview` lists them"] = "Preview the pads as another situation — `/qc preview <name>` or `off`; `/qc preview` lists them"
L["Preview as (now: %s):"] = "Preview as (now: %s):"
L["  %s: %s"] = "  %s: %s"
L["No situation named %s. Type /qc preview for the list."] = "No situation named %s. Type /qc preview for the list."
L["Previewing: %s"] = "Previewing: %s"
L["Preview off."] = "Preview off."
```

- [ ] **Step 10: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS, including `test_disabled` (the new verb answers with the one refusal line while disabled; no event was added), `test_setup`'s degraded case (the session row sits after `settings/SchemaRows.lua`'s early return) and the kit's `test_prose`.

- [ ] **Step 11: Commit**

```bash
git add defaults/GameIds.lua core/Compat.lua .luacheckrc modules/Preview.lua modules/Diagnostics.lua settings/Schema.lua settings/SchemaRows.lua settings/Slash.lua settings/SlashVerbs.lua QuickComms.toc locales/enUS.lua tests/test_preview.lua tests/test_compat.lua tests/test_diagnostics.lua
git checkout -- defaults/GameIds.lua core/Compat.lua .luacheckrc modules/Preview.lua modules/Diagnostics.lua settings/Schema.lua settings/SchemaRows.lua settings/Slash.lua settings/SlashVerbs.lua QuickComms.toc locales/enUS.lua tests/test_preview.lua tests/test_compat.lua tests/test_diagnostics.lua
git commit -m "Preview: the dungeon presets, the Preview as row, /qc preview and the diagnostics line"
```

---

### Task 5: Why is this showing?: the pad header tooltip and `/qc why`

Spec §13.3: "the tooltip on the pad header … lists the groups shown in priority order, with `Resolver.Explain` lines, plus any locks." §14: `why` prints it for every surface. The plan keeps the Resolver's match info for its groups; `Surfaces.WhyLines` turns a pad's last plan into lines; the header's `OnEnter` shows them when `behavior.whyTooltips` is on.

**Files:**
- Modify: `modules/Surfaces.lua` (`BuildPlan` keeps `plan.active`; `WhyLines`)
- Modify: `modules/Pad.lua` (the header's `OnEnter`; `Pad.ShowWhy`)
- Modify: `modules/Pad_Render.lua` (`ShowLines`)
- Modify: `settings/Slash.lua`, `settings/SlashVerbs.lua` (`why`)
- Test: `tests/test_surfaces.lua`, `tests/test_pad.lua`, `tests/test_slash.lua`
- Modify: `locales/enUS.lua`

**Interfaces:**
- Consumes: `NS.Resolver.Explain(name, info)`, `NS.Library.Group`, `NS.Library.IsBuiltin`, `NS.Preview.Label`, `NS.PadRender.LOCK_TEXT`, `NS.Setting("behavior.whyTooltips")`.
- Produces: `plan.active = { [groupId] = { matched = rows } }` (from `Resolver.ActiveGroups`); `NS.Surfaces.WhyLines(id) -> string[]`; `NS.Pad.ShowWhy(id, owner) -> boolean`; `NS.PadRender.ShowLines(owner, title, lines)`; `NS.SlashVerbs.WhyLines() -> string[]`, `NS.SlashVerbs.Why()`; the `why` verb.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_surfaces.lua`:
```lua
test("surfaces: [phase 3] WhyLines names each shown group in order, built-ins marked, then the locks", function()
    local NS = live({})
    local cid = userCallout(NS, { name = "Ask", text = "Raid stack", channel = "raid" })
    local lines = NS.Surfaces.WhyLines("p1")
    -- the open world, solo: only the user group (an empty When) is active, and /raid is locked
    assertEqual(lines[1], "Mine: always on")
    assertEqual(lines[#lines], "Locked: you are not in a raid.")
    assertTrue(cid ~= nil)
end)

test("surfaces: [phase 3] WhyLines in a key explains the built-in's matched row; a preview says so", function()
    local NS = live()
    assertEqual(NS.Surfaces.WhyLines("p1")[1], "M+ (generic) (built-in): Content")
    NS.Preview.SetPreviewAs("arena")
    local lines = NS.Surfaces.WhyLines("p1")
    assertEqual(lines[1], "Preview as: Arena")
    assertEqual(lines[2], "Arena (generic) (built-in): Content")
    NS.Preview.SetPreviewAs("current")
    NS.Preview.SetTestMode(true)
    assertEqual(NS.Surfaces.WhyLines("p1")[1], "Test mode: placeholder chips that send nothing.")
    assertEqual(NS.Surfaces.WhyLines("p9")[1], "This pad has not been built yet.")
end)
```
`live({})` reads empty inputs: solo, open world. `userCallout` and `live` are this suite's helpers.

Append to `tests/test_pad.lua`:
```lua
test("pad: [phase 3] the header's tooltip says why each group shows, unless the player turned it off", function()
    local NS = applied()
    local shown = {}
    NS.PadRender.ShowLines = function(_, title, lines) shown[#shown + 1] = { title = title, lines = lines } end
    local header = NS.Pad.Instance("p1").header
    header:__fire("OnEnter")
    -- red under: drop the Pad.ShowWhy call from the header's OnEnter
    assertEqual(#shown, 1)
    assertEqual(shown[1].title, "Why is this showing?")
    assertEqual(shown[1].lines[1], "M+ (generic) (built-in): Content")
    header:__fire("OnLeave")
    NS.SchemaRuntime.Set("behavior.whyTooltips", false)
    header:__fire("OnEnter")
    assertEqual(#shown, 1, "behavior.whyTooltips off: no tooltip")
end)
```
Append to `tests/test_slash.lua`:
```lua
test("slash: [phase 3] `why` prints each built pad and why its groups show", function()
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function()
        return { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true, keyLevel = 12,
            inGroup = true }
    end
    NS.Situation.RefreshNow("test")
    m.prints = {}
    NS.addon:OnSlashCommand("why")
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("Comms Pad (p1):", 1, true) ~= nil, text)
    assertTrue(text:find("  M+ (generic) (built-in): Content", 1, true) ~= nil, text)
end)
```
(`tests/test_slash.lua` already imports `assertTrue`.)

- [ ] **Step 2: Run the tests to check they fail**

Run: `lua tests/run.lua`
Expected: FAIL (`WhyLines`, `ShowLines` and the `why` verb do not exist).

- [ ] **Step 3: The plan keeps the match info, and WhyLines reads it**

In `modules/Surfaces.lua`, `S.BuildPlan`, change the plan literal to keep the active set:
```lua
    local plan = { surfaceId = surfaceId, snapshot = snap, order = order, sections = {},
        lockdownChip = false, hasActive = #order > 0, active = active }
```
After `S.MarkPreview`, add:
```lua
--- "Why is this showing?" for one pad (spec §13.3): the groups it shows, in priority order, each with
--- the When rows that matched (Resolver.Explain), then every lock in effect on its chips. Read from
--- the pad's last plan, so in combat it explains what is on screen.
--- @return string[]
function S.WhyLines(id)
    local plan = S.Plans()[id]
    if not plan then return { L["This pad has not been built yet."] } end
    if plan.test and not plan.preview then return { L["Test mode: placeholder chips that send nothing."] } end
    local out = {}
    if plan.preview then out[1] = L["Preview as: %s"]:format(NS.Preview.Label(plan.preview)) end
    if #plan.order == 0 then out[#out + 1] = L["No group matches this situation."] end
    for _, gid in ipairs(plan.order) do
        local g = NS.Library.Group(gid)
        local name = g and g.name or gid
        if NS.Library.IsBuiltin(gid) then name = L["%s (built-in)"]:format(name) end
        out[#out + 1] = NS.Resolver.Explain(name, plan.active and plan.active[gid])
    end
    local locks, seen = {}, {}
    for _, sec in ipairs(plan.sections) do
        for _, slot in ipairs(sec.slots) do
            if slot.lock and not seen[slot.lock] then
                seen[slot.lock] = true
                locks[#locks + 1] = slot.lock
            end
        end
    end
    table.sort(locks)
    for _, lock in ipairs(locks) do out[#out + 1] = NS.PadRender.LOCK_TEXT[lock] or tostring(lock) end
    return out
end
```

- [ ] **Step 4: The header shows it**

In `modules/Pad_Render.lua`, after `R.ShowTooltip`, add:
```lua
--- A titled tooltip of plain lines over `owner` (the pad header's "Why is this showing?").
function R.ShowLines(owner, title, lines)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(title)
    for _, line in ipairs(lines or {}) do GameTooltip:AddLine(line, 1, 1, 1, true) end
    GameTooltip:Show()
end
```
In `modules/Pad.lua`, `build`, replace
```lua
    header:SetScript("OnEnter", function() Pad.SetHover(id, true) end)
```
with
```lua
    header:SetScript("OnEnter", function()
        Pad.SetHover(id, true)
        Pad.ShowWhy(id, header)
    end)
```
and, after `Pad.SetHover`, add:
```lua
--- "Why is this showing?" (spec §13.3) over the pad's header, unless behavior.whyTooltips is off.
--- Insecure: a tooltip, shown in combat too.
function Pad.ShowWhy(id, owner)
    if NS.Setting("behavior.whyTooltips") == false then return false end
    R.ShowLines(owner, L["Why is this showing?"], NS.Surfaces.WhyLines(id))
    return true
end
```

- [ ] **Step 5: The verb**

In `settings/Slash.lua`, `COMMANDS`, after the `preview` row, add:
```lua
    {"why",      L["Say why each pad shows the groups it shows"],
        function() NS.SlashVerbs.Why() end},
```
In `settings/SlashVerbs.lua`, add:
```lua
--- The lines `/qc why` prints (spec §14): every built pad, in the pad order, then why it shows what it
--- shows (Surfaces.WhyLines).
--- @return string[]
function V.WhyLines()
    local p = NS.db and NS.db.profile
    local plans = NS.Surfaces.Plans()
    local out = {}
    for _, id in ipairs(p and p.padOrder or {}) do
        if plans[id] then
            out[#out + 1] = L["%s (%s):"]:format(p.pads[id].name or id, id)
            for _, line in ipairs(NS.Surfaces.WhyLines(id)) do out[#out + 1] = "  " .. line end
        end
    end
    if #out == 0 then out[1] = L["No pad is showing: nothing has been built yet."] end
    return out
end

function V.Why()
    for _, line in ipairs(V.WhyLines()) do NS.Print(line) end
end
```

- [ ] **Step 6: Locale keys**

In `locales/enUS.lua`, under a new comment `-- Why is this showing? (modules/Surfaces.lua, modules/Pad.lua, settings/SlashVerbs.lua)`:
```lua
L["This pad has not been built yet."] = "This pad has not been built yet."
L["Test mode: placeholder chips that send nothing."] = "Test mode: placeholder chips that send nothing."
L["Preview as: %s"] = "Preview as: %s"
L["No group matches this situation."] = "No group matches this situation."
L["%s (built-in)"] = "%s (built-in)"
L["Why is this showing?"] = "Why is this showing?"
L["Say why each pad shows the groups it shows"] = "Say why each pad shows the groups it shows"
L["%s (%s):"] = "%s (%s):"
L["No pad is showing: nothing has been built yet."] = "No pad is showing: nothing has been built yet."
```

- [ ] **Step 7: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add modules/Surfaces.lua modules/Pad.lua modules/Pad_Render.lua settings/Slash.lua settings/SlashVerbs.lua locales/enUS.lua tests/test_surfaces.lua tests/test_pad.lua tests/test_slash.lua
git checkout -- modules/Surfaces.lua modules/Pad.lua modules/Pad_Render.lua settings/Slash.lua settings/SlashVerbs.lua locales/enUS.lua tests/test_surfaces.lua tests/test_pad.lua tests/test_slash.lua
git commit -m "Pad: Why is this showing? on the header tooltip and /qc why"
```

**Milestone 1 checkpoint.** `lua tests/run.lua` and `luacheck .` green; every member field, "Preview as…" and "Why" work from the CLI and the pad. Record the checkpoint in this plan's checkboxes before starting Task 6.

---
### Task 6: The editor pages' shared frame, and the page test helpers

What the four pages share lives in one file, so each page file is its band, its tabs and its acts: the selection (`NS.State.editing`, healed to a member that exists), one deferred and coalesced structural repaint, the delete confirmation, the drag-to-reorder list, a "pick to act" dropdown, page registration (a canvas, a Defaults button, the renderer that cancels the reorder list first) and the jump to another page. `tests/page_helpers.lua` drives a page headlessly through the kit's AceGUI recorder, as AuraMaster's does.

**Files:**
- Create: `settings/Editors.lua`; Modify: `QuickComms.toc` (after `settings\Panel.lua`)
- Create: `tests/page_helpers.lua` (a helper, not a suite)
- Create: `tests/test_editors.lua`; Modify: `tests/run.lua` (add `"test_editors",` after `"test_members",`)
- Modify: `locales/enUS.lua`

**Interfaces:**
- Consumes: `Settings.Helpers` (the LibKa0s-Options instance: `RegisterOptionsPage`, `CreatePanel`, `SetRenderer`, `ClearScroll`, `RefreshPanel`, `RenderTabbedSchema`, `RenderGrid`, `EnsureScroll`, `AttachTooltip`, `AceGUI`), `LibStub("LibKa0s-Widgets-1.0").ReorderList`, `NS.Icon("segment")`, `NS.MSG.*`, `NS.Bus:NewTarget()`, `NS.Preview.PreviewSnapshot()`, `NS.Situation.Current()`, `NS.Library.IsBuiltin`, `NS.SchemaRuntime.FindRow`.
- Produces (`Settings.Editors`, read by Tasks 7–11 as `local Ed = Settings.Editors`):
  - `Ed.Selected(kind) -> id|nil`; `Ed.Select(kind, id)` (selecting a group also sets `editing.builtin` to it when it is a built-in, else clears it); `Ed.Heal(kind, ids) -> id|nil`
  - `Ed.Snapshot() -> snapshot` (the preview's when on, else the live one)
  - `Ed.PickerList(entries) -> list, order` (from ordered `{ id, label }`)
  - `Ed.RequestRefresh()` (one structural `RefreshPanel` of every built editor page on the next frame; nothing while no page body has been built); `Ed.Pending() -> boolean`
  - `Ed.STRUCTURAL` (the member-row paths whose write repaints: the names, `group.enabled`, `group.when`, `builtin.enabled`); every other member-row write refreshes in place
  - `Ed.Live(ctx, fn)` (a host refresher for a line the page draws itself: run on every scalar refresh and, through `Ed.RefreshLive()`, on a `SITUATION_CHANGED` that leaves the set of active groups as it was)
  - `Ed.Row(path) -> row|nil`; `Ed.Scalar(rows) -> rows` (drops the structured rows: types `point`, `when`, `idset`)
  - `Ed.ActionDropdown(label, tooltip, entries, onPick[, ctx]) -> RenderGrid item` (`entries` a list, or a function re-read by an `Ed.Live` refresher when `ctx` is given)
  - `Ed.ReorderRows(ctx, pageKey, entries, onMove)`: entries `{ id, label, remove = fn|nil }`, one uniform row each; `onMove(from, to)`; no `onMove` draws the rows with no handles
  - `Ed.CancelReorder(pageKey)`
  - `Ed.Tabs(ctx, pageKey, tabs) -> groups, keys` (`RenderTabbedSchema` with host tabs and `rerender`)
  - `Ed.RegisterPage(pageKey, title, frameSuffix, render, defaults)` (`defaults = { tooltip, onClick(ctx) }`)
  - `Ed.ConfirmDelete(name, onAccept)` (popup `QUICKCOMMS_DELETE_MEMBER`, `onAccept` handed as the popup's data)
  - `Ed.Open(pageKey) -> boolean`
  - `Ed.pages[pageKey] = ctx` (registered), `Ed.built[pageKey] = ctx` (its body drawn at least once), `Ed.categories[pageKey]`, `Ed.redraw[pageKey] = function(ctx)`, `Ed.reorders[pageKey]`
  - `Ed.ACTIVE_DOT` (a texture escape marking an active group)
- `tests/page_helpers.lua` returns `function(NS, m) -> P` with `P.ctx(pageKey)`, `P.show(title)`, `P.redraw(pageKey)`, `P.tab(pageKey, key)`, `P.during(fn)`, `P.flush()`, `P.find(widgets, wtype, label)`, `P.all(widgets, wtype, label)`, `P.texts(widgets)`, `P.hasText(widgets, needle)`, `P.banner(ctx)`, `P.bannerAction(ctx)`, `P.accept()`, `P.reorderSpy()`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_editors.lua`:
```lua
-- tests/test_editors.lua — settings/Editors.lua: what the editor pages share. The selection heals to a
-- member that exists and a profile switch clears it; a change that alters a page's shape asks for ONE
-- structural repaint on the next frame, and a scalar write or a situation change that leaves the
-- active groups alone repaints nothing (options-ui-§11); no page built, no timer; the delete
-- confirmation runs its act only when accepted; the jump opens a page.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function enabled()
    local NS, m = T.enableAddon()
    return NS, m, NS.addon.Settings.Editors
end

-- Count the structural refreshes of a probe page registered as built.
local function probe(NS, Ed)
    local H = NS.addon.Settings.Helpers
    local page, counts = { qcLive = {} }, { structural = 0 }
    Ed.built.probe = page
    local refresh = H.RefreshPanel
    H.RefreshPanel = function(ctx, structural)
        if ctx == page and structural then counts.structural = counts.structural + 1 end
    end
    return page, counts, function()
        H.RefreshPanel = refresh
        Ed.built.probe = nil
    end
end

test("editors: [review 2] Select mirrors a built-in group into the built-in selection; Heal keeps a member that exists", function()
    local NS, _, Ed = enabled()
    Ed.Select("group", "bi.mplus")
    assertEqual(NS.State.editing.builtin, "bi.mplus")
    Ed.Select("group", "g9")
    assertNil(NS.State.editing.builtin)
    Ed.Select("callout", "c5")
    assertEqual(Ed.Heal("callout", { "c1", "c5" }), "c5")
    assertEqual(Ed.Heal("callout", { "c1" }), "c1")
    assertEqual(NS.State.editing.callout, "c1")
    assertNil(Ed.Heal("callout", {}))
    assertNil(NS.State.editing.callout)
end)

test("editors: every membership change asks for one structural repaint, on the next frame", function()
    local NS, m, Ed = enabled()
    local _, counts, done = probe(NS, Ed)
    NS.Library.Touch("callout", "c1")
    NS.Library.Touch("group", "g2")
    assertEqual(counts.structural, 0, "deferred: never under the widget whose callback is running")
    m.__fireTimers()
    -- red under: drop the `pending` check in Ed.RequestRefresh (two repaints)
    assertEqual(counts.structural, 1)
    done()
end)

test("editors: [phase 3] a scalar member write repaints nothing; a name does", function()
    local NS, m, Ed = enabled()
    local _, counts, done = probe(NS, Ed)
    assertTrue(NS.SchemaRuntime.Set("pad.layout.scale", 1.5, "p1"))
    m.__fireTimers()
    -- red under: drop the Ed.STRUCTURAL check from Editors' LIBRARY_CHANGED handler
    assertEqual(counts.structural, 0, "a slider write refreshes in place (options-ui-§11)")
    assertTrue(NS.SchemaRuntime.Set("pad.name", "Main", "p1"))
    m.__fireTimers()
    assertEqual(counts.structural, 1, "a name is a picker label")
    done()
end)

test("editors: [phase 3] a situation change repaints only when the set of active groups changes", function()
    local NS, m, Ed = enabled()
    local page, counts, done = probe(NS, Ed)
    local live = 0
    page.qcLive[1] = function() live = live + 1 end
    NS.addon:SendMessage(NS.MSG.SITUATION_CHANGED)
    m.__fireTimers()
    assertEqual(counts.structural, 1, "the first change primes the active set")
    NS.addon:SendMessage(NS.MSG.SITUATION_CHANGED)
    m.__fireTimers()
    -- red under: drop the active-set comparison from Editors' SITUATION_CHANGED handler
    assertEqual(counts.structural, 1, "the same active groups: no repaint")
    assertEqual(live, 1, "the live lines refresh in place")
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    m.__fireTimers()
    assertEqual(counts.structural, 2, "a key started: the M+ set is active now")
    done()
end)

test("editors: [phase 3] with no page body built, no change schedules a repaint", function()
    local NS, _, Ed = enabled()
    NS.Library.Touch("callout", "c1")
    NS.addon:SendMessage(NS.MSG.SITUATION_CHANGED)
    -- red under: drop `next(Ed.built) == nil` from Ed.RequestRefresh (a timer for a player who never opens the settings)
    assertFalse(Ed.Pending())
end)

test("editors: a profile switch clears every selection", function()
    local NS, _, Ed = enabled()
    Ed.Select("callout", "c1")
    Ed.Select("pad", "p1")
    NS.addon.db:SetProfile("Other")
    assertNil(NS.State.editing.callout)
    assertNil(NS.State.editing.pad)
end)

test("editors: the stand-down cancels a pending repaint", function()
    local NS, m, Ed = enabled()
    local _, counts, done = probe(NS, Ed)
    NS.Library.Touch("callout", "c1")
    assertTrue(Ed.Pending())
    NS.SchemaRuntime.Set("enabled", false)
    m.__fireTimers()
    assertEqual(counts.structural, 0)
    assertFalse(Ed.Pending())
    done()
end)

test("editors: ConfirmDelete asks first, and only the accepted popup runs the act, once", function()
    local _, m, Ed = enabled()
    local ran = 0
    Ed.ConfirmDelete("Lust", function() ran = ran + 1 end)
    local shown = m.popupsShown[#m.popupsShown]
    assertEqual(shown[1], "QUICKCOMMS_DELETE_MEMBER")
    assertEqual(shown[2], "Lust")
    assertEqual(ran, 0)
    m.StaticPopupDialogs[shown[1]].OnAccept(nil, shown[4])
    assertEqual(ran, 1)
    assertTrue(m.StaticPopupDialogs[shown[1]].text:find("%s", 1, true) ~= nil, "names what is deleted")
end)

test("editors: Open goes to a page's category by its id", function()
    local _, m, Ed = enabled()
    local opened
    m.Settings.OpenToCategory = function(id) opened = id end
    Ed.categories.probe = { GetID = function() return 42 end }
    assertTrue(Ed.Open("probe"))
    assertEqual(opened, 42)
    assertFalse(Ed.Open("nope"))
    Ed.categories.probe = nil
end)

test("editors: Scalar keeps the rows the flow engine draws, and CancelReorder cancels once", function()
    local _, _, Ed = enabled()
    local rows = Ed.Scalar({ { path = "a", type = "string" }, { path = "b", type = "when" }, { path = "c", type = "number" } })
    assertEqual(#rows, 2)
    assertEqual(rows[2].path, "c")
    local n = 0
    Ed.reorders.probe = { Cancel = function() n = n + 1 end }
    Ed.CancelReorder("probe")
    Ed.CancelReorder("probe")
    assertEqual(n, 1)
end)

test("editors: Snapshot is the preview's while Preview as is on", function()
    local NS, _, Ed = enabled()
    NS.Situation.RefreshNow("test")
    assertEqual(Ed.Snapshot().content, NS.Situation.Current().content)
    NS.Preview.SetPreviewAs("arena")
    assertEqual(Ed.Snapshot().content, "arena")
end)
```
In `tests/run.lua`, add `"test_editors",` after `"test_members",`.

- [ ] **Step 2: Run the tests to check they fail**

Run: `lua tests/run.lua`
Expected: FAIL (`NS.addon.Settings.Editors` is nil).

- [ ] **Step 3: The shared frame**

Create `settings/Editors.lua`:
```lua
local addonName, NS = ...
-- settings/Editors.lua — what the editor pages share (design spec §13.1): Callouts, Groups, Comms Pad
-- and Share each register here, keep their selection here and repaint through here.
--
-- THE SELECTION is session state (NS.State.editing[kind], never saved): the member each page edits.
-- The band's picker sets it (options-ui-§14: the banner is the ONLY picker), and the member rows
-- resolve against it when the panel or the CLI writes with no instance argument (settings/Schema.lua).
-- Heal keeps it on a member that exists; a profile switch clears it (the ids were the old profile's).
--
-- THE REPAINT (options-ui-§11: re-render only when what invalidates the layout changed, never on every
-- write). A member changes from a widget's own callback, a popup, a slash verb, the pad's drag or a
-- profile switch. A structural refresh of every built page, ONE, on the next frame and coalesced (so
-- no page is torn down under the widget whose callback is running; a hidden page is only marked
-- owed), follows: a LIBRARY_CHANGED with no field (membership, order, Customize) or naming a field in
-- STRUCTURAL (a name is a picker label; a group's Enabled and When, and a set's Enabled, move the
-- active-now dot and the When tab's rows); a SITUATION_CHANGED that changes the set of active
-- groups; TEST_MODE_CHANGED (Preview as…); PROFILE_CHANGED. Any other member-row write is a scalar:
-- the seam's announce refreshes the widgets in place (Helpers.RefreshAll), and the lines a page draws
-- itself (Ed.Live) with them. A SITUATION_CHANGED that leaves the active groups alone re-runs only
-- those lines, never the library's own refreshers, so a box the player is typing in keeps its text.
-- Until a page body has been built nothing is scheduled at all.
--
-- THE REORDER LISTS are LibKa0s-Widgets' ReorderList (options-ui-§18): one controller per page,
-- canceled at the top of every render (RegisterPage's redraw, which a tab click also runs through
-- `rerender`) before ClearScroll gives the row frames back to AceGUI. Without the library there is
-- no handle and the list does not drag: the accepted degradation, with no host-drawn arrows.

local QC = NS.addon
local Settings = QC.Settings
local L = NS.L
local State = NS.State

Settings.Editors = Settings.Editors or {}
local Ed = Settings.Editors

Ed.ROW_H = 30       -- one reorderable row; the drop arithmetic's stride
Ed.HANDLE_W = 30    -- the library's handle gutter (LibKa0s-Widgets ROW_BOX.HANDLE_W)
Ed.ACTIVE_DOT = "|TInterface\\COMMON\\Indicator-Green:12|t "
Ed.pages, Ed.built, Ed.categories, Ed.reorders, Ed.redraw = {}, {}, {}, {}, {}

local function H() return Settings.Helpers end

-- ── the selection ───────────────────────────────────────────────────────────────────────────

function Ed.Selected(kind)
    return State.editing[kind]
end

--- Select the member a page edits. A built-in group is also the built-in overlay's selection, so the
--- `builtin.*` rows address the set the Groups page shows.
function Ed.Select(kind, id)
    State.editing[kind] = id
    if kind == "group" then
        State.editing.builtin = (id ~= nil and NS.Library.IsBuiltin(id)) and id or nil
    end
end

--- Keep a page's selection on a member that exists: the current one, else the first of `ids`.
--- @return string|nil the selection
function Ed.Heal(kind, ids)
    local current = State.editing[kind]
    for _, id in ipairs(ids) do
        if id == current then return current end
    end
    Ed.Select(kind, ids[1])
    return ids[1]
end

--- The snapshot an editor shows its lines against: the previewed one while "Preview as…" is on.
function Ed.Snapshot()
    return NS.Preview.PreviewSnapshot() or NS.Situation.Current()
end

--- O.PageBanner's list and order, from ordered { id, label } entries.
function Ed.PickerList(entries)
    local list, order = {}, {}
    for i, e in ipairs(entries) do
        list[e.id] = e.label
        order[i] = e.id
    end
    return list, order
end

-- ── the repaint ─────────────────────────────────────────────────────────────────────────────

local pending, lastActive

--- The member-row paths whose write changes what a page draws, not only a value in place.
Ed.STRUCTURAL = { ["callout.name"] = true, ["group.name"] = true, ["group.enabled"] = true,
    ["group.when"] = true, ["pad.name"] = true, ["builtin.enabled"] = true }

-- The ids of the groups active under the editors' snapshot, as one comparable string.
local function activeKey()
    if not (NS.db and NS.db.profile) then return "" end
    local ids = {}
    for id in pairs(NS.Resolver.ActiveGroups(NS.Library.AllGroups(), Ed.Snapshot())) do ids[#ids + 1] = id end
    table.sort(ids)
    return table.concat(ids, ",")
end

--- One structural refresh of every built editor page, on the next frame, however many changes ask.
--- Nothing is scheduled while no page body has been built (a player who never opens the settings).
function Ed.RequestRefresh()
    if pending or next(Ed.built) == nil then return end
    pending = QC:ScheduleTimer(function()
        pending = nil
        lastActive = activeKey()
        local h = H()
        if not (h and h.RefreshPanel) then return end
        for _, ctx in pairs(Ed.built) do h.RefreshPanel(ctx, true) end
    end, 0)
end

function Ed.Pending()
    return pending ~= nil
end

--- A line the page draws itself (the baked line, the active-now line, the token list): `fn` puts it
--- back to current state in place. It runs with the library's refreshers on every scalar write, and
--- on its own on a situation change that leaves the active groups alone (Ed.RefreshLive).
function Ed.Live(ctx, fn)
    ctx.qcLive = ctx.qcLive or {}
    ctx.qcLive[#ctx.qcLive + 1] = fn
    if ctx.refreshers then ctx.refreshers[#ctx.refreshers + 1] = fn end
end

function Ed.RefreshLive()
    for _, ctx in pairs(Ed.built) do
        for _, fn in ipairs(ctx.qcLive or {}) do pcall(fn) end
    end
end

local function onLibraryChanged(_, _, _, field)
    if field ~= nil and not Ed.STRUCTURAL[field] then return end
    Ed.RequestRefresh()
end

local function onSituationChanged()
    if next(Ed.built) == nil then return end
    local key = activeKey()
    if key ~= lastActive then
        lastActive = key
        return Ed.RequestRefresh()
    end
    Ed.RefreshLive()
end

local function onProfileChanged()
    for kind in pairs(State.editing) do State.editing[kind] = nil end
    Ed.RequestRefresh()
end

local HANDLERS = {
    { NS.MSG.LIBRARY_CHANGED, onLibraryChanged },
    { NS.MSG.SITUATION_CHANGED, onSituationChanged },
    { NS.MSG.TEST_MODE_CHANGED, function() Ed.RequestRefresh() end },
    { NS.MSG.PROFILE_CHANGED, onProfileChanged },
}

-- Its own target (core/Bus.lua): one target holds several different messages.
local receiver
local function listen()
    receiver = receiver or NS.Bus:NewTarget()
    if not receiver then return end
    for _, h in ipairs(HANDLERS) do receiver:RegisterMessage(h[1], h[2]) end
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if pending then QC:CancelTimer(pending) end
    pending, lastActive = nil, nil
    if receiver and not NS.Bus.tracked then
        for _, h in ipairs(HANDLERS) do receiver:UnregisterMessage(h[1]) end
    end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end

-- ── rows ────────────────────────────────────────────────────────────────────────────────────

function Ed.Row(path)
    return NS.SchemaRuntime.FindRow(path)
end

-- The structured member rows (settings/SchemaMembers.lua): a table each, drawn by the page's own controls.
local STRUCTURED = { point = true, when = true, idset = true }

--- The rows the flow engine draws: a structured row has its own control on its page.
function Ed.Scalar(rows)
    local out = {}
    for _, row in ipairs(rows or {}) do
        if not STRUCTURED[row.type] then out[#out + 1] = row end
    end
    return out
end

--- A dropdown that acts on the choice at once ("Add a callout", "Insert a token"), as a RenderGrid item.
--- `entries` is a list, or a function; with `ctx`, a function is re-read in place (Ed.Live), so a
--- list that depends on a field (the token list on the callout's channel) follows it without a repaint.
function Ed.ActionDropdown(label, tooltip, entries, onPick, ctx)
    local function current()
        if type(entries) == "function" then return entries() end
        return entries
    end
    return { make = function(_, parent, rel)
        local h = H()
        local dd = h.AceGUI:Create("Dropdown")
        dd:SetLabel(label)
        local list, order = Ed.PickerList(current())
        dd:SetList(list, order)
        if ctx and type(entries) == "function" then
            Ed.Live(ctx, function() dd:SetList(Ed.PickerList(current())) end)
        end
        dd:SetRelativeWidth(rel or 0.5)
        dd:SetCallback("OnValueChanged", function(_, _, key) onPick(key) end)
        h.AttachTooltip(dd, label, tooltip)
        parent:AddChild(dd)
        return dd
    end }
end

-- ── the reorder lists (options-ui-§18) ──────────────────────────────────────────────────────

function Ed.CancelReorder(pageKey)
    local r = Ed.reorders[pageKey]
    Ed.reorders[pageKey] = nil
    if r then r:Cancel() end
end

local function newReorder(pageKey, onMove)
    local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)
    if not (W and W.ReorderList) then return nil end
    local r = W.ReorderList{
        stride        = Ed.ROW_H,
        handleIcon    = NS.Icon("segment"),
        handleTooltip = L["Drag to reorder"],
        onMove        = onMove,
    }
    Ed.reorders[pageKey] = r
    return r
end

--- One uniform row per entry ({ id, label, remove = fn|nil }): the library's handle in the gutter at
--- the left, the label, and Remove at the right. With `onMove(from, to)` the rows drag; the list's one
--- write and one repaint are the host's (Library, then LIBRARY_CHANGED).
function Ed.ReorderRows(ctx, pageKey, entries, onMove)
    local h = H()
    local scroll = h.EnsureScroll(ctx)
    if not (h.AceGUI and scroll) then return end
    local built, items = {}, {}
    for i, e in ipairs(entries) do
        items[i] = { wide = true, make = function(_, into)
            local AceGUI = h.AceGUI
            into:SetLayout("Flow")
            into:SetAutoAdjustHeight(false)
            into:SetHeight(Ed.ROW_H)
            local gutter = AceGUI:Create("Label")
            gutter:SetText("")
            gutter:SetWidth(Ed.HANDLE_W)
            into:AddChild(gutter)
            local label = AceGUI:Create("Label")
            label:SetText(e.label)
            label:SetRelativeWidth(e.remove and 0.62 or 0.85)
            into:AddChild(label)
            if e.remove then
                local b = AceGUI:Create("Button")
                b:SetText(L["Remove"])
                b:SetRelativeWidth(0.25)
                b:SetCallback("OnClick", function() e.remove() end)
                into:AddChild(b)
            end
            built[#built + 1] = { group = into, entry = e }
            return true
        end }
    end
    h.RenderGrid(ctx, items, scroll, { gap = false })
    if not onMove then return end
    local r = newReorder(pageKey, onMove)
    if not r then return end
    for _, b in ipairs(built) do r:AddRow(b.group.frame, { ghostText = b.entry.label }) end
    r:Finish(scroll.content or scroll.frame)
end

-- ── pages ───────────────────────────────────────────────────────────────────────────────────

--- The strip and the active tab, through the library's tabbed renderer with the page's host tabs. A
--- tab click runs the page's whole redraw (`rerender`), so the reorder cancel and the band come first.
function Ed.Tabs(ctx, pageKey, tabs)
    return H().RenderTabbedSchema(ctx, pageKey, nil, nil, { tabs = tabs, rerender = Ed.redraw[pageKey] })
end

--- Register one editor page (options-ui-§3, §5): its canvas, a body built on first show, its place in
--- the sidebar and its Defaults button (`defaults = { tooltip, onClick(ctx) }`; options-ui-§13: its
--- blast radius is the selected member). `render(ctx)` draws the band, the strip and the active tab.
function Ed.RegisterPage(pageKey, title, frameSuffix, render, defaults)
    local function redraw(ctx)
        Ed.CancelReorder(pageKey)
        H().ClearScroll(ctx)
        ctx.qcLive = {}
        Ed.built[pageKey] = ctx
        render(ctx)
    end
    Ed.redraw[pageKey] = redraw
    H().RegisterOptionsPage(pageKey, title, function(parentCategory)
        local h = H()
        local ctx = h.CreatePanel(addonName .. frameSuffix, title, {
            pageKey = pageKey, defaultsButton = true, defaultsTooltip = defaults.tooltip })
        ctx.panel.defaultsOnClick = function() defaults.onClick(ctx) end
        h.SetRenderer(ctx, redraw)
        Ed.pages[pageKey] = ctx
        local category = _G.Settings.RegisterCanvasLayoutSubcategory(parentCategory, ctx.panel, title)
        Ed.categories[pageKey] = category
        return category
    end)
end

-- ── acts ────────────────────────────────────────────────────────────────────────────────────

local DELETE_POPUP = "QUICKCOMMS_DELETE_MEMBER"

--- Ask before deleting `name`; `onAccept` runs only when the player accepts. It is the popup's data,
--- so a popup accepted after combat started still runs it: a delete is a data write, and the pads
--- pick it up at combat end.
function Ed.ConfirmDelete(name, onAccept)
    StaticPopupDialogs[DELETE_POPUP] = StaticPopupDialogs[DELETE_POPUP] or {
        text         = L["Delete '%s'? This cannot be undone."],
        button1      = YES or "Yes",
        button2      = NO or "No",
        timeout      = 0,
        whileDead    = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnAccept     = function(_, data) if type(data) == "function" then data() end end,
    }
    StaticPopup_Show(DELETE_POPUP, name, nil, onAccept)
end

--- Open the settings at another editor page (a "Used by" link, Customize). The page repaints from
--- the selection the caller set.
--- @return boolean opened
function Ed.Open(pageKey)
    Ed.RequestRefresh()
    local category = Ed.categories[pageKey]
    local S = _G.Settings
    if not (category and type(category.GetID) == "function" and S and S.OpenToCategory) then return false end
    S.OpenToCategory(category:GetID())
    return true
end
```
In `QuickComms.toc`, after `settings\Panel.lua`, add:
```
# LOAD-BEARING: publishes Settings.Editors, which the four page files below take at load; reads NS.MSG
# and NS.Bus at load.
settings\Editors.lua
```

- [ ] **Step 4: The page test helpers**

Create `tests/page_helpers.lua`:
```lua
-- tests/page_helpers.lua — drives an editor page the way a player does, on a fresh environment.
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit; shaped after
-- AuraMaster's tests/page_helpers.lua. The kit's AceGUI fake records every widget it hands out
-- (`__created`) and exposes `__fire`, and the kit's panels expose `__fire` for the deferred OnShow
-- render, so a page can be drawn and clicked headlessly. `redraw` runs a page's whole render as a
-- tab click or a repaint does; `tab` is a tab click (the library sets `activeTab` and calls the
-- page's `rerender`).
return function(NS, m)
    local P = {}
    local ace = m.LibStub("AceGUI-3.0")
    local Settings = NS.addon.Settings
    local H = Settings.Helpers

    local function since(mark)
        local out = {}
        for i = mark + 1, #ace.__created do
            local w = ace.__created[i]
            if not w.__released then out[#out + 1] = w end
        end
        return out
    end

    function P.ctx(pageKey) return H.__panelFor(pageKey) end

    --- Fire a page's OnShow by its sidebar title; answers the widgets the render drew.
    function P.show(title)
        local mark = #ace.__created
        m.__subcategories[title]:__fire("OnShow")
        return since(mark)
    end

    --- Run a page's whole render now; answers the widgets it drew.
    function P.redraw(pageKey)
        local mark = #ace.__created
        Settings.Editors.redraw[pageKey](P.ctx(pageKey))
        return since(mark)
    end

    --- A tab click: the active tab moves and the page's rerender draws it.
    function P.tab(pageKey, key)
        P.ctx(pageKey).activeTab = key
        return P.redraw(pageKey)
    end

    --- The widgets `fn` creates while it runs.
    function P.during(fn)
        local mark = #ace.__created
        fn()
        return since(mark)
    end

    --- Run the deferred repaint (Editors.RequestRefresh) and every other queued timer.
    function P.flush() m.__fireTimers() end

    function P.find(widgets, wtype, label)
        for _, w in ipairs(widgets) do
            if (wtype == nil or w.type == wtype) and (w.labelText == label or w.text == label) then return w end
        end
        return nil
    end

    function P.all(widgets, wtype, label)
        local out = {}
        for _, w in ipairs(widgets) do
            if w.type == wtype and (label == nil or w.labelText == label or w.text == label) then out[#out + 1] = w end
        end
        return out
    end

    --- The texts of the Label and InteractiveLabel widgets, in draw order.
    function P.texts(widgets)
        local out = {}
        for _, w in ipairs(widgets) do
            if (w.type == "Label" or w.type == "InteractiveLabel") and w.text then out[#out + 1] = w.text end
        end
        return out
    end

    function P.hasText(widgets, needle)
        for _, t in ipairs(P.texts(widgets)) do
            if t:find(needle, 1, true) then return true end
        end
        return false
    end

    -- The live AceGUI widget of `wtype` whose frame the library's chrome ledger lists.
    local function inBand(ctx, wtype)
        local band = {}
        for _, f in ipairs(ctx and ctx.__chromeKids or {}) do band[f] = true end
        for i = #ace.__created, 1, -1 do
            local w = ace.__created[i]
            if w.type == wtype and w.frame and band[w.frame] and not w.__released then return w end
        end
        return nil
    end

    --- The page banner's picker (O.PageBanner's Dropdown) and its create action (its Button).
    function P.banner(ctx) return inBand(ctx, "Dropdown") end
    function P.bannerAction(ctx) return inBand(ctx, "Button") end

    --- Accept the last popup shown, as the player's Yes does.
    function P.accept()
        local shown = m.popupsShown[#m.popupsShown]
        m.StaticPopupDialogs[shown[1]].OnAccept(nil, shown[4])
    end

    --- Record every ReorderList built from here on: { opts, rows } per list, latest last.
    function P.reorderSpy()
        local W = m.LibStub("LibKa0s-Widgets-1.0")
        local real = W.ReorderList
        local lists = {}
        W.ReorderList = function(opts)
            local r = real(opts)
            local seen = { opts = opts, rows = 0 }
            lists[#lists + 1] = seen
            local add = r.AddRow
            r.AddRow = function(self, ...)
                seen.rows = seen.rows + 1
                return add(self, ...)
            end
            return r
        end
        return lists
    end

    return P
end
```

- [ ] **Step 5: Locale keys**

In `locales/enUS.lua`, under a new comment `-- Editor pages (settings/Editors.lua)`:
```lua
L["Drag to reorder"] = "Drag to reorder"
L["Remove"] = "Remove"
L["Delete '%s'? This cannot be undone."] = "Delete '%s'? This cannot be undone."
```

- [ ] **Step 6: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS. luacheck knows `YES`, `NO`, `StaticPopup_Show`, `StaticPopupDialogs`, `Settings` and `LibStub` already (`.luacheckrc`).

- [ ] **Step 7: Commit**

```bash
git add settings/Editors.lua tests/page_helpers.lua tests/test_editors.lua tests/run.lua QuickComms.toc locales/enUS.lua
git checkout -- settings/Editors.lua tests/page_helpers.lua tests/test_editors.lua tests/run.lua QuickComms.toc locales/enUS.lua
git commit -m "Settings: the editor pages' shared frame (selection, repaint, reorder lists, delete) and the page test helpers"
```

---
### Task 7: The Callouts page

Spec §13.1, as ruled toward options-ui-§14: a banner with the callout picker and "New callout"; a `General` tab with the callout's rows, "Insert a token", the live line it sends here (under the current or previewed situation, with the bake's reason or the lock), then Duplicate and Delete; a `Used by` tab listing the groups that hold it, each a link to the Groups page. Only user callouts are listed: a built-in callout is copied when a group takes it (spec P2).

**Files:**
- Create: `settings/Callouts.lua`; Modify: `QuickComms.toc` (after `settings\Editors.lua`)
- Create: `tests/test_page_callouts.lua`; Modify: `tests/run.lua` (add `"test_page_callouts",` after `"test_editors",`)
- Modify: `locales/enUS.lua`

**Interfaces:**
- Consumes: Task 6's `Ed.*` (`Live`, the `ActionDropdown` with a function list); Task 3a's `callout.*` rows; `NS.Library.MemberIds`, `CreateCallout`, `DuplicateCallout`, `DeleteCallout`, `UsedBy`; `NS.Bake.Bake(callout, snap, opts) -> line, reason, info{ length, lock, unknown, missing, selfPrint }`; `NS.Surfaces.BakeContext(snap)`; `NS.PadRender.REASON_TEXT`, `LOCK_TEXT`; `NS.Preview.PreviewAs()`, `Label`.
- Produces (`Settings.Callouts`, used by Task 9's Preview tab): `C.Entries() -> { { id, label } }` (in `Library.MemberIds("callout")` order); `C.Create() -> id|nil`; `C.Duplicate(id) -> id|nil`; `C.Delete(id)`; `C.InsertToken(id, token) -> boolean`; `C.PreviewLines(callout) -> string[]` (first line is what it sends, or why it sends nothing); `C.OpenGroup(groupId) -> boolean`; `C.TOKENS` (offered on every channel); `C.TokensFor(channel) -> string[]` (adds `{group1}`–`{group8}` when the channel can resolve to Raid, spec §8.1).

- [ ] **Step 1: Write the failing tests**

Create `tests/test_page_callouts.lua`:
```lua
-- tests/test_page_callouts.lua — settings/Callouts.lua (spec §13.1): the banner's picker and New
-- callout, the General tab's rows, token insert, live line and acts, and the Used by tab. Driven
-- headlessly through tests/page_helpers.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function open(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or {} end
    NS.Situation.RefreshNow("test")
    local P = dofile("tests/page_helpers.lua")(NS, m)
    P.show("Callouts")
    return NS, m, P
end

test("callouts page: with no callouts it says how to make one, and New callout makes and selects one", function()
    local NS, _, P = open()
    local w = P.redraw("callouts")
    assertTrue(P.hasText(w, "No callouts yet"))
    P.bannerAction(P.ctx("callouts")):__fire("OnClick")
    P.flush()
    local id = NS.State.editing.callout
    assertTrue(id ~= nil and NS.db.profile.callouts[id] ~= nil)
    w = P.redraw("callouts")
    assertEqual(P.find(w, "EditBox", "Name").text, "New callout")
    assertEqual(P.banner(P.ctx("callouts")).value, id)
end)

test("callouts page: the rows write the selected callout through the seam", function()
    local NS, _, P = open()
    local id = NS.addon.Settings.Callouts.Create()
    local w = P.redraw("callouts")
    P.find(w, "EditBox", "Name"):__fire("OnEnterPressed", "Bloodlust")
    P.find(w, "EditBox", "Text"):__fire("OnEnterPressed", "Lust now")
    P.find(w, "Dropdown", "Channel"):__fire("OnValueChanged", "party")
    local c = NS.db.profile.callouts[id]
    assertEqual(c.name, "Bloodlust")
    assertEqual(c.text, "Lust now")
    assertEqual(c.channel, "party")
end)

test("callouts page: [review 5] an empty name is refused and nothing changes", function()
    local NS, _, P = open()
    local id = NS.addon.Settings.Callouts.Create()
    local w = P.redraw("callouts")
    P.find(w, "EditBox", "Name"):__fire("OnEnterPressed", "")
    assertEqual(NS.db.profile.callouts[id].name, "New callout")
end)

test("callouts page: [phase 3] the token picker offers {group1}-{group8} only when the channel can resolve to Raid", function()
    local NS = open()
    local C = NS.addon.Settings.Callouts
    local function has(channel, token)
        for _, t in ipairs(C.TokensFor(channel)) do
            if t == token then return true end
        end
        return false
    end
    -- red under: drop the RAID_CAPABLE branch from C.TokensFor (spec §8.1)
    assertFalse(has("party", "{group1}"))
    assertFalse(has("say", "{group8}"))
    assertTrue(has("raid", "{group1}"))
    assertTrue(has("raidWarning", "{group8}"))
    assertTrue(has("smartGroup", "{group4}"))
    assertTrue(has("smartLead", "{group4}"))
    assertTrue(has("party", "{skull}"), "the markers are offered everywhere")
end)

test("callouts page: [phase 3] the live line refreshes in place when the callout changes", function()
    local NS, _, P = open(MPLUS)
    local id = NS.addon.Settings.Callouts.Create()
    NS.SchemaRuntime.Set("callout.channel", "party", id)
    NS.SchemaRuntime.Set("callout.text", "Pull", id)
    local w = P.redraw("callouts")
    local line
    for _, label in ipairs(P.all(w, "Label")) do
        if label.text and label.text:find("Sends:", 1, true) then line = label end
    end
    assertTrue(line ~= nil)
    NS.SchemaRuntime.Set("callout.text", "Kick", id)
    NS.addon.Settings.Editors.RefreshLive()
    -- red under: draw the live line without its Ed.Live refresher in settings/Callouts.lua
    assertTrue(line.text:find("Sends: /p Kick", 1, true) ~= nil, line.text)
end)

test("callouts page: Insert a token adds it to the end of the text", function()
    local NS, _, P = open()
    local id = NS.addon.Settings.Callouts.Create()
    NS.SchemaRuntime.Set("callout.text", "Kick", id)
    local w = P.redraw("callouts")
    P.find(w, "Dropdown", "Insert a token"):__fire("OnValueChanged", "{target}")
    assertEqual(NS.db.profile.callouts[id].text, "Kick {target}")
end)

test("callouts page: the live line shows what it sends here, or why it sends nothing", function()
    local NS, _, P = open(MPLUS)
    local id = NS.addon.Settings.Callouts.Create()
    NS.SchemaRuntime.Set("callout.text", "Pulling {rt8}", id)
    NS.SchemaRuntime.Set("callout.channel", "party", id)
    local w = P.redraw("callouts")
    assertTrue(P.hasText(w, "Sends: /p Pulling {rt8}"))
    assertTrue(P.hasText(w, "of 255 bytes"))
    -- [review 5] text that starts with / is stored, and the page says at once that it sends nothing
    NS.SchemaRuntime.Set("callout.text", "/run x", id)
    assertEqual(NS.db.profile.callouts[id].text, "/run x")
    w = P.redraw("callouts")
    assertTrue(P.hasText(w, "Sends nothing here: Callout text cannot start with /."))
    -- under a previewed raid, a party callout is fine; a raid one in the open world is padlocked
    NS.SchemaRuntime.Set("callout.text", "Stack", id)
    NS.SchemaRuntime.Set("callout.channel", "raid", id)
    NS.Situation.ReadInputs = function() return {} end
    NS.Situation.RefreshNow("test")
    w = P.redraw("callouts")
    assertTrue(P.hasText(w, "Locked: you are not in a raid."))
    NS.Preview.SetPreviewAs("raid:heroic")
    w = P.redraw("callouts")
    assertFalse(P.hasText(w, "Locked: you are not in a raid."))
    assertTrue(P.hasText(w, "Previewing: Raid"))
end)

test("callouts page: Duplicate selects the copy; Delete asks, then removes it from every group", function()
    local NS, _, P = open()
    local C = NS.addon.Settings.Callouts
    local id = C.Create()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.Library.AddToGroup(gid, id)
    local w = P.redraw("callouts")
    P.find(w, "Button", "Duplicate"):__fire("OnClick")
    local copy = NS.State.editing.callout
    assertTrue(copy ~= id)
    assertEqual(NS.db.profile.callouts[copy].name, "New callout (copy)")
    NS.addon.Settings.Editors.Select("callout", id)
    w = P.redraw("callouts")
    P.find(w, "Button", "Delete"):__fire("OnClick")
    assertTrue(NS.db.profile.callouts[id] ~= nil, "asks first")
    P.accept()
    assertNil(NS.db.profile.callouts[id])
    assertEqual(#NS.db.profile.groups[gid].callouts, 0)
end)

test("callouts page: [review 2] the selected callout deleted elsewhere: the page heals, writes go to the next", function()
    local NS, _, P = open()
    local C = NS.addon.Settings.Callouts
    local first = C.Create()
    NS.SchemaRuntime.Set("callout.name", "Alpha", first)
    local second = C.Create()
    NS.SchemaRuntime.Set("callout.name", "Beta", second)
    NS.addon.Settings.Editors.Select("callout", second)
    P.redraw("callouts")
    NS.Library.DeleteCallout(second)      -- as the Groups page or a profile reset would
    P.flush()
    local w = P.redraw("callouts")
    assertEqual(NS.State.editing.callout, first)
    assertEqual(P.find(w, "EditBox", "Name").text, "Alpha")
    assertTrue(NS.SchemaRuntime.Set("callout.text", "x"))
    assertEqual(NS.db.profile.callouts[first].text, "x")
    assertNil(NS.db.profile.callouts[second])
end)

test("callouts page: Used by lists the groups that hold it, and a click opens that group", function()
    local NS, m, P = open()
    local C = NS.addon.Settings.Callouts
    local id = C.Create()
    local w = P.tab("callouts", "usedBy")
    assertTrue(P.hasText(w, "No group holds this callout yet"))
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.Library.AddToGroup(gid, id)
    local opened
    m.Settings.OpenToCategory = function(cid) opened = cid end
    NS.addon.Settings.Editors.categories.groups = { GetID = function() return 9 end }
    w = P.tab("callouts", "usedBy")
    local link = P.find(w, "InteractiveLabel", "Mine")
    assertTrue(link ~= nil)
    link:__fire("OnClick")
    assertEqual(NS.State.editing.group, gid)
    assertEqual(opened, 9)
end)
```
In `tests/run.lua`, add `"test_page_callouts",` after `"test_editors",`.

- [ ] **Step 2: Run the tests to check they fail**

Run: `lua tests/run.lua`
Expected: FAIL (`m.__subcategories.Callouts` is nil: no page).

- [ ] **Step 3: The page**

Create `settings/Callouts.lua`:
```lua
local _, NS = ...
-- settings/Callouts.lua — the Callouts page (design spec §13.1): one callout at a time.
--
--     band     [ Callout v (picker)        ][ New callout ]
--     strip    [ General ][ Used by ]
--     General  Name, Text, Channel, Icon (the member rows, settings/SchemaMembers.lua), Insert a
--              token, then what it sends here (the baked line and its bytes, or why it sends
--              nothing, and any lock), then Duplicate and Delete
--     Used by  every group that holds it, each a link to the Groups page
--
-- The band holds the picker and the create action and nothing else (options-ui-§14); the acts on
-- the selected callout are the General tab's, which is first. Every field writes through the seam to
-- the selected callout (NS.State.editing.callout). A name change repaints the page (the picker's
-- label, settings/Editors.lua); any other field refreshes in place, the baked line and the token list
-- with it (Ed.Live), so the byte count follows each committed write (Enter), not each keystroke.
-- Built-in callouts are not listed: a group copies one when it takes it (spec P2), and the copy is
-- then edited here.

local QC = NS.addon
local Settings = QC.Settings
local Ed = Settings.Editors
local L = NS.L

local PAGE = "callouts"
local GENERAL = L["General"]

Settings.Callouts = Settings.Callouts or {}
local C = Settings.Callouts

-- The picker's tokens (spec §8.1). The eight raid markers are offered by name ({star} to {skull});
-- a typed {rt1} to {rt8} works the same. {spell:ID} needs an id, so it is typed, never picked.
C.TOKENS = { "{target}", "{focus}", "{skull}", "{cross}", "{square}", "{moon}", "{triangle}", "{diamond}",
    "{circle}", "{star}", "{me}", "{spec}", "{role}", "{key}", "{dungeon}" }

-- The channels that can resolve to Raid (spec §8.2), where {group1} to {group8} expand.
local RAID_CAPABLE = { raid = true, raidWarning = true, smartGroup = true, smartLead = true }

--- The tokens the picker offers for a channel: C.TOKENS, plus {group1} to {group8} only when the
--- channel can resolve to Raid (spec §8.1).
function C.TokensFor(channel)
    local out = {}
    for i, token in ipairs(C.TOKENS) do out[i] = token end
    if RAID_CAPABLE[channel] then
        for n = 1, 8 do out[#out + 1] = "{group" .. n .. "}" end
    end
    return out
end

local function H() return Settings.Helpers end

--- The user callouts as picker entries, in the page's order (Library.MemberIds: by name, then id).
function C.Entries()
    local callouts = NS.db.profile.callouts
    local out = {}
    for _, id in ipairs(NS.Library.MemberIds("callout")) do
        out[#out + 1] = { id = id, label = callouts[id].name or id }
    end
    return out
end

local function ids(entries)
    local out = {}
    for i, e in ipairs(entries) do out[i] = e.id end
    return out
end

function C.Create()
    local id = NS.Library.CreateCallout({ name = L["New callout"], text = "", channel = "smartGroup" })
    if id then
        Ed.Select("callout", id)
        Ed.RequestRefresh()
    end
    return id
end

function C.Duplicate(id)
    local copy = NS.Library.DuplicateCallout(id)
    if copy then
        Ed.Select("callout", copy)
        Ed.RequestRefresh()
    end
    return copy
end

function C.Delete(id)
    local c = NS.db.profile.callouts[id]
    if not c then return end
    Ed.ConfirmDelete(c.name, function() NS.Library.DeleteCallout(id) end)
end

--- Add a token to the end of the callout's text, through the seam.
function C.InsertToken(id, token)
    local c = NS.db.profile.callouts[id]
    if not c then return false end
    local text = c.text or ""
    local sep = (text == "" or text:sub(-1) == " ") and "" or " "
    return (NS.SchemaRuntime.Set("callout.text", text .. sep .. token, id)) == true
end

--- What a callout sends here (spec §13.1: the live preview of the baked line, under the current or
--- previewed situation, with the padlock when locked): the line and its bytes, or why it sends
--- nothing; then any lock, the unknown tokens and the tokens empty here.
--- @return string[]
function C.PreviewLines(callout)
    local snap = Ed.Snapshot()
    local line, reason, info = NS.Bake.Bake(callout, snap,
        { soloFallback = NS.Setting("behavior.soloFallback"), ctx = NS.Surfaces.BakeContext(snap) })
    local R = NS.PadRender
    local out = {}
    if line then
        out[1] = L["Sends: %s"]:format(line)
        out[2] = L["%d of 255 bytes"]:format(info.length)
    elseif reason == "solo" and info.selfPrint then
        out[1] = L["Solo: prints to you, sends nothing."]
    else
        out[1] = L["Sends nothing here: %s"]:format(R.REASON_TEXT[reason] or tostring(reason))
        if info.length then out[2] = L["%d of 255 bytes"]:format(info.length) end
    end
    if info.lock then out[#out + 1] = R.LOCK_TEXT[info.lock] or tostring(info.lock) end
    if info.unknown and #info.unknown > 0 then
        out[#out + 1] = L["Unknown tokens, sent as typed: %s"]:format(table.concat(info.unknown, ", "))
    end
    if info.missing and #info.missing > 0 then
        out[#out + 1] = L["Empty here: %s"]:format(table.concat(info.missing, ", "))
    end
    local key = NS.Preview.PreviewAs()
    if key then out[#out + 1] = L["Previewing: %s"]:format(NS.Preview.Label(key)) end
    return out
end

--- Select a group and open the Groups page on it (a Used by link).
function C.OpenGroup(groupId)
    Ed.Select("group", groupId)
    return Ed.Open("groups")
end

local NONE = L["No callouts yet. Click New callout to make one."]

-- The token picker's entries for the callout's channel as it is now.
local function tokenEntries(id)
    return function()
        local c = NS.db.profile.callouts[id]
        local out = {}
        for i, token in ipairs(C.TokensFor(c and c.channel)) do out[i] = { id = token, label = token } end
        return out
    end
end

local function renderGeneral(ctx, rows)
    local h = H()
    local id = Ed.Selected("callout")
    local callout = id and NS.db.profile.callouts[id]
    if not callout then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Scalar(rows), nil, nil, { noHeadings = true })
    h.RenderGrid(ctx, { Ed.ActionDropdown(L["Insert a token"],
        L["Add a token to the end of the text. Tokens are filled in when the callout is sent."],
        tokenEntries(id), function(token) C.InsertToken(id, token) end, ctx) })
    h.Section(ctx, L["What it sends here"])
    -- One label, refreshed in place (Ed.Live) on every write to this callout and every situation change.
    local live = h.TextRow(ctx, table.concat(C.PreviewLines(callout), "\n"))
    Ed.Live(ctx, function()
        local c = NS.db.profile.callouts[id]
        if c and live then live:SetText(table.concat(C.PreviewLines(c), "\n")) end
    end)
    h.InlineButtonPair(ctx,
        { text = L["Duplicate"], tooltip = L["Make a copy of this callout and edit the copy."],
          onClick = function() C.Duplicate(id) end },
        { text = L["Delete"], tooltip = L["Delete this callout and take it out of every group. Asks first."],
          onClick = function() C.Delete(id) end })
end

local function renderUsedBy(ctx)
    local h = H()
    local id = Ed.Selected("callout")
    if not (id and NS.db.profile.callouts[id]) then
        h.TextRow(ctx, NONE)
        return
    end
    local used = NS.Library.UsedBy(id)
    if #used == 0 then
        h.TextRow(ctx, L["No group holds this callout yet. Add it on a group's Callouts tab."])
        return
    end
    h.TextRow(ctx, L["The groups that hold this callout. Click one to open it on the Groups page."])
    local items = {}
    for _, gid in ipairs(used) do
        items[#items + 1] = { wide = true, make = function(_, parent)
            local link = h.AceGUI:Create("InteractiveLabel")
            link:SetText(NS.db.profile.groups[gid].name)
            link:SetFullWidth(true)
            link:SetCallback("OnClick", function() C.OpenGroup(gid) end)
            parent:AddChild(link)
            return link
        end }
    end
    h.RenderGrid(ctx, items)
end

local function render(ctx)
    local h = H()
    local entries = C.Entries()
    local selected = Ed.Heal("callout", ids(entries))
    local list, order = Ed.PickerList(entries)
    h.PageBanner(ctx, {
        label = L["Callout"], list = list, order = order, value = selected,
        tooltip = L["Which callout this page edits."],
        onSelect = function(v)
            Ed.Select("callout", v)
            Ed.RequestRefresh()
        end,
        action = { text = L["New callout"], tooltip = L["Make a new callout and edit it here."], onClick = C.Create },
    })
    Ed.Tabs(ctx, PAGE, {
        { key = GENERAL, render = renderGeneral },
        { key = "usedBy", label = L["Used by"], tooltip = L["The groups that hold this callout."], render = renderUsedBy },
    })
end

Ed.RegisterPage(PAGE, L["Callouts"], "CalloutsPanel", render, {
    tooltip = L["Put the selected callout's channel back to Smart group. Its name, text and icon are kept."],
    onClick = function(ctx) H().RestoreDefaults(PAGE, ctx) end,
})
```
In `QuickComms.toc`, after `settings\Editors.lua`, add:
```
# LOAD-BEARING: takes Settings.Editors at load and registers the Callouts page (after General).
settings\Callouts.lua
```

- [ ] **Step 4: Locale keys**

In `locales/enUS.lua`, under a new comment `-- Callouts page (settings/Callouts.lua)`:
```lua
L["New callout"] = "New callout"
L["Sends: %s"] = "Sends: %s"
L["%d of 255 bytes"] = "%d of 255 bytes"
L["Sends nothing here: %s"] = "Sends nothing here: %s"
L["Unknown tokens, sent as typed: %s"] = "Unknown tokens, sent as typed: %s"
L["Empty here: %s"] = "Empty here: %s"
L["No callouts yet. Click New callout to make one."] = "No callouts yet. Click New callout to make one."
L["Insert a token"] = "Insert a token"
L["Add a token to the end of the text. Tokens are filled in when the callout is sent."] = "Add a token to the end of the text. Tokens are filled in when the callout is sent."
L["What it sends here"] = "What it sends here"
L["Duplicate"] = "Duplicate"
L["Make a copy of this callout and edit the copy."] = "Make a copy of this callout and edit the copy."
L["Delete"] = "Delete"
L["Delete this callout and take it out of every group. Asks first."] = "Delete this callout and take it out of every group. Asks first."
L["No group holds this callout yet. Add it on a group's Callouts tab."] = "No group holds this callout yet. Add it on a group's Callouts tab."
L["The groups that hold this callout. Click one to open it on the Groups page."] = "The groups that hold this callout. Click one to open it on the Groups page."
L["Callout"] = "Callout"
L["Which callout this page edits."] = "Which callout this page edits."
L["Make a new callout and edit it here."] = "Make a new callout and edit it here."
L["Used by"] = "Used by"
L["The groups that hold this callout."] = "The groups that hold this callout."
L["Callouts"] = "Callouts"
L["Put the selected callout's channel back to Smart group. Its name, text and icon are kept."] = "Put the selected callout's channel back to Smart group. Its name, text and icon are kept."
```

- [ ] **Step 5: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS (the kit's AceGUI fake records `SetValue` as `.value`, `SetText` as `.text` and `SetLabel` as `.labelText`, which is what the helpers read).

- [ ] **Step 6: Commit**

```bash
git add settings/Callouts.lua tests/test_page_callouts.lua tests/run.lua QuickComms.toc locales/enUS.lua
git checkout -- settings/Callouts.lua tests/test_page_callouts.lua tests/run.lua QuickComms.toc locales/enUS.lua
git commit -m "Settings: the Callouts page (rows, tokens, the live line, duplicate, delete, used by)"
```

---
### Task 8: The When editor and the game-id readers

Spec §13.2: "One row per condition from §5.3, each with an enable checkbox and a multi-select (or a range for the key level). Instance and battleground pickers are searchable lists keyed by `instanceID` … The list data comes from a shipped ID table; there is no localized-name matching. A live line reads 'Active now ✓ / ✗', with the reason." This task builds the editor as a module the Groups page (Task 9) calls for its When tab: a pure half (toggle a value, clear a row, set the key-level range, describe a When, the active-now line, the values a row offers) and a render half. Instances, battlegrounds and characters use the library's `IdList` (an add box with suggestions, one line per entry with Remove) with host kinds whose ids are instanceIDs or `Name-Realm` strings; each also offers "add the one you are in". Every change writes the group's whole When through the seam.

**Files:**
- Create: `settings/Groups_When.lua`; Modify: `QuickComms.toc` (after `settings\Callouts.lua`)
- Modify: `modules/Resolver.lua` (publish `R.LABEL`)
- Modify: `core/Compat.lua` (`SpecInfoByID`, `ClassName`), `.luacheckrc`
- Modify: `core/State.lua` (`State.whenOpen`), `settings/Editors.lua` (a profile switch clears it)
- Create: `tests/test_groups_when.lua`; Modify: `tests/run.lua` (add `"test_groups_when",` after `"test_page_callouts",`); Modify: `tests/test_compat.lua`
- Modify: `locales/enUS.lua`

**Interfaces:**
- Consumes: `NS.Resolver.ROWS`, `Matches(when, snap) -> ok, matched, failedRow`; `NS.GameIds` (Task 4b); `NS.Compat.InstanceName` (Task 4b); `NS.PadRender.CONTENT`; `NS.BuiltIns.groups` (each battleground set's `when.battleground`); Task 6's `Ed.Snapshot`, `Ed.RequestRefresh`; `Settings.Helpers` (`TextRow`, `RenderGrid`, `IdList`, `InlineButtonPair`, `AttachTooltip`, `AceGUI`); `NS.Library.Group`, `IsBuiltin`; `NS.SchemaRuntime.Set("group.when", when, gid)`.
- Produces (`Settings.GroupsWhen`):
  - Pure: `W.ROWS` (the editor's row order); `W.IsSet(when, row) -> boolean`; `W.Toggle(when, row, value, on) -> when` (a copy; an emptied row is dropped); `W.ClearRow(when, row) -> when`; `W.SetKeyLevel(when, lo, hi) -> when | nil, "badWhen"|"badRange"`; `W.Values(row, when) -> { { value, text } }`; `W.Describe(when) -> string[]`; `W.ActiveLine(group, snap, previewLabel) -> string` (a group turned off reads "Off", whatever its When); `W.ActiveText(gid) -> string` (the line for a group under the editors' snapshot and the preview); `W.CharacterId(text, live) -> string|nil`; `W.InstanceName(id)`, `W.BattlegroundName(id)`.
  - Edge: `W.Write(gid, when) -> boolean` (prints the seam's reason on a refusal); `W.SetKeyField(gid, field, text) -> boolean`; `W.Render(ctx, gid)` (the When tab).
  - `NS.State.whenOpen = { [gid] = { [row] = true } }` (session-only; declared in `core/State.lua`, cleared by a profile switch).
  - `NS.Resolver.LABEL` (row -> display label); `NS.Compat.SpecInfoByID(id) -> name|nil, icon|nil`; `NS.Compat.ClassName(classFile) -> string|nil`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_groups_when.lua`:
```lua
-- tests/test_groups_when.lua — settings/Groups_When.lua (spec §5.3, §13.2): the When editor's pure half
-- (toggle, clear, the key-level range, the values a row offers, the description, the active-now line)
-- and its write through the seam. The tab itself is driven in tests/test_page_groups.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function boot()
    local NS = T.bootAddon()
    return NS, NS.addon.Settings.GroupsWhen
end

test("when: Toggle adds and removes one value, drops an emptied row, and never mutates its input", function()
    local _, W = boot()
    local w0 = {}
    local w1 = W.Toggle(w0, "content", "mythicPlus", true)
    assertTrue(w1.content.mythicPlus)
    assertNil(w0.content, "a copy")
    local w2 = W.Toggle(w1, "content", "raid", true)
    assertTrue(w2.content.raid and w2.content.mythicPlus)
    local w3 = W.Toggle(W.Toggle(w2, "content", "raid", false), "content", "mythicPlus", false)
    assertNil(w3.content, "an emptied row is no row")
    assertTrue(w2.content.raid, "the earlier copy is untouched")
    assertNil(W.ClearRow(w2, "content").content)
end)

test("when: [review 5] the key-level range refuses lowest above highest; clearing both drops the row", function()
    local _, W = boot()
    local w, why = W.SetKeyLevel({}, 12, 10)
    assertNil(w)
    assertEqual(why, "badRange")
    w = W.SetKeyLevel({}, 10, nil)
    assertEqual(w.keyLevel.min, 10)
    assertNil(w.keyLevel.max)
    assertNil(W.SetKeyLevel(w, nil, nil).keyLevel)
    assertTrue(W.IsSet({ keyLevel = { max = 5 } }, "keyLevel"))
    assertFalse(W.IsSet({ keyLevel = {} }, "keyLevel"))
    assertFalse(W.IsSet({ content = {} }, "content"))
end)

test("when: [review 5] a typed key level is refused when the range would be upside down, and nothing is stored", function()
    local NS, W = boot()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    assertTrue(W.SetKeyField(gid, "min", "12"))
    assertEqual(NS.db.profile.groups[gid].when.keyLevel.min, 12)
    assertFalse(W.SetKeyField(gid, "max", "10"))
    assertNil(NS.db.profile.groups[gid].when.keyLevel.max)
    assertFalse(W.SetKeyField(gid, "max", "ten"))
    assertTrue(W.SetKeyField(gid, "min", ""))
    assertNil(NS.db.profile.groups[gid].when.keyLevel, "both ends empty: no row")
end)

test("when: the specialization row offers the player's class, or the classes the class row picked", function()
    local NS, W = boot()
    NS.Situation.Current = function() return { classFile = "MAGE" } end
    local function values(when)
        local out = {}
        for i, v in ipairs(W.Values("spec", when)) do out[i] = v.value end
        return table.concat(out, ",")
    end
    assertEqual(values({}), "62,63,64")
    assertEqual(values({ class = { PRIEST = true } }), "256,257,258")
    assertEqual(values({ spec = { [265] = true } }), "62,63,64,265", "a picked spec of another class stays listed")
    assertEqual(#W.Values("content", {}), 9)
    assertEqual(W.Values("role", {})[1].value, "TANK")
end)

test("when: Describe reads a When back as lines, and ActiveLine names the row that does not match", function()
    local NS, W = boot()
    assertEqual(W.Describe({})[1], "Always: this group has no conditions.")
    local lines = W.Describe({ content = { mythicPlus = true }, keyLevel = { min = 10 } })
    assertEqual(lines[1], "Content: M+")
    assertEqual(lines[2], "Key level: 10 to any")
    local snap = NS.Situation.Classify({ inInstance = true, instanceType = "raid", difficultyID = 15 })
    assertTrue(W.ActiveLine({ when = { content = { raid = true } } }, snap):find("Active now", 1, true) ~= nil)
    local line = W.ActiveLine({ when = { content = { mythicPlus = true } } }, snap)
    assertTrue(line:find("Content does not match", 1, true) ~= nil, line)
    line = W.ActiveLine({ when = {} }, snap, "Arena")
    assertTrue(line:find("In the preview (Arena)", 1, true) ~= nil, line)
end)

test("when: [phase 3] a group turned off never reads Active now, as the picker's dot does not", function()
    local NS, W = boot()
    local snap = NS.Situation.Classify({ inInstance = true, instanceType = "raid", difficultyID = 15 })
    -- red under: drop the `enabled == false` branch from W.ActiveLine
    local line = W.ActiveLine({ enabled = false, when = { content = { raid = true } } }, snap)
    assertTrue(line:find("Off: this group is turned off.", 1, true) ~= nil, line)
    NS.Library.SetBuiltinEnabled("bi.raid", false)
    line = W.ActiveLine(NS.Library.Group("bi.raid"), snap)
    assertTrue(line:find("Active now", 1, true) == nil, line)
end)

test("when: CharacterId takes Name-Realm as typed and gives a bare name the player's realm", function()
    local _, W = boot()
    local live = { character = "Me-Area52" }
    assertEqual(W.CharacterId("Traxex", live), "Traxex-Area52")
    assertEqual(W.CharacterId("  Traxex-Other  ", live), "Traxex-Other")
    assertNil(W.CharacterId("two words", live))
    assertNil(W.CharacterId("Traxex", {}), "no realm to add")
    assertNil(W.CharacterId("", live))
end)

test("when: [phase 3] the open rows are session state that a profile switch clears", function()
    local NS = T.enableAddon()
    NS.State.whenOpen.g1 = { content = true }
    NS.addon.db:SetProfile("Other")
    -- red under: drop the whenOpen loop from Editors' onProfileChanged
    assertNil(NS.State.whenOpen.g1)
end)

test("when: Write stores a user group's When through the seam and refuses a built-in with its reason", function()
    local NS, W = boot()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    assertTrue(W.Write(gid, { content = { arena = true } }))
    assertTrue(NS.db.profile.groups[gid].when.content.arena)
    assertFalse(W.Write("bi.mplus", { content = { arena = true } }))
    assertTrue(NS.BuiltIns.groups["bi.mplus"].when.content.mythicPlus)
end)

test("when: the battleground names come from the shipped sets, by instanceID", function()
    local _, W = boot()
    assertEqual(W.BattlegroundName(2107), "Arathi Basin")
    assertEqual(W.BattlegroundName(489), "Warsong Gulch")
    assertEqual(W.InstanceName(99999), "Instance 99999")
end)
```
Append to `tests/test_compat.lua`:
```lua
test("compat: [phase 3] SpecInfoByID and ClassName read display names; secret or missing ones are nil", function()
    local NS, env = T.newAddon()
    env.issecretvalue = T.isSecret
    env.GetSpecializationInfoByID = function(id)
        if id == 265 then return 265, "Affliction", "", 136145, "DAMAGER", "WARLOCK" end
        return id, T.secret("x")
    end
    env.LOCALIZED_CLASS_NAMES_MALE = { WARLOCK = "Warlock", MAGE = T.secret("Mage") }
    local name, icon = NS.Compat.SpecInfoByID(265)
    assertEqual(name, "Affliction")
    assertEqual(icon, 136145)
    assertNil((NS.Compat.SpecInfoByID(62)))
    assertEqual(NS.Compat.ClassName("WARLOCK"), "Warlock")
    assertNil(NS.Compat.ClassName("MAGE"))
    assertNil(NS.Compat.ClassName("NOPE"))
    env.GetSpecializationInfoByID, env.LOCALIZED_CLASS_NAMES_MALE = nil, nil
    assertNil((NS.Compat.SpecInfoByID(265)))
    assertNil(NS.Compat.ClassName("WARLOCK"))
end)
```
In `tests/run.lua`, add `"test_groups_when",` after `"test_page_callouts",`.

- [ ] **Step 2: Run the tests to check they fail**

Run: `lua tests/run.lua`
Expected: FAIL (`NS.addon.Settings.GroupsWhen` is nil; `SpecInfoByID` and `ClassName` do not exist).

- [ ] **Step 3: The readers**

In `modules/Resolver.lua`, after the `LABEL` table, add:
```lua
R.LABEL = LABEL   -- the When editor's row labels (settings/Groups_When.lua)
```
In `core/Compat.lua`, after `Compat.InstanceName`, add:
```lua
--- A specialization's display name and icon from its specID, or nil.
function Compat.SpecInfoByID(id)
    if not (PlainNumber(id) and GetSpecializationInfoByID) then return nil end
    local _, name, _, icon = GetSpecializationInfoByID(id)
    name = PlainString(name)
    if not name or name == "" then return nil end
    return name, PlainNumber(icon)
end

--- A class's display name from its classFile token, or nil.
function Compat.ClassName(classFile)
    local names = LOCALIZED_CLASS_NAMES_MALE
    if type(names) ~= "table" or not Compat.IsSafeKey(classFile) then return nil end
    return PlainString(names[classFile])
end
```
In `.luacheckrc`, extend the editors' line added in Task 4b:
```lua
  -- core/Compat.lua: the editors' display names (shown, never matched).
  "GetRealZoneText", "GetSpecializationInfoByID", "LOCALIZED_CLASS_NAMES_MALE",
```
In `core/State.lua`, append:
```lua

-- The When editor's rows switched on with nothing chosen yet (settings/Groups_When.lua):
-- { [groupId] = { [row] = true } }. Session-only; a profile switch clears it (settings/Editors.lua).
State.whenOpen = {}
```
In `settings/Editors.lua`, `onProfileChanged`, after the loop that clears `State.editing`, add:
```lua
    for gid in pairs(State.whenOpen or {}) do State.whenOpen[gid] = nil end
```

- [ ] **Step 4: The editor**

Create `settings/Groups_When.lua`:
```lua
local _, NS = ...
-- settings/Groups_When.lua — the When editor (design spec §5.3, §13.2), the Groups page's When tab.
--
-- Shaped after the WeakAuras Load tab: one row per condition, each an enable checkbox and, while on,
-- its values: checkboxes for a short list, a lowest and highest box for the key level, and an id list
-- (the library's IdList: an add box with suggestions, one line per entry with Remove) for instances,
-- battlegrounds and characters. Values are ids and tokens, never localized names
-- (localization-§4): instances and battlegrounds by instanceID, classes by classFile,
-- specializations by specID, characters by Name-Realm; a name is shown, never matched. The list
-- data is shipped (defaults/GameIds.lua and the battleground sets); "Add the instance you are in"
-- covers an id the table does not list yet. A live line says whether the group is active now, or in
-- the previewed situation, and which row stops it.
--
-- Every change writes the group's WHOLE When through the seam (`group.when`, a structured member
-- row, settings/SchemaMembers.lua), read fresh from the profile at the click, so two clicks before a
-- repaint never lose one. A row switched on with nothing chosen yet stays open for the session
-- (NS.State.whenOpen); switched off, its values are cleared. A built-in group's When is fixed: the
-- tab describes it. The pure half is tested headlessly in tests/test_groups_when.lua.

local QC = NS.addon
local Settings = QC.Settings
local Ed = Settings.Editors
local L = NS.L
local State = NS.State

Settings.GroupsWhen = Settings.GroupsWhen or {}
local W = Settings.GroupsWhen

W.ROWS = { "content", "instances", "difficulty", "keyLevel", "group", "leadership", "class", "spec", "role",
    "characters", "battleground" }

local CONTENT = { "openWorld", "dungeon", "mythicPlus", "raid", "delve", "scenario", "battleground", "arena", "housing" }
local DIFFICULTY = { { "normal", L["Normal"] }, { "heroic", L["Heroic"] }, { "mythic", L["Mythic"] },
    { "keystone", L["Mythic Keystone"] }, { "lfr", L["LFR"] }, { "story", L["Story"] }, { "follower", L["Follower"] } }
local GROUP = { { "solo", L["Solo"] }, { "party", L["Party"] }, { "raid", L["Raid"] },
    { "instance", L["Instance group (LFG, LFR or a battleground)"] } }
local LEADERSHIP = { { "leader", L["Leader"] }, { "assist", L["Assist"] } }
local ROLE = { { "TANK", L["Tank"] }, { "HEALER", L["Healer"] }, { "DAMAGER", L["Damage"] } }

W.TIP = {
    content = L["The kind of place you are in."],
    instances = L["Specific dungeons or raids, by instance."],
    difficulty = L["The instance's difficulty."],
    keyLevel = L["The Mythic+ key level, from the lowest to the highest. Leave a box empty for no limit."],
    group = L["The kind of group you are in."],
    leadership = L["Whether you lead the group or assist."],
    class = L["Your class."],
    spec = L["Your specialization."],
    role = L["Your group role."],
    characters = L["Specific characters, as Name-Realm."],
    battleground = L["Specific battlegrounds."],
}

local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

-- ── the pure half ───────────────────────────────────────────────────────────────────────────

--- Whether a When row takes part (spec §5.3: a nil or empty row is ignored).
function W.IsSet(when, row)
    local v = type(when) == "table" and when[row] or nil
    if type(v) ~= "table" then return false end
    if row == "keyLevel" then return type(v.min) == "number" or type(v.max) == "number" end
    return next(v) ~= nil
end

--- A copy of `when` with `value` on or off in `row`; a row left empty is dropped.
function W.Toggle(when, row, value, on)
    local w = copy(when or {})
    local set = type(w[row]) == "table" and w[row] or {}
    set[value] = on and true or nil
    w[row] = next(set) ~= nil and set or nil
    return w
end

function W.ClearRow(when, row)
    local w = copy(when or {})
    w[row] = nil
    return w
end

--- A copy of `when` with the key-level range set (nil ends are open; both nil drops the row).
--- @return table|nil when, string|nil reason ("badWhen" | "badRange")
function W.SetKeyLevel(when, lo, hi)
    if (lo ~= nil and type(lo) ~= "number") or (hi ~= nil and type(hi) ~= "number") then return nil, "badWhen" end
    if lo and hi and lo > hi then return nil, "badRange" end
    local w = copy(when or {})
    w.keyLevel = (lo or hi) and { min = lo, max = hi } or nil
    return w
end

function W.InstanceName(id)
    return NS.Compat.InstanceName(id) or L["Instance %d"]:format(id)
end

local bgNames
local function battlegroundNames()
    if bgNames then return bgNames end
    bgNames = {}
    for _, def in pairs(NS.BuiltIns.groups) do
        local ids = def.when and def.when.battleground
        if type(ids) == "table" then
            for id in pairs(ids) do bgNames[id] = def.name end
        end
    end
    return bgNames
end

function W.BattlegroundName(id)
    return battlegroundNames()[id] or W.InstanceName(id)
end

local function battlegroundIds()
    local out = {}
    for id in pairs(battlegroundNames()) do out[#out + 1] = id end
    table.sort(out)
    return out
end

--- A typed character as Name-Realm: as typed when it carries a realm, else with the player's realm.
--- @param live table a snapshot (its `character` is the player's Name-Realm)
function W.CharacterId(text, live)
    local name = (text or ""):match("^%s*(.-)%s*$")
    if name == "" or name:find("%s") then return nil end
    if name:find("-", 1, true) then return name end
    local realm = live and live.character and live.character:match("%-(.+)$")
    if not realm then return nil end
    return name .. "-" .. realm
end

local function pairsToValues(list)
    local out = {}
    for i, p in ipairs(list) do out[i] = { value = p[1], text = p[2] } end
    return out
end

--- The values a checkbox row offers, in order. The specialization row offers the classes the class
--- row picked, or the player's own; a spec chosen earlier stays listed so it can be cleared.
--- @return table { { value, text } }
function W.Values(row, when)
    if row == "content" then
        local out = {}
        for i, v in ipairs(CONTENT) do out[i] = { value = v, text = NS.PadRender.CONTENT[v] or v } end
        return out
    end
    if row == "difficulty" then return pairsToValues(DIFFICULTY) end
    if row == "group" then return pairsToValues(GROUP) end
    if row == "leadership" then return pairsToValues(LEADERSHIP) end
    if row == "role" then return pairsToValues(ROLE) end
    if row == "class" then
        local out = {}
        for i, cf in ipairs(NS.GameIds.CLASSES) do out[i] = { value = cf, text = NS.Compat.ClassName(cf) or cf } end
        return out
    end
    if row == "spec" then
        local classes = {}
        local picked = type(when) == "table" and when.class or nil
        if type(picked) == "table" and next(picked) then
            for cf in pairs(picked) do classes[#classes + 1] = cf end
            table.sort(classes)
        else
            local live = NS.Situation.Current()
            if live.classFile then classes[1] = live.classFile end
        end
        local out, seen = {}, {}
        local function add(specID)
            if seen[specID] then return end
            seen[specID] = true
            out[#out + 1] = { value = specID, text = NS.Compat.SpecInfoByID(specID) or L["Specialization %d"]:format(specID) }
        end
        for _, cf in ipairs(classes) do
            for _, specID in ipairs(NS.GameIds.SPECS[cf] or {}) do add(specID) end
        end
        local chosen = {}
        for specID in pairs(type(when) == "table" and when.spec or {}) do chosen[#chosen + 1] = specID end
        table.sort(chosen)
        for _, specID in ipairs(chosen) do add(specID) end
        return out
    end
    return {}
end

local function nameOf(row, value)
    if row == "instances" then return W.InstanceName(value) end
    if row == "battleground" then return W.BattlegroundName(value) end
    if row == "characters" then return tostring(value) end
    for _, v in ipairs(W.Values(row, {})) do
        if v.value == value then return v.text end
    end
    if row == "spec" then return NS.Compat.SpecInfoByID(value) or L["Specialization %d"]:format(value) end
    return tostring(value)
end

--- A When read back as lines: "Content: M+, Raid", "Key level: 10 to any". A built-in's When tab
--- shows these.
--- @return string[]
function W.Describe(when)
    local out = {}
    for _, row in ipairs(W.ROWS) do
        if W.IsSet(when, row) then
            local label = NS.Resolver.LABEL[row] or row
            if row == "keyLevel" then
                local kl = when.keyLevel
                out[#out + 1] = L["%s: %s to %s"]:format(label, kl.min and tostring(kl.min) or L["any"],
                    kl.max and tostring(kl.max) or L["any"])
            else
                local names = {}
                for value in pairs(when[row]) do names[#names + 1] = nameOf(row, value) end
                table.sort(names)
                out[#out + 1] = L["%s: %s"]:format(label, table.concat(names, ", "))
            end
        end
    end
    if #out == 0 then out[1] = L["Always: this group has no conditions."] end
    return out
end

--- The live line (spec §13.2) for a group (user or merged built-in): off when the group is turned
--- off (Resolver.ActiveGroups skips it, so the picker's dot agrees), else active now or the row that
--- does not match; prefixed with the preview when "Preview as…" is on.
function W.ActiveLine(group, snap, previewLabel)
    local ok, _, failed = NS.Resolver.Matches(group and group.when, snap)
    local line
    if group and group.enabled == false then
        line = L["|cffa0a0a0Off: this group is turned off.|r"]
    elseif ok then
        line = L["|cff40ff40Active now.|r"]
    else
        line = L["|cffff6060Not active now:|r %s does not match."]:format(NS.Resolver.LABEL[failed] or tostring(failed))
    end
    if previewLabel then line = L["In the preview (%s): %s"]:format(previewLabel, line) end
    return line
end

--- The live line for group `gid` as it is now, under the editors' snapshot and the preview.
function W.ActiveText(gid)
    local g = gid and NS.Library.Group(gid)
    if not g then return "" end
    local key = NS.Preview.PreviewAs()
    return W.ActiveLine(g, Ed.Snapshot(), key and NS.Preview.Label(key))
end

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

local function fresh(gid)
    local g = NS.Library.Group(gid)
    return g and g.when or {}
end

local function openRows(gid)
    State.whenOpen[gid] = State.whenOpen[gid] or {}
    return State.whenOpen[gid]
end

--- Write a group's whole When through the seam; a refusal prints its reason.
--- @return boolean
function W.Write(gid, when)
    local ok, _, why = NS.SchemaRuntime.Set("group.when", when, gid)
    if not ok and why then NS.Print(tostring(why)) end
    return ok == true
end

--- One end of the key-level range from typed text ("" clears that end).
--- @return boolean stored
function W.SetKeyField(gid, field, text)
    local when = fresh(gid)
    local kl = when.keyLevel or {}
    local lo, hi = kl.min, kl.max
    local typed = (text or ""):match("^%s*(.-)%s*$")
    local n = typed ~= "" and tonumber(typed:match("^(%d+)$")) or nil
    if typed ~= "" and not n then
        NS.Print(L["A key level is a whole number."])
        return false
    end
    if field == "min" then lo = n else hi = n end
    local w, why = W.SetKeyLevel(when, lo, hi)
    if not w then
        NS.Print(why == "badRange" and L["The lowest key level is above the highest."] or L["That condition is not one Quick Comms knows."])
        return false
    end
    return W.Write(gid, w)
end

local function H() return Settings.Helpers end

local function checkbox(label, value, tooltip, onChange)
    return { make = function(_, parent, rel)
        local h = H()
        local cb = h.AceGUI:Create("CheckBox")
        cb:SetLabel(label)
        cb:SetValue(value and true or false)
        cb:SetRelativeWidth(rel or 0.5)
        cb:SetCallback("OnValueChanged", function(_, _, v) onChange(v and true or false) end)
        if tooltip then h.AttachTooltip(cb, label, tooltip) end
        parent:AddChild(cb)
        return cb
    end }
end

local function renderKeyLevel(ctx, gid)
    local kl = fresh(gid).keyLevel or {}
    local function box(label, field)
        return { make = function(_, parent, rel)
            local eb = H().AceGUI:Create("EditBox")
            eb:SetLabel(label)
            eb:SetText(kl[field] and tostring(kl[field]) or "")
            eb:SetRelativeWidth(rel or 0.5)
            eb:SetCallback("OnEnterPressed", function(_, _, text) W.SetKeyField(gid, field, text) end)
            parent:AddChild(eb)
            return eb
        end }
    end
    H().RenderGrid(ctx, { box(L["Lowest key level"], "min"), box(L["Highest key level"], "max") })
end

-- Typed text -> one of `candidates` by exact name (case-insensitive), through `nameFn`.
local function byName(text, candidates, nameFn)
    local want = (text or ""):lower()
    local found
    for _, id in ipairs(type(candidates) == "function" and candidates() or {}) do
        if nameFn(id):lower() == want then
            if found and found ~= id then return nil, "ambiguous" end
            found = id
        end
    end
    if found then return found, nameFn(found) end
    return nil, "notFound"
end

local function idKind(nameFn, noun, plural)
    return {
        noun = noun, plural = plural,
        info = function(id) return nameFn(id), nil end,
        resolve = function(text, candidates)
            local n = tonumber(text)
            if n then return n, nameFn(n) end
            return byName(text, candidates, nameFn)
        end,
    }
end

local KIND = {
    instances = function() return idKind(W.InstanceName, L["instance"], L["instances"]) end,
    battleground = function() return idKind(W.BattlegroundName, L["battleground"], L["battlegrounds"]) end,
    characters = function()
        return { noun = L["character"], plural = L["characters"],
            info = function(id) return tostring(id), nil end,
            resolve = function(text)
                local id = W.CharacterId(text, NS.Situation.Current())
                if id then return id, id end
                return nil, "notFound"
            end }
    end,
}

local CANDIDATES = {
    instances = function()
        local out = {}
        for _, id in ipairs(NS.GameIds.DUNGEONS) do out[#out + 1] = id end
        for _, id in ipairs(NS.GameIds.RAIDS) do out[#out + 1] = id end
        return out
    end,
    battleground = battlegroundIds,
    characters = function() return {} end,
}

local ADD = {
    instances = { L["Add an instance"], L["Type an instance id or a listed name, then press Enter or Add."],
        L["Add the instance you are in"] },
    battleground = { L["Add a battleground"], L["Type a battleground's id or name, then press Enter or Add."],
        L["Add the battleground you are in"] },
    characters = { L["Add a character"], L["Type Name-Realm, or a name on your realm, then press Enter or Add."],
        L["Add this character"] },
}

-- The one the player is in now (the live snapshot, never the preview).
local function here(row)
    local live = NS.Situation.Current()
    if row == "instances" then return live.content ~= "openWorld" and live.instanceID or nil end
    if row == "battleground" then return live.content == "battleground" and live.instanceID or nil end
    if row == "characters" then return live.character end
    return nil
end

local function renderIdRow(ctx, gid, row)
    local h = H()
    h.IdList(ctx, {
        kind = KIND[row](),
        label = ADD[row][1], tooltip = ADD[row][2],
        candidates = CANDIDATES[row],
        emptyText = L["None yet."],
        entries = function()
            local list = {}
            for id in pairs(fresh(gid)[row] or {}) do list[#list + 1] = id end
            table.sort(list, function(a, b) return tostring(a) < tostring(b) end)
            local out = {}
            for i, id in ipairs(list) do out[i] = { id = id } end
            return out
        end,
        onAdd = function(id) W.Write(gid, W.Toggle(fresh(gid), row, id, true)) end,
        onRemove = function(id) W.Write(gid, W.Toggle(fresh(gid), row, id, false)) end,
    })
    local now = here(row)
    if now ~= nil then
        h.InlineButtonPair(ctx, { text = ADD[row][3], tooltip = ADD[row][2],
            onClick = function() W.Write(gid, W.Toggle(fresh(gid), row, now, true)) end }, nil)
    end
end

local function renderRow(ctx, gid, row)
    local when = fresh(gid)
    local on = W.IsSet(when, row) or openRows(gid)[row] == true
    local label = NS.Resolver.LABEL[row] or row
    H().RenderGrid(ctx, { { wide = true, make = function(_, parent)
        local h = H()
        local cb = h.AceGUI:Create("CheckBox")
        cb:SetLabel(label)
        cb:SetValue(on)
        cb:SetFullWidth(true)
        cb:SetCallback("OnValueChanged", function(_, _, v)
            if v then
                openRows(gid)[row] = true
                Ed.RequestRefresh()
            else
                openRows(gid)[row] = nil
                W.Write(gid, W.ClearRow(fresh(gid), row))
            end
        end)
        h.AttachTooltip(cb, label, W.TIP[row])
        parent:AddChild(cb)
        return cb
    end } })
    if not on then return end
    if row == "keyLevel" then return renderKeyLevel(ctx, gid) end
    if KIND[row] then return renderIdRow(ctx, gid, row) end
    local items = {}
    for _, v in ipairs(W.Values(row, when)) do
        local chosen = type(when[row]) == "table" and when[row][v.value] == true
        items[#items + 1] = checkbox(v.text, chosen, nil, function(x)
            W.Write(gid, W.Toggle(fresh(gid), row, v.value, x))
        end)
    end
    H().RenderGrid(ctx, items)
end

--- The When tab for group `gid` (spec §13.2).
function W.Render(ctx, gid)
    local h = H()
    local g = gid and NS.Library.Group(gid)
    if not g then
        h.TextRow(ctx, L["No groups yet. Click New group to make one."])
        return
    end
    -- Refreshed in place (Ed.Live): a write to this group or a situation change re-reads it.
    local active = h.TextRow(ctx, W.ActiveText(gid))
    Ed.Live(ctx, function() if active then active:SetText(W.ActiveText(gid)) end end)
    if NS.Library.IsBuiltin(gid) then
        h.TextRow(ctx, L["A built-in set's conditions are fixed. Customize it to change them."])
        for _, line in ipairs(W.Describe(g.when)) do h.TextRow(ctx, line) end
        return
    end
    for _, row in ipairs(W.ROWS) do renderRow(ctx, gid, row) end
end
```
In `QuickComms.toc`, after `settings\Callouts.lua`, add:
```
# Conventional: the When editor; settings\Groups.lua calls Settings.GroupsWhen at run time only.
settings\Groups_When.lua
```

- [ ] **Step 5: Locale keys**

In `locales/enUS.lua`, under a new comment `-- The When editor (settings/Groups_When.lua)`:
```lua
L["Mythic Keystone"] = "Mythic Keystone"
L["Story"] = "Story"
L["Follower"] = "Follower"
L["Instance group (LFG, LFR or a battleground)"] = "Instance group (LFG, LFR or a battleground)"
L["Leader"] = "Leader"
L["Assist"] = "Assist"
L["The kind of place you are in."] = "The kind of place you are in."
L["Specific dungeons or raids, by instance."] = "Specific dungeons or raids, by instance."
L["The instance's difficulty."] = "The instance's difficulty."
L["The Mythic+ key level, from the lowest to the highest. Leave a box empty for no limit."] = "The Mythic+ key level, from the lowest to the highest. Leave a box empty for no limit."
L["The kind of group you are in."] = "The kind of group you are in."
L["Whether you lead the group or assist."] = "Whether you lead the group or assist."
L["Your class."] = "Your class."
L["Your specialization."] = "Your specialization."
L["Your group role."] = "Your group role."
L["Specific characters, as Name-Realm."] = "Specific characters, as Name-Realm."
L["Specific battlegrounds."] = "Specific battlegrounds."
L["Specialization %d"] = "Specialization %d"
L["%s: %s to %s"] = "%s: %s to %s"
L["%s: %s"] = "%s: %s"
L["Always: this group has no conditions."] = "Always: this group has no conditions."
L["|cff40ff40Active now.|r"] = "|cff40ff40Active now.|r"
L["|cffff6060Not active now:|r %s does not match."] = "|cffff6060Not active now:|r %s does not match."
L["|cffa0a0a0Off: this group is turned off.|r"] = "|cffa0a0a0Off: this group is turned off.|r"
L["In the preview (%s): %s"] = "In the preview (%s): %s"
L["A key level is a whole number."] = "A key level is a whole number."
L["Lowest key level"] = "Lowest key level"
L["Highest key level"] = "Highest key level"
L["instance"] = "instance"
L["instances"] = "instances"
L["battleground"] = "battleground"
L["battlegrounds"] = "battlegrounds"
L["character"] = "character"
L["characters"] = "characters"
L["Add an instance"] = "Add an instance"
L["Type an instance id or a listed name, then press Enter or Add."] = "Type an instance id or a listed name, then press Enter or Add."
L["Add the instance you are in"] = "Add the instance you are in"
L["Add a battleground"] = "Add a battleground"
L["Type a battleground's id or name, then press Enter or Add."] = "Type a battleground's id or name, then press Enter or Add."
L["Add the battleground you are in"] = "Add the battleground you are in"
L["Add a character"] = "Add a character"
L["Type Name-Realm, or a name on your realm, then press Enter or Add."] = "Type Name-Realm, or a name on your realm, then press Enter or Add."
L["Add this character"] = "Add this character"
L["None yet."] = "None yet."
L["No groups yet. Click New group to make one."] = "No groups yet. Click New group to make one."
L["A built-in set's conditions are fixed. Customize it to change them."] = "A built-in set's conditions are fixed. Customize it to change them."
```

- [ ] **Step 6: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS. (`W.Describe({ content = { mythicPlus = true } })` reads `Content: M+` because the content row's display names are `NS.PadRender.CONTENT`, whose `mythicPlus` is `M+`.)

- [ ] **Step 7: Commit**

```bash
git add settings/Groups_When.lua settings/Editors.lua modules/Resolver.lua core/Compat.lua core/State.lua .luacheckrc tests/test_groups_when.lua tests/test_compat.lua tests/run.lua QuickComms.toc locales/enUS.lua
git checkout -- settings/Groups_When.lua settings/Editors.lua modules/Resolver.lua core/Compat.lua core/State.lua .luacheckrc tests/test_groups_when.lua tests/test_compat.lua tests/run.lua QuickComms.toc locales/enUS.lua
git commit -m "Settings: the When editor (one row per condition, id lists, the active-now line)"
```

---
### Task 9: The Groups page

Spec §13.1 (as ruled toward options-ui-§14) and §12.2: a banner with the group picker (user groups by name, then the built-in sets in shipped order, each active one marked with a green dot) and "New group"; tabs General, Callouts, When and Preview. For a user group: General has "Preview as" (page-wide, first), the group rows, Duplicate and Delete; Callouts is a drag-to-reorder list with Remove and an "Add a callout" picker (a built-in callout is copied in, P2). For a built-in: General explains it is read-only and has its Enabled row and Customize; Callouts is the hidden-callouts editor (a Show checkbox per callout, a node's callouts named with their node). A new group goes to the top of every pad and dial (ruling 6), so it shows as soon as its When matches.

**Files:**
- Create: `settings/Groups.lua`; Modify: `QuickComms.toc` (after `settings\Groups_When.lua`)
- Create: `tests/test_page_groups.lua`; Modify: `tests/run.lua` (add `"test_page_groups",` after `"test_groups_when",`)
- Modify: `locales/enUS.lua`

**Interfaces:**
- Consumes: Task 6's `Ed.*` and `tests/page_helpers.lua`; Task 7's `Settings.Callouts.PreviewLines`; Task 8's `Settings.GroupsWhen.Render`, `ActiveText`; Task 3a's `group.*` and `builtin.enabled` rows and Task 4b's `state.previewAs` row; `NS.SchemaRuntime.BulkRun`, `ApplyDefault`; `NS.Library.MemberIds`, `CreateGroup`, `OfferGroup`, `DuplicateGroup`, `DeleteGroup`, `Customize`, `AddToGroup`, `RemoveFromGroup`, `MoveInGroup`, `SetBuiltinCalloutHidden`, `Group`, `Callout`, `AllGroups`, `IsBuiltin`; `NS.Resolver.ActiveGroups`; `NS.Surfaces.Sections`.
- Produces (`Settings.Groups`, used by Task 11): `G.Entries() -> { { id, label } }`; `G.Create() -> id|nil`; `G.Duplicate(id)`; `G.Delete(id)`; `G.Customize(builtinId) -> copyId|nil`; `G.CustomizedAs(builtinId) -> id|nil`; `G.AddableCallouts(gid) -> { { id, label } }`; `G.AddCallout(gid, cid)`; `G.MoveCallout(gid, from, to)`; `G.RestoreDefaults(ctx)` (the page's Defaults); `G.PAGE = "groups"`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_page_groups.lua`:
```lua
-- tests/test_page_groups.lua — settings/Groups.lua (spec §13.1, §13.2, §12.2): the picker and New group,
-- a user group's General, Callouts, When and Preview tabs, and a built-in's read-only General with
-- Customize and its hidden-callouts editor. Driven headlessly through tests/page_helpers.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function open(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or {} end
    NS.Situation.RefreshNow("test")
    local P = dofile("tests/page_helpers.lua")(NS, m)
    P.show("Groups")
    return NS, m, P
end

local function pick(NS, gid) NS.addon.Settings.Editors.Select("group", gid) end

test("groups page: [exit] a new group with a callout and a When shows first on the pad in that situation", function()
    local NS, _, P = open(MPLUS)
    local cid = NS.Library.CreateCallout({ name = "Inc", text = "Incoming", channel = "smartGroup" })
    P.bannerAction(P.ctx("groups")):__fire("OnClick")
    P.flush()
    local gid = NS.State.editing.group
    assertTrue(NS.db.profile.groups[gid] ~= nil)
    assertEqual(NS.db.profile.pads.p1.groups[1], gid, "offered to the top of the pad")
    local w = P.tab("groups", "callouts")
    P.find(w, "Dropdown", "Add a callout"):__fire("OnValueChanged", cid)
    assertEqual(NS.db.profile.groups[gid].callouts[1], cid)
    w = P.tab("groups", "When")
    P.find(w, "CheckBox", "Content"):__fire("OnValueChanged", true)
    P.flush()
    w = P.tab("groups", "When")
    P.find(w, "CheckBox", "M+"):__fire("OnValueChanged", true)
    assertTrue(NS.db.profile.groups[gid].when.content.mythicPlus)
    local plan = NS.Surfaces.Plans().p1
    assertEqual(plan.order[1], gid)
    assertEqual(NS.Pad.ChipsFor("p1", cid)[1]:GetAttribute("macrotext"), "/p Incoming")
    -- and not in the open world
    NS.Situation.ReadInputs = function() return {} end
    NS.Situation.RefreshNow("test")
    assertTrue(NS.Pad.ChipsFor("p1", cid)[1] == nil)
end)

test("groups page: the picker lists user groups by name, then the built-ins, active ones dotted", function()
    local NS = open(MPLUS)
    NS.Library.CreateGroup({ name = "Zed" })
    NS.Library.CreateGroup({ name = "Alpha" })
    local entries = NS.addon.Settings.Groups.Entries()
    assertTrue(entries[1].label:find("Alpha", 1, true) ~= nil)
    assertTrue(entries[2].label:find("Zed", 1, true) ~= nil)
    assertEqual(entries[3].id, NS.BuiltIns.order[1])
    local mplus
    for _, e in ipairs(entries) do if e.id == "bi.mplus" then mplus = e end end
    assertTrue(mplus.label:find("Indicator-Green", 1, true) ~= nil, "active in a key")
    assertTrue(mplus.label:find("(built-in)", 1, true) ~= nil)
end)

test("groups page: General draws Preview as first, then the group's rows; Duplicate and Delete act", function()
    local NS, _, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    pick(NS, gid)
    local w = P.redraw("groups")
    assertTrue(P.find(w, "Dropdown", "Preview as") ~= nil)
    P.find(w, "EditBox", "Name"):__fire("OnEnterPressed", "Kicks")
    assertEqual(NS.db.profile.groups[gid].name, "Kicks")
    P.find(w, "CheckBox", "Enabled"):__fire("OnValueChanged", false)
    assertFalse(NS.db.profile.groups[gid].enabled)
    P.find(w, "Button", "Duplicate"):__fire("OnClick")
    local copy = NS.State.editing.group
    assertTrue(copy ~= gid and NS.db.profile.groups[copy] ~= nil)
    w = P.redraw("groups")
    P.find(w, "Button", "Delete"):__fire("OnClick")
    P.accept()
    assertNil(NS.db.profile.groups[copy])
end)

test("groups page: Callouts drags to reorder, removes, and copies a built-in callout in (P2)", function()
    local NS, _, P = open()
    local lists = P.reorderSpy()
    local a = NS.Library.CreateCallout({ name = "A", text = "a", channel = "party" })
    local b = NS.Library.CreateCallout({ name = "B", text = "b", channel = "party" })
    local gid = NS.Library.CreateGroup({ name = "Mine", callouts = { a, b } })
    pick(NS, gid)
    P.tab("groups", "callouts")
    local list = lists[#lists]
    assertEqual(list.rows, 2)
    list.opts.onMove(1, 2)
    assertEqual(table.concat(NS.db.profile.groups[gid].callouts, ","), b .. "," .. a)
    local w = P.tab("groups", "callouts")
    P.all(w, "Button", "Remove")[1]:__fire("OnClick")
    assertEqual(table.concat(NS.db.profile.groups[gid].callouts, ","), a)
    w = P.tab("groups", "callouts")
    P.find(w, "Dropdown", "Add a callout"):__fire("OnValueChanged", "bi.mplus.lust")
    local copied = NS.db.profile.groups[gid].callouts[2]
    assertTrue(copied:match("^c%d+$") ~= nil, "a copy, never the built-in id")
    assertEqual(NS.db.profile.callouts[copied].name, "Lust")
end)

test("groups page: [review 4] a built-in is read-only; Customize puts the copy in its place and selects it", function()
    local NS, _, P = open()
    pick(NS, "bi.raid")
    local w = P.redraw("groups")
    assertTrue(P.hasText(w, "is a built-in set"))
    assertNil(P.find(w, "EditBox", "Name"), "no name box for a built-in")
    local enabled = P.find(w, "CheckBox", "Enabled")
    enabled:__fire("OnValueChanged", false)
    assertFalse(NS.db.profile.builtins["bi.raid"].enabled, "the overlay row, through the seam")
    enabled:__fire("OnValueChanged", true)
    local at
    for i, g in ipairs(NS.db.profile.pads.p1.groups) do if g == "bi.raid" then at = i end end
    w = P.redraw("groups")
    P.find(w, "Button", "Customize"):__fire("OnClick")
    local copy = NS.State.editing.group
    assertTrue(copy ~= "bi.raid" and NS.db.profile.groups[copy] ~= nil)
    assertEqual(NS.db.profile.pads.p1.groups[at], copy, "in the built-in's place")
    assertFalse(NS.db.profile.builtins["bi.raid"].enabled)
    w = P.redraw("groups")
    assertTrue(P.find(w, "EditBox", "Name") ~= nil, "the copy is editable")
end)

test("groups page: a built-in's Callouts tab hides and shows its callouts, a node's named with its node", function()
    local NS, _, P = open()
    pick(NS, "bi.bg.ab")
    local w = P.tab("groups", "callouts")
    local box = P.find(w, "CheckBox", "Stables: INC 1")
    assertTrue(box ~= nil and box.value == true)
    box:__fire("OnValueChanged", false)
    assertTrue(NS.db.profile.builtins["bi.bg.ab"].hidden["bi.bg.ab.stables.inc1"])
    for _, cid in ipairs(NS.Library.Group("bi.bg.ab.stables").callouts) do
        assertTrue(cid ~= "bi.bg.ab.stables.inc1", "hidden from the merged set")
    end
end)

test("groups page: the When tab of a built-in describes it; a user group's edits it; Preview bakes each callout", function()
    local NS, _, P = open(MPLUS)
    pick(NS, "bi.mplus")
    local w = P.tab("groups", "When")
    assertTrue(P.hasText(w, "Content: M+"))
    assertTrue(P.hasText(w, "Active now."))
    local cid = NS.Library.CreateCallout({ name = "Pull", text = "Pulling", channel = "party" })
    local gid = NS.Library.CreateGroup({ name = "Mine", callouts = { cid } })
    pick(NS, gid)
    w = P.tab("groups", "preview")
    assertTrue(P.hasText(w, "Pull: Sends: /p Pulling"))
end)

test("groups page: [phase 3] a built-in's Defaults turns it back on: the Enabled row its General draws", function()
    local NS, _, P = open()
    pick(NS, "bi.raid")
    P.redraw("groups")
    NS.Library.SetBuiltinEnabled("bi.raid", false)
    P.ctx("groups").panel.defaultsOnClick()
    -- red under: make the Groups page's Defaults plain RestoreDefaults("groups") (builtin.enabled's page is share)
    assertTrue(NS.db.profile.builtins["bi.raid"].enabled)
end)

test("groups page: [review 5] the When tab refuses an upside-down key-level range", function()
    local NS, m, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine", when = { keyLevel = { min = 12 } } })
    pick(NS, gid)
    local w = P.tab("groups", "When")
    m.prints = {}
    P.find(w, "EditBox", "Highest key level"):__fire("OnEnterPressed", "10")
    assertTrue(table.concat(m.prints, "\n"):find("The lowest key level is above the highest.", 1, true) ~= nil)
    assertNil(NS.db.profile.groups[gid].when.keyLevel.max)
end)
```
In `tests/run.lua`, add `"test_page_groups",` after `"test_groups_when",`.

- [ ] **Step 2: Run the tests to check they fail**

Run: `lua tests/run.lua`
Expected: FAIL (`m.__subcategories.Groups` is nil: no page).

- [ ] **Step 3: The page**

Create `settings/Groups.lua`:
```lua
local _, NS = ...
-- settings/Groups.lua — the Groups page (design spec §13.1, §12.2): one group at a time, a user group
-- or a built-in set.
--
--     band      [ Group v (picker; a green dot marks a group active now) ][ New group ]
--     strip     [ General ][ Callouts ][ When ][ Preview ]
--     General   Preview as (page-wide, first), then Name, Icon, Enabled, Open the dial on this group,
--               then Duplicate and Delete. A built-in: what it is, its Enabled row, and Customize.
--     Callouts  a user group's callouts as a drag-to-reorder list with Remove, then Add a callout (a
--               built-in callout is copied in first, spec P2). A built-in: a Show checkbox per
--               callout, the hidden-callouts editor (spec §12.2).
--     When      settings/Groups_When.lua
--     Preview   the active-now line, then every callout baked for the current or previewed situation
--
-- The band holds the picker and the create action (options-ui-§14); the acts are General's, which
-- is first. A built-in group is read-only: its group rows refuse every write (settings/SchemaMembers.lua),
-- so the page draws only what may change, its overlay. A new group goes to the top of every pad and
-- dial (Library.OfferGroup), so it shows as soon as its When matches.

local QC = NS.addon
local Settings = QC.Settings
local Ed = Settings.Editors
local L = NS.L

local PAGE = "groups"
local GENERAL = L["General"]
local WHEN = L["When"]

Settings.Groups = Settings.Groups or {}
local G = Settings.Groups
G.PAGE = PAGE

local function H() return Settings.Helpers end
local function isBuiltin(id) return NS.Library.IsBuiltin(id) end

--- Picker entries in the page's order (Library.MemberIds: the user groups by name, then the built-in
--- sets in shipped order); a group active under the current or previewed situation carries a green dot.
function G.Entries()
    local active = NS.Resolver.ActiveGroups(NS.Library.AllGroups(), Ed.Snapshot())
    local out = {}
    for _, id in ipairs(NS.Library.MemberIds("group")) do
        local text
        if isBuiltin(id) then
            text = L["%s (built-in)"]:format(NS.BuiltIns.groups[id].name)
        else
            text = NS.db.profile.groups[id].name or id
        end
        out[#out + 1] = { id = id, label = (active[id] and Ed.ACTIVE_DOT or "") .. text }
    end
    return out
end

function G.Create()
    local gid = NS.Library.CreateGroup({ name = L["New group"] })
    if not gid then return nil end
    NS.Library.OfferGroup(gid)
    Ed.Select("group", gid)
    Ed.RequestRefresh()
    return gid
end

function G.Duplicate(id)
    local copy = NS.Library.DuplicateGroup(id)
    if copy then
        Ed.Select("group", copy)
        Ed.RequestRefresh()
    end
    return copy
end

function G.Delete(id)
    local g = NS.db.profile.groups[id]
    if not g then return end
    Ed.ConfirmDelete(g.name, function() NS.Library.DeleteGroup(id) end)
end

--- The user group a built-in was customized into, while it still exists.
function G.CustomizedAs(builtinId)
    local o = NS.db.profile.builtins[builtinId]
    local copy = o and o.customizedAs
    return (copy and NS.db.profile.groups[copy]) and copy or nil
end

--- Customize a built-in (spec §12.2): the copy takes its place on every pad and dial, the built-in
--- is turned off, and the page selects the copy. A set already customized selects its copy.
function G.Customize(builtinId)
    local existing = G.CustomizedAs(builtinId)
    if existing then
        Ed.Select("group", existing)
        Ed.RequestRefresh()
        return existing
    end
    local copy = NS.Library.Customize(builtinId)
    if not copy then return nil end
    Ed.Select("group", copy)
    NS.Print(L["%s customized: the copy took its place on every pad."]:format(NS.BuiltIns.groups[builtinId].name))
    Ed.RequestRefresh()
    return copy
end

local function calloutLabel(cid)
    local c = NS.Library.Callout(cid)
    if not c then return cid end
    return ("%s  |cff808080%s|r"):format(c.name or cid, c.channel or "")
end

--- What "Add a callout" offers: the user callouts not in the group, by name, then every built-in
--- callout as "<set>: <name>" (adding one copies it, spec P2).
function G.AddableCallouts(gid)
    local have = {}
    for _, cid in ipairs((NS.db.profile.groups[gid] or {}).callouts or {}) do have[cid] = true end
    local user = {}
    for id, c in pairs(NS.db.profile.callouts) do
        if not have[id] then user[#user + 1] = { id = id, label = c.name or id } end
    end
    table.sort(user, function(a, b) return a.label:lower() < b.label:lower() end)
    local out = user
    local function addSet(gidB, prefix)
        local def = NS.BuiltIns.groups[gidB]
        for _, cid in ipairs(def.callouts or {}) do
            out[#out + 1] = { id = cid, label = L["%s: %s"]:format(prefix, NS.BuiltIns.callouts[cid].name) }
        end
        for _, child in ipairs(def.children or {}) do
            addSet(child, L["%s: %s"]:format(prefix, NS.BuiltIns.groups[child].name))
        end
    end
    for _, top in ipairs(NS.BuiltIns.order) do addSet(top, NS.BuiltIns.groups[top].name) end
    return out
end

function G.AddCallout(gid, cid) return NS.Library.AddToGroup(gid, cid) end
function G.MoveCallout(gid, from, to) return NS.Library.MoveInGroup(gid, from, to) end

local NONE = L["No groups yet. Click New group to make one."]

local function renderGeneral(ctx, rows)
    local h = H()
    local gid = Ed.Selected("group")
    h.RenderRows(ctx, { Ed.Row("state.previewAs") }, nil, nil, { noHeadings = true })
    if not (gid and NS.Library.Group(gid)) then
        h.TextRow(ctx, NONE)
        return
    end
    if isBuiltin(gid) then
        h.TextRow(ctx, L["%s is a built-in set: read-only, and updated with the addon. Customize makes an editable copy in its place on every pad."]
            :format(NS.BuiltIns.groups[gid].name))
        h.RenderRows(ctx, { Ed.Row("builtin.enabled") }, nil, nil, { noHeadings = true })
        local copy = G.CustomizedAs(gid)
        h.InlineButtonPair(ctx, {
            text = copy and L["Edit the copy"] or L["Customize"],
            tooltip = copy and L["This set is already customized: open its copy."]
                or L["Copy this set into a group you can edit, in its place on every pad, and turn the set off."],
            onClick = function() G.Customize(gid) end,
        }, nil)
        return
    end
    local mine = {}
    for _, row in ipairs(Ed.Scalar(rows)) do
        if row.path ~= "state.previewAs" then mine[#mine + 1] = row end
    end
    h.RenderRows(ctx, mine, nil, nil, { noHeadings = true })
    h.InlineButtonPair(ctx,
        { text = L["Duplicate"], tooltip = L["Make a copy of this group, with the same callouts and When."],
          onClick = function() G.Duplicate(gid) end },
        { text = L["Delete"], tooltip = L["Delete this group and take it off every pad. Its callouts are kept. Asks first."],
          onClick = function() G.Delete(gid) end })
end

local function renderBuiltinCallouts(ctx, gid)
    local h = H()
    h.TextRow(ctx, L["Untick a callout to hide it from every pad. A hidden callout stays in the set."])
    local hidden = (NS.db.profile.builtins[gid] or {}).hidden or {}
    local items = {}
    local function add(cid, prefix)
        local c = NS.BuiltIns.callouts[cid]
        local label = prefix and L["%s: %s"]:format(prefix, c.name) or c.name
        items[#items + 1] = { make = function(_, parent, rel)
            local cb = h.AceGUI:Create("CheckBox")
            cb:SetLabel(label)
            cb:SetValue(not hidden[cid])
            cb:SetRelativeWidth(rel or 0.5)
            cb:SetCallback("OnValueChanged", function(_, _, v)
                NS.Library.SetBuiltinCalloutHidden(gid, cid, not v)
            end)
            h.AttachTooltip(cb, c.name, c.text)
            parent:AddChild(cb)
            return cb
        end }
    end
    local def = NS.BuiltIns.groups[gid]
    for _, cid in ipairs(def.callouts or {}) do add(cid) end
    for _, child in ipairs(def.children or {}) do
        local node = NS.BuiltIns.groups[child]
        for _, cid in ipairs(node.callouts or {}) do add(cid, node.name) end
    end
    h.RenderGrid(ctx, items)
end

local function renderCallouts(ctx)
    local h = H()
    local gid = Ed.Selected("group")
    if not (gid and NS.Library.Group(gid)) then
        h.TextRow(ctx, NONE)
        return
    end
    if isBuiltin(gid) then return renderBuiltinCallouts(ctx, gid) end
    local list = NS.db.profile.groups[gid].callouts
    if #list == 0 then
        h.TextRow(ctx, L["No callouts in this group yet. Add one below."])
    else
        local entries = {}
        for i, cid in ipairs(list) do
            entries[i] = { id = cid, label = calloutLabel(cid),
                remove = function() NS.Library.RemoveFromGroup(gid, i) end }
        end
        Ed.ReorderRows(ctx, PAGE, entries, function(from, to) G.MoveCallout(gid, from, to) end)
    end
    h.RenderGrid(ctx, { Ed.ActionDropdown(L["Add a callout"],
        L["Add a callout to the end of this group. A built-in callout is copied into your callouts first."],
        G.AddableCallouts(gid), function(cid) G.AddCallout(gid, cid) end) })
end

local function renderPreview(ctx)
    local h = H()
    local gid = Ed.Selected("group")
    local g = gid and NS.Library.Group(gid)
    if not g then
        h.TextRow(ctx, NONE)
        return
    end
    -- Every line here is refreshed in place (Ed.Live) on a write or a situation change.
    local W = Settings.GroupsWhen
    local active = h.TextRow(ctx, W.ActiveText(gid))
    Ed.Live(ctx, function() if active then active:SetText(W.ActiveText(gid)) end end)
    local sections = NS.Surfaces.Sections(gid, NS.Library.Group)
    local any = false
    for _, sec in ipairs(sections) do
        if #sections > 1 then h.Section(ctx, sec.title) end
        local ids = sec.callouts
        local function lines()
            local out = {}
            for _, cid in ipairs(ids) do
                local c = NS.Library.Callout(cid)
                if c then out[#out + 1] = L["%s: %s"]:format(c.name, Settings.Callouts.PreviewLines(c)[1]) end
            end
            return out
        end
        local now = lines()
        if #now > 0 then
            any = true
            local label = h.TextRow(ctx, table.concat(now, "\n"))
            Ed.Live(ctx, function() if label then label:SetText(table.concat(lines(), "\n")) end end)
        end
    end
    if not any then h.TextRow(ctx, L["This group has no callouts yet."]) end
end

local function ids(entries)
    local out = {}
    for i, e in ipairs(entries) do out[i] = e.id end
    return out
end

local function render(ctx)
    local h = H()
    local entries = G.Entries()
    local selected = Ed.Heal("group", ids(entries))
    Ed.Select("group", selected)   -- keeps the built-in selection in step after a heal
    local list, order = Ed.PickerList(entries)
    h.PageBanner(ctx, {
        label = L["Group"], list = list, order = order, value = selected,
        tooltip = L["Which group this page edits. A green dot marks a group active now (or in the preview)."],
        onSelect = function(v)
            Ed.Select("group", v)
            Ed.RequestRefresh()
        end,
        action = { text = L["New group"], tooltip = L["Make a new group, put it at the top of every pad, and edit it here."],
            onClick = G.Create },
    })
    Ed.Tabs(ctx, PAGE, {
        { key = GENERAL, render = renderGeneral },
        { key = "callouts", label = L["Callouts"], tooltip = L["The callouts this group shows, in order."],
          before = WHEN, render = renderCallouts },
        { key = WHEN, render = function(c) Settings.GroupsWhen.Render(c, Ed.Selected("group")) end },
        { key = "preview", label = L["Preview"], tooltip = L["What each callout sends here, or in the preview."],
          render = renderPreview },
    })
end

--- The page's Defaults (options-ui-§13: page-wide, what the page draws). A user group: every row of
--- the page. A built-in set: its group rows refuse every write, and its General draws Preview as and
--- the overlay's Enabled row (whose page is share), so those two are what it resets, as one act.
function G.RestoreDefaults(ctx)
    local h = H()
    if not isBuiltin(Ed.Selected("group")) then return h.RestoreDefaults(PAGE, ctx) end
    local S = NS.SchemaRuntime
    S.BulkRun("reset", PAGE, function()
        S.ApplyDefault(Ed.Row("state.previewAs"))
        S.ApplyDefault(Ed.Row("builtin.enabled"))
    end)
    if h.RefreshPanel then h.RefreshPanel(ctx, false) end
end

Ed.RegisterPage(PAGE, L["Groups"], "GroupsPanel", render, {
    tooltip = L["Turn the selected group or built-in set back on, stop it opening the dial, and turn Preview as off. Its name, callouts and When are kept."],
    onClick = function(ctx) G.RestoreDefaults(ctx) end,
})
```
In `QuickComms.toc`, after `settings\Groups_When.lua`, add:
```
# LOAD-BEARING: takes Settings.Editors at load and registers the Groups page (after Callouts).
settings\Groups.lua
```

- [ ] **Step 4: Locale keys**

In `locales/enUS.lua`, under a new comment `-- Groups page (settings/Groups.lua)`:
```lua
L["New group"] = "New group"
L["%s customized: the copy took its place on every pad."] = "%s customized: the copy took its place on every pad."
L["%s is a built-in set: read-only, and updated with the addon. Customize makes an editable copy in its place on every pad."] = "%s is a built-in set: read-only, and updated with the addon. Customize makes an editable copy in its place on every pad."
L["Edit the copy"] = "Edit the copy"
L["Customize"] = "Customize"
L["This set is already customized: open its copy."] = "This set is already customized: open its copy."
L["Copy this set into a group you can edit, in its place on every pad, and turn the set off."] = "Copy this set into a group you can edit, in its place on every pad, and turn the set off."
L["Make a copy of this group, with the same callouts and When."] = "Make a copy of this group, with the same callouts and When."
L["Delete this group and take it off every pad. Its callouts are kept. Asks first."] = "Delete this group and take it off every pad. Its callouts are kept. Asks first."
L["Untick a callout to hide it from every pad. A hidden callout stays in the set."] = "Untick a callout to hide it from every pad. A hidden callout stays in the set."
L["No callouts in this group yet. Add one below."] = "No callouts in this group yet. Add one below."
L["Add a callout"] = "Add a callout"
L["Add a callout to the end of this group. A built-in callout is copied into your callouts first."] = "Add a callout to the end of this group. A built-in callout is copied into your callouts first."
L["This group has no callouts yet."] = "This group has no callouts yet."
L["Which group this page edits. A green dot marks a group active now (or in the preview)."] = "Which group this page edits. A green dot marks a group active now (or in the preview)."
L["Make a new group, put it at the top of every pad, and edit it here."] = "Make a new group, put it at the top of every pad, and edit it here."
L["The callouts this group shows, in order."] = "The callouts this group shows, in order."
L["Preview"] = "Preview"
L["What each callout sends here, or in the preview."] = "What each callout sends here, or in the preview."
L["Turn the selected group or built-in set back on, stop it opening the dial, and turn Preview as off. Its name, callouts and When are kept."] = "Turn the selected group or built-in set back on, stop it opening the dial, and turn Preview as off. Its name, callouts and When are kept."
```
(`L["%s: %s"]`, `L["%s (built-in)"]`, `L["Group"]`, `L["Callouts"]`, `L["Groups"]`, `L["Duplicate"]` and `L["Delete"]` exist from earlier tasks or phases.)

- [ ] **Step 5: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add settings/Groups.lua tests/test_page_groups.lua tests/run.lua QuickComms.toc locales/enUS.lua
git checkout -- settings/Groups.lua tests/test_page_groups.lua tests/run.lua QuickComms.toc locales/enUS.lua
git commit -m "Settings: the Groups page (picker, General, Callouts, When, Preview; built-ins read-only with Customize)"
```

---
### Task 10: The Comms Pad page

Spec §13.1, §10.2–§10.4 (as ruled toward options-ui-§14): a banner with the pad picker and "New pad"; tabs General, Groups, Layout and Look. General: "Preview as" first, the pad's Name and Enabled, then Unlock (or Lock) pads and Delete pad. Groups: "Show groups as", then the pad's groups as a drag-to-reorder list (its priority order) with Remove, then "Add a group". Layout: the layout rows, then Position (X and Y boxes writing the `pad.point` row the drag writes, and Reset this pad's position). Look: visibility, fade and faded alpha (ruling 9: the font group, border group and colors with their class-color companions arrive with phase 5's polish, added to §19 row 5 by Task 12). Every write reaches the pad through `LIBRARY_CHANGED` → `Surfaces.Request`, so a change made while the pad is in combat waits for combat end (the panel itself is locked in combat).

**Files:**
- Create: `settings/Pads.lua`; Modify: `QuickComms.toc` (after `settings\Groups.lua`)
- Create: `tests/test_page_pads.lua`; Modify: `tests/run.lua` (add `"test_page_pads",` after `"test_page_groups",`)
- Modify: `locales/enUS.lua`

**Interfaces:**
- Consumes: Task 6's `Ed.*` and `tests/page_helpers.lua`; Task 3a's `pad.*` rows and Task 4b's `state.previewAs` row; `NS.Library.CreateSurface`, `DeleteSurface`, `AddGroupToSurface`, `RemoveGroupFromSurface`, `MoveGroupOnSurface`, `Group`, `AllGroups`, `IsBuiltin`; `NS.Resolver.ActiveGroups`; `NS.SlashVerbs.ToggleLock`; `NS.Pad.DEFAULT_POINT` (Task 3b); `NS.Library.MemberIds`.
- Produces (`Settings.Pads`): `PD.Entries()`, `PD.Create() -> id|nil`, `PD.Delete(id)`, `PD.Point(id) -> { point, relativePoint, x, y }` (a copy), `PD.SetOffset(id, axis, text) -> boolean` (`axis` `"x"` or `"y"`), `PD.ResetPoint(id) -> boolean`, `PD.AddableGroups(id) -> { { id, label } }`, `PD.MoveGroup(id, from, to) -> boolean`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_page_pads.lua`:
```lua
-- tests/test_page_pads.lua — settings/Pads.lua (spec §10.2-§10.4, §13.1): the pad picker and New pad,
-- General's acts, the Groups priority list, Layout with the X/Y position, and Look. Driven headlessly
-- through tests/page_helpers.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function open(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or MPLUS end
    NS.Situation.RefreshNow("test")
    local P = dofile("tests/page_helpers.lua")(NS, m)
    P.show("Comms Pad")
    NS.addon.Settings.Editors.Select("pad", "p1")
    return NS, m, P
end

local function pointOf(inst)
    local p, _, rel, x, y = inst.root:GetPoint(1)
    return table.concat({ tostring(p), tostring(rel), tostring(x), tostring(y) }, ",")
end

test("pads page: New pad makes a second pad holding every built-in, selects it, and the pad is built", function()
    local NS, _, P = open()
    P.bannerAction(P.ctx("pads")):__fire("OnClick")
    P.flush()
    local id = NS.State.editing.pad
    assertTrue(id ~= "p1" and NS.db.profile.pads[id] ~= nil)
    assertEqual(NS.db.profile.pads[id].name, "Comms Pad 2")
    assertEqual(#NS.db.profile.pads[id].groups, #NS.BuiltIns.order)
    assertTrue(NS.Pad.Instance(id) ~= nil, "built by the rebuild LIBRARY_CHANGED asked for")
end)

test("pads page: the Layout rows write the selected pad", function()
    local NS, _, P = open()
    local w = P.tab("pads", "Layout")
    P.find(w, "Dropdown", "Orientation"):__fire("OnValueChanged", "vertical")
    P.find(w, "Dropdown", "Chip style"):__fire("OnValueChanged", "label")
    P.find(w, "Slider", "Scale"):__fire("OnMouseUp", 1.5)
    local layout = NS.db.profile.pads.p1.layout
    assertEqual(layout.orientation, "vertical")
    assertEqual(layout.style, "label")
    assertEqual(layout.scale, 1.5)
end)

test("pads page: X and Y move the pad through its pad.point row; Reset puts it back", function()
    local NS, m, P = open()
    local inst = NS.Pad.Instance("p1")
    local w = P.tab("pads", "Layout")
    P.find(w, "EditBox", "X offset"):__fire("OnEnterPressed", "40")
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "CENTER,CENTER,40,-150")
    w = P.tab("pads", "Layout")
    P.find(w, "EditBox", "Y offset"):__fire("OnEnterPressed", "-60")
    assertEqual(pointOf(inst), "CENTER,CENTER,40,-60", "the rebuild re-anchors the pad")
    m.prints = {}
    w = P.tab("pads", "Layout")
    P.find(w, "EditBox", "X offset"):__fire("OnEnterPressed", "left")
    assertTrue(table.concat(m.prints, "\n"):find("A position is a number of pixels.", 1, true) ~= nil)
    assertEqual(NS.db.profile.pads.p1.point[3], 40)
    w = P.tab("pads", "Layout")
    P.find(w, "Button", "Reset this pad's position"):__fire("OnClick")
    assertNil(NS.db.profile.pads.p1.point)
    assertEqual(pointOf(inst), "CENTER,CENTER,0,-150")
end)

test("pads page: Look's visibility reaches the pad's state driver", function()
    local NS, m, P = open()
    local w = P.tab("pads", "Look")
    P.find(w, "Dropdown", "Visibility"):__fire("OnValueChanged", "never")
    assertEqual(NS.db.profile.pads.p1.look.visibility, "never")
    assertEqual(m.stateDrivers[NS.Pad.Instance("p1").root].visibility, "hide")
end)

test("pads page: Groups lists the pad's groups; remove one, add it back at the end, drag to reorder", function()
    local NS, _, P = open()
    local lists = P.reorderSpy()
    local groups = NS.db.profile.pads.p1.groups
    local first, count = groups[1], #groups
    local w = P.tab("pads", "Groups")
    assertEqual(lists[#lists].rows, count)
    P.all(w, "Button", "Remove")[1]:__fire("OnClick")
    assertEqual(#NS.db.profile.pads.p1.groups, count - 1)
    w = P.tab("pads", "Groups")
    P.find(w, "Dropdown", "Add a group"):__fire("OnValueChanged", first)
    assertEqual(NS.db.profile.pads.p1.groups[count], first, "added back at the end")
    P.tab("pads", "Groups")
    lists[#lists].opts.onMove(count, 1)
    assertEqual(NS.db.profile.pads.p1.groups[1], first, "dragged to the top")
end)

test("pads page: Delete pad asks, then the pad is gone, its frame released, and the page heals", function()
    local NS, _, P = open()
    local id = NS.addon.Settings.Pads.Create()
    P.flush()
    assertTrue(NS.Pad.Instance(id).live)
    local w = P.redraw("pads")
    P.find(w, "Button", "Delete pad"):__fire("OnClick")
    assertTrue(NS.db.profile.pads[id] ~= nil, "asks first")
    P.accept()
    assertNil(NS.db.profile.pads[id])
    assertFalse(NS.Pad.Instance(id).live, "released by Pad.Sync")
    P.flush()
    P.redraw("pads")
    assertEqual(NS.State.editing.pad, "p1")
end)

test("pads page: General's Unlock pads toggles the one lock", function()
    local NS, _, P = open()
    local w = P.redraw("pads")
    assertTrue(P.find(w, "Dropdown", "Preview as") ~= nil, "Preview as is page-wide, first")
    P.find(w, "Button", "Unlock pads"):__fire("OnClick")
    assertFalse(NS.Setting("locked"))
    P.flush()
    w = P.redraw("pads")
    P.find(w, "Button", "Lock pads"):__fire("OnClick")
    assertTrue(NS.Setting("locked"))
end)
```
In `tests/run.lua`, add `"test_page_pads",` after `"test_page_groups",`.

- [ ] **Step 2: Run the tests to check they fail**

Run: `lua tests/run.lua`
Expected: FAIL (`m.__subcategories["Comms Pad"]` is nil: no page).

- [ ] **Step 3: The page**

(`NS.Pad.DEFAULT_POINT` was published in Task 3b, for the CLI's `x y` form.)


Create `settings/Pads.lua`:
```lua
local _, NS = ...
-- settings/Pads.lua — the Comms Pad page (design spec §10.2-§10.4, §13.1): one pad at a time.
--
--     band     [ Pad v (picker) ][ New pad ]
--     strip    [ General ][ Groups ][ Layout ][ Look ]
--     General  Preview as (page-wide, first), Name, Enabled, then Unlock (or Lock) pads and Delete pad
--     Groups   Show groups as, then the pad's groups as a drag-to-reorder list with Remove (its
--              priority order, spec §7), then Add a group
--     Layout   orientation, grid columns, growth, chip style, scale, spacing, chip width, then
--              Position: X and Y and Reset this pad's position
--     Look     visibility, fade and faded alpha
--
-- The band holds the picker and the create action (options-ui-§14). Every field is a member row
-- (settings/SchemaMembers.lua) written to the selected pad; the pad redraws through LIBRARY_CHANGED
-- -> Surfaces.Request, which waits for combat end when it must. X and Y write the whole `pad.point`
-- row, the same one the drag strip writes (spec §5.1). The pad's list order and membership are
-- Library's (MoveGroupOnSurface, Add/RemoveGroupFromSurface). Lock is the one master lock. A write to
-- a pad's fields refreshes the tab in place (only its name repaints, settings/Editors.lua); the X/Y
-- boxes have their own refreshers, so a drag on screen updates them.

local QC = NS.addon
local Settings = QC.Settings
local Ed = Settings.Editors
local L = NS.L

local PAGE = "pads"
local GENERAL = L["General"]
local GROUPS = L["Groups"]
local LAYOUT = L["Layout"]
local LOOK = L["Look"]

Settings.Pads = Settings.Pads or {}
local PD = Settings.Pads

local function H() return Settings.Helpers end

function PD.Entries()
    local pads = NS.db.profile.pads
    local out = {}
    for _, id in ipairs(NS.Library.MemberIds("pad")) do out[#out + 1] = { id = id, label = pads[id].name or id } end
    return out
end

function PD.Create()
    local id = NS.Library.CreateSurface("pad", L["Comms Pad %d"]:format(#NS.db.profile.padOrder + 1))
    if id then
        Ed.Select("pad", id)
        Ed.RequestRefresh()
    end
    return id
end

function PD.Delete(id)
    local pad = NS.db.profile.pads[id]
    if not pad then return end
    Ed.ConfirmDelete(pad.name or id, function() NS.Library.DeleteSurface("pad", id) end)
end

--- The pad's anchor, or the default one; a copy.
function PD.Point(id)
    local pad = NS.db.profile.pads[id]
    local pt = (pad and type(pad.point) == "table") and pad.point or NS.Pad.DEFAULT_POINT
    return { pt[1], pt[2], pt[3], pt[4] }
end

--- Move the pad by a typed X or Y offset: the whole `pad.point` row, through the seam.
function PD.SetOffset(id, axis, text)
    local n = tonumber((text or ""):match("^%s*(-?%d+%.?%d*)%s*$"))
    if not n then
        NS.Print(L["A position is a number of pixels."])
        return false
    end
    local pt = PD.Point(id)
    if axis == "x" then pt[3] = n else pt[4] = n end
    return (NS.SchemaRuntime.Set("pad.point", pt, id)) == true
end

function PD.ResetPoint(id)
    return (NS.SchemaRuntime.Set("pad.point", nil, id)) == true
end

local function groupLabel(gid, active)
    local g = NS.Library.Group(gid)
    local name = g and g.name or gid
    if NS.Library.IsBuiltin(gid) then name = L["%s (built-in)"]:format(name) end
    return ((active and active[gid]) and Ed.ACTIVE_DOT or "") .. name
end

--- The groups the pad does not list: user groups by name, then the top-level built-ins in order.
function PD.AddableGroups(id)
    local on = {}
    for _, gid in ipairs(NS.db.profile.pads[id].groups) do on[gid] = true end
    local user = {}
    for gid, g in pairs(NS.db.profile.groups) do
        if not on[gid] then user[#user + 1] = { id = gid, label = g.name or gid } end
    end
    table.sort(user, function(a, b) return a.label:lower() < b.label:lower() end)
    for _, gid in ipairs(NS.BuiltIns.order) do
        if not on[gid] then user[#user + 1] = { id = gid, label = groupLabel(gid) } end
    end
    return user
end

function PD.MoveGroup(id, from, to)
    return NS.Library.MoveGroupOnSurface("pad", id, from, to)
end

local NONE = L["No pads yet. Click New pad to make one."]

local function selected()
    local id = Ed.Selected("pad")
    return (id and NS.db.profile.pads[id]) and id or nil
end

local function renderGeneral(ctx, rows)
    local h = H()
    h.RenderRows(ctx, { Ed.Row("state.previewAs") }, nil, nil, { noHeadings = true })
    local id = selected()
    if not id then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Scalar(rows), nil, nil, { noHeadings = true })
    local locked = NS.Setting("locked") ~= false
    h.InlineButtonPair(ctx,
        { text = locked and L["Unlock pads"] or L["Lock pads"],
          tooltip = L["Unlocked, every pad shows a strip to drag it by. The same switch as /qc lock and /qc unlock."],
          onClick = function()
              NS.SlashVerbs.ToggleLock()
              Ed.RequestRefresh()
          end },
        { text = L["Delete pad"], tooltip = L["Delete this pad. Its groups and callouts are kept. Asks first."],
          onClick = function() PD.Delete(id) end })
end

local function renderGroups(ctx, rows)
    local h = H()
    local id = selected()
    if not id then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Scalar(rows), nil, nil, { noHeadings = true })
    local list = NS.db.profile.pads[id].groups
    if #list == 0 then
        h.TextRow(ctx, L["This pad lists no group. Add one below."])
    else
        h.TextRow(ctx, L["Higher groups come first on the pad. Drag to reorder."])
        local active = NS.Resolver.ActiveGroups(NS.Library.AllGroups(), Ed.Snapshot())
        local entries = {}
        for i, gid in ipairs(list) do
            entries[i] = { id = gid, label = groupLabel(gid, active),
                remove = function() NS.Library.RemoveGroupFromSurface("pad", id, gid) end }
        end
        Ed.ReorderRows(ctx, PAGE, entries, function(from, to) PD.MoveGroup(id, from, to) end)
    end
    h.RenderGrid(ctx, { Ed.ActionDropdown(L["Add a group"], L["Add a group to the end of this pad's list."],
        PD.AddableGroups(id), function(gid) NS.Library.AddGroupToSurface("pad", id, gid) end) })
end

-- One offset box. Its refresher (a scalar refresh, never a situation change) puts it back to the
-- stored point after any write, the drag's included.
local function offsetBox(ctx, id, label, axis)
    local index = axis == "x" and 3 or 4
    return { make = function(_, parent, rel)
        local eb = H().AceGUI:Create("EditBox")
        eb:SetLabel(label)
        eb:SetText(tostring(PD.Point(id)[index]))
        if ctx.refreshers then
            ctx.refreshers[#ctx.refreshers + 1] = function() eb:SetText(tostring(PD.Point(id)[index])) end
        end
        eb:SetRelativeWidth(rel or 0.5)
        eb:SetCallback("OnEnterPressed", function(_, _, text) PD.SetOffset(id, axis, text) end)
        H().AttachTooltip(eb, label, L["Pixels from the pad's anchor. Press Enter to apply."])
        parent:AddChild(eb)
        return eb
    end }
end

local function renderLayout(ctx, rows)
    local h = H()
    local id = selected()
    if not id then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Scalar(rows), nil, nil, { noHeadings = true })
    h.Section(ctx, L["Position"])
    h.RenderGrid(ctx, { offsetBox(ctx, id, L["X offset"], "x"), offsetBox(ctx, id, L["Y offset"], "y") })
    h.InlineButtonPair(ctx, { text = L["Reset this pad's position"],
        tooltip = L["Put this pad back in its default place."], onClick = function() PD.ResetPoint(id) end }, nil)
end

local function renderLook(ctx, rows)
    local h = H()
    if not selected() then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Scalar(rows), nil, nil, { noHeadings = true })
end

local function ids(entries)
    local out = {}
    for i, e in ipairs(entries) do out[i] = e.id end
    return out
end

local function render(ctx)
    local h = H()
    local entries = PD.Entries()
    local sel = Ed.Heal("pad", ids(entries))
    local list, order = Ed.PickerList(entries)
    h.PageBanner(ctx, {
        label = L["Pad"], list = list, order = order, value = sel,
        tooltip = L["Which Comms Pad this page edits."],
        onSelect = function(v)
            Ed.Select("pad", v)
            Ed.RequestRefresh()
        end,
        action = { text = L["New pad"], tooltip = L["Make a new Comms Pad showing every built-in set, and edit it here."],
            onClick = PD.Create },
    })
    Ed.Tabs(ctx, PAGE, {
        { key = GENERAL, render = renderGeneral },
        { key = GROUPS, render = renderGroups },
        { key = LAYOUT, render = renderLayout },
        { key = LOOK, render = renderLook },
    })
end

Ed.RegisterPage(PAGE, L["Comms Pad"], "PadsPanel", render, {
    tooltip = L["Put the selected pad's groups-as, layout and look back to their defaults, and turn it on. Its name, groups and position are kept."],
    onClick = function(ctx) H().RestoreDefaults(PAGE, ctx) end,
})
```
In `QuickComms.toc`, after `settings\Groups.lua`, add:
```
# LOAD-BEARING: takes Settings.Editors at load and registers the Comms Pad page (after Groups).
settings\Pads.lua
```

- [ ] **Step 4: Locale keys**

In `locales/enUS.lua`, under a new comment `-- Comms Pad page (settings/Pads.lua)`:
```lua
L["Comms Pad %d"] = "Comms Pad %d"
L["A position is a number of pixels."] = "A position is a number of pixels."
L["No pads yet. Click New pad to make one."] = "No pads yet. Click New pad to make one."
L["Unlock pads"] = "Unlock pads"
L["Lock pads"] = "Lock pads"
L["Unlocked, every pad shows a strip to drag it by. The same switch as /qc lock and /qc unlock."] = "Unlocked, every pad shows a strip to drag it by. The same switch as /qc lock and /qc unlock."
L["Delete pad"] = "Delete pad"
L["Delete this pad. Its groups and callouts are kept. Asks first."] = "Delete this pad. Its groups and callouts are kept. Asks first."
L["This pad lists no group. Add one below."] = "This pad lists no group. Add one below."
L["Higher groups come first on the pad. Drag to reorder."] = "Higher groups come first on the pad. Drag to reorder."
L["Add a group"] = "Add a group"
L["Add a group to the end of this pad's list."] = "Add a group to the end of this pad's list."
L["Pixels from the pad's anchor. Press Enter to apply."] = "Pixels from the pad's anchor. Press Enter to apply."
L["X offset"] = "X offset"
L["Y offset"] = "Y offset"
L["Reset this pad's position"] = "Reset this pad's position"
L["Put this pad back in its default place."] = "Put this pad back in its default place."
L["Pad"] = "Pad"
L["Which Comms Pad this page edits."] = "Which Comms Pad this page edits."
L["New pad"] = "New pad"
L["Make a new Comms Pad showing every built-in set, and edit it here."] = "Make a new Comms Pad showing every built-in set, and edit it here."
L["Put the selected pad's groups-as, layout and look back to their defaults, and turn it on. Its name, groups and position are kept."] = "Put the selected pad's groups-as, layout and look back to their defaults, and turn it on. Its name, groups and position are kept."
```

- [ ] **Step 5: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS, including `test_pad`'s `[registry]` grep (this file builds a new point table and hands it to the seam; it never assigns `.point`).

- [ ] **Step 6: Commit**

```bash
git add settings/Pads.lua tests/test_page_pads.lua tests/run.lua QuickComms.toc locales/enUS.lua
git checkout -- settings/Pads.lua tests/test_page_pads.lua tests/run.lua QuickComms.toc locales/enUS.lua
git commit -m "Settings: the Comms Pad page (picker, groups priority list, layout with X/Y, look)"
```

---
### Task 11: The Share page's Built-in tab

Spec §13.1: "Share — Tabs: Export, Import, **Built-in** (the list of built-in sets with an enabled toggle, Customize, and a hidden-callouts editor)". Phase 3 ships the page with its Built-in tab (Export and Import join in phase 5, ahead of it). One line per shipped set: an Enabled checkbox named after the set, Customize (or "Edit the copy" once customized), and "Choose callouts", which opens the set on the Groups page's Callouts tab, the hidden-callouts editor Task 9 built (ruling 7: one editor, reached from both pages). The page's Defaults button turns every set back on and shows all of their callouts.

**Files:**
- Create: `settings/Share.lua`; Modify: `QuickComms.toc` (after `settings\Pads.lua`)
- Modify: `modules/Library.lua` (`Lib.Batch`)
- Create: `tests/test_page_share.lua`; Modify: `tests/run.lua` (add `"test_page_share",` after `"test_page_pads",`); Modify: `tests/test_library.lua` (one case)
- Modify: `locales/enUS.lua`

**Interfaces:**
- Consumes: Task 6's `Ed.*` and `tests/page_helpers.lua`; Task 9's `Settings.Groups.Customize`, `CustomizedAs`, `G.PAGE`; `NS.Library.Group`, `SetBuiltinEnabled`; `NS.SchemaRuntime.Set("builtin.hidden", {}, id)`; `NS.BuiltIns.order / groups`.
- Produces (`Settings.Share`): `SH.Customize(id) -> copyId|nil` (and opens the Groups page on the copy); `SH.ChooseCallouts(id) -> boolean` (selects the set, puts the Groups page on its Callouts tab, opens it); `SH.RestoreAll()` (one bulk act: one `[Set] reset share: N rows` line, one `LIBRARY_CHANGED`, so one pad rebuild and one repaint; the Defaults button that calls it is refused in combat by the options library at the control, `libs/LibKa0s/Options.lua` line 795).
- Produces (`modules/Library.lua`): `Lib.Batch(fn)` (runs `fn` with Library's announces held, then sends one `LIBRARY_CHANGED (kind)` per kind it touched, with no id and no field; nested calls join the outer one; an error is re-raised after the announces).

- [ ] **Step 1: Write the failing tests**

Create `tests/test_page_share.lua`:
```lua
-- tests/test_page_share.lua — settings/Share.lua (spec §13.1, §12.2): the Built-in tab. Each shipped set
-- is one line: Enabled, Customize, Choose callouts. Defaults turns every set back on. Driven headlessly
-- through tests/page_helpers.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function open()
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    local P = dofile("tests/page_helpers.lua")(NS, m)
    P.show("Share")
    return NS, m, P
end

test("share page: every shipped set has a line; turning M+ off takes it off the pad", function()
    local NS, _, P = open()
    local w = P.redraw("share")
    assertEqual(#P.all(w, "Button", "Customize"), #NS.BuiltIns.order)
    local box = P.find(w, "CheckBox", "M+ (generic)")
    assertTrue(box ~= nil and box.value == true)
    box:__fire("OnValueChanged", false)
    assertFalse(NS.db.profile.builtins["bi.mplus"].enabled)
    assertTrue(NS.Pad.ChipsFor("p1", "bi.mplus.pull")[1] == nil, "the pad dropped the set")
end)

test("share page: [review 4] Customize puts the copy in the set's place, selects it and opens the Groups page", function()
    local NS, m, P = open()
    local opened
    m.Settings.OpenToCategory = function(id) opened = id end
    NS.addon.Settings.Editors.categories.groups = { GetID = function() return 3 end }
    local w = P.redraw("share")
    local buttons = P.all(w, "Button", "Customize")
    local index
    for i, gid in ipairs(NS.BuiltIns.order) do if gid == "bi.mplus" then index = i end end
    buttons[index]:__fire("OnClick")
    local copy = NS.State.editing.group
    assertTrue(NS.db.profile.groups[copy] ~= nil)
    assertEqual(NS.db.profile.pads.p1.groups[1], copy, "bi.mplus was first; the copy is first")
    assertFalse(NS.db.profile.builtins["bi.mplus"].enabled)
    assertEqual(opened, 3)
    w = P.redraw("share")
    assertTrue(P.find(w, "Button", "Edit the copy") ~= nil)
end)

test("share page: Choose callouts opens the set on the Groups page's Callouts tab", function()
    local NS, _, P = open()
    local w = P.redraw("share")
    P.all(w, "Button", "Choose callouts")[1]:__fire("OnClick")
    assertEqual(NS.State.editing.group, NS.BuiltIns.order[1])
    assertEqual(NS.addon.Settings.Editors.pages.groups.activeTab, "callouts")
end)

test("share page: Defaults turns every set back on and shows all of their callouts, as one act", function()
    local NS, _, P = open()
    NS.Library.SetBuiltinEnabled("bi.raid", false)
    NS.Library.SetBuiltinCalloutHidden("bi.mplus", "bi.mplus.lust", true)
    local changes, rebuilds = 0, 0
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.LIBRARY_CHANGED, function() changes = changes + 1 end)
    local request = NS.Surfaces.Request
    NS.Surfaces.Request = function(...) rebuilds = rebuilds + 1 return request(...) end
    P.ctx("share").panel.defaultsOnClick()
    NS.Surfaces.Request = request
    assertTrue(NS.db.profile.builtins["bi.raid"].enabled)
    assertTrue(next(NS.db.profile.builtins["bi.mplus"].hidden) == nil)
    -- red under: drop Lib.Batch from SH.RestoreAll (one announce, and one rebuild, per set and field)
    assertEqual(changes, 1)
    assertTrue(rebuilds <= 1, "one pad rebuild")
end)
```
In `tests/run.lua`, add `"test_page_share",` after `"test_page_pads",`.

- [ ] **Step 2: Run the tests to check they fail**

Run: `lua tests/run.lua`
Expected: FAIL (`m.__subcategories.Share` is nil: no page).

- [ ] **Step 3: The page**

Create `settings/Share.lua`:
```lua
local _, NS = ...
-- settings/Share.lua — the Share page (design spec §13.1, §12.2). Phase 3 ships its Built-in tab;
-- Export and Import join it, ahead of it, in phase 5.
--
--     strip     [ Built-in ]
--     Built-in  one line per shipped set: an Enabled checkbox named after the set, then Customize (or
--               Edit the copy) and Choose callouts
--
-- Enabled is the set's `builtin.enabled` member row, written through the seam with the set's id.
-- Customize is Library's (the copy takes the set's place on every pad and dial, and the set is turned
-- off) and opens the Groups page on the copy. Choose callouts opens the set on the Groups page's
-- Callouts tab, the one hidden-callouts editor. The page edits no single instance, so its band has no
-- picker. Defaults turns every set back on and shows all of their callouts.

local QC = NS.addon
local Settings = QC.Settings
local Ed = Settings.Editors
local L = NS.L

local PAGE = "share"
local BUILTIN = L["Built-in"]

Settings.Share = Settings.Share or {}
local SH = Settings.Share

local function H() return Settings.Helpers end

function SH.Customize(id)
    local copy = Settings.Groups.Customize(id)
    if copy then Ed.Open(Settings.Groups.PAGE) end
    return copy
end

function SH.ChooseCallouts(id)
    Ed.Select("group", id)
    local groups = Ed.pages[Settings.Groups.PAGE]
    if groups then groups.activeTab = "callouts" end
    return Ed.Open(Settings.Groups.PAGE)
end

--- Every set back on, every callout shown (the page's Defaults; its blast radius is the whole list).
--- One act: one bulk bracket (debug-logging-§10: one `[Set] reset share: N rows` line) and one
--- coalesced LIBRARY_CHANGED (Lib.Batch), so the pads rebuild once and the pages repaint once. The
--- Defaults button is refused in combat by the options library, at the control.
function SH.RestoreAll()
    local S = NS.SchemaRuntime
    S.BulkRun("reset", PAGE, function()
        NS.Library.Batch(function()
            for _, id in ipairs(NS.BuiltIns.order) do
                S.Set("builtin.enabled", true, id)
                S.Set("builtin.hidden", {}, id)
            end
        end)
    end)
end

local function renderBuiltIn(ctx)
    local h = H()
    h.TextRow(ctx, L["The callout sets that ship with Quick Comms. Turn a set off, Customize it into a group you can edit, or choose which of its callouts show."])
    local items = {}
    for _, id in ipairs(NS.BuiltIns.order) do
        local def = NS.BuiltIns.groups[id]
        local group = NS.Library.Group(id)
        items[#items + 1] = { make = function(_, parent, rel)
            local cb = h.AceGUI:Create("CheckBox")
            cb:SetLabel(def.name)
            cb:SetValue(group and group.enabled ~= false)
            cb:SetRelativeWidth(rel or 0.5)
            cb:SetCallback("OnValueChanged", function(_, _, v) NS.Library.SetBuiltinEnabled(id, v and true or false) end)
            h.AttachTooltip(cb, def.name, L["Show this set wherever it matches. Off keeps it, and its place on every pad."])
            parent:AddChild(cb)
            return cb
        end }
        items[#items + 1] = { make = function(_, parent, rel)
            local AceGUI = h.AceGUI
            local row = AceGUI:Create("SimpleGroup")
            row:SetLayout("Flow")
            row:SetRelativeWidth(rel or 0.5)
            local copy = Settings.Groups.CustomizedAs(id)
            local customize = AceGUI:Create("Button")
            customize:SetText(copy and L["Edit the copy"] or L["Customize"])
            customize:SetRelativeWidth(0.48)
            customize:SetCallback("OnClick", function() SH.Customize(id) end)
            row:AddChild(customize)
            local choose = AceGUI:Create("Button")
            choose:SetText(L["Choose callouts"])
            choose:SetRelativeWidth(0.48)
            choose:SetCallback("OnClick", function() SH.ChooseCallouts(id) end)
            row:AddChild(choose)
            parent:AddChild(row)
            return row
        end }
    end
    h.RenderGrid(ctx, items)
end

local function render(ctx)
    Ed.Tabs(ctx, PAGE, { { key = BUILTIN, render = renderBuiltIn } })
end

Ed.RegisterPage(PAGE, L["Share"], "SharePanel", render, {
    tooltip = L["Turn every built-in set back on and show all of their callouts. Your customized copies are kept."],
    onClick = function() SH.RestoreAll() end,
})
```
In `QuickComms.toc`, after `settings\Pads.lua`, add:
```
# LOAD-BEARING: takes Settings.Editors at load and registers the Share page (after Comms Pad, before Profiles).
settings\Share.lua
```

- [ ] **Step 4: Library's batch**

Append to `tests/test_library.lua`:
```lua
test("library: [phase 3] Batch holds the announces and sends one per kind it touched", function()
    local NS, Lib, _, sent = boot()
    local before = #sent
    Lib.Batch(function()
        Lib.SetBuiltinEnabled("bi.raid", false)
        Lib.SetBuiltinEnabled("bi.arena", false)
        Lib.Batch(function() Lib.SetBuiltinEnabled("bi.mplus", false) end)
    end)
    -- red under: announce inside Lib.Batch as usual (three messages)
    assertEqual(#sent - before, 1)
    assertEqual(sent[#sent][1], NS.MSG.LIBRARY_CHANGED)
    assertEqual(sent[#sent][2], "builtin")
    assertNil(sent[#sent][3], "no id: several members changed")
    assertFalse(NS.db.profile.builtins["bi.mplus"].enabled)
    Lib.SetBuiltinEnabled("bi.raid", true)
    assertEqual(#sent - before, 2, "announces flow again after the batch")
end)
```
In `modules/Library.lua`, replace the file-local `announce` (as Task 2 left it) with:
```lua
-- While Lib.Batch runs, the kinds announced, to send once each when it ends; nil otherwise.
local batched

local function announce(kind, id, field)
    if batched then
        batched[kind] = true
        return
    end
    NS.Debug(TAG, "%s %s%s", kind, tostring(id), field and (" " .. field) or "")
    NS.addon:SendMessage(NS.MSG.LIBRARY_CHANGED, kind, id, field)
end
```
and, after `Lib.Touch`, add:
```lua
--- Run `fn` with Library's announces held, then send one LIBRARY_CHANGED per kind it touched, with no
--- id and no field (several members changed): a bulk act (Share's Defaults) rebuilds the pads and
--- repaints the pages once. A nested call joins the outer batch. An error in `fn` is re-raised after
--- the held announces are sent, so nothing that landed goes unannounced.
function Lib.Batch(fn)
    if batched then return fn() end
    batched = {}
    local ok, err = pcall(fn)
    local kinds = {}
    for kind in pairs(batched) do kinds[#kinds + 1] = kind end
    batched = nil
    table.sort(kinds)
    for _, kind in ipairs(kinds) do announce(kind, nil) end
    if not ok then error(err, 0) end
end
```

- [ ] **Step 5: Locale keys**

In `locales/enUS.lua`, under a new comment `-- Share page (settings/Share.lua)`:
```lua
L["The callout sets that ship with Quick Comms. Turn a set off, Customize it into a group you can edit, or choose which of its callouts show."] = "The callout sets that ship with Quick Comms. Turn a set off, Customize it into a group you can edit, or choose which of its callouts show."
L["Show this set wherever it matches. Off keeps it, and its place on every pad."] = "Show this set wherever it matches. Off keeps it, and its place on every pad."
L["Choose callouts"] = "Choose callouts"
L["Share"] = "Share"
L["Turn every built-in set back on and show all of their callouts. Your customized copies are kept."] = "Turn every built-in set back on and show all of their callouts. Your customized copies are kept."
```

- [ ] **Step 6: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS, and `test_setup`'s options cases still find General under the category (the sidebar is now General, Callouts, Groups, Comms Pad, Share, then Profiles where AceDBOptions resolves).

- [ ] **Step 7: Commit**

```bash
git add settings/Share.lua modules/Library.lua tests/test_page_share.lua tests/test_library.lua tests/run.lua QuickComms.toc locales/enUS.lua
git checkout -- settings/Share.lua modules/Library.lua tests/test_page_share.lua tests/test_library.lua tests/run.lua QuickComms.toc locales/enUS.lua
git commit -m "Settings: the Share page's Built-in tab (enable, Customize, choose callouts)"
```

**Milestone 2 checkpoint.** Green; every page renders headlessly and its suite drives it. Record it in this plan's checkboxes before Task 12.

---
### Task 12: The docs for phase 3

Documentation only, plus the regenerated test inventory and the README badge. No deviation is recorded: the one considered (the table-valued member rows on the CLI) is met through the Slash descriptor's `parse` and `format` hooks (Task 3b).

**Files:**
- Modify: `docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md` (the rulings, Step 0)
- Modify: `docs/ARCHITECTURE.md`, `docs/module-map.md`, `docs/schema.md`, `docs/settings-panel.md`, `docs/data-flow.md`, `docs/scope.md`, `docs/slash-dispatch.md`, `docs/compat-layer.md`, `docs/common-tasks.md`, `docs/testing.md`, `docs/smoke-tests.md`, `docs/test-cases.md` (regenerated), `README.md`

**Interfaces:**
- Consumes: everything Tasks 1–11 built, by the names they produce.
- Produces: documentation only; no code changes.

- [ ] **Step 0: Write the rulings into the spec**

In `docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md`:
- **§4.3, the `Library` row's Owns cell:** append "*Built (phase 3):* membership, the order of every list, the references a group and a surface hold, the ids and the seeding. A member's own fields (a callout's text, a group's When, a pad's layout and position, a built-in's overlay) are schema rows written through the one seam (architecture-§5), resolved by `Library.Member` and announced by `Library.Touch`."
- **§5.1, named non-setting state:** replace the bullet's `pads[id].point` sentence with "`pads[id].point` is the `pad.point` member row: the drag, the X/Y boxes and Reset position write it through the seam (the drag through `Library.SetSurfacePoint`). It is a preference, not named state, because a control sets it." Add a bullet: "**The editors' selection** (`NS.State.editing`, session-only) is the member each editor page has selected; a member row written with no instance argument writes it."
- **§7:** after the `Resolver.Explain` sentence, append "*Built (phases 1, 3):* `Explain` names the When rows that matched (`M+ (generic) (built-in): Content`), not their values (`Content = Mythic+ ✓`): the row is what a player changes on the When tab, and the values are on that tab."
- **§8.1:** after the table, append "*Built (phase 3):* the Callouts page's picker offers `{target}`, `{focus}`, the eight markers by name (`{star}`…`{skull}`; a typed `{rt1}`…`{rt8}` works the same), `{me}`, `{spec}`, `{role}`, `{key}` and `{dungeon}`, plus `{group1}`…`{group8}` only when the callout's channel can resolve to Raid (raid, raid warning, smart group, smart lead). `{spell:ID}` needs an id, so it is typed, never picked; the Text row's tooltip names it."
- **§10.3, Look:** append "*Built (phase 3):* the pad's Look tab has visibility, fade and the faded alpha; the font group, border group and colors with their class-color companions arrive with phase 5's polish (§19 row 5)."
- **§13.1, the table:** in the Callouts row replace "Tabs: **Message** has … Page-wide acts (rename, duplicate, delete) sit on the Message tab." with "Tabs: **General** has name, text with a token picker and the live line (the baked line and its byte count under the current or previewed situation, or why it sends nothing, and the padlock text), channel, an icon box (a texture id or path; a LibKa0s icon by its path; the visual picker arrives with phase 5's polish, §19 row 5), then Duplicate and Delete (options-ui-§14: a page's acts sit on its first tab, named General). The live line is the byte counter: it follows each committed write (Enter in the Text box), not each keystroke. **Used by** lists the groups that reference it, each a link to the Groups page." In the Groups row replace "A nav rail of groups, plus the banner picker, a create box and an active-now dot." with "The banner picker (user groups by name, then the built-in sets; a green dot marks a group active now or in the preview) and New group, which puts the group at the top of every pad and dial; no nav rail (options-ui-§14: the rail is not a picker)." and add "For a built-in, General has its Enabled row and Customize, and Callouts is the hidden-callouts editor." In the Comms Pad row replace "A nav rail of pads." with "The banner picker and New pad; no nav rail." and add "General also has Preview as, Unlock pads and Delete pad; Layout ends with the X and Y offsets and Reset this pad's position." In the Comms Dial row replace "A nav rail of dials." with "The banner picker and New dial (phase 4); no nav rail." In the Share row add "*Built (phase 3):* the Built-in tab only, one line per set (Enabled, Customize, Choose callouts, which opens the set's hidden-callouts editor on the Groups page); Export and Import join in phase 5."
- **§13.2:** append "*Built (phase 3):* checkbox rows for content, difficulty, group, leadership, class, specialization (the classes picked, else the player's) and role; a lowest and highest box for the key level; the library's IdList for instances, battlegrounds and characters (`Name-Realm`), each with an add-the-one-you-are-in button. The shipped id table (`defaults/GameIds.lua`) lists the season's returning dungeons; the Midnight dungeon and raid ids are confirmed in game in phase 5, with the battleground ids."
- **§13.3:** replace "A banner dropdown on the Groups, Pad and Dial pages, with these entries:" with "A session row, `state.previewAs`, drawn first on the General tab of the Groups and Comms Pad pages (and the Dial page in phase 4), and `/qc preview <name>` from the command line, with these entries:"; after "It is session-only, and switches off when the panel closes or combat starts." add "*Built (phase 3):* it is test mode's second flavor: one switch at a time with the placeholders, refused in combat and while disabled, ended at the start of combat, by the stand-down and when the settings window closes. Every previewed chip is disarmed (it sends, prints and reports nothing) and its tooltip says so; the header reads `Preview: <situation>` and shows PREVIEW. The dungeon entries are the shipped ids (`defaults/GameIds.lua`), each `M+ · <dungeon> · <spec>` as listed above (`M+ · <dungeon>` when the spec is unknown), after a generic `M+ · <spec>`."
- **§17, `TEST_MODE_CHANGED`:** change the Payload cell to "on (true while test mode or Preview as… is on)" and the Consumers cell to "Surfaces (rebuilds the pads from the test or preview plan), the editor pages (repaint), Dial".
- **§17, `LIBRARY_CHANGED`:** change the Sender cell to "Library (its own writes, and `Library.Touch` for every member row the seam writes)" and the Payload cell to "kind, id, field (the member row's path for a field write; none for membership, order or a batch)".
- **§19, row 5 (Share, polish, release):** in the content cell, after "Share (codec tests, import report).", add "Editor polish: the pad's Look font group, border group and colors with class-color companions (options-ui-§16/§17, the composed controls), and a visual icon picker for callouts and groups."

- [ ] **Step 1: ARCHITECTURE.md**

- The intro: add `[superpowers/plans/2026-10-13-quickcomms-phase-3.md](superpowers/plans/2026-10-13-quickcomms-phase-3.md)` to the build-order sentence.
- **Overview:** replace "At the end of phase 2 … the editors are phase 3 and the Comms Dial phase 4." with "At the end of phase 3 the data layer feeds the secure send engine and the Comms Pads, and the player edits callouts, groups (with their When), pads and the built-in sets on the Callouts, Groups, Comms Pad and Share pages; "Preview as…" draws the pads in another situation and "Why is this showing?" explains them. The Comms Dial is phase 4." In the Widgets row's Gives cell, add "and the reorder lists on the editor pages (`ReorderList`)"; change "of the Widgets major only `DragHandle` is used" to "of the Widgets major `DragHandle` and `ReorderList` are used". Add to "On screen": "the editor pages".
- **Module Map:** add rows `Editors` (settings, the pages' shared frame: selection, repaint, reorder lists, delete), `Callouts`, `Groups`, `GroupsWhen`, `Pads`, `Share` (settings pages), and note `Preview` now holds "Preview as…".
- **Settings Schema:** after the first paragraph add: "**Member rows** (`settings/SchemaMembers.lua`): every field a player sets on a member is a row whose path starts with the member's kind (`callout.*`, `group.*`, `pad.*`, `builtin.*`). The seam's `resolveRoot` hands it to `Library.Member(kind, id)`; the id is the instance argument, or the member that kind's editor page has selected (`NS.State.editing`). Each row's `onChange` is `Library.Touch`. With nothing selected, the seam addresses the first member the page lists (`Settings.EditingId`). Member rows are no AceDB default: each resolves against `Library.TEMPLATES` at the boot check, and the profile reset's count leaves them out. Three structured rows (`pad.point`, `group.when`, `builtin.hidden`) hold tables: their pages draw their own controls, and `settings/Slash.lua`'s descriptor `parse` and `format` hooks type and print them on the CLI." Replace the registry paragraph's "The structural registry has one writer, `modules/Library.lua` (spec §4.3, §5): …" with "The structural registry has one writer, `modules/Library.lua`: membership (create, delete, duplicate, Customize) of `profile.callouts`, `groups`, `pads`, `dials` and the built-in overlay, the order lists (`padOrder`, `dialOrder`, each group's callouts and each surface's groups), `nextId`, `seeded` and the overlay's `customizedAs`. Panel pages, slash verbs and (phase 5) import call it or the seam; they never write those keys." Delete the "Named non-setting state" paragraph's `pads[id].point` sentence (it is a row now) and keep the sentence about the pad's tab and collapsed state; add "The editors' selection (`NS.State.editing`) and the When editor's open rows (`NS.State.whenOpen`) are session-only."
- **Message Bus:** in the `TEST_MODE_CHANGED` row, the payload reads "on (test mode or Preview as…)" and the consumers add "the editor pages (repaint)"; in `LIBRARY_CHANGED`, `SITUATION_CHANGED` and `PROFILE_CHANGED` add "the editor pages (`settings/Editors.lua`, one deferred repaint)" to the consumers.
- **Slash Commands:** add the feature verbs `preview` and `why`.
- **Taint Notes:** append: "The editor pages touch no frame of a pad: every write reaches a pad through `LIBRARY_CHANGED` → `Surfaces.Request`, so a write made in combat (a CLI `set`, a popup accepted after the pull) waits for combat end behind the stale hint. The panel itself stays locked in combat by the options library."
- **Known Limitations:** replace "There are no editors yet: …" with three bullets: "A member row written from the CLI addresses the member its page has selected, else the first that page lists; the echo does not name which member it was." / "The instance list ships only the season's returning dungeons; a Midnight dungeon or raid is added with the When editor's add-the-instance-you-are-in button or its id until phase 5 confirms the ids." / "The pad's Look has visibility and fade; its fonts, border and colors, and an icon picker, arrive with phase 5's polish."
- **Documentation map:** no new doc.
- **Documented deviations:** stays "None." (the table-valued member rows are CLI rows through the Slash descriptor's hooks, slash-commands-§6).

- [ ] **Step 2: The maps**

- `docs/module-map.md`, **Load order:** insert, where the TOC has them, `defaults/GameIds.lua` (the shipped ids: dungeons, raids, classes, specializations), `settings/SchemaMembers.lua` (the member rows), `settings/Editors.lua`, `settings/Callouts.lua`, `settings/Groups_When.lua`, `settings/Groups.lua`, `settings/Pads.lua`, `settings/Share.lua`, one line each. **Tests:** add `test_members`, `test_editors`, `test_page_callouts`, `test_groups_when`, `test_page_groups`, `test_page_pads`, `test_page_share`, one line each naming what it pins, and a line for `tests/page_helpers.lua` (a helper, not a suite).
- `docs/schema.md`: in the profile table change the `Set by` cell of `callouts`, `groups`, `builtins`, `pads`, `dials` to "`Library` (membership and order); member fields through the seam (member rows)", and the `pads[id].point` row's to "the `pad.point` member row: the drag strip, the X/Y boxes, Reset position"; under the table add "**Member rows** address a member's fields through the seam (`settings/SchemaMembers.lua`): `callout.name|text|channel|icon`, `group.name|icon|enabled|openInto|when`, `pad.name|enabled|groupsAs`, `pad.layout.orientation|columns|growth|style|scale|spacing|width`, `pad.point`, `pad.look.visibility|fade|fadeAlpha`, `builtin.enabled|hidden`. They are not AceDB defaults; `Library.TEMPLATES` is their shape." Under **Session-only** add `previewAs`, `editing` and `whenOpen`.
- `docs/settings-panel.md`: add rows `Callouts`, `Groups`, `Comms Pad`, `Share` to the `Page | Covers` table, then one section per page with its band, its tabs and their rows (copy each page file's header diagram), and replace **Still to come** with "The Comms Dial page (phase 4) and Share's Export and Import tabs (phase 5)."
- `docs/data-flow.md`: add after "Today: test mode":

> ## Today: an editor writes a member
>
> A widget on an editor page (or `/qc set callout.text …`) writes a member row through the seam: `resolveRoot` finds the member (`Library.Member`) by the instance argument or the page's selection, the row validates and stores the field, and its `onChange` calls `Library.Touch`, which sends `LIBRARY_CHANGED`. `Surfaces.Request` rebuilds the pads (in combat: queued, with the stale hint), and `settings/Editors.lua` repaints every editor page once, on the next frame. Creating, deleting, duplicating, reordering and Customize are Library's own operations and end the same way.
>
> ## Today: Preview as…
>
> `Preview.SetPreviewAs(key)` (the General tab's row, `/qc preview`) turns test mode's second flavor on: `TEST_MODE_CHANGED`, then `Surfaces.ApplyAll` builds each pad from the previewed snapshot and marks the plan, so every chip is disarmed and the header reads `Preview: …`. Combat, the stand-down and the settings window closing end it.

- `docs/scope.md`: rename "What exists at the end of phase 2" to "What exists at the end of phase 3" and add: "Phase 3 added the editors: the Callouts, Groups (with the When editor and a Preview tab), Comms Pad and Share (Built-in tab) pages, "Preview as…" on the pads and `/qc preview`, and "Why is this showing?" on the pad header and `/qc why`." Point the closing sentence at the phase 3 plan too.
- `docs/slash-dispatch.md`: add rows

| Verb | Kind | Live while disabled | Handler |
|---|---|---|---|
| `preview [name\|off]` | feature | no (refused while disabled) | `NS.SlashVerbs.Preview`: no name lists the menu with the one on now; a name switches "Preview as…" on; `off` (or `current`) switches it off. Refused in combat with one line, as the panel row is. |
| `why` | feature | no (refused while disabled) | `NS.SlashVerbs.Why`: each built pad, then `Surfaces.WhyLines` (the groups shown, each with the When rows that matched, then the locks) |

and replace the sentence "The design's other verbs (spec §14), `preview` and `why`, are added with the tasks that own them." with "Every verb of spec §14 now exists." Add under the table: "The member rows are CLI rows too: `/qc set callout.text …` writes the callout selected on the Callouts page, else the first callout that page lists; with no callout at all the write is refused with a line naming the page, and `get` and `list` print `(nothing to edit)`. A built-in set's rows (`builtin.*`) address only the set the Groups page has selected. The three table-valued rows have text forms (the descriptor's `parse` and `format`, slash-commands-§6): `pad.point` takes `x y` or `POINT RELATIVEPOINT x y`; `group.when` takes `<condition> <value>[,<value>…]` (the condition alone clears it; `keyLevel` takes `min-max`, either end empty) and prints `content=mythicPlus; keyLevel=10..any`; `builtin.hidden` takes callout ids or `none`."
- `docs/compat-layer.md`: change "Twenty shims" to "Twenty-three shims" and the count's `answers `20`` to `answers `23``; add rows `InstanceName(id)` (`GetRealZoneText`; plain or nil, an empty name is nil; callers `Preview`, `GroupsWhen`), `SpecInfoByID(id)` (`GetSpecializationInfoByID`; name and icon plain or nil; caller `GroupsWhen`), `ClassName(classFile)` (`LOCALIZED_CLASS_NAMES_MALE`; an unsafe key or a secret name is nil; caller `GroupsWhen`).
- `docs/common-tasks.md`: add two recipes:

> ## Add a member field
>
> Add the field to `Library.TEMPLATES[kind]` (its shape and default), and a row to `settings/SchemaMembers.lua` with `instance = "<kind>"`, a `page` and a `group` (the tab), a `validate` that names its reason, (the file's closing loop gives it `onChange = Library.Touch(kind, id, path)`). If Library creates or copies the member, write the field there too (a create writes the member whole). If a write to it changes what a page draws (a label, a dot), add its path to `Editors.STRUCTURAL`. The page's tab draws it through `RenderRows`; a table-valued field gets a structured `type`, a bespoke control that writes the whole value with `NS.SchemaRuntime.Set(path, value, id)`, and a text form in `settings/Slash.lua`'s `PARSE` and `FORMAT`.
>
> ## Add an editor page
>
> A file under `settings/` that calls `Settings.Editors.RegisterPage(pageKey, title, frameSuffix, render, defaults)`, listed in the TOC above `settings\SlashVerbs.lua`. `render(ctx)` draws `PageBanner` (the picker and the create action), then `Settings.Editors.Tabs(ctx, pageKey, tabs)`. Keep the selection with `Ed.Heal`/`Ed.Select`, draw lists with `Ed.ReorderRows`, delete through `Ed.ConfirmDelete`, and write only through Library or the seam. Drive it in a suite through `tests/page_helpers.lua`.

- `docs/testing.md`, **The harness:** add the seven new suites to the sentence listing the addon's suites, and add: "`tests/page_helpers.lua` (not a suite) drives an editor page through the kit's AceGUI recorder: show a page, redraw it, click a tab, find a widget by its label, fire its callback, accept the last popup, and spy on the reorder lists."

- [ ] **Step 3: smoke-tests.md**

In `docs/smoke-tests.md`, add an index row after `PAD-1..7`:
```
| EDIT-1..8 | Editors | The Callouts, Groups, Comms Pad and Share pages, Preview as…, Why is this showing? |
```
add a section after the `## Pad` section (before `## Dial`):
```markdown
## Editors

**EDIT-1. A callout and a group on the pad (the phase 3 exit).** Settings → Callouts → New callout;
name it `Inc`, text `INC {skull}`, channel Smart group. Groups → New group; on its Callouts tab add
`Inc`; on its When tab tick Content, then M+. Enter a key → the pad shows the new group first with
an `Inc` chip; click it → the party sees "INC" with a skull. Leave the key → the group is gone from
the pad. Result:

**EDIT-2. Customize a built-in (the phase 3 exit).** Groups → pick "M+ (generic) (built-in)" → it
says it is read-only and offers Customize; click it → a line says the copy took its place, the page
now edits "M+ (generic) (custom)", and the pad (in a key) shows the copy where the set was. Rename a
callout in the copy → the chip's label changes. Share → Built-in shows the set's button as "Edit the
copy". Result:

**EDIT-3. Preview as….** Out of combat, in the open world: Groups → General → Preview as → Arena →
the pad shows the arena set with PREVIEW on its header and `Preview: Arena`; clicking a chip sends
nothing; its tooltip says so. Close the settings → the preview ends. `/qc preview raid:heroic` →
the raid set; pull something → the preview ends with one line and the live chips return. Result:

**EDIT-4. Why is this showing?.** In a key, hover the pad's header → the tooltip lists "M+
(generic) (built-in): Content" (and any user group, with its rows); with a `/raid` callout on the pad
outside a raid, the last line names the lock. Behavior → Explain why groups show off → no tooltip.
`/qc why` prints the same lines per pad. Result:

**EDIT-5. The Comms Pad page.** Comms Pad → Layout: Orientation Vertical, Chip style Label only,
Scale 1.5 → the pad redraws each time. Type X `200`, Y `-100` → it moves; Reset this pad's position
→ it returns. Look → Visibility Only out of combat → it hides on the pull with no error. Groups:
drag a group to the top → it comes first on the pad. New pad → a second pad appears with every
built-in set; Delete pad (Yes) → it is gone. Result:

**EDIT-6. The Built-in tab.** Share → Built-in: untick "Raid (generic)" → in a raid it is gone from
the pad. Choose callouts on "M+ (generic)" → the Groups page opens on its Callouts tab; untick
"Lust" → the chip is gone in a key. Defaults (top right) → every set and callout is back. Result:

**EDIT-7. An edit during combat.** With a user callout on the pad, in combat type `/qc set
callout.text Incoming now` (the callout selected on the Callouts page, or, if that page was never
opened this session, the first callout it lists) → no error, the header
shows "updates after combat"; after combat the chip sends the new text. Opening the settings in
combat is refused, as before. Result:

**EDIT-8. The selection survives what other pages do.** Select a callout on the Callouts page, then
`/qc profile Other` and back → the Callouts page shows a callout that exists, never an empty or
erroring page. Delete the selected group from the Groups page → the page moves to the next group.
Result:
```
and add `EDIT-1..8` to the **Pending sign-off** table with origin "Phase 3: the editors".


- [ ] **Step 4: test-cases.md and the README**

Run:
```bash
lua tests/run.lua --list > docs/test-cases.md
lua tests/run.lua | tail -3
```
In `README.md`:
- Set the `Tests` badge to the run's passing / total counts (`Tests-<X>%2F<Y>_passing`), matching `docs/test-cases.md`'s Total.
- Replace "The editors and the Comms Dial come in later builds." with "You can now write your own callouts and groups, say when each group shows, arrange your pads and turn the built-in sets on, off or into editable copies. The Comms Dial comes in a later build."
- In Usage, add: "Settings → Callouts makes a callout; Groups puts callouts in a group and, on its When tab, says where it shows; Comms Pad arranges a pad. "Preview as…" on the Groups page (or `/qc preview`) shows the pads as they would look in a key, a raid, an arena or a battleground; hover a pad's header (or `/qc why`) to see why each group is there."

- [ ] **Step 5: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS, including the kit's `test_prose` (US English in every edited doc) and `test_layout_cap`.

- [ ] **Step 6: Commit**

```bash
git add docs/ README.md
git checkout -- docs/ README.md
git commit -m "Docs: phase 3 editors; smoke checks EDIT-1..8; spec rulings"
```

---

### Task 13: In-game smoke test (owner)

The §19 exit criteria for phase 3, run by the owner in the client. An agent never marks a check passed.

**Files:**
- Modify (owner only): `docs/smoke-tests.md` (the `Result:` lines)

**Interfaces:**
- Consumes: the whole phase.
- Produces: the recorded results.

- [ ] **Step 1: Install and load**

Link the repo into `Interface\AddOns\QuickComms` (the `symlinks.txt` pattern), `/reload`, and run INSTALL-1 and PANEL-1 again: no Lua error; the settings sidebar reads General, Callouts, Groups, Comms Pad, Share, Profiles.

- [ ] **Step 2: The exit criteria (spec §19, row 3)**

| Exit criterion | Smoke checks |
|---|---|
| Create a callout and a group, set When, see it on the pad in the right situation | EDIT-1 |
| Customize a built-in | EDIT-2 |

Then run EDIT-3 to EDIT-8, and PAD-2 and PAD-7 again (the rebuild path the editors now use), recording each `Result:` line with the date, the client build and pass or fail.

- [ ] **Step 3: Capture what fails**

For any failure: `/qc diagnostics`, copy the `library`, `surfaces` and `send` sections, and file an issue with the check's ID. A Lua error names the file and line; attach it as text.

- [ ] **Step 4: Commit the results (owner)**

```bash
git add docs/smoke-tests.md && git checkout -- docs/smoke-tests.md
git commit -m "Smoke: phase 3 results"
```

---

## Self-review

**1. Spec coverage (phase 3):**

| Spec section | Task |
|---|---|
| §19 row 3: Callouts page | 7 |
| §19 row 3: Groups page with the When editor and Preview | 8, 9 |
| §19 row 3: Pads page (layout, look, order, groups-as; X/Y, spec §10.4) | 3a (rows), 10 |
| §19 row 3: Preview as… (§13.3) | 4a (engine, ends), 4b (dungeons, row, verb), 9 and 10 (the General tab row) |
| §19 row 3: Why tooltips (§13.3) and `why` (§14) | 5 |
| §19 row 3: Built-in tab (enable, hide, Customize; §12.2) | 3a (overlay rows), 9 (hide editor, Customize, Defaults), 11 |
| §5 data model: ids, references, When; built-ins read-only | 2, 3a, 3b |
| §7 Resolver: `Explain` in the tooltip, active-now lines | 5, 8, 9 |
| §8.1 tokens: the picker, `{groupN}` only for a channel that can resolve to Raid | 7 |
| §8.4 lock matrix: the padlock text in the live line and the why tooltip | 5, 7 |
| §10 pad: preview flavor on the header and chips | 4a |
| §13.1 panel rules: refused in combat (library), setters queue through SendEngine | Global Constraints; 3b ([review 1]) |
| §14 `preview`, `why`; `get`/`set`/`list` reach every member row (architecture-§5) | 3b, 4b, 5 |
| §16 diagnostics: the preview | 4b |
| §18 edge cases: callout deleted while on a surface; profile switch; edit in combat | 3a, 3b, 6, 7 |
| §20 docs | 12 |
| The parked phase-2 minor (`dragHeld`) | 1 |

**Not in this plan, on purpose:** the Comms Dial page, its Preview tab and its rows (phase 4); Share's Export and Import (phase 5); the Look tab's font group, border group and colors and a visual icon picker (rulings 9 and 15, added to §19 row 5 by Task 12); confirming the Midnight instance ids (phase 5).

**2. Placeholders:** none. Each code step carries the full code; each test step the full test.

**3. Type consistency:**
- Member kinds are `callout`, `group`, `pad`, `builtin` in `Settings.INSTANCE_KINDS`, `Lib.Member`, `Lib.TEMPLATES`, the rows' `instance` field and `NS.State.editing` (Tasks 2, 3a, 6–11); `Lib.MemberIds(kind)` covers `callout`, `group`, `pad` and is the order of `Settings.EditingId`'s fallback and of every picker (`C.Entries`, `G.Entries`, `PD.Entries`).
- `Lib.Touch(kind, id, field)` is every member row's `onChange` (Task 3a's closing loop, `field` the row's path) and sends `LIBRARY_CHANGED (kind, id, field)` (Task 2); Library's own operations send no field, and `Lib.Batch` (Task 11) sends `(kind)` alone. `Ed.STRUCTURAL` (Task 6) is keyed by those paths.
- `Preview.SetPreviewAs(key)` takes `nil | "" | "off" | "current" | <preset key>` in Tasks 4a, 4b, 9, 10 and the row's set closure; `Preview.PreviewAs()` answers a key or nil; `PreviewSnapshot()` a snapshot or nil (Tasks 4a, 6, 7, 8).
- A plan carries `preview` (a key) and `active` (`{ [gid] = { matched } }`) in Tasks 4a and 5; a slot carries `preview = true` in Task 4a (Surfaces, Pad, Pad_Render).
- `Ed.ReorderRows(ctx, pageKey, entries, onMove)` with entries `{ id, label, remove }` in Tasks 6, 9 and 10; `Ed.ActionDropdown(label, tooltip, entries, onPick[, ctx])` with entries `{ id, label }` (or a function returning them) in Tasks 6, 7, 9 and 10; `Ed.Live(ctx, fn)` in Tasks 7, 8 and 9.
- `W.ActiveLine(group, snap, previewLabel)` and `W.ActiveText(gid)` (Task 8) feed the When tab and the Groups Preview tab (Task 9); `Settings.Callouts.PreviewLines(callout)` (Task 7) feeds the Groups Preview tab; `Settings.Groups.Customize`, `CustomizedAs`, `PAGE` (Task 9) feed Share (Task 11); `Settings.GroupsWhen.Render` (Task 8) feeds Groups (Task 9).
- The structured row types `point`, `when`, `idset` are the same in `VALID_TYPES` (Task 3a), the Slash `PARSE` / `FORMAT` tables (Task 3b) and `Ed.Scalar`'s `STRUCTURED` (Task 6).

**4. Review Focus:** each line carries a `[review n]` test: 1 in Task 3b; 2 in Tasks 6 (Heal) and 7 (the healed page and the next write), with Task 3a's stale-selection case; 3 in Task 4a (four cases, the self-fallback one included); 4 in Tasks 3a, 3b, 9 and 11; 5 in Tasks 3a, 7 and 8.

**5. Gate hazards checked:** the kit's prose gate (US "canceled" in Task 1's test name and comment and in `settings/Editors.lua`); `tests/test_setup.lua`'s degraded case (Task 3a rewrites it: member rows only, the `state.previewAs` row sitting after `settings/SchemaRows.lua`'s early return); `tests/test_situation.lua`'s "stand-down cancels a pending coalesced refresh" (Editors schedules nothing until a page body is built, Task 6); lizard's CCN 15 line (`Lib.ValidWhen` split, Task 2).

**Open questions ruled (the brief said decide and report):**
1. **Member fields through the seam, not through Library** (architecture-§5 over spec §4.3 and the brief's "editors write ONLY through modules/Library.lua"). Library keeps membership, order, ids, references and seeding, resolves members for the seam and announces every member write; its old field writers keep their names and go through the seam. Recorded in the spec (Task 12 Step 0).
2. **No nav rails** on the Groups and Comms Pad pages: the banner is the one picker (options-ui-§14).
3. **The Callouts page's first tab is `General`**, holding the acts (options-ui-§14), not "Message".
4. **"Preview as…" is a session row** on the General tab of the Groups and Comms Pad pages, plus `/qc preview`, not a second band control (options-ui-§14 keeps the band to one row).
5. **"Preview as…" is test mode's second flavor:** one switch at a time with the placeholders; `TEST_MODE_CHANGED (on)` covers both; previewed chips are disarmed and carry no self-line or lock text, so they send, print and report nothing.
6. **A new group goes to the top of every pad and dial** (`Library.OfferGroup`), so a player's group shows as soon as its When matches (the exit check needs it on the pad).
7. **The hidden-callouts editor lives on the Groups page** (a built-in's Callouts tab); Share's Built-in tab has Enabled, Customize and a jump to it, so there is one editor.
8. **The Share page ships in phase 3 with its Built-in tab only**; Export and Import join, ahead of it, in phase 5.
9. **The pad's Look tab is visibility, fade and faded alpha**; the font group, border group and colors with class-color companions (spec §13.1, options-ui-§16/§17) move to phase 5's polish, which Task 12 adds to §19 row 5 so the deferral has a home.
10. **Instance ids:** `defaults/GameIds.lua` ships only ids confirmed when the plan was written (the season's returning dungeons); the Midnight dungeon and raid ids are confirmed in game in phase 5, like the battleground ids. The When editor adds the current instance or a typed id meanwhile.
11. **Editing in combat:** the options library locks the panel (no page guard); a CLI write or an accepted popup lands in the data, and the pads take it at combat end behind the stale hint.
12. **Every editor page has a Defaults button** whose blast radius is what the page draws for the selected member (options-ui-§13): a user group's rows; for a built-in set, Preview as and its Enabled row (Task 9); Share's turns every built-in set back on, as one bulk act with one rebuild.
13. **The pad's X/Y are bespoke boxes writing the whole `pad.point` row**, the row the drag writes; the dial keeps Library's direct point write until its page (phase 4).
14. **`Resolver.Explain` keeps phase 1's format** (the matched rows' labels, not their values); Task 12 records this in spec §7 as a Built note.
15. **The icon is a text box** (a texture id or a texture path; a LibKa0s icon by its path), not spec §13.1's picker; a visual icon picker joins phase 5's polish (§19 row 5). There is no `ka0s:` icon-name form in the addon today, so none is documented.
16. **The live byte counter follows each committed write** (Enter in the Text box), not each keystroke: the seam writes on Enter (the library's EditBox), and the line refreshes in place then (`Ed.Live`).
17. **The token picker** offers the eight markers by name, not `{rt1}`…`{rt8}` too (the same eight; a typed `{rtN}` works), and leaves `{spell:ID}` to typing (it needs an id); `{group1}`…`{group8}` appear only for a channel that can resolve to Raid (spec §8.1). Recorded in spec §8.1 by Task 12.
18. **With nothing selected, a member row addresses the first member its page lists** (`Settings.EditingId`), so `/qc set pad.layout.scale 1.5` works before the Comms Pad page was ever opened; a built-in set's overlay rows have no fallback (only the set the Groups page shows). With no member at all, `set` is refused naming the page and `get`/`list` print "(nothing to edit)".
19. **"Preview as…"'s dungeon entries read `M+ · <dungeon> · <spec>`** as spec §13.3 lists them (`M+ · <dungeon>` when the spec is unknown), after a generic `M+ · <spec>`.
20. **No deviation:** the table-valued member rows are CLI rows through the Slash descriptor's `parse` and `format` hooks (slash-commands-§6), not `cli = false` rows.
