extends Node2D
## Pinewatch live test — canonical art pass (assets_src/out -> game/assets)
## on top of the real hosting loop: Game.new_day() boards actual guests,
## click a traveller then an open pad to seat (star preview on every pad),
## click a seated guest to pull them back, Enter says Goodnight and shows
## the night report, Enter again rolls the next morning.
## Color grade (vs docs/reference/eastward-11.webp): wang sheets are
## HSV-graded by tools/tb_grade.py --site pinewatch_v2 (fresh yellow-olive
## grass, ochre forest floor, saturated teal water, sandy stone); a
## CanvasModulate adds the lightened warm sunny multiply (#fbf4e4); macro
## ground colour comes from the GroundTint overlay sprite
## (fx/ground_tintmap.png, baked by tools/tb_tintmap.py — tile-swap zones
## are forbidden); the Backdrop node paints a sky->dirt gradient +
## shadowed treeline over the top forest strip so the top edge reads
## depth, not a dirt wall.
## Run: run_pinewatch.cmd   or   godot --path game res://scenes/pinewatch_test.tscn
## Headless shot:  godot --path game res://scenes/pinewatch_test.tscn --shot
##   -> assets_src/cleanup/pinewatch_engine_graded.png

const A := "res://assets/pinewatch/"
const T := 32                                # tile px
const CELL := 64                             # pad cell px
const TAP_SLOP := 7.0                        # px of finger travel that
                                             # turns a press into a pan —
                                             # ~Android scaledTouchSlop
var GW := 20                                 # ground dims follow the
var GH := 12                                 # active site mask (pinewatch
                                             # is 22x14; river/valley 20x12)
# ---------------------------------------------------------------- terrain
# Painted ground (PixelLab map-base export, terrain only): zones and
# transitions are baked art, no wang tilemap at runtime.  The mask that
# mirrors the baked zones for gameplay/scatter logic lives in the site
# layout JSON (layouts/<site>.json "mask"; tools/import_map.tscn
# regenerates it from a PixelLab export).
#   D = packed earth (road band, court plaza, yard)
#   G = fresh grass   W = pond water
# Per-site: sites without a baked ground draw _mask procedurally
# (_build_ground fallback), so the mask IS the map there.

## Site stage anchors: the fire/dog/notice-board positions are authored
## against each site's dressing — the layout supplies cells + errand
## anchors, these land the interactables inside it.
const SITE_STAGE := {
    "pinewatch": {"fire": Vector2(480, 512), "dog": Vector2(384, 592),
        "board": Rect2(704, 224, 96, 96)},
    "whisper_river": {"fire": Vector2(288, 192), "dog": Vector2(352, 238),
        "board": Rect2(46, 222, 40, 46)},
    "lantern_valley": {"fire": Vector2(288, 192), "dog": Vector2(352, 238),
        "board": Rect2(500, 284, 40, 46)},
}

# ------------------------------------------------------------- prop comp
# [category dir, file stem, anchor x, anchor y, lean deg?] — mirrors the
# P() calls in tools/scene_comp_v2.py, drawn into the y-sorted world so
# footing and overlaps sort themselves out.
# Phase 0.3: regrouped into 4 storytelling clusters (sub-cell jitter,
# mild overlap, pads/pond/path kept clear, site layout kept: van NW,
# trees top, fire centre, pond SW).  Phase 0.1: an optional 5th element
# leans the prop ±2-4° about its base — loose freestanding props only,
# never anchored/large ones (van, cabin, trees).
const PROPS_PINEWATCH := [
    # ===== v17 painted map — terrain + static dressing are baked into
    # fx/ground_sunlit.png (PixelLab map-base + objects); runtime keeps
    # only the stateful/live pieces =====
    # crew hut anchor — on painted maps the sprite stays hidden and
    # the authored PixelLab house (object layer) carries the visual;
    # position matches the house's exported collider foot
    ["props_large",  "cabin",             468, 389, 0.0, 1.05],
    # scorched dirt under the runtime fire ring at cell (7,7)
    ["props_medium", "dirt_patch",        480, 504],
    # junction signpost where the east lane meets the court — the
    # baked reception board sits below the frame edge
    ["props_small",  "signpost",          752, 320],
    # ===== BOUNDARY marks =====
]

## Whisper River v1 dressing (lean — painted ground lands with its art
## pass): maple/broadleaf treeline, the van parked NE, fire yard centre,
## reeds + lily pads reading the south bank under the water-row pads.
const PROPS_WHISPER := [
    ["props_large",  "tree_maple",        40,  68, 0.0, 0.55],
    ["fx", "tree_broadleaf_sunlit",   120,  62, 0.0, 0.55],
    ["fx", "tree_broadleaf_sunlit",   210,  66, 0.0, 0.52],
    ["fx", "tree_feathery_sunlit",    300,  62, 0.0, 0.55],
    ["fx", "tree_broadleaf_sunlit",   400,  66, 0.0, 0.55],
    ["props_large",  "tree_maple",       500,  64, 0.0, 0.55],
    ["fx", "tree_broadleaf_sunlit",   600,  68, 0.0, 0.55],
    ["props_large",  "outfitter_bus",    560, 118, 0.0, 1.30],
    ["props_small",  "signpost",          64, 258],
    ["props_medium", "dome_tent_slate",  150, 140, 0.0, 1.05],
    ["props_medium", "tripod_cauldron",  288, 188],
    ["props_small",  "log_stool",        250, 208],
    ["props_small",  "log_stool",        330, 205],
    ["props_medium", "lantern_post",     430, 170, 0.0, 1.05],
    ["props_medium", "reed_shore",        66, 316],
    ["props_medium", "reed_shore",       230, 318],
    ["props_medium", "reed_shore",       420, 316],
    ["props_medium", "reed_shore",       570, 318],
    ["decals",       "decal_lily_pad",   180, 352],
    ["decals",       "decal_lily_pad",   420, 356],
    ["props_small",  "fishing_rod",      330, 318],
    ["props_small",  "tackle_box",       342, 326],
    ["props_medium", "moped_cub",        500, 132, 0.0, 1.05],
    ["props_medium", "picnic_basket",    560, 240],
]

## Lantern Valley v1 dressing: compact pine camp, silk lanterns strung
## over the south terrace where the ground drops away.
const PROPS_LANTERN := [
    ["fx", "pine_tall_a_sunlit",       60,  70, 0.0, 0.60],
    ["fx", "pine_tall_b_sunlit",      160,  64, 0.0, 0.58],
    ["fx", "pine_tall_a_sunlit",      270,  66, 0.0, 0.60],
    ["props_large",  "flamboyant_tree",  380,  64, 0.0, 0.55],
    ["fx", "pine_tall_b_sunlit",      490,  66, 0.0, 0.58],
    ["fx", "pine_tall_a_sunlit",      600,  70, 0.0, 0.60],
    ["props_medium", "dome_tent_amber",   80, 150, 0.0, 1.10],
    ["props_medium", "tripod_cauldron",  288, 188],
    ["props_small",  "log_stool",        250, 208],
    ["props_small",  "log_stool",        330, 205],
    ["props_medium", "tea_table",        560, 150],
    ["props_small",  "silk_lantern_red", 430, 180],
    ["props_large",  "string_lights",    140, 290],
    ["props_large",  "string_lights",    500, 290],
    ["props_medium", "lantern_post",     300, 300],
    ["props_medium", "lantern_post",     400, 300],
    ["props_small",  "step_stone_a",     180, 340],
    ["props_small",  "step_stone_b",     360, 344],
    ["props_medium", "moped_cub",        480, 330, 0.0, 1.05],
    ["props_large",  "outfitter_bus",    560, 330, 0.0, 1.30],
    ["props_small",  "signpost",         520, 322],
]

const SITE_PROPS := {
    "pinewatch": PROPS_PINEWATCH,
    "whisper_river": PROPS_WHISPER,
    "lantern_valley": PROPS_LANTERN,
}

const EMBED_SKIP := ["dirt_patch", "reed_shore", "shore_edge_bank",
                     "shore_islet", "decal_lily_pad",
                     # flat-lying or on-furniture/hanging items — a base
                     # tuft would read as grass on the table or under air
                     "enamel_mug", "pho_bowl", "banh_mi", "phin_coffee",
                     "tea_cup", "jam_jar", "bread_board", "egg_tray",
                     "banana_bunch", "coconut_drink", "folded_map",
                     "brass_compass", "journal_pencil", "playing_cards",
                     "co_tuong_set", "camp_radio", "first_aid_pouch",
                     "headlamp", "insect_spray", "hanging_fish",
                     "garlic_braid", "herb_bundle", "seed_packet",
                     "kite", "sleeping_pad", "folded_blanket", "sandals",
                     "hiking_boots", "rope_coil", "folded_towel",
                     "step_stone_a", "step_stone_b", "step_stone_c",
                     "clothesline"]

const WORLD_SCALE := 0.80              # Eastward ratio pass: all
                                        # world props x0.8 so the
                                        # frame shows more world
const WorldFX := preload("res://scripts/world_fx.gd")
const AmbientFX := preload("res://scripts/ambient_fx.gd")
const QaSmoke := preload("res://scripts/qa_smoke.gd")
const WorldBuilder := preload("res://scripts/world_builder.gd")
const InputPresenter := preload("res://scripts/input_presenter.gd")
# Stage anchors moved per-site into SITE_STAGE (UI-034): _fire_pos,
# _dog_pos and _board_rect are set from it in _ready once site_id is
# known.  Pinewatch keeps the authored values every tool references.
const WARDEN_POS := Vector2(544, 424)
const MAI_POS := Vector2(800, 416)           # east meadow edge, by the lane
const BOARD_POS := Vector2(752, 320)         # signpost at the lane junction (UI-023)

# scatter decal groups by visual family — a cluster commits to ONE so it
# reads as a patch of something (tuft / flowers / dry grass / pebbles /
# mushrooms), not confetti
const DECAL_FAMILIES := {
    "tuft":   ["tuft_grass_a", "tuft_grass_b", "tuft_grass_c",
               "decal_fern_frond", "decal_fern_leaf", "decal_plantain"],
    "flower": ["decal_flowers_white", "decal_flowers_purple",
               "decal_flowers_white_b", "decal_dandelion"],
    "dry":    ["tuft_grass_dry", "decal_twig", "decal_stick_mossy"],
    "pebble": ["decal_pebbles", "decal_pebbles_moss", "decal_stone_moss"],
    "shroom": ["decal_mushroom_brown", "decal_mushroom_orange",
               "decal_mushroom_yellow"],
    # leaf litter for the (intentionally near-flat) B5 forest floor:
    # litter tuft + pile + single leaf + pinecones + bare branch + nest
    "litter": ["tuft_leaf_litter", "decal_leaf_pile", "decal_leaf_single",
               "decal_pinecones", "decal_branch_bare", "decal_bird_nest"],
    # damp moss/soil for shoreline + tree feet
    "moss":   ["tuft_moss_patch", "decal_soil_patch", "decal_soil_mound"],
}
const TENTS := ["dome_tent_sage", "dome_tent_amber", "dome_tent_slate"]
# Batch H: hut stage art (index = crew stage, last = restored cabin)
const HUT_STAGES := ["cabin_s0", "cabin_s1", "cabin_s2", "cabin"]
const PAD_OVERGROWN := ["pad_overgrown_a", "pad_overgrown_b"]

# ------------------------------------------------------------- grade pass
const WARM_MUL := Color.WHITE                # clean day — the post
                                             # grade owns warmth now;
                                             # multiply is exposure
                                             # only, never a film
const STORM_MUL := Color(0.38, 0.40, 0.48)   # desaturated slate — storm
const SIM_TO_FX := {"clear": "sunny", "rain": "rain",
                    "storm": "storm"}        # sim weather -> profile
                                             # #f4ead3 over-darkened the
                                             # scene (2026-10-12 review);
                                             # kept near-white so the day
                                             # reads bright/sunny
const SKY_TOP := Color("f2ecd6")             # sky sliver peeking above
const SKY_BOT := Color("d6dcbe")             # the far canopy (pale haze)
const SKY_H := 50.0                          # sliver height px
const TREE_FAR := Color(0.54, 0.62, 0.50)    # shadowed treeline tints —
const TREE_MID := Color(0.49, 0.57, 0.43)    # warm-deep-green multiplies
const TREE_NEAR := Color(0.43, 0.52, 0.39)   # (B>G read grey-blue, not
                                             # forest); g-dominant keeps
                                             # the canopy read leafy
const OVR_TOP := Color("1d2919")             # overscan fill: deep canopy
const OVR_BOT := Color("2c3620")             # shadowed grass at map foot
const OVR_DEEP := Color("151b0e")            #   fading to dark soil
# Edge-clustered decals (ground recipe): ~14 total, ONE family per
# cluster, ONLY at edges — prop bases, pond shoreline, treeline feet.
# Open-field interior stays EMPTY; the tint map carries macro variation.
# [centre x, centre y, family, count, radius x, radius y, terrain want]
const DECAL_CLUSTERS := [
    # empty on purpose — ground wear is BAKED into ground_dressed by
    # tools/tb_ground_scatter.py (tuft patches + packed pond rim).
    # Runtime decals on top double-dressed the same zones and read as
    # leaf clutter; ref grammar keeps open grass clean.
]
const DECAL_GROUND := Color(1.0, 1.0, 1.0, 0.85)
                                             # sink decals INTO the wash

var layout: Dictionary
var origin: Vector2
var anchors := {}                            # "cat/name.png" -> {anchor_x,y}
var pad_cells := {}                          # pid -> Rect2 (px)

# UI-034 site parameterisation — the scene is the main scene for every
# site: layout/mask/props/stage anchors all key off Game.site_id, and
# travel_to() lands through a scene reload (Transition.to_scene).
var _site_id := "pinewatch"
var _mask: Array = []                      # scatter/placement guard —
                                           # set from layout in _ready
var _props: Array = PROPS_PINEWATCH          # dressing table
var _fire_pos := Vector2(368, 236)           # fire-loop anchor
var _dog_pos := Vector2(420, 322)            # stray's lounge spot
var _board_rect := Rect2(384, 296, 36, 52)   # notice-board tap zone
var _fish_spots: Array = []                  # [{key, node, spot}]

var ground: Node2D
var stage: Node2D                            # all world layers — centred on
                                             # wide viewports (aspect=expand)
var _cam := Vector2.ZERO                     # view offset into the stage px
var scatter: Node2D
var pads_node: Node2D
var shadows: Node2D                          # Phase 5.0 light model —
var _shadow_tex: Texture2D                   # shared radial pool texture
var world: Node2D
# walk-behind fading: fadeable tall props get a zone over their
# upper art — an actor footing inside lerps the sprite alpha down
# so campers never vanish behind roofs/canopies (position rect,
# no physics). Actors register in _build_actors.
const FADEABLE := ["tree_feathery", "tree_broadleaf",
                   "outfitter_bus", "cabin"]
const FADE_ALPHA := 0.35
const FADE_SPEED := 2.6                      # ~0.25s ramp — their spec
var fade_zones := []                         # [{s: Sprite2D, r: Rect2}]
var actor_nodes := []                        # walking sprites to protect
var _grade: CanvasModulate                   # filmic grade — weather tint
var _fx: WorldFX                             # front/dusk scalar driver —
var _post_layer: CanvasLayer                 # screen-space grade tier
var _post: ColorRect                         # the pass itself
var _post_mat: ShaderMaterial                # uniforms synced per-frame
                                             # every atmospheric channel
                                             # is a curve off these
var _warp: ColorRect                         # ground-only screen warp
var _warp2: ColorRect                        #   double-buffered twin —
var _warp_chan := []                         #   [A, B] crossfade slots
var _veil: ColorRect                         # full-scene post overlay
var _veil2: ColorRect                        #   same pairing —
var _veil_chan := []                         #   outgoing fades on one
                                           #   while incoming rolls in
                                           #   on the other
var _rain: GPUParticles2D                    # slanted 2.5D downpour
var _leaves: GPUParticles2D                  # làn gió debris stream
var _noise_cache := {}                       # seed -> FastNoiseLite tex
var _weather_forced := false                 # --weather= locks the day
var _booted := false                         # boot resolve done — phase
                                             # signals during our own
                                             # _ready apply instantly
                                             # (is_node_ready() is TRUE
                                             # inside _ready) and
                                             # ceremonies stay queued
var _weather_tween: Tween
var _overlay_fades := {}                     # rect -> live fade Tween
var marks: Node2D                            # hover + star previews above world
var hover: Sprite2D
var hud: HUD                                 # chrome root (fades when idle)
var hud_layer: CanvasLayer                   # HUD tier (hidden by --bare)
var panel_mgr: PanelManager                  # modal panel stack (PANEL tier)
var markers: WorldMarkers                    # floating world markers layer
var hud_tween: Tween
var idle_ms := 0.0
var fire_bubble: Panel                       # marker content over the fire
var _fire_on := false
var _fire_tween: Tween
var _fire_light: PointLight2D                # hearth glow — emit row
var _fire_pit: Sprite2D                      # stone ring when upgraded
var _quit: Control                           # quit-confirm panel (one at a time)

var selected := ""                           # guest id being placed
var guest_nodes := {}                        # gid -> seated world Node2D
var tent_nodes := {}                         # gid -> [Sprite2D]
var star_labels := {}                        # pid -> preview Node2D
var evening_open := true                     # Enter -> Goodnight
var night_rating := ""
var _trait_names := {}                       # tid -> name (lazy)
var guest_bubbles := {}                      # gid -> trait-state marker token
var board_anchor: Node2D                     # notice-board prop anchor (UI-023)
var _actor_map := {}                         # dialogue anchors (name -> node)
var _sim: SimWorld                           # evening cast world (D4)
var _actor_view: ActorView                   # presenter — sim -> sprites
var _ceremony_layer: CanvasLayer             # UI-039 milestone overlay tier
var _dlg_queue := []                         # pending morning dialogue rows
var _dlg_tok := 0                            # live bubble marker token
var _five_star_seen := false                 # session flag for cer_five
var _board_tok := 0                          # morning "!" marker token

# --- prep layer (§7): forage nodes + pond/lookout/dog taps, PREP only
var _errand_layer: Node2D                    # decal sprites + spot anchors
var _errand_nodes := {}                      # forage node_id -> Sprite2D
var _errand_marks := {}                      # key -> affordance marker token
var _errand_anchors := {}                    # "pond"|"lookout" -> Node2D

# --- build layer (UI-033): decor world sprites + armed-ghost placement
var _decor_layer: Node2D                     # placed pieces, always drawn
var _decor_nodes := {}                       # st["decor"] idx -> Sprite2D
var _build_overlay: BuildGrid                # legal cells + candidate tint
var _build_menu_tok := 0                     # piece context-row token

var _pad_menu_tok := 0                       # pad context-row token
var _pad_menu_pid := ""                      # pad the menu is parked on
var _pad_chips := {}                         # pid -> afford marker token
var _pad_clearing := {}                      # pid -> true mid-clear anim
var _pad_shelters := {}                      # pid -> shelter Sprite2D

var _meal_sel := -1                          # armed meal instance idx
var _served_marks := {}                      # gid -> plate chip token
var _hut: Sprite2D                           # crew structure prop —
                                             # warden's hut (cabin art)
var _hut_dress: Node2D                       # staged restoration layer
var _hut_tok := 0                            # affordance chip token
var _hut_ready := false                      # stage-ready chip showing
                                             # (smoke-visible state)
var _dog_move: AnimatedSprite2D              # walk anim shown
                                             # mid-round (§9)
var _dog_shadow: Sprite2D                    # follows him on rounds
var _dog_points: Array = []                  # waypoint ring (per site)
var _dog_round_t := 7.0                      # seconds to first wander
var _dog_walking := false

var _tex_cache := {}
var _builder: RefCounted  # world passes (D-ARCH-9)
var _input: RefCounted  # gesture + tap routing (D-ARCH-9)


func _tex(rel: String) -> Texture2D:
    if not _tex_cache.has(rel):
        _tex_cache[rel] = load(A + rel + ".png")
    return _tex_cache[rel]


## Sprite2D whose bottom-center (or anchors.json anchor) sits at pos.
## Prefers the fx/<n>_sunlit family-regraded variant when one exists —
## originals stay the raw PixelLab export, sunlit is the graded copy.
func _anchored(cat: String, n: String, pos: Vector2) -> Sprite2D:
    var s := Sprite2D.new()
    var sun := "fx/" + n + "_sunlit"
    if ResourceLoader.exists(A + sun + ".png"):
        s.texture = _tex(sun)
    else:
        s.texture = _tex(cat + "/" + n)
    # Phase 5.1 interim — nearest keeps pixel edges hard under
    # fractional scale until assets are rebaked at native size
    s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var e: Dictionary = anchors.get(cat + "/" + n + ".png", {})
    var ax: float = e.get("anchor_x", s.texture.get_width() / 2.0)
    var ay: float = e.get("anchor_y", float(s.texture.get_height()))
    s.centered = false
    s.offset = -Vector2(ax, ay)
    # §5.9 texel phase: rest positions land on whole virtual px so
    # every sprite shares one texel grid under nearest filtering
    s.position = pos.round()
    return s


func _anchored_frames(prefix: String, names: Array, fps: float,
                      pos: Vector2, anchor := Vector2(-1, -1)) -> AnimatedSprite2D:
    var frames := SpriteFrames.new()
    frames.add_animation("main")
    frames.set_animation_speed("main", fps)
    for n in names:
        frames.add_frame("main", _tex(n))
    var a := AnimatedSprite2D.new()
    a.sprite_frames = frames
    a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    a.centered = false
    var sz: Vector2 = frames.get_frame_texture("main", 0).get_size()
    var an := anchor if anchor.x >= 0.0 else Vector2(sz.x / 2.0, sz.y)
    a.offset = -an
    a.position = pos.round()   # §5.9 texel phase — whole-px rests
    a.play("main")
    return a


func _ready() -> void:
    anchors = JSON.parse_string(
        FileAccess.get_file_as_string(A + "anchors.json"))
    _site_id = String(Game.site_id)
    layout = Catalog.data["layouts"].get(_site_id,
        Catalog.data["layouts"]["pinewatch"])
    _site_id = String(layout.get("site_id", "pinewatch"))
    _mask = layout.get("mask", [])
    assert(not _mask.is_empty(),
        "layout %s has no mask rows" % _site_id)
    GW = _mask[0].length()                   # frame dims come from the
    GH = _mask.size()                        # site's mask, not constants
    _props = SITE_PROPS.get(_site_id, PROPS_PINEWATCH)
    var sst: Dictionary = SITE_STAGE.get(_site_id,
        SITE_STAGE["pinewatch"])
    _fire_pos = sst["fire"]
    _dog_pos = sst["dog"]
    _board_rect = sst["board"]
    var opx: Array = layout["camp_core_origin_px"]
    # §5.9: whole-px origin keeps the whole pad grid on the texel
    # phase — guests, marks, hover all derive from these rects
    origin = Vector2(opx[0], opx[1]).round()
    var rng := RandomNumberGenerator.new()
    rng.seed = 7

    _grade = CanvasModulate.new()            # warm sunny filmic multiply;
    _grade.name = "WarmGrade"                # HUD sits in its own
    _grade.color = WARM_MUL                  # CanvasLayer, unaffected
    add_child(_grade)

    stage = Node2D.new()                     # every world layer lives under
    stage.name = "Stage"                     # Stage so _fit_stage() can centre
    add_child(stage)                         # the map inside wide viewports
    _fit_stage()
    Audio.play_music(&"camp")                # ambience bed is set in
                                             # _status() once phase is known
    get_viewport().size_changed.connect(_fit_stage)

    _builder = WorldBuilder.new(self)
    _input = InputPresenter.new(self)
    _build_ground()
    _build_backdrop()
    _build_scatter(rng)
    # macro ground colour: the baked tint field sits above Ground +
    # Scatter (terrain + decals get sun pools / shade) and below World
    # (props and characters stay unaffected) — replaces tile-swap zones.
    # Baked for pinewatch; other sites get it with their painted ground.
    if _site_id == "pinewatch":
        var ttex: Texture2D = _tex("fx/ground_tintmap")
        # tintmap is baked per-frame-size (tb_tintmap.py) — the 640x360
        # bake predates the 704x448 map; skip until a matching re-bake
        # lands, never shade the wrong cells
        if ttex and ttex.get_width() == GW * T:
            var tint := Sprite2D.new()
            tint.name = "GroundTint"
            tint.texture = ttex
            tint.centered = false
            tint.modulate = Color(1, 1, 1, 0.15) # whisper — the baked dapple
                                                # now carries the pools;
                                                # tintmap was a flat dim
            stage.add_child(tint)                # of zones, not a film
    pads_node = Node2D.new()
    pads_node.name = "Pads"
    stage.add_child(pads_node)
    _build_pads(rng)
    shadows = Node2D.new()                   # canopy/contact shadow
    shadows.name = "Shadows"                 # pools — drawn UNDER world
    stage.add_child(shadows)
    _warp = ColorRect.new()                  # screen-space ground warp:
    _warp.name = "WarpOverlay"               # reads pixels drawn BELOW
    _warp.position = Vector2.ZERO            # it (ground+tint+shadows),
    _warp.size = Vector2(GW * T, GH * T)     # so weather warps terrain
    _warp.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _warp.material = ShaderMaterial.new()    # while y-sorted props and
    _warp.visible = false                    # actors stay crisp; the
    stage.add_child(_warp)                   # profile picks the shader
    _warp2 = _warp.duplicate()               # crossfade twin — needs its
    _warp2.name = "WarpOverlayB"             # OWN material: duplicate()
    _warp2.material = ShaderMaterial.new()   # shares the resource
    stage.add_child(_warp2)
    _warp_chan = [_warp, _warp2]             # (ripples / gusts)
    world = Node2D.new()
    world.name = "World"
    world.y_sort_enabled = true
    stage.add_child(world)
    _build_objects()                       # PixelLab map props — the
                                           # export's base bake is
                                           # object-free, so they draw
                                           # here, y-sorted with actors
    _rain = GPUParticles2D.new()             # slanted downpour ABOVE the
    _rain.name = "ScreenRain"                # y-sorted world, UNDER the
    _rain.amount = 1400                      # canopy crowns (added to
    _rain.lifetime = 1.0                     # stage after world)
    _rain.emitting = false
    var pm := ParticleProcessMaterial.new()
    pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    pm.emission_box_extents = Vector3(700, 30, 1)
    pm.direction = Vector3(-0.35, 1.0, 0.0)  # wind slant, near-parallel
    pm.spread = 2.0                          # (high spread reads confetti)
    pm.initial_velocity_min = 520.0
    pm.initial_velocity_max = 680.0
    pm.gravity = Vector3.ZERO
    pm.scale_min = 1.0
    pm.scale_max = 1.5
    pm.set_particle_flag(
        ParticleProcessMaterial.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY,
        true)                                # streaks along travel dir
    _rain.process_material = pm
    _rain.texture = _rain_tex()
    _rain.position = Vector2(GW * T * 0.5 + 160, -30)
    _rain.visibility_rect = Rect2(-1400, -800, 3000, 2000)
    stage.add_child(_rain)
    _leaves = GPUParticles2D.new()           # làn gió debris — leaves
    _leaves.name = "LeafDebris"              # sweeping sideways on wind
    _leaves.amount = 120                     # days; sparse, tumbling
    _leaves.lifetime = 1.6
    _leaves.emitting = false
    var lm := ParticleProcessMaterial.new()
    lm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    lm.emission_box_extents = Vector3(30, 400, 1)   # left-edge strip
    lm.direction = Vector3(1.0, 0.15, 0.0)   # hard rightward, slight dip
    lm.spread = 6.0
    lm.initial_velocity_min = 400.0
    lm.initial_velocity_max = 650.0
    lm.gravity = Vector3(0, 60, 0)           # gentle settling arc
    lm.angular_velocity_min = -220.0
    lm.angular_velocity_max = 220.0          # tumble as they zip past
    _leaves.process_material = lm
    _leaves.texture = _leaf_tex()
    _leaves.position = Vector2(-20, GH * T * 0.4)
    _leaves.visibility_rect = Rect2(-1400, -800, 3000, 2000)
    stage.add_child(_leaves)
    # WorldFX — the rolling-front scalar driver: `front` (weather
    # severity) + `dusk` (nightfall) feed every channel through
    # response curves, so transitions continue from current values
    # instead of snapping between constants.  Phase changes feed
    # dusk; the weather profile feeds front + base tint.
    _fx = WorldFX.new()
    _fx.name = "WorldFX"
    add_child(_fx)
    _fx.bind(_grade, _rain, _leaves, WARM_MUL)
    Game.phase_changed.connect(_on_phase_dusk)
    # Post-grade — one screen pass shaping tone (contrast / split-tone
    # / vignette) on layer 7: above the world canvas + world markers,
    # below the HUD canvas.  Drives off the same WorldFX scalars.
    _post_layer = CanvasLayer.new()
    _post_layer.name = "PostGradeLayer"
    _post_layer.layer = 7
    add_child(_post_layer)
    _post = ColorRect.new()
    _post.name = "PostGrade"
    _post.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _post.set_anchors_preset(Control.PRESET_FULL_RECT)
    _post_mat = ShaderMaterial.new()
    _post_mat.shader = load("res://shaders/post_grade.gdshader")
    _post.material = _post_mat
    _post_layer.add_child(_post)
    _build_props()
    _build_ambient()
    _build_actors()
    # Phase 5.6 — canopy crowns hanging INTO the frame top: the
    # forest reads as continuing past the camera (Eastward edge cue)
    # — fallback maps only; painted maps author their own canopy
    var front := Node2D.new()
    front.name = "FrontCanopy"
    stage.add_child(front)
    var painted := _painted_map()
    for fp in [] if painted else [[34.0, 84.0, 1.45], [342.0, 74.0, 1.30]]:
        var cr := _anchored("props_large", "tree_broadleaf",
                            Vector2(fp[0], fp[1]))
        cr.scale = Vector2(fp[2], fp[2])
        front.add_child(cr)
    _veil = ColorRect.new()                  # post overlay over the WHOLE
    _veil.name = "VeilOverlay"               # map incl. actors — rays and
    _veil.position = Vector2.ZERO            # fog live here; HUD is on its
    _veil.size = Vector2(GW * T, GH * T)     # own layer, untouched
    _veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _veil.material = ShaderMaterial.new()
    _veil.visible = false
    stage.add_child(_veil)
    _veil2 = _veil.duplicate()               # crossfade twin — needs its
    _veil2.name = "VeilOverlayB"             # OWN material: duplicate()
    _veil2.material = ShaderMaterial.new()   # shares the resource
    stage.add_child(_veil2)
    _veil_chan = [_veil, _veil2]
    marks = Node2D.new()
    marks.name = "Marks"
    stage.add_child(marks)
    hover = Sprite2D.new()
    hover.texture = _tex("pad_hover")
    hover.centered = false
    hover.visible = false
    marks.add_child(hover)
    _build_ui()
    # weather QA lock parsed BEFORE the first advance_day — the
    # boot-morning phase handler must already know a --weather= /
    # --storm day is locked so it doesn't double-apply the sim roll
    var wkey := ""
    for a in OS.get_cmdline_args():
        if a.begins_with("--weather="):
            wkey = a.get_slice("=", 1)
            _weather_forced = true
    if OS.get_cmdline_args().has("--storm"):
        wkey = "storm"
        _weather_forced = true
    Game.advance_day()
    Game.set_phase(Game.Phase.EVENING)
    _spawn_board()
    _status()
    Transition.reveal()
    # QA hook: --reduced-motion exercises the UIFeel policy (the real
    # toggle lives in the P3 settings sheet)
    UIFeel.reduced_motion = OS.get_cmdline_args().has("--reduced-motion")
    if OS.get_cmdline_args().has("--smoke"):
        Transition.snap_reveal()
        _smoke()
        return
    # capture engine render for pipeline review (test scene only);
    # --shot writes the canonical graded shot, --shot=PATH elsewhere;
    # --bare strips chrome+markers+gameplay overlays entirely — pure
    # world art for the title vista (pad rings and tray cards are UI,
    # not scenery)
    if OS.get_cmdline_args().has("--bare"):
        hud_layer.visible = false
        markers.visible = false
        pads_node.visible = false
    # weather presenter: --weather=fog|wind|rain|storm locks the day
    # to a profile (--storm is shorthand, both parsed pre-boot);
    # otherwise the sim's rolled weather maps through SIM_TO_FX — so
    # the forecast the night summary promised is the front that
    # actually rolls in with each morning
    if not _weather_forced:
        wkey = SIM_TO_FX.get(
            String(Game.site_state().get("weather", "clear")),
            "sunny")
    if not WEATHER_PROFILES.has(wkey):
        wkey = "sunny"
    _set_weather(wkey, 0.0)                  # instant at boot
    _sync_night_props()                      # loaded saves land lit
    _booted = true                           # phase signals from here
    _drain_ceremonies()                      # on roll; boot-queued
                                             # milestones play now
    # --pose: QA screenshot staging — seats the first guest (trait
    # bubble visible), selects the second and hovers a pad (strip +
    # star previews visible)
    if OS.get_cmdline_args().has("--pose"):
        var st0: Dictionary = Game.site_state()
        var b0: Array = st0["board"]
        if not b0.is_empty():
            for pid0 in pad_cells:
                if st0["pads"][pid0].get("open", false) \
                        and not _pad_occupied(pid0):
                    selected = b0[0]["id"]
                    _try_seat(pid0)
                    break
            if b0.size() > 1:
                _select(b0[1]["id"])
                for pid0 in pad_cells:
                    if st0["pads"][pid0].get("open", false) \
                            and not _pad_occupied(pid0):
                        _update_strip(pad_cells[pid0].get_center())
                        hover.position = pad_cells[pid0].position
                        hover.visible = true
                        break
        # --pose --night: run Goodnight so the summary sheet stages
        if OS.get_cmdline_args().has("--night"):
            _goodnight()
        # --pose --morning: sleep through into the next Morning (the
        # "!" board marker + HEAD OUT button stage); --board then opens
        # the booking sheet for its own shot
        if OS.get_cmdline_args().has("--morning"):
            _goodnight()
            var sh: Control = panel_mgr.top()
            if sh is NightSummary:
                sh.sleep_pressed.emit()
        if OS.get_cmdline_args().has("--board"):
            _open_booking()
    # --settings: stage the §17.4 sheet for QA shots
    if OS.get_cmdline_args().has("--settings"):
        panel_mgr.open(SettingsSheet.make())
    # --journal: stage the §8.3 journal for QA shots (optionally a tab:
    # --journal=letters)
    var journal_arg := ""
    for a in OS.get_cmdline_args():
        if a.begins_with("--journal"):
            journal_arg = a.get_slice("=", 1) if "=" in a else "open"
    if journal_arg != "":
        var js := JournalSheet.make()
        panel_mgr.open(js)
        if journal_arg != "open":
            js._select_tab(journal_arg)
    var shot_arg := ""
    for a in OS.get_cmdline_args():
        if a.begins_with("--shot="):
            shot_arg = a.get_slice("=", 1)
    # --hide=NAME[,NAME] — layer-bisect for grade/QA shots: toggles
    # off nodes anywhere in the tree by name before capture
    for a in OS.get_cmdline_args():
        if a.begins_with("--hide="):
            for hn in a.get_slice("=", 1).split(","):
                var n2 := find_child(hn, true, false)
                if n2 != null:
                    n2.visible = false
                else:
                    print("--hide: no node named ", hn)
    if shot_arg != "" or OS.get_cmdline_args().has("--shot"):
        Transition.snap_reveal()
        await get_tree().process_frame
        await get_tree().process_frame
        for ch in [_warp, _warp2, _veil, _veil2]:
            var m := ch.material as ShaderMaterial
            print("OVERLAY ", ch.name, " vis:", ch.visible,
                " shader:", (m.shader.resource_path if m and m.shader
                    else "none"),
                " int:", (m.get_shader_parameter("intensity")
                    if m and m.shader else "-"))
        print("OVERLAY grade:", _grade.color)
        var img := get_viewport().get_texture().get_image()
        var out := shot_arg if shot_arg != "" else \
            "D:/monet/trail-bound/assets_src/cleanup/pinewatch_engine_graded.png"
        print("scene shot ->", out, " err:", img.save_png(out))
        get_tree().quit()


func _process(delta: float) -> void:
    if _post_mat != null and _fx != null:    # grade tracks the scalars
        _post_mat.set_shader_parameter("dusk", _fx.dusk)
        _post_mat.set_shader_parameter("front", _fx.front)
    var all_actors: Array = actor_nodes
    if _actor_view != null:                   # sim cast joins the set
        all_actors = actor_nodes + _actor_view.actor_nodes
    for z in fade_zones:                      # walk-behind fades
        var s: Sprite2D = z["s"]
        var occluded := false
        for a in all_actors:
            if z["r"].has_point(a.position):
                occluded = true
                break
        var target := FADE_ALPHA if occluded else 1.0
        if not is_equal_approx(s.modulate.a, target):
            s.modulate.a = move_toward(s.modulate.a, target,
                delta * FADE_SPEED)
    if hud == null:
        return
    idle_ms += delta
    if idle_ms > 3.0 and hud.modulate.a > 0.21:
        _fade_chrome(0.2)
    # §9 rounds — ambient wander between waypoints in the daylit
    # phases; view-only, never touches sim state.  Reduced motion pins
    # him at his post.
    var dg: Node2D = _actor_map.get("dog")
    if dg != null and not _dog_walking \
            and bool(Game.dog.get("met", false)) \
            and Game.phase in [Game.Phase.MORNING, Game.Phase.PREP] \
            and not UIFeel.reduced_motion:
        _dog_round_t -= delta
        if _dog_round_t <= 0.0:
            _dog_round_t = randf_range(9.0, 15.0)
            _dog_walk(dg)


## Weather presenter — visual only, no sim involvement. A profile row
## (grade tint + veil overlay + warp overlay + emitters + lightning)
## drives one parallel tween; a new state is a table row + optional
## shader, not new plumbing. Driven by --weather= / st["weather"]
## today; the scenario cast owns the trigger when the matrix lands.
const WEATHER_PROFILES := {
    # "veil" = post overlay over the whole map (rays, fog);
    # "warp" = ground-only distortion below the y-sorted world.
    # "front" = severity target the WorldFX scalar rolls toward —
    # rain/leaves/wind/audio all derive from it, so a row never
    # says "start rain", it says "how far into the front we are".
    "sunny": {"color": WARM_MUL, "front": 0.0,
              "veil": {"shader": "res://shaders/sun_rays.gdshader",
                       "val": 0.22,            # vệt nắng — ambient shafts
                       "resp": "dusk"},        # stay a shimmer, die at dusk
              "warp": null,
              "lightning": false},
    "rain":  {"color": Color(0.58, 0.60, 0.68), # sim's everyday rain —
              "front": 0.7,                    # wet, dim, no lightning
              "veil": null,
              "warp": {"shader": "res://shaders/rain_ripples.gdshader",
                       "val": 0.7,
                       "resp": "front"},       # puddles accumulate WITH
              "lightning": false},             # the front, not on a timer
    "storm": {"color": STORM_MUL, "front": 1.0,
              "veil": null,
              "warp": {"shader": "res://shaders/rain_ripples.gdshader",
                       "val": 1.0,
                       "resp": "front"},
              "lightning": true},
    "fog":   {"color": Color(0.65, 0.7, 0.75), "front": 0.3,
                                               # milky isolation —
              "veil": {"shader": "res://shaders/layered_fog.gdshader",
                       "val": 0.7},            # sương mù banks — flat:
              "warp": null,                    # fog ignores both scalars
              "lightning": false},
    "wind":  {"color": Color(0.85, 0.9, 0.85), "front": 0.35,
                                               # cool overcast
              "veil": null,
              "warp": {"shader": "res://shaders/wind_gusts.gdshader",
                       "val": 0.035,           # làn gió ground shimmer
                       "resp": "front_lift"},  # baseline + front swell
              "lightning": false},
    # "heatwave": overexposed gold grade (values >1.0 auto-route to
    #             daylight-scatter — they can never lift the night)
    #             + sine-warp haze
    #             veil; cast weights pond/shade spots — shade-as-data.
    # Foliage sway (when it lands) is a MATERIAL on tall props, not a
    # weather row: VERTEX.x bend ∝ height above anchor_y, driven by
    # RenderingServer.global_shader_parameter_set("global_wind_speed")
    # — one call, every swaying material reads it; phase from world-x.
    # Not binary: calm days keep ~0.8 ambient sway, WINDY gusts ~4/5.
    # anchor_y caveat: VERTEX.y ∈ [-ay, h-ay] — only base-anchored
    # props get the neat [-h, 0] range the write-ups assume.
}


func _set_weather(state: String, dur := 4.0) -> void:
    var p: Dictionary = WEATHER_PROFILES[state]
    var instant := dur <= 0.05
    _fx.lightning = p.get("lightning", false)
    # kill stale overlay fades before anything writes intensity —
    # tracked overlays register during _apply_overlay below
    if _weather_tween and _weather_tween.is_running():
        _weather_tween.kill()
    _weather_tween = null
    # one fx tween owns the scalar channels (front + tint); the scene
    # tween owns only flat overlay fades — every channel shares the
    # same reduced-motion policy so nothing outpaces the front
    var rdur := dur * (0.3 if UIFeel.reduced_motion else 1.0)
    _fx.set_front(float(p.get("front", 0.0)), dur, p["color"])
    if not instant:
        _weather_tween = create_tween().set_parallel(true)
    _apply_overlay(_warp_chan, p.get("warp"), rdur, instant)
    _apply_overlay(_veil_chan, p.get("veil"), rdur, instant)


## Phase -> nightfall target.  Morning barely dims (dawn freshness),
## evening is golden hour, night is the deep blue the sleep summary
## sits on.  `dusk` rolls in on the scalar — no hard day/night swap.
func _on_phase_dusk(p: int) -> void:
    # signals fired during our own _ready resolve instantly — the
    # first frame must already read as evening, not roll toward it
    _fx.set_dusk(_dusk_target(p), 3.5 if _booted else 0.0)
    _sync_night_props()
    if p == Game.Phase.MORNING and not _weather_forced:
        _apply_day_weather(6.0 if _booted else 0.0)


## Batch H night read — at EVENING/NIGHT occupied tents glow from
## inside, occupied pallet decks gain the bedroll+lantern overlay,
## and the restored hut lights its window (via _sync_crew_hut).
## Day restores the day sprites.  Called on every phase flip and
## after seat/unseat so loaded saves and arrivals match the hour.
func _sync_night_props() -> void:
    var night := Game.phase in [Game.Phase.EVENING, Game.Phase.NIGHT]
    var occupied := {}
    for pid_list in Game.site_state()["assignments"].values():
        for pid2 in pid_list:
            occupied[pid2] = true
    for gid2 in tent_nodes:
        for t in tent_nodes[gid2]:
            var key := String(t.get_meta("tent_key", ""))
            if key == "":
                continue
            var want := key + "_night" if night else key
            if ResourceLoader.exists(A + "props_medium/%s.png" % want):
                t.texture = _tex("props_medium/" + want)
    for pid in _pad_shelters:
        var ov: Sprite2D = _pad_shelters[pid]
        if ov.get_meta("shelter", "") != "platform":
            continue
        var want2 := "pallet_deck_occupied" \
            if (night and occupied.has(pid)) else "pallet_deck"
        if ResourceLoader.exists(A + "props_medium/%s.png" % want2):
            ov.texture = _tex("props_medium/" + want2)
    _sync_crew_hut()


func _dusk_target(p: int) -> float:
    match p:
        Game.Phase.MORNING: return 0.10
        Game.Phase.PREP:    return 0.25
        Game.Phase.EVENING: return 0.55
        Game.Phase.NIGHT:   return 1.0
    return 0.4


## The day's rolled weather becomes a rolling front with the morning
## — the forecast the summary promised literally arrives on screen.
func _apply_day_weather(dur := 6.0) -> void:
    var st: Dictionary = Game.site_state()
    var wkey: String = SIM_TO_FX.get(String(st["weather"]), "sunny")
    _set_weather(wkey, dur)


## spec = {"shader": path, "val": target intensity} or null. Every
## overlay shader exposes `uniform float intensity` so the profile
## row never names uniforms. `chan` is a [primary, twin] pair — a
## new effect rolls in on the free slot while the outgoing one dies
## on its own shader, so transitions crossfade instead of popping.
func _apply_overlay(chan: Array, spec: Variant,
                    dur: float, instant: bool) -> void:
    var showing: ColorRect = null
    var free: ColorRect = null
    for r in chan:
        if r.visible and showing == null:
            showing = r
        elif free == null:
            free = r
    if free == null:                           # both busy mid-fade —
        free = chan[1]                         # overwrite the twin
    if spec == null:
        if showing != null:
            _fade_out(showing, dur, instant)
        return
    var sm := (showing.material as ShaderMaterial) if showing else null
    if sm != null and sm.shader != null \
            and sm.shader.resource_path == spec["shader"]:
        _kill_fade(showing)                    # a rect mid-fade-out can
        var rr := String(spec.get("resp", "")) # be revived — kill the
        if rr != "":                           # stale tween; tracked
            _fx.track_overlay(sm, float(spec["val"]),  # specs rejoin
                StringName(rr))                # the scalar instead
        elif instant:
            sm.set_shader_parameter("intensity", spec["val"])
        else:
            _weather_tween.tween_property(sm,  # hide callback fires on
                "shader_parameter/intensity", spec["val"], dur)
        return                                 # the reviving effect
    _kill_fade(free)                           # same for a reused slot
    var fm := free.material as ShaderMaterial  # different effect —
    fm.shader = load(spec["shader"])           # incoming rolls in on
    _bind_noise(fm, spec["shader"])            # the free slot while
    free.visible = true                        # the old one dies fast
    var resp := String(spec.get("resp", ""))
    if instant:
        if resp != "":
            _fx.track_overlay(fm, float(spec["val"]),
                StringName(resp))              # applies val x curve
        else:
            fm.set_shader_parameter("intensity", spec["val"])
        if showing != null:
            _kill_fade(showing)
            showing.visible = false
    else:
        if resp != "":
            # scalar owns intensity — it rises as the front rolls in
            # (ripples accumulate, rays die with the light)
            _fx.track_overlay(fm, float(spec["val"]),
                StringName(resp))
        else:
            fm.set_shader_parameter("intensity", 0.0)
            _weather_tween.tween_property(fm,
                "shader_parameter/intensity", spec["val"], dur)
        if showing != null:
            _fade_out(showing, dur * 0.5, instant)


## Fade tweens are tracked per rect — a slot reused while a fade is
## still running must not let the stale tween drive the NEW effect's
## intensity to 0 or fire its hide callback.
func _kill_fade(rect: ColorRect) -> void:
    if _overlay_fades.has(rect):
        _overlay_fades[rect].kill()
        _overlay_fades.erase(rect)
    # a killed/reused slot must not keep answering to the scalars —
    # the caller re-tracks if the revived effect still wants it
    _fx.untrack_overlay(rect.material as ShaderMaterial)


func _fade_out(rect: ColorRect, dur: float, instant: bool) -> void:
    _kill_fade(rect)
    var m := rect.material as ShaderMaterial
    if m.shader == null or instant:
        rect.visible = false
        return
    var ft := create_tween()                   # own tween: callback on
    ft.tween_property(m,                       # a parallel tween has
        "shader_parameter/intensity", 0.0, dur)   # fuzzy step timing
    ft.tween_callback(func():
        rect.visible = false
        _overlay_fades.erase(rect))
    _overlay_fades[rect] = ft


func _bind_noise(m: ShaderMaterial, path: String) -> void:
    ## Procedural FastNoiseLite fields — no binary noise assets
    match path:
        "res://shaders/sun_rays.gdshader":
            m.set_shader_parameter("noise_tex", _noise_tex(11))
        "res://shaders/layered_fog.gdshader":
            m.set_shader_parameter("fog_noise_1", _noise_tex(11))
            m.set_shader_parameter("fog_noise_2", _noise_tex(47))
        "res://shaders/wind_gusts.gdshader":
            m.set_shader_parameter("noise_tex", _noise_tex(23))


func _noise_tex(nseed: int) -> Texture2D:
    if not _noise_cache.has(nseed):
        var n := FastNoiseLite.new()
        n.seed = nseed
        n.frequency = 0.035
        n.fractal_octaves = 3
        var img := Image.create(256, 256, false, Image.FORMAT_L8)
        for y in 256:
            for x in 256:
                var v := clampf(n.get_noise_2d(x, y) * 0.5 + 0.5,
                                0.0, 1.0)
                img.set_pixel(x, y, Color(v, v, v))
        _noise_cache[nseed] = ImageTexture.create_from_image(img)
    return _noise_cache[nseed]


func _leaf_tex() -> Texture2D:
    ## 8x8 autumn leaf pixel-blob; angular_velocity tumbles it
    var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    for y in range(2, 6):
        for x in range(2, 6):
            img.set_pixel(x, y, Color(0.75, 0.45, 0.18, 0.9))
    img.set_pixel(1, 3, Color(0.75, 0.45, 0.18, 0.9))
    img.set_pixel(6, 3, Color(0.9, 0.6, 0.25, 0.9))
    return ImageTexture.create_from_image(img)


func _rain_tex() -> Texture2D:
    ## 2x16 streak — bright leading tip fading toward the tail; the
    ## particle flag aligns it to velocity so it draws as a rain line
    var img := Image.create(2, 16, false, Image.FORMAT_RGBA8)
    for y in 16:
        var a := lerpf(0.55, 0.05, y / 15.0)
        img.set_pixel(0, y, Color(1, 1, 1, a))
        img.set_pixel(1, y, Color(1, 1, 1, a))
    return ImageTexture.create_from_image(img)


func _fade_chrome(a: float) -> void:
    if hud_tween and hud_tween.is_running():
        hud_tween.kill()
    hud_tween = UIFeel.apply(create_tween(), "chrome")
    hud_tween.tween_property(hud, "modulate:a", a, UIFeel.dur("chrome"))


func _wake_chrome() -> void:
    idle_ms = 0.0
    if hud == null:                            # HUD not built yet
        return
    if hud.modulate.a < 0.99:
        _fade_chrome(1.0)


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_MOUSE_ENTER:
        _wake_chrome()


## Position the stage: centre when the map is smaller than the
## viewport (aspect=expand shows margin on wide phones), pan by _cam
## when it's larger (D-ARCH-8).  The dark clear colour paints any
## margin, not the mid-grey default.
func _fit_stage() -> void:
    # smaller-than-viewport axes centre; larger axes pan inside _cam —
    # everything under stage (ground/props/actors) is map-space so pan
    # is just this offset, and pointer math `mouse - stage.position`
    # stays correct at any cam
    var vp := get_viewport_rect().size
    _cam = _cam.clamp(Vector2.ZERO, Vector2(
        maxf(0.0, float(GW * T) - vp.x),
        maxf(0.0, float(GH * T) - vp.y)))
    stage.position = Vector2(
        maxf(0.0, (vp.x - float(GW * T)) / 2.0),
        maxf(0.0, (vp.y - float(GH * T)) / 2.0)) - _cam


func focus_cell(c: Vector2i) -> void:
    ## scroll the view so a cell sits near centre — the UI seam for
    ## "show me" affordances (seated guest, board, fire) once pans
    ## leave the authored frame
    _cam = Vector2(c) * CELL + Vector2(CELL * 0.5, CELL * 0.5) \
        - get_viewport_rect().size * 0.5
    _fit_stage()


# ------------------------------------------------------------- scenery

func _cell_mask(c: Vector2i) -> int:
    ## 0 grass 1 dirt 2 water — logical mirror of the painted ground
    ## (MASK above), used by scatter guards + pad placement only.
    if c.x < 0 or c.x >= GW or c.y < 0 or c.y >= GH:
        return 0
    match _mask[c.y][c.x]:
        "D": return 1
        "W": return 2
        "#": return 3                    # void — never a scatter target
        _:   return 0


func _build_ground() -> void:
    _builder.build_ground()

func _open_cell(px: float, py: float, want: int) -> bool:
    return _builder.open_cell(px, py, want)

func _build_backdrop() -> void:
    _builder.build_backdrop()

func _build_scatter(rng: RandomNumberGenerator) -> void:
    _builder.build_scatter(rng)

func _build_pads(rng: RandomNumberGenerator) -> void:
    _builder.build_pads(rng)

## PixelLab object layer (map import). Each entry becomes a Node2D
## anchored at its collider's bottom-centre — that foot point is what
## `world` y-sorts on, so actors pass in front of/behind props
## correctly. Children are added in authored drawOrder so equal-foot-y
## ties keep the editor's layering. Sites without an objects manifest
## (lantern_valley, whisper_river) simply skip.
func _build_objects() -> void:
    _builder.build_objects()

func _build_props() -> void:
    _builder.build_props()

## Phase 5.0+5.3 — canopy/contact shadow pools. Green-brown radial
## pools centred on each prop's footprint, sun upper-left so the
## pool reads centred with a slight +X bias. Water/ground items
## and flat-lying pieces get none.
const SHADOW_SKIP := ["shore_islet", "decal_lily_pad", "reed_shore",
                      "shore_edge_bank", "dirt_patch", "fishing_rod",
                      "step_stone_a", "step_stone_b", "step_stone_c"]

func _shadow_texture() -> Texture2D:
    if _shadow_tex == null:
        var g := Gradient.new()
        g.set_color(0, Color(0.20, 0.32, 0.18, 0.36))
        g.set_color(1, Color(0.20, 0.32, 0.18, 0.0))   # ends first —
        g.add_point(0.66, Color(0.20, 0.32, 0.18, 0.20))  # insert shifts
                                                        # indices!
        var t := GradientTexture2D.new()
        t.gradient = g
        t.width = 128
        t.height = 64
        t.fill = GradientTexture2D.FILL_RADIAL
        t.fill_from = Vector2(0.5, 0.5)
        t.fill_to = Vector2(1.0, 0.5)
        _shadow_tex = t
    return _shadow_tex


func _add_shadow(p: Array) -> void:
    _builder.add_shadow(p)

func _char_shadow(pos: Vector2, w: float) -> Sprite2D:
    var s := Sprite2D.new()
    s.texture = _shadow_texture()
    s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    s.scale = Vector2(w / 128.0, w * 0.32 / 64.0)
    s.position = pos + Vector2(2.0, -1.0)
    shadows.add_child(s)
    return s


## Phase 0.1 embed pass — kill the sticker look: 1-3 small decals
## (tufts on grass, litter on forest floor) anchored just BELOW the
## prop's base so the y-sort draws them in front of its bottom ~8-15%.
## The base edge gets visually broken by foreground vegetation and the
## prop reads as sitting IN the world, not pasted on it.
func _embed_base(p: Array, rng: RandomNumberGenerator) -> void:
    _builder.embed_base(p, rng)

## AmbientFX + foliage sway — the "world breathes" layer (fireflies,
## pond glints, pollen, hut smoke, moths, butterflies) plus the wind
## vertex wobble on rooted vegetation.  Runs AFTER _build_props so the
## sway pass sees every decal that exists: scatter clusters, prop-foot
## embeds and the Batch-H overgrown pad tiles all came earlier.
const SWAY_KEYS := ["decals/tuft_", "decals/decal_fern",
    "decals/decal_flowers", "decals/decal_dandelion",
    "decals/decal_plantain", "decals/decal_sprout",
    "decals/decal_berries", "decals/decal_ivy",
    "decals/pad_overgrown"]

var _amb: AmbientFX                          # null until built
var _sway: ShaderMaterial


func _sway_mat() -> ShaderMaterial:
    if _sway == null:
        _sway = ShaderMaterial.new()
        _sway.shader = load("res://shaders/foliage_sway.gdshader")
        _sway.set_shader_parameter("amp",
            0.8 * (0.3 if UIFeel.reduced_motion else 1.0))
    return _sway


func _sways(tex: Texture2D) -> bool:
    var p := tex.resource_path
    for k in SWAY_KEYS:
        if k in p:
            return true
    return false


func _apply_sway() -> void:
    for grp in [scatter, world, pads_node]:
        if grp == null:
            continue
        for n in grp.get_children():
            if n is Sprite2D and n.texture != null \
                    and _sways(n.texture):
                n.material = _sway_mat()


func _build_ambient() -> void:
    _apply_sway()
    # lantern posts make moth anchors — the lamp head sits ~14px
    # above the prop's ground anchor
    var lamps: Array = []
    for p in _props:
        if p.size() > 1 and p[1] == "lantern_post":
            lamps.append(Vector2(p[2], p[3] - 14.0))
    # Pinewatch's pond rect is authored; other sites get a generous
    # box around their pond errand spot, or nothing
    var pond := Rect2(6, 195, 130, 105)
    var es: Dictionary = layout.get("errand_spots", {})
    if _site_id != "pinewatch":
        if es.has("pond"):
            var pp: Array = es["pond"]
            pond = Rect2(pp[0] - 60, pp[1] - 40, 120, 80)
        else:
            pond = Rect2(-999, -999, 4, 4)
    # smoke only exists where a crew structure does — sites without a
    # hut never light a chimney
    var smoke_at := _hut_px() + Vector2(-30, -58) \
        if _hut != null else Vector2(-999, -999)
    _amb = AmbientFX.new()
    _amb.name = "AmbientFX"
    _amb.bind(_fx, {
        "pond": pond,
        "treeline": Rect2(0, 30, GW * T, 70),
        "flutter": Rect2(150, 110, 360, 160),
        "lanterns": lamps,
        "smoke_at": smoke_at})
    stage.add_child(_amb)                    # over the world, under UI
    _amb.set_smoke(_hut != null
        and _crew_stage(_crew_sid()) > 0)


func _build_actors() -> void:
    var ch := WORLD_SCALE * 1.12    # ~0.9 — chars shrink slightly less
                                  # than props so they stay readable
    # Stone Fire Pit upgrade swaps the bare ground for the fitted
    # ring — drawn first so the flame loop sorts over it.  Lazy via
    # _sync_decor_world so a mid-session buy drops the ring in too.
    _sync_fire_pit()
    # fire loop — A1b cycle, frames 1..6 (frame 0 is the ignite lead-in)
    var fire := _anchored_frames("fx",
        ["fx/A1b_1", "fx/A1b_2", "fx/A1b_3", "fx/A1b_4", "fx/A1b_5",
         "fx/A1b_6"], 6.0, _fire_pos)
    fire.name = "FireLoop"
    # reduced-flashing setting: the 6 fps flame cycle is the one real
    # on-screen flicker — slow it to a breathing ember instead of
    # killing the fire outright (still reads as fire, stops strobing)
    if UIFeel.reduced_flashing:
        fire.speed_scale = 0.35
    fire.scale = Vector2(ch, ch)
    world.add_child(fire)
    # hearth light — the emit registry's first node row: a warm
    # pool that only exists once real dark falls (the "ember"
    # curve), so the fire pops against the night grade — the payoff
    # matrix.txt's storm-night table sells.  Texture generated —
    # radial falloff, no asset.
    var gg := Gradient.new()
    gg.set_color(0, Color(1, 1, 1, 1))
    gg.set_color(1, Color(1, 1, 1, 0))
    var gt := GradientTexture2D.new()
    gt.gradient = gg
    gt.width = 96
    gt.height = 96
    gt.fill = GradientTexture2D.FILL_RADIAL
    gt.fill_from = Vector2(0.5, 0.5)
    gt.fill_to = Vector2(1.0, 0.5)
    _fire_light = PointLight2D.new()
    _fire_light.name = "FireLight"
    _fire_light.position = _fire_pos + Vector2(0, -8)  # flames ride
                                                    # above the anchor
    _fire_light.color = Color(1.0, 0.60, 0.32)
    _fire_light.texture = gt
    _fire_light.texture_scale = 1.7        # ~80px pool over the ring
    _fire_light.energy = 0.0               # the ember curve owns it
    world.add_child(_fire_light)
    _fx.track_emit(&"fire", Color(1.5, 1.5, 1.5), &"ember",
        _fire_light, &"energy", 0.06)  # §5.10 hearth flicker —
                                       # storm turns it to sputter
    # warden idle-south (A2, 4f breathing) beside the fire
    var warden := _anchored_frames("chars",
        ["characters/warden/A2_idle_south_0",
         "characters/warden/A2_idle_south_1",
         "characters/warden/A2_idle_south_2",
         "characters/warden/A2_idle_south_3"], 4.0, WARDEN_POS)
    warden.scale = Vector2(ch, ch)
    world.add_child(warden)
    # camp dog idle (A3, 8f) — bean_quad cast, feet anchor at (26,38)
    var dog := _anchored_frames("chars",
        ["characters/bean_quad/A3_idle_south_0",
         "characters/bean_quad/A3_idle_south_1",
         "characters/bean_quad/A3_idle_south_2",
         "characters/bean_quad/A3_idle_south_3",
         "characters/bean_quad/A3_idle_south_4",
         "characters/bean_quad/A3_idle_south_5",
         "characters/bean_quad/A3_idle_south_6",
         "characters/bean_quad/A3_idle_south_7"], 5.0, _dog_pos,
        Vector2(26, 38))
    dog.scale = Vector2(ch, ch)
    world.add_child(dog)
    # ranger Mai keeps watch by the path bend
    var mai := _anchored("characters/ranger_mai",
                         "ranger_mai_south", MAI_POS)
    mai.scale = Vector2(ch, ch)
    world.add_child(mai)
    _char_shadow(WARDEN_POS, 34.0)
    _dog_shadow = _char_shadow(_dog_pos, 26.0)
    _char_shadow(MAI_POS, 34.0)
    actor_nodes = [warden, dog, mai]         # walk-behind fade set
    _actor_map = {"warden": warden, "dog": dog, "mai": mai}
    # §9 rounds — bean_quad walk anims swap in for the tween; the
    # idle loop owns him while he's posted.
    _dog_move = AnimatedSprite2D.new()
    _dog_move.centered = false
    _dog_move.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _dog_move.scale = Vector2(ch, ch)
    _dog_move.offset = -Vector2(26, 38)
    var dframes := SpriteFrames.new()
    for d4 in ["east", "south", "west", "north"]:
        dframes.add_animation(d4)
        dframes.set_animation_speed(d4, 8.0)
        for i in 8:
            dframes.add_frame(d4,
                _tex("characters/bean_quad/A3_walk_%s_%d" % [d4, i]))
    _dog_move.sprite_frames = dframes
    _dog_move.visible = false
    world.add_child(_dog_move)
    _dog_points = [_dog_pos,
        _fire_pos + Vector2(40, 18),
        _board_rect.get_center() + Vector2(10, 34)]
    var fsp: Variant = layout.get("errand_spots", {}).get("forage")
    if fsp != null:
        _dog_points.append(Vector2(fsp[0], fsp[1]) + Vector2(22, 14))
    _sync_decor_world()                      # placed pieces render always
    _build_overlay = BuildGrid.new()         # UI-033 cell-tint layer
    _build_overlay.org = origin
    _build_overlay.cell_px = CELL
    _build_overlay.visible = false
    _build_overlay.z_as_relative = false
    _build_overlay.z_index = 8               # tints ride above world art
    stage.add_child(_build_overlay)


# ----------------------------------------------------------------- UI
# HUD/panels/markers live in game/ui/ — chrome builders are UIKit statics,
# tokens come from UITokens, this file only wires the layers together.

func _build_ui() -> void:
    markers = WorldMarkers.new()               # WORLD_FEEDBACK tier
    markers.name = "Markers"
    add_child(markers)

    hud_layer = CanvasLayer.new()
    hud_layer.name = "HUD"
    hud_layer.layer = UITokens.Tier.HUD
    add_child(hud_layer)
    hud = HUD.new()                            # the chrome root itself —
    hud.name = "Chrome"                        # _fade_chrome modulates it
    hud_layer.add_child(hud)
    hud.phase_pressed.connect(_advance_phase)
    hud.cook_pressed.connect(
        func(): panel_mgr.open(PantrySheet.make()))
    hud.shop_pressed.connect(func(): _open_outfitter())
    hud.build_pressed.connect(_on_build_pressed)
    hud.crew_pressed.connect(func(): _open_crew())
    hud.map_pressed.connect(func():
        var ms := TrailMapSheet.make()
        ms.travel_requested.connect(_on_travel)
        panel_mgr.open(ms))
    hud.settings_pressed.connect(
        func(): panel_mgr.open(SettingsSheet.make()))
    hud.journal_pressed.connect(
        func(): panel_mgr.open(JournalSheet.make()))

    panel_mgr = PanelManager.new()             # PANEL tier, dimmer stack
    panel_mgr.name = "Panels"
    add_child(panel_mgr)
    panel_mgr.stack_changed.connect(_on_panels_changed)
    Platform.back_pressed.connect(_on_back)
    Platform.close_requested.connect(_on_close_window)
    # ceremony layer rides MODAL — above the panel stack and its dimmer
    _ceremony_layer = CanvasLayer.new()
    _ceremony_layer.layer = UITokens.Tier.MODAL
    _ceremony_layer.name = "CeremonyLayer"   # --hide QA hook
    add_child(_ceremony_layer)
    Game.crew_stage_ready.connect(func(_s):
        hud.set_crew_badge(true)
        _sync_crew_hut())
    Game.crew_collected.connect(_on_crew_collected)
    _sync_crew_hut()                           # restore state on reload
    Game.page_completed.connect(_on_page_completed)
    # §8.3 journal badge: unread mail count; refreshed on delivery and
    # whenever the panel stack settles (reading happens inside the sheet)
    Game.letter_delivered.connect(_refresh_journal_badge.unbind(1))
    _refresh_journal_badge()
    # spec 005: authored light cues — sheets declare WHAT cue is up
    # (vignette shown, ceremony playing, letter open); we apply it as
    # a moment-bound emit term on the scalar driver
    Game.light_cue_changed.connect(_on_light_cue)

    # fire proximity bubble — a world marker so it rides the canvas
    # transform (stage margins included); shown only while the pointer
    # is near the fire ring (GDD 17.5: bubbles over interactive objects)
    var fire_anchor := Node2D.new()
    fire_anchor.position = _fire_pos
    stage.add_child(fire_anchor)
    board_anchor = Node2D.new()              # UI-023: notice-board anchor
    board_anchor.position = BOARD_POS
    stage.add_child(board_anchor)
    var tok := markers.marker(fire_anchor, Vector2(-61, -74))
    fire_bubble = UIKit.panel(markers.marker_control(tok),
        Rect2(0, 0, 122, 41), "bubble_prompt")
    var fico := TextureRect.new()
    fico.texture = UIKit.icon("campfire")
    fico.position = Vector2(10, 3)
    fico.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fire_bubble.add_child(fico)
    var bl := UIKit.label_for(tr("hud_fire").to_upper(),
        UITokens.TypeRole.HEAD, UITokens.INK)
    bl.position = Vector2(30, 4)
    fire_bubble.add_child(bl)
    fire_bubble.modulate.a = 0.0
    fire_bubble.visible = false


func _fire_near(on: bool) -> void:
    if on == _fire_on or fire_bubble == null:
        return
    _fire_on = on
    if _fire_tween and _fire_tween.is_running():
        _fire_tween.kill()
    if on:
        fire_bubble.visible = true
    _fire_tween = UIFeel.apply(create_tween(), "fire")
    _fire_tween.tween_property(fire_bubble, "modulate:a",
        1.0 if on else 0.0, UIFeel.dur("fire"))
    if not on:
        _fire_tween.tween_callback(fire_bubble.hide)


func _on_panels_changed() -> void:
    # a modal sheet means the chrome is gone entirely — a 0.12 ghost
    # still renders its frames through the 45% scrim (they read as
    # stray lines stacked on the sheet's own chrome)
    if panel_mgr.top() != null:
        _fade_chrome(0.0)
    else:
        _wake_chrome()
    _refresh_journal_badge()


func _refresh_journal_badge() -> void:
    if hud:
        hud.set_journal_badge(Game.unread_letters().size())


func _on_back() -> void:
    ## §17.6: Back closes the top sheet; on the camp screen it asks first.
    if panel_mgr.top() != null:
        panel_mgr.close()
    elif _input.build_armed():
        _disarm_build()                    # drop the ghost, keep mode
    elif _pad_menu_pid != "":
        _close_pad_menu()
    elif _meal_sel >= 0:
        _tap_meal(-1)                        # disarm the plate
    elif _input.build_active():
        _set_build(false)
    else:
        _confirm_quit()


## Desktop window-X (Platform.close_requested): quit saves the run
## first — on mobile this never fires, on desktop the request is
## otherwise swallowed because auto_accept_quit is off.
func _on_close_window() -> void:
    Save.save_state(Game.state_dict())
    get_tree().quit()


func _confirm_quit() -> void:
    if _quit != null:
        return
    _quit = _quit_dialog()
    _quit.tree_exited.connect(func(): _quit = null)
    panel_mgr.open(_quit)


func _quit_dialog() -> Control:
    var vp := get_viewport_rect().size
    var p := Panel.new()
    p.size = Vector2(188, 96)
    p.position = (vp - p.size) / 2.0
    p.add_theme_stylebox_override("panel",
        UIKit.flat("glass_panel"))
    var m := MarginContainer.new()
    m.set_anchors_preset(Control.PRESET_FULL_RECT)
    m.add_theme_constant_override("margin_top", 12)
    m.add_theme_constant_override("margin_left", 12)
    m.add_theme_constant_override("margin_right", 12)
    m.add_theme_constant_override("margin_bottom", 10)
    p.add_child(m)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 10)
    m.add_child(v)
    var l := UIKit.label_for(tr("quit_title"), UITokens.TypeRole.HEAD,
        UITokens.PAPER)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(l)
    var brow := HBoxContainer.new()
    brow.add_theme_constant_override("separation", UITokens.SP2)
    var stay := UIKit.btn(brow, Vector2(74, UITokens.MIN_TOUCH),
        tr("quit_stay"), "green")
    stay.set_meta("primary", true)       # safe default for nav focus
    stay.pressed.connect(panel_mgr.close)
    var push := Control.new()
    push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    push.mouse_filter = Control.MOUSE_FILTER_IGNORE
    brow.add_child(push)
    var leave := UIKit.btn(brow, Vector2(74, UITokens.MIN_TOUCH),
        tr("quit_leave"))
    # parity with _on_close_window: a deliberate quit banks the day
    leave.pressed.connect(func():
        Game.commit()
        get_tree().quit())
    v.add_child(brow)
    return p


## Headless smoke (godot --headless --path game <scene> --smoke):
## exercises Back -> quit-confirm -> close and the fire-proximity
## bubble, prints assertions, quits.  Runs beside --shot, no prod cost.
func _smoke() -> void:
    # QA choreography lives in scripts/qa_smoke.gd (SOTA split: prod
    # scene owns world/HUD/FX, QaSmoke owns the --smoke drive). This
    # stays the one-line entry the --smoke flag calls.
    QaSmoke.run(self)


## Poll a condition each frame (cap ~4s) — tween timing varies headless.
## Kept for callers; the body lives on QaSmoke with the rest of the drive.
func _frames_until(cond: Callable, cap := 240) -> void:
    await QaSmoke.frames_until(self, cond, cap)


# ------------------------------------------------------------- guests

func _trait_map() -> Dictionary:
    if _trait_names.is_empty():
        for row in Catalog.data.get("traits", []):
            _trait_names[row.get("id", "")] = row.get("name", "?")
    return _trait_names


## Placeholder until persona art exists: one warden sprite tinted the
## way the old world-tray distinguished elite/loud guests.
func _tint(req: Dictionary) -> Color:
    if req.get("elite", false):
        return Color("ffcf7d")
    if req.get("loud", false):
        return Color("b8d7a8")
    return Color.WHITE


func _card_sprite(req: Dictionary) -> Dictionary:
    return {"tex": _tex("characters/warden/warden_south"),
        "tint": _tint(req)}


func _spawn_board() -> void:
    for n in guest_nodes.values():
        n.queue_free()
    for ts in tent_nodes.values():
        for t in ts:
            t.queue_free()
    guest_nodes = {}
    tent_nodes = {}
    var st: Dictionary = Game.site_state()
    selected = ""
    _meal_sel = -1
    _input.reset_gesture()
    _clear_bubbles()
    hud.tray.visible = true
    # §5.2: a favourite reads gold once its dish has ever been cooked —
    # cooking IS the discovery pass, so the card answers honestly
    var cooked := {}
    for r in Game.recipes_cooked:
        cooked[r] = true
    var meal_names := {}
    for req in st["board"]:
        var f := String(req.get("favourite", ""))
        if f != "" and not meal_names.has(f):
            meal_names[f] = _ing_name_row("recipes", f)
    for m in Game.meals:
        var f2 := String(m.get("id", ""))
        if not meal_names.has(f2):
            meal_names[f2] = _ing_name_row("recipes", f2)
    hud.tray.build(st["board"], _trait_map(), _card_sprite,
        cooked, meal_names)
    hud.tray.set_meals(Game.meals)           # §5.5 tonight's menu lane
    hud.tray.sync_served(st["served"], Game.meals)
    evening_open = true
    hud.set_report("")
    _sync_marks()


func _seat_visual(gid: String, pads: Array) -> void:
    var st: Dictionary = Game.site_state()
    var arch: String = st["guests"][gid].get("archetype", "")
    # a fresh world sprite joins the y-sort — feet just under the pad's
    # bottom edge so it sorts in front of the tent
    var g := Node2D.new()
    g.name = "w_" + gid
    # the seat sprite IS the evening cast face — persona_key picks
    # identically on both sides; ungenerated personas fall back to the
    # tinted stand-in
    var pk := SimDirector.persona_key(gid, arch, _cast_seed(),
        _actors_data())
    var s: Sprite2D
    if pk != "" and ResourceLoader.exists(
            A + "characters/%s/%s_south.png" % [pk, pk]):
        s = _anchored("characters/" + pk, pk + "_south", Vector2.ZERO)
    else:
        s = _anchored("characters/warden", "warden_south", Vector2.ZERO)
        s.modulate = _tint(st["guests"][gid])
    g.add_child(s)
    g.position = pad_cells[pads[0]].position + Vector2(12, CELL + 4)
    world.add_child(g)
    guest_nodes[gid] = g
    UIFeel.pop(g, Vector2(1.12, 0.85))   # landing squash — seats thud
    tent_nodes[gid] = []
    var idx := absi(hash(gid + arch) as int)
    for pid in pads:
        var tk: String = TENTS[idx % TENTS.size()]
        var t := _anchored("props_medium", tk, Vector2.ZERO)
        t.set_meta("tent_key", tk)      # night swap reads this
        idx += 1
        var r: Rect2 = pad_cells[pid]
        t.position = r.position + Vector2(CELL / 2.0, CELL)
        world.add_child(t)
        tent_nodes[gid].append(t)
    hud.tray.mark_seated(gid)
    _refresh_bubbles()
    _sync_marks()
    _sync_night_props()                        # evening arrival = lit
    _recast_if_evening()                       # the new guest walks in


func _unseat_visual(gid: String) -> void:
    if guest_nodes.has(gid):
        guest_nodes[gid].queue_free()
        guest_nodes.erase(gid)
    for t in tent_nodes.get(gid, []):
        t.queue_free()
    tent_nodes[gid] = []
    _sync_night_props()                        # freed pads go dark
    if guest_bubbles.has(gid):
        markers.release(guest_bubbles[gid])
        guest_bubbles.erase(gid)
    _clear_served_mark(gid)                  # their plate goes back
    hud.tray.mark_unseated(gid)
    _refresh_bubbles()
    _sync_marks()
    _recast_if_evening()


## UI-021: trait-state bubbles over seated guests.  Every trait gets a
## state glyph — "+" met, "−" tripped, "·" unresolved — never colour
## alone; the same sign vocabulary the breakdown strip uses before
## seating.  States come from the real resolve_guest detail, and every
## seat/unseat re-evaluates ALL seated guests because neighbour effects
## move other people's states (social fills, loud trips light_sleeper).
func _bubble_state(d: Dictionary) -> Dictionary:
    if d.get("tripped", false):
        return {"sign": "−", "color": UITokens.RED}
    if d.get("met", false):
        return {"sign": "+", "color": UITokens.GREEN}
    return {"sign": "·", "color": UITokens.DIM}


func _refresh_bubbles() -> void:
    var st: Dictionary = Game.site_state()
    for gid in st["assignments"]:
        var r := Game.preview(gid, st["assignments"][gid])
        if r.is_empty():
            continue
        var control: Control = null
        if guest_bubbles.has(gid):
            control = markers.marker_control(guest_bubbles[gid])
            if not is_instance_valid(control):
                control = null
        if control == null:
            var g: Node2D = guest_nodes.get(gid)
            if g == null:
                continue
            var anchor := Node2D.new()
            anchor.position = Vector2(0, -80)   # above the sprite's head
            g.add_child(anchor)
            guest_bubbles[gid] = markers.marker(anchor,
                Vector2(-40, 0))
            control = markers.marker_control(guest_bubbles[gid])
        _fill_bubble(control, r["detail"])


## Rebuild one bubble's chips: trait icons in a slot-dark tag, each
## carrying its state sign on the lower edge.
func _fill_bubble(control: Control, detail: Array) -> void:
    for c in control.get_children():
        c.queue_free()
    var w := detail.size() * 18 + 10
    var p := Panel.new()
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_theme_stylebox_override("panel",
        UIKit.flat("glass_chip", 1.0, 0.92))
    p.position = Vector2(40 - w / 2.0, 0)        # centred on the anchor
    p.size = Vector2(w, 22)
    control.add_child(p)
    var x := 5
    for d in detail:
        var st := _bubble_state(d)
        var chip := Control.new()
        chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
        chip.position = Vector2(x, 3)
        chip.size = Vector2(16, 16)
        var t := UIKit.icon_rect(String(d.get("trait", "")),
            Color(1, 1, 1, 0.65) if st["sign"] == "·" else null)
        chip.add_child(t)
        var l := UIKit.label_for(st["sign"], UITokens.TypeRole.HEAD,
            st["color"])
        l.position = Vector2(9, 5)
        chip.add_child(l)
        p.add_child(chip)
        x += 18


func _clear_bubbles() -> void:
    for tok in guest_bubbles.values():
        markers.release(tok)
    guest_bubbles = {}
    for tok in _served_marks.values():       # plates share the lifetime
        markers.release(int(tok))
    _served_marks = {}


## §5.5 dinner: a meal chip toggles the arm; armed, a seated guest tap
## (world sprite or seated card) serves the plate.  Serving the same
## dish again takes it back.
func _tap_meal(idx: int) -> void:
    _input.tap_meal(idx)

func _clear_served_mark(gid: String) -> void:
    if _served_marks.has(gid):
        markers.release(_served_marks[gid])
        _served_marks.erase(gid)


func _serve_tap(gid: String) -> void:
    _input.serve_tap(gid)

## Selection is the tap-tap path (UI-020): card tap -> previews +
## neutral strip; tap again to put the guest back.
func _select(gid: String) -> void:
    _input.select(gid)

func _deselect() -> void:
    _input.deselect()

func _tap_card(gid: String) -> void:
    _input.tap_card(gid)

func _try_seat(pid: String) -> void:
    _input.try_seat(pid)

func _do_unseat(gid: String) -> void:
    _input.do_unseat(gid)

## Card press -> drag (UI-020): the guest sprite rides the pointer
## until release; release over a pad seats exactly like a tap-tap.
func _begin_drag(gid: String) -> void:
    _input.begin_drag(gid)

func _end_drag(px: Vector2) -> void:
    _input.end_drag(px)

## Live strip: while a guest is selected, hovering an open pad shows
## the full score breakdown; anywhere else it falls back to the
## guest's neutral trait list.
func _update_strip(px: Vector2) -> void:
    _input.update_strip(px)

## Pad rings show on open pads with nobody seated — the tent itself
## is the occupied state (§5.1).
func _sync_marks() -> void:
    var st: Dictionary = Game.site_state()
    for pid in pad_cells:
        var mark := pads_node.get_node_or_null("mark_" + pid)
        if mark:
            mark.visible = st["pads"].get(pid, {}).get("open", false) \
                and not _pad_occupied(pid)


## Pads a guest would take starting at pid — one, or pid plus its
## first free neighbour for a two-pad party.
func _pads_for(gid: String, pid: String) -> Array:
    return _input.pads_for(gid, pid)

func _show_previews(gid: String) -> void:
    _input.show_previews(gid)

func _clear_previews() -> void:
    _input.clear_previews()

func _pad_occupied(pid: String) -> bool:
    return _input.pad_occupied(pid)

func _status() -> void:
    var st: Dictionary = Game.site_state()
    # ranger's tips setting gates the [hint] tail; the status facts
    # themselves always show
    var hint := "   [%s]" % tr("tray_hint") \
        if bool(Game.settings.get("rangers_tips", true)) else ""
    hud.set_status(("day %d · site day %d · %s · %dc%s") % [
        Game.day, Game.site_day(), st["weather"].to_upper(), Game.coins,
        hint])
    # ambience is a live mix owned by WorldFX — the dusk + front
    # scalars crossfade day birds / night crickets / storm wash
    hud.set_crew_badge(Game.is_stage_ready())
    # the button is the phase action, not the phase name (§4 table:
    # Evening -> Goodnight, Night -> Sleep, Morning -> Head out)
    hud.set_phase(tr("hud_goodnight").to_upper() if evening_open \
        else (tr("hud_headout").to_upper() \
            if Game.phase == Game.Phase.PREP \
            else (tr("hud_prep").to_upper() \
                if Game.phase == Game.Phase.MORNING \
                else tr("hud_sleep").to_upper())))
    hud.set_rating(night_rating if night_rating else "—")
    hud.set_coins(tr("hud_coins_short") % Game.coins)
    hud.set_day("%s %d · %s" % [tr("hud_day").to_upper(), Game.day,
        tr("weather_" + String(st["weather"])).to_upper()],
        st["weather"])


func _goodnight() -> void:
    # capture names before goodnight() clears st["guests"]
    var names := {}
    for gid in Game.site_state()["guests"]:
        names[gid] = Game.site_state()["guests"][gid].get("name", gid)
    var rep := Game.goodnight()
    night_rating = "%.1f" % rep["rating"]
    if rep["rating"] >= 4.99 and not _five_star_seen:
        _five_star_seen = true              # first-ever 5★ earns the beat
        _queue_ceremony("fivestar", tr("cer_five"), "", "star_full")
    evening_open = false
    _deselect()
    _clear_bubbles()
    hud.tray.reset()
    hud.tray.visible = false
    _status()
    # spec 005 A: tonight's vignette is a beat — the card shows in the
    # sheet and its `cue` light term grades the world behind it; clears
    # whichever way the sheet leaves (Sleep or a dimmer-dismiss)
    var vid := String(rep.get("vignette", ""))
    if vid != "":
        var vrow := _vignette_row(vid)
        var cue: Dictionary = vrow.get("cue", {})
        if not cue.is_empty():
            Game.set_light_cue("vig_" + vid,
                Color(String(cue.get("col", "e8c46a"))),
                StringName(cue.get("w", "ember")))
    # UI-022: the payoff sheet — reviews with breakdowns, totals,
    # pages, forecast, Double-tips offer, Sleep
    var sheet := NightSummary.make(rep, names, Game.day,
        Game.forecast())
    sheet.sleep_pressed.connect(_on_sleep)
    if vid != "":
        sheet.tree_exited.connect(
            func(): Game.clear_light_cue("vig_" + vid))
    panel_mgr.open(sheet)
    sheet.run_count_up.call_deferred()


func _vignette_row(vid: String) -> Dictionary:
    for v in Catalog.data.get("vignettes", []):
        if v.get("id") == vid:
            return v
    return {}


## Sleep exits the night (§4 phase table): close the summary and roll
## into the next morning — same path the phase button takes.
func _on_sleep() -> void:
    UIFeel.haptic("confirm")
    panel_mgr.close()
    _advance_phase()


func _advance_phase() -> void:
    if evening_open:
        _goodnight()
    elif Game.phase == Game.Phase.MORNING:
        UIFeel.haptic("confirm")               # into the day's prep
        UIFeel.sfx("confirm")
        _start_prep()
    elif Game.phase == Game.Phase.PREP:
        UIFeel.haptic("confirm")               # Head out — guests arrive
        UIFeel.sfx("confirm")
        _start_evening()
    else:                                      # Night -> next Morning
        hud.set_report("")
        Game.advance_day()                     # set_phase(MORNING) inside
        Ads.show_interstitial()                # §24.2 pacing-gated mock
        _start_morning()


## UI-023 Morning: camp is quiet — the notice board is the interactive
## object.  A "!" marker floats over the signpost until Head out.
func _start_morning() -> void:
    evening_open = false
    _clear_cast()                            # last night's cast is home
    _cast_day()                              # morning ambience joins
    _set_build(false)                          # build tools stay out
    _clear_errands()                           # a new day re-rolls nodes
    _sync_crew_hut()                           # day-2 crew may start here
    _check_dog_adoption()                      # Friend bond → naming sheet
    # "!" chip over the notice board — flat glass chip; gold glyph.
    # offset places it just over the signpost's visible head — the
    # prop is mostly occluded by the chest + warden tent
    var bang := UIKit.label_for("!", UITokens.TypeRole.DISPLAY,
        UITokens.GOLD)
    bang.position = Vector2(8, -1)
    var rc: Array = markers.icon_chip(board_anchor, bang,
        Vector2(-11, -42), Vector2(22, 22))
    _board_tok = rc[0]
    var bub: Panel = rc[1]
    # gentle bob so the marker reads alive, not painted on the prop.
    # Gate: under reduced motion/flashing a set_loops() tween at the
    # collapsed 1ms duration would be an infinite strobe — skip it.
    bub.pivot_offset = bub.size / 2.0
    if UIFeel.can_pulse():
        # bound to the chip so the loop dies when the marker releases —
        # a scene-bound loop would keep stepping a freed target
        var bob := UIFeel.apply(bub.create_tween().set_loops(), "marker")
        var bd := UIFeel.dur("marker")
        bob.tween_property(bub, "scale", Vector2(1.12, 1.12), bd)
        bob.tween_property(bub, "scale", Vector2.ONE, bd)
    _check_dialogue()
    _status()


## Authored light cue -> moment-bound emit term on WorldFX (spec 005).
## Single-slot in Game; we translate set/clear into track/untrack —
## "ember" warm beats, "dusk" night beats, "flat" held tints.
var _cue_id := ""

func _on_light_cue(cue: Dictionary) -> void:
    if _cue_id != "":
        _fx.untrack_emit(StringName(_cue_id))
        _cue_id = ""
    if not cue.is_empty() and _fx != null:
        _cue_id = String(cue["id"])
        _fx.track_emit(StringName(_cue_id), cue["col"],
            StringName(cue["w"]))


## Morning dialogue (UI-038 world half): rows from data/dialogue.json
## whose site+day match and haven't run yet queue onto the actors'
## markers, one bubble at a time.  spec 005: `when` rows react to
## last night's resolution — a matching conditional beats plain
## `day` rows to the front of the queue.
func _check_dialogue() -> void:
    _dlg_queue.clear()
    var when_rows := []
    var day_rows := []
    var rows: Array = Catalog.data.get("dialogue", [])
    for d in rows:
        if d.get("site", "") != String(Game.site_id):
            continue
        if Game.dialogue_seen.get(d.get("id", ""), false):
            continue
        if not _actor_map.has(d.get("anchor", "")):
            continue
        var w: Dictionary = d.get("when", {})
        if not w.is_empty():
            if Game.dialogue_when_ok(w):
                when_rows.append(d)
        elif int(d.get("day", -1)) == Game.site_day():
            day_rows.append(d)
    _dlg_queue = when_rows + day_rows
    _run_dialogue()


func _run_dialogue() -> void:
    if _dlg_queue.is_empty() or _dlg_tok != 0:
        return
    var d: Dictionary = _dlg_queue.pop_front()
    var anchor: Node2D = _actor_map[d["anchor"]]
    Game.dialogue_seen[d["id"]] = true
    _dlg_tok = DialogueBubble.say(markers, anchor,
        Vector2(-DialogueBubble.W / 2.0, -66), String(d.get("who", "")),
        d.get("lines", []), func(): _dlg_tok = 0; _run_dialogue())


# ---------------------------------------------------------- ceremonies

func _on_crew_collected(_structure: StringName, keepsake: StringName,
		_finished: bool) -> void:
    hud.set_crew_badge(Game.is_stage_ready())
    _sync_crew_hut(true)               # the cleared stage scatters off
    _queue_ceremony("keepsake", tr("cer_keepsake"),
        _keepsake_label(String(keepsake)), "keepsakes")


func _on_page_completed(_site: StringName, _page: int, gift: int,
		_unlocks: Array) -> void:
    var sub := tr("cer_gift").format({"n": gift}) if gift > 0 else ""
    _queue_ceremony("page", tr("cer_page"), sub, "journal")


## Milestones queue — a page completing on load or a keepsake landing
## the same tick as a 5★ night must never stack cards.  Held during
## boot (signals can fire inside _ready) and played one at a time.
var _ceremony_q := []
var _ceremony_busy := false

func _queue_ceremony(kind: String, title: String, sub: String,
		icon: String) -> void:
    _ceremony_q.append([kind, title, sub, icon])
    _drain_ceremonies()


## spec 005 A3: ceremony kind -> authored light cue (the world grades
## while the card is up).  Warm for milestones, gold for the perfect
## night, a journal-blue for pages.
const CEREMONY_CUE := {
    "fivestar": {"col": Color("e8c46a"), "w": &"flat"},
    "keepsake": {"col": Color("c9a45c"), "w": &"flat"},
    "page":     {"col": Color("7a9ac4"), "w": &"flat"},
}

func _drain_ceremonies() -> void:
    if _ceremony_busy or not _booted or _ceremony_q.is_empty():
        return
    _ceremony_busy = true
    var c: Array = _ceremony_q.pop_front()
    var kind := String(c[0])
    # spec 005 A3: each ceremony kind grades the world while its card
    # is up — the Eastward pattern of authored light on the beat
    var cue: Dictionary = CEREMONY_CUE.get(kind, {})
    if not cue.is_empty():
        Game.set_light_cue("cer_" + kind, cue["col"], cue["w"])
    Ceremony.play(_ceremony_layer, kind, String(c[1]),
        String(c[2]), String(c[3]),
        func() -> void:
            Game.clear_light_cue("cer_" + kind)
            _ceremony_busy = false
            _drain_ceremonies())


func _keepsake_label(kid: String) -> String:
    var structures: Array = Catalog.data.get("crew", {}) \
        .get("structures", [])
    for s in structures:
        for st in s.get("stages", []):
            if st.get("keepsake", {}).get("id") == kid:
                return String(st["keepsake"].get("label", kid))
    return kid


func _start_evening() -> void:
    if _board_tok:
        markers.release(_board_tok)
        _board_tok = 0
    _set_build(false)                          # tools down at dusk
    _clear_errands()                           # prep closes at dusk
    _sync_crew_hut()                           # porch glow wakes at dusk
    Game.set_phase(Game.Phase.EVENING)
    _spawn_board()
    _cast_evening()                            # D4 — tonight's cast on
    _status()


# ------------------------------------------------- D4 actor layer (§17)
#
# Sim-first actors: cast_night resolves Game state -> SimWorld
# programs once per evening; ActorView performs them under a fixed-dt
# sim clock that freezes while any sheet is open (§17 — nothing
# walks while you read). The seat sprite IS the cast face — both
# sides draw through persona_key(gid, seed), so a mid-night re-seat
# just recasts and the new guest walks in.

func _cast_seed() -> int:
    return int(abs(hash("cast:%s:%d" % [Game.site_id, Game.day])))


func _actors_data() -> Dictionary:
    return Catalog.data.get("actors", {})


func _cast_evening() -> void:
    _sim = SimDirector.cast_night(Game.site_state(), layout,
        _cast_seed(), _actors_data())
    if _actor_view == null:
        _actor_view = ActorView.new()
        add_child(_actor_view)
    _actor_view.clear()
    _actor_view.configure(_sim, _actors_data(), world, _tex,
        func() -> bool: return panel_mgr.top() != null,
        WORLD_SCALE * 1.12, _emote_show, _emote_hide)
    _sync_seat_actors()


## Day ambience (§3 "alive in ten seconds"): while the player reads
## the board or works prep, locals + the dog drift the errand loop.
## Same presenter, calmer cast — no guest parties until dusk.
func _cast_day() -> void:
    _sim = SimDirector.cast_day(Game.site_state(), layout,
        _cast_seed(), _actors_data(), Game.last_night_perfect())
    if _actor_view == null:
        _actor_view = ActorView.new()
        add_child(_actor_view)
    _actor_view.clear()
    _actor_view.configure(_sim, _actors_data(), world, _tex,
        func() -> bool: return panel_mgr.top() != null,
        WORLD_SCALE * 1.12, _emote_show, _emote_hide)


func _recast_if_evening() -> void:
    if Game.phase == Game.Phase.EVENING:
        _cast_evening()
    elif Game.phase in [Game.Phase.MORNING, Game.Phase.PREP]:
        _cast_day()                            # build changed the set


## The sim actor IS the guest once cast — the stand-in seat sprite
## hides (the node stays: bubbles/plates/taps anchor to the pad,
## not to the walking figure).
func _sync_seat_actors() -> void:
    var cast := {}
    if _sim != null:
        for eid in _sim.query(["persona"]):
            var gid := String(_sim.getc(eid, "persona")
                .get("guest", ""))
            if gid != "":
                cast[gid] = true
    for gid in guest_nodes:
        var n: Node2D = guest_nodes[gid]
        if n.get_child_count() > 0:
            (n.get_child(0) as CanvasItem).visible = not cast.has(gid)


func _clear_cast() -> void:
    if _actor_view != null:
        _actor_view.clear()
    _sim = null
    for gid in guest_nodes:
        var n: Node2D = guest_nodes[gid]
        if n.get_child_count() > 0:
            (n.get_child(0) as CanvasItem).visible = true


## Emote chips — sim emote comp -> marker chip over the actor sprite.
## Icon strings route through the registry where they can, a glyph
## label otherwise.
func _emote_show(anchor: Node2D, icon: String) -> int:
    var map := {"!": "alert", "?": "question", "heart": "heart"}
    var ik := String(map.get(icon, ""))
    var content: Control
    if ik != "":
        content = UIKit.icon_rect(ik, UITokens.PAPER, 10)
    else:
        content = UIKit.label_for(icon, UITokens.TypeRole.DISPLAY,
            UITokens.GOLD)
    return int(markers.icon_chip(anchor, content, Vector2(8, -42))[0])


func _emote_hide(tok: int) -> void:
    markers.release(tok)


## Outfitter (UI-032) — the decor tab's Place rows hand off to build
## mode through the sheet's place_requested signal.
func _open_outfitter(tab := "gear") -> void:
    var s := OutfitterSheet.make(tab)
    s.place_requested.connect(_on_place_requested)
    panel_mgr.open(s)


## The notice board sheet (§17.2): tonight's requests + the forecast.
func _open_booking() -> void:
    var st: Dictionary = Game.site_state()
    var open_n := 0
    for pid in st["pads"]:
        if st["pads"][pid].get("open", false):
            open_n += 1
    var cooked := {}
    for r in Game.recipes_cooked:
        cooked[r] = true
    panel_mgr.open(BookingBoard.make(st["board"],
        String(st["weather"]), open_n, _card_sprite, _trait_map(),
        cooked))


# ------------------------------------------------------------- prep (§7)
#
# The day's middle: the board is already known, tonight's favourites
# steer what you gather.  Errand nodes are day-scoped — they roll with
# the morning, the layer fades at dusk.  Gear-gated taps answer with a
# hint chip, not silence — they advertise the outfitter (UI-032).

func _start_prep() -> void:
    Game.set_phase(Game.Phase.PREP)
    _cast_day()                              # recast over any build edits
    _spawn_errands()
    _status()


## Decal reads the node's contents at a glance; gold pops for the rare.
func _errand_decal(node: Dictionary) -> String:
    var items: Array = node.get("items", [])
    var first := String(items[0]) if not items.is_empty() else ""
    if "goldcap" in items:
        return "decal_mushroom_orange"         # the rare one reads gold
    match first:
        "berries":  return "decal_berries_red"
        "mushroom": return "decal_mushroom_brown"
        "honey":    return "decal_flowers_white"
        _:          return "decal_plantain"    # herb / generic forage


func _spawn_errands() -> void:
    _clear_errands()
    _errand_layer = Node2D.new()
    _errand_layer.name = "Errands"
    world.add_child(_errand_layer)
    _sync_errand_nodes()
    var es: Dictionary = layout.get("errand_spots", {})
    # fishing water is authored per site: pinewatch's lone "pond" anchor
    # or whisper_river's named banks — each spot keeps its own daily
    # catch count in the sim
    _fish_spots = []
    if es.has("pond"):
        _add_errand_spot("pond", es["pond"], "fish", "pond")
    for k in es.get("fishing", {}):
        _add_errand_spot("fish_" + String(k), es["fishing"][k],
            "fish", String(k))
    if es.has("lookout"):
        _add_errand_spot("lookout", es["lookout"], "eye", "lookout")
    _sync_dog_chip()
    _sync_pad_chips()


func _add_errand_spot(key: String, a: Variant, icon: String,
		spot := "") -> void:
    var anchor := Node2D.new()
    anchor.position = Vector2(float(a[0]), float(a[1])).round()
    _errand_layer.add_child(anchor)
    _errand_anchors[key] = anchor
    _afford_chip(anchor, icon, key)
    if spot != "" and icon == "fish":
        _fish_spots.append({"key": key, "node": anchor, "spot": spot})


## One forage node = one decal + one leaf affordance chip above it.
func _spawn_errand_node(node: Dictionary) -> void:
    var nid := String(node["id"])
    var p: Array = node.get("px", [0, 0])
    var spr := _anchored("decals", _errand_decal(node),
        Vector2(float(p[0]), float(p[1])))
    _errand_layer.add_child(spr)
    _errand_nodes[nid] = spr
    _afford_chip(spr, "leaf", nid)


## Spotting can append a bonus node mid-prep — spawn visuals for any
## sim node that doesn't have one yet.
func _sync_errand_nodes() -> void:
    if _errand_layer == null:
        return
    for node in Game.site_state()["forage_nodes"]:
        var nid := String(node["id"])
        if not _errand_nodes.has(nid):
            _spawn_errand_node(node)


## The stray advertises a pet only while today's pet is unspent.
func _sync_dog_chip() -> void:
    var tok := int(_errand_marks.get("dog", 0))
    var want := bool(Game.dog.get("met", false)) \
        and not bool(Game.dog.get("pet_today", false))
    if tok != 0 and not want:
        markers.release(tok)
        _errand_marks.erase("dog")
    elif tok == 0 and want and _actor_map.has("dog"):
        _afford_chip(_actor_map["dog"], "dog", "dog")


## The quiet affordance: a small icon chip riding the node's marker.
func _afford_chip(anchor: Node2D, icon: String, key: String) -> void:
    var ic := UIKit.icon_rect(icon, UITokens.PAPER, 12)
    ic.position = Vector2(3, 3)
    _errand_marks[key] = markers.icon_chip(anchor, ic,
        Vector2(-9, -30))[0]


## Result feedback: a chip pops over the spot, holds a readable beat,
## veils out, releases its marker.  Reduced motion keeps the hold —
## the fade is the motion, not the point.
func _float_chip(anchor: Node2D, text: String, icon := "") -> void:
    var tok := markers.marker(anchor, Vector2(-40, -48))
    var chip := PanelContainer.new()
    chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    chip.add_theme_stylebox_override("panel", UIKit.flat("glass_chip"))
    var h := HBoxContainer.new()
    h.mouse_filter = Control.MOUSE_FILTER_IGNORE
    h.add_theme_constant_override("separation", UITokens.SP1)
    chip.add_child(h)
    if icon != "":
        h.add_child(UIKit.icon_rect(icon, UITokens.GOLD, 12))
    if text != "":
        h.add_child(UIKit.label_for(text, UITokens.TypeRole.CAPTION,
            UITokens.PAPER))
    var host: Control = markers.marker_control(tok)
    host.add_child(chip)
    chip.resized.connect(func():
        chip.position.x = -chip.size.x / 2.0   # centre once measured
        chip.pivot_offset = chip.size / 2.0)   # and pop around centre
    UIFeel.pop(chip)
    var tw := create_tween()
    tw.tween_interval(0.75)
    UIFeel.apply(tw, "veil_out")
    tw.tween_property(chip, "modulate:a", 0.0, UIFeel.dur("veil_out"))
    tw.tween_callback(func(): markers.release(tok))


func _ing_name(item_id: String) -> String:
    for r in Catalog.data.get("ingredients", []):
        if r.get("id") == item_id:
            return String(r.get("name", item_id))
    return item_id


## "+2 Berries" — per-kind counts, ingredient names match the pantry.
func _gain_text(items: Array) -> String:
    var counts := {}
    for i in items:
        var k := String(i)
        counts[k] = int(counts.get(k, 0)) + 1
    var parts := []
    for k in counts:
        parts.append("+%d %s" % [counts[k], _ing_name(k)])
    return "  ".join(parts)


func _free_errand(nid: String) -> void:
    var spr: Node2D = _errand_nodes.get(nid)
    if spr != null:
        var tw := UIFeel.apply(create_tween(), "veil_out")
        tw.tween_property(spr, "modulate:a", 0.0, UIFeel.dur("veil_out"))
        tw.tween_callback(spr.queue_free)
        _errand_nodes.erase(nid)
    var tok := int(_errand_marks.get(nid, 0))
    if tok != 0:
        markers.release(tok)
        _errand_marks.erase(nid)


func _clear_errands() -> void:
    for tok in _errand_marks.values():
        markers.release(int(tok))
    _errand_marks = {}
    _errand_nodes = {}
    _errand_anchors = {}
    for tok in _pad_chips.values():
        markers.release(int(tok))
    _pad_chips = {}
    _close_pad_menu()
    if _errand_layer != null:
        _errand_layer.queue_free()
        _errand_layer = null


## PREP tap routing.  Returns a tag for the smoke harness; hit-test
## order is pads (fixed landmarks) -> forage -> pond -> lookout -> dog.
func _prep_tap(px: Vector2) -> String:
    return _input.prep_tap(px)

# ------------------------------------------------------------ the dog
## §9 rounds + adoption.  Rounds are view-only: a waypoint ring, a
## directional still while he walks, the idle loop while posted.  The
## tap zone and pet chip ride dog.position so both keep working mid-
## walk.  Adoption: Friend-level bond opens the naming prompt once.

func _dog_walk(dog: AnimatedSprite2D) -> void:
    if _dog_points.is_empty():
        return
    # pick from reachable waypoints only — choosing his own spot used
    # to no-op the tick (and flaked the smoke assert ~25% of runs)
    var cands: Array = []
    for p in _dog_points:
        if (p as Vector2).distance_to(dog.position) >= 10.0:
            cands.append(p)
    if cands.is_empty():
        return
    var next: Vector2 = cands[randi() % cands.size()]
    _dog_walking = true
    var dir := next - dog.position
    _dog_move.animation = _dir4(dir)
    _dog_move.position = dog.position
    _dog_move.visible = true
    _dog_move.play()
    dog.visible = false
    var dur := dir.length() / 36.0           # ~36px/s waddle
    var tw := dog.create_tween().set_parallel()
    tw.tween_property(dog, "position", next, dur)
    tw.tween_property(_dog_move, "position", next, dur)
    if _dog_shadow != null:
        tw.tween_property(_dog_shadow, "position",
            next + Vector2(2.0, -1.0), dur)
    tw.chain().tween_callback(func():
        _dog_move.visible = false
        dog.visible = true
        _dog_walking = false)


## 8-way direction name -> camp_dog_<dir>.png still.
func _dir8(d: Vector2) -> String:
    var oct: int = int(round(d.angle() / (PI / 4.0))) & 7
    return ["east", "south-east", "south", "south-west",
        "west", "north-west", "north", "north-east"][oct]


## 4-way direction name -> bean_quad A3_walk_<dir> anim (diagonals
## fold to the nearest cardinal).
func _dir4(d: Vector2) -> String:
    var q: int = int(round(d.angle() / (PI / 2.0))) & 3
    return ["east", "south", "west", "north"][q]


func _check_dog_adoption() -> void:
    if not bool(Game.dog.get("met", false)) or Game.dog_adopted() \
            or Game.dog_level() < 2:
        return
    call_deferred("_open_adopt")


func _open_adopt() -> void:
    if Game.dog_adopted() or panel_mgr == null:
        return
    var cur := String(Game.dog.get("name", "Bean"))
    if TranslationServer.get_locale().begins_with("vi"):
        cur = String(Catalog.data.get("dog", {}).get("name_vi", cur))
    var s := AdoptSheet.make(cur)
    s.named.connect(_on_dog_named)
    panel_mgr.open(s)


func _on_dog_named(n: String) -> void:
    Game.adopt_dog(n)
    UIFeel.sfx("confirm")
    UIFeel.haptic("confirm")
    var dog: Node2D = _actor_map.get("dog")
    if dog != null:
        _float_chip(dog, String(Game.dog.get("name", "")), "heart")


## Generic row-name lookup (birds etc.) — same convention as _ing_name.
func _ing_name_row(list_name: String, rid: String) -> String:
    for r in Catalog.data.get(list_name, []):
        if r.get("id") == rid:
            return String(r.get("name", rid))
    return rid


# ------------------------------------------------------- build (UI-033)
#
# Build mode is a PREP tool.  The HUD hammer toggles it; the outfitter's
# decor tab arms a piece (buy-on-place — the charge lands on the drop,
# refundable until Goodnight).  The ghost snaps to the footprint cell —
# never under the finger — tinted by the real placement rule, and the
# overlay reads the same legal set the sim enforces.  Placed pieces are
# world sprites forever; build mode only edits them.

## decor id -> [atlas folder, sprite].  campfire-size rows upgrade the
## ring itself (no world node); aura rows are glow zones, never drawn.
const DECOR_SPRITE := {
    "stools": ["props_medium", "stool_pair"],
    "bench": ["props_medium", "log_bench"],
    "picnic_table": ["props_large", "picnic_table"],
    "lantern": ["props_medium", "lantern_post"],
    "string_lights": ["props_large", "string_lights"],
    "silk_lantern": ["props_small", "silk_lantern_red"],
    "planter": ["props_medium", "flower_box"],
    "lotus": ["props_small", "lotus_bowl"],
    "flower_arch": ["props_large", "flower_arch"],
    "tarp": ["props_medium", "drying_tarp"],
    "hedge": ["props_medium", "bush_clover"],
    "reed_screen": ["props_medium", "reed_screen"],
    "dog_bed": ["props_medium", "dog_bed"],
    "guitar_stump": ["props_small", "guitar"],
    "wind_chime": ["props_small", "chili_garlic_string"],
    "radio": ["props_medium", "radio_stump"],
    "swing": ["props_large", "swing"],
    "kite": ["props_small", "kite"],
    "telescope": ["props_medium", "viewpoint_binoculars"],
    "scout_pennant": ["props_medium", "scout_pennant"],
    "koi_pond": ["props_large", "koi_pond"],
    "photo_wall": ["props_medium", "photo_wall"],
    "stone_fire_pit": ["props_medium", "stone_fire_pit"],
}


func _cell_px(c: Vector2i) -> Vector2:
    return _input.cell_px(c)

## Footprint anchor: bottom-centre of the covered cells — the same
## convention every world prop uses.
func _foot_anchor_px(cells: Array) -> Vector2:
    return _input.foot_anchor_px(cells)

## Placed decor lives in the world permanently — rebuilt wholesale on
## any verb change (sets are small) so index keys always match the sim.
func _sync_decor_world() -> void:
    if _decor_layer == null:
        _decor_layer = Node2D.new()
        _decor_layer.name = "Decor"
        world.add_child(_decor_layer)
    for c in _decor_layer.get_children():
        c.queue_free()
    _decor_nodes = {}
    var st: Dictionary = Game.site_state()
    for i in st["decor"].size():
        var d: Dictionary = st["decor"][i]
        if d.get("aura", false):
            continue                       # glow zones, no sprite
        var spec: Array = DECOR_SPRITE.get(String(d["id"]), [])
        if spec.is_empty():
            continue
        var spr := _anchored(spec[0], spec[1], _foot_anchor_px(
            d.get("cells", [])))
        spr.set_meta("decor_idx", i)
        _decor_layer.add_child(spr)
        _decor_nodes[i] = spr
    _sync_fire_pit()


## The campfire-size row (Stone Fire Pit) mutates campfire.radius —
## never lands in st["decor"] — so its ring sprite is maintained
## here: spawn once upgraded, drop if the save ever regresses.
func _sync_fire_pit() -> void:
    var up := Game.fire_pit_upgraded()
    if up and (_fire_pit == null or not is_instance_valid(_fire_pit)):
        _fire_pit = _anchored("props_medium", "stone_fire_pit",
            _fire_pos)
        world.add_child(_fire_pit)
        var flame := world.get_node_or_null("FireLoop")
        if flame:                          # under the flame loop
            world.move_child(_fire_pit, flame.get_index())
    elif not up and _fire_pit != null and is_instance_valid(_fire_pit):
        _fire_pit.queue_free()
        _fire_pit = null


func _decor_row_for(item_id: String) -> Dictionary:
    for r in Catalog.data.get("decor", []):
        if r.get("id") == item_id:
            return r
    return {}


## Toggle from the HUD hammer.  Outside PREP the camp keeps working —
## a hint chip says why instead of silently ignoring.
func _on_build_pressed() -> void:
    _input.on_build_pressed()

func _set_build(on: bool) -> void:
    _input.set_build(on)

## {id, kind: buy|stored|move, idx} — arms the ghost.  move reuses the
## piece's own cells (ignore) so it can land where it already sits.
func _arm_build(item: Dictionary) -> void:
    _input.arm_build(item)

func _disarm_build() -> void:
    _input.disarm_build()

## The persistent twin of _float_chip — rides the armed ghost, says
## "{name} · {effect}" until the piece lands or the arm is cancelled.
func _build_hint_show() -> void:
    _input.build_hint_show()

## Screen-space nudge for "wrong phase" presses — same glass chip,
## pinned bottom-centre (no world anchor to ride).
func _hud_hint(text: String) -> void:
    var chip := PanelContainer.new()
    chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    chip.add_theme_stylebox_override("panel", UIKit.flat("glass_chip"))
    chip.add_child(UIKit.label_for(text, UITokens.TypeRole.CAPTION,
        UITokens.PAPER))
    chip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    chip.position.y -= UITokens.MIN_TOUCH + 24
    hud_layer.add_child(chip)
    UIFeel.pop(chip)
    var tw := create_tween()
    tw.tween_interval(0.9)
    UIFeel.apply(tw, "veil_out")
    tw.tween_property(chip, "modulate:a", 0.0, UIFeel.dur("veil_out"))
    tw.tween_callback(chip.queue_free)


## Hand-off from the outfitter's Place button: sheet closes, PREP arms.
func _on_place_requested(item_id: String, from_stored: bool) -> void:
    _input.on_place_requested(item_id, from_stored)

## Pointer cell under the footprint rule: 1x1 snaps to the cell; 2x1
## picks the nearer horizontal pair, preferring a legal pair.
func _footprint_at(px: Vector2) -> Array:
    return _input.footprint_at(px)

## Motion: ghost snaps to the candidate, tinted by the real rule —
## green legal, red blocked; the reach ring previews coverage.
func _ghost_to(px: Vector2) -> void:
    _input.ghost_to(px)

## Build-mode tap.  Armed -> place attempt; else piece taps open the
## Move/Store/Return context row.  Returns a tag for the smoke.
func _build_tap(px: Vector2) -> String:
    return _input.build_tap(px)

func _try_place(px: Vector2) -> String:
    return _input.try_place(px)

## Wobble rejection — the ghost rocks and nothing else happens.
func _ghost_wobble() -> void:
    _input.ghost_wobble()

func _decor_idx_at(px: Vector2) -> int:
    return _input.decor_idx_at(px)

## Context row on a tapped piece: Move re-arms the ghost with kind
## "move", Store packs it, today's buys return for the full price.
func _open_piece_menu(idx: int) -> void:
    _close_piece_menu()
    var d: Dictionary = Game.site_state()["decor"][idx]
    var tok := markers.marker(_decor_nodes[idx], Vector2(-72, -66))
    var chip := PanelContainer.new()
    chip.add_theme_stylebox_override("panel", UIKit.flat("glass_chip"))
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 2)
    chip.add_child(h)
    var item_id := String(d["id"])
    var mv := UIKit.icon_btn(h, "edit")
    mv.tooltip_text = tr("bld_move")
    mv.pressed.connect(func():
        _close_piece_menu()
        _arm_build({"id": item_id, "kind": "move", "idx": idx}))
    var sb := UIKit.icon_btn(h, "box")
    sb.tooltip_text = tr("bld_store")
    sb.pressed.connect(func():
        if Game.store_decor(idx):
            UIFeel.sfx("close")
            _close_piece_menu()
            _sync_decor_world()
            _build_overlay.free_cells = Game.decor_cells_free()
            _build_overlay.queue_redraw())
    if item_id in Game.bought_today:
        var row := _decor_row_for(item_id)
        var rb := UIKit.btn(h, Vector2(64, UITokens.MIN_TOUCH),
            tr("bld_return").format({"p": int(row.get("price", 0))}),
            "pill", Control.SIZE_SHRINK_CENTER)
        rb.tooltip_text = tr("bld_return")
        rb.pressed.connect(func():
            if Game.return_bought(item_id):
                UIFeel.sfx("coin")
                _close_piece_menu()
                _sync_decor_world()
                _build_overlay.free_cells = Game.decor_cells_free()
                _build_overlay.queue_redraw()
                _status())
    markers.marker_control(tok).add_child(chip)
    _build_menu_tok = tok


func _close_piece_menu() -> void:
    if _build_menu_tok != 0:
        markers.release(_build_menu_tok)
        _build_menu_tok = 0


# ------------------------------------------------------------- pads

## Pad state -> sprite + shelter overlay.  Called on load (restore),
## after clear_pad, and after upgrade_pad.
func _sync_pad_visual(pid: String) -> void:
    var st: Dictionary = Game.site_state()["pads"].get(pid, {})
    var spr: Sprite2D = pads_node.get_node_or_null("mark_" + pid)
    if spr == null:
        return
    spr.texture = _tex("pad_open" if st.get("open", false) \
        else "pad_locked")
    # ground tile: open pads sit on packed pitch earth.  The clear
    # scatter shrinks the overgrown tile away; this resurfaces it in
    # its cleared outfit (the marker pop carries the beat — pop
    # tweens to scale 1.0 which would break a shrunken decal).
    var gnd: Sprite2D = pads_node.get_node_or_null("ground_" + pid)
    if gnd != null and st.get("open", false):
        gnd.texture = _tex("decals/pad_cleared")
        gnd.rotation = 0.0
        gnd.modulate.a = 1.0
        gnd.scale = Vector2.ONE * float(gnd.get_meta("s0", 1.0))
    var shelter := String(st.get("shelter", "bare"))
    if shelter == "bare" or _pad_shelters.has(pid):
        return
    var ov := _anchored("props_medium" if shelter == "platform" \
        else "props_large",
        "pallet_deck" if shelter == "platform" else "cottage_shed",
        pad_cells[pid].position + Vector2(CELL / 2.0, CELL))
    ov.set_meta("shelter", shelter)           # night swap reads this
    var w := ov.texture.get_width() * ov.scale.x
    if w > CELL * 1.05:                      # pad furniture, not a prop
        ov.scale *= CELL * 1.05 / w
    pads_node.add_child(ov)                  # under tents when seated
    _pad_shelters[pid] = ov


## PREP affordances on pads that still need work: muted lock while
## locked, accent hand once it's paid-and-waiting.
func _sync_pad_chips() -> void:
    for tok in _pad_chips.values():
        markers.release(int(tok))
    _pad_chips = {}
    if Game.phase != Game.Phase.PREP:
        return
    var pads: Dictionary = Game.site_state()["pads"]
    for pid in pad_cells:
        var st: Dictionary = pads.get(pid, {})
        if st.get("open", false) or _pad_clearing.has(pid):
            continue
        var node := pads_node.get_node_or_null("mark_" + pid)
        if node == null:
            continue
        var paid: bool = st.get("paid", false)
        var pair: Array = markers.icon_chip(node,
            UIKit.icon_rect("hand" if paid else "lock",
                UITokens.GOLD if paid else UITokens.MUTE, 12),
            Vector2(CELL / 2.0 - 9, -26))
        _pad_chips[pid] = pair[0]


## Tap on a pad -> context row: locked sells the unlock, paid offers
## Clear, open+bare lists shelter upgrades.  Nothing actionable -> no
## menu (the tap falls through to a dismiss).
func _open_pad_menu(pid: String) -> void:
    _close_pad_menu()
    var st: Dictionary = Game.site_state()["pads"].get(pid, {})
    var node := pads_node.get_node_or_null("mark_" + pid)
    if node == null:
        return
    var chip := PanelContainer.new()
    chip.add_theme_stylebox_override("panel", UIKit.flat("glass_chip"))
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 2)
    chip.add_child(h)
    var n := 0
    if not st.get("open", false):
        if st.get("paid", false):
            var cb := UIKit.btn(h, Vector2(64, UITokens.MIN_TOUCH),
                tr("pad_clear"), "pill", Control.SIZE_SHRINK_CENTER)
            cb.pressed.connect(func():
                _close_pad_menu()
                _play_clear(pid))
            n += 1
        else:
            var price := Game.pad_unlock_price(pid)
            if price >= 0:
                var ub := UIKit.btn(h, Vector2(96, UITokens.MIN_TOUCH),
                    tr("pad_unlock").format({"p": price}), "pill",
                    Control.SIZE_SHRINK_CENTER)
                ub.disabled = Game.coins < price
                ub.pressed.connect(func():
                    if Game.unlock_pad(pid):
                        UIFeel.sfx("coin")
                        UIFeel.haptic("medium")
                        _status()
                        _sync_pad_chips()
                        _open_pad_menu(pid))   # row rebuilds: now Clear
                n += 1
    else:
        for opt in Game.pad_shelter_options(pid):
            var sh := String(opt["shelter"])
            var ob := UIKit.btn(h, Vector2(110, UITokens.MIN_TOUCH),
                tr("pad_shelter_" + sh).format({"p": int(opt["price"])}),
                "pill", Control.SIZE_SHRINK_CENTER)
            ob.disabled = (not opt["unlocked"]) \
                or Game.coins < int(opt["price"])
            ob.pressed.connect(func():
                if Game.upgrade_pad(pid, sh):
                    UIFeel.sfx("coin")
                    UIFeel.haptic("medium")
                    _status()
                    _sync_pad_visual(pid)
                    _close_pad_menu())
            n += 1
    if n == 0:
        return
    var tok := markers.marker(node, Vector2(-50, -66))
    markers.marker_control(tok).add_child(chip)
    _pad_menu_tok = tok
    _pad_menu_pid = pid
    UIFeel.pop(chip)


func _close_pad_menu() -> void:
    if _pad_menu_tok != 0:
        markers.release(_pad_menu_tok)
        _pad_menu_tok = 0
    _pad_menu_pid = ""


## Paid pad -> the clear transform is the reward: weeds and leaf litter
## scatter off, the pad brightens, then clear_pad lands the state and
## the open texture swaps in.  Skipped shells under reduced motion.
func _play_clear(pid: String) -> void:
    _pad_clearing[pid] = true
    _sync_pad_chips()
    var spr := pads_node.get_node_or_null("mark_" + pid)
    var tuft := pads_node.get_node_or_null("tuft_" + pid)
    var gnd := pads_node.get_node_or_null("ground_" + pid)
    var r: Rect2 = pad_cells[pid]
    if UIFeel.reduced_motion:
        if tuft != null:
            tuft.queue_free()
        _finish_clear(pid)
        return
    var litter := ["decal_fern_frond", "decal_leaf_single", "decal_twig"]
    for i in 3:
        var d := _anchored("decals", litter[i],
            r.position + Vector2(10 + i * 20, 28 + (i % 2) * 14))
        pads_node.add_child(d)
        var tw := d.create_tween()
        tw.set_parallel()
        tw.tween_property(d, "position",
            d.position + Vector2((i - 1) * 24.0, -30.0), 0.6)\
            .set_delay(0.06 * i)
        tw.tween_property(d, "rotation_degrees",
            (i - 1) * 160.0, 0.6).set_delay(0.06 * i)
        tw.chain().tween_property(d, "modulate:a", 0.0, 0.16)
        tw.finished.connect(d.queue_free)
    if tuft != null:
        var tw2 := tuft.create_tween()
        tw2.set_parallel()
        tw2.tween_property(tuft, "rotation_degrees", 200.0, 0.55)
        tw2.tween_property(tuft, "scale", Vector2.ZERO, 0.55)
        tw2.tween_property(tuft, "modulate:a", 0.0, 0.55)
        tw2.finished.connect(tuft.queue_free)
    if gnd != null:
        # the overgrown plot shrinks into the earth — _finish_clear
        # resurfaces it as the packed pitch tile
        var twg := gnd.create_tween()
        twg.set_parallel()
        twg.tween_property(gnd, "rotation_degrees", 120.0, 0.55)
        twg.tween_property(gnd, "scale", Vector2.ZERO, 0.55)
        twg.tween_property(gnd, "modulate:a", 0.0, 0.55)
    if spr != null:
        var tw3 := spr.create_tween()
        tw3.tween_property(spr, "modulate",
            Color(1.35, 1.3, 1.1), 0.25).set_delay(0.3)
    get_tree().create_timer(0.58).timeout.connect(
        _finish_clear.bind(pid))


func _finish_clear(pid: String) -> void:
    if Game.clear_pad(pid):
        UIFeel.sfx("confirm")
        UIFeel.haptic("medium")
    _sync_pad_visual(pid)
    var spr := pads_node.get_node_or_null("mark_" + pid)
    if spr != null:
        spr.modulate = Color.WHITE
        UIFeel.pop(spr, Vector2(1.15, 0.85))
    _pad_clearing.erase(pid)
    _sync_pad_chips()


# ----------------------------------------------------- crew structure
## §8.4/UI-035 world presence: the site's crew structure (Pinewatch =
## the warden's hut, drawn as the `cabin` prop) dresses per art_state
## and carries the affordance chip — "!" gold while a stage sits ready,
## the dim crew glyph while work runs.  Tapping it opens the same
## CrewSheet the HUD button does.  Stage is derived from collected
## keepsakes so a swapped-out active structure can't desync the prop.

func _crew_sid() -> String:
    var plots: Array = layout.get("crew_plots", [])
    for p in plots:
        if p.get("kind") == "structure":
            return String(p.get("structure", ""))
    return ""


func _crew_rows(sid: String) -> Dictionary:
    for s in Catalog.data.get("crew", {}).get("structures", []):
        if s.get("id") == sid:
            return s
    return {}


## Stage = count of this structure's keepsakes already collected —
## crew["stage"] only describes the ACTIVE structure, collected[] is
## the durable record.
func _crew_stage(sid: String) -> int:
    var n := 0
    var got: Array = Game.crew.get("collected", [])
    for st in _crew_rows(sid).get("stages", []):
        if got.has(st.get("keepsake", {}).get("id", "")):
            n += 1
    return n


func _hut_px() -> Vector2:
    return _input.hut_px()

## The hut is anonymous scenery until the crew engages (day-2 start or
## any collected stage) — a "!" on a ruin the player was never told
## about reads as a bug, not a mystery.
func _hut_engaged() -> bool:
    var sid := _crew_sid()
    return sid != "" and (Game.crew.get("structure", "") == sid
        or _crew_stage(sid) > 0)


func _hut_rect() -> Rect2:
    return _input.hut_rect()

func _open_crew() -> void:
    panel_mgr.open(CrewSheet.make())


## UI-034: the trail map is a morning act (§8.2) — the verb enforces
## it; a true return reloads the scene so layout/props/anchors rebuild
## for the new site in one _ready pass.
func _on_travel(site: StringName) -> void:
    if not Game.travel_to(site):
        UIFeel.sfx("warn")
        _hud_hint(tr("map_morning"))
        return
    UIFeel.sfx("confirm")
    UIFeel.haptic("confirm")
    panel_mgr.close()
    Transition.to_scene(get_tree().current_scene.scene_file_path)


func _hut_tap(px: Vector2) -> bool:
    return _input.hut_tap(px)

func _painted_map() -> bool:
    ## True when the site ships a PixelLab object layer — authored art
    ## owns static props, so runtime sprite stand-ins stay hidden.
    return FileAccess.file_exists(
        "res://assets/%s/objects.json" % _site_id)


## Idempotent state->view pass: debris + dim by stage, porch glow once
## restored (evening/night only), chip by work state.  animate=true on
## collect so the cleared stage visibly scatters before the rebuild.
func _sync_crew_hut(animate := false) -> void:
    var sid := _crew_sid()
    if _hut == null or sid == "":
        return
    var stage := _crew_stage(sid)
    var total: int = _crew_rows(sid).get("stages", []).size()
    var restored := total > 0 and stage >= total
    if _amb != null:                         # kitchen smoke = crew
        _amb.set_smoke(stage > 0)            # living/working in it
    # stage art swap (Batch H): the sprite itself carries the state —
    # ruin -> cleared -> roof fixed -> restored cabin.  A lit-window
    # night variant lands at dusk once the hut is whole again.
    # Painted maps: the authored house is the visual; no sprite swaps.
    var painted := _painted_map()
    if not painted:
        var day_tex: String = HUT_STAGES[mini(stage,
            HUT_STAGES.size() - 1)]
        var want := String(day_tex)
        if restored and Game.phase in [Game.Phase.EVENING,
                Game.Phase.NIGHT] and ResourceLoader.exists(
                A + "props_large/cabin_night.png"):
            want = "cabin_night"
        if ResourceLoader.exists(A + "props_large/%s.png" % want):
            _hut.texture = _tex("props_large/" + want)
    if _hut_dress != null:
        var old := _hut_dress
        _hut_dress = null
        if animate and not UIFeel.reduced_motion:
            var tw := old.create_tween().set_parallel()
            for c in old.get_children():
                tw.tween_property(c, "position",
                    c.position + Vector2(randf_range(-26.0, 26.0),
                        randf_range(4.0, 14.0)), 0.55) \
                    .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
                tw.tween_property(c, "modulate:a", 0.0, 0.55)
            tw.chain().tween_callback(old.queue_free)
        else:
            old.queue_free()
    _hut_dress = Node2D.new()
    _hut_dress.name = "CrewDress"
    _hut_dress.position = _hut_px()          # sorts with the hut itself
    world.add_child(_hut_dress)
    _hut.modulate = Color.WHITE              # sprite carries state
    if stage == 0 and not painted:
        # ruin reads through the litter on its footprint
        for spec in [["props_medium", "debris_brambles", -26, 8],
                ["props_medium", "debris_branch_pile", 20, 12],
                ["props_medium", "debris_brambles", 4, 18]]:
            var d := _anchored(spec[0], spec[1],
                Vector2(spec[2], spec[3]))
            _hut_dress.add_child(d)
    elif restored:
        # the porch light: a small lantern by the door, warm pool at dusk
        var lamp := _anchored("props_medium", "lantern_post",
            Vector2(34, 14))
        _hut_dress.add_child(lamp)
        var glow := Sprite2D.new()
        glow.texture = _shadow_texture()
        glow.modulate = Color(0.95, 0.78, 0.42, 0.55)
        glow.position = Vector2(30, 16)
        glow.scale = Vector2(0.9, 0.5)
        glow.visible = Game.phase in [Game.Phase.EVENING,
            Game.Phase.NIGHT]
        _hut_dress.add_child(glow)
    # --- affordance chip: "!" while a stage waits on the player
    var show := _hut_engaged() and not restored
    _hut_ready = show and Game.crew.get("structure", "") == sid \
        and Game.is_stage_ready()
    if show:
        var content: Control
        if _hut_ready:
            var bang := UIKit.label_for("!", UITokens.TypeRole.HEAD,
                UITokens.GOLD)
            bang.position = Vector2(6, -2)
            content = bang
        else:
            content = UIKit.icon_rect("crew", UITokens.DIM, 12)
            content.position = Vector2(3, 3)
        var pair: Array = markers.icon_chip(_hut, content,
            Vector2(0, -88))
        if _hut_tok:
            markers.release(_hut_tok)
        _hut_tok = int(pair[0])
    elif _hut_tok:
        markers.release(_hut_tok)
        _hut_tok = 0


# ------------------------------------------------------------- input

func _pad_at(px: Vector2) -> String:
    return _input.pad_at(px)

func _guest_at(px: Vector2) -> String:
    return _input.guest_at(px)

func _unhandled_input(event: InputEvent) -> void:
    _input.unhandled(event)

## The commit side of the tap lane — runs only on release inside
## TAP_SLOP.  Same hit-test order the old press path used: morning +
## prep answer board/hut/camp work; the evening lane answers meal
## chips, seated guests, then pad seating; night stays a spectator.
func _commit_map_tap(sp: Vector2, mpx: Vector2, px: Vector2) -> void:
    _input.commit_map_tap(sp, mpx, px)

# ------------------------------------------------------------- classes

## Build-mode grid overlay (UI-033): faint legal cells while armed, the
## candidate footprint tinted by the real placement rule, and the reach
## ring previewing coverage.  One custom-draw item — cheaper than a
## sprite per cell and always in the scene's own px space.
class BuildGrid:
    extends Node2D

    var org := Vector2.ZERO
    var cell_px := 64.0
    var free_cells: Array = []
    var cand: Array = []
    var ok := false
    var reach := 0
    var anchor := Vector2.ZERO

    func _draw() -> void:
        for c in free_cells:
            draw_rect(Rect2(org + Vector2(c) * cell_px,
                Vector2(cell_px, cell_px)),
                Color(0.55, 0.9, 0.55, 0.10), true)
        if reach > 0:
            draw_arc(anchor, (reach + 0.4) * cell_px, 0.0, TAU, 28,
                Color(1.0, 0.85, 0.45, 0.35), 2.0)
        if not cand.is_empty():
            var cc := Color(0.55, 1.0, 0.6, 0.34) if ok \
                else Color(1.0, 0.42, 0.35, 0.36)
            for c in cand:
                draw_rect(Rect2(org + Vector2(c) * cell_px,
                    Vector2(cell_px, cell_px)), cc, true)


