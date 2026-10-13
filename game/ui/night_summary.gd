class_name NightSummary
extends Panel
## UI-022: the Night summary sheet (GDD §17.2) — the payoff read-out
## for the core loop.  Built from the Game.goodnight() report:
##
##   reviews      one block per seated guest: name, star icons, fee+tip,
##                the same +/− breakdown vocabulary the tray uses, then
##                the review quote (§5.6)
##   totals       fees · tips · walk-in leftover sales · gathering bonus
##                · income and the coin tally, which counts up on open
##   progress     journal pages completed tonight (§8.1)
##   forecast     tomorrow's weather — the real seeded roll (Game.forecast)
##   buttons      "Double tips +Nc" (opt-in rewarded ad, §24 — mocked on
##                desktop, once per in-game day from night 3) and
##                "Sleep" which exits to the next morning
##
## Emits sleep_pressed; the scene owns advancing the day.

signal sleep_pressed

const W := 336
const H := 300

var _rep := {}
var _names := {}
var _coins_l: Label
var _double_b: Button
var _doubled := false


## names: gid -> display name, captured by the caller BEFORE
## Game.goodnight() — it clears st["guests"], so ids alone can't
## recover names afterwards.
static func make(rep: Dictionary, names: Dictionary, day: int,
		forecast: String) -> NightSummary:
	var s := NightSummary.new()
	s._rep = rep
	s._names = names
	s._build(day, forecast)
	return s


func _ready() -> void:
	position = (get_viewport_rect().size - size) / 2.0


func _build(day: int, forecast: String) -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	add_theme_stylebox_override("panel", UIKit.flat("sheet"))
	# container layout: one margin column — content can never reach
	# the frame's decorated zone by construction
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
	var title := UIKit.label_for(tr("night_title") % day,
		UITokens.TypeRole.DISPLAY, UITokens.PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	_build_reviews(v)
	_build_vignette(v)
	_build_totals(forecast, v)
	_build_buttons(v)


# ----------------------------------------------------------- reviews

func _build_reviews(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Reviews"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var results: Array = _rep.get("results", [])
	if results.is_empty():
		UIKit.empty(list, "guestbook", tr("night_none"))
		return
	var best_id: String = _rep.get("best", {}).get("id", "")
	for r in results:
		list.add_child(_review_block(r, r["id"] == best_id))


func _review_block(r: Dictionary, is_best: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	# line 1: name [+ best star] · star icons · fee+tip
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	var name_l := UIKit.label_for(String(_names.get(r["id"],
		r["id"])), UITokens.TypeRole.HEAD, UITokens.PAPER)
	top.add_child(name_l)
	if is_best:
		top.add_child(UIKit.icon_rect("sparkle", UITokens.GOLD))
	for i in int(r.get("stars", 0)):
		top.add_child(UIKit.icon_rect("star_full"))
	var pay := UIKit.label_for("+%dc" % (int(r.get("fee", 0))
		+ int(round(r.get("tip", 0.0)))),
		UITokens.TypeRole.HEAD, UITokens.GREEN)
	top.add_child(pay)
	box.add_child(top)
	# line 2: the breakdown — every signed term with its icon
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 5)
	for d in r.get("detail", []):
		chips.add_child(_term(String(d.get("trait", "")),
			"+1" if d.get("met", false) else \
			("−1" if d.get("tripped", false) else "·")))
	if int(r.get("comfort", 0)) > 0:
		chips.add_child(_term("tent",
			"+%d" % int(r["comfort"])))
	if int(r.get("weather", 0)) != 0:
		chips.add_child(_term("rain", "−1"))
	var meal := int(r.get("meal", 0))
	if meal != 0:
		chips.add_child(_term("cook",
			"%+d" % meal))
	box.add_child(chips)
	# line 3: the review quote
	var c := UIKit.label_for("“%s”" % String(r.get("comment", "")),
		UITokens.TypeRole.BODY, UITokens.DIM)
	box.add_child(c)
	return box


func _term(icon_name: String, sign: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	var t := UIKit.icon_rect(icon_name,
		Color(1, 1, 1, 0.6) if sign == "·" else null)
	row.add_child(t)
	var color := UITokens.DIM
	if sign.begins_with("+"):
		color = UITokens.GREEN
	elif sign.begins_with("−"):
		color = UITokens.RED
	var l := UIKit.label_for(sign, UITokens.TypeRole.BODY, color)
	row.add_child(l)
	return row


## spec 005 A: tonight's vignette is a beat, not bookkeeping — a chip
## card between the reviews and the ledger (label + one-line scene
## description).  The matching light cue is the scene's job: it tracks
## the row's `cue` term while this sheet is open.
func _build_vignette(parent: Control) -> void:
	var vid := String(_rep.get("vignette", ""))
	if vid == "":
		return
	var row := {}
	for v in Catalog.data.get("vignettes", []):
		if v.get("id") == vid:
			row = v
			break
	if row.is_empty():
		return
	var card := PanelContainer.new()
	card.name = "VignetteCard"
	card.add_theme_stylebox_override("panel", UIKit.flat("glass_chip"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(h)
	h.add_child(UIKit.icon_rect("moon"))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	h.add_child(mid)
	mid.add_child(UIKit.label_for(String(row.get("label", vid)),
		UITokens.TypeRole.HEAD, UITokens.GOLD))
	var line := UIKit.label_for(String(row.get("line", "")),
		UITokens.TypeRole.BODY, UITokens.DIM)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(line)
	parent.add_child(card)


# ------------------------------------------------------------ totals

func _build_totals(forecast: String, parent: Control) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)
	var fees := int(_rep.get("fees", 0))
	var tips := int(_rep.get("tips", 0))
	var sales := int(_rep.get("meal_sales", 0))
	var walks := int(_rep.get("walk_ins", 0))
	var gather := int(_rep.get("gathering", {}).get("bonus", 0))
	var income := int(_rep.get("income", 0))
	var parts := "%s +%dc   %s +%dc" % [tr("night_fees"), fees,
		tr("night_tips"), tips]
	box.add_child(UIKit.label_for(parts, UITokens.TypeRole.BODY,
		UITokens.PAPER))
	if walks > 0:
		box.add_child(UIKit.label_for(
			tr("night_walkins").format({"n": walks, "c": sales}),
			UITokens.TypeRole.BODY, UITokens.PAPER))
	if gather > 0:
		box.add_child(UIKit.label_for(
			tr("night_gathering") % gather,
			UITokens.TypeRole.BODY, UITokens.PAPER))
	for p in _rep.get("pages", []):
		var pl := UIKit.label_for(tr("night_page") % int(p),
			UITokens.TypeRole.BODY, UITokens.GOLD)
		box.add_child(pl)
	# forecast row: weather left, money pushed right — no floating numbers
	var last := HBoxContainer.new()
	last.add_theme_constant_override("separation", 6)
	var wico := UIKit.icon_rect(forecast)
	last.add_child(wico)
	last.add_child(UIKit.label_for(
		"%s: %s" % [tr("night_tomorrow"),
		tr("weather_" + forecast)],
		UITokens.TypeRole.BODY, UITokens.PAPER))
	var push := Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	last.add_child(push)
	last.add_child(UIKit.label_for("+%dc" % income,
		UITokens.TypeRole.HEAD, UITokens.GREEN))
	last.add_child(UIKit.icon_rect("coin"))
	_coins_l = UIKit.label_for("%dc" % Game.coins,
		UITokens.TypeRole.HEAD, UITokens.GOLD)
	last.add_child(_coins_l)
	box.add_child(last)


## Coin count-up (§17.2): the tally animates from before-income to the
## real total — call once the sheet is on screen.
func run_count_up() -> void:
	if _coins_l == null:
		return
	var income := int(_rep.get("income", 0))
	var from := Game.coins - income
	UIFeel.sfx("coin")
	var tw := UIFeel.apply(create_tween(), "count_up")
	tw.tween_method(func(v): _coins_l.text = "%dc" % int(v),
		float(from), float(Game.coins), UIFeel.dur("count_up"))


# ------------------------------------------------------------ buttons

func _build_buttons(parent: Control) -> void:
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", UITokens.SP2)
	var tips := int(_rep.get("tips", 0))
	if Ads.can_double_tips(Game.day) and tips > 0 \
			and Game.tips_doubled_day != Game.day:
		_double_b = UIKit.btn(brow, Vector2(150, UITokens.MIN_TOUCH),
			tr("night_double") % tips, "green")
		_double_b.pressed.connect(_on_double)
	var push := Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	push.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brow.add_child(push)
	var sleep := UIKit.btn(brow, Vector2(104, UITokens.MIN_TOUCH),
		tr("night_sleep"), "gold")
	sleep.set_meta("primary", true)      # nav-mode focus lands here
	sleep.pressed.connect(func(): sleep_pressed.emit())
	parent.add_child(brow)


func _on_double() -> void:
	if _doubled or _double_b == null:
		return
	var tips := int(_rep.get("tips", 0))
	if not Game.double_tips(tips):
		return                            # already claimed this night
	_doubled = true
	Ads.show_rewarded_night_bonus(Game.day)   # mock: instant reward
	_double_b.disabled = true
	_double_b.text = tr("night_doubled") % tips
	# recount to the new total so the tally never lies
	UIFeel.haptic("pay")
	UIFeel.sfx("pay")
	var tw := UIFeel.apply(create_tween(), "recount")
	tw.tween_method(func(v): _coins_l.text = "%dc" % int(v),
		float(Game.coins - tips), float(Game.coins),
		UIFeel.dur("recount"))
