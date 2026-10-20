# Scope — Ka0s Quick Comms

## What it is for

Quick Comms puts predefined group callouts one click or one keypress away, on a Comms Pad (a strip
of buttons) or a ping-wheel-style Comms Dial, and shows the callouts that fit where the player is
and what they are doing. Every send goes through a secure button, the one path Midnight leaves open
during chat lockdown, so it works for the whole of a Mythic+ key, a boss pull and a PvP match
(design spec §1, in
[`superpowers/specs/2026-10-11-quickcomms-v1-design.md`](superpowers/specs/2026-10-11-quickcomms-v1-design.md)).

v0.1.0's design carries the callout library (each callout owned by one group, a reuse making a copy;
the 2026-10-17 amendment, which retired callouts shared between groups by reference), the
situation engine and the resolver, the secure send engine with a soft spam guard (dimming and
drop notes; no hard guard in combat, spec §9.2), any number of pads and dials, built-in sets for
Mythic+, raid, arena, battlegrounds and the solo open world (seeded into each profile as ordinary, editable groups; the
2026-10-18 amendment, which retired the read-only built-ins and their Customize), groups nested one
level, the settings panel with *Preview as…* and *Why is this showing?*, and export and import
strings.

## What exists at the end of phase 5

The data layer: the situation snapshot and the restriction state, the token and channel rules, the
bake (one sanitized macro line per callout), the resolver, the library (the registry writer and its
load pass), the four shipped built-in sets, the Behavior defaults and `/qc check <id>`, which prints
what a callout would send and never sends. On top of it, phase 2 built the send engine (secure
buttons, the soft spam guard, the echo tracker, the combat-end queue), the default Comms Pad showing
the active built-in sets, test mode, the lock and the saved position. Phase 3 added the editors: the
Callouts, Groups (with the When editor and a Preview tab), Comms Pad and Share (then with a Built-in tab) pages
(since 2026-10-17 a group owns its callouts, and the callout popup on its Callouts tab replaces the
Callouts page),
"Preview as…" on the pads and `/qc preview`, and "Why is this showing?" on the pad header and
`/qc why`. Phase 4 added the Comms Dial in Relaxed mode: a key (or WoW's key bindings menu) opens it, a click on a wedge sends, a group wedge opens its ring, battleground node sets open straight on their nodes, and the Comms Dial page sets it up. Phase 5 added sharing (an export string and an import that checks, reports and adds what a string holds as new, unbound members), the pad's Look font, border and background with class colors, the icon picker, battleground node sets pinned to their compass winds, and the instance ids matched against the client's data (their in-game confirmation is the smoke test's); since 2026-10-18 the icon browser replaces the inline icon picker (the raid markers, every icon the macro icon selector offers, and every LibKa0s glyph, drawn in a color the player picks); since 2026-10-18 too, the built-in sets are seeded into each profile as ordinary groups (a battleground's nodes as groups inside its set) with Restore built-in groups in place of the Share page's Built-in tab and Customize, any group can sit inside a top-level group (one level), and a group's Preview tab is a table of each callout's name beside what it sends ([`superpowers/plans/2026-10-18-builtins-as-groups.md`](superpowers/plans/2026-10-18-builtins-as-groups.md)); since 2026-10-19 a World (solo) set ships too, the five node battlegrounds carry map-wide callouts of their own (a wedge of their own on the pinned dial), every built-in callout and group draws a colored catalog glyph, the Groups page previews the group it edits on every pad and dial (Preview while editing, on by default), PREVIEW and TEST MODE ride the pad's drag strip, and right-clicking a pad's group title opens that group on the Groups page ([`superpowers/plans/2026-10-19-groups-polish.md`](superpowers/plans/2026-10-19-groups-polish.md)); since 2026-10-20 the battleground sets hold a group per objective, worded the same for either faction (every Alterac Valley general, captain, bunker, tower and graveyard with Attack and Defend, Isle of Conquest's Our base and Enemy base, and objective groups for Warsong Gulch, Twin Peaks, Wintergrasp, Ashran, Deephaul Ravine and Seething Shore), a grid pad sets a parent's small child sections side by side, and schema step 7 brings them to stored profiles ([`superpowers/plans/2026-10-20-bg-subgroups.md`](superpowers/plans/2026-10-20-bg-subgroups.md)); since 2026-10-20 too, every base-capture node (and Isle of Conquest's bases) holds Attack, Defend, INC and Clear as Wintergrasp's workshops do, Silvershard Mines holds its tracks and switches and Temple of Kotmogu its orbs and center, an In Group set (Hello, tyff, GLHF, ggty and the like) is active in any party, raid or instance group, and a pad's drag strip is as wide as the pad; the release gate is green, and v0.1.0 waits for the owner's word. The frame they plug into: the settings panel's
landing page, General page (Master controls) and Profiles page, the `/qc` command with the reserved verbs, the launcher, the debug console and
the diagnostics report, the performance harness, the stand-down latch, the message catalog and the
migration runner. The paragraph above was built in the plan's phases ([`superpowers/plans/2026-10-11-quickcomms-phase-0-1.md`](superpowers/plans/2026-10-11-quickcomms-phase-0-1.md)
for phases 0 and 1, [`superpowers/plans/2026-10-13-quickcomms-phase-2.md`](superpowers/plans/2026-10-13-quickcomms-phase-2.md)
for phase 2, [`superpowers/plans/2026-10-13-quickcomms-phase-3.md`](superpowers/plans/2026-10-13-quickcomms-phase-3.md)
for phase 3, [`superpowers/plans/2026-10-13-quickcomms-phase-4.md`](superpowers/plans/2026-10-13-quickcomms-phase-4.md)
for phase 4, [`superpowers/plans/2026-10-13-quickcomms-phase-5.md`](superpowers/plans/2026-10-13-quickcomms-phase-5.md)
for phase 5).

## What it deliberately does not do

- Send anything the player did not press a button or a key for. There is no automatic callout and
  no addon-side send path besides the secure buttons (design decision D12); `/qc check` prints what
  a callout would send and never sends it.
- Read combat-only data (unit health, auras, cooldowns): those are secret values in Midnight, and the
  situation engine reads only non-secret inputs.
- In v0.1.0: callout variants, confirmations, per-callout cooldowns, marks, a key per callout,
  gamepad support, countdown callouts, an arc layout for pads, analytics, faction-aware wording,
  per-dungeon built-in sets, and any locale beyond enUS (design spec §1), and the hold, flick and
  release dial (C7). Groups nest one level only (2026-10-18 amendment): no group inside a group
  inside a group. Each is recorded here and in the design spec rather than left as a silent
  omission; those with a GitHub issue so far are callout variants (#1), confirmations (#2),
  per-callout cooldowns (#3), marks (#4) and a key per callout (#5). The C7 upgrade has no issue
  yet: its record is the design spec §11.2 (*Upgrade (C7)*) and
  `docs/brainstorm/go-no-go/round-4-build-checks.md`.
