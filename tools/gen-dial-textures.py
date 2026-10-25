#!/usr/bin/env python3
"""Write the Comms Dial's slice and page-indicator textures (layout-§1: a dev-only generator).

    python3 tools/gen-dial-textures.py

Writes, under media/textures/dial/ (only this addon draws them, so they are not library assets):

  dial-sector-<n>.tga   n = 2..12: one slice of an n-slice dial, white on transparent, its apex at
                        the image's center and its middle on the up axis; modules/Dial_Slices.lua
                        tints it and turns it onto its wedge (SetRotation about the center). One
                        slice is the whole disc, drawn with dial-disc.tga instead.
  dial-disc.tga         every filled circle the dial draws (the hub's backdrop and circle, Target's
                        dot, the page dots, the arrow plates, the wedges' veils, the one-slice dial),
                        and, cut in halves by texcoords, the round caps of the current page's pill,
                        the indicators' background and their borders: 256 px across.
  dial-ring-<k>.tga     k = 1..12: a hollow ring, its outer edge at the image's edge and its line
                        RING_STEPS[k] of its diameter (a geometric ladder from 1.25% to 50%,
                        0.0125 * 40 ^ ((k - 1) / 11)); modules/Dial_Render.lua's R.RingTexture picks
                        the step nearest a ring's line over its diameter: 128 px across.

Edges are antialiased by supersampling. Each file is overwritten whole; edit this script, never the
output.
"""
import math
import os
import sys

from PIL import Image

SIZE = 256          # a sector's side, in pixels (the dial is drawn at up to ~450 px across)
DISC = 256          # the disc's side: it also draws the one-slice dial
RING = 128          # a ring's side (a hub is at most 80 px, a dot at most 20 px)
RING_STEPS = [0.0125 * (40 ** ((k - 1) / 11)) for k in range(1, 13)]   # line / diameter, as Lua's R.RING_STEPS
SUPER = 4           # samples per pixel side
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, "media", "textures", "dial")


def sector(n):
    half = math.pi / n
    big = Image.new("L", (SIZE * SUPER, SIZE * SUPER), 0)
    px = big.load()
    c = SIZE * SUPER / 2
    r2 = c * c
    for y in range(SIZE * SUPER):
        dy = c - (y + 0.5)              # up is positive
        for x in range(SIZE * SUPER):
            dx = (x + 0.5) - c
            if dx * dx + dy * dy > r2:
                continue
            if abs(math.atan2(dx, dy)) <= half:   # clockwise from up, as the dial measures
                px[x, y] = 255
    return big.resize((SIZE, SIZE), Image.LANCZOS)


def annulus(side, inner):
    """A white ring `side` px across on transparent: its outer radius the image's half, its inner
    radius `inner` of that (0 is the filled disc)."""
    n = side * SUPER
    big = Image.new("L", (n, n), 0)
    px = big.load()
    c = n / 2
    r2, i2 = c * c, (c * inner) ** 2
    for y in range(n):
        dy = (y + 0.5) - c
        for x in range(n):
            dx = (x + 0.5) - c
            d2 = dx * dx + dy * dy
            if i2 <= d2 <= r2:
                px[x, y] = 255
    return big.resize((side, side), Image.LANCZOS)


def disc():
    return annulus(DISC, 0)


def ring(frac):
    return annulus(RING, 1 - 2 * frac)


def save(alpha, name):
    img = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
    img.putalpha(alpha)
    path = os.path.join(OUT, name)
    img.save(path, format="TGA", rle=False)
    print("wrote", os.path.relpath(path))


def main():
    os.makedirs(OUT, exist_ok=True)
    for n in range(2, 13):
        save(sector(n), "dial-sector-%d.tga" % n)
    save(disc(), "dial-disc.tga")
    for k, frac in enumerate(RING_STEPS, start=1):
        save(ring(frac), "dial-ring-%d.tga" % k)
    return 0


if __name__ == "__main__":
    sys.exit(main())
