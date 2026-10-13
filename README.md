# Ka0s Quick Comms

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.0-purple)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-249%2F249_passing-green)

Quick Comms puts your usual group callouts one click or one keypress away. "Kick on me", "Lust
now", "Inc 2 Lumber Mill": you set them up once, and they sit on a Comms Pad or open from a
ping-wheel-style Comms Dial. The addon works out where you are, whether that's a Mythic+ key, a raid boss,
an arena or a battleground, and shows the callouts that fit. Every message goes out through a secure button, the
only kind of send Midnight still allows mid-pull, so it keeps working in keys and on bosses.

**Quick Comms is in development.** Version 0.1.0 is the shell for now: the settings panel, the
minimap button, the `/qc` command and the debug tools. The pad, the dial and the built-in callout
sets come in later builds. The full plan is in the
[design spec](docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md), and this page will catch
up with it as each part lands.

## Usage

There is not much to use yet. Type `/qc` to open the settings panel, where the General page has the
switch that turns the addon on and off and the box for the minimap button. Left-click the minimap
button to get the same panel; right-click it for a small menu that can switch the addon off and on.

Once the pad lands it will be a small strip of buttons you can place anywhere, showing the callouts
for whatever you're doing. The dial opens on a key you choose, and you flick toward a callout and
let go to send it.

Everything is configured under **Settings → AddOns → Ka0s Quick Comms**, and `/qc help` (or
`/quickcomms help`) prints the full command list.

## How the callouts work

This is the design, in the order it is being built:

- Callouts are short lines of text. You group them, and one callout can belong to several groups.
- Each group has conditions for when it applies, such as "in a Mythic+ key" or "I'm the tank". The
  addon checks those against where you are and what you're doing, and shows the groups that match.
- Text is prepared ahead of time, out of combat, and loaded onto secure buttons. Pressing one sends
  the line to the right channel (say, yell, party, instance, raid or raid warning), even during a boss.
- A spam guard of about a second stops a double press from sending twice. On a boss the game quietly
  drops anything sent faster than that anyway, so you lose nothing.
- Built-in sets for Mythic+, raids, arenas and battlegrounds come switched on. They're read-only,
  but you can copy one and edit the copy.

## FAQ

| Question | Answer |
|---|---|
| Does it send anything on its own? | No. A callout is only ever sent when you press its button or its key. |
| Why secure buttons? | In Midnight an addon can't send chat by itself during a boss, a Mythic+ key or a PvP match. A button you press can, so that's the one way Quick Comms sends anything. |
| Can I use it now? | Not for callouts yet. 0.1.0 is the frame the pad and the dial plug into. |

## Troubleshooting

| Symptom | Fix |
|---|---|
| `/qc` says the addon is disabled | Type `/qc enable`, or tick **Enable Ka0s Quick Comms** on the General page. |
| The minimap button is gone | Tick **Minimap button** on the General page. |
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
| 0.1.0 | Unreleased | - The settings panel, the minimap button, the `/qc` command and the debug tools |
