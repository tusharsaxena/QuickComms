# 01 — Current state: Ka0s Quick Comms

Audit run **2026-10-25**, read-only, against branch `feat/2026-10-25-review-audit-fixes` at
**`18a2b55`** (clean tree; `git status --porcelain` empty at the start of the run).

## What this was measured against

| Item | Value |
|---|---|
| Repo kind | **Addon**: `dev-copilot-profile` reported `kind=addon` (reason `toc:## Interface`), and the discriminator agrees (root `QuickComms.toc`; `ADDONS.md` row *Ka0s Quick Comms*). The full addon rule set applies. |
| Standard | **Ka0s WoW Addon Standard v2.88.0 (2026-10-24)**, `standards/STANDARDS.md` line 1 |
| Source | **Network fetch** of `raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` (`AUDIT.md`, `standards/STANDARDS.md`, all 28 section files from the Sections list, `ADDONS.md`, `CHANGELOG.md`), published master `36da4ef`. The sibling checkout `../WowAddonStandards` was **not** used: its `HEAD` is `b9ee560` (an unpublished local v2.89.0 close, "WS-90"), which differs from the remote `36da4ef`, and `diff -rq` against the fetch differs in seven files plus a local-only `skinning.md`. |
| Playbook | `AUDIT.md` from the same fetch |
| Prior audit | `docs/audits/2026-10-13/` (v2.80.0, prefix **`QC-`**, IDs reused here) |
| Library | LibKa0s **v1.77.0** (root `CLAUDE.md:42`), sibling `../LibKa0s` tag `v1.77.0` = `e9b126d`, identical to `origin`'s tag. LibKa0s v1.78.0 exists upstream (a scheduling fact, not a compliance one). |

The addon is **unreleased** (`## Version: 0.1.0`, README `| 0.1.0 | Unreleased |`). Every v2.88.0 ruling
that commences "at the addon's next release after v2.88.0" (launcher-§6 shape, options-ui-§20/§21,
frame-layering) therefore binds this addon's first release, which has not happened; the repo has
already adopted most of them (commits `QC-KB`, `QC-LY`, `QC-ZS`, `QC-RV3`). Findings against those
rules are graded as owed at the 0.1.0 tag.

## Layout (layout)

- Five source folders plus `tools/`, `tests/`, `docs/`, `media/`, `libs/`; root holds the TOC,
  `Bindings.xml`, `README.md`, `CLAUDE.md`, `DEPENDENCIES.md`, `LICENSE`, `.luacheckrc`, `.pkgmeta`,
  `.gitattributes`, `.gitignore`. `.superpowers/` exists on disk (git-ignored), `.claude/` does not.
- 77 authored `.lua` files load from the TOC; 139 files are linted (`.luacheckrc` scope).
- **Cap census** (`git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs wc -l`): nothing over
  1500. The 1000–1500 band holds **six** files: `tests/test_page_groups.lua` 1500 (at the cap),
  `tests/test_dial.lua` 1392, `locales/enUS.lua` 1348, `modules/Library.lua` 1316,
  `tests/test_library.lua` 1065, `tests/wow_mock.lua` 1027. The hub's census
  (`docs/ARCHITECTURE.md:380-387`) says "Nothing is over the cap today", which is true; the kit gate
  `test_layout_cap` is wired (`tests/run.lua:198`, `Kit.layoutCap = { hub = "docs/ARCHITECTURE.md" }`
  at `:137`) and green.
- `tools/` holds four Python generators, one Lua offline renderer and its Python compositor; all
  `.pkgmeta`-ignored (`.pkgmeta:16`), none in the TOC. `media/` holds `logos/` and `textures/` (the
  dial and shine art the `tools/` generators write); no copy of a library asset.
- Logo files (TGA header read, not `file`): `quickcomms.logo.128.tga` type 2, 128×128, 32 bpp;
  `quickcomms.logo.tga` type 2, 300×300, 32 bpp. Editable sources `.png` and `.jpg` are committed.
- `Bindings.xml` at the root, five `CLICK` bindings, every one `category="BINDING_HEADER_QUICKCOMMS"`,
  no `header`, no `default`, no Lua; Toggle Comms Pads first. Not in the TOC, not ignored.

## TOC (toc-file)

`QuickComms.toc:1-13` follows the field order; `## Interface: 120105` (README badge `Midnight_12.1.5`
agrees); `## IconTexture` names the 128 logo; two SavedVariables (`QuickCommsDB, QuickCommsPerfDB`);
`# X-Curse-Project-ID: not published on CurseForge yet` in its position (compliant, no row owed).
Listing in the six mandated groups, LibKa0s as one `libs\LibKa0s\LibKa0s.xml` line after Ace3
(`:35`). Every line carries a LOAD-BEARING or Conventional comment; the six
`defaults\BuiltIns_*.lua` positions are labeled Conventional although each appends to the
TOC-ordered `BI.order` (QC-26).

## Libraries (library-stack)

- Ace3 set vendored (AceAddon, AceEvent, AceTimer, AceConsole, AceDB, AceGUI, AceConfig,
  AceDBOptions), LibSharedMedia, LibDataBroker, LibDBIcon, LibCustomGlow, LibKa0s. LibSerialize and
  LibDeflate left with today's Share removal (`2f0e2b3`).
- **Vendor drift**: `diff -r <v1.77.0>/LibKa0s libs/LibKa0s` and `diff -r <v1.77.0>/testkit tests/_kit`
  are both **empty** (the tag exported with `git archive`). `LibKa0s icons: all (icon browser).`
  (`CLAUDE.md:43`) with the icon browser (`settings/IconBrowser.lua`) as its chooser; the full icon
  set and all four attribution files ship, so no `Only in` line appears.
- Fourteen majors wired, one setup file each (`docs/ARCHITECTURE.md:54-69`); Compat wired for its
  two guards; Item vendored, not wired. Glow adopted (`core/GlowSetup.lua`), Sim not adopted (no
  simulator ships).
- Re-vendor store `docs/revendor/` (horizon 2026-10-22): vendored tags v1.75.0, v1.75.1, v1.75.2,
  v1.76.0, v1.77.0; all five recorded. Nothing unrecorded.

## Architecture, schema, SavedVariables

- `local addonName, NS = ...` then a self-naming header on line 2 in every authored source file
  (checked over all `core/ modules/ settings/ defaults/ locales/` files: no miss).
- AceAddon on `NS` (`core/QuickComms.lua:11`), printer reclaimed (`:16`).
- Bus: `core/Bus.lua:22-30`, nine `Ka0s_QuickComms_<PascalCase>` constants with their senders;
  no literal at a call site; strict catalog with LibKa0s-Bus; each receiver on its own target.
- Schema: one seam `NS.SchemaRuntime.Set` (LibKa0s-Schema); member rows addressed per kind; registry
  writer `modules/Library.lua` with load pass `Library.Prepare` named in the hub and `schema.md`.
- Migrations: `core/Database.lua:16-44`, nine steps, runner owns the stamp, per-profile steps walk
  `db.sv.profiles`, `NS.SCHEMA_VERSION` = 9, `schemaVersion = 0` default.
- Named non-setting state: the hub names `db.char.padsHidden` and points at `schema.md` for
  `previewWindow`; neither names `padsHidden`'s owner and writer (QC-23).

## Settings panel (options-ui)

- Options instance from a descriptor with `addonName`, the seam, `colorDecode/Encode`,
  `skipRestoreAll` (`settings/OptionsSetup.lua:103-132`); load-completing stub (`:23-100`) answering
  `KeybindingsTab`, `KeybindRows`, `KEYBINDS_UNCHANGED`, `StrataTooltip`, `ResetAllTooltip`.
- Landing page through `BuildLandingPage` (`settings/Panel.lua:25-37`), no `logoSize`.
- General page: `Master controls` composed (`settings/Panel.lua:44-70`, `extra` = Preview as),
  `Behavior`, `Keybindings` last (`O.KeybindingsTab`, `:92-104`); header Defaults tooltip
  `ResetAllTooltip(KEYBINDS_UNCHANGED)` (`:114`).
- Global reset: `db:ResetProfile()` behind the verbatim options-ui-§12 text (`settings/Schema.lua:341-352`),
  blast radius pinned (`tests/test_schema.lua:129`).
- Pages: General, Groups, Comms Pad (Pad), Comms Dial (Dial), Profiles. Colors through `ColorPair`;
  several color pairs and two font blocks gray out on their feature switch (QC-18). Delete buttons and
  `Duplicate` miss options-ui-§21's words (QC-19).
- Page jump `Ed.OpenPage` is combat-gated and opens against `category:GetID()`
  (`settings/Editors.lua:714-728`). No code closes or commits `SettingsPanel`; three insecure
  `HookScript("OnHide")` post-hooks only end the addon's own previews and drafts.

## Slash (slash-commands)

21 `NS.COMMANDS` triples (`settings/Slash.lua:25-68`); dispatcher from LibKa0s-Slash with
`liveVerbs` = `lib.LIVE_VERBS` + `profile`, `isEnabled` = the stored switch, `debug` sink passed.
Feature verbs (`lock`, `unlock`, `toggle`, `check`, `test`, `preview`, `why`) refuse while disabled;
under the `perf` hold alone `toggle`, test mode and Preview as answer the capture line. Library-absent
stub carries `DISABLED_LINE_FORMAT` pinned with `Kit.assertLibraryConstant`
(`tests/test_surface_parity.lua:44-48`); its help row uses an em dash (QC-17).

## Disabled state (slash-commands-§7)

- One latch, two holds (`core/LifecycleSetup.lua`); `NS.StandDown` unregisters every
  `NS.FEATURE_EVENTS` row, takes the tracked bus down, runs every module's `STAND_DOWN`
  (`core/QuickComms.lua:47-58`). The only other registration is SendEngine's held-stand-down
  `PLAYER_REGEN_ENABLED`, through `NS.SafeRegisterEvent`, released when it fires
  (`modules/SendEngine.lua:353-385`).
- Registration census over the TOC load list: every `RegisterMessage` site has its `UnregisterMessage`
  on the degraded bus and is tracked otherwise; every timer has a cancel in its module's
  `STAND_DOWN`. No draw gate.
- `tests/test_disabled.lua` (listed in `tests/run.lua`) walks the ten steps; step 6's per-event reach
  and step 8's disabled key press are still missing (QC-03, narrowed).

## Launcher (launcher)

One LDB object through LibKa0s-Launcher (`core/LauncherSetup.lua:47-79`): name = folder, `label =
NS.BRAND`, icon = the 128 logo, `minimap` = `db.global.minimap`, the four accessor/toggle pairs
matching `ADDONS.md` (*Enabled · Locked · Test mode · Show window*), `debug` and `debugAtEnable`
passed. No host `OnClick`, menu or `OnTooltipShow`. Show window binding `QuickCommsTogglePads`
(`settings/SlashVerbs.lua:94-114`), plain button, `AnyDown`, calls `V.TogglePads`, which refuses by
hold; `BINDING_HEADER_QUICKCOMMS = NS.BRAND` at file scope; `NS.BINDINGS` in Bindings.xml order.

## Debug and diagnostics (debug-logging)

DebugLog descriptor with `addonName`, `font`, `diagnostics` sections, no opt-out
(`core/DebugLogSetup.lua:89-122`); stub answers `DebugVerb`, `RunDiagnostics` with the
library-absent line (`:66-80`). `diagnostics` is one `COMMANDS` row; no alias. README
`## Reporting a bug` verbatim (`README.md:130-136`). Library sinks: Slash, Options, Launcher,
Lifecycle descriptors all pass `debug`.

## Frame layering (frame-layering)

`NS.Constants.LAYERS` with the stack comment (`core/Constants.lua:33-116`); no strata literal, no
absolute level; sibling-relative level hits are all relative to the band owner. Pads `MEDIUM`, dial
header `DIALOG` (secure fixed point, register row), dial screen catcher `HIGH`, preview window and
modals `FULLSCREEN`, confirms lifted to `FULLSCREEN_DIALOG` and restored to the recorded strata. No
`SetToplevel` call anywhere; the modals are neither toplevel nor clamped (QC-21).

## Tests, lint, complexity (testing, lint, automated-tests)

- `luacheck .`: **0 warnings / 0 errors in 139 files**. Excludes `libs/`, three frozen stores,
  `docs/brainstorm/`, `_dev/`, `tests/_kit/`; harness globals in `files["tests/"]`; one narrow
  per-file ignore (`settings/Slash.lua` 212/self).
- `lua tests/run.lua`: **1157 passed, 0 failed, 1 skipped, 1158 total**, exit 0; 31.6 s user +
  10.2 s system CPU, serial (no `jobs`). `docs/test-cases.md` regenerates byte-identical; README badge
  `1157/1157` matches its Total.
- Kit revision **42**; kit suites declared by path: `test_eol`, `test_prose`, `test_layout_cap`,
  `test_diagnostics_contract`, `test_lizard_sighted`; runner recorded `100755`.
- Complexity (`bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`): **pass**,
  19 functions above CCN 15, max CCN 30, 34,825 NLOC over 3,795 functions; the newest bundle
  `20261014-002540` measured `6cc22be`, **294 commits** behind HEAD, and recorded 0 warnings, max 15,
  one band file (QC-14).

## Packaging and line endings

- `.pkgmeta`: no externals; ignores every dev entry present, comments out `.claude` and
  `.playwright-mcp` (absent); ignores `media/logos/*.png` but **not** `*.jpg` (QC-20).
- `.gitattributes` (recorded verbatim in `03_EVIDENCE.md` E-LE): client-bound pin
  `* text=auto eol=crlf`, both carve-outs, 20 binary marks; the 84-line body is byte-identical to
  line-endings-§5's client-bound file; **0** tracked files disagree with the pin.

## Root docs and `docs/` (documentation)

- README: H1, four badges (bare standard badge, no CurseForge badge pre-publish), no logo, no library
  inventory, no numbered list, sections in canonical order; no `## Screenshots` (unpublished, SHOULD).
  Three angle-bracket placeholders in shipped content (QC-16). `## Credits` credits all three icon sets
  with Game-icons' license, link, authors and modification statement.
- `CLAUDE.md`: stub shape, standards section, pointers, gate line, provenance + icons lines.
- `DEPENDENCIES.md`: runtime / development / release groups, pipx for lizard, verification commands.
- Tier 1 all present. Tier 2: `slash-dispatch.md` (21 commands), `compat-layer.md`, `profiles.md`,
  `debug.md`, `perf-analysis/README.md` present; `midnight-quirks.md` and `message-bus.md` *Not
  applicable* rows; **`known-limitations.md` and `taint.md` neither present nor rowed**, while both
  hub sections are far past the spill threshold in substance (QC-22).
- `## Documentation map` has the four tables in order; every `.md` under `docs/` (frozen stores
  excluded) appears once; no orphan, no dangling row, no retired doc, no non-canonical Tier 1/2 name.
- Hub: 387 lines / 81,866 bytes; wraps to 1,047 lines at 100 columns (QC-22). Eleven `##`
  sections: the ten mandated plus `## Frame layering`, which restates the tier stack (QC-27).
- Register: seven rows (accepted below); census heading present under it.

## Recorded (accepted) deviations

The register (`docs/ARCHITECTURE.md:370-378`) holds seven rows; each is recorded as accepted in
`02_DEVIATIONS.md` (QC-R1..QC-R7) and excluded from the tallies. No trigger has fired. One row's
text has gone stale (QC-25). The issue store holds no `state:will-not-do` issue; issue #11
(`state:untriaged`) proposes the QC-18 fix; no `docs/pending/LEDGER.md`, no `[status]` prefix.

## Prior audit (2026-10-13) — status at this run

| ID | Status |
|---|---|
| QC-01, QC-02, QC-04, QC-05, QC-06, QC-07, QC-09, QC-10, QC-11, QC-12, QC-13, QC-15 | Closed; each fix verified in code or test (`03_EVIDENCE.md` E-PRIOR) |
| QC-03 | Largely closed; step 6 per-event reach and step 8 disabled key press remain — re-filed narrowed |
| QC-08 | Recurred: the shim count moved again (31 by the documented grep; docs say 27) |
| QC-14 | Recurred: record now 294 commits stale, 19 release blockers above CCN 15 |
