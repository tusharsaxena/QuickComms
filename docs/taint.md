# Taint notes — Ka0s Quick Comms

What keeps the addon's secure half untainted, in full. The hub, [`ARCHITECTURE.md`](ARCHITECTURE.md),
carries the summary. Every strata and frame level named here is defined once, in `core/Constants.lua`
`NS.Constants.LAYERS`, whose header comment records the whole stack; `tests/test_layers.lua` pins it.

## One secure file

Every secure rule lives in one file. `modules/SendEngine.lua` is the only code that creates a frame
from a `Secure*` template, calls `SetAttribute` or registers a state driver; `tests/test_sendengine.lua`
greps every other shipped file for `Secure*Template`, `SecureHandler`, `SetAttribute` (called or named
as a string), the state-driver and override-binding calls, and for `SendChatMessage` (D12: the secure
button is the one send path). `Bake` refuses a leading `/` at every bake, so no callout text is ever
run as a command.

## Send buttons and the pad

Send buttons are `SecureActionButtonTemplate`, named `QuickCommsSend<n>`, registered for `AnyUp` and
`AnyDown`, armed with `type=macro` and one baked `macrotext` line, and only out of combat
(`InCombatLockdown()`, events-frames-taint-§2). A pad's root becomes protected in combat because its
buttons are secure: its visibility is a `visibility` state driver, and its geometry is set only out of
combat, through `RunOrQueue` (rebuilds, which also re-anchor it from the active profile, the end of a
drag, Reset position). A rebuild asked for in combat is filed in SendEngine's keyed combat-end queue
(one entry per key, the last write winning) and drained at `PLAYER_REGEN_ENABLED`, which
`Restrictions` owns and hands to `SendEngine.Drain`, and on any later `RESTRICTION_CHANGED` out of
combat. Tabs and collapse are refused in combat.

A released button or wedge is parked armed: the pool hides it, so it takes no click. After a rebuild
places its buttons, and after `Pad.Release` / `Dial.Release`, every button the pool did not take back
is disarmed (Pad's `disarmFree`; Dial's `releaseFree`, which also releases the wedge's glow), so no
hidden button keeps a line. `SendEngine.Arm` writes nothing for an unchanged line, so a rebuild that
moved no line rewrites no button's `type` or `macrotext` (F-006, `3712c66`). Every one of these writes
happens inside Apply or Release, which never write in combat.

The click hook is an insecure `HookScript("OnClick")`: it cannot cancel the secure click, so the spam
guard is soft (spec §9.2), and it never reads chat text. Each send button also carries an insecure
`HookScript("PreClick")` (QF-03): for an armed live button whose callout text uses `{coordinates}` (its
meta's `rebake`, set by Pad's arm), it re-bakes the line with the position at the press and re-arms
through `SendEngine.Arm` when the line changed, out of combat only; in combat it returns before any
attribute write, so the button sends what it last held. The line is written by addon code exactly as
a rebuild's `Arm` writes it, only later, in the client's place for adjusting a secure action button's
attributes before it acts. A stand-down in combat holds its secure half in one private
`PLAYER_REGEN_ENABLED` registration, released when it fires.

## The Comms Dial's secure header

The Comms Dial (Relaxed mode) is one `SecureHandlerClickTemplate` header per dial,
`QuickCommsDial<n>`, created by SendEngine; its ring containers are `SecureFrameTemplate` frames, its
wedges are send buttons, and each ring's two page arrows are send buttons that never arm, wrapped by
the arrow snippet (a left click shows the page before or after, or does nothing at an end).
`modules/Dial_Secure.lua` holds the header's restricted snippets as text and hands them, every
attribute and every frame ref to SendEngine out of combat; the snippets themselves write no attribute
(the ring on screen is a global in the header's restricted environment; `tests/test_dial_secure.lua`'s
firewall case checks the snippet text, and the firewall grep, whose list includes a header's
`SetFrameRef`, `WrapScript` and `Execute`, covers the file).

In combat only the snippets act: they show and hide the rings and the hub, anchor the hub at the
cursor, and bind Escape, the wheel, 1–8 and (on a paged ring) the Left and Right arrow keys with
`SetBindingClick` while the dial is open from its key, releasing them with `ClearBindings`; an open
from the insecure side (test mode, Preview as…, `qc-display`) binds nothing. A callout wedge's post
snippet closes the dial after the pick unless the header's `qc-preview` attribute is set (QF-01, owner
2026-10-23): `DS.Load` writes it out of combat in the same call that loads the rings, true for a
preview, edit-preview or test-mode plan (`Dial.Apply` passes `plan.test`), whose wedges that same
rebuild disarms, and false for a live plan, so a preview dial stays open for the next pick while a
live pick closes exactly as before, in and out of combat; the snippet only reads it.

Each wedge's click is wrapped by the header before SendEngine hooks it (the client's wrap replaces the
script, which would drop an earlier hook); a wedge acts on the up edge and only a left click (or a
catcher's forwarded `w<n>`) is a press.

### The catchers

Since the dial polish (2026-10-21) a wedge takes no mouse (`EnableMouse(false)`, set at a rebuild out
of combat; `Dial_Layout.HitSize` and the hit insets retired): each ring has one secure catcher button
over its disc (`SendEngine.NewDialCatcher`, a `SecureActionButtonTemplate` registered for `AnyUp`
only), whose header-wrapped pre-click snippet reads the cursor with the restricted `GetMousePosition`,
works out the slice from the ring's `qc-size`, `qc-start`, `qc-hub` and `qc-disc` attributes (written
by `DS.Load` out of combat, the math of `Dial_Layout.SliceAt`) and returns `w<n>`, which the catcher's
`*type-w<n> = click` and `*clickbutton-w<n>` forward to that wedge (the any-modifier form: with Shift,
Ctrl or Alt held the client reads `shift-type-w<n>` and then `*type-w<n>`, never the plain key, so a
modified click still sends). Inside the hub's circle (`Dial_Layout.InHub`) the snippet runs the
header's `qc-up` snippet (up a ring, or close on the first ring; the header's own left click runs it
too) and returns nothing, any modifier held; an empty place or past the rim returns nothing.

The header itself takes no mouse (`EnableMouse(false)`, set at a rebuild out of combat; round hub,
2026-10-21): it is a square button and the hub is drawn round, so the catcher, centered on the hub, is
the only mouse target there and the hub starts and ends at its circle in every direction; the keys
still click the header by name (`SetBindingClick`, `CLICK QuickCommsDial<n>:Toggle`).

Each header also has a hidden full-screen catcher (`SendEngine.NewDialScreen`, a child of the header
set over `UIParent` in the `HIGH` strata, `AnyUp`): the header's show snippet shows it on a key open
(never on an insecure open) and the close snippet hides it, so any click outside the dial runs
`qc-close` and does nothing else. It is named in the hub's register row for frame-layering-§1/§4
until the standard rules on catchers behind a secure HUD popup.

### The insecure paint over it

The slices, the lit slice, the page row, the pointer and the tooltip's place are insecure textures and
anchors on the ring containers and the header (`modules/Dial_Slices.lua`, `modules/Dial_Render.lua`);
the hub's backdrop and circle and the pointer sit on a plain, mouse-off front frame whose level is
raised over the rings (an insecure call). The lit slice follows the cursor's bearing from the hub in
the pointer's per-frame update, and the hub's hover (its circle brightened, its "Why is this
showing?" tooltip) follows the cursor inside the hub's circle in the same update
(`DialRender.HoverHub`, no header `OnEnter`), so both work in combat with no protected call.

## Key bindings

The dials' keys are WoW's own key bindings of the `CLICK QuickCommsDial<n>:Toggle` entries, set in
Options → Keybindings or on the General page's Keybindings tab. The Dial page's Binding tab, an
in-panel key box, was retired in the dial rework (2026-10-21, `b902e35`); the owner's item 015
(2026-10-24) supersedes that removal with the library's editor (`O.KeybindingsTab`, LibKa0s v1.77.0,
options-ui-§20), drawn as General's last tab from `NS.BINDINGS`, not with the retired `Dial.BindKey`.
The library's tab writes `SetBinding` then `SaveBindings(GetCurrentBindingSet())` out of combat only,
keeps no key in the profile and follows `UPDATE_BINDINGS`; no file of this addon calls either.
`Dial.KeyOf` reads a key through `Compat.BindingKey`. No override binding is made, so a stand-down or
a rebuild leaves the keys alone.

`Bindings.xml` adds `CLICK QuickCommsTogglePads:LeftButton` (Toggle Comms Pads), first, then those
entries to WoW's own key bindings menu, every line in `category="BINDING_HEADER_QUICKCOMMS"` with no
`header=` (launcher-§6 as of standard v2.88.0), so the menu draws a section of its own titled Ka0s
Quick Comms; the binding names are unchanged, so no saved key is lost. Its labels are client-read
globals: the category global declared in `.luacheckrc` `globals` and assigned in
`settings/SlashVerbs.lua` beside the button and `NS.BINDINGS`, the five entry labels (not
identifiers) set with `rawset` (the four dials' in `modules/Dial.lua`, Toggle Comms Pads' in
`settings/SlashVerbs.lua`).

## The settings panel, the modal windows and the confirms

Opening the settings panel stays refused in combat by the options library, and the callout popup is
locked with it: its ctx is a panel ctx, so the library's combat cover lies over its page and refuses
Save and every draft write; Escape and the window's close X (outside the page) still cancel. The icon
browser is locked the same way (its ctx is a panel ctx too) and refuses Choose in combat, so nothing
it picks is written in combat.

The popup's window and the icon browser's are Blizzard's `SettingsFrameTemplate`
(`settings/ModalWindow.lua`), an insecure template with no protected child, each built on its first
Open. Both sit in the `FULLSCREEN` strata, one over the Comms Dial's `DIALOG`, so a preview dial's hub
never draws over them (the dial's secure header keeps its strata; `69719ca`, `0901b8c`), and the
browser is above the popup by a band of levels of its own (`ModalWindow.LEVEL_OVER`); its swatch
raises Blizzard's own `ColorPickerFrame` (AceGUI's ColorPicker widget) to `FULLSCREEN_DIALOG`, above
it. Both windows are clamped to the screen and deliberately not toplevel: the client raises a
toplevel frame to the top of its strata on every mouse-down, so the click on the popup's Choose icon…
would lift the popup over the browser's band as the browser opens (`36e6cd3`; register row for
frame-layering-§1/§4).

The preview window is `FULLSCREEN` too, at a client level under a modal's catcher, and is never
`Raise`d (the client's Raise would lift it over the modals in that strata). Quick Comms' confirms (the
deletes, Reset all) are Blizzard StaticPopups, `DIALOG` by default: each lifts its dialog to
`FULLSCREEN_DIALOG` while shown and hands the shared frame back in its own strata on hide
(`ModalWindow.LiftConfirm`), so a confirm is over the dial and over an open popup. While the browser
is open the popup's name is taken out of `UISpecialFrames` (put back on the next frame after the
browser closes), so Escape closes the browser only. The skin (a Ka0s skin, or EllesmereUI's through
LibKa0s-Skin-1.0's `eui` source, since the skinning rollout) paints those two windows' template chrome
with alpha-only primitives (`FadeNineSlice`, `FadeRegions`, given back under Ka0s Default), never
another Blizzard frame.

The editor pages touch no frame of a pad: every write reaches a pad through `LIBRARY_CHANGED` →
`Surfaces.Request`, so a write made in combat (a CLI `set`, a popup accepted after the pull) waits for
combat end behind the stale hint.

## Glows, title hit frames and the click preview

The Icons tab's border frame and LibCustomGlow-1.0's effect frames are plain (unprotected) children
of a button's or a wedge's icon: made out of combat at a rebuild, they can be shown, anchored and
animated in combat, so a hover or an After sending glow starts and stops in combat with no protected
call (`tests/test_glow.lua` checks the mock's refusal list stays empty); an Icons tab write changes
button geometry (the icon size), so it reaches the surfaces through the rebuild, queued behind combat
like any write. LibKa0s-Glow-1.0 resolves LibCustomGlow-1.0 at call time, and nothing is drawn
without either.

A pad's section titles each carry a plain (non-secure) hit frame, a child of the pad's root made,
placed and sized at a rebuild out of combat; its right-click reaches `QC:EditGroup`, which in combat
opens nothing and prints the settings refusal. The PREVIEW and TEST MODE marker is the drag strip's
label text, set at a rebuild; the strip is not protected.

A click on a previewed button or wedge, or on a test-mode placeholder (each disarmed: no `type`, so
the secure half does nothing), is taken by the same insecure `OnClick` hook every send button already
carries, not by an overlay (which would steal the mouse from the dial's secure catcher and need an
insecure Show/Hide): the hook runs after the secure handler and cannot cancel or taint it, and on a
disarmed button's echo it only prints a string baked out of combat with the plan, filling `%t` and
`%f` with `Compat.UnitDisplayName`, a read (QC-07). It calls no send API, stamps no guard and awaits
no echo; an armed button carries no echo, so live presses are unchanged.
