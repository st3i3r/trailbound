class_name JournalSheet
extends Panel
## Journal (UI-030, §8.3) — the grandpa's-book surface. Eight tabs on
## the glass kit; every row reads live Game/Catalog state.
##
##   chapters   — page goals per site, stamped/locked/vol-II dimmed
##   guestbook  — personas by archetype (first stay) + regulars
##   field_notes— birds (fish join when their data lands)
##   recipes    — cooked vs. still-undiscovered dishes
##   keepsakes  — crew-stage keepsakes with their notes
##   letters    — delivered mail; tap to read (marks it read)
##   days       — one line per night, newest first
##   then_now   — per-site day-1 → today card; the photo pair lands
##                with the capture pass — shown as honest text until then
##
## Cover % = collected/total over the five fill-in sections — the
## same number the save-completion chip uses (Game.journal_completion).

const W := 316
const H := 300

const TABS := [
	["chapters", "trail_map", "jrnl_t_chapters"],
	["guestbook", "guestbook", "jrnl_t_guestbook"],
	["field_notes", "field_notes", "jrnl_t_field"],
	["recipes", "recipes", "jrnl_t_recipes"],
	["keepsakes", "keepsakes", "jrnl_t_keepsakes"],
	["letters", "letters", "jrnl_t_letters"],
	["days", "daily", "jrnl_t_days"],
	["then_now", "camera", "jrnl_t_thennow"],
]

var _v: VBoxContainer
var _tab := "chapters"
var _tab_btns := {}
var _content: ScrollContainer
var _letter: Dictionary = {}


static func make() -> JournalSheet:
	var s := JournalSheet.new()
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
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_bottom", 10)
	add_child(m)
	_v = VBoxContainer.new()
	_v.add_theme_constant_override("separation", 4)
	m.add_child(_v)
	var x := UIKit.icon_btn(self, "close")
	x.position = Vector2(W - UITokens.MIN_TOUCH - 8, 4)
	x.pressed.connect(_close)
	_build_main()


func _close() -> void:
	var pm := get_parent() as PanelManager
	if pm:
		pm.close()


func _build_main() -> void:
	# header: title + cover completion
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_v.add_child(head)
	var t := UIKit.label_for(tr("jrnl_title"), UITokens.TypeRole.DISPLAY,
		UITokens.PAPER)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var comp := Game.journal_completion()
	var pct := UIKit.label_for("%d/%d" % [comp["done"], comp["total"]],
		UITokens.TypeRole.HEAD, UITokens.GOLD)
	pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(pct)
	UIKit.spacer(head, UITokens.MIN_TOUCH)   # keep clear of the X chip

	# tab strip — 8 sections, icon-only (tooltips carry the names);
	# horizontal scroll keeps every tab a full 40px target
	var strip := ScrollContainer.new()
	strip.custom_minimum_size = Vector2(0, UITokens.MIN_TOUCH + 4)
	strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_v.add_child(strip)
	var tb := HBoxContainer.new()
	tb.add_theme_constant_override("separation", 4)
	strip.add_child(tb)
	for spec in TABS:
		var b := UIKit.icon_btn(tb, spec[1])
		b.tooltip_text = tr(spec[2])
		b.toggle_mode = true
		b.pressed.connect(_select_tab.bind(spec[0]))
		_tab_btns[spec[0]] = b

	_content = ScrollContainer.new()
	_content.name = "JournalRows"
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_v.add_child(_content)
	_show_tab()


func _select_tab(tab: String) -> void:
	_letter = {}
	_tab = tab
	_show_tab()


func _show_tab() -> void:
	for c in _content.get_children():
		c.queue_free()
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", UITokens.SP1)
	_content.add_child(list)
	for k in _tab_btns:
		var b: Button = _tab_btns[k]
		b.button_pressed = (k == _tab)
		b.add_theme_stylebox_override("normal",
			UIKit.flat("glass_chip", 1.2) if k == _tab else StyleBoxEmpty.new())
	if _letter:
		_view_letter(list)
	else:
		call("_rows_" + _tab, list)


# ------------------------------------------------------------- row kit

func _cap(parent: Control, text: String) -> void:
	var l := UIKit.label_for(text.to_upper(), UITokens.TypeRole.CAPTION,
		UITokens.DIM)
	l.custom_minimum_size.y = 14
	parent.add_child(l)


## One list row: left glyph, body text (optionally two lines), right
## glyph cluster. `dim` renders the locked/undiscovered look.
func _row(parent: Control, icon: String, text: String,
		right_icon := "", dim := false, sub := "") -> void:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 22)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	var col := UITokens.DIM if dim else UITokens.PAPER
	h.add_child(UIKit.icon_rect(icon, col))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	h.add_child(mid)
	mid.add_child(UIKit.label_for(text, UITokens.TypeRole.HEAD, col))
	if sub != "":
		var s := UIKit.label_for(sub, UITokens.TypeRole.CAPTION,
			UITokens.DIM)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mid.add_child(s)
	if right_icon != "":
		h.add_child(UIKit.icon_rect(right_icon,
			UITokens.DIM if dim else UITokens.GOLD))
	parent.add_child(h)


func _empty(parent: Control, key: String) -> void:
	var l := UIKit.label_for(tr(key), UITokens.TypeRole.BODY,
		UITokens.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)


# ------------------------------------------------------------- tabs

func _rows_chapters(list: Control) -> void:
	for site in Game.JOURNAL_SITES:
		var done := Game.chapter_done(site)
		_cap(list, "%s  %s" % [Game.site_name(site),
			"✓" if done else ""])
		var reachable := Game.site_reachable(site)
		for p in Game.chapter_pages(site):
			var n := int(p["n"])
			var is_done := Game.page_done(n, site)
			var vol2 := int(p.get("vol", 1)) == 2
			var icon := "check" if is_done else (
				"lock" if not reachable or (vol2 and not Game.vol2_open())
				else "pen_square")
			var sub := ""
			if p.get("gift", 0) > 0:
				sub = "+%dc" % int(p["gift"])
			_row(list, icon, "P%d  %s" % [n, p["goal"]],
				"" , not reachable or vol2 and not is_done, sub)


func _rows_guestbook(list: Control) -> void:
	_cap(list, tr("jrnl_t_guestbook"))
	var any := false
	for a in Catalog.data.get("archetypes", []):
		var met: bool = Game.personas_met.has(a["id"])
		any = any or met
		_row(list, "user",
			Game.personas_met.get(a["id"], "—"),
			"", not met,
			a["name"])
	if not any:
		_empty(list, "jrnl_empty_guestbook")
	_cap(list, tr("jrnl_regulars"))
	var any_r := false
	for s in Game.JOURNAL_SITES:
		var visits: Dictionary = Game.site_state(s)["counters"].get(
			"regular_visits", {})
		for r in Catalog.data.get("regulars", []):
			if r["id"] in visits:
				any_r = true
				_row(list, "users", r["name"], "",
					false, tr("jrnl_visits") % int(visits[r["id"]]))
	if not any_r:
		_empty(list, "jrnl_empty_regulars")


func _rows_field_notes(list: Control) -> void:
	_cap(list, tr("jrnl_t_field"))
	var any := false
	for b in Catalog.data.get("birds", []):
		var seen: bool = b["id"] in Game.field_notes
		any = any or seen
		_row(list, "leaf", b["name"] if seen else "? ? ?",
			"check" if seen else "", not seen,
			b["note"] if seen else Game.site_name(b["site"]))
	if not any:
		_empty(list, "jrnl_empty_field")


func _rows_recipes(list: Control) -> void:
	_cap(list, tr("jrnl_t_recipes"))
	var any := false
	for r in Catalog.data.get("recipes", []):
		var cooked: bool = r["id"] in Game.recipes_cooked
		any = any or cooked
		_row(list, "cook", r["name"] if cooked else "? ? ?",
			"check" if cooked else "", not cooked,
			"" if cooked else tr("jrnl_not_cooked"))
	if not any:
		_empty(list, "jrnl_empty_recipes")


func _rows_keepsakes(list: Control) -> void:
	_cap(list, tr("jrnl_t_keepsakes"))
	var got: Array = Game.crew["collected"]
	var any := false
	for s in Catalog.data.get("crew", {}).get("structures", []):
		for stage in s.get("stages", []):
			var k: Dictionary = stage.get("keepsake", {})
			if k.is_empty():
				continue
			var has: bool = k["id"] in got
			any = any or has
			_row(list, "keepsakes", k["label"] if has else "? ? ?",
				"check" if has else "", not has,
				tr(k["note_key"]) if has else "")
	if "the_second_volume" in got:
		_row(list, "keepsakes", tr("jrnl_vol2"), "check")
	if not any and "the_second_volume" not in got:
		_empty(list, "jrnl_empty_keepsakes")


func _rows_letters(list: Control) -> void:
	_cap(list, tr("jrnl_t_letters"))
	var any := false
	for site in Game.JOURNAL_SITES:
		var letters := Game.letters_for(site)
		if letters.is_empty():
			continue
		any = true
		for l in letters:
			var unread: bool = l["id"] not in Game.letters_read
			var b := Button.new()
			b.custom_minimum_size = Vector2(0, 30)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
			b.add_theme_stylebox_override("hover",
				UIKit.flat("glass_chip"))
			b.add_theme_stylebox_override("pressed",
				UIKit.flat("glass_chip", 0.82))
			b.pressed.connect(func():
				UIFeel.haptic("press")
				Game.read_letter(l["id"])
				_letter = l
				_show_tab())
			var h := HBoxContainer.new()
			h.set_anchors_preset(Control.PRESET_FULL_RECT)
			h.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.alignment = BoxContainer.ALIGNMENT_CENTER
			h.add_theme_constant_override("separation", 8)
			b.add_child(h)
			h.add_child(UIKit.icon_rect(
				"mail" if unread else "scroll",
				UITokens.PAPER if unread else UITokens.DIM))
			var mid := VBoxContainer.new()
			mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(mid)
			mid.add_child(UIKit.label_for(
				l.get("theme", ""), UITokens.TypeRole.HEAD,
				UITokens.PAPER if unread else UITokens.DIM))
			mid.add_child(UIKit.label_for(
				"%s · %s" % [l.get("from", ""), Game.site_name(site)],
				UITokens.TypeRole.CAPTION, UITokens.DIM))
			if unread:
				h.add_child(UIKit.icon_rect("alert", UITokens.GOLD))
			list.add_child(b)
	if not any:
		_empty(list, "jrnl_empty_letters")


func _rows_days(list: Control) -> void:
	_cap(list, tr("jrnl_t_days"))
	if Game.days_log.is_empty():
		_empty(list, "jrnl_empty_days")
		return
	var icons := {"clear": "sun", "cloud": "cloud", "rain": "rain",
		"storm": "rain", "night": "moon", "sunrise": "sunrise"}
	for i in range(Game.days_log.size() - 1, -1, -1):
		var d: Dictionary = Game.days_log[i]
		_row(list, icons.get(d["weather"], "sun"),
			tr("jrnl_day_line") % [int(d["day"]),
				Game.site_name(StringName(d["site"]))],
			"star_full" if int(d.get("best", 0)) > 0 else "",
			false,
			tr("jrnl_day_sub") % [int(d["guests"]), int(d["income"])])


func _rows_then_now(list: Control) -> void:
	_cap(list, tr("jrnl_t_thennow"))
	var any := false
	for site in Game.JOURNAL_SITES:
		if not Game.site_reachable(site):
			continue
		any = true
		_row(list, "camera", Game.site_name(site), "", false,
			tr("jrnl_then_line") % Game.day)
	if not any:
		_empty(list, "jrnl_empty_thennow")
	var note := UIKit.label_for(tr("jrnl_then_note"),
		UITokens.TypeRole.CAPTION, UITokens.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(note)


# ------------------------------------------------------------- letter

func _view_letter(list: Control) -> void:
	var from := UIKit.label_for(
		tr("jrnl_from") % _letter.get("from", ""),
		UITokens.TypeRole.CAPTION, UITokens.DIM)
	list.add_child(from)
	var theme_l := UIKit.label_for(_letter.get("theme", ""),
		UITokens.TypeRole.HEAD, UITokens.PAPER)
	list.add_child(theme_l)
	var body := UIKit.label_for(_letter.get("text", ""),
		UITokens.TypeRole.BODY, UITokens.PAPER)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(body)
	var back := UIKit.btn(list, Vector2(100, UITokens.MIN_TOUCH),
		tr("jrnl_back"), "pill", Control.SIZE_SHRINK_CENTER)
	back.pressed.connect(func():
		_letter = {}
		_show_tab())
