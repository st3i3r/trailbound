#!/usr/bin/env python3
"""Char master palette -> per-persona subset ramps (palette_lock --ramp
input).  Master hues are measured from assets_src/refs/grade/ew_saiga.jpg
(median-cut) + authored material ramps in the same saturation family.
Char ramps are SITE-NEUTRAL but share the ref's value/saturation band —
" different colors, same world".  Run:  python tools/build_char_palettes.py
Writes assets_src/palettes/chars/<persona>.json {"ramp": [...]}."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets_src", "palettes", "chars")

MASTER = {
 "source": "ew_saiga.jpg median-cut anchors + authored ramps in-family",
 # measured straight off the ref — shared with the world grade
 "anchor": {
  "ink":   ["#251e24"],
  "shade": ["#273828", "#432f2a", "#4e492b"],
  "warm":  ["#5c4e41", "#7a5f51", "#a27b46", "#c39353"],
  "paper": ["#bbb99a", "#dde798", "#eff8b8"],
 },
 # character material ramps — 5 steps hi->deep, ref-family saturation
 "ramps": {
  "skin_light":  ["#f5cf9f", "#eeb98a", "#d69a68", "#8a5a3a"],
  "skin_mid":    ["#e8b07e", "#cf9060", "#a86a44", "#634734"],
  "skin_deep":   ["#b8845a", "#9a6a48", "#6b4a34", "#422b23"],
  "hair_black":  ["#554a4a", "#403838"],
  "hair_dark":   ["#6b4a34", "#5a3f2e", "#3d2818"],
  "hair_brown":  ["#b87c50", "#a06844", "#6b4428", "#3a2418"],
  "hair_grey":   ["#d0cec4", "#b8b8b0", "#8a8a84", "#55524a"],
  "cloth_forest":  ["#8fce6e", "#5da854", "#3f8340", "#2d5e30"],
  "cloth_navy":    ["#7d94b8", "#546a94", "#3d4a70", "#2c3450"],
  "cloth_olive":   ["#c0b86a", "#a8a34e", "#7a7650", "#55522f"],
  "cloth_khaki":   ["#d8c898", "#b8a070", "#8a7650", "#584a30"],
  "cloth_cream":   ["#fff8e0", "#f0e8c8", "#d8cfa8", "#b0a884", "#6b6550"],
  "cloth_pink":    ["#ffd0d8", "#f0a8b8", "#d88798", "#a86070", "#6b3a48"],
  "cloth_red":     ["#e07850", "#c05038", "#98382c", "#682418"],
  "cloth_charcoal":["#8a8a90", "#5c5660", "#3f3b44"],
  "cloth_denim":   ["#88a0b8", "#5d7a94", "#405a74", "#2c3c50"],
  "cloth_mustard": ["#e0c060", "#c09a40", "#90702c", "#5c4a1e"],
  "cloth_tweed":   ["#c0a888", "#a89070", "#8a7058", "#6b5340", "#4a382a"],
  "cloth_mauve":   ["#d8b0b8", "#c098a4", "#9a7284", "#6b4e5c"],
  "cloth_pastelblue": ["#c8e0ee", "#a0c8e0", "#74a4c4", "#4e7896"],
  # measured Eastward vivid cloth (palette audit): saiga teal
  # jacket h164 s.7, farm coral barn h3 s.5, mist indigo h227 s.69
  "cloth_teal":    ["#6ed4b8", "#31a082", "#287860", "#1c544a"],
  "cloth_coral":   ["#e8a08a", "#d26f69", "#b05250", "#783a40"],
  "cloth_indigo":  ["#8090d0", "#5568b8", "#344ca6", "#28386e"],
  "gear_leather":  ["#d09a68", "#b8845a", "#93603c", "#6b4428"],
  "gear_straw":    ["#e8d088", "#c8a858", "#96783c", "#5c4a24"],
  "gear_wood":     ["#d8a868", "#b08048", "#7a5a34", "#4e3524"],
  "fur_bean":      ["#f0e4c8", "#e8dcc0", "#c8b490", "#9a8264", "#5c4e41"],
  "fur_dark":      ["#6b6460", "#4e4844", "#3a3230", "#241e20"],
  "fur_white":     ["#f4f0e4", "#ddd8c8", "#b8b0a0"],
  "collar_red":    ["#c05038", "#98382c"],
 },
 # persona -> ramps each sprite may draw from (ink+shade always appended;
 # paper kept out of sprites — it's panel/light, not cloth)
 "assign": {
  "warden":           ["skin_light", "hair_brown", "cloth_forest", "gear_leather"],
  "ranger_mai":       ["skin_light", "hair_black", "cloth_navy", "gear_straw", "gear_leather"],
  "bean":             ["fur_bean", "fur_dark", "collar_red"],
  "backpacker_woman": ["skin_mid", "hair_dark", "cloth_olive", "gear_leather"],
  "scout_kid":        ["skin_light", "hair_brown", "cloth_khaki", "cloth_red"],
  "aodai_woman":      ["skin_light", "hair_black", "cloth_cream"],
  "kid_pinkdress":    ["skin_light", "hair_dark", "cloth_pink"],
  "phuot_rider":      ["skin_mid", "hair_black", "cloth_charcoal", "cloth_red"],
  "backpacker_man":   ["skin_light", "hair_brown", "cloth_denim", "gear_leather"],
  "angler_uncle":     ["skin_mid", "hair_grey", "cloth_mustard", "gear_wood"],
  "bird_uncle":       ["skin_light", "hair_grey", "cloth_tweed"],
  # Vietnamese daily-life pass (D4.1a)
  "grandma_ba":       ["skin_light", "hair_grey", "cloth_mauve", "gear_straw"],
  "grandpa_mu":       ["skin_mid", "hair_grey", "cloth_khaki", "gear_straw"],
  "auntie_dobo":      ["skin_mid", "hair_dark", "cloth_mauve", "gear_straw"],
  "uncle_deptong":    ["skin_mid", "hair_black", "cloth_cream", "cloth_charcoal"],
  "sunhood_woman":    ["skin_light", "hair_black", "cloth_pastelblue", "cloth_charcoal"],
  "teen_jersey":      ["skin_light", "hair_black", "cloth_red", "cloth_charcoal"],
  "student_bucket":   ["skin_light", "hair_brown", "cloth_cream", "cloth_denim"],
  "vendor_ganh":      ["skin_mid", "hair_black", "cloth_khaki", "gear_straw", "gear_wood"],
  "border_collie":    ["fur_dark", "fur_white", "collar_red"],
 },
}


def build():
    master = MASTER["ramps"]
    ink_shade = MASTER["anchor"]["ink"] + MASTER["anchor"]["shade"]
    os.makedirs(OUT, exist_ok=True)
    manifest = {}
    for persona, ramps in MASTER["assign"].items():
        cols = []
        for r in ramps:
            cols += master[r]
        cols += ink_shade
        cols = list(dict.fromkeys(cols))
        path = os.path.join(OUT, persona + ".json")
        json.dump({"persona": persona, "ramps": ramps, "ramp": cols},
                  open(path, "w"), indent=1)
        manifest[persona] = len(cols)
        print("%-20s %2d colors  %s" % (persona, len(cols), ", ".join(ramps)))
    json.dump(MASTER, open(os.path.join(ROOT, "assets_src", "palettes",
               "char_master.json"), "w"), indent=1)
    print("\nwrote %d persona ramps + char_master.json" % len(manifest))


if __name__ == "__main__":
    build()
