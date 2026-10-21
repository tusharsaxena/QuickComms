# Shine overlay — design (2026-10-21)

Owner request: an optional overlay that gives pad buttons and dial slices a shiny or glossy look.
Mockups and the generated-art preview: https://claude.ai/artifact/PogWcsjkcyGTsDabhw3K2A

Status: built (docs/superpowers/plans/2026-10-21-shine-overlay.md, T1-T5), then reworked after the
owner's first in-game look (2026-10-21, below), and again after the second (2026-10-21, "The owner's
second look"); its in-game checks are ART-1 and SHINE-1..3 in
`docs/smoke-tests.md`, pending the owner's run. The art generator is `tools/gen-shine-textures.py`
(Pillow and NumPy; see DEPENDENCIES.md), and its 50 textures are committed under
`media/textures/shine-*.tga`.

**What the addon draws, rendered offline:** `2026-10-21-shine-overlay/render-dial-4.png`,
`render-dial-8.png`, `render-dial-12.png` and `render-pad.png`, beside this file, every look and None.
`tools/render-shine-preview.lua` loads the addon headless through the test harness and dumps every
region the stock dial and pad painted; `tools/render-shine-preview.py` composites the dump as the
client blends it. They replace the prototype's `preview.py` and `preview.png` (removed): that script
composited a hand-written copy of the recipe at four slices, never the addon's code, so nobody saw what
the game would draw.

## The owner's first look and the rework (2026-10-21)

The owner tried each look in game (stock settings, a new profile, an 8-slice dial) and found they did
not look like the mockups; on the pad, the shine covered only the icon. The renderer, run on the code
as it was, reproduced each screenshot, and showed why:

- **Glass orb:** past four slices the sprites narrowed by tan(π/n) but kept their height, so at eight
  the elongated spot and glow became round dots, and the soft edge shade was too weak to make a bead.
  Now the bead, spot and glow are laid out on each slice's inscribed circle (`DialSlices.OrbSprites`),
  so the mockup's shape scales whole, and a vignette sprite (`shine-bead`) darkens the slice outside
  the bead as the mockup's does.
- **Frosted glass and the rims:** every slice drew a rim about 4 px wide, so two neighbours made a
  thick light bar at every spoke, and the streak was a straight sprite. Now the rim is about one texel
  (two neighbours read as the mockup's 1.2 px stroke) and the streak is a per-count edge set on the
  arc (`shine-edge-streak-<n>`), keeping its share of the slice at every count.
- **Fluid glass:** the blooms were radial, so the mint ring was even all round. The mockup's gradient
  runs along each slice's own axis (pink and purple rising toward the rim, mint only at the middle of
  its arc), which the blooms now follow; they still turn with their slice, as in the mockup's SVG.
- **Gloss cap:** the art was right; its light rim turned the slices' boundaries into light spokes,
  where the mockup has dark hairlines. The rim is now black.
- **Bevel:** each slice's whole outline took one shade by the way the slice faced. The mockup's outline
  is one dial-wide gradient, so it shades along each edge; it is now that upright gradient
  (`shine-dial-bevel-edge`) seen through the slice's rim as a second mask.
- **Rim light:** the soft edge glow ran along the spokes too; the mockup's glow is only inside the rim
  (`shine-dial-rim`, radial).
- **Pads: the whole button (owner, 2026-10-21)**, not the icon; see Pads.

Every dial look is now the mockup card's SVG recipe drawn at the slice's count; the dial's
`shine-edge-soft-<n>` sets and `shine-streak` sprite are retired.

## The owner's second look (2026-10-21)

The owner tried the reworked looks in game (8 slices, stock). Gloss cap and Rim light "look great"
and stay as they are. The rest changed (owner, 2026-10-21), each checked in the offline renders at 4,
8 and 12 slices and on the pad:

- **Glass orb: no dots.** The mockup's specular spot and glow read as a dot on every slice ("looks
  broken"), so both are gone, and so is their art (`shine-spot`, `shine-glow`). The bulge is the shading
  alone: the bead (`shine-bead`) now carries a broad, faint dome of light inside its vignette, tinted
  by the Tint, and the dark hairlines stay. The pad's orb lost its spot and its bottom glow too; it is
  a soft band of light across the button's upper third over edges that darken all round, darkest at
  the bottom, so it stays plainly different from None on a wide button.
- **Frosted glass: reworked** ("ok, not awesome"). A milky wash, thin over the hub and milkier toward
  the rim, with a crisp bright line on the outer arc (`shine-dial-frost`, whole-disc, masked), faint
  light lines at the spokes, and a soft line of light just inside each slice's left spoke, at the same
  angle off it at every count (`shine-edge-streak-<n>`, redrawn), so it reads as light caught along one
  edge of the glass. The pad's: a milky wash, milkier toward the edges, a crisp rim brightest along the
  top, and a soft streak just under the top edge.
- **Fluid glass: redesigned** ("looks bad": a muddy mint ring and a murky pink wash). The two blooms
  are now sprites (`shine-fluid-bloom1/2`, `DialSlices.FluidSprites`) as wide as the slice's chord at
  the rim, their tops on it: together a clean iridescent edge, pink (bloom A) at the middle of each
  slice's outer arc crossing to mint (bloom B) toward its spokes, at a constant total, rising steeply
  to 60% at the rim and gone well before the hub, plus the thin light rim. Neighbours meet mint to
  mint, so the ring reads continuous; the slices' middles carry no wash. Both bloom colors keep their
  meaning. The whole-disc blooms (`shine-dial-fluid-bloom1/2`) are retired. The pad's Fluid glass is
  unchanged.
- **Bevel: the same on every slice** ("top left has bevels, bottom right does not"). The owner
  overrides the first build's call of one light direction for the whole dial (owner, 2026-10-21): each
  slice is raised in its own frame, a per-count art set (`shine-edge-bevel-<n>`) placed and turned with
  the slice like the fill: light on the outer arc and the left spoke, dark on the right spoke and the
  inner end, each strongest at the edge and easing inward, mitred at the corners, over a gentle shade
  from light at the outer left to dark at the inner right. It needs no mask; the upright art
  (`shine-dial-bevel`, `shine-dial-bevel-edge`) and the rim mask are retired. The pad's Bevel is
  unchanged.

Conformance: the Ka0s WoW Addon Standard applies throughout (schema-driven rows, locales, the green
gate, docs in the same change). Nothing here is meant to deviate; if building it needs one, stop and
flag it (CLAUDE.md).

## Goals

1. **Six looks** (owner picked all but Satin sheen): Gloss cap, Glass orb, Frosted glass, Fluid glass,
   Bevel, Rim light, plus **None** (the default).
2. **Chosen separately for pad buttons and dial slices** (owner): a pad's buttons and a dial's slices
   each have their own Look, Strength and Tint, so a pad can be Glass orb while a dial is Rim light,
   or either can be None. They are per member, like every other look setting: each pad and each dial
   keeps its own.
3. **Our own art.** Every texture is drawn by a script in this repo (`tools/gen-shine-textures.py`,
   beside `tools/gen-dial-textures.py`), so no outside licence is involved. The generator ships with
   the repo under its MIT licence.
4. **No change for anyone who does not opt in.** Default None on both; existing profiles load as they
   are, with no migration.
5. **Crisp dial art (owner, 2026-10-21): real textures replace the shapes the dial draws today.**
   The hub (all four styles: the backdrop, its rim, the hollow ring, the filled circle, Target's dot),
   the page dots and the current page's pill, the indicator background, the dot borders and the round
   arrow plates look ragged in game. Rings and rims are 64 straight segments, and every filled circle
   is Blizzard's portrait mask stretched to size. See "Crisp dial art" below.

## Non-goals

- No animated shine (a sweep on hover or send); possible later.
- No shine on the pad header, the dial's hub, the page arrows or the indicators in this batch (the hub
  could reuse the dial's radial looks later).
- No per-button or per-slice override: the look is per pad and per dial.

## Crisp dial art (goal 5)

The art is generated by our own script, in Quick Comms (`media/textures/`), not LibKa0s. LibKa0s
Media has nothing round to reuse (gradient, over- and underlines only), and an outside MIT asset would
add a provenance trail for shapes a script draws exactly. Every texture is white on transparent and
antialiased by supersampling, and the client tints it with SetVertexColor, as the slice sectors are.

| File | Size | Replaces |
|---|---|---|
| `dial-disc.tga` | 256² | Every filled circle: the hub's backdrop and circle, Target's dot, the page dots, the arrow plates, the wedge's dim, cooldown and flash discs, the wedge's round icon border (branch review), and the one-slice dial (today `TempPortraitAlphaMask`). |
| `dial-ring-<k>.tga`, k = 1..12 | 128² | The hollow ring, Target's ring and the backdrop's rim (today `DL.ARC` segments). Ring k has a line of `RING_STEPS[k]` of its diameter, a geometric ladder from 1.25% to 50% (about 1.4× per step). A ring `d` across with a `w` px line draws the step nearest `w/d`, so the error stays under about 18% of the line (under 1 px at the largest line width). |
| the disc's halves | (texcoords) | The current page's pill, the indicator background and their borders: three pieces (the left half of `dial-disc`, a stretched WHITE8x8 middle, the right half), so the round ends stay round at any width. `dial-pill.tga` is retired. |

Sizes: a hub is at most 80 px and a dot at most 20 px, so 128² rings stay crisp at every size the
settings allow, and mipmaps keep them clean when drawn small. The disc is 256² because it also draws
the one-slice dial (up to about 450 px, like the sector textures). Together they are about 1 MB. The
pointer keeps its glyph (a 64-px LibKa0s icon), which is already clean.

Code: `R.RingTexture(diameter, width) -> path` (pure, tested) picks the step. `R.PaintHubLook` sets
the rim and ring textures instead of building segment lists (`qcHubRim` and `qcHubRing` each become
one texture), and `DL.ARC` goes. Dial_Slices' dots, pill, background and borders take the disc and the
three-piece pill. Nothing in a profile changes.

## Settings (schema rows; locales for every string)

| Where | Path | Type | Default |
|---|---|---|---|
| Pad page, Buttons tab, new "Shine" heading | `pad.button.shineLook` | none, gloss, orb, frost, fluid, bevel, rim | none |
| | `pad.button.shineStrength` | 0–100 %, step 5 | 85 |
| | `pad.button.shineTint` + `useClassColorShineTint` | color | white |
| | `pad.button.shineBloomA`, `shineBloomB` (+ class-color companions; Fluid glass only) | color | #ff9ad5, #8affc1 |
| Dial page, Slices tab, new "Shine" heading | `dial.slice.shine*` | the same leaves | the same |

Flat leaves, like `dial.page.dotBack*`. Strength, Tint and the bloom colors gray out while Look is None, and the bloom colors gray out unless
Look is Fluid glass (the pattern the pointer rows use). New leaves come from the defaults tables, so
profiles need no migration (as with `dial.slice.gap`). Diagnostics' pad and dial look lines print the
look and strength.

## Art (generated, white light and black shade on transparent)

| File | Size | Used by |
|---|---|---|
| `shine-pad-<look>.tga` (gloss, orb, frost, fluid, bevel, rim) | 128² | one per pad button, over the whole button in three pieces |
| `shine-pad-fluid-bloom1/2.tga` | 128² | Fluid glass's two tinted bloom layers |
| `shine-dial-gloss.tga`, `-rim.tga` (128²), `-frost.tga` (256²) | | the whole disc, cut to each slice by a mask |
| `shine-edge-rim-<n>.tga`, n = 1..12 | 256² | each slice's own rim, about one texel, shaped exactly like `dial-sector-<n>.tga` |
| `shine-edge-streak-<n>.tga`, n = 1..12 | 256² | Frosted glass's line of light just inside each slice's left spoke |
| `shine-edge-bevel-<n>.tga`, n = 1..12 | 256² | Bevel's raised edges and face shade, in the slice's own frame |
| `shine-bead.tga` | 128² | Glass orb's bulge, a dome of light and a vignette; square, so a turn keeps its shape |
| `shine-fluid-bloom1/2.tga` | 128² | Fluid glass's two blooms across a slice's outer part |

Retired after the owner's second look (2026-10-21; the generator removes them): `shine-spot`,
`shine-glow`, `shine-dial-bevel`, `shine-dial-bevel-edge`, `shine-dial-fluid-bloom1/2`.

About 10.6 MB in all, on top of today's 2.8 MB of slice textures. White pixels add light and black
pixels add shade, so one texture can do both. The client draws them in BLEND mode; SetVertexColor's
color tints the light (shade stays black) and its alpha is Strength.

## Pads

- **The whole button (owner, 2026-10-21):** the shine covers the button's plate, its icon and its
  label's chip, whatever the Button style (a label-only button takes it too); it was anchored to the
  icon until then.
- A button is a wide chip (120 × 24 by default) and the art is square, so each layer is three pieces
  (`btn.qcShine = { left, mid, right }`), as the dial's pills are: the art's left half as a cap on the
  button's left corners, half the button's height wide; its middle column (texcoords 0.49 to 0.51)
  stretched between; its right half on the right corners. The caps keep every edge the art draws (a
  rim, a bevel, the gloss cap's rounded end) as thin as on a square, and a square
  button (Icon only) is the art whole, with no middle. A button taller than wide takes caps half its
  width. `NS.Shine.Apply(btn, shine, w, h)` takes the button's drawn size (`R.ApplyButtonLook`'s).
- Layer: ARTWORK sublevel 5, above the icon. It stays below the OVERLAY marks (the lock, the label,
  the veils and the send flash) and below the HIGHLIGHT hover, so those read the same as today.
- Fluid glass adds two more layers (the blooms, three pieces each), created only when that look is
  chosen.
- Painted in the pad's render pass (Pad_Render), from R.Look's new `shine` table.

## Dial slices

- Each slice gets an overlay set, placed by the same `place()` helper as its fill (Dial_Slices). It
  therefore follows the slice gap, the W/E layouts and every slice count.
- Layer: BACKGROUND, above the fill and the hover highlight. The icons sit on the wedge buttons
  above, so they are never covered.
- Per look, at the slice's count (radius 1; Gloss cap and Rim light are the mockup card's SVG, radius
  100 there; the others were redrawn after the owner's second look):
  - **Gloss cap** (a-ring): the disc gloss, clear to 0.55 of the radius, 42% at 0.57 falling to 10%
    at the rim, masked by the slice's sector; plus the slice's rim in black at 60% (the mockup's dark
    hairlines between slices).
  - **Glass orb** (b-sl, no dots: owner, 2026-10-21): on the slice's inscribed circle (center
    c = 1/(1 + sin(π/n)), radius p = c·sin(π/n); for one slice the disc itself), so the bead keeps its
    shape at every count: the bead sprite, 7 p across, tinted by the Tint (its shade stays black), a
    vignette black 50% from 1.4 p out, easing in from 0.77 p, and inside it a broad dome of light,
    12% at its middle (a little toward the rim) fading by 1.26 p; masked; plus the black rim at 60%.
  - **Frosted glass** (reworked: owner, 2026-10-21): the frost disc (`shine-dial-frost`, masked: a
    white wash 5% at the hub rising smoothly to 18% at the rim, and a crisp 85% line on the arc at
    0.982), the rim at 35%, and the streak edge set (a soft line of light 42% at its peak, about 4.3
    degrees off the slice's left spoke at every count, fading in from 0.3 to 0.6 of the radius and out
    from 0.82 to 0.96).
  - **Fluid glass** (redesigned: owner, 2026-10-21): both blooms as sprites (`FluidSprites`: a square
    as wide as the slice's chord at the rim, 2 sin(π/n), its top on the rim; the whole disc for one or
    two slices), masked, tinted bloom A and bloom B, turned with the slice. Across the sprite the
    gradient runs pink (A) at the middle to mint (B) toward both sides (eased, from 0.05 to 0.42 of the
    width off the middle), at a constant total that rises from clear at 0.35 of the sprite's height to
    60% at its top (eased, to the power 2.5); bloom A is drawn first and bloom B over it with the
    alphas split so the two cross-fade exactly. Plus the rim at 30%.
  - **Bevel** (the same on every slice: owner, 2026-10-21): the slice's bevel edge set
    (`shine-edge-bevel-<n>`), placed and turned as the fill, unmasked: bands 0.045 of the radius wide,
    strongest at the edge and easing inward, light 60% on the outer arc and the left spoke, dark 70% on
    the right spoke and the inner end (at 0.17), the nearest edge winning at each corner; under them a
    face shade from white 14% at the outer left to black 14% at the inner right.
  - **Rim light** (g-srim): a radial glow, clear to 0.82 and rising to 30% at the rim, masked; plus the
    rim at 50%.
- **Masks:** a MaskTexture per slice of its sector texture (`mask`), placed and turned like the fill,
  created once per slice and reused. Bevel needs none (its art is slice-shaped).
- **Sprites:** square art, positioned in the slice's own frame (a local x across and a distance out,
  turned by the slice's middle angle), the same math as the wedge centers; the slice's mask cuts them.
- **One slice (n = 1):** `dial-disc.tga` as the mask and `shine-edge-*-1` (a full-disc rim, a streak
  across the top left and a disc bevel lit from the top left).

## LibKa0s: not now (owner, 2026-10-21)

Everything lives in Quick Comms for now. The button half (the pad art and its generator, the attach
and paint helper, the Look / Strength / Tint settings block) is generic enough for LibKa0s: KickCD,
AuraMaster, ConsumableMaster and DropWatcher all draw icon buttons. But it has one consumer today,
and `library-stack-§7` asks for two. So:

- The button half sits behind one seam, `NS.Shine`, shaped as the library helper would be:
  `NS.Shine.Apply(btn, icon, { look, strength, tint, bloomA, bloomB })`, plus `NS.Shine.LOOKS`. It
  holds no pad-specific code, so a later move is a lift, not a rewrite.
- The pad art lives in Quick Comms' `media/textures/`, made by `tools/gen-shine-textures.py`.
- Re-check trigger: a second Ka0s addon wants a button shine. Then propose moving the button half
  into LibKa0s Media, Widgets and Options (the dial half stays here).

## Combat and performance

- Purely cosmetic textures on the existing frames, created and painted in Apply (out of combat). The
  secure click path (catchers, wedges, header) is untouched, and so is the firewall.
- Changing a look in combat queues like any other look change. Color and alpha changes would be
  legal in combat, but we keep the existing rule of painting on Apply.
- No per-frame work. It adds one to three textures per pad button and three to five per slice, and
  six to sixty more regions on a 12-slice dial.

## Tests (headless)

- Rows: look choices, ranges, defaults, gray-out rules, both pages.
- Pads: the shine's three pieces exist, sit at the right layer and sublevel, cover the whole button
  (the caps on its corners, half its height wide, the texcoords), use the chosen file, tint and alpha,
  and are hidden at None; a square button has no middle; a label-only button keeps its shine. Fluid
  glass's blooms exist only for Fluid glass.
- Dial: per look, the overlay set per slice and its masks. Masks follow the slice's place and
  rotation, including with gap 8 and fixed 4 with two items (W/E). Bevel is its count's edge set,
  placed and turned as the fill, unmasked. Glass orb's bead sits on the slice's inscribed circle with no
  spot or glow, and Fluid glass's blooms span the slice's outer part, each at its local position turned
  by the slice, at 4 and 8 slices. Frosted glass's streak is its count's edge set. Nothing is created
  at None; the retired layers (the orb's spot and glow, Bevel's outline and rim mask) never are.
- The offline renders (`tools/render-shine-preview.py`) are re-run after any change to the art or a
  recipe, and looked at against the mockup; they gate nothing.
- Independence: the pad set to orb and the dial set to none (and the reverse) each paint only their
  own.
- A generator check: the TOC-relative paths the code names all exist under media/textures.

## Smoke tests (in game)

- Each look on a pad and on a dial, at icon sizes 24, 40 and 128, and with a slice gap of 0 and 8.
- **A turned MaskTexture cuts every masked layer cleanly at every slice place.** The owner's first
  screenshots showed the sector mask cutting cleanly at 8 slices. Fallback: per-slice-count masked
  textures for Gloss cap (about 2.8 MB more), as Bevel now is.
- Readability: Frosted glass and Fluid glass at full strength on busy icons, and every look over a
  pad button's label now that the shine covers it; the Strength default may drop if needed.

## Builder's calls (owner may override)

- Look, Strength and Tint per pad and per dial. There is no global setting, because every other look
  setting is per member.
- The dial's shine sits under the icons and the pad's sits over them (the action-bar convention).
- The default Strength is 85%.
- Bevel's light direction: one for the whole dial in the first build; the owner overrode it
  (2026-10-21): every slice is raised the same way, in its own frame.
- Satin sheen is dropped, and so is its letter: the looks keep their mockup letters A–E and G.
