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
signal settings_pressed
signal journal_pressed

var coins_label: Label
var day_label: Label
var rating_label: Label
var phase_button: Button
var tray: EveningTray                      # UI-020 evening seating band
var journal_btn: Button
var journal_badge: Label
var _tl: VBoxContainer
var _tr: VBoxContainer
# debug-gated (null when UITokens.debug_ui() is false)
var dev_label: Label
var report_label: Label
var status_label: Label


func _ready() -> void:
    theme = UITheme.theme()
    # a Control under a CanvasLayer gets no parent area — anchors can't
    # resolve — so the root sizes itself from the viewport outright
    # (children may then anchor against it normally)
    size = get_viewport_rect().size
    get_viewport().size_changed.connect(_on_viewport_resized)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_to_group("hud")            # settings sheet finds us for handedness
    _build()
    _apply_insets()


func _on_viewport_resized() -> void:
    size = get_viewport_rect().size
    _apply_insets()


## Notch/punch-hole insets — keep chrome inside the display safe area
## (UI-015; zero on desktop).  Edge stacks shift by the matching inset.
func _apply_insets() -> void:
    var ins := UITokens.safe_insets(size)
    if _tl:
        _tl.position = Vector2(UITokens.MARGIN + ins["l"],
            6 + ins["t"])
    if _tr:
        _tr.offset_left = -(UITokens.MARGIN + ins["r"] + 74)
        _tr.offset_right = -(UITokens.MARGIN + ins["r"])
        _tr.offset_top = 6 + ins["t"]
    apply_handedness()


## §8.3 journal badge: unread-letter count on the journal button;
## hidden at zero (a badge must mean something, not decorate).
func set_journal_badge(n: int) -> void:
    if journal_badge:
        journal_badge.text = str(n) if n > 0 else ""


## §17.4 left-handed layout (UI-036): the action side mirrors — phase
## button and tray swap left/right so the dominant thumb stays home.
## Called by _apply_insets and live by the settings sheet.
func apply_handedness() -> void:
    var ins := UITokens.safe_insets(size)
    var lh := UIKit.left_handed
    if phase_button:
        phase_button.set_anchors_preset(
            Control.PRESET_BOTTOM_LEFT if lh
            else Control.PRESET_BOTTOM_RIGHT)
        if lh:
            phase_button.offset_left = 10 + ins["l"]
            phase_button.offset_right = \
                UITokens.MIN_TOUCH + 48 + 10 + ins["l"]
        else:
            phase_button.offset_left = \
                -(UITokens.MIN_TOUCH + 48 + 10 + ins["r"])
            phase_button.offset_right = -(10 + ins["r"])
        phase_button.offset_top = -(UITokens.MIN_TOUCH + 10 + ins["b"])
        phase_button.offset_bottom = -(10 + ins["b"])
    if tray:
        # the tray shares the bottom band with the phase button: it
        # stops ~6px short of the button's edge so they can never
        # overlap at any aspect (cards scroll inside if they overflow)
        tray.offset_top = -(EveningTray.CARD_H + 10 + ins["b"])
        tray.offset_bottom = -(10 + ins["b"])
        if lh:
            tray.offset_left = UITokens.MIN_TOUCH + 48 + 16 + ins["l"]
            tray.offset_right = -(UITokens.MARGIN + ins["r"])
        else:
            tray.offset_left = UITokens.MARGIN + ins["l"]
            tray.offset_right = \
                -(UITokens.MIN_TOUCH + 48 + 16 + ins["r"])


func _build() -> void:
    # --------------------------------- top-left: coins + day/weather
    # VBox stack — left edge on MARGIN, 6px top, SP1 row separation.
    _tl = VBoxContainer.new()
    _tl.name = "StatusStack"
    _tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _tl.position = Vector2(UITokens.MARGIN, 6)
    _tl.size = Vector2(96, 44)
    _tl.add_theme_constant_override("separation", UITokens.SP1)
    add_child(_tl)
    coins_label = UIKit.pill(_tl, Vector2(78, 20), "coin", "")
    day_label = UIKit.pill(_tl, Vector2(96, 20), "clear", "")

    # -------------------------------- top-right: rating + journal badge
    # VBox pinned to the right margin; children shrink-end so their right
    # edges ride the margin.  The journal badge keeps its 4px inset from
    # the margin via a trailing spacer.
    _tr = VBoxContainer.new()
    _tr.name = "RatingStack"
    _tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    _tr.offset_left = -(UITokens.MARGIN + 74)
    _tr.offset_right = -UITokens.MARGIN
    _tr.offset_top = 6
    _tr.offset_bottom = 50
    _tr.add_theme_constant_override("separation", UITokens.SP1)
    add_child(_tr)
    rating_label = UIKit.pill(_tr, Vector2(74, 20), "star_full", "—",
        Control.SIZE_SHRINK_END)
    var jrow := HBoxContainer.new()
    jrow.name = "JournalRow"
    jrow.alignment = BoxContainer.ALIGNMENT_END
    jrow.add_theme_constant_override("separation", 4)
    _tr.add_child(jrow)
    # settings gear — the §17.4 sheet (UI-036); full MIN_TOUCH target
    var gear := UIKit.icon_btn(jrow, "gear")
    gear.pressed.connect(func(): settings_pressed.emit())
    # journal button + unread-letters badge (UI-030 §8.3)
    journal_btn = UIKit.icon_btn(jrow, "journal")
    journal_btn.pressed.connect(func(): journal_pressed.emit())
    journal_badge = UIKit.label_for("", UITokens.TypeRole.CAPTION,
        UITokens.GOLD)
    journal_badge.position = Vector2(
        UITokens.MIN_TOUCH - 14, UITokens.MIN_TOUCH - 16)
    journal_badge.size = Vector2(14, 12)
    journal_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    journal_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    journal_btn.add_child(journal_badge)
    UIKit.spacer(jrow, UITokens.SP1)

    # ---------------- bottom-right: phase button (click = Goodnight)
    # MIN_TOUCH: 88x40 hit area, real Button -> pressed/hover/focus
    # states come free (UI-008).
    phase_button = UIKit.btn(self, Rect2(0, 0, 0, 0), "", "gold")
    phase_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    phase_button.offset_left = -UITokens.MIN_TOUCH - 48 - 10
    phase_button.offset_top = -UITokens.MIN_TOUCH - 10
    phase_button.offset_right = -10
    phase_button.offset_bottom = -10
    phase_button.pressed.connect(func(): phase_pressed.emit())

    # ---------------- bottom-left/center: the evening tray (UI-020)
    # Bottom-anchored band of guest cards; hidden while the board is
    # closed (Night phase shows nothing).  Its breakdown strip rides
    # just above it — see evening_tray.gd.
    tray = EveningTray.new()
    tray.name = "EveningTray"
    tray.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    tray.offset_top = -(EveningTray.CARD_H + 10)
    tray.offset_right = -(UITokens.MIN_TOUCH + 48 + 16)
    tray.offset_bottom = -10
    tray.visible = false
    add_child(tray)

    # --------------------------------------------- dev chrome (gated)
    if UITokens.debug_ui():
        # third row of the left stack -> lands at (8, 54)
        dev_label = UIKit.label_for(
            "Hồ Chào Mào — phở, đá cầu, nón lá, bánh mì",
            UITokens.TypeRole.BODY)
        _tl.add_child(dev_label)
        _tl.size.y += UITokens.SP1 + 13

        report_label = UIKit.label_for("", UITokens.TypeRole.BODY)
        report_label.position = Vector2(150, 8)
        add_child(report_label)

        status_label = UIKit.label_for("", UITokens.TypeRole.BODY)
        status_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
        status_label.offset_left = 200
        status_label.offset_top = -13
        add_child(status_label)


# ------------------------------------------------------------ setters

func set_phase(text: String) -> void:
    phase_button.text = text


func set_rating(text: String) -> void:
    rating_label.text = text


func set_coins(text: String) -> void:
    coins_label.text = text
    UIKit.pill_fit(coins_label)


## text + weather id ("clear"/"rain"/…) — swaps the pill's icon glyph.
func set_day(text: String, weather: String) -> void:
    day_label.text = text
    var ico: TextureRect = day_label.get_parent().get_meta("icon")
    ico.texture = UIKit.weather_icon(weather)
    ico.modulate = UIKit.GLYPH_TINT.get(weather, UITokens.PAPER)
    UIKit.pill_fit(day_label)


func set_status(text: String) -> void:
    if status_label:
        status_label.text = text


func set_report(text: String) -> void:
    if report_label:
        report_label.text = text


func toggle_dev() -> void:
    if dev_label:
        dev_label.visible = not dev_label.visible
