#!/usr/bin/env python3
"""Detailed component analysis of the U1-U5 UI sheets."""
import os, sys
from collections import Counter
from PIL import Image

UI = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                  "assets_src", "staging", "pinewatch", "ui")
REVIEW = os.path.join(os.environ.get("TEMP", "/tmp"), "tb_review")
os.makedirs(REVIEW, exist_ok=True)

def components(im, min_px=4):
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
            cols = Counter()
            while stack:
                x, y = stack.pop(); n += 1; xs.append(x); ys.append(y)
                cols[px[x, y][:3]] += 1
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h:
                            j = ny * w + nx
                            if not seen[j] and px[nx, ny][3] > 0:
                                seen[j] = 1; stack.append((nx, ny))
            if n >= min_px:
                comps.append({"bbox": (min(xs), min(ys), max(xs) + 1, max(ys) + 1),
                              "n": n, "top": cols.most_common(3)})
    comps.sort(key=lambda c: (c["bbox"][1], c["bbox"][0]))
    return comps

for name in ["U1_0", "U2_0", "U3_0", "U4_0", "U5_0"]:
    im = Image.open(os.path.join(UI, name + ".png")).convert("RGBA")
    comps = components(im)
    print(f"\n===== {name} {im.size} — {len(comps)} comps =====")
    for i, c in enumerate(comps):
        x0, y0, x1, y1 = c["bbox"]
        print(f"  [{i:2d}] ({x0:3d},{y0:3d})-({x1:3d},{y1:3d}) "
              f"{x1-x0:3d}x{y1-y0:3d} px={c['n']:5d} top={c['top']}")
    # review magnify
    im.resize((im.width * 3, im.height * 3), Image.NEAREST).save(
        os.path.join(REVIEW, name + "_x3.png"))
print("\nreview sheets ->", REVIEW)
