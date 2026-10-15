"""Efros-Freeman quilting: extend exemplar tiles into ground zones.
Usage: python tools/quilt_ground.py
"""
import numpy as np
from PIL import Image
import colorsys, os

rng = np.random.default_rng(11)

ROOT = 'assets_src'
GROUND = f'{ROOT}/stage/ground_v2.png'
SHEET  = f'{ROOT}/tiles_ground_32_flat.png'
OUT    = f'{ROOT}/stage/ground_quilted.png'

sheet = np.array(Image.open(SHEET).convert('RGB')).astype(np.float32)
# exemplar tiles (x,y) on the 128x96 sheet
EX = {
 'sunpool':   sheet[0:32,  0:32],
 'lit':       sheet[0:32, 32:64],
 'mid':       sheet[0:32, 64:96],
 'pocket':    sheet[0:32, 96:128],
 'water':     sheet[32:64, 0:32],
 'water_deep':sheet[32:64, 32:64],
 'dirt':      sheet[32:64, 64:96],
}

g = np.array(Image.open(GROUND).convert('RGB')).astype(np.float32)
H, W = g.shape[:2]

# ---- classify each pixel to a band by hue/value/sat ----
def hsvv(px):
    r,gg,b = px[...,0]/255, px[...,1]/255, px[...,2]/255
    mx = px.max(-1); mn = px.min(-1)
    d = mx-mn
    v = mx/255.0
    s = np.where(mx>0, d/np.maximum(mx,1e-6), 0)
    h = np.zeros_like(v)
    m = d>1e-6
    h = np.where(m & (mx==px[...,0]), (60*((px[...,1]-px[...,2])/d) % 360)/360, h)
    h = np.where(m & (mx==px[...,1]), (60*((px[...,2]-px[...,0])/d)+120)/360, h)
    h = np.where(m & (mx==px[...,2]), (60*((px[...,0]-px[...,1])/d)+240)/360, h)
    return h, s, v

h,s,v = hsvv(g)
# band masks (ordered by priority)
is_water = (h>0.40)&(h<0.52)&(s>0.35)&(v>0.25)
is_deep  = is_water & (v<0.55)
is_water = is_water & ~is_deep
is_dark  = (v<0.42)&~is_water                                  # outlines/stones/plum
is_rock  = (s<0.35)&(v>=0.42)&(v<0.75)&(h<0.35)|(h>0.55)&(s<0.35)&(v>=0.42)&(v<0.75)
is_grass = ~is_water & ~is_deep & ~is_dark & ~is_rock & (s>0.3) & (v>0.5)
is_pocket= is_grass & (v<0.66)
is_sun   = is_grass & (v>0.78) & (h<0.22)
is_dirt  = is_grass & (v>0.55)&(v<0.78)&(s<0.55)&(h>0.15)&(h<0.25)
is_lit   = is_grass & ~is_pocket & ~is_sun & ~is_dirt
is_mid   = np.zeros((H,W),bool)

# pocket leftovers -> mid if greener
masks = {'sunpool':is_sun,'lit':is_lit,'mid':is_mid,'pocket':is_pocket,
         'water':is_water,'water_deep':is_deep,'dirt':is_dirt}
for k,m in masks.items(): print(k, int(m.sum()))

# ---- quilting ----
def quilt(mask, exemplar, P=20, O=6, K=9):
    out = np.zeros((H,W,3),np.float32)
    step = P-O
    # allowed write region = mask bounding box padded
    ys,xs = np.where(mask)
    if len(ys)==0: return out, mask
    y0,y1,x0,x1 = ys.min(), ys.max(), xs.min(), xs.max()
    y0=max(0,y0-4); x0=max(0,x0-4); y1=min(H-1,y1+4); x1=min(W-1,x1+4)
    eh,ew = exemplar.shape[:2]
    written = np.zeros((H,W),bool)
    for gy in range(y0, y1+1, step):
        for gx in range(x0, x1+1, step):
            # target region
            ty0,tx0 = gy,gx
            ty1,tx1 = min(H,gy+P), min(W,gx+P)
            ph,pw = ty1-ty0, tx1-tx0
            best=None; besterr=1e18
            for _ in range(K):
                ey,ex = rng.integers(0,eh), rng.integers(0,ew)
                # toroidal crop
                yy=(np.arange(ph)+ey)%eh; xx=(np.arange(pw)+ex)%ew
                patch = exemplar[np.ix_(yy,xx)]
                err=0.0
                # overlap with written: left strip + top strip
                if gx>0:
                    ov = patch[:, :O] - out[ty0:ty1, tx0:tx0+O]
                    err += float((ov**2).sum())
                if gy>0:
                    ov = patch[:O, :] - out[ty0:ty0+O, tx0:tx1]
                    err += float((ov**2).sum())
                if err<besterr: besterr=err; best=patch
            patch = best
            # min-error seam on overlaps -> simple: paste with soft alpha on overlap
            alpha = np.ones((ph,pw,1),np.float32)
            for i in range(O):
                a = (i+1)/(O+1)
                if gx>0 and i<pw: alpha[:,i,0]*=a
                if gy>0 and i<ph: alpha[i,:,0]*=a
            out[ty0:ty1,tx0:tx1] = out[ty0:ty1,tx0:tx1]*(1-alpha)+patch*alpha
            written[ty0:ty1,tx0:tx1]=True
    return out, mask

result = g.copy()
for band,ex in EX.items():
    out,mask = quilt(masks[band], ex)
    sel = mask & (out.sum(-1)>0)
    result[sel] = out[sel]

# keep original edge treatment: restore pixels within 3px of any band boundary
from scipy import ndimage
anymask = np.zeros((H,W),bool)
for m in masks.values(): anymask|=m
bnd = np.zeros((H,W),bool)
for m in masks.values():
    bnd |= (ndimage.binary_erosion(m,iterations=2)^m)
edge = ndimage.binary_dilation(bnd,iterations=2)
result[edge]=g[edge]
# also restore non-band pixels (rocks, outlines, dark)
result[~anymask]=g[~anymask]

Image.fromarray(result.astype(np.uint8)).save(OUT)
print('saved', OUT)
