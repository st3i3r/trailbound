#!/usr/bin/env python3
"""Trailbound ground tint-map baker — the 640x360 RGBA overlay that
carries ALL macro ground colour for a site (SOTA ground recipe: shape
in the calm tile, colour in a low-frequency tint field; tile-swap zones
are forbidden).

Output (byte-identical copies):
  assets_src/cleanup/ground_tintmap.png        pipeline/review master
  game/assets/pinewatch/fx/ground_tintmap.png  engine overlay

The engine draws it as a Sprite2D ("GroundTint") ABOVE Ground+Scatter
and BELOW World — it shades terrain + decals, never props or chars.
scene_comp_v2.py pastes the same file at the same stack point, so comp
and engine stay pixel-identical.  This is a lighting layer: it is
EXEMPT from palette snapping (see site_palette_v3.json note).

Layers (all soft-edged, deterministic seed 23):
  1. low-frequency value noise -> continuous warm-sun / cool-shade
     zones (alpha ~10-18%), faded out above the treeline sky band
  2. cool shade band under the treeline feet + pools under the big
     pines and the cabin's NE side (alpha peak ~22-30%)
  3. dry-warm drifts — path mouth + the tent/fire flat (alpha ~12%)
  4. sun pools — 3 soft radial gradients r~70-110 px, pale #ffe9b0,
     peak alpha ~24% — open field + picnic/van side

    python tools/tb_tintmap.py            # bake + copy to fx/
    python tools/tb_tintmap.py --check    # also %TEMP%/tb_review preview
"""
import argparse
import os
import shutil
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLN = os.path.join(ROOT, "assets_src", "cleanup")
FX = os.path.join(ROOT, "game", "assets", "pinewatch", "fx")
W, H = 640, 360
SEED = 23

# tint colours (source-over RGBA)
WARM = np.array((247, 222, 150), float)      # sun-warmed grass
COOL = np.array((74, 96, 138), float)        # canopy shade (cool blue)
DRY = np.array((217, 181, 121), float)       # worn dry ochre
SUN = np.array((255, 233, 176), float)       # #ffe9b0 sun pools

FIELD_A_WARM, FIELD_A_COOL = 0.14, 0.18      # noise-field peak alphas
SHADE_A, DRY_A, SUN_A = 0.26, 0.13, 0.24     # layer peak alphas
ALPHA_MAX = 0.30
SKY_FADE_Y = 105.0                           # noise dies out above this


def smooth_noise(rng, cell):
    """One octave of value noise: coarse random grid, bilinear-up."""
    gw, gh = int(W / cell) + 2, int(H / cell) + 2
    small = (rng.random((gh, gw)) * 255).astype(np.uint8)
    return np.array(Image.fromarray(small)
                    .resize((W, H), Image.BILINEAR)) / 255.0


def blob(x, y, cx, cy, r, sx=1.0, sy=1.0):
    """Soft radial gaussian, effectively gone by r (r = 2.5 sigma)."""
    d = ((x - cx) / sx) ** 2 + ((y - cy) / sy) ** 2
    return np.exp(-d / (2.0 * (r / 2.5) ** 2))


def bake():
    rng = np.random.default_rng(SEED)
    y, x = np.mgrid[0:H, 0:W].astype(float)

    # ---- 1. continuous warm/cool field -------------------------------
    f = np.zeros((H, W))
    for cell, amp in ((170, 1.0), (85, 0.45), (42, 0.2)):
        f += (smooth_noise(rng, cell) - 0.5) * 2.0 * amp
    f /= np.abs(f).max()                                  # -> [-1, 1]
    sky = np.clip((y - (SKY_FADE_Y - 45.0)) / 45.0, 0.0, 1.0)  # fade up-top
    warm_a = np.clip(f, 0.0, 1.0) * FIELD_A_WARM * sky
    cool_a = np.clip(-f, 0.0, 1.0) * FIELD_A_COOL * sky

    # ---- 2. treeline shade + under-canopy pools ----------------------
    band = np.exp(-((y - 172.0) / 46.0) ** 2)             # row-5 grass band
    band *= 0.75 + 0.25 * smooth_noise(rng, 60)  # ragged edge
    shade = band * 0.85
    for cx, cy, r, sx, sy in ((74, 150, 78, 1.0, 0.8),    # pine W
                              (156, 150, 70, 1.0, 0.8),   # pine W2
                              (540, 145, 80, 1.0, 0.8),   # pine E
                              (610, 170, 70, 1.0, 0.9),   # bamboo/spirit E
                              (470, 145, 62, 1.1, 0.85),  # cabin NE side
                              (270, 168, 66, 1.2, 0.8)):  # flamboyant S
        shade = np.maximum(shade, blob(x, y, cx, cy, r, sx, sy))
    cool_a = np.maximum(cool_a, shade * SHADE_A)

    # ---- 3. dry-warm drifts ------------------------------------------
    dry = np.maximum(blob(x, y, 390, 340, 60, 1.3, 0.8),  # path mouth
                     blob(x, y, 300, 258, 78, 1.4, 0.9))  # tent/fire flat
    dry_a = dry * DRY_A

    # ---- 4. sun pools -------------------------------------------------
    sun = np.zeros((H, W))
    for cx, cy, r in ((185, 292, 105),                    # open field W
                      (445, 300, 96),                     # picnic side
                      (112, 228, 74)):                    # van clearing
        sun = np.maximum(sun, blob(x, y, cx, cy, r))
    sun_a = sun * SUN_A

    # ---- compose (dry under shade under warm field under sun) --------
    # proper source-over on non-premultiplied colours:
    #   out_a = as + aa(1-as);  out_rgb = (cs*as + ca*aa(1-as))/out_a
    layers = [(DRY, dry_a), (COOL, cool_a),
              (WARM, warm_a), (SUN, sun_a)]
    acc = np.zeros((H, W, 4), float)
    for col, a in layers:
        a_s = np.clip(a, 0.0, 1.0)
        a_a = acc[..., 3]
        out_a = a_s + a_a * (1.0 - a_s)
        acc[..., :3] = (col[None, None, :] * a_s[..., None]
                        + acc[..., :3] * a_a[..., None]
                          * (1.0 - a_s[..., None])) \
            / np.maximum(out_a[..., None], 1e-6)
        acc[..., 3] = out_a
    acc[..., 3] = np.clip(acc[..., 3], 0.0, ALPHA_MAX) * 255.0
    return np.clip(acc, 0.0, 255.0).astype(np.uint8)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true",
                    help="emit %%TEMP%%/tb_review/tintmap_preview.png "
                         "(tint over flat mid-grey + alpha readout)")
    args = ap.parse_args()
    img = bake()
    dest = os.path.join(CLN, "ground_tintmap.png")
    Image.fromarray(img, "RGBA").save(dest)
    fx = os.path.join(FX, "ground_tintmap.png")
    os.makedirs(FX, exist_ok=True)
    shutil.copy2(dest, fx)
    a = img[..., 3] / 255.0
    print("tintmap 640x360 alpha: mean %.3f  p50 %.2f  p95 %.2f  max %.2f"
          % (a.mean(), np.percentile(a, 50), np.percentile(a, 95),
             a.max()))
    print("cover>10%%: %.1f%%   cover>20%%: %.1f%%"
          % ((a > 0.10).mean() * 100, (a > 0.20).mean() * 100))
    print("->", dest, "\n->", fx)
    if args.check:
        prev = np.zeros((H, W, 4), np.uint8)
        prev[..., :3] = 140
        prev[..., 3] = 255
        base = Image.fromarray(prev, "RGBA")
        base.alpha_composite(Image.fromarray(img, "RGBA"))
        side = Image.fromarray(img, "RGBA")   # raw RGBA on transparency
        out = Image.new("RGBA", (W * 2 + 8, H), (30, 30, 30, 255))
        out.paste(base, (0, 0))
        out.paste(side, (W + 8, 0), side)
        d = os.path.join(os.environ.get("TEMP", ROOT), "tb_review")
        os.makedirs(d, exist_ok=True)
        p = os.path.join(d, "tintmap_preview.png")
        out.save(p)
        print("->", p, "(left: over mid-grey, right: raw)")


if __name__ == "__main__":
    main()
