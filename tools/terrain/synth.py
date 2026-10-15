"""Stage C -- Efros-Freeman quilting with min-error-boundary seams.

For each zone: raster-scan P-size patches with O overlap. Each patch is the
best of K toroidal exemplar crops (min SSD on the overlap), then pasted through
a dynamic-programming minimum-error cut through the overlap region -- not an
alpha blend. This is the EF technique proper; the cut hides seams along
low-contrast paths.

Augment: exemplar crops get random mirror/rot90 -- free variety for
non-directional materials (grass fields), disabled per-zone for water (keeps
band direction) via DIRECTED set.
"""
import numpy as np
from scipy import ndimage

DIRECTED = {'water', 'water_deep'}          # no flips/rots: bands keep orientation
PATCH, OVLP, K = 24, 7, 12


def _vseam(E):
    """Min-cost top->bottom path through error strip E (h x w). Returns cut mask:
    True = keep left(existing) side."""
    h, w = E.shape
    C = E.copy()
    for i in range(1, h):
        for j in range(w):
            C[i, j] += min(C[i - 1, max(0, j - 1):min(w, j + 2)])
    path = np.zeros(h, np.int32)
    path[-1] = C[-1].argmin()
    for i in range(h - 2, -1, -1):
        j = path[i + 1]
        lo = max(0, j - 1)
        path[i] = lo + C[i, lo:min(w, j + 2)].argmin()
    cut = np.zeros((h, w), bool)
    for i, j in enumerate(path):
        cut[i, :j] = True
    return cut


def _paste(out, patch, ty, tx, ovl, H, W):
    """Paste patch at (ty,tx) cutting seams through the overlap `ovl` px."""
    ph, pw = patch.shape[:2]
    keep_old = np.zeros((ph, pw), bool)
    if tx > 0:                                   # vertical overlap on left
        wov = min(OVLP, pw, W - tx)
        E = ((patch[:, :wov] - out[ty:ty + ph, tx:tx + wov]) ** 2).sum(-1)
        keep_old[:, :wov] = _vseam(E)
    if ty > 0:                                   # horizontal overlap on top
        hov = min(OVLP, ph, H - ty)
        E = ((patch[:hov] - out[ty:ty + hov, tx:tx + pw]) ** 2).sum(-1)
        keep_old[:hov, :] |= _vseam(E.T).T
    reg = out[ty:ty + ph, tx:tx + pw]
    reg[...] = np.where(keep_old[..., None], reg, patch)


def quilt_zone(shape, mask, exemplar, rng, directed=False):
    H, W = shape
    ys, xs = np.where(mask)
    if len(ys) == 0:
        return None, mask
    pad = PATCH
    y0, y1 = max(0, ys.min() - pad), min(H - 1, ys.max() + pad)
    x0, x1 = max(0, xs.min() - pad), min(W - 1, xs.max() + pad)
    out = np.zeros((H, W, 3), np.float32)
    written = np.zeros((H, W), bool)
    eh, ew = exemplar.shape[:2]
    step = PATCH - OVLP
    # align grid so bbox tiles evenly from (0,0)
    for gy in range(0, y1 + 1, step):
        for gx in range(0, x1 + 1, step):
            ty1, tx1 = min(H, gy + PATCH), min(W, gx + PATCH)
            ph, pw = ty1 - gy, tx1 - gx
            best, besterr = None, np.inf
            for _ in range(K):
                ey, ex = rng.integers(0, eh), rng.integers(0, ew)
                yy = (np.arange(ph) + ey) % eh
                xx = (np.arange(pw) + ex) % ew
                p = exemplar[np.ix_(yy, xx)]
                if not directed and rng.random() < .5:
                    p = p[:, ::-1]
                if not directed and rng.random() < .25:
                    p = p[::-1]
                err = 0.0
                if gx > 0 and written[gy:ty1, gx].any():
                    err += float((((p[:, :OVLP] - out[gy:ty1, gx:gx + OVLP])) ** 2).sum())
                if gy > 0 and written[gy, gx:tx1].any():
                    err += float((((p[:OVLP] - out[gy:gy + OVLP, gx:tx1])) ** 2).sum())
                if err < besterr:
                    besterr, best = err, p
            _paste(out, best, gy, gx, OVLP, H, W)
            written[gy:ty1, gx:tx1] = True
    return out, mask


def run(zmap, masks, exemplars, base, rng):
    """Synthesize interiors; returns full-size float rgb + per-zone coverage."""
    from .lib import ZONE_IDS
    out = base.copy()
    cover = np.zeros(zmap.shape, bool)
    for k, ex in exemplars.items():
        z = ZONE_IDS.index(k)
        m = masks[k]
        if not m.any():
            print(f'  {k:10s} (empty)')
            continue
        # erode 2px so synthesis stays inside zone; boundary belongs to transitions
        inner = ndimage.binary_erosion(m, iterations=2)
        q, sel = quilt_zone(zmap.shape, inner, ex, rng, directed=(k in DIRECTED))
        sel = sel & (q.sum(-1) > 0)
        out[sel] = q[sel]
        cover |= sel
        print(f'  {k:10s} {int(sel.sum()):7d}px quilted')
    return out, cover
