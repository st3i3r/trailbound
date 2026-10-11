#!/usr/bin/env python3
"""Pinewatch scene compositor — paints the palette-locked art into a
640x360 scene exactly as Godot will: tile grid + sprites anchored
bottom-center, Y-sorted, source-over alpha. Proves the art composes
before we wire up TileMapLayer/Y-sort in engine.

Output: assets_src/cleanup/pinewatch_comp.png
Stdlib only (tools/png.py).
"""
import os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import png as pngmod

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
G = os.path.join(ROOT, "assets_src", "gen")
OUT = os.path.join(ROOT, "assets_src", "cleanup", "pinewatch_comp.png")
W, H, T = 640, 360, 32

_cache = {}
def img(name):
    if name not in _cache:
        _cache[name] = pngmod.read(os.path.join(G, name + ".png"))
    return _cache[name]

canvas = [bytearray(W * 4) for _ in range(H)]

def blit(name, x, y):
    """Top-left paste, source-over straight alpha."""
    sw, sh, rows = img(name)
    for sy in range(sh):
        dy = y + sy
        if dy < 0 or dy >= H:
            continue
        srow, drow = rows[sy], canvas[dy]
        for sx in range(sw):
            dx = x + sx
            if dx < 0 or dx >= W:
                continue
            a = srow[sx * 4 + 3]
            if a == 0:
                continue
            so, do = sx * 4, dx * 4
            if a == 255:
                drow[do:do + 4] = srow[so:so + 4]
            else:
                inv = 255 - a
                for c in range(3):
                    drow[do + c] = (srow[so + c] * a + drow[do + c] * inv) // 255
                drow[do + 3] = min(255, a + drow[do + 3] * inv // 255)

def rot90(rows, w, h):
    """90° CW — returns (rows, w', h')."""
    out = [bytearray(h * 4) for _ in range(w)]
    for y in range(h):
        for x in range(w):
            out[x][(h - 1 - y) * 4:(h - y) * 4] = rows[y][x * 4:(x + 1) * 4]
    return out, h, w

def tile(name, tx, ty, rot=0, mirror=False):
    if rot or mirror:
        key = f"{name}:{rot}:{int(mirror)}"
        if key not in _cache:
            sw, sh, rows = img(name)
            src = [bytearray(r) for r in rows]
            for _ in range(rot % 4):
                src, sw, sh = rot90(src, sw, sh)
            if mirror:
                for row in src:
                    for x in range(sw // 2):
                        a, b = x * 4, (sw - 1 - x) * 4
                        row[a:a + 4], row[b:b + 4] = row[b:b + 4], row[a:a + 4]
            _cache[key] = (sw, sh, src)
        blit(key, tx * T, ty * T)
        return
    blit(name, tx * T, ty * T)

def anchor(name, x, y):
    """Bottom-center anchored sprite."""
    sw, sh, _ = img(name)
    blit(name, x - sw // 2, y - sh)

# ---- ground -----------------------------------------------------------
# forest backdrop rows 0-2, grass field 3-9, pond bottom-left rows 8-11,
# dirt path wandering up from bottom-center to the fire ring
pond = {(tx, ty) for ty in range(8, 12) for tx in range(0, 4)}
path = {(8, 11), (8, 10), (9, 10), (9, 9), (9, 8), (10, 8), (10, 7),
        (10, 6), (9, 6), (9, 5)}
rng = random.Random(7)
for ty in range(H // T + 1):
    for tx in range(W // T):
        if (tx, ty) in pond:
            tile("terrain_pond_water_0", tx, ty)
        elif (tx, ty) in path:
            tile("terrain_dirt_v2_0", tx, ty, rng.randrange(4), rng.random() < 0.5)
        elif ty < 3:
            tile("terrain_forest_floor_0", tx, ty, rng.randrange(4))
        else:
            v = rng.random()
            name = ("terrain_grass_lush_v2_0" if v < 0.08
                    else "terrain_grass_worn_v2_0" if v < 0.15
                    else "terrain_grass_p1_0")
            tile(name, tx, ty, rng.randrange(4), rng.random() < 0.5)
# shore edge + corners along the pond's top/right banks
for tx in range(4):
    blit("terrain_shore_p_0", tx * T, 7 * T)
blit("terrain_shore_cout_0", 4 * T, 7 * T)
se = img("terrain_shore_p_0")
_cache["shore_e"] = (se[1], se[0], rot90(se[2], se[0], se[1])[0])
for ty in range(8, 12):
    blit("shore_e", 4 * T, ty * T)

# ---- scatter decals (seeded, ~1 per 2 tiles, grass zone only) ---------
decals = ["decal_tuft_a_0", "decal_tuft_b_0", "decal_fern_0",
          "decal_flower_0", "decal_pebbles_0", "decal_mushroom_v2_0"]
for ty in range(3, 11):
    for tx in range(20):
        if (tx, ty) in pond or (tx, ty) in path or rng.random() > 0.10:
            continue
        d = decals[rng.randrange(len(decals))]
        blit(d, tx * T + rng.randrange(8), ty * T + rng.randrange(8))

# ---- props, Y-sorted (back to front) -----------------------------------
props = [
    # backdrop tree line — overlapping the top edge like Eastward
    ("tree_pine_green_2", 30, 70), ("tree_pine_green_0", 95, 78),
    ("tree_ref_2", 170, 72), ("tree_pine_green_2", 240, 70),
    ("tree_pine_green_0", 320, 78), ("tree_ref_3", 400, 70),
    ("tree_pine_green_2", 470, 72), ("tree_pine_green_0", 545, 78),
    ("tree_pine_green_2", 610, 70),
    ("prop_van_p_0", 585, 108),                    # outfitter van, top right
    ("prop_supply_crate_0", 545, 118),
    ("prop_signpost_0", 305, 330),                 # path entrance, bottom
    ("prop_tent_olive_0", 165, 205),               # pad A
    ("prop_tent_rust_0", 500, 195),                # pad B
    ("prop_boulder_0", 415, 235),
    ("prop_lantern_post_0", 255, 190),
    ("prop_log_bench_0", 300, 250),                # fire circle
    ("campfire_0", 350, 230),
    ("prop_stump_0", 390, 255),
    ("player_front_0", 345, 265),
    ("prop_stump_0", 290, 285),
]
for name, x, y in sorted(props, key=lambda p: p[2]):
    anchor(name, x, y)

# flame sits on the ring
anchor("flame_01", 350, 214)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
pngmod.write(OUT, W, H, canvas)
print("->", OUT)
