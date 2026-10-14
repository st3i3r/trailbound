# Prompt pack v3 — every remaining generated asset

Source of truth for generation prompts from 2026-10-12. Each job is
assembled as **HOUSE + SITE + CLASS + content line** (§2). Per-batch job
files (`batchN.json`, harness `tools/pixellab_mcp.py`) are built from this
pack at execution time; this file is what gets reviewed. Rosters come from
`game/data/*.json`, not guesses.

## 1. Review of the current prompt system

| # | Finding | Evidence | Fix in v3 |
|---|---|---|---|
| 1 | House block contradicts the approved colour direction | style_lock "Prompt language" says *muted desaturated olive-khaki grass, grey-teal muted water, gentle contrast*; colour direction v2 (user, 2026-10-12) says *high-key, fresh, wide value range* and v1 read "horror movie"; the craft spec demands *FULL VALUE RANGE* | New house core (§2.1) |
| 2 | Site flavour hard-coded | "Vietnamese pine-highland flavour" in every prompt — wrong for Whisper River, Lantern Valley, Sơn Trà | Site modules (§2.2) |
| 3 | Ground colour words leak into object prompts | Stools, kettles, tents all carried "olive-khaki grass, ochre earth, teal water" | Terrain words only in terrain prompts |
| 4 | Characters under-specified and too tall | C1–C3 are one line each, no proportion or size discipline; 64 px canvas → warden 57 px (15.8%) vs ≤12% (≈43 px) | Character class (§2.3): 48×48 canvas, figure ≈90% of height |
| 5 | View parameter inconsistent | "top-down" / "low top-down" / "high top-down" mixed | Tiles `high top-down`; Pro Flash objects + characters `low top-down` (classic 3/4); batch tool only offers `top-down` |
| 6 | Obsolete jobs | U1–U5 paper UI, I1 chrome icons, F1 font | Retired (D-UI-1/2/5) — no UI panel or font gens |
| 7 | Signage vs "no text" | Batch A needs sign/menu/price boards | Blank faces in art; text drawn at runtime in Be Vietnam Pro (localizes EN/VI) |
| 8 | Opaque output names | Shipped props are `S_10`, `M1_5`, `XS_33` — same smell as the I1 icons | Every slot gets a semantic `item_names` id in the job file |
| 9 | Cost model unused | Verified quotes (`get_pro_flash_capabilities`): Pro Flash = **5 gens per image** (≤96 px), 6 at 128–192, 9 at 256×128; character 8-dir = 6. Batch tool `create_1_direction_object` = ~10 gens per job for **64 items (≤42 px) / 16 (≤85) / 4 (≤170)** | ~~Batch tool for every square ≤170 px set~~ **REVERSED (2026-10-16, Batch E pilot):** `create_1_direction_object` produces soft-shaded generic illustrations — no `style_options`, style_images only set canvas size and copy loosely, thin grammar drifts off-palette. Shipped sprites/icons/props ALWAYS go `create_object_pro_flash` + Eastward craft BLOCK + same-size graded style ref + downstream grade+lock. The batch tool is only for throwaway candidate scouting, never for shipped art |
| 10 | Data → art gaps not in the manifest | Decor without art: Flower Arch, Reed Screen, Dog Bed, Stone Fire Pit, Scout Pennant, Koi Pond, Photo Wall, Kite Line (flying); Warden's Hut restoration stages (§8.4); camp tier-ups (§6.7); Clear debris and overgrown pads (§5.1); tent/cabin night states; festival packs and the Music Night band (§13.5) | Batches E, H, I below |
| 11 | Identity conflicts the prompts would bake in | Field Notes birds are mostly European species (Eurasian Jay, Tawny Owl, White-throated Dipper, Eurasian Skylark, European Bee-eater…) — only the bulbul is distinctly Vietnamese | Decision D-PP-1 (§5) before Batch C |
| 12 | GDD vs style lock on character size | GDD §16.2 "about 48 px tall in 64×64"; style lock ≤12% | GDD §16.2 aligned to ≈43 px in 48×48 |

## 2. Prompt architecture

### 2.1 House core v3 (every job)

> painterly pixel art in the style of Eastward, 3/4 top-down view with
> fronts drawn straight-on (not isometric), sunlight from the upper left,
> full value range from deep cool shadows to bright warm highlights,
> hue-shifted colour ramps, adaptive dark coloured outlines (never pure
> black), chunky readable silhouette, handcrafted imperfect detail,
> contemporary everyday objects and clothing of the 2020s — never
> antique, medieval or vintage surplus gear, no text, no letters, no
> numbers

Cut-out clause (objects, characters, items):
> single subject centred on a transparent background, no ground plane, no
> cast shadow, nothing cropped at the edges

Contact shadows and anchors are baked afterwards by `tools/tb_post.py`,
grade by `tools/tb_grade.py` — never prompt shadows on cut-outs.

### 2.2 Site modules

| Site | Module |
|---|---|
| Pinewatch | cool highland pine forest with red-ochre earth and wild sunflowers, bright fresh daylight greens, ember-orange accents |
| Whisper River | river valley with bamboo groves and lotus ponds, fresh teal water, humid bright greens |
| Lantern Valley | terraced hill valley at golden hour, warm meadow gold, dusk-violet shadows, silk lanterns |
| Sơn Trà Shore (SB-2) | tropical coastal jungle above a white-sand fishing beach, bright marine teal, deep jungle green, coral accents |

Cast, food, fauna and keepsakes are site-neutral: no site module.

### 2.3 Class modules

| Class | Tool and canvas | Module (appended) |
|---|---|---|
| Terrain | `create_topdown_tileset` pro, 32 px, `high top-down` | calm low-detail ground wash, large soft tonal patches, no flowers, no tufts, no speckles, no repeating motif; for shore tiles: mossy stone ring edging the water, not a plain fill *(pipeline: detail from `tb_dither` + decals; shimmer frames are derived, T4)* |
| Hero prop / structure | Batch tool ≤170 (4 slots, 128–160 style refs); Pro Flash custom for non-square | hand-painted miniature density, contemporary 2026 camping equipment (dome tents, coolers, chairs, stoves — never patched canvas / rusted surplus), clean surfaces with light wear (scuffs, dirt splash), one strong silhouette with one accent detail, top and front faces both visible, calm interior masses with detail at the silhouette, thin adaptive coloured outline |
| Small item (L6) | Batch tool ≤42 (64 slots, 32 px refs) or ≤85 (16 slots, 64 px refs) | small and simple, readable at 1×, two or three tones plus outline, one clear silhouette, no fine noise |
| Foliage / tree | Batch tool ≤170 | leaf masses as clumps (not single dots), lit top-left rim, cool shaded underside, visible trunk and root flare *(pipeline: canopy + trunk gen'd as two separate cut-outs, composited by `tb_post`, T2; colour variants are `tb_variant` ramp-swaps, never re-gen'd, T1)* |
| Character | `create_character_pro_flash` 48×48, `low top-down`, template `mannequin`, 8 directions, `style_options.detail=false` | full body about 3.5 heads tall filling about 90% of the canvas height, readable face with simple eyes, distinctive silhouette with one signature colour, clothing folds in two or three tones, relaxed standing pose facing south |
| Child | same, 48×48 | child about two-thirds adult height, figure fills about 60% of the canvas height |
| Persona | Character class + | an ordinary person on a weekend nature trip, everyday clothes (not hiking gear unless stated) |
| Animal (dog, cat) | `create_character_pro_flash` 48×48, template `dog` / `cat` | expressive ears and tail, soft fur in two-tone clumps |
| Small fauna / item icon | Batch tool ≤42 at 32 px | one subject, 3/4 view, rich appetising colour, a cream highlight on the lit edge (the sticker outline is added by script) |
| Hero item (result card, Field Notes) | Batch tool ≤85 at 64 px | same as item icon, with more interior detail and a visible bowl/plate rim |
| Cut-in close-up | Pro Flash 256×128, background on | dramatic close-up, the foreground object large and low, dark vignette around, warm light from below |
| Vista panel | Pro Flash 256×128, background on | distant layered hills with aerial perspective, cool desaturated far layers, soft sky gradient, no foreground objects, seamless left and right edges |
| State edit | `create_object_state` / `edit_image_pro_flash` / `inpaint_image_pro_flash` | describe only the change; palette correction on |
| Animation | `animate_character` template (walks, 1 gen/dir) or v3 (custom, ≈1 gen/dir at 48 px, 8 frames) | motion only, no environment words (tool rule) |
| VFX | `vfx_workbench` (free) | fireflies, petals, smoke, steam, sparkle, confetti, stamp burst, coin pop, star twinkle, rain splash |

Style references: **target-quality crops, not our shipped art**
(decided 2026-10-13 — self-refs cap craft at the current level; the
style image teaches structure/shading/outline while `tb_grade` owns
the palette).  Source: `refs/crops/` subject-organized library +
`docs/reference/` Eastward/Octopia masters (official press + gameplay
shots).  The Octopia images are exactly 3× our render scale — crop at
3× multiples and downscale NEAREST ÷3 for native-res refs.  Crop to
the **exact target canvas** (Pro Flash and the batch tool refuse to
resize; the largest batch-tool style image sets the output size).
Pick crops matching the job's subject family (tree crops for A-R1,
prop/farm for A-R4, water for A-R3).

## 3. Batches — content lines

Each line is the content slot only; HOUSE + SITE + CLASS are appended.
`id` becomes the semantic file name.

**Generation modes (decided 2026-10-13) — pick the right tool, not the
biggest tool:**

| Mode | Tool | Rule |
|---|---|---|
| Static prop | `create_1_direction_object`, `view=top-down` | World props are fixed-orientation, fronts to camera — never spend 8-dir on objects |
| Directional | `create_character_pro_flash` 8-dir | Characters, pets, anything that walks. **Only creatures get directions** |
| Multi-state | gen master first → `create_object_state` / `edit` | night-lit windows, occupied pads, restoration stages. Master must exist before states |
| Loop anim | `animate_object` v3 / `vfx_workbench` (free) | flutters, sway, smoke, fire |
| Variant | `tb_variant` ramp-swap / `tb_dither` noise | foliage palettes, water shimmer — 0 gens, deterministic |

Per-asset state/anim needs are noted inline as `[+state:…]` /
`[+anim:…]` — the master job gen's the base only; states and anims are
follow-on jobs riding the master's `source_image_id`.

### Batch A — Pinewatch world (site: Pinewatch)

**A1 · small items (batch tool ≤42, 64 slots, 1 job ≈10)**
`stone_step_round` flat round stepping stone · `stone_step_oval` oval stepping stone with a mossy edge · `stone_step_pair` two stepping stones · `enamel_plate_chopsticks` white enamel plate with bamboo chopsticks · `bowls_stack` stack of three blue-rim enamel bowls · `pot_lidded` aluminium cooking pot with lid · `chopstick_cup` bamboo chopsticks standing in a cup · `charcoal_stove` small clay charcoal stove · `straw_mat_rolled` rolled rice-straw mat · `saw_flat` hand saw lying flat · `hatchet_ground` hatchet lying on the ground · `rope_coil` coil of rope · `tin_lantern_unlit` metal camp lantern, unlit · `kettle_red` red enamel kettle · `crate_cabbage` wooden crate of cabbages · `basket_oranges` woven basket of oranges · `rice_sack` tied sack of rice · `pickle_jar` glass jar of pickled vegetables · `basin_pink` pink plastic washing basin · `broom_bamboo` bamboo broom leaning · `bucket_wood` wooden bucket of water · `sandals_pair` pair of rubber sandals · `tea_tin` tin of tea leaves · `milk_tin` condensed milk tin · `incense_pot` small incense pot with three smoking sticks · `offering_plate` small plate of fruit offerings · `lily_pad` single lily pad · `lily_cluster` lily pads with a pink lotus bud · `reeds_clump` clump of reeds · `cattails` clump of cattails · `rock_mossy_s` small mossy river rock · `rock_mossy_pair` two mossy rocks · `duckweed` patch of duckweed · `debris_branch` fallen branch with leaves · `debris_weeds_tall` tall weed clump · `debris_thistle` small thistle bush · `debris_rubble` small pile of rubble stones · `debris_crate_broken` broken wooden crate · `debris_bucket_rusty` old rusty bucket · `debris_brambles` tangle of brambles · `fern_clump` sprouting fern clump · `bush_round_s` small round bush · `bush_white_flower` bush with small white flowers · `vine_hanging` hanging vine tendril · `price_board_blank` small blank chalk price board on a stand · `arrow_sign_blank` small blank wooden arrow sign · `menu_aframe_blank` sandwich-board menu with a blank chalk face · `shop_sign_hanging_blank` hanging wooden shop sign, blank · `bananas_bunch` bunch of bananas · `dragonfruit_pile` pile of dragon fruit · `fish_trap` woven bamboo fish trap · `net_bundle` bundle of fishing net · `egg_basket` basket of brown eggs · `stool_wood_low` low wooden stool · `paper_lantern_white` small white paper lantern

**A2 · edges, fences, yard (batch tool ≤85, 16 slots, 1 job ≈10)**
`fence_bamboo_straight` woven bamboo fence segment · `fence_bamboo_post` bamboo fence end post · `fence_plank_straight` split-plank wooden fence segment · `fence_plank_gate` split-plank fence gate, closed · `wall_drystone_straight` low dry-stone wall segment · `wall_drystone_corner` dry-stone wall corner · `rope_barrier` rope-and-post trail barrier · `mailbox_green` green metal mailbox on a wooden post · `bicycle_old` old black bicycle on its kickstand · `terrace_steps` two stone terrace steps · `terrace_edge_mossy` mossy stone terrace edge block · `hand_pump` cast-iron hand water pump · `rain_barrel` rain barrel · `well_covered` stone well with a wooden lid · `trail_marker` trail marker post with a painted band · `laundry_short` short laundry line with two shirts

**A3 · forest wall dressing (batch tool ≤170, 4 slots, 2 jobs ≈20)**
*(Single-tree species moved to A-R1 — they must be canopy+trunk split masters (T2), not flat cut-outs; genning them here too would double-pay and ship two inconsistent versions of the same species.)*
- A3a: `tree_cherry_bloom` wild Himalayan cherry in pink bloom, canopy + trunk split (T2) · `tree_fern` tree fern with a tall shaggy trunk, canopy + trunk split (T2) · `shrub_mass_dark` dense dark-green shrub mass for a forest base · `moss_vines_drape` moss and vines draping over a rock ledge
- A3b **framing pieces — replace the cut-out clause** with "fills the stated canvas edge, exits the frame": `crown_cluster` three trees with overlapping crowns filling the canvas edge, trunks visible below · `canopy_gate` two trees arching into a doorway of leaves over a path, crowns exiting both side edges · `repoussoir_top` dark foreground foliage hanging down from the top edge, large leaves, near-silhouette · `repoussoir_bottom` dark foreground fern fronds rising up from the bottom edge

**A4 · landmarks (batch tool ≤170, 4 slots, 1 job + 1 reroll ≈20)**
`trailhead_gate` rustic timber village gate arch with a curved tile roof cap, a lantern on each post, a blank hanging signboard · `pho_stall` roadside noodle stall: wooden cart counter under a tin awning on bamboo poles, steaming aluminium broth pot, stacked bowls, hanging herb bunches and lime nets, blank menu board · `jetty_short` short wooden plank jetty on posts reaching into the water · `footbridge_small` small wooden footbridge over a stream

**A5 · building touch-ups (`inpaint_image_pro_flash`, 4 × ≈6 ≈24)**
`cabin` + vines climbing the corners and potted plants by the door · `outfitter_van` + roof clutter: crates, folded chairs, a nón lá hanging on the mirror · `cottage_shed` + laundry on a line and a herb box on the porch · `pallet_deck` + worn planks and a rolled mat

**A6 · vista (Pro Flash 256×128, 3 panels + 2 seam inpaints ≈39)**
`vista_p1..p3` distant pine-covered highland ridges above a misty valley, far hills fading to cool blue under a soft warm sky — seamless edges; the night version comes from the grade, not a gen

**A7 · trail-map site thumbnail (Pro Flash 96×64, ≈10)**
`map_thumb_pinewatch` tiny vignette of a campfire clearing under tall pines with two tents and a van — later sites when they are built

### Batch A-R — world refresh (post-reference pass, decided 2026-10-13)

Why: the shipped world is one painted canvas — flat pond edges, baked
static trees, canvas-era tents.  Reference study (`assets_src/reference/`)
settled the fix: techniques T1–T5 in `style_lock.md`.  The world stays
painted; this batch adds the layered family on top.  **H4's dome-tent
re-author folds in here** — superseded by A-R4.

**A-R1 · tree family (batch ≤170, 6 slots, 2 jobs ≈20)**
All `1_direction` statics.  3 canopy masters
(`tree_broadleaf_round` · `tree_maple_copper` · `tree_feathery_droop`)
`[+anim: canopy sway → G]` + 3 trunk cut-outs — two separate gens per
tree, composited by `tb_post` (T2).  `tree_pine_highland` is dropped:
the shipped `pine_tall_a/b` are already variant-able masters —
`tb_variant` dry-run on them extracts a clean continuous ramp, so
pine variants cost 0 gens (T1).  Colour variants on all species are
`tb_variant` ramp-swaps — never re-gen'd: the model would redraw a
different silhouette every time; the ramp-swap preserves it exactly.

**A-R2 · bush + undergrowth family (batch ≤85, ≈10)**
`bush_round_m` · `bush_white_flower_v` · `fern_bank` ·
`grass_tussock` · `reed_shore` — masters only; variants derived.

**A-R3 · pond edge + water (batch ≤85, ≈10)**
`shore_ring_{n,ne,e,se,s,sw,w,nw}` — each line MUST name which edge
the water sits on (e.g. `shore_ring_n` "mossy stone shore edge strip,
water along the north side", `shore_ring_ne` "mossy stone shore
corner, water to the north-east") or the model will draw whole ponds.
`water_shimmer_{f1,f2}` = noise pass on the water tile via
`tb_dither` — 0 gens; runtime frame swap.

**A-R4 · modern camp props (batch ≤170, 9 slots, 3 jobs ≈30) — replaces the canvas set**
All `1_direction` statics; states are follow-on jobs:
`dome_tent_{sage,amber,slate}` — one dome silhouette, three colours
`[+state: night-lit ×2 → H3]` · `cooler_box` · `folding_chair_pair` ·
`propane_stove` · `solar_lantern` `[+state: lit]` · `dry_bag` ·
`camp_table_fold`.  (`string_lights_seg` dropped —
`props_large/string_lights` already ships `[+anim: sway]`.)  Era spec
applies (style_lock): clean surfaces, light wear only.  The shipped
canvas A-frames, warden tent and tarp tent retire to `_superseded/`
on landing — **integration step:** `tent_green`/`tent_red` are
referenced by `game/scripts/pinewatch_test.gd` (placement + TENTS
const); rename to the dome ids on landing.

**A-R5 · grounding decal family (batch ≤42, ≈10)**
`tuft_grass_{a,b,c,d}` · `tuft_leaf_litter` · `tuft_moss_patch` —
small base-blend decals in site palette; the layout pass stamps 1–3 at
every prop base (T3).

**Keep, no re-gen:** graded site backdrop, terrain tiles + wang
transitions, buildings/van, pads + fire pit, path + jetty, A1/A2 item
families that already read 2026.

### Batch B — the cast (character class)

Pricing: 6 gens per character (8 directions incl. the first image), +30%
rerolls. Walks are in Batch G.

#### Batch B2 — D4.1 actor cast amendment (2026-10-15)

**Resolution — measured, not assumed.** Eastward bodies read
~50-55 px in a 450 px frame (Octopia fisher, measured) = **11-12% of
frame height**. Our frame is 640×360, chars draw at scale
`0.80 × 1.12 ≈ 0.896` → target canvas figure = 40-43 / 0.896 ≈
**45-48 px** → **48×48 canvas, figure ≈90% of height**. 64×64 makes
the model overshoot (warden hit 89% → 14.2% of frame); forced
downscale loses pixel precision. Dog/animal templates: same canvas,
figure ≈75%.

**Layering → prompt rules** (traced through the scene, not guessed):
the engine bakes nothing onto actors — `_char_shadow` draws a
separate ellipse, y-sort handles occlusion, the `_veil` overlay and
PointLight2D pools grade/light them AFTER. So sprites must carry
**neutral daylight internal shading** (full value range, warm upper-
left / cool shadow ramps — the same sun as props) and must NOT carry
cast shadows, ground patches, rim-light, glow, or dusk tones —
baked scene light fights the veil grade. Internal shading is NOT
optional: flat chars read dead under the night veil.

**Style refs**: `assets_src/refs/crops/char/style_char_64.png`
(Octopia fisher — the canonical char look) + `diner_workers.png`.
Never our shipped chars (self-referencing caps quality — the current
warden/mai/bean are legacy and are REGENERATED by this batch). Never
`docs/reference/ui_stale/` (stale editorial grabs, quarantined
2026-10-15).

**D4.1 subset — 12 jobs, keyed to `game/data/actors.json`**:
named `warden`, `ranger_mai`, `bean` (regen) + guest personas
`backpacker_woman` [Hiker], `scout_kid` [Scout], `aodai_woman`
[Couple], `kid_pinkdress` [Family], `phuot_rider`+`backpacker_man`
[Van-lifer], `angler_uncle` [Angler], `bird_uncle` [Photographer],
`cyclist` [Cyclist], `food_vlogger` [Food-blogger]. Content lines
below; the cast is site-neutral, no site module. The D-PP-2
proposals it uses (`cyclist`, `backpacker_*`, `angler_uncle`,
`food_vlogger`, `scout_kid`) are confirmed by this batch — the
persona layer is what the actor Director consumes, so this subset
lands first and the rest of Batch B follows the same recipes.

**D4.1a Vietnamese daily-life expansion (+8)** — a VN campground is
not all hiking packs: `grandma_ba` [Family] — áo bà ba + low grey
bun + nón lá; `grandpa_mu` [Angler] — khaki + pith helmet + thermos;
`auntie_dobo` [Food-blogger] — floral đồ bộ + headscarf;
`uncle_deptong` [Couple] — singlet + dép tông; `sunhood_woman`
[Hiker] — pastel áo chống nắng; `teen_jersey` [Scout] — red VN
football jersey (kid gate); `student_bucket` [Couple/Photographer]
— oversized tee + bucket hat; `vendor_ganh` [Food-blogger] —
nón lá + shoulder yoke.

**Per-template prompt blocks** (gate failures drove this): the
shared 90%-fill adult block mis-scales non-adults — `BLOCK_DOG`
(~65% fill, quadruped) for `bean`; `BLOCK_KID` (~68% fill, 3
head-lengths) for `scout_kid`, `kid_pinkdress`, `teen_jersey`.
Driver: `tools/batch_b2_cast.py` — `fire` is idempotent + cap-
tolerant (Tier-1: 8 concurrent); `finish` = download → alpha-bbox
gate (adult 40-46 / kid 30-36 / dog 28-36 + feet ≥y43) →
`tb_grade --kind char` → `palette_lock --ramp
assets_src/palettes/chars/<key>.json` → stage `<key>_<dir>.png`.
Master palette: `assets_src/palettes/char_master.json` — ref
anchors measured off `ew_saiga.jpg` + authored material ramps in
the same saturation family (`tools/build_char_palettes.py`
assigns each persona a subset — SOTA master→subset model: every
colour exists in the master, identity survives).

**Assembled char block (B2)** — house core adapted to the layering
rules; `style_image` = the fisher crop; `style_options` =
`{color_palette:false, outline:true, shading:true, detail:false}` —
the ref teaches craft (outline/shading), NOT palette: a cast needs
per-persona schemes (prompt words own them; never put hex codes in
prompts — models read colour words, hex is noise). Exact hex
enforcement is the pipeline's job: `tb_grade --kind char` + pooled
`palette_lock` (shared ramp over the cast's own histogram — one
color depth, individual identities intact). Site-palette snap is
never run on chars — it would remap skin onto terrain hues.

> painterly pixel art character in the style of Eastward, low
> top-down 3/4 view with the front drawn straight-on — chunky
> readable silhouette about 3.5-4 head-lengths tall filling about
> 90% of the canvas height, full value range with a warm
> upper-left lit side and a cool shadow side, hue-shifted colour
> ramps, adaptive dark coloured outline (never pure black), calm
> interior masses with detail concentrated at the silhouette, one
> signature colour or prop, relaxed standing pose facing south,
> warm friendly expression, contemporary everyday clothes of the
> 2020s — single subject centred on a transparent background,
> neutral midday light, no cast shadow, no ground patch, no rim
> light, no glow, no dusk tones, no text

Each job appends one persona line (Vietnamese-contemporary
campers; the roster below) + `create_character_pro_flash` 48×48,
`low top-down`, template `mannequin` (`dog` for bean), 8 dirs.

**Cast consistency spec — the numbers every char is judged by**
(48×48 canvas, transparent, feet baseline y≈46-47, centred x=24):

| Kind | Figure px | Heads | On-screen (×0.896) | Prop anchor |
|---|---|---|---|---|
| Adult (all personas) | 42-44 | 3.5-4 (~11-12px head) | ~38-39px | dome tent 54px ≈1.4×, bench 28px, stool 16-24px |
| Kid (`kid_pinkdress`, `scout_kid`) | 32-34 | ~3 (~11px head) | ~29-30px | ~0.75× adult — read as children |
| Dog (`bean`) | 30-34 body len | — | ~28-30px | smaller than a tent, bigger than a stool |

Post-gen gate (before `tb_grade`): measure the alpha bbox — adult
outside 40-46px, kid outside 30-36px, dog outside 28-36px → reject
or rescale-96%→nearest-pixel. All eight directions share the same
bbox rule — a north view taller than the south view is a reject.
Anchor is the FEET, not the canvas: sprites integrate via
`anchors.json` bottom-centre like the shipped chars.

**Lesson (2026-10-15) — schema-first, never prompt-first.** Three
kid refires and two dog refires were wasted because we iterated on
prompt WORDS ("child", "3 head-lengths") to fix a mechanical
problem: the humanoid mannequin fills ~90% of any canvas regardless
of age words. The API already exposes the real levers — read the
`create_character` schema BEFORE spending generations:
- `size` is CHARACTER height in standard mode; the canvas grows
  ~40% (size 32 → ~32px figure on a 48px canvas).
- `proportions` presets exist for humanoids (`chibi` = big head —
  the kid silhouette).
- `body_type:"quadruped"` + `template:"dog"` is the correct dog
  path — never a humanoid prompt with dog words.
- v3 + `reference_image_url` rotates YOUR sprite into 8 dirs —
  the escape hatch when the model won't give the size you want:
  generate the south sprite at the exact canvas size (32×32 for
  kids — the model fills ~90% of ANY canvas, so canvas size IS
  the proportion control), then rotate.
- Bake-time rescale (`batch_b2_cast.py rescale <key> <px>`) is the
  deterministic fix for a 1-3px miss on an otherwise good sprite.

**Named**
- `warden` young warden, forest-green hoodie with sleeves pushed up, khaki shorts, sturdy boots, small tan backpack, short black hair, friendly face
- `ranger_mai` cheerful park ranger woman, olive ranger shirt with a small badge, khaki trousers, conical palm-leaf hat, long black hair in a low ponytail, clipboard
- `bean` (template dog) scruffy tan village dog, perky ears, curled tail, red collar with a small brass tag
- `crew_hammer` young volunteer builder, orange safety vest over a white tee, backwards cap, work gloves, hammer
- `crew_planks` volunteer woman, bandana, rolled sleeves, tool belt, carrying two planks
- `crew_foreman` older volunteer foreman, grey stubble, bucket hat, measuring tape on his belt
- `pho_vendor` noodle-stall auntie, apron, rolled sleeves, ladle in hand
- `grandpa_photo` (Pro Flash 64×64, background on — the only portrait not derived from a sprite) elderly man with a warm smile, white stubble, knitted cardigan over a collared shirt, old canvas fishing cap, sepia-toned photograph look, soft vignette

**Regulars** (`game/data/regulars.json`)
- `hung` teen scout leader, khaki scout shirt, red neck scarf, shorts, merit-badge sash, whistle on a cord
- `minh_father` friendly dad, polo shirt, slacks, sandals, carrying a cooler · `minh_mother` mum, floral blouse, wide sun hat, tote bag · `minh_kid_a` (child) girl with pigtails, yellow t-shirt · `minh_kid_b` (child) boy in a striped shirt and red shorts holding a feather shuttlecock
- `old_ba` thin elderly angler, green pith helmet, faded blue shirt, rolled trousers, bamboo rod over his shoulder
- `lan` photographer woman, short bob, linen shirt, cargo trousers, vintage film camera on a strap

**Personas** (persona class; archetype it can play in brackets)
- `aodai_woman` young woman in a flowing pastel áo dài with white trousers, straw hat in hand [Couple, Photographer] · `aodai_man` young man in a crisp white shirt and dark trousers holding a phone [Couple]
- `phuot_rider` motorbike road-tripper, bandana, sunglasses pushed up, cargo vest, fingerless gloves, dusty boots [Hiker, Van-lifer]
- `sundress_girl` city girl in a sundress, conical hat, white sneakers, oversized tote [Hiker, Couple]
- `karaoke_aunt` loud cheerful auntie, bright patterned blouse, visor cap, portable speaker with a microphone · `karaoke_uncle` jolly uncle, tank top, shorts, flip-flops, big bag of snacks [Family]
- `chess_elder_a` retired man, white undershirt, slacks, folded xiangqi board · `chess_elder_b` retired man, beret, cardigan, thermos of tea [Couple]
- `tiktok_teen` trendy teenager, oversized hoodie, bucket hat, phone on a mini tripod with a ring light [Scout]
- `bird_uncle` retired uncle, safari vest, wide-brim hat, huge telephoto lens [Photographer, Angler]
- `bride` bride in a white gown with a long veil and a bouquet · `groom` groom in a light grey suit with a bow tie [Couple, Photographer]
- `art_student` round glasses, oversized cardigan, sketchbook under one arm, film camera [Hiker, Photographer]
- `temple_granny` elderly grandmother in a brown loose blouse and black trousers, hair in a bun, incense sticks [Family]
- `office_escapee` rolled-up dress shirt, loosened tie, chinos, sneakers, laptop bag [Hiker, Couple]
- `kid_uniform` (child) boy in a white school shirt · `kid_pinkdress` (child) girl in a pink dress [Family]
- *Proposed (D-PP-2):* `cyclist` bright jersey, black cycling shorts, helmet, cycling glasses, water bottle [Cyclist] · `backpacker_woman` sun-tanned foreign traveller, braided hair, big travel pack, hiking sandals · `backpacker_man` bearded foreign traveller, linen shirt, ukulele [Van-lifer] · `angler_uncle` middle-aged angler, fishing vest, bucket hat, folding stool and rod [Angler] · `food_vlogger` stylish food vlogger, sunglasses, pastel blazer over a tee, phone on a gimbal, one gold accessory [Food Blogger — must read elite] · `scout_kid` (child) young scout, khaki shirt, red scarf, big backpack [Scout]

**Guest pets** (cosmetic) — `pet_border_collie` (template dog) black-and-white border collie · `pet_corgi` (template dog) orange-and-white corgi · `pet_cat_basket` (batch tool ≤85 object) grey tabby cat sitting in a woven basket

**Portraits** (`create_portrait_character`, character → portrait, 64 px, 10 gens each): `ranger_mai`, `hung`, `old_ba`, `lan`, `minh_mother`, `crew_foreman`, `pho_vendor` (≈70). The silent warden gets none.

### Batch C — fauna (class: small fauna; Field Notes heroes at 64)

Species list pending D-PP-1. Slots per species: perched + in-flight (birds), in-hand + jumping (fish).
- **C1 (≤42, 64 slots, ≈10):** 12 birds × 2 poses · `perch`, `carp`, `trout`, `catfish`, `golden_koi` × 2 · `hen_brown`, `rooster`, `chick`, `duck_white`, `duckling`, `frog_green`, `butterfly_yellow`, `butterfly_blue`, `dragonfly_red`
- **C2 (≤85, 16 slots, 2 jobs ≈20):** Field Notes heroes — 12 birds, 5 fish, 5 forage finds (`mushroom`, `herb`, `berries`, `goldcap`, `honey`)

### Batch D — food, ingredients, keepsakes (class: item icon / hero item)

**Content-icon spec (confirmed 2026-10-15 off genuine Eastward
captures — `docs/reference/ui_eastward/`):** item icons ARE painterly
pixel sprites — dark *coloured* outline, chunky 2-3 tone shading,
saturated, one object centred on transparency; NEVER flat monochrome
(flat silhouettes are the chrome-glyph class, our `G_*` code set).
The hero/detail view shows the SAME sprite enlarged — on Eastward's
result card the dish hero sits inside a **dark ring medallion** drawn
by chrome, so hero gens stay unframed art. Selection = thin corner
brackets (chrome), not a fill — our vermilion focus ring already reads
equivalent.

**Resolution spec (measured 2026-10-15):** refs at ~3× of 360p —
Eastward row icons ~24-28 game px in ~30px rows; result-card dish
~37px inside its medallion; icon:text ≈ 2.3× (generous, not garnish).
Model fills ~90% of any canvas — canvas size IS the size control:

| Asset | Canvas | Figure target | Displays at |
|---|---|---|---|
| D1 icon | 32×32, fill ~80% (~26px figure) — icons keep 2-3px margin, they never touch the cell | 24-28px | rows/chips 1:1 |
| D2 hero | 64×64, fill ~85% (~54-58px figure) | ~56px zone | result card, Field Notes, medallion frame is chrome |

Dense 12-16px slots keep `G_*` code glyphs — painterly icons never
get runtime-downscaled into a dense slot (same law as the `_16`/`_12`
glyph size variants).

- **D1 (≤42, 64 slots, ≈10):** 22 dishes + 17 ingredients + 9 keepsakes at 32 px
- **D2 (≤85, 16 slots, 2 jobs ≈20):** 22 dish heroes + 9 keepsake heroes at 64 px (result card, journal)

**D1 shipped (2026-10-16):** all 48 generated via
`create_object_pro_flash` (`n_directions:1`, 32×32, `view:low
top-down`, style_image = the 28×32 fisher crop). Driver:
`tools/batch_d1_items.py` (pilot → fire → poll → finish). Pipeline:
download → `_normalize` (nearest-fit figure into a 30px box → ≥1px
margin) → alpha-bbox gate (23-30px figure) → `tb_grade --kind char`
→ **pooled** `palette_lock --colors 48` (one median-cut ramp across
the whole set — icons share colour depth, unlike per-persona char
ramps) → stage `game/assets/pinewatch/icons/{dish_|ing_|}<id>.png` +
auto-wire `icons.json.objects`. Gate result: 48/48 pass, 23-30px
figures, 81 far-mapped px total. IDs match `recipes.json` /
`ingredients.json` / `crew.json` keepsake ids exactly (keepsake file
names use the catalog id — `grandpas_thermos.png`, not
`keepsake_thermos.png`). UI: `UIKit.icon_rect(id, null, 32)` renders
1:1 untinted — `icon_rect` only tints `G_*` glyph masks by default;
`UIKit.icon_exists` is the fallback check. Slots wired: pantry
ingredient chips (3-col, 94×40), pantry meal strip (dish chips),
evening-tray meal chip (84px, dish art left), journal recipe +
keepsake rows (`_row` gained `icon_size`; content art at 32px,
undiscovered rows keep the glyph).

**D2 shipped (same day):** 31 heroes (22 dishes + 9 keepsakes) at
64×64 via `fire_hero`. Two lessons recorded: (1) passing the D1 icon
as `style_image` locks the figure to the ref's pixel size — the icon
was redrawn 31px inside the 64px canvas; heroes use the craft ref
instead and share palette through the master ramp; (2) hero fill is
smaller than icon fill BY DESIGN — Eastward's dish reads ~37px
inside its medallion, so the gate is 30-56px figure on the 64px
canvas, and under-fill is never fixed with non-integer nearest
rescaling (mushes edges). File id `<stem>_hero`, icon key
`<id>_hero`. Display: the pantry cook result card — `medallion`
flat piece (dark lacquer disc, r=999) + `icon_rect(id+"_hero",
null, 64)` + name/price.

**Palette audit (2026-10-16):** the self-pooled ramp was measured
against a real Eastward item-cell extraction (the ingredient grid
in `eastward_inventory_menu.png`, blue row-strips filtered out) —
verdict: pooled amplified warm food hues (40/48 entries h12-49),
had no crimson/rose family, and only 2 thin greens. The
`assets_src/palettes/icon_master.json` ramp now anchors on the
extracted Eastward item palette (brick `#ab5950`, crimson
`#a13b45`, dusty rose `#be8286`, muted greens h98-124 s.12-.24,
warm near-black `#483f40`, creams `#f8f5e2`) plus saiga anchors
and authored fauna accents (`#4fa8c9` kingfisher blue etc. —
Eastward's own icons have no saturated blue; our birds need it).
`finish()` locks `--ramp icon_master.json`; never reintroduce
pooled mode here (it rebuilt the ramp from a filtered subset once
already).

**World palette audit (same day):** `site_palette_v3` was
frequency-greedy *derived from* our own graded art and — the real
bug — **never applied**: `palette_lock --ramp` needs a flat `ramp`
key, v3 had `colors`(dicts)+`ramps`(nested), so every shipped
world asset sat 0% on the ramp (grade-only look, class_shares
warm 59.5 / cool 1.6). Measured against 8 Eastward scene captures
(colored-px quantize): foliage spans h73-146 chartreuse→**mint**
(`#aabb6a`→`#75b18f`/`#83a692`), water runs s.5-.9 (`#0c5a8a`,
`#446e84`), mist `#344ca6` indigo, accents `#d26f69` salmon /
`#36cbb8` teal / `#dfc20e` yellow. Authored
`assets_src/out/site_palette_v4.json` (flat `ramp` + named
`ramps`) and snapped all 350 world PNGs (decals/props/terrain
tiles; `ground_painted` exempt — baked painterly composite,
re-colors via re-bake). Chars/icons keep their own masters.
`char_master` gained measured vivid cloth families
(`cloth_teal`/`cloth_coral`/`cloth_indigo`) for future personas —
existing persona assignments unchanged.

Dishes (`recipes.json`): `camp_mash` lumpy grey-brown mash in a dented tin bowl with a spoon · `trail_stew` hearty vegetable stew in an enamel camp pot, steam · `mushroom_skewers` grilled mushroom skewers on bamboo sticks · `herb_tea` green herbal tea in a small clay cup with a mint sprig · `berry_tea` pink berry tea in a glass with floating berries · `smores` toasted marshmallow s'mores on a tin plate · `trail_sandwich` crusty baguette sandwich with pickled carrot, cucumber and herbs · `goldcap_skillet` golden mushrooms sizzling in a small cast-iron skillet · `grilled_fish` whole grilled fish on a banana leaf with lime · `noodle_soup` beef noodle soup in a big white bowl with herbs, lime and chili · `iced_coffee` iced coffee with condensed milk, drip filter on top of the glass · `com_nam` triangle rice balls with sesame salt on a banana leaf · `goi_cuon` fresh spring rolls in translucent rice paper with shrimp and herbs, dipping sauce · `che` layered sweet bean dessert in a tall glass with coconut cream · `sinh_to` mango-avocado smoothie in a glass with a straw · `ca_phe_trung` egg coffee in a small cup standing in a bowl of hot water, foamy top · `tra_mat_ong` honey tea in a glass mug with a lemon slice · `ca_kho` caramelised braised fish in a small clay pot, glossy dark sauce · `mi_quang` turmeric-yellow noodles in a shallow bowl with shrimp, peanuts and a rice cracker · `berry_pie` lattice berry pie slice on a tin plate · `honey_cakes` stack of small honey cakes drizzled with honey · `caramel_custard` caramel custard with dark caramel on a small plate

Ingredients (`ingredients.json`): `mushroom` brown wild mushrooms · `herb` tied herb bundle · `berries` handful of red berries · `goldcap` golden mushroom · `honey` honey jar with a wooden dipper · `perch` small perch · `carp` carp · `trout` speckled trout · `catfish` catfish · `bread` baguette · `rice` bowl of uncooked rice · `eggs` three brown eggs · `tea` tin of tea leaves · `marshmallow` bag of marshmallows · `noodles` bundle of dried rice noodles · `coffee` bag of coffee beans · `sweet_milk` condensed milk tin

Keepsakes (`crew.json`): `keepsake_thermos` dented green enamel thermos · `keepsake_register` worn cloth-bound ledger · `keepsake_photo` old photo in a wooden frame, sepia, faces blurred · `keepsake_oar` oar carved with initials (marks only, no letters) · `keepsake_chart` rolled hand-drawn river chart · `keepsake_boat` small wooden rowboat · `keepsake_frames` bamboo lantern frames with rice paper · `keepsake_book` battered pattern book · `keepsake_lantern` half-finished silk lantern

### Batch E — decor and gear gaps (`decor.json`, `gear.json`)

**E shipped via `tools/batch_e_props.py` (create_object_pro_flash,
NOT the batch tool — see row 9):** 16× props_medium 64px + 4×
props_large 128px. Style refs = REAL Eastward scene crops
(`assets_src/refs/grade/ew_prop_fence64.png` /
`ew_prop_shop128.png`, extracted from `eastward_shopfront.png`) —
our own graded props as refs gave copy-of-a-copy drift (soft flat
fills; the first pilot was rejected on sight). BLOCK carries the
"hand-painted miniature density" + weathering grammar; palette is
NEVER a gen-time `palette=` param (forced palettes flatten fills —
Pro pilot lesson), it's `tb_grade pinewatch_v2` +
`palette_lock --ramp site_palette_v4` in post. World props are
bottom-anchored (`_normalize_prop`), not icon-centred.
Also fixed DECOR_SPRITE: 5 entries pointed at `props_medium` for
art living in `props_small` (invisible-decor bug:
`silk_lantern`/`lotus`/`guitar_stump`/`wind_chime`/`kite`), 6
placeholders now map to the new art (`flower_arch`/`koi_pond`/
`photo_wall`/`reed_screen`/`dog_bed`/`scout_pennant`), and
`stone_fire_pit`
(campfire-size → mutates `campfire.radius`) draws its ring via
`_sync_fire_pit()` under the A1b flame loop. Gear icons `cooler` +
`dutch_oven` went through the D1 driver (32px, icon_master);
outfitter gear rows now reserve a 32px slot (painterly icons
render untinted at native size; `fishing_rod`/`binoculars` keep
their authored 16px sprites, centred).

- **E1 (≤85, 16 slots, ≈10):** `reed_screen` woven reed privacy screen · `dog_bed` woven rattan dog bed with a checked blanket · `stone_fire_pit` fitted stone fire pit with a grill grate · `scout_pennant` triangular felt pennant on a pole, emblem only · `dutch_oven` cast-iron pot with lid on three legs · `binoculars` pair of handheld binoculars · `reception_board` wooden booking board with pegs and blank cards (tier-up) · `kite_stake` kite string tied to a stake with the kite flying high
- **E2 (≤170, 4 slots, 2 jobs ≈20):** `flower_arch` wooden arch covered in bougainvillea · `koi_pond` small stone-rimmed pond with lily pads and orange koi · `photo_wall` wooden frame wall of pinned blank photos · `cook_shelter` open-sided thatched kitchen shelter over a clay stove (tier-up) · `outfitter_lodge` small timber shop with a tin roof and porch beside the van (tier-up) · `trail_gate_tier` = A4 `trailhead_gate` (reuse)

### Batch F — cooking cut-in — **SHIPPED** (`tools/batch_f_cutin.py`)

`cutin_campfire_cook` — 256×128 full-bleed scene via
`create_image_pro_flash` (`no_background: false`; it is a scene
panel, not an object). 3 seeds fired, seed 3 picked — widest
centred wok, symmetric side props.  Style ref = real Eastward
night crop `refs/grade/ew_cutin_night256.png` (lantern-glow region
of `eastward_trailer_night.jpg`, 2:1 → 256×128): transfers the
deep blue-purple vignette + saturated warm glow pool.  NO palette
lock — baked night art; v4 is a day ramp and would strip the
vignette.  Pantry `_cutin_card()` shows it on a successful cook
with the two D1 ingredient sprites dropping into the wok
(`UIFeel`-timed, reduced-motion places them landed).

### Batch G — animation (motion-only descriptions)

Walks: `animate_character` template, south / north / east (west mirrored)
— 3 gens per character. Custom v3: 1 direction (south-east) unless noted.

| Who | Animations (action_description) |
|---|---|
| warden | crouching and poking embers with a stick · walking while carrying a box in both arms · crouched, pulling up weeds with both hands · talking with open-hand gestures · stretching arms overhead and yawning |
| ranger_mai | writing on a clipboard · waving hello |
| bean | digging with front paws · lying down and curling up asleep, slow breathing · bouncing with a wagging tail · eating from a bowl · pouncing forward |
| guests (shared) | sitting on a low stool, gentle sway · seated, lifting a bowl and eating with chopsticks · raising a phone to take a photo · casting a fishing line, then waiting · two people chatting with gestures (pair) |
| persona extras | singing into a microphone, swaying (karaoke_aunt) · seated, moving a chess piece (chess elders) · seated, sketching (art_student) · slow stretch (office_escapee) · taking a selfie (tiktok_teen) · holding hands and turning (bride + groom) · panning a long lens (bird_uncle) |
| kids | running in a loop · đá cầu kick, ready and balance poses (shuttlecock is a hand-drawn 8×12 sprite + physics, GDD §15) |
| crew | hammering · carrying a plank · sawing |
| props (`animate_object` v3) | awning flutter · lantern sway · pennant flutter · laundry flutter · hen pecking · duck swimming · bird hop and fly-off |
| VFX (`vfx_workbench`, free) | stall and fire smoke, steam, water ripple, fireflies, falling petals, sparkle, confetti, stamp burst, coin pop |

#### Batch G runtime — implemented 2026-10-16 (`tools/batch_g_anims.py`)

- **Driver matrix** (universal baseline + archetype layer —
  `sim_director` `anim_map`): `idle` south loop for all 22 personas
  (`breathing-idle` template; `idle` for quadrupeds) · `walk`
  S/N/E/W **for ALL 22** (`walking-8-frames`; `walk-8-frames` for
  quads) — walk is the universal verb: `dog_wary` rolls on any guest
  (flee renders walk at 80 px/s) and the scenario matrix can path
  anyone (arrivals, strolls, vignettes). Eastward-equivalent: every
  NPC ships idle+walk, bespoke actions layer on top ·
  `fish`+`sit` for anglers, `play`+`pet` for kids, `sniff`+`play`
  for dogs (custom `action_description` + `frame_count` on
  `animate_character` — no v3 needed). `wary`/`flee` get no art:
  wary→idle+`!` chip, flee→walk clip (distance-stepping reads as a
  run at 80 px/s). Warden's existing `A2_*` clips are copied to the
  persona contract (`warden_idle_south_*`, `warden_walk_*`) — zero
  gens.
- **Foot-slide SOTA fix — distance-driven stepping:** `actor_view`
  accumulates `moved.length()` and picks
  `frame = int(walk_acc / STEP_PX) % n` (`STEP_PX=5`), not a fps —
  cadence tracks speed at 35/55/80 px/s alike. Diagonals drive the
  dominant-cardinal clip (`CARD_OF`). Idles keep time-based
  `play()` with a presentation-only `randi()` start-frame desync.
- **Contract:** `still_<dir>` (8-way stills, always) ·
  `<clip>_<dir>` generated (walk) · `<clip>_south` activities ·
  fallback chain `<anim>_south → idle_south → still_south`.
- **Frame normalization:** every gen frame is re-anchored onto the
  still's canvas by bbox bottom-center (`_norm_frames`) so clips of
  any source size ground identically — no anchor drift. Palette-
  lock to the persona ramp after normalize.
- **POSE-CLASS RULE (hard-won, verified on sit + pet):**
  `animate_character` — template AND v3 — animates the character's
  **rotation image**: `action_description` can bend limbs but cannot
  change the pose class. "sitting on a stool" produced a *standing*
  sway; "kneeling to pet a dog" produced a standing wave (and baked
  a hallucinated dog into the sprite — never name the interaction
  target). Same-silhouette motions (walk/idle/arm gestures/head
  dips/rod casts/play-bow) work fine with action_description.
  For any stand→{sit,kneel,lie,crouch} clip: **repose first** —
  `edit_image_pro_flash` the still into the target pose →
  `animate_character` v3 `custom_start_frame_base64` = that pose →
  the loop stays posed. `batch_g_anims.py` enforces it: clips in
  `POSECLASS` skip with a hint unless
  `assets_src/gen/g/<key>/pose_<clip>.png` exists. Eastward does
  the equivalent: seated NPCs are authored seated sprites.
- **Tool gotchas learned:** job slots are **per direction** (a 4-dir
  walk = 4 of 8 slots; cap error must not mark `fired`); frame URLs
  (`{i}.png` pattern) can lag a couple of minutes after `done` —
  poll multi-dir jobs until ALL `want_dirs` urls are present before
  downloading; download dirs contain a non-image `download.png`
  artifact — filter frames by the `<dir>_<i>.png` pattern before
  PIL; `get_character` output arrives with cp1252-mangled em-dashes —
  parse on section shape, never literal `—`; `batch_d1.harness`
  sys.exit()s on subprocess failure — use the local non-fatal
  `harness` in batch_g_anims for loops; `create_object_pro_flash`
  `first_frame_url` reuse mode is for direction rotation ONLY, it
  will not repose (width/height/style args rejected too).

### Batch H — restoration, Clear, states — **SHIPPED** (`tools/batch_h_states.py`)

- **H1 Warden's Hut stages** (`edit_image_pro_flash` from the shipped `cabin` master, identity + anchor preserved): `cabin_s0` brambles + collapsed roof over the stilt silhouette · `cabin_s1` cleared, bare rafters · `cabin_s2` fresh roof planks on weathered walls · restored = existing `cabin`
- **H2 pad ground** (`create_object_pro_flash`, 64 px class, style-ref `refs/crops/tuft` + `ground`): `pad_overgrown_a/b` weed-covered pitch · `pad_cleared` packed pitch earth — runtime draws these UNDER the bracket markers; the clear scatter shrinks the overgrowth, `_sync_pad_visual` resurfaces it as the cleared tile
- **H3 night/occupied states** (`edit_image_pro_flash` on the day masters): `dome_tent_{sage,amber,slate}_night` warm interior glow + cool shell · `cabin_night` lit window · `pallet_deck_occupied` bedroll + lantern
- **Runtime**: `HUT_STAGES` swap in `_sync_crew_hut` (sprite carries state, modulate dim retired) · `ground_<pid>` tiles in `_build_pads`/`_play_clear`/`_sync_pad_visual` · `_sync_night_props` swaps tent/deck/hut at `EVENING+`, on seat/unseat, and at boot for loaded saves
- Palette: everything v4-locked (the night amber survived — the ramp's ochre family carries it). Boathouse and Lantern Workshop stages ship with their sites.
- **FX layer rule (ambient pass, 2026-10-16):** any art derived from or layered over a shipped prop goes in `game/assets/pinewatch/fx/` — originals never touched in place. The ambient sprites (`fx_firefly`, `fx_sparkle`, `fx_smoke`, `fx_moth`, `fx_butterfly`, `fx_mote`) are Pillow-authored straight from ramp hexes (`#e1e5c4` lamp, `#dfc20e` amber, `#bdd6f5` sky, `#939a79` sage, `#d26f69` salmon) so they're born on-palette; sway shader lives in `shaders/foliage_sway.gdshader` and reads the `global_wind_speed` scalar WorldFX already declares.
- **Compositing stack (grade fix, 2026-10-16):** the frame composes as world canvas → `GroundTint` (sun pools/shade, 0.6 alpha) → `_warp` ground distort → y-sorted world → `_veil` weather film (sun_rays 0.22 / layered_fog 0.7, posterized `hint_screen_texture` passes) → `PostGradeLayer` at CanvasLayer 7 (`post_grade.gdshader`: S-curve contrast + split-tone shadows→indigo / highlights→lamp + 6% sat + dusk vignette; HUD lives at 10+ untouched) → `WarmGrade` CanvasModulate (exposure only — `_dusk_mul(dusk)*absorb + daylight-scatter`, multiplies ≤1, can never lift). **The milk-wash bug:** light cues (`Game.set_light_cue`, vignettes/ceremonies) fed *raw authored hues* (`e8c46a` ≈ 0.9/channel) additively into the multiply → grade hit 1.4× = near-white frame. `CUE_GAIN` (0.22) in `_apply_grade` keeps cues a hue nudge; `flash` stays 1.0 (real exposure pulse). Rule: **nothing that writes `_grade` may push a channel >1 for ambient beats** — >1 is reserved for daylight-scatter tints and lightning. QA: `--shot` prints `OVERLAY` lines (veil shader + intensity + grade colour) and `--hide=NAME` toggles nodes for layer bisects; the painted ground must render within ~±15 of its authored pixels (`src 120,172,75 → 130,168,62` shipped). **Saturation rule:** the ramp locks each asset, but the *composite* must also land in the Eastward band — refs grade at 0.45-0.53 mean saturation (grass_zoom 0.46, shore 0.53, dirt 0.42); authored art runs ~0.55, so `post_grade.gdshader` pulls `sat_amt` to 0.97 (filmic desat, no art touch). Frame target ≈0.51-0.53 — measured 0.517 shipped. If the scene reads garish, tune `sat_amt`/`contrast_amt` first; don't re-grade individual props for scene-level hue.

### Batch I — events (§13.5)

- **I1 Tết (batch ≤170, 4 slots, ≈10):** `tet_peach_tree` blossoming pink peach tree in a pot · `tet_apricot_tree` yellow apricot blossom tree in a pot · `tet_bamboo_pole` tall bamboo pole with a red cloth tip · `tet_lantern_string` string of red lanterns
- **I2 (≤85, 16 slots, ≈10):** `tet_red_envelope`, `tet_rice_cake` square green rice cake tied with string, `tet_fruit_tray`, `tet_firecracker_paper` red paper streamers (no fireworks), `music_guitar`, `music_cajon`, `music_speaker`, `music_mic_stand`, `star_lantern` red five-point star lantern, `carp_lantern`, `mooncake_box`
- **I3 characters (≈18 + anims):** `band_guitarist` young guitarist on a stool · `band_singer` singer with a microphone · `band_drummer` cajón drummer · `lion_dance` (object + `animate_object`) red-and-gold lion dance costume with a fluffy mane and two dancers' legs
- Mid-Autumn (Lantern Valley) with Site 3

## 4. Budget (verified prices, 2026-10-12)

| Batch | Est. gens | Note |
|---|---|---|
| A world | ≈133 | Vista panels are the costly line; A3 slimmed to dressing pieces (trees moved to A-R1) |
| B cast | ≈385 | 36 humans (13 named/regular + 17 persona sprites + 6 proposed) × 6, +30% rerolls ≈281; 3 dogs ≈23; grandpa 10; 7 portraits × 10 = 70 |
| C fauna | ≈30 | Batch tool (C1 44 of 64 slots) |
| D food | ≈30 | Batch tool (D1 48 of 64 slots) |
| E decor | ≈30 | |
| F cut-in | ≈27 | |
| G animation | ≈220 | Walks: 39 walkers × 3 dirs = 117; ~85 custom anims × 1 (each sprite needs its own copy); prop loops ≈14 |
| A-R refresh | ≈105 | **Flat 15 gens/job at every slot count** (verified 2026-10-13: ≤170 4-slot, ≤85 16-slot, ≤42 64-slot all = 15) — pack items tight: 64-slot jobs are ~0.23/item. A-R = 7 jobs; bonus auto-fills covered A1 debris + extra trunk/decal vocabulary free |
| H states | ≈66 | H4 dome-tent re-author moved to A-R4 |
| I events | ≈55 | |
| **Total** | **≈1,075** (+20% contingency ≈1,290) | vs ~475 in the old manifest — characters and animation were under-priced |

Balance 1,633 now; the allowance refills to 2,000 on 2026-11-11 and
each cycle after. Fits this cycle with ≈350 left after contingency.
Levers if needed: one seed per persona, portraits for 4 characters
instead of 7, west mirrored (already assumed).

## 5. Open decisions

| ID | Decision | Recommendation |
|---|---|---|
| D-PP-1 | Field Notes bird roster | Keep the 12 slots but use species that plausibly live in each site's setting (e.g. a scops owl instead of the Tawny Owl, a brown dipper instead of the White-throated Dipper, blue-tailed bee-eater, oriental skylark; keep jay, kingfisher, heron, hoopoe, kestrel, wagtail, bulbul if ranges fit) — verify ranges before Batch C; names stay generic per D-07 |
| D-PP-2 | Persona roster | 17 personas: add cyclist, backpacker pair, angler uncle, food vlogger, scout kid so every archetype has a persona that reads right → Guestbook 21 entries, collectible total 88 |
| D-PP-3 | Spend order | A → D1/C1 (cheap, unblock UI) → B named + regulars → H → B personas → G → E/F → I |
| D-PP-4 | **Era: contemporary 2026** — Eastward-modern (Octopia camp frames), not heritage scout-camp; gear is new/clean, neglect told by nature; canvas tents re-author as domes (H4) | Decided 2026-10-12 (user); era clause baked into the House core + hero-prop class; style_lock prop era spec is the checklist |

## 6. Generation hygiene

- Record `seed`, style-ref file and the assembled prompt in every job
  entry (batch JSON) — reproducible rerolls.
- **Review flow:** batch jobs land in `review` — `get_object` → view
  candidates → `select_object_frames(indices)` (or `dismiss_review`).
  **Select promptly** — review objects can auto-finalize (job
  `08a95d4c` consumed itself before a delayed select; the 404 means
  the frames already became standalone objects, recoverable via
  `list_objects`).  Selected frames get NEW object ids — record them
  in the job meta.
- **Item grid semantics:** `item_descriptions` maps to grid slots in
  order; fewer lines than the grid auto-fills the rest FROM THE JOB
  DESCRIPTION — free bonus candidates in the same style (J3's 10
  auto-fills covered half the A1 debris family).  Every job costs a
  flat **15 gens regardless of slot count** — always fill slots.
- **Repair ladder before reroll:** `correct_pixelart` (off-grid) →
  `reduce_colors` (noisy palette) → `inpaint_image` (local fix) →
  reroll only when the silhouette itself is wrong.
- Pipeline unchanged: `tb_grade` → palette snap (dE>30) → `tb_post`
  (contact shadow, anchor) → stage → integrate.
- QA gate per asset: `pixelart_workbench lint` + `score`, plus the
  style_lock craft rubric for heroes.
- `style_options.detail=false` exists **only on Pro Flash tools** —
  the batch tool has no style toggles; calm comes from the crop +
  prompt words.
- **Native-resolution rule (hardened 2026-10-13): gen canvas ≈
  CONTENT size, not display canvas.**  Content fills ~80% of a gen
  canvas, so: ship 32–40 px → ≤42 job (exact, zero resize); ship
  56–72 px → ≤85 job (~1.15×); ship 128–150 px → ≤170 job (~1.1×).
  NEVER mix display-size classes in one job — a 40 px prop on a 160
  canvas crushes 4× into speckle (verified: A-R4 stove/lantern/chair,
  fixed by J8 re-gen at 85).  Post pipeline: crop to content bbox
  (lossless) → resize at most ONCE ≤1.3×, or ship at cropped size.
- **Ship resize is per-family** (verified 2026-10-13): organic/
  curve-dominant props (tents, canopies, bushes) → **LANCZOS**
  (smooth arcs, slight softening); hard-edged items (cooler, stove,
  tools, straight linework) → **NEAREST** (keeps edges, can stair-step
  curves).  `tb_post` takes `--resample smooth|sharp`.
- `transfer_outfit` noted for Batch B: persona variants from one base
  character instead of full char gens (potential ~100-gen saving).
- Semantic ids everywhere (`item_names`); no new `S_n`/`M1_n` names.
