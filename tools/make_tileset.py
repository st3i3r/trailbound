#!/usr/bin/env python3
"""Emit game/resources/pinewatch_terrain.tres — a Godot TileSet built from
the three 128x128 wang-corner sheets in game/assets/pinewatch/terrain/.

Each sheet ships a <name>.json (PixelLab pro-tileset metadata). Its
tileset_data.tiles[] gives, per 32 px tile, the atlas bounding_box and the
four corners {NE,NW,SE,SW}: "upper" (grass) or "lower" (water/forest/stone).

Mapping (mirrors tools/scene_comp_v2.py):
  * One TileSetAtlasSource per sheet -> one terrain set per sheet.
  * Terrain 0 = "lower" (water/forest floor/stone), terrain 1 = "upper"
    (grass).  Corner peering bits only; side bits stay unset so
    match_corners_and_sides treats them as wildcards.
  * Tile center terrain: the all-lower tile (wang_0) is the only
    "lower-center" tile — blob cells always paint as the full lower tile
    and transitions are carved into neighbouring upper cells, exactly like
    the comp's corners() OR-rule.

Run:  python tools/make_tileset.py
Then: godot --path game --import   (regenerates .godot import cache)
"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TDIR = os.path.join(ROOT, "game", "assets", "pinewatch", "terrain")
OUT = os.path.join(ROOT, "game", "resources", "pinewatch_terrain.tres")

# (json/png stem, terrain-set index, lower name, upper name, lower color, upper color)
SETS = [
    ("terrain_grass_water_pro_0",  0, "water",  "grass", (0.22, 0.52, 0.62), (0.38, 0.66, 0.28)),
    ("terrain_grass_forest_pro_0", 1, "forest", "grass", (0.20, 0.38, 0.20), (0.38, 0.66, 0.28)),
    ("terrain_grass_stone_pro_0",  2, "stone",  "grass", (0.55, 0.52, 0.45), (0.38, 0.66, 0.28)),
]

# grass_variant_* tiles are RETIRED (2026-10-12): 32px tile-swap macro
# zones are forbidden by the ground recipe — variation now comes from the
# fx/ground_tintmap.png overlay (tools/tb_tintmap.py).  Keep this empty.
VARIANTS = []

# Fill-variant tiles (2026-10-13): the two pure fills per sheet
# (wang_15 UUUU grass / wang_0 LLLL lower) stamped one identical pattern
# over ~100 cells.  tools/tb_dither.py emits VAR_N 32x32 variants per
# fill (variant_<tag>_<UUUU|LLLL>_<i>.png); each becomes its own 1-tile
# atlas source with the SAME terrain peering bits as its base tile, so
# variants are legal wherever the base is and terrain-connect may even
# resolve to them.  pinewatch_test.gd re-seats pure-fill cells on a
# hash-picked variant source — ordering below is the source-id contract:
#   source 3 + sheet_idx*12 + fill_idx*6 + variant_idx
VAR_N = 6
VAR_FILLS = (("UUUU", 1), ("LLLL", 0))   # (suffix, center terrain)
# atlas coord of each fill inside its 128x128 sheet (for reference:
# UUUU = wang_15 at (0,3), LLLL = wang_0 at (2,1))

# JSON corner name -> .tres peering-bit key
BIT = {"NW": "top_left_corner", "NE": "top_right_corner",
       "SE": "bottom_right_corner", "SW": "bottom_left_corner"}


def col(c):
    return "Color(%s, %s, %s, 1)" % c


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    ext, sub, res = [], [], []
    for stem, si, lname, uname, lcol, ucol in SETS:
        jp = os.path.join(TDIR, stem + ".json")
        data = json.load(open(jp))
        tiles = data["tileset_data"]["tiles"]
        assert len(tiles) == 16, f"{stem}: expected 16 wang tiles, got {len(tiles)}"
        eid = f"{si + 1}_{lname}"
        ext.append(f'[ext_resource type="Texture2D" '
                   f'path="res://assets/pinewatch/terrain/{stem}.png" id="{eid}"]')
        lines = [f'[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_{lname}"]',
                 f'texture = ExtResource("{eid}")',
                 'texture_region_size = Vector2i(32, 32)']
        for t in tiles:
            x = int(t["bounding_box"]["x"]) // 32
            y = int(t["bounding_box"]["y"]) // 32
            corners = t["corners"]
            n_lower = sum(1 for v in corners.values() if v == "lower")
            center = 0 if n_lower == 4 else 1      # see module docstring
            lines.append(f"{x}:{y}/0 = 1")
            lines.append(f"{x}:{y}/0/terrain_set = {si}")
            lines.append(f"{x}:{y}/0/terrain = {center}")
            for cn in ("NW", "NE", "SE", "SW"):
                v = 0 if corners[cn] == "lower" else 1
                lines.append(f"{x}:{y}/0/terrains_peering_bit/{BIT[cn]} = {v}")
        sub.append("\n".join(lines))
    for vi, vname in enumerate(VARIANTS):
        eid = f"{len(SETS) + vi + 1}_{vname}"
        ext.append(f'[ext_resource type="Texture2D" '
                   f'path="res://assets/pinewatch/terrain/'
                   f'grass_variant_{vname}.png" id="{eid}"]')
        sub.append("\n".join(
            [f'[sub_resource type="TileSetAtlasSource" '
             f'id="TileSetAtlasSource_grass_{vname}"]',
             f'texture = ExtResource("{eid}")',
             'texture_region_size = Vector2i(32, 32)',
             '0:0/0 = 1']))
    # ------------------------------------------------- fill variants
    # one 1-tile atlas source per variant PNG; source order = SETS order
    # (sheet idx) x VAR_FILLS (fill idx) x VAR_N — mirrored by
    # _variant_source() in pinewatch_test.gd and scene_comp_v2.py
    var_names = []
    for stem, si, lname, uname, lcol, ucol in SETS:
        for fi, (fill, center) in enumerate(VAR_FILLS):
            for i in range(VAR_N):
                vn = f"{lname}_{fill}_{i}"
                var_names.append(vn)
                png_n = f"variant_{lname}_{fill}_{i}.png"
                assert os.path.exists(os.path.join(TDIR, png_n)), \
                    f"missing {png_n} — run tools/tb_dither.py first"
                eid = f"var_{vn}"
                ext.append(f'[ext_resource type="Texture2D" '
                           f'path="res://assets/pinewatch/terrain/{png_n}"'
                           f' id="{eid}"]')
                bit = "1" if fill == "UUUU" else "0"
                lines = [f'[sub_resource type="TileSetAtlasSource" '
                         f'id="TileSetAtlasSource_var_{vn}"]',
                         f'texture = ExtResource("{eid}")',
                         'texture_region_size = Vector2i(32, 32)',
                         '0:0/0 = 1',
                         f'0:0/0/terrain_set = {si}',
                         f'0:0/0/terrain = {center}']
                for cn in ("NW", "NE", "SE", "SW"):
                    lines.append(f"0:0/0/terrains_peering_bit/{BIT[cn]}"
                                 f" = {bit}")
                sub.append("\n".join(lines))
    for stem, si, lname, uname, lcol, ucol in SETS:
        res += [f"terrain_set_{si}/mode = 0",
                f"terrain_set_{si}/terrain_0/name = \"{lname.capitalize()}\"",
                f"terrain_set_{si}/terrain_0/color = {col(lcol)}",
                f"terrain_set_{si}/terrain_1/name = \"{uname.capitalize()}\"",
                f"terrain_set_{si}/terrain_1/color = {col(ucol)}"]
    src_names = [n for (_, _, n, *_r) in SETS] \
        + ["grass_" + v for v in VARIANTS] \
        + ["var_" + v for v in var_names]
    res += [f"sources/{i} = SubResource(\"TileSetAtlasSource_{n}\")"
            for i, n in enumerate(src_names)]

    doc = ("[gd_resource type=\"TileSet\" load_steps=%d format=3]\n\n"
           % (len(ext) + len(sub) + 1)
           + "\n".join(ext) + "\n\n"
           + "\n\n".join(sub) + "\n\n"
           + "[resource]\ntile_size = Vector2i(32, 32)\n"
           + "\n".join(res) + "\n")
    open(OUT, "w", newline="\n").write(doc)
    print("wrote", OUT,
          f"({len(SETS)} terrain sheets x 16 tiles + "
          f"{len(VARIANTS)} retired + {len(var_names)} fill-variant "
          f"sources, 3 terrain sets)")


if __name__ == "__main__":
    sys.exit(main())
