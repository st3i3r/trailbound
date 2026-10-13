#!/usr/bin/env python3
"""Dress a rendered PixelLab map ground to the Ground recipe.

Takes the flat painted render (view_map PNG — zones only) and adds the
texture layers Eastward carries inside the wash:

  1. tonal blotches  — low-freq noise, +-4-7% luminance per family
  2. patch dither    — irregular patches, ~50% checker at +-1 ramp step,
                       sampled from each family's own luminance quantiles
  3. speckles        — dirt: dark crack/stone specks; grass: blade dots;
                       water: horizontal tonal bands + shore foam dots
  4. edge blades     — 2-3px grass strokes crossing grass->dirt borders
  5. micro flowers   — rare cream dots inside grass only

Family masks come from palette-anchored nearest-class classification,
so it survives grading. Run AFTER the render is palette-snapped to the
site palette (tb_grade) or pass --pre-grade to skip family anchoring.

Usage:
  python tools/tb_ground_dress.py IN.png OUT.png [--seed 7]
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

rng_global = np.random.default_rng(7)

# family anchors (RGB) — sampled from the pinewatch_v2 render; the
# classifier only needs to split grass/dirt/water reliably
ANCH = {
    "grass": np.array([140, 190, 74]),
    "dirt":  np.array([206, 162, 96]),
    "water": np.array([70, 160, 160]),
}


def classify(a):
    """nearest-anchor family per pixel -> int map (0 grass,1 dirt,2 water)"""
    names = list(ANCH)
    d = np.stack([((a - ANCH[n]) ** 2).sum(-1) for n in names])
    return np.argmin(d, 0)


def smooth_noise(shape, rng, octaves=(8, 16)):
    """low-freq value noise 0..1"""
    out = np.zeros(shape)
    for o in octaves:
        g = rng.random((shape[0] // o + 2, shape[1] // o + 2))
        im = Image.fromarray((g * 255).astype(np.uint8)).resize(
            (shape[1], shape[0]), Image.BILINEAR)
        out += np.array(im) / 255.0
    return out / len(octaves)


# Eastward ramps sampled from refs/grade/ew_saiga.jpg (shade/mid/hi per
# family, RGB) — the painted ground is luminance-mapped onto these so
# the wash keeps its internal shading but snaps to the fresh palette.
SNAP = {
    0: [np.array([60, 112,  64]), np.array([140, 192,  78]),
        np.array([185, 222,  95])],                     # grass
    1: [np.array([109, 76,   43]), np.array([200, 155,  92]),
        np.array([232, 196, 138])],                     # dirt
    2: [np.array([62,  81,   87]), np.array([104, 165, 165]),
        np.array([150, 210, 205])],                     # water
}


def palette_snap(a, fam):
    """per family: LOCAL luminance -> position on the Eastward ramp.
    t comes from a 9px box-blurred luminance field — the sheet's baked
    checker dither averages out, so the ramp sets macro tone without
    amplifying micro-contrast into neon checkerboard."""
    lum_all = a.mean(2)
    lum_blur = np.array(Image.fromarray(lum_all.astype(np.uint8))
                        .filter(ImageFilter.BoxBlur(4)), dtype=np.float32)
    for f, ramp in SNAP.items():
        m = fam == f
        if not m.any():
            continue
        lum = lum_blur[m]
        lo, hi = np.quantile(lum, (0.05, 0.95))
        t = np.clip((lum - lo) / max(hi - lo, 1.0), 0, 1)
        lo_c, mid_c, hi_c = [c.astype(np.float32) for c in ramp]
        snap_c = np.where(
            t[:, None] < 0.5,
            lo_c + (mid_c - lo_c) * (t[:, None] * 2),
            mid_c + (hi_c - mid_c) * ((t[:, None] - 0.5) * 2))
        # blend: snapped macro colour + the pixel's own micro deviation
        dev = (a[m].mean(1) - lum_blur[m])[:, None]
        a[m] = np.clip(snap_c + dev * 0.7, 0, 255)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    seed = 7
    snap = True
    if "--seed" in sys.argv:
        seed = int(sys.argv[sys.argv.index("--seed") + 1])
    if "--no-snap" in sys.argv:
        snap = False
    light = "--light" in sys.argv   # flat tiles: sun-pools only, no specks
    rng = np.random.default_rng(seed)

    im = Image.open(src).convert("RGB")
    a = np.array(im).astype(np.float32)
    H, W = a.shape[:2]
    fam = classify(a)
    if snap:
        palette_snap(a, fam)

    # ---- 0. calm the wash: grass interiors run ~flat in the refs
    # (lime wash + soft sun patches, no blade clusters — dense gen-noise
    # reads as speckle at display size).  Median-filter grass pixels ONLY
    # (5px), keeping a 2px rim along boundaries crisp.
    flat = np.array(Image.fromarray(a.astype(np.uint8))
                    .filter(ImageFilter.MedianFilter(5)), dtype=np.float32)
    non_g = np.array(Image.fromarray((fam != 0).astype(np.uint8))
                     .filter(ImageFilter.MaxFilter(5)))
    interior = (fam == 0) & (non_g == 0)
    a[interior] = flat[interior]

    # ---- 1. tonal blotches — the visible "sun pool" patches in the ref
    # are larger and softer than generic noise: low octaves, grass gets
    # the warm-yellow pool shift like the shot.  Phase 5.2 correction:
    # amplitude ~halved — any frequency is fine if contrast stays
    # +-3-5%; higher amplitude was the "camo" complaint.
    for f, amp in ((0, 0.042), (1, 0.048), (2, 0.045)):
        n = smooth_noise((H, W), rng, (6, 12))
        n = (n - n.mean()) * 2.0 * amp              # +-amp
        a[fam == f] = np.clip(a[fam == f] * (1.0 + n[fam == f, None]), 0, 255)

    if light:
        # flat-generation tiles carry their own edge + micro texture —
        # dress only adds the macro wash; speckles/bands/blades skipped.
        # water: nudge hue toward the ref's green-teal (#309d80) —
        # teal->greener = lift G, pull B slightly (vectorized, not per-px)
        wm = fam == 2
        g = a[:, :, 1]; g[wm] = np.clip(g[wm] * 1.07, 0, 255)
        b = a[:, :, 2]; b[wm] = np.clip(b[wm] * 0.96, 0, 255)
        Image.fromarray(a.astype(np.uint8)).save(dst)
        print(f"dressed(light) {src} -> {dst} ({W}x{H})")
        return

    # ---- 2. patch dither: dirt keeps pockets; grass stays ~flat (a few
    # faint patches only — refs run the wash calm inside the field)
    for f, q, amp in ((0, 0.90, 0.05), (1, 0.72, 0.09)):
        n = smooth_noise((H, W), rng, (18, 36))
        patch = (fam == f) & (n > np.quantile(n[fam == f], q))
        ys, xs = np.where(patch)
        sel = (xs + ys) % 2 == 0
        xs, ys = xs[sel], ys[sel]
        mul = np.where(rng.random(len(xs)) < 0.5, -amp, amp)
        a[ys, xs] = np.clip(a[ys, xs] * (1.0 + mul[:, None]), 0, 255)

    # ---- 3a. dirt speckles: dark cracks + pale stones, sparse
    ys, xs = np.where(fam == 1)
    pick = rng.random(len(xs))
    dk = xs[pick < 0.004]; dy = ys[pick < 0.004]
    a[dy, dk] = np.clip(a[dy, dk] * 0.72, 0, 255)
    lt = xs[(pick > 0.004) & (pick < 0.007)]; ly = ys[(pick > 0.004) & (pick < 0.007)]
    a[ly, lt] = np.clip(a[ly, lt] * 1.18, 0, 255)

    # ---- 3b. grass: near-zero interior marks — a handful of cream dots
    ys, xs = np.where(interior)
    pick = rng.random(len(xs))
    fl = pick < 0.0012
    fx, fy = xs[fl], ys[fl]
    a[fy, fx] = [235, 228, 205]                            # rare flower dot

    # ---- 3c. water: horizontal bands + shore foam
    band = np.zeros((H, W), bool)
    for y0 in range(0, H, 26):
        band[y0 + int(rng.random() * 8):y0 + 10, :] = True
    wmask = (fam == 2) & band
    a[wmask] = np.clip(a[wmask] * 0.92, 0, 255)
    # foam dots along water boundary
    near = np.array(Image.fromarray((fam == 2).astype(np.uint8))
                    .filter(ImageFilter.MaxFilter(3))) & (fam == 0)
    ys, xs = np.where(near)
    sel = rng.random(len(xs)) < 0.08
    a[ys[sel], xs[sel]] = [215, 226, 224]

    # ---- 4. edge blades: grass strokes crossing into dirt
    gmask = fam == 0; dmask = fam == 1
    dil_g = np.array(Image.fromarray(gmask.astype(np.uint8))
                     .filter(ImageFilter.MaxFilter(5)))
    border = dil_g & dmask
    ys, xs = np.where(border)
    sel = rng.random(len(xs)) < 0.10
    for x, y in zip(xs[sel], ys[sel]):
        for k in range(1 + int(rng.random() * 2)):          # 1-2 px stroke
            xx, yy = x + k, y - k
            if 0 <= yy < H and 0 <= xx < W and fam[yy, xx] == 1:
                a[yy, xx] = np.array([96, 142, 68])       # grass-shade blade

    out = Image.fromarray(a.astype(np.uint8))
    out.save(dst)
    print(f"dressed {src} -> {dst} ({W}x{H})")


if __name__ == "__main__":
    main()
