# Combined actions, pings, markers, message-and-emote built-ins and auto-thank (QuickComms#16 to #20)

The owner, 2026-11-10: "Lets build QC issues #16-20". The issues:

- **#16** Combine actions in one callout: a chat line, an emote, a ping and a raid marker. AC: "a callout can
  send 'Kick on me' in party, /point at the target, ping it and mark it, all on one press, on Retail and
  Forever."
- **#17** Ping callouts through the game's ping system and the secure button. AC: "places the chosen ping on
  Retail and Forever, including in combat."
- **#18** Raid target marker callouts through `/tm` and the secure button, honoring marking rights. AC: "marks
  the target on both clients, and says why when it cannot (no rights, no target)."
- **#19** Auto-thank buffers: a small LibKa0s toast names who buffed you and with what, with a one-click Thank
  button. AC: "open world stranger buff -> one toast; click sends /thank at them; unclicked fades. Raid-wide
  buff from five players -> throttled stack, not five toasts in a burst. Nothing for self-buffs or when off
  for that content kind."
- **#20** New default callouts that send a message and an emote together (depends on #16). AC: "fresh
  profile lists them, each sends line+emote on one press on both clients; existing profile gains them once,
  a deleted set stays deleted, edited callouts are left alone."

Built on `feat/2026-11-10-combined-actions`, branched from master at 37a1e7b. Baseline: 1780 passed, 0 failed,
1 skipped on both kit profiles; luacheck 0/0 over 172 files.

**Revision 2 (2026-11-11).** This revision applies the 19-point review of revision 1 and the owner's
rulings R-A and R-B. Each review point was checked against the repo and against the Blizzard UI source
for Retail (live) and WoW Forever (1.60.1). Where a point was only partly right, the text says so and
gives the evidence. The review's point 11 (#20's rows duplicate shipped callouts) is superseded by R-A.
Its point 18 question on `thank.enabled` is superseded by R-B.

## 1. Scope and the owner's rulings

The owner's rulings, quoted as given:

- **D1 (owner, O1, #16).** "FIXED SLOTS - four optional slots, each at most once, at least one set: Line
  (channel+text), Emote (token), Ping (type), Marker (icon). Fixed press order line, emote, ping, marker."
- **D2 (owner, O2, #17).** "ping TARGET ONLY (/ping [@target] <type>); no target -> the press says why."
  The bake writes the conditional as `[@target,exists]` (D12, §5). That is still target only.
- **D3 (owner, O3, #19 buff filter).** "HEURISTIC by default (helpful aura cast on you by another player,
  not you/pets/NPCs, lasting >= 60s, not from current party/raid members, per caster+spell cooldown) PLUS an
  'only known raid buffs' allowlist toggle."
- **D4 (owner, O4, #19).** "text line goes as a WHISPER to the caster (editable, {name}/{buff} tokens)."
- **D5 (owner, O5, #20).** "add the new message+emote callouts INTO THE EXISTING built-in sets (not a new
  set); the schema step inserts into groups the player may have edited; a deleted set stays deleted; edited
  callouts are left alone." R-A narrows this (below).
- **D6 (owner, O6, #19 combat).** "QUEUE UNTIL COMBAT ENDS - remember in-combat buffs (when the caster is
  readable) and toast them after the fight." §9 Combat says how this is done with the restricted payload.
- **D7 (owner, O7, #16 spam guard).** "ONE PRESS = ONE TICK; echo tracker expects one echo per chat-type
  action."
- **D8 (owner, O8, delivery).** "one branch feat/2026-11-10-combined-actions, milestone commits per issue
  (#17,#18 -> #16 -> #20 -> #19), pushed at milestones, one PR, merge only on owner go-ahead after their
  smoke pass."

The owner's rulings of 2026-11-11:

- **R-A (owner, #20).** "Add emotes to shipped ones."
  - The existing shipped callouts that fit a game emote gain that emote beside their line (§8).
  - New rows are added only where no shipped callout fits, and no set goes past 12 callouts.
  - The schema step adds the emote only to stored callouts that still carry their shipped origin and are
    unedited (defined exactly in §8). It leaves edited callouts alone, and it never brings back a deleted
    callout or set.
  - This replaces revision 1's list of 14 new rows.
- **R-B (owner, #19).** "ON BY DEFAULT, in the open world, for buffs from someone not in your party/raid.
  Other content kinds off by default."

**Builder call recorded with the rulings (D26).** LibKa0s Toast has no fade: a toast is hidden when its
time runs out (`libs/LibKa0s/Toast.lua:162-173` starts the timer, `dismiss` then hides the frame at
`:468`). The file has no alpha or fade code. So the builder adds an alpha fade-out, out of combat, and
#19's "unclicked fades" holds as written (§9 The toast).

Out of scope:

- a new built-in set (D5);
- shipped callouts that carry a ping or a marker (D24);
- any change to the addon version (CLAUDE.md);
- Share (removed, issue #12).

### Milestones

The milestones are, in order (D8). Each one's tests come before its code, and each one is pushed when it
is green.

- **M0: the locale split and the union gates (D9).**
- **M1: the slot model, with ping (#17) and marker (#18) as callout actions.** A callout holds one action
  in M1, and the editor is not changed yet (§2 M1 rule).
- **M2: combining (#16).** The multi-line bake, echo grouping, the editor and the preview.
- **M3: #20 content and schema step 20.**
- **M4: #19 auto-thank.**

### M0: the locale split (D9, builder call)

- **The cap.** `locales/enUS.lua` is 1474 lines, against the 1500-line cap (layout-§1,
  `tests/_kit/test_layout_cap.lua:109`). The census at `docs/ARCHITECTURE.md:424-429` says 1459, so it is
  stale. These issues add far more than 26 lines of strings.
- **The rule is already written.** localization-§6 ("Splitting a locale file at the cap") sets the shape.
  Revision 1's F1 (whether the standard allows a second base-locale file) is dropped, because §6 answers it:
  - `enUS.lua` keeps its name, and it is the only file that creates `NS.L`;
  - a topic file opens with `local _, NS = ...` and `local L = NS.L`, and only assigns keys;
  - `<Topic>` names the consumer, which is a source folder or a feature module;
  - every key lives in exactly one file. A shared key sits with its first reader in TOC load order.
- **The files.** Revision 1's `enUS_Actions` named no consumer, and it mixed BuiltIns names (read in
  `defaults/`), module strings and settings strings, so it is replaced by:
  - **`locales/enUS_Settings.lua`** holds the strings that only `settings/*` reads. M0 moves the existing
    settings-only keys out of `enUS.lua` into it. That makes room for the module strings that M1 to M4
    add, which stay in `enUS.lua`, because a module reads them first. The keys to move are listed by
    grepping every `L["..."]` reader, and a key that any file outside `settings/` reads stays put;
  - **`locales/enUS_AutoThank.lua`** (M4) holds the strings that only `modules/AutoThank*.lua` reads. The
    Auto-thank page's own strings go to `enUS_Settings.lua`. A string that both read stays with the module,
    because `modules/` loads before `settings/`;
  - #20's two new row names and texts are read first by `defaults/` (§8), so they stay in `enUS.lua`.
- **The TOC.** The topic files load directly after `locales\enUS.lua` (TOC line 39), contiguous with it.
  Each line carries the `LOAD-BEARING` comment that localization-§6 requires, for example
  `# LOAD-BEARING: fills NS.L, which locales\enUS.lua creates, at file load.` Revision 1 wrote
  `# Conventional:` here, which was wrong.
- **The union gates, which land in M0 before the split.** This repo has no locale coverage or dead-key gate
  of its own today. `tests/test_page_pads.lua:537` reads only `enUS.lua`, and `tests/test_harness.lua:33`
  pins only `files[1]`. The new suite `tests/test_locale.lua`, registered in `tests/run.lua`:
  - reads the list of enUS files from the TOC (`Loader.tocFiles`, as `tests/loader.lua:26` does), so the
    list cannot drift from it;
  - loads them in TOC order into one namespace, and reads `NS.L` raw (`rawget`) for coverage, so the
    key-on-miss fallback cannot answer for a missing key;
  - fails on a dead key: a key in any enUS file that no addon file reads. The reads counted are literal
    `L["..."]`; a key reached only by a dynamic read (`L[var]`, such as `L[r.textKey]` or a reason table
    indexed into `L`) goes in an explicit allowlist in the suite, with the reading file:line, and is never
    deleted as dead. At 37a1e7b there is no such read, so the allowlist starts empty;
  - fails on a key defined in more than one enUS file. The check reads the files' text, because last write
    wins in the loaded table;
  - widens `tests/test_page_pads.lua:537` to the union;
  - enforces placement both ways, from the split (M0) on: every `enUS_Settings.lua` key is read only under
    `settings/`, and every `enUS.lua` key has a reader outside `settings/`. M4 adds the same case for
    `enUS_AutoThank.lua`. A key only settings reads when it is added sits in `enUS_Settings.lua`, and the
    task that gives it a module reader moves it to `enUS.lua`.
- **Docs.** A row for each new file in `docs/module-map.md`, and the corrected census in the same commit.
  The census needs no over-cap row afterwards (localization-§6, "After the split").

## 2. The callout action model (#16)

### Storage (`QuickCommsDB.profile.callouts[<"cN">]`)

| Slot | Fields | Values | Absent means |
|---|---|---|---|
| Line | `channel`, `text` | `channel` is any kind in `NS.Channels.KINDS` except `gameEmote`; `text` is non-empty after `B.CleanText` | `channel == "gameEmote"`, or `text == ""` |
| Emote | `emote` | a token `^[%u%d_]+$` (`Lib.ValidEmote`, Library.lua:437) | `false` or `nil` |
| Ping | `ping` (new) | `"attack"`, `"warning"`, `"onmyway"` or `"assist"` | `false` or `nil` |
| Marker | `marker` (new) | an integer from 1 to 8 (1 star, 2 circle, 3 diamond, 4 triangle, 5 moon, 6 square, 7 cross, 8 skull) | `false` or `nil` |

- **D10 (builder call, for the owner to confirm): "no line" stays `channel = "gameEmote"`.** The
  relabel lives where the Channel labels live: `CHANNEL_LABEL` in `settings/SchemaMembers.lua:140` (the
  `callout.channel` values, so `tests/schema_pins.lua` is regenerated) and `SHORT_CHANNEL` in
  `settings/Groups.lua:226`, not in CalloutPopup.lua.
  - No new kind and no schema step. Every legacy game-emote callout (`channel="gameEmote"`,
    `emote=<token>`, `text=""`) then reads as "no Line, Emote set" as it stands. `Channels.IsKind` keeps
    passing for stored data.
  - The editor relabels the kind `L["None (no chat line)"]`, in place of the game-emote label.
  - The alternative is a new kind `"none"`, plus a step that rewrites `gameEmote` to it. It reads better in
    the data, but it adds a step and moves `Channels.KINDS`, `LOCKS.gameEmote` (Channels.lua:98), the pins
    and the tests, so it was not taken.
- An emote now sits beside any channel. Its lock is always `LOCKS.gameEmote`, whatever the callout's channel
  (§3).
- `Lib.TEMPLATES.callout` (Library.lua:953) gains `ping = false, marker = false`, so the boot check
  (Schema.lua:251-256) resolves the new member rows.
- **New member rows**, beside `callout.emote` in `settings/SchemaMembers.lua`:
  - `callout.ping`: `type="string"`, `default=false`, `values` = none plus the four types,
    `validate=Lib.ValidPing`. Its `normalize` maps `""` and `"none"` to false;
  - `callout.marker`: `type="number"`, `default=false`, `values` = none plus 1 to 8, with
    `|TInterface\TargetingFrame\UI-RaidTargetingIcon_<n>:0|t` labels, `validate=Lib.ValidMarker`. Its
    `normalize` maps 0 to false.

  Both mirror `callout.emote`. None of the three is reset-exempt (D11, builder call: an emote is not
  reset-exempt today, so all three action fields behave the same). `tests/schema_pins.lua` is regenerated
  in the same commit, with a header note.
- **The `callout.emote` row is reworded** (SchemaMembers.lua:180-188). An emote is no longer the "Game
  emote" channel's whole content. The new text:
  - comment: an emote's token, one of a callout's four actions (#16), performed after its Line;
  - `label`: `L["Game emote"]` (the existing key, kept). Not `L["Emote"]`: that key already labels the
    `emote` (/e) channel (SchemaMembers.lua:140, Groups.lua:226), and one key must not carry two meanings;
  - `desc`: `L["The game emote this callout performs, by its token (POINT) or command (/point), after its
    chat line if it has one. It acts on your target, as the game's own emote does."]`.

  The old desc key goes, and the dead-key gate (M0) proves nothing else reads it. `L["Game emote"]` stays
  as the field's label; once D10 relabels the channel (§7), the field label is its only reader.
- **Validation.**
  - `Lib.ValidPing(v)` and `Lib.ValidMarker(v)` are shaped like `Lib.ValidEmote`, and false or nil passes.
    `validCallout` (Library.lua:442) gains both checks.
  - **The "at least one action" rule is not put into `validCallout`.** `validCallout` gates every write
    through the seam. A stored callout with a chat channel, `text=""` and no emote is legal today, because
    `text` only has to be a string (Library.lua:445). If `validCallout` refused it, every later `/qc set`
    on that callout would fail. So the rule is a separate `Lib.HasAction(f)`, and it is applied:
    - in `Lib.CreateCallout` (Library.lua:474) and the popup's `check(d)` (§7), which refuse with the new
      reason `"noAction"`;
    - at the seam, only when a write would take away the last action of a callout that had one. A write
      that leaves an action-less legacy callout as it was still passes.

    The message is `L["Set at least one action: a line, an emote, a ping or a marker."]`. Each slot is at
    most once by construction, since each is one field.
  - test_library pins that a legacy empty-text callout stays editable, for example `/qc set callout.name`
    on one.
- **Every site that lists callout fields gains `ping` and `marker`:**
  - `Lib.CreateCallout` (Library.lua:474);
  - `copyCallout` (:488);
  - `seedCallout` (:719);
  - step 6's raw copy (Library_Migrate.lua:151);
  - in `settings/CalloutPopup.lua`: `DRAFT` (:58), `copyFields`, `put` and `seamValue`. These three keep the
    false-to-nil handling and also gain `emote`.

  `splitShared` copies the whole table and needs no change.
- **`BI.Callout(groupId, short, name, text, channel, glyph, color, extra)`** (defaults/BuiltIns.lua:30) gains
  `extra = { emote= }`, copied into `BI.callouts[id]`. `BI.Callouts` rows gain `r[6]` as `extra`.
  `BuiltIns_Emotes.lua` switches from its post-assign idiom (:19-20) to `extra`, with no data change. The
  `glyph` field stays in `BI.callouts` for the integrity tests, and it is never copied into a profile.
- **Seeded data is unchecked** (Library.lua:703-705), so `tests/test_builtins.lua` gains an integrity row:
  every `BI.callouts[*]` passes `validCallout` and `Lib.HasAction`, including `ping` and `marker`.

### M1 rule: one action per callout until M2

M1 ships the slot model and the two new actions without combining them:

- `Lib.HasAction` also counts actions, and M1 refuses a callout with more than one set action through the
  reason `"oneAction"`. This rule lives on the branch only, and M2's first commit removes it, with its test
  inverted.
- Legacy callouts already hold one action, either a Line or an Emote.
- A ping-only or marker-only callout is made through `/qc set callout.ping <id> attack` or
  `/qc set callout.marker <id> 8` on a callout whose Line is None.
- M1 adds `ping` and `marker` to `DRAFT`, `copyFields`, `put` and `seamValue`, so an editor Save keeps them,
  although the editor draws no control for them until M2.

## 3. The bake

- `B.Bake(callout, s, opts)` (modules/Bake.lua:77) keeps its contract and becomes the **Line action** bake.
  `B.CleanText` keeps flattening `%c` in user text (anti-pattern #20), so a newline never comes from data.
- **New `B.BakeActions(callout, s, opts)`** returns `macro, reason, info`:
  - `info.actions` is an ordered list of **every** set action, baked or not. Each entry is
    `{ kind, line, reason, concrete, chatType, lock, length, unknown, missing, selfPrint }`.
  - `info.baked` holds only the entries that baked (`line ~= nil`), in the same order;
  - `info.total` is the macro's budgeted length: the sum of each baked entry's `length` plus one byte for
    each `"\n"`. `#macro` is not used, because `B.Length` (Bake.lua:48-51) adds `NS.Tokens.LIVE_NOMINAL`
    for each live token, and the raw macro holds the token, not its expansion;
  - `macro` is `table.concat(<info.baked lines>, "\n")`, in the fixed order line, emote, ping, marker (D1).
    Only code joins the lines, and each line other than the Line comes from a fixed table.

| Kind | The line it bakes | `length` | `chatType` | Lock |
|---|---|---|---|---|
| `line` | today's `B.Bake` result, `<prefix> <text>` | `B.Length(text, live, prefix)` | `Channels.ChatType(concrete)` | `Channels.LockState(concrete, s)` |
| `emote` | `NS.Emotes.Command(token)` (today's `B.BakeEmote`) | `#line` | `"TEXT_EMOTE"` | `LOCKS.gameEmote` |
| `ping` | `Compat.PingCommand() .. " [@target,exists] " .. PING_NUM[type]`, where `PING_NUM = {attack="1", warning="2", onmyway="3", assist="4"}` | `#line` | none | none (D25) |
| `marker` | `Compat.MarkerCommand() .. " [@target,exists] !" .. n` | `#line` | none | none (D25) |

- **D12 (builder call).**
  - The ping line uses the numeric keyword. It is the same in every locale (`pingNameToTypeTable`,
    `Blizzard_ChatFrameBase/Mainline/SlashCommandsOverrides.lua:41-54`, VERIFIED in source on both
    clients).
  - The marker line uses `!N`, which sets the marker and never toggles it off (VERIFIED in source,
    `Blizzard_ChatFrameBase/Shared/SlashCommands.lua:1406-1412` live, and the same block at :1457-1463 on
    Forever). A second press therefore never unmarks the target.
  - **Both lines carry `exists` (review point 3, correct).** `SecureCmdOptionParse` answers `@target` with the
    unit token whether or not the unit exists, which is why macros write `[@mouseover,exists]`.
    - `/ping`'s own guard, `if not target and msg:find("%[.+%]") then return end`
      (SlashCommandsOverrides.lua:66-68), therefore fires only when a condition fails. With a bare
      `[@target]` and no target, the handler would call `C_Ping.SendMacroPing{ targetToken = "target" }`,
      which "will do it's best to come up with a target" (the comment at :63-65).
    - With `[@target,exists]` and no target, the option parse returns nil, and the guard returns.
    - `/tm` sets `target = "target"` when the parse gives none (SlashCommands.lua:1401-1404 live). With
      `exists`, the parse gives no marker either, so `if ( marker )` (:1424) skips `SetRaidTarget`.
- **Client detection.** New code in `core/Compat.lua` (842 lines today):
  - `Compat.PingCommand()`: `_G.SLASH_PING1`, read through `PlainString`, or nil when the global or
    `C_Ping` is absent;
  - `Compat.MarkerCommand()`: `_G.SLASH_TARGET_MARKER1`, read the same way.

  Both commands are localized (a Spanish client accepts `/aviso`). When a command is absent, that action
  does not bake: it gets the reason `"noPing"` or `"noMarker"`, the macro leaves it out, and the preview,
  tooltip and `/qc check` show the reason. This is the same rule as an unknown emote token, which drops
  only the Emote action.
- **Caps (D13, builder call, conservative).**
  - `B.MAX_BYTES = 255` stays the cap per line.
  - A new `B.MAX_MACRO = 255` caps the whole macro, measured as `info.total`. The wiki's
    SecureActionButtonTemplate page says 255 in total, and the 1023 figure on API_RunMacroText is stale.
    Neither is confirmed in game (ACTION-4).
  - The non-Line actions bake first. The Line's budget is then
    `min(MAX_BYTES, MAX_MACRO - (sum of the other baked lengths + one per "\n" the Line adds))`. When the
    Line's `B.Length` goes over it, the Line alone fails with `"tooLong"`, and the others still bake.
  - The editor and `/qc check` show `"%d of %d bytes"` for each line, plus `L["Macro: %d of 255 bytes"]`.
  - If ACTION-4 proves the cap larger, raising `MAX_MACRO` is a one-line change. That is recorded as the
    re-check trigger in known-limitations.
- **Partial bakes (D14, builder call).**
  - The macro holds every action that baked. The button arms when at least one action baked.
  - `reason` is set only when none baked. It is then the Line's reason if there was a Line, else the first
    action's reason.
  - Solo with the "self" fallback: the Line contributes no macro line, only `selfText`, and the other
    actions still arm.
- **Slot (`S.Slot`, Surfaces.lua:98-124).**
  - `slot.line` is the joined `macro`. The name is kept, so `SE.Arm`, `rebake` and the arm gate do not
    change.
  - **`slot.actions` holds only the baked actions** (`info.baked`), and so does `meta.actions`. The actions
    that did not bake go in `slot.skipped`, which the preview, the tooltip and `/qc check` read, so the arm
    gate and the press-time reasons never fire for an action that is not in the macro.
  - `slot.chatTypes` lists the `chatType` of each baked chat action. `slot.chatType` is kept as
    `slot.chatTypes[1]` for readers not yet moved. It is retired by the end of M2.
  - `slot.lock` is the first lock among the baked actions, and `slot.locks` lists each one. `lockdownChip`
    is set when any action's lock is `"lockdown"`.
  - **`slot.rebake`** (the `{coordinates}` press-time re-bake, SendEngine.lua:42-48) calls
    `B.BakeActions` and returns `macro, reason, info`. The re-bake refreshes `meta.actions`,
    `meta.chatTypes`, `meta.locks` and `meta.skipped` from `info`, so the echo tracker never waits for a
    Line that the new coordinates pushed over budget. If the Line dropped, the press prints its reason
    (`L["%s: the line is too long to send with its other actions."]`). If nothing baked, the old macro and
    meta stay as they were.
  - `Tokens.UsesCoordinates` still reads `callout.text`, the Line's text.
  - `S.RefreshLocks` (Surfaces.lua:542) relocks each action's concrete.
- **The arm gate** in `arm()` (Pad.lua:213) becomes
  `slot.line and slot.actions and #slot.actions > 0 and not preview`. A ping-only or marker-only callout
  arms.
- **Diagnostics.** `SE.Escaped` (SendEngine.lua:173) shows each `"\n"` as ` \n ` (a visible backslash and
  n), so the Diagnostics row (Diagnostics.lua:197) stays one row.

## 4. The send path

`press(b)` (SendEngine.lua:435-470) changes as follows. The meta from `arm()` gains `actions`, `chatTypes`,
`locks` and `skipped`.

1. No meta, or stood down: return (unchanged).
2. **`meta.echo` (a preview or a test) now comes before `meta.selfText`.** This order change is deliberate
   (review point 19). Today `selfText` prints and returns first (SendEngine.lua:439-442). A previewed press
   must print what every action would do, including the Line's self-print, and never act. So `meta.echo`
   prints one `NS.Print` per entry from `P.SlotEcho`, then returns (step 9). test_preview pins the new
   order.
3. `meta.selfText`: print it. Return only when `meta.actions` is empty, and otherwise go on.
4. The gate becomes `b.qcArmed and meta.actions and #meta.actions > 0`, in place of `meta.chatType` (:452).
5. **Press-time reasons (D15).** These are read in the PreClick hook and printed in the OnClick hook.
   - **Why PreClick (review point 4, correct).** The OnClick hook runs after the secure macro has run. By
     then the press's own ping may have started the ping cooldown, which would give a false "cooldown"
     reason.
   - `SE.PreClick` (SendEngine.lua:490) today returns at once in combat, because it only re-bakes. It is
     split:
     - on the acting edge, in and out of combat, it stores `b.qcPressNotes = SE.PressNotes(meta)`. These
       reads only read and never write an attribute;
     - the re-bake keeps its `inCombat()` early return.
   - `press()` prints `b.qcPressNotes` and clears them.
   - Every read goes through a Compat plain reader, because they run in combat. Each reader tests
     `IsSecret` first, and an unknown answer prints nothing. There is no raw `== false`.
   - For each baked ping or marker action:
     - `Compat.TargetExists()` plainly false prints `L["%s: no target to ping."]` or
       `L["%s: no target to mark."]`;
     - ping only: `Compat.PingState()` answers `"off"` when `C_Ping.IsPingSystemEnabled()` is plainly false
       or the `enablePings` CVar is off. It answers `"cooldown"` when `C_Ping.GetCooldownInfo().endTimeMs`
       is a plain number above `GetTime() * 1000`. That clock base is the one Blizzard's own ping UI uses
       (`Blizzard_PingUI/Blizzard_PingUI.lua:131-133`, `local nowMs = GetTime() * 1000`);
     - marker only: `Compat.CanMark("target")`, which is `CanBeRaidTarget` through `IsSecret`. Plainly
       false prints `L["%s: that target cannot be marked."]`;
     - marker only: `Compat.MarkerRights() == "noRights"` prints
       `L["%s: you need leader or assist to mark in a raid."]` (§6).
   - Each reason prints once per press, named with `meta.name`. New `REASON_TEXT` rows (Pad_Render.lua:137)
     are added for `noAction`, `noPing` and `noMarker`. The press-time texts are separate locale rows,
     because they describe the press, not the bake.
6. **Locks, for each action.**
   - A chat action whose lock says "may not have been sent" prints today's note and records no echo for that
     action.
   - If every baked action is a locked chat action, today's behavior is kept: print, then return with no
     tick and no echo.
7. **Guard (D7).** Exactly one `G.Decide`, one `State.lastSendAt = now` and one
   `qcOnPress(b, verdict, window)` per press, however many actions it has. A press with no chat action still
   ticks and dims.
8. **Echo (D7).**
   - Build `press = { need = <unlocked chat actions>, got = 0, done = false }`.
   - `G.Record(e, now, chatType, meta, press)` (SendEngine_Guard.lua:88) is called once per unlocked chat
     action. A Line and an Emote give two pending entries of different types, `PARTY` and `TEXT_EMOTE`, so a
     match is never ambiguous.
   - `G.Match` (SendEngine_Guard.lua:95) still takes the oldest pending entry of the chat type.
   - `OnSendEcho` increments `press.got`. When `got == need` and the press is not `done`, it sets `done` and
     emits one `SEND_RESULT "sent"`.
   - `G.Expire` (:114) emits one `"dropped"` per press: the first entry of a press to expire marks it
     `done`. Its drop note names the callout and the kind that dropped
     (`L["%s (emote) may not have been sent."]`).
   - `SE.EchoState().pending` keeps counting entries. `tests/test_sendengine.lua:265` keeps 1 for a
     Line-only press, and a new case pins 2 for a Line plus an Emote.
   - **D16 (builder call, for the owner to confirm).** A press whose baked actions are all pings or markers
     has nothing to echo, so it emits `SEND_RESULT "sent"` at once, and the button flashes as any press
     does. The flash is not a confirmation: a ping or marker the server refuses still flashes, and the
     press-time reason is the honest signal. This is recorded in known-limitations.
9. **Preview and test echo.**
   - `P.SlotEcho` (Preview.lua:484) returns a list with one entry per action, baked or skipped:
     - the Line, re-baked with the mock, as today;
     - `L["would emote %s"]` with the command;
     - `L["would ping %s on your target"]` with `L["Attack"]`, `L["Warning"]`, `L["On my way"]` or
       `L["Assist"]`;
     - `L["would mark your target %s"]` with `{rtN}` rendered as its texture;
     - a skipped action's reason text.
   - `P.FillEcho` fills `%t` in each entry. The press prints each entry with its own `NS.Print`: no raw
     `"\n"` inside one print, and no separator glyph for `test_glyphs` to catch.
10. **Encounter rule.** 12.0's macro chat restriction during instance encounters allows one message per group
    channel within a short window. A callout holds at most one Line, so a press sends at most one chat-type
    message, plus a token emote (`PerformEmote`, not `SendChatMessage`). Whether `PerformEmote` or `/ping`
    share that throttle is UNVERIFIED (ACTION-6).

## 5. Pings (#17)

- **Types and storage:** `ping ∈ {attack, warning, onmyway, assist}`, labeled `L["Attack"]`, `L["Warning"]`,
  `L["On my way"]` and `L["Assist"]`. `AlertNotThreat` and `AlertThreat` (keywords 5 and 6,
  SlashCommandsOverrides.lua:50-53) are left out, because the issue names four.
- **Target only (D2).** The line is always `/ping [@target,exists] <n>` (D12). With no target the option parse
  fails, and Blizzard's guard returns (`if not target and msg:find("%[.+%]") then return end`,
  SlashCommandsOverrides.lua:66-68, VERIFIED in source). Revision 1 said that a bare `[@target]` "returns
  silently". That was wrong, because `@target` with no condition always parses (D12). The press-time reason
  says why nothing happened (§4 step 5).
- **Path.** `/ping` is a secure slash command (`SlashCommandUtil.CheckAddSecureSlashCommand`,
  SlashCommandsOverrides.lua:55, VERIFIED). It runs from `SECURE_ACTIONS.macro`, which calls
  `C_Macro.RunMacroText` on an untainted click. No addon code calls `C_Ping.SendMacroPing`. The firewall test
  (test_sendengine.lua:201-211) is unchanged, and a new grep pins that no file names `C_Ping.SendMacroPing`.
- **Forever.** Forever ships `Blizzard_PingUI` and the same `/ping` handler (VERIFIED in source, build
  1.60.1.70888). Whether its servers deliver pings is UNVERIFIED (PING-3).
- **In combat:** it should work, since the secure path is the same (UNVERIFIED, PING-2). Solo or ungrouped
  pinging is UNVERIFIED (PING-1).
- **D25 (builder call).** No `LOCKS.ping` row. The encounter lockdown is not known to block `/ping`. If PING-4
  finds it blocked, a `LOCKS.ping` row is added, and that is the re-check trigger.
- **D17 (builder call).** `PING_SYSTEM_ERROR` is not registered. If PING-5 shows that the client prints
  nothing on a refused ping, registering it is a follow-up, and it would add a pinned event.

## 6. Raid target markers (#18)

- **Storage:** `marker` is 1 to 8. The bake is `SLASH_TARGET_MARKER1 .. " [@target,exists] !" .. n`.
- **The `/tm` path (review point 10, correct; revision 1 had it wrong).**
  - `/tm` is registered with `SlashCommandUtil.CheckAddSlashCommand`, not `CheckAddSecureSlashCommand`
    (SlashCommands.lua:1400 live, :1451 Forever). It is an ordinary Blizzard slash handler.
  - It still runs from Blizzard's own code inside the secure macro, on an untainted click.
  - `SetRaidTarget` has `HasRestrictions = true` on both clients (RaidMarkersDocumentation.lua:95-97 live,
    :114-116 Forever).
  - The `!` branch compares `GetRaidTargetIndex(target) == marker` (SlashCommands.lua:1410 live, :1461
    Forever), and `GetRaidTargetIndex` has `SecretReturns = true` (RaidMarkersDocumentation.lua:36-38 live,
    :55-57 Forever). That compare is in Blizzard's code, on the secure path. If the execution were tainted,
    or if 12.0 restricts marking in combat or during an encounter, the mark would not land.
  - That is unchecked, so the new **MARK-7** covers it: marking in combat and during an encounter, on both
    clients. #18's AC implies it.
  - `SECURE_ACTIONS.raidtarget` is not used, because a button carries one `type` and a combined callout must
    stay one macro.
- **Rights (VERIFIED on the wiki; the server enforces them):**
  - in a 5-player party, every member may mark;
  - in a raid, only the leader and assistants may mark, or everyone when `IsEveryoneAssistant()` is true.

  `Compat.MarkerRights()` is:

  ```lua
  local leader, assist = Compat.Leadership()          -- Compat.lua:109-113: two plain booleans
  if Compat.InRaid() and not (leader or assist) and not Compat.EveryoneAssistant() then return "noRights" end
  return "ok"
  ```

  Revision 1's `not Compat.Leadership()` read only the first return value, so an assistant read as having
  no rights. `Compat.InRaid()` and `Compat.EveryoneAssistant()` are plain readers (`plainTrue`, Compat.lua:76).
  Solo marking is believed to be allowed, and it is UNVERIFIED (MARK-1).
- **Reasons** (§4 step 5): no target, a target that cannot be marked (`CanBeRaidTarget`), and no rights. They
  print at the press. The rights reason is a press-time read, not a padlock: rights move with the roster, and
  the plan is not rebuilt on every roster change.
- **The 12.0 throttle.** Macros cannot mark more than 3 units within a very short time (VERIFIED,
  MMO-Champion). This goes in known-limitations, with no code.
- No addon code reads `GetRaidTargetIndex`, because `!N` makes that read unnecessary.

## 7. The editor (settings/CalloutPopup.lua and its readers; M2)

- **Layout:**
  - **Line 1:** Name | Channel (unchanged). The Channel list shows `gameEmote` as `L["None (no chat line)"]`.
  - **Line 2:** the Text box, hidden when Channel is None. The existing `isGameEmote` switch in `setField`
    re-renders.
  - **Line 3:** `L["Emote (optional)"]`, the `Pop.EmotePicker` at full width, always shown. Emptying the box
    sets `draft.emote = nil`. Today an empty set only refreshes.
  - **Line 4:** Ping | Marker, two dropdowns from the `callout.ping` and `callout.marker` member rows. Each is
    drawn with `h.RenderField(ctx, row, line, h.BUTTON_PAIR_REL)`, `split()` and `alignField()`, as Name |
    Channel are.
  - Then Icon, What it sends, Save | Cancel and the error line, as today. `fit()` sizes the window.
- `FIELDS` gains `"ping", "marker"`, so `draftRows()` binds them. `DRAFT` already has them from M1, after
  `"emote"`. The blank draft in `Pop.Open` (:579) gains `emote=nil, ping=nil, marker=nil`.
- **The R7 exclusion is removed:** `Pop.Save()` (:611) no longer clears `text` or `emote`. When Channel is
  None, Save writes `text = ""`, because a hidden box keeps nothing.
- **`check(d)` is split** to stay under CCN 15: `checkLine`, `checkEmote`, `checkPing`, `checkMarker`, then
  `Lib.HasAction` (`"noAction"`).
  - `checkLine` runs only when Channel is not None. It checks that `text` is non-empty, and that the Line's
    `B.Length` is at most 255 **bytes**. The caps are bytes (Bake.lua:12, :67), so revision 1's
    "characters" was wrong.
  - `checkEmote` runs only when an emote is set (its message is `L["Pick an emote from the list."]`).
  - Each failure names its field through `L["%s: %s"]`.
- **`C.PreviewLines(callout)`** (settings/Callouts.lua:85) calls `B.BakeActions`:
  - one row per action: `L["Sends: %s"]`, `L["Emotes: %s"]`, `L["Pings: %s"]`, `L["Marks: %s"]`, and a
    skipped action's reason;
  - the bytes for each line, plus the macro total;
  - one lock row per locked action;
  - for a ping or marker, the note `L["Needs a target when pressed."]`.

  `[1]` becomes a one-line summary, with the action rows joined by `", "` (for example `"Kick on me" in
  Party, /point, ping Attack, mark Skull`). `G.PreviewBlocks` (Groups.lua:~515) reads only `[1]`.
- **Groups:** `G.CalloutSummary(c)` (Groups.lua:254) and `calloutLabel` (:262) append short suffixes
  (`+/point`, `+ping`, `+{rtN}`). The edit tooltip at :502 reads `L["Edit its name, actions and icon."]`.
- **`PadRender.TooltipLines`** (Pad_Render.lua:192) shows one row per action, with the channel row for the
  Line only. `R.Veiled` is unchanged.
- **`V.CheckLines`** (`/qc check`, SlashVerbs.lua:24) prints one row per action,
  `"<kind>: <line>, %d of 255 bytes"`, then `L["macro: %d of 255 bytes"]`.
- `/qc set callout.ping <id> attack` and `/qc set callout.marker <id> 8` work through the seam with no extra
  code.

## 8. #20: shipped callouts gain an emote (R-A; M3)

### The list

- **Every token** is in `tests/emote_tokens.lua` under both `retail` and `forever`. The two
  ChatEmoteConstants files are byte-identical (the fixture's header, :1-6), and the list uses only the 20
  tokens the fixture holds.
- **No shipped line changes.** Each listed callout gains only `extra = { emote = <token> }` in its
  `BI.Callouts` row.
- The emote acts on your target, as the game's own does, and without a target it is addressed to no one.

| Set (id, name) | Callout id | Its line (unchanged) | Channel | Emote | Why it fits |
|---|---|---|---|---|---|
| `bi.world` Solo | `bi.world.rare` | Rare spotted: {target} @ {coordinates} | general | POINT | points at the rare you name |
| `bi.world` Solo | `bi.world.elite` | Can anyone help with this elite? {target} @ {coordinates} | general | HELPME | the voice line asks for help |
| `bi.world` Solo | `bi.world.thanks` | Thanks for the help! | general | THANK | |
| `bi.group` In Group | `bi.group.hello` | Hello! | smartGroup | WAVE | its glyph is the Emotes set's Wave glyph (ph:hand-waving) |
| `bi.group` In Group | `bi.group.ready` | Ready | smartGroup | READY | |
| `bi.group` In Group | `bi.group.glhf` | GLHF! | smartGroup | CHEER | |
| `bi.group` In Group | `bi.group.tyff` | tyff | smartGroup | THANK | "thank you for the food" |
| `bi.group` In Group | `bi.group.ggty` | ggty | smartGroup | THANK | "good game, thank you" |
| `bi.group` In Group | `bi.group.ggnt` | ggnt | smartGroup | BYE | "good game, good night" |
| `bi.mplus` Dungeon (and M+) | `bi.mplus.pull` | Pulling next pack | smartGroup | CHARGE | |
| `bi.mplus` Dungeon (and M+) | `bi.mplus.mana` | Wait, need mana | smartGroup | OOM | |
| `bi.raid` Raid (lead list) | `bi.raid.wipe` | Wipe it, run back | smartLead | FLEE | |

**New rows, only where no shipped callout fits.** Healing has no shipped callout in either set:

| Set | New id | Name | Line | Channel | Emote | Glyph, color | Placed after |
|---|---|---|---|---|---|---|---|
| `bi.mplus` Dungeon | `bi.mplus.healme` | `L["Heal me"]` | `L["Need heals!"]` | smartGroup | HEALME | gi:heart-plus, green | `bi.mplus.kicks` (the end) |
| `bi.raid` Raid (raid list) | `bi.raid.healme` | `L["Heal me"]` | `L["Need heals on me!"]` | raid | HEALME | gi:heart-plus, green | `bi.raid.stones` (the end of the raid list, before the lead list) |

- **Set sizes, against `DL.MAX_SLICES = 12`** (Dial_Layout.lua:53):

  | Set | Before | After |
  |---|---|---|
  | Solo | 7 | 7 |
  | In Group | 11 | 11 |
  | Dungeon | 7 | 8 |
  | Raid | 8 | 9 |

  No Auto dial gains a page.
- `L["Heal me"]` already exists (the Emotes set's `healme`, BuiltIns_Emotes.lua:37). `L["Need heals!"]` and
  `L["Need heals on me!"]` are new rows in `enUS.lua`, because `defaults/` reads them first. The glyph is
  one the catalog already ships.
- **Sets that gain nothing, and why.**
  - Arena and every battleground set: their snapshots carry `lockdown = { pvpMatch = true }`
    (BuiltIns_Arena.lua:21, BuiltIns_Battlegrounds.lua:21). `LOCKS.gameEmote = LOCKS.say` (Channels.lua:98),
    and `LOCKS.say` answers `"lockdown"` under `pvpMatch` (Channels.lua:91-93). So an emote there would
    print "may not have been sent" on every press.
  - The Emotes set: it is emotes alone.
  - The shipped callouts not listed: none of the 20 tokens fits them (rez, lust, summon, kick order and so
    on).
  - The M+ case is the Dungeon set, `bi.mplus`, whose When covers dungeons and keys (BuiltIns_MythicPlus.lua).
- **Review point 11's lock remark, checked.** Revision 1's review said the Dungeon snapshot is chat-locked
  (`lockdown.chat`), so the emote may fail in a key. That is only partly right:
  - `LOCKS.say` reads only `lockdown.encounter` and `lockdown.pvpMatch` (Channels.lua:91-93), never
    `lockdown.chat`. So outside a boss, in a key, the emote is not padlocked;
  - during a boss encounter it is, and so is any Say line. That case gets the per-action note (§4 step 6);
  - EMOTE-9 covers a key both outside and inside an encounter.
- **D24 (builder call).** No shipped callout carries a ping or a marker. Whether one should is left to the
  owner after the smoke pass, since a shipped marker press would mark targets in any group.
- **Tests:**
  - `tests/test_builtins.lua:505` widens from the Emotes set to every `BI.callouts[*].emote`, checked
    against the fixture under both kit profiles;
  - `:519` (each token bakes to the client's own command) widens the same way;
  - the In Group smart-group audit (:407) and the bake audit (:74) must pass with the emotes added;
  - a pin of the 12 emote additions and the 2 new rows, so a later edit to BuiltIns is a visible change.

### Step 20: `Lib.MigrateComboCallouts(profile)` (modules/Library_Migrate.lua)

- **Guard.** It returns at once unless `type(profile)=="table"`, `profile.seeded==true`, and `groups`,
  `callouts` and `nextId` are present and well-typed. An unprepared profile is left to `Prepare`, which
  seeds the full sets from the updated `BI` data.
- **Input: two frozen local tables, never read from `BI` at run time.** That way a later change to BuiltIns
  cannot change what step 20 recognizes:
  - `COMBO_EMOTES`: 12 rows of `{ origin, channel, textKey, emote }`, in shipped order, holding each
    listed callout's **pre-step** shipped values. For example
    `{ "bi.group.hello", "smartGroup", "Hello!", "WAVE" }`;
  - `COMBO_NEW`: the 2 new origins, each with its predecessor origin and its full field list (below).
- **Part 1: emotes on unedited shipped callouts.** For every stored callout `c` (`pairs(profile.callouts)`,
  `type(c)=="table"`), where `c.origin` names a `COMBO_EMOTES` row `r`, the callout is **unedited** when all
  of these hold:
  1. `c.channel == r.channel`;
  2. `c.text == L[r.textKey]`. The stored text was seeded as the localized string. A player who has since
     changed the client's language reads as edited and is left alone, which is the safe side;
  3. `c.emote == nil or c.emote == false`;
  4. `c.ping` and `c.marker` are nil or false.

  An unedited callout gets `c.emote = r.emote`. Nothing else is written.
  - **Name, icon and icon color are not compared.** R-A names "line/channel/emote", and a rename or a
    recolor does not change what the callout sends. This is a builder reading of the ruling, for the owner
    to confirm (F4).
  - A copy carries no origin (Library.lua:1244-1246 clears it), so a duplicated callout or set never gains
    the emote.
  - A callout the player deleted is not in `profile.callouts`, so nothing brings it back.
- **Part 2: the two new rows.**
  - **Which group.** For each `COMBO_NEW` row, the group is the one whose `origin` is the row's parent, the
    origin minus its last segment (`bi.mplus`, `bi.raid`). A profile holds at most one such group, because
    a copy's `origin` is cleared and only the original keeps it (Library.lua:1231-1246; `byOrigin`,
    Library.lua:132-139, picks the lowest id if stale data ever held two).
  - **Copies gain nothing**, nested copies included. Revision 1's "every match, nested copies included" was
    wrong, and its "nested copies gain" test is dropped. The Raid set's raid and lead lists are one group,
    not nested groups.
  - **The order.** Rows are processed in shipped order.
  - **The write.** If the group's callouts hold no callout with that origin, the step takes
    `id = takeCalloutId(profile)` (Library_Migrate.lua:102) and writes through `seedCallout`'s field list
    only: `{ name, text, channel, icon, iconColor, emote, ping, marker, origin }`. `seedCallout` itself is
    local to Library.lua and reads `NS.BuiltIns` at run time, so the step does not call it: it calls a
    frozen field writer in Library_Migrate.lua (`writeComboCallout(profile, row)`), whose values come from
    the frozen `COMBO_NEW` row (text, channel, icon, iconColor, emote), never from `BI` at run time. No
    `glyph` field is written: it is in `BI.callouts` for the integrity tests and not in
    `TEMPLATES.callout`.
  - **The place.** The new callout is inserted right after the callout whose origin is the row's
    predecessor, else appended. `placeAfter` (Library_Migrate.lua:463-475; :454 is `shippedBefore`)
    cannot be reused: it reads `profile.groups[id].origin`, so it only places groups on surface lists. The
    step adds a callout-list twin, `placeCalloutAfter(profile, list, cid, afterOrigin)`, that reads
    `profile.callouts[id].origin` (a non-table entry is skipped) and otherwise keeps `placeAfter`'s shape:
    a list that holds `cid` already is left as it is.
- **What this gives:**
  - **A deleted set stays deleted:** no group carries that origin, so nothing is added.
  - **A duplicated set gains nothing:** copies carry no origin.
  - **Edited callouts are left alone:** an edited one fails the unedited test, and nothing else in it is
    read or written.
  - **No deleted callout comes back:** part 1 writes only callouts that exist, and part 2 adds only the two
    origins that never shipped before.
  - **Sets this client does not ship gain nothing:** none of the listed sets is skipped on Forever
    (`SKIP_BUILTINS` is only `bi.arena`, GameIds_Clients.lua:111).
  - **A damaged group is skipped:** `callouts` must be a table.
- **D20 (builder call).** There is no callout-level "given" record (`seededCallouts`). The per-account
  `schemaVersion` stamp runs the step once, as it runs step 6.
  - Part 1 is idempotent: a callout that already has an emote is no longer unedited.
  - Part 2 is guarded by the origin it looks for.
  - A re-stamp could re-add a new row that the player deleted. That is accepted, because no import path
    exists. The re-check trigger is Share coming back (#12).
  - Revision 1 justified this with `defaults/Profile.lua` being "near its line budget". That was wrong: the
    file is 73 lines.

## 9. #19: auto-thank (M4)

### Files

| File | TOC place | Holds |
|---|---|---|
| `core/ToastSetup.lua` | under core, after GlowSetup | `NS.NewToast(d)`: sets `d.owner = addonName` and returns `LibStub("LibKa0s-Toast-1.0"):New(d)`, or `NS.ToastStub` (a table of no-op members) when the library is absent. DropWatcher's seam is the template. |
| `modules/AutoThank.lua` | after `modules\SendEngine.lua` and `modules\Situation.lua` | The pure decision functions (`AT.Accept(aura, caster, settings, now)`, `AT.Fill(text, name, buff, budget)`, `AT.Macro(caster, buff, settings)`), the unit-filter frame and its handler, the cooldown map, the known-aura set and the after-combat diff. It appends to `NS.STAND_DOWN` and `NS.STAND_UP`. |
| `modules/AutoThank_Toast.lua` | after AutoThank.lua | The toast host: `NS.NewToast{...}`, the builder and its fade, Hold and Release on the combat edge, the throttle pump, and the Bus targets |
| `settings/AutoThank.lua` | after `settings\Dials.lua`, before `settings\Profiles.lua` (which stays last) | `NS.SchemaRuntime.AddRows` for `thank.*`, and the sidebar page `L["Auto-thank"]` (D21) |
| `locales/enUS_AutoThank.lua` | after `locales\enUS.lua` and `enUS_Settings.lua` | The strings only `modules/AutoThank*.lua` reads (M0 rules) |

### Defaults (`defaults/Profile.lua`, `NS.C.PROFILE.thank`; AceDB merges them in, so no step is needed)

```lua
thank = {
    enabled = true,                  -- R-B: on by default
    content = { openWorld = true, dungeon = false, mythicPlus = false, raid = false, delve = false,
                scenario = false, battleground = false, arena = false, housing = false },   -- R-B
    send = "emote",                  -- "emote" | "line" | "both"
    text = L["Thanks for the {buff}, {name}!"],
    mute = "none",                   -- "none" | "strangers" | "known" (friends and guild)
    raidBuffsOnly = false,           -- D3's allowlist toggle
    position = false,                -- the toast's dragged spot; reset-exempt
}
```

R-B sets `enabled = true` and the open world alone. Every existing profile gains it through AceDB's merge,
and that is the owner's call.

Constants go in `core/Constants.lua`:

- `C.THANK.MIN_DURATION = 60` (D3);
- `C.THANK.COOLDOWN = 600`, the seconds per caster and spell;
- `C.THANK.GAP = 1.5`, the minimum seconds between two `Show` calls;
- `C.THANK.STACK = 3`;
- `C.THANK.MAX_QUEUE = 5`;
- `C.THANK.COMBAT_QUEUE = 10`, the most candidates the after-combat diff takes;
- `C.THANK.DURATION = 10`, the toast's seconds;
- `C.THANK.FADE = 2`, the last seconds over which the toast fades (D26).

### The event: the unit-filter frame (review point 8, correct)

Revision 1's D22 put `UNIT_AURA` on `NS.addon`. events-frames-taint-§1 carves out "The unit-filter frame"
for exactly this case, so D22 is replaced:

- **The frame.** `NS.AutoThank.frame` is a private `CreateFrame("Frame")`. Its only job is
  `NS.SafeRegisterUnitEvent(frame, "UNIT_AURA", NS.rejectedEvents, "player")` (CoreSetup.lua:68, :86) and
  one `OnEvent` that calls `AT.OnAura`.
  - It is held on the module, so teardown and the suites can reach it.
  - It is made once and re-used across a disable and enable, never rebuilt.
- **Registered only when needed.** `AT.Rewire()` registers the event when `thank.enabled` is on, the addon
  is not stood down, and `thank.content[NS.Situation.Current().content]` is on. Otherwise it unregisters
  the event.
  - It runs on `SITUATION_CHANGED`, `PROFILE_CHANGED`, a `thank.*` setting change, and `NS.STAND_UP`.
  - The default (open world only, R-B) therefore costs nothing in instances.
- **Teardown.** `NS.STAND_DOWN` runs `frame:UnregisterAllEvents()`, because AceAddon's `UnregisterAllEvents`
  does not reach this frame (events-frames-taint-§1). slash-commands-§7 and testing-§1 already require the
  teardown and the pin.
- **The unit filter removes the unit compare.** Revision 1's first line, `unit ~= "player"`, compared a
  value that may be secret. The `UNIT_AURA` payload is `SecretWhenAurasRestricted = true` as a whole
  (UnitAuraDocumentation.lua:643-650 live, :647-654 Forever), so that compare is gone.
- **Pins.** `test_disabled` `PINNED` does **not** gain `UNIT_AURA`, because the event is not on `NS.addon`.
  The suite pins the frame through the mock's `__unitEvents` record (`tests/_kit/mock_base.lua:239`):
  `UNIT_AURA -> { "player" }` while the feature is on in the open world, and nothing while it is off, in a
  dungeon, or stood down.

### Detection (D3)

`AT.OnAura(_, updateInfo)`:

1. Return when `NS.IsStoodDown()`, or when `Compat.InCombat()` or the combat edge is set
   (`State.combatEdge`, Restrictions.lua:171). In combat, set `State.thankDirty = true` and return (see
   Combat).
2. If `Compat.IsSecret(updateInfo)` or `type(updateInfo) ~= "table"`, set `State.thankDirty = true` and
   return. Nothing is indexed before this test.
3. **A full update** (`updateInfo.isFullUpdate` plainly true) re-snapshots `State.thankKnown` quietly and
   toasts nothing, so login, zoning and reloads never burst.
   - `isFullUpdate` and the payload are `Nilable = false` on both clients (UnitConstantsDocumentation.lua:60;
     UnitAuraDocumentation.lua:649 live, :653 Forever).
   - Revision 1's "Forever may send nil" was guesswork. The `type(updateInfo) ~= "table"` test stays, but
     only as a defensive guard.
4. `removedAuraInstanceIDs` (plain numbers) leave `State.thankKnown`.
5. For each `addedAuras[i]` that is a plain table, its plain `auraInstanceID` joins `State.thankKnown`. The
   aura is a candidate when it passes `AT.Accept` (below). A secret entry sets `State.thankDirty`.

**`AT.Accept(aura, caster, settings, now)` rejects unless all of these hold:**

- `isHelpful` is plainly true;
- **`isFromPlayerOrPlayerPet` is plainly true** (review point 1, correct). The field is the old `UnitAura`
  `castByPlayer` (`AuraUtil.UnpackAuraData` returns it in slot 13, AuraUtil.lua:57). It is true for an aura
  cast by **any** player or player pet, not only by you. Revision 1 required it to be false, which would
  have dropped every stranger's buff. Self and pets are rejected by GUID (below);
- `caster` is non-nil (`Compat.AuraCaster`, below), which already rejects self, NPCs, pets and group members;
- `duration` is a plain number `>= C.THANK.MIN_DURATION`, which also rejects 0 (no expiry) (D23, builder
  call);
- `raidBuffsOnly` is off, or `spellId` is in `NS.GameIds.THANK_RAID_BUFFS`;
- `mute` passes: `"strangers"` drops a caster with `caster.known == false`, and `"known"` drops one with
  `caster.known == true`;
- `now - cooldown[caster.guid .. ":" .. spellId]` is at least `C.THANK.COOLDOWN`.

**`Compat.AuraCaster(auraInstanceID, aura)`: GUID first, `sourceUnit` second (review point 2, correct).**

1. `guid = PlainString(C_UnitAuras.GetAuraCasterGUID("player", auraInstanceID))`.
   - The function exists on both clients (UnitAuraDocumentation.lua:171-187), with
     `SecretArguments = "AllowedWhenTainted"`. It gives the caster's GUID with no unit token, which is
     revision 1's R1 problem.
   - It is `SecretWhenUnitAuraRestricted`, and `PlainString` drops a secret answer.
   - The fallback, when it is nil: `aura.sourceUnit` as a plain string, then `PlainString(UnitGUID(sourceUnit))`.
2. `guid:find("^Player%-")`. This rejects NPCs (`Creature-`), pets (`Pet-`) and vehicles.
3. `guid ~= PlainString(UnitGUID("player"))`. This rejects self.
4. `C_PartyInfo.IsGUIDInGroup(guid)` (PartyInfoDocumentation.lua:420, both clients) plainly true rejects a
   group member. A secret answer reads as "in group", which is the safe side.
5. `name, realm` are the 6th and 7th returns of `GetPlayerInfoByGUID(guid)`
   (PlayerScriptDocumentation.lua:675 live, :837 Forever; `SecretArguments = "AllowedWhenTainted"`), read
   through `PlainString`. A nil name means unreadable, and the aura is dropped.
6. `known = C_FriendList.IsFriend(guid) or IsGuildMember(guid)`, through `plainTrue`. Both exist on both
   clients (FriendListDocumentation.lua:219 live, :229 Forever; `IsGuildMember` is used with a GUID in
   Blizzard's `SocialQueue.lua:204`).
7. `whisperName = Compat.WhisperName(name, realm)` (below).

It returns `{ guid, name, whisperName, known }`, or nil when any needed read is nil or secret. The cooldown
key is the GUID. `Compat.Relation` from revision 1 never existed, and it is replaced by `known`.

**`Compat.WhisperName(name, realm)` (review point 6, correct).**

- **The form is chosen by `Compat.RegionalNames()`** (Compat.lua:147-149, feature detection, clients-§3),
  never by "Retail or Forever".
- **With regional names** the name is "First Surname". The space is replaced by `-`, giving "First-Surname".
  - Forever's `ExtractTellTarget` accepts the hyphen form through its `RegionalUniqueNamesEnabled()`
    pattern (`Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua:84-90` Forever).
  - It accepts the space form only when `C_AutoComplete` knows the name (:96-108), and a stranger is not in
    AutoComplete.
- **Otherwise** it is `name .. "-" .. realm`, with spaces and hyphens stripped from the realm (the
  normalized form, as `GetNormalizedRealmName` gives it), or `name` alone when `realm == ""` (same realm).
  - Live `ExtractTellTarget` (ChatFrameEditBox.lua:82-108 live) splits the target at the first whitespace
    unless AutoComplete knows the name.
  - So `/w Bob-Argent Dawn hi` would whisper "Bob-Argent" the text "Dawn hi".
- Revision 1's `Compat.UnitWhisperName(unit)` (`GetUnitName(unit, true)`) is dropped, because the GUID path
  needs no unit.

**`NS.GameIds.THANK_RAID_BUFFS`** is per client in `defaults/GameIds_Clients.lua`:

- Retail: Arcane Intellect 1459, Power Word: Fortitude 21562 and Mark of the Wild 1126.
- **Trimmed (review point 15, correct).** Battle Shout, Skyfury and Blessing of the Bronze reach only the
  caster's own party or raid. D3 drops group members, so with `raidBuffsOnly` on they could never toast.
  Arcane Intellect, Fortitude and Mark of the Wild can be cast on any friendly player, so a stranger can
  give them to you.
- Forever: to be filled from its client tables (wago `wowf`, through `tools/client_tables.py`, which exists),
  or from a `/qc probe` aura read. With an empty Forever list, the raid-buffs-only toggle (D3) would show
  nothing at all on Forever, so if no ids are derived the toggle is hidden or disabled on Forever (the
  owner rules which, at the M3 checkpoint) and the gap is a known limitation.

Every id is UNVERIFIED until THANK-7.

### Combat (D6), with the restricted payload

While auras are restricted, the payload is secret, and so is every read of it. Revision 1 said that
`auraInstanceID` is NeverSecret. That is unsupported: only the GetAura* functions' `unit` arguments carry
`NeverSecret` (UnitAuraDocumentation.lua:93, :198, :235, :253 live). So D6 is done by a diff after the
fight, not by a queue of ids:

- **`State.thankKnown`** is the plain set of the player's helpful `auraInstanceID`s.
  - It is re-snapshotted silently when the frame is registered and on a full update.
  - It is kept up to date from plain payloads out of combat.
  - The snapshot reads `C_UnitAuras.GetUnitAuraInstanceIDs("player", "HELPFUL")` (UnitAuraDocumentation.lua
    :473-491 live, :475 Forever), through the new `Compat.HelpfulAuraIds()`. If any element is secret, it
    answers nil.
- **Nothing is filed at the `PLAYER_REGEN_DISABLED` edge.** Filing `SE.RunOrQueue("thank.diff", AT.Diff)`
  there would not wait for the end of combat:
  - at that edge `InCombatLockdown()` is still false (`Compat.InCombat`, Compat.lua:590), so
    `RunOrQueue` (SendEngine.lua:301-308) runs the diff at once;
  - even `SE.Queue` would not hold it, because the same edge sends `RESTRICTION_CHANGED`, and
    SendEngine's `onRestrictionChanged` (SendEngine.lua:535-539) drains the queue while lockdown is
    false.
- **In combat**, and whenever the payload is secret, the handler sets `State.thankDirty` (Detection steps 1
  and 2). When `Compat.InCombat()` is true, or `State.combatEdge` is set, `AT.OnAura` also files
  `SE.Queue("thank.diff", AT.Diff)` (not `RunOrQueue`). That runs after the edge's own drain, so the entry
  waits. `AT.Diff` itself returns, still dirty, while `Compat.InCombat()` or `State.combatEdge` holds, so
  an early drain in the edge window does nothing.
- **The host's own `RESTRICTION_CHANGED` receiver** (on the AutoThank Bus target, the pattern of
  SendEngine.lua:535-539): when `NS.Restrictions.InCombat()` is true it calls `toast:Hold()`; when it is
  false and `Compat.InCombat()` is false, it calls `toast:Release()` and then `AT.Diff()` when
  `State.thankDirty` is set.
- **After combat.** `SE.Drain` runs the queued diff. `R.OnCombatEdge` calls `SE.Drain` directly on the
  `PLAYER_REGEN_ENABLED` edge (Restrictions.lua:166-174). `R.OnCombatEdge(false)` (Restrictions.lua:170-174)
  also gains a hook, after `State.combatEdge` is cleared: `NS.AutoThank.OnCombatEnd()` when the module is
  loaded, which releases the toast and diffs when dirty.
  - That hook covers the case Restrictions.lua:166-169 warns about: after a login or /reload in combat,
    `RESTRICTION_CHANGED` may never be sent at the end of combat. So no part of #19 (neither the diff nor
    the toast's `Release`) waits on that message alone.
  - A `RESTRICTION_CHANGED` with nothing restricted also runs `AT.Diff` when `State.thankDirty` is set,
    which covers restrictions that lift outside combat.
- **`AT.Diff()`:**
  1. read `current = Compat.HelpfulAuraIds()`. If it is nil (still restricted), it stays dirty and returns;
  2. the candidates are `current` minus `State.thankKnown`, the newest `C.THANK.COMBAT_QUEUE` first;
  3. for each one: `C_UnitAuras.GetAuraDataByAuraInstanceID("player", id)` (through
     `Compat.AuraByInstance`), then `Compat.AuraCaster`, then `AT.Accept`. An aura that has expired, or whose
     caster cannot be read, is dropped quietly. This is how "when the caster is readable" applies;
  4. `State.thankKnown = current`, and `State.thankDirty = false`.
- **Known limitation:** a buff gained and lost inside one fight is never seen. The 60-second minimum makes
  that rare.

### The toast (LibKa0s-Toast-1.0, adopted here for the first time)

- `NS.NewToast{ name = "QuickCommsThankToast", build = buildThank, duration = C.THANK.DURATION,
  stack = C.THANK.STACK, stackGrow = "UP", maxQueue = C.THANK.MAX_QUEUE, draggable = true,
  getPosition/setPosition = thank.position, defaultPosition = { "TOP", 0, -180 } }`.
- **Combat-lockdown hazards (review point 5, correct).** The Thank secure button is parented to the toast
  frame. Once that is so, a `Hide`, `SetPoint` or `StartMoving` on the frame in combat moves a protected
  child, so it is blocked (frame-layering-§4's Combat bullet). The library does all three on its own:
  - the timer's `dismiss` and `takeDown` hide the frame (Toast.lua:162-173, :461-468);
  - a hover's `resume` restarts the countdown when the pointer leaves (:188-195), which defeats `Pause()`;
  - a right-click and the close mark go through `dismiss` (:321-323, :332);
  - `reflow` and `applyLayout` call `SetPoint` (:222-246, :277), and a drag calls `StartMoving` (:306);
  - `present` runs the builder, whose `SE.NewButton` returns nil in combat (SendEngine.lua:80-83).

  So no toast may be on screen in combat, and the host keeps to these rules:
  - every host `Show` and every step of the GAP pump is gated on `not InCombatLockdown()`. Out of combat it
    calls `Show`, and in combat it keeps the payload in its own pending list;
  - at the `PLAYER_REGEN_DISABLED` edge, which is synchronous and still writable, it always calls
    `toast:Hold()` with no `keepShown`, from its `RESTRICTION_CHANGED` receiver when
    `NS.Restrictions.InCombat()` is true (Combat, above). Every toast on screen goes back to the queue with
    its full time (Toast.lua:595-600), and nothing shows until `Release`;
  - it never calls `Hold(true)` or `Pause()` in lockdown. Revision 1's "Hold(true) + Pause() if already in
    lockdown" branch is removed. It was unsafe, and it was also moot, because no toast survives a /reload;
  - after combat, `toast:Release()` runs from that receiver when nothing is restricted and lockdown is
    false, or from the `R.OnCombatEdge(false)` hook, before the diff's own `Show` calls. It is not tied to
    the drained `"thank.diff"` entry, which would drain at combat start (Combat, above).
- **`buildThank(frame, payload)`** runs only from `present`, and so only out of combat (above):
  - the aura's icon;
  - `L["%s buffed you with %s"]`, filled with the name and the buff;
  - **the Thank button is made once per pool frame**, the first time that frame is drawn:
    `if not frame.qcThank then frame.qcThank = SE.NewThankButton(frame); toast:Attach(frame.qcThank) end`.
    `Attach` HookScripts the button (Toast.lua:624-628, `hookPointer` with `set = false`, :314-324), so
    calling it on every reuse would pile up hooks without bound. It is called once, when the button is
    made;
  - `SE.Arm(frame.qcThank, payload.macro, meta)`, with
    `meta = { kind = "thank", name = L["Thank"], calloutId = payload.key, surfaceId = "thank", actions, chatTypes }`;
  - the fade (D26, below).
- **The fade (D26, builder call).** The library has no fade (§1), so the builder adds one:
  - On the frame's first build, the host hooks `OnUpdate` once (`frame.qcFadeHooked`). On each draw it sets
    `frame.qcDue = GetTime() + C.THANK.DURATION` and `SetAlpha(1)`.
  - `OnUpdate` returns at once in combat (`InCombatLockdown()`). While `frame:IsMouseOver()` it pushes
    `qcDue` forward by the elapsed time and keeps alpha at 1. This mirrors the library's hover pause, which
    also covers the attached button, because the button sits inside the frame.
  - When the pointer leaves with less than one second left, it sets `qcDue = now + 1`, mirroring the
    library's `MIN_RESUME = 1` (Toast.lua:87, :194).
  - Otherwise it sets alpha to `max(0, min(1, (qcDue - now) / C.THANK.FADE))`.
  - The library's own timer then hides the frame at the same moment.
  - `OnUpdate` fires only while the frame is shown, so a hidden toast costs nothing.
- **The throttle (AC "five players → a throttled stack"):**
  - a cooldown per caster and spell;
  - at least `C.THANK.GAP` between `Show` calls, through a host timer pump gated on lockdown;
  - at most `C.THANK.STACK` toasts on screen at once;
  - `maxQueue` drops the oldest waiting toast;
  - `opts.key = guid .. ":" .. spellId`.
- After a click, `toast:Remove(key)` runs through `SE.RunOrQueue`.
- **Strata and placement.** The toast's strata is the library's HIGH (`lib.STRATA`, Toast.lua:82, the T5
  alert tier). A comment in `C.LAYERS` (Constants.lua:86) records it, and addon code makes no
  `SetFrameStrata` call. Revision 1 cited Constants.lua:397, which is blank.
  - Pads sit at DIALOG (`C.LAYERS.STRATA.HUD`, Constants.lua:88), above HIGH, so a pad placed over the
    toast's spot covers it.
  - The default spot, TOP 0,-180, is clear of the default pad, which sits at CENTER 0,-150
    (`DEFAULT_POINT`, Pad.lua:53).
  - The toast is draggable, and known-limitations notes the overlap.

### The Thank button (D4; the only secure writer is SendEngine)

- **New `SE.NewThankButton(parent)`**, in `modules/SendEngine.lua`, is `SE.NewButton(parent, nil)` followed by
  `RegisterForClicks("LeftButtonUp", "LeftButtonDown")` and `b.qcLeftOnly = true`. A right-click
  (Attach's dismiss) then never runs the macro.
- **Its press has its own path (review point 14, correct).** `press()` branches on `meta.kind == "thank"` to
  `pressThank(b, meta)`:
  - **no `G.Decide` and no `State.lastSendAt`**, so a Thank click never marks the next pad press as
    "guarded";
  - a non-nil `calloutId` (the toast key) and `surfaceId = "thank"`. The Pad and Dial `SEND_RESULT`
    receivers find no button of theirs for it, and a test pins that a Thank result touches no pad or dial
    button;
  - **its own lock read.** The whisper is locked when `Compat.InChatMessagingLockdown()` (Compat.lua:597) is
    true. The emote is locked when `Channels.LockState("gameEmote", NS.Situation.Current())` answers. A
    locked action prints `L["%s may not have been sent. %s"]` and records no echo;
  - the echo tracker records one pending entry per unlocked chat action, as §4 step 8 does.
- **`AT.Macro(caster, buff, settings)`** builds, in order:
  - `"emote"`: `NS.Emotes.Command("THANK") .. " " .. caster.whisperName`;
  - `"line"`: `_G.SLASH_WHISPER1 .. " " .. caster.whisperName .. " " .. AT.Fill(text, name, buff, budget)`;
  - `"both"`: the emote, `"\n"`, then the line.
- **The budget (review point 7, correct).** The whole macro is held to `B.MAX_MACRO`. The line's text budget
  is `B.MAX_MACRO - #prefixPart - (#emoteLine + 1 in "both")`, and never more than `B.MAX_BYTES`.
  - `AT.Fill` substitutes `{name}` and `{buff}`, runs `B.CleanText` (no control bytes) and doubles `|`.
  - It then cuts the result to the budget at a UTF-8 character boundary, never inside a multi-byte
    character or a doubled pipe.
  - The tokens are filled when the toast is built, so the lengths are exact, with no `LIVE_NOMINAL`.
- **Refusals.**
  - A text that starts with `/` is refused, as a Line's is.
  - **An empty filled text is refused** (a bare `/w Name` sends nothing). In `"line"` mode the button is
    then not armed, and the toast says `L["Nothing to whisper: the thank-you text is empty."]`. In `"both"`
    mode only the emote is baked.
- **Echo.** `G.CHAT_TYPE_BY_EVENT` gains `CHAT_MSG_WHISPER_INFORM = "WHISPER"`. `OnSendEcho` treats
  WHISPER_INFORM as `fromMe = true`, since its sender is the recipient. This pins a new event in
  `test_disabled` `PINNED` and in `G.ECHO_EVENTS`. The emote's echo is `TEXT_EMOTE`. With `"both"`, one
  press records two pending entries and gives one result (§4 step 8).
- **Whisper as a callout channel stays refused.** `tests/test_library.lua:119`, the owner's ruling on issue
  #7, still holds. The auto-thank whisper is D4's separate owner ruling, recorded in the test comment.

### Settings page (D21, builder call: its own sidebar page)

The page is built on the `buildGeneralPage` pattern (Panel.lua:239), with `pageKey="autothank"`, a Defaults
button, and `RegisterOptionsPage` stubbed when the library is absent (`settings/OptionsSetup.lua:80`). It has these
headings:

- **General:**
  - `thank.enabled`;
  - `thank.send` (Emote, Whisper, Both);
  - `thank.text`, with the token help `L["{name} is the caster, {buff} the buff."]`;
  - `thank.mute` (No one, Strangers, Friends and guild).
- **Where:** one checkbox per content kind, built from `NS.Resolver.TOKENS.content` and labeled through
  `NS.PadRender.CONTENT`. Kinds in `NS.GameIds.HIDDEN_CONTENT` are hidden on this client. The
  `contentValues()` builder (Groups_When.lua:209) is lifted to a shared helper. A change re-runs
  `AT.Rewire()`.
- **Filter:** `thank.raidBuffsOnly`, with a description that names the heuristic and says the allowlist holds
  only buffs a stranger can give you.

`position` is reset-exempt. Every default references `NS.C.PROFILE.thank`. `tests/schema_pins.lua` and
`tests/test_layout.lua` gain the page.

## 10. Schema

- **Step 20** (M3): `{ to = 20, perProfile = true, run = function(_, profile)
  NS.Library.MigrateComboCallouts(profile) end }` in `core/Database.lua` `NS.MIGRATIONS`, after step 19,
  with a comment. `NS.SCHEMA_VERSION` (Database.lua:86) follows it to 20.
- `ping` and `marker` need no step, since absent reads as none (the QFE-E2 precedent). `thank.*` needs no
  step, since AceDB merges it in.
- **Pins that move from 19 to 20:**
  - `tests/test_builtins.lua:198`, with its comment at :193-197 rewritten, because step 20 does touch
    prebuilts;
  - `tests/test_anim_styles.lua:337-338`;
  - `tests/test_profile.lua:56` and `:146`.
- **The step 19 test** (`tests/test_database.lua:580-640`) replays from 18, so step 20 runs too.
  - Its Solo-copy count (`#p.groups.g1.callouts == 1`) is unchanged, because Solo gains no row.
  - Its `originCount` checks are re-read for the Dungeon and Raid rows.
  - Any Solo callout it seeds unedited now carries its emote.

## 11. Tests to add or change

- **test_locale (new, M0):**
  - TOC-derived enUS file list;
  - raw coverage over the union;
  - dead keys over the union;
  - no key in two files;
  - each topic file's TOC line carries `LOAD-BEARING`;
  - placement both ways (`enUS_Settings.lua` read only under `settings/`; each `enUS.lua` key read outside
    it), and the dynamic-read allowlist.
- **test_bake:**
  - `BakeActions` keeps the order line, emote, ping, marker;
  - each line comes from code: no data byte follows a `"\n"`;
  - the ping keyword is numeric, and both the ping and the marker lines carry `[@target,exists]`;
  - the marker line uses `!N`;
  - an absent `SLASH_PING1` or `SLASH_TARGET_MARKER1` gives `noPing` or `noMarker` and drops only that
    action;
  - `info.total` counts `LIVE_NOMINAL` per live token, plus the newlines;
  - the Line budget is `MAX_MACRO` minus the others, so a Line over it fails `tooLong` while the rest bakes;
  - `info.baked` holds only what baked, and `info.actions` holds all;
  - a partial bake arms the rest;
  - every action failing returns the Line's reason.

  The header and `:1`, `:26-29` are rewritten: one line per action, and never a newline from data.
- **test_surfaces:**
  - `slot.actions` and `meta.actions` hold only the baked actions, and `slot.skipped` holds the rest;
  - a `{coordinates}` re-bake that pushes the Line over budget refreshes `meta.chatTypes` (no false
    "dropped");
  - a re-bake where nothing bakes keeps the old macro.
- **test_library:**
  - `ValidPing` and `ValidMarker`;
  - `noAction` on create;
  - a legacy empty-text, no-emote callout stays editable through the seam;
  - a seam write that clears the last action is refused;
  - `CreateCallout` and `copyCallout` carry `ping` and `marker`;
  - a legacy gameEmote callout still validates;
  - M1 only: `"oneAction"`, inverted in M2.
- **test_callout_popup:**
  - the four slots;
  - None hides Text;
  - clearing the emote;
  - Save keeps an emote beside a Line;
  - `noAction` names itself;
  - `checkLine` counts bytes;
  - the `DRAFT` and `FIELDS` pins.
- **test_sendengine:**
  - a Line plus an Emote gives pending 2 and one "sent";
  - #16's AC press: "Kick on me" in Party plus POINT, ping Attack and marker 8 gives `sentLines` of 4 lines
    in the order line, emote, ping, marker, one `G.Decide`, one `lastSendAt`, pending 2 and one "sent", in
    combat and under the forever kit profile;
  - one expired entry gives one "dropped" for the press;
  - a ping-only press ticks once and emits "sent";
  - a locked Line plus an Emote prints the note and records only TEXT_EMOTE;
  - the press-time reasons (no target, no rights, an assistant has rights, cannot be marked, pings off, and
    cooldown read in PreClick before the macro);
  - a secret `UnitExists` prints no reason;
  - `meta.echo` prints before `selfText`;
  - in combat, the macro runs through `sentMacros` with `m.blocked` empty.
- **test_send_guard:** grouped presses, and the WHISPER_INFORM row.
- **test_emotes:** the game-emote cases re-run as an Emote slot beside a Line.
- **test_preview and test_check:** one echo row and one check row per action, skipped actions included. The
  exact macrotext pins (test_preview :157, :433, :584; test_surfaces :254) are re-checked.
- **test_builtins:**
  - integrity of `ping`, `marker` and `HasAction`;
  - every seeded emote token in the fixture on both clients;
  - the 12 emote additions and the 2 new rows present on a fresh profile, on both kit profiles;
  - no set over 12 callouts;
  - the bake audit runs `B.BakeActions`, not only `B.Bake`: under each set's snapshot every action bakes
    and none is skipped, `info.total <= B.MAX_MACRO`, and no action carries a lock;
  - one built-in press (for example `bi.group.hello`) sends its line and its emote on one press (#20 AC).
- **test_database, step 20:**
  - an unedited shipped callout gains its emote, once;
  - **"unedited" is pinned one field at a time:** a changed text, a changed channel, an emote already set,
    or a ping or marker set each leaves the callout alone;
  - a renamed or recolored callout still gains it (F4);
  - a callout with no origin (a copy) gains nothing;
  - text from another locale reads as edited;
  - a deleted callout is not brought back;
  - the 2 new rows are inserted once, in shipped order, after their predecessors, with no `glyph` field;
  - a renamed or reordered group still gains;
  - a deleted set gains nothing;
  - a duplicated set gains nothing;
  - an unprepared profile is left to Prepare;
  - `nil`, `{}` and damaged profiles are safe;
  - it is idempotent on a re-run.
- **New `tests/test_autothank.lua`**, registered in `tests/run.lua` `suites`:
  - each filter: self by GUID, a pet GUID, an NPC GUID, a group member, a stranger with
    `isFromPlayerOrPlayerPet = true` accepted, a duration of 59 against 60 and 0, the cooldown, the
    allowlist, and the two mutes;
  - `GetAuraCasterGUID` nil falls back to `sourceUnit`, and both nil drop the aura;
  - the unit-filter frame's `__unitEvents` is `UNIT_AURA -> { "player" }` when on in the open world. It is
    empty when off, in a dungeon by default, or stood down, and it is re-used across a cycle;
  - a content kind off gives nothing;
  - a full update gives nothing;
  - a secret payload sets dirty, and the after-combat diff toasts the new aura once;
  - a `/reload` in combat with no `RESTRICTION_CHANGED` still diffs on `PLAYER_REGEN_ENABLED`;
  - five strangers give 3 toasts on screen and 2 queued, `C.THANK.GAP` apart, with no burst;
  - no `Show` in lockdown, and `Hold()` with no `keepShown` at the combat edge;
  - with lockdown still false at the `PLAYER_REGEN_DISABLED` edge, a buff in the edge window is not diffed
    and not shown until the end of combat, and `Release` does not fire at combat start;
  - a UNIT_AURA from a stranger leads to exactly one `Show`, whose text is `L["%s buffed you with %s"]`
    filled with the caster and the buff;
  - Attach is called once per pool frame across reuses;
  - the Thank click's `sentMacros` in each mode:
    - `/thank Name-Realm` with the realm normalized;
    - regional names give `First-Surname`;
    - `/w Name text` with `{name}` and `{buff}` filled and pipes doubled;
    - "both" holds the whole macro at 255 bytes;
    - an empty text is refused;
  - a Thank click does not stamp `lastSendAt`, emits a non-nil id, and prints the lock note under chat
    lockdown;
  - an unclicked toast fades over its last `C.THANK.FADE` seconds, hover holds it at alpha 1, and the
    library hides it at `C.THANK.DURATION`;
  - the stand-down clears the toast and unregisters the frame.
- **The mock** (`tests/wow_mock.lua`, header documented; nothing in `tests/_kit/` is touched) gains:
  - `C_UnitAuras.GetAuraDataByAuraInstanceID`, `GetAuraCasterGUID` and `GetUnitAuraInstanceIDs`, and a
    UNIT_AURA `updateInfo` helper, with a secret variant;
  - `GetPlayerInfoByGUID`, `UnitGUID`, `C_PartyInfo.IsGUIDInGroup`, `C_FriendList.IsFriend` and
    `IsGuildMember`;
  - `C_Ping.IsPingSystemEnabled` and `GetCooldownInfo`;
  - `CanBeRaidTarget`, `IsInRaid` leadership and `IsEveryoneAssistant`;
  - the `SLASH_PING1`, `SLASH_TARGET_MARKER1` and `SLASH_WHISPER1` globals;
  - a `sentLines(i)` helper that splits a macro on `"\n"`;
  - frame `SetAlpha`, `GetAlpha` and `IsMouseOver`, if they are missing.
- **Harness obligations:**
  - `test_disabled` `PINNED` gains CHAT_MSG_WHISPER_INFORM only. UNIT_AURA is pinned through the
    unit-filter frame (§9);
  - `test_surface_parity` gets a Toast stub case, with an entry in `Kit.setSurfaceSource`;
  - `test_harness:44-56` asserts that Toast is the live library;
  - `test_skin_windows` `FILES` and `tests/skin_surfaces.lua` gain the toast;
  - `.luacheckrc` `read_globals` gains each new client global, scoped to `files["core/Compat.lua"]`.

## 12. Docs to update

- **docs/ARCHITECTURE.md:**
  - the Module Map (`AutoThank`, `AutoThank_Toast`, `ToastSetup`, `enUS_Settings`, `enUS_AutoThank`);
  - the Per-client features table (Ping and Marker on both clients, citing Blizzard_PingUI; a row for the
    `THANK_RAID_BUFFS` ids per client, including Forever's state);
  - Event Subscriptions (CHAT_MSG_WHISPER_INFORM on `NS.addon`; UNIT_AURA on the unit-filter frame, when it
    is registered);
  - Settings Schema (`callout.ping`, `callout.marker`, `thank.*`, and the reworded `callout.emote`);
  - Taint Notes (the multi-line macrotext; the toast frame carrying a secure child, so it is never moved or
    hidden in combat);
  - Known Limitations;
  - the file census (the corrected `enUS.lua` count and the new locale files);
  - the Documentation map (unchanged unless a new .md file is added).
- `docs/compat-layer.md`: `PingCommand`, `MarkerCommand`, `PingState`, `TargetExists`, `CanMark`,
  `MarkerRights`, `InRaid`, `EveryoneAssistant`, `AuraCaster`, `AuraByInstance`, `HelpfulAuraIds` and
  `WhisperName`.
- `docs/midnight-quirks.md`:
  - the UNIT_AURA payload is secret when auras are restricted;
  - `GetAuraCasterGUID` and `GetAuraDataByAuraInstanceID` are secret when the unit's auras are restricted;
  - `GetRaidTargetIndex` returns secrets, which `/tm`'s `!` branch compares;
  - `SetRaidTarget` has restrictions;
  - `@target` parses with no target unless `exists` is given.
- `docs/performance.md`: the UNIT_AURA cost. One unit (player) is registered only while the feature is on
  for the current content kind, and it costs nothing in instances by default.
- `docs/schema.md`: the callouts row (:35), the member rows (:69), the `thank` block, and a Step 20
  paragraph after step 19 (:299), defining "unedited".
- `docs/data-flow.md` `## Today: a callout is pressed`: one macro line per action, out of combat; the
  PreClick read of press-time reasons.
- `docs/taint.md`: send buttons, and the toast's Thank button.
- `docs/known-limitations.md`:
  - the 255-byte cap covers the whole macro;
  - pings and markers need a target;
  - marking rights, and the three-unit marker throttle;
  - an action-only press flashes with no confirmation;
  - the heuristic buff filter, and the raid-buff allowlist's three buffs;
  - in-combat buffs are found by a diff after the fight, so a buff gained and lost in one fight is not seen;
  - a pad placed over the toast covers it (DIALOG over HIGH);
  - In Group emotes are padlocked in arenas and battlegrounds (`pvpMatch`);
  - Forever's raid-buff ids, when none are derived: the raid-buffs-only toggle is hidden or disabled there.
- `docs/scope.md:50-70`: remove "marks (#4)" from "does not do". Rewrite "Read combat-only data (auras)" to
  allow the one read #19 makes: your own helpful auras, acted on only out of combat (F2).
- `docs/settings-panel.md`: rewrite "The emote channels"; update the popup tree, the draft and Save; add the
  Auto-thank page.
- `docs/common-tasks.md`: "Add a member field" (with `ping` and `marker` as the worked example) and "Add a
  callout action".
- `docs/module-map.md`, `docs/testing.md` (the new suites and mock surfaces), `docs/test-cases.md`
  (regenerated) and the README tests badge, each in the same commit as its change.
- `README.md` feature text (README.md:92-96 says a game-emote callout does one thing): combined actions,
  pings, markers, the shipped callouts' emotes and auto-thank, each in its milestone's docs task.
- `docs/smoke-tests.md` Pending sign-off: the roll-up sentence (the "Owed from ..." paragraphs, about
  line 2587) gains the run's new ids, beside the Index rows and the checks themselves.

## 13. In-game smoke checks to add (docs/smoke-tests.md, Pending sign-off; an agent never marks one passed)

New themes get rows in `## Index`. Each check runs on Retail, then on WoW Forever. The highest ids today are
EMOTE-8 and FOREVER-25.

- **ACTION-1.** #16's AC: a callout with "Kick on me" in Party, `/point`, an Attack ping and Skull, on a
  target, in a party. Expected: one press sends all four, the button flashes once and the guard dims once.
- **ACTION-2.** The same callout in combat.
- **ACTION-3.** The same callout with no target. Expected: the line and the emote go out, the press prints
  "no target to ping" and "no target to mark", and no ping lands on an auto-chosen target (`exists`).
- **ACTION-4.** The macro cap: a 250-byte line plus an emote and a ping (about 290 bytes). Expected: the Line
  is refused as too long and the rest sends. Then raise `MAX_MACRO` in a dev build and check whether a
  300-byte, four-line macro runs (UNVERIFIED total cap).
- **ACTION-5.** Say plus an emote outdoors in one press: both go out (the hardware event covers the second
  line; UNVERIFIED).
- **ACTION-6.** During a boss encounter: a Line plus an Emote plus a Ping. Note which go out (encounter
  throttle; UNVERIFIED).
- **ACTION-7.** A Line locked by chat lockdown, plus a marker: the note prints and the marker still applies.
- **ACTION-8.** A legacy game-emote callout from before the update still emotes, and its editor shows Channel
  None.
- **PING-1.** Solo, with a target, each of the four types (UNVERIFIED: solo pinging).
- **PING-2.** In a party, in combat (#17 AC).
- **PING-3.** WoW Forever: is the ping placed and seen by a party member (UNVERIFIED: server delivery)?
- **PING-4.** During an encounter lockdown.
- **PING-5.** With pings disabled in options, and on cooldown: the reason prints, and does the client print
  its own error? A single press off cooldown prints no false "cooldown".
- **MARK-1.** Solo, marking a target (UNVERIFIED: solo rights).
- **MARK-2.** In a party, as a non-leader: the mark lands.
- **MARK-3.** In a raid, without assist: the rights reason prints and no mark lands. With assist: no reason,
  and the mark lands.
- **MARK-4.** A second press does not clear the mark (`!N`).
- **MARK-5.** No target, and a target that cannot be marked: each reason prints.
- **MARK-6.** Forever: `/tm` is the command name in its locale (UNVERIFIED).
- **MARK-7.** Marking in combat, and during a boss encounter, in a party, on both clients. Does the mark land,
  and is there a taint or blocked-action error (`SetRaidTarget` restrictions; the secret
  `GetRaidTargetIndex` compare in `/tm`'s `!` branch)?
- **EMOTE-9.** A fresh profile: the 12 listed callouts carry their emote and the 2 new rows are listed, on
  both clients (no listed set is skipped on Forever). Each sends its line and its emote on one press. Run it
  in a key outside a boss (no padlock), and during a boss (the emote's note prints). Note any token that
  produces no `CHAT_MSG_TEXT_EMOTE` without a target (R3).
- **EMOTE-10.** An existing profile from before the update, after a /reload:
  - every unedited listed callout gains its emote, once;
  - an In Group callout whose text was edited does not;
  - a renamed one does;
  - a deleted Raid set stays deleted;
  - a deleted Solo `thanks` does not come back;
  - Dungeon and Raid gain `healme` once.
- **THANK-1.** Open world: a stranger buffs you with Arcane Intellect. Expected: one toast. The click sends
  `/thank` at them, and an unclicked toast fades, then goes (#19 AC).
- **THANK-2.** Is the caster readable for a stranger who is not your target, with friendly nameplates off? Read
  `GetAuraCasterGUID` first and `sourceUnit` second. Record each with and without the stranger targeted,
  and record `GetPlayerInfoByGUID`'s name and realm for that stranger (the other half of R1).
- **THANK-3.** `/thank Name` when the caster is out of range or out of sight (UNVERIFIED).
- **THANK-4.** The whisper mode: the whisper reaches a cross-realm caster whose realm has a space on Retail,
  and a "First Surname" caster on Forever, and the echo is matched. The emote mode too: `/thank Name-Realm`
  lands on a cross-realm caster on Retail, and `/thank First-Surname` on Forever.
- **THANK-5.** A buff mid-fight: no toast in combat, one after it. Repeat after a /reload in combat.
- **THANK-6.** Five strangers buff in a burst: at most three on screen and the rest after, not five at once.
- **THANK-7.** Raid buffs only: the allowlist ids on Retail and on Forever (UNVERIFIED ids).
- **THANK-8.** Off for the content kind (a dungeon, by default): nothing. A self-buff, a group member's buff and
  a pet's buff: nothing.
- **THANK-9.** A toast is up when combat starts: it hides without a taint error and comes back after the
  fight.
- **THANK-10.** A right-click dismisses the toast and sends nothing.
- **THANK-11.** A Thank click, then a pad press within the spam-guard window: the pad press is not "guarded".
- **THANK-12.** The two mute modes: a friend's buff and a guildmate's buff under "Strangers" and under
  "Friends and guild". Confirms `C_FriendList.IsFriend(guid)` and `IsGuildMember(guid)` answer for a GUID.
- **FOREVER-26.** The combined-actions core re-run on Forever: ACTION-1, PING-2, MARK-2 and MARK-7.

## 14. Risks and points to flag to the owner

- **R1: the caster may be unreadable (#19's core risk), now smaller.** `C_UnitAuras.GetAuraCasterGUID` gives
  the caster's GUID with no unit token, and `GetPlayerInfoByGUID` gives the name and realm. So revision 1's
  "no unit token, no name" case is covered when the GUID is plain. The risk left is that the GUID or the
  player info is secret or nil for strangers out of combat. THANK-2 settles it. If it is unreadable in the
  common case, #19 needs a rethink, and that is the owner's call.
- **R2: the total macro cap is unverified.** D13 keeps 255, which shrinks a Line's room when actions are set.
- **R3: echo for silent emotes.** If a token produces no `CHAT_MSG_TEXT_EMOTE` without a target, the press
  reports a false "may not have been sent". EMOTE-9 checks each token.
- **R4: Forever pings.** If PING-3 fails, Forever's ping slot is hidden through Compat. That is a new
  per-client row, and the AC would need the owner's ruling.
- **R5: marking in combat (MARK-7).** If `/tm` is blocked in combat or in encounters, #18's AC holds only out
  of combat, and the owner rules on it.

**Points against the standard or the addon's own scope.** Each is for the owner to decide, as CLAUDE.md
requires, and none is silently taken:

- **F1 (resolved, dropped).** The locale split follows localization-§6 exactly (§1 M0), so there is no
  deviation and no upstream change.
- **F2: the scope doc.** `docs/scope.md` says the addon does not read auras, and D12 says no callout is sent
  automatically. #19 reads your own auras, and it still sends nothing without a click. This is the addon's
  own scope, not the standard. The issue and R-B are the owner's rulings, and scope.md is rewritten.
  Confirm.
- **F3: a whisper sent from a secure macro (D4).** It breaks the addon's own rule from issue #7 (no whisper
  channels), for auto-thank only. It is not a standard rule.
- **F4: builder calls that change what is stored or shown, named here:**
  - a synthetic "sent" for an action-only press (D16);
  - "no line" kept as `gameEmote` (D10);
  - step 20's "unedited" ignoring name and icon (§8);
  - the Arena and battleground sets left without emotes (§8);
  - the after-combat diff in place of a queue of ids (§9 Combat).
- **F5: Toast adoption.** The LibKa0s Toast shell paints the toast. No deviation is expected. If the skin
  gates (`test_skin_switch`) need toast colors the library does not expose, stop and flag it. The fade is
  done in the builder and needs nothing from the library. If a fade is later wanted in the library, that is
  a LibKa0s change, not a deviation.
- **The unit-filter frame (§9)** is inside events-frames-taint-§1's carve-out, so it needs no deviation row.

No deviation row is added to `docs/ARCHITECTURE.md` `## Documented deviations` unless the owner ratifies one.

## Done when

- Both kit profiles are green, and luacheck is 0/0 (through `ka0s-bounded`). Every authored file is under
  1500 lines, with the census current. The complexity suite has nothing above CCN 15.
- The locale union gates are green over every enUS file.
- Every doc in §12 is updated, `docs/test-cases.md` is regenerated, and the README badge matches.
- Every check in §13 is in Pending sign-off.
- One PR on `feat/2026-11-10-combined-actions`, merged only on the owner's go-ahead after the smoke pass
  (D8).
