# Data flow — Ka0s Quick Comms

## Today: a setting changes

```
panel checkbox ─┐
/qc set|enable ─┼─> NS.SchemaRuntime.Set(path, v) ─> store ─> [Set] line ─> row.onChange ─> announce
launcher entry ─┘                                                   │                    │
                                                    Settings.REACTIONS[path]       panel refresh
                                                    (enabled → the latch's `disabled` hold)
```

Every module reads a setting back through `NS.Setting(path)`.

## Today: enable and disable

`enabled = false` → `Lifecycle:Set("disabled", true)` → `NS.StandDown`: every `NS.FEATURE_EVENTS`
row unregistered, tracked bus registrations taken down, each module's `NS.STAND_DOWN` step run. The
stand-up re-registers and runs each `NS.STAND_UP` step from current settings. The perf harness's
suspend takes the same latch's `perf` hold.

## Today: a profile event

AceDB's switch, copy or reset → `reloadProfile` (`core/QuickComms.lua`): the migrations,
`Library.Prepare()` (the default pad and dial and the seeded sets once, a newly shipped set seeded,
the registry repaired, a bad parent dropped, `nextId` lifted), a panel refresh, the latch re-read
from the incoming profile's `enabled`, then `NS.MSG.PROFILE_CHANGED`.

## Today: the built-in sets are seeded

The shipped sets (`NS.BuiltIns`, `defaults/BuiltIns*.lua`) are seed data. A profile `Library.Prepare`
has never prepared (a new or a reset one) gets the default pad and dial, then every shipped set, in
shipped order, as ordinary user groups and callouts under fresh ids from `nextId`: each group's
callouts take their ids before it, and a battleground's nodes come after their set as groups inside
it (`parent`); `Library.Children` lists a group's children A–Z by name (then made order), so a
set's nodes read alphabetically everywhere (2026-10-25). Each seeded member keeps its
shipped id as `origin`, a node its `compass` wind, and `profile.seededSets` records every set and
node given. The top-level sets go on the default pad and dial. From then on they are ordinary groups:
every edit, delete and duplicate is the player's, and nothing at draw time reads `NS.BuiltIns` for
them. A set a later version ships is seeded by the next `Prepare` at the end of every pad and dial;
a deleted one is never seeded again by `Prepare`. A stored profile from before the seeding is
converted once by migration step 3 (`Library.SeedFromOverlay`, `docs/schema.md`).

Restore built-in groups (the Groups page's General tab) calls `Library.RestoreBuiltins`, one act in
`Library.Batch`: each shipped set and node is matched by origin against the profile's groups, and
each shipped callout by origin among the callouts of its seeded group; what is missing is seeded
again, fresh, and a set that came back
goes at the end of every pad and dial. One `LIBRARY_CHANGED` rebuilds the surfaces and repaints the
pages, and the page prints one line with the counts.

## Today: a group inside another

A group's `parent` (the `group.parent` row) puts it inside a top-level group, one level deep
(`Library.ValidParent`). The write's `onChange` runs `Library.SettleParent` and `Library.Touch` in
one `Library.Batch`, taking the group off every pad and dial. A rebuild draws a parent where the
surface lists it: `Surfaces.BuildPlan` gives a pad a section for the parent's own callouts (when it
has any), then one section per child that the Resolver finds active, in `Library.Children`'s order;
`Surfaces.BuildDialPlan` gives a dial the parent's own callouts first, then a node ring per active
child (pinned to the compass winds when every child has one, the parent's own callouts then taking
one more wedge on the first free wind). The parent's When and Enabled gate the whole family, and a child that inherits its When
conditions (`group.inheritWhen`, on unless stored `false`) is judged by the parent's When instead of
its own (`Resolver.WhenOf`). Deleting a parent (`Library.DeleteGroup`)
makes its children top-level groups, in its place on every pad and dial, in one act.

## Today: General joined or left

`CHANNEL_UI_UPDATE` or `CHAT_MSG_CHANNEL_NOTICE` (the notice also covers the automatic joins after login
and the zone's channel swap) → `Situation.Refresh` → `ReadInputs` reads `Compat.GeneralJoined()` into
the snapshot's `general`, a signature field → a join or leave sends `SITUATION_CHANGED` and the pads
rebuild, so a `general` callout bakes `/1 text` while channel 1 is joined and `/s text` when it is not
(QF-04). A notice for any other channel leaves the signature, so nothing rebuilds.

## Today: a restriction or combat edge

`ADDON_RESTRICTION_STATE_CHANGED` or a `PLAYER_REGEN` edge → `Restrictions` (it owns both
`PLAYER_REGEN` rows) → when the set of blocking reasons moves, `RESTRICTION_CHANGED (reason,
canSendChat)` → Situation refreshes the snapshot's `lockdown` and `inCombat` in place. The signature
does not move and no `SITUATION_CHANGED` is sent. `PLAYER_REGEN_ENABLED` also drains SendEngine's
combat-end queue directly, whether or not the restriction set moved. On the edge into combat, still
writable, SendEngine re-arms each `{coordinates}` button once with the position at the pull
(`RefreshRebakes`, QF-03).

## Today: `/qc check <id>`

```
/qc check ─> Library.Callout(id) ─> Situation.Current() ─> Bake.Bake(callout, snapshot, {soloFallback})
                                                                 │  tokens, channel, sanitize
                                                                 ▼
                                              line, channel, bytes, lock  ─> NS.Print   (never sends)
```

The verb bakes the line the pad would arm, and never sends it.

## Today: a callout is pressed

The button is a secure button armed with one baked line. The game sends the line (the secure path; nothing in Lua sends). A button whose text uses `{coordinates}` is re-baked first, in its insecure `PreClick` hook, out of combat only: the line with the position as it is now replaces the armed one when it differs, and the secure handler that runs next sends it (bake → press re-bake, QF-03); in combat it sends what it holds. The button's `OnClick` hook runs on the acting edge: `SendEngine` classifies the press against the last one (`guarded` inside `behavior.spamGuard`, reported at once), records it for the echo tracker, and dims every button for the window. A `CHAT_MSG_*` of the same chat type from the player within 1.5 s makes it `sent`; none makes it `dropped`, with one `[QC]` note. `SEND_RESULT` flashes the button.

## Today: something changes that a pad draws

`SITUATION_CHANGED`, `LIBRARY_CHANGED`, `PROFILE_CHANGED`, `TEST_MODE_CHANGED` and the settings reactions all call `Surfaces.Request`. Out of combat it rebuilds every enabled pad from the current snapshot (`BuildPlan` → `Pad.Sync`); each button's paint (`PadRender.ApplyButtonLook`) ends with the Buttons tab's shine over the whole button (`NS.Shine.Apply`, from `ButtonLook`'s `shine`, `NS.Shine.Resolve`; None hides it). In combat it files one `surfaces` entry in the combat-end queue, shows the stale hint and sends `SURFACE_REBUILT (id, true)`; at combat end the queue drains, the pads rebuild from the snapshot as it is then, and `COMBAT_QUEUE_DRAINED` clears the hints. `RESTRICTION_CHANGED` re-reads only the padlocks, the lockdown chip and the fade, which change in combat too.

## Today: test mode

The checkbox, `/qc test` and the launcher entry call `Preview.SetTestMode`. It is refused in combat and stood down, and `RESTRICTION_CHANGED` with the combat edge ends it. `TEST_MODE_CHANGED` makes `Surfaces` draw each pad from `TestPlan` and each dial from `TestDialPlan`: placeholder buttons and wedges, disarmed, that send nothing, in four groups of 4, 8, 12 and 16 (`Surfaces.TEST_COUNTS`; owner, 2026-10-21), each wearing a shipped callout's name and icon read from the seed table (`NS.BuiltIns`). Nothing of it is written to the profile.

## Today: an editor writes a member

A widget on an editor page (or `/qc set group.name …`) writes a member row through the seam: `resolveRoot` finds the member (`Library.Member`) by the instance argument or the page's selection (a callout only by its id: `/qc set callout.text <id> …`), the row validates and stores the field, and its `onChange` calls `Library.Touch`, which sends `LIBRARY_CHANGED`. `Surfaces.Request` rebuilds the pads (in combat: queued, with the stale hint). A name, Enabled, When, Parent group, Inherit when conditions, or an Icons tab's Glow or Glow style write (`Editors.STRUCTURAL`), or a membership change, repaints every editor page once on the next frame; any other field write refreshes the widgets and the live lines in place. Creating, deleting, duplicating, reordering and restoring are Library's own operations and end the same way. An act of several writes (New group, Restore built-in groups, a Parent group write with the surfaces it leaves, a page's Defaults) runs inside `Library.Batch`, which sends one `LIBRARY_CHANGED` for the whole act, so the pads rebuild once.

## Today: the callout popup saves

A user group's callouts belong to it, and are edited in the callout popup (`settings/CalloutPopup.lua`), never on a page of their own. Add callout or a row's edit glyph opens it on a **draft**: a plain copy of the callout's four fields and its icon's glyph color (blank for Add). The controls write the draft only; Preview bakes the draft (`Settings.Callouts.PreviewLines`) and the Text label's token tooltip reads its channel (`Settings.Callouts.TokenHelp`), so nothing reaches the profile or the pads while the player edits. Save checks the draft with the `callout.*` rows' validators, then writes one act in `Library.Batch`: for a listed callout, each field that differs from the copy taken at open goes through the seam by id (`SchemaRuntime.Set("callout.<field>", v, id)`; the icon before its color, which the color row checks against); for Add, `Library.CreateCalloutIn` creates the callout and puts it at the end of the group. One `LIBRARY_CHANGED` follows, as for any act. Cancel, Escape, the close X, the settings window hiding, a profile change, the stand-down and a `LIBRARY_CHANGED` that removes the callout or its group drop the draft and write nothing. Reuse's Add (`Library.AddToGroup`) and the remove glyph (`Library.RemoveFromGroup`, after the confirmation) are Library operations: the first adds an independent copy, the second deletes the callout it takes out.

## Today: an icon is chosen

Choose icon… (`Ed.IconChooser`, in the callout popup or on a user group's General tab) opens the icon browser (`settings/IconBrowser.lua`) on the stored icon and color, with an `onChoose` the opener supplies. The browser writes nothing itself: its tabs read their lists from `settings/IconBrowser_Sources.lua` (the game icons through `Compat.MacroIcons`, kept once the client answers with icons), and its selection and color are local to it. Choose hands `onChoose(icon, color)` the icon and, for a LibKa0s glyph, its color (none for white or for any other icon), then closes. The popup's `onChoose` writes its **draft** (`Pop.SetIcon`; Save writes it later, as above). A group's writes the profile in one act: `Library.SetIcon("group", id, icon, color)` sets `group.icon`, then `group.iconColor` (cleared unless the icon is a glyph), through the seam inside `Library.Batch`, so one `LIBRARY_CHANGED` rebuilds the surfaces. The clear glyph beside Choose icon… calls the same `onChoose` with no icon and no color (the draft emptied, or `Library.SetIcon` with `false`), the one way back to no icon in the panel. The swatch beside the editor's icon writes the color alone (the draft's, or `group.iconColor` through the seam). Any other write to an icon row that leaves a colored member without a glyph (`/qc set`; the editors draw no Icon box) clears the color in the same act: the icon rows' `onChange` sets `<kind>.iconColor` to none inside a `Library.Batch` before it announces. Cancel, the close X, Escape, the opener closing, the settings window hiding, a profile change, the opener's member gone and the stand-down close the browser and write nothing.

Every place a member's icon is drawn (a pad's buttons, a dial's wedges and ring wedges, the Groups page's callout rows, the editors' icon, the browser's grid and footer) sets its tint from `Library.IconTint(icon, color)`, white included: a pooled texture keeps the last tint it was given. The slot and ring plans carry `iconColor` beside `icon` (`Surfaces.Slot`, `Surfaces.BuildDialPlan`, `Dial_Layout`).

## Today: Preview as…

The menu (`Preview.Presets`, owner 2026-10-25) is Current; one M+ entry per current-season dungeon (`mplus:<id>`, `NS.GameIds.DUNGEONS`, A-Z by the client's name); one Mythic entry per current-season raid (`raid:<id>`, `Raid · Mythic · The Voidspire`, `NS.GameIds.RAIDS`, A-Z); Arena; one `BG - <name>` entry per battleground set; and Solo.

`Preview.SetPreviewAs(key)` (the row in General › Master controls, `/qc preview`) turns test mode's second flavor on: `TEST_MODE_CHANGED`, then `Surfaces.ApplyAll` builds each pad from the previewed snapshot and marks the plan, so every button is disarmed (a click prints the line it would have sent, `[QC] /p Pulling next pack`, through `NS.Print`, and sends nothing: `Surfaces.MarkPreview` bakes each slot's echo with `Preview.SlotEcho`, the callout re-baked with `Preview.MOCK` standing in for a baked value missing there, or `(nothing sent: <reason>)` in `PadRender.REASON_TEXT`'s words, and the click hook fills `%t`, `%f`, raid markers and group tokens with `Preview.FillEcho`; a test-mode placeholder's echo is its name and `(test-mode placeholder: nothing sent)`, QC-07; the echo names no padlock, since locks read your real group rather than the previewed situation, so it is what the press would send), the header reads `Preview: …` and the drag strip reads `<pad name>  PREVIEW` (test mode's reads `TEST MODE`; the strip shows while it carries the marker, locked or not). Current previews the live snapshot, where you are. The preview window (`modules/PreviewWindow.lua`) is up while it or the edit preview is on, whichever way it started: Preview's announce and its stand-down call `PreviewWindow.Sync`, the window's dropdown goes back through `SetPreviewAs`, and End preview and the close mark through `Preview.EndPreview`. `off`, End preview, the window's close mark or Escape, test mode, combat and the stand-down end it; closing the settings window does not.

The edit preview sits over both flavors. While the Groups page is on screen with Preview while
editing ticked (`behavior.previewOnEdit`), `Groups.SyncEditPreview` (run on every draw, on the page's
show and hide, on the setting's write and on `RESTRICTION_CHANGED`) hands the selected group to
`Preview.SetEditPreview(gid)`: `TEST_MODE_CHANGED`, then `Surfaces.ApplyAll` sets `deps.only`, so each
pad and dial skips the Resolver and draws that group with every group inside it, marked
(`plan.editGroup`) and disarmed as a Preview as plan (a click echoes its line the same way), still baked against the Preview as snapshot when
one is set. The page hiding, the settings window closing, combat and the stand-down end it; Preview
as and test mode, left as they were, come back. Once combat ends it comes back while the page is
still on screen.

## Today: the Comms Dial

A rebuild (`Surfaces.ApplyAll`, out of combat) builds each enabled dial's plan (`Surfaces.BuildDialPlan`: the active groups in the dial's order, each slot baked, the dial's radius as `plan.radius`, then `Dial_Layout.Rings`: one active group opens straight on its ring, several on the ring of groups; each ring paged at the dial's slices, every unpinned page placed from N, clockwise (W until 2026-10-22), and Auto capped at the slices whose arc still fits an icon, `Dial_Layout.AutoCap`), and `Dial.Sync` re-acquires the dial's ring containers and wedges, sizes the rings to the radius, paints each ring's slices (a tinted pie-slice fill per wedge place, each moved out by the Slice gap, `Dial_Slices.Paint`, then each slice's shine from `DialRender.Look`'s `shine`: the look's layers placed as the fill, the whole-disc ones cut by the slice's mask, the places past the ring's size hidden), paints the hub in its Hub style and sizes the header to the Hub size, arms each callout wedge with its baked line and places it at the Icon offset with its mouse off, sizes each ring's catcher to the disc, places each paged ring's two page arrows and paints its pill and dots in the Paging tab's sizes and colors, paints the labels outside the disc (or at the Label offset) in the Labels tab's Slice labels font (or hides them) and the ring's title in its Group labels font, sizes, colors and places the pointer, raises the hub's front frame over the rings (`DialRender.RaiseFront`), works out where the dial's tooltips go (`DialRender.PlaceTips`), and hands the rings, their page targets, their arrows, each ring's catcher with its shape and forwards and the screen catcher to the header (`DialSecure.Load`, through SendEngine). The key is not re-bound: it is WoW's own binding of the place's `CLICK QuickCommsDial<n>:Toggle` entry, set in Options → Keybindings or on General → Keybindings. Pressing the key clicks the header with `Toggle`: its snippet shows the ring and page a key open was last closed on (owner, 2026-10-22: each ring's `qc-key-<r>`, its path of group and node ids from `Dial_Layout.Rings`, and `qc-page-<r>`, so it outlives a rebuild; that ring's first page when the page is gone; else the ring the plan opens on; an insecure open, test mode or Preview as, shows the plan's and leaves the memory alone) and the full-screen catcher (a click outside the dial closes it) and binds Escape, the wheel, 1–8 and, on a paged ring, the Left and Right arrow keys. A page arrow's wrapped click, the arrow keys and the wheel show the page before or after (nothing at an end); the hub goes up a ring from any page. A group wedge's wrapped click shows that group's ring; a callout wedge's click sends its `macrotext` (the hook tracks it like a button's) and its post snippet closes the dial. On a preview, edit-preview or test-mode dial the wedge is disarmed, so the click sends nothing and the hook prints its echo, and the post snippet leaves the dial open (the header's `qc-preview`, written by `DialSecure.Load` from `plan.test`; QF-01), so the next slice can be tried at once. While the dial is open, the pointer's per-frame update turns the pointer toward the cursor and lights the slice its bearing points into, anywhere on the disc outside the hub's circle (`Dial_Slices.Track`), giving it its wedge's tooltip and hover glow, and inside the circle hovers the hub (its circle brightens and its "Why is this showing?" tooltip shows, `DialRender.HoverHub`); closing clears both. The header takes no mouse, so every click on the disc, the hub's included, lands on the ring's catcher: inside the hub's circle (`Dial_Layout.InHub`) its snippet runs the header's `qc-up` (up a ring, or close on the first ring); a right click on a slice runs `qc-back` (up a ring, or nothing on the first ring; owner, 2026-10-22), on the hub or past the rim it closes; else it works out the same slice (`Dial_Layout.SliceAt`'s math) and forwards the click to its wedge (through `*type-w<n>`, so a click with a modifier held still sends). In combat only the snippets run; a change waits for combat end behind the hub's stale hint.

## The design's callout pipeline (spec §4.1)

```
 game events ─► Situation ──SITUATION_CHANGED──► Resolver ──ACTIVE_GROUPS_CHANGED──► Surfaces
 (zone, key,    (classify the                 (When rules → active           (Pad, Dial:
  group, spec,   snapshot)                     groups, per-surface order)      layout, render)
  restriction)                                     ▲                                │ slot plans
 Library (the registry writer) ──LIBRARY_CHANGED───┘                                ▼
                                                              Bake (tokens, channel, sanitize →
                                                              one macro line, out of combat)
                                                                                    │
                                                                                    ▼
                                         SendEngine (the only secure-attribute writer: button pool,
                                         combat-end queue, bindings, spam guard, echo tracker)
```

The README's `## How the callouts work` is the same pipeline told for players. Every stage exists
including the Dial and its bindings; today `Surfaces` resolves and bakes inside its own
rebuild, and `ACTIVE_GROUPS_CHANGED` is sent from there.
