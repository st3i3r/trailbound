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
