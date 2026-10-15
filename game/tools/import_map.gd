extends Node
## PixelLab export -> site layout importer (UI-034 map pipeline).
##
##   godot --headless --path game tools/import_map.tscn -- \
##     --export=../assets_src/pl_map/godot_export \
##     --site=pinewatch --crop=0,0,22,14 [--write]
##   (--crop x0,y0,x1,y1 is the map-cell window, end-exclusive:
##    0,0,22,14 = 22 wide x 14 tall)
##
## Reads the export's structured data and DERIVES the mechanical parts
## of data/layouts/<site>.json — never touches authored intent:
##   derived : mask, camp_core_max_cells, map_rev, nav.blocked,
##             fx/ground_sunlit.png (terrain-only crop)
##   authored: pads, campfire, decor_cells, errand_spots, crew_plots,
##             nav.road / road_cost / pad_cost, terrain_letters,
##             nav.overrides (add/remove cells — the explicit, diffable
##             record of where gameplay blocking departs from the art)
## Validation runs the SAME SimGrid code the runtime uses, so an import
## that breaks connectivity/pads/decor fails loudly here, not in tests.
## Without --write it is a pure dry-run report.

const TILE := 32.0     # PixelLab map tile px
const CELL := 64.0     # gameplay cell px (2x2 map tiles)

var _fails := 0


func _ready() -> void:
	var args := _args()
	var export_dir: String = args.get("export", "")
	var site: String = args.get("site", "pinewatch")
	var crop := _crop(args.get("crop", ""))
	var write: bool = args.has("write")
	if export_dir == "" or crop == Rect2i():
		_fail("need --export=<dir> and --crop=x0,y0,x1,y1 (map cells)")
		get_tree().quit(2); return
	print("import_map  site=%s  crop=%s  write=%s" % [site, crop, write])

	var lay_path := "res://data/layouts/%s.json" % site
	var layout: Dictionary = _json(lay_path)
	if layout.is_empty():
		_fail("no layout %s" % lay_path); get_tree().quit(2); return
	var src := export_dir.path_join("pixellab/source")
	var emap: Dictionary = _json(export_dir.path_join(
		"pixellab/engine-map.json"))
	var tmap: Dictionary = _json(src.path_join("terrain-map.json"))
	var smap: Dictionary = _json(src.path_join("map.json"))
	if emap.is_empty() or tmap.is_empty() or smap.is_empty():
		_fail("export missing engine-map/terrain-map/map.json")
		get_tree().quit(2); return

	# --- dense terrain grid over the export's bounding box -------------
	var bb: Dictionary = smap["mapConfig"]["boundingBox"]
	var minx := int(bb["minX"]); var miny := int(bb["minY"])
	var mw := int(bb["maxX"]) - minx + 1
	var mh := int(bb["maxY"]) - miny + 1
	var tid2letter: Dictionary = {}
	var twalk := {}                  # terrain id -> bool when the
	for t in smap.get("terrains", []):   # editor's walkable flag is set
		var tid := str(int(t["id"]))
		if t.get("walkable") != null:
			twalk[tid] = bool(t["walkable"])
		var letter := String(layout.get("terrain_letters",
			{}).get(tid, ""))
		if letter == "":
			_fail("terrain id %s (%s) has no terrain_letters entry" % [
				tid, String(t.get("name", "?")).left(40)])
			get_tree().quit(2); return
		tid2letter[tid] = letter
	var def := str(int(tmap.get("defaultTerrain", 0)))
	if not tid2letter.has(def):
		_fail("defaultTerrain id %s has no terrain_letters entry" % def)
		get_tree().quit(2); return
	var tgrid: Array = []            # [y][x] terrain id strings, bbox
	for y in mh:
		var row: Array = []
		row.resize(mw); row.fill(def)
		tgrid.append(row)
	for c in tmap.get("cells", []):
		var gx := int(c["x"]) - minx; var gy := int(c["y"]) - miny
		if gx >= 0 and gy >= 0 and gx < mw and gy < mh:
			tgrid[gy][gx] = str(int(c["terrainId"]))

	# --- mask + solidity over the crop -----------------------------------
	# mask is the letter grid; solidity is a parallel bool grid — a tile
	# is solid when the editor marked its terrain walkable=false, or the
	# letter heuristic says so (W = water).  walkable=true suppresses the
	# letter heuristic (a painted "water" ford stays passable).
	var mask: Array = []
	var solid: Array = []
	for my in range(crop.position.y, crop.end.y):
		var ry := my - miny
		if ry < 0 or ry >= mh:
			mask.append("G".repeat(crop.size.x))
			solid.append(".".repeat(crop.size.x)); continue
		var row := ""
		var srow := ""
		for mx in range(crop.position.x, crop.end.x):
			var gx := mx - minx
			var tid: String = tgrid[ry][gx] if gx >= 0 and gx < mw \
				else def
			var letter: String = tid2letter[tid]
			row += letter
			srow += "#" if (twalk.has(tid) and not twalk[tid]) \
				or (not twalk.has(tid) and letter == "W") else "."
		mask.append(row)
		solid.append(srow)
	print("mask %dx%d" % [crop.size.x, crop.size.y])
	for r in mask: print("   " + r)

	var core := [int(ceil(crop.size.x / 2.0)),
		int(ceil(crop.size.y / 2.0))]

	# --- derived nav.blocked --------------------------------------------
	var derived := {}
	for gy in core[1]:
		for gx in core[0]:
			var w := 0
			for dy in 2:
				for dx in 2:
					var mx: int = gx * 2 + dx; var my: int = gy * 2 + dy
					if mx < solid[my].length() \
							and solid[my][mx] == "#":
						w += 1
			if w >= 3:   # >=3 of 4 map tiles solid -> impassable cell
				derived[Vector2i(gx, gy)] = true
	var n_water: int = derived.size()
	# Object px are in cell-0-origin space (px/32 = map cell); the crop
	# origin shifts them into frame space.  Every planted prop carries a
	# "blocker" collider — including dressing on pads/roads — so only the
	# collider CENTER's cell is blocked, and gameplay-reserved cells
	# (pads/road/decor) never block: authored intent outranks the art.
	var reserved := {}
	for s in layout.get("pads", {}).get("spots", {}).values():
		reserved[Vector2i(s[0], s[1])] = true
	for c in layout.get("nav", {}).get("road", []):
		reserved[Vector2i(c[0], c[1])] = true
	for c in layout.get("decor_cells", []):
		reserved[Vector2i(c[0], c[1])] = true
	for o in emap.get("objects", []):
		var col: Dictionary = o.get("collider", {})
		if col.is_empty() or String(col.get("role", "blocker")) \
				!= "blocker":
			continue
		var cc := Vector2(col["x"], col["y"]) \
			+ Vector2(col["width"], col["height"]) * 0.5 \
			- Vector2(crop.position.x, crop.position.y) * TILE
		var cell := Vector2i(int(cc.x / CELL), int(cc.y / CELL))
		if cell.x >= 0 and cell.y >= 0 and cell.x < core[0] \
				and cell.y < core[1] and not reserved.has(cell):
			derived[cell] = true
	var n_col: int = derived.size() - n_water
	print("derived blocked: %d (water %d + colliders %d)" % [
		derived.size(), n_water, n_col])

	# --- merge with authored overrides -----------------------------------
	var ov: Dictionary = layout.get("nav", {}).get("overrides", {})
	var merged := derived.duplicate()
	for c in ov.get("add", []):
		merged[Vector2i(c[0], c[1])] = true
	for c in ov.get("remove", []):
		merged.erase(Vector2i(c[0], c[1]))
	var blocked := merged.keys()
	blocked.sort_custom(func(a, b):
		return a.y * 100 + a.x < b.y * 100 + b.x)
	var blocked_arr: Array = blocked.map(func(c): return [c.x, c.y])

	var old := {}
	for c in layout.get("nav", {}).get("blocked", []):
		old[Vector2i(c[0], c[1])] = true
	var added := merged.keys().filter(func(c): return not old.has(c))
	var removed := old.keys().filter(func(c): return not merged.has(c))
	print("nav.blocked drift: +%s  -%s" % [added, removed])

	# --- validate with the real SimGrid -----------------------------------
	var test_layout := layout.duplicate(true)
	test_layout["camp_core_max_cells"] = core
	test_layout["nav"] = test_layout.get("nav", {}).duplicate()
	test_layout["nav"]["blocked"] = blocked_arr
	var walk := SimGrid.walk_cells(test_layout)
	var seen := SimGrid.reachable(walk)
	_report(walk.size() == seen.size(),
		"connectivity %d/%d walkable cells reachable" % [
			seen.size(), walk.size()])
	var pads: Dictionary = layout.get("pads", {}).get("spots", {})
	for pid in pads:
		var s: Array = pads[pid]
		_report(seen.has(Vector2i(s[0], s[1])), "pad %s reachable" % pid)
	for dc in layout.get("decor_cells", []):
		var d := Vector2i(dc[0], dc[1])
		_report(walk.has(d), "decor cell %s walkable" % [dc])
		if walk.has(d):
			var w2 := walk.duplicate(); w2.erase(d)
			_report(SimGrid.reachable(w2).size() == w2.size(),
				"decor cell %s strands nothing" % [dc])

	# --- write ------------------------------------------------------------
	if write and _fails == 0:
		layout["mask"] = mask
		layout["camp_core_max_cells"] = core
		layout["map_rev"] = "%s@%s" % [
			String(emap.get("mapId", "?")).left(8),
			String(smap.get("exportDate", "local")).left(10)]
		layout["nav"]["blocked"] = blocked_arr
		var f := FileAccess.open(lay_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(_intify(layout), "  ", true))
		f.close()
		print("wrote %s" % lay_path)
		var base := Image.load_from_file(
			src.path_join("map-base.png"))
		if base:
			var px := Rect2i(
				(crop.position.x - minx) * int(TILE),
				(crop.position.y - miny) * int(TILE),
				crop.size.x * int(TILE),
				crop.size.y * int(TILE))
			var out: Image = base.get_region(px)
			var gpath := "res://assets/%s/fx/ground_sunlit.png" % site
			out.save_png(ProjectSettings.globalize_path(gpath))
			print("wrote %s (%dx%d)" % [gpath, out.get_width(),
				out.get_height()])
	elif write:
		print("NOT writing — fix the fails above first")

	print("import_map: %s" % ("OK" if _fails == 0 else "%d FAILS" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


## JSON parses every number as float — walk the tree and restore whole
## numbers to int so the written layout stays clean (ids like [5.0, 4.0]
## would diff as noise and trip strict int readers).
func _intify(v: Variant) -> Variant:
	if v is float and v == floorf(v):
		return int(v)
	if v is Array:
		return v.map(func(e): return _intify(e))
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _intify(v[k])
		return d
	return v


func _report(ok: bool, label: String) -> void:
	if ok:
		print("  OK " + label)
	else:
		print("  XX " + label); _fails += 1


func _fail(msg: String) -> void:
	print("XX " + msg); _fails += 1


func _json(path: String) -> Variant:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		ProjectSettings.globalize_path(path)
		if path.begins_with("res://") else path))
	return v if v is Dictionary else {}


func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		out[kv[0]] = kv[1] if kv.size() == 2 else true
	return out


func _crop(s: String) -> Rect2i:
	var p := s.split(",")
	if p.size() != 4:
		return Rect2i()
	return Rect2i(int(p[0]), int(p[1]),
		int(p[2]) - int(p[0]), int(p[3]) - int(p[1]))
