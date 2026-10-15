extends "res://tests/harness.gd"
## Depth systems — the authored-texture pass: evening care gestures,
## recipe mastery, familiar faces, spot-tabled fishing, the Field
## Camera, Grandpa's Fund, decor variants. Run:
##   godot --headless --path game tests/test_depth.tscn
## Exit code = number of failed checks.


func _ready() -> void:
	print("=== depth systems ===")
	Game.load_state(Save.default_state())
	Game.coins = 1000
	var st: Dictionary = Game.site_state()

	# --- care gestures: stoke once, tuck once, both undoable --------
	Game.set_phase(Game.Phase.EVENING)
	check("stoke available in the evening", Game.can_stoke_fire())
	check("stoke lands", Game.stoke_fire())
	check("stoke once a night", not Game.can_stoke_fire())
	check("stoke undoes", Game.undo() and Game.can_stoke_fire())
	Game.stoke_fire()
	var g1 := _inject("g_a", "hiker", [])
	g1["fee"] = 40
	st["assignments"]["g_a"] = ["p1"]
	check("tuck needs a seat", not Game.can_tuck_in("g_ghost"))
	check("tuck lands", Game.tuck_in("g_a"))
	check("one tuck a night", not Game.tuck_in("g_a"))
	var base := int(Seating.resolve_guest(g1, ["p1"],
		Game._world(), -1)["stars"])
	var rep := Game.goodnight()
	var stars := int(rep["results"][0]["stars"])
	check("tuck raises one star", stars == mini(base + 1, 5),
		"got %d from %d" % [stars, base])
	# stoke warms the tip pool: round(per-guest tip) then x1.1 on it
	var want_tip := int(round(
		float(int(round(Econ.tip(40, stars)))) * 1.1))
	check("stoke warms tips", rep["tips"] == want_tip,
		"got %d want %d" % [rep["tips"], want_tip])

	# --- gestures reset with the day --------------------------------
	Game.advance_day()
	check("stoke resets", st["fire_stoked"] == false)
	check("tuck resets", st["tucked_in"] == "")

	# --- unseat releases a tuck --------------------------------------
	st["assignments"].clear()
	var g2 := _inject("g_b", "hiker", [])
	st["assignments"]["g_b"] = ["p1"]
	Game.set_phase(Game.Phase.EVENING)
	check("tuck again next night", Game.tuck_in("g_b"))
	Game.unseat("g_b")
	check("unseat frees the tuck", st["tucked_in"] == "")
	Game.goodnight()

	# --- recipe mastery ----------------------------------------------
	check("tier 0 unpracticed", Game.cook_tier("stew") == 0)
	Game.cook_counts["stew"] = 5
	check("tier 1 at 5 cooks", Game.cook_tier("stew") == 1)
	Game.cook_counts["stew"] = 15
	check("tier 2 at 15", Game.cook_tier("stew") == 2)
	# a Signature stew that lands on a guest tips +15
	Game.advance_day()
	st["assignments"].clear()
	var g3 := _inject("g_c", "scout", [])
	g3["fee"] = 40
	st["assignments"]["g_c"] = ["p1"]
	Game.meals = [{"id": "stew", "price": 18}]
	Game.set_phase(Game.Phase.EVENING)
	rep = Game.goodnight()
	var t2 := int(rep["results"][0]["stars"])
	var want := int(round(Econ.tip(40, t2))) + 15
	check("signature plate tips +15", rep["tips"] == want,
		"got %d want %d" % [rep["tips"], want])

	# --- familiar faces -----------------------------------------------
	# two prior hiker stays at this site -> the board tags returners
	Game.advance_day()
	st["counters"]["arch_visits"]["hiker"] = 2
	Game.advance_day()
	var ret = st["board"].filter(func(b):
		return b.get("archetype") == "hiker" \
			and b.get("returning", false))
	var all_h = st["board"].filter(func(b):
		return b.get("archetype") == "hiker")
	check("returning badged on the card",
		ret.size() == all_h.size() and ret.size() > 0,
		"got %d/%d" % [ret.size(), all_h.size()])
	check("regulars never tagged", not st["board"].any(func(b):
		return b.get("regular", "") != "" \
			and b.get("returning", false)))
	# seat a returner -> +10 loyalty tip, logged
	st["assignments"].clear()
	var rg: Dictionary = ret[0]
	st["assignments"][rg["id"]] = ["p1"]
	Game.set_phase(Game.Phase.EVENING)
	rep = Game.goodnight()
	var rst := int(rep["results"][0]["stars"])
	check("returner tips +10", rep["tips"] ==
		int(round(Econ.tip(int(rg["fee"]), rst))) + 10,
		"got %d" % rep["tips"])
	check("days_log counts returners",
		Game.days_log.back().get("returners", 0) == 1)

	# --- WR spot tables: the bank decides what bites -------------------
	Game.visit_site(&"whisper_river")
	var wr: Dictionary = Game.site_state()
	Game.gear.append("fishing_rod")
	# 3 real casts/day: stream positions 0,1,2 — bank_a is a catfish
	# bend, never a loach bank (the table simply lacks the row)
	var catches = {}
	for i in 3:
		var got := Game.fish_catch("bank_a")
		if got != "":
			catches[got] = true
	check("bank_a never gives loach",
		not catches.has("loach") and not catches.is_empty(),
		"got %s" % [catches.keys()])
	check("bank_a spent its casts", Game.fish_catch("bank_a") == "")
	# determinism: replay the same day-state, the stream reproduces
	wr["fish_taken"] = {}
	var a := Game.fish_catch("bank_c")
	wr["fish_taken"] = {}
	check("same day same draw", Game.fish_catch("bank_c") == a)
	# the run is the only loach bank — sweep days (each a fresh
	# stream) for coverage one fixed seed can't fake
	var saw_loach := false
	for i in 6:
		wr["fish_taken"] = {}
		Game.day += 1
		for c in 3:
			if Game.fish_catch("bank_c") == "loach":
				saw_loach = true
	check("bank_c can give loach", saw_loach)

	# --- the Field Camera ----------------------------------------------
	Game.visit_site(&"lantern_valley")
	var lv: Dictionary = Game.site_state()
	check("no camera, no photo", not Game.can_photo())
	Game.gear.append("camera")
	check("camera opens the verb", Game.can_photo())
	var coins0 := Game.coins
	var shot := Game.take_photo()
	check("a shot lands", String(shot.get("id", "")) != "")
	check("print sale pays", Game.coins > coins0)
	check("one shot a day", not Game.can_photo())
	# five shots finish the wall — reset the day flag per shot
	for i in 4:
		lv["photo_day"] = -1
		Game.take_photo()
	check("photo_wall event at five",
		lv["counters"]["events"].has("photo_wall"))
	check("camera is LV-only", not (
		Game.site_id != &"lantern_valley" and Game.can_photo()))

	# --- Grandpa's Fund ---------------------------------------------------
	Game.visit_site(&"pinewatch")
	var pw: Dictionary = Game.site_state()
	Game.coins = 600
	check("donate floor", not Game.donate_fund(10))
	check("donate beyond purse", not Game.donate_fund(700))
	var gift := Game.donate_fund(500)
	check("tier 1 banks", Game.fund_total == 500)
	check("tier event fires",
		pw["counters"]["events"].has("fund_tier_1"))
	check("grant lands in stored",
		pw["stored"].any(func(s): return s["id"] == "trail_bench"))
	check("coins leave", Game.coins == 100)
	var grant = pw["stored"].filter(
		func(s): return s["id"] == "trail_bench")[0]
	check("grant carries effect", String(grant.get("effect", "")) != "")
	# the wandering mailbag delivers it next morning, at any site
	Game.advance_day()
	check("fund letter delivers",
		"fund_1" in pw["letters_delivered"]
		and "fund_1" in Game.letters_delivered_any)
	var before = pw["letters_delivered"].size()
	Game.advance_day()
	check("any-mail delivers once",
		pw["letters_delivered"].size() <= before + 1)

	# --- seating wishes ----------------------------------------------------
	# at PW (no pad tags) only generic kinds can be dealt
	var wish_vocab := ["fire", "quiet", "company", "solo", "water",
		"view", "lit", "sky", "together"]
	var wished = pw["board"].filter(
		func(b): return String(b.get("wish", "")) != "")
	check("the board deals wishes", wished.size() > 0,
		"got %d of %d" % [wished.size(), pw["board"].size()])
	check("wishes stay in the vocabulary", pw["board"].all(func(b):
		return String(b.get("wish", "")) == "" \
			or String(b.get("wish", "")) in wish_vocab))
	check("tag-wishes need a tagged site", pw["board"].all(func(b):
		return String(b.get("wish", "")) not in ["water", "view"]))
	check("cards carry the wish label", wished.all(func(b):
		return String(b.get("wish_label", "")) != ""))
	# no broken promises: every dealt kind is grantable tonight
	var kinds: Array = Game._wish_kinds(st)
	check("dealt wishes are grantable", pw["board"].all(func(b):
		var w := String(b.get("wish", ""))
		return w == "" or w in kinds \
			or w in ["quiet", "company", "solo"]))
	# a met wish is +1 star — quiet lands on an empty camp
	st["assignments"].clear()
	var wrld: Dictionary = Game._world()
	var plain := int(Seating.resolve_guest(
		{"id": "wq0", "traits": [], "fee": 40, "archetype": "hiker"},
		["p1"], wrld)["stars"])
	var wq := _inject("wq", "hiker", [])
	wq["wish"] = "quiet"
	var met := Seating.resolve_guest(wq, ["p1"], wrld)
	check("met wish adds a star",
		int(met["stars"]) == mini(plain + 1, 5),
		"got %d vs %d" % [int(met["stars"]), plain])
	check("met wish rekeys the line",
		String(met["comment_key"]) == "wish",
		"got %s" % met["comment_key"])
	var wco := _inject("wco", "hiker", [])
	wco["wish"] = "company"
	var missed := Seating.resolve_guest(wco, ["p1"], wrld)
	check("missed wish stays put",
		int(missed["stars"]) == plain \
			and missed["wish_met"] == false)
	# and the night ledger counts granted ones
	st["assignments"].clear()
	st["assignments"]["wq"] = ["p1"]
	Game.set_phase(Game.Phase.EVENING)
	Game.goodnight()
	check("days_log counts wishes",
		int(Game.days_log.back().get("wishes_met", 0)) >= 1)

	# --- Grandpa's Margins ---------------------------------------------------
	Game.advance_day()
	check("margins are pinewatch's", Game.can_read_margin())
	var m1 := Game.read_margin()
	check("first margin reads", String(m1.get("id", "")) == "m01")
	check("one margin a day", not Game.can_read_margin())
	Game.advance_day()
	check("margins run in order",
		String(Game.read_margin().get("id", "")) == "m02")
	# a recipe hint writes the pair straight into the discovery log
	st["margins_read"].resize(12)
	st["margin_day"] = -1
	var m13 := Game.read_margin()
	check("recipe hint writes the pair",
		String(m13.get("hint", {}).get("kind", "")) == "recipe"
		and String(Game.pairs_tried.get("catfish+honey", "")) != "",
		"got %s" % m13)
	Game.visit_site(&"whisper_river")
	check("margins stay home", not Game.can_read_margin())
	Game.visit_site(&"pinewatch")

	# --- weather streaks -----------------------------------------------------
	# the forecast is seeded — find the first real 3-day run, play to
	# it, and the ledger records the camp feeling the weather
	var streak_at := -1
	for sday in range(1, 60):
		var w0 := Game._weather_at(sday)
		if Game._weather_at(sday + 1) == w0 \
				and Game._weather_at(sday + 2) == w0:
			streak_at = sday + 2
			break
	check("the climate makes a streak", streak_at > 0)
	# settle the camp so advance_day can't quietly no-op forever
	st["assignments"].clear()
	Game.meals.clear()
	var guard := 0
	while Game.site_day() < streak_at and guard < 80:
		Game.advance_day()
		guard += 1
	var wsev = ["soggy_camp", "heat_wave", "wild_storm", "wet_streak"]
	var evs: Dictionary = st["counters"]["events"]
	check("three same days mark the ledger",
		wsev.any(func(e): return evs.has(e)),
		"got %s" % [evs.keys()])
	check("the streak counts itself",
		int(st["weather_streak"]["days"]) >= 3)
	var wsk := String(st["weather_streak"]["kind"])
	check("the streak arm reads",
		Game.journal.dialogue_when_ok({"weather_streak": wsk}))
	check("the streak arm is honest",
		not Game.journal.dialogue_when_ok({"weather_streak":
			"rain" if wsk != "rain" else "clear"}))
	# wishes_met_min stays honest whatever the last night held
	var last_wishes := int(Game.days_log.back().get("wishes_met", 0))
	check("wishes arm is honest",
		not Game.journal.dialogue_when_ok(
			{"wishes_met_min": last_wishes + 1}))
	Game.advance_day()
	check("soggy letter wanders in",
		"w_soggy" in st["letters_delivered"]
			or not st["counters"]["events"].has("soggy_camp"))

	# --- dog fetch --------------------------------------------------------------
	check("he won't work for a stranger", not Game.can_dog_fetch())
	Game.adopt_dog("Chó")
	check("fetch opens post-adoption", Game.can_dog_fetch())
	Game.pantry.clear()                    # headroom: 40 days of digs filled it
	var p0 := 0
	for v in Game.pantry.values():
		p0 += int(v)
	var fetched := Game.dog_fetch("forage")
	check("he brings something", String(fetched.get("id", "")) != "")
	var p1 := 0
	for v in Game.pantry.values():
		p1 += int(v)
	check("the pantry gains", p1 == p0 + 1)
	check("once a day", not Game.can_dog_fetch())
	check("bad kind refused", Game.dog_fetch("gold").is_empty())

	# --- decor variants ---------------------------------------------------
	Game.coins = 200
	_put("lantern", "comfort", 1, [[4, 4]])
	var di = st["decor"].size() - 1
	check("variant buys", Game.buy_decor_variant(di, "brass"))
	check("variant tagged",
		String(st["decor"][di].get("variant", "")) == "brass")
	check("variant priced", Game.coins == 200 - 90)
	check("no re-buy same", not Game.buy_decor_variant(di, "brass"))
	check("unknown variant refused",
		not Game.buy_decor_variant(di, "neon"))
	check("variant undoes", Game.undo()
		and st["decor"][di].get("variant", "") == ""
		and Game.coins == 200)

	# leave a neutral save behind for the next suite
	Game.load_state(Save.default_state())
	Save.save_state(Game.state_dict())
	finish()
