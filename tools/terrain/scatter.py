"""Stage E -- micro-detail scatter.

Poisson-disc rejection sampling places 1-2px specks inside zones, density and
tone rule per zone -- the worked-surface micro grammar the flat synth lacks:
  sunpool/lit/mid : sparse bright tuft flecks + occasional dark seed pixels
  pocket          : few dark flecks only
  dirt            : small pebble pairs (dark 2px + light 1px)
  water           : very sparse light sparkle, 1px
Never on struct pixels, never across boundaries (min dist >= spacing//2).
"""
import numpy as np
from scipy import ndimage
from .lib import ZONE_IDS

RULES = {
    'sunpool': dict(spacing=5, n_frac=0.020, br=((235, 255, 120), (210, 235, 90))),
    'lit': dict(spacing=5, n_frac=0.018, br=((200, 240, 110), (160, 195, 75))),
    'mid': dict(spacing=4, n_frac=0.022, br=((185, 215, 95), (140, 170, 65))),
    'pocket': dict(spacing=6, n_frac=0.012, br=((110, 130, 70),)),
    'dirt': dict(spacing=5, n_frac=0.016, br=((190, 190, 110), (140, 140, 70))),
    'water': dict(spacing=9, n_frac=0.004, br=((120, 220, 190),)),
    'water_deep': dict(spacing=12, n_frac=0.002, br=((90, 170, 150),)),
}


def poisson(mask, spacing, rng, n_frac):
    ys, xs = np.where(mask)
    if len(ys) == 0:
        return []
    area = len(ys)
    n = max(8, int(area * n_frac))
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    cell = spacing / np.sqrt(2)
    gw = int((x1 - x0 + 1) / cell) + 2
    gh = int((y1 - y0 + 1) / cell) + 2
    grid = np.zeros((gh, gw), np.int32) - 1
    pts = []
    tries = n * 30
    while len(pts) < n and tries > 0:
        tries -= 1
        i = rng.integers(0, len(ys))
        y, x = int(ys[i]), int(xs[i])
        gy, gx = int((y - y0) / cell), int((x - x0) / cell)
        ok = True
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                yy, xx = gy + dy, gx + dx
                if 0 <= yy < gh and 0 <= xx < gw and grid[yy, xx] >= 0:
                    py, px = pts[grid[yy, xx]]
                    if (py - y) ** 2 + (px - x) ** 2 < spacing * spacing:
                        ok = False
        if ok:
            grid[gy, gx] = len(pts)
            pts.append((y, x))
    return pts


def run(out, zmap, masks, rng):
    inner = {k: ndimage.binary_erosion(m, iterations=2)
             for k, m in masks.items() if k in RULES}
    for k, r in RULES.items():
        if k not in inner or not inner[k].any():
            continue
        pts = poisson(inner[k], r['spacing'], rng, r['n_frac'])
        for y, x in pts:
            col = np.array(r['br'][rng.integers(0, len(r['br']))], np.float32)
            out[y, x] = out[y, x] * .35 + col * .65
            if k == 'dirt' and rng.random() < .5 and x + 1 < out.shape[1]:
                out[y, x + 1] = out[y, x + 1] * .5 + col * .5   # 2px pebble
        print(f'  {k:10s} {len(pts):5d} specks')
    return out
