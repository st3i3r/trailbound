"""Stage B -- skeleton fields.

From zone masks derives the geometric skeleton the detail stages consume:
  dist[z]     signed distance to zone z boundary (px, float; + inside)
  pairs       adjacent zone pairs (for transition synthesis)
  shore       distance field into water from shoreline (for rim rings)
  edge        thin ring around every zone boundary (kept struct/edge pass)
Emits layers/fields.npz + layers/dist_<zone>.png heatmaps for inspection.
"""
import numpy as np
from scipy import ndimage
from .lib import LAYERS, ZONE_IDS, save_rgb


def dist_signed(mask):
    """+d inside mask, -d outside, 0 at boundary."""
    din = ndimage.distance_transform_edt(mask)
    dout = ndimage.distance_transform_edt(~mask)
    return din - dout


def zone_adjacency(zmap, maxgap=6):
    """Pairs of zones whose dilated footprints overlap (transition candidates)."""
    pairs = set()
    for i in range(len(ZONE_IDS)):
        mi = ndimage.binary_dilation(zmap == i, iterations=maxgap)
        for j in range(i + 1, len(ZONE_IDS)):
            if (mi & (zmap == j)).any():
                pairs.add((ZONE_IDS[i], ZONE_IDS[j]))
    return sorted(pairs)


def heat(d, lo=-6, hi=6):
    t = np.clip((d - lo) / (hi - lo), 0, 1)
    return np.stack([t * 255, (1 - np.abs(t - .5) * 2) * 255, (1 - t) * 255], -1)


def run(zmap, masks):
    dist = {k: dist_signed(masks[k]) for k in masks}
    pairs = zone_adjacency(zmap)
    edge = np.zeros(zmap.shape, bool)
    for m in masks.values():
        edge |= ndimage.binary_erosion(m, iterations=1) ^ m
    np.savez_compressed(f'{LAYERS}/fields.npz',
                        **{f'd_{k}': d for k, d in dist.items()},
                        edge=edge)
    for k, d in dist.items():
        save_rgb(heat(d), f'{LAYERS}/dist_{k}.png')
    save_rgb(heat(np.where(edge, 0, 8), -1, 8), f'{LAYERS}/edge.png')
    print('  adjacency:', pairs)
    return dist, pairs, edge
