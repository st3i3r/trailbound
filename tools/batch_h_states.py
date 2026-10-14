#!/usr/bin/env python3
"""Batch H — restoration & state sprites (Pinewatch v1).

Jobs were fired by hand (edit_image_pro_flash state edits off shipped
art; create_object_pro_flash for pad tiles). This driver polls,
downloads, locks to site_palette_v4 and stages:

  H1 cabin states   -> props_large/cabin_s{0,1,2}.png (restored=cabin)
  H2 pad tiles      -> decals/pad_overgrown_{a,b}.png, pad_cleared.png
  H3 night states   -> props_medium/dome_tent_*_night.png,
                       props_large/cabin_night.png,
                       props_medium/pallet_deck_occupied.png

  python tools/batch_h_states.py poll     # check all, download ready
  python tools/batch_h_states.py finish   # lock + stage downloaded
"""
import json, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from batch_g_anims import harness          # non-fatal variant

GEN = os.path.join(ROOT, "assets_src", "gen", "h")
RAMP = os.path.join(ROOT, "assets_src", "palettes", "site_palette_v4.json")
ASSETS = os.path.join(ROOT, "game", "assets", "pinewatch")
STATE = os.path.join(ROOT, "tools", "batch_h_state.json")

# job -> (job_kind, job_id, staged dest folder, staged name)
JOBS = {
    "cabin_s0":  ("img", "97cd3ded-23a7-4aaa-bdc6-c2d2253bc1a3",
                  "props_large"),
    "cabin_s1":  ("img", "a5bdf878-4096-41c6-a78a-5c378eb42ec5",
                  "props_large"),
    "cabin_s2":  ("img", "b423e47f-af1a-4f5e-a71c-fee52ead8bf7",
                  "props_large"),
    "pad_overgrown_a": ("obj", "118a6055-e7e1-4646-b527-b20a8c16d3fa",
                        "decals"),
    "pad_overgrown_b": ("obj", "3fd700ea-6279-47bf-b3a9-1e94e20497fa",
                        "decals"),
    "pad_cleared":     ("obj", "ba2fc2cc-dd53-4799-b826-f532a6a78bb0",
                        "decals"),
    "dome_tent_sage_night":  ("img",
        "1ed3643b-2393-4e6b-92a7-9b3fbdb3f1f7", "props_medium"),
    "dome_tent_amber_night": ("img",
        "5b387e30-1695-432e-988a-bd735ecb759d", "props_medium"),
    "dome_tent_slate_night": ("img",
        "24695398-a51c-4688-8b2d-262aa6b45ba7", "props_medium"),
    "cabin_night":           ("img",
        "3acd381f-b03e-4bb3-9b0c-b52eea171485", "props_large"),
    "pallet_deck_occupied":  ("img",
        "34194260-b08e-4df9-9c7c-505f2b93fa28", "props_medium"),
}


def load_state():
    return json.load(open(STATE)) if os.path.exists(STATE) else {}


def save_state(st):
    json.dump(st, open(STATE, "w"), indent=1)


def _get(url, dst):
    r = subprocess.run([sys.executable, "tools/pixellab_mcp.py",
                        "--get", url, dst], cwd=ROOT,
                       capture_output=True)
    ok = r.returncode == 0 and os.path.exists(dst) \
        and os.path.getsize(dst) > 200
    if not ok and os.path.exists(dst):
        os.remove(dst)
    return ok


def poll():
    st = load_state()
    for name, (kind, jid, _dst) in JOBS.items():
        ent = st.setdefault(name, {})
        if ent.get("file"):
            continue
        if kind == "img":
            out = harness("get_image", {"job_id": jid})
        else:
            out = harness("get_object", {"object_id": jid})
        ent["reply"] = out[:300]
        m = re.search(r"https://\S+", out)
        if not m or "completed" not in out:
            print(name, "pending")
            continue
        dst = os.path.join(GEN, name + ".png")
        os.makedirs(GEN, exist_ok=True)
        if _get(m.group(0), dst):
            ent["file"] = dst
            print(name, "downloaded")
        save_state(st)


def finish():
    from PIL import Image
    st = load_state()
    todo = []
    for name, (_k, _j, folder) in JOBS.items():
        ent = st.get(name, {})
        src = ent.get("file")
        if not src or not os.path.exists(src):
            continue
        im = Image.open(src).convert("RGBA")
        if im.getbbox() is None:
            print(name, "EMPTY — skipped")
            continue
        # pad tiles keep an organic-edge content crop; state swaps of
        # structures keep the source canvas so the anchor never drifts
        dst = os.path.join(ASSETS, folder, name + ".png")
        (im.crop(im.getbbox()) if name.startswith("pad_")
         else im).save(dst)
        ent["staged"] = dst
        todo.append(dst)
    if todo:
        r = subprocess.run([sys.executable, "tools/palette_lock.py",
                            "--ramp", RAMP] + todo, cwd=ROOT,
                           capture_output=True, text=True)
        print(r.stdout[-600:] if r.stdout else r.stderr[-400:])
    for name in st:
        if st[name].get("staged"):
            print("staged", st[name]["staged"])
    save_state(st)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "poll"
    {"poll": poll, "finish": finish}[cmd]()
