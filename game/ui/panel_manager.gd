class_name PanelManager
extends CanvasLayer
## Modal panel stack on the PANEL elevation tier (above HUD, below MODAL).
##
## open(panel) pushes a Control onto the stack: a paper-dark dimmer fades
## in under it and eats clicks so panels are modal.  close() pops the top
## panel; top() returns the current one (null when empty).  Android back
## / ui_cancel closes the top panel before the scene ever sees it.
## stack_changed fires on every push/pop so the HUD can react (dim its
## own chrome, suspend input, …).
##
## Scaffold — no panels exist yet; first users will be the guest card,
## journal and settings sheets.

signal stack_changed

var _stack: Array[Control] = []
var _dimmer: ColorRect
var _prev_focus: Control                   # focus owner to restore on pop


func _init() -> void:
    layer = UITokens.Tier.PANEL


func _ready() -> void:
    _dimmer = ColorRect.new()
    _dimmer.name = "Dimmer"
    _dimmer.color = UITokens.DIMMER
    # Controls under a CanvasLayer get no parent area — size the scrim
    # from the viewport directly (same pattern as HUD's root)
    _dimmer.size = get_viewport().get_visible_rect().size
    get_viewport().size_changed.connect(
        func(): _dimmer.size = get_viewport().get_visible_rect().size)
    _dimmer.visible = false
    _dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    # §17.6: a tap on the scrim dismisses the top sheet
    _dimmer.gui_input.connect(func(e: InputEvent) -> void:
        if e is InputEventMouseButton and e.pressed \
                and e.button_index == MOUSE_BUTTON_LEFT:
            close())
    add_child(_dimmer)
    # keep the dimmer under whatever panel is on top
    move_child(_dimmer, 0)


func open(panel: Control) -> void:
    _dimmer.visible = true
    _dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(panel)                    # after the dimmer: draws above
    _stack.append(panel)
    panel.theme = UITheme.theme()       # raw children inherit kit styles
    _animate_in(panel, _stack.size() == 1)
    # UI-016: modal focus — remember the owner, hand the panel's first
    # focusable button control once it exists on screen
    var vp := get_viewport()
    _prev_focus = vp.gui_get_focus_owner()
    _grab_panel_focus.call_deferred(panel)
    stack_changed.emit()


func close() -> void:
    var p := top()
    if p == null:
        return
    _stack.pop_back()
    _animate_out(p)
    if _stack.is_empty():
        _animate_dimmer(false)
    _restore_focus()
    stack_changed.emit()


func _grab_panel_focus(p: Control) -> void:
    if not is_instance_valid(p):
        return
    var buttons := p.find_children("", "Button", true, false)
    if not buttons.is_empty():
        (buttons[0] as Button).grab_focus()


func _restore_focus() -> void:
    var vp := get_viewport()
    if is_instance_valid(_prev_focus):
        _prev_focus.grab_focus()
    else:
        vp.gui_release_focus()
    _prev_focus = null


func _animate_in(p: Control, first_panel: bool) -> void:
    ## Scale+fade pop for the panel; the scrim only fades in on the
    ## first panel (re-fading per push would flash the stack).
    if first_panel:
        _animate_dimmer(true)
    else:
        _dimmer.modulate.a = 1.0
    p.pivot_offset = p.size / 2.0
    p.scale = Vector2(0.96, 0.96)
    p.modulate.a = 0.0
    var tw := create_tween().set_parallel()
    tw.tween_property(p, "scale", Vector2.ONE, 0.16)
    tw.tween_property(p, "modulate:a", 1.0, 0.16)


func _animate_out(p: Control) -> void:
    var tw := create_tween().set_parallel()
    tw.tween_property(p, "scale", Vector2(0.96, 0.96), 0.12)
    tw.tween_property(p, "modulate:a", 0.0, 0.12)
    tw.chain().tween_callback(p.queue_free)


func _animate_dimmer(on: bool) -> void:
    if on:
        _dimmer.visible = true
        _dimmer.modulate.a = 0.0
        create_tween().tween_property(_dimmer, "modulate:a", 1.0, 0.15)
    else:
        var tw := create_tween()
        tw.tween_property(_dimmer, "modulate:a", 0.0, 0.12)
        tw.tween_callback(_dimmer.hide)


func top() -> Control:
    return _stack.back() if not _stack.is_empty() else null


func _unhandled_input(event: InputEvent) -> void:
    # Android's back gesture lands here as ui_cancel
    if event.is_action_pressed("ui_cancel") and top() != null:
        close()
        get_viewport().set_input_as_handled()
