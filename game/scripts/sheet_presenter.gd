extends RefCounted
## SheetPresenter — sheets, context menus + chips (§17.2/§17.4).
## SOTA split (D-ARCH-9/10/11/12): the scene owns panel_mgr,
## markers, pad/decor nodes and menu-token state; this owns the
## sheet opens (outfitter/booking/crew/adopt), piece/pad context
## menus, the pad clear/finish transforms, pad visual/chip sync
## and the floating/hint chips. Scene passed as untyped `s`;
## sheet locals renamed (`s` -> `sheet`); Node APIs (`tr`,
## `create_tween`, `get_tree`, `call_deferred`) route via `s`.
## Menu tokens split: `_build_menu_tok` moved here (piece menus
## own it); `_pad_menu_tok/_pid` stay on the scene (shared UI).


var s  # the pinewatch_test scene (untyped: mutual ref)

var _build_menu_tok := 0


func _init(scene) -> void:
    s = scene


func open_outfitter(tab := "gear") -> void:
    var sheet := OutfitterSheet.make(tab)
    sheet.place_requested.connect(s._on_place_requested)
    s.panel_mgr.open(sheet)


## The notice board sheet (§17.2): tonight's requests + the forecast.


func open_booking() -> void:
    var st: Dictionary = Game.site_state()
    var open_n := 0
    for pid in st["pads"]:
        if st["pads"][pid].get("open", false):
            open_n += 1
    var cooked := {}
    for r in Game.recipes_cooked:
        cooked[r] = true
    s.panel_mgr.open(BookingBoard.make(st["board"],
        String(st["weather"]), open_n, s._card_sprite, s._trait_map(),
        cooked))


func open_crew() -> void:
    s.panel_mgr.open(CrewSheet.make())


## UI-034: the trail map is a morning act (§8.2) — the verb enforces
## it; a true return reloads the scene so layout/props/anchors rebuild
## for the new site in one _ready pass.


func open_adopt() -> void:
    if Game.dog_adopted() or s.panel_mgr == null:
        return
    var cur := String(Game.dog.get("name", "Bean"))
    if TranslationServer.get_locale().begins_with("vi"):
        cur = String(Catalog.data.get("dog", {}).get("name_vi", cur))
    var sheet := AdoptSheet.make(cur)
    sheet.named.connect(on_dog_named)
    s.panel_mgr.open(sheet)


func on_dog_named(n: String) -> void:
    Game.adopt_dog(n)
    UIFeel.sfx("confirm")
    UIFeel.haptic("confirm")
    var dog: Node2D = s._actor_map.get("dog")
    if dog != null:
        float_chip(dog, String(Game.dog.get("name", "")), "heart")


## Generic row-name lookup (birds etc.) — same convention as _ing_name.


func check_dog_adoption() -> void:
    if not bool(Game.dog.get("met", false)) or Game.dog_adopted() \
            or Game.dog_level() < 2:
        return
    s.call_deferred("_open_adopt")


func open_piece_menu(idx: int) -> void:
    close_piece_menu()
    var d: Dictionary = Game.site_state()["decor"][idx]
    var tok: int = s.markers.marker(s._decor_nodes[idx], Vector2(-72, -66))
    var chip := PanelContainer.new()
    chip.add_theme_stylebox_override("panel", UIKit.flat("glass_chip"))
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 2)
    chip.add_child(h)
    var item_id := String(d["id"])
    var mv := UIKit.icon_btn(h, "edit")
    mv.tooltip_text = s.tr("bld_move")
    mv.pressed.connect(func():
        close_piece_menu()
        s._arm_build({"id": item_id, "kind": "move", "idx": idx}))
    var sb := UIKit.icon_btn(h, "box")
    sb.tooltip_text = s.tr("bld_store")
    sb.pressed.connect(func():
        if Game.store_decor(idx):
            UIFeel.sfx("close")
            close_piece_menu()
            s._sync_decor_world()
            s._build_overlay.free_cells = Game.decor_cells_free()
            s._build_overlay.queue_redraw())
    if item_id in Game.bought_today:
        var row: Dictionary = s._decor_row_for(item_id)
        var rb := UIKit.btn(h, Vector2(64, UITokens.MIN_TOUCH),
            s.tr("bld_return").format({"p": int(row.get("price", 0))}),
            "pill", Control.SIZE_SHRINK_CENTER)
        rb.tooltip_text = s.tr("bld_return")
        rb.pressed.connect(func():
            if Game.return_bought(item_id):
                UIFeel.sfx("coin")
                close_piece_menu()
                s._sync_decor_world()
                s._build_overlay.free_cells = Game.decor_cells_free()
                s._build_overlay.queue_redraw()
                s._status())
    s.markers.marker_control(tok).add_child(chip)
    _build_menu_tok = tok


func close_piece_menu() -> void:
    if _build_menu_tok != 0:
        s.markers.release(_build_menu_tok)
        _build_menu_tok = 0


func open_pad_menu(pid: String) -> void:
    close_pad_menu()
    var st: Dictionary = Game.site_state()["pads"].get(pid, {})
    var node: Node = s.pads_node.get_node_or_null("mark_" + pid)
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
                s.tr("pad_clear"), "pill", Control.SIZE_SHRINK_CENTER)
            cb.pressed.connect(func():
                close_pad_menu()
                play_clear(pid))
            n += 1
        else:
            var price := Game.pad_unlock_price(pid)
            if price >= 0:
                var ub := UIKit.btn(h, Vector2(96, UITokens.MIN_TOUCH),
                    s.tr("pad_unlock").format({"p": price}), "pill",
                    Control.SIZE_SHRINK_CENTER)
                ub.disabled = Game.coins < price
                ub.pressed.connect(func():
                    if Game.unlock_pad(pid):
                        UIFeel.sfx("coin")
                        UIFeel.haptic("medium")
                        s._status()
                        sync_pad_chips()
                        open_pad_menu(pid))   # row rebuilds: now Clear
                n += 1
    else:
        for opt in Game.pad_shelter_options(pid):
            var sh := String(opt["shelter"])
            var ob := UIKit.btn(h, Vector2(110, UITokens.MIN_TOUCH),
                s.tr("pad_shelter_" + sh).format({"p": int(opt["price"])}),
                "pill", Control.SIZE_SHRINK_CENTER)
            ob.disabled = (not opt["unlocked"]) \
                or Game.coins < int(opt["price"])
            ob.pressed.connect(func():
                if Game.upgrade_pad(pid, sh):
                    UIFeel.sfx("coin")
                    UIFeel.haptic("medium")
                    s._status()
                    sync_pad_visual(pid)
                    close_pad_menu())
            n += 1
    if n == 0:
        return
    var tok: int = s.markers.marker(node, Vector2(-50, -66))
    s.markers.marker_control(tok).add_child(chip)
    s._pad_menu_tok = tok
    s._pad_menu_pid = pid
    UIFeel.pop(chip)


func close_pad_menu() -> void:
    if s._pad_menu_tok != 0:
        s.markers.release(s._pad_menu_tok)
        s._pad_menu_tok = 0
    s._pad_menu_pid = ""


## Paid pad -> the clear transform is the reward: weeds and leaf litter
## scatter off, the pad brightens, then clear_pad lands the state and
## the open texture swaps in.  Skipped shells under reduced motion.


func play_clear(pid: String) -> void:
    s._pad_clearing[pid] = true
    sync_pad_chips()
    var spr: Node = s.pads_node.get_node_or_null("mark_" + pid)
    var tuft: Node = s.pads_node.get_node_or_null("tuft_" + pid)
    var gnd: Node = s.pads_node.get_node_or_null("ground_" + pid)
    var r: Rect2 = s.pad_cells[pid]
    if UIFeel.reduced_motion:
        if tuft != null:
            tuft.queue_free()
        finish_clear(pid)
        return
    var litter := ["decal_fern_frond", "decal_leaf_single", "decal_twig"]
    for i in 3:
        var d: Sprite2D = s._anchored("decals", litter[i],
            r.position + Vector2(10 + i * 20, 28 + (i % 2) * 14))
        s.pads_node.add_child(d)
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
        var tw2: Tween = tuft.create_tween()
        tw2.set_parallel()
        tw2.tween_property(tuft, "rotation_degrees", 200.0, 0.55)
        tw2.tween_property(tuft, "scale", Vector2.ZERO, 0.55)
        tw2.tween_property(tuft, "modulate:a", 0.0, 0.55)
        tw2.finished.connect(tuft.queue_free)
    if gnd != null:
        # the overgrown plot shrinks into the earth — _finish_clear
        # resurfaces it as the packed pitch tile
        var twg: Tween = gnd.create_tween()
        twg.set_parallel()
        twg.tween_property(gnd, "rotation_degrees", 120.0, 0.55)
        twg.tween_property(gnd, "scale", Vector2.ZERO, 0.55)
        twg.tween_property(gnd, "modulate:a", 0.0, 0.55)
    if spr != null:
        var tw3: Tween = spr.create_tween()
        tw3.tween_property(spr, "modulate",
            Color(1.35, 1.3, 1.1), 0.25).set_delay(0.3)
    s.get_tree().create_timer(0.58).timeout.connect(
        finish_clear.bind(pid))


func finish_clear(pid: String) -> void:
    if Game.clear_pad(pid):
        UIFeel.sfx("confirm")
        UIFeel.haptic("medium")
    sync_pad_visual(pid)
    var spr: Node = s.pads_node.get_node_or_null("mark_" + pid)
    if spr != null:
        spr.modulate = Color.WHITE
        UIFeel.pop(spr, Vector2(1.15, 0.85))
    s._pad_clearing.erase(pid)
    sync_pad_chips()


func sync_pad_visual(pid: String) -> void:
    var st: Dictionary = Game.site_state()["pads"].get(pid, {})
    var spr: Sprite2D = s.pads_node.get_node_or_null("mark_" + pid)
    if spr == null:
        return
    spr.texture = s._tex("pad_open" if st.get("open", false) \
        else "pad_locked")
    # ground tile: open pads sit on packed pitch earth.  The clear
    # scatter shrinks the overgrown tile away; this resurfaces it in
    # its cleared outfit (the marker pop carries the beat — pop
    # tweens to scale 1.0 which would break a shrunken decal).
    var gnd: Sprite2D = s.pads_node.get_node_or_null("ground_" + pid)
    if gnd != null and st.get("open", false):
        gnd.texture = s._tex("decals/pad_cleared")
        gnd.rotation = 0.0
        gnd.modulate.a = 1.0
        gnd.scale = Vector2.ONE * float(gnd.get_meta("s0", 1.0))
    var shelter := String(st.get("shelter", "bare"))
    if shelter == "bare" or s._pad_shelters.has(pid):
        return
    var ov: Sprite2D = s._anchored("props_medium" if shelter == "platform" \
        else "props_large",
        "pallet_deck" if shelter == "platform" else "cottage_shed",
        s.pad_cells[pid].position + Vector2(s.CELL / 2.0, s.CELL))
    ov.set_meta("shelter", shelter)           # night swap reads this
    var w := ov.texture.get_width() * ov.scale.x
    if w > s.CELL * 1.05:                      # pad furniture, not a prop
        ov.scale *= s.CELL * 1.05 / w
    s.pads_node.add_child(ov)                  # under tents when seated
    s._pad_shelters[pid] = ov


## PREP affordances on pads that still need work: muted lock while
## locked, accent hand once it's paid-and-waiting.


func sync_pad_chips() -> void:
    for tok in s._pad_chips.values():
        s.markers.release(int(tok))
    s._pad_chips = {}
    if Game.phase != Game.Phase.PREP:
        return
    var pads: Dictionary = Game.site_state()["pads"]
    for pid in s.pad_cells:
        var st: Dictionary = pads.get(pid, {})
        if st.get("open", false) or s._pad_clearing.has(pid):
            continue
        var node: Node = s.pads_node.get_node_or_null("mark_" + pid)
        if node == null:
            continue
        var paid: bool = st.get("paid", false)
        var pair: Array = s.markers.icon_chip(node,
            UIKit.icon_rect("hand" if paid else "lock",
                UITokens.GOLD if paid else UITokens.MUTE, 12),
            Vector2(s.CELL / 2.0 - 9, -26))
        s._pad_chips[pid] = pair[0]


## Tap on a pad -> context row: locked sells the unlock, paid offers
## Clear, open+bare lists shelter upgrades.  Nothing actionable -> no
## menu (the tap falls through to a dismiss).


func float_chip(anchor: Node2D, text: String, icon := "") -> void:
    var tok: int = s.markers.marker(anchor, Vector2(-40, -48))
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
    var host: Control = s.markers.marker_control(tok)
    host.add_child(chip)
    chip.resized.connect(func():
        chip.position.x = -chip.size.x / 2.0   # centre once measured
        chip.pivot_offset = chip.size / 2.0)   # and pop around centre
    UIFeel.pop(chip)
    var tw: Tween = s.create_tween()
    tw.tween_interval(0.75)
    UIFeel.apply(tw, "veil_out")
    tw.tween_property(chip, "modulate:a", 0.0, UIFeel.dur("veil_out"))
    tw.tween_callback(func(): s.markers.release(tok))


func hud_hint(text: String) -> void:
    var chip := PanelContainer.new()
    chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    chip.add_theme_stylebox_override("panel", UIKit.flat("glass_chip"))
    chip.add_child(UIKit.label_for(text, UITokens.TypeRole.CAPTION,
        UITokens.PAPER))
    chip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    chip.position.y -= UITokens.MIN_TOUCH + 24
    s.hud_layer.add_child(chip)
    UIFeel.pop(chip)
    var tw: Tween = s.create_tween()
    tw.tween_interval(0.9)
    UIFeel.apply(tw, "veil_out")
    tw.tween_property(chip, "modulate:a", 0.0, UIFeel.dur("veil_out"))
    tw.tween_callback(chip.queue_free)


## Hand-off from the outfitter's Place button: sheet closes, PREP arms.


func gain_text(items: Array) -> String:
    var counts := {}
    for i in items:
        var k := String(i)
        counts[k] = int(counts.get(k, 0)) + 1
    var parts := []
    for k in counts:
        parts.append("+%d %s" % [counts[k], ing_name(k)])
    return "  ".join(parts)


func ing_name(item_id: String) -> String:
    for r in Catalog.data.get("ingredients", []):
        if r.get("id") == item_id:
            return String(r.get("name", item_id))
    return item_id


## "+2 Berries" — per-kind counts, ingredient names match the pantry.


