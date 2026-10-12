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

const CARD_W := 84
const CARD_H := 46
const STRIP_H := 24

var cards: HBoxContainer
var strip: Panel
var strip_box: HBoxContainer
var _cards := {}                       # gid -> card Panel
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
## {"tex": Texture2D, "tint": Color} for the portrait.
func build(board: Array, trait_names: Dictionary,
		sprite_cb: Callable) -> void:
	reset()
	_trait_names = trait_names
	for req in board:
		var card := _card(req, sprite_cb.call(req))
		cards.add_child(card)
		_cards[req["id"]] = card
	hide_strip()


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
	# head-and-shoulders portrait: an integer 36px crop near the top of
	# the bottom-anchored figure — reads as a portrait, keeps 1x pixels
	var src: Texture2D = sprite.get("tex")
	if src:
		var at := AtlasTexture.new()
		at.atlas = src
		at.region = Rect2((src.get_width() - 36) / 2.0, 6, 36, 34)
		var port := TextureRect.new()
		port.name = "Portrait"
		port.texture = at
		port.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		port.stretch_mode = TextureRect.STRETCH_KEEP
		port.position = Vector2(4, 6)
		port.modulate = sprite.get("tint", Color.WHITE)
		c.add_child(port)
	var name_l := UIKit.label_for(_card_name(req),
		UITokens.TypeRole.CAPTION)
	name_l.name = "Name"
	name_l.position = Vector2(41, 3)
	name_l.size = Vector2(CARD_W - 43, 10)
	c.add_child(name_l)
	# fee: coin icon + amount
	var coin := UIKit.icon_rect("coin")
	coin.name = "FeeIcon"
	coin.position = Vector2(41, 14)
	c.add_child(coin)
	var fee_l := UIKit.label_for("%dc" % int(req.get("fee", 0)),
		UITokens.TypeRole.BODY)
	fee_l.name = "Fee"
	fee_l.position = Vector2(58, 17)
	fee_l.size = Vector2(24, 10)
	c.add_child(fee_l)
	# trait icons: up to 3, 16px at 13px stride so three fit the column
	var tx := 41
	for tid in req.get("traits", []).slice(0, 3):
		var t := UIKit.icon_rect(String(tid))
		t.position = Vector2(tx, 29)
		c.add_child(t)
		tx += 13
	# badges: elite star top-left, loud megaphone under it, favourite
	# heart+? top-right (undiscovered favourites show the placeholder)
	var by := 1
	if req.get("elite", false):
		_badge(c, "star_full", Vector2(1, by), UITokens.GOLD)
		by += 13
	if req.get("loud", false):
		_badge(c, "megaphone", Vector2(1, by), Color.WHITE)
	var fav := UIKit.icon_rect("heart", UITokens.DIM)
	fav.name = "Fav"
	fav.position = Vector2(CARD_W - 15, 1)
	c.add_child(fav)
	var q := UIKit.label_for("?", UITokens.TypeRole.BODY, UITokens.DIM)
	q.name = "FavQ"
	q.position = Vector2(CARD_W - 7, 3)
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
	var n: String = req.get("name", "?")
	if int(req.get("pads", 1)) > 1:
		n += " ×%d" % int(req["pads"])
	return n


func _badge(card: Control, icon_name: String, pos: Vector2,
		tint: Color) -> void:
	var b := UIKit.icon_rect(icon_name, tint)
	b.position = pos
	card.add_child(b)


# ---------------------------------------------------- breakdown strip

## Neutral trait list for a selected guest (no pad under the pointer
## yet) — shows what they want before the board answers.
func show_guest_terms(guest: Dictionary, hint: String) -> void:
	var chips := []
	for tid in guest.get("traits", []):
		chips.append({"icon": String(tid),
			"name": _trait_names.get(tid, tid), "sign": "·",
			"color": UITokens.DIM})
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
