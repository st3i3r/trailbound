#!/usr/bin/env python3
"""Assemble the Pinewatch ground tilemap from the authored tile set.

Zone classification comes from the derendered ground (v13 composition,
props already removed): each 32px cell -> dominant material by median HSV,
then damped by neighbor majority so single odd cells don't pop.

Tiles are reconstructed from the per-tile pixel maps
(assets_src/out/tiles_maps_v16.json + water_flat_map.json) -> the exact
tileset pixels, one tile per cell. No props, no synthesis.

Usage: python -m tools.terrain.mapbuild
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = f'{ROOT}/assets_src/stage/ground_clean.png'
MAPS = f'{ROOT}/assets_src/out/tiles_maps_v16.json'
WATER = f'{ROOT}/assets_src/out/water_flat_map.json'
OUT = f'{ROOT}/assets_src/stage/tilemap.png'
T = 32


def tile_from_map(entry):
    leg = {k: tuple(int(v[i:i + 2], 16) for i in (1, 3, 5))
           for k, v in entry['legend'].items()}
    rows = entry['rows']
    arr = np.array([[leg[c] for c in r] for r in rows], np.uint8)
    return arr


def load_tiles():
    tiles = {e['name']: tile_from_map(e) for e in json.load(open(MAPS))}
    w = json.load(open(WATER))
    tiles['water'] = tile_from_map(w)
    return tiles


def classify(cell):
    """Dominant material of a 32x32 cell by median HSV."""
    px = cell.reshape(-1, 3).astype(float) / 255
    mx, mn = px.max(1), px.min(1)
    d = mx - mn
    v = mx
    s = np.where(mx > 0, d / np.maximum(mx, 1e-9), 0)
    r, g, b = px[:, 0], px[:, 1], px[:, 2]
    m = d > 1e-6
    h = np.where(mx == r, ((g - b) / np.maximum(d, 1e-9)) % 6,
                 np.where(mx == g, (b - r) / np.maximum(d, 1e-9) + 2,
                          (r - g) / np.maximum(d, 1e-9) + 4)) * 60
    hm, sm, vm = np.median(h), np.median(s), np.median(v)
    if sm < 0.18 or vm < 0.14:
        return 'pocket'                     # crushed/near-black -> shade tile
    if 115 <= hm < 195 and vm > 0.38:
        return 'water'                      # bright teal only — dark canopy -> pocket
    if 8 <= hm < 55:
        return 'dirt'                       # tan plaza/road
    if vm <= 0.62:
        return 'pocket'
    return 'sunpool' if vm > 0.82 else 'mid'


def build(img):
    H, W = img.shape[:2]
    ch, cw = H // T, W // T
    zone = np.empty((ch, cw), object)
    for y in range(ch):
        for x in range(cw):
            zone[y, x] = classify(img[y * T:(y + 1) * T, x * T:(x + 1) * T])
    # majority damping: a cell surrounded on all 4 sides joins the crowd
    for _ in range(2):
        z2 = zone.copy()
        for y in range(1, ch - 1):
            for x in range(1, cw - 1):
                nb = [zone[y - 1, x], zone[y + 1, x], zone[y, x - 1], zone[y, x + 1]]
                if all(n == nb[0] for n in nb) and zone[y, x] != nb[0]:
                    z2[y, x] = nb[0]
        zone = z2
    # grass cells touching water read as the near-shore 'lit' band
    grass = {'sunpool', 'mid'}
    for y in range(ch):
        for x in range(cw):
            if zone[y, x] in grass:
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < ch and 0 <= xx < cw and zone[yy, xx] == 'water':
                        zone[y, x] = 'lit'
    return zone


def render(zone, tiles, out):
    ch, cw = zone.shape
    img = np.zeros((ch * T, cw * T, 3), np.uint8)
    for y in range(ch):
        for x in range(cw):
            img[y * T:(y + 1) * T, x * T:(x + 1) * T] = tiles[zone[y, x]]
    Image.fromarray(img).save(out)
    return img


if __name__ == '__main__':
    tiles = load_tiles()
    img = np.array(Image.open(SRC).convert('RGB'))
    img = img[:img.shape[0] // T * T, :img.shape[1] // T * T]
    zone = build(img)
    for row in zone:
        print(' '.join(str(r)[0].upper() for r in row))
    render(zone, tiles, OUT)
    print('saved', OUT)
