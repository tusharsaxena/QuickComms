# Debug — Ka0s Quick Comms

The console is LibKa0s-DebugLog's, built from the descriptor in `core/DebugLogSetup.lua`. The
logging flag is `NS.State.debug`: session-only, default off, never saved, independent of the window.

## Commands

| Command | What it does |
|---|---|
| `/qc debug` | open or close the console window; logging is untouched |
| `/qc debug on` / `off` | turn logging on or off for this session |
| `/qc diagnostics` | write the diagnostics report to the console |
| `/qc debug diagnostics` | the same report; `diagnostics` is tested first |

No other name runs the report: there is no `diag`, `dump` or other alias.

## The diagnostics report (debug-logging-§14)

Both forms run the same report, also reachable from the console's orange **Diagnostics** link. It
runs while the addon is disabled, **turns debug logging on for the session** before it writes when
it is off, **appends** after whatever the console already holds and never clears it, and stays under
the library's cap (a `truncated` line says when it was reached). The library writes the markers, the
identity header (client build, locale, the debug flag, both combat reads, the running LibKa0s minors,
the `[Init]` line) and wraps each section in its own `pcall`.

The addon's sections (`modules/Diagnostics.lua`), in order:

| Section | What it reports |
|---|---|
| `identity` | schema stored and in code, the profile, `enabled`, whether stood down, the latch's holds |
| `settings` | every setting that differs from its default, and `enabled` always; member rows are left out (the `library` section counts the members) |
| `registration` | the declared feature events, whether they are registered, the events the client refused |
| `integrations` | the launcher's registration and button; the callout popup's EllesmereUI skin (`ellesmereui: suite= facade= enabled= applied= failed=`): whether the suite and its Blizzard Skin child are loaded, whether EllesmereUI called back, its `S.IsEnabled()`, whether it painted or failed |
| `situation` | the snapshot: content, instance, difficulty, key level, group, leadership, class, spec, role, combat, and the active lockdown reasons |
| `restrictions` | the restriction state: every reason in effect (Map included), the reason the lockdown chip names, `canSendChat`, and the combat flag as Restrictions reads it (the `PLAYER_REGEN` edge first) |
| `library` | the counts (callouts, groups, pads, dials), `nextId`, `seeded`, and the ids of the active groups under the current situation |
| `surfaces` | the pads built, whether test mode is on, the previewed situation (`previewAs`, or `off`), and per pad its ordered active groups, its stale hint and its lockdown chip (the pads; the dials have their own section) |
| `dials` | each built dial: its id, header (`QuickCommsDial<n>`), key, ring count, the ring it opens on, whether it is open, its ordered active groups, its stale hint and its lockdown chip |
| `bindings` | every override binding the addon holds: the key, and the header and button it clicks |
| `send` | the send buttons and how many are armed, each armed one with its pad or dial, callout and escaped line; the combat-end queue's pending keys; the guard (window, last press, time remaining); the echo tracker's counts (pending, sent, dropped, unknown sender, ignored) |

The report reads state only: it calls no client API that changes anything, takes no hold, starts no
timer and registers no event. It reads no chat and no other addon's data.

## Tags

`Set` (one line per setting written at the seam, one per bulk reset), `Profile`, `Init` (the session
summary, held until logging is turned on), `Migrate`, and the phase 1 feature tags: `Situation`
(each snapshot change, with the cause), `RES` (each restriction change), `Library` (each registry
write and the `Prepare` summary), and phase 2's: `Send` (a button, arm or disarm refused in combat),
`Guard` (a press inside the guard window), `Echo` (a press confirmed `sent` or reported `dropped`),
`Queue` (an entry queued or replaced, the drain, a drop, the held stand-down) and `Pad` (a pad
built or moved, a rebuild run or held for combat, test mode on or off), and phase 4's: `Dial` (a dial
header built, an attribute or header write refused in combat) and `Bind` (the override bindings
applied, logged only on a change, or refused in combat), and phase 5's: `Share` (an export: what it
held and its length); `Library` also logs each import's tally, and the import's field writes share
one `[Set] import share: N rows` line. The libraries add their own: `Cmd`, `Cfg`, `Launcher`,
`Lifecycle`, `Perf`. The design's `Resolver` and `Bake` tags (spec §16) are not used: the resolve
and the bake run inside a rebuild, which `Pad` logs.
