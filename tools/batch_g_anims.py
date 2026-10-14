#!/usr/bin/env python3
"""Batch G — per-persona animation clips (the sim's anim vocabulary).

Clips land as <key>_<anim>_<dir>_<i>.png in characters/<key>/ and the
actor_view contract picks them up automatically (idle loops,
distance-driven walk cycles, activity loops).

  template mode (animate_character, ~1 gen/dir):
    idle  — breathing-idle (humanoid) / idle (quadruped), south only
    walk  — walking-8-frames (humanoid) / walk-8-frames (quadruped),
            cardinals only; diagonals keep the _dir stills
  v3 custom (action_description, south only):
    fish/sit/play/pet/sniff — per-archetype activity loops

Frames are content-normalised onto the persona's still canvas
(bottom-center anchor = the _south still's foot point) then locked
to the persona ramp assets_src/palettes/chars/<key>.json.

Usage:
  python tools/batch_g_anims.py fire [key ...]     # default: all
  python tools/batch_g_anims.py fire --anim walk   # one clip only
  python tools/batch_g_anims.py poll               # resolve+download
  python tools/batch_g_anims.py finish [key ...]   # normalize+lock+stage
"""
import json, os, re, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from batch_d1_items import harness as _d1_harness  # noqa: E402


def harness(tool, args, extra=None):
    """Non-fatal harness — batch_d1's version sys.exit()s on any
    subprocess failure, which kills the fire/poll loop on a
    transient cap or network error.  Return the output instead and
    let callers decide (they check for 'error'/'failed')."""
    cmd = [sys.executable, "tools/pixellab_mcp.py", tool,
           json.dumps(args)]
    if extra:
        cmd += extra
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT)
    return (r.stdout or "") + (r.stderr or "")

B2 = os.path.join(ROOT, "tools", "batch_b2_state.json")
CHARS = os.path.join(ROOT, "game", "assets", "pinewatch", "characters")
RAMP = os.path.join(ROOT, "assets_src", "palettes", "chars")
GEN = os.path.join(ROOT, "assets_src", "gen", "g")
STATE = os.path.join(ROOT, "tools", "batch_g_state.json")

QUADS = {"bean", "border_collie"}
ANGLERS = {"angler_uncle", "grandpa_mu"}
KIDS = {"scout_kid", "kid_pinkdress", "grandma_ba"}
MOVERS = ANGLERS | KIDS | QUADS          # personas that actually path
CARD = ["south", "north", "east", "west"]

# clip -> per-persona v3 action line (movement only)
V3 = {
    "fish": "standing at the water edge holding a fishing rod, "
            "casting the line then holding it still, watching",
    "sit": "sitting on a low camping stool, relaxed gentle sway",
    "play": "bouncing and playing with energy, arms swinging",
    "pet": "kneeling down and reaching a hand out to pet a dog",
    "sniff": "sniffing the ground, nose low, tail wagging",
    "play_dog": "play bow — front down, rear up, tail wagging fast",
}


def jobs():
    out = []
    for key in sorted(load_b2()):
        quad = key in QUADS
        out.append((key, "idle", "template",
                    "idle" if quad else "breathing-idle",
                    ["south"], None))
        if key in MOVERS:
            out.append((key, "walk", "template",
                        "walk-8-frames" if quad else
                        "walking-8-frames", CARD, None))
        if key in ANGLERS:
            out.append((key, "fish", "v3", V3["fish"], ["south"], 8))
            out.append((key, "sit", "v3", V3["sit"], ["south"], 4))
        if key in KIDS:
            out.append((key, "play", "v3", V3["play"], ["south"], 6))
            out.append((key, "pet", "v3", V3["pet"], ["south"], 4))
        if key in QUADS:
            out.append((key, "sniff", "v3", V3["sniff"], ["south"], 6))
            out.append((key, "play", "v3", V3["play_dog"],
                        ["south"], 6))
    return out


def load_b2():
    return json.load(open(B2))


def load_state():
    return json.load(open(STATE)) if os.path.exists(STATE) else {}


def save_state(st):
    json.dump(st, open(STATE, "w"), indent=1)


def fire(only=None, anim=None):
    b2 = load_b2()
    st = load_state()
    for key, clip, mode, what, dirs, frames in jobs():
        if only and key not in only:
            continue
        if anim and clip != anim:
            continue
        jk = "%s/%s" % (key, clip)
        ent = st.setdefault(jk, {})
        if ent.get("fired"):
            continue
        args = {"character_id": b2[key]["character_id"],
                "directions": dirs,
                "animation_name": clip}
        if mode == "template":
            args["template_animation_id"] = what
        else:
            args["action_description"] = what
            args["frame_count"] = frames
        out = harness("animate_character", args)
        ent["reply"] = out[:400]
        if "error" in out.lower() or "failed" in out.lower():
            print("FAIL", jk, out[:160])
            save_state(st)
            break                      # slot cap — rerun when slots free
        ent["fired"] = True
        ent["want_dirs"] = dirs
        print("fired", jk)
        save_state(st)
        time.sleep(1)


def poll():
    """get_character -> animation groups; collect per-dir frame urls."""
    b2 = load_b2()
    st = load_state()
    for key in sorted(b2):
        need = [jk for jk in st if jk.startswith(key + "/")
                and st[jk].get("fired") and not st[jk].get("done")]
        if not need:
            continue
        txt = harness("get_character",
                      {"character_id": b2[key]["character_id"]})
        # parse animation sections: "name — N dir (...), Mf ... [group: id]"
        # the em-dash separator arrives cp1252-mangled — match the
        # shape, not the dash:  "<name> <junk> N dir ... [group: id]"
        for m in re.finditer(
                r"^\s+(\w[\w-]*)[^\n=]*?(\d+)\s*dir[^\n]*?"
                r"\[group:\s*([0-9a-f-]+)\]\s*\n((?:\s+\S+:.*\n?)*)",
                txt, re.M):
            aname = m.group(1).strip()
            for dm in re.finditer(
                    r"(\w[\w-]*):\s*(https://\S+)", m.group(4)):
                dname, url = dm.group(1), dm.group(2)
                jk = "%s/%s" % (key, aname)
                if jk not in st:
                    continue
                ent = st[jk]
                ent.setdefault("urls", {})[dname] = url
                save_state(st)
        for jk in need:
            ent = st[jk]
            want = len(ent.get("want_dirs") or ["south"])
            if ent.get("urls") and len(ent["urls"]) >= want:
                _download(key, jk, ent)
                ent["done"] = True
                print(jk, "done", list(ent["urls"]))
                save_state(st)


def _download(key, jk, ent):
    outdir = os.path.join(GEN, key, jk.split("/")[1])
    os.makedirs(outdir, exist_ok=True)
    for dname, url in ent["urls"].items():
        # url has {i} placeholder — probe frames 0..15 until 404
        if "{i}" in url:
            i = 0
            while True:
                dst = os.path.join(outdir, "%s_%d.png" % (dname, i))
                r = subprocess.run(
                    [sys.executable, "tools/pixellab_mcp.py", "--get",
                     url.replace("{i}", str(i)), dst],
                    cwd=ROOT, capture_output=True)
                if r.returncode != 0 or not os.path.exists(dst) \
                        or os.path.getsize(dst) < 200:
                    if os.path.exists(dst):
                        os.remove(dst)
                    break
                i += 1
        else:
            subprocess.run([sys.executable, "tools/pixellab_mcp.py",
                            "--get", url,
                            os.path.join(outdir, dname + ".png")],
                           cwd=ROOT, capture_output=True)


def _norm_frames(key, clip):
    """Anchor clip frames to the still's foot point on its canvas."""
    from PIL import Image
    base = os.path.join(GEN, key, clip)
    still = os.path.join(CHARS, key, "%s_south.png" % key)
    sim = Image.open(still).convert("RGBA")
    sb = sim.getbbox()
    foot = (int((sb[0] + sb[2]) / 2), sb[3])      # still's bottom-center
    frames = sorted(f for f in os.listdir(base)
                    if f.endswith(".png")
                    and "_" in f[:-4]
                    and f[:-4].rsplit("_", 1)[1].isdigit())
    outdir = os.path.join(base, "_staged")
    os.makedirs(outdir, exist_ok=True)
    outs = []
    for f in frames:
        im = Image.open(os.path.join(base, f)).convert("RGBA")
        b = im.getbbox()
        if not b:
            continue
        cx, fy = int((b[0] + b[2]) / 2), b[3]
        # paste onto the still-size canvas; grow only if content spills
        canvas = Image.new("RGBA", sim.size, (0, 0, 0, 0))
        canvas.paste(im, (foot[0] - cx, foot[1] - fy))
        canvas.save(os.path.join(outdir, f))
        outs.append(os.path.join(outdir, f))
    return outs


def finish(only=None):
    st = load_state()
    for jk, ent in st.items():
        key, clip = jk.split("/")
        if only and key not in only:
            continue
        if not ent.get("done") or ent.get("staged"):
            continue
        files = _norm_frames(key, clip)
        if not files:
            continue
        ramp = os.path.join(RAMP, key + ".json")
        if os.path.exists(ramp):
            subprocess.run([sys.executable, "tools/palette_lock.py"]
                           + files + ["--ramp", ramp],
                           check=True, cwd=ROOT)
        for f in files:
            # <dir>_<i>.png -> <key>_<clip>_<dir>_<i>.png
            dn = os.path.splitext(os.path.basename(f))[0]
            if "_" not in dn:
                continue
            dname, i = dn.rsplit("_", 1)
            if not i.isdigit():
                continue
            dst = os.path.join(CHARS, key,
                               "%s_%s_%s_%s.png" % (key, clip, dname, i))
            import shutil
            shutil.copy2(f, dst)
        ent["staged"] = True
        print("staged", jk, len(files), "frames")
        save_state(st)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "poll"
    args = sys.argv[2:]
    anim = None
    if "--anim" in args:
        i = args.index("--anim")
        anim = args[i + 1]
        args = args[:i] + args[i + 2:]
    only = set(args) or None
    if cmd == "fire":
        fire(only, anim)
    elif cmd == "poll":
        poll()
    elif cmd == "finish":
        finish(only)
