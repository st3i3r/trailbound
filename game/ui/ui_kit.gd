class_name UIKit
extends RefCounted
## Chrome builders — the shared kit behind HUD, panels and markers.
## Statics only: fonts and the ui_atlas_meta nine-slice table lazy-load
## once and are shared by every caller (no autoload needed).
##
## Placement convention for pill()/panel()/button():  pass `where` as a
## Rect2 for absolute placement inside a plain Control, or as a Vector2
## (w, h) for a container-managed child (sets custom_minimum_size and
## `h_flag`, so e.g. SHRINK_END right-aligns inside a VBox row).

## Capsule pill ends, per scene_comp_v2 — overrides the banner's own
## nine_slice insets so the ends stay round at any width.
const PILL_INS := {"l": 14, "r": 14, "t": 5, "b": 6}

static var _f_head: FontFile
static var _f_body: FontFile
static var _ui_meta := {}
static var _tex_cache := {}
static var _ready := false


static func _ensure() -> void:
    if _ready:
        return
    _f_head = load(UITokens.FONTS + "F1_1.ttf")
    _f_body = load(UITokens.FONTS + "BeVietnamPro-Regular.ttf")
    # F1 is ASCII-only: Be Vietnam Pro catches · — “” etc; the engine
    # fallback covers whatever both fonts lack.
    _f_head.fallbacks.append(_f_body)
    _f_body.fallbacks.append(ThemeDB.fallback_font)
    _ui_meta = JSON.parse_string(FileAccess.get_file_as_string(
        UITokens.ASSETS + "ui/ui_atlas_meta.json"))
    _ready = true


static func font_head() -> Font:
    _ensure()
    return _f_head


static func font_body() -> Font:
    _ensure()
    return _f_body


static func font_for(role: UITokens.TypeRole) -> Font:
    _ensure()
    return _f_head if UITokens.TYPE[role]["font"] == "head" else _f_body


static func type_size(role: UITokens.TypeRole) -> int:
    return UITokens.TYPE[role]["size"]


static func tex(rel: String) -> Texture2D:
    ## Shared texture cache; rel is relative to assets/pinewatch/, no ext.
    if not _tex_cache.has(rel):
        _tex_cache[rel] = load(UITokens.ASSETS + rel + ".png")
    return _tex_cache[rel]


static func nine(name: String, ins := {}) -> StyleBoxTexture:
    ## Nine-slice chrome.  Insets come from ui_atlas_meta.json; pass an
    ## override where the comp prescribes something else (capsule ends).
    _ensure()
    if ins.is_empty():
        ins = _ui_meta.get(name, {}).get("nine_slice",
            {"l": 4, "r": 4, "t": 4, "b": 4})
    var sb := StyleBoxTexture.new()
    sb.texture = tex("ui/" + name)
    sb.texture_margin_left = ins["l"]
    sb.texture_margin_right = ins["r"]
    sb.texture_margin_top = ins["t"]
    sb.texture_margin_bottom = ins["b"]
    return sb


static func label(text: String, size := 8, font: Font = null,
                  color := UITokens.PAPER) -> Label:
    _ensure()
    var l := Label.new()
    l.text = text
    l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    # chrome is click-through; labels never eat input (a container would
    # otherwise give them a real rect that swallows world clicks)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    l.add_theme_font_override("font", font if font else _f_body)
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_shadow_color", UITokens.SHADOW)
    l.add_theme_constant_override("shadow_offset_x", 1)
    l.add_theme_constant_override("shadow_offset_y", 1)
    return l


static func label_for(text: String, role: UITokens.TypeRole,
                      color := UITokens.PAPER) -> Label:
    return label(text, type_size(role), font_for(role), color)


static func _place(c: Control, where: Variant,
                   h_flag: int) -> Vector2:
    ## Rect2 -> absolute rect; Vector2 -> container child min size.
    ## Returns the resolved size so callers can lay out children inside.
    var sz := Vector2.ZERO
    if where is Rect2:
        c.position = where.position
        c.size = where.size
        sz = where.size
    elif where is Vector2:
        sz = where
        c.custom_minimum_size = sz
        c.size_flags_horizontal = h_flag
    return sz


static func pill(parent: Control, where: Variant, icon: String,
                 text: String,
                 h_flag := Control.SIZE_SHRINK_BEGIN) -> Label:
    ## Banner pill: optional 16px icon at left, F1 heading text, capsule
    ## ends.  Returns the inner Label (its parent is the Panel).
    var p := Panel.new()
    var sz := _place(p, where, h_flag)
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_theme_stylebox_override("panel",
        nine("hud_banner_flat", PILL_INS))
    parent.add_child(p)
    var xo := 6.0
    if icon != "":
        var t := TextureRect.new()
        t.texture = tex("icons/" + icon)
        t.stretch_mode = TextureRect.STRETCH_KEEP
        t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        t.position = Vector2(UITokens.SP1, (sz.y - 16) / 2.0)
        t.mouse_filter = Control.MOUSE_FILTER_IGNORE
        p.add_child(t)
        xo = 22.0
    var l := label(text, 8, _f_head, UITokens.INK)
    l.position = Vector2(xo, (sz.y - 9) / 2.0 - 1)
    p.add_child(l)
    return l


static func panel(parent: Control, where: Variant, piece: String,
                  ins := {}, h_flag := Control.SIZE_SHRINK_BEGIN) -> Panel:
    ## Generic nine-slice panel (bubble_prompt, card_guest, panel_window…)
    var p := Panel.new()
    _place(p, where, h_flag)
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_theme_stylebox_override("panel", nine(piece, ins))
    parent.add_child(p)
    return p


static func button(parent: Control, where: Variant,
                   h_flag := Control.SIZE_SHRINK_BEGIN) -> Panel:
    ## Pill-chrome interactive button — same look as pill() but eats
    ## clicks; connect its gui_input (or wrap the press in a signal).
    var p := Panel.new()
    _place(p, where, h_flag)
    p.add_theme_stylebox_override("panel",
        nine("hud_banner_flat", PILL_INS))
    p.mouse_filter = Control.MOUSE_FILTER_STOP
    parent.add_child(p)
    return p


static func spacer(parent: Control, w: float, h := 0.0) -> Control:
    ## Transparent layout shim for container rows (mouse-filtered out).
    var s := Control.new()
    s.custom_minimum_size = Vector2(w, h)
    s.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(s)
    return s
