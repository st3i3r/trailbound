extends Node2D
## Pinewatch art test — composes the palette-locked sprites exactly like
## tools/scene_comp.py does: 32px tile grid, sprites anchored
## bottom-center under a YSort, seeded scatter decals, flame layer.
## Run: godot --path game res://scenes/pinewatch_test.tscn

const A := "res://assets/pinewatch/"
const T := 32

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
    ["prop_tent_olive_0", 165, 205], ["prop_tent_rust_0", 500, 195],
    ["prop_boulder_0", 415, 235], ["prop_lantern_post_0", 255, 190],
    ["prop_log_bench_0", 300, 250], ["campfire_0", 350, 230],
    ["prop_stump_0", 390, 255], ["player_front_0", 345, 265],
    ["prop_stump_0", 290, 285],
]

func _tex(n: String) -> Texture2D:
    return load(A + n + ".png")

func _sprite(n: String) -> Sprite2D:
    var s := Sprite2D.new()
    s.texture = _tex(n)
    s.centered = false
    return s

func _ready() -> void:
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

    var world := Node2D.new()
    world.name = "World"
    world.y_sort_enabled = true
    add_child(world)
    for p in props:
        var s: Sprite2D = _sprite(p[0])
        var size: Vector2 = s.texture.get_size()
        s.position = Vector2(p[1] - size.x / 2.0, p[2] - size.y)
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
