#!/usr/bin/env python3
"""Trailbound colour-variant tool — rank-preserving ramp re-shade.

Implements style_lock T1: a palette variant is a NEW shading pass on
the same silhouette, not a hue rotation.  The master sprite is gen'd
once; each variant remaps the target colour family's ramp while keeping
every pixel's rank (its position dark->light) — silhouette, band
structure and pixel-art clusters survive exactly, 0 gen credits.

    python tools/tb_variant.py IN.png --variant dry_gold
    python tools/tb_variant.py IN.png --variant autumn_copper --family warm
    python tools/tb_variant.py IN.png --variant dry_gold --dry-run
    python tools/tb_variant.py IN.png --ramp "#2e3316,#5a5c1f,#8a7f2a,#b09b34,#d1b94a"

--family selects which pixels the ramp-swap touches:
    green  hue 55-145, s>0.20, g-dominant      (default — foliage)
    warm   hue 15-55,  s>0.20, r>=g            (copper/autumn crowns)
    cool   hue 145-265, s>0.20                  (teal/water families)
    all    any pixel with s>0.20                (whole-sprite recolour)
Alpha and non-family pixels pass through untouched.
"""
import argparse
import colorsys
import os
import sys

import numpy as np
from PIL import Image

# ------------------------------------------------------------- family masks
def family_mask(arr, fam):
    h, w = arr.shape[:2]
    r = arr[..., 0].astype(float) / 255.0
    g = arr[..., 1].astype(float) / 255.0
    b = arr[..., 2].astype(float) / 255.0
    a = arr[..., 3] > 0
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    d = mx - mn
    s = np.zeros_like(mx)
    nz = mx > 0
    s[nz] = d[nz] / mx[nz]
    # hue in degrees, numpy vectorised
    hh = np.zeros_like(mx)
    m = d > 0
    i = m & (mx == r)
    hh[i] = (60.0 * ((g - b) / np.maximum(d, 1e-9)) % 360.0)[i]
    i = m & (mx == g)
    hh[i] = (60.0 * ((b - r) / np.maximum(d, 1e-9)) + 120.0)[i]
    i = m & (mx == b)
    hh[i] = (60.0 * ((r - g) / np.maximum(d, 1e-9)) + 240.0)[i]
    hh = hh % 360.0
    base = a & (s > 0.20)
    if fam == "green":
        return base & (hh >= 55) & (hh <= 145) & (g >= r * 0.9)
    if fam == "warm":
        return base & (hh >= 15) & (hh <= 55) & (r >= g)
    if fam == "cool":
        return base & (hh >= 145) & (hh <= 265)
    return base                                   # "all"

# ------------------------------------------------------------- named variants
# Ramps are dark -> light hex stops, sampled by rank.  Seeded from the
# Pinewatch v3 grass ramp (#5a6e3c shade / #c0c879 mid / #d4d587 light)
# and the re-shaded variants studied in assets_src/reference/resurrected_rpg.
VARIANTS = {
    "deep_summer": ["#26351f", "#3d5428", "#5f7f35", "#8aa848", "#b5cc5e"],
    "dry_gold":    ["#33301a", "#57531f", "#7f7226", "#a8922f", "#cbb245"],
    "autumn_copper": ["#2e1f16", "#54321a", "#7d4a1e", "#a86524", "#cf8436"],
    "winter_frost": ["#2b3134", "#46545a", "#678086", "#93abb0", "#bfd4d6"],
    "dusk_violet": ["#241f33", "#3d3354", "#5c4f7f", "#8373a8", "#ab9ccc"],
}


def hex_to_rgb(hx):
    hx = hx.lstrip("#")
    return tuple(int(hx[i:i + 2], 16) for i in (0, 2, 4))


def ramp_sample(stops, t):
    """Sample a hex-stop ramp at t in [0,1], HSV lerp shortest-hue."""
    hsv = [colorsys.rgb_to_hsv(*(c / 255.0 for c in hex_to_rgb(s)))
           for s in stops]
    if t <= 0:
        out = hsv[0]
    elif t >= 1:
        out = hsv[-1]
    else:
        p = t * (len(hsv) - 1)
        i0 = int(p)
        f = p - i0
        a, b = hsv[i0], hsv[i0 + 1]
        dh = ((b[0] - a[0] + 0.5) % 1.0) - 0.5    # shortest arc
        out = ((a[0] + dh * f) % 1.0,
               a[1] + (b[1] - a[1]) * f,
               a[2] + (b[2] - a[2]) * f)
    r, g, b = colorsys.hsv_to_rgb(*out)
    return int(round(r * 255)), int(round(g * 255)), int(round(b * 255))


def variant_remap(arr, fam, stops):
    """Rank-preserving recolor of the family pixels.  Returns (arr, table)."""
    mask = family_mask(arr, fam)
    if not mask.any():
        return arr, []
    cols = {}
    ys, xs = np.where(mask)
    for y, x in zip(ys, xs):
        c = tuple(arr[y, x][:3])
        cols[c] = cols.get(c, 0) + 1
    ramp = sorted(cols, key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2])
    n = len(ramp)
    table = [(c, ramp_sample(stops, i / max(1, n - 1)), cols[c])
             for i, c in enumerate(ramp)]
    lut = {old: new for old, new, _ in table}
    for y, x in zip(ys, xs):
        arr[y, x, :3] = lut[tuple(arr[y, x][:3])]
    return arr, table


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("--variant", default="dry_gold",
                    choices=list(VARIANTS) + ["custom"])
    ap.add_argument("--family", default="green",
                    choices=["green", "warm", "cool", "all"])
    ap.add_argument("--ramp", help="comma hex stops, overrides --variant")
    ap.add_argument("-o", "--out")
    ap.add_argument("--dry-run", action="store_true",
                    help="print the ramp remap, write nothing")
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args()

    if args.list:
        for k, v in VARIANTS.items():
            print(f"{k:14s} {' '.join(v)}")
        return 0

    stops = [s.strip() for s in args.ramp.split(",")] if args.ramp \
        else VARIANTS.get(args.variant, VARIANTS["dry_gold"])
    name = "custom" if args.ramp else args.variant

    im = Image.open(args.src).convert("RGBA")
    arr = np.array(im)
    arr2, table = variant_remap(arr, args.family, stops)
    if not table:
        print(f"no '{args.family}' pixels in {args.src}")
        return 1
    print(f"{args.family} ramp ({len(table)} bands) -> {name}:")
    for old, new, npx in table:
        print(f"  #{''.join(f'{c:02x}' for c in old)} -> "
              f"#{''.join(f'{c:02x}' for c in new)}   ({npx}px)")
    if args.dry_run:
        return 0
    out = args.out or os.path.splitext(args.src)[0] + f"_{name}.png"
    Image.fromarray(arr2, "RGBA").save(out)
    print("wrote", out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
