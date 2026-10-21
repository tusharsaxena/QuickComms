# Shine overlay — design (2026-10-21)

Owner request: an optional overlay that gives pad buttons and dial slices a shiny or glossy look.
Mockups and the generated-art preview: https://claude.ai/artifact/PogWcsjkcyGTsDabhw3K2A

Status: design only, not built. The art prototype sits beside this file in
`2026-10-21-shine-overlay/`: `gen-shine-textures.py` (the generator, to move to `tools/` when this is
built; it uses Pillow and NumPy, so DEPENDENCIES.md gains NumPy then), `preview.py` (composites the
textures the way the client blends them) and `preview.png` (its output). The textures are not
committed: run the generator to rebuild them.

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

## Non-goals

- No animated shine (a sweep on hover or send); possible later.
- No shine on the pad header, the dial's hub, the page arrows or the indicators in this batch (the hub
  could reuse the dial's radial looks later).
- No per-button or per-slice override: the look is per pad and per dial.

## Settings (schema rows; locales for every string)

| Where | Path | Type | Default |
|---|---|---|---|
| Pad page, Buttons tab, new "Shine" heading | `pad.button.shine.look` | none, gloss, orb, frost, fluid, bevel, rim | none |
| | `pad.button.shine.strength` | 0–100 % | 85 |
| | `pad.button.shine.tint` + `useClassColorTint` | color | white |
| | `pad.button.shine.bloomA`, `bloomB` (+ class-color companions; shown for Fluid glass only) | color | #ff9ad5, #8affc1 |
| Dial page, Slices tab, new "Shine" heading | `dial.slice.shine.*` | the same leaves | the same |

Strength, Tint and the bloom colors gray out while Look is None, and the bloom colors gray out unless
Look is Fluid glass (the pattern the pointer rows use). New leaves come from the defaults tables, so
profiles need no migration (as with `dial.slice.gap`). Diagnostics' pad and dial look lines print the
look and strength.

## Art (generated, white light and black shade on transparent)

| File | Size | Used by |
|---|---|---|
| `shine-pad-<look>.tga` (gloss, orb, frost, fluid, bevel, rim) | 128² | one per pad button, over the icon |
| `shine-pad-fluid-bloom1/2.tga` | 128² | Fluid glass's two tinted bloom layers |
| `shine-dial-gloss.tga`, `-bevel.tga`, `-fluid-bloom1/2.tga` | 128² | the whole disc, cut to each slice by a mask |
| `shine-edge-rim-<n>.tga`, n = 1..12 | 256² | each slice's own thin rim, shaped exactly like `dial-sector-<n>.tga` |
| `shine-edge-soft-<n>.tga`, n = 1..12 | 128² | each slice's soft edge falloff (Glass orb's shade, Rim light's glow) |
| `shine-spot.tga`, `shine-glow.tga`, `shine-streak.tga` | small | Glass orb's highlight and inner glow, Frosted glass's streak |

About 4.7 MB in all, on top of today's 2.8 MB of slice textures. White pixels add light and black
pixels add shade, so one texture can do both. The client draws them in BLEND mode; SetVertexColor's
color tints the light (shade stays black) and its alpha is Strength.

## Pads

- One new texture per button (`btn.qcShine`), anchored with SetAllPoints to the icon, so it follows
  the icon's size and inset.
- Layer: ARTWORK at a sublevel above the icon. It stays below the OVERLAY marks (the lock, the label
  and the send flash) and below the HIGHLIGHT hover, so those read the same as today.
- Fluid glass adds two more textures (the blooms), created only when that look is chosen.
- Painted in the pad's render pass (Pad_Render), from R.Look's new `shine` table.

## Dial slices

- Each slice gets an overlay set, placed by the same `place()` helper as its fill (Dial_Slices). It
  therefore follows the slice gap, the W/E layouts and every slice count.
- Layer: BACKGROUND, above the fill and the hover highlight. The icons sit on the wedge buttons
  above, so they are never covered.
- Per look:
  - **Gloss cap:** the disc gloss, masked by the slice's sector, plus its rim at 30%.
  - **Glass orb:** soft edge shade, the glow sprite near the inner end, the spot sprite near the
    outer corner.
  - **Frosted glass:** a flat 9% white wash (WHITE8x8, masked), the rim at 55%, the streak on the
    outer arc.
  - **Fluid glass:** both blooms (masked, tinted) plus the rim at 35%.
  - **Bevel:** the disc shade, not rotated (one light direction for the whole dial; only the mask
    turns), plus each slice's rim tinted light or dark by which way the slice faces.
  - **Rim light:** soft edge glow plus the rim at 60%.
- **Masks:** a MaskTexture per slice, using that slice's sector texture and placed and turned like
  the fill. It is created once per slice and reused.
- **Sprites:** positioned in the slice's own frame (a local x/y turned by the slice's middle angle),
  the same math as the wedge centers.
- **One slice (n = 1):** the round mask and `shine-edge-*-1` (a full-disc rim).

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
- Pads: the shine texture exists, sits at the right layer and sublevel, uses the chosen file, tint
  and alpha, and is hidden at None. Fluid glass's blooms exist only for Fluid glass.
- Dial: per look, the overlay set per slice. Masks follow the slice's place and rotation, including
  with gap 8 and fixed 4 with two items (W/E). Bevel's disc texture is not rotated. Sprites sit at
  their local positions turned by the slice. Nothing is created at None.
- Independence: the pad set to orb and the dial set to none (and the reverse) each paint only their
  own.
- A generator check: the TOC-relative paths the code names all exist under media/textures.

## Smoke tests (in game)

- Each look on a pad and on a dial, at icon sizes 24, 40 and 128, and with a slice gap of 0 and 8.
- **A turned MaskTexture cuts the Bevel and Gloss discs cleanly at every slice place.** This is the
  one client behaviour not yet seen in game. Fallback: per-slice-count masked textures for Bevel and
  Gloss (about 2.8 MB more), or Bevel uses only its rim.
- Readability: Frosted glass and Fluid glass at full strength on busy icons; the Strength default may
  drop if needed.

## Builder's calls (owner may override)

- Look, Strength and Tint per pad and per dial. There is no global setting, because every other look
  setting is per member.
- The dial's shine sits under the icons and the pad's sits over them (the action-bar convention).
- The default Strength is 85%.
- Satin sheen is dropped, and so is its letter: the looks keep their mockup letters A–E and G.
