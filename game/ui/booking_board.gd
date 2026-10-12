class_name BookingBoard
extends Panel
## UI-023: the booking board sheet — tonight's requests, read in the
## Morning before the evening seating puzzle (§5.2, §17.2).
##
## Diegetic entry: the notice board prop on the map opens this; the
## sheet itself is informational — cards can't be declined, parties
## beyond the open-pad count simply wait at the trailhead (§5.6).
##
## Layout mirrors the night sheet's discipline: title centred inside
## the paper under the frame emblem, a single 36px content column
## clear of the rope corners, forecast row, scrollable request cards,
## demand line at the bottom.  Dimmer tap closes (PanelManager).
##
## make() signature: the scene supplies the day's `st["board"]`, the
## morning-rolled weather (the forecast is always right, §5.7), the
## open-pad count for the demand line, the same sprite_cb the tray
## uses for portraits, and the trait-id -> display-name map.

const W := 336
const H := 300
const CARD_H := 44

var _board: Array = []
var _trait_names := {}


func _ready() -> void:
	position = (get_viewport_rect().size - size) / 2.0


static func make(board: Array, weather: String, open_pads: int,
		sprite_cb: Callable, trait_names: Dictionary) -> BookingBoard:
	var s := BookingBoard.new()
	s._board = board
	s._trait_names = trait_names
	s._build(weather, open_pads, sprite_cb)
	return s


func _build(weather: String, open_pads: int,
		sprite_cb: Callable) -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	add_theme_stylebox_override("panel", UIKit.flat("sheet"))
	# container layout — same margin discipline as the night sheet
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_top", 5)
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_bottom", 12)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	m.add_child(v)
	var title := UIKit.label_for(tr("board_title"),
		UITokens.TypeRole.DISPLAY, UITokens.PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	# forecast row — the morning forecast IS tonight's weather (§5.7)
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 6)
	frow.add_child(UIKit.icon_rect(weather))
	frow.add_child(UIKit.label_for(
		tr("board_forecast") % tr("weather_" + weather),
		UITokens.TypeRole.BODY, UITokens.PAPER))
	v.add_child(frow)

	# request cards
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	for req in _board:
		list.add_child(_card(req, sprite_cb))

	# demand line (§5.6): requests vs open pads, overflow waits outside
	var demand := VBoxContainer.new()
	demand.add_theme_constant_override("separation", 2)
	demand.add_child(UIKit.label_for(
		tr("board_demand") % [_board.size(), open_pads],
		UITokens.TypeRole.BODY, UITokens.PAPER))
	if _board.size() > open_pads:
		demand.add_child(UIKit.label_for(tr("board_wait"),
			UITokens.TypeRole.BODY, UITokens.DIM))
	v.add_child(demand)


## One request row — a dark pinned card on the parchment, same family
## as the tray cards: portrait crop, name (+ party size), fee, trait
## icons, favourite marker, regular ribbon.
func _card(req: Dictionary, sprite_cb: Callable) -> Panel:
	var c := Panel.new()
	c.custom_minimum_size = Vector2(W - 32, CARD_H)
	c.size = c.custom_minimum_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_theme_stylebox_override("panel", UIKit.flat("glass_chip"))
	var sprite: Dictionary = sprite_cb.call(req)
	var src: Texture2D = sprite.get("tex")
	if src:
		var at := AtlasTexture.new()
		at.atlas = src
		at.region = Rect2((src.get_width() - 36) / 2.0, 6, 36, 34)
		var port := TextureRect.new()
		port.texture = at
		port.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		port.stretch_mode = TextureRect.STRETCH_KEEP
		port.position = Vector2(4, 5)
		port.modulate = sprite.get("tint", Color.WHITE)
		c.add_child(port)
	var n: String = req.get("name", "?")
	if int(req.get("pads", 1)) > 1:
		n += " ×%d" % int(req["pads"])
	var name_l := UIKit.label_for(n, UITokens.TypeRole.CAPTION)
	name_l.position = Vector2(44, 4)
	name_l.size = Vector2(W - 32 - 46, 10)
	c.add_child(name_l)
	var coin := UIKit.icon_rect("coin")
	coin.position = Vector2(44, 16)
	c.add_child(coin)
	var fee_l := UIKit.label_for("%dc" % int(req.get("fee", 0)),
		UITokens.TypeRole.BODY)
	fee_l.position = Vector2(61, 19)
	c.add_child(fee_l)
	# icons only — names don't fit a 44px card; the evening strip
	# explains the same trait vocabulary live while seating
	var tx := 44
	for tid in req.get("traits", []).slice(0, 4):
		var t := UIKit.icon_rect(String(tid))
		t.position = Vector2(tx, 28)
		c.add_child(t)
		tx += 18
	# favourite: heart + "?" until the recipe is cooked (§5.2)
	var fav := UIKit.icon_rect("heart", UITokens.DIM)
	fav.position = Vector2(W - 32 - 40, 4)
	c.add_child(fav)
	var q := UIKit.label_for("?", UITokens.TypeRole.BODY, UITokens.DIM)
	q.position = Vector2(W - 32 - 26, 6)
	c.add_child(q)
	# regulars arrive on ribboned cards (§5.2) — gold star badge
	if req.get("regular", false):
		var rib := UIKit.icon_rect("star_full")
		rib.position = Vector2(W - 32 - 40, 22)
		c.add_child(rib)
	return c
