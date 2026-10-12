#!/usr/bin/env python3
"""Inspect staged Pinewatch assets: size, alpha bbox, bottom shadow
detection, dominant colors. Read-only analysis — writes nothing."""
import os, sys, json
from collections import Counter
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    "assets_src", "staging", "pinewatch")

def alpha_bbox(im):
    a = im.getchannel("A")
    return a.getbbox()

def components(im, min_px=8):
    """8-connected components of alpha>0. Returns list of (bbox, npix)."""
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    comps = []
    for y0 in range(h):
        for x0 in range(w):
            i = y0 * w + x0
            if seen[i] or px[x0, y0][3] == 0:
                continue
            stack = [(x0, y0)]; seen[i] = 1
            xs = []; ys = []; n = 0
            while stack:
                x, y = stack.pop(); n += 1; xs.append(x); ys.append(y)
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h:
                            j = ny * w + nx
                            if not seen[j] and px[nx, ny][3] > 0:
                                seen[j] = 1; stack.append((nx, ny))
            if n >= min_px:
                comps.append(((min(xs), min(ys), max(xs) + 1, max(ys) + 1), n))
    return comps

def bottom_band_stats(im, band_frac=0.18):
    """Look at the bottom band for soft dark shadow-like pixels."""
    w, h = im.size
    px = im.load()
    y0 = int(h * (1 - band_frac))
    dark_soft = 0; opaque = 0
    for y in range(y0, h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            opaque += 1
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            if 30 <= a <= 200 and lum < 110:
                dark_soft += 1
    return opaque, dark_soft

def top_colors(im, n=8):
    px = im.load(); w, h = im.size
    c = Counter()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 200:
                c[(r, g, b)] += 1
    return c.most_common(n)

def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    for cat in sorted(os.listdir(ROOT)):
        d = os.path.join(ROOT, cat)
        if not os.path.isdir(d):
            continue
        if only and cat != only:
            continue
        print(f"\n===== {cat} =====")
        for fn in sorted(os.listdir(d)):
            if not fn.endswith(".png"):
                continue
            im = Image.open(os.path.join(d, fn)).convert("RGBA")
            w, h = im.size
            bb = alpha_bbox(im)
            op, soft = bottom_band_stats(im)
            ncomp = len(components(im)) if w * h <= 20000 else -1
            print(f"{fn:42s} {w:4d}x{h:<4d} bbox={bb} comps={ncomp:3d} "
                  f"botband opq={op} softdark={soft}")

if __name__ == "__main__":
    main()
