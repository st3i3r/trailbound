"""Stage A -- zone layer stack.

Classifies the painted ground into named zone layers (Houdini-style: each zone
is its own mask layer). Emits inspectable data, not just pixels:
  layers/zones.png      indexed visualization, one flat color per zone
  layers/zones.npz      zone index map + boolean mask per zone
  layers/zones.json     per-zone pixel counts

Classification = nearest measured anchor in RGB, gated to terrain-like pixels
(non-terrain: outlines, rocks, props -> 'struct', preserved verbatim).
"""
import numpy as np
from scipy import ndimage
from .lib import GROUND, LAYERS, ZONE_IDS, ANCHORS, ZONE_VIZ, load_rgb, save_rgb, dump_json, hsv


def classify(g):
    """Zones come from the *layout masses*, not per-pixel texture:
    blur hard (kills texture, keeps masses) -> nearest anchor -> drop small
    components -> leftovers take the nearest surviving zone."""
    H, W = g.shape[:2]
    sm = ndimage.gaussian_filter(g, sigma=(9, 9, 0))
    # struct is judged on RAW pixels (outlines/rims are detail, not masses);
    # zone masses are judged on the blurred field (texture must not flip zones)
    hr, sr, vr = hsv(g)
    terrain = (sr > 0.26) & (vr > 0.30)
    terrain = ndimage.binary_opening(terrain, iterations=1)
    keys = list(ANCHORS)
    D = np.stack([((sm - np.array(c, np.float32)) ** 2).sum(-1)
                  for c in ANCHORS.values()])
    best = D.argmin(0)
    zmap = np.where(terrain, best, ZONE_IDS.index('struct')).astype(np.int32)
    # drop specks: remove zone components smaller than 48px
    clean = np.full_like(zmap, -1)
    for i in range(len(ZONE_IDS) - 1):                    # skip struct
        m = zmap == i
        lab, n = ndimage.label(m)
        for j in range(1, n + 1):
            comp = lab == j
            if comp.sum() >= 48:
                clean[comp] = i
    # leftover terrain -> nearest surviving zone by distance transform
    orphans = terrain & (clean < 0)
    if orphans.any():
        _, idx = ndimage.distance_transform_edt(clean < 0, return_indices=True)
        clean[orphans] = clean[tuple(idx[:, orphans])]
    clean[~terrain] = ZONE_IDS.index('struct')
    return clean


def run(g=None, authored=True, bare=False):
    g = load_rgb(GROUND) if g is None else g
    if authored:
        from . import layout
        return layout.sketch_to_zones(base=None if bare else g)
    zmap = classify(g)
    ids = ZONE_IDS
    masks = {ids[i]: (zmap == i) for i in range(len(ids))}
    # gentle zone cleanup: fill 1-2px holes inside each mask
    for k, m in masks.items():
        if k == 'struct':
            continue
        masks[k] = ndimage.binary_fill_holes(m) & ~masks['struct']
    np.savez_compressed(f'{LAYERS}/zones.npz', zmap=zmap,
                        **{f'm_{k}': m for k, m in masks.items()})
    viz = np.zeros((*zmap.shape, 3), np.uint8)
    for i, k in enumerate(ids):
        viz[zmap == i] = ZONE_VIZ[k]
    save_rgb(viz, f'{LAYERS}/zones.png')
    stats = {k: int(m.sum()) for k, m in masks.items()}
    dump_json({'counts': stats, 'zone_ids': ids}, f'{LAYERS}/zones.json')
    for k in ids:
        print(f'  {k:10s} {stats[k]:7d}')
    return zmap, masks


if __name__ == '__main__':
    run()
