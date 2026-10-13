extends Node
## Audio — music crossfades, ambience layers, SFX pools (GDD 18, 21.1).
##
## SFX: small AudioStreamPlayer pool on the "SFX" bus (the bus is
## created lazily by Game._apply_audio, which runs earlier in autoload
## order).  Semantic names come from UIFeel.sfx(); the wavs are the
## deterministic placeholders from tools/tb_sfx.py — swap the files,
## keep the ids.

const SFX_DIR := "res://assets/pinewatch/sfx/"
const MUSIC_DIR := "res://assets/pinewatch/music/"
const AMB_DIR := "res://assets/pinewatch/amb/"
const POOL := 8                            # concurrent UI sounds

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache := {}
var _music: AudioStreamPlayer
var _music_id := ""
var _amb_layers := {}            # layer id -> dedicated player


func _ready() -> void:
	for i in POOL:
		var p := AudioStreamPlayer.new()
		# the SFX bus exists by now (Game autoloads first); fall back
		# to Master if a stray boot order ever removes it
		p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 \
			else "Master"
		add_child(p)
		_players.append(p)
	_music = _layer_player("Music")


func _layer_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "Master"
	add_child(p)
	return p


func play_sfx(sfx_id: StringName) -> void:
	var s := _wav(SFX_DIR + String(sfx_id) + ".wav")
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.play()


## Raw .wav load — generated placeholders ship no .import files, so
## ResourceLoader can't see them.  load_from_file reads the wav
## straight off disk; missing paths cache as null to warn once.
func _wav(path: String) -> AudioStreamWAV:
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		push_warning("Audio: no wav at " + path)
		_cache[path] = null
		return null
	_cache[path] = AudioStreamWAV.load_from_file(path)
	return _cache[path]


## Looping track on the Music bus, faded in over the "chrome" token.
## Same-id calls are no-ops so _status() can assert the mood freely.
func play_music(track_id: StringName) -> void:
	if track_id == StringName(_music_id) and _music.playing:
		return
	var s := _loop_stream(MUSIC_DIR + String(track_id) + ".wav")
	if s == null:
		return
	_music_id = String(track_id)
	_music.stream = s
	_fade_in(_music)


## Ambience is a live MIX, not a switch: WorldFX calls this every
## scalar step with per-layer levels, so crossfades between beds
## (day birds / night crickets / storm wash) ride the front + dusk
## curves for free.  The caller owns the whole mix — layers absent
## from `mix` keep whatever level they last got, so always pass the
## full set (a 0 entry is how a bed goes quiet).  Volumes arrive
## 0..1 linear; a layer at ~0 stops its player so silent beds cost
## nothing.  No per-layer tween here — the caller's scalar already
## interpolates, setting volume_db directly keeps each step on-curve.
func set_ambience_mix(mix: Dictionary) -> void:
	for layer in mix:
		_set_amb_layer(StringName(layer),
			clampf(float(mix[layer]), 0.0, 1.0))


const AMB_ON := 0.02               # deadband: a layer only STARTS
const AMB_OFF := 0.008             # above 0.02 and only STOPS below
                                    # 0.008 — hovering at the gate can
                                    # never flap the player per-frame


func _set_amb_layer(layer: StringName, level: float) -> void:
	var p: AudioStreamPlayer = _amb_layers.get(layer)
	if p == null:
		if level <= AMB_ON:
			return
		p = _layer_player("Ambience")
		_amb_layers[layer] = p
	if not p.playing:
		if level <= AMB_ON:
			return
		p.stream = _loop_stream(AMB_DIR + String(layer) + ".wav")
		if p.stream == null:
			return
		p.play()
	elif level <= AMB_OFF:
		p.stop()
		return
	p.volume_db = linear_to_db(level)


func _fade_in(p: AudioStreamPlayer) -> void:
	p.volume_db = -24.0
	p.play()
	var tw := p.create_tween()
	tw.tween_property(p, "volume_db", 0.0, UIFeel.dur("chrome"))


func _loop_stream(path: String) -> AudioStream:
	var s := _wav(path)
	if s == null:
		return null
	# set the loop in code — the generated wavs ship no .import
	# loop flags, and audio.import isn't part of the tool contract
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return s
