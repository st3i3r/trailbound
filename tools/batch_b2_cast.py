#!/usr/bin/env python3
"""Batch B2 — D4.1 actor cast (PROMPT_PACK.md B2).

Fires create_character_pro_flash for the 12-persona cast keyed to
game/data/actors.json, then polls each character to completion and
downloads the 8-direction stills to assets_src/cast/<key>/.

Usage:
  python tools/batch_b2_cast.py fire           # submit all 12 jobs
  python tools/batch_b2_cast.py poll           # poll + download stills
  python tools/batch_b2_cast.py                # fire + poll in one go

State lives in tools/batch_b2_state.json — re-running `fire` skips
keys already submitted (idempotent; jobs cost real gens).
Style ref: the Octopia fisher crop uploaded as upload:<id> — renew
via pixellab_mcp.py get_upload_url + curl if it expired (>3 days).
"""
import json, os, re, shutil, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MCP = os.path.join(ROOT, "tools", "pixellab_mcp.py")
STATE = os.path.join(ROOT, "tools", "batch_b2_state.json")
OUT = os.path.join(ROOT, "assets_src", "cast")

STYLE_REF = "upload:15b2fa7d-2b49-4294-8226-324b800c515f"
BLOCK = ("painterly pixel art character in the style of Eastward, low "
         "top-down 3/4 view with the front drawn straight-on — chunky "
         "readable silhouette about 3.5-4 head-lengths tall filling "
         "about 90% of the canvas height, full value range with a "
         "warm upper-left lit side and a cool shadow side, "
         "hue-shifted colour ramps, adaptive dark coloured outline "
         "(never pure black), calm interior masses with detail "
         "concentrated at the silhouette, one signature colour or "
         "prop, relaxed standing pose facing south, warm friendly "
         "expression, contemporary everyday clothes of the 2020s — "
         "single subject centred on a transparent background, "
         "neutral midday light, no cast shadow, no ground patch, "
         "no rim light, no glow, no dusk tones, no text. ")
# Quadrupeds share the craft rules but NOT the human fill spec —
# 90%-fill makes a dog adult-tall (the bean run proved it: 43px vs
# the 28-36px gate). Dog = compact body ~65% of canvas height.
BLOCK_DOG = ("painterly pixel art dog in the style of Eastward, low "
         "top-down 3/4 view with the front drawn straight-on — "
         "compact chunky body filling about 65% of the canvas height, "
         "four short legs, full value range with a warm upper-left "
         "lit side and a cool shadow side, hue-shifted colour ramps, "
         "adaptive dark coloured outline (never pure black), calm "
         "interior masses with detail concentrated at the silhouette, "
         "alert standing pose facing south, friendly expression — "
         "single subject centred on a transparent background, "
         "neutral midday light, no cast shadow, no ground patch, "
         "no rim light, no glow, no dusk tones, no text. ")
# Kids: ~3 head-lengths, ~68% of canvas height — the shared 90% fill
# produced adult-sized kids (scout_kid/pinkdress failed the gate).
BLOCK_KID = ("painterly pixel art small child in the style of "
         "Eastward, low top-down 3/4 view with the front drawn "
         "straight-on — chunky readable silhouette about 3 "
         "head-lengths tall filling about 68% of the canvas height, "
         "big head small body proportions, full value range with a "
         "warm upper-left lit side and a cool shadow side, "
         "hue-shifted colour ramps, adaptive dark coloured outline "
         "(never pure black), calm interior masses, one signature "
         "colour or prop, standing pose facing south, cheerful "
         "expression — single subject centred on a transparent "
         "background, neutral midday light, no cast shadow, no "
         "ground patch, no rim light, no glow, no dusk tones, "
         "no text. ")

JOBS = [
    # key, persona line, template
    ("warden", "young trail warden, forest-green hoodie with sleeves "
     "pushed up, khaki shorts, sturdy boots, small tan backpack, "
     "short black hair, friendly face", "mannequin"),
    ("ranger_mai", "cheerful park ranger woman, olive ranger shirt "
     "with a small badge, khaki trousers, conical palm-leaf hat, "
     "long black hair in a low ponytail, clipboard", "mannequin"),
    ("bean", "scruffy tan village stray dog, perky ears, curled tail, "
     "red collar with a small brass tag", "dog"),
    ("backpacker_woman", "sun-tanned traveller woman, braided hair, "
     "big travel pack, hiking sandals, rolled trousers", "mannequin"),
    ("scout_kid", "young scout kid, khaki shirt, red scarf, big "
     "backpack, shorts — a child about three quarters adult height",
     "mannequin"),
    ("aodai_woman", "young woman in a flowing pastel áo dài with "
     "white trousers, straw hat held in hand", "mannequin"),
    ("kid_pinkdress", "small girl in a pink dress holding a paper "
     "pinwheel — a child about three quarters adult height",
     "mannequin"),
    ("phuot_rider", "motorbike road-tripper, bandana, sunglasses "
     "pushed up, cargo vest, fingerless gloves, dusty boots",
     "mannequin"),
    ("backpacker_man", "bearded traveller, linen shirt, ukulele on "
     "his back, big travel pack, hiking sandals", "mannequin"),
    ("angler_uncle", "middle-aged angler, fishing vest with tackle "
     "pockets, bucket hat, folding stool and bamboo rod",
     "mannequin"),
    ("bird_uncle", "retired uncle, safari vest, wide-brim hat, huge "
     "telephoto lens on a strap", "mannequin"),
    ("cyclist", "road cyclist, bright colourblock jersey, helmet, "
     "cycling glasses, fingerless gloves, water bottle", "mannequin"),
    ("food_vlogger", "stylish food vlogger, sunglasses, pastel "
     "blazer over a tee, phone on a gimbal, one gold accessory",
     "mannequin"),
    # -- Vietnamese daily-life pass (D4.1a): different generations,
    # not everyone in camping kit. Same craft block + scale spec.
    ("grandma_ba", "elderly Vietnamese grandmother, muted mauve "
     "áo bà ba blouse and dark trousers, grey hair in a low bun, "
     "conical palm hat held at her side, gentle lined face",
     "mannequin"),
    ("grandpa_mu", "elderly Vietnamese grandfather, khaki button "
     "shirt tucked in, dark trousers, rubber sandals, pith helmet, "
     "thin grey hair, kind weathered face", "mannequin"),
    ("auntie_dobo", "cheerful middle-aged Vietnamese auntie, "
     "colourful floral đồ bộ home outfit, headscarf tied at the "
     "nape, rubber sandals, round friendly face", "mannequin"),
    ("uncle_deptong", "relaxed middle-aged Vietnamese uncle, white "
     "singlet, dark shorts, slight belly, dép tông rubber sandals, "
     "small thermos cup in hand", "mannequin"),
    ("sunhood_woman", "young Vietnamese woman in a pastel-blue "
     "full sun-protection jacket with the hood up, dark leggings, "
     "sneakers, canvas tote bag", "mannequin"),
    ("teen_jersey", "Vietnamese teenage boy, red football jersey "
     "with gold trim, black shorts, sneakers, short black hair, "
     "eager grin", "mannequin"),
    ("student_bucket", "Vietnamese gen-Z student girl, oversized "
     "cream tee, light jeans, bucket hat, canvas tote bag, phone "
     "in hand", "mannequin"),
    ("vendor_ganh", "Vietnamese street vendor woman, conical palm "
     "hat, plain khaki blouse, dark trousers rolled at the ankle, "
     "shoulder yoke with two woven baskets", "mannequin"),
]


def harness(tool, args, extra=None):
    r = subprocess.run(
        [sys.executable, MCP, tool, json.dumps(args)] + (extra or []),
        capture_output=True, text=True, cwd=ROOT)
    if r.returncode != 0:
        sys.exit(f"{tool} failed:\n{r.stdout}\n{r.stderr}")
    return r.stdout


def load_state():
    return json.load(open(STATE)) if os.path.exists(STATE) else {}


def save_state(st):
    json.dump(st, open(STATE, "w"), indent=1)


# -- two-stage kid pipeline (D4.1) ------------------------------------------
# The mannequin template anchors figure height to canvas fill — age
# words can't shrink it (two failed refires proved that). The model
# fills ~90% of ANY canvas, so a 32px canvas produces a true ~30px
# child with real big-head proportions; then create_character v3
# rotates that exact sprite into 8 directions (identity preserved).
KID_STYLE_REF = "upload:edf722ed-06ae-42c9-864a-601541f3a43a"
JOB_LINES = {k: line for k, line, _t in JOBS}


def _upload(path):
    url = harness("get_upload_url", {})
    m = re.search(r'https://api\.pixellab\.ai/v2/uploads/\S+', url)
    if not m:
        sys.exit("no upload url in reply")
    r = subprocess.run(["curl", "-sS", "-F", "file=@" + path, m.group(0)],
                       capture_output=True, text=True, cwd=ROOT)
    ref = json.loads(r.stdout).get("ref", "")
    if not ref:
        sys.exit("upload failed: " + r.stdout[:300])
    return ref


def fire_kid(key):
    """Gen a 32x32 south kid sprite, v3-rotate it into 8 dirs."""
    if key not in JOB_LINES:
        sys.exit("no job line for " + key)
    gendir = os.path.join(GENDIR, key)
    os.makedirs(gendir, exist_ok=True)
    sprite = os.path.join(gendir, key + "_src.png")
    if not os.path.exists(sprite):
        args = {"description": BLOCK_KID + JOB_LINES[key],
                "width": 32, "height": 32, "no_background": True,
                "style_image": {"url": KID_STYLE_REF,
                                "usage_description":
                                    "match this Eastward pixel-art "
                                    "craft: outline weight, shading "
                                    "ramps, colour depth"},
                "style_options": {"color_palette": False,
                                  "outline": True, "shading": True,
                                  "detail": False}}
        out = harness("create_image_pro_flash", args,
                      extra=["--poll", "get_image", "job_id",
                             "--save", gendir, "--prefix", key + "_src"])
        print(out[-600:])
        got = [f for f in os.listdir(gendir)
               if f.startswith(key + "_src") and f.endswith(".png")]
        if not got:
            sys.exit("kid sprite did not save: " + out[-300:])
        os.rename(os.path.join(gendir, got[0]), sprite)
    ref = _upload(sprite)
    st = load_state()
    out = harness("create_character", {
        "description": "rotate this exact child sprite into 8 "
            "directions — keep the proportions, outfit and colours",
        "name": key, "mode": "v3", "n_directions": 8,
        "reference_image_url": ref})
    cid = ""
    for tok in out.replace("\n", " ").split(" "):
        t = tok.strip(".,'\"")
        if len(t) == 36 and t.count("-") == 4:
            cid = t
            break
    st[key] = {"character_id": cid, "template": "kid_v3"}
    save_state(st)
    print(key, "->", cid)


def fire():
    st = load_state()
    for key, line, tmpl in JOBS:
        if key in st:
            print(f"skip {key} (already {st[key]})")
            continue
        block = (BLOCK_DOG if tmpl == "dog"
                 else BLOCK_KID if key in GATE_KIND and
                 GATE_KIND[key] == "kid" else BLOCK)
        args = {"description": block + line,
                "name": key,
                "view": "low top-down",
                "template_id": tmpl,
                "n_directions": 8,
                "width": 48, "height": 48,
                "style_image": {"url": STYLE_REF,
                                "usage_description":
                                    "match this Eastward pixel-art "
                                    "craft: proportions, outline "
                                    "weight, shading ramps"},
                "style_options": {"color_palette": False,
                                  "outline": True,
                                  "shading": True,
                                  "detail": False}}
        try:
            out = harness("create_character_pro_flash", args)
        except SystemExit:
            # Tier-1 caps concurrent jobs at 8 — a capped create exits
            # the harness; skip this job, fire() reruns pick it up.
            print(f"--- {key} SKIPPED (concurrency cap or failure)")
            continue
        print(f"--- {key}\n{out[-400:]}")
        # character_id surfaces in the reply text — take the FIRST
        # uuid (the tail also carries the background-job id, which
        # get_character rejects: bean stored the job id once, "not
        # found" until re-keyed)
        cid = ""
        for tok in out.replace("\n", " ").split(" "):
            t = tok.strip(".,'\"")
            if len(t) == 36 and t.count("-") == 4:
                cid = t
                break
        st[key] = {"character_id": cid, "template": tmpl}
        save_state(st)
    print("fired:", list(st))


def poll():
    st = load_state()
    if not st:
        sys.exit("nothing submitted — run `fire` first")
    for key in st:
        cid = st[key].get("character_id", "")
        if not cid:
            print(f"{key}: no character_id captured — check reply")
            continue
        print(f"=== {key} ({cid}) ===")
        harness("get_character", {"character_id": cid})


# -- post-gen pipeline (PROMPT_PACK B2 gate) -------------------------------
# download -> alpha-bbox gate -> tb_grade --kind char -> palette_lock --ramp
# <persona> -> stage into game/assets/.../<key>/ as <key>_<dir>.png.
# Site-palette snap is NEVER run on chars.

GATE = {"adult": (40, 46), "kid": (30, 36), "dog": (28, 36)}
GATE_KIND = {"scout_kid": "kid", "kid_pinkdress": "kid",
             "teen_jersey": "kid", "bean": "dog",
             "border_collie": "dog"}
STAGE = os.path.join(ROOT, "game", "assets", "pinewatch", "characters")
GENDIR = os.path.join(ROOT, "assets_src", "gen", "b2")
CHARS_PAL = os.path.join(ROOT, "assets_src", "palettes", "chars")


def _bbox(png_path):
    import png as pngmod
    w, h, rows = pngmod.read(png_path)
    xs, ys = [], []
    for y in range(h):
        for x in range(w):
            if rows[y][x * 4 + 3] >= 128:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return (min(xs), max(xs), min(ys), max(ys))


def _gate(key, gendir):
    lo, hi = GATE[GATE_KIND.get(key, "adult")]
    ok = True
    for f in sorted(os.listdir(gendir)):
        if not f.endswith(".png") or f.startswith("_"):
            continue
        b = _bbox(os.path.join(gendir, f))
        if not b:
            print("  %s EMPTY" % f)
            ok = False
            continue
        fh = b[3] - b[2] + 1
        feet = b[3]
        import png as pngmod
        _w, ch, _r = pngmod.read(os.path.join(gendir, f))
        verdict = "ok" if lo <= fh <= hi and feet >= ch - 2 else "FAIL"
        if verdict == "FAIL":
            ok = False
        print("  %-24s h=%dpx y=%d-%d %s" % (f, fh, b[2], b[3], verdict))
    return ok


def finish(keys=None):
    sys.path.insert(0, ROOT + "/tools")
    st = load_state()
    for key in st:
        if keys and key not in keys:
            continue
        cid = st[key].get("character_id", "")
        if not cid:
            continue
        gendir = os.path.join(GENDIR, key)
        os.makedirs(gendir, exist_ok=True)
        # 1. download rotations (idempotent — skips if already 8 files)
        have = len([f for f in os.listdir(gendir)
                    if f.endswith(".png")]) if os.path.isdir(gendir) else 0
        if have < 8:
            out = harness("get_character", {"character_id": cid},
                          extra=["--save", gendir, "--prefix", key])
            print(out[-300:])
        print("=== %s bbox gate ===" % key)
        _gate(key, gendir)
        # 2. char grade + persona ramp, in a graded/ subdir
        g2 = os.path.join(gendir, "graded")
        os.makedirs(g2, exist_ok=True)
        for f in os.listdir(gendir):
            if f.endswith(".png"):
                shutil.copy2(os.path.join(gendir, f),
                             os.path.join(g2, f))
        subprocess.run([sys.executable, "tools/tb_grade.py",
                        "--site", "pinewatch_v2", "--kind", "char",
                        "--target", g2], check=True, cwd=ROOT)
        ramp = os.path.join(CHARS_PAL, key + ".json")
        if os.path.exists(ramp):
            files = [os.path.join(g2, f) for f in sorted(os.listdir(g2))
                     if f.endswith(".png")]
            subprocess.run([sys.executable, "tools/palette_lock.py"]
                           + files + ["--ramp", ramp],
                           check=True, cwd=ROOT)
        # 3. stage <key>_<dir>.png into the game tree
        dest = os.path.join(STAGE, key)
        os.makedirs(dest, exist_ok=True)
        for f in os.listdir(g2):
            m = re.match(re.escape(key) + r"_8_(.+)\.png$", f)
            if m:
                shutil.copy2(os.path.join(g2, f),
                             os.path.join(dest,
                                          "%s_%s.png" % (key, m.group(1))))
        print("  staged -> %s" % dest)


def rescale(key, target_h):
    """Deterministic bake-time correction for a persona that generated
    correct but a few px off-gate. Nearest-resizes the figure in each
    graded PNG and re-anchors feet to the canvas bottom. This is an
    explicit, logged post-process — never a runtime presenter fix."""
    from PIL import Image
    g2 = os.path.join(GENDIR, key, "graded")
    for f in sorted(os.listdir(g2)):
        if not f.endswith(".png") or f.startswith("_"):
            continue
        p = os.path.join(g2, f)
        im = Image.open(p).convert("RGBA")
        a = im.getchannel("A")
        box = a.getbbox()
        if not box:
            continue
        fig = im.crop(box)
        fh = box[3] - box[1]
        nh = target_h
        nw = max(1, round((box[2] - box[0]) * nh / fh))
        fig = fig.resize((nw, nh), Image.NEAREST)
        out = Image.new("RGBA", im.size, (0, 0, 0, 0))
        out.paste(fig, ((im.width - nw) // 2, im.height - nh))
        out.save(p)
        print("  %s %dpx -> %dpx" % (f, fh, nh))
    # restage
    dest = os.path.join(STAGE, key)
    os.makedirs(dest, exist_ok=True)
    for f in os.listdir(g2):
        m = re.match(re.escape(key) + r"_8_(.+)\.png$", f)
        if m:
            shutil.copy2(os.path.join(g2, f),
                         os.path.join(dest, "%s_%s.png" % (key, m.group(1))))
    print("  restaged -> %s" % dest)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "all"
    if cmd in ("fire", "all"):
        fire()
    if cmd in ("poll", "all"):
        poll()
    if cmd == "kid":
        fire_kid(sys.argv[2])
    if cmd == "rescale":
        rescale(sys.argv[2], int(sys.argv[3]))
    if cmd == "finish":
        finish(set(sys.argv[2:]) or None)
