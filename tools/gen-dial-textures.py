#!/usr/bin/env python3
"""Write the Comms Dial's slice and page-indicator textures (layout-§1: a dev-only generator).

    python3 tools/gen-dial-textures.py

Writes, under media/textures/ (only this addon draws them, so they are not library assets):

  dial-sector-<n>.tga   n = 2..12: one slice of an n-slice dial, white on transparent, its apex at
                        the image's center and its middle on the up axis; modules/Dial_Render.lua
                        tints it and turns it onto its wedge (SetRotation about the center). One
                        slice is the whole disc, drawn with the round mask instead.
  dial-pill.tga         the current page's indicator: a white rounded bar, 4:1.

Edges are antialiased by supersampling. Each file is overwritten whole; edit this script, never the
output.
"""
import math
import os
import sys

from PIL import Image

SIZE = 256          # a sector's side, in pixels (the dial is drawn at up to ~450 px across)
SUPER = 4           # samples per pixel side
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, "media", "textures")


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


def pill():
    w, h = 64, 16
    big = Image.new("L", (w * SUPER, h * SUPER), 0)
    px = big.load()
    rad = h * SUPER / 2
    for y in range(h * SUPER):
        for x in range(w * SUPER):
            cx = min(max(x + 0.5, rad), w * SUPER - rad)
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - rad) ** 2 <= rad * rad:
                px[x, y] = 255
    return big.resize((w, h), Image.LANCZOS)


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
    save(pill(), "dial-pill.tga")
    return 0


if __name__ == "__main__":
    sys.exit(main())
