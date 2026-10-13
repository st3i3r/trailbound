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
static var reduced_flashing := false          # settings sheet writes this
static var haptics_enabled := true            # settings sheet writes this
static var nav_input := false                 # keys/joypad armed focus nav


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
    if not haptics_enabled or not OS.has_feature("android"):
        return
    Input.vibrate_handheld(int(HAPTIC_MS.get(kind, 0)))


# ------------------------------------------------------------------- sfx
## Same semantic-event discipline as haptics: call sites say what
## happened ("confirm"), the map decides which file plays.  Volume and
## the step-0 mute live on the SFX bus (Game._apply_audio) — no extra
## gate here.  Placeholders come from tools/tb_sfx.py.
const SFX := {
    "press": "press", "confirm": "confirm", "warn": "warn",
    "pay": "coin", "coin": "coin", "open": "open", "close": "close",
    "pop": "pop", "tick": "tick", "stamp": "stamp", "shake": "warn",
}


static func sfx(kind: String) -> void:
    Audio.play_sfx(StringName(SFX.get(kind, "press")))


## Gate for looping pulses/strobes.  NOT just reduced_motion: a loop
## running at dur()==0.001 (the collapsed spatial duration) is an
## infinite near-instant strobe — the worst possible output under
## reduced motion.  Callers must skip the loop entirely here, and the
## reduced_flashing setting opts flicker-sensitive users out too.
static func can_pulse() -> bool:
    return not (reduced_motion or reduced_flashing)


# -------------------------------------------------------------- typewriter
## Letter/dialogue reveal (UI-038): `visible_characters` counts up at
## the "type" token's per-char rate, with a soft tick every few chars.
## Reduced motion → whole text instantly.  `on_done` fires once either
## way (advance glyph shows on it).  Returns the Tween, or null.
static func typewriter(rt: RichTextLabel, on_done := Callable()) -> Tween:
    if rt == null:
        return null
    var total := rt.get_parsed_text().length()
    if reduced_motion or total <= 1:
        rt.visible_characters = -1
        if on_done.is_valid():
            on_done.call()
        return null
    rt.visible_characters = 0
    var last := [0]
    var tw := rt.create_tween()
    tw.tween_method(func(v: float):
        var n := int(v)
        rt.visible_characters = n
        # a tick every ~4 chars reads as pen-scratch, not a machine gun
        if n >= int(last[0]) + 4:
            sfx("tick")
            last[0] = n,
        0.0, float(total), dur("type") * total)
    tw.tween_callback(func():
        if on_done.is_valid():
            on_done.call())
    return tw


# ------------------------------------------------------------------ shake
## Refused-action wobble — rotation phases on the control's centre
## pivot, "scale" kind so reduced motion skips the spatial jiggle.
static func shake(c: Control) -> void:
    if c == null or reduced_motion:
        return
    c.pivot_offset = c.size / 2.0
    var d := dur("shake")
    var tw := c.create_tween()
    tw.tween_property(c, "rotation", 0.07, d * 0.25)
    tw.tween_property(c, "rotation", -0.06, d * 0.50)
    tw.tween_property(c, "rotation", 0.0, d * 0.25)


## Squash-and-stretch tap: dip to `to`, BACK-ease home.  Works on any
## CanvasItem (button chrome, world ghosts, seated guests).  Reduced
## motion callers should skip entirely — checked here anyway.
static func pop(c: CanvasItem, to := Vector2(0.88, 0.88)) -> void:
    if c == null or reduced_motion:
        return
    if c is Control:
        (c as Control).pivot_offset = (c as Control).size / 2.0
    c.set("scale", to)                  # Node2D + Control both have it
    var tw := c.create_tween()
    apply(tw, "pop")
    tw.tween_property(c, "scale", Vector2.ONE, dur("pop"))
