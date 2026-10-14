extends Node2D
## AmbientFX — the "world breathes" layer.  Pure response curves on the
## same two WorldFX scalars everything else reads (dusk, front); zero
## new plumbing, zero sim state.  Five channels:
##
##   fireflies   pond + treeline, ember curve — blink desyncs itself
##               because the colour-ramp alpha pulses over each
##               particle's own lifetime
##   shimmer     pond glints — daylight-weighted, ~15% moon residue
##   motes       pollen drift — daytime, ducks under the front
##   smoke       hut kitchen smoke — only once the hut is whole
##               (semantic: the camp is alive again, not decoration)
##   critters    moths orbiting lantern posts at night, butterflies
##               over the meadow by day — deterministic sine paths,
##               never physics
##
## Every sprite lives in assets/pinewatch/fx/ (the FX layer dir) and
## is authored straight from the v4 ramp hexes — nothing in this file
## touches a shipped prop.

const AMB_A := "res://assets/pinewatch/fx/"

var _fx                                     # WorldFX scalar driver
var _pond := Rect2(6, 195, 130, 105)        # water surface, px
var _treeline := Rect2(0, 30, 640, 70)
var _flutter := Rect2(150, 110, 360, 160)   # butterfly meadow
var _lanterns: Array = []
var _smoke_at := Vector2.ZERO
var _smoke_on := false

var _flies: GPUParticles2D                  # pond swarm
var _flies2: GPUParticles2D                 # treeline swarm
var _sparkle: GPUParticles2D
var _motes: GPUParticles2D
var _smoke: GPUParticles2D
var _moths := []                            # [{s,anchor,r,spd,ph}]
var _flies_day := []                        # butterflies [{s,c,ph}]
var _t := 0.0
var _calm := 1.0                            # reduced-motion scale


func bind(fx, anchors: Dictionary) -> void:
    _fx = fx
    _pond = anchors.get("pond", _pond)
    _treeline = anchors.get("treeline", _treeline)
    _flutter = anchors.get("flutter", _flutter)
    _lanterns = anchors.get("lanterns", [])
    _smoke_at = anchors.get("smoke_at", Vector2.ZERO)
    _calm = 0.35 if UIFeel.reduced_motion else 1.0
    _build()


func set_smoke(on: bool) -> void:
    _smoke_on = on
    if _smoke != null:
        _smoke.emitting = on


func _tex(n: String) -> Texture2D:
    return load(AMB_A + n + ".png")


func _emitter(texn: String, rect: Rect2, amount: int,
        life: float, additive := false) -> GPUParticles2D:
    var p := GPUParticles2D.new()
    p.amount = amount
    p.lifetime = life
    p.texture = _tex(texn)
    p.position = rect.get_center()
    p.visibility_rect = Rect2(-rect.size.x, -rect.size.y,
        rect.size.x * 2.2, rect.size.y * 2.2)
    p.preprocess = life            # mid-snapshot spawn — no pop-in
    var pm := ParticleProcessMaterial.new()
    pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    pm.emission_box_extents = Vector3(rect.size.x * 0.5,
        rect.size.y * 0.5, 0)
    pm.direction = Vector3(0, -1, 0)
    pm.spread = 180.0
    p.process_material = pm
    if additive:
        var cm := CanvasItemMaterial.new()
        cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
        p.material = cm
    p.emitting = false
    p.amount_ratio = 1.0
    add_child(p)
    return p


static func _ramp_tex(points: Array) -> GradientTexture1D:
    var g := Gradient.new()
    g.set_color(0, Color(1, 1, 1, points[0]))
    g.set_color(1, Color(1, 1, 1, points[points.size() - 1]))
    for i in range(1, points.size() - 1):
        g.add_point(float(i) / (points.size() - 1),
            Color(1, 1, 1, points[i]))
    var t := GradientTexture1D.new()
    t.gradient = g
    return t


func _build() -> void:
    # --- fireflies: pond swarm + sparser treeline swarm ------------
    var g := _ramp_tex([0.0, 1.0, 0.35, 1.0, 0.2, 0.9, 0.0])
    _flies = _emitter("fx_firefly", _pond, 14, 9.0, true)
    var fp: ParticleProcessMaterial = _flies.process_material
    fp.initial_velocity_min = 3.0
    fp.initial_velocity_max = 8.0
    fp.damping_min = 1.0
    fp.damping_max = 2.0
    fp.turbulence_enabled = true
    fp.turbulence_noise_strength = 0.8
    fp.turbulence_noise_scale = 6.0
    fp.color_ramp = g
    _flies2 = _emitter("fx_firefly", _treeline, 8, 11.0, true)
    var fp2: ParticleProcessMaterial = _flies2.process_material
    fp2.initial_velocity_min = 3.0
    fp2.initial_velocity_max = 7.0
    fp2.damping_min = 1.0
    fp2.damping_max = 2.0
    fp2.turbulence_enabled = true
    fp2.turbulence_noise_strength = 0.8
    fp2.turbulence_noise_scale = 6.0
    fp2.color_ramp = g
    _flies.emitting = true
    _flies2.emitting = true
    # --- pond glints -------------------------------------------------
    _sparkle = _emitter("fx_sparkle", _pond, 9, 0.75, true)
    var sp: ParticleProcessMaterial = _sparkle.process_material
    sp.initial_velocity_min = 0.0
    sp.initial_velocity_max = 0.0
    sp.color_ramp = _ramp_tex([0.0, 0.85, 0.0])
    _sparkle.emitting = true
    # --- daytime pollen drift ---------------------------------------
    _motes = _emitter("fx_mote", Rect2(0, 60, 640, 220), 22, 12.0)
    var mp: ParticleProcessMaterial = _motes.process_material
    mp.direction = Vector3(1, 0.35, 0)
    mp.spread = 30.0
    mp.initial_velocity_min = 1.5
    mp.initial_velocity_max = 4.0
    mp.turbulence_enabled = true
    mp.turbulence_noise_strength = 0.5
    mp.turbulence_noise_scale = 8.0
    mp.color_ramp = _ramp_tex([0.0, 0.55, 0.0])
    _motes.emitting = true
    # --- hut kitchen smoke -------------------------------------------
    _smoke = _emitter("fx_smoke",
        Rect2(_smoke_at.x, _smoke_at.y, 4, 4), 7, 4.6)
    var kp: ParticleProcessMaterial = _smoke.process_material
    kp.emission_box_extents = Vector3(2, 2, 0)
    kp.direction = Vector3(-0.25, -1, 0)     # rises, leans off-roof
    kp.spread = 14.0
    kp.initial_velocity_min = 5.0
    kp.initial_velocity_max = 9.0
    kp.damping_min = 0.4
    kp.damping_max = 0.9
    kp.turbulence_enabled = true
    kp.turbulence_noise_strength = 0.7
    kp.turbulence_noise_scale = 5.0
    kp.scale_min = 0.35
    kp.scale_max = 0.6
    var sc := CurveTexture.new()
    var scurve := Curve.new()
    scurve.add_point(Vector2(0, 0.35))
    scurve.add_point(Vector2(1, 1.6))        # expands as it climbs
    sc.curve = scurve
    kp.scale_curve = sc
    kp.color_ramp = _ramp_tex([0.0, 0.5, 0.0])
    _smoke.modulate = Color(1, 1, 1, 0.55)
    _smoke.emitting = _smoke_on
    # --- critters: moths on lanterns, butterflies on the meadow ------
    for i in _lanterns.size():
        for j in 2:
            var m := Sprite2D.new()
            m.texture = _tex("fx_moth")
            add_child(m)
            _moths.append({"s": m, "a": _lanterns[i],
                "r": 7.0 + j * 4.0 + i,
                "spd": (2.6 + j * 0.9) * (1 if i % 2 else -1),
                "ph": float(i * 2 + j) * 1.7})
    for i in 3:
        var b := Sprite2D.new()
        b.texture = _tex("fx_butterfly")
        add_child(b)
        _flies_day.append({"s": b,
            "c": _flutter.get_center() + Vector2(
                (i - 1) * 70.0, (i % 2) * 40.0 - 20.0),
            "ph": i * 2.13})


func _process(delta: float) -> void:
    _t += delta * _calm
    var dusk: float = _fx.dusk if _fx != null else 0.0
    var front: float = _fx.front if _fx != null else 0.0
    # fireflies fade in with the ember curve — no pop: ratio follows
    # dusk directly, emitters stay on so stragglers die naturally
    var fl := clampf((dusk - 0.3) / 0.4, 0.0, 1.0) * _calm
    _flies.amount_ratio = fl
    _flies2.amount_ratio = fl * 0.8
    _flies.emitting = fl > 0.02
    _flies2.emitting = fl > 0.02
    # pond glints: bright in daylight, a thin moon residue at night,
    # rain on the surface suppresses the sparkle a little
    _sparkle.amount_ratio = clampf(
        (1.0 - dusk) * 0.85 + 0.15, 0.0, 1.0) \
        * (1.0 - 0.35 * front) * _calm
    # pollen belongs to the light; the front washes it out
    _motes.amount_ratio = clampf((1.0 - dusk) * (1.0 - 0.6 * front),
        0.0, 1.0) * _calm
    _motes.emitting = _motes.amount_ratio > 0.05
    # smoke is a flag, not a curve — the restored hut always breathes
    # a little kitchen smoke; storms bend it more (damping does it)
    _smoke.emitting = _smoke_on
    # critters
    var moth_a := clampf((dusk - 0.4) / 0.3, 0.0, 1.0)
    for m in _moths:
        var s: Sprite2D = m["s"]
        s.modulate.a = moth_a
        if moth_a <= 0.01:
            continue
        var ang: float = _t * m["spd"] + m["ph"]
        s.position = m["a"] + Vector2(cos(ang) * m["r"],
            sin(ang) * m["r"] * 0.55 - 4.0)
        s.scale.x = 0.75 + 0.25 * sin(_t * 24.0 + m["ph"])
    var fly_a := clampf(1.0 - dusk * 1.8, 0.0, 1.0) * (1.0 - front)
    for i in _flies_day.size():
        var f: Dictionary = _flies_day[i]
        var s: Sprite2D = f["s"]
        s.modulate.a = fly_a
        if fly_a <= 0.01:
            continue
        var ph: float = f["ph"] + i * 1.31
        s.position = f["c"] + Vector2(
            sin(_t * 0.9 + ph) * 46.0 + sin(_t * 2.7 + ph) * 6.0,
            cos(_t * 1.3 + ph * 1.7) * 22.0
            + sin(_t * 5.0 + ph) * 2.5)
        # wing flap = horizontal squash
        var flap := 0.45 + 0.55 * absf(sin(_t * 11.0 + ph))
        s.scale = Vector2(flap, 1.0)
