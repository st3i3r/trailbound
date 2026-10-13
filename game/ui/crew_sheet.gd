class_name CrewSheet
extends Panel
## Crew sheet (UI-035, §8.4) — the restoration clock.  Shows the
## active structure + stage progress, time remaining (ticks while the
## sheet is open), Collect when the stage is ready, and the
## rewarded-speed-up row (chunk caps handled by the sim).  The
## keepsake collect moment itself lands as a Ceremony overlay driven
## by Game.crew_collected — this sheet just rebuilds.

const W := 300
const H := 260

var _v: VBoxContainer
var _time: Label                       # live countdown, 1s cadence
var _acc := 0.0


static func make() -> CrewSheet:
	var s := CrewSheet.new()
	s._build()
	return s


func _ready() -> void:
	position = (get_viewport_rect().size - size) / 2.0
	set_process(true)


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
	_v.add_theme_constant_override("separation", 6)
	m.add_child(_v)
	var x := UIKit.icon_btn(self, "close")
	x.position = Vector2(W - UITokens.MIN_TOUCH - 8, 4)
	x.pressed.connect(_close)
	_rebuild()


func _process(delta: float) -> void:
	# countdown is wall-clock backed — crew_tick() does the math so a
	# clock set back never undoes work; we only repaint the readout
	_acc += delta
	if _acc < 1.0:
		return
	_acc = 0.0
	Game.crew_tick()
	if _time:
		_time.text = _time_text()
	if Game.is_stage_ready():
		_rebuild()                     # stage completed while watching


func _close() -> void:
	var pm := get_parent() as PanelManager
	if pm:
		pm.close()


func _rebuild() -> void:
	for c in _v.get_children():
		c.queue_free()
	_time = null
	_build_main()


func _build_main() -> void:
	var title := UIKit.label_for(tr("crew_t_sheet"),
		UITokens.TypeRole.DISPLAY, UITokens.PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_v.add_child(title)

	if Game.crew_done():
		UIKit.empty(_v, "keepsakes", tr("crew_done"))
		_build_keepsakes()
		return

	var structure := String(Game.crew.get("structure", ""))
	if structure == "":
		UIKit.empty(_v, "crew", tr("crew_idle"))
		_build_keepsakes()
		return

	# --- active structure: label, stage x/y, progress bar, clock
	var s := _structure(structure)
	var st := _stage(s, int(Game.crew["stage"]))
	var head := UIKit.label_for("%s — %s" % [
		s.get("label", structure), st.get("label", "")],
		UITokens.TypeRole.HEAD, UITokens.PAPER)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_v.add_child(head)
	var stage_line := UIKit.label_for(tr("crew_working").format(
		{"name": s.get("label", structure),
		 "s": int(Game.crew["stage"]) + 1,
		 "t": s.get("stages", []).size()}),
		UITokens.TypeRole.CAPTION, UITokens.DIM)
	_v.add_child(stage_line)

	var stage_secs := float(st.get("seconds", 1))
	var left := float(Game.crew["seconds_left"])
	_v.add_child(_bar(1.0 - left / maxf(1.0, stage_secs)))

	_time = UIKit.label_for(_time_text(), UITokens.TypeRole.BODY,
		UITokens.GOLD)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_v.add_child(_time)

	# --- actions
	if Game.is_stage_ready():
		var cb := UIKit.btn(_v, Vector2(160, UITokens.MIN_TOUCH),
			tr("crew_collect"), "gold", Control.SIZE_SHRINK_CENTER)
		cb.set_meta("ui_primary", true)
		cb.pressed.connect(func():
			var got := Game.crew_collect()
			if got.is_empty():
				return
			UIFeel.sfx("stamp")
			_rebuild())
	else:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		_v.add_child(row)
		if Game.crew_can_speedup():
			var chunk := maxf(900.0, stage_secs / 6.0)
			var su := UIKit.btn(row, Vector2(140, UITokens.MIN_TOUCH),
				tr("crew_speedup").format(
					{"m": int(chunk / 60.0)}),
				"pill", Control.SIZE_SHRINK_CENTER)
			su.pressed.connect(func():
				if Game.crew_speedup() > 0.0:
					UIFeel.sfx("confirm")
					UIFeel.haptic("confirm")
					_rebuild())
		if Game.crew_free_finish():
			var ff := UIKit.btn(row, Vector2(140, UITokens.MIN_TOUCH),
				tr("crew_free"), "green", Control.SIZE_SHRINK_CENTER)
			ff.pressed.connect(func():
				if Game.crew_free_finish():
					UIFeel.sfx("confirm")
					_rebuild())

	_build_keepsakes()


func _bar(frac: float) -> Control:
	var back := Panel.new()
	back.custom_minimum_size = Vector2(0, 8)
	back.add_theme_stylebox_override("panel", UIKit.flat("glass_chip"))
	var fill := Panel.new()
	fill.anchor_right = clampf(frac, 0.0, 1.0)
	fill.anchor_bottom = 1.0
	fill.add_theme_stylebox_override("panel",
		UIKit.flat("sel_glow", 1.0, 0.9))
	back.add_child(fill)
	return back


func _time_text() -> String:
	var left := int(ceil(Game.crew.get("seconds_left", 0.0)))
	if left <= 0:
		return tr("crew_ready")
	if left >= 3600:
		return tr("crew_left").format(
			{"time": "%d:%02d" % [left / 3600, (left % 3600) / 60]})
	return tr("crew_left").format({"time": "%d:%02d" % [left / 60,
		left % 60]})


## Keepsakes earned so far — the journal's keepsakes tab owns the
## notes; here they read as a small "collected" shelf.
func _build_keepsakes() -> void:
	var got: Array = Game.crew.get("collected", [])
	if got.is_empty():
		return
	_v.add_child(UIKit.label_for(tr("crew_shelf"),
		UITokens.TypeRole.CAPTION, UITokens.DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_v.add_child(row)
	for k in got:
		var chip := Panel.new()
		chip.custom_minimum_size = Vector2(0, 24)
		chip.add_theme_stylebox_override("panel",
			UIKit.flat("glass_chip"))
		var l := UIKit.label_for(_keepsake_name(String(k)),
			UITokens.TypeRole.CAPTION, UITokens.PAPER)
		l.position = Vector2(8, 5)
		l.size = Vector2(1, 14)          # sized by text; chip autos to fit
		chip.add_child(l)
		chip.custom_minimum_size.x = \
			l.get_theme_font("font").get_string_size(l.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				l.get_theme_font_size("font_size")).x + 16
		row.add_child(chip)


func _structure(id: String) -> Dictionary:
	var structures: Array = Catalog.data.get("crew", {}) \
		.get("structures", [])
	for s in structures:
		if s.get("id") == id:
			return s
	return {}


func _stage(s: Dictionary, i: int) -> Dictionary:
	var stages: Array = s.get("stages", [])
	return stages[i] if i < stages.size() else {}


func _keepsake_name(kid: String) -> String:
	var structures: Array = Catalog.data.get("crew", {}) \
		.get("structures", [])
	for s in structures:
		for st in s.get("stages", []):
			var k: Dictionary = st.get("keepsake", {})
			if k.get("id") == kid:
				return String(k.get("label", kid))
	return kid
