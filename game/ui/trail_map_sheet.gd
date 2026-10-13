class_name TrailMapSheet
extends Panel
## Trail map (UI-034, §8.2) — the three campgrounds as chapter cards.
## Each row reads its Game.site_card(): name, journal pages collected,
## a "here" pin on the current site, a lock + its unlock road on the
## rest.  Travel is a morning act (§8.2): the row shows the real gate —
## disabled with the reason outside MORNING rather than silently doing
## nothing.  Travel lands through travel_requested -> the scene runs
## the verb and reloads; this sheet stays pure UI.

signal travel_requested(site: StringName)

const W := 300
const H := 236


static func make() -> TrailMapSheet:
	var s := TrailMapSheet.new()
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

	var title := UIKit.label_for(tr("map_t_sheet"),
		UITokens.TypeRole.DISPLAY, UITokens.PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	for sid in Game.site_order():
		v.add_child(_site_card(Game.site_card(sid)))

	if Game.phase != Game.Phase.MORNING:
		var hint := UIKit.label_for(tr("map_morning"),
			UITokens.TypeRole.CAPTION, UITokens.DIM)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(hint)


func _site_card(c: Dictionary) -> Control:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(0, 54)
	card.add_theme_stylebox_override("panel", UIKit.flat("glass_chip"))
	var pin := UIKit.icon_rect("map_pin",
		UITokens.GOLD if c["current"] else UITokens.DIM)
	pin.position = Vector2(8, 10)
	card.add_child(pin)
	var nm := UIKit.label_for(_site_name(c),
		UITokens.TypeRole.HEAD, UITokens.PAPER)
	nm.position = Vector2(30, 7)
	nm.size = Vector2(160, 16)
	nm.clip_text = true
	card.add_child(nm)
	var sub := UIKit.label_for(tr("map_pages").format(
		{"n": c["pages_done"], "t": c["pages_total"]}),
		UITokens.TypeRole.CAPTION, UITokens.DIM)
	sub.position = Vector2(30, 26)
	card.add_child(sub)

	var bx := W - 28 - 88                    # right-edge action column
	if c["current"]:
		var here := UIKit.label_for(tr("map_here"),
			UITokens.TypeRole.CAPTION, UITokens.GOLD)
		here.position = Vector2(bx, 20)
		here.size = Vector2(84, 14)
		here.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		card.add_child(here)
	elif c["reachable"]:
		var tb := UIKit.btn(card, Vector2(84, UITokens.MIN_TOUCH),
			tr("map_travel"), "gold")
		tb.position = Vector2(bx, 5)
		tb.disabled = Game.phase != Game.Phase.MORNING
		tb.set_meta("ui_primary", true)
		var sid: StringName = c["id"]
		tb.pressed.connect(func(): travel_requested.emit(sid))
	elif not c["visited"]:
		var lock := UIKit.label_for(
			tr("map_locked").format({"site": _prev_site_name(c)}),
			UITokens.TypeRole.CAPTION, UITokens.MUTE)
		lock.position = Vector2(30, 40)
		lock.size = Vector2(230, 12)
		lock.clip_text = true
		card.add_child(lock)
	return card


## The chapter road: locked rows name the previous site's journal —
## the player always sees the next road, never a dead end.
func _prev_site_name(c: Dictionary) -> String:
	var order: Array = Game.site_order()
	var i := order.find(c["id"])
	if i <= 0:
		return ""
	return _site_name(Game.site_card(order[i - 1]))


func _site_name(c: Dictionary) -> String:
	var key := "site_" + String(c["id"])
	var t := tr(key)
	return t if t != key else String(c["name"])


func _close() -> void:
	var pm := get_parent() as PanelManager
	if pm:
		pm.close()
