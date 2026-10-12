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
const DIM := Color("a59a72")               # muted text
const DIMMER := Color(0.09, 0.06, 0.02, 0.4)
                                           # panel scrim, paper-dark ~40%

# ------------------------------------------------------------ elevation
## CanvasLayer tiers — lower draws first.  World content (tilemap,
## props, actors) lives on the scene's own canvas; UI floats on these
## explicit tiers so nothing ever interleaves with chrome by accident.
enum Tier { WORLD_FEEDBACK = 5, HUD = 10, PANEL = 20, MODAL = 30 }

# ----------------------------------------------------------------- type
## Type roles -> which font + px size.  f_head = F1 pixel caps (the EN
## display font, ASCII-only); f_body = BeVietnamPro (VI body copy, full
## diacritics).  UIKit.font_for() resolves a role to a Font.
enum TypeRole { DISPLAY, HEAD, BODY, CAPTION, MONO }
const TYPE := {
    TypeRole.DISPLAY: {"font": "head", "size": 12},
    TypeRole.HEAD:    {"font": "head", "size": 9},
    TypeRole.BODY:    {"font": "body", "size": 8},
    TypeRole.CAPTION: {"font": "head", "size": 8},
    TypeRole.MONO:    {"font": "head", "size": 8},
}

# --------------------------------------------------------------- debug
## Dev chrome (dev/report/status labels, the guest-click hint) only
## exists in debug builds or while this flag is set.  Flip to false for
## clean production screenshots.
const DEBUG_UI := true


static func debug_ui() -> bool:
    return DEBUG_UI or OS.is_debug_build()
