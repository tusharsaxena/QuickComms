# Scout report: icon styling for Comms Pad chips and Comms Dial wedges

No QC bug was found in this area. QC's chips and wedges currently have no icon styling of any kind. This report covers the reference build in DropWatcher, QC's current code, and a proposed setting set.

**Possible ambiguity in the user's request.** The user wrote: "add [the new icons] to LibKa0s directly … vendor the new LibKa0s version to this addon only." That most likely means the icon-style and glow code goes into LibKa0s as a new major. It could instead mean new glyph *images* for the `LibKa0s-Media-1.0` `ICONS` catalog (`LibKa0s/Media.lua:92`). The planner should confirm which.

## 1. DropWatcher reference (what to port)

### `modules/IconStyle.lua` (156 lines)
- **Settings**, from `defaults/Profile.lua:179-187`, all under `icons.`:
  - `zoom` = 0.1, range 0..0.25, step 0.01. Hand-written slider row at `settings/SchemaRows.lua:513-517`.
  - Border fields: `borderShow` = true, `borderStyle` = "Solid" (an LSM border name), `borderSize` = 2 (checked 1..16), `borderColor` = {0,0,0,1}, `useClassColorBorder` = false.
  - `borderQuality` = false, an extra row.
  - The border rows are composed with `Helpers.BorderGroup{show=true, prefix="icons.", classColor={source="player"}, extra={borderQuality}}` in `settings/ComposedRows.lua:33-49`. Checks and dimming come from `DECORATE` (`:52-61`). Style, size and quality are dimmed while the border is off; the color pair is never dimmed (options-ui-§17, anti-pattern #74).
- **How it applies:**
  - Zoom is `b.art:SetTexCoord(z,1-z,z,1-z)` (`:139`).
  - The border is a `BackdropTemplate` child frame, created on first use, with `SetAllPoints(b)` (`paintBorder`, `:111-131`). It uses `SetBackdrop{edgeFile, edgeSize}` plus `SetBackdropBorderColor`. A child sits one frame level above the button, so it draws over the icon art.
  - At load it registers "Solid" → `Interface\Buttons\WHITE8X8` with LSM (`:55-58`). An unknown style falls back to `UI-Tooltip-Border`.
  - Colors go through `NS.ResolveColor(color, useClass, nil)`, which uses the player's class and keeps the swatch's alpha.
  - There is no desaturate, no tint and no per-icon alpha.
- **Caching:** a generation counter, a cached `cfg`, and a weak table `made[b]`. `Apply` returns early when `b.iconGen == gen`. `Refresh()` bumps the generation and re-applies every button made so far.
- **Headless record:** decisions are kept on the button as `b.iconZoom` and `b.iconBorder`.

### `modules/Glow.lua` (179 lines)
- Uses `LibStub("LibCustomGlow-1.0", true)` and degrades softly: headless runs still record `b.glowKind`.
- Constants: `KEY = "DropWatcherUpgrade"`, `FRAME_LEVEL = 2` (just above the border).
- `START`/`STOP` tables (`:89-115`) map styles to library calls:
  - `ButtonGlow_Start(b, color, buttonFrequency, lvl)`
  - `ProcGlow_Start(b, {color, startAnim, duration, xOffset, yOffset, key, frameLevel})`
  - `PixelGlow_Start(b, color, lines, freq, length>0 and length or nil, thickness, x, y, border==true, KEY, lvl)`
  - `AutoCastGlow_Start(b, color, particles, freq, scale, x, y, KEY, lvl)`
- `Apply` keeps the effect when kind, generation and width are unchanged; otherwise it stops and restarts (`:146-166`).
- `spendBurst` stops the proc style's opening burst from replaying on every pool re-show (`:122-126`).
- `StopFree(pool, buttonOf)` stops the glow on pooled frames that a repaint left unused.
- The trigger is DW policy (`KindOf`: an upgrade) and is not portable.
- **Rows:** `glow.<main|offSpec>.` (`SchemaRows.lua:398-505`):
  - `enabled` (bool).
  - `type`, a pick from `GLOW_STYLES` (`:148`): button / proc / pixel / autocast.
  - `color`: type color, `hasAlpha`, `classColorSource="player"`.
  - `useClassColor`.
  - The `GLOW_KNOBS` table (`:402-445`):

| Knob | Range / step | Default | Styles |
|---|---|---|---|
| pixelLines | 1-20 | 8 | pixel |
| pixelFrequency | 0.05-2 / 0.05 | 0.1 | pixel |
| pixelLength | 0-20 (0 = auto, `zeroText`) | 0 | pixel |
| pixelThickness | 1-6 | 1 | pixel |
| pixelBorder | bool | true | pixel |
| autocastParticles | 1-12 | 4 | autocast |
| autocastFrequency | 0.05-2 | 0.125 | autocast |
| autocastScale | 0.5-3 / 0.1 | 1 | autocast |
| buttonFrequency | 0.05-2 | 0.25 | button |
| procDuration | 0.25-3 / 0.25 | 1 | proc |
| procStartAnim | bool | true | proc |
| xOffset, yOffset | -10..10 | 0 | pixel, proc, autocast |

  Defaults come from the `glow()` builder (`defaults/Profile.lua:27-39`). A knob is dimmed through `knobOff` while its glow is off or its style doesn't match.
- **Settings page:** Window, with an "Upgrade glow" group (subgroups Effect plus one heading per style) and an "Icons" group (Zoom, Border). DW records a documented deviation for placing the class-color companion *below* its swatch (`SchemaRows.lua:466-473`).
- **Vendoring:**
  - `libs/LibCustomGlow-1.0/` (MIT, minor 24, copied from KickCD; KickCD also vendors it).
  - TOC line `libs\LibCustomGlow-1.0\LibCustomGlow-1.0.xml` before `LibKa0s.xml`, and `LibCustomGlow-1.0` listed in `## OptionalDeps`.
  - Recorded in `DEPENDENCIES.md:16-17`.
  - `.pkgmeta` has no `externals:`.
- **Tests:**
  - `tests/test_glow.lua`: a `fakeLib(m)` registers `LibCustomGlow-1.0` minor 24 on the mock LibStub and records `{name, args…}`. It asserts call order and arguments per style (`:96`), no calls on an unchanged repaint (`:139`), class color (`:164`), the proc burst (`:206`) and pooled rows (`:269`).
  - `tests/test_icon_style.lua`: defaults (`:51`), LSM Solid (`:78`), the no-op repaint (`:91`), class and quality colors, and the glow starting above the border (`:244`).
- **Docs:** feedback-21 appears in `docs/{ARCHITECTURE,schema,settings-panel,module-map,data-flow,smoke-tests,testing,performance}.md`. ARCHITECTURE line 198 notes the glows are plain frames and run in combat.

## 2. Standard constraints

- **library-stack-§7, promotion bars.** The shape needs two or more consumers with the same semantics, no per-consumer flags, and a stable abstraction. DW plus QC (KickCD and AuraMaster borders too) meet the consumer bar for a pure "apply the icon look" and "start or stop a glow from a config table". DW's `KindOf` and its `NS.Setting` reads must stay in each host.
- **library-stack-§7, new major.**
  - One LibStub major per module (e.g. `LibKa0s-IconStyle-1.0`). A `NEEDS_CORE` floor that returns before `NewLibrary`.
  - A `MODULES` minor entry, a line in `LibKa0s.xml`, `tests/majors.lua`, and a `docs/api/<Major>/` doc. The §7 module table and its counts ("fifteen majors / thirty-four files") must be **recounted upstream** in WowAddonStandards, which is a standard change.
  - The contract is additive-only from the first minor.
- **The payload cannot contain third-party libs** (§7, the Bus/AceEvent precedent at line 118). So the LibKa0s module must resolve `LibCustomGlow-1.0` at call time, softly, with no floor. **QC itself must vendor `libs/LibCustomGlow-1.0`** (§3 MUST), add the TOC line before `LibKa0s.xml`, add it to `## OptionalDeps`, record it in `DEPENDENCIES.md`, and update ARCHITECTURE's lib list. Copy the folder from DW or KickCD (§3 SHOULD).
- **Vendor sync (§7, testing-§11).** `tests/test_vendor_sync.lua` compares `libs/LibKa0s` and `tests/_kit` against the tag named in QC's `CLAUDE.md` line. LibKa0s must therefore be **tagged** (v1.74.0) before QC re-vendors, in its own commit, with the provenance line updated. Never edit `libs/`.
- **options-ui-§16/§17.** Border via `O.BorderGroup` (hand-writing it is anti-pattern #73). Every swatch gets `O.ColorPair` with `classColorSource="player"`. Color pairs are never dimmed.
- **layout-§1 cap.** `modules/Library.lua` is 1450/1500 lines. New defaults belong in `SURFACE_DEFAULTS` (`:872-889`) but must stay small.

## 3. QC today

- **Pad chip.** `modules/Pad_Render.lua:117-155` (`R.Dress`) creates `btn.qcIcon` as an ARTWORK texture sized `PL.ICON` (20), at LEFT+2.
  - Paint at `:158-163`: `SetTexture(slot.icon or DEFAULT_ICON)`, then `SetVertexColor(NS.Library.IconTint(slot.icon, slot.iconColor))` (the per-callout glyph tint, `modules/Library.lua:306`, white for anything that isn't a glyph), shown unless the style is "label".
  - There is no TexCoord and no icon border.
  - Overlays: `qcDim`, `qcCool` and `qcFlash` OVERLAY veils, plus a gold HIGHLIGHT hover.
  - Sizes come from `modules/Pad_Layout.lua:16-18`: `CHIP_H` 24, `ICON` 20, `ICON_ONLY` 28. `PL.CellSize` is at `:78-84`, so changing icon size changes chip geometry.
- **Dial wedge.** `modules/Dial_Render.lua:174-198` (`R.DressWedge`): `qcIcon` is sized `DL.WEDGE-12` (32) and centered on a round `qcBg` (circle mask `TempPortraitAlphaMask`).
  - `qcGlow` is a gold circular HIGHLIGHT (hover), not a LibCustomGlow effect.
  - Paint at `:203-214`. `DL.WEDGE` = 44 (`Dial_Layout.lua:35`) feeds the radius, disc and title math.
- **Secure and taint.** Chips and wedges are `SecureActionButtonTemplate` send buttons created by SendEngine; wedges sit under a `SecureHandlerClickTemplate` header (`docs/ARCHITECTURE.md:217`).
  - An unprotected child frame (the border backdrop, LibCustomGlow's frames) parented to a secure button may be created, shown, anchored and animated in combat. Only the button's own protected calls are refused.
  - All Look writes go through `LIBRARY_CHANGED` → `Surfaces.Request`, which queues in combat behind the stale hint. Pad.Apply is at `modules/Pad.lua:240-262`; wedges are painted at `modules/Dial.lua:118-129`. Keep icon styling on that path; it is required anyway because icon size changes protected geometry.
  - `test_sendengine.lua` greps shipped files for Secure/SetAttribute. A glow module adds none of these.
  - The mock (`tests/wow_mock.lua:211-215`) blocks `SetPoint`/`SetSize`/`SetFrameLevel`/`Show` in combat only on protected frames.
  - Released chips (`releaseChip`, `Pad.lua:113`, used at `:244` and `:275`) must stop their glow, the equivalent of DW's StopFree.
- **Schema.**
  - Hand-written pad rows `pad.look.visibility/fade/fadeAlpha` are at `settings/SchemaMembers.lua:278-289`.
  - The composed Look (`FontGroup`, `BorderGroup`, `ColorPair(background)`) is at `:325-406`: `lookChecks` at `:364`, `lookSpec` at `:382`, stamped with `instance="pad"`.
  - The onChange loop is at `:408-435`.
  - Defaults: `SURFACE_DEFAULTS.pad.look` (`Library.lua:878-884`). **Dials have no `look` at all** (`:888-889`, and `TEMPLATES.dial` at `:903`).
  - `fillShape` (`Library.lua:1303-1312`) backfills **one level deep**: `s[key][field]`. New fields must therefore be flat leaves of a top-level table such as `pad.icon.*`, not nested `look.glow.*`.
  - Paths resolve against `Lib.TEMPLATES` at boot (`settings/Schema.lua:240`).
  - Share carries any member row automatically (`SH.Portable`, `modules/Share.lua:331`).
- **Editor tabs.**
  - Pads: General / Groups / Layout / Look (`settings/Pads.lua:263`). Look renders `PD.LOOK_GROUPS` (`:214`) under headings in `renderLook` (`:225`).
  - Dials: General / Groups / Wheel / Binding / Preview (`settings/Dials.lua:400`).
- **Tests to extend or adjust.**
  - `tests/test_pad_render.lua`: the Look tests at `:167`, `:189`, `:226`; the glyph tint test at `:250`.
  - `tests/test_dial.lua`: `:72` (catalog marks).
  - `tests/test_page_pads.lua:203` **asserts exactly 3 "Use class color" checkboxes on Look**, so adding icon color pairs to Look breaks it. A separate tab avoids that.
  - `tests/test_page_dials.lua`: the tab tests.
  - `test_surface_parity.lua`, `test_share.lua` and `test_profile.lua` (backfill) also touch this area.
  - Mock regions accept any capitalized method through a catch-all, so `SetTexCoord`/`SetDesaturated` are not recorded. Extend `tests/wow_mock.lua`'s `region()` (around `:235`) to record them. QC owns that file; `tests/_kit` is off-limits.

## 4. Proposal

**LibKa0s, new major `LibKa0s-IconStyle-1.0`** (one file, or `IconStyle.lua` plus `IconStyleGlow.lua`). Pure and config-driven:
- `Apply(btn, tex, cfg)`: zoom via TexCoord, `desaturate`, `alpha`, tint multiply, and a backdrop border child frame created lazily, with headless records on the button.
- `Glow.Apply(btn, cfg, key)` / `Glow.Stop(btn, key)`: the DW START/STOP tables, the generation/width no-op and `spendBurst`.
- `GLOW_STYLES` and `GLOW_KNOBS` published as catalogs with ranges and defaults.
- An optional `O.GlowGroup` composer in `OptionsCompose.lua` (Options attach minor bump) so hosts never hand-write glow rows.
- LSM "Solid" registration.
- LibKa0s tests use a fake LibCustomGlow (DW's `fakeLib`), plus `docs/api` and a CHANGELOG entry.
- DW is not re-vendored now (owner instruction).

**QC per-surface rows.** Flat leaves under new top-level `pad.icon.*` and `dial.icon.*`, with defaults in `SURFACE_DEFAULTS` and `TEMPLATES.dial`:
- **Size:**
  - Pad: `size`, 12-40, default 20, feeding `PL.ICON`/`ICON_ONLY`/`CHIP_H` through `CellSize`.
  - Dial: `size`, 16-44, default 32, drawn inside the fixed 44 wedge so no wedge geometry changes. Making the wedge itself resizable would mean reworking DL's radius math, which is out of scope.
- **Look:** `zoom` 0..0.25 (default 0, which keeps today's look), `desaturate` bool, `alpha` 0.1..1, and a `tint` ColorPair (`tint`, `useClassColorTint`). The planner must decide how the tint combines with a callout's glyph `iconColor`: multiply, or the glyph color wins.
- **Border:** `O.BorderGroup{show=true, prefix="pad.icon."}`, default off. On the round wedge a square border looks wrong, so either offer a circular ring option or a mask for dials.
- **Glow:** `glowEnabled` (default off), `glowType`, the `glowColor` ColorPair, and the knob table with flat names such as `pixelLines`.
- **Glow trigger needs an owner decision.** DW glows on a condition; QC has none yet. Candidates: always, on hover (would replace today's HIGHLIGHT), or while a send result flashes.
- **Performance:** pixel and autocast effects run an OnUpdate on every glowing chip while the pad is shown. Add a perf bucket and a smoke test.

**Editor placement.**
- A new **"Icons" tab** on Comms Pad (General / Groups / Layout / Look / Icons) and on Comms Dial (after Wheel), with headed subgroups Size & crop, Tint, Border, Glow plus one heading per style.
- Each page's Defaults tooltip (`Pads.lua` RegisterPage, `Dials.lua:409`) must name the new rows.
- Locale keys go in `locales/enUS.lua` (853 lines).
- Docs to update: `schema.md`, `settings-panel.md`, `module-map.md`, `ARCHITECTURE.md` (lib list, Taint Notes: glows are unprotected children of secure buttons and start and stop in combat), `DEPENDENCIES.md`, `smoke-tests.md`.