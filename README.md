# Ka0s Quick Comms

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.5-purple)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-1157%2F1157_passing-green)

Quick Comms puts your usual group callouts one click or one keypress away. "Kick on me", "Lust
now", "INC Lumber Mill": set them up once and they sit on a Comms Pad or open from a
ping-wheel-style Comms Dial. The addon works out where you are, whether that's a Mythic+ key, a raid
boss, an arena or a battleground, and shows the callouts that fit. Every message goes out through a
secure button, the only kind of send Midnight still allows mid-pull, so it keeps working in keys and
on bosses.

It ships with callout sets for Mythic+, raids, arenas, every battleground, the open world when
you play solo and any group you are in (In Group: Hello, tyff, GLHF, ggty and the like), all switched
on, each callout and group with an icon in its own color. A battleground's set holds a group per
objective: every base-capture node (Attack, Defend, INC and Clear), every Alterac Valley general,
captain, bunker, tower and graveyard (Attack and Defend each), both bases on Isle of Conquest, Silvershard
Mines' tracks, Temple of Kotmogu's orbs, and the flags, workshops, events, carts or azerite of the
rest, worded the same for either faction.
You can write your own callouts, sort them into groups, say when each group shows, and style the pad.

## Usage

Enter a key, a raid, an arena or a battleground (or head out into the open world on your own) and the
Comms Pad shows the callouts that fit; click one to send it. `/qc unlock` lets you drag the pad, `/qc lock` fixes it, `/qc test` shows
placeholder buttons so you can place it anywhere (the strip above the pad, as wide as the pad, then reads TEST MODE after
its name, as it reads PREVIEW during a preview), and `/qc toggle` (or the Toggle Comms Pads key,
bound in WoW's Options → Keybindings → Ka0s Quick Comms, or on General → Keybindings in this addon's
settings) hides every pad until you toggle it back;
each character remembers it through a reload or a logout. The minimap button's right-click menu has Enabled, Locked, Test mode and Show window.

The Comms Dial opens on a key: bind Open Comms Dial in WoW's Options → Keybindings → Ka0s Quick
Comms, or on General → Keybindings in this addon's settings, which lists the same keys (Toggle Comms
Pads first, then Open Comms Dial 1 to 4, each with one key button and Clear; a second key set in
WoW's menu shows on the button as `<key> +1`, named in its tooltip). A key set in one shows in the other. It is
shared by all your characters unless you tick Character Specific Keybindings in WoW's Keybindings.
Press it: with one group active the dial opens straight on that group's callouts; with several it
shows the groups first, so click one, then click a callout to send it. In a battleground the map's
set shows its nodes, each where it sits on the map. A ring with more callouts than wedges is paged:
the arrows under the dial (or the Left and Right arrow keys, or the mouse wheel) turn the pages, and
a gold pill under the dial marks the page you are on. Alterac Valley lists its objectives A to Z that way; its
pad sets them two to a row. A right click on a slice goes back up one ring (on the first ring it does
nothing). The key again, Escape, a right click on the middle button or a click anywhere outside the
dial closes it, and the next press opens it where you left it: the same group and page. The number
keys 1 to 8 pick a wedge. Slices are laid out from the top (N), going
clockwise and evenly spaced: one is the whole dial, two are top and bottom, three are thirds. The slice the mouse points into lights whole, anywhere outside the middle button, a click
anywhere in it sends it, and its tooltip shows outside the dial. On Settings → Dial, the Layout tab sets
the slices per ring (Auto spreads them evenly, up to 12, and pages sooner when big icons would not
fit), the ring's radius, the gap between the slices and where the dial opens; the Slices tab colors
the slices and the lit slice and gives the slices an optional shine (Gloss cap, Gloss fade, Glass orb, Frosted glass,
Fluid glass, Bevel or Rim light, with its strength and tint); the Hub tab styles the middle button (a solid circle, a hollow ring, a target or a rimmed disc, with
its size and colors) and sets the pointer (its size, distance and color, or hides it); the Paging
tab sizes, spaces and colors the page arrows and the pill and dots; the Labels tab shows or hides
the slices' names (their distance from the middle, font, size, outline, color and shadow) and the
ring's title above the dial, and sets which side of the dial the tooltip shows on; and the Icons tab
sets the icons' size, their distance from the middle and their look, up to 128 pixels.

Settings → Groups makes a group and, on its Callouts tab, its callouts: Add callout opens a small
editor for the name, text, channel and icon (Save keeps it, Cancel drops it). The text takes tokens in
braces, such as `{target}`, `{me}`, `{key}` and `{coordinates}` (your map position, `45.2, 61.8`, read as
you press, so `{target} @ {coordinates}` tells others where a rare is); the "i" beside Text lists them. Choose icon… opens
a browser with the raid markers, every icon the macro icon picker has and the LibKa0s glyphs, which
you can color and search (the game's own icons by texture id; the tab points to Wowhead for a name).
Reuse
callout copies a callout from any of your other groups into this one, and each row has an
edit and a remove button. A group's Parent group setting puts it inside another group: it then
shows wherever that group does, in a section (or a dial ring) of its own, while its conditions
match: its parent's, while Inherit when conditions is ticked (the default), else its own. The What it sends tab lists each callout beside what it would send where you are. The group's When tab says where it shows, one condition per drawer (click a condition to open it), with Inherit when conditions at its top; the Pad page arranges a pad: its General tab names it and sets when it shows (visibility and fade), its Window tab the pad's border and background, its Header tab styles the header row
(the one that names where you are: "Quick Comms: World"), its Section titles tab the section titles (their height, font and a
band behind each), and its Buttons tab the
buttons themselves (size, font, background, border, an optional glow and an optional shine over the whole button, chosen
apart from the dial's), each color with a Use class color
box. "Preview as…" (or `/qc preview`) shows the pads
and the dial as they would look somewhere else. `/qc preview` on its own previews where you are, in
a small window whose dropdown switches the situation; End preview (or Escape, or its close mark)
ends it. A preview started from the settings opens the same window and outlives the settings, and
the window keeps the place you drag it to. In a preview or in test mode, clicking a pad button or a
dial slice sends nothing, and the dial stays open for the next one: it prints, to you alone, what it would have sent (`[QC] /p Hello world!`,
the channel the previewed situation picks and the text with its tokens filled, `<target>` and the
like standing in for a value you have not got right now), or why it would send nothing, or that a
test button is a placeholder. Hovering a pad's header or the dial's middle (or
`/qc why`) tells you why each group is there. While the Groups page is open, every pad and dial shows
only the group you are editing, sending nothing: a click prints `[QC] /p <text>`, the line it would
have sent, and the preview window comes up titled with the group and showing the situation it is
previewed in (the group's own: Alterac Valley for Alterac Valley, Current for one with no content).
The window is grayed out there, since the Groups page drives it: pick another group to change it,
or untick Preview while editing, beside the Group picker, to keep the pads live. Right-click a
group's title on a pad to open it on the Groups page; the page stays on the tab you last used.

Everything is configured under **Settings → AddOns → Ka0s Quick Comms**, and `/qc help` (or
`/quickcomms help`) prints the full command list.

## How the callouts work

- Callouts are short lines of text, and each one lives in a group. To use a callout in a second
  group, reuse it there: that makes a copy you can change on its own.
- Each group has conditions for when it applies, such as "in a Mythic+ key" or "I'm the tank". The
  addon checks those against where you are and shows the groups that match, in the order you set.
- Text is prepared ahead of time, out of combat, and loaded onto secure buttons. Pressing one sends
  the line to the right channel (say, yell, party, instance, raid, raid warning, or General, /1, which
  falls back to say where you have not joined it), even during a boss.
- After a press, every button dims for about a second. On a boss the game quietly drops anything
  sent faster than that, so if a line never arrives you get a note in chat.
- The built-in sets arrive as ordinary groups: change, rename or delete them like your own. Restore
  built-in groups (Settings → Groups → General) brings back any built-in group or callout you deleted.
- A callout whose text starts with a slash command is refused, and the text is checked again every
  time a line is prepared.

## FAQ

| Question | Answer |
|---|---|
| Does it send anything on its own? | No. A callout is only ever sent when you press its button or its key. |
| Why secure buttons? | In Midnight an addon can't send chat by itself during a boss, a Mythic+ key or a PvP match. A button you press can, so that's the one way Quick Comms sends anything. |
| Does it work with EllesmereUI? | Yes. With EllesmereUI's Blizzard skins on (and Quick Comms on in its Third-Party Addons list), the callout editor takes the same look as your settings window. Turn it off there, then reload. |

## Troubleshooting

| Symptom | Fix |
|---|---|
| `/qc` says the addon is disabled | Type `/qc enable`, or tick **Enable Ka0s Quick Comms** on the General page. |
| The minimap button is gone | Tick **Minimap button** on the General page. |
| The pad won't move | Type `/qc unlock` and drag the strip above it; it can't move in combat. |
| The dial's key does nothing | Check Open Comms Dial in WoW's Options → Keybindings → Ka0s Quick Comms, or on General → Keybindings in this addon's settings. The dial opens only where at least one of its groups is active. |
| A message didn't arrive and chat says it may have been dropped | The game drops messages sent too close together on a boss. Wait for the buttons to brighten before pressing again. |
| Something looks wrong and I want to report it | Follow [Reporting a bug](#reporting-a-bug) below. |

## Reporting a bug

- Type `/qc debug on` and reproduce the bug.
- Type `/qc diagnostics`.
- If the debug window isn't open, open it with `/qc debug`. Press **Copy**, copy the entire output, and include it with your bug report.

The report is added after the debug trace in the same window, so one copy carries both.

## Issues and feature requests

Bugs and ideas are tracked in the
[GitHub issues](https://github.com/tusharsaxena/QuickComms/issues). Please file them there rather
than in comments, so nothing gets lost.

## Version History

| Version | Date | Highlights |
|---|---|---|
| 0.1.0 | Unreleased | - The Comms Pad and the Comms Dial, with built-in callouts for Mythic+, raids, arenas, every battleground and the solo open world, sent through secure buttons<br>- Battleground sets with a group per objective: Alterac Valley's generals, captains, bunkers, towers and graveyards, Isle of Conquest's bases, and the objectives of Warsong Gulch, Twin Peaks, Wintergrasp, Ashran, Deephaul Ravine and Seething Shore<br>- Your own callouts and groups (the built-in sets among them, as groups you can edit, and groups inside groups), with conditions for when each group shows, Preview as…, a preview of the group you are editing and Why is this showing?<br>- A small preview window, opened by `/qc preview` or the Preview as… row, to switch the previewed situation or end the preview<br>- In a preview or test mode, a click on a button or a slice prints what it would have sent, and sends nothing; the dial stays open<br>- The preview window over the group you are editing, showing the situation it is previewed in<br>- A `{coordinates}` token, your map position as you press<br>- The General channel (/1), falling back to say where you have not joined it; the solo open-world callouts use it<br>- The spam guard, drop notes, test mode and the lock<br>- The pad's font, border and background, with class colors<br>- An optional shine on the pad's buttons and the dial's slices (seven looks), and the dial's own round art<br>- The settings panel, the minimap button, the `/qc` command and the debug tools<br>- Your keys on the General page's Keybindings tab, the same ones WoW's Options → Keybindings → Ka0s Quick Comms shows<br>- Settings laid out by subject: Behavior under two headings, the Groups band on one row with Inherit when conditions on the When tab, the Pad tabs from the window inwards, and the Dial's Layout, Labels and Ring map tabs |

## Credits

The glyphs in the icon browser come from three icon sets, each shipped with its license beside its art:

- **Open Iconic**, by Waybury, MIT license (<https://github.com/iconic/open-iconic>).
- **Phosphor** (the Fill weight), by Phosphor Icons, MIT license (<https://phosphoricons.com>).
- **Game-icons.net**, CC BY 3.0 (<https://game-icons.net>), by Andy Meneely, Aussiesim, Carl Olsen,
  Caro Asercion, Cathelineau, Catsu, DarkZaitzev, Delapouite, Faithtoken, Felbrigg, GeneralAce135,
  Guard13007, HeavenlyDog, Irongamer, John Colburn, John Redman, Kier Heyl, Lorc, Lord Berandas,
  Lucas, Pepijn Poolman, Pierre Leducq, PriorBlue, Quoting, Rihlsul, Sbed, SeregaCthtuf, Skoll,
  Sparker, SpencerDub, Starseeker, Viscious Speed, Willdabeast, Zajkonur and Zeromancer. The marks
  were rasterized to 64×64, their background square removed and recolored white so the game can tint
  them; `AUTHORS.txt` names each mark's author, and the icon browser's tooltip does too.
