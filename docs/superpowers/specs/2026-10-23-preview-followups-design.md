# Preview follow-ups — design (2026-10-23)

Owner report and requests of 2026-10-23, after the QC-01..QC-07 preview run (merged 0487489). Single-repo
work on `feat/2026-10-23-qc-preview-followups`; the plan is
`docs/superpowers/plans/2026-10-23-preview-followups.md` (items QF-01..QF-06).

## 0. The request (verbatim)

> QC preview changes -
> - works when i do /qc preview (print to chat and the preview modal appears)
> - neither of these appear when i go edit a group with previewing while editing selected
> - in preview mode, clicking a slice on the dial should not close the dial
>
> QC other changes
> - add a placeholder for coordinates - can be used in things like rare spotted - {target} @ {coordinates}
>   - update existing callouts where coordinates can be useful
> - For the solo group, update the prebuilt callouts to send to General chat /1 instead of say

And, on the prebuilts (owner, 2026-10-23):

> go ahead and just replace the prebuilts, no need for migration since this is pre-release (i'll edit
> them again if needed)
> - In fact look at the ones I edited and add them to prebuilts (text, icons, colors)
>   - The only thing to change is the In Group > Hello callout should have its text as "Hello!" only
>     not "Hello there!"

Lead decisions D1-D5 (binding) are restated per section below.

## 1. Current state, with evidence

### 1.1 The edit preview has no window (D1): the cause

- `modules/PreviewWindow.lua:172` (`PW.Sync`): `local want = NS.Preview.PreviewAs() ~= nil and not
  NS.IsStoodDown()`. The window keys on `State.previewAs` only. `State.editPreview` (the Groups page's
  "Preview while editing", `modules/Preview.lua:249` `P.SetEditPreview`) never shows it.
- This was deliberate in QC-02: the file's header says so, `modules/PreviewWindow.lua:4-5` ("Plain
  test mode (placeholders) and the edit preview get no window"), and `docs/module-map.md`,
  `docs/ARCHITECTURE.md` repeat "shown exactly while Preview as is on".
- Its controls know only Preview as: `endPreview` (`modules/PreviewWindow.lua:47-49`) calls
  `SetPreviewAs(OFF)`; `onHide` (`:122-125`) ends only when `PreviewAs() ~= nil`; `fill` (`:162-167`)
  selects `PreviewAs()`; the title is the fixed `"%s - Preview"` (`:141`).
- `announce()` already calls `PW.Sync` on every flavor's edge (`modules/Preview.lua:32-38`), and
  `SetEditPreview` calls `announce()` (`:252-254`), so once `Sync` reads the edit preview, the
  window follows it with no new wiring.
- The Groups page restarts the edit preview whenever `G.SyncEditPreview` runs while
  `behavior.previewOnEdit` is on (`settings/Groups.lua:539-544`), and it runs on **every render**
  (`settings/Groups.lua:715-730`, the render ends with `G.SyncEditPreview()`), on the page's `onShow`
  (`:761`) and on every combat end (`:551-553`, `onRestrictionChanged`). A render follows every
  `TEST_MODE_CHANGED` (`settings/Editors.lua:160` -> `Ed.RequestRefresh`, a 0 s timer, `:103-112`), and
  `SetEditPreview(nil)` itself sends that message (`announce()`, `modules/Preview.lua:32-38`). So
  ending the edit preview while the page is on screen and the setting is on bounces straight back on
  the next frame; ending it for good needs either the setting off or an explicit session "dismissed"
  mark the page honours (2.1). The band's checkbox reads the setting (`settings/Groups.lua:642`).
- `/qc preview off` (`settings/SlashVerbs.lua:126-131`) only calls `SetPreviewAs(OFF)`; with the edit
  preview on and Preview as off it prints `Preview off.` and nothing ends. The End preview button's
  tooltip advertises `/qc preview off` as its typed equivalent (`modules/PreviewWindow.lua:97`).

### 1.2 "Print to chat" in the edit preview (D1)

Two readings, and both are covered:

1. **The start line.** `/qc preview` prints `Previewing: <situation>` (`settings/SlashVerbs.lua:118`,
   `:131`) and the window appears. The edit preview starts silently by design
   (`modules/Preview.lua:237-238`, "refused without a line, because the page asks again on every
   draw"; `P.SetEditPreview` prints nothing on success either). This is the most literal reading of
   the owner's "(print to chat and the preview modal appears)".
2. **The click echo (QC-07).** The echo path is shared: `Surfaces.ApplyAll` marks an edit-preview plan
   with `S.MarkPreview(plan, NS.Preview.EDIT)` (`modules/Surfaces.lua:421-424`), which bakes every
   slot's `echo` (`:248-255`); Pad's `arm` carries it on preview slots (`modules/Pad.lua:195-207`,
   used by dial wedges through `Pad.ArmSlot`); the click hook prints it (`modules/SendEngine.lua:405-410`).
   Headless, the pad echo under the edit preview is green (`tests/test_preview.lua`, "the edit
   preview echoes too"). Not covered headless: a dial wedge under the edit preview clicked through
   the ring's catcher while the Groups page is on screen (the only in-client path to a wedge: wedges
   take no mouse, `modules/Dial_Secure.lua`). No code-level cause was found for a missing echo;
   per "bisect before theorizing" the plan adds that exact headless case (red if broken) and an
   in-client check with `/qc debug` on, whose existing `press ...` debug line
   (`modules/SendEngine.lua:398-399`) tells a click that never arrived from an echo that never
   printed. If the case is red, the cause is fixed in the same item.

### 1.3 A slice click closes the preview dial (D2): the cause

- `modules/Dial_Secure.lua:200-202`, `WEDGE_POST`: `owner:RunAttribute("qc-close")`, unconditionally,
  after every left click on a callout wedge that `WEDGE_PRE` let through (`:186-198` returns
  `button, "sent"`). Preview and test wedges are disarmed (no `type`), but the wrap's post still runs.
- The header already distinguishes an insecure open (`display`, set by `DISPLAY` `:124-130`, cleared
  by `CLOSE` and by a key `Toggle`, `:63-69`), but nothing tells the snippets the plan is a preview,
  and `display` is the wrong key: a preview dial opened with its key must stay open too ("in any
  preview or test mode").
- `DS.Load` (`modules/Dial_Secure.lua:315-345`) is the one place header attributes are written, out
  of combat, through `SendEngine.SetAttributes`; `Dial.Apply` calls it with the plan
  (`modules/Dial.lua:291-292`), where `plan.test` is true for test mode, Preview as and the edit
  preview alike (`S.MarkPreview` sets `plan.test, plan.preview`, `modules/Surfaces.lua:249`; the test
  dial plan carries `test = true`, `:240`).

### 1.4 Tokens (D3)

- `modules/Tokens.lua`: engine tokens (`{target}` -> `%t`, `{focus}` -> `%f`, `:13`) are left to the
  game; baked tokens (`BAKED`, `:15`) come from `ctx`, filled out of combat by `Surfaces.BakeContext`
  (`modules/Surfaces.lua:96-108`). A missing baked value is dropped (`""`) and listed in `missing`
  (`:29-34`); with a `mock` (the preview echo) it is the mock instead.
- Every value is baked into the button's `macrotext` at plan time (`SendEngine.Arm`,
  `modules/SendEngine.lua:97-110`), out of combat. A secure macro button sends what its attribute
  says, so a value that changes while the plan does not (your position) goes stale unless something
  re-arms the button. The send buttons carry one insecure hook today, `OnClick` (after the secure
  handler, `modules/SendEngine.lua:84`). The headless mock's `Click` runs only `OnClick`
  (`tests/wow_mock.lua:815-818`); it models no `PreClick`.
- `core/Compat.lua` has no map-position shim (no `C_Map` anywhere in `core/` or `modules/`).
- Where tokens are listed: `settings/Callouts.lua:19-20` (`C.TOKENS`, the token glyph's list and
  autocomplete), `:40-48` (`TOKEN_HELP`), `settings/SchemaMembers.lua:162` and
  `locales/enUS.lua:563` (the Text row's description), `modules/Tokens.lua:3-5` (header),
  `modules/Preview.lua:276-279` (`P.MOCK`), `docs/smoke-tests.md:447` (EDIT-18),
  `docs/compat-layer.md` (the shim table), README's preview paragraph (`README.md:77`).

### 1.5 Channels (D4b)

- `modules/Channels.lua:9` `Ch.KINDS` = smartGroup, smartLead, party, raid, instance, raidWarning, say,
  yell; `PREFIX` / `CHAT_TYPE` (`:11-17`); `Ch.Resolve` (`:41-51`) returns a fixed kind as itself
  (`if PREFIX[kind]`) and maps the smart ones from the snapshot; `LOCKS` (`:55-78`). **No numbered or
  custom channel exists.** `Channels.lua` is the one place a kind becomes a slash (`Bake.Bake` reads
  `Prefix` and `ChatType`).
- Every consumer enumerates `Ch.KINDS` / `Ch.IsKind`: the callout's channel row
  (`settings/SchemaMembers.lua:123-130`, labels in `CHANNEL_LABEL`), `Library` validation
  (`modules/Library.lua:437`), Share import (`modules/Share.lua:250`).
- The echo tracker matches `CHAT_MSG_*` by chat type (`modules/SendEngine_Guard.lua:23-33`); it has
  no `CHAT_MSG_CHANNEL` row.
- Whether channel 1 is joined is not in the snapshot (`modules/Situation.lua:49` `Classify`, `:73`
  `SIGNATURE_FIELDS`, `:87` `ReadInputs`, `:162-166` `EVENTS`).
- The solo set: `defaults/BuiltIns_World.lua:13` — `BI.Callouts(ID, "say", {...})`, seven callouts.
  `tests/test_builtins.lua:133-149` asserts every solo callout is say or yell and that `thanks` bakes
  `/s ...`.

### 1.6 The prebuilts, and the owner's edits (D4a)

- Shipped sets are **seeded** into each profile as ordinary groups and callouts, each keeping its
  shipped id as `origin` (`defaults/BuiltIns.lua:1-4`; `modules/Library.lua:718-740`). A shipped
  default change reaches only new profiles and Restore built-in groups; an existing profile keeps
  what it has. No schema step is added (D4c): `NS.MIGRATIONS` stays at 9 (`core/Database.lua`).
- **The diff.** The owner's SavedVariables (read-only, `.../WTF/Account/ADD1KTED2KA0S/SavedVariables/
  QuickComms.lua`, profile `Default`, schemaVersion 9) were loaded with the repo's own loader and
  every seeded group and callout compared, by `origin`, against `NS.BuiltIns` (name, text, channel,
  icon, iconColor, membership and order; groups the same). The `SmokeTest` profile has no
  difference. The `Default` profile has:

  | Where | Owner's profile | Shipped now | Verdict |
  | --- | --- | --- | --- |
  | Dungeon > Chain pull (`bi.mplus.chain`) | color `fff468` | `ff4040` (red) | **owner edit: adopt** |
  | In Group > Hello (`bi.group.hello`) | text `Hello there!`, color `3fc7eb` | `Hello!`, `ffd100` (gold) | **color adopted; text stays `Hello!`** (owner's exception) |
  | In Group, 2nd (no origin, `c481`) | `At Stone` / `At stone, WM off.` / smartGroup / `gi:tombstone-sbed` / `b07cff` | absent | **owner addition: adopt** as `bi.group.stone`, 2nd |
  | 14 texts: Raid > Battle rez, Solo > Rare / Elite / World boss, EotS flag kill, WSG and TP kill EFC, ToK kill (set and four orbs), DHR crystal kill, Ashran captain | `... %t` | `... {target}` | **not an owner edit: keep shipped** |

  The 14 `%t` texts are stale seeds, not edits: they are exactly what `d79bb09` shipped, and
  `65f3a5a` (2026-10-22, "the shipped look", built from the owner's profile then) turned every
  shipped `%t` into the `{target}` chip; `tests/test_builtins.lua:356` pins "no shipped callout types a
  raw %t". Both send the same line (`modules/Tokens.lua:13`). The owner's profile was seeded before
  that change and no step rewrote texts. Flagged for the owner, not adopted.
- Colors: `BI.COLOR` (`defaults/BuiltIns.lua:15-16`) has no `fff468` or `3fc7eb`. The two owner
  colors join it (`yellow = "fff468"`, `sky = "3fc7eb"`), as `crimson` did in `65f3a5a`.
  `tests/test_builtins.lua:162` (every callout colored, no white-only group) is unaffected.
- `modules/Library.lua` is at 1401 lines: nothing is added there.

## 2. Design

### 2.1 D1 — the window over the edit preview

- `PW.Sync`: `want = (PreviewAs() ~= nil or EditGroup() ~= nil) and not NS.IsStoodDown()`.
- **Title.** Editing: `"<brand> - Preview: <group name>"`; otherwise the current
  `"<brand> - Preview"`. Word wrap off, so a long name truncates.
- **Dropdown.** Lists the same presets. Selection: `PreviewAs()`, or `CURRENT` when only the edit
  preview is on (it then bakes against the live snapshot, which is what Current is). Picking calls
  `SetPreviewAs(v)` as today: the edit preview sits over Preview as and bakes against its snapshot
  (`modules/Surfaces.lua:405-411`), so the edited group re-renders under the picked situation with no
  new state. Consequence, documented: a situation picked while editing **is** a Preview as, so it
  outlives the settings window like any other (EDIT-27's existing rule).
- **End preview, the close mark and `/qc preview off`** (explicit; one function, `P.EndPreview()` in
  `modules/Preview.lua`, so the three cannot drift): if the edit preview is on, write
  `behavior.previewOnEdit = false` through `NS.SchemaRuntime.Set` (its `onChange` runs
  `Groups.SyncEditPreview`, which ends the edit preview; the band's checkbox reflects it on the page's
  next draw, and `announce()`'s `RefreshAll` redraws), and call `SetEditPreview(nil)` as well (a no-op
  when the `onChange` already ended it); then `SetPreviewAs(OFF)`. Turning the setting off is what
  stops the Groups page restarting the preview on its next render (1.1).
  - `/qc preview off` (`settings/SlashVerbs.lua` `V.PreviewLines`) calls `P.EndPreview()` whenever
    Preview as **or** the edit preview is on (today's guard `P.PreviewAs() ~= want` misses the edit
    preview), then prints `Preview off.` as today. So the End preview tooltip's `/qc preview off`
    stays true and is not changed. With nothing on, it prints `Preview off.` and writes nothing.
- **Escape / a Hide()** (not a click on the window's controls): **a session-only dismissal**, option
  (b) of the plan review. The saved switch is left alone: Escape is also the player's way to close the
  settings window, and turning `behavior.previewOnEdit` off as a side effect would be a surprise.
  - `P.DismissEditPreview()` (new, `modules/Preview.lua`): `State.editPreviewDismissed =
    State.editPreview`, then `SetEditPreview(nil)` and `SetPreviewAs(OFF)`. `onHide` calls it when the
    window was hidden by Escape or `Hide()` and the edit preview was on; with only Preview as on it
    calls `SetPreviewAs(OFF)` as today.
  - `G.SyncEditPreview` honours it: when the group it would preview equals
    `State.editPreviewDismissed`, it previews nothing. The mark is cleared (set to nil) when (1) the
    selected group differs from it (a group switch: Sync clears it, then starts the new group's
    preview), (2) the Groups page's `onShow` runs (before its Sync: reopening the page is a new
    start), (3) the setting is written (either value), (4) `P.EndPreview()` runs. Every other restart
    path (any render, any `TEST_MODE_CHANGED`, a combat end) goes through Sync and so stays off.
  - Session-only (`NS.State`, never saved); the stand-down's state wipe clears it with the rest.
- A hidden UIParent (Alt+Z) still ends nothing (the `IsShown` test in `onHide` stays).
- **Start line.** `P.SetEditPreview(gid, quiet)` prints `Previewing: <group> (editing)` on the
  off -> on edge only, unless `quiet`. Intended behaviour, per path:
  | Path | Line? |
  | --- | --- |
  | The Groups page shown with the setting on (`onShow`) | yes |
  | The setting ticked on while the page is shown | yes |
  | A group switch while on (on -> on, no edge) | no |
  | Any render or `TEST_MODE_CHANGED` re-sync while on (no edge) | no |
  | The restart after combat ends (`onRestrictionChanged` passes `quiet`) | **no**: the window coming back is the signal; the only chat line is Preview's `Preview ended: you entered combat.` |
  | A refused start (combat, stood down) | no (silent, as today) |
  | After Escape (dismissed: no restart) | no |
  `G.SyncEditPreview(quiet)` forwards `quiet`; only `onRestrictionChanged` passes it.
- **Echo.** No design change: the shared path stands. QF-02 adds the catcher-path headless case for a
  dial wedge under the edit preview with the Groups page shown; a red result is fixed in place.
- Header comments that say "the edit preview gets no window" are rewritten.

### 2.2 D2 — a preview dial stays open on a slice click

- `DS.Load` writes one more header attribute, `qc-preview` (true when `opts.preview`), in the same
  `SetAttributes` call as the rings. `Dial.Apply` passes `preview = plan.test == true`.
- `WEDGE_POST` becomes:

  ```lua
  if not owner:GetAttribute("qc-preview") then owner:RunAttribute("qc-close") end
  ```

  The snippet reads an attribute, never writes one (the firewall case,
  `tests/test_dial_secure.lua:220`, stays green).
- **Live path unchanged.** A live plan writes `qc-preview = false`, so the post closes exactly as
  today. The attribute is written by the same `DS.Load` that arms or disarms the wedges, out of
  combat, so `qc-preview` and the wedges' armed state always agree: when combat starts while a preview
  is up, Preview's combat edge ends the preview and the rebuild runs at `PLAYER_REGEN_DISABLED`
  (writes still allowed); were that rebuild ever queued instead, the wedges are still the disarmed
  preview ones, so keeping the dial open matches what is drawn. No change runs in combat, and no
  insecure code is added to the click chain.
- Unchanged in a preview: a ring wedge still opens its ring, a page arrow still pages, the hub still
  goes up or closes, a right click on a slice still goes back, a middle click still closes, Escape and
  the key still close, and the outside-click screen catcher still closes a key-opened dial. A number
  key pick (`w<n>`) on a preview dial also leaves it open (the same post).
- Test mode's placeholder dial is a `plan.test` plan too, so it stays open as well.

### 2.3 D3 — the {coordinates} token

- **Compat** (`core/Compat.lua`, bake-context section): `Compat.PlayerMapPosition()` returns `x, y` in
  percent (0-100) or `nil`: `C_Map.GetBestMapForUnit("player")`, then
  `C_Map.GetPlayerMapPosition(mapID, "player")`, then `:GetXY()`; every value through `PlainNumber`
  (secret-value safe); `nil` when any step is missing, the map is restricted (instances return nil),
  or the position is 0,0. `Compat.Coordinates()` formats it: `("%.1f, %.1f"):format(x, y)` ->
  `"45.2, 61.8"`. Both read only (a click in combat may call them).
- **Tokens** (`modules/Tokens.lua`): `coordinates` joins `BAKED` (`coords` is accepted as a typed alias,
  as `x` is for `cross`). Missing in a live bake: dropped and listed in `missing`, the existing
  convention, so `"{target} @ {coordinates}"` bakes to `"%t @"` in a dungeon.
- **BakeContext** (`modules/Surfaces.lua:98`): `coordinates = C.Coordinates()` when the snapshot is the
  live one; `nil` for a synthetic preview snapshot (a Preview as preset other than Current: your real
  position is not the previewed place). **The live snapshot is detected by identity**:
  `snap == NS.Situation.Current()`. `P.PreviewSnapshot()` returns that same table for Current
  (`modules/Preview.lua:198`), and `Surfaces.ApplyAll` falls back to it when no preset is on
  (`modules/Surfaces.lua:410-411`, the edit preview alone), so Current, the edit preview alone and
  live plans all count as live; every other preset builds its own table and does not.
- **Staying current (the live send): re-bake at the press, out of combat.** A position changes while
  the plan does not. `SendEngine` gives each send button one more insecure hook, `PreClick` (beside the
  `OnClick` hook where the button is made; SendEngine stays the only file that touches a secure
  frame). When the button's meta carries `rebake` (set by Pad's `arm` only for an armed live slot whose
  callout text uses `{coordinates}`), the hook, **out of combat only**, calls it for the line with the
  current context and, when it differs from `macrotext`, re-arms through `SE.Arm`; the secure handler
  that runs next sends the fresh line. In combat the hook returns at once (no attribute write is
  attempted), so the button sends what it last held.
  - The combat edge: on `RESTRICTION_CHANGED` into combat (still writable at `PLAYER_REGEN_DISABLED`,
    the edge Preview already uses), `SE.RefreshRebakes()` re-arms every button with a `rebake` once,
    so a press in combat sends the position at the pull, not the last rebuild's.
  - A re-bake that fails (over 255 bytes) leaves the button as it was.
  - Why not a timer (an earlier draft's 1 s re-arm loop): the press-time re-bake is exact out of
    combat and costs nothing between presses; the combat edge covers the one case a press cannot
    write. Taint: the line is written by addon code exactly as `SE.Arm` writes it today, only later;
    `PreClick` is the client's place to adjust a secure action button's attributes before it acts.
  - Perf: one `Perf.Note` key (`coordsRebake`) beside the existing ones (`core/PerfSetup.lua`).
  - The mock: `tests/wow_mock.lua` gains `PreClick` (run before `OnClick` on a `Click` and a
    `__click`), the client API the tests need (docs/testing.md: extend the mock, never `tests/_kit/`).
- **Preview echo.** `P.SlotEcho` builds its ctx from `NS.Surfaces.BakeContext(snap)`
  (`modules/Preview.lua:294-295`), which for the live snapshot **does** carry `coordinates` (the bullet
  above), so left alone the mock would never be asked and the echo would print the plan-time
  position. So `SlotEcho` takes a copy of that ctx and **sets `ctx.coordinates = nil`** before the bake
  (always: an echo never uses the plan-time position), and `mockBaked("coordinates")` answers:
  - the literal `"{coordinates}"` when `snap == NS.Situation.Current()` (the identity test above), so
    the placeholder survives the bake into `slot.echo`;
  - `P.MOCK.coordinates` (`L["<coordinates>"]`) otherwise (a synthetic preset).
  `P.FillEcho` then replaces a literal `{coordinates}` at the click with `Compat.Coordinates()`, or
  `P.MOCK.coordinates` when that is nil. So a Current or edit-preview echo in the open world prints
  where you are at the click; an M+ preset, or no position, prints `<coordinates>`. The literal must
  pass `Bake`'s text cleaning unchanged (`{` and `}` are not escaped); a headless case pins it.
- **Lists.** `C.TOKENS` gains `{coordinates}` (after `{dungeon}`), `TOKEN_HELP` gains
  `"Your map position, as 45.2, 61.8. Empty where the map does not show you (dungeons, raids)."`, the
  Text row's description lists it, `P.MOCK.coordinates`, every new string in `locales/enUS.lua`;
  README, `docs/compat-layer.md`, EDIT-18's token list.

### 2.4 D4 — the prebuilts, replaced (no migration)

**(a) The owner's edits, adopted** (1.6): `bi.mplus.chain` takes `C.yellow` (`fff468`);
`bi.group.hello` takes `C.sky` (`3fc7eb`), its text stays `Hello!`; `bi.group.stone` is new, 2nd in In
Group: `{ "stone", L["At Stone"], L["At stone, WM off."], "gi:tombstone-sbed", C.purple }` on the
set's `smartGroup` (`b07cff` is `C.purple`). The stable-id scheme is the set id plus a short key
(`defaults/BuiltIns.lua` `BI.Callout`); `stone` is new and unused.

**(b) General (/1).** A new channel kind, `general`, through `modules/Channels.lua` only:

- `Ch.KINDS` gains `general` (after `yell`); `PREFIX.general = "/1"`, `CHAT_TYPE.general = "CHANNEL"`.
- `Ch.Resolve("general", s)`, ahead of the fixed-kind return: `"general"` when `s.general` (channel 1
  joined), else `"say"` (the fallback). Resolution is at bake time, as smart kinds already are, and a
  join or leave rebuilds (below).
- `LOCKS.general = LOCKS.say` (the encounter / PvP chat lockdown).
- **Snapshot.** `Situation.ReadInputs` reads `Compat.GeneralJoined()` (`GetChannelName(1)` returns a
  non-zero id; `PlainNumber` guarded) into `general`; `Classify` copies it; `SIGNATURE_FIELDS` gains
  it, so a join or leave rebuilds. Events: `CHANNEL_UI_UPDATE` **and** `CHAT_MSG_CHANNEL_NOTICE`
  join `EVENTS` (the notice fires on `YOU_JOINED` / `YOU_LEFT` / `YOU_CHANGED`, including the
  automatic joins a few seconds after `PLAYER_ENTERING_WORLD` and the zone's channel swap, in case
  `CHANNEL_UI_UPDATE` does not fire for them). Both go through `Sit.Refresh` as every other situation
  event (coalesced as today); the signature makes a notice for any other channel a no-op rebuild-wise.
  Preview `base()` copies the live `general`; the Solo bake-audit snapshot
  (`BI.SNAPSHOTS["bi.world"]`) sets `general = true`. SEND-6 checks explicitly that Solo bakes `/1`
  right after login and right after a zone change.
- **Echo tracker.** `G.CHAT_TYPE_BY_EVENT.CHAT_MSG_CHANNEL = "CHANNEL"` (`G.ECHO_EVENTS` goes from 9 to
  10). `CHAT_MSG_CHANNEL` fires for **every** channel the player is in (Trade, LFG, Services, custom),
  so matching by chat type and sender alone would take the player's own `/2` line inside the 1.5 s
  window as the General echo. The edge (`NS.addon.OnSendEcho`) therefore also reads the channel index,
  the 8th payload field (`select(8, ...)`), and asks a pure `G.IsGeneralEcho(index)` (in
  `SendEngine_Guard.lua`, beside `G.Match`): `true` for 1, `false` for any other readable number (the
  event is ignored before `G.Match`), `nil` when unreadable (secret), which falls through to the
  sender test under the existing UNKNOWN rule. Never by text.
  - Perf note: `OnSendEcho` now runs on every General and Trade line in a capital. It already returns
    at its first line when no press is pending (`modules/SendEngine.lua:460`), before any `select`;
    the index read is after that test, so the idle cost is one table lookup per line.
    `docs/performance.md` records it beside `echoMatch`.
- **The editor and the labels.** `CHANNEL_LABEL.general = L["General (/1; Say when not joined)"]`
  (`settings/SchemaMembers.lua`); `CHANNEL_NAME.general = L["General"]` in `modules/Pad_Render.lua:74-77`
  (else `channelLine("general")` returns nil and a Solo button's or wedge's tooltip loses its
  `Channel:` line); `SHORT_CHANNEL.general = L["General"]` in `settings/Groups.lua:216-219` (else the
  Groups page's callout rows show no channel label for the Solo set).
- **The color.** `R.ChannelColor(NS.Channels.ChatType(concrete))` would ask for `"CHANNEL"`, which has
  no `Constants.CHAT_COLORS` fallback and falls to Say's white. The player's own channel-1 color is
  `ChatTypeInfo.CHANNEL1`. So `Ch.ColorType(kind)` (new, `modules/Channels.lua`) returns `"CHANNEL1"`
  for `general` and `ChatType(kind)` otherwise; `Pad_Render`'s `channelLine` and the Groups row ask
  `ColorType`, and `core/Constants.lua` `CHAT_COLORS` gains `CHANNEL1 = { 1.0, 0.75, 0.75 }` (the
  client's default channel color) as the fallback. `ChatType` stays `"CHANNEL"` (the echo's type).
- **Wording that says "never a custom channel".** `modules/SendEngine_Guard.lua:21` ("Never a guild or
  custom channel (§8.4)") becomes "Never a guild, community or custom channel; General (/1) is the one
  numbered channel (2026-10-23)". The v1 spec's lock matrix row
  (`docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md:433`, "guild, community, custom: Not
  offered") is a frozen record: it gets an italic "*Superseded in part 2026-10-23 by
  2026-10-23-preview-followups-design.md: General (/1) is offered, locked as Say.*" line under the
  table, the convention that file already uses; `docs/ARCHITECTURE.md` gets the same fact where it lists
  the channel kinds.
- **Protected send.** `/1 text` is sent by the same secure macro button click as `/s`, a hardware
  event, which public channels require. No new send path.
- **Solo set.** `BI.Callouts(ID, "general", {...})`.

**(b) Coordinates.** Only the Solo set is open world with no group; every other set runs where the
map is restricted (dungeons, raids, M+), where the place is already named (battleground nodes), or is
a short social line (In Group). In Solo, the four lines that say "here" about a place take it:

| Callout | Why |
| --- | --- |
| `bi.world.rare` | the owner's example, `{target} @ {coordinates}` |
| `bi.world.elite` | helpers need to find it |
| `bi.world.boss` | as rare |
| `bi.world.event` | "here" means nothing to a reader elsewhere |

Unchanged: quest (no fixed place), invite, thanks.

**(c) No migration.** No schema step, no `schemaVersion` bump; existing profiles keep what they have
(the owner re-edits theirs). New profiles and Restore built-in groups seed the new defaults. One
consequence, accepted: Restore on a profile that already has its own "At Stone" (no `origin`) puts the
shipped one back beside it, as Restore does for any shipped callout no member keeps the origin of.

**(d) The full prebuilt diff (before -> after).** Every other shipped group and callout is unchanged.

| Set > callout | Field | Before | After |
| --- | --- | --- | --- |
| Dungeon > Chain pull (`bi.mplus.chain`) | color | `ff4040` | `fff468` |
| In Group > Hello (`bi.group.hello`) | color | `ffd100` | `3fc7eb` |
| In Group > Hello (`bi.group.hello`) | text | `Hello!` | `Hello!` (unchanged, owner) |
| In Group > At Stone (`bi.group.stone`, new, 2nd) | all | — | name `At Stone`, text `At stone, WM off.`, Smart group, `gi:tombstone-sbed`, `b07cff` |
| In Group | order | Hello, Summon, Buffs please, Healthstone, tyff, brb, Ready, GLHF, ggty, ggnt | Hello, **At Stone**, Summon, Buffs please, Healthstone, tyff, brb, Ready, GLHF, ggty, ggnt |
| Solo > all seven | channel | Say | General (/1; Say when not joined) |
| Solo > Rare spotted (`bi.world.rare`) | text | `Rare spotted here: {target}` | `Rare spotted: {target} @ {coordinates}` |
| Solo > Elite help (`bi.world.elite`) | text | `Can anyone help with this elite? {target}` | `Can anyone help with this elite? {target} @ {coordinates}` |
| Solo > World boss (`bi.world.boss`) | text | `World boss up here: {target}` | `World boss up: {target} @ {coordinates}` |
| Solo > Event here (`bi.world.event`) | text | `World event starting here, come join` | `World event starting @ {coordinates}, come join` |
| `BI.COLOR` | entries | 9 | + `yellow = "fff468"`, `sky = "3fc7eb"` |

Not adopted, flagged: the 14 `%t` texts in the owner's profile (1.6), stale seeds of the pre-`65f3a5a`
defaults; the shipped `{target}` chip sends the same line.

## 3. Risks

| Risk | Mitigation |
| --- | --- |
| D2 changes a secure snippet on the live path. | The post reads one attribute written out of combat in the same `DS.Load` as the arming; live writes `false`. Headless cases pin the live close out of and in combat; firewall grep unchanged. |
| D2: a preview dial no longer closes after a pick. | Owner asked for exactly this; Escape, the key, the hub, a middle click and End preview still close it. |
| D1: Escape ends the edit preview but every render, `TEST_MODE_CHANGED` and combat end restarts it (1.1). | The session dismissal mark (2.1), honoured by `G.SyncEditPreview`, the one restart path; cleared only by a group switch, a page show, a setting write or End preview. Headless: still off after the scheduled Editors refresh and after a combat end. |
| D1: the start line prints on each open of the Groups page, and could print after every combat end. | One line per user-started edge (page show, setting ticked on); the combat-end restart is `quiet`; group switches and re-syncs have no edge. Headless case for the combat end. |
| D1: `/qc preview off` and End preview disagree. | Both call `P.EndPreview()`; headless case on the slash with only the edit preview on. |
| D4: `CHAT_MSG_CHANNEL` is registered always and fires for every channel line. | Early return when nothing is pending (existing); the channel index filter after it. Perf note. |
| D3: a new insecure `PreClick` hook on secure send buttons. | Out of combat only, writes through `SE.Arm` (the one writer), touches only buttons whose meta carries `rebake`; in combat it returns at once. Headless: a press in combat leaves the mock's `blocked` list empty. |
| D3: a stale position in combat. | Re-armed at the combat edge; documented ("in combat, where you were at the pull"). |
| D3: `GetPlayerMapPosition` returns a secret or nil in restricted content. | `PlainNumber` on every value; nil -> the token is dropped (live) or mocked (preview). |
| D4: channel 1 is not always General (a player can reorder). | Labelled "General (/1 ...)": it sends to channel 1, as the owner asked; the fallback covers "not joined". |
| D4: chat lockdown on public channels. | `LOCKS.general = LOCKS.say`: padlock in an encounter or PvP match, as Say. |
| D4: an import from this build into an older one carries `general` or `{coordinates}`. | Older builds reject `general` as `badChannel` and leave `{coordinates}` unknown, their usual handling; pre-release, no older build is in players' hands. |
| D4: existing profiles do not get the new defaults. | The owner's decision (no migration); Restore built-in groups brings a deleted set back with them. |

## 4. Tests (headless, red first)

- **D2** (`tests/test_dial_secure.lua`): `DS.Load(..., { preview = true })` -> a callout wedge click
  leaves the header shown, sends nothing; a live load still closes, out of and in combat; a ring wedge,
  the hub and a right click behave as before in a preview. (`tests/test_preview.lua`): Preview as
  Mythic+ -> the dial opens, a catcher click on a callout slice prints the echo and the dial stays
  shown; test mode the same; `/qc preview off` -> the live dial closes on a pick.
- **D1** (`tests/test_preview_window.lua`): the edit preview shows the window with the group's title
  and Current selected; picking Arena keeps the edit preview and sets Preview as; End preview ends both
  and turns `behavior.previewOnEdit` off; the close mark the same; Escape ends both and leaves the
  setting on, and **after the scheduled Editors refresh runs** (the mock's 0 s timer flushed, the page
  re-rendered) the edit preview is still off and the window still hidden; a group switch afterwards
  starts the new group's preview; hiding and showing the page starts it again; a combat end while
  dismissed leaves it off; closing the settings window with only the edit preview hides the window;
  `/qc preview off` with only the edit preview on ends it, writes the setting off, hides the window and
  prints `Preview off.`; with nothing on it prints `Preview off.` and writes nothing.
  (`tests/test_edit_preview.lua`): the start line prints once on the page-show edge and once on the
  setting ticked on, not on a group switch, not on a re-render, not on a refusal; with the page shown,
  entering combat prints `Preview ended: you entered combat.` and leaving it restarts the edit preview
  (window shown) **without** a `Previewing:` line; a dial wedge under the edit preview, clicked through
  its ring's catcher with the Groups page shown, prints its echo.
- **D3** (`tests/test_compat.lua`, `tests/test_tokens.lua`, a new `tests/test_coordinates.lua`): the
  shim's format and every nil path; the token and its alias expand, drop when missing, mock in an echo;
  the `PreClick` re-bake re-arms only a `rebake` button, only when the line changed, never in combat;
  the combat edge re-arms each once; the echo fills at the click: a Current (and an edit-preview)
  echo baked at one position and clicked after the mock player moved prints the **click-time**
  position (red under: `SlotEcho` keeping `ctx.coordinates`); the baked `slot.echo` holds the literal
  `{coordinates}`; an M+ preset echo prints `<coordinates>`.
- **D4** (`tests/test_channels.lua`, `tests/test_builtins.lua`, `tests/test_situation.lua`,
  `tests/test_send_guard.lua`): `general` resolves to `general` / `say`; prefix, chat type, lock; the
  snapshot reads and signs `general`; `CHANNEL_UI_UPDATE` and `CHAT_MSG_CHANNEL_NOTICE` are registered;
  `CHAT_MSG_CHANNEL` from the player with channel index 1 matches a `CHANNEL` send, from the player
  with index 2 does not (the press stays pending), from another player with index 1 does not, an
  unreadable index falls to the sender rule; `ECHO_EVENTS` has 10; `Pad_Render.TooltipLines` of a
  `general` slot has a `Channel: General` line in the `CHANNEL1` color; the Groups row's short label
  is `General`; the Solo set is
  `general` and bakes `/1 ...` with channel 1 joined, `/s ...` without; the four coordinate texts; the
  In Group rows with At Stone 2nd; Chain pull's and Hello's colors; Hello's text `Hello!`;
  `NS.MIGRATIONS` still ends at 9 (no step added).
- `tests/test_page_groups.lua` is at 1499 lines and is not grown.

## 5. In-client smoke (pending; the owner runs them)

New checks in `docs/smoke-tests.md`, each `Result: pending`, listed under Pending sign-off:
PREVIEW-11 (the window and start line over the edit preview; End preview and `/qc preview off` turn
the switch off; Escape closes the window and it stays closed until a group switch or the page is
reopened; after a pull and combat end the preview comes back with no `Previewing:` line; the echo on
a pad button and a dial slice while editing, `/qc debug` on), PREVIEW-12 (the dial stays open on a
slice click in Preview as, the edit preview and test mode; live still closes), TOKEN-1
(`{coordinates}` live in the open world, after walking, in a dungeon, in combat, in a preview echo),
SEND-6 (Solo sends to /1, **checked right after login and right after a zone change**; a line typed in
/2 inside the guard window does not count as the echo; leave General -> Say; the tooltip names
General in channel-1 color), STATE-6 (a new profile's prebuilts match 2.4 (d)).
