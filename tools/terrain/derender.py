"""Derender -- strip baked props from a scene render via cv2.inpaint
(Telea diffusion), then re-key the ground to the measured palette:

  water        -> #389E83 (cleaner teal, user pick)
  grass near water (<10px) -> #ADD85A
  grass open             -> #DFF968

Prop detection: high local contrast (9x9 luma std) | dark/pale struct,
closed + dilated; components <60px dropped.

Usage: python -m tools.terrain.derender [src.png] [dst.png]
"""
import sys
import numpy as np
import cv2
from PIL import Image
from scipy import ndimage
from . import lib
from .lib import LAYERS, save_rgb, hsv


def prop_mask(g):
    lum = g.mean(-1)
    e1 = ndimage.uniform_filter(lum, 9)
    e2 = ndimage.uniform_filter(lum * lum, 9)
    std = np.sqrt(np.maximum(e2 - e1 * e1, 0))
    h, s, v = hsv(g)
    struct = (v < 0.30) | (s < 0.22)
    m = (std > 14) | struct
    m = ndimage.binary_closing(m, iterations=3)
    m = ndimage.binary_fill_holes(m)
    lab, n = ndimage.label(m)
    keep = np.zeros_like(m)
    for i in range(1, n + 1):
        c = lab == i
        if c.sum() >= 60:
            keep |= c
    return ndimage.binary_dilation(keep, iterations=4)


def rekey(res):
    """Palette rules on the cleaned image (preserve local luminance)."""
    h, s, v = hsv(res)
    water = (h > 0.34) & (h < 0.55) & (s > 0.30)
    # -> anchor #389E83 preserving per-pixel lightness ratio
    anch = np.array([0x38, 0x9E, 0x83], np.float32)
    lum = res[water].mean(-1, keepdims=True) / max(float(anch.mean()), 1)
    res[water] = np.clip(anch * lum, 0, 255)
    # grass: distance-from-water tint  near -> #ADD85A, far -> #DFF968
    grass = (h > 0.12) & (h <= 0.34) & (s > 0.25) & ~water
    d = ndimage.distance_transform_edt(~water)
    near = grass & (d < 10)
    far = grass & (d >= 10)
    for m, c in ((near, (0xAD, 0xD8, 0x5A)), (far, (0xDF, 0xF9, 0x68))):
        if m.any():
            c = np.array(c, np.float32)
            lum = res[m].mean(-1, keepdims=True) / float(c.mean())
            res[m] = np.clip(c * np.clip(lum, .85, 1.15), 0, 255)
    return res


def run(src='assets_src/stage/ground_fresh.png',
        out='assets_src/stage/ground_clean.png',
        rects=None):
    """rects: [(x,y,w,h),...] manual ghost regions; None -> auto prop_mask."""
    g = lib.load_rgb(src)
    if rects is None:
        pm = prop_mask(g)
    else:
        pm = np.zeros(g.shape[:2], bool)
        for x, y, w, h in rects:
            pm[y:y + h, x:x + w] = True
    save_rgb(np.tile((pm * 255).astype(np.uint8)[..., None], (1, 1, 3)),
             f'{LAYERS}/propmask.png')
    img = np.clip(g, 0, 255).astype(np.uint8)
    clean = cv2.inpaint(img, pm.astype(np.uint8), 5, cv2.INPAINT_TELEA)
    res = clean.astype(np.float32)
    # soften the patch to a flat wash like the surrounding ground, then a
    # whisper of low-frequency mottle so it isn't dead-flat
    blur = ndimage.gaussian_filter(res, (3.0, 3.0, 0))
    res[pm] = blur[pm]
    mottle = ndimage.gaussian_filter(
        np.random.default_rng(11).standard_normal(res.shape[:2]), 3.0)
    res[pm] = np.clip(res[pm] + mottle[..., None][pm] * 1.5, 0, 255)
    # feather at hole edge for seam safety
    edge = ndimage.binary_dilation(pm, iterations=2) & ~pm
    res[edge] = res[edge] * 0.5 + g[edge] * 0.5
    res = rekey(res)
    if res.shape[:2] != (384, 640):
        res = np.asarray(Image.fromarray(
            np.clip(res, 0, 255).astype(np.uint8)).resize(
            (640, 384), Image.BILINEAR)).astype(np.float32)
    save_rgb(res, out)
    print('props removed:', int(pm.sum()), 'px; saved', out)


if __name__ == '__main__':
    run(*sys.argv[1:])
