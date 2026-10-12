extends Control
## UI-018: the storybook — every chrome component in labeled sections,
## rendered headless via --shot=PATH for golden PNGs, and linted via
## --lint (touch targets, contrast, icon registry, string coverage).
##
##   godot --path game res://scenes/ui_gallery.tscn
##     --shot=D:/path/gallery.png
##     --lint
##
## Honest scope: buttons show normal + disabled (hover/pressed are
## stylebox art — shown as labelled variants since states can't be
## forced without input); aspect variants run via --resolution on the
## game scenes, not here — this page checks the components themselves.

const A := "res://assets/pinewatch/"

func _ready() -> void:
	theme = UITheme.theme()
	Transition.snap_reveal()      # lift the boot veil for --shot/--lint
	var bg := ColorRect.new()
	bg.color = Color("2a3520")          # scene-dark backdrop
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", UITokens.SP1)
	root.position = Vector2(UITokens.MARGIN, 6)
	add_child(root)

	_sec_type(root)
	_sec_panels(root)
	_sec_pills_buttons(root)
	_sec_icons(root)
	_sec_chips(root)

	for a in OS.get_cmdline_args():
		if a.begins_with("--shot"):
			# process_frame can fire before the first canvas draw on a
			# fresh window — frame_post_draw waits for real pixels
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var out := a.get_slice("=", 1) if "=" in a \
				else "D:/monet/trail-bound/assets_src/cleanup/ui_gallery.png"
			var img := get_viewport().get_texture().get_image()
			print("gallery shot ->", out, " err:", img.save_png(out))
			get_tree().quit()
	if OS.get_cmdline_args().has("--lint"):
		await get_tree().process_frame    # containers need a frame to size
		var fails := _lint_all()
		get_tree().quit(1 if fails > 0 else 0)


# ---------------------------------------------------------- sections

func _section(parent: Control, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var h := UIKit.label_for(title.to_upper(),
		UITokens.TypeRole.CAPTION, UITokens.GOLD)
	box.add_child(h)
	parent.add_child(box)
	return box


func _chip(parent: Control, w: float, h: float,
		piece := "glass_chip", mod := 1.0) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(w, h)
	p.size = p.custom_minimum_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UIKit.chrome(piece, mod))
	parent.add_child(p)
	return p


func _sec_type(root: Control) -> void:
	var box := _section(root, "Type — roles on dark / paper")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITokens.SP2)
	box.add_child(row)
	# dark surface card
	var dark := _chip(row, 196, 80)
	for i in UITokens.TypeRole.size():
		var role: UITokens.TypeRole = i
		var l := UIKit.label_for(
			"Đêm %d — Trại %s" % [i + 1, "Aa"],
			role)
		l.position = Vector2(8, 4 + i * 15)
		dark.add_child(l)
	# cream surface card — survives for spoken-word bubbles (D-UI-1)
	var paper := _chip(row, 196, 80, "bubble_speech_flat")
	for i in UITokens.TypeRole.size():
		var role: UITokens.TypeRole = i
		var l := UIKit.label_for(
			"Đêm %d — Trại %s" % [i + 1, "Aa"],
			role, UITokens.INK)
		l.position = Vector2(8, 4 + i * 15)
		paper.add_child(l)
	# accent vocabulary
	var acc := _chip(row, 196, 80)
	var cols := [UITokens.GREEN, UITokens.RED, UITokens.GOLD,
		UITokens.DIM, UITokens.PAPER]
	var words := ["+1 met", "−1 tripped", "★ = 3", "· unresolved",
		"body text"]
	for i in cols.size():
		var l := UIKit.label_for(words[i], UITokens.TypeRole.BODY,
			cols[i])
		l.position = Vector2(8, 4 + i * 11)
		acc.add_child(l)


func _sec_panels(root: Control) -> void:
	var box := _section(root, "Lacquer glass kit (UI-019)")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITokens.SP2)
	box.add_child(row)
	for piece in ["glass_panel", "glass_band", "glass_chip",
			"glass_pill", "sel_glow", "seal_lacquer",
			"bubble_speech_flat"]:
		var p := _chip(row, 84, 40, piece)
		var l := UIKit.label_for(piece, UITokens.TypeRole.CAPTION,
			UITokens.PAPER)
		l.position = Vector2(6, 4)
		p.add_child(l)


func _sec_pills_buttons(root: Control) -> void:
	var box := _section(root, "Pills · buttons (states)")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITokens.SP2)
	box.add_child(row)
	UIKit.pill(row, Vector2(64, 20), "coin", "20c")
	UIKit.pill(row, Vector2(64, 20), "clear", "DAY 1")
	UIKit.pill(row, Vector2(64, 20), "", "plain")
	for kind in ["pill", "green", "gold"]:
		UIKit.btn(row, Vector2(72, UITokens.MIN_TOUCH),
			kind.to_upper(), kind)
	var dis := UIKit.btn(row, Vector2(72, UITokens.MIN_TOUCH),
		"DISABLED", "gold")
	dis.disabled = true
	# state art variants (hover/pressed brighten/dim the fill —
	# drawn as labelled swatches since states can't be forced)
	for st in [{"n": "hover", "m": 1.15}, {"n": "press", "m": 0.82}]:
		var p := _chip(row, 56, UITokens.MIN_TOUCH, "btn_gold",
			st["m"])
		var l := UIKit.label_for(st["n"], UITokens.TypeRole.CAPTION,
			UITokens.PAPER)
		l.position = Vector2(6, 8)
		p.add_child(l)


func _sec_icons(root: Control) -> void:
	var box := _section(root, "Icon registry — glyphs tinted, objects painterly (UI-066)")
	var reg: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/icons.json"))
	for cat in ["values", "weather", "chrome", "sections", "traits",
			"objects", "inline12"]:
		var table: Dictionary = reg.get(cat, {})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UITokens.SP2)
		box.add_child(row)
		var cap := UIKit.label_for(cat, UITokens.TypeRole.CAPTION,
			UITokens.DIM)
		cap.custom_minimum_size = Vector2(52, 0)
		row.add_child(cap)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 3)
		flow.add_theme_constant_override("v_separation", 2)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(flow)
		for k in table:
			if k == "comment":
				continue
			# glyph masks get semantic tints; painterly objects render raw
			var t := UIKit.icon_rect(k) \
				if String(table[k]).begins_with("G_") \
				else UIKit.icon_rect(k, Color.WHITE)
			flow.add_child(t)


func _sec_chips(root: Control) -> void:
	var box := _section(root, "Sign vocabulary (dark / paper)")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITokens.SP2)
	box.add_child(row)
	var dark := _chip(row, 140, 40)
	var signs := [["+1", UITokens.GREEN], ["−1", UITokens.RED],
		["·", UITokens.DIM], ["★=3", UITokens.GOLD]]
	for i in signs.size():
		var l := UIKit.label_for(signs[i][0], UITokens.TypeRole.HEAD,
			signs[i][1])
		l.position = Vector2(8 + i * 32, 14)
		dark.add_child(l)
	var paper := _chip(row, 140, 40, "bubble_speech_flat")
	var psigns := [["+1", UITokens.PLUS], ["−1", UITokens.MINUS],
		["·", UITokens.MUTE], ["★=3", UITokens.GOLD_DEEP]]
	for i in psigns.size():
		var l := UIKit.label_for(psigns[i][0], UITokens.TypeRole.HEAD,
			psigns[i][1])
		l.position = Vector2(8 + i * 32, 14)
		paper.add_child(l)
	var bang := _chip(row, 24, 24)
	var bl := UIKit.label_for("!", UITokens.TypeRole.DISPLAY,
		UITokens.GOLD)
	bl.position = Vector2(8, 1)
	bang.add_child(bl)


# ------------------------------------------------------------- lints
## --lint prints LINT name:PASS/FAIL lines; returns the fail count.

func _lint_all() -> int:
	var fails := 0
	fails += _lint_touch()
	fails += _lint_icons()
	fails += _lint_strings()
	fails += _lint_contrast()
	fails += _lint_widths()
	return fails


## Interactive controls (mouse_filter STOP) must reach MIN_TOUCH on
## both axes — the spec's ≥40px hit area includes padding, so art may
## be smaller but the control rect may not.
func _lint_touch() -> int:
	var bad := []
	for c in find_children("", "Control", true, false):
		if c.mouse_filter == Control.MOUSE_FILTER_STOP \
				and not (c is Button and c.disabled):
			var sz: Vector2 = c.size
			if sz.x < UITokens.MIN_TOUCH or sz.y < UITokens.MIN_TOUCH:
				bad.append("%s %sx%s" % [c.get_path(), sz.x, sz.y])
	print("LINT touch targets:", "PASS" if bad.is_empty() else bad)
	return bad.size()


## Every registry name must resolve to a real texture.
func _lint_icons() -> int:
	var bad := []
	var reg: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/icons.json"))
	for cat in reg:
		if reg[cat] is Dictionary:
			for k in reg[cat]:
				if k != "comment" and UIKit.icon(k) == null:
					bad.append(k)
	print("LINT icon registry:", "PASS" if bad.is_empty() else bad)
	return bad.size()


## Every CSV row needs EN + VI; every literal tr-key in the scripts
## must exist in the CSV.  The pattern needs ") right after the key
## so prefix-concat lookups ("weather_" + w) don't false-positive.
func _lint_strings() -> int:
	var bad := []
	var keys := {}
	for ln in FileAccess.get_file_as_string(
			"res://data/strings/strings.csv").split("\n"):
		ln = ln.strip_edges()
		if ln == "" or ln.begins_with("key"):
			continue
		var p := ln.split(",", false)
		if p.size() < 3 or p[1] == "" or p[2] == "":
			bad.append("row: " + ln)
		else:
			keys[p[0]] = true
	var re := RegEx.create_from_string(
		"tr\\(\"([a-z_0-9]+)\"\\)")
	var re_pre := RegEx.create_from_string(
		"tr\\(\"([a-z_0-9]+)\"\\s*\\+")
	for path in _gd_files("res://scripts") \
			+ _gd_files("res://scripts/autoload") \
			+ _gd_files("res://ui"):
		var src := FileAccess.get_file_as_string(path)
		for m in re.search_all(src):
			if not keys.has(m.get_string(1)):
				bad.append("missing key " + m.get_string(1) +
					" in " + path)
		for m in re_pre.search_all(src):
			var hit := false
			for k in keys:
				if k.begins_with(m.get_string(1)):
					hit = true
					break
			if not hit:
				bad.append("prefix " + m.get_string(1) +
					" matches no keys in " + path)
	print("LINT strings:", "PASS" if bad.is_empty() else bad)
	return bad.size()


func _gd_files(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	return out


## WCAG contrast — each text token on its *declared* surface: the
## dark-chrome set on the tray/panel dark, the paper set on parchment.
## Body text needs 4.5; the ratio prints so borderline pairs show.
## (A token used off-surface — DIM on paper — is the bug class this
## exists to catch; declaring surfaces keeps that flag meaningful.)
func _lint_contrast() -> int:
	var bad := []
	# measured surfaces: glass_panel fill, bubble_speech cream —
	# the lint checks the real art, not approximations
	var L_GLASS := _lum(Color("141d1a"))
	var L_CREAM := _lum(Color("eed6ac"))
	var usage := {   # token -> the measured surface it is allowed on
		"PAPER": L_GLASS, "GOLD": L_GLASS, "GREEN": L_GLASS,
		"RED": L_GLASS, "DIM": L_GLASS, "BLUE": L_GLASS,
		"GLOW": L_GLASS,
		"INK": L_CREAM, "MUTE": L_CREAM, "PLUS": L_CREAM,
		"MINUS": L_CREAM, "GOLD_DEEP": L_CREAM}
	var cols := {"PAPER": UITokens.PAPER, "INK": UITokens.INK,
		"GOLD": UITokens.GOLD, "GREEN": UITokens.GREEN,
		"RED": UITokens.RED, "DIM": UITokens.DIM, "BLUE": UITokens.BLUE,
		"GLOW": UITokens.GLOW,
		"MUTE": UITokens.MUTE, "PLUS": UITokens.PLUS,
		"MINUS": UITokens.MINUS, "GOLD_DEEP": UITokens.GOLD_DEEP}
	for n in usage:
		var L := _lum(cols[n])
		var s: float = usage[n]
		var r := (maxf(L, s) + 0.05) / (minf(L, s) + 0.05)
		if r < 4.5:
			bad.append("%s = %.1f" % [n, r])
	print("LINT contrast (4.5):", "PASS" if bad.is_empty() else bad)
	return bad.size()


func _lum(c: Color) -> float:
	var f := func(v: float) -> float:
		return v / 12.92 if v <= 0.04045 \
			else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) \
		+ 0.0722 * f.call(c.b)


## Width drift (advisory — not counted): VI strings longer than ~1.7×
## their EN twin flag the containers to verify.  Auto-growing parents
## (pills, the full-width strip) handle these today, so the list is a
## review cue rather than a failure — a clipped one shows in a shot.
func _lint_widths() -> int:
	var bad := []
	var f := UIKit.font_for(UITokens.TypeRole.BODY)
	for ln in FileAccess.get_file_as_string(
			"res://data/strings/strings.csv").split("\n"):
		ln = ln.strip_edges()
		if ln == "" or ln.begins_with("key"):
			continue
		var p := ln.split(",", false)
		if p.size() >= 3 and p[0] != "" and p[1] != "" and p[2] != "":
			var sz := UITokens.TYPE[UITokens.TypeRole.BODY]["size"]
			var we := f.get_string_size(p[1],
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz).x
			var wv := f.get_string_size(p[2],
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz).x
			if we > 20.0 and wv > we * 1.7:
				bad.append("%s VI %.0f vs EN %.0f" % [p[0], wv, we])
	print("LINT VI width (review):", "none" if bad.is_empty() else bad)
	return 0
