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
| STATE-1..4 | State | Enable/disable, the launcher menu, `/qc toggle`, the pads' hidden state across /reload |
| COMBAT-1 | Combat | The settings panel in combat |
| DIAG-1..2 | Diagnostics | The debug console, the report, perf |
| DEGRADED-1 | Degraded | The install with LibKa0s missing |
| SEND-1..5 | Send | Secure sends in keys and on bosses, the spam guard |
| PAD-1..15 | Pad | The Comms Pad, its growth and button width, the World (solo) and In Group sets and the built-ins' colors, the header click and icon only's width, the header's Quick Comms: text |
| EDIT-1..30 | Editors | The Pad and Dial page names; the Groups (with the callout popup, its EllesmereUI look and its token glyph, the icon browser, its search, its glyph sets and glyph colors, the Callouts rows, Reuse and the glyph lists, the built-in sets as ordinary groups and Restore, nested groups and Inherit when conditions, the Preview table, the When drawers, Preview while editing, a pad title's right-click, a preview click's echo), Comms Pad and Share pages, Preview as…, Why is this showing?, an older profile's conversion |
| DIAL-1..35 | Dial | The Comms Dial (Relaxed), its key and Bindings.xml, the battleground node dial, the lone-group open and the group ring, page arrows and the page row, Auto wedges, the ring radius, the Slice labels tab, the slices and the slice lit by direction, the Slices tab, the pointer, the tooltip outside the dial, the hub over the slices, the pointer, label and icon offsets, the Paging tab; the dial polish: the border gone, the slice gap, placement from W, a slice clicked to the hub in combat, the hub styles, the Group labels tab, Icon offset on Icons, 128-pixel icons, a click outside closing the dial in combat, the page indicators' background and border, the Hub tab |
| KEY-1..3 | Key bindings | A dial's key as WoW's own binding in Options → Keybindings, Character Specific Keybindings, Toggle Comms Pads |
| SHARE-1..6 | Share | Export and import strings, the report, refusals, unbound pads and dials |
| LOOK-1..6 | Pad header, Section header, Window | The Comms Pad's three window tabs: the section titles' font, the pad's border and background, the header's look, size and alignment, the tab strip and headings, the section header's band and height |
| BUTTON-1..2 | Buttons tab | The buttons' size, color, border and font; the button glow |
| ICONS-1..3 | Icons tab | The buttons' and wedges' icon look, border and glow triggers |
| ICON-1 | Icons | Choosing an icon, for a callout and for a group |
| ART-1 | Art | The dial's round art: the hub's styles, the dots and pill, the indicator background, the borders and the arrow plates |
| SHINE-1..3 | Shine | The shine overlay: each look on a pad and on a dial, and a pad and a dial keeping their own |
| BG-1..8 | Battlegrounds | Node winds on the dial; the battleground instance ids; the objective groups (Alterac Valley, Isle of Conquest's bases, a flag map) and their migration; the four node buttons; Silvershard Mines' and Temple of Kotmogu's groups |
| IDS-1 | Instance ids | The Midnight dungeons and raids |
| LOC-1 | [Non-English client](#non-english-client) | What a deDE or frFR client changes |

## Before you start

- Install the addon folder as `Interface\AddOns\QuickComms` and `/reload`.
- Keep the debug console closed unless a check opens it; `/qc debug` opens it.

## Install

**INSTALL-1. Loads clean.** `/reload` with only Quick Comms enabled → no Lua error, no chat line at
login, the addon listed in the AddOns list with the gold speech-bubble logo. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**INSTALL-2. Minimap button and broker.** Look at the minimap → the speech-bubble button is there;
hover it → the tooltip reads `Ka0s Quick Comms  v0.1.0`, `Enabled: Yes`, then the two click hints. A
missing icon (a blank or green square) is the failure. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**INSTALL-3. Reload keeps settings.** Untick **Minimap button**, `/reload` → the button stays
hidden; turn debug logging on with `/qc debug on`, `/reload` → it is off again (session-only).
Result: 2026-10-21, pass (the owner's run; client build not recorded).

## Slash

**SLASH-1. Help.** `/qc help` and `/quickcomms help` → the same index, gold commands, white
descriptions, every row present; `/qc` alone opens the settings panel. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**SLASH-2. No collision on `/qc`.** With the addons you normally run enabled, `/qc help` → Quick
Comms' index, not another addon's. Another addon answering, or nothing at all, is the failure (design
spec §3's phase 0 collision check). Result: 2026-10-21, pass (the owner's run; client build not recorded).

## Settings panel

**PANEL-1. Landing page.** Settings → AddOns → Ka0s Quick Comms → the logo once (not twice after
switching pages back and forth), the notes line, and the slash command list. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PANEL-2. Master controls.** General → the `Master controls` tab: Enable Ka0s Quick Comms beside
General visibility, Master scale beside Master alpha, Lock frame beside Debug console, Minimap button
beside Test mode, then Preview as alone on its own line, then Reset position beside Reset all
settings. Ticking Debug console opens the
console; unticking Minimap button hides the button at once. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PANEL-3. Defaults and Reset all.** Hide the minimap button, untick Enable, press the header's
Defaults button and accept → Enable is ticked again and the minimap button stays hidden. Result: 2026-10-21, pass (the owner's run; client build not recorded).

## Profiles

**PROFILE-1. The Profiles page.** Settings → Ka0s Quick Comms → Profiles → AceDB's page draws;
create a profile, untick Enable, switch back → the first profile is still enabled. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PROFILE-2. The profile verb.** `/qc profile` lists the profiles; `/qc profile <name>` switches,
and works while the addon is disabled. Result: 2026-10-21, pass (the owner's run; client build not recorded).

## State

**STATE-1. Disable stands everything down.** `/qc disable` → `/qc help`, `/qc version`, `/qc list`
and `/qc diagnostics` still answer; the minimap menu's Enabled entry is unticked and still clickable;
`/qc enable` → enabled again, and `enabled = true` is echoed. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**STATE-2. Launcher menu.** Right-click the minimap button → four entries, Enabled, Locked, Test
mode and Show window, each ticking the state it shows and toggling it; left-click → the settings
panel opens. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**STATE-3. Hide the pads.** `/qc toggle` → every Comms Pad hides, and nothing is printed to chat
(2026-10-21: the debug log has a `[Pads] hidden on this character until shown again` line); the minimap menu's Show window is unticked; the dials
still open. `/qc test` → the pads show as placeholders, and turning it off hides them again. `/qc
toggle` → the pads are back. Hide them, pull a training dummy and type `/qc toggle` → nothing changes
until combat ends, then the pads show, with no Lua error. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**STATE-4. The hidden state lasts, per character (2026-10-21).** `/qc toggle` → the pads hide.
`/reload` → they stay hidden. Log out and back in on the same character → still hidden; the minimap
menu's Show window is unticked. Log a second character → its pads show (its own choice). Back on the
first, switch profile (Profiles page) → still hidden. `/qc toggle` → shown; `/reload` → still shown.
Result: 2026-10-21, pass (the owner's run; client build not recorded).

## Combat

**COMBAT-1. The panel in combat.** Pull a training dummy and type `/qc` → a gray notice that the
panel can't open in combat, and no Lua error; with the panel already open on General, enter combat →
the page is covered and its controls refuse until combat ends. Result: 2026-10-21, pass (the owner's run; client build not recorded).

## Diagnostics

**DIAG-1. The report.** `/qc diagnostics` → the console opens with both markers naming Ka0s Quick
Comms and the `identity`, `settings`, `registration`, `integrations`, `situation`, `restrictions`,
`library`, `surfaces` and `send` sections; logging is on
afterwards. `/qc debug diagnostics` writes the same report again below the first. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAG-2. Perf.** `/qc perf` → the step panel opens with its own close mark; run A, B and finish →
the report prints the `bakeSurface`, `sendClick`, `padLayout` and `echoMatch` rows and no Lua
error. Result: 2026-10-21, pass (the owner's run; client build not recorded).

## Degraded

**DEGRADED-1. LibKa0s missing.** Rename `libs\LibKa0s` and `/reload` → no Lua error; one chat line
says the library is missing; `/qc disable` and `/qc enable` still work; `/qc list` says the settings
CLI is unavailable; `/qc config` says the settings panel is unavailable. Restore the folder after.
Result: 2026-10-21, pass (the owner's run; client build not recorded).

## Send

**SEND-1. Trash in a key.** In a Mythic+ key, out of combat and then on trash in combat, click
`Pulling` on the default pad → the party sees "Pulling next pack" both times; with `/qc debug on`,
the console shows an `Echo` line ending `sent`. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**SEND-2. A boss in a key.** On a key's boss, click `Lust` once → the party sees the line; the button
flashes gold. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**SEND-3. The spam guard on a boss.** On a boss, click two buttons about half a second apart → every
button dims for about a second after the first press; the second button flashes amber. If the game
drops it, the button flashes red and exactly one `[QC] … may have been dropped by the game` line
prints; if it arrives, no line prints. Never two lines for one press. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**SEND-4. A raid boss (C1).** In a raid (LFR is enough), the pad shows the raid set; on a boss,
click a `/raid` button → the raid sees it, the button flashes gold. A lead callout's tooltip reads
`Channel: Raid warning` only when you are leader or assist; otherwise its button carries a padlock and
its tooltip says why, and its label stops short of the padlock, not under it. A `/raid`
line that never arrives during the encounter is C1 failing: record it. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**SEND-5. Rebuilt between pulls in a key (C4).** In a key, between pulls, `/qc set
behavior.autoPromote true` → the pad rebuilds with no error and the next click still sends. An
"interface action blocked" error here is C4 failing: record it (the fallback bakes once at key
start). Result: 2026-10-21, pass (the owner's run; client build not recorded).

The C1–C9 checks of the phase 0 harness (design spec §19) are recorded in
`docs/brainstorm/go-no-go/`; SEND-4 and SEND-5 repeat C1 and C4 against the shipped addon.

## Pad

**PAD-1. First run.** On a fresh profile, enter a key → the default pad shows "Dungeon (generic)" with
eight buttons, with no channel letter at the right edge of any of them (the label runs to the edge);
the header reads `Quick Comms: M+ · <dungeon> +<level>`. Hovering a button shows its name, the exact line it sends
and `Channel: Party` in the party's chat color; a wedge on the Comms Dial shows the same lines. Every button shows its glyph in a color: Lust a red enraged face,
Need mana a blue drop, Res me a green ankh, GG a gold trophy, Pulling orange crossed swords, Kick
order a purple boot, Skipping a cyan figure, Chain pull red chains. Leave the key and zone into a
normal or heroic dungeon → the same set shows. On a profile saved before this build (it still shows
"M+ (generic)" with the bloodlust spell icon on Lust), `/reload` with this build → the set reads
"Dungeon (generic)" and Lust shows the red glyph; a set renamed before, or a callout whose icon was
cleared, keeps the player's choice. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PAD-2. The stale hint.** In combat, `/qc set behavior.autoPromote false` → the header shows
"updates after combat"; when combat ends it clears and the pad has rebuilt. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PAD-3. Lock, drag, position.** `/qc unlock` → a drag strip appears above the pad, exactly as wide
as the pad (add or remove a group so the pad widens or narrows → the strip follows); drag it
elsewhere; `/reload` → it is where you left it. In combat the strip will not drag, and a drag still
held when combat starts ends there, with no error. `/qc lock` → the strip is gone (it comes back, undraggable, only to carry PREVIEW or TEST MODE). General → Master
controls → Reset position → the pad returns to its default place, just below the center. The
launcher's Locked entry toggles the same lock. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PAD-4. Test mode.** `/qc test` → placeholder buttons, and the strip above the pad reads
`Comms Pad  TEST MODE` (TEST MODE in green; the strip shows even while locked, and will not drag
then; the header has no TEST MODE of its own); clicking one sends nothing. Rename the pad to a long
name → the strip stays as wide as the pad while the name and the marker fit, and widens past the pad only for a name too long for it. Pull something → test mode ends with one line and the real buttons return. `/qc test` in
combat → refused with one line. The Master controls checkbox and the launcher entry follow every
change. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PAD-5. Visibility and fade.** General visibility "Only out of combat" → the pad hides on the pull
with no error and returns after; Master alpha 50% → the pad is half transparent. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PAD-6. Disabled mid-combat.** `/qc disable` during combat → no "action blocked" error; the pad
stays until combat ends, then hides. `/qc enable` → it returns with live buttons. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PAD-7. A profile switch in combat.** `/qc profile <another>` during combat → the stale hint
shows, no error; after combat the pad is the other profile's. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PAD-8. The padlock mark.** Put a Say callout on the pad and pull an encounter (the chat lockdown) →
its button shows a small gold padlock in its top-right corner (the LibKa0s catalog's `lock` mark, not the pet-battle lock). With LibKa0s removed (DEGRADED-1)
the pet-battle padlock draws instead, with no error. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PAD-9. Up growth.** Pad → Layout → Growth offers Right and down, Left and down, Right and up
and Left and up (no Upward). Right and up → the header row sits at the bottom of the pad and the
sections stack upward above it; `/qc unlock` → the drag strip sits below the pad. Drag the strip
somewhere, then add a group to the pad → the pad grows upward and the strip stays where you left it;
`/reload` → the strip is still there. Left and up → the buttons fill right to left, still upward. Right
and down → the header is on top again, the strip above, and adding a group grows the pad downward
from a top edge that stays put. A profile saved with Upward growth loads as Right and up. A pad placed
before 2026-10-19 moves once on its first load, by up to its height (see Known Limitations in
`docs/ARCHITECTURE.md`); drag it back and it stays. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PAD-10. Button width and the section title.** Pad → Buttons → Button width reads 100 on a new
pad, and Layout no longer has it; drag it to 300 → wide buttons, each label on one line, running to the button's right edge with no
channel letter after it; down to 30 → the labels cut short, still
one line; down to 1 → icon-only slivers, no label and no Lua error. Make a group named `World`, put
it on the pad and stand in the open world → the header reads `Quick Comms: World` and the section under it has
no second `World` line; rename the group `My world` → its title line is back. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PAD-11. World (solo) and the built-ins' colors (groups polish).** Out of any group, in the open
world: the pad shows a World (solo) section of nine buttons, each tooltip reading `Channel: Say` (Rare spotted a gold spyglass,
Elite help a red ogre, Group quest a gold scroll, World boss a red crowned skull, Event here an orange
bell, Invite me a blue envelope, Thanks green hands, AFK a white cup, Back a cyan arrow).
Target a mob and click Rare spotted → /say reads "Rare spotted here: <target>"; click Invite me →
/say reads "Invite please". Join a party → the set is gone. On the Groups page every built-in group's
icon is a colored glyph named for it (Dungeon a purple gate, Arathi Basin a gold wheat sheaf, each
node its own), and no set's callouts are all white. On a profile saved before this build, `/reload`
→ World (solo) is added at the end of every pad and dial; the built-in callouts and groups take their
colors, except one whose icon or color you changed; each node battleground set gains its map-wide
callouts once, at the end of its list; a battleground set you had deleted does not come back.
`/reload` again → nothing changes and nothing is added. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PAD-12. In Group (bg buttons).** Join a party → the pad shows an In Group section of twelve buttons
after the content sets (Hello a gold waving hand, tyff a green meal, Buffs please a purple arm,
Healthstone a green potion, GLHF a green clover, ggty gold hands, ggnt a cyan thumb, ty a green
handshake, brb a white cup, Ready a green check, Drink a blue flask, Summon a purple portal), the set's
own icon three cyan figures. Click GLHF → party chat reads "GLHF"; Drink → "Drinking"; Summon →
"Summon please!". Convert to a raid → the same buttons send to raid chat; in a battleground or a
dungeon finder group → instance chat, and the battleground's own set is still first on the pad and
the dial opens on its groups, the battleground's set and In Group among them (DIAL-2). Leave the group → the In Group section is gone. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PAD-13. Click the header to collapse.** Left-click anywhere on the pad's header row (on "World",
not only the − button) → the pad folds to its header and the button reads +; click the row again → the
buttons come back. A right-click on the row does nothing. In combat a click prints the one-line refusal
and the pad stays as it was. The mouse wheel over the row still switches tabs, and hovering it still shows
"Why is this showing?".

**PAD-14. Icon only has no spare width (2026-10-20).** Pad → Layout → Button style Icon only, a
grid of 4 columns, in the open world (`Quick Comms: World` in the header) → the gap between the last button and the
pad's right edge is the same as between the first button and its left edge (before, the right one was
wider). Button style Icon and label → the same even gap. Enter a key, whose header text is longer than
four icons → the pad widens just enough for the text and the collapse button. With a Say callout in
the pad's groups, Preview as… an arena → LOCKDOWN shows after the header text and the pad widens for
it too: it clears the collapse button and stays inside the right edge. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PAD-15. The header reads Quick Comms: (dial polish, 2026-10-21).** Solo in the open world → the pad's
header reads `Quick Comms: World`; in a key → `Quick Comms: M+ · <dungeon> +<level>` (Windrunner
Spire +14, for one). A section title that names the situation (a group named `World` in the open world)
is still hidden under it (PAD-10). Preview as… → `Preview: …`, and test mode → `Test mode`, as before.
Result: 2026-10-21, pass (the owner's run; client build not recorded).

## Editors

**EDIT-1. A callout and a group on the pad (the phase 3 exit).** Settings → Groups → New group; on
its Callouts tab click Add callout → the callout popup opens blank (Smart group, no icon); name it
`Inc`, text `INC {skull}`, Save → the popup closes and `Inc` is the list's last row. On the group's
When tab click the Content header and tick M+ in its drawer. Enter a key → the pad shows the new group first with
an `Inc` button; click it → the party sees "INC" with a skull. Leave the key → the group is gone from
the pad. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-2. A built-in set is an ordinary group (the phase 3 exit, rewritten 2026-10-18).** Groups →
pick "Dungeon (generic)" → the picker shows no "(built-in)" tag (in a key it reads `Dungeon (generic)` with the
green dot after the name, not before it; Pad → Groups and Dial → Groups put it after the name too), and the page draws the same tabs as a
group of yours, nothing read-only. General: Name, Enabled, Parent group,
the icon with Choose icon…, Duplicate and Delete, then Restore built-in groups; no Customize and no
read-only line. Callouts: the callout table, exactly as a group of yours draws it (Add callout, Reuse
callout with Add, a boxed row per callout with its handle, icon, name and channel, edit and remove
glyphs); no Show checkboxes. When: the editable condition drawers (EDIT-22), Content's summary
reading M+ in gold; not read-only text. Rename a callout in the popup and Save → in a key, the button's label
changes. Untick Enabled → in a key the set is gone from the pad; tick it again. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-3. Preview as….** Out of combat, in the open world: General → Master controls → Preview as → Arena →
the pad shows the arena set with `Preview: Arena` on its header and PREVIEW on its drag strip (in
green, after the pad's name); clicking a button sends
nothing to chat and prints its line locally (EDIT-29); its tooltip says so. The Comms Pad, Comms Dial and Groups pages' General tabs have no
Preview as row. Close the settings → the preview ends. `/qc preview raid:heroic` →
the raid set; pull something → the preview ends with one line and the live buttons return. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-4. Why is this showing?.** In a key, hover the pad's header → the tooltip lists "Dungeon
(generic): Content" (and any other group, with its rows); with a `/raid` callout on the pad
outside a raid, the last line names the lock. Behavior → Explain why groups show off → no tooltip.
`/qc why` prints the same lines per pad. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-5. The Pad page.** Pad → Layout: Orientation Vertical, Button style Label only,
Scale 1.5 → the pad redraws each time. Type X `200`, Y `-100` → it moves; Reset this pad's position
→ it returns. General → Visibility Only out of combat → it hides on the pull with no error. Groups:
drag a group to the top → it comes first on the pad. New pad → a second pad appears holding every
built-in group you still have (top-level, in shipped order); Delete pad (Yes) → it is gone. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-6. Restore built-in groups (rewritten 2026-10-18; the Share page's Built-in tab is gone).**
Share has two tabs, Export and Import. Groups → "Raid (generic)" → Delete (Yes) → it is gone from the
picker and, in a raid, from the pad. On "Dungeon (generic)"'s Callouts tab remove "Lust" (Yes). General →
Restore built-in groups (no question asked) → one chat line counts the groups and callouts that came
back; "Raid (generic)" is in the picker again and last on every pad's and dial's Groups list, and
"Lust" is the last row of Dungeon (generic)'s Callouts. Click Restore again → "nothing to restore", and
nothing is added. Delete "Lumber Mill" (inside "Arathi Basin") → Restore → it is back, indented under
Arathi Basin in the picker, and in Arathi Basin (or Preview as → Arathi Basin) its wedge is on its
wind, SW, again. Rename "Dungeon (generic)" → Restore leaves it as it is and adds no second dungeon set. With
every group deleted, the "No groups yet" General still offers Restore built-in groups. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-7. An edit during combat.** With a user callout on the pad (its id is `c<n>`: `/qc get
callout.name c1` names the first), in combat type `/qc set callout.text c1 Incoming now` → no error,
the header shows "updates after combat"; after combat the button sends the new text. `/qc set
callout.text Incoming now` (no id) is refused with a line naming the id form and writes nothing.
Opening the settings in combat is refused, as before. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-8. The selection survives what other pages do.** Select a group of yours on the Groups page,
then `/qc profile Other` and back → the Groups page shows a group that exists, never an empty or
erroring page. Delete the selected group (Yes; the line says its callouts go too) → the page moves
to the next group, and the deleted group's callouts are offered nowhere (Reuse callout no
longer lists them). Result: 2026-10-21, pass (the owner's run; client build not recorded).

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
bottom. Clicking the page behind it does nothing. Type more text and press Enter → Preview follows the edit, while the button on
the pad still sends the old line; type text long enough that Preview wraps onto another
line → the window grows with it. Clear the Name and click Save → the popup stays open and a red line names Name;
nothing changed on the pad, and the window grew to show the red line. Type a name back, click Choose icon… and double-click an icon in the browser, Save → the popup
closes, the row and the button show the new name, text and icon. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-10. Cancel leaves nothing behind.** Add callout → type a name and text → Cancel → no new row,
and `/reload` shows none either. Edit a callout, change its text → press Escape → the old text
stands. Edit again, change it → click the close X → the old text stands. Edit again → close the
settings window (or `/qc profile Other`) → the popup is gone with it, nothing saved. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-11. Reuse makes a copy.** On group A's Callouts tab, open Reuse callout → your
callouts read `<group>: <callout>` (none of group A's own: they are left out), a seeded set's
`<set>: <callout>` and a battleground node's `<set>: <node>: <callout>` (Arathi Basin's and
Deepwind Gorge's Farm read apart), all in one alphabetical list (by group, then callout); the group part is a
muted gold, the callout's name white. The dropdown runs across the row with Add at its right
edge, Add as tall as the dropdown, and Add callout above spans the same width: the right edges of
Add callout and Add line up, a hair (2 px) short of the list's boxes, and **both buttons' right
borders are whole** (not shaved by the page's edge). In the list, every row's handle, icon, name and
glyphs sit centered in its box, and the edit and remove glyphs are small and close to the box's
right edge (the same on Pad → Groups and Dial → Groups). Pick one of group B's callouts → nothing is added yet; click Add → it is A's
last row. Edit the copy's text and Save → B's original is unchanged (check its row or its button).
The list has no built-in section: "Dungeon (generic): Lust" is listed like any other group's callout;
reuse it → a copy you can edit, and the M+ group's Lust is unchanged. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-12. The remove glyphs.** On a group's Callouts tab, a row's remove glyph (the red no-entry
sign; its tooltip reads Remove, "Delete this callout. Asks first.") → the confirmation names the callout;
No keeps it, Yes deletes it, and Reuse no longer offers it. On Pad → Groups, a row's remove
glyph (its tooltip: the group itself is kept) → the group leaves that pad at once, with no question, and is still on the Groups page; the
same on Dial → Groups. Neither list has an edit glyph. Result: 2026-10-21, pass (the owner's run; client build not recorded).

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
Lua error appears. Result: 2026-10-21, pass (the owner's run; client build not recorded).

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
the popup shows the skull (the button on the pad does not change until Save). Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-15. The Game icons tab.** In the browser, Game icons → thousands of icons (the count reads in
the thousands), the same ones the macro icon selector offers. Scroll with the wheel and drag the
scrollbar from top to bottom → it keeps up without a hitch, and each icon draws (no blank or green
square). Hover one → "Texture id N". Show → Spells, then Items → each list is smaller, and All is
both. Choose a game icon, Save → the button and the row show it. If the tab says the game's icon list
has not loaded yet on the first open after a login, open it again a moment later → the icons are
there. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-16. A glyph's color, everywhere.** Choose a glyph for one of your callouts (Glyphs tab), then
Icon color → Blizzard's color picker opens **above** the browser; pick orange → every glyph in the
grid and the footer turns orange. Choose, Save → the button on the pad, the wedge on the Comms Dial
(test mode) and the callout's row on the Callouts tab show the glyph in orange; the popup's icon too
when it is opened again. On a group of yours, General → Choose icon… → a glyph, Choose → then Icon
color → green → the group's wedge on the dial is green at once. Now choose a raid marker for that
group → the marker is drawn in its own colors, the swatch grays out, and choosing a glyph again
shows it white (the color went with the marker). Export the orange callout's group (Share → Export),
import the string → the copy's glyph is orange too. `/reload` → every color is still there. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-17. What closes the browser.** Open the browser from the popup and press Escape → the browser
closes and the popup stays open; press Escape again → the popup closes, nothing saved. Open the
browser from the popup, click its close X → the same as Cancel. Open it again and close the settings
window (or `/qc profile Other`) → the browser and the popup are both gone and nothing is saved; no
Lua error. Open it from a group's General tab and `/qc profile Other` → it closes the same way, and
the group's icon is unchanged when you switch back. In combat, the settings panel cannot be opened; with the browser
open on the pull, the panel's combat cover lies over it and Choose (a double-click too) prints one
line and changes nothing. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-18. The token glyph beside Text.** Edit a party callout (EDIT-9) → a small white "i" sits
just right of the Text label, no taller than the label's letters, centered on them and clear of the
box under it. Hover it → a tooltip headed Tokens lists each token with one line of help ({target}, {focus},
the eight markers, {me}, {spec}, {role}, {key}, {dungeon}, then {spell:ID}), with no
{group1} … {group8} line, and fits on screen without wrapping each line. Pick Raid as the Channel
and hover again → one {group1} … {group8} line appears (no Save needed). Move off → the tooltip
hides. Cancel, then open another settings page with text boxes (a group's General tab) and open
the popup again a few times → no stray "i" appears beside any other box, and the popup shows
exactly one. Result: 2026-10-21, pass (the owner's run; client build not recorded).

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
Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-20. The Preview table.** Groups → "Dungeon (generic)" → Preview → the active-now line, then a gold
header row, "Callout" and "What it sends here", then one box per callout like the Callouts tab's rows
(switch between the two tabs: the same fill and border, and the same left and right edges): the
callout's icon (in its color) and name on the left, what it sends here on the right, or, outside a
key, why it sends nothing. Give a callout a long text → its row grows, the text wraps inside the
right cell, and the name and the text stay centered in the row. Preview as → an M+ dungeon → each
row's text changes in place to the baked line. "Arathi Basin" → a titled table per node (Stables,
Lumber Mill, …), each with its header. A new group with no callouts → "This group has no callouts
yet." and no table. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-21. An older profile converts once.** On a profile saved before the built-in sets became
groups (the owner's, with a hidden built-in callout, one set unticked on the old Built-in tab, and
one customized copy), `/reload` → no Lua error; the Groups picker lists every built-in set by name,
with no "(built-in)" tag and no duplicates; Pad → Groups and Dial → Groups list them in
the same places as before; the unticked set is a group with Enabled unticked; the hidden callout is
missing from its group (Restore built-in groups brings it back); the customized copy is there with
your edits, in its place, with no stock set beside it. `/reload` again → nothing changes and nothing
is added. Result: 2026-10-21, pass (the owner's run; client build not recorded).

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
header opens. Result: 2026-10-21, pass (the owner's run; client build not recorded).

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
Export), import the string → the copy's child does not inherit either. Result: 2026-10-21, pass (the owner's run; client build not recorded).

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
the Wowhead window closes with it. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-25. The Callouts rows and the window and Buttons tabs.** Groups → "Dungeon (generic)" → Callouts → each
row reads its icon, the name in gold, the channel's short label in its chat color (Party blue,
Say white) and the start of its text in a muted white, cut at 40
characters with "…". A callout with no icon shows the question mark; a callout whose text holds a
`|` shows the bar, not a color change; a Smart channel takes the color of the channel it resolves to
now (solo: Party). Pad → Pad header and Section header → the Size, Font, Background and Border
headings, Window → the Background and Border headings, General → the Visibility heading, each heading once; Pad → Buttons → the Size, Color, Border, Font and Glow
headings, each once. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-26. The glyph sets and their credits.** Open the icon browser (EDIT-14) → Glyphs: the count
reads over five thousand. A set dropdown left of Icon color reads All; pick Open Iconic → only the
original marks (the count about two hundred), Phosphor → the Phosphor marks, Game-icons → the
thousands of game marks; All → every set again. The search (EDIT-24) filters within the set picked.
Labels drop the set prefix (`Arrow up`, not `ph:arrow-up`); hover a Phosphor mark → the tooltip
names Phosphor; hover a Game-icons mark → "Game-icons, by <author>" (a Lorc or Delapouite mark, for
instance). Choose a Game-icons glyph, Save → the button shows it in white, or in the Icon color picked.
The README's Credits section names the three sets, their licenses and the Game-icons authors.
Typing in the search box keeps up without a hitch. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-27. Preview while editing.** Out of combat, in the open world: Settings → Groups → the band
draws the Group picker's box under its label, New group to its right and level with the box, and
Preview while editing, ticked, under the Group picker; pick another group and the three are still
drawn. Pick "Arena" → every pad shows only the
arena set, with `Preview: Arena` on its header and PREVIEW on its drag strip, and dial 1 opens on it; clicking a button
sends nothing to chat and prints one local line, `[QC] /<slash> <text>` (the channel's slash and the
callout's text with its tokens filled in, `{me}` as your name). Pick a battleground set → its own callouts and every node show, outside the
battleground. Set General → Master controls → Preview as → Raid · Heroic, then back on Groups → the
edited group still shows alone; go to another settings page → the pads show the Raid · Heroic
preview again; close the settings with the X → the live pads. On Groups, untick Preview while
editing → the live pads at once; tick it → the group again. Enter combat with the page open → the
pads go live with one "Preview ended" line; leave combat with the page still open → the edited
group's preview comes back. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-28. Right-click a group title.** Out of combat, in a battleground (or with Preview as →
Arathi Basin): hover a section title on the pad → the tooltip names the group and says Right-click
to edit this group. Left-click it → nothing. Right-click it → Settings opens on Groups with that
group in the picker. Pick the Callouts tab, close the settings, right-click a node's title → Groups
opens on that node, still on Callouts. Set the pad's Groups as to Tabs → right-click the tab's title →
the group that tab shows. Enter combat and right-click a title → the "cannot open settings during
combat" line and nothing opens; no error. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-29. A preview click echoes its line.** Out of combat, solo in the open world: make a group
with a callout `Go {me}` on Yell and put it on the pad and the dial. Master controls → Preview as →
World · Solo → click the button → one local chat line, `[QC] /y Go <your name>`, and nothing said
aloud (no yell bubble, nobody else sees it). Change the callout to Smart group and preview Raid ·
Heroic → the click prints `[QC] /raid Go <your name>`. Open the dial on the preview and click the
wedge → the same line, and the dial closes. On Groups with Preview while editing ticked, click a button
of the edited group → its line prints the same way. End the preview and click the live button → the
yell goes out, with no `[QC]` line. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-30. The Pad and Dial pages (dial polish, 2026-10-21).** Open the settings → the pages under Ka0s
Quick Comms read General, Groups, Pad, Dial, Share, Profiles (no "Comms Pad" or "Comms Dial" page).
The default pad and dial are still named Comms Pad and Comms Dial in their pickers, Share → Export
still lists them by those names, and a dial's ring of groups is still titled Comms Dial. Delete every
dial, then `/qc set dial.radius 120` → "No dial to edit: make one on the Dial page." Result: 2026-10-21, pass (the owner's run; client build not recorded).

## Dial

**DIAL-1. Open and close (Relaxed).** Options → Keybindings → Ka0s Quick Comms → Open Comms Dial 1:
bind G (Settings → Dial has no Binding tab: General, Groups, Wheel, Slices, Hub, Paging, Slice labels, Group labels,
Icons, Preview).
In a key (any content with an active group), press G → the dial opens in the middle of the screen: a
dark disc made of slices with no lines between them (Slice gap 0), wedges with bare icons (no
round backdrop behind them) and white labels wholly outside the disc, clear space between each icon
and the disc's edge, a gold solid circle on a dark hub, and a gold chevron pointer just outside the hub that follows the
cursor. Press G → it closes. Open it; Escape → it closes and the game menu does not open. Open
it; right-click a wedge → it closes and nothing is sent. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-2. A wedge sends in a boss (the phase 4 exit; rewritten in the dial rework, 2026-10-21).** In
a party on a raid or M+ boss, press G → the dial opens on the ring of groups (Dungeon or Raid
(generic) and In Group: several active groups); click the raid or dungeon set → its callouts; click a
callout wedge → the group sees the line, the dial closes, and there is no "action blocked" error or
red text. With the dial closed, 1 still fires your action bar's first button. Press G again at once →
every wedge is dimmed for about a second (the spam guard). Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-3. The Categories two-stroke (the phase 4 exit).** With two groups active (an always-on group of
your own and M+ in a key): press G → the first ring shows the groups; click one → its callouts; click
a callout → it is sent. Open again, click a group, click the hub → back to the groups; click the hub
again → the dial closes. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-4. The Arathi Basin node dial (the phase 4 exit; pinned in phase 5; three rings since the dial
rework).** In Arathi Basin, with Wedges per ring at 4: press G → the ring of groups (Arathi Basin,
Battleground (generic), In Group); click Arathi Basin → all five nodes on one ring, no page arrows,
each on its compass wind (Blacksmith N, Gold Mine NE, Farm SE, Lumber Mill SW, Stables NW), with an
Arathi Basin wedge (the gold wheat sheaf) on E, the first wind left free, that opens the map-wide
callouts (groups polish); click Lumber Mill, then INC → instance chat shows "INC Lumber Mill". Open
again, open Arathi Basin and press 5 → Lumber Mill's ring opens (the number keys count the shown
wedges clockwise from N). (If the dial does not show Arathi Basin at all, the instance id may be
wrong: run `/qc diagnostics`, copy the `situation` section's instanceID into the "Battleground
instance IDs seen" table of `docs/brainstorm/go-no-go/round-4-build-checks.md`, and file it with
this check's ID; BG-2 confirms the ids.) Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-5. Number keys, the wheel, the page arrows and dots (dial rework, 2026-10-21).** Wheel →
Wedges per ring 4, in a key: open, open a group with more than four callouts, press 3 → the third
wedge's callout is sent. Open it again → no More wedge; under the dial, below the bottom label, a
left and a right arrow (round dark plates, each with a gold chevron; not Blizzard's spellbook page
arrows) with a row between them: a gold pill for this page and a small gray dot for each other page,
the left arrow dimmed on page 1. Hover a live arrow → its plate lights and its tooltip shows outside
the dial. Click the right arrow → page 2, the pill moved to the second place, the dial still open and
nothing sent; on the last page the right arrow is dimmed and does nothing. Left arrow key → back a
page; Right arrow key → on; scroll down → on, up → back. Click the hub on page 2 → up to the ring of
groups (not page 1). A ring of one page shows no arrows and no dots, and there the Left and Right
arrow keys still turn your character. After the dial closes, 1–8, the arrow keys, Escape and the
mouse wheel do what they did before. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-6. The key is set only in WoW's key bindings (dial rework, 2026-10-21).** Options →
Keybindings → Ka0s Quick Comms → bind Open Comms Dial 1 to TAB (WoW asks to take it from Target
Nearest Enemy; accept) → TAB opens the dial (set it back afterwards). `/qc disable` → TAB opens
nothing (it stays bound: a WoW binding is not handed back); `/qc enable` → TAB opens the dial again.
Settings → Dial: no Binding tab and no Key box on any tab. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-7. Open at the cursor, the dial's place, Reset position.** Wheel → Open at → At the cursor →
press G away from the middle → the dial opens centered on the cursor, in combat too (a restricted
`SetPoint` to `$cursor`, verified 2026-10-21). Back to At its place; set Y to 150 → it opens higher; Reset this
dial's position → the middle again. General → Master controls → Reset position → pads and dials back,
one chat line. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-8. Edits and disable in combat.** In combat: `/qc set dial.slices 8` → no error, and the hub
shows "updates after combat" when G opens it; after combat it has eight wedges. In combat with the
dial open: `/qc disable` → no error, the dial keeps working until combat ends, then it is gone and G
opens nothing (still bound in WoW's key bindings). Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-9. Test mode and Preview as.** Out of combat: `/qc test` → dial 1 opens at its place with
placeholder wedges and TEST MODE above the hub; clicking sends nothing; 1 still fires the action bar.
General → Master controls → Preview as → Arathi Basin → the dial opens on its groups with PREVIEW, and Arathi Basin opens the nodes; nothing
sends; Escape closes the settings window (not the dial), which ends the preview and closes the dial.
Turn test mode on, then pull a target dummy → test mode ends; the dial closes at once or, if combat
won the race, at combat end, and in between 1–8 and Escape still do what they always do. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-10. The hub and the drop flash.** Hover the hub → "Why is this showing?" lists the groups and their matched rows;
with a Say callout on the dial during an encounter, LOCKDOWN shows above the hub; Behavior → Explain
why groups show off → no tooltip. `/qc why` lists the dials too; `/qc diagnostics` has `dials` and
`bindings` sections naming the key. If a wedge's send is ever reported dropped (the [QC] note), reopen the
dial within 5 s → that wedge shows red. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-11. Mouse-button keys, two dials, labels.** Bind Open Comms Dial 1 to BUTTON3 (middle mouse) in Options → Keybindings: press it
over the world → the dial opens; press it again with the cursor on a callout wedge → the dial closes
and nothing is sent; on the hub → it closes. A side button (BUTTON4) click on a wedge also closes
without sending, and the restricted snippet's other-frame `RunAttribute` raises no error. New dial →
bind Open Comms Dial 2 to H; press G, then H → dial 1 closes and dial 2 opens; press 1 → dial 2's first wedge, never dial
1's; close it → 1 fires the action bar again. In Preview as Arathi Basin (open the set) the ring title sits above
the N wedge's label, and every label sits outside the disc, reading away from it. With test mode on, close the
dial with the hub, then change Wedges per ring → it stays closed. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-12. The hub and the wedge padlock (the red ✕ retired in the dial polish, 2026-10-21).** Open the
dial → the hub is a dark backdrop with a gold circle and no ✕, and during an encounter a Say callout's wedge shows
the same small gold padlock as a pad button (PAD-8). With LibKa0s removed (DEGRADED-1) the pet-battle padlock
draws instead, with no error. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-13. One group opens straight on it; several open on the groups (dial rework, 2026-10-21).**
Solo in the open world (World (solo) the only active group), press G → the dial opens straight on
World (solo)'s callouts, no ring of groups. Join a party in the open world → press G → the ring of
groups (World (solo) is gone, In Group and any always-on group of yours); click In Group → its
callouts. Enter a dungeon with the party (or start a key) → the ring of groups shows Dungeon (generic)
and In Group; click one → its callouts. Settings → Groups → any group → General: no Open the dial
on this group and no Skip on the dial in content. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-14. Auto wedges (dial rework, 2026-10-21).** Settings → Dial → Wheel → Wedges per ring
shows Auto first; a new dial (New dial) is on Auto. On Auto, with a group of your own holding 1, 2,
3, 4, then 5 callouts (add them one at a time, Preview as wherever it is active): 1 → the one wedge
at W (left); 2 → W and E; 3 → W, N and E, with S empty; 4 → W, N, E and S; 5 → five evenly spaced,
the first at W, going clockwise. The slices split the ring to match. With 13 or more callouts → 12
on page 1 and the rest on page 2, behind the arrows. A ring of groups holds at most 8 a page. The
Preview tab lists wedge 1 as W. Pick 6 → six slices from W whatever the count (DIAL-27). Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-15. The ring radius (dial rework, 2026-10-21).** Wheel → Ring radius reads 100. Drag it to 160
→ the dial redraws bigger: the wedges further out, the disc grown with them, the labels still outside
the disc, the title above the top label and the page arrows below the bottom one. 70 → small, the
labels still clear of each other at four wedges. In combat, `/qc set dial.radius 140` → no error,
"updates after combat", the new size at combat end. Defaults → 100. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-16. The Slice labels tab (dial rework, 2026-10-21; Labels until the dial polish).** Dial → Slice labels: Show labels ticked, then a
Font block (font, size, outline, color, Use class color, shadow). Font size 18, Thick outline, color
yellow → the wedges' labels redraw that way and the title and page arrows move out to clear them; Use
class color → your class color; untick the shadow → no shadow. Untick Show labels → the icons alone,
the font controls grayed out, the title and arrows come in closer; hovering a wedge still names it.
Defaults → white 12-point labels again. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-17. A stored dial keeps its wedges (dial rework, 2026-10-21).** On a profile made before the
update, the dial keeps its Wedges per ring (4 stays 4; only a new dial starts on Auto); `/reload` →
no Lua error, and Groups pages carry no Open the dial or Skip on the dial boxes. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-18. The slice under the cursor lights whole (dial slices, 2026-10-21; by direction since the
hub fix).** Open the dial on a four-wedge ring. Move the mouse just outside the hub toward E, between
the hub and the E icon, not on it → the whole E slice, hub to rim, takes a faint gold fill. Sweep
round the hub → the lit slice follows the mouse's direction; over the hub or past the rim →
nothing lights; on a three-callout Auto ring the empty S quarter never lights. Close the dial → the
fill goes. A click anywhere in the lit slice sends it (DIAL-28). In combat → the same, no error. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-19. The Slices tab (dial slices, 2026-10-21; Border replaced by Gap and Hub added in the dial
polish; Hub and Pointer on the Hub tab since).** Dial → Slices: three headings (Background, Gap, Highlight), each color with Use class color. Background a blue → every
slice fills blue, an empty place (S on a three-callout Auto ring) too. No Border heading and
no lines between the slices (DIAL-25). Highlight green → a
hovered slice fills green; Use class color → your class color. Defaults → dark slices, no gap,
the gold highlight. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-20. The pointer (dial slices, 2026-10-21).** Hub → Pointer: Pointer size 40 → the chevron
in the hub is bigger and sits further out so it never covers the hub's circle; Pointer color white → white;
Use class color → your class color. Untick Show pointer → no pointer while the dial is open, and its
size and color are grayed out. Defaults → the gold 20-pixel chevron. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-21. The tooltip outside the dial (dial slices, 2026-10-21).** Hover a wedge → its tooltip
(name, line, channel) shows above the dial, over the ring's title, never over the slices or a label;
hover the hub → Why is this showing? shows there too. Slice labels → Tooltip side Below → under the page
arrows (or under the bottom label on a one-page ring); Left → left of the disc, clear of the longest
label on that side; Right → mirrored. Tooltip offset 40 → each 40 pixels further out. Ring radius
160 → the tooltip still clears the bigger dial. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-22. The hub draws over the slices (2026-10-21).** Open the dial with the default Slices look,
then Background alpha 100% → the hub's backdrop and circle stay bright on top; the pointer is drawn over
the slices; the stale hint, LOCKDOWN and PREVIEW labels near the hub stay readable. Click the hub →
it still goes up a ring or closes. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-23. Pointer, label and icon offsets (2026-10-21).** Hub → Pointer offset 70 → the pointer
circles 70 pixels from the middle; 0 → back just outside the hub. Slice labels → Label offset 250 → every
label sits further out, the ring title above them and the page row below them; 0 → just past the
disc; untick Show labels → the offset grays out. Icons → Icon offset 60 (a Wheel row until the dial polish) → the icons sit closer to the
hub, the disc keeps its size and each slice still lights and clicks; 0 → back on the ring radius.
Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-24. The Paging tab (2026-10-21).** On a paged ring (World solo), Dial → Paging: three
headings (Position, Arrows, Page indicator). Offset 30 → the row drops further under the labels.
Arrow size 40 → bigger round plates and chevrons; Arrow spacing 30 → they stand further from the
dots; Arrow color white, Arrow background red → as set (the dimmed end arrow stays gray). Dot size
10, Current page width 10 → the pill becomes a plain dot; Dot spacing 15; Current page color green,
Other pages color white → as set; Use class color → your class color. Defaults → the gold 24-pixel
arrows and the 18-by-6 gold pill. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-25. The slice border is gone; an older profile loads clean (dial polish, 2026-10-21).** On a
profile saved before the update with Border size 3 in red: `/reload` → no Lua error; the dial draws no
lines between its slices and no rim; Dial → Slices has no Border heading; `/qc get dial.slice.borderSize`
→ an unknown setting. `/qc diagnostics` → its `dials` section's `slices` line reads `gap=0` and names no
border. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-26. The slice gap (dial polish, 2026-10-21).** Dial → Slices → Gap → Slice gap 10 → a clear,
even strip 10 pixels wide between every pair of slices, straight-edged (parallel, not a wedge), the
slices' outer edges still on the disc; the lit slice's fill moves with it. On a one-callout Auto ring
→ the whole disc, no gap. 20 → wider strips, no Lua error. On Auto with 12 or more callouts and Slice
gap 20 → fewer wedges a page than at 0 (the icons still fit), the rest paged; on a fixed 8 the count
stays 8. Defaults → 0. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-27. Slice placement from W (dial polish, 2026-10-21).** Wheel → Wedges per ring 4, with a group
of your own holding 1, then 2, 3 and 4 callouts (Preview as wherever it is active): 1 → its wedge W,
the three other quarters drawn empty; 2 → W and E; 3 → W, N and E, S empty; 4 → W, N, E and S. An
empty quarter never lights and a click on it sends nothing. Wedges per ring 8 with 2 callouts → the
two at W and NW (clockwise from W), six empty slices. Wedges per ring 6 → the first slice centered on
W. The Preview tab lists wedge 1 as W, and the number keys 1–8 still follow the callouts' order. A
battleground node ring (Arathi Basin) keeps its compass winds (DIAL-4). Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-28. A slice clicks all the way to the hub, in combat (dial polish, 2026-10-21; owed: the
restricted `GetMousePosition`, C7).** On a four-wedge ring at radius 100, put the cursor just outside
the hub toward E, well inside the E icon → the E slice lights and its tooltip shows; click → it sends.
The same just inside the rim, and next to a neighbor's border. Hold Shift (then Ctrl, then Alt) and
click the E slice → it still sends. On a 12-wedge ring, on each diagonal (NE, SE, SW, NW), put the
cursor just outside the hub's drawn circle → that slice lights, shows its tooltip and sends (the hub
is round: no dead corner). Just inside the circle → no slice lights, the hub's circle brightens and
its "Why is this showing?" tooltip shows; move out → both clear. A click inside the circle goes up a
ring (or closes on the first ring), and so does one with Shift, Ctrl or Alt held. The dial's key
still opens and closes it; a click on an empty place sends nothing; a right-click anywhere on the disc closes the dial
and sends nothing. Then in combat on a target dummy, repeat each click → the same, with no "action
blocked" error and no Lua error. With Slice gap 10, a click in a gap sends the slice whose direction
it is in. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-29. The hub styles (dial polish, 2026-10-21).** Dial → Hub → Hub: Hub style Solid circle (the
default) → a gold filled circle on a dark backdrop, no ✕; Hollow ring → a gold ring; Target → a ring
with a dot in the middle; Rimmed disc → a rim round the backdrop and a filled circle inside it. Line
width grayed out under Solid circle and 4 → a thicker ring under Hollow ring. Hub size 70 → a wider hub,
the slices and the pointer starting at its edge in every direction, and a click just outside its
circle, on a diagonal too, lands on a slice (DIAL-28); Circle size 40 → a bigger circle. Backdrop color, Hub border size 3 with a red Hub border
color, Circle color green, each Use class color → as set. Hover the hub → the circle brightens; move
off → it dims. The stale hint, LOCKDOWN and TEST MODE labels sit where they did. Defaults → the gold
solid circle on the 40-pixel hub. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-30. The Group labels tab (dial polish, 2026-10-21).** Dial → Group labels: Show group labels
ticked, then a Font block. Font size 18, a different face, Thick outline, color white → the ring's
title above the dial ("World (solo)", "Comms Dial") redraws that way, lifted to clear the labels, and
the tooltip above it moves up too; the slice labels are unchanged. Untick Show group labels → no title,
the font controls grayed out. Defaults → the gold 12-point title. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-31. Icon offset on the Icons tab (dial polish, 2026-10-21).** Dial → Wheel → no Icon offset row;
Dial → Icons → Icon offset is the first row. Icon offset 60 → the icons sit closer to the hub (DIAL-23);
`/qc set dial.iconOffset 0` → back on the ring radius. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-32. Dial icons up to 128 (dial polish, 2026-10-21).** Dial → Icons → Icon size: drag it to 128
→ no error, the icons drawn big (a game icon softer past 64, not broken; a catalog glyph scaled the
same); on Auto with five or more callouts at radius 100, fewer icons a page (about four) so they do not
overlap, the rest behind the page arrows; Ring radius 180 → more fit. Pad → Icons → Icon size still
stops at 40. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-33. A click outside closes the dial, in combat (dial polish, 2026-10-21).** Open the dial with
its key; left-click the world away from it → the dial closes and nothing else happens (no target
change, no movement); open it, right-click away from it → it closes, no camera turn; open it, click an
action-bar button → the dial closes and the action does not fire. In combat on a target dummy, the
same three → the same, no "action blocked" error. With test mode on (or Preview as…), the dial open
from the settings window: clicks on the settings window still work and do not close the dial. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-34. The page indicators' background and border (dial polish, 2026-10-21).** Open a paged ring
(Wheel → Wedges per ring 4, a group of eight callouts) over a busy scene (a city, spell effects) →
under the dial, between the arrow plates, the dots and the gold pill sit on a dark rounded strip,
round at both ends, and each dot and the pill has a thin dark outline. Dial → Paging → Page
indicator: Background padding 12 → the strip grows around the row; Indicator background → red → the
strip turns red; untick Show indicator background → the strip is gone and Indicator background and
Background padding gray out. Dot border 4 → thicker outlines; Dot border color → white → white
outlines; Dot border 0 → the slider reads None, no outlines, and Dot border color grays out.
Defaults → the strip and the 1-pixel outlines are back. `/qc diagnostics` → the dial's paging line ends
`back=true pad=4 border=1`. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-35. The Hub tab (dial polish, 2026-10-21).** Settings → Dial → the strip reads General, Groups,
Wheel, Slices, Hub, Paging, Slice labels, Group labels, Icons, Preview. Slices holds Background, Gap
and Highlight only; Hub holds the Hub heading (Hub style, sizes, colors) and the Pointer heading (Show
pointer, size, offset, color). A dial styled before this change keeps its hub style and pointer
settings (`/qc get dial.hub.style` and `/qc get dial.slice.pointerSize` read as before). Hub → Hub
size 60 → the dial's hub grows; Defaults → back to 40. Delete every dial → Hub says No dials yet,
as Slices does. Result: 2026-10-21, pass (the owner's run; client build not recorded).

## Share

**SHARE-1. Export a group.** Settings → Groups → New group `My keys`; on its Callouts tab, Add
callout `Kick` (`Kick on me {skull}`, Party) and `Lust` (`Lust now`, Smart group). Share → Export:
there are no callout checkboxes, only groups, pads and dials; tick `My keys` → the line under the boxes reads "The string will hold 2 callouts, 1 group."; Export → a
window opens with a string starting `!QC1!`, already selected; Ctrl+C copies it; Escape closes the
window. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**SHARE-2. Import it, twice.** Profiles → make a profile `Share test`. Share → Import: paste the
string and click Accept → "Ready to import: 2 callouts, 1 group."; Import → chat says "Imported 2
callouts, 1 group." and "An imported group is on no pad or dial yet: add it on the Groups tab of the
Pad or Dial page.", and Groups lists `My keys` with both callouts. Paste and import it
again → a second `My keys`, and the first one is untouched. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**SHARE-3. A string that tries a command.** Paste this on Import and click Accept:

```
!QC1!v4CVUjmmuuaybLPIufQdD2kdOwwqHbeZgPYatnrIz8pxLef7RJSVUuuvx6JsEIS4jcZ6rF6CotojB8U4q4TIMYp)xjmgxKcRkuLfQnEafsdOpZrHfgRTUEGrqG4xAb85kHw7WXVIDQ(9oRnW77qTugrTbstxMlzlNGFOHfhZeMdzwG9RN29xAg)rKx1kqemJbRWthE8K8SBtZVT2hr2GVdP3l)intwJGO)A6LQHm86RF)09)
```

→ "Ready to import: 1 callout, 1 group.", "Left out the callout 'Sneaky': its text starts with /." and
"1 reference to something the string does not carry was left out."; Import → the group `Smoke test`
holds `Kick` only, and nothing ran. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**SHARE-4. Damaged, foreign and newer strings.** On Import, Accept each: the SHARE-1 string with its
last ten characters deleted → "That string is damaged or cut short. Copy all of it again."; `hello`
→ "That is not a Quick Comms string: one starts with !QC1!."; and this →
"That string was made by a newer Quick Comms. Update the addon, then import it.":

```
!QC1!JXWsk9IYV0ckMRGsmLuYpVffyPzMC2oNFU5wStzNzEPKusLMxk5KAtjNyo5KFPLumxcvgRa(
```

Clicking Import after any of them prints the same line and adds nothing. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**SHARE-5. A pad and a dial travel unbound.** Bind Open Comms Dial 1 to G in Options → Keybindings. Share → Export: tick
the Comms Pad and the Comms Dial; Export, copy. Switch to `Share test`, import it → chat also says an
imported dial's key is the one WoW binds to its place in the dial list; the new pad sits in the
default place (not where yours is), and the new dial (the profile's first) opens on Open Comms Dial
1's key, G, since the key belongs to the place, not the dial. Switch back → G opens your dial as before. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**SHARE-6. A string that wrapped.** Paste a SHARE-1 string into a chat message or a forum post so it
breaks across lines, copy it back out with the line breaks, and paste that on Import → Accept reads
it as before. Result: 2026-10-21, pass (the owner's run; client build not recorded).

## Look

The Comms Pad's Pad header, Section header and Window tabs (one Window tab until 2026-10-20, the
Look tab before that, then Main window until it became Window, its visibility rows on General; the
checks keep their LOOK ids).

**LOOK-1. Section titles.** On a new pad the section titles are gold, 12 points and outlined. Pad →
Section header → Font: pick another face, Font size 14, Font flags None, untick Font shadow →
the section titles (In Party, Mythic+…) redraw that way, still
gold; the button labels do not change (they are the Buttons tab's). Tick Use class color → the titles take
your class color, and Font color's opacity still applies; untick it and set Font color to red → the
titles turn red. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**LOOK-2. Border and background.** Pad → Window → Border style: a LibSharedMedia border (Blizzard Tooltip, for one),
thickness 3, color red → the pad's edge changes; thickness 0 → no edge. Background: dark blue at 50%
opacity → the body changes; Use class color → your class color at 50%. The settings panel is closed
and locked in combat, so the in-combat write goes through the command line: in combat,
`/qc set pad.look.borderSize 3` → no error, the header shows "updates after combat", and the thicker
edge lands at combat end. Defaults → the Ka0s look again. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**LOOK-3. The header's look (2026-10-20).** On a new pad the header row (the top row, `World` in the
open world) is 24 pixels tall (it was 18) with gold 16-point outlined text, no background and no edge
(the owner's defaults). Pad → Pad header: Size → Header height 30 → the row grows and every
section moves down with it; Font size 20, another face, Font flags Thick outline → the situation text
redraws that way, and during an encounter with a Say callout on the pad the LOCKDOWN tag takes the
same face and size and stays red; the collapse button grows with it. Background dark red at 60% → a
band behind the header only; Border thickness 2, color white → an edge around the header only, with no
gray inner line; a LibSharedMedia border style draws that art. Use class color on each → your class
color. Defaults → the owner's header again, 24 tall. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**LOOK-4. The header's text sits on the titles' edge (2026-10-20).** Stand where the pad shows a section
title under the header (a party in the open world: `World` over `In Party`). The `W` of World and the
`I` of In Party start at the same distance from the pad's left edge (before, World sat a few pixels to
the right). Layout → Growth → Left and down, Right and up, Left and up in turn → still aligned in each;
Spacing 20 → still aligned. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**LOOK-5. Three window tabs (2026-10-20).** Pad → the strip reads General, Groups, Layout, Pad
header, Section header, Window, Buttons, Icons (no Main window or Chip tab). Pad header shows the headings Size,
Font, Background and Border, each once; Section header the same four; Window Background and
Border, with no font controls and no Visibility (General has it, under its own heading, above Unlock
pads and Delete pad). Change a value on each tab → only that part of the pad
changes (the header row, the section titles, the pad's body). Defaults on the page → all three tabs go
back to the owner's look. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**LOOK-6. The section header's band and height (2026-10-20).** Stand where the pad shows section titles
(a party in the open world). By default no band is drawn behind them. Pad → Section header →
Background dark blue at 60% → a band behind each title, spanning the pad's inside (a battleground set's
paired objectives: each band its own block's width, stopping at its neighbor); Border thickness 2,
color white → an edge around each band, the title text kept clear of it; Use class color on each →
your class color. Size → Section header height 30 → every title row grows to 30 pixels with its text
centered and the buttons move down with it; 0 → the automatic height again (it reads Automatic). A
right-click on a title still opens its group. Result: 2026-10-21, pass (the owner's run; client build not recorded).

## Buttons tab

**BUTTON-1. Size, color, border and font (2026-10-20).** On a new pad the buttons wear the owner's
defaults: a faint gray body (#3F3F3F at 25%), a faint 1-pixel light edge (#EAEAEA at 10%), small white
labels, 16-pixel icons. Pad → Buttons: Button width 160 → wider buttons; Button height 40 →
taller buttons, label and icon centered; Button height 0 → back to the automatic height; Button style Icon
only (Layout) → square buttons around the icons whatever the size says. Color → Background red at 50% →
every button's body; Use class color → your class color. Border thickness 2, color white → an edge around
every button, over the body, never hiding the icon or label; a LibSharedMedia border draws that art; 0 →
no edge. Font: another face, size 14, Outline, Font color yellow → the button labels only (the section
titles keep the Section header tab's font); a bigger font grows the automatic height. Defaults → the owner's
buttons again. In combat, `/qc set pad.button.width 150` → no error, "updates after combat", wider buttons at
combat end. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**BUTTON-2. The button glow (2026-10-20).** Buttons → Glow is off by default and Glow style is grayed out.
Tick Glow → every button glows around its whole edge in Pixel border, gold; Glow style Auto cast
sparkles, Button (rotating rays), Proc (flipbook) → each looks different; Glow color green → green;
Use class color → your class color. With the Icons tab's glow on too, both glows show (one around the
icon, one around the button) and turning either off leaves the other. A full pad glowing keeps the frame
rate where it was; untick Glow → every button glow stops. Result: 2026-10-21, pass (the owner's run; client build not recorded).

## Key bindings

**KEY-1. A dial's key is WoW's own binding (2026-10-20; set only there since the dial rework,
2026-10-21).** Options → Keybindings → AddOns → Ka0s Quick Comms → bind Open Comms Dial 1 to G → G
opens the dial. Bind it to F instead → F opens the dial and G no longer does. Clear it → no key, and
the dial opens on nothing. Make five dials → only Open Comms Dial 1 to 4 are listed, so the fifth
has no key. `/reload` → the key is still bound. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**KEY-2. Account-wide, unless Character Specific Keybindings (2026-10-20).** Bind G to Open Comms
Dial 1 on one character, log a second character → G opens its dial too. Options → Keybindings → tick
Character Specific Keybindings on the second character, bind Open Comms Dial 1 to H there → H opens it
here; log back to the first → still G there. Switch profile (Profiles page) → the key does not
change. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**KEY-3. Toggle Comms Pads (2026-10-20).** Options → Keybindings → Ka0s Quick Comms lists Toggle Comms
Pads after Open Comms Dial 1 to 4. Bind it to P. Press P once → every pad hides, nothing is printed to chat, and with
`/qc debug on` the log has exactly one `[Pads] hidden on this character until shown again` line (one press, one toggle); the minimap menu's Show
window is unticked. Press P → the pads are back. In combat, press P → nothing changes until combat
ends, then the pads toggle, with no Lua error. `/qc disable`, press P → the disabled line, as
`/qc toggle` prints. Result: 2026-10-21, pass (the owner's run; client build not recorded).

## Icons tab

**ICONS-1. Look.** Pad → Icons: Icon size reads 16 on a new pad (an icon-only button is 24
pixels square); Icon size 32 → the buttons grow taller around the bigger icons;
Zoom 0.1 → each icon's edge is cropped; Desaturate → gray; Icon opacity 50% → faint; Tint red → a
white glyph turns red and a colored glyph darker. Show border, thickness 2, color white → a square
edge over each icon. Dial → Icons: Show border → a round ring behind each wedge's icon; Icon size
20 → smaller icons, the wedges keep their size. Defaults on each page → the icons at their defaults again (16 on a pad, 32 on a dial). Result: 2026-10-21, pass (the owner's run; client build not recorded).

**ICONS-2. Glow styles.** Pad → Icons, glow off → Offset sits right under Glow color, its two
sliders grayed out, and no style's heading shows below it. Tick Glow → the Pixel border heading and
its knobs appear under Offset at once, the scroll where it was, and the offsets come alive; lines run
around every icon. Glow style Auto cast sparkles, Button (rotating rays) and Proc (flipbook) → each
looks different, and each swaps in only its own heading and knobs; under Button the offsets gray out.
Untick Glow → the style's heading goes, Offset stays. Dial → Icons → the same. With a full pad
glowing in Pixel border, the frame rate stays where it was. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**ICONS-3. Glow triggers.** Glow when On hover → only the icon under the mouse glows; in combat too,
with no error. After sending → a button glows for about a second and a half after its line is sent,
then stops; on a dial, send from a wedge and reopen the dial within a few seconds → that wedge glows
for about a second and a half from the open, then stops, and a later reopen shows no glow. In combat, `/qc set pad.icon.size 30` → no error, "updates after combat", the bigger
icons land at combat end. Result: 2026-10-21, pass (the owner's run; client build not recorded).

## Icons

**ICON-1. Choosing an icon.** Groups → a group of yours → Callouts → a row's edit glyph → Choose
icon… → double-click the skull → the icon beside Choose icon… is the skull (the popup has no Icon
box); Save → the row and the button show the skull. Groups → a group of yours → General → no Icon text
box, an "Icon" label over the icon and Choose icon… → Glyphs → double-click a glyph → the group's
wedge on the Comms Dial shows it, and the General tab's icon follows. With that group selected,
`/qc set group.icon 136012` still sets it. Click the red clear glyph beside Choose icon… → the
General tab's icon is the question mark, the wedge shows no icon, and the clear glyph goes idle; in
the popup, a callout with an icon → clear glyph → the icon is the question mark, Save → the row and
the button show no icon. A built-in set's General tab ("Dungeon (generic)") has the same Icon row and
Choose icon…: a glyph chosen there shows on its wedge. Result: 2026-10-21, pass (the owner's run; client build not recorded).

## Art

The dial's own round art (crisp dial art, 2026-10-21): `media/textures/dial-disc.tga` and the
twelve-step ring ladder `dial-ring-1..12.tga`, written by `tools/gen-dial-textures.py`, in place of the
64-segment rings and the stretched portrait mask.

**ART-1. Round edges at every size (2026-10-21).** Open a dial (its key). Dial → Hub → Hub style
Solid circle, Hollow ring, Target and Rimmed disc in turn, each at Hub size 24, 40 and 80, and for the
ring styles Line width 1 and 6 → the backdrop, its rim, the ring, the filled circle and Target's dot
are smooth round shapes with no flat facets or jagged steps, and the ring's line looks as thick all
the way round. Circle size 4 with Line width 6 → a small solid dot, not a stretched or missing ring.
On a paged ring (Wheel → wedges per ring 4 with more than four callouts in a group): Paging → Dot size
4 and 20 → the dots are round, the current page's pill has round ends at any Current page width, and
with Show indicator background on and Dot border 2 the strip behind the row and every border are
round-ended and smooth; the page arrows' round plates are smooth at Arrow size 12 and 48. Result:

## Shine

The shine overlay (2026-10-21): Shine look on the Pad page's Buttons tab and the Dial page's Slices
tab, drawn from `media/textures/shine-*.tga` (`tools/gen-shine-textures.py`).

**SHINE-1. Each look on a pad (2026-10-21).** On a new pad the buttons have no shine (Shine look
None; Shine strength and Shine tint grayed out, Bloom color A and B grayed out). Pad → Buttons →
Shine look Gloss cap, Glass orb, Frosted glass, Fluid glass, Bevel and Rim light in turn, each at the
Icons tab's Icon size 16, 24 and 40 → every button's icon takes the look, sized to the icon and never
past it; the padlock, the label, the send flash and the hover still read over it. Bloom color A and B
are enabled only under Fluid glass; set them to red and blue → its two blooms change color. Shine
strength 0 → no shine; 100 → the strongest. Shine tint yellow → the light turns yellow, the shade stays
dark; Use class color → your class color. Fluid glass, then Gloss cap, then None → no bloom or shine is
left behind. Layout → Button style Label only → no shine (no icon is drawn); a callout whose icon is cleared → its
button has no shine. Result:

**SHINE-2. Each look on a dial (2026-10-21).** Open a dial. Dial → Slices → Shine look each of the six
in turn, at Wheel → wedges per ring 4 and 8, Slice gap 0 and 8, and Ring radius 100 and 180 → every
slice takes the look inside its own edges, moving with its slice when the gap opens, and the icons and
labels sit over it, uncovered. Bevel's light stays at the top left on every slice (the light does not
turn with the slices). Gloss cap and Bevel are cut cleanly at each slice's edges at every slice place,
with no square corner, seam or bleed past the slice (the one client behavior not seen before this
check; on a fail the spec's fallback applies). Turn a page on a paged ring and switch 8 to 4 → the
slices no longer used show no shine. Hover a slice → its highlight still shows. Result:

**SHINE-3. A pad and a dial keep their own (2026-10-21).** Set the pad's Shine look to Glass orb and
the dial's to Rim light → each shows its own; set the pad's to None → the dial keeps Rim light, and the
reverse. `/reload` → both kept. `/qc diagnostics` → the pad's line reads `p1 button shine=none 85` and
the dial's slices line ends `shine=rim 85`. Result:

## Battlegrounds

**BG-1. Node winds.** In each node battleground you play (Arathi Basin, Eye of the Storm, Battle for
Gilneas, Deepwind Gorge, Isle of Conquest, Wintergrasp: the Fortress at the top, Broken Temple top
left, Sunken Ring top right, Westspark bottom left, Eastspark bottom right, the Towers at the bottom),
open the dial and click the battleground's set on the ring of groups → the nodes sit where they are on the map,
north up (Arathi Basin: Stables top left, Gold Mine top right, Farm bottom right, Lumber Mill bottom
left, Blacksmith, the middle node, at the top), and Deepwind Gorge shows five nodes (owner ruling R2).
One more wedge, drawn as the battleground itself, sits on the first wind no node takes and opens its
map-wide callouts; the nodes stay pinned around it.
Lumber Mill, then INC is two clicks from the set's ring. A node that points the wrong way is filed with this
check's ID and its battleground. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**BG-2. Battleground instance ids.** In each battleground you play: `/qc diagnostics` → the
`situation` section's instanceID is one its set lists (`defaults/BuiltIns_Battlegrounds.lua`), and
the pad and the dial show that set. Write each id into the "Battleground instance IDs seen" table of
`docs/brainstorm/go-no-go/round-4-build-checks.md`. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**BG-3. Alterac Valley's objectives.** In Alterac Valley, on a default pad: the Alterac Valley
section (its four map-wide callouts) is followed by 19 objective sections, two to a row, north to
south: Vanndar, DB North Bunker, Stormpike GY, Aid Station, DB South Bunker, Icewing Bunker,
Stonehearth GY, Balinda, Stonehearth Bunker, Snowfall GY, Iceblood GY, Galvangar, Iceblood Tower,
Tower Point, Frostwolf GY, West FW Tower, East FW Tower, Relief Hut, Drek'Thar (the last on a row
of its own). Each holds Attack and Defend; a long title stops short at its neighbor, and its buttons
stay on the grid's columns. The pad fits on screen; note its height. Click Iceblood Tower's Attack →
`/i Attack Iceblood Tower`. Right-click a title in the second
column → the Groups page opens on that objective. Open the dial and click Alterac Valley on the ring
of groups → its own callouts first, then the objectives a page at a time, the arrows under the dial
(or the Left and Right arrow keys) turning the page and the pill marking it; an objective's ring
holds Attack and Defend. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**BG-4. Isle of Conquest's bases.** In Isle of Conquest: the pad shows Our base and Enemy base side
by side after Refinery, each with Attack, Defend, INC and Clear; Our base's lines read "Fight at our
base", "Defend our base", "INC our base", "Our base is clear", Enemy base's "Attack the enemy base",
"Hold the enemy base", "INC at the enemy base", "The enemy base is clear", the same for either
faction. On the dial the five nodes stay on their winds, the Isle of Conquest wedge stays
where it was (NE), and Our base and Enemy base take two of the winds left over. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**BG-5. A flag map.** In Warsong Gulch or Twin Peaks: the pad shows the set's map-wide EFC callouts,
then Our flag, Enemy flag, Our FC and Midfield (Bridge in Twin Peaks), each its own section; on the
dial (click the set on the ring of groups) the set's ring has its own wedge on N and the four groups on the winds after it. Send
"INC flag room" → `INC our flag room`; "We have it" → `We have their flag`. The four groups take the
winds after the set's own wedge in the order they ship, not where they are on the map: which wind
Our flag or Enemy flag lands on is that order, not geography. The same holds for Ashran, Deephaul Ravine, Seething
Shore and Isle of Conquest's two bases. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**BG-6. A profile from before the objective groups.** On a profile saved before this build (or a
copy of one): log in → `/qc diagnostics` shows schema 7; Alterac Valley's set holds its 19 objectives
and opens into its ring on the dial, Isle of Conquest's holds Our base and Enemy base after its
nodes, and every callout you had edited still reads as you left it. Delete one objective, `/reload`
→ it stays deleted. A set you had deleted before the update is still gone. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**BG-7. The four node buttons (bg buttons).** On a reset profile, in Arathi Basin, Eye of the Storm,
Battle for Gilneas, Deepwind Gorge or Isle of Conquest: every node's section holds Attack (red crossed
swords), Defend (blue shield), INC (orange charge) and Clear (green check), as Wintergrasp's workshops
do; Lumber Mill's send "Attack Lumber Mill", "Defend Lumber Mill", "INC Lumber Mill", "Lumber Mill is
clear". Eye of the Storm's Flag reads Take flag, Defend flag, INC, Clear ("Take the flag", "The flag is
clear"). Each set's own map-wide callouts (Hold our bases, Zerg next…) are unchanged. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**BG-8. Silvershard Mines and Temple of Kotmogu (bg buttons).** In Silvershard Mines: after the set's
own Escort, Contest and Cart help, the pad shows Lava track, Water track and North track (Contest,
Escort, INC, Clear: "Contest their cart on the lava track", "Escort our cart on the lava track", "INC
on the lava track", "Clear on the lava track") and Switches (Flip switch, Hold switch, INC, Clear).
Check the track names against what players call them in your games; a name that reads wrong is filed
with this check's ID. In Temple of Kotmogu: after Orb heals, Kill orb and Go mid, the pad shows Orange
orb, Blue orb, Green orb and Purple orb, each drawn in its color (Take orb, Peel, Kill carrier, Heals:
"Take the blue orb", "Peel for our blue orb carrier", "Kill their blue orb carrier <target>", "Our
blue orb carrier needs heals") and Center (Go center, Hold center, INC, Clear). On the dial both open
on the set's ring, the groups on the winds left after the set's own wedge, in the order they ship.
Result: 2026-10-21, pass (the owner's run; client build not recorded).

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
client does; only then does that file's note say "confirmed". Result: 2026-10-21, pass (the owner's run; client build not recorded).

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
- **The pads' fonts** (the Pad header and Section header tabs', the Buttons tab's labels): the default face is LibSharedMedia's "Friz Quadrata TT", which LibSharedMedia
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
from the client, so this check needs a non-English client pass. Result: 2026-10-21, pass (the owner's run; client build not recorded).

## Pending sign-off

The owner ran every check above, except those listed here, on 2026-10-21 and reported all of them
passed (the client build was not recorded). A check added or rewritten after that date is listed here,
with its origin and why it is owed, until its pass is recorded:

| ID | Origin | Why it is owed |
|---|---|---|
| ART-1 | Crisp dial art (2026-10-21, shine overlay plan T1) | No client pass recorded yet: the generated disc and ring ladder replace the segmented rings and the portrait mask |
| SHINE-1..3 | The shine overlay (2026-10-21, plan T2-T5) | No client pass recorded yet; SHINE-2 holds the turned MaskTexture's cut, which the headless mock cannot see |
