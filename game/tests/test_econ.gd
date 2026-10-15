extends "res://tests/harness.gd"
## Headless econ unit coverage (GDD §5, §30 row: every star term,
## tips, the rating window, walk-ins, meal allocation). Run:
##   godot --headless --path game tests/test_econ.tscn
## Exit code = number of failed checks.


func _ready() -> void:
	print("=== econ (§5) ===")

	# --- stars: 2 + comfort + meal + needs - aversions + weather ---
	check("stars base", Econ.stars(0, 0, 0, 0, 0) == 2)
	check("stars every term",
		Econ.stars(2, 1, 1, 1, -1) == 4)   # 2+2+1+1-1-1
	check("stars cap 5", Econ.stars(2, 1, 1, 0, 0) == 5)
	check("stars floor 1", Econ.stars(0, -1, 0, 4, -1) == 1)
	check("stars storm uncovered stings",
		Econ.stars(0, 0, 0, 0, -1) == 1)

	# --- tips: fee x 10% x max(0, stars - 2) -----------------------
	check("tip 1/2-star floor", Econ.tip(40, 1) == 0.0
		and Econ.tip(40, 2) == 0.0)
	check("tip 3-star", is_equal_approx(Econ.tip(40, 3), 4.0))
	check("tip 5-star", is_equal_approx(Econ.tip(40, 5), 12.0))
	check("tip scales with fee",
		is_equal_approx(Econ.tip(80, 5), 24.0))

	# --- rating: mean of the review list (window lives in Game) ----
	check("rating empty", Econ.rating([]) == 0.0)
	check("rating mean",
		is_equal_approx(Econ.rating([5, 4, 3]), 4.0))

	# --- walk-ins: min(seats, floor(rating) - 2), floored at 0 -----
	check("walk-ins under 3 stars", Econ.walk_ins(5, 2.9) == 0)
	check("walk-ins at 4.x", Econ.walk_ins(5, 4.2) == 2)
	check("walk-ins seat-capped", Econ.walk_ins(1, 5.0) == 1)

	# --- round5: display prices round to nearest 5 ----------------
	check("round5 halves up", Econ.round5(12) == 10
		and Econ.round5(13) == 15 and Econ.round5(7) == 5)

	# --- meal allocation (§5.5): favourites first, cheapest rest ---
	var meals := [{"id": "stew", "price": 18},
		{"id": "tea", "price": 8}, {"id": "fish", "price": 25}]
	var seated := [
		{"guest": {"id": "g1", "favourite": "fish"}},
		{"guest": {"id": "g2", "favourite": ""}},
		{"guest": {"id": "g3", "favourite": ""}}]
	var plan := Seating.allocate_meals(meals, seated)
	check("favourite eats +1", plan["terms"]["g1"] == 1)
	check("fed guests get 0", plan["terms"]["g2"] == 0
		and plan["terms"]["g3"] == 0)
	check("no leftover", plan["leftover"].is_empty())

	# shortfall: 2 meals, 3 guests -> last guest is hungry (-1)
	plan = Seating.allocate_meals(
		[{"id": "tea", "price": 8}, {"id": "stew", "price": 18}],
		seated)
	var starved := 0
	for gid in plan["terms"]:
		if plan["terms"][gid] == -1:
			starved += 1
	check("shortfall marks -1", starved == 1)

	# leftover: expensive meal survives to the walk-in pool
	plan = Seating.allocate_meals(
		[{"id": "tea", "price": 8}, {"id": "stew", "price": 18}],
		[seated[0]])                       # g1's favourite is fish
	check("leftover holds the pricier",
		plan["leftover"].size() == 1
			and plan["leftover"][0]["id"] == "stew")

	# --- the 15-review window (§5.6) applied at Game --------------
	Game.visit_site(&"pinewatch")
	var st := Game.site_state()
	st["reviews"] = []
	for i in 20:
		st["reviews"].append(3 if i < 10 else 5)
	while st["reviews"].size() > 15:               # goodnight's window
		st["reviews"].pop_front()
	check("window keeps last 15", st["reviews"].size() == 15)
	check("window drops the old",
		is_equal_approx(Econ.rating(st["reviews"]), 65.0 / 15),
		"got %s" % Econ.rating(st["reviews"]))
		# last 15 = five 3s + ten 5s -> 65/15 ~= 4.33

	finish()
