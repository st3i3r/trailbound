extends "res://tests/harness.gd"
## Scene-level input law (D-ARCH-8): taps commit on release inside
## TAP_SLOP, pan gestures eat presses, and the view pans by _cam.
## Synthetic events feed _unhandled_input directly — the headless
## viewport swallows Input.parse_input_event before unhandled.
## Run:
##   godot --headless --path game tests/test_input.tscn

var s: Node


func _press(sp: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = sp
	s._unhandled_input(e)


func _release(sp: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.position = sp
	s._unhandled_input(e)


func _drag(rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.relative = rel
	s._unhandled_input(e)


func _ready() -> void:
	print("=== input: tap/pan gesture law (D-ARCH-8) ===")
	s = load("res://scenes/pinewatch_test.tscn").instantiate()
	add_child(s)
	await get_tree().process_frame
	await get_tree().process_frame

	var cam0: Vector2 = s._cam
	var st: Dictionary = Game.site_state()
	var seats0: int = st["seats"]

	# a bare tap on a pad with nobody selected commits nothing
	var px: Vector2 = s.pad_cells["p1"].position + s.stage.position
	_press(px)
	check("press arms a candidate tap", s._tap_armed)
	_release(px)
	check("idle tap is inert", s._cam == cam0
		and st["seats"] == seats0 and not s._tap_armed)

	# press -> drag -> release: the travel eats the tap, view pans
	_press(px)
	_drag(Vector2(-60, -40))        # left/up: into the overscan
	_release(px + Vector2(-60, -40))
	check("pan moved the view", s._cam != cam0)
	check("pan ate the seat tap", st["seats"] == seats0)

	# a clean tap still commits — evening, guest selected, pad open;
	# recompute the screen point since the stage moved under the pan
	Game.set_phase(Game.Phase.EVENING)
	var gid := "probe_guest"
	st["guests"][gid] = {"id": gid, "archetype": "hiker",
		"traits": [], "loud": false, "fee": 40, "pads": 1}
	s.selected = gid
	st["pads"]["p1"]["open"] = true
	var px2: Vector2 = s.pad_cells["p1"].position + s.stage.position
	_press(px2)
	_release(px2)
	check("release commits the seat tap",
		st["assignments"].get(gid, []) == ["p1"])

	finish()
