#!/usr/bin/env python3
"""Per-asset palette remapper — indexed color-swap, not pixel grading.

For each sprite PNG:
  1. extract unique opaque colors (+counts)
  2. classify each color into a material family (teal / lemon-green / warm /
     neutral / accent)
  3. build target ramps measured from the reference image (eastward_clean.png)
     — real distributions, not hand-picked hexes
  4. per family: sort src colors by luminance rank, map each rank to the same
     percentile of the ref family's value distribution; hue/sat pulled toward
     ref family center but keeping per-color variation (tighten, not flatten)
  5. apply exact src->dst LUT per pixel: edges, dither, aa all preserved

Usage:
  python tools/palette_remap.py --report            # write before/after sheets
  python tools/palette_remap.py --apply [--dirs ...] # remap in place
  python tools/palette_remap.py --file PATH [--apply]
"""
import colorsys
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REF = os.path.join(ROOT, "assets_src/refs/eastward_clean.png")
ASSETS = os.path.join(ROOT, "game/assets/pinewatch")

# family hue ranges (deg) — measured on eastward_clean.png
FAMILIES = {
    "teal":  (115, 195),   # water / boulders — ref h_med 163, s .61, v .25-.75
    "lemon": (55, 115),    # grass/foliage — ref h_med 72, s .59, v .38-1.0
    "warm":  (8, 55),      # wood/tan — ref h_med 51, s .51, v .21-1.0
}
REF_STATS = {}


def rgb2hsv(px):
    mx = px.max(-1)
    mn = px.min(-1)
    d = mx - mn
    v = mx
    s = np.where(mx > 0, d / np.maximum(mx, 1e-9), 0.0)
    r, g, b = px[..., 0], px[..., 1], px[..., 2]
    m = d > 1e-6
    hr = np.where(m, ((g - b) / np.maximum(d, 1e-9)) % 6, 0)
    hg = np.where(m, (b - r) / np.maximum(d, 1e-9) + 2, 0)
    hb = np.where(m, (r - g) / np.maximum(d, 1e-9) + 4, 0)
    h = np.where(mx == r, hr, np.where(mx == g, hg, hb)) * 60.0
    return h, s, v


def hsv2rgb(h, s, v):
    out = np.empty(h.shape + (3,), float)
    flat = [colorsys.hsv_to_rgb(a / 60.0 % 6.0, float(np.clip(b, 0, 1)), float(np.clip(c, 0, 1)))
            for a, b, c in zip(h.ravel(), s.ravel(), v.ravel())]
    out = np.array(flat).reshape(h.shape + (3,))
    return out


def load_ref():
    """Measure per-family distributions on the reference image."""
    im = np.array(Image.open(REF).convert("RGB"), float) / 255.0
    px = im.reshape(-1, 3)
    h, s, v = rgb2hsv(px)
    for name, (lo, hi) in FAMILIES.items():
        sel = (h >= lo) & (h < hi) & (s > 0.25) & (v > 0.12)
        REF_STATS[name] = {
            "h_med": float(np.median(h[sel])),
            "s_med": float(np.median(s[sel])),
            "v_sorted": np.sort(v[sel]),          # full dist for percentile map
            "v_lo": float(np.percentile(v[sel], 3)),
            "v_hi": float(np.percentile(v[sel], 97)),
        }


def family_of(h, s, v):
    if s <= 0.18 or v <= 0.10:
        return "neutral"
    for name, (lo, hi) in FAMILIES.items():
        if lo <= h < hi:
            return name
    return "accent"          # reds/pinks/blues — keep verbatim


def remap_file(path, write=False):
    """Remap one PNG in place. Returns (n_colors_changed, n_px) or None."""
    im = Image.open(path).convert("RGBA")
    arr = np.array(im)
    rgb = arr[..., :3].astype(float) / 255.0
    a = arr[..., 3]
    opaque = a > 12
    if not opaque.any():
        return None

    cols, inv, counts = np.unique(
        arr[..., :3][opaque].reshape(-1, 3), axis=0,
        return_inverse=True, return_counts=True)
    h, s, v = rgb2hsv(cols.astype(float) / 255.0)
    fam = np.array([family_of(*c) for c in zip(h, s, v)])

    lut = cols.astype(float).copy()
    for name in FAMILIES:
        sel = fam == name
        if sel.sum() < 2:
            continue
        ref = REF_STATS[name]
        src_v = v[sel]
        src_h = h[sel]
        src_s = s[sel]
        # luminance rank within family -> same percentile on ref v-dist
        order = src_v.argsort()
        rank = np.empty(len(order))
        rank[order] = np.linspace(0, 1, len(order))
        vq = np.quantile(ref["v_sorted"], rank)
        # tighten hue/sat toward ref family center (keep 35%/50% variation)
        nh = ref["h_med"] + (src_h - np.median(src_h)) * 0.35
        ns = np.clip(ref["s_med"] + (src_s - np.median(src_s)) * 0.5, 0.05, 0.95)
        # accents guard: warm-family brights (fire/flowers) keep 70% identity
        if name == "warm":
            bright = (src_v > 0.78) & (src_s > 0.60)
            nh = np.where(bright, src_h * 0.7 + nh * 0.3, nh)
            ns = np.where(bright, src_s * 0.8 + ns * 0.2, ns)
            vq = np.where(bright, src_v, vq)
        dst = hsv2rgb(nh, ns, vq) * 255.0
        lut[sel] = dst

    # neutral: slight lift of crushed darks only
    neu = fam == "neutral"
    if neu.any():
        dark = v[neu] < 0.30
        idx = np.where(neu)[0][dark]
        if len(idx):
            lut[idx] = np.clip(lut[idx] * 1.10 + 4, 0, 255)

    lut = np.clip(np.round(lut), 0, 255).astype(np.uint8)
    changed = int((lut != cols).any(1).sum())
    if changed == 0:
        return (0, int(opaque.sum()))

    # apply LUT per pixel (opaque only)
    out = arr.copy()
    px_idx = inv
    new_rgb = lut[px_idx]
    op = out[..., :3][opaque]
    op[:] = new_rgb
    if write:
        Image.fromarray(out).save(path)
    return (changed, int(opaque.sum()))


def collect_pngs(dirs):
    for d in dirs:
        for dp, _, fs in os.walk(d):
            for f in sorted(fs):
                if f.endswith(".png"):
                    yield os.path.join(dp, f)


def report_sheet(pairs, out):
    cell, cols = 96, 10
    n = len(pairs)
    rows = math.ceil(n * 2 / cols)
    im = Image.new("RGB", (cols * cell, rows * (cell + 12)), (28, 28, 32))
    d = ImageDraw.Draw(im)
    for i, (path, kind) in enumerate(pairs):
        x, y = (i % cols) * cell, (i // cols) * (cell + 12)
        s = Image.open(path).convert("RGBA")
        s.thumbnail((cell - 6, cell - 6), Image.NEAREST)
        bg = Image.new("RGBA", (s.width, s.height), (46, 46, 50, 255))
        bg.alpha_composite(s)
        im.paste(bg, (x + 3, y + 3))
        d.text((x + 3, y + cell), os.path.basename(path)[:14], fill=(200, 200, 200))
    im.save(out)


def main():
    apply = "--apply" in sys.argv
    one = None
    if "--file" in sys.argv:
        one = sys.argv[sys.argv.index("--file") + 1]
    load_ref()

    if one:
        files = [one]
    else:
        dirs = [os.path.join(ASSETS, d) for d in
                ("props_large", "props_medium", "props_small", "decals",
                 "fx", "terrain", "icons")]
        dirs = [d for d in dirs if os.path.isdir(d)]
        # ground + tintmap keep their own palette-keyed pipeline (derender.py)
        skip = {"ground_painted.png", "ground_sunlit.png",
                "ground_tintmap.png", "ground_sunlit_trial.png"}
        files = [p for p in collect_pngs(dirs)
                 if os.path.basename(p) not in skip]

    results = {}
    for p in files:
        try:
            r = remap_file(p, write=apply)
            if r:
                results[os.path.relpath(p, ASSETS)] = r
        except Exception as e:
            results[os.path.relpath(p, ASSETS)] = ("ERR", str(e))

    n_changed = sum(1 for v in results.values() if v[0] not in (0, "ERR"))
    print(f"{len(results)} files, {n_changed} remapped"
          + (" (applied)" if apply else " (dry run)"))
    if "--verbose" in sys.argv or one:
        for k, v in results.items():
            print(" ", k, v)
    return results


if __name__ == "__main__":
    main()
