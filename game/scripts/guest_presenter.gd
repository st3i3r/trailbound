extends RefCounted
## GuestPresenter — seating visuals + trait bubbles (UI-020/021).
## SOTA split (D-ARCH-9/10/11): the scene owns guest/tent/bubble
## nodes + tray/markers; this owns seat/unseat visuals, bubble
## refresh/fill/clear and pad-mark sync. Scene passed as untyped
## `s`; the only local renamed is _seat_visual's sprite
## (`s` -> `spr`). All guest state stays on the scene (smoke
## reads `guest_bubbles`); pad occupancy reads `s._pad_occupied`.


var s  # the pinewatch_test scene (untyped: mutual ref)


func _init(scene) -> void:
    s = scene


func seat_visual(gid: String, pads: Array) -> void:
    var st: Dictionary = Game.site_state()
    var arch: String = st["guests"][gid].get("archetype", "")
    # a fresh world sprite joins the y-sort — feet just under the pad's
    # bottom edge so it sorts in front of the tent
    var g := Node2D.new()
    g.name = "w_" + gid
    # the seat sprite IS the evening cast face — persona_key picks
    # identically on both sides; ungenerated personas fall back to the
    # tinted stand-in
    var pk := SimDirector.persona_key(gid, arch, s._cast_seed(),
        s._actors_data())
    var spr: Sprite2D
    if pk != "" and ResourceLoader.exists(
            s.A + "characters/%s/%s_south.png" % [pk, pk]):
        spr = s._anchored("characters/" + pk, pk + "_south", Vector2.ZERO)
    else:
        spr = s._anchored("characters/warden", "warden_south", Vector2.ZERO)
        spr.modulate = s._tint(st["guests"][gid])
    g.add_child(spr)
    g.position = s.pad_cells[pads[0]].position + Vector2(12, s.CELL + 4)
    s.world.add_child(g)
    s.guest_nodes[gid] = g
    UIFeel.pop(g, Vector2(1.12, 0.85))   # landing squash — seats thud
    s.tent_nodes[gid] = []
    var idx := absi(hash(gid + arch) as int)
    for pid in pads:
        var tk: String = s.TENTS[idx % s.TENTS.size()]
        var t: Sprite2D = s._anchored("props_medium", tk, Vector2.ZERO)
        t.set_meta("tent_key", tk)      # night swap reads this
        idx += 1
        var r: Rect2 = s.pad_cells[pid]
        t.position = r.position + Vector2(s.CELL / 2.0, s.CELL)
        s.world.add_child(t)
        s.tent_nodes[gid].append(t)
    s.hud.tray.mark_seated(gid)
    refresh_bubbles()
    sync_marks()
    s._sync_night_props()                        # evening arrival = lit
    s._recast_if_evening()                       # the new guest walks in


func unseat_visual(gid: String) -> void:
    if s.guest_nodes.has(gid):
        s.guest_nodes[gid].queue_free()
        s.guest_nodes.erase(gid)
    for t in s.tent_nodes.get(gid, []):
        t.queue_free()
    s.tent_nodes[gid] = []
    s._sync_night_props()                        # freed pads go dark
    if s.guest_bubbles.has(gid):
        s.markers.release(s.guest_bubbles[gid])
        s.guest_bubbles.erase(gid)
    s._clear_served_mark(gid)                  # their plate goes back
    s.hud.tray.mark_unseated(gid)
    refresh_bubbles()
    sync_marks()
    s._recast_if_evening()


## UI-021: trait-state bubbles over seated guests.  Every trait gets a
## state glyph — "+" met, "−" tripped, "·" unresolved — never colour
## alone; the same sign vocabulary the breakdown strip uses before
## seating.  States come from the real resolve_guest detail, and every
## seat/unseat re-evaluates ALL seated guests because neighbour effects
## move other people's states (social fills, loud trips light_sleeper).


func bubble_state(d: Dictionary) -> Dictionary:
    if d.get("tripped", false):
        return {"sign": "−", "color": UITokens.RED}
    if d.get("met", false):
        return {"sign": "+", "color": UITokens.GREEN}
    return {"sign": "·", "color": UITokens.DIM}


func refresh_bubbles() -> void:
    var st: Dictionary = Game.site_state()
    for gid in st["assignments"]:
        var r := Game.preview(gid, st["assignments"][gid])
        if r.is_empty():
            continue
        var control: Control = null
        if s.guest_bubbles.has(gid):
            control = s.markers.marker_control(s.guest_bubbles[gid])
            if not is_instance_valid(control):
                control = null
        if control == null:
            var g: Node2D = s.guest_nodes.get(gid)
            if g == null:
                continue
            var anchor := Node2D.new()
            anchor.position = Vector2(0, -80)   # above the sprite's head
            g.add_child(anchor)
            s.guest_bubbles[gid] = s.markers.marker(anchor,
                Vector2(-40, 0))
            control = s.markers.marker_control(s.guest_bubbles[gid])
        fill_bubble(control, r["detail"])


## Rebuild one bubble's chips: trait icons in a slot-dark tag, each
## carrying its state sign on the lower edge.


func fill_bubble(control: Control, detail: Array) -> void:
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
        var st := bubble_state(d)
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


func clear_bubbles() -> void:
    for tok in s.guest_bubbles.values():
        s.markers.release(tok)
    s.guest_bubbles = {}
    for tok in s._served_marks.values():       # plates share the lifetime
        s.markers.release(int(tok))
    s._served_marks = {}


## §5.5 dinner: a meal chip toggles the arm; armed, a seated guest tap
## (world sprite or seated card) serves the plate.  Serving the same
## dish again takes it back.


func sync_marks() -> void:
    var st: Dictionary = Game.site_state()
    for pid in s.pad_cells:
        var mark: Node = s.pads_node.get_node_or_null("mark_" + pid)
        if mark:
            mark.visible = st["pads"].get(pid, {}).get("open", false) \
                and not s._pad_occupied(pid)


## Pads a guest would take starting at pid — one, or pid plus its
## first free neighbour for a two-pad party.


