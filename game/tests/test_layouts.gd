extends "res://tests/harness.gd"
## Layout law — runs the import_map validation contract on the
## COMMITTED layouts every suite run, so a stale layout or a bad
## reimport fails CI instead of silently shipping broken nav.
##
## The importer derives mask/nav.blocked/core from the export; the
## runtime trusts them blindly — this suite re-checks what the
## runtime depends on:
##
##   * required fields exist (mask, core, nav.blocked, pads, fire)
##   * walk connectivity: largest component covers the field
##   * every pad spot, decor cell and campfire is reachable
##   * no decor cell strands another cell (placement must never
##     disconnect the map — the importer enforces it, the runtime
##     assumes it)
##   * errand spots land on or beside a walkable cell
##   * painted sites: objects.json exists and every img resolves
##
## Run:  godot --headless --path game tests/test_layouts.tscn

const CELL := 64.0


func _ready() -> void:
	print("=== layouts: nav/decor/pads law ===")
	var dir := DirAccess.get_files_at("res://data/layouts")
	var sites := 0
	for f in dir:
		if not f.ends_with(".json"):
			continue
		sites += 1
		_check_layout(f.trim_suffix(".json"))
	check("layouts found", sites >= 1, "saw %d" % sites)
	finish()


func _check_layout(site: String) -> void:
	var layout: Variant = _json("res://data/layouts/%s.json" % site)
	check("%s parses" % site, layout is Dictionary)
	if not layout is Dictionary:
		return

	for key in ["mask", "camp_core_max_cells", "nav",
			"pads", "campfire", "decor_cells"]:
		check("%s has %s" % [site, key], layout.has(key))

	var core: Array = layout.get("camp_core_max_cells", [0, 0])
	var walk := SimGrid.walk_cells(layout)
	check("%s walk non-empty" % site, walk.size() > 0)
	if walk.is_empty():
		return

	var main := SimGrid.largest_component(walk)
	check("%s connectivity" % site,
		main.size() >= int(walk.size() * 0.6),
		"%d/%d in main component" % [main.size(), walk.size()])

	# pads: every spot reachable — a pad outside the main component
	# is a dead purchase
	var pads: Dictionary = layout.get("pads", {}).get("spots", {})
	for pid in pads:
		var s: Array = pads[pid]
		check("%s pad %s reachable" % [site, pid],
			main.has(Vector2i(int(s[0]), int(s[1]))))

	# campfire is the gather-around anchor — its own cell stays
	# blocked (the prop can't be walked through), but it must touch
	# the field so actors can circle it
	var fire: Array = layout.get("campfire", {}).get("cell", [])
	if fire.size() >= 2:
		check("%s campfire touches field" % site,
			_near_walk(Vector2i(int(fire[0]), int(fire[1])), main))

	# decor cells: walkable, in the main component, and removing one
	# must never disconnect the field (placement preview relies on it)
	for dc in layout.get("decor_cells", []):
		var d := Vector2i(int(dc[0]), int(dc[1]))
		check("%s decor %s walkable" % [site, dc],
			main.has(d))
		if walk.has(d):
			var w2: Dictionary = walk.duplicate()
			w2.erase(d)
			var seed := Vector2i(-999, -999)
			for c in main:
				if w2.has(c):
					seed = c; break
			var stranded := false
			if seed.x != -999:
				var m2 := SimGrid.reachable(w2, seed)
				for c in main:
					if w2.has(c) and not m2.has(c):
						stranded = true; break
			check("%s decor %s strands nothing" % [site, dc],
				not stranded)

	# errand spots are px anchors — the actor pathfinds toward them,
	# but cast/gather points can sit just past the walkable edge
	# (whisper_river's banks live below the blocked riverbank row).
	# Law: within two cells of the field — inside, adjacent, or one
	# row across the bank.
	var es: Dictionary = layout.get("errand_spots", {})
	for key in es:
		var p: Variant = es[key]
		if p is Array and p.size() >= 2:
			var c := Vector2i(int(float(p[0]) / CELL),
				int(float(p[1]) / CELL))
			check("%s errand %s reachable" % [site, key],
				_near_walk(c, main, 2),
				"cell %s >2 cells from field" % [c])
		elif p is Dictionary:
			for sub in p:
				var q: Variant = p[sub]
				if q is Array and q.size() >= 2:
					var c2 := Vector2i(int(float(q[0]) / CELL),
						int(float(q[1]) / CELL))
					check("%s errand %s.%s reachable" % [site, key, sub],
						_near_walk(c2, main, 2),
						"cell %s >2 cells from field" % [c2])

	_check_objects(site, layout)


## Painted-site law: when objects.json exists, the authored prop
## layer owns static art — every entry needs an image that resolves
## and a foot point inside the world bounds.
func _check_objects(site: String, layout: Dictionary) -> void:
	var mpath := "res://assets/%s/objects.json" % site
	if not FileAccess.file_exists(mpath):
		return                                       # unpainted site
	var manifest: Variant = _json(mpath)
	check("%s objects manifest parses" % site, manifest is Array)
	if not manifest is Array:
		return
	check("%s objects non-empty" % site, manifest.size() > 0)
	var world := Vector2(
		int(layout["camp_core_max_cells"][0]) * CELL,
		int(layout["camp_core_max_cells"][1]) * CELL)
	var bad_img := 0
	var bad_foot := 0
	for o in manifest:
		if not FileAccess.file_exists(
				"res://assets/%s/objects/%s" % [site, String(o.get("img", ""))]):
			bad_img += 1
		# edge-framing trees legitimately hang a cell past the crop —
		# law is overscan sanity, not hard containment
		var f: Array = o.get("foot", [-9999, -9999])
		if f.size() < 2 or float(f[0]) < -CELL or float(f[1]) < -CELL \
				or float(f[0]) > world.x + CELL \
				or float(f[1]) > world.y + CELL:
			bad_foot += 1
	check("%s object images resolve" % site, bad_img == 0,
		"%d missing" % bad_img)
	check("%s object feet in overscan" % site, bad_foot == 0,
		"%d beyond %s+64" % [bad_foot, world])


func _near_walk(c: Vector2i, walk: Dictionary, depth := 1) -> bool:
	if walk.has(c):
		return true
	var ring := {c: true}
	for _i in depth:
		var next := {}
		for cell in ring:
			for d in [Vector2i(1, 0), Vector2i(-1, 0),
					Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = cell + d
				if walk.has(n):
					return true
				if not ring.has(n):
					next[n] = true
		if next.is_empty():
			return false
		for n in next:
			ring[n] = true
	return false


func _json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())
