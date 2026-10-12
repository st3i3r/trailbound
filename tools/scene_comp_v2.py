#!/usr/bin/env python3
"""Pinewatch composite v3 — paints the POST-PROCESSED art (assets_src/out/)
into three 640x360 mocks exactly as Godot will: Wang-corner terrain tiles,
sprites anchored bottom-center, Y-sorted, source-over alpha, nearest only.

v3 = the eastward color grade: the wang sheets it loads are already
HSV-graded by tools/tb_grade.py --site pinewatch_v2 (fresh yellow-olive
grass / ochre dirt / saturated teal water); this script adds the same
scene-level grade the engine got — sky->dirt backdrop band behind the
treeline, edge-clustered decals, the baked ground tint map
(cleanup/ground_tintmap.png = the engine's GroundTint sprite), and the
lighter warm sunny multiply (#fbf4e4 = CanvasModulate).

Outputs (assets_src/cleanup/):
  pinewatch_comp_v3.png  full campsite clearing, graded
  hud_mock.png           scene dimmed 10% + assembled HUD
  panel_mock.png         scene dimmed 40% + guest panel
"""
import os, json, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets_src", "out")
CLN = os.path.join(ROOT, "assets_src", "cleanup")
B4 = os.path.join(ROOT, "assets_src", "gen", "candidates", "batch4")
STG = os.path.join(ROOT, "assets_src", "staging", "pinewatch")
PIECES = os.path.join(OUT, "ui", "pieces")
W, H, T = 640, 360, 32

# ---------------------------------------------------------------- wang map
# corner key NW,NE,SE,SW (U=upper/grass, L=lower) -> cell offset in the
# 128x128 pro sheet (identical layout in all three sets)
KEY2XY = {
    "UUUL": (0, 0), "ULLU": (1, 0), "LULL": (2, 0), "UULL": (3, 0),
    "LULU": (0, 1), "ULLL": (1, 1), "LLLL": (2, 1), "LLUL": (3, 1),
    "ULUU": (0, 2), "LLUU": (1, 2), "LLLU": (2, 2), "LUUL": (3, 2),
    "UUUU": (0, 3), "UULU": (1, 3), "ULUL": (2, 3), "LUUU": (3, 3),
}

def load(p):
    return Image.open(p).convert("RGBA")

SHEET = {n: load(os.path.join(OUT, "terrain", f"terrain_grass_{n}_pro_0.png"))
         for n in ("water", "forest", "stone")}
GRASS = SHEET["water"].crop((0, 96, 32, 128))          # wang_15 upper —
                                                       # base fill tile;
                                                       # cells now show
                                                       # variant PNGs

def tile(set_name, key):
    cx, cy = KEY2XY[key]
    return SHEET[set_name].crop((cx * 32, cy * 32, cx * 32 + 32, cy * 32 + 32))

def corners(mask, tx, ty, gw, gh):
    """corner state for cell: 'L' if any cell sharing that vertex is
    in-mask, else 'U'."""
    def m(x, y):
        return 0 <= x < gw and 0 <= y < gh and mask[y][x]
    nw = m(tx - 1, ty - 1) or m(tx, ty - 1) or m(tx - 1, ty) or m(tx, ty)
    ne = m(tx, ty - 1) or m(tx + 1, ty - 1) or m(tx, ty) or m(tx + 1, ty)
    sw = m(tx - 1, ty) or m(tx, ty) or m(tx - 1, ty + 1) or m(tx, ty + 1)
    se = m(tx, ty) or m(tx + 1, ty) or m(tx, ty + 1) or m(tx + 1, ty + 1)
    return "".join("L" if v else "U" for v in (nw, ne, se, sw))

# ---------------------------------------------------------------- scene
GW, GH = W // T, H // T + 1
scene = Image.new("RGBA", (W, H))

# ---------------------------------------------------------------- fills
# Fill-variant tiles mirror the engine (pinewatch_test.gd variant pass):
# a cell painted with a PURE fill (UUUU / LLLL in any sheet) shows the
# hash-picked variant variant_<set>_<key>_<vi>.png with
# vi = (tx*31 + ty*17 + src) % 6, src = the terrain-set index whose
# tile won the cell (grass base = water sheet = 0).  Source order in
# the .tres: 3 + set*12 + fill*6 + variant — same contract.
SET_ID = {"water": 0, "forest": 1, "stone": 2}
VAR_N = 6
_VCACHE = {}

def variant(set_name, key, tx, ty):
    src = SET_ID[set_name]
    vi = (tx * 31 + ty * 17 + src) % VAR_N
    p = "variant_%s_%s_%d.png" % (set_name, key, vi)
    if p not in _VCACHE:
        _VCACHE[p] = load(os.path.join(OUT, "terrain", p))
    return _VCACHE[p]

# regions (cell masks)
forest = [[ty <= 2 or (ty == 3 and tx not in (4, 5, 11, 12, 17))
           for tx in range(GW)] for ty in range(GH)]
pond = [[(tx <= 3 and ty >= 8) or (tx == 4 and ty >= 10)
         for tx in range(GW)] for ty in range(GH)]
path = [[(tx, ty) in {(10, 11), (10, 10), (9, 10), (9, 9), (9, 8), (9, 7),
                     (10, 7), (11, 7), (12, 7), (13, 7)}
         for tx in range(GW)] for ty in range(GH)]

# final tile per cell: grass base = water UUUU (src 0), then each blob's
# non-UUUU tiles overwrite in the engine's order (forest, pond, path)
final = {}
for ty in range(GH):
    for tx in range(GW):
        final[(tx, ty)] = ("water", "UUUU")
        for set_name, mask in (("forest", forest),
                               ("water", pond), ("stone", path)):
            k = corners(mask, tx, ty, GW, GH)
            if k != "UUUU":
                final[(tx, ty)] = (set_name, k)

for ty in range(GH):
    for tx in range(GW):
        set_name, k = final[(tx, ty)]
        if k in ("UUUU", "LLLL"):          # pure fill -> hash variant
            scene.paste(variant(set_name, k, tx, ty), (tx * T, ty * T))
        else:
            scene.paste(tile(set_name, k), (tx * T, ty * T))

# ---------------------------------------------- macro ground zones (v4)
# Tile-swap zones are FORBIDDEN (style lock 2026-10-12): all macro ground
# colour comes from the baked 640x360 RGBA tint map
# (assets_src/cleanup/ground_tintmap.png, tools/tb_tintmap.py), pasted
# below after decals — the same stack point the engine's GroundTint
# sprite occupies (above Ground+Scatter, below World/props).
# What stays on the tile grid: tracked-down-to-dirt wear under tents /
# fire ring / path junction.
WEAR_CELLS = [(6, 7), (7, 7), (6, 8), (5, 9), (6, 9), (7, 9),
              (10, 8), (11, 8), (10, 9), (13, 6), (12, 6), (14, 7)]

def grass_cell(tx, ty):
    return not (forest[ty][tx] or pond[ty][tx] or path[ty][tx])

worn = 0
for tx, ty in WEAR_CELLS:
    if grass_cell(tx, ty):
        # engine: set_cell(src=1, LLLL) -> forest LLLL variant by hash
        scene.paste(variant("forest", "LLLL", tx, ty), (tx * T, ty * T))
        final[(tx, ty)] = ("forest", "LLLL")
        worn += 1
print("ground: ", worn, "wear cells, tint map carries macro variation")

# ------------------------------------------------------------- backdrop
# grade pass: sky->dirt gradient behind a shadowed treeline, painted on
# top of the top forest strip so the top edge reads depth (mirrors the
# engine's Backdrop node)
SKY_TOP = (232, 220, 192)                    # #e8dcc0 pale warm
SKY_BOT = (185, 168, 136)                    # #b9a888 horizon -> dirt
SKY_H = 118
grad = Image.new("RGBA", (W, SKY_H))
gd = np.linspace(0, 1, SKY_H)[:, None]
band = (np.array(SKY_TOP, float) * (1 - gd[..., None])
        + np.array(SKY_BOT, float) * gd[..., None])
grad = Image.fromarray(
    np.concatenate([np.repeat(band.astype(np.uint8), W, axis=1),
                    np.full((SKY_H, W, 1), 255, np.uint8)], axis=2))
scene.paste(grad, (0, 0), grad)

# ---------------------------------------------------------------- helpers
_cache = {}
def img(path):
    if path not in _cache:
        _cache[path] = load(path)
    return _cache[path]

anchors = json.load(open(os.path.join(OUT, "anchors.json")))

def anchor_blit(im, ax, ay, anchor=None):
    """Paste im so its anchor lands on (ax,ay). anchor=(x,y) px in im."""
    if anchor is None:
        anchor = (im.width // 2, im.height)
    scene.paste(im, (int(ax - anchor[0]), int(ay - anchor[1])), im)

def prop(cat, name, ax, ay, lean=0.0):
    im = img(os.path.join(OUT, cat, name + ".png"))
    key = f"{cat}/{name}.png"
    a = anchors.get(key)
    anch = (a["anchor_x"], a["anchor_y"]) if a else (im.width // 2, im.height)
    if lean:
        # rotate about the base anchor (planted lean); NEAREST keeps the
        # pixel grid, sign flipped vs Godot rotation_degrees (y-down)
        im = im.rotate(-lean, resample=Image.NEAREST, center=anch)
    anchor_blit(im, ax, ay, anch)

def raw(path, ax, ay, anch=None):
    im = img(path)
    anchor_blit(im, ax, ay, anch)

# ---------------------------------------------- backdrop treeline (v3)
# 3 rows of the existing large props, darkened + cooled, standing in
# front of the sky band — mirrors the engine's Backdrop node tints
_TREES = ["pine_tall_a", "pine_tall_b"]
def tinted_prop(cat, name, ax, ay, mul, s=1.0):
    im = img(os.path.join(OUT, cat, name + ".png")).copy()
    if s != 1.0:
        im = im.resize((int(im.width * s), int(im.height * s)),
                       Image.NEAREST)
    a = np.array(im).astype(float)
    a[..., :3] = np.clip(a[..., :3] * np.array(mul), 0, 255)
    im = Image.fromarray(a.astype(np.uint8))
    anch = anchors.get(f"{cat}/{name}.png")
    anchor_blit(im, ax, ay,
                (anch["anchor_x"] * s, anch["anchor_y"] * s)
                if anch else (im.width // 2, im.height))

k = 0
for base_y, dx, x0, mul, s in ((78, 118, -34, (0.62, 0.66, 0.72), 0.62),
                             (98, 128, 22, (0.57, 0.61, 0.68), 0.80),
                             (118, 190, 170, (0.51, 0.55, 0.62), 1.00)):
    x = x0
    while x < W + 40:
        n = "flamboyant_tree" if (base_y == 98 and k % 4 == 3) \
            else _TREES[k % 2]
        tinted_prop("props_large", n, x, base_y, mul, s)
        x += dx
        k += 1

# ---------------------------------------------------------------- decals
# edge-clustered (ground recipe): ~14 decals total, ONE family per
# cluster, ONLY at edges — prop bases, pond shoreline, treeline feet.
# Open-field interior stays EMPTY; the tint map carries macro variation.
# Mirrors DECAL_CLUSTERS in pinewatch_test.gd exactly.
DECAL_FAMILIES = {
    "tuft":   ["XS_0", "XS_1", "XS_4", "XS_24", "XS_36", "XS_52"],
    "flower": ["XS_10", "XS_11", "XS_22", "XS_56"],
    "dry":    ["XS_2", "XS_6", "XS_8"],
    "pebble": ["XS_29", "XS_41", "XS_51"],
    "shroom": ["XS_13", "XS_16", "XS_43", "XS_44", "XS_61"],
    # leaf litter for the (intentionally near-flat) B5 forest floor:
    # needle scatter + pile, pine twig, fallen yellow/red leaves, pinecone
    "litter": ["XS_19", "XS_20", "XS_21", "XS_22", "XS_23", "XS_17"],
}
# [cx, cy, family, count, rx, ry, want]  want: 0 grass, 1 forest floor
DECAL_CLUSTERS = [
    (212, 247, "tuft",   2, 16, 8, 0),   # tent_green base
    (192, 316, "dry",    2, 16, 8, 0),   # tent_red base
    (256, 272, "pebble", 2, 12, 6, 0),   # log_bench feet
    (540, 174, "tuft",   1, 10, 6, 0),   # chicken_coop base
    (118, 192, "pebble", 1, 10, 6, 0),   # van wheel line
    (140, 300, "pebble", 2, 14, 24, 0),  # pond shoreline
    (238, 121, "litter", 2, 16, 5, 1),   # treeline floor W
    (486, 122, "litter", 2, 18, 5, 1),   # treeline floor E
    (408, 166, "flower", 1, 10, 6, 0),   # flower_box base
]
import random
rng = random.Random(7)                  # same seed domain as engine rng

# pad rects (layout pinewatch.json, origin (0,96), 64 px cells) — the
# comp draws no pad markers but scatter still avoids them like the game
PAD_SPOTS = [(1, 0), (4, 0), (7, 0), (0, 1), (9, 1), (1, 2), (4, 3),
             (7, 3)]
PAD_RECTS = [(cx * 64, 96 + cy * 64, 64, 64) for cx, cy in PAD_SPOTS]

def cell_mask(tx, ty):
    if not (0 <= tx < GW and 0 <= ty < GH):
        return -1
    if pond[ty][tx] or path[ty][tx]:
        return 2
    return 1 if forest[ty][tx] else 0

def open_cell(px, py, want):
    if cell_mask(int(px) // T, int(py) // T) != want:
        return False
    return not any(rx <= px < rx + rw and ry <= py < ry + rh
                   for rx, ry, rw, rh in PAD_RECTS)

def decal(name, ax, ay, fg=False):
    """prop() at 0.85 alpha — decal sinks into the ground wash.
    fg=True keeps full alpha: the decal is FOREGROUND vegetation
    overlapping a prop's base (embed pass), not ground scatter."""
    im = img(os.path.join(OUT, "decals", name + ".png")).copy()
    if not fg:
        a = np.array(im)
        a[..., 3] = (a[..., 3].astype(float) * 0.85).astype(np.uint8)
        im = Image.fromarray(a)
    anch = anchors.get(f"decals/{name}.png")
    anchor_blit(im, ax, ay,
                (anch["anchor_x"], anch["anchor_y"])
                if anch else (im.width // 2, im.height))

placed = 0
for cx, cy, fam_name, ndec, rx, ry, want in DECAL_CLUSTERS:
    fam = DECAL_FAMILIES[fam_name]
    for _ in range(ndec):
        # triangular offset -> denser near the centre, soft edges
        px = cx + (rng.random() + rng.random() - 1.0) * rx
        py = cy + (rng.random() + rng.random() - 1.0) * ry
        if open_cell(px, py, want):
            decal(fam[rng.randrange(len(fam))], px, py)
            placed += 1
print("scatter decals:", placed, f"({len(DECAL_CLUSTERS)} edge clusters)")

# ------------------------------------------------- grass texture relief
# broad low-frequency luminance variation on the pure-grass field so the
# 32 px tile grid disappears (kept off transitions/water/props zones)
arr = np.array(scene).astype(float)
noise = np.zeros((H, W))
rn2 = np.random.default_rng(4)
for _ in range(3):
    k = rn2.integers(20, 90)
    small = rn2.random((H // k + 2, W // k + 2))
    big = np.array(Image.fromarray((small * 255).astype(np.uint8))
                   .resize((W, H), Image.BILINEAR)) / 255
    noise += (big - big.mean())
noise = noise / noise.std() * 4.0          # +-~8 px luminance swing
grass_only = np.zeros((H, W), bool)
for ty in range(GH):
    for tx in range(GW):
        if (not forest[ty][tx] and not pond[ty][tx] and not path[ty][tx]
                and corners(forest, tx, ty, GW, GH) == "UUUU"
                and corners(pond, tx, ty, GW, GH) == "UUUU"
                and corners(path, tx, ty, GW, GH) == "UUUU"):
            grass_only[ty * T:(ty + 1) * T, tx * T:(tx + 1) * T] = True
arr[..., :3] = np.clip(arr[..., :3] + noise[..., None] * grass_only[..., None],
                       0, 255)
scene = Image.fromarray(arr.astype(np.uint8))

# ------------------------------------------------- ground tint map (v4)
# same stack point as the engine's GroundTint sprite: above terrain +
# backdrop + decals, below props/chars.  One baked RGBA field carries
# all macro ground colour — soft warm/cool zones, treeline shade band,
# sun pools.  Lighting layer: exempt from palette snapping.
_tint = load(os.path.join(CLN, "ground_tintmap.png"))
scene.alpha_composite(_tint, (0, 0))

# ---------------------------------------------------------------- props
# (draw call, y-anchor) — sorted by y before painting
jobs = []
def P(cat, name, x, y, lean=0.0):
    jobs.append((y, lambda: prop(cat, name, x, y, lean)))
    embed(cat, name, x, y)
def R(path, x, y, anch=None):
    jobs.append((y, lambda p=path, X=x, Y=y, A=anch: raw(p, X, Y, A)))

# ------------------------------------------------- embed pass (Phase 0.1)
# 1-3 small decals anchored just BELOW each prop's base so they y-sort
# in front of its bottom ~8-15% — foreground vegetation breaks the base
# edge = the prop sits IN the world (mirrors _embed_base in
# pinewatch_test.gd; own rng since the RNG streams can't match anyway).
EMBED_SKIP = {"dirt_patch"}                    # it IS the ground
erng = random.Random(23)

def embed(cat, name, x, y):
    if name in EMBED_SKIP:
        return
    key = f"{cat}/{name}.png"
    a = anchors.get(key, {})
    im = img(os.path.join(OUT, cat, name + ".png"))
    ax = a.get("anchor_x", im.width // 2)
    ay = a.get("anchor_y", im.height)
    c = a.get("content", [0, 0, im.width, im.height])
    fx0, fx1 = x - ax + c[0], x - ax + c[2]
    ch = c[3] - c[1]
    overlap = min(max(ch * 0.11, 3.0), 7.0)
    for _ in range(1 + erng.randrange(3)):
        px = fx0 + (fx1 - fx0) * (0.2 + 0.6 * erng.random())
        py = y + max(1.0, 8.0 - overlap + erng.random() * 2.0 - 1.0)
        tx, ty = int(px) // T, int(py) // T
        if not (0 <= tx < GW and 0 <= ty < GH):
            continue
        if pond[ty][tx]:                       # never on the pond
            continue
        if any(rx <= px < rx + rw and ry <= py < ry + rh
               for rx, ry, rw, rh in PAD_RECTS):
            continue                           # pads stay clear
        fam = DECAL_FAMILIES["pebble" if path[ty][tx]
                             else "litter" if forest[ty][tx] else "tuft"]
        nm = fam[erng.randrange(len(fam))]
        jobs.append((py, lambda P_=px, Y=py, N=nm: decal(N, P_, Y, True)))

# Phase 0.3 cluster recomposition — 4 storytelling clusters from the
# existing staged assets: outfitter camp NW, camp kitchen centre,
# rest corner E, work edge NE.  Sub-cell jitter, mild overlap, site
# layout kept (van NW, trees top, fire centre, pond SW).
# treeline + structures (backdrop band)
P("props_large", "pine_tall_a", 74, 96)
P("props_large", "pine_tall_b", 156, 102)
P("props_large", "flamboyant_tree", 262, 94)
P("props_large", "pine_tall_a", 540, 92)
P("props_large", "bamboo_clump", 606, 96)
P("props_large", "cabin", 428, 128)
P("props_large", "pennant_string", 345, 168)
# outfitter camp (NW): van, awning stools, crates, nón lá, signpost
P("props_large", "outfitter_van", 110, 178)
P("props_medium", "prop_supply_crate_0", 206, 188)
P("props_small", "non_la_hat", 209, 196)
P("props_medium", "stool_pair", 172, 200)
P("props_medium", "moped_cub", 78, 208)
P("props_small", "signpost", 222, 208, 2.5)       # leaned
P("props_small", "stool_plastic_blue", 148, 214)
P("props_small", "stool_plastic_red", 186, 214)
# camp kitchen (centre): fire ring + flame + tripod + bench + stump
P("props_medium", "lantern_post", 356, 218, -3.0)  # leaned
P("props_medium", "tent_green", 212, 232)
P("props_medium", "tripod_cauldron", 302, 238)
P("props_medium", "dirt_patch", 326, 250)
R(os.path.join(B4, "A1", "A1b_0.png"), 326, 246)          # lit fire ring
P("props_medium", "radio_stump", 370, 258)
P("props_medium", "log_bench", 256, 262)
# rest corner (E): hammock by the tall pine, picnic set below
P("props_large", "hammock", 566, 150)
P("props_large", "picnic_table", 516, 250)
P("props_medium", "picnic_basket", 498, 266)
P("props_medium", "tea_table", 472, 276)
P("props_medium", "tent_red", 192, 300, -2.5)      # leaned
# spare unlit fire pit near the rest corner (storytelling; A1b flame
# stays on the shipped ring at the kitchen fire)
P("props_medium", "fire_ring_unlit_v2", 565, 294)
# work edge (NE/E): coop, herbs/racks, broom, cabin planter, shrine
# cottage_shed = shipped cabin reused as a small second structure in
# the row-3 treeline gap, back-left of the coop/spirit_house pair
P("props_large", "cottage_shed", 566, 110)
P("props_small", "spirit_house", 596, 130)
P("props_medium", "flower_box", 408, 158)
P("props_medium", "chicken_coop", 540, 164)
P("props_small", "chili_garlic_string", 518, 170)
P("props_small", "dried_fish_rack", 482, 166)
P("props_small", "S_15", 566, 178)
# characters
R(os.path.join(B4, "A2", "A2_idle_south_0.png"), 348, 262)  # warden idle S
P("characters", "ranger_mai_south", 468, 254)
P("characters", "camp_dog_south", 300, 306)

for _, fn in sorted(jobs, key=lambda j: j[0]):
    fn()

# --------------------------------------------------- warm multiply (v3)
# engine's CanvasModulate #fbf4e4 — near-white sunny cast vs the old
# #f4ead3 which over-darkened the scene (2026-10-12 colour correction).
arr = np.array(scene).astype(float)
arr[..., :3] = np.clip(arr[..., :3]
                       * np.array((251, 244, 228)) / 255.0, 0, 255)
scene = Image.fromarray(arr.astype(np.uint8))

BASE = os.path.join(CLN, "pinewatch_comp_v3.png")
os.makedirs(CLN, exist_ok=True)
scene.save(BASE)
print("->", BASE)

# ---------------------------------------------------------------- UI bits
def nine_slice(im, w, h, ins):
    """ins = dict l,t,r,b (px). Nearest-stretch: border kept, center
    stretched (flat interiors make this lossless)."""
    l, t, r, b = ins["l"], ins["t"], ins["r"], ins["b"]
    sw, sh = im.size
    # clamp so borders fit the target
    if l + r > w - 4:
        l = r = max(2, (w - 4) // 2)
    if t + b > h - 4:
        t = b = max(2, (h - 4) // 2)
    out = Image.new("RGBA", (w, h))
    # corners
    out.paste(im.crop((0, 0, l, t)), (0, 0))
    out.paste(im.crop((sw - r, 0, sw, t)), (w - r, 0))
    out.paste(im.crop((0, sh - b, l, sh)), (0, h - b))
    out.paste(im.crop((sw - r, sh - b, sw, sh)), (w - r, h - b))
    # edges
    out.paste(im.crop((l, 0, sw - r, t)).resize((w - l - r, t)),
              (l, 0))
    out.paste(im.crop((l, sh - b, sw - r, sh)).resize((w - l - r, b)),
              (l, h - b))
    out.paste(im.crop((0, t, l, sh - b)).resize((l, h - t - b)),
              (0, t))
    out.paste(im.crop((sw - r, t, sw, sh - b)).resize((r, h - t - b)),
              (w - r, t))
    # center
    out.paste(im.crop((l, t, sw - r, sh - b))
              .resize((w - l - r, h - t - b)), (l, t))
    return out

FONT = os.path.join(STG, "font", "F1_1.ttf")
def text(dr, xy, s, size=9, fill=(62, 40, 20)):
    dr.text(xy, s, font=ImageFont.truetype(FONT, size), fill=fill)

def piece(name):
    return img(os.path.join(PIECES, name + ".png"))

PILL = {"l": 14, "r": 14, "t": 5, "b": 6}      # capsule insets for banner

def pill(w, h):
    return nine_slice(piece("hud_banner_flat"), w, h, PILL)

def icon_pick(want):
    """pick an icon index whose mean color best matches a target hue"""
    best = (1e9, None)
    for i in range(64):
        p = os.path.join(STG, "icons", f"I1_{i}.png")
        if not os.path.exists(p):
            continue
        a = np.array(load(p))
        m = a[..., 3] > 100
        if not m.any():
            continue
        rgb = a[..., :3][m].mean(0)
        d = float(((rgb - np.array(want)) ** 2).sum() ** 0.5)
        if d < best[0]:
            best = (d, i)
    return best[1]

# ============================================================== hud_mock
hud = Image.eval(scene.copy().convert("RGB"),
                 lambda v: int(v * 0.90))                # dim ~10%
dr = ImageDraw.Draw(hud)

# top-left: coins pill + day/weather pill
p1 = pill(78, 20); hud.paste(p1, (8, 6), p1)
p2 = pill(92, 20); hud.paste(p2, (8, 30), p2)
coin = load(os.path.join(STG, "icons",
                         f"I1_{icon_pick((230, 180, 60))}.png"))
hud.paste(coin, (12, 8), coin)
text(dr, (30, 10), "1,245", 9)
sun = load(os.path.join(STG, "icons",
                        f"I1_{icon_pick((250, 210, 90))}.png"))
hud.paste(sun, (12, 32), sun)
text(dr, (30, 34), "DAY 3", 9)

# top-right: rating pill + journal badge pill
p3 = pill(74, 20); hud.paste(p3, (W - 82, 6), p3)
star = load(os.path.join(STG, "icons",
                         f"I1_{icon_pick((240, 200, 40))}.png"))
hud.paste(star, (W - 78, 8), star)
text(dr, (W - 60, 10), "4.6", 9)
p4 = pill(28, 20); hud.paste(p4, (W - 40, 30), p4)
journal = load(os.path.join(STG, "icons",
                            f"I1_{icon_pick((150, 100, 60))}.png"))
hud.paste(journal, (W - 34, 32), journal)

# bottom-right: phase button
ph = nine_slice(piece("hud_banner_flat"), 74, 24, PILL)
hud.paste(ph, (W - 84, H - 34), ph)
text(dr, (W - 70, H - 28), "EVENING", 8)

# proximity bubble over the fire ring
bub = piece("bubble_prompt")
hud.paste(bub, (326 - bub.width // 2, 172), bub)

# bottom-left: toolbar + avatar medallion
tb = piece("hud_toolbar")
hud.paste(tb, (30, H - 28), tb)
med = piece("hud_medallion_empty")
hud.paste(med, (2, H - 60), med)

HUD_OUT = os.path.join(CLN, "hud_mock.png")
hud.save(HUD_OUT)
print("->", HUD_OUT)

# ============================================================ panel_mock
pan = Image.eval(scene.copy().convert("RGB"),
                 lambda v: int(v * 0.60))                # dim ~40%
dr = ImageDraw.Draw(pan)
PW, PH = 420, 260
PX, PY = (W - PW) // 2, (H - PH) // 2
panel = nine_slice(piece("panel_window_flat"), PW, PH,
                   {"l": 11, "t": 27, "r": 12, "b": 11})
pan.paste(panel, (PX, PY), panel)

# title strip across the panel's top edge
ttl = nine_slice(piece("hud_banner_flat"), 150, 24, PILL)
pan.paste(ttl, (PX + PW // 2 - 75, PY - 10), ttl)
text(dr, (PX + PW // 2 - 26, PY - 4), "GUESTS", 9)

# two guest cards
card = piece("card_guest")
pan.paste(card, (PX + 24, PY + 34), card)
pan.paste(card, (PX + 140, PY + 34), card)

# slot row right side: parchment + dark slots + wood medallion
pan.paste(piece("slot_parchment"), (PX + 262, PY + 40),
          piece("slot_parchment"))
pan.paste(piece("slot_dark"), (PX + 322, PY + 40), piece("slot_dark"))
pan.paste(piece("slot_parchment"), (PX + 262, PY + 100),
          piece("slot_parchment"))
pan.paste(piece("medallion_wood"), (PX + 324, PY + 102),
          piece("medallion_wood"))

# buttons along the bottom
pan.paste(piece("btn_green"), (PX + 40, PY + 196), piece("btn_green"))
text(dr, (PX + 62, PY + 208), "CHECK IN", 8)
pan.paste(piece("btn_gold"), (PX + 150, PY + 196), piece("btn_gold"))
text(dr, (PX + 182, PY + 208), "BOOK", 8)

# red seal on the panel's bottom-right corner
pan.paste(piece("seal_red"), (PX + PW - 60, PY + PH - 60), piece("seal_red"))

PAN_OUT = os.path.join(CLN, "panel_mock.png")
pan.save(PAN_OUT)
print("->", PAN_OUT)

# ==================================================== grade_compare.png
# side-by-side review stack: reference | engine shot | this comp,
# 4 px black separators (layout read off the existing file)
GAP = 4
cmp_imgs = [Image.open(os.path.join(ROOT, "docs", "reference",
                                  "eastward.jpg")).convert("RGB")
            .resize((W, 360), Image.LANCZOS)]
eng_p = os.path.join(CLN, "pinewatch_engine_graded.png")
if os.path.exists(eng_p):
    eng_im = Image.open(eng_p).convert("RGB")
    cmp_imgs.append(eng_im.crop((0, 0, W, min(360, eng_im.height))))
cmp_imgs.append(scene.convert("RGB").crop((0, 0, W, 360)))
tot_h = sum(i.height for i in cmp_imgs) + GAP * (len(cmp_imgs) - 1)
cmp_out = Image.new("RGB", (W, tot_h))
y = 0
for im in cmp_imgs:
    cmp_out.paste(im, (0, y))
    y += im.height + GAP
GC_OUT = os.path.join(CLN, "grade_compare.png")
cmp_out.save(GC_OUT)
print("->", GC_OUT)
