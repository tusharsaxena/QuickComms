# 03 — Evidence: Ka0s Quick Comms

Every citation below was re-read in the tree at `be9cf49` before it was written, and the cited text is
quoted beside it. Every count states the command that produced it and what that command covered.
Bounded runs used `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded`. CRs are stripped from quoted
lines (the tree is CRLF-pinned).

## E0 — Standard source, kind and register

```
$ git -C ../WowAddonStandards status -sb | head -1
## master...origin/master [ahead 2]
$ git -C ../WowAddonStandards log --oneline -2
8aad69d QC: Bindings.xml is a client-mandated root file, beside the TOC (v2.80.0)
fcfaf5c QC-02: Ka0s Quick Comms' launcher row lists Locked and Test mode
$ head -1 ../WowAddonStandards/standards/STANDARDS.md
# Ka0s WoW Addon Standard (v2.80.0, 2026-10-13)
$ git -C ../WowAddonStandards diff origin/master --stat | tail -1
 10 files changed, 22 insertions(+), 10 deletions(-)
$ dev-copilot-profile
profile=wow  kind=addon  name=QuickComms  reason=toc:## Interface
```

Register: `docs/ARCHITECTURE.md:252` `## Documented deviations`, `:257` "None.", `:259`
`### Files over the 1500-line cap`, `:265` "Nothing is over the cap today."

```
$ gh issue list --state all --limit 200 --json number,title,state,labels,url
#7 OPEN  state:triaged severity:low  "Re-evaluate whisper-to-target / whisper-to-focus channels"
#6 CLOSED state:done severity:critical "Go/no-go: can a player-pressed secure button send group chat…"
#5 #4 #3 #2 #1 OPEN state:triaged severity:low (callout keybind, mark, cooldown, confirm, variants)
$ ls docs/pending
ls: cannot access 'docs/pending': No such file or directory
```
(Output condensed to one line per issue; all seven carry exactly one `state:` and one `severity:` label
and no bracketed title prefix.)

## E1 — Green gate

```
$ ka0s-bounded lua tests/run.lua
664 passed, 0 failed, 1 skipped, 665 total          (exit 0; wall=10.81s cpu=4.45s+0.75s)
$ ka0s-bounded luacheck .
Total: 0 warnings / 0 errors in 109 files
$ ka0s-bounded lua tests/run.lua --list > $SCRATCH/list.md; diff docs/test-cases.md $SCRATCH/list.md
(no output: identical after CR strip)
```
Scope: luacheck walks the tree minus `.luacheckrc` `exclude_files` (`libs/`, `docs/audits/`,
`docs/reviews/`, `docs/revendor/`, `docs/brainstorm/`, `_dev/`, `tests/_kit/`). 109 = the 110 authored
Lua files of E3 minus `docs/brainstorm/go-no-go/harness/QCTest.lua`.

## E2 — Line endings (`line-endings`)

```
$ test -f .gitattributes && echo present                       → present
$ grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes      → 26:* text=auto eol=crlf
$ grep -nE '^\*\.(sh|py) text eol=lf' .gitattributes           → 36:*.sh text eol=lf / 37:*.py text eol=lf
$ grep -c ' binary' .gitattributes                             → 23
$ n=84; diff <(head -n $n .gitattributes | tr -d '\r') canonical_client_body   → (empty) BODY-IDENTICAL
$ tail -n +85 .gitattributes | tr -d '\r' | grep -m1 .         → (nothing: no appendix)
$ git ls-files -z | xargs -0 -n1 sh -c '…(AUDIT.md (e) verbatim)…' _ 2>/dev/null | wc -l
0
```
Scope: (e) is the whole tracked set, `libs/` and `tests/_kit/` included (419 tracked files). The
canonical body was cut from `line-endings.md` lines 164–247 (84 lines).

## E3 — Lua census (`layout-§1`)

```
$ git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | wc -l           → 110
$ git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs wc -l | sort -rn | head -3
  23497 total
   1017 modules/Library.lua
    788 tests/test_library.lua
$ git ls-files '*.lua' | grep '^docs/'  → docs/brainstorm/go-no-go/harness/QCTest.lua
```
Scope: the default denominator (authored Lua, `tests/` in, `libs/` and `tests/_kit/` out). No file
over 1500; one in the 1000–1500 band. No generated-data exemption is declared, and none is needed.

## E4 — Vendored payloads (`library-stack-§7`, `testing-§11`)

```
$ grep -n 'Bundles \[LibKa0s\]' CLAUDE.md README.md
CLAUDE.md:42:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.71.0 (MIT).
$ git -C ../LibKa0s rev-parse v1.71.0                    → 3bf1b97937f0db2130ee96483e4d877b2ca67e2b
$ git -C ../LibKa0s archive v1.71.0 LibKa0s testkit | tar -x -C $SCRATCH/lk
$ diff -r $SCRATCH/lk/LibKa0s libs/LibKa0s && echo EMPTY  → EMPTY
$ diff -r $SCRATCH/lk/testkit tests/_kit; echo rc=$?     → rc=0  (37 files each side)
$ grep -n 'Kit.VERSION' tests/_kit/framework.lua          → 20:Kit.VERSION = 38
$ git ls-files -s tests/_kit/run-automated-tests.sh       → 100755 685cbcc… 0 tests/_kit/run-automated-tests.sh
$ grep -c '<Script file=' libs/LibKa0s/LibKa0s.xml        → 34
```
Diffed at the tag `CLAUDE.md` names, not the sibling's HEAD (`5d22cf1`). `git archive` applies the
library repo's CRLF pin, so both sides are the same representation.

Re-vendor history (`audit-review-history`):
```
$ ls docs/revendor                                     → No such file or directory
$ git log --format='%h %ad %s' --date=short -- libs/LibKa0s tests/_kit
fdf7756 2026-10-13 Scaffold Ka0s Quick Comms from the standard playbook   (provenance at that commit: v1.71.0)
```

## E5 — Packaging (`packaging`)

```
(a) checking: .luacheckrc .pkgmeta .gitignore .gitattributes docs tests _dev tools .superpowers  → no NOT IGNORED line
(b) UNACCOUNTED — .git   (the one sanctioned exception)
(c) (no FALSE CLAIM line)
$ ls -d .playwright-mcp → No such file or directory
```
`.pkgmeta:13` — `  - .playwright-mcp  # dev-only browser-tool scratch: present in local checkouts (git-ignored), never shipped` (**QC-15**).
`grep -n Bindings QuickComms.toc .pkgmeta` → no output.

## E6 — QC-01: the reset confirmation wording

Standard, `options-ui.md:302`:
> **Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded — your other profiles are not affected.**

Addon:
- `settings/Schema.lua:333` — `text = L["Reset this profile to the addon's defaults? Everything you have configured in it is discarded \226\128\148 your other profiles are not affected."],`
- `locales/enUS.lua:63` — `L["Reset this profile to the addon's defaults? Everything you have configured in it is discarded \226\128\148 your other profiles are not affected."] =`

The missing words are " or added". What the reset discards here includes player-created members:
`docs/ARCHITECTURE.md:111-112` names `profile.callouts`, `groups`, `pads`, `dials` as the registry the
profile holds. `grep -rn 'configured' tests/*.lua` → no output: no test pins the text.

## E7 — QC-02: the page jump

- `settings/Editors.lua:435` — `function Ed.Open(pageKey)`
- `settings/Editors.lua:440` — `S.OpenToCategory(category:GetID())`
- Callers: `settings/Callouts.lua:135` — `return Ed.Open("groups")`; `settings/Share.lua:217` —
  `if copy then Ed.Open(Settings.Groups.PAGE) end`; `settings/Share.lua:225` — `return Ed.Open(Settings.Groups.PAGE)`

```
$ git ls-files '*.lua' ':!libs' ':!tests' ':!docs' | xargs grep -nE 'SettingsPanel|HideUIPanel|ToggleGameMenu|OpenToCategory|InCombatLockdown'
core/Compat.lua:122:    return InCombatLockdown ~= nil and InCombatLockdown() == true
modules/Preview.lua:198:--- client's SettingsPanel once; the hook is insecure and runs only when that window hides.
settings/Editors.lua:439:    if not (category and type(category.GetID) == "function" and S and S.OpenToCategory) then return false end
settings/Editors.lua:440:    S.OpenToCategory(category:GetID())
settings/Panel.lua:95:    if NS.Preview then NS.Preview.WatchPanel(_G.SettingsPanel) end
(plus four comment-only hits in Restrictions, SendEngine and Situation)
```
The ID is the integer `:GetID()` of the page's own subcategory (half one of the carve-out holds); no
`InCombatLockdown` test sits on this path (half two does not). No other host close, hide or commit
of `SettingsPanel` exists; `Preview.WatchPanel` is a post-hook on `OnHide` that only ends Preview-as.

## E8 — QC-03: the conformance suite against `slash-commands-§7`'s ten steps

`tests/test_disabled.lua` (180 lines, 9 cases, listed in `tests/run.lua:102`):

| Step | Covered by | Gap |
|---|---|---|
| 1 Baseline `R_on` non-empty | `:70-74` "disabled 1" pins 22 events | `T_on`, `F_on` not captured |
| 2 Disable through the seam | `:65-68` both `/qc disable` and `SchemaRuntime.Set("enabled", false)` | — |
| 3 Registration set empty | `:84` `assertEqual(registered(m), "", …)`; `:83` `-- red under: drop the UnregisterEvent loop in NS.StandDown` | `:35` `if r.kind ~= "message" then` drops message registrations; only the probe receiver is checked |
| 4 No timer armed | `:90` `assertEqual(#m.__timers(), 0, "no live timer")` | not re-asserted after firing |
| 5 Every frame in `F_on` hidden | — | **absent** |
| 6 Fire every `R_on` event | `:98` `m.__fireUnconditional(NS.addon, PROBE_EVENT)` | one probe event only; no `PLAYER_REGEN_DISABLED` by name; no zero-print or zero-show assertion; no `red under` |
| 7 Every `NS.COMMANDS` entry while disabled | `:105` `for _, verb in ipairs({ "help", "version", "list", "get enabled", "diagnostics", "profile", "perf" })`; `:118-129` a probe feature verb | missing `config`, bare `/qc`, `debug`, `set`, `reset`, `resetall`, `enable`; the real feature verbs (`lock`, `unlock`, `check`, `test`, `preview`, `why`) not pinned |
| 8 Launcher | `:152-171` right-click `Enabled` live | left-click → panel with zero writes, and *Locked* / *Test mode* grayed, not asserted |
| 9 Restore from current state | `:131-140` re-registers `R_on` | no setting changed while disabled |
| 10 The latch | — in this suite; `tests/test_setup.lua:163` `NS.Lifecycle:Hold(NS.HOLD_PERF)` holds `perf` alone | the disabled + perf interplay, in both orders, is **absent**; no `red under` |

The code the suite should pin is compliant: `core/QuickComms.lua:47` `for _, row in ipairs(NS.FEATURE_EVENTS) do QC:UnregisterEvent(row[1]) end`, `:48` `NS.Bus:StandDown()`, `:49` `runAll(NS.STAND_DOWN)`; `modules/Surfaces.lua:445` `NS.SendEngine.Teardown(function()` hides pads and dials; `modules/SendEngine.lua:152` `UnregisterStateDriver(frame, "visibility")`.

Registration census (scope: tracked `*.lua` minus `libs/`, `tests/`, `docs/`):
```
$ … | xargs grep -nE 'Register(Unit)?Event|RegisterMessage|RegisterBucketEvent|SafeRegister'
core/QuickComms.lua:28:        NS.SafeRegisterEvent(self, row[1], row[2], NS.rejectedEvents)
modules/SendEngine.lua:330:    pending:RegisterEvent("PLAYER_REGEN_ENABLED", function()
modules/{Dial:360, Pad:460-461, Preview:224, SendEngine:468, Situation:195, Surfaces:439}, settings/Editors.lua:169 — RegisterMessage on NewTarget receivers
(core/CoreSetup.lua:57-87 and core/Bus.lua:5 — the degraded helpers' definitions and a comment)
```

## E9 — QC-04: no blast-radius case for the global reset

```
$ grep -rn 'RestoreAllDefaults\|ResetProfile\|resetall' tests/test_*.lua
tests/test_master.lua:81:    NS.addon.Settings.Helpers.RestoreAllDefaults()
tests/test_pad.lua:286:    NS.addon.db:ResetProfile()
tests/test_schema.lua:83:    NS.addon.Settings.Helpers.RestoreAllDefaults()
tests/test_schema.lua:91:    NS.addon:OnSlashCommand("resetall")
```
`tests/test_schema.lua:78` — `test("schema: neither reset touches the minimap button (launcher-§3)"` (minimap only);
`tests/test_master.lua:75` — `"…and Reset all ends it"` (test mode only); `tests/test_pad.lua:286` (one pad's point). None
creates two or more members and asserts the shipped set, the profile list, or `PROFILE_CHANGED`.

## E10 — QC-05: the degraded `DebugVerb`

- `core/DebugLogSetup.lua:73` — `DebugVerb       = function() return false end,`
- `settings/Slash.lua:411` — `if not DL:DebugVerb(rest) then DL:Toggle() end`
- The stub's `Toggle` (`core/DebugLogSetup.lua:34`) is `function() sayOnce() end`, which prints the
  console-unavailable line and flips nothing. The stub's own `SetEnabled` (`:50-57`) does flip and
  ack, but nothing on the slash path reaches it.

Standard: `debug-logging.md:113` — "The stub **MUST** still flip the flag and still print the ack… a
user who types `/<slash> debug on` must not be told nothing happened." `debug-logging.md:449-452` —
the stub's `RunDiagnostics` prints the library-absent line with `%s = "/<slash> diagnostics"`.
`tests/test_slash.lua:80` ("`debug on` turns logging on") runs only on the live load.

## E11 — QC-06: the direct registration

- `modules/SendEngine.lua:330` — `pending:RegisterEvent("PLAYER_REGEN_ENABLED", function()`
- Contrast `core/QuickComms.lua:28` — `NS.SafeRegisterEvent(self, row[1], row[2], NS.rejectedEvents)`
- Standard `events-frames-taint.md:42`: "Registration is **isolated per event**: every `RegisterEvent`
  goes through a single `pcall`ed helper… A host on v1.56.0 or later **MUST** register through them."

## E12 — QC-07: marks drawn off-catalog

- `modules/Dial_Render.lua:23` — `local LOCK_ICON = "Interface\\PetBattles\\PetBattle-LockIcon"`; used `:175` `btn.qcLock:SetTexture(LOCK_ICON)`
- `modules/Dial_Render.lua:24` — `local CLOSE_ICON = "Interface\\Buttons\\UI-StopButton"`; used `:65` `header.qcClose:SetTexture(CLOSE_ICON)`
- `modules/Pad_Render.lua:19` — `local LOCK_ICON = "Interface\\PetBattles\\PetBattle-LockIcon"`; used `:131` `btn.qcLock:SetTexture(LOCK_ICON)`
- Catalog: `ls libs/LibKa0s/media/icons` includes `lock.tga`, `close.tga`, `chevron-right.tga`.
  The seam exists: `core/MediaSetup.lua:16` `function NS.Icon(name)`.
- The close-button grep is clean: `grep -rn 'MakeCloseButton(' --include='*.lua' . | grep -v /libs/ | grep -v /tests/` → `core/CoreSetup.lua:104:    return lib.MakeCloseButton(parent, onClick, addonName)` only. The hub mark is a texture on a secure header, not a close control the wrapper could build.

## E13 — QC-08: compat count and wiring drift

```
$ cat core/Compat*.lua | grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.'
27
```
Scope: the compat family (one file, `core/Compat.lua`).
- `docs/compat-layer.md:9` — `**Twenty-five shims**, counted the way documentation-§3 counts them`; `:10` — `` …answers `25`) ``
- `docs/ARCHITECTURE.md:232` — `` | `compat-layer.md` | Present | `core/Compat.lua` publishes 25 shims, three or more | ``
- Not in `docs/compat-layer.md`'s table: `core/Compat.lua:273` `function Compat.BindingLabel(action)`, `:282` `function Compat.BindingKey(command)`
- `docs/ARCHITECTURE.md:47` — `` `LibKa0s-Compat-1.0` and `LibKa0s-Item-1.0` are vendored and not wired… `` against
  `core/Compat.lua:7` `local CompatLib = LibStub and LibStub("LibKa0s-Compat-1.0", true)` and `:10`
  `Compat.IsSecret = CompatLib and CompatLib.IsSecret or function(v)`.

The trigger's verdict does not change (27 ≥ 3, doc present); only the stated figures are wrong.

## E14 — QC-09: guard-arm comment

`core/Compat.lua:9-17`: the lines above each fallback are `--- True when \`v\` is a secret value. Exactly one boolean.`
and `--- True when \`v\` may be used as a table key: not secret, not nil.`; neither names the Compat API
document. Standard `options-ui.md:76`: "**The guard arm**… The host copy carries a comment naming that section."

## E15 — QC-10: comments that misdescribe

- `QuickComms.toc:48` — `# LOAD-BEARING: NS.Compat, read by modules at call time; needs NS.SafeToString (CoreSetup, above) and LibKa0s-Compat (optional)`.
  `grep -n SafeToString core/Compat.lua` → no output. `grep -nE '^local [A-Za-z_, ]+ *= *NS\.Compat' core/*.lua modules/*.lua settings/*.lua defaults/*.lua` → `core/Compat.lua:6` only.
- `QuickComms.toc:54` — `# Conventional: session-only state (NS.State), read by everything below at call time.`
  against e.g. `modules/Restrictions.lua:34` `local State = NS.State`; the same file-scope capture is in
  Dial, Pad, Preview, SendEngine, Situation, Surfaces, `settings/Editors.lua` and `settings/Groups_When.lua`.
  No `core/` file below `State.lua` captures it, so within its group the position is free.
- `core/QuickComms.lua:18` — `-- Every game event this addon owns, as { event, handlerMethodName } pairs. None yet: the situation`
  while `tests/test_disabled.lua:12-19` pins 22 owned events.

## E16 — QC-11: hand-rolled change gate

`modules/SendEngine.lua:293-297`:
```
    local sig = table.concat(parts, ",")
    if sig ~= boundSig then
        boundSig = sig
        NS.Debug("Bind", "bound %s", sig ~= "" and sig or "nothing")
    end
```
`grep -n 'DebugChanged\|DebugOnce\|onClear' core modules settings` → only the stub and binding lines in
`core/DebugLogSetup.lua` (27-28, 76-77, 119-120); no `onClear` in the descriptor.

## E17 — QC-12: bucket names

`core/PerfSetup.lua:24` — `{ key = "situation.refresh" },` through `:30` — `{ key = "dial.render" },`
(seven keys, all dotted). `naming-cheatsheet.md`, Perf buckets row: "lowerCamelCase, named for the
path they time (performance-§3) | `absorbEvent`, `repaintPass`, `paintBar`".

## E18 — QC-13: color codec

`settings/OptionsSetup.lua:82-109` (the `lib:New` descriptor) passes no `colorDecode` / `colorEncode`.
Stored shape `modules/Library.lua:595` — `fontColor = { r = 1, g = 1, b = 1, a = 1 },` (the library default shape).

## E19 — QC-14: the record against HEAD (`automated-tests`)

```
$ ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle
  complexity  pass  — 0 warnings (fun rate 0.00), 18663 NLOC / 2313 funcs, avg NLOC 7.2, avg CCN 2.5 (max 15) …
  verdict: green
  record:  newest bundle 20261013-094801 measured fdf7756, 110 commit(s) behind HEAD
$ lizard --version → 1.24.0
```
`docs/automated-tests/RESULTS.md:35` — `` | [`20261013-094801`](20261013-094801/) | `fdf7756` | clean | 0.1.0 → 0.1.0 | 0/0 | 37 | 136/1/137 | pass | 2632 | 477 | 4.4 | 2.0 | 13 | 0 | **green** | ``.
Bundle manifest: `"sha": "fdf77569…"`, `"dirty": false`, `"blindFiles": 0`. The watch list's band table
reads "None."; `modules/Library.lua` is now 1017 lines (E3). No function above CCN 15 today (max 15),
so no warned function is owed a disposition. No disposition is "Accepted", so anti-pattern #53 has no
instance.

## E20 — Compliance evidence for checks that passed

| Check | Evidence |
|---|---|
| Bindings.xml (v2.80.0) | root file, 4 `<Binding name="CLICK QuickCommsDial<n>:Toggle" …/>` lines, no script; `modules/Dial.lua:42` `BINDING_HEADER_QUICKCOMMS = NS.BRAND`, `:44` `rawset(_G, ("BINDING_NAME_CLICK %s:%s")…` |
| IconTexture | TOC line 6 `## IconTexture: Interface\AddOns\QuickComms\media\logos\quickcomms.logo.128.tga`; header bytes: type 2, 128×128, 32 bpp |
| README | badge `:5` `![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)` (bare); `grep -nE '^[[:space:]]*[0-9]+[.)][[:space:]]' README.md` → none; no library heading; no logo image |
| Bus | `core/Bus.lua:22-30` nine `Ka0s_QuickComms_<PascalCase>` constants; `grep -rnE '(Send|Register)Message\("Ka0s_' …` → none |
| Landing | `settings/Panel.lua:26` `Helpers.BuildLandingPage(ctx, {` |
| Master controls | `settings/Panel.lua:44-58` `Helpers.MasterControls{ … debugConsolePath, minimapPath, testModePath …}` |
| Launcher | `core/LauncherSetup.lua:47-76`; ADDONS.md row "Enabled · Locked · Test mode" |
| Reset veto | `settings/OptionsSetup.lua:108` `skipRestoreAll = Settings.VetoedFromResetAll,`; `tests/test_schema.lua:78` |
| Live verbs | `settings/Slash.lua:330` `for i, verb in ipairs(lib.LIVE_VERBS) do liveVerbs[i] = verb end`, `:331` `liveVerbs[#liveVerbs + 1] = "profile"` |
| Migration runner | `core/Database.lua:24` `NS.SCHEMA_VERSION = NS.MIGRATIONS[#NS.MIGRATIONS].to`; `:40` `g.schemaVersion = step.to   -- reached only if the step returned`; `defaults/Profile.lua:44` `GLOBAL_DEFAULTS = { schemaVersion = 0, minimap = { hide = false } },` |
| Dead locale keys | scratch script over `locales/enUS.lua` against `core/ modules/ settings/ defaults/`: `689 keys; 0 with no quoted occurrence outside locales/` |
| Bootstrap + header | all 60 source files: line 1 is the bootstrap, line 2 names the file's path |
| Stub parity | `tests/test_surface_parity.lua` (15 cases) loads the addon with the whole payload skipped and compares each stub to its live major; green |
