extends "res://tests/harness.gd"
## Headless Trail Daily checks (GDD §10 + the CI solver gate). Run:
##   godot --headless --path game tests/test_daily.tscn
## Exit code = number of failed checks.


func _ready() -> void:
	print("=== trail daily (§10) ===")

	# The unlock rides letter p06 — inject it rather than replay the
	# 10-day letter chain (that path is covered by test_seating).
	Game.site_state(&"pinewatch")["letters_delivered"] = ["p06"]
	check("daily unlocks with p06", Game.daily_unlocked())

	var pz := Game.daily("2025-03-07")
	var pz2 := Game.daily("2025-03-07")
	check("daily deterministic",
		pz["requests"].map(func(r): return r["id"]) ==
			pz2["requests"].map(func(r): return r["id"])
		and pz["kit"].map(func(k): return k["id"]) ==
			pz2["kit"].map(func(k): return k["id"])
		and pz["meals"] == pz2["meals"])
	var mk := {}
	for m in pz["meals"]:
		mk[m["id"]] = true
	check("daily shape: 5p/4kit/6req/5meals",
		pz["pads"].size() == 5 and pz["kit"].size() == 4
		and pz["requests"].size() == 6 and pz["meals"].size() == 5
		and mk.size() == 4, "kinds %d" % mk.size())
	check("no families in daily", not pz["requests"].any(
		func(r): return r.get("archetype") == "family"))
	var pz_other := Game.daily("2025-03-08")
	check("different date, different board",
		pz["requests"].map(func(r): return r["id"] + str(r["traits"])) !=
			pz_other["requests"].map(
				func(r): return r["id"] + str(r["traits"])))
	# Seat 5 of 6, place the kit — score lands and the attempt locks.
	var asg := {}
	for i in 5:
		asg[pz["requests"][i]["id"]] = ["d%d" % (i + 1)]
	var plc := {}
	var spots: Array = pz["decor_spots"]
	for i in pz["kit"].size():
		plc[pz["kit"][i]["id"]] = [Vector2i(spots[i][0], spots[i][1])]
	var sc := Game.daily_score(pz, asg, plc)
	check("daily score ≤25 w/ results", sc["score"] <= 25
		and sc["results"].size() == 5
		and sc["share"].contains("Trailbound Daily #"),
		"got %d" % sc["score"])
	# Submit only counts today's puzzle; practice never overwrites.
	var today := Time.get_date_string_from_system()
	var pzt := Game.daily(today)
	var asg2 := {}
	for i in mini(5, pzt["requests"].size()):
		asg2[pzt["requests"][i]["id"]] = ["d%d" % (i + 1)]
	var plc2 := {}
	for i in pzt["kit"].size():
		plc2[pzt["kit"][i]["id"]] = [Vector2i(spots[i][0], spots[i][1])]
	Game.daily_state = {"date": "", "score": -1}
	Game.daily_score(pzt, asg2, plc2, true)
	var scored: int = Game.daily_state["score"]
	check("one scored attempt recorded",
		Game.daily_state["date"] == today and scored >= 0)
	Game.daily_score(pzt, asg2, plc2, true)
	check("no double submission",
		Game.daily_state["score"] == scored
		and Game.daily(today)["attempted"])

	# --- solver (§10 CI gate) -----------------------------------------
	var pzs := Game.daily("2025-03-15")
	var sol: Dictionary = Seating.daily_solve(pzs, Game._trait_kinds())
	check("best within bounds", sol["best"] <= 25 and sol["best"] > 0,
		"got %d" % sol["best"])
	check("naive never beats best", sol["naive"] <= sol["best"],
		"got %d vs %d" % [sol["naive"], sol["best"]])
	check("accept implies gates", not sol["accept"] or
		(sol["best"] >= 22 and sol["gap"] >= 3))
	# The winning play must reproduce `best` through the real scoring
	# path — solver vs game parity, the whole point of the design.
	var occ_inv := {}
	for pid in sol["play"]["occupants"]:
		occ_inv[sol["play"]["occupants"][pid]] = pid
	var asg3 := {}
	for rq in pzs["requests"]:
		if occ_inv.has(rq["id"]):
			asg3[rq["id"]] = [occ_inv[rq["id"]]]
	var plc3 := {}
	for d in sol["play"]["decor"]:
		plc3[d["id"]] = d["cells"]
	check("solver best achievable", Game.daily_score(
		pzs, asg3, plc3)["score"] == sol["best"],
		"got %d vs %d" % [Game.daily_score(
			pzs, asg3, plc3)["score"], sol["best"]])
	# Reroll chain: try k>0 is a different deterministic puzzle.
	var pzr := Game._daily_gen("2025-03-15", 1)
	check("reroll differs", pzr["requests"].map(
		func(r): return r["archetype"]) != pzs["requests"].map(
			func(r): return r["archetype"])
		or pzr["kit"] != pzs["kit"] or pzr["meals"] != pzs["meals"])
	check("reroll deterministic",
		Game._daily_gen("2025-03-15", 1) == pzr)
	check("seeds table drives tries",
		Game._daily_tries("2099-01-01") == 0)

	finish()
