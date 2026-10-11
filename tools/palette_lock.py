#!/usr/bin/env python3
"""Palette lock (GDD §16.2/§28): reduce a batch of sprites to one shared
ramp. Median-cut on the pooled opaque-pixel histogram -> weighted ramp,
then remap every sprite to its nearest ramp color (redmean distance).

Usage:
    python tools/palette_lock.py [--batch 0] [--colors 32] [files...]
    --batch N   pull files of that batch from assets_src/manifest.json
    files...    explicit PNG paths (may be combined with --batch)
Remaps each sprite in place (gen/ is the canonical location; originals
live in git history) + writes cleanup/batch0_palette.{png,json}.
Stdlib only (tools/png.py).
"""
import argparse, json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import png as pngmod

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "assets_src", "manifest.json")
OUT = os.path.join(ROOT, "assets_src", "cleanup")


def histogram(paths):
    """Pooled opaque-pixel color histogram: {rgb: count}."""
    hist = {}
    images = []
    for p in paths:
        w, h, rows = pngmod.read(p)
        images.append((p, w, h, rows))
        for row in rows:
            for x in range(w):
                a = row[x * 4 + 3]
                if a >= 128:
                    key = (row[x * 4], row[x * 4 + 1], row[x * 4 + 2])
                    hist[key] = hist.get(key, 0) + 1
    return hist, images


def _score(box):
    """Population-weighted channel range — bigger, wider boxes split first."""
    if len(box) < 2:
        return -1
    pop = sum(c for _, c in box)
    ranges = [max(k[ch] for k, _ in box) - min(k[ch] for k, _ in box)
              for ch in range(3)]
    return pop * max(ranges)


def _split(box):
    ch = max(range(3), key=lambda c:
             max(k[c] for k, _ in box) - min(k[c] for k, _ in box))
    box.sort(key=lambda kv: kv[0][ch])
    half = sum(c for _, c in box) / 2
    acc = i = 0
    while acc < half and i < len(box) - 1:
        acc += box[i][1]
        i += 1
    if i == 0:
        i = 1
    return box[:i], box[i:]


def median_cut(hist, n):
    boxes = [list(hist.items())]
    while len(boxes) < n:
        bi = max(range(len(boxes)), key=lambda i: _score(boxes[i]))
        if _score(boxes[bi]) <= 0:
            break
        a, b = _split(boxes.pop(bi))
        boxes += [a, b] if b else [a]
    ramp = []
    for box in boxes:
        tot = sum(c for _, c in box)
        ramp.append(tuple(round(sum(k[ch] * c for k, c in box) / tot)
                          for ch in range(3)))
    return ramp


def dist2(c, p):
    """Redmean — cheap perceptual-ish RGB distance."""
    rm = (c[0] + p[0]) / 2
    dr, dg, db = c[0] - p[0], c[1] - p[1], c[2] - p[2]
    return (2 + rm / 256) * dr * dr + 4 * dg * dg \
        + (2 + (255 - rm) / 256) * db * db


def nearest(c, ramp):
    return min(range(len(ramp)), key=lambda i: dist2(c, ramp[i]))


def remap(rows, w, ramp):
    cache, used, far = {}, set(), 0
    for row in rows:
        for x in range(w):
            if not row[x * 4 + 3]:
                continue
            c = (row[x * 4], row[x * 4 + 1], row[x * 4 + 2])
            i = cache.get(c)
            if i is None:
                i = nearest(c, ramp)
                cache[c] = i
                if math.sqrt(dist2(c, ramp[i])) > 64:
                    far += 1
            used.add(i)
            row[x * 4:x * 4 + 3] = ramp[i]
    return len(cache), used, far


def sort_ramp(ramp):
    def hsv(c):
        r, g, b = (v / 255 for v in c)
        mx, mn = max(r, g, b), min(r, g, b)
        d = mx - mn
        if d == 0:
            h = 0
        elif mx == r:
            h = ((g - b) / d) % 6
        elif mx == g:
            h = (b - r) / d + 2
        else:
            h = (r - g) / d + 4
        return h * 60, mx
    return sorted(ramp, key=lambda c: (*hsv(c), c))


def swatch(ramp, cell=8):
    cols = len(ramp)
    rows = [bytearray(cols * cell * 4) for _ in range(cell)]
    for i, c in enumerate(ramp):
        for y in range(cell):
            for x in range(cell):
                o = (i * cell + x) * 4
                rows[y][o:o + 4] = (*c, 255)
    return cols * cell, cell, rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    ap.add_argument("--batch", type=int, help="files of this manifest batch")
    ap.add_argument("--colors", type=int, default=32)
    a = ap.parse_args()

    paths = list(a.files)
    if a.batch is not None:
        m = json.load(open(MANIFEST))
        paths += [os.path.join(ROOT, "assets_src", f)
                  for e in m["assets"] if e.get("batch") == a.batch
                  for f in e.get("files", [])]
    elif not a.files:
        m = json.load(open(MANIFEST))
        paths += [os.path.join(ROOT, "assets_src", f)
                  for e in m["assets"] for f in e.get("files", [])]
    paths = [p for p in dict.fromkeys(paths) if os.path.exists(p)]
    if not paths:
        sys.exit("no input files")

    hist, images = histogram(paths)
    print(f"{len(paths)} files, {len(hist)} unique colors pooled")
    ramp = median_cut(hist, a.colors)
    ramp = sort_ramp(ramp)
    print(f"ramp: {len(ramp)} colors")

    os.makedirs(OUT, exist_ok=True)
    coverage, far_tot = set(), 0
    for p, w, h, rows in images:
        uniq, used, far = remap(rows, w, ramp)
        coverage |= used
        far_tot += far
        pngmod.write(p, w, h, rows)          # lock in place — gen/ is canonical
        print(f"  {os.path.basename(p):28s} {uniq:4d} uniq -> "
              f"{len(used):2d} ramp colors, {far} far-mapped")

    name = f"batch{a.batch}_palette" if a.batch is not None else "site_palette"
    w, h, rows = swatch(ramp)
    pngmod.write(os.path.join(OUT, name + ".png"), w, h, rows)
    json.dump({"batch": a.batch if a.batch is not None else "all",
               "colors": a.colors,
               "sources": [os.path.relpath(p, ROOT) for p in paths],
               "ramp": ["#%02x%02x%02x" % c for c in ramp]},
              open(os.path.join(OUT, name + ".json"), "w"), indent=2)
    print(f"coverage: {len(coverage)}/{len(ramp)} ramp colors used, "
          f"{far_tot} far-mapped px")
    print(f"-> {os.path.relpath(OUT, ROOT)}/{name}.*")


if __name__ == "__main__":
    main()
