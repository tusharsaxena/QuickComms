# Combined actions, pings, markers, message-and-emote built-ins and auto-thank (#16 to #20): plan

Spec: `docs/superpowers/specs/2026-11-10-combined-actions-design.md` (revision 2, 2026-11-11). Section
numbers below (§1 to §14) are the spec's. Branch `feat/2026-11-10-combined-actions`, this checkout,
branched from master at 37a1e7b. Baseline: 1780 passed, 0 failed, 1 skipped on both kit profiles;
luacheck 0/0 over 172 files.

Milestones follow D8: M0 (locale split), M1 (#17, #18 as single actions), M2 (#16 combining), M3 (#20),
M4 (#19), then M5 (review, PR, handover). One PR, merged only on the owner's go-ahead after the smoke pass.

## Resume

Git is the state. A task is done when a commit whose subject starts with its id exists on the branch.

1. `git -C /mnt/d/Profile/Users/Tushar/Documents/GIT/QuickComms branch --show-current` must print
   `feat/2026-11-10-combined-actions`. If not, `git switch feat/2026-11-10-combined-actions`.
2. List what is done:
   - `git log --oneline master..HEAD | grep ^.......\ CA-`
   - robust form (git may print a longer hash): `git log --format=%s master..HEAD | grep ^CA-`
3. The next task is the first ledger row below whose id is not in that list. Ids run in ledger order; never
   skip one. The ledger's `state` and `commit` cells are updated in the next commit that touches this file
   (the milestone docs task or checkpoint task), so git outranks the ledger when they disagree.
4. **An interrupted task** (the working tree is dirty): read `git status` and `git diff` (and
   `git diff --staged`). Either finish the task and commit it under its id, or, if the change cannot be
   finished now, `git stash push -m "<ID> partial"` and record that in the checkpoint notes. Never
   `git reset --hard`, never `git checkout -- .`, never `git clean`. A stash named `<ID> partial` is popped
   before the task is resumed.
5. The last Checkpoints row says which milestone was last pushed. `git status -sb` shows whether the
   branch is ahead of `origin`.

## Rules for every task

- **TDD.** Write or change the failing test first and see it fail (`lua tests/run.lua` names the suite and
  case). Then implement, then the green gate.
- **The green gate, before every commit:**
  1. `lua tests/run.lua`
  2. `KA0S_KIT_CLIENT=forever lua tests/run.lua`
  3. `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0 warnings / 0 errors)
- **Never edit `libs/` or `tests/_kit/`** (vendored). New client APIs go in `tests/wow_mock.lua`, with its
  header documented.
- **No version bump.** The TOC `## Version`, README version and CHANGELOG version stay as they are.
- **The file cap.** Every authored file stays under 1500 lines (`tests/_kit/test_layout_cap.lua`).
  `modules/Library.lua` is 1358 lines and `locales/enUS.lua` 1474 today; watch both. If a file would cross
  the cap, split it along the layout-§1 shape (a `<File>_<Topic>.lua` sibling, contiguous in the TOC) in
  its own commit under the task's id, and update the census in the same commit.
- **Locale keys.** Every new `L["..."]` goes in exactly one enUS file, placed by its first reader in TOC
  order (§1 M0): `modules/`, `defaults/` and `core/` readers in `locales/enUS.lua`, `settings/`-only
  readers in `locales/enUS_Settings.lua`, `modules/AutoThank*`-only readers in
  `locales/enUS_AutoThank.lua`. `tests/test_locale.lua` enforces it in both directions: CA-M0-3 adds
  "every `enUS_Settings.lua` key is read only under `settings/`" and "every `enUS.lua` key has a reader
  outside `settings/`", and CA-M4-4 adds the `enUS_AutoThank.lua` case. A key that only settings reads
  today, but that a module reads in a later task, sits in `enUS_Settings.lua` until that task moves it.
- **Commit subjects** start with the id: `CA-M1-3: Validate ping and marker fields...`. End the message
  with the session's attribution lines. Stage only the task's files (named paths, never `git add -A`).
- **Test count.** A task that moves the case count regenerates `docs/test-cases.md`
  (`lua tests/run.lua --list`) and the README `[tests]` badge in the same commit (testing-§5).
- **Smoke checks** are added to `docs/smoke-tests.md` under Pending sign-off. An agent never marks one
  passed.

## Owner rulings and builder calls that must not be built silently

The spec flags **no deviation from the Ka0s standard** (§14: F1 dropped, the unit-filter frame sits inside
events-frames-taint-§1's carve-out, F5 expects none). No row is added to `docs/ARCHITECTURE.md`
`## Documented deviations`. If a task finds a standard conflict that the spec did not foresee (for
example F5: the skin gates need toast colors LibKa0s does not expose), it STOPS, commits nothing for it,
and asks the owner whether it is an accepted deviation or an upstream change.

These are addon-scope rulings or builder calls the spec asks the owner to confirm. The run builds the
spec's reading, names each one in the milestone checkpoint report and in the PR body, and changes the
listed task if the owner rules otherwise:

| Id | What | Spec | Built in | Ask by |
|---|---|---|---|---|
| D10 | "No line" stays `channel = "gameEmote"`, relabelled None | §2 | CA-M2-7 | M1 checkpoint |
| D16 | An action-only press emits a synthetic `SEND_RESULT "sent"` | §4 step 8 | CA-M1-9 | M1 checkpoint |
| F4a | Step 20's "unedited" ignores name, icon and icon color | §8 | CA-M3-3 | M2 checkpoint |
| F4b | Arena and battleground sets gain no emotes (pvpMatch padlock) | §8 | CA-M3-1 | M2 checkpoint |
| F4c | In-combat buffs found by an after-combat diff, not an id queue (queued from `AT.OnAura` in combat; the toast's Hold and Release on its own `RESTRICTION_CHANGED` receiver plus the `R.OnCombatEdge(false)` hook) | §9 Combat | CA-M4-7, CA-M4-10 | M3 checkpoint |
| FRB | Forever's `THANK_RAID_BUFFS`: derived through `tools/client_tables.py` if it can; if not, the raid-buffs-only toggle (D3) is hidden or disabled on Forever, since an empty list would toast nothing there | §9 | CA-M4-3, CA-M4-14 | M3 checkpoint |
| F2 | `docs/scope.md` rewritten to allow reading your own helpful auras | §14 | CA-M4-15 | M3 checkpoint, before M4 starts |
| F3 | The auto-thank whisper breaks the addon's #7 no-whisper rule, for auto-thank only | §9, §14 | CA-M4-12 | M3 checkpoint, before M4 starts |
| D24 | No shipped callout carries a ping or a marker | §8 | (nothing built) | PR body |
| R4, R5 | Forever pings (PING-3) and marking in combat (MARK-7) may narrow #17/#18's AC | §14 | (smoke) | smoke handover |

## Status ledger

| id | task | state | commit |
|---|---|---|---|
| CA-M0-1 | Commit the spec and this plan | done | 367c71e |
| CA-M0-2 | `tests/test_locale.lua`: the locale union gates | done | a343b5e |
| CA-M0-3 | Split settings-only strings into `locales/enUS_Settings.lua` | done | 1ac626d |
| CA-M0-4 | M0 docs | done | (this commit) |
| CA-M0-5 | M0 checkpoint | todo | |
| CA-M1-1 | Mock: ping, marker and target surfaces | todo | |
| CA-M1-2 | Compat: ping, marker, target and rights readers | todo | |
| CA-M1-3 | Library: `ValidPing`, `ValidMarker`, `HasAction`, the M1 one-action rule | todo | |
| CA-M1-4 | Library: every callout field list carries `ping` and `marker` | todo | |
| CA-M1-5 | Schema: `callout.ping`, `callout.marker`, the reworded `callout.emote` | todo | |
| CA-M1-6 | BuiltIns: `BI.Callout` `extra`, the integrity row | todo | |
| CA-M1-7 | Bake: `B.BakeActions` with one action per kind | todo | |
| CA-M1-8 | Surfaces and Pad: the slot's action lists and the arm gate | todo | |
| CA-M1-9 | Send path: press order, the action gate, one tick, D16 | todo | |
| CA-M1-10 | Send path: press-time reasons read in PreClick | todo | |
| CA-M1-11 | Popup: the draft carries `emote`, `ping` and `marker` | todo | |
| CA-M1-12 | Preview, tooltip and `/qc check` for a ping-only or marker-only callout | todo | |
| CA-M1-13 | M1 docs and smoke checks | todo | |
| CA-M1-14 | M1 checkpoint | todo | |
| CA-M2-1 | Lift the one-action rule | todo | |
| CA-M2-2 | Bake: the multi-line macro, `MAX_MACRO`, the Line budget, partial bakes | todo | |
| CA-M2-3 | Surfaces: the `{coordinates}` re-bake refreshes the press meta | todo | |
| CA-M2-4 | Echo grouping: one result per press, per-action lock notes | todo | |
| CA-M2-5 | Diagnostics: `SE.Escaped` shows each newline | todo | |
| CA-M2-6 | Preview: one echo row per action | todo | |
| CA-M2-7 | Editor: the four-slot layout, None, Save | todo | |
| CA-M2-8 | Editor: `check(d)` split, byte counts, `noAction` | todo | |
| CA-M2-9 | Settings readers: `C.PreviewLines`, Groups labels and tooltip | todo | |
| CA-M2-10 | Module and slash readers: `Pad_Render.TooltipLines`, `V.CheckLines` | todo | |
| CA-M2-11 | Retire `slot.chatType` | todo | |
| CA-M2-12 | M2 docs and smoke checks | todo | |
| CA-M2-13 | M2 checkpoint | todo | |
| CA-M3-1 | BuiltIns: 12 shipped callouts gain an emote | todo | |
| CA-M3-2 | BuiltIns: the two `healme` rows | todo | |
| CA-M3-3 | Step 20 part 1: emotes on unedited shipped callouts | todo | |
| CA-M3-4 | Step 20 part 2: the two new rows | todo | |
| CA-M3-5 | Register step 20; schema version 20 and its pins | todo | |
| CA-M3-6 | M3 docs and smoke checks | todo | |
| CA-M3-7 | M3 checkpoint | todo | |
| CA-M4-1 | Mock: aura, GUID, friend and guild surfaces | todo | |
| CA-M4-2 | Compat: `AuraCaster`, `AuraByInstance`, `HelpfulAuraIds`, `WhisperName` | todo | |
| CA-M4-3 | Constants, `thank` defaults, raid-buff ids, `enUS_AutoThank.lua` | todo | |
| CA-M4-4 | `AT.Accept`, `AT.Fill`, `AT.Macro` (pure) | todo | |
| CA-M4-5 | The unit-filter frame, `AT.Rewire`, stand-down and stand-up | todo | |
| CA-M4-6 | `AT.OnAura`: detection and the known-aura set | todo | |
| CA-M4-7 | Combat: the after-combat diff | todo | |
| CA-M4-8 | `core/ToastSetup.lua`: the Toast seam and stub | todo | |
| CA-M4-9 | `AutoThank_Toast.lua`: host, builder, GAP pump, stack, `maxQueue`, stand-down | todo | |
| CA-M4-10 | The toast's combat Hold and Release receiver | todo | |
| CA-M4-11 | The toast fade (D26) | todo | |
| CA-M4-12 | `SE.NewThankButton`, `pressThank`, the whisper echo | todo | |
| CA-M4-13 | Schema rows `thank.*` | todo | |
| CA-M4-14 | The Auto-thank settings page | todo | |
| CA-M4-15 | M4 docs and smoke checks | todo | |
| CA-M4-16 | M4 checkpoint | todo | |
| CA-M5-1 | Whole-branch review | todo | |
| CA-M5-2 | Review fixes | todo | |
| CA-M5-3 | Complexity and file-cap pass | todo | |
| CA-M5-4 | Docs sync | todo | |
| CA-M5-5 | Final checkpoint and PR open | todo | |
| CA-M5-6 | Owner smoke checklist handover | todo | (no commit) |

## Checkpoints

| milestone | date | gate: retail / forever / luacheck | head | pushed |
|---|---|---|---|---|
| baseline | 2026-11-10 | 1780/0/1 skip; 1780/0/1 skip; 0/0 (172 files) | 37a1e7b | n/a |

---

## M0: the locale split and the union gates (§1 M0)

### CA-M0-1: Commit the spec and this plan

- Files: `docs/superpowers/specs/2026-11-10-combined-actions-design.md`,
  `docs/superpowers/plans/2026-11-10-combined-actions.md`.
- Tests: none (docs only); the gate still runs (`test_prose`, `test_eol` read docs).
- Acceptance: both files committed; gate green.
- Commit: `CA-M0-1: Design and plan for combined actions, pings, markers and auto-thank (#16-#20)`

### CA-M0-2: `tests/test_locale.lua`, the union gates

- Files: `tests/test_locale.lua` (new), `tests/run.lua` (register the suite), `tests/test_page_pads.lua`
  (:537 reads the union), `locales/enUS.lua` only if the dead-key case finds existing dead keys.
- Tests, written first:
  - the enUS file list comes from the TOC (`Loader.tocFiles`, as `tests/loader.lua:26`), all
    `locales\enUS*.lua` lines in order;
  - they load in TOC order into one namespace; coverage reads `rawget(NS.L, key)` for every `L["..."]` an
    addon file reads (no key-on-miss answer);
  - a dead key (defined, read by no addon file) fails;
  - a key defined in two enUS files fails (read from the files' text, not the loaded table);
  - every topic file's TOC line is preceded by a `# LOAD-BEARING:` comment;
  - `test_page_pads.lua:537` checks against the union.
- Dynamic reads: the dead-key case counts only literal `L["..."]` reads, so before it deletes anything it
  greps for dynamic reads (`L[var]`, for example `L[r.textKey]`, or a reason table indexed into `L`). A key
  reached only that way goes in an explicit allowlist in the suite, with the reading file:line beside it,
  and is not deleted. At 37a1e7b no addon file reads `L[` with a non-literal key (every label table is
  built from literal `L["..."]` values), so the allowlist starts empty; a later task that adds a dynamic
  read adds its keys there.
- Implement: the suite only. If the dead-key case fails on today's tree, check each key against the
  dynamic-read grep, remove the truly dead ones from `enUS.lua` in this commit and list them in the commit
  body.
- Acceptance: the suite passes on the one-file tree under both profiles; a planted duplicate or dead key
  fails it (checked by hand, not committed).
- Commit: `CA-M0-2: Locale union gates: TOC-derived enUS files, raw coverage, dead and duplicate keys`

### CA-M0-3: `locales/enUS_Settings.lua`

- Files: `locales/enUS_Settings.lua` (new), `locales/enUS.lua`, `QuickComms.toc` (after
  `locales\enUS.lua`, line 39, with
  `# LOAD-BEARING: fills NS.L, which locales\enUS.lua creates, at file load.`), `tests/test_locale.lua`
  (two cases: every key in `enUS_Settings.lua` is read only from `settings/`; the reverse, every key in
  `enUS.lua` has at least one reader outside `settings/`).
- Method: grep every `L["..."]` reader; move each key read only under `settings/` into the new file, which
  opens `local _, NS = ...` / `local L = NS.L` and only assigns. A key read anywhere outside `settings/`
  stays in `enUS.lua`.
- Acceptance: the union gates green; `enUS.lua` well below 1500 lines (record the new count); the in-game
  load is unchanged (no string changes).
- Commit: `CA-M0-3: Move settings-only strings into locales/enUS_Settings.lua (localization-§6)`

### CA-M0-4: M0 docs

- Files: `docs/ARCHITECTURE.md` (Module Map row, the file census at :424-429 corrected for `enUS.lua` and
  the new file, no over-cap row), `docs/module-map.md` (row for `enUS_Settings.lua`), `docs/testing.md`
  (the locale suite), `docs/test-cases.md` and README badge (regenerated), this plan (ledger M0 rows).
- Tests: the gate; `test_prose`.
- Commit: `CA-M0-4: Document the locale split and the union gates`

### CA-M0-5: M0 checkpoint

- Run the gate; record totals for both profiles and luacheck.
- `git push -u origin feat/2026-11-10-combined-actions`.
- Add a Checkpoints row (date, totals, `git rev-parse --short HEAD`, pushed yes) and mark the ledger.
- Commit: `CA-M0-5: M0 checkpoint` (this plan only), then push again so the row is on origin.

---

## M1: the slot model, with ping (#17) and marker (#18) as single actions (§2, §3, §4, §5, §6)

### CA-M1-1: Mock surfaces for ping, marker and target

- Files: `tests/wow_mock.lua` (header documents each), `tests/test_mock_secure.lua` or `tests/test_compat.lua`
  (a smoke case per new surface).
- Adds: `C_Ping.IsPingSystemEnabled`, `C_Ping.GetCooldownInfo` (settable `endTimeMs`), the `enablePings`
  CVar, `CanBeRaidTarget`, `IsInRaid`, leadership and assist flags, `IsEveryoneAssistant`, a settable and
  secret-capable `UnitExists("target")`, globals `SLASH_PING1="/ping"` and `SLASH_TARGET_MARKER1="/tm"`
  (each removable per case), and `sentLines(i)` that splits a sent macro on `"\n"`.
- Acceptance: each surface answers its default and its override; nothing in `tests/_kit/` changes.
- Commit: `CA-M1-1: Mock the ping, marker and target APIs and a sentLines helper`

### CA-M1-2: Compat readers

- Files: `core/Compat.lua`, `.luacheckrc` (`read_globals` for `C_Ping`, `CanBeRaidTarget`,
  `IsEveryoneAssistant`, `SLASH_PING1`, `SLASH_TARGET_MARKER1`, scoped to `files["core/Compat.lua"]`),
  `tests/test_compat.lua`.
- Tests first: `PingCommand()` and `MarkerCommand()` return the localized command through `PlainString`,
  nil when the global (or `C_Ping`) is absent; `PingState()` answers `"off"` (system off, CVar off),
  `"cooldown"` (`endTimeMs > GetTime()*1000`), `"ok"`, and nil on a secret; `TargetExists()`, `CanMark()`
  plain or nil on a secret (no raw `== false`); `InRaid()`, `EveryoneAssistant()` via `plainTrue`;
  `MarkerRights()`: raid without leader or assist gives `"noRights"`, an assistant `"ok"` (both returns of
  `Compat.Leadership()` read), everyone-assistant `"ok"`, a party `"ok"`.
- Acceptance: cases green on both profiles; Compat.lua stays under the cap.
- Commit: `CA-M1-2: Compat readers for the ping and marker commands, ping state, target and marking rights`

### CA-M1-3: Library validation and the one-action rule

- Files: `modules/Library.lua`, `tests/test_library.lua`, `locales/enUS.lua` (the `noAction` and
  `oneAction` messages).
- Tests first: `Lib.ValidPing` (four types, false/nil pass, others fail); `Lib.ValidMarker` (1..8,
  false/nil pass, 0, 9, 1.5 fail); `validCallout` (Library.lua:442) rejects a bad ping or marker;
  `Lib.HasAction` counts actions; `Lib.CreateCallout` refuses no action with `"noAction"` and, M1 only,
  two actions with `"oneAction"`; a legacy empty-text, no-emote callout stays editable
  (`/qc set callout.name`); a seam write that removes the last action of a callout that had one is
  refused; a legacy gameEmote callout still validates.
- Acceptance: the message is `L["Set at least one action: a line, an emote, a ping or a marker."]`; the
  `oneAction` case carries a comment that CA-M2-1 inverts it.
- Commit: `CA-M1-3: Validate pings and markers, and require at least one action (one per callout in M1)`

### CA-M1-4: Callout field lists carry `ping` and `marker`

- Files: `modules/Library.lua` (`TEMPLATES.callout` :953 gains `ping=false, marker=false`;
  `CreateCallout` :474; `copyCallout` :488; `seedCallout` :719), `modules/Library_Migrate.lua` (step 6's
  raw copy :151), `tests/test_library.lua`, `tests/test_database.lua`.
- Tests first: create, copy and seed carry both fields; step 6's copy carries them; the boot check
  (Schema.lua:251-256) still resolves.
- Commit: `CA-M1-4: Carry ping and marker through create, copy, seed and step 6`

### CA-M1-5: Schema member rows

- Files: `settings/SchemaMembers.lua` (`callout.ping`, `callout.marker` beside `callout.emote`; reword
  `callout.emote` :180-188), `tests/schema_pins.lua` (regenerated, header note), `tests/test_schema.lua`,
  `locales/enUS_Settings.lua` (`L["Attack"]`, `L["Warning"]`, `L["On my way"]`, `L["Assist"]`, the row
  labels and descs: all read only by settings in this task, so the reverse locale case puts them here;
  CA-M1-12 moves the four ping names to `enUS.lua` when `modules/Preview.lua` reads them), removing the old
  `callout.emote` desc key.
- The reworded `callout.emote` label is `L["Game emote"]` (the existing key), not `L["Emote"]`: `L["Emote"]`
  already labels the `emote` (/e) channel (SchemaMembers.lua:140), and one key must not carry two meanings.
- Tests first: the rows' type, default false, values (none plus four; none plus 1..8 with the raid-icon
  texture labels), `normalize` (`""`/`"none"` to false; 0 to false), validate wired, not reset-exempt
  (D11); the dead-key gate proves the old emote keys are unread.
- Commit: `CA-M1-5: Schema rows for callout.ping and callout.marker, and reword callout.emote`

### CA-M1-6: BuiltIns `extra` and the integrity row

- Files: `defaults/BuiltIns.lua` (`BI.Callout(..., extra)` :30; `BI.Callouts` rows take `r[6]`),
  `defaults/BuiltIns_Emotes.lua` (post-assign idiom :19-20 becomes `extra`, no data change),
  `tests/test_builtins.lua`.
- Tests first: every `BI.callouts[*]` passes `validCallout` and `Lib.HasAction` (ping and marker
  included); the Emotes set's data is byte-for-byte as before; `glyph` is never copied into a profile.
- Commit: `CA-M1-6: BI.Callout takes extra action fields, and every shipped callout is checked`

### CA-M1-7: `B.BakeActions` with one action per kind

- Files: `modules/Bake.lua`, `tests/test_bake.lua` (rewrite the header and :1, :26-29 to "one line per
  action, never a newline from data"), `locales/enUS.lua` (reason texts if Bake reads them).
- Tests first: `BakeActions` returns `macro, reason, info` with `info.actions` (all), `info.baked` (only
  baked), `info.total`; the Line entry equals today's `B.Bake`; the emote line is
  `NS.Emotes.Command(token)`; the ping line is `/ping [@target,exists] 1..4` (numeric keyword); the marker
  line is `/tm [@target,exists] !N`; absent `SLASH_PING1` or `SLASH_TARGET_MARKER1` gives `noPing` or
  `noMarker` and drops only that action; each entry's `chatType` and `lock` per the §3 table; `B.Bake`'s
  contract unchanged.
- Note: `MAX_MACRO`, the newline join and the Line budget are tested in CA-M2-2, but the code joins with
  `"\n"` from the start.
- Commit: `CA-M1-7: B.BakeActions bakes each set action, with pings and markers on the target`

### CA-M1-8: The slot's action lists and the arm gate

- Files: `modules/Surfaces.lua` (`S.Slot` :98-124, `rebake`, `S.RefreshLocks` :542), `modules/Pad.lua`
  (`arm()` :213), the dial arm site if it gates on `chatType` (`modules/Dial_Secure.lua`),
  `tests/test_surfaces.lua`, `tests/test_pad.lua`, `tests/test_dial_secure.lua`.
- Tests first: `slot.line` is the macro; `slot.actions` and `meta.actions` hold only baked actions;
  `slot.skipped` the rest; `slot.chatTypes`, `slot.chatType == slot.chatTypes[1]`; `slot.locks`, `slot.lock`,
  `lockdownChip` when any lock is lockdown; a ping-only and a marker-only callout arm; a callout whose only
  action was skipped does not arm. Re-check the exact macrotext pin at `test_surfaces:254`.
- Commit: `CA-M1-8: Slots carry their baked actions, and a ping-only or marker-only callout arms`

### CA-M1-9: Press order, the action gate, one tick, D16

- Files: `modules/SendEngine.lua` (`press` :435-470), `modules/Pad_Render.lua` (`REASON_TEXT` :137 rows
  `noAction`, `noPing`, `noMarker`), `tests/test_sendengine.lua`, `tests/test_preview.lua`.
- Tests first: `meta.echo` prints before `selfText` (step 2, pinned in test_preview); `selfText` returns
  only when no action is left; the gate reads `#meta.actions > 0`; a ping-only press calls `G.Decide` once,
  stamps `State.lastSendAt` once, `qcOnPress` once, and emits `SEND_RESULT "sent"` at once (D16); in
  combat the macro runs through `sentMacros` with `m.blocked` empty; no file names `C_Ping.SendMacroPing`
  (new grep case); the firewall test (:201-211) unchanged.
- Commit: `CA-M1-9: The press gates on its actions, ticks once, and an action-only press reports sent`

### CA-M1-10: Press-time reasons in PreClick

- Files: `modules/SendEngine.lua` (`SE.PreClick` :490 split; new `SE.PressNotes(meta)`),
  `locales/enUS.lua` (the four press-time texts), `tests/test_sendengine.lua`.
- Tests first: the notes are read in PreClick in and out of combat (the re-bake keeps its `inCombat()`
  return) and printed once each by `press()`, named with `meta.name`: no target to ping, no target to
  mark, cannot be marked, no rights in a raid; an assistant prints nothing; pings off and cooldown print
  (cooldown set before the macro, so a press's own ping never reads as cooldown); a secret `UnitExists`
  prints nothing; PreClick writes no attribute.
- Commit: `CA-M1-10: Say why a ping or a mark cannot land, read before the macro runs`

### CA-M1-11: The popup draft carries the action fields

- Files: `settings/CalloutPopup.lua` (`DRAFT` :58, `copyFields`, `put`, `seamValue` gain `emote`, `ping`,
  `marker` with false-to-nil handling), `tests/test_callout_popup.lua`.
- Tests first: opening and saving a callout set to a ping by `/qc set` keeps the ping; the `DRAFT` pin
  updated; no new control is drawn (M1 rule).
- Commit: `CA-M1-11: Editor Save keeps a callout's emote, ping and marker`

### CA-M1-12: Preview, tooltip and `/qc check` for one action

- Files: `modules/Preview.lua` (`P.SlotEcho` :484 returns a list), its consumers:
  `modules/SendEngine.lua` (`press` :448-449 does `NS.Print(NS.Preview.FillEcho(meta.echo))` on a string;
  it prints one `FillEcho` per entry, one `NS.Print` per row), `modules/Surfaces.lua` (`S.MarkPreview`
  :286-291 stores the list as `slot.echo`), `modules/Pad.lua` (:211 `slot.echo or slot.line`: a string
  `slot.line` is wrapped as a one-entry list so `meta.echo` is always a list), `modules/Pad_Render.lua`
  (`TooltipLines` :192), `settings/SlashVerbs.lua` (`V.CheckLines` :24), `locales/enUS.lua`
  (`L["would ping %s on your target"]`, `L["would mark your target %s"]`, `L["would emote %s"]`, and the four
  ping names `L["Attack"]`, `L["Warning"]`, `L["On my way"]`, `L["Assist"]` moved from
  `enUS_Settings.lua`, which Preview now reads), `locales/enUS_Settings.lua`, `tests/test_preview.lua`,
  `tests/test_check.lua`, `tests/test_pad_render.lua`; re-check `tests/test_edit_preview.lua` (:397 reads
  `qcMeta.echo`) and `tests/test_preview_window.lua`.
- Tests first: a ping-only callout previews `would ping Attack on your target`; a marker-only one renders
  the `{rtN}` texture; a skipped action shows its reason; `/qc check` prints the action's line and bytes;
  each echo entry is its own `NS.Print` (no raw newline; `test_glyphs` green); pins at test_preview :157,
  :433, :584 re-checked.
- Commit: `CA-M1-12: Preview, tooltip and /qc check show a ping or a marker action`

### CA-M1-13: M1 docs and smoke checks

- Files: `docs/ARCHITECTURE.md` (Per-client features: Ping and Marker on both clients, citing
  Blizzard_PingUI; Settings Schema rows; Taint Notes), `docs/compat-layer.md` (`PingCommand`,
  `MarkerCommand`, `PingState`, `TargetExists`, `CanMark`, `MarkerRights`, `InRaid`, `EveryoneAssistant`),
  `docs/midnight-quirks.md` (`GetRaidTargetIndex` secret, `SetRaidTarget` restrictions, `@target` parses
  without `exists`), `docs/schema.md` (callouts row :35, member rows :69), `docs/data-flow.md` (PreClick
  reasons), `docs/known-limitations.md` (needs a target; marking rights; three-unit throttle; D16 flash),
  `docs/scope.md` (drop "marks (#4)" from "does not do"), `docs/smoke-tests.md` (Index rows; PING-1..5,
  MARK-1..7 in Pending sign-off, and the PING and MARK ids added to the Pending sign-off roll-up
  sentence, the "Owed from ..." paragraphs near line 2587), `docs/testing.md` (mock surfaces),
  `docs/test-cases.md` + README badge, `README.md` feature text (README.md:92-96: a callout can ping your
  target or mark it), this plan.
- Commit: `CA-M1-13: Document pings and markers, and add the PING and MARK smoke checks`

### CA-M1-14: M1 checkpoint

- Gate, push, Checkpoints row, ledger. The report names D10 and D16 for the owner.
- Commit: `CA-M1-14: M1 checkpoint`, then push.

---

## M2: combining (#16) (§2 to §4, §7)

### CA-M2-1: Lift the one-action rule

- Files: `modules/Library.lua`, `tests/test_library.lua` (the `oneAction` case inverted: two, three and
  four actions are accepted), `locales/enUS.lua` (drop the `oneAction` message; dead-key gate).
- Commit: `CA-M2-1: A callout may hold up to four actions`

### CA-M2-2: The multi-line macro and its caps

- Files: `modules/Bake.lua` (`B.MAX_MACRO = 255`, the join, `info.total`, the Line budget, D14),
  `tests/test_bake.lua`, `locales/enUS.lua` if a new reason text is read.
- Tests first: order line, emote, ping, marker; no data byte follows a `"\n"`; `info.total` counts
  `LIVE_NOMINAL` per live token plus one per newline; the Line budget is
  `min(MAX_BYTES, MAX_MACRO - others - newlines)`, so a Line over it fails `tooLong` and the rest bakes;
  every action failing returns the Line's reason (else the first action's); solo with the "self" fallback
  gives `selfText` and the other actions arm.
- Commit: `CA-M2-2: Join a callout's actions into one macro held to 255 bytes`

### CA-M2-3: The re-bake refreshes the press meta

- Files: `modules/Surfaces.lua` (`slot.rebake`), `modules/SendEngine.lua` (the consumer is the local
  `rebake(b)` at :143-151, called by `SE.RefreshRebakes`; :42-48 is only its comment block. It expects one
  string today, so it takes `macro, reason, info`, refreshes `meta.actions`, `meta.chatTypes`,
  `meta.locks` and `meta.skipped` from `info`, and re-arms on a changed macro),
  `locales/enUS.lua` (`L["%s: the line is too long to send with its other actions."]`),
  `tests/test_surfaces.lua`.
- Tests first: a `{coordinates}` re-bake that pushes the Line over budget refreshes `meta.actions`,
  `meta.chatTypes`, `meta.locks`, `meta.skipped` and prints the reason (no false "dropped"); a re-bake
  where nothing bakes keeps the old macro and meta.
- Commit: `CA-M2-3: A press-time re-bake refreshes the actions the echo waits for`

### CA-M2-4: Echo grouping and per-action locks

- Files: `modules/SendEngine.lua` (step 6 and 8), `modules/SendEngine_Guard.lua` (`G.Record` :88 takes
  `press`, `G.Match` :95, `G.Expire` :114), `locales/enUS.lua` (`L["%s (emote) may not have been sent."]`
  and the kind names), `tests/test_sendengine.lua`, `tests/test_send_guard.lua`, `tests/test_emotes.lua`.
- Tests first: a Line plus an Emote gives `SE.EchoState().pending == 2` and one "sent"; a Line-only press
  keeps 1 (:265); one expired entry gives one "dropped" naming the kind; a locked Line plus an Emote prints
  the note and records only TEXT_EMOTE; all actions locked keeps today's print-and-return; test_emotes'
  game-emote cases re-run as an Emote slot beside a Line.
- #16's AC, pressed headless: the callout "Kick on me" in Party with POINT, ping Attack and marker 8. One
  press gives `sentLines` of 4 lines in the order line, emote, ping, marker; `G.Decide` is called once and
  `State.lastSendAt` stamped once; `SE.EchoState().pending == 2` and one "sent". The case runs in combat
  as well as out, and passes under `KA0S_KIT_CLIENT=forever`.
- Commit: `CA-M2-4: One press records an echo per chat action and reports one result`

### CA-M2-5: Diagnostics shows each newline

- Files: `modules/SendEngine.lua` (`SE.Escaped` :173), `tests/test_diagnostics.lua`.
- Tests first: a two-action macro shows ` \n ` and the Diagnostics row (Diagnostics.lua:197) stays one row.
- Commit: `CA-M2-5: Diagnostics shows a combined macro on one row`

### CA-M2-6: One echo row per action

- Files: `modules/Preview.lua` (`P.SlotEcho`, `P.FillEcho`), `tests/test_preview.lua`.
- Tests first: one entry per action, baked or skipped, in order; `%t` filled in each; each printed with its
  own `NS.Print`.
- Commit: `CA-M2-6: A previewed press prints what each action would do`

### CA-M2-7: The editor's four slots

- Files: `settings/CalloutPopup.lua` (layout lines 1-4, `FIELDS` gains `ping`, `marker`; blank draft in
  `Pop.Open` :579; R7 removed from `Pop.Save` :611; None writes `text = ""`; emptying the emote sets
  `draft.emote = nil`), `settings/SchemaMembers.lua` (`CHANNEL_LABEL` :140, the `callout.channel` values:
  `gameEmote` becomes `L["None (no chat line)"]`, the D10 relabel), `settings/Groups.lua` (`SHORT_CHANNEL`
  :226, the same relabel), `tests/schema_pins.lua` (regenerated, header note), `tests/test_schema.lua`,
  `locales/enUS_Settings.lua` (`L["None (no chat line)"]`, `L["Emote (optional)"]`, the Ping and Marker
  labels), `tests/test_callout_popup.lua`, `tests/test_layout.lua` if it pins the popup.
- `L["Game emote"]` stays: the `callout.emote` label (CA-M1-5) and CalloutPopup.lua still read it. Drop it
  only if the dead-key gate shows no reader is left.
- Tests first: four slots drawn; None hides Text; clearing the emote; Save keeps an emote beside a Line;
  the `FIELDS` pin; `fit()` sizes the window. D10: the gameEmote kind is labelled None.
- Commit: `CA-M2-7: The callout editor sets a line, an emote, a ping and a marker`

### CA-M2-8: `check(d)` split

- Files: `settings/CalloutPopup.lua` (`checkLine`, `checkEmote`, `checkPing`, `checkMarker`, then
  `Lib.HasAction`), `locales/enUS_Settings.lua` (`L["Pick an emote from the list."]`, `L["%s: %s"]` if not
  present), `tests/test_callout_popup.lua`.
- Tests first: `checkLine` counts bytes (a multi-byte line at 255 bytes, not characters); `noAction` names
  itself; each failure names its field; each function under CCN 15.
- Commit: `CA-M2-8: The editor checks each action and counts the line in bytes`

### CA-M2-9: Settings readers

- Files: `settings/Callouts.lua` (`C.PreviewLines` :85), `settings/Groups.lua` (`G.CalloutSummary` :254,
  `calloutLabel` :262, tooltip :502), `locales/enUS_Settings.lua`, `tests/test_editors.lua`,
  `tests/test_page_groups.lua`.
- Tests first: `[1]` is the one-line summary (`"Kick on me" in Party, /point, ping Attack, mark Skull`);
  per-action rows, bytes and `L["Macro: %d of 255 bytes"]`; `L["Needs a target when pressed."]`; Groups
  suffixes `+/point`, `+ping`, `+{rtN}`; `G.PreviewBlocks` still reads `[1]`.
- Commit: `CA-M2-9: The callout editor and the groups page list every action`

### CA-M2-10: Module and slash readers

- Files: `modules/Pad_Render.lua` (`TooltipLines`), `settings/SlashVerbs.lua` (`V.CheckLines`), the enUS
  files per reader (a key CA-M2-9 put in `enUS_Settings.lua` that a module now reads moves to `enUS.lua`),
  `tests/test_pad_render.lua`, `tests/test_check.lua`.
- Tests first: the tooltip lists each action, skipped ones with their reason; `/qc check` prints
  `"<kind>: <line>, %d of 255 bytes"` per action, then the macro total.
- Commit: `CA-M2-10: Tooltips and /qc check list every action`

### CA-M2-11: Retire `slot.chatType`

- Files: every remaining reader (`grep -rn "chatType\b" modules settings`), `modules/Surfaces.lua`, the
  matching tests.
- Tests first: a grep case that no addon file reads `slot.chatType` or `meta.chatType`.
- Commit: `CA-M2-11: Retire the single chatType on slots`

### CA-M2-12: M2 docs and smoke checks

- Files: `docs/ARCHITECTURE.md` (Taint Notes: multi-line macrotext; Known Limitations), `docs/data-flow.md`
  (one macro line per action), `docs/taint.md` (send buttons), `docs/settings-panel.md` (rewrite "The emote
  channels"; popup tree, draft and Save), `docs/common-tasks.md` ("Add a member field" with ping/marker;
  "Add a callout action"), `docs/known-limitations.md` (255 bytes covers the whole macro, re-check trigger
  ACTION-4), `docs/smoke-tests.md` (ACTION-1..8, and the ACTION ids in the Pending sign-off roll-up
  sentence), `docs/test-cases.md` + badge, `README.md` feature text (README.md:92-96 says a game-emote
  callout does one thing: a callout now sends a line, an emote, a ping and a marker on one press), this
  plan.
- Commit: `CA-M2-12: Document combined actions, and add the ACTION smoke checks`

### CA-M2-13: M2 checkpoint

- Gate, push, Checkpoints row, ledger. The report names F4a and F4b for the owner.
- Commit: `CA-M2-13: M2 checkpoint`, then push.

---

## M3: #20, shipped callouts gain an emote (§8, §10)

### CA-M3-1: 12 shipped callouts gain an emote

- Files: `defaults/BuiltIns_World.lua`, `defaults/BuiltIns_Group.lua`, `defaults/BuiltIns_MythicPlus.lua`,
  `defaults/BuiltIns_Raid.lua` (each listed row gains `extra = { emote = <token> }`, no line changes),
  `tests/test_builtins.lua`.
- Tests first: :505 widens to every `BI.callouts[*].emote`, checked against `tests/emote_tokens.lua` on both
  profiles; :519 (each token bakes to the client's command) widens the same way; the In Group audit (:407)
  passes; a pin of the 12 additions (id to token, exactly the §8 table); Arena and battleground sets carry
  no emote (F4b).
- The bake audit (:74-90) calls only `NS.Bake.Bake`, the Line action, so as it stands it would pass
  vacuously for the 12 emotes. It widens to `B.BakeActions`: under each set's snapshot, every action bakes
  and none is skipped (`#info.baked == #info.actions`), `info.total <= B.MAX_MACRO`, and no
  baked action carries a lock. The `B.Bake` assertions stay.
- #20's "each sends line+emote on one press": one built-in press, `bi.group.hello` seeded on a fresh
  profile and pressed in a party, gives `sentLines` of 2 (its line, then its emote command).
- Commit: `CA-M3-1: Twelve shipped callouts perform a fitting emote with their line (#20)`

### CA-M3-2: The two `healme` rows

- Files: `defaults/BuiltIns_MythicPlus.lua` (`bi.mplus.healme` after `bi.mplus.kicks`),
  `defaults/BuiltIns_Raid.lua` (`bi.raid.healme` after `bi.raid.stones`, before the lead list),
  `locales/enUS.lua` (`L["Need heals!"]`, `L["Need heals on me!"]`), `tests/test_builtins.lua`.
- Tests first: both rows on a fresh profile on both profiles, in place, with HEALME, `gi:heart-plus`
  (already in the catalog), green; set sizes Solo 7, In Group 11, Dungeon 8, Raid 9; no set over
  `DL.MAX_SLICES = 12`; no Auto dial gains a page.
- Commit: `CA-M3-2: Dungeon and Raid gain a Heal me callout with the HEALME emote (#20)`

### CA-M3-3: Step 20 part 1

- Files: `modules/Library_Migrate.lua` (`Lib.MigrateComboCallouts` guard and part 1, frozen `COMBO_EMOTES`),
  `tests/test_database.lua`.
- Tests first (call the function directly; registration is CA-M3-5): an unedited shipped callout gains its
  emote once; a changed text, a changed channel, an emote already set, a ping or a marker set each leave
  it alone (one case per field); renamed or recolored still gains (F4a); no origin gains nothing; text
  from another locale reads as edited; `nil`, `{}`, unseeded and damaged profiles are safe; a re-run is a
  no-op.
- Commit: `CA-M3-3: Step 20 adds the shipped emote to unedited shipped callouts`

### CA-M3-4: Step 20 part 2

- Files: `modules/Library_Migrate.lua` (frozen `COMBO_NEW`, group by origin parent, `takeCalloutId` :102, a
  frozen field writer `writeComboCallout(profile, row)` that writes `seedCallout`'s field list from the
  `COMBO_NEW` row, and `placeCalloutAfter(profile, list, cid, afterOrigin)`), `tests/test_database.lua`.
- Why not reuse: `seedCallout` (Library.lua:719) is local to Library.lua and reads `NS.BuiltIns` at run
  time, so a migration step must not call it; `placeAfter` (Library_Migrate.lua:463-475) reads
  `profile.groups[id].origin`, so it only places groups on surface lists. `placeCalloutAfter` is its
  callout-list twin, reading `profile.callouts[id].origin` and skipping a non-table entry.
- Tests first: the 2 rows inserted once, in shipped order, after their predecessors (else appended), with no
  `glyph` field; a renamed or reordered group still gains; a deleted set and a duplicated set gain nothing;
  a deleted callout is not brought back; a damaged group (non-table `callouts`) is skipped; idempotent;
  `placeCalloutAfter` leaves a list that holds `cid` as it is, and skips a dangling id in the list; the
  written fields equal the frozen row even when `BI.callouts` is changed after load.
- Commit: `CA-M3-4: Step 20 inserts the two Heal me callouts into their shipped sets`

### CA-M3-5: Register step 20

- Files: `core/Database.lua` (`NS.MIGRATIONS` step 20 with a comment; `NS.SCHEMA_VERSION` :86 to 20),
  `tests/test_builtins.lua` (:198 and the comment :193-197 rewritten), `tests/test_anim_styles.lua`
  (:337-338), `tests/test_profile.lua` (:56, :146), `tests/test_database.lua` (step 19 replay :580-640:
  Solo-copy count unchanged, `originCount` re-read for Dungeon and Raid, unedited Solo seeds carry their
  emote).
- Commit: `CA-M3-5: Register schema step 20`

### CA-M3-6: M3 docs and smoke checks

- Files: `docs/schema.md` (Step 20 paragraph after step 19 :299, defining "unedited"), `docs/ARCHITECTURE.md`
  (Settings Schema, Known Limitations), `docs/known-limitations.md` (In Group emotes padlocked under
  `pvpMatch`), `docs/smoke-tests.md` (EMOTE-9, EMOTE-10, and both ids in the Pending sign-off roll-up
  sentence), `docs/test-cases.md` + badge, `README.md` feature text (the shipped callouts that now perform
  an emote with their line, and the two Heal me callouts), this plan.
- Commit: `CA-M3-6: Document step 20 and add the EMOTE-9 and EMOTE-10 smoke checks`

### CA-M3-7: M3 checkpoint

- Gate, push, Checkpoints row, ledger. The report names F2, F3, F4c and FRB, and asks for F2, F3 and FRB
  before M4 starts. If no answer arrives, M4 proceeds on R-B and D4 as given, and the PR body names both.
- Commit: `CA-M3-7: M3 checkpoint`, then push.

---

## M4: #19 auto-thank (§9)

### CA-M4-1: Mock aura, GUID, friend and guild surfaces

- Files: `tests/wow_mock.lua` (header), `tests/test_compat.lua`.
- Adds: `C_UnitAuras.GetAuraDataByAuraInstanceID`, `GetAuraCasterGUID`, `GetUnitAuraInstanceIDs`, a
  `UNIT_AURA` updateInfo helper with a secret variant, `GetPlayerInfoByGUID`, `UnitGUID`,
  `C_PartyInfo.IsGUIDInGroup`, `C_FriendList.IsFriend`, `IsGuildMember`, `SLASH_WHISPER1`, frame
  `SetAlpha`/`GetAlpha`/`IsMouseOver` if missing.
- Commit: `CA-M4-1: Mock the aura, GUID, friend and guild APIs`

### CA-M4-2: Compat aura and whisper readers

- Files: `core/Compat.lua`, `.luacheckrc` (scoped `read_globals`), `tests/test_compat.lua`.
- Tests first: `AuraCaster` GUID first, `sourceUnit` second, both nil drops; rejects `Creature-`, `Pet-`,
  self, a group member (secret reads as in group); a nil name drops; `known` from friend or guild;
  `AuraByInstance`; `HelpfulAuraIds` nil when any element is secret; `WhisperName` by
  `Compat.RegionalNames()` (First-Surname), else `Name-Realm` with spaces and hyphens stripped, or the name
  alone on the same realm.
- Commit: `CA-M4-2: Compat readers for an aura's caster, the player's helpful auras and a whisper name`

### CA-M4-3: Constants, defaults, raid-buff ids, the AutoThank locale file

- Files: `core/Constants.lua` (`C.THANK.*`; a `C.LAYERS` comment :86 recording the toast's HIGH strata),
  `defaults/Profile.lua` (`thank` block, R-B), `defaults/GameIds_Clients.lua` (`THANK_RAID_BUFFS` Retail
  1459, 21562, 1126; Forever: derived from its client tables with `tools/client_tables.py` and the wago
  `wowf` export, matched by spell name, each id recorded UNVERIFIED until THANK-7; if the tool cannot
  answer, the Forever list stays empty and CA-M4-14 hides or disables the toggle there, per FRB),
  `locales/enUS.lua` (`L["Thanks for the {buff}, {name}!"]`: read first by `defaults/Profile.lua`, so it
  belongs here), `tests/test_profile.lua`, `tests/test_gameids.lua` (Forever: either the derived ids, or an
  empty list pinned with a comment naming FRB).
- `locales/enUS_AutoThank.lua` is not made here: this task has no AutoThank-only string. CA-M4-4, the first
  task with one, creates it, its TOC line and its locale case.
- Commit: `CA-M4-3: Auto-thank constants, defaults (on in the open world), raid-buff ids and locale file`

### CA-M4-4: Pure decision functions

- Files: `modules/AutoThank.lua` (new; TOC after `modules\SendEngine.lua` and `modules\Situation.lua`),
  `locales/enUS_AutoThank.lua` (new; the first AutoThank-only strings), `QuickComms.toc` (both: the locale
  file after `locales\enUS_Settings.lua` with its `LOAD-BEARING` comment), `tests/test_autothank.lua`
  (new), `tests/run.lua` (register), `tests/test_locale.lua` (a case: keys in `enUS_AutoThank.lua` are read
  only from `modules/AutoThank*`).
- Tests first: `AT.Accept` per filter (helpful; `isFromPlayerOrPlayerPet == true` accepted for a stranger;
  duration 59 against 60 and 0; cooldown; allowlist; the two mutes); `AT.Fill` fills `{name}`/`{buff}`,
  cleans control bytes, doubles pipes, cuts at a UTF-8 boundary and never inside a doubled pipe;
  `AT.Macro` per mode (`/thank Name-Realm`, `/w Name text`, "both" held to 255 bytes), refuses a text
  starting with `/` and an empty filled text ("both" keeps the emote).
- Commit: `CA-M4-4: Auto-thank decides which buffs to thank and builds the macro`

### CA-M4-5: The unit-filter frame

- Files: `modules/AutoThank.lua` (`NS.AutoThank.frame`, `AT.Rewire`, `NS.STAND_DOWN`/`NS.STAND_UP`
  appends, subscriptions to `SITUATION_CHANGED` and `PROFILE_CHANGED`; core/Bus.lua:21-31 carries no
  setting-change message, so a `thank.*` change reaches `AT.Rewire` through the rows' `onChange`, wired in
  CA-M4-13),
  `tests/test_autothank.lua`, `tests/test_disabled.lua` (teardown pin; `PINNED` does not gain UNIT_AURA).
- Tests first: `__unitEvents` is `UNIT_AURA -> { "player" }` when on in the open world; empty when off, in
  a dungeon by default, or stood down; the frame is re-used across a disable and enable.
- Commit: `CA-M4-5: Auto-thank listens to the player's auras only where it is on`

### CA-M4-6: `AT.OnAura`

- Files: `modules/AutoThank.lua`, `tests/test_autothank.lua`.
- Tests first: stood down or in combat or on the combat edge returns (dirty in combat); a secret or
  non-table payload sets dirty, indexing nothing; a full update re-snapshots silently; removed ids leave
  `State.thankKnown`; an added plain aura that passes `AT.Accept` becomes a candidate; a content kind off
  gives nothing. Candidates go to a host hook stubbed until CA-M4-9.
- Commit: `CA-M4-6: Auto-thank finds new buffs from other players out of combat`

### CA-M4-7: The after-combat diff

- Why not at the edge: at `PLAYER_REGEN_DISABLED`, `InCombatLockdown()` is still false
  (`Compat.InCombat`, Compat.lua:590), so `SE.RunOrQueue` (SendEngine.lua:301-308) would run the diff at
  once; and even `SE.Queue` would not hold it, because the same edge sends `RESTRICTION_CHANGED` and
  `onRestrictionChanged` (SendEngine.lua:535-539) drains while lockdown is false.
- Files: `modules/AutoThank.lua` (`AT.Diff`, which returns still dirty while `Compat.InCombat()` or
  `State.combatEdge` holds; `AT.OnAura` files `SE.Queue("thank.diff", AT.Diff)`, not `RunOrQueue`, only
  when `Compat.InCombat()` is true or `State.combatEdge` is set, which is after the edge's drain; the
  module's `RESTRICTION_CHANGED` receiver runs `AT.Diff` when dirty, nothing is restricted and lockdown is
  false; `AT.OnCombatEnd()`), `modules/Restrictions.lua` (`R.OnCombatEdge(false)` :170-174 calls
  `NS.AutoThank.OnCombatEnd()` when loaded, after `State.combatEdge` is cleared: the /reload-in-combat
  case, where `RESTRICTION_CHANGED` may never come), `tests/test_autothank.lua`.
- Tests first: with lockdown still false at the `PLAYER_REGEN_DISABLED` edge, a buff in the edge window
  sets dirty and is not diffed or toasted at the edge, and the edge's own drain runs nothing for it; a
  secret payload in combat, then the end of combat, gives the new aura once; a `/reload` in combat with
  no `RESTRICTION_CHANGED` still diffs on `PLAYER_REGEN_ENABLED` through the hook; a still restricted read
  stays dirty; at most `C.THANK.COMBAT_QUEUE`, newest first; expired or unreadable auras drop quietly.
- Commit: `CA-M4-7: Buffs gained in combat are thanked after the fight`

### CA-M4-8: The Toast seam

- Files: `core/ToastSetup.lua` (new; TOC after `core\GlowSetup.lua`), `QuickComms.toc`,
  `tests/test_surface_parity.lua` and `tests/run.lua` (`Kit.setSurfaceSource` entry :122),
  `tests/test_harness.lua` (:44-56 Toast is the live library), `tests/test_skin_windows.lua` `FILES`,
  `tests/skin_surfaces.lua`.
- Tests first: `NS.NewToast(d)` sets `d.owner` and returns the library's toast; with the library absent it
  returns `NS.ToastStub` whose members are no-ops; parity covers every member the host calls.
- Stop condition (F5): if a skin gate needs toast colors LibKa0s does not expose, stop and ask the owner.
- Commit: `CA-M4-8: The LibKa0s Toast seam, with a stub when the library is missing`

### CA-M4-9: The toast host and its throttle

- Files: `modules/AutoThank_Toast.lua` (new; TOC after `modules\AutoThank.lua`), `QuickComms.toc`,
  `tests/test_autothank.lua`.
- Tests first: five strangers give 3 on screen and 2 queued, shown `C.THANK.GAP` apart; `maxQueue` drops
  the oldest; no `Show` in lockdown (payloads held in the host's list, the GAP pump gated on lockdown); the
  stand-down clears the toast. The builder is stubbed for the button until CA-M4-12.
- Commit: `CA-M4-9: Auto-thank shows a throttled toast stack`

### CA-M4-10: The toast's combat Hold and Release

- Files: `modules/AutoThank_Toast.lua` (its own `RESTRICTION_CHANGED` receiver on the AutoThank Bus target,
  shaped like SendEngine.lua:535-539: `NS.Restrictions.InCombat()` true calls `toast:Hold()` with no
  `keepShown`; false with `Compat.InCombat()` false calls `toast:Release()`, then `AT.Diff()` when
  `State.thankDirty`), `modules/AutoThank.lua` (`AT.OnCombatEnd` releases the toast before its diff),
  `tests/test_autothank.lua`.
- Tests first: `Hold()` with no `keepShown` at the combat edge while lockdown is still false; `Release()`
  does not fire at combat start (the edge's drain does not release); `Release()` at the end of combat,
  before the diff's own shows, both from the receiver and from the `R.OnCombatEdge(false)` hook with no
  `RESTRICTION_CHANGED`; `Hold(true)` and `Pause()` are never called.
- Commit: `CA-M4-10: The thank toast holds through combat and comes back after it`

### CA-M4-11: The fade (D26)

- Files: `modules/AutoThank_Toast.lua`, `tests/test_autothank.lua`.
- Tests first: alpha 1 until the last `C.THANK.FADE` seconds, then falls to 0; hover holds alpha 1 and
  pushes the due time; leaving with under a second gives one second; `OnUpdate` is hooked once per frame
  and returns in combat; the library hides at `C.THANK.DURATION`.
- Commit: `CA-M4-11: An unclicked thank toast fades before it goes`

### CA-M4-12: The Thank button and its press

- Files: `modules/SendEngine.lua` (`SE.NewThankButton`, `pressThank`), `modules/SendEngine_Guard.lua`
  (`G.CHAT_TYPE_BY_EVENT` and `G.ECHO_EVENTS` gain `CHAT_MSG_WHISPER_INFORM`; `fromMe = true`),
  `modules/AutoThank_Toast.lua` (the builder arms the button), `tests/test_autothank.lua`,
  `tests/test_send_guard.lua`, `tests/test_disabled.lua` (`PINNED` gains CHAT_MSG_WHISPER_INFORM),
  `tests/test_library.lua` (:119 comment records D4 beside the #7 ruling; the refusal stays).
- Tests first: the click's `sentMacros` per mode; a right-click never runs the macro (`qcLeftOnly`); a
  click does not stamp `lastSendAt` and the next pad press is not guarded; the result carries
  `calloutId = key`, `surfaceId = "thank"` and touches no pad or dial button; the whisper lock under chat
  lockdown prints the note and records no echo; "both" records two pending entries and one result; the
  empty-text toast says `L["Nothing to whisper: the thank-you text is empty."]` and the button is unarmed.
- Moved here from CA-M4-9, since they need this task's button and click: `Attach` is called once per pool
  frame across reuses (`frame.qcThank` made once); `toast:Remove(key)` after a click goes through
  `SE.RunOrQueue`.
- #19's AC, now that the builder is real: a UNIT_AURA from a stranger, end to end, gives exactly one
  `Show`, and the drawn toast text is `L["%s buffed you with %s"]` filled with the caster's name and the
  buff.
- Commit: `CA-M4-12: The toast's Thank button emotes or whispers the caster`

### CA-M4-13: Schema rows `thank.*`

- Files: `settings/AutoThank.lua` (new; TOC after `settings\Dials.lua`, before `settings\Profiles.lua`;
  `NS.SchemaRuntime.AddRows`), `QuickComms.toc`, `tests/schema_pins.lua` (regenerated),
  `tests/test_schema.lua`, `locales/enUS_Settings.lua`.
- Tests first: every row's default references `NS.C.PROFILE.thank`; `position` reset-exempt; `/qc set
  thank.send line` works; a change re-runs `AT.Rewire`, through each `thank.*` row's `onChange` (there is no
  Bus setting-change message, so this is the only wire; CA-M4-5 does not subscribe to one).
- Commit: `CA-M4-13: Schema rows for auto-thank`

### CA-M4-14: The Auto-thank page

- Files: `settings/AutoThank.lua` (page on `buildGeneralPage`, Panel.lua:239, `pageKey="autothank"`,
  Defaults button, stubbed `RegisterOptionsPage`, `settings/OptionsSetup.lua:80`), `settings/Groups_When.lua`
  (lift the local `contentValues()` :209 to a public `Settings.GroupsWhen.ContentValues()` in the same file;
  Groups_When.lua loads before `settings/AutoThank.lua` in the TOC, so the page reads it from there),
  `locales/enUS_Settings.lua`, `tests/test_layout.lua`, `tests/test_groups_when.lua`.
- Tests first: General, Where and Filter headings; one checkbox per content kind, hidden kinds hidden on
  this client; `Settings.GroupsWhen.ContentValues()` gives Groups When the same values as before; on
  Forever with an empty `THANK_RAID_BUFFS`, the raid-buffs-only toggle is hidden or disabled per FRB.
- Commit: `CA-M4-14: The Auto-thank settings page`

### CA-M4-15: M4 docs and smoke checks

- Files: `docs/ARCHITECTURE.md` (Module Map: AutoThank, AutoThank_Toast, ToastSetup, enUS_AutoThank;
  Per-client features: a row for the `THANK_RAID_BUFFS` ids, Retail's three and Forever's derived ids or
  its hidden toggle (§12); Event Subscriptions: WHISPER_INFORM on `NS.addon`, UNIT_AURA on the unit-filter
  frame; Settings Schema `thank.*`; Taint Notes: the toast carries a secure child; Known Limitations;
  census),
  `docs/module-map.md`, `docs/compat-layer.md` (`AuraCaster`, `AuraByInstance`, `HelpfulAuraIds`,
  `WhisperName`), `docs/midnight-quirks.md` (UNIT_AURA payload secret; caster GUID and aura data secret
  when restricted), `docs/performance.md` (UNIT_AURA cost), `docs/schema.md` (`thank` block),
  `docs/taint.md` (the Thank button), `docs/known-limitations.md` (heuristic filter, three-buff allowlist,
  the in-fight diff, pad over toast, Forever's raid-buff ids per FRB), `docs/scope.md` (F2 rewrite of
  "Read combat-only data (auras)"), `docs/settings-panel.md` (the Auto-thank page), `docs/testing.md`,
  `docs/smoke-tests.md` (THANK-1..12 and FOREVER-26, the ids in the Pending sign-off roll-up sentence;
  THANK-2 records `GetPlayerInfoByGUID`'s name and realm for the stranger, the other half of R1; THANK-4
  also checks the emote form, `/thank Name-Realm` at a cross-realm caster on Retail and
  `/thank First-Surname` on Forever; THANK-12 is a friend's buff and a guildmate's buff under each mute
  setting, "Strangers" and "Friends and guild", which checks `C_FriendList.IsFriend(guid)` and
  `IsGuildMember(guid)` with a GUID), `docs/test-cases.md` + badge, `README.md` feature text
  (auto-thank), this plan.
- Commit: `CA-M4-15: Document auto-thank and add the THANK and FOREVER-26 smoke checks`

### CA-M4-16: M4 checkpoint

- Gate, push, Checkpoints row, ledger.
- Commit: `CA-M4-16: M4 checkpoint`, then push.

---

## M5: review, docs sync, PR, handover

### CA-M5-1: Whole-branch review

- Run the `dev-copilot:review` skill with `branch` (WoW review; it re-runs lint and tests). It writes a
  frozen bundle under `docs/reviews/<date>/`.
- Commit: `CA-M5-1: Whole-branch review of combined actions and auto-thank` (the bundle only).

### CA-M5-2: Review fixes

- One commit per finding or tight group, each subject `CA-M5-2: <fix>`, test first where the finding is
  behavioral. A finding that would deviate from the standard is surfaced, not fixed. The ledger row is
  done when the bundle's execution plan has no open item; list skipped findings with reasons in the
  checkpoint notes.

### CA-M5-3: Complexity and file-cap pass

- `bash tests/_kit/run-automated-tests.sh --suite complexity`: zero functions above CCN 15, `blindFiles`
  0, `crashedFiles` 0. Fix any over-limit function under this id. Confirm every authored file under 1500
  lines and the census current.
- Commit: `CA-M5-3: Hold every function at CCN 15 or under` (skip the commit if nothing changed; mark the
  ledger with the run's result).

### CA-M5-4: Docs sync

- Run `dev-copilot:sync-docs`, then check every §12 item is done, `docs/test-cases.md` regenerated, the
  README badge matches, and every §13 check sits under Pending sign-off.
- Commit: `CA-M5-4: Sync the docs to the branch`

### CA-M5-5: Final checkpoint and PR

- Gate; push; Checkpoints row `M5`; ledger.
- Commit: `CA-M5-5: Final checkpoint`, then push.
- Open the PR with `gh pr create --base master --head feat/2026-11-10-combined-actions` titled
  `Combined actions, pings, markers, message-and-emote built-ins and auto-thank (#16-#20)`. The body lists
  each issue's AC and how it is met, the gate totals, every row of "Owner rulings and builder calls"
  above, the unverified items (ACTION-4, ACTION-6, PING-1..3, MARK-1, MARK-6, MARK-7, THANK-2, THANK-4,
  THANK-7, THANK-12) and
  the smoke list. Do not merge.

### CA-M5-6: Owner smoke checklist handover

- No commit. Hand the owner the ordered list of new smoke checks (ACTION-1..8, PING-1..5, MARK-1..7,
  EMOTE-9, EMOTE-10, THANK-1..12, FOREVER-26), Retail then Forever, with the setup each needs, and the
  decisions each result feeds (R2 `MAX_MACRO`, R3 silent emotes, R4 Forever pings, R5 marking in combat,
  R1 caster readability, the Forever raid-buff ids). Merge waits on the owner's go-ahead after the pass.

## After merge

Only after the owner merges (or tells the run to):

- `git switch master && git pull`.
- Delete the branch: `git branch -d feat/2026-11-10-combined-actions` and
  `git push origin --delete feat/2026-11-10-combined-actions`.
- Stashes: `git stash list | grep ' CA-'`; drop each `<ID> partial` stash this run created, after checking
  its content landed (`git stash show -p`). Leave stashes the run did not create.
- Worktrees: `git worktree list`; remove any the run created (`git worktree remove <path>`), then
  `git worktree prune`.
- Update the auto-memory build-status note with the merge commit.

## Spec gaps found while planning

- **Forever raid-buff ids.** §9 says Forever's `THANK_RAID_BUFFS` is "to be filled" from wago `wowf` or a
  `/qc probe` aura read, and gives no ids. CA-M4-3 ships Retail's three and an empty Forever list, so on
  Forever `raidBuffsOnly` would toast nothing. Now an owner-rulings row (FRB, asked at the M3
  checkpoint): CA-M4-3 tries `tools/client_tables.py` first; if it cannot derive the ids, CA-M4-14 hides
  or disables the toggle on Forever. Either way the gap goes in known-limitations (CA-M4-15) and THANK-7.
- **Where M1 stops for the preview.** §1 puts "the preview" in M2, but a ping-only callout made in M1 must
  preview and `/qc check` sensibly. CA-M1-12 adds the single-action rows; CA-M2-6, CA-M2-9 and CA-M2-10
  add the list form.
- **`modules/Library.lua` is 1358 lines.** §2 adds three validators, `HasAction` and field-list entries;
  the spec does not plan for the cap. The file-cap rule above covers a split if needed.
- **The combat-edge hook for the diff (fixed in the spec).** Filing `SE.RunOrQueue` at the
  `PLAYER_REGEN_DISABLED` edge ran the diff at once (lockdown is still false there), and even `SE.Queue`
  was drained by the same edge's `RESTRICTION_CHANGED`; the toast's `Release` riding on `"thank.diff"`
  had the same fault, so D6 failed as written. §9 Combat now queues from `AT.OnAura` only in combat or on
  the edge, gives Hold and Release their own `RESTRICTION_CHANGED` receiver, and adds a
  `R.OnCombatEdge(false)` hook for the /reload-in-combat case (CA-M4-7, CA-M4-10). No new `NS.addon`
  event is added; a new pinned event would be flagged.
- **F2 and F3** are owner rulings already (R-B, D4) but the spec asks for confirmation; the plan asks at
  the M3 checkpoint, before M4.
