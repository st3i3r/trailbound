#!/usr/bin/env python3
"""ASCII-art alpha/color map of a PNG or sub-region — lets me 'see' shapes."""
import os, sys
from PIL import Image

def show(path, region=None, sx=2, sy=2, mode="alpha"):
    im = Image.open(path).convert("RGBA")
    if region:
        im = im.crop(region)
    w, h = im.size
    px = im.load()
    for y in range(0, h, sy):
        line = []
        for x in range(0, w, sx):
            a = px[x, y][3]
            if mode == "alpha":
                line.append(" " if a == 0 else ("." if a < 128 else "#"))
            else:  # colorclass
                if a == 0:
                    line.append(" ")
                else:
                    r, g, b, _ = px[x, y]
                    if r > 200 and g > 170 and b < 200:
                        line.append("p")          # parchment cream
                    elif r > 150 and g < 100 and b < 80:
                        line.append("R")          # red seal
                    elif g > r and g > b:
                        line.append("g")          # green
                    elif r > 150 and g > 100 and b < 110:
                        line.append("o")          # orange/ember/gold
                    elif r < 90 and g < 90 and b < 70:
                        line.append("d")          # dark outline
                    elif abs(r-g) < 40 and abs(g-b) < 40:
                        line.append("n")          # neutral brown/grey
                    else:
                        line.append("?")
        print("".join(line))

if __name__ == "__main__":
    path = sys.argv[1]
    region = tuple(int(v) for v in sys.argv[2].split(",")) if len(sys.argv) > 2 else None
    mode = sys.argv[3] if len(sys.argv) > 3 else "color"
    show(path, region, mode=mode)
