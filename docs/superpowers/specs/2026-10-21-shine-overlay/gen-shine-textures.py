#!/usr/bin/env python3
"""Write the shine overlays for pad buttons and dial slices (a dev-only generator, like gen-dial-textures.py).

    python3 tools/gen-shine-textures.py [out_dir]

Every texture is light and shade on transparent: white pixels add light, black pixels add shade, and
alpha is how much. The addon draws them with the BLEND mode, tints them with SetVertexColor (the
tint colors the light; shade stays black) and fades them by the Strength setting (the vertex alpha).

Looks: gloss (Gloss cap), orb (Glass orb), frost (Frosted glass), fluid (Fluid glass), bevel (Bevel),
rim (Rim light).

  shine-pad-<look>.tga        128 x 128, over a pad button's icon (SetAllPoints on the icon).
  shine-pad-fluid-bloom1.tga  Fluid glass's two bloom layers, white on transparent, each tinted by
  shine-pad-fluid-bloom2.tga  its own bloom color.
  shine-dial-<look>.tga       256 x 256, the whole disc. A slice draws it masked by its own sector
                              texture (dial-sector-<n>.tga as a MaskTexture), placed like the fill,
                              so one texture serves every slice count. Radial looks turn with the
                              slice; bevel's light is fixed (the texture is not rotated, the mask is).
  shine-dial-fluid-bloom1.tga / -bloom2.tga  as on the pad.
  shine-spot.tga              64 x 32, the orb's highlight, placed on each slice.
  shine-streak.tga            128 x 16, the frosted glass's light streak along each slice's rim.

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
# Disc textures (128 x 128, the whole disc, centered): a slice draws one masked by its own sector
# texture, placed like its fill, so one texture serves every slice count. Edge textures (one pair per
# slice count, shaped exactly like dial-sector-<n>.tga: apex at the center, middle on the up axis)
# give each slice its own rim, so neighbouring slices read as separate buttons.

def disc_cut(cv):
    return ramp(cv.r, 1.0, 0.985)                        # nothing past the disc's edge


def dial_gloss(cv):
    band = ramp(cv.r, 0.55, 0.58) * (0.42 + (0.1 - 0.42) * ramp(cv.r, 0.58, 1.0))
    cv.light(band * disc_cut(cv))


def dial_fluid_bloom1(cv):
    cv.light(0.3 * ramp(cv.r, 0.45, 0.78) * ramp(cv.r, 1.05, 0.9) * disc_cut(cv))


def dial_fluid_bloom2(cv):
    cv.light(0.45 * ramp(cv.r, 0.76, 1.0) * disc_cut(cv))


def dial_bevel(cv):
    cut = disc_cut(cv)
    t = clamp(((cv.x + cv.y) / 2 + 0.7) / 1.4)
    cv.light(0.14 * ramp(t, 0.5, 0.0) * cut)
    cv.shade(0.28 * ramp(t, 0.5, 1.0) * cut)


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
    def draw(cv):
        e, inside = sector_edge(cv, n)
        line = ramp(e, 0.032, 0.02) * ramp(e, 0.0, 0.006)
        cv.light(np.where(inside, line, 0) * ramp(cv.r, 0.14, 0.28))
    return draw


def edge_soft(n):
    def draw(cv):
        e, inside = sector_edge(cv, n)
        cv.light(np.where(inside, ramp(e, 0.2, 0.0), 0) * ramp(cv.r, 0.12, 0.3))
    return draw


# ── sprites ─────────────────────────────────────────────────────────────────────────────────────

def spot(cv):
    cv.light(0.95 * clamp(1 - ellipse_q(cv, 0.5, 0.5, 0.5, 0.5)) ** 1.2)


def glow(cv):
    cv.light(clamp(1 - ellipse_q(cv, 0.5, 0.5, 0.5, 0.5)) ** 2)


def streak(cv):
    along = clamp(1 - np.abs(2 * cv.u - 1)) ** 1.5
    cv.light(along * np.exp(-((cv.v - 0.5) / 0.22) ** 2))


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
    ("shine-spot.tga", 64, 32, spot),
    ("shine-glow.tga", 64, 32, glow),
    ("shine-streak.tga", 128, 16, streak),
] + [("shine-edge-rim-%d.tga" % n, 256, 256, edge_rim(n)) for n in range(1, 13)] \
  + [("shine-edge-soft-%d.tga" % n, 128, 128, edge_soft(n)) for n in range(1, 13)
]


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else OUT
    os.makedirs(out, exist_ok=True)
    for name, w, h, draw in TEXTURES:
        cv = Canvas(w, h)
        draw(cv)
        path = os.path.join(out, name)
        cv.image().save(path, format="TGA", rle=False)
        print("wrote", path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
