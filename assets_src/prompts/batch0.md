# Batch 0 — style lock prompts (GDD §28)

Shared tail for every prompt (Eastward-style sunlit daylight — ref:
docs/reference/eastward.jpg + eastward1.jpg):
> cozy pixel art, Eastward-style painterly soft-dithered shading,
> sunlit yellow-green ground with warm browns on wood and stone,
> ember orange accents only, single sun angle from upper left, soft
> contact shadow, crisp outlines, one pixel density

| Asset | Tool | Size | Prompt (before shared tail) |
|---|---|---|---|
| campfire_ring | pixen high top-down | 64×64 | stone-ringed campfire with charred logs, no flame (flame is a separate layer) — DONE, see gen/campfire_0.png |
| campfire_flame | pixen side | 128×32 | small campfire flame sprite sheet, 4 frames in a row: tall, low, lean left, lean right, equal spacing — DONE, gen/flame_frames_0.png |
| player_idle | pixen low top-down | 64×64 | young trail warden with a worn leather backpack, ranger hat and a rolled journal, standing idle facing the viewer, ~48 px tall centered bottom |
| terrain_grass_pinewatch | pixen high top-down | 32×32 | seamless pine-forest floor tile: moss, needles, a few 1–2 px specks, tileable edges |
| terrain_shore_sample | pixen high top-down | 32×32 | water-edge sample tile: sandy bank meeting still water, subtle edge foam, tileable horizontally |
| prop_outfitter_van | pixen high top-down | 64×64 | small vintage outfitter van parked sideways, canvas canopy, warm paint — Batch 0 prop pick |

Palette lock: once the set lands, reduce all six to one shared ramp in
Pixelorama (cleanup/batch0_palette.pxo) — the ramp is the site palette.
