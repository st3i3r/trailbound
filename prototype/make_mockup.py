#!/usr/bin/env python3
"""Procedural pixel-art mockup: 'Pip's Potions' isometric diorama.

Draws the scene at a small logical resolution, then upscales with
NEAREST for chunky pixels. Outputs:
  potion-scene.png  - pure diorama (like example.png)
  potion-mockup.png - scene inside the new game UI
"""
import math
from PIL import Image, ImageDraw, ImageFont

# ---------------------------------------------------------- palette
INK   = (28, 18, 44)      # thick outlines (deep plum, not black)
BG    = (18, 14, 34)
GRASS = [(86, 168, 84), (96, 184, 92), (76, 152, 78)]
GRASS_D = (64, 132, 70)
DIRT  = (150, 110, 70)
DIRT_D = (126, 90, 56)
STONE = (168, 160, 186)
STONE_D = (132, 124, 156)
WOOD  = (150, 98, 60)
WOOD_D = (112, 70, 44)
PLANK = (178, 128, 80)
ROOF  = (126, 90, 200)
ROOF_D = (92, 62, 160)
ROOF_HI = (158, 122, 232)
WALLC = (240, 218, 176)
WALLC_D = (210, 184, 140)
WIN   = (255, 214, 120)
POTION = (74, 224, 170)
POTION_HI = (140, 255, 210)
CAUL  = (38, 30, 58)
CAUL_HI = (70, 56, 100)
FIRE1 = (255, 158, 79)
FIRE2 = (255, 217, 93)
PINK  = (240, 106, 138)
TEAL  = (53, 181, 168)
LAV   = (201, 168, 224)
GOLD  = (245, 197, 66)
CREAM = (255, 248, 234)
WATER = (64, 120, 200)
WATER_HI = (110, 175, 240)
MUSH  = (96, 200, 210)
MUSH_D = (60, 150, 170)
MUSH_CAP = (120, 90, 210)
MUSH_SPOT = (230, 235, 255)

SCALE = 5
LW, LH = 230, 210          # logical canvas
img = Image.new("RGB", (LW, LH), BG)
d = ImageDraw.Draw(img)

def px(x, y, w, h, c):
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)

def diamond(cx, cy, w, h, c, oc=None):
    pts = [(cx, cy - h // 2), (cx + w // 2, cy), (cx, cy + h // 2), (cx - w // 2, cy)]
    if oc:
        d.polygon(pts, fill=oc)
        w2, h2 = w - 4, h - 2
        pts = [(cx, cy - h2 // 2), (cx + w2 // 2, cy), (cx, cy + h2 // 2), (cx - w2 // 2, cy)]
    d.polygon(pts, fill=c)

def circle(cx, cy, r, c, oc=None, o=1):
    if oc:
        d.ellipse([cx - r - o, cy - r - o, cx + r + o, cy + r + o], fill=oc)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=c)

def rrect(x, y, w, h, c, oc=None, r=2):
    if oc:
        d.rounded_rectangle([x - 1, y - 1, x + w, y + h], r + 1, fill=oc)
    d.rounded_rectangle([x, y, x + w - 1, y + h - 1], r, fill=c)

# ---------------------------------------------------------- iso ground
TW, TH = 16, 8
OX, OY = 115, 74          # iso origin (top corner of the diamond)
def iso(i, j):
    return OX + (i - j) * (TW // 2), OY + (i + j) * (TH // 2)

GRID = 13
for i in range(GRID):
    for j in range(GRID):
        x, y = iso(i, j)
        c = GRASS[(i + j) % 2]
        d.polygon([(x, y), (x + TW // 2, y + TH // 2), (x, y + TH),
                   (x - TW // 2, y + TH // 2)], fill=c)

# ground edge (thickness)
for i in range(GRID):
    x, y = iso(i, GRID - 1)
    d.polygon([(x - TW // 2, y + TH // 2), (x, y + TH),
               (x, y + TH + 10), (x - TW // 2, y + TH // 2 + 10)], fill=GRASS_D)
    d.polygon([(x, y + TH), (x + TW // 2, y + TH // 2),
               (x + TW // 2, y + TH // 2 + 10), (x, y + TH + 10)], fill=(52, 108, 58))

# grass detail: tufts, flowers, glow-dots
DET = [(1,5),(2,9),(4,11),(6,10),(8,11),(10,8),(11,5),(11,2),(2,2),(5,1),
       (9,1),(0,7),(3,6),(7,3),(10,10),(12,4)]
for k,(i,j) in enumerate(DET):
    x, y = iso(i, j)
    if k % 4 == 0:
        px(x, y+4, 2, 2, (250, 220, 120))              # glow flower
        px(x-1, y+5, 1, 1, (250, 220, 120)); px(x+3, y+5, 1, 1, (250, 220, 120))
    elif k % 4 == 1:
        px(x, y+5, 1, 3, GRASS_D); px(x+2, y+4, 1, 4, GRASS_D); px(x+4, y+5, 1, 3, GRASS_D)
    elif k % 4 == 2:
        px(x+1, y+5, 2, 1, (140, 200, 130))
    else:
        px(x+2, y+4, 2, 2, PINK); px(x+1, y+5, 4, 1, PINK)  # flower

# ---------------------------------------------------------- pond (front-left)
for (i, j) in [(0,9),(0,10),(0,11),(1,9),(1,10),(1,11),(1,12),(2,11),(2,12),(0,12)]:
    x, y = iso(i, j)
    d.polygon([(x, y), (x + TW // 2, y + TH // 2), (x, y + TH),
               (x - TW // 2, y + TH // 2)], fill=WATER)
x, y = iso(0, 10); px(x-3, y+3, 5, 1, WATER_HI)
x, y = iso(1, 11); px(x-4, y+4, 7, 1, WATER_HI)
x, y = iso(1, 10)                                     # lilypad
px(x-2, y+3, 5, 3, (90, 190, 90)); px(x-1, y+2, 3, 1, (120, 220, 120))

# ---------------------------------------------------------- stone path
for (i, j) in [(4,5),(5,6),(6,7),(5,7),(6,8),(7,8)]:
    x, y = iso(i, j)
    diamond(x, y + TH // 2, 10, 6, STONE)
    px(x-3, y+TH//2-1, 3, 2, (200, 194, 220))

# ---------------------------------------------------------- potion shop (back-left)
# body sits around tiles (1..5, 0..4); compute base position
bx, by = iso(3, 1)
# walls
d.polygon([(bx-40, by-34), (bx, by-56), (bx, by-14), (bx-40, by+8)], fill=WALLC_D)
d.polygon([(bx, by-56), (bx+42, by-34), (bx+42, by+8), (bx, by-14)], fill=WALLC)
# timber frame lines
for t in range(4):
    px(bx+6+t*10, by-50+t*5, 2, 44-t*5, WOOD)
px(bx-40, by+6, 82, 3, WOOD_D)
# corner posts
px(bx-40, by-32, 4, 40, WOOD); px(bx+40, by-32, 4, 40, WOOD)
# big crooked witch roof: stacked shrinking diamonds
roof_c = [(bx+1, by-62, 96, 22), (bx-2, by-72, 76, 18),
          (bx-6, by-81, 56, 14), (bx-11, by-89, 36, 11)]
for cx0, cy0, w0, h0 in roof_c:
    d.polygon([(cx0 - w0//2, cy0), (cx0 + 2, cy0 - h0),
               (cx0 + w0//2, cy0), (cx0, cy0 + h0//3)], fill=ROOF, outline=INK)
# roof tip curls left
d.polygon([(bx-29, by-86), (bx-38, by-98), (bx-24, by-92)], fill=ROOF, outline=INK)
px(bx-37, by-99, 4, 4, ROOF_HI)
# shingle lines
for t in range(3):
    px(bx-30+t*8, by-66-t*7, 20, 2, ROOF_D)
# chimney with smoke
px(bx+26, by-84, 7, 18, WOOD_D); px(bx+25, by-86, 9, 4, INK)
circle(bx+29, by-92, 3, (200, 200, 220), None)
circle(bx+32, by-98, 4, (200, 200, 220), None)
circle(bx+30, by-106, 5, (200, 200, 220), None)
# round glowing window (front face)
circle(bx+24, by-38, 6, WIN, oc=INK)
px(bx+23, by-40, 2, 2, (255, 240, 180))
px(bx+24, by-44, 1, 12, WOOD_D); px(bx+18, by-38, 12, 1, WOOD_D)
# door (side face) + step
d.polygon([(bx-28, by-16), (bx-14, by-24), (bx-14, by-4), (bx-28, by+4)],
          fill=WOOD_D, outline=INK)
px(bx-25, by-13, 3, 3, WIN)
diamond(bx-21, by+9, 14, 6, STONE_D)
# hanging sign (potion bottle)
px(bx+44, by-30, 1, 10, WOOD_D)
rrect(bx+40, by-22, 9, 10, (240, 228, 200), oc=INK)
px(bx+43, by-19, 3, 5, POTION); px(bx+44, by-21, 1, 2, WOOD_D)

# ---------------------------------------------------------- giant glowing mushrooms (edges)
def big_mushroom(mx, my, s, cap=MUSH_CAP, stem=C((222), 206, 180) if False else (222, 206, 180)):
    px(mx-s//2, my-s//3, s, s//3, (200, 186, 164))            # stem
    px(mx-s//2+1, my-s//3, s-2, s//3, stem)
    d.pieslice([mx-s, my-s, mx+s, my+s], 180, 360, fill=cap, outline=INK)
    for (ox, oy, r) in [(-s//3, -s//5, 2), (0, -s//3, 3), (s//3, -s//6, 2)]:
        circle(mx+ox, my+oy, r, MUSH_SPOT)
    px(mx-s//2-1, my-1, s+2, 2, MUSH_D)                       # gill shade

big_mushroom(*iso(0, 1), 18)
big_mushroom(iso(0,1)[0]+16, iso(0,1)[1]-8, 11, TEAL)
big_mushroom(iso(11,0)[0]+4, iso(11,0)[1]-4, 14)
big_mushroom(iso(12,1)[0]+10, iso(12,1)[1]+2, 9, TEAL)
# small ones scattered
for (i,j) in [(2,3),(10,2),(1,4),(12,3)]:
    x, y = iso(i, j)
    px(x-1, y, 3, 4, (222, 206, 180))
    d.pieslice([x-4, y-5, x+6, y+4], 180, 360, fill=PINK, outline=INK)

# ---------------------------------------------------------- string lights (two poles)
lx1, ly1 = iso(0, 3); lx2, ly2 = iso(9, 0)
px(lx1, ly1-46, 3, 48, WOOD_D); px(lx2, ly2-40, 3, 42, WOOD_D)
circle(lx1+1, ly1-47, 2, GOLD); circle(lx2+1, ly2-41, 2, GOLD)
steps = 26
for s in range(steps + 1):
    t = s / steps
    x = lx1 + (lx2 - lx1) * t
    y = (ly1 - 44) + ((ly2 - 38) - (ly1 - 44)) * t + math.sin(t * math.pi) * 10
    px(x, y, 1, 1, INK)
    if s % 2 == 0 and 0 < s < steps:
        px(x-1, y+1, 3, 3, [GOLD, PINK, POTION_HI, LAV][(s // 2) % 4])

# ---------------------------------------------------------- cauldron (center)
kx, ky = iso(6, 6)
# fire: logs + flames
px(kx-9, ky+10, 18, 3, WOOD_D)
d.polygon([(kx-6, ky+10), (kx-2, ky+3), (kx+1, ky+10)], fill=FIRE1)
d.polygon([(kx-1, ky+10), (kx+4, ky+2), (kx+8, ky+10)], fill=FIRE1)
d.polygon([(kx-3, ky+10), (kx+1, ky+5), (kx+4, ky+10)], fill=FIRE2)
# glow
circle(kx+1, ky+7, 12, None)  # noop keep
d.ellipse([kx-13, ky+2, kx+15, ky+14], outline=None, fill=None)
px(kx-12, ky+5, 26, 6, (70, 60, 40))
# pot body
d.ellipse([kx-12, ky-6, kx+14, ky+10], fill=INK)
d.ellipse([kx-11, ky-5, kx+13, ky+9], fill=CAUL)
d.ellipse([kx-12, ky-8, kx+14, ky+1], fill=INK)
d.ellipse([kx-10, ky-7, kx+12, ky], fill=CAUL_HI)
d.ellipse([kx-9, ky-6, kx+11, ky-1], fill=POTION)
px(kx-9, ky-6, 20, 2, POTION_HI)
# legs + handle
px(kx-9, ky+8, 3, 4, INK); px(kx+8, ky+8, 3, 4, INK)
d.arc([kx-8, ky-16, kx+10, ky-2], 200, 340, fill=INK)
# bubbles + ladle
circle(kx-3, ky-8, 2, POTION_HI); circle(kx+5, ky-9, 1, POTION_HI)
px(kx+12, ky-16, 2, 12, WOOD); px(kx+11, ky-17, 4, 3, WOOD)

# ---------------------------------------------------------- potion stall table (right)
tx, ty = iso(9, 7)
d.polygon([(tx-16, ty+2), (tx+18, ty+2), (tx+18, ty+8), (tx-16, ty+8)],
          fill=WOOD, outline=INK)
d.polygon([(tx-16, ty+2), (tx, ty-6), (tx+18, ty+2), (tx+1, ty+9)],
          fill=PLANK, outline=INK)
px(tx-14, ty+8, 3, 8, WOOD_D); px(tx+13, ty+8, 3, 8, WOOD_D)
# bottles on top
for n,(ox,c) in enumerate([(-8,POTION),(0,PINK),(8,LAV)]):
    px(tx+ox, ty-10, 4, 7, c, )
    px(tx+ox+1, ty-12, 2, 2, WOOD_D)
    px(tx+ox, ty-9, 1, 2, (255,255,255))
# awning: pink/white stripes on two poles
px(tx-15, ty-34, 2, 30, WOOD_D); px(tx+15, ty-34, 2, 30, WOOD_D)
for s in range(6):
    c = PINK if s % 2 == 0 else CREAM
    px(tx-18+s*7, ty-38, 7, 6, c)
px(tx-18, ty-38, 42, 2, INK); px(tx-18, ty-33, 42, 1, INK)

# ---------------------------------------------------------- characters
def witch(wx, wy):
    # cloak
    d.polygon([(wx-7, wy+10), (wx, wy-6), (wx+7, wy+10)], fill=(104, 74, 168), outline=INK)
    # head (big, chibi)
    circle(wx, wy-9, 6, (242, 201, 160), oc=INK)
    px(wx-2, wy-10, 1, 2, INK); px(wx+2, wy-10, 1, 2, INK)   # eyes
    px(wx-2, wy-6, 4, 1, (220, 140, 140))                    # mouth
    px(wx-5, wy-8, 2, 1, (255, 170, 170)); px(wx+4, wy-8, 2, 1, (255, 170, 170))
    # hat: brim + tall crooked cone
    d.ellipse([wx-10, wy-16, wx+10, wy-9], fill=(70, 50, 130), outline=INK)
    d.polygon([(wx-7, wy-13), (wx+7, wy-13), (wx-2, wy-30)], fill=(104, 74, 168), outline=INK)
    d.polygon([(wx-2, wy-30), (wx+3, wy-35), (wx+1, wy-27)], fill=(104, 74, 168), outline=INK)
    px(wx-6, wy-14, 12, 2, GOLD)                             # hat band
    # wand
    px(wx+8, wy-4, 1, 7, WOOD_D); px(wx+7, wy-6, 3, 3, POTION_HI)

def knight(nx, ny):
    # body armor
    rrect(nx-5, ny-2, 11, 12, (150, 160, 190), oc=INK)
    px(nx-5, ny+4, 11, 2, (110, 120, 155))
    # head + helmet
    circle(nx, ny-7, 6, (242, 201, 160), oc=INK)
    px(nx-2, ny-8, 1, 2, INK); px(nx+2, ny-8, 1, 2, INK)
    d.pieslice([nx-7, ny-14, nx+7, ny-4], 180, 360, fill=(150, 160, 190), outline=INK)
    px(nx-1, ny-16, 3, 3, PINK)                              # plume base
    d.polygon([(nx, ny-16), (nx+5, ny-22), (nx+3, ny-14)], fill=PINK, outline=INK)
    # sword held up
    px(nx+8, ny-16, 2, 14, (200, 210, 230))
    px(nx+7, ny-17, 4, 2, GOLD); px(nx+6, ny-3, 6, 2, INK)

witch(iso(4, 7)[0]+4, iso(4, 7)[1]-8)
knight(iso(8, 5)[0]+2, iso(8, 5)[1]+2)

# cat (white, sitting) near pond edge
cx0, cy0 = iso(2, 8)
circle(cx0, cy0, 4, (235, 235, 245), oc=INK)
d.polygon([(cx0-4, cy0-3), (cx0-3, cy0-7), (cx0-1, cy0-4)], fill=(235,235,245), outline=INK)
d.polygon([(cx0+1, cy0-4), (cx0+3, cy0-7), (cx0+4, cy0-3)], fill=(235,235,245), outline=INK)
px(cx0-2, cy0-1, 1, 1, INK); px(cx0+2, cy0-1, 1, 1, INK)
px(cx0-1, cy0+3, 6, 3, (235, 235, 245))
px(cx0+4, cy0+4, 4, 1, (200, 200, 220))                    # tail

# ---------------------------------------------------------- props: crates, barrel, basket
wx0, wy0 = iso(2, 4)
rrect(wx0-2, wy0-8, 9, 9, WOOD, oc=INK); px(wx0+1, wy0-5, 3, 3, WOOD_D)
rrect(wx0+6, wy0-5, 8, 8, (170, 118, 74), oc=INK)
# barrel with mushrooms
bx2, by2 = iso(3, 4)
d.ellipse([bx2-3, by2-8, bx2+7, by2+4], fill=WOOD, outline=INK)
d.ellipse([bx2-2, by2-9, bx2+6, by2-4], fill=(110, 160, 90), outline=INK)
px(bx2, by2-11, 2, 4, (222, 206, 180))
d.pieslice([bx2-3, by2-13, bx2+6, by2-6], 180, 360, fill=MUSH_CAP, outline=INK)
# signpost near path
sx0, sy0 = iso(7, 9)
px(sx0, sy0-12, 2, 14, WOOD_D)
d.polygon([(sx0+1, sy0-12), (sx0+11, sy0-8), (sx0+1, sy0-6)], fill=PLANK, outline=INK)
d.polygon([(sx0+1, sy0-5), (sx0-8, sy0-2), (sx0+1, sy0+1)], fill=PLANK, outline=INK)

# fence along right edge
for i in (10, 11, 12):
    x, y = iso(i, 9)
    px(x-1, y-6, 3, 9, WOOD_D)
for i in (10, 11):
    x1, y1 = iso(i, 9); x2, y2 = iso(i+1, 9)
    d.line([x1+1, y1-4, x2+1, y2-4], fill=WOOD, width=2)
# fence along left edge
for j in (5, 6, 7):
    x, y = iso(0, j)
    px(x-1, y-6, 3, 9, WOOD_D)
for j in (5, 6):
    x1, y1 = iso(0, j); x2, y2 = iso(0, j+1)
    d.line([x1+1, y1-4, x2+1, y2-4], fill=WOOD, width=2)

# sparkles / fireflies
for (fx0, fy0) in [(30,60),(52,30),(180,44),(200,90),(40,120),(190,140),(96,30),(150,60),(70,170),(150,20)]:
    px(fx0, fy0, 2, 2, GOLD)
    px(fx0, fy0-2, 2, 1, GOLD); px(fx0, fy0+3, 2, 1, GOLD)

# ---------------------------------------------------------- export scene
scene = img.resize((LW * SCALE, LH * SCALE), Image.NEAREST)
scene.save("potion-scene.png")
print("saved potion-scene.png", scene.size)

# ==========================================================
# part 2 — game mockup: scene + new UI in a phone frame
# ==========================================================
PW, PH = 430, 880
mock = Image.new("RGB", (PW, PH), BG)
# scale scene to fill width, crop vertically (scene is behind everything)
sc = scene.resize((PW, int(LH * SCALE * PW / (LW * SCALE))), Image.NEAREST)
# crop a window: keep upper 2/3 of scene visible above the sheet
mock.paste(sc, (0, 0))
md = ImageDraw.Draw(mock)

def load_font(sz, bold=True, emoji=False):
    paths = []
    if emoji:
        paths = ["C:/Windows/Fonts/seguiemj.ttf"]
    else:
        paths = ["C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
                 "C:/Windows/Fonts/arialbd.ttf"]
    for p in paths:
        try:
            return ImageFont.truetype(p, sz)
        except OSError:
            continue
    return ImageFont.load_default()

F_TITLE = load_font(17); F_PILL = load_font(15); F_SMALL = load_font(12, bold=False)
F_BTN = load_font(18); F_AIL = load_font(13, bold=False); F_EMOJI = load_font(15, emoji=True)
F_EMOJI_L = load_font(22, emoji=True); F_WHO = load_font(14)

def pill(x, y, w, label, emoji=None, dark=False):
    h = 30
    fill = (59, 48, 82) if dark else (247, 233, 200)
    md.rounded_rectangle([x, y, x + w, y + h], 15, fill=fill,
                         outline=(255, 255, 255, 60), width=1)
    tx = x + 12
    if emoji:
        try: md.text((tx, y + 6), emoji, font=F_EMOJI, fill=None, embedded_color=True)
        except TypeError: md.text((tx, y + 6), emoji, font=F_EMOJI, fill=(240,200,80))
        tx += 22
    md.text((tx, y + 7), label, font=F_PILL,
            fill=(247, 233, 200) if dark else (58, 42, 26))

# HUD
md.text((14, 12), "Pip's Potions", font=F_TITLE, fill=CREAM)
md.text((15, 33), "prototype - dusk", font=F_SMALL, fill=(200, 190, 220))
md.rounded_rectangle([PW-52, 12, PW-14, 40], 10, fill=(30, 22, 55),
                     outline=(120, 100, 160))
try: md.text((PW-45, 15), "U", font=F_PILL, fill=CREAM)  # speaker glyph fallback
except Exception: pass
pill(14, 52, 76, "175", "🪙")
pill(96, 52, 96, "3.0 guild", "⭐")
pill(198, 52, 82, "17 charm", "✨")
pill(286, 52, 128, "Night 1  ▓▓▓░", "🌙", dark=True)

# order bubble over the knight (scene coords -> mock coords)
knx, kny = iso(8, 5)
bxx, byy = int(knx * PW / LW), int(kny * PW / LW * LH / LH)  # scale x only (pasted at y0)
byy = int(kny * PW / LW) + 6
bw, bh = 210, 46
bx0 = min(max(bxx - bw // 2, 8), PW - bw - 8)
md.rounded_rectangle([bx0, byy - 62, bx0 + bw, byy - 16], 12,
                     fill=(247, 233, 200), outline=GOLD, width=3)
d.polygon([(bxx - 8, byy - 16), (bxx + 8, byy - 16), (bxx, byy - 6)], fill=GOLD)
# patience ring
circle(bx0 + 22, byy - 39, 13, (230, 214, 180))
d.arc([bx0 + 10, byy - 51, bx0 + 34, byy - 27], -90, 190, fill=TEAL, width=4)
try: md.text((bx0 + 15, byy - 49), "⚔", font=F_EMOJI_L, embedded_color=True)
except TypeError: md.text((bx0 + 15, byy - 49), "!", font=F_BTN, fill=INK)
md.text((bx0 + 42, byy - 50), '"I fight slimes at dawn..."', font=F_AIL,
        fill=(107, 74, 47))

# bottom sheet (parchment) -----------------------------------
SH = 300
md.rounded_rectangle([0, PH - SH, PW, PH + 20], 24, fill=(247, 233, 200))
md.rounded_rectangle([PW//2 - 22, PH - SH + 8, PW//2 + 22, PH - SH + 13], 3,
                     fill=(190, 170, 140))
# order card
md.rounded_rectangle([14, PH - SH + 24, PW - 14, PH - SH + 78], 14,
                     fill=(255, 253, 247), outline=(220, 200, 170))
md.rounded_rectangle([22, PH - SH + 32, 62, PH - SH + 70], 10, fill=(76, 58, 140))
try: md.text((30, PH - SH + 38), "🗡", font=F_EMOJI_L, embedded_color=True)
except TypeError: md.text((34, PH - SH + 40), "K", font=F_WHO, fill=CREAM)
md.text((70, PH - SH + 30), "Kael the Sellsword", font=F_WHO, fill=INK)
md.text((70, PH - SH + 48), '"Got a slime contract at dawn - need', font=F_SMALL, fill=(107, 74, 47))
md.text((70, PH - SH + 63), 'something that burns goo."', font=F_SMALL, fill=(107, 74, 47))
# ingredient chips
INGS = [("🔥","emberroot"), ("🌙","moonwater"), ("🍄","ghostcap"),
        ("✨","stardew"), ("❄️","frostfern"), ("🩸","drakeblood")]
SEL = {0, 4}
cw = (PW - 28 - 5 * 8) // 6
for n, (e, nm) in enumerate(INGS):
    x = 14 + n * (cw + 8); y = PH - SH + 90
    on = n in SEL
    md.rounded_rectangle([x, y, x + cw, y + 58], 12,
                         fill=(255, 246, 221) if on else (255, 253, 247),
                         outline=GOLD if on else (220, 200, 170), width=2 if on else 1)
    try: md.text((x + cw//2 - 10, y + 5), e, font=F_EMOJI_L, embedded_color=True)
    except TypeError: md.text((x + cw//2 - 10, y + 5), e, font=F_EMOJI_L, fill=GOLD)
    md.text((x + cw//2 - len(nm) * 2.6, y + 34), nm[:10], font=load_font(9, bold=False),
            fill=(107, 74, 47))
    md.text((x + cw//2 - 7, y + 45), "x30", font=load_font(9, bold=False), fill=(150, 130, 100))
# brew + serve buttons
by0 = PH - 74
md.rounded_rectangle([14, by0, PW//2 - 5, by0 + 56], 14, fill=(42, 145, 134))
md.rectangle([14, by0 + 46, PW//2 - 5, by0 + 56], fill=(31, 116, 107))
md.rounded_rectangle([PW//2 + 5, by0, PW - 14, by0 + 56], 14, fill=(209, 79, 112))
md.rectangle([PW//2 + 5, by0 + 46, PW - 14, by0 + 56], fill=(166, 58, 85))
md.text((PW//4 - 38, by0 + 16), "BREW", font=F_BTN, fill=CREAM)
md.text((PW*3//4 - 38, by0 + 16), "SERVE", font=F_BTN, fill=CREAM)
try:
    md.text((PW//4 - 62, by0 + 15), "⚗", font=F_EMOJI_L, embedded_color=True)
    md.text((PW*3//4 - 62, by0 + 15), "🧪", font=F_EMOJI_L, embedded_color=True)
except TypeError:
    pass

mock.save("potion-mockup.png")
print("saved potion-mockup.png", mock.size)
