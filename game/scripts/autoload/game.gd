extends Node
## Game — phase state machine and day/site flow (GDD 21.1).
## Boot → Title → Morning → Prep → Evening → Night, one in-game day
## at a time, player-paced. The crew clock (§8.4, D-23) also lives
## here: real-time stage progress beside the day, never feeding an
## RNG (§21.3) and never blocking the arc.

signal phase_changed(phase: Phase)
signal crew_stage_ready(structure: StringName)
signal crew_collected(structure: StringName, keepsake: StringName, finished: bool)
signal page_completed(site: StringName, page: int, gift: int, unlocks: Array)
signal letter_delivered(letter: Dictionary)

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
var letters_read: Array = []                # letter ids (§8.2 journal)
var vignettes_seen: Array = []              # §13.4 unseen plays first
var field_notes: Array = []                 # §7.3 logged bird ids
var dog := {"name": "Bean", "bond": 0, "met": false,
	"pet_today": false}                       # §9 companion
var crew: Dictionary = {}                   # §22 save shape, see _crew_reset()
var coins: int = 0                          # §6.1: one currency, starts at 0
var seed: int = 0                           # save seed feeding every stream (§21.3)
var sites: Dictionary = {}                  # site_id -> site state, see _fresh_site()
var meals: Array = []                       # cooked today; never carried over (§5.5)
var bought_today: Array = []                # refundable until Goodnight (§6.1)
var pantry := {}                            # ingredient id -> count (§7.4, global)
var gear: Array = []                        # owned gear ids (global, §6.7)
var recipes_cooked: Array = []              # recipe ids cooked ≥once — the book
var pairs_tried := {}                       # "a+b" -> recipe id | "camp_mash" | "oven_hint"
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


## §8.2: the morning trail map. Gated by chapter completion; re-rolls
## the day at the chosen site so the board/weather are the new site's.
func travel_to(site: StringName) -> bool:
	if not site_reachable(site):
		return false
	visit_site(site)
	new_day()
	return true


## §12.3: regulars book about every third day at their site until
## their story ends (visit count reaching story_visits). They take a
## normal request slot; an elite card is never displaced.
func _inject_regulars(st: Dictionary) -> void:
	var d := site_day()
	for reg: Dictionary in Catalog.data.get("regulars", []):
		if reg.get("site") != site_id:
			continue
		var rid: String = reg["id"]
		var visits: int = st["counters"]["regular_visits"].get(rid, 0)
		if visits >= int(reg.get("story_visits", 3)):
			continue                                   # story told
		var due := false
		if reg.get("weekend_only", false):
			# the Minh family: weekend visitors, and only once a
			# neighbouring pair can take them (§5.2 family rule)
			due = d % 7 in [6, 0] and _has_free_pair(st)
		else:
			var off := int(reg.get("offset", 3))
			due = d >= off and (d - off) % int(reg.get("every", 3)) == 0
		if not due:
			continue
		var req := {"id": "reg_" + rid,
			"archetype": reg["archetype"], "name": reg["name"],
			"traits": reg.get("traits", []).duplicate(),
			"loud": reg.get("loud", false),
			"pads": int(reg.get("pads", 1)),
			"fee": int(reg["fee"]), "regular": rid,
			"favourite": reg.get("favourite", "")}
		var slotted := false
		# Front-scan: the last two cards may carry the day-6+
		# conflict pair (§5.2) — displacing them breaks the board.
		for i in st["board"].size():
			var card: Dictionary = st["board"][i]
			if not card.get("elite") and card.get("regular", "") == "":
				st["board"][i] = req
				slotted = true
				break
		if not slotted:
			st["board"].append(req)


# ------------------------------------------------------------- letters (§8.2/§13)
#
# Letters arrive in order, at most one per morning; event-triggered
# letters go first and unread ones wait in the journal.

func _letters_for(site := site_id) -> Array:
	return Catalog.data.get("letters", []).filter(
		func(l): return l.get("site") == site)


func _letter_due(l: Dictionary, st: Dictionary) -> bool:
	var tr: Dictionary = l.get("trigger", {})
	if tr.has("morning"):
		return site_day() >= int(tr["morning"])
	var ev: String = tr.get("event", "")
	match ev:
		"family_booked":
			return st["counters"]["events"].has("family_booked")
		"chapter_done":
			return chapter_done(site_id)
		_:
			if ev.begins_with("regular_done:"):
				return _story_done(ev.get_slice(":", 1))
			if ev.begins_with("page:"):
				return page_done(int(ev.get_slice(":", 1)))
	return false


## One letter per morning, event triggers before morning triggers,
## both in written order (§8.2).
func _deliver_letter(st: Dictionary) -> void:
	var delivered: Array = st["letters_delivered"]
	for want_event in [true, false]:
		for l in _letters_for():
			if l["id"] in delivered:
				continue
			if (l.get("trigger", {}).has("event")) != want_event:
				continue
			if _letter_due(l, st):
				delivered.append(l["id"])
				letter_delivered.emit(l)
				return


## Journal API: delivered-but-unread letters for this site.
func unread_letters(site := site_id) -> Array:
	var st := site_state(site)
	return _letters_for(site).filter(func(l):
		return l["id"] in st["letters_delivered"] \
			and l["id"] not in letters_read)


func read_letter(id: String) -> void:
	if id not in letters_read:
		letters_read.append(id)


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
		for sr in Catalog.data.get("sites", []):
			if sr.get("crew_structure") == structure:
				site_state(sr["id"])["vignette_restored"] = structure
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
		"blogger_bonus": false, "forage_nodes": [], "fish_taken": {},
		"spot_day": -1,
		"pages_done": [], "letters_delivered": [],
		"vignette_restored": "",
		"counters": {"guests_welcomed": 0, "families": 0,
			"anglers_water": 0, "fish_kinds": [], "oven_recipes": 0,
			"regular_visits": {}, "events": {}}}


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
## Errand tables (forage nodes, catches) seed off the same morning.
func new_day() -> void:
	var st := site_state()
	st["weather"] = _roll_weather()
	st["assignments"] = {}
	st["guests"] = {}
	st["fish_taken"] = {}
	bought_today = []
	st["forage_nodes"] = _roll_forage()
	dog["pet_today"] = false
	if dog["met"]:
		_dog_dig()                               # §9: 1 bonus item/day
	if site_id == &"pinewatch" and site_day() == 1:
		journal_event("fire_lit")                # §8.1 P1: day-1 tutorial
	st["board"] = Seating.board(site_row(),
		Catalog.data.get("archetypes", []), site_day(), _open_pads(st),
		rating(), _rng_for("board"), _has_free_pair(st),
		_favourite_pool())
	_inject_regulars(st)
	if st["board"].any(func(b): return b.get("archetype") == "family") \
			or int(st["counters"]["families"]) > 0:
		st["counters"]["events"]["family_booked"] = true
	_deliver_letter(st)
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
	var kinds := _trait_kinds()
	return {"layout": Catalog.data.get("layouts", {}).get(site_id, {}),
		"campfire": st["campfire"], "decor": st["decor"],
		"pads": st["pads"], "occupants": occ,
		"guests": st["guests"], "weather": st["weather"],
		"trait_kinds": kinds,
		"comments": Catalog.data.get("reviews", {}),
		"day": site_day()}


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
	var cnt: Dictionary = st["counters"]
	var night := {"five_stars": 0, "stargazer_five": 0, "pads_filled": 0}
	var tags: Dictionary = Catalog.data.get("layouts", {}).get(
		site_id, {}).get("pads", {}).get("tags", {})
	for s in seated:
		var r := Seating.resolve_guest(s["guest"], s["pad_ids"],
			_world(), int(plan["terms"].get(s["guest"]["id"], -1)))
		results.append(r)
		fees += r["fee"]
		tips += int(round(r["tip"]))
		st["reviews"].append(r["stars"])
		if s["guest"].get("elite", false) and r["stars"] == 5:
			elite5 = true                              # §5.6: +1 walk-in tomorrow
		# journal counters (§8.1)
		cnt["guests_welcomed"] += 1
		night["pads_filled"] += s["pad_ids"].size()
		var arch: String = s["guest"].get("archetype", "")
		if arch == "family":
			cnt["families"] += 1
		elif arch == "angler" and s["pad_ids"].any(
				func(pid): return "water" in tags.get(pid, [])):
			cnt["anglers_water"] += 1
		var regular: String = s["guest"].get("regular", "")
		if regular != "":
			cnt["regular_visits"][regular] = int(
				cnt["regular_visits"].get(regular, 0)) + 1
		if r["stars"] == 5:
			night["five_stars"] += 1
			if "stargazer" in s["guest"].get("traits", []):
				night["stargazer_five"] = 1
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
	if not dog["met"] and site_id == &"pinewatch" and site_day() == 1:
		dog["met"] = true                          # §9: night-1 stray
	if dog["met"]:
		dog["bond"] += int(_dog_cfg().get("bond_leftover", 1)) \
			* (leftover.size() - sold.size())
	st["blogger_bonus"] = elite5
	var vig := _pick_vignette(st, seated)
	st["assignments"] = {}
	st["guests"] = {}
	meals.clear()                                    # leftovers to the dog
	coins += fees + tips + meal_sales
	var pages := _check_pages(night)
	set_phase(Phase.NIGHT)
	var best := {}
	for r in results:
		if best.is_empty() or int(r["stars"]) > int(best["stars"]):
			best = {"id": r["id"], "stars": r["stars"],
				"comment": r["comment"]}
	return {"results": results, "fees": fees, "tips": tips,
		"walk_ins": sold.size(), "meal_sales": meal_sales,
		"income": fees + tips + meal_sales, "rating": rating(),
		"pages": pages.map(func(p): return int(p["n"])),
		"best": best, "vignette": vig}


## §13.4: one vignette per night. A crew-restoration scene preempts
## everything on the first night at that site; otherwise unseen
## triggers play first and the one matching the most guests wins.
func _pick_vignette(st: Dictionary, seated: Array) -> String:
	var rows: Array = Catalog.data.get("vignettes", [])
	var restored: String = st.get("vignette_restored", "")
	if restored != "":
		st["vignette_restored"] = ""
		for v in rows:
			if v.get("trigger", {}).get("crew_restored") == restored:
				vignettes_seen.append(v["id"])
				return v["id"]
	var world := _world()
	var spots: Dictionary = world["layout"]["pads"]["spots"]
	var best_id := ""
	var best_weight := -1
	for v in rows:
		var tr: Dictionary = v.get("trigger", {})
		if tr.has("crew_restored"):
			continue
		var w := _vignette_weight(tr, seated, st, world, spots)
		if w < 0:
			continue                                   # not eligible
		# unseen first; then the trigger matching the most guests
		var key := w if v["id"] not in vignettes_seen else w - 100
		if key > best_weight:
			best_weight = key
			best_id = v["id"]
	if best_id != "":
		vignettes_seen.append(best_id)
	return best_id


## -1 = ineligible; otherwise how many seated guests match the
## trigger (the tiebreak §13.4 wants).
func _vignette_weight(tr: Dictionary, seated: Array, st: Dictionary,
		world: Dictionary, spots: Dictionary) -> int:
	var meal_ids: Array = meals.map(func(m): return m["id"])
	var n := 0
	for s in seated:
		var g: Dictionary = s["guest"]
		var ok := true
		if tr.has("trait"):
			ok = ok and tr["trait"] in g.get("traits", [])
		if tr.has("archetype"):
			ok = ok and g.get("archetype") == tr["archetype"]
		if tr.has("regular"):
			ok = ok and g.get("regular", "") == tr["regular"]
		if tr.has("effect"):
			var hit := false
			for pid in s["pad_ids"]:
				var cell := Vector2i(spots[pid][0], spots[pid][1])
				if Seating.effects_at(cell, world).has(tr["effect"]):
					hit = true
			ok = ok and hit
		if ok:
			n += 1
	if tr.has("trait") or tr.has("archetype") or tr.has("regular") \
			or tr.has("effect"):
		if n == 0:
			return -1
	if tr.has("decor"):
		if not st["decor"].any(func(d): return d["id"] == tr["decor"]):
			return -1
	if tr.has("weather") and st["weather"] != tr["weather"]:
		return -1
	if tr.has("meal") and tr["meal"] not in meal_ids:
		return -1
	var dm: Dictionary = tr.get("decor_effect_min", {})
	if dm:
		var count := 0
		for d in st["decor"]:
			if d.get("effect") == dm["effect"]:
				count += 1
		if count < int(dm.get("n", 1)):
			return -1
	return maxi(n, 1)


# ------------------------------------------------------------- journal (§8)
#
# Each site's chapter holds five pages; a page's "check" is evaluated
# against that site's counters plus whatever happened tonight. Pages
# complete in any order, pay their gift, and register their unlocks.

func _chapter(site := site_id) -> Dictionary:
	for c in Catalog.data.get("chapters", []):
		if c.get("id") == site:
			return c
	return {}


## Evaluate one page check. `night` carries same-night metrics
## (five_stars, pads_filled, stargazer_five) from Goodnight.
func _goal_met(check: Dictionary, st: Dictionary,
		night: Dictionary) -> bool:
	var cnt: Dictionary = st["counters"]
	if check.has("event"):
		return cnt["events"].has(check["event"])
	if check.has("night"):
		return int(night.get(check["night"], 0)) >= int(check["target"])
	var metric: String = check.get("metric", "")
	var target := int(check.get("target", 1))
	match metric:
		"rating":
			return st["reviews"].size() >= 15 \
				and rating() >= float(check["target"])
		"recipes":
			return recipes_cooked.size() >= target
		"fish_kinds":
			return cnt["fish_kinds"].size() >= target
		_:
			if metric.begins_with("regular_visits:"):
				return int(cnt["regular_visits"].get(
					metric.get_slice(":", 1), 0)) >= target
			return int(cnt.get(metric, 0)) >= target


## External events (tutorial steps, scripted moments) — e.g.
## journal_event("fire_lit") when the player relights the campfire.
func journal_event(name: String) -> void:
	site_state()["counters"]["events"][name] = true
	_check_pages()


func _bump(metric: String, n := 1) -> void:
	var cnt: Dictionary = site_state()["counters"]
	cnt[metric] = int(cnt.get(metric, 0)) + n


## Complete every met-but-undone page for the current site; returns
## the pages finished this call so the report/UI can celebrate them.
func _check_pages(night := {}) -> Array:
	var st := site_state()
	var done := []
	for page in _chapter().get("pages", []):
		var n := int(page["n"])
		if n in st["pages_done"]:
			continue
		if not _goal_met(page.get("check", {}), st, night):
			continue
		st["pages_done"].append(n)
		coins += int(page.get("gift", 0))
		page_completed.emit(site_id, n, int(page.get("gift", 0)),
			page.get("unlocks", []))
		done.append(page)
	return done


func page_done(page: int, site := site_id) -> bool:
	return page in site_state(site)["pages_done"]


## A chapter finishes when all five pages are stamped — it opens the
## next site (§8.1).
func chapter_done(site: StringName) -> bool:
	return site_state(site)["pages_done"].size() >= 5


## Unlock strings: "P3" = Pinewatch page 3, "W0" = Whisper River
## arrival (chapter 1 done), "W2" = its page 2, "L0" = chapter 2 done.
func _is_unlocked(unlock: String) -> bool:
	if unlock == "":
		return true
	if unlock.begins_with("S:"):
		return _story_done(unlock.get_slice(":", 1))
	var letter_sites := {"P": &"pinewatch", "W": &"whisper_river",
		"L": &"lantern_valley"}
	var site: StringName = letter_sites[unlock.left(1)]
	var n := int(unlock.substr(1))
	if n == 0:                                   # "arrival" unlocks
		match site:
			&"pinewatch": return true
			&"whisper_river": return chapter_done(&"pinewatch")
			&"lantern_valley": return chapter_done(&"whisper_river")
	return n in site_state(site)["pages_done"]


func site_reachable(site: StringName) -> bool:
	match site:
		&"pinewatch": return true
		&"whisper_river": return chapter_done(&"pinewatch")
		&"lantern_valley": return chapter_done(&"whisper_river")
	return false


## §12.3: a regular's story ends after story_visits seated stays —
## it unlocks the story gift (Hùng's Scout Pennant).
func _story_done(reg_id: String) -> bool:
	for reg: Dictionary in Catalog.data.get("regulars", []):
		if reg.get("id") == reg_id:
			var cnt: Dictionary = site_state(reg.get("site"))["counters"]
			return int(cnt["regular_visits"].get(reg_id, 0)) \
				>= int(reg.get("story_visits", 3))
	return false


# --- purchases (§6.1: one currency, no debt, refund until Goodnight) ---

func buy_decor(item_id: String, cells: Array) -> bool:
	var row := _row("decor", item_id)
	var st := site_state()
	if row.is_empty() or coins < int(row.get("price", 0)) \
			or not _is_unlocked(row.get("unlock", "")):
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
	var need := "P2" if shelter == "platform" else "W0"
	if not st["pads"].get(pad_id, {}).get("open", false) \
			or price <= 0 or coins < price or not _is_unlocked(need):
		return false
	coins -= price
	st["pads"][pad_id]["shelter"] = shelter
	return true


func buy_gear(item_id: String) -> bool:
	var row := _row("gear", item_id)
	if row.is_empty() or item_id in gear or coins < int(row.get("price", 0)) \
			or not _is_unlocked(row.get("unlock", "")):
		return false
	coins -= int(row["price"])
	gear.append(item_id)
	return true


## Staples are global, 5 coins each, gated by the site's staples
## unlock rank (P1 < W0 < L0 — §6.7).
func buy_staple(item_id: String) -> bool:
	var row := _row("ingredients", item_id)
	if row.get("kind") != "staple" or coins < int(row.get("price", 5)):
		return false
	if not _is_unlocked(row.get("unlock", "P1")):
		return false
	if pantry_add(item_id, 1) < 1:
		return false                                   # pantry full
	coins -= int(row.get("price", 5))
	return true


# ------------------------------------------------------------- kitchen (§7)

const PANTRY_BASE := 20
const PANTRY_COOLER := 30
const SITE_RANKS := {"pinewatch": 0, "whisper_river": 1,
	"lantern_valley": 2}


func _site_rank(site := site_id) -> int:
	return SITE_RANKS.get(site, 0)


func _unlock_rank(unlock: String) -> int:
	if unlock.begins_with("P"):
		return 0
	if unlock.begins_with("W"):
		return 1
	return 2


func pantry_count() -> int:
	var n := 0
	for k in pantry:
		n += int(pantry[k])
	return n


func pantry_capacity() -> int:
	return PANTRY_COOLER if "cooler" in gear else PANTRY_BASE


## Returns how many actually fit (§7.4: nodes keep what's left over).
func pantry_add(item_id: String, n := 1) -> int:
	var room := pantry_capacity() - pantry_count()
	var take := mini(n, room)
	if take > 0:
		pantry[item_id] = int(pantry.get(item_id, 0)) + take
	return take


func _ingredients_of_kind(kind: String, site := site_id) -> Array:
	var out := []
	for i in Catalog.data.get("ingredients", []):
		if i.get("kind") == kind and site in i.get("sites", []):
			out.append(i)
	return out


## §7.1: six seeded nodes a day, two items each, positions and
## contents rolled fresh each morning; Goldcap about one day in three.
func _roll_forage() -> Array:
	var pool := _ingredients_of_kind("forage")
	var rng := _rng_for("forage")
	var fpx: Array = Catalog.data.get("layouts", {}).get(
		site_id, {}).get("errand_spots", {}).get("forage", [96, 72])
	var nodes := []
	var goldcap_day := rng.randf() < 1.0 / 3.0 \
		and pool.any(func(i): return i.get("rare", false))
	var goldcap_slot := rng.randi() % 6
	for i in 6:
		var items := []
		for j in 2:
			items.append(_pick_weighted(pool, rng,
				func(i2): return i2.get("rare", false)))
		if goldcap_day and i == goldcap_slot:
			items[0] = "goldcap"
		nodes.append({"id": "f%d" % i, "items": items,
			"px": [fpx[0] + rng.randi_range(-72, 72),
				fpx[1] + rng.randi_range(-28, 28)]})
	return nodes


func _pick_weighted(pool: Array, rng: RandomNumberGenerator,
		skip: Callable = Callable()) -> String:
	var usable := pool
	if skip.is_valid():
		usable = pool.filter(func(i): return not skip.call(i))
	var total := 0.0
	for i in usable:
		total += float(i.get("weight", 1))
	var roll := rng.randf() * total
	for i in usable:
		roll -= float(i.get("weight", 1))
		if roll <= 0.0:
			return i["id"]
	return usable.back()["id"] if not usable.is_empty() else ""


## §7.1: gather a node — items land in the pantry until it's full;
## the node keeps whatever didn't fit.
func gather(node_id: String) -> Array:
	var st := site_state()
	var got := []
	for node in st["forage_nodes"]:
		if node["id"] != node_id:
			continue
		var left := []
		for item in node["items"]:
			if pantry_add(item, 1) > 0:
				got.append(item)
			else:
				left.append(item)
		node["items"] = left
	return got


## §7.2: 3 catches per spot per day, +1 in rain; needs the rod.
func fish_catch(spot: String) -> String:
	if "fishing_rod" not in gear:
		return ""
	var st := site_state()
	var limit := 3 + (1 if st["weather"] == "rain" else 0)
	var taken := int(st["fish_taken"].get(spot, 0))
	if taken >= limit:
		return ""
	var rng := _rng_for("fish_" + spot)
	var kinds := _ingredients_of_kind("fish")
	var pick := ""
	for i in taken + 1:
		pick = kinds[rng.randi() % kinds.size()]["id"] if kinds else ""
	st["fish_taken"][spot] = taken + 1
	if pantry_add(pick, 1) == 0:
		st["fish_taken"][spot] = taken               # full pantry: no catch
		return ""
	var logged: Array = st["counters"]["fish_kinds"]
	if pick not in logged:
		logged.append(pick)
		_check_pages()                               # e.g. W1 "3 kinds"
	return pick


## §7.3: the lookout, once per site day, needs the Binoculars —
## logs one bird not yet in Field Notes and reveals a bonus forage
## node. All birds logged → the node still appears.
func can_spot() -> bool:
	return "binoculars" in gear \
		and site_state()["spot_day"] != site_day()


func spot() -> Dictionary:
	if not can_spot():
		return {}
	var st := site_state()
	st["spot_day"] = site_day()
	var rng := _rng_for("bird")
	var unlogged: Array = Catalog.data.get("birds", []).filter(
		func(b): return b.get("site") == site_id \
			and b["id"] not in field_notes)
	var bird := {}
	if not unlogged.is_empty():
		bird = unlogged[rng.randi() % unlogged.size()]
		field_notes.append(bird["id"])
	var fpx: Array = site_row().get("errand_spots", {}).get(
		"forage", [96, 72])
	var pool := _ingredients_of_kind("forage")
	var items := []
	for i in 2:
		items.append(_pick_weighted(pool, rng,
			func(i2): return i2.get("rare", false)))
	st["forage_nodes"].append({"id": "fb", "items": items,
		"bonus": true,
		"px": [fpx[0] + rng.randi_range(-72, 72),
			fpx[1] + rng.randi_range(-28, 28)]})
	return {"bird": bird,
		"all_logged": _site_bird_count() <= field_notes.filter(
			func(b): return _bird_site(b) == site_id).size()}


func _bird_site(bird_id: String) -> String:
	return String(_row("birds", bird_id).get("site", ""))


func _site_bird_count() -> int:
	return Catalog.data.get("birds", []).filter(
		func(b): return b.get("site") == site_id).size()


## Recipes a guest could plausibly crave at this site (§5.2 card):
## every ingredient obtainable here, oven recipes only once Lantern
## Valley makes them possible.
func _favourite_pool(site := site_id) -> Array:
	var rank := _site_rank(site)
	var fish := _ingredients_of_kind("fish", site)
	var out := []
	for r in Catalog.data.get("recipes", []):
		if r.get("fallback", false):
			continue
		if r.get("station") == "oven" and rank < 2:
			continue
		var ok := true
		for ing in r.get("pair", []):
			if ing == "any_fish":
				ok = ok and not fish.is_empty()
			else:
				var row := _row("ingredients", ing)
				if row.get("kind") == "staple":
					ok = ok and _unlock_rank(
						row.get("unlock", "P1")) <= rank
				else:
					ok = ok and site in row.get("sites", [])
			if not ok:
				break
		if ok:
			out.append(r["id"])
	return out


func _slot(want: String, have_id: String) -> bool:
	return want == have_id or (want == "any_fish" \
		and _row("ingredients", have_id).get("kind") == "fish")


func _match_recipe(a: String, b: String) -> Dictionary:
	for r in Catalog.data.get("recipes", []):
		var pair: Array = r.get("pair", [])
		if pair.size() != 2:
			continue
		if (_slot(pair[0], a) and _slot(pair[1], b)) \
				or (_slot(pair[0], b) and _slot(pair[1], a)):
			return r
	return {}


## §7.5: pick two ingredients, cook one portion. A known pair → that
## meal; an oven pair at the campfire → hint, ingredients kept; an
## unknown pair → Camp Mash.
func cook(a: String, b: String) -> Dictionary:
	var need := {}
	for x in [a, b]:
		need[x] = int(need.get(x, 0)) + 1
	for x in need:
		if int(pantry.get(x, 0)) < need[x]:
			return {"result": "missing", "missing": x}
	var key := "+".join([a, b] if a < b else [b, a])
	var r := _match_recipe(a, b)
	if r.is_empty():
		r = _row("recipes", "camp_mash")
		pairs_tried[key] = "camp_mash"
	elif r.get("station") == "oven" and "oven" not in gear:
		pairs_tried[key] = "oven_hint"
		return {"result": "oven_hint",
			"hint": "%s needs the Camp Oven" % r.get("name", "?")}
	else:
		pairs_tried[key] = r["id"]
	for x in need:
		pantry[x] -= need[x]
		if pantry[x] <= 0:
			pantry.erase(x)
	var meal := {"id": r["id"], "price": int(r.get("price", 5))}
	meals.append(meal)
	if r["id"] not in recipes_cooked:
		recipes_cooked.append(r["id"])
	if r.get("station") == "oven":
		_bump("oven_recipes")
	_check_pages()                                   # e.g. P3 "5 recipes"
	return {"result": "ok", "recipe": r["id"], "meal": meal,
		"name": r.get("name", "")}


# ------------------------------------------------------------- the dog (§9)
#
# A stray who turns up on Pinewatch's first night. No needs, no
# penalties, never lost; its guest effect only ever comes from the
# Dog Bed decor item, so wandering never touches scoring.

func _dog_cfg() -> Dictionary:
	return Catalog.data.get("dog", {})


## Seeded bonus forage each morning — straight into the pantry; a
## full pantry means the dog buries it for later (no item).
func _dog_dig() -> void:
	var pool := _ingredients_of_kind("forage")
	if pool.is_empty():
		return
	var rng := _rng_for("dog")
	var pick: Dictionary = pool[rng.randi() % pool.size()]
	pantry_add(pick["id"], 1)


## One pet per day, +bond per dog.json. Returns false once petted.
func dog_pet() -> bool:
	if not dog["met"] or dog["pet_today"]:
		return false
	dog["pet_today"] = true
	dog["bond"] += int(_dog_cfg().get("bond_pet", 2))
	return true


func name_dog(n: String) -> void:
	if n.strip_edges() != "":
		dog["name"] = n


## Bond level 0-4 from the thresholds in dog.json; each level
## unlocks a cosmetic trick, the last is the đá cầu chase (§9).
func dog_level() -> int:
	var lvl := 0
	var levels: Array = _dog_cfg().get("levels", [])
	for i in levels.size():
		if dog["bond"] >= int(levels[i].get("bond", 0)):
			lvl = i
	return lvl


func dog_trick() -> String:
	var levels: Array = _dog_cfg().get("levels", [])
	if levels.is_empty():
		return ""
	return String(levels[dog_level()].get("trick", ""))


## Is the Dog Bed placed here? (The dog sleeps on it — §9 — but the
## guest effect already flows through the decor, nothing to score.)
func dog_bed_placed() -> bool:
	return site_state()["decor"].any(
		func(d): return d["id"] == "dog_bed")


# ------------------------------------------------------------- Daily (§10)
#
# One shared puzzle per calendar day, seeded by hash("daily", date).
# One scored attempt; unlimited practice afterwards. Unlocks with
# Pinewatch letter 6 (p06).

const DAILY_EPOCH := "2025-01-01"

var daily_state := {"date": "", "score": -1}      # last scored attempt


func daily_unlocked() -> bool:
	return "p06" in site_state(&"pinewatch")["letters_delivered"]


func _daily_date(date_str := "") -> String:
	return date_str if date_str != "" \
		else Time.get_date_string_from_system()


func daily_n(date_str: String) -> int:
	var a := Time.get_unix_time_from_datetime_string(
		DAILY_EPOCH + "T00:00:00")
	var b := Time.get_unix_time_from_datetime_string(
		date_str + "T00:00:00")
	return int((b - a) / 86400.0)


## The seeded puzzle for a date — deterministic, so a reload shows
## the same cards, kit and meals.
func daily(date_str := "") -> Dictionary:
	var d := _daily_date(date_str)
	var pz := _daily_gen(d, _daily_tries(d))
	pz["date"] = d
	pz["n"] = daily_n(d)
	pz["attempted"] = daily_state["date"] == d \
		and daily_state["score"] >= 0
	return pz


## Deterministic reroll chain (§10): attempt k>0 uses seed
## "daily|date|rk". The CI solver (tests/daily_check) bakes the
## accepted try count into data/daily_seeds.json; dates beyond the
## table fall back to the raw seed.
func _daily_seed(d: String, tries: int) -> int:
	var s := "daily|" + d
	if tries > 0:
		s += "|r%d" % tries
	return absi(int(s.hash()))


func _daily_tries(d: String) -> int:
	return int(Catalog.data.get("daily_seeds", {}).get(
		"seeds", {}).get(d, 0))


func _daily_gen(d: String, tries: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = _daily_seed(d, tries)
	var skip := ["seats", "warmth_upgrade", "none"]
	var kit_pool: Array = Catalog.data.get("decor", []).filter(
		func(x): return String(x.get("unlock", "")).begins_with("P") \
			and x.get("effect") not in skip)
	return Seating.daily_puzzle(site_row(&"pinewatch"),
		Catalog.data.get("archetypes", []), kit_pool,
		_favourite_pool(&"pinewatch"), rng)


func _trait_kinds() -> Dictionary:
	var kinds := {}
	for t in Catalog.data.get("traits", []):
		kinds[t["id"]] = t.get("kind", "need")
	return kinds


## Score an attempt. assignments: {guest_id: [pad_ids]};
## placements: {kit_item_id: [Vector2i cells]}. submit=true records
## the score if today's attempt is unused (§10 one scored attempt).
func daily_score(puzzle: Dictionary, assignments: Dictionary,
		placements: Dictionary, submit := false) -> Dictionary:
	var kit_rows := {}
	for k in puzzle["kit"]:
		kit_rows[k["id"]] = k
	var decor_items := []
	for iid in placements:
		var row: Dictionary = kit_rows.get(iid, {})
		decor_items.append({"id": iid, "cells": placements[iid],
			"effect": row.get("effect", ""),
			"reach": int(row.get("reach", 1))})
	var guests := {}
	var occupants := {}
	var seated := []
	for r in puzzle["requests"]:
		guests[r["id"]] = r
	for gid in assignments:
		if gid not in guests:
			continue
		for pid in assignments[gid]:
			occupants[pid] = gid
		seated.append({"guest": guests[gid],
			"pad_ids": assignments[gid]})
	var kinds := _trait_kinds()
	var world := Seating.daily_world(puzzle, decor_items, occupants,
		guests, kinds, Catalog.data.get("reviews", {}))
	var plan := Seating.allocate_meals(puzzle["meals"], seated)
	var results := []
	var total := 0
	for s in seated:
		var rr := Seating.resolve_guest(s["guest"], s["pad_ids"],
			world, int(plan["terms"].get(s["guest"]["id"], -1)))
		results.append(rr)
		total += rr["stars"]
	if submit and puzzle.get("date") == _daily_date() \
			and daily_state["date"] != puzzle.get("date"):
		daily_state = {"date": puzzle["date"], "score": total}
	return {"score": total, "results": results,
		"share": daily_share(puzzle, results)}


func daily_share(puzzle: Dictionary, results: Array) -> String:
	var row := ""
	for r in results:
		row += "★".repeat(int(r["stars"])) + " "
	return "Trailbound Daily #%d — %d/25\n%s" % [
		int(puzzle.get("n", 0)), int(
			results.reduce(func(a, x): return a + x["stars"], 0)),
		row.strip_edges()]


# ------------------------------------------------------------- save (§22)

func state_dict() -> Dictionary:
	crew_tick()
	return {"day": day, "site": String(site_id), "phase": phase,
		"sites_visited": sites_visited, "crew": crew.duplicate(true),
		"coins": coins, "seed": seed, "meals": meals.duplicate(true),
		"pantry": pantry.duplicate(), "gear": gear.duplicate(),
		"recipes": recipes_cooked.duplicate(),
		"pairs_tried": pairs_tried.duplicate(),
		"letters": letters_read.duplicate(),
		"journal": {"vignettes_seen": vignettes_seen.duplicate()},
		"daily": daily_state.duplicate(),
		"dog": dog.duplicate(),
		"field_notes": field_notes.duplicate(),
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
	pantry = state.get("pantry", pantry)
	gear = state.get("gear", gear)
	recipes_cooked = state.get("recipes", recipes_cooked)
	pairs_tried = state.get("pairs_tried", pairs_tried)
	letters_read = state.get("letters", letters_read)
	vignettes_seen = state.get("journal", {}).get(
		"vignettes_seen", vignettes_seen)
	daily_state = state.get("daily", daily_state)
	dog = state.get("dog", dog)
	field_notes = state.get("field_notes", field_notes)
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
