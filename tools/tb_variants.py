#!/usr/bin/env python3
"""Derive macro ground-variety grass tiles from the graded B5 grass fill —
HSV ops only, no generation (the tile stays a calm wash, just re-lit).

Source: the all-upper wang tile (wang_15, bounding_box 0,96,32,32 — the
same cell the engine uses as UUUU) of the already-graded
terrain_grass_water_pro_0.png, so variants sit on top of the canonical
pinewatch grade instead of fighting it.

  sunlit  hue -8, sat x1.05, val x1.10   warm bright -> sun pool
  mossy   hue +10, sat x0.95, val x0.86  cool dark   -> tree shadow
  dry     hue -18, sat x0.85, val x1.05  ochre pale  -> worn/dry grass

Writes grass_variant_<name>.png (32x32) to all three pipeline dirs:
  assets_src/out/terrain, game/assets/pinewatch/terrain,
  assets_src/staging/pinewatch/terrain
Then regenerate the tileset:  python tools/make_tileset.py
"""
import os, sys, colorsys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import png

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "game", "assets", "pinewatch", "terrain",
                   "terrain_grass_water_pro_0.png")
BOX = (0, 96, 32, 32)                    # wang_15 all-upper grass fill
DIRS = [os.path.join(ROOT, "assets_src", "out", "terrain"),
        os.path.join(ROOT, "game", "assets", "pinewatch", "terrain"),
        os.path.join(ROOT, "assets_src", "staging", "pinewatch",
                   "terrain")]

VARIANTS = {
    "sunlit": {"dh": -8.0,  "s": 1.05, "v": 1.10},
    "mossy":  {"dh": +10.0, "s": 0.95, "v": 0.86},
    "dry":    {"dh": -18.0, "s": 0.85, "v": 1.05},
}


def shift_px(r, g, b, rule):
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    h = (h * 360.0 + rule["dh"]) % 360.0
    s = min(1.0, max(0.0, s * rule["s"]))
    v = min(1.0, max(0.0, v * rule["v"]))
    r2, g2, b2 = colorsys.hsv_to_rgb(h / 360.0, s, v)
    return int(round(r2 * 255)), int(round(g2 * 255)), \
        int(round(b2 * 255))


def main():
    w, h, rows = png.read(SRC)
    x0, y0, tw, th = BOX
    base = [bytearray(rows[y0 + y][x0 * 4:(x0 + tw) * 4])
            for y in range(th)]
    avg = [sum(base[y][x * 4 + c] for y in range(th) for x in range(tw))
           // (tw * th) for c in range(3)]
    print("base tile %dx%d @%s avg rgb %s" % (tw, th, BOX, tuple(avg)))
    for name, rule in VARIANTS.items():
        out = [bytearray(r) for r in base]
        for y in range(th):
            row = out[y]
            for x in range(tw):
                i = x * 4
                if row[i + 3] < 128:
                    continue
                row[i], row[i + 1], row[i + 2] = shift_px(
                    row[i], row[i + 1], row[i + 2], rule)
        va = [sum(out[y][x * 4 + c] for y in range(th) for x in range(tw))
              // (tw * th) for c in range(3)]
        for d in DIRS:
            os.makedirs(d, exist_ok=True)
            p = os.path.join(d, "grass_variant_%s.png" % name)
            png.write(p, tw, th, out)
        print("variant %-6s %s  avg rgb %s -> %s x%d dirs"
              % (name, rule, tuple(avg), tuple(va), len(DIRS)))


if __name__ == "__main__":
    main()
