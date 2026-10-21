#!/usr/bin/env python3
"""Write the shine overlays for pad buttons and dial slices (a dev-only generator, like gen-dial-textures.py).

    python3 tools/gen-shine-textures.py [out_dir]

Every texture is light and shade on transparent: white pixels add light, black pixels add shade, and
alpha is how much. The addon draws them with the BLEND mode, tints them with SetVertexColor (the
tint colors the light; shade stays black) and fades them by the Strength setting (the vertex alpha).

Looks: gloss (Gloss cap), glossfade (Gloss fade), orb (Glass orb), frost (Frosted glass), fluid
(Fluid glass), bevel (Bevel), rim (Rim light).

  shine-pad-<look>.tga        128 x 128, over a whole pad button in three pieces (modules/Shine.lua:
                              the left half as a cap, the middle column stretched, the right half),
                              so every edge drawn here stays as thin on a wide button as on a square.
  shine-pad-fluid-bloom1.tga  Fluid glass's two bloom layers, white on transparent, each tinted by
  shine-pad-fluid-bloom2.tga  its own bloom color.
  shine-dial-<name>.tga       the whole disc (gloss, glossfade, frost 256 x 256, rim; 128 x 128 otherwise). A
                              slice draws one masked by its own sector texture (dial-sector-<n>.tga
                              as a MaskTexture), placed and turned like the fill, so one texture
                              serves every slice count.
  shine-edge-rim-<n>.tga      n = 1..12, 256 x 256: each slice's own rim, about one texel, shaped
                              exactly like dial-sector-<n>.tga (n = 1 is the whole disc's rim).
  shine-edge-streak-<n>.tga   n = 1..12, 256 x 256: Frosted glass's line of light along one spoke.
  shine-edge-bevel-<n>.tga    n = 1..12, 256 x 256: Bevel's raised edges and face shade, in the
                              slice's own frame, so every slice wears the same bevel.
  shine-bead.tga              128 x 128, Glass orb's bulge (a dome of light and a vignette; square,
                              so a turn keeps its shape).
  shine-fluid-bloom1.tga      128 x 128, Fluid glass's two blooms on a slice's outer part, each tinted
  shine-fluid-bloom2.tga      by its own bloom color.

Each dial recipe is the spec's "Dial slices"; tools/render-shine-preview.py renders what the
addon draws with these files, to check a change against the mockup before an in-game pass.

modules/Shine.lua (NS.Shine) names every file. They are written under media/textures/ (only this
addon draws them, so they are not library assets); the generator is not loaded by the client, and
.pkgmeta ignores tools/.

Antialiased by supersampling. Each file is overwritten whole; edit this script, never the output.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

SUPER = 4
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, "media", "textures")


def clamp(x, lo=0.0, hi=1.0):
    return np.clip(x, lo, hi)


def ramp(x, a, b):
    """0 at a, 1 at b, linear between (a > b runs the other way)."""
    return clamp((x - a) / (b - a))


class Canvas:
    """Straight-alpha layers composited with 'over', in a supersampled grid."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        W, H = w * SUPER, h * SUPER
        ys, xs = np.mgrid[0:H, 0:W].astype(np.float64)
        self.u = (xs + 0.5) / W          # 0..1, left to right
        self.v = (ys + 0.5) / H          # 0..1, top to bottom
        self.x = self.u * 2 - 1          # -1..1, the disc's frame
        self.y = self.v * 2 - 1
        self.r = np.sqrt(self.x ** 2 + self.y ** 2)
        self.c = np.zeros((H, W))        # gray: 0 black .. 1 white
        self.a = np.zeros((H, W))

    def paint(self, gray, alpha):
        alpha = clamp(alpha)
        out_a = alpha + self.a * (1 - alpha)
        with np.errstate(invalid="ignore", divide="ignore"):
            self.c = np.where(out_a > 0, (gray * alpha + self.c * self.a * (1 - alpha)) / out_a, 0)
        self.a = out_a

    def light(self, alpha):
        self.paint(1.0, alpha)

    def shade(self, alpha):
        self.paint(0.0, alpha)

    def image(self):
        H, W = self.h, self.w
        pre = (self.c * self.a).reshape(H, SUPER, W, SUPER).mean(axis=(1, 3))
        a = self.a.reshape(H, SUPER, W, SUPER).mean(axis=(1, 3))
        with np.errstate(invalid="ignore", divide="ignore"):
            g = np.where(a > 0, pre / a, 0)
        rgba = np.dstack([g, g, g, a])
        return Image.fromarray((clamp(rgba) * 255 + 0.5).astype(np.uint8), "RGBA")


def ellipse_q(cv, cx, cy, rx, ry, deg=0.0):
    """Normalized distance from an ellipse's center (1 on its edge), in u,v units."""
    t = math.radians(deg)
    dx, dy = cv.u - cx, cv.v - cy
    ex = dx * math.cos(t) + dy * math.sin(t)
    ey = -dx * math.sin(t) + dy * math.cos(t)
    return np.sqrt((ex / rx) ** 2 + (ey / ry) ** 2)


def edge(cv):
    return np.minimum(np.minimum(cv.u, 1 - cv.u), np.minimum(cv.v, 1 - cv.v))


# ── pad buttons (128 x 128) ─────────────────────────────────────────────────────────────────────

def pad_gloss(cv):
    bound = 0.42 + 0.09 * (1 - (2 * cv.u - 1) ** 2)
    inside = clamp((bound - cv.v) * 128 / 1.0)          # a one-pixel soft lower edge
    cv.light(inside * (0.7 + (0.15 - 0.7) * clamp(cv.v / bound)))


def smooth(x, a, b):
    """Smoothstep: 0 at a, 1 at b, eased at both ends (a > b runs the other way)."""
    t = ramp(x, a, b)
    return t * t * (3 - 2 * t)


def pad_glossfade(cv):
    # Gloss fade (owner, 2026-10-21): Gloss cap's light with no cap edge, one smooth gradient, brightest
    # at the top edge and fading to nothing toward the bottom.
    cv.light(0.62 * smooth(cv.v, 0.92, 0.0) ** 1.5)


def pad_orb(cv):
    # A glass bead with no specular dots (owner, 2026-10-21): the button bulges by its shading alone,
    # a soft band of light across its upper third, dark toward every edge and darkest at the bottom.
    e = edge(cv)
    cv.shade(0.5 * smooth(e, 0.22, 0.0))
    cv.shade(0.3 * smooth(cv.v, 0.5, 1.0))
    cv.light(0.34 * np.exp(-((cv.v - 0.3) / 0.13) ** 2) * smooth(e, 0.0, 0.12))


def pad_frost(cv):
    # A milky wash, milkier toward the edges, a crisp bright rim (brightest along the top) and a soft
    # streak of light just under the top edge (owner, 2026-10-21: the rework).
    e = edge(cv)
    cv.light(0.1 + 0.12 * smooth(e, 0.3, 0.0))
    cv.light(0.22 * np.exp(-((cv.v - 0.17) / 0.06) ** 2) * smooth(np.abs(cv.u - 0.5), 0.5, 0.2))
    rim = ramp(e, 0.03, 0.018) * ramp(e, 0.0, 0.006)
    cv.light(rim * (0.55 + 0.35 * ramp(cv.v, 0.5, 0.0)))


def pad_fluid(cv):
    cv.light(0.28 * ramp(cv.v, 0.42, 0.0))
    e = edge(cv)
    cv.light(0.35 * ramp(e, 0.03, 0.015))


def pad_fluid_bloom1(cv):
    cv.light(0.32 * ramp(cv.v, 0.46, 0.74) * ramp(cv.v, 1.02, 0.86))


def pad_fluid_bloom2(cv):
    cv.light(0.5 * ramp(cv.v, 0.68, 1.0))


def pad_bevel(cv):
    t = (cv.u + cv.v) / 2
    cv.light(0.18 * ramp(t, 0.5, 0.0))
    cv.shade(0.22 * ramp(t, 0.5, 1.0))
    w = 0.048
    lit = ((cv.u < w) | (cv.v < w)) & (cv.u + cv.v < 1)
    dark = ((cv.u > 1 - w) | (cv.v > 1 - w)) & (cv.u + cv.v >= 1)
    cv.light(np.where(lit, 0.65, 0.0))
    cv.shade(np.where(dark, 0.65, 0.0))


def pad_rim(cv):
    d = np.sqrt((cv.u - 0.5) ** 2 + (cv.v - 0.5) ** 2) / 0.72
    cv.light(0.4 * ramp(d, 0.72, 1.0))
    top = ramp(cv.v, 0.04, 0.02) * ramp(np.abs(cv.u - 0.5), 0.36, 0.3)
    cv.light(0.85 * top)


# ── dial slices ─────────────────────────────────────────────────────────────────────────────────
# Each recipe is the approved mockup's SVG (docs/superpowers/specs/2026-10-21-shine-overlay-design.md
# names it), drawn on a disc of radius 1 instead of the mockup's 100.
#
# Disc textures (the whole disc, centered, up the slice's outward axis): a slice draws one masked by
# its own sector texture, placed like its fill, so one texture serves every slice count. Edge
# textures (one per slice count, shaped exactly like dial-sector-<n>.tga: apex at the center, middle
# on the up axis) give each slice its own rim and Frosted glass's streak along its own arc.

def disc_cut(cv):
    return ramp(cv.r, 1.0, 0.985)                        # nothing past the disc's edge


def up(cv):
    return -cv.y                                         # along the slice's outward axis


def dial_gloss(cv):
    # a-ring: nothing to 0.55, 0.42 at 0.57, falling to 0.1 at the rim
    band = ramp(cv.r, 0.55, 0.57) * (0.42 + (0.1 - 0.42) * ramp(cv.r, 0.57, 1.0))
    cv.light(band * disc_cut(cv))


def dial_glossfade(cv):
    # Gloss fade (owner, 2026-10-21): the same per-slice gloss as Gloss cap with no falloff edge, one
    # smooth radial gradient, nothing at the slice's inner end (the hub's edge) rising to its brightest
    # at the rim.
    cv.light(0.5 * smooth(cv.r, 0.18, 1.0) ** 1.4 * disc_cut(cv))


def dial_frost(cv):
    # The frosted wash (owner, 2026-10-21: the rework): milky, thin over the hub and milkier toward the
    # rim, and a crisp bright line on the outer arc (the slice's mask keeps only its own arc of it).
    cv.light((0.05 + 0.13 * smooth(cv.r, 0.2, 1.0)) * disc_cut(cv))
    cv.light(0.85 * ramp(np.abs(cv.r - 0.982), 0.011, 0.005) * disc_cut(cv))


def dial_rim(cv):
    # g-srim: nothing to 0.82, rising to the rim (the recipe's level is the mockup's 0.3)
    cv.light(ramp(cv.r, 0.82, 1.0) * disc_cut(cv))


def sector_edge(cv, n):
    """Distance (in disc radii) from a point inside slice 1 of n to the slice's nearest edge, and
    whether the point is inside it."""
    half = math.pi / n
    phi = np.arctan2(cv.x, -cv.y)                        # clockwise from up
    inside = (cv.r <= 1) & (np.abs(phi) <= half)
    side = np.where(half - np.abs(phi) < math.pi / 2, cv.r * np.sin(np.maximum(half - np.abs(phi), 0)), cv.r)
    e = np.minimum(1 - cv.r, side) if n > 1 else 1 - cv.r
    return e, (inside if n > 1 else cv.r <= 1)


def edge_rim(n):
    # The slice's own outline, about one texel (a 1 px line at the stock dial, 284 px across): with its
    # neighbour's it reads as the mockup's 1.2 px stroke along the shared edge.
    def draw(cv):
        e, inside = sector_edge(cv, n)
        line = ramp(e, 0.013, 0.007) * ramp(e, 0.0, 0.002)
        cv.light(np.where(inside, line, 0) * ramp(cv.r, 0.14, 0.28))
    return draw


def edge_streak(n):
    # Frosted glass's streak (owner, 2026-10-21: the rework): a soft line of light just inside the
    # slice's left spoke, at the same angle off it on every count (about 4.3 degrees, so it widens a
    # little toward the rim as the slice does), fading in from the hub and out before the arc, so it
    # reads as light caught along one edge of the glass.
    def draw(cv):
        half = math.pi / n
        phi = np.arctan2(cv.x, -cv.y)
        off = np.sin(np.clip(phi + half, 0, math.pi / 2))        # the left spoke's distance / r
        band = np.exp(-((off - 0.075) / 0.024) ** 2) if n > 1 else np.exp(-((cv.x + cv.y + 0.9) / 0.18) ** 2)
        inside = (np.abs(phi) <= half) if n > 1 else (cv.r <= 1)
        cv.light(np.where(inside, 0.42 * band * smooth(cv.r, 0.3, 0.6) * smooth(cv.r, 0.96, 0.82), 0))
    return draw


BEVEL_W = 0.045


def edge_bevel(n):
    # Bevel (owner, 2026-10-21: the same on every slice, in the slice's own frame): light on the outer
    # arc and the left spoke, dark on the right spoke and the inner end, each strongest at the edge and
    # easing inward, mitred where two meet (the nearest edge wins), over a gentle shade from light at
    # the outer left to dark at the inner right, so each slice reads raised. Drawn as the fill is drawn
    # and turned with it, so every slice wears the same bevel.
    def draw(cv):
        half = math.pi / n
        phi = np.arctan2(cv.x, -cv.y)
        inside = ((np.abs(phi) <= half) if n > 1 else np.ones_like(cv.r, bool)) & (cv.r <= 1)
        inner = 0.17
        d_arc = 1 - cv.r
        d_in = cv.r - inner
        if n > 1:
            d_l = cv.r * np.sin(np.clip(half + phi, 0, math.pi / 2))
            d_r = cv.r * np.sin(np.clip(half - phi, 0, math.pi / 2))
            q = (phi + half) / (2 * half)
        else:
            d_l = d_r = np.full_like(cv.r, 9.0)
            q = clamp((cv.x - cv.y) / 2.8 + 0.5)
        dmin = np.minimum(np.minimum(d_arc, d_in), np.minimum(d_l, d_r))
        lit = (d_arc <= dmin) | (d_l <= dmin)
        if n == 1:
            lit = (cv.x + cv.y) < 0
        w = BEVEL_W
        band = clamp(1 - dmin / w) ** 0.8 * ramp(dmin, -0.004, 0.003)
        face = (1 - q) * 0.5 + ramp(cv.r, inner, 1.0) * 0.5          # 1 outer left .. 0 inner right
        fade = ramp(cv.r, inner - 0.03, inner)
        keep = np.where(inside, fade, 0)
        cv.paint(np.where(face > 0.5, 1.0, 0.0), np.abs(face - 0.5) * 0.28 * keep)
        cv.paint(np.where(lit, 1.0, 0.0), np.where(lit, 0.6, 0.7) * band * keep)
    return draw


# ── sprites ─────────────────────────────────────────────────────────────────────────────────────
# Square, their shape inside the inscribed circle, so a sprite turned to any angle keeps all of it.

# Fluid glass (owner, 2026-10-21: the redesign): one slice's outer part in a soft pink to mint
# gradient across it, low contrast, a sprite as wide as the slice's chord at the rim and set on its
# outer edge (DialSlices.FluidSprites), the slice's mask cutting it to the slice. The two blooms carry
# the gradient's two colors, each tinted by its bloom color; together they cross-fade at a constant
# total (bloom 1 drawn first, then bloom 2 over it), so no stripe is muddier than another. Clear at
# the sprite's bottom (toward the hub), rising to FLUID_PEAK at its top (the rim).
FLUID_PEAK = 0.6


def fluid_split(cv):
    t = smooth(np.abs(cv.u - 0.5), 0.05, 0.42)           # 0 at the slice's middle .. 1 at its spokes
    total = FLUID_PEAK * smooth(1 - cv.v, 0.35, 1.0) ** 2.5
    a2 = total * t
    a1 = total * (1 - t) / np.maximum(1 - a2, 1e-6)
    return a1, a2


def fluid_bloom1(cv):
    a1, _ = fluid_split(cv)
    cv.light(a1)


def fluid_bloom2(cv):
    _, a2 = fluid_split(cv)
    cv.light(a2)


def bead(cv):
    # b-svig: a slice's bulge. Clear to 0.6 of the vignette's radius, black 0.45 at it and past it to
    # the sprite's edge; the vignette's radius is 0.4 of the sprite's half side, so a sprite 3.5 times
    # the slice's inscribed radius across its half covers the slice from its apex to its corners.
    # With no specular dots (owner, 2026-10-21) the bulge is the shading alone: past the vignette it is
    # black 0.5, and inside it a broad dome of light, brightest a little toward the rim and fading
    # long before the bead's edge, so the slice reads lit in its middle and dark at its edges. The
    # recipe tints it with the shine's tint (the shade stays black).
    d = np.sqrt((cv.u - 0.5) ** 2 + (cv.v - 0.5) ** 2) / 0.5 / 0.4
    cv.shade(0.5 * smooth(d, 0.55, 1.0))
    dome = np.sqrt((cv.u - 0.5) ** 2 + (cv.v - 0.47) ** 2) / 0.5 / 0.4
    cv.light(0.12 * smooth(dome, 0.9, 0.0))


TEXTURES = [
    ("shine-pad-gloss.tga", 128, 128, pad_gloss),
    ("shine-pad-glossfade.tga", 128, 128, pad_glossfade),
    ("shine-pad-orb.tga", 128, 128, pad_orb),
    ("shine-pad-frost.tga", 128, 128, pad_frost),
    ("shine-pad-fluid.tga", 128, 128, pad_fluid),
    ("shine-pad-fluid-bloom1.tga", 128, 128, pad_fluid_bloom1),
    ("shine-pad-fluid-bloom2.tga", 128, 128, pad_fluid_bloom2),
    ("shine-pad-bevel.tga", 128, 128, pad_bevel),
    ("shine-pad-rim.tga", 128, 128, pad_rim),
    ("shine-dial-gloss.tga", 128, 128, dial_gloss),
    ("shine-dial-glossfade.tga", 128, 128, dial_glossfade),
    ("shine-dial-frost.tga", 256, 256, dial_frost),
    ("shine-dial-rim.tga", 128, 128, dial_rim),
    ("shine-bead.tga", 128, 128, bead),
    ("shine-fluid-bloom1.tga", 128, 128, fluid_bloom1),
    ("shine-fluid-bloom2.tga", 128, 128, fluid_bloom2),
] + [("shine-edge-rim-%d.tga" % n, 256, 256, edge_rim(n)) for n in range(1, 13)] \
  + [("shine-edge-streak-%d.tga" % n, 256, 256, edge_streak(n)) for n in range(1, 13)] \
  + [("shine-edge-bevel-%d.tga" % n, 256, 256, edge_bevel(n)) for n in range(1, 13)]

# Files an earlier version wrote; main() removes them.
RETIRED = ["shine-streak.tga", "shine-spot.tga", "shine-glow.tga", "shine-dial-bevel.tga",
           "shine-dial-bevel-edge.tga", "shine-dial-fluid-bloom1.tga", "shine-dial-fluid-bloom2.tga"] \
    + ["shine-edge-soft-%d.tga" % n for n in range(1, 13)]


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else OUT
    os.makedirs(out, exist_ok=True)
    for name, w, h, draw in TEXTURES:
        cv = Canvas(w, h)
        draw(cv)
        path = os.path.join(out, name)
        cv.image().save(path, format="TGA", rle=False)
        print("wrote", path)
    for name in RETIRED:
        path = os.path.join(out, name)
        if os.path.exists(path):
            os.remove(path)
            print("removed", path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
