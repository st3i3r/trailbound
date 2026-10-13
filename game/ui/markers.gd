class_name WorldMarkers
extends CanvasLayer
## Floating world-anchored markers on the WORLD_FEEDBACK tier — draws
## above world sprites, below HUD chrome.  Each marker is a screen-space
## Control that follows a world Node2D every frame through the canvas
## transform, so it tracks camera pan/zoom and viewport stretch for free.
##
##   var tok := markers.marker(guest_node, Vector2(0, -70))
##   markers.marker_control(tok).add_child(my_content)
##   markers.release(tok)
##
## bubble(content) wraps content in the nine-slice prompt chrome — the
## base for need-bubbles and "+12c" floaters.  inspector_ring() is the
## scaffold for the selected-guest ring (lands with the inspector pass).

var _markers := {}                       # token -> {node, offset, control}
var _next := 1


func _init() -> void:
    layer = UITokens.Tier.WORLD_FEEDBACK


func _process(_delta: float) -> void:
    var dead := []
    for tok in _markers:
        var m: Dictionary = _markers[tok]
        var n = m["node"]                # untyped — a freed instance
        if not is_instance_valid(n):     # can't enter a typed var
            m["control"].queue_free()
            dead.append(tok)
            continue
        m["control"].position = \
            n.get_global_transform_with_canvas().origin + m["offset"]
    for tok in dead:
        _markers.erase(tok)


## Attach an empty marker Control to a world node; returns its token.
## Fill it via marker_control() — the control's top-left sits at
## node_origin + offset.
func marker(world_node: Node2D, offset := Vector2.ZERO) -> int:
    var c := Control.new()
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(c)
    var tok := _next
    _next += 1
    _markers[tok] = {"node": world_node, "offset": offset, "control": c}
    return tok


func marker_control(token: int) -> Control:
    return _markers.get(token, {}).get("control")


func release(token: int) -> void:
    var m: Dictionary = _markers.get(token, {})
    if m.is_empty():
        return
    m["control"].queue_free()
    _markers.erase(token)


func clear() -> void:
    for tok in _markers.keys():
        release(tok)


## Glass affordance chip on a marker: small panel + content, caller
## places the glyph (icon_rect, label).  Returns [token, panel] — the
## token for release(), the panel for pivot/tween work.
func icon_chip(anchor: Node2D, content: Control, offset: Vector2,
        size := Vector2(18, 18)) -> Array:
    var tok := marker(anchor, offset)
    var p := Panel.new()
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_theme_stylebox_override("panel", UIKit.flat("glass_chip"))
    p.size = size
    p.add_child(content)
    marker_control(tok).add_child(p)
    return [tok, p]


## Nine-slice bubble chrome for marker content — caller parents it into
## a marker_control and sizes it to fit.
func bubble(content: Control, piece := "bubble_prompt") -> Panel:
    var p := Panel.new()
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_theme_stylebox_override("panel", UIKit.chrome(piece))
    p.add_child(content)
    return p


## Scaffold: selection ring under a world node.  Currently a marker
## token holding a square Control centred on the node — the real
## nine-slice ring sprite + pulse land with the guest-inspector pass.
func inspector_ring(node: Node2D, radius := 20.0) -> int:
    var tok := marker(node, Vector2(-radius, -radius))
    var c: Control = _markers[tok]["control"]
    c.custom_minimum_size = Vector2(radius * 2, radius * 2)
    c.size = c.custom_minimum_size
    return tok
