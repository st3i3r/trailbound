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
var coins: int = 0                          # §6.1: one currency, starts at 0
var seed: int = 0                           # save seed feeding every stream (§21.3)
var sites: Dictionary = {}                  # site_id -> site state, see _fresh_site()
var meals: Array = []                       # cooked today; never carried over (§5.5)
var bought_today: Array = []                # refundable until Goodnight (§6.1)
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
	new_day()
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


# ------------------------------------------------------------- hosting (§5)
#
# Per-site state lives in `sites[site_id]` and round-trips through the
# save's "sites" key (§22). The transient half — board, assignments,
# weather — is rebuilt every new_day; the persistent half — open pads,
# shelters, decor, seats, reviews — survives.

func site_day(site := site_id) -> int:
	return day - int(sites_visited.get(site, day)) + 1


func site_row(site := site_id) -> Dictionary:
	for s in Catalog.data.get("sites", []):
		if s.get("id") == site:
			return s
	return {}


func _row(list_name: String, item_id: String) -> Dictionary:
	for item in Catalog.data.get(list_name, []):
		if item.get("id") == item_id:
			return item
	return {}


func site_state(site := site_id) -> Dictionary:
	if site not in sites:
		sites[site] = _fresh_site(site)
	return sites[site]


func _fresh_site(site: StringName) -> Dictionary:
	var layout: Dictionary = Catalog.data.get("layouts", {}).get(site, {})
	var pads := {}
	var open: Array = layout.get("pads", {}).get("open", [])
	for pid in layout.get("pads", {}).get("spots", {}):
		pads[pid] = {"open": pid in open, "shelter": "bare"}
	var fire: Dictionary = layout.get("campfire",
		{"cell": [0, 0], "radius": 2})
	var fcell: Array = fire.get("cell", [0, 0])
	return {"pads": pads, "decor": [],
		"campfire": {"cell": Vector2i(fcell[0], fcell[1]),
			"radius": int(fire.get("radius", 2))},
		"seats": 0, "reviews": [], "weather": "clear",
		"board": [], "guests": {}, "assignments": {},
		"blogger_bonus": false}


## §21.3: every stream is seeded by save + site + site day + stream
## name, so a reload always rebuilds the same morning.
func _rng_for(stream: String, site := site_id) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d|%s|%d|%s" % [seed, site, site_day(site),
		stream]).hash()
	return rng


func _open_pads(st: Dictionary) -> Array:
	var out := []
	for pid in st["pads"]:
		if st["pads"][pid]["open"]:
			out.append(pid)
	return out


## A neighbouring pair of open, unseated pads — the family gate (§5.2).
func _has_free_pair(st: Dictionary) -> bool:
	var nbs: Dictionary = Catalog.data.get("layouts", {}).get(
		site_id, {}).get("pads", {}).get("neighbours", {})
	var taken := {}
	for pad_ids in st["assignments"].values():
		for pid in pad_ids:
			taken[pid] = true
	for pid in st["pads"]:
		if not st["pads"][pid]["open"] or taken.has(pid):
			continue
		for nb in nbs.get(pid, []):
			if st["pads"].get(nb, {}).get("open", false) \
					and not taken.has(nb):
				return true
	return false


func rating(site := site_id) -> float:
	return Econ.rating(site_state(site)["reviews"])


## Morning: forecast + booking board, both deterministic per §5.2/§5.7.
func new_day() -> void:
	var st := site_state()
	st["weather"] = _roll_weather()
	st["assignments"] = {}
	st["guests"] = {}
	bought_today = []
	st["board"] = Seating.board(site_row(),
		Catalog.data.get("archetypes", []), site_day(), _open_pads(st),
		rating(), _rng_for("board"), _has_free_pair(st))
	for r in st["board"]:
		st["guests"][r["id"]] = r


func _roll_weather() -> String:
	var sday := site_day()
	if sday <= 1:                                    # §5.7: never on day 1
		return "clear"
	if site_id == &"pinewatch" and sday == 4:        # §14 scripted rain
		return "rain"
	var chance := float(site_row().get("rain_chance", 0.2))
	return "rain" if _rng_for("weather").randf() < chance else "clear"


## Seating input for the pure-math layer (§5).
func _world() -> Dictionary:
	var st := site_state()
	var occ := {}
	for gid in st["assignments"]:
		for pid in st["assignments"][gid]:
			occ[pid] = gid
	var kinds := {}
	for t in Catalog.data.get("traits", []):
		kinds[t["id"]] = t.get("kind", "need")
	return {"layout": Catalog.data.get("layouts", {}).get(site_id, {}),
		"campfire": st["campfire"], "decor": st["decor"],
		"pads": st["pads"], "occupants": occ,
		"guests": st["guests"], "weather": st["weather"],
		"trait_kinds": kinds}


## §5 drag preview: what this party would score on those pads tonight.
func preview(guest_id: String, pad_ids: Array) -> Dictionary:
	var st := site_state()
	var guest: Dictionary = st["guests"].get(guest_id, {})
	if guest.is_empty():
		return {}
	return Seating.resolve_guest(guest, pad_ids, _world())


func can_seat(guest_id: String, pad_ids: Array) -> bool:
	var st := site_state()
	if not st["guests"].has(guest_id) or pad_ids.is_empty():
		return false
	var occupied := {}
	for gid in st["assignments"]:
		for pid in st["assignments"][gid]:
			occupied[pid] = gid
	for pid in pad_ids:
		if not st["pads"].get(pid, {}).get("open", false) \
				or occupied.has(pid):
			return false
	return true


func seat(guest_id: String, pad_ids: Array) -> bool:
	if not can_seat(guest_id, pad_ids):
		return false
	site_state()["assignments"][guest_id] = pad_ids
	return true


func unseat(guest_id: String) -> void:
	site_state()["assignments"].erase(guest_id)


## Goodnight (§5.4–5.6): resolve every seated party, take fees + tips,
## file reviews, sell leftover meals to walk-ins, end the day.
func goodnight() -> Dictionary:
	var st := site_state()
	var seated := []
	for gid in st["assignments"]:
		seated.append({"guest": st["guests"][gid],
			"pad_ids": st["assignments"][gid]})
	var rating_before := rating()
	var plan := Seating.allocate_meals(meals, seated)
	var results := []
	var fees := 0
	var tips := 0
	var elite5 := false
	for s in seated:
		var r := Seating.resolve_guest(s["guest"], s["pad_ids"],
			_world(), int(plan["terms"].get(s["guest"]["id"], -1)))
		results.append(r)
		fees += r["fee"]
		tips += int(round(r["tip"]))
		st["reviews"].append(r["stars"])
		if s["guest"].get("elite", false) and r["stars"] == 5:
			elite5 = true                              # §5.6: +1 walk-in tomorrow
	while st["reviews"].size() > 15:
		st["reviews"].pop_front()
	var walk_ins := Econ.walk_ins(st["seats"], rating_before)
	if st["blogger_bonus"]:
		walk_ins += 1
	var leftover: Array = plan["leftover"]
	leftover.sort_custom(
		func(a, b): return a.get("price", 0) > b.get("price", 0))
	var sold := leftover.slice(0, mini(walk_ins, leftover.size()))
	var meal_sales := 0
	for m in sold:
		meal_sales += int(m.get("price", 0))
	st["blogger_bonus"] = elite5
	st["assignments"] = {}
	st["guests"] = {}
	meals.clear()                                    # leftovers to the dog
	coins += fees + tips + meal_sales
	set_phase(Phase.NIGHT)
	return {"results": results, "fees": fees, "tips": tips,
		"walk_ins": sold.size(), "meal_sales": meal_sales,
		"income": fees + tips + meal_sales, "rating": rating()}


# --- purchases (§6.1: one currency, no debt, refund until Goodnight) ---

func buy_decor(item_id: String, cells: Array) -> bool:
	var row := _row("decor", item_id)
	var st := site_state()
	if row.is_empty() or coins < int(row.get("price", 0)):
		return false
	coins -= int(row["price"])
	if row.get("size") == "campfire":                # Stone Fire Pit
		st["campfire"]["radius"] = 3
	else:
		st["decor"].append({"id": item_id,
			"effect": row.get("effect", ""),
			"reach": int(row.get("reach", 1)),
			"cells": cells})
		st["seats"] += int(row.get("seats", 0))
	bought_today.append(item_id)
	return true


func open_pad(pad_id: String) -> bool:
	var st := site_state()
	var row := site_row()
	var prices: Array = row.get("pad_prices", [])
	var idx := _open_pads(st).size() - int(row.get("start_pads", 0))
	if idx < 0 or idx >= prices.size() \
			or not st["pads"].has(pad_id) \
			or st["pads"][pad_id]["open"] \
			or coins < int(prices[idx]):
		return false
	coins -= int(prices[idx])
	st["pads"][pad_id]["open"] = true
	return true


func upgrade_pad(pad_id: String, shelter: String) -> bool:
	var st := site_state()
	var row := site_row()
	var raw: Variant = row.get("platform_price") \
		if shelter == "platform" else row.get("cabin_price")
	var price := int(raw) if raw != null else 0
	if not st["pads"].get(pad_id, {}).get("open", false) \
			or price <= 0 or coins < price:
		return false
	coins -= price
	st["pads"][pad_id]["shelter"] = shelter
	return true


# ------------------------------------------------------------- save (§22)

func state_dict() -> Dictionary:
	crew_tick()
	return {"day": day, "site": String(site_id), "phase": phase,
		"sites_visited": sites_visited, "crew": crew.duplicate(true),
		"coins": coins, "seed": seed, "meals": meals.duplicate(true),
		"sites": _sites_to_json()}


## Vector2i cells aren't JSON-safe — flatten before saving, rebuild on
## load (§22).
func _sites_to_json() -> Dictionary:
	var out := {}
	for site in sites:
		var st: Dictionary = sites[site].duplicate(true)
		var fire: Dictionary = st["campfire"]
		st["campfire"] = {"cell": [fire["cell"].x, fire["cell"].y],
			"radius": fire["radius"]}
		var decor := []
		for d in st["decor"]:
			var item: Dictionary = d.duplicate()
			item["cells"] = d["cells"].map(
				func(c): return [c.x, c.y])
			decor.append(item)
		st["decor"] = decor
		out[site] = st
	return out


func _sites_from_json(raw: Dictionary) -> Dictionary:
	var out := {}
	for site in raw:
		var st: Dictionary = raw[site].duplicate(true)
		var fire: Dictionary = st.get("campfire", {})
		var fc: Array = fire.get("cell", [0, 0])
		st["campfire"] = {"cell": Vector2i(fc[0], fc[1]),
			"radius": int(fire.get("radius", 2))}
		for d in st.get("decor", []):
			d["cells"] = d.get("cells", []).map(
				func(c): return Vector2i(c[0], c[1]))
		out[StringName(site)] = st
	return out


func load_state(state: Dictionary) -> void:
	day = int(state.get("day", day))
	site_id = StringName(state.get("site", site_id))
	phase = Phase.values()[clampi(
		int(state.get("phase", int(phase))), 0, Phase.size() - 1)]
	sites_visited = state.get("sites_visited", sites_visited)
	coins = int(state.get("coins", coins))
	seed = int(state.get("seed", seed))
	meals = state.get("meals", meals)
	if state.has("sites"):
		sites = _sites_from_json(state["sites"])
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
