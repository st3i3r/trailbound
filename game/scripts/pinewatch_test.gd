extends Node2D
## Pinewatch art + pad-grid test — composes palette-locked sprites:
## 32px tile ground, seeded scatter, y-sort world props, pad markers
## driven by game/data/layouts/pinewatch.json, tents snapped to the
## open pads, hover highlight on open pad cells.
## Run: godot --path game res://scenes/pinewatch_test.tscn

const A := "res://assets/pinewatch/"
const T := 32
const CELL := 64

var pond := Rect2(0, 8, 4, 4)                      # tiles
var path := [Vector2i(8,11), Vector2i(8,10), Vector2i(9,10), Vector2i(9,9),
             Vector2i(9,8), Vector2i(10,8), Vector2i(10,7), Vector2i(10,6),
             Vector2i(9,6), Vector2i(9,5)]
var decals := ["decal_tuft_a_0", "decal_tuft_b_0", "decal_fern_0",
               "decal_flower_0", "decal_pebbles_0", "decal_mushroom_v2_0"]
var props := [
    ["tree_pine_green_2", 30, 70], ["tree_pine_green_0", 95, 78],
    ["tree_ref_2", 170, 72], ["tree_pine_green_2", 240, 70],
    ["tree_pine_green_0", 320, 78], ["tree_ref_3", 400, 70],
    ["tree_pine_green_2", 470, 72], ["tree_pine_green_0", 545, 78],
    ["tree_pine_green_2", 610, 70],
    ["prop_van_p_0", 585, 108], ["prop_supply_crate_0", 545, 118],
    ["prop_signpost_0", 305, 330],
    ["prop_boulder_0", 415, 235], ["prop_lantern_post_0", 255, 190],
    ["prop_log_bench_0", 300, 250], ["campfire_0", 350, 230],
    ["prop_stump_0", 390, 255], ["player_front_0", 345, 265],
    ["prop_stump_0", 290, 285],
]
var occupants := {"p1": "prop_tent_olive_0", "p2": "prop_tent_rust_0"}

var layout: Dictionary
var origin: Vector2
var pad_cells := {}                                # pid -> Rect2 (px)
var hover: Sprite2D

func _tex(n: String) -> Texture2D:
    return load(A + n + ".png")

func _sprite(n: String) -> Sprite2D:
    var s := Sprite2D.new()
    s.texture = _tex(n)
    s.centered = false
    return s

func _ready() -> void:
    layout = Catalog.data["layouts"]["pinewatch"]
    var opx: Array = layout["camp_core_origin_px"]
    origin = Vector2(opx[0], opx[1])
    var rng := RandomNumberGenerator.new()
    rng.seed = 7

    var ground := Node2D.new()
    ground.name = "Ground"
    add_child(ground)
    for ty in 12:
        for tx in 20:
            var n := "terrain_grass_p1_0"
            var pos := Vector2i(tx, ty)
            if pond.has_point(Vector2(tx, ty)):
                n = "terrain_pond_water_0"
            elif pos in path:
                n = "terrain_dirt_v2_0"
            elif ty < 3:
                n = "terrain_forest_floor_0"
            else:
                var v := rng.randf()
                n = ("terrain_grass_lush_v2_0" if v < 0.08
                     else "terrain_grass_worn_v2_0" if v < 0.15
                     else "terrain_grass_p1_0")
            var s := _sprite(n)
            s.position = Vector2(tx * T, ty * T)
            ground.add_child(s)

    var scatter := Node2D.new()
    scatter.name = "Scatter"
    add_child(scatter)
    for ty in range(3, 11):
        for tx in 20:
            if pond.has_point(Vector2(tx, ty)) or Vector2i(tx, ty) in path:
                continue
            if rng.randf() > 0.10:
                continue
            var d := _sprite(decals[rng.randi() % decals.size()])
            d.position = Vector2(tx * T + rng.randi() % 8,
                                 ty * T + rng.randi() % 8)
            scatter.add_child(d)

    var pads_node := Node2D.new()
    pads_node.name = "Pads"
    add_child(pads_node)
    var spots: Dictionary = layout["pads"]["spots"]
    var open_pads: Array = layout["pads"]["open"]
    for pid in spots:
        var c: Array = spots[pid]
        var rect := Rect2(origin + Vector2(c[0], c[1]) * CELL,
                          Vector2(CELL, CELL))
        pad_cells[pid] = rect
        if occupants.has(pid):
            continue                                   # tent sprite is the state
        if pid in open_pads:
            var m := _sprite("pad_open")
            m.position = rect.position
            pads_node.add_child(m)
        else:
            for gy in 2:
                for gx in 2:
                    var o := _sprite("terrain_grass_lush_v2_0")
                    o.position = rect.position + Vector2(gx * T, gy * T)
                    pads_node.add_child(o)
            var m2 := _sprite("pad_locked")
            m2.position = rect.position
            pads_node.add_child(m2)
            var tuft := _sprite("decal_fern_0")
            tuft.position = rect.position + Vector2(
                8 + rng.randi() % 40, 8 + rng.randi() % 40)
            pads_node.add_child(tuft)

    hover = _sprite("pad_hover")
    hover.visible = false
    pads_node.add_child(hover)

    var world := Node2D.new()
    world.name = "World"
    world.y_sort_enabled = true
    add_child(world)
    for p in props:
        var s: Sprite2D = _sprite(p[0])
        var size: Vector2 = s.texture.get_size()
        s.position = Vector2(p[1] - size.x / 2.0, p[2] - size.y)
        world.add_child(s)
    for pid in occupants:
        var s: Sprite2D = _sprite(occupants[pid])
        var r: Rect2 = pad_cells[pid]
        s.position = r.position + Vector2(CELL / 2.0 - s.texture.get_size().x / 2.0,
                                          CELL - s.texture.get_size().y)
        world.add_child(s)

    # flame layer over the ring
    var frames := SpriteFrames.new()
    frames.add_animation("flicker")
    frames.set_animation_speed("flicker", 6.0)
    for f in ["flame_00", "flame_01", "flame_02", "flame_03"]:
        frames.add_frame("flicker", _tex(f))
    var flame := AnimatedSprite2D.new()
    flame.sprite_frames = frames
    flame.centered = false
    var fs: Vector2 = _tex("flame_00").get_size()
    flame.position = Vector2(350 - fs.x / 2.0, 214 - fs.y)
    world.add_child(flame)
    flame.play("flicker")

    # capture engine render for pipeline review (test scene only)
    if OS.get_cmdline_args().has("--shot"):
        await get_tree().process_frame
        await get_tree().process_frame
        var img := get_viewport().get_texture().get_image()
        var out := "D:/monet/trail-bound/assets_src/cleanup/pinewatch_engine.png"
        print("scene shot ->", out, " err:", img.save_png(out))
        get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        var pid := _pad_at(get_global_mouse_position())
        hover.visible = pid != "" and pid in layout["pads"]["open"] \
            and not occupants.has(pid)
        if hover.visible:
            hover.position = pad_cells[pid].position

func _pad_at(px: Vector2) -> String:
    for pid in pad_cells:
        if pad_cells[pid].has_point(px):
            return pid
    return ""
