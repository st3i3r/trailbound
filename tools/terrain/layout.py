"""Stage A (authored) -- layout sketch -> zone map.

The zone layer is AUTHORED, not recovered from finished pixels. We paint a
160x96 indexed sketch from geometric primitives (pond, stream, road, plaza,
sun pools, pockets), then upsample x4 -> 640x384 zone map.

layers/layout.png  is the sketch -- it is SOURCE DATA: hand-edit it in
Aseprite (only the 8 zone colors) and the whole terrain regenerates.
Falls back to image-classification only if layout.png is absent.

Composition (Pinewatch): waterfall/stream enters top-left, widens into the
west pond; guest road enters from the right edge to the central fire plaza;
hut yard upper-right; sun pools break over the open lawn; pocket shade under
the tree line and behind the hut yard.
"""
import numpy as np
from PIL import Image
from scipy import ndimage
from .lib import LAYERS, ZONE_IDS, ZONE_VIZ, save_rgb, dump_json

W4, H4 = 640, 384          # full res
WL, HL = 160, 96           # sketch res
Z = {k: i for i, k in enumerate(ZONE_IDS)}
rng = np.random.default_rng(7)


def _blob(m, z, cx, cy, rx, ry, rot=0.0, wob=0.0):
    """Wobbled ellipse -> zone pixels."""
    yy, xx = np.mgrid[0:HL, 0:WL]
    ca, sa = np.cos(rot), np.sin(rot)
    dx, dy = xx - cx, yy - cy
    u = (dx * ca + dy * sa) / rx
    v = (-dx * sa + dy * ca) / ry
    ang = np.arctan2(v, u)
    r = np.sqrt(u * u + v * v)
    w = 1 + wob * np.sin(3 * ang + cx) + wob * .6 * np.sin(5 * ang + cy)
    m[r < w] = z


def _path(m, z, pts, width):
    """Thick polyline -> zone pixels (road/stream)."""
    yy, xx = np.mgrid[0:HL, 0:WL]
    d = np.full((HL, WL), 1e9, np.float32)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        vx, vy = x1 - x0, y1 - y0
        t = np.clip(((xx - x0) * vx + (yy - y0) * vy) / max(vx * vx + vy * vy, 1e-6), 0, 1)
        d = np.minimum(d, np.sqrt((xx - (x0 + t * vx)) ** 2 + (yy - (y0 + t * vy)) ** 2))
    m[d <= width / 2] = z


def paint_sketch():
    """v13 composition: pond bottom-left with stone path, dirt fire plaza
    centre, road spur right, open lawn dominant, shade under tree line."""
    m = np.full((HL, WL), Z['lit'], np.int32)          # base = lit grass
    # mid-grass masses: broad regions under tree line + field edges
    _blob(m, Z['mid'], 40, 14, 46, 12, wob=.2)
    _blob(m, Z['mid'], 130, 18, 34, 14, wob=.18)
    _blob(m, Z['mid'], 150, 70, 22, 20, wob=.15)
    _blob(m, Z['mid'], 20, 60, 18, 18, wob=.2)
    # pond: bottom-left, irregular; deep core
    _blob(m, Z['water'], 12, 86, 24, 14, wob=.22)
    _blob(m, Z['water'], 30, 80, 12, 9, wob=.2)
    _blob(m, Z['water_deep'], 10, 88, 13, 9, wob=.18)
    # dirt: fire plaza centre + path spurs right + gate apron
    _blob(m, Z['dirt'], 108, 60, 22, 15, wob=.22)                    # plaza
    _path(m, Z['dirt'], [(108, 60), (135, 66), (160, 70)], 8)        # road out right
    _path(m, Z['dirt'], [(104, 56), (96, 40), (98, 30)], 5)          # spur up
    # sun pools on the open lawn
    _blob(m, Z['sunpool'], 60, 55, 30, 18, wob=.25)
    _blob(m, Z['sunpool'], 120, 40, 18, 11, wob=.25)
    _blob(m, Z['sunpool'], 45, 88, 16, 8, wob=.2)
    _blob(m, Z['sunpool'], 145, 90, 15, 8, wob=.2)
    # pockets: tree-line shade band on top, plus dark lawn islands
    _blob(m, Z['pocket'], 60, 3, 34, 7, wob=.3)
    _blob(m, Z['pocket'], 130, 5, 28, 8, wob=.3)
    _blob(m, Z['pocket'], 88, 78, 10, 6, wob=.25)
    _blob(m, Z['pocket'], 30, 40, 9, 6, wob=.25)
    return m


def struct_from(base, water_zone_mask=None):
    """Detect non-terrain pixels (outlines, rims, props) in the base render.
    Keep only coherent pieces: components >= 40px, OR anything hugging the
    waterline (shore rim rocks). Isolated fragments read as specks."""
    from .lib import hsv
    h, s, v = hsv(base)
    st = (v < 0.30) | (s < 0.26)
    st = ndimage.binary_opening(st, iterations=1)
    # layout changed -> only struct that hugs the authored waterline survives
    # (shore rim rocks); old prop shadows elsewhere are dropped
    near_water = (ndimage.binary_dilation(water_zone_mask, iterations=8)
                  if water_zone_mask is not None else np.zeros_like(st))
    keep = np.zeros_like(st)
    lab, n = ndimage.label(st)
    for i in range(1, n + 1):
        comp = lab == i
        if (comp & near_water).any() or comp.sum() >= 90:
            keep |= comp
    return keep


def sketch_to_zones(base=None):
    """Paint (or load) sketch -> full-res zmap + masks + npz + viz."""
    p = f'{LAYERS}/layout.png'
    sketch = paint_sketch()
    viz = np.zeros((HL, WL, 3), np.uint8)
    for k, i in Z.items():
        viz[sketch == i] = ZONE_VIZ[k]
    save_rgb(viz, p)                                   # editable sketch
    # x4 upsample with ORGANIC boundaries: per-zone mask -> bicubic ->
    # noise-jittered threshold. Nearest upsample leaves visible 4px steps.
    nz = len(ZONE_IDS) - 1
    wob = (ndimage.gaussian_filter(rng.random((H4, W4)), 3) - .5) * 0.5
    votes = np.zeros((nz, H4, W4), np.float32)
    for i in range(nz):
        m = (sketch == i).astype(np.float32)
        soft = np.asarray(Image.fromarray(m).resize((W4, H4), Image.BICUBIC))
        votes[i] = soft
    zmap = (votes + wob[None]).argmax(0).astype(np.int32)
    # majority cleanup over 5x5 to remove stray pixels
    votes = np.stack([ndimage.uniform_filter((zmap == i).astype(np.float32), size=5)
                      for i in range(nz)])
    zmap = votes.argmax(0).astype(np.int32)
    masks = {ZONE_IDS[i]: (zmap == i) for i in range(len(ZONE_IDS) - 1)}
    if base is not None:
        wmask = (zmap == Z['water']) | (zmap == Z['water_deep'])
        st = struct_from(base, wmask)
        zmap[st] = Z['struct']
        for k in masks:
            masks[k] = masks[k] & ~st
    masks['struct'] = (zmap == Z['struct'])
    viz4 = np.zeros((H4, W4, 3), np.uint8)
    for k, i in Z.items():
        viz4[zmap == i] = ZONE_VIZ[k]
    save_rgb(viz4, f'{LAYERS}/zones.png')
    np.savez_compressed(f'{LAYERS}/zones.npz', zmap=zmap,
                        **{f'm_{k}': m for k, m in masks.items()})
    stats = {k: int(m.sum()) for k, m in masks.items()}
    dump_json({'counts': stats, 'source': 'authored layout.png'}, f'{LAYERS}/zones.json')
    for k in ZONE_IDS:
        print(f'  {k:10s} {stats[k]:7d}')
    return zmap, masks
