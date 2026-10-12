# assets_src — source art (not imported)

**Status: Pinewatch art is canonical & engine-verified** (graded sheets
in `out/` == `game/assets/` == `staging/`; engine shot:
`cleanup/pinewatch_engine_graded.png`).

Pipeline: PixelLab → candidates → pick → **`tools/tb_grade.py --site X`**
→ palette-snap (dE>30) → staging/out → `game/assets/pinewatch/`.
Everything here is source material; the canonical copies live under
`out/` (plus a handful of `gen/` keepers) and are mirrored into
`game/assets/pinewatch/` — see "Canonical assets" below.

## Layout

```
gen/candidates/<batchN>/  every PixelLab candidate (raw pool)
gen/_superseded/          batch 0-2 art replaced by batch3/4 winners
staging/pinewatch/        picked WINNERS — never edit in place
out/                      post-processed copies: contact shadows baked,
                          anchors.json, palette outlier snap (dE>30),
                          terrain fixes, ui/ kit pieces + atlas
cleanup/                  palette ramps, Pixelorama .pxo, working files,
                          composite mocks
sheets/                   assembled atlases/sprite sheets ready for
                          game/assets (2 px padding)
prompts/                  prompt library per batch (GDD §28)
picks/                    winner picks + notes per batch
refs/                     style refs, palette ramps, Eastward teardowns
manifest.json             the asset ledger — ids -> files, measured
                          dims, anchors, statuses
```

## Naming

`gen/<id>_<n>.png` for generated files; `sheets/<site>_<kind>_<size>.png`
for atlases. IDs are stable snake_case and match `game/data/*.json` ids
where the asset backs a data entry.

## Rules (GDD §16.2, §16.4, §28)

- 32 px tiles, 64 px placement cells, 64×64 prop/character frames (48 px
  characters, anchored bottom-center — see `out/scale_report.json`: the
  batch3 turnaround runs ~58 px tall, ~21% over spec; left as authored,
  no resample — revisit at import).
- One pixel density, one sun angle (upper left), one wind direction.
- Contact shadow under every object (synthesized soft ellipse in `out/`
  where missing); open/occupied/lit micro-state variants for
  interactive props.
- Atlases: 2 px padding, no mipmaps, nearest filtering, palette-locked
  per site (Pinewatch = `out/site_palette_v2.json`, greens-dominated).
- **Download generated images immediately — PixelLab objects expire
  after ~8 h.**

## Flow

1. `tools/pixellab_gen.py` (or MCP) → `gen/candidates/<batchN>/`
   — prompts carry the locked grade language
   (`prompts/style_lock.md`); pass
   `cleanup/pinewatch_engine_graded.png` (or a scene crop) as the
   PixelLab **style reference** instead of raw eastward.jpg — it's the
   house style distilled, so candidates land pre-graded.
2. Pick winners → `staging/pinewatch/` + `picks/batchN_picks.json` +
   `staging_report.json`
3. **Grade:** `python tools/tb_grade.py --site pinewatch
   --from-pristine` (terrain) or `--site X --target <dir>` for other
   asset dirs — see "Color grade" below.
4. Post-process onto `out/` copies:
   `tools/tb_post.py` (shadows/anchors/scale), `tools/tb_palette.py`
   (site ramp + outlier snap, dE>30), `tools/tb_terrain_superseded.py`
   (terrain fixes + gen/ superseded sweep)
5. UI kit: `tools/tb_ui_kit.py` → `out/ui/` (pieces, nine_slice insets,
   atlas)
6. Mock/review: `tools/scene_comp_v2.py` → `cleanup/*_comp*.png` /
   `*_mock.png`
7. Copy canonical files into `game/assets/pinewatch/` (map below) +
   register in manifest.json (`status: imported`). The old `sheets/`
   step is superseded — the game now consumes the same per-asset PNGs
   the mocks use, so what you see in `cleanup/` is what ships.

## Color grade — `tools/tb_grade.py`

Per-pixel HSV pass, one preset per site (`--site pinewatch` is
canonical — multipliers documented in the script header + PRESETS;
`river`/`valley` are TUNE-ME placeholders). Terrain sheets keep their
sheet kind; `--target <dir>` grades any asset dir, classifying
grass/water/dirt per pixel and falling back to a mild global-warm prop
pass (sat ×0.95, +5° toward warm, v ×0.98).

The script grades **in place — not idempotent.** Re-grade from pristine
(`--from-pristine`, or copy `gen/candidates/batch3/T{2,3,4}` over the
three terrain dirs first) and keep `out/` == `game/assets/` ==
`staging/` byte-identical. Verify with
`cleanup/grade_compare.png` (eastward | before | current) and the
engine shot (`godot.cmd --path game res://scenes/pinewatch_test.tscn
--shot` → `cleanup/pinewatch_engine_graded.png`).

## Canonical assets — `game/assets/pinewatch/`

Mirrored from `out/` (and a few `gen/` keepers). `*.import` files are
engine-generated, never copied. `pad_*.png` are legacy pad markers,
kept in place.

```
terrain/         3 wang sheets + their .json metadata
                 (grass↔water / grass↔forest / grass↔stone)
decals/          XS_* scatter decals
props_small/     S_* + named small props (spirit_house, non_la_hat…)
props_medium/    M*_* + named medium props (tents, tripod_cauldron,
                 fire_ring, chicken_coop… + gen/ keepers
                 prop_boulder_0, prop_supply_crate_0)
props_large/     cabin, outfitter_van, hammock, flamboyant_tree,
                 pine_tall_a/b, bamboo_clump, pennant_string…
characters/      warden/ ranger_mai/ camp_dog/ — 8-dir turnarounds
                 plus batch4 anim frames (A2_* warden, A3_* dog)
fx/              A1b_0..6 fire loop, A1_0..6 ignite one-shot
ui/              ui_atlas.png + ui_atlas_meta.json (nine-slice
                 insets) + every ui piece as its own PNG
icons/           G_* chrome glyph masks (values/weather/traits/sections —
                 generated by tools/tb_glyphs.py) + I1_* painterly
                 content icons (items/dishes only, never chrome)
fonts/           F1_1.ttf (display), BeVietnamPro-Regular.ttf (body —
                 Vietnamese coverage), LICENSE_BeVietnamPro.txt (OFL)
anchors.json     bottom-anchor px per sprite
pad_open/pad_locked/pad_hover.png   pad markers (legacy)
```

`tools/make_tileset.py` rebuilds `game/resources/pinewatch_terrain.tres`
from the terrain JSONs (one TileSetAtlasSource per sheet, corner
peering bits, 3 terrain sets × 16 tiles).

## Third-party notices

- **pixelarticons** (`thirdparty/pixelarticons/`) — MIT © 2019 Gerrit
  Halfmann; LICENSE in-tree.  Chrome glyph masks rasterised from its
  SVGs by `tools/tb_glyphs.py` (provenance per glyph in
  `game/data/icons_sources.json`).
- **BeVietnamPro** — OFL; `fonts/LICENSE_BeVietnamPro.txt`.
