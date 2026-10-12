# Style lock — the Trailbound house look

Canonical reference: `assets_src/cleanup/pinewatch_engine_graded.png`
(the graded engine shot — the house style distilled).  Reference
teardown: `docs/reference/eastward.jpg`.

**Status: Pinewatch art is canonical & engine-verified.**  Every future
batch inherits this look — do not restyle per batch.

## Prompt language (bake into every description)

> **Superseded 2026-10-12 by `assets_src/prompts/PROMPT_PACK.md` §2**
> (house core v3 + site + class modules). The block below contradicts
> the approved v2 colour direction (it asks for muted water and gentle
> contrast) — kept only as a record of what batches 0–3 used.

> cozy pixel art in the style of Eastward with a Vietnamese
> pine-highland flavour: 3/4 top-down view, fronts drawn straight-on
> facing the viewer (not isometric), soft painterly shading, warm
> sunlight from the upper left, dark coloured outline, chunky readable
> shapes, no text or letters, muted desaturated olive-khaki grass,
> warm ochre earth, grey-teal muted water, warm filmic color cast,
> soft painterly dither, gentle contrast

## Style reference trick — do this for every gen job

Pass `assets_src/cleanup/pinewatch_engine_graded.png` (or a scene crop
of it) as the PixelLab **style reference image** instead of raw
`eastward.jpg`.  The engine shot already carries the sheet grade + the
warm `#f4ead3` multiply, so candidates come back *pre-graded* and the
HSV pass below only has to nudge, not drag.

## Post-gen grade (deterministic, applied to every pipeline copy)

```
generate -> tools/tb_grade.py --site X -> palette-snap (dE>30) -> stage -> integrate
```

`tools/tb_grade.py --site pinewatch_v2` (canonical — the shipped grade;
the old `pinewatch` v1 preset is kept in the script for archaeology):

| class | rule |
|---|---|
| grass | dh -2°, sat x0.80, val x1.21 — bright fresh yellow-green (~192,201,121) |
| dirt  | pull ->38° w0.60, sat x0.90, val x1.11 — warm ochre |
| water | hue +0, sat x0.80, val x1.04 — FRESH teal (~93,135,140) |
| stone | hue +8, sat x0.90 (grey px -> h38, s+0.07) — sandy |
| prop fallback (non-terrain `--target`) | +5° toward warm, sat x0.95, val x0.98 |
| warm multiply | `#fbf4e4` — light warm cast, NOT the old dark `#f4ead3` |

**Colour direction (2026-10-12, user review):** high-key and fresh —
bright sunlit grass, deep cool shade, wide value range, saturated teal
water.  Mute mid-value clutter, never the light.  v1 read "horror
movie" (over-muted); v2 is the approved target.

Snap target: `out/site_palette_v3.json` — light->mid->shade ramps per
family (grass #d4d587/#c0c879/#5a6e3c, water #68a5a5/#5d878c/#3e5157,
dirt #daad66/#c69553/#6d4c2b, warm #dad4bf/#968d75/#443e33).  The
tint-map overlay is a lighting layer — EXEMPT from snapping.

`--site river` / `--site valley` exist as TUNE-ME placeholders in the
script — tune them against their own reference shots before shipping.

The script grades **in place and is not idempotent** — always re-grade
from pristine (`--from-pristine`, or copy `gen/candidates/batch3/T{2,3,4}`
over the three terrain dirs) and verify `out/`, `game/assets/`, and
`staging/` end up byte-identical.

## Ground recipe (SOTA, decided 2026-10-12 after user review)

Researched sources: Pixpil's own notes ("tilemap is only used to build
the base wall/floor" — their fields are painted art + a lighting pass),
the Mytheria tech-art writeup, and common autotile practice.  The
principle every one of them shares:

> **Separate shape from colour.**  A calm repeating texture carries the
> *shape*; a low-frequency tint field carries the *colour*.  Macro
> variation is painted light/tonal zones — never tile swaps or dense
> scatter.

Canonical ground recipe for every site — THREE texture layers
(forensic-verified 2026-10-12 against eastward1/eastward-11 at 4x):

| layer | rule |
|---|---|
| base tile | low-detail tonal base — no baked tufts/flowers/specks (prompt for calm at gen time; `tb_calm.py` is rescue only) |
| **mid texture** | **dither patches, baked into tiles by `tools/tb_dither.py`** — irregular patch shapes (low-freq noise threshold) filled with single-pixel dither at +-1-2 ramp steps (~50-70% checker density); low amplitude (measured ref: dev_med ~2.6 dirt / ~7 grass); per-position seed so no two tiles share a pattern; apply to fill tiles AND the matching terrain regions inside transition tiles |
| macro variation | ONE baked 640x360 tint-map overlay: low-frequency noise -> soft warm/cool/dry zones + a few stronger sun pools/shade pools; alpha ~12-20%; continuous, ignores the tile grid |
| tile-swap zones | **forbidden** — 32px cell swaps produce jigsaw boundaries |
| edge interlock | dark rim already in wang transitions + sparse 1-3px blade strokes crossing grass->lower boundaries |
| decals | ~10-14 per 640x360 screen, clustered at edges/prop bases/shoreline only, ONE family per cluster, open-field interior empty |
| wear | small dirt patches under tents/fire/path mouth — ground tells a story |
| light | soft painted pools via the tint map + warm CanvasModulate `#fbf4e4` |

Failure modes (the recipe avoids all four):

1. **Too noisy** — busy baked specks + uniform scatter everywhere.
2. **All tiles the same** — one uniform wash, no macro zones.
3. **Vector-flat** — calm base + no mid texture -> digital fill.
4. **Canvas-filter** — dither applied uniformly (out-of-patch rate too
   high -> fine even grain over everything).  Texture must COME AND GO:
   strong dithered patches alternating with quiet zones (grass
   out-of-patch scatter <=~0.08).

Density through **clustering**, variety through **large soft gradients**,
texture through **low-amplitude dither**.  Props carry the detail;
ground supports it.

## Prop era spec (decided 2026-10-12 — contemporary camping, not heritage)

Reference: Eastward: Octopia camp frames — the gear reads modern
through *silhouette*, not clutter.

**Era is 2026.**  Camping equipment is contemporary: dome / pop-up
tents, cooler boxes, folding camp chairs, propane-butane stoves,
string lights, solar lanterns, dry bags, thermoses, insulated mugs,
folding tables, camp showers.  NOT heritage scout-camp: no patched
canvas wall tents on wood poles, no rusted enamel-surplus reads on
*equipment*.

**Neglect is told by nature, not aged gear.**  The abandoned-site
story comes from overgrowth, moss, leaf litter, fallen branches and
weeds over pads — the *gear* a traveller brings is clean and new.
Equipment wear stays light (a scuff, dirt splash, a faded sticker);
rust-out and patched-canvas are era cues and are banned on items.

**Minimalism — one silhouette + one accent.**  A tent is a dome mass,
a door arc, maybe one guyline — not ropes + stakes + patches + poles
all at once.  Every prop earns ~60–70% empty ground around it; the
Octopia frames keep props sparse and let each object read alone.

Camper van exception: the VW-shape van stays — a classic camper is a
contemporary lifestyle object (same family as Octopia's RV), not an
"ancient" one.  The shipped canvas A-frame pad tents, the warden tent
and the brown tarp tent are queued for re-authoring as modern domes —
that is a prop-art regen, not a layout change.

## UI recipe (SOTA, decided 2026-10-12 — cozy HUD discipline)

Research: cozy-UI guides ("great game UI disappears — start with nothing,
justify every element"), the Fagerholt diegetic taxonomy, mobile-landscape
patterns, Pixpil interviews, GDD §17.  Core philosophy:

> **The UI is a guest, not a host.**  Cozy games sell resting — every
> persistent pixel of chrome competes with the world.

Three-layer model:

| layer | contents | lifetime |
|---|---|---|
| spatial (in-world) | proximity bubbles, ★ pad previews, pad markers, interact prompts | contextual — appear near the object, vanish on leave |
| ambient chrome | 4 pills (coins, day/weather, rating, journal) + phase button + medallion | persistent but fades to ~20% after 3s idle |
| on-demand panels | booking board, pantry, journal, outfitter, settings | full UI only when open — ALL complexity lives here |

Rules:

- **Zones:** top corners = pills; bottom-right = THE verb (phase button,
  thumb zone, one action at a time); centre = never persistent.
- **Hierarchy:** one loud element at a time.  Pills ambient, phase
  button prominent, bubbles contextual, banners transient.
- **Physicality:** panels read as objects — cream paper, wood trim,
  red lacquer seal, stamped cards; generous margins, tactile chunk.
- **Text:** art ships text-free; labels render at runtime
  (EN + VI lengths, diacritics — pixel font headings, sans body).
- **Touch:** >=48dp targets, hit areas larger than art, safe-area aware.
- **Motion:** gentle — fade/slide, ~200-300ms, nothing pulses or pops.
- **States:** every control has normal/pressed/disabled; star preview
  is the pre-commit feedback pattern.

## Production UI spec (decided 2026-10-12 — scope beyond chrome)

> **Under reconciliation (UI audit 2026-10-12, `docs/UI_PRODUCTION.md`
> §3).** Time controls, food/rest/social need-bubbles, the booking
> calendar, stay length/mood and the alert rail contradict GDD §4/§5 and
> are withdrawn. Screen list authority is GDD §17.2. "48dp+ everywhere
> (already met)" was false (UI-005). Star row, close X, back and settings
> icons already exist (I1_1–3, 13, 15, 12). **D-UI-1 decided: Eastward
> glass** — the cream-paper panel kit and the "Physicality: cream paper,
> wood trim" rule above retire; cream stays only for speech bubbles.
> Fonts: Be Vietnam Pro family, hi-res (D-UI-2). Glass spec v0 and the
> lacquer-tint proposal: `docs/UI_PRODUCTION.md` §8.1. Rewrite = UI-010.

Benchmark formula: Eastward diegesis x Bear&Breakfast management
clarity x Two Point alert discipline x mobile touch ergonomics.
Current state: HUD chrome ~15% of a production UI — style is right,
scope is the gap. All items build on the existing atlas/fonts.

### The panel suite (the game lives here)

- **Booking Board** — arrivals/departures calendar, the money screen
- **Guest Inspector** — tap guest → bottom-sheet: needs, prefs, stay
  length, rating, mood
- **Pad Inspector** — tap pad → status, occupant, upgrade options
- **Build mode** — catalog rail + placement ghost + rotate/confirm/
  cancel + cost preview
- **Pantry/Kitchen** — stock levels, orders, meal prep queue
- **Day-end Report** — income, ratings, events recap (retention hook)
- **Trail Map** — site network overview; the signature screen
- **Settings** — standard

### The diegetic layer (the Eastward rule)

Panels open FROM world objects — booking board opens from the
signboard prop, pantry from supply crates, journal from the warden's
notebook. World and UI are one fiction, never overlaid chrome.

### In-world feedback (floating layer, not chrome)

- **Need-bubbles** over guests — food / rest / social icons (the
  Cozy Grove request pattern; evolved from our TALK bubble)
- **Floaters** — +N coins, mood icons, hearts on petting, star
  twinkle on rating change
- **Inspector ring** — selected-object highlight, tap-anything model

### Alert rail + time

- Queued priority alerts (guest unhappy / food out / pad ready) —
  icon rail, Two Point discipline; toast stays for confirmations
- Time controls: pause / 1x / 2x speed — management standard

### Lifecycle rules

- HUD collapses/fades while panels are open (context-aware)
- Modal stack: one panel at a time; Android back-button closes top
- Safe areas respected; bottom-third = primary actions

### Juice spec (cheap, mandatory)

- Press squash on all controls; coin count-up on income; panel
  slide/spring in (~200-300ms, per Motion rule); completion confetti;
  defined sound-hook points (no audio assets yet)

### Designed states + pipeline

- Every panel: empty / loading / error / first-run states designed,
  never default
- Onboarding: coach-mark system for first run
- i18n: ALL labels externalized EN/VI — zero hardcoded strings
- Accessibility: text scale, reduced-motion toggle, colorblind-safe
  accent pairs, 48dp+ everywhere (already met)

### Component + system gap inventory (UI audit 2026-10-12)

Verdict: style SOTA (atlas paper-kit ~90%), chrome ~75%, component
coverage ~40%, systems ~25%, screens ~15%. Atlas = 27 pieces, heavy
on bubbles/medallions, thin on structure.

**Missing components:**
- Structural: tab bar, list rows, scrollbar, dividers, modal dimmer,
  bottom-sheet w/ handle, back arrow, close X, icon buttons
- Data display: progress/track bars, badge/count chips, star rating
  row (full/half/empty), need icons (food/rest/social), calendar
  cells, queue cards
- Inputs: toggle, slider, quantity stepper, checkbox, dropdown,
  filter chips
- Feedback: tooltip card, inspector ring, alert bell + severity
  icons, notification dot, coach-mark ring
- Signature: DIALOGUE PANEL (nameplate + portrait + text + tail —
  compose from bubble pieces), PORTRAIT FRAMES (guest faces via
  create_portrait_character — soul axis applied to UI), speed
  controls (pause/1x/2x), menu/settings entry button (none exists!)

**Missing systems:**
- Design tokens: 4px spacing grid, elevation tiers
  (HUD < panel < modal+dimmer), named color tokens
- Type scale: display/heading/body/caption/mono-numbers
- Motion per component: sheet slide-up, dialog scale-in, toast
  slide, count-up, ring pulse (beyond the 200-300ms rule)
- Focus/selection model: ring + focus order (inspector pattern)
- i18n: VI strings ~30% longer — externalize + size for expansion
- Debug flag: dev line must not render in production shots
- Haptics hook points: press/confirm/pay

**Build order:** tokens + missing atlas pieces (~15 gens ornaments,
rest layout code) → Guest Inspector + Dialogue Panel as flagship
screens (exercise sheet/portrait/icons/stars/rows) → rest of suite.

## Scene composition recipe (SOTA, decided 2026-10-12 — map grammar)

Forensically decoded from all six Eastward references. Their maps are
**systems** — road, nodes, boundaries — not decorated fields. Two parts:
the *grammar* (how space is organized) and the *layer stack* (how it's
built in our pipeline).

### Map grammar — the seven rules

1. **Spine:** one circulation artery (dirt road / trail) enters the
   frame, connects the functional zones, and exits — it implies a world
   beyond the frame. For Trailbound this is literal: trailhead in,
   trail to the next site out. No dead-end stubs.
2. **Terrain = function:** ground type reads *what an area is for* —
   dirt = road/worked yard, stone = permanent paths/steps/shore ring,
   grass = yards/wild periphery. Zones are designed shapes, never
   decoration. (Our tint zones handle mood; tile zones handle function.)
3. **Hero anchor:** one big structure organizes the space (inn, bus,
   lodge). Everything else orients to it and to the spine.
4. **Sealed envelope:** the site's edge is readable — treeline, shore
   ring, fences, cliffs. Player knows where inside ends.
5. **Exit cues:** paths/stairs/roads leaving the frame in 2+ directions.
6. **Furniture on the spine:** bench, mailbox, signpost, lanterns sit
   ON the circulation route, not mid-field.
7. **Density gradient:** busy at spine + anchors, breathing room at
   the periphery — never uniform scatter, never uniform emptiness.

### The layer stack — implementation order (bottom → top)

| # | Layer | What | Our implementation |
|---|-------|------|--------------------|
| L-1 | Sky/vista | painterly sky + mountain depth layers | `create_map` strip, behind treeline |
| L0 | Terrain tiles | calm fills + transitions | wang sheets → TileMapLayer |
| L1 | Terrain zones | function-shaped dirt/stone/grass regions | terrain set painting per zone shape |
| L2 | Ground texture | dither patches + tint field | `tb_dither.py` + `tb_tintmap` overlay |
| L3 | Boundaries | treeline band, shore ring, fences | prop placement, border role |
| L4 | Anchors | hero props (van, cabin, lodge) | `*_hero.png`, y-sort, embed pass |
| L5 | Mid props | functional cluster items (table, crates, coop) | medium props, clustered at zones |
| L6 | **Small functional items** | dishes, tools, stepping stones, crop rows, signboards, fence runs — **the "more detailed" layer** | small props, dense, ON the spine/zones |
| L7 | Decals + embed | terrain texture at feet, tufts breaking bases | decals layer + `tb_embed` overlap |
| L8 | Characters | NPCs, guests, animals | sprite layer, y-sort, anim |
| L9 | Lighting/grade | warm cast, AO, bounce | CanvasModulate + prop shading pass |

**The L6 rule (the ratio fix):** reference frames carry **60–80 visible
objects** with a thick small layer at **1–3% of frame width each**
(radish ~15px, crops ~22px, mailbox ~45px at 1568×880). Density is not
noise — smalls are *functional*: stones mark paths, fences mark edges,
dishes mark kitchens, crops mark farms. Sparseness at L6 is why ours
read "big and empty" even with good anchors.

### Scale spec

- Characters: **≤12% of frame height** (ours run 15% — flagged, fix at
  next char regen, not by rescale)
- Anchors: 20–40% frame width is correct territory
- Small items: 1–3% frame width each, 4–6 per anchor's footprint
- Pixel budget: every object carries internal detail per Craft spec

*Mobile SOTA check (2026-10-12): base-res + character-share benchmarked
against shipped peers — Eastward renders at 360p (Pixpil patch notes +
Steam teardown), Stardew/Terraria ship 16px tiles with pinch/button
zoom, Kairosoft's keitai engine ran 240×135–240×240, Into the Breach's
Netflix port chose 64px tiles for board legibility, and the pixeli
proportion rules put characters at ~10–16% of screen height for
top-down. Our 640×360 / 32px-tile / 43px-figure (12%) spec sits inside
that band — the scale spec is validated, not the current oversized
warden sprite. 24px tiles would move toward the open-world density
branch (needs zoom to compensate) — wrong branch for a fixed board.*

### Pinewatch gap list (what the restructure must deliver)

- [ ] Real spine: trailhead (bottom) → road → fire hub → branches to
      van/pads/work edge → trail exit through treeline gap (north)
- [ ] Terrain=function zones: dirt yard at hub+road, stone shore ring +
      dock at pond, grass periphery
- [ ] Boundaries: treeline w/ single gap (north trail), shore ring,
      fence runs at site edge
- [ ] Anchors face the road: van at trailhead, fire at junction
- [ ] Furniture on spine: signpost AT junction, lanterns on road,
      bench at hub
- [ ] L6 density: ~60–80 objects; deploy staged smalls functionally +
      gen the missing types (fences, stepping stones, dishes/tools,
      signboards) — the only planned spend (~25 gens)

### Deep-cut detail spec (forensic pass 2 — every small thing)

Details found re-reviewing all references at native res. Cost-mapped.

1. **Sky/vista backdrop (L-1, above treeline):** painterly sky +
   volumetric clouds + mountain silhouettes in ~3 aerial-perspective
   layers (near saturated → far pale/cool). Deliberately soft/painterly
   vs pixel-crisp playfield — the contrast IS the depth signal.
   Implement: `create_map` painted backdrop strip (~10-15 gens).
   Refinements from the sky-vista decode: **repoussoir framing** —
   dark foliage masses at frame edges pushing the eye to the lit
   center; aerial order far=pale-blue → near=saturated-green →
   foreground=darkest; sky MORE saturated than playfield. **Vista as
   staging:** the north trail gap should reveal a sliver of vista —
   the "world out there" hook.
2. **Characters in context:** NPCs use furniture and do things (guests
   SIT on the bench, one reads). Posed mid-activity, never idle
   standing. Placement + pose anims (free now, anims later).
3. **Ambient critters:** birds perched on roof ridges, chickens at
   pens, ducks on water — tiny life accents (~5 gens in L6 batch).
4. **Building massing + overgrowth:** multi-mass structures with
   lean-to annexes, varied rooflines, moss in roof tiles, vines eating
   walls. Nature integrates architecture (~10 gens inpaint).
5. **Diegetic signage:** every building labeled in-world — noren
   curtain glyph, vertical signboard, shop sign, mailbox. Signs ARE
   street furniture (L6 batch).
6. **Ordered functional plots:** raised bed + stone border + ordered
   crop rows — designed cultivation reads "someone works here"
   instantly (L6 batch + placement).
7. **Two+ fence vocabularies:** bamboo vs plank vs stone — different
   fence types per zone, not one generic boundary (L6 batch).
8. **Road wear:** worn center / wheel-track band in the dirt spine —
   use marks baked into circulation (decals, free).
9. **Tree variety:** 5+ species per frame, deliberate color spread
   (one accent/autumn tree per scene). We run pines + flamboyant;
   add 2-3 species (~15 gens).
10. **Debris halos:** fallen leaves under accent trees, petals under
    bloom trees — feature trees get ground debris (decals, free).
11. **Saturated accent props:** a red mailbox/noren — small saturated
    punctuation planted in the green field (L6 batch).
12. **Surface clutter on structures:** hanging pots, stacked goods at
    doorways, items visible inside dark storefronts — "inhabited"
    dressing (inpaint or L6 smalls).

### Forest wall spec (EW_147 decode — boundary that reads as forest)

A treeline is NOT a row of spaced trees — it is a layered canopy mass:

1. **Overlap crowns 40-60%** in 2-3 staggered rows — foliage
   interweaves into a wall, reads as depth not a fence line.
2. **Mix 4-6 species per cluster** (bamboo culms, birch/autumn, round
   fluffy crowns, feathery droop, pines) — deliberate color spread
   inside one wall.
3. **Trunk gaps:** vertical trunks visible BETWEEN crowns — dark
   lines that say "there is space inside" (y-sorted trunk layers).
4. **Underbrush fills under crowns:** ferns, mossy boulders, vines,
   grass tufts — the forest floor is never bare.
5. **Canopy = a shade mass:** the wall zone runs darker/cooler via
   tint map; the clearing is the light pool.
6. **The exit is a DOOR IN THE WALL:** a wooden gate built INTO the
   canopy + hanging lantern = the literal "trail leads onward" cue.
7. **Terracing:** stone retaining edges create height steps between
   clearing and forest-floor levels.
8. **Dressed water:** lily pads, mossy rocks, reeds at every shore —
   never bare pond rims.

### Busy-scene spec (New Dam City market decode — the alive frame)

1. **The crowd IS the density:** 12+ distinct NPCs per busy frame,
   each doing something — vendors inside stalls, browsers at
   counters, a kid trio conversing. People grouped in social
   clusters, not scattered solos.
2. **Stall grammar:** every stall is a composed object — patterned
   awning + counter + DISPLAYED MERCHANDISE (crates of produce, jar
   rows, hanging strips) + price sign + vendor inside. Goods are the
   L6 layer on surfaces.
3. **Signage max density:** ~15 readable surfaces per frame —
   vertical signs, painted wall text, price tags, posters, glyphs.
   Objects are labeled; walls are postered.
4. **Landmark thresholds:** zone transitions get ornate hero
   architecture (twin-dragon gate + sign). The threshold IS a
   landmark, not a signpost.
5. **Overhead layer:** wires/laundry/lantern strings between
   structures — a second clutter layer above head height.
6. **Mood per district:** each district runs its own grade (market =
   cool blue-green vs village = warm sunny). Site presets vary MOOD,
   not just hue. Few saturated accents punch through the muted base.
7. **Wear = traffic:** ground worn darkest where people actually
   stand — under stalls, at counters, on walking lines. Use-pattern,
   never decoration.
8. **One-of-a-kind ornaments:** asymmetric ornate objects (dragon
   columns) as focal punctuation — rare, never repeated.

## Lighting spec (EW night-scene decode 2026-10-12 — 2.5D real lighting)

The Eastward depth secret: their engine runs REAL dynamic 2D
lighting — sprites carry light-response data, props cast real
directional shadows. It reads 3D because the light behaves like a
3D scene. We implement the same with Godot's native 2D stack —
deterministic, zero generation.

### The visual recipe (unchanged)

1. **Darkness is a color:** night base = deep indigo-violet
   (~#2a2450), never grey-black. Day/night = a global GRADE shift.
2. **Light = colored pools:** soft falloff on the ground plane, ~2-3x
   source size, offset below the fixture. Hue per source: lamp cyan,
   doorway amber, neon magenta, fire ember-orange, tent windows warm.
3. **Grounding persists:** contact shadows survive inside pools.
4. **Light = wayfinding + staging:** pools land on the playable
   route and interaction spots only.
5. **Emissive surfaces:** glowing rects spill (tent windows lit from
   inside = the night money shot).
6. **Vignette:** soft edge-darken on the frame.

### The 2.5D implementation (the depth upgrade)

- `CanvasModulate` per phase: day warm → dusk → night indigo.
- `PointLight2D` at real sources (fire flicker via seeded sin+noise,
  lantern posts, tent windows, signboard) — real attenuation + hue,
  not sprite pools. Sprite pools only where engine lights are too
  costly (vista fill).
- `LightOccluder2D` on trees/buildings/large props → REAL cast
  shadows, directional per source.
- **Normal maps on hero props** — generated cheaply from sprite
  luminance/edges (emboss); PointLight2D then wraps forms. ~70-80%
  of Eastward's hand-normal look, no artisan cost.
- Warm bounce tint in prop shadow sides (form-shading pass) — the
  roundness cue.
- Repoussoir foreground leaf-mass layer at frame edges (~5 gens).
- Terrace side faces + aerial tint bands: elevation/depth planes.
- Pool intensity ramps by phase; pools placed on trail/pads/hub.

### Supporting depth conventions (from all refs)

Two-faces on every object (top+front visible) — already drawn;
elevation terraces in terrain; y-sort occlusion (chars walk behind
trees); aerial perspective on vista/backdrop layers.

## Character spec (the soul axis — RPS review decode 2026-10-12)

External confirmation: Eastward's lasting praise is its CAST — "every
smallest character gets bespoke animations," NPCs are why it is
remembered, not the tiles. Rules for our characters/guests:

- **Scale:** ≤12% frame height (ours run ~15% — fix at next char
  regen with `create_character_pro_flash`, never by rescale).
- **Bespoke animation:** every named character/guest type gets its own
  anim set — idle quirks, not just walk cycles. Reviewers notice
  animation craft above all else.
- **In context:** characters DO things — sit on benches, read, fish,
  cook, pet the dog. Posed mid-activity; no idle standing crowds.
- **Living world:** scenes must visibly change — guests arrive/leave,
  pads fill, phases redress, bubbles show needs. A beautiful frozen
  diorama fails the spec.
- **Feedback complete:** every state change gets visual (and later
  audio) feedback — Eastward's one criticized gap was a missing
  warning sting. We out-feedback them.

## Style-ref crop library (assets_src/refs/crops/)

43 purpose-organized crops from the 10 decoded references —
manifest.json maps each crop → source rect → purpose → suggested
gen canvas size. Categories: tree(5) building(4) ground(4) prop(5)
water(2) forest(3) stall(3) crowd/gate/sign/goods vehicle cluster
zone char vista(4) light(4).

Usage rules: crops teach LOOK (palette/outline/shading), prompts
teach CONTENT — always crop to the subject, never style a 64px
object from a full scene; resize the crop to the target canvas
(style image must fit native canvas); `style_options.detail=false`
when copying from busy refs. For shipped assets prefer OUR graded
comps as style refs — self-reinforcing, no external-art dependency.
Eastward crops are for R&D/direction only.

## create_map usage policy (decided 2026-10-12)

`create_map`/`edit_map`/`place_map_object` produce a FLAT painted
image — no tiles, no y-sort, no interaction. Approved uses ONLY:

1. **L-1 vista backdrop** — painted sky+mountains strip behind the
   treeline (decorative far layer; ~10-15 gens).
2. **Trail Map screen art** — the site-network overview IS a painted
   map; menu asset, not gameplay (~10 gens).
3. **Direction frames** — 1-2 painted comps of the target layout,
   judged BEFORE implementing in tilemap; concept art that de-risks
   the restructure (~10-20 gens).

NOT for: playable terrain (needs tilemap data/variants/y-sort/phase
redress), place_map_object composites (props need anchors+anim).

## PixelLab capability notes (audited 2026-10-12 — 108 MCP tools)

New since batch 3 — tools that serve this style lock:

- `create_image_pro_flash` / `create_object_pro_flash` /
  `create_character_pro_flash` / `edit_image_pro_flash` — take a
  `style_image` PLUS `style_options` toggling color_palette / outline /
  detail / shading INDEPENDENTLY.  **Default for future gens:**
  `style_image = graded comp`, `detail=false` — copy palette+outline
  +shading, keep detail calm.  This is "generate calm, don't blur busy"
  enforced inside the tool.
- `get_upload_url` / `save_to_asset` — upload our own art as a
  first-class style reference (`source_image_id`).
- `inpaint_image` / `inpaint_image_pro_flash` — masked surgical fixes;
  use for prop touch-ups instead of full regens (10-25 gens).
- `create_map` / `edit_map` / `place_map_object` — full painted-scene
  composition; pilot for backdrop/depth layers.
- `create_tiles_pro` / `create_path_tiles` / `create_building_kit` —
  newer pro terrain/path/building gens for future sites.
- `create_portrait_character` / `set_character_portrait` — guest
  portraits for the U4 guest cards.
- `transfer_outfit`, `create_8_direction_object`, `reduce_colors`,
  `correct_pixelart`, `unzoom_image`, `create_vocal_animation`.
- Pro tier price cut (Oct 2026): 20/25/40 -> 10/15/25 gens by size.

Not our view/pipeline: isometric tiles, sidescroller sets.

## Craft spec — what "full craft" means (review rubric)

Every prop/character/UI piece is judged against this table before
staging.  This is also the craft-spec prompt block for hero art:

| dimension | target |
|---|---|
| value range | near-black darks to near-white lights inside the object |
| colors | 8-15, hue-shifted ramps (warm lit side, cool shadow side) |
| outlines | adaptive coloured per surface, never uniform black |
| internal shapes | rich — weathered dither, small parts, ~40 shapes on heroes |
| grounding | embedded — grass/decals overlap the base, wear nearby |
| shadow | directional with bounce-lit dark side, not flat ellipse |
| composition | storytelling clusters, asymmetric, imperfect |
| UI | dense content, nested borders, paper texture, seals |

Prompt block (append to hero-prop prompts):

> painterly pixel art prop, 3/4 top-down straight-on front view —
> FULL VALUE RANGE (deep near-black shadows to bright highlights),
> hue-shifting colour ramps (warm lit side, cool shadow side),
> 8+ colours, adaptive dark outline matching each surface colour,
> weathered dithered surfaces (rust, wear, fabric, bark), handcrafted
> asymmetric detail, small imperfections (lean, sag, patch), object
> partially embedded in ground, sun upper-left, interior detail
> density like a hand-painted miniature — not a clean icon

Working principle: **generate a competent base -> craft it up.**
Deterministic craft passes (form shading, embedding, clustering, UI
enrich) lift existing art at zero quota; generation buys only what
code cannot reach.
