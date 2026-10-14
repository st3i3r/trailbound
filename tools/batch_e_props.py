#!/usr/bin/env python3
"""Batch E — decor/gear world props via create_object_pro_flash
(the proven Eastward-craft path — the create_1_direction_object
review packs came back soft-shaded/off-palette; dismissed).

Per item: fire -> poll -> download raw -> alpha-bbox gate ->
tb_grade --site pinewatch_v2 --kind prop -> palette_lock --ramp
site_palette_v4 -> stage to game/assets/pinewatch/<cat>/<name>.png.

Style refs are GRADED+v4 props of the same canvas size (the ref
locks figure scale — D2 lesson), palette comes from the v4 lock.

  python tools/batch_e_props.py fire [names...]
  python tools/batch_e_props.py poll
  python tools/batch_e_props.py finish
"""
import json, os, re, subprocess, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from batch_d1_items import harness, _upload, _bbox  # noqa


def _normalize_prop(path):
    """World-prop normalize: fit the figure into (canvas - margin)
    and anchor its BOTTOM edge to the canvas floor — the engine
    grounds props by bottom-centre, so centre-pasting would float
    the object.  Margin = canvas//16 (64->4px, 128->8px)."""
    from PIL import Image
    im = Image.open(path).convert("RGBA")
    box = im.getchannel("A").getbbox()
    if not box:
        return
    fig = im.crop(box)
    fw, fh = fig.size
    cw, ch = im.size
    m = max(2, ch // 16)
    bw, bh = cw - 2 * m, ch - m
    s = min(1.0, float(bw) / fw, float(bh) / fh)
    if s < 1.0:
        nw, nh = max(1, round(fw * s)), max(1, round(fh * s))
        fig = fig.resize((nw, nh), Image.NEAREST)
        fw, fh = nw, nh
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(fig, ((cw - fw) // 2, ch - fh - max(0, m // 4)))
    out.save(path)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(ROOT, "assets_src", "gen", "e")
STG = os.path.join(ROOT, "game", "assets", "pinewatch")
V4 = os.path.join(ROOT, "assets_src", "out", "site_palette_v4.json")
STATE = os.path.join(ROOT, "tools", "batch_e_state.json")

# Craft grammar = the char/icon recipe (real Eastward ref anchors
# the style; palette comes from the v4 lock, NEVER a palette= gen
# param — forced palettes flatten to muted fills).  Prop flavour:
# PROMPT_PACK "hand-painted miniature density" + weathering, which
# is what the first batch-tool run lacked (clean flat fills).
BLOCK = ("painterly pixel art game prop in the style of Eastward, "
         "low top-down 3/4 view — hand-painted miniature density, "
         "chunky readable silhouette filling about 80% of the canvas, "
         "full value range: warm upper-left lit top and front faces, "
         "deep warm-brown shadow masses on the cool side, hue-shifted "
         "colour ramps, thin adaptive dark coloured outline (never "
         "pure black), weathered surface with light wear — scuffs, "
         "dirt splash, a knot or patch — calm interior masses with "
         "texture detail concentrated at the silhouette, one "
         "signature saturated accent, contemporary camping gear — "
         "single object centred on a transparent background, "
         "no cast shadow, no ground patch, no rim light, no glow, "
         "no text — ")

# name -> (category, canvas, line)
JOBS = {
    # --- 64px props_medium ---
    "reed_screen": ("props_medium", 64,
        "woven reed privacy screen, tall woven grass panels on a bamboo frame"),
    "dog_bed": ("props_medium", 64,
        "woven rattan dog bed with a folded checked blanket inside"),
    "photo_wall": ("props_medium", 64,
        "wooden frame strung with a line of small blank pinned photos"),
    "scout_pennant": ("props_medium", 64,
        "triangular felt pennant flag on a wooden pole, plain emblem"),
    "reception_board": ("props_medium", 64,
        "wooden booking board with pegs and blank paper cards"),
    "stone_fire_pit": ("props_medium", 64,
        "fitted stone fire pit ring with an iron grill grate"),
    "woodpile": ("props_medium", 64,
        "neatly stacked firewood pile, cut log ends visible"),
    "bird_feeder": ("props_medium", 64,
        "small wooden bird feeder hanging from a bamboo post"),
    "picnic_umbrella": ("props_medium", 64,
        "olive canvas patio umbrella over a low table"),
    "water_jar": ("props_medium", 64,
        "large glazed ceramic water jar with a wooden ladle on top"),
    "bamboo_bench": ("props_medium", 64, "low bamboo slat bench"),
    "potted_flowers": ("props_medium", 64,
        "cluster of flowering plants in terracotta clay pots"),
    "herb_rack": ("props_medium", 64,
        "wooden rack with bunches of dried herbs hanging"),
    "kite_stake": ("props_medium", 64,
        "kite string tied to a ground stake, diamond kite flying"),
    "camp_cot": ("props_medium", 64,
        "folding camp cot with olive canvas bed"),
    "rain_barrel": ("props_medium", 64,
        "old wooden rain barrel with a brass tap"),
    # --- 128px props_large (2x1 decor + tier-ups) ---
    "flower_arch": ("props_large", 128,
        "wooden garden arch covered in pink bougainvillea flowers"),
    "koi_pond": ("props_large", 128,
        "small stone-rimmed garden pond, lily pads, orange koi fish"),
    "cook_shelter": ("props_large", 128,
        "open-sided thatched kitchen shelter on wooden posts, clay stove"),
    "outfitter_lodge": ("props_large", 128,
        "small timber camp shop, corrugated tin roof, wooden porch"),
}

_REFS = {}


# Style refs = REAL Eastward crops (assets_src/refs/grade/ew_prop_*)
# — the char/icon wins anchored on ew_saiga pixels; our own props
# are a copy-of-a-copy anchor.  Sizes match the target canvas (the
# ref locks figure scale — D2 lesson).
EW_REF = {64: "upload:7a03b064-c563-4043-aacd-68f79be599cb",
          128: "upload:eb9c106a-6058-44fd-89f7-da9cd04b2a31"}


def style_ref(canvas):
    return EW_REF[canvas]


def load_state():
    return json.load(open(STATE)) if os.path.exists(STATE) else {}


def save_state(s):
    json.dump(s, open(STATE, "w"), indent=1)


def fire(only=None):
    st = load_state()
    for name, (cat, size, line) in JOBS.items():
        if only and name not in only:
            continue
        ent = st.setdefault(name, {})
        if ent.get("object_id"):
            continue
        args = {"description": BLOCK + line, "name": name,
                "n_directions": 1, "width": size, "height": size,
                "view": "low top-down",
                "style_image": {"url": style_ref(size),
                                "usage_description":
                                    "match this pixel-art craft: "
                                    "outline weight, shading ramps, "
                                    "colour depth"},
                "style_options": {"color_palette": False,
                                  "outline": True, "shading": True,
                                  "detail": True}}
        out = harness("create_object_pro_flash", args)
        m = re.search(r'[0-9a-f]{8}-[0-9a-f-]{27,}', out)
        if "error" in out.lower() or not m:
            ent["error"] = out[:300]
            print("FAIL", name, out[:200])
        else:
            ent["job"] = m.group(0)
            print("fired", name, m.group(0)[:8])
        save_state(st)
        time.sleep(1)


def resolve(only=None):
    """list_objects newest-first; first name match wins."""
    st = load_state()
    out = harness("list_objects", {"limit": 50})
    lines = out.splitlines()
    for name in JOBS:
        if only and name not in only:
            continue
        ent = st.get(name)
        if not ent or ent.get("object_id") or not ent.get("job"):
            continue
        for ln in lines:
            if name in ln:
                m = re.search(r'[0-9a-f]{8}-[0-9a-f-]{27,}', ln)
                if m:
                    ent["object_id"] = m.group(0)
                    break
    save_state(st)


def poll(only=None):
    st = load_state()
    resolve(only)
    for name, ent in st.items():
        if only and name not in only:
            continue
        oid = ent.get("object_id")
        if not oid or ent.get("done"):
            continue
        txt = harness("get_object",
                      {"object_id": oid, "include_preview": False})
        if "status: completed" in txt or "download" in txt:
            ent["done"] = True
            url = re.search(r'https://\S+?\.png', txt)
            ent["url"] = url.group(0) if url else None
        elif "status: failed" in txt or "error" in txt.lower()[:200]:
            ent["failed"] = txt[:200]
        save_state(st)
        print(name, "done" if ent.get("done")
              else ("FAILED" if ent.get("failed") else "pending"))
    print("done:", sum(1 for e in st.values() if e.get("done")),
          "/", sum(1 for k in st if k in JOBS))


def finish(only=None):
    st = load_state()
    graded = os.path.join(GEN, "graded")
    if os.path.exists(graded):
        import shutil
        shutil.rmtree(graded)
    os.makedirs(graded)
    files = []
    for name, (cat, size, _l) in JOBS.items():
        if only and name not in only:
            continue
        ent = st.get(name)
        if not ent or not ent.get("done"):
            continue
        raw = os.path.join(GEN, name + ".png")
        if not os.path.exists(raw):
            if not ent.get("url"):
                continue
            subprocess.run([sys.executable, "tools/pixellab_mcp.py",
                            "--get", ent["url"], raw], check=True,
                           cwd=ROOT)
        g = os.path.join(graded, name + ".png")
        import shutil
        shutil.copy2(raw, g)
        _normalize_prop(g)
        files.append(g)
    if not files:
        print("nothing to finish")
        return
    subprocess.run([sys.executable, "tools/tb_grade.py", "--site",
                    "pinewatch_v2", "--target",
                    graded], check=True, cwd=ROOT)
    subprocess.run([sys.executable, "tools/palette_lock.py"] + files
                   + ["--ramp", V4], check=True, cwd=ROOT)
    import shutil
    for f in files:
        name = os.path.splitext(os.path.basename(f))[0]
        cat = JOBS[name][0]
        shutil.copy2(f, os.path.join(STG, cat, name + ".png"))
        print("staged", cat, name)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "poll"
    names = set(sys.argv[2:]) or None
    {"fire": fire, "poll": poll, "finish": finish,
     "resolve": resolve}[cmd](names)
