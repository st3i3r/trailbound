"""Fresh-tone grade -- remap art toward the measured Eastward palette
signature (eastward_clean.png):

  dominant 50-80deg lemon-green mass; teal 160deg water/rock family;
  warm tones kept small; bright high-key V (median .64, p90 .99);
  shadows desaturate (s .35) while brights stay vivid (s .53).

Per-family HSV rules (keep each sprite's internal shading order):
  greens  60-110deg : hue pulled to ~66deg lemon band, s*0.95, v*1.07
  teals  140-190deg : s*0.78, v*1.10  -> bluer, lighter water/rock
  warm   10-50deg dark-ish : s*0.82, v*1.05 -> wood/tan reads cooler
  accents 0-10 & 330-360, bright: untouched (flowers/fire stay warm)
  neutrals s<0.22 : v*1.03 (greys/creams lift slightly)
  outlines v<0.30 : untouched (no lift on line art)

CLI:
  python -m tools.terrain.freshgrade <file.png> [...]
  python -m tools.terrain.freshgrade --batch   # all pinewatch art dirs
"""
import os, sys
import numpy as np
from PIL import Image
from .lib import hsv

BATCH_DIRS = [
    'game/assets/pinewatch/fx',
    'game/assets/pinewatch/props_large',
    'game/assets/pinewatch/props_medium',
    'game/assets/pinewatch/props_small',
    'game/assets/pinewatch/decals',
    'game/assets/pinewatch/characters',
    'game/assets/pinewatch/icons',
]
SKIP = {'ground_sunlit.png', 'ground_painted.png', 'ground_tintmap.png',
        'ground_sunlit_trial.png'}


def grade_rgb(g):
    """g: float RGB 0-255 array -> graded same shape."""
    h, s, v = hsv(g)
    nh, ns, nv = h.copy(), s.copy(), v.copy()

    water = (h > 0.36) & (h < 0.53) & (s > 0.25)
    nh[water] = 0.44 + (nh[water] - 0.44) * 0.30
    ns[water] *= 0.78
    nv[water] = np.clip(nv[water] * 1.10 + 0.03, 0, 1)

    grass = (h > 0.155) & (h <= 0.31) & (s > 0.22) & ~water
    nh[grass] = 0.185 + (nh[grass] - 0.19) * 0.55         # to lemon-green band
    ns[grass] *= 0.95
    nv[grass] = np.clip(nv[grass] * 1.07 + 0.015, 0, 1)

    warm = (h > 0.03) & (h <= 0.14) & (s > 0.28) & (v < 0.80)
    ns[warm] *= 0.82
    nv[warm] = np.clip(nv[warm] * 1.05 + 0.01, 0, 1)

    neut = s <= 0.22
    nv[neut] = np.clip(nv[neut] * 1.03, 0, 1)

    # shadows stay desaturated & soft (ref trait), no lift on line art v<.30
    dark = (v < 0.45) & (v >= 0.30)
    ns[dark] *= 0.90
    line = v < 0.30                                          # outlines frozen
    nh[line], ns[line], nv[line] = h[line], s[line], v[line]
    return _hsv2rgb(nh, ns, nv)


def _hsv2rgb(h, s, v):
    i = (h * 6).astype(np.int32) % 6
    f = h * 6 - (h * 6).astype(np.int32)
    p = v * (1 - s); q = v * (1 - f * s); t = v * (1 - (1 - f) * s)
    r = np.choose(i, [v, q, p, p, t, v])
    g = np.choose(i, [t, v, v, q, p, p])
    b = np.choose(i, [p, p, t, v, v, q])
    return np.stack([r, g, b], -1) * 255


def grade_file(path):
    im = Image.open(path).convert('RGBA')
    a = np.array(im)
    rgb = a[..., :3].astype(np.float32)
    out = np.clip(grade_rgb(rgb), 0, 255).astype(np.uint8)
    a[..., :3] = out
    Image.fromarray(a, 'RGBA').save(path)


def batch():
    n = 0
    for d in BATCH_DIRS:
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.endswith('.png') and f not in SKIP:
                grade_file(os.path.join(d, f))
                n += 1
    print(f'graded {n} files')


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if '--batch' in sys.argv:
        batch()
    elif args:
        for p in args:
            grade_file(p)
            print('graded', p)
    else:
        print(__doc__)
