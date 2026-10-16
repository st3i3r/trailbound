extends RefCounted
## CastPresenter — sim cast + errands + dog rounds (§7/§9/D4).
## SOTA split (D-ARCH-9/10/11/12/13/14/15): the scene owns the
## frame tick, all actor/errand/dog nodes and sim/view state
## (`_sim`, `_actor_view`, maps); this owns cast build/configure
## (day + evening), seat-actor sync, emote chips, errand spawn/
## sync/free and dog rounds + direction names. Scene passed as
## untyped `s`. Bare method refs (`configure()` emote args)
## rename like calls; node add_child routes via `s`.


var s  # the pinewatch_test scene (untyped: mutual ref)


func _init(scene) -> void:
    s = scene


func build_actors() -> void:
    var ch: float = s.WORLD_SCALE * 1.12    # ~0.9 — chars shrink slightly less
                                  # than props so they stay readable
    # Stone Fire Pit upgrade swaps the bare ground for the fitted
    # ring — drawn first so the flame loop sorts over it.  Lazy via
    # _sync_decor_world so a mid-session buy drops the ring in too.
    s._sync_fire_pit()
    # fire loop — A1b cycle, frames 1..6 (frame 0 is the ignite lead-in)
    var fire: AnimatedSprite2D = s._anchored_frames("fx",
        ["fx/A1b_1", "fx/A1b_2", "fx/A1b_3", "fx/A1b_4", "fx/A1b_5",
         "fx/A1b_6"], 6.0, s._fire_pos)
    fire.name = "FireLoop"
    # reduced-flashing setting: the 6 fps flame cycle is the one real
    # on-screen flicker — slow it to a breathing ember instead of
    # killing the fire outright (still reads as fire, stops strobing)
    if UIFeel.reduced_flashing:
        fire.speed_scale = 0.35
    fire.scale = Vector2(ch, ch)
    s.world.add_child(fire)
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
    s._fire_light = PointLight2D.new()
    s._fire_light.name = "FireLight"
    s._fire_light.position = s._fire_pos + Vector2(0, -8)  # flames ride
                                                    # above the anchor
    s._fire_light.color = Color(1.0, 0.60, 0.32)
    s._fire_light.texture = gt
    s._fire_light.texture_scale = 1.7        # ~80px pool over the ring
    s._fire_light.energy = 0.0               # the ember curve owns it
    s.world.add_child(s._fire_light)
    s._fx.track_emit(&"fire", Color(1.5, 1.5, 1.5), &"ember",
        s._fire_light, &"energy", 0.06)  # §5.10 hearth flicker —
                                       # storm turns it to sputter
    # warden idle-south (A2, 4f breathing) beside the fire
    var warden: AnimatedSprite2D = s._anchored_frames("chars",
        ["characters/warden/A2_idle_south_0",
         "characters/warden/A2_idle_south_1",
         "characters/warden/A2_idle_south_2",
         "characters/warden/A2_idle_south_3"], 4.0, s.WARDEN_POS)
    warden.scale = Vector2(ch, ch)
    s.world.add_child(warden)
    # camp dog idle (A3, 8f) — bean_quad cast, feet anchor at (26,38)
    var dog: AnimatedSprite2D = s._anchored_frames("chars",
        ["characters/bean_quad/A3_idle_south_0",
         "characters/bean_quad/A3_idle_south_1",
         "characters/bean_quad/A3_idle_south_2",
         "characters/bean_quad/A3_idle_south_3",
         "characters/bean_quad/A3_idle_south_4",
         "characters/bean_quad/A3_idle_south_5",
         "characters/bean_quad/A3_idle_south_6",
         "characters/bean_quad/A3_idle_south_7"], 5.0, s._dog_pos,
        Vector2(26, 38))
    dog.scale = Vector2(ch, ch)
    s.world.add_child(dog)
    # ranger Mai keeps watch by the path bend
    var mai: Sprite2D = s._anchored("characters/ranger_mai",
                         "ranger_mai_south", s.MAI_POS)
    mai.scale = Vector2(ch, ch)
    s.world.add_child(mai)
    s._char_shadow(s.WARDEN_POS, 34.0)
    s._dog_shadow = s._char_shadow(s._dog_pos, 26.0)
    s._char_shadow(s.MAI_POS, 34.0)
    s.actor_nodes = [warden, dog, mai]         # walk-behind fade set
    s._actor_map = {"warden": warden, "dog": dog, "mai": mai}
    # §9 rounds — bean_quad walk anims swap in for the tween; the
    # idle loop owns him while he's posted.
    s._dog_move = AnimatedSprite2D.new()
    s._dog_move.centered = false
    s._dog_move.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    s._dog_move.scale = Vector2(ch, ch)
    s._dog_move.offset = -Vector2(26, 38)
    var dframes := SpriteFrames.new()
    for d4 in ["east", "south", "west", "north"]:
        dframes.add_animation(d4)
        dframes.set_animation_speed(d4, 8.0)
        for i in 8:
            dframes.add_frame(d4,
                s._tex("characters/bean_quad/A3_walk_%s_%d" % [d4, i]))
    s._dog_move.sprite_frames = dframes
    s._dog_move.visible = false
    s.world.add_child(s._dog_move)
    s._dog_points = [s._dog_pos,
        s._fire_pos + Vector2(40, 18),
        s._board_rect.get_center() + Vector2(10, 34)]
    var fsp: Variant = s.layout.get("errand_spots", {}).get("forage")
    if fsp != null:
        s._dog_points.append(Vector2(fsp[0], fsp[1]) + Vector2(22, 14))
    s._sync_decor_world()                      # placed pieces render always
    s._build_overlay = s.BuildGrid.new()         # UI-033 cell-tint layer
    s._build_overlay.org = s.origin
    s._build_overlay.cell_px = s.CELL
    s._build_overlay.visible = false
    s._build_overlay.z_as_relative = false
    s._build_overlay.z_index = 8               # tints ride above world art
    s.stage.add_child(s._build_overlay)


func cast_seed() -> int:
    return int(abs(hash("cast:%s:%d" % [Game.site_id, Game.day])))


func actors_data() -> Dictionary:
    return Catalog.data.get("actors", {})


func cast_evening() -> void:
    s._sim = SimDirector.cast_night(Game.site_state(), s.layout,
        cast_seed(), actors_data())
    if s._actor_view == null:
        s._actor_view = ActorView.new()
        s.add_child(s._actor_view)
    s._actor_view.clear()
    s._actor_view.configure(s._sim, actors_data(), s.world, s._tex,
        func() -> bool: return s.panel_mgr.top() != null,
        s.WORLD_SCALE * 1.12, emote_show, emote_hide)
    sync_seat_actors()


## Day ambience (§3 "alive in ten seconds"): while the player reads
## the board or works prep, locals + the dog drift the errand loop.
## Same presenter, calmer cast — no guest parties until dusk.


func cast_day() -> void:
    s._sim = SimDirector.cast_day(Game.site_state(), s.layout,
        cast_seed(), actors_data(), Game.last_night_perfect())
    if s._actor_view == null:
        s._actor_view = ActorView.new()
        s.add_child(s._actor_view)
    s._actor_view.clear()
    s._actor_view.configure(s._sim, actors_data(), s.world, s._tex,
        func() -> bool: return s.panel_mgr.top() != null,
        s.WORLD_SCALE * 1.12, emote_show, emote_hide)


func recast_if_evening() -> void:
    if Game.phase == Game.Phase.EVENING:
        cast_evening()
    elif Game.phase in [Game.Phase.MORNING, Game.Phase.PREP]:
        cast_day()                            # build changed the set


## The sim actor IS the guest once cast — the stand-in seat sprite
## hides (the node stays: bubbles/plates/taps anchor to the pad,
## not to the walking figure).


func sync_seat_actors() -> void:
    var cast := {}
    if s._sim != null:
        for eid in s._sim.query(["persona"]):
            var gid := String(s._sim.getc(eid, "persona")
                .get("guest", ""))
            if gid != "":
                cast[gid] = true
    for gid in s.guest_nodes:
        var n: Node2D = s.guest_nodes[gid]
        if n.get_child_count() > 0:
            (n.get_child(0) as CanvasItem).visible = not cast.has(gid)


func clear_cast() -> void:
    if s._actor_view != null:
        s._actor_view.clear()
    s._sim = null
    for gid in s.guest_nodes:
        var n: Node2D = s.guest_nodes[gid]
        if n.get_child_count() > 0:
            (n.get_child(0) as CanvasItem).visible = true


## Emote chips — sim emote comp -> marker chip over the actor sprite.
## Icon strings route through the registry where they can, a glyph
## label otherwise.


func emote_show(anchor: Node2D, icon: String) -> int:
    var map := {"!": "alert", "?": "question", "heart": "heart"}
    var ik := String(map.get(icon, ""))
    var content: Control
    if ik != "":
        content = UIKit.icon_rect(ik, UITokens.PAPER, 10)
    else:
        content = UIKit.label_for(icon, UITokens.TypeRole.DISPLAY,
            UITokens.GOLD)
    return int(s.markers.icon_chip(anchor, content, Vector2(8, -42))[0])


func emote_hide(tok: int) -> void:
    s.markers.release(tok)


## Outfitter (UI-032) — the decor tab's Place rows hand off to build
## mode through the sheet's place_requested signal.


func spawn_errands() -> void:
    clear_errands()
    s._errand_layer = Node2D.new()
    s._errand_layer.name = "Errands"
    s.world.add_child(s._errand_layer)
    sync_errand_nodes()
    var es: Dictionary = s.layout.get("errand_spots", {})
    # fishing water is authored per site: pinewatch's lone "pond" anchor
    # or whisper_river's named banks — each spot keeps its own daily
    # catch count in the sim
    s._fish_spots = []
    if es.has("pond"):
        add_errand_spot("pond", es["pond"], "fish", "pond")
    for k in es.get("fishing", {}):
        add_errand_spot("fish_" + String(k), es["fishing"][k],
            "fish", String(k))
    if es.has("lookout"):
        add_errand_spot("lookout", es["lookout"], "eye", "lookout")
    sync_dog_chip()
    s._sync_pad_chips()


func add_errand_spot(key: String, a: Variant, icon: String, spot := "") -> void:
    var anchor := Node2D.new()
    anchor.position = Vector2(float(a[0]), float(a[1])).round()
    s._errand_layer.add_child(anchor)
    s._errand_anchors[key] = anchor
    afford_chip(anchor, icon, key)
    if spot != "" and icon == "fish":
        s._fish_spots.append({"key": key, "node": anchor, "spot": spot})


## One forage node = one decal + one leaf affordance chip above it.


func spawn_errand_node(node: Dictionary) -> void:
    var nid := String(node["id"])
    var p: Array = node.get("px", [0, 0])
    var spr: Sprite2D = s._anchored("decals", errand_decal(node),
        Vector2(float(p[0]), float(p[1])))
    s._errand_layer.add_child(spr)
    s._errand_nodes[nid] = spr
    afford_chip(spr, "leaf", nid)


## Spotting can append a bonus node mid-prep — spawn visuals for any
## sim node that doesn't have one yet.


func sync_errand_nodes() -> void:
    if s._errand_layer == null:
        return
    for node in Game.site_state()["forage_nodes"]:
        var nid := String(node["id"])
        if not s._errand_nodes.has(nid):
            spawn_errand_node(node)


## The stray advertises a pet only while today's pet is unspent.


func errand_decal(node: Dictionary) -> String:
    var items: Array = node.get("items", [])
    var first := String(items[0]) if not items.is_empty() else ""
    if "goldcap" in items:
        return "decal_mushroom_orange"         # the rare one reads gold
    match first:
        "berries":  return "decal_berries_red"
        "mushroom": return "decal_mushroom_brown"
        "honey":    return "decal_flowers_white"
        _:          return "decal_plantain"    # herb / generic forage


func sync_dog_chip() -> void:
    var tok := int(s._errand_marks.get("dog", 0))
    var want := bool(Game.dog.get("met", false)) \
        and not bool(Game.dog.get("pet_today", false))
    if tok != 0 and not want:
        s.markers.release(tok)
        s._errand_marks.erase("dog")
    elif tok == 0 and want and s._actor_map.has("dog"):
        afford_chip(s._actor_map["dog"], "dog", "dog")


## The quiet affordance: a small icon chip riding the node's marker.


func afford_chip(anchor: Node2D, icon: String, key: String) -> void:
    var ic := UIKit.icon_rect(icon, UITokens.PAPER, 12)
    ic.position = Vector2(3, 3)
    s._errand_marks[key] = s.markers.icon_chip(anchor, ic,
        Vector2(-9, -30))[0]


## Result feedback: a chip pops over the spot, holds a readable beat,
## veils out, releases its marker.  Reduced motion keeps the hold —
## the fade is the motion, not the point.


func free_errand(nid: String) -> void:
    var spr: Node2D = s._errand_nodes.get(nid)
    if spr != null:
        var tw: Tween = UIFeel.apply(s.create_tween(), "veil_out")
        tw.tween_property(spr, "modulate:a", 0.0, UIFeel.dur("veil_out"))
        tw.tween_callback(spr.queue_free)
        s._errand_nodes.erase(nid)
    var tok := int(s._errand_marks.get(nid, 0))
    if tok != 0:
        s.markers.release(tok)
        s._errand_marks.erase(nid)


func clear_errands() -> void:
    for tok in s._errand_marks.values():
        s.markers.release(int(tok))
    s._errand_marks = {}
    s._errand_nodes = {}
    s._errand_anchors = {}
    for tok in s._pad_chips.values():
        s.markers.release(int(tok))
    s._pad_chips = {}
    s._close_pad_menu()
    if s._errand_layer != null:
        s._errand_layer.queue_free()
        s._errand_layer = null


## PREP tap routing.  Returns a tag for the smoke harness; hit-test
## order is pads (fixed landmarks) -> forage -> pond -> lookout -> dog.


func dog_walk(dog: AnimatedSprite2D) -> void:
    if s._dog_points.is_empty():
        return
    # pick from reachable waypoints only — choosing his own spot used
    # to no-op the tick (and flaked the smoke assert ~25% of runs)
    var cands: Array = []
    for p in s._dog_points:
        if (p as Vector2).distance_to(dog.position) >= 10.0:
            cands.append(p)
    if cands.is_empty():
        return
    var next: Vector2 = cands[randi() % cands.size()]
    s._dog_walking = true
    var dir := next - dog.position
    s._dog_move.animation = dir4(dir)
    s._dog_move.position = dog.position
    s._dog_move.visible = true
    s._dog_move.play()
    dog.visible = false
    var dur := dir.length() / 36.0           # ~36px/s waddle
    var tw := dog.create_tween().set_parallel()
    tw.tween_property(dog, "position", next, dur)
    tw.tween_property(s._dog_move, "position", next, dur)
    if s._dog_shadow != null:
        tw.tween_property(s._dog_shadow, "position",
            next + Vector2(2.0, -1.0), dur)
    tw.chain().tween_callback(func():
        s._dog_move.visible = false
        dog.visible = true
        s._dog_walking = false)


## 8-way direction name -> camp_dog_<dir>.png still.


func dir8(d: Vector2) -> String:
    var oct: int = int(round(d.angle() / (PI / 4.0))) & 7
    return ["east", "south-east", "south", "south-west",
        "west", "north-west", "north", "north-east"][oct]


## 4-way direction name -> bean_quad A3_walk_<dir> anim (diagonals
## fold to the nearest cardinal).


func dir4(d: Vector2) -> String:
    var q: int = int(round(d.angle() / (PI / 2.0))) & 3
    return ["east", "south", "west", "north"][q]


