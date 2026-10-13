class_name SimDirector
extends RefCounted
## Casting layer (PLAN_gameplay D4): Game state -> SimWorld entity
## programs. v1 uses a minimal in-code table (guest idle at pad,
## dog patrol, angler walks to the bank); the full
## archetype/trait/item/weather scenario matrix becomes a JSON
## data file when real scenarios land.

const CELL := SimGrid.CELL


static func _cell_pt(c: Array, dy := 48.0) -> Vector2:
	return SimGrid.cell_pt(Vector2i(int(c[0]), int(c[1])), dy)


static func _bank(layout: Dictionary) -> Variant:
	var p: Variant = layout.get("errand_spots", {}).get("pond")
	return null if p == null else Vector2(p[0], p[1])


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
	var cells := SimGrid.blocked(layout)
	if cells.is_empty():
		return [b]
	var blocked := {}
	for c in cells:
		blocked["%d,%d" % [c.x, c.y]] = true
	var ca := _px_cell(a)
	var cb := _px_cell(b)
	if _los(blocked, ca, cb):
		return [b]
	# A* on the cell grid (4-dir); pads are soft cost, the
	# destination cell is always allowed even if flagged
	var pads: Dictionary = layout.get("pads", {}).get("spots", {})
	var pad_cost := float(nav.get("pad_cost", 3.0))
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
			var step := 1.0
			for pid in pads:
				var pc: Array = pads[pid]
				if int(pc[0]) == n.x and int(pc[1]) == n.y:
					step = pad_cost
					break
			var nc: float = cost[ck] + step
			if not cost.has(nk) or nc < cost[nk]:
				cost[nk] = nc
				came[nk] = ck
				var h: float = absf(n.x - cb.x) + absf(
					n.y - cb.y)
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


## Evening cast: every seated guest performs an archetype loop from
## their pad; the dog patrols when adopted. Deterministic — same
## state + seed => same performance.
static func cast_night(st: Dictionary, layout: Dictionary,
		seed: int) -> SimWorld:
	var w := SimWorld.new(seed)
	var spots: Dictionary = layout.get("pads", {}).get("spots", {})
	var bank: Variant = _bank(layout)
	# cast context for select/if branches: which items exist and
	# where — placement changes the night (AC-style item binding)
	var items: Array = []
	var item_pt := {}
	for d in st.get("decor", []):
		items.append(d["id"])
		var cells: Array = d.get("cells", [])
		if not cells.is_empty():
			item_pt[d["id"]] = _cell_pt(cells[0])
	w.ctx = {"items": items,
		"weather": st.get("weather", "clear")}
	var dog_here: bool = st.get("dog", {}).get("met", false) \
		or items.has("dog_bed")
	for gid in st.get("assignments", {}):
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
		match arch:
			"angler":
				if bank != null:
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
				else:
					steps = [{"op": "anim", "name": "idle"},
						{"op": "wait", "t": 4.0},
						{"op": "jump", "to": 0}]
			"kids", "family":
				# the swing the player placed changes the cast;
				# the dog's proximity scores their reaction
				var base: Array
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
				else:
					base = [{"op": "anim", "name": "play"},
						{"op": "wait", "t": 4.0},
						{"op": "jump", "to": 0}]
				if dog_here:
					extra["tags"] = {"tags": ["kid"]}
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
				else:
					steps = [{"op": "anim", "name": "idle"},
						{"op": "wait", "t": 4.0},
						{"op": "jump", "to": 0}]
		var comps := {"pos": {"x": home.x, "y": home.y},
			"schedule": _jitter(w, steps),
			"anchor": anchor,
			"persona": {"sprite": "warden_south",
				"guest": gid},
			"anim": {"name": "idle", "fps": 6.0}}
		for k in extra:
			comps[k] = extra[k]
		w.spawn(comps)
	# the dog does its rounds past seated guests (§9): sniff, bark —
	# the bark cue is what dog_wary guests react to
	if dog_here:
		var visit := []
		for gid in st.get("assignments", {}):
			for pid in st["assignments"][gid]:
				if spots.has(pid) and not visit.has(pid):
					visit.append(pid)
		if visit.is_empty():
			visit = spots.keys().slice(0, 3)
		# patrol past occupied pads; anything tagged "oddity" is
		# investigated (goto the percept's position), sniffed and
		# barked at — the alarm cue is itself a stimulus others
		# can respond to. Same pipeline, different weights.
		var steps := [{"op": "respond", "tags": ["oddity"],
			"bands": [{"gte": 0.3, "goto": "investigate"}]},
			{"op": "anim", "name": "walk"}]
		var prev := _cell_pt(spots[visit[0]])
		for pid in visit:
			var pt := _cell_pt(spots[pid])
			steps.append_array(_goto_legs(layout, prev, pt,
				60.0))
			steps.append({"op": "anim", "name": "sniff"})
			steps.append({"op": "emit", "cue": "bark", "t": 2.0})
			steps.append({"op": "wait", "t": 1.5})
			prev = pt
		steps.append({"op": "jump", "to": 0})
		steps.append_array([
			{"op": "goto", "percept": "oddity", "speed": 70.0,
				"label": "investigate"},
			{"op": "anim", "name": "sniff"},
			{"op": "emit", "cue": "bark", "t": 2.0,
				"tags": ["alarm", "noise"]},
			{"op": "wait", "t": 2.0}, {"op": "jump", "to": 0}])
		var home := _cell_pt(spots[visit[0]])
		w.spawn({"pos": {"x": home.x, "y": home.y},
			"schedule": _jitter(w, steps),
			"anchor": {"kind": "pt", "ref": "dog"},
			"persona": {"sprite": "dog"},
			"tags": {"tags": ["dog", "fluffy"]},
			"perceive": {"sight_r": 130.0, "hear_r": 140.0,
				"weights": {"oddity": 0.9}},
			"anim": {"name": "walk", "fps": 8.0}})
	return w
