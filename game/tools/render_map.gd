extends Node
## Painted-site composite renderer — what the engine draws minus
## actors/UI/grade, at full native res (not the camera crop).
##
##   godot --headless --path game tools/render_map.tscn -- \
##     --site=pinewatch --out=../assets_src/_scratch/map_render.png \
##     [--overlay] [--crop=0,0,30,20] \
##     [--diff=<source_composite.png>]
##
## Composites assets/<site>/fx/ground_sunlit.png + every entry in
## assets/<site>/objects.json (blit at x,y in emitted draw order —
## the same order _build_objects spawns them).  --overlay shades
## nav.blocked cells / pads / road / decor on top for layout review.
## --diff pixel-compares against an export's map-composite.png and
## reports the differing-pixel count (clip-boundary slivers expected).

const CELL := 64.0

var _fails := 0


func _ready() -> void:
	var args := _args()
	var site: String = args.get("site", "pinewatch")
	var out: String = args.get("out", "")
	if out == "":
		_fail("need --out=<png path>"); get_tree().quit(2); return

	var gpath := "res://assets/%s/fx/ground_sunlit.png" % site
	var ground := Image.load_from_file(
		ProjectSettings.globalize_path(gpath))
	if ground == null:
		_fail("no ground %s" % gpath); get_tree().quit(2); return
	ground.convert(Image.FORMAT_RGBA8)
	print("ground %dx%d <- %s" % [
		ground.get_width(), ground.get_height(), gpath])

	var dir := "res://assets/%s" % site
	var objs: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		ProjectSettings.globalize_path(dir + "/objects.json")))
	if objs is Array:
		var n := 0
		for o in objs:
			var img := Image.load_from_file(
				ProjectSettings.globalize_path(
					"%s/objects/%s" % [dir, String(o["img"])]))
			if img == null:
				_fail("missing object img %s" % o["img"]); continue
			img.convert(Image.FORMAT_RGBA8)
			ground.blend_rect(img, Rect2i(0, 0,
				img.get_width(), img.get_height()),
				Vector2i(int(o["x"]), int(o["y"])))
			n += 1
		print("objects blitted: %d" % n)
	else:
		print("no objects.json — ground only")

	if args.has("overlay"):
		_overlay(ground, site)

	if args.has("diff"):
		# --diff ref is in the export's bbox space; the runtime crop
		# starts at crop.position tiles -> ref offset (crop - bbox min)
		var ref_off := Vector2i.ZERO
		if args.has("crop") and args.has("export"):
			var crop := _crop(String(args["crop"]))
			var smap: Dictionary = _json(
				String(args["export"]).path_join(
					"pixellab/source/map.json"))
			var bb: Dictionary = smap.get("mapConfig", {}) \
				.get("boundingBox", {})
			ref_off = Vector2i(
				crop.position.x - int(bb.get("minX", 0)),
				crop.position.y - int(bb.get("minY", 0))) * 32
		_diff(ground, String(args["diff"]), ref_off)

	var err := ground.save_png(
		ProjectSettings.globalize_path(out)
		if out.begins_with("res://") else out)
	print("render -> %s  err:%d" % [out, err])
	get_tree().quit(0 if _fails == 0 and err == OK else 1)


func _overlay(img: Image, site: String) -> void:
	var layout: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		ProjectSettings.globalize_path(
			"res://data/layouts/%s.json" % site)))
	if not layout is Dictionary:
		return
	var t := int(CELL)
	for c in layout.get("nav", {}).get("blocked", []):
		_shade(img, c, Color(1, 0.2, 0.2, 0.35), t)
	for c in layout.get("pads", {}).get("spots", {}).values():
		_shade(img, c, Color(0.3, 0.6, 1, 0.4), t)
	for c in layout.get("nav", {}).get("road", []):
		_shade(img, c, Color(1, 0.8, 0.1, 0.3), t)
	for c in layout.get("decor_cells", []):
		_shade(img, c, Color(0.2, 1, 0.5, 0.3), t)
	print("overlay: blocked/pads/road/decor shaded")


func _shade(img: Image, c: Variant, col: Color, t: int) -> void:
	for y in t:
		for x in t:
			var px := int(c[0]) * t + x
			var py := int(c[1]) * t + y
			if px >= 0 and py >= 0 and px < img.get_width() \
					and py < img.get_height():
				img.set_pixel(px, py, img.get_pixel(px, py).blend(col))


func _diff(img: Image, ref_path: String, off: Vector2i) -> void:
	var ref := Image.load_from_file(
		ProjectSettings.globalize_path(ref_path)
		if ref_path.begins_with("res://") else ref_path)
	if ref == null:
		_fail("diff source missing: %s" % ref_path); return
	ref.convert(Image.FORMAT_RGBA8)
	var n := 0; var checked := 0
	for y in img.get_height():
		for x in img.get_width():
			var rx := x + off.x; var ry := y + off.y
			if rx < 0 or ry < 0 or rx >= ref.get_width() \
					or ry >= ref.get_height():
				continue
			checked += 1
			if img.get_pixel(x, y) != ref.get_pixel(rx, ry):
				n += 1
	print("diff vs %s (off %s): %d/%d px differ (%.2f%%)" % [
		ref_path, off, n, checked,
		100.0 * n / float(maxi(1, checked))])


func _json(path: String) -> Variant:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		ProjectSettings.globalize_path(path)
		if path.begins_with("res://") else path))
	return v if v is Dictionary else {}


func _crop(s: String) -> Rect2i:
	var p := s.split(",")
	if p.size() != 4:
		return Rect2i()
	return Rect2i(int(p[0]), int(p[1]),
		int(p[2]) - int(p[0]), int(p[3]) - int(p[1]))


func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		out[kv[0]] = kv[1] if kv.size() == 2 else true
	return out


func _fail(msg: String) -> void:
	print("XX " + msg); _fails += 1
