"""Shared terrain-pipeline helpers: io, color, exemplars, zone constants."""
import numpy as np
from PIL import Image
import os, json

ROOT = 'assets_src'
LAYERS = f'{ROOT}/layers'
GROUND = f'{ROOT}/stage/ground_v2.png'
SHEET = f'{ROOT}/tiles_ground_32_flat.png'
OUT = f'{ROOT}/stage/ground_terrain.png'

# measured ref anchors (eastward.pxo) -- guides, not copied pixels
ZONE_IDS = ['sunpool', 'lit', 'mid', 'pocket', 'dirt', 'water', 'water_deep', 'struct']
ANCHORS = {
    'sunpool': (0xDE, 0xFE, 0x66),
    'lit': (0xB1, 0xDD, 0x5C),
    'mid': (0xA6, 0xCC, 0x52),
    'pocket': (0x84, 0x97, 0x5B),
    'dirt': (0xA8, 0xA8, 0x4E),
    'water': (0x30, 0x9D, 0x81),
    'water_deep': (0x18, 0x78, 0x64),
}
# colors used to visualize zones.png
ZONE_VIZ = {
    'sunpool': (222, 254, 102), 'lit': (177, 221, 92), 'mid': (140, 180, 80),
    'pocket': (90, 110, 60), 'dirt': (170, 160, 80), 'water': (48, 157, 129),
    'water_deep': (24, 100, 90), 'struct': (20, 20, 20),
}

# exemplar tile grid on the 128x96 sheet
EX_POS = {
    'sunpool': (0, 0), 'lit': (0, 32), 'mid': (0, 64), 'pocket': (0, 96),
    'water': (32, 0), 'water_deep': (32, 32), 'dirt': (32, 64),
}


def load_rgb(path):
    return np.asarray(Image.open(path).convert('RGB'), np.float32)


def save_rgb(arr, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(path)


def hsv(px):
    """Vectorized RGB->HSV, float in [0,1]. Safe on flat colors."""
    r, g, b = px[..., 0], px[..., 1], px[..., 2]
    mx = px.max(-1); mn = px.min(-1)
    d = np.maximum(mx - mn, 1e-6)
    v = mx / 255.0
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0.0)
    h = np.zeros_like(v)
    h = np.where(mx == r, (60 * ((g - b) / d) % 360) / 360.0, h)
    h = np.where((mx == g) & (mx != r), (60 * ((b - r) / d) + 120) / 360.0, h)
    h = np.where((mx == b) & (mx != r) & (mx != g), (60 * ((r - g) / d) + 240) / 360.0, h)
    return h, s, v


def exemplars(sheet_path=SHEET, size=32):
    sh = load_rgb(sheet_path)
    return {k: sh[y:y + size, x:x + size] for k, (y, x) in EX_POS.items()}


def dump_json(obj, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        json.dump(obj, f, indent=1)
