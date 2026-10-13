class_name Ceremony
extends Control
## Ceremony overlay (UI-039): a milestone beat — keepsake collected,
## journal page completed, first five-star night.  Halftone-dark
## dimmer, a stamped glass card popping in with the "stamp" sfx and a
## ring of sparkles thrown outward; tap anywhere to dismiss.
##
##   Ceremony.play(layer, "keepsake", tr("cer_keepsake"), name)
##
## kind picks the card accent: keepsake/page → gold, fivestar → red.

const TINTS := {
	"keepsake": UITokens.GOLD, "page": UITokens.GOLD,
	"fivestar": UITokens.RED, "chapter": UITokens.GOLD,
}

var _done := false
var _on_done := Callable()


static func play(layer: CanvasLayer, kind: String, title: String,
		sub := "", icon_name_ := "sparkle",
		on_done := Callable()) -> void:
	var c := Ceremony.new()
	c._on_done = on_done
	layer.add_child(c)
	c._build(kind, title, sub, icon_name_)


func _build(kind: String, title: String, sub: String,
		icon_name_: String) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.07, 0.06, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var card := Panel.new()
	card.custom_minimum_size = Vector2(200, 96)
	card.add_theme_stylebox_override("panel", UIKit.flat("sheet"))
	var vc := VBoxContainer.new()
	vc.set_anchors_preset(Control.PRESET_FULL_RECT)
	vc.alignment = BoxContainer.ALIGNMENT_CENTER
	vc.add_theme_constant_override("separation", 4)
	card.add_child(vc)
	var tint: Color = TINTS.get(kind, UITokens.GOLD)
	var ic := UIKit.icon_rect(icon_name_, tint, 24)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vc.add_child(ic)
	var t := UIKit.label_for(title, UITokens.TypeRole.HEAD,
		UITokens.PAPER)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vc.add_child(t)
	if sub != "":
		var s := UIKit.label_for(sub, UITokens.TypeRole.BODY,
			UITokens.DIM)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vc.add_child(s)
	var tap := UIKit.label_for(tr("cer_tap"), UITokens.TypeRole.CAPTION,
		UITokens.DIM)
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vc.add_child(tap)
	add_child(card)
	card.position = (get_viewport_rect().size - card.size) / 2.0

	# sparkle burst: six glyph sparks flung from the card centre, each
	# fading on the way out — cheap code confetti, no vfx asset needed
	var origin := card.position + card.size / 2.0
	for i in 6:
		var sp := UIKit.icon_rect("sparkle", tint, 12)
		sp.position = origin - Vector2(6, 6)
		add_child(sp)
		var dir := Vector2.RIGHT.rotated(i * TAU / 6.0 + 0.35)
		var tw := UIFeel.apply(sp.create_tween(), "panel_in")
		tw.set_parallel()
		tw.tween_property(sp, "position",
			origin + dir * 46 - Vector2(6, 6), UIFeel.dur("panel_in"))
		tw.tween_property(sp, "modulate:a", 0.0,
			UIFeel.dur("panel_in"))
		tw.chain().tween_callback(sp.queue_free)

	# card pops with the stamp thunk; dimmer fades in on its own token
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.9, 0.9)
	dim.modulate.a = 0.0
	UIFeel.apply(create_tween(), "dimmer") \
		.tween_property(dim, "modulate:a", 1.0, UIFeel.dur("dimmer"))
	UIFeel.apply(create_tween(), "panel_in") \
		.tween_property(card, "scale", Vector2.ONE,
			UIFeel.dur("panel_in"))
	UIFeel.sfx("stamp")
	UIFeel.haptic("pay")


func _dismiss() -> void:
	if _done:
		return
	_done = true
	UIFeel.sfx("close")
	queue_free()
	if _on_done.is_valid():
		_on_done.call()


func _gui_input(ev: InputEvent) -> void:
	var tap: bool = (ev is InputEventMouseButton and ev.pressed
		and ev.button_index == MOUSE_BUTTON_LEFT) \
		or (ev is InputEventScreenTouch and ev.pressed)
	if tap:
		_dismiss()


func _unhandled_key_input(ev: InputEvent) -> void:
	# keys/joypad path: any confirm/cancel dismisses the moment
	if _done:
		return
	if ev.is_action_pressed("ui_accept") or ev.is_action_pressed(
			"ui_cancel"):
		get_viewport().set_input_as_handled()
		_dismiss()
