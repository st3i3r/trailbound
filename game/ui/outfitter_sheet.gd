class_name OutfitterSheet
extends Panel
## Outfitter (UI-032, §6.7) — the supply crate.  Two tabs: Gear is
## one-time kit (rod/binocs/cooler/oven) gated by the unlock ladder;
## Staples are repeatable pantry goods.  Locked rows show their
## requirement instead of hiding — the sheet advertises the road ahead.
## Decor placement lives in build mode (UI-033); this sheet is buy-only.

const W := 320
const H := 300

## Emitted by Place rows — the scene closes the sheet and arms build
## mode (buy-on-place; from_stored skips the charge via place_stored).
signal place_requested(item_id: String, from_stored: bool)

## gear id -> objects icon (Batch E painterly 32px; rod/bins keep
## their authored 16px sprites — both centre in the 32px slot)
const GEAR_ICON := {"fishing_rod": "fishing_rod",
    "binoculars": "binoculars", "cooler": "cooler", "oven": "dutch_oven"}
## gear effect -> blurbs (what buying actually unlocks in the world)
const EFF_KEY := {"fishing": "shop_eff_fishing",
    "lookout": "shop_eff_lookout", "meals": "shop_eff_meals",
    "oven_recipes": "shop_eff_oven"}
## decor effect -> registry glyph for the row (the value, not the look)
const DECOR_ICON := {"seats": "users", "light": "lantern",
    "nature": "leaf", "cover": "umbrella", "privacy": "eye_off",
    "dog": "dog", "music": "music", "play": "kite",
    "stars": "star_full", "warmth_upgrade": "fire", "none": "sparkle"}
## decor effect -> blurb key (shared with the build ghost's hint chip)
const DECOR_EFF := {"seats": "eff_seats", "light": "eff_light",
    "nature": "eff_nature", "cover": "eff_cover",
    "privacy": "eff_privacy", "dog": "eff_dog", "music": "eff_music",
    "play": "eff_play", "stars": "eff_stars",
    "warmth_upgrade": "eff_warm", "none": "eff_none"}
const TABS := [["gear", "shop_tab_gear"], ["staples", "shop_tab_staples"],
    ["decor", "shop_tab_decor"]]

var _v: VBoxContainer
var _tab := "gear"
var _tab_btns := {}


static func make(tab := "gear") -> OutfitterSheet:
	var s := OutfitterSheet.new()
	s._tab = tab
	s._build()
	return s


## One-line effect summary — "light · reach 1", "+2 seats".  Static so
## the build ghost's hint chip says the same words the shelf does —
## TranslationServer.translate is the static-safe form of tr().
static func effect_text(row: Dictionary) -> String:
	var n := int(row.get("reach", 0))
	if String(row.get("effect", "")) == "seats":
		n = int(row.get("seats", 0))
	var key := String(DECOR_EFF.get(row.get("effect", ""), "eff_none"))
	return String(TranslationServer.translate(key)).format({"n": n})


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
	_tab_btns = {}
	_build_main()


func _build_main() -> void:
	# --- header: title + wallet
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_v.add_child(head)
	var title := UIKit.label_for(tr("shop_t"),
		UITokens.TypeRole.HEAD, UITokens.PAPER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UIKit.icon_rect("coin", UITokens.GOLD, 12))
	head.add_child(UIKit.label_for(str(Game.coins),
		UITokens.TypeRole.BODY, UITokens.GOLD))

	# --- tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	_v.add_child(tabs)
	for spec in TABS:
		var b := UIKit.btn(tabs, Vector2(110, 30), tr(spec[1]), "pill",
			Control.SIZE_SHRINK_CENTER)
		b.toggle_mode = true
		b.button_pressed = (_tab == spec[0])
		b.add_theme_stylebox_override("normal",
			UIKit.flat("glass_chip", 1.2) if _tab == spec[0]
			else StyleBoxEmpty.new())
		b.pressed.connect(func():
			_tab = spec[0]
			UIFeel.sfx("press")
			_rebuild())
		_tab_btns[spec[0]] = b

	# --- list (scrolls; staples outgrow the frame)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	if _tab == "gear":
		_build_gear(list)
	elif _tab == "staples":
		_build_staples(list)
	else:
		_build_decor(list)


func _build_gear(list: Control) -> void:
	for row in Catalog.data.get("gear", []):
		list.add_child(_gear_row(row))


func _build_staples(list: Control) -> void:
	var cap := UIKit.label_for(tr("pan_capacity").format(
		{"n": Game.pantry_count(), "m": Game.pantry_capacity()}),
		UITokens.TypeRole.CAPTION, UITokens.DIM)
	list.add_child(cap)
	for row in Catalog.data.get("ingredients", []):
		if row.get("kind") == "staple":
			list.add_child(_staple_row(row))


## Gear row: glyph + name/effect, right edge is the state — owned ✓,
## locked 🔒+requirement, else the price button (dim when broke).
func _gear_row(row: Dictionary) -> Control:
	var item_id := String(row.get("id", ""))
	var price := int(row.get("price", 0))
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 40)
	h.add_theme_constant_override("separation", 8)
	var ic := UIKit.icon_rect(GEAR_ICON.get(item_id, "tools"),
		null, 32)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	mid.add_child(UIKit.label_for(String(row.get("name", item_id)),
		UITokens.TypeRole.BODY, UITokens.PAPER))
	var eff := String(EFF_KEY.get(row.get("effect", ""), ""))
	mid.add_child(UIKit.label_for(tr(eff) if eff != "" else "",
		UITokens.TypeRole.CAPTION, UITokens.DIM))
	h.add_child(mid)
	if item_id in Game.gear:
		h.add_child(_state(tr("shop_owned"), "check", UITokens.GREEN))
	elif not Game.is_unlocked(String(row.get("unlock", ""))):
		h.add_child(_state(_unlock_req(String(row.get("unlock", ""))),
			"lock", UITokens.DIM))
	else:
		var b := UIKit.btn(h, Vector2(74, 30),
			"%dc" % price, "gold", Control.SIZE_SHRINK_END)
		b.disabled = Game.coins < price
		b.pressed.connect(func(): _buy_gear(item_id))
	return h


## Staple row: name + owned count, right edge price or pantry-full.
func _staple_row(row: Dictionary) -> Control:
	var item_id := String(row.get("id", ""))
	var price := int(row.get("price", 5))
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 34)
	h.add_theme_constant_override("separation", 8)
	var ic := UIKit.icon_rect("box", UITokens.DIM, 14)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	mid.add_child(UIKit.label_for(String(row.get("name", item_id)),
		UITokens.TypeRole.BODY, UITokens.PAPER))
	var have := int(Game.pantry.get(item_id, 0))
	if have > 0:
		mid.add_child(UIKit.label_for(
			tr("shop_have").format({"n": have}),
			UITokens.TypeRole.CAPTION, UITokens.DIM))
	h.add_child(mid)
	if not Game.is_unlocked(String(row.get("unlock", ""))):
		h.add_child(_state(_unlock_req(String(row.get("unlock", ""))),
			"lock", UITokens.DIM))
	elif Game.pantry_count() >= Game.pantry_capacity():
		h.add_child(_state(tr("shop_full"), "box", UITokens.DIM))
	else:
		var b := UIKit.btn(h, Vector2(60, 30),
			"%dc" % price, "gold", Control.SIZE_SHRINK_END)
		b.disabled = Game.coins < price
		b.pressed.connect(func(): _buy_staple(item_id))
	return h


## Right-edge state chip: glyph + caption, no button.
func _state(text: String, icon: String, tint: Color) -> Control:
	var s := HBoxContainer.new()
	s.alignment = BoxContainer.ALIGNMENT_END
	s.add_theme_constant_override("separation", 4)
	var ic := UIKit.icon_rect(icon, tint, 12)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.add_child(ic)
	var l := UIKit.label_for(text, UITokens.TypeRole.CAPTION, tint)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.add_child(l)
	return s


## Humanized unlock code: W0/L0 = reach the site; Pn/Wn/Ln = page done.
func _unlock_req(unlock: String) -> String:
	if unlock.begins_with("S:"):
		return tr("shop_lock_story")
	var sites := {"P": "pinewatch", "W": "whisper_river",
		"L": "lantern_valley"}
	var site := _site_name(sites.get(unlock.left(1), ""))
	var n := int(unlock.substr(1))
	if n == 0:
		return tr("shop_lock_reach").format({"site": site})
	return tr("shop_lock_page").format({"site": site, "n": n})


## Decor tab (UI-033 handoff): stored pieces place free, catalog rows
## arm build mode — the charge lands on placement, refundable until
## Goodnight.  The campfire-size row is a ring upgrade, not a piece:
## it buys straight through.
func _build_decor(list: Control) -> void:
	var stored: Array = Game.site_state()["stored"]
	if not stored.is_empty():
		list.add_child(UIKit.label_for(tr("shop_stored"),
			UITokens.TypeRole.CAPTION, UITokens.DIM))
		for d in stored:
			list.add_child(_stored_row(String(d.get("id", ""))))
	for row in Catalog.data.get("decor", []):
		list.add_child(_decor_row(row))


func _stored_row(item_id: String) -> Control:
	var row := _decor_row_for(item_id)
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 34)
	h.add_theme_constant_override("separation", 8)
	var ic := UIKit.icon_rect(
		String(DECOR_ICON.get(row.get("effect", ""), "sparkle")),
		UITokens.PAPER, 14)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(UIKit.label_for(String(row.get("name", item_id)),
		UITokens.TypeRole.BODY, UITokens.PAPER))
	mid.add_child(UIKit.label_for(effect_text(row),
		UITokens.TypeRole.CAPTION, UITokens.DIM))
	h.add_child(mid)
	# a piece bought today and packed away can still be refunded
	if item_id in Game.bought_today:
		var rb := UIKit.btn(h, Vector2(74, 30),
			tr("shop_back").format({"p": int(row.get("price", 0))}),
			"pill", Control.SIZE_SHRINK_END)
		rb.pressed.connect(func():
			if Game.return_bought(item_id):
				UIFeel.sfx("coin")
				_rebuild())
		return h
	var b := UIKit.btn(h, Vector2(74, 30), tr("shop_place_free"),
		"gold", Control.SIZE_SHRINK_END)
	b.pressed.connect(func(): place_requested.emit(item_id, true))
	return h


func _decor_row(row: Dictionary) -> Control:
	var item_id := String(row.get("id", ""))
	var price := int(row.get("price", 0))
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 40)
	h.add_theme_constant_override("separation", 8)
	var ic := UIKit.icon_rect(
		String(DECOR_ICON.get(row.get("effect", ""), "sparkle")),
		UITokens.PAPER, 16)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	mid.add_child(UIKit.label_for(String(row.get("name", item_id)),
		UITokens.TypeRole.BODY, UITokens.PAPER))
	mid.add_child(UIKit.label_for(effect_text(row),
		UITokens.TypeRole.CAPTION, UITokens.DIM))
	h.add_child(mid)
	var campfire := String(row.get("size", "")) == "campfire"
	if campfire and Game.fire_pit_upgraded():
		h.add_child(_state(tr("shop_owned"), "check", UITokens.GREEN))
	elif not Game.is_unlocked(String(row.get("unlock", ""))):
		h.add_child(_state(_unlock_req(String(row.get("unlock", ""))),
			"lock", UITokens.DIM))
	elif campfire:
		var ub := UIKit.btn(h, Vector2(110, 30),
			tr("shop_upgrade").format({"p": price}),
			"gold", Control.SIZE_SHRINK_END)
		ub.disabled = Game.coins < price
		ub.pressed.connect(func():
			if Game.buy_decor(item_id, []):
				UIFeel.sfx("pay")
				UIFeel.haptic("pay")
				_rebuild())
	else:
		var b := UIKit.btn(h, Vector2(110, 30),
			tr("shop_place_free") if price == 0 else
				tr("shop_place").format({"p": price}),
			"gold", Control.SIZE_SHRINK_END)
		# placement is a Prep job — the button rests otherwise
		b.disabled = Game.coins < price \
			or Game.phase != Game.Phase.PREP
		b.pressed.connect(func(): place_requested.emit(item_id, false))
	return h


func _decor_row_for(item_id: String) -> Dictionary:
	for r in Catalog.data.get("decor", []):
		if r.get("id") == item_id:
			return r
	return {}


func _site_name(site_id: String) -> String:
	for s in Catalog.data.get("sites", []):
		if s.get("id") == site_id:
			return String(s.get("name", site_id))
	return site_id


func _buy_gear(item_id: String) -> void:
	if not Game.buy_gear(item_id):
		UIFeel.sfx("warn")
		return
	UIFeel.sfx("pay")
	UIFeel.haptic("pay")
	_rebuild()


func _buy_staple(item_id: String) -> void:
	if not Game.buy_staple(item_id):
		UIFeel.sfx("warn")
		return
	UIFeel.sfx("pay")
	UIFeel.haptic("pay")
	_rebuild()
