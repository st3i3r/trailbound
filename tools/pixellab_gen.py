#!/usr/bin/env python3
"""PixelLab asset generation client — submit job, poll, download PNGs."""
import base64, json, os, sys, time
import urllib.request

TOKEN = os.environ.get("PIXELLAB_TOKEN") or sys.exit(
    "Set PIXELLAB_TOKEN env var (see .env.example)")
API = "https://api.pixellab.ai/v2"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.environ.get("GEN_OUT_DIR", ROOT + "/assets_src")
GEN = A + "/gen"
os.makedirs(GEN, exist_ok=True)

def b64img(path):
    with open(path, "rb") as f:
        return {"type": "base64", "base64": base64.b64encode(f.read()).decode(),
                "format": "png"}

def req(method, path, body=None):
    r = urllib.request.Request(
        API + path,
        data=json.dumps(body).encode() if body else None,
        headers={"Authorization": "Bearer " + TOKEN,
                 "Content-Type": "application/json"},
        method=method)
    try:
        with urllib.request.urlopen(r, timeout=180) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        print("HTTP", e.code, e.read()[:500])
        return None

def poll(job_id, timeout=420):
    t0 = time.time()
    while time.time() - t0 < timeout:
        r = req("GET", f"/background-jobs/{job_id}")
        if not r:
            time.sleep(5); continue
        st = r.get("status")
        print(f"  job {job_id[:8]}... {st}")
        if st == "completed":
            return r
        if st == "failed":
            print("  FAILED:", json.dumps(r)[:400]); return None
        time.sleep(5)
    print("  timeout"); return None

def download(url, path):
    urllib.request.urlretrieve(url, path)

def collect_images(resp, prefix):
    """Pull every image URL/base64 out of a completed job response."""
    out = []
    def walk(o):
        if isinstance(o, dict):
            for k, v in o.items():
                if k in ("image_url", "url", "download_url") and isinstance(v, str) and v.startswith("http"):
                    out.append(v)
                elif k in ("image", "png", "base64") and isinstance(v, str) and len(v) > 1000:
                    out.append("b64:" + v)
                else:
                    walk(v)
        elif isinstance(o, list):
            for v in o: walk(v)
    walk(resp)
    saved = []
    for i, u in enumerate(dict.fromkeys(out)):
        p = f"{GEN}/{prefix}_{i}.png"
        if u.startswith("b64:"):
            open(p, "wb").write(base64.b64decode(u[4:]))
        else:
            download(u, p)
        saved.append(p)
        print("  saved", p)
    return saved

def gen_image(description, w, h, prefix, style=None, no_bg=True, seed=None,
              style_palette=True):
    body = {"description": description,
            "image_size": {"width": w, "height": h},
            "no_background": no_bg}
    if style:
        im = __import__("PIL.Image", fromlist=["Image"]).open(style)
        body["style_image"] = {"image": b64img(style),
                               "size": {"width": im.width, "height": im.height},
                               "usage_description": "copy this pixel art style: palette, outlines, shading and level of detail"}
        body["style_options"] = {"color_palette": style_palette,
                                 "outline": True,
                                 "detail": True, "shading": True}
    if seed is not None:
        body["seed"] = seed
    r = req("POST", "/generate-image-v2", body)
    if not r: return []
    jid = r.get("background_job_id")
    print(f"{prefix}: job {jid}")
    resp = poll(jid)
    if not resp: return []
    return collect_images(resp, prefix)

def gen_pixen(description, w, h, prefix, view="high top-down", no_bg=True):
    """Cheaper synchronous generator — returns image directly."""
    body = {"description": description,
            "image_size": {"width": w, "height": h},
            "view": view, "no_background": no_bg,
            "outline": "single color outline",
            "detail": "highly detailed",
            "enhance_prompt": True}
    r = req("POST", "/create-image-pixen", body)
    if not r: return []
    saved = collect_images(r, prefix)
    return saved

if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser(
        description="Generate PixelLab images into GEN_OUT_DIR/gen "
                    "(default: assets_src/gen).")
    ap.add_argument("description", help="prompt text")
    ap.add_argument("width", type=int)
    ap.add_argument("height", type=int)
    ap.add_argument("prefix", help="output file prefix")
    ap.add_argument("--style", default=ROOT + "/docs/reference/example.png",
                    help="style reference image (default: docs/reference/example.png)")
    ap.add_argument("--style-no-color", action="store_true",
                    help="transfer outline/detail/shading only — keep the "
                         "described palette instead of the ref's")
    ap.add_argument("--no-style", action="store_true",
                    help="generate without a style reference")
    ap.add_argument("--keep-bg", action="store_true",
                    help="keep the background (default: transparent)")
    ap.add_argument("--seed", type=int)
    ap.add_argument("--pixen", action="store_true",
                    help="cheaper synchronous generator; ignores --style and --seed")
    ap.add_argument("--view", default="high top-down", help="view for --pixen")
    a = ap.parse_args()
    if a.pixen:
        saved = gen_pixen(a.description, a.width, a.height, a.prefix,
                          view=a.view, no_bg=not a.keep_bg)
    else:
        saved = gen_image(a.description, a.width, a.height, a.prefix,
                          style=None if a.no_style else a.style,
                          no_bg=not a.keep_bg, seed=a.seed,
                          style_palette=not a.style_no_color)
    sys.exit(0 if saved else 1)
