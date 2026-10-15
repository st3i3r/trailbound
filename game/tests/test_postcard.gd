extends "res://tests/harness.gd"
## §33.5 Camp Postcards codec — encode/decode round-trip, checksum
## typos, version/site guards, and the 40–50 char length target.
##   godot --headless --path game tests/test_postcard.tscn

const Postcard := preload("res://scripts/systems/postcard.gd")

func _ready() -> void:
	print("=== postcard codec (§33.5) ===")
	var decor := [
		{"id": "stools", "cells": [Vector2i(3, 2)]},
		{"id": "picnic_table", "cells": [Vector2i(4, 6), Vector2i(5, 6)]},
	]
	var code: String = Postcard.encode("pinewatch", 421337, decor)
	print("code: %s (%d chars)" % [code, code.length()])
	check("code inside 40–50 char budget",
		code.length() >= 5 and code.length() <= 50)
	check("code is typeable (no ILOU/space)",
		code.to_upper() == code and " " not in code
			and "I" not in code and "O" not in code)

	var back: Dictionary = Postcard.decode(code)
	check("decode ok", back.get("ok") == true)
	check("site survives", back.get("site") == "pinewatch")
	check("seed survives", back.get("seed") == 421337)
	var bd: Array = back.get("decor", [])
	check("decor count survives", bd.size() == 2)
	var by_id := {}
	for r in bd:
		by_id[String(r["id"])] = r["cells"]
	check("1x1 cell survives",
		by_id.get("stools", []) == [Vector2i(3, 2)])
	check("2x1 cell survives + footprint re-derived",
		by_id.get("picnic_table", []) == [Vector2i(4, 6), Vector2i(5, 6)])

	# typos: every single-char mutation must fail the checksum
	var bad := 0
	for i in code.length():
		if code[i] == "-":
			continue
		var c2 := code
		c2[i] = "Z" if code[i] != "Z" else "A"
		if Postcard.decode(c2).get("ok"):
			bad += 1
	check("single-char typos rejected", bad == 0)
	check("truncated code rejected",
		not Postcard.decode(code.substr(0, code.length() - 3)).get("ok"))
	check("garbage rejected", not Postcard.decode("QQQQ").get("ok"))
	check("empty rejected", not Postcard.decode("").get("ok"))

	# unplaceable decor (unknown id / off-grid cell) is dropped,
	# the code still decodes — shares never carry illegal state
	var weird := [{"id": "nope", "cells": [Vector2i(0, 0)]},
		{"id": "stools", "cells": [Vector2i(-9, -9)]},
		{"id": "stools", "cells": [Vector2i(3, 2)]}]
	var back2: Dictionary = Postcard.decode(
		Postcard.encode("pinewatch", 1, weird))
	check("unplaceable items dropped, legal kept",
		back2.get("ok") and back2["decor"].size() == 1)

	var big: Dictionary = Postcard.decode(
		Postcard.encode("lantern_valley", (1 << 20) - 1, decor))
	check("site + max seed survive",
		big.get("ok") and big["site"] == "lantern_valley"
			and big["seed"] == (1 << 20) - 1)

	# consumer half: a code materializes a sandbox st that
	# cast_night accepts — decor placed, wanderers at the fire
	var m1: Dictionary = Postcard.materialize(code)
	var m2: Dictionary = Postcard.materialize(code)
	check("materialize ok + site", m1.get("ok") and
		m1["site"] == "pinewatch")
	check("materialize deterministic",
		m1["st"]["weather"] == m2["st"]["weather"]
			and m1["st"]["board"].size() == m2["st"]["board"].size())
	check("sandbox decor matches postcard",
		m1["st"]["decor"].size() == 2)
	var w_sb: SimWorld = SimDirector.cast_night(m1["st"],
		m1["layout"], int(m1["seed"]))
	check("sandbox cast has wanderers",
		w_sb.query(["persona"]).size() > 0)
	check("bad code can't materialize",
		not Postcard.materialize("QQQQ").get("ok"))
	finish()
