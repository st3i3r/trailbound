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
| 9 | Cost model unused | Verified quotes (`get_pro_flash_capabilities`): Pro Flash = **5 gens per image** (≤96 px), 6 at 128–192, 9 at 256×128; character 8-dir = 6. Batch tool `create_1_direction_object` = ~10 gens per job for **64 items (≤42 px) / 16 (≤85) / 4 (≤170)** | Batch tool for every square ≤170 px set; Pro Flash only for characters, non-square, >170 px, or busy style refs (`detail=false`) |
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
| Terrain | `create_topdown_tileset` pro, 32 px, `high top-down` | calm low-detail ground wash, large soft tonal patches, no flowers, no tufts, no speckles, no repeating motif (detail comes from `tb_dither` + decals); pond/lake shores get a stone-ring edge band + 2–3 frame shimmer overlay, not a flat fill (T4) |
| Hero prop / structure | Batch tool ≤170 (4 slots, 128–160 style refs); Pro Flash custom for non-square | hand-painted miniature density, contemporary 2026 camping equipment (style_lock prop era spec: dome tents, coolers, chairs, stoves — never patched canvas / rusted surplus), clean surfaces with light wear (scuffs, dirt splash), one strong silhouette with one accent detail, base embedded, top and front faces both visible |
| Small item (L6) | Batch tool ≤42 (64 slots, 32 px refs) or ≤85 (16 slots, 64 px refs) | small and simple, readable at 1×, two or three tones plus outline, one clear silhouette, no fine noise |
| Foliage / tree | Batch tool ≤170 | leaf masses as clumps (not single dots), lit top-left rim, cool shaded underside, visible trunk and root flare; **canopy and trunk as separate sprites** (T2); **variants re-shaded on the same silhouette — new light structure, never a hue swap** (T1) |
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

Style references: our graded art cropped to the **exact target canvas**
(Pro Flash and the batch tool refuse to resize; the largest batch-tool
style image sets the output size). Build `refs/house/` crops: 32, 48
(character), 64, 128, 160 px from `cleanup/pinewatch_engine_graded.png`
and the canonical sprites. Eastward crops stay R&D-only.

## 3. Batches — content lines

Each line is the content slot only; HOUSE + SITE + CLASS are appended.
`id` becomes the semantic file name.

### Batch A — Pinewatch world (site: Pinewatch)

**A1 · small items (batch tool ≤42, 64 slots, 1 job ≈10)**
`stone_step_round` flat round stepping stone · `stone_step_oval` oval stepping stone with a mossy edge · `stone_step_pair` two stepping stones · `enamel_plate_chopsticks` white enamel plate with bamboo chopsticks · `bowls_stack` stack of three blue-rim enamel bowls · `pot_lidded` aluminium cooking pot with lid · `chopstick_cup` bamboo chopsticks standing in a cup · `charcoal_stove` small clay charcoal stove · `straw_mat_rolled` rolled rice-straw mat · `saw_flat` hand saw lying flat · `hatchet_ground` hatchet lying on the ground · `rope_coil` coil of rope · `tin_lantern_unlit` metal camp lantern, unlit · `kettle_red` red enamel kettle · `crate_cabbage` wooden crate of cabbages · `basket_oranges` woven basket of oranges · `rice_sack` tied sack of rice · `pickle_jar` glass jar of pickled vegetables · `basin_pink` pink plastic washing basin · `broom_bamboo` bamboo broom leaning · `bucket_wood` wooden bucket of water · `sandals_pair` pair of rubber sandals · `tea_tin` tin of tea leaves · `milk_tin` condensed milk tin · `incense_pot` small incense pot with three smoking sticks · `offering_plate` small plate of fruit offerings · `lily_pad` single lily pad · `lily_cluster` lily pads with a pink lotus bud · `reeds_clump` clump of reeds · `cattails` clump of cattails · `rock_mossy_s` small mossy river rock · `rock_mossy_pair` two mossy rocks · `duckweed` patch of duckweed · `debris_branch` fallen branch with leaves · `debris_weeds_tall` tall weed clump · `debris_thistle` small thistle bush · `debris_rubble` small pile of rubble stones · `debris_crate_broken` broken wooden crate · `debris_bucket_rusty` old rusty bucket · `debris_brambles` tangle of brambles · `fern_clump` sprouting fern clump · `bush_round_s` small round bush · `bush_white_flower` bush with small white flowers · `vine_hanging` hanging vine tendril · `price_board_blank` small blank chalk price board on a stand · `arrow_sign_blank` small blank wooden arrow sign · `menu_aframe_blank` sandwich-board menu with a blank chalk face · `shop_sign_hanging_blank` hanging wooden shop sign, blank · `bananas_bunch` bunch of bananas · `dragonfruit_pile` pile of dragon fruit · `fish_trap` woven bamboo fish trap · `net_bundle` bundle of fishing net · `egg_basket` basket of brown eggs · `stool_wood_low` low wooden stool · `paper_lantern_white` small white paper lantern

**A2 · edges, fences, yard (batch tool ≤85, 16 slots, 1 job ≈10)**
`fence_bamboo_straight` woven bamboo fence segment · `fence_bamboo_post` bamboo fence end post · `fence_plank_straight` split-plank wooden fence segment · `fence_plank_gate` split-plank fence gate, closed · `wall_drystone_straight` low dry-stone wall segment · `wall_drystone_corner` dry-stone wall corner · `rope_barrier` rope-and-post trail barrier · `mailbox_green` green metal mailbox on a wooden post · `bicycle_old` old black bicycle on its kickstand · `terrace_steps` two stone terrace steps · `terrace_edge_mossy` mossy stone terrace edge block · `hand_pump` cast-iron hand water pump · `rain_barrel` rain barrel · `well_covered` stone well with a wooden lid · `trail_marker` trail marker post with a painted band · `laundry_short` short laundry line with two shirts

**A3 · forest wall (batch tool ≤170, 4 slots, 3 jobs ≈30)**
- A3a: `tree_broadleaf_round_a` broadleaf evergreen with a dense round crown · `tree_broadleaf_round_b` second round-crown broadleaf, taller and narrower · `tree_feathery_droop` slender tree with feathery drooping foliage · `tree_maple_copper` highland maple with copper-red foliage
- A3b: `tree_cherry_bloom` wild Himalayan cherry in pink bloom · `tree_fern` tree fern with a tall shaggy trunk · `shrub_mass_dark` dense dark-green shrub mass for a forest base · `crown_cluster` three trees with overlapping crowns, staggered depths, trunks visible below
- A3c: `canopy_gate` two trees arching into a doorway of leaves over a path · `repoussoir_top` dark foreground foliage hanging from the top edge, large leaves, near-silhouette · `repoussoir_bottom` dark foreground fern fronds rising from the bottom edge · `moss_vines_drape` moss and vines draping over a rock ledge

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

**A-R1 · tree family, canopy+trunk pairs (batch ≤170, ≈40)**
Masters: `tree_pine_highland` · `tree_broadleaf_round` ·
`tree_maple_copper` · `tree_feathery_droop` — each ships as canopy
sprite + shared trunk sprite (T2), then **2 re-shaded canopy variants**
(deep-summer, dry-gold) on the same silhouette description (T1) —
≈4 masters + 8 variants.  Replaces the trees baked into the backdrop.

**A-R2 · bush + undergrowth family (batch ≤85, ≈15)**
`bush_round_m` · `bush_white_flower_v` · `fern_bank` ·
`grass_tussock` · `reed_shore` — master + 1 re-shaded variant where a
second palette earns its slot.

**A-R3 · pond edge + water (batch ≤85 + Pro Flash, ≈15)**
`shore_ring_{n,ne,e,se,s,sw,w,nw}` mossy stone-ring shore edges in the
Pinewatch palette (T4) · `water_shimmer_{f1,f2}` — two low-frequency
shimmer overlays at tile size; animation is a runtime frame swap, not
an animated gen.

**A-R4 · modern camp props (batch ≤170, ≈30) — replaces the canvas set**
`dome_tent_{sage,amber,slate}` — one dome silhouette, three colours ·
`cooler_box` · `folding_chair_pair` · `propane_stove` ·
`solar_lantern` · `string_lights_seg` · `dry_bag` ·
`camp_table_fold`.  Era spec applies (style_lock): clean surfaces,
light wear only.  The shipped canvas A-frames, warden tent and tarp
tent retire to `_superseded/` on landing.

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

- **D1 (≤42, 64 slots, ≈10):** 22 dishes + 17 ingredients + 9 keepsakes at 32 px
- **D2 (≤85, 16 slots, 2 jobs ≈20):** 22 dish heroes + 9 keepsake heroes at 64 px (result card, journal)

Dishes (`recipes.json`): `camp_mash` lumpy grey-brown mash in a dented tin bowl with a spoon · `trail_stew` hearty vegetable stew in an enamel camp pot, steam · `mushroom_skewers` grilled mushroom skewers on bamboo sticks · `herb_tea` green herbal tea in a small clay cup with a mint sprig · `berry_tea` pink berry tea in a glass with floating berries · `smores` toasted marshmallow s'mores on a tin plate · `trail_sandwich` crusty baguette sandwich with pickled carrot, cucumber and herbs · `goldcap_skillet` golden mushrooms sizzling in a small cast-iron skillet · `grilled_fish` whole grilled fish on a banana leaf with lime · `noodle_soup` beef noodle soup in a big white bowl with herbs, lime and chili · `iced_coffee` iced coffee with condensed milk, drip filter on top of the glass · `com_nam` triangle rice balls with sesame salt on a banana leaf · `goi_cuon` fresh spring rolls in translucent rice paper with shrimp and herbs, dipping sauce · `che` layered sweet bean dessert in a tall glass with coconut cream · `sinh_to` mango-avocado smoothie in a glass with a straw · `ca_phe_trung` egg coffee in a small cup standing in a bowl of hot water, foamy top · `tra_mat_ong` honey tea in a glass mug with a lemon slice · `ca_kho` caramelised braised fish in a small clay pot, glossy dark sauce · `mi_quang` turmeric-yellow noodles in a shallow bowl with shrimp, peanuts and a rice cracker · `berry_pie` lattice berry pie slice on a tin plate · `honey_cakes` stack of small honey cakes drizzled with honey · `caramel_custard` caramel custard with dark caramel on a small plate

Ingredients (`ingredients.json`): `mushroom` brown wild mushrooms · `herb` tied herb bundle · `berries` handful of red berries · `goldcap` golden mushroom · `honey` honey jar with a wooden dipper · `perch` small perch · `carp` carp · `trout` speckled trout · `catfish` catfish · `bread` baguette · `rice` bowl of uncooked rice · `eggs` three brown eggs · `tea` tin of tea leaves · `marshmallow` bag of marshmallows · `noodles` bundle of dried rice noodles · `coffee` bag of coffee beans · `sweet_milk` condensed milk tin

Keepsakes (`crew.json`): `keepsake_thermos` dented green enamel thermos · `keepsake_register` worn cloth-bound ledger · `keepsake_photo` old photo in a wooden frame, sepia, faces blurred · `keepsake_oar` oar carved with initials (marks only, no letters) · `keepsake_chart` rolled hand-drawn river chart · `keepsake_boat` small wooden rowboat · `keepsake_frames` bamboo lantern frames with rice paper · `keepsake_book` battered pattern book · `keepsake_lantern` half-finished silk lantern

### Batch E — decor and gear gaps (`decor.json`, `gear.json`)

- **E1 (≤85, 16 slots, ≈10):** `reed_screen` woven reed privacy screen · `dog_bed` woven rattan dog bed with a checked blanket · `stone_fire_pit` fitted stone fire pit with a grill grate · `scout_pennant` triangular felt pennant on a pole, emblem only · `dutch_oven` cast-iron pot with lid on three legs · `binoculars` pair of handheld binoculars · `reception_board` wooden booking board with pegs and blank cards (tier-up) · `kite_stake` kite string tied to a stake with the kite flying high
- **E2 (≤170, 4 slots, 2 jobs ≈20):** `flower_arch` wooden arch covered in bougainvillea · `koi_pond` small stone-rimmed pond with lily pads and orange koi · `photo_wall` wooden frame wall of pinned blank photos · `cook_shelter` open-sided thatched kitchen shelter over a clay stove (tier-up) · `outfitter_lodge` small timber shop with a tin roof and porch beside the van (tier-up) · `trail_gate_tier` = A4 `trailhead_gate` (reuse)

### Batch F — cooking cut-in (Pro Flash 256×128, ≈27 for 3 seeds)

`cutin_campfire_cook` close-up of a campfire cooking station: blackened wok on three stones, flames licking up, glowing embers, steam rising, dark night vignette, warm firelight from below. Ingredients drop in as existing D1 sprites.

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

### Batch H — restoration, Clear, states

- **H1 Warden's Hut stages** (`edit_image_pro_flash` from the restored `cottage_shed`, 128 px, palette correction on, 3 × 2 seeds ≈36): `hut_s0` ruined, collapsed roof, broken shutters, brambles and vines over the walls · `hut_s1` brambles cleared, roof open with bare rafters · `hut_s2` new roof tiles, shutters still broken · `hut_s3` = restored (existing)
- **H2 overgrown pads** (batch ≤85, 16 slots, ≈10): `pad_overgrown_a..d` square of earth covered by tall weeds, brambles, a fallen branch and stones · `pad_clearing_a..b` patchy dirt with weed stubs · `pad_cleared_a..b` freshly cleared packed earth with a few pebbles
- **H3 night/occupied states** (`create_object_state`, ≈5 each, ≈20): `tent_green_night`, `tent_red_night` warm lantern glow inside the modern dome tent, door half open · `cabin_night` warm light in the windows · `pallet_deck_occupied` bedroll and a small lantern on the deck
- **H4 tent re-author** (batch ≤170, ≈15): the shipped canvas A-frame pad tents (`tent_green`, `tent_red`), the warden tent and the brown tarp tent regenerate as **modern dome tents** per the style_lock prop era spec — clean two-tone ripstop, door arc, one guyline; the era-spec neglect story lives in weeds/debris on the pad, not in aged canvas
- Boathouse and Lantern Workshop stages: with their sites

### Batch I — events (§13.5)

- **I1 Tết (batch ≤170, 4 slots, ≈10):** `tet_peach_tree` blossoming pink peach tree in a pot · `tet_apricot_tree` yellow apricot blossom tree in a pot · `tet_bamboo_pole` tall bamboo pole with a red cloth tip · `tet_lantern_string` string of red lanterns
- **I2 (≤85, 16 slots, ≈10):** `tet_red_envelope`, `tet_rice_cake` square green rice cake tied with string, `tet_fruit_tray`, `tet_firecracker_paper` red paper streamers (no fireworks), `music_guitar`, `music_cajon`, `music_speaker`, `music_mic_stand`, `star_lantern` red five-point star lantern, `carp_lantern`, `mooncake_box`
- **I3 characters (≈18 + anims):** `band_guitarist` young guitarist on a stool · `band_singer` singer with a microphone · `band_drummer` cajón drummer · `lion_dance` (object + `animate_object`) red-and-gold lion dance costume with a fluffy mane and two dancers' legs
- Mid-Autumn (Lantern Valley) with Site 3

## 4. Budget (verified prices, 2026-10-12)

| Batch | Est. gens | Note |
|---|---|---|
| A world | ≈143 | Vista panels are the costly line |
| B cast | ≈385 | 36 humans (13 named/regular + 17 persona sprites + 6 proposed) × 6, +30% rerolls ≈281; 3 dogs ≈23; grandpa 10; 7 portraits × 10 = 70 |
| C fauna | ≈30 | Batch tool (C1 44 of 64 slots) |
| D food | ≈30 | Batch tool (D1 48 of 64 slots) |
| E decor | ≈30 | |
| F cut-in | ≈27 | |
| G animation | ≈220 | Walks: 39 walkers × 3 dirs = 117; ~85 custom anims × 1 (each sprite needs its own copy); prop loops ≈14 |
| A-R refresh | ≈95 | Net of H4's folded-in tent re-author (gross ≈110) |
| H states | ≈66 | H4 dome-tent re-author moved to A-R4 |
| I events | ≈55 | |
| **Total** | **≈1,100** (+20% contingency ≈1,320) | vs ~475 in the old manifest — characters and animation were under-priced |

Balance 1,633 now; the allowance refills to 2,000 on 2026-11-11 and
each cycle after. Fits this cycle with ≈330 left after contingency.
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
- Pipeline unchanged: `tb_grade` → palette snap (dE>30) → `tb_post`
  (contact shadow, anchor) → stage → integrate.
- QA gate per asset: `pixelart_workbench lint` + `score`, plus the
  style_lock craft rubric for heroes.
- Semantic ids everywhere (`item_names`); no new `S_n`/`M1_n` names.
