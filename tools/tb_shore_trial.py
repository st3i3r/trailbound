#!/usr/bin/env python3
"""Trial: composite PixelLab-painted shore art onto the baked ground.

Extracts the rock-rim strip + shore grass from pond_shore.png
(palette-corrected toward the ref band) and stamps them along every
grass|water edge in the pinewatch mask. Writes a trial PNG for review —
does NOT touch the production pipeline.

  python tools/tb_shore_trial.py
"""
import numpy as np
from PIL import Image

SW_SHORE = "assets_src/pl_swatches/pond_shore.png"
SW_GRASS = "assets_src/pl_swatches/grass_field.png"
BASE = "assets_src/stage/ground_dressed.png"
MASKF = "assets_src/stage/pinewatch_mask.txt"
OUT = "assets_src/cleanup/_trial_shore.png"
TILE = 32


def hsv_arr(px):
    px = px / 255.0
    r, g, b = px[..., 0], px[..., 1], px[..., 2]
    mx = px.max(-1); mn = px.min(-1); d = mx - mn
    h = np.zeros_like(mx); nz = d > 1e-6
    rm = (mx == r) & nz; gm = (mx == g) & ~rm & nz; bm = nz & ~rm & ~gm
    h[rm] = ((g - b)[rm] / d[rm]) % 6
    h[gm] = (b - r)[gm] / d[gm] + 2
    h[bm] = (r - g)[bm] / d[bm] + 4
    return h / 6 % 1, np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0), mx


def rgb_arr(h, s, v):
    i = (np.floor(h * 6).astype(int)) % 6
    f = h * 6 - np.floor(h * 6)
    p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    r = np.choose(i, [v, q, p, p, t, v])
    g = np.choose(i, [t, v, v, q, p, p])
    b = np.choose(i, [p, p, t, v, v, q])
    return np.stack([r, g, b], -1) * 255


def lift(img, v_target=0.85, v_amt=0.85, h_to=0.227, h_amt=0.5):
    """Pull the swatch's grass-band pixels toward the ref key."""
    a = np.asarray(img.convert("RGB")).astype(float)
    h, s, v = hsv_arr(a)
    green = (h > 0.10) & (h < 0.40) & (s > 0.20)
    nv = v + (v_target - v) * v_amt
    nh = h + (h_to - h) * h_amt
    h = np.where(green, nh, h); v = np.where(green, nv, v)
    return Image.fromarray(rgb_arr(h, s, v).astype(np.uint8))


def main():
    rng = np.random.default_rng(7)
    mask = [l.rstrip("\n") for l in open(MASKF) if l.strip()]
    rows, cols = len(mask), len(mask[0])

    shore = lift(Image.open(SW_SHORE))
    grass = lift(Image.open(SW_GRASS))
    base = Image.open(BASE).convert("RGB")
    W, H = base.size
    out = base.copy()

    # --- 1. grass texture swap in the shore ring (dist-to-water < 48) ---
    wt = [(c * TILE + TILE / 2, r * TILE + TILE / 2)
          for r, row in enumerate(mask)
          for c, ch in enumerate(row) if ch == "W"]
    arr = np.asarray(out).astype(float)
    yy, xx = np.mgrid[0:H, 0:W]
    dist = np.minimum.reduce(
        [(xx - wx) ** 2 + (yy - wy) ** 2 for wx, wy in wt]) ** 0.5
    ring = (dist < 48)
    # only swap pixels that are grass in the mask
    gm = np.zeros((H, W), bool)
    for r in range(rows):
        for c in range(cols):
            if mask[r][c] == "G":
                gm[r * TILE:(r + 1) * TILE, c * TILE:(c + 1) * TILE] = True
    ring &= gm
    g_a = np.asarray(grass).astype(float)
    ox, oy = int(rng.integers(0, 128)), int(rng.integers(0, 128))
    sw = np.roll(np.roll(g_a, ox, 1), oy, 0)          # wrap-around offset
    sw = np.tile(sw, (H // 256 + 2, W // 256 + 2, 1))[:H, :W]
    fade = np.clip((48 - dist) / 20.0, 0, 1)[..., None]  # feathered seam
    arr = np.where(ring[..., None], arr * (1 - fade) + sw * fade, arr)
    out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))

    # --- 2. rim tiles: cut the swatch's rock strip, keep ONLY the
    # rock pixels (segmented grey-blue) so no water/grass squares stamp
    rim_strip = shore.crop((78, 0, 138, 256))          # 60x256 rim column
    rim_tiles = []
    for i in range(0, 224, TILE):
        seg = rim_strip.crop((0, i, 60, i + TILE)).convert("RGB")
        a = np.asarray(seg).astype(float)
        h, s, v = hsv_arr(a)
        rock = ((h > 0.50) & (h < 0.75) & (v > 0.30) & (v < 0.85)) | \
               ((s < 0.30) & (v > 0.35) & (v < 0.80))
        alpha = np.asarray(seg.convert("RGBA"))[..., 3]
        alpha = np.where(rock, alpha, 0).astype(np.uint8)
        seg2 = seg.convert("RGBA")
        seg2.putalpha(Image.fromarray(alpha))
        rim_tiles.append(seg2)

    for r in range(rows):
        for c in range(cols):
            if mask[r][c] not in "GD":
                continue
            bx, by = c * TILE, r * TILE
            for dr, dc in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nr, nc = r + dr, c + dc
                if not (0 <= nr < rows and 0 <= nc < cols) or mask[nr][nc] != "W":
                    continue
                seg = rim_tiles[int(rng.integers(0, len(rim_tiles)))]
                # rim strip faces water on its LEFT; rotate so the rock
                # pixels straddle the shared edge
                if dc == -1:   # water west
                    tile_im, px0, py0 = seg, bx - 22, by
                elif dc == 1:  # water east
                    tile_im = seg.transpose(Image.FLIP_LEFT_RIGHT)
                    px0, py0 = bx + TILE - 38, by
                elif dr == -1: # water north
                    tile_im = seg.rotate(-90, expand=True)
                    px0, py0 = bx, by - 22
                else:          # water south
                    tile_im = seg.rotate(90, expand=True)
                    px0, py0 = bx, by + TILE - 38
                out.paste(tile_im, (px0, py0), tile_im)

    out.save(OUT)
    print("trial ->", OUT)


if __name__ == "__main__":
    main()
