class_name DailySheet
extends Panel
## Trail Daily (§10) — today's shared board as a read card: the seeded
## request lineup, the kit it ships with, the meals, and the share
## block once today's one scored attempt lands.  Locked until letter
## p06 arrives; the locked card still names its own unlock road.

const W := 300
const H := 262


static func make() -> DailySheet:
	var s := DailySheet.new()
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
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)
	var x := UIKit.icon_btn(self, "close")
	x.position = Vector2(W - UITokens.MIN_TOUCH - 8, 4)
	x.pressed.connect(_close)

	if not Game.daily_unlocked():
		UIKit.empty(v, "journal", tr("daily_locked"))
		return

	var pz: Dictionary = Game.daily()
	var title := UIKit.label_for(
		tr("daily_t").format({"n": int(pz.get("n", 0))}),
		UITokens.TypeRole.DISPLAY, UITokens.PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var dt := UIKit.label_for(String(pz.get("date", "")),
		UITokens.TypeRole.CAPTION, UITokens.DIM)
	dt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(dt)

	# today's attempt state
	var status := UIKit.label_for(
		tr("daily_done").format({"s": int(Game.daily_state["score"])})
			if pz.get("attempted", false) else tr("daily_open"),
		UITokens.TypeRole.BODY,
		UITokens.GOLD if pz.get("attempted", false) else UITokens.PAPER)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(status)

	# the seeded board: guest request chips + kit + meals, icon level
	_cap_row(v, tr("daily_board"))
	var reqs := HBoxContainer.new()
	reqs.alignment = BoxContainer.ALIGNMENT_CENTER
	reqs.add_theme_constant_override("separation", 4)
	v.add_child(reqs)
	for r in pz.get("requests", []):
		var chip := Panel.new()
		chip.custom_minimum_size = Vector2(0, 30)
		chip.add_theme_stylebox_override("panel",
			UIKit.flat("glass_chip"))
		var l := UIKit.label_for(String(r.get("name", "?")),
			UITokens.TypeRole.CAPTION, UITokens.PAPER)
		l.position = Vector2(6, 8)
		chip.add_child(l)
		chip.custom_minimum_size.x = l.get_theme_font("font") \
			.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT,
				-1.0, l.get_theme_font_size("font_size")).x + 12
		reqs.add_child(chip)

	_cap_row(v, tr("daily_kit"))
	var kit := HBoxContainer.new()
	kit.alignment = BoxContainer.ALIGNMENT_CENTER
	kit.add_theme_constant_override("separation", 4)
	v.add_child(kit)
	for k in pz.get("kit", []):
		var ic := Panel.new()
		ic.custom_minimum_size = Vector2(26, 26)
		ic.add_theme_stylebox_override("panel",
			UIKit.flat("glass_chip"))
		var g := UIKit.icon_rect("decor", UITokens.PAPER, 14)
		g.position = Vector2(6, 6)
		ic.add_child(g)
		var tip := String(k.get("id", ""))
		ic.tooltip_text = tip
		kit.add_child(ic)
	var meals := UIKit.label_for(
		"%d %s" % [pz.get("meals", []).size(), tr("daily_meals")],
		UITokens.TypeRole.CAPTION, UITokens.DIM)
	meals.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(meals)

	if pz.get("attempted", false):
		var cb := UIKit.btn(v, Vector2(200, UITokens.MIN_TOUCH),
			tr("daily_copy"), "pill", Control.SIZE_SHRINK_CENTER)
		cb.pressed.connect(_copy_share)


func _cap_row(v: Control, text: String) -> void:
	var c := UIKit.label_for(text, UITokens.TypeRole.CAPTION,
		UITokens.DIM)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(c)


func _copy_share() -> void:
	# the recorded attempt's share block was baked at submit time —
	# the star row can't be rebuilt without the per-guest results
	var share_text := String(Game.daily_state.get("share",
		"Trailbound Daily"))
	DisplayServer.clipboard_set(share_text)
	UIFeel.sfx("confirm")
	UIFeel.haptic("confirm")


func _close() -> void:
	var pm := get_parent() as PanelManager
	if pm:
		pm.close()
