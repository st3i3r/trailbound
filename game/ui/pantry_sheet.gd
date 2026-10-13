class_name PantrySheet
extends Panel
## Pantry + cook pot (UI-031, §7.4/§7.5) — the day-phase prep surface.
## The ingredient grid reads Game.pantry; tap two chips to load the
## pot, COOK calls Game.cook() and reports ok/oven_hint/missing with
## the semantic sfx.  Tonight's menu strip lists Game.meals — what the
## guests will actually be served.
##
## Ingredient art is per-kind glyph for now (leaf/fish/box); real I1
## dish art is the Batch F follow-up, the slots keep a fixed 16px.

const W := 320
const H := 300

## ingredient kind -> registry glyph
const KIND_ICON := {"forage": "leaf", "fish": "fish", "staple": "box"}

var _v: VBoxContainer
var _slot_a := ""
var _slot_b := ""
var _res_text := ""
var _res_tint: Color = UITokens.PAPER


static func make() -> PantrySheet:
	var s := PantrySheet.new()
	s._build()
	return s


func _ready() -> void:
	position = (get_viewport_rect().size - size) / 2.0


func _build() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	add_theme_stylebox_override("panel", UIKit.flat("sheet"))
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_top", 5)
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_bottom", 12)
	add_child(m)
	_v = VBoxContainer.new()
	_v.add_theme_constant_override("separation", 5)
	m.add_child(_v)
	var x := UIKit.icon_btn(self, "close")
	x.position = Vector2(W - UITokens.MIN_TOUCH - 8, 4)
	x.pressed.connect(_close)
	_rebuild()


func _close() -> void:
	var pm := get_parent() as PanelManager
	if pm:
		pm.close()


func _rebuild() -> void:
	for c in _v.get_children():
		c.queue_free()
	_build_main()


func _build_main() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_v.add_child(head)
	var title := UIKit.label_for(tr("pan_t_pantry"),
		UITokens.TypeRole.HEAD, UITokens.PAPER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var cap := UIKit.label_for(tr("pan_capacity").format(
		{"n": Game.pantry_count(), "m": Game.pantry_capacity()}),
		UITokens.TypeRole.CAPTION, UITokens.DIM)
	head.add_child(cap)

	# --- ingredient grid: one chip per stocked item, 4 wide
	if Game.pantry.is_empty():
		UIKit.empty(_v, "pantry", tr("pan_empty"))
	else:
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		_v.add_child(grid)
		for item_id in Game.pantry:
			grid.add_child(_ing_chip(String(item_id),
				int(Game.pantry[item_id])))

	# --- the pot: two slots + COOK
	var pot := HBoxContainer.new()
	pot.alignment = BoxContainer.ALIGNMENT_CENTER
	pot.add_theme_constant_override("separation", 6)
	_v.add_child(pot)
	var sa := _slot_chip(pot, _slot_a)
	var sb := _slot_chip(pot, _slot_b)
	var cook := UIKit.btn(pot, Vector2(96, UITokens.MIN_TOUCH),
		tr("pan_cook"), "gold", Control.SIZE_SHRINK_CENTER)
	cook.set_meta("ui_primary", true)
	cook.pressed.connect(_on_cook)
	sa.pressed.connect(func(): _slot_a = ""; _rebuild())
	sb.pressed.connect(func(): _slot_b = ""; _rebuild())

	# --- result + tonight's menu (result text survives rebuilds —
	# the cook outcome paints into the fresh layout)
	var res := UIKit.label_for(_res_text, UITokens.TypeRole.BODY,
		_res_tint)
	res.name = "Result"
	res.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_v.add_child(res)

	_v.add_child(_meal_strip())

	var known := 0
	for k in Game.pairs_tried:
		if String(Game.pairs_tried[k]) not in ["oven_hint"]:
			known += 1
	var foot := UIKit.label_for(
		tr("pan_known").format({"n": known}),
		UITokens.TypeRole.CAPTION, UITokens.DIM)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_v.add_child(foot)


func _ing_chip(item_id: String, count: int) -> Control:
	var row: Array = Catalog.data.get("ingredients", [])
	var kind := "staple"
	var dname := item_id
	for r in row:
		if r.get("id") == item_id:
			kind = r.get("kind", kind)
			dname = r.get("name", item_id)
			break
	var b := Button.new()
	b.custom_minimum_size = Vector2(68, 40)
	b.add_theme_stylebox_override("normal", UIKit.flat("glass_chip"))
	b.add_theme_stylebox_override("hover",
		UIKit.flat("glass_chip", 1.08))
	b.add_theme_stylebox_override("pressed",
		UIKit.flat("glass_chip", 0.82))
	b.add_theme_stylebox_override("focus", UIKit.focus_box())
	# picked slots get the glow ring so selection reads at a glance
	if item_id == _slot_a or item_id == _slot_b:
		b.add_theme_stylebox_override("normal",
			UIKit.flat("sel_glow"))
	UIKit.pressable(b)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 3)
	h.add_child(UIKit.icon_rect(
		KIND_ICON.get(kind, "box"), UITokens.DIM, 16))
	var nl := UIKit.label_for("%s ×%d" % [dname, count],
		UITokens.TypeRole.CAPTION, UITokens.PAPER)
	nl.clip_text = true
	h.add_child(nl)
	b.add_child(h)
	b.pressed.connect(func(): _pick(item_id))
	return b


func _slot_chip(parent: Control, item_id: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(64, UITokens.MIN_TOUCH)
	b.add_theme_stylebox_override("normal", UIKit.flat("glass_chip"))
	b.add_theme_stylebox_override("hover", UIKit.flat("glass_chip", 1.08))
	b.add_theme_stylebox_override("pressed",
		UIKit.flat("glass_chip", 0.82))
	b.add_theme_stylebox_override("focus", UIKit.focus_box())
	UIKit.pressable(b)
	var l := UIKit.label_for(
		_ing_name(item_id) if item_id != "" else "—",
		UITokens.TypeRole.CAPTION,
		UITokens.PAPER if item_id != "" else UITokens.DIM)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	b.add_child(l)
	parent.add_child(b)
	return b


func _ing_name(item_id: String) -> String:
	var row: Array = Catalog.data.get("ingredients", [])
	for r in row:
		if r.get("id") == item_id:
			return String(r.get("name", item_id))
	return item_id


func _pick(item_id: String) -> void:
	if _slot_a == "" or item_id == _slot_a:
		_slot_a = item_id
	elif _slot_b == "" or item_id == _slot_b:
		_slot_b = item_id
	else:
		_slot_b = item_id          # third tap rolls B over
	UIFeel.sfx("press")
	_rebuild()


func _on_cook() -> void:
	if _slot_a == "" or _slot_b == "":
		_res_text = tr("pan_pick")
		_res_tint = UITokens.DIM
		UIFeel.sfx("warn")
		_rebuild()
		return
	var r := Game.cook(_slot_a, _slot_b)
	match String(r.get("result", "")):
		"ok":
			UIFeel.sfx("stamp")
			UIFeel.haptic("confirm")
			_res_text = tr("pan_res_ok").format(
				{"name": r.get("name", "?"),
				 "p": int(r.get("meal", {}).get("price", 0))})
			_res_tint = UITokens.GREEN
			_slot_a = ""
			_slot_b = ""
		"oven_hint":
			UIFeel.sfx("warn")
			_res_text = String(r.get("hint", ""))
			_res_tint = UITokens.GOLD
		_:                                   # "missing"
			UIFeel.sfx("warn")
			UIFeel.haptic("warn")
			_res_text = tr("pan_res_missing").format(
				{"name": _ing_name(String(r.get("missing", "?")))})
			_res_tint = UITokens.RED
	_rebuild()


func _meal_strip() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var cap := UIKit.label_for(tr("pan_today"), UITokens.TypeRole.CAPTION,
		UITokens.DIM)
	box.add_child(cap)
	if Game.meals.is_empty():
		var none := UIKit.label_for(tr("pan_meals_none"),
			UITokens.TypeRole.CAPTION, UITokens.DIM)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(none)
		return box
	# group by dish: "Trail Stew ×2"
	var counts := {}
	for meal in Game.meals:
		counts[meal["id"]] = int(counts.get(meal["id"], 0)) + 1
	var names := {}
	for r in Catalog.data.get("recipes", []):
		names[r["id"]] = r.get("name", r["id"])
	var parts := []
	for rid in counts:
		parts.append("%s ×%d" % [names.get(rid, rid), counts[rid]])
	var l := UIKit.label_for("  ·  ".join(parts),
		UITokens.TypeRole.BODY, UITokens.PAPER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	return box
