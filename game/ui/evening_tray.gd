class_name EveningTray
extends Control
## UI-020: the evening seating tray — guest cards along the bottom
## band, and the live scoring-breakdown strip that rides above them.
##
## Cards are non-interactive Controls (mouse_filter IGNORE): the scene
## hit-tests via card_at() and owns all press/drag/release routing so
## world and card input share one path.  Cards show an in-world sprite
## portrait (an integer crop of the sprite — no fractional scaling),
## persona name, fee, trait icons and elite/loud/favourite badges;
## seated cards dim and take a check.
##
## The strip is the Into-the-Breach pattern: every +/− term that makes
## the star rating, each with its icon — trait needs (+1 when met),
## aversions (−1 when tripped), shelter comfort, uncovered rain — then
## the star total.  show_guest_terms() lists a guest's traits neutral
## while no pad is under the pointer; show_preview() repaints it live
## from Game.preview() so players can explain their stars before they
## commit (§5.3/§5.4).

const CARD_W := 100
const CARD_H := 46
const STRIP_H := 24
## Name row usable width: card minus the left badge column minus the
## favourite-heart zone at the right edge.  _lint_names enforces it.
const NAME_W := CARD_W - 27

var cards: HBoxContainer
var strip: Panel
var strip_box: HBoxContainer
var meal_lane: HBoxContainer           # tonight's menu, lead of the row
var meal_sep: VSeparator
var _cards := {}                       # gid -> card Panel
var _meals := {}                       # meal instance idx -> chip Panel
var _meal_names := {}                  # recipe id -> display name
var _cooked := {}                      # recipe id -> true (fav reveal)
var _trait_names := {}                 # tid -> display name


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scroll := ScrollContainer.new()
	scroll.name = "CardScroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scroll)
	cards = HBoxContainer.new()
	cards.name = "Cards"
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards.add_theme_constant_override("separation", UITokens.SP1)
	scroll.add_child(cards)
	# dinner lane sits ahead of the guest cards — both scroll together
	meal_lane = HBoxContainer.new()
	meal_lane.name = "MealLane"
	meal_lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meal_lane.add_theme_constant_override("separation", UITokens.SP1)
	meal_lane.visible = false
	cards.add_child(meal_lane)
	meal_sep = VSeparator.new()
	meal_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meal_sep.visible = false
	cards.add_child(meal_sep)
	strip = Panel.new()
	strip.name = "BreakdownStrip"
	strip.visible = false
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# glass_chip — same clean frame the cards use (flat chrome)
	strip.add_theme_stylebox_override("panel",
		UIKit.flat("glass_chip", 1.0, 0.92))
	strip_box = HBoxContainer.new()
	strip_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	strip_box.alignment = BoxContainer.ALIGNMENT_CENTER
	strip_box.add_theme_constant_override("separation", UITokens.SP2)
	strip.add_child(strip_box)
	add_child(strip)


## Rebuild the card row from the evening board (§5.2).  trait_names
## maps trait id -> display name; sprite_cb(req) returns
## {"tex": Texture2D, "tint": Color} for the portrait.  cooked =
## recipe ids the camp has cooked (favourites reveal once the dish is
## known, §5.2); meal_names maps recipe id -> display name for the
## dinner lane + armed-meal strip.
func build(board: Array, trait_names: Dictionary,
		sprite_cb: Callable, cooked := {}, meal_names := {}) -> void:
	reset()
	_trait_names = trait_names
	_cooked = cooked
	_meal_names = meal_names
	if board.is_empty():
		var e := UIKit.empty(cards, "users", tr("tray_empty"))
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for req in board:
		var card := _card(req, sprite_cb.call(req))
		cards.add_child(card)
		_cards[req["id"]] = card
	hide_strip()


## §5.5: tonight's menu — one chip per cooked meal instance, ahead of
## the guest cards.  Tap arms it; the scene serves on a guest tap.
func set_meals(list: Array) -> void:
	for c in _meals.values():
		c.queue_free()
	_meals = {}
	meal_lane.visible = not list.is_empty()
	meal_sep.visible = meal_lane.visible
	for i in list.size():
		_meals[i] = _meal_chip(list[i], i)
		meal_lane.add_child(_meals[i])


## Meal instance index under viewport point p (-1 when none).
func meal_at(p: Vector2) -> int:
	for i in _meals:
		if _meals[i].get_global_rect().has_point(p):
			return int(i)
	return -1


func set_meal_selected(idx: int) -> void:
	for i in _meals:
		_meals[i].get_node("Sel").visible = int(i) == idx


## Re-mark chips from sim state: the first unmarked chips per served id
## take the plate look — dupes are real instances, same as the sim.
func sync_served(served: Dictionary, list: Array) -> void:
	var want := {}
	for gid in served:
		var mid := String(served[gid])
		want[mid] = int(want.get(mid, 0)) + 1
	for i in _meals:
		var m: Control = _meals[i]
		var mid := String(list[int(i)].get("id", ""))
		var on := int(want.get(mid, 0)) > 0
		if on:
			want[mid] -= 1
		m.get_node("Served").visible = on
		m.modulate = Color(1, 1, 1, 0.55) if on else Color.WHITE


## Armed-meal strip line: "{name} — tap a seated guest to serve".
func show_meal(meal_name: String) -> void:
	_show([{"icon": "bowl", "name": meal_name, "sign": "",
		"color": UITokens.GOLD}, {"text": tr("tray_serve")}])


## gid whose card is under viewport point p ("" when none).
func card_at(p: Vector2) -> String:
	for gid in _cards:
		if _cards[gid].get_global_rect().has_point(p):
			return gid
	return ""


func set_selected(gid: String) -> void:
	for id in _cards:
		_cards[id].get_node("Sel").visible = id == gid


func mark_seated(gid: String) -> void:
	var c: Control = _cards.get(gid)
	if c:
		c.modulate = Color(1, 1, 1, 0.68)
		c.get_node("Seated").visible = true


func mark_unseated(gid: String) -> void:
	var c: Control = _cards.get(gid)
	if c:
		c.modulate = Color.WHITE
		c.get_node("Seated").visible = false


func is_seated(gid: String) -> bool:
	var c: Control = _cards.get(gid)
	return c != null and c.get_node("Seated").visible


## Refused action read: the card itself wobbles (UIFeel.shake handles
## pivot + reduced-motion), so the rejection lands on the thing the
## player tried to move — pair with the warn haptic/sfx at call sites.
func shake_card(gid: String) -> void:
	var c: Control = _cards.get(gid)
	if c:
		UIFeel.shake(c)


func reset() -> void:
	for c in _cards.values():
		c.queue_free()
	_cards = {}


# ------------------------------------------------------------- cards

func _card(req: Dictionary, sprite: Dictionary) -> Panel:
	var c := Panel.new()
	c.name = "card_" + String(req.get("id", "?"))
	c.custom_minimum_size = Vector2(CARD_W, CARD_H)
	c.size = Vector2(CARD_W, CARD_H)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_theme_stylebox_override("panel", UIKit.flat("glass_chip"))
	# name banner across the top (Eastward card anatomy): the full row
	# is text space, clear of the portrait below and the heart at right
	var name_l := UIKit.label_for(_card_name(req),
		UITokens.TypeRole.CAPTION)
	name_l.name = "Name"
	name_l.position = Vector2(4, 2)
	name_l.size = Vector2(NAME_W, 10)
	name_l.clip_text = true
	c.add_child(name_l)
	# head-and-shoulders portrait: an integer 36px crop near the top of
	# the bottom-anchored figure — reads as a portrait, keeps 1x pixels
	var src: Texture2D = sprite.get("tex")
	if src:
		var at := AtlasTexture.new()
		at.atlas = src
		at.region = Rect2((src.get_width() - 36) / 2.0, 8, 36, 32)
		var port := TextureRect.new()
		port.name = "Portrait"
		port.texture = at
		port.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		port.stretch_mode = TextureRect.STRETCH_KEEP
		port.position = Vector2(4, 12)
		port.modulate = sprite.get("tint", Color.WHITE)
		c.add_child(port)
	# fee: coin icon + amount (right column, beside the portrait)
	var coin := UIKit.icon_rect("coin")
	coin.name = "FeeIcon"
	coin.position = Vector2(44, 15)
	c.add_child(coin)
	var fee_l := UIKit.label_for("%dc" % int(req.get("fee", 0)),
		UITokens.TypeRole.BODY)
	fee_l.name = "Fee"
	fee_l.position = Vector2(61, 18)
	fee_l.size = Vector2(30, 10)
	fee_l.clip_text = true
	c.add_child(fee_l)
	# trait icons: up to 3, 16px at 13px stride, bottom-right column
	var tx := 44
	for tid in req.get("traits", []).slice(0, 3):
		var t := UIKit.icon_rect(String(tid))
		t.position = Vector2(tx, 28)
		c.add_child(t)
		tx += 13
	# badges ride the portrait corners: elite star top-left, loud
	# megaphone under it; favourite heart+? top-right of the card
	# (undiscovered favourites show the placeholder)
	var by := 13
	if req.get("elite", false):
		_badge(c, "star_full", Vector2(2, by), UITokens.GOLD)
		by += 13
	if req.get("loud", false):
		_badge(c, "megaphone", Vector2(2, by), Color.WHITE)
	# favourite: heart + "?" until the recipe has been cooked (§5.2) —
	# then the heart goes gold; select the card for the dish's name
	var fav := String(req.get("favourite", ""))
	var known := fav != "" and _cooked.has(fav)
	var fh := UIKit.icon_rect("heart",
		UITokens.GOLD if known else UITokens.DIM)
	fh.name = "Fav"
	fh.position = Vector2(CARD_W - 17, 2)
	c.add_child(fh)
	var q := UIKit.label_for("?", UITokens.TypeRole.BODY, UITokens.DIM)
	q.name = "FavQ"
	q.position = Vector2(CARD_W - 8, 4)
	q.visible = not known
	c.add_child(q)
	# seated check + selection ring (toggled, both drawn last = on top)
	var chk := UIKit.icon_rect("check")
	chk.name = "Seated"
	chk.position = Vector2(13, 15)
	chk.visible = false
	c.add_child(chk)
	var ring := Panel.new()
	ring.name = "Sel"
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# sel_glow — the lacquer kit's notched selection ring
	ring.add_theme_stylebox_override("panel",
		UIKit.state_nine("sel_glow"))
	ring.visible = false
	c.add_child(ring)
	return c


func _card_name(req: Dictionary) -> String:
	# card_name is the short card form (data may omit → full name);
	# journal/sheets still show the long one
	var n: String = req.get("card_name", "")
	if n == "":
		n = req.get("name", "?")
	if int(req.get("pads", 1)) > 1:
		n += " ×%d" % int(req["pads"])
	return n


func _badge(card: Control, icon_name: String, pos: Vector2,
		tint: Color) -> void:
	var b := UIKit.icon_rect(icon_name, tint)
	b.position = pos
	card.add_child(b)


## One dinner chip per meal instance: bowl + clipped name + price, a
## served check, and the same selection ring the guest cards wear.
func _meal_chip(m: Dictionary, idx: int) -> Panel:
	var c := Panel.new()
	c.name = "meal_%d" % idx
	c.custom_minimum_size = Vector2(64, CARD_H)
	c.size = Vector2(64, CARD_H)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_theme_stylebox_override("panel", UIKit.flat("glass_chip"))
	var b := UIKit.icon_rect("bowl")
	b.position = Vector2(4, 4)
	c.add_child(b)
	var nm := UIKit.label_for(String(_meal_names.get(
		String(m.get("id", "")), String(m.get("id", "?")))),
		UITokens.TypeRole.CAPTION)
	nm.position = Vector2(20, 4)
	nm.size = Vector2(42, 10)
	nm.clip_text = true
	c.add_child(nm)
	var coin := UIKit.icon_rect("coin")
	coin.position = Vector2(4, 30)
	c.add_child(coin)
	var pr := UIKit.label_for("%d" % int(m.get("price", 0)),
		UITokens.TypeRole.BODY)
	pr.position = Vector2(19, 30)
	pr.size = Vector2(30, 10)
	pr.clip_text = true
	c.add_child(pr)
	var chk := UIKit.icon_rect("check", UITokens.GREEN)
	chk.name = "Served"
	chk.position = Vector2(48, 30)
	chk.visible = false
	c.add_child(chk)
	var ring := Panel.new()
	ring.name = "Sel"
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_theme_stylebox_override("panel", UIKit.state_nine("sel_glow"))
	ring.visible = false
	c.add_child(ring)
	return c


# ---------------------------------------------------- breakdown strip

## Neutral trait list for a selected guest (no pad under the pointer
## yet) — shows what they want before the board answers.
func show_guest_terms(guest: Dictionary, hint: String) -> void:
	var chips := []
	for tid in guest.get("traits", []):
		chips.append({"icon": String(tid),
			"name": _trait_names.get(tid, tid), "sign": "·",
			"color": UITokens.DIM})
	var fav := String(guest.get("favourite", ""))
	if fav != "" and _cooked.has(fav):
		# the known favourite reads as part of their wants — steering
		# for both seating and tonight's menu
		chips.append({"icon": "heart",
			"name": _meal_names.get(fav, fav), "sign": "",
			"color": UITokens.GOLD})
	chips.append({"text": hint, "color": UITokens.DIM})
	_show(chips)


## Live terms for one candidate placement: the full resolve_guest
## result laid out as icon'd signed chips — met need +1, tripped
## aversion −1, comfort +N, uncovered rain −1 — then the star total.
func show_preview(r: Dictionary) -> void:
	var chips := []
	for d in r.get("detail", []):
		var sign := "·"
		var color: Color = UITokens.DIM
		if d.get("tripped", false):
			sign = "−1"
			color = UITokens.RED
		elif d.get("met", false):
			sign = "+1"
			color = UITokens.GREEN
		chips.append({"icon": String(d.get("trait", "")),
			"name": _trait_names.get(d.get("trait", ""), ""),
			"sign": sign, "color": color})
	var comfort := int(r.get("comfort", 0))
	chips.append({"icon": "tent",
		"name": tr("tray_shelter"),
		"sign": "+%d" % comfort if comfort > 0 else "·",
		"color": UITokens.GREEN if comfort > 0 else UITokens.DIM})
	if int(r.get("weather", 0)) != 0:
		chips.append({"icon": "rain",
			"name": tr("tray_rain"), "sign": "−1",
			"color": UITokens.RED})
	chips.append({"icon": "star_full",
		"name": "=", "sign": "%d" % int(r.get("stars", 0)),
		"color": UITokens.GOLD})
	_show(chips)


func hide_strip() -> void:
	strip.visible = false


func _show(chips: Array) -> void:
	for c in strip_box.get_children():
		c.queue_free()
	var w := UITokens.SP3
	for ch in chips:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 2)
		if ch.has("icon"):
			var t := UIKit.icon_rect(ch["icon"])
			row.add_child(t)
		var name := String(ch.get("name", ""))
		if name != "":
			row.add_child(UIKit.label_for(name, UITokens.TypeRole.BODY,
				UITokens.DIM))
		var sign := String(ch.get("sign", ch.get("text", "")))
		if sign != "":
			row.add_child(UIKit.label_for(sign, UITokens.TypeRole.HEAD,
				ch.get("color", UITokens.DIM)))
		strip_box.add_child(row)
		w += int(row.get_combined_minimum_size().x) + UITokens.SP2
	w += UITokens.SP3 - UITokens.SP2
	# strip rides just above the card band, width fitted to content
	strip.offset_left = 0
	strip.offset_top = -STRIP_H - UITokens.SP1
	strip.offset_right = float(w)
	strip.offset_bottom = -UITokens.SP1
	strip.visible = true
