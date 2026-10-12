class_name HUD
extends Control
## Screen-space HUD chrome — the full-rect root the scene idles/fades.
## Layout is anchor-driven (corner stacks on MARGIN, bottom items glued
## to the bottom edge); absolute placement survives only where a
## container can't express it — the fire-proximity bubble pinned over a
## world position.  At the 640x360 design size the rects below are
## pixel-identical to the original fixed coordinates.
##
## Exposes: set_phase(), set_rating(), set_status(), set_report(),
## toggle_dev(); members phase_button / dev_label / report_label /
## status_label (the three debug labels exist only under
## UITokens.debug_ui() — prod shots stay clean).  Signal phase_pressed
## fires on left-click of the phase button.

signal phase_pressed

var fire_pos := Vector2(326, 246)            # set before add_child

var coins_label: Label
var day_label: Label
var rating_label: Label
var phase_button: Panel
var phase_label: Label
var fire_bubble: Panel
# debug-gated (null when UITokens.debug_ui() is false)
var dev_label: Label
var report_label: Label
var status_label: Label


func _ready() -> void:
    # a Control under a CanvasLayer gets no parent area — anchors can't
    # resolve — so the root sizes itself from the viewport outright
    # (children may then anchor against it normally)
    size = get_viewport_rect().size
    get_viewport().size_changed.connect(
        func(): size = get_viewport_rect().size)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _build()


func _build() -> void:
    # --------------------------------- top-left: coins + day/weather
    # VBox stack — left edge on MARGIN, 6px top, SP1 row separation.
    var tl := VBoxContainer.new()
    tl.name = "StatusStack"
    tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tl.position = Vector2(UITokens.MARGIN, 6)
    tl.size = Vector2(96, 44)
    tl.add_theme_constant_override("separation", UITokens.SP1)
    add_child(tl)
    coins_label = UIKit.pill(tl, Vector2(78, 20), "I1_4",
        "%dc" % Game.coins)
    var st: Dictionary = Game.site_state()
    day_label = UIKit.pill(tl, Vector2(96, 20), "I1_49",
        "DAY %d · %s" % [Game.day, st["weather"].to_upper()])

    # -------------------------------- top-right: rating + journal badge
    # VBox pinned to the right margin; children shrink-end so their right
    # edges ride the margin.  The journal badge keeps its 4px inset from
    # the margin via a trailing spacer.
    var tr := VBoxContainer.new()
    tr.name = "RatingStack"
    tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    tr.offset_left = -(UITokens.MARGIN + 74)
    tr.offset_right = -UITokens.MARGIN
    tr.offset_top = 6
    tr.offset_bottom = 50
    tr.add_theme_constant_override("separation", UITokens.SP1)
    add_child(tr)
    rating_label = UIKit.pill(tr, Vector2(74, 20), "I1_15", "—",
        Control.SIZE_SHRINK_END)
    var jrow := HBoxContainer.new()
    jrow.name = "JournalRow"
    jrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    jrow.alignment = BoxContainer.ALIGNMENT_END
    jrow.add_theme_constant_override("separation", 0)
    tr.add_child(jrow)
    UIKit.pill(jrow, Vector2(28, 20), "I1_26", "")
    UIKit.spacer(jrow, UITokens.SP1)

    # ------------------ bottom-left: avatar medallion + toolbar chrome
    # Anchored art, not laid out — glue to the bottom edge with the same
    # rects the comp used (design space 640x360).
    var med := TextureRect.new()
    med.texture = UIKit.tex("ui/hud_medallion_empty")
    med.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    med.offset_left = 2
    med.offset_top = -60
    med.offset_right = 69
    med.offset_bottom = -2
    med.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(med)
    var tb := TextureRect.new()
    tb.texture = UIKit.tex("ui/hud_toolbar")
    tb.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    tb.offset_left = 30
    tb.offset_top = -28
    tb.offset_right = 191
    tb.offset_bottom = -9
    tb.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(tb)

    # ---------------- bottom-right: phase button (click = Goodnight)
    phase_button = Panel.new()
    phase_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    phase_button.offset_left = -84
    phase_button.offset_top = -34
    phase_button.offset_right = -10
    phase_button.offset_bottom = -10
    phase_button.add_theme_stylebox_override("panel",
        UIKit.nine("hud_banner_flat", UIKit.PILL_INS))
    phase_button.mouse_filter = Control.MOUSE_FILTER_STOP
    phase_button.gui_input.connect(_on_phase_gui_input)
    add_child(phase_button)
    phase_label = UIKit.label("EVENING", 8, UIKit.font_head(),
        UITokens.INK)
    phase_label.position = Vector2(14, 7)
    phase_button.add_child(phase_label)

    # ----------------- fire-proximity bubble (world-pinned, absolute —
    # a marker-layer concern once bubbles follow actors; fixed for now)
    fire_bubble = UIKit.panel(self,
        Rect2(fire_pos.x - 61, 172, 122, 41), "bubble_prompt")
    var fico := TextureRect.new()
    fico.texture = UIKit.tex("icons/I1_42")
    fico.position = Vector2(10, 3)
    fico.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fire_bubble.add_child(fico)
    var bl := UIKit.label("FIRE", 8, UIKit.font_head(), UITokens.INK)
    bl.position = Vector2(30, 4)
    fire_bubble.add_child(bl)

    # --------------------------------------------- dev chrome (gated)
    if UITokens.debug_ui():
        # third row of the left stack -> lands at (8, 54)
        dev_label = UIKit.label(
            "Hồ Chào Mào — phở, đá cầu, nón lá, bánh mì",
            8, UIKit.font_body())
        tl.add_child(dev_label)
        tl.size.y += UITokens.SP1 + 13

        report_label = UIKit.label("", 8, UIKit.font_body())
        report_label.position = Vector2(150, 8)
        add_child(report_label)

        status_label = UIKit.label("", 8, UIKit.font_body())
        status_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
        status_label.offset_left = 200
        status_label.offset_top = -13
        add_child(status_label)


func _on_phase_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed \
            and event.button_index == MOUSE_BUTTON_LEFT:
        phase_pressed.emit()


# ------------------------------------------------------------ setters

func set_phase(text: String) -> void:
    phase_label.text = text


func set_rating(text: String) -> void:
    rating_label.text = text


func set_status(text: String) -> void:
    if status_label:
        status_label.text = text


func set_report(text: String) -> void:
    if report_label:
        report_label.text = text


func toggle_dev() -> void:
    if dev_label:
        dev_label.visible = not dev_label.visible
