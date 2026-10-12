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
## Silver-sheet chrome (post-D-UI-1): light translucent surfaces over
## the dark world — the Eastward dialogue-box read.  Text on chrome is
## warm dark ink; the accents are deep variants tuned ≥4.5 on silver.
const PAPER := Color("332e22")             # dark warm ink — text on silver
const INK := Color("3e2814")               # dark ink (cream bubbles only)
const SHADOW := Color("1c2413")            # 1px text drop shadow
const GOLD := Color("644508")              # deep gold — coin/star on silver
const GREEN := Color("2f5218")             # ok — deep camp green
const RED := Color("7c2e1e")               # aversion / penalty — dark sienna
const DIM := Color("514a3a")               # muted text — warm grey-sage
const BLUE := Color("234a6e")              # info / water — deep sky
# Lacquer kit metals — the frame/selection/primary palette.
const LEAF := Color("c9a45c")              # gold-leaf 1px line frame
const GLOW := Color("e8c46a")              # selection glow
const VERMILION := Color("b8322a")         # sơn mài seal — primary btn
# On-PAPER variants — the accents above are tuned for dark chrome and
# wash out on parchment; these deep variants carry the same meaning.
# (All WCAG-4.5-verified vs their surfaces — UI-018 lint contrast.)
const MUTE := Color("6b5836")              # muted text on paper
const PLUS := Color("40682c")              # positive terms on paper
const MINUS := Color("9a3a28")             # negative terms on paper
const GOLD_DEEP := Color("7a5510")         # accent / coin text on paper
const DIMMER := Color(0.05, 0.07, 0.06, 0.45)
                                           # panel scrim — cool pine dim
# Silver surfaces — fills + hairline for StyleBoxFlat chrome.  Faint
# alpha keeps a whisper of the world behind (the ref's float feel).
const GLASS := Color("e8e5d8cc")           # sheet silver, ~80% opaque
const CHIP  := Color("e0dcccbc")           # recessed silver, ~74%
const LINE  := Color("6f6752")             # graphite-sage hairline
const LINE_DIM := Color("a89f8a")          # recessed line — disabled
const GREEN_BG := Color("dce5cd")          # ok-fill on silver
const DIM_BG := Color("d9d5c8e0")          # disabled fill
const SHADOW_SOFT := Color(0.0, 0.0, 0.0, 0.35)
                                           # sheet drop shadow

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
## Scale: 18 / 12 / 9 / 9 — ≥1.3× between levels (Eastward's ~2×
## title:body). CAPTION stays at the 9px floor — VI stacked diacritics
## don't survive 8px; its hierarchy is the DIM color, not size.
const TYPE := {
    TypeRole.DISPLAY: {"font": "semi", "size": 18},
    TypeRole.HEAD:    {"font": "med",  "size": 12},
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

# --------------------------------------------------------------- motion
## UI-017: every tween reads duration + curve from here — no magic
## numbers at call sites.  kind decides what reduced-motion does:
## "fade" survives at a snappier time, "scale" collapses to ~instant
## (position/shape changes are the nauseating ones, opacity is not).
const MOTION := {
    "panel_in":   {"d": 0.16, "trans": Tween.TRANS_CUBIC,
                   "ease": Tween.EASE_OUT,     "kind": "scale"},
    "panel_out":  {"d": 0.12, "trans": Tween.TRANS_CUBIC,
                   "ease": Tween.EASE_IN,      "kind": "scale"},
    "dimmer":     {"d": 0.15, "trans": Tween.TRANS_SINE,
                   "ease": Tween.EASE_IN_OUT,  "kind": "fade"},
    "chrome":     {"d": 0.40, "trans": Tween.TRANS_SINE,
                   "ease": Tween.EASE_IN_OUT,  "kind": "fade"},
    "fire":       {"d": 0.25, "trans": Tween.TRANS_SINE,
                   "ease": Tween.EASE_IN_OUT,  "kind": "fade"},
    "count_up":   {"d": 0.70, "trans": Tween.TRANS_QUAD,
                   "ease": Tween.EASE_OUT,     "kind": "fade"},
    "recount":    {"d": 0.40, "trans": Tween.TRANS_QUAD,
                   "ease": Tween.EASE_OUT,     "kind": "fade"},
    "marker":     {"d": 0.50, "trans": Tween.TRANS_SINE,
                   "ease": Tween.EASE_IN_OUT,  "kind": "scale"},
}

# --------------------------------------------------------------- debug
## Dev chrome (dev/report/status labels, the guest-click hint) is an
## opt-in: the const, or --dev-ui on a debug build (run_pinewatch.cmd
## passes it).  Release exports and plain --shot runs stay clean.
const DEBUG_UI := false


static func debug_ui() -> bool:
    return DEBUG_UI or (OS.is_debug_build()
        and OS.get_cmdline_args().has("--dev-ui"))
