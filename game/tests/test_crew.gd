extends Node
## Headless crew-clock checks (GDD 29 §8.4/§6.10 cases). Run:
##   godot --headless --path game tests/test_crew.tscn
## Exit code = number of failed checks.

var failures := 0


func check(name: String, cond: bool, detail := "") -> void:
	if not cond:
		failures += 1
		print("  XX %s %s" % [name, detail])
	else:
		print("  OK %s" % name)


func _ready() -> void:
	var game := Game
	var save := Save
	var now := int(Time.get_unix_time_from_system())
	print("=== crew clock (§8.4, §6.10) ===")

	# Day 1: nothing started.
	game.advance_day()
	check("day 1 idle", game.crew["structure"] == "")

	# Day 2: Mai's van — hut stage 1 starts by itself.
	game.advance_day()
	check("day 2 hut starts", game.crew["structure"] == "wardens_hut"
		and game.crew["seconds_left"] == 600.0,
		"got %s %.0fs" % [game.crew["structure"], game.crew["seconds_left"]])

	# Clock moved BACK: no progress is undone (§8.4).
	game.crew["seconds_left"] = 400.0
	game.crew_tick(now - 3600)
	check("clock back keeps progress", game.crew["seconds_left"] == 400.0,
		"got %.0f" % game.crew["seconds_left"])

	# Offline progress: app "closed" for 500 s.
	game.crew_tick(now + 500)
	check("closed-app progress", game.crew["seconds_left"] == 0.0
		or absf(game.crew["seconds_left"]) < 1.0,
		"got %.0f" % game.crew["seconds_left"])
	check("stage ready bubble", game.is_stage_ready())

	# Collect stage 1: keepsake in, stage 2 (4 h) starts.
	var r: Dictionary = game.crew_collect()
	check("collect stage 1", r.get("keepsake") == &"grandpas_thermos"
		and game.crew["stage"] == 1
		and game.crew["seconds_left"] == 14400.0,
		"got %s" % r)

	# Speed-up gate: day < 4 (§8.4).
	game.day = 3
	check("no speed-up before day 4", not game.crew_can_speedup())

	# Speed-up chunk on the 4 h stage: max(900, 14400/6) = 2400.
	game.day = 5
	var chunk: float = game.crew_speedup()
	check("chunk = stage/6 = 40 min", chunk == 2400.0, "got %.0f" % chunk)
	check("chunk applied", game.crew["seconds_left"] == 12000.0
		and game.crew["speedups_stage"] == 1
		and game.crew["speedups_today"] == 1)

	# Stage cap: 3 per stage (§6.10).
	game.crew_speedup()
	game.crew_speedup()
	check("stage cap 3", not game.crew_can_speedup()
		and game.crew["seconds_left"] == 7200.0,
		"got %.0fs" % game.crew["seconds_left"])

	# Per-day cap survives the stage reset on collect.
	game.crew["seconds_left"] = 0.0
	game.crew_collect()
	check("new stage resets stage cap",
		game.crew["speedups_stage"] == 0 and game.crew_can_speedup())
	for i in 5:
		game.crew_speedup()
	check("day cap 6", not game.crew_can_speedup()
		and game.crew["speedups_today"] == 6,
		"got %d" % game.crew["speedups_today"])

	# Free finish at ≤ 5 min (§6.10).
	game.crew["seconds_left"] = 299.0
	check("free finish ≤ 5 min", game.crew_free_finish()
		and game.crew["seconds_left"] == 0.0)

	# Finish the hut: last keepsake + vignette, crew goes idle.
	var last: Dictionary = game.crew_collect()
	check("hut finished", last.get("finished") == true
		and last.get("vignette") == "porch_light"
		and game.crew["structure"] == "", "got %s" % last)

	# Boathouse starts only once its site is reached (§8.4).
	game.visit_site(&"whisper_river")
	check("boathouse on reach", game.crew["structure"] == "boathouse"
		and game.crew["seconds_left"] == 3600.0,
		"got %s" % game.crew["structure"])

	# Kill mid-stage + reload: state round-trips, offline ticks apply.
	var saved: Dictionary = save.default_state()
	saved.merge(game.state_dict(), true)
	saved["crew"]["last_seen_utc"] = saved["crew"]["last_seen_utc"] - 3600
	game.crew["seconds_left"] = 9999.0
	game.load_state(save._migrate(saved))
	check("reload catches up 1 h", game.crew["structure"] == "boathouse"
		and game.crew["seconds_left"] <= 1.0,
		"got %.0f" % game.crew["seconds_left"])
	check("keepsakes kept", game.crew["collected"].size() == 3)

	# Collect the rest; workshop starts on reaching Lantern Valley.
	for i in 3:
		game.crew["seconds_left"] = 0.0
		game.crew_collect()
	game.visit_site(&"lantern_valley")
	check("workshop on reach", game.crew["structure"] == "lantern_workshop")
	for i in 3:
		game.crew["seconds_left"] = 0.0
		game.crew_collect()
	check("all 9 keepsakes", game.crew_done()
		and game.crew["collected"].size() == 9,
		"got %d" % game.crew["collected"].size())

	print("=== %s ===" % ("ALL CHECKS PASS" if failures == 0
		else "%d FAILURES" % failures))
	get_tree().quit(failures)
