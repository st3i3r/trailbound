#!/usr/bin/env python3
"""Rewrite assets_src/manifest.json to describe the canonical
staging+out set: ids -> filenames, measured dims, anchors, statuses."""
import os, json
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASRC = os.path.join(ROOT, "assets_src")
STG = os.path.join(ASRC, "staging", "pinewatch")
OUT = os.path.join(ASRC, "out")

rep = json.load(open(os.path.join(STG, "staging_report.json")))
picks = json.load(open(os.path.join(ASRC, "picks", "batch3_picks.json")))
anchors = json.load(open(os.path.join(OUT, "anchors.json")))
pal = json.load(open(os.path.join(OUT, "site_palette_v2.json")))
scale = json.load(open(os.path.join(OUT, "scale_report.json")))
slist = json.load(open(os.path.join(OUT, "superseded_list.json")))
old = json.load(open(os.path.join(ASRC, "manifest.json")))

def bbox_of(p):
    a = np.array(Image.open(p).convert("RGBA"))[..., 3]
    ys, xs = np.where(a > 0)
    if len(xs) == 0:
        return None
    return [int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1)]

JOB_NOTES = {j: picks["jobs"][j].get("notes") for j in picks["jobs"]}
JOB_ROLE = {j: picks["jobs"][j].get("role") for j in picks["jobs"]}

assets = []
for cat, files in rep["categories"].items():
    for ent in files:
        fn = ent["file"]; job = ent["job"]
        if not fn.endswith(".png"):
            continue
        p = os.path.join(STG, cat, fn)
        im = Image.open(p)
        w, h = im.size
        key = f"{cat}/{fn}"
        stem = fn[:-4]
        a = {"id": stem, "category": cat, "job": job,
             "batch": 3,
             "file": f"staging/pinewatch/{cat}/{fn}",
             "size": f"{w}x{h}",
             "content_bbox": bbox_of(p)}
        if key in anchors:
            a["anchor"] = {"x": anchors[key]["anchor_x"],
                           "y": anchors[key]["anchor_y"],
                           "kind": anchors[key]["anchor"]}
        outp = os.path.join(OUT, cat, fn)
        if os.path.exists(outp):
            a["out"] = f"out/{cat}/{fn}"
            a["status"] = "post"
        else:
            a["status"] = "staged"
        if JOB_ROLE.get(job):
            a["role"] = JOB_ROLE[job]
        note = JOB_NOTES.get(job)
        if note:
            a["job_notes"] = note
        assets.append(a)

# batch4 candidates (not staged; A1b/A2/A3 used in comp)
b4 = os.path.join(ASRC, "gen", "candidates", "batch4")
for job in sorted(os.listdir(b4)):
    d = os.path.join(b4, job)
    if not os.path.isdir(d):
        continue
    for fn in sorted(os.listdir(d)):
        if not fn.endswith(".png"):
            continue
        im = Image.open(os.path.join(d, fn))
        w, h = im.size
        assets.append({"id": fn[:-4], "category": "anims" if job != "I2"
                       else "icons", "job": job, "batch": 4,
                       "file": f"gen/candidates/batch4/{job}/{fn}",
                       "size": f"{w}x{h}",
                       "status": "candidates",
                       "job_notes": {"A1": "flame loop on fire ring; A1b = alt take, used in comp v2",
                                     "A2": "warden walk 4-dir + idle south",
                                     "A3": "camp dog idle/sit south",
                                     "I2": "icon reroll pack (64 cands)"}.get(job)})

# superseded ledger
for fn, info in slist["superseded"].items():
    assets.append({"id": fn[:-4] if fn.endswith(".png") else fn,
                   "category": "legacy", "batch": "0-2",
                   "file": info["moved_to"],
                   "status": "superseded",
                   "superseded_by": info["superseded_by"]})
for fn, why in slist["kept_no_replacement"].items():
    assets.append({"id": fn[:-4], "category": "legacy", "batch": "0-2",
                   "file": f"gen/{fn}", "status": "generated",
                   "job_notes": why})

# carry forward planned/draft entries from old manifest
for a in old["assets"]:
    if a.get("status") in ("planned", "draft"):
        assets.append(a)

# UI kit entry
uim = json.load(open(os.path.join(OUT, "ui", "ui_atlas_meta.json")))
assets.append({"id": "ui_atlas_pinewatch", "category": "ui", "batch": 3,
               "file": "out/ui/ui_atlas.png",
               "size": f'{uim["_atlas"]["w"]}x{uim["_atlas"]["h"]}',
               "status": "post",
               "job_notes": "segmented U1-U5 kit; pieces in out/ui/pieces/, "
                            "nine_slice insets in ui_atlas_meta.json"})

manifest = {
    "project": "Trailbound",
    "palette": ("Pinewatch site ramp v2: %d colors, out/site_palette_v2.json "
                "(%s) — built from staged batch3+4 winners; greens dominate. "
                "Old cleanup/site_palette.json retired (warm-heavy). Dusk "
                "warmth is a §16.3 lighting layer — do NOT bake into sprites"
                % (len(pal["colors"]),
                   ", ".join(f'{k} {v}%' for k, v in
                             pal["class_shares"].items()))),
    "sun_angle": "upper left",
    "pipeline": ("PixelLab -> gen/candidates/<batchN> -> winners staged at "
                 "staging/pinewatch -> post-processed copies at out/ "
                 "(contact shadows, anchors.json, palette outlier snap, "
                 "terrain fixes, ui kit) -> sheets/atlases -> game/assets"),
    "scale_check": scale,
    "assets": assets,
}
with open(os.path.join(ASRC, "manifest.json"), "w") as f:
    json.dump(manifest, f, indent=1)
print("manifest assets:", len(assets))
