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
const STAR_ICON := "I1_4"                    # the gold icon the comp uses
                                             # for the rating star

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
    ["props_large",  "pine_tall_a",        74,  96],
    ["props_large",  "pine_tall_b",       156, 102],
    ["props_large",  "flamboyant_tree",   262,  94],
    ["props_large",  "pine_tall_a",       540,  92],
    ["props_large",  "bamboo_clump",      606,  96],
    ["props_large",  "cabin",             428, 128],
    ["props_large",  "pennant_string",    345, 168],
    # ---------------- outfitter camp (NW): van, stools, crates, signpost
    ["props_large",  "outfitter_van",     110, 178],
    ["props_medium", "prop_supply_crate_0", 206, 188],
    ["props_small",  "non_la_hat",        209, 196],
    ["props_medium", "stool_pair",        172, 200],
    ["props_medium", "moped_cub",          78, 208],
    ["props_small",  "signpost",          222, 208, 2.5],
    ["props_small",  "stool_plastic_blue",148, 214],
    ["props_small",  "stool_plastic_red", 186, 214],
    # ------- camp kitchen (centre): fire, tripod, bench, stump, lantern
    ["props_medium", "lantern_post",      356, 218, -3.0],
    ["props_medium", "tent_green",        212, 232],
    ["props_medium", "tripod_cauldron",   302, 238],
    ["props_medium", "dirt_patch",        326, 250],
    ["props_medium", "radio_stump",       370, 258],
    ["props_medium", "log_bench",         256, 262],
    # ---------- rest corner (E): hammock by the pine, picnic set below
    ["props_large",  "hammock",           566, 150],
    ["props_large",  "picnic_table",      516, 250],
    ["props_medium", "picnic_basket",     498, 266],
    ["props_medium", "tea_table",         472, 276],
    ["props_medium", "tent_red",          192, 300, -2.5],
    # spare unlit fire pit near the rest corner (storytelling; the A1b
    # flame loop stays on the shipped ring at the kitchen fire)
    ["props_medium", "fire_ring_unlit_v2", 565, 294],
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
]
# props that get NO foreground embed decal (it IS the ground)
const EMBED_SKIP := ["dirt_patch"]

const FIRE_POS := Vector2(326, 246)          # A1b fire-loop anchor
const WARDEN_POS := Vector2(348, 262)
const DOG_POS := Vector2(300, 306)
const MAI_POS := Vector2(468, 254)

# scatter decal groups by visual family — a cluster commits to ONE so it
# reads as a patch of something (tuft / flowers / dry grass / pebbles /
# mushrooms), not confetti
const DECAL_FAMILIES := {
    "tuft":   ["XS_0", "XS_1", "XS_4", "XS_24", "XS_36", "XS_52"],
    "flower": ["XS_10", "XS_11", "XS_22", "XS_56"],
    "dry":    ["XS_2", "XS_6", "XS_8"],
    "pebble": ["XS_29", "XS_41", "XS_51"],
    "shroom": ["XS_13", "XS_16", "XS_43", "XS_44", "XS_61"],
    # leaf litter for the (intentionally near-flat) B5 forest floor:
    # needle scatter + pile, pine twig, fallen yellow/red leaves, pinecone
    "litter": ["XS_19", "XS_20", "XS_21", "XS_22", "XS_23", "XS_17"],
}
const TENTS := ["tent_green", "tent_red"]

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
    [212.0, 247.0, "tuft",   2, 16.0, 8.0, 0],   # tent_green base
    [192.0, 316.0, "dry",    2, 16.0, 8.0, 0],   # tent_red base
    [256.0, 272.0, "pebble", 2, 12.0, 6.0, 0],   # log_bench feet
    [540.0, 174.0, "tuft",   1, 10.0, 6.0, 0],   # chicken_coop base
    [118.0, 192.0, "pebble", 1, 10.0, 6.0, 0],   # van wheel line
    [140.0, 300.0, "pebble", 2, 14.0, 24.0, 0],  # pond shoreline
    [238.0, 121.0, "litter", 2, 16.0, 5.0, 1],   # treeline floor W
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
var scatter: Node2D
var pads_node: Node2D
var world: Node2D
var tray: Node2D
var marks: Node2D                            # hover + star previews above world
var hover: Sprite2D
var hud: HUD                                 # chrome root (fades when idle)
var panel_mgr: PanelManager                  # modal panel stack (PANEL tier)
var markers: WorldMarkers                    # floating world markers layer
var hud_tween: Tween
var idle_ms := 0.0

var selected := ""                           # guest id being placed
var guest_nodes := {}                        # gid -> Node2D
var tent_nodes := {}                         # gid -> [Sprite2D]
var star_labels := {}                        # pid -> preview Node2D
var evening_open := true                     # Enter -> Goodnight
var night_rating := ""

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
    add_child(tint)
    pads_node = Node2D.new()
    pads_node.name = "Pads"
    add_child(pads_node)
    _build_pads(rng)
    world = Node2D.new()
    world.name = "World"
    world.y_sort_enabled = true
    add_child(world)
    _build_props()
    _build_actors()
    tray = Node2D.new()
    tray.name = "Tray"
    add_child(tray)
    marks = Node2D.new()
    marks.name = "Marks"
    add_child(marks)
    hover = Sprite2D.new()
    hover.texture = _tex("pad_hover")
    hover.centered = false
    hover.visible = false
    marks.add_child(hover)
    _build_ui()
    Game.advance_day()
    _spawn_board()
    _status()
    # capture engine render for pipeline review (test scene only)
    if OS.get_cmdline_args().has("--shot"):
        await get_tree().process_frame
        await get_tree().process_frame
        var img := get_viewport().get_texture().get_image()
        var out := "D:/monet/trail-bound/assets_src/cleanup/pinewatch_engine_graded.png"
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
    hud_tween = create_tween()
    hud_tween.tween_property(hud, "modulate:a", a, 0.4)


func _wake_chrome() -> void:
    idle_ms = 0.0
    if hud == null:                            # HUD not built yet
        return
    if hud.modulate.a < 0.99:
        _fade_chrome(1.0)


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_MOUSE_ENTER:
        _wake_chrome()


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
    add_child(ground)
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
    add_child(bd)
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
    add_child(scatter)
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

    var hud_layer := CanvasLayer.new()
    hud_layer.name = "HUD"
    hud_layer.layer = UITokens.Tier.HUD
    add_child(hud_layer)
    hud = HUD.new()                            # the chrome root itself —
    hud.name = "Chrome"                        # _fade_chrome modulates it
    hud.fire_pos = FIRE_POS
    hud_layer.add_child(hud)
    hud.phase_pressed.connect(_advance_phase)

    panel_mgr = PanelManager.new()             # PANEL tier, dimmer stack
    panel_mgr.name = "Panels"
    add_child(panel_mgr)


# ------------------------------------------------------------- guests

func _trait_names(ids: Array) -> String:
    var out := []
    for t in ids:
        for row in Catalog.data.get("traits", []):
            if row.get("id") == t:
                out.append(row.get("name", t))
    return " · ".join(out)


func _tray_pos(i: int) -> Vector2:
    return Vector2(400 + i * 66, 292)


func _spawn_board() -> void:
    for n in guest_nodes.values():
        n.queue_free()
    for ts in tent_nodes.values():
        for t in ts:
            t.queue_free()
    guest_nodes = {}
    tent_nodes = {}
    var st: Dictionary = Game.site_state()
    var i := 0
    for req in st["board"]:
        var g := Node2D.new()
        g.name = req["id"]
        var s := _anchored("characters/warden", "warden_south", Vector2.ZERO)
        s.modulate = Color("ffcf7d") if req.get("elite") \
            else Color("b8d7a8") if req.get("loud") else Color("ffffff")
        g.add_child(s)
        var l := UIKit.label("%s %dc\n%s" % [req.get("name", "?"),
            req.get("fee", 0), _trait_names(req.get("traits", []))])
        l.position = Vector2(-18, 4)
        g.add_child(l)
        g.position = _tray_pos(i)
        tray.add_child(g)
        guest_nodes[req["id"]] = g
        i += 1
    evening_open = true
    hud.set_report("")
    _sync_marks()


func _seat_visual(gid: String, pads: Array) -> void:
    var st: Dictionary = Game.site_state()
    var arch: String = st["guests"][gid].get("archetype", "")
    var g: Node2D = guest_nodes[gid]
    g.get_parent().remove_child(g)
    world.add_child(g)                             # join the y-sort
    # feet just under the pad's bottom edge — sorts in front of the tent
    g.position = pad_cells[pads[0]].position + Vector2(12, CELL + 4)
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
    _sync_marks()


func _unseat_visual(gid: String) -> void:
    var g: Node2D = guest_nodes[gid]
    for t in tent_nodes.get(gid, []):
        t.queue_free()
    tent_nodes[gid] = []
    g.get_parent().remove_child(g)
    tray.add_child(g)
    g.position = _tray_pos(guest_nodes.keys().find(gid))
    _sync_marks()


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
        # no star glyph in either font — gold icon + number, comp-style
        var m := Node2D.new()
        m.position = pad_cells[pid].position + Vector2(18, 2)
        var t := TextureRect.new()
        t.texture = _tex("icons/" + STAR_ICON)
        t.stretch_mode = TextureRect.STRETCH_KEEP
        t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        m.add_child(t)
        var l := UIKit.label("%d" % r["stars"], 9)
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
    hud.set_status(("day %d · site day %d · %s · %dc   " \
        + "[click guest, then pad · Enter = Goodnight]") % [
        Game.day, Game.site_day(), st["weather"].to_upper(), Game.coins])
    hud.set_phase("EVENING" if evening_open else "NIGHT")
    hud.set_rating(night_rating if night_rating else "—")


func _goodnight() -> void:
    var names := {}
    for gid in Game.site_state()["guests"]:
        names[gid] = Game.site_state()["guests"][gid].get("name", gid)
    var rep := Game.goodnight()
    var parts := []
    for r in rep["results"]:
        parts.append("%s *%d +%dc  “%s”" % [names.get(r["id"], r["id"]),
            r["stars"], r["fee"] + int(r["tip"]), r["comment"]])
    if rep["walk_ins"] > 0:
        parts.append("%d walk-in(s) +%dc" % [rep["walk_ins"],
            rep["meal_sales"]])
    hud.set_report("night: " + "   ".join(parts) \
        + "   >>  rating %.1f   income %dc" % [rep["rating"],
            rep["income"]])
    night_rating = "%.1f" % rep["rating"]
    evening_open = false
    _clear_previews()
    _status()


func _advance_phase() -> void:
    if evening_open:
        _goodnight()
    else:
        hud.set_report("")
        Game.advance_day()
        _spawn_board()
        _status()


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
        if not evening_open:
            return                                    # night: watch the fire
        var pid := _pad_at(get_global_mouse_position())
        var ok: bool = pid != "" \
            and st["pads"].get(pid, {}).get("open", false) == true \
            and not _pad_occupied(pid) and selected != ""
        hover.visible = ok
        if ok:
            hover.position = pad_cells[pid].position
        return
    if not evening_open and event is InputEventMouseButton:
        return                                        # night: watch the fire
    if event is InputEventMouseButton and event.pressed \
            and event.button_index == MOUSE_BUTTON_LEFT:
        var px := get_global_mouse_position()
        var gid := _guest_at(px)
        var pid := _pad_at(px)
        if gid != "" and gid in st["guests"]:
            if st["assignments"].has(gid):            # pull back to tray
                Game.unseat(gid)
                _unseat_visual(gid)
                selected = ""
                _clear_previews()
            else:                                     # pick for seating
                selected = gid
                _show_previews(gid)
            return
        if pid != "" and selected != "":
            var pick := _pads_for(selected, pid)
            if pick.size() == int(st["guests"][selected].get("pads", 1)) \
                    and Game.seat(selected, pick):
                _seat_visual(selected, pick)
                selected = ""
                _clear_previews()
    elif event is InputEventKey and event.pressed:
        if event.keycode == KEY_ENTER:
            _advance_phase()
        elif event.keycode == KEY_F1:
            hud.toggle_dev()
