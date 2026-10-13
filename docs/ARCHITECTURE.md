# Architecture — Ka0s Quick Comms

The hub: what this addon is, in ten mandated sections, each a summary with a link to its topic doc.
The design it is being built to is
[`superpowers/specs/2026-10-11-quickcomms-v1-design.md`](superpowers/specs/2026-10-11-quickcomms-v1-design.md),
and the build order is
[`superpowers/plans/2026-10-11-quickcomms-phase-0-1.md`](superpowers/plans/2026-10-11-quickcomms-phase-0-1.md);
this page describes what exists.

## Overview

A Retail addon that puts context-aware group callouts on a Comms Pad and a Comms Dial and sends them
through secure buttons, so they work during chat lockdown in Mythic+ keys, boss pulls and PvP
matches ([`scope.md`](scope.md)). At v0.1.0's scaffold it is the frame those features plug into.

Ace3 (AceAddon, AceDB, AceEvent, AceTimer, AceConsole, AceGUI, AceConfig, AceDBOptions),
LibSharedMedia, LibDataBroker and LibDBIcon are vendored under `libs/`, and so is the whole
LibKa0s v1.71.0 payload, of which twelve majors are wired, one setup file each (`DEPENDENCIES.md`
lists the toolchain):

| Major | Setup file | Gives |
|---|---|---|
| Core | `core/CoreSetup.lua` | the `[QC]` printer, secret-safe stringifier, SafeRegister family, the skin, the close mark, the resize grip |
| Media | `core/MediaSetup.lua` | the icon catalog and the monospace face |
| Env | `core/EnvSetup.lua` | the addon's own TOC metadata and version |
| Pool | `core/PoolSetup.lua` | the frame pool (for the pad's chips and the dial's wedges) |
| Bus | `core/Bus.lua` | the strict message catalog and the tracked receivers |
| Lifecycle | `core/LifecycleSetup.lua` | the stand-down latch |
| Perf | `core/PerfSetup.lua` | the performance harness |
| DebugLog | `core/DebugLogSetup.lua` | the debug console and the diagnostics report |
| Launcher | `core/LauncherSetup.lua` | the minimap button and broker plugin, one object |
| Schema | `settings/SchemaSetup.lua` | the write seam's runtime |
| Options | `settings/OptionsSetup.lua` | the settings panel |
| Slash | `settings/Slash.lua` | the `/qc` dispatcher |

`LibKa0s-Compat-1.0`, `LibKa0s-Item-1.0` and the Widgets majors are vendored and not wired. Each
setup file holds a descriptor and a degradation stub, and `tests/test_surface_parity.lua` holds every
stub to the live surface.

Nothing is drawn on screen yet apart from the settings panel and the minimap button.

## Module Map

Every file, its kind and its TOC position is in [`module-map.md`](module-map.md). In short: `core/`
holds the identity, nine of the setup files, the session state, the addon object and its lifecycle,
and the migration runner; `defaults/` the default values; `modules/` the diagnostics sections;
`settings/` the schema, the panel pages and the slash table. The design's modules (spec §4.3) are
added under `modules/` by the plan's later tasks.

## Settings Schema

One write seam, `NS.SchemaRuntime.Set` (LibKa0s-Schema), reached by the panel, the CLI, the launcher
and the host verbs alike; the rows are `settings/Schema.lua`'s `Settings.Schema` array, today the
composed Master controls rows. Every module reads a setting through `NS.Setting(path)`, which answers
the row's default before the database exists. The reactions every surface shares are
`Settings.REACTIONS`. The path `enabled` is declared `writeThrough` so `/qc enable|disable` still
lands on a load where the composers are hollow (options-ui-§1 route (a)). Shape, defaults and
migrations: [`schema.md`](schema.md); the panel: [`settings-panel.md`](settings-panel.md).

**State written outside the seam** (architecture-§5): `global.minimap.minimapPos` is LibDBIcon's own
write into the table the launcher hands it. No structural registry exists yet; the callout, group,
pad and dial collections arrive with their one registry writer, `modules/Library.lua` (spec §4.3).

## Message Bus

`core/Bus.lua` declares the catalog once, `NS.MSG`, as `Ka0s_QuickComms_<Event>` wire names with one
named sender each. With LibKa0s-Bus present the table is the strict `Catalog` copy, so a mistyped
key raises. Receivers take their own `NS.Bus:NewTarget()`; `NS.StandDown` / `NS.StandUp` take every
tracked registration down and replay it.

| `NS.MSG` key | Wire suffix | Sender | Payload | Consumers |
|---|---|---|---|---|
| `PROFILE_CHANGED` | `ProfileChanged` | `core/QuickComms.lua` `reloadProfile` (every AceDB profile event) | none | none yet; every module that caches a profile value |

The rest of design spec §17's catalog lands with the modules that send it.

## Slash Commands

`/qc`, alias `/quickcomms`. Today the reserved verbs only: `help config enable disable version list
get set reset resetall profile debug diagnostics perf`. The full table, the live-while-disabled set
and the handlers are in [`slash-dispatch.md`](slash-dispatch.md). `enable` and `disable` call the
same handler as the Master controls row and the launcher entry.

## Event Subscriptions

Every game event is declared in `NS.FEATURE_EVENTS` and registered through `NS.SafeRegisterEvent`,
so `OnEnable` and the stand-up register exactly that list and the stand-down unregisters it. The list
is empty at the scaffold; the situation and restriction edges add the first rows.

AceDB's `OnProfileChanged`, `OnProfileCopied` and `OnProfileReset` callbacks are setup and stay up
while disabled. Events the client refuses are kept in `NS.rejectedEvents` and reported by the
`[Init]` summary and the diagnostics report.

## Taint Notes

Nothing secure exists yet: no secure button, no attribute write, no override binding. Settings
writes touch no protected frame. Opening the settings panel is refused in combat by the options
library, which also locks a page shown in combat; the addon adds no lock of its own and never closes
Blizzard's settings window (options-ui-§2). The design's secure rules (spec §9–§11: one secure
writer, baking out of combat, the combat-end queue) are written here when `SendEngine` lands.

## Known Limitations

- v0.1.0's scaffold is the frame of the addon: there is no pad, no dial and no callout yet
  ([`scope.md`](scope.md)).
- The Master controls tab is frameless (no scale, alpha, lock or Reset position) and has no Test mode
  until the Comms Pad gives them something to act on.
- The Profiles page builds only where AceDBOptions and AceConfigDialog resolve, which the headless
  mock does not model; PROFILE-1 is its in-game check.
- The logo is a placeholder generated for the scaffold; the owner may replace the art (regenerate
  the TGAs with the recipe in `DEPENDENCIES.md`).

## Documentation map

Every `.md` under `docs/` appears in exactly one table below. Out of scope and named once each as
directories, never row by row: `docs/audits/`, `docs/reviews/`, `docs/automated-tests/<run>/`,
`docs/perf-analysis/<run>/`, `docs/revendor/<date>-v<tag>/`, `docs/superpowers/` (the design spec and
the implementation plan) and `docs/investigations/`. This addon's own frozen store, `docs/brainstorm/`,
is registered once, as a store, in the Tier 3 table; the documents under it get no row each.

### Required (documentation-§3, Tier 1)

| Doc | Covers |
|---|---|
| `scope.md` | What the addon is for, what exists at this version, and what it deliberately does not do |
| `module-map.md` | Every non-vendored file, its responsibility, and the TOC load order |
| `schema.md` | The SavedVariables shape, every default, and the migration path |
| `settings-panel.md` | The `Page \| Covers` table and the page → tab → row tree |
| `data-flow.md` | How a setting and the stand-down flow today, and the design's callout pipeline |
| `common-tasks.md` | Recipes for the changes made most often here |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `perf-analysis/README.md` | Present | The performance harness is wired (`core/PerfSetup.lua`) |
| `slash-dispatch.md` | Present | 14 commands in `NS.COMMANDS` |
| `profiles.md` | Present | The Profiles page ships in the options UI |
| `debug.md` | Present | The diagnostics dump ships in every addon (debug-logging-§14) |
| `midnight-quirks.md` | Not applicable | The addon carries no client-version workaround of its own yet |
| `compat-layer.md` | Not applicable | No `core/Compat.lua` ships: the addon makes no deprecated or version-variant client call outside LibKa0s's majors yet (compat's applicability condition); the situation task adds the file |
| `message-bus.md` | Not applicable | 1 message is defined, not more than ten |

### Verification and record (documentation-§3)

| Doc | Covers |
|---|---|
| `testing.md` | How to run the harness and lint; the green commit gate and the release gate |
| `smoke-tests.md` | The in-game smoke-test suite |
| `test-cases.md` | The generated case inventory (authoritative pass count) |
| `performance.md` | The addon performance page |
| `automated-tests/README.md` | What the automated-test record is and how to produce it |
| `automated-tests/RESULTS.md` | One row per run; generated by the runner, never hand-edited apart from the watch list's `Disposition` column (automated-tests-§4) |

### Addon-specific (documentation-§3, Tier 3)

| Doc | Covers |
|---|---|
| `brainstorm/` | The pre-scaffold record, kept as history: the research notes, the brainstorm and its decisions D1–D12, the clickable UX mockup and the in-game go/no-go test with its harness and screenshots |

## Documented deviations

The single home for a ratified deviation from the Ka0s WoW Addon Standard (documentation-§3). A
deviation not in this table is not ratified.

None.

### Files over the 1500-line cap

The layout-§1 census of authored `.lua` files over the 1500-line cap. Vendored code (`libs/`,
`tests/_kit/`) is out of scope, and the repository has no generated data.

Nothing is over the cap today.
