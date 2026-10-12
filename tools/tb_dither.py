#!/usr/bin/env python3
"""Trailbound mid-texture pass — bakes dither-patch texture into the three
graded+calmed wang terrain sheets (style_lock.md Ground recipe, "mid
texture" layer): irregular low-frequency-noise patches filled with
single-pixel dither at +-1-2 ramp steps, low amplitude, per-tile seed so
no two tiles share a pattern.  Runs AFTER `tb_grade.py --site
pinewatch_v2` + `tb_calm.py` (the sheets must already carry the shipped
grade); processes the copies in assets_src/out/terrain and mirrors
byte-identical over game/assets + staging — same contract as tb_calm.

Per tile (bounding_box + corners from each sheet's JSON tileset_data):

  0. pure fills only (wang_15 UUUU / wang_0 LLLL): erase the small baked
     flower/tuft sprigs — colour-outlier clusters vs the local inlier
     mean, pulled flat (see erase_sprigs).  They stamped identically on
     every fill cell; decals carry the meadow detail now.
  1. classify every opaque pixel grass vs the sheet's lower terrain
     (same hue/sat test as tb_grade/tb_calm, plus the CTX_MIN
     embedded-speck widening) — the painted boundary, not the corner
     bitmask, decides which region a pixel belongs to.
  2. patch field: seeded 2-octave value noise, thresholded so ~COV of
     the class's pixels land inside 2-4 irregular patches.
  3. dither: inside patches a jittered checker-cluster scatter (~60%
     density — parity flips with a mid-frequency phase field, so the
     marks clump instead of papering evenly) snaps the pixel +-1-2
     steps along a 4-6 tone ramp sampled from the tile's OWN class
     palette (luminance-quantile medians, deduped).  Outside patches a
     faint sparse scatter keeps the field from going dead-flat.
  4. edge blades: on transition tiles, sparse 1-3 px grass-dark strokes
     stamped just past the grass->lower boundary (~1 per 7 boundary px),
     leaning INTO the lower terrain.
  5. amplitude guard: dev_med (median |px - 5x5 mean| luminance,
     sampled every 2nd px) on the all-grass wang_15 tile reports at the
     end — target band ~3-7 (ref: eastward1 dirt ~2.6, grass ~7-9).
  6. fill variants: per sheet, VAR_N variants of each pure fill are
     written as standalone 32x32 PNGs (variant_<tag>_<UUUU|LLLL>_<i>)
     into all three pipeline dirs — v0 = the shipped tile, v1..5 =
     fresh dither passes on the sprig-erased pre-dither base with new
     seeds + new patch layouts.  make_tileset.py adds them to the
     tileset; pinewatch_test.gd/scene_comp_v2.py pick per cell by hash.

NOT idempotent (like grade/calm): re-running re-derives ramps from the
already-dithered palette.  Restore from pristine first:
    python tools/tb_grade.py --site pinewatch_v2 --from-pristine
    python tools/tb_calm.py --keep-grass 0.55 --grass-only
    python tools/tb_dither.py

    python tools/tb_dither.py --dry-run   # previews only, no writes
    python tools/tb_dither.py             # apply out/ + mirror + verify
"""
import argparse
import colorsys
import json
import math
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import png

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets_src", "out", "terrain")
MIRROR_DIRS = [
    os.path.join(ROOT, "game", "assets", "pinewatch", "terrain"),
    os.path.join(ROOT, "assets_src", "staging", "pinewatch", "terrain"),
]
REVIEW = os.path.join(os.environ.get("TEMP", ROOT), "tb_review")

T = 32                        # tile px — every wang tile is 32x32

# --------------------------------------------------------------- per-class
# cov    fraction of the class's pixels inside dither patches (lower
#        terrains ~15-40%; grass 0.62 — the retune needs the sampled
#        median px to land inside a patch or dev_med falls into the
#        quiet population and the whole-tile guard reads low)
# den    (on-parity, off-parity) fire rates -> in-patch dither density
# out    outside-patch sparse scatter rate — kept LOW (grass 0.07):
#        the retune dropped it from 0.30 so strong dithered patches
#        alternate with genuinely quiet zones (patch rhythm), instead
#        of papering the whole field with even "canvas filter" grain
# step   max ramp step (1 or 2)
# dark   P(sign = darker) — grass/dirt dither leans a touch darker
# minsp  min luminance span of the sampled ramp before it is widened
#        around the class median (B5's near-flat lower tiles ship ~2
#        unique colours — quantiles alone would collapse to zero-step)
CFG_GRASS = dict(cov=0.62, den=(0.95, 0.45), out=0.07,
                 step=2, p2=1.00, dark=0.55, minsp=20.0)
CFG_WATER = dict(cov=0.35, den=(0.88, 0.26), out=0.08,
                 step=1, p2=0.0, dark=0.50, minsp=0.0)
CFG_DIRT  = dict(cov=0.40, den=(0.92, 0.35), out=0.15,
                 step=2, p2=0.40, dark=0.52, minsp=20.0)
CFG_STONE = dict(cov=0.15, den=(0.90, 0.30), out=0.0,
                 step=1, p2=0.0, dark=0.50, minsp=0.0)

SHEETS = {
    "terrain_grass_water_pro_0.png":
        dict(seed=11, lower="water", cfg=CFG_WATER, blades=True,
             tag="water"),
    "terrain_grass_forest_pro_0.png":
        dict(seed=23, lower="dirt", cfg=CFG_DIRT, blades=True,
             tag="forest"),
    "terrain_grass_stone_pro_0.png":
        dict(seed=37, lower="stone", cfg=CFG_STONE, blades=True,
             tag="stone"),
}

# ------------------------------------------------------- fill variants
# The two pure fills per sheet (wang_15 = UUUU grass, wang_0 = LLLL
# lower terrain) stamp ~100 cells each — one baked pattern every 32px.
# We ship VAR_N variants per fill as standalone 32x32 PNGs
# (variant_<tag>_<UUUU|LLLL>_<i>.png), picked per-cell by a
# deterministic hash in pinewatch_test.gd / scene_comp_v2.py.
#   variant 0   = the in-sheet tile (post sprig-erase, shipped pass)
#   variants 1+ = fresh dither passes on the SAME sprig-erased
#                 pre-dither base with new seeds AND new patch layouts
#                 (octave cell/wrap/weight/phase per VAR_PATCH — every
#                 layout keeps cell*wrap == 32 so tiles stay seamless),
#                 same class CFGs/coverage as the shipped pass.
# tools/make_tileset.py VARIANT_SOURCES must mirror this ordering.
VAR_N = 6
FILLS = (("wang_15", "UUUU"), ("wang_0", "LLLL"))
VAR_SALT = (0, 0x9E37, 0x51AB, 0x85EB, 0xC2B2, 0x27D4)
VAR_PATCH = (None,                                     # v0 = shipped
             dict(ox=11.0, oy=5.0),
             dict(c1=32.0 / 3, w1=3, c2=8.0, w2=4, ox=3.0, oy=13.0),
             dict(c1=8.0, w1=4, c2=6.4, w2=5, wlo=0.66,
                  ox=7.0, oy=1.0),
             dict(c1=16.0, w1=2, c2=6.4, w2=5, ox=15.0, oy=9.0),
             dict(c1=32.0 / 3, w1=3, c2=32.0 / 6, w2=6, wlo=0.78,
                  ox=1.0, oy=7.0))
KEEP_SPRIG_VAR = 5        # one later variant may keep a subtle sprig

BLADE_PITCH = 7.0        # ~1 stroke per 7 boundary px (spec: 6-10)
CTX_MIN = 0.85           # embedded specks deep inside grass count as
                         # grass-family (same rule as tb_calm)
RIM_TAIL = 0.12          # darkest 12% of a lower region = edge rim /
                         # deep ripple shadow: exempt from dither so the
                         # wang rim shading keeps its clean dark line
AMAX = 12.0              # max luminance jump per dithered px — wide-span
                         # transition ramps would otherwise hop 20+


# ------------------------------------------------------------------ noise
def _ih(seed, x, y):
    """Deterministic lattice hash -> [0,1).  Pure int mix (splitmix-ish)."""
    n = (int(x) * 0x632BE5AB + int(y) * 0x85157AF5
         + int(seed) * 0x9E3779B1) & 0xFFFFFFFF
    n ^= n >> 13
    n = (n * 0x85EBCA6B) & 0xFFFFFFFF
    n ^= n >> 16
    return n / 4294967296.0


def vnoise(seed, x, y, cell, wrap=None):
    """Seeded value noise: smoothstep-interpolated random lattice.
    wrap=n makes the field periodic over n cells (lattice wraps mod n) —
    cells dividing 32 tile seamlessly."""
    fx, fy = x / cell, y / cell
    ix, iy = math.floor(fx), math.floor(fy)
    tx, ty = fx - ix, fy - iy
    tx = tx * tx * (3.0 - 2.0 * tx)
    ty = ty * ty * (3.0 - 2.0 * ty)
    if wrap:
        ix %= wrap
        iy %= wrap
        a = _ih(seed, ix, iy)
        b = _ih(seed, (ix + 1) % wrap, iy)
        c = _ih(seed, ix, (iy + 1) % wrap)
        d = _ih(seed, (ix + 1) % wrap, (iy + 1) % wrap)
    else:
        a = _ih(seed, ix, iy)
        b = _ih(seed, ix + 1, iy)
        c = _ih(seed, ix, iy + 1)
        d = _ih(seed, ix + 1, iy + 1)
    return a + (b - a) * tx + (c - a) * ty + (a - b - c + d) * tx * ty


def patch_field(seed, x, y, c1=16.0, w1=2, c2=8.0, w2=4, wlo=0.72,
                ox=0.0, oy=0.0):
    """2-octave field, PERIODIC over the 32 px tile (lattices wrap so
    cell*wrap == 32) -> irregular blobs that never clip at tile edges,
    so the fill tile tiles without seams.  Retune: low octave weighted
    up (0.72/0.28) for a touch wider patch spread — bigger blobs AND
    bigger quiet gaps, so the rhythm reads at field scale.

    Fill-variant passes override the layout: c/w pick a different
    lattice density (must keep cell*wrap == 32 or the tile stops
    being seamless), wlo rebalances the octaves, (ox,oy) slides the
    field phase — any offset stays periodic."""
    return wlo * vnoise(seed, x + ox, y + oy, c1, wrap=w1) \
        + (1.0 - wlo) * vnoise(seed + 0x51AB, x + ox, y + oy, c2,
                               wrap=w2)


# -------------------------------------------------------------- classify
def is_grass(r, g, b):
    """tb_grade/tb_calm hue test — works on the graded olive tones."""
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    return s > 0.22 and 50.0 <= h * 360.0 <= 145.0 and g > r and g >= b


def lum(r, g, b):
    return 0.299 * r + 0.587 * g + 0.114 * b


def classify_tile(tile):
    """tile: 32x32 list of (r,g,b,a).  -> (grass_ctx, lower, opaque)
    boolean masks.  grass_ctx widens the grass family to non-grass specks
    embedded deep inside it (CTX rule from tb_calm); lower = the rest of
    the opaque tile."""
    opaque = [[p[3] >= 128 for p in row] for row in tile]
    grass = [[opaque[y][x] and is_grass(*tile[y][x][:3])
              for x in range(T)] for y in range(T)]
    gctx = [[False] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            if not opaque[y][x]:
                continue
            if grass[y][x]:
                gctx[y][x] = True
                continue
            # 9x9 grass fraction (edge-clamped window)
            cnt = tot = 0
            for yy in range(max(0, y - 4), min(T, y + 5)):
                grow = grass[yy]
                for xx in range(max(0, x - 4), min(T, x + 5)):
                    tot += 1
                    cnt += grow[xx]
            gctx[y][x] = cnt >= CTX_MIN * tot
    lower = [[opaque[y][x] and not gctx[y][x]
              for x in range(T)] for y in range(T)]
    return gctx, lower, opaque


# ------------------------------------------------------------------ ramp
def build_ramp(px, minsp):
    """px: list of (r,g,b) of one class in one tile -> luminance-sorted
    ramp of <=5 REAL palette colours, evenly re-spaced between the p12
    and p88 luminance so every +-1 index step is a visible but small
    nudge.  Degenerate palettes (span < minsp) are widened around the
    median in HSV value so steps still land a few luminance units apart."""
    if not px:
        return []
    pts = sorted(px, key=lambda c: lum(*c))
    n = len(pts)
    # pick the widest percentile pair reaching minsp, so ramp colours are
    # always real palette samples; synth-widen only as a last resort
    lo = hi = None
    for pl, ph in ((12, 88), (8, 92), (5, 95), (2, 98), (0, 100)):
        a = pts[int(n * pl / 100.0)]
        b = pts[min(n - 1, int(n * ph / 100.0))]
        lo, hi = a, b
        if lum(*b) - lum(*a) >= max(minsp, 6.0):
            break
    span = lum(*hi) - lum(*lo)
    if span >= max(minsp, 6.0):
        # even luminance targets -> nearest sampled colour, no dupes
        ramp, used = [], set()
        for i in range(5):
            tgt = lum(*lo) + span * i / 4.0
            bi, bd = 0, 1e9
            for j, c in enumerate(pts):
                if j in used:
                    continue
                d = abs(lum(*c) - tgt)
                if d < bd:
                    bi, bd = j, d
            used.add(bi)
            ramp.append(pts[bi])
        if len(set(ramp)) >= 2:
            return sorted(set(ramp), key=lambda c: lum(*c))
    # widen around the median colour: keep hue/sat, spread value so
    # adjacent steps sit ~4-5 luminance units apart
    med = pts[n // 2]
    h, s, v = colorsys.rgb_to_hsv(med[0] / 255.0, med[1] / 255.0,
                                  med[2] / 255.0)
    gap = max(minsp, 10.0) / 4.0 / 255.0     # adjacent steps ~minsp/4 lum
    out = []
    for i in range(5):
        vv = min(1.0, max(0.0, v + (i - 2) * gap))
        r, g, b = colorsys.hsv_to_rgb(h, s, vv)
        c = (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)))
        if not out or c != out[-1]:
            out.append(c)
    return out


def ramp_idx(ramp_lum, l):
    """nearest ramp index for luminance l"""
    best, bd = 0, 1e9
    for i, rl in enumerate(ramp_lum):
        d = abs(rl - l)
        if d < bd:
            best, bd = i, d
    return best


# ----------------------------------------------------------------- dither
def dither_region(tile, mask, ramp, seed, cfg, pf=None):
    """Apply the patch-field + checker-cluster dither to mask pixels.
    Two passes: (1) calibrate the patch threshold so ~cov of the class
    lands inside, (2) scatter +-1-2 ramp steps inside patches, sparse
    +-1 scatter outside.  pf overrides the patch-field layout for fill
    variants (see patch_field); the phase field slides with it too."""
    pts = [(x, y) for y in range(T) for x in range(T) if mask[y][x]]
    if not pts or len(ramp) < 2:
        return 0
    pf = pf or {}
    ox, oy = pf.get("ox", 0.0), pf.get("oy", 0.0)
    fld = sorted(patch_field(seed, x, y, **pf) for x, y in pts)
    thr = fld[min(len(fld) - 1, int(len(fld) * (1.0 - cfg["cov"])))]
    ramp_lum = [lum(*c) for c in ramp]
    den_on, den_off = cfg["den"]
    step_max = cfg["step"]
    changed = 0
    for x, y in pts:
        inside = patch_field(seed, x, y, **pf) > thr
        parity = (x + y) & 1
        phase = vnoise(seed + 0x7A11, x + ox, y + oy, 5.0) > 0.5
        h = _ih(seed + 0x3C6E, x, y)
        if inside:
            fire = h < (den_on if parity == phase else den_off)
        else:
            fire = h < cfg["out"]
        if not fire:
            continue
        sign = -1 if _ih(seed + 0x51A9, x, y) < cfg["dark"] else 1
        step = 1 + (1 if step_max > 1
                    and _ih(seed + 0x2B99, x, y) < cfg["p2"] else 0)
        p = tile[y][x]
        pl = lum(*p[:3])
        i = ramp_idx(ramp_lum, pl)
        j = min(len(ramp) - 1, max(0, i + sign * min(step, step_max)))
        if j == i:
            j = min(len(ramp) - 1, max(0, i - sign))   # clamped: flip
        if j == i:
            continue
        c = ramp[j]
        dl = ramp_lum[j] - pl
        if abs(dl) > AMAX:          # wide-transition ramps can jump 20+
            f = AMAX / abs(dl)      # lum units — cap the luminance step
            c = tuple(int(round(p[k] + (c[k] - p[k]) * f))
                      for k in range(3))
        tile[y][x] = (c[0], c[1], c[2], p[3])
        changed += 1
    return changed


# ------------------------------------------------------------ rim guard
def rim_mask(mask, tile):
    """lower-region mask minus its darkest RIM_TAIL luminance tail —
    the wang edge rim / deep ripple shadow stays clean."""
    pts = [(x, y) for y in range(T) for x in range(T) if mask[y][x]]
    if not pts:
        return mask
    ls = sorted(lum(*tile[y][x][:3]) for x, y in pts)
    cut = ls[int(len(ls) * RIM_TAIL)]
    # only a tail sitting clearly BELOW the body counts as rim — on a
    # near-flat 2-colour tile the darkest 12% is just the base tone and
    # must not be carved away
    if cut >= ls[len(ls) // 2] - 12.0:
        return mask
    return [[mask[y][x] and lum(*tile[y][x][:3]) > cut
             for x in range(T)] for y in range(T)]


def hue_inliers(mask, tile, max_dh=55.0):
    """Drop class-region px whose hue is an outlier vs the region's
    circular median hue — e.g. warm-bank browns embedded in the water
    region must not be snapped toward teal (or vote in its ramp).
    Near-achromatic px (s<0.10) are kept: their hue is meaningless."""
    pts = [(x, y) for y in range(T) for x in range(T) if mask[y][x]]
    if len(pts) < 8:
        return mask
    hs = []
    for x, y in pts:
        h, s, v = colorsys.rgb_to_hsv(*[c / 255.0 for c in tile[y][x][:3]])
        if s > 0.10:
            hs.append(h * 360.0)
    if len(hs) < 8:
        return mask
    # circular median: mean angle of the hue cluster
    sa = sum(math.sin(math.radians(h)) for h in hs)
    ca = sum(math.cos(math.radians(h)) for h in hs)
    mid = math.degrees(math.atan2(sa, ca)) % 360.0
    out = [row[:] for row in mask]
    for x, y in pts:
        h, s, v = colorsys.rgb_to_hsv(*[c / 255.0 for c in tile[y][x][:3]])
        if s < 0.10:
            continue
        d = abs((h * 360.0 - mid + 180.0) % 360.0 - 180.0)
        if d > max_dh:
            out[y][x] = False
    return out


# ------------------------------------------------------------ sprig erase
# The pure fill tiles (wang_15 UUUU grass / wang_0 LLLL lower) carry 1-4
# small baked flower/tuft sprigs — PixelLab stamps the same marks in the
# shared grass texture of every sheet, so they repeat identically on
# every fill cell = the strongest tiling tell.  Detection: px whose RGB
# distance from the LOCAL INLIER MEAN (9x9 masked box mean over px within
# INLIER_D of the tile-median colour — sprigs never vote) exceeds
# SPRIG_SEED, flood-grown through px over SPRIG_GROW; components up to
# SPRIG_MAX px are pulled fully to the local mean (tb_calm-style).
# Thresholds sit between the sprig bodies (~31-33 px, dev 30-90) and the
# fills' natural tone patches (dev <25) / stone LLLL mottle (broad
# mid-dev fields that merge into oversized components -> auto-rejected).
SPRIG_SEED = 30.0
SPRIG_GROW = 15.0
SPRIG_MAX = 60
INLIER_D = 40.0


def _cd(a, b):
    return math.sqrt(sum((a[k] - b[k]) ** 2 for k in range(3)))


def local_mean(tile, donor):
    """9x9 masked box mean (edge-clamped, same window as classify_tile):
    returns mean[y][x] = (r,g,b) over donor-mask px."""
    out = [[None] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            s = [0.0, 0.0, 0.0]
            c = 0
            for yy in range(max(0, y - 4), min(T, y + 5)):
                drow = donor[yy]
                for xx in range(max(0, x - 4), min(T, x + 5)):
                    if drow[xx]:
                        p = tile[yy][xx]
                        s[0] += p[0]
                        s[1] += p[1]
                        s[2] += p[2]
                        c += 1
            if c:
                out[y][x] = (s[0] / c, s[1] / c, s[2] / c)
    return out


def erase_sprigs(tile):
    """Pull small colour-outlier clusters to the local inlier mean, in
    place.  Returns [ [(x,y,(r,g,b)), ...], ... ] — one entry per removed
    component (kept so a variant may re-stamp ONE subtle sprig)."""
    pts = [tile[y][x] for y in range(T) for x in range(T)
           if tile[y][x][3] >= 128]
    if len(pts) < 64:
        return []
    med = sorted(pts, key=lambda p: lum(*p[:3]))[len(pts) // 2][:3]
    donor = [[tile[y][x][3] >= 128 and _cd(tile[y][x][:3], med) < INLIER_D
              for x in range(T)] for y in range(T)]
    mean = local_mean(tile, donor)
    dev = [[0.0] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            if mean[y][x] is not None:
                dev[y][x] = _cd(tile[y][x][:3], mean[y][x])
    # hysteresis components: seed on dev>SPRIG_SEED, grow over dev>SPRIG_GROW
    seen = [[False] * T for _ in range(T)]
    removed = []
    for y in range(T):
        for x in range(T):
            if seen[y][x] or dev[y][x] <= SPRIG_SEED:
                continue
            comp, q, hit = [], [(x, y)], False
            seen[y][x] = True
            while q:
                cx, cy = q.pop()
                comp.append((cx, cy))
                hit = hit or dev[cy][cx] > SPRIG_SEED
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if (0 <= nx < T and 0 <= ny < T
                                and not seen[ny][nx]
                                and dev[ny][nx] > SPRIG_GROW):
                            seen[ny][nx] = True
                            q.append((nx, ny))
            # oversized / core-less blobs = natural texture, skip
            if not hit or len(comp) > SPRIG_MAX:
                continue
            saved = []
            for cx, cy in comp:
                p = tile[cy][cx]
                m = mean[cy][cx]
                saved.append((cx, cy, p[:3]))
                tile[cy][cx] = (int(round(m[0])), int(round(m[1])),
                                int(round(m[2])), p[3])
            removed.append(saved)
    return removed


def stamp_sprig(tile, comp, mean, faint=0.45):
    """Re-stamp one saved sprig component at `faint` strength toward the
    CURRENT local mean — a soft ghost, not the full baked mark."""
    for x, y, c in comp:
        m = mean[y][x]
        if m is None:
            continue
        p = tile[y][x]
        tile[y][x] = (int(round(m[0] + (c[0] - m[0]) * faint)),
                      int(round(m[1] + (c[1] - m[1]) * faint)),
                      int(round(m[2] + (c[2] - m[2]) * faint)), p[3])


# ------------------------------------------------------------ edge blades
def blades(tile, gctx, lower, grass_ramp, seed):
    """Sparse 1-3 px grass-dark strokes stamped just past grass->lower
    boundaries, leaning into the lower region."""
    bnd = []
    for y in range(T):
        for x in range(T):
            if not gctx[y][x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < T and 0 <= ny < T and lower[ny][nx]:
                    bnd.append((x, y))
                    break
    if not bnd or not grass_ramp:
        return 0
    tone = grass_ramp[0]                          # grass-dark ramp foot
    bnd.sort(key=lambda p: _ih(seed + 0xB1AD, p[0], p[1]))
    chosen = []
    for x, y in bnd:
        if all((x - cx) ** 2 + (y - cy) ** 2 >= BLADE_PITCH ** 2 * 0.55
               for cx, cy in chosen):
            chosen.append((x, y))
    made = 0
    for x, y in chosen:
        # dominant direction into the lower region (8-neighbour mean),
        # biased a half-step downward -> marks read as hanging blades
        sx = sy = 0.0
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                nx, ny = x + dx, y + dy
                if 0 <= nx < T and 0 <= ny < T and lower[ny][nx]:
                    sx += dx
                    sy += dy
        sy += 0.5                                  # lean down
        ln = math.hypot(sx, sy) or 1.0
        dx, dy = int(round(sx / ln)), int(round(sy / ln))
        if dx == 0 and dy == 0:
            dy = 1
        n = 1 + int(_ih(seed + 0x57E9, x, y) * 3)  # 1-3 px
        px, py = x, y
        for _ in range(n):
            px, py = px + dx, py + dy
            if not (0 <= px < T and 0 <= py < T) or not lower[py][px]:
                break
            p = tile[py][px]
            tile[py][px] = (tone[0], tone[1], tone[2], p[3])
            made += 1
    return made


# ------------------------------------------------------------- dev guard
def dev_med(tile, step=2):
    """median |px - 5x5 mean| luminance over the tile (sampled)."""
    ls = [[lum(*tile[y][x][:3]) for x in range(T)] for y in range(T)]
    devs = []
    for y in range(0, T, step):
        for x in range(0, T, step):
            s = c = 0
            for yy in range(max(0, y - 2), min(T, y + 3)):
                for xx in range(max(0, x - 2), min(T, x + 3)):
                    s += ls[yy][xx]
                    c += 1
            devs.append(abs(ls[y][x] - s / c))
    devs.sort()
    return devs[len(devs) // 2]


# ------------------------------------------------------------------ misc
def load_tile(rows, bx, by):
    return [[tuple(rows[by + y][(bx + x) * 4:(bx + x) * 4 + 4])
             for x in range(T)] for y in range(T)]


def store_tile(rows, tile, bx, by):
    for y in range(T):
        row = rows[by + y]
        for x in range(T):
            i = (bx + x) * 4
            p = tile[y][x]
            row[i:i + 4] = bytes((p[0], p[1], p[2], p[3]))


def run_tile(tile, corners, tseed, meta, pf=None):
    """The full per-tile pass: classify -> per-class ramp -> patch-dither
    -> edge blades (transitions only).  pf = patch-field layout override
    for fill variants.  Returns (grass_px, lower_px, blade_px)."""
    gctx, lower, _ = classify_tile(tile)
    n_lower = sum(1 for v in corners.values() if v == "lower")
    # ---- grass region
    gpx = [tile[y][x][:3] for y in range(T) for x in range(T)
           if gctx[y][x]]
    gramp = build_ramp(gpx, CFG_GRASS["minsp"])
    ng = dither_region(tile, gctx, gramp, tseed + 1, CFG_GRASS, pf)
    # ---- lower region (rim tail + hue outliers exempt — and kept
    # OUT of the ramp sample so rims/bank specks don't skew steps)
    lmask = hue_inliers(rim_mask(lower, tile), tile)
    lpx = [tile[y][x][:3] for y in range(T) for x in range(T)
           if lmask[y][x]]
    lramp = build_ramp(lpx, meta["cfg"]["minsp"])
    nl = dither_region(tile, lmask, lramp, tseed + 2, meta["cfg"], pf)
    # ---- edge blades (transition tiles only)
    nb = 0
    if 0 < n_lower < 4 and meta["blades"]:
        nb = blades(tile, gctx, lower, gramp, tseed + 3)
    return ng, nl, nb


def write_variant(tag, fill, i, tile):
    """Save one 32x32 variant PNG to out/ + both mirror dirs."""
    rows = [bytearray(T * 4) for _ in range(T)]
    for y in range(T):
        for x in range(T):
            rows[y][x * 4:x * 4 + 4] = bytes(tile[y][x])
    name = "variant_%s_%s_%d.png" % (tag, fill, i)
    png.write(os.path.join(OUT_DIR, name), T, T, rows)
    for d in MIRROR_DIRS:
        shutil.copy2(os.path.join(OUT_DIR, name), os.path.join(d, name))
    return name


def process_sheet(path, meta):
    """Dither one sheet in place + emit its fill-variant PNGs.
    Returns (per-tile report, variant file names)."""
    w, h, rows = png.read(path)
    data = json.load(open(path[:-4] + ".json"))
    tiles = data["tileset_data"]["tiles"]
    report = {}
    fill_base = {}          # tile name -> (pre-dither tile, corners,
                            #              sprig comps, bbox)
    for ti, t in enumerate(tiles):
        bx, by = int(t["bounding_box"]["x"]), int(t["bounding_box"]["y"])
        tile = load_tile(rows, bx, by)
        n_lower = sum(1 for v in t["corners"].values() if v == "lower")
        tseed = meta["seed"] * 1000 + ti * 97
        if n_lower in (0, 4):
            # pure fill: kill the baked sprigs BEFORE dithering (they
            # would otherwise pollute the ramp + repeat on every cell);
            # snapshot the sprig-erased pre-dither base for variants
            sprig = erase_sprigs(tile)
            fill_base[t["name"]] = ([r[:] for r in tile],
                                    t["corners"], sprig, (bx, by), ti)
            report_sprig = len(sprig)
        else:
            report_sprig = 0
        ng, nl, nb = run_tile(tile, t["corners"], tseed, meta)
        store_tile(rows, tile, bx, by)
        report[t["name"]] = (ng, nl, nb, report_sprig,
                             round(dev_med(tile), 2))
    png.write(path, w, h, rows)
    # ------------------------------------------------ fill variants
    # v0 = the shipped in-sheet tile (post sprig-erase + shipped dither
    # pass); v1..5 = fresh dither passes on the SAME sprig-erased
    # pre-dither base, new seeds + new patch layouts (VAR_PATCH).
    made = []
    for tname, fill in FILLS:
        base, corners, sprig, (bx, by), ti = fill_base[tname]
        tseed = meta["seed"] * 1000 + ti * 97
        for i in range(VAR_N):
            if i == 0:
                vt = load_tile(rows, bx, by)      # as-shipped tile
            else:
                vt = [r[:] for r in base]
                run_tile(vt, corners, tseed + VAR_SALT[i], meta,
                         VAR_PATCH[i])
                if i == KEEP_SPRIG_VAR and sprig:
                    # one subtle sprig survives in ONE variant — ghosted
                    # at 45% so it reads as a faint meadow mark, and it
                    # only shows on 1/6 of fill cells
                    comp = max(sprig, key=len)
                    if len(comp) >= 10:
                        pts = [vt[y][x] for y in range(T)
                               for x in range(T) if vt[y][x][3] >= 128]
                        med = sorted(pts, key=lambda p: lum(*p[:3]))[
                            len(pts) // 2][:3]
                        donor = [[vt[y][x][3] >= 128
                                  and _cd(vt[y][x][:3], med) < INLIER_D
                                  for x in range(T)] for y in range(T)]
                        stamp_sprig(vt, comp, local_mean(vt, donor))
            made.append(write_variant(meta["tag"], fill, i, vt))
    return report, made


# --------------------------------------------------------------- previews
def canvas(w, h, c=(26, 26, 30, 255)):
    return [bytearray(c * w) for _ in range(h)]


def blit(dst, tile, ox, oy, zoom=1):
    for y in range(T):
        for x in range(T):
            p = tile[y][x]
            for yy in range(zoom):
                row = dst[oy + y * zoom + yy]
                for xx in range(zoom):
                    i = (ox + x * zoom + xx) * 4
                    row[i:i + 4] = bytes(p)


def snap_sheet(name):
    """tiles dict name->tile from the CURRENT out/ sheet."""
    w, h, rows = png.read(os.path.join(OUT_DIR, name))
    data = json.load(open(os.path.join(OUT_DIR, name[:-4] + ".json")))
    out = {}
    for t in data["tileset_data"]["tiles"]:
        bb = t["bounding_box"]
        out[t["name"]] = (load_tile(rows, int(bb["x"]), int(bb["y"])),
                          t["corners"])
    return out


def dry_run():
    """Fill tile + 2 transition tiles through the dither; emit
    %TEMP%/tb_review/dither_dryrun.png (6x6 tiled before|after) and
    dither_transition.png (4x before|after).  Writes NOTHING."""
    import copy
    name = "terrain_grass_water_pro_0.png"
    tiles0 = snap_sheet(name)
    fill0 = copy.deepcopy(tiles0["wang_15"][0])
    tr0 = copy.deepcopy(tiles0["wang_12"][0])      # UULL: top grass /
                                                 # bottom water edge
    tr1_name, tr1 = "wang_14", None
    tilesF = snap_sheet("terrain_grass_forest_pro_0.png")
    tr1 = copy.deepcopy(tilesF[tr1_name][0])       # UULU corner

    def run(tile, seed, cfg, corners, do_blades=True):
        gctx, lower, _ = classify_tile(tile)
        gpx = [tile[y][x][:3] for y in range(T) for x in range(T)
               if gctx[y][x]]
        gramp = build_ramp(gpx, CFG_GRASS["minsp"])
        ng = dither_region(tile, gctx, gramp, seed + 1, CFG_GRASS)
        lmask = hue_inliers(rim_mask(lower, tile), tile)
        lpx = [tile[y][x][:3] for y in range(T) for x in range(T)
               if lmask[y][x]]
        lramp = build_ramp(lpx, cfg["minsp"])
        nl = dither_region(tile, lmask, lramp, seed + 2, cfg)
        nb = 0
        nl_c = sum(1 for v in corners.values() if v == "lower")
        if do_blades and 0 < nl_c < 4:
            nb = blades(tile, gctx, lower, gramp, seed + 3)
        return ng, nl, nb, gramp, lramp, dev_med(tile)

    fill = copy.deepcopy(fill0)
    ng, nl, nb, gramp, _, dm1 = run(fill, 11000 + 15 * 97, CFG_WATER,
                                   tiles0["wang_15"][1])
    dm0 = dev_med(fill0)
    print("fill tile: grass dithered %d px  dev_med %.2f -> %.2f "
          "(band 3-7)" % (ng, dm0, dm1))
    print("  grass ramp:", gramp)

    tr = copy.deepcopy(tr0)
    r = run(tr, 11000 + 12 * 97, CFG_WATER, tiles0["wang_12"][1])
    print("water wang_12: grass %d  water %d  blades %d  dev_med %.2f"
          % (r[0], r[1], r[2], r[5]))
    print("  water ramp:", r[4])
    trf = copy.deepcopy(tr1)
    rf = run(trf, 23000 + 14 * 97, CFG_DIRT, tilesF[tr1_name][1])
    print("forest wang_14: grass %d  dirt %d  blades %d  dev_med %.2f"
          % (rf[0], rf[1], rf[2], rf[5]))
    print("  dirt ramp:", rf[4])

    # 6x6 tiled fill preview, before over after, at 2x
    os.makedirs(REVIEW, exist_ok=True)
    S = 6 * T * 2
    cv = canvas(S, S * 2 + 8)
    for gy in range(6):
        for gx in range(6):
            blit(cv, fill0, gx * T * 2, gy * T * 2, 2)
            blit(cv, fill, gx * T * 2, S + 8 + gy * T * 2, 2)
    p1 = os.path.join(REVIEW, "dither_dryrun.png")
    png.write(p1, S, S * 2 + 8, cv)

    # transition tiles at 4x: before | after pairs stacked
    cv2 = canvas(T * 4 * 2 + 8, (T * 4) * 2 + 8)
    blit(cv2, tr0, 0, 0, 4)
    blit(cv2, tr, T * 4 + 8, 0, 4)
    blit(cv2, tr1, 0, T * 4 + 8, 4)
    blit(cv2, trf, T * 4 + 8, T * 4 + 8, 4)
    p2 = os.path.join(REVIEW, "dither_transition.png")
    png.write(p2, T * 4 * 2 + 8, T * 4 * 2 + 8, cv2)
    print("->", p1, "\n->", p2,
          "\n(top: before 6x6 tiled, bottom: after; "
          "transitions 4x before|after)")


def variants_preview():
    """6x6 grass field painted exactly like the engine — per-cell variant
    pick hash (tx*31+ty*17+src)%6 on the water UUUU pool at 2x — plus the
    adjacency report (identical neighbours should sit ~1/VAR_N, not 1.0).
    -> %TEMP%/tb_review/variants_preview.png"""
    os.makedirs(REVIEW, exist_ok=True)
    pool = []
    for i in range(VAR_N):
        w, h, rows = png.read(os.path.join(
            OUT_DIR, "variant_water_UUUU_%d.png" % i))
        pool.append(load_tile(rows, 0, 0))
    G, Z = 6, 2
    cv = canvas(G * T * Z, G * T * Z)
    pick = {}
    for gy in range(G):
        for gx in range(G):
            i = (gx * 31 + gy * 17 + 0) % VAR_N     # engine hash, src=0
            pick[(gx, gy)] = i
            blit(cv, pool[i], gx * T * Z, gy * T * Z, Z)
    p = os.path.join(REVIEW, "variants_preview.png")
    png.write(p, G * T * Z, G * T * Z, cv)
    same = tot = 0
    for gy in range(G):
        for gx in range(G):
            for dx, dy in ((1, 0), (0, 1)):
                if (gx + dx, gy + dy) in pick:
                    tot += 1
                    same += pick[(gx, gy)] == pick[(gx + dx, gy + dy)]
    print("->", p)
    print("   adjacency: %d/%d identical neighbour pairs "
          "(chance ~%.0f%%)" % (same, tot, 100.0 / VAR_N))


# ------------------------------------------------------------------ main
def main():
    ap = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true",
                    help="previews only — no sheet writes")
    args = ap.parse_args()
    if args.dry_run:
        dry_run()
        return
    all_vars = []
    for name, meta in SHEETS.items():
        path = os.path.join(OUT_DIR, name)
        rep, made = process_sheet(path, meta)
        all_vars += made
        dst = os.path.join(OUT_DIR, name)
        for d in MIRROR_DIRS:
            shutil.copy2(dst, os.path.join(d, name))
        print("%-38s" % name)
        for tn, (ng, nl, nb, ns, dm) in sorted(rep.items()):
            tag = "  sprigs-%d" % ns if ns else ""
            print("   %-8s grass+%-4d lower+%-4d blades %-2d dev_med %.2f%s"
                  % (tn, ng, nl, nb, dm, tag))
    # byte-identical check (sheets + every variant PNG)
    import hashlib as _h
    ok = True
    for name in list(SHEETS) + all_vars:
        ref = _h.md5(open(os.path.join(OUT_DIR, name), "rb")
                     .read()).hexdigest()
        for d in MIRROR_DIRS:
            m = _h.md5(open(os.path.join(d, name), "rb")
                       .read()).hexdigest()
            if m != ref:
                ok = False
                print("MISMATCH", os.path.join(d, name))
    print("mirror byte-identical:", ok, "(%d variant tiles)" % len(all_vars))
    variants_preview()
    print("synced ->", *MIRROR_DIRS, sep="\n         ")


if __name__ == "__main__":
    main()
