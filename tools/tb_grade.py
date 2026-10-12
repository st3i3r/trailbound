#!/usr/bin/env python3
"""Trailbound color grade — per-pixel HSV pass over wang terrain sheets
(or any asset dir via --target), applied identically to every copy in
the pipeline (assets_src/out -> game/assets -> assets_src/staging).

Goal (docs/reference/eastward.jpg): olive-khaki grass instead of lime,
warm ochre forest floor instead of maroon, muted grey-teal water,
slightly sandy stone.  Operates on hue/sat/value only — alpha bytes,
dither structure and transition detail are untouched.

NOT idempotent: it grades files in place.  Re-running double-grades.
Always re-grade from the pristine candidate sheets (--from-pristine,
or copy gen/candidates/batch3/T{2,3,4} over the pipeline dirs first).

CANONICAL SITE PRESET — pinewatch (engine-verified vs eastward.jpg):
    grass  h-11 deg, s x0.736, v x1.02   lime -> dusty olive-khaki
    dirt   pull ->38 deg w0.60, s x0.90, v x1.11   maroon -> warm ochre
    water  h+0,      s x0.55,  v x0.97   cyan-teal -> muted grey-teal
    stone  h+8,      s x0.90,  v x1.00   sandy cast (grey px -> h38, s+0.07)
    prop   +5 deg toward warm, s x0.95,  v x0.98   mild global warm

History: the first pass rotated water hue +7 deg; the water-fix review
reverted it — shipped pinewatch water keeps its source hue and is muted
by desaturation alone.  Do NOT re-apply a hue shift to pinewatch water.

    python tools/tb_grade.py                        # pinewatch, all 3 dirs
    python tools/tb_grade.py --from-pristine        # restore + re-grade
    python tools/tb_grade.py --site river --target assets_src/out/river/terrain
    python tools/tb_grade.py --target assets_src/out/props_medium --check
"""
import argparse
import os
import shutil
import sys
import colorsys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import png

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEETS = ["terrain_grass_water_pro_0.png",
          "terrain_grass_forest_pro_0.png",
          "terrain_grass_stone_pro_0.png"]
KIND = {"terrain_grass_water_pro_0.png": "water",
        "terrain_grass_forest_pro_0.png": "dirt",
        "terrain_grass_stone_pro_0.png": "stone"}
DIRS = [os.path.join(ROOT, "assets_src", "out", "terrain"),
        os.path.join(ROOT, "game", "assets", "pinewatch", "terrain"),
        os.path.join(ROOT, "assets_src", "staging", "pinewatch", "terrain")]
# pristine PixelLab output — the only un-graded copies in the repo.
# batch5 (B5-T{2,3,4}) = the calm-wash regeneration that shipped.
PRISTINE = {
    "terrain_grass_water_pro_0.png":
        os.path.join(ROOT, "assets_src", "gen", "candidates",
                     "batch5", "B5-T2", "terrain_grass_water_pro_0.png"),
    "terrain_grass_forest_pro_0.png":
        os.path.join(ROOT, "assets_src", "gen", "candidates",
                     "batch5", "B5-T3", "terrain_grass_forest_pro_0.png"),
    "terrain_grass_stone_pro_0.png":
        os.path.join(ROOT, "assets_src", "gen", "candidates",
                     "batch5", "B5-T4", "terrain_grass_stone_pro_0.png"),
}

# ------------------------------------------------------------- site presets
# h in degrees [0,360), s/v in [0,1].  Rule fields:
#   dh        additive hue rotation (deg)
#   s, v      sat/value multipliers
#   pull      (target_deg, weight) pull hue toward target (ochre-ify)
#   pull_min  min saturation for pull to apply
#   grey      (s_thresh, h_set, s_add) low-sat pixels get a flat cast
#   toward    (target_deg, max_step) clamped step toward a hue — the
#             gentle "nudge toward warm/cool" used for prop fallback
PRESETS = {
    # Pine-highland campground — CANONICAL, matches the shipped sheets.
    "pinewatch": {
        "grass": {"dh": -11.0, "s": 0.736, "v": 1.02},
        "dirt":  {"pull": (38.0, 0.60), "pull_min": 0.12,
                  "s": 0.90, "v": 1.11},
        "water": {"dh": 0.0, "s": 0.55, "v": 0.97},
        "stone": {"dh": 8.0, "s": 0.90, "v": 1.0,
                  "grey": (0.12, 38.0, 0.07)},
        "prop":  {"toward": (40.0, 5.0), "s": 0.95, "v": 0.98},
    },
    # Pinewatch v2 (2026-10-12 colour-direction correction): v1 over-muted
    # the scene ("horror movie").  Eastward is high-key — bright sunlit
    # yellow-green grass, deep cool shade, saturated teal water; it mutes
    # mid-value clutter, never the light.  Grass keeps the olive hue
    # family but pushes value way up (sheet base lands ~(192,201,121),
    # reading ~(190,193,109) after the lightened #fbf4e4 CanvasModulate);
    # water keeps its teal hue with most of its source saturation back.
    "pinewatch_v2": {
        "grass": {"dh": -2.0, "s": 0.80, "v": 1.21},
        "dirt":  {"pull": (38.0, 0.60), "pull_min": 0.12,
                  "s": 0.90, "v": 1.11},
        "water": {"dh": 0.0, "s": 0.80, "v": 1.04},
        "stone": {"dh": 8.0, "s": 0.90, "v": 1.0,
                  "grey": (0.12, 38.0, 0.07)},
        "prop":  {"toward": (40.0, 5.0), "s": 0.95, "v": 0.98},
    },
    # Whisper River — TUNE-ME placeholder: cooler grass, blue-dominant
    # water, bamboo greens.  Not yet engine-verified.
    "river": {
        "grass": {"dh": 4.0, "s": 0.70, "v": 1.00},
        "dirt":  {"pull": (34.0, 0.50), "pull_min": 0.12,
                  "s": 0.85, "v": 1.05},
        "water": {"dh": 12.0, "s": 0.50, "v": 0.96},
        "stone": {"dh": 4.0, "s": 0.85, "v": 1.0,
                  "grey": (0.12, 205.0, 0.05)},
        "prop":  {"toward": (130.0, 4.0), "s": 0.94, "v": 0.98},
    },
    # Valley — TUNE-ME placeholder: golden meadow + dusk violet.
    # Not yet engine-verified.
    "valley": {
        "grass": {"dh": -20.0, "s": 0.85, "v": 1.04},
        "dirt":  {"pull": (32.0, 0.55), "pull_min": 0.12,
                  "s": 0.92, "v": 1.06},
        "water": {"dh": 60.0, "s": 0.55, "v": 0.90},
        "stone": {"dh": -6.0, "s": 0.88, "v": 1.0,
                  "grey": (0.12, 280.0, 0.06)},
        "prop":  {"toward": (35.0, 6.0), "s": 0.96, "v": 0.99},
    },
}


def apply_rule(rule, h, s, v):
    """rule dict -> (h, s, v); caller clamps s/v to [0,1]."""
    if "grey" in rule and s < rule["grey"][0]:
        # near-achromatic pixels are hue-free: give them the flat cast
        return rule["grey"][1], s * rule.get("s", 1.0) + rule["grey"][2], \
            v * rule.get("v", 1.0)
    if "pull" in rule and s > rule.get("pull_min", 0.12):
        tgt, w = rule["pull"]
        h = h + (tgt - h) * w
    if "toward" in rule:
        tgt, step = rule["toward"]
        d = ((tgt - h + 180.0) % 360.0) - 180.0
        h += max(-step, min(step, d))
    h = (h + rule.get("dh", 0.0)) % 360.0
    return h, s * rule.get("s", 1.0), v * rule.get("v", 1.0)


def classify(r, g, b, sheet_kind=None):
    """-> preset key.  Green-dominant pixels are grass in every sheet
    (also covers lily pads and stone moss flecks).  On terrain sheets
    everything else is the sheet's lower terrain; on --target dirs a
    colour-based water/dirt test runs first and the remainder falls to
    the mild 'prop' default."""
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    hd = h * 360.0
    if s > 0.25 and 55.0 <= hd <= 140.0 and g > r and g >= b:
        return "grass"
    if sheet_kind is not None:
        return sheet_kind
    if s > 0.20 and 150.0 <= hd <= 265.0 and b >= r:
        return "water"
    if s > 0.25 and 12.0 <= hd <= 55.0 and r > g:
        return "dirt"
    return "prop"


def grade_rows(rows, w, h, sheet_kind, preset):
    counts = {}
    for y in range(h):
        row = rows[y]
        for x in range(w):
            i = x * 4
            if row[i + 3] < 128:                      # fully transparent
                continue
            r, g, b = row[i], row[i + 1], row[i + 2]
            kind = classify(r, g, b, sheet_kind)
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            hh, ss, vv = apply_rule(preset[kind], hh * 360.0, ss, vv)
            r2, g2, b2 = colorsys.hsv_to_rgb((hh % 360.0) / 360.0,
                                             min(1.0, max(0.0, ss)),
                                             min(1.0, max(0.0, vv)))
            row[i] = int(round(r2 * 255))
            row[i + 1] = int(round(g2 * 255))
            row[i + 2] = int(round(b2 * 255))         # alpha untouched
            counts[kind] = counts.get(kind, 0) + 1
    return counts


def main():
    ap = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--site", choices=sorted(PRESETS), default="pinewatch",
                    help="site preset (default: pinewatch — canonical)")
    ap.add_argument("--target", action="append", metavar="DIR",
                    help="asset dir to grade (repeatable). Grades every "
                         "*.png inside; known wang sheets keep their "
                         "sheet kind, other art classifies per-pixel "
                         "(grass/water/dirt) with the mild 'prop' "
                         "fallback. Replaces the default terrain dirs.")
    ap.add_argument("--from-pristine", action="store_true",
                    help="copy the pristine batch3 candidate sheets over "
                         "the pipeline dirs before grading — avoids "
                         "double-grading (terrain sheets only)")
    ap.add_argument("--check", action="store_true",
                    help="emit %%TEMP%%/tb_review/grade_check.png "
                         "(2x before|after crop)")
    args = ap.parse_args()
    preset = PRESETS[args.site]
    print("site preset:", args.site)

    if args.from_pristine:
        if args.target:
            sys.exit("--from-pristine only applies to the default "
                     "terrain dirs (it knows wang sheets, not props)")
        for name in SHEETS:
            src = PRISTINE[name]
            for d in DIRS:
                shutil.copy2(src, os.path.join(d, name))
                side = src[:-4] + ".json"        # wang metadata rides along
                if os.path.exists(side):
                    shutil.copy2(side, os.path.join(d, name[:-4] + ".json"))
            print("pristine ->", name, "x%d" % len(DIRS))

    dirs = [os.path.abspath(t) for t in args.target] if args.target else DIRS
    before = {}
    first_path = None
    for d in dirs:
        names = SHEETS if not args.target else sorted(
            n for n in os.listdir(d) if n.lower().endswith(".png"))
        for name in names:
            p = os.path.join(d, name)
            if not os.path.exists(p):
                print("skip (missing)", p)
                continue
            w, h, rows = png.read(p)
            if first_path is None:
                first_path = p
            if args.check and p == first_path:
                before[p] = [bytearray(r) for r in rows]
            kind = KIND.get(name)      # None -> prop-mode classification
            counts = grade_rows(rows, w, h, kind, preset)
            png.write(p, w, h, rows)
            print("graded %-52s %dx%d %s" % (p, w, h, counts))
    if args.check:
        emit_check(before, first_path)


def emit_check(before, path):
    """2x-zoomed before|after of a grass->water transition edge."""
    try:
        from PIL import Image
    except ImportError:
        print("PIL unavailable — grade_check.png skipped")
        return
    import png as _png
    if path is None:
        print("no files graded — grade_check.png skipped")
        return
    w, h, after = _png.read(path)
    before_path_rows = before.get(path)
    if before_path_rows is None:
        print("no before snapshot — grade_check.png skipped")
        return
    box = (0, 0, min(64, w), min(64, h))              # 4 transition tiles
    def crop(rows):
        im = Image.new("RGBA", (box[2] - box[0], box[3] - box[1]))
        px = im.load()
        for y in range(box[1], box[3]):
            for x in range(box[0], box[2]):
                i = x * 4
                px[x - box[0], y - box[1]] = tuple(rows[y][i:i + 4])
        return im.resize((im.width * 2, im.height * 2), Image.NEAREST)
    b_im, a_im = crop(before_path_rows), crop(after)
    out = Image.new("RGBA", (b_im.width + a_im.width + 4, b_im.height))
    out.paste(b_im, (0, 0))
    out.paste(a_im, (b_im.width + 4, 0))
    dest = os.path.join(os.environ.get("TEMP", ROOT), "tb_review")
    os.makedirs(dest, exist_ok=True)
    out.save(os.path.join(dest, "grade_check.png"))
    print("->", os.path.join(dest, "grade_check.png"),
          "(left: before, right: after, 2x)")


if __name__ == "__main__":
    main()
