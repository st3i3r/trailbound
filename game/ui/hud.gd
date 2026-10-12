class_name HUD
extends Control
## Screen-space HUD chrome — the full-rect root the scene idles/fades.
## Layout is anchor-driven (corner stacks on MARGIN, the phase button
## glued to the bottom-right edge).  World-pinned chrome — the fire
## bubble — lives on the markers tier, not here.
##
## Exposes: set_phase(), set_rating(), set_status(), set_report(),
## toggle_dev(); members phase_button / dev_label / report_label /
## status_label (the three debug labels exist only under
## UITokens.debug_ui() — prod shots stay clean).  Signal phase_pressed
## fires on left-click of the phase button.

signal phase_pressed

var coins_label: Label
var day_label: Label
var rating_label: Label
var phase_button: Panel
var phase_label: Label
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
    coins_label = UIKit.pill(tl, Vector2(78, 20), "coin", "")
    day_label = UIKit.pill(tl, Vector2(96, 20), "clear", "")

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
    rating_label = UIKit.pill(tr, Vector2(74, 20), "star_full", "—",
        Control.SIZE_SHRINK_END)
    var jrow := HBoxContainer.new()
    jrow.name = "JournalRow"
    jrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    jrow.alignment = BoxContainer.ALIGNMENT_END
    jrow.add_theme_constant_override("separation", 0)
    tr.add_child(jrow)
    UIKit.pill(jrow, Vector2(28, 20), "journal", "")
    UIKit.spacer(jrow, UITokens.SP1)

    # ---------------- bottom-right: phase button (click = Goodnight)
    # MIN_TOUCH: 88x40 hit area, label centred inside.
    phase_button = Panel.new()
    phase_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    phase_button.offset_left = -UITokens.MIN_TOUCH - 48 - 10
    phase_button.offset_top = -UITokens.MIN_TOUCH - 10
    phase_button.offset_right = -10
    phase_button.offset_bottom = -10
    phase_button.add_theme_stylebox_override("panel",
        UIKit.nine("hud_banner_flat", UIKit.PILL_INS))
    phase_button.mouse_filter = Control.MOUSE_FILTER_STOP
    phase_button.gui_input.connect(_on_phase_gui_input)
    add_child(phase_button)
    phase_label = UIKit.label_for("EVENING", UITokens.TypeRole.HEAD,
        UITokens.INK)
    phase_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    phase_button.add_child(phase_label)

    # --------------------------------------------- dev chrome (gated)
    if UITokens.debug_ui():
        # third row of the left stack -> lands at (8, 54)
        dev_label = UIKit.label_for(
            "Hồ Chào Mào — phở, đá cầu, nón lá, bánh mì",
            UITokens.TypeRole.BODY)
        tl.add_child(dev_label)
        tl.size.y += UITokens.SP1 + 13

        report_label = UIKit.label_for("", UITokens.TypeRole.BODY)
        report_label.position = Vector2(150, 8)
        add_child(report_label)

        status_label = UIKit.label_for("", UITokens.TypeRole.BODY)
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


func set_coins(text: String) -> void:
    coins_label.text = text


## text + weather id ("clear"/"rain"/…) — swaps the pill's icon glyph.
func set_day(text: String, weather: String) -> void:
    day_label.text = text
    var ico: TextureRect = day_label.get_parent().get_meta("icon")
    ico.texture = UIKit.weather_icon(weather)


func set_status(text: String) -> void:
    if status_label:
        status_label.text = text


func set_report(text: String) -> void:
    if report_label:
        report_label.text = text


func toggle_dev() -> void:
    if dev_label:
        dev_label.visible = not dev_label.visible
