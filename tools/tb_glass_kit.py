#!/usr/bin/env python3
"""UI-019 glass kit v2 — procedural lacquer chrome, Eastward restraint.

v1 read as ornate nameplates: saturated gold frames, chunky notches,
visible gradients, a solid vermilion button.  The Eastward grammar is
quieter: hairline desaturated frames, 2px micro-notches, near-flat dark
glass, and colour living in the content — metalwork only marks state
(selected) or intent (vermilion inner line on the primary).

Out: game/assets/pinewatch/ui/*.png + nine-slice insets in
     ui_atlas_meta.json
"""
import os, json
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(ROOT, "game", "assets", "pinewatch", "ui")
META = os.path.join(UI, "ui_atlas_meta.json")

# --------------------------------------------------------- lacquer tokens
## v3: cool down.  Warm brown + gold read editorial/vintage — Eastward's
## chrome is cool pine glass + a pale sage hairline.  The lacquer story
## survives as gloss (sheen) and the vermilion seal — not warm chrome.
GLASS = (20, 29, 26, 232)          # 141d1a cool pine ~91%
GLASS_LO = (29, 40, 35, 232)       # 1d2823 barely-lighter bottom
BAND = (36, 51, 48, 240)           # 243330 cool slate band
LINE = (179, 183, 149, 255)        # b3b795 — Eastward's pale sage
LINE_DIM = (95, 102, 82, 255)      # dim frame variant
LEAF = (201, 164, 92, 255)         # c9a45c — state accents only
VERM = (184, 50, 42, 255)          # b8322a — seal / primary inner line
GLOW = (232, 196, 106, 255)        # e8c46a selection ring
SHEEN = (240, 244, 222, 16)        # whisper-thin top light


def fill(h, w, top, bot):
    """Near-flat vertical fill — a 4-level drift, not a gradient."""
    a = np.zeros((h, w, 4), np.uint8)
    for y in range(h):
        t = y / max(h - 1, 1)
        a[y, :] = tuple(int(round(top[i] + (bot[i] - top[i]) * t))
                        for i in range(4))
    return a


def rr_mask(h, w, r):
    """Rounded-rect mask — smooth pixel corners, radius r.  The frame
    then follows the arc at a consistent 1 px (v4: rounder + even)."""
    yy, xx = np.mgrid[0:h, 0:w]
    m = ((xx >= r) & (xx <= w - 1 - r)) | ((yy >= r) & (yy <= h - 1 - r))
    for cx, cy in [(r, r), (w - 1 - r, r),
                   (r, h - 1 - r), (w - 1 - r, h - 1 - r)]:
        m |= ((xx - cx) ** 2 + (yy - cy) ** 2) <= r * r
    return m


def hairline(h, w, r, col, alpha=255):
    """Consistent 1 px frame following the rounded corner."""
    f = np.zeros((h, w), bool)
    m = rr_mask(h, w, r)
    for y in range(h):
        for x in range(w):
            if not m[y, x]:
                continue
            if (x == 0 or y == 0 or x == w - 1 or y == h - 1
                    or not m[y - 1, x] or not m[y + 1, x]
                    or not m[y, x - 1] or not m[y, x + 1]):
                f[y, x] = True
    out = np.zeros((h, w, 4), np.uint8)
    out[f] = (col[0], col[1], col[2], alpha)
    return out


def surface(w, h, top, bot, r=4, line=LINE):
    """Base glass surface: flat fill, consistent hairline frame on a
    rounded corner, whisper sheen under the top edge."""
    a = fill(h, w, top, bot)
    a[~rr_mask(h, w, r)] = 0
    f = hairline(h, w, r, line)
    a[f[..., 3] > 0] = f[f[..., 3] > 0]
    for x in range(r + 2, w - r - 2):            # sheen, inside frame
        if a[2, x, 3] > 0:
            a[2, x] = SHEEN
    return a


def button(w, h, top, bot, outer=LINE):
    """Button: the same single rounded hairline every surface uses —
    intent reads via the frame's accent (no sheen — on a 24px control
    it reads as a second stacked border)."""
    a = fill(h, w, top, bot)
    a[~rr_mask(h, w, 4)] = 0
    f = hairline(h, w, 4, outer)
    a[f[..., 3] > 0] = f[f[..., 3] > 0]
    return a


def capsule(w, h, top, bot, line=LINE):
    """Pill: round ends (r = h//2), hairline frame."""
    r = h // 2
    yy, xx = np.mgrid[0:h, 0:w]
    inside = ((xx - r) ** 2 + (yy - r) ** 2 <= r * r) | \
             ((xx - (w - 1 - r)) ** 2 + (yy - r) ** 2 <= r * r) | \
             ((xx >= r) & (xx <= w - 1 - r))
    a = np.zeros((h, w, 4), np.uint8)
    a[inside] = fill(h, w, top, bot)[inside]
    f = np.zeros((h, w, 4), np.uint8)
    for y in range(h):
        for x in range(w):
            if not inside[y, x]:
                continue
            if (x == 0 or y == 0 or x == w - 1 or y == h - 1
                    or not inside[y - 1, x] or not inside[y + 1, x]
                    or not inside[y, x - 1] or not inside[y, x + 1]):
                f[y, x] = line
    a[f[..., 3] > 0] = f[f[..., 3] > 0]
    return a


def sel_glow(s=32):
    """Selection: rounded 1 px glow ring + faint outer halo."""
    a = np.zeros((s, s, 4), np.uint8)
    m = rr_mask(s, s, 5)
    ring = np.zeros((s, s), bool)
    ring[2:-2, 2:-2] = m[2:-2, 2:-2]
    ring[3:-3, 3:-3] = False
    a[ring] = GLOW
    halo = np.zeros((s, s), bool)
    halo[1:-1, 1:-1] = m[1:-1, 1:-1]
    halo[2:-2, 2:-2] = False
    halo &= ~ring
    a[halo] = (GLOW[0], GLOW[1], GLOW[2], 90)
    return a


def halftone(pitch=3):
    a = np.zeros((pitch, pitch, 4), np.uint8)
    a[0, 0] = (10, 6, 4, 150)
    return a


def seal(s=20):
    """Vermilion seal chip — the one place solid lacquer red speaks."""
    a = fill(s, s, (190, 52, 43, 255), (140, 34, 28, 255))
    a[~rr_mask(s, s, 3)] = 0
    f = hairline(s, s, 3, (222, 226, 194, 255))
    a[f[..., 3] > 0] = f[f[..., 3] > 0]
    return a


# ---------------------------------------------------------------- pieces
pieces = {
    "glass_panel": surface(48, 48, GLASS, GLASS_LO),
    "glass_chip": surface(24, 24, (16, 24, 21, 232), (22, 30, 26, 232),
                          3, LINE),
    "glass_pill": capsule(40, 20, GLASS, GLASS_LO),
    # buttons: one hairline on every surface — intent reads via the
    # frame accent: sage neutral, green-fill safe, vermilion primary
    "btn_pill": button(40, 24, GLASS, GLASS_LO),
    "btn_green": button(40, 24, (20, 38, 28, 255), (14, 28, 21, 255)),
    "btn_gold": button(40, 24, GLASS, GLASS_LO, VERM),
    "btn_disabled": button(40, 24, (30, 34, 30, 220), (24, 27, 25, 220),
                           LINE_DIM),
    "sel_glow": sel_glow(),
    "halftone_3": halftone(),
    "seal_lacquer": seal(),
}
# glass_band: the sheet surface — top strip is the band + separator
b = surface(48, 64, GLASS, GLASS_LO)
b[2:13, 3:-3][b[2:13, 3:-3, 3] > 0] = BAND
for x in range(3, 45):
    b[13, x] = LINE
pieces["glass_band"] = b

# ---------------------------------------------------------------- writes
meta = json.load(open(META)) if os.path.exists(META) else {}
insets = {
    "glass_panel": {"l": 8, "r": 8, "t": 8, "b": 8},
    "glass_band": {"l": 8, "r": 8, "t": 16, "b": 8},
    "glass_chip": {"l": 6, "r": 6, "t": 6, "b": 6},
    "glass_pill": {"l": 10, "r": 10, "t": 9, "b": 9},
    "btn_pill": {"l": 6, "r": 6, "t": 6, "b": 6},
    "btn_gold": {"l": 6, "r": 6, "t": 6, "b": 6},
    "btn_green": {"l": 6, "r": 6, "t": 6, "b": 6},
    "btn_disabled": {"l": 6, "r": 6, "t": 6, "b": 6},
    "sel_glow": {"l": 8, "r": 8, "t": 8, "b": 8},
    "seal_lacquer": {"l": 5, "r": 5, "t": 5, "b": 5},
}
for name, arr in pieces.items():
    Image.fromarray(arr).save(os.path.join(UI, name + ".png"))
    if name in insets:
        meta[name] = {"nine_slice": insets[name],
                      "src": {"file": name + ".png",
                              "derived": "tb_glass_kit v2"}}
    print(name, arr.shape[1], "x", arr.shape[0])
json.dump(meta, open(META, "w"), indent=1)
print("->", UI, "| meta updated:", len(insets))
