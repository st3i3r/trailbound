#!/usr/bin/env python3
"""Trailbound de-noise pass — calms the baked micro-detail in the wang
terrain sheets AFTER the tb_grade.py colour pass.

Eastward ground is a near-flat tone wash with sparse clustered detail;
the PixelLab sheets instead carry uniform freckle scatter (dark tufts +
pale flower dots every ~10-20 px on grass, a regular waffle bump on the
dirt band, fine ripple specks on water).  For every pixel this computes
the local mean of ITS OWN class (masked box blur — grass means never
borrow dirt/water px, so transition fringes keep their edge contrast)
and rescales the pixel's deviation from that mean:

    new = local_mean + (px - local_mean) * KEEP

KEEP < 1 shrinks freckle-scale contrast while variation larger than the
blur window survives untouched — a soft wash, not a flat fill.

    grass  keep 0.45  (tufts -> faint value noise, flowers ~absorbed)
    dirt   keep 0.65  (waffle-dot softened ~35 %, ochre tone kept)
    water  keep 0.80  (tiniest ripple specks -20 %)
    stone  untouched (only its grass side is calmed)

NOT idempotent like the grade: run on freshly graded sheets
(tools/tb_grade.py --from-pristine), then re-run this once.  Processes
the copies in assets_src/out/terrain and copies the results over the
other two pipeline dirs so all nine files stay byte-identical.

    python tools/tb_calm.py            # calm + sync all 3 dirs
    python tools/tb_calm.py --check    # also emit a 2x before/after crop
"""
import argparse
import os
import shutil
import sys
import colorsys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import png

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets_src", "out", "terrain")
MIRROR_DIRS = [
    os.path.join(ROOT, "game", "assets", "pinewatch", "terrain"),
    os.path.join(ROOT, "assets_src", "staging", "pinewatch", "terrain"),
]

# sheet -> (lower-terrain keep factor).  Grass is treated in every sheet.
SHEETS = {
    "terrain_grass_water_pro_0.png":  {"lower": 0.80},   # ripple specks
    "terrain_grass_forest_pro_0.png": {"lower": 0.65},   # waffle bumps
    "terrain_grass_stone_pro_0.png":  {"lower": 1.00},   # stone kept
}
KEEP_GRASS = 0.40
R_GRASS = 4          # 9x9 window — covers 1-4 px tufts/flowers
R_LOWER = 3          # 7x7 window for dirt waffle / ripple specks
# B5 regenerated sheets arrive already calm (prompted flat-wash); the v2
# re-grade run uses --keep-grass 0.55 --grass-only so residual sprigs are
# absorbed while the soft large tonal patches survive untouched.
CTX_MIN = 0.85       # non-grass px this deep inside grass count as
                     # grass-family specks (pale flowers / soil flecks
                     # fail the hue test but must be absorbed, while
                     # transition-fringe dithers next to real dirt keep
                     # their edge contrast)


def is_grass(r, g, b):
    """Same test as tb_grade.classify, slightly looser — works on the
    already-graded olive tones as well as the pristine lime."""
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    return s > 0.22 and 50.0 <= h * 360.0 <= 145.0 and g > r and g >= b


def box_mean(arr, r):
    """Edge-padded 2r+1 box mean of a 2-D float array."""
    p = np.pad(arr, r, mode="edge")
    c = p.cumsum(0).cumsum(1)
    c = np.pad(c, ((1, 0), (1, 0)))
    k = 2 * r + 1
    return (c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]) / (k * k)


def calm(rgb, apply_mask, keep, radius, mean_mask=None):
    """Pull apply_mask pixels toward the masked local mean; returns rgb.
    mean_mask (default: apply_mask) controls which pixels vote in the
    mean — specks kept OUT of the mean get absorbed harder."""
    if keep >= 1.0 or not apply_mask.any():
        return
    if mean_mask is None:
        mean_mask = apply_mask
    m = mean_mask.astype(float)
    den = box_mean(m, radius)
    for ch in range(3):
        mean = box_mean(rgb[..., ch] * m, radius) / np.maximum(den, 1e-6)
        # isolated px (no same-class neighbour): mean ~ px, no change
        dev = (rgb[..., ch] - mean) * (1.0 - keep)
        rgb[..., ch] = np.where(apply_mask, mean + dev, rgb[..., ch])


def calm_sheet(path, lower_keep, keep_grass=KEEP_GRASS):
    w, h, rows = png.read(path)
    arr = np.asarray(rows, dtype=np.uint8).reshape(h, w, 4).astype(float)
    rgb, alpha = arr[..., :3], arr[..., 3]
    opaque = alpha > 128
    grass = np.zeros((h, w), bool)
    it = np.nditer(opaque, flags=["multi_index"])
    for px in it:
        if not px:
            continue
        y, x = it.multi_index
        if is_grass(*rgb[y, x]):
            grass[y, x] = True
    # widen the grass family to specks embedded deep inside it
    gfrac = box_mean(grass.astype(float), R_GRASS)
    grass_ctx = opaque & (grass | (gfrac >= CTX_MIN))
    calm(rgb, grass_ctx, keep_grass, R_GRASS, mean_mask=grass)
    calm(rgb, opaque & ~grass_ctx, lower_keep, R_LOWER)
    out = arr.copy()
    out[..., :3] = np.clip(np.round(rgb), 0, 255)
    png.write(path, w, h,
              [bytearray(r) for r in out.astype(np.uint8).reshape(h, w * 4)])
    return grass_ctx, opaque


def emit_check(before, after, path):
    """2x-zoomed before|after: the all-grass UUUU tile + a transition
    strip so edge crispness is visible at a glance."""
    try:
        from PIL import Image
    except ImportError:
        print("PIL unavailable — calm_check.png skipped")
        return
    def crop_rows(rows, box):
        x0, y0, x1, y1 = box
        w_, h_ = x1 - x0, y1 - y0
        im = Image.new("RGBA", (w_, h_))
        px = im.load()
        for y in range(h_):
            row = rows[y0 + y]
            for x in range(w_):
                px[x, y] = tuple(row[(x0 + x) * 4:(x0 + x) * 4 + 4])
        return im.resize((w_ * 2, h_ * 2), Image.NEAREST)
    boxes = [(0, 96, 32, 128), (0, 64, 64, 96)]     # UUUU + 2x1 transitions
    ims = []
    for b in boxes:
        ims.append(crop_rows(before, b))
        ims.append(crop_rows(after, b))
    W = sum(i.width for i in ims) + 8 * (len(ims) - 1)
    out = Image.new("RGBA", (W, max(i.height for i in ims)))
    x = 0
    for im in ims:
        out.paste(im, (x, 0))
        x += im.width + 8
    dest = os.path.join(os.environ.get("TEMP", ROOT), "tb_review")
    os.makedirs(dest, exist_ok=True)
    p = os.path.join(dest, "calm_check.png")
    out.save(p)
    print("->", p, "(before|after pairs: UUUU, transitions)")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true",
                    help="emit %%TEMP%%/tb_review/calm_check.png")
    ap.add_argument("--keep-grass", type=float, default=KEEP_GRASS,
                    help="grass deviation keep factor (default %.2f; "
                         "higher = lighter touch)" % KEEP_GRASS)
    ap.add_argument("--grass-only", action="store_true",
                    help="leave the lower terrains (water ripple / dirt "
                         "waffle) untouched — grass fill only")
    args = ap.parse_args()
    for name, cfg in SHEETS.items():
        path = os.path.join(OUT_DIR, name)
        w, h, before = png.read(path)
        before = [bytearray(r) for r in before]
        lower = 1.0 if args.grass_only else cfg["lower"]
        grass, opaque = calm_sheet(path, lower, args.keep_grass)
        print("calmed %-52s grass %d/%d px keep %.2f r%d | lower keep %.2f"
              % (path, grass.sum(), opaque.sum(), args.keep_grass, R_GRASS,
                 lower))
        for d in MIRROR_DIRS:
            shutil.copy2(path, os.path.join(d, name))
        if args.check:
            w2, h2, after = png.read(path)
            emit_check(before, after, path)
    print("synced ->", *MIRROR_DIRS, sep="\n         ")


if __name__ == "__main__":
    main()
