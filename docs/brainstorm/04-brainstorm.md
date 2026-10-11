# Brainstorm: how Ka0s Quick Comms should behave, look and feel

This is the thinking stage, not a spec. Every section ends with the questions it raises. The mockup ([`mockup/index.html`](mockup/index.html)) shows the ideas in a clickable form.

## Decisions so far (owner, 2026-10-11)

| # | Question | Decision |
|---|---|---|
| D1 | Naming | **Callout** for a single message, **Group** for a collection of callouts. "Comms set" and "comms group" are retired. |
| D2 | Dial default | **Categories** (groups on the first ring, callouts in the sub-ring). |
| D3 | Where the dial opens | **Screen centre by default**, with an option for **at cursor**. |
| D4 | Several surfaces | **Yes.** Any number of pads and dials, each with its own group priority list. |
| D5 | Callout extras (variants, confirm, cooldown, mark, keybind) | **None in the first version.** Filed as future enhancements [#1](https://github.com/tusharsaxena/QuickComms/issues/1)–[#5](https://github.com/tusharsaxena/QuickComms/issues/5). |
| D6 | Specific dungeon group vs generic M+ | **Alongside**, ordered by each surface's priority list. A specific group never replaces a generic one. |
| D7 | Built-in sets | **On by default.** Every new profile includes them, and the player can turn them off or customize them. |
| D8 | Callouts in several groups | **Shared.** A group holds references to callouts in one library. Editing a callout changes it everywhere, and the editor shows "used in N groups". |
| D9 | Nested built-in sets in Categories mode | **Open into the top group.** When the highest-priority active group is a battleground node set, the dial opens straight on its node ring, and the centre button goes back to all groups. This is a per-group flag, on for battleground node sets. |
| D10 | Gamepad | **Not in the first version.** Parked in §10. |
| D11 | Faction-aware battleground wording | **No.** |

**Nothing is open except the go/no-go test in §13.** The owner's verdict: if a player-pressed button can't send group chat during a key or a boss pull, the addon is not viable.

---

## 1. What the addon is for

> One keypress or click puts the right sentence in the right channel at the right moment, including mid-pull in a +15 key, where typing is impossible and, in Midnight, addons can't send chat on their own.

Who it serves:
- **Key leaders and raid callers:** "Lust on this pack", "Pulling in 3", "Soak {rt3}".
- **Support players:** "Healthstones down", "Gateway up", "Battle rez used", "OOM, wait".
- **Pug players:** "Thanks all, gg", "First time on this boss, any tips?", "Skipping with invis".
- **PvP players:** "INC {rt8} mid", "Need help at flag".

What success looks like: the player never types the same thing twice, the visible callouts change as soon as they zone in, and sending works in the moments that matter most.

## 2. Vocabulary

**Decided (D1).** The terms below replace *comms set* and *comms group* everywhere.

| Old term | Name | What it is |
|---|---|---|
| comms set | **Callout** | One message: name, text, channel, icon |
| comms group | **Group** | An ordered list of callouts, plus **when** it applies (situations) |
| situations | **Situations** (the "When" tab of a group) | Conditions that switch a group on |
| comms pad / comms dial | **Comms Pad** and **Comms Dial** (together called **surfaces**) | Ways to show the active groups |

The hierarchy is: callouts belong to groups; groups switch on through situations; surfaces show the active groups in priority order.

## 3. The Midnight constraint changes the design

Research note 01 explains the details. In short:
- **During an M+ key, a boss pull or a PvP match**, an addon can't send chat by itself.
- **Secure macro buttons still can** send to party, raid, rw and instance, using text built *before* combat.

Design responses:
1. **All group-channel sends go through secure buttons.** The player never has to think about lockdown for party, raid, rw or instance callouts.
2. **The text is "baked" before combat.** Addon-resolved tokens (player name, key level, dungeon name) are filled in out of combat. Live tokens use the game's own substitutions: `{target}` becomes `%t`, `{focus}` becomes `%f`, and `{rt8}` stays `{rt8}`.
3. **Callouts that can't send right now look locked, not hidden.** In a boss fight a whisper or SAY callout shows a small padlock and the tooltip "Whispers only reach players in this instance during an encounter" (or "SAY is blocked during encounters"). Hiding them would shift the layout and break muscle memory.
4. **There is a visible lockdown chip.** The pad header and the dial centre show a small "LOCKDOWN" chip while restrictions are active, so the behaviour is explained rather than mysterious.
5. **The encounter throttle is visible.** If Blizzard's macro throttle drops a send, the chip or wedge flashes and the chat frame gets a one-line `[QC]` note instead of failing silently. A full per-callout cooldown with a sweep is future work ([#3](https://github.com/tusharsaxena/QuickComms/issues/3)).

**Go/no-go before anything else:** confirm that a player-pressed secure button can send group chat in a key and a boss pull. The test plan and the fallback (real macros) are in §13.

## 4. The Comms Dial

### Feel
Copy what Blizzard's ping wheel does well:
- a dark translucent disc that fades into the world
- thin spokes between wedges
- a large icon on each wedge and a white label outside the disc
- the selected wedge glows gold with a small pointer near the centre
- a round **✕ cancel** hub in the middle

It should look like a sibling of the ping wheel, not an addon frame.

### Interaction
- **Hold to open, release to send** (Quick mode, the default). The dial opens at **screen centre** by default, or **at the cursor** if the player chooses (D3). Release in the centre or press Esc to cancel.
- **Tap with no movement sends the group's first callout.** That makes your most-used callout a one-keystroke action.
- **Relaxed mode** for accessibility: tap to open, click to send.
- **About 300 ms delay before drawing** (from marking-menu research). Experts who flick quickly never see the menu at all; their flick just sends.
- **Number keys 1–8** pick a wedge clockwise from the top. **Mouse wheel** switches pages.
- **Gamepad** is not in the first version (D10). The later idea: the stick selects (with a dead zone), a bumper changes pages.

### How groups map onto the dial
Two modes, chosen per dial. **Categories is the default (D2).**

| Mode | What you see | Good for |
|---|---|---|
| **Categories** (default; Rocket League style) | The top ring shows *groups* ("M+", "Windrunner Spire", "Warlock"). Holding over one opens its callouts as a sub-ring. | Players with many groups active at once |
| **Flat** | The top ring shows *callouts* straight away, filled from the highest-priority group down. A "More ▸" wedge takes the overflow. | Players who want 4–8 favourites on a flick |

**Nested built-in sets (D9).** In Categories mode a battleground node set would go three levels deep (group, then node, then "INC 2"), which research says is hard under pressure. The decision is **open into the top group**: when the highest-priority active group has the flag (on for battleground node sets), the dial opens straight on its ring, and the centre button goes back to all groups. The rejected options were "embed" (nodes share the first ring with other groups) and accepting depth 3.

### Limits (from research note 02)
- **Default 4 wedges.** This matches the ping wheel, uses only on-axis directions, and works on a d-pad.
- The editor allows 4, 6 or 8. **12 only on a ring with no sub-rings.**
- **Depth 2 by default**, depth 3 with a warning in the editor ("Three levels deep is hard to use under pressure").
- 8 × 8 gives 64 slots, which is more than anyone remembers. A second bind or more pages is better than going deeper.

### Several dials (D4)
You can bind **more than one dial** ("Callouts" on G, "Raid lead" on Shift-G), like Overwatch's comm and ping wheels. Each dial has its own key and its own group priority list.

A "mark + callout" wedge (put a skull on the target *and* say "kill {rt8}") is future work: [#4](https://github.com/tusharsaxena/QuickComms/issues/4).

## 5. The Comms Pad

The goal is **sleek, not a wall of buttons**.

### Look
- **Buttons are chips.** Each chip has a square icon tile, a label, and a small **channel tag** on the right edge.
- **Channel tags use WoW's own chat colours:**
  - Party `#AAAAFF`, Raid `#FF7F00`, Instance `#FF7F00`, Raid warning `#FF4800`
  - Say `#FFFFFF`, Yell `#FF4040`, Whisper `#FF80FF`
  - Smart group has a split badge showing which channel it currently resolves to
  Players already read these colours without thinking.
- **The Ka0s skin:** a dark translucent body, 1px edges and a gold hover outline. No bevels or parchment.
- **A thin header** (drag handle) with the active situation as a chip ("M+ · Windrunner Spire +14"), a lockdown chip when relevant, and a collapse toggle.
- **Groups appear either as sections with small caps labels, or as tabs** (one group visible at a time, scroll the mouse wheel over the pad to switch).
- **After a send**, the chip flashes gold. The real chat line appears in the chat frame as usual, so no extra toast is needed. A cooldown sweep is future work ([#3](https://github.com/tusharsaxena/QuickComms/issues/3)).
- **Fade options:** fade out of combat, fade to x% until moused over, or hide when no group is active.

### Layout options

| Option | Values |
|---|---|
| Orientation | Horizontal bar, vertical column, grid (N columns), and maybe an arc (half a dial, pinned to a screen edge) |
| Growth | Left/right/up/down from the anchor |
| Button style | Icon + label, icon only (label in tooltip), label only |
| Size | Scale, spacing, button width |
| Groups | Sections, tabs, or merged into one list |
| Visibility | Always, only in combat, only out of combat, only when a group is active, never (Ka0s standard visibility dropdown) |

### Several pads (D4)
Any number of pads, for example a raid-lead pad by the raid frames and a personal pad by the action bars. Each pad has its own position, layout and group priority list. All of them use the same callout and group library.

## 6. Callouts

### Fields
- **Name** (short label on the button or wedge), **text** (255-character counter, token chips), **channel**, **icon** (game icon picker plus the LibKa0s icon set).

### Channel options
- Say, Yell, Party, Raid, Instance, Raid warning, Whisper target, Whisper focus
- **Smart group:** instance, then raid, then party
- **Smart lead:** raid warning if you're leader or assist, otherwise smart group
- **Solo fallback** for the smart options: do nothing (default), print to self, or Say

### Extras: future enhancements (D5)
None of these are in the first version. They are filed as issues:

| Extra | Issue |
|---|---|
| **Variants:** several texts for one callout, picked at random | [#1](https://github.com/tusharsaxena/QuickComms/issues/1) |
| **Confirm:** a second click before sending (for Raid warning and Yell) | [#2](https://github.com/tusharsaxena/QuickComms/issues/2) |
| **Cooldown:** a per-callout cooldown with a sweep | [#3](https://github.com/tusharsaxena/QuickComms/issues/3) |
| **Mark:** apply a raid marker to the target when sending (secure `raidtarget`) | [#4](https://github.com/tusharsaxena/QuickComms/issues/4) |
| **Keybind:** a direct key for a single callout | [#5](https://github.com/tusharsaxena/QuickComms/issues/5) |

**Countdown** (`/cd 5` as a callout action) is parked in §10. The countdown payload is secret in lockdown, so it needs checking first.

### Tokens
Friendly chips that map to engine or baked values:

| Chip | Becomes |
|---|---|
| `{target}` | `%t` |
| `{focus}` | `%f` |
| `{rt1}`–`{rt8}` | the raid icon |
| `{me}` | your name |
| `{spec}` / `{role}` | your spec / role |
| `{key}` | the key level |
| `{dungeon}` | the dungeon name |
| `{spell:12345}` | the spell link |

## 7. Groups and situations

### What a group holds
- an ordered list of callouts (LibKa0s `ReorderList`)
- a **When** tab with conditions

### The When tab
It looks like the WeakAuras Load tab because WoW players already know it: one row per condition, a checkbox to turn the row on, and a multi-select for values. Rows are ANDed; values inside a row are ORed.

| Condition | Values |
|---|---|
| Content | Open world, Dungeon, Mythic+, Raid, Delve, Scenario, Battleground, Arena, Housing |
| Specific instance | A searchable list of dungeons and raids, by ID |
| Specific boss | Encounter IDs (active between `ENCOUNTER_START` and `ENCOUNTER_END`) |
| Difficulty | Normal, Heroic, Mythic, Keystone (with a level range), LFR, Story, Follower |
| Group | Solo, Party, Raid, Instance group |
| You are | Leader, Assist |
| Class / Spec / Role | Multi-select |
| Character | Specific characters (by `Name-Realm`) |
| Combat | In combat, Out of combat |
| Lockdown | Active, Inactive |

### Resolving priority
1. **Every group whose conditions match is active** (union). A specific group (Windrunner Spire) sits **alongside** the generic one (M+); it never replaces it (D6).
2. **Each surface decides the order**: its own ordered list of groups, set by you. This keeps your idea of "priority of groups inside the pad/dial".
3. **Optional "auto-promote specific" toggle:** a group with a narrower When (for example a specific dungeon) floats above a broader one (any M+) in Flat mode, so the dungeon's callouts get the on-axis wedges. A small badge says why.
4. **Optional "Always" group** for things like "Thanks", "gg", "One sec".

### Making it understandable
- **"Preview as…"** picker at the top of the settings: choose "M+ · Windrunner Spire · Warlock · Party" and the pad and dial preview update live. This is also the Ka0s test mode.
- **"Why is this showing?"** in the tooltip of every pad header and dial hub, listing the groups and which conditions matched.
- **Group list badges:** a green "Active now" dot next to groups that match your current situation.

**Shared callouts (D8).** Callouts live in one library and groups reference them. Editing "Lust here" changes it in every group that uses it, and the editor shows "used in N groups". Built-in sets reference their own read-only callouts. **Customize** copies both the group and its callouts, so a built-in update never changes the player's copy.

## 8. Predefined sets (shipped with the addon)

Quick Comms comes with ready-made groups so it is useful from the first login. Each one already has its **When** conditions filled in.

| Set | Switches on when | Example callouts |
|---|---|---|
| **M+ (generic)** | Mythic+ key active | Pulling next pack · Lust on this pack {rt8} · Wait, need mana · Kick order: {rt1} {rt2} {rt3} · Skipping with invis/shroud · Res me pls · Key time is tight, chain pull · gg, thanks all |
| **Raid (generic)** | In a raid instance | Bloodlust now · Battle rez used on %t · Soak {rt3} · Spread for mechanic · Stack on {rt1} · Healthstones/cauldron down · Pull in 10 · Wipe it, run back |
| **Arena (generic)** | Arena (skirmish or rated, incl. Solo Shuffle) | Trinket used · CC {rt1} now · Swap to %t · I'm in CC · Going for kill on %t · Drink, reset |
| **One per battleground** | That battleground's map ID | Warsong Gulch / Twin Peaks: EFC at {location}, Our FC needs heals. Arathi Basin: INC Stables / Lumber Mill / Blacksmith / Mine / Farm. Similar node or objective sets for Eye of the Storm, Battle for Gilneas, Silvershard Mines, Temple of Kotmogu, Deepwind Gorge, Seething Shore, Deephaul Ravine, Alterac Valley, Isle of Conquest, Ashran and Wintergrasp |
| **PvP (generic BG)** | Any battleground with no specific set, or alongside one | Need help here · INC {rt8} · Hold this · Capping · Defend · Push now |

### Behaviour ideas
- **They are templates, not your data.** Predefined sets are read-only and labelled "Built-in". A **Customize** button copies one into an editable group (and turns the built-in off). New addon versions can then update the built-ins, for example when a battleground or the M+ pool changes, without overwriting your edits.
- **On by default, easy to turn off (D7).** Every new profile starts with all built-ins switched on and placed in the default pad's and dial's priority lists. Each built-in can be toggled in Groups, and its callouts can be hidden one by one without making a copy.
- **They use the same channels as everything else.** M+ uses smart group (party or instance), raid uses Raid, with Raid warning only on lead callouts. Battlegrounds use Instance chat (smart group handles that automatically). Arena uses Party.
- **The battleground node dial is the showcase for nested dials.** In Arathi Basin the top ring lists the 5 nodes on their real compass directions (Stables NW, Lumber Mill N, Blacksmith centre, Mine SE…). The sub-ring is **INC 1 / 2 / 3 / Many / Clear / Help**. Two flicks send "INC 3 Lumber Mill". The same pattern works for any node or objective battleground, and maps onto Rocket League's 4 × 4.
- **The M+ set is generic on purpose.** Per-dungeon sets would be a content treadmill each season. Players can add their own and share them through export strings.
- **Localization:** built-in text ships in English first (Ka0s rule: enUS locale table, keys are the English text). Other locales can follow.

Battleground callouts are faction-neutral: no "our base / their base" wording (D11).

## 9. Settings structure (Ka0s standard)

Blizzard Settings ▸ AddOns ▸ **Ka0s Quick Comms**

| Page | What it holds |
|---|---|
| *Landing* | Logo, tagline, slash command list |
| **General** | **Master controls** tab (standard rows), **Behaviour** tab (solo fallback, lockdown chip, "why" tooltips, sounds) |
| **Callouts** | A nav rail listing every callout (search, filter by channel or group). One editor tab, **Message** (name, text, tokens, channel, icon, preview). An **Extras** tab arrives with #1–#5. |
| **Groups** | A nav rail of groups with an active-now dot. Editor tabs: **Callouts** (ReorderList, add from library), **When** (conditions), **Preview** |
| **Comms Pad** | A nav rail of pads. Editor tabs: **Groups** (priority ReorderList), **Layout** (orientation, growth, style, size), **Look** (fade, visibility, font, colours) |
| **Comms Dial** | A nav rail of dials. Editor tabs: **Groups** (priority ReorderList, Categories (default) or Flat), **Wheel** (slices 4/6/8/12, depth, open at screen centre (default) or cursor, delay), **Binding** (Quick/Relaxed, key, tap action) |
| **Share** | Export and import of callouts, groups and whole layouts as strings (LibSerialize + LibDeflate + `CopyWindow`), plus the **Built-in** sets from §8 (toggle, Customize) |
| **Profiles** | AceDBOptions |

Everything persists in one `QuickCommsDB` profile, so a player's setup follows them across characters, and the **Character** and **Class** conditions do the per-character work.

## 10. Ideas parked for later

- **Callout analytics:** "You used 'Lust on this pack' 212 times." Cheap to collect, and a nice touch on the landing page.
- **An addon-message preview** so the group leader can see which callout pack you run. This is probably blocked in lockdown, so it is low value.
- **Per-dungeon and per-class built-in sets.** Shipping these each season is a content treadmill, so only if players ask for them.
- **Voice line or sound per channel:** a small "sent" sound, off by default.
- **Arc layout** for the pad (a half-dial pinned to a screen edge).
- **Gamepad support** (D10): stick selects a wedge, a bumper pages, and ConsolePort integration.
- **Countdown callout:** `/cd 5` as a callout action, once the lockdown behaviour of the countdown payload is checked.
- **Callout extras:** variants, confirm, cooldown, mark, keybind ([#1](https://github.com/tusharsaxena/QuickComms/issues/1)–[#5](https://github.com/tusharsaxena/QuickComms/issues/5)).

## 11. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Secure `macrotext` no longer works for chat | The dial can't send in keys or boss pulls | Spike first. The fallback is real macros, budgeted (one per *visible* slot, rotated out of combat). |
| Encounter throttle is very tight | Two quick callouts and the second is dropped | Flash and print a `[QC]` note, and queue nothing (a queued send in a boss fight is worse than none). The full cooldown is [#3](https://github.com/tusharsaxena/QuickComms/issues/3). |
| Smart channel sends somewhere unexpected | Embarrassment, as with MultiMeters' AUTO | Always show the *resolved* channel on the tag; never fall back to Say by default |
| Too much configuration | Players give up before the first callout | Built-in M+, raid, arena and battleground sets (§8), sensible defaults, and a pad that works out of the box with an "Always" group |
| Spam reputation | Group members get annoyed | Solo fallback "do nothing" and a visible resolved channel now. Cooldown, variants and confirm later ([#1](https://github.com/tusharsaxena/QuickComms/issues/1)–[#3](https://github.com/tusharsaxena/QuickComms/issues/3)) |

## 12. Open questions

All design questions are answered (D1–D11 at the top). Only the go/no-go test below remains.

## 13. Go/no-go: can a player's button press send group chat during lockdown?

Tracked as [#6](https://github.com/tusharsaxena/QuickComms/issues/6). **Result: GO**: path A works in real M+ and raid encounters (see the results at the end of this section; the full record, raw logs, screenshots and harness source are in [`go-no-go/`](go-no-go/README.md)).

**Why it decides everything.** The addon exists for the moments when Midnight locks addon chat: an active M+ key, a boss pull, a PvP match. If a player-pressed button can't send to party or raid then, the addon is not viable (owner's verdict).

**Why a press isn't automatically enough.** Lockdown checks *whose code* sends, not whether a human clicked. A click that runs addon Lua calling `SendChatMessage` is still blocked. What gets through is a click on a **secure action button**, where the *game* runs a macro on the player's behalf. That is still a manual, one-press-one-message action, never automation, and that is what Blizzard allows.

**Why there is a documented fallback.** Blizzard's published Midnight macro rules (research note 01) state that during encounters macros **can** still send `/p`, `/raid`, `/rw` and instance chat, throttled. So there are two candidate paths:

| Path | How it works | Cost |
|---|---|---|
| **A: secure macro text** | A secure button with `type=macro` and `macrotext="/p …"`, set out of combat | None. Unlimited callouts. |
| **B: real macros** | The addon writes real character or account macros out of combat; secure buttons run them (`type=macro`, `macro=<index>`). MarkerBar works this way in 12.0. | Macro slots (120 account, 30 per character). Budget one per *visible* slot and rewrite them out of combat when the situation changes. |

The addon is dead only if **both** fail, which would contradict Blizzard's published rules. If only A fails, the design survives with B's slot budget.

### Test plan (about 20 minutes in game)

The fastest way to run it is a throwaway test addon, or `/run` lines plus one real macro. It needs one party member, or a follower dungeon for party chat.

1. **Force lockdown without a key.** `/console addonChatRestrictionsForced 1`, then confirm with `/dump C_ChatInfo.InChatMessagingLockdown()`, which should print `true`.
2. **Baseline, which should fail:** a plain addon button whose OnClick calls `C_ChatInfo.SendChatMessage("test A0", "PARTY")`. Expect `ADDON_ACTION_BLOCKED`. This confirms lockdown is real.
3. **Path A:** out of combat, create `CreateFrame("Button", "QCTest", UIParent, "SecureActionButtonTemplate")` with `type=macro`, `macrotext="/p test A"` and `RegisterForClicks("AnyDown","AnyUp")`. Bind a key with `SetOverrideBindingClick`, or click it. Does "test A" arrive in party chat?
4. **Path B:** create a real macro `/p test B` and a secure button with `type=macro`, `macro="<name>"`. Does "test B" arrive?
5. **Repeat 3 and 4 in the real contexts:**
   - during an M+ key, on trash and on a boss
   - in a raid boss pull (LFR is fine)
   - with `/console addonEncounterRestrictionsForced 1`, `addonChallengeModeRestrictionsForced 1`, `addonPvPMatchRestrictionsForced 1` or `addonCombatRestrictionsForced 1` as a cheaper first pass (names confirmed in game, 12.1)
6. **Measure the throttle:** press twice quickly during a boss. How close together can two sends be before the second is dropped?
7. **Tokens:** do `%t` and `{rt8}` expand in the macro path? Does `{g1}`?
8. Reset all the `addon*RestrictionsForced` console variables to 0 afterwards.

**Reading the results:**
- **A works:** go, with the design as written.
- **A fails and B works:** go, and add the macro-slot budget to the design.
- **Both fail:** stop.

### Results, round 1: forced lockdown in a follower dungeon (2026-10-11)

Throwaway harness `QCTest`; channel `/i`; `addonChatRestrictionsForced 1` throughout. Each forced setting was added on top of the previous one, and every button was tested both out of combat and in combat.

| Forced setting | 0: addon Lua | A: secure macrotext | B: real macro | T: tokens |
|---|---|---|---|---|
| `addonEncounterRestrictionsForced` | blocked | **sent** | **sent** | sent |
| `+ addonChallengeModeRestrictionsForced` | blocked | **sent** | **sent** | sent |
| `+ addonPvPMatchRestrictionsForced` | blocked | **sent** | **sent** | sent |
| `+ addonCombatRestrictionsForced` | blocked | **sent** | **sent** | sent |

- Baseline 0 raised `ADDON_ACTION_BLOCKED UNKNOWN()` every time, which confirms lockdown was real.
- A and B each arrived 0.5–0.75 s after the click, every time.
- Tokens: `%t` expands to the target's name, or `<no target>` when there is none. `{rt8}` expands to the skull icon. `{g1}` arrives as `|g|` here; see the correction in round 2.
- Not yet measured: the throttle (clicks were about 1 s apart), a key binding, and a real encounter or key.

**Verdict so far: path A works, so the provisional answer is GO.** It still needs confirming in a real LFR boss and a real M+ key.

### Results, round 2: real LFR boss, no forced settings (2026-10-11)

All forced settings were 0. The status line showed chat lockdown ON and combat yes, so this was the game's own encounter lockdown. The channel was `/i`.

| Button | Result |
|---|---|
| 0: addon Lua | blocked (`ADDON_ACTION_BLOCKED UNKNOWN()`) |
| A: secure macrotext | **sent**, arriving 0.6 s after the click |
| B: real macro | **sent**, arriving 0.6 s after the click |
| T: tokens | sent; `%t` and `{rt8}` expand |

- **`{g1}` correction.** In a raid, `{gN}` expands to the names of the members of raid subgroup N. In round 1 it arrived as `|g|` only because a follower dungeon has no raid subgroups. It is usable in raids, but is noisy and has no use outside a raid.
- **Key binding works.** The fast presses below came from F6, bound with `SetOverrideBindingClick`, pressed during the boss. Each press sent at most once, so key-down and key-up did not double-fire.
- **Throttle.** Three F6 presses on A, 0.27 s apart (777.24, 777.51 and 777.79), produced only **two** messages, arriving at 777.82 and 778.37. One was dropped silently. Earlier, sends about 0.8 s apart all arrived. So the encounter throttle falls somewhere between 0.27 s and about 0.8 s. The design needs a short per-button cooldown (≈1 s) with a visible "sent / dropped" cue, because the game gives no feedback when it drops a message.
- Not yet tested: a real M+ key.

**Verdict: GO on path A, confirmed in a real encounter.** A real M+ key is the last context still to check.

### Results, round 3: real M+ key, no forced settings (2026-10-11)

Channel `/p`. Once the key started, chat lockdown was ON for the whole run, out of combat as well as on trash.

| Context | 0: addon Lua | A / B / T (clicks about 0.5 s apart) |
|---|---|---|
| Out of combat, in the key | blocked | **3 of 3 arrived** |
| Trash | blocked | **3 of 3 arrived** |
| Boss | blocked | **2 of 3 arrived** (825.06 and 825.61); the third is not in the log |

- Each message arrived 0.6 s after the click, as in LFR.
- On the boss, presses 0.5 s apart lost one message. In LFR, presses 0.27 s apart lost one, and presses 0.8 s apart lost none. That fits a boss-only throttle of roughly 0.5–0.8 s; outside a boss, 0.5 s spacing was fine. The design should use a ≈1 s per-button cooldown and show a sent/dropped cue.
- Tokens in a party: `%t` expands, and a player target also gets their class or role icon. `{rt8}` expands to the skull. `{g1}` stays as the literal `{g1}` because a party has no raid subgroups.

## Verdict: GO

Path A (secure `macrotext` on a `SecureActionButtonTemplate`, pressed by the player by click or key binding) sends to party, instance and raid chat during chat lockdown. It worked in a real M+ key (on trash and on a boss), in a real LFR boss, and under every forced restriction. Plain addon Lua is blocked in all of them. Path B also works, but is not needed. **The design stands as written**, with these additions:
1. A ≈1 s per-button cooldown with sent/dropped feedback.
2. `{gN}` is offered only in raids.
