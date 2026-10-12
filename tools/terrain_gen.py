#!/usr/bin/env python3
"""Terrain generator — retexture the PixelLab Wang sheet with procedural,
palette-locked surfaces, derive the sibling Wang sets, and cut the
standalone base tiles. Deterministic (seeded); no network.

The PixelLab sheet (assets_src/raw/terrain_grass_dirt_wang_0.png) has good
corner-mask shapes — a dark tufted grass lip on every transition edge —
but flat neon grass and a cobble-y dirt. We classify each sheet pixel
(HSV), keep the shapes, and repaint:

    GRASS_FILL  hue 60-110, sat>.85, val>.75   -> grass texture G
    RIM         other green family (60-170)    -> grass[0..2] by luminance
    DIRT_SHADOW hue<60, val<.55 (lip shade)    -> 2 darkest ground shades
    DIRT        everything else                -> the set's ground texture

Every ground texture is exactly 32-periodic (wrap-around value noise on
lattices that divide 32, all features painted mod 32) and is sampled at
tile-local coords, so shared edges always match. Neighbour-dependent
detail (water's shade band and foam line) is computed on a 3x3
neighbourhood of tiles — each neighbour is the real tile whose corners
match the shared edge — then cropped back to the centre tile.

Outputs in assets_src/gen/ (same 128x128 4x4 layout + corner/bounding-box
metadata as the source set; JSONs marked derived_from):

    terrain_grass_dirt_wang_0    grass <-> packed dirt
    terrain_grass_water_wang_0   grass <-> pond water (shade band + foam)
    terrain_grass_forest_wang_0  grass <-> forest floor (needle litter)
    terrain_grass_stone_wang_0   grass <-> flagstones (mossy gaps)
    terrain_grass_0 / _lush_0 / _worn_0, terrain_dirt_0,
        terrain_dirt_pebbles_0   standalone 32x32 base tiles — variants
                                 differ only >=3px inside the border so
                                 they sit next to the pure Wang tiles

Stdlib only (tools/png.py + palette_lock helpers). Run with no args.
"""
import json, os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import png as pngmod
import palette_lock as pl

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(ROOT, "assets_src", "gen")
RAW = os.path.join(ROOT, "assets_src", "raw")
SRC_PNG = os.path.join(RAW, "terrain_grass_dirt_wang_0.png")
SRC_JSON = os.path.join(RAW, "terrain_grass_dirt_wang_0.json")
SEED = 20261012
T = 32  # tile size

pal = json.load(open(os.path.join(ROOT, "assets_src", "cleanup",
                                  "site_palette.json"), encoding="utf-8"))
R = {n: [pl.hex2rgb(c) for c in cols] for n, cols in pal["ramps"].items()}
SHADOW = tuple(pal["shadow_rgba"])

GRASS_FILL, RIM, DIRT_SHADOW, DIRT = range(4)
CLS_NAME = {GRASS_FILL: "grass_fill", RIM: "rim",
            DIRT_SHADOW: "dirt_shadow", DIRT: "dirt"}


# ---------- classification ----------

def hsv(c):
    r, g, b = (v / 255 for v in c)
    mx, mn = max(r, g, b), min(r, g, b)
    d = mx - mn
    if d == 0:
        h = 0
    elif mx == r:
        h = ((g - b) / d) % 6 * 60
    elif mx == g:
        h = ((b - r) / d + 2) * 60
    else:
        h = ((r - g) / d + 4) * 60
    return h, (d / mx if mx else 0), mx


def classify(c):
    h, s, v = hsv(c)
    if 60 <= h <= 110 and s > .85 and v > .75:
        return GRASS_FILL
    if 60 <= h <= 170:
        return RIM
    if h < 60 and v < .55:
        return DIRT_SHADOW
    return DIRT


def sheet_classes(w, h, rows):
    cls = [[classify((rows[y][x * 4], rows[y][x * 4 + 1], rows[y][x * 4 + 2]))
            for x in range(w)] for y in range(h)]
    # stray non-grass specks inside grass -> grass fill (they would read
    # as dirt holes); two passes catch pairs
    for _ in range(2):
        flip = []
        for y in range(h):
            for x in range(w):
                if cls[y][x] in (DIRT, DIRT_SHADOW):
                    n = sum(cls[yy][xx] in (GRASS_FILL, RIM)
                            for dy in (-1, 0, 1) for dx in (-1, 0, 1)
                            if (dx or dy) and 0 <= y + dy < h
                            and 0 <= x + dx < w
                            for xx, yy in [(x + dx, y + dy)])
                    if n >= 5:
                        flip.append((x, y))
        for x, y in flip:
            cls[y][x] = GRASS_FILL
    return cls


def luma(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


# ---------- 32-periodic ground textures ----------

def lattice_noise(seed, octaves=((8, 1.0), (4, 0.45))):
    """Wrap-around value noise sampled at tile-local coords -> fn(x,y)."""
    rng = random.Random(seed)
    lats = [([[rng.random() for _ in range(l)] for _ in range(l)], l, a)
            for l, a in octaves]
    tot = sum(a for _, _, a in lats)

    def sample(x, y):
        v = 0.0
        for lat, l, a in lats:
            gx, gy = x * l / T, y * l / T
            x0, y0 = int(gx) % l, int(gy) % l
            x1, y1 = (x0 + 1) % l, (y0 + 1) % l
            fx, fy = gx - int(gx), gy - int(gy)
            top = lat[y0][x0] * (1 - fx) + lat[y0][x1] * fx
            bot = lat[y1][x0] * (1 - fx) + lat[y1][x1] * fx
            v += (top * (1 - fy) + bot * fy) * a
        return v / tot
    return sample


def put(t, x, y, c):           # mod-32 paint keeps the texture periodic
    t[y % T][x % T] = c


def tex_grass():
    """Eastward lime field: low contrast, blotches + sparse tufts."""
    n = lattice_noise(SEED + 1)
    t = [[R["grass"][4] for _ in range(T)] for _ in range(T)]
    for y in range(T):
        for x in range(T):
            v = n(x, y)
            if v > .63:
                t[y][x] = R["grass"][3]
            elif v > .57 and (x + y) % 2 == 0:
                t[y][x] = R["grass"][3]          # 50% dither at blob edge
    rng = random.Random(SEED + 2)
    for _ in range(9):                           # highlight specks
        put(t, rng.randrange(T), rng.randrange(T), R["grass"][5])
    for _ in range(6):                           # tiny tufts
        cx, cy = rng.randrange(T), rng.randrange(T)
        for dx, dy in rng.sample([(-1, -1), (0, -1), (1, -1), (-1, 0),
                                  (1, 0), (-1, 1), (0, 1), (1, 1)],
                                 rng.randint(3, 4)):
            put(t, cx + dx, cy + dy, R["grass"][3])
        put(t, cx, cy, R["grass"][2])            # base pixel
    return t


def tex_dirt():
    n = lattice_noise(SEED + 11)
    t = [[R["dirt"][3] for _ in range(T)] for _ in range(T)]
    for y in range(T):
        for x in range(T):
            v = n(x, y)
            if v > .62:
                t[y][x] = R["dirt"][2]
            elif v > .56 and (x + y) % 2 == 0:
                t[y][x] = R["dirt"][2]
    rng = random.Random(SEED + 12)
    for _ in range(8):
        put(t, rng.randrange(T), rng.randrange(T), R["dirt"][4])
    for _ in range(5):
        put(t, rng.randrange(T), rng.randrange(T), R["dirt"][1])
    return t


def tex_water():
    nb = lattice_noise(SEED + 21, ((8, 1.0),))
    nr = lattice_noise(SEED + 22, ((8, 1.0),))
    t = [[R["water"][2] for _ in range(T)] for _ in range(T)]
    for y in range(T):
        band = nb(4, y)                          # horizontal soft bands
        for x in range(T):
            if band + .08 * nr(x, y) > .60:
                t[y][x] = R["water"][1]
    rng = random.Random(SEED + 23)
    for _ in range(7):                           # 2-3px horizontal ripples
        x, y = rng.randrange(T), rng.randrange(T)
        for i in range(rng.randint(2, 3)):
            put(t, x + i, y, R["water"][3])
        if rng.random() < .4:
            put(t, x + 1, y - 1, R["water"][4])  # occasional glint
    return t


def tex_forest():
    n = lattice_noise(SEED + 31)
    t = [[R["grass"][2] for _ in range(T)] for _ in range(T)]
    for y in range(T):
        for x in range(T):
            v = n(x, y)
            if v > .66:
                t[y][x] = R["dirt"][1]
            elif v > .58:
                t[y][x] = R["dirt"][2]
            elif v > .55 and (x + y) % 2 == 0:
                t[y][x] = R["dirt"][2]
    rng = random.Random(SEED + 32)
    cols = [R["wood"][2], R["wood"][3], R["dirt"][3]]
    for _ in range(16):                          # short diagonal needles
        x, y = rng.randrange(T), rng.randrange(T)
        dx = rng.choice((-1, 1))
        c = rng.choice(cols)
        for i in range(rng.randint(1, 2)):
            put(t, x + i * dx, y + i, c)
    return t


def tex_stone():
    """Rounded flagstones on a wrapped jittered 8px grid, mossy gaps."""
    rng = random.Random(SEED + 41)
    L = 4                                        # 4x4 stones per tile
    cell = T // L
    seeds = {}
    for gy in range(L):
        for gx in range(L):
            seeds[(gx, gy)] = (gx * cell + rng.randint(1, cell - 3),
                               gy * cell + rng.randint(1, cell - 3),
                               rng.random())
    n = lattice_noise(SEED + 42)

    def nearest_seed(x, y):
        best, bd = None, 1e9
        for (gx, gy), (sx, sy, j) in seeds.items():
            dx = min(abs(x - sx), T - abs(x - sx))
            dy = min(abs(y - sy), T - abs(y - sy))
            d = dx * dx + dy * dy
            if d < bd:
                bd, best = d, (sx, sy, j)
        return best, bd ** .5

    stone = [[False] * T for _ in range(T)]
    cen = [[None] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            (sx, sy, j), d = nearest_seed(x, y)
            rad = cell * .62 + j * 1.5
            if d < rad + (n(x, y) - .5) * 2:
                stone[y][x] = True
                cen[y][x] = (sx, sy)

    t = [[None] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            if not stone[y][x]:
                v = n(x * 2 % T, y * 2 % T)
                t[y][x] = R["grass"][2] if v > .82 else R["dirt"][2]
                continue
            sx, sy = cen[y][x]
            dx = min((x - sx) % T, (sx - x) % T) * (1 if (x - sx) % T <= T // 2 else -1)
            dy = min((y - sy) % T, (sy - y) % T) * (1 if (y - sy) % T <= T // 2 else -1)
            if any(not stone[(y + dyy) % T][(x + dxx) % T]
                   for dxx, dyy in ((0, -1), (0, 1), (-1, 0), (1, 0))):
                t[y][x] = R["stone"][0]          # 1-px border
            elif dx <= 0 and dy <= 0 and (dx + dy) > -cell * .5 \
                    and n(x, y) > .35:
                t[y][x] = R["stone"][4]          # top-left highlight
            elif dx >= 0 and dy >= 0 and (dx + dy) > cell * .35:
                t[y][x] = R["stone"][1]          # bottom-right edge
            else:
                t[y][x] = R["stone"][2] if n(x + 7, y + 3) > .5 \
                    else R["stone"][3]
    return t


# ---------- tiles, masks, neighbourhood ----------

def load_tiles(cls, w, rows):
    meta = json.load(open(SRC_JSON, encoding="utf-8"))
    tiles = []
    by_corners = {}
    for td in meta["tileset_data"]["tiles"]:
        b = td["bounding_box"]
        key = tuple(td["corners"][k] for k in ("NW", "NE", "SW", "SE"))
        tile = {
            "name": td["name"], "corners": td["corners"], "box": b,
            "cls": [r[b["x"]:b["x"] + b["width"]]
                    for r in cls[b["y"]:b["y"] + b["height"]]],
            "rgb": [[(rows[y][x * 4], rows[y][x * 4 + 1],
                      rows[y][x * 4 + 2])
                     for x in range(b["x"], b["x"] + b["width"])]
                    for y in range(b["y"], b["y"] + b["height"])],
        }
        tile["mask"] = [[c in (GRASS_FILL, RIM) for c in r]
                        for r in tile["cls"]]
        tiles.append(tile)
        by_corners[key] = tile
    assert len(by_corners) == 16, "expected all 16 corner combos"
    return meta, tiles, by_corners


def neighbour_corners(c, dx, dy):
    """Corners of the tile across edge (dx,dy): the shared edge keeps its
    corners, repeated onto the far side; diagonals share one vertex."""
    if dx and dy:                      # diagonal shares one vertex
        v = c["NE" if dx == 1 and dy == -1 else
               "NW" if dx == -1 and dy == -1 else
               "SE" if dx == 1 else "SW"]
        return {"NW": v, "NE": v, "SW": v, "SE": v}
    if dx == 1:
        return {"NW": c["NE"], "NE": c["NE"], "SW": c["SE"], "SE": c["SE"]}
    if dx == -1:
        return {"NW": c["NW"], "NE": c["NW"], "SW": c["SW"], "SE": c["SW"]}
    if dy == -1:
        return {"NW": c["NW"], "NE": c["NE"], "SW": c["NW"], "SE": c["NE"]}
    return {"NW": c["SW"], "NE": c["SE"], "SW": c["SW"], "SE": c["SE"]}


def neighbourhood_mask(tile, by_corners):
    """96x96 grass mask: centre tile + real tiles matching each shared
    edge's corners."""
    m = [[False] * (3 * T) for _ in range(3 * T)]
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx == 0 and dy == 0:
                nb = tile
            else:
                nc = neighbour_corners(tile["corners"], dx, dy)
                key = tuple(nc[k] for k in ("NW", "NE", "SW", "SE"))
                nb = by_corners[key]
            for y in range(T):
                for x in range(T):
                    m[T + dy * T + y][T + dx * T + x] = nb["mask"][y][x]
    return m


def chebyshev_dist(mask):
    """Distance from the nearest True pixel (8-conn BFS), capped at 8."""
    n = len(mask)
    dist = [[99] * n for _ in range(n)]
    q = []
    for y in range(n):
        for x in range(n):
            if mask[y][x]:
                dist[y][x] = 0
                q.append((x, y))
    for x, y in q:
        d = dist[y][x] + 1
        if d > 8:
            continue
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                nx, ny = x + dx, y + dy
                if (dx or dy) and 0 <= nx < n and 0 <= ny < n \
                        and dist[ny][nx] > d:
                    dist[ny][nx] = d
                    q.append((nx, ny))
    return dist


# ---------- set rendering ----------

def luma_index(c, lo, hi, steps):
    i = int((luma(c) - lo) / (hi - lo + 1e-9) * steps)
    return max(0, min(steps - 1, i))


def render_set(tiles, ground_tex, shadow_pal, water=False,
               by_corners=None):
    """-> 128x128 rows. shadow_pal = [dark, darker] for the lip shade."""
    # global rim/shadow luma ranges keep the grading consistent per tile
    rim_l, sh_l = [], []
    for t in tiles:
        for y in range(T):
            for x in range(T):
                if t["cls"][y][x] == RIM:
                    rim_l.append(luma(t["rgb"][y][x]))
                elif t["cls"][y][x] == DIRT_SHADOW:
                    sh_l.append(luma(t["rgb"][y][x]))
    r_lo, r_hi = (min(rim_l), max(rim_l)) if rim_l else (0, 1)
    s_lo, s_hi = (min(sh_l), max(sh_l)) if sh_l else (0, 1)

    foam_rng = random.Random(SEED + 50)
    sheets = {}
    dists = {}
    if water:
        for t in tiles:
            dists[t["name"]] = chebyshev_dist(
                neighbourhood_mask(t, by_corners))

    out = [bytearray(4 * T * 4) for _ in range(4 * T)]
    for t in tiles:
        b = t["box"]
        d3 = dists.get(t["name"])
        for y in range(T):
            for x in range(T):
                cls = t["cls"][y][x]
                src = t["rgb"][y][x]
                if cls == GRASS_FILL:
                    c = TEX["grass"][y][x]
                elif cls == RIM:
                    c = R["grass"][luma_index(src, r_lo, r_hi, 3)]
                elif water and d3 and d3[T + y][T + x] == 1:
                    c = R["water"][0]            # shade band at the bank
                elif water and cls == DIRT_SHADOW:
                    c = R["water"][0]
                elif water and d3 and d3[T + y][T + x] == 2 \
                        and foam_rng.random() < .55:
                    c = R["water"][4] if (x + y) % 3 else R["water"][3]
                elif cls == DIRT_SHADOW:
                    c = shadow_pal[luma_index(src, s_lo, s_hi,
                                              len(shadow_pal))]
                else:
                    c = ground_tex[y][x]
                o = (b["x"] + x) * 4
                out[b["y"] + y][o:o + 4] = (*c, 255)
    return out


def derived_json(name, lower_desc, out_name):
    meta = json.load(open(SRC_JSON, encoding="utf-8"))
    meta["id"] = f'{meta["id"]}-proc-{name}'
    meta["name"] = f'{lower_desc} -> grass (procedural resurface)'
    meta["lower_description"] = lower_desc
    meta["derived_from"] = "terrain_grass_dirt_wang_0 (PixelLab " \
        "c878be0a-64f7-4d5e-87d3-e6108c31d88a, masks kept)"
    meta["generator"] = "tools/terrain_gen.py"
    p = os.path.join(GEN, out_name + ".json")
    json.dump(meta, open(p, "w"), indent=2)
    return p


# ---------- base tiles ----------

def tile_px(sheet_rows, tile):
    b = tile["box"]
    return [[tuple(sheet_rows[b["y"] + y][(b["x"] + x) * 4:
                                          (b["x"] + x) * 4 + 4])
             for x in range(T)] for y in range(T)]


def to_rows(px):
    rows = [bytearray(T * 4) for _ in range(T)]
    for y in range(T):
        for x in range(T):
            rows[y][x * 4:x * 4 + 4] = px[y][x]
    return rows


def interior_variant(px, fn):
    """Mutate only pixels >=3px inside the border so the variant sits
    seamlessly next to the pure Wang tile."""
    for y in range(3, T - 3):
        for x in range(3, T - 3):
            fn(px, x, y)


def main():
    w, h, rows = pngmod.read(SRC_PNG)
    cls = sheet_classes(w, h, rows)
    meta, tiles, by_corners = load_tiles(cls, w, rows)

    TEX["grass"] = tex_grass()
    grounds = {
        "dirt": tex_dirt(), "water": tex_water(),
        "forest": tex_forest(), "stone": tex_stone(),
    }

    sets = [
        ("terrain_grass_dirt_wang_0", "dirt", grounds["dirt"],
         R["dirt"][:2], False,
         "warm light-tan packed dirt footpath"),
        ("terrain_grass_water_wang_0", "water", grounds["water"],
         R["water"][:1], True,
         "calm dark pond water"),
        ("terrain_grass_forest_wang_0", "forest", grounds["forest"],
         R["grass"][:2], False,
         "pine-needle litter over moss"),
        ("terrain_grass_stone_wang_0", "stone", grounds["stone"],
         R["dirt"][:2], False,
         "mossy flagstone paving"),
    ]
    sheets = {}
    for out_name, key, tex, sh_pal, is_water, desc in sets:
        out = render_set(tiles, tex, sh_pal, water=is_water,
                         by_corners=by_corners)
        sheets[key] = out
        pngmod.write(os.path.join(GEN, out_name + ".png"), 4 * T, 4 * T,
                     out)
        print("wrote", out_name + ".png")
        if out_name != "terrain_grass_dirt_wang_0":
            derived_json(key, desc, out_name)
    # main set keeps its PixelLab json, marked derived
    derived_json("dirt", "warm light-tan packed dirt footpath",
                 "terrain_grass_dirt_wang_0")

    # ---- standalone base tiles ----
    grass_t = next(t for t in tiles
                   if all(t["corners"][k] == "upper" for k in t["corners"]))
    dirt_t = next(t for t in tiles
                  if all(t["corners"][k] == "lower" for k in t["corners"]))
    grass_px = tile_px(sheets["dirt"], grass_t)
    dirt_px = tile_px(sheets["dirt"], dirt_t)

    def save(name, px):
        pngmod.write(os.path.join(GEN, name + ".png"), T, T, to_rows(px))
        print("wrote", name + ".png")

    save("terrain_grass_0", grass_px)
    save("terrain_dirt_0", dirt_px)

    rng = random.Random(SEED + 60)
    lush = [r[:] for r in grass_px]
    clumps = [(rng.randrange(4, T - 6), rng.randrange(4, T - 6))
              for _ in range(4)]
    def lush_fn(px, x, y):
        for cx, cy in clumps:
            if abs(x - cx) + abs(y - cy) <= 1:
                px[y][x] = (*R["foliage"][2 if (x + y) % 2 else 3], 255)
    interior_variant(lush, lush_fn)
    for _ in range(6):                           # extra tufts, interior only
        cx, cy = rng.randrange(4, T - 4), rng.randrange(4, T - 4)
        for dx, dy in rng.sample([(-1, 0), (1, 0), (0, -1), (0, 1),
                                  (-1, -1), (1, -1)], 3):
            if 3 <= cy + dy < T - 3 and 3 <= cx + dx < T - 3:
                lush[cy + dy][cx + dx] = (*R["grass"][3], 255)
        lush[cy][cx] = (*R["grass"][2], 255)
    save("terrain_grass_lush_0", lush)

    worn = [r[:] for r in grass_px]
    patches = [(rng.randrange(4, T - 6), rng.randrange(4, T - 6),
                rng.randint(1, 2)) for _ in range(5)]
    def worn_fn(px, x, y):
        for cx, cy, r in patches:
            if abs(x - cx) <= r and abs(y - cy) <= r and \
                    abs(x - cx) + abs(y - cy) <= r + 1:
                px[y][x] = (*R["dirt"][3 if (x + y) % 3 else 2], 255)
    interior_variant(worn, worn_fn)
    save("terrain_grass_worn_0", worn)

    peb = [r[:] for r in dirt_px]
    for _ in range(4):
        cx, cy = rng.randrange(4, T - 5), rng.randrange(4, T - 5)
        s = rng.randint(1, 2)
        for dy in range(s + 1):
            for dx in range(s + 1):
                if 3 <= cy + dy < T - 3 and 3 <= cx + dx < T - 3:
                    peb[cy + dy][cx + dx] = \
                        (*R["stone"][2 + (dx + dy) % 2], 255)
        if cy + s + 1 < T - 3:                   # 1-px ground shade
            for dx in range(s + 1):
                peb[cy + s + 1][cx + dx] = (*R["dirt"][1], 255)
    save("terrain_dirt_pebbles_0", peb)

    print("done — all surfaces 32-periodic, palette-locked")


TEX = {}
if __name__ == "__main__":
    main()
