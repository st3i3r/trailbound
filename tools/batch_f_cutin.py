#!/usr/bin/env python3
"""Batch F — cooking cut-in (256x128 full-bleed scene panel).

create_image_pro_flash (full image, no_background=False — a scene,
not an object), 3 seed variants, style ref = real Eastward night
crop (`ew_cutin_night256`, extracted from eastward_trailer_night.jpg:
deep blue-purple vignette + saturated warm glow pool — the exact
cook-moment grade).

Palette lesson applied: NO palette= at gen time and NO v4 ramp lock —
the cut-in is baked night art; v4 is a day-world ramp with no deep-
night family (snapping would strip the vignette).  Internal cohesion
comes from the style ref + prompt.

Usage:
  python tools/batch_f_cutin.py fire [seed ...]   # default 3 seeds
  python tools/batch_f_cutin.py poll              # resolve + download
  python tools/batch_f_cutin.py sheet             # candidate sheet
  python tools/batch_f_cutin.py pick <seed>       # stage winner
"""
import json, os, re, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from batch_d1_items import harness  # noqa: E402

GEN = os.path.join(ROOT, "assets_src", "gen", "f")
STG = os.path.join(ROOT, "game", "assets", "pinewatch", "fx")
STATE = os.path.join(ROOT, "tools", "batch_f_state.json")
EW_REF = "upload:71868f95-c1a2-4047-ba5d-1a43fa3762d7"  # trailer_night crop

BLOCK = ("painterly pixel art night scene in the style of Eastward, "
         "wide cinematic close-up of a campfire cooking station: a "
         "blackened wok on three fitted stones over low flames, "
         "glowing embers, thin steam rising, warm firelight pooling "
         "on the ground and fading into a deep blue-purple night "
         "vignette at the edges, scattered pots and a ladle at the "
         "sides, chunky hue-shifted colour ramps, thin adaptive dark "
         "coloured outlines, calm centre for the cooking pot with "
         "texture detail at the edges, no people, no animals, "
         "no text")


def load_state():
    return json.load(open(STATE)) if os.path.exists(STATE) else {}


def save_state(st):
    json.dump(st, open(STATE, "w"), indent=1)


def _dl(url, path):
    subprocess.run([sys.executable, "tools/pixellab_mcp.py",
                    "--get", url, path], check=True, cwd=ROOT)


def fire(seeds):
    st = load_state()
    for seed in seeds:
        key = "cutin_s%d" % seed
        if key in st:
            print("skip", key)
            continue
        args = {"description": BLOCK,
                "width": 256, "height": 128, "no_background": False,
                "seed": seed,
                "style_image": {"url": EW_REF,
                    "usage_description":
                    "copy the night vignette grade, warm firelight "
                    "pool, outline weight and painterly texture "
                    "density; do not copy the composition or palette"},
                "style_options": {"color_palette": False,
                    "outline": True, "detail": True, "shading": True}}
        out = harness("create_image_pro_flash", args)
        m = re.search(r'[0-9a-f]{8}-[0-9a-f-]{27,}', out)
        if "error" in out.lower() or not m:
            st[key] = {"error": out[:300]}
            print("FAIL", key, out[:200])
        else:
            st[key] = {"job": m.group(0), "seed": seed}
            print("fired", key, m.group(0)[:8])
        save_state(st)
        time.sleep(1)


def poll():
    st = load_state()
    for key, ent in st.items():
        if ent.get("done") or not ent.get("job"):
            continue
        txt = harness("get_image", {"job_id": ent["job"]})
        if "status: completed" in txt or "image_url" in txt:
            url = re.search(r'download: (https://\S+)', txt) or \
                re.search(r'https://\S+?\.png', txt)
            if url:
                os.makedirs(GEN, exist_ok=True)
                path = os.path.join(GEN, key + ".png")
                _dl(url.group(1) if url.lastindex else
                    url.group(0), path)
                ent["file"] = path
            ent["done"] = True
            print(key, "done")
        elif "status: failed" in txt:
            ent["failed"] = txt[:200]
            print(key, "FAILED")
        else:
            print(key, "pending")
        save_state(st)


def sheet():
    from PIL import Image
    st = load_state()
    imgs = [(k, Image.open(v["file"])) for k, v in sorted(st.items())
            if v.get("file") and os.path.exists(v["file"])]
    if not imgs:
        print("nothing finished"); return
    sh = Image.new("RGB", (512, 256 * len(imgs)), (30, 28, 34))
    for i, (k, im) in enumerate(imgs):
        sh.paste(im.convert("RGB").resize((512, 256), Image.NEAREST),
                 (0, i * 256))
    out = os.path.join(ROOT, "assets_src", "cleanup",
                       "_batch_f_sheet.png")
    sh.save(out)
    print("sheet ->", out)


def pick(seed):
    st = load_state()
    src = st["cutin_s%d" % int(seed)]["file"]
    os.makedirs(STG, exist_ok=True)
    dst = os.path.join(STG, "cutin_campfire_cook.png")
    from PIL import Image
    Image.open(src).save(dst)
    print("staged", dst)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "poll"
    if cmd == "fire":
        fire([int(s) for s in sys.argv[2:]] or [1, 2, 3])
    elif cmd == "poll":
        poll()
    elif cmd == "sheet":
        sheet()
    elif cmd == "pick":
        pick(sys.argv[2])
