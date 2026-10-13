class_name DialogueBubble
extends Control
## World-anchored speech bubble — the in-world half of UI-038.  Rides
## a Markers token so it tracks the speaker's screen position; each
## line runs the shared typewriter and the waving ▼ says "tap me".
## Tap mid-line completes it; tap at the end advances; after the last
## line the token releases and `on_done` fires.
##
##   DialogueBubble.say(markers, mai_node, Vector2(-86, -64),
##                      "Mai", ["line one", "line two"])

const WaveFX := preload("res://ui/rich_text_wave.gd")
const W := 168

var _mgr                      # Markers layer
var _tok := 0
var _lines: Array = []
var _who := ""
var _done := Callable()
var _idx := 0
var _tw: Tween
var _body: RichTextLabel
var _cue: RichTextLabel


## Anchors a bubble over `anchor` at `offset`; returns the marker
## token so the caller can release() early if the scene moves on.
static func say(mgr, anchor: Node2D, offset: Vector2, who: String,
		lines: Array, on_done := Callable()) -> int:
	var tok: int = mgr.marker(anchor, offset)
	var host: Control = mgr.marker_control(tok)
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	var b := DialogueBubble.new()
	b._mgr = mgr
	b._tok = tok
	b._who = who
	b._lines = lines.duplicate()
	b._done = on_done
	host.add_child(b)
	b._build()
	b._speak()
	return tok


func _build() -> void:
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(W, 30)
	chip.size = chip.custom_minimum_size
	chip.add_theme_stylebox_override("panel", UIKit.flat("glass_chip"))
	add_child(chip)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 6)
	m.add_theme_constant_override("margin_top", 5)
	m.add_theme_constant_override("margin_bottom", 4)
	chip.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	m.add_child(v)
	if _who != "":
		var n := UIKit.label_for(_who, UITokens.TypeRole.CAPTION,
			UITokens.DIM)
		v.add_child(n)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.install_effect(WaveFX.new())
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.fit_content = true
	_body.scroll_active = false
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_override("normal_font",
		UIKit.font_for(UITokens.TypeRole.BODY))
	_body.add_theme_font_size_override("normal_font_size",
		UIKit.type_size(UITokens.TypeRole.BODY))
	_body.add_theme_color_override("default_color", UITokens.PAPER)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_body)
	_cue = RichTextLabel.new()
	_cue.bbcode_enabled = true
	_cue.install_effect(WaveFX.new())
	_cue.fit_content = true
	_cue.scroll_active = false
	_cue.size_flags_horizontal = Control.SIZE_SHRINK_END
	_cue.add_theme_font_override("normal_font",
		UIKit.font_for(UITokens.TypeRole.CAPTION))
	_cue.add_theme_font_size_override("normal_font_size",
		UIKit.type_size(UITokens.TypeRole.CAPTION))
	_cue.add_theme_color_override("default_color", UITokens.GOLD)
	_cue.append_text("[wave]▼[/wave]")
	_cue.visible = false
	v.add_child(_cue)
	# tail: the little down-arrow under the chip points at the speaker
	var tail := UIKit.icon_rect("arrow_down", UITokens.LINE, 8)
	tail.position = Vector2(W * 0.5 - 4, chip.custom_minimum_size.y)
	# height reflows with content — keep the tail pinned to the bottom
	chip.resized.connect(func():
		tail.position.y = chip.size.y - 2)
	add_child(tail)
	chip.gui_input.connect(_on_tap)


func _speak() -> void:
	if _idx >= _lines.size():
		_finish()
		return
	_body.clear()
	_body.append_text(String(_lines[_idx]))
	_cue.visible = false
	_tw = UIFeel.typewriter(_body, func(): _cue.visible = true)


func _on_tap(ev: InputEvent) -> void:
	var tap: bool = (ev is InputEventMouseButton and ev.pressed
		and ev.button_index == MOUSE_BUTTON_LEFT) \
		or (ev is InputEventScreenTouch and ev.pressed)
	if not tap:
		return
	if _tw != null:
		_tw.kill()
		_tw = null
		_body.visible_characters = -1
		_cue.visible = true
		UIFeel.sfx("press")
		return
	_idx += 1
	if _idx < _lines.size():
		UIFeel.sfx("press")
		_speak()
	else:
		_finish()


func _finish() -> void:
	UIFeel.sfx("close")
	_mgr.release(_tok)
	if _done.is_valid():
		_done.call()
