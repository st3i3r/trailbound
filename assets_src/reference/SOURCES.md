# Reference assets — study only, never ship

| Pack | Source | Licence | Use |
|---|---|---|---|
| `overworld_tileset/` | edermunizz — "Free Pixel Art Overworld Tileset" (itch.io) | CC BY-ND 4.0 + custom: commercial/edit OK, **no file redistribution** | UI-034 trail-map icon vocabulary (schematic tree/mountain/town/path/water at map zoom). Reference only — our map icons are drawn in `tools/tb_glyphs.py`, not imported. |
| `cloud_sky/` | Free Game Assets (CraftPix) — "Free Pixel Cloud and Sky Backgrounds" (itch.io) | CraftPix licence: unlimited commercial, no standalone redistribution (license.txt → craftpix.net/file-licenses) | Cinematic sky surfaces, NOT world art: sleep→day transition cards (set 3 = moonlit), ceremonies UI-039, loading/letterbox UI-041/042. 4 sets × 2–6 parallax layers @ 576×324 — needs edge-extend or letterbox at our 640×360. |

These zips live outside `game/` so nothing ships to the build.
