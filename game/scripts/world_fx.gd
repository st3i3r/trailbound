extends Node
## WorldFX — the "rolling front" pattern made continuous (matrix.txt).
##
## Instead of a timeline of phases, one normalized scalar per driver
## and every atmospheric channel is a pure response curve evaluated in
## _apply():
##
##   front  0..1   weather severity — clear 0.0, windy ~0.35,
##                 rain ~0.7, full storm 1.0
##   dusk   0..1   nightfall — noon 0.0, golden hour ~0.5, night 1.0
##   flash         lightning impulse, decays in _process
##
## Light model: grade = time(dusk) x absorb(base_color) + emit terms.
## Transmittance can never exceed 1 (Beer-Lambert) — a profile
## channel above 1 is in-scatter and routes to a daylight-weighted
## additive term, so brightening weather can never lift the night
## ("no sunny at night" is structural, not a guard clause).
##
## Interrupts are free: a retargeted tween continues from the current
## scalar, so a storm cancelled mid-roll never snaps.  Reduced motion
## shortens every roll; reduced flashing gates the lightning channel
## entirely (a hard-won class of bug — never strobe on a flag meant
## to prevent strobing).

const DUSK_GOLD := Color(0.96, 0.90, 0.74)  # golden-hour dim — gentle;
                                            # warmth lives in the post
                                            # grade's split-tone, not a
                                            # film over the frame
const NIGHT_MUL := Color(0.30, 0.32, 0.54)  # moonlit blue multiply
const FLASH_ADD := Color(0.95, 0.95, 1.10, 0.0)
const CUE_GAIN := 0.22                      # authored cue hues nudge the
                                            # grade ~+0.15/channel; raw
                                            # adds washed the frame
const RAIN_ON := 0.26                       # emitter hysteresis —
const RAIN_OFF := 0.20                      # crossing up needs more
const LEAF_ON := 0.30                       # than staying on
const LEAF_OFF := 0.24
const WILDLIFE := 0.7                       # bird/cricket bed level
const WIND_CALM := 0.8                      # ambient sway baseline —
const WIND_STORM := 4.2                     # foliage materials read
                                            # this global when they
                                            # land (profile note)

var base_color := Color.WHITE:              # profile tint — also a
	set(v):                                 # scalar channel: tweened
		base_color = v                      # like the rest, so the
		_apply()                            # composite follows it
var front := 0.0:
	set(v):
		front = clampf(v, 0.0, 1.0)
		_apply()
var dusk := 0.0:
	set(v):
		dusk = clampf(v, 0.0, 1.0)
		_apply()
var flash := 0.0
var lightning := false                      # profile flag — flashes
                                            # only at high front AND
                                            # once the roll settles
var _settled := true
var _ftw: Tween
var _dtw: Tween
var _flash_cd := 2.0
var _wind_param := false
var _fx_layers := {}                         # ShaderMaterial ->
                                             # {val, resp} — overlays
                                             # that track the scalars
var _emit_layers := {}                       # id -> {col, amp, w, n,
                                             # p, jitter} — additive
                                             # light terms: grade rows
                                             # tint the canvas, node
                                             # rows drive a property
var _jt := 0.0                               # jitter clock — visual
                                             # only, never sim state

var _grade: CanvasModulate
var _rain: GPUParticles2D
var _leaves: GPUParticles2D
var _rain_on := false
var _leaf_on := false


func bind(grade: CanvasModulate, rain: GPUParticles2D,
		leaves: GPUParticles2D, base: Color) -> void:
	_grade = grade
	_rain = rain
	_leaves = leaves
	base_color = base
	# runtime-declared so future sway materials can read it without
	# a project.godot shader_globals entry.  get_list() is editor-only
	# on the GL renderer — check the declared setting instead
	if RenderingServer.has_method(&"global_shader_parameter_add") \
			and not ProjectSettings.has_setting(
				"shader_globals/global_wind_speed"):
		RenderingServer.global_shader_parameter_add(
			&"global_wind_speed",
			RenderingServer.GLOBAL_VAR_TYPE_FLOAT, WIND_CALM)
	_wind_param = true
	# flash is an emit row, not a special case — the registry's
	# built-in first entry
	_emit_layers[&"flash"] = {"col": FLASH_ADD, "amp": 1.0,
		"w": &"flash", "n": null, "p": &""}
	_apply()


func set_front(target: float, dur := 4.0, tint: Variant = null) -> void:
	if UIFeel.reduced_motion:
		dur *= 0.3                            # fronts still roll, faster
	if _ftw and _ftw.is_running():
		_ftw.kill()
	if dur <= 0.05:
		front = target
		if tint is Color:
			base_color = tint
		_settled = true
		return
	_settled = false
	_ftw = create_tween()
	_ftw.tween_property(self, "front", target, dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if tint is Color:                         # one tween per transition —
		# the tint channel rides the same roll as the front
		_ftw.parallel().tween_property(self, "base_color", tint,
			dur).set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
	_ftw.tween_callback(func(): _settled = true)


func set_dusk(target: float, dur := 3.5) -> void:
	if UIFeel.reduced_motion:
		dur *= 0.3
	if _dtw and _dtw.is_running():
		_dtw.kill()
	if dur <= 0.05:
		dusk = target
		return
	_dtw = create_tween()
	_dtw.tween_property(self, "dusk", target, dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	_jt += delta
	# jittered emit rows re-apply their own prop each frame — grade
	# recomputes would fight a shared composite write.  Amplitude and
	# speed both scale with the front: a hearth light sputters under
	# the storm instead of burning through it untouched.
	for k in _emit_layers.keys():
		var e: Dictionary = _emit_layers[k]
		var j: float = e.get("jitter", 0.0)
		if j <= 0.0:
			continue
		var n: Object = e["n"]
		if not is_instance_valid(n):
			continue                       # _apply_grade sweeps stale rows
		var ja: float = j * (1.0 + 1.5 * front)
		if not UIFeel.can_pulse():
			ja *= 0.3                    # reduced flashing flattens it
		var t: float = _jt * (1.0 + 0.8 * front) \
			+ float(absi(hash(k)) % 97)  # per-row phase — no hive-mind
		var nz: float = (sin(t * 9.0) + cos(t * 9.0 * 1.618)
			+ sin(t * 9.0 * 2.314)) / 3.0
		n.set(StringName(e["p"]),
			float(e["amp"]) * _emit_weight(StringName(e["w"]))
			* (1.0 + ja * nz))
	if flash > 0.0:
		flash = maxf(0.0, flash - delta / 0.14)
		_apply_grade()
	# lightning waits for the roll to settle — a flash mid-ramp fights
	# the transition — and is gated by reduced flashing like every
	# pulse in the codebase
	if not (lightning and _settled and front > 0.8) \
			or not UIFeel.can_pulse():
		return
	_flash_cd -= delta
	if _flash_cd <= 0.0:
		_flash_cd = randf_range(2.5, 7.0)
		flash = 1.0
		_apply_grade()
		# thunder lags the flash — light before sound, ~0.2–0.8 s
		var dl := create_tween()
		dl.tween_interval(randf_range(0.15, 0.8))
		dl.tween_callback(Audio.play_sfx.bind(&"thunder"))


## Overlays (veil/warp shader rects) opt into scalar tracking via a
## "resp" key on their profile spec — the matrix row for that layer:
##   "front"      accumulate-late — ripples deepen as water collects
##   "front_lift" keeps a baseline, scales up with the front (gusts)
##   "dusk"       dies with the light — sun rays go out at nightfall
## Absent = flat one-shot fade (fog banks don't care about either).
## Applied immediately on register so revive/settled paths never
## leave a stale intensity.
func track_overlay(m: ShaderMaterial, val: float,
		resp: StringName) -> void:
	_fx_layers[m] = {"val": val, "resp": resp}
	_apply_overlay(m)


func untrack_overlay(m: ShaderMaterial) -> void:
	_fx_layers.erase(m)


func _apply_overlay(m: ShaderMaterial) -> void:
	var e: Dictionary = _fx_layers.get(m, {})
	if e.is_empty():
		return
	var iv: float = float(e["val"])
	match String(e["resp"]):
		"front":
			iv *= pow(front, 1.3)
		"front_lift":
			iv *= 0.3 + 0.7 * front
		"dusk":
			iv *= 1.0 - dusk
	m.set_shader_parameter("intensity", iv)


## Emission layers — the additive half of the light model.  `w`
## names a scalar curve (the row selector); grade rows add colour
## to the canvas, node rows set `p` to amp*w (light energy, glow
## alpha).  `jitter` on a node row adds a relative organic flicker
## (sputter grows with the front).  Registered terms apply
## immediately.
func track_emit(id: StringName, col: Color, w: StringName,
		node: Object = null, prop: StringName = &"",
		jitter := 0.0) -> void:
	_emit_layers[id] = {"col": col,
		"amp": maxf(col.r, maxf(col.g, col.b)),
		"w": w, "n": node, "p": prop, "jitter": jitter}
	_apply_grade()


func untrack_emit(id: StringName) -> void:
	_emit_layers.erase(id)


## Emit weight curves — additive light rides its own scalar:
##   flat     constant term
##   ember    hearth light — arrives only once real dark falls
##   daylight scatter term — heat shimmer dies with the sun
##   dusk     grows into the night
##   front    follows the storm front
##   flash    the lightning impulse itself
func _emit_weight(w: StringName) -> float:
	match w:
		&"flat":     return 1.0
		&"ember":    return smoothstep(0.45, 0.92, dusk)
		&"daylight": return 1.0 - dusk
		&"dusk":     return dusk
		&"front":    return front
		&"flash":    return flash
	return 0.0


## Grade-only path — flash decay touches colour alone; recomputing
## ambience/emitters per decay frame would churn for nothing.
func _apply_grade() -> void:
	if _grade == null:
		return
	# Beer-Lambert split: absorb = transmitted light (<=1, applies
	# day and night), scatter = emitted light (>1, scales with
	# daylight).  A heatwave tint at midnight stays dark — the
	# "only scales at day" caveat is structural, not a comment.
	var absorb := Color(minf(base_color.r, 1.0),
		minf(base_color.g, 1.0), minf(base_color.b, 1.0))
	var scatter := Color(maxf(base_color.r - 1.0, 0.0),
		maxf(base_color.g - 1.0, 0.0), maxf(base_color.b - 1.0, 0.0))
	var c := _dusk_mul(dusk) * absorb + scatter * (1.0 - dusk)
	for k in _emit_layers.keys():
		var e: Dictionary = _emit_layers[k]
		var n: Object = e["n"]
		var w: float = _emit_weight(StringName(e["w"]))
		if n == null:
			# Cue cols are authored hues (e8c46a firelight, 6a7fa8
			# moon) — adding them raw into a multiply channel lifts
			# the whole frame 40%+ = milk wash.  CUE_GAIN keeps the
			# beat a nudge of authored colour; lightning flash is a
			# real exposure pulse and stays full-strength.
			var gain := 1.0 if StringName(e["w"]) == &"flash" \
				else CUE_GAIN
			c += (e["col"] as Color) * w * gain
		elif is_instance_valid(n):
			n.set(StringName(e["p"]), float(e["amp"]) * w)
		else:
			_emit_layers.erase(k)
	_grade.color = c


## Every channel reads the scalars — the "matrix" is these curves.
func _apply() -> void:
	if _grade == null:
		return
	_apply_grade()
	# rain swells through the front: drizzle ~0.3, downpour at 1.0.
	# amount_ratio ramps density so drops fade in, not pop
	var rr: float = clampf((front - RAIN_ON) / (1.0 - RAIN_ON),
		0.0, 1.0)
	if _rain != null:
		_rain.amount_ratio = rr
		var want_rain: bool = front > (RAIN_OFF if _rain_on else RAIN_ON)
		if want_rain != _rain_on:
			_rain_on = want_rain
			_rain.emitting = want_rain
	# wind debris — sparse tumble on windy days, heavy under storm
	var lr: float = clampf((front - LEAF_ON) / 0.5, 0.0, 1.0) * 0.7
	if _leaves != null:
		_leaves.amount_ratio = lr
		var want_leaf: bool = front > (LEAF_OFF if _leaf_on else LEAF_ON)
		if want_leaf != _leaf_on:
			_leaf_on = want_leaf
			_leaves.emitting = want_leaf
	if _wind_param:
		RenderingServer.global_shader_parameter_set(
			&"global_wind_speed",
			lerpf(WIND_CALM, WIND_STORM, front * front))
	# tracked overlay materials follow their response curves
	for m: ShaderMaterial in _fx_layers.keys():
		if is_instance_valid(m):
			_apply_overlay(m)
		else:
			_fx_layers.erase(m)
	# the audio mix follows the same curves — wildlife ducks under
	# the storm wash, crickets inherit the night
	Audio.set_ambience_mix({
		&"day": WILDLIFE * (1.0 - dusk) * (1.0 - 0.6 * front),
		&"night": WILDLIFE * dusk * (1.0 - 0.5 * front),
		&"storm": 0.85 * front * front,
	})


## Nightfall grade: noon white -> golden hour -> moonlit blue.
func _dusk_mul(d: float) -> Color:
	if d < 0.5:
		return Color.WHITE.lerp(DUSK_GOLD, d * 2.0)
	return DUSK_GOLD.lerp(NIGHT_MUL, (d - 0.5) * 2.0)
