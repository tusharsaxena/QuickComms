# Ka0s Quick Comms

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.0-purple)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-476%2F476_passing-green)

Quick Comms puts your usual group callouts one click or one keypress away. "Kick on me", "Lust
now", "Inc 2 Lumber Mill": you set them up once, and they sit on a Comms Pad or open from a
ping-wheel-style Comms Dial. The addon works out where you are, whether that's a Mythic+ key, a raid boss,
an arena or a battleground, and shows the callouts that fit. Every message goes out through a secure button, the
only kind of send Midnight still allows mid-pull, so it keeps working in keys and on bosses.

**Quick Comms is in development.** The Comms Pad works: it shows the built-in callouts for where you are (Mythic+, raid, arena, battlegrounds) and sends them through secure buttons, with a spam guard and a note when the game drops a message. You can now write your own callouts and groups, say when each group shows, arrange your pads and turn the built-in sets on, off or into editable copies. The Comms Dial comes in a later build. The full plan is in the [design spec](docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md).

## Usage

Enter a key, a raid, an arena or a battleground and the Comms Pad shows the callouts that fit; click one to send it. `/qc unlock` lets you drag the pad, `/qc lock` fixes it, and `/qc test` shows placeholder chips so you can place it anywhere. `/qc` opens the settings panel; the minimap button's right-click menu has Enabled, Locked and Test mode.

Settings → Callouts makes a callout; Groups puts callouts in a group and, on its When tab, says where it shows; Comms Pad arranges a pad. "Preview as…" on the Groups page (or `/qc preview`) shows the pads as they would look in a key, a raid, an arena or a battleground; hover a pad's header (or `/qc why`) to see why each group is there.

Once the dial lands, it opens on a key you choose, and you flick toward a callout and let go to
send it.

Everything is configured under **Settings → AddOns → Ka0s Quick Comms**, and `/qc help` (or
`/quickcomms help`) prints the full command list.

## How the callouts work

This is the design, in the order it is being built:

- Callouts are short lines of text. You group them, and one callout can belong to several groups.
- Each group has conditions for when it applies, such as "in a Mythic+ key" or "I'm the tank". The
  addon checks those against where you are and what you're doing, and shows the groups that match.
- Text is prepared ahead of time, out of combat, and loaded onto secure buttons. Pressing one sends
  the line to the right channel (say, yell, party, instance, raid or raid warning), even during a boss.
- After a press, every button dims for about a second. On a boss the game quietly drops anything
  sent faster than that, so a second press inside that window gets a note in chat if it never
  arrived.
- Built-in sets for Mythic+, raids, arenas and battlegrounds come switched on. They're read-only,
  but you can copy one and edit the copy.

## FAQ

| Question | Answer |
|---|---|
| Does it send anything on its own? | No. A callout is only ever sent when you press its button or its key. |
| Why secure buttons? | In Midnight an addon can't send chat by itself during a boss, a Mythic+ key or a PvP match. A button you press can, so that's the one way Quick Comms sends anything. |
| Can I use it now? | Yes, with the built-in callouts on the Comms Pad. Your own callouts and the dial come later. |

## Troubleshooting

| Symptom | Fix |
|---|---|
| `/qc` says the addon is disabled | Type `/qc enable`, or tick **Enable Ka0s Quick Comms** on the General page. |
| The minimap button is gone | Tick **Minimap button** on the General page. |
| The pad won't move | Type `/qc unlock` and drag the strip above it; it can't move in combat. |
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
| 0.1.0 | Unreleased | - The settings panel, the minimap button, the `/qc` command and the debug tools<br>- The Comms Pad with the built-in callouts, sent through secure buttons, with the spam guard, drop notes, test mode and the lock |
