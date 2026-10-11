#!/usr/bin/env python3
"""Composite a real isometric pixel-art diorama from CC0 assets.

Base: iso-64x64 medieval composed scene (OGA). Characters: DezrasDragons
hero sheets (CC0). Props: furnitureandwalls (CC0). Grade: saturation boost,
dark outline pass (the 'example.png' look), vignette.
"""
import os, math
from PIL import Image, ImageEnhance, ImageFilter, ImageDraw

A = os.path.dirname(os.path.abspath(__file__)) + "/assets"
S = A + "/sprites"
OUT = A + "/.."

INK = (18, 12, 28)        # dark plum outline like example.png
BG  = (11, 13, 22)        # near-black backdrop

def outline(im, w=2, color=INK):
    """Return sprite with a dark rim added behind it (thick-outline look)."""
    a = im.getchannel("A")
    rim = a.filter(ImageFilter.MaxFilter(w * 2 + 1))
    rim = rim.point(lambda v: 255 if v > 60 else 0)
    base = Image.new("RGBA", im.size, (0, 0, 0, 0))
    solid = Image.new("RGBA", im.size, color + (255,))
    base.paste(solid, (0, 0), rim)
    base.paste(im, (0, 0), im)
    return base

def hero_cell(sx, sy, cx, cy):
    """Crop one 33px cell; key out the lavender sheet background."""
    hero = Image.open(A + "/hero.png").convert("RGBA")
    c = hero.crop((sx * 165 + cx * 33, sy * 264 + cy * 33,
                   sx * 165 + cx * 33 + 33, sy * 264 + cy * 33 + 33))
    px = c.load()
    for y in range(c.height):
        for x in range(c.width):
            r, g, b, a = px[x, y]
            edge = x <= 1 or y <= 1 or x >= c.width - 1 or y >= c.height - 1
            if edge or (abs(r - 200) < 28 and abs(g - 191) < 28
                        and abs(b - 231) < 30):
                px[x, y] = (0, 0, 0, 0)
    return c

def scale(im, f):
    return im.resize((round(im.width * f), round(im.height * f)), Image.NEAREST)

def load_sprite(name):
    for f in os.listdir(S):
        if f.startswith(name):
            return Image.open(S + "/" + f).convert("RGBA")
    raise FileNotFoundError(name)

# ---------- canvas ----------
W, H = 1120, 1180
cv = Image.new("RGBA", (W, H), BG + (255,))

# ---------- base diorama (medieval house + trees + pond) ----------
base = Image.open(A + "/medieval-outside.png").convert("RGBA")
base = scale(base, 1.12)
# candy grade: more saturation + contrast + slight warm shift
base = ImageEnhance.Color(base).enhance(1.55)
base = ImageEnhance.Contrast(base).enhance(1.12)
base = ImageEnhance.Brightness(base).enhance(1.08)
# shift green grass -> richer emerald, mauve roof -> violet
px = base.load()
w, h = base.size
for y in range(h):
    for x in range(w):
        r, g, b, a = px[x, y]
        if a == 0: continue
        if g > r and g > b:                      # grass -> emerald
            px[x, y] = (min(255, int(r * 0.75)), min(255, int(g * 1.12)),
                        min(255, int(b * 1.05)), a)
        elif r > b > g and r - g > 18:           # roof mauve -> violet
            px[x, y] = (min(255, int(r * 1.15)), int(g * 0.85),
                        min(255, int(b * 1.35)), a)
        elif b > r and b > g:                    # pond -> teal potion water
            px[x, y] = (int(r * 0.7), min(255, int(g * 1.15)),
                        min(255, int(b * 1.1)), a)
bx = (W - base.width) // 2
by = 150
cv.paste(base, (bx, by), base)

# ---------- props around the shop ----------
def put(sprite, x, y, o=True, ow=2):
    s = outline(sprite, ow) if o else sprite
    cv.paste(s, (int(x), int(y)), s)

barrel = scale(load_sprite("fw_07_"), 0.9)
put(barrel, bx + 300, by + 300)
put(scale(load_sprite("fw_08_"), 0.9), bx + 330, by + 295)

# cauldron-ish pot + jar next to door
put(scale(load_sprite("fw_31_"), 1.0), bx + 260, by + 330)
put(scale(load_sprite("fw_24_"), 0.9), bx + 355, by + 335)

# crates
put(scale(load_sprite("fw_47_"), 0.95), bx + 640, by + 300)
put(scale(load_sprite("fw_60_"), 0.95), bx + 668, by + 305)

# round table with jar (serving stall vibe)
put(scale(load_sprite("fw_51_"), 1.0), bx + 590, by + 345)
put(scale(load_sprite("fw_42_"), 0.8), bx + 618, by + 322, ow=1)

# rugs as welcome mat at door
put(scale(load_sprite("fw_66_"), 0.62), bx + 360, by + 365, o=False)

# ---------- characters (front-facing idle frames, chunky scale) ----------
CH = 3.4  # scale characters ~24px -> ~80px chunky
def char(sx, sy, cx, cy, x, y, ow=3):
    c = hero_cell(sx, sy, cx, cy)
    c = scale(c, CH)
    put(c, x - c.width // 2, y - c.height, ow=ow)

# red-robed witch by the door (block 5,0)
char(5, 0, 0, 0, bx + 355, by + 400)
# knight customer center (block 0,0)
char(0, 0, 0, 0, bx + 480, by + 445)
# dark-haired warrior (block 1,0)
char(1, 0, 0, 0, bx + 575, by + 415)
# red warrior by the pond (block 4,0)
char(4, 0, 0, 0, bx + 310, by + 520)
# hooded rogue customer (bottom block 4,1)
char(4, 1, 0, 0, bx + 650, by + 480)
# blue cleric on the path (block 3,0)
char(3, 0, 0, 0, bx + 420, by + 520)

# ---------- campfire-ish glow: pot + sparkles ----------
d = ImageDraw.Draw(cv)
import random
random.seed(7)
for _ in range(46):
    x = random.uniform(bx + 40, bx + base.width - 40)
    y = random.uniform(by + 60, by + base.height - 40)
    r = random.choice([1, 1, 2, 2, 3])
    c = random.choice([(255, 232, 150), (160, 240, 200), (200, 180, 255)])
    d.ellipse([x, y, x + r * 2, y + r * 2], fill=c + (200,))

# ---------- vignette + soften ----------
vig = Image.new("L", (W, H), 0)
dv = ImageDraw.Draw(vig)
dv.ellipse([-W * 0.28, -H * 0.18, W * 1.28, H * 1.14], fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(120))
black = Image.new("RGBA", (W, H), (5, 6, 12, 255))
cv = Image.composite(cv, black, vig)

cv.save(OUT + "/potion-iso-real.png")
print("saved potion-iso-real.png", cv.size)
