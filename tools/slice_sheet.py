#!/usr/bin/env python3
"""Slice a sprite-sheet strip into per-frame PNGs, with an alignment
report and optional re-centering onto the §16.2 anchor.

    python tools/slice_sheet.py gen/flame_frames_0.png --cols 4
    python tools/slice_sheet.py sheet.png --cols 8 --rows 2 \
        --out gen/walk --recenter --anchor bottom

The default mode reports each cell's opaque bbox and how far it sits
from the anchor — the jitter check before a strip goes to the game.
--write emits per-frame PNGs; --recenter repacks each frame's content
inside its cell on the anchor (bottom-center default for characters
and props, center for icons/effects).

Stdlib only (tools/png.py does the codec work).
"""
import argparse, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import png


def cell_image(rows, x0, y0, w, h):
    return [bytearray(rows[y][x0 * 4:(x0 + w) * 4]) for y in range(y0, y0 + h)]


def despeckle(cell, w, h):
    """Zero the alpha of every detached component touching a cell border.

    8-connected flood fill on alpha>0. In a strip slice, anything
    disconnected and edge-touching is a neighbor frame's bleed — its
    continuation lives in the adjacent cell. The largest component and
    interior strays (sparks = real detail) are kept. Returns px cleared.
    """
    seen = [[False] * w for _ in range(h)]
    cleared = 0
    comps = []
    for y0 in range(h):
        for x0 in range(w):
            if seen[y0][x0] or not cell[y0][x0 * 4 + 3]:
                continue
            comp, stack = [], [(x0, y0)]
            seen[y0][x0] = True
            while stack:
                x, y = stack.pop()
                comp.append((x, y))
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if (0 <= nx < w and 0 <= ny < h
                                and not seen[ny][nx] and cell[ny][nx * 4 + 3]):
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            comps.append(comp)
    if len(comps) < 2:
        return 0
    biggest = max(len(c) for c in comps)
    for comp in comps:
        if len(comp) == biggest:
            continue
        if any(x in (0, w - 1) or y in (0, h - 1) for x, y in comp):
            for x, y in comp:
                cell[y][x * 4 + 3] = 0
            cleared += len(comp)
    return cleared


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("sheet")
    ap.add_argument("--cols", type=int, required=True)
    ap.add_argument("--rows", type=int, default=1)
    ap.add_argument("--cell", help="cell size WxH (default: sheet/cols x sheet/rows)")
    ap.add_argument("--out", help="output prefix (default: <sheet>_f)")
    ap.add_argument("--write", action="store_true", help="write per-frame PNGs")
    ap.add_argument("--recenter", action="store_true",
                    help="repaint each frame's content onto the anchor")
    ap.add_argument("--anchor", default="bottom", choices=["bottom", "center"],
                    help="anchor for --recenter and the alignment report")
    ap.add_argument("--despeckle", action="store_true",
                    help="drop detached components touching a cell border — "
                         "kills neighbor-frame bleed of any size; interior "
                         "strays (sparks) and the main blob are kept")
    a = ap.parse_args()

    W, H, rows = png.read(a.sheet)
    cw = ch = None
    if a.cell:
        cw, ch = map(int, a.cell.lower().split("x"))
    else:
        cw, ch = W // a.cols, H // a.rows
    if cw * a.cols > W or ch * a.rows > H:
        sys.exit(f"grid {a.cols}x{a.rows} of {cw}x{ch} exceeds {W}x{H}")

    prefix = a.out or os.path.splitext(a.sheet)[0] + "_f"
    os.makedirs(os.path.dirname(prefix) or ".", exist_ok=True)

    for i in range(a.cols * a.rows):
        cx, cy = (i % a.cols) * cw, (i // a.cols) * ch
        cell = cell_image(rows, cx, cy, cw, ch)
        dropped = despeckle(cell, cw, ch) if a.despeckle else 0
        bb = png.bbox_alpha(cell, 0, 0, cw, ch)
        tag = f"{i:02d} @({cx},{cy}) {cw}x{ch}"
        if dropped:
            tag += f" despeckled {dropped}px"
        if bb is None:
            print(f"{tag}: EMPTY")
            continue
        bx, by, bw, bh = bb
        want_x = (cw - bw) // 2
        want_y = (ch - bh) if a.anchor == "bottom" else (ch - bh) // 2
        drift = (bx - want_x, by - want_y)
        print(f"{tag}: bbox {bw}x{bh} at +{bx},+{by}  "
              f"drift-from-{a.anchor} {drift[0]:+d},{drift[1]:+d}px")
        if a.write:
            if a.recenter:
                out_cell = [bytearray(cw * 4) for _ in range(ch)]
                for y in range(bh):
                    dst_y = want_y + y
                    if not (0 <= dst_y < ch):
                        continue
                    for px in range(bw):
                        dx = want_x + px
                        if 0 <= dx < cw:
                            out_cell[dst_y][dx * 4:dx * 4 + 4] = \
                                cell[by + y][(bx + px) * 4:(bx + px) * 4 + 4]
                cell = out_cell
            out = f"{prefix}_{i:02d}.png"
            png.write(out, cw, ch, cell)
            print(f"  wrote {out}")


if __name__ == "__main__":
    main()
