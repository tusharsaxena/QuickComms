# Brainstorm: how Ka0s Quick Comms should behave, look and feel

This is the thinking stage, not a spec. Every section ends with the questions it raises. The mockup ([`mockup/index.html`](mockup/index.html)) shows the ideas in a clickable form.

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

Your list says *comms set* for a single message and *comms group* for a collection of them. In English "set" also means a collection, so the two terms invite confusion. A working proposal, used in the mockup:

| Your term | Proposed name | What it is |
|---|---|---|
| comms set | **Callout** | One message: name, text, channel, icon (plus optional extras, §6) |
| comms group | **Callout group** (or just **Group**) | An ordered list of callouts, plus **when** it applies (situations) |
| situations | **Situations** (the "When" tab of a group) | Conditions that switch a group on |
| comms pad / comms dial | **Comms Pad** and **Comms Dial** (together called **surfaces**) | Ways to show the active groups |

The hierarchy is: callouts belong to groups; groups switch on through situations; surfaces show the active groups in priority order.

**Question:** do you want to keep "comms set" and "comms group", or switch to Callout and Group?

## 3. The Midnight constraint changes the design

Research note 01 explains the details. In short:
- **During an M+ key, a boss pull or a PvP match**, an addon can't send chat by itself.
- **Secure macro buttons still can** send to party, raid, rw and instance, using text built *before* combat.

Design responses:
1. **All group-channel sends go through secure buttons.** The player never has to think about lockdown for party, raid, rw or instance callouts.
2. **The text is "baked" before combat.** Addon-resolved tokens (player name, key level, dungeon name) are filled in out of combat. Live tokens use the game's own substitutions: `{target}` becomes `%t`, `{focus}` becomes `%f`, and `{rt8}` stays `{rt8}`.
3. **Callouts that can't send right now look locked, not hidden.** In a boss fight a whisper or SAY callout shows a small padlock and the tooltip "Whispers only reach players in this instance during an encounter" (or "SAY is blocked during encounters"). Hiding them would shift the layout and break muscle memory.
4. **There is a visible lockdown chip.** The pad header and the dial centre show a small "LOCKDOWN" chip while restrictions are active, so the behaviour is explained rather than mysterious.
5. **The encounter throttle shows up as a cooldown sweep.** After a send, the button runs a short radial sweep, like an action bar cooldown, instead of failing silently.

**Spike before anything else:** confirm that secure `macrotext` works in a key and a boss pull. If it turns out to need real macros, the design gets a macro-slot budget (see §10).

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
- **Hold to open, release to send** (Quick mode, the default). The dial opens at the cursor. Release in the centre or press Esc to cancel.
- **Tap with no movement sends the group's first callout.** That makes your most-used callout a one-keystroke action.
- **Relaxed mode** for accessibility: tap to open, click to send.
- **About 300 ms delay before drawing** (from marking-menu research). Experts who flick quickly never see the menu at all; their flick just sends.
- **Number keys 1–8** pick a wedge clockwise from the top. **Mouse wheel** switches pages.
- **Gamepad:** the stick selects (with a dead zone), a bumper changes pages.

### How groups map onto the dial
Two modes, chosen per dial layout:

| Mode | What you see | Good for |
|---|---|---|
| **Categories** (Rocket League style) | The top ring shows *groups* ("M+", "Windrunner Spire", "Warlock"). Holding over one opens its callouts as a sub-ring. | Players with many groups active at once |
| **Flat** | The top ring shows *callouts* straight away, filled from the highest-priority group down. A "More ▸" wedge takes the overflow. | Players who want 4–8 favourites on a flick |

### Limits (from research note 02)
- **Default 4 wedges.** This matches the ping wheel, uses only on-axis directions, and works on a d-pad.
- The editor allows 4, 6 or 8. **12 only on a ring with no sub-rings.**
- **Depth 2 by default**, depth 3 with a warning in the editor ("Three levels deep is hard to use under pressure").
- 8 × 8 gives 64 slots, which is more than anyone remembers. A second bind or more pages is better than going deeper.

### Several dials
You can bind **more than one dial** ("Callouts" on G, "Marks + kicks" on Shift-G), like Overwatch's comm and ping wheels. Each dial has its own group priority list.

**Questions:**
- Should the dial open at the cursor or at screen centre?
- Categories or Flat as the default?
- Should Quick Comms offer a "mark + callout" wedge (put a skull on the target *and* say "kill {rt8}")? 12.0's secure `raidtarget` action makes it possible.

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
- **After a send**, the chip flashes gold and runs a cooldown sweep. The real chat line appears in the chat frame as usual, so no extra toast is needed.
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

**Questions:**
- Should one layout be allowed to show **both** a pad and a dial built from the same groups, or does each surface keep its own group priority list? (I lean towards each surface having its own list, as you described.)
- Do you want more than one pad on screen (for example a raid-lead pad by the raid frames plus a personal pad by the action bars)?

## 6. Callouts

### Fields
- **Name** (short label on the button or wedge), **text** (255-character counter, token chips), **channel**, **icon** (game icon picker plus the LibKa0s icon set).

### Channel options
- Say, Yell, Party, Raid, Instance, Raid warning, Whisper target, Whisper focus
- **Smart group:** instance, then raid, then party
- **Smart lead:** raid warning if you're leader or assist, otherwise smart group
- **Solo fallback** for the smart options: do nothing (default), print to self, or Say

### Optional extras
These came out of the research:
- **Variants:** several texts for one callout, picked at random, so "Thanks!" doesn't read like a bot after the fifth key.
- **Confirm:** require a second click for Raid warning and Yell, to stop misclicks from broadcasting.
- **Cooldown:** a per-callout cooldown to stop spam (the games all use a burst allowance followed by a lockout).
- **Mark:** apply a raid marker to the target when sending (secure `raidtarget`).
- **Keybind:** a direct key for the 2–3 callouts players use most.
- **Countdown:** `/cd 5` as a callout action. The countdown payload is secret in lockdown, so this needs checking.

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

**Question:** variants, confirm, cooldown, mark, keybind and countdown — which of these are in the first version and which are later ideas?

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
1. **Every group whose conditions match is active** (union).
2. **Each surface decides the order**: its own ordered list of groups, set by you. This keeps your idea of "priority of comms groups inside comms pad/dial".
3. **Optional "auto-promote specific" toggle:** a group with a narrower When (for example a specific dungeon) floats above a broader one (any M+) in Flat mode, so the dungeon's callouts get the on-axis wedges. A small badge says why.
4. **Optional "Always" group** for things like "Thanks", "gg", "One sec".

### Making it understandable
- **"Preview as…"** picker at the top of the settings: choose "M+ · Windrunner Spire · Warlock · Party" and the pad and dial preview update live. This is also the Ka0s test mode.
- **"Why is this showing?"** in the tooltip of every pad header and dial hub, listing the groups and which conditions matched.
- **Group list badges:** a green "Active now" dot next to groups that match your current situation.

**Questions:**
- Should a **specific dungeon or boss** group *replace* the generic M+ group, or sit alongside it? I lean towards alongside, with priority.
- Should callouts be able to appear in **several groups** (shared by reference), or should each group own copies? I lean towards by reference, with a "used in N groups" note in the editor.

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
- **On by default, easy to turn off.** Each built-in can be toggled in Groups, and its callouts can be hidden one by one without making a copy.
- **They use the same channels as everything else.** M+ uses smart group (party or instance), raid uses Raid, with Raid warning only on lead callouts. Battlegrounds use Instance chat (smart group handles that automatically). Arena uses Party.
- **The battleground node dial is the showcase for nested dials.** In Arathi Basin the top ring lists the 5 nodes on their real compass directions (Stables NW, Lumber Mill N, Blacksmith centre, Mine SE…). The sub-ring is **INC 1 / 2 / 3 / Many / Clear / Help**. Two flicks send "INC 3 Lumber Mill". The same pattern works for any node or objective battleground, and maps onto Rocket League's 4 × 4.
- **The M+ set is generic on purpose.** Per-dungeon sets would be a content treadmill each season. Players can add their own and share them through export strings.
- **Localization:** built-in text ships in English first (Ka0s rule: enUS locale table, keys are the English text). Other locales can follow.

**Questions:**
- Should built-ins be **on by default** for new users, or offered once through a "pick your packs" step on first login?
- For battleground sets, should Quick Comms track **which side you're on** (Alliance/Horde) to phrase callouts like "our base" or "their base"? This adds complexity for little gain, so I'd leave it out.

## 9. Settings structure (Ka0s standard)

Blizzard Settings ▸ AddOns ▸ **Ka0s Quick Comms**

| Page | What it holds |
|---|---|
| *Landing* | Logo, tagline, slash command list |
| **General** | **Master controls** tab (standard rows), **Behaviour** tab (send safety, solo fallback, default cooldown, sounds) |
| **Callouts** | A nav rail listing every callout (search, filter by channel or group). Editor tabs: **Message** (name, text, tokens, channel, icon, preview), **Extras** (variants, confirm, cooldown, mark, keybind) |
| **Groups** | A nav rail of groups with an active-now dot. Editor tabs: **Callouts** (ReorderList, add from library), **When** (conditions), **Preview** |
| **Comms Pad** | A nav rail of pads. Editor tabs: **Groups** (priority ReorderList), **Layout** (orientation, growth, style, size), **Look** (fade, visibility, font, colours) |
| **Comms Dial** | A nav rail of dials. Editor tabs: **Groups** (priority ReorderList, Categories or Flat), **Wheel** (slices 4/6/8/12, depth, open at cursor or centre, delay), **Binding** (Quick/Relaxed, key, tap action) |
| **Share** | Export and import of callouts, groups and whole layouts as strings (LibSerialize + LibDeflate + `CopyWindow`), plus the **Built-in** sets from §8 (toggle, Customize) |
| **Profiles** | AceDBOptions |

Everything persists in one `QuickCommsDB` profile, so a player's setup follows them across characters, and the **Character** and **Class** conditions do the per-character work.

## 10. Ideas parked for later

- **Callout analytics:** "You used 'Lust on this pack' 212 times." Cheap to collect, and a nice touch on the landing page.
- **An addon-message preview** so the group leader can see which callout pack you run. This is probably blocked in lockdown, so it is low value.
- **Per-dungeon and per-class built-in sets.** Shipping these each season is a content treadmill, so only if players ask for them.
- **Voice line or sound per channel:** a small "sent" sound, off by default.
- **Arc layout** for the pad (a half-dial pinned to a screen edge).
- **ConsolePort integration** for gamepad players.

## 11. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Secure `macrotext` no longer works for chat | The dial can't send in keys or boss pulls | Spike first. The fallback is real macros, budgeted (one per *visible* slot, rotated out of combat). |
| Encounter throttle is very tight | Two quick callouts and the second is dropped | Show a cooldown sweep and queue nothing (a queued send in a boss fight is worse than none) |
| Smart channel sends somewhere unexpected | Embarrassment, as with MultiMeters' AUTO | Always show the *resolved* channel on the tag; never fall back to Say by default |
| Too much configuration | Players give up before the first callout | Built-in M+, raid, arena and battleground sets (§8), sensible defaults, and a pad that works out of the box with an "Always" group |
| Spam reputation | Group members get annoyed | Per-callout cooldown, variants, confirm on RW and Yell |

## 12. The questions in one place

1. Keep "comms set / comms group", or switch to **Callout / Group**?
2. Dial default: **Categories** or **Flat**? Open at the **cursor** or **screen centre**?
3. Allow more than one pad and more than one dial at a time?
4. Which callout extras (variants, confirm, cooldown, mark, keybind, countdown) are first-version material?
5. Should specific-dungeon groups **replace** generic ones or sit **alongside** them?
6. Should callouts be **shared by reference** across groups, or copied into each group?
7. Built-in sets: **on by default**, or a "pick your packs" step on first login?
8. Is gamepad support in scope for the first version?
