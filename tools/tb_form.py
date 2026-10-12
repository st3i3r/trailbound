#!/usr/bin/env python3
"""Form shading (Phase 0.2) — deterministic craft pass on prop sprites.

Fakes ambient/form light on the generated props so they stop reading as
flat icons (style_lock craft spec: "warm lit side, cool shadow side",
"directional shadow with bounce-lit dark side"):

  1. Lower-right third darkens ~14% max with a cool hue tilt
     (+~10deg toward blue + a small RGB cool multiply) — a soft ramp,
     strongest at the bottom-right corner, zero above/left of centre.
  2. The darkest already-painted pixels under the object centre
     (lower band, |nx-0.5|<0.28, original value < 0.45) pull toward
     near-black — deepens the painted contact shadow only, never
     invents one.
  3. Upper-left highlights are untouched by construction.

Runs IN PLACE over the three synced copies (assets_src/out/,
assets_src/staging/pinewatch/, game/assets/pinewatch/) — props_* dirs
ONLY.  Never on terrain/decals/characters/fx/font/ui.

Usage:
  python tools/tb_form.py --dry-run    # 5 props -> %TEMP%/tb_review/form_dryrun.png
  python tools/tb_form.py              # apply to all props in all 3 dirs
"""
import os, sys, json, math
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIRS = [os.path.join(ROOT, "assets_src", "out"),
        os.path.join(ROOT, "assets_src", "staging", "pinewatch"),
        os.path.join(ROOT, "game", "assets", "pinewatch")]
CATS = ["props_small", "props_medium", "props_large"]
ANCH = json.load(open(os.path.join(DIRS[0], "anchors.json")))
REVIEW = os.path.join(os.environ.get("TEMP", ROOT), "tb_review")

# flat ground art that lives in the props dirs — shading it would
# paint a weird directional stain on the ground itself
EXCLUDE = {"dirt_patch"}

DRYRUN = [("props_large", "outfitter_van"), ("props_medium", "tent_red"),
          ("props_medium", "fire_ring_unlit"),
          ("props_small", "stool_plastic_red"),
          ("props_medium", "lantern_post")]

DARKEN = 0.14          # max value loss at the bottom-right corner
HUE_SHIFT = 10.0 / 360.0
CONTACT = 0.55         # max pull toward near-black in the contact zone


def rgb2hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = np.max(rgb, -1); mn = np.min(rgb, -1); d = mx - mn
    v = mx.copy()
    s = np.where(mx > 0, d / np.maximum(mx, 1e-9), 0)
    h = np.zeros_like(mx)
    ok = d > 1e-9
    i = ok & (mx == r); h[i] = ((g - b)[i] / d[i]) % 6
    i = ok & (mx == g); h[i] = (b - r)[i] / d[i] + 2
    i = ok & (mx == b); h[i] = (r - g)[i] / d[i] + 4
    return h / 6.0, s, v


def hsv2rgb(h, s, v):
    h = (h % 1.0) * 6.0
    i = np.floor(h).astype(int); f = h - i
    p = v * (1 - s); q = v * (1 - s * f); t = v * (1 - s * (1 - f))
    out = np.zeros(h.shape + (3,))
    for k, (rr, gg, bb) in enumerate(((v, t, p), (q, v, p), (p, v, t),
                                      (p, q, v), (t, p, v), (v, p, q))):
        m = i % 6 == k
        out[..., 0][m] = rr[m]; out[..., 1][m] = gg[m]; out[..., 2][m] = bb[m]
    return out


def shade(im, content=None):
    """im: HxWx4 float array 0..255. Returns (out, stats) or (im, None)."""
    a = im[..., 3]
    vis = a > 0
    if not vis.any():
        return im, None
    H, W = a.shape
    if content:
        x0, y0, x1, y1 = content
    else:
        ys, xs = np.where(vis)
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    nx = (xx - x0) / max(x1 - x0, 1)
    ny = (yy - y0) / max(y1 - y0, 1)

    rgb = im[..., :3] / 255.0
    h, s, v0 = rgb2hsv(rgb)

    def sstep(t):
        t = np.clip(t, 0, 1)
        return t * t * (3 - 2 * t)

    # -- 1. lower-right shade ramp (zero on the upper-left half, -------
    # full strength inside the lower-right third of the content box)
    wx = sstep((nx - 0.50) / 0.25)          # 0 at mid -> 1 by x=0.75
    wy = sstep((ny - 0.45) / 0.27)          # 0 at mid -> 1 by y=0.72
    w = wx * wy * np.clip(a / 255.0, 0, 1)
    h = (h + w * HUE_SHIFT) % 1.0
    v = v0 * (1.0 - DARKEN * w)
    out = hsv2rgb(h, s, v)
    # cool tilt that also reaches low-sat pixels (hue shift can't)
    out[..., 0] *= (1.0 - 0.040 * w)
    out[..., 1] *= (1.0 - 0.015 * w)
    out[..., 2] *= (1.0 + 0.045 * w)

    # -- 2. deepen the painted contact shadow under the centre --------
    zy = sstep((ny - 0.74) / 0.18)
    zx = 1.0 - sstep((np.abs(nx - 0.5) - 0.14) / 0.16)
    dark = np.clip((0.45 - v0) / 0.45, 0, 1)      # only already-dark px
    cw = zy * zx * dark * np.clip(a / 255.0, 0, 1) * CONTACT
    near_black = np.array((24, 21, 19)) / 255.0
    out = out * (1 - cw[..., None]) + near_black[None, None, :] * cw[..., None]

    out = np.clip(out, 0, 1)
    res = im.copy()
    res[..., :3] = out * 255.0

    # stats: where did it actually change?
    d = np.abs(res[..., :3] - im[..., :3]).sum(-1)
    changed = (d > 2) & vis
    ul = (nx < 0.4) & (ny < 0.4) & vis
    stats = {"px_vis": int(vis.sum()),
             "px_changed": int(changed.sum()),
             "mean_d": float(d[changed].mean()) if changed.any() else 0.0,
             "max_d_upperleft": float(d[ul].max()) if ul.any() else 0.0,
             "contact_px": int((cw > 0.08).sum())}
    return res, stats


def process(path, save=True):
    im = np.array(Image.open(path).convert("RGBA")).astype(float)
    rel = os.path.basename(path)
    key = None
    for c in CATS:
        k = f"{c}/{rel}"
        if k in ANCH:
            key = k
            break
    content = ANCH.get(key, {}).get("content") if key else None
    out, stats = shade(im, content)
    if save and stats:
        Image.fromarray(out.astype(np.uint8)).save(path)
    return im, out, stats


def main():
    dry = "--dry-run" in sys.argv
    if dry:
        os.makedirs(REVIEW, exist_ok=True)
        Z = 4
        tiles = []
        print(f"{'prop':26s} {'vis':>6} {'changed':>7} {'mean|d|':>7} "
              f"{'ULmax':>6} {'contact':>7}")
        for cat, name in DRYRUN:
            p = os.path.join(DIRS[0], cat, name + ".png")
            before, after, st = process(p, save=False)
            print(f"{name:26s} {st['px_vis']:6d} {st['px_changed']:7d} "
                  f"{st['mean_d']:7.1f} {st['max_d_upperleft']:6.1f} "
                  f"{st['contact_px']:7d}")
            for arr in (before, after):
                t = Image.fromarray(arr.astype(np.uint8))
                t = t.resize((t.width * Z, t.height * Z), Image.NEAREST)
                tiles.append((name, t))
        w = max(t.width for _, t in tiles) * 2 + 24
        hgt = sum(t.height for _, t in tiles[::2]) + 40
        sheet = Image.new("RGBA", (w, hgt), (38, 34, 30, 255))
        dr = ImageDraw.Draw(sheet)
        y = 30
        for (name, tb), (_, ta) in zip(tiles[::2], tiles[1::2]):
            sheet.paste(tb, (4, y), tb)
            sheet.paste(ta, (tb.width + 14, y), ta)
            dr.text((8, y - 12), f"{name}  before | after  x{Z}",
                    fill=(240, 230, 200))
            y += tb.height + 22
        out = os.path.join(REVIEW, "form_dryrun.png")
        sheet.save(out)
        print("->", out)
        return

    seen = set()
    n = 0
    tot = {"px": 0, "changed": 0}
    for d in DIRS:
        for cat in CATS:
            cd = os.path.join(d, cat)
            if not os.path.isdir(cd):
                continue
            for f in sorted(os.listdir(cd)):
                if not f.endswith(".png"):
                    continue
                name = f[:-4]
                if name in EXCLUDE:
                    print("skip (ground):", cat, name)
                    continue
                p = os.path.join(cd, f)
                _, _, st = process(p, save=True)
                if st:
                    n += 1
                    tot["px"] += st["px_vis"]
                    tot["changed"] += st["px_changed"]
                    seen.add(f"{cat}/{name}")
    print(f"form-shaded {n} files ({len(seen)} unique props x3 dirs), "
          f"{tot['changed']}/{tot['px']} px touched "
          f"({100.0 * tot['changed'] / max(tot['px'], 1):.1f}%)")


if __name__ == "__main__":
    main()
