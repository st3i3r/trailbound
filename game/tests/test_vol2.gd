extends "res://tests/harness.gd"
## Headless Volume II checks (GDD §33.3/§6.11/§33.5). Run:
##   godot --headless --path game tests/test_vol2.tscn
## Exit code = number of failed checks.


func _fresh_team(site: StringName) -> Dictionary:
	return Game.restore_status(site)["team"]


func _ready() -> void:
	print("=== volume II (§33.3/§6.11) ===")

	# --- gate: everything stays shut until the finale ---------------
	check("vol2 shut pre-finale", not Game.vol2_open())
	Game.coins = 5000
	check("no restore pre-finale", not Game.restore_can_start(
		&"fire_tower"))
	# Vol II pages can't stamp early even with the metric met.
	Game.visit_site(&"pinewatch")
	Game.site_state()["counters"]["gatherings_met"] = 3
	Game._check_pages()
	check("page 8 gated", not Game.page_done(8))

	# Stamp the fifteen v1 pages → the finale → Volume II opens.
	for site in [&"pinewatch", &"whisper_river", &"lantern_valley"]:
		Game.site_state(site)["pages_done"] = [1, 2, 3, 4, 5]
	check("vol2 opens after finale", Game.vol2_open())
	check("vol2 not done", not Game.vol2_done())
	Game._check_pages()
	check("page 8 lands post-finale", Game.page_done(8))

	# --- restorations (§6.11) ----------------------------------------
	check("fire tower startable", Game.restore_can_start(&"fire_tower"))
	var coins_before := Game.coins
	check("stage 1 pays 300", Game.restore_start(&"fire_tower")
		and Game.coins == coins_before - 300)
	check("one stage per site team",
		not Game.restore_can_start(&"pond_dock"))
	check("other site's team is free",
		Game.restore_can_start(&"bamboo_treehouse"))

	# Burn through Fire Tower's three stages on Pinewatch's team.
	Game.coins = 5000
	for i in 3:
		var team := _fresh_team(&"pinewatch")
		if team["structure"] == "":
			Game.restore_start(&"fire_tower")
		team["seconds_left"] = 0.0
		Game.restore_collect(&"pinewatch")
	check("fire tower restored", Game.restored(&"fire_tower")
		and "fire_tower" in Game.site_state()["restored"])
	check("view tags on 3 pads",
		Game.site_state()["pad_tags"].size() == 3)
	check("photographers join P mix", restore_mix() == 10)
	check("P6 stamped", Game.page_done(6))

	# Treehouse adds the W 9th pad — cabin, covered, no neighbours.
	Game.coins = 10000
	Game.visit_site(&"whisper_river")
	for i in 3:
		var team := _fresh_team(&"whisper_river")
		if team["structure"] == "":
			Game.restore_start(&"bamboo_treehouse")
		team["seconds_left"] = 0.0
		Game.restore_collect(&"whisper_river")
	var pads9: Dictionary = Game.site_state(
		&"whisper_river")["pads"].get("p9", {})
	check("treehouse adds p9", pads9.get("open", false)
		and pads9.get("shelter") == "cabin")

	# Bathhouse aura rides the decor pipeline; Long Table seats+walk-ins.
	for i in 3:
		var team := _fresh_team(&"whisper_river")
		if team["structure"] == "":
			Game.restore_start(&"bathhouse")
		team["seconds_left"] = 0.0
		Game.restore_collect(&"whisper_river")
	check("bathhouse warmth aura", Game.site_state(
		&"whisper_river")["decor"].any(
			func(d): return d.get("aura") and d["effect"] == "warmth"))
	Game.coins = 5000
	var seats_before: int = Game.site_state(&"lantern_valley")["seats"]
	for i in 3:
		var team := _fresh_team(&"lantern_valley")
		if team["structure"] == "":
			Game.restore_start(&"long_table")
		team["seconds_left"] = 0.0
		Game.restore_collect(&"lantern_valley")
	var lst := Game.site_state(&"lantern_valley")
	check("long table seats+2 +walk", lst["seats"] == seats_before + 2
		and lst["walk_bonus"] == 1)

	# --- gatherings (§33.3) -------------------------------------------
	# Force-offer loop: advance mornings until the seeded roll lands.
	Game.visit_site(&"pinewatch")
	Game.site_state()["seats"] = 8
	var offered := ""
	for i in 30:
		Game.day += 1
		Game.new_day()
		var card: Array = Game.site_state()["board"].filter(
			func(b): return b.get("gathering", "") != "")
		if not card.is_empty():
			offered = card[0]["gathering"]
			break
	check("gathering offered within 30 days", offered != "")

	# Crafted quiet_corner night: two parties, both 5-star → brief met.
	var st := Game.site_state()
	st["seats"] = 8
	st["weather"] = "clear"
	st["decor"] = []
	st["assignments"] = {}
	st["guests"] = {}
	st["campfire"]["radius"] = 3
	st["blogger_bonus"] = false
	for pid in ["p1", "p2", "p3", "p6", "p7", "p8"]:
		st["pads"][pid]["open"] = true
		st["pads"][pid]["shelter"] = "platform"
	var g1 := _inject("qc_0", "couple", ["chilly"])
	g1["gathering"] = "p_quiet_corner"
	g1["favourite"] = "trail_stew"
	var g2 := _inject("qc_1", "hiker", ["chilly"])
	g2["gathering"] = "p_quiet_corner"
	g2["favourite"] = "trail_stew"
	Game.seat("qc_0", ["p2"])
	Game.seat("qc_1", ["p7"])
	Game.meals = [{"id": "trail_stew", "price": 18},
		{"id": "trail_stew", "price": 18}]
	var coins0 := Game.coins
	var rep := Game.goodnight()
	var fees2 := int(g1.get("fee", 40)) + int(g2.get("fee", 40))
	check("brief met pays +25%", rep["gathering"].get("met") == true
		and rep["gathering"]["bonus"] == int(round(fees2 * 0.25)),
		"got %s" % rep["gathering"])
	check("brief counts for page 8", int(Game.site_state()["counters"]
		.get("gatherings_met", 0)) >= 1)
	check("first-met gift flagged",
		"p_quiet_corner" in st["gathering_gifts"])
	check("bonus in the night's coins",
		Game.coins >= coins0 + fees2 + int(round(fees2 * 0.25)))

	# A missed brief pays nothing and doesn't count.
	st["assignments"] = {}
	st["guests"] = {}
	var g3 := _inject("qc_2", "couple", ["light_sleeper"])
	g3["gathering"] = "p_quiet_corner"
	var g4 := _inject("qc_3", "van_lifer", [], true)
	g4["gathering"] = "p_quiet_corner"
	_inject("qc_loud", "van_lifer", [], true)
	Game.seat("qc_loud", ["p2"])
	Game.seat("qc_2", ["p7"])
	Game.seat("qc_3", ["p1"])
	var met0: int = st["counters"].get("gatherings_met", 0)
	rep = Game.goodnight()
	check("missed brief pays nothing", rep["gathering"].get("bonus",
		0) == 0 and st["counters"].get("gatherings_met", 0) == met0)

	# --- Vol II night pages --------------------------------------------
	# P9: six parties, every one 5-star.
	st["weather"] = "clear"
	st["decor"] = []
	st["assignments"] = {}
	st["guests"] = {}
	var six := ["p1", "p2", "p3", "p6", "p7", "p8"]
	for i in six.size():
		var gg := _inject("pf_%d" % i, "hiker", ["chilly"])
		gg["favourite"] = "trail_stew"
		Game.seat("pf_%d" % i, [six[i]])
	Game.meals = []
	for i in 6:
		Game.meals.append({"id": "trail_stew", "price": 18})
	rep = Game.goodnight()
	check("perfect night stamps P9", rep["pages"].has(9),
		"pages %s stars %s" % [rep["pages"], rep["results"].map(
			func(r): return r["stars"])])

	# --- Trail Passport (§33.5) -----------------------------------------
	Game.passport_stamps = []
	var today := Time.get_date_string_from_system()
	var pz := Game.daily(today)
	var asg := {}
	for i in mini(5, pz["requests"].size()):
		asg[pz["requests"][i]["id"]] = ["d%d" % (i + 1)]
	var plc := {}
	var spots: Array = pz["decor_spots"]
	for i in pz["kit"].size():
		plc[pz["kit"][i]["id"]] = [Vector2i(spots[i][0], spots[i][1])]
	Game.daily_state = {"date": "", "score": -1}
	Game.daily_score(pz, asg, plc, true)
	check("daily stamps the passport",
		Game.passport_stamps.size() == 1
		and Game.passport_stamps[0] == today)
	Game.daily_score(pz, asg, plc, true)          # no double stamp
	check("no double stamp", Game.passport_stamps.size() == 1)
	for i in 6:
		Game.passport_stamps.append("2099-0%d-0%d" % [i + 1, i + 1])
	check("7 stamps = a cosmetic", Game.passport_cosmetics() == 1)

	# --- save round-trip -------------------------------------------------
	var blob := Save.default_state()
	blob.merge(Game.state_dict(), true)
	Game.sites = {}
	Game.load_state(blob)
	check("vol2 state persists",
		Game.restored(&"fire_tower", &"pinewatch")
		and Game.site_state(&"lantern_valley")["walk_bonus"] == 1
		and Game.passport_stamps.size() == 7)

	finish()


func restore_mix() -> int:
	var row: Dictionary = Game.restore.site_row(
		Game.site_row(&"pinewatch"), &"pinewatch")
	return int(row["archetype_mix"].get("photographer", 0))
