extends "res://tests/harness.gd"
## Headless hosting checks — the integrated playthrough: board,
## seating, economy, journal, kitchen, regulars, travel, letters,
## vignettes (GDD 29 §5.2–5.7 + §7–§8 + §13). Domain suites split
## out: test_daily / test_dog / test_spotting. Run:
##   godot --headless --path game tests/test_seating.tscn
## Exit code = number of failed checks.


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
	# `returning`/`wish_label` are Game-side annotations stamped after
	# the deal — compare against the raw dealt rows.
	var again := Seating.board(Game.site_row(),
		Catalog.data["archetypes"], Game.site_day(),
		Game._open_pads(st), Game.rating(), Game._rng_for("board"),
		Game._has_free_pair(st), Game._favourite_pool(),
		Game._wish_kinds(st))
	var dealt: Array = st["board"].map(func(r):
		var c: Dictionary = r.duplicate()
		c.erase("wish_label")
		c.erase("returning")
		return c)
	check("board reseeds identically", again == dealt)

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

	# spec 004 C — decor→demand: placed `attract` tags fold into the
	# board tables; trait tags can introduce absent traits, archetype
	# tags weight the mix, and the bonus caps at half the base table.
	st["decor"] = [{"id": "telescope", "effect": "stars",
		"reach": 1, "cells": [Vector2i(0, 0)]}]
	var arow := Game._attract_row(Game.site_row(), st)
	check("attract introduces absent trait",
		int(arow["trait_pool"].get("stargazer", 0)) > 0,
		"pool: %s" % [arow["trait_pool"]])
	check("attract doesn't touch base row",
		int(Game.site_row()["trait_pool"].get("stargazer", -1)) == -1)
	st["decor"] = [{"id": "scout_pennant", "effect": "",
		"reach": 1, "cells": [Vector2i(0, 0)]}]
	arow = Game._attract_row(Game.site_row(), st)
	check("attract archetype +10",
		int(arow["archetype_mix"].get("scout", 0))
			== int(Game.site_row()["archetype_mix"]["scout"]) + 10,
		"mix: %s" % [arow["archetype_mix"]])
	st["decor"] = []
	for i in 30:
		st["decor"].append({"id": "lantern", "effect": "light",
			"reach": 1, "cells": [Vector2i(0, 0)]})
	arow = Game._attract_row(Game.site_row(), st)
	var pbase := 0
	for v in Game.site_row()["trait_pool"].values():
		pbase += int(v)
	var pb := int(arow["trait_pool"].get("night_owl", 0)) \
		- int(Game.site_row()["trait_pool"].get("night_owl", 0))
	check("attract bonus capped at half base",
		pb <= int(pbase * Game.ATTRACT_CAP) + 1,
		"bonus %d cap %d" % [pb, int(pbase * Game.ATTRACT_CAP)])
	st["decor"] = []
	st["campfire"]["radius"] = 3
	arow = Game._attract_row(Game.site_row(), st)
	check("stone fire pit draws chilly",
		int(arow["trait_pool"].get("chilly", 0))
			> int(Game.site_row()["trait_pool"]["chilly"]))
	st["campfire"]["radius"] = 2

	# --- §5.4 worked examples ----------------------------------------
	# Fire sits at cell (4,4) r2; p4 = (3,5) is inside its reach.
	st["weather"] = "clear"
	st["decor"] = []
	st["assignments"] = {}
	st["guests"] = {}
	st["pads"]["p4"]["shelter"] = "platform"
	_put("planter", "nature", 1, [Vector2i(4, 6)])
	var hiker := _inject("g_hiker", "hiker",
		["chilly", "nature_lover"])
	var r := Seating.resolve_guest(hiker, ["p4"], Game._world(), 1)
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
	_put("hedge", "privacy", 1, [Vector2i(7, 6)])
	_put("tarp", "cover", 1, [Vector2i(5, 6)])
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
	Game.site_state()["assignments"]["g_b"] = ["p2"]   # p1's neighbour
	check("social met beside guest", _stars("g_a", ["p1"]) == 3)
	_put("lantern", "light", 1, [Vector2i(6, 4)])
	_inject("g_owl", "scout", ["night_owl"])
	check("night owl by lantern", _stars("g_owl", ["p5"]) == 3)
	_inject("g_star", "scout", ["stargazer"])
	_put("telescope", "stars", 1, [Vector2i(5, 6)])
	r = Seating.resolve_guest(st["guests"]["g_star"], ["p5"],
		Game._world(), 0)
	check("stargazer: stars+light cancel",
		r["needs_met"] == 1 and r["aversions"] == 1
		and r["stars"] == 2, "got %s" % r)
	_put("dog_bed", "dog", 2, [Vector2i(7, 2)])   # r2 reaches p2 (5,3)
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
	st["pads"]["p5"]["shelter"] = "platform"
	st["assignments"]["g_solo"] = ["p5"]
	Game.meals = [{"id": "stew", "price": 18},
		{"id": "fish", "price": 25}]
	# Verb guards: unsettled evening work blocks the day rollover;
	# settling is an evening act.
	var day0 := Game.day
	Game.advance_day()
	check("advance_day blocked while seated", Game.day == day0)
	Game.set_phase(Game.Phase.EVENING)
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
	check("buy lantern", Game.buy_decor("lantern", [Vector2i(6, 4)])
		and Game.coins == 730)
	check("decor cell legality",
		not Game.buy_decor("lantern", [Vector2i(5, 1)])
		and not Game.buy_decor("lantern", [Vector2i(8, 3)])
		and not Game.buy_decor("lantern", [Vector2i(4, 4)])
		and Game.coins == 730)
	check("2x1 needs a pair", not Game.buy_decor("picnic_table",
		[Vector2i(6, 2)]))
	# --- build verbs: move / store / return (§6.1, §5.8) ------------
	check("move to legal cell", Game.move_decor(0, [Vector2i(7, 2)])
		and Game.site_state()["decor"][0]["cells"][0] == Vector2i(7, 2))
	# (2,2) is blocked pond — sealing a walkable cell on the open
	# court can't strand, so the rejection rides on the blocked cell.
	check("stranding move rejected",
		not Game.move_decor(0, [Vector2i(2, 2)])
		and Game.site_state()["decor"][0]["cells"][0] == Vector2i(7, 2))
	check("move to blocked cell fails",
		not Game.move_decor(0, [Vector2i(3, 1)]))
	check("buy stools", Game.buy_decor("stools", [Vector2i(5, 6)])
		and Game.coins == 705)
	check("store frees the cell", Game.store_decor(1)
		and Game.site_state()["decor"].size() == 1
		and Game.site_state()["stored"].size() == 1)
	check("re-place stored", Game.place_stored("stools",
		[Vector2i(5, 6)]) and Game.site_state()["decor"].size() == 2)
	check("today's buy returns", Game.return_decor(1)
		and Game.coins == 730
		and Game.site_state()["decor"].size() == 1)
	check("gone from today list",
		not "stools" in Game.bought_today)
	# --- placement deadlock guard: a drop must not strand cells ------
	# corridor (0,0)-(2,0) with a pocket hanging off (1,0): sealing the
	# corridor strands the pocket + far end; capping an end is fine.
	var corridor := {Vector2i(0, 0): true, Vector2i(1, 0): true,
		Vector2i(2, 0): true, Vector2i(1, 1): true,
		Vector2i(1, 2): true}
	check("sealing corridor rejected",
		Game._strands_any(corridor, [Vector2i(1, 0)]))
	check("capping corridor end ok",
		not Game._strands_any(corridor, [Vector2i(0, 0)]))
	# --- layout integrity lint: terrain truth stays single-source ----
	# decor_cells ⊆ walkable (caught (1,3) water), no decor_cell always
	# strands (caught (2,2) sealing the p1/p8 pocket), pads all walkable
	# + mutually reachable, fire solid, errands on/near ground.
	var lay: Dictionary = Game._layout()
	var walk: Dictionary = Game._walk_cells(lay)
	var navb := {}
	for c in lay.get("nav", {}).get("blocked", []):
		navb[Vector2i(int(c[0]), int(c[1]))] = true
	var bad_cell: Variant = null
	for c in lay.get("decor_cells", []):
		var v := Vector2i(int(c[0]), int(c[1]))
		if not walk.has(v):
			bad_cell = v
	check("decor cells walkable", bad_cell == null, str(bad_cell))
	var dead_cell: Variant = null
	for c in lay.get("decor_cells", []):
		var v := Vector2i(int(c[0]), int(c[1]))
		if Game._strands_any(walk, [v]):
			dead_cell = v
	check("no dead decor cell", dead_cell == null, str(dead_cell))
	var spots: Dictionary = lay["pads"]["spots"]
	var bad_pad: Variant = null
	for pid in spots:
		var v := Vector2i(int(spots[pid][0]), int(spots[pid][1]))
		if not walk.has(v):
			bad_pad = pid
	check("pads all walkable", bad_pad == null, str(bad_pad))
	var reach := Game._reachable_set(walk)
	var lost_pad: Variant = null
	for pid in spots:
		var v := Vector2i(int(spots[pid][0]), int(spots[pid][1]))
		if not reach.has(v):
			lost_pad = pid
	check("pads mutually reachable", lost_pad == null, str(lost_pad))
	var fire: Array = lay["campfire"]["cell"]
	check("fire is solid", navb.has(Vector2i(int(fire[0]),
		int(fire[1]))))
	var bad_errand: Variant = null
	for key in lay.get("errand_spots", {}):
		var p: Array = lay["errand_spots"][key]
		var v := Vector2i(int(p[0] / SimGrid.CELL),
			int(p[1] / SimGrid.CELL))
		if walk.has(v):
			continue
		var ok := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(0, 1), Vector2i(0, -1)]:
			if walk.has(v + d):
				ok = true
		if not ok:
			bad_errand = key
	check("errands on/near ground", bad_errand == null, str(bad_errand))
	check("fire pit r3", Game.buy_decor("stone_fire_pit", [])
		and Game.coins == 430
		and Game.site_state()["campfire"]["radius"] == 3)
	# §6.1: today's buys refund by id — the pit never enters decor[],
	# so the indexed return can't reach it; return_bought does.
	check("fire pit refunds by id", Game.return_bought("stone_fire_pit")
		and Game.coins == 730
		and Game.site_state()["campfire"]["radius"] == 2)
	check("fire pit re-buys clean", Game.buy_decor("stone_fire_pit", [])
		and Game.coins == 430
		and Game.site_state()["campfire"]["radius"] == 3)
	# two-step pad opening (§5.1): unlock pays but stays overgrown —
	# it still blocks bookings; the Clear step is free.
	check("unlock p4 pays only", Game.unlock_pad("p4")
		and Game.coins == 230
		and not Game.site_state()["pads"]["p4"]["open"])
	check("unpaid pad can't clear", not Game.clear_pad("p5"))
	check("clear is free", Game.clear_pad("p4")
		and Game.coins == 230
		and Game.site_state()["pads"]["p4"]["open"])

	# --- save round-trip ----------------------------------------------
	var blob := Save.default_state()
	blob.merge(Game.state_dict(), true)
	Game.coins = 0
	Game.sites = {}
	Game.load_state(Save._migrate(blob))
	var back: Dictionary = Game.site_state()
	check("sites round-trip", back["pads"]["p3"]["open"]
		and back["pads"]["p3"]["shelter"] == "platform"
		and back["pads"]["p4"]["open"]
		and back["campfire"]["radius"] == 3
		and back["decor"].size() == 1
		and back["decor"][0]["cells"][0] == Vector2i(7, 2)
		and back["pages_done"].has(1)
		and back["counters"]["guests_welcomed"] == 20
		and Game.coins == 230)

	# --- kitchen: forage → pantry → cook (§7) --------------------------
	Game.pantry = {}
	Game.meals = []
	var nodes: Array = Game.site_state()["forage_nodes"]
	check("6+ seeded forage nodes", nodes.size() >= 6
		and nodes.all(func(n): return n["items"].size() == 2))
	var first_items: Array = nodes[0]["items"].duplicate()
	var nid: String = nodes[0]["id"]
	var got := Game.gather(nid)
	check("gather moves items to pantry",
		got.size() == 2 and Game.pantry_count() == 2
		and got == first_items, "got %s" % [got])
	check("cleaned node fades",
		not Game.site_state()["forage_nodes"].any(
			func(n): return n["id"] == nid))
	# Pantry capacity: fill to the brim, node keeps its leftovers.
	for i in 18:
		Game.pantry_add("berries", 1)
	var left := Game.gather(nodes[1]["id"])
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
		and Game.buy_decor("scout_pennant", [Vector2i(8, 2)]))

	# The D-UI-8 engagement gate held morning mail until a guest
	# stayed (welcomed ≥ 1 since §5.4). Flush the pending queue now —
	# p04–p06 must land before p10's chapter_done event exists. Day
	# advances too: site_day = day − visited, so p06 needs day ≥ 6.
	for i in 3:
		Game.day += 1
		Game._deliver_letter(Game.site_state(&"pinewatch"))

	# Travel gates on chapter completion; W/L need all 5 pages done.
	Game.set_phase(Game.Phase.MORNING)
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
		Game.set_phase(Game.Phase.EVENING)
		Game.goodnight()
		Game.day += 1
	var wcnt: Dictionary = Game.site_state()["counters"]
	check("Old Ba x3 → W4 + pond", Game.page_done(4)
		and wcnt["anglers_water"] == 3
		and Game._is_unlocked("W4")
		and Game.buy_decor("koi_pond",
			[Vector2i(6, 2), Vector2i(7, 2)]),
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
	Game.set_phase(Game.Phase.EVENING)
	var rep3 := Game.goodnight()
	check("Old Ba's story vignette", rep3["vignette"] == "old_ba_story",
		"got %s" % rep3["vignette"])
	Game.vignettes_seen = []
	Game.site_state()["vignette_restored"] = "boathouse"
	Game.site_state()["guests"]["reg_old_ba"] = old_ba
	Game.site_state()["assignments"] = {"reg_old_ba": ["p6"]}
	Game.set_phase(Game.Phase.EVENING)
	var rep4 := Game.goodnight()
	check("restoration preempts",
		rep4["vignette"] == "boat_on_the_river"
		and Game.site_state()["vignette_restored"] == "",
		"got %s" % rep4["vignette"])
	check("letters+journal persist", Game.state_dict().has("letters")
		and Game.state_dict()["journal"].has("vignettes_seen"))
	# p06 delivered during the run → the Daily unlocks here too.
	check("daily unlocks with p06", Game.daily_unlocked())

	# Morning-after color (spec-005 B): dialogue_when_ok reads
	# days_log.back() — whisper_river's night just logged above.
	var dlg: Dictionary = Game.days_log.back()
	check("days_log carries fav+regulars",
		dlg.has("fav_served") and dlg.has("regulars"),
		"keys: %s" % [dlg.keys()])
	check("regulars logged honestly",
		"old_ba" in dlg["regulars"], "got %s" % [dlg["regulars"]])
	Game.days_log.back()["best"] = 5
	check("when: stars_min matches",
		Game.dialogue_when_ok({"last_stars_min": 5}))
	check("when: stars_min misses",
		not Game.dialogue_when_ok({"last_stars_min": 6}))
	check("when: weather matches",
		Game.dialogue_when_ok({"last_weather": "clear"}))
	check("when: weather misses",
		not Game.dialogue_when_ok({"last_weather": "rain"}))
	check("when: first_night false (2nd WR night)",
		not Game.dialogue_when_ok({"first_night": true}))
	Game.days_log.back()["fav_served"] = true
	check("when: favourite served",
		Game.dialogue_when_ok({"served_favourite": true}))
	check("when: regular visit",
		Game.dialogue_when_ok({"regular_visit": "old_ba"}))
	check("when: unknown key fails closed",
		not Game.dialogue_when_ok({"nonsense": true}))
	check("when: empty passes",
		Game.dialogue_when_ok({}))

	finish()
