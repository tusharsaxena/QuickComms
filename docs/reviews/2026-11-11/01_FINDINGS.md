# 01 — Findings (review of 2026-11-11)

**Verdict: minor issues.** Nothing blocks the combined-actions branch on correctness or taint; one
perf ceiling is broken, the test inventory is stale, and four new functions sit above the CCN gate.

**Scope:** `branch` — `feat/2026-11-10-combined-actions` against `master` (merge base `37a1e7b`),
`git diff master...HEAD`: 93 files, +10873 / -1215 (76 outside `docs/`). The measurement ran over
the whole addon. Reviewed in depth: `modules/AutoThank.lua`, `modules/AutoThank_Toast.lua`,
`core/ToastSetup.lua`, `modules/Bake.lua`, `modules/Surfaces.lua`, `modules/Pad.lua`, the
`modules/SendEngine.lua` press path, `modules/Library_Migrate.lua` step 20, `settings/AutoThank.lua`,
the complexity hot spots in `settings/Callouts.lua` and `settings/SlashVerbs.lua`. The test suites
were read for falsifiability where they cover the findings below.

Detected repo profile: `profile=wow kind=addon` (`dev-copilot-profile`, `reason=toc:## Interface`).
The calling command passed the same line; the two agree.

Run note: this review was run inline by the build agent, following
`agents/review.md` plus `profiles/wow/agent-review.md` (dev-copilot 2.9.0), because the session that
ran CA-M5-1 had no subagent dispatch tool. The spec, measurement and artifacts are the agent's.

## Measurement run

All Lua runs through `~/.claude/dev-copilot/bin/ka0s-bounded`; output in the session scratchpad, not
the repo. Kit revision 54 (`tests/_kit/framework.lua`), so the complexity run is sighted.

| Suite | Result | Command |
|---|---|---|
| luacheck | **pass**, 0 warnings / 0 errors in 180 files | `ka0s-bounded luacheck .` |
| Headless suite, Retail | **pass**, 2018 passed, 0 failed, 1 skipped (2019 total, 16 shards) | `ka0s-bounded lua tests/run.lua` |
| Headless suite, Forever | **pass**, 2018 passed, 0 failed, 1 skipped (2019 total, 16 shards) | `KA0S_KIT_CLIENT=forever ka0s-bounded lua tests/run.lua` |
| Test-case inventory | ran; **Total 2018** | `ka0s-bounded lua tests/run.lua --list` (to scratch) |
| Offline perf | **fail**, 1 assertion: `padRebuild12 allocated 91773.6 bytes/iter, over its 70656-byte ceiling` | `ka0s-bounded lua tests/perf.lua` |
| Offline perf, master (comparison) | pass; `padRebuild12` 68156.2 B/iter | same command in a detached `master` worktree in scratch |
| Complexity (sighted) | **pass** by the runner's verdict (non-gating), **5 warnings**, max CCN 17, 5721 functions, 50682 NLOC, blindFiles 0, crashedFiles 0 | `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` |
| Complexity, master (comparison) | 2 warnings: `groupFinderLine` 17, `C.PreviewLines` 17 | the runner's shadow + fixed lizard invocation over the `master` worktree |
| `make test` | not applicable (no root `Makefile`) | — |
| Vendor sync | **clean**: `libs/LibKa0s/` and `tests/_kit/` equal LibKa0s `v1.95.0`'s `LibKa0s/` and `testkit/` (CR-normalized) | `git -C ../LibKa0s archive v1.95.0 LibKa0s testkit`, then `diff -rq --strip-trailing-cr` |
| Cross-addon, class 1 (slash tokens) | **clean**: 36 roots over 18 roster addons, no collision, no raw `SLASH_*` in loaded source | the two loops in the overlay, roster from `WowAddonStandards/standards/ADDONS.md` |
| Cross-addon, class 2 (minors) | **3 lines**: the roster vendors three tags (9 on v1.93.0, 8 on v1.94.0, 1 on v1.95.0, read from each `CLAUDE.md`) — a re-vendor sweep in progress, not a QuickComms fault | the class-2 loop |
| Cross-addon, class 3 (bytes) | QuickComms differs from AbsorbTracker (v1.93.0) in 217 paths: the tag split above; QuickComms itself matches its own tag byte for byte (vendor-sync row) | `diff -rq --strip-trailing-cr AbsorbTracker/libs/LibKa0s <a>/libs/LibKa0s` |
| Cross-addon, class 4 (`## Interface:`) | **clean per slot**: Retail `120105` everywhere, Forever `16001` everywhere | the class-4 loop |

Committed artifacts that disagree with the fresh run:

- `docs/test-cases.md` says `| **Total** | **2014** |` (line 2383) and `### test_autothank.lua (59)`;
  the fresh inventory says 2018 and 63. The README badge reads `Tests-2014%2F2014_passing` (line 7). See F-002.
- `docs/performance.md:63` gives `padRebuild12` a 69 KiB ceiling and a 65516.8 B figure; today's run
  is 91773.6 B. See F-001.
- `docs/automated-tests/RESULTS.md` is current as of `20261104-042401`, measured at `7455a75`, 127
  commits behind HEAD (the runner's own line). Stale, not a finding: regeneration belongs to release.

Standard: the sibling `../WowAddonStandards` checkout, clean, at `a96a7db` which equals
`origin/master` (`git ls-remote`), **Ka0s WoW Addon Standard v2.107.0 (2026-11-10)**. Used as a
guardrail on the fix directions only.

## Medium

### F-001 — `padRebuild12` is 35% over its perf ceiling `[perf]`

- **Where:** `tests/perf.lua:58` — `padRebuild12 = 70656, dialOpenClose = 53248, situationRefresh = 2048,`;
  the scenario at `tests/perf.lua:186` (`measure("padRebuild12", 200, function()`).
- **Problem:** one 12-button pad rebuild allocates 91773.6 B per iteration on this branch against
  68156.2 B on `master` (+23617 B, +34.7%), and the offline runner's one assertion is red.
- **Impact:** every pad rebuild makes about 23 KB more garbage than before. `tests/perf.lua` is outside
  the green gate, so nothing in the branch's gate saw the rise, and the file's own rule is that "a
  rise is the finding" (`tests/perf.lua:28`).
- **Reachability:** any player with a pad shown, on every rebuild (situation, profile, setting and
  library changes, out of combat).
- **Attribution (unverified):** the new per-slot tables are the likely cause. `B.BakeActions`
  (`modules/Bake.lua`) makes `info`, `info.actions`, `info.baked`, `lines` and one entry per action, and
  `S.ApplyActions` / `slotLocks` (`modules/Surfaces.lua`) make `skipped`, `chatTypes` and `locks` per
  slot. `S.SlotLockdown` adds a fresh `{}` per slot without locks (`slot.locks or {}`). Nobody has
  bisected it yet.

### F-002 — The test inventory and badge did not move with CA-M4-R1 and CA-M4-R2 `[tests]`

- **Where:** `docs/test-cases.md:2383` (`| **Total** | **2014** |`), `README.md:7`
  (`Tests-2014%2F2014_passing`).
- **Problem:** the suite runs 2018 cases. The four cases added by `5b301cf` (CA-M4-R1, two cases) and
  `c312a0a` (CA-M4-R2, two cases) are not in the committed inventory, and the badge still says 2014.
- **Impact:** the authoritative pass count is wrong on the branch the PR will merge. testing-§5 says
  the inventory and badge move in the same change.
- **Reachability:** a doc and a badge; no runtime effect.

### F-003 — Four new functions above CCN 15 `[complexity]`

- **Where (fresh sighted run):** `press@549-589@./modules/SendEngine.lua` CCN 16 (`local function press(b)`),
  `actionRows@126-147@./settings/Callouts.lua` CCN 17 (`local function actionRows(out, a, alone)`),
  `scan@74-101@./tests/test_locale.lua` CCN 16 (`local function scan(src)`),
  `CreateFrame@981-1041@./tests/wow_mock.lua` CCN 16 (`M.CreateFrame = function(frameType, name, parent, template)`).
  `groupFinderLine@422-450@./settings/SlashVerbs.lua` CCN 17 is already on `master` and the branch did not change it.
- **Problem:** the release gate is zero functions above CCN 15 (RESULTS.md line 14). The branch adds
  four and keeps one from `master`. (It also clears `C.PreviewLines`, which `master` had at 17.)
- **Impact:** the next release is gated red until they are split.
- **Reachability:** maintainability only; no runtime effect.

### F-004 — The toast's dragged spot skips the schema write seam `[design]`

- **Where:** `modules/AutoThank_Toast.lua:187-190`:
  `setPosition = function(point) local t = thankSettings() if t then t.position = point or false end end,`
- **Problem:** `thank.position` is a schema row with `validate = isPoint` (`settings/AutoThank.lua:53`),
  but the toast's drag writes `db.profile.thank.position` directly. The pads save their place through
  `NS.Library.SetSurfacePoint` (`modules/Pad.lua:99`), which validates and refuses.
- **Impact:** a point the row would refuse is stored unchecked, and the write skips the seam's debug and
  notify side effects. Today the library always passes a well-formed point, so nothing visible breaks.
- **Reachability:** any player who drags the thank toast.

### F-005 — Every in-combat player `UNIT_AURA` allocates a closure and re-queues `[perf]`

- **Where:** `modules/AutoThank.lua:259-262`:
  `if fighting() then State.thankDirty = true NS.SendEngine.Queue("thank.diff", function() AT.OnCombatEnd() end) return end`
- **Problem:** each player `UNIT_AURA` in combat makes a new closure and calls `SE.Queue`, which replaces
  the keyed entry and writes a debug line (`modules/SendEngine.lua:320-323`), even when the set is
  already dirty and the entry is already filed.
- **Impact:** allocation and a queue write on the hottest event the addon hears, in the state where
  garbage costs the most. One entry and one clean flag would do.
- **Reachability:** any player in open-world combat with auto-thank on, which is the default
  (`thank.enabled = true`, `content.openWorld = true`).

## Low

### F-006 — A drag ended by the library can leave every later toast unfaded `[correctness]` (plausible)

- **Where:** `modules/AutoThank_Toast.lua:146-147` (`local function dragStart() TH.dragging = true end`,
  `local function dragStop() TH.dragging = nil end`), hooked on the frame's `OnDragStart` / `OnDragStop`
  (`:154-155`). The library also ends a drag itself, in `takeDown` (`libs/LibKa0s/Toast.lua:463`,
  `if S.moving == R then endDrag(S) end`) and `applyLayout` (`:281`), which calls
  `StopMovingOrSizing` and does not fire the frame's `OnDragStop` script.
- **Problem:** if a drag is still held when the library takes the toast down (the combat-edge `Hold`,
  a right-click close of another toast, a stand-down `Clear`), `TH.dragging` can stay `true`.
- **Impact:** while it stays set, `fade` (`:133`) holds every toast at full alpha and pushes its due
  time, so toasts vanish at the library's timer instead of fading. The next drag clears it.
- **Reachability:** a player who is dragging a thank toast when combat starts. Whether the client still
  sends `OnDragStop` to a frame hidden mid-drag is unverified, so this is **plausible**. It has an
  in-game check (S-4 in `03_SMOKE_TESTS.md`).

## Non-findings worth recording

- **Taint:** the Thank button is armed and disarmed only through `SE.Arm`/`SE.Disarm`, which refuse in
  combat (`modules/SendEngine.lua:124-153`). The toast is held at the combat edge and released only
  when both `Restrictions.InCombat()` and `InCombatLockdown()` read false (`modules/AutoThank_Toast.lua:254-258`).
  No new protected call in an unguarded path was found.
- **Secrets:** `AT.OnAura` tests `IsSecret(info)` and `IsSecret(info.isFullUpdate)` before indexing
  further, and `AT.Accept` reads every field through `IsSecret` / `PlainNumber`.
- **Migration step 20** (`modules/Library_Migrate.lua`) works from frozen inputs, is idempotent, and
  does not resurrect a deleted set.
- **Stand-down:** `tests/test_disabled.lua` pins the unit-filter frame's `UNIT_AURA:player` going away
  through every disable route, with a `-- red under:` line.
