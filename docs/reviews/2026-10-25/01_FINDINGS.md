# 01 — Findings (Ka0s Quick Comms, review of 2026-10-25)

**Verdict: minor issues.** No player-facing defect rates above Medium. The project's own release gate is red today, though (the perf ceilings in F-001 and complexity in F-002), so the pending v0.1.0 tag is blocked until both are dealt with.

**Resolved scope:** the whole repository (`all`) at `18a2b55` on branch `feat/2026-10-25-review-audit-fixes`, with a clean tree. That covers authored Lua in `core/ defaults/ locales/ modules/ settings/ tests/ tools/`, plus `Bindings.xml`, the TOC, `.luacheckrc` and `docs/`. `libs/` and `tests/_kit/` are vendored: only their descriptors and stubs were reviewed, and their byte identity was measured. `docs/audits/` was not touched, because a standards audit runs at the same time.

Profile: `profile=wow kind=addon`. This matches the caller's `Detected repo profile:` line.

Standards cross-check: done against Ka0s WoW Addon Standard **v2.88.0 (2026-10-24)**, fetched from `raw.githubusercontent.com/.../master`. The sibling `../WowAddonStandards` checkout was **not** used. Its HEAD `b9ee560` (v2.89.0, 2026-10-25) is ahead of `origin/master` `36da4ef`, so the freshness check failed.

## Measurement run

All runs used `~/.claude/dev-copilot/bin/ka0s-bounded` from the repo root, with output written to the session scratchpad and nothing written into the repo. The interpreter was `lua5.1` 5.1.5.

| Suite | Result | Command | Counts |
|---|---|---|---|
| luacheck | **pass** | `ka0s-bounded luacheck .` | 0 warnings / 0 errors in 139 files |
| Headless tests | **pass** | `ka0s-bounded lua5.1 tests/run.lua` | 1157 passed, 0 failed, 1 skipped, 1158 total (skip: `diagnostics contract: an addon that opts out …`, declared) |
| Inventory (`--list`) | **pass, no drift** | `ka0s-bounded lua5.1 tests/run.lua --list` → scratch | Total 1157, Skipped 1. Identical to the committed `docs/test-cases.md` after CR strip (`diff` empty). README badge `Tests-1157%2F1157_passing` agrees |
| Offline perf | **FAIL** (exit 1) | `ka0s-bounded lua5.1 tests/perf.lua` | 2 assertions failed: `padRebuild12` 87026.8 B/iter vs 70656 ceiling; `dialOpenClose` 2317.1 vs 2048. The other four scenarios are within their ceilings (`bracketCaptureOff` 0.0, `dialPointerCaptureOff` 224.0, `dialPointerNoHarness` 224.0, `situationRefresh` 2016.0) |
| Complexity (sighted) | runner `pass` (non-gating); **release-gate fail** | `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` | 19 warnings, max CCN 30, 3795 functions, 34825 NLOC. Kit revision 42 (sighted); no blind-file or crashed-file line was printed. Names come from the runner's own shadow plus the fixed invocation, run in scratch |
| `make test` | not applicable | — | no root `Makefile` |
| Vendor sync | **pass** | `diff -rq libs/LibKa0s <scratch>/LibKa0s` and `diff -rq tests/_kit <scratch>/testkit`, both from `git -C ../LibKa0s archive v1.77.0` | both empty. The sibling's HEAD is v1.78.0, which differs as expected, so the diff was taken at the tag the addon vendors |
| Cross-addon class 1 (slash tokens) | **clean** | the two loops in the brief, roster from `WowAddonStandards/standards/ADDONS.md` (15 addons) | 30 roots, 0 collisions, 0 raw `SLASH_*` in loaded source; QuickComms owns `qc`, `quickcomms` |
| Cross-addon class 2 (minors) | **split, 2 lines** | minors loop over 15 `libs/LibKa0s` | 14 addons at `Bus:2 Compat:1 Core:12 DebugLog:21 Env:2 Glow:1 Item:3 Launcher:5 Lifecycle:3 Media:5 Options:30 Perf:15 Pool:3 Schema:2 Sim:2 Slash:20 Widgets:15`, which equals the per-major minors at `v1.77.0`. LootHistory alone is at v1.78.0 (`Core:13 DebugLog:22 Media:7 Options:33 Skin:4 Widgets:16`). See F-010 |
| Cross-addon class 3 (bytes) | **clean for QuickComms** | `diff -rq AbsorbTracker/libs/LibKa0s <each>/libs/LibKa0s`, reference AbsorbTracker (57 files) | outside LootHistory, the only output is `media/icons` "Only in" lines, which are per-addon icon subsets. QuickComms ships 5892 files, equal to the v1.77.0 payload count (`git ls-tree … LibKa0s \| wc -l` = 5892) |
| Cross-addon class 4 (`## Interface:`) | **clean** | interface loop | one value, `120105`, across 15 |
| Library rows at v1.77.0 | measured | the brief's library-row commands | 17 majors, kit revision 42, 5892 payload files; provenance tags are 14 at v1.77.0 and LootHistory at v1.78.0 |

**Committed artifacts that disagree with today's run**

- `docs/performance.md:57-58` still records `padRebuild12` at "69 KiB" and `dialOpenClose` at "2 KiB". Today's figures are 87026.8 and 2317.1 B/iter, so the write-up is stale (F-001).
- `docs/automated-tests/RESULTS.md:35` / `:77`, newest bundle `20261014-002540` at `6cc22be`, 294 commits behind HEAD, reads "Max CCN **15** … **0** of them warned on". Today's sighted run has 19 warnings and max CCN 30 (F-002).
- `docs/scope.md:33` says "the release gate is green". Today, perf fails and complexity has 19 warnings (F-001, F-002, F-004).
- `docs/test-cases.md` and the README `[tests]` badge both agree with today's run.

**Perf bisection.** Each historical commit was extracted with `git archive <sha>` into scratch and run with `ka0s-bounded lua5.1 tests/perf.lua`. All figures come from this machine on this day, and they are only compared with each other.

- `dialOpenClose`: 1356.6 at `239b665`, then 2317.1 at `71c85f2` (2026-10-21, the shine-build merge), and unchanged since.
- `padRebuild12`: 66008.0 at `71c85f2`, then 86888.4 at `65f3a5a` (2026-10-22, "shipped look"), 86890.8 at `0df7e14`, and 87026.8 at `c753867`/HEAD.
- Experiment on a scratch copy of HEAD with `defaults/PadStyle.lua:70` `shineLook` set to `"none"`: `padRebuild12` = 66290.8, which is −20736.0 B/iter. With the dial's `shineLook` (`:116`) set to `"none"`, `dialOpenClose` stays at 2317.1.

## Medium

### F-001 — The offline perf runner has been red for four days, and two committed ceilings no longer describe the code `[perf]` `[tests]`

- **Where:** `tests/perf.lua:34-38`, quoted: `padRebuild12 = 70656, dialOpenClose = 2048, situationRefresh = 2048,`.
- **Problem:** two of the runner's six deterministic assertions fail today. No re-measured "Raised …" note exists for either rise, although the file's own rule (`tests/perf.lua:27-28`) says: "Raise a ceiling only by re-measuring and saying why; a rise is the finding."
- **Impact:** `docs/testing.md:86` makes `perf` a release gate ("recorded, never fails a run or blocks a commit | gates"), and so does automated-tests-§3, *The release gate*. The v0.1.0 tag cannot be cut as things stand, and `docs/performance.md:57-58` misreports both figures.
- **Reachability:** only the maintainer, at the v0.1.0 release run (`/dev-copilot:bump-version` reads `perf` from the manifest). Players are not affected directly. These are headless-mock bytes, which the runner itself warns overstate client allocation.
- **Measured:** `padRebuild12` 87026.8 vs 70656 (+23%); `dialOpenClose` 2317.1 vs 2048 (+13%). By bisection, the pad rise is the shipped Gloss fade default (`defaults/PadStyle.lua:70`, `shineLook = "glossfade", shineStrength = 80,`) painted on every button at every rebuild, outside the look signature (`modules/Pad_Render.lua:489-490`, `Glow.Button(btn, sizedGlow(cl, w, h))` / `NS.Shine.Apply(btn, cl.shine, w, h)`). Turning it off removes 20736.0 B/iter. The dial rise lands in `239b665..71c85f2`; its cause inside that range was not narrowed further and is **unverified**.
- **Fix direction:** reduce the cost first (guard the shine paint as the rest of the look is guarded), then raise any remainder with the dated note the file requires. Never gate a commit on perf (automated-tests-§3).

### F-002 — 19 functions are above CCN 15 against a release gate that requires zero, and the committed watch list says zero `[complexity]`

- **Where:** fresh sighted run, warned functions by `location@lines`. All 19 are listed for the record: `Lib.SeedFromOverlay@1102-1145 modules/Library.lua` (CCN **30**), `S.ApplyAll@426-478 modules/Surfaces.lua` (28), `(anonymous)@97-140 tests/test_dial_shine.lua` (26), `G.ReusableCallouts@270-306 settings/Groups.lua` (24), `P.EditPresetKey@320-333 modules/Preview.lua` (23), `R.Look@246-279 modules/Dial_Render.lua` (22), `DS.Load@321-347 modules/Dial_Secure.lua` (19), `PL.Compute@281-308 modules/Pad_Layout.lua` (19), `expandOne@19-45 modules/Tokens.lua` (19), `W.Summary@473-498 settings/Groups_When.lua` (19), `Pad.Apply@370-418 modules/Pad.lua` (18), `R.PointerUpdate@103-129 modules/Dial_Render.lua` (17), `Dial.Apply@248-301 modules/Dial.lua` (17), `W.ResolveValue@544-569 settings/Groups_When.lua` (17), `encode@108-145 tools/render-shine-preview.lua` (16), `R.SkinFor@333-347 modules/Pad_Render.lua` (16), `oldDungeonWhen@39-48 modules/Library_Migrate.lua` (16), `Lib.ValidWhenValue@382-395 modules/Library.lua` (16), `V.PreviewLines@127-154 settings/SlashVerbs.lua` (16).
- **Problem:** automated-tests-§3 ("`suites.complexity.warnings` at **0**") and `docs/testing.md:87` ("gates, with zero functions above CCN 15") both block a release on this. The committed record (`docs/automated-tests/RESULTS.md:77`, "Max CCN **15** across 2364 functions, **0** of them warned on") was measured 294 commits ago and is stale.
- **Impact:** the v0.1.0 tag is blocked. Several entries are lizard's `and`/`or` tax rather than tangled control flow, for example `P.EditPresetKey` (CCN 23 in 14 NLOC) and `R.SkinFor` (16 in 15 NLOC). Those are cheap to fix with a data table and one loop. `Lib.SeedFromOverlay` and `S.ApplyAll` are genuine branch density.
- **Reachability:** only the maintainer, at the release run. No runtime effect.
- The previous record predates kit revision 35's sighted shadow only if its runner was older. Its manifest says `6cc22be`. Entries never measured before should be called *newly measured*, not regressions; which entries those are cannot be told from today's run.

### F-003 — Restrictions are never re-read when an encounter or key ends, although the header says they are and a test is named as if they were `[correctness]` `[tests]`

- **Where:** `modules/Restrictions.lua:23-25`, quoted: "A lockdown that lifts with no event of its own is picked up by the next read, and by Refresh, which the messaging edge (phase 2's SendEngine) calls on ENCOUNTER_END and CHALLENGE_MODE_COMPLETED." No shipped file calls `R.Refresh` on either event. The only callers are `:172` (`ADDON_RESTRICTION_STATE_CHANGED`), `:181` (the two `PLAYER_REGEN` edges) and `:208` (stand-up). Census: `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs grep -n 'ENCOUNTER_END\|R.Refresh'`, over authored shipped and test Lua.
- **Problem:** `RESTRICTION_CHANGED` is the only thing that re-runs `Surfaces.RefreshLocks` (`modules/Surfaces.lua:555`). Take a chat lockdown (`InChatMessagingLockdown`, the encounter or challenge-mode type) that clears after the last restriction event and the last combat edge, for example when the client's flag lags the event. That stale `lockdown` stays on the snapshot until some unrelated restriction or combat event arrives.
- **Impact:** Say, Yell and General buttons and wedges keep their padlock and the lockdown chip. A press still sends, because the button stays armed, but it prints "%s may not have been sent. %s" and skips echo tracking (`modules/SendEngine.lua:454-459`). So the player is told a working callout may have failed.
- **Reachability:** players in a Mythic+ key or a raid encounter, after the key completes or the boss dies, when the client's lockdown flag clears after the last `ADDON_RESTRICTION_STATE_CHANGED`/`PLAYER_REGEN_ENABLED` it sends. How often the client orders events that way is **unverified in client**: it needs the in-game check in `03_SMOKE_TESTS.md`.
- **Asleep test:** `tests/test_restrictions.lua:179-188`, `test("restrictions: Refresh announces a lift no event reported", …)`, calls `NS.Restrictions.Refresh("ENCOUNTER_END")` directly. It stays green while nothing wires the event, so it reads as coverage of the end-to-end path without providing it (testing-§12).
- **Constraint for the fix:** `CHALLENGE_MODE_COMPLETED` is already a Situation row on `NS.addon` (`tests/test_disabled.lua:14`, in `PINNED`), and AceEvent keeps one handler per event per object. The fix cannot simply register it a second time.

## Low

### F-004 — Docs still describe the Share feature removed today and the node pinning retired today, and claim a green release gate `[naming]` `[docs]`

- `docs/ARCHITECTURE.md:281`: "a profile switch, copy, reset or share string never moves it".
- `docs/ARCHITECTURE.md:377`: a ratified deviation row names "the Share window", which no longer exists.
- `docs/module-map.md:57`: "`PinNodes`: `middle` and `free` nodes take the winds left over)". `PinNodes` is gone from the code; census `git ls-files | grep -vE '^(libs/|tests/_kit/)' | xargs grep -n PinNodes` finds only this doc line.
- `docs/module-map.md:127`: "the Share and icon link windows".
- `docs/schema.md:36,37,38,47`: "they travel in a share string". `docs/schema.md:39`: "share string never moves it".
- `docs/scope.md:33`: "the release gate is green", contradicted by today's run.
- **Impact:** a reader of the hub or the deviation register is told about frames and features that no longer exist, and is told the release is ready.
- **Reachability:** doc text only; no runtime effect. Change `0df7e14` (remove Share) did not sweep these. Historical notes in `docs/scope.md` that say "removed 2026-10-25" are correct and out of scope here.

### F-005 — `.luacheckrc` still whitelists the retired key editor's binding writers `[lint]`

- **Where:** `.luacheckrc:58-60`, quoted: `-- core/Compat.lua: a dial's key is WoW's own binding of its Open Comms Dial entry: read, set, saved` / `"GetBindingAction", "GetBindingKey", "SetBinding", "SaveBindings", "GetCurrentBindingSet",`.
- **Problem:** `GetBindingAction`, `SetBinding`, `SaveBindings` and `GetCurrentBindingSet` have zero uses in shipped source. Census: each name grepped over `git ls-files '*.lua' | grep -vE '^(libs/|tests/|docs/)'`; only `GetBindingKey` is used. The comment describes behavior retired in `b902e35`.
- **Impact:** lint would wave through a reintroduced hand-rolled key editor (anti-pattern #98, options-ui-§20). That is exactly the regression this config could otherwise catch.
- **Reachability:** none at runtime; it affects lint coverage only.

### F-006 — `SendEngine.Arm`'s "unchanged line rewrites nothing" fast path cannot fire on a rebuild `[perf]` `[naming]`

- **Where:** `modules/SendEngine.lua:107` ("Out of combat only; an unchanged line rewrites nothing.") and `:114` (`if b.qcArmed and b:GetAttribute("macrotext") == line then`). Every rebuild first releases every button through `releaseButton` → `NS.SendEngine.Disarm(btn)` (`modules/Pad.lua:179-182`, called at `:378`). The dial does the same at `modules/Dial.lua:154`/`:161`.
- **Impact:** each pad button and dial wedge pays 4 `SetAttribute` writes per out-of-combat rebuild (2 to disarm, 2 to arm) even when nothing changed, and the comment promises otherwise. The cost is small in absolute terms. No in-client figure exists (`docs/perf-analysis/` has no capture), so it is **unverified**.
- **Reachability:** every player, every out-of-combat rebuild (zone, roster, settings write). It is cost only; behavior is correct.

### F-007 — The `general` channel kind sends to whatever channel 1 is, and the UI calls it General `[ux]`

- **Where:** `core/Compat.lua:236-241` (`--- True when the player is in chat channel 1 (General, by the client's default order):` … `return id ~= nil and id ~= 0`) and `modules/Channels.lua:52`.
- **Problem:** any joined channel 1 counts as General, but channel order is player-configurable. `GetChannelName(1)` also returns the channel's name, and that name is not checked.
- **Impact:** a player whose `/1` is a custom or reordered channel sends a "General" callout there.
- **Reachability:** only players who have reordered their chat channels, or whose channel 1 is not General.

### F-008 — Shipped functions with no shipped caller `[dead-code]`

- **Where:** `modules/Tokens.lua:64` `Tok.UsesGroupToken`, `modules/Restrictions.lua:100` `R.CanSendChat`, `modules/Restrictions.lua:113` `R.ActiveReason`, `modules/Library.lua:479` `Lib.DeleteCallout`, `settings/Groups_When.lua:454` `W.HasAll`. Census: every `function X.Name` in `git ls-files '*.lua' | grep -vE '^(libs/|tests/|docs/)'`, grepped for `[.:]Name` or a quoted `"Name"` in the same set. Each has callers only under `tests/`.
- **Notes:** `UsesGroupToken`'s comment says "a raid-group token, which expands only in a raid (spec §8.1)". Nothing uses it to lock or warn about such a slot outside a raid, so the check it was written for is unwired. `B.ScrollTo` (`settings/IconBrowser.lua:673`) has the same shape but is documented as the scrollbar's programmatic twin, a test seam, so it is not filed.
- **Reachability:** none at runtime; maintenance only.

### F-009 — A test suite sits exactly at the layout-§1 cap, and the registry writer is near it `[design]`

- **Census:** `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | tr '\n' '\0' | xargs -0 wc -l`, default scope (authored Lua, `tests/` in).
- `tests/test_page_groups.lua` has **1500** lines, the cap itself. `modules/Library.lua` has 1316; its sibling's header says it "is at its line budget" (`modules/Library_Migrate.lua:3`). `locales/enUS.lua` has 1348 and `tests/test_dial.lua` 1392.
- **Impact:** the next Groups-page case cannot go into its suite without splitting it, and the F-003 and F-002 work adds cases. This is maintainability only; the census itself is the audit's business.
- **Reachability:** none at runtime.

### F-010 — The collection's LibKa0s minors are split: with LootHistory loaded, QuickComms runs v1.78.0 library code it never tested against `[cross-addon]`

- **Repositories:** QuickComms (v1.77.0, `CLAUDE.md`: "Bundles [LibKa0s](…) v1.77.0 (MIT).") and LootHistory (`../LootHistory/CLAUDE.md:56`, "Bundles [LibKa0s](…) v1.78.0 (MIT)."). LootHistory ships `Core:13 DebugLog:22 Media:7 Options:33 Widgets:16` (plus `Skin:4`); QuickComms ships `Core:12 DebugLog:21 Media:5 Options:30 Widgets:15`.
- **Impact:** LibStub keeps the highest minor, so in a shared session those five majors come from LootHistory's copy, whatever the load order. QuickComms' 1157 cases measure v1.77.0.
- **Reachability:** any player running LootHistory and QuickComms together.
- This is the normal state partway through a re-vendor sweep, not a defect in either repo. The remedy is QuickComms' own re-vendor to v1.78.0 as its own commit (`/dev-copilot:wow-revendor-libka0s`), never an edit under `libs/`.

### F-011 — `Library.Children` scans every group and lowercases names inside its sort comparator, on every rebuild `[perf]`

- **Where:** `modules/Library.lua:80-94`, quoted: `local function key(gid) return tostring(groups[gid].name or gid):lower() end` inside `table.sort(out, function(a, b) local x, y = key(a), key(b) …`.
- **Callers:** called per ordered group per pad and dial (`modules/Surfaces.lua` `childrenOf`), and from `Lib.ValidParent`. Added today (owner, 2026-10-25, A–Z children).
- **Measured:** `padRebuild12` moved 86890.8 → 87026.8 B/iter between `0df7e14` and `c753867` (+136), on the mock.
- **Reachability:** every player, every rebuild. Small cost; behavior is correct.

## Upstream findings

None. No defect was found in `libs/` or `tests/_kit/`. Both are byte-identical to LibKa0s `v1.77.0`.

## Non-findings recorded (measured clean)

- The secure-write firewall (`modules/SendEngine.lua` as the only secure writer) and the leading-`/` and control-character sanitizer (`modules/Bake.lua:25-38`, `modules/Tokens.lua:40-41`) were read and hold.
- The disabled-state suite (`tests/test_disabled.lua`) carries `-- red under:` comments for steps 3, 6 and 10, and asserts on the registration set.
- `Bindings.xml` has one category, no `header=` and no `default=`.
- The load lists in `tests/loader.lua` are derived from the TOC (`Loader.tocFiles`, `Loader.xmlFiles`).
- Every bucket in `core/PerfSetup.lua` is bracketed. The zero-overhead pair (`dialPointerCaptureOff` 224.0 == `dialPointerNoHarness` 224.0) holds today.
