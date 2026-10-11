extends Node
## Game — phase state machine and day/site flow (GDD 21.1).
## Boot → Title → Morning → Prep → Evening → Night, one in-game day
## at a time, player-paced. The crew clock (§8.4, D-23) also lives
## here: real-time stage progress beside the day, never feeding an
## RNG (§21.3) and never blocking the arc.

signal phase_changed(phase: Phase)
signal crew_stage_ready(structure: StringName)
signal crew_collected(structure: StringName, keepsake: StringName, finished: bool)

enum Phase { BOOT, TITLE, MORNING, PREP, EVENING, NIGHT }

const SPEEDUP_MIN_CHUNK := 900.0   # §6.10: chunk = max(15 min, stage / 6)
const SPEEDUPS_PER_STAGE := 3
const SPEEDUPS_PER_DAY := 6
const FREE_FINISH_LEFT := 300.0    # Finish is free once ≤ 5 min remain
const SPEEDUP_FROM_DAY := 4        # offers appear from day 4 (§8.4)

var phase: Phase = Phase.BOOT
var day: int = 0
var site_id: StringName = &"pinewatch"
var sites_visited: Dictionary = {}          # site_id -> first in-game day
var crew: Dictionary = {}                   # §22 save shape, see _crew_reset()
var _next_structure := 0
var _tick_accum := 0.0


func _ready() -> void:
	_crew_reset()


## crew.json structures in site order; read lazily so autoload order
## (Game before Catalog) can't matter.
func _structures() -> Array:
	return Catalog.data.get("crew", {}).get("structures", [])


func _process(delta: float) -> void:
	_tick_accum += delta
	if _tick_accum >= 1.0:
		_tick_accum = 0.0
		crew_tick()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		crew_tick()                          # catch up after backgrounding


func set_phase(next: Phase) -> void:
	if next == phase:
		return
	phase = next
	phase_changed.emit(phase)


func advance_day() -> void:
	day += 1
	visit_site(site_id)
	if day == 2:
		crew_start(&"wardens_hut")           # §8.4: Mai's van on day 2
	set_phase(Phase.MORNING)


func visit_site(site: StringName) -> void:
	site_id = site
	if site not in sites_visited:
		sites_visited[site] = day
		_try_start_next()


# ------------------------------------------------------------- crew (§8.4)

func _crew_reset() -> void:
	crew = {
		"structure": "", "stage": 0, "seconds_left": 0.0,
		"last_seen_utc": 0, "speedups_stage": 0,
		"speedups_today": 0, "speedups_day": "", "collected": []}


func _structure(id: StringName) -> Dictionary:
	for s in _structures():
		if s.get("id") == id:
			return s
	return {}


func _current_stage() -> Dictionary:
	var stages: Array = _structure(crew["structure"]).get("stages", [])
	return stages[crew["stage"]] if crew["stage"] < stages.size() else {}


func _today() -> String:
	return Time.get_datetime_string_from_system().substr(0, 10)


## §8.4 clock: progress = max(0, now − last seen), so a clock set back
## never undoes work (forward finishing early is accepted, §32). Runs
## while the app is closed via the same call on load.
func crew_tick(now := int(Time.get_unix_time_from_system())) -> void:
	var last: int = crew["last_seen_utc"]
	crew["last_seen_utc"] = now
	if crew["structure"] == "" or crew["seconds_left"] <= 0.0:
		return
	crew["seconds_left"] = maxf(0.0,
		crew["seconds_left"] - maxi(0, now - last))
	if crew["seconds_left"] <= 0.0:
		crew_stage_ready.emit(crew["structure"])


func crew_start(structure: StringName) -> void:
	var s := _structure(structure)
	if s.is_empty() or crew["structure"] != "":
		return
	crew["structure"] = structure
	crew["stage"] = 0
	crew["seconds_left"] = float(s["stages"][0]["seconds"])
	crew["last_seen_utc"] = int(Time.get_unix_time_from_system())
	crew["speedups_stage"] = 0
	_next_structure = _structures().find(s) + 1
	crew_tick()


## Next structure starts itself once its site is reached and the crew
## is free (§8.4). The hut is day-2-gated instead (advance_day).
func _try_start_next() -> void:
	if crew["structure"] != "" or _next_structure >= _structures().size():
		return
	var s: Dictionary = _structures()[_next_structure]
	if s.get("auto_start") == "site_reached_and_crew_free" \
			and s.get("site", "") in sites_visited:
		crew_start(s["id"])


## Collect a finished stage: keepsake to the journal, next stage (or
## structure) starts by itself (§8.4). Returns {} when not ready.
func crew_collect() -> Dictionary:
	crew_tick()
	if crew["structure"] == "" or crew["seconds_left"] > 0.0:
		return {}
	var s := _structure(crew["structure"])
	var structure: StringName = s["id"]
	var stage: Dictionary = s["stages"][crew["stage"]]
	var keepsake: StringName = stage["keepsake"]["id"]
	crew["collected"].append(keepsake)
	crew["stage"] += 1
	crew["speedups_stage"] = 0
	var finished: bool = crew["stage"] >= s["stages"].size()
	if finished:
		crew["structure"] = ""
		crew["seconds_left"] = 0.0
		_try_start_next()
	else:
		crew["seconds_left"] = float(s["stages"][crew["stage"]]["seconds"])
	crew_collected.emit(structure, keepsake, finished)
	return {"structure": structure, "keepsake": keepsake,
		"finished": finished, "vignette": s.get("vignette", "")}


## Rewarded-ad speed-up (§6.10): one chunk off the stage, capped per
## stage and per calendar day, offered from day 4 (§8.4).
func crew_speedup() -> float:
	crew_tick()
	if not crew_can_speedup():
		return 0.0
	if crew["speedups_day"] != _today():
		crew["speedups_day"] = _today()
		crew["speedups_today"] = 0
	var chunk := maxf(SPEEDUP_MIN_CHUNK,
		float(_current_stage()["seconds"]) / 6.0)
	crew["seconds_left"] = maxf(0.0, crew["seconds_left"] - chunk)
	crew["speedups_stage"] += 1
	crew["speedups_today"] += 1
	return chunk


func crew_can_speedup() -> bool:
	if day < SPEEDUP_FROM_DAY or crew["structure"] == "" \
			or crew["seconds_left"] <= 0.0:
		return false
	var today_used: int = crew["speedups_today"] \
		if crew["speedups_day"] == _today() else 0
	return crew["speedups_stage"] < SPEEDUPS_PER_STAGE \
		and today_used < SPEEDUPS_PER_DAY


## Finish is free once 5 minutes or less remain (§6.10).
func crew_free_finish() -> bool:
	crew_tick()
	if crew["structure"] == "" or crew["seconds_left"] > FREE_FINISH_LEFT:
		return false
	crew["seconds_left"] = 0.0
	return true


func is_stage_ready() -> bool:
	crew_tick()
	return crew["structure"] != "" and crew["seconds_left"] <= 0.0


func crew_done() -> bool:
	var total := 0
	for s in _structures():
		total += s.get("stages", []).size()
	return crew["collected"].size() >= total and total > 0


# ------------------------------------------------------------- save (§22)

func state_dict() -> Dictionary:
	crew_tick()
	return {"day": day, "site": String(site_id), "phase": phase,
		"sites_visited": sites_visited, "crew": crew.duplicate(true)}


func load_state(state: Dictionary) -> void:
	day = int(state.get("day", day))
	site_id = StringName(state.get("site", site_id))
	phase = Phase.values()[clampi(
		int(state.get("phase", int(phase))), 0, Phase.size() - 1)]
	sites_visited = state.get("sites_visited", sites_visited)
	var saved: Dictionary = state.get("crew", {})
	_crew_reset()
	for key in saved:
		crew[key] = saved[key]
	_next_structure = _next_unfinished()
	crew_tick()                    # offline progress applies on load (§8.4)


## First structure not fully collected, or one past the active one.
func _next_unfinished() -> int:
	for i in _structures().size():
		var s: Dictionary = _structures()[i]
		if s.get("id", "") == crew["structure"]:
			return i + 1
		var all_collected := true
		for stage in s.get("stages", []):
			if stage.get("keepsake", {}).get("id", "") \
					not in crew["collected"]:
				all_collected = false
		if not all_collected:
			return i
	return _structures().size()
