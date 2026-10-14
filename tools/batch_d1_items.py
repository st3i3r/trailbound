#!/usr/bin/env python3
"""Batch D1 — content icons (22 dishes + 17 ingredients + 9 keepsakes).

Pipeline: create_object_pro_flash (n_directions=1, 32x32, style ref =
fisher crop) -> download -> alpha-bbox gate (icon rules: figure
20-30px, >=1px margin from edges) -> tb_grade --kind char -> pooled
palette_lock (one shared ramp across the whole set) -> stage to
game/assets/pinewatch/icons/<file_id>.png + icons.json objects.

Usage:
    python tools/batch_d1_items.py pilot          # one dish first
    python tools/batch_d1_items.py fire           # the rest (cap-tolerant)
    python tools/batch_d1_items.py poll           # status sweep
    python tools/batch_d1_items.py finish [ids..] # download+gate+stage
"""
import json, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATE = os.path.join(ROOT, "tools", "batch_d1_state.json")
GENDIR = os.path.join(ROOT, "assets_src", "gen", "d1")
STAGE = os.path.join(ROOT, "game", "assets", "pinewatch", "icons")
ICONS_JSON = os.path.join(ROOT, "game", "data", "icons.json")
STYLE_REF = "upload:edf722ed-06ae-42c9-864a-601541f3a43a"  # 28x32 crop

BLOCK = ("painterly pixel art game icon in the style of Eastward — "
         "chunky readable silhouette filling about 80% of the canvas "
         "with a 2-3px margin all round, dark warm-brown coloured "
         "outline (never pure black), 2-3 tone shading with warm "
         "upper-left light and a cool shadow side, saturated colours, "
         "calm interior masses, single subject centred on a "
         "transparent background, no cast shadow, no ground patch, "
         "no rim light, no text — ")

JOBS = [
 # dishes (recipes.json)
 ("noodle_soup", "dish", "a bowl of beef noodle soup with herbs, lime wedge and a chili"),
 ("trail_stew", "dish", "a hearty vegetable stew in a small enamel camp pot, steam rising"),
 ("camp_mash", "dish", "lumpy grey-brown mash in a dented tin bowl with a spoon"),
 ("mushroom_skewers", "dish", "two grilled mushroom skewers on bamboo sticks"),
 ("herb_tea", "dish", "green herbal tea in a small clay cup with a mint sprig"),
 ("berry_tea", "dish", "pink berry tea in a glass with floating berries"),
 ("smores", "dish", "toasted marshmallow s'mores on a small tin plate"),
 ("trail_sandwich", "dish", "a crusty baguette sandwich with pickled carrot and herbs"),
 ("goldcap_skillet", "dish", "golden mushrooms sizzling in a small cast-iron skillet"),
 ("grilled_fish", "dish", "a whole grilled fish on a banana leaf with a lime wedge"),
 ("iced_coffee", "dish", "iced coffee with condensed milk, a drip filter on top of the glass"),
 ("com_nam", "dish", "triangle rice balls with sesame salt on a banana leaf"),
 ("goi_cuon", "dish", "fresh spring rolls in translucent rice paper with shrimp and herbs, small dipping sauce"),
 ("che", "dish", "layered sweet bean dessert in a tall glass with coconut cream"),
 ("sinh_to", "dish", "mango-avocado smoothie in a glass with a straw"),
 ("ca_phe_trung", "dish", "Vietnamese egg coffee in a small cup standing in a bowl of hot water"),
 ("tra_mat_ong", "dish", "honey tea in a glass mug with a lemon slice"),
 ("ca_kho", "dish", "caramelised braised fish in a small clay pot, glossy dark sauce"),
 ("mi_quang", "dish", "turmeric-yellow noodles in a shallow bowl with shrimp, peanuts and a rice cracker"),
 ("berry_pie", "dish", "a lattice berry pie slice on a small plate"),
 ("honey_cakes", "dish", "a stack of small honey cakes drizzled with honey"),
 ("caramel_custard", "dish", "caramel custard with dark caramel on a small plate"),
 # ingredients (ingredients.json)
 ("mushroom", "ing", "a cluster of brown wild mushrooms"),
 ("herb", "ing", "a tied bundle of fresh green herbs"),
 ("berries", "ing", "a handful of red berries"),
 ("goldcap", "ing", "a single golden mushroom"),
 ("honey", "ing", "a honey jar with a wooden dipper"),
 ("perch", "ing", "a small silver perch fish"),
 ("carp", "ing", "a plump carp fish"),
 ("trout", "ing", "a speckled trout fish"),
 ("catfish", "ing", "a whiskered catfish"),
 ("bread", "ing", "a crusty baguette"),
 ("rice", "ing", "a small bowl of uncooked white rice"),
 ("eggs", "ing", "three brown eggs"),
 ("tea", "ing", "a tin of loose tea leaves"),
 ("marshmallow", "ing", "a bag of white marshmallows"),
 ("noodles", "ing", "a bundle of dried rice noodles"),
 ("coffee", "ing", "a small bag of coffee beans"),
 ("sweet_milk", "ing", "a tin of condensed milk"),
 # keepsakes (crew.json)
 ("grandpas_thermos", "keep", "a dented green enamel thermos"),
 ("old_trail_register", "keep", "a worn cloth-bound ledger book"),
 ("photo_on_the_porch", "keep", "an old photo in a wooden frame, sepia, faces blurred"),
 ("carved_oar", "keep", "a small carved wooden oar with etched marks"),
 ("river_chart", "keep", "a rolled hand-drawn river chart tied with string"),
 ("old_bas_boat", "keep", "a small wooden rowboat model"),
 ("bamboo_frames", "keep", "bamboo lantern frames with rice paper"),
 ("pattern_book", "keep", "a battered pattern book with a fabric bookmark"),
 ("unfinished_lantern", "keep", "a half-finished silk lantern"),
]

FILE_ID = {}  # key -> icon filename stem
for k, kind, _l in JOBS:
    FILE_ID[k] = {"dish": "dish_%s", "ing": "ing_%s",
                  "keep": "%s"}[kind] % (k if kind != "keep" else k)

HERO_KEYS = [k for k, kind, _l in JOBS if kind in ("dish", "keep")]

HERO_BLOCK = ("painterly pixel art game illustration in the style "
              "of Eastward — chunky readable silhouette filling "
              "about 85% of the canvas with a 4-5px margin all "
              "round, dark warm-brown coloured outline (never pure "
              "black), 2-3 tone shading with warm upper-left light "
              "and a cool shadow side, saturated colours, rich "
              "interior texture and garnish detail suited to the "
              "larger canvas, single subject centred on a "
              "transparent background, no cast shadow, no ground "
              "patch, no rim light, no text — ")


def _upload(path):
    url = harness("get_upload_url", {})
    m = re.search(r'https://api\.pixellab\.ai/v2/uploads/\S+', url)
    if not m:
        sys.exit("no upload url in reply")
    r = subprocess.run(["curl", "-sS", "-F", "file=@" + path,
                        m.group(0)], capture_output=True, text=True,
                       cwd=ROOT)
    ref = json.loads(r.stdout).get("ref", "")
    if not ref:
        sys.exit("upload failed: " + r.stdout[:300])
    return ref


def fire_hero(only=None):
    """D2: 64x64 heroes for dishes + keepsakes. Fresh gen with the
    craft ref — NOTE: using the D1 icon as style_image locks the
    figure to 32px inside the 64px canvas (verified hero_noodle_
    soup pilot); palette consistency comes from the pooled lock."""
    st = load_state()
    for key in HERO_KEYS:
        if only and key not in only:
            continue
        ent = st.setdefault("hero_" + key, {})
        if ent.get("object_id"):
            continue
        line = next(l for k, _t, l in JOBS if k == key)
        args = {"description": HERO_BLOCK + line, "name": "hero_" + key,
                "n_directions": 1, "width": 64, "height": 64,
                "view": "low top-down",
                "style_image": {"url": STYLE_REF,
                                "usage_description":
                                    "match this pixel-art craft: "
                                    "outline weight, shading ramps, "
                                    "colour depth"},
                "style_options": {"color_palette": False,
                                  "outline": True, "shading": True,
                                  "detail": True}}
        try:
            out = harness("create_object_pro_flash", args)
        except SystemExit as e:
            if "concurrent" in str(e).lower():
                print("cap reached — rerun fire_hero after finish")
                return
            raise
        m = re.search(
            r"\b[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\b", out)
        ent["object_id"] = m.group(0) if m else ""
        save_state(st)
        print("fired hero_" + key, ent["object_id"])


def harness(tool, args, extra=None):
    cmd = [sys.executable, "tools/pixellab_mcp.py", tool,
           json.dumps(args)]
    if extra:
        cmd += extra
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT)
    out = (r.stdout or "") + (r.stderr or "")
    if r.returncode != 0:
        sys.exit("%s failed:\n%s" % (tool, out))
    return out


def load_state():
    return json.load(open(STATE)) if os.path.exists(STATE) else {}


def save_state(st):
    json.dump(st, open(STATE, "w"), indent=1)


def fire(only=None):
    st = load_state()
    for key, kind, line in JOBS:
        if only and key not in only:
            continue
        if st.get(key, {}).get("object_id"):
            continue
        args = {"description": BLOCK + line, "name": key,
                "n_directions": 1, "width": 32, "height": 32,
                "view": "low top-down",
                "style_image": {"url": STYLE_REF,
                                "usage_description":
                                    "match this pixel-art craft: "
                                    "outline weight, shading ramps, "
                                    "colour depth"},
                "style_options": {"color_palette": False,
                                  "outline": True, "shading": True,
                                  "detail": False}}
        try:
            out = harness("create_object_pro_flash", args)
        except SystemExit as e:
            if "concurrent" in str(e).lower():
                print("cap reached — rerun fire() after jobs finish")
                return
            raise
        oid = ""
        m = re.search(r"\b[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\b",
                      out)
        if m:
            oid = m.group(0)
        st[key] = {"object_id": oid, "kind": kind}
        save_state(st)
        print("fired", key, oid)


def resolve():
    """Match each fired key to its real object_id by name via
    list_objects — the fire reply's first uuid is the job id."""
    st = load_state()
    out = harness("list_objects", {"limit": 50})
    for ln in out.splitlines():
        m = re.match(r"\s*([0-9a-f-]{36})\s*\|\s*(\S+)", ln)
        if not m:
            continue
        oid, name = m.group(1), m.group(2)
        if name in st and st[name].get("object_id") != oid:
            st[name]["object_id"] = oid
    save_state(st)


def poll():
    resolve()
    st = load_state()
    for key, ent in st.items():
        if not ent.get("object_id"):
            continue
        try:
            out = harness("get_object", {"object_id": ent["object_id"]})
        except SystemExit:
            print("%-22s error" % key)
            continue
        status = ""
        for ln in out.splitlines():
            if ln.startswith("status:"):
                status = ln.split(":", 1)[1].strip()
        print("%-22s %s" % (key, status or out.splitlines()[0][:60]))


def _normalize(path):
    """Fit the figure inside the canvas-2 margin box (32px icon ->
    30px box, 64px hero -> 60px box), centred, nearest."""
    from PIL import Image
    im = Image.open(path).convert("RGBA")
    box = im.getchannel("A").getbbox()
    if not box:
        return
    fig = im.crop(box)
    fw, fh = fig.size
    cw, ch = im.size
    m = 2 if ch == 64 else 1
    bw, bh = cw - 2 * m, ch - 2 * m
    if fw <= bw and fh <= bh and box[0] >= m and box[1] >= m \
            and box[2] <= cw - m and box[3] <= ch - m:
        return
    s = min(float(bw) / fw, float(bh) / fh)
    nw, nh = max(1, round(fw * s)), max(1, round(fh * s))
    fig = fig.resize((nw, nh), Image.NEAREST)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(fig, ((cw - nw) // 2, (ch - nh) // 2))
    out.save(path)


def _bbox(path):
    import png as pngmod
    w, h, rows = pngmod.read(path)
    xs, ys = [], []
    for y in range(h):
        for x in range(w):
            if rows[y][x * 4 + 3] >= 128:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return (min(xs), max(xs), min(ys), max(ys))


def _gate(key, path):
    import png as pngmod
    w, h, _rows = pngmod.read(path)
    b = _bbox(path)
    if not b:
        print("  %s EMPTY" % key)
        return False
    fh = b[3] - b[2] + 1
    margin = min(b[0], b[2], w - 1 - b[1], h - 1 - b[3])
    # 32px icon: 20-30px figure, >=1px margin
    # 64px hero: 30-56px figure, >=2px margin — Eastward's dish reads
    # ~37px inside its medallion; the ring is chrome, the hero sits
    # inside it, and non-integer nearest-rescaling mushes edges
    lo, hi, mmin = (30, 56, 2) if h == 64 else (20, 30, 1)
    ok = lo <= fh <= hi and margin >= mmin
    print("  %-22s h=%dpx margin=%d %s" % (key, fh, margin,
          "ok" if ok else "FAIL"))
    return ok


def finish(keys=None):
    sys.path.insert(0, ROOT + "/tools")
    resolve()
    st = load_state()
    done = []
    for key, ent in st.items():
        if keys and key not in keys:
            continue
        oid = ent.get("object_id")
        if not oid:
            continue
        base = key[5:] if key.startswith("hero_") else key
        gendir = os.path.join(GENDIR, key)
        os.makedirs(gendir, exist_ok=True)
        raw = os.path.join(gendir, "%s.png" % key)
        if not os.path.exists(raw):
            out = harness("get_object", {"object_id": oid},
                          extra=["--save", gendir, "--prefix", key])
            saved = [f for f in os.listdir(gendir)
                     if f.endswith(".png")]
            if saved:
                os.rename(os.path.join(gendir, saved[0]), raw)
        if not os.path.exists(raw):
            print("  %s no png (still running?)" % key)
            continue
        _normalize(raw)
        if _gate(key, raw):
            done.append(raw)
    if not done:
        return
    # grade + pooled lock happen on a flat shared dir so the whole
    # set collapses onto one ramp (same as the cast batch pool)
    import shutil
    g2 = os.path.join(GENDIR, "_graded")
    if os.path.exists(g2):
        shutil.rmtree(g2)
    os.makedirs(g2)
    for raw in done:
        shutil.copy2(raw, g2)
    subprocess.run([sys.executable, "tools/tb_grade.py",
                    "--site", "pinewatch_v2", "--kind", "char",
                    "--target", g2], check=True, cwd=ROOT)
    files = [os.path.join(g2, f) for f in sorted(os.listdir(g2))
             if f.endswith(".png")]
    subprocess.run([sys.executable, "tools/palette_lock.py"]
                   + files + ["--colors", "48"], check=True, cwd=ROOT)
    for f in files:
        key = os.path.basename(f)[:-4]
        if key.startswith("hero_"):
            stem = FILE_ID[key[5:]] + "_hero"
        else:
            stem = FILE_ID[key]
        shutil.copy2(f, os.path.join(STAGE, stem + ".png"))
    print("staged %d icons -> %s" % (len(files), STAGE))
    _wire_icons_json()


def _wire_icons_json():
    d = json.load(open(ICONS_JSON))
    obj = d.setdefault("objects", {})
    n = 0
    for key, kind, _l in JOBS:
        fid = FILE_ID[key]
        if os.path.exists(os.path.join(STAGE, fid + ".png")) \
                and obj.get(key) != fid:
            obj[key] = fid
            n += 1
        hero = fid + "_hero"
        if kind in ("dish", "keep") and \
                os.path.exists(os.path.join(STAGE, hero + ".png")) \
                and obj.get(key + "_hero") != hero:
            obj[key + "_hero"] = hero
            n += 1
    json.dump(d, open(ICONS_JSON, "w"), indent=1, ensure_ascii=False)
    print("icons.json: %d mappings wired" % n)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "poll"
    if cmd == "pilot":
        fire({"noodle_soup"})
    elif cmd == "fire":
        fire(set(sys.argv[2:]) or None)
    elif cmd == "hero_pilot":
        fire_hero({"noodle_soup"})
    elif cmd == "fire_hero":
        fire_hero(set(sys.argv[2:]) or None)
    elif cmd == "poll":
        poll()
    elif cmd == "finish":
        finish(set(sys.argv[2:]) or None)
    elif cmd == "wire":
        _wire_icons_json()
