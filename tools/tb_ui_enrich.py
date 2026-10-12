#!/usr/bin/env python3
"""UI enrichment (Phase 0.4) — deterministic craft pass on the ui pieces.

Lifts the flat generated parchment/chrome toward the style_lock UI rubric
("dense content, nested borders, paper texture, seals"):

  1. +1px inner border line — a darker warm tone laid just inside the
     detected outline ring (nested-border read).
  2. Soft inner shadow strips — a light catch a few px inside the top
     interior edge, a darker strip inside the bottom edge (shallow
     depth — the panel reads as a raised object).
  3. Sparse paper-fiber specks — ~1.5% of light interior px get a very
     low-alpha warm fleck (parchment grain).
  4. Asymmetric corner wear — 1-2px L-nibbles on 1-2 corners, picked
     deterministically per piece name.
  5. Deepened drop shadows under raised elements (buttons, medallions,
     seal) — existing dark/soft edge px pulled darker + slightly
     stronger alpha at the bottom-right.

Nine-slice safety: strips/specks only touch the slice-INTERIOR rect
(l..w-r, t..h-b from ui_atlas_meta.json); the border region inside the
margins receives nothing but the inner line.  Corners nibble at most
2px — insets stay valid.

Runs over assets_src/out/ui/pieces/ and game/assets/pinewatch/ui/
(byte-identical output both sides) and re-packs ui_atlas.png in out/
+ game/ at the recorded meta positions (piece sizes are unchanged).

Note: pieces are downstream artifacts of tools/tb_ui_kit.py — re-running
that kit regenerates pristine pieces and drops this pass.  Staging
sheets (U1-U5) are the untouched gen source and are NOT edited.

Usage: python tools/tb_ui_enrich.py [--report]
"""
import os, sys, json, zlib
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets_src", "out", "ui")
GAME = os.path.join(ROOT, "game", "assets", "pinewatch", "ui")
PIECES = os.path.join(OUT, "pieces")
META = json.load(open(os.path.join(OUT, "ui_atlas_meta.json")))
REVIEW = os.path.join(os.environ.get("TEMP", ROOT), "tb_review")

# raised elements whose drop shadow gets deepened
RAISED = {"btn_green", "btn_gold", "btn_disabled", "btn_round_gold",
          "medallion_wood", "hud_medallion", "hud_medallion_empty",
          "seal_red"}
WARM_DARK = np.array((64, 40, 22))          # inner line / fiber tones
FIBER = np.array((110, 80, 50))


def depth_map(alpha):
    """Per-pixel depth = # of 8-erosions survived (same as tb_ui_kit)."""
    m = alpha > 0
    depth = np.zeros(alpha.shape, np.int16)
    cur = m.copy()
    d = 0
    while cur.any():
        d += 1
        depth[cur] = d
        e = cur.copy()
        e[1:, :] &= cur[:-1, :]; e[:-1, :] &= cur[1:, :]
        e[:, 1:] &= cur[:, :-1]; e[:, :-1] &= cur[:, 1:]
        e[1:, 1:] &= cur[:-1, :-1]; e[:-1, :-1] &= cur[1:, 1:]
        e[1:, :-1] &= cur[:-1, 1:]; e[:-1, 1:] &= cur[1:, :-1]
        e[:-1, 1:] &= cur[1:, :-1]; e[:-1, :-1] &= cur[1:, 1:]
        cur = e
        if d > 200:
            break
    return depth


def is_lightish(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (r + g + b > 330) & ~((r > 140) & (g < 110) & (b < 90))


def enrich(arr, name):
    """arr: HxWx4 float 0..255 — returns enriched array + stats."""
    a = arr[..., 3]
    H, W = a.shape
    depth = depth_map(a)
    rgb = arr[..., :3].copy()
    v = (rgb @ np.array([0.299, 0.587, 0.114])) / 255.0
    yy, xx = np.mgrid[0:H, 0:W]
    st = {"line": 0, "strip": 0, "speck": 0, "wear": 0, "shadow": 0}

    # -- outline thickness: deepest ring still >50% dark --------------
    ot = 1
    for d in range(1, 7):
        ring = (depth == d) & (a > 0)
        if not ring.any():
            break
        if (v[ring] < 0.42).mean() > 0.5:
            ot = d
        else:
            break

    # -- 1. +1px inner border line (darker warm tone) ------------------
    line = (depth == ot + 1) & (a > 0)
    k = 0.60
    rgb[line] = rgb[line] * (1 - k) + WARM_DARK * k
    st["line"] = int(line.sum())

    # -- interior: inside slice margins when nine-sliced ---------------
    ins = META.get(name, {}).get("nine_slice")
    if ins:
        inter = (xx >= ins["l"]) & (xx < W - ins["r"]) & \
                (yy >= ins["t"]) & (yy < H - ins["b"]) & (depth > ot + 1)
    else:
        inter = (depth > ot + 1) & (a > 0)
    if not inter.any():
        out = arr.copy(); out[..., :3] = rgb
        return out, st
    iy0, iy1 = yy[inter].min(), yy[inter].max()

    # -- 2. soft inner shadow strips (top light / bottom dark) ---------
    dt = yy - iy0                                  # px below inner top
    db = iy1 - yy                                  # px above inner bot
    top_w = np.clip((3.5 - dt) / 3.5, 0, 1) * inter
    bot_w = np.clip((3.5 - db) / 3.5, 0, 1) * inter
    rgb = rgb + (255 - rgb) * (top_w * 0.07)[..., None]
    rgb = rgb * (1 - (bot_w * 0.09))[..., None]
    st["strip"] = int((top_w + bot_w > 0).sum())

    # -- 3. paper-fiber specks (~1.5% of light interior px) ------------
    rng = np.random.default_rng(zlib.crc32(name.encode()) & 0xffffffff)
    lite = inter & is_lightish(rgb) & (a > 200)
    pick = lite & (rng.random((H, W)) < 0.015)
    rgb[pick] = rgb[pick] * 0.78 + FIBER * 0.22
    st["speck"] = int(pick.sum())

    # -- 4. asymmetric corner wear -------------------------------------
    hh = zlib.crc32(("wear" + name).encode())
    rng2 = np.random.default_rng(hh & 0xffffffff)
    order = list(rng2.permutation(4))
    n_wear = 1 + hh % 2                            # 1-2 corners
    ys0, xs0 = np.where(a > 0)
    bx0, bx1, by0, by1 = xs0.min(), xs0.max(), ys0.min(), ys0.max()
    corners = [(bx0, by0), (bx1, by0), (bx0, by1), (bx1, by1)]
    done = 0
    a = a.copy()
    for ci in order:
        if done >= n_wear:
            break
        cx, cy = corners[ci]
        sx = 1 if cx == bx0 else -1           # inward direction
        sy = 1 if cy == by0 else -1
        # walk the corner diagonal to the first SOLID px — rounded
        # corners mean the bbox corner itself is usually air
        px_ = None
        for k in range(8):
            if a[cy + sy * k, cx + sx * k] > 200:
                px_ = (cx + sx * k, cy + sy * k)
                break
        if px_ is None:
            continue
        nx_, ny_ = px_
        # 2px step-notch cut along the two edge directions
        for qx, qy in ((0, 0), (-sx, 0), (0, -sy), (-sx, -sy)):
            if 0 <= ny_ + qy < H and 0 <= nx_ + qx < W:
                a[ny_ + qy, nx_ + qx] = 0
        done += 1
    st["wear"] = done

    # -- 5. deepen drop shadows under raised elements ------------------
    if name in RAISED:
        ring = (depth <= 3) & (a > 0)
        zone = (yy >= H * 0.55) | (xx >= W * 0.62)
        m = ring & zone & (v < 0.65)
        rgb[m] *= 0.82
        a = np.where(m, np.clip(a * 1.10, 0, 255), a)
        st["shadow"] = int(m.sum())

    out = arr.copy()
    out[..., :3] = np.clip(rgb, 0, 255)
    out[..., 3] = a
    return out, st


def review_sheet(before_after):
    os.makedirs(REVIEW, exist_ok=True)
    Z = 4
    rows = []
    for name, pair in before_after:
        z = [Image.fromarray(p.astype(np.uint8)) for p in pair]
        z = [t.resize((t.width * Z, t.height * Z), Image.NEAREST)
             for t in z]
        rows.append((name, z))
    W_ = max(t.width + t2.width for _, (t, t2) in rows) + 24
    H_ = sum(max(t.height, t2.height) for _, (t, t2) in rows) + 30 * len(rows)
    sheet = Image.new("RGBA", (W_, H_ + 20), (38, 34, 30, 255))
    dr = ImageDraw.Draw(sheet)
    y = 20
    for name, (t, t2) in rows:
        dr.text((8, y - 12), f"{name}  before | after  x{Z}",
                fill=(240, 230, 200))
        sheet.paste(t, (4, y), t)
        sheet.paste(t2, (t.width + 14, y), t2)
        y += max(t.height, t2.height) + 24
    out = os.path.join(REVIEW, "craft_ui.png")
    sheet.save(out)
    print("->", out)


def main():
    names = sorted(f[:-4] for f in os.listdir(PIECES)
                   if f.endswith(".png"))
    review = []
    for name in names:
        p = os.path.join(PIECES, name + ".png")
        before = np.array(Image.open(p).convert("RGBA")).astype(float)
        after, st = enrich(before, name)
        im = Image.fromarray(after.astype(np.uint8))
        im.save(p)
        gp = os.path.join(GAME, name + ".png")
        if os.path.exists(gp):
            im.save(gp)                            # keep copies synced
        print(f"{name:24s} line={st['line']:5d} strip={st['strip']:5d} "
              f"speck={st['speck']:4d} wear={st['wear']} "
              f"shadow={st['shadow']:4d}")
        if name in ("panel_window_flat", "btn_green", "card_guest"):
            review.append((name, (before, after)))

    # ---------------- repack atlas at recorded positions --------------
    for adir in (OUT, GAME):
        ap = os.path.join(adir, "ui_atlas.png")
        if not os.path.exists(ap):
            continue
        atlas = Image.open(ap).convert("RGBA")
        for name in names:
            m = META.get(name)
            if not m:
                continue
            im = Image.open(os.path.join(PIECES, name + ".png")) \
                if adir == OUT else \
                Image.open(os.path.join(GAME, name + ".png"))
            atlas.paste(im, (m["x"], m["y"]))
        atlas.save(ap)
        print("atlas repacked ->", ap)

    review_sheet(review)


if __name__ == "__main__":
    main()
