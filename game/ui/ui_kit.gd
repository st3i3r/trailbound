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

static var _f_head: FontFile                 # BeVietnamPro-Medium (heads)
static var _f_disp: FontFile                 # BeVietnamPro-SemiBold
static var _f_body: FontFile                 # BeVietnamPro-Regular
static var _ui_meta := {}
static var _icons := {}                       # semantic name -> "I1_n"
static var _tex_cache := {}
static var _ready := false


static func _ensure() -> void:
    if _ready:
        return
    _f_body = load(UITokens.FONTS + "BeVietnamPro-Regular.ttf")
    _f_head = load(UITokens.FONTS + "BeVietnamPro-Medium.ttf")
    _f_disp = load(UITokens.FONTS + "BeVietnamPro-SemiBold.ttf")
    _f_body.fallbacks.append(ThemeDB.fallback_font)
    _f_head.fallbacks.append(_f_body)
    _f_disp.fallbacks.append(_f_head)
    _ui_meta = JSON.parse_string(FileAccess.get_file_as_string(
        UITokens.ASSETS + "ui/ui_atlas_meta.json"))
    # semantic icon registry (data/icons.json): flatten the category
    # tables into name -> file id; raw "I1_n" names still pass through
    var reg: Dictionary = JSON.parse_string(
        FileAccess.get_file_as_string("res://data/icons.json"))
    for cat in reg:
        if reg[cat] is Dictionary:
            for k in reg[cat]:
                if k != "comment":
                    _icons[k] = reg[cat][k]
    _ready = true


static func icon_name(name: String) -> String:
    ## Semantic name -> file id ("coin" -> "I1_0"); passes raw ids through.
    _ensure()
    return _icons.get(name, name)


static func icon(name: String) -> Texture2D:
    return tex("icons/" + icon_name(name))


## trait id -> its registry icon (falls back to the trait name itself
## so a raw "I1_n" still resolves).
static func trait_icon(trait_id: String) -> Texture2D:
    return icon(trait_id)


## weather string ("clear"/"rain") -> weather icon texture.
static func weather_icon(weather: String) -> Texture2D:
    _ensure()
    return icon(weather if _icons.has(weather) else "clear")


static func font_head() -> Font:
    _ensure()
    return _f_head


static func font_body() -> Font:
    _ensure()
    return _f_body


static func font_for(role: UITokens.TypeRole) -> Font:
    _ensure()
    match UITokens.TYPE[role]["font"]:
        "semi": return _f_disp
        "med":  return _f_head
        _:      return _f_body


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


static func label(text: String, size := 9, font: Font = null,
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
    # 1px shadow lifts light text off the ground; on ink-weight text
    # (INK, MUTE, PLUS, MINUS, GOLD_DEEP) it just muddies strokes.
    # Luminance threshold replaces the old INK-only check (UI-002).
    if color.get_luminance() > 0.5:
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
    ## Banner pill: optional 16px icon at left (semantic registry name
    ## or raw "I1_n"), heading text, capsule ends.  Grows to fit the
    ## text so callers can pass a minimum, not a guess.  Returns the
    ## inner Label; the Panel parent carries the icon in its "icon"
    ## meta for later swaps (e.g. the weather glyph).
    _ensure()
    var tw := _f_body.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
        -1.0, type_size(UITokens.TypeRole.HEAD)).x
    var need := (22.0 if icon != "" else 6.0) + tw + 14.0
    if where is Vector2 and need > where.x:
        where.x = need
    elif where is Rect2 and need > where.size.x:
        where.size.x = need
    var p := Panel.new()
    var sz := _place(p, where, h_flag)
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_theme_stylebox_override("panel",
        nine("hud_banner_flat", PILL_INS))
    parent.add_child(p)
    var xo := 6.0
    if icon != "":
        var t := TextureRect.new()
        t.texture = UIKit.icon(icon)
        t.stretch_mode = TextureRect.STRETCH_KEEP
        t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        t.position = Vector2(UITokens.SP1, (sz.y - 16) / 2.0)
        t.mouse_filter = Control.MOUSE_FILTER_IGNORE
        p.add_child(t)
        p.set_meta("icon", t)
        xo = 22.0
    var l := label_for(text, UITokens.TypeRole.HEAD, UITokens.INK)
    l.position = Vector2(xo, (sz.y - 10) / 2.0 - 1)
    p.add_child(l)
    return l


static func pill_fit(l: Label) -> void:
    ## Re-measure a pill()'s text and grow its parent to fit — pills are
    ## created with "" or short text and set later, so width can't be
    ## known at build time.  Grow-only: never shrinks (containers would
    ## jitter); the label's left offset already accounts for the icon.
    _ensure()
    var p: Control = l.get_parent()
    var f := l.get_theme_font("font")
    var tw: float = f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT,
        -1.0, l.get_theme_font_size("font_size")).x
    var need: float = l.position.x + tw + 14.0
    p.size.x = maxf(need, p.size.x)
    p.custom_minimum_size.x = p.size.x


static func panel(parent: Control, where: Variant, piece: String,
                  ins := {}, h_flag := Control.SIZE_SHRINK_BEGIN) -> Panel:
    ## Generic nine-slice panel (bubble_prompt, card_guest, panel_window…)
    var p := Panel.new()
    _place(p, where, h_flag)
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_theme_stylebox_override("panel", nine(piece, ins))
    parent.add_child(p)
    return p


static func spacer(parent: Control, w: float, h := 0.0) -> Control:
    ## Transparent layout shim for container rows (mouse-filtered out).
    var s := Control.new()
    s.custom_minimum_size = Vector2(w, h)
    s.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(s)
    return s


# ------------------------------------------------------------- buttons
## Real Button nodes with the five interactive states (UI-008): the
## atlas already ships the art — pill chrome for neutral, green for
## safe/ok, gold for primary, round_gold for icon-only controls, and a
## dedicated disabled piece.  Hover/pressed reuse the same nine-slice
## tinted (a press is a darkening dip, not a new piece).
const BTN_KINDS := {
    "pill":  "hud_banner_flat",
    "green": "btn_green",
    "gold":  "btn_gold",
    "round": "btn_round_gold",
}

static func state_nine(piece: String, ins := {}, mod := 1.0) -> StyleBoxTexture:
    ## nine() + a brightness multiplier — cheap hover/pressed variants.
    var sb := nine(piece, ins)
    sb.modulate_color = Color(mod, mod, mod)
    return sb


static func focus_box() -> StyleBoxFlat:
    ## 1px gold focus ring — drawn over the control when a gamepad /
    ## keyboard owns it, invisible otherwise (mouse focus shows hover).
    var sb := StyleBoxFlat.new()
    sb.draw_center = false
    sb.border_color = UITokens.GOLD
    sb.set_border_width_all(1)
    sb.corner_radius_top_left = 10
    sb.corner_radius_top_right = 10
    sb.corner_radius_bottom_left = 10
    sb.corner_radius_bottom_right = 10
    return sb


static func btn(parent: Control, where: Variant, text: String,
                kind := "pill",
                h_flag := Control.SIZE_SHRINK_BEGIN) -> Button:
    _ensure()
    var piece: String = BTN_KINDS.get(kind, kind)
    var ins: Dictionary = PILL_INS if piece == "hud_banner_flat" else {}
    var b := Button.new()
    _place(b, where, h_flag)
    b.text = text
    b.focus_mode = Control.FOCUS_ALL
    b.mouse_filter = Control.MOUSE_FILTER_STOP
    b.add_theme_font_override("font",
        font_for(UITokens.TypeRole.HEAD))
    b.add_theme_font_size_override("font_size",
        type_size(UITokens.TypeRole.HEAD))
    for c in ["font_color", "font_hover_color", "font_pressed_color",
              "font_focus_color"]:
        b.add_theme_color_override(c, UITokens.INK)
    b.add_theme_color_override("font_disabled_color", UITokens.DIM)
    b.add_theme_stylebox_override("normal", nine(piece, ins))
    b.add_theme_stylebox_override("hover", state_nine(piece, ins, 1.1))
    b.add_theme_stylebox_override("pressed", state_nine(piece, ins, 0.8))
    b.add_theme_stylebox_override("disabled", nine("btn_disabled"))
    b.add_theme_stylebox_override("focus", focus_box())
    parent.add_child(b)
    return b
