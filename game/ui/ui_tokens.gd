class_name UITokens
extends RefCounted
## Design tokens — the single source of truth for Trailbound UI metrics.
## Everything sits on a 4px spacing grid; screens hang off MARGIN.

const ASSETS := "res://assets/pinewatch/"
const FONTS := ASSETS + "fonts/"

# ------------------------------------------------------------- spacing
const SP1 := 4
const SP2 := 8
const SP3 := 12
const SP4 := 16
const SP5 := 20
const SP6 := 24
const SP7 := 28
const SP8 := 32
const MARGIN := SP2                        # screen-edge margin

# ------------------------------------------------------------- palette
const PAPER := Color("f5e9c8")             # parchment — light text on dark
const INK := Color("3e2814")               # dark ink on parchment pills
const SHADOW := Color("1c2413")            # 1px text drop shadow
const GOLD := Color("ffcf7d")              # elite / rating accent
const GREEN := Color("b8d7a8")             # ok / camp green
const RED := Color("e0886c")               # aversion / penalty terms
const DIM := Color("a59a72")               # muted text
const DIMMER := Color(0.09, 0.06, 0.02, 0.4)
                                           # panel scrim, paper-dark ~40%

# ------------------------------------------------------------ elevation
## CanvasLayer tiers — lower draws first.  World content (tilemap,
## props, actors) lives on the scene's own canvas; UI floats on these
## explicit tiers so nothing ever interleaves with chrome by accident.
enum Tier { WORLD_FEEDBACK = 5, HUD = 10, PANEL = 20, MODAL = 30 }

# ----------------------------------------------------------------- type
## Type roles -> which font + px size.  D-UI-2: Be Vietnam Pro is the
## UI typeface for every role — F1 is ASCII-only and retired from text.
## Weight hierarchy (D-UI-3/UI-013): display SemiBold, heads Medium,
## body Regular — size alone is too weak a hierarchy on phone screens.
## Sizes are 360p virtual px (the stretch scale re-renders them crisp
## on device).  UIKit.font_for() resolves a role to a Font.
enum TypeRole { DISPLAY, HEAD, BODY, CAPTION, MONO }
const TYPE := {
    TypeRole.DISPLAY: {"font": "semi", "size": 14},
    TypeRole.HEAD:    {"font": "med",  "size": 10},
    TypeRole.BODY:    {"font": "body", "size": 9},
    TypeRole.CAPTION: {"font": "body", "size": 9},
    TypeRole.MONO:    {"font": "body", "size": 9},
}

# --------------------------------------------------------------- safe area
## DisplayServer.get_display_safe_area() is reported in real window px;
## scale it into our 360p virtual space before comparing with layout.
static func safe_insets(vp_size: Vector2) -> Dictionary:
    var win := Vector2(DisplayServer.window_get_size())
    var zero := {"l": 0.0, "t": 0.0, "r": 0.0, "b": 0.0}
    if win.x <= 0 or win.y <= 0:
        return zero
    var safe := Rect2(DisplayServer.get_display_safe_area())
    if safe.size.x <= 0 or safe.size == Rect2(Vector2.ZERO, win).size:
        return zero
    var sc := Vector2(vp_size.x / win.x, vp_size.y / win.y)
    var a: Vector2 = safe.position * sc
    var b: Vector2 = safe.end * sc
    return {"l": maxf(0.0, a.x), "t": maxf(0.0, a.y),
            "r": maxf(0.0, vp_size.x - b.x),
            "b": maxf(0.0, vp_size.y - b.y)}

# ----------------------------------------------------------------- touch
## 48dp on a phone-density screen ≈ 40 virtual px at the 360p base.
## Hit areas must reach this even when the art is smaller.
const MIN_TOUCH := 40

# --------------------------------------------------------------- debug
## Dev chrome (dev/report/status labels, the guest-click hint) is an
## opt-in: the const, or --dev-ui on a debug build (run_pinewatch.cmd
## passes it).  Release exports and plain --shot runs stay clean.
const DEBUG_UI := false


static func debug_ui() -> bool:
    return DEBUG_UI or (OS.is_debug_build()
        and OS.get_cmdline_args().has("--dev-ui"))
