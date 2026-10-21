# Shine overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Crisp generated art for the dial's hub, dots and pill, then an optional shine overlay
(six looks) chosen separately for pad buttons and dial slices.

**Architecture:** Every texture is white-and-black on transparent, drawn by our own generators in
`tools/`, shipped in `media/textures/`, and tinted and faded in game with SetVertexColor. One new
module, `modules/Shine.lua` (`NS.Shine`), owns the looks catalog and paints a pad button's shine; it
has no pad-specific code, so a later lift to LibKa0s is a move. The dial's slice shine lives in
`modules/Dial_Slices.lua`, beside the fills it follows.

**Tech Stack:** Lua 5.1 (WoW), the headless harness (`tests/run.lua`, `tests/wow_mock.lua`),
luacheck, Python 3 with Pillow (and NumPy for the shine generator).

**Spec:** `docs/superpowers/specs/2026-10-21-shine-overlay-design.md`

## Global Constraints

- Ka0s WoW Addon Standard throughout: schema rows in `settings/SchemaMembers.lua`, every string
  through `L[...]` in `locales/enUS.lua`, docs in the same commit as the code. A deviation stops the
  task and is reported, never worked around.
- Gate before every commit: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
  and `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0/0).
- Lua and Markdown files are CRLF on disk (`.gitattributes`; the `eol` test fails on LF); `.py` is LF.
- Art is ours, in Quick Comms only (`media/textures/`), never LibKa0s. No outside assets.
- Default look **None** on both pads and dials; no migration step (new leaves come from the defaults
  tables, as `dial.slice.gap` did).
- Leaves are flat, like `dial.page.dotBack*`: `shineLook`, `shineStrength`, `shineTint` +
  `useClassColorShineTint`, `shineBloomA` + `useClassColorShineBloomA`, `shineBloomB` +
  `useClassColorShineBloomB`, under `pad.button.` and `dial.slice.`.
- Look ids: `none`, `gloss` (Gloss cap), `orb` (Glass orb), `frost` (Frosted glass), `fluid` (Fluid
  glass), `bevel` (Bevel), `rim` (Rim light). Strength 0–100, step 5, default 85. Tint default white
  {1,1,1,1}. Bloom defaults #ff9ad5 {1,0.604,0.835,1} and #8affc1 {0.541,1,0.757,1}.
- Secure code is untouched: no task changes SendEngine, the snippets or the catchers.

## Review Focus

1. Switching from Fluid glass to another look, or to None, leaves no bloom or sprite behind.
2. A dial whose slice count changes (Auto paging, a fixed 4 changed to 8, a page turn) hides the
   overlay sets of places it no longer uses and resizes the rest.
3. A slice gap above 0 moves each slice's shine with its slice (the same `place()` call).
4. A pad button with no icon drawn (a text-only button style) draws no shine.
5. A ring whose line is half its diameter or more (a 6 px line on a 4 px circle) draws the solid
   disc, not a stretched or missing ring.

Each line has its test in the task that owns the code.

## Status ledger

- [x] T1 Crisp dial art: disc, ring ladder, three-piece pill
- [ ] T2 Shine art and `NS.Shine` (catalog and the pad painter)
- [ ] T3 Pad buttons: Shine settings and paint
- [ ] T4 Dial slices: Shine settings and paint
- [ ] T5 Docs, diagnostics, smoke tests, push

Commit subjects start with "Shine T<n>:".

---

### Task 1: Crisp dial art

**Files:**
- Modify: `tools/gen-dial-textures.py` (add the disc and the ring ladder; drop the pill)
- Create: `media/textures/dial-disc.tga`, `media/textures/dial-ring-1.tga` .. `dial-ring-12.tga`
- Delete: `media/textures/dial-pill.tga`
- Modify: `modules/Dial_Render.lua` (`CIRCLE`, `circle()`, `R.DressHub`, `R.PaintHubLook`, the
  segment `arc()` helper goes), `modules/Dial_Slices.lua` (`CIRCLE`, `S.PILL`, `paintBack`,
  `paintDot`, `S.SectorTexture(1)`), `modules/Dial_Layout.lua` (`DL.ARC` goes)
- Test: `tests/test_dial.lua`, `tests/test_dial_layout.lua`

**Interfaces:**
- Produces: `R.RING_STEPS` (12 numbers, line ÷ diameter, `0.0125 * (40 ^ ((k-1)/11))`);
  `R.RingTexture(diameter, width) -> string` (the media path of the nearest step in log space, or the
  disc's path when `width >= diameter / 2`); `S.DISC` (the disc's path), used by T4.

- [ ] **Step 1: Write the failing tests**
  - `dial: [art] RingTexture picks the nearest step`: `R.RingTexture(22, 2)` ends `dial-ring-<k>`
    with k the step nearest 2/22 (assert by recomputing the log-distance minimum over `R.RING_STEPS`);
    `R.RingTexture(80, 1)` is step 1; `R.RingTexture(4, 6)` is `S.DISC` (Review Focus 5);
    `R.RingTexture(40, 20)` is `S.DISC`.
  - `dial: [art] the hub draws textures, not segments`: after Apply with each style, `qcHubRing` and
    `qcHubRim` are single textures whose texture is a `dial-ring-` path (or hidden for `solid`, rim
    hidden at borderSize 0), the backdrop and the circle use `dial-disc`, and no texture on the hub
    uses `TempPortraitAlphaMask`.
  - `dial: [art] the pill is three pieces with round ends`: a paged ring's current pill and the
    indicator background are each a left cap (the disc, texcoords 0..0.5), a middle (WHITE8x8) and a
    right cap (0.5..1), caps `h` wide, the middle `w - h`; the same with a border.
  - `dial layout: [art] DL.ARC is gone`; every `dial-*.tga` path the dial modules name exists under
    `media/textures/` (read the files from the module sources' string constants).
- [ ] **Step 2: Run them, expect FAIL** (the functions and files do not exist).
- [ ] **Step 3: Generate the art.** Add `disc()` (256², the filled circle) and `ring(frac)` (128²,
  outer radius at the edge, inner at `1 - 2*frac` of it) to `tools/gen-dial-textures.py`, both
  supersampled with the script's `SUPER`; write `dial-ring-<k>` for each step; stop writing the pill.
  Run `python3 -I tools/gen-dial-textures.py`; delete `media/textures/dial-pill.tga`.
- [ ] **Step 4: Use it.** `R.RingTexture` as above; `R.PaintHubLook` sets ring and rim with it
  (rim: diameter `hub.size`, width `hub.borderSize`; ring: `circleSize`, `lineWidth`; Target's ring as
  the ring); every circle that used `TempPortraitAlphaMask` uses the disc; Dial_Slices draws the pill,
  the background and their borders as three pieces.
- [ ] **Step 5: Run the gate, expect PASS.** Update the tests that counted segments or named the
  pill.
- [ ] **Step 6: Commit** "Shine T1: crisp dial art (disc, ring ladder, three-piece pill)", the TGAs
  included; update `DEPENDENCIES.md`'s gen-dial-textures paragraph (what it now writes).

### Task 2: Shine art and NS.Shine

**Files:**
- Create: `tools/gen-shine-textures.py` (moved from
  `docs/superpowers/specs/2026-10-21-shine-overlay/gen-shine-textures.py`; output under
  `media/textures/`), `media/textures/shine-*.tga` (39 files), `modules/Shine.lua`
- Modify: `QuickComms.toc` and the tests' load list (a new module, in load order before
  `Pad_Render.lua`), `DEPENDENCIES.md` (NumPy, for this generator only)
- Test: `tests/test_shine.lua` (new; register it in `tests/run.lua` as the others are)

**Interfaces:**
- Produces:
  - `NS.Shine.LOOKS` = `{ "none", "gloss", "orb", "frost", "fluid", "bevel", "rim" }`;
  - `NS.Shine.Texture(kind, look) -> path|nil` (`kind` is `"pad"`, `"dial"`, `"edge-rim"`,
    `"edge-soft"`, `"sprite"`), and `NS.Shine.Edge(kind, n)` for the per-count edge textures;
  - `NS.Shine.Resolve(cfg) -> { look, alpha, tint = {r,g,b}, bloomA, bloomB }` from a look table's
    flat leaves (Strength / 100 → alpha; class colors resolved through `NS.ResolveColor`);
  - `NS.Shine.Apply(btn, icon, shine)`: paints `shine` (a Resolve result) on `btn` over `icon`.
- Consumes: nothing from T1.

- [ ] **Step 1: Write the failing tests** in `tests/test_shine.lua`:
  - `shine: every catalog path exists`: each look's pad texture, the dial discs, the blooms, the
    sprites and both edge sets for n = 1..12 exist under `media/textures/`.
  - `shine: Apply paints over the icon`: `btn.qcShine` is ARTWORK sublevel 5, anchored all-points to
    `icon`, texture `shine-pad-orb`, vertex color tint × alpha 0.85, blend `BLEND`.
  - `shine: blooms only for fluid`: `fluid` shows `qcShineBloom1/2` (ARTWORK 6 and 7, tinted bloomA and
    bloomB); then `orb` hides both (Review Focus 1); then `none` hides all three.
  - `shine: no icon, no shine`: an icon that is hidden or has no texture leaves `qcShine` hidden
    (Review Focus 4).
  - `shine: Resolve`: Strength 0 → alpha 0; class color tint uses the class color.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Move the generator, run it, write `modules/Shine.lua`.** The mock records draw layer
  and sublevel already (dial polish); add blend mode if it does not.
- [ ] **Step 4: Gate, expect PASS.**
- [ ] **Step 5: Commit** "Shine T2: shine art and NS.Shine"; remove the prototype copy from the spec
  folder and point the spec at `tools/`.

### Task 3: Pad buttons — Shine settings and paint

**Files:**
- Modify: `defaults/PadStyle.lua` (`D.Button()` gains the shine leaves), `settings/SchemaMembers.lua`
  (`buttonRows`: a "Shine" heading), `modules/Pad_Render.lua` (`R.ButtonLook` carries
  `shine = NS.Shine.Resolve(button)`, its signature includes it; `R.ApplyButtonLook` calls
  `NS.Shine.Apply(btn, btn.qcIcon, cl.shine)`), `locales/enUS.lua`
- Test: `tests/test_pad_render.lua`, `tests/test_page_pads.lua`

**Interfaces:**
- Consumes: `NS.Shine.Resolve`, `NS.Shine.Apply`, `NS.Shine.LOOKS` (T2).
- Produces: the pad's `R.ButtonLook(...).shine`.

- [ ] **Step 1: Failing tests:**
  - `page pads: [shine] the Buttons tab has a Shine heading`: Look (the seven choices, default None),
    Strength (0–100, step 5, default 85), Tint + class color, Bloom colors A and B. Strength, Tint and
    the blooms are disabled while Look is None; the blooms are disabled unless Look is Fluid glass.
  - `pad render: [shine] a look on the Buttons tab paints every button`: set `pad.button.shineLook =
    "gloss"` → every visible button's `qcShine` shows `shine-pad-gloss`; None hides them.
  - `pad render: [shine] the pad's look leaves the dial alone`: a pad at `orb` and a dial at `none`
    → the dial's slices carry no shine (Goal 2's independence; T4 adds the reverse).
- [ ] **Step 2: Run, expect FAIL.** **Step 3: Implement.** **Step 4: Gate, expect PASS.**
- [ ] **Step 5: Commit** "Shine T3: pad buttons take a shine".

### Task 4: Dial slices — Shine settings and paint

**Files:**
- Modify: `defaults/PadStyle.lua` (`D.DialSlice()` gains the shine leaves),
  `settings/SchemaMembers.lua` (`sliceRows`: a "Shine" heading), `modules/Dial_Render.lua` (`R.Look`
  carries `shine`), `modules/Dial_Slices.lua` (`S.Dress` adds per-slice overlay lists; `S.Paint`
  calls a new local `paintShine(ring, spec, look)` after `paintFills`), `locales/enUS.lua`
- Test: `tests/test_dial.lua`, `tests/test_page_dials.lua`

**Interfaces:**
- Consumes: `NS.Shine.Texture`, `NS.Shine.Edge`, `NS.Shine.Resolve` (T2); `S.DISC` (T1); the
  existing `place(t, ring, j, shape)` and `middle(j, size, start)`.
- Produces: per slice j, `ring.qcShine[j]` = `{ disc, mask, rim, soft, spot, glow, streak, bloom1,
  bloom2 }` (created on first use, hidden when unused).

Each look's recipe, per slice, levels × the Strength alpha (the spec's "Dial slices" section):

| Look | Layers |
|---|---|
| gloss | disc `shine-dial-gloss` masked by the slice; rim 0.30 |
| orb | soft, tinted black, 0.50; `shine-glow` 0.45 at local (0, -0.38R), 0.5R × 0.2R; `shine-spot` at (-0.24R, -0.80R), 0.34R × 0.12R, turned 22° counterclockwise |
| frost | WHITE8x8 masked, 0.09; rim 0.55; `shine-streak` at (0, -0.95R), 0.68R × 0.05R |
| fluid | `shine-dial-fluid-bloom1/2` masked, tinted bloomA/bloomB; rim 0.35 |
| bevel | `shine-dial-bevel` masked, **not rotated**; rim tinted white when `cos(a - 315°) >= 0`, else black, at `0.25 + 0.45*|cos(a - 315°)|` |
| rim | soft 0.35; rim 0.60 |

R is the slice's placed radius (`(shape.disc - 2*shape.shift) / 2`). Local points turn by the
slice's middle angle `a` exactly as `place()` turns the fill; a sprite's rotation is its local turn
minus `a`. The mask is a MaskTexture set to `S.SectorTexture(n)`, placed with `place()`, added to
each masked layer; one slice (n = 1) uses the disc as its mask. Layers sit at BACKGROUND above the
fill and the highlight (`place()` callers today use sublevels 1 and 2: shine uses 3 to 6).

- [ ] **Step 1: Failing tests:**
  - `page dials: [shine] the Slices tab has a Shine heading`: the same rows and gray-outs as T3.
  - `dial: [shine] each look builds its recipe on every slice`: for each look on a 4-slice ring, the
    layers in the table are shown with those textures and alphas; the others are hidden.
  - `dial: [shine] the overlay follows the slice`: with gap 8 and with fixed 4 holding 2 items (W/E),
    each slice's disc, rim and mask share the fill's size, point and rotation (Review Focus 3);
    bevel's disc has rotation 0 and its mask the fill's.
  - `dial: [shine] sprites sit in the slice's frame`: orb's spot on the E slice is at
    `local(-0.24, -0.80)` turned by 90°.
  - `dial: [shine] fewer slices hide the rest`: paint 8 slices, then 4 → places 5..8 have every layer
    hidden (Review Focus 2); `none` hides all.
  - `dial: [shine] the dial's look leaves the pad alone`: the reverse of T3's test.
- [ ] **Step 2: Run, expect FAIL.** **Step 3: Implement.** **Step 4: Gate, expect PASS.**
- [ ] **Step 5: Commit** "Shine T4: dial slices take a shine".

### Task 5: Docs, diagnostics, smoke tests, push

**Files:**
- Modify: `modules/Diagnostics.lua` (the pad's button-look line and the dial's slice line print
  `shine=<look> <strength>`), `tests/test_diagnostics.lua`, `docs/ARCHITECTURE.md` (module map row
  for Shine, the art, known limitations: the turned mask is in-game only), `docs/module-map.md`,
  `docs/schema.md`, `docs/settings-panel.md`, `docs/data-flow.md`, `docs/smoke-tests.md`,
  `docs/test-cases.md` (regenerated with `--list`, the Total), `README.md` (feature text, test badge),
  `docs/superpowers/specs/2026-10-21-shine-overlay-design.md` (point the art at `tools/`)

- [ ] **Step 1: Failing test** for the diagnostics lines; **Step 2** implement; **Step 3** gate.
- [ ] **Step 4: Smoke tests**, one per item, added to the index and the Pending sign-off table:
  - ART-1: the hub's four styles, the dots, the pill, the indicator background, the borders and the
    arrow plates are smooth at hub sizes 24, 40 and 80, dot sizes 4 and 20, and line widths 1 and 6.
  - SHINE-1: each look on a pad at icon sizes 16, 24 and 40.
  - SHINE-2: each look on a dial at 4 and 8 slices, gap 0 and 8, radius 100 and 180; Bevel's light
    stays top-left on every slice and the turned mask cuts Gloss and Bevel cleanly (the one client
    behavior not yet seen; fallback in the spec).
  - SHINE-3: a pad and a dial set to different looks keep their own.
- [ ] **Step 5: Commit** "Shine T5: docs, diagnostics and smoke tests", then `git push`.
