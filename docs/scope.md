# Scope — Ka0s Quick Comms

## What it is for

Quick Comms puts predefined group callouts one click or one keypress away, on a Comms Pad (a strip
of buttons) or a ping-wheel-style Comms Dial, and shows the callouts that fit where the player is
and what they are doing. Every send goes through a secure button, the one path Midnight leaves open
during chat lockdown, so it works for the whole of a Mythic+ key, a boss pull and a PvP match
(design spec §1, in
[`superpowers/specs/2026-10-11-quickcomms-v1-design.md`](superpowers/specs/2026-10-11-quickcomms-v1-design.md)).

v0.1.0's design carries the callout library (callouts shared between groups by reference), the
situation engine and the resolver, the secure send engine with a soft spam guard (dimming and
drop notes; no hard guard in combat, spec §9.2), any number of pads and dials, built-in sets for
Mythic+, raid, arena and battlegrounds, the settings panel with *Preview as…* and *Why is this
showing?*, and export and import strings.

## What exists at the end of phase 1

The data layer: the situation snapshot and the restriction state, the token and channel rules, the
bake (one sanitized macro line per callout), the resolver, the library (the registry writer and its
load pass), the four shipped built-in sets, the Behavior defaults and `/qc check <id>`, which prints
what a callout would send and never sends. Nothing is drawn yet and nothing is sent: the Comms Pad,
the Comms Dial and the send engine are phase 2. The frame they plug into: the settings panel's
landing page, General page (Master controls) and Profiles page, the `/qc` command with the reserved verbs, the launcher, the debug console and
the diagnostics report, the performance harness, the stand-down latch, the message catalog and the
migration runner. The surfaces and the rest of the paragraph above arrive with the plan's later
phases ([`superpowers/plans/2026-10-11-quickcomms-phase-0-1.md`](superpowers/plans/2026-10-11-quickcomms-phase-0-1.md)
for phases 0 and 1).

## What it deliberately does not do

- Send anything the player did not press a button or a key for. There is no automatic callout and
  no addon-side send path besides the secure buttons (design decision D12); `/qc check` prints what
  a callout would send and never sends it.
- Read combat-only data (unit health, auras, cooldowns): those are secret values in Midnight, and the
  situation engine reads only non-secret inputs.
- In v0.1.0: callout variants, confirmations, per-callout cooldowns, marks, a key per callout,
  gamepad support, countdown callouts, an arc layout for pads, analytics, faction-aware wording,
  per-dungeon built-in sets, and any locale beyond enUS (design spec §1). Each is a GitHub issue
  rather than a silent omission.
