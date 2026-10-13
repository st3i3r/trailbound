class_name SimDirector
extends RefCounted
## Casting layer (PLAN_gameplay D4): Game state -> SimWorld entity
## programs. v1 uses a minimal in-code table (guest idle at pad,
## dog patrol, angler walks to the bank); the full
## archetype/trait/item/weather scenario matrix becomes a JSON
## data file when real scenarios land.

const CELL := 64.0


static func _cell_pt(c: Array, dy := 48.0) -> Vector2:
	return Vector2(c[0] * CELL + CELL / 2.0, c[1] * CELL + dy)


static func _bank(layout: Dictionary) -> Vector2:
	var p: Array = layout.get("errand_spots", {}) \
		.get("pond", [168, 290])
	return Vector2(p[0], p[1])


static func _schedule(steps: Array) -> Dictionary:
	return {"steps": steps, "i": 0, "wait": 0.0, "started": false}


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


## Evening cast: every seated guest performs an archetype loop from
## their pad; the dog patrols when adopted. Deterministic — same
## state + seed => same performance.
static func cast_night(st: Dictionary, layout: Dictionary,
		seed: int) -> SimWorld:
	var w := SimWorld.new(seed)
	var spots: Dictionary = layout.get("pads", {}).get("spots", {})
	var bank := _bank(layout)
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
				steps = [
					{"op": "anim", "name": "walk"},
					{"op": "goto", "to": [bank.x, bank.y],
						"speed": 40.0},
					{"op": "anim", "name": "fish"},
					{"op": "wait", "t": 8.0},
					{"op": "anim", "name": "walk"},
					{"op": "goto", "to": [home.x, home.y],
						"speed": 40.0},
					{"op": "anim", "name": "sit"},
					{"op": "wait", "t": 6.0},
					{"op": "jump", "to": 0}]
			"kids", "family":
				# the swing the player placed changes the cast
				if item_pt.has("swing"):
					var sw: Vector2 = item_pt["swing"]
					anchor = {"kind": "item", "ref": "swing"}
					steps = [
						{"op": "anim", "name": "walk"},
						{"op": "goto", "to": [sw.x, sw.y],
							"speed": 55.0},
						{"op": "anim", "name": "play"},
						{"op": "wait", "t": 5.0},
						{"op": "anim", "name": "walk"},
						{"op": "goto", "to": [home.x, home.y],
							"speed": 55.0},
						{"op": "anim", "name": "idle"},
						{"op": "wait", "t": 3.0},
						{"op": "jump", "to": 0}]
				else:
					steps = [{"op": "anim", "name": "idle"},
						{"op": "wait", "t": 4.0},
						{"op": "jump", "to": 0}]
			_:
				if traits.has("dog_wary") and dog_here:
					# scripted reaction: the dog's bark cue latches
					# into `heard` (sys_listen) -> flinch emote
					extra["listen"] = {"r": 140.0}
					steps = [
						{"op": "react", "to": "bark", "goto": 4},
						{"op": "anim", "name": "idle"},
						{"op": "wait", "t": 4.0},
						{"op": "jump", "to": 0},
						{"op": "emote", "icon": "!",
							"t": 1.0},
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
		var steps := [{"op": "anim", "name": "walk"}]
		for pid in visit:
			var pt := _cell_pt(spots[pid])
			steps.append({"op": "goto", "to": [pt.x, pt.y],
				"speed": 60.0})
			steps.append({"op": "anim", "name": "sniff"})
			steps.append({"op": "emit", "cue": "bark", "t": 2.0})
			steps.append({"op": "wait", "t": 1.5})
		steps.append({"op": "jump", "to": 0})
		var home := _cell_pt(spots[visit[0]])
		w.spawn({"pos": {"x": home.x, "y": home.y},
			"schedule": _jitter(w, steps),
			"anchor": {"kind": "pt", "ref": "dog"},
			"persona": {"sprite": "dog"},
			"anim": {"name": "walk", "fps": 8.0}})
	return w
