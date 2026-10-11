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
        bb = png.bbox_alpha(rows, cx, cy, cw, ch)
        tag = f"{i:02d} @({cx},{cy}) {cw}x{ch}"
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
            cell = [bytearray(cw * 4) for _ in range(ch)]
            for y in range(bh):
                src = cx + bx
                dst_y = want_y + y
                dst_x = want_x
                if not (0 <= dst_y < ch):
                    continue
                line = rows[cy + by + y]
                for px in range(bw):
                    dx = dst_x + px
                    if 0 <= dx < cw:
                        cell[dst_y][dx * 4:dx * 4 + 4] = \
                            line[(src + px) * 4:(src + px) * 4 + 4]
            else:
                if not a.recenter:
                    cell = cell_image(rows, cx, cy, cw, ch)
            out = f"{prefix}_{i:02d}.png"
            png.write(out, cw, ch, cell)
            print(f"  wrote {out}")


if __name__ == "__main__":
    main()
