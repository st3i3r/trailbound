#!/usr/bin/env python3
"""Stage batch-AR candidates -> assets_src/staging/pinewatch/<cat>/.

Per-asset ship spec: canvas-size resize (LANCZOS organic / NEAREST hard),
content-fitted onto the category canvas. Tree T2 composites merge
trunk + canopy onto one 128x128 props_large sheet (shadow added later
by tb_post).

Run:  python tools/tb_stage_ar.py
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets_src", "gen", "candidates", "batchAR4")
STG = os.path.join(ROOT, "assets_src", "staging", "pinewatch")

LANC = Image.LANCZOS
NEAR = Image.NEAREST

# name: (src, cat, canvas, resample)
SPEC = {
    # A-R4 modern camp set
    "dome_tent_sage":   ("dome_tent_sage.png",   "props_medium", (96, 80), LANC),
    "dome_tent_amber":  ("dome_tent_amber.png",  "props_medium", (96, 80), LANC),
    "dome_tent_slate":  ("dome_tent_slate.png",  "props_medium", (96, 80), LANC),
    "camp_table_fold":  ("j8/camp_table_v2.png", "props_medium", (56, 52), NEAR),
    "cooler_box":       ("j8/cooler_box_v2.png", "props_small",  (48, 52), NEAR),
    "folding_chair_pair":("j8/folding_chair_v2.png","props_small",(44, 48), NEAR),
    "propane_stove":    ("j8/propane_stove_v2.png","props_small",(48, 34), NEAR),
    "solar_lantern":    ("solar_lantern.png",    "props_small",  (32, 32), NEAR),
    # J8 L6 keeps — shipped at ratio table sizes (CHAR=48)
    "firewood_bundle":  ("j8/firewood_bundle.png","props_small", (44, 38), NEAR),
    "axe_on_log":       ("j8/axe_on_log.png",    "props_small",  (34, 44), NEAR),
    "camp_pillow":      ("j8/camp_pillow.png",   "props_small",  (38, 28), NEAR),
    "dry_bag":          ("dry_bag.png",          "props_small",  (48, 48), NEAR),
    "duffel_bag":       ("duffel_bag.png",       "props_small",  (48, 48), NEAR),
    # A-R2 undergrowth
    "bush_round_m":     ("bush_round_m.png",     "props_medium", (64, 64), LANC),
    "bush_white_flower_v":("bush_white_flower_v.png","props_medium",(64, 64), LANC),
    "bush_clover":      ("bush_clover.png",      "props_medium", (64, 64), LANC),
    "fern_bank":        ("fern_bank.png",        "props_medium", (64, 64), LANC),
    "grass_tussock":    ("grass_tussock.png",    "props_small",  (48, 48), LANC),
    "reed_shore":       ("reed_shore.png",       "props_medium", (64, 64), LANC),
    # A-R1 bonus vocabulary
    "rock_mossy_s":     ("rock_mossy_s.png",     "props_small",  (48, 48), NEAR),
    "mushrooms_orange": ("mushrooms_orange.png", "props_small",  (40, 40), NEAR),
    "debris_log_mossy": ("debris_log_mossy.png", "props_medium", (64, 64), NEAR),
    "debris_brambles":  ("debris_brambles.png",  "props_medium", (64, 64), NEAR),
    "debris_branch_pile":("debris_branch_pile.png","props_medium",(64, 64), NEAR),
    "pine_sapling":     ("pine_sapling.png",     "props_medium", (64, 64), LANC),
    "root_gnarled":     ("root_gnarled.png",     "props_small",  (48, 48), NEAR),
    "stump_mushroom":   ("stump_mushroom.png",   "props_medium", (64, 64), NEAR),
    "stump_dead":       ("stump_dead.png",       "props_medium", (64, 64), NEAR),
    "stump_burnt":      ("stump_burnt.png",      "props_medium", (64, 64), NEAR),
    # A-R3 shore vocabulary
    "shore_edge_bank":     ("shore_edge_bank.png",    "terrain", (64, 64), NEAR),
    "shore_edge_grass_n":  ("shore_edge_grass_n.png", "terrain", (64, 64), NEAR),
    "shore_edge_vert":     ("shore_edge_vert.png",    "terrain", (64, 64), NEAR),
    "shore_corner_a":      ("shore_corner_a.png",     "terrain", (64, 64), NEAR),
    "shore_corner_b":      ("shore_corner_b.png",     "terrain", (64, 64), NEAR),
    "shore_corner_L":      ("shore_corner_L.png",     "terrain", (64, 64), NEAR),
    "shore_islet":         ("shore_islet.png",        "terrain", (64, 64), NEAR),
    "shore_steps_water":   ("shore_steps_water.png",  "terrain", (64, 64), NEAR),
    "shore_cape_tip":      ("shore_cape_tip.png",     "terrain", (64, 64), NEAR),
    # ---- J9 L6 smalls (42px job) — near-native ships, resize <=1.5x
    # re-gens / replacements
    "solar_lantern":    ("j9/f00.png", "props_small", (18, 30), NEAR),
    "lantern_mini":     ("j9/f01.png", "props_small", (17, 32), NEAR),
    "camp_pillow":      ("j9/f38.png", "props_small", (37, 28), NEAR),
    "camp_kettle":      ("j9/f13.png", "props_small", (18, 30), NEAR),
    "camp_radio":       ("j9/f15.png", "props_small", (23, 28), NEAR),
    "first_aid_pouch":  ("j9/f63.png", "props_small", (28, 26), NEAR),
    "dried_fish_rack":  ("j9/f53.png", "props_small", (37, 34), NEAR),
    # L6 vocabulary
    "enamel_mug":       ("j9/f02.png", "props_small", (22, 22), NEAR),
    "thermos":          ("j9/f03.png", "props_small", (17, 30), NEAR),
    "rope_coil":        ("j9/f04.png", "props_small", (24, 24), NEAR),
    "fence_wood":       ("j9/f05.png", "props_small", (31, 26), NEAR),
    "fence_rope":       ("j9/f06.png", "props_small", (26, 28), NEAR),
    "fence_bamboo":     ("j9/f07.png", "props_small", (38, 26), NEAR),
    "stone_wall_row":   ("j9/f08.png", "props_small", (35, 24), NEAR),
    "signpost_arrow":   ("j9/f12.png", "props_small", (32, 34), NEAR),
    "cook_pot":         ("j9/f14.png", "props_small", (26, 26), NEAR),
    "pho_bowl":         ("j9/f16.png", "props_small", (23, 26), NEAR),
    "banh_mi":          ("j9/f17.png", "props_small", (28, 24), NEAR),
    "phin_coffee":      ("j9/f18.png", "props_small", (17, 24), NEAR),
    "tea_cup":          ("j9/f19.png", "props_small", (15, 24), NEAR),
    "coconut_drink":    ("j9/f20.png", "props_small", (23, 28), NEAR),
    "jam_jar":          ("j9/f21.png", "props_small", (21, 26), NEAR),
    "bread_board":      ("j9/f22.png", "props_small", (30, 26), NEAR),
    "trowel":           ("j9/f23.png", "props_small", (15, 28), NEAR),
    "watering_can":     ("j9/f24.png", "props_small", (31, 32), NEAR),
    "fishing_rod":      ("j9/f25.png", "props_small", (19, 38), NEAR),
    "landing_net":      ("j9/f26.png", "props_small", (29, 32), NEAR),
    "tackle_box":       ("j9/f27.png", "props_small", (30, 26), NEAR),
    "metal_bucket":     ("j9/f28.png", "props_small", (35, 26), NEAR),
    "sleeping_pad":     ("j9/f29.png", "props_small", (33, 26), NEAR),
    "folded_blanket":   ("j9/f30.png", "props_small", (32, 28), NEAR),
    "hiking_boots":     ("j9/f31.png", "props_small", (27, 26), NEAR),
    "sandals":          ("j9/f32.png", "props_small", (27, 22), NEAR),
    "umbrella":         ("j9/f33.png", "props_small", (15, 30), NEAR),
    "insect_spray":     ("j9/f34.png", "props_small", (11, 24), NEAR),
    "folded_map":       ("j9/f35.png", "props_small", (29, 26), NEAR),
    "brass_compass":    ("j9/f36.png", "props_small", (15, 24), NEAR),
    "headlamp":         ("j9/f37.png", "props_small", (32, 24), NEAR),
    "journal_pencil":   ("j9/f39.png", "props_small", (24, 28), NEAR),
    "playing_cards":    ("j9/f40.png", "props_small", (32, 24), NEAR),
    "co_tuong_set":     ("j9/f41.png", "props_small", (29, 32), NEAR),
    "guitar":           ("j9/f42.png", "props_small", (34, 38), NEAR),
    "birdhouse":        ("j9/f43.png", "props_small", (30, 36), NEAR),
    "potted_herb":      ("j9/f44.png", "props_small", (23, 32), NEAR),
    "seed_packet":      ("j9/f45.png", "props_small", (22, 26), NEAR),
    "hanging_fish":     ("j9/f46.png", "props_small", (21, 38), NEAR),
    "crab_basket":      ("j9/f47.png", "props_small", (27, 32), NEAR),
    "rice_sack":        ("j9/f48.png", "props_small", (31, 32), NEAR),
    "banana_bunch":     ("j9/f49.png", "props_small", (25, 24), NEAR),
    "egg_tray":         ("j9/f50.png", "props_small", (27, 24), NEAR),
    "herb_bundle":      ("j9/f51.png", "props_small", (23, 26), NEAR),
    "garlic_braid":     ("j9/f52.png", "props_small", (19, 32), NEAR),
    "log_stool":        ("j9/f54.png", "props_small", (27, 26), NEAR),
    "folded_towel":     ("j9/f55.png", "props_small", (23, 22), NEAR),
    "clothesline":      ("j9/f56.png", "props_small", (40, 32), NEAR),
    "trash_bag":        ("j9/f57.png", "props_small", (27, 32), NEAR),
    "water_jug":        ("j9/f58.png", "props_small", (24, 32), NEAR),
    "trekking_poles":   ("j9/f59.png", "props_small", (37, 38), NEAR),
    "marshmallow_skewer":("j9/f60.png","props_small", (33, 36), NEAR),
    "dutch_oven":       ("j9/f61.png", "props_small", (26, 30), NEAR),
    "kite":             ("j9/f62.png", "props_small", (24, 32), NEAR),
    # stepping stones ship flat as decals (feet-level, no shadow)
    "step_stone_a":     ("j9/f09.png", "decals", (36, 22), NEAR),
    "step_stone_b":     ("j9/f10.png", "decals", (38, 26), NEAR),
    "step_stone_c":     ("j9/f11.png", "decals", (32, 20), NEAR),
}

# T2 tree composites: name -> (canopy_src, trunk_src)
TREES = {
    "tree_broadleaf": ("canopy_broadleaf.png", "trunk_broadleaf.png"),
    "tree_maple":     ("canopy_maple.png",     "trunk_maple.png"),
    "tree_feathery":  ("canopy_feathery.png",  "trunk_feathery.png"),
    "tree_cherry":    ("canopy_cherry.png",    "trunk_cherry.png"),
}

DECALS = [f[:-4] for f in os.listdir(SRC) if f.startswith(("decal_", "tuft_"))]


def content_bbox(a):
    ys, xs = np.where(a > 8)
    if len(xs) == 0:
        return 0, 0, a.shape[1], a.shape[0]
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def fit(img, canvas, resample, margin=1):
    """Trim to content, resize to fit canvas (keep aspect), paste
    bottom-center in the canvas."""
    a = np.array(img.convert("RGBA"))
    x0, y0, x1, y1 = content_bbox(a[..., 3])
    img = Image.fromarray(a[y0:y1, x0:x1])
    cw, ch = canvas
    sc = min((cw - 2 * margin) / img.width, (ch - 2 * margin) / img.height)
    nw, nh = max(1, round(img.width * sc)), max(1, round(img.height * sc))
    img = img.resize((nw, nh), resample)
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    out.paste(img, ((cw - nw) // 2, ch - nh - margin), img)
    return out


def tree_composite(canopy_p, trunk_p):
    """128x128: trunk bottom-center, canopy above (20% overlap)."""
    C = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    tr = Image.open(trunk_p).convert("RGBA")
    a = np.array(tr)
    x0, y0, x1, y1 = content_bbox(a[..., 3])
    tr = Image.fromarray(a[y0:y1, x0:x1])
    sc = 48 / tr.height
    tr = tr.resize((max(1, round(tr.width * sc)), 48), LANC)
    tx = (128 - tr.width) // 2
    ty = 126 - tr.height
    C.paste(tr, (tx, ty), tr)
    ca = Image.open(canopy_p).convert("RGBA")
    a = np.array(ca)
    x0, y0, x1, y1 = content_bbox(a[..., 3])
    ca = Image.fromarray(a[y0:y1, x0:x1])
    sc = min(120 / ca.width, 96 / ca.height)
    ca = ca.resize((max(1, round(ca.width * sc)),
                    max(1, round(ca.height * sc))), LANC)
    cx = (128 - ca.width) // 2
    cy = max(0, ty + int(tr.height * 0.2) - ca.height)
    C.paste(ca, (cx, cy), ca)
    return C


def main():
    done = []
    for name, (src, cat, canvas, res) in SPEC.items():
        p = os.path.join(SRC, src)
        if not os.path.exists(p):
            print("MISS", src)
            continue
        img = fit(Image.open(p), canvas, res)
        os.makedirs(os.path.join(STG, cat), exist_ok=True)
        img.save(os.path.join(STG, cat, name + ".png"))
        done.append(f"{cat}/{name}.png {img.size}")
    for name, (cap, tru) in TREES.items():
        img = tree_composite(os.path.join(SRC, cap), os.path.join(SRC, tru))
        img.save(os.path.join(STG, "props_large", name + ".png"))
        done.append(f"props_large/{name}.png {img.size}")
    for name in DECALS:
        img = fit(Image.open(os.path.join(SRC, name + ".png")), (32, 32), NEAR)
        img.save(os.path.join(STG, "decals", name + ".png"))
        done.append(f"decals/{name}.png")
    print(f"staged {len(done)} assets")
    for d in done:
        print(" ", d)


if __name__ == "__main__":
    main()
