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
const GW := 20                               # ground width  (tiles)
const GH := 12                               # ground height (tiles)
const UUUU := Vector2i(0, 3)                 # atlas coords of the all-upper
                                             # wang tile in every pro sheet

# ---------------------------------------------------------------- terrain
# masks copied from tools/scene_comp_v2.py — the layout authority.
const PATH := [Vector2i(10, 11), Vector2i(10, 10), Vector2i(9, 10),
               Vector2i(9, 9), Vector2i(9, 8), Vector2i(9, 7),
               Vector2i(10, 7), Vector2i(11, 7), Vector2i(12, 7),
               Vector2i(13, 7)]
const FOREST_ROW3_GAPS := [4, 5, 11, 12, 17]

# ------------------------------------------------------ macro ground zones
# Tile-swap zones are FORBIDDEN (style lock, 2026-10-12): macro variation
# comes from fx/ground_tintmap.png — one baked 640x360 RGBA overlay drawn
# as the GroundTint sprite above Ground+Scatter, below World (soft
# warm/cool fields + sun pools + treeline shade, alpha 10-30%).
# What stays on the tilemap: tracked-down-to-dirt wear (the T3
# forest-floor tile) — under each tent, at the fire ring's front lip,
# the path-top junction — 3 cells each.  Ground tells a story.
const LLLL := Vector2i(2, 1)                 # all-lower tile = solid
                                             # forest floor (T3 sheet)
const WEAR_CELLS := [Vector2i(6, 7), Vector2i(7, 7), Vector2i(6, 8),
                     Vector2i(5, 9), Vector2i(6, 9), Vector2i(7, 9),
                     Vector2i(10, 8), Vector2i(11, 8), Vector2i(10, 9),
                     Vector2i(13, 6), Vector2i(12, 6), Vector2i(14, 7)]

# --------------------------------------------------------- fill variants
# The two pure fills per sheet (UUUU grass / LLLL lower) stamped one
# identical tile over ~100 cells — the strongest tiling tell.  The
# tileset carries 36 one-tile variant sources after the 3 wang sheets
# (tools/make_tileset.py): source = 3 + sheet*12 + fill*6 + variant,
# same peering bits as the base tile.  Pure-fill cells get re-seated on
# a hash-picked variant below; transition tiles keep their edge config.
const VAR_SRC0 := 3
const VAR_N := 6

# ------------------------------------------------------------- prop comp
# [category dir, file stem, anchor x, anchor y, lean deg?] — mirrors the
# P() calls in tools/scene_comp_v2.py, drawn into the y-sorted world so
# footing and overlaps sort themselves out.
# Phase 0.3: regrouped into 4 storytelling clusters (sub-cell jitter,
# mild overlap, pads/pond/path kept clear, site layout kept: van NW,
# trees top, fire centre, pond SW).  Phase 0.1: an optional 5th element
# leans the prop ±2-4° about its base — loose freestanding props only,
# never anchored/large ones (van, cabin, trees).
const PROPS := [
    # ------------------------------------------------- treeline + cabin
    # T2 trees break the row: broadleaf between pads, copper maple
    # over the (locked) p3, cherry framing the rest corner
    ["props_large",  "pine_tall_a",        74,  96],
    ["props_large",  "pine_tall_b",       156, 102],
    ["props_large",  "tree_broadleaf",    210,  96],
    ["props_large",  "flamboyant_tree",   262,  94],
    ["props_large",  "tree_maple",        484,  96],
    ["props_large",  "pine_tall_a",       540,  92],
    ["props_large",  "bamboo_clump",      606,  96],
    ["props_large",  "tree_cherry",       616, 130],
    ["props_large",  "cabin",             428, 128],
    ["props_large",  "pennant_string",    345, 168],
    # undergrowth at treeline feet — breaks the flat row
    ["props_medium", "bush_round_m",      138, 136],
    ["props_medium", "fern_bank",         350, 140],
    ["props_medium", "bush_clover",       386, 148],
    ["props_small",  "mushrooms_orange",  268, 138],
    ["props_medium", "debris_brambles",   442, 134],
    # ---------------- outfitter camp (NW): van, stools, crates, signpost
    ["props_large",  "outfitter_van",     110, 178],
    ["props_medium", "prop_supply_crate_0", 206, 188],
    ["props_small",  "non_la_hat",        209, 196],
    ["props_medium", "stool_pair",        172, 200],
    ["props_medium", "moped_cub",          78, 208],
    ["props_small",  "signpost",          222, 208, 2.5],
    ["props_small",  "stool_plastic_blue",148, 214],
    ["props_small",  "stool_plastic_red", 186, 214],
    # unloading vignette: gear spilling out of the van's open back
    ["props_small",  "duffel_bag",        152, 196],
    # ------- camp kitchen (centre): fire, tripod, bench, stump, lantern
    ["props_medium", "lantern_post",      356, 218, -3.0],
    ["props_medium", "dome_tent_sage",    212, 232],
    ["props_medium", "tripod_cauldron",   302, 238],
    ["props_medium", "dirt_patch",        326, 250],
    ["props_medium", "radio_stump",       370, 258],
    ["props_medium", "log_bench",         256, 262],
    # A-R4 gear cluster by the sage dome: cooler + chair at its mouth
    ["props_small",  "cooler_box",        240, 246],
    ["props_small",  "folding_chair_pair", 200, 258, -4.0],
    ["props_small",  "propane_stove",     300, 264],
    # kitchen woodpile + old-fire story
    ["props_medium", "debris_branch_pile",352, 272],
    ["props_medium", "stump_burnt",       396, 262],
    # L6 work items: firewood + chopping block beside the kitchen
    ["props_small",  "firewood_bundle",   336, 276],
    ["props_small",  "axe_on_log",        380, 272],
    # ---------- rest corner (E): hammock by the pine, picnic set below
    ["props_large",  "hammock",           566, 150],
    ["props_large",  "picnic_table",      516, 250],
    ["props_medium", "picnic_basket",     498, 266],
    ["props_medium", "tea_table",         472, 276],
    ["props_medium", "dome_tent_amber",   192, 300, -2.5],
    # A-R4 gear cluster by the amber dome: table + bags + lantern
    ["props_medium", "camp_table_fold",   232, 312],
    ["props_small",  "dry_bag",           168, 314],
    ["props_small",  "solar_lantern",     246, 322],
    # third pitch on the south field — slate dome + gear vignette
    ["props_medium", "dome_tent_slate",   400, 326],
    ["props_small",  "duffel_bag",        356, 334],
    ["props_small",  "camp_pillow",       366, 340, -3.0],
    # spare unlit fire pit near the rest corner (storytelling; the A1b
    # flame loop stays on the shipped ring at the kitchen fire)
    ["props_medium", "fire_ring_unlit_v2", 565, 294],
    ["props_medium", "bush_white_flower_v", 534, 300],
    ["props_medium", "stump_mushroom",    596, 280],
    # A-R1 T2 composite: feathery canopy drooping over the pond west edge
    ["props_large",  "tree_feathery",     108, 272],
    # pond dressing: reeds + shore edges + islet + lily pads
    ["props_medium", "reed_shore",         58, 252],
    ["props_medium", "reed_shore",        142, 334],
    ["terrain",      "shore_edge_bank",   150, 268],
    ["terrain",      "shore_edge_bank",   152, 306],
    ["terrain",      "shore_islet",        95, 300],
    ["decals",       "decal_lily_pad",     60, 290],
    ["decals",       "decal_lily_pad",     90, 314],
    ["decals",       "decal_lily_pad",     42, 268],
    ["props_small",  "rock_mossy_s",      162, 250],
    # ------- work edge (NE/E): coop, herbs, broom, planter, spirit house
    # cottage_shed = shipped cabin reused as a small second structure in
    # the row-3 treeline gap, back-left of the coop/spirit_house pair
    ["props_large",  "cottage_shed",      566, 110],
    ["props_small",  "spirit_house",      596, 130],
    ["props_medium", "flower_box",        408, 158],
    ["props_medium", "chicken_coop",      540, 164],
    ["props_small",  "chili_garlic_string", 518, 170],
    ["props_small",  "dried_fish_rack",   482, 166],
    ["props_small",  "S_15",              566, 178],
    # wood-working vignette: fallen log, dead stump, gnarled root, sapling
    ["props_medium", "debris_log_mossy",  505, 148],
    ["props_medium", "stump_dead",        575, 152],
    ["props_small",  "root_gnarled",      458, 152],
    ["props_medium", "pine_sapling",      628, 158],
]
# props that get NO foreground embed decal (it IS the ground, or it
# sits in/at the water where a front tuft would float)
const EMBED_SKIP := ["dirt_patch", "reed_shore", "shore_edge_bank",
                     "shore_islet", "decal_lily_pad"]

const FIRE_POS := Vector2(326, 246)          # A1b fire-loop anchor
const WARDEN_POS := Vector2(348, 262)
const DOG_POS := Vector2(300, 306)
const MAI_POS := Vector2(468, 254)
const BOARD_POS := Vector2(222, 208)         # signpost = notice board (UI-023)
const BOARD_RECT := Rect2(204, 160, 40, 52)  # its tap zone in stage px

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

# ------------------------------------------------------------- grade pass
const WARM_MUL := Color("fbf4e4")            # sunny filmic multiply —
                                             # #f4ead3 over-darkened the
                                             # scene (2026-10-12 review);
                                             # kept near-white so the day
                                             # reads bright/sunny
const SKY_TOP := Color("e8dcc0")             # backdrop sky (pale warm)
const SKY_BOT := Color("b9a888")             # backdrop horizon -> dirt
const SKY_H := 118.0                         # gradient band height px
const TREE_FAR := Color(0.62, 0.66, 0.72)    # shadowed treeline tints —
const TREE_MID := Color(0.57, 0.61, 0.68)    # lightened ~10% vs the fresh
const TREE_NEAR := Color(0.51, 0.55, 0.62)   # v2 ground so they don't
                                             # read dead-black
# Edge-clustered decals (ground recipe): ~14 total, ONE family per
# cluster, ONLY at edges — prop bases, pond shoreline, treeline feet.
# Open-field interior stays EMPTY; the tint map carries macro variation.
# [centre x, centre y, family, count, radius x, radius y, terrain want]
const DECAL_CLUSTERS := [
    [212.0, 247.0, "tuft",   2, 16.0, 8.0, 0],   # dome_tent_sage base
    [192.0, 316.0, "dry",    2, 16.0, 8.0, 0],   # dome_tent_amber base
    [400.0, 340.0, "tuft",   2, 18.0, 7.0, 0],   # dome_tent_slate base
    [256.0, 272.0, "pebble", 2, 12.0, 6.0, 0],   # log_bench feet
    [540.0, 174.0, "tuft",   1, 10.0, 6.0, 0],   # chicken_coop base
    [118.0, 192.0, "pebble", 1, 10.0, 6.0, 0],   # van wheel line
    [140.0, 300.0, "pebble", 2, 14.0, 24.0, 0],  # pond shoreline
    [150.0, 288.0, "moss",   2, 14.0, 26.0, 0],  # pond bank damp
    [110.0, 288.0, "moss",   1, 12.0, 10.0, 0],  # willow foot
    [238.0, 121.0, "litter", 2, 16.0, 5.0, 1],   # treeline floor W
    [210.0, 116.0, "litter", 1, 14.0, 6.0, 1],   # broadleaf foot
    [484.0, 112.0, "litter", 1, 14.0, 6.0, 1],   # maple foot
    [616.0, 148.0, "flower", 1, 12.0, 6.0, 0],   # cherry foot
    [565.0, 168.0, "dry",    1, 14.0, 7.0, 0],   # work-edge stump vignette
    [505.0, 160.0, "litter", 1, 12.0, 6.0, 0],   # mossy log base
    # pad fringes — break the flat-tan read on pitch edges
    [ 96.0, 168.0, "pebble", 1, 20.0, 5.0, 0],   # p1/p4 fringe
    [288.0, 172.0, "tuft",   1, 20.0, 5.0, 0],   # p2 south fringe
    [480.0, 172.0, "pebble", 1, 20.0, 5.0, 0],   # p3 south fringe
    [288.0, 282.0, "pebble", 1, 20.0, 5.0, 0],   # p7 north fringe
    [480.0, 282.0, "tuft",   1, 20.0, 5.0, 0],   # p8 north fringe
    [608.0, 230.0, "dry",    1, 14.0, 6.0, 0],   # p5 fringe / rest corner
    [486.0, 122.0, "litter", 2, 18.0, 5.0, 1],   # treeline floor E
    [408.0, 166.0, "flower", 1, 10.0, 6.0, 0],   # flower_box base
]
const DECAL_GROUND := Color(1.0, 1.0, 1.0, 0.85)
                                             # sink decals INTO the wash

var layout: Dictionary
var origin: Vector2
var anchors := {}                            # "cat/name.png" -> {anchor_x,y}
var pad_cells := {}                          # pid -> Rect2 (px)

var ground: TileMapLayer
var stage: Node2D                            # all world layers — centred on
                                             # wide viewports (aspect=expand)
var scatter: Node2D
var pads_node: Node2D
var world: Node2D
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
var _quit: Control                           # quit-confirm panel (one at a time)

var selected := ""                           # guest id being placed
var guest_nodes := {}                        # gid -> seated world Node2D
var tent_nodes := {}                         # gid -> [Sprite2D]
var star_labels := {}                        # pid -> preview Node2D
var evening_open := true                     # Enter -> Goodnight
var night_rating := ""
var _press := {}                             # pending card press {gid, pos}
var _drag_ghost: Sprite2D                    # sprite following a card drag
var _trait_names := {}                       # tid -> name (lazy)
var guest_bubbles := {}                      # gid -> trait-state marker token
var board_anchor: Node2D                     # notice-board prop anchor (UI-023)
var _board_tok := 0                          # morning "!" marker token

var _tex_cache := {}


func _tex(rel: String) -> Texture2D:
    if not _tex_cache.has(rel):
        _tex_cache[rel] = load(A + rel + ".png")
    return _tex_cache[rel]


## Sprite2D whose bottom-center (or anchors.json anchor) sits at pos.
func _anchored(cat: String, n: String, pos: Vector2) -> Sprite2D:
    var s := Sprite2D.new()
    s.texture = _tex(cat + "/" + n)
    var e: Dictionary = anchors.get(cat + "/" + n + ".png", {})
    var ax: float = e.get("anchor_x", s.texture.get_width() / 2.0)
    var ay: float = e.get("anchor_y", float(s.texture.get_height()))
    s.centered = false
    s.offset = -Vector2(ax, ay)
    s.position = pos
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
    a.centered = false
    var sz: Vector2 = frames.get_frame_texture("main", 0).get_size()
    var an := anchor if anchor.x >= 0.0 else Vector2(sz.x / 2.0, sz.y)
    a.offset = -an
    a.position = pos
    a.play("main")
    return a


func _ready() -> void:
    anchors = JSON.parse_string(
        FileAccess.get_file_as_string(A + "anchors.json"))
    layout = Catalog.data["layouts"]["pinewatch"]
    var opx: Array = layout["camp_core_origin_px"]
    origin = Vector2(opx[0], opx[1])
    var rng := RandomNumberGenerator.new()
    rng.seed = 7

    var grade := CanvasModulate.new()        # warm sunny filmic multiply;
    grade.name = "WarmGrade"                 # HUD sits in its own
    grade.color = WARM_MUL                   # CanvasLayer, unaffected
    add_child(grade)

    stage = Node2D.new()                     # every world layer lives under
    stage.name = "Stage"                     # Stage so _fit_stage() can centre
    add_child(stage)                         # the map inside wide viewports
    _fit_stage()
    get_viewport().size_changed.connect(_fit_stage)

    _build_ground()
    _build_backdrop()
    _build_scatter(rng)
    # macro ground colour: the baked tint field sits above Ground +
    # Scatter (terrain + decals get sun pools / shade) and below World
    # (props and characters stay unaffected) — replaces tile-swap zones
    var tint := Sprite2D.new()
    tint.name = "GroundTint"
    tint.texture = _tex("fx/ground_tintmap")
    tint.centered = false
    stage.add_child(tint)
    pads_node = Node2D.new()
    pads_node.name = "Pads"
    stage.add_child(pads_node)
    _build_pads(rng)
    world = Node2D.new()
    world.name = "World"
    world.y_sort_enabled = true
    stage.add_child(world)
    _build_props()
    _build_actors()
    marks = Node2D.new()
    marks.name = "Marks"
    stage.add_child(marks)
    hover = Sprite2D.new()
    hover.texture = _tex("pad_hover")
    hover.centered = false
    hover.visible = false
    marks.add_child(hover)
    _build_ui()
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
    if shot_arg != "" or OS.get_cmdline_args().has("--shot"):
        Transition.snap_reveal()
        await get_tree().process_frame
        await get_tree().process_frame
        var img := get_viewport().get_texture().get_image()
        var out := shot_arg if shot_arg != "" else \
            "D:/monet/trail-bound/assets_src/cleanup/pinewatch_engine_graded.png"
        print("scene shot ->", out, " err:", img.save_png(out))
        get_tree().quit()


func _process(delta: float) -> void:
    if hud == null:
        return
    idle_ms += delta
    if idle_ms > 3.0 and hud.modulate.a > 0.21:
        _fade_chrome(0.2)


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


## Centre the 640x360 map when the stretched viewport is larger —
## aspect=expand shows extra room on wide phones (~800px virtual at
## 20:9) and taller tablets; the empty margin paints with the dark
## clear colour, not the mid-grey default.
func _fit_stage() -> void:
    var vp := get_viewport_rect().size
    stage.position = Vector2(
        maxf(0.0, (vp.x - float(GW * T)) / 2.0),
        maxf(0.0, (vp.y - float(GH * T)) / 2.0))


# ------------------------------------------------------------- scenery

func _cell_mask(c: Vector2i) -> int:
    ## 0 grass 1 forest 2 water 3 stone — one terrain wins per cell,
    ## same priority order as the comp (forest < water < stone paint).
    if c in PATH:
        return 3
    if (c.x <= 3 and c.y >= 8) or (c.x == 4 and c.y >= 10):
        return 2
    if c.y <= 2 or (c.y == 3 and not FOREST_ROW3_GAPS.has(c.x)):
        return 1
    return 0


func _blob(mask_cells: Array, source_id: int, set_id: int) -> void:
    ## Paint a lower-terrain blob: pre-seed the mask + its one-cell ring
    ## with this set's all-upper tile so connect() can carve transitions
    ## into it, then terrain-connect the mask itself.
    var zone := {}
    for c in mask_cells:
        for dy in [-1, 0, 1]:
            for dx in [-1, 0, 1]:
                var n: Vector2i = c + Vector2i(dx, dy)
                if n.x >= 0 and n.x < GW and n.y >= 0 and n.y < GH:
                    zone[n] = true
    for n in zone:
        ground.set_cell(n, source_id, UUUU)
    ground.set_cells_terrain_connect(mask_cells, set_id, 0)


func _build_ground() -> void:
    ground = TileMapLayer.new()
    ground.name = "Ground"
    ground.tile_set = load("res://resources/pinewatch_terrain.tres")
    stage.add_child(ground)
    var forest_cells: Array[Vector2i] = []
    var pond_cells: Array[Vector2i] = []
    var path_cells: Array[Vector2i] = []
    for ty in GH:
        for tx in GW:
            var c := Vector2i(tx, ty)
            ground.set_cell(c, 0, UUUU)      # grass base = water-set UUUU
            match _cell_mask(c):
                1: forest_cells.append(c)
                2: pond_cells.append(c)
                3: path_cells.append(c)
    _blob(forest_cells, 1, 1)                # forest first (comp order)
    _blob(pond_cells, 0, 0)
    _blob(path_cells, 2, 2)
    # wear: solid forest-floor tile where feet/gear have killed the grass
    # (under each tent, the fire ring's front lip, the path junction)
    var worn := 0
    for c in WEAR_CELLS:
        if _cell_mask(c) == 0:
            ground.set_cell(c, 1, LLLL)
            worn += 1
    # variant pass: every cell still sitting on a pure fill tile (UUUU
    # or LLLL in any of the 3 wang sheets) is re-seated on a hash-picked
    # variant source — deterministic (tx*31+ty*17+src)%6 so the comp
    # mirrors it exactly.  Transition tiles vary by edge config already.
    var swapped := 0
    for ty in GH:
        for tx in GW:
            var c := Vector2i(tx, ty)
            var src := ground.get_cell_source_id(c)
            var at := ground.get_cell_atlas_coords(c)
            var fill := -1
            if at == UUUU:
                fill = 0
            elif at == LLLL:
                fill = 1
            if src < 0 or src > 2 or fill < 0:
                continue
            var vi: int = (tx * 31 + ty * 17 + src) % VAR_N
            ground.set_cell(c, VAR_SRC0 + src * 12 + fill * 6 + vi,
                            Vector2i(0, 0))
            swapped += 1
    print("ground: %d wear cells, %d fill-variant cells, tint map "
          % [worn, swapped] + "carries macro variation")


func _open_cell(px: float, py: float, want: int) -> bool:
    ## Scatter placement guard: the point must sit on terrain `want`
    ## (0 grass / 1 forest) and outside every pad rect — keeps decals
    ## off pond/path/pads exactly like the old _open_grass did.
    var tx := int(px) / T
    var ty := int(py) / T
    if tx < 0 or tx >= GW or ty < 0 or ty >= GH:
        return false
    if _cell_mask(Vector2i(tx, ty)) != want:
        return false
    for r in pad_cells.values():
        if r.has_point(Vector2(px, py)):
            return false
    return true


func _build_backdrop() -> void:
    ## Depth band over the top forest strip: pale sky fading into the
    ## dirt, then rows of darkened pines standing in front of it.  Added
    ## right after Ground so it paints above the (fully opaque) tiles —
    ## below them it could never be seen — and below everything else.
    var bd := Node2D.new()
    bd.name = "Backdrop"
    stage.add_child(bd)
    # sky -> dirt fill first; trees land on top of it
    var sky := Polygon2D.new()
    sky.polygon = PackedVector2Array([
        Vector2(0, 0), Vector2(GW * T, 0),
        Vector2(GW * T, SKY_H), Vector2(0, SKY_H)])
    sky.vertex_colors = PackedColorArray(
        [SKY_TOP, SKY_TOP, SKY_BOT, SKY_BOT])
    bd.add_child(sky)
    # shadowed treeline — rows shrink with distance so the pale sky
    # reads above the far canopy tops; near rows darker, all cool
    var rows: Array = [
        {"y": 78.0,  "dx": 118.0, "x0": -34.0, "tint": TREE_FAR,  "s": 0.62},
        {"y": 98.0,  "dx": 128.0, "x0": 22.0,  "tint": TREE_MID,  "s": 0.80},
        {"y": 118.0, "dx": 190.0, "x0": 170.0, "tint": TREE_NEAR, "s": 1.00},
    ]
    var k := 0
    for r in rows:
        var x: float = r["x0"]
        while x < GW * T + 40.0:
            var n := "pine_tall_a" if k % 2 else "pine_tall_b"
            if r["y"] == 98.0 and k % 4 == 3:
                n = "flamboyant_tree"               # silhouette variety
            var t := _anchored("props_large", n, Vector2(x, r["y"]))
            t.scale = Vector2(r["s"], r["s"])
            t.modulate = r["tint"]
            bd.add_child(t)
            x += r["dx"]
            k += 1


func _build_scatter(rng: RandomNumberGenerator) -> void:
    scatter = Node2D.new()
    scatter.name = "Scatter"
    stage.add_child(scatter)
    # edge-clustered decals (ground recipe): DECAL_CLUSTERS is a fixed
    # list — one family per cluster, only at prop bases / shoreline /
    # treeline feet; the open-field interior stays empty because the
    # GroundTint overlay carries macro variation now.  pad_cells is
    # filled from the layout here because _build_pads only runs after us.
    if pad_cells.is_empty():
        var spots: Dictionary = layout["pads"]["spots"]
        for pid in spots:
            var c: Array = spots[pid]
            pad_cells[pid] = Rect2(origin + Vector2(c[0], c[1]) * CELL,
                                   Vector2(CELL, CELL))
    var placed := 0
    for spec in DECAL_CLUSTERS:
        var ctr := Vector2(spec[0], spec[1])
        var fam: Array = DECAL_FAMILIES[spec[2]]
        var want: int = spec[6]
        for i in int(spec[3]):
            # triangular offset -> denser near the centre, soft edges
            var p: Vector2 = ctr + Vector2(
                (rng.randf() + rng.randf() - 1.0) * spec[4],
                (rng.randf() + rng.randf() - 1.0) * spec[5])
            if _open_cell(p.x, p.y, want):
                var d := _anchored("decals",
                                   fam[rng.randi() % fam.size()], p)
                d.modulate = DECAL_GROUND      # sit IN the ground wash
                scatter.add_child(d)
                placed += 1
    print("scatter decals: %d (%d edge clusters)"
          % [placed, DECAL_CLUSTERS.size()])


func _build_pads(rng: RandomNumberGenerator) -> void:
    var spots: Dictionary = layout["pads"]["spots"]
    var open_pads: Array = layout["pads"]["open"]
    for pid in spots:
        var c: Array = spots[pid]
        var rect := Rect2(origin + Vector2(c[0], c[1]) * CELL,
                          Vector2(CELL, CELL))
        pad_cells[pid] = rect
        var m := Sprite2D.new()
        m.texture = _tex("pad_open" if pid in open_pads else "pad_locked")
        m.centered = false
        m.name = "mark_" + pid
        m.position = rect.position
        pads_node.add_child(m)
        if not (pid in open_pads):
            var tuft := _anchored("decals", "XS_13",
                rect.position + Vector2(8 + rng.randi() % 40,
                                        8 + rng.randi() % 40))
            pads_node.add_child(tuft)


func _build_props() -> void:
    var erng := RandomNumberGenerator.new()
    erng.seed = 23                     # embed jitter — fixed so the
                                       # sticker-kill is reproducible
    for p in PROPS:
        var spr := _anchored(p[0], p[1], Vector2(p[2], p[3]))
        if p.size() > 4:               # organic lean on loose props
            spr.rotation_degrees = p[4]
        world.add_child(spr)
        _embed_base(p, erng)


## Phase 0.1 embed pass — kill the sticker look: 1-3 small decals
## (tufts on grass, litter on forest floor) anchored just BELOW the
## prop's base so the y-sort draws them in front of its bottom ~8-15%.
## The base edge gets visually broken by foreground vegetation and the
## prop reads as sitting IN the world, not pasted on it.
func _embed_base(p: Array, rng: RandomNumberGenerator) -> void:
    if p[1] in EMBED_SKIP:
        return
    var e: Dictionary = anchors.get(p[0] + "/" + p[1] + ".png", {})
    var tex: Texture2D = _tex(p[0] + "/" + p[1])
    var ax: float = e.get("anchor_x", tex.get_width() / 2.0)
    var ay: float = e.get("anchor_y", float(tex.get_height()))
    var c: Array = e.get("content",
        [0, 0, tex.get_width(), tex.get_height()])
    # prop footprint in world px (content box, not the whole canvas)
    var fx0: float = p[2] - ax + c[0]
    var fx1: float = p[2] - ax + c[2]
    var ch: float = c[3] - c[1]
    var overlap: float = clamp(ch * 0.11, 3.0, 7.0)
    for i in 1 + rng.randi() % 3:
        var pos := Vector2(
            lerpf(fx0, fx1, 0.2 + 0.6 * rng.randf()),
            p[3] + max(1.0, 8.0 - overlap + rng.randf() * 2.0 - 1.0))
        # pos must clear the prop's own anchor y (sorts in front) and
        # land on turf — gravel pebbles allowed on the path edge, never
        # on pond / pads
        var want := _cell_mask(Vector2i(int(pos.x) / T, int(pos.y) / T))
        if want == 2:
            continue
        var on_pad := false
        for r in pad_cells.values():
            if r.has_point(pos):
                on_pad = true
                break
        if on_pad:
            continue
        var fam_name := "tuft" if want == 0 else \
            "litter" if want == 1 else "pebble"
        var fam: Array = DECAL_FAMILIES[fam_name]
        world.add_child(_anchored("decals",
                                  fam[rng.randi() % fam.size()], pos))


func _build_actors() -> void:
    # fire loop — A1b cycle, frames 1..6 (frame 0 is the ignite lead-in)
    world.add_child(_anchored_frames("fx",
        ["fx/A1b_1", "fx/A1b_2", "fx/A1b_3", "fx/A1b_4", "fx/A1b_5",
         "fx/A1b_6"], 6.0, FIRE_POS))
    # warden idle-south (A2, 4f breathing) beside the fire
    world.add_child(_anchored_frames("chars",
        ["characters/warden/A2_idle_south_0",
         "characters/warden/A2_idle_south_1",
         "characters/warden/A2_idle_south_2",
         "characters/warden/A2_idle_south_3"], 4.0, WARDEN_POS))
    # camp dog idle (A3, 8f)
    world.add_child(_anchored_frames("chars",
        ["characters/camp_dog/A3_idle_south_0",
         "characters/camp_dog/A3_idle_south_1",
         "characters/camp_dog/A3_idle_south_2",
         "characters/camp_dog/A3_idle_south_3",
         "characters/camp_dog/A3_idle_south_4",
         "characters/camp_dog/A3_idle_south_5",
         "characters/camp_dog/A3_idle_south_6",
         "characters/camp_dog/A3_idle_south_7"], 5.0, DOG_POS))
    # ranger Mai keeps watch by the path bend
    world.add_child(_anchored("characters/ranger_mai",
                              "ranger_mai_south", MAI_POS))


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
    hud.settings_pressed.connect(
        func(): panel_mgr.open(SettingsSheet.make()))
    hud.journal_pressed.connect(
        func(): panel_mgr.open(JournalSheet.make()))

    panel_mgr = PanelManager.new()             # PANEL tier, dimmer stack
    panel_mgr.name = "Panels"
    add_child(panel_mgr)
    panel_mgr.stack_changed.connect(_on_panels_changed)
    Platform.back_pressed.connect(_on_back)
    # §8.3 journal badge: unread mail count; refreshed on delivery and
    # whenever the panel stack settles (reading happens inside the sheet)
    Game.letter_delivered.connect(_refresh_journal_badge.unbind(1))
    _refresh_journal_badge()

    # fire proximity bubble — a world marker so it rides the canvas
    # transform (stage margins included); shown only while the pointer
    # is near the fire ring (GDD 17.5: bubbles over interactive objects)
    var fire_anchor := Node2D.new()
    fire_anchor.position = FIRE_POS
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
    else:
        _confirm_quit()


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
    stay.pressed.connect(panel_mgr.close)
    var push := Control.new()
    push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    push.mouse_filter = Control.MOUSE_FILTER_IGNORE
    brow.add_child(push)
    var leave := UIKit.btn(brow, Vector2(74, UITokens.MIN_TOUCH),
        tr("quit_leave"))
    leave.pressed.connect(get_tree().quit)
    v.add_child(brow)
    return p


## Headless smoke (godot --headless --path game <scene> --smoke):
## exercises Back -> quit-confirm -> close and the fire-proximity
## bubble, prints assertions, quits.  Runs beside --shot, no prod cost.
func _smoke() -> void:
    await get_tree().process_frame
    _on_back()
    await _frames_until(func(): return panel_mgr.top() != null \
        and panel_mgr.top().modulate.a > 0.9)
    var top: Control = panel_mgr.top()
    print("SMOKE back -> quit panel open: ", top != null,
          " size:", top.size if top else Vector2.ZERO)
    _on_back()
    await _frames_until(func(): return _quit == null)
    print("SMOKE back -> closed: ", panel_mgr.top() == null,
          " quit cleared:", _quit == null)
    _fire_near(true)
    await _frames_until(func(): return fire_bubble.modulate.a > 0.9)
    print("SMOKE fire bubble a=", snappedf(fire_bubble.modulate.a, 0.01))
    _fire_near(false)
    await _frames_until(func(): return not fire_bubble.visible)
    print("SMOKE fire bubble hidden:", not fire_bubble.visible)
    # UI-020 tray: build -> select -> previews+strip -> seat -> unseat
    var st: Dictionary = Game.site_state()
    var board: Array = st["board"]
    print("SMOKE tray cards:", hud.tray._cards.size(), "of",
          board.size())
    var g0: String = board[0]["id"]
    _tap_card(g0)
    await get_tree().process_frame
    print("SMOKE select:", selected == g0,
          " previews:", star_labels.size() > 0,
          " strip:", hud.tray.strip.visible)
    var pid0 := ""
    for pid in pad_cells:
        if st["pads"][pid].get("open", false) \
                and not _pad_occupied(pid):
            pid0 = pid
            break
    _try_seat(pid0)
    await get_tree().process_frame
    print("SMOKE seat:", st["assignments"].has(g0),
          " card dimmed:", hud.tray.is_seated(g0),
          " bubble:", guest_bubbles.has(g0))
    _do_unseat(g0)
    print("SMOKE unseat:",
          not Game.site_state()["assignments"].has(g0),
          " card restored:", not hud.tray.is_seated(g0),
          " bubble freed:", not guest_bubbles.has(g0))
    _tap_card(g0)
    _tap_card(g0)
    print("SMOKE toggle-deselect:", selected == "")
    # UI-022: Goodnight -> summary sheet -> Sleep -> next morning
    var day_before := Game.day
    _advance_phase()
    await _frames_until(func(): return panel_mgr.top() != null)
    var sheet := panel_mgr.top()
    print("SMOKE night sheet:", sheet is NightSummary)
    if sheet is NightSummary:
        (sheet as NightSummary).sleep_pressed.emit()
        await get_tree().process_frame
        print("SMOKE sleep -> day:", Game.day == day_before + 1,
              " closed:", panel_mgr.top() == null,
              " morning:", Game.phase == Game.Phase.MORNING,
              " board marker:", _board_tok != 0)
        # UI-023: booking sheet opens -> close -> Head out -> evening
        _open_booking()
        await get_tree().process_frame
        print("SMOKE booking sheet:", panel_mgr.top() is BookingBoard)
        panel_mgr.close()
        _advance_phase()
        await get_tree().process_frame
        print("SMOKE head out -> evening:",
              Game.phase == Game.Phase.EVENING,
              " tray:", hud.tray.visible,
              " marker cleared:", _board_tok == 0)
    # UI-036: gear opens the §17.4 sheet; a toggle applies + persists
    hud.settings_pressed.emit()
    await _frames_until(func(): return panel_mgr.top() != null)
    var ss := panel_mgr.top()
    print("SMOKE settings sheet:", ss is SettingsSheet)
    if ss is SettingsSheet:
        var rm0: bool = UIFeel.reduced_motion
        Game.setting("reduced_motion", not rm0)
        print("SMOKE reduced_motion applied:",
              UIFeel.reduced_motion == (not rm0),
              " persisted:", bool(Game.settings["reduced_motion"])
              == (not rm0))
        Game.setting("reduced_motion", rm0)      # restore for later steps
        panel_mgr.close()
    # UI-030: journal button opens the §8.3 sheet; tabs switch; the
    # badge mirrors unread mail; days log gains a line per goodnight
    var badge0 := Game.unread_letters().size()
    print("SMOKE journal badge:", hud.journal_badge.text == (
        str(badge0) if badge0 > 0 else ""))
    hud.journal_pressed.emit()
    await _frames_until(func(): return panel_mgr.top() != null)
    var js := panel_mgr.top()
    print("SMOKE journal sheet:", js is JournalSheet)
    if js is JournalSheet:
        var comp := Game.journal_completion()
        print("SMOKE journal completion:",
              comp["done"] >= 0 and comp["total"] > 0)
        for tab in ["chapters", "letters", "days", "then_now"]:
            js._select_tab(tab)
            await get_tree().process_frame
        print("SMOKE journal tabs:",
              js._content.get_child_count() > 0)
        # read every staged unread letter — mornings deliver one each,
        # so the run can carry more than one
        var unread := Game.unread_letters()
        for l in unread:
            Game.read_letter(l["id"])
        if not unread.is_empty():
            print("SMOKE letter read:",
                  unread.all(func(l): return l["id"] in Game.letters_read))
        panel_mgr.close()
        await get_tree().process_frame
        print("SMOKE badge cleared:",
              hud.journal_badge.text == "")
    get_tree().quit()


## Poll a condition each frame (cap ~4s) — tween timing varies headless.
func _frames_until(cond: Callable, cap := 240) -> void:
    for i in cap:
        if cond.call():
            return
        await get_tree().process_frame


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
    _press = {}
    if _drag_ghost != null:
        _drag_ghost.queue_free()
        _drag_ghost = null
    _clear_bubbles()
    hud.tray.visible = true
    hud.tray.build(st["board"], _trait_map(), _card_sprite)
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
    var s := _anchored("characters/warden", "warden_south", Vector2.ZERO)
    s.modulate = _tint(st["guests"][gid])
    g.add_child(s)
    g.position = pad_cells[pads[0]].position + Vector2(12, CELL + 4)
    world.add_child(g)
    guest_nodes[gid] = g
    tent_nodes[gid] = []
    var idx := absi(hash(gid + arch) as int)
    for pid in pads:
        var t := _anchored("props_medium",
                           TENTS[idx % TENTS.size()], Vector2.ZERO)
        idx += 1
        var r: Rect2 = pad_cells[pid]
        t.position = r.position + Vector2(CELL / 2.0, CELL)
        world.add_child(t)
        tent_nodes[gid].append(t)
    hud.tray.mark_seated(gid)
    _refresh_bubbles()
    _sync_marks()


func _unseat_visual(gid: String) -> void:
    if guest_nodes.has(gid):
        guest_nodes[gid].queue_free()
        guest_nodes.erase(gid)
    for t in tent_nodes.get(gid, []):
        t.queue_free()
    tent_nodes[gid] = []
    if guest_bubbles.has(gid):
        markers.release(guest_bubbles[gid])
        guest_bubbles.erase(gid)
    hud.tray.mark_unseated(gid)
    _refresh_bubbles()
    _sync_marks()


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


## Selection is the tap-tap path (UI-020): card tap -> previews +
## neutral strip; tap again to put the guest back.
func _select(gid: String) -> void:
    selected = gid
    hud.tray.set_selected(gid)
    hud.tray.show_guest_terms(Game.site_state()["guests"][gid],
        tr("tray_pick_pad"))
    _show_previews(gid)


func _deselect() -> void:
    selected = ""
    hud.tray.set_selected("")
    hud.tray.hide_strip()
    _clear_previews()


func _tap_card(gid: String) -> void:
    if Game.site_state()["assignments"].has(gid):
        _do_unseat(gid)
    elif gid == selected:
        _deselect()
    else:
        _select(gid)


func _try_seat(pid: String) -> void:
    var st: Dictionary = Game.site_state()
    var pick := _pads_for(selected, pid)
    if pick.size() == int(st["guests"][selected].get("pads", 1)) \
            and Game.seat(selected, pick):
        UIFeel.haptic("confirm")
        _seat_visual(selected, pick)
        _deselect()
    else:
        # tapped a pad but couldn't seat — wrong count or camp full
        UIFeel.haptic("warn")


func _do_unseat(gid: String) -> void:
    Game.unseat(gid)
    _unseat_visual(gid)
    _deselect()


## Card press -> drag (UI-020): the guest sprite rides the pointer
## until release; release over a pad seats exactly like a tap-tap.
func _begin_drag(gid: String) -> void:
    _select(gid)
    _drag_ghost = _anchored("characters/warden", "warden_south",
        Vector2.ZERO)
    _drag_ghost.modulate = _tint(Game.site_state()["guests"][gid])
    _drag_ghost.modulate.a = 0.8
    marks.add_child(_drag_ghost)


func _end_drag(px: Vector2) -> void:
    if _drag_ghost == null:
        return
    _drag_ghost.queue_free()
    _drag_ghost = null
    var pid := _pad_at(px)
    if pid != "" and selected != "":
        _try_seat(pid)


## Live strip: while a guest is selected, hovering an open pad shows
## the full score breakdown; anywhere else it falls back to the
## guest's neutral trait list.
func _update_strip(px: Vector2) -> void:
    var gid := selected
    if gid == "":
        return
    var st: Dictionary = Game.site_state()
    var pid := _pad_at(px)
    if pid != "" and st["pads"].get(pid, {}).get("open", false) \
            and not _pad_occupied(pid):
        var pick := _pads_for(gid, pid)
        if pick.size() == int(st["guests"][gid].get("pads", 1)):
            hud.tray.show_preview(Game.preview(gid, pick))
            return
    hud.tray.show_guest_terms(st["guests"][gid], tr("tray_pick_pad"))


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
    var st: Dictionary = Game.site_state()
    if int(st["guests"].get(gid, {}).get("pads", 1)) != 2:
        return [pid]
    for nb in layout["pads"]["neighbours"].get(pid, []):
        if st["pads"].get(nb, {}).get("open", false) \
                and not _pad_occupied(nb):
            return [pid, nb]
    return []


func _show_previews(gid: String) -> void:
    _clear_previews()
    var st: Dictionary = Game.site_state()
    for pid in pad_cells:
        if not st["pads"].get(pid, {}).get("open", false) \
                or _pad_occupied(pid):
            continue
        var pick := _pads_for(gid, pid)
        if pick.is_empty():
            continue
        var r := Game.preview(gid, pick)
        if r.is_empty():
            continue
        # star icon + number, comp-style
        var m := Node2D.new()
        m.position = pad_cells[pid].position + Vector2(18, 2)
        var t := UIKit.icon_rect("star_full")
        m.add_child(t)
        var l := UIKit.label_for("%d" % r["stars"],
            UITokens.TypeRole.HEAD)
        l.position = Vector2(17, 2)
        m.add_child(l)
        star_labels[pid] = m
        marks.add_child(m)


func _clear_previews() -> void:
    for l in star_labels.values():
        l.queue_free()
    star_labels = {}


func _pad_occupied(pid: String) -> bool:
    var st: Dictionary = Game.site_state()
    for pad_ids in st["assignments"].values():
        if pid in pad_ids:
            return true
    return false


func _status() -> void:
    var st: Dictionary = Game.site_state()
    hud.set_status(("day %d · site day %d · %s · %dc   [%s]") % [
        Game.day, Game.site_day(), st["weather"].to_upper(), Game.coins,
        tr("tray_hint")])
    # the button is the phase action, not the phase name (§4 table:
    # Evening -> Goodnight, Night -> Sleep, Morning -> Head out)
    hud.set_phase(tr("hud_goodnight").to_upper() if evening_open \
        else (tr("hud_headout").to_upper() \
            if Game.phase == Game.Phase.MORNING \
            else tr("hud_sleep").to_upper()))
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
    evening_open = false
    _deselect()
    _clear_bubbles()
    hud.tray.reset()
    hud.tray.visible = false
    _status()
    # UI-022: the payoff sheet — reviews with breakdowns, totals,
    # pages, forecast, Double-tips offer, Sleep
    var sheet := NightSummary.make(rep, names, Game.day,
        Game.forecast())
    sheet.sleep_pressed.connect(_on_sleep)
    panel_mgr.open(sheet)
    sheet.run_count_up.call_deferred()


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
        UIFeel.haptic("confirm")               # Head out
        _start_evening()
    else:                                      # Night -> next Morning
        hud.set_report("")
        Game.advance_day()                     # set_phase(MORNING) inside
        _start_morning()


## UI-023 Morning: camp is quiet — the notice board is the interactive
## object.  A "!" marker floats over the signpost until Head out.
func _start_morning() -> void:
    evening_open = false
    # "!" chip over the notice board — flat glass chip; gold glyph
    var bub := Panel.new()
    bub.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bub.add_theme_stylebox_override("panel",
        UIKit.flat("glass_chip"))
    bub.size = Vector2(22, 22)
    var bang := UIKit.label_for("!", UITokens.TypeRole.DISPLAY,
        UITokens.GOLD)
    bang.position = Vector2(8, -1)
    bub.add_child(bang)
    # offset places the chip just over the signpost's visible head —
    # the prop is mostly occluded by the chest + warden tent
    _board_tok = markers.marker(board_anchor, Vector2(-11, -42))
    markers.marker_control(_board_tok).add_child(bub)
    # gentle bob so the marker reads alive, not painted on the prop
    bub.pivot_offset = bub.size / 2.0
    # bound to the chip so the loop dies when the marker releases —
    # a scene-bound loop would keep stepping a freed target
    var bob := UIFeel.apply(bub.create_tween().set_loops(), "marker")
    var bd := UIFeel.dur("marker")
    bob.tween_property(bub, "scale", Vector2(1.12, 1.12), bd)
    bob.tween_property(bub, "scale", Vector2.ONE, bd)
    _status()


func _start_evening() -> void:
    if _board_tok:
        markers.release(_board_tok)
        _board_tok = 0
    Game.set_phase(Game.Phase.EVENING)
    _spawn_board()
    _status()


## The notice board sheet (§17.2): tonight's requests + the forecast.
func _open_booking() -> void:
    var st: Dictionary = Game.site_state()
    var open_n := 0
    for pid in st["pads"]:
        if st["pads"][pid].get("open", false):
            open_n += 1
    panel_mgr.open(BookingBoard.make(st["board"],
        String(st["weather"]), open_n, _card_sprite, _trait_map()))


# ------------------------------------------------------------- input

func _pad_at(px: Vector2) -> String:
    for pid in pad_cells:
        if pad_cells[pid].has_point(px):
            return pid
    return ""


func _guest_at(px: Vector2) -> String:
    for gid in guest_nodes:
        var g: Node2D = guest_nodes[gid]
        # 64px sprite sits above the feet anchor; the label hangs below
        if Rect2(g.global_position - Vector2(40, 64),
                Vector2(80, 100)).has_point(px):
            return gid
    return ""


func _unhandled_input(event: InputEvent) -> void:
    var st: Dictionary = Game.site_state()
    if event is InputEventMouseMotion:
        _wake_chrome()
        var sp: Vector2 = event.position              # viewport px (cards)
        var px := get_global_mouse_position() - stage.position
        _fire_near(px.distance_to(FIRE_POS) <= 56.0)
        if not evening_open:
            return                                    # night: watch the fire
        # a card press that travels >7px becomes a drag (UI-020)
        if not _press.is_empty() and _drag_ghost == null \
                and not hud.tray.is_seated(_press["gid"]) \
                and sp.distance_to(_press["pos"]) > 7.0:
            _begin_drag(_press["gid"])
            _press = {}
        var pid := _pad_at(px)
        var ok: bool = pid != "" \
            and st["pads"].get(pid, {}).get("open", false) == true \
            and not _pad_occupied(pid) and selected != ""
        hover.visible = ok
        if ok:
            hover.position = pad_cells[pid].position
        if _drag_ghost != null:
            _drag_ghost.position = px + Vector2(0, 4)
        _update_strip(px)
        return
    if event is InputEventMouseButton and event.pressed \
            and Game.phase == Game.Phase.MORNING:
        # morning: the notice board is the one interactive object
        var mpx0 := get_global_mouse_position()
        if BOARD_RECT.has_point(mpx0 - stage.position):
            _open_booking()
        return
    if not evening_open and event is InputEventMouseButton:
        return                                        # night: watch the fire
    if event is InputEventMouseButton \
            and event.button_index == MOUSE_BUTTON_LEFT:
        var sp: Vector2 = event.position              # viewport px (cards)
        var mpx := get_global_mouse_position()
        var px := mpx - stage.position
        _fire_near(px.distance_to(FIRE_POS) <= 56.0)
        if event.pressed:
            # card presses defer to release — they may become drags
            var card_gid := hud.tray.card_at(sp)
            if card_gid != "":
                _press = {"gid": card_gid, "pos": sp}
                return
            var gid := _guest_at(mpx)
            if gid != "" and st["assignments"].has(gid):
                _do_unseat(gid)                       # tap seated guest = undo
                return
            var pid := _pad_at(px)
            if pid != "" and selected != "":
                _try_seat(pid)
        else:
            if _drag_ghost != null:
                _end_drag(px)
            elif not _press.is_empty():
                var p: Dictionary = _press
                _press = {}
                if hud.tray.card_at(sp) == p["gid"]:
                    _tap_card(p["gid"])
    elif event is InputEventKey and event.pressed:
        if event.keycode == KEY_ENTER:
            _advance_phase()
        elif event.keycode == KEY_F1:
            hud.toggle_dev()
