# Ka0s Quick Comms

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.0-purple)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-686%2F686_passing-green)

Quick Comms puts your usual group callouts one click or one keypress away. "Kick on me", "Lust
now", "INC 3 Lumber Mill": set them up once and they sit on a Comms Pad or open from a
ping-wheel-style Comms Dial. The addon works out where you are, whether that's a Mythic+ key, a raid
boss, an arena or a battleground, and shows the callouts that fit. Every message goes out through a
secure button, the only kind of send Midnight still allows mid-pull, so it keeps working in keys and
on bosses.

It ships with callout sets for Mythic+, raids, arenas and every battleground, all switched on.
You can write your own callouts, sort them into groups, say when each group shows, style the pad,
and share any of it with a friend as a string you copy and paste.

## Usage

Enter a key, a raid, an arena or a battleground and the Comms Pad shows the callouts that fit; click
one to send it. `/qc unlock` lets you drag the pad, `/qc lock` fixes it, and `/qc test` shows
placeholder chips so you can place it anywhere. The minimap button's right-click menu has Enabled,
Locked and Test mode.

The Comms Dial opens on a key. Pick one on Settings → Comms Dial → Binding (or in WoW's key bindings
menu), press it, click a group, then click a callout to send it. In a battleground the dial opens
straight on the map's nodes, each where it sits on the map, so INC 3 at the Lumber Mill is two
clicks. The key again, Escape or a right click closes it; the number keys 1 to 8 pick a wedge.

Settings → Callouts makes a callout and gives it an icon; Groups puts callouts in a group and, on its
When tab, says where it shows; Comms Pad arranges a pad, and its Look tab sets the font, the border
and the background, each with a Use class color box. "Preview as…" (or `/qc preview`) shows the pads
and the dial as they would look somewhere else, and hovering a pad's header or the dial's middle (or
`/qc why`) tells you why each group is there.

To share, open Settings → Share → Export, tick what you want to send and click Export, then copy the
string with Ctrl+C. To take one in, paste it on the Import tab and click Accept: Quick Comms lists
what's in it and anything it left out, and nothing changes until you click Import. Everything
arrives as a new copy, and a shared pad or dial comes without a key or a screen position.

Everything is configured under **Settings → AddOns → Ka0s Quick Comms**, and `/qc help` (or
`/quickcomms help`) prints the full command list.

## How the callouts work

- Callouts are short lines of text. You put them in groups, and one callout can be in several.
- Each group has conditions for when it applies, such as "in a Mythic+ key" or "I'm the tank". The
  addon checks those against where you are and shows the groups that match, in the order you set.
- Text is prepared ahead of time, out of combat, and loaded onto secure buttons. Pressing one sends
  the line to the right channel (say, yell, party, instance, raid or raid warning), even during a boss.
- After a press, every button dims for about a second. On a boss the game quietly drops anything
  sent faster than that, so if a line never arrives you get a note in chat.
- The built-in sets are read-only, but you can copy one and edit the copy.
- A shared string is checked before anything is added. A callout whose text starts with a slash
  command is left out, and the text is checked again every time a line is prepared.

## FAQ

| Question | Answer |
|---|---|
| Does it send anything on its own? | No. A callout is only ever sent when you press its button or its key. |
| Why secure buttons? | In Midnight an addon can't send chat by itself during a boss, a Mythic+ key or a PvP match. A button you press can, so that's the one way Quick Comms sends anything. |
| Can a shared string run a command? | No. Callout text is always chat text. A shared callout that starts with a slash is left out, and nothing in a string is ever run. |
| Will importing overwrite my callouts? | No. Everything in a string arrives as a new copy beside what you have. |

## Troubleshooting

| Symptom | Fix |
|---|---|
| `/qc` says the addon is disabled | Type `/qc enable`, or tick **Enable Ka0s Quick Comms** on the General page. |
| The minimap button is gone | Tick **Minimap button** on the General page. |
| The pad won't move | Type `/qc unlock` and drag the strip above it; it can't move in combat. |
| The dial's key does nothing | Check Settings → Comms Dial → Binding. The dial opens only where at least one of its groups is active. |
| An imported dial won't open | Shared dials arrive without a key. Give it one on Settings → Comms Dial → Binding. |
| The import says the string is damaged | It was cut short when it was copied. Ask for it again and copy all of it; line breaks and spaces in it are fine. |
| The import says the string is from a newer Quick Comms | Update the addon, then import it again. |
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
| 0.1.0 | Unreleased | - The Comms Pad and the Comms Dial, with built-in callouts for Mythic+, raids, arenas and every battleground, sent through secure buttons<br>- Your own callouts and groups, with conditions for when each group shows, Preview as… and Why is this showing?<br>- The spam guard, drop notes, test mode and the lock<br>- The pad's font, border and background, with class colors<br>- Sharing callouts, groups, pads and dials as a string<br>- The settings panel, the minimap button, the `/qc` command and the debug tools |
