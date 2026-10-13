class_name AdoptSheet
extends Panel
## The adoption beat (§9): bond reaching Friend means the stray stayed.
## One small prompt — a name field over the usual sheet chrome.  The
## sim verb is Game.adopt_dog; this emits the chosen name and closes.

signal named(n: String)

const W := 260
const H := 150

var _edit: LineEdit


static func make(cur: String) -> AdoptSheet:
	var s := AdoptSheet.new()
	s._edit_text = cur
	s._build()
	return s


var _edit_text := ""


func _ready() -> void:
	position = (get_viewport_rect().size - size) / 2.0


func _build() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	add_theme_stylebox_override("panel", UIKit.flat("sheet"))
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_bottom", 12)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	var t := UIKit.label_for(tr("dog_adopted_t"),
		UITokens.TypeRole.DISPLAY, UITokens.PAPER)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := UIKit.label_for(tr("dog_adopted_sub"),
		UITokens.TypeRole.CAPTION, UITokens.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	_edit = LineEdit.new()
	_edit.text = _edit_text
	_edit.max_length = 12
	_edit.custom_minimum_size = Vector2(0, UITokens.MIN_TOUCH)
	_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_edit)
	var ok := UIKit.btn(v, Vector2(140, UITokens.MIN_TOUCH),
		tr("dog_adopted_ok"), "gold", Control.SIZE_SHRINK_CENTER)
	ok.set_meta("ui_primary", true)
	ok.pressed.connect(_confirm)
	_edit.text_submitted.connect(func(_n): _confirm())


func _confirm() -> void:
	named.emit(_edit.text.strip_edges())
	var pm := get_parent() as PanelManager
	if pm:
		pm.close()
