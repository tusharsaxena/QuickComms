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

- [x] QF-00 Spec and plan
- [ ] QF-01 D2: a preview or test dial stays open on a slice click
- [ ] QF-02 D1: the preview window and start line over the edit preview
- [ ] QF-03 D3: the `{coordinates}` token
- [ ] QF-04 D4b: the `general` channel kind (/1, Say when not joined)
- [ ] QF-05 D4: the prebuilts replaced (owner edits, Solo on General, coordinates)
- [ ] QF-06 Docs sweep, smoke checks, test-cases.md and badge, final gate

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

**Files:** `modules/PreviewWindow.lua` (`PW.Sync`, `fill`, the title, `endPreview`, `onHide`, header),
`modules/Preview.lua` (`P.SetEditPreview` start line, the `announce()` comment), `locales/enUS.lua`
(`"%s - Preview: %s"`, `"Previewing: %s (editing)"`, any changed tooltip), `tests/test_preview_window.lua`,
`tests/test_edit_preview.lua`.

**Failing tests first:**
- `test_preview_window`: the edit preview alone shows the window, titled with the group's name, Current
  selected; picking Arena keeps the edit preview and sets Preview as; End preview ends both and writes
  `behavior.previewOnEdit = false`; the close mark the same; Escape (a `Hide()`) ends both and leaves
  the setting on; the settings window closing with only the edit preview hides the window; a hidden
  UIParent ends nothing. (red under: `Sync` keyed on `PreviewAs()` alone.)
- `test_edit_preview`: the start line prints once on the off -> on edge, not on a group switch, not on
  a refusal (combat / stood down); a dial wedge under the edit preview, clicked through its ring's
  catcher with the Groups page shown, prints its echo (spec 1.2: if this is red, find and fix the
  cause in this item, bisecting before theorizing, and record it in the commit message).

**Behavior:** spec 2.1. End preview / close mark: `SchemaRuntime.Set("behavior.previewOnEdit", false)`
when the edit preview is on, then `SetPreviewAs(OFF)`. Escape / Hide: `SetEditPreview(nil)` and
`SetPreviewAs(OFF)`, the setting untouched. The start line on the edge only.

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
`SE.RefreshRebakes`, the combat-edge call), `modules/Preview.lua` (`P.MOCK.coordinates`, `SlotEcho`'s
mock for a live snapshot, `FillEcho`), `core/PerfSetup.lua` (`coordsRebake`), `settings/Callouts.lua`
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
  in a dungeon (no position) the line is `"%t @"`; a Current preview echo prints the click-time
  position, an M+ preset prints `<coordinates>`. (red under: no `PreClick` re-bake.)

**Behavior:** spec 2.3.

**Docs ripple:** `docs/compat-layer.md` (two rows), `docs/ARCHITECTURE.md` (taint notes: the
`PreClick` hook; event wiring: the combat-edge re-arm), `docs/data-flow.md` (bake -> press re-bake),
`docs/module-map.md` (SendEngine, Tokens), `docs/performance.md` (`coordsRebake`), README (the token
in the feature text), `docs/smoke-tests.md` EDIT-18's token list and TOKEN-1 (pending); `docs/test-cases.md`,
README badge.

**Verify:** both gate commands green; `grep -n "SetAttribute" modules/*.lua | grep -v SendEngine` is
empty (firewall).

## QF-04: D4b — the `general` channel kind

**Files:** `modules/Channels.lua` (`KINDS`, `PREFIX`, `CHAT_TYPE`, `Resolve`, `LOCKS`), `core/Compat.lua`
(`GeneralJoined`), `modules/Situation.lua` (`ReadInputs`, `Classify`, `SIGNATURE_FIELDS`, `EVENTS` +
`CHANNEL_UI_UPDATE`), `modules/Preview.lua` (`base()` copies `general`), `modules/SendEngine_Guard.lua`
(`CHAT_MSG_CHANNEL`), `settings/SchemaMembers.lua` (`CHANNEL_LABEL.general`), `locales/enUS.lua`,
`tests/wow_mock.lua` (`GetChannelName`), `tests/test_channels.lua`, `tests/test_situation.lua`,
`tests/test_send_guard.lua`.

**Failing tests first:**
- `test_channels`: `Resolve("general", { general = true })` -> `"general"`; without -> `"say"`;
  `Prefix("general") == "/1"`, `ChatType("general") == "CHANNEL"`; locked as Say in an encounter or a
  PvP match; `IsKind("general")`. (red under: no `general` kind.)
- `test_situation`: the snapshot reads `general` from `GetChannelName(1)`; a join or leave changes the
  signature; `CHANNEL_UI_UPDATE` is registered.
- `test_send_guard`: a `CHAT_MSG_CHANNEL` from the player matches a `CHANNEL` send; from another
  player it does not.
- A callout on `general` bakes `/1 text` with channel 1 joined and `/s text` without; the channel row
  offers it with its label; Share import accepts it.

**Behavior:** spec 2.4 (b), General. No new send path: the secure macro button sends `/1 text` on the
hardware click.

**Docs ripple:** `docs/schema.md` (callout channel values), `docs/ARCHITECTURE.md` (channels, event
wiring), `docs/data-flow.md` (snapshot fields), `docs/compat-layer.md` (`GeneralJoined`),
`docs/module-map.md`, README (the channel list, `README.md:100`), `docs/smoke-tests.md` SEND-6
(pending); `docs/test-cases.md`, README badge.

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
