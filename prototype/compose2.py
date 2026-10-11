#!/usr/bin/env python3
"""Final demo composite — AI-generated example.png-style assets + game UI."""
import os, random, math
from PIL import Image, ImageDraw, ImageFont, ImageEnhance, ImageFilter

A = os.path.dirname(os.path.abspath(__file__)) + "/assets"
G = A + "/gen"
INK = (22, 14, 34)
BG = (13, 11, 24)

def load(p):
    return Image.open(p).convert("RGBA")

def scale(im, f):
    return im.resize((max(1,round(im.width*f)), max(1,round(im.height*f))), Image.NEAREST)

W, H = 1120, 1220
cv = Image.new("RGBA", (W, H), BG + (255,))
d = ImageDraw.Draw(cv)
random.seed(11)

# ---------- stars on the dark backdrop ----------
for _ in range(90):
    x, y = random.uniform(0, W), random.uniform(0, H)
    r = random.choice([1, 1, 1, 2, 2, 3])
    c = random.choice([(255,240,190),(190,235,255),(210,190,255),(150,255,215)])
    d.ellipse([x, y, x+r*2, y+r*2], fill=c+(random.randint(140,230),))

# ---------- ground: isometric grass diamond with dirt sides ----------
cx, gy = W//2, 250          # diamond top-center
DW, DH = 880, 560           # diamond size
top=(cx,gy); right=(cx+DW//2,gy+DH//2); bottom=(cx,gy+DH); left=(cx-DW//2,gy+DH//2)
# dirt sides (thickness below left/right/bottom edges)
dirt=(74,48,44); dirt2=(58,38,36); off=66
d.polygon([left,bottom,(bottom[0],bottom[1]+off),(left[0],left[1]+off)],fill=dirt2)
d.polygon([bottom,right,(right[0],right[1]+off),(bottom[0],bottom[1]+off)],fill=dirt)
# grass top
grass=(88,168,66)
d.polygon([top,right,bottom,left],fill=grass)
# grass speckle texture
px=cv.load()
for _ in range(2600):
    x,y=random.uniform(0,W-1),random.uniform(0,H-1)
    # inside diamond?
    dx,dy=abs(x-cx),abs(y-(gy+DH//2))
    if dx/(DW/2)+dy/(DH/2) <= 1.0:
        shade=random.choice([(98,178,72),(78,152,60),(108,186,80),(96,172,150)])
        for ox in range(3):
            for oy in range(3):
                xi,yi=int(x+ox),int(y+oy)
                if 0<=xi<W and 0<=yi<H: px[xi,yi]=shade+(255,)
# stone path from bottom point toward shop door
path=[(cx-40,gy+DH-30),(cx-10,gy+DH-120),(cx-60,gy+DH-190),(cx-90,gy+DH-250)]
for i,(pxx,pyy) in enumerate(path):
    d.ellipse([pxx-34,pyy-14,pxx+34,pyy+14],fill=(168,160,140))
    d.ellipse([pxx-30,pyy-12,pxx+30,pyy+11],fill=(188,180,158))

# pond bottom-right
d.ellipse([cx+150,gy+DH-180,cx+370,gy+DH-60],fill=(60,170,200))
d.ellipse([cx+160,gy+DH-172,cx+360,gy+DH-68],fill=(86,205,228))
d.ellipse([cx+205,gy+DH-140,cx+245,gy+DH-112],fill=(120,225,240))  # sparkle
# lily pad
d.ellipse([cx+290,gy+DH-130,cx+330,gy+DH-106],fill=(80,160,90))

# helper: iso-ish ground position -> feet anchor
def put(im, fx, fy):
    cv.paste(im, (int(fx-im.width/2), int(fy-im.height)), im)

# ---------- the shop (hero) ----------
shop = scale(load(G+"/shop_0.png"), 1.5)
put(shop, cx-210, gy+330)

# string lights: shop corner -> tree
def garland(x0,y0,x1,y1,n=16,sag=26):
    for i in range(n+1):
        t=i/n; x=x0+(x1-x0)*t; y=y0+(y1-y0)*t+math.sin(t*math.pi)*sag
        c=[(255,220,120),(150,240,200),(255,150,200)][i%3]
        d.ellipse([x-3,y-3,x+3,y+3],fill=c+(255,))
garland(cx-60,gy+170,cx+120,gy+230)

# ---------- trees framing the back ----------
tree = load(G+"/p_tree_0.png")
put(scale(tree,1.35), cx+330, gy+150)
put(scale(tree,1.15), cx+400, gy+290)
put(scale(tree,1.0),  cx-390, gy+170)
# big leafy OGA tree left
bigt = Image.open(A+"/sprites/plants/isometric tiles/bigtree02.png").convert("RGBA")
bigt.thumbnail((200,220),Image.NEAREST)
put(bigt, cx-380, gy+230)

# ---------- props ----------
cauldron = scale(load(G+"/p_cauldron_0.png"), 1.35)
put(cauldron, cx-30, gy+DH-230)
# fire ring under cauldron glow
d.ellipse([cx-60,gy+DH-150,cx+30,gy+DH-110],fill=(255,160,60))
# barrel + crates (OGA furniture sprites)
def spr(name):
    for f in os.listdir(A+"/sprites"):
        if f.startswith(name): return load(A+"/sprites/"+f)
put(scale(spr("fw_07_"),1.0), cx-330, gy+330)
put(scale(spr("fw_60_"),1.0), cx+300, gy+DH-200)
# mushroom dots
for _ in range(7):
    x=random.uniform(cx-420,cx+400); y=random.uniform(gy+180,gy+DH-40)
    d.ellipse([x,y,x+10,y+8],fill=(230,90,120)); d.rectangle([x+3,y+8,x+7,y+14],fill=(240,220,200))

# ---------- characters ----------
witch = scale(load(G+"/witch_1.png"), 1.25)
put(witch, cx-130, gy+390)
knight = scale(load(G+"/knight_1.png"), 1.25)
put(knight, cx+80, gy+430)
slime = scale(load(G+"/p_slime_0.png"), 1.2)
put(slime, cx+230, gy+DH-120)

# two more customers from the OGA hero sheet (chroma-keyed, outlined)
def hero_cell(sx,sy,cx2,cy):
    hero=load(A+"/hero.png")
    c=hero.crop((sx*165+cx2*33, sy*264+cy*33, sx*165+cx2*33+33, sy*264+cy*33+33))
    p=c.load()
    for y in range(c.height):
        for x in range(c.width):
            r,g,b,a=p[x,y]
            if x<=1 or y<=1 or x>=c.width-1 or y>=c.height-1 or (abs(r-200)<28 and abs(g-191)<28 and abs(b-231)<30):
                p[x,y]=(0,0,0,0)
    return c
def outline(im,w=3):
    a=im.getchannel("A"); rim=a.filter(ImageFilter.MaxFilter(w*2+1))
    rim=rim.point(lambda v:255 if v>60 else 0)
    base=Image.new("RGBA",im.size,(0,0,0,0))
    base.paste(Image.new("RGBA",im.size,INK+(255,)),(0,0),rim)
    base.paste(im,(0,0),im); return base
def char(sx,sy,cx2,cy,fx,fy,f=3.0):
    c=outline(scale(hero_cell(sx,sy,cx2,cy),f))
    put(c,fx,fy)
char(4,0,0,0, cx-200, gy+DH-120)   # red warrior by the pond
char(3,0,0,0, cx+160, gy+330)     # horned-helm knight near table
char(1,0,0,0, cx-60, gy+DH-90)    # dark warrior at bottom path

# ---------- UI layer ----------
def font(sz):
    try: return ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf",sz)
    except: return ImageFont.load_default()
F_S,F_M,F_L,F_XL=font(21),font(27),font(34),font(46)
def rrect(x0,y0,x1,y1,r,fill,outline_=None,ow=0):
    d.rounded_rectangle([x0,y0,x1,y1],r,fill=fill,outline=outline_,width=ow)
def tc(cx2,y,s,f,fill):
    bb=d.textbbox((0,0),s,font=f); d.text((cx2-(bb[2]-bb[0])/2,y),s,font=f,fill=fill)

# HUD pills
rrect(26,26,300,80,27,(18,14,32,240))
d.ellipse([42,40,72,70],fill=(255,200,70))
d.text((86,40),"2,450",font=F_M,fill="white")
rrect(322,26,510,80,27,(18,14,32,240))
d.ellipse([338,40,366,68],fill=(120,230,150))
d.text((378,40),"Rep 12",font=F_M,fill="white")
rrect(W-170,26,W-26,80,27,(18,14,32,240))
d.arc([W-150,36,W-108,72],-90,200,fill=(150,225,255),width=7)
d.text((W-96,42),"Night 3",font=F_S,fill="white")

# speech bubble over knight (knight feet ~ (cx+80, gy+430)); bubble above head
bxk, byk = cx+80, gy+430-120
bw,bh=320,150
rrect(bxk-bw/2,byk-bh,bxk+bw/2,byk,20,(246,234,204,255),INK,5)
d.polygon([(bxk-16,byk-3),(bxk+16,byk-3),(bxk,byk+26)],fill=(246,234,204),outline=INK)
tc(bxk,byk-bh+14,"KAEL · SELLSWORD",F_S,INK)
tc(bxk,byk-bh+48,"\u201cI fight slimes at dawn\u2026",F_M,(52,38,62))
tc(bxk,byk-bh+82,"need something strong!\u201d",F_M,(52,38,62))
d.arc([bxk+bw/2-56,byk-bh+10,bxk+bw/2-14,byk-bh+52],-90,-90+300,fill=(38,180,160),width=7)
tc(bxk+bw/2-35,byk-bh+18,"50",F_S,INK)

# bottom sheet
sy=H-390
rrect(18,sy,W-18,H-18,36,(24,18,42,246))
rrect(18,sy,W-18,H-18,36,(0,0,0,0),(208,176,124),3)
tc(W/2,sy+18,"Brew for Kael",F_L,(255,240,212))
tc(W/2,sy+64,"Pick 1\u20133 ingredients \u2014 ailment: slime fight",F_M,(190,168,205))
ing=["Emberroot","Moonwater","Ghostcap","Stardew","Frostfern"]
x=56
for i,n in enumerate(ing):
    wtxt=d.textbbox((0,0),n,font=F_M)[2]+44
    sel=i<2
    rrect(x,sy+112,x+wtxt,sy+170,22,(58,96,74,255) if sel else (40,32,62,255),(170,235,190) if sel else (96,84,128),3)
    d.text((x+22,sy+126),n,font=F_M,fill=(214,255,226) if sel else (200,190,214))
    x+=wtxt+16
rrect(42,sy+205,W-300,sy+295,28,(44,196,168,255))
tc((W-258)/2,sy+228,"BREW",F_XL,(8,32,26))
rrect(W-280,sy+205,W-42,sy+295,28,(58,48,82,255))
tc(W-161,sy+228,"SERVE",F_XL,(150,140,172))

# vignette
vig=Image.new("L",(W,H),0)
ImageDraw.Draw(vig).ellipse([-W*0.3,-H*0.2,W*1.3,H*1.16],fill=255)
vig=vig.filter(ImageFilter.GaussianBlur(130))
cv=Image.composite(cv,Image.new("RGBA",(W,H),(5,6,12,255)),vig)
cv.save("potion-final.png")
print("saved potion-final.png", cv.size)
