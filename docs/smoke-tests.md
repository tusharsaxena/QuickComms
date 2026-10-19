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
| STATE-1..3 | State | Enable/disable, the launcher menu, `/qc toggle` |
| COMBAT-1 | Combat | The settings panel in combat |
| DIAG-1..2 | Diagnostics | The debug console, the report, perf |
| DEGRADED-1 | Degraded | The install with LibKa0s missing |
| SEND-1..5 | Send | Secure sends in keys and on bosses, the spam guard |
| PAD-1..10 | Pad | The Comms Pad, its growth and chip width |
| EDIT-1..26 | Editors | The Groups (with the callout popup, its EllesmereUI look and its token glyph, the icon browser, its search, its glyph sets and glyph colors, the Callouts rows, Reuse and the glyph lists, the built-in sets as ordinary groups and Restore, nested groups and Inherit when conditions, the Preview table, the When drawers), Comms Pad and Share pages, Preview as…, Why is this showing?, an older profile's conversion |
| DIAL-1..12 | Dial | The Comms Dial (Relaxed), its key and Bindings.xml, the battleground node dial |
| SHARE-1..6 | Share | Export and import strings, the report, refusals, unbound pads and dials |
| LOOK-1..2 | Look | The Comms Pad's font, border and background |
| ICONS-1..3 | Icons tab | The chips' and wedges' icon look, border and glow triggers |
| ICON-1 | Icons | Choosing an icon, for a callout and for a group |
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
beside Test mode, then Preview as alone on its own line, then Reset position beside Reset all
settings. Ticking Debug console opens the
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

**STATE-2. Launcher menu.** Right-click the minimap button → four entries, Enabled, Locked, Test
mode and Show window, each ticking the state it shows and toggling it; left-click → the settings
panel opens. Result:

**STATE-3. Hide the pads for the session.** `/qc toggle` → every Comms Pad hides and the chat says so;
the minimap menu's Show window is unticked; the dials still open. `/qc test` → the pads show as
placeholders, and turning it off hides them again. `/qc toggle` → the pads are back. Hide them, pull
a training dummy and type `/qc toggle` → nothing changes until combat ends, then the pads show, with
no Lua error. Hide them and `/reload` → the pads show. Result:

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

**PAD-1. First run.** On a fresh profile, enter a key → the default pad shows "Dungeon (generic)" with
eight chips, each tagged `P`; the header reads `M+ · <dungeon> +<level>`. Hovering a chip shows its
name and the exact line it sends. Every chip shows its glyph: Lust a red enraged face, Need mana a
blue drop, Res me a green ankh, GG a gold trophy, the rest white. Leave the key and zone into a
normal or heroic dungeon → the same set shows. On a profile saved before this build (it still shows
"M+ (generic)" with the bloodlust spell icon on Lust), `/reload` with this build → the set reads
"Dungeon (generic)" and Lust shows the red glyph; a set renamed before, or a callout whose icon was
cleared, keeps the player's choice. Result:

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

**PAD-9. Up growth.** Comms Pad → Layout → Growth offers Right and down, Left and down, Right and up
and Left and up (no Upward). Right and up → the header row sits at the bottom of the pad and the
sections stack upward above it; `/qc unlock` → the drag strip sits below the pad. Drag the strip
somewhere, then add a group to the pad → the pad grows upward and the strip stays where you left it;
`/reload` → the strip is still there. Left and up → the chips fill right to left, still upward. Right
and down → the header is on top again, the strip above, and adding a group grows the pad downward
from a top edge that stays put. A profile saved with Upward growth loads as Right and up. A pad placed
before 2026-10-19 moves once on its first load, by up to its height (see Known Limitations in
`docs/ARCHITECTURE.md`); drag it back and it stays. Result:

**PAD-10. Chip width and the section title.** Comms Pad → Layout → Chip width reads 100 on a new
pad; drag it to 300 → wide chips, each label on one line; down to 30 → the labels cut short, still
one line; down to 1 → icon-only slivers, no label and no Lua error. Make a group named `World`, put
it on the pad and stand in the open world → the header reads `World` and the section under it has
no second `World` line; rename the group `My world` → its title line is back. Result:

## Editors

**EDIT-1. A callout and a group on the pad (the phase 3 exit).** Settings → Groups → New group; on
its Callouts tab click Add callout → the callout popup opens blank (Smart group, no icon); name it
`Inc`, text `INC {skull}`, Save → the popup closes and `Inc` is the list's last row. On the group's
When tab click the Content header and tick M+ in its drawer. Enter a key → the pad shows the new group first with
an `Inc` chip; click it → the party sees "INC" with a skull. Leave the key → the group is gone from
the pad. Result:

**EDIT-2. A built-in set is an ordinary group (the phase 3 exit, rewritten 2026-10-18).** Groups →
pick "Dungeon (generic)" → the picker shows no "(built-in)" tag, and the page draws the same tabs as a
group of yours, nothing read-only. General: Name, Enabled, Open the dial on this group, Parent group,
the icon with Choose icon…, Duplicate and Delete, then Restore built-in groups; no Customize and no
read-only line. Callouts: the callout table, exactly as a group of yours draws it (Add callout, Reuse
callout with Add, a boxed row per callout with its handle, icon, name and channel, edit and remove
glyphs); no Show checkboxes. When: the editable condition drawers (EDIT-22), Content's summary
reading M+ in gold; not read-only text. Rename a callout in the popup and Save → in a key, the chip's label
changes. Untick Enabled → in a key the set is gone from the pad; tick it again. Result:

**EDIT-3. Preview as….** Out of combat, in the open world: General → Master controls → Preview as → Arena →
the pad shows the arena set with PREVIEW on its header and `Preview: Arena`; clicking a chip sends
nothing; its tooltip says so. The Comms Pad, Comms Dial and Groups pages' General tabs have no
Preview as row. Close the settings → the preview ends. `/qc preview raid:heroic` →
the raid set; pull something → the preview ends with one line and the live chips return. Result:

**EDIT-4. Why is this showing?.** In a key, hover the pad's header → the tooltip lists "Dungeon
(generic): Content" (and any other group, with its rows); with a `/raid` callout on the pad
outside a raid, the last line names the lock. Behavior → Explain why groups show off → no tooltip.
`/qc why` prints the same lines per pad. Result:

**EDIT-5. The Comms Pad page.** Comms Pad → Layout: Orientation Vertical, Chip style Label only,
Scale 1.5 → the pad redraws each time. Type X `200`, Y `-100` → it moves; Reset this pad's position
→ it returns. Look → Visibility Only out of combat → it hides on the pull with no error. Groups:
drag a group to the top → it comes first on the pad. New pad → a second pad appears holding every
built-in group you still have (top-level, in shipped order); Delete pad (Yes) → it is gone. Result:

**EDIT-6. Restore built-in groups (rewritten 2026-10-18; the Share page's Built-in tab is gone).**
Share has two tabs, Export and Import. Groups → "Raid (generic)" → Delete (Yes) → it is gone from the
picker and, in a raid, from the pad. On "Dungeon (generic)"'s Callouts tab remove "Lust" (Yes). General →
Restore built-in groups (no question asked) → one chat line counts the groups and callouts that came
back; "Raid (generic)" is in the picker again and last on every pad's and dial's Groups list, and
"Lust" is the last row of Dungeon (generic)'s Callouts. Click Restore again → "nothing to restore", and
nothing is added. Delete "Lumber Mill" (inside "Arathi Basin") → Restore → it is back, indented under
Arathi Basin in the picker, and in Arathi Basin (or Preview as → Arathi Basin) its wedge is on its
wind, SW, again. Rename "Dungeon (generic)" → Restore leaves it as it is and adds no second dungeon set. With
every group deleted, the "No groups yet" General still offers Restore built-in groups. Result:

**EDIT-7. An edit during combat.** With a user callout on the pad (its id is `c<n>`: `/qc get
callout.name c1` names the first), in combat type `/qc set callout.text c1 Incoming now` → no error,
the header shows "updates after combat"; after combat the chip sends the new text. `/qc set
callout.text Incoming now` (no id) is refused with a line naming the id form and writes nothing.
Opening the settings in combat is refused, as before. Result:

**EDIT-8. The selection survives what other pages do.** Select a group of yours on the Groups page,
then `/qc profile Other` and back → the Groups page shows a group that exists, never an empty or
erroring page. Delete the selected group (Yes; the line says its callouts go too) → the page moves
to the next group, and the deleted group's callouts are offered nowhere (Reuse callout no
longer lists them). Result:

**EDIT-9. The callout popup: look, Save and a refused field.** Groups → a group of yours → Callouts →
a row's edit glyph (the edit mark; its tooltip is headed Edit) → the popup opens filled in, over a dimmed
settings window, and looks like the settings window itself: the same background and border, the
window title "Ka0s Quick Comms" in the top bar and Blizzard's close X at its top right (its
background as bright as the settings window's, not darkened by the dim around it), then the gold
"Edit callout" header and rule, then Name and Channel side by side, Text on a line of its own across
the whole width, an "Icon" label over the icon with Choose icon…, a small red clear glyph and Icon
color (there is **no Icon text box**), a section's gap (about 18 px) under that row, the Preview
heading over the baked line,
a clear gap (about a section's) under that line, and the red Cancel and Save buttons, Cancel on the
left; there is no Insert a token dropdown. **Alignment:** every label starts exactly over the left
edge of its box (Name, Channel, Text), the Channel dropdown's left edge meets the Name box's line,
the icon and the Icon label start on that same line, and so do the Preview rule, the preview line
and Cancel; in the right column the Channel label, its dropdown, the Icon color swatch and Save all
start on one line, a clear gap right of the Name box; the right edges of the Channel dropdown, the
Text box, the Preview rule and Save line up, as do the Name box's, the clear glyph's cell's and Cancel's. There is **no scrollbar**: the window is
exactly as tall as its content, with no empty band under the error line and nothing cut off at the
bottom. Clicking the page behind it does nothing. Type more text and press Enter → Preview follows the edit, while the chip on
the pad still sends the old line; type text long enough that Preview wraps onto another
line → the window grows with it. Clear the Name and click Save → the popup stays open and a red line names Name;
nothing changed on the pad, and the window grew to show the red line. Type a name back, click Choose icon… and double-click an icon in the browser, Save → the popup
closes, the row and the chip show the new name, text and icon. Result:

**EDIT-10. Cancel leaves nothing behind.** Add callout → type a name and text → Cancel → no new row,
and `/reload` shows none either. Edit a callout, change its text → press Escape → the old text
stands. Edit again, change it → click the close X → the old text stands. Edit again → close the
settings window (or `/qc profile Other`) → the popup is gone with it, nothing saved. Result:

**EDIT-11. Reuse makes a copy.** On group A's Callouts tab, open Reuse callout → your
callouts read `<group>: <callout>` (none of group A's own: they are left out), a seeded set's
`<set>: <callout>` and a battleground node's `<set>: <node>: <callout>` (Arathi Basin's and
Deepwind Gorge's Farm read apart), all in one alphabetical list (by group, then callout); the group part is a
muted gold, the callout's name white. The dropdown runs across the row with Add at its right
edge, Add as tall as the dropdown, and Add callout above spans the same width: the right edges of
Add callout and Add line up, a hair (2 px) short of the list's boxes, and **both buttons' right
borders are whole** (not shaved by the page's edge). In the list, every row's handle, icon, name and
glyphs sit centered in its box, and the edit and remove glyphs are small and close to the box's
right edge (the same on Comms Pad → Groups and Comms Dial → Groups). Pick one of group B's callouts → nothing is added yet; click Add → it is A's
last row. Edit the copy's text and Save → B's original is unchanged (check its row or its chip).
The list has no built-in section: "Dungeon (generic): Lust" is listed like any other group's callout;
reuse it → a copy you can edit, and the M+ group's Lust is unchanged. Result:

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
facade=true enabled=true applied=true failed=false browser=false why=popup painted; browser not built
yet (painted when it is first opened)`; click Choose icon… → the icon
browser wears the same shell, border and close X, and `/qc diagnostics` now reads `browser=true why=popup painted; browser painted`. Turn QuickComms off in EllesmereUI's
Third-Party Addons list and `/reload` → the popup is Blizzard's settings window again (EllesmereUI
does not call back: `facade=false enabled=n/a applied=false`, and `why=` says EllesmereUI has not
called back because its third-party skinning or QuickComms' entry was off at login). Turn it back on
and `/reload`; `/qc disable` → open the popup and the icon browser from the settings window → both
still wear EllesmereUI's look (the skin does not wait for the addon to be enabled); `/qc enable`.
Disable EllesmereUI → the popup opens in Blizzard's look, `why=EllesmereUI is not loaded`, and no
Lua error appears. Result:

**EDIT-14. The icon browser: look, tabs and a pick.** Open a callout of yours in the popup (EDIT-9) →
under the Icon row, the callout's icon (a question mark for none), Choose icon… and Icon color.
Click Choose icon… → the icon browser opens **over** the popup, which is dimmed behind it (a click on
the popup does nothing), and looks like it: the settings window's background and border, "Ka0s
Quick Comms" in the top bar, Blizzard's close X, the gold "Choose an icon" header. The tabs read
Markers, Game icons, Glyphs (no Suggested); the callout's icon is selected (gold behind it) on its
own tab, scrolled into view, and named in the footer; a callout with no icon, or a seeded set's
spell icon, opens on Markers with nothing selected. On Glyphs, the Icon color row sits clear of the first
row of icons (a gap between them), and it is gone on Markers. Markers shows the eight markers; Glyphs every
LibKa0s glyph, white, each named on hover (`Arrow circle down`-style names); the count at the right
follows the tab. Click an icon → it is selected and named in the footer, nothing else changes; Cancel
→ the popup's icon is unchanged. Choose icon… again, double-click the skull → the browser closes and
the popup shows the skull (the chip on the pad does not change until Save). Result:

**EDIT-15. The Game icons tab.** In the browser, Game icons → thousands of icons (the count reads in
the thousands), the same ones the macro icon selector offers. Scroll with the wheel and drag the
scrollbar from top to bottom → it keeps up without a hitch, and each icon draws (no blank or green
square). Hover one → "Texture id N". Show → Spells, then Items → each list is smaller, and All is
both. Choose a game icon, Save → the chip and the row show it. If the tab says the game's icon list
has not loaded yet on the first open after a login, open it again a moment later → the icons are
there. Result:

**EDIT-16. A glyph's color, everywhere.** Choose a glyph for one of your callouts (Glyphs tab), then
Icon color → Blizzard's color picker opens **above** the browser; pick orange → every glyph in the
grid and the footer turns orange. Choose, Save → the chip on the pad, the wedge on the Comms Dial
(test mode) and the callout's row on the Callouts tab show the glyph in orange; the popup's icon too
when it is opened again. On a group of yours, General → Choose icon… → a glyph, Choose → then Icon
color → green → the group's wedge on the dial is green at once. Now choose a raid marker for that
group → the marker is drawn in its own colors, the swatch grays out, and choosing a glyph again
shows it white (the color went with the marker). Export the orange callout's group (Share → Export),
import the string → the copy's glyph is orange too. `/reload` → every color is still there. Result:

**EDIT-17. What closes the browser.** Open the browser from the popup and press Escape → the browser
closes and the popup stays open; press Escape again → the popup closes, nothing saved. Open the
browser from the popup, click its close X → the same as Cancel. Open it again and close the settings
window (or `/qc profile Other`) → the browser and the popup are both gone and nothing is saved; no
Lua error. Open it from a group's General tab and `/qc profile Other` → it closes the same way, and
the group's icon is unchanged when you switch back. In combat, the settings panel cannot be opened; with the browser
open on the pull, the panel's combat cover lies over it and Choose (a double-click too) prints one
line and changes nothing. Result:

**EDIT-18. The token glyph beside Text.** Edit a party callout (EDIT-9) → a small white "i" sits
just right of the Text label, no taller than the label's letters, centered on them and clear of the
box under it. Hover it → a tooltip headed Tokens lists each token with one line of help ({target}, {focus},
the eight markers, {me}, {spec}, {role}, {key}, {dungeon}, then {spell:ID}), with no
{group1} … {group8} line, and fits on screen without wrapping each line. Pick Raid as the Channel
and hover again → one {group1} … {group8} line appears (no Save needed). Move off → the tooltip
hides. Cancel, then open another settings page with text boxes (a group's General tab) and open
the popup again a few times → no stray "i" appears beside any other box, and the popup shows
exactly one. Result:

**EDIT-19. A group inside another.** Make two groups of yours, `My keys` (on the pad, with a
callout and a When that matches where you are) and `Kicks`. On Kicks' General tab, Parent group →
the dropdown lists None and the top-level groups, not Kicks itself; pick My keys → Kicks leaves every
pad's and dial's Groups list, Add a group there does not offer it, and the Groups picker lists it
indented right under My keys, and Inherit when conditions beside Parent group is ticked and no
longer grayed out. Give Kicks a callout → the pad shows My keys' own section, then a section titled
Kicks; the dial (test mode or its key) shows My keys' callouts, then a Kicks wedge that opens its
ring. Untick Inherit when conditions and give Kicks a When that does not match → its section and
ring go, My keys stays (EDIT-23 covers inheriting). On My keys' General tab, Parent group is grayed out; its tooltip names
Kicks. Duplicate Kicks → the chat line says the copy is inside My keys. Delete My keys → the question
says the groups inside it become top-level groups in its place; Yes → Kicks and its copy are
top-level, on every pad and dial where My keys was. `/qc set group.parent none` on a selected child
makes it top-level; `/qc set group.parent <its own id>` is refused, with a line saying why.
Result:

**EDIT-20. The Preview table.** Groups → "Dungeon (generic)" → Preview → the active-now line, then a gold
header row, "Callout" and "What it sends here", then one box per callout like the Callouts tab's rows
(switch between the two tabs: the same fill and border, and the same left and right edges): the
callout's icon (in its color) and name on the left, what it sends here on the right, or, outside a
key, why it sends nothing. Give a callout a long text → its row grows, the text wraps inside the
right cell, and the name and the text stay centered in the row. Preview as → an M+ dungeon → each
row's text changes in place to the baked line. "Arathi Basin" → a titled table per node (Stables,
Lumber Mill, …), each with its header. A new group with no callouts → "This group has no callouts
yet." and no table. Result:

**EDIT-21. An older profile converts once.** On a profile saved before the built-in sets became
groups (the owner's, with a hidden built-in callout, one set unticked on the old Built-in tab, and
one customized copy), `/reload` → no Lua error; the Groups picker lists every built-in set by name,
with no "(built-in)" tag and no duplicates; Comms Pad → Groups and Comms Dial → Groups list them in
the same places as before; the unticked set is a group with Enabled unticked; the hidden callout is
missing from its group (Restore built-in groups brings it back); the customized copy is there with
your edits, in its place, with no stock set beside it. `/reload` again → nothing changes and nothing
is added. Result:

**EDIT-22. The When drawers.** Groups → a group of yours → When → the active-now line, then the gray
line "Every condition you set must match. A condition left as Any does not limit the group.", a
clear gap under it, then twelve header bars, closed, in this order: Content, Instance, Difficulty, Key level, Group, Leader
or assist, Class, Specialization, Role, Character, Battleground, Arena. Each has a right-pointing chevron,
its name in white and "Any" in gray at its right edge; there is no enable checkbox anywhere. They
look like the settings panel (its fonts, gold, dark fills and thin borders), not like another
addon's cards. Hover a header → its tooltip. Click Content → the chevron points down, the header's
edge turns gold and its bottom corners square off, and a box joins under it holding the content
types in three columns (World, Dungeon, M+ on the first line), lined up under the name, with Select
all and Clear (Any) at its bottom right. Tick M+, then Raid → the name turns gold and the summary
reads "M+, Raid"; in a key the group shows. Click Difficulty → both drawers are open. Select all →
every difficulty is ticked and the summary lists them, cut with an ellipsis before the edge. Clear
(Any) → all unticked, the name white, the summary "Any", the drawer still open. Key level: Lowest
`10` → "10 or higher"; Highest `15` → "10 to 15"; Highest `5` is refused with a line and the box goes
back. Instance: an add box and Add the instance you are in, no Select all; add two dungeons → "2
instances"; Clear (Any) empties the list. Specialization with a class picked → Select all ticks that
class's specs only. Battleground: "All battlegrounds" sits on top of the drawer, unticked; add one
battleground, then tick it → the summary reads "All battlegrounds", the add box, the list and both
buttons are dimmed and do nothing on a click; in any battleground the group is active; untick → the
battleground you added is still listed and the summary names it. Instance has "All dungeons and
raids" and Arena "All arenas" the same way; Character has no such box. Instance: type `Murder Row`
(or `mu` and pick it from the suggestions) → it is added and named, though it is no season dungeon;
type `Magisters' Terrace` → the season's 2811 is added. Arena: type `Nagrand` → the suggestions list
Nagrand Arena once; add it → the summary names it; in an arena, Add the arena you are in adds its
id, and outside one a line says "You are not in an arena." Open every drawer, scroll to the bottom, open Battleground and tick a box in
it, then Select all and Clear (Any) → the page stays where you scrolled each time, never jumping to
the top. Click an open header → its drawer closes and its summary stays. Pick another
group and come back → the drawers you left open are still open, and the other group's are its own;
`/qc profile Other` and back → all closed; `/reload` → all closed, every condition kept. In combat
the panel cannot be opened; with it open on the pull, the combat cover lies over the tab and no
header opens. Result:

**EDIT-23. Inherit when conditions.** Out of a key, in the open world: Groups → "Arathi Basin" →
pick a node inside it ("Lumber Mill") → General → Inherit when conditions beside Parent group is
ticked; its tooltip says it uses the parent group's When. The Group picker shows **no green dot** on
Arathi Basin's nodes (nor on any seeded battleground's), and none on the set itself. When → the gold
line "Uses Arathi Basin's conditions. Untick Inherit when conditions on the General tab to set this
group's own.", then the drawers with Arathi Basin's conditions: Content's summary reads Battleground
in gold; a drawer opens and closes, its checkboxes are grayed out and there is no Select all or
Clear (Any). Enter Arathi Basin (or Preview as → Arathi Basin) → the node's wedge is on the dial and
its section on the pad. Untick Inherit when conditions → the When tab is editable and shows the
node's own (empty) When, every summary "Any", and the picker's dot is back in the open world (an
empty When matches anywhere); give it a When of its own (Content → Arena) → in Arathi Basin its
wedge and section are gone, the other nodes stay. Tick it again → back to the parent's
conditions, and the node's own Arena is still there when you untick it once more. On a top-level
group of yours the box is grayed out. `/qc set group.inheritWhen false` on a selected child unticks
it; the page's Defaults ticks it again. Export a group with a child that does not inherit (Share →
Export), import the string → the copy's child does not inherit either. Result:

**EDIT-24. The icon browser's search.** Open the icon browser (EDIT-14) → the toolbar holds a search
box with a gold magnifier inside its left edge, beside Show on Game icons, beside Icon color on
Glyphs, at the left on Markers; hover it → "Markers by name, glyphs by name, game icons by texture
id. Not case-sensitive." Markers → type `sk` → the skull alone, and the count reads "1 of 8 icons".
A gray clear mark shows at the box's right; click it → the box empties and the eight markers are
back ("8 icons"). Glyphs → type `arrow` → only arrow glyphs; `Arrow Circle` finds the same as
`arrow-circle`. Game icons → type `1320` → only icons whose texture id holds those digits, the
count "N of M icons", the grid from the top; hover one → its texture id holds `1320`. Type `zzz` →
"No icon matches your search.". Under the grid, a box reads "Search by texture id. To find an icon
by its name (e.g. ability_cheapshot), look it up on Wowhead and type its id here." beside **Copy
wowhead.com/icons**; click it → a small window titled "Quick Comms: Wowhead icons" opens **above**
the browser, holding `https://www.wowhead.com/icons` selected; Ctrl+C copies it. Look up
ability_cheapshot there, type its id `132092` → its icon is in the grid; double-click it → chosen.
The hint box is gone on Markers and Glyphs. Switch tabs with text in the box → the new tab is
filtered by it; Cancel and open the browser again → the text is still there; `/reload` → the box is
empty. Escape with the Wowhead window's box focused closes that window alone; close the browser →
the Wowhead window closes with it. Result:

**EDIT-25. The Callouts rows and the Look tab.** Groups → "Dungeon (generic)" → Callouts → each
row reads its icon, the name in gold, the channel's short label in its chat color (Party blue,
Say white) and the start of its text in a muted white, cut at 40
characters with "…". A callout with no icon shows the question mark; a callout whose text holds a
`|` shows the bar, not a color change; a Smart channel takes the color of the channel it resolves to
now (solo: Party). Comms Pad → Look → Visibility, then the Font, Border and Background headings, each
heading once. Result:

**EDIT-26. The glyph sets and their credits.** Open the icon browser (EDIT-14) → Glyphs: the count
reads over five thousand. A set dropdown left of Icon color reads All; pick Open Iconic → only the
original marks (the count about two hundred), Phosphor → the Phosphor marks, Game-icons → the
thousands of game marks; All → every set again. The search (EDIT-24) filters within the set picked.
Labels drop the set prefix (`Arrow up`, not `ph:arrow-up`); hover a Phosphor mark → the tooltip
names Phosphor; hover a Game-icons mark → "Game-icons, by <author>" (a Lorc or Delapouite mark, for
instance). Choose a Game-icons glyph, Save → the chip shows it in white, or in the Icon color picked.
The README's Credits section names the three sets, their licenses and the Game-icons authors.
Typing in the search box keeps up without a hitch. Result:

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
General → Master controls → Preview as → Arathi Basin → the dial opens on the nodes with PREVIEW; nothing
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

## Icons tab

**ICONS-1. Look.** Comms Pad → Icons: Icon size 32 → the chips grow taller around the bigger icons;
Zoom 0.1 → each icon's edge is cropped; Desaturate → gray; Icon opacity 50% → faint; Tint red → a
white glyph turns red and a colored glyph darker. Show border, thickness 2, color white → a square
edge over each icon. Comms Dial → Icons: Show border → a round ring behind each wedge's icon; Icon size
20 → smaller icons, the wedges keep their size. Defaults on each page → the icons as before. Result:

**ICONS-2. Glow styles.** Comms Pad → Icons → Glow on: Pixel border → lines run around every icon;
Auto cast sparkles, Button (rotating rays) and Proc (flipbook) each look different, and each style's
knobs gray out under the others. With a full pad glowing in Pixel border, the frame rate stays where
it was. Result:

**ICONS-3. Glow triggers.** Glow when On hover → only the icon under the mouse glows; in combat too,
with no error. After sending → a chip glows for about a second and a half after its line is sent,
then stops; on a dial, send from a wedge and reopen the dial within a few seconds → that wedge glows
for about a second and a half from the open, then stops, and a later reopen shows no glow. In combat, `/qc set pad.icon.size 30` → no error, "updates after combat", the bigger
icons land at combat end. Result:

## Icons

**ICON-1. Choosing an icon.** Groups → a group of yours → Callouts → a row's edit glyph → Choose
icon… → double-click the skull → the icon beside Choose icon… is the skull (the popup has no Icon
box); Save → the row and the chip show the skull. Groups → a group of yours → General → no Icon text
box, an "Icon" label over the icon and Choose icon… → Glyphs → double-click a glyph → the group's
wedge on the Comms Dial shows it, and the General tab's icon follows. With that group selected,
`/qc set group.icon 136012` still sets it. Click the red clear glyph beside Choose icon… → the
General tab's icon is the question mark, the wedge shows no icon, and the clear glyph goes idle; in
the popup, a callout with an icon → clear glyph → the icon is the question mark, Save → the row and
the chip show no icon. A built-in set's General tab ("Dungeon (generic)") has the same Icon row and
Choose icon…: a glyph chosen there shows on its wedge. Result:

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
`/qc diagnostics` → the instanceID matches; a group's When → the Instance drawer → Add the instance
you are in adds that id. Groups → Preview as lists "M+ · Windrunner Spire" and the other seven by name. On a Devourer
Demon Hunter, `/qc diagnostics` → the Situation line reads `spec=1480`, and a When's Specialization
drawer offers Devourer. If you can enter Sporefall (map 1592), note whether it is a raid and its instanceID
(ruling R4 left it out of the shipped raids). Only after this check passes
does `defaults/GameIds.lua`'s note change from "matched" to "confirmed". In any dungeon or raid
outside the season, and in each arena you play: `/qc diagnostics` → the instanceID is one
`defaults/GameIds_Instances.lua` lists (INSTANCES, ARENAS), and the When editor names it the way the
client does; only then does that file's note say "confirmed". Result:

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
| INSTALL-1..3, SLASH-1..2, PANEL-1..3, PROFILE-1..2, STATE-1..3, COMBAT-1, DIAG-1..2, DEGRADED-1, LOC-1 | The phase 0 scaffold | No client pass recorded yet; LOC-1 re-enumerated in phase 5 and owed a non-English client pass; STATE-3 added and PANEL-2 rewritten with `/qc toggle` and Preview as in Master controls (2026-10-19) |
| SEND-1..5, PAD-1..10 | Phase 2: the send engine and the Comms Pad | No client pass recorded yet; PAD-8 added in phase 5 (audit QC-07); PAD-1 rewritten and PAD-9..10 added with the up growth, chip width and the built-in glyphs (2026-10-19) |
| EDIT-1..26 | Phase 3: the editors | No client pass recorded yet; EDIT-3, 4, 20 and 22 rewritten and EDIT-25..26 added with Preview as in Master controls, the Dungeon set, the Arena drawer, instance search, the Callouts rows and the glyph sets (2026-10-19); EDIT-1, 2 and 19 rewritten and EDIT-22..24 added with the When drawers, Inherit when conditions and the icon browser's search (2026-10-18); EDIT-2, 4, 5, 6, 11, 14 and ICON-1 rewritten and EDIT-19..21 added when the built-in sets became seeded groups, groups nested and the Preview tab became a table (2026-10-18); EDIT-1, 7 and 8 rewritten and EDIT-9..12 added when callouts moved into their groups (2026-10-17), SHARE-1 and ICON-1 rewritten with them; EDIT-9 and 10 rewritten and EDIT-13 added when the popup took the settings window's look (2026-10-17); EDIT-9, 13 and ICON-1 rewritten and EDIT-14..17 added with the icon browser and glyph colors (2026-10-18); EDIT-9 rewritten and EDIT-18 added when the token dropdown became the Text label's info glyph (2026-10-18); EDIT-13, 14 and ICON-1 rewritten when the Suggested tab went and the skin stopped waiting for the addon to be enabled (2026-10-18); EDIT-9, 18 and ICON-1 rewritten when the Icon boxes went and the popup took its two-column layout (2026-10-18); EDIT-9, 11 and ICON-1 rewritten with the clear glyph, the Preview gap and the buttons' 2 px inset (2026-10-18) |
| DIAL-1..12 | Phase 4: the Comms Dial | No client pass recorded yet; DIAL-9 rewritten when Preview as moved to Master controls (2026-10-19); DIAL-4 rewritten in phase 5 for the pinned ring; DIAL-12 added in phase 5 (audit QC-07) |
| SHARE-1..6, LOOK-1..2, ICON-1, BG-1..2, IDS-1 | Phase 5: share, polish and the instance ids | No client pass recorded yet; LOOK-2's in-combat step goes through `/qc set`; IDS-1 extended to the journal instances and arenas (2026-10-19) |
| ICONS-1..3 | Icons and polish (2026-10-19): the Icons tab | No client pass recorded yet |
