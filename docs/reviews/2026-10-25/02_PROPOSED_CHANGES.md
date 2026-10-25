# 02 — Proposed changes (HLD + LLD)

**Standard resolved:** Ka0s WoW Addon Standard **v2.88.0 (2026-10-24)**, network fetch of `STANDARDS.md` and its 28 linked section files from `raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`. The sibling checkout `../WowAddonStandards` (`b9ee560`, v2.89.0, unpushed) was not used: its HEAD did not match `origin/master` (`36da4ef`). Re-check the changes below against v2.89.0 once it is pushed.

Scope and finding IDs refer to `01_FINDINGS.md`. No change below targets a path under `libs/` or `tests/_kit/`.

## HLD — themes

### T1. Make the release gate tell the truth (F-001, F-002, F-004)

- **Why:** the owner's next act is the v0.1.0 tag. Two of the four release suites fail on today's tree, and the docs say the gate is green.
- **Approach:** cut the measurable perf cost first, then record any remaining rise as the runner's own rule requires. Retire complexity warnings with the four permitted refactor shapes (performance-§11), each preceded by a characterization test where the function lacks coverage (testing-§13). Then correct the docs.
- **Alternatives rejected:**
  - Raising both ceilings with no reduction is permitted by `tests/perf.lua:27-28`, but it would leave 20.7 KB/iter of avoidable mock churn per pad rebuild unexamined.
  - Gating commits on perf or complexity is forbidden by automated-tests-§3 ("MUST NOT fail a run, or block a commit, on a perf or complexity result").
  - Hand-editing `RESULTS.md` figures or regenerating the record here is out of bounds: regeneration belongs to the release run (`/dev-copilot:bump-version`), and only the `Disposition` column is authored (automated-tests-§4).
- **Trade-off:** 19 refactors is a sizeable diff right before release. Order them by file so each lands as a reviewable commit.

### T2. Close the restriction-lift gap (F-003)

- **Why:** the module's header promises a re-read on `ENCOUNTER_END` and `CHALLENGE_MODE_COMPLETED`, and a test is named for it, but nothing is wired.
- **Approach:** Restrictions owns the lift events and refreshes on them, plus once more a moment later, because the client's flag can lag its own event, as the module's header already says. The new event goes into `NS.FEATURE_EVENTS`, so the stand-down unregisters it (slash-commands-§7). Its timer is canceled in Restrictions' `STAND_DOWN` (slash-commands-§7: "every timer, ticker and OnUpdate canceled").
- **Alternatives:**
  - (a) Correct the comment and delete nothing. Rejected: it leaves the padlock symptom.
  - (b) Re-read restrictions inside Situation's coalesced refresh. Rejected: it couples the two edges, and Situation would then announce restriction changes.
  - (c) A polling ticker while locked. Rejected: it is a timer that runs in combat for a cosmetic fix.

### T3. Pay for the look only when it changes (F-001, F-006, F-011)

- **Why:** a rebuild repaints the button shine and rewrites every secure attribute even when nothing changed.
- **Approach:** an identity guard on the shine paint, the same pattern as `btn.qcLookSig`. The release path stops disarming buttons that are about to be re-armed with the same line. The `Children` comparator gets precomputed sort keys.
- **Trade-off:** each guard is a cache that must be invalidated on release. The risk notes cover it.

### T4. Hygiene (F-005, F-007, F-008, F-009)

- **Approach:** prune the lint whitelist, make the `general` kind check channel 1's name, wire or delete the dead helpers, and split the suite at the cap.

### T5. Cross-addon convergence (F-010)

- **Approach:** re-vendor LibKa0s v1.78.0 into QuickComms as its own commit, through `/dev-copilot:wow-revendor-libka0s`. That is a whole-folder copy, not an edit.

## Upstream change-set

None. No `[upstream]` finding was raised, and F-010 needs no library change.

## LLD — change-set per finding

### C-01 — Guard the pad button shine paint; re-measure; record the remainder (F-001)

- **Files:** `modules/Pad_Render.lua` (`R.ApplyButtonLook`), `tests/perf.lua` (`BYTE_CEILING` plus a dated "Raised …" note, only for what remains), `docs/performance.md:57-58`.
- **Before** (`modules/Pad_Render.lua:489-490`):
  ```lua
  Glow.Button(btn, sizedGlow(cl, w, h))
  NS.Shine.Apply(btn, cl.shine, w, h)
  ```
- **After (sketch):** compare identity and size; no string is built, so the guard itself allocates nothing.
  ```lua
  if btn.qcShineLook ~= cl.shine or btn.qcShineW ~= w or btn.qcShineH ~= h then
      btn.qcShineLook, btn.qcShineW, btn.qcShineH = cl.shine, w, h
      NS.Shine.Apply(btn, cl.shine, w, h)
  end
  ```
- **Risks:**
  - `cl.shine` must be the same table while settings hold. It is built inside `R.ButtonLook(button, inst.clook)`, which reuses the previous look while its signature holds; confirm the shine sub-table is reused too, not rebuilt.
  - The pool's release path must clear `qcShineLook` if release ever hides the shine layers. Today `releaseButton` (`modules/Pad.lua:179-182`) only disarms.
  - The dial slices paint shine through `modules/Dial_Slices.lua`, not this path. The dial rise (`239b665..71c85f2`) needs its own bisect over the commits in that range (`66feba4` … `064f4ea`) before a fix is chosen.
- **Measurement that shows it worked:** `ka0s-bounded lua5.1 tests/perf.lua`. `padRebuild12` should fall from 87026.8 toward the 66290.8 measured with the shine off, in the same run on the same machine. Whatever stays above 70656 is raised with a note naming the commit and the cause, per `tests/perf.lua:27-28`, and `docs/performance.md` moves in the same change.
- **Standards:** performance-§9 (deterministic assertions only; the runner stays outside the green gate), automated-tests-§3 (no commit gate).

### C-02 — Retire the 19 complexity warnings (F-002)

- **Files and functions:** as listed in F-002. Suggested shapes (performance-§11, in its order of preference):
  - **Data table plus one loop, built once at file load** (the `and`/`or` tax): `P.EditPresetKey` (`modules/Preview.lua`, a module-level ordered table of `{ test, key }` rows), `R.SkinFor`, `R.Look`, `PL.Compute`, `oldDungeonWhen`, `Lib.ValidWhenValue`, `W.Summary`, `V.PreviewLines`.
  - **Module-level dispatch:** `expandOne` (`modules/Tokens.lua`, a module-level resolver list replacing the `if` ladder), `W.ResolveValue`.
  - **Named helpers:** `Lib.SeedFromOverlay` (convert refs, seed sets and settle surfaces as three named steps), `S.ApplyAll` (`planFor(id, kind)`, `announceOrder`, `logShows`), `Pad.Apply`, `Dial.Apply`, `DS.Load`, `R.PointerUpdate`, `G.ReusableCallouts`.
  - The two non-shipping entries (`tests/test_dial_shine.lua` anonymous, `tools/render-shine-preview.lua` `encode`) are inside the measured shadow and count toward the gate. Split them the same way.
- **Prerequisite:** a characterization test, run green against the unrefactored function, for any warned function no case covers (testing-§13).
- **Risks:**
  - `S.ApplyAll`, `Pad.Apply`, `Dial.Apply` and `DS.Load` sit on the secure path. Pin the attribute writes and the `SendEngine` call order before moving anything.
  - Do not fix F-003, F-006 or anything else inside a refactor commit (performance-§11, "MUST NOT change behavior").
  - Do not move a defaults table inside a hot function (anti-patterns #43).
- **Test movement:** characterization cases move the pass count. `docs/test-cases.md` (regenerated by `--list`) and the README badge move in the same commit (testing-§5). `tests/test_page_groups.lua` is at 1500 lines, so any new Groups-page case needs C-09 first.
- **Watch-list note for the release:** every entry above is expected to leave the watch list. The next release run's regeneration confirms this; nothing is regenerated here.

### C-03 — Re-read restrictions when an encounter or key ends (F-003)

- **Files:** `modules/Restrictions.lua`, `modules/Situation.lua` (forwarding only), `tests/test_restrictions.lua` (new cases), `tests/test_disabled.lua` (`PINNED` gains `ENCOUNTER_END`; the expected registration set moves with the behavior, which is not a weakened test).
- **After (sketch):**
  ```lua
  -- modules/Restrictions.lua
  local LIFT_DELAY = 0.5   -- the client's flag can lag its own event (see the header)
  function R.RefreshAfterLift(cause)
      R.Refresh(cause)
      if State.restrictionLiftTimer then return end
      State.restrictionLiftTimer = NS.addon:ScheduleTimer(function()
          State.restrictionLiftTimer = nil
          R.Refresh(cause .. "+late")
      end, LIFT_DELAY)
  end
  NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "ENCOUNTER_END", "OnRestrictionLiftEvent" }
  function NS.addon.OnRestrictionLiftEvent(_, event) R.RefreshAfterLift(event) end
  -- STAND_DOWN: cancel State.restrictionLiftTimer with the rest.
  ```
  ```lua
  -- modules/Situation.lua, OnSituationEvent: CHALLENGE_MODE_COMPLETED is this row's (one handler per
  -- event per object), so it forwards the lift to Restrictions rather than registering it twice.
  if event == "CHALLENGE_MODE_COMPLETED" then NS.Restrictions.RefreshAfterLift(event) end
  ```
- **Header fix:** `modules/Restrictions.lua:23-25` names this function and these two edges, not "phase 2's SendEngine".
- **New cases** (each with a `-- red under:` line, testing-§12):
  - "restrictions: ENCOUNTER_END re-reads a lockdown the client cleared after the last event". Fire the event through the mock with `m.chatLockdown = false` after a locked refresh, and assert `RESTRICTION_CHANGED` was heard. Red under: drop the `ENCOUNTER_END` row.
  - "restrictions: CHALLENGE_MODE_COMPLETED re-reads, through Situation's row". Red under: drop the forward.
  - "restrictions: the late re-read is canceled by the stand-down". Red under: drop the cancel.
- **Risks:** `ENCOUNTER_END` fires for every boss in the session, including a wipe. The refresh is a read plus a signature compare and announces only on change, so the cost is negligible. Confirm the event name on 12.0.5 in client (DropWatcher registers it).
- **Standards:** slash-commands-§7 (event in `FEATURE_EVENTS`, timer canceled on stand-down); events-frames-taint-§1 (registration through `NS.SafeRegisterEvent`, which `registerFeatureEvents` already does).

### C-04 — Sweep the docs (F-004)

- **Files:** `docs/ARCHITECTURE.md:281,377`; `docs/module-map.md:57,127`; `docs/schema.md:36-39,47`; `docs/scope.md:33`.
- **Edits:**
  - Drop "or share string" and "the Share window".
  - Replace the `PinNodes` clause with today's A–Z placement, matching `docs/ARCHITECTURE.md:308`.
  - Drop "they travel in a share string".
  - `docs/scope.md:33`: say the release gate is evaluated at the release run, instead of asserting it is green.
- **Note:** the `## Documented deviations` row at `:377` is edited only to remove the retired frame. Its ruling is unchanged, so this is not a new deviation (documentation-§3 keeps the register as the single home).

### C-05 — Prune the lint whitelist (F-005)

- **File:** `.luacheckrc:58-60`. Keep `"GetBindingKey"`; remove `"GetBindingAction"`, `"SetBinding"`, `"SaveBindings"` and `"GetCurrentBindingSet"`. Reword the comment to "read only: `Dial.KeyOf` through `Compat.BindingKey`".
- **Verify:** `ka0s-bounded luacheck .` stays 0/0. If it does not, the hit is exactly the finding to look at.
- **Standards:** lint (no blanket suppressions); options-ui-§20 and anti-pattern #98 (the library writes bindings, the addon does not).

### C-06 — Keep an unchanged button armed across a rebuild (F-006)

- **Files:** `modules/Pad.lua` (`releaseButton`, `arm`), `modules/Dial.lua` (`releaseWedge`), `modules/SendEngine.lua` (comment).
- **Approach:** release parks a button without disarming it. Only the buttons the pool does **not** re-acquire this rebuild are disarmed, after `place()` finishes: the pool's free list once the active set is rebuilt. `SE.Arm`'s fast path then fires for an unchanged line.
- **Risk:** this sits on the secure path. A parked button that stays armed but hidden must never be clickable: the pool hides it, and a hidden secure button takes no click. Pin it with a case saying every button outside the active set has no `type` after `Pad.Apply`.
- **Measurement:** `padRebuild12` and `dialOpenClose` bytes and notes. Count `SetAttribute` calls per rebuild in a new perf scenario, or as an assertion in `tests/test_sendengine.lua`.
- Lower priority than C-01 to C-03; deferrable past v0.1.0.

### C-07 — `general` names channel 1 only when it is General (F-007)

- **File:** `core/Compat.lua` `Compat.GeneralJoined`. Read `local id, name = GetChannelName(1)`, and treat channel 1 as General only when `name` is plain and matches the client's General prefix. The compare must be locale-safe: use the channel's zone-channel identity where the client exposes it, otherwise fall back to today's behavior. Then document in Known Limitations what happens when it does not match.
- **Alternative:** keep the behavior and rename the kind in the UI to "Channel 1". That is a locale-key change (`locales/enUS.lua`) and the safer pre-release choice if the identity check proves unreliable in client.
- **Standards:** localization-§4 (match ids and tokens, never a localized name). This is why the name-match option must use an id, not the English "General".

### C-08 — Wire or delete the dead helpers (F-008)

- `Tok.UsesGroupToken`: either wire it into `Channels.LockState` / the slot tooltip ("{g1}-{g8} expand only in a raid") or delete it with its three asserts in `tests/test_tokens.lua:24-26`. Deleting moves the count (testing-§5).
- `R.CanSendChat`, `R.ActiveReason`: the shipped code reads `R.Snapshot`/`R.ActiveSet`. Delete them, or keep them and document them as the module's public readers. They are not stubs, so the dead-code rule applies.
- `Lib.DeleteCallout`, `W.HasAll`: delete unless a page is about to call them.

### C-09 — Split `tests/test_page_groups.lua` before it takes a case (F-009)

- Split along its own groupings, for example the When tab cases into `tests/test_page_groups_when.lua`, and add the new name to the `suites` list in `tests/run.lua` (`:141` onward). `Kit.assertSuiteInventory` fails the run both ways: a listed name with no file, and a `test_*.lua` on disk with no name.
- The case count is unchanged. The inventory's per-file headings move, so regenerate `docs/test-cases.md` in the same commit.

### C-10 — Precompute `Children`' sort keys (F-011)

- **File:** `modules/Library.lua:80-94`. Build a `keys[gid] = name:lower()` table once per call, then sort on it.
- **Measurement:** `padRebuild12` should drop by about the +136 B/iter it gained today.

### C-11 — Re-vendor LibKa0s v1.78.0 (F-010)

- Run `/dev-copilot:wow-revendor-libka0s` to v1.78.0 as its own commit: a whole-folder copy of `libs/LibKa0s/` and `tests/_kit/`, then update the `CLAUDE.md` provenance line and `DEPENDENCIES.md`.
- Never a partial copy or an edit in place (library-stack-§5, testing-§11).
- Do it after the T1/T2 work lands and before the release run, so the release measures the payload players will actually run alongside LootHistory.

## Standards conformance (per change)

| Change | New deviation? | Rule that shaped it |
|---|---|---|
| C-01 | no | performance-§9; automated-tests-§3 (the rejected commit gate) |
| C-02 | no | performance-§11 (shapes and MUST NOTs); testing-§13; anti-patterns #43, #52 |
| C-03 | no | slash-commands-§7 (FEATURE_EVENTS, timer cancel); events-frames-taint-§1 |
| C-04 | no | documentation-§3 (the deviation register edited, not re-ruled) |
| C-05 | no | lint; options-ui-§20 / anti-pattern #98 |
| C-06 | no | events-frames-taint-§2 (out-of-combat attribute writes only, unchanged) |
| C-07 | no | localization-§4 (rejected: matching the English name) |
| C-08 | no | testing-§5 (the count moves in the same change) |
| C-09 | no | layout-§1 (the cap); testing-§5 |
| C-10 | no | — |
| C-11 | no | library-stack-§5; testing-§11 |
