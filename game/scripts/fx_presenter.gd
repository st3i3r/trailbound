extends RefCounted
## FxPresenter — weather/FX config + response (D-ARCH-1/3).
## SOTA split (D-ARCH-9/10/11/12/13/14): the scene owns the
## frame tick (`_process`), all FX nodes (`_grade/_fx/_rain/
## `_leaves/_amb`, overlay/post channels) and data tables
## (`WEATHER_PROFILES`); this owns profile application, overlay
## crossfades, procedural textures, sway assignment, chrome
## fades and the light-cue track/untrack. Scene passed as
## untyped `s`. Moved caches: noise textures, weather tween,
## overlay fades, cue id, sway material, hud tween.


const AmbientFX := preload("res://scripts/ambient_fx.gd")

var s  # the pinewatch_test scene (untyped: mutual ref)

var _noise_cache: Dictionary = {}
var _weather_tween: Tween
var _overlay_fades: Dictionary = {}
var _cue_id := ""
var _sway: ShaderMaterial
var hud_tween: Tween


func _init(scene) -> void:
    s = scene


func set_weather(state: String, dur := 4.0) -> void:
    var p: Dictionary = s.WEATHER_PROFILES[state]
    var instant := dur <= 0.05
    s._fx.lightning = p.get("lightning", false)
    # kill stale overlay fades before anything writes intensity —
    # tracked overlays register during _apply_overlay below
    if _weather_tween and _weather_tween.is_running():
        _weather_tween.kill()
    _weather_tween = null
    # one fx tween owns the scalar channels (front + tint); the scene
    # tween owns only flat overlay fades — every channel shares the
    # same reduced-motion policy so nothing outpaces the front
    var rdur := dur * (0.3 if UIFeel.reduced_motion else 1.0)
    s._fx.set_front(float(p.get("front", 0.0)), dur, p["color"])
    if not instant:
        _weather_tween = s.create_tween().set_parallel(true)
    apply_overlay(s._warp_chan, p.get("warp"), rdur, instant)
    apply_overlay(s._veil_chan, p.get("veil"), rdur, instant)


## Phase -> nightfall target.  Morning barely dims (dawn freshness),
## evening is golden hour, night is the deep blue the sleep summary
## sits on.  `dusk` rolls in on the scalar — no hard day/night swap.


func on_phase_dusk(p: int) -> void:
    # signals fired during our own _ready resolve instantly — the
    # first frame must already read as evening, not roll toward it
    s._fx.set_dusk(dusk_target(p), 3.5 if s._booted else 0.0)
    sync_night_props()
    if p == Game.Phase.MORNING and not s._weather_forced:
        apply_day_weather(6.0 if s._booted else 0.0)


## Batch H night read — at EVENING/NIGHT occupied tents glow from
## inside, occupied pallet decks gain the bedroll+lantern overlay,
## and the restored hut lights its window (via _sync_crew_hut).
## Day restores the day sprites.  Called on every phase flip and
## after seat/unseat so loaded saves and arrivals match the hour.


func sync_night_props() -> void:
    var night := Game.phase in [Game.Phase.EVENING, Game.Phase.NIGHT]
    var occupied := {}
    for pid_list in Game.site_state()["assignments"].values():
        for pid2 in pid_list:
            occupied[pid2] = true
    for gid2 in s.tent_nodes:
        for t in s.tent_nodes[gid2]:
            var key := String(t.get_meta("tent_key", ""))
            if key == "":
                continue
            var want := key + "_night" if night else key
            if ResourceLoader.exists(s.A + "props_medium/%s.png" % want):
                t.texture = s._tex("props_medium/" + want)
    for pid in s._pad_shelters:
        var ov: Sprite2D = s._pad_shelters[pid]
        if ov.get_meta("shelter", "") != "platform":
            continue
        var want2 := "pallet_deck_occupied" \
            if (night and occupied.has(pid)) else "pallet_deck"
        if ResourceLoader.exists(s.A + "props_medium/%s.png" % want2):
            ov.texture = s._tex("props_medium/" + want2)
    s._sync_crew_hut()


func dusk_target(p: int) -> float:
    match p:
        Game.Phase.MORNING: return 0.10
        Game.Phase.PREP:    return 0.25
        Game.Phase.EVENING: return 0.55
        Game.Phase.NIGHT:   return 1.0
    return 0.4


## The day's rolled weather becomes a rolling front with the morning
## — the forecast the summary promised literally arrives on screen.


func apply_day_weather(dur := 6.0) -> void:
    var st: Dictionary = Game.site_state()
    var wkey: String = s.SIM_TO_FX.get(String(st["weather"]), "sunny")
    set_weather(wkey, dur)


## spec = {"shader": path, "val": target intensity} or null. Every
## overlay shader exposes `uniform float intensity` so the profile
## row never names uniforms. `chan` is a [primary, twin] pair — a
## new effect rolls in on the free slot while the outgoing one dies
## on its own shader, so transitions crossfade instead of popping.


func apply_overlay(chan: Array, spec: Variant, dur: float, instant: bool) -> void:
    var showing: ColorRect = null
    var free: ColorRect = null
    for r in chan:
        if r.visible and showing == null:
            showing = r
        elif free == null:
            free = r
    if free == null:                           # both busy mid-fade —
        free = chan[1]                         # overwrite the twin
    if spec == null:
        if showing != null:
            fade_out(showing, dur, instant)
        return
    var sm := (showing.material as ShaderMaterial) if showing else null
    if sm != null and sm.shader != null \
            and sm.shader.resource_path == spec["shader"]:
        kill_fade(showing)                    # a rect mid-fade-out can
        var rr := String(spec.get("resp", "")) # be revived — kill the
        if rr != "":                           # stale tween; tracked
            s._fx.track_overlay(sm, float(spec["val"]),  # specs rejoin
                StringName(rr))                # the scalar instead
        elif instant:
            sm.set_shader_parameter("intensity", spec["val"])
        else:
            _weather_tween.tween_property(sm,  # hide callback fires on
                "shader_parameter/intensity", spec["val"], dur)
        return                                 # the reviving effect
    kill_fade(free)                           # same for a reused slot
    var fm := free.material as ShaderMaterial  # different effect —
    fm.shader = load(spec["shader"])           # incoming rolls in on
    bind_noise(fm, spec["shader"])            # the free slot while
    free.visible = true                        # the old one dies fast
    var resp := String(spec.get("resp", ""))
    if instant:
        if resp != "":
            s._fx.track_overlay(fm, float(spec["val"]),
                StringName(resp))              # applies val x curve
        else:
            fm.set_shader_parameter("intensity", spec["val"])
        if showing != null:
            kill_fade(showing)
            showing.visible = false
    else:
        if resp != "":
            # scalar owns intensity — it rises as the front rolls in
            # (ripples accumulate, rays die with the light)
            s._fx.track_overlay(fm, float(spec["val"]),
                StringName(resp))
        else:
            fm.set_shader_parameter("intensity", 0.0)
            _weather_tween.tween_property(fm,
                "shader_parameter/intensity", spec["val"], dur)
        if showing != null:
            fade_out(showing, dur * 0.5, instant)


## Fade tweens are tracked per rect — a slot reused while a fade is
## still running must not let the stale tween drive the NEW effect's
## intensity to 0 or fire its hide callback.


func kill_fade(rect: ColorRect) -> void:
    if _overlay_fades.has(rect):
        _overlay_fades[rect].kill()
        _overlay_fades.erase(rect)
    # a killed/reused slot must not keep answering to the scalars —
    # the caller re-tracks if the revived effect still wants it
    s._fx.untrack_overlay(rect.material as ShaderMaterial)


func fade_out(rect: ColorRect, dur: float, instant: bool) -> void:
    kill_fade(rect)
    var m := rect.material as ShaderMaterial
    if m.shader == null or instant:
        rect.visible = false
        return
    var ft: Tween = s.create_tween()                   # own tween: callback on
    ft.tween_property(m,                       # a parallel tween has
        "shader_parameter/intensity", 0.0, dur)   # fuzzy step timing
    ft.tween_callback(func():
        rect.visible = false
        _overlay_fades.erase(rect))
    _overlay_fades[rect] = ft


func bind_noise(m: ShaderMaterial, path: String) -> void:
    ## Procedural FastNoiseLite fields — no binary noise assets
    match path:
        "res://shaders/sun_rays.gdshader":
            m.set_shader_parameter("noise_tex", noise_tex(11))
        "res://shaders/layered_fog.gdshader":
            m.set_shader_parameter("fog_noise_1", noise_tex(11))
            m.set_shader_parameter("fog_noise_2", noise_tex(47))
        "res://shaders/wind_gusts.gdshader":
            m.set_shader_parameter("noise_tex", noise_tex(23))


func noise_tex(nseed: int) -> Texture2D:
    if not _noise_cache.has(nseed):
        var n := FastNoiseLite.new()
        n.seed = nseed
        n.frequency = 0.035
        n.fractal_octaves = 3
        var img := Image.create(256, 256, false, Image.FORMAT_L8)
        for y in 256:
            for x in 256:
                var v := clampf(n.get_noise_2d(x, y) * 0.5 + 0.5,
                                0.0, 1.0)
                img.set_pixel(x, y, Color(v, v, v))
        _noise_cache[nseed] = ImageTexture.create_from_image(img)
    return _noise_cache[nseed]


func leaf_tex() -> Texture2D:
    ## 8x8 autumn leaf pixel-blob; angular_velocity tumbles it
    var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    for y in range(2, 6):
        for x in range(2, 6):
            img.set_pixel(x, y, Color(0.75, 0.45, 0.18, 0.9))
    img.set_pixel(1, 3, Color(0.75, 0.45, 0.18, 0.9))
    img.set_pixel(6, 3, Color(0.9, 0.6, 0.25, 0.9))
    return ImageTexture.create_from_image(img)


func rain_tex() -> Texture2D:
    ## 2x16 streak — bright leading tip fading toward the tail; the
    ## particle flag aligns it to velocity so it draws as a rain line
    var img := Image.create(2, 16, false, Image.FORMAT_RGBA8)
    for y in 16:
        var a := lerpf(0.55, 0.05, y / 15.0)
        img.set_pixel(0, y, Color(1, 1, 1, a))
        img.set_pixel(1, y, Color(1, 1, 1, a))
    return ImageTexture.create_from_image(img)


func fade_chrome(a: float) -> void:
    if hud_tween and hud_tween.is_running():
        hud_tween.kill()
    hud_tween = UIFeel.apply(s.create_tween(), "chrome")
    hud_tween.tween_property(s.hud, "modulate:a", a, UIFeel.dur("chrome"))


func wake_chrome() -> void:
    s.idle_ms = 0.0
    if s.hud == null:                            # HUD not built yet
        return
    if s.hud.modulate.a < 0.99:
        fade_chrome(1.0)


func sway_mat() -> ShaderMaterial:
    if _sway == null:
        _sway = ShaderMaterial.new()
        _sway.shader = load("res://shaders/foliage_sway.gdshader")
        _sway.set_shader_parameter("amp",
            0.8 * (0.3 if UIFeel.reduced_motion else 1.0))
    return _sway


func sways(tex: Texture2D) -> bool:
    var p := tex.resource_path
    for k in s.SWAY_KEYS:
        if k in p:
            return true
    return false


func apply_sway() -> void:
    for grp in [s.scatter, s.world, s.pads_node]:
        if grp == null:
            continue
        for n in grp.get_children():
            if n is Sprite2D and n.texture != null \
                    and sways(n.texture):
                n.material = sway_mat()


func build_ambient() -> void:
    apply_sway()
    # lantern posts make moth anchors — the lamp head sits ~14px
    # above the prop's ground anchor
    var lamps: Array = []
    for p in s._props:
        if p.size() > 1 and p[1] == "lantern_post":
            lamps.append(Vector2(p[2], p[3] - 14.0))
    # Pinewatch's pond rect is authored; other sites get a generous
    # box around their pond errand spot, or nothing
    var pond := Rect2(6, 195, 130, 105)
    var es: Dictionary = s.layout.get("errand_spots", {})
    if s._site_id != "pinewatch":
        if es.has("pond"):
            var pp: Array = es["pond"]
            pond = Rect2(pp[0] - 60, pp[1] - 40, 120, 80)
        else:
            pond = Rect2(-999, -999, 4, 4)
    # smoke only exists where a crew structure does — sites without a
    # hut never light a chimney
    var smoke_at: Vector2 = s._hut_px() + Vector2(-30, -58) \
        if s._hut != null else Vector2(-999, -999)
    s._amb = AmbientFX.new()
    s._amb.name = "AmbientFX"
    s._amb.bind(s._fx, {
        "pond": pond,
        "treeline": Rect2(0, 30, s.GW * s.T, 70),
        "flutter": Rect2(150, 110, 360, 160),
        "lanterns": lamps,
        "smoke_at": smoke_at})
    s.stage.add_child(s._amb)                    # over the world, under UI
    s._amb.set_smoke(s._hut != null
        and s._crew_stage(s._crew_sid()) > 0)


func on_light_cue(cue: Dictionary) -> void:
    if _cue_id != "":
        s._fx.untrack_emit(StringName(_cue_id))
        _cue_id = ""
    if not cue.is_empty() and s._fx != null:
        _cue_id = String(cue["id"])
        s._fx.track_emit(StringName(_cue_id), cue["col"],
            StringName(cue["w"]))


## Morning dialogue (UI-038 world half): rows from data/dialogue.json
## whose site+day match and haven't run yet queue onto the actors'
## markers, one bubble at a time.  spec 005: `when` rows react to
## last night's resolution — a matching conditional beats plain
## `day` rows to the front of the queue.


