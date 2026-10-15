extends RefCounted
## Crew — Ranger Mai's volunteer restoration clock (§8.4, §6.10).
##
## Leaf subsystem owned by Game (see autoload/game.gd): holds no save
## state of its own. The `crew` dict and `_next_structure` index stay on
## Game for the save schema; this object reads `g.crew` and mutates it.
## Public API stays on Game as one-line delegates, so callers never move.
## Tuning consts stay on Game (restore.gd reads g.SPEEDUP_*) — this file
## reads them via `g` so §6.10 has one source.

var g # the Game autoload (untyped: circular ref)


func _init(game) -> void:
	g = game


func reset() -> void:
	g.crew = {
		"structure": "", "stage": 0, "seconds_left": 0.0,
		"last_seen_utc": 0, "speedups_stage": 0,
		"speedups_today": 0, "speedups_day": "", "collected": []}


func _structure(id: StringName) -> Dictionary:
	for s in g._structures():
		if s.get("id") == id:
			return s
	return {}


func _current_stage() -> Dictionary:
	var stages: Array = _structure(g.crew["structure"]).get("stages", [])
	return stages[g.crew["stage"]] if g.crew["stage"] < stages.size() else {}


func _today() -> String:
	return Time.get_datetime_string_from_system().substr(0, 10)


## §8.4 clock: progress = max(0, now − last seen), so a clock set back
## never undoes work (forward finishing early is accepted, §32). Runs
## while the app is closed via the same call on load.
func tick(now := int(Time.get_unix_time_from_system())) -> void:
	var last: int = g.crew["last_seen_utc"]
	g.crew["last_seen_utc"] = now
	if g.crew["structure"] == "" or g.crew["seconds_left"] <= 0.0:
		return
	g.crew["seconds_left"] = maxf(0.0,
		g.crew["seconds_left"] - maxi(0, now - last))
	if g.crew["seconds_left"] <= 0.0:
		g.crew_stage_ready.emit(g.crew["structure"])


func start(structure: StringName) -> void:
	var s := _structure(structure)
	if s.is_empty() or g.crew["structure"] != "":
		return
	g.crew["structure"] = structure
	g.crew["stage"] = 0
	g.crew["seconds_left"] = float(s["stages"][0]["seconds"])
	g.crew["last_seen_utc"] = int(Time.get_unix_time_from_system())
	g.crew["speedups_stage"] = 0
	g._next_structure = g._structures().find(s) + 1
	Analytics.log_event(&"crew_stage_start",
		{"structure": String(structure)})
	tick()
	g.touch()


## Next structure starts itself once its site is reached and the crew
## is free (§8.4). The hut is day-2-gated instead (advance_day).
func try_start_next() -> void:
	if g.crew["structure"] != "" or g._next_structure >= g._structures().size():
		return
	var s: Dictionary = g._structures()[g._next_structure]
	if s.get("auto_start") == "site_reached_and_crew_free" \
			and s.get("site", "") in g.sites_visited:
		start(s["id"])


## Collect a finished stage: keepsake to the journal, next stage (or
## structure) starts by itself (§8.4). Returns {} when not ready.
func collect() -> Dictionary:
	tick()
	if g.crew["structure"] == "" or g.crew["seconds_left"] > 0.0:
		return {}
	var s := _structure(g.crew["structure"])
	var structure: StringName = s["id"]
	var stage: Dictionary = s["stages"][g.crew["stage"]]
	var keepsake: StringName = stage["keepsake"]["id"]
	g.crew["collected"].append(keepsake)
	g.crew["stage"] += 1
	g.crew["speedups_stage"] = 0
	var finished: bool = g.crew["stage"] >= s["stages"].size()
	if finished:
		g.crew["structure"] = ""
		g.crew["seconds_left"] = 0.0
		for sr in Catalog.data.get("sites", []):
			if sr.get("crew_structure") == structure:
				g.site_state(sr["id"])["vignette_restored"] = structure
		try_start_next()
	else:
		g.crew["seconds_left"] = float(s["stages"][g.crew["stage"]]["seconds"])
	g.crew_collected.emit(structure, keepsake, finished)
	Analytics.log_event(&"crew_stage_collect",
		{"structure": String(structure), "finished": finished})
	g.touch()
	return {"structure": structure, "keepsake": keepsake,
		"finished": finished, "vignette": s.get("vignette", "")}


## Rewarded-ad speed-up (§6.10): one chunk off the stage, capped per
## stage and per calendar day, offered from day 4 (§8.4).
func speedup() -> float:
	tick()
	if not can_speedup():
		return 0.0
	if g.crew["speedups_day"] != _today():
		g.crew["speedups_day"] = _today()
		g.crew["speedups_today"] = 0
	var chunk := maxf(g.SPEEDUP_MIN_CHUNK,
		float(_current_stage()["seconds"]) / 6.0)
	g.crew["seconds_left"] = maxf(0.0, g.crew["seconds_left"] - chunk)
	g.crew["speedups_stage"] += 1
	g.crew["speedups_today"] += 1
	g.ads["last_rewarded_utc"] = int(Time.get_unix_time_from_system())
	Analytics.log_event(&"ad_rewarded_complete",
		{"placement": "crew_speedup"})
	g.touch()
	return chunk


func can_speedup() -> bool:
	if g.day < g.SPEEDUP_FROM_DAY or g.crew["structure"] == "" \
			or g.crew["seconds_left"] <= 0.0:
		return false
	var today_used: int = g.crew["speedups_today"] \
		if g.crew["speedups_day"] == _today() else 0
	return g.crew["speedups_stage"] < g.SPEEDUPS_PER_STAGE \
		and today_used < g.SPEEDUPS_PER_DAY


## Finish is free once 5 minutes or less remain (§6.10).
func free_finish() -> bool:
	tick()
	if g.crew["structure"] == "" or g.crew["seconds_left"] > g.FREE_FINISH_LEFT:
		return false
	g.crew["seconds_left"] = 0.0
	g.touch()
	return true


func is_stage_ready() -> bool:
	tick()
	return g.crew["structure"] != "" and g.crew["seconds_left"] <= 0.0


## All three v1 structures fully collected. Vol II restorations are
## site-team work, not the v1 crew's list (§6.11).
func done() -> bool:
	var total := 0
	for s in g._structures():
		if s.get("volume2", false):
			continue
		total += s.get("stages", []).size()
	return g.crew["collected"].size() >= total and total > 0


## First structure not fully collected, or one past the active one.
func next_unfinished() -> int:
	for i in g._structures().size():
		var s: Dictionary = g._structures()[i]
		if s.get("id", "") == g.crew["structure"]:
			return i + 1
		var all_collected := true
		for stage in s.get("stages", []):
			if stage.get("keepsake", {}).get("id", "") \
					not in g.crew["collected"]:
				all_collected = false
		if not all_collected:
			return i
	return g._structures().size()
