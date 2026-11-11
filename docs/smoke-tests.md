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
| PANEL-1..4 | Settings panel | Landing page, General → Master controls, the Defaults button, no Sim mode row |
| PROFILE-1..2 | Profiles | The Profiles page and the `profile` verb |
| STATE-1..6 | State | Enable/disable, the launcher menu, `/qc toggle`, the pads' hidden state across /reload, a new profile's prebuilts |
| COMBAT-1 | Combat | The settings panel in combat |
| DIAG-1..2 | Diagnostics | The debug console, the report, perf |
| DEGRADED-1..2 | Degraded | The install with LibKa0s missing, and its help rows |
| SEND-1..7 | Send | Secure sends in keys and on bosses, the spam guard, General (/1) with its Say fallback, the lockdown lift after an encounter or a key |
| TOKEN-1 | Tokens | `{coordinates}`: your map position, read at the press, in a preview echo and in combat |
| PAD-1..17 | Pad | The Comms Pad, its growth and button width, the Solo and In Group sets and the built-ins' colors, the header click and icon only's width, the header's Quick Comms: text |
| EDIT-1..34 | Editors | The Pad and Dial page names; the Groups (with the callout popup, its look on the skin and its token glyph, the icon browser, its search, its glyph sets and glyph colors, the Callouts rows, Reuse and the glyph lists, the built-in sets as ordinary groups and Restore, nested groups and Inherit when conditions, the Preview table, the When drawers, Preview while editing, a pad title's right-click, a preview click's echo) and Comms Pad pages, Preview as…, Why is this showing?, an older profile's conversion |
| PREVIEW-1..12 | Preview window | The Preview as selector window: every entry point, the dropdown, End preview, close and Escape, combat, test mode and the stand-down, Alt+Z, the saved position, bare /qc preview and list; every preview drawn as live; a preview or test click prints what it would send; a preview dial staying open on a pick |
| DIAL-1..43 | Dial | The Comms Dial (Relaxed), its key and Bindings.xml, the battleground node dial, the lone-group open and the group ring, page arrows and the page row, Auto wedges, the ring radius, the Slice labels tab, the slices and the slice lit by direction, the Slices tab, the pointer, the tooltip outside the dial, the hub over the slices, the pointer, label and icon offsets, the Paging tab; the dial polish: the border gone, the slice gap, placement from W, a slice clicked to the hub in combat, the hub styles, the Group labels tab, Icon offset on Icons, 128-pixel icons, a click outside closing the dial in combat, the page indicators' background and border, the Hub tab; automatic icon offset and size; the 120 radius and 48-pixel icons by default; a right click back a ring; opening where it was closed; slices from N |
| LAYOUT-1..6 | Settings layout | Item 020: the General page's Behavior headings and Defaults tooltip; the Groups band on one row, General's order, Inherit on When, What it sends; the Pad strip outside in and its relabels; the Dial strip (Layout, Labels, Ring map) and its headings; no setting lost or changed, through a /reload |
| LAYER-1..9 | Frame layering | Item 030: a pad button's and a dial wedge's borders, glows, label, padlock and veils in order; the drag strip over a faded pad; the windows, modals and popups still stacked as before; #14: the pads and the dial over other addons' windows, QuickComms' own stack, a click outside the dial, the skin picker over a pad |
| KEY-1..6 | Key bindings | A dial's key as WoW's own binding in Options → Keybindings, Character Specific Keybindings, Toggle Comms Pads; item 015: the Ka0s Quick Comms section of its own, the General → Keybindings tab in sync both ways, its capture and combat refusal |
| LOOK-1..7 | Window, Header, Section titles (Pad header and Section header before item 020) | The Comms Pad's three window tabs: the section titles' font, the pad's border and background, the header's look, size and alignment, the tab strip and headings, the section header's band and height; the pad's window repainting only when its look moves |
| BUTTON-1..2 | Buttons tab | The buttons' size, color, border and font; the button glow |
| ICONS-1..6 | Icons tab | The buttons' and wedges' icon look, border and glow triggers; the glows through LibKa0s-Glow-1.0; no native icon edge on the HUD |
| ICON-1..5 | Icons | Choosing an icon, for a callout and for a group; the LibKa0s v1.75.0 re-vendor: the icon browser's three sets and the library-drawn marks; the popup and the browser over the preview dial; test mode's numbered groups and the default icons |
| ART-1..2 | Art | The dial's round art: the hub's styles, the dots and pill, the indicator background, the borders and the arrow plates; every texture loading from its folder |
| SHINE-1..4 | Shine | The shine overlay: each look on a pad and on a dial, and a pad and a dial keeping their own |
| BG-1..9 | Battlegrounds | Node rings on the dial, one slice per node; the faction and location colors; the battleground instance ids; the objective groups (Alterac Valley, Isle of Conquest's bases, a flag map) and their migration; the four node buttons; Silvershard Mines' and Temple of Kotmogu's groups |
| IDS-1 | Instance ids | The Midnight dungeons and raids |
| LOC-1 | [Non-English client](#non-english-client) | What a deDE or frFR client changes |
| ANIM-1..20 | [Animations](#animations) | The dial's open and close, every style by family, Slide's Direction, a send, combat, the stand-down, Alt-Z, a pad having none, text that neither shimmers nor truncates, the old defaults moved |
| PLOOK-1..11 | [The pad's look per skin](#the-pads-look-per-skin) | The pad in each skin: edges, buttons and shine (the owner's findings of 2026-11-01) |
| FSKIN-1..13 | [The full skin](#the-full-skin) | Every pad and dial color, the shadow, texture and shine on the skin, Ka0s Default unmoved, the companions off, an existing profile, meaning colors, the ghost, a stored pick of the deleted Friz |
| ROLE-1..3 | [Role and character](#role-and-character) | The Role row on General → Behavior and its Automatic phrase, the group's assigned role winning over the spec, the Character and Specialization rows of the When editor (Retail; FOREVER-18 to FOREVER-21 re-run them on Forever) |
| FOREVER-1..26 | [WoW Forever](#wow-forever) | The core re-run on a live WoW Forever client: the AddOns list, a clean load, the settings panel and the launcher, the default skin per client, a pad's secure send in the open world, a dial's open, send and animations (the strata guard), a lifted confirm, the key bindings, profiles across a full restart, diagnostics, enable and disable; the content kinds and drawers the When editor offers, Preview as..., the sets a fresh profile seeds, the token help, Forever's place ids against the client's own names and a profile copied from Retail; Automatic role from the talent tree, the Role pick, the long character name and your own lines; `/qc probe` on both clients and `probe clear`; the Dungeon set matching dungeons alone; `/qc probe ids`, the no-travel sweep of the client's map, dungeon finder and battleground names; the combined-actions core re-run |
| EMOTE-1..10 | [Emotes](#emotes) | Retail, then Forever: a custom emote callout (`/e`) and its lock, a game emote callout, the emote picker's order and voice marks, preview, throttle and an unknown token, a game emote during an encounter, the Emotes set in the open world and an existing profile gaining it once, the shipped callouts that emote with their line and the two Heal me callouts, and an existing profile gaining them (step 20) |
| ACTION-1..8 | [Combined actions](#combined-actions) | Retail, then Forever: one press that sends a line, an emote, a ping and a marker (#16), in combat, with no target, the 255-byte macro cap, Say and an emote outdoors, a boss encounter, a locked Line beside a marker, a legacy game-emote callout |
| THANK-1..12 | [Auto-thank](#auto-thank) | Retail, then Forever: a stranger's buff toasted and thanked (#19), whether the caster reads, the whisper and the emote at a cross-realm caster, a buff mid-fight, a burst throttled, raid buffs only, where it stays quiet, combat with a toast up, a right-click, the spam guard, the mute modes |
| PING-1..5 | [Pings](#pings) | Retail, then Forever: a callout's ping on the target (#17), solo and grouped, in combat, Forever's server delivery, an encounter lockdown, pings off and on cooldown |
| MARK-1..7 | [Raid markers](#raid-markers) | Retail, then Forever: a callout's raid target marker on the target (#18), solo, in a party and in a raid with and without assist, a second press, no target and an unmarkable one, Forever's `/tm`, marking in combat and during an encounter |
| SKIN-1..31 | [Skins](#skins) | The skinning rollout: the one-time reset under Ka0s Default, a new pad, dial or profile on the skin, Ka0s Default elsewhere unchanged, the Skin tab, every skin on the pads and dials, the *Use the skin's ...* boxes, the Preview as window, the callout popup and the icon browser, the settings pages, the tool windows, the Font and texture overrides, Ignore fonts, EllesmereUI on and off and the reload back, profiles and combat, the first-run skin picker (its eye, Apply, close, gear, the switch and a profile event, one picker across Ka0s addons), the CLI and the degraded install; LibKa0s v1.82.0: the Font outline, From skin font flags, `/qc skin`, the HUD size scale and the windows' width parity; the skin on the only media picker; no line under any window title |

## Before you start

- **Clients (clients-§6).** The addon serves Retail and WoW Forever. Every check outside the
  [WoW Forever](#wow-forever) section runs on **Retail**, where its recorded result was taken. That
  section names the checks to run on a live **Forever** client.
- Install the addon folder as `Interface\AddOns\QuickComms` and `/reload`.
- Keep the debug console closed unless a check opens it; `/qc debug` opens it.

## Install

**INSTALL-1. Loads clean.** `/reload` with only Quick Comms enabled → no Lua error, no chat line at
login, the addon listed in the AddOns list with the gold speech-bubble logo. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**INSTALL-2. Minimap button and broker.** Look at the minimap → the speech-bubble button is there;
hover it → the tooltip reads `Ka0s Quick Comms  v1.0.0`, `Enabled: Yes`, then the two click hints. A
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
General visibility, Master scale beside Master opacity, Lock frame beside Debug console, Minimap button
beside Test mode, then Preview as alone on its own line, then Reset position beside Reset all
settings. Ticking Debug console opens the
console; unticking Minimap button hides the button at once. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PANEL-3. Defaults and Reset all.** Hide the minimap button, untick Enable, press the header's
Defaults button and accept → Enable is ticked again and the minimap button stays hidden. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PANEL-4. No Sim mode row at LibKa0s compose minor 19 (R6-RV2, smoke round 6).** After a full client
restart, General → the `Master controls` tab → the rows are exactly PANEL-2's, in PANEL-2's pairs, and
there is no Sim mode checkbox: Quick Comms has no simulation, so it passes no sim hooks. No Lua error
from `OptionsCompose.lua`. Fail: a Sim mode row, a row out of its PANEL-2 pair, or a Lua error.
Result:

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

**STATE-5. A perf capture refuses by its own line (2026-10-22).** Start a perf capture from `/qc
perf`'s step panel, then press the Toggle Comms Pads key, type `/qc toggle` and `/qc test` → each
prints `Not available during a performance capture.` once and nothing toggles. Finish the capture →
the key toggles the pads again. Then `/qc disable` and press the Toggle Comms Pads key → the disabled
line, `Ka0s Quick Comms is disabled — enable it with /qc enable` (unchanged, as KEY-3). `/qc enable`
to finish. **Owed**: the headless gate holds the latch directly and cannot drive a real capture.
Result: 2026-10-23, pass (the owner's run; client build not recorded).

**STATE-6. A new profile's prebuilts (2026-10-23, run item QF-05).** Profiles page → create a new
profile and switch to it. Groups page: Dungeon > Chain pull has yellow chains (`fff468`); In Group
reads Hello (a sky-blue hand, `3fc7eb`, sending `Hello!`), At Stone 2nd (a purple tombstone, Smart
group, sending `At stone, WM off.`), then Summon, Buffs please, Healthstone, tyff, brb, Ready, GLHF,
ggty, ggnt; every Solo callout's channel reads General (/1; Say when not joined); Rare spotted reads
`Rare spotted: {target} @ {coordinates}`, Elite help `Can anyone help with this elite? {target} @
{coordinates}`, World boss `World boss up: {target} @ {coordinates}`, Event here `World event
starting @ {coordinates}, come join`. Switch back to the old profile → its callouts are as you left
them (no migration). Delete the test profile. Result: 2026-10-24, pass (the owner's run; client build not recorded).

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

**DEGRADED-2. Help without LibKa0s (2026-10-25, audit QC-17).** With `libs\LibKa0s` renamed as in
DEGRADED-1, `/qc help` → each row reads `/qc <verb>  <description>`: the verb, two spaces, then its
description, with no em dash between them and no color. Restore the folder after.
Result: 2026-10-25, pass (the owner's run; client build not recorded).

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

**SEND-6. General (/1) and its Say fallback (2026-10-23, run item QF-04; rewritten 2026-10-25, F-007).**
Out of combat in the open world, make a callout on the channel "General (/1; Say when not joined)" in
a group on your pad; its Groups row reads `General` in channel 1's color. Hover its button →
`Channel: General` in the same color. Click it → the line appears in General
(`[1. General - <zone>]`), with no "interface action blocked" and no drop note. This is also the
in-client check that `C_ChatInfo.GetGeneralChannelLocalID()` answers 1 for a normal General.
`/reload`, and click it again as soon as the pad shows → `/1` again (the automatic join after login
reached the snapshot). Take a portal or flight to another zone and click it right after the loading
screen → still `/1`, in the new zone's General. Type `/leave 1`, click it → the line goes to Say.
`/join General` → confirm it came back as `/1`, click → back in General (if the client rejoins it at
another number, the callout stays on Say: that is the expected fallback, F-007). With General left
again, `/join <a custom name>` so the custom channel takes `/1` → a General callout goes to Say, not
to the custom channel. With a press pending, type a line in `/2` (Trade, in a capital) inside about a
second → no false "sent" (the `/2` line is not taken as the echo; a drop note only if the General line
really never arrived). Record the client build.
Result: 2026-10-25, pass (the owner's run; client build not recorded).

**SEND-7. Lockdown lift after an encounter or a key (2026-10-25, F-003).** On a raid boss or in a
Mythic+ key, put a Say callout on the pad. During the encounter the padlock and the lockdown chip
show. Kill the boss, or complete the key → within about a second of `ENCOUNTER_END` /
`CHALLENGE_MODE_COMPLETED` the padlock and the chip clear, and a press prints no "may not have been
sent" line. Repeat with a wipe (`ENCOUNTER_END` fires then too). Note whether the flag ever clears
later than the 1 s re-read (a known limitation if it does). Record the client build.
Result: 2026-10-25, pass (the owner's run; client build not recorded).

## Tokens

**TOKEN-1. {coordinates} (2026-10-23, run item QF-03).** Out of combat in the open world, make a Say
callout `{target} @ {coordinates}` in a group on your pad. Target something, click it → chat shows
`<name> @ 45.2, 61.8`-style numbers matching your position on the world map (one decimal
each, x then y). Walk a little, click again → the new position, not the old one, with no error and no
"interface action blocked". Walk again, pull a mob, and click it in combat → it sends the position
where combat started (not the last out-of-combat one before you walked), and no error. Leave combat.
`/qc preview`, click it → `[QC] /s <name> @ <where you are>` and nothing is sent; walk, click → the
echo follows you. Pick M+ in the window, click → `<coordinates>` in place of the numbers. End preview.
Enter a dungeon, click it → `<name> @` with nothing after the `@`. The callout popup's "i" lists
{coordinates} with its line of help, and `{coords}` typed works the same.
Result: 2026-10-24, pass (the owner's run; client build not recorded).

## Pad

**PAD-1. First run.** On a fresh profile, enter a key → the default pad shows "Dungeon" with
eight buttons, with no channel letter at the right edge of any of them (the label runs to the edge);
the header reads `Quick Comms: M+ · <dungeon> +<level>`. Hovering a button shows its name, the exact line it sends
and `Channel: Party` in the party's chat color; a wedge on the Comms Dial shows the same lines. Every button shows its glyph in a color: Lust a red enraged face,
Need mana a blue drop, Res me a green ankh, GG a gold trophy, Pulling orange crossed swords, Kick
order a purple boot, Skipping a cyan figure, Chain pull red chains. Leave the key and zone into a
normal or heroic dungeon → the same set shows. On a profile saved before this build (it still shows
"M+ (generic)" with the bloodlust spell icon on Lust), `/reload` with this build → the set reads
"Dungeon" and Lust shows the red glyph; a set renamed before, or a callout whose icon was
cleared, keeps the player's choice. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PAD-2. The stale hint.** In combat, `/qc set behavior.autoPromote false` → the header shows
"updates after combat"; when combat ends it clears and the pad has rebuilt. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PAD-3. Lock, drag, position.** `/qc unlock` → a drag strip appears above the pad, exactly as wide
as the pad (add or remove a group so the pad widens or narrows → the strip follows); drag it
elsewhere; `/reload` → it is where you left it. In combat the strip will not drag, and a drag still
held when combat starts ends there, with no error. `/qc lock` → the strip is gone (it comes back, undraggable, only to carry PREVIEW or TEST MODE). General → Master
controls → Reset position → the pad returns to its default place, just below the center. The
launcher's Locked entry toggles the same lock. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PAD-4. Test mode.** `/qc test` → placeholder buttons in four groups, Test group 1 to 4, holding 4,
8, 12 and 16 buttons (2026-10-21), each with a shipped callout's name and icon (Pulling, Lust and
so on, no name twice), and the strip above the pad reads
`Comms Pad  TEST MODE` (TEST MODE in green; the strip shows even while locked, and will not drag
then; the header has no TEST MODE of its own); clicking one sends nothing. Rename the pad to a long
name → the strip stays as wide as the pad while the name and the marker fit, and widens past the pad only for a name too long for it. Pull something → test mode ends with one line and the real buttons return. `/qc test` in
combat → refused with one line. The Master controls checkbox and the launcher entry follow every
change. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PAD-5. Visibility and fade.** General visibility "Only out of combat" → the pad hides on the pull
with no error and returns after; Master opacity 50% → the pad is half transparent. Result: 2026-10-21, pass (the owner's run; client build not recorded).

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
before 2026-10-19 moves once on its first load, by up to its height (see
`docs/known-limitations.md`); drag it back and it stays. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PAD-10. Button width and the section title.** Pad → Buttons → Button width reads 100 on a new
pad, and Layout no longer has it; drag it to 300 → wide buttons, each label on one line, running to the button's right edge with no
channel letter after it; down to 30 → the labels cut short, still
one line; down to 1 → icon-only slivers, no label and no Lua error. Make a group named `World`, put
it on the pad and stand in the open world → the header reads `Quick Comms: World` and the section under it has
no second `World` line; rename the group `My world` → its title line is back. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**PAD-11. Solo and the built-ins' colors (groups polish).** Out of any group, in the open
world: the pad shows a Solo section of seven buttons, each tooltip reading `Channel: Say` (Rare spotted a gold spyglass,
Elite help a red ogre, Group quest a gold scroll, World boss a red crowned skull, Event here an orange
bell, Invite me a blue envelope, Thanks green hands).
Target a mob and click Rare spotted → /say reads "Rare spotted here: <target>"; click Invite me →
/say reads "Invite please". Join a party → the set is gone. On the Groups page every built-in group's
icon is a colored glyph named for it (Dungeon a purple gate, Arathi Basin a gold wheat sheaf, each
node its own), and no set's callouts are all white. On a profile saved before this build, `/reload`
→ Solo is added at the end of every pad and dial; the built-in callouts and groups take their
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

**PAD-16. A shrunk pad leaves nothing clickable behind (2026-10-25, F-006).** On an M+ pad (18
buttons), zone to the open world so the pad shrinks. Click where a removed button used to be →
nothing is sent and nothing there takes the click. The remaining buttons still send.
Result: 2026-10-25, pass (the owner's run; client build not recorded).

**PAD-17. A rebuild that moved no line still sends (2026-10-25, F-006).** Change the pad's spacing
(or any setting that changes no line) and press a button → it still sends its line.
Result: 2026-10-25, pass (the owner's run; client build not recorded).

## Editors

**EDIT-1. A callout and a group on the pad (the phase 3 exit).** Settings → Groups → New group; on
its Callouts tab click Add callout → the callout popup opens blank (Smart group, no icon); name it
`Inc`, text `INC {skull}`, Save → the popup closes and `Inc` is the list's last row. On the group's
When tab click the Content header and tick M+ in its drawer. Enter a key → the pad shows the new group first with
an `Inc` button; click it → the party sees "INC" with a skull. Leave the key → the group is gone from
the pad. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-2. A built-in set is an ordinary group (the phase 3 exit, rewritten 2026-10-18).** Groups →
pick "Dungeon" → the picker shows no "(built-in)" tag (in a key it reads `Dungeon` with the
green dot after the name, not before it; Pad → Groups and Dial → Groups put it after the name too), and the page draws the same tabs as a
group of yours, nothing read-only. General: Name, Enabled, Parent group,
the icon with Choose icon…, Duplicate group and Delete group…, then Restore built-in groups; no Customize and no
read-only line. Callouts: the callout table, exactly as a group of yours draws it (Add callout, Reuse
callout with Add, a boxed row per callout with its handle, icon, name and channel, edit and remove
glyphs); no Show checkboxes. When: the editable condition drawers (EDIT-22), Content's summary
reading M+ in gold; not read-only text. Rename a callout in the popup and Save → in a key, the button's label
changes. Untick Enabled → in a key the set is gone from the pad; tick it again. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-3. Preview as….** Out of combat, in the open world: General → Master controls → Preview as → Arena →
the pad shows the arena set with `Preview: Arena` on its header and PREVIEW on its drag strip (in
green, after the pad's name); clicking a button sends
nothing to chat and prints its line locally (EDIT-29); its tooltip says so. The Comms Pad, Comms Dial and Groups pages' General tabs have no
Preview as row. Close the settings → the preview and its window stay; End preview in the window
ends it. `/qc preview raid:2912` →
the raid set; pull something → the preview ends with one line and the live buttons return.
Result: 2026-10-23, pass (the owner's run; client build not recorded).

**EDIT-4. Why is this showing?.** In a key, hover the pad's header → the tooltip lists "Dungeon:
Content" (and any other group, with its rows); with a `/raid` callout on the pad
outside a raid, the last line names the lock. Behavior → Explain why groups show off → no tooltip.
`/qc why` prints the same lines per pad. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-5. The Pad page.** Pad → Layout: Orientation Vertical, Button style Label only,
Scale 1.5 → the pad redraws each time. Type X `200`, Y `-100` → it moves; Reset this pad's position
→ it returns. General → Visibility Only out of combat → it hides on the pull with no error. Groups:
drag a group to the top → it comes first on the pad. New pad → a second pad appears holding every
built-in group you still have (top-level, in shipped order); Delete pad… (Yes) → it is gone. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-6. Restore built-in groups (rewritten 2026-10-18; the Share page's Built-in tab is gone).**
Groups → "Raid" → Delete (Yes) → it is gone from the
picker and, in a raid, from the pad. On "Dungeon"'s Callouts tab remove "Lust" (Yes). General →
Restore built-in groups (no question asked) → one chat line counts the groups and callouts that came
back; "Raid" is in the picker again and last on every pad's and dial's Groups list, and
"Lust" is the last row of Dungeon's Callouts. Click Restore again → "nothing to restore", and
nothing is added. Delete "Lumber Mill" (inside "Arathi Basin") → Restore → it is back, indented under
Arathi Basin in the picker, and in Arathi Basin (or Preview as → Arathi Basin) its wedge is on its
wind, SW, again. Rename "Dungeon" → Restore leaves it as it is and adds no second dungeon set. With
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
settings window, in the skin's window (on **Ka0s Default** the Ka0s window: its dark fill and edge,
the window title "Ka0s Quick Comms" in the top bar in the skin's title color and face, and the skin's
close X at its top right; its background not darkened by the dim around it), then the gold
"Edit callout" header and rule, then Name and Channel side by side, Text on a line of its own across
the whole width, an "Icon" label over the icon with Choose icon…, a small red clear glyph and Icon
color (there is **no Icon text box**), a section's gap (about 18 px) under that row, the Preview
heading over the baked line,
a clear gap (about a section's) under that line, and the red Save and Cancel buttons, Save on the
left (since 2026-10-22, owner; Cancel on the left before); there is no Insert a token dropdown. **Alignment:** every label starts exactly over the left
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
closes, the row and the button show the new name, text and icon. (Amended by QC-02, 2026-10-30: since
LibKa0s v1.81.0 retired the stock look, R-2, the popup is the skin's window under Ka0s Default too, no
longer Blizzard's settings window; WoW Default is the stock look. The 2026-10-21 pass predates it.)
Result: pass (owner-marked 2026-10-30).

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
The list has no built-in section: "Dungeon: Lust" is listed like any other group's callout;
reuse it → a copy you can edit, and the M+ group's Lust is unchanged. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-12. The remove glyphs.** On a group's Callouts tab, a row's remove glyph (the red no-entry
sign; its tooltip reads Remove, "Delete this callout. Asks first.") → the confirmation names the callout;
No keeps it, Yes deletes it, and Reuse no longer offers it. On Pad → Groups, a row's remove
glyph (its tooltip: the group itself is kept) → the group leaves that pad at once, with no question, and is still on the Groups page; the
same on Dial → Groups. Neither list has an edit glyph. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-13. The callout popup on the skin (rewritten by QC-05, 2026-10-29; by QC-02, 2026-10-30).**
Quick Comms' own EllesmereUI bridge is retired (rollout D1): the popup and the icon browser wear the
skin this addon wears, EllesmereUI's look among them, through LibKa0s. On **Ka0s Default** open the
callout popup (EDIT-9), then Choose icon… → both wear the Ka0s window (LibKa0s v1.81.0 retired the
stock look, R-2). **WoW Default** → open them again → both are Blizzard's settings window. Settings →
General → **Skin** → **Azeroth** → open them again → both wear Azeroth's window (SKIN-8). With EllesmereUI set up
as SKIN-13 says and **Skin source** on **EllesmereUI** → both wear the same EllesmereUI shell, border
and close X as the settings window behind them, and `/qc diagnostics`'s integrations section reads
`skin: source=eui skin=… ellesmereui: ok=true painted=true refused=nil failing=none`. `/qc disable` →
open the popup and the icon browser from the settings window → both still wear the skin (it does not
wait for the addon to be enabled); `/qc enable`. Disable EllesmereUI and `/reload` → the popup opens in
the Ka0s skin, and `failing=` names the missing condition. Result: pass (owner-marked 2026-10-30).

**EDIT-14. The icon browser: look, tabs and a pick.** Open a callout of yours in the popup (EDIT-9) →
under the Icon row, the callout's icon (a question mark for none), Choose icon… and Icon color.
Click Choose icon… → the icon browser opens **over** the popup, which is dimmed behind it (a click on
the popup does nothing), and looks like it: the skin's window (the Ka0s window on Ka0s Default, R-2),
"Ka0s Quick Comms" in the top bar, the skin's close X, the gold "Choose an icon" header. The tabs read
Markers, Game icons, Glyphs (no Suggested); the callout's icon is selected (gold behind it) on its
own tab, scrolled into view, and named in the footer; a callout with no icon, or a seeded set's
spell icon, opens on Markers with nothing selected. On Glyphs, the Icon color row sits clear of the first
row of icons (a gap between them), and it is gone on Markers. Markers shows the eight markers; Glyphs every
LibKa0s glyph, white, each named on hover (`Arrow circle down`-style names); the count at the right
follows the tab. Click an icon → it is selected and named in the footer, nothing else changes; Cancel
→ the popup's icon is unchanged. Choose icon… again, double-click the skull → the browser closes and
the popup shows the skull (the button on the pad does not change until Save). (Amended by QC-02,
2026-10-30: since LibKa0s v1.81.0 retired the stock look, R-2, the browser is the skin's window under
Ka0s Default too; the 2026-10-21 pass predates it.) Result: pass (owner-marked 2026-10-30).

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
shows it white (the color went with the marker). `/reload` → every color is still there. Result: 2026-10-21, pass (the owner's run; client build not recorded).

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
the eight markers, {me}, {spec}, {role}, {key}, {dungeon}, {coordinates}, then {spell:ID}), with no
{group1} … {group8} line, and fits on screen without wrapping each line. Pick Raid as the Channel
and hover again → one {group1} … {group8} line appears (no Save needed). Move off → the tooltip
hides. Cancel, then open another settings page with text boxes (a group's General tab) and open
the popup again a few times → no stray "i" appears beside any other box, and the popup shows
exactly one. Result: 2026-10-24, pass (the owner's run; client build not recorded); passed 2026-10-21 before {coordinates} joined the list, QF-03).

**EDIT-19. A group inside another.** Make two groups of yours, `My keys` (on the pad, with a
callout and a When that matches where you are) and `Kicks`. On Kicks' General tab, Parent group →
the dropdown lists None and the top-level groups, not Kicks itself; pick My keys → Kicks leaves every
pad's and dial's Groups list, Add a group there does not offer it, and the Groups picker lists it
indented right under My keys, and Inherit when conditions beside Parent group is ticked and no
longer grayed out. Give Kicks a callout → the pad shows My keys' own section, then a section titled
Kicks; the dial (test mode or its key) shows My keys' callouts, then a Kicks wedge that opens its
ring. Untick Inherit when conditions and give Kicks a When that does not match → its section and
ring go, My keys stays (EDIT-23 covers inheriting). On My keys' General tab, Parent group is grayed out; its tooltip names
Kicks. Duplicate group on Kicks → the chat line says the copy is inside My keys. Delete My keys → the question
says the groups inside it become top-level groups in its place; Yes → Kicks and its copy are
top-level, on every pad and dial where My keys was. `/qc set group.parent none` on a selected child
makes it top-level; `/qc set group.parent <its own id>` is refused, with a line saying why.
Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-20. The Preview table.** Groups → "Dungeon" → Preview → the active-now line, then a gold
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
it; the page's Defaults ticks it again. Result: 2026-10-21, pass (the owner's run; client build not recorded).

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

**EDIT-25. The Callouts rows and the window and Buttons tabs.** Groups → "Dungeon" → Callouts → each
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
preview again; close the settings with the X → the edit preview ends, but Preview as stays on
Raid · Heroic: the pads show the Raid · Heroic preview and its window stays up (End preview → the
live pads). On Groups, untick Preview while
editing → the live pads at once; tick it → the group again. Enter combat with the page open → the
pads go live with one "Preview ended" line; leave combat with the page still open → the edited
group's preview comes back.
Result: 2026-10-23, pass (the owner's run; client build not recorded).

**EDIT-28. Right-click a group title.** Out of combat, in a battleground (or with Preview as →
Arathi Basin): hover a section title on the pad → the tooltip names the group and says Right-click
to edit this group. Left-click it → nothing. Right-click it → Settings opens on Groups with that
group in the picker. Pick the Callouts tab, close the settings, right-click a node's title → Groups
opens on that node, still on Callouts. Set the pad's Groups as to Tabs → right-click the tab's title →
the group that tab shows. Enter combat and right-click a title → the "cannot open settings during
combat" line and nothing opens; no error. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-29. A preview click echoes its line.** Out of combat, solo in the open world: make a group
with a callout `Go {me}` on Yell and put it on the pad and the dial. Master controls → Preview as →
Solo → click the button → one local chat line, `[QC] /y Go <your name>`, and nothing said
aloud (no yell bubble, nobody else sees it). Change the callout to Smart group and preview Raid ·
Heroic → the click prints `[QC] /raid Go <your name>`. Open the dial on the preview and click the
wedge → the same line, and the dial closes. On Groups with Preview while editing ticked, click a button
of the edited group → its line prints the same way. End the preview and click the live button → the
yell goes out, with no `[QC]` line. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-30. The Pad and Dial pages (dial polish, 2026-10-21).** Open the settings → the pages under Ka0s
Quick Comms read General, Groups, Pad, Dial, Profiles (no "Comms Pad" or "Comms Dial" page).
The default pad and dial are still named Comms Pad and Comms Dial in their pickers, and a dial's ring of groups is still titled Comms Dial. Delete every
dial, then `/qc set dial.radius 120` → "No dial to edit: make one on the Dial page." Result: 2026-10-21, pass (the owner's run; client build not recorded).

**EDIT-31. The callout popup's Save is on the left (owner, 2026-10-22).** Open Edit callout → Save on
the left, Cancel on the right, each a column wide; Save saves and closes, Cancel closes and changes
nothing. Result: 2026-10-23, pass (the owner's run; client build not recorded).

**EDIT-32. Preview as and the shipped sets (owner, 2026-10-22).** General → Master controls → Preview
as → Current; one M+ entry per current-season dungeon (M+ · <dungeon> · <spec>, eight, A–Z: Algeth'ar
Academy first, Windrunner Spire last); Raid · Mythic · <raid> for each of the three raids, A–Z (March on
Quel'Danas, The Dreamrift, The Voidspire), and no LFR, Normal or Heroic rows (2026-10-25); Arena; one BG - <name> entry per battleground; Solo last. On a fresh
profile the groups read Dungeon, Raid, Arena, Battleground and Solo; Dungeon holds seven callouts
(Pulling, Lust, Need mana, Skipping, Res me, Chain pull, Kick order), In Group ten (Hello, Summon,
Buffs please, Healthstone, tyff, brb, Ready, GLHF, ggty, ggnt) and Solo seven. Arena's Swap and Kill
and every Kill … carrier callout send your target's name ({target}). The pads start unlocked (their
drag strips show) until Lock pads. Result: 2026-10-25, pass (the owner's run; client build not recorded).

**EDIT-33. Nested groups A–Z (2026-10-25).** Groups → the Group picker: the top-level groups A–Z, and
under Alterac Valley its objectives A–Z (Aid Station, Balinda, DB North Bunker, DB South Bunker,
Drek'Thar, Frostwolf GY, FW East Tower, FW West Tower, Galvangar, …, Tower Point, Vanndar), Arathi Basin's nodes
Blacksmith, Farm, Gold Mine, Lumber Mill, Stables. In Arathi Basin the pad's sections and the dial's
ring (after the set's own wedge) follow the same order. New group `Zed`, then `Alpha`, both inside a
group of yours → Alpha lists first. Result: 2026-10-25, pass (the owner's run; client build not recorded).

**EDIT-34. The delete and copy buttons' labels (2026-10-25, audit QC-19).** On the Groups, Pads
and Dials pages' General tabs, each delete button ends in an ellipsis (Delete group…, Delete pad…,
Delete dial…) and opens its confirm; the Groups page's copy button reads Duplicate group.
Result: 2026-10-25, pass (the owner's run; client build not recorded).

## Preview window

The "Preview as…" selector window (`modules/PreviewWindow.lua`, 2026-10-23): a small window titled
`Ka0s Quick Comms - Preview`, with a situation dropdown, End preview and a close mark, shown exactly
while a Preview as… preview is on, whichever way it started.

**PREVIEW-1. The settings row opens it.** Out of combat: Settings → General → Master controls →
Preview as → Solo → the window appears above the settings, its dropdown on Solo, with an End
preview button; the pads show PREVIEW.
Result: 2026-10-23, pass (the owner's run; client build not recorded).

**PREVIEW-2. The dropdown and the slash move together.** With PREVIEW-1's preview on, pick Arena in
the window's dropdown → the pads switch to the arena set and the settings row reads Arena.
`/qc preview raid:2912` → the dropdown moves to the Raid · Mythic · The Voidspire entry.
Result: 2026-10-25, pass (the owner's run; client build not recorded).

**PREVIEW-3. It outlives the settings window.** Close the settings window with a preview on → the
preview and the window stay. Click End preview in the window → the window goes, the pads are live,
and the settings row reads Off when the settings are reopened.
Result: 2026-10-23, pass (the owner's run; client build not recorded).

**PREVIEW-4. The close mark and Escape.** With a preview on, click the window's close mark → the
preview ends. Start one again with the settings open and press Escape → the preview ends and the
window hides, the settings stay; a second Escape closes the settings.
Result: 2026-10-23, pass (the owner's run; client build not recorded).

**PREVIEW-5. Combat and Alt+Z.** With a preview on, pull a mob → the window goes with one
`Preview ended: you entered combat.` line and the live buttons come back. Out of combat, start a
preview and press Alt+Z → the window hides with the UI; Alt+Z again → it is back and the preview
never ended.
Result: 2026-10-23, pass (the owner's run; client build not recorded).

**PREVIEW-6. Test mode, disable and the open menu.** With a preview on, `/qc test` → the window
goes (test mode has no window). With a preview on, `/qc disable` → the window goes; `/qc enable`.
With a preview on, open the window's dropdown menu and press Escape → the menu and the window are
both gone, nothing left floating.
Result: 2026-10-23, pass (the owner's run; client build not recorded).

**PREVIEW-7. The saved position.** Drag the window somewhere else, end the preview and start it
again → it opens in the same place. `/reload` and start a preview again → still the dragged place.
Result: 2026-10-23, pass (the owner's run; client build not recorded).

**PREVIEW-8. Bare `/qc preview` and `list`.** In the open world with no preview on: `/qc preview` →
chat `Previewing: Current`, the window opens on Current and the pads show PREVIEW. `/qc preview list`
→ the menu prints and nothing changes. `/qc preview nope` → the line points at `/qc preview list`.
`/qc help` → the preview line reads "Preview the pads and dials as another situation in a small
window — …".
Result: 2026-10-23, pass (the owner's run; client build not recorded).

**PREVIEW-9. Every preview looks like live (2026-10-23, run item QC-05, SM-QC-8).** In the open
world, solo, note how the pad's buttons and the dial's wedge icons look in a live situation (or
from a screenshot of one). Open Settings → Groups (the edit preview) on a group with party
callouts, then Preview as → Dungeon: the dial and pad icons look exactly as in live mode, with no
fading and no dark circle over the dial's icons; only the PREVIEW labels (the hub's, the pad
strip's) are added. Click a button and a wedge → nothing is sent. Turn test mode on → its
placeholders look the same as before.
Result: 2026-10-23, pass (the owner's run; client build not recorded).

**PREVIEW-10. A click prints what it would send (2026-10-23, run item QC-07, SM-QC-10).** In the
open world, with no target: `/qc preview`, pick In Group in the window. Click the Hello pad button →
your chat frame shows a `[QC] /p Hello world!`-style line, the slash the previewed situation picks
and the text with its tokens filled (a callout with `{target}` shows `<target>` while you have no
target, and your target's name once you have one; a raid marker shows as its icon). Click a dial
slice → the same kind of line. Nothing appears in party chat, and no button flashes as sent. A
callout that would send nothing there (a smart-channel callout under Preview as World) prints
`[QC] (nothing sent: <reason>)` with the tooltip's reason. `/qc test`, click a placeholder button and
a placeholder slice → one line each: its name and `(test-mode placeholder: nothing sent)`. `/qc
preview off`, click Hello → it really sends, as before, and prints nothing extra.
Result: 2026-10-24, pass (the owner's run; client build not recorded).

**PREVIEW-11. The window and start line over the edit preview (2026-10-23, run items QF-02 and QF-07).** Out
of combat, `/qc debug` on, Preview while editing ticked: Settings → Groups → a group of yours → chat
prints `Previewing: <group> (editing)` once and the preview window opens, titled
`Ka0s Quick Comms - Preview: <group>`, its dropdown on the group's own situation, and the whole
window grayed out (QF-07, 2026-10-23): hovering the dropdown, End preview or the close mark shows a
tooltip saying the window is disabled while you edit a group and to pick another group to see its
preview, and clicking them does nothing. Pick Alterac Valley → the dropdown
reads `BG - Alterac Valley`; an AV node → the same; a raid group → `Raid · Normal · <raid>`; In Group
→ Current; the pads' slashes are that situation's. Pick another group → the title and the dropdown
follow and no new line prints. Click a pad button and a dial slice of the edited group → each prints
its `[QC]` line (with `/qc debug` on, a `press ...` debug line shows the click arrived; a missing echo
with a debug line is the bug, a missing debug line means the click never reached the button). Untick
Preview while editing → the pads go live and the window goes; tick it → the line and the window
again. Press Escape → the window and the preview go, the box stays ticked, and
it does not come back while the same group stays selected (switching tabs, waiting, a combat end);
pick another group → it starts again. Pull a mob with it on → `Preview ended: you entered combat.`;
leave combat with the page open → the window is back with no `Previewing:` line. `/qc preview off`
with only the edit preview on → `Preview off.`, the window goes, the box is unticked. Close the
settings with the X → the window goes. Press Alt+Z → the window hides with the UI and the preview
stays on.
Result: 2026-10-24, pass (the owner's run; client build not recorded).

**PREVIEW-12. A preview dial stays open on a slice click (2026-10-23, run item QF-01).** `/qc
preview`, pick In Group in the window, open the dial (it opens with the preview). Click a callout
slice → its `[QC]` line prints and the dial stays open; click another slice → its line too, still
open. A group slice still opens its ring, the hub still goes up a ring (and closes on the first),
a right click still goes back, a middle click and Escape still close. `/qc test` → a placeholder
slice prints its line and the dial stays open. On the Groups page with Preview while editing on, a
slice of the edited group prints and the dial stays open. `/qc preview off`, open the dial with its
key, click a slice → it sends and the dial closes, as before; the same in combat.
Result: 2026-10-24, pass (the owner's run; client build not recorded).

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
and In Group: several active groups); click the raid or dungeon set → its callouts; click a
callout wedge → the group sees the line, the dial closes, and there is no "action blocked" error or
red text. With the dial closed, 1 still fires your action bar's first button. Press G again at once →
every wedge is dimmed for about a second (the spam guard). Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-3. The Categories two-stroke (the phase 4 exit).** With two groups active (an always-on group of
your own and M+ in a key): press G → the first ring shows the groups; click one → its callouts; click
a callout → it is sent. Open again, click a group, click the hub → back to the groups; click the hub
again → the dial closes. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-4. The Arathi Basin node dial (the phase 4 exit; three rings since the dial rework; unpinned
2026-10-25).** In Arathi Basin, with Slices per ring on Auto: press G → the ring of groups (Arathi
Basin, Battleground, In Group); click Arathi Basin → six slices and no empty one, no page arrows: the
Arathi Basin wedge (the gold wheat sheaf) at N, which opens the map-wide callouts (groups polish), then
clockwise Blacksmith, Farm, Gold Mine, Lumber Mill, Stables; click Lumber Mill, then INC → instance
chat shows "INC Lumber Mill". Open again, open Arathi Basin and press 5 → Lumber Mill's ring opens
(the number keys count the shown wedges clockwise from N). With Slices per ring at 4 → two pages, the
first four, then Lumber Mill and Stables. (If the dial does not show Arathi Basin at all, the instance id may be
wrong: run `/qc diagnostics`, copy the `situation` section's instanceID into the "Battleground
instance IDs seen" table of `docs/brainstorm/go-no-go/round-4-build-checks.md`, and file it with
this check's ID; BG-2 confirms the ids.) Result: 2026-10-25, pass (the owner's run; client build not recorded).

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
placeholder wedges and TEST MODE above the hub: four group wedges, Test group 1 to 4, opening rings of
4, 8, 12 and 16 callouts with shipped names and icons (2026-10-21; a ring holding more than
the dial's slices pages: its page arrows turn the page, the Left and Right arrow keys and the wheel do not); clicking sends nothing; 1 still fires the action bar. `/qc test` again → test mode ends, and
no Test group or placeholder callout appears on the Groups page or in a new session.
General → Master controls → Preview as → Arathi Basin → the dial opens on its groups with PREVIEW, and Arathi Basin opens the nodes; nothing
sends; Escape ends the preview through the preview window (the dial closes, the settings window
stays open), and a second Escape closes the settings window.
Turn test mode on, then pull a target dummy → test mode ends; the dial closes at once or, if combat
won the race, at combat end, and in between 1–8 and Escape still do what they always do.
Result: 2026-10-23, pass (the owner's run; client build not recorded).

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
Solo in the open world (Solo the only active group), press G → the dial opens straight on
Solo's callouts, no ring of groups. Join a party in the open world → press G → the ring of
groups (Solo is gone, In Group and any always-on group of yours); click In Group → its
callouts. Enter a dungeon with the party (or start a key) → the ring of groups shows Dungeon
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
W. The Preview tab lists wedge 1 as W, and the number keys 1–8 still follow the callouts' order. Result: 2026-10-21, pass (the owner's run; client build not recorded).

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
width grayed out under Solid circle and Rimmed disc, and 4 → a thicker ring under Hollow ring. Hub size 70 → a wider hub,
the slices and the pointer starting at its edge in every direction, and a click just outside its
circle, on a diagonal too, lands on a slice (DIAL-28); Circle size 40 → a bigger circle. Backdrop color, Hub border size 3 with a red Hub border
color, Circle color green, each Use class color → as set. Hover the hub → the circle brightens; move
off → it dims. The stale hint, LOCKDOWN and TEST MODE labels sit where they did. Defaults → the gold
solid circle on the 40-pixel hub. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-30. The Group labels tab (dial polish, 2026-10-21).** Dial → Group labels: Show group labels
ticked, then a Font block. Font size 18, a different face, Thick outline, color white → the ring's
title above the dial ("Solo", "Comms Dial") redraws that way, lifted to clear the labels, and
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

**DIAL-36. Automatic icon offset and size follow the ring radius (2026-10-21).** On a new dial with
eight wedges (Wheel → Wedges per ring 8), Dial → Icons: Icon offset reads Automatic and Icon size
(0 = automatic) reads Automatic (`/qc get dial.icon.size` → 0). Ring radius 100 → the icons sit
roughly in the middle of their slices at 32 pixels, as before. Ring radius 150 → the whole wheel
scales: each icon keeps the same place in its slice (not out by the rim) and grows to about 48
pixels. Ring radius 180 → the same place, about 58 pixels, nothing overlapping. Ring radius 70 → the
same place, about 22 pixels. At every radius a click anywhere in a slice still sends it (DIAL-28),
and the hovered slice lights the one the icon is in. Icon size 40 → 40 pixels at every radius; drag it
back to 0 → Automatic. Icon offset 60 → the icons at 60 at every radius. In combat, `/qc set
dial.radius 150` → "updates after combat", the icons moved and resized at combat end, no error. A
dial saved before this keeps its stored Icon size (32) until it is set to 0. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**DIAL-37. A new dial is 120 across with 48-pixel icons (owner, 2026-10-22).** Dials → New dial →
Wheel → Ring radius reads 120; Icons → Icon size reads Automatic → the icons draw at 48 pixels, in the
same places as a 120 dial before this change. Ring radius 100 → 40 pixels; 150 → 60; 180 → 72; 70 → 28.
The dial's Defaults button puts Ring radius back to 120. A dial saved before this keeps its stored
radius (100). Result: 2026-10-23, pass (the owner's run; client build not recorded).

**DIAL-38. A right click on a slice goes back a ring (owner, 2026-10-22).** In a key with two groups
active, open the dial (the ring of groups), click a group → its callouts. Right-click a slice → back on
the ring of groups, still open, nothing sent. Right-click a slice there → nothing happens, the dial
stays open. On a paged group ring, turn to page 2 and right-click a slice → the ring of groups.
Right-click the middle button → the dial closes. Repeat in combat on a target dummy → the same, no
"action blocked" error. Result: 2026-10-23, pass (the owner's run; client build not recorded).

**DIAL-39. The dial opens where it was closed (owner, 2026-10-22).** Open the dial, click a group, turn
to its page 2, press the key → it closes. Press it again → the same group on page 2. Escape, a click
outside and a sent callout leave it the same way. Change a setting (a rebuild) → it still opens there.
Go up to the ring of groups, close, reopen → the ring of groups. Leave the content so that group is no
longer active → it opens where the dial opens by default. Test mode shows the default ring and does
not change where the key opens it. In combat → the same. Result: 2026-10-23, pass (the owner's run; client build not recorded).

**DIAL-40. Slices from N; labels a little further out (owner, 2026-10-22).** Wedges per ring Auto:
with one callout → the whole disc, its icon at the top; two → top and bottom halves; three → thirds,
the first at the top; four → N, E, S, W; eight → N first, clockwise. Wedges per ring 4 with two
callouts → N and S, E and W empty; with three → N, E and S. Wedges per ring 12 → the Preview tab lists
wedge 1 at 12 o'clock. The number keys still follow the callouts' order. Label offset 0 → each label sits a little clear of the disc's edge (4 pixels, 2
before). Clicks, hover and right-click land on the slice under the cursor, in combat too.
Result: 2026-10-23, pass (the owner's run; client build not recorded).

**DIAL-41. The shipped dial look (owner, 2026-10-22).** On a fresh profile the dial has a 32-pixel
solid gold hub with a 1-pixel gold rim and a 24-pixel circle, a 24-pixel pointer 24 pixels out,
outlined slice labels, 16-point outlined group labels, the Orb shine on the slices (gray tint), and
8-pixel page dots with a 2-pixel border. Result: 2026-10-23, pass (the owner's run; client build not recorded).

**DIAL-42. A dial that lost wedges (2026-10-25, F-006).** Open a dial whose rebuild dropped wedges
(fewer callouts than before) → the number keys past the item count do nothing, and a click on an empty
slice does nothing. Result: 2026-10-25, pass (the owner's run; client build not recorded).

**DIAL-43. The slice highlight on reopen (2026-10-25, F-001).** Open a dial, hover a slice, close
it, and reopen it with the cursor on the same slice → it lights in place. Change Slice gap, reopen and
hover → the highlight sits on the shifted slice. Result: 2026-10-25, pass (the owner's run; client build not recorded).

## Look

The Comms Pad's Pad header, Section header and Window tabs (one Window tab until 2026-10-20, the
Look tab before that, then Main window until it became Window, its visibility rows on General; the
checks keep their LOOK ids).

**LOOK-1. Section titles.** On a new pad the section titles are gold, 12 points and outlined. Pad →
Section header → Font: untick Use the skin's font, pick another face, Font size 14, Font flags None, untick Font shadow →
the section titles (In Party, Mythic+…) redraw that way, still
gold; the button labels do not change (they are the Buttons tab's). Tick Use class color → the titles take
your class color, and Font color's opacity still applies; untick it and set Font color to red → the
titles turn red. (Amended by QC-05, 2026-10-29: since the skinning rollout a face is picked with Use
the skin's font unticked, SKIN-6.) Result: pass (owner-marked 2026-10-30).

**LOOK-2. Border and background.** Pad → Window → untick Use the skin's border, then Border style: a LibSharedMedia border (Blizzard Tooltip, for one),
thickness 3, color red → the pad's edge changes; thickness 0 → no edge. Background: dark blue at 50%
opacity → the body changes; Use class color → your class color at 50%. The settings panel is closed
and locked in combat, so the in-combat write goes through the command line: in combat,
`/qc set pad.look.borderSize 3` → no error, the header shows "updates after combat", and the thicker
edge lands at combat end. Defaults → the Ka0s look again, Use the skin's border ticked. (Amended by
QC-05, 2026-10-29, the skinning rollout, SKIN-6.) Result: pass (owner-marked 2026-10-30).

**LOOK-3. The header's look (2026-10-20).** On a new pad the header row (the top row, `World` in the
open world) is 24 pixels tall (it was 18) with gold 16-point outlined text, no background and no edge
(the owner's defaults). Pad → Pad header: Size → Header height 30 → the row grows and every
section moves down with it; Font size 20, another face (Use the skin's font unticked first), Font flags Thick outline → the situation text
redraws that way, and during an encounter with a Say callout on the pad the LOCKDOWN tag takes the
same face and size and stays red; the collapse button grows with it. Background dark red at 60% → a
band behind the header only; Border thickness 2, color white → an edge around the header only, with no
gray inner line; with Use the skin's border unticked, a LibSharedMedia border style draws that art. Use class color on each → your class
color. Defaults → the owner's header again, 24 tall, in the skin's face. (Amended by QC-05,
2026-10-29: the skinning rollout's Use the skin's font and border, SKIN-6; the header's default face
is the skin's HUD font, SKIN-1.) Amended by R5-QC1 (smoke round 5): by default the header wears the
skin's title band (PLOOK-12), not no background; the dark red draws with *Use the skin's background*
unticked, and under Ka0s Default the Border thickness 2 draws around the header over the band with *Use the
skin's border* still ticked. Result:

**LOOK-4. The header's text sits on the titles' edge (2026-10-20).** Stand where the pad shows a section
title under the header (a party in the open world: `World` over `In Party`). The `W` of World and the
`I` of In Party start at the same distance from the pad's left edge (before, World sat a few pixels to
the right). Layout → Growth → Left and down, Right and up, Left and up in turn → still aligned in each;
Spacing 20 → still aligned. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**LOOK-5. Three window tabs (2026-10-20).** Pad → the strip reads General, Groups, Layout, Pad
header, Section header, Window, Buttons, Icons (no Main window or Chip tab). Pad header shows the headings Size,
Font, Background and Border, each once; Section header the same four; Window Background and
Border, with no font controls and no Visibility (General has it, under its own heading, above Unlock
pads and Delete pad…). Change a value on each tab → only that part of the pad
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

**LOOK-7. The pad's window repaints when it should (2026-10-31).** A rebuild no longer repaints the pad's
window when nothing about it changed. On a pad, move Pad → Window's border thickness and its border and
background colors → each shows at once. Pick another skin on the Skin tab → the pad's edge, background
and inner line follow it. Change the situation so the pad's buttons rebuild, and `/reload` → the pad
keeps that look, with no gap in its border. Result:

## Buttons tab

**BUTTON-1. Size, color, border and font (2026-10-20).** On a new pad the buttons wear the fuller Ka0s
Default look (PLOOK-1, 2026-11-01), small white labels, 16-pixel icons. Pad → Buttons: Button width 160 → wider buttons; Button height 40 →
taller buttons, label and icon centered; Button height 0 → back to the automatic height; Button style Icon
only (Layout) → square buttons around the icons whatever the size says. Color → Background red at 50% →
every button's body; Use class color → your class color. Border thickness 2, color white → an edge around
every button, over the body, never hiding the icon or label; with Use the skin's border unticked, a LibSharedMedia border draws that art; 0 →
no edge. Font: untick Use the skin's font, another face, size 14, Outline, Font color yellow → the button labels only (the section
titles keep the Section header tab's font); a bigger font grows the automatic height. Defaults → the owner's
buttons again. In combat, `/qc set pad.button.width 150` → no error, "updates after combat", wider buttons at
combat end. (Amended by QC-05, 2026-10-29: the skinning rollout's Use the skin's font and border,
SKIN-6.) Result: Passed (owner, 2026-11-02).

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
Since item 015 (2026-10-24) Toggle Comms Pads is listed **first**, before Open Comms Dial 1 to 4, in
a section of its own (KEY-4).

**KEY-4 (SM-QC-KB1). A section of its own (item 015, 2026-10-24).** Options → Keybindings: scroll
past Blizzard's sections → a section titled **Ka0s Quick Comms** holds, in order, Toggle Comms Pads,
Open Comms Dial 1, 2, 3 and 4, with these labels; the AddOns section no longer lists them, and there
is no blank spacer row above them. A key bound before the update (for example Open Comms Dial 1 on G)
is still bound. Result: 2026-10-24, pass (the owner's run; client build not recorded).

**KEY-5 (SM-QC-KB2, SM-QC-RV3; rewritten 2026-10-24 for the one key button). General → Keybindings follows Options → Keybindings, both ways.** Settings → Ka0s
Quick Comms → General: the last tab is Keybindings; it opens on the intro line, the dial line, then
the five rows in the same order, each with one key button and Clear (no second key button), and
under them "Saved for: all characters". Bind Toggle Comms Pads to P on the tab → Options → Keybindings → Ka0s Quick Comms shows P
beside it. Bind Open Comms Dial 2 to H there, come back to the tab → H shows in its row without a
/reload. Tick Character Specific Keybindings → the tab's line reads "Saved for: this character only";
bind a key on the tab → it shows in the character set there, and the account set (on another
character) does not have it. In Options → Keybindings give Open Comms Dial 2 a second key, J, as well
as H → the tab's button reads "H +1" and its tooltip names H and J and says the others were set on
the game's Key Bindings page; Clear on that row → both keys are gone there too. The Defaults button's tooltip ends "Key bindings are not changed.";
Defaults and Reset all settings leave every key bound. Result: 2026-10-24, pass (the owner's run; client build not recorded).

**KEY-6 (SM-QC-KB3, SM-QC-RV3; rewritten 2026-10-24 for the one key button). The key works; Escape
cancels; combat refuses.** Bind Open Comms Dial 1 with the row's key button → the key opens dial 1;
bind Toggle Comms Pads → the key hides and shows the pads. Right-click a bound key button → that key
is removed and the line reads "Key removed.". Click the key button so it
reads "Press a key...", press Escape → the capture cancels, the button shows its key again and the
settings window stays open. Take a key another action holds (for example bind a dial to TAB) → the
key moves without a question and the line under the rows names the action that lost it. Enter
combat with the tab open → a capture in progress stops and the line reads "Key bindings can be
changed after combat."; click the key button or Clear in combat → nothing is bound or cleared, the same line.
No Lua error. Result: 2026-10-24, pass (the owner's run; client build not recorded).

## Settings layout

Item 020 (2026-10-24): rows moved, regrouped and relabeled, no setting changed. Checks above that
were written before it use the old names: Pad header is now Header, Section header is Section titles,
Wheel is Layout, Slice labels and Group labels are one Labels tab, the Groups and Dial Preview tabs
are What it sends and Ring map, Faded alpha is Faded opacity, Wedges per ring is Slices per ring,
Add a group is Add group, Unlock pads is Unlock all pads, and the editors' Enabled box is Enable this
group, pad or dial.

**LAYOUT-1 (SM-QC-LY). General (QUI-L01, L02, L-new2).** Settings → Ka0s Quick Comms → General →
Behavior → two headings, Sending (When you are solo | Spam guard (seconds), then Play a sound on send |
Note dropped callouts in chat) and Pads and dials (Put instance-specific groups first | Show the
LOCKDOWN tag, then Explain why groups show (tooltips)); each still writes what it did (tick Show the
LOCKDOWN tag off → no LOCKDOWN on a pad). Hover the header's Defaults → the same text as Master
controls' Reset all settings tooltip, ending "Key bindings are not changed." Result: 2026-10-24, pass (the owner's run; client build not recorded).

**LAYOUT-2 (SM-QC-LY). Groups (QUI-L03 to L08, L34, L-new3).** Groups → the band is one row: the
Group picker, New group, then Preview while editing, all level, and the strip starts at the same
height as on Pad and Dial. General → Name | Enable this group, the icon, Parent group alone, Duplicate group
| Delete group…, a gap, a gray line "Adds back the built-in groups and callouts you deleted. Changes
nothing you have.", then Restore built-in groups; no Inherit box here. When → Inherit when conditions
under the active-now line, grayed out for a group with no parent; on a child, untick it there → its
own drawers come live, tick it → "Uses <parent>'s conditions. Untick Inherit when conditions above
…". The fourth tab reads What it sends; the callout popup's heading reads What it sends. Hover
Defaults → it names the icon and the parent as kept. Result: 2026-10-24, pass (the owner's run; client build not recorded).

**LAYOUT-3 (SM-QC-LY). Pad (QUI-L07, L09 to L15, L18, L36, L-new1, L-new3).** Pad → the strip reads
General, Groups, Layout, Window, Header, Section titles, Buttons, Icons, and fits as before. General →
Enable this pad, Faded opacity, Unlock all pads (or Lock all pads; its tooltip names Lock frame on the
General page > Master controls). Groups → Add group above the list. Layout → Pad scale and Button
spacing. Buttons → Size, Font, Background (Background color), Border, Button glow, Shine. Icons → Icon
glow holds the glow offsets, with no Offset heading. Every swatch on Window, Header, Section titles
and Buttons reads Background color. Result: 2026-10-24, pass (the owner's run; client build not recorded).

**LAYOUT-4 (SM-QC-LY). Dial (QUI-L07, L08, L19, L21 to L29, L35, L-new3).** Dial → the strip reads
General, Groups, Layout, Slices, Hub, Paging, Labels, Icons, Ring map; note whether it fits one row at
your UI scale. General → Enable this dial, then the gray line pointing at the General page >
Keybindings, then Delete dial… (no key box). Layout → Slices per ring | Ring radius, Slice gap alone,
then Position: Open at, X | Y, Reset. Slices → one Colors heading, then Shine. Hub → Hub, Hub border,
Hub circle, Pointer. Paging → Page row (Distance below labels), Arrows, Page indicator, Indicator
border, Indicator background (Show indicator background | Background padding). Labels → Slice labels,
Group labels, then Tooltip; untick Show slice labels → only the slice labels' font grays. Icons → Size,
offset and crop: Icon size | Icon offset, then Zoom. Ring map lists the rings as Preview did. Result: 2026-10-24, pass (the owner's run; client build not recorded).

**LAYOUT-5 (SM-QC-LY). Nothing lost, nothing changed.** Before updating, note a few values you set
(a pad's Faded alpha, Section header height, a dial's slice gap, Tooltip side, Dot border, a group's
Inherit). After the update: each reads the same under its new name and place, the pads and dials
look as they did, `/qc list` shows every setting (the Behavior rows in their new order), and after a
`/reload` every value is still there. Each page's Defaults resets what it did before. Result: 2026-10-24, pass (the owner's run; client build not recorded).

**LAYOUT-6. The Position block (2026-11-01).** The block now comes from the options library (LibKa0s#59)
and should look as it did. Pad → Layout: one Position heading, X offset | Y offset as typed boxes, then
Reset this pad's position. Type 40 in X offset and press Enter → the pad moves; type *left* → a line says
a position is a number of pixels and the box goes back to 40; Reset puts the pad back and both boxes
follow. Drag the unlocked pad → the boxes follow. Dial → Layout: the same under Position, with Open at
first. Result:

## Frame layering

Item 030 (frame-layering, standard v2.88.0; `core/Constants.lua` `NS.Constants.LAYERS`).

**LAYER-1 (SM-QC-ZS1). A pad button's parts in order (QUI-Z02, Z03).** On a Comms Pad: Buttons →
Border thickness 3, color white, and Glow on; Icons → Border on and Glow Always. Add a callout whose
text starts with `/` so its button is refused → that button dims **whole**: its edge, the icon's
border and both glows are under the dim veil, not at full brightness over it. Press an armed button →
the send flash lights over the glows and the borders. The label and the padlock stay readable over
the thick border. The icon's border draws over the button's border where they meet; switch the pad to
Icon only → note whether the icon's border covers the inner half of the button glow (the analysis
expected it; say if it looks wrong). Hover a button → its tooltip; click it → it still sends (the
overlay takes no mouse). Result: 2026-10-24, pass (the owner's run; client build not recorded).

**LAYER-2 (SM-QC-ZS2). A dial wedge's parts in order (QUI-Z04).** On a Comms Dial with Icons → Border
on and Glow Always, open the dial on a ring holding a refused callout → its wedge's icon ring and glow
are under the dim veil; send from a wedge → the flash covers its icon glow; the labels and padlocks
read over the icon rings; the hub and pointer still draw over every wedge. Clicking a slice still
sends. Result: 2026-10-24, pass (the owner's run; client build not recorded).

**LAYER-3 (SM-QC-ZS3). The drag strip over a faded pad (QUI-Z11).** Comms Pad → Fade: out of combat,
Faded alpha 0.2; unlock the pads (`/qc unlock`) → the pad fades, its drag strip stays at full
opacity, and dragging it moves the pad; hover the pad → it comes back; lock → the strip hides.
Result: 2026-10-24, pass (the owner's run; client build not recorded).

**LAYER-4 (SM-QC-ZS4). Nothing else moved (QUI-Z01, Z06, Z09, Z10).** With Preview as… on: the
preview window sits over the preview dial and under the callout popup's dim; the icon browser opens
over the popup; its Wowhead link window opens over the browser; a delete confirm opened from the
popup shows over it and can be clicked. Open a dial
by its key, click outside it → it closes (with the settings window closed). No Lua error. Result: 2026-10-24, pass (the owner's run; client build not recorded).

**LAYER-5. The modal windows stay on screen and in order (2026-10-25, audit QC-21).** Drag the
callout popup to each screen edge → it stops at the edge; open the icon browser and do the same → it
stops too. Click the popup, then Choose icon… → the browser opens over the popup and still covers it.
Result: 2026-10-25, pass (the owner's run; client build not recorded).

**LAYER-6. The pad and the dial over other addons' windows (#14).** Open a bag addon, Details or another
meter, and a Ka0s window (for example another addon's settings), and drag a Comms Pad over them → the
pad draws on top of all three and its buttons click. Open a Comms Dial by its key over the same windows
→ the dial draws on top; clicking a slice sends. Open the debug console (`/qc debug`) under the pad →
say whether the pad over it reads as wrong. Result: Passed (owner, 2026-11-02).

**LAYER-7. QuickComms' own stack (#14).** Open the settings window with a pad over it → the pad draws
over the settings. With Preview as… on and dial 1 open: the preview window sits over the preview dial,
hub included; Edit a callout → its popup and dim cover the pad, the dial and the preview window; Choose
icon… → the browser opens over the popup; its Wowhead link window opens over the browser; open the popup's
dropdowns and the color picker → each opens over the popup and the browser; a delete confirm opened from
the popup shows over everything and can be clicked. Hover a pad button and a slice → the tooltip is over
both. No Lua error. Result: Passed (owner, 2026-11-02).

**LAYER-8. A click outside a key-opened dial (#14).** Open a dial by its key with a pad on screen. Click
the pad → the dial closes and the pad's button does not send; open the dial again with the settings
window up and click the settings → the dial closes. In combat, open it and click the world → it closes.
With a key-opened dial and Preview as… on, click the preview window → it takes the click. Result: Passed (owner, 2026-11-02).

**LAYER-9. The skin picker over a pad (#14).** Drag a Comms Pad to the upper middle of the screen, then
run `/qc skin` → the picker draws over the pad and its dropdown, buttons and close click. Close it, set
`skin.pickerSeen` off (`/qc set skin.pickerSeen false`) and `/reload` → the first-run picker is over the
pad too. Result: Passed (owner, 2026-11-02).

## Icons tab

**ICONS-1. Look.** Pad → Icons: Icon size reads 16 on a new pad (an icon-only button is 24
pixels square); Icon size 32 → the buttons grow taller around the bigger icons;
Zoom 0.1 → each icon's edge is cropped; Desaturate → gray; Icon opacity 50% → faint; Tint red → a
white glyph turns red and a colored glyph darker. Show border → the skin's icon border (Solid, 2
pixels, on Ka0s Default); untick Use the skin's border, thickness 3, color white → a square
edge over each icon. Dial → Icons: Show border → a round ring behind each wedge's icon; Icon size
20 → smaller icons, the wedges keep their size. Defaults on each page → the icons at their defaults again (16 on a pad, 32 on a dial). (Amended by QC-05, 2026-10-29: the skinning rollout's Use the skin's border, SKIN-6.) Result: pass (owner-marked 2026-10-30).

**ICONS-2. Glow styles.** (Amended by QC-67, 2026-11-01: with the glow off the picked style's knobs now show, grayed.) Pad → Icons, glow off → Offset sits right under Glow color, its two
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

**ICONS-4. Glows through LibKa0s-Glow-1.0 (2026-10-22).** The glows are now drawn by the library's
driver (LibKa0s#56); nothing should look different. Pad → Icons, Glow on: each style (Pixel border,
Auto cast sparkles, Button, Proc) × Always / On hover / After sending, on a pad and on a dial → each
looks as before; Proc's opening burst plays once, not on every rebuild. Pad → Buttons, button glow
on: each style circles the whole pad button and coexists with the icon glow on the same button. In
combat, hover a pad button and a dial wedge with On hover → the glow starts and stops, no Lua error,
no taint message. Result: 2026-10-23, pass (the owner's run; client build not recorded).

**ICONS-5. Sections a choice does not use (2026-11-01, LibKa0s#67).** Pad → Icons, glow off → the Pixel
border heading and its knobs show, grayed. Glow style Proc → Pixel border goes and Proc comes, grayed, on the
next frame, the scroll kept. Tick Glow → the knobs come alive in place. Pad → Buttons, Shine look Gloss fade →
no Bloom color rows and no gap where they were; Fluid glass → Bloom color A and B appear, live; None → they
go, and Shine strength and Shine tint gray. Dial → Slices the same, and Dial → Icons as the pad's.
`/qc list` still shows every knob and bloom. Result:

**ICONS-6. No native icon edge on the HUD (R4-ZOOM, smoke round 4).** Give a pad's callout and a dial's
callout a game icon (Choose icon… → Game icons, e.g. Bloodlust), set Pad → Icons and Dial → Icons Zoom to
0 and tick Show border. On **Ka0s Default** → each game icon sits inside its black edge with no rounded
dark rim and no lighter corner of Blizzard's own icon edge showing between them; untick Show border →
still no rim at the icon's edge. Zoom 0.05 → no change; Zoom 0.15 → the icon crops further. A glyph (the
default speech bubble) and a raid marker at Zoom 0 → whole, nothing clipped at their edges. Repeat under
Obsidian. Fail: a rounded or dark native edge inside any game icon's border on a pad or a dial.
Result:

**ICONS-7. Game icons in the windows and settings pages are framed (R5-ICON, smoke round 5, item 7).** On the
Skin tab untick **Ignore settings panel**. Open a group's callout popup and **Choose icon…** → Game icons:
every game icon in the grid sits inside a 1 px gray outline with no rounded dark rim or lighter corner of
Blizzard's own edge showing; click one → the footer preview is framed the same. Choose it → the popup's icon
chooser shows it framed. On the Groups page, a callout with a game icon → its row's icon and the Preview
table's icon are framed. Markers and Glyphs tabs, and a callout with the default speech bubble or a raid
marker → those draw whole, with no outline. Switch skins → the outline follows the skin's icon outline.
Tick **Ignore settings panel** again and reopen → the game icons stay cropped (no native rim), with no Ka0s
outline, as the library's own id lists. Fail: a native rim on any game icon, an outline on a glyph or a
marker, or an outline left behind on a row that no longer shows an icon.
Result:

## Icons

**ICON-1. Choosing an icon.** Groups → a group of yours → Callouts → a row's edit glyph → Choose
icon… → double-click the skull → the icon beside Choose icon… is the skull (the popup has no Icon
box); Save → the row and the button show the skull. Groups → a group of yours → General → no Icon text
box, an "Icon" label over the icon and Choose icon… → Glyphs → double-click a glyph → the group's
wedge on the Comms Dial shows it, and the General tab's icon follows. With that group selected,
`/qc set group.icon 136012` still sets it. Click the red clear glyph beside Choose icon… → the
General tab's icon is the question mark, the wedge shows no icon, and the clear glyph goes idle; in
the popup, a callout with an icon → clear glyph → the icon is the question mark, Save → the row and
the button show no icon. A built-in set's General tab ("Dungeon") has the same Icon row and
Choose icon…: a glyph chosen there shows on its wedge. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**ICON-2. The icon browser after the v1.75.0 re-vendor (2026-10-22, run item QC-RV, SM-QC-1).**
`/reload` → no Lua error. Groups → a group of yours → Callouts → a row's edit glyph → Choose icon… →
the icon browser lists all three sets (Open Iconic, Phosphor, Game-icons) and every glyph draws, in
each set and in a search's results. `CLAUDE.md` declares `LibKa0s icons: all (icon browser).`, so the
prune removed nothing; a blank cell means an icon went missing. Result: 2026-10-23, pass (the owner's run; client build not recorded).

**ICON-3. Library-drawn art after the v1.75.0 re-vendor (2026-10-22, run item QC-RV, SM-QC-2).** The
marks the library draws, and the addon's own, still draw: `/qc debug` → the console's close, copy and
clear marks; the icon browser's Wowhead link window (Game icons → Copy wowhead.com/icons) → its close; Groups → a group →
When → the id list's info mark; a pad's padlock (lock the pads) and a dial's page arrows and pointer.
A blank control is the failure: a pruned or undeclared icon resolves to a path and draws nothing.
Result: 2026-10-23, pass (the owner's run; client build not recorded).

**ICON-4. The callout popup and the icon browser over the preview dial (2026-10-23, run item QC-06,
SM-QC-9).** Open Settings → Groups → a group of yours: the edit preview shows the dial with its hub
(or Preview as → Dungeon). Callouts → New callout: the dial hub's yellow dot and pointer stay behind
the dialog, never over it; Edit callout on a row, the same. In the dialog, Choose icon…: the icon browser sits
above the dialog, and the settings window sits below both. With the browser open, its filter's
pull-out and the color swatch's picker draw over the browser. Preview as → a situation with the
preview window shown, then New callout: the dialog covers the preview window too, and stays over
it when `/qc preview arena` is typed with the dialog open. With the edit preview's dial shown on
the Groups page, a callout's or the group's remove glyph: the delete confirm draws over the dial's
hub; with the dialog open, `/qc resetall`: the reset confirm draws over the dialog and its dim, and
its Yes / No answer clicks.
Result: 2026-10-23, pass (the owner's run; client build not recorded).

**ICON-5. Test mode's numbered groups and the default icons (QC-02, 2026-10-30, Ka0sAddonsCommonTasks
`docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK/`, D-21; image-52, image-53).** `/qc test` → dial 1's first
ring shows four group wedges, Test group 1 to 4, wearing a numbered circle each, ① to ④, in cyan,
gold, purple and green, where they drew red question marks; open each → its callouts keep their
shipped glyphs, as before. Make a group of your own with no icon and put it on a dial → its wedge
draws a white folder; give it a callout with no icon → the callout's pad button and dial wedge draw
a white speech bubble, and so do its row on the Groups page's Callouts tab and the callout popup's
icon preview; the group's General tab icon preview shows the folder. Choose an icon, then clear it →
back to the folder or the bubble. Fail: a question mark anywhere while LibKa0s is loaded. Result: Owner reported pass, 2026-10-31.

## Art

The dial's own round art (crisp dial art, 2026-10-21): `media/textures/dial/dial-disc.tga` and the
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
round-ended and smooth; the page arrows' round plates are smooth at Arrow size 12 and 48. Icons →
Show border on, Use the skin's border unticked, Border size 4 → every wedge's round border is smooth
too. (Amended by QC-05, 2026-10-29: the skinning rollout's Use the skin's border, SKIN-6.) Result: pass (owner-marked 2026-10-30).

## Shine

The shine overlay (2026-10-21): Shine look on the Pad page's Buttons tab and the Dial page's Slices
tab, drawn from `media/textures/shine/` (a folder per look) (`tools/gen-shine-textures.py`).

**ART-2. Every texture loads from its folder (2026-10-25).** The art moved into `media/textures/dial/`
and `media/textures/shine/<look>/` (the rim edges in `shine/shared/`). After a full client restart (a
`/reload` does not pick up moved files): open a dial on its key with each Hub style, at 1, 4 and 12
slices, then set each of the seven Shine looks on the pad's buttons and on the dial's slices → every
disc, ring, slice and shine draws as before; a green or blank square is the failure. Result: owed (new 2026-10-25).

**SHINE-1. Each look on a pad (2026-10-21; whole button, 2026-10-21).** On a new pad the buttons
have no shine (Shine look None; Shine strength and Shine tint grayed out, no Bloom color rows). Pad → Buttons → Shine look Gloss cap, Gloss fade, Glass orb, Frosted glass, Fluid glass, Bevel and Rim light
in turn, each at the Icons tab's Icon size 16, 24 and 40 → each look covers the whole button, its
plate, icon and label, edge to edge, and matches its tile in
`docs/superpowers/specs/2026-10-21-shine-overlay/render-pad.png`: Gloss cap a bright band over the top
half with rounded ends; Gloss fade (2026-10-21, listed right after Gloss cap) one smooth gradient,
brightest at the top edge and fading to nothing toward the bottom, with no cap edge; Glass orb a soft band of light across the upper third, edges darkening all
round and darkest at the bottom, with no spot or dot anywhere (2026-10-21), plainly different from
None on the wide buttons; Frosted glass a milky wash, milkier toward the edges, a crisp bright rim
(brightest along the top) and a soft streak of light just under the top edge; Fluid glass a haze at the
top and a pink-to-mint bloom at the bottom; Bevel a light top and left edge and a dark bottom and right
one; Rim light an edge glow and a short top highlight. On the wide buttons the edges stay as thin as on
a square one (nothing stretched at the ends); Layout → Button style Icon only → the square buttons
take the art whole. The padlock, the label, the send flash and the hover still read over it. Bloom color A and B
show only under Fluid glass; set them to red and blue → its two blooms change color. Shine
strength (with Use the skin's shine unticked; ticked, its row is gray and the skin's 55 draws) 0 → no
shine; 100 → the strongest. Shine tint yellow → the light turns yellow, the shade stays
dark; Use class color → your class color. Fluid glass, then Gloss cap, then None → no bloom or shine is
left behind. Layout → Button style Label only → the buttons keep their shine (it covers the plate, not
the icon). Result: Passed (owner, 2026-11-02).

**SHINE-2. Each look on a dial (2026-10-21).** Open a dial. Dial → Slices → Shine look each of the seven
in turn, at Wheel → wedges per ring 4, 8 and 12, Slice gap 0 and 8, and Ring radius 100 and 180 → every
slice takes the look inside its own edges, moving with its slice when the gap opens, and the icons and
labels sit over it, uncovered. Each look matches its tile in
`docs/superpowers/specs/2026-10-21-shine-overlay/render-dial-4.png`, `-8.png` and `-12.png` (the
addon's own paint, composited offline): Gloss cap a bright band on the outer half of each slice, its
inner edge one curve around the hub, dark hairlines between slices; Gloss fade (2026-10-21) the same
gloss with no falloff edge, nothing at each slice's inner end rising smoothly to its brightest at the
rim, with the same dark hairlines; Glass orb a bead per slice, lit
softly in its middle and dark toward its corners, with dark hairlines between slices and no highlight
spot or dot on any slice (2026-10-21); Frosted glass a milky wash, milkier toward the rim, a crisp
bright line along the outer arc, faint light lines between slices and a soft line of light just inside
each slice's left spoke; Fluid glass a clean iridescent edge, each slice pink at the middle of its
outer arc and mint toward its spokes, fading out well before the hub, with a thin light rim, no wide
mint band and no wash over the slices' middles (2026-10-21); Bevel every slice raised the same way
(2026-10-21): a light outer arc and left spoke, a dark right spoke and inner end, and a gentle shade
from light at the outer left to dark at the inner right, turning with its slice (no single light
direction for the dial); Rim light a soft glow just inside the rim and thin light lines between
slices. Every masked look (Gloss cap, Gloss fade, Glass orb, Frosted glass, Fluid glass, Rim light) is cut cleanly
at each slice's edges at every slice place, with no square corner, seam or bleed past the slice (the
owner's first screenshots showed the sector mask cutting cleanly at 8 slices); Bevel is slice-shaped
art of its own, with no mask. Turn a page on a paged ring and switch 8 to 4 → the
slices no longer used show no shine. Hover a slice → its highlight still shows. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**SHINE-3. A pad and a dial keep their own (2026-10-21).** Set the pad's Shine look to Glass orb and
the dial's to Rim light → each shows its own; set the pad's to None → the dial keeps Rim light.
`/reload` → both kept. `/qc diagnostics` → the pad's line reads `p1 button shine=none 85` and the
dial's slices line ends `shine=rim 85`. Then set the pad back to Glass orb and the dial to None → the
pad keeps Glass orb and the dial shows no shine. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**SHINE-4. The shine re-fits its button (2026-10-25, F-001).** With Gloss fade on, change Button
width, then Button height, then Layout style to icon only → each time the shine re-fits the button:
its caps half the button's height wide, and no middle on a square button. A rebuild that changes
neither (spacing) leaves it drawn as it was. Result: 2026-10-25, pass (the owner's run; client build not recorded).

## Battlegrounds

**BG-1. Node rings (rewritten 2026-10-25: no compass pinning).** In each node battleground you play
(Arathi Basin, Eye of the Storm, Battle for Gilneas, Deepwind Gorge, Isle of Conquest, Wintergrasp,
Ashran), with Slices per ring on Auto, open the dial and click the battleground's set on the ring of
groups → one slice per entry and no empty slice: a wedge drawn as the battleground itself at N (it
opens its map-wide callouts), then the nodes A–Z clockwise (Arathi Basin six slices, Battle for
Gilneas four, Ashran six), and Deepwind Gorge shows five nodes (owner ruling R2). Lumber Mill, then
INC is two clicks from the set's ring. An empty slice, or a node out of A–Z order, is filed with this
check's ID and its battleground. Result: 2026-10-25, pass (the owner's run; client build not recorded).

**BG-2. Battleground instance ids.** In each battleground you play: `/qc diagnostics` → the
`situation` section's instanceID is one its set lists (`defaults/BuiltIns_Battlegrounds.lua`), and
the pad and the dial show that set. Write each id into the "Battleground instance IDs seen" table of
`docs/brainstorm/go-no-go/round-4-build-checks.md`. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**BG-3. Alterac Valley's objectives.** In Alterac Valley, on a default pad: the Alterac Valley
section (its four map-wide callouts) is followed by 19 objective sections, two to a row, north to
south: Vanndar, DB North Bunker, Stormpike GY, Aid Station, DB South Bunker, Icewing Bunker,
Stonehearth GY, Balinda, Stonehearth Bunker, Snowfall GY, Iceblood GY, Galvangar, Iceblood Tower,
Tower Point, Frostwolf GY, FW West Tower, FW East Tower, Relief Hut, Drek'Thar (the last on a row
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
faction. On the dial the set's ring has the Isle of Conquest wedge at N, then its seven groups A–Z,
Our base and Enemy base among them. Result: 2026-10-25, pass (the owner's run; client build not recorded).

**BG-5. A flag map.** In Warsong Gulch or Twin Peaks: the pad shows the set's map-wide EFC callouts,
then Our flag, Enemy flag, Our FC and Midfield (Bridge in Twin Peaks), each its own section; on the
dial (click the set on the ring of groups) the set's ring has its own wedge on N and the four groups
after it, A–Z, five slices in all. Send "INC flag room" → `INC our flag room`; "We have it" → `We have
their flag`. The same holds for Ashran, Deephaul Ravine and Seething Shore. Result: 2026-10-25, pass (the owner's run; client build not recorded).

**BG-6. A profile from before the objective groups.** On a profile saved before this build (or a
copy of one): log in → `/qc diagnostics` shows schema 7; Alterac Valley's set holds its 19 objectives
and opens into its ring on the dial, Isle of Conquest's holds Our base and Enemy base after its
nodes, and every callout you had edited still reads as you left it. Delete one objective, `/reload`
→ it stays deleted. A set you had deleted before the update is still gone. Result: 2026-10-21, pass (the owner's run; client build not recorded).

**BG-7. The four node buttons (bg buttons).** On a reset profile, in Arathi Basin, Eye of the Storm,
Battle for Gilneas, Deepwind Gorge or Isle of Conquest: every node's section holds Attack (crimson crossed
swords), Defend (cyan shield), INC (orange charge) and Clear (green check), as Wintergrasp's workshops
do; Lumber Mill's send "Attack Lumber Mill", "Defend Lumber Mill", "INC Lumber Mill", "Lumber Mill is
clear". Eye of the Storm's Flag reads Take flag, Defend flag, INC, Clear ("Take the flag", "The flag is
clear"). Each set's own map-wide callouts (Hold our bases, Zerg next…) are unchanged. Result: 2026-10-25, pass (the owner's run; client build not recorded).

**BG-8. Silvershard Mines and Temple of Kotmogu (bg buttons).** In Silvershard Mines: after the set's
own Escort, Contest and Cart help, the pad shows Lava track, Water track and North track (Contest,
Escort, INC, Clear: "Contest their cart on the lava track", "Escort our cart on the lava track", "INC
on the lava track", "Clear on the lava track") and Switches (Flip switch, Hold switch, INC, Clear).
Check the track names against what players call them in your games; a name that reads wrong is filed
with this check's ID. In Temple of Kotmogu: after Orb heals, Kill orb and Go mid, the pad shows Orange
orb, Blue orb, Green orb and Purple orb, each drawn in its color (Take orb, Peel, Kill carrier, Heals:
"Take the blue orb", "Peel for our blue orb carrier", "Kill their blue orb carrier <target>", "Our
blue orb carrier needs heals") and Center (Go center, Hold center, INC, Clear). On the dial both open
on the set's ring, the groups A–Z after the set's own wedge, one slice each.
Result: 2026-10-25, pass (the owner's run; client build not recorded).

**BG-9. Faction and location colors (2026-10-25).** On a reset profile (the colors are not migrated):
Alterac Valley's Vanndar, Balinda, both Dun Baldar bunkers, Icewing and Stonehearth Bunker, Stormpike
and Stonehearth GY and the Aid Station are Alliance blue (#2AA2FF); Drek'Thar, Galvangar, Iceblood
Tower, Tower Point, both Frostwolf towers, Iceblood and Frostwolf GY and the Relief Hut are Horde red
(#FF4040); Snowfall GY is gold (#FFD100). Eye of the Storm: Draenei Ruins and Mage Tower blue (Alliance-owned), Blood Elf Tower and Fel Reaver
Ruins red (Horde-owned). Ashran's Road of Glory is gold. Arathi Basin's Stables are
brown, Deepwind Gorge's and Isle of Conquest's Quarry stone gray, Isle of Conquest's Hangar sky blue,
Warsong Gulch's Midfield brown and Twin Peaks' Bridge gray; no battleground icon is white. Under any
location, Attack is crimson and Defend cyan, on the pad and on the dial. Result: 2026-10-25, pass (the owner's run; client build not recorded).

## Instance ids

**IDS-1. The Midnight dungeons and raids.** In each of the eight dungeons and three raids you visit
(Windrunner Spire 2805, Magisters' Terrace 2811, Nexus-Point Xenas 2915, Maisara Caverns 2874, and
the four returning dungeons; The Voidspire 2912, The Dreamrift 2939, March on Quel'Danas 2913):
`/qc diagnostics` → the instanceID matches; a group's When → the Instance drawer → Add the instance
you are in adds that id. Groups → Preview as lists an M+ entry for each of the eight dungeons (since 2026-10-25, owner). On a Devourer
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
- **The pads' fonts** (the Header and Section titles tabs', the Buttons tab's labels, the dial's
  labels): the default face is the skin's HUD font while Use the skin's font is ticked and Ignore
  fonts is not (Ka0s Default's Prototype since LibKa0s v1.82.0; since LibKa0s v1.81.0 each other skin its own face,
  SKIN-5; WoW Default Ka0s Ubuntu since R3-FRIZ (Ka0s Friz Quadrata TT from LibKa0s v1.83.0); LibKa0s registers a face only for the locales it can draw), else
  the player's pick (LibSharedMedia's "Friz Quadrata TT" by default), which
  LibSharedMedia does not register on koKR, zhCN or zhTW; a face the machine does not have draws
  `STANDARD_TEXT_FONT` (`Pad_Render.LabelFont`, `test_pad_render`). (Amended by QC-05, 2026-10-29, the
  skinning rollout; by QC-02, 2026-10-30, the library follow-ups; by QC-01, 2026-10-30, LibKa0s v1.82.0's faces.)
- **Printed**: every chat and report line is English through `NS.L`
  (`test_slash`, `test_diagnostics`).

On a deDE or frFR client: `/reload`, run `/qc help` and `/qc diagnostics`; open the Groups page's When
on an instance and a spec; make a callout with `{spec}` → no Lua
error, no stray `%s` or `%d` in any line, the When's names in the client's language with the ids
unchanged, and the pad's labels drawn in a font (on koKR, zhCN or zhTW, the client's own). The failure
looks like a raw format token in chat, a missing label, or a When that stops matching after a locale
switch. **Owed**: the enumeration above is covered headlessly, but the names and the font fallback come
from the client, so this check needs a non-English client pass. Result: pass (owner-marked 2026-10-30). Owner reported pass, 2026-10-31.

## Skins

The skinning rollout's checks (QC-RV to QC-05, Ka0sAddonsCommonTasks `docs/2026-10-29-SKINNING_ROLLOUT/`;
O2, O3 and X3 to X10 below are its rulings, D1 to D11 its Quick Comms calls in `DECISIONS.md`). The
seam is `core/SkinSetup.lua`, the HUD's faces and border styles `modules/Pad_Render.lua` (`FontKey`,
`BorderKey`, `Chrome`) and `modules/IconStyle.lua`, the one-time reset schema step 10
(`modules/Library_Migrate.lua` `MigrateFollowSkin`); the Skin tab, the picker and the EllesmereUI
provider are the library's. See [ARCHITECTURE.md → Skins](ARCHITECTURE.md#skins). Start each check
from a **fresh client start** after updating (the skins' font and texture files are new, and the client
reads new files only at start), and pick skins on Settings → Ka0s Quick Comms → General → **Skin**.
Every check also fails on a Lua error or a taint warning.

**SKIN-1. The one-time reset under Ka0s Default (O2, X5, D11).** Before updating, on a profile give a
pad's Header, Section titles and Buttons tabs their own face (Morpheus, say), the Window tab and the
Header a LibSharedMedia border (Blizzard Tooltip, thickness 3), turn on the pad's Icons border, give a
dial's Slice labels and Group labels their own face, and set a few colors; note them, and do the same
on a second, inactive profile. Update and log in on the first → every label on the pad and the dial is
in **Prototype** (the skin's HUD font since LibKa0s v1.82.0) in place of the face you picked, each picked border art is
**None**, the flat edge at the thickness you set, and the icon border is the skin's (Solid, 1 pixel, 2 until LibKa0s v1.85.0's R3-FIX):
the skin governs that border's thickness too, so an icon border you had at 3 pixels is now 1. Every
other color, font size, flag, shadow, height and thickness is as you noted. Each Font block shows *Use
the skin's font* ticked and each Border block *Use the skin's border* ticked, their pickers grayed out
and showing the skin's choice. The wider face can widen a pad and move where a label is cut or where a
dial's label ring sits (D11). Untick each box → your old pick comes back at once. `/reload` → still
unticked and still yours: the reset ran once. Switch to the second profile → it was reset the same way,
its picks kept. This is the expected change, not a regression. Fail: a color, size or flag that
moved, a pick lost after unticking, or the boxes ticked again after the reload. (Amended by QC-01, 2026-10-30, LibKa0s v1.82.0's faces.) Re-opened by R3-FIX: the skin's icon border is 1 pixel. Result: not run

**SKIN-2. A new pad, dial or profile follows the skin (X3).** Pad → New pad, Dial → New dial, and
Profiles → a new profile → their Font and Border blocks show the *Use the skin's ...* boxes ticked, and
the labels are Prototype on Ka0s Default. Untick one on a pad, then the page's **Defaults** →
it is ticked again. (Amended by QC-01, 2026-10-30, LibKa0s v1.82.0's faces.) Result: pass (owner-marked 2026-10-30). Owner reported pass, 2026-10-31.

**SKIN-3. Ka0s Default elsewhere looks as before.** On **Ka0s Default** with **Ignore settings panel**
on (the default): the pads' and dials' colors (the gold padlock, the dark veils over a refused or
cooling button, the gold hover wash, the send flashes, the red LOCKDOWN tag and the gray stale hint,
the green PREVIEW and TEST MODE marks, a dimmed page arrow at an end), every settings page (its colored
lines included), the debug console's and the perf panel's colors, the Copy window, the drag strip and
its tooltip (gold title, white body), the reorder lists, the minimap button and its tooltip → each
looks as before this update. These changes are expected: the **Preview as** window's title and
close mark sit in a 30-pixel top bar across the window, the title in the skin's title font (Prototype,
larger) instead of Blizzard's (D9); the icon browser's scroll bar is a flat knob in a dark corridor
instead of Blizzard's knob over a black track (D3); the first-run skin picker is new (SKIN-17); since
LibKa0s v1.81.0 (R-2) the callout popup and the icon browser wear the **Ka0s window** (dark fill and
edge, the title in the skin's title color and face, the skin's close X; the dim behind unchanged),
no longer Blizzard's settings window (SKIN-8), and the icon browser's count, status, hint and
selected-icon name draw **Prototype** inside it (R-2; **Ignore fonts** gives Blizzard's font back); and
the library's own strings in the skin's face
(D-13) draw **Prototype** where they drew Blizzard's font: the debug console's title-bar labels, the
perf panel's step and command columns, the drag strip's label and the Preview as window's dropdown
menu rows. Fail: any other changed color, edge, face or spacing outside the pads' and dials'
faces and border styles (SKIN-1). (Amended by QC-02, 2026-10-30, the library follow-ups; by QC-01, 2026-10-30, LibKa0s v1.82.0's faces.) Result: pass (owner-marked 2026-10-30). Owner reported pass, 2026-10-31.

**SKIN-4. The Skin tab.** General → the strip reads Master controls, Behavior, **Skin**, Keybindings.
Skin → **Skin source** (*Ka0s skins* on; *EllesmereUI* disabled with a line saying why unless
EllesmereUI can skin this addon), the nine skins with their swatches under a **Look** heading,
**Font and texture** (**Font** and **Texture**, both *Skin's default* in a new profile), the Scope
(**Ignore settings panel** ticked, **Ignore fonts** unticked), **Copy to every Ka0s addon…** (live with
another Ka0s addon that uses skins loaded; alone, disabled with its hint) and the note on what skins
change. Pick **Obsidian** → no reload; `/qc get skin.skin` prints `obsidian`. (Amended by QC-F01, 2026-10-31: *Skin's default*.) Result: Owner reported pass, 2026-10-31.

**SKIN-5. Every skin on the pads and dials, live.** With a pad on screen (`/qc test` fills it) and a
dial open, pick each skin in turn: Obsidian, Azeroth, Glass, High Contrast, Ember, WoW Default, WoW
Midnight, WoW Forever, then Ka0s Default again → with **no reload** the labels redraw in the skin's HUD
face, each skin its own since LibKa0s v1.81.0 (R-4): Obsidian Expressway, Azeroth Open Sans Semibold,
Glass Avant Garde, High Contrast Doris PP, Ember Emblem, WoW Default Ka0s Ubuntu, WoW
Midnight Segoe UI Semibold, WoW Forever Fira Sans SemiBold, Ka0s Default Prototype (the faces since LibKa0s v1.83.0, D-06);
a followed border takes the skin's border style, and the padlock, the veils, the hover wash, the
flashes, the LOCKDOWN and stale tags, the PREVIEW and TEST MODE marks and the page arrows take the
skin's colors, and so does every color with its *Use the skin's ...* box ticked (FSKIN-2, FSKIN-3); a
class color stays yours. Fail: a
pad or dial that keeps the previous skin until `/reload`, a class color that changed, or a label
cut where it was not before on the same face. (Amended by QC-02, 2026-10-30: a HUD face per skin,
R-4; by QC-01, 2026-10-30, LibKa0s v1.82.0's faces; by QC-F01, 2026-10-31, LibKa0s v1.83.0's faces; by FS-QC-REC, 2026-11-01, the full skin; by R3-FRIZ, 2026-11-02, WoW Default's Ka0s Ubuntu.) Result: owed (expected result changed).

**SKIN-6. The *Use the skin's ...* boxes.** On a non-default skin, Pad → Header: untick **Use the
skin's font** → *Font* comes alive with your pick and the header redraws in it; tick → the skin's face
again, *Font* grayed showing it. **Use the skin's border**: under a skin with no border of its own
(Obsidian) *Border style* and its thickness stay live and draw your pick, ticked or not; under
**High Contrast**, Azeroth, WoW Default and WoW Midnight, ticked, both gray and the skin's border draws
(FSKIN-12); the same boxes on Section titles and Buttons, the border box on
Window, and on the Dial's Labels tab both font blocks' boxes. Pad → Icons and Dial → Icons: with **Show border** off, *Use the skin's
border* is grayed; with it on and the box ticked, *Border style* and *Border thickness* are grayed and
the edge is the skin's icon border; untick → yours. Switch skins with a box unticked → that pick is
kept. (Amended by FS-QC-GATE, 2026-11-01, a skin's None defers.) Result: Passed (owner, 2026-11-02).

**SKIN-7. The Preview as window (D8, D9).** Pick a situation in **Preview as…** under each skin →
the window wears the skin: its fill, edge and top bar, the title and the close mark centered in the
bar; **End preview** reads in the step panels' colors (light gray at rest, gold on hover, gray while
the window is locked over the edit preview, PREVIEW-11), and its tooltip lines are readable. Switch
the skin with the window open → it repaints with no reload. Result: pass (owner-marked 2026-10-30).

**SKIN-8. The callout popup and the icon browser (X10, D2, D3; rewritten by QC-02, 2026-10-30).**
Open a callout (EDIT-9), then Choose icon… → under **Ka0s Default** both wear the **Ka0s window**: the
template's background and border faded under Ka0s Default's dark fill and edge, the title "Ka0s Quick
Comms" in the skin's title color and face, the skin's close X (LibKa0s v1.81.0 retired the stock look,
R-2; Ka0sAddonsCommonTasks D-06). Pick **WoW Default** → both are Blizzard's settings window. Pick
**Azeroth** with both closed and open them again, then switch skins with them open → the window's
fill, edge, title and close X are the skin's, the page's controls follow the skin when **Ignore
settings panel** is off, the dim behind takes the skin's cover, and in the browser the selected cell,
the scroll bar and its corridor, the hint box, the search glyphs, the count, name and status lines
and the footer note take the skin's colors and its body font. With **Ignore settings panel** on (the
default) the popup's page stays stock inside the skinned window: its controls, its red refused-field
line (EDIT-9) and its token tooltip's colors (EDIT-18) keep Ka0s Default's under every skin; untick it
→ they follow the skin with the rest of the page (D-03). Back to **Ka0s Default** → the Ka0s window
again, with no reload. Fail: Blizzard's settings window under Ka0s Default, the template's art showing through a
skinned window, or a part on the old colors. Result: pass (owner-marked 2026-10-30).

**SKIN-9. The settings pages wear the skin when asked.** On a non-default skin, untick **Ignore settings
panel** → General, Groups (the When drawers, the Callouts rows, the Reuse dropdown, What it sends), Pad,
Dial and Profiles repaint in the skin; the colored lines (the gray hints, the When drawer's green
*Active now.* and red *Not active now:*, an inheriting group's line, the Reuse dropdown's callout name
and preview) take the skin's colors; under **Ka0s Default** they are the same colors as before. Open
another addon's settings pages and flip back and forth a few times → the other addon's pages stay stock
every time. Tick **Ignore settings panel** → this addon's pages are stock again, their colored lines
back on Ka0s Default's colors (the gray hints, the green and red When lines, the muted gold Reuse group
part, the gold table headings: a stock page never carries the skin's colors, D-03), and the Pad →
Groups and Dial → Groups reorder lists stock too (their ghost and drop line); the pads, dials,
windows, the callout popup and the icon browser keep the skin. (Amended by QC-02, 2026-10-30, the
library follow-ups.) Result: pass (owner-marked 2026-10-30).

**SKIN-10. The tool windows follow the skin.** On a non-default skin (Azeroth reads clearest), open
`/qc debug` and its **Copy** window, `/qc perf`, the icon browser's Wowhead address window (Game icons
→ the hint), `/qc unlock` for the drag strip (its label, and its tooltip's title and body in the
skin's tooltip colors, R-7), and, with **Ignore settings panel** off, a Pad → Groups reorder list
(under the default Scope it stays stock, a settings page's widget: SKIN-9) → each wears the skin, the
resize grip of the console, its Copy window and the perf panel included. Tick **Ignore fonts** → the
console's title-bar labels, the perf panel's columns and the drag strip's label go back to Blizzard's
face. Switch back to **Ka0s Default** with the console open → it recolors with no reload, its labels in
Prototype (SKIN-3). (Amended by QC-02, 2026-10-30, the library follow-ups; by QC-01, 2026-10-30, LibKa0s v1.82.0's faces.) Result: pass (owner-marked 2026-10-30). Owner reported pass, 2026-10-31.

**SKIN-11. The Font and texture overrides.** Skin → **Font** → a clearly different face → with no
reload every pad and dial label whose *Use the skin's font* is ticked takes it (unless **Ignore
fonts** is on, SKIN-12), a block with the box unticked keeps its own pick, and the windows' and the
settings pages' text takes it too; the debug
console keeps its monospace face. Switch skin → the override stays. **Texture** → any status bar →
a pad button whose *Use the skin's texture* is ticked takes it; the dial draws no bars. Set both back to *Skin's default* → the
skin's again. Open **Font** and **Texture** → every row draws in its own face or beside its bar, *Skin's default (…)* first (LibKa0s v1.83.0, D-08). (Amended by QC-F01, 2026-10-31.) Result: Passed (owner, 2026-11-02).

**SKIN-12. Ignore fonts (rewritten by QC-02, 2026-10-30).** On a non-default skin with **Ignore
settings panel** off, a pad on screen (`/qc test`) and a dial open, give a pad's Buttons tab a face of
its own (Morpheus, say) with *Use the skin's font* still ticked, then tick **Ignore fonts** → with no
reload the windows' and the settings pages' text goes back to the game's face, its colors kept, and
**the HUD too** (LibKa0s v1.81.0, R-1): every pad and dial label whose *Use the skin's font* is ticked
draws its own stored face (Morpheus on the buttons, Ka0s Prototype where you never picked one), its
colors, size, flags and shadow unchanged, and the box stays ticked; the Font picker beside it, still
grayed, previews that stored face. A Font override (SKIN-11) does not reach the HUD while Ignore fonts
is on. Untick → the skin's face returns on the windows, the pages and every following HUD label,
live. In combat the pads and dials redraw at combat end. Fail: a following HUD label left on the
skin's face while Ignore fonts is on, or a box that unticked itself. Result: Passed (owner, 2026-11-02).

**SKIN-13. EllesmereUI on.** With EllesmereUI and EllesmereUI Blizzard Skin loaded, its third-party
skinning on and Quick Comms on in its Third-Party Addons list → Skin → **Skin source** offers
**EllesmereUI**; choosing it repaints live: the callout popup and the icon browser wear EllesmereUI's
shell, border and close X as the settings window behind them does (what EDIT-13 checked before the
rollout, through Quick Comms' own bridge, now retired: D1), and the Preview as window, the console and
the perf panel wear it too; the pads' and dials' faces and border styles come from EllesmereUI's look
while their boxes are ticked, and each color with its own box ticked follows it too. `/qc diagnostics` → the integrations line reads
`skin: source=eui skin=… ellesmereui: ok=true painted=true refused=nil failing=none`. Result: Passed (owner, 2026-11-02).

**SKIN-14. EllesmereUI off.** Turn Quick Comms off in EllesmereUI's Third-Party Addons list (or disable
EllesmereUI) and `/reload` → on the Skin tab the EllesmereUI choice is disabled, the failing condition
and its fix are listed, Quick Comms wears its Ka0s skin (the popup is the Ka0s window under Ka0s
Default, R-2), and `/qc diagnostics` names the failing condition after `failing=`. (Amended by QC-02,
2026-10-30.) Result: pass (owner-marked 2026-10-30).

**SKIN-15. Back from EllesmereUI asks for a reload.** With EllesmereUI as the source, pick **Ka0s
skins** → a reload is offered; after the reload the Ka0s skin shows on the pads, the dials and every
window. Result: pass (owner-marked 2026-10-30).

**SKIN-16. Profiles and combat.** Give two profiles different skins, switch between them on the
Profiles page and with `/qc profile <name>`, then reset one → the pads, dials and windows follow the
profile each time with no reload. In combat (a target dummy), `/qc set skin.skin azeroth` → no Lua
error and no taint warning; the windows repaint at once, and the pads and dials at combat end, with
the stale hint meanwhile (known-limitations). Result: pass (owner-marked 2026-10-30).

**SKIN-17. The first-run skin picker (O3, X6; rewritten by QC-02, 2026-10-30).** For a character that
never ran this build, log in → about two seconds after the world loads a small window titled **Choose
a skin** opens (LibKa0s v1.81.0, R-11), with **Ka0s Quick Comms** on its own line above the dropdown,
whole, never cut off (the window widens to fit it): a dropdown showing the skin worn now, an **eye**
button, a gear button, **Apply** and a close mark. It never opens while the addon is switched off, and
in combat it waits until combat ends. Create a new profile → it opens again; close it, reset the
profile → it opens again. Fail: no eye, a title other than "Choose a skin", an addon name missing or
cut off, a picker on a profile that already closed it, or one while the addon is off. Result: pass (owner-marked 2026-10-30).

**SKIN-18. The picker's eye, preview and Apply.** On a fresh profile, press the eye → test mode turns
on: every pad shows its placeholders and dial 1 opens, with the picker above them. Pick **Obsidian** →
the pads, the dial and the windows repaint in Obsidian with no reload and the picker stays open; `/qc
get skin.skin` still prints the old skin. Press **Apply** → the picker closes, Obsidian stays, the
Skin tab shows it and `/qc get skin.skin` prints `obsidian`. `/reload` → still Obsidian, and no picker.
In combat the eye prints test mode's refusal and changes nothing. Result: pass (owner-marked 2026-10-30).

**SKIN-19. Closing the picker puts the old skin back.** On a fresh profile on Ka0s Default, preview
**Obsidian**, then close the picker with its close mark → Ka0s Default again, nothing saved, and the
picker does not come back on that profile after a `/reload`. Repeat on another fresh profile with
**Escape** → the same. Result: pass (owner-marked 2026-10-30).

**SKIN-20. The picker's gear.** On a fresh profile, preview **Azeroth** and press the gear → the
settings open on **General** with its **Skin** tab selected, showing Azeroth, and the picker closes;
`/reload` → still Azeroth. Result: pass (owner-marked 2026-10-30).

**SKIN-21. The picker, the switch and a profile event.** With the picker open on a previewed skin,
`/qc disable` → the picker closes and the stored skin is back; `/qc enable`, `/reload` → the picker
opens again, because it was never closed. Give a second profile **Azeroth** and close its picker; on a
fresh profile on Ka0s Default, preview **Obsidian**, then switch to the Azeroth profile → the picker
closes and the addon wears **Azeroth**; switch back → Ka0s Default, and the picker opens there again.
Result: pass (owner-marked 2026-10-30).

**SKIN-22. One picker at a time across Ka0s addons.** With a second Ka0s addon that uses skins, both on
fresh profiles, `/reload` → only one picker opens; close it → the other addon's opens at once. Reset
both and `/reload` → on the first picker, **Apply to all Ka0s addons** is shown; press it after
previewing **Azeroth** → both addons wear Azeroth, no second picker opens, and `/reload` brings
neither back. Result: pass (owner-marked 2026-10-30).

**SKIN-23. The CLI and the degraded install.** `/qc get skin.source` → `ka0s`; `/qc set skin.skin
nope` → refused with the allowed values; `/qc set skin.skin glass` → the pads and windows repaint at
once; `/qc set skin.skin ka0s` → back. `/qc get pad.header.fontFromSkin` → `true`. Then rename
`libs\LibKa0s` aside and `/reload` (DEGRADED-1) → no Lua error and no picker; rename it back and
`/reload`. Result: pass (owner-marked 2026-10-30).

**SKIN-24. The Font outline (LibKa0s v1.82.0, Ka0sAddonsCommonTasks `docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK/`,
D-06).** On a fresh client start, General → **Skin** → Font and texture shows **Font outline** under
**Reset font** and **Reset texture**, set to **HUD text only** (the default since LibKa0s v1.83.0, D-10); `/qc get skin.outline` → `hud`. `/qc test`
→ every pad label, section title, header, dial slice label and ring title is outlined, and the windows'
text (the callout popup, the icon browser, the Preview window) is not. Pick **All text** → the pads and
the dial stay outlined and the windows' text takes the outline, and so does the settings window's where
the skin paints it. `/reload` → still All text: a pick made on this release persists. (All text picked on the
v1.82.0 branch build does not carry over: it was the default there, so AceDB stripped it at logout, and that
profile opens on HUD text only.) Pick **Off** → the pads and the dial lose theirs too, with no reload. `/reload` → still Off.
Tick **Ignore fonts** → the Font outline is grayed out and the HUD is outlined again, as it was before
this release. `/qc set skin.outline thick` → refused with the allowed values. Switch to another profile
→ it wears its own Font outline (HUD text only on a new one). Fail: a mode that changes nothing on screen,
a mode lost after the reload, or a Lua error. (Amended by QC-F01 and its review, 2026-10-31.) Result: Owner reported pass, 2026-10-31.

**SKIN-25. From skin font flags (D-07, Addendum 01).** Before updating, on a profile set one pad's
Buttons tab Font flags to **Thick outline** and leave its Header and Section titles on the shipped
Outline; note a dial's Slice labels flags (Outline by default). Update and log in → Header, Section
titles and the dial's Slice labels and Group labels read Font flags **From skin**, the first entry of
the list; the Buttons tab keeps **Thick outline**. With the Font outline on Off, the From skin blocks
lose their outline and the Thick outline buttons keep theirs. Pick **Outline** on the Header → it
stays Outline after `/reload` and under Off (a picked flag wins). A new pad and a new dial start on
From skin. Fail: a picked flag moved to From skin, From skin missing from a Font block, or the
Header back on From skin after the reload. Result: Owner reported pass, 2026-10-31.

**SKIN-26. `/qc skin` (D-16).** On a profile that has closed the first-run picker, `/qc skin` → the
**Choose a skin** window opens with **Ka0s Quick Comms** on its own line; pick and Apply → saved, as
SKIN-18. `/qc help` lists `skin` right after `config` as "Choose a skin: open the skin picker". In
combat (a target dummy), `/qc skin` twice → each prints a gray "cannot open the skin picker during
combat" line and nothing opens. `/qc disable`, `/qc skin` → the one disabled line, no picker;
`/qc enable`. With `libs\LibKa0s` renamed aside and a `/reload`, `/qc skin` → "/qc skin is
unavailable: the LibKa0s library did not load." (rename it back, `/reload`). Result: Owner reported pass, 2026-10-31.

**SKIN-27. The HUD size scale (D-09).** On Ka0s Default, give pad 1's Buttons tab Font size 12 with
*Use the skin's font* ticked and note how wide a button's label is. Pick **Obsidian** → the labels are
the same width as under Ka0s Default, drawn at a slightly larger size (13), and the buttons grow
taller to hold them; `/qc get pad.button.fontSize` still prints 12. Untick *Use the skin's font* →
the label is back to 12 in your own face. Tick **Ignore fonts** → 12 again. Repeat on the dial's Slice
labels. Fail: a stored size that changed, a label cut off, or a size that moves with the box unticked.
Result: Owner reported pass, 2026-10-31.

**SKIN-28. Width parity of the windows (D-08).** In each skin, with the Font outline on HUD text only (the
default), on All text and on Off: open the callout popup (Groups → a callout's Edit), the icon browser
(Choose icon…), the Preview window (`/qc preview`) and the perf step panel (`/qc perf`), and unlock a
pad so its drag strip shows → no title, label, button text or tab is cut off or overlaps its
neighbor, and the drag strip's title fits with its TEST MODE marker under `/qc test`. Compare each
window with Ka0s Default: its text is about as wide. Fail: an ellipsis or clipped text in any skin,
or a skin whose text runs clearly wider than Ka0s Default's. Result: Owner reported pass, 2026-10-31.

**SKIN-29. Media pickers preview (LibKa0s v1.83.0, options-ui-§23).** Fully restart the client, then open a
pad's Buttons tab and untick *Use the skin's font* and *Use the skin's border*. Open **Font** → every row draws
in its own face. Open **Border** → every row shows its art. Pick one of each, `/reload` → the keys stay and
the pad draws them. Repeat on the Dial's Labels tab Font and an icon's Border. Fail: a plain list of names, a
row in the wrong face, a pick lost after the reload, or a Lua error. Result: Owner reported pass, 2026-10-31.

**SKIN-30. A font row and a border row on the only media picker (M3-MEDIA, 2026-11-01).** On the Skin tab
turn **Ignore settings panel** off and pick a skin other than Ka0s Default. Pad → Header → untick Use
the skin's font, open the **Font** dropdown: the closed row and every row of the list wear the skin,
each face previewed in itself, and a pick reaches the pad's header. Pad → Window → untick Use the skin's
border, open **Border style**: the same skinned list with a swatch per border, the row lines up with
its neighbors, and a pick reaches the pad's edge. Switch skins and open both again: they follow it.
Fail: a stock-looking dropdown, a blank list or a Lua error.
Result:

**SKIN-31. No line under any window title (R4-SEP, smoke round 4).** On **Ka0s Default**, open `/qc
preview` (the Preview as window), `/qc debug` and its **Copy** window, `/qc perf`, a group's callout popup
(Groups → a group of yours → Callouts → a row's edit glyph), its **Choose icon…** browser and the browser's Wowhead address window (Game
icons → the hint), and the skin picker (`/qc skin`) → each title band meets the window body with no line between them, like the Skin
Tester showroom's (`/st show`); under Ka0s Default the band is the dark gold gradient. Switch to
Obsidian, then Azeroth, with the windows open → still no line under any title. Inside the callout popup
and the icon browser, the settings page header's gold rule under the page title stays: it is a page
header's rule, not the window's. The console's footer rule and the browser's hint box edges stay too.
Fail: a line under any window's title band in any skin.
Result:

**SKIN-32. The skin picker's list closes on an outside press (R5-RV, LibKa0s R5-L4, smoke round 5).** Open
`/qc skin` and open its skin list. Press the window body → the list closes. Open it again and press the game
world → it closes. Open it again and press the settings page's **Font** dropdown (Pad → Header, *Use the skin's
font* unticked) → the skin list closes and the Font list opens. Repeat once on the Skin tab's picker. Escape
still closes the window. Fail: a skin list that stays open after any of those presses, or a Lua error.
Result:

**SKIN-33. Every window's header on its band, like Loot History's (R5-WIN, smoke round 5, items 2 and 5).** On
**Ka0s Default**, open `/qc preview`, a group's callout popup (Groups → a group of yours → Callouts → a row's edit
glyph), its **Choose icon…** browser and the browser's Wowhead address window (Game icons → the hint), `/qc debug`
and its **Copy** window, `/qc perf` and `/qc skin`. Each window shows one title band, flush inside the window
edge with no strip of body color between the edge and the band, darker than round 4. Each title and close
mark sits on the band's vertical middle. In the callout popup and the icon browser, the page (its title and gold
rule) starts under the band and covers none of it. In the Preview window, the dropdown row sits a small gap under
the band. Switch to WoW Midnight (its 2 px edge) and then Azeroth with the windows open → the same in each skin.
Under Midnight the band and the header move 1 px down with the edge. Fail: a body-color strip above or beside
a band, two bands, a page over the band's lower edge, or a title or close mark visibly above or below the band's
middle in any skin.
Result:

**SKIN-34. The skin picker at LibKa0s picker minor 11 (R6-RV, smoke round 6).** After a full client restart,
open `/qc skin`, pick another skin and close the window with its close mark, then open it again and close it
with Escape, then open it again and press **Apply**. Each opens and closes with no Lua error, and the skin the
window opened with is back after the two closes that did not apply. Fail: a Lua error from
`OptionsSkinPicker.lua`, or a close that leaves the picked skin showing.
Result:

**SKIN-35. The picker's eye is test mode, entered at show and put back at every close (R6-PV, smoke
round 6).** Test mode off. `/qc toggle` to hide the pads, then `/qc skin` with the pads hidden → test
mode turns on: every pad shows its placeholders and dial 1 opens, the settings panel's **Test mode**
checkbox and the launcher's Test mode entry read on, and the picker stays in front of the pads and the
dial. The eye is lit; hover it → "test mode is on". Press the eye → test mode turns off, the eye dims,
its tooltip says off; press it again → on and lit. Close the picker with its close mark → test mode is
off and the pads are hidden, as before the picker opened. Repeat the open and close by Escape, by
**Apply** and by the gear → each time test mode is off after the close. Then `/qc test` to turn test
mode on first, `/qc skin`, press the eye (test mode off) and close → test mode is on again. Then `/qc
toggle` to show the pads, test mode off, `/qc skin` → nothing enters (the pads already show); the eye
turns test mode on and the close turns it off. Last, with the pads hidden, `/qc skin` (test mode on),
then pull a target dummy → test mode ends with its own combat line; close the picker in combat → no
further line. Test mode is session state, so a `/reload` with the picker up leaves it off. Fail: test
mode left on after a close the picker turned it on for, left off after a close the eye turned it off
for, the picker behind a pad or the dial, or a second chat line at the close in combat.
Result:

## Animations

The issue is #13; the rulings are in `docs/superpowers/specs/2026-11-01-open-close-animations-design.md`.

**ANIM-1. The defaults on an existing profile.** Update with your own profile and open a dial by its key,
then close it → it turns and grows into place over 0.2 s, and turns and shrinks away over 0.2 s, about the
dial's center, not the cursor. Result: Passed (owner, 2026-11-02).

**ANIM-2. The handoff.** With a Shine look on the Slices tab and a glow on the Icons tab, open and close a
dial slowly at 0.3 s, on the default skin and on one other → the copy matches the real dial, with no
visible pop as it lands, no missing slice edges and no double image. Result: Passed (owner, 2026-11-02).

**ANIM-3. The first styles, and the list.** On the Dial page's Animation tab try Fade, Scale and fade, Fan
and None, open and close, at 0.5 s and at 2 s. The Open and the Close dropdowns each offer the same 18
entries, and Scale and fade is not one of them. While a style is None its Duration is hidden. The Pad page has no Animation tab. Result: Passed (owner, 2026-11-02).

**ANIM-4. The two switches.** Set a dial's Close to None: it leaves at once and still opens animated. Do
the same for its Open → each changes that one thing on that one dial. Result: Passed (owner, 2026-11-02).

**ANIM-5. A quick send, in combat.** In combat, tap the dial's key and click a slice within 0.1 s → the
line goes out at once; the chosen slice stays bright and pulses while the rest collapse. Press Escape on
the next open → a plain collapse with no emphasis. Result: Passed (owner, 2026-11-02).

**ANIM-6. Rapid toggling.** Spam the dial's key, in and out of combat → it reverses from where it stands
with no jump, and ends fully opaque or fully gone. Result: Passed (owner, 2026-11-02).

**ANIM-7. Taint.** With `/console taintLog 2`, run ANIM-5 and ANIM-6 and read `Logs\taint.log` → no
QuickComms entry and no "blocked" popup. Result: Passed (owner, 2026-11-02).

**ANIM-8. The stand-down.** Open a dial and run `/qc disable` during the animation, or start a perf capture
→ nothing stays on screen; `/qc enable` brings the surfaces back whole. Result: Passed (owner, 2026-11-02).

**ANIM-9. The preview.** Turn on Preview as…: the preview dial plays its open. Edit a setting: it rebuilds
without flickering. Result: Passed (owner, 2026-11-02).

**ANIM-10. Alt-Z.** With a dial open (Preview as… keeps one open), press Alt-Z twice, and watch a short
cinematic → nothing plays on the way out or on the way back; it comes back whole, at its rest alpha. The
next real close and open play. Result: Passed (owner, 2026-11-02).

**ANIM-11. A pad does not animate.** Toggle a pad with `/qc toggle`, in and out of combat, with Fade on
Mouseover → it shows and hides at once, its hover and fade answer at once, and no copy is drawn. On a
profile that ran this branch's first step 12, `/dump` a pad's `anim` → nil. Result: Passed (owner, 2026-11-02).

**ANIM-12. Text neither shimmers nor truncates.** On the Dial page's Animation tab set Scale and fade at
0.5 s, then at 2 s, and open and close a dial with a long title ("Quick Comms: World") → the title and
every label scale smoothly with the art, about the dial's center, with no shimmer, no jitter of the
letters, no text cut short and no ellipsis at any moment; each string stays on its slice; none jumps at
the landing. Reverse one mid-animation → the text turns with the art. Send on a slice at 2 s → that
slice's label pulses with it. A little softness at the small end is Vertex mode on a font that is not a
slug font; note it if it looks wrong. Result: Passed (owner, 2026-11-02).

For each family below, set the same style on Open and Close and play it at 0.5 s and again at 2 s. Each
ends with the real dial whole and fully opaque, or fully gone, with no pop at the landing. The first
in-game trials are marked: nothing but the client can show whether they draw at all.

**ANIM-13. The scales.** Scale and Scale and fade → on open each grows from small about the dial's
center, on close each shrinks into it. Scale and fade fades the whole way; Scale reaches full alpha early.
There is no start-large style. Text stays sharp and whole, as ANIM-12. Result: Passed (owner, 2026-11-02). (SF-QC-1 changed
the expected result: any earlier pass no longer stands.)

**ANIM-14. The slices moving apart.** Inward spiral, Outward spiral, Orbit and Shatter → each slice's fill,
shine and edge turn as one with no gap opening inside a slice, its icon and label ride with it and stay
upright, and the hub and title only fade. Orbit's slices start together at the top. Try a ring of 4 and
of 8. Result: Passed (owner, 2026-11-02).

**ANIM-15. The overshoots.** Burst, Stagger pop and Pop → the small overshoot is visible at 2 s and lands
with no snap. On Pop and Stagger pop the text overshoots with the art, not behind it. Result: Passed (owner, 2026-11-02).

**ANIM-16. The moves.** Drop bounces to rest. Slide with Direction Up, Down, Left and Right, on Open and on
Close separately → Up rises into place and leaves upward; the row shows only on Slide; text moves with
the art. A send during a close leaves the sent slice where it rests. Result: Passed (owner, 2026-11-02).

**ANIM-17. Rotate and scale. First in-game trial.** The ring swings about 120° as it grows and winds back
as it shrinks → every fill, shine layer and mask turns cleanly about the dial's center, with no slice
showing its mask's edge; icons and text stay upright; the hub stays level. Note any rotated art that
reads wrong. Result: Passed (owner, 2026-11-02).

**ANIM-18. Squash and Flip. First in-game trial.** Squash opens from a thin line, one axis then the
other, and collapses the same way. Flip narrows like a card seen edge-on → the art really stretches on
one axis, masks and slices included, no frame snaps back to full size at a leg's end or at the landing,
and the text stretches with it. A Scale animation on a 1×1 frame carrying regions anchored outside it is
what this tries. If the dial only shrinks evenly, the client took the substitute: note it. Result: Passed (owner, 2026-11-02).

**ANIM-19. Flash.** Flash → a soft bloom through the ring that peaks mid-way and is gone at the landing,
with no square edge to the glow. Result: Passed (owner, 2026-11-02).

**ANIM-20. The old defaults moved.** On a profile that ran this branch before these rulings, with one dial
still on Inward spiral at 0.5 s and Outward spiral at 0.3 s, one on Scale and fade at 0.7 s, and one with
other picks → after the update the first shows Rotate and scale at 0.2 s for its open and its close, the
second Scale and fade at 0.7 s, and the third keeps its picks. Result: Passed (owner, 2026-11-02).

**ANIM-21. The merged scales and the swapped labels (SF-QC-1, SF-QC-2).** On a profile that stored Scale
in, Scale out, Scale in and fade or Scale out and fade on a dial → after the update they read Scale or
Scale and fade with their durations kept. On Open, Inward spiral spirals the slices inward to the center
and Outward spiral spirals them outward from it, each as its label says. Rotate and scale is still the
default. Result: Passed (owner, 2026-11-02).

**ANIM-22. WoW Default's window border (SF-QC-3).** Wear WoW Default → the pad's window is framed in the
dialog-box border art the Skin Tester's window wears, not a thin gray line; the buttons keep their
hairlines, and the header's title band and the section titles draw no line (amended by R5-QC1, smoke round
5). Any other skin → the pad's window is as before.
Result:

## The pad's look per skin

The owner's findings of 2026-11-01. Each check: a pad on screen (`/qc test`), the named skin, every box
at its default. Compare a hairline with that skin's window edge on the settings or Preview window.

**PLOOK-1. Ka0s Default.** The buttons have a dark body with a soft top-to-bottom gradient and a gentle
gloss, a thin gray edge, the same icons and colors; restrained next to Obsidian's. The header wears the
dark gold title band (PLOOK-12) and the section titles draw no band. Fail: the old flat wash, or a gloss
brighter than Obsidian's. Amended by R5-QC1 (smoke round 5): the header is the skin's title band with no edge, and section titles draw no band.
Result:

**PLOOK-2. Obsidian.** As before but the gloss is about a third lighter; buttons have hairline
edges. Amended by R5-QC1 (smoke round 5): the header is the skin's title band with no edge, and section titles draw no band.
Result:

**PLOOK-3. Azeroth.** Leather buttons with a lighter gloss. Amended by R5-QC1 (smoke round 5): the header is the skin's title band with no edge, and section titles draw no band.
Result:

**PLOOK-4. Glass.** Gloss cap a third lighter; no thick pale frame on the header or any section title, as
on 2026-11-01. Amended by R5-QC1 (smoke round 5): the header is the skin's title band with no edge, and section titles draw no band.
Result:

**PLOOK-5. High Contrast.** White hairlines on the buttons, no shine. Fail: an edge around the header or a
section title. Amended by R5-QC1 (smoke round 5): the header is the skin's title band with no edge, and section titles draw no band.
Result:

**PLOOK-6. Ember.** Ember buttons with a lighter gloss. Amended by R5-QC1 (smoke round 5): the header is the skin's title band with no edge, and section titles draw no band.
Result:

**PLOOK-7. WoW Default.** A Blizzard-style pad: dark window with a gray edge, a gray title band under the
header with gold text and no line around it, section titles on no band, clear red buttons with a soft sheen.
Fail: any white band or white edge, or buttons dark maroon. Amended by R5-QC1 (smoke round 5): the header is the skin's title band with no edge, and section titles draw no band.
Result:

**PLOOK-8. WoW Midnight.** Night-violet buttons, gold hairlines on the buttons, a lighter gloss. Amended by R5-QC1 (smoke round 5): the header is the skin's title band with no edge, and section titles draw no band.
Result:

**PLOOK-9. WoW Forever.** Charcoal buttons with a lighter gloss. Amended by R5-QC1 (smoke round 5): the header is the skin's title band with no edge, and section titles draw no band.
Result:

**PLOOK-10. Strength and the box.** Pad → Buttons and Dial → Slices: with *Use the skin's shine* ticked
Shine strength is gray; a dial sharing the skin's look reads as light as the pad. Untick it → the row
wakes, your stored value draws under every skin. Result: Passed (owner, 2026-11-02).

**PLOOK-11. The texture override.** Skin → WoW Default, then pick a Texture on the Skin tab's Font and
texture section → the buttons take it; back to the skin's own → flat red. A page dot's edge under WoW
Default is dark, not white. Result: Passed (owner, 2026-11-02).

**PLOOK-12. The pad's header is a title band, like Loot History's (R5-QC1, smoke round 5, item 4, images 40
and 41).** With a Comms Pad shown (a section such as "Solo" on it), on **Ka0s Default**: the header row ("Quick
Comms: ...", the "-" button) wears the dark gold title band, darker than round 4, with its gradient. The band
sits inside the pad's black edge and gray inner rule, with the edge and the rule showing all round it as Loot
History's band does, and no body-color strip between them. The header text stays left, the "-" stays right,
and both sit on the band's vertical middle. The "Solo" section title draws no band of its own. Switch to
Obsidian, Azeroth, Ember, WoW Midnight and WoW Default: the header shows each skin's own title band
(Ember, Midnight and WoW Default with a gradient), with no edge or box of its own in any skin. Under WoW
Default the band sits inside the dialog art and the art is not cut across. The section titles draw no band in
any skin. The header text stays readable on the band. Collapse the pad with "-": it is exactly the band and
the edge around it. Set the pad to grow up (Pad → Layout → growth up): the band is the pad's bottom row, inside
the edge, with the same gradient direction (lighter at the top). Pad → Header: untick *Use the skin's
background* and pick a color: the band goes and the picked color fills the row. Tick it again: the band is
back. Tick *Use class color* for the background: the class color, no band. Untick it, and on Ka0s Default set
the header's Border thickness to 2 with *Use the skin's border* still ticked: a 2 px edge around the band,
the band kept; switch to WoW Default: no edge (a skin's own style never draws on the band). Fail: no band, two stacked boxes,
a band over the window edge or rule, a body-color strip around the band, a section band, an edge around the
header, or the stored color drawn over a gradient.
Result:

## The full skin

LibKa0s v1.85.0 and Ka0sAddonsCommonTasks `docs/2026-11-01-FULL_SKINNING/` (cause D7). Each check names
what it should show; a token that reads the same in two skins cannot show a change, so these use
Obsidian, Azeroth, Glass and High Contrast, whose fills, text and shadows differ. Windows and files
are added in this build: a full client restart comes first.

**FSKIN-1. Ka0s Default did not move.** New profile on **Ka0s Default**, a pad on screen and a dial open
→ the gold header on the skin's dark gold title band (R5-QC1, smoke round 5, PLOOK-12) and the titles over
no band, white labels, the
slices, the gray hub with its gold rim and circle, the page dots and the Gloss fade and Glass orb
shines look as they did before this build, text shadows included, but for the pad buttons and the
shine's strength (PLOOK-1). Fail: any other pixel moved but the checks' named ones (a tooltip title,
FSKIN-9). Amended by R5-QC1 (smoke round 5): the header's title band. Result:

**FSKIN-2. Every pad color follows a skin, live.** Skin → **Obsidian**, then **Azeroth**, a pad on
screen → with no reload the window fill and edge, the header's and the titles' text, the header's title
band in the skin's title colors with no edge and no band behind a section title (amended by R5-QC1, smoke
round 5), the buttons' body, edge and
label all change. A thickness of your own on a band draws instead under a skin with no border of its own
(FSKIN-12). Fail: any of them keeping the last skin. Result:

**FSKIN-3. Every dial color follows a skin, live.** Same, a dial open and paged → the slices, a hovered
slice, the hub's disc, rim and circle, the pointer, the page arrows and plates, the pill and dots, the
slice labels and the group label all change. In combat they change when combat ends. Result: Passed (owner, 2026-11-02).

**FSKIN-4. Text shadows.** Under **High Contrast** the HUD text's shadow sits 2 pixels off; under
**Obsidian** 1; under **Ka0s Default** the black 1, -1 they always had. Tick **Ignore fonts** → each
block's stored shadow. Pad → Buttons → untick *Use the skin's shadow* → its Font shadow box decides
under every skin. Result: Passed (owner, 2026-11-02).

**FSKIN-5. The button texture and the shine.** **Azeroth** → the buttons' bodies take its parchment bar
texture in the skin's button color; untick *Use the skin's texture* → flat. **Glass** → the pad's shine
is Gloss cap, the dial's Frosted glass; **High Contrast** → no shine; every other skin keeps the Ka0s
Default look in its own tint. Untick *Use the skin's shine* → your Shine look, tint and Strength under
every skin. Result: Passed (owner, 2026-11-02).

**FSKIN-6. A box unticked keeps your color.** On a pad, untick *Use the skin's color* beside Background
color and pick red, then switch skins → the red stays; tick the box → the skin's, and your red comes
back when it is unticked. No swatch grays out. Same on the Hub's Hub border, where the box also gives
the thickness to a skin with a border of its own: under **High Contrast** Hub border size grays while
it is on; under Obsidian it stays live and your size draws. Result: Passed (owner, 2026-11-02).

**FSKIN-7. An existing profile moves once.** Log in on a profile from before this build with colors of
your own → every pad and dial follows the skin, the stored colors kept behind the unticked swatches'
boxes; `/reload` and untick a box → it stays unticked through a reload, General's Defaults and a profile
switch and back. Reset this profile → the shipped look. Result: Passed (owner, 2026-11-02).

**FSKIN-8. Meaning stays.** On any non-default skin: a button with **Use class color** on its font or
background keeps the class color with the skin's box ticked; a callout's colored glyph keeps its color,
a game icon its art, and only a plain white glyph takes the skin's tint. The send flashes keep their
meaning colors. Under the default Scope the settings panel stays stock. Result: Passed (owner, 2026-11-02).

**FSKIN-9. The tool marks and tooltips, Scope cleared.** Skin → untick **Ignore settings panel** on
Azeroth → the Groups, Pads and Dials lists' active marker is a green-toned Ka0s tick, not the client's
dot; the editors' remove, clear, edit and Tokens glyphs are Ka0s marks in the skin's tint; the icon
browser's cell hover takes the skin's. Tick it back → all stock, with no reload. On any skin, every
tooltip title on a button, a wedge, the hub, the Preview as window and an icon cell is in the tooltip
title color. The hub's stale, lockdown and test labels and End preview are in the skin's face.
Result: Passed (owner, 2026-11-02).

**FSKIN-10. The animation copy wears the skin.** **Azeroth**, a dial → open and close it, and its Fan →
through the animation the copy shows the skin's fills, edges and text with its shadow: no flash of Ka0s
Default, no text losing its shadow. Result: Passed (owner, 2026-11-02).

**FSKIN-11. The picker's preview.** The first-run picker's eye over a pad → each pick repaints the pad
and dial in that skin, closing it puts them back. Result: Passed (owner, 2026-11-02).

**FSKIN-12. A skin's own wash and border.** On a pad's Main window, tick *Use the skin's border*, pick a
border style of your own and thickness 4. **Obsidian** → your border draws, since this skin has none of
its own. **High Contrast**, then Azeroth, WoW Default and WoW Midnight → the skin's border wins at its
own thickness, on the window and the buttons; the header's title band and the section titles draw no edge
while they follow the skin (amended by R5-QC1, smoke round 5). Untick the box → yours under every skin. Ka0s
Default with no pick of yours → no band edge and the shipped look. A refused and a
cooling button → the two veils take each skin's dim color and still read apart, the refused one darker.
Icon borders and glows differ between skins with the boxes ticked. A send flash keeps its meaning color.
Result:

**FSKIN-13. A stored pick of the deleted Friz lands on Ka0s Ubuntu (R3-FRIZ, step 18).** Before updating,
untick a pad's Header *Use the skin's font* and set *Font* (or the Skin tab's Font) to *Ka0s Friz Quadrata
TT* in two profiles; log out. Update and fully restart the client (a new font file) → the header draws in
Ubuntu and *Font* reads *Ka0s Ubuntu*; switch to the other profile → the same. A font set to Blizzard's
own *Friz Quadrata TT* keeps it. Fail: the game's default face, or a row still naming Ka0s Friz Quadrata
TT. Result: not run

**FSKIN-14. The pad's icon border is 1 pixel in every skin (R3-FIX).** Turn on a pad's Icons border with
*Use the skin's border* ticked, open the pad, then pick Ka0s Default, Azeroth, Ember, WoW Midnight and WoW
Default → every icon's border is a flat 1-pixel edge in each, never 2 pixels and never the tooltip-style
edge WoW Default drew before. Untick the box → your own style and thickness come back. Fail: a 2-pixel or
tooltip edge under any skin. Result: not run

## Role and character

**Client: Retail** unless the check says otherwise; FOREVER-18 to FOREVER-21 re-run these on WoW
Forever. **Code:** `core/Compat.lua` (`CharacterKey`, `PlayerRole`, `SetRoleOverride`,
`SpecsForClass`), `libs/LibKa0s/Role.lua` (vendored), `settings/Schema.lua` and
`settings/SchemaRows.lua` (the Role row), `settings/Groups_When.lua` (the Character and Specialization
rows), `modules/Situation.lua` (`DescribeRole`), `settings/SlashVerbs.lua` (`/qc why`).

- **ROLE-1. The Role row (Retail).** General → Behavior → **Your role** → the **Role** dropdown reads
  *Automatic (Tank, from your specialization: Protection)*, or your own spec and role; its tooltip
  ends *Automatic now: ...* with the same phrase. Pick **Healer** → a group whose When ticks only Role
  Healer shows on the pad at once, with no /reload; `/qc why` opens with *Your role: Healer, your
  choice on the General page.* Switch to another profile → the Role row still reads Healer (it is per
  character). Pick **Automatic** → the pad goes back, and `/qc why` names the spec again. Result: passed (owner, 2026-11-10)
- **ROLE-2. The group's role wins over the spec (Retail).** Join a dungeon finder group as a role
  other than your spec's → `/qc why` reads *Your role: <that role>, the role your group gave you.*;
  `/qc diagnostics` shows `roleSource=assigned`. Result: passed (owner, 2026-11-10)
- **ROLE-3. The Character and Specialization rows (Retail).** Groups → any group → When → **Character**
  → **Add this character** → your `Name-Realm` is listed, as before. **Specialization** → your class's
  specs are listed by name. A group saved before this change with a Character entry still matches.
  Result: passed (owner, 2026-11-10)

## WoW Forever

**Client: WoW Forever** (1.60.1, interface 16001), every check here. The rest of this file is Retail's; these checks re-run its core on Forever, where the client draws its own frames and keeps its own `WTF`. Every Retail rule above holds: zero Lua errors, no taint warning, nothing sent that you did not press. The content kinds, place lists, role, probe and emote checks join this section with their items of the port (Ka0sAddonsCommonTasks `docs/2026-11-10-QUICKCOMMS_FOREVER_EMOTES/`).

**Code:** `QuickComms.toc` (the two-number `## Interface:` line), `core/SkinSetup.lua` (`NS.DEFAULT_SKIN`), `core/Compat.lua` (`Compat.FrameStrata`, the strata guard), `modules/Anim_Ghost.lua` and `settings/ModalWindow.lua` (its two readers), `modules/SendEngine.lua` (the secure send path, unchanged on Forever).

**Setup.** Link the checkout into the Forever client once, from an elevated Windows prompt, then fully restart the client:
`mklink /d "G:\Games\Blizzard\World of Warcraft\_forever_\Interface\AddOns\QuickComms" "D:\Profile\Users\Tushar\Documents\GIT\QuickComms"`.
Forever's SavedVariables are `_forever_/WTF/Account/<ACCOUNT>/SavedVariables/QuickComms.lua`. Props: a second character or a friend to group with, for FOREVER-5.

- **FOREVER-1. The AddOns list.** At character select → **Ka0s Quick Comms** is listed with its logo and is **not** marked *Out of date*, and "Load out of date AddOns" does not need to be ticked for it to load. Result: passed (owner, 2026-11-10)
- **FOREVER-2. A fresh install loads clean.** With no `QuickComms.lua` in Forever's SavedVariables, log in → zero Lua errors and no chat line at login (INSTALL-1); `/qc version` prints the version. Result: passed (owner, 2026-11-10)
- **FOREVER-3. The settings panel and the launcher.** `/qc config` → the settings open on the landing page, and General, Groups, Comms Pad, Comms Dial and Profiles each draw with no error. The minimap button shows the speech-bubble logo; left-click → the settings open; right-click → the four entries Enabled, Locked, Test mode and Show window, each ticking its state (STATE-2). Result: passed (owner, 2026-11-10)
- **FOREVER-4. The default skin per client.** On a fresh Forever profile (create one on the Profiles page) → `/qc get skin.skin` reads `forever`, and General → Skin shows **WoW Forever** selected. On Retail, a fresh profile reads `ka0s` (Ka0s Default). Then pick Obsidian, then Ka0s Default, then WoW Forever on Forever → the pads, the dial and the settings windows repaint each time, with no error. Result: passed (owner, 2026-11-10)
- **FOREVER-5. A pad sends through its secure button.** In the open world, grouped with a second character → the pad shows its open-world set. Click a button → its line goes to the channel it names, once, and the spam guard dims every button for about a second as on Retail (SEND-3). Out of the group, solo → the solo set shows and a click follows Behavior's solo fallback. Result: passed (owner, 2026-11-10)
- **FOREVER-6. A dial opens, sends and animates (the strata guard).** Bind Open Comms Dial 1 (Options → Keybindings → Ka0s Quick Comms), press it → the dial opens with its open animation and no Lua error mentioning a secret value or a strata; pick a wedge → its line is sent and the dial closes with its close animation; open it in combat on a training dummy and pick a wedge → it sends (DIAL-1, ANIM-1). Result: passed (owner, 2026-11-10)
- **FOREVER-7. A lifted confirm (the strata guard).** With a dial bound, open **Groups**, pick a group and click **Delete group…** → the confirm draws over the settings window and over the dial if it is open, and **No** takes the click. Then open the game menu and **Log Out**, and cancel it → Blizzard's own popup draws where it always does, under nothing of this addon's. Result: passed (owner, 2026-11-10)
- **FOREVER-8. The key bindings.** Options → Keybindings → the **Ka0s Quick Comms** section lists Open Comms Dial 1 and Toggle Comms Pads, and General → Keybindings shows the same keys (KEY-3, KEY-4, KEY-5). Result: passed (owner, 2026-11-10)
- **FOREVER-9. Profiles across a full restart.** Create profile `SmokeTest` on the Profiles page, move a pad there, then **exit the client completely** and start it again → the same profile is active and the pad is where you left it. Switch back and delete `SmokeTest` afterwards. Result: passed (owner, 2026-11-10)
- **FOREVER-10. Diagnostics.** `/qc diagnostics` → the console opens with the sections DIAG-1 names and no Lua error, and the report's `client:` line reads `version=1.60.1` and `interface=16001`. Result: passed (owner, 2026-11-10)
- **FOREVER-11. Enable and disable.** `/qc disable` → every pad and dial stands down and `/qc help`, `/qc version` and `/qc diagnostics` still answer; `/qc enable` → they return, as on Retail (STATE-1). Result: passed (owner, 2026-11-10)

The content kinds, place lists and seeds (QFE-F3; **code:** `defaults/GameIds_Clients.lua`, `defaults/BuiltIns.lua` `Ships`/`Seeded`, `settings/Groups_When.lua`, `modules/Preview.lua`, `settings/Callouts.lua`). Forever's ids are derived from Forever's own GroupFinderActivity and Map tables, joined on map id (build 1.60.1.70862; `tools/derive-gameids.py --forever`); FOREVER-16 confirms them in game with `/qc probe ids` (FOREVER-25), which needs no travel.

- **FOREVER-12. The When editor offers Forever's kinds.** Groups → pick any group → When → open **Content** → it lists exactly Open world, Dungeon, Raid and Battleground (no Mythic+, Delve, Scenario, Arena or Housing); **Select all** ticks those four only. The drawers listed are Content, Instance, Group, Leader or assist, Class, Specialization, Role, Character and Battleground: no **Difficulty**, **Key level** or **Arena** drawer. Open **Instance** and type `Molten` → Molten Core is suggested; type `Algeth` → nothing is suggested. On Retail the same group shows all nine kinds and every drawer (unchanged). Result: passed (owner, 2026-11-10)
- **FOREVER-13. Preview as... lists Forever's places.** Settings → General → **Preview as...** → the menu reads Current, then the 30 dungeons the group finder lists (the classic ones with Scarlet Monastery and Scholomance, Forever's own nine, such as City of Dalaran and The Hall of Thanes, and Demon Fall Canyon and Karazhan Crypts) as `Dungeon · <name>`, A-Z, then the 12 raids (Molten Core, Onyxia's Lair, Blackwing Lair, Zul'Gurub, both Ahn'Qiraj raids, Naxxramas, Storm Cliffs, The Tainted Scar, The Crystal Vale, Nightmare Grove and Scarlet Enclave) as `Raid · <name>`, A-Z and with no difficulty named, then `BG - Arathi Basin`, `BG - Warsong Gulch`, `BG - Alterac Valley` and Solo. There is no `M+` entry, no Arena and no Darkspear Islands (D3-R). Pick `Dungeon · Deadmines` → the pads show the groups whose Content ticks Dungeon; pick `BG - Warsong Gulch` → the Warsong Gulch set shows; then turn the preview off. Every name reads as the client names it, not `Instance <number>`, and is the name FOREVER-25's `/qc probe ids` record holds for that id in `maps`. Result: passed (owner, 2026-11-10)
- **FOREVER-14. A fresh profile seeds Forever's sets.** Profiles → create `SmokeSeeds` → Groups lists Dungeon, Raid, Solo, Emotes, Arathi Basin, Warsong Gulch, Alterac Valley (each opening into its objectives, as on Retail), Battleground and In Group, and **no** Arena set or any other battleground (Eye of the Storm, Twin Peaks and the rest are absent). **Restore built-in groups** → `0` groups come back. Delete Warsong Gulch, then **Restore built-in groups** → it comes back with its nodes, and the Arena set still does not. Switch back and delete `SmokeSeeds` afterwards. Result: passed (owner, 2026-11-10)
- **FOREVER-15. The token help leaves out {dungeon} and {key}.** Edit any callout and hover the info glyph beside **Text** → the token list has `{spec}` and `{role}` but no `{dungeon}` and no `{key}`. On Retail it lists both (unchanged). Result: passed (owner, 2026-11-10)
- **FOREVER-16. Forever's ids match the client's own names, with no travel (confirms the derived ids).** Run FOREVER-25's `/qc probe ids` → its third line reads *shipped ids the client does not name: none*; an id it lists (`dungeon <id>`, `raid <id>` or `battleground set <key> (<ids>)`) is one the client does not know, so record it. Its fifth line reads *group finder: N activities; shipped ids it does not list: none; maps it lists that no shipped id carries: Darkspear Islands (2997)* (on build 1.60.1.70862, N about 114, fewer where the client hides an activity); record any other id or map it names. Many GroupFinderActivity rows carry a player condition (every raid, most battlegrounds and some dungeons, 43 of 114 rows on build 1.60.1.70862; among them every place D3-R added: Demon Fall Canyon, Karazhan Crypts, Storm Cliffs, The Tainted Scar, The Crystal Vale, Nightmare Grove, Scarlet Enclave), so the client may hide an activity from a character that does not meet it: if the line names a shipped id, record it with the character's level and faction. Its fourth line, the dungeon finder's, may read *not checked*: Forever's group finder is the fifth line's listing. Log out and send Claude `_forever_/WTF/Account/<ACCOUNT>/SavedVariables/QuickComms.lua`: in the ids record's `maps`, each of the 30 dungeons and 12 raids `defaults/GameIds_Clients.lua` lists carries the name its comment gives, and 489, 529 and 30 name Warsong Gulch, Arathi Basin and Alterac Valley; Claude compares them with `tests/test_gameids.lua`'s `FOREVER_MAPS` and records any difference. If you are in a listed place anyway, `/qc why` there → its content reads `dungeon`, `raid` or `battleground` and its instance id is the listed one, and a battleground's own set shows on the pad and opens on the dial; no visit is owed for this check. Result: passed (owner, 2026-11-10; the ids record of 2026-11-10 named all 45 shipped ids as `FOREVER_MAPS` does, and its group finder listed 77 activities, hiding 389, 2784, 2875, the 12 raids and Alterac Valley (30), every one a GroupFinderActivity row with a player condition the character did not meet)
- **FOREVER-17. A profile copied from Retail still works.** Copy a Retail `QuickComms.lua` (with its Dungeon and Arena sets) into Forever's SavedVariables while the client is closed, then log in → zero Lua errors; the Dungeon and Arena groups are still on the Groups page and editable, and their When still shows its other rows; **Restore built-in groups** adds nothing for them. Put the original file back afterwards. Result: passed (owner, 2026-11-10)

The role and the long character names (QFE-F4; **code:** as **Role and character** above). Forever's
talent-tree-to-role map is MATCHED, NOT CONFIRMED until FOREVER-18 passes for a hybrid class.

- **FOREVER-18. Automatic reads the talent tree.** On a hybrid (a warrior, paladin or druid), with
  most points in the tank tree and no group role assigned → General → Behavior → **Role** reads
  *Automatic (Tank, from your talents: Protection)*, or the tree's own name; respec most points into a
  damage tree → after the respec it reads Damage with that tree's name, and a group whose When ticks
  only Role Tank stops showing. Record the tree names shown and any class whose answer is wrong.
  Result: passed (owner, 2026-11-10)
- **FOREVER-19. The Role pick (Forever).** Pick **Healer** → `/qc why` opens with *Your role: Healer,
  your choice on the General page.*; `/qc diagnostics` shows `role=HEALER` and
  `roleSource=override ... override=HEALER`; log out and back in → still Healer. Pick **Automatic** →
  the talent answer comes back. Result: passed (owner, 2026-11-10)
- **FOREVER-20. The character row and {me} use the long form.** Groups → any group → When →
  **Character** → **Add this character** → your first name and surname are listed (`First Surname`, no
  realm, no hyphen); the drawer's tooltip says *by first name and surname*. Type a friend's
  `first surname` in lower case and press Enter → it is listed as `First Surname`. A group whose
  Character lists only you shows; one listing only the friend does not. A callout whose text holds
  `{me}` sends your first name and surname. Result: passed (owner, 2026-11-10)
- **FOREVER-21. Your own lines count as yours.** With Behavior's *Note dropped callouts in chat* on,
  send ten callouts a little over a second apart in a group → no *dropped* note appears for any of
  them (the echo of your own line, sent as `First Surname`, is matched). `/qc diagnostics` → the Echo
  line's `unknownSender` stays 0. The Specialization row lists your class's one Forever spec by name.
  Result: passed (owner, 2026-11-10)

The probe (QFE-F5; **code:** `settings/SlashVerbs.lua` `ProbeLines`, `core/Compat.lua` `ProbeInstance`,
`TalentGroups`, `EmoteTokens`). Both clients. A place record confirms the content kind and instance id of a place you happen to be in; Forever's ids are confirmed without travel by FOREVER-25's ids record.

- **FOREVER-22. `/qc probe` where you are, beside the ids record.** Out of combat, once in the open
  world and in any Forever dungeon, raid or battleground you happen to enter (no visit is owed: the ids
  are FOREVER-16's and FOREVER-25's), type `/qc probe` → four chat lines: *Probe N saved for forever (...)*, then the place (its name, type, difficulty id and name,
  max players and instance id), then the content kind, group and role, then the spec, the talent
  groups with their points and the emote count (a few hundred). In combat → one line, *The probe is
  not available in combat.*, and nothing is recorded. Then `/qc probe ids` (FOREVER-25). Log out, then
  send Claude `_forever_/WTF/Account/<ACCOUNT>/SavedVariables/QuickComms.lua`: its
  `global.probes.forever` holds one record per probe, oldest first, the place records (no `kind`, each
  with every `GetInstanceInfo` value, the situation, the role and source, the spec and the emote
  tokens) and the ids record (`kind = "ids"`) in one list. Record any place whose content kind or
  instance id differs from `defaults/GameIds_Clients.lua`. Result: passed (owner, 2026-11-10)
- **FOREVER-23. `/qc probe` on Retail, and `probe clear`.** On Retail, type `/qc probe` in the open world
  → the same four lines, *saved for retail*, with no talent groups (*none*). Then `/qc probe clear` →
  *Probes cleared: N removed.*, N being the probes taken on this client; after a /reload the
  file has no `probes` table. `/qc help` lists `probe`. Result: passed (owner, 2026-11-10)

The Dungeon set on Forever (QFE-C7, the lead's call; **code:** `defaults/GameIds_Clients.lua`
`BUILTIN_WHEN`, `defaults/BuiltIns.lua` `WhenOf`, `modules/Library.lua` `seedGroup`).

- **FOREVER-24. The Dungeon set matches dungeons alone.** On a fresh Forever profile (FOREVER-14's
  `SmokeSeeds`), Groups → **Dungeon** → When → **Content** has Dungeon ticked and nothing else, and
  there is no Key level drawer. Zone into any listed dungeon, grouped or solo → the pad shows the
  Dungeon set and the dial opens on it, and `/qc why` names it active. In the open world it is not
  shown. Delete it, then **Restore built-in groups** → it comes back with its seven callouts and the
  same dungeon-only When. On Retail a fresh profile's Dungeon set still ticks Dungeon and Mythic+
  (unchanged). Result: passed (owner, 2026-11-10)

The ids sweep (QuickComms#21, the forever-ids design; **code:** `settings/SlashVerbs.lua` `ProbeLines`,
`ProbeIdsRecord`, `ProbeIdsSummary`, `core/Compat.lua` `ProbeMapNames`, `ProbeDungeonFinder`,
`ProbeBattlegrounds`, `ProbeGroupFinder`). Anywhere on Forever; no travel.

- **FOREVER-25. `/qc probe ids` sweeps the client's names with no travel.** Out of combat, anywhere on
  Forever, type `/qc probe ids` → no Lua error, and five chat lines: *Ids probe N saved for forever
  (...)*; *map names read: M of ids 0 to 4000; dungeon finder: L entries; battlegrounds: B*, with M at
  least 45 (the ids Forever ships); *shipped ids the client does not name: none* (FOREVER-16);
  *dungeon finder names no shipped id carries:* followed by *none*, by names, or by *not checked, the
  dungeon finder listed no entries*; and *group finder: N activities; shipped ids it does not list:
  none; maps it lists that no shipped id carries: Darkspear Islands (2997)*, expected on build
  1.60.1.70862 with N about 114 (the group finder is how Forever lists its places, the forever-ids
  design's D5; *group finder: not checked, the group finder listed no activities* means the check
  failed, so record it). Record L and B as the client gives them: Forever's own UI never calls
  the dungeon finder or battleground list APIs, so L = 0 and B = 0, with the *not checked* line, is a
  possible answer and not a failure. Where L is not 0, expect about 35 specific entries (LFGDungeons
  TypeID 0 on build 1.60.1.70862: 31 dungeon entries, the Blackrock Spire halves and Dire Maul's three
  wings apart, and 4 raids), then any random ones. A listed name may be the dungeon finder's own spelling
  of a shipped place (Stormwind Stockades, Zul'Farak, Lower or Upper Blackrock Spire, Dire Maul - East,
  West or North, Onyxia, Hall of Thanes); record any other name it gives. In combat → one line, *The probe is not available in combat.*, and nothing is recorded.
  `/qc disable`, then `/qc probe ids` → the one disabled line, and nothing is recorded; `/qc enable`.
  `/qc probe ids2` → one line naming `/qc probe`, `/qc probe ids` and `/qc probe clear`. On Retail,
  `/qc probe ids` → the same five lines, *saved for retail*. Log out and send Claude Forever's
  `QuickComms.lua`: the ids record holds `kind = "ids"`, `client = "forever"`, `time`, `maps`, `lfg` (each
  entry with its `id`, `name`, `typeID`, `subtypeID` and `mapID`, a random one with `random`),
  `battlegrounds` (each with its `name`, `battlegroundID` and `mapID`) and `groupFinder` (each activity
  with its `id`, `name`, `categoryID`, `mapID`, `maxNumPlayers` and `isPvp`); Darkspear Islands is among
  the group finder's activities and gets no set of its own (D3-R), and Battle for Gilneas is not listed
  by the group finder. Result: passed (owner, 2026-11-10)
- **FOREVER-26. The combined-actions core on Forever.** On WoW Forever, run ACTION-1 (one press sends a
  line, an emote, a ping and a marker), PING-2 (a ping in a party, in combat), MARK-2 (a mark in a party
  as a non-leader) and MARK-7 (marking in combat and during a boss encounter) → each as its check
  describes; record any that differs from Retail. Result: owed

## Emotes

**Client: Retail, then WoW Forever**, every check here (QuickComms#15, Ka0sAddonsCommonTasks
`docs/2026-11-10-QUICKCOMMS_FOREVER_EMOTES/`). **Code:** `modules/Channels.lua` (the `emote` kind),
`modules/SendEngine_Guard.lua` (the `CHAT_MSG_EMOTE` echo row), `settings/SchemaMembers.lua`,
`settings/Groups.lua` and `modules/Pad_Render.lua` (its labels); for the game emotes
`modules/Emotes.lua`, `modules/Bake.lua` (`BakeEmote`) and `settings/CalloutPopup.lua` (the picker).

- **EMOTE-1. A custom emote callout sends /e (QFE-E1).** Out of combat in the open world, solo, edit a
  callout in a group on your pad → the **Channel** dropdown lists **Emote** last, after General. Pick it
  and set the text to `waves at {me}` → its Groups row reads `Emote` in the emote color (orange, as an
  emote line shows in chat). Hover its button → `Channel: Emote` in the same color. Click it → chat
  shows `<your name> waves at <your name>` as an emote, once, with no "interface action blocked" and,
  with *Note dropped callouts in chat* on, no drop note (the `CHAT_MSG_EMOTE` echo is matched; `/qc
  debug on` shows an `Echo` line ending `sent`). Grouped, it still goes out as an emote (no party
  line). Turn on **Preview as... → World** and click it → one `[QC] /e waves at <your name>` line and
  nothing in chat. Repeat on WoW Forever, where `{me}` is your first name and surname. Result: passed (owner, 2026-11-10)
- **EMOTE-2. An emote locks as Say does (QFE-E1, Retail).** On a raid boss, with the emote callout on
  the pad → its button carries the padlock and its tooltip ends *Locked: Say, Yell and Emote are blocked
  during this encounter.*; the lockdown chip shows as for a Say callout (SEND-7). Kill the boss or wipe
  → the padlock clears. Record whether the game actually refuses the emote during the encounter.
  Result: passed (owner, 2026-11-10)

- **EMOTE-3. A game emote callout performs the game's emote (QFE-E2).** Out of combat in the open
  world, target a nearby player or NPC, and edit a callout in a group on your pad → the **Channel**
  dropdown lists **None (no chat line)** last (the game-emote kind, relabeled by combined actions D10).
  Pick it → the Text box is hidden; the **Emote (optional)** box stays. Type
  `po` → a list hangs under the box with `/point` among its rows; pick it → the Name, if empty, becomes
  `/point`, and What it sends reads `Emotes: /point`. Save → its Groups row reads `/point  None (no
  chat line)  /point` with the channel in the emote color. Click its button → your character points at your
  target and chat shows the game's own line (`You point at <target>.`), once, with no "interface action
  blocked" and no drop note (`/qc debug on` shows an `Echo` line ending `sent`: the
  `CHAT_MSG_TEXT_EMOTE` echo is matched). With no target it points ahead as `/point` typed does.
  Repeat on WoW Forever. Result: owed (passed by the owner 2026-11-10; CA-M2-7 changed the editor it
  walks through)
- **EMOTE-4. The picker's order, its voice marks and the name rule (QFE-E2).** In the Emote (optional)
  box type `o` → the first rows are speech emotes (`/incoming (voice)`, `/oom (voice)`...), then the
  animated ones (`/bow`, `/point`...), then the rest; the arrow keys and Enter pick from the
  list. Rename the callout `Look`, then pick `/wave` → the name stays `Look`. Pick `/oom` on a new
  callout → What it sends adds *A voice emote: it also plays its sound.*; its button plays the voice
  line. Typing `/wave` and pressing Enter without picking a row also picks it. Switch the channel back
  to Say and type a text → the Text box returns and the emote stays; Save → one press says the text
  and waves (combined actions, #16). Empty the emote box and Save → `/qc get callout.emote <id>`
  prints false. Result: owed (passed by the owner 2026-11-10; CA-M2-7 kept the emote beside the Line)
- **EMOTE-5. Preview, throttle and an unknown token (QFE-E2).** Turn on **Preview as... → World** and
  click the `/point` button → one `[QC] would emote /point` line and no emote. Turn preview off and
  press it twice quickly → the second press is dimmed by the guard as for chat. Then run
  `/qc set callout.emote <id> NOTANEMOTE` → the button shows as unavailable and its tooltip reads
  *This game emote is not on this client.*; the callout editor's What it sends adds *Emote token:
  NOTANEMOTE*; its Groups row reads `NOTANEMOTE (not on this client)`. Result: passed (owner, 2026-11-10)
- **EMOTE-6. A game emote during an encounter (QFE-E2, Retail).** On a raid boss → the `/point`
  button carries the padlock as a Say callout does (EMOTE-2). Record whether the game would refuse
  `/point` typed by hand during the encounter: if it does not, the lock is stricter than it needs to be
  and is a follow-up. Result: passed (owner, 2026-11-10)
- **EMOTE-7. The Emotes set in the open world (QFE-E3).** On a fresh profile (or after **Restore
  built-in groups**), out of combat in the open world, solo → the pad shows an **Emotes** section right
  after Solo: twenty buttons, the voice ones first (Incoming, Charge, Attack target, Open fire, Out of
  mana, Heal me, Help me, Flee, Wait, Follow me), then Wave, Hello, Thank you, Cheer, Bow, Point, Dance,
  Ready, Laugh and Bye, each with its own tinted icon; the dial offers the same group. Join a party
  in the open world → Emotes still shows (any group size). Enter a dungeon → it is gone. Click **Out
  of mana** → your character says the out-of-mana voice line and chat shows the game's own line, once,
  no drop note; **Point** with a target → you point at it. Delete the Emotes group, `/reload` → it
  stays gone; **Restore built-in groups** → it is back with all twenty. Repeat on WoW Forever.
  Result: passed (owner, 2026-11-10)
- **EMOTE-8. An existing profile gains Emotes once (QFE-E3, step 19).** On a profile saved before this
  build (Solo on the pad) → after the update the pad lists Emotes right after Solo and nothing else
  moved; an edited Solo callout keeps its text. Delete Emotes and `/reload` → it does not come back.
  Result: passed (owner, 2026-11-10)
- **EMOTE-9. Shipped callouts emote with their line (QuickComms#20, combined actions §8).** On a fresh
  profile (or after **Restore built-in groups**) → in the callout editor, each of these carries its
  emote: Solo's Rare spotted (POINT), Elite help (HELPME) and Thanks (THANK); In Group's Hello (WAVE), Ready
  (READY), GLHF (CHEER), tyff and ggty (THANK) and ggnt (BYE); Dungeon's Pulling (CHARGE) and Need mana
  (OOM); Raid's Wipe (FLEE). Dungeon lists **Heal me** (*Need heals!*, Smart group) last, and Raid
  lists **Heal me** (*Need heals on me!*, Raid) right after Healthstones, before Pull in 10; both with
  the green heart-plus icon and the HEALME emote. Each sends its line and then its emote on one press,
  once each, with no drop note. In a key, outside a boss, Pulling and Heal me show no padlock and both
  actions go; during a boss, the emote's lock note prints. Note any token that gives no emote line in
  chat without a target. Repeat on WoW Forever (no listed set is skipped there). Result: owed
- **EMOTE-10. An existing profile gains them once (step 20).** On a profile saved before this build,
  with In Group's Ready text edited, Hello renamed, the Raid set deleted and Solo's Thanks deleted →
  after the update and a `/reload`: every unedited listed callout carries its emote, once; the edited
  Ready does not; the renamed Hello does; the Raid set stays deleted; Thanks does not come back; Dungeon
  gains **Heal me** once, after Kick order. A second `/reload` changes nothing. Repeat on WoW Forever.
  Result: owed

## Combined actions

**Client: Retail, then WoW Forever**, every check here (QuickComms#16, the combined-actions design
`docs/superpowers/specs/2026-11-10-combined-actions-design.md` §2 to §4 and §7). **Code:**
`modules/Bake.lua` (`B.BakeActions`, `B.MAX_MACRO`), `modules/Surfaces.lua` (`S.ApplyActions`),
`modules/SendEngine.lua` and `modules/SendEngine_Guard.lua` (one result per press), `settings/CalloutPopup.lua`
(the four action slots), `settings/Callouts.lua` (What it sends), `modules/Pad_Render.lua` (the tooltip)
and `settings/SlashVerbs.lua` (`/qc check`).

**Set-up, for every check here.** Edit a callout in a group on your pad → the popup draws Name | Channel,
Text, **Emote (optional)** across both columns, then **Ping** | **Raid marker**. Set the Name `Kick`,
Channel Party, Text `Kick on me`, the emote `/point`, Ping Attack and Raid marker Skull, and Save → What
it sends opens with `"Kick on me" in Party, /point, ping Attack, mark Skull`, lists each action with its
bytes, `Macro: <n> of 255 bytes` and *Needs a target when pressed.*; its Groups row ends `+/point +ping
+{rt8}`. `/qc check <id>` → `<id> -> 4 actions`, then `line: /p Kick on me, 13 of 255 bytes`,
`channel: party`, `emote: /point, 6 of 255 bytes`, `ping: /ping [@target,exists] 1, 24 of 255 bytes`,
`marker: /tm [@target,exists] !8, 23 of 255 bytes` and `macro: 69 of 255 bytes`. Hover its button → one
row per action, `Channel: Party` under the line only.

- **ACTION-1. One press sends all four (#16 AC).** Out of combat, in a party, with a target → one press
  sends `Kick on me` to party, you point at the target, the Attack ping lands on it and the skull marks
  it, with no "interface action blocked" and no drop note. The button flashes once and the guard dims
  every button once; `/qc debug on` shows one press and one `sent`. Result: owed
- **ACTION-2. The same callout in combat.** As ACTION-1, in combat → all four go out, with no taint or
  blocked-action error. Result: owed
- **ACTION-3. No target.** As ACTION-1, with no target → the line and the emote go out (the emote with no
  target, as typed), and chat shows `[QC] Kick: no target to ping.` and `[QC] Kick: no target to mark.`;
  no ping lands on a unit you did not pick and nothing is marked (`exists`). Result: owed
- **ACTION-4. The macro cap (D13, UNVERIFIED).** Set the Text to a 250-byte line, keep the emote and the
  ping, clear the marker → What it sends reads `No line: Too long to send with its other actions.` and
  `253 of <n> bytes`, the Line's share of the macro (`/qc check <id>`: `line: not sent here (tooLong),
  253 of <n> bytes`), and the others still bake; a press performs the emote and the ping and sends no line. Then, on a dev build
  with `B.MAX_MACRO` raised, check whether a 300-byte, four-line macro runs in full: if it does, the
  total cap is larger than 255 and `MAX_MACRO` can be raised (the re-check trigger in
  `known-limitations.md`). Result: owed
- **ACTION-5. Say and an emote outdoors (UNVERIFIED).** In the open world, solo or grouped, a callout with
  Channel Say and the emote `/wave` → one press says the line and waves: the one hardware event covers
  the second line. Result: owed
- **ACTION-6. During a boss encounter (UNVERIFIED).** A Line, an emote and a ping on one callout, pressed
  on a boss → record which of the three go out (the encounter's throttle and chat lockdown), and whether
  the press reports `sent` or one drop note naming what dropped. Result: owed
- **ACTION-7. A locked Line beside a marker.** A callout with Channel Say and Raid marker Skull, pressed
  under a chat lockdown (a raid boss), with a target → chat shows `[QC] <name> may not have been sent.`
  with the lock's reason, the skull still lands, and no drop note follows for the Line. Result: owed
- **ACTION-8. A legacy game-emote callout.** On a profile saved before this build, a Game emote callout
  (EMOTE-3) still performs its emote on a press. Its editor shows Channel **None (no chat line)**, the
  Text box hidden and the emote in **Emote (optional)**; its Groups row names the channel *None (no chat
  line)*. Result: owed

## Pings

**Client: Retail, then WoW Forever**, every check here (QuickComms#17, the combined-actions design
`docs/superpowers/specs/2026-11-10-combined-actions-design.md` §5). **Code:** `modules/Bake.lua`
(`B.BakeActions`: `/ping [@target,exists] <n>`), `core/Compat.lua` (`PingCommand`, `PingState`,
`TargetExists`), `modules/SendEngine.lua` (`SE.PressNotes`, read in `PreClick`; the synthetic `sent`, D16),
`modules/Preview.lua` and `settings/SlashVerbs.lua`.

**Set-up, for every check here.** A ping callout: take a Game emote callout on your pad (EMOTE-3), then
`/qc set callout.ping <id> attack` and `/qc set callout.emote <id> none`, so its one action is the Attack
ping (`/qc set callout.ping <id> warning|onmyway|assist` for the others). Run these checks on the build
where callouts combine actions (CA-M2-1 and later): the M1 build's one-action rule refuses the first
command. `/qc check <id>` → `<id> -> /ping [@target,exists] 1` and `action: ping, <n> of 255 bytes`.

- **PING-1. Solo, with a target, each of the four types (#17).** Out of combat in the open world, solo,
  target a nearby NPC and press the callout once for each of Attack, Warning, On my way and Assist, a few
  seconds apart → each places its ping on the target, with no "interface action blocked" and no drop
  note; the button flashes once per press and the guard dims once. Turn on **Preview as... → World** and
  click it → one `[QC] would ping Attack on your target` line and no ping. Record whether a solo ping
  shows at all (UNVERIFIED: solo pinging). Result: owed
- **PING-2. In a party, in combat (#17 AC).** In a party, in combat with a target → the press places the
  ping on the target and a party member sees it; no taint or blocked-action error. Result: owed
- **PING-3. WoW Forever: the ping is placed and seen (R5).** On a live Forever client, in a party with a
  target → is the ping placed, and does a party member see it? Record both (UNVERIFIED: server
  delivery); a failure narrows #17's AC on Forever. Result: owed
- **PING-4. During an encounter lockdown (D25).** On a raid or dungeon boss, with a target → record whether
  the ping is placed. If the encounter blocks `/ping`, a `LOCKS.ping` row is the follow-up. Result: owed
- **PING-5. Pings off, and on cooldown (D17).** Turn off the game's Enable pings option and press → chat
  shows `[QC] <name>: pings are turned off.` and nothing is pinged; turn it back on. Press quickly
  several times on a target → once the client's cooldown runs, `[QC] <name>: your ping is on cooldown.`
  prints; a single press off cooldown prints no false cooldown note. With no target →
  `[QC] <name>: no target to ping.` and nothing is pinged on a unit you did not pick (`exists`). Record
  whether the client prints an error of its own on a refused ping (if it prints nothing,
  `PING_SYSTEM_ERROR` is a follow-up). Result: owed

## Raid markers

**Client: Retail, then WoW Forever**, every check here (QuickComms#18, the combined-actions design §6).
**Code:** `modules/Bake.lua` (`B.BakeActions`: `/tm [@target,exists] !<n>`), `core/Compat.lua`
(`MarkerCommand`, `TargetExists`, `CanMark`, `MarkerRights`, `InRaid`, `EveryoneAssistant`),
`modules/SendEngine.lua` (`SE.PressNotes`), `modules/Preview.lua` and `settings/SlashVerbs.lua`.

**Set-up, for every check here.** A marker callout, as for the pings: a Game emote callout, then
`/qc set callout.marker <id> 8` and `/qc set callout.emote <id> none`, so its one action is Skull (1 star
to 8 skull). On the build where callouts combine actions (CA-M2-1 and later), as above. `/qc check <id>`
→ `<id> -> /tm [@target,exists] !8` and `action: marker, <n> of 255 bytes`.

- **MARK-1. Solo, marking a target (#18).** Out of combat in the open world, solo, target a nearby NPC and
  press → the skull lands on it, with no "interface action blocked"; the button flashes once (D16: no
  echo is awaited). Turn on **Preview as... → World** and click it → one `[QC] would mark your target`
  line ending in the skull icon, and nothing is marked. Record whether a solo mark lands (UNVERIFIED: solo
  rights). Result: owed
- **MARK-2. In a party, as a non-leader.** In a party you do not lead, with a target → the mark lands and
  no rights note prints. Result: owed
- **MARK-3. In a raid, without assist and with it.** In a raid, without leader or assist (and Everyone is
  assistant off) → `[QC] <name>: you need leader or assist to mark in a raid.` prints and no mark lands.
  Given assist → no note, and the mark lands. With Everyone is assistant on and no assist → no note, and
  the mark lands. Result: owed
- **MARK-4. A second press keeps the mark (`!N`).** Press it twice on the same target → the skull stays
  on; the second press does not clear it. Result: owed
- **MARK-5. No target, and a target that cannot be marked.** With no target → `[QC] <name>: no target to
  mark.` and nothing is marked. Target a unit that cannot carry a marker → `[QC] <name>: that target
  cannot be marked.` Result: owed
- **MARK-6. WoW Forever: `/tm` is the command (UNVERIFIED).** On Forever, `/qc check <id>` → the line
  opens with the client's own marker command, and a press marks the target. Result: owed
- **MARK-7. Marking in combat, and during a boss encounter (R4).** In a party, on both clients: press on a
  target in combat, then during a boss encounter → record whether the mark lands and whether any taint or
  blocked-action error shows (`SetRaidTarget`'s restrictions; the secret `GetRaidTargetIndex` compare in
  `/tm`'s `!` branch). A failure narrows #18's AC. Result: owed

## Auto-thank

**Client: Retail, then WoW Forever**, every check here (QuickComms#19, the combined-actions design §9 and
§13). **Code:** `modules/AutoThank.lua` (the filter, the unit-filter frame, the after-combat diff),
`modules/AutoThank_Toast.lua` (the toast, its pump, Hold and Release, the fade), `core/ToastSetup.lua`,
`modules/SendEngine.lua` (`SE.NewThankButton`, `pressThank`), `core/Compat.lua` (`AuraCaster`,
`AuraByInstance`, `HelpfulAuraIds`, `WhisperName`, `WhisperCommand`) and `settings/AutoThank.lua` (the
Auto-thank page). **Set-up:** a fresh profile (auto-thank on, the open world alone, Emote), and a second
character or a stranger who can cast a long buff on you.

- **THANK-1. A stranger's buff, thanked (#19).** In the open world, out of combat, not grouped, a stranger
  casts Arcane Intellect on you → one toast: the buff's icon and *<name> buffed you with Arcane
  Intellect*. Click **Thank** → you `/thank` them (the client's own emote line in chat), and the toast
  goes. Again, and leave it → it fades over its last two seconds and goes after about ten; hovering it
  holds it. Result: owed
- **THANK-2. Whether the caster reads for a stranger (R1).** With friendly nameplates off and the stranger
  not your target, then targeted: run `/dump C_UnitAuras.GetAuraCasterGUID("player", <id>)` first and the
  aura's `sourceUnit` second (`/dump C_UnitAuras.GetAuraDataByAuraInstanceID("player", <id>).sourceUnit`),
  and record each answer both ways; then record `GetPlayerInfoByGUID(<guid>)`'s name and realm (the 6th and
  7th returns) for that stranger. A caster that reads in neither way shows no toast. Result: owed
- **THANK-3. `/thank Name` out of range or out of sight (UNVERIFIED).** Let the stranger walk out of range,
  or behind a wall, before you click Thank → record whether the emote names them or falls back to the
  untargeted form. Result: owed
- **THANK-4. The whisper and the emote reach a cross-realm caster.** Set Thank button sends to Whisper →
  a click whispers *Thanks for the Arcane Intellect, <name>!*, the whisper reaches the caster and no drop
  note prints (the echo is matched). On Retail use a cross-realm caster whose realm name has a space; on
  Forever a "First Surname" caster. Then Emote: `/thank Name-Realm` lands on the cross-realm caster on
  Retail, and `/thank First-Surname` on Forever. Then Both: one click sends the emote, then the whisper.
  Result: owed
- **THANK-5. A buff mid-fight.** Get buffed by a stranger while in combat → no toast in combat; one after
  it. Repeat after a `/reload` in combat (the toast still comes after the fight). Result: owed
- **THANK-6. A burst is throttled.** Five strangers buff you in a burst → at most three toasts on screen,
  about a second and a half apart, and the rest after, never five at once. Result: owed
- **THANK-7. Raid buffs only.** Tick **Filter → Raid buffs only** → Arcane Intellect, Power Word: Fortitude
  and Mark of the Wild from a stranger toast and no other buff does, on Retail and on Forever (whose list
  holds every rank of the three; UNVERIFIED ids). Record any of the three that does not toast. Result: owed
- **THANK-8. Where it stays quiet.** In a dungeon (off by default) → no toast. In the open world: a buff
  you cast on yourself, a group member's buff and a pet's buff → no toast. Result: owed
- **THANK-9. Combat starts with a toast up.** With a toast on screen, pull a mob → the toast goes at once
  with no "interface action blocked" or taint error, and comes back after the fight. Result: owed
- **THANK-10. A right-click dismisses.** Right-click a toast → it goes and nothing is sent. Result: owed
- **THANK-11. Thank does not trip the spam guard.** Click Thank, then press a pad button at once → the pad
  press is sent and not "guarded". Result: owed
- **THANK-12. The mute modes.** Set **Mute → Strangers**: a stranger's buff shows no toast, a friend's and a
  guildmate's do. Set **Friends and guild**: a friend's buff and a guildmate's buff show no toast, a
  stranger's does. This confirms `C_FriendList.IsFriend(guid)` and `IsGuildMember(guid)` answer for a
  GUID. Result: owed

## Pending sign-off

The owner ran every check above on 2026-10-21 and reported all of them passed (the client build was
not recorded). A check added or rewritten later is listed here, with its origin
and why it is owed, until its pass is recorded.

EDIT-18, PREVIEW-10, PREVIEW-11, PREVIEW-12, SEND-6, STATE-6 and TOKEN-1 (QC-07 and QF-01 to QF-07)
passed in the owner's run of 2026-10-24. PREVIEW-11's locked-window tooltip was reworded, and made to
show on the disabled controls, after that run, on the owner's request; the owner's later pass of the
same day covers the reworded check.

On 2026-10-24 the owner reported that every check of the keybindings, settings layout and frame
layering run passed (KEY-4 to KEY-6 with the one-key-button follow-up QC-RV3, LAYOUT-1 to LAYOUT-5
and LAYER-1 to LAYER-4), recorded on each check's Result line.

On 2026-10-25 the owner reported that every check of that day's run (Preview as for the whole
season, nested groups A–Z, unpinned dial rings, battleground colors) passed: EDIT-32 and PREVIEW-2
(rewritten for the season's dungeons and Mythic raids), EDIT-33 (new), DIAL-4, BG-1, BG-4, BG-5, BG-7
and BG-8 (rewritten for unpinned rings and the new action colors) and BG-9 (new), recorded on each
check's Result line.

The owner reported later on 2026-10-25 that every check of the review and audit fixes passed:
SEND-6 (rewritten for the client-confirmed General, F-007), and new SEND-7 (the lockdown lift,
F-003), PAD-16, PAD-17 and DIAL-42 (parked buttons, F-006), DIAL-43 and SHINE-4 (the cheaper
repaints, F-001), DEGRADED-2 (audit QC-17), EDIT-34 (audit QC-19) and LAYER-5 (audit QC-21),
recorded on each check's Result line.

Owed from the texture folders of 2026-10-25: ART-2 (new).

On 2026-10-30 the owner reported that every check of the skinning rollout (QC-05, 2026-10-29,
Ka0sAddonsCommonTasks `docs/2026-10-29-SKINNING_ROLLOUT/`) and the library follow-ups (QC-02,
2026-10-30, `docs/2026-10-30-SKIN_LIBRARY_FOLLOWUPS/`) passed: SKIN-1 to SKIN-23 (new; SKIN-3, SKIN-5,
SKIN-8 to SKIN-12, SKIN-14 and SKIN-17 then rewritten for LibKa0s v1.81.0); EDIT-9, EDIT-13 and
EDIT-14 (the popup and the browser in the Ka0s window under Ka0s Default); LOOK-1, LOOK-2, LOOK-3,
BUTTON-1, ICONS-1 and ART-1 (amended for the *Use the skin's ...* boxes); and LOC-1 (its fonts note),
each recorded on its Result: line as pass (owner-marked 2026-10-30).

The owner reported on 2026-10-31 that the smoke lists of both of that week's font runs passed
(Ka0sAddonsCommonTasks `docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK/` and
`docs/2026-10-31-FONT_PICKERS_AND_SKIN_FACES/`, "everythings works as expected"): SKIN-24 to SKIN-28 and
ICON-5 (new, QC-01 and QC-02), LOC-1, SKIN-1, SKIN-2, SKIN-3, SKIN-5 and SKIN-10 (amended for v1.82.0's
faces), SKIN-4, SKIN-5 and SKIN-11 (re-opened by QC-F01) and SKIN-29 (new, QC-F02), recorded on each
check's Result line.

Owed from the findings remediation (FX-QC-PERF, 2026-10-31): LOOK-7 (new).

Open from the same run's re-cut v1.84.0 (M3-MEDIA, `Ka0sMedia_*` the only media picker): SKIN-30 is new.

Owed from issue #14 (2026-11-01): LAYER-6, LAYER-7, LAYER-8, LAYER-9 (new).

Owed from issue #13 (2026-11-01): ANIM-1 to ANIM-20 (new; the pad ruling reshaped them before any was run, ANIM-12 is the shimmer and truncation fix, and ANIM-13 to ANIM-20 are the styles, with ANIM-17 and ANIM-18 the first in-game trials).

Owed from the full skin (FS-QC-REC, 2026-11-01): FSKIN-1 to FSKIN-11 (new); SKIN-5, SKIN-11, SKIN-12 and SKIN-13
(their expected result changed, so each lost its pass mark).

Owed from the pad's looks (FS-QC-FIX, 2026-11-01): PLOOK-1 to PLOOK-11 (new); BUTTON-1 and SHINE-1 (their
expected result changed, so each lost its pass mark). The re-cut LibKa0s v1.85.0 gives four skins a border
style of their own, and PLOOK-3, 5, 7 and 8 are written for it.

Owed from the owner's third smoke round (R3-FRIZ, 2026-11-02): FSKIN-13 (new); SKIN-5 names Ka0s Ubuntu for WoW Default and stays owed.

Owed from the owner's fourth smoke round (R4-SEP and R4-ZOOM, 2026-11-03, Ka0sAddonsCommonTasks `docs/2026-11-03-SMOKE_ROUND4/`): SKIN-31 and ICONS-6 (new).

On 2026-11-02 the owner reported that every check on the smoke lists of the full skinning run and its smoke feedback batch (Ka0sAddonsCommonTasks `docs/2026-11-01-FULL_SKINNING/` and `docs/2026-11-01-SMOKE_FEEDBACK/`) passed, apart from DpsRace's clock font, the skinned look of the AceGUI Dropdown and the Ka0sMedia_Font and Ka0sMedia_Statusbar pickers, FadeNineSlice and IconBorder (`docs/2026-11-02-SMOKE_ROUND3/`, R3-SMOKE). Passed, recorded on each `Result:` line as `Passed (owner, 2026-11-02)`: ANIM-1, ANIM-2, ANIM-3, ANIM-4, ANIM-5, ANIM-6, ANIM-7, ANIM-8, ANIM-9, ANIM-10, ANIM-11, ANIM-12, ANIM-13, ANIM-14, ANIM-15, ANIM-16, ANIM-17, ANIM-18, ANIM-19, ANIM-20, ANIM-21, ANIM-22, BUTTON-1, FSKIN-1, FSKIN-2, FSKIN-3, FSKIN-4, FSKIN-5, FSKIN-6, FSKIN-7, FSKIN-8, FSKIN-9, FSKIN-10, FSKIN-11, FSKIN-12, LAYER-6, LAYER-7, LAYER-8, LAYER-9, PLOOK-1, PLOOK-2, PLOOK-3, PLOOK-4, PLOOK-5, PLOOK-6, PLOOK-7, PLOOK-8, PLOOK-9, PLOOK-10, PLOOK-11, SHINE-1, SKIN-6, SKIN-11, SKIN-12 and SKIN-13. Still owed: SKIN-5, whose expected result the third smoke round itself changed after the owner's run.

Owed from the owner's fifth smoke round (Ka0sAddonsCommonTasks `docs/2026-11-03-SMOKE_ROUND5/`): SKIN-32 (new, R5-RV); SKIN-33 (new, R5-WIN); PLOOK-12 (new, R5-QC1); ICONS-7 (new, R5-ICON); PLOOK-1 to PLOOK-9, ANIM-22 and FSKIN-12 (R5-QC1 changed their expected result, so each lost its pass mark); LOOK-3, FSKIN-1 and FSKIN-2 (the R5-QC1 review found their expected result stale against the header's band, so each lost its pass mark).

Owed from the owner's sixth smoke round (Ka0sAddonsCommonTasks `docs/2026-11-03-SMOKE_ROUND6/`): SKIN-34 (new, R6-RV); SKIN-35 (new, R6-PV); PANEL-4 (new, R6-RV2).

Owed from the WoW Forever port (QFE-F2, Ka0sAddonsCommonTasks `docs/2026-11-10-QUICKCOMMS_FOREVER_EMOTES/`): FOREVER-1 to
FOREVER-11, new, each with its `Result:` line reading `owed`. From QFE-F3: FOREVER-12 to FOREVER-17, new, each owed. From QFE-F4: ROLE-1 to ROLE-3 (Retail) and
FOREVER-18 to FOREVER-21, new, each owed. From QFE-F5: FOREVER-22 and FOREVER-23, new, each owed. From QFE-E1: EMOTE-1 and EMOTE-2, new, each owed. From QFE-E2: EMOTE-3 to EMOTE-6, new, each owed. From QFE-E3: EMOTE-7 and EMOTE-8, new, each owed. From QFE-C7 (QFE-REV): FOREVER-24, new, owed; FOREVER-14 and FOREVER-15 have a changed expected result and stay owed.

Owed from the Forever ids run (QuickComms#21, FID-1 to FID-3, `docs/superpowers/specs/2026-11-10-forever-ids-design.md`): FOREVER-25, new, owed; FOREVER-13 (the derived lists, by name against the ids record), FOREVER-16 (now `/qc probe ids`, with no travel) and FOREVER-22 (the place probe where you happen to be, beside the ids record), rewritten, each owed. From FID-4 (the design's Revision 2026-11-10, group finder): FOREVER-13 (30 dungeons, 12 raids), FOREVER-16 and FOREVER-25 (the group finder line) have a changed expected result and stay owed.

On 2026-11-10 the owner reported that every check owed from the WoW Forever port and emotes run (Ka0sAddonsCommonTasks `docs/2026-11-10-QUICKCOMMS_FOREVER_EMOTES/`) and the Forever ids run (QuickComms#21) passed. Passed, recorded on each `Result:` line as `passed (owner, 2026-11-10)`: ROLE-1 to ROLE-3, FOREVER-1 to FOREVER-25 and EMOTE-1 to EMOTE-8. FOREVER-16's line also records what the ids record showed.

Owed from combined actions M1 (QuickComms#17 and #18, CA-M1-1 to CA-M1-12, `docs/superpowers/specs/2026-11-10-combined-actions-design.md` §5, §6 and §13): PING-1 to PING-5 and MARK-1 to MARK-7, new, each owed. Each runs on the build where callouts combine actions (CA-M2-1 and later), since the M1 build's one-action rule refuses the set-up's first command.

Owed from combined actions M2 (QuickComms#16, CA-M2-1 to CA-M2-11, the same design §2 to §4 and §7): ACTION-1 to ACTION-8, new, each owed; EMOTE-3 and EMOTE-4 (the callout editor's four action slots and Channel None changed their expected result, so each lost its pass mark). PING-1 to PING-5 and MARK-1 to MARK-7 are runnable from this build on.

Owed from combined actions M3 (QuickComms#20, CA-M3-1 to CA-M3-5, the same design §8 and §10): EMOTE-9 and EMOTE-10, new, each owed.

Owed from combined actions M4 (QuickComms#19, CA-M4-1 to CA-M4-14, the same design §9 and §13): THANK-1 to THANK-12 and FOREVER-26, new, each owed.
