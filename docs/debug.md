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
| `integrations` | the launcher's registration and button; the callout popup's EllesmereUI skin (`ellesmereui: suite= facade= enabled= applied= failed= browser= why=`): whether the suite and its Blizzard Skin child are loaded, whether EllesmereUI called back, its `S.IsEnabled()`, whether it painted the popup or failed, whether it painted the icon browser, and `why=`, in words: the first step that stops the skin (EllesmereUI or its Blizzard Skins+ module not loaded, not registered, no callback because its third-party skinning or Quick Comms' entry was off at login, EllesmereUI saying off, a facade missing a primitive, a failed paint), else each window's state (`popup painted; browser not built yet (painted when it is first opened)`) |
| `situation` | the snapshot: content, instance, difficulty, key level, group, leadership, class, spec, role, combat, and the active lockdown reasons |
| `restrictions` | the restriction state: every reason in effect (Map included), the reason the lockdown chip names, `canSendChat`, and the combat flag as Restrictions reads it (the `PLAYER_REGEN` edge first) |
| `library` | the counts (callouts, groups, pads, dials), `nextId`, `seeded`, and the ids of the active groups under the current situation |
| `surfaces` | the pads built, whether test mode is on, the previewed situation (`previewAs`, or `off`), the group the Groups page is previewing (`editPreview`, or `off`), whether this character's pads are hidden (`padsHidden=`), per pad its ordered active groups, its stale hint and its lockdown chip, and per pad its button line (`button shine=`: the Buttons tab's Shine look and strength) (the pads; the dials have their own section) |
| `dials` | each built dial: its id, header (`QuickCommsDial<n>`), key, ring count, the ring it opens on, whether it is open, its ordered active groups, its stale hint and its lockdown chip; the ring on screen (`shown=`, or `closed`); its look (`look`: mode, slices, radius, icon offset, open at; `slices`: slice gap, pointer show, size and offset, slice labels show, size and offset, tooltip side and offset, shine look and strength; `paging`: offset, arrow size and gap, dot size, pill width, dot gap, whether the indicator background shows, its padding, dot border; `hub`: style, size, circle size, line width, border size, and whether group labels show); and one line per ring of its plan (title, page of pages, wedge count, start, item count, and the rings its hub, previous and next lead to) |
| `bindings` | each Open Comms Dial entry and Toggle Comms Pads: the key WoW binds to it (or `none`) and the command (`G -> CLICK QuickCommsDial1:Toggle`) |
| `send` | the send buttons and how many are armed, each armed one with its pad or dial, callout and escaped line; the combat-end queue's pending keys; the guard (window, last press, time remaining); the echo tracker's counts (pending, sent, dropped, unknown sender, ignored) |

The report reads state only: it calls no client API that changes anything, takes no hold, starts no
timer and registers no event. It reads no chat and no other addon's data.

## Tags

`Set` (one line per setting written at the seam, one per bulk reset), `Profile`, `Init` (the session
summary, held until logging is turned on), `Migrate`, and the phase 1 feature tags: `Situation`
(each snapshot change, with the cause), `RES` (each restriction change), `Library` (each registry
write and the `Prepare` summary), and phase 2's: `Send` (a button, arm or disarm refused in combat),
`Guard` (a press inside the guard window), `Send` also logs each press (callout, pad or dial, chat type, and `(disarmed)` when it was not armed), `Echo` (a press confirmed `sent` or reported `dropped`),
`Queue` (an entry queued or replaced, the drain, a drop, the held stand-down) and `Pad` (a pad
built or moved, a rebuild run or held for combat, test mode on or off, and after each rebuild what
every pad shows), and phase 4's: `Dial` (a dial header built, an attribute or header write refused in
combat; since 2026-10-21 also a dial applied at its place (ring count, the ring it opens on, slices,
radius) or released, each open and close, each ring the snippets show (an open, a group wedge, a page
turn), and after each rebuild what every dial shows), `Pads` (`/qc toggle` and the Toggle Comms Pads
key hiding or showing the pads, 2026-10-21: no chat line any more) and `Bind` (the diagnostics report's
bindings section; the Dial page no longer sets a key, since the dial rework of 2026-10-21),. The libraries add their own: `Cmd`, `Cfg`, `Launcher`,
`Lifecycle`, `Perf`. The design's `Resolver` and `Bake` tags (spec §16) are not used: the resolve
and the bake run inside a rebuild, which `Pad` logs.
