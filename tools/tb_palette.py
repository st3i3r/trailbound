#!/usr/bin/env python3
"""Build site_palette_v2 from the staged batch3/4 winners (greens must
dominate) and snap only outlier pixels (dE > threshold) on the out/
copies — a subtle pass that preserves AA and dither.

Out: out/site_palette_v2.json + cleanup/site_palette_v2.png swatch
     per-asset snap stats -> out/palette_snap_report.json
"""
import os, json, colorsys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STG = os.path.join(ROOT, "assets_src", "staging", "pinewatch")
OUT = os.path.join(ROOT, "assets_src", "out")
CLN = os.path.join(ROOT, "assets_src", "cleanup")
PAL_CATS = ["props_large", "props_medium", "props_small",
            "characters", "decals", "icons", "terrain"]
SNAP_CATS = ["props_large", "props_medium", "props_small",
             "characters", "decals", "icons"]
N_COLORS = 48
MERGE_DE = 14          # min distance between palette colors
SNAP_DE = 30           # outlier threshold (CIE76) — keeps deliberate
                        # accent colors (plastic-stool blue, silk red)

def srgb2lab(rgb):
    """rgb uint8 (...,3) -> Lab float (...,3), D65."""
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
                a = np.array(Image.open(os.path.join(d, fn)).convert("RGBA"))
                m = a[..., 3] > 200
                px.append(a[..., :3][m])
    return np.concatenate(px)

def build_palette(px):
    """Frequency-greedy palette: most common colors first, keep if far
    enough (Lab dE > MERGE_DE) from everything already chosen."""
    cols, counts = np.unique(px.reshape(-1, 3), axis=0,
                             return_counts=True)
    order = np.argsort(-counts)
    cols = cols[order]; counts = counts[order]
    # pre-filter: drop colors with <0.01% share (noise)
    keep = counts > len(px) * 0.0001
    cols, counts = cols[keep], counts[keep]
    lab = srgb2lab(cols)
    pal_idx = []
    for i in range(len(cols)):
        if not pal_idx:
            pal_idx.append(i); continue
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

def main():
    px = collect()
    print("opaque px pooled:", len(px))
    pal, cnts = build_palette(px)
    labs = srgb2lab(pal.reshape(1, -1, 3)).reshape(-1, 3)

    stats = {"green": 0, "warm": 0, "neutral": 0, "cool": 0}
    entries = []
    for c, n in zip(pal, cnts):
        k = classify(c)
        stats[k] += int(n)
        entries.append({"rgb": [int(v) for v in c],
                        "hex": "#%02x%02x%02x" % tuple(c),
                        "share": round(int(n) / len(px) * 100, 2),
                        "class": k})
    total = sum(stats.values())
    print("palette classes:", {k: round(v / total * 100, 1)
                             for k, v in stats.items()})

    # ---- outlier snap on out/ copies ---------------------------------
    report = {}
    for cat in SNAP_CATS:
        d = os.path.join(OUT, cat)
        for fn in sorted(os.listdir(d)):
            if not fn.endswith(".png"):
                continue
            p = os.path.join(d, fn)
            arr = np.array(Image.open(p).convert("RGBA"))
            a = arr[..., 3]
            m = a > 200
            if m.sum() == 0:
                continue
            pix = arr[..., :3][m].astype(float)
            pl = srgb2lab(pix.reshape(1, -1, 3)).reshape(-1, 3)
            # distance to each palette color (chunked)
            best_d = np.full(len(pix), 1e9); best_i = np.zeros(len(pix), int)
            for i, lc in enumerate(labs):
                d_e = np.sqrt(((pl - lc) ** 2).sum(1))
                upd = d_e < best_d
                best_d[upd] = d_e[upd]; best_i[upd] = i
            snap = best_d > SNAP_DE
            if snap.sum():
                pix2 = pix.copy()
                pix2[snap] = pal[best_i[snap]]
                out = arr.copy()
                out[..., :3][m] = np.clip(pix2, 0, 255).astype(np.uint8)
                Image.fromarray(out).save(p)
            report[f"{cat}/{fn}"] = {
                "opaque": int(m.sum()), "snapped": int(snap.sum()),
                "max_dE": round(float(best_d.max()), 1)}
    with open(os.path.join(OUT, "palette_snap_report.json"), "w") as f:
        json.dump(report, f, indent=1)
    snapped = sum(v["snapped"] for v in report.values())
    worst = sorted(report.items(), key=lambda kv: -kv[1]["snapped"])[:8]
    print("snapped px total:", snapped, "worst:", worst)

    with open(os.path.join(OUT, "site_palette_v2.json"), "w") as f:
        json.dump({"source": "staged batch3+4 winners (props, chars, "
                             "decals, icons, terrain)",
                   "method": "frequency-greedy, Lab dE>14 merge, top 48",
                   "class_shares": {k: round(v / total * 100, 1)
                                    for k, v in stats.items()},
                   "colors": entries}, f, indent=1)
    # swatch
    sw = np.zeros((6 * 14, 8 * 40, 4), np.uint8)
    sw[..., 3] = 255
    for i, c in enumerate(pal):
        y, x = (i // 8) * 14, (i % 8) * 40
        sw[y:y + 12, x:x + 38, :3] = c
    Image.fromarray(sw).save(os.path.join(CLN, "site_palette_v2.png"))
    print("->", os.path.join(OUT, "site_palette_v2.json"))

if __name__ == "__main__":
    main()
