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
    add_child(_dimmer)
    # keep the dimmer under whatever panel is on top
    move_child(_dimmer, 0)


func open(panel: Control) -> void:
    _dimmer.visible = true
    _dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(panel)                    # after the dimmer: draws above
    _stack.append(panel)
    stack_changed.emit()


func close() -> void:
    var p := top()
    if p == null:
        return
    _stack.pop_back()
    p.queue_free()
    _dimmer.visible = not _stack.is_empty()
    stack_changed.emit()


func top() -> Control:
    return _stack.back() if not _stack.is_empty() else null


func _unhandled_input(event: InputEvent) -> void:
    # Android's back gesture lands here as ui_cancel
    if event.is_action_pressed("ui_cancel") and top() != null:
        close()
        get_viewport().set_input_as_handled()
