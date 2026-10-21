#!/usr/bin/env python3
"""Composite the generated shine textures onto a sample pad and dial the way the client draws them:
BLEND mode, SetVertexColor tint (rgb) and Strength (alpha), a slice's overlay masked by its sector."""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

TEX, SECTORS, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
STRENGTH = 0.85
SCENE = (43, 35, 64)
SS = 4


def load(name, folder=TEX):
    return Image.open(os.path.join(folder, name)).convert("RGBA")


def tinted(img, rgb=(255, 255, 255), alpha=1.0, size=None):
    if size:
        img = img.resize(size, Image.LANCZOS)
    a = np.asarray(img).astype(np.float64) / 255
    a[..., 0] *= rgb[0] / 255
    a[..., 1] *= rgb[1] / 255
    a[..., 2] *= rgb[2] / 255
    a[..., 3] *= alpha
    return Image.fromarray((a * 255 + 0.5).astype(np.uint8), "RGBA")


def masked(img, mask):
    a = np.asarray(img).astype(np.float64)
    m = np.asarray(mask.convert("RGBA")).astype(np.float64)[..., 3] / 255
    a[..., 3] *= m
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def put(dst, img, cx, cy):
    dst.alpha_composite(img, (int(round(cx - img.width / 2)), int(round(cy - img.height / 2))))


TILES = {"O": ((255, 177, 92), (194, 65, 12)), "T": ((95, 224, 214), (15, 118, 110)),
         "V": ((182, 155, 255), (91, 60, 196)), "G": ((155, 227, 122), (63, 125, 38))}


def tile(kind, size):
    S = size * SS
    a, b = TILES[kind]
    yy, xx = np.mgrid[0:S, 0:S] / (S - 1)
    t = (xx + yy) / 2
    rgb = np.dstack([a[i] + (b[i] - a[i]) * t for i in range(3)])
    img = Image.fromarray(np.dstack([rgb, np.full((S, S), 255)]).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img)
    k = S / 52
    w = int(4 * k)
    if kind == "O":
        d.line([(26 * k, 13 * k), (26 * k, 31 * k)], fill="white", width=w)
        d.ellipse([(23.2 * k, 37.2 * k), (28.8 * k, 42.8 * k)], fill="white")
    elif kind == "T":
        d.ellipse([(15 * k, 15 * k), (37 * k, 37 * k)], outline="white", width=int(3 * k))
        for seg in [((26, 8), (26, 16)), ((26, 36), (26, 44)), ((8, 26), (16, 26)), ((36, 26), (44, 26))]:
            d.line([(p[0] * k, p[1] * k) for p in seg], fill="white", width=int(3 * k))
    elif kind == "V":
        d.line([(26 * k, 39 * k), (26 * k, 14 * k)], fill="white", width=w)
        d.line([(15 * k, 25 * k), (26 * k, 14 * k), (37 * k, 25 * k)], fill="white", width=w, joint="curve")
    else:
        pts = [(26, 11), (38, 16), (38, 27), (33, 36), (26, 42), (19, 36), (14, 27), (14, 16), (26, 11)]
        d.line([(p[0] * k, p[1] * k) for p in pts], fill="white", width=int(3 * k), joint="curve")
    return img.resize((size, size), Image.LANCZOS)


def disc_img(D, rgb, a):
    S = D * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(img).ellipse([(0, 0), (S - 1, S - 1)], fill=rgb + (int(a * 255),))
    return img.resize((D, D), Image.LANCZOS)


def pad(cell, ox, oy, look):
    B, gap = 84, 12
    frame = Image.new("RGBA", (2 * B + gap + 28, 2 * B + gap + 52), (13, 12, 18, 200))
    put(cell, frame, ox + frame.width / 2, oy + frame.height / 2)
    ImageDraw.Draw(cell).text((ox + 12, oy + 10), "Quick Comms - World", fill=(245, 197, 66))
    for i, kind in enumerate("OTVG"):
        x = ox + 14 + (i % 2) * (B + gap)
        y = oy + 38 + (i // 2) * (B + gap)
        btn = tile(kind, B)
        if look:
            btn.alpha_composite(tinted(load("shine-pad-%s.tga" % look), alpha=STRENGTH, size=(B, B)))
            if look == "fluid":
                btn.alpha_composite(tinted(load("shine-pad-fluid-bloom1.tga"), (255, 154, 213), STRENGTH, (B, B)))
                btn.alpha_composite(tinted(load("shine-pad-fluid-bloom2.tga"), (138, 255, 193), STRENGTH, (B, B)))
        cell.alpha_composite(btn, (x, y))


def dial(cell, cx, cy, look, R=130):
    D = 2 * R
    put(cell, disc_img(int(D * 1.04), (11, 10, 16), 0.6), cx, cy)
    sector = load("dial-sector-4.tga", SECTORS).resize((D, D), Image.LANCZOS)
    for j, deg in enumerate([270, 0, 90, 180]):
        a = math.radians(deg)
        mask = sector.rotate(-deg, resample=Image.BICUBIC)
        hover = deg == 0
        fill = tinted(mask, (59, 53, 82) if hover else (29, 27, 38), 0.95 if hover else 0.9)
        put(cell, fill, cx, cy)
        if look:
            W = (255, 255, 255)
            rim = load("shine-edge-rim-4.tga").resize((D, D), Image.LANCZOS).rotate(-deg, resample=Image.BICUBIC)
            soft = load("shine-edge-soft-4.tga").resize((D, D), Image.LANCZOS).rotate(-deg, resample=Image.BICUBIC)

            def disc(name, rgb=W, al=1.0):
                put(cell, masked(tinted(load(name), rgb, STRENGTH * al, (D, D)), mask), cx, cy)

            def edge(img, rgb, al):
                put(cell, tinted(img, rgb, STRENGTH * al), cx, cy)

            def local(lx, ly):
                return (cx + (lx * math.cos(a) - ly * math.sin(a)) * R, cy + (lx * math.sin(a) + ly * math.cos(a)) * R)

            def sprite(name, w, h, lx, ly, rot, al=1.0):
                s = tinted(load(name), alpha=STRENGTH * al, size=(int(w * R), max(4, int(h * R))))
                put(cell, s.rotate(rot - deg, expand=True, resample=Image.BICUBIC), *local(lx, ly))
            if look == "gloss":
                disc("shine-dial-gloss.tga")
                edge(rim, W, 0.3)
            elif look == "orb":
                edge(soft, (0, 0, 0), 0.5)
                sprite("shine-glow.tga", 0.5, 0.2, 0, -0.38, 0, 0.45)
                sprite("shine-spot.tga", 0.34, 0.12, -0.24, -0.80, 22)
            elif look == "frost":
                put(cell, masked(Image.new("RGBA", (D, D), (255, 255, 255, int(255 * 0.09 * STRENGTH))), mask), cx, cy)
                edge(rim, W, 0.55)
                sprite("shine-streak.tga", 0.68, 0.05, 0, -0.95, 0)
            elif look == "fluid":
                disc("shine-dial-fluid-bloom1.tga", (255, 154, 213))
                disc("shine-dial-fluid-bloom2.tga", (138, 255, 193))
                edge(rim, W, 0.35)
            elif look == "bevel":
                disc("shine-dial-bevel.tga")
                k = math.cos(a - math.radians(315))
                edge(rim, W if k >= 0 else (0, 0, 0), (0.25 + 0.45 * abs(k)))
            elif look == "rim":
                edge(soft, W, 0.35)
                edge(rim, W, 0.6)
    for kind, (lx, ly) in zip("OTVG", [(-0.62, 0), (0, -0.62), (0.62, 0), (0, 0.62)]):
        put(cell, tile(kind, int(0.30 * R)), cx + lx * R, cy + ly * R)
    put(cell, disc_img(int(0.40 * R), (30, 30, 36), 0.95), cx, cy)
    put(cell, disc_img(int(0.22 * R), (245, 197, 66), 1.0), cx, cy)


LOOKS = [(None, "Today (no overlay)"), ("gloss", "A. Gloss cap"), ("orb", "B. Glass orb"),
         ("frost", "C. Frosted glass"), ("fluid", "D. Fluid glass"), ("bevel", "E. Bevel"), ("rim", "G. Rim light")]
CW, CH = 560, 330
cols = 4
sheet = Image.new("RGBA", (CW * cols + 20, CH * 2 + 20), (23, 20, 31, 255))
try:
    font = ImageFont.truetype("DejaVuSans-Bold.ttf", 18)
except OSError:
    font = ImageFont.load_default()
for i, (look, title) in enumerate(LOOKS):
    cell = Image.new("RGBA", (CW - 20, CH - 20), SCENE + (255,))
    pad(cell, 14, 40, look)
    dial(cell, 390, 170, look)
    ImageDraw.Draw(cell).text((14, 10), title, fill=(236, 232, 245), font=font)
    sheet.alpha_composite(cell, (20 + (i % cols) * CW, 20 + (i // cols) * CH))
sheet.convert("RGB").save(OUT)
print("wrote", OUT)
