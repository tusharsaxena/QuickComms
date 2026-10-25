# 04 — Technical design: closing the 2026-10-25 deviations

Keyed to `02_DEVIATIONS.md`. Nothing here needs a library change, a migration or a schema-version
bump; every change is a label, a test, a doc, a config line or two `Set…` calls. Grouped by the
surface each change touches, so one commit can carry each group.

## A. Docs (QC-08, QC-22, QC-23, QC-24, QC-25, QC-27)

**One sync pass, hub first.** The hub is the root cause of four of these: it is a 1,047-line document
(wrapped) dressed as a 387-line one, and a section that holds a full body is a section that drifts
(QC-24's `locked` default and Share remnants both sit in hub bodies that should have been summaries).

1. **Spill (QC-22).** Create `docs/taint.md` from the Taint Notes paragraph (`ARCHITECTURE.md:237`),
   reflowed into sub-headings (send buttons, the dial's secure header and catchers, key bindings,
   modal windows and confirms, glows); create `docs/known-limitations.md` from `:267-315`, grouped
   (send engine, dial, previews, battleground data, editors, art). Leave each hub section as a
   three-to-five-line summary plus exactly one link. Cut Module Map to the kinds summary and the
   link (the 39-row table already exists, finer, in `module-map.md`); cut Settings Schema to the seam,
   the registry writer, the load pass and one link to `schema.md`. Add `taint.md` and
   `known-limitations.md` rows to `### Conditional` as *Present* with their trigger.
2. **Named state, one home (QC-23).** With Settings Schema spilled, `schema.md` becomes the only home.
   Add a *Named non-setting state* section listing, per key: `previewWindow` — owner
   `modules/PreviewWindow.lua`, writer the drag-stop handler (`remember`); `padsHidden` — owner
   `settings/SlashVerbs.lua`, writer `V.TogglePads` (reached by `/qc toggle`, the launcher's Show
   window and the Toggle Comms Pads key); `global.minimap.minimapPos` — LibDBIcon's own write. Delete
   the half-copies from the hub.
3. **Frame layering pointer (QC-27).** Replace `## Frame layering`'s body with one line pointing at
   `core/Constants.lua` `NS.Constants.LAYERS`, and the test pinning it (`tests/test_layers.lua`).
   Keep the heading or fold the line into the Taint Notes summary; either is fine, the copy is not.
4. **Counts (QC-08).** Re-run `cat core/Compat*.lua | grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.'`
   (31 today), write it in `compat-layer.md` and the Conditional row, add `UnitDisplayName` to the
   table. Prefer prose that names the command and drops the number from the hub row ("the documented
   grep answers N") so the next shim moves one figure, not two.
5. **Drift (QC-24).** Hub Master-controls defaults read `locked` `false`; `schema.md:21` and
   `settings-panel.md:26,33` say *Master opacity*; drop "share string" (hub, `schema.md` ×5) and "the
   Share … windows" (`module-map.md:127`); check `tests/test_layers.lua` still has no Share case (it has
   none).
6. **Register hygiene (QC-25).** In row QC-R6 delete "the Share window", replace "QC-06, 2026-10-18"
   with the SHAs `69719ca`/`0901b8c` (2026-10-23), and add the dial screen catcher (QC-30) and, if the
   QC-21 decision is to keep the modals non-toplevel, the modals. Going forward, run-plan items take a
   prefix that cannot collide with the audit's `QC-` (for example `QR-` or the plan's own `QF-`), and
   test names cite audits only as `[audit QC-nn]`.

Risk: none at runtime. Order: 1 → 2 (the spill decides where names live) → 3-6 in any order.

## B. Settings labels and gray-outs (QC-18, QC-19)

- **QC-19.** Change the three locale keys and values to `Delete group…`, `Delete pad…`, `Delete dial…`
  (U+2026) and `Duplicate` to `Duplicate group`; update `settings/Groups.lua:373,377`,
  `settings/Pads.lua:170`, `settings/Dials.lua:189`; update any test asserting the old label
  (grep `tests/` for the strings) and `docs/settings-panel.md`. Tooltips already say "Asks first", which
  can stay. No migration (a label is not a stored path; options-ui-§21).
- **QC-18.** An owner decision, two exits:
  - *Conform:* remove the `disabledIf` assignment from the color rows only — in `shineRows` set
    `disabledIf` on the non-color rows and skip it for `ColorPair` output; drop the loops at
    `SchemaMembers.lua:631-634`, `:693-696`, `:706-709`; for the two font blocks, keep `disabledIf` on
    every row except the `fontColor` / `useClassColorFont` pair (filter on `row.type == "color"` and its
    companion). Add each swatch's tooltip note per options-ui-§17 ("not read while … is off" is the
    feature-switch variant). Pin with a schema test: no row of `type == "color"` (or its companion)
    carries `disabledIf`.
  - *Decline pending upstream:* close issue #11 as `state:will-not-do` (or keep it `state:triaged`)
    **and** add a register row `options-ui-§17` | the eleven pairs gate on their feature switch | the
    swatch is genuinely unread then; WowAddonStandards#13 proposes permitting exactly this | 2026-10-xx |
    *WowAddonStandards#13 ruled*. An issue without the row is not ratified.

## C. Slash stub (QC-17)

`settings/Slash.lua:277`: `return SLASH .. " " .. entry[1] .. "  " .. entry[2]`. Add a degraded case in
`tests/test_slash.lua` asserting a help row carries no `—` and no `|cFF` (red under: restore the em
dash). The landing rows in the stub share `helpRow`, so they change too, which is correct (plain).

## D. Disabled suite (QC-03)

In `tests/test_disabled.lua` step 6:

```lua
for _, r in ipairs(snap.raw) do
    if r.kind ~= "message" then
        -- red under: a kit whose __fireUnconditional returns 0 (the loop proves nothing then)
        assertTrue(m.__fireUnconditional(NS.addon, r.event) >= 1, r.event .. " reached a handler")
    end
end
```

then the existing zero-writes / zero-prints / zero-shows asserts (a handler that early-returns while
disabled writes nothing, which is the point). Messages: deliver each through the receiver directly or
assert the tracked bus answers zero live receivers; the live `SendMessage` stays as the "nothing
listens" half. Step 8: after `disable(NS)`, bind a key to `CLICK QuickCommsTogglePads:LeftButton`,
`m.__pressKey`, assert zero `__svWrites`, unchanged `padsHidden`, unchanged shown frames and exactly one
line matching `NS.SlashCommands:DisabledLine()`. Risk: an event whose handler is not reachable by method
name on kit 42 — the kit's own note says kit 39+ reaches method-name handlers, so none is expected; if
one appears, call the handler the addon registered, never accept a zero.

## E. Packaging and lint (QC-20, QC-29)

- `.pkgmeta`: add `  - media/logos/*.jpg   # a .jpg render of the logo, for the project page; same reason`
  beside the `.png` line.
- `.luacheckrc:58-60`: keep `GetBindingKey` (read by `Compat.BindingKey`); drop `GetBindingAction`,
  `SetBinding`, `SaveBindings`, `GetCurrentBindingSet`; reword the comment to "core/Compat.lua reads a
  dial's key (WoW's own binding) through GetBindingKey; the Keybindings tab's writes are the
  library's". `luacheck .` must stay 0/0, which also proves nothing used them.

## F. TOC labels (QC-26)

Replace the six `# Conventional: data` labels with one LOAD-BEARING (b) comment above
`defaults\BuiltIns_MythicPlus.lua` naming the table and order, and a specific note above
`defaults\BuiltIns_Group.lua`:

```
# LOAD-BEARING (b): each BuiltIns_* file appends its sets to NS.BuiltIns.order, the order every new
# pad and dial is seeded in (Library seededTops); tests/test_builtins.lua pins it. Keep M+, raid,
# arena, world, then the battleground sets.
…
# LOAD-BEARING (b): In Group last, after the generic battleground set, so a content set stays the
# first active group on the pad and the dial (D9).
```

toc-file-§5 lets one comment cover a run of lines that share one constraint.

## G. Frame layering (QC-21, QC-30)

`settings/ModalWindow.lua` `MW.Build`, after `window:SetFrameStrata`: `window:SetToplevel(true)`,
`window:SetClampedToScreen(true)`. Toplevel raises the window among `FULLSCREEN` peers on click; the
preview window is the only other `FULLSCREEN` frame and is deliberately not toplevel, so a modal
clicked over it stays above it, which is the intended order. The catcher is the window's parent, so a
raise of the window cannot lift it over its own catcher's dim incorrectly — verify in `test_layers`
with the kit's `mock_layers.lua` (toplevel recorded, level bands unchanged). If the owner prefers to
keep them non-toplevel, record it in row QC-R6 instead. QC-30 needs no code: name the catcher in row
QC-R6 and raise the scope question upstream (secure T3 popups versus the T8 no-catcher rule).

## H. Gate speed and the release record (QC-28, QC-14)

- **QC-28.** testing-§14 first: measure (`lua tests/run.lua` under `time`, plus the kit's per-suite
  timing if it prints one) and name what dominates (loader cache is in kit 42 already; suspect the
  per-case `T.enableAddon()` boots and the secure mock). Then `Kit.run{ …, jobs = "auto" }` in
  `tests/run.lua`, after confirming a sharded run reports the same 1157/1/1158 and exit code. Record the
  figure in the next `RESULTS.md` run.
- **QC-14.** At release, not now: `bash tests/_kit/run-automated-tests.sh --release 0.1.0`. The release
  gate needs zero functions above CCN 15; the 19 split into dense defaulting (`R.Look`, `R.SkinFor`,
  `P.EditPresetKey`, `Lib.ValidWhenValue`, `oldDungeonWhen`) — candidates for a module-level defaults
  table read (performance-§11, never a per-call table, anti-pattern #43; and `== nil` where a stored
  `false` is a choice, anti-pattern #54) — and real control flow (`Lib.SeedFromOverlay`,
  `S.ApplyAll`, `G.ReusableCallouts`, `Pad.Apply`, `Dial.Apply`, `DS.Load`), which want named helpers
  with characterization tests first (testing-§13). The test function and `tools/render-shine-preview.lua`
  `encode` count too. Give each band file a `Disposition` in the generated watch list.

## Ordering constraints

- A before the release; A.1 before A.2.
- B, C, D, E, F, G are independent of each other and of A.
- H.QC-14 last: it measures the tree everything else changed.
