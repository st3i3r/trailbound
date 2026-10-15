extends RefCounted
## InputPresenter — gesture + tap routing (D-ARCH-8, §5/§17).
## SOTA split (D-ARCH-9/10): the scene owns nodes, camera state
## (`_cam`), selection UI state (`selected`, `_meal_sel`) and
## all visual/HUD builders; this owns gesture state (tap-arm,
## card-press/drag ghost, build ghost) and the tap/drag/pan
## decision code. Scene passed as untyped `s`; the only local
## renamed is _decor_idx_at's sprite (`s` -> `sn`). Node APIs
## (`tr`, `create_tween`) route through `s` — RefCounted has none.


var s  # the pinewatch_test scene (untyped: mutual ref)

# Gesture state — moved here from the scene; camera (`_cam`)
# and selection UI state (`selected`, `_meal_sel`) stay there.
var _tap_armed := false
var _tap_origin := Vector2.ZERO
var _mb_pan := false
var _press: Dictionary = {}
var _drag_ghost: Sprite2D
var _build_on := false
var _build_item: Dictionary = {}
var _build_ghost: Sprite2D
var _build_hint := 0


func _init(scene) -> void:
    s = scene


func tap_meal(idx: int) -> void:
    if s._meal_sel == idx or idx < 0:
        s._meal_sel = -1
        s.hud.tray.set_meal_selected(-1)
        s.hud.tray.hide_strip()
        if idx >= 0:
            UIFeel.sfx("close")
        return
    s._meal_sel = idx
    s.hud.tray.set_meal_selected(idx)
    s.hud.tray.show_meal(s._ing_name_row("recipes",
        String(Game.meals[idx].get("id", ""))))
    UIFeel.sfx("pop")
    UIFeel.haptic("press")


func serve_tap(gid: String) -> void:
    var st: Dictionary = Game.site_state()
    if s._meal_sel < 0 or s._meal_sel >= Game.meals.size():
        tap_meal(-1)
        return
    var mid := String(Game.meals[s._meal_sel].get("id", ""))
    var g: Node2D = s.guest_nodes.get(gid)
    if String(st["served"].get(gid, "")) == mid:
        Game.unserve(gid)
        UIFeel.sfx("close")
        s._clear_served_mark(gid)
    elif Game.serve_meal(gid, mid):
        UIFeel.sfx("pop")
        UIFeel.haptic("confirm")
        s._clear_served_mark(gid)
        if g != null:
            # the plate lands beside the guest's feet — a little dish
            # on the ground, honest to the grid, no floating UI
            var pair: Array = s.markers.icon_chip(g,
                UIKit.icon_rect("bowl", UITokens.PAPER, 12),
                Vector2(10, -10))
            s._served_marks[gid] = pair[0]
            var fav := String(st["guests"].get(gid, {})
                .get("favourite", ""))
            if mid == fav and fav != "" \
                    and Game.recipes_cooked.has(fav):
                s._float_chip(g, s.tr("tray_fav_served"), "heart")
    else:
        UIFeel.sfx("warn")
        UIFeel.haptic("warn")
    s.hud.tray.sync_served(st["served"], Game.meals)


## Selection is the tap-tap path (UI-020): card tap -> previews +
## neutral strip; tap again to put the guest back.


func select(gid: String) -> void:
    s.selected = gid
    s.hud.tray.set_selected(gid)
    s.hud.tray.show_guest_terms(Game.site_state()["guests"][gid],
        s.tr("tray_pick_pad"))
    show_previews(gid)


func deselect() -> void:
    s.selected = ""
    s.hud.tray.set_selected("")
    s.hud.tray.hide_strip()
    clear_previews()


func tap_card(gid: String) -> void:
    if Game.site_state()["assignments"].has(gid):
        do_unseat(gid)
    elif gid == s.selected:
        deselect()
    else:
        select(gid)


func try_seat(pid: String) -> void:
    var st: Dictionary = Game.site_state()
    var pick := pads_for(s.selected, pid)
    if pick.size() == int(st["guests"][s.selected].get("pads", 1)) \
            and Game.seat(s.selected, pick):
        UIFeel.haptic("confirm")
        UIFeel.sfx("confirm")
        s._seat_visual(s.selected, pick)
        deselect()
    else:
        # tapped a pad but couldn't seat — wrong count or camp full;
        # the card wobbles so the refusal lands on the thing tried
        UIFeel.haptic("warn")
        if not st["pads"].get(pid, {}).get("open", false):
            s._float_chip(s.pads_node.get_node("mark_" + pid),
                s.tr("bld_not_prep"), "lock")
        UIFeel.sfx("warn")
        s.hud.tray.shake_card(s.selected)


func do_unseat(gid: String) -> void:
    Game.unseat(gid)
    s._unseat_visual(gid)
    deselect()


## Card press -> drag (UI-020): the guest sprite rides the pointer
## until release; release over a pad seats exactly like a tap-tap.


func begin_drag(gid: String) -> void:
    select(gid)
    _drag_ghost = s._anchored("characters/warden", "warden_south",
        Vector2.ZERO)
    _drag_ghost.modulate = s._tint(Game.site_state()["guests"][gid])
    _drag_ghost.modulate.a = 0.8
    s.marks.add_child(_drag_ghost)
    UIFeel.pop(_drag_ghost, Vector2(1.15, 0.8))   # pickup squash
    UIFeel.sfx("pop")


func end_drag(px: Vector2) -> void:
    if _drag_ghost == null:
        return
    _drag_ghost.queue_free()
    _drag_ghost = null
    var pid := pad_at(px)
    if pid != "" and s.selected != "":
        try_seat(pid)


## Live strip: while a guest is selected, hovering an open pad shows
## the full score breakdown; anywhere else it falls back to the
## guest's neutral trait list.


func update_strip(px: Vector2) -> void:
    var gid: String = s.selected
    if gid == "":
        return
    var st: Dictionary = Game.site_state()
    var pid := pad_at(px)
    if pid != "" and st["pads"].get(pid, {}).get("open", false) \
            and not pad_occupied(pid):
        var pick := pads_for(gid, pid)
        if pick.size() == int(st["guests"][gid].get("pads", 1)):
            s.hud.tray.show_preview(Game.preview(gid, pick))
            return
    s.hud.tray.show_guest_terms(st["guests"][gid], s.tr("tray_pick_pad"))


## Pad rings show on open pads with nobody seated — the tent itself
## is the occupied state (§5.1).


func pads_for(gid: String, pid: String) -> Array:
    var st: Dictionary = Game.site_state()
    if int(st["guests"].get(gid, {}).get("pads", 1)) != 2:
        return [pid]
    for nb in s.layout["pads"]["neighbours"].get(pid, []):
        if st["pads"].get(nb, {}).get("open", false) \
                and not pad_occupied(nb):
            return [pid, nb]
    return []


func show_previews(gid: String) -> void:
    clear_previews()
    var st: Dictionary = Game.site_state()
    var best_pid := ""
    var best := -1
    for pid in s.pad_cells:
        if not st["pads"].get(pid, {}).get("open", false) \
                or pad_occupied(pid):
            continue
        var pick := pads_for(gid, pid)
        if pick.is_empty():
            continue
        var r := Game.preview(gid, pick)
        if r.is_empty():
            continue
        if int(r["stars"]) > best:
            best = int(r["stars"])
            best_pid = pid
        # star icon + number, comp-style
        var m := Node2D.new()
        m.position = s.pad_cells[pid].position + Vector2(18, 2)
        var t := UIKit.icon_rect("star_full")
        t.name = "Star"
        m.add_child(t)
        var l := UIKit.label_for("%d" % r["stars"],
            UITokens.TypeRole.HEAD)
        l.name = "Num"
        l.position = Vector2(17, 2)
        m.add_child(l)
        s.star_labels[pid] = m
        s.marks.add_child(m)
    # assist mode: gild the best-scoring pad so the pick is obvious
    # (numbers stay on every pad — this is emphasis, not hiding)
    if bool(Game.settings.get("assist_mode", false)) \
            and s.star_labels.has(best_pid):
        var top: Node2D = s.star_labels[best_pid]
        top.get_node("Star").modulate = UITokens.GOLD
        top.get_node("Num").add_theme_color_override("font_color",
            UITokens.GOLD)


func clear_previews() -> void:
    for l in s.star_labels.values():
        l.queue_free()
    s.star_labels = {}


func pad_occupied(pid: String) -> bool:
    var st: Dictionary = Game.site_state()
    for pad_ids in st["assignments"].values():
        if pid in pad_ids:
            return true
    return false


func prep_tap(px: Vector2) -> String:
    var st: Dictionary = Game.site_state()
    var pid := pad_at(px)
    if pid != "" and not s._pad_clearing.has(pid):
        s._open_pad_menu(pid)
        return "pad" if s._pad_menu_pid != "" else ""
    s._close_pad_menu()                        # a tap elsewhere dismisses
    for node in st["forage_nodes"]:
        var nid := String(node["id"])
        var spr: Node2D = s._errand_nodes.get(nid)
        if spr == null:
            continue
        if not Rect2(spr.position + Vector2(-20, -32),
                Vector2(40, 40)).has_point(px):
            continue
        var got := Game.gather(nid)
        if got.is_empty():
            UIFeel.sfx("warn")
            s._float_chip(spr, s.tr("prep_pantry_full"), "leaf")
            return "full"
        UIFeel.sfx("pop")
        UIFeel.haptic("press")
        s._float_chip(spr, s._gain_text(got), "leaf")
        if not st["forage_nodes"].any(func(n): return n["id"] == nid):
            s._free_errand(nid)                # cleaned out — husk fades
        s._status()                          # pantry count rides the HUD
        return "gathered"
    for fs in s._fish_spots:
        var water: Node2D = fs["node"]
        if not Rect2(water.position - Vector2(28, 28),
                Vector2(56, 56)).has_point(px):
            continue
        if "fishing_rod" not in Game.gear:
            UIFeel.sfx("warn")
            s._float_chip(water, s.tr("prep_need_rod"), "fishing_rod")
            return "locked"
        var fish := Game.fish_catch(String(fs["spot"]))
        if fish == "":
            s._float_chip(water, s.tr("prep_pond_rest"), "fish")
            return "rested"
        UIFeel.sfx("pop")
        s._float_chip(water, "+1 %s" % s._ing_name(fish), "fish")
        s._status()
        return "caught"
    var look: Node2D = s._errand_anchors.get("lookout")
    if look != null and Rect2(look.position - Vector2(28, 28),
            Vector2(56, 56)).has_point(px):
        if "binoculars" not in Game.gear:
            UIFeel.sfx("warn")
            s._float_chip(look, s.tr("prep_need_binocs"), "binoculars")
            return "locked"
        if not Game.can_spot():
            s._float_chip(look, s.tr("prep_spot_done"), "eye")
            return "rested"
        var r := Game.spot()
        UIFeel.sfx("confirm")
        var bird: Dictionary = r.get("bird", {})
        s._float_chip(look, s.tr("prep_spotted") % s._ing_name_row(
            "birds", String(bird.get("id", "")))
            if not bird.is_empty() else s.tr("prep_birds_done"), "eye")
        s._sync_errand_nodes()                 # the bonus node lands live
        return "spotted"
    var dog: Node2D = s._actor_map.get("dog")
    if dog != null and Rect2(dog.position + Vector2(-26, -52),
            Vector2(52, 58)).has_point(px):
        if Game.dog_pet():
            UIFeel.haptic("confirm")
            UIFeel.sfx("confirm")
            s._float_chip(dog, "", "heart")
            s._sync_dog_chip()                 # paw chip retires for today
            return "pet"
        s._float_chip(dog, s.tr("prep_dog_done"), "dog")
        return "rested"
    return ""


func cell_px(c: Vector2i) -> Vector2:
    return s.origin + Vector2(c) * s.CELL


## Footprint anchor: bottom-centre of the covered cells — the same
## convention every world prop uses.


func foot_anchor_px(cells: Array) -> Vector2:
    var minx := 1e9
    var maxx := -1e9
    var maxy := -1e9
    for c in cells:
        var v: Vector2i = c if c is Vector2i \
            else Vector2i(int(c[0]), int(c[1]))
        minx = minf(minx, v.x)
        maxx = maxf(maxx, v.x)
        maxy = maxf(maxy, v.y)
    return s.origin + Vector2((minx + maxx + 1.0) / 2.0,
        maxy + 1.0) * s.CELL


## Placed decor lives in the world permanently — rebuilt wholesale on
## any verb change (sets are small) so index keys always match the sim.


func on_build_pressed() -> void:
    if Game.phase != Game.Phase.PREP:
        s._hud_hint(s.tr("bld_not_prep"))
        UIFeel.sfx("warn")
        return
    set_build(not _build_on)


func set_build(on: bool) -> void:
    if on == _build_on:
        return
    _build_on = on
    s.hud.set_build_active(on)
    s._build_overlay.visible = on
    if on:
        s._build_overlay.free_cells = Game.decor_cells_free(
            int(_build_item.get("idx", -1)))
        s._build_overlay.queue_redraw()
    else:
        disarm_build()
        s._close_piece_menu()


## {id, kind: buy|stored|move, idx} — arms the ghost.  move reuses the
## piece's own cells (ignore) so it can land where it already sits.


func arm_build(item: Dictionary) -> void:
    _build_item = item
    set_build(true)
    s._close_piece_menu()
    if _build_ghost != null:
        _build_ghost.queue_free()
        _build_ghost = null
    var spec: Array = s.DECOR_SPRITE.get(String(item.get("id", "")), [])
    if not spec.is_empty():
        _build_ghost = s._anchored(spec[0], spec[1], Vector2.ZERO)
        _build_ghost.modulate = Color(1, 1, 1, 0.55)
        _build_ghost.z_index = 6           # previews ride above pieces
        s.world.add_child(_build_ghost)
    var row: Dictionary = s._decor_row_for(String(item.get("id", "")))
    _build_item["want"] = 1 if String(row.get("size", "1x1")) == "1x1" \
        else 2
    if String(item.get("kind", "")) == "move":
        var n: CanvasItem = s._decor_nodes.get(int(item["idx"]))
        if n != null:
            n.modulate.a = 0.3           # the moving piece dims in place
    build_hint_show()


func disarm_build() -> void:
    if _build_ghost != null:
        _build_ghost.queue_free()
        _build_ghost = null
    _build_item = {}
    if _build_hint != 0:
        s.markers.release(_build_hint)
        _build_hint = 0
    if s._build_overlay != null:
        s._build_overlay.cand = []
        s._build_overlay.reach = 0
        s._build_overlay.queue_redraw()
    s._sync_decor_world()                  # lifts any mid-move dim


## The persistent twin of _float_chip — rides the armed ghost, says
## "{name} · {effect}" until the piece lands or the arm is cancelled.


func build_hint_show() -> void:
    if _build_hint != 0:
        s.markers.release(_build_hint)
    if _build_ghost == null:
        return
    var row: Dictionary = s._decor_row_for(String(_build_item.get("id", "")))
    _build_hint = s.markers.marker(_build_ghost, Vector2(20, -58))
    var chip := PanelContainer.new()
    chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    chip.add_theme_stylebox_override("panel", UIKit.flat("glass_chip"))
    var h := HBoxContainer.new()
    h.mouse_filter = Control.MOUSE_FILTER_IGNORE
    h.add_theme_constant_override("separation", UITokens.SP1)
    chip.add_child(h)
    h.add_child(UIKit.icon_rect(
        String(OutfitterSheet.DECOR_ICON.get(row.get("effect", ""),
            "sparkle")), UITokens.GOLD, 12))
    var l := UIKit.label_for("%s · %s" % [row.get("name", "?"),
        OutfitterSheet.effect_text(row)],
        UITokens.TypeRole.CAPTION, UITokens.PAPER)
    h.add_child(l)
    s.markers.marker_control(_build_hint).add_child(chip)


## Screen-space nudge for "wrong phase" presses — same glass chip,
## pinned bottom-centre (no world anchor to ride).


func on_place_requested(item_id: String, from_stored: bool) -> void:
    if Game.phase != Game.Phase.PREP:
        s._hud_hint(s.tr("bld_not_prep"))
        return                             # sheet stays open
    s.panel_mgr.close()
    arm_build({"id": item_id,
        "kind": "stored" if from_stored else "buy", "idx": -1})


## Pointer cell under the footprint rule: 1x1 snaps to the cell; 2x1
## picks the nearer horizontal pair, preferring a legal pair.


func footprint_at(px: Vector2) -> Array:
    var c := Vector2i((px - s.origin) / s.CELL)
    if int(_build_item.get("want", 1)) == 1:
        return [c]
    var right := [c, c + Vector2i(1, 0)]
    var left := [c - Vector2i(1, 0), c]
    var a: Array = right if px.distance_squared_to(
        foot_anchor_px(right)) <= px.distance_squared_to(
        foot_anchor_px(left)) else left
    var b: Array = left if a == right else right
    if Game.decor_placement_ok(String(_build_item["id"]), a,
            int(_build_item.get("idx", -1))):
        return a
    return b


## Motion: ghost snaps to the candidate, tinted by the real rule —
## green legal, red blocked; the reach ring previews coverage.


func ghost_to(px: Vector2) -> void:
    if _build_ghost == null or _build_item.is_empty():
        return
    var cells := footprint_at(px)
    var ok := Game.decor_placement_ok(String(_build_item["id"]), cells,
        int(_build_item.get("idx", -1)))
    _build_ghost.position = foot_anchor_px(cells)
    _build_ghost.modulate = Color(0.55, 1.0, 0.6, 0.62) if ok \
        else Color(1.0, 0.5, 0.45, 0.6)
    var row: Dictionary = s._decor_row_for(String(_build_item["id"]))
    s._build_overlay.cand = cells
    s._build_overlay.ok = ok
    s._build_overlay.reach = int(row.get("reach", 0))
    s._build_overlay.anchor = _build_ghost.position
    s._build_overlay.queue_redraw()


## Build-mode tap.  Armed -> place attempt; else piece taps open the
## Move/Store/Return context row.  Returns a tag for the smoke.


func build_tap(px: Vector2) -> String:
    if not _build_item.is_empty():
        return try_place(px)
    var idx := decor_idx_at(px)
    if idx >= 0:
        s._open_piece_menu(idx)
        return "menu"
    s._close_piece_menu()
    return ""


func try_place(px: Vector2) -> String:
    var cells := footprint_at(px)
    var id := String(_build_item["id"])
    var idx := int(_build_item.get("idx", -1))
    if not Game.decor_placement_ok(id, cells, idx):
        ghost_wobble()
        UIFeel.sfx("warn")
        return "blocked"
    var kind := String(_build_item["kind"])
    var done := false
    match kind:
        "buy":    done = Game.buy_decor(id, cells)
        "stored": done = Game.place_stored(id, cells)
        "move":   done = Game.move_decor(idx, cells)
    if not done:
        ghost_wobble()
        UIFeel.sfx("warn")
        return "blocked"
    UIFeel.sfx("stamp")
    UIFeel.haptic("confirm")
    s._sync_decor_world()
    s._build_overlay.free_cells = Game.decor_cells_free()
    s._build_overlay.queue_redraw()
    s._status()                            # coins pill / seat count
    # stay armed while the same buy is still possible — stools come in
    # twos; stored stays armed while another of that id is packed away
    var row: Dictionary = s._decor_row_for(id)
    var again := false
    if kind == "buy":
        again = Game.coins >= int(row.get("price", 0)) \
            and Game.is_unlocked(String(row.get("unlock", "")))
    elif kind == "stored":
        again = Game.site_state()["stored"].any(
            func(d): return d["id"] == id)
    if not again:
        disarm_build()
    return "placed"


## Wobble rejection — the ghost rocks and nothing else happens.


func ghost_wobble() -> void:
    if _build_ghost == null:
        return
    var tw: Tween = s.create_tween()
    UIFeel.apply(tw, "shake")
    tw.tween_property(_build_ghost, "rotation", 0.07, 0.05)
    tw.tween_property(_build_ghost, "rotation", -0.07, 0.08)
    tw.tween_property(_build_ghost, "rotation", 0.0, 0.06)


func decor_idx_at(px: Vector2) -> int:
    for i in s._decor_nodes:
        var sn: Node2D = s._decor_nodes[i]
        # prop art anchors bottom-centre; the body stands above it
        if Rect2(sn.position + Vector2(-28, -52),
                Vector2(56, 58)).has_point(px):
            return i
    return -1


## Context row on a tapped piece: Move re-arms the ghost with kind
## "move", Store packs it, today's buys return for the full price.


func hut_px() -> Vector2:
    var plots: Array = s.layout.get("crew_plots", [])
    for p in plots:
        if p.get("kind") == "structure" and p.has("px"):
            return Vector2(p["px"][0], p["px"][1])
    return s._hut.position if s._hut != null else Vector2.ZERO


## The hut is anonymous scenery until the crew engages (day-2 start or
## any collected stage) — a "!" on a ruin the player was never told
## about reads as a bug, not a mystery.


func hut_rect() -> Rect2:
    return Rect2(hut_px() + Vector2(-46, -66), Vector2(98, 78))


func hut_tap(px: Vector2) -> bool:
    if s._hut == null or not s._hut_engaged() \
            or not hut_rect().has_point(px):
        return false
    UIFeel.sfx("open")
    s._open_crew()
    return true


func pad_at(px: Vector2) -> String:
    for pid in s.pad_cells:
        if s.pad_cells[pid].has_point(px):
            return pid
    return ""


func guest_at(px: Vector2) -> String:
    for gid in s.guest_nodes:
        var g: Node2D = s.guest_nodes[gid]
        # 64px sprite sits above the feet anchor; the label hangs below
        if Rect2(g.global_position - Vector2(40, 64),
                Vector2(80, 100)).has_point(px):
            return gid
    return ""


func unhandled(event: InputEvent) -> void:
    var st: Dictionary = Game.site_state()
    # --- view pan (D-ARCH-8): touch drag on the map; middle/right
    # drag on desktop.  A card press owns its finger first — panning
    # never steals a guest drag, and panning cancels a pending card
    # press so release can't tap it.
    if event is InputEventScreenTouch:
        return                         # taps ride the emulated mouse
    if event is InputEventScreenDrag:
        if _drag_ghost != null or not _press.is_empty():
            return                     # a card/guest owns the gesture
        s._cam = s._cam - event.relative
        s._fit_stage()
        return
    if event is InputEventMouseButton \
            and event.button_index in [MOUSE_BUTTON_MIDDLE,
                MOUSE_BUTTON_RIGHT]:
        _mb_pan = event.pressed
        return
    if event is InputEventMouseMotion:
        s._wake_chrome()
        if _mb_pan:
            s._cam = s._cam - event.relative
            s._fit_stage()
            return
        var sp: Vector2 = event.position              # viewport px (cards)
        var px: Vector2 = event.position - s.stage.position
        s._fire_near(px.distance_to(s._fire_pos) <= 56.0)
        if _build_on and not _build_item.is_empty() \
                and Game.phase == Game.Phase.PREP:
            ghost_to(px)
        if not s.evening_open:
            return                                    # night: watch the fire
        # a card press that travels >7px becomes a drag (UI-020)
        if not _press.is_empty() and _drag_ghost == null \
                and not s.hud.tray.is_seated(_press["gid"]) \
                and sp.distance_to(_press["pos"]) > s.TAP_SLOP:
            begin_drag(_press["gid"])
            _press = {}
        var pid := pad_at(px)
        var ok: bool = pid != "" \
            and st["pads"].get(pid, {}).get("open", false) == true \
            and not pad_occupied(pid) and s.selected != ""
        s.hover.visible = ok
        if ok:
            s.hover.position = s.pad_cells[pid].position
        if _drag_ghost != null:
            # §5.9: no spring to settle — round every frame so the
            # ghost keeps texel phase and sub-px pointer creep holds
            _drag_ghost.position = (px + Vector2(0, 4)).round()
        update_strip(px)
        return
    # --- tap lane (D-ARCH-8): NOTHING commits on press.  A press arms
    # a candidate tap; release inside TAP_SLOP commits it, travel past
    # slop (a pan, a card drag) eats it.  This is the platform's own
    # law — the emulated-mouse press lands before the first drag event,
    # so deferring is the only place a tap-vs-pan can be told apart.
    if event is InputEventMouseButton \
            and event.button_index == MOUSE_BUTTON_LEFT:
        # event.position IS the pointer — the canvas-transformed view
        # coord on every platform (mouse, emulated touch, synthetic
        # tests); get_global_mouse_position() can't see synthetic input
        var sp: Vector2 = event.position              # viewport px (cards)
        var mpx := sp                                 # viewport px (world)
        var px: Vector2 = mpx - s.stage.position
        s._fire_near(px.distance_to(s._fire_pos) <= 56.0)
        if event.pressed:
            _tap_armed = true
            _tap_origin = sp
            # card presses defer to release — they may become drags
            if s.evening_open:
                var card_gid: String = s.hud.tray.card_at(sp)
                if card_gid != "":
                    _press = {"gid": card_gid, "pos": sp}
            # press-time FEEDBACK stays instant: hover ring under the
            # finger, like a button highlight (commit rides release)
            if s.evening_open and s.selected != "":
                var hpid := pad_at(px)
                var hok: bool = hpid != "" \
                    and st["pads"].get(hpid, {}).get("open", false) \
                        == true and not pad_occupied(hpid)
                s.hover.visible = hok
                if hok:
                    s.hover.position = s.pad_cells[hpid].position
            return
        # release ------------------------------------------------------------
        var was_tap: bool = _tap_armed \
            and sp.distance_to(_tap_origin) <= s.TAP_SLOP
        _tap_armed = false
        if _drag_ghost != null:
            end_drag(px)
            return
        if not _press.is_empty():
            var p: Dictionary = _press
            _press = {}
            if s.hud.tray.card_at(sp) == p["gid"]:
                if s._meal_sel >= 0 \
                        and s.hud.tray.is_seated(p["gid"]):
                    serve_tap(p["gid"])     # card lane serves too
                else:
                    tap_card(p["gid"])
            return
        if was_tap:
            commit_map_tap(sp, mpx, px)
        return
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_ENTER:
            s._advance_phase()
        elif event.keycode == KEY_F1:
            s.hud.toggle_dev()


## The commit side of the tap lane — runs only on release inside
## TAP_SLOP.  Same hit-test order the old press path used: morning +
## prep answer board/hut/camp work; the evening lane answers meal
## chips, seated guests, then pad seating; night stays a spectator.


func commit_map_tap(sp: Vector2, mpx: Vector2, px: Vector2) -> void:
    var st: Dictionary = Game.site_state()
    if Game.phase in [Game.Phase.MORNING, Game.Phase.PREP]:
        # the notice board stays readable (tonight's favourites steer
        # what you gather); prep adds errand taps
        if s._board_rect.has_point(px):
            s._open_booking()
            return
        if hut_tap(px):                    # the hut answers in any phase
            return
        if Game.phase == Game.Phase.PREP:
            # build mode owns prep taps; armed ghost = every tap is a
            # drop attempt, unarmed = piece menus / errand pass
            if _build_on:
                build_tap(px)
            else:
                prep_tap(px)
        else:
            # morning: locked pads still answer taps — camp work is a
            # Prep job, said out loud instead of silence
            var mpid := pad_at(px)
            if mpid != "" and not st["pads"].get(mpid, {})\
                    .get("open", false):
                s._float_chip(s.pads_node.get_node("mark_" + mpid),
                    s.tr("bld_not_prep"), "lock")
        return
    if not s.evening_open:
        return                                        # night: watch the fire
    var mi: int = s.hud.tray.meal_at(sp)
    if mi >= 0:
        tap_meal(mi)
        return
    var gid := guest_at(mpx)
    if gid != "" and st["assignments"].has(gid):
        if s._meal_sel >= 0:
            serve_tap(gid)                  # armed meal beats unseat
        else:
            do_unseat(gid)                  # tap seated guest = undo
        return
    var pid := pad_at(px)
    if pid != "" and s.selected != "":
        try_seat(pid)
    elif hut_tap(px):               # crew sheet from the world too
        pass
    elif s._meal_sel >= 0:
        tap_meal(-1)                        # empty ground disarms


## Chrome/setup seams (called from scene-owned flows, never gesture input).
func build_armed() -> bool:
    return not _build_item.is_empty()


func build_active() -> bool:
    return _build_on


## Evening board reset: drop any pending press + free a live drag ghost.
func reset_gesture() -> void:
    _press = {}
    if _drag_ghost != null:
        _drag_ghost.queue_free()
        _drag_ghost = null


