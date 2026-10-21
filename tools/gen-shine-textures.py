#!/usr/bin/env python3
"""Write the shine overlays for pad buttons and dial slices (a dev-only generator, like gen-dial-textures.py).

    python3 tools/gen-shine-textures.py [out_dir]

Every texture is light and shade on transparent: white pixels add light, black pixels add shade, and
alpha is how much. The addon draws them with the BLEND mode, tints them with SetVertexColor (the
tint colors the light; shade stays black) and fades them by the Strength setting (the vertex alpha).

Looks: gloss (Gloss cap), orb (Glass orb), frost (Frosted glass), fluid (Fluid glass), bevel (Bevel),
rim (Rim light).

  shine-pad-<look>.tga        128 x 128, over a whole pad button in three pieces (modules/Shine.lua:
                              the left half as a cap, the middle column stretched, the right half),
                              so every edge drawn here stays as thin on a wide button as on a square.
  shine-pad-fluid-bloom1.tga  Fluid glass's two bloom layers, white on transparent, each tinted by
  shine-pad-fluid-bloom2.tga  its own bloom color.
  shine-dial-<name>.tga       128 x 128, the whole disc (gloss, bevel, bevel-edge, rim, fluid-bloom1,
                              fluid-bloom2). A slice draws one masked by its own sector texture
                              (dial-sector-<n>.tga as a MaskTexture), placed like the fill, so one
                              texture serves every slice count. The radial looks and the blooms turn
                              with the slice; bevel and bevel-edge are fixed (one light direction for
                              the dial: the texture is not rotated, the masks are), bevel-edge seen
                              through the slice's rim as a second mask.
  shine-edge-rim-<n>.tga      n = 1..12, 256 x 256: each slice's own rim, about one texel, shaped
                              exactly like dial-sector-<n>.tga (n = 1 is the whole disc's rim).
  shine-edge-streak-<n>.tga   n = 1..12, 256 x 256: Frosted glass's streak on each slice's arc.
  shine-spot.tga              64 x 64, the orb's highlight (square: a turn keeps its shape).
  shine-glow.tga              64 x 64, the orb's inner glow.
  shine-bead.tga              128 x 128, the orb's vignette: each slice's bulge.

Each dial recipe is the approved mockup card's SVG; tools/render-shine-preview.py renders what the
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


def pad_orb(cv):
    d = np.sqrt((cv.u - 0.5) ** 2 + (cv.v - 0.45) ** 2) / 0.72
    cv.shade(0.5 * ramp(d, 0.6, 1.0))
    cv.light(0.38 * clamp(1 - ellipse_q(cv, 0.5, 0.865, 0.346, 0.135)))
    cv.light(0.95 * clamp(1 - ellipse_q(cv, 0.31, 0.23, 0.21, 0.115, -25)))


def pad_frost(cv):
    cv.light(np.full_like(cv.u, 0.14))
    e = edge(cv)
    cv.light(0.6 * ramp(e, 0.04, 0.025) * ramp(e, 0.0, 0.012))
    cv.light(clamp(1 - ellipse_q(cv, 0.5, 0.955, 0.31, 0.04)))


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


def diagonal(cv):
    """0 at the disc's top left (-0.7, -0.7) to 1 at its bottom right (0.7, 0.7): the mockup's one
    light direction for the whole dial."""
    return clamp(((cv.x + cv.y) / 2 + 0.7) / 1.4)


def dial_gloss(cv):
    # a-ring: nothing to 0.55, 0.42 at 0.57, falling to 0.1 at the rim
    band = ramp(cv.r, 0.55, 0.57) * (0.42 + (0.1 - 0.42) * ramp(cv.r, 0.57, 1.0))
    cv.light(band * disc_cut(cv))


def stops(t, points):
    """Piecewise linear through (t, value) points."""
    return np.interp(t, [p[0] for p in points], [p[1] for p in points])


# d-siri, along the slice's axis from 0.28 to 1: clear, purple 0.12 at 0.64, pink 0.30 at 0.856,
# green 0.45 at the rim. Bloom 1 (tinted bloom A, pink) carries the purple and pink, bloom 2 (bloom
# B, green) the green; past 0.856 the two cross-fade as the gradient's colors do.
FLUID = [(0.28, 0.0), (0.64, 0.12), (0.856, 0.30), (1.0, 0.45)]


def fluid_split(cv):
    t = up(cv)
    total = stops(t, FLUID) * (t > 0.28)
    green = clamp((t - 0.856) / (1.0 - 0.856))
    a2 = green * total
    a1 = np.where(a2 < 1, (1 - green) * total / np.maximum(1 - a2, 1e-6), 0)
    return a1, a2


def dial_fluid_bloom1(cv):
    a1, _ = fluid_split(cv)
    cv.light(a1 * disc_cut(cv))


def dial_fluid_bloom2(cv):
    _, a2 = fluid_split(cv)
    cv.light(a2 * disc_cut(cv))


def dial_bevel(cv):
    # e-sshade: white at 0.12 to black at 0.25 along the dial's diagonal
    t = diagonal(cv)
    cv.paint(1 - t, (0.12 + 0.13 * t) * disc_cut(cv))


def dial_bevel_edge(cv):
    # e-bev, the slices' outline: white at 0.65 to black at 0.75 along the same diagonal. Drawn through
    # each slice's rim (shine-edge-rim-<n> as a MaskTexture), so the outline shades along its length.
    t = diagonal(cv)
    cv.paint(1 - t, (0.65 + 0.1 * t) * disc_cut(cv))


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
    # c-arc: a 2.4 px stroke on the arc at 0.98, brightest at the slice's middle and gone by 45% of its
    # half-angle (the mockup's +-34 of 70.7 on a quarter), so it keeps its share of every count.
    def draw(cv):
        half = math.pi / n
        phi = np.abs(np.arctan2(cv.x, -cv.y))
        along = clamp(1 - phi / (0.45 * half))
        band = ramp(np.abs(cv.r - 0.98), 0.016, 0.008)
        cv.light(along * band)
    return draw


# ── sprites ─────────────────────────────────────────────────────────────────────────────────────
# Square, their shape inside the inscribed circle, so a sprite turned to any angle keeps all of it.

def spot(cv):
    # b-spec at the mockup's 28 x 10: white 0.95 at the middle to clear at the edge
    cv.light(0.95 * clamp(1 - ellipse_q(cv, 0.5, 0.5, 0.5, 0.5 * 10 / 28)))


def glow(cv):
    # b-glow at 44 x 18 (its level, 0.38, is the recipe's)
    cv.light(clamp(1 - ellipse_q(cv, 0.5, 0.5, 0.5, 0.5 * 18 / 44)))


def bead(cv):
    # b-svig: a slice's bulge. Clear to 0.6 of the vignette's radius, black 0.45 at it and past it to
    # the sprite's edge; the vignette's radius is 0.4 of the sprite's half side, so a sprite 3.5 times
    # the slice's inscribed radius across its half covers the slice from its apex to its corners.
    d = np.sqrt((cv.u - 0.5) ** 2 + (cv.v - 0.5) ** 2) / 0.5 / 0.4
    cv.shade(0.45 * ramp(d, 0.6, 1.0))


TEXTURES = [
    ("shine-pad-gloss.tga", 128, 128, pad_gloss),
    ("shine-pad-orb.tga", 128, 128, pad_orb),
    ("shine-pad-frost.tga", 128, 128, pad_frost),
    ("shine-pad-fluid.tga", 128, 128, pad_fluid),
    ("shine-pad-fluid-bloom1.tga", 128, 128, pad_fluid_bloom1),
    ("shine-pad-fluid-bloom2.tga", 128, 128, pad_fluid_bloom2),
    ("shine-pad-bevel.tga", 128, 128, pad_bevel),
    ("shine-pad-rim.tga", 128, 128, pad_rim),
    ("shine-dial-gloss.tga", 128, 128, dial_gloss),
    ("shine-dial-fluid-bloom1.tga", 128, 128, dial_fluid_bloom1),
    ("shine-dial-fluid-bloom2.tga", 128, 128, dial_fluid_bloom2),
    ("shine-dial-bevel.tga", 128, 128, dial_bevel),
    ("shine-dial-bevel-edge.tga", 128, 128, dial_bevel_edge),
    ("shine-dial-rim.tga", 128, 128, dial_rim),
    ("shine-spot.tga", 64, 64, spot),
    ("shine-glow.tga", 64, 64, glow),
    ("shine-bead.tga", 128, 128, bead),
] + [("shine-edge-rim-%d.tga" % n, 256, 256, edge_rim(n)) for n in range(1, 13)] \
  + [("shine-edge-streak-%d.tga" % n, 256, 256, edge_streak(n)) for n in range(1, 13)]

RETIRED = ["shine-streak.tga"] + ["shine-edge-soft-%d.tga" % n for n in range(1, 13)]


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
