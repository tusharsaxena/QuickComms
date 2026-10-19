# Settings panel scout report: Look headings, Preview as, Callouts rows

## (1) Section headers drawn twice on the pad Look tab

**Root cause (confirmed by reading the code).** `settings/Pads.lua:225-241` `renderLook` draws every heading twice:

```lua
for _, subgroup in ipairs(PD.LOOK_GROUPS) do
    local mine = PD.LookRows(scalar, subgroup)
    if #mine > 0 then
        h.Section(ctx, subgroup)                                   -- heading #1 (host)
        h.RenderRows(ctx, mine, nil, nil, { noHeadings = true })   -- heading #2 (library)
```

- The composed rows carry `subgroup`. `settings/SchemaMembers.lua:382-401` `lookSpec(subgroup)` feeds `O.FontGroup`, `O.BorderGroup` and `O.ColorPair`, and `libs/LibKa0s/OptionsCompose.lua:168,194` stamps `row.subgroup` on each row.
- `libs/LibKa0s/OptionsWidgets.lua:232-237` `startSubgroup` emits `O.Section(ctx, row.subgroup)` whenever `row.subgroup ~= ctx.lastSubgroup`. Its comment at :223 says it is "deliberately NOT suppressed by `noHeadings`". `noHeadings` suppresses only the group heading (:210).
- `O.Section` (:552) does not set `ctx.lastSubgroup`, so the host's own `h.Section` doesn't stop the library from drawing a second one. Pads.lua has done this since commit fcde0ee. The library always drew subgroups; it is not a regression from a re-vendor.

**Fix.** Replace the loop with one call, `h.RenderRows(ctx, Ed.Scalar(rows), nil, nil, { noHeadings = true })`. The rows with no subgroup (`pad.look.visibility`, `fade`, `fadeAlpha`, SchemaMembers.lua:278-288) come before the composed rows in schema order (`lookRows()` is appended at :403), so the order holds. `PD.LOOK_GROUPS` and `PD.LookRows` (Pads.lua:214-223) then become dead code. Nothing outside Pads.lua uses them (only `docs/superpowers` history and a frozen complexity bundle mention them), so they can be deleted. The header comment at Pads.lua:9-12 needs updating too.

This is required by the standard. options-ui-§7 says "a subsection is still never drawn by a builder" (the heading comes from the row's `subgroup`). Using the one `Heading` widget is anti-pattern #71.

**The Layout tab and the dial editor do not have the bug.** No other schema row carries `subgroup`; grep finds it only in `lookSpec`.
- Pads `renderLayout` (Pads.lua:206) and Dials `renderWheel` (Dials.lua:322) each draw one `h.Section(ctx, L["Position"])` above controls that are not schema rows.
- The Dials tabs (Dials.lua:400-407: General, Groups, Wheel, Binding, Preview) have no Look tab and no subgrouped rows.
- `Ed.TableRows` (Editors.lua:621), `settings/Share.lua:99` and `CalloutPopup.lua:385` also call `h.Section`, but none of them is followed by subgrouped schema rows.

**Test.** `tests/test_page_pads.lua:203-214` only checks that each heading exists: `assertTrue(P.find(w, "Heading", heading) ~= nil)`. That is why the duplicate went unnoticed. Tighten it to `assertEqual(#P.all(w, "Heading", heading), 1, heading)`. `P.all` is at `tests/page_helpers.lua:93`. The check fails on today's code.

## (2) Moving Preview as to General > Master controls

**Where it is now.** One schema row, `state.previewAs`, at `settings/SchemaRows.lua:65-77`. It has `page = "groups"`, `group = L["General"]`, `sessionOnly`, `values = NS.Preview.Choices`, and `validate = NS.Preview.FindPreset`. It goes through `StampClosureRows`, then `AddRows`, appended after Behavior. Its storage closures are `SESSION["state.previewAs"]` at `settings/Schema.lua:52-56`. Three host pages draw it by hand at the top of their General tab:
- `settings/Pads.lua:131` in `renderGeneral`
- `settings/Dials.lua:252` in `renderGeneral`
- `settings/Groups.lua:314` in `renderGeneral`. That page also lists it in `UNDRAWN` (:308), because the row's own page is "groups" and `Ed.Scalar(rows)` would otherwise draw it a second time.

**Where Master controls is built.** `settings/Panel.lua:44-63` calls `Helpers.MasterControls{...}`, then `AddRows(MASTER_ROWS, 1)`. The tab is drawn by `RenderTabbedSchema(c, "general", AFTER_GROUP)` (:79), where `AFTER_GROUP[MASTER_GROUP] = MASTER_TAIL` draws the Reset position / Reset all button pair.

**Option A (recommended): use the composer's `extra` field.** `MasterControls` calls `appendExtra(ms, rows)` (OptionsCompose.lua:186-199, called at ~:549). That puts extras after the canonical rows and before the button pair, and stamps them with the page, group and order. The library docs (`LibKa0s/docs/api/Options/version-29…-docs.md:2090`) describe `extra` as "Rows appended after the canonical block". Steps:
- Move the row spec from SchemaRows.lua into `Panel.lua`'s `MasterControls{ extra = { … } }`.
- Panel.lua's existing loop (:58-60) sets `row.onChange = REACTIONS[path]`, which is nil here, as it is today. `StampClosureRows(MASTER_ROWS)` (:61) binds the SESSION get/set.
- After Test mode the line is already full (two rows), so Preview as starts its own line, then the buttons follow.
- Side effect: `tests/test_schema.lua:33-42` asserts `paths[9] == "behavior.soloFallback"`. That becomes `state.previewAs`, so update the test and its comment.

**Option B: keep the row in SchemaRows.lua.** Set `page = "general"` and `group = NS.addon.Settings.Helpers.MASTER_GROUP`. The tab partition is by group, so the row still lands in Master controls after the canonical rows, and test_schema stays green. But the row is hand-written, which sits less comfortably with the "composed" spirit of §15.

**Standard constraint (needs an explicit owner call).** options-ui-§15 says "The set is canonical, not a menu… MUST NOT reorder them, rename them, or split them across tabs". It neither allows nor forbids an extra row after the set. The library allows extras "after the mandated rows, never interleaved", which matches the §16 wording for BorderGroup. Per CLAUDE.md, the planner should raise this as a possible deviation and let the owner decide between:
- recording it in `docs/ARCHITECTURE.md` → `## Documented deviations`, or
- treating it as the standard's sanctioned extension point.

Note that options-ui-§14 puts page-wide controls in the band or on the `General` tab. The current per-page copies were justified that way (SchemaRows.lua:65-67 comment).

**What else changes with the move:**
- Delete the three `h.RenderRows(ctx, { Ed.Row("state.previewAs") }…)` calls.
- Drop `state.previewAs` from Groups `UNDRAWN` (:308) and update its comment (:305-307).
- Update the header comments at Groups.lua:8, Pads.lua:6 and Dials.lua:6.
- **Groups Defaults no longer turns Preview off.** `G.RestoreDefaults` → `H().RestoreDefaults("groups")` restores the page's rows, and the row will no longer be on that page. So the tooltip at Groups.lua:531 needs a new locale key, and `locales/enUS.lua:602` (old key) must be removed. The global Reset all still sweeps session rows (options-ui-§12, "MUST be restored row by row").
- Refresh works without new code. `Preview.announce` calls `H.RefreshAll()` (modules/Preview.lua:25), so the General page's dropdown follows `/qc preview` and the combat or close stop.
- Degraded load (no LibKa0s): the composer is hollow and returns `{}`, so the row is absent. `tests/test_setup.lua:270-290` (only member rows on a degraded load) stays green.

**Tests to change or add:**
- Remove the "Preview as" dropdown asserts at `test_page_pads.lua:153`, `test_page_dials.lua:52-55` and `test_page_groups.lua:82-87`, and assert the dropdown is absent instead.
- Add a General-page check that the Master controls rows hold `state.previewAs` after `state.testMode`, through `Settings.RowsForPage("general")` or the schema order. There is no `P.redraw("general")`: `Editors.redraw` only knows the Ed pages, and the General page renders through `RenderTabbedSchema`.
- These need no change: `test_slash.lua:188-199` (FindRow desc), `test_preview.lua:217-223` (seam Get/Set), `test_diagnostics.lua:84-86`.
- Docs to update: `docs/settings-panel.md:16-30` (Master controls table) and :50, :372, :395, :405; `docs/ARCHITECTURE.md:113,125`.

## (3) Callouts tab rows

**Row builder.**
- `settings/Groups.lua:208-212` `calloutLabel(cid)` returns `"%s  |cff808080%s|r"` filled with `c.name` and `c.channel`. The channel shown is the raw kind id ("smartGroup", "raidWarning"), not a readable name.
- `renderCallouts` (:415-435) builds `{ id, label, icon, iconColor, edit, remove }` and calls `Ed.ReorderRows`.
- `Ed.ReorderRows` (`settings/Editors.lua:491-538`) lays a row out in Table columns (`Ed.RowColumns`, :459): handle gutter, one fill Label, then the glyph cells. The Label draws `e.icon` through `SetImage` at `ROW_ICON` = 18px, only when the callout has an icon, tinted with `Ed.Tint` → `NS.Library.IconTint(icon, color)` (:481-484; Library.lua:306). An OnRelease handler sets the tint back to white. `ghostText = b.entry.label` (:536) is the drag copy's text.

**Icon.** A callout with no icon shows no image today. For "[icon]" on every row, fall back to `Ed.NO_ICON` (Editors.lua:226), the same question mark the pads use (Pad_Render.lua:18,161).

**Gold.** `NS.C.GOLD` (#FFD100, core/Constants.lua:16) or `HEADER_COLOR` {1, 0.82, 0} (Editors.lua:559). As an escape: `|cffffd100`.

**Channel color.**
- `NS.Compat.ChatColor(chatType)` (core/Compat.lua:302-311) reads `ChatTypeInfo`.
- The fallback is `NS.C.CHAT_COLORS` (Constants.lua:20-23).
- The kind → chat type map is `NS.Channels.ChatType(concrete)` (Channels.lua:23).
- `Pad_Render.lua:83-88` has a local `tagColor` doing the lookup plus fallback. It is not exported; hoisting it, e.g. to `NS.PadRender.TagColor` or a Channels helper, avoids a copy.
- **Open decision:** the smart kinds have no fixed chat type. Either resolve them with `NS.Channels.Resolve(kind, Ed.Snapshot(), NS.Setting("behavior.soloFallback"))` (Channels.lua:43-54; nil when solo), or pick a fixed color per kind.
- Readable channel names: `CHANNEL_LABEL` (SchemaMembers.lua:125-130) is local, but the same text is on `Ed.Row("callout.channel").values`. The labels are long ("Smart group (instance, raid or party)"), so shorter ones may need new locale keys.

**Text preview.**
- Truncate `c.text` to N UTF-8 characters. A `firstChars` helper exists but is local to `modules/Library.lua:451-459` (`chars` is at :246); export it, or reuse the count in `CalloutPopup.lua:100`.
- Escape `|` for display with `NS.Share.Literal` (modules/Share.lua:82-88), or user text breaks the color codes.
- Muted white: no constant exists. The other muted colors in use are `|cff808080` (the current grey) and IconBrowser's `MARK_GRAY`.
- Row height is fixed at `Ed.ROW_H` = 30 and the Label wraps, so the truncation (or a one-line, non-wrapping label) is what keeps rows a uniform height. options-ui-§18 requires uniform rows because the drop position is arithmetic on the row stride.

**Building the row.** The simplest route is one Label with color escapes, keeping `ReorderRows` unchanged. Pass a plain `ghostText` if the colors look wrong in the drag copy; that means adding an optional `entry.ghost` read at Editors.lua:536. Separate columns would mean changing `Ed.RowColumns` and every caller, including the Pads and Dials group lists. options-ui-§18 leaves the row's contents to the addon ("entirely the consumer's"); the handle, box and fill stay the library's.

**Existing tests:**
- `test_page_groups.lua:900-913` finds the row Label by `label.image[1] == star` and asserts `vertexColor` "0,1,0".
- `:916-931` checks the white reset on release.
- `:101-124` and `:432-447` cover the reorder spy (`lists[#lists].rows`) and `P.glyph(w, "remove", 1)`.
- Nothing asserts the row's text, so new asserts are needed for: gold name escape, channel color escape, truncation at N, `|` escaped, and the fallback icon when there is none.