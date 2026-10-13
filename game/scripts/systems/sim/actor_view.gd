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
##   walk -> "_dir": 8-way directional stills <key>_<dir>.png
##   <other> -> "idle": south still; <key>_idle_south_<n>.png loops
##     upgrade to an AnimatedSprite2D with a per-eid phase offset
## Missing persona dirs degrade to actors.json's fallback sprite+tint.
## Despawned eids fade out over ~0.3s. Emote comps raise a chip over
## the sprite while emote.t lives.

const DT := 1.0 / 30.0                 # fixed sim step (presentation)
const DIR8 := ["east", "south-east", "south", "south-west",
	"west", "north-west", "north", "north-east"]
const FADE_OUT := 0.30

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
	for eid in sim.query(["pos"]):
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
		"chip": -1}


func _sprite(key: String) -> CanvasItem:
	var base := "characters/%s/%s" % [key, key]
	var has_dir := not key.is_empty() and ResourceLoader.exists(
		tex_path(base + "_south"))
	var sc := Vector2(char_scale, char_scale)
	if has_dir:
		var idle0 := base + "_idle_south_0"
		if ResourceLoader.exists(tex_path(idle0)):
			var frames := SpriteFrames.new()
			frames.add_animation("main")
			var i := 0
			while ResourceLoader.exists(
					tex_path("%s_idle_south_%d" % [base, i])):
				frames.add_frame("main", tex.call(
					"%s_idle_south_%d" % [base, i]))
				i += 1
			frames.set_animation_speed("main", 4.0)
			var a := AnimatedSprite2D.new()
			a.sprite_frames = frames
			a.centered = false
			a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var sz := frames.get_frame_texture("main", 0).get_size()
			a.offset = -Vector2(sz.x / 2.0, sz.y)
			a.scale = sc
			a.play("main")
			return a
		var s := Sprite2D.new()
		s.texture = tex.call(base + "_south")
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.offset = -Vector2(s.texture.get_width() / 2.0,
			s.texture.get_height())
		s.scale = sc
		return s
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
	if render == "_dir":
		_still(rec, rec["dir"])
	elif rec["node"] is Sprite2D:
		_still(rec, "south")


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
