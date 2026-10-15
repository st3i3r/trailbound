class_name SimDirector
extends RefCounted
## Casting layer (PLAN_gameplay D4): Game state -> SimWorld entity
## programs. v1 uses a minimal in-code table (guest idle at pad,
## dog patrol, angler walks to the bank); the full
## archetype/trait/item/weather scenario matrix becomes a JSON
## data file when real scenarios land.

const CELL := SimGrid.CELL


static func _cell_pt(c: Variant, dy := 48.0) -> Vector2:
	if c is Vector2i:
		return SimGrid.cell_pt(c, dy)
	return SimGrid.cell_pt(Vector2i(int(c[0]), int(c[1])), dy)


## All fishable bank points for the layout — pond (scalar), stream
## (scalar) and the named fishing dict all normalize to px points,
## sorted so the seeded pick below can't depend on dict order.
static func _banks(layout: Dictionary) -> Array:
	var es: Dictionary = layout.get("errand_spots", {})
	var pts := []
	for key in ["pond", "stream"]:
		var p: Variant = es.get(key)
		if p is Array and p.size() >= 2:
			pts.append(Vector2(float(p[0]), float(p[1])))
	var fishing: Dictionary = es.get("fishing", {})
	var names := fishing.keys()
	names.sort()
	for k in names:
		var p: Variant = fishing[k]
		if p is Array and p.size() >= 2:
			pts.append(Vector2(float(p[0]), float(p[1])))
	return pts


## Archetypes that use a claimed sit_spot when one's free (spec 003) —
## kids and anglers keep their own verbs, everyone else is "restful".
const SITTER_CHANCE := 0.45
const SITTER_ARCHS := ["couple", "hiker", "scout", "van_lifer",
	"photographer", "cyclist", "food_blogger"]
## §variants (spec 006, anti-pattern 5): one seeded draw per guest
## splits loop shapes — the ACNH personality-set trick, so two
## hikers don't run the same evening. Bands share the draw: sitter
## < SITTER_CHANCE, vista stroll to VISTA_END, fire linger to
## FIRE_END, idle loop above. Kids tag and the angler circuit are
## their own sub-bands.
const VISTA_END := 0.70
const FIRE_END := 0.85
const TAG_CHANCE := 0.30
const TWO_BANK_CHANCE := 0.40


## One tagged entity per socket per placed piece (spec 003):
## {id, kind, px_offset, facing} on the decor row → a bare
## pos+tags entity the view ignores (renderable = pos+persona).
static func _spawn_sockets(w: SimWorld, st: Dictionary) -> Array:
	var out := []
	for d in st.get("decor", []):
		var cells: Array = d.get("cells", [])
		if cells.is_empty():
			continue
		var row: Dictionary = {}
		for r in Catalog.data.get("decor", []):
			if r.get("id") == d["id"]:
				row = r
				break
		var socks: Array = row.get("sockets", [])
		for so in socks:
			var off: Array = so.get("px_offset", [0, 0])
			var pt := _cell_pt(cells[0]) + Vector2(
				float(off[0]), float(off[1]))
			var eid := w.spawn({"pos": {"x": pt.x, "y": pt.y},
				"tags": {"tags": ["sit_spot", "free"]},
				"socket": {"item": d["id"],
					"slot": String(so.get("id", ""))}})
			out.append({"eid": eid, "pos": pt})
	return out


## Storm wrap (§14): prepend a select that diverts any guest into a
## tent-huddle when ctx.weather == "storm" — nobody banks in a gale.
## Every base program loops back to 0, so the select re-checks each
## pass while staying deterministic (ctx is fixed at cast).
static func _storm_wrap(steps: Array, home: Vector2) -> Array:
	var out := [{"op": "select", "else": 1,
		"branches": [{"ctx": {"weather": "storm"}, "goto": "huddle"}]}]
	out.append_array(steps)
	out.append_array([{"op": "anim", "name": "sit", "label": "huddle"},
		{"op": "emote", "icon": "sigh", "t": 1.5},
		{"op": "wait", "t": 5.0},
		{"op": "goto", "to": [home.x, home.y], "speed": 30.0},
		{"op": "jump", "to": 0}])
	return out


## Sit-spot program (spec 003): walk to the claimed socket, sit a
## while, emote (heart by day, sigh in the rain), walk home.
static func _sit_program(layout: Dictionary, home: Vector2,
		spot: Vector2, weather: String) -> Array:
	var steps := [{"op": "anim", "name": "walk"}]
	steps.append_array(_goto_legs(layout, home, spot, 40.0))
	steps.append_array([{"op": "anim", "name": "sit"},
		{"op": "wait", "t": 6.0},
		{"op": "emote", "icon": "sigh" if weather == "storm" \
			else "heart", "t": 1.5},
		{"op": "wait", "t": 2.0}, {"op": "anim", "name": "walk"}])
	steps.append_array(_goto_legs(layout, spot, home, 40.0))
	steps.append_array([{"op": "anim", "name": "idle"},
		{"op": "wait", "t": 4.0}, {"op": "jump", "to": 0}])
	return steps


## §13.5/§17.3 duet: two parties of the same archetype (the couple
## vignette class) meet at the named decor — goto its socket area,
## rendezvous via `await`, sway, walk home. One pair per night.
static func _duet_program(layout: Dictionary, home: Vector2,
		peer_gid: String, meet: Vector2) -> Array:
	var steps := [{"op": "anim", "name": "walk"}]
	steps.append_array(_goto_legs(layout, home, meet, 45.0))
	steps.append_array([{"op": "anim", "name": "idle"},
		{"op": "await", "peer": peer_gid, "r": 48.0, "t": 10.0},
		{"op": "anim", "name": "play"},
		{"op": "emote", "icon": "heart", "t": 2.0},
		{"op": "wait", "t": 6.0}, {"op": "anim", "name": "walk"}])
	steps.append_array(_goto_legs(layout, meet, home, 45.0))
	steps.append_array([{"op": "anim", "name": "idle"},
		{"op": "wait", "t": 8.0}, {"op": "jump", "to": 0}])
	return steps


static func _px_cell(p: Vector2) -> Vector2i:
	return SimGrid.px_cell(p)


## Cast-time routing (static cost matrix, PLAN D4): the map
## dictates the path, not the actor. nav.blocked cells cost inf;
## pad cells cost pad_cost (prefer walking around tents, not
## through them). Straight lines take the fast path; anything
## crossing water/fire/the treeline gets an A* detour emitted as
## a chain of goto steps — deterministic, no runtime pathfinding.
static func _route(layout: Dictionary, a: Vector2,
		b: Vector2) -> Array:
	var nav: Dictionary = layout.get("nav", {})
	var bcells := SimGrid.blocked(layout)
	# §road (spec 006, anti-pattern 4): nav.road cells carry a
	# discounted step cost — the trail wins ties, the lawn stays
	# walkable. Any road data means the straight-line fast path is
	# wrong to take without scoring it, so the A* always runs.
	var road := {}
	for c in nav.get("road", []):
		if c is Array and c.size() >= 2:
			road["%d,%d" % [int(c[0]), int(c[1])]] = true
	var road_cost := float(nav.get("road_cost", 0.7))
	if bcells.is_empty() and road.is_empty():
		return [b]
	var blocked := {}
	for c in bcells:
		blocked["%d,%d" % [c.x, c.y]] = true
	var ca := _px_cell(a)
	var cb := _px_cell(b)
	if _los(blocked, ca, cb) and road.is_empty():
		return [b]
	# A* on the cell grid (4-dir); pads are soft cost, the
	# destination cell is always allowed even if flagged
	var pads: Dictionary = layout.get("pads", {}).get("spots", {})
	var pad_cost := float(nav.get("pad_cost", 3.0))
	var hmin := minf(1.0, road_cost)
	var open := [{"c": ca, "f": 0.0}]
	var came := {}
	var cost := {"%d,%d" % [ca.x, ca.y]: 0.0}
	var found := false
	var guard := 0
	while not open.is_empty() and guard < 400:
		guard += 1
		var bi := 0
		for i in open.size():
			if open[i]["f"] < open[bi]["f"]:
				bi = i
		var cur: Dictionary = open[bi]
		open.remove_at(bi)
		var c: Vector2i = cur["c"]
		if c == cb:
			found = true
			break
		var ck := "%d,%d" % [c.x, c.y]
		for d in [Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			var nk := "%d,%d" % [n.x, n.y]
			if blocked.has(nk) and n != cb:
				continue
			var step: float = road_cost if road.has(nk) else 1.0
			for pid in pads:
				var pc: Array = pads[pid]
				if int(pc[0]) == n.x and int(pc[1]) == n.y:
					step = pad_cost
					break
			var nc: float = cost[ck] + step
			if not cost.has(nk) or nc < cost[nk]:
				cost[nk] = nc
				came[nk] = ck
				# Manhattan × cheapest step stays admissible
				var h: float = (absf(n.x - cb.x) + absf(
					n.y - cb.y)) * hmin
				open.append({"c": n, "f": nc + h})
	if not found:
		return [b]
	var cells: Array = [cb]
	var k := "%d,%d" % [cb.x, cb.y]
	var sk := "%d,%d" % [ca.x, ca.y]
	while k != sk:
		k = came[k]
		var parts := k.split(",")
		cells.push_front(Vector2i(int(parts[0]),
			int(parts[1])))
	var pts := []
	for c2 in cells:
		pts.append(_cell_pt([c2.x, c2.y]))
	pts.append(b)
	return pts


## Supercover line-of-sight over the cell grid: any blocked cell
## on the straight path (destination excluded) means we route.
static func _los(blocked: Dictionary, a: Vector2i,
		b: Vector2i) -> bool:
	var x := a.x
	var y := a.y
	var dx: int = b.x - a.x
	var dy: int = b.y - a.y
	var nx: int = absi(dx)
	var ny: int = absi(dy)
	var sx := 1 if dx > 0 else -1
	var sy := 1 if dy > 0 else -1
	var err := nx - ny
	while not (x == b.x and y == b.y):
		if blocked.has("%d,%d" % [x, y]):
			return false
		var e2 := 2 * err
		if e2 > -ny:
			err -= ny
			x += sx
		elif e2 < nx:
			err += nx
			y += sy
	return true


## Route -> goto step chain (each goto blocks until arrival, so
## consecutive gotos are natural waypoint following).
static func _goto_legs(layout: Dictionary, a: Vector2,
		b: Vector2, speed: float) -> Array:
	var steps := []
	for p in _route(layout, a, b):
		steps.append({"op": "goto", "to": [p.x, p.y],
			"speed": speed})
	return steps


static func _schedule(steps: Array) -> Dictionary:
	_resolve_labels(steps)
	return {"steps": steps, "i": 0, "wait": 0.0, "started": false}


## Programs may mark a step with "label" and branch to it by name
## (jump.to / react.goto / band.goto) instead of magic indexes —
## resolved once at schedule build, so editing a program can no
## longer silently re-point a branch.
static func _resolve_labels(steps: Array) -> void:
	var at := {}
	for i in steps.size():
		var lbl: Variant = steps[i].get("label")
		if lbl != null:
			at[lbl] = i
	for st in steps:
		st.erase("label")
		if st.get("op") == "jump":
			var v: Variant = st.get("to")
			if v is String and at.has(v):
				st["to"] = at[v]
		var gt: Variant = st.get("goto")
		if gt is String and at.has(gt):
			st["goto"] = at[gt]
		for b in st.get("bands", []):
			var v: Variant = b.get("goto")
			if v is String and at.has(v):
				b["goto"] = at[v]
		for b in st.get("branches", []):
			var v2: Variant = b.get("goto")
			if v2 is String and at.has(v2):
				b["goto"] = at[v2]


## Seed-baked entropy (PLAN D4): draw per-entity phase offsets and
## wait-time jitter from the world rng at cast time — identical
## loops desynchronize while replay stays deterministic (draws
## happen in spawn order). Applied to wait steps + a start delay.
static func _jitter(w: SimWorld, steps: Array) -> Dictionary:
	for st in steps:
		if st.get("op") == "wait":
			st["t"] = maxf(0.2, float(st["t"]) +
				w.rng.randf_range(-0.4, 0.4) * float(st["t"]))
	var sc := _schedule(steps)
	sc["wait"] = w.rng.randf_range(0.0, 1.5)
	return sc


## Wrap a base loop with a scored-stimulus check (production
## response pipeline, PLAN D4): step 0's `respond` consults the
## entity's percept map — weights live on the perceive comp, so
## the same wrap serves any stimulus. Kids: flee / wary / pet.
## Wary personas: flee / wary. The stimulus tags are parameters.
static func _stim_wrap(base: Array, stim_tags: Array,
		home: Vector2, allow_pet: bool) -> Array:
	var steps := [{"op": "respond", "tags": stim_tags}]
	steps.append_array(base)
	steps.append_array([{"op": "anim", "name": "flee",
			"label": "flee"},
		{"op": "goto", "to": [home.x, home.y], "speed": 80.0},
		{"op": "wait", "t": 2.0}, {"op": "jump", "to": 0}])
	steps.append_array([{"op": "anim", "name": "wary",
			"label": "wary"},
		{"op": "wait", "t": 1.5}, {"op": "jump", "to": 0}])
	var bands := [{"gte": 0.55, "goto": "flee"},
		{"gte": 0.25, "goto": "wary"}]
	if allow_pet:
		steps.append_array([
			{"op": "goto", "percept": stim_tags[0],
				"speed": 35.0, "label": "pet"},
			{"op": "anim", "name": "pet"},
			{"op": "emote", "icon": "heart", "t": 1.5},
			{"op": "wait", "t": 1.5}, {"op": "jump", "to": 0}])
		bands.append({"else": true, "goto": "pet"})
	else:
		bands.append({"else": true, "goto": "wary"})
	steps[0]["bands"] = bands
	return steps


## Rare beats (spec 004-D): at most one low-weight beat per night,
## rolled from w.rng at cast — deterministic delight, never randf
## at tick. `when` gates on cast ctx (meteor needs clear skies).
const RARE_CHANCE := 0.18
const _RARE_BEATS := [
	{"id": "raccoon", "weight": 1.0},
	{"id": "meteor", "weight": 0.7, "when": {"weather": "clear"}},
	{"id": "swim", "weight": 0.5, "when": {"weather": "clear"}},
]


static func _roll_rare_beat(w: SimWorld, ctx: Dictionary) -> String:
	if w.rng.randf() >= RARE_CHANCE:
		return ""
	var rows := []
	for r in _RARE_BEATS:
		var ok := true
		for k in r.get("when", {}):
			if ctx.get(k) != r["when"][k]:
				ok = false
		if ok:
			rows.append(r)
	if rows.is_empty():
		return ""
	var total := 0.0
	for r in rows:
		total += float(r["weight"])
	var pick := w.rng.randf() * total
	for r in rows:
		pick -= float(r["weight"])
		if pick <= 0.0:
			return String(r["id"])
	return ""


## Persona pick — pure hash on (gid, cast seed): the same guest gets
## the same face whether drawn at cast time or at seat time (the seat
## visual uses this too, so the seated sprite IS the face the actor
## performs with — order-independent, no rng coupling). Missing pools
## degrade to the fallback sprite+tint; `persona` keeps the key for
## anim lookup. Returns "" when the pool is empty.
static func persona_key(gid: String, arch: String, seed: int,
		personas: Dictionary) -> String:
	var pool: Array = personas.get("archetypes", {}).get(arch, [])
	if pool.is_empty():
		return ""
	return String(pool[absi(int(hash("%s:%d" % [gid, seed])))
		% pool.size()])


static func _persona(_w: SimWorld, personas: Dictionary, arch: String,
		gid: String, seed: int) -> Dictionary:
	var key := persona_key(gid, arch, seed, personas)
	if key.is_empty():
		var fb: Dictionary = personas.get("fallback", {})
		return {"sprite": String(fb.get("sprite", "")),
			"tint": String(fb.get("tint", "")), "guest": gid}
	return {"persona": key,
		"sprite": "characters/%s/%s_south" % [key, key],
		"guest": gid}


## Evening cast: every seated guest performs an archetype loop from
## their pad; the dog patrols when adopted. Deterministic — same
## state + seed => same performance. `personas` = data/actors.json —
## faces are hash-picked per (gid, seed), independent of iteration
## order, so the same night replays the same faces (D4.1).
static func cast_night(st: Dictionary, layout: Dictionary,
		seed: int, personas: Dictionary = {}) -> SimWorld:
	var w := SimWorld.new(seed)
	var spots: Dictionary = layout.get("pads", {}).get("spots", {})
	var banks: Array = _banks(layout)
	var weather := String(st.get("weather", "clear"))
	# cast context for select/if branches: which items exist and
	# where — placement changes the night (AC-style item binding)
	var items: Array = []
	var item_pt := {}
	for d in st.get("decor", []):
		items.append(d["id"])
		var cells: Array = d.get("cells", [])
		if not cells.is_empty():
			item_pt[d["id"]] = _cell_pt(cells[0])
	w.ctx = {"items": items, "weather": weather,
		"event": String(st.get("event", "")),
		"stoked": bool(st.get("fire_stoked", false))}
	var dog_here: bool = st.get("dog", {}).get("met", false) \
		or items.has("dog_bed")
	# spec 004-D: one seeded rare beat can reshape tonight's cast —
	# rolled before guests so programs can author around it.
	var beat := _roll_rare_beat(w, w.ctx)
	# spec 003: seat sockets spawn as bare pos+tags affordances;
	# the Director claims them in cast order (seeded) so two guests
	# never perform on the same cushion.
	var free_sockets := _spawn_sockets(w, st)
	var couples := []                              # duet pairing list
	# §variants destinations: vista points a guest would walk to see
	# (banks + lookout) and a free spot on the fire ring to linger by
	var poi: Array = banks.duplicate()
	var lv: Variant = layout.get("errand_spots", {}).get("lookout")
	if lv is Array and lv.size() >= 2:
		poi.append(Vector2(float(lv[0]), float(lv[1])))
	var fire_spot := Vector2.ZERO
	var fcell: Variant = layout.get("campfire", {}).get("cell")
	if fcell is Array and fcell.size() >= 2:
		var fb := SimGrid.blocked(layout)
		for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0),
				Vector2i(-1, 0), Vector2i(0, 1)]:
			var fc := Vector2i(int(fcell[0]),
				int(fcell[1])) + d
			if not fb.has(fc):
				fire_spot = _cell_pt(fc)
				break
	# iterate the board (canonical seed order), not the assignments
	# dict — seat order differs across replays but the cast must not.
	# Stray assigned gids (fixture/partial states) append sorted.
	var seated := []
	var cards := {}
	var assign: Dictionary = st.get("assignments", {})
	for r in st.get("board", []):
		var gid_b := String(r.get("id", ""))
		cards[gid_b] = r
		if assign.has(gid_b):
			seated.append(gid_b)
	var stray := []
	for gid in assign:
		if gid not in seated:
			stray.append(String(gid))
	stray.sort()
	seated.append_array(stray)
	for gid in seated:
		var pads: Array = st["assignments"][gid]
		if pads.is_empty() or not spots.has(pads[0]):
			continue
		var pid: String = pads[0]
		var home := _cell_pt(spots[pid])
		var g: Dictionary = st.get("guests", {}).get(gid, {})
		var arch := String(g.get("archetype", ""))
		var traits: Array = g.get("traits", [])
		var anchor := {"kind": "pad", "ref": pid}
		var steps: Array
		var extra := {}
		# §variants: one draw per guest splits the evening's shape;
		# every branch consumes it so draw order stays stable
		var v := w.rng.randf()
		match arch:
			"kids", "family":
				# the swing the player placed changes the cast;
				# the dog's proximity scores their reaction
				var base: Array
				var nbrs: Array = layout.get("pads", {}) \
					.get("neighbours", {}).get(pid, [])
				if item_pt.has("swing"):
					var sw: Vector2 = item_pt["swing"]
					anchor = {"kind": "item", "ref": "swing"}
					base = [{"op": "anim", "name": "walk"}]
					base.append_array(_goto_legs(layout, home,
						sw, 55.0))
					base.append_array([
						{"op": "anim", "name": "play"},
						{"op": "wait", "t": 5.0},
						{"op": "anim", "name": "walk"}])
					base.append_array(_goto_legs(layout, sw,
						home, 55.0))
					base.append_array([
						{"op": "anim", "name": "idle"},
						{"op": "wait", "t": 3.0},
						{"op": "jump", "to": 0}])
				elif v < TAG_CHANCE and not nbrs.is_empty() \
						and spots.has(nbrs[0]):
					# tag chase (§variants): bolt to a neighbouring
					# pad, play there, bolt back — the loudest loop
					var tpt := _cell_pt(spots[nbrs[0]])
					base = [{"op": "anim", "name": "walk"}]
					base.append_array(_goto_legs(layout, home,
						tpt, 70.0))
					base.append_array([
						{"op": "anim", "name": "play"},
						{"op": "wait", "t": 2.5},
						{"op": "anim", "name": "walk"}])
					base.append_array(_goto_legs(layout, tpt,
						home, 70.0))
					base.append_array([
						{"op": "anim", "name": "play"},
						{"op": "wait", "t": 2.5},
						{"op": "jump", "to": 0}])
				else:
					base = [{"op": "anim", "name": "play"},
						{"op": "wait", "t": 4.0},
						{"op": "jump", "to": 0}]
				if dog_here:
					extra["perceive"] = {"sight_r": 150.0,
						"weights": {"dog": 0.55, "fluffy": 0.55}}
					steps = _stim_wrap(base, ["dog", "fluffy"],
						home, true)
				else:
					steps = base
			_:
				if traits.has("dog_wary") and dog_here:
					# two senses: bark cue -> flinch (hearing);
					# dog proximity -> flee/wary (scored sight)
					extra["perceive"] = {"hear_r": 140.0,
						"sight_r": 150.0,
						"weights": {"dog": 0.9}}
					steps = [
						{"op": "react", "to": "bark",
							"goto": "flinch"},
						{"op": "respond", "tags": ["dog"],
							"bands": [
								{"gte": 0.55, "goto": "flee"},
								{"else": true, "goto": "wary"}]},
						{"op": "anim", "name": "idle"},
						{"op": "wait", "t": 4.0},
						{"op": "jump", "to": 0},
						{"op": "emote", "icon": "!",
							"t": 1.0, "label": "flinch"},
						{"op": "jump", "to": 0},
						{"op": "anim", "name": "flee",
							"label": "flee"},
						{"op": "goto", "to": [home.x, home.y],
							"speed": 80.0},
						{"op": "wait", "t": 2.0},
						{"op": "jump", "to": 0},
						{"op": "anim", "name": "wary",
							"label": "wary"},
						{"op": "wait", "t": 1.5},
						{"op": "jump", "to": 0}]
				elif arch == "angler" and not banks.is_empty():
					var bank: Vector2 = banks[w.rng.randi()
						% banks.size()]
					if banks.size() >= 2 and v < TWO_BANK_CHANCE:
						# the circuit (§variants): works two banks
						var bank2: Vector2 = banks[w.rng.randi()
							% banks.size()]
						if bank2 == bank:
							bank2 = banks[(banks.find(bank) + 1)
								% banks.size()]
						steps = [{"op": "anim", "name": "walk"}]
						steps.append_array(_goto_legs(layout,
							home, bank, 40.0))
						steps.append_array([
							{"op": "anim", "name": "fish"},
							{"op": "wait", "t": 5.0},
							{"op": "anim", "name": "walk"}])
						steps.append_array(_goto_legs(layout,
							bank, bank2, 40.0))
						steps.append_array([
							{"op": "anim", "name": "fish"},
							{"op": "wait", "t": 5.0},
							{"op": "anim", "name": "walk"}])
						steps.append_array(_goto_legs(layout,
							bank2, home, 40.0))
						steps.append_array([
							{"op": "anim", "name": "sit"},
							{"op": "wait", "t": 5.0},
							{"op": "jump", "to": 0}])
					else:
						steps = [{"op": "anim", "name": "walk"}]
						steps.append_array(_goto_legs(layout,
							home, bank, 40.0))
						steps.append_array([
							{"op": "anim", "name": "fish"},
							{"op": "wait", "t": 8.0},
							{"op": "anim", "name": "walk"}])
						steps.append_array(_goto_legs(layout,
							bank, home, 40.0))
						steps.append_array([
							{"op": "anim", "name": "sit"},
							{"op": "wait", "t": 6.0},
							{"op": "jump", "to": 0}])
				elif arch in SITTER_ARCHS \
						and not free_sockets.is_empty() \
						and v < SITTER_CHANCE:
					# claim a socket: it stops advertising itself
					# and the program bakes the exact seat point
					var so: Dictionary = free_sockets.pop_front()
					var sock_tags: Dictionary = w.getc(
						so["eid"], "tags")
					sock_tags["tags"] = ["sit_spot", "claimed"]
					steps = _sit_program(layout, home,
						so["pos"], weather)
				elif v < VISTA_END and not poi.is_empty():
					# vista stroll (§variants): "went to see the
					# water" — a walk with a destination, then home
					var vpt: Vector2 = poi[w.rng.randi()
						% poi.size()]
					steps = [{"op": "anim", "name": "walk"}]
					steps.append_array(_goto_legs(layout,
						home, vpt, 35.0))
					steps.append_array([
						{"op": "anim", "name": "idle"},
						{"op": "wait", "t": 6.0},
						{"op": "anim", "name": "walk"}])
					steps.append_array(_goto_legs(layout,
						vpt, home, 35.0))
					steps.append_array([
						{"op": "anim", "name": "sit"},
						{"op": "wait", "t": 4.0},
						{"op": "jump", "to": 0}])
				elif v < FIRE_END and fire_spot != Vector2.ZERO:
					# fire linger (§variants): drift to the ring,
					# warm a while, drift back
					steps = [{"op": "anim", "name": "walk"}]
					steps.append_array(_goto_legs(layout,
						home, fire_spot, 30.0))
					steps.append_array([
						{"op": "anim", "name": "idle"},
						{"op": "wait", "t": 6.0},
						{"op": "anim", "name": "walk"}])
					steps.append_array(_goto_legs(layout,
						fire_spot, home, 30.0))
					steps.append_array([
						{"op": "anim", "name": "sit"},
						{"op": "wait", "t": 4.0},
						{"op": "jump", "to": 0}])
				else:
					steps = [{"op": "anim", "name": "idle"},
						{"op": "wait", "t": 4.0},
						{"op": "jump", "to": 0}]
		if beat == "meteor" and (traits.has("stargazer") \
				or traits.has("night_owl")):
			# meteor beat (spec 004-D): sky-watchers gain a scored
			# response to the "sky" stimulus — glance up, gasp,
			# watch a while, drift back to their loop.
			var per: Dictionary = extra.get("perceive",
				{"sight_r": 240.0, "weights": {}})
			per["weights"]["sky"] = 0.8
			extra["perceive"] = per
			steps.push_front({"op": "respond", "tags": ["sky"],
				"bands": [{"gte": 0.5, "goto": "gaze"}]})
			steps.append_array([
				{"op": "anim", "name": "sit", "label": "gaze"},
				{"op": "emote", "icon": "!", "t": 1.5},
				{"op": "wait", "t": 5.0},
				{"op": "goto", "to": [home.x, home.y],
					"speed": 30.0},
				{"op": "jump", "to": 0}])
		steps = _storm_wrap(steps, home)
		# §depth beats: the evening's care shows in the cast — a
		# tucked or wish-granted guest settles with a heart; a
		# returning face greets the camp it knows. One emote up
		# front, then the loop takes over like any idle beat.
		var card: Dictionary = cards.get(gid, {})
		if bool(g.get("tucked", false)) or bool(card.get("wish_met", false)):
			steps.insert(0, {"op": "emote", "icon": "heart",
				"t": 1.2})
		elif bool(card.get("returning", false)):
			steps.insert(0, {"op": "emote", "icon": "!",
				"t": 1.2})
		# trait tags make guests visible stimuli — the dog reads
		# "dog_lover" for its greeting beat; future scenarios read
		# any trait without new machinery.
		var comps := {"pos": {"x": home.x, "y": home.y},
			"schedule": _jitter(w, steps),
			"anchor": anchor,
			"persona": _persona(w, personas, arch, gid, seed),
			"tags": {"tags": traits.duplicate()},
			"anim": {"name": "idle", "fps": 6.0}}
		for k in extra:
			comps[k] = extra[k]
		var eid := w.spawn(comps)
		if arch == "couple":
			couples.append({"eid": eid, "gid": gid, "home": home})
	# §13.5 slow-dance: two seated couples + string lights = the duet
	# (the vignette of the same name reads the same conditions).
	if couples.size() >= 2 and item_pt.has("string_lights"):
		var meet: Vector2 = item_pt["string_lights"] + Vector2(24, 12)
		for i in 2:
			# swap the whole schedule comp — _jitter resolves the
			# wrapped labels and re-seeds the phase offset
			var duet := _storm_wrap(_duet_program(layout,
				couples[i]["home"], couples[1 - i]["gid"], meet),
				couples[i]["home"])
			w.put(couples[i]["eid"], "schedule",
				_jitter(w, duet))
	# the dog does its rounds past seated guests (§9): sniff, bark —
	# the bark cue is what dog_wary guests react to. spec 005-D
	# presence beats: a storm shelters it, an empty camp (quiet
	# night) curls it at the fire instead of patrolling nobody.
	if dog_here:
		var visit := []
		for gid in seated:
			for pid in st["assignments"][gid]:
				if spots.has(pid) and not visit.has(pid):
					visit.append(pid)
		if visit.is_empty():
			visit = spots.keys()
			visit.sort()
			visit = visit.slice(0, 3)
		var fc_dog := _cell_pt(layout.get("campfire", {})
			.get("cell", [6, 4]))
		var start_pt := fc_dog if visit.is_empty() \
			else _cell_pt(spots[visit[0]])
		var steps: Array
		if weather == "storm":
			# shelter beat: nobody patrols in a gale — curl up in
			# the lee of the fire and whimper at the thunder
			var lee := fc_dog + Vector2(40, 20)
			steps = [{"op": "anim", "name": "walk"}]
			steps.append_array(_goto_legs(layout, start_pt,
				lee, 55.0))
			steps.append_array([
				{"op": "anim", "name": "sit"},
				{"op": "emote", "icon": "sigh", "t": 1.5},
				{"op": "wait", "t": 6.0},
				{"op": "emote", "icon": "!", "t": 1.0},
				{"op": "wait", "t": 4.0},
				{"op": "jump", "to": 0}])
		elif st.get("assignments", {}).is_empty():
			# quiet-night beat: no guests to guard — curl at the
			# fire and doze, tail wag in its sleep
			var curl := fc_dog + Vector2(-36, 28)
			steps = [{"op": "anim", "name": "walk"}]
			steps.append_array(_goto_legs(layout, start_pt,
				curl, 40.0))
			steps.append_array([
				{"op": "anim", "name": "sleep"},
				{"op": "wait", "t": 8.0},
				{"op": "emote", "icon": "heart", "t": 1.2},
				{"op": "wait", "t": 5.0},
				{"op": "jump", "to": 0}])
		else:
			# patrol past occupied pads; anything tagged "oddity" is
			# investigated (goto the percept's position), sniffed and
			# barked at — the alarm cue is itself a stimulus others
			# can respond to. Same pipeline, different weights.
			steps = [{"op": "respond", "tags": ["oddity"],
				"bands": [{"gte": 0.3, "goto": "investigate"}]},
				{"op": "anim", "name": "walk"}]
			var prev := _cell_pt(spots[visit[0]])
			for pid in visit:
				var pt := _cell_pt(spots[pid])
				steps.append_array(_goto_legs(layout, prev, pt,
					60.0))
				steps.append({"op": "anim", "name": "sniff"})
				steps.append({"op": "emit", "cue": "bark",
					"t": 2.0})
				steps.append({"op": "wait", "t": 1.5})
				prev = pt
		if not st.get("assignments", {}).is_empty() \
				and weather != "storm":
			# §9 greeting beat: a nearby dog_lover guest gets the
			# wiggle (respond band > sniff loop, below oddity alarm)
			steps.append({"op": "respond", "tags": ["dog_lover"],
				"bands": [{"gte": 0.45, "goto": "greet"}]})
			steps.append({"op": "jump", "to": 0})
			steps.append_array([
				{"op": "anim", "name": "play", "label": "greet"},
				{"op": "emote", "icon": "heart", "t": 1.5},
				{"op": "wait", "t": 2.0}, {"op": "jump", "to": 0}])
			steps.append_array([
				{"op": "goto", "percept": "oddity", "speed": 70.0,
					"label": "investigate"},
				{"op": "anim", "name": "sniff"},
				{"op": "emit", "cue": "bark", "t": 2.0,
					"tags": ["alarm", "noise"]},
				{"op": "wait", "t": 2.0}, {"op": "jump", "to": 0}])
		w.spawn({"pos": {"x": start_pt.x, "y": start_pt.y},
			"schedule": _jitter(w, steps),
			"anchor": {"kind": "pt", "ref": "dog"},
			"persona": _persona(w, personas, "dog", "dog", seed),
			"tags": {"tags": ["dog", "fluffy"]},
			"perceive": {"sight_r": 130.0, "hear_r": 140.0,
				"weights": {"oddity": 0.9, "dog_lover": 0.6}},
			"anim": {"name": "walk", "fps": 8.0}})
	# trailhead queue (§10): guests on the board without an
	# assignment wait by the fire — walking bodies sell the
	# "still looking for a spot" read the board sheet reports.
	var unseated: Array = st.get("board", []).filter(
		func(r): return not st.get("assignments", {}).has(r["id"]))
	if not unseated.is_empty():
		var fc := _cell_pt(layout.get("campfire", {})
			.get("cell", [6, 4]))
		var qi := 0
		for r in unseated:
			var ang := TAU * float(qi) / float(unseated.size()) \
				+ w.rng.randf() * 0.4
			var anchor_pt := fc + Vector2(cos(ang),
				sin(ang)) * 56.0
			var w1 := anchor_pt + Vector2(28, 0)
			var w2 := anchor_pt + Vector2(-28, 8)
			var qsteps := [{"op": "anim", "name": "idle"},
				{"op": "wait", "t": 3.0},
				{"op": "anim", "name": "walk"},
				{"op": "goto", "to": [w1.x, w1.y], "speed": 25.0},
				{"op": "wait", "t": 2.5},
				{"op": "emote", "icon": "?", "t": 1.2},
				{"op": "anim", "name": "walk"},
				{"op": "goto", "to": [w2.x, w2.y], "speed": 25.0},
				{"op": "wait", "t": 3.5},
				{"op": "jump", "to": 0}]
			w.spawn({"pos": {"x": anchor_pt.x, "y": anchor_pt.y},
				"schedule": _jitter(w, qsteps),
				"anchor": {"kind": "pt", "ref": "queue"},
				"persona": _persona(w, personas,
					String(r.get("archetype", "")),
					String(r["id"]), seed),
				"anim": {"name": "idle", "fps": 5.0}})
			qi += 1
	# rare-beat entities (spec 004-D): the roll happened before the
	# guest loop so programs could author around it — these spawns
	# are the stimulus each beat needs in the world.
	match beat:
		"meteor":
			# bare "sky" stimulus over the lookout (or the fire as
			# fallback): watchers' injected respond band scores it
			var es_b: Dictionary = layout.get("errand_spots", {})
			var lp: Variant = es_b.get("lookout",
				layout.get("campfire", {}).get("cell", [6, 4]))
			var sky_pt := Vector2(float(lp[0]), float(lp[1])) \
				if lp is Array else _cell_pt(lp) - Vector2(0, 96)
			w.spawn({"pos": {"x": sky_pt.x, "y": sky_pt.y},
				"tags": {"tags": ["sky"]}})
		"raccoon":
			# a critter raids the forage bush — tagged oddity so the
			# dog's investigate band finds it and barks it off
			var es_r: Dictionary = layout.get("errand_spots", {})
			var fp: Variant = es_r.get("forage",
				es_r.get("lookout", null))
			if fp is Array and fp.size() >= 2:
				var a_pt := Vector2(float(fp[0]), float(fp[1]))
				var b_pt := a_pt + Vector2(72, 16)
				w.spawn({"pos": {"x": a_pt.x, "y": a_pt.y},
					"schedule": _jitter(w, [
						{"op": "anim", "name": "walk"},
						{"op": "goto", "to": [b_pt.x, b_pt.y],
							"speed": 35.0},
						{"op": "anim", "name": "sniff"},
						{"op": "wait", "t": 3.0},
						{"op": "goto", "to": [a_pt.x, a_pt.y],
							"speed": 35.0},
						{"op": "wait", "t": 2.0},
						{"op": "jump", "to": 0}]),
					"anchor": {"kind": "pt", "ref": "beat"},
					"persona": _persona(w, personas, "raccoon",
						"raccoon", seed),
					"tags": {"tags": ["oddity", "critter",
						"fluffy"]},
					"anim": {"name": "walk", "fps": 6.0}})
		"swim":
			# the 1% night swim: a camper sneaks a dip off the bank —
			# oddity-tagged so the dog can discover and bark at them
			if not banks.is_empty():
				var b_pt: Vector2 = banks[w.rng.randi() \
					% banks.size()]
				var back_pt := b_pt + Vector2(0, 44)
				w.spawn({"pos": {"x": back_pt.x, "y": back_pt.y},
					"schedule": _jitter(w, [
						{"op": "anim", "name": "walk"}]
						+ _goto_legs(layout, back_pt, b_pt, 45.0)
						+ [{"op": "anim", "name": "play"},
							{"op": "emote", "icon": "heart",
								"t": 1.5},
							{"op": "wait", "t": 7.0}]
						+ _goto_legs(layout, b_pt, back_pt, 45.0)
						+ [{"op": "anim", "name": "idle"},
							{"op": "wait", "t": 4.0},
							{"op": "jump", "to": 0}]),
					"anchor": {"kind": "pt", "ref": "beat"},
					"persona": _persona(w, personas, "camper",
						"swimmer", seed),
					"tags": {"tags": ["oddity"]},
					"anim": {"name": "walk", "fps": 6.0}})
	return w


## §3 "alive in ten seconds": the day cast — gentle ambience while
## the player plans. Locals drift between forage/lookout/fire; the
## dog patrols a looser ring. No scenario writes needed — same
## verbs, calmer programs, no guest parties (they arrive at dusk).
static func cast_day(st: Dictionary, layout: Dictionary,
		seed: int, personas: Dictionary = {},
		prev_perfect := false) -> SimWorld:
	var w := SimWorld.new(seed)
	var spots: Dictionary = layout.get("pads", {}).get("spots", {})
	var es: Dictionary = layout.get("errand_spots", {})
	var weather := String(st.get("weather", "clear"))
	var items: Array = []
	for d in st.get("decor", []):
		items.append(d["id"])
	w.ctx = {"items": items, "weather": weather,
		"event": String(st.get("event", "")),
		"stoked": bool(st.get("fire_stoked", false))}
	# ambient locals wander the errand loop: forage -> lookout ->
	# fire, seeded pick of the loop start so casts differ by day
	var stops := []
	for k in ["forage", "lookout"]:
		var p: Variant = es.get(k)
		if p is Array and p.size() >= 2:
			stops.append(Vector2(float(p[0]), float(p[1])))
	var fire_v: Variant = layout.get("campfire", {}).get("cell")
	if fire_v != null:
		stops.append(_cell_pt(fire_v))
	var n_locals := mini(2, stops.size())
	var offset: int = w.rng.randi() % maxi(1, stops.size())
	for li in n_locals:
		if stops.is_empty():
			break
		var loop := []
		for j in stops.size():
			loop.append(stops[(offset + j) % stops.size()])
		var steps := [{"op": "anim", "name": "walk"}]
		var first_pt: Vector2 = loop[0]
		for pt in loop:
			steps.append({"op": "goto", "to": [pt.x, pt.y],
				"speed": 30.0})
			steps.append({"op": "anim", "name": "idle"})
			steps.append({"op": "wait",
				"t": 4.0 + w.rng.randf() * 4.0})
			steps.append({"op": "anim", "name": "walk"})
		steps.append({"op": "jump", "to": 0})
		steps = _storm_wrap(steps, first_pt)
		w.spawn({"pos": {"x": first_pt.x, "y": first_pt.y},
			"schedule": _jitter(w, steps),
			"anchor": {"kind": "pt", "ref": "ambient"},
			"persona": _persona(w, personas, "camper",
				"ambient_%d" % li, seed),
			"anim": {"name": "walk", "fps": 6.0}})
	# the dog sniffs the day's errands instead of the night pads
	if st.get("dog", {}).get("met", false) or items.has("dog_bed"):
		var visit := stops.duplicate()
		if visit.is_empty() and not spots.is_empty():
			var pids := spots.keys()
			pids.sort()              # pad ids, not JSON dict order
			for pid in pids.slice(0, 3):
				visit.append(_cell_pt(spots[pid]))
		if not visit.is_empty():
			var steps := []
			if prev_perfect:
				# spec 005-D wag: the morning after an all-5★ night
				# the dog bounces at the fire before its rounds
				steps = [{"op": "anim", "name": "play"},
					{"op": "emote", "icon": "heart", "t": 1.5},
					{"op": "wait", "t": 1.0}]
			steps.append({"op": "anim", "name": "walk"})
			var prev: Vector2 = visit[0]
			for pt in visit:
				steps.append_array(_goto_legs(layout, prev, pt,
					55.0))
				steps.append({"op": "anim", "name": "sniff"})
				steps.append({"op": "wait", "t": 2.0})
				prev = pt
			steps.append({"op": "jump", "to": 0})
			w.spawn({"pos": {"x": prev.x, "y": prev.y},
				"schedule": _jitter(w, steps),
				"anchor": {"kind": "pt", "ref": "dog"},
				"persona": _persona(w, personas, "dog",
					"dog", seed),
				"tags": {"tags": ["dog", "fluffy"]},
				"anim": {"name": "walk", "fps": 8.0}})
	return w
