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


## Evening cast: every seated guest performs an archetype loop from
## their pad; the dog patrols when adopted. Deterministic — same
## state + seed => same performance.
static func cast_night(st: Dictionary, layout: Dictionary,
		seed: int) -> SimWorld:
	var w := SimWorld.new(seed)
	var spots: Dictionary = layout.get("pads", {}).get("spots", {})
	var bank := _bank(layout)
	for gid in st.get("assignments", {}):
		var pads: Array = st["assignments"][gid]
		if pads.is_empty() or not spots.has(pads[0]):
			continue
		var pid: String = pads[0]
		var home := _cell_pt(spots[pid])
		var arch := String(st.get("guests", {}).get(gid, {}) \
			.get("archetype", ""))
		var steps: Array
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
			_:
				steps = [
					{"op": "anim", "name": "idle"},
					{"op": "wait", "t": 4.0},
					{"op": "jump", "to": 0}]
		w.spawn({"pos": {"x": home.x, "y": home.y},
			"schedule": _schedule(steps),
			"anchor": {"kind": "pad", "ref": pid},
			"persona": {"sprite": "warden_south",
				"guest": gid},
			"anim": {"name": "idle", "fps": 6.0}})
	# the dog patrols pad to pad and sniffs (§9) once adopted
	if st.get("dog", {}).get("met", false) \
			or st.get("decor", []).any(
				func(d): return d["id"] == "dog_bed"):
		var keys := spots.keys()
		if not keys.is_empty():
			var steps := [{"op": "anim", "name": "walk"}]
			for i in 3:
				var pt := _cell_pt(spots[keys[i % keys.size()]])
				steps.append({"op": "goto", "to": [pt.x, pt.y],
					"speed": 60.0})
				steps.append({"op": "anim", "name": "sniff"})
				steps.append({"op": "wait", "t": 1.5})
			steps.append({"op": "jump", "to": 0})
			var home := _cell_pt(spots[keys[0]])
			w.spawn({"pos": {"x": home.x, "y": home.y},
				"schedule": _schedule(steps),
				"anchor": {"kind": "pt", "ref": "dog"},
				"persona": {"sprite": "dog"},
				"anim": {"name": "walk", "fps": 8.0}})
	return w
