class_name SettingsSheet
extends Panel
## Settings (UI-036, §17.4) — one sheet, sections as caption rows,
## every value stored via Game.setting() (persist + apply + save).
##
## Row vocabulary:
##   toggle  — row-as-button (full 40 px target), check chip on right
##   stepper — label + −/+ icon_btns with a live value readout
##   nav     — row-as-button with a trailing arrow (credits, privacy)
##
## Live-applied today: volumes (bus volumes on Music/Ambience/SFX),
## haptics gate, reduced motion, text scale (+2 px on text roles —
## surfaces rebuilt AFTER the change pick it up; the sheet itself
## rebuilds in place), language (same rebuild rule), left-handed HUD.
## Stored for their systems: reduced flashing (vfx pass), assist mode
## (fishing §7.2), ranger's tips (hints), reminder/crew notifications
## (scheduling P3), Remove Ads + Restore (billing P3 — shown disabled).

const W := 304
const H := 292

var _v: VBoxContainer


static func make() -> SettingsSheet:
    var s := SettingsSheet.new()
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
    m.add_theme_constant_override("margin_left", 14)
    m.add_theme_constant_override("margin_right", 14)
    m.add_theme_constant_override("margin_bottom", 12)
    add_child(m)
    _v = VBoxContainer.new()
    _v.add_theme_constant_override("separation", 5)
    m.add_child(_v)
    # close X floats on the band corner — first chrome-glyph button
    var x := UIKit.icon_btn(self, "close")
    x.position = Vector2(W - UITokens.MIN_TOUCH - 8, 4)
    x.pressed.connect(_close)
    _build_main()


func _close() -> void:
    var pm := get_parent() as PanelManager
    if pm:
        pm.close()


func _rebuild() -> void:
    ## text size / language changes redraw the whole sheet in place —
    ## other surfaces pick them up on their next build.  Keep the
    ## scroll position so a mid-list toggle doesn't jump to the top.
    var scroll: ScrollContainer = _v.get_node_or_null("Rows")
    var pos: int = scroll.scroll_vertical if scroll else 0
    for c in _v.get_children():
        c.queue_free()
    _build_main()
    var s2: ScrollContainer = _v.get_node_or_null("Rows")
    if s2 and pos > 0:
        (func(): s2.scroll_vertical = pos).call_deferred()


func _build_main() -> void:
    var title := UIKit.label_for(tr("set_title"),
        UITokens.TypeRole.DISPLAY, UITokens.PAPER)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _v.add_child(title)

    var scroll := ScrollContainer.new()
    scroll.name = "Rows"
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _v.add_child(scroll)
    var rows := VBoxContainer.new()
    rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rows.add_theme_constant_override("separation", UITokens.SP1)
    scroll.add_child(rows)

    _sec(rows, "set_sec_sound")
    _step(rows, "set_music", "music", "music")
    _step(rows, "set_ambience", "leaf", "ambience")
    _step(rows, "set_sfx", "volume", "sfx")
    _sec(rows, "set_sec_feel")
    _toggle(rows, "set_haptics", "hand", "haptics")
    _toggle(rows, "set_reduced_motion", "pause", "reduced_motion")
    _toggle(rows, "set_reduced_flash", "eye_off", "reduced_flashing")
    _sec(rows, "set_sec_display")
    _choice(rows, "set_text_size", "book_open", "text_size",
        ["normal", "large"], "set_size_")
    _toggle(rows, "set_left_handed", "back", "left_handed")
    _sec(rows, "set_sec_game")
    _choice(rows, "set_language", "scroll", "language",
        ["en", "vi"], "")
    _toggle(rows, "set_tips", "lightbulb", "rangers_tips")
    _toggle(rows, "set_assist", "question", "assist_mode")
    _sec(rows, "set_sec_alerts")
    _toggle(rows, "set_daily_rem", "bell", "daily_reminder")
    _toggle(rows, "set_crew_notif", "users", "crew_notification")
    _sec(rows, "set_sec_store")
    _nav(rows, "set_remove_ads", "coins", Callable(), true)
    _nav(rows, "set_restore", "undo", Callable(), true)
    _sec(rows, "set_sec_about")
    _nav(rows, "set_credits", "info", _show_credits)
    _nav(rows, "set_privacy", "eye",
        func(): Ads.request_consent())

    var ver := UIKit.label_for("v%s" % ProjectSettings.get_setting(
        "application/config/version", "0.0.0"),
        UITokens.TypeRole.CAPTION, UITokens.DIM)
    ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _v.add_child(ver)


# ------------------------------------------------------------- row kit

func _sec(parent: Control, key: String) -> void:
    var l := UIKit.label_for(tr(key).to_upper(),
        UITokens.TypeRole.CAPTION, UITokens.DIM)
    l.custom_minimum_size.y = 14
    parent.add_child(l)


## Row-as-button base: 40 px target, chip-glyph left, HEAD label.
func _row(parent: Control, label_key: String, icon: String) -> Button:
    var b := Button.new()
    b.custom_minimum_size = Vector2(0, UITokens.MIN_TOUCH)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.focus_mode = Control.FOCUS_ALL
    b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
    b.add_theme_stylebox_override("hover", UIKit.flat("glass_chip"))
    b.add_theme_stylebox_override("pressed",
        UIKit.flat("glass_chip", 0.82))
    b.add_theme_stylebox_override("focus", UIKit.focus_box())
    UIKit.pressable(b, false)            # row-wide buttons: no squash
    var h := HBoxContainer.new()
    h.set_anchors_preset(Control.PRESET_FULL_RECT)
    h.mouse_filter = Control.MOUSE_FILTER_IGNORE
    h.add_theme_constant_override("separation", 8)
    h.alignment = BoxContainer.ALIGNMENT_CENTER
    b.add_child(h)
    h.add_child(UIKit.icon_rect(icon))
    var l := UIKit.label_for(tr(label_key), UITokens.TypeRole.HEAD,
        UITokens.PAPER)
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    h.add_child(l)
    parent.add_child(b)
    return b


func _toggle(parent: Control, label_key: String, icon: String,
             key: String) -> void:
    var b := _row(parent, label_key, icon)
    var h: HBoxContainer = b.get_child(0)
    var check := UIKit.icon_rect("check", UITokens.GREEN)
    check.visible = bool(Game.settings.get(key, false))
    h.add_child(check)
    b.pressed.connect(func() -> void:
        var on: bool = not bool(Game.settings.get(key, false))
        Game.setting(key, on)
        check.visible = on
        _after_change(key))


## −/+ stepper over an int range (volumes 0..3).
func _step(parent: Control, label_key: String, icon: String,
           key: String, lo := 0, hi := 3) -> void:
    var holder := HBoxContainer.new()
    holder.custom_minimum_size = Vector2(0, UITokens.MIN_TOUCH)
    holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    holder.alignment = BoxContainer.ALIGNMENT_CENTER
    holder.add_theme_constant_override("separation", 8)
    holder.add_child(UIKit.icon_rect(icon))
    var l := UIKit.label_for(tr(label_key), UITokens.TypeRole.HEAD,
        UITokens.PAPER)
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    holder.add_child(l)
    var minus := UIKit.icon_btn(holder, "minus")
    var val := UIKit.label_for("", UITokens.TypeRole.HEAD, UITokens.PAPER)
    val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    val.custom_minimum_size.x = 16
    holder.add_child(val)
    var plus := UIKit.icon_btn(holder, "plus")
    var show := func(): val.text = str(int(Game.settings.get(key, 0)))
    show.call()
    minus.pressed.connect(func() -> void:
        var n: int = clampi(int(Game.settings.get(key, 0)) - 1, lo, hi)
        Game.setting(key, n)
        show.call())
    plus.pressed.connect(func() -> void:
        var n: int = clampi(int(Game.settings.get(key, 0)) + 1, lo, hi)
        Game.setting(key, n)
        show.call())
    parent.add_child(holder)


## −/+ over a list of discrete string options (language, text size).
## `label_prefix` maps option -> tr() key; empty = show the raw id.
func _choice(parent: Control, label_key: String, icon: String,
             key: String, options: Array, label_prefix: String) -> void:
    var holder := HBoxContainer.new()
    holder.custom_minimum_size = Vector2(0, UITokens.MIN_TOUCH)
    holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    holder.alignment = BoxContainer.ALIGNMENT_CENTER
    holder.add_theme_constant_override("separation", 8)
    holder.add_child(UIKit.icon_rect(icon))
    var l := UIKit.label_for(tr(label_key), UITokens.TypeRole.HEAD,
        UITokens.PAPER)
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    holder.add_child(l)
    var minus := UIKit.icon_btn(holder, "minus")
    var val := UIKit.label_for("", UITokens.TypeRole.HEAD, UITokens.PAPER)
    val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    val.custom_minimum_size.x = 42
    holder.add_child(val)
    var plus := UIKit.icon_btn(holder, "plus")
    var show := func() -> void:
        var cur: String = String(Game.settings.get(key, options[0]))
        val.text = cur.to_upper() if label_prefix == "" \
            else tr(label_prefix + cur)
    show.call()
    var step_to := func(dir: int) -> void:
        var i: int = options.find(Game.settings.get(key, options[0]))
        i = (i + dir + options.size()) % options.size()
        Game.setting(key, options[i])
        show.call()
        _after_change(key)
    minus.pressed.connect(func(): step_to.call(-1))
    plus.pressed.connect(func(): step_to.call(1))
    parent.add_child(holder)


func _nav(parent: Control, label_key: String, icon: String,
          cb: Callable, disabled := false) -> void:
    var b := _row(parent, label_key, icon)
    var h: HBoxContainer = b.get_child(0)
    if disabled:
        var tag := UIKit.label_for(tr("set_soon"),
            UITokens.TypeRole.CAPTION, UITokens.DIM)
        h.add_child(tag)
        b.disabled = true
        return
    h.add_child(UIKit.icon_rect("arrow_right", UITokens.DIM))
    b.pressed.connect(cb)


## Side-effects beyond the stored value.
func _after_change(key: String) -> void:
    match key:
        "text_size", "language":
            _rebuild()
        "left_handed":
            var hud := get_tree().get_first_node_in_group("hud")
            if hud and hud.has_method("apply_handedness"):
                hud.apply_handedness()


# ------------------------------------------------------------ credits

func _show_credits() -> void:
    for c in _v.get_children():
        c.queue_free()
    var title := UIKit.label_for(tr("set_credits").to_upper(),
        UITokens.TypeRole.HEAD, UITokens.PAPER)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _v.add_child(title)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _v.add_child(scroll)
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation", 6)
    scroll.add_child(list)
    for key in ["set_credit_icons", "set_credit_font", "set_credit_us",
                "set_offline_note"]:
        var l := UIKit.label_for(tr(key), UITokens.TypeRole.BODY,
            UITokens.PAPER)
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        list.add_child(l)
    var back := UIKit.btn(_v, Vector2(120, UITokens.MIN_TOUCH),
        tr("set_back"), "pill", Control.SIZE_SHRINK_CENTER)
    back.pressed.connect(_rebuild)
