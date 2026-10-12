class_name UIFeel
extends RefCounted
## UIFeel — motion + haptics plumbing (GDD §5, UI-017).
## Every UI animation routes through dur()/apply() so duration,
## easing and reduced-motion live in one place; every tactile event
## routes through haptic() so vibration stays a semantic call
## ("confirm"), never a raw duration.
##
## Reduced motion: fades keep a short 60 ms (pure opacity, no
## spatial change); scale/pop tweeners collapse to ~instant.  The
## flag is static for now — the settings sheet (P3) writes it and
## --reduced-motion on the command line sets it for QA.

static var reduced_motion := false


## Duration for a token key, after the reduced-motion policy.
static func dur(key: String) -> float:
    var m: Dictionary = UITokens.MOTION.get(key, {})
    if m.is_empty():
        return 0.0
    if not reduced_motion:
        return float(m["d"])
    return 0.06 if m.get("kind") == "fade" else 0.001


## Set a tween's transition+easing from the token.  Returns the same
## tween for chaining: UIFeel.apply(create_tween(), "panel_in").
static func apply(tw: Tween, key: String) -> Tween:
    var m: Dictionary = UITokens.MOTION.get(key, {})
    if not m.is_empty():
        tw.set_trans(int(m["trans"])).set_ease(int(m["ease"]))
    return tw


# ---------------------------------------------------------------- haptics
## Semantic tactile events → vibration length (ms).  Light taps only:
## 8 ms reads as a "tick", 30 ms as a "no".  Durations that short are
## all amplitude-blended by the OS anyway, so granularity beyond this
## is fake precision.
const HAPTIC_MS := {
    "press":   8,    # any button press — wired in UIKit.btn
    "confirm": 15,   # committing a choice (seat, sleep, head out)
    "pay":     20,   # coins move (double-tips claim)
    "warn":    30,   # refused action (full camp, spent card)
}


static func haptic(kind: String) -> void:
    if not OS.has_feature("android"):
        return
    Input.vibrate_handheld(int(HAPTIC_MS.get(kind, 0)))
