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
`Library.Prepare()` (seed, append newly shipped built-ins, repair the registry, lift `nextId`), a panel
refresh, the latch re-read from the incoming profile's `enabled`, then `NS.MSG.PROFILE_CHANGED`.

## Today: a restriction or combat edge

`ADDON_RESTRICTION_STATE_CHANGED` or a `PLAYER_REGEN` edge → `Restrictions` (it owns both
`PLAYER_REGEN` rows) → when the set of blocking reasons moves, `RESTRICTION_CHANGED (reason,
canSendChat)` → Situation refreshes the snapshot's `lockdown` and `inCombat` in place. The signature
does not move and no `SITUATION_CHANGED` is sent. `PLAYER_REGEN_ENABLED` also drains SendEngine's
combat-end queue directly, whether or not the restriction set moved.

## Today: `/qc check <id>`

```
/qc check ─> Library.Callout(id) ─> Situation.Current() ─> Bake.Bake(callout, snapshot, {soloFallback})
                                                                 │  tokens, channel, sanitize
                                                                 ▼
                                              line, channel, bytes, lock  ─> NS.Print   (never sends)
```

The verb bakes the line the pad would arm, and never sends it.

## Today: a callout is pressed

The chip is a secure button armed with one baked line. The game sends the line (the secure path; nothing in Lua sends). The button's `OnClick` hook runs on the acting edge: `SendEngine` classifies the press against the last one (`guarded` inside `behavior.spamGuard`, reported at once), records it for the echo tracker, and dims every chip for the window. A `CHAT_MSG_*` of the same chat type from the player within 1.5 s makes it `sent`; none makes it `dropped`, with one `[QC]` note. `SEND_RESULT` flashes the chip.

## Today: something changes that a pad draws

`SITUATION_CHANGED`, `LIBRARY_CHANGED`, `PROFILE_CHANGED`, `TEST_MODE_CHANGED` and the settings reactions all call `Surfaces.Request`. Out of combat it rebuilds every enabled pad from the current snapshot (`BuildPlan` → `Pad.Sync`). In combat it files one `surfaces` entry in the combat-end queue, shows the stale hint and sends `SURFACE_REBUILT (id, true)`; at combat end the queue drains, the pads rebuild from the snapshot as it is then, and `COMBAT_QUEUE_DRAINED` clears the hints. `RESTRICTION_CHANGED` re-reads only the padlocks, the lockdown chip and the fade, which change in combat too.

## Today: test mode

The checkbox, `/qc test` and the launcher entry call `Preview.SetTestMode`. It is refused in combat and stood down, and `RESTRICTION_CHANGED` with the combat edge ends it. `TEST_MODE_CHANGED` makes `Surfaces` draw each pad from `TestPlan`: placeholder chips, disarmed, that send nothing.

## Today: an editor writes a member

A widget on an editor page (or `/qc set group.name …`) writes a member row through the seam: `resolveRoot` finds the member (`Library.Member`) by the instance argument or the page's selection (a callout only by its id: `/qc set callout.text <id> …`), the row validates and stores the field, and its `onChange` calls `Library.Touch`, which sends `LIBRARY_CHANGED`. `Surfaces.Request` rebuilds the pads (in combat: queued, with the stale hint). A name, Enabled or When write (`Editors.STRUCTURAL`), or a membership change, repaints every editor page once on the next frame; any other field write refreshes the widgets and the live lines in place. Creating, deleting, duplicating, reordering and Customize are Library's own operations and end the same way. An act of several writes (Customize, New group, a page's Defaults) runs inside `Library.Batch`, which sends one `LIBRARY_CHANGED` for the whole act, so the pads rebuild once.

## Today: the callout popup saves

A user group's callouts belong to it, and are edited in the callout popup (`settings/CalloutPopup.lua`), never on a page of their own. Add callout or a row's edit glyph opens it on a **draft**: a plain copy of the callout's four fields and its icon's glyph color (blank for Add). The controls write the draft only; the token list and What it sends here bake the draft (`Settings.Callouts.PreviewLines`), so nothing reaches the profile or the pads while the player edits. Save checks the draft with the `callout.*` rows' validators, then writes one act in `Library.Batch`: for a listed callout, each field that differs from the copy taken at open goes through the seam by id (`SchemaRuntime.Set("callout.<field>", v, id)`; the icon before its color, which the color row checks against); for Add, `Library.CreateCalloutIn` creates the callout and puts it at the end of the group. One `LIBRARY_CHANGED` follows, as for any act. Cancel, Escape, the close X, the settings window hiding, a profile change, the stand-down and a `LIBRARY_CHANGED` that removes the callout or its group drop the draft and write nothing. Reuse's Add (`Library.AddToGroup`) and the remove glyph (`Library.RemoveFromGroup`, after the confirmation) are Library operations: the first adds an independent copy, the second deletes the callout it takes out.

## Today: an icon is chosen

Choose icon… (`Ed.IconChooser`, in the callout popup or on a user group's General tab) opens the icon browser (`settings/IconBrowser.lua`) on the stored icon and color, with an `onChoose` the opener supplies. The browser writes nothing itself: its tabs read their lists from `settings/IconBrowser_Sources.lua` (the game icons through `Compat.MacroIcons`, kept once the client answers with icons), and its selection and color are local to it. Choose hands `onChoose(icon, color)` the icon and, for a LibKa0s glyph, its color (none for white or for any other icon), then closes. The popup's `onChoose` writes its **draft** (`Pop.SetIcon`; Save writes it later, as above). A group's writes the profile in one act: `Library.SetIcon("group", id, icon, color)` sets `group.icon`, then `group.iconColor` (cleared unless the icon is a glyph), through the seam inside `Library.Batch`, so one `LIBRARY_CHANGED` rebuilds the surfaces. The swatch beside the editor's icon writes the color alone (the draft's, or `group.iconColor` through the seam). Any other write to an icon row that leaves a colored member without a glyph (the Icon box, `/qc set`) clears the color in the same act: the icon rows' `onChange` sets `<kind>.iconColor` to none inside a `Library.Batch` before it announces. Cancel, the close X, Escape, the opener closing, the settings window hiding, a profile change, the opener's member gone and the stand-down close the browser and write nothing.

Every place a member's icon is drawn (a pad's chips, a dial's wedges and ring wedges, the Groups page's callout rows, the editors' icon, the browser's grid and footer) sets its tint from `Library.IconTint(icon, color)`, white included: a pooled texture keeps the last tint it was given. The slot and ring plans carry `iconColor` beside `icon` (`Surfaces.Slot`, `Surfaces.BuildDialPlan`, `Dial_Layout`).

## Today: Preview as…

`Preview.SetPreviewAs(key)` (the General tab's row, `/qc preview`) turns test mode's second flavor on: `TEST_MODE_CHANGED`, then `Surfaces.ApplyAll` builds each pad from the previewed snapshot and marks the plan, so every chip is disarmed and the header reads `Preview: …`. Combat, the stand-down and the settings window closing end it.

## Today: the Comms Dial

A rebuild (`Surfaces.ApplyAll`, out of combat) builds each enabled dial's plan (`Surfaces.BuildDialPlan`: the active groups in the dial's order, each slot baked, then `Dial_Layout.Rings`), and `Dial.Sync` re-acquires the dial's ring containers and wedges, arms each callout wedge with its baked line, hands the rings to the header (`DialSecure.Load`, through SendEngine) and re-binds every dial's key (`SendEngine.BindKeys`). Pressing the key clicks the header with `Toggle`: its snippet shows the ring the plan opens on and binds Escape, the wheel and 1–8. A group wedge's wrapped click shows that group's ring; a callout wedge's click sends its `macrotext` (the hook tracks it like a chip's) and its post snippet closes the dial. In combat only the snippets run; a change waits for combat end behind the hub's stale hint.

## Today: sharing

Export: the ticks (`NS.State.share.pick`) go to `Share.Collect`, which adds what they need (a pad's or a dial's user groups, a group's callouts) and reads each pad's and dial's portable fields through the seam (`Share.FieldsOf`); `Share.Encode` makes the `!QC1!` string, and the copy window shows it selected. A callout travels only inside its group: Export has no callout ticks. Import: the pasted string goes to `Share.Check` (decode, version, schema checks, a callout no imported group holds left out and counted in the report, `Bake.CleanText` over every text field and nested key, names and field strings stored with their `|` escapes literal), the page shows `Share.ReportLines` (an edit to the box forgets the check, so Import needs a fresh Accept), and Import hands the result to `Share.Apply`, which calls `Library.Import`: fresh ids, one copy of a callout per group that holds it (a glyph's color travels with its callout or group; an old string without one arrives untinted, and a malformed color is dropped and counted with the ignored fields, with no payload version change), references remapped, a surface's fields through the seam, no key or position, all in one `Library.Batch`, so one `LIBRARY_CHANGED` rebuilds the surfaces (at combat end, if need be) and repaints the pages.

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
