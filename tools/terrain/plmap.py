#!/usr/bin/env python3
"""Render a PixelLab topdown map using the account's wang tilesets.

Map = grid of terrain cells (from get_map overview). Each output cell picks a
tile by its four corner terrains; a corner is claimed by the highest-priority
terrain of the <=4 cells touching that vertex. Two-terrain corner patterns use
that pair's 16-tile wang sheet (lower=non-grass, upper=grass); single-terrain
cells use the all-corners base tile; three-terrain mixes collapse to the
highest-priority non-grass pair (rare in this map).

Tilesets used (PixelLab ids):
  water_grass c11258cb-4d20-4eb0-9acf-7f28534c33fc   (fresh teal -> spring grass)
  dirt_grass  5baec2e2-1ab4-44f3-a6b7-bb678846014a   (golden dirt -> grass)
  stone_grass 5d14702f-fa22-4efb-a60f-9e717f9e92e4   (flagstone -> grass)

Usage: python -m tools.terrain.plmap [out.png]
"""
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TILES = f'{ROOT}/assets_src/pl_tiles'
OUT = f'{ROOT}/assets_src/stage/plmap.png'
T = 32

# trailbound_pinewatch_v5 (0adab69e-c35b-45f8-8a19-dbb9466445bd)
# bounds x -1..20, y -1..12 ; w=dirt f=grass a=flagstone c=water .=empty
GRID = [
    "FFFFFFFFFFFFFFFFFFFFFF",
    "FWWWWWWWWWWWWWWWWWWWWF",
    "FWWWWWWWWWWWWWWWWWWWWF",
    "FFFFFFFFFFFFFFFFWWWWFF",
    "FFFFFFFFFFFFFFFFWWWWFF",
    "FFFFFFFFWWWFFFWWFFFFFF",
    "FFFFFFFFFWWWWWWWFFFFFF",
    "FFFFFFFFFWWWWWWFFFFFFF",
    "FMMMMMFFFWWWWWWWWFFFFF",
    "FMMMMMFSSSSSSSSSSFFFFF",
    "FMMMMMFFFFWWWWWWWFFFFF",
    "FMMMMMFFFFWWWFFFFFFFFF",
    "FMMMMMFFFFWWWFFFFFFFFF",
    "FFFFFFFFFFFFFFFFFFFFFF",
]
# v5 letters: w=dirt, f=grass, a=flagstone, c=water, m was used for water
# in this overview too? -- v5 legend has c=water but overview shows M.
LETTER = {'w': 'dirt', 'f': 'grass', 'a': 'stone', 'c': 'water',
          'm': 'water', 's': 'dirt', '.': 'grass'}
PRIORITY = {'water': 3, 'stone': 2, 'dirt': 2, 'grass': 1}
PAIR_SHEET = {'water': 'water_grass_v2', 'dirt': 'dirt_grass_v2', 'stone': 'stone_grass'}


def load_sheet(name):
    meta = json.load(open(f'{TILES}/{name}.json'))
    img = np.array(Image.open(f'{TILES}/{name}.png').convert('RGB'))
    by_corners = {}
    for t in meta['tileset_data']['tiles']:
        c = t['corners']
        key = (c['NW'], c['NE'], c['SW'], c['SE'])
        bb = t['bounding_box']
        by_corners[key] = img[bb['y']:bb['y'] + bb['height'],
                              bb['x']:bb['x'] + bb['width']]
    return by_corners


def vertex_terrain(cells, vx, vy, h, w):
    """Terrain claiming vertex (vx,vy): highest-priority of cells touching it."""
    best, bp = 'grass', -1
    for cy in (vy - 1, vy):
        for cx in (vx - 1, vx):
            if 0 <= cy < h and 0 <= cx < w:
                t = cells[cy][cx]
                if PRIORITY[t] > bp:
                    best, bp = t, PRIORITY[t]
    return best


def render(cells):
    h, w = len(cells), len(cells[0])
    sheets = {k: load_sheet(v) for k, v in PAIR_SHEET.items()}
    out = np.zeros((h * T, w * T, 3), np.uint8)
    for y in range(h):
        for x in range(w):
            cn = [vertex_terrain(cells, x, y, h, w),
                  vertex_terrain(cells, x + 1, y, h, w),
                  vertex_terrain(cells, x, y + 1, h, w),
                  vertex_terrain(cells, x + 1, y + 1, h, w)]
            non_grass = [t for t in cn if t != 'grass']
            if not non_grass:
                low = 'water'                     # any set's all-upper tile is grass
            else:
                low = max(set(non_grass), key=lambda t: (non_grass.count(t),
                                                         PRIORITY[t]))
            key = tuple('lower' if t == low else 'upper' for t in cn)
            tile = sheets[low].get(key)
            if tile is None:
                tile = sheets[low][('lower',) * 4]
            out[y * T:(y + 1) * T, x * T:(x + 1) * T] = tile
    return out


if __name__ == '__main__':
    cells = [[LETTER[ch.lower()] for ch in row] for row in GRID]
    img = render(cells)
    dst = sys.argv[1] if len(sys.argv) > 1 else OUT
    Image.fromarray(img).save(dst)
    print('saved', dst, img.shape)
