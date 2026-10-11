#!/usr/bin/env python3
"""PixelLab asset generation client — submit job, poll, download PNGs."""
import base64, json, os, sys, time
import urllib.request

TOKEN = os.environ.get("PIXELLAB_TOKEN") or sys.exit(
    "Set PIXELLAB_TOKEN env var (see .env.example)")
API = "https://api.pixellab.ai/v2"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.environ.get("GEN_OUT_DIR", ROOT + "/prototype/assets")
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
        with urllib.request.urlopen(r, timeout=60) as resp:
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

def gen_image(description, w, h, prefix, style=None, no_bg=True, seed=None):
    body = {"description": description,
            "image_size": {"width": w, "height": h},
            "no_background": no_bg}
    if style:
        im = __import__("PIL.Image", fromlist=["Image"]).open(style)
        body["style_image"] = {"image": b64img(style),
                               "size": {"width": im.width, "height": im.height},
                               "usage_description": "copy this pixel art style: chunky sprites, thick dark outlines, saturated candy palette, cozy isometric game art"}
        body["style_options"] = {"color_palette": True, "outline": True,
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
    style = ROOT + "/docs/reference/example.png"
    which = sys.argv[1] if len(sys.argv) > 1 else "shop"
    pixen = which.startswith("p_")
    if pixen:
        which = which[2:]
    if pixen:
        descs = {
            "cauldron": "big black iron cauldron bubbling with glowing teal potion and green bubbles, small wooden stool beside it, pixel art game prop, thick dark outline",
            "stall": "small wooden market stall with striped purple awning and glass potion bottles on the counter, pixel art game prop, thick dark outline",
            "tree": "chunky stylized pine tree, deep teal green foliage with tiny warm fairy lights, pixel art game prop, thick dark outline",
            "slime": "cute teal slime blob creature with big eyes and tiny wizard hat, chibi pixel art game character, thick dark outline",
            "cat": "round chibi black cat familiar with amber eyes sitting, pixel art game character, thick dark outline",
        }
        sizes = {"cauldron": (120,120), "stall": (140,140), "tree": (112,152),
                 "slime": (96,80), "cat": (96,80)}
        w,h = sizes[which]
        gen_pixen(descs[which], w, h, "p_"+which)
        sys.exit(0)
    if which == "shop":
        gen_image(
            "isometric cozy potion shop building for a pixel art game: a small "
            "wooden cottage shop with a giant curved purple witch hat as its "
            "roof, glowing warm windows, tiny chimney puffing teal smoke, "
            "wooden signpost, hanging lantern, viewed at isometric angle on "
            "transparent background",
            240, 280, "shop", style=style)
    elif which == "witch":
        gen_image(
            "chibi pixel art game character: cute little witch shopkeeper, big "
            "head, oversized purple witch hat, orange dress, holding a wooden "
            "spoon, standing facing camera, full body, thick dark outline, "
            "transparent background",
            96, 96, "witch", style=style)
    elif which == "knight":
        gen_image(
            "chibi pixel art game character: small round knight customer with "
            "big head, dented helmet with red plume, tiny sword, standing "
            "facing camera, full body, thick dark outline, transparent",
            96, 96, "knight", style=style)
    elif which == "slime":
        gen_image(
            "chibi pixel art game creature: cute teal slime blob with big eyes "
            "and a tiny wizard hat, thick dark outline, transparent",
            96, 80, "slime", style=style)
    elif which == "cat":
        gen_image(
            "chibi pixel art game creature: round black cat familiar with "
            "amber eyes sitting, thick dark outline, transparent",
            96, 80, "cat", style=style)
    elif which == "cauldron":
        gen_image(
            "pixel art game prop: big black iron cauldron bubbling with "
            "glowing teal potion, small wooden stool, isometric view, thick "
            "dark outline, transparent background",
            120, 120, "cauldron", style=style)
    elif which == "stall":
        gen_image(
            "pixel art game prop: small wooden market stall with striped "
            "purple awning, potion bottles on the counter, isometric view, "
            "thick dark outline, transparent background",
            140, 140, "stall", style=style)
    elif which == "tree":
        gen_image(
            "pixel art game prop: single chunky stylized pine tree, deep teal "
            "green with fairy lights wrapped around, isometric view, thick "
            "dark outline, transparent background",
            110, 150, "tree", style=style)
    elif which == "scene":
        gen_image(
            "isometric cozy pixel art game diorama at dusk: a small potion "
            "shop cottage with giant purple witch hat roof in a forest "
            "clearing, bubbling cauldron on campfire, wooden market stall, "
            "glowing mushrooms, teal pond, pine trees around the edges, "
            "string lights, scattered flowers and crates, rich saturated "
            "colors on a dark night background, chunky chibi style",
            560, 420, "scene", style=style, no_bg=False)
