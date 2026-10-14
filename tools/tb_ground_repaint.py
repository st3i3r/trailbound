#!/usr/bin/env python3
"""Repaint the site ground as Eastward-grade painted art via PixelLab
inpaint, tiled into <=256px regions (Tier-1 cap) that overlap 64px so
each tile blends into its already-painted neighbor.

Paint order: left->right, top->bottom; each tile is cropped from the
CURRENT composite so AI always sees painted context at shared edges.
At composite time the tile's LEFT/TOP edges get a 24px feather toward
the neighbor. Prompts are per-tile zone descriptions read from the mask.

  python tools/tb_ground_repaint.py [out.png]
"""
import base64, io, json, subprocess, sys, time
import numpy as np
from PIL import Image

BASE = "game/assets/pinewatch/terrain/ground_painted.png"
MASKF = "assets_src/stage/pinewatch_mask.txt"
OUT = sys.argv[1] if len(sys.argv) > 1 else "assets_src/stage/ground_ai.png"
CLI = ["python", "tools/pixellab_mcp.py"]
TILE = 32
W, H = 640, 384
OVL = 64                      # tile overlap
COLS = [(0, 256), (192, 448), (384, 640)]
ROWS = [(0, 256), (128, 384)]

ZONE_DESC = {
    "G": "sunlit yellow-green grass field with soft painterly sun pools",
    "D": "worn dry grass — same yellow-green family as the lawn, slightly lighter and drier, NOT brown or orange sand",
    "W": "flat calm teal-green pond water with a packed band of chunky rounded grey-blue rim stones hugging the waterline and a thin darker-olive grass ring just outside the rocks",
}


def tile_desc(x0, y0, x1, y1, mask):
    hits = []
    for r, row in enumerate(mask):
        for c, ch in enumerate(row):
            cx, cy = c * TILE, r * TILE
            if cx >= x0 - TILE and cx < x1 and cy >= y0 - TILE and cy < y1 \
                    and ch not in hits:
                hits.append(ch)
    order = [ch for ch in "WDG" if ch in hits] or ["G"]
    body = "; ".join(f"{ZONE_DESC[ch]} ({'majority' if i == len(order)-1 else 'a region'})"
                     for i, ch in enumerate(reversed(order)))
    return ("Repaint this top-down 2D pixel-art game ground region in "
            "hand-painted Eastward style, preserving the existing zone "
            f"layout and palette exactly. Contains: {body}. Painted "
            "texture, soft organic washes, no objects, no characters, "
            "no outlines.")


def call(args, poll=True):
    cmd = CLI + [args[0], json.dumps(args[1])]
    if poll:
        cmd += ["--poll", "get_image", "job_id"]
    out = subprocess.run(cmd, capture_output=True, text=True)
    txt = out.stdout + out.stderr
    if "download" in txt or '"download' in txt:
        import re
        m = re.search(r'"(https://api\.pixellab\.ai/mcp/images/[^"]+)"', txt)
        if not m:
            m = re.search(r'download: (https://\S+)', txt)
        return m.group(1) if m else None
    return None


def upload(img):
    buf = io.BytesIO()
    img.save(buf, "PNG")
    up = subprocess.run(CLI + ["get_upload_url", "{}"], capture_output=True,
                        text=True).stdout
    import re
    url = re.search(r'(https://api\.pixellab\.ai/v2/uploads/\S+)', up).group(1)
    r = subprocess.run(["curl", "-sS", "-F", "file=@-;filename=tile.png", url],
                       input=buf.getvalue(), capture_output=True)
    ref = json.loads(r.stdout.decode())["ref"]
    return ref


def main():
    mask = [l.rstrip("\n") for l in open(MASKF) if l.strip()]
    work = Image.open(BASE).convert("RGB")
    comp = work.copy()
    FEATHER = 24

    import os
    for ry, (y0, y1) in enumerate(ROWS):
        for rx, (x0, x1) in enumerate(COLS):
            ck = f"assets_src/stage/_ground_ai_r{ry}c{rx}.png"
            if os.path.exists(ck):
                comp = Image.open(ck).convert("RGB")   # resume point
                print(f"tile r{ry}c{rx}: cached")
                continue
            tile = comp.crop((x0, y0, x1, y1))
            ref = upload(tile)
            print(f"tile r{ry}c{rx} ({x0},{y0},{x1-x0}x{y1-y0}): {tile_desc(x0, y0, x1, y1, mask)[:80]}...")
            dl = call(["inpaint_image", {
                "image_url": ref,
                "description": tile_desc(x0, y0, x1, y1, mask),
                "mask_x": 0, "mask_y": 0,
                "mask_width": x1 - x0, "mask_height": y1 - y0}])
            if not dl:
                print("  FAILED, keeping base")
                continue
            subprocess.run(CLI + ["--get", dl, "assets_src/stage/_tile_tmp.png"],
                           check=True)
            art = Image.open("assets_src/stage/_tile_tmp.png")
            art.load()                               # force decode now —
                                                     # partial files pass open()
            if art.size != (x1 - x0, y1 - y0):
                print(f"  bad tile size {art.size}, keeping base")
                continue
            art = art.convert("RGB")
            # feather mask: full inside, 0 at edges that touch painted
            # neighbours (left edge when rx>0, top edge when ry>0)
            tw, th = art.size
            al = np.full((th, tw), 255, np.uint8)
            if rx > 0:
                ramp = np.clip(np.arange(tw) / FEATHER * 255, 0, 255)
                al = np.minimum(al, ramp[None, :])
            if ry > 0:
                ramp = np.clip(np.arange(th) / FEATHER * 255, 0, 255)
                al = np.minimum(al, ramp[:, None])
            comp.paste(art, (x0, y0), Image.fromarray(al.astype(np.uint8)))
            comp.save(f"assets_src/stage/_ground_ai_r{ry}c{rx}.png")
            print("  painted + composited")
    comp.save(OUT)
    print("done ->", OUT)


if __name__ == "__main__":
    main()
