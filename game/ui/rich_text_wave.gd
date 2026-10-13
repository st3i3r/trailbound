class_name RichTextWave
extends RichTextEffect
## `[wave]` bbcode effect (UI-038): gentle per-glyph sine bob, the
## Eastward dialogue-flourish trick.  The y offset is round()ed to
## whole pixels so glyphs ride the grid — no sub-pixel smear on a
## NEAREST-filtered game.
##
## Usage:  rt.bbcode_enabled = true
##         rt.add_theme_constant_override? no — install the effect:
##         rt.install_effect(RichTextWave.new())
##         rt.append_text("[wave amp=2 speed=5]▼[/wave]")
## Optional env: amp (px, default 1.5), speed (rad/s, default 5),
## freq (glyph phase spacing, default 0.7).

var bbcode := "wave"


func _process_custom_fx(fx: CharFXTransform) -> bool:
    var amp := float(fx.env.get("amp", 1.5))
    var speed := float(fx.env.get("speed", 5.0))
    var freq := float(fx.env.get("freq", 0.7))
    var wave := sin(fx.elapsed_time * speed
        + fx.relative_index * freq) * amp
    # pixel-snap: the whole point — a fractional offset would blur
    fx.transform.origin.y += round(wave)
    return true
