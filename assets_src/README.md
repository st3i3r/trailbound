# assets_src — source art (not imported)

PixelLab → cleanup → sheets → `game/assets/`. Everything here is source
material; only `sheets/` output gets copied into the game project.

## Layout

```
gen/          generated art — current canonical sprites (palette-locked in place)
cleanup/      palette ramps, Pixelorama .pxo, working files
sheets/       assembled atlases/sprite sheets ready for game/assets (2 px padding)
prompts/      prompt library per batch (GDD §28)
refs/         style refs, palette ramps, Eastward teardown frames
manifest.json the asset ledger — every asset's status, file, size, frames
```

## Naming

`gen/<id>_<n>.png` for generated files; `sheets/<site>_<kind>_<size>.png`
for atlases. IDs are stable snake_case and match `game/data/*.json` ids
where the asset backs a data entry.

## Rules (GDD §16.2, §16.4, §28)

- 32 px tiles, 64 px placement cells, 64×64 prop/character frames (48 px
  characters, anchored bottom-center).
- One pixel density, one sun angle (upper left), one wind direction.
- Contact shadow under every object; open/occupied/lit micro-state
  variants for interactive props.
- Atlases: 2 px padding, no mipmaps, nearest filtering, palette-locked
  per site.
- **Download generated images immediately — PixelLab objects expire
  after ~8 h.** `gen/` output is committed so nothing rots on their side.
- Cleanup estimate lives in §28 (~100 h); time per asset goes in
  manifest.json as batches complete.

## Flow

1. `tools/pixellab_gen.py` (or MCP) → `gen/` — assets are approved by
   default; re-roll or clean only when something's actually wrong
2. `tools/palette_lock.py --batch N` → remaps gen/ onto the shared ramp
   in place + refreshes `cleanup/batchN_palette.*`
3. Assemble sheet → `sheets/` → copy into `game/assets/` + register
   in manifest.json (`status: imported`)

Statuses: `planned` → `generated` → `imported`.
