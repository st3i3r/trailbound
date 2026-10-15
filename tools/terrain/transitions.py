"""Stage D -- transitions: generated boundary treatment between zones.

For every adjacent zone pair, a pair-specific rule blends the synthesized
interiors across the shared boundary. Distance fields give smooth weights;
rules encode the material grammar measured from the ref:

  water -> land   : wet rim ring (darkened land within 2px of shore) +
                    1px shore-line darkening inside water edge
  dirt <-> grass  : scalloped encroach -- dirt specks invade grass, jittered
                    boundary via value noise
  grass <-> grass : wide soft wash blend (+-4px) -- continuous-tone fields
                    mix without visible cut
  *  -> struct    : struct pixels are never touched (outlines, rims, props)
"""
import numpy as np
from scipy import ndimage
from .lib import ZONE_IDS

GRASS = {'sunpool', 'lit', 'mid', 'pocket'}
LAND = GRASS | {'dirt'}


def _noise2(shape, cell, rng):
    g = np.zeros(shape, np.float32)
    hh, ww = shape[0] // cell + 2, shape[1] // cell + 2
    base = rng.random((hh, ww))
    for y in range(shape[0]):
        for x in range(shape[1]):
            fy, fx = y / cell, x / cell
            y0, x0 = int(fy), int(fx)
            ty, tx = fy - y0, fx - x0
            ty, tx = ty * ty * (3 - 2 * ty), tx * tx * (3 - 2 * tx)
            g[y, x] = (base[y0, x0] * (1 - ty) * (1 - tx) + base[y0, x0 + 1] * (1 - ty) * tx +
                       base[y0 + 1, x0] * ty * (1 - tx) + base[y0 + 1, x0 + 1] * ty * tx)
    return g


def run(out, base, zmap, masks, dist, rng):
    H, W = zmap.shape
    zi = {k: ZONE_IDS.index(k) for k in ZONE_IDS}
    water = masks['water'] | masks['water_deep']

    # --- 1. water shoreline: wet rim on land + inner shore line ---
    shore_in = ndimage.binary_dilation(water, iterations=2) & ~water & ~masks['struct']
    # wet rim: darken + desaturate land within 2px of water
    hsvv = out.copy()
    dark = hsvv * np.array([0.82, 0.92, 0.88], np.float32)
    out[shore_in] = dark[shore_in]
    # inner water edge: 1px darker-teal line just inside water
    line = masks['water'] & ~ndimage.binary_erosion(masks['water'], iterations=2)
    edge_deep = np.array([0x24, 0x86, 0x70], np.float32)
    grad = ndimage.distance_transform_edt(masks['water'])
    ring = masks['water'] & (grad <= 2.0)
    t = np.clip(1 - grad[ring] / 2.0, 0, 1)[..., None]
    out[ring] = out[ring] * (1 - 0.5 * t) + edge_deep * (0.5 * t)

    # --- 2. dirt<->grass: scalloped encroach (jittered boundary) ---
    jt = (_noise2((H, W), 7, rng) - .5) * 6.0            # +-3px scallop
    for gname in GRASS & set(zi) - {'pocket'}:
        mG = masks[gname]; mD = masks['dirt']
        if not (mG.any() and mD.any()):
            continue
        d = ndimage.distance_transform_edt(mG)          # dist into grass
        near = mG & (d <= 4.0 + jt)
        blend = np.clip(1 - d[near] / 5.0, 0, 1)[..., None] * 0.45
        dirt_tone = np.array([0xA8, 0xA8, 0x4E], np.float32)
        out[near] = out[near] * (1 - blend) + dirt_tone * blend

    # --- 3. grass<->grass soft washes (sunpool/lit/mid/pocket borders) ---
    for a in GRASS:
        for b in GRASS:
            if a >= b:
                continue
            mA, mB = masks[a], masks[b]
            touch = ndimage.binary_dilation(mA, iterations=2) & mB
            if not touch.any():
                continue
            dA = ndimage.distance_transform_edt(mB)     # inside B, dist to A
            band = mB & (dA <= 4)
            t = np.clip(1 - dA[band] / 4.0, 0, 1)[..., None]
            # pull toward A's tone via local mean of synthesized A pixels
            ref = out[mA].mean(0) if mA.any() else 0
            out[band] = out[band] * (1 - .35 * t) + ref * (.35 * t)

    # --- 4. struct pixels always preserved ---
    out[masks['struct']] = base[masks['struct']]
    return out
