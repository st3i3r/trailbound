"""Rebuild a props-free ground from a full scene render (e.g. _v13.png).

The render has props/trees/rocks BAKED IN. To use its composition as terrain:
  1. classify zone masses on a heavily blurred copy (props become local
     colour noise; masses survive)
  2. mark non-terrain pixels (struct: outlines, props, characters, trees)
  3. flood-fill struct areas with the NEAREST zone's identity (grass/dirt
     continue under props -- plausible because props sit on ground)
  4. synthesize every zone interior via the quilting pipeline

Output: same composition as the render, zero baked props.
Usage: python -m tools.terrain.rebuild_from assets_src/cleanup/_v13.png
"""
import sys
import numpy as np
from scipy import ndimage
from . import lib, fields, synth, transitions, scatter, validate, zones, exemplars as exb
from .lib import ZONE_IDS, LAYERS, save_rgb
from PIL import Image


def zone_map_from_render(src):
    g = lib.load_rgb(src)
    zmap = zones.classify(g)                          # blurred-mass classifier
    struct = zmap == ZONE_IDS.index('struct')
    # canopy band is dark AND saturated-dark: it may classify as water_deep.
    # Water must touch the water hue AND sit low-left-ish or in a coherent
    # blob: keep only water components whose mean raw colour is truly teal.
    h, s, v = lib.hsv(g)
    zi = ZONE_IDS
    for k in ('water', 'water_deep'):
        m = zmap == zi.index(k)
        lab, n = ndimage.label(m)
        keep = np.zeros_like(m)
        for i in range(1, n + 1):
            comp = lab == i
            mh = float(np.median(h[comp]))
            if 0.36 < mh < 0.52:                       # component is really teal
                keep |= comp
        zmap[m & ~keep] = zi.index('pocket')           # dark non-teal -> shade
    # struct -> nearest real zone (ground continues under props)
    filled = zmap.copy()
    st = filled == zi.index('struct')
    if st.any():
        _, idx = ndimage.distance_transform_edt(st, return_indices=True)
        filled[st] = filled[tuple(idx[:, st])]
    return filled


def run(src):
    rng = np.random.default_rng(11)
    zmap = zone_map_from_render(src)
    masks = {ZONE_IDS[i]: (zmap == i) for i in range(len(ZONE_IDS) - 1)}
    masks['struct'] = np.zeros(zmap.shape, bool)
    viz = np.zeros((*zmap.shape, 3), np.uint8)
    from .lib import ZONE_VIZ
    for i, k in enumerate(ZONE_IDS):
        viz[zmap == i] = ZONE_VIZ[k]
    save_rgb(viz, f'{LAYERS}/zones_rebuilt.png')
    for k in ZONE_IDS[:-1]:
        print(f'  {k:10s} {int(masks[k].sum()):7d}')

    dist, pairs, edge = fields.run(zmap, masks)
    base = np.zeros((*zmap.shape, 3), np.float32)     # nothing inherited
    ex = exb.gen_all(rng)
    out, cover = synth.run(zmap, masks, ex, base, rng)
    # uncovered pixels (2px erosion ring at every zone edge) -> nearest
    # synthesized pixel so no black seams
    if (~cover).any():
        _, idx = ndimage.distance_transform_edt(~cover, return_indices=True)
        out[~cover] = out[tuple(idx[:, ~cover])]
    out = transitions.run(out, base, zmap, masks, dist, rng)
    out = scatter.run(out, zmap, masks, rng)
    dst = 'assets_src/stage/ground_rebuilt.png'
    if out.shape[:2] != (384, 640):                  # scene ground is 640x384
        out = np.asarray(Image.fromarray(
            np.clip(out, 0, 255).astype(np.uint8)).resize(
            (640, 384), Image.BILINEAR)).astype(np.float32)
    save_rgb(out, dst)
    validate.run(out, masks)
    print('saved', dst)


if __name__ == '__main__':
    run(sys.argv[1] if len(sys.argv) > 1 else 'assets_src/cleanup/_v13.png')
