# Smoke tests — Ka0s Quick Comms

The in-client checks the headless suite cannot make: what the real client draws, what its events
really carry, and what Blizzard's restrictions really allow. Run them on a clean `/reload`, with
debug logging off unless a check says to turn it on (`/qc debug on`). Record each result on its
`Result:` line with the date, the client build and pass or fail (and what was seen when it failed).
IDs are `<THEME>-<n>`: a new check takes the next free number in its theme, and a retired number is
never reused. A number marked *reserved* is promised to the feature named beside it, which writes
the check when it lands. These checks are the owner's to run; an agent never marks one passed.

## Index

| ID range | Theme | What it covers |
|---|---|---|
| INSTALL-1..3 | Install | Load, reload, first run, the logo |
| SLASH-1..2 | Slash | `/qc` and `/quickcomms`, help, a slash collision |
| PANEL-1..3 | Settings panel | Landing page, General → Master controls, the Defaults button |
| PROFILE-1..2 | Profiles | The Profiles page and the `profile` verb |
| STATE-1..2 | State | Enable/disable, the launcher menu |
| COMBAT-1 | Combat | The settings panel in combat |
| DIAG-1..2 | Diagnostics | The debug console, the report, perf |
| DEGRADED-1 | Degraded | The install with LibKa0s missing |
| SEND-1..5 | Send | Secure sends in keys and on bosses, the spam guard |
| PAD-1..8 | Pad | The Comms Pad |
| EDIT-1..13 | Editors | The Groups (with the callout popup and its EllesmereUI look, Reuse and the glyph lists), Comms Pad and Share pages, Preview as…, Why is this showing? |
| DIAL-1..12 | Dial | The Comms Dial (Relaxed), its key and Bindings.xml, the battleground node dial |
| SHARE-1..6 | Share | Export and import strings, the report, refusals, unbound pads and dials |
| LOOK-1..2 | Look | The Comms Pad's font, border and background |
| ICON-1 | Icons | The icon picker |
| BG-1..2 | Battlegrounds | Node winds on the dial; the battleground instance ids |
| IDS-1 | Instance ids | The Midnight dungeons and raids |
| LOC-1 | [Non-English client](#non-english-client) | What a deDE or frFR client changes |

## Before you start

- Install the addon folder as `Interface\AddOns\QuickComms` and `/reload`.
- Keep the debug console closed unless a check opens it; `/qc debug` opens it.

## Install

**INSTALL-1. Loads clean.** `/reload` with only Quick Comms enabled → no Lua error, no chat line at
login, the addon listed in the AddOns list with the gold speech-bubble logo. Result:

**INSTALL-2. Minimap button and broker.** Look at the minimap → the speech-bubble button is there;
hover it → the tooltip reads `Ka0s Quick Comms  v0.1.0`, `Enabled: Yes`, then the two click hints. A
missing icon (a blank or green square) is the failure. Result:

**INSTALL-3. Reload keeps settings.** Untick **Minimap button**, `/reload` → the button stays
hidden; turn debug logging on with `/qc debug on`, `/reload` → it is off again (session-only).
Result:

## Slash

**SLASH-1. Help.** `/qc help` and `/quickcomms help` → the same index, gold commands, white
descriptions, every row present; `/qc` alone opens the settings panel. Result:

**SLASH-2. No collision on `/qc`.** With the addons you normally run enabled, `/qc help` → Quick
Comms' index, not another addon's. Another addon answering, or nothing at all, is the failure (design
spec §3's phase 0 collision check). Result:

## Settings panel

**PANEL-1. Landing page.** Settings → AddOns → Ka0s Quick Comms → the logo once (not twice after
switching pages back and forth), the notes line, and the slash command list. Result:

**PANEL-2. Master controls.** General → the `Master controls` tab: Enable Ka0s Quick Comms beside
General visibility, Master scale beside Master alpha, Lock frame beside Debug console, Minimap button
beside Test mode, then Reset position beside Reset all settings. Ticking Debug console opens the
console; unticking Minimap button hides the button at once. Result:

**PANEL-3. Defaults and Reset all.** Hide the minimap button, untick Enable, press the header's
Defaults button and accept → Enable is ticked again and the minimap button stays hidden. Result:

## Profiles

**PROFILE-1. The Profiles page.** Settings → Ka0s Quick Comms → Profiles → AceDB's page draws;
create a profile, untick Enable, switch back → the first profile is still enabled. Result:

**PROFILE-2. The profile verb.** `/qc profile` lists the profiles; `/qc profile <name>` switches,
and works while the addon is disabled. Result:

## State

**STATE-1. Disable stands everything down.** `/qc disable` → `/qc help`, `/qc version`, `/qc list`
and `/qc diagnostics` still answer; the minimap menu's Enabled entry is unticked and still clickable;
`/qc enable` → enabled again, and `enabled = true` is echoed. Result:

**STATE-2. Launcher menu.** Right-click the minimap button → three entries, Enabled, Locked and Test
mode, each ticking the state it shows and toggling it; left-click → the settings panel opens.
Result:

## Combat

**COMBAT-1. The panel in combat.** Pull a training dummy and type `/qc` → a gray notice that the
panel can't open in combat, and no Lua error; with the panel already open on General, enter combat →
the page is covered and its controls refuse until combat ends. Result:

## Diagnostics

**DIAG-1. The report.** `/qc diagnostics` → the console opens with both markers naming Ka0s Quick
Comms and the `identity`, `settings`, `registration`, `integrations`, `situation`, `restrictions`,
`library`, `surfaces` and `send` sections; logging is on
afterwards. `/qc debug diagnostics` writes the same report again below the first. Result:

**DIAG-2. Perf.** `/qc perf` → the step panel opens with its own close mark; run A, B and finish →
the report prints the `bakeSurface`, `sendClick`, `padLayout` and `echoMatch` rows and no Lua
error. Result:

## Degraded

**DEGRADED-1. LibKa0s missing.** Rename `libs\LibKa0s` and `/reload` → no Lua error; one chat line
says the library is missing; `/qc disable` and `/qc enable` still work; `/qc list` says the settings
CLI is unavailable; `/qc config` says the settings panel is unavailable. Restore the folder after.
Result:

## Send

**SEND-1. Trash in a key.** In a Mythic+ key, out of combat and then on trash in combat, click
`Pulling` on the default pad → the party sees "Pulling next pack" both times; with `/qc debug on`,
the console shows an `Echo` line ending `sent`. Result:

**SEND-2. A boss in a key.** On a key's boss, click `Lust` once → the party sees the line; the chip
flashes gold. Result:

**SEND-3. The spam guard on a boss.** On a boss, click two chips about half a second apart → every
chip dims for about a second after the first press; the second chip flashes amber. If the game
drops it, the chip flashes red and exactly one `[QC] … may have been dropped by the game` line
prints; if it arrives, no line prints. Never two lines for one press. Result:

**SEND-4. A raid boss (C1).** In a raid (LFR is enough), the pad shows the raid set; on a boss,
click a `/raid` chip → the raid sees it, the chip flashes gold. A lead callout shows `RW` only when
you are leader or assist; otherwise its chip carries a padlock and its tooltip says why. A `/raid`
line that never arrives during the encounter is C1 failing: record it. Result:

**SEND-5. Rebuilt between pulls in a key (C4).** In a key, between pulls, `/qc set
behavior.autoPromote true` → the pad rebuilds with no error and the next click still sends. An
"interface action blocked" error here is C4 failing: record it (the fallback bakes once at key
start). Result:

The C1–C9 checks of the phase 0 harness (design spec §19) are recorded in
`docs/brainstorm/go-no-go/`; SEND-4 and SEND-5 repeat C1 and C4 against the shipped addon.

## Pad

**PAD-1. First run.** On a fresh profile, enter a key → the default pad shows "M+ (generic)" with
eight chips, each tagged `P`; the header reads `M+ · <dungeon> +<level>`. Hovering a chip shows its
name and the exact line it sends. Result:

**PAD-2. The stale hint.** In combat, `/qc set behavior.autoPromote false` → the header shows
"updates after combat"; when combat ends it clears and the pad has rebuilt. Result:

**PAD-3. Lock, drag, position.** `/qc unlock` → a drag strip appears above the pad; drag it
elsewhere; `/reload` → it is where you left it. In combat the strip will not drag, and a drag still
held when combat starts ends there, with no error. `/qc lock` → the strip is gone. General → Master
controls → Reset position → the pad returns to its default place, just below the center. The
launcher's Locked entry toggles the same lock. Result:

**PAD-4. Test mode.** `/qc test` → placeholder chips and a TEST MODE label; clicking one sends
nothing. Pull something → test mode ends with one line and the real chips return. `/qc test` in
combat → refused with one line. The Master controls checkbox and the launcher entry follow every
change. Result:

**PAD-5. Visibility and fade.** General visibility "Only out of combat" → the pad hides on the pull
with no error and returns after; Master alpha 50% → the pad is half transparent. Result:

**PAD-6. Disabled mid-combat.** `/qc disable` during combat → no "action blocked" error; the pad
stays until combat ends, then hides. `/qc enable` → it returns with live chips. Result:

**PAD-7. A profile switch in combat.** `/qc profile <another>` during combat → the stale hint
shows, no error; after combat the pad is the other profile's. Result:

**PAD-8. The padlock mark.** Put a Say callout on the pad and pull an encounter (the chat lockdown) →
its chip shows a small gold padlock in its top-right corner (the LibKa0s catalog's `lock` mark, not the pet-battle lock). With LibKa0s removed (DEGRADED-1)
the pet-battle padlock draws instead, with no error. Result:

## Editors

**EDIT-1. A callout and a group on the pad (the phase 3 exit).** Settings → Groups → New group; on
its Callouts tab click Add callout → the callout popup opens blank (Smart group, no icon); name it
`Inc`, text `INC {skull}`, Save → the popup closes and `Inc` is the list's last row. On the group's
When tab tick Content, then M+. Enter a key → the pad shows the new group first with
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

**EDIT-7. An edit during combat.** With a user callout on the pad (its id is `c<n>`: `/qc get
callout.name c1` names the first), in combat type `/qc set callout.text c1 Incoming now` → no error,
the header shows "updates after combat"; after combat the chip sends the new text. `/qc set
callout.text Incoming now` (no id) is refused with a line naming the id form and writes nothing.
Opening the settings in combat is refused, as before. Result:

**EDIT-8. The selection survives what other pages do.** Select a group of yours on the Groups page,
then `/qc profile Other` and back → the Groups page shows a group that exists, never an empty or
erroring page. Delete the selected group (Yes; the line says its callouts go too) → the page moves
to the next group, and the deleted group's callouts are offered nowhere (Reuse existing callout no
longer lists them). Result:

**EDIT-9. The callout popup: look, Save and a refused field.** Groups → a group of yours → Callouts →
a row's edit glyph (the edit mark; its tooltip is headed Edit) → the popup opens filled in, over a dimmed
settings window, and looks like the settings window itself: the same background and border, the
window title "Ka0s Quick Comms" in the top bar and Blizzard's close X at its top right (its
background as bright as the settings window's, not darkened by the dim around it), then the gold
"Edit callout" header and rule, then Choose an icon and the Preview heading over the baked line,
a clear gap (about a section's) under that line, and the red Cancel and Save buttons, Cancel on the
left; there is no Insert a token dropdown. There is **no scrollbar**: the window is
exactly as tall as its content, with no empty band under the error line and nothing cut off at the
bottom. Clicking the page behind it does nothing. Type more text and press Enter → Preview follows the edit, while the chip on
the pad still sends the old line; type text long enough that Preview wraps onto another
line → the window grows with it. Clear the Name and click Save → the popup stays open and a red line names Name;
nothing changed on the pad, and the window grew to show the red line. Type a name back, pick an icon under Choose an icon, Save → the popup
closes, the row and the chip show the new name, text and icon. Result:

**EDIT-10. Cancel leaves nothing behind.** Add callout → type a name and text → Cancel → no new row,
and `/reload` shows none either. Edit a callout, change its text → press Escape → the old text
stands. Edit again, change it → click the close X → the old text stands. Edit again → close the
settings window (or `/qc profile Other`) → the popup is gone with it, nothing saved. Result:

**EDIT-11. Reuse makes a copy.** On group A's Callouts tab, open Reuse existing callout → your
callouts read `<group>: <callout>` (this group's own included), then the built-in ones as
`<set>: <callout>`. Pick one of group B's callouts → nothing is added yet; click Add → it is A's
last row. Edit the copy's text and Save → B's original is unchanged (check its row or its chip).
Reuse a built-in callout → a copy you can edit. Result:

**EDIT-12. The remove glyphs.** On a group's Callouts tab, a row's remove glyph (the red no-entry
sign; its tooltip reads Remove, "Delete this callout. Asks first.") → the confirmation names the callout;
No keeps it, Yes deletes it, and Reuse no longer offers it. On Comms Pad → Groups, a row's remove
glyph (its tooltip: the group itself is kept) → the group leaves that pad at once, with no question, and is still on the Groups page; the
same on Comms Dial → Groups. Neither list has an edit glyph. Result:

**EDIT-13. The callout popup in EllesmereUI's look.** With EllesmereUI and EllesmereUI Blizzard Skin
enabled, EllesmereUI's third-party skinning on and QuickComms on in its Third-Party Addons list,
its window skins not killed, its Settings window skin on and set to the style its other windows
mostly use (the third-party style), `/reload` → open the callout popup (EDIT-9) → its window wears
the same EllesmereUI shell, border and close X as the settings window behind it, and the page's controls look as they do on the
settings pages. `/qc diagnostics` → the integrations section reads `ellesmereui: suite=true
facade=true enabled=true applied=true failed=false`. Turn QuickComms off in EllesmereUI's
Third-Party Addons list and `/reload` → the popup is Blizzard's settings window again (EllesmereUI
does not call back: `facade=false enabled=n/a applied=false`). Disable EllesmereUI → the popup opens in Blizzard's look and no Lua
error appears. Result:

**EDIT-14. The token glyph beside Text.** Edit a party callout (EDIT-9) → a small white "i" sits
just right of the Text label, about the label's height, centered on it and clear of the box under
it. Hover it → a tooltip headed Tokens lists each token with one line of help ({target}, {focus},
the eight markers, {me}, {spec}, {role}, {key}, {dungeon}, then {spell:ID}), with no
{group1} … {group8} line, and fits on screen without wrapping each line. Pick Raid as the Channel
and hover again → one {group1} … {group8} line appears (no Save needed). Move off → the tooltip
hides. Cancel, then open another settings page with text boxes (a group's General tab) and open
the popup again a few times → no stray "i" appears beside any other box, and the popup shows
exactly one. Result:

## Dial

**DIAL-1. Open and close (Relaxed).** Settings → Comms Dial → Binding: click Key, press G → the line
reads "G opens and closes this dial." Close the settings. In a key (any content with an active group),
press G → the dial opens in the middle of the screen: a dark disc, wedges with icons and white labels
outside the disc, the ✕ hub, and a gold pointer that follows the cursor. Press G → it closes. Open it;
Escape → it closes and the game menu does not open. Open it; right-click a wedge → it closes and nothing
is sent. Result:

**DIAL-2. A wedge sends in a boss (the phase 4 exit).** On a raid or M+ boss, press G and click a
callout wedge → the group sees the line, the dial closes, and there is no "action blocked" error or red
text. With the dial closed, 1 still fires your action bar's first button. Press G again at once → every
wedge is dimmed for about a second (the spam guard). Result:

**DIAL-3. The Categories two-stroke (the phase 4 exit).** With two groups active (an always-on group of
your own and M+ in a key): press G → the first ring shows the groups; click one → its callouts; click
a callout → it is sent. Open again, click a group, click the hub → back to the groups; click the hub
again → the dial closes. Result:

**DIAL-4. The Arathi Basin node dial (the phase 4 exit; pinned in phase 5).** In Arathi Basin, with
Wedges per ring at 4: press G → the dial opens straight on the nodes, all five on one ring with no
More, each on its compass wind (Blacksmith N, Gold Mine NE, Farm SE, Lumber Mill SW, Stables NW);
click Lumber Mill, then INC 3 → instance chat shows "INC 3 Lumber Mill": two clicks. Open again and
press 4 → Lumber Mill's ring opens (the number keys count the shown wedges clockwise from N). (If it opens on the group ring instead, check the Groups tab: Arathi Basin must sit above
Battleground (generic) and every group active there, and the tab's "Three rings deep" warning names the
cause; a `/reload` after updating runs the migration that moves the generic set. If the dial does not
show Arathi Basin at all, the instance id may be wrong: run `/qc diagnostics`, copy the `situation`
section's instanceID into the "Battleground instance IDs seen" table of
`docs/brainstorm/go-no-go/round-4-build-checks.md`, and file it with this check's ID; BG-2 confirms
the ids.) Result:

**DIAL-5. Number keys, the wheel and pages.** Wheel → Wedges per ring 4, in a key: open, press 3 → the
third wedge's callout is sent; open, scroll down → the next page, up → back; the More wedge does the
same. After the dial closes, 1–8, Escape and the mouse wheel do what they did before. Result:

**DIAL-6. Key bindings and conflicts.** Escape → Options → Keybindings → AddOns → "Ka0s Quick Comms"
lists Open Comms Dial 1 to 4; bind Open Comms Dial 1 to F → F opens dial 1 like its own key. On the
Binding tab set the key to TAB → the line warns that TAB is also a WoW binding, and TAB opens the dial;
`/qc disable` → TAB targets again; `/qc enable` → TAB opens the dial again. New dial → give it TAB →
refused with "TAB already opens Comms Dial."; give it 3, or the mouse wheel → refused, saying the open
dial uses them; ALT-3 is taken. Result:

**DIAL-7. Open at the cursor, the dial's place, Reset position.** Wheel → Open at → At the cursor →
press G away from the middle → the dial opens centered on the cursor, in combat too (unverified: a
restricted `SetPoint` to `$cursor`). Back to At its place; set Y to 150 → it opens higher; Reset this
dial's position → the middle again. General → Master controls → Reset position → pads and dials back,
one chat line. Result:

**DIAL-8. Edits and disable in combat.** In combat: `/qc set dial.key H` → no error, and the hub shows
"updates after combat" when G opens it; after combat H opens it and G no longer does. In combat with
the dial open: `/qc disable` → no error, the dial keeps working until combat ends, then it is gone and
the key is the game's again. Result:

**DIAL-9. Test mode and Preview as.** Out of combat: `/qc test` → dial 1 opens at its place with
placeholder wedges and TEST MODE above the hub; clicking sends nothing; 1 still fires the action bar.
Comms Dial → General → Preview as → Arathi Basin → the dial opens on the nodes with PREVIEW; nothing
sends; Escape closes the settings window (not the dial), which ends the preview and closes the dial.
Turn test mode on, then pull a target dummy → test mode ends; the dial closes at once or, if combat
won the race, at combat end, and in between 1–8 and Escape still do what they always do. Result:

**DIAL-10. The hub and the drop flash.** Hover the hub → "Why is this showing?" lists the groups and their matched rows;
with a Say callout on the dial during an encounter, LOCKDOWN shows above the hub; Behavior → Explain
why groups show off → no tooltip. `/qc why` lists the dials too; `/qc diagnostics` has `dials` and
`bindings` sections naming the key. If a wedge's send is ever reported dropped (the [QC] note), reopen the
dial within 5 s → that wedge shows red. Result:

**DIAL-11. Mouse-button keys, two dials, labels.** Set the dial's key to BUTTON3 (middle mouse): press it
over the world → the dial opens; press it again with the cursor on a callout wedge → the dial closes
and nothing is sent; on the hub → it closes. A side button (BUTTON4) click on a wedge also closes
without sending, and the restricted snippet's other-frame `RunAttribute` raises no error. New dial →
key H; press G, then H → dial 1 closes and dial 2 opens; press 1 → dial 2's first wedge, never dial
1's; close it → 1 fires the action bar again. In Preview as Arathi Basin the ring title sits above
the N wedge's label, and the NE, SE, SW and NW labels read away from their wedges. With test mode on, close the
dial with the hub, then change Wedges per ring → it stays closed. Result:

**DIAL-12. The hub's close and the wedge padlock.** Open the dial → the hub carries a red ✕ (the
LibKa0s catalog's `close` mark, not the round stop button), and during an encounter a Say callout's wedge shows
the same small gold padlock as a pad chip (PAD-8). With LibKa0s removed (DEGRADED-1) the stop button and the
pet-battle padlock draw instead, with no error. Result:

## Share

**SHARE-1. Export a group.** Settings → Groups → New group `My keys`; on its Callouts tab, Add
callout `Kick` (`Kick on me {skull}`, Party) and `Lust` (`Lust now`, Smart group). Share → Export:
there are no callout checkboxes, only groups, pads and dials; tick `My keys` → the line under the boxes reads "The string will hold 2 callouts, 1 group."; Export → a
window opens with a string starting `!QC1!`, already selected; Ctrl+C copies it; Escape closes the
window. Result:

**SHARE-2. Import it, twice.** Profiles → make a profile `Share test`. Share → Import: paste the
string and click Accept → "Ready to import: 2 callouts, 1 group."; Import → chat says "Imported 2
callouts, 1 group." and "An imported group is on no pad or dial yet: add it on the Groups tab of the
Comms Pad or Comms Dial page.", and Groups lists `My keys` with both callouts. Paste and import it
again → a second `My keys`, and the first one is untouched. Result:

**SHARE-3. A string that tries a command.** Paste this on Import and click Accept:

```
!QC1!v4CVUjmmuuaybLPIufQdD2kdOwwqHbeZgPYatnrIz8pxLef7RJSVUuuvx6JsEIS4jcZ6rF6CotojB8U4q4TIMYp)xjmgxKcRkuLfQnEafsdOpZrHfgRTUEGrqG4xAb85kHw7WXVIDQ(9oRnW77qTugrTbstxMlzlNGFOHfhZeMdzwG9RN29xAg)rKx1kqemJbRWthE8K8SBtZVT2hr2GVdP3l)intwJGO)A6LQHm86RF)09)
```

→ "Ready to import: 1 callout, 1 group.", "Left out the callout 'Sneaky': its text starts with /." and
"1 reference to something the string does not carry was left out."; Import → the group `Smoke test`
holds `Kick` only, and nothing ran. Result:

**SHARE-4. Damaged, foreign and newer strings.** On Import, Accept each: the SHARE-1 string with its
last ten characters deleted → "That string is damaged or cut short. Copy all of it again."; `hello`
→ "That is not a Quick Comms string: one starts with !QC1!."; and this →
"That string was made by a newer Quick Comms. Update the addon, then import it.":

```
!QC1!JXWsk9IYV0ckMRGsmLuYpVffyPzMC2oNFU5wStzNzEPKusLMxk5KAtjNyo5KFPLumxcvgRa(
```

Clicking Import after any of them prints the same line and adds nothing. Result:

**SHARE-5. A pad and a dial travel unbound.** Give the Comms Dial the key G. Share → Export: tick
the Comms Pad and the Comms Dial; Export, copy. Switch to `Share test`, import it → chat also says
"An imported dial has no key yet: give it one on the Comms Dial page."; the new pad sits in the
default place (not where yours is), the new dial's Binding tab shows no key, and G does nothing on
this profile until you give one. Switch back → G opens your dial as before. Result:

**SHARE-6. A string that wrapped.** Paste a SHARE-1 string into a chat message or a forum post so it
breaks across lines, copy it back out with the line breaks, and paste that on Import → Accept reads
it as before. Result:

## Look

**LOOK-1. Font.** Comms Pad → Look → Font: pick another face, Font size 14, Font flags Outline,
untick Font shadow → the chip labels and the section titles redraw that way, the titles still gold;
tick Use class color → both take your class color, and Font color's opacity still applies; untick it
and set Font color to red → both turn red. Result:

**LOOK-2. Border and background.** Border style: a LibSharedMedia border (Blizzard Tooltip, for one),
thickness 3, color red → the pad's edge changes; thickness 0 → no edge. Background: dark blue at 50%
opacity → the body changes; Use class color → your class color at 50%. The settings panel is closed
and locked in combat, so the in-combat write goes through the command line: in combat,
`/qc set pad.look.borderSize 3` → no error, the header shows "updates after combat", and the thicker
edge lands at combat end. Defaults → the Ka0s look again. Result:

## Icons

**ICON-1. The icon picker.** Groups → a group of yours → Callouts → a row's edit glyph → Choose an
icon: click the skull → the popup's Icon box shows its path; Save → the row and the chip show the
skull. Groups → a group of yours → General → click a
mark → the group's wedge on the Comms Dial shows it. A built-in set's General tab has no picker.
Result:

## Battlegrounds

**BG-1. Node winds.** In each node battleground you play (Arathi Basin, Eye of the Storm, Battle for
Gilneas, Deepwind Gorge, Isle of Conquest), open the dial → the nodes sit where they are on the map,
north up (Arathi Basin: Stables top left, Gold Mine top right, Farm bottom right, Lumber Mill bottom
left, Blacksmith, the middle node, at the top), and Deepwind Gorge shows five nodes (owner ruling R2).
Lumber Mill, then INC 3 is still two clicks. A node that points the wrong way is filed with this
check's ID and its battleground. Result:

**BG-2. Battleground instance ids.** In each battleground you play: `/qc diagnostics` → the
`situation` section's instanceID is one its set lists (`defaults/BuiltIns_Battlegrounds.lua`), and
the pad and the dial show that set. Write each id into the "Battleground instance IDs seen" table of
`docs/brainstorm/go-no-go/round-4-build-checks.md`. Result:

## Instance ids

**IDS-1. The Midnight dungeons and raids.** In each of the eight dungeons and three raids you visit
(Windrunner Spire 2805, Magisters' Terrace 2811, Nexus-Point Xenas 2915, Maisara Caverns 2874, and
the four returning dungeons; The Voidspire 2912, The Dreamrift 2939, March on Quel'Danas 2913):
`/qc diagnostics` → the instanceID matches; a group's When → Instances → "add the one you are in" adds
that id. Groups → Preview as lists "M+ · Windrunner Spire" and the other seven by name. On a Devourer
Demon Hunter, `/qc diagnostics` → the Situation line reads `spec=1480`, and a When's Spec row
offers Devourer. If you can enter Sporefall (map 1592), note whether it is a raid and its instanceID
(ruling R4 left it out of the shipped raids). Only after this check passes
does `defaults/GameIds.lua`'s note change from "matched" to "confirmed". Result:

## Non-English client

**LOC-1. A deDE or frFR client.** What this build reads that a locale can change, enumerated from the
code (phase 5):
- **Matched, never by name** (localization-§4): the situation engine keys instances, battlegrounds and
  specializations by id, difficulty and content by `difficultyID` and tokens, a class by its
  `classFile` token, a character by Name-Realm (`modules/Situation.lua`, `Library.ValidWhenValue`).
  Headless: `test_situation`, `test_resolver`, `test_library`.
- **Shown, never matched**: the editors' display names, read through Compat (`InstanceName` from
  `GetRealZoneText`, `SpecInfoByID`, `ClassName` from `LOCALIZED_CLASS_NAMES_MALE`, `BindingLabel`
  from a `BINDING_NAME_*` global). Headless: `test_compat` (a missing or secret name is nil, and the
  editor falls back to the id).
- **Sent in chat**: the callout tokens' values (`{me}`, `{spec}`, …) come from the client in its own
  language and are escaped like any value (`test_tokens`).
- **The Look's font**: the default face is LibSharedMedia's "Friz Quadrata TT", which LibSharedMedia
  does not register on koKR, zhCN or zhTW; a face the machine does not have draws `STANDARD_TEXT_FONT`
  (`Pad_Render.LabelFont`, `test_pad_render`).
- **Printed**: every chat and report line is English through `NS.L`, the share and import lines
  included (`test_slash`, `test_diagnostics`, `test_share`, `test_page_share`).

On a deDE or frFR client: `/reload`, run `/qc help` and `/qc diagnostics`; open the Groups page's When
on an instance and a spec; make a callout with `{spec}`; export a group and import the string → no Lua
error, no stray `%s` or `%d` in any line, the When's names in the client's language with the ids
unchanged, and the pad's labels drawn in a font (on koKR, zhCN or zhTW, the client's own). The failure
looks like a raw format token in chat, a missing label, or a When that stops matching after a locale
switch. **Owed**: the enumeration above is covered headlessly, but the names and the font fallback come
from the client, so this check needs a non-English client pass. Result:

## Pending sign-off

| ID | Origin | Why it is owed |
|---|---|---|
| INSTALL-1..3, SLASH-1..2, PANEL-1..3, PROFILE-1..2, STATE-1..2, COMBAT-1, DIAG-1..2, DEGRADED-1, LOC-1 | The phase 0 scaffold | No client pass recorded yet; LOC-1 re-enumerated in phase 5 and owed a non-English client pass |
| SEND-1..5, PAD-1..8 | Phase 2: the send engine and the Comms Pad | No client pass recorded yet; PAD-8 added in phase 5 (audit QC-07) |
| EDIT-1..14 | Phase 3: the editors | No client pass recorded yet; EDIT-1, 7 and 8 rewritten and EDIT-9..12 added when callouts moved into their groups (2026-10-17), SHARE-1 and ICON-1 rewritten with them; EDIT-9 and 10 rewritten and EDIT-13 added when the popup took the settings window's look (2026-10-17); EDIT-9 rewritten and EDIT-14 added when the token dropdown became the Text label's info glyph (2026-10-18) |
| DIAL-1..12 | Phase 4: the Comms Dial | No client pass recorded yet; DIAL-4 rewritten in phase 5 for the pinned ring; DIAL-12 added in phase 5 (audit QC-07) |
| SHARE-1..6, LOOK-1..2, ICON-1, BG-1..2, IDS-1 | Phase 5: share, polish and the instance ids | No client pass recorded yet; LOOK-2's in-combat step goes through `/qc set` |
