# Style lock — the Trailbound house look

Source of truth for all visual rules. Canonical reference:
`assets_src/cleanup/pinewatch_engine_graded.png` (the graded engine
shot — the house style distilled). Target-quality teardown refs:
`docs/reference/` (Eastward/Octopia official shots).

**Pinewatch art is canonical.** Every batch inherits this look — do
not restyle per batch. Prompt text lives in `PROMPT_PACK.md`; this
file owns the rules those prompts encode.

## Style references

Pass a subject-appropriate crop as the PixelLab `style_image` on every
gen job — never a full scene. Crops teach LOOK (craft level, outline,
shading); prompts teach CONTENT. Style refs anchor to target-quality
art (Eastward/Octopia crops in `assets_src/refs/crops/`,
`docs/reference/`), never to shipped Trailbound art — self-referencing
caps output at current quality. `docs/reference/ui_stale/` is
quarantined (2026-10-15): mislabeled editorial captures, not
Eastward — never send them as style refs. Palette is owned by
`tb_grade`, so a ref need only carry craft.

## Post-gen grade (deterministic, applied to every pipeline copy)

```
generate -> tools/tb_grade.py --site X -> palette-snap (dE>30) -> stage -> integrate
```

`tools/tb_grade.py --site pinewatch_v2`:

| class | rule |
|---|---|
| grass | dh -2°, sat x0.80, val x1.21 — bright fresh yellow-green (~192,201,121) |
| dirt  | pull ->38° w0.60, sat x0.90, val x1.11 — warm ochre |
| water | hue +0, sat x0.80, val x1.04 — fresh teal (~93,135,140) |
| stone | hue +8, sat x0.90 (grey px -> h38, s+0.07) — sandy |
| prop fallback (non-terrain `--target`) | +5° toward warm, sat x0.95, val x0.98 |
| warm multiply | `#fbf4e4` — light warm cast |

Colour direction: high-key and fresh — bright sunlit grass, deep cool
shade, wide value range, saturated teal water. Mute mid-value clutter,
never the light.

Snap target: `out/site_palette_v3.json` — light->mid->shade ramps per
family (grass #d4d587/#c0c879/#5a6e3c, water #68a5a5/#5d878c/#3e5157,
dirt #daad66/#c69553/#6d4c2b, warm #dad4bf/#968d75/#443e33). The
tint-map overlay is a lighting layer — EXEMPT from snapping.

`--site river` / `--site valley` are placeholders — tune them against
their own reference shots before shipping those sites.

The script grades **in place and is not idempotent** — always re-grade
from pristine (`--from-pristine`, or restore the candidate PNGs into
staging) and verify `out/`, `game/assets/`, `staging/` stay
byte-identical.

## Ground recipe

Separate **shape** from **colour**: a calm repeating texture carries
the shape; a low-frequency tint field carries the colour. Macro
variation is painted light/tonal zones — never tile swaps or dense
scatter.

Three texture layers:

| layer | rule |
|---|---|
| base tile | low-detail tonal base — no baked tufts/flowers/specks (prompt for calm at gen time; `tb_calm.py` is rescue only) |
| mid texture | dither patches baked into tiles by `tools/tb_dither.py` — irregular patch shapes (low-freq noise threshold) filled with single-pixel dither at +-1-2 ramp steps (~50-70% checker density); low amplitude; per-position seed so no two tiles share a pattern; apply to fill tiles AND the matching terrain regions inside transition tiles |
| macro variation | ONE baked 640x360 tint-map overlay: low-frequency noise -> soft warm/cool/dry zones + a few stronger sun pools/shade pools; alpha ~12-20%; continuous, ignores the tile grid |

| rule | spec |
|---|---|
| tile-swap zones | **forbidden** — 32px cell swaps produce jigsaw boundaries |
| edge interlock | dark rim in wang transitions + sparse 1-3px blade strokes crossing grass->lower boundaries |
| decals | ~10-14 per 640x360 screen, clustered at edges/prop bases/shoreline only, ONE family per cluster, open-field interior empty |
| wear | small dirt patches under tents/fire/path mouth — ground tells a story |
| light | soft painted pools via the tint map + warm CanvasModulate `#fbf4e4` |

Failure modes the recipe avoids:

1. **Too noisy** — busy baked specks + uniform scatter everywhere.
2. **All tiles the same** — one uniform wash, no macro zones.
3. **Vector-flat** — calm base + no mid texture -> digital fill.
4. **Canvas-filter** — dither applied uniformly (fine even grain over
   everything). Texture must COME AND GO: strong dithered patches
   alternating with quiet zones (grass out-of-patch scatter <=~0.08).

Density through **clustering**, variety through **large soft
gradients**, texture through **low-amplitude dither**. Props carry the
detail; ground supports it.

## Prop era spec — contemporary camping

**Era is 2026.** Camping equipment is contemporary: dome / pop-up
tents, cooler boxes, folding camp chairs, propane-butane stoves,
string lights, solar lanterns, dry bags, thermoses, insulated mugs,
folding tables, camp showers. Never heritage scout-camp reads on
*equipment*: no patched canvas wall tents, no rusted surplus.

**Neglect is told by nature, not aged gear.** The abandoned-site story
comes from overgrowth, moss, leaf litter, fallen branches, weeds over
pads — the *gear* a traveller brings is clean and new. Equipment wear
stays light (a scuff, dirt splash, a faded sticker); rust-out and
patched-canvas are banned on items.

**Minimalism — one silhouette + one accent.** A tent is a dome mass, a
door arc, maybe one guyline — not ropes + stakes + patches + poles all
at once. Every prop earns ~60-70% empty ground around it.

Camper van exception: the VW-shape van stays — a classic camper is a
contemporary lifestyle object. Canvas A-frames, the warden tent and
the brown tarp tent are superseded by `dome_tent_*` and retired to
`_superseded/`.

## World-art techniques

The gen model only understands visual descriptors — process words
("re-shade", "in layers", "never hue-swap") are ignored and dilute
real descriptors. Gens produce **subjects**; techniques run in the
deterministic pipeline:

| # | Technique | Rule | Mechanism |
|---|---|---|---|
| T1 | Foliage variants are re-shaded, never hue-swapped | Each palette variant gets its own highlight structure and dither | Derived via `tools/tb_variant.py`: segments the foliage colour family, remaps light/mid/shade ramps to the variant ramp. Silhouette preserved by construction; 0 gens; works on any shipped sprite |
| T2 | Trees ship in three layers | canopy · trunk · baked shadow | Gen canopy and trunk as separate cut-outs, composite + shadow via `tb_post`/staging tool. Variants land on canopy only |
| T3 | Prop grounding is systematic | Every placed prop gets ground blend at its base rim | Layout pass stamps 1-3 tuft decals per prop; contact shadow from `tb_post` |
| T4 | Water gets a ring, not a flat fill | Stone-ring edge band + low-frequency shimmer | Ring pieces = subject gen; shimmer frames = `tb_dither` pass on the water tile (0 gens), runtime frame swap |
| T5 | Cinematic != world | Painted vista art never enters the site scene | Cards/ceremonies/letterbox/title pull from the `SOURCES.md` shelf |

## UI recipe

> **The UI is a guest, not a host.** Every persistent pixel of chrome
> competes with the world.

Three-layer model:

| layer | contents | lifetime |
|---|---|---|
| spatial (in-world) | proximity bubbles, pad previews, pad markers, interact prompts | contextual |
| ambient chrome | pills (coins, day/weather, rating, journal) + phase button | persistent, fades to ~20% after 3s idle |
| on-demand panels | booking board, pantry, journal, outfitter, settings | full UI only when open |

Rules:

- **Look:** Eastward glass — frosted panels over the world. Cream
  paper only for speech bubbles.
- **Fonts:** Be Vietnam Pro (full Vietnamese coverage — pixel fonts
  are ASCII-only and cannot render VI). Pixel-font headings are
  ASCII-only cases.
- **Zones:** top corners = pills; bottom-right = THE verb (one action
  at a time, thumb zone); centre = never persistent.
- **Hierarchy:** one loud element at a time. Pills ambient, phase
  button prominent, bubbles contextual, banners transient.
- **Text:** art ships text-free; labels render at runtime (EN + VI
  lengths, diacritics).
- **Touch:** >=48dp targets, hit areas larger than art, safe-area
  aware.
- **Motion:** gentle — fade/slide ~200-300ms, nothing pulses or pops.
- **States:** every control has normal/pressed/disabled.
- **Diegesis:** panels open FROM world objects — booking board from
  the signboard, pantry from crates, journal from the warden's
  notebook. World and UI are one fiction.
- **Lifecycle:** HUD collapses while panels are open; one panel at a
  time; Android back closes top; bottom-third = primary actions.
- **Juice:** press squash on controls; coin count-up; panel
  slide/spring ~200-300ms; haptics hook points.
- **Designed states:** every panel gets empty/loading/error/first-run
  states. i18n: all labels externalized EN/VI. Accessibility: text
  scale, reduced-motion toggle, colorblind-safe accents.

Screen inventory authority: GDD §17.2 and `docs/UI_PRODUCTION.md`.

## Scene composition recipe

Maps are **systems** — road, nodes, boundaries — not decorated fields.

### Map grammar — the seven rules

1. **Spine:** one circulation artery enters the frame, connects the
   functional zones, and exits — implies a world beyond the frame.
   No dead-end stubs.
2. **Terrain = function:** ground type reads what an area is for —
   dirt = road/worked yard, stone = permanent paths/steps/shore ring,
   grass = yards/wild periphery. Zones are designed shapes, never
   decoration.
3. **Hero anchor:** one big structure organizes the space; everything
   else orients to it and to the spine.
4. **Sealed envelope:** the site's edge is readable — treeline, shore
   ring, fences, cliffs.
5. **Exit cues:** paths/stairs/roads leaving the frame in 2+
   directions.
6. **Furniture on the spine:** bench, mailbox, signpost, lanterns sit
   ON the circulation route, not mid-field.
7. **Density gradient:** busy at spine + anchors, breathing room at
   the periphery — never uniform scatter, never uniform emptiness.

### Layer stack — implementation order (bottom -> top)

| # | Layer | What | Implementation |
|---|-------|------|----------------|
| L-1 | Sky/vista | painterly sky + mountain depth layers | `create_map` strip, behind treeline |
| L0 | Terrain tiles | calm fills + transitions | wang sheets -> TileMapLayer |
| L1 | Terrain zones | function-shaped dirt/stone/grass regions | terrain set painting per zone shape |
| L2 | Ground texture | dither patches + tint field | `tb_dither.py` + `tb_tintmap` overlay |
| L3 | Boundaries | treeline band, shore ring, fences | prop placement, border role |
| L4 | Anchors | hero props (van, cabin, lodge) | `*_hero.png`, y-sort, embed pass |
| L5 | Mid props | functional cluster items | medium props, clustered at zones |
| L6 | Small functional items | dishes, tools, stepping stones, crop rows, signboards, fence runs — **the density layer** | small props, dense, ON the spine/zones |
| L7 | Decals + embed | terrain texture at feet | decals layer + embed overlap |
| L8 | Characters | NPCs, guests, animals | sprite layer, y-sort, anim |
| L9 | Lighting/grade | warm cast, AO, bounce | CanvasModulate + lighting |

**The L6 rule:** frames carry **60-80 visible objects** with a thick
small layer at 1-3% of frame width each. Density is not noise — smalls
are *functional*: stones mark paths, fences mark edges, dishes mark
kitchens, crops mark farms.

### Scale spec

- Characters: **<=12% of frame height** (~43-48 px at 360p) — enforced
  at gen time via `create_character_pro_flash`, never by rescale.
- Anchors: 20-40% frame width.
- Small items: 1-3% frame width each, 4-6 per anchor's footprint.
- Board: 640x360 world space, 32px terrain tile grid.

#### Canonical object ratios (measured from Octopia 1080p refs —
#### character ~115 px ~11% frame height)

Every asset is pinned to **CHAR = 48 px**. Ratios are content height
unless noted; before anchors/shadow.

| Class | xCHAR | Ship px | Examples |
|---|---|---|---|
| Dome tent / pitch | 2.4 w / 1.7 h | ~112x82 | dome_tent_* |
| Big structure | 2.5-4x | 120-200 | cabin, van, warden hut |
| Forest tree (total) | 2.5-3x | 120-150 | pines, T2 composites |
| Garden/farm tree | 1.5-1.8x | 72-86 | orchard/sapling scale |
| Bush / shrub | 0.9-1.4x | 44-66 | bush_*, fern_bank |
| Lamp post / signpost | 1.4-1.5x | 66-72 | lantern_post |
| Picnic/camp table | 1.0-1.2x w | 48-58 w | camp_table_fold |
| Chair / bench | 0.8-0.95x | 38-46 | folding_chair_pair |
| Ice chest / crate | 0.5 h / 1.0 w | ~26x46 | cooler_box, crates |
| Stove / grill | 0.45-0.6x | 24-32 | propane_stove |
| Handheld lantern | 0.3-0.4x | 15-20 | solar_lantern |
| Kettle / pot / radio | 0.4-0.6x | 20-28 | kettle, camp_radio |
| Mug / rope / pillow | 0.25-0.45x | 12-22 | enamel_mug, rope_coil |
| Rock / stump | 0.5-0.8x | 24-38 | rock_*, stump_* |
| Ground decal | 0.3-0.6x | 15-30 | decal_*, tuft_* |
| Fence segment | 0.5 h / 1.5 w | ~24x72 | fence runs |
| Signboard | 0.6-0.9x | 30-44 | signpost, stall board |
| Stall / food cart | 1.6-2.2x | 78-106 | pho_stall |
| Vehicle | 2-3x w | 96-144 w | outfitter_van, moped |
| Dog (pet) | 0.5-0.7x | 24-34 | Bean/Bo |
| Bird / critter | 0.15-0.3x | 8-15 | Field Notes species |
| Fish (prop) | 0.3-0.5x | 15-24 | fishing vignettes |
| Dish sprite | 0.2-0.35x | 10-17 | food dishes |
| Ingredient sprite | 0.15-0.3x | 8-15 | pantry icons |
| Portrait (UI) | n/a | 48-64 box | character portraits |
| Keepsake item | 0.3-0.5x | 15-24 | keepsakes |

Within +/-15% reads fine; >1.5x off reads wrong in-scene. True smalls
(<40 px ship) belong in <=42-px jobs — see PROMPT_PACK
native-resolution rule.

#### Canvas <-> content mapping (PixelLab discrete canvases)

Content fills ~80% of a gen canvas. Pick canvas by desired CONTENT:

| Target ship | Canvas | Resize |
|---|---|---|
| 32-40 px | <=42 | ~1:1 — ship at crop |
| 56-72 px | <=85 | ~1.1x max |
| 96-150 px | <=170 | ~1.1x max |
| <32 px | <=42 + "compact subject centred occupying about half the canvas" | ~1-1.3x |

Pipeline: crop to content bbox (lossless) -> ship at cropped size when
within +/-10% of ratio target -> else ONE resize <=1.3x. Never 2x+.

Ship resize is per-family: organic/curve-dominant props (tents,
canopies, bushes) -> LANCZOS; hard-edged items (cooler, stove, tools)
-> NEAREST.

### Forest wall spec — a boundary that reads as forest

A treeline is a layered canopy mass, not a row of spaced trees:

1. **Overlap crowns 40-60%** in 2-3 staggered rows.
2. **Mix 4-6 species per cluster** — deliberate colour spread inside
   one wall.
3. **Trunk gaps** between crowns — dark lines saying "there is space
   inside".
4. **Underbrush fills under crowns** — ferns, boulders, vines, tufts;
   the forest floor is never bare.
5. **Canopy = a shade mass** — the wall zone runs darker/cooler via
   tint map; the clearing is the light pool.
6. **The exit is a door in the wall** — gate built INTO the canopy +
   hanging lantern = the literal "trail leads onward" cue.
7. **Terracing** — stone retaining edges create height steps.
8. **Dressed water** — lily pads, mossy rocks, reeds at every shore;
   never bare pond rims.

### Busy-scene spec — the alive frame

1. **The crowd IS the density:** 12+ distinct NPCs per busy frame,
   each doing something, grouped in social clusters.
2. **Stall grammar:** awning + counter + DISPLAYED MERCHANDISE +
   price sign + vendor inside.
3. **Signage at density:** objects are labeled; walls are postered.
4. **Landmark thresholds:** zone transitions get hero architecture.
5. **Overhead layer:** wires/laundry/lantern strings between
   structures.
6. **Mood per district:** each district runs its own grade.
7. **Wear = traffic:** ground worn darkest where people actually
   stand.
8. **One-of-a-kind ornaments:** asymmetric ornate objects as focal
   punctuation — rare, never repeated.

## Lighting spec — 2.5D real lighting

### Visual recipe

1. **Darkness is a color:** night base = deep indigo-violet (~#2a2450),
   never grey-black. Day/night = a global grade shift.
2. **Light = colored pools:** soft falloff, ~2-3x source size, offset
   below the fixture. Hue per source: lamp cyan, doorway amber, neon
   magenta, fire ember-orange, tent windows warm.
3. **Grounding persists:** contact shadows survive inside pools.
4. **Light = wayfinding + staging:** pools land on the playable route
   and interaction spots only.
5. **Emissive surfaces:** glowing rects spill (tent windows lit from
   inside = the night money shot).
6. **Vignette:** soft edge-darken on the frame.

### Implementation

- `CanvasModulate` per phase: day warm -> dusk -> night indigo.
- `PointLight2D` at real sources — real attenuation + hue. Sprite
  pools only where engine lights are too costly.
- `LightOccluder2D` on trees/buildings/large props -> real cast
  shadows, directional per source.
- Normal maps on hero props from sprite luminance/edges (emboss);
  PointLight2D wraps forms.
- Warm bounce tint in prop shadow sides (form-shading pass).
- Repoussoir foreground leaf-mass layer at frame edges.
- Terrace side faces + aerial tint bands: elevation/depth planes.
- Pool intensity ramps by phase; pools placed on trail/pads/hub.

### Depth conventions

Two faces on every object (top+front visible); elevation terraces in
terrain; y-sort occlusion (chars walk behind trees); aerial
perspective on vista/backdrop layers.

## Character spec — the soul axis

- **Scale:** <=12% frame height via `create_character_pro_flash`,
  never by rescale.
- **Bespoke animation:** every named character/guest type gets its own
  anim set — idle quirks, not just walk cycles.
- **In context:** characters DO things — sit, read, fish, cook, pet
  the dog. Posed mid-activity; no idle standing crowds.
- **Living world:** scenes visibly change — guests arrive/leave, pads
  fill, phases redress, bubbles show needs.
- **Feedback complete:** every state change gets visual feedback.

## create_map usage policy

`create_map`/`edit_map`/`place_map_object` produce a FLAT painted
image — no tiles, no y-sort, no interaction. Approved uses only:

1. **L-1 vista backdrop** — painted sky+mountains strip behind the
   treeline.
2. **Trail Map screen art** — the site-network overview IS a painted
   map; menu asset, not gameplay.
3. **Direction frames** — painted comps of a target layout, judged
   BEFORE implementing in tilemap; concept art that de-risks a
   restructure.

NOT for: playable terrain (needs tiles/variants/y-sort/phase redress),
place_map_object composites (props need anchors+anim).

## PixelLab capability notes

Tool roles in this pipeline:

- `create_1_direction_object` — batch grid, the default for square
  props (4/16/64 slots at <=170/<=85/<=42 px, flat 15 gens/job).
- `create_character_pro_flash` — characters/directional sets.
- `create_object_state` / `inpaint_image` — multi-state props and
  surgical fixes (preferred over rerolls).
- `animate_object` / `vfx_workbench` — loops.
- `correct_pixelart` / `reduce_colors` / `unzoom_image` — the repair
  ladder before rerolls.
- `get_upload_url` / `save_to_asset` — upload our own art as a
  first-class style reference.
- `transfer_outfit` — persona variants from one base character.
- `create_map` / `create_tiles_pro` / `create_path_tiles` /
  `create_building_kit` — per the usage policy above.
- `create_portrait_character` / `set_character_portrait` — guest
  portraits.

`style_options.detail=false` exists only on Pro Flash tools — the
batch tool has no style toggles; calm comes from the crop + prompt
words.

Not our view/pipeline: isometric tiles, sidescroller sets.

## Craft spec — review rubric

Every prop/character/UI piece is judged against this table before
staging. This is also the craft-spec prompt block for hero art:

| dimension | target |
|---|---|
| value range | near-black darks to near-white lights inside the object |
| colors | 8-15, hue-shifted ramps (warm lit side, cool shadow side) |
| outlines | adaptive coloured per surface, never uniform black |
| internal shapes | rich — weathered dither, small parts, ~40 shapes on heroes |
| grounding | embedded — grass/decals overlap the base, wear nearby |
| shadow | directional with bounce-lit dark side, not flat ellipse |
| composition | storytelling clusters, asymmetric, imperfect |
| UI | dense content, nested borders, glass panels |

Prompt blocks (two variants — pick by subject era; never send the aged
block to 2026 camping equipment, and never send "embedded in ground"
to a cut-out — embedding is the pipeline's job, T3):

> **modern (equipment/props):** painterly pixel art prop, 3/4
> top-down straight-on front view — FULL VALUE RANGE (deep near-black
> shadows to bright highlights), hue-shifting colour ramps (warm lit
> side, cool shadow side), 8+ colours, thin adaptive dark outline
> matching each surface colour, calm interior masses with detail
> concentrated at the silhouette, clean new surfaces with light wear
> only (a scuff, a dirt splash, a faded sticker), handcrafted
> asymmetric detail, sun upper-left, interior detail density like a
> hand-painted miniature — not a clean icon

> **aged (keepsakes/ruins only):** same block but "weathered
> dithered surfaces (rust, wear, fabric, bark), small imperfections
> (lean, sag, patch)" in place of the clean-surfaces clause.

Working principle: **generate a competent base -> craft it up.**
Deterministic craft passes lift existing art at zero quota; generation
buys only what code cannot reach.

---

## Ground painting — Eastward grammar (measured 2026-10-14, ref ew_user_ref.png)

**The core pattern — a single diagonal ramp in (hue, sat, value) space:**
light pulls toward lemon-yellow, shadow pulls toward grey-olive. h, s, v
slide *together*, never independently:

| band | v | h | s |
|---|---|---|---|
| sun pool | 0.93-1.0 | 0.20 | 0.58 |
| lit | 0.85-0.93 | 0.234 | 0.55 |
| mid | 0.7-0.85 | 0.275 | 0.53 |
| deep/shade | 0.5-0.7 | 0.30 | 0.40 |

Sun pools are the default (~50-60% of grass), pockets the exception.

**Measured brush grammar:**
- moss dabs: 1-8px, median 4px, ~square/horizontal-biased (46% w>h), ~7/1000px, cover ~8% of grass — sparse seasoning
- sun pools: billow patches 60-150px, smooth organic edges — painted noise field, NOT tiles (autocorrelation decays smoothly, no 16px grid)
- rim stones: 3x4px pebbles (~12px sq), packed along waterline, occasional runs
- dirt dashes: 3x3px worn-grass marks, same hue family as grass
- water highlights: sparse 1-4px

**Water:** flat body v~0.62 rgb(45,157,128); north edge carries the
bank's shadow band (darker, rgb~45,132,103) — NOT a light sliver;
south edge = body. Water darker than grass (v0.62 vs v0.93) — it is
the frame's dark anchor mass, only ~9% of pixels (rim+ring expand the
visual mass to ~25%).

**Zone bands at waterline:** water -> 4-11px packed grey-blue rim
stones -> 10-20px olive shore ring -> field.

**Pipeline:** `tools/tb_paint_ground.lua` renders the layered ground
(zones | water | grass | dirt | shore | rim | shade) from a mask txt;
editable source `assets_src/pinewatch_ground_v2.aseprite`; flat zone
guide generated by python for repaint bases.

### Deeper structure (second pass)

- **Dabs are an edge treatment, not seasoning**: 107 dabs/1000px at
  sun-pool borders vs 0.4/1000 inside pool interiors. The billowy pool
  outlines are MADE OF the micro-texture; tone-field interiors stay clean.
- **Everything is horizontal**: 85-91% of elongated dabs sit within
  ±22deg of horizontal (both refs — it survives lighting changes).
  Sun pools themselves are horizontal clouds (w/h median 1.25-1.6).
- **The h/s/v ramp is a lighting rule, not a palette**: the overcast ref
  shows the same diagonal (h 0.34->0.25, s 0.27->0.44 as v rises) with
  the lemon end simply missing — exposure picks where on the diagonal
  the scene lives.
- **Rim band mass** concentrates 3-9px into land, tailing to ~20px.
- Water north edge = bank shadow band (darker than body); there is no
  north light sliver.

### The grammar is a light simulation (deepest pattern)

The ground isn't decorated noise — it's painted daylight dappling:

- deep pockets are CANOPY SHADOWS: median 4px from dark mass vs 17px
  overall; 21% shade within 20px of canopy, ~0% beyond 50px. Paint
  pockets only where the virtual canopy would cast (tree feet, corners).
- sun pools fall through CANOPY GAPS: 34% coverage below treeline gaps
  vs 20% below trees. Bright pools respond to openings, not randomness.
- dab hatching decays with distance from shadow (87/k at <20px ->
  20/k far) — it contours the light/shade boundary wherever they meet.
- zone boundaries stay CLEAN (3% dabs at dirt edges) — hatching is a
  light/shadow effect only; only water gets a constructed edge (rim).
- no tiling: 0 duplicate 32px blocks; FFT shows broad ~45px blob scale
  (the pool size), nothing periodic.
- implicit: pool field period ~45px, pools horizontally elongated.

## Shore/rim correction (zoom re-review)
- Rim stones are NOT 3x4 pebbles — they are chunky 8-14px OVERLAPPING boulders:
  grey-blue-teal body (112,136,145), lit top-left (160,185,170),
  dark plum outline/underside (45,38,60), occasional olive moss top.
- Boulders sit ON an olive shore band (~2-10px wide) hugging the waterline.
- Field interiors carry a fine grain: sparse 1px darker dots (~3% in
  sunpools, ~2% in lit) — flat-perfect fills read synthetic.
- Shoreline pass implemented in Pixelorama live session
  (pxo: assets_src/pxo/pinewatch_ground_v2_live.pxo).
