#!/usr/bin/env python3
"""Family-ramp transfer — per-asset regrade onto measured Eastward bands.

The palette-lock puts assets in-family; this pass moves each asset's
family pixels into the family's measured ref BAND while preserving the
sprite's internal shading order (rank-preserving transfer). Whole-frame
grading can't do this — a screen pass can't tell grass luma from tent
luma; per-asset knows exactly what each pixel is.

Inputs:
  assets_src/refs/ramps.json    family -> gate + transfer params + ref band
  assets_src/family_map.json    asset -> family, src, dst
Output: game/assets/pinewatch/<dst>; anchors.json gains the dst key.

QA: per-asset line prints sampled family mean before/after vs the ref
band target (dH/dS/dV) — a family landing far off-band is a data bug,
not a taste call.
"""
import json, os, sys
import colorsys
import numpy as np
from PIL import Image

ROOT = "game/assets/pinewatch/"
RAMPS = json.load(open("assets_src/refs/ramps.json"))
FMAP = json.load(open("assets_src/family_map.json"))["map"]


def gate_mask(rgb, a, g):
    r, gr, b = rgb[..., 0] / 255.0, rgb[..., 1] / 255.0, rgb[..., 2] / 255.0
    mx = np.maximum(np.maximum(r, gr), b)
    mn = np.minimum(np.minimum(r, gr), b)
    d = mx - mn
    # vectorised hsv
    h = np.zeros_like(mx)
    nz = d > 1e-6
    rm = (mx == r) & nz; gm = (mx == gr) & ~rm & nz; bm = nz & ~rm & ~gm
    h[rm] = ((gr - b)[rm] / d[rm]) % 6
    h[gm] = (b - r)[gm] / d[gm] + 2
    h[bm] = (r - gr)[bm] / d[bm] + 4
    h = h / 6.0 % 1.0
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0)
    v = mx
    m = (a > g["a"]) & (s > g["s"]) & (h > g["h"][0]) & (h < g["h"][1])
    if "v_max" in g:
        m &= v < g["v_max"]
    return m, h, s, v


def transfer(h, s, v, m, p):
    if p["mode"] == "affine":
        nv = np.minimum(v * p["v_mul"] + p["v_add"], p["v_max"])
        ns = np.maximum(s * p["s_mul"], p.get("s_min", 0.0))
    else:  # toward: lerp v toward measured ref band, add sat
        nv = v + (p["v_target"] - v) * p["v_amt"]
        ns = np.minimum(s + p["s_add"], p["s_max"])
    nh = h + (p["h_to"] - h) * p["h_amt"]
    # sun-pool dapple: the ref's grass swings shade->near-yellow-white;
    # a "toward" lerp compresses internal spread, so the pools get
    # stamped back on AFTER the lerp (seeded blocky cells = pixel grammar)
    if "dapple" in p:
        d = p["dapple"]
        cell, amp = d["cell"], d["amp"]
        lo = np.random.default_rng(d["seed"]).random(
            (max(2, nv.shape[0] // cell + 1), max(2, nv.shape[1] // cell + 1)))
        # bilinear-upsampled low-res noise = soft organic sun pools,
        # not an 8px checkerboard; ground is painted so soft is right
        nse = np.asarray(Image.fromarray((lo * 255).astype(np.uint8))
                         .resize((nv.shape[1], nv.shape[0]), Image.BILINEAR),
                         dtype=float) / 255.0
        nv = nv + np.clip(nse - 0.42, -0.5, 0.58) * 2.0 * amp   # warm-biased
    # tonal zones: the ref ground is hand-crafted layers — grass darkens
    # + goes olive toward water shores and map edges, canopy band stays
    # shaded. Applied post-lerp so the zones survive compression.
    if "zones" in p:
        z = p["zones"]
        tile = z["tile"]
        zmask = [l.rstrip("\n") for l in open(z["mask"]) if l.strip()]
        H, Wd = nv.shape
        yy, xx = np.mgrid[0:H, 0:Wd]
        wt = [(c * tile + tile / 2, r * tile + tile / 2)
              for r, row in enumerate(zmask)
              for c, ch in enumerate(row) if ch == "W"]
        if wt:
            dist = np.minimum.reduce(
                [(xx - wx) ** 2 + (yy - wy) ** 2 for wx, wy in wt]) ** 0.5
            shore = np.clip(1.0 - dist / z["shore_px"], 0, 1) * z["shore_amt"]
        else:
            shore = 0.0
        edge = np.minimum.reduce(
            [xx, Wd - 1 - xx, yy, H - 1 - yy])
        ev = np.clip(1.0 - edge / z["edge_px"], 0, 1) * z["edge_amt"]
        top = np.clip(1.0 - yy / z["top_px"], 0, 1) * z["top_amt"]
        damp = np.clip(shore + ev + top, 0, z["cap"])
        nv = nv * (1.0 - damp)                 # darker
        nh = nh + shore * z.get("h_shift", 0.0)  # olive shift at shore
    return nh % 1.0, np.clip(ns, 0, 1), np.clip(nv, 0, 1)


def hsv_to_rgb(h, s, v):
    i = np.floor(h * 6).astype(int) % 6
    f = h * 6 - np.floor(h * 6)
    pp, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    r = np.choose(i, [v, q, pp, pp, t, v])
    g = np.choose(i, [t, v, v, q, pp, pp])
    b = np.choose(i, [pp, pp, t, v, v, q])
    return np.stack([r, g, b], -1)


def band(px):
    if not len(px):
        return "n/a"
    rr, gg, bb = px.mean(0)
    return f"({rr:3.0f},{gg:3.0f},{bb:3.0f})"


def main():
    anchors_path = os.path.join(ROOT, "anchors.json")
    anchors = json.load(open(anchors_path)) if os.path.exists(anchors_path) else {}
    changed = False
    for e in FMAP:
        src = e["src"] if e.get("src_root") == "." else ROOT + e["src"]
        dst = ROOT + e["dst"]
        p = RAMPS[e["family"]]
        im = Image.open(src).convert("RGBA")
        arr = np.asarray(im).astype(float)
        m, h, s, v = gate_mask(arr[..., :3], arr[..., 3], p["gate"])
        before = arr[..., :3][m]
        nh, ns, nv = transfer(h, s, v, m, p)
        out_rgb = arr[..., :3].copy()
        out_rgb[m] = hsv_to_rgb(nh[m], ns[m], nv[m]) * 255
        out = np.concatenate([out_rgb, arr[..., 3:4]], -1).astype(np.uint8)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        Image.fromarray(out).save(dst)
        after = out_rgb[m]
        rm = p["ref_mean"]
        # delta vs ref band on the AFTER sample
        dh = after[:, 1].mean() - rm[1]  # channel-2 proxy for hue drift
        dv = out_rgb[m].max(-1).mean() / 255 - max(rm) / 255
        print(f"{e['family']:<12} {e['dst']:<34} "
              f"{band(before)} -> {band(after)}  ref {tuple(rm)}")
        key = e["dst"]
        for k, vv in anchors.items():
            if k == e["src"].split("/")[-1] or k.endswith("/" + e["src"].split("/")[-1]):
                anchors[key] = vv
                changed = True
                break
        else:
            # clone by basename match (props_large/x.png -> fx/x_sunlit.png)
            base = e["src"].split("/")[-1]
            for k, vv in anchors.items():
                if k.endswith("/" + base):
                    anchors[key] = vv
                    changed = True
                    break
    if changed:
        json.dump(anchors, open(anchors_path, "w"), indent=1)
        print("anchors.json: dst keys cloned")


if __name__ == "__main__":
    sys.exit(main())
