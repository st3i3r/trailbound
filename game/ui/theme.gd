class_name UITheme
extends RefCounted
## Shared Theme resource, built in code (not a .tres) so UITokens stays
## the single source of truth — one cached instance handed to UI roots
## (title scene, HUD, panels) so any raw Button/Label child inherits
## correct font/colour/state styles without per-node overrides.

static var _theme: Theme


static func theme() -> Theme:
    if _theme:
        return _theme
    var t := Theme.new()
    # ---- Button: pill chrome by default; kinds override per-node
    # through UIKit.btn() — these are the inherited fallbacks.
    var head := UIKit.font_for(UITokens.TypeRole.HEAD)
    var head_sz := UIKit.type_size(UITokens.TypeRole.HEAD)
    t.set_font("font", "Button", head)
    t.set_font_size("font_size", "Button", head_sz)
    t.set_color("font_color", "Button", UITokens.PAPER)
    t.set_color("font_hover_color", "Button", UITokens.PAPER)
    t.set_color("font_pressed_color", "Button", UITokens.PAPER)
    t.set_color("font_disabled_color", "Button", UITokens.DIM)
    t.set_color("font_focus_color", "Button", UITokens.PAPER)
    t.set_stylebox("normal", "Button", UIKit.flat("btn_pill"))
    t.set_stylebox("hover", "Button", UIKit.flat("btn_pill", 1.15))
    t.set_stylebox("pressed", "Button", UIKit.flat("btn_pill", 0.82))
    t.set_stylebox("disabled", "Button", UIKit.flat("btn_disabled"))
    t.set_stylebox("focus", "Button", UIKit.focus_box())
    t.set_constant("h_separation", "Button", UITokens.SP1)
    # ---- Label: body defaults; INK-on-paper labels and role fonts
    # still override per-node via UIKit.label().
    var body := UIKit.font_for(UITokens.TypeRole.BODY)
    t.set_font("font", "Label", body)
    t.set_font_size("font_size", "Label",
        UIKit.type_size(UITokens.TypeRole.BODY))
    t.set_color("font_color", "Label", UITokens.PAPER)
    t.set_color("font_shadow_color", "Label", UITokens.SHADOW)
    t.set_constant("shadow_offset_x", "Label", 1)
    t.set_constant("shadow_offset_y", "Label", 1)
    _theme = t
    return t
