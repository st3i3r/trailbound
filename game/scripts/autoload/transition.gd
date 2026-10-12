extends CanvasLayer
## Transition — the scene-change veil (UI-011 app shell).  A full-rect
## scrim one tier above MODAL: boot starts covered, each scene reveals
## itself, to_scene() covers -> swaps -> reveals.  The scrim eats input
## while opaque so taps can't reach a half-loaded scene.
##
## Eastward wipes with letterbox bands; a deep-forest fade reads right
## at our scale and costs one ColorRect until art direction wants more.

const VEIL := Color(0.07, 0.09, 0.05)        # deep forest, ~clear colour
const T_OUT := 0.22                          # cover time s
const T_IN := 0.30                           # reveal time s

var _rect: ColorRect
var _busy := false


func _init() -> void:
    layer = UITokens.Tier.MODAL + 10


func _ready() -> void:
    _rect = ColorRect.new()
    _rect.name = "Veil"
    _rect.color = VEIL
    _rect.size = get_viewport().get_visible_rect().size
    get_viewport().size_changed.connect(
        func(): _rect.size = get_viewport().get_visible_rect().size)
    _rect.mouse_filter = Control.MOUSE_FILTER_STOP
    _rect.modulate.a = 1.0                     # boot covered; reveal() opens
    add_child(_rect)


func reveal() -> void:
    ## Called by each scene's _ready() once its first frame exists.
    if _rect.modulate.a <= 0.0:
        return
    _rect.visible = true
    _rect.mouse_filter = Control.MOUSE_FILTER_STOP
    await _fade(0.0, T_IN)
    _rect.visible = false                       # alpha-0 still eats input
    _rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Headless runs and --shot paths can't wait out the fade — open now.
func snap_reveal() -> void:
    _rect.modulate.a = 0.0
    _rect.visible = false
    _rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func to_scene(path: String) -> void:
    if _busy:
        return
    _busy = true
    _rect.visible = true
    _rect.mouse_filter = Control.MOUSE_FILTER_STOP
    await _fade(1.0, T_OUT)
    get_tree().change_scene_to_file(path)
    # the new scene calls reveal() once its _ready() has laid out —
    # cover the load window in case _ready() is slow (first build)
    _busy = false


func _fade(a: float, t: float) -> void:
    var tw := create_tween()
    tw.tween_property(_rect, "modulate:a", a, t)
    await tw.finished
