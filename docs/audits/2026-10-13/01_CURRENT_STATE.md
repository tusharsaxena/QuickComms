# 01 — Current state: Ka0s Quick Comms

First standards audit of this addon. Read-only: nothing outside this folder was changed.

## Run identity

| Field | Value |
|---|---|
| Repository | `QuickComms` (`/mnt/d/Profile/Users/Tushar/Documents/GIT/QuickComms`) |
| Branch / commit | `feat/phase-5-share-release` at `be9cf49`, clean tree |
| Addon version | `0.1.0` (TOC `## Version`), unreleased (README Version History: "Unreleased") |
| Repo kind | **Addon**: `dev-copilot-profile` reported `kind=addon` (`reason=toc:## Interface`), and `ADDONS.md` lists *Ka0s Quick Comms* in its in-scope table. Audited against the full addon rule set. |
| Deviation-ID prefix | **`QC-`** (assigned on this first audit) |
| Standard | **v2.80.0 (2026-10-13)**, `standards/STANDARDS.md` line 1 |
| Playbook | `AUDIT.md` from the same checkout |

### Where the standard was read from

The standard was read from the **local working tree** of `WowAddonStandards`
(`/mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards`, `master` at `8aad69d`), **not** from the
raw GitHub `master`, on the owner's instruction. That checkout is **2 commits ahead of `origin/master`**
(`55da22b`): `fcfaf5c` (the roster's launcher entries for Quick Comms) and `8aad69d` (v2.80.0,
*`Bindings.xml` is a client-mandated root file*). `git diff origin/master --stat` touches 10 files,
including `AUDIT.md`, `standards/STANDARDS.md`, `standards/standards/layout.md` and
`standards/standards/toc-file.md`. The difference matters to this addon: v2.79.x's `layout-§1`
("never loose at the root") would forbid the root `Bindings.xml` this addon ships, and v2.80.0 permits
it. Every grade in this bundle is against v2.80.0. All 27 section files under the Sections list, the
index, `AUDIT.md` and `ADDONS.md` were read in full.

## The deviation register and the issue store (read first)

- `docs/ARCHITECTURE.md` → `## Documented deviations` exists and reads **"None."**; its
  `### Files over the 1500-line cap` sub-heading exists and reads "Nothing is over the cap today."
- The issue store (`gh issue list --state all --json …`) holds **7 issues**: #1–#5 and #7 open
  `state:triaged` / `severity:low` enhancements, #6 closed `state:done` / `severity:critical` (the
  go/no-go). Every issue carries exactly one `state:` and one `severity:` label; no `[status]` title
  prefix; no `state:will-not-do` issue, so there is no decline living outside the register.
- No `docs/pending/` directory and no `LEDGER.md`.
- Root `CLAUDE.md` and `docs/scope.md` record no accepted deviation from the standard.

So nothing in this bundle is filed as *accepted*: there are no ratified rows to honor, and no
unratified declines to report.

## Snapshot, section by section

### Layout (`layout`)
- Five source folders plus `media/logos/`, `libs/`, `tests/`, `tools/`, `docs/`. Root holds the TOC,
  `Bindings.xml`, `README.md`, `CLAUDE.md`, `DEPENDENCIES.md`, `LICENSE` and the dotfiles.
- **`Bindings.xml`** (v2.80.0 check): at the root, exactly that name, four `CLICK QuickCommsDial<n>:Toggle`
  bindings carrying no Lua; not in the TOC (`grep -n Bindings QuickComms.toc` is empty); not in
  `.pkgmeta`'s ignore list; labels set from `modules/Dial.lua:42-44` (`BINDING_HEADER_QUICKCOMMS`,
  four `rawset` `BINDING_NAME_*`). **Compliant.**
- `tools/` holds three Python 3 scripts (`client_tables.py`, `derive-gameids.py`, `derive-winds.py`):
  authored, not in the TOC or any load list, `.pkgmeta`-ignored, interpreter named in `DEPENDENCIES.md`.
  They print derived blocks and check the repo, failing with exit 1 on a mismatch. **Compliant.**
- LOC census (default scope, `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`, 110 files): no
  file over 1500. **`modules/Library.lua` is 1017 lines, in the 1000–1500 on-notice band** (see
  QC-14). The census heading's "Nothing is over the cap today" is accurate. The kit gate
  `test_layout_cap` is wired by its kit path.
- `media/` holds only `media/logos/` (logo `.png` source, `quickcomms.logo.128.tga` type 2 / 128×128 / 32
  bpp, `quickcomms.logo.tga` type 2 / 300×300 / 32 bpp). No private copy of a library asset.
- Every one of the 60 source files opens with `local addonName, NS = ...` or `local _, NS = ...` and a
  self-naming header on line 2 (`documentation-§9`).

### TOC (`toc-file`)
- Field order canonical; single `## Interface: 120100` (matches the 14 other rostered TOCs);
  `## IconTexture` names `media\logos\quickcomms.logo.128.tga`; `## SavedVariables: QuickCommsDB,
  QuickCommsPerfDB`; `X-License: MIT`; `X-Standard` present; `# X-Curse-Project-ID: not published on
  CurseForge yet` in the field's position (compliant for an unpublished addon).
- Listing in `# Libraries → # Locales → # Core → # Defaults → # Modules → # Settings` order;
  `libs\LibKa0s\LibKa0s.xml` listed once after Ace3.
- Every file-scope `NS` / library read was swept (96 `local … = NS.…` captures plus every file-scope
  `LibStub`). Every within-group load-bearing position carries a comment naming what resolves. Two
  comments misdescribe their line (QC-10, Info).

### Library stack (`library-stack`)
- Ace3 (AceAddon, AceEvent, AceTimer, AceConsole, AceDB, AceGUI, AceConfig, AceDBOptions),
  LibSharedMedia, LibDataBroker, LibDBIcon, LibDeflate, LibSerialize, and the whole LibKa0s payload.
- **Provenance:** root `CLAUDE.md:42`, `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
  v1.71.0 (MIT).` One hit in `CLAUDE.md`, none in `README.md`.
- **`diff -r` against the `v1.71.0` tag** of the sibling `../LibKa0s` (`3bf1b97`): `libs/LibKa0s` and
  `tests/_kit` are both **empty diffs** (37 files each side for the kit). Kit revision **38**.
  `run-automated-tests.sh` recorded `100755`.
- Wired majors: Core, Media, Env, Pool, Widgets, Bus, Lifecycle, Perf, DebugLog, Launcher, Schema,
  Options, Slash, plus **Compat** (its guards only, `core/Compat.lua:7-17`). Item is vendored and not
  wired.
- Re-vendor store: no `docs/revendor/`. The only commit touching `libs/LibKa0s` or `tests/_kit` is the
  scaffold (`fdf7756`, v1.71.0). No store, no re-vendor since, so nothing is owed yet
  (`audit-review-history`: a repo with no store is measured from its next re-vendor).

### Architecture (`architecture`)
- `NS` promoted by `AceAddon:NewAddon(NS, …)` (`core/QuickComms.lua:11`), `NS.Print` reclaimed
  (`:16`), pinned by `tests/test_setup.lua` ("NS.Print is NS.Util.print after AceConsole's embed").
- Bus: 9 messages, each declared once in `core/Bus.lua:22-30` with its sender in a comment;
  PascalCase wire tails; no literal at any call site; receivers on `NS.Bus:NewTarget()` (tracked).
  Strict `Catalog` when LibKa0s-Bus is present.
- Schema: one write seam, `NS.SchemaRuntime.Set` (LibKa0s-Schema), reached by panel, CLI, launcher
  and host verbs. `enabled` declared `writeThrough`. Member rows resolved against the selected member.
  The registry writer is `modules/Library.lua`, named with its load pass (`Library.Prepare`,
  `RunMigrations`) in `docs/ARCHITECTURE.md` → Settings Schema. The pad drag writes through the seam
  (`modules/Pad.lua:71` → `Library.SetSurfacePoint` → `SchemaRuntime.Set(kind .. ".point", …)`).
  A sweep for direct writes into `db.profile` / `db.global` outside the writer found none.

### SavedVariables (`savedvariables`)
- `global.schemaVersion = 0` in defaults (`defaults/Profile.lua:44`); `NS.SCHEMA_VERSION` = highest
  step's `to` (`core/Database.lua:24`); the stamp advances only after a step returns (`:40`); the
  one profile-scoped step walks every stored profile; the runner runs right after `AceDB:New`
  (`core/QuickComms.lua:110`) and from every profile callback (`:65`). No `or`-defaulting of stored
  booleans was found.

### Options UI (`options-ui`)
- `Settings.Helpers` **is** the `LibKa0s-Options-1.0` instance, decorated in place
  (`settings/OptionsSetup.lua:82-113`); `addonName` passed; `get`/`set` are the seam; the
  library-absent branch is load-completing with hollow composers.
- Landing body is the library's `BuildLandingPage` (`settings/Panel.lua:25-37`), no `logoSize`.
- General page: tab strip, first tab `Master controls`, composed by `Helpers.MasterControls` with all
  ten canonical rows (enable, visibility, scale, alpha, lock, debug console, minimap, test mode, reset
  position, reset all). Editor pages (Callouts, Groups, Comms Pad, Comms Dial, Share) draw a banner
  with the picker and the create act, then a strip whose first tab is `General`. Profiles is
  AceConfig-drawn.
- Pad Look rows are composed (`FontGroup`, `BorderGroup`, `ColorPair`), class color player-scoped.
- No up/down arrow reorder; `ReorderList` used and canceled at the top of each render.
- No host code leaves regions or scripts on an AceGUI `.frame` / `.content`.
- No host code closes, hides or commits `SettingsPanel`. **One host `Settings.OpenToCategory`**, a
  page jump (`settings/Editors.lua:435-442`) with no combat gate (QC-02).
- Global reset is `db:ResetProfile()` behind a `StaticPopupDialogs` confirmation **whose text is not
  the verbatim canonical wording** (QC-01).

### Launcher (`launcher`)
- One LDB object through `LibKa0s-Launcher-1.0` (`core/LauncherSetup.lua:47-76`), `label = NS.BRAND`
  ("Ka0s Quick Comms"), logo icon, `minimap` = `db.global.minimap`, `isEnabled`/`setEnabled`,
  `isLocked`/`toggleLock`, `isTestMode`/`toggleTestMode` — matching `ADDONS.md`'s *Enabled · Locked ·
  Test mode*. `debug` and `debugAtEnable` passed. No host `OnClick`, `OnTooltipShow` or menu code.
- Minimap row at `global.minimap.shown`, closures over `minimap.hide`; vetoed from both resets
  (`skipRestoreAll`, pinned by `tests/test_schema.lua:78`).

### Slash commands (`slash-commands`)
- `/qc` and `/quickcomms` through AceConsole; `NS.COMMANDS` holds **20** positional triples
  (`settings/Slash.lua:25-66`), including `enable`/`disable` writing `enabled` through the seam and
  echoing `enabled = …` (`runEnabled`, `:382-390`), `diagnostics`, `perf`, `lock`/`unlock`.
- Disabled surface: `liveVerbs` built on `lib.LIVE_VERBS` plus `profile` (`:329-331`); feature verbs
  (`lock`, `unlock`, `check`, `test`, `preview`, `why`) refused with the library's one line.
- **The disabled state.** One latch, two holds (`core/LifecycleSetup.lua`, `LibKa0s-Lifecycle-1.0`
  minor 3). `NS.StandDown` (`core/QuickComms.lua:46-50`) unregisters every `NS.FEATURE_EVENTS` row,
  calls `NS.Bus:StandDown()` (tracked receivers) and runs every module's teardown (timers canceled,
  surfaces hidden through `SendEngine.Teardown`, which holds the secure half to `PLAYER_REGEN_ENABLED`
  in combat on one private registration released when it fires). Registration census: the only
  `RegisterEvent` sites are the feature-events loop (`core/QuickComms.lua:28`, through
  `SafeRegisterEvent`) and the held stand-down (`modules/SendEngine.lua:330`); every `RegisterMessage`
  is on a tracked `NewTarget`. The vendored kit is v1.71.0, past the v1.42.0 floor.
- `tests/test_disabled.lua` exists, is in `tests/run.lua`, and asserts on the mock's registration set,
  but covers only part of the ten mandated steps (QC-03).

### Debug logging (`debug-logging`)
- `NS.DebugLog` from a descriptor (`core/DebugLogSetup.lua:82-115`): `name`, `addonName`, `title`,
  `font`, `slash`, session-only flag, call-time forwarders, `initSummary`, `brandName`,
  `diagnostics`; `diagnosticsEnablesLogging` left at its default. Gates bound bare. `debug` handed to
  Slash, Options, Launcher, Lifecycle. `/qc diagnostics` and `/qc debug diagnostics` both reach
  `RunDiagnostics`; no `diag`/`dump` alias; the kit's diagnostics contract suite wired and green.
- `docs/debug.md` documents both forms, append, the enable, the sections, the cap, and what the report
  does not touch. README carries `## Reporting a bug` verbatim between Troubleshooting and Issues.
- Degraded stub: `DebugVerb` answers `false` unconditionally (QC-05).

### Events, frames, taint (`events-frames-taint`)
- Feature events through `NS.SafeRegisterEvent` with `NS.rejectedEvents`, surfaced in `[Init]` and in
  the diagnostics `registration` section. One direct `RegisterEvent` (QC-06).
- All secure writes in `modules/SendEngine.lua`, gated on `InCombatLockdown()` via `Compat.InCombat`.
  Pads use a `visibility` state driver, unregistered on teardown (`:152`).
- Chat output through `NS.Print` (library printer); no global `print()` outside the degraded Core
  branch.

### Compat (`compat`)
- One family file, `core/Compat.lua`, publishing **27** shims by the documentation-§3 count, plus
  `IsSecret`/`IsSafeKey` routed through `LibKa0s-Compat-1.0` with a guard-arm fallback.
  `docs/compat-layer.md` exists (trigger fired). Its stated count is stale (QC-08).

### Localization (`localization`)
- `NS.L` metatable fallback, `enUS.lua` only; 689 keys, none without a quoted reader in source.
  The kit's prose gate is wired, with per-file, per-word waivers for `docs/brainstorm/` only.

### Performance (`performance`)
- `NS.Perf` from `core/PerfSetup.lua`, 7 declared buckets (one nested), Shape A brackets at every
  site, `perf` verb, `QuickCommsPerfDB`, the `perf` hold on the same latch. `tests/perf.lua` with the
  zero-overhead scenario. `docs/perf-analysis/README.md` present, no captures yet.

### Lint and tests (`lint`, `testing`)
- `luacheck .` → **0 warnings / 0 errors in 109 files**. `exclude_files` is the template's set plus
  `docs/brainstorm/` (one tracked Lua file there, a go/no-go harness kept as history); `tests/` is
  linted; the harness global is in `files["tests/"]`.
- `lua tests/run.lua` → **664 passed, 0 failed, 1 skipped, 665 total**, exit 0, 10.8 s wall. The skip
  is the kit's diagnostics opt-out case, which this addon does not take. `docs/test-cases.md` equals a
  fresh `--list` byte for byte; README badge `664/664` (skip excluded from both, per testing-§5).
- Kit suites wired by path: `test_eol`, `test_prose`, `test_layout_cap`,
  `test_diagnostics_contract`, `test_lizard_sighted`; `test_surface_parity` and `test_vendor_sync`
  present.

### Automated-test record (`automated-tests`)
- `docs/automated-tests/{README.md,RESULTS.md}` present, one bundle `20261013-094801` at `fdf7756`
  (clean, `blindFiles` 0). That bundle is **110 commits behind HEAD**. The sighted complexity suite
  today: 0 warnings, max CCN 15, 2313 functions, verdict green (QC-14 records the drift).

### Packaging and line endings (`packaging`, `line-endings`)
- `.pkgmeta`: no `externals:`; every root dot-entry present (`.gitattributes`, `.gitignore`,
  `.luacheckrc`, `.pkgmeta`, `.superpowers`) is ignored; `docs`, `tests`, `tools`, `_dev`, the logo
  `.png` ignored; `Bindings.xml` not ignored. One ignore line for an absent `.playwright-mcp`
  (QC-15, Info).
- `.gitattributes`: present, `* text=auto eol=crlf`, both shebang carve-outs, 84 lines **byte-identical
  to the canonical client-bound body**, no appendix. Working-tree check (e): **0** files disagree.

### Root docs (`documentation-§1/§2/§7`)
- README: H1, four badges (no CurseForge badge, unpublished), standard badge **bare**, no logo image,
  no library inventory, no numbered list, no angle-bracket placeholder; Usage, How the callouts work,
  FAQ, Troubleshooting (with the reporting row), Reporting a bug, Issues, Version History (bulleted).
  No Screenshots section (a SHOULD until published).
- `CLAUDE.md`: stub shape, standards section, read-the-docs list, green-gate line, provenance line.
- `DEPENDENCIES.md`: runtime / development / release groups, pipx for lizard, verification commands,
  the Python tools named and stated as not needed to build or test.

### `docs/` shape (`documentation-§3`)
- Tier 1: all six present. Tier 2: `slash-dispatch.md` (20 commands), `compat-layer.md` (27 shims),
  `profiles.md` (Profiles page ships), `debug.md`, `perf-analysis/README.md` present;
  `midnight-quirks.md` and `message-bus.md` (9 messages) marked *Not applicable* with their triggers.
- `## Documentation map`: four tables in order; Verification and record holds exactly the six; all 18
  live `.md` files under `docs/` appear exactly once (the hub's self-row is absent, a MAY);
  `docs/brainstorm/` registered once as this repo's own frozen store; no dangling row.
- No non-canonical Tier 1/2 names, no `file-index.md`, `conventions.md`, `complexity.md` or
  `docs/perf-runs/`.
- Hub: 265 lines, all ten mandated sections, each a summary with a link.

## Bottom line

A carefully built addon: the shared subsystems are consumed rather than copied, the payload is
byte-identical to its tag, the disabled state is a real stand-down on the one latch, and lint, tests,
line endings and the doc map are clean. The findings are one user-visible wording defect in the reset
warning, a latent combat gap on one page jump, an incomplete conformance suite, and a set of smaller
documentation and convention gaps.
