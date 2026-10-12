#!/usr/bin/env python3
"""Palette lock (GDD §16.2/§28): reduce a batch of sprites to one shared
ramp. Two modes:

  --ramp PATH   remap onto the flat "ramp" list of an existing palette
                JSON (e.g. cleanup/site_palette.json); writes no palette
                files.
  (default)     median-cut on the pooled opaque-pixel histogram ->
                weighted ramp, remap every sprite to its nearest ramp
                color (redmean distance). Writes cleanup/auto_palette.*
                or cleanup/batchN_palette.* with --batch — never
                site_palette.* (that file is hand-authored).

Usage:
    python tools/palette_lock.py [--batch 0] [--colors 32] [--ramp P.json]
                                 [files...]
    python tools/palette_lock.py --swatch cleanup/site_palette.json
                                 # one row per named ramp -> .png sibling
    --batch N   pull files of that batch from assets_src/manifest.json
    files...    explicit PNG paths (may be combined with --batch)
Remaps each sprite in place (gen/ is the canonical location); the first
in-place overwrite of a file copies the original to assets_src/raw/.
Only fully opaque pixels are remapped — semi-transparent overlay pixels
(contact shadows) are left untouched.
Stdlib only (tools/png.py).
"""
import argparse, json, math, os, shutil, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import png as pngmod

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "assets_src", "manifest.json")
OUT = os.path.join(ROOT, "assets_src", "cleanup")
RAW = os.path.join(ROOT, "assets_src", "raw")


def hex2rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def load_ramp(path):
    """Flat ramp list [(r,g,b),...] from a palette JSON — either a dict
    with a "ramp" key of #rrggbb strings, or a bare list of them."""
    d = json.load(open(path, encoding="utf-8"))
    cols = d["ramp"] if isinstance(d, dict) else d
    return [hex2rgb(c) for c in cols]


def backup_raw(p):
    """First in-place overwrite keeps the original in assets_src/raw/."""
    dst = os.path.join(RAW, os.path.basename(p))
    if not os.path.exists(dst):
        os.makedirs(RAW, exist_ok=True)
        shutil.copy2(p, dst)


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
            if row[x * 4 + 3] != 255:      # keep semi-transparent overlays
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


def named_swatch(ramps, cell=8, pad=2):
    """One row per named ramp (dark -> light)."""
    cols = max(len(r) for r in ramps.values())
    w, h = cols * cell, len(ramps) * (cell + pad) - pad
    rows = [bytearray(w * 4) for _ in range(h)]
    for ri, (name, ramp) in enumerate(ramps.items()):
        for i, hx in enumerate(ramp):
            c = hex2rgb(hx)
            for y in range(cell):
                for x in range(cell):
                    o = (i * cell + x) * 4
                    rows[ri * (cell + pad) + y][o:o + 4] = (*c, 255)
    return w, h, rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    ap.add_argument("--batch", type=int, help="files of this manifest batch")
    ap.add_argument("--colors", type=int, default=32)
    ap.add_argument("--ramp", help="palette JSON with a flat 'ramp' list; "
                    "remap onto it, write no palette files")
    ap.add_argument("--swatch", help="palette JSON with named 'ramps'; "
                    "write a one-row-per-ramp swatch PNG next to it")
    a = ap.parse_args()

    if a.swatch:
        d = json.load(open(a.swatch, encoding="utf-8"))
        w, h, rows = named_swatch(d["ramps"])
        out = os.path.splitext(a.swatch)[0] + ".png"
        pngmod.write(out, w, h, rows)
        print("->", os.path.relpath(out, ROOT))
        return

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
    if a.ramp:
        ramp = load_ramp(a.ramp)
        print(f"ramp: {len(ramp)} colors <- {a.ramp}")
    else:
        ramp = sort_ramp(median_cut(hist, a.colors))
        print(f"ramp: {len(ramp)} colors (median-cut)")

    coverage, far_tot = set(), 0
    for p, w, h, rows in images:
        backup_raw(p)
        uniq, used, far = remap(rows, w, ramp)
        coverage |= used
        far_tot += far
        pngmod.write(p, w, h, rows)          # lock in place — gen/ is canonical
        print(f"  {os.path.basename(p):28s} {uniq:4d} uniq -> "
              f"{len(used):2d} ramp colors, {far} far-mapped")

    if a.ramp:
        print(f"coverage: {len(coverage)}/{len(ramp)} ramp colors used, "
              f"{far_tot} far-mapped px")
        return

    os.makedirs(OUT, exist_ok=True)
    name = f"batch{a.batch}_palette" if a.batch is not None else "auto_palette"
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
