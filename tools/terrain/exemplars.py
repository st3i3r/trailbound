"""Stage C0 -- exemplar generation.

Generates a large (96x96) procedural exemplar per zone directly, from the
measured ref construction rules. Why generated, not the 32px sheet: the
synthesizer needs non-stationary texture -- areas of smooth wash NEXT TO
clusters of worked speckle. A 32px uniform tile tiles into uniform noise;
a 96px field with a blobby "worked" density map quilts into texture that
varies across the zone like hand-painted ground.

Per-zone recipe (from eastward.pxo measurements):
  field  = normalize(gauss(noise, big cell))  -> soft wash mass
         + 0.35*normalize(gauss(noise, small)) -> medium mottle
  color  = lerp(lo, hi, field)  (continuous tone, no quantize)
  grain  = per-pixel jitter * worked-density-map  (0 in smooth areas,
           full inside worked blobs -> clustered speckle)
"""
import json
import numpy as np
from PIL import Image
from scipy import ndimage
from .lib import SHEET, EX_POS, LAYERS, save_rgb

SZ = 96


def _snoise(shape, cell, rng):
    n = rng.random(shape)
    return ndimage.gaussian_filter(n, cell / 2.2)


def _norm(f):
    f = f - f.min()
    return f / max(f.max(), 1e-6)


def _lerp(lo, hi, t):
    lo = np.array(lo, np.float32); hi = np.array(hi, np.float32)
    return lo + (hi - lo) * t[..., None]


def field_zone(lo, hi, rng, big=26, small=9, grain_amp=9, worked_thresh=0.58,
               worked_sigma=7):
    f = _norm(0.68 * _snoise((SZ, SZ), big, rng) + 0.32 * _snoise((SZ, SZ), small, rng))
    col = _lerp(lo, hi, f)
    # clustered "worked" speckle: blobby density map gates per-pixel jitter
    worked = _norm(_snoise((SZ, SZ), worked_sigma, rng))
    gate = np.clip((worked - worked_thresh) / (1 - worked_thresh + 1e-6), 0, 1)
    gate = np.clip(gate * 1.6, 0, 1)
    # grain correlated into ~1.5px clumps (ref grain is clumped, not salt)
    spk = ndimage.gaussian_filter(
        rng.standard_normal((SZ, SZ)), 0.8)[..., None] * grain_amp * gate[..., None]
    return np.clip(col + spk, 0, 255)


def water_zone(rng):
    """Flat teal + a few broad vertical tonal bands, hard seams (measured).
    NO per-pixel speckle -- ref water is dead flat. Base #389E83 (user's
    cleaner/fresher pick)."""
    base = np.array([0x38, 0x9E, 0x83], np.float32)
    col = np.tile(base, (SZ, SZ, 1))
    bands = np.clip(_norm(_snoise((SZ,), 40, rng)) * 3, 0, 2).astype(np.int32)
    tones = [base, np.array([0x34, 0x9F, 0x82], np.float32),
             np.array([0x34, 0xA1, 0x85], np.float32)]
    for x in range(SZ):
        col[:, x] = tones[bands[x]]
    return col


def deep_zone(rng):
    base = np.array([0x18, 0x78, 0x64], np.float32)
    f = _norm(_snoise((SZ, SZ), 22, rng))
    col = _lerp(base, np.array([0x21, 0x86, 0x70], np.float32), np.clip(f * 0.6, 0, 1))
    return np.clip(col, 0, 255)


def gen_all(rng):
    ex = {
        # sunpool: ref shows uniform micro-drift (+-1-3/ch), not clustered
        # speckle -> low amp, gate mostly open
        'sunpool': field_zone((220, 248, 95), (233, 255, 108), rng,
                              big=30, small=12, grain_amp=3, worked_thresh=0.30),
        'lit': field_zone((166, 210, 80), (188, 228, 100), rng,
                          big=26, small=9, grain_amp=7, worked_thresh=0.60),
        'mid': field_zone((150, 190, 68), (176, 219, 95), rng,
                          big=22, small=6, grain_amp=10, worked_thresh=0.50),
        'pocket': field_zone((86, 118, 64), (122, 158, 96), rng,
                             big=20, small=7, grain_amp=8, worked_thresh=0.55),
        'dirt': field_zone((150, 156, 74), (185, 190, 108), rng,
                           big=18, small=7, grain_amp=9, worked_thresh=0.5),
        'water': water_zone(rng),
        'water_deep': deep_zone(rng),
    }
    for k, v in ex.items():
        save_rgb(v, f'{LAYERS}/ex_{k}.png')
    return ex


def _hex(c):
    c = c.lstrip('#')
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def bake():
    """Sync the 32px sheet flat png from per-tile JSON maps (legacy path)."""
    sh = np.asarray(Image.open(SHEET).convert('RGB'), np.uint8).copy()
    for path in ('assets_src/out/tiles_maps_v16.json',
                 'assets_src/out/water_flat_map.json'):
        try:
            data = json.load(open(path))
        except FileNotFoundError:
            continue
        entries = data if isinstance(data, list) else [data]
        for e in entries:
            name = e['name']
            if name not in EX_POS:
                continue
            leg = {k: _hex(v) for k, v in e['legend'].items()}
            y0, x0 = EX_POS[name]
            for r, row in enumerate(e['rows'][:32]):
                for c, ch in enumerate(row[:32]):
                    if ch in leg:
                        sh[y0 + r, x0 + c] = leg[ch]
    save_rgb(sh.astype(np.float32), SHEET)


if __name__ == '__main__':
    gen_all(np.random.default_rng(11))

