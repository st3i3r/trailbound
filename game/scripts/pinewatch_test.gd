extends Node2D
## Pinewatch live test — art composition + the real hosting loop:
## Game.new_day() boards actual guests, click a traveller then an open
## pad to seat (★ preview on every pad), click a seated guest to pull
## them back, Enter says Goodnight and shows the night report, Enter
## again rolls the next morning. Run: run_pinewatch.cmd or
##   godot --path game res://scenes/pinewatch_test.tscn

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
    ["tree_pine_green_2", 470, 72], ["tree_pine_green_1", 545, 78],
    ["tree_pine_green_2", 610, 70],
    ["prop_van_p_0", 585, 108], ["prop_supply_crate_0", 545, 118],
    ["prop_signpost_0", 305, 330],
    ["prop_boulder_0", 415, 235], ["prop_lantern_post_0", 255, 190],
    ["prop_log_bench_0", 300, 250], ["campfire_0", 350, 230],
    ["prop_stump_0", 390, 255],
    ["prop_stump_0", 290, 285],
]
var tents := ["prop_tent_olive_0", "prop_tent_rust_0"]

var layout: Dictionary
var origin: Vector2
var pad_cells := {}                                # pid -> Rect2 (px)
var pads_node: Node2D
var world: Node2D
var tray: Node2D
var hover: Sprite2D
var report_label: Label
var status_label: Label

var selected := ""                                # guest id being placed
var guest_nodes := {}                             # gid -> Node2D
var tent_nodes := {}                              # gid -> [Sprite2D]
var star_labels := {}                             # pid -> Label
var evening_open := true                          # Enter -> Goodnight


func _tex(n: String) -> Texture2D:
    return load(A + n + ".png")


func _sprite(n: String) -> Sprite2D:
    var s := Sprite2D.new()
    s.texture = _tex(n)
    s.centered = false
    return s


func _label(text: String, size := 8) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", Color("f5e9c8"))
    l.add_theme_color_override("font_shadow_color", Color("1c2413"))
    l.add_theme_constant_override("shadow_offset_x", 1)
    l.add_theme_constant_override("shadow_offset_y", 1)
    return l


func _ready() -> void:
    layout = Catalog.data["layouts"]["pinewatch"]
    var opx: Array = layout["camp_core_origin_px"]
    origin = Vector2(opx[0], opx[1])
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    _build_ground(rng)
    _build_scatter(rng)
    pads_node = Node2D.new()
    pads_node.name = "Pads"
    add_child(pads_node)
    _build_pads(rng)
    world = Node2D.new()
    world.name = "World"
    world.y_sort_enabled = true
    add_child(world)
    _build_props()
    _build_flame()
    tray = Node2D.new()
    tray.name = "Tray"
    add_child(tray)
    status_label = _label("", 8)
    status_label.position = Vector2(4, 344)
    add_child(status_label)
    report_label = _label("", 8)
    report_label.position = Vector2(4, 4)
    add_child(report_label)
    Game.advance_day()
    _spawn_board()
    _status()
    # capture engine render for pipeline review (test scene only)
    if OS.get_cmdline_args().has("--shot"):
        await get_tree().process_frame
        await get_tree().process_frame
        var img := get_viewport().get_texture().get_image()
        var out := "D:/monet/trail-bound/assets_src/cleanup/pinewatch_engine.png"
        print("scene shot ->", out, " err:", img.save_png(out))
        get_tree().quit()


# ------------------------------------------------------------- scenery

func _build_ground(rng: RandomNumberGenerator) -> void:
    var ground := Node2D.new()
    ground.name = "Ground"
    add_child(ground)
    for ty in 12:
        for tx in 20:
            var pos := Vector2i(tx, ty)
            var n := "terrain_grass_flat_0"
            if pond.has_point(Vector2(tx, ty)):
                n = "terrain_water_flat_0"
            elif pos in path:
                n = "terrain_dirt_0"
            elif ty < 3:
                n = "terrain_floor_flat_0"
            else:
                var v := rng.randf()
                n = ("terrain_grass_worn_0" if v < 0.06
                     else "terrain_grass_lush_0" if v < 0.12
                     else "terrain_grass_flat_0")
            var s := _sprite(n)
            s.position = Vector2(tx * T, ty * T)
            ground.add_child(s)


func _build_scatter(rng: RandomNumberGenerator) -> void:
    var scatter := Node2D.new()
    scatter.name = "Scatter"
    add_child(scatter)
    for ty in range(3, 11):
        for tx in 20:
            if pond.has_point(Vector2(tx, ty)) \
                    or Vector2i(tx, ty) in path or rng.randf() > 0.08:
                continue
            var d := _sprite(decals[rng.randi() % decals.size()])
            d.position = Vector2(tx * T + rng.randi() % 8,
                                 ty * T + rng.randi() % 8)
            scatter.add_child(d)


func _build_pads(rng: RandomNumberGenerator) -> void:
    var spots: Dictionary = layout["pads"]["spots"]
    var open_pads: Array = layout["pads"]["open"]
    for pid in spots:
        var c: Array = spots[pid]
        var rect := Rect2(origin + Vector2(c[0], c[1]) * CELL,
                          Vector2(CELL, CELL))
        pad_cells[pid] = rect
        if pid in open_pads:
            var m := _sprite("pad_open")
            m.name = "mark_" + pid
            m.position = rect.position
            pads_node.add_child(m)
        else:
            for gy in 2:
                for gx in 2:
                    var o := _sprite("terrain_grass_lush_0")
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


func _build_props() -> void:
    for p in props:
        var s: Sprite2D = _sprite(p[0])
        var size: Vector2 = s.texture.get_size()
        s.position = Vector2(p[1] - size.x / 2.0, p[2] - size.y)
        world.add_child(s)


func _build_flame() -> void:
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


# ------------------------------------------------------------- guests

func _trait_names(ids: Array) -> String:
    var out := []
    for t in ids:
        for row in Catalog.data.get("traits", []):
            if row.get("id") == t:
                out.append(row.get("name", t))
    return " · ".join(out)


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
        var s := _sprite("player_front_0")
        s.modulate = Color("ffcf7d") if req.get("elite") \
            else Color("b8d7a8") if req.get("loud") else Color("ffffff")
        g.add_child(s)
        var l := _label("%s %dc\n%s" % [req.get("name", "?"),
            req.get("fee", 0), _trait_names(req.get("traits", []))])
        l.position = Vector2(-8, 30)
        g.add_child(l)
        var slot := Rect2(430 + i * 68, 300, 64, 60)
        g.position = slot.position
        tray.add_child(g)
        guest_nodes[req["id"]] = g
        i += 1
    evening_open = true
    report_label.text = ""
    _sync_marks()


func _seat_visual(gid: String, pads: Array) -> void:
    var st: Dictionary = Game.site_state()
    var arch: String = st["guests"][gid].get("archetype", "")
    var g: Node2D = guest_nodes[gid]
    g.get_parent().remove_child(g)
    world.add_child(g)                             # join the y-sort
    g.position = pad_cells[pads[0]].position + Vector2(12, -22)
    tent_nodes[gid] = []
    var idx := absi(hash(gid + arch) as int)
    for pid in pads:
        var t := _sprite(tents[idx % tents.size()])
        idx += 1
        var r: Rect2 = pad_cells[pid]
        t.position = r.position + Vector2(
            CELL / 2.0 - t.texture.get_size().x / 2.0,
            CELL - t.texture.get_size().y)
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
    g.position = Vector2(430 + guest_nodes.keys().find(gid) * 68, 300)
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
        var l := _label("★%d" % r["stars"], 9)
        l.position = pad_cells[pid].position + Vector2(24, 2)
        star_labels[pid] = l
        pads_node.add_child(l)


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
    status_label.text = ("day %d · site day %d · %s · %dc   " \
        + "[click guest, then pad · Enter = Goodnight]") % [
        Game.day, Game.site_day(), st["weather"].to_upper(), Game.coins]


func _goodnight() -> void:
    var names := {}
    for gid in Game.site_state()["guests"]:
        names[gid] = Game.site_state()["guests"][gid].get("name", gid)
    var rep := Game.goodnight()
    var parts := []
    for r in rep["results"]:
        parts.append("%s %d★ +%dc  “%s”" % [names.get(r["id"], r["id"]),
            r["stars"], r["fee"] + int(r["tip"]), r["comment"]])
    if rep["walk_ins"] > 0:
        parts.append("%d walk-in(s) +%dc" % [rep["walk_ins"],
            rep["meal_sales"]])
    report_label.text = "night: " + "   ".join(parts) \
        + "   →  rating %.1f   income %dc" % [rep["rating"], rep["income"]]
    evening_open = false
    _clear_previews()
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
        if Rect2(g.global_position - Vector2(8, 0),
                Vector2(80, 60)).has_point(px):
            return gid
    return ""


func _unhandled_input(event: InputEvent) -> void:
    var st: Dictionary = Game.site_state()
    if not evening_open and event is InputEventMouseButton:
        return                                       # night: watch the fire
    if event is InputEventMouseMotion:
        var pid := _pad_at(get_global_mouse_position())
        var ok: bool = pid != "" \
            and st["pads"].get(pid, {}).get("open", false) == true \
            and not _pad_occupied(pid) and selected != ""
        hover.visible = ok
        if ok:
            hover.position = pad_cells[pid].position
    elif event is InputEventMouseButton and event.pressed \
            and event.button_index == MOUSE_BUTTON_LEFT:
        var px := get_global_mouse_position()
        var gid := _guest_at(px)
        var pid := _pad_at(px)
        if gid != "" and gid in st["guests"]:
            if st["assignments"].has(gid):           # pull back to tray
                Game.unseat(gid)
                _unseat_visual(gid)
                selected = ""
                _clear_previews()
            else:                                    # pick for seating
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
    elif event is InputEventKey and event.pressed \
            and event.keycode == KEY_ENTER:
        if evening_open:
            _goodnight()
        else:
            report_label.text = ""
            Game.advance_day()
            _spawn_board()
            _status()
