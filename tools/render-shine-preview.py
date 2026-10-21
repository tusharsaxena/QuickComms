#!/usr/bin/env python3
"""Composite the shine overlay the way the client draws it (a dev-only tool; half two of
tools/render-shine-preview.lua).

    python3 tools/render-shine-preview.py [--json dump.json] [--out DIR] [--bg RRGGBB] [--scenes]

Run from the repo root. Without --json it first runs `lua tools/render-shine-preview.lua` (the
addon loaded headless, as the test harness loads it) into a temporary file. It writes, under --out
(default docs/superpowers/specs/2026-10-21-shine-overlay/):

  render-dial-4.png, render-dial-8.png, render-dial-12.png   the stock dial at that many slices, one
                                                             tile per look (None and the six), labeled
  render-pad.png                                             the stock pad's buttons and an icon-only
                                                             pad, one row per look
  --scenes also writes every scene alone (scene-<kind>-<look>-<n>.png).

How it draws, as the client does:
  * Layout: every frame and region is laid out from its recorded anchors (SetPoint, SetAllPoints)
    and sizes, y up, from the dumped root's center.
  * Order: by frame level, then draw layer (BACKGROUND, BORDER, ARTWORK, OVERLAY; HIGHLIGHT is the
    hover and is left out), then sublevel, then creation order.
  * A texture is sampled bilinearly (clamped at its edges) over its rect through its texcoords;
    SetRotation turns the whole quad about the rect's center (counterclockwise, aspect kept): the
    client draws nothing outside the turned quad (a clamped sample there would streak the corners of
    every turned slice, which the client does not). SetColorTexture fills the rect.
  * The vertex color multiplies (its alpha too), as do the region's and its frames' alphas; BLEND is
    alpha "over", ADD adds.
  * A MaskTexture multiplies the alpha of every texture it is attached to by its own alpha, sampled
    in its own rect and rotation; outside its rect it is 0 (CLAMPTOBLACKADDITIVE).
  * Textures are read from the repo (.tga, .png or .blp-less paths under Interface\\AddOns\\QuickComms\\);
    WHITE8x8 is white; any other file (the client's own art) is a gray square.
  * Font strings draw their text in DejaVu Sans at the face's size, in their color.

Render at 2x and downsample, so edges antialias like the client's filtered sampling.
"""
import argparse
import json
import math
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir))
OUT = os.path.join(ROOT, "docs", "superpowers", "specs", "2026-10-21-shine-overlay")
ADDON = "interface\\addons\\quickcomms\\"
SS = 2
LAYERS = {"BACKGROUND": 0, "BORDER": 1, "ARTWORK": 2, "OVERLAY": 3}
LOOK_NAMES = {"none": "None", "gloss": "Gloss cap", "orb": "Glass orb", "frost": "Frosted glass",
              "fluid": "Fluid glass", "bevel": "Bevel", "rim": "Rim light"}
FONT_PATH = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

_cache = {}


def font(size):
    try:
        return ImageFont.truetype(FONT_PATH, size)
    except OSError:
        return ImageFont.load_default()


def load_texture(path):
    """Premultiplied float RGBA (H, W, 4), or None for a gray placeholder."""
    if path in _cache:
        return _cache[path]
    arr = None
    low = path.lower()
    if low.endswith("white8x8"):
        arr = np.ones((8, 8, 4))
    elif low.startswith(ADDON):
        rel = path[len(ADDON):].replace("\\", "/")
        for ext in ("", ".tga", ".png"):
            full = os.path.join(ROOT, rel + ext)
            if os.path.isfile(full):
                img = np.asarray(Image.open(full).convert("RGBA")).astype(np.float64) / 255
                img[..., :3] *= img[..., 3:4]
                arr = img
                break
    _cache[path] = arr
    return arr


def sample(tex, u, v):
    """Bilinear, clamped, at normalized u (right), v (down)."""
    h, w = tex.shape[:2]
    x = np.clip(u * w - 0.5, 0, w - 1)
    y = np.clip(v * h - 0.5, 0, h - 1)
    x0 = np.floor(x).astype(int)
    y0 = np.floor(y).astype(int)
    x1 = np.minimum(x0 + 1, w - 1)
    y1 = np.minimum(y0 + 1, h - 1)
    fx = (x - x0)[..., None]
    fy = (y - y0)[..., None]
    top = tex[y0, x0] * (1 - fx) + tex[y0, x1] * fx
    bot = tex[y1, x0] * (1 - fx) + tex[y1, x1] * fx
    return top * (1 - fy) + bot * fy


H_OF = {"LEFT": -1, "TOPLEFT": -1, "BOTTOMLEFT": -1, "RIGHT": 1, "TOPRIGHT": 1, "BOTTOMRIGHT": 1}
V_OF = {"TOP": 1, "TOPLEFT": 1, "TOPRIGHT": 1, "BOTTOM": -1, "BOTTOMLEFT": -1, "BOTTOMRIGHT": -1}


class Scene:
    def __init__(self, s):
        self.s = s
        self.items = {}
        for f in s["frames"]:
            self.items[f["id"]] = f
        for r in s["regions"]:
            self.items[r["id"]] = r
        self.rects = {}

    def size_of(self, it):
        sz = it.get("size") or []
        w = sz[0] if len(sz) > 0 and sz[0] is not None else None
        h = sz[1] if len(sz) > 1 and sz[1] is not None else None
        return w, h

    def rect(self, rid):
        """(left, bottom, right, top), y up, from the root's center."""
        if rid in self.rects:
            return self.rects[rid]
        it = self.items.get(rid)
        if it is None:
            return (0, 0, 0, 0)
        self.rects[rid] = (0, 0, 0, 0)   # a cycle guard
        w, h = self.size_of(it)
        if rid == self.s["root"]:
            w, h = w or 0, h or 0
            r = (-w / 2, -h / 2, w / 2, h / 2)
        elif it.get("allPoints"):
            r = self.rect(it["allPoints"])
        else:
            pts = it.get("points") or []
            xs, ys = {}, {}
            for p in pts:
                point, rel, relPoint, ox, oy = (p + [None] * 5)[:5]
                rel = rel or it.get("parent") or it.get("frame")
                L, B, R, T = self.rect(rel)
                rp = relPoint or point
                ax = {-1: L, 0: (L + R) / 2, 1: R}[H_OF.get(rp, 0)] + (ox or 0)
                ay = {-1: B, 0: (B + T) / 2, 1: T}[V_OF.get(rp, 0)] + (oy or 0)
                xs[H_OF.get(point, 0)] = ax
                ys[V_OF.get(point, 0)] = ay
            r = (*self.axis(xs, w), *self.axis(ys, h))
            r = (r[0], r[2], r[1], r[3])
        self.rects[rid] = r
        return r

    @staticmethod
    def axis(known, size):
        if -1 in known and 1 in known:
            return known[-1], known[1]
        size = size or 0
        if -1 in known:
            return known[-1], known[-1] + size
        if 1 in known:
            return known[1] - size, known[1]
        c = known.get(0, 0)
        return c - size / 2, c + size / 2

    def frame_alpha(self, fid):
        a = 1.0
        while fid and fid in self.items:
            f = self.items[fid]
            a *= f.get("alpha", 1) or 1
            if fid == self.s["root"]:
                break
            fid = f.get("parent")
        return a

    def level(self, r):
        f = self.items.get(r.get("frame"), {})
        return f.get("level", 0)


def uv_map(region, rect, px, py):
    """Normalized texture u, v (and inside-rect flag) for canvas points px, py (y up)."""
    L, B, R, T = rect
    w, h = max(R - L, 1e-6), max(T - B, 1e-6)
    cx, cy = (L + R) / 2, (B + T) / 2
    dx, dy = px - cx, py - cy
    rot = region.get("rotation") or 0
    c, s = math.cos(-rot), math.sin(-rot)
    ux, uy = dx * c - dy * s, dx * s + dy * c
    u = ux / w + 0.5
    v = 0.5 - uy / h
    inside = (u >= 0) & (u <= 1) & (v >= 0) & (v <= 1)
    tc = region.get("texCoord")
    if tc and len(tc) == 4:
        u = tc[0] + u * (tc[1] - tc[0])
        v = tc[2] + v * (tc[3] - tc[2])
    elif tc and len(tc) == 8:
        ulx, uly, llx, lly, urx, ury, lrx, lry = tc
        tu = ulx * (1 - u) * (1 - v) + urx * u * (1 - v) + llx * (1 - u) * v + lrx * u * v
        tv = uly * (1 - u) * (1 - v) + ury * u * (1 - v) + lly * (1 - u) * v + lry * u * v
        u, v = tu, tv
    return u, v, inside


def bounds(region, rect):
    """The canvas area a region covers: its rect, or a turned quad's bounds."""
    rl, rb, rr, rt = rect
    rot = region.get("rotation") or 0
    if not rot:
        return rect
    cx, cy, hw, hh = (rl + rr) / 2, (rb + rt) / 2, (rr - rl) / 2, (rt - rb) / 2
    ex = abs(hw * math.cos(rot)) + abs(hh * math.sin(rot))
    ey = abs(hw * math.sin(rot)) + abs(hh * math.cos(rot))
    return cx - ex, cy - ey, cx + ex, cy + ey


def source(scene, r, rect, px, py):
    """The region's premultiplied color at canvas points px, py: its art (or fill) through its
    texcoords and turn, times its vertex color and alphas, times each attached mask's alpha."""
    u, v, inside = uv_map(r, rect, px, py)
    if r.get("solid"):
        src = np.ones(px.shape + (4,))
    else:
        tex = load_texture(r["texture"])
        src = sample(tex, u, v) if tex is not None else np.dstack([np.full(px.shape, 0.55)] * 3 + [np.ones(px.shape)])
    color = list(r.get("color") or [1, 1, 1, 1]) + [1] * 4
    a = color[3] * (r.get("alpha", 1) or 1) * scene.frame_alpha(r.get("frame"))
    src = src * np.array([color[0] * a, color[1] * a, color[2] * a, a]) * inside[..., None]
    for mid in r.get("masks") or []:
        m = scene.items.get(mid)
        mt = load_texture(m.get("texture") or "") if m and m.get("shown", True) else None
        if mt is not None:
            mu, mv, minside = uv_map(m, scene.rect(mid), px, py)
            src *= (sample(mt, mu, mv)[..., 3] * minside)[..., None]
    return src


def draw_region(canvas, scene, r, box, K):
    L, _, _, T = box
    H, W = canvas.shape[:2]
    rect = scene.rect(r["id"])
    if rect[2] - rect[0] <= 0 or rect[3] - rect[1] <= 0 or not (r.get("solid") or r.get("texture")):
        return
    rl, rb, rr, rt = bounds(r, rect)
    x0, x1 = max(0, int(math.floor((rl - L) * K))), min(W, int(math.ceil((rr - L) * K)))
    y0, y1 = max(0, int(math.floor((T - rt) * K))), min(H, int(math.ceil((T - rb) * K)))
    if x1 <= x0 or y1 <= y0:
        return
    ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float64)
    src = source(scene, r, rect, L + (xs + 0.5) / K, T - (ys + 0.5) / K)
    dst = canvas[y0:y1, x0:x1]
    if (r.get("blend") or "BLEND") == "ADD":
        dst[..., :3] = np.clip(dst[..., :3] + src[..., :3], 0, 1)
    else:
        dst[...] = src + dst * (1 - src[..., 3:4])


def draw_text(draw, scene, r, box, zoom):
    L, _, _, T = box
    rl, rb, rr, rt = scene.rect(r["id"])
    size = (r.get("font") or [None, 11])[1] or 11
    f = font(int(size * zoom))
    fill = tuple(int(255 * x) for x in (r.get("color") or [1, 1, 1])[:3])
    tw = draw.textlength(r["text"], font=f) / zoom
    pts = r.get("points") or [["CENTER"]]
    point = pts[0][0] if pts else "CENTER"
    x = rl if rr - rl > 1 else rl - {-1: 0, 0: tw / 2, 1: tw}[H_OF.get(point, 0)]   # spanned: left
    y = (rb + rt) / 2 - {-1: -size / 2, 0: 0, 1: size / 2}[V_OF.get(point, 0)]
    draw.text(((x - L) * zoom, (T - y) * zoom), r["text"], font=f, fill=fill, anchor="lm")


def composite(scene, box, bg, zoom=1):
    """Draw the scene's shown regions over `bg` in canvas box (L, B, R, T), `zoom` output pixels to
    the UI pixel; answers an RGB Image. Font strings go last: every label the shine meets is OVERLAY."""
    L, B, R, T = box
    K = SS * zoom
    canvas = np.zeros((int(round((T - B) * K)), int(round((R - L) * K)), 4))
    canvas[..., :3] = np.array(bg) / 255
    canvas[..., 3] = 1
    shown = [r for r in scene.s["regions"] if r.get("shown")]
    textures = sorted((r for r in shown if r["kind"] == "Texture" and r.get("layer") in LAYERS),
                      key=lambda r: (scene.level(r), LAYERS[r["layer"]], r.get("sublevel") or 0, int(r["id"][1:])))
    for r in textures:
        draw_region(canvas, scene, r, box, K)
    img = Image.fromarray((np.clip(canvas[..., :3], 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
    img = img.resize((int(round((R - L) * zoom)), int(round((T - B) * zoom))), Image.LANCZOS)
    draw = ImageDraw.Draw(img)
    for r in shown:
        if r["kind"] == "FontString" and r.get("text"):
            draw_text(draw, scene, r, box, zoom)
    return img


def dial_tile(s, bg):
    scene = Scene(s)
    half = s["disc"] / 2 + 14
    return composite(scene, (-half, -half, half, half), bg)


def pad_tile(s, bg, pad=6, zoom=2):
    scene = Scene(s)
    rects = [scene.rect(b) for b in s["buttons"]]
    L = min(r[0] for r in rects) - pad
    B = min(r[1] for r in rects) - pad
    R = max(r[2] for r in rects) + pad
    T = max(r[3] for r in rects) + pad
    return composite(scene, (L, B, R, T + 16), bg, zoom)   # room for the first section title


def label(img, text, size=15):
    f = font(size)
    out = Image.new("RGB", (img.width, img.height + size + 12), (23, 20, 31))
    out.paste(img, (0, size + 12))
    ImageDraw.Draw(out).text((8, 5), text, font=f, fill=(245, 197, 66))
    return out


def grid(tiles, cols, gap=10, title=None):
    w = max(t.width for t in tiles)
    h = max(t.height for t in tiles)
    rows = (len(tiles) + cols - 1) // cols
    top = 34 if title else 0
    out = Image.new("RGB", (cols * w + (cols + 1) * gap, top + rows * h + (rows + 1) * gap), (23, 20, 31))
    if title:
        ImageDraw.Draw(out).text((gap, 8), title, font=font(18), fill=(236, 232, 245))
    for i, t in enumerate(tiles):
        out.paste(t, (gap + (i % cols) * (w + gap), top + gap + (i // cols) * (h + gap)))
    return out


def dial_grids(scenes, bg, out_dir, scenes_too):
    for n in sorted({s["slices"] for s in scenes if s["kind"] == "dial"}):
        tiles = []
        for look in LOOK_NAMES:
            for s in scenes:
                if s["kind"] == "dial" and s["slices"] == n and s["look"] == look:
                    img = dial_tile(s, bg)
                    if scenes_too:
                        img.save(os.path.join(out_dir, "scene-dial-%s-%d.png" % (look, n)))
                    tiles.append(label(img, LOOK_NAMES[look]))
        out = os.path.join(out_dir, "render-dial-%d.png" % n)
        grid(tiles, 4, title="Comms Dial, stock, %d slices (rendered from the addon's own paint)" % n).save(out)
        print("wrote", out)


def pad_row(scenes, look, bg, out_dir, scenes_too):
    parts = []
    for style in ("default", "icon"):
        for s in scenes:
            if s["kind"] == "pad" and s["look"] == look and s["style"] == style:
                img = pad_tile(s, bg)
                if scenes_too:
                    img.save(os.path.join(out_dir, "scene-pad-%s-%s.png" % (look, style)))
                parts.append(img)
    row = Image.new("RGB", (sum(p.width for p in parts) + 16 * (len(parts) - 1), max(p.height for p in parts)),
                    (23, 20, 31))
    x = 0
    for p in parts:
        row.paste(p, (x, 0))
        x += p.width + 16
    return label(row, LOOK_NAMES[look])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json")
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--bg", default="2b2340", help="the scene behind, hex (the mockup's default)")
    ap.add_argument("--scenes", action="store_true")
    args = ap.parse_args()
    bg = tuple(int(args.bg[i:i + 2], 16) for i in (0, 2, 4))
    path = args.json
    if not path:
        path = os.path.join(tempfile.mkdtemp(), "shine-preview.json")
        subprocess.run(["lua", "tools/render-shine-preview.lua", path], cwd=ROOT, check=True)
    with open(path) as fh:
        scenes = json.load(fh)["scenes"]
    os.makedirs(args.out, exist_ok=True)
    dial_grids(scenes, bg, args.out, args.scenes)
    rows = [pad_row(scenes, look, bg, args.out, args.scenes) for look in LOOK_NAMES]
    out = os.path.join(args.out, "render-pad.png")
    grid(rows, 1, title="Comms Pad, stock buttons and an icon-only pad (rendered from the addon's own paint)").save(out)
    print("wrote", out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
