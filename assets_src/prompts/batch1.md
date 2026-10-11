# Batch 1 — Pinewatch terrain (GDD §28: terrain batch)

Shared tail for every prompt (same as Batch 0):
> cozy pixel art, Eastward-style painterly soft-dithered shading,
> sunlit yellow-green ground with warm browns on wood and stone,
> ember orange accents only, single sun angle from upper left, soft
> contact shadow, crisp outlines, one pixel density

Base tiles are 32×32, tileable, and fill the whole canvas (no
transparent corners). Decals are 32×32 on transparency — they sit ON
the base tiles, so their palette must sit inside the batch-0 ramp.

| Asset | Tool | Size | Prompt (before shared tail) |
|---|---|---|---|
| terrain_grass_lush | pixen high top-down | 32×32 | seamless lusher grass tile: denser moss and taller blades, a few tiny clover leaves, tileable edges — under-canopy variant of the base grass |
| terrain_grass_worn | pixen high top-down | 32×32 | seamless worn grass tile: sparse blades, dry patches, exposed earth showing through, tileable edges — high-traffic variant |
| terrain_dirt | pixen high top-down | 32×32 | seamless bare packed-earth tile: smooth dirt with a few 1–2 px pebbles and scuffs, tileable edges |
| terrain_path_dirt | pixen high top-down | 32×32 | seamless worn footpath tile: packed earth darker at center, faint boot-worn streaks along the vertical, tileable edges |
| terrain_forest_floor | pixen high top-down | 32×32 | seamless pine-needle bed tile: brown-olive needle litter over moss, sparse cone bits, tileable edges — ground under the pines |
| terrain_path_stone | pixen high top-down | 32×32 | seamless stepping-stone path tile: flat irregular flagstones set in dirt, moss in the gaps, tileable edges |
| terrain_pond_water | pixen high top-down | 32×32 | seamless still pond-water tile: dark green-blue water, faint horizontal ripple streaks, a few speckle highlights, tileable edges |
| terrain_shore_corner_in | pixen high top-down | 32×32 | shore corner tile: sandy bank curving around still water, inside corner (bank top-left, water bottom-right), foam along the curve — matches terrain_shore_p_0 |
| terrain_shore_corner_out | pixen high top-down | 32×32 | shore corner tile: water curving around a sandy point, outside corner (water top-left, bank bottom-right), foam along the curve — matches terrain_shore_p_0 |
| decal_grass_tuft_a | pixen high top-down | 32×32 | small grass tuft cluster decal: 3–4 blades fanning up with a soft contact shadow, sparse — sits on grass base |
| decal_grass_tuft_b | pixen high top-down | 32×32 | small grass tuft cluster decal, different silhouette: droopier blades, one bent tip, sparse |
| decal_pine_needles | pixen high top-down | 32×32 | pine-needle drift decal: a loose scatter of brown needle streaks, sparse, soft contact shadow |
| decal_pebbles | pixen high top-down | 32×32 | small pebble cluster decal: 4–5 grey-tan stones of 2–4 px, soft contact shadows, sparse |
| decal_fern | pixen high top-down | 32×32 | small fern clump decal: 3–4 unfurling fronds, slightly bluer green than grass, sparse |
| decal_wildflower | pixen high top-down | 32×32 | tiny wildflower decal: 2–3 small white and violet dots on thin stems, sparse |
| decal_mushroom | pixen high top-down | 32×32 | small mushroom pair decal: two brown-cap mushrooms 4–6 px tall, soft contact shadow — forage hint |

Palette lock: `tools/palette_lock.py --batch 1` after the set lands —
the batch-0 ramp is the target; this pass widens it only if terrain
genuinely needs new colors (dirt browns, water blues).
