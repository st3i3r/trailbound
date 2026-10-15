class_name ActorView
extends Node
## D4.2 view presenter (PLAN_gameplay §17): SimWorld -> sprite nodes.
##
## PURE VIEW — reads pos/persona/anim/emote comps, never writes back
## into the sim. Sprites are parented into `world` directly so they
## interleave with props in the y-sort (world sorts direct children
## only). Fixed-dt accumulation: `_process` banks real time and ticks
## the sim in DT steps; the whole clock freezes while `paused` fires
## (any sheet open — no actors walking while you read a letter).
##
## Rendering contract (actors.json anim_map):
##   walk/flee -> "_dir": distance-driven step cycle — the frame index
##     is a function of ground travelled (frame = acc/STEP_PX), so
##     cadence always matches speed at any gait; <key>_walk_<dir>_<i>
##     clips where they exist, else the 8-way stills swap as before
##   <other>  -> clip name: <key>_<anim>_south_<i>.png loops play
##     when present, else the south still (idle fallback chain)
## Personas with no clips still work — stills only.  Missing persona
## dirs degrade to actors.json's fallback sprite+tint.  Despawned
## eids fade out over ~0.3s.  Emote chips ride above the sprite.

const DT := 1.0 / 30.0                 # fixed sim step (presentation)
const DIR8 := ["east", "south-east", "south", "south-west",
	"west", "north-west", "north", "north-east"]
const FADE_OUT := 0.30
const STEP_PX := 5.0                   # 1 walk frame per 5px travelled
const CLIPS := ["idle", "walk", "fish", "sit", "play", "pet",
	"sniff", "wary"]
## diagonal travel drives the dominant-cardinal clip — generated
## walks only exist for N/S/E/W (8-way diagonal stills cover the
## rest), so a strafing actor keeps stepping instead of freezing
## on a still mid-slide
const CARD_OF := {
	"east": "east", "south-east": "south",
	"south": "south", "south-west": "south",
	"west": "west", "north-west": "north",
	"north": "north", "north-east": "north",
}

var sim: SimWorld
var actors_data: Dictionary = {}       # data/actors.json
var world: Node2D                      # sprite parent (y-sorted)
var paused: Callable = Callable()      # -> bool; scene injects panels
var tex: Callable = Callable()         # rel path -> Texture2D
var emote_show: Callable = Callable()  # (anchor,icon)->chip token|-1
var emote_hide: Callable = Callable()  # (token)->void
var char_scale := 1.0

var actor_nodes: Array = []            # scene fade-protection set
var _acc := 0.0
var _nodes := {}                       # eid -> rec
var _fading: Array = []                # [{node}]
var _prev := {}                        # eid -> Vector2 (dir tracking)


func configure(w: SimWorld, data: Dictionary, p_world: Node2D,
		p_tex: Callable, p_paused: Callable, p_scale: float,
		show := Callable(), hide := Callable()) -> void:
	sim = w
	actors_data = data
	world = p_world
	tex = p_tex
	paused = p_paused
	char_scale = p_scale
	emote_show = show
	emote_hide = hide


func clear() -> void:
	for eid in _nodes.keys():
		_free_rec(_nodes[eid])
	_nodes.clear()
	_prev.clear()
	for f in _fading:
		if is_instance_valid(f["node"]):
			f["node"].queue_free()
	_fading.clear()
	actor_nodes.clear()


func _process(delta: float) -> void:
	if sim == null:
		return
	if paused.is_valid() and paused.call():
		return                              # sim clock freezes on panels
	_acc += delta
	while _acc >= DT:
		sim.tick(DT)
		_acc -= DT
	_sync()
	_fade_step(delta)


func _sync() -> void:
	var live := {}
	# renderable = pos+persona — bare-pos entities (sit_spot sockets,
	# stimuli) are sim furniture the view must never materialize.
	for eid in sim.query(["pos", "persona"]):
		live[eid] = true
		var pos: Dictionary = sim.getc(eid, "pos")
		var p := Vector2(float(pos["x"]), float(pos["y"]))
		var rec: Dictionary = _nodes.get(eid, {})
		if rec.is_empty():
			rec = _spawn(eid)
			_nodes[eid] = rec
		var moved: Vector2 = p - _prev.get(eid, p)
		_prev[eid] = p
		_pose(rec, eid, p, moved)
		_emote(rec, eid)
		rec["node"].position = p.round()    # texel phase — whole px
	for eid in _nodes.keys():
		if not live.has(eid):
			_despawn(eid)


func _spawn(eid: int) -> Dictionary:
	var per: Dictionary = sim.getc(eid, "persona")
	var key := String(per.get("persona", ""))
	var sp := _sprite(key)
	world.add_child(sp)
	actor_nodes.append(sp)
	return {"node": sp, "key": key, "anim": "", "dir": "south",
		"chip": -1, "clip": "", "walk_acc": 0.0}


func _sprite(key: String) -> CanvasItem:
	var base := "characters/%s/%s" % [key, key]
	var has_dir := not key.is_empty() and ResourceLoader.exists(
		tex_path(base + "_south"))
	var sc := Vector2(char_scale, char_scale)
	if has_dir:
		var frames := SpriteFrames.new()
		for d in DIR8:                             # stills — always
			if ResourceLoader.exists(tex_path(base + "_" + d)):
				frames.add_animation("still_" + d)
				frames.add_frame("still_" + d,
					tex.call(base + "_" + d))
		for an in CLIPS:                           # generated clips
			for d in DIR8:
				var c := "%s_%s" % [an, d]
				if not ResourceLoader.exists(
						tex_path("%s_%s_0" % [base, c])):
					continue
				frames.add_animation(c)
				var i := 0
				while ResourceLoader.exists(
						tex_path("%s_%s_%d" % [base, c, i])):
					frames.add_frame(c,
						tex.call("%s_%s_%d" % [base, c, i]))
					i += 1
				frames.set_animation_speed(c, 5.0)
		var a := AnimatedSprite2D.new()
		a.sprite_frames = frames
		a.centered = false
		a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var first := "idle_south" if \
			frames.has_animation("idle_south") else "still_south"
		var sz := frames.get_frame_texture(first, 0).get_size()
		a.offset = -Vector2(sz.x / 2.0, sz.y)
		a.scale = sc
		a.animation = first
		a.play(first)
		# desync: stagger the start frame so the crowd never
		# breathes in phase (presentation-only randi — the sim
		# stays deterministic)
		a.frame = randi() % frames.get_frame_count(first)
		return a
	# fallback — the actors.json placeholder, tinted per persona entry
	var fb: Dictionary = actors_data.get("fallback", {})
	var s2 := Sprite2D.new()
	var fp := String(fb.get("sprite", ""))
	if ResourceLoader.exists(tex_path(fp)):
		s2.texture = tex.call(fp)
	s2.centered = false
	s2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if s2.texture != null:
		s2.offset = -Vector2(s2.texture.get_width() / 2.0,
			s2.texture.get_height())
	var tint := String(fb.get("tint", ""))
	if tint != "":
		s2.modulate = Color(tint)
	s2.scale = sc
	return s2


func tex_path(rel: String) -> String:
	return "res://assets/pinewatch/" + rel + ".png"


func _pose(rec: Dictionary, eid: int, p: Vector2,
		moved: Vector2) -> void:
	var anim: Dictionary = sim.getc(eid, "anim")
	var aname := String(anim.get("name", "idle"))
	var render := String(actors_data.get("anim_map", {})
		.get(aname, "idle"))
	if moved.length() > 0.5:
		rec["dir"] = _dir8(moved)
	rec["walk_acc"] += moved.length()
	var n: CanvasItem = rec["node"]
	if n is AnimatedSprite2D:
		var frames: SpriteFrames = n.sprite_frames
		if render == "_dir":
			var wc: String = "walk_" + String(
				CARD_OF.get(rec["dir"], rec["dir"]))
			if not frames.has_animation(wc):
				wc = "walk_" + rec["dir"]      # rare: diag clip exists
			if frames.has_animation(wc):
				_clip(rec, wc)
				n.stop()                    # frame = f(distance)
				n.frame = int(rec["walk_acc"] / STEP_PX) \
					% frames.get_frame_count(wc)
			else:                            # no clip dir -> still
				_clip(rec, "still_" + rec["dir"])
		else:
			var c := render + "_south"
			var fps := float(anim.get("fps", 5.0))
			if frames.has_animation(c):
				_clip(rec, c, fps)
			elif frames.has_animation("idle_south"):
				_clip(rec, "idle_south", fps)
			else:
				_clip(rec, "still_south")
	elif n is Sprite2D:
		_still(rec, rec["dir"] if render == "_dir" else "south")


func _clip(rec: Dictionary, c: String, fps := 5.0) -> void:
	if rec["clip"] == c:
		return
	rec["clip"] = c
	var n: AnimatedSprite2D = rec["node"]
	n.sprite_frames.set_animation_speed(c, fps)
	n.animation = c
	n.play(c)


func _still(rec: Dictionary, dir: String) -> void:
	var n: Sprite2D = rec["node"]
	if rec["anim"] == dir:
		return
	var key := String(rec["key"])
	var rel := "characters/%s/%s_%s" % [key, key, dir]
	if ResourceLoader.exists(tex_path(rel)):
		n.texture = tex.call(rel)
		n.offset = -Vector2(n.texture.get_width() / 2.0,
			n.texture.get_height())
		rec["anim"] = dir


func _dir8(d: Vector2) -> String:
	var ang := atan2(d.y, d.x)              # y-down: +y = south
	var i := int(round(ang / (PI / 4.0))) & 7
	return DIR8[i]


func _emote(rec: Dictionary, eid: int) -> void:
	var em: Dictionary = sim.getc(eid, "emote", {})
	var has := not em.is_empty()
	if has == (int(rec["chip"]) != -1):
		return
	if has and emote_show.is_valid():
		rec["chip"] = int(emote_show.call(rec["node"],
			String(em.get("icon", "!"))))
	elif rec["chip"] != -1:
		if emote_hide.is_valid():
			emote_hide.call(int(rec["chip"]))
		rec["chip"] = -1


func _despawn(eid: int) -> void:
	var rec: Dictionary = _nodes[eid]
	_nodes.erase(eid)
	_prev.erase(eid)
	actor_nodes.erase(rec["node"])
	if int(rec["chip"]) != -1 and emote_hide.is_valid():
		emote_hide.call(int(rec["chip"]))
	rec["node"].z_index = -1
	_fading.append(rec)


func _fade_step(delta: float) -> void:
	for i in range(_fading.size() - 1, -1, -1):
		var n: CanvasItem = _fading[i]["node"]
		if not is_instance_valid(n):
			_fading.remove_at(i)
			continue
		n.modulate.a = move_toward(n.modulate.a, 0.0,
			delta / FADE_OUT)
		if n.modulate.a <= 0.0:
			n.queue_free()
			_fading.remove_at(i)


func _free_rec(rec: Dictionary) -> void:
	if is_instance_valid(rec["node"]):
		rec["node"].queue_free()
