#!/usr/bin/env python3
"""Scatter ground decals onto the painted terrain (family-aware, seeded).

Takes the dressed ground PNG (one sprite, zones painted) + the site zone
mask, and bakes decal sprites into it: grass tufts, flowers, ferns and
mushrooms on grass; mounds, pebbles and twigs on dirt; duckweed and
lily pads on water. Density is graded denser toward frame center
(measured Eastward grammar: detail center-weighted ~+20% vs edges).

Baking is deliberate: ground decals are flat, so they belong in the
painted sprite (zero runtime nodes, zero y-sort issues). Raised props
(bushes, feeders) stay as nodes.

Usage:
  python tools/tb_ground_scatter.py IN.png MASK.txt OUT.png
      [--seed 7] [--count 180] [--keepout x,y,w,h]...
  MASK.txt: rows of G/D/W chars, 20 cols (32px tiles on 640px ground).

Pipeline position: AFTER tools/tb_ground_dress.py, BEFORE the family
regrade (tools/tb_family_regrade.py) so baked decals lift with the
ground family. Output goes to assets_src/; promote via the normal flow.
"""
import sys
import numpy as np
from PIL import Image

A = "game/assets/pinewatch/decals/"

# family pools: (filename, weight)
POOLS = {
    "G": [("tuft_grass_a.png", 5), ("tuft_grass_b.png", 5), ("tuft_grass_c.png", 5),
          ("tuft_grass_dry.png", 2), ("decal_flowers_white.png", 3),
          ("decal_flowers_purple.png", 2), ("decal_dandelion.png", 2),
          ("decal_fern_frond.png", 3), ("decal_fern_leaf.png", 2),
          ("decal_mushroom_brown.png", 1), ("decal_mushroom_orange.png", 1),
          ("decal_berries_red.png", 1), ("decal_strawberry.png", 1),
          ("tuft_moss_patch.png", 2), ("tuft_leaf_litter.png", 2),
          ("decal_leaf_pile.png", 1), ("decal_sprout.png", 2)],
    "D": [("decal_dirt_mound.png", 3), ("decal_soil_mound.png", 2),
          ("decal_soil_patch.png", 2), ("decal_pebbles.png", 3),
          ("decal_pebbles_moss.png", 1), ("decal_twig.png", 2),
          ("decal_pinecones.png", 1), ("decal_stick_mossy.png", 1),
          ("decal_stone_moss.png", 1)],
    "W": [("decal_duckweed.png", 4), ("decal_lily_pad.png", 2)],
}
TILE = 32
MIN_DIST = 18          # px between decal centers — keeps scatter even
                       # (Eastward reads sparse+regular, not clumped)


def load_decal(name, scale):
    im = Image.open(A + name).convert("RGBA")
    if scale != 1.0:
        # NEAREST only — bicubic blurs pixel edges; baked into a sharp
        # painted ground that is mixed pixel grammar.
        im = im.resize((max(1, int(im.width * scale)),
                        max(1, int(im.height * scale))), Image.NEAREST)
    return im


def pick(pool, rng):
    names = [n for n, _ in pool]
    ws = np.array([w for _, w in pool], dtype=float)
    return names[rng.choice(len(names), p=ws / ws.sum())]


def main():
    args = sys.argv[1:]
    if len(args) < 3:
        print(__doc__)
        sys.exit(2)
    inp, maskf, outp = args[0], args[1], args[2]
    seed = 7
    count = 180
    keepouts = []
    i = 3
    while i < len(args):
        if args[i] == "--seed":
            seed = int(args[i + 1]); i += 2
        elif args[i] == "--count":
            count = int(args[i + 1]); i += 2
        elif args[i] == "--keepout":
            keepouts.append(tuple(map(int, args[i + 1].split(",")))); i += 2
        else:
            i += 1
    rng = np.random.default_rng(seed)

    base = Image.open(inp).convert("RGBA")
    W, H = base.size
    mask = [l.rstrip("\n") for l in open(maskf) if l.strip()]
    rows, cols = len(mask), len(mask[0])

    def family_at(x, y):
        c = min(cols - 1, int(x // TILE))
        r = min(rows - 1, int(y // TILE))
        return mask[r][c]

    # keepout test = decal bbox corners, not just the centre point —
    # a 24px sprite whose centre misses a pad can still poke inside.
    def box_hits_keepout(x, y, w, h):
        x0, y0, x1, y1 = x - w // 2, y - h // 2, x + w // 2, y + h // 2
        for kx, ky, kw, kh in keepouts:
            if (x0 < kx + kw and x1 > kx and y0 < ky + kh and y1 > ky):
                return True
        return False

    # density field: gaussian falloff from frame center (measured grammar)
    yy, xx = np.mgrid[0:H, 0:W]
    dens = np.exp(-(((xx - W * 0.5) / (W * 0.42)) ** 2 +
                    ((yy - H * 0.55) / (H * 0.42)) ** 2) / 2)
    dens = 0.45 + 0.55 * dens / dens.max()

    # min-spacing grid — one lookup cell per MIN_DIST block
    spaced = np.zeros((H // MIN_DIST + 2, W // MIN_DIST + 2), dtype=bool)

    def too_close(x, y):
        cx, cy = int(x // MIN_DIST), int(y // MIN_DIST)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if spaced[cy + dy, cx + dx]:
                    return True
        return False

    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    placed = {"G": 0, "D": 0, "W": 0}
    tries = 0
    while sum(placed.values()) < count and tries < count * 20:
        tries += 1
        x = int(rng.integers(16, W - 16))
        y = int(rng.integers(16, H - 16))
        if rng.random() > dens[y, x]:
            continue
        if too_close(x, y):
            continue
        fam = family_at(x, y)
        if fam not in POOLS:
            continue
        d = load_decal(pick(POOLS[fam], rng), rng.uniform(0.85, 1.2))
        if box_hits_keepout(x, y, d.width, d.height):
            continue
        # slight alpha jitter so repeats don't read as stamps
        if rng.random() < 0.3:
            a = np.asarray(d).copy()
            a[..., 3] = (a[..., 3].astype(float) * rng.uniform(0.75, 1.0)).astype(np.uint8)
            d = Image.fromarray(a)
        layer.paste(d, (x - d.width // 2, y - d.height // 2), d)
        spaced[int(y // MIN_DIST), int(x // MIN_DIST)] = True
        placed[fam] += 1

    out = Image.alpha_composite(base, layer).convert("RGB")
    out.save(outp)
    print(f"scattered {sum(placed.values())} decals "
          f"(G:{placed['G']} D:{placed['D']} W:{placed['W']}) "
          f"seed={seed} -> {outp}")


if __name__ == "__main__":
    main()
