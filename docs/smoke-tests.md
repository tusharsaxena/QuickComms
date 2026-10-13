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
| PAD-1..7 | Pad | The Comms Pad |
| EDIT-1..8 | Editors | The Callouts, Groups, Comms Pad and Share pages, Preview as…, Why is this showing? |
| DIAL-1..11 | Dial | The Comms Dial (Relaxed), its key and Bindings.xml, the battleground node dial |
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
the report prints the `bake.surface`, `send.click`, `pad.layout` and `echo.match` rows and no Lua
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

**DIAL-4. The Arathi Basin node dial (the phase 4 exit).** In Arathi Basin: press G → the dial opens
straight on the nodes (Stables, Lumber Mill, Blacksmith, More); click Lumber Mill, then INC 3 → instance
chat shows "INC 3 Lumber Mill": two clicks. Open again; click More → Gold Mine and Farm; the hub goes
back a page. (If it opens on the group ring instead, check the Groups tab: Arathi Basin must sit above
Battleground (generic) and every group active there, and the tab's "Three rings deep" warning names the
cause; a `/reload` after updating runs the migration that moves the generic set. If the dial does not
show Arathi Basin at all, the instance id may be wrong: run `/qc diagnostics`, copy the `situation`
section's instanceID into the "Battleground instance IDs seen" table of
`docs/brainstorm/go-no-go/round-4-build-checks.md`, and file it with this check's ID; phase 5 confirms
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
the N wedge's label, and the E and W labels read away from their wedges. With test mode on, close the
dial with the hub, then change Wedges per ring → it stays closed. Result:

## Non-English client

**LOC-1. A deDE or frFR client.** What this build reads that a locale can change, enumerated from the
code: nothing. It reads no localized `_G` string, parses no tooltip line, keys nothing off a display
string, and writes no header another tool parses; its own strings are English through `NS.L`, which
answers the key itself on any client. The checks that will carry locale risk arrive with the
situation engine (instance and difficulty matched by id, never by name, design spec §6) and the
callout tokens (spec §8.1). Until then, on a deDE or frFR client: `/reload`, run `/qc help` and
`/qc diagnostics` → English text throughout, no Lua error, and no stray `%s` or `%d` in any line.
The failure looks like a raw format token in chat or a missing label. **Signed off without the
client** while the enumeration above holds: the headless cases `test_slash` and `test_diagnostics`
cover every line printed today, and the English client's INSTALL and SLASH checks are sufficient. The
section is re-armed by the situation task, whose check replaces this paragraph's "nothing". Result:

## Pending sign-off

| ID | Origin | Why it is owed |
|---|---|---|
| INSTALL-1..3, SLASH-1..2, PANEL-1..3, PROFILE-1..2, STATE-1..2, COMBAT-1, DIAG-1..2, DEGRADED-1, LOC-1 | The phase 0 scaffold | No client pass recorded yet |
| SEND-1..5, PAD-1..7 | Phase 2: the send engine and the Comms Pad | No client pass recorded yet |
| EDIT-1..8 | Phase 3: the editors | No client pass recorded yet |
| DIAL-1..11 | Phase 4: the Comms Dial | No client pass recorded yet |
