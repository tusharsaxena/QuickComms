# 03 — Evidence: Ka0s Quick Comms

Every citation below was re-read at `18a2b55` before it was written, and the quoted text is what the
line holds (CR stripped). Every count carries the command that produced it and its scope. Repo root
is the working directory for every command unless stated.

## E-SRC — what the run was measured against

```text
$ curl -fsSL … $RAW/AUDIT.md, $RAW/standards/STANDARDS.md, 28 section files, ADDONS.md, CHANGELOG.md
  (RAW = https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master; no fetch failed)
standards/STANDARDS.md:1: # Ka0s WoW Addon Standard (v2.88.0, 2026-10-24)

$ git -C ../WowAddonStandards status --porcelain          -> (empty)
$ git -C ../WowAddonStandards rev-parse HEAD             -> b9ee560fcffce7fa025199b68994baf3a228ae16
$ git -C ../WowAddonStandards ls-remote origin refs/heads/master -> 36da4ef31b8268d1d6be2be7058fb458dd2e506c
$ diff -rq <fetch>/standards ../WowAddonStandards/standards
  -> STANDARDS.md, CHANGELOG.md, anti-patterns.md, debug-logging.md, library-stack.md, open-evolutions.md,
     options-ui.md, standalone-windows.md differ; Only in sibling: standards/skinning.md (+4 non-normative files)
```

Sibling HEAD ≠ remote master, so the sibling failed the currency check; the network fetch (v2.88.0) is
the standard of record. `dev-copilot-profile`: `kind=addon`, reason `toc:## Interface`.

## E-MECH — the mechanical runs

All runs through `~/.claude/dev-copilot/bin/ka0s-bounded`; none exited 124 or 137.

```text
$ ka0s-bounded luacheck .
Total: 0 warnings / 0 errors in 139 files            (exit 0)

$ time ka0s-bounded lua tests/run.lua
1157 passed, 0 failed, 1 skipped, 1158 total
31.57s user 10.20s system 35% cpu 1:56.06 total      (exit 0; wall includes any slot-pool queueing)
  SKIP  diagnostics contract: an addon that opts out … (this addon keeps the default)

$ ka0s-bounded lua tests/run.lua --list > /tmp/list.md; diff docs/test-cases.md /tmp/list.md   -> identical
docs/test-cases.md: | **Total** | **1157** |      README.md:6: ![Tests](…/badge/Tests-1157%2F1157_passing-green)

$ ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle
  complexity  pass  — 19 warnings (fun rate 0.01), 34825 NLOC / 3795 funcs, avg NLOC 8.2, avg CCN 2.6 (max 30)
  record:  newest bundle 20261014-002540 measured 6cc22be, 294 commit(s) behind HEAD
$ git rev-list --count 6cc22be..HEAD  -> 294
```

The `--no-bundle` run prints no warning list, so the list below comes from the runner's own pipeline
reproduced into scratch — its `find` file list, `tests/_kit/lizard_sighted.lua shadow`, and its fixed
`lizard -l lua -L 1500 -x "./libs/*" -x "./tests/_kit/*" .` (runner lines 508-514), nothing added.
Totals agree with the runner (34825 NLOC, 3795 functions, 19 warnings):

| CCN | NLOC | Function | Shape |
|---|---|---|---|
| 30 | 42 | `Lib.SeedFromOverlay` `modules/Library.lua:1102-1145` | branching migration (control flow) |
| 28 | 37 | `S.ApplyAll` `modules/Surfaces.lua:426-478` | control flow |
| 26 | 43 | anonymous `tests/test_dial_shine.lua:97-140` | test table walk |
| 24 | 30 | `G.ReusableCallouts` `settings/Groups.lua:270-306` | control flow |
| 23 | 14 | `P.EditPresetKey` `modules/Preview.lua:320-333` | guard ladder (`or` / type guards) |
| 22 | 34 | `R.Look` `modules/Dial_Render.lua:246-279` | dense defaulting (`tonumber(x) or D.x`) |
| 19 | 26/25/26/26 | `DS.Load`, `PL.Compute`, `expandOne` (`modules/Tokens.lua:19`), `W.Summary` (`settings/Groups_When.lua:473`) | mixed |
| 18–16 | — | `Pad.Apply`, `Dial.Apply`, `R.PointerUpdate`, `W.ResolveValue`, `R.SkinFor` (defaulting), `oldDungeonWhen`, `Lib.ValidWhenValue`, `V.PreviewLines`, `encode` (`tools/render-shine-preview.lua`) | mixed |

`docs/automated-tests/RESULTS.md` (the record of `20261014-002540`): "Max CCN **15** across 2364
functions, **0** of them warned on; 1 file(s) in the 1000–1500 band". No watch-list entry exists, so
none can have carried *Accepted* for three runs (anti-pattern #53 has no instance), and no
watch-list-driven refactor happened since (performance-§11 has nothing to audit).

## E-VEND — vendored LibKa0s drift

```text
CLAUDE.md:42: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.77.0 (MIT).
CLAUDE.md:43: LibKa0s icons: all (icon browser).
$ grep -n 'Bundles \[LibKa0s\]' README.md   -> (none)
$ git -C ../LibKa0s rev-parse v1.77.0       -> e9b126d961c2970e5b14d0566480f7c1d8b5e5e8
$ git -C ../LibKa0s ls-remote --tags origin v1.77.0 -> e9b126d961c2970e5b14d0566480f7c1d8b5e5e8 (same)
$ git -C ../LibKa0s archive v1.77.0 LibKa0s testkit | tar -x -C <scratch>
$ diff -r <scratch>/LibKa0s libs/LibKa0s     -> (empty; no line at all, media/icons included)
$ diff -r <scratch>/testkit tests/_kit       -> (empty)
tests/_kit/framework.lua:20: Kit.VERSION = 42
$ git ls-files -s tests/_kit/run-automated-tests.sh -> 100755 …
```

Chooser for `all`: `settings/IconBrowser.lua` (the Glyphs tab offers every catalog icon).
README `## Credits` (`README.md:150-162`) credits Open Iconic, Phosphor and Game-icons.net with
license, link, the full author list and the modification statement.

Re-vendor bundles (`AUDIT.md` step 4 script, scope: commits touching `libs/LibKa0s` or `tests/_kit`
since `2026-10-22 00:00`): vendored `v1.75.0 v1.75.1 v1.75.2 v1.76.0 v1.77.0`; recorded the same five;
unrecorded: none.

## E-LE — line endings

Pin and carve-outs, verbatim (`.gitattributes:26,36,37`, CR stripped):

```text
* text=auto eol=crlf
*.sh text eol=lf
*.py text eol=lf
```

`file .gitattributes` → "with CRLF line terminators", so the playbook's literal `grep -n '…$'` checks
print nothing on the working copy; run on `tr -d '\r' < .gitattributes`: pin at 26, carve-outs at
36-37, `grep -c ' binary$'` = **20**. `head -84` of the stripped file against line-endings-§5's
client-bound body (extracted from the fetched section): **identical**, nothing below it. Check (e),
run verbatim from `AUDIT.md` over `git ls-files -z` (whole tracked set, no exclusions): **0**. Kit gate
`{ name = "test_eol", dir = "tests/_kit/" }` at `tests/run.lua:196`.

## E-PKG — packaging

```text
.pkgmeta:19:   - media/logos/*.png   # the editable logo source (layout-§4): committed, never loadable, never shipped
$ grep -n 'jpg' .pkgmeta   -> (none)
$ git ls-files media/logos -> quickcomms.logo.128.tga, quickcomms.logo.jpg, quickcomms.logo.png, quickcomms.logo.tga
$ ls -l media/logos/quickcomms.logo.jpg -> 1605114 bytes
```

`AUDIT.md` packaging (a)/(b)/(c): (a) nothing un-ignored; (b) only `.git` (exempt); (c) no false claim
(`.claude` and `.playwright-mcp` are commented-out lines). The packaging template carries
`  - media/logos/*.jpg   # a .jpg render of the logo, for the project page; same reason`.

TGA headers (bytes 2, 12-15, 16): `quickcomms.logo.128.tga` type 2, 128×128, 32 bpp;
`quickcomms.logo.tga` type 2, 300×300, 32 bpp. `QuickComms.toc:6`:
`## IconTexture: Interface\AddOns\QuickComms\media\logos\quickcomms.logo.128.tga`.

## E-CAP — layout census

```text
$ git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs wc -l | sort -n | tail -7
  1027 tests/wow_mock.lua   1065 tests/test_library.lua   1316 modules/Library.lua
  1348 locales/enUS.lua     1392 tests/test_dial.lua      1500 tests/test_page_groups.lua
```

Scope: every tracked authored `.lua`, `tests/` and `tools/` included, vendored folders excluded; the
repo declares no generated-data exemption (`tests/run.lua:136-137`). None over 1500; six in the band.
`docs/ARCHITECTURE.md:387`: "Nothing is over the cap today."

## E-03 — QC-03 (disabled suite)

```text
tests/test_disabled.lua:290:  if r.kind == "message" then NS.addon:SendMessage(r.event) else ran = ran + m.__fire(r.event) end
tests/test_disabled.lua:294:  ran = ran + m.__fire("PLAYER_REGEN_DISABLED")
tests/test_disabled.lua:300:  assertEqual(m.__fireUnconditional(NS.addon, "PLAYER_REGEN_DISABLED"), 1, "the combat handler reached")
tests/test_disabled.lua:476:  test("disabled [by hold]: under the perf hold alone, the Toggle Comms Pads key press refuses as /qc toggle does", function()
tests/test_disabled.lua:506:  NS.SlashVerbs.TogglePads()
```

Step walk (slash-commands-§7): 1 `:251-257` (R_on, T_on, F_on, `#snap.R > 0`); 2 `:243`; 3 `:268-271`
with `-- red under` at `:267`, `:269`; 4 `:272`, `:305`; 5 `:279`; **6 partial** — the loop at
`:289-291` fires the 25 pinned events (`:13-21`) and the messages through the live dispatch, which
reaches nothing after the stand-down (`ran == 0` at `:295`), and only `PLAYER_REGEN_DISABLED` is fired
unconditionally (`:300`); 7 `:312-347` (every `NS.COMMANDS` row and the bare `/qc`; the capture line at
`:468-474`); **8 partial** — `:349-383` covers both clicks; the key press is driven only under the
`perf` hold (`:476-487`) and, with both holds, by calling the handler (`:506`), never by pressing the
bound button while disabled; 9 `:385-402`; 10 `:436-444` with `-- red under` at `:433`.

## E-08 — QC-08 (compat count)

```text
$ cat core/Compat*.lua | grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.'   -> 31   (one family file: core/Compat.lua)
docs/compat-layer.md:9:  **Twenty-seven shims**, counted the way documentation-§3 counts them
docs/compat-layer.md:10: (`cat core/Compat*.lua | grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.'` answers `27`). The two
docs/ARCHITECTURE.md:345: | `compat-layer.md` | Present | `core/Compat.lua` publishes 27 shims, three or more |
$ grep -cE '^\| `[A-Za-z]+\(' docs/compat-layer.md  -> 30
missing from the page's table: Compat.UnitDisplayName
```

## E-16 — QC-16 (README placeholders)

```text
$ grep -nE '<[A-Za-z][^>]*>' README.md | grep -v '<br>'
README.md:37: WoW's menu shows on the button as `<key> +1`, named in its tooltip). …
README.md:81: the channel the previewed situation picks and the text with its tokens filled, `<target>` and the
README.md:85: only the group you are editing, sending nothing: a click prints `[QC] /p <text>`, the line it would
```

documentation-§1: "Angle-bracket placeholders MUST NOT appear in shipped README content. CurseForge
strips `<setting>`, `<name>`, `<value>` and the like as unknown HTML tags — including inside backticks".

## E-17 — QC-17 (stub help row)

```text
settings/Slash.lua:277:  local function helpRow(entry) return SLASH .. " " .. entry[1] .. " — " .. entry[2] end
settings/Slash.lua:302:  for _, entry in ipairs(COMMANDS) do NS.Print("  " .. helpRow(entry)) end
```

slash-commands-§1: "In particular it MUST NOT copy `FormatRow`. A degraded help row prints
`cmd  desc` plainly, with no gold command and no em dash."

## E-18 — QC-18 (gray-outs on color rows)

```text
settings/SchemaMembers.lua:484:  local pairs3 = { { "shineTint", L["Shine tint"], "useClassColorShineTint", off },
settings/SchemaMembers.lua:492:          r.disabledIf = p[4]            (the three shine color pairs; shineRows runs for pads :532 and dials :614)
settings/SchemaMembers.lua:631:  for _, r in ipairs(pair(POINTER, "pointerColor", L["Pointer color"], "useClassColorPointer", HUB_TAB)) do
settings/SchemaMembers.lua:632:      r.disabledIf = pointerOff
settings/SchemaMembers.lua:693:  for _, r in ipairs(pair(BORDER, "dotBorderColor", L["Dot border color"], "useClassColorDotBorder")) do
settings/SchemaMembers.lua:694:      r.disabledIf = borderOff
settings/SchemaMembers.lua:706:  for _, r in ipairs(pair(BACK, "dotBackColor", L["Indicator background"], "useClassColorDotBack")) do
settings/SchemaMembers.lua:707:      r.disabledIf = backOff
settings/SchemaMembers.lua:739:  stampBlock(font, O.FontGroup(blockSpec(LABELP, LABELS, SLICE_LABELS, ldef)), LABELP, composedChecks(O), "dial")
settings/SchemaMembers.lua:741:      row.disabledIf = hidden        (the whole block, its Font color pair included)
settings/SchemaMembers.lua:775:  stampBlock(font, O.FontGroup(blockSpec(TITLEP, LABELS, TITLES, tdef)), TITLEP, composedChecks(O), "dial")
settings/SchemaMembers.lua:777:      row.disabledIf = hidden
```

Eleven pairs: 3 shine × 2 surfaces, pointer, dot border, indicator background, two font colors.
`gh issue view 11` — *Stop graying color pairs (options-ui-§17, anti-pattern #74)*, `state:untriaged`,
`severity:low`. Upstream: `open-evolutions.md:245-250` (*Gating a swatch on its feature's own switch
(deferred, owner call CALL-05)* … "Not ruled at v2.88.0"), WowAddonStandards#13 OPEN.

## E-19 — QC-19 (labels)

```text
settings/Groups.lua:373:  { text = L["Duplicate"], tooltip = NS.Library.IsChild(gid)
settings/Groups.lua:377:  { text = L["Delete group"], tooltip = L["Delete this group and its callouts, and take it off every pad. Asks first."],
settings/Pads.lua:170:    { text = L["Delete pad"], tooltip = L["Delete this pad. Its groups and callouts are kept. Asks first."],
settings/Dials.lua:189:   h.InlineButtonPair(ctx, { text = L["Delete dial"],
settings/Editors.lua:751: StaticPopup_Show(DELETE_POPUP, name, nil, onAccept)        (reached by all three deletes)
locales/enUS.lua:761: L["Duplicate"] = "Duplicate"      :762 "Delete group"   :880 "Delete pad"   :967 "Delete dial"
```

Other §21 greps (units, `Max`, `alpha` labels, `&`, location arrows in settings text) return no
finding: the only `->` hits are debug lines and two `check` chat lines, not settings locations.

## E-21 — QC-21 (modals)

```text
$ grep -rn 'SetToplevel' --include='*.lua' core modules settings   -> (none)
$ grep -rn 'SetClampedToScreen' --include='*.lua' core modules settings
modules/Pad.lua:272:            root:SetClampedToScreen(true)
modules/PreviewWindow.lua:166:  f:SetClampedToScreen(true)
settings/ModalWindow.lua:119-131: MW.Build — SetFrameStrata, SetFrameLevel, SetSize, SetPoint("CENTER", UIParent, "CENTER", 0, 0), EnableMouse; no SetToplevel, no SetClampedToScreen
```

## E-22 — QC-22 (hub shape)

```text
$ wc -lc docs/ARCHITECTURE.md   -> 387 lines, 81866 bytes;  fold -w 100 -s | wc -l -> 1047
per section (raw lines / chars / lines wrapped at 100):
  Overview 48/3941/64      Module Map 49/17683/201     Settings Schema 54/14060/159
  Message Bus 18/3345/43   Slash Commands 8/947/12     Event Subscriptions 22/1662/25
  Taint Notes 3/11741/120  Frame layering 25/1758/30   Known Limitations 51/14158/168
  Documentation map 47/2670/55                          Documented deviations 22/7114/84
docs/ARCHITECTURE.md:336-346  ### Conditional — rows: perf-analysis/README.md, slash-dispatch.md, profiles.md,
  debug.md, midnight-quirks.md, compat-layer.md, message-bus.md   (no known-limitations.md, no taint.md)
$ ls docs/known-limitations.md docs/taint.md   -> No such file or directory (both)
```

## E-23 — QC-23 (named state)

```text
docs/ARCHITECTURE.md:170: Whether `/qc toggle` hid the Comms Pads is per character and saved: `db.char.padsHidden` (AceDB's
docs/ARCHITECTURE.md:179: … Its window's place is saved (`previewWindow`, `docs/schema.md`). …
docs/schema.md:41: | `previewWindow` | … | `modules/PreviewWindow.lua` only: the window's drag stop | …
docs/schema.md:83: | `padsHidden` | `false` | whether `/qc toggle`, the launcher's Show window or the Toggle Comms Pads key last hid …
settings/SlashVerbs.lua:72: function V.TogglePads()
settings/SlashVerbs.lua:76:     NS.db.char.padsHidden = hidden
```

## E-24 — QC-24 (doc drift)

```text
docs/ARCHITECTURE.md:134-135: … `enabled`, `visibility`, `scale`, `alpha` and `locked` (defaults `true`, `always`, 1, 1, `true`) …
defaults/Profile.lua:20:      locked     = false,      -- Lock frame: a new profile starts unlocked (owner, 2026-10-22; spec §5.1 locked)
docs/schema.md:22: | `locked` | `false` | … | a new profile starts unlocked (owner, 2026-10-22; locked before) …
docs/schema.md:21: | `alpha` | `1.0` | the Master alpha row | the ceiling of every pad's fade |
docs/settings-panel.md:26: set, in order: Enable, General visibility, Master scale, Master alpha, Lock frame, Debug console,
docs/settings-panel.md:33: | Master scale (`scale`, 0.5-2) | Master alpha (`alpha`) |
docs/ARCHITECTURE.md:281: … a profile switch, copy, reset or share string never moves it …
docs/schema.md:36,37,38,47: … they travel in a share string        :39 … reset or share string never moves it
docs/module-map.md:127: … the modal bands, the Share and icon link windows |
$ git log --oneline -1 2f0e2b3 -> Remove the Share (export/import) feature before v0.1.0
$ grep -rni 'share' --include='*.lua' core modules settings (excluding shared/share-of)  -> no Share code remains
```

## E-25 — QC-25 (register row evidence)

```text
docs/ARCHITECTURE.md:377: | `frame-layering-§1` (the secure fixed point), `frame-layering-§4` (windows are toplevel) | … the preview window,
  the Share window, the callout popup and the icon browser sit at `FULLSCREEN` … | … (QC-06) … | 2026-10-24 (item 030; QC-06, 2026-10-18) | …
$ git log --format='%h %ad %s' --date=short | grep QC-06
0901b8c 2026-10-23 QC-06: address review — no Raise on the preview window; lift the confirms over the dial and modals
69719ca 2026-10-23 QC-06: put the callout popup and icon browser above the preview dial
7735f9c 2026-10-13 Audit QC-06: the held stand-down registers PLAYER_REGEN_ENABLED through NS.SafeRegisterEvent
docs/audits/2026-10-13/02_DEVIATIONS.md:33: | QC-06 | `events-frames-taint-§1` | Low | MUST | The held stand-down registers `PLAYER_REGEN_ENABLED` …
tests/test_edit_preview.lua:300: test("preview: [QC-05] the edit preview and Preview as draw every button and wedge exactly as live", …
tests/test_slash.lua:101:        test("slash: [audit QC-05] degraded, `debug on`/`off` flip the flag and ack, and `debug diagnostics` routes", …
```

Other register evidence ids resolve: `gh issue view 49 -R tusharsaxena/LibKa0s` → CLOSED *Promotion
candidates from Drop Watcher…*; `#56` → CLOSED *Promote icon styling and LibCustomGlow glows…*. Row
QC-R4's trigger: `grep -n 'char' tests/_kit/mock_record.lua` → no hit (kit 42 still models no `char`).

## E-26 — QC-26 (TOC positions)

```text
QuickComms.toc:89:  # Conventional: data          QuickComms.toc:90:  defaults\BuiltIns_MythicPlus.lua
QuickComms.toc:91-98: the same label over BuiltIns_Raid, BuiltIns_Arena, BuiltIns_World, BuiltIns_Battlegrounds
QuickComms.toc:99:  # Conventional: data (declared after the battleground sets: D9)
QuickComms.toc:100: defaults\BuiltIns_Group.lua
defaults/BuiltIns.lua:47:   if def.parent == nil then BI.order[#BI.order + 1] = id end
modules/Library.lua:782:    for _, top in ipairs(NS.BuiltIns.order) do      (seededTops: "in shipped order")
tests/test_builtins.lua:10-19: BI.order[1] == "bi.mplus" … BI.order[#BI.order] == "bi.group"
```

Positions: `defaults\BuiltIns_MythicPlus.lua`, `_Raid`, `_Arena`, `_World`, `_Battlegrounds`, `_Group`.

## E-27 — QC-27 (hub tier copy)

`docs/ARCHITECTURE.md:241-244`: "Every strata and frame level the addon sets is named once, in
`core/Constants.lua` `NS.Constants.LAYERS` … so this section names the tiers and does not copy the
numbers. Bottom to top:" followed by six bullets (`:246-259`) giving each tier's strata and frames —
the content of `core/Constants.lua:38-68`.

## E-28 — QC-28 (gate speed)

Gate CPU 31.57 s user + 10.20 s system (E-MECH); `grep -n 'jobs' tests/run.lua` → none;
`docs/audits/2026-10-13/02_DEVIATIONS.md:58`: "Gate speed: 10.8 s wall serial".

## E-29 — QC-29 (lint)

```text
.luacheckrc:58:  -- core/Compat.lua: a dial's key is WoW's own binding of its Open Comms Dial entry: read, set, saved
.luacheckrc:60:  "GetBindingAction", "GetBindingKey", "SetBinding", "SaveBindings", "GetCurrentBindingSet",
$ for g in GetBindingAction SetBinding SaveBindings GetCurrentBindingSet; do grep -rlw $g core modules settings defaults locales; done
  -> only modules/SendEngine.lua:29, a comment naming the library's SetBinding; no call
```

## E-30 — QC-30 (dial screen catcher)

`docs/ARCHITECTURE.md:279`: "While a dial is open from its key, its full-screen catcher takes every
click outside it (it closes the dial and does nothing else) …"; `modules/SendEngine.lua:253`:
`s:SetFrameStrata(LAYERS.STRATA.DIAL_SCREEN)`; `core/Constants.lua:44-48` documents the tie with the
Settings panel (QUI-Z09).

## E-COMPLIANT — compliance claims made in 01/02

- **Bus**: `grep -rnE '(Send|Register)Message\("Ka0s_' …` → none; wire names only at `core/Bus.lua:22-30`, PascalCase.
- **Close button grep**: `core/CoreSetup.lua:107` (`return lib.MakeCloseButton(parent, onClick, addonName)`, the wrapper),
  `modules/PreviewWindow.lua:185` and `settings/ModalWindow.lua:94` (`NS.MakeCloseButton(...)`), tests only otherwise.
- **Layering greps**: `SetFrameStrata("` none; absolute `SetFrameLevel(<digit>` none; the three sibling-form hits
  (`modules/IconStyle.lua:131`, `modules/Pad_Render.lua:168`, `:187`) are relative to `btn`, the band owner.
- **Settings-window calls**: `grep -rnE 'SettingsPanel|HideUIPanel|ToggleGameMenu|OpenToCategory'` → `settings/Editors.lua:726`
  (page jump, gated at `:715`, ID from `category:GetID()` at `:721`); `HookScript("OnHide")` at `settings/CalloutPopup.lua:464`,
  `settings/IconBrowser.lua:574`, `modules/Preview.lua:499`; no close, hide or commit.
- **Keybinding editor**: `grep -rnE 'Create\("Keybinding"\)|SetBinding\(|SaveBindings|KeybindListener' … | grep -v /libs/ | grep -v /tests/` → none;
  `settings/Panel.lua:93` `Helpers.KeybindingsTab({ bindings = NS.BINDINGS, … })`, `:114` `ResetAllTooltip(Helpers.KEYBINDS_UNCHANGED)`.
- **Registration census** (TOC load list, 77 files): registrations at `core/QuickComms.lua:29`, `modules/SendEngine.lua:379`, and
  `RegisterMessage` on per-module targets (`Dial.lua:491`, `Pad.lua:624-625`, `Preview.lua:522`, `PreviewWindow.lua:270,273`,
  `SendEngine.lua:545`, `Situation.lua:200`, `Surfaces.lua:564`, `CalloutPopup.lua:587`, `Editors.lua:166`, `Groups.lua:580`,
  `IconBrowser.lua:735`); undone by `core/QuickComms.lua:48-50` and each module's `STAND_DOWN`.
- **Diagnostics**: one `"diagnostics"` row (`settings/Slash.lua:56`); `grep -rniE '"(diag|dump|dx)"' settings core modules` → none;
  `runDebug` defers to `DebugVerb` first (`:413-416`); `README.md:130-136` verbatim.
- **Notation**: the `documentation-§6` sweep command (frozen stores, `libs/`, `tests/_kit/`, `docs/brainstorm/` excluded) returns only
  design-spec citations (`spec §9.2`, `spec §4.1` …); 353 `filename-§N` citations over the same scope, 84 distinct, all within
  `grep -c '^### [0-9]'` of their file.
- **Headers**: every `core/ modules/ settings/ defaults/ locales/` file has `local …NS = ...` on line 1 and `-- <its path>` on line 2.

## E-PRIOR — prior findings verified closed

| ID | Evidence |
|---|---|
| QC-01 | `settings/Schema.lua:342` carries the verbatim sentence; `tests/test_schema.lua:163` pins it |
| QC-02 | `settings/Editors.lua:715-718`: `if NS.Compat.InCombat() then QC:OpenSettings() return false end` |
| QC-04 | `tests/test_schema.lua:129`: "[audit QC-04] the global reset takes every created member back to a fresh profile, and only this one" |
| QC-05 | `core/DebugLogSetup.lua:75-80` stub `DebugVerb`; `tests/test_slash.lua:101` |
| QC-06 | `modules/SendEngine.lua:379`: `NS.SafeRegisterEvent(pending, "PLAYER_REGEN_ENABLED", onRegenEnabled, NS.rejectedEvents)` |
| QC-07 | `modules/Pad_Render.lua:199` `lockMark or LOCK_ICON`; `modules/Dial_Render.lua:473` `mark(btn.qcLock, "lock", LOCK_ICON, …)` |
| QC-09 | `core/Compat.lua:9`: "Library-absent guard arm: LibKa0s docs/api/Compat/version-1-docs.md, "Degradation" (options-ui-§1)." |
| QC-10 | `QuickComms.toc:46` Compat now "Conventional: … read inside functions only"; `:55` State's comment rewritten |
| QC-11 | no `boundSig`; change gates used (`settings/CalloutPopup_Skin.lua:113`) |
| QC-12 | commit `d4d51f9` (buckets lowerCamelCase) |
| QC-13 | `settings/OptionsSetup.lua:129-130` `colorDecode` / `colorEncode` |
| QC-15 | `.pkgmeta:13` `# - .playwright-mcp …` commented out |
