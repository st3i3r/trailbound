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
		Game._has_free_pair(st), Game._favourite_pool())
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
	check("aversion writes the comment",
		r["comment_key"] == "loud"
		and r["comment"] in Catalog.data["reviews"]["loud"],
		"got %s/%s" % [r["comment_key"], r["comment"]])
	check("comments deterministic", Seating.resolve_guest(
		couple, ["p1"], Game._world(), 0)["comment"] == r["comment"])

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
	# §5.6: the strongest term writes the review line.
	check("favourite writes the comment",
		rep["results"][0]["comment_key"] == "favourite"
		and rep["results"][0]["comment"] in
			Catalog.data["reviews"]["favourite"])
	check("best review surfaced",
		rep["best"]["stars"] == rep["results"][0]["stars"]
		and rep["best"]["comment"] != "")
	# Walk-ins = min(seats 2, floor(4.73)-2 = 2); one leftover sells.
	check("walk-in buys leftover",
		rep["walk_ins"] == 1 and rep["meal_sales"] == 25,
		"got %d/%d" % [rep["walk_ins"], rep["meal_sales"]])
	# P5 (rating ≥4.0, 15 reviews) also landed tonight — gift +50.
	check("P5 page lands on rating",
		rep["pages"].has(5)
		and Game.coins == 40 + int(40 * 0.10 * 3) + 25 + 50,
		"got %s %d" % [rep["pages"], Game.coins])
	check("phase went NIGHT", Game.phase == Game.Phase.NIGHT)

	# --- journal (§8.1) -------------------------------------------------
	check("P1 auto-lit day 1", Game.page_done(1))
	check("platform still locked", not Game._is_unlocked("P2"))
	check("W gated by chapter", not Game._is_unlocked("W0")
		and not Game.site_reachable(&"whisper_river"))
	var cnt: Dictionary = Game.site_state()["counters"]
	cnt["guests_welcomed"] = 20
	Game.recipes_cooked = ["a", "b", "c", "d", "e"]
	var coins_before := Game.coins
	Game._check_pages()
	check("P2+P3 land together", Game.page_done(2) and Game.page_done(3)
		and Game.coins == coins_before + 60,
		"coins %d" % Game.coins)

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
		and back["pages_done"].has(1)
		and back["counters"]["guests_welcomed"] == 20
		and Game.coins == 430)

	# --- kitchen: forage → pantry → cook (§7) --------------------------
	Game.pantry = {}
	Game.meals = []
	var nodes: Array = Game.site_state()["forage_nodes"]
	check("6 seeded forage nodes", nodes.size() == 6
		and nodes.all(func(n): return n["items"].size() == 2))
	var first_items: Array = nodes[0]["items"].duplicate()
	var got := Game.gather("f0")
	check("gather moves items to pantry",
		got.size() == 2 and Game.pantry_count() == 2
		and got == first_items, "got %s" % [got])
	# Pantry capacity: fill to the brim, node keeps its leftovers.
	for i in 18:
		Game.pantry_add("berries", 1)
	var left := Game.gather("f1")
	check("full pantry keeps node items", left.is_empty()
		and Game.pantry_count() == 20)

	Game.pantry = {"mushroom": 2, "herb": 1, "bread": 1,
		"sweet_milk": 1, "honey": 1, "tea": 1}
	var c := Game.cook("mushroom", "herb")
	check("known pair cooks", c["result"] == "ok"
		and c["recipe"] == "trail_stew"
		and Game.meals[0]["price"] == 20
		and Game.pantry.get("mushroom", 0) == 1)
	c = Game.cook("bread", "tea")
	check("unknown pair → Camp Mash", c["result"] == "ok"
		and c["recipe"] == "camp_mash"
		and Game.meals[1]["price"] == 5)
	c = Game.cook("sweet_milk", "honey")
	check("oven pair hints, keeps ingredients",
		c["result"] == "oven_hint"
		and Game.pantry.get("sweet_milk", 0) == 1
		and Game.meals.size() == 2)
	Game.gear.append("oven")
	c = Game.cook("sweet_milk", "honey")
	check("oven unlocked cooks custard", c["recipe"] == "caramel_custard"
		and Game.meals.size() == 3)
	Game.gear.erase("oven")
	c = Game.cook("mushroom", "mushroom")
	check("same-ingredient pair needs 2",
		c["result"] == "missing" or c["recipe"] == "mushroom_skewers",
		"got %s" % c)
	Game.pantry = {"rice": 1, "herb": 1}
	c = Game.cook("rice", "herb")
	check("gỏi cuốn cooks", c["result"] == "ok"
		and c["recipe"] == "goi_cuon"
		and Game.meals.back()["price"] == 25, "got %s" % c)
	Game.pantry = {"coffee": 1, "eggs": 1}
	c = Game.cook("eggs", "coffee")
	check("cà phê trứng cooks", c["result"] == "ok"
		and c["recipe"] == "ca_phe_trung"
		and Game.meals.back()["price"] == 30, "got %s" % c)
	Game.pantry = {}
	Game.meals = []
	Game.gear = []

	# Staples + gear purchases + fishing (§7.2).
	Game.coins = 30
	check("buy tea (P1 staple)", Game.buy_staple("tea")
		and Game.coins == 25 and Game.pantry.get("tea") == 1)
	check("noodles gated at Pinewatch", not Game.buy_staple("noodles"))
	check("no rod, no fish", Game.fish_catch("pond") == "")
	Game.coins = 200
	check("buy fishing rod", Game.buy_gear("fishing_rod")
		and Game.coins == 50)
	Game.pantry = {}
	var catches := []
	for i in 5:
		catches.append(Game.fish_catch("pond"))
	check("3 catches per spot", catches.slice(0, 3).all(
			func(f): return f in ["perch", "carp"])
		and catches[3] == "" and catches[4] == "",
		"got %s" % [catches])
	Game.site_state()["weather"] = "rain"
	check("rain adds a 4th", Game.fish_catch("pond") != "")
	Game.site_state()["weather"] = "clear"
	Game.gear = []
	Game.pantry = {}

	# Every board card carries a cookable favourite (§5.2).
	var pool := Game._favourite_pool()
	check("favourite pool non-empty", pool.size() >= 7,
		"got %d" % pool.size())
	var all_named := true
	for req in Game.site_state()["board"]:
		if req.get("favourite", "") not in pool:
			all_named = false
	check("cards carry favourites", all_named)

	# --- regulars + travel (§8.2, §12.3) ---------------------------------
	# Hùng is due at Pinewatch every 3rd day from day 3.
	Game.day = 2
	Game.new_day()
	check("Hùng not early", not Game.site_state()["board"].any(
		func(b): return b.get("regular") == "hung"))
	Game.day = 3
	Game.new_day()
	check("Hùng due day 3", Game.site_state()["board"].any(
		func(b): return b.get("regular") == "hung" and b["fee"] == 35))
	# His story told (3 seated stays) retires him and frees the pennant.
	Game.site_state()["counters"]["regular_visits"]["hung"] = 3
	Game.new_day()
	check("story ends the bookings", not Game.site_state()["board"].any(
		func(b): return b.get("regular") == "hung"))
	Game.coins = 100
	check("pennant unlocks on story", Game._is_unlocked("S:hung")
		and Game.buy_decor("scout_pennant", [Vector2i(3, 1)]))

	# Travel gates on chapter completion; W/L need all 5 pages done.
	check("W locked before chapter", not Game.travel_to(&"whisper_river"))
	Game.site_state()["pages_done"] = [1, 2, 3, 4, 5]
	check("travel to W", Game.travel_to(&"whisper_river")
		and Game.site_id == &"whisper_river")
	var wtags: Dictionary = Catalog.data["layouts"]["whisper_river"] \
		["pads"]["tags"]
	check("W water bank pads", "water" in wtags["p6"]
		and "water" in wtags["p7"] and "water" in wtags["p8"])
	# Old Ba: seat him 3 nights on the river bank → W4 + the Koi Pond.
	Game.coins = 2000
	Game.open_pad("p6")
	var old_ba := {"id": "reg_old_ba", "archetype": "angler",
		"name": "Old Ba", "traits": ["angler"], "fee": 70,
		"regular": "old_ba"}
	for i in 3:
		Game.site_state()["guests"]["reg_old_ba"] = old_ba
		Game.site_state()["assignments"] = {"reg_old_ba": ["p6"]}
		Game.goodnight()
		Game.day += 1
	var wcnt: Dictionary = Game.site_state()["counters"]
	check("Old Ba x3 → W4 + pond", Game.page_done(4)
		and wcnt["anglers_water"] == 3
		and Game._is_unlocked("W4")
		and Game.buy_decor("koi_pond", [Vector2i(2, 1)]),
		"pages %s" % [Game.site_state()["pages_done"]])

	# --- letters + vignettes (§8.2, §13) ---------------------------------
	# Morning letters landed one per morning while days advanced above.
	var pdel: Array = Game.site_state(&"pinewatch")["letters_delivered"]
	check("P letters one per morning",
		"p01" in pdel and "p02" in pdel and "p03" in pdel,
		"got %s" % [pdel])
	# w01 arrived on the morning we traveled to Whisper River.
	var wdel: Array = Game.site_state()["letters_delivered"]
	check("W arrival letter", "w01" in wdel,
		"got %s" % [wdel])
	check("unread waits in journal",
		Game.unread_letters().size() == wdel.size())
	Game.read_letter("w01")
	check("read clears unread",
		Game.unread_letters().size() == wdel.size() - 1)
	# Event letters go first: the Minh family's day-6 weekend board
	# already stamped p08 that morning — ahead of the m6 letter p06 —
	# and chapter_done delivers p10 as the last event letter.
	Game.visit_site(&"pinewatch")
	Game.new_day()
	var pdel2: Array = Game.site_state(&"pinewatch")["letters_delivered"]
	check("family letter preempted mornings",
		pdel2.find("p08") < pdel2.find("p06")
		and pdel2.back() == "p10", "got %s" % [pdel2])

	# Vignettes: unseen first, guest-match wins, restoration preempts.
	Game.visit_site(&"whisper_river")
	Game.vignettes_seen = []
	Game.site_state()["weather"] = "clear"
	Game.site_state()["guests"]["reg_old_ba"] = old_ba
	Game.site_state()["assignments"] = {"reg_old_ba": ["p6"]}
	var rep3 := Game.goodnight()
	check("Old Ba's story vignette", rep3["vignette"] == "old_ba_story",
		"got %s" % rep3["vignette"])
	Game.vignettes_seen = []
	Game.site_state()["vignette_restored"] = "boathouse"
	Game.site_state()["guests"]["reg_old_ba"] = old_ba
	Game.site_state()["assignments"] = {"reg_old_ba": ["p6"]}
	var rep4 := Game.goodnight()
	check("restoration preempts",
		rep4["vignette"] == "boat_on_the_river"
		and Game.site_state()["vignette_restored"] == "",
		"got %s" % rep4["vignette"])
	check("letters+journal persist", Game.state_dict().has("letters")
		and Game.state_dict()["journal"].has("vignettes_seen"))

	# --- Trail Daily (§10) -----------------------------------------------
	check("daily unlocks with p06",
		Game.daily_unlocked())          # p06 delivered during the run
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

	# --- daily solver (§10 CI gate) --------------------------------------
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

	# --- the dog (§9) ----------------------------------------------------
	Game.dog = {"name": "Bean", "bond": 0, "met": false,
		"pet_today": false}
	# Night 1 at Pinewatch: the stray comes for the leftover stew —
	# with no seats the walk-ins can't take them, so the dog eats.
	Game.visit_site(&"pinewatch")
	Game.day = 0
	Game.sites_visited["pinewatch"] = 0          # site_day 1
	Game.new_day()
	Game.site_state()["seats"] = 0
	Game.meals = [{"id": "stew", "price": 18}, {"id": "tea", "price": 8}]
	Game.goodnight()
	check("stray meets night 1", Game.dog["met"])
	check("leftovers feed bond", Game.dog["bond"] == 2,
		"got %d" % Game.dog["bond"])
	check("pet once a day", Game.dog_pet() and Game.dog["bond"] == 4
		and not Game.dog_pet())
	Game.pantry = {}
	Game.new_day()                               # resets pet + dig
	var dug: int = Game.pantry.size() + Game.pantry.values().reduce(
		func(a, x): return a + int(x), 0)
	check("digs a bonus item", Game.dog["pet_today"] == false
		and dug >= 1 and Game.dog_pet())
	# Bond levels and the đá cầu chase.
	var lvls := []
	for b in [0, 9, 10, 24, 25, 49, 50, 79, 80]:
		Game.dog["bond"] = b
		lvls.append(Game.dog_level())
	check("bond levels 0-4", lvls == [0, 0, 1, 1, 2, 2, 3, 3, 4],
		"got %s" % [lvls])
	check("last trick is đá cầu", Game.dog_trick() == "da_cau")
	Game.name_dog("Bơ")
	check("rename keeps value", Game.dog["name"] == "Bơ")
	Game.name_dog("   ")
	check("blank name rejected", Game.dog["name"] == "Bơ")
	check("dog in save", Game.state_dict()["dog"]["met"] == true)

	print("=== %s ===" % ("ALL CHECKS PASS" if failures == 0
		else "%d FAILURES" % failures))
	get_tree().quit(failures)
