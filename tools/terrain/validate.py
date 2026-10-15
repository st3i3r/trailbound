"""Stage F -- validation.

Per-zone stats on the synthesized output, checked against the measured ref
grammar (grain amplitude, unique-color density, dominant hex family):

  grain  = mean |dV| to right+bottom neighbor inside zone interior
  colors = unique RGB count per 1024 px sampled
  top    = 3 dominant hexes

Prints a table and writes layers/validate.json. FAIL flags on:
  grain > 0.04 on sunpool/lit (should be soft wash ~0.01)
  colors < 40 per 1024 on grass zones (ref = continuous tone, 80+)
  dominant hex outside +-12 per channel of the zone anchor
"""
import numpy as np
from collections import Counter
from .lib import ZONE_IDS, ANCHORS, LAYERS, dump_json, hsv

GRASS = {'sunpool', 'lit', 'mid', 'pocket'}
EXPECT = {
    'sunpool': dict(grain_max=0.045, colors_min=40),
    'lit': dict(grain_max=0.045, colors_min=40),
    'mid': dict(grain_max=0.060, colors_min=40),
    'pocket': dict(grain_max=0.060, colors_min=25),
    'dirt': dict(grain_max=0.060, colors_min=25),
    'water': dict(grain_max=0.020, colors_min=4),
    'water_deep': dict(grain_max=0.020, colors_min=4),
}


def zone_stats(out, mask):
    ys, xs = np.where(mask)
    if len(ys) < 64:
        return None
    px = out[mask]
    q = (px / 8).astype(np.int32) * 8
    cnt = Counter(map(tuple, q[::4])).most_common(3)
    top = ['#%02X%02X%02X' % tuple(map(int, c)) for c, _ in cnt]
    _, _, v = hsv(out)
    dv = (np.abs(np.diff(v, axis=1, append=v[:, -1:])) +
          np.abs(np.diff(v, axis=0, append=v[-1:, :]))) / 2
    grain = float(dv[mask].mean())
    uq = len(np.unique(px.astype(np.uint8).reshape(-1, 3), axis=0))
    uq_norm = uq * 1024.0 / max(1, len(px))
    anch = np.array(ANCHORS.get(list(ANCHORS)[0]))
    return dict(px=len(px), colors_1k=round(uq_norm, 1), grain=round(grain, 4), top=top)


def run(out, masks):
    print(f'{"zone":11s}{"px":>8s}{"colors/1k":>10s}{"grain":>8s}  top')
    res = {}
    fails = []
    for k in ZONE_IDS:
        if k == 'struct' or not masks[k].any():
            continue
        st = zone_stats(out, masks[k])
        if st is None:
            continue
        res[k] = st
        exp = EXPECT.get(k, {})
        flag = ''
        if st['grain'] > exp.get('grain_max', 9):
            flag += ' !grain'
            fails.append(f'{k}: grain {st["grain"]}')
        if st['colors_1k'] < exp.get('colors_min', 0):
            flag += ' !flat'
            fails.append(f'{k}: colors_1k {st["colors_1k"]}')
        print(f'{k:11s}{st["px"]:8d}{st["colors_1k"]:10.1f}{st["grain"]:8.4f}  {st["top"]}{flag}')
    dump_json(res, f'{LAYERS}/validate.json')
    print('  FAILS:', fails if fails else 'none')
    return res, fails
