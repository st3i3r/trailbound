#!/usr/bin/env python3
"""Pad marker sprites — corner-bracket rings for camp pads (GDD §5.1:
64x64 cells). Synthesized locally — no API spend for pure geometry.
Writes pad_open.png / pad_hover.png / pad_locked_dot.png to
game/assets/pinewatch/. Stdlib only (tools/png.py).
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import png as pngmod

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "assets", "pinewatch")
S = 64

def blank():
    return [bytearray(S * 4) for _ in range(S)]

def px(rows, x, y, rgba):
    if 0 <= x < S and 0 <= y < S:
        rows[y][x * 4:x * 4 + 4] = rgba

def corner_brackets(color, arm=12, th=2, inset=4):
    """L-brackets at each corner, inside a 64px cell."""
    rows = blank()
    r, g, b, a = color
    for i in range(arm):
        for t in range(th):
            # top-left
            px(rows, inset + i, inset + t, color)
            px(rows, inset + t, inset + i, color)
            # top-right
            px(rows, S - 1 - inset - i, inset + t, color)
            px(rows, S - 1 - inset - t, inset + i, color)
            # bottom-left
            px(rows, inset + i, S - 1 - inset - t, color)
            px(rows, inset + t, S - 1 - inset - i, color)
            # bottom-right
            px(rows, S - 1 - inset - i, S - 1 - inset - t, color)
            px(rows, S - 1 - inset - t, S - 1 - inset - i, color)
    # dotted mid-edge ticks
    for cx, cy in [(S//2, inset), (S//2, S-1-inset), (inset, S//2), (S-1-inset, S//2)]:
        for t in range(th):
            px(rows, cx + t - 1, cy, color)
            px(rows, cx, cy + t - 1, color)
    return rows

def write(name, rows):
    p = os.path.join(OUT, name)
    pngmod.write(p, S, S, rows)
    print("->", p)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    # open: moss-green brackets, readable but quiet on grass
    write("pad_open.png", corner_brackets((60, 100, 50, 200)))
    # hover/select: pale warm cream — reads as interactive
    write("pad_hover.png", corner_brackets((240, 220, 150, 255)))
    # locked: faint dark brackets under the overgrowth
    write("pad_locked.png", corner_brackets((30, 45, 25, 120)))
