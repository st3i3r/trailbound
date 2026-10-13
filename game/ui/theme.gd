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
    # ---- Button icon colors (UI-066): glyph masks tint per state —
    # muted idle, warm on press, dim when disabled; white mask assets
    # make one file serve every state.
    t.set_color("icon_normal_color", "Button", UITokens.PAPER)
    t.set_color("icon_hover_color", "Button", UITokens.PAPER)
    t.set_color("icon_pressed_color", "Button", UITokens.GOLD)
    t.set_color("icon_focus_color", "Button", UITokens.PAPER)
    t.set_color("icon_disabled_color", "Button", UITokens.DIM)
    # ---- Label: body defaults; INK-on-paper labels and role fonts
    # still override per-node via UIKit.label().
    var body := UIKit.font_for(UITokens.TypeRole.BODY)
    t.set_font("font", "Label", body)
    t.set_font_size("font_size", "Label",
        UIKit.type_size(UITokens.TypeRole.BODY))
    t.set_color("font_color", "Label", UITokens.PAPER)
    # no global text shadow — flat surfaces read clean at these
    # contrasts; UIKit.label() adds a 1px lift only for light text
    # floating over the world (the one case that needs it)
    # ---- ScrollBars: the stock theme is dark and reads as a foreign
    # object on the silver kit.  Thin recessed trough + graphite grabber
    # (LINE tokens), no arrow buttons — content margins set the trough
    # thickness (~6px), not a theme constant.
    for bar in ["VScrollBar", "HScrollBar"]:
        t.set_stylebox("scroll", bar, _scroll_trough())
        t.set_stylebox("scroll_focus", bar, _scroll_trough())
        t.set_stylebox("grabber", bar, _scroll_grab(1.0))
        t.set_stylebox("grabber_highlight", bar, _scroll_grab(1.2))
        t.set_stylebox("grabber_pressed", bar, _scroll_grab(0.8))
        for k in ["increment", "increment_highlight",
                  "increment_pressed", "decrement",
                  "decrement_highlight", "decrement_pressed"]:
            t.set_stylebox(k, bar, StyleBoxEmpty.new())
    _theme = t
    return t


static func _scroll_trough() -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(UITokens.LINE, 0.14)      # recessed whisper
    sb.set_corner_radius_all(3)
    sb.content_margin_left = 2.5
    sb.content_margin_right = 2.5
    sb.content_margin_top = 2.5
    sb.content_margin_bottom = 2.5
    return sb


static func _scroll_grab(mod: float) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    var c := UITokens.LINE
    sb.bg_color = Color(c.r * mod, c.g * mod, c.b * mod)
    sb.set_corner_radius_all(3)
    sb.content_margin_top = 6.0                    # min grabber length
    sb.content_margin_bottom = 6.0
    return sb
