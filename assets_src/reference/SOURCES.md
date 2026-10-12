# Reference assets — study only, never ship

| Pack | Source | Licence | Use |
|---|---|---|---|
| `overworld_tileset/` | edermunizz — "Free Pixel Art Overworld Tileset" (itch.io) | CC BY-ND 4.0 + custom: commercial/edit OK, **no file redistribution** | UI-034 trail-map icon vocabulary (schematic tree/mountain/town/path/water at map zoom). Reference only — our map icons are drawn in `tools/tb_glyphs.py`, not imported. |
| `cloud_sky/` | Free Game Assets (CraftPix) — "Free Pixel Cloud and Sky Backgrounds" (itch.io) | CraftPix licence: unlimited commercial, no standalone redistribution (license.txt → craftpix.net/file-licenses) | Cinematic sky surfaces, NOT world art: sleep→day transition cards (set 3 = moonlit), ceremonies UI-039, loading/letterbox UI-041/042. 4 sets × 2–6 parallax layers @ 576×324 — needs edge-extend or letterbox at our 640×360. |
| `resurrected_rpg/` | Immunity — "Resurrected RPG" 32×32 forest top-down (itch.io) | Custom: commercial/edit OK, no redistribution, credit appreciated | **Primary tree/prop reference** — 6 trees/bushes ×5 *re-shaded* colour variants (not hue swaps — study for seasonal gen prompts), prop grounding (grass tufts at prop bases), ruins vocabulary for the Fire Tower arc, `PlantShadow` soft-blob technique. Aseprite sources included — study layer construction. |
| `fm32x32/` | Immunity — "Forgotten Memories" 32×32 tileset (itch.io) | Custom: commercial/edit OK, no redistribution, credit appreciated | **Water + compositor reference** — `WaterTiles-6frames.png`: animated pond-edge autotile (stone-ringed shores, transitions, waterfall — the fix for our flat pond edges); `Trees_seperated.png`: canopy/trunk/shadow layer split; grass/dirt terrain, fences. |

These zips live outside `game/` so nothing ships to the build.
