#!/usr/bin/env python3
"""Post-process staged Pinewatch art onto COPIES in assets_src/out/.

- copies staging/pinewatch/<cat> -> out/<cat> (ui handled separately)
- synthesizes a soft contact-shadow ellipse (upper-left sun -> +2,+1)
  under every prop/character that lacks a soft shadow (skips line props)
- writes out/anchors.json (bottom-center props/chars; center decals/icons)
- measures character heights vs the 48 px spec -> out/scale_report.json

Never touches staging/ or gen/.
"""
import os, json, shutil, math
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STG = os.path.join(ROOT, "assets_src", "staging", "pinewatch")
OUT = os.path.join(ROOT, "assets_src", "out")

COPY_CATS = ["characters", "decals", "font", "icons", "props_large",
             "props_medium", "props_small", "terrain"]
SHADOW_CATS = {"characters", "props_large", "props_medium", "props_small"}
NO_SHADOW = {"pennant_string.png", "string_lights.png"}   # line-hung props
SHADOW_RGB = (26, 34, 22)      # dark forest-green/brown
SHADOW_A = 89                  # ~35%
BAYER = np.array([[1.0, 0.62], [0.62, 1.0]])

def content_bbox(a):
    ys, xs = np.where(a > 0)
    if len(xs) == 0:
        return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1

def soft_dark_ratio(arr, bbox):
    """Soft dark shadow-ish px in the 5 rows above content bottom."""
    x0, y0, x1, y1 = bbox
    band = arr[max(y1 - 5, 0):y1, x0:x1]
    r, g, b, a = (band[..., i].astype(int) for i in range(4))
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    m = (a > 25) & (a < 200) & (lum < 110)
    return m.sum()

def add_shadow(arr):
    """Draw a dithered ellipse under the sprite; sprite wins on overlap."""
    a = arr[..., 3]
    bb = content_bbox(a)
    if bb is None:
        return arr, None
    x0, y0, x1, y1 = bb
    h, w = a.shape
    cw = x1 - x0
    ew = max(10, int(cw * 0.72))
    eh = max(3, min(9, int(ew * 0.20)))
    if eh % 2 == 0:
        eh += 1
    cx = (x0 + x1) / 2 + 2            # sun upper-left -> shade lower-right
    cy = y1 - 1
    ex0, ey0 = int(cx - ew / 2), int(cy - eh / 2)
    ex1, ey1 = ex0 + ew, ey0 + eh
    sx0, sy0 = max(ex0, 0), max(ey0, 0)
    sx1, sy1 = min(ex1, w), min(ey1, h)
    if sx1 <= sx0 or sy1 <= sy0:
        return arr, {"skipped": "no room below sprite"}
    yy, xx = np.mgrid[sy0:sy1, sx0:sx1]
    nx = (xx + 0.5 - cx) / (ew / 2)
    ny = (yy + 0.5 - cy) / (eh / 2)
    rr = np.sqrt(nx * nx + ny * ny)
    inside = rr <= 1.0
    alpha = np.zeros(rr.shape)
    alpha[inside] = SHADOW_A
    edge = (rr > 0.72) & inside                      # soft rim
    alpha[edge] = SHADOW_A * 0.45
    dith = BAYER[yy % 2, xx % 2]                     # slight dither
    alpha = alpha * np.where(inside, dith, 1.0)
    alpha = alpha.round().astype(np.uint8)
    lay = np.zeros((sy1 - sy0, sx1 - sx0, 4), np.uint8)
    lay[..., :3] = SHADOW_RGB
    lay[..., 3] = alpha
    out = arr.copy()
    reg = out[sy0:sy1, sx0:sx1].astype(float)
    la = lay[..., 3:4].astype(float) / 255
    # under-composite: result = sprite over shadow
    da = reg[..., 3:4] / 255
    rgb = reg[..., :3] * da + lay[..., :3] * la * (1 - da)
    aa = da + la * (1 - da)
    reg[..., :3] = np.clip(rgb / np.maximum(aa, 1e-6), 0, 255)
    reg[..., 3:4] = aa * 255
    out[sy0:sy1, sx0:sx1] = reg.astype(np.uint8)
    return out, {"ellipse": [int(ex0), int(ey0), int(ew), int(eh)],
                 "shadow_px": int((alpha > 0).sum())}

def main():
    anchors, shadow_log, scale = {}, {}, {}
    for cat in COPY_CATS:
        src = os.path.join(STG, cat)
        dst = os.path.join(OUT, cat)
        os.makedirs(dst, exist_ok=True)
        for fn in sorted(os.listdir(src)):
            s = os.path.join(src, fn)
            if not fn.endswith(".png"):
                shutil.copy2(s, os.path.join(dst, fn))
                continue
            arr = np.array(Image.open(s).convert("RGBA"))
            bb = content_bbox(arr[..., 3])
            if bb is None:
                continue
            x0, y0, x1, y1 = bb
            key = f"{cat}/{fn}"
            if cat in ("decals", "icons", "font", "terrain"):
                anchors[key] = {"anchor_x": round((x0 + x1) / 2),
                                "anchor_y": round((y0 + y1) / 2),
                                "anchor": "center",
                                "content": [int(x0), int(y0), int(x1), int(y1)]}
            else:
                anchors[key] = {"anchor_x": round((x0 + x1) / 2),
                                "anchor_y": int(y1),
                                "anchor": "bottom-center",
                                "content": [int(x0), int(y0), int(x1), int(y1)]}
            if cat == "characters":
                scale.setdefault(fn.split("_")[0], []).append(y1 - y0)
            # shadow pass
            if cat in SHADOW_CATS and fn not in NO_SHADOW:
                if soft_dark_ratio(arr, bb) > 30:
                    shadow_log[key] = "has_soft_shadow"
                else:
                    out, info = add_shadow(arr)
                    shadow_log[key] = info or "synthesized"
                    arr = out
            elif cat in SHADOW_CATS:
                shadow_log[key] = "skipped (line prop)"
            Image.fromarray(arr).save(os.path.join(dst, fn))

    with open(os.path.join(OUT, "anchors.json"), "w") as f:
        json.dump(anchors, f, indent=1)
    with open(os.path.join(OUT, "shadow_log.json"), "w") as f:
        json.dump(shadow_log, f, indent=1)

    rep = {}
    for who, hs in scale.items():
        rep[who] = {"min": int(min(hs)), "max": int(max(hs)),
                    "mean": round(float(sum(hs)) / len(hs), 1),
                    "spec": 48,
                    "in_window_38_52": all(38 <= h <= 52 for h in hs)}
    rep["action"] = ("no resample per brief; sizes left as authored, "
                     "deviation noted")
    with open(os.path.join(OUT, "scale_report.json"), "w") as f:
        json.dump(rep, f, indent=1)
    print(json.dumps(rep, indent=1))
    synth = sum(1 for v in shadow_log.values()
                if isinstance(v, dict) and "ellipse" in v)
    print("anchors:", len(anchors), "shadows synthesized:", synth,
          "of", len(shadow_log))

if __name__ == "__main__":
    main()
