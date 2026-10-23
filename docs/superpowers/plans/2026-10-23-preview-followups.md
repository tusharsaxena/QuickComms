# Preview Follow-ups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The owner's 2026-10-23 preview follow-ups: the preview window and start line over the edit
preview (D1), a preview dial that stays open on a slice click (D2), a `{coordinates}` token (D3), and
the prebuilts replaced with the owner's edits, Solo on General (/1) and coordinates in the Solo lines
(D4), with no migration.

**Spec:** `docs/superpowers/specs/2026-10-23-preview-followups-design.md` (read it beside this plan; section
numbers below are the spec's).

**Tech Stack:** Lua 5.1 (WoW), Ace3, LibKa0s v1.76.0, headless harness `tests/run.lua` with
`tests/wow_mock.lua`, luacheck.

## Status ledger (resume here)

Git is the state: an item is done when a commit whose subject starts `QF-NN: ` exists on
`feat/2026-10-23-qc-preview-followups`. To resume, `git log --oneline master..` and tick what is
committed; on a dirty tree, read the diff and continue it (never `reset --hard` or `checkout .`).

- [x] QF-00 Spec and plan (and its plan review, see the end of this file)
- [ ] QF-01 D2: a preview or test dial stays open on a slice click
- [ ] QF-02 D1: the preview window and start line over the edit preview
- [ ] QF-03 D3: the `{coordinates}` token
- [ ] QF-04 D4b: the `general` channel kind (/1, Say when not joined)
- [ ] QF-05 D4: the prebuilts replaced (owner edits, Solo on General, coordinates)
- [ ] QF-06 Docs sweep, smoke checks, test-cases.md and badge, final gate
- [ ] QF-07 Owner follow-up (2026-10-24): the window locked over the edit preview, its dropdown on the group's situation

Order: QF-01 and QF-02 are independent; QF-05 needs QF-03 (the token) and QF-04 (the kind).

## Global Constraints

- Green gate before every commit: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
  (0 failed) and `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0 warnings / 0 errors).
  Never run either unbounded. 1500-line cap per file: `tests/test_page_groups.lua` is at 1499 (never
  grow it), `modules/Library.lua` at 1401 (add nothing there), `locales/enUS.lua` at 1372.
- Files are CRLF on disk (`.gitattributes`); after any tool that writes LF, restore CRLF
  (`sed -i 's/\r\?$/\r/' <file>`). Re-run the tests AFTER committing, so the eol test sees the
  checked-in bytes.
- Never edit `libs/` or `tests/_kit/`. Extend `tests/wow_mock.lua` for a new client API.
- Only `modules/SendEngine.lua` creates `Secure*` frames or calls `SetAttribute`, `SetFrameRef`,
  `WrapScript` (`tests/test_sendengine.lua` firewall grep). Snippets never write an attribute
  (`tests/test_dial_secure.lua` firewall case). Nothing new runs in combat that writes.
- Every user-visible string through `L[...]` with an entry in `locales/enUS.lua`.
- Every new test carries a `-- red under: <the change that breaks it>` line.
- No version bump, no schema step (`NS.MIGRATIONS` stays at 9), no merge, no push (the lead pushes).
  Commit subjects start `QF-NN: `; messages end with the session trailers.
- In-client smoke checks go in `docs/smoke-tests.md` as `Result: pending`; never mark one passed.
- A deviation from the Ka0s standard: stop and report it (CLAUDE.md).
- Every item that moves the test count regenerates `docs/test-cases.md` (`lua tests/run.lua --list`)
  and the README `Tests` badge in the same commit (docs/testing.md, testing-§5).

## Review Focus

1. The live dial still closes on a pick, in and out of combat (QF-01): the only secure snippet change.
2. The `PreClick` re-bake (QF-03) never writes in combat (mock `blocked` stays empty) and touches only
   buttons whose meta carries `rebake`.
3. The prebuilt diff in QF-05 matches the spec's table 2.4 (d) exactly, and no migration was added.

---

## QF-01: D2 — a preview or test dial stays open on a slice click

**Files:** `modules/Dial_Secure.lua` (`WEDGE_POST`, `DS.Load`), `modules/Dial.lua` (the `DS.Load` call,
`:291`), `tests/test_dial_secure.lua`, `tests/test_preview.lua`.

**Failing tests first:**
- `test_dial_secure`: `DS.Load(header, rings, { preview = true })`, open, click a callout wedge -> the
  header is still shown and nothing is sent; with no `preview` (or `false`) -> closed, as today; the
  live close with `m.inCombat = true`; in a preview a ring wedge still opens its ring, the hub still goes
  up, a right click still goes back, a middle click still closes. (red under: `WEDGE_POST` closing
  unconditionally.)
- `test_preview`: Preview as Mythic+, open the dial, catcher click on a callout slice -> echo printed,
  dial shown; test mode the same; after `/qc preview off` a pick on the live dial closes it.

**Behavior:** `DS.Load` adds `["qc-preview"] = opts.preview == true` to the header's attribute batch;
`Dial.Apply` passes `preview = plan.test == true`; `WEDGE_POST` reads it
(`if not owner:GetAttribute("qc-preview") then owner:RunAttribute("qc-close") end`). Header comments
of both files say why (spec 2.2).

**Docs ripple:** `docs/ARCHITECTURE.md` (dial / taint notes: the new header attribute),
`docs/module-map.md` (Dial_Secure line), `docs/data-flow.md` (the click path in a preview);
`docs/smoke-tests.md` PREVIEW-12 (pending) and its Pending sign-off line; `docs/test-cases.md` and the
README badge.

**Verify:** both gate commands green; `grep -n "qc-preview" modules/*.lua` shows only `Dial_Secure.lua`.

## QF-02: D1 — the preview window and start line over the edit preview

**Files:** `modules/PreviewWindow.lua` (`PW.Sync`, `fill`, the title, `endPreview` -> `P.EndPreview`,
`onHide` -> `P.DismissEditPreview`, header), `modules/Preview.lua` (`P.EndPreview`,
`P.DismissEditPreview`, `State.editPreviewDismissed`, `P.SetEditPreview(gid, quiet)` start line, the
`announce()` comment), `settings/Groups.lua` (`G.SyncEditPreview(quiet)` honours and clears the
dismissal; `onShow` clears it; the checkbox write clears it; `onRestrictionChanged` passes `quiet`),
`settings/SlashVerbs.lua` (`V.PreviewLines`: `off` calls `P.EndPreview()` when either flavor is on),
`locales/enUS.lua` (`"%s - Preview: %s"`, `"Previewing: %s (editing)"`, any changed tooltip),
`tests/test_preview_window.lua`, `tests/test_edit_preview.lua`. (`tests/test_page_groups.lua` is at
1499: none of these cases go there.)

**Failing tests first:**
- `test_preview_window`: the edit preview alone shows the window, titled with the group's name, Current
  selected; picking Arena keeps the edit preview and sets Preview as; End preview ends both and writes
  `behavior.previewOnEdit = false`; the close mark the same; Escape (a `Hide()`) ends both and leaves
  the setting on, **and after the scheduled `Ed.RequestRefresh` runs (flush the mock's 0 s timer so the
  page re-renders and calls `G.SyncEditPreview`) the edit preview is still off and the window hidden**
  (red under: Escape without the dismissal mark); then a group switch starts the new group's preview;
  hiding and re-showing the page starts it again; a combat end while dismissed leaves it off; the
  settings window closing with only the edit preview hides the window; a hidden UIParent ends nothing;
  `/qc preview off` with only the edit preview on ends it, writes the setting off, hides the window and
  prints `Preview off.` (red under: `PreviewLines` keyed on `PreviewAs()` alone); with nothing on it
  prints `Preview off.` and writes nothing. (red under: `Sync` keyed on `PreviewAs()` alone.)
- `test_edit_preview`: the start line prints once on the page-show edge and once when the setting is
  ticked on, not on a group switch, not on a re-render, not on a refusal (combat / stood down); with the
  page shown, entering combat prints `Preview ended: you entered combat.` and leaving combat restarts
  the edit preview (window shown) with **no** `Previewing:` line (red under: `onRestrictionChanged`
  not passing `quiet`); a dial wedge under the edit preview, clicked through its ring's catcher with
  the Groups page shown, prints its echo (spec 1.2: if this is red, find and fix the cause in this
  item, bisecting before theorizing, and record it in the commit message).

**Behavior:** spec 2.1. End preview / close mark / `/qc preview off`: `P.EndPreview()` —
`SchemaRuntime.Set("behavior.previewOnEdit", false)` and `SetEditPreview(nil)` when the edit preview
is on, clear the dismissal, then `SetPreviewAs(OFF)`. Escape / Hide: `P.DismissEditPreview()` — mark
the group dismissed for the session, `SetEditPreview(nil)`, `SetPreviewAs(OFF)`, the setting untouched;
`G.SyncEditPreview` previews nothing while the selected group is the dismissed one. The start line on
a user-started edge only (spec 2.1's table). The End preview tooltip's `/qc preview off` stays.

**Docs ripple:** `docs/ARCHITECTURE.md` and `docs/module-map.md` ("shown exactly while Preview as is on"
-> also while the edit preview is on), `docs/settings-panel.md` (Preview while editing), README's
preview paragraph (`README.md:77` area), `docs/smoke-tests.md` PREVIEW-11 (pending; includes the
`/qc debug` echo check on a pad button and a dial slice while editing) and EDIT checks that say the
edit preview has no window; `docs/test-cases.md`, README badge.

**Verify:** both gate commands green; `grep -n "edit preview get no window\|edit preview gets no window" -r modules docs README.md` is empty.

## QF-03: D3 — the `{coordinates}` token

**Files:** `core/Compat.lua` (`PlayerMapPosition`, `Coordinates`), `modules/Tokens.lua` (`BAKED`,
alias, header), `modules/Surfaces.lua` (`BakeContext`), `modules/Pad.lua` (`arm`: `meta.rebake` for an
armed live slot whose text uses the token), `modules/SendEngine.lua` (the `PreClick` hook,
`SE.RefreshRebakes`, the combat-edge call), `modules/Preview.lua` (`P.MOCK.coordinates`; `SlotEcho` copies the
`BakeContext` ctx and sets `ctx.coordinates = nil`, and `mockBaked("coordinates")` answers the literal
`"{coordinates}"` when `snap == NS.Situation.Current()` (identity; `PreviewSnapshot` returns that table
for Current) and `P.MOCK.coordinates` otherwise; `FillEcho` replaces the literal at the click), `core/PerfSetup.lua` (`coordsRebake`), `settings/Callouts.lua`
(`C.TOKENS`, `TOKEN_HELP`), `settings/SchemaMembers.lua:162` + `locales/enUS.lua` (the Text row
description, the help line, `<coordinates>`), `tests/wow_mock.lua` (`C_Map.GetBestMapForUnit`,
`C_Map.GetPlayerMapPosition` returning an object with `GetXY`, settable per test; `PreClick` run before
`OnClick` on `Click` / `__click`), `tests/test_compat.lua`, `tests/test_tokens.lua`, new
`tests/test_coordinates.lua` (registered in `tests/run.lua`'s suite list).

**Failing tests first:**
- `test_compat`: `Coordinates()` -> `"45.2, 61.8"` for 0.452, 0.618; nil for no map id, nil position,
  0,0, a secret value, no `C_Map`.
- `test_tokens`: `{coordinates}` and `{coords}` expand from `ctx.coordinates`; missing -> dropped and in
  `missing`; with a mock -> the mock.
- `test_coordinates`: a live pad button with `"{target} @ {coordinates}"` bakes the position; move the
  mock player, press -> `PreClick` re-arms and the macrotext holds the new position; an unchanged
  position writes nothing; a button without the token gets no `rebake`; `m.inCombat = true`, press ->
  no write, `m.blocked` empty, the old line sent; the combat edge re-arms each `rebake` button once;
  in a dungeon (no position) the line is `"%t @"`; a Current preview echo and an edit-preview echo,
  each baked at one position and clicked after the mock player moved, print the click-time position
  and their baked `slot.echo` holds the literal `{coordinates}` (red under: `SlotEcho` keeping
  `ctx.coordinates` from `BakeContext`); an M+ preset prints `<coordinates>`. (red under: no
  `PreClick` re-bake.)

**Behavior:** spec 2.3.

**Docs ripple:** `docs/compat-layer.md` (two rows), `docs/ARCHITECTURE.md` (taint notes: the
`PreClick` hook; event wiring: the combat-edge re-arm), `docs/data-flow.md` (bake -> press re-bake),
`docs/module-map.md` (SendEngine, Tokens), `docs/performance.md` (`coordsRebake`), README (the token
in the feature text), `docs/smoke-tests.md` EDIT-18's token list and TOKEN-1 (pending); `docs/test-cases.md`,
README badge.

**Verify:** both gate commands green; `grep -n "SetAttribute" modules/*.lua | grep -v SendEngine` is
empty (firewall).

## QF-04: D4b — the `general` channel kind

**Files:** `modules/Channels.lua` (`KINDS`, `PREFIX`, `CHAT_TYPE`, `Resolve`, `LOCKS`, new
`Ch.ColorType`), `core/Compat.lua` (`GeneralJoined`), `core/Constants.lua` (`CHAT_COLORS.CHANNEL1`),
`modules/Situation.lua` (`ReadInputs`, `Classify`, `SIGNATURE_FIELDS`, `EVENTS` + `CHANNEL_UI_UPDATE`
and `CHAT_MSG_CHANNEL_NOTICE`), `modules/Preview.lua` (`base()` copies `general`),
`modules/SendEngine_Guard.lua` (`CHAT_MSG_CHANNEL`, pure `G.IsGeneralEcho(index)`, the "Never a guild or
custom channel (§8.4)" comment reworded), `modules/SendEngine.lua` (`OnSendEcho`: for
`CHAT_MSG_CHANNEL`, after the existing nothing-pending return, read `select(8, ...)` and drop a
readable index other than 1 before `G.Match`), `modules/Pad_Render.lua` (`CHANNEL_NAME.general`;
`channelLine` asks `Ch.ColorType`), `settings/Groups.lua` (`SHORT_CHANNEL.general`; the row's color
through `Ch.ColorType`), `settings/SchemaMembers.lua` (`CHANNEL_LABEL.general`), `locales/enUS.lua`
(`General`, the label), `docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md` (only an italic
"Superseded in part 2026-10-23" line under the §8.4 lock matrix; the row itself is not edited),
`tests/wow_mock.lua` (`GetChannelName`; `ChatTypeInfo.CHANNEL1` if the mock has a `ChatTypeInfo`),
`tests/test_channels.lua`, `tests/test_situation.lua`, `tests/test_send_guard.lua` (its
`#ECHO_EVENTS == 9` becomes 10), `tests/test_sendengine.lua` (the edge's index filter),
`tests/test_pad_render.lua` (the `Channel: General` line).

**Failing tests first:**
- `test_channels`: `Resolve("general", { general = true })` -> `"general"`; without -> `"say"`;
  `Prefix("general") == "/1"`, `ChatType("general") == "CHANNEL"`; locked as Say in an encounter or a
  PvP match; `IsKind("general")`. (red under: no `general` kind.)
- `test_situation`: the snapshot reads `general` from `GetChannelName(1)`; a join or leave changes the
  signature; `CHANNEL_UI_UPDATE` and `CHAT_MSG_CHANNEL_NOTICE` are registered; a notice after a join
  (mock `GetChannelName(1)` turned non-zero) refreshes the snapshot to `general = true` (red under: no
  notice event, with no `CHANNEL_UI_UPDATE` fired).
- `test_send_guard` / `test_sendengine`: `G.IsGeneralEcho(1) == true`, `(2) == false`, unreadable ->
  nil; a `CHAT_MSG_CHANNEL` from the player with index 1 matches a pending `CHANNEL` send; from the
  player with index 2 it does not (the press stays pending; red under: matching by type and sender
  alone); from another player with index 1 it does not; `#ECHO_EVENTS == 10`.
- `Pad_Render.TooltipLines` of a `general` slot carries `Channel: General` in the `CHANNEL1` color;
  (`test_pad_render.lua`); the Groups row's short label for a `general` callout is `General`
  (`SHORT_CHANNEL` is a local of `settings/Groups.lua`: asserted by rendering the Callouts tab from a
  test file other than `test_page_groups.lua`, e.g. `test_edit_preview.lua`, which already shows the
  page; if no such file can reach it cheaply, it is a SEND-6 smoke step instead, said in the commit).
- A callout on `general` bakes `/1 text` with channel 1 joined and `/s text` without; the channel row
  offers it with its label; Share import accepts it.

**Behavior:** spec 2.4 (b), General. No new send path: the secure macro button sends `/1 text` on the
hardware click.

**Docs ripple:** `docs/schema.md` (callout channel values), `docs/ARCHITECTURE.md` (channels, event
wiring), `docs/data-flow.md` (snapshot fields), `docs/compat-layer.md` (`GeneralJoined`),
`docs/module-map.md`, `docs/performance.md` (`OnSendEcho` now hears every channel line; idle cost is
the existing nothing-pending return), README (the channel list, `README.md:100`), `docs/smoke-tests.md`
SEND-6 (pending; checks Solo bakes `/1` right after login and right after a zone change, a `/2` line
inside the guard window is not taken as the echo, and the tooltip names General); `docs/test-cases.md`,
README badge.

**Verify:** both gate commands green.

## QF-05: D4 — the prebuilts replaced

**Files:** `defaults/BuiltIns.lua` (`BI.COLOR.yellow`, `BI.COLOR.sky`), `defaults/BuiltIns_MythicPlus.lua`
(chain -> `C.yellow`), `defaults/BuiltIns_Group.lua` (hello -> `C.sky`, new `stone` 2nd),
`defaults/BuiltIns_World.lua` (`"general"`, the four texts, header comment), `locales/enUS.lua` (new
`At Stone`, `At stone, WM off.` and the four Solo texts; the replaced Solo strings removed),
`tests/test_builtins.lua`.

**Failing tests first (`test_builtins`):**
- Solo: every callout's channel is `general`; `thanks` bakes `/1 Thanks for the help!` with the audit
  snapshot (`general = true`) and `/s ...` without; the four texts exactly as spec 2.4 (d). The old
  "say or yell" case is rewritten. (red under: Solo still on say.)
- In Group rows: `Hello=Hello!|At Stone=At stone, WM off.|Summon=...` (At Stone 2nd), `bi.group.stone` on
  `smartGroup`, glyph `gi:tombstone-sbed`, color `b07cff`; `bi.group.hello.iconColor == "3fc7eb"`.
- `bi.mplus.chain.iconColor == "fff468"`.
- `#NS.MIGRATIONS` (or its last `to`) is still 9: no step added.
- The existing "no raw %t" case stays green (the owner's stale `%t` texts are not adopted, spec 1.6).

**Behavior:** spec 2.4 (a), (b), (d). No migration, no `schemaVersion` bump (2.4 (c)).

**Docs ripple:** `docs/scope.md` / README if they list the shipped sets' callouts or Solo's channel,
`docs/schema.md` if it names the shipped colors, `docs/smoke-tests.md` STATE-6 (pending: a new profile's
prebuilts match the table); `docs/test-cases.md`, README badge. The commit message lists the adopted
owner edits and the 14 stale `%t` texts left out, so the owner can see both.

**Verify:** both gate commands green; `git grep -n "MIGRATIONS" core/Database.lua` shows no `to = 10`.

## QF-06: Docs sweep, smoke checks, test-cases.md and badge, final gate

**Files:** `docs/ARCHITECTURE.md`, `docs/module-map.md`, `docs/data-flow.md`, `docs/compat-layer.md`,
`docs/settings-panel.md`, `docs/smoke-tests.md`, `docs/test-cases.md`, `README.md`.

**Behavior:** read every doc each item touched against the code as it now stands (counts, file:line
citations, the token and channel lists); the five new checks PREVIEW-11, PREVIEW-12, TOKEN-1, SEND-6,
STATE-6 all `Result: pending` and listed under `## Pending sign-off` with their origin (QF-0n,
2026-10-23); regenerate `docs/test-cases.md` and the README `Tests` badge from
`lua tests/run.lua --list`. No new tests unless a doc check finds a gap.

**Verify:** both gate commands green, re-run after the commit (eol); `git log --oneline master..`
shows QF-00..QF-06; `git status` clean. Report to the lead: test totals, the commit list, the smoke
checks owed, and the two owner-facing notes (the 14 stale `%t` texts not adopted; existing profiles
keep their callouts, so the owner re-edits Solo's channel and texts or uses Restore).

---

## Plan review (2026-10-23)

A critique of the committed spec and plan (`50915f0`) raised seven points. Each was checked against the
code; all seven hold, and the spec and this plan are amended in `QF-00: address plan review`.

| # | Point | Verified against | Verdict | Amendment |
| --- | --- | --- | --- | --- |
| 1 | Escape ends the edit preview but it bounces back: `SetEditPreview(nil)` -> `announce()` -> `TEST_MODE_CHANGED` -> `Ed.RequestRefresh` (0 s timer) -> render -> `G.SyncEditPreview` restarts it; it also restarts on `onShow` and every combat end. | `modules/Preview.lua:32-38`, `settings/Editors.lua:103-112,160`, `settings/Groups.lua:539-553,715-730,761` | **Accepted.** The spec's "restarts only on a redraw (a group switch)" was wrong. | Option (b): a session dismissal mark (`State.editPreviewDismissed`, `P.DismissEditPreview`) honoured by `G.SyncEditPreview`, cleared by a group switch, a page show, a setting write or End preview (spec 1.1, 2.1). Option (a) rejected: Escape also closes the settings window, so it would silently flip a saved switch. Option (c) rejected: it leaves the edit preview's pads up with no window to end them. QF-02's Escape test now asserts the preview stays off after the scheduled refresh runs, and after a combat end. |
| 2 | The start line would print after every combat end (Groups' restart follows Preview's "Preview ended" line) and on every Escape bounce. | `modules/Preview.lua:349`, `settings/Groups.lua:551-553` | **Accepted.** | `P.SetEditPreview(gid, quiet)`; `onRestrictionChanged` passes `quiet`. Spec 2.1 has the per-path table; the bounce is gone with point 1. Headless combat case added to QF-02. |
| 3 | `/qc preview off` only ends Preview as; with only the edit preview on it prints "Preview off." and nothing ends, while the End tooltip advertises it as the typed equivalent. | `settings/SlashVerbs.lua:126-131`, `modules/PreviewWindow.lua:97` | **Accepted.** | `/qc preview off` calls the shared `P.EndPreview()` (same as End and the close mark, setting off), so the tooltip stays true. Tests for both the edit-preview-only and the nothing-on cases. |
| 4 | The coordinates echo contradicts itself: `SlotEcho` bakes with `BakeContext(snap)`, which carries `coordinates` for the live snapshot, so the mock is never asked and the plan-time position prints. | `modules/Preview.lua:198,294-295`, `modules/Surfaces.lua:410-411` | **Accepted.** | `SlotEcho` copies the ctx and clears `coordinates`; the live snapshot is `snap == NS.Situation.Current()` (identity); the literal survives to `FillEcho`. Click-time test (moved mock player) added to QF-03. |
| 5 | Ripple misses for `general`: `Pad_Render` `CHANNEL_NAME`, Groups `SHORT_CHANNEL`, the Guard's "Never a guild or custom channel (§8.4)" comment and the v1 wording, and the `CHANNEL` color fallback. | `modules/Pad_Render.lua:74-77,115-120`, `settings/Groups.lua:216-219`, `modules/SendEngine_Guard.lua:21`, `core/Constants.lua:21-24`, v1 spec `:433` | **Accepted** (all four). | QF-04 Files list gains each. Color: new `Ch.ColorType` -> `CHANNEL1` for `general`, `CHAT_COLORS.CHANNEL1` fallback. The frozen v1 spec gets only an italic "Superseded in part" line, its existing convention. |
| 6 | `CHAT_MSG_CHANNEL` fires for every channel; type + sender would take the player's own `/2` line as the General echo; the handler now runs on every channel line. | `modules/SendEngine.lua:453-466`, `modules/SendEngine_Guard.lua:23-37` | **Accepted.** | Match on the channel index (payload field 8) too, through a pure `G.IsGeneralEcho`; unreadable index falls to the sender rule. Perf note in spec 2.4 (b) and `docs/performance.md`. Tests in `test_send_guard` / `test_sendengine`; `ECHO_EVENTS` 9 -> 10. |
| 7 | Snapshot freshness: `CHANNEL_UI_UPDATE` alone may miss the automatic joins after login and the zone swap. | `modules/Situation.lua:162-169` | **Accepted** (both remedies). | `CHAT_MSG_CHANNEL_NOTICE` joins `EVENTS` beside `CHANNEL_UI_UPDATE`, and SEND-6 checks Solo bakes `/1` right after login and after a zone change. |

Rejected: none.

## Addendum QF-07 (owner, 2026-10-24)

Smoke of PREVIEW-11 found two faults with Preview while editing on: the dropdown read Current under an
`Alterac Valley` title, and a pick in it did nothing visible. The owner's fix: over the edit preview the
window is disabled (dimmed, the dropdown, End preview and the close mark off, a tooltip naming the Groups
page), and its dropdown follows the group being edited. `Preview.EditPresetKey` maps the group's When
(its parent's when it inherits) to a preset: a battleground set's map, M+, the tier's raid at its first
ticked difficulty or Normal, Arena, Solo, else Current. `Preview.EditSnapshot` is what `Surfaces.ApplyAll`
bakes the edit preview's pads and dials under, so the window names what the pads show; the Groups page
keeps judging where you are (`Editors.Snapshot`), its active dots and rows unchanged.
