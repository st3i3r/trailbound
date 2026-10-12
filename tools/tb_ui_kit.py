#!/usr/bin/env python3
"""UI kit assembly — segments the staged U1-U5 sheets into named pieces,
flattens parchment interiors for 9-slice use, recolors button variants,
empties the avatar portrait, measures nine-slice insets, and packs
everything into ui_atlas.png + ui_atlas_meta.json.

In : assets_src/staging/pinewatch/ui/U{1..5}_0.png
Out: assets_src/out/ui/pieces/*.png, ui_atlas.png, ui_atlas_meta.json
"""
import os, json, math, colorsys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI_IN = os.path.join(ROOT, "assets_src", "staging", "pinewatch", "ui")
OUT = os.path.join(ROOT, "assets_src", "out", "ui")
PIECES = os.path.join(OUT, "pieces")
os.makedirs(PIECES, exist_ok=True)

DARK = (41, 20, 9)          # outline brown
CREAM = (238, 214, 172)     # parchment light
DEEP_GREEN = (45, 62, 41)   # avatar fill

sheets = {n: np.array(Image.open(os.path.join(UI_IN, n + ".png"))
                     .convert("RGBA")) for n in
          ["U1_0", "U2_0", "U3_0", "U4_0", "U5_0"]}

# ---------------------------------------------------------------- pieces
# name -> (sheet, x0, y0, x1, y1, how)   how: 'rect'|'disc'
PIECE_DEFS = [
    # U1 — window panel (green hanging tab fused on top is part of it)
    ("panel_window",   "U1_0", 23, 32, 234, 210, "rect"),
    # U2 — buttons
    ("btn_green",      "U2_0", 30, 32, 115, 66, "rect"),
    ("btn_round_gold", "U2_0", 128, 32, 161, 65, "rect"),
    # U3 — HUD cluster is fused; split by measured geometry
    ("hud_medallion",  "U3_0", 159, 28, 226, 86, "disc"),   # disc c=(192,56) r=34
    ("hud_banner",     "U3_0", 16, 81, 241, 113, "rect"),
    ("hud_tag",        "U3_0", 96, 113, 161, 139, "rect"),
    ("hud_toolbar",    "U3_0", 48, 223, 209, 242, "rect"),
    # U4 — guest card + slots + red seal + wood medallion
    ("card_guest",     "U4_0", 11, 19, 115, 155, "rect"),
    ("slot_dark",      "U4_0", 125, 28, 174, 77, "rect"),
    ("slot_parchment", "U4_0", 186, 27, 237, 78, "rect"),
    ("seal_red",       "U4_0", 186, 104, 237, 155, "rect"),
    ("medallion_wood", "U4_0", 126, 107, 173, 154, "rect"),
    # U5 — bubbles
    ("bubble_speech",  "U5_0", 16, 20, 117, 91, "rect"),
    ("bubble_wide",    "U5_0", 136, 24, 241, 65, "rect"),
    ("bubble_tail",    "U5_0", 38, 92, 58, 109, "rect"),
    ("bubble_prompt",  "U5_0", 127, 100, 249, 141, "rect"),
    ("bubble_flat",    "U5_0", 20, 149, 121, 180, "rect"),
]

pieces = {}   # name -> RGBA np array (tight)
src_rects = {}
for name, sheet, x0, y0, x1, y1, how in PIECE_DEFS:
    arr = sheets[sheet][y0:y1, x0:x1].copy()
    if how == "disc":
        h, w = arr.shape[:2]
        cx, cy, r = 192 - x0, 56 - y0, 34
        yy, xx = np.mgrid[0:h, 0:w]
        keep = ((xx - cx) ** 2 + (yy - cy) ** 2) <= r * r
        arr[~keep] = (0, 0, 0, 0)
    pieces[name] = arr
    src_rects[name] = [x0, y0, x1 - x0, y1 - y0]

# repair hud_banner's top edge: the medallion overlaps piece rows 0-4
# (banner y81-112, centre-y 96.5). Rebuild contaminated columns from the
# vertically mirrored (clean) bottom rows.
ban = pieces["hud_banner"]
pcx, pcy = 192 - 16, 56 - 81             # disc centre in piece coords
yy, xx = np.mgrid[0:ban.shape[0], 0:ban.shape[1]]
disc = (xx - pcx) ** 2 + (yy - pcy) ** 2 <= 34 * 34
for y in range(0, 5):                    # piece rows 0-4 = sheet y81-85
    my = int(round(2 * 15.5 - y))        # mirror across piece centre-y 15.5
    cols = disc[y]
    ban[y, cols] = ban[my, cols]
pieces["hud_banner"] = ban

# ---------------------------------------------------------------- helpers
def depth_map(alpha):
    """Per-pixel depth = # of 8-erosions survived. alpha>0 -> 1..deep."""
    m = alpha > 0
    depth = np.zeros(alpha.shape, np.int16)
    cur = m.copy()
    d = 0
    while cur.any():
        d += 1
        depth[cur] = d
        e = cur.copy()
        e[1:, :] &= cur[:-1, :]; e[:-1, :] &= cur[1:, :]
        e[:, 1:] &= cur[:, :-1]; e[:, :-1] &= cur[:, 1:]
        e[1:, 1:] &= cur[:-1, :-1]; e[:-1, :-1] &= cur[1:, 1:]
        e[1:, :-1] &= cur[:-1, 1:]; e[:-1, 1:] &= cur[1:, :-1]
        cur = e
        if d > 200:
            break
    return depth

def is_lightish(rgb):
    r, g, b = rgb[..., 0].astype(int), rgb[..., 1].astype(int), rgb[..., 2].astype(int)
    # parchment / light-green interiors; excludes dark outline + red seal
    return (r + g + b > 330) & ~((r > 140) & (g < 110) & (b < 90))

def flatten(arr, inset=13):
    """Replace deep light-interior px with the piece's lightest interior
    color; keeps border, rim shading and dark/red motifs."""
    a = arr[..., 3]
    depth = depth_map(a)
    inter = (depth >= inset) & is_lightish(arr[..., :3]) & (a > 0)
    if inter.sum() < 20:
        return None
    px = arr[..., :3][inter]
    lum = px @ np.array([0.299, 0.587, 0.114])
    flat = tuple(int(v) for v in px[lum >= np.percentile(lum, 80)].mean(0).round())
    out = arr.copy()
    out[..., :3][inter] = flat
    return out, flat, int(inter.sum())

def save(arr, name):
    Image.fromarray(arr).save(os.path.join(PIECES, name + ".png"))

def ramp_recolor(arr, hue_lo, hue_hi, sat_lo, ramp):
    """Map pixels whose hue is in [hue_lo,hue_hi) & sat>=sat_lo onto the
    target ramp (list of rgb sorted dark->light) by luminance percentile."""
    out = arr.copy()
    rgb = arr[..., :3].astype(float) / 255
    a = arr[..., 3]
    hsv = np.array([colorsys.rgb_to_hsv(*p) for p in
                    rgb.reshape(-1, 3)]).reshape(arr.shape[:2] + (3,))
    h, s = hsv[..., 0], hsv[..., 1]
    m = (a > 200) & (s >= sat_lo) & (h >= hue_lo) & (h < hue_hi)
    if m.sum() < 5:
        return out, 0
    lum = rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114
    vals = np.sort(lum[m])
    ranks = np.searchsorted(vals, lum[m]) / max(len(vals) - 1, 1)
    idx = np.clip((ranks * (len(ramp) - 1)).round().astype(int), 0, len(ramp) - 1)
    tgt = np.array(ramp, dtype=np.uint8)[idx]
    out[..., :3][m] = tgt
    return out, int(m.sum())

def nine_insets(arr):
    """Border insets {l,t,r,b}: px from each edge until the dominant
    interior color takes over along the middle band."""
    a = arr[..., 3]; h, w = a.shape
    cy0, cy1 = int(h * 0.25), int(h * 0.75)
    cx0, cx1 = int(w * 0.25), int(w * 0.75)
    ctr = arr[cy0:cy1, cx0:cx1]
    op = ctr[ctr[..., 3] > 200][:, :3].astype(int)
    if len(op) == 0:
        return {"l": 0, "t": 0, "r": 0, "b": 0}
    interior_rgb = np.median(op, 0)
    dist = np.sqrt(((arr[..., :3].astype(int) - interior_rgb) ** 2).sum(-1))
    inter = (dist < 46) & (a > 0)
    if is_lightish(np.array(interior_rgb.reshape(1, 1, 3)))[0, 0]:
        inter |= is_lightish(arr[..., :3]) & (a > 0)

    def scan(axis, sign):
        n = (h if axis == "x" else w)          # band length
        ln = (w if axis == "x" else h)         # scan length
        m0, m1 = int(n * 0.35), int(n * 0.65)
        for i in range(ln // 2):
            if axis == "x":
                sl = inter[m0:m1, i if sign > 0 else w - 1 - i]
            else:
                sl = inter[i if sign > 0 else h - 1 - i, m0:m1]
            if sl.mean() > 0.6:
                return i
        return ln // 2
    return {"l": scan("x", 1), "r": scan("x", -1),
            "t": scan("y", 1), "b": scan("y", -1)}

# ---------------------------------------------------------------- 1. saves
for name, arr in pieces.items():
    save(arr, name)

# ---------------------------------------------------------------- 2. flat
FLATTEN = ["panel_window", "hud_banner", "bubble_speech",
           "bubble_wide", "bubble_flat", "bubble_prompt"]
flat_info = {}
for name in FLATTEN:
    r = flatten(pieces[name])
    if r:
        out, flat, n = r
        pieces[name + "_flat"] = out
        save(out, name + "_flat")
        flat_info[name] = {"flat_rgb": flat, "px": n}
    else:
        flat_info[name] = "skipped (interior too small)"
print("flatten:", flat_info)

# ---------------------------------------------------------------- 3. btns
# ember-gold ramp sampled from the round gold button's warm ramp
gold_src = pieces["btn_round_gold"]
grgb = gold_src[..., :3].reshape(-1, 3).astype(int)
ga = gold_src[..., 3].reshape(-1)
warm = grgb[(ga > 200) & (grgb[:, 0] > grgb[:, 2] + 40)
            & (grgb[:, 0] > 100)]
wl = warm @ np.array([0.299, 0.587, 0.114])
warm = warm[np.argsort(wl)]
sampled = [tuple(int(v) for v in warm[int(t)]) for t in
           np.linspace(0, len(warm) - 1, 4).astype(int)]
gold_ramp = [(206, 138, 58), (222, 165, 78), (238, 189, 105)] + sampled[1:]
print("gold ramp:", gold_ramp)
cream_ramp = [(122, 104, 78), (157, 137, 103), (196, 176, 138),
              (222, 204, 168), (233, 216, 181)]

btn = pieces["btn_green"]
green_mask_hue = (0.20, 0.45)
gold_btn, n1 = ramp_recolor(btn, *green_mask_hue, 0.18, gold_ramp)
dis_btn, n2 = ramp_recolor(btn, *green_mask_hue, 0.18, cream_ramp)
pieces["btn_gold"] = gold_btn; save(gold_btn, "btn_gold")
pieces["btn_disabled"] = dis_btn; save(dis_btn, "btn_disabled")
print("button recolor px:", n1, n2, "gold ramp:", gold_ramp)

# ---------------------------------------------------------------- 4. avatar
med = pieces["hud_medallion"].copy()
h, w = med.shape[:2]
yy, xx = np.mgrid[0:h, 0:w]
cx, cy = 192 - 159, 56 - 28          # = (33, 28)
d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
inner = (d <= 26) & (med[..., 3] > 0)
med[..., :3][inner] = DEEP_GREEN
pieces["hud_medallion_empty"] = med
save(med, "hud_medallion_empty")
print("avatar fill px:", int(inner.sum()))

# ---------------------------------------------------------------- 5. insets
NINE = ["panel_window", "panel_window_flat", "hud_banner",
        "hud_banner_flat", "hud_tag", "hud_toolbar", "btn_green",
        "btn_gold", "btn_disabled", "btn_round_gold", "card_guest",
        "slot_dark", "slot_parchment", "bubble_speech",
        "bubble_speech_flat", "bubble_wide", "bubble_wide_flat",
        "bubble_flat", "bubble_flat_flat", "bubble_prompt"]
insets = {}
for name in NINE:
    if name in pieces:
        insets[name] = nine_insets(pieces[name])
print("insets:", json.dumps(insets))

# ---------------------------------------------------------------- 6. atlas
order = sorted(pieces, key=lambda n: -pieces[n].shape[0])
PAD = 2
# shelf pack: shelf width ~ sqrt of total area, round to 64
area = sum((p.shape[1] + PAD) * (p.shape[0] + PAD) for p in pieces.values())
SW = max(64, int(math.sqrt(area) * 1.15 + 0.5))
x = y = PAD; shelf_h = 0
atlas_w = 0
placed = []
rows = []
for n in order:
    p = pieces[n]
    pw, ph = p.shape[1], p.shape[0]
    if x + pw + PAD > SW and x > PAD:
        rows.append((y, shelf_h)); y += shelf_h + PAD
        x = PAD; shelf_h = 0
    placed.append((n, x, y, pw, ph))
    x += pw + PAD; shelf_h = max(shelf_h, ph)
    atlas_w = max(atlas_w, x)
rows.append((y, shelf_h))
atlas_h = y + shelf_h + PAD
atlas = np.zeros((atlas_h, atlas_w, 4), np.uint8)
src_of = {}
for n, sheet, x0, y0, x1, y1, how in PIECE_DEFS:
    src_of[n] = {"file": sheet + ".png", "rect": [x0, y0, x1 - x0, y1 - y0]}
for n in list(pieces):
    if n.endswith("_flat") and n[:-5] in src_of:
        src_of[n] = dict(src_of[n[:-5]], derived="flatten_interior")
src_of["btn_gold"] = dict(src_of["btn_green"], derived="recolor_gold")
src_of["btn_disabled"] = dict(src_of["btn_green"], derived="recolor_cream")
src_of["hud_medallion_empty"] = dict(src_of["hud_medallion"],
                                   derived="avatar_flat_fill")
meta = {}
for n, px_, py_, pw, ph in placed:
    atlas[py_:py_ + ph, px_:px_ + pw] = pieces[n]
    meta[n] = {"x": px_, "y": py_, "w": pw, "h": ph,
               "src": src_of.get(n)}
    if n in insets:
        meta[n]["nine_slice"] = insets[n]
Image.fromarray(atlas).save(os.path.join(OUT, "ui_atlas.png"))
meta["_atlas"] = {"w": int(atlas_w), "h": int(atlas_h), "pad": PAD}
with open(os.path.join(OUT, "ui_atlas_meta.json"), "w") as f:
    json.dump(meta, f, indent=1)
print("atlas", atlas_w, "x", atlas_h, "pieces:", len(placed))
print("->", OUT)
