#!/usr/bin/env python3
"""Build site_palette_v3 — the NEW snap target — from the re-graded
(pinewatch_v2) staged assets, WITH explicit light->mid->shade ramps per
family so future art can be snapped/derived against the full value
range, not just the modal colours.

Families:
  grass  bright yellow-green lights -> mid olive -> deep cool shade
  water  fresh teal lights -> mid teal -> muted teal shadow
  dirt   warm ochre light -> mid -> deep brown shade
  warm   prop/accent ramp (cream -> ochre/wood -> umber outline)

Ramps are DERIVED from the re-graded sheets (mid = measured fill mean;
lights/shades pushed in HSV to the corrected Eastward direction), so the
json documents the actual shipped ramp, not an aspiration.

NOTE (carried in the json): the ground tint-map overlay
(assets_src/cleanup/ground_tintmap.png, the engine's GroundTint sprite)
is a LIGHTING layer — EXEMPT from palette snapping.  Snap targets are
the art layers only.

Out: out/site_palette_v3.json + cleanup/site_palette_v3.png swatch
"""
import colorsys
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import png as _png

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STG = os.path.join(ROOT, "assets_src", "staging", "pinewatch")
OUT = os.path.join(ROOT, "assets_src", "out")
CLN = os.path.join(ROOT, "assets_src", "cleanup")
PAL_CATS = ["props_large", "props_medium", "props_small",
            "characters", "decals", "icons", "terrain"]
N_COLORS = 48
MERGE_DE = 14


def srgb2lab(rgb):
    x = rgb.astype(float) / 255
    lin = np.where(x > 0.04045, ((x + 0.055) / 1.055) ** 2.4, x / 12.92)
    M = np.array([[0.4124, 0.3576, 0.1805],
                  [0.2126, 0.7152, 0.0722],
                  [0.0193, 0.1192, 0.9505]])
    xyz = lin @ M.T / np.array([0.95047, 1.0, 1.08883])
    e = 0.008856
    f = np.where(xyz > e, xyz ** (1 / 3), (7.787 * xyz) + 16 / 116)
    L = 116 * f[..., 1] - 16
    a = 500 * (f[..., 0] - f[..., 1])
    b = 200 * (f[..., 1] - f[..., 2])
    return np.stack([L, a, b], -1)


def collect():
    px = []
    for cat in PAL_CATS:
        d = os.path.join(STG, cat)
        for fn in os.listdir(d):
            if fn.endswith(".png"):
                a = np.array(Image.open(os.path.join(d, fn))
                             .convert("RGBA"))
                m = a[..., 3] > 200
                px.append(a[..., :3][m])
    return np.concatenate(px)


def build_palette(px):
    cols, counts = np.unique(px.reshape(-1, 3), axis=0,
                             return_counts=True)
    order = np.argsort(-counts)
    cols, counts = cols[order], counts[order]
    keep = counts > len(px) * 0.0001
    cols, counts = cols[keep], counts[keep]
    lab = srgb2lab(cols)
    pal_idx = []
    for i in range(len(cols)):
        if not pal_idx:
            pal_idx.append(i)
            continue
        d = np.sqrt(((lab[pal_idx] - lab[i]) ** 2).sum(1))
        if d.min() > MERGE_DE:
            pal_idx.append(i)
        if len(pal_idx) >= N_COLORS:
            break
    return cols[pal_idx], counts[pal_idx]


def classify(c):
    r, g, b = [v / 255 for v in c]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if s < 0.18:
        return "neutral"
    if 0.16 <= h <= 0.52:
        return "green"
    if h < 0.16 or h > 0.85:
        return "warm"
    return "cool"


def hsv_shift(rgb, dh=0.0, s=1.0, v=1.0):
    h, s_, v_ = colorsys.rgb_to_hsv(*(c / 255 for c in rgb))
    r, g, b = colorsys.hsv_to_rgb(((h * 360 + dh) % 360) / 360,
                                min(1, max(0, s_ * s)),
                                min(1, max(0, v_ * v)))
    return tuple(int(round(c * 255)) for c in (r, g, b))


def fill_mean(path, box):
    """Mean RGB of the opaque pixels in a wang sheet fill tile."""
    w, h, rows = _png.read(path)
    px = []
    for y in range(box[1], box[3]):
        for x in range(box[0], box[2]):
            i = x * 4
            if rows[y][i + 3] > 200:
                px.append(rows[y][i:i + 3])
    return tuple(np.mean(np.asarray(px), 0))


def hexs(rgb):
    return "#%02x%02x%02x" % tuple(int(c) for c in rgb)


def main():
    px = collect()
    pal, cnts = build_palette(px)
    stats = {"green": 0, "warm": 0, "neutral": 0, "cool": 0}
    entries = []
    for c, n in zip(pal, cnts):
        k = classify(c)
        stats[k] += int(n)
        entries.append({"rgb": [int(v) for v in c], "hex": hexs(c),
                        "share": round(int(n) / len(px) * 100, 2),
                        "class": k})
    total = sum(stats.values())

    # ---- measured mids from the re-graded sheets ---------------------
    T = os.path.join(STG, "terrain")
    grass_mid = fill_mean(os.path.join(T, "terrain_grass_water_pro_0.png"),
                          (0, 96, 32, 128))
    water_mid = fill_mean(os.path.join(T, "terrain_grass_water_pro_0.png"),
                          (64, 32, 96, 64))
    dirt_mid = fill_mean(os.path.join(T, "terrain_grass_forest_pro_0.png"),
                         (64, 32, 96, 64))
    # warm mid = median warm palette colour by luminance
    warm_cols = np.array([e["rgb"] for e in entries
                          if e["class"] == "warm"])
    wl = warm_cols @ np.array([0.299, 0.587, 0.114])
    warm_mid = tuple(warm_cols[np.argsort(wl)[len(wl) // 2]])

    ramps = {
        # bright yellow-green lights -> mid olive -> deep cool shade
        "grass": {
            "light": hexs(hsv_shift(grass_mid, dh=-6, s=0.92, v=1.06)),
            "mid":   hexs(grass_mid),
            "shade": hexs(hsv_shift(grass_mid, dh=18, s=1.15, v=0.55)),
        },
        # fresh teal lights -> mid teal -> muted teal shadow
        "water": {
            "light": hexs(hsv_shift(water_mid, dh=-6, s=1.10, v=1.18)),
            "mid":   hexs(water_mid),
            "shade": hexs(hsv_shift(water_mid, dh=8, s=0.85, v=0.62)),
        },
        # warm ochre (forest floor / path dirt)
        "dirt": {
            "light": hexs(hsv_shift(dirt_mid, dh=2, s=0.92, v=1.10)),
            "mid":   hexs(dirt_mid),
            "shade": hexs(hsv_shift(dirt_mid, dh=-4, s=1.05, v=0.55)),
        },
        # prop/warm family: cream light -> wood mid -> umber outline
        "warm": {
            "light": hexs(hsv_shift(warm_mid, dh=4, s=0.55, v=1.45)),
            "mid":   hexs(warm_mid),
            "shade": hexs(hsv_shift(warm_mid, dh=-4, s=1.10, v=0.45)),
        },
    }

    doc = {
        "version": 3,
        "source": "staged assets re-graded with tb_grade.py "
                  "--site pinewatch_v2 (B5 sheets, props/chars/decals "
                  "unchanged)",
        "method": "frequency-greedy, Lab dE>14 merge, top 48; ramps "
                  "derived from measured fill means + HSV pushes",
        "note": "the ground tint-map overlay (cleanup/ground_tintmap.png, "
                "engine GroundTint sprite) is a LIGHTING layer — EXEMPT "
                "from palette snapping; snap applies to art layers only",
        "class_shares": {k: round(v / total * 100, 1)
                         for k, v in stats.items()},
        "ramps": ramps,
        "colors": entries,
    }
    out_p = os.path.join(OUT, "site_palette_v3.json")
    with open(out_p, "w") as f:
        json.dump(doc, f, indent=1)
    print("palette classes:", doc["class_shares"])
    for fam, ramp in ramps.items():
        print("ramp %-5s" % fam,
              "  ".join(f"{k}={v}" for k, v in ramp.items()))

    # swatch: ramps on top (4 rows x 3 cells), frequency palette below
    sw = np.zeros((4 * 16 + 6 * 14, 8 * 40, 4), np.uint8)
    sw[..., 3] = 255
    for ri, fam in enumerate(("grass", "water", "dirt", "warm")):
        for ci, step in enumerate(("light", "mid", "shade")):
            hexc = ramps[fam][step]
            col = tuple(int(hexc[i:i + 2], 16) for i in (1, 3, 5))
            y, x = ri * 16 + 2, ci * 80 + 4
            sw[y:y + 12, x:x + 72, :3] = col
    yoff = 4 * 16 + 2
    for i, c in enumerate(pal):
        y, x = yoff + (i // 8) * 14, (i % 8) * 40
        sw[y:y + 12, x:x + 38, :3] = c
    Image.fromarray(sw).save(os.path.join(CLN, "site_palette_v3.png"))
    print("->", out_p)


if __name__ == "__main__":
    main()
