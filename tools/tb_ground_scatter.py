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

# family pools: (filename, weight) — wear, not items. The ref's open
# grass is nearly clean: NO leaf litter / flowers / fronds mid-field
# (those read as noise); richness comes from the painted mottle alone.
POOLS = {
    "G": [("tuft_grass_a.png", 6), ("tuft_grass_b.png", 6), ("tuft_grass_c.png", 6),
          ("tuft_grass_dry.png", 3), ("decal_sprout.png", 2)],
    "D": [("decal_dirt_mound.png", 3), ("decal_soil_mound.png", 2),
          ("decal_soil_patch.png", 2), ("decal_pebbles.png", 3),
          ("decal_pebbles_moss.png", 1), ("decal_twig.png", 2),
          ("decal_pinecones.png", 1), ("decal_stick_mossy.png", 1),
          ("decal_stone_moss.png", 1)],
    "W": [("decal_duckweed.png", 4), ("decal_lily_pad.png", 2)],
}
# pond-rim stones: flat river rocks baked along the G<->W border —
# the ref rims every water edge with chunky painted stones
RIM = [("step_stone_a.png", 3), ("step_stone_b.png", 3),
       ("step_stone_c.png", 2), ("decal_pebbles.png", 2),
       ("decal_pebbles_moss.png", 1), ("decal_stone_moss.png", 1)]
TILE = 32
MIN_DIST = 10          # px inside a patch — tight enough to read as one mass
PATCH_R = 26           # patch radius
PATCHES = 4            # localized wear patches — sparse; ref grass is
                       # clean, wear lives in the mottle + the pond rim


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
    placed = {"G": 0, "D": 0, "W": 0, "rim": 0}

    # --- mottle pre-pass: chunky warm/cool blotches on G cells so the
    # grass has painterly wear like the ref, not a flat fill. 8px cells,
    # small hsv deltas — banding stays in pixel grammar.
    arr = np.asarray(base).astype(np.float32)
    cell = 8
    noise = rng.random((H // cell + 1, W // cell + 1))
    for gy in range(noise.shape[0] - 1):
        for gx in range(noise.shape[1] - 1):
            if family_at(gx * cell + 4, gy * cell + 4) != "G":
                continue
            n = noise[gy, gx]
            if n < 0.30:      # warm sunny blotch
                dr, dg, db = 10.0, 8.0, -6.0
            elif n > 0.78:    # cool shade blotch
                dr, dg, db = -10.0, -4.0, 8.0
            else:
                continue
            y0, y1 = gy * cell, gy * cell + cell
            x0, x1 = gx * cell, gx * cell + cell
            arr[y0:y1, x0:x1, 0] += dr
            arr[y0:y1, x0:x1, 1] += dg
            arr[y0:y1, x0:x1, 2] += db
    base = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))

    # --- rim pass: a PACKED band of chunky stones along every grass|water
    # edge. The ref rims water with overlapping rocks that read as
    # masonry, not spaced pebbles — stones sit ON the boundary every
    # ~8px and may overlap. Own spacing set (7px) so packed-but-not-
    # piled. Corner cells collect all water edges (no break).
    rim_edges = []
    for r in range(rows):
        for c in range(cols):
            if mask[r][c] not in "GD":
                continue
            for dr, dc in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nr, nc = r + dr, c + dc
                if 0 <= nr < rows and 0 <= nc < cols and mask[nr][nc] == "W":
                    rim_edges.append((c * TILE, r * TILE, dc, dr))
    rim_pts = []
    for bx, by, dc, dr in rim_edges:
        if dc != 0:  # vertical shared edge, stones march along y
            ex = bx + (0 if dc < 0 else TILE)
            pts = [(ex, by + t) for t in range(3, TILE, 8)]
        else:        # horizontal shared edge, stones march along x
            ey = by + (0 if dr < 0 else TILE)
            pts = [(bx + t, ey) for t in range(3, TILE, 8)]
        for x, y in pts:
            x += int(rng.integers(-3, 4))
            y += int(rng.integers(-3, 4))
            x = max(8, min(W - 8, x)); y = max(8, min(H - 8, y))
            if any((x - px) ** 2 + (y - py) ** 2 < 49 for px, py in rim_pts):
                continue                       # 7px — packed, not piled
            if box_hits_keepout(x, y, 18, 10):
                continue
            rim_pts.append((x, y))
            d = load_decal(pick(RIM, rng), rng.uniform(1.0, 1.35))
            layer.paste(d, (x - d.width // 2, y - d.height // 2), d)
            placed["rim"] += 1

    # --- patch pass: a few homogeneous wear patches, not confetti ---
    centres = []
    tries = 0
    while len(centres) < PATCHES and tries < 400:
        tries += 1
        cx = int(rng.integers(24, W - 24))
        cy = int(rng.integers(24, H - 24))
        fam = family_at(cx, cy)
        if fam not in POOLS:
            continue
        if any((cx - px) ** 2 + (cy - py) ** 2 < 90 ** 2 for px, py, _ in centres):
            continue
        centres.append((cx, cy, fam))

    for cx, cy, fam in centres:
        pool = POOLS[fam]
        hero = pick(pool, rng)          # one dominant kind per patch —
                                        # wear reads as a coherent mass
        n = int(rng.integers(4, 8))
        for _ in range(n):
            x = int(cx + (rng.random() + rng.random() - 1) * PATCH_R)
            y = int(cy + (rng.random() + rng.random() - 1) * PATCH_R)
            if not (8 < x < W - 8 and 8 < y < H - 8):
                continue
            if family_at(x, y) != fam or too_close(x, y):
                continue
            name = hero if rng.random() < 0.7 else pick(pool, rng)
            d = load_decal(name, rng.uniform(0.85, 1.2))
            if box_hits_keepout(x, y, d.width, d.height):
                continue
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
          f"(G:{placed['G']} D:{placed['D']} W:{placed['W']} rim:{placed['rim']}) "
          f"seed={seed} -> {outp}")


if __name__ == "__main__":
    main()
