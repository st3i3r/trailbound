#!/usr/bin/env python3
"""Superseded sweep + terrain fixes.

- lists gen/ root files superseded by staged batch3/4 winners ->
  out/superseded_list.json, then moves them to gen/_superseded/
- T2 water: desaturate/cool the teal ~10% -> out/terrain/
- T3 forest floor: soften 2-3 of the most regular 'waffle' bumps ->
  out/terrain/
Never modifies staging/.
"""
import os, json, shutil
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(ROOT, "assets_src", "gen")
STG = os.path.join(ROOT, "assets_src", "staging", "pinewatch")
OUT = os.path.join(ROOT, "assets_src", "out")
SUP = os.path.join(GEN, "_superseded")

# ---------------------------------------------------------- superseded
SUPERSEDED = {
    "campfire_0.png": "fire_ring_unlit/lit_static (M1) + A1b flame (b4)",
    "player_0.png": "warden_* 8-dir turnaround (C1)",
    "player_front_0.png": "warden_* 8-dir turnaround (C1)",
    "prop_lantern_post_0.png": "lantern_post + lantern_post_small (M1/S)",
    "prop_log_bench_0.png": "log_bench (M1)",
    "prop_signpost_0.png": "signpost (M1)",
    "prop_stump_0.png": "radio_stump (M1) / stool_pair seat role",
    "prop_tent_olive_0.png": "tent_green (M1)",
    "prop_tent_rust_0.png": "tent_red (M1)",
    "prop_van_p_0.png": "outfitter_van (L1)",
    "terrain_dirt_0.png": "dirt_patch (M1) + T4 stone wang",
    "terrain_dirt_pebbles_0.png": "dirt_patch (M1) + T4 stone wang",
    "terrain_floor_flat_0.png": "T3 forest floor wang",
    "terrain_grass_0.png": "T2/T3/T4 pro wang upper (grass)",
    "terrain_grass_flat_0.png": "T2/T3/T4 pro wang upper (grass)",
    "terrain_grass_dirt_wang_0.png": "T4 grass->stone pro wang",
    "terrain_grass_dirt_wang_0.json": "T4 grass->stone pro wang",
    "terrain_grass_forest_wang_0.png": "T3 grass->forest pro wang",
    "terrain_grass_forest_wang_0.json": "T3 grass->forest pro wang",
    "terrain_grass_lush_0.png": "T2/T3/T4 pro wang upper (grass)",
    "terrain_grass_stone_wang_0.png": "T4 grass->stone pro wang",
    "terrain_grass_stone_wang_0.json": "T4 grass->stone pro wang",
    "terrain_grass_water_wang_0.png": "T2 grass->water pro wang",
    "terrain_grass_water_wang_0.json": "T2 grass->water pro wang",
    "terrain_grass_worn_0.png": "T2/T3/T4 pro wang upper (grass)",
    "terrain_water_flat_0.png": "T2 grass->water pro wang",
    "tree_pine_green_0.png": "pine_tall_a/b (L1)",
    "tree_pine_green_1.png": "pine_tall_a/b (L1)",
    "tree_pine_green_2.png": "pine_tall_a/b (L1)",
    "tree_pine_green_3.png": "pine_tall_a/b (L1)",
    "tree_ref_0.png": "flamboyant_tree (L1)",
    "tree_ref_1.png": "flamboyant_tree (L1)",
    "tree_ref_2.png": "flamboyant_tree (L1)",
    "tree_ref_3.png": "flamboyant_tree (L1)",
}
KEPT = {"prop_boulder_0.png": "no batch3/4 replacement (boulder role)",
        "prop_supply_crate_0.png": "no batch3/4 replacement (crate role)"}

def sweep():
    moved, listed = [], {}
    for fn in sorted(os.listdir(GEN)):
        p = os.path.join(GEN, fn)
        if not os.path.isfile(p) or fn not in SUPERSEDED:
            continue
        listed[fn] = {"superseded_by": SUPERSEDED[fn],
                      "moved_to": f"gen/_superseded/{fn}"}
        moved.append(fn)
    with open(os.path.join(OUT, "superseded_list.json"), "w") as f:
        json.dump({"superseded": listed, "kept_no_replacement":
                   {k: v for k, v in KEPT.items()},
                   "note": "gen/candidates/** is the candidate pool, not "
                           "canonical — left untouched"}, f, indent=1)
    os.makedirs(SUP, exist_ok=True)
    for fn in moved:
        shutil.move(os.path.join(GEN, fn), os.path.join(SUP, fn))
    print("superseded moved:", len(moved))

# ---------------------------------------------------------- terrain
def rgb2hsv_arr(rgb):
    x = rgb.astype(float) / 255
    mx, mn = x.max(-1), x.min(-1)
    d = mx - mn
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    r, g, b = x[..., 0], x[..., 1], x[..., 2]
    h = np.where(d == 0, 0,
        np.where(mx == r, ((g - b) / d) % 6,
        np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4))) / 6 % 1
    return h, s, mx

def hsv2rgb_arr(h, s, v):
    i = np.floor(h * 6).astype(int) % 6
    f = h * 6 - np.floor(h * 6)
    p = v * (1 - s); q = v * (1 - f * s); t = v * (1 - (1 - f) * s)
    out = np.zeros(h.shape + (3,))
    for k in range(6):
        m = i == k
        r = np.choose(k, [v, q, p, p, t, v])[..., 0] if False else None
    # vectorized via stacking
    r = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5],
                  [v, q, p, p, t, v])
    g = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5],
                  [t, v, v, q, p, p])
    b = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5],
                  [p, p, t, v, v, q])
    return np.stack([r, g, b], -1)

def fix_water():
    """Desaturate + cool the teal water hues ~10%."""
    p = os.path.join(OUT, "terrain", "terrain_grass_water_pro_0.png")
    arr = np.array(Image.open(p).convert("RGBA"))
    h, s, v = rgb2hsv_arr(arr[..., :3])
    m = (arr[..., 3] > 0) & (s > 0.30) & (h > 0.38) & (h < 0.60)
    s2 = np.clip(s * 0.90, 0, 1)                    # -10% sat
    h2 = h - 0.02                                    # teal -> cooler blue
    rgb = hsv2rgb_arr(np.where(m, h2, h),
                      np.where(m, s2, s), v)
    arr[..., :3] = np.clip(rgb * 255, 0, 255).astype(np.uint8)
    Image.fromarray(arr).save(p)
    print("T2 water: adjusted px:", int(m.sum()))

def fix_forest():
    """Soften the 3 most isolated bright 'waffle' bumps inside T3's
    forest-dominant (lower) tiles: wang_0(64,32), wang_1(96,32),
    wang_2(64,64), wang_8(32,32)."""
    p = os.path.join(OUT, "terrain", "terrain_grass_forest_pro_0.png")
    arr = np.array(Image.open(p).convert("RGBA")).astype(float)
    lum = (arr[..., 0] * 0.299 + arr[..., 1] * 0.587
           + arr[..., 2] * 0.114)
    cells = [(64, 32), (96, 32), (64, 64), (32, 32)]
    bumps = []   # (isolation, cx, cy)
    for x0, y0 in cells:
        cell = lum[y0:y0 + 32, x0:x0 + 32]
        mean = cell.mean()
        for y in range(2, 30):
            for x in range(2, 30):
                c = cell[y, x]
                ring = np.concatenate([cell[y - 2, x - 2:x + 3],
                                       cell[y + 2, x - 2:x + 3],
                                       cell[y - 1:y + 2, x - 2],
                                       cell[y - 1:y + 2, x + 2]])
                iso = c - ring.mean()
                if c == cell[y - 1:y + 2, x - 1:x + 2].max() and iso > 8:
                    bumps.append((iso, x0 + x, y0 + y))
    # non-max suppression >= 5 px apart, strongest first
    bumps.sort(key=lambda b: -b[0])
    picked = []
    for b in bumps:
        if all(abs(b[1] - q[1]) + abs(b[2] - q[2]) >= 5 for q in picked):
            picked.append(b)
        if len(picked) == 3:
            break
    for i, (iso, bx, by) in enumerate(picked):
        reg = arr[by - 1:by + 2, bx - 1:bx + 2]
        flat = reg[1, 1, :3] * 0.40 + reg[..., :3].reshape(-1, 3).mean(0) * 0.60
        arr[by, bx, :3] = flat
        # feather the 4-neighbours halfway
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            px = arr[by + dy, bx + dx, :3]
            arr[by + dy, bx + dx, :3] = px * 0.75 + flat * 0.25
        print(f"  softened bump {i} at ({bx},{by}) isolation {iso:.1f}")
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(p)

if __name__ == "__main__":
    sweep()
    fix_water()
    fix_forest()
