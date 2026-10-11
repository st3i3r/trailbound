#!/usr/bin/env python3
"""Extract sprites from downloaded OGA sheets -> sprite PNGs + manifest."""
import json, os
from PIL import Image

A = os.path.dirname(os.path.abspath(__file__)) + "/assets"
OUT = A + "/sprites"
os.makedirs(OUT, exist_ok=True)

def alpha_boxes(im, min_area=60, pad=1):
    """Find connected-component bounding boxes of opaque regions."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    boxes = []
    from collections import deque
    for y0 in range(h):
        for x0 in range(w):
            i = y0 * w + x0
            if seen[i] or px[x0, y0][3] < 40:
                continue
            # flood fill
            q = deque([(x0, y0)]); seen[i] = 1
            minx = maxx = x0; miny = maxy = y0
            while q:
                x, y = q.popleft()
                if x < minx: minx = x
                if x > maxx: maxx = x
                if y < miny: miny = y
                if y > maxy: maxy = y
                for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not seen[j] and px[nx, ny][3] >= 40:
                            seen[j] = 1; q.append((nx, ny))
            if (maxx-minx+1) * (maxy-miny+1) >= min_area:
                boxes.append([minx-pad, miny-pad, maxx+pad+1, maxy+pad+1])
    # merge overlapping boxes (sprites split into parts)
    merged = True
    while merged:
        merged = False
        for i in range(len(boxes)):
            for j in range(i+1, len(boxes)):
                a, b = boxes[i], boxes[j]
                if not (a[2] < b[0] or b[2] < a[0] or a[3] < b[1] or b[3] < a[1]):
                    boxes[i] = [min(a[0],b[0]), min(a[1],b[1]), max(a[2],b[2]), max(a[3],b[3])]
                    del boxes[j]; merged = True; break
            if merged: break
    return sorted(boxes, key=lambda b: (b[1], b[0]))

# --- furniture sheet: connected components ---
fw = Image.open(A + "/furnitureandwalls.png").convert("RGBA")
boxes = alpha_boxes(fw, min_area=150)
manifest = {}
for i, b in enumerate(boxes):
    crop = fw.crop(b)
    name = f"fw_{i:02d}_{b[0]}x{b[1]}_{b[2]-b[0]}x{b[3]-b[1]}"
    crop.save(f"{OUT}/{name}.png")
    manifest[name] = b
print(f"furnitureandwalls: {len(boxes)} sprites")

# --- hero sheets: 6 cols x 2 rows of 5x5 sub-sheets; detect cell grid ---
hero = Image.open(A + "/hero.png").convert("RGBA")
W, H = hero.size  # 959 x 496
# sheets are 160px wide (960/6); two rows ~248 tall; cell = 32x32 within 5x5 + margins
# probe: top-left sheet at (0,0): cells at x=1..5*32? Let's just crop each 160x248 block
# and auto-extract the 25 cells by the known 32px grid offset inside.
idx = 0
for sy in range(2):
    for sx in range(6):
        bx, by = sx * 160, sy * 248
        # within each block: 5x5 cells of 32px starting at (0,0)? blocks are 160 wide = 5*32
        for cy in range(5):
            for cx in range(5):
                cell = hero.crop((bx + cx*32, by + cy*32, bx + cx*32 + 32, by + cy*32 + 32))
                # skip fully transparent or mostly-empty cells
                alpha = cell.getchannel("A")
                if sum(1 for v in alpha.getdata() if v > 40) < 30:
                    continue
                cell.save(f"{OUT}/char_{sx}_{sy}_{cx}_{cy}.png")
                idx += 1
print(f"hero cells: {idx}")

# --- plants sheet: connected components ---
pl = Image.open(A + "/plants.png").convert("RGBA")
boxes = alpha_boxes(pl, min_area=200)
for i, b in enumerate(boxes):
    pl.crop(b).save(f"{OUT}/plant_{i:02d}_{b[0]}x{b[1]}_{b[2]-b[0]}x{b[3]-b[1]}.png")
print(f"plants: {len(boxes)} sprites")

# --- interiorTiles zip: extract the useful tiles ---
import zipfile
z = zipfile.ZipFile(A + "/interiorTiles.zip")
z.extractall(OUT + "/interiorTiles")
print("interiorTiles extracted:", len(z.namelist()))
print("done")
