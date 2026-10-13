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
| DIAL-1..n | Dial | The Comms Dial and its bindings (reserved, phase 4) |
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

## Dial

Reserved for the Comms Dial (phase 4): hold, flick and release in a boss, the two-stroke categories,
the battleground node dial.

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
