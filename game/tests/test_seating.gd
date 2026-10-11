extends Node
## Headless hosting checks (GDD 29 §5.2–5.7 cases). Run:
##   godot --headless --path game tests/test_seating.tscn
## Exit code = number of failed checks.

var failures := 0


func check(name: String, cond: bool, detail := "") -> void:
	if not cond:
		failures += 1
		print("  XX %s %s" % [name, detail])
	else:
		print("  OK %s" % name)


func _inject(gid: String, arch: String, traits: Array,
		loud := false) -> Dictionary:
	var g := {"id": gid, "archetype": arch, "traits": traits,
		"loud": loud, "fee": 40, "pads": 1}
	Game.site_state()["guests"][gid] = g
	return g


func _put(item_id: String, effect: String, reach: int,
		cells: Array) -> void:
	Game.site_state()["decor"].append({"id": item_id,
		"effect": effect, "reach": reach, "cells": cells})


func _stars(gid: String, pads: Array, meal := 0) -> int:
	var g: Dictionary = Game.site_state()["guests"][gid]
	Game.site_state()["assignments"][gid] = pads
	return Seating.resolve_guest(g, pads, Game._world(), meal)["stars"]


func _ready() -> void:
	print("=== seating engine (§5.2–5.7) ===")

	# --- §5.2 board: day 1 scripted, then seeded ---------------------
	Game.advance_day()
	var st: Dictionary = Game.site_state()
	check("day 1 scripted board", st["board"].size() == 2
		and st["board"][0]["archetype"] == "hiker"
		and st["board"][0]["traits"] == ["chilly"],
		"got %s" % [st["board"]])

	Game.advance_day()                               # site day 2
	check("board = open pads + 1", st["board"].size() == 3,
		"got %d" % st["board"].size())

	# Determinism: re-seeded rng rebuilds the identical board (§5.2).
	var again := Seating.board(Game.site_row(),
		Catalog.data["archetypes"], Game.site_day(),
		Game._open_pads(st), Game.rating(), Game._rng_for("board"),
		Game._has_free_pair(st))
	check("board reseeds identically", again == st["board"])

	# Weekend boards carry one extra request (§5.2).
	while Game.site_day() < 7:
		Game.advance_day()
	check("weekend board +1", st["board"].size() == 4,
		"got %d" % st["board"].size())

	# From day 6 every board holds a conflicting pair (§5.2).
	var ok_conflicts := true
	while Game.site_day() < 12:
		Game.advance_day()
		if not Seating._has_conflict(st["board"]):
			ok_conflicts = false
	check("day≥6 conflict pair", ok_conflicts)

	# --- §5.4 worked examples ----------------------------------------
	# Fire sits at cell (4,2) r2; p7 = (4,3) is beside it.
	st["weather"] = "clear"
	st["decor"] = []
	st["assignments"] = {}
	st["guests"] = {}
	st["pads"]["p7"]["shelter"] = "platform"
	_put("planter", "nature", 1, [Vector2i(3, 3)])
	var hiker := _inject("g_hiker", "hiker",
		["chilly", "nature_lover"])
	var r := Seating.resolve_guest(hiker, ["p7"], Game._world(), 1)
	check("5★: platform+fire+planter+favourite", r["stars"] == 5,
		"got %d (%s)" % [r["stars"], r])

	# Loud neighbour + rain, bare pad, no tarp → 1★.
	st["weather"] = "rain"
	st["assignments"] = {}
	_inject("g_loud", "van_lifer", [], true)
	Game.site_state()["assignments"]["g_loud"] = ["p2"]
	_inject("g_couple", "couple", ["light_sleeper", "introvert"])
	var couple: Dictionary = st["guests"]["g_couple"]
	r = Seating.resolve_guest(couple, ["p1"], Game._world(), 0)
	check("1★: loud neighbour + rain + bare",
		r["stars"] == 1 and r["aversions"] == 1
		and r["weather"] == -1, "got %s" % r)

	# Same couple behind a hedge under a tarp, away from the noise.
	_put("hedge", "privacy", 1, [Vector2i(1, 3)])
	_put("tarp", "cover", 1, [Vector2i(0, 2)])
	r = Seating.resolve_guest(couple, ["p6"], Game._world(), 0)
	check("3★: hedge privacy + covered in rain",
		r["stars"] == 3 and r["needs_met"] == 1
		and r["aversions"] == 0 and r["weather"] == 0, "got %s" % r)
	r = Seating.resolve_guest(couple, ["p6"], Game._world(), 1)
	check("4★: …and the favourite meal", r["stars"] == 4,
		"got %d" % r["stars"])

	# --- trait matrix -------------------------------------------------
	st["weather"] = "clear"
	st["decor"] = []
	st["assignments"] = {}
	st["guests"] = {}
	_inject("g_a", "scout", ["social"])
	check("social unmet alone", _stars("g_a", ["p1"]) == 2)
	_inject("g_b", "hiker", ["chilly"])
	Game.site_state()["assignments"]["g_b"] = ["p4"]   # p1's neighbour
	check("social met beside guest", _stars("g_a", ["p1"]) == 3)
	_put("lantern", "light", 1, [Vector2i(0, 1)])
	_inject("g_owl", "scout", ["night_owl"])
	check("night owl by lantern", _stars("g_owl", ["p1"]) == 3)
	_inject("g_star", "scout", ["stargazer"])
	_put("telescope", "stars", 1, [Vector2i(2, 0)])
	r = Seating.resolve_guest(st["guests"]["g_star"], ["p1"],
		Game._world(), 0)
	check("stargazer: stars+light cancel",
		r["needs_met"] == 1 and r["aversions"] == 1
		and r["stars"] == 2, "got %s" % r)
	_put("dog_bed", "dog", 2, [Vector2i(3, 0)])   # r2 reaches p2 (4,0)
	_inject("g_wary", "couple", ["dog_wary"])
	r = Seating.resolve_guest(st["guests"]["g_wary"], ["p2"],
		Game._world(), 0)
	check("dog-wary within dog bed r2",
		r["aversions"] == 1 and r["stars"] == 1, "got %s" % r)

	# Families: needs met on either pad, comfort from the worse (§5.4).
	st["pads"]["p6"]["shelter"] = "platform"   # p6 good, p7 platform too
	st["pads"]["p7"]["shelter"] = "platform"
	st["assignments"] = {}
	var fam := {"id": "g_fam", "archetype": "family",
		"traits": ["kids"], "loud": true, "fee": 110, "pads": 2}
	st["guests"]["g_fam"] = fam
	st["assignments"]["g_fam"] = ["p6", "p7"]
	check("family comfort worst-pad",
		Seating.comfort_of(["p6", "p7"], Game._world()) == 1)
	st["pads"]["p6"]["shelter"] = "bare"
	check("family comfort dips to bare",
		Seating.comfort_of(["p6", "p7"], Game._world()) == 0)

	# --- goodnight: economy + reviews + walk-ins ----------------------
	Game.coins = 0
	st["seats"] = 2
	st["reviews"] = [5, 5, 5, 4, 5, 4, 5, 5, 4, 5, 5, 4, 5, 5, 4]
	st["weather"] = "clear"
	st["decor"] = []
	st["assignments"] = {}
	st["guests"] = {}
	var guest := _inject("g_solo", "hiker", ["chilly"])
	guest["favourite"] = "stew"
	guest["fee"] = 40
	st["assignments"]["g_solo"] = ["p7"]
	Game.meals = [{"id": "stew", "price": 18},
		{"id": "fish", "price": 25}]
	var rep := Game.goodnight()
	check("favourite found, term +1",
		rep["results"][0]["meal"] == 1
		and rep["results"][0]["stars"] == 5, "got %s" % rep["results"])
	# Walk-ins = min(seats 2, floor(4.73)-2 = 2); one leftover sells.
	check("walk-in buys leftover",
		rep["walk_ins"] == 1 and rep["meal_sales"] == 25,
		"got %d/%d" % [rep["walk_ins"], rep["meal_sales"]])
	check("coins = fee+tip+meal",
		Game.coins == 40 + int(40 * 0.10 * 3) + 25,
		"got %d" % Game.coins)
	check("phase went NIGHT", Game.phase == Game.Phase.NIGHT)

	# --- purchases -----------------------------------------------------
	Game.coins = 1000
	check("open pad p3", Game.open_pad("p3") and Game.coins == 880)
	check("pad not open twice", not Game.open_pad("p3"))
	check("platform upgrade", Game.upgrade_pad("p3", "platform")
		and Game.coins == 780)
	check("cabin unavailable at pinewatch",
		not Game.upgrade_pad("p3", "cabin"))
	check("buy lantern", Game.buy_decor("lantern", [Vector2i(5, 1)])
		and Game.coins == 730)
	check("fire pit r3", Game.buy_decor("stone_fire_pit", [])
		and Game.coins == 430
		and Game.site_state()["campfire"]["radius"] == 3)

	# --- save round-trip ----------------------------------------------
	var blob := Save.default_state()
	blob.merge(Game.state_dict(), true)
	Game.coins = 0
	Game.sites = {}
	Game.load_state(Save._migrate(blob))
	var back: Dictionary = Game.site_state()
	check("sites round-trip", back["pads"]["p3"]["open"]
		and back["pads"]["p3"]["shelter"] == "platform"
		and back["campfire"]["radius"] == 3
		and back["decor"].size() == 1
		and back["decor"][0]["cells"][0] == Vector2i(5, 1)
		and Game.coins == 430)

	print("=== %s ===" % ("ALL CHECKS PASS" if failures == 0
		else "%d FAILURES" % failures))
	get_tree().quit(failures)
