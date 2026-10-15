extends "res://tests/harness.gd"
## Seeded verb fuzz — property-test layer over the whole public API.
## Drives random verb sequences (seat/serve/buy/pantry/cook/day-cycle/
## save-reload) against a live campaign and asserts the invariants any
## UI or agent bug would break: no crash, coins never negative, every
## assignment names a real guest on a real open pad, state_dict always
## JSON-round-trips, and a fixed seed replays bit-identical.
## Run: godot --headless --path game tests/test_fuzz.tscn

const SEEDS := [42, 137, 2024, 7777]
const STEPS := 60

var rng := RandomNumberGenerator.new()
var gid_n := 0


func _ready() -> void:
	print("=== verb fuzz (seeded property run) ===")
	var hashes := {}
	for seed in SEEDS:
		var h := _run(seed)
		check("seed %d completes" % seed, h != 0)
		hashes[seed] = h
	# same seed after the others => identical terminal state
	check("seed %d replays identical" % SEEDS[0],
		_run(SEEDS[0]) == hashes[SEEDS[0]])
	# leave a neutral save behind for the next suite
	Game.load_state(Save.default_state())
	Save.save_state(Game.state_dict())
	finish()


func _run(seed: int) -> int:
	Game.load_state(Save.default_state())
	Game.coins = 500
	gid_n = 0
	rng.seed = seed
	for step in STEPS:
		if step % 5 == 4:
			check("seed %d step %d undo round-trip" % [seed, step],
				_undo_roundtrip())
		else:
			_verb(rng.randi() % 19)
		if not _invariants(seed, step):
			return 0
	return JSON.stringify(_stable(Game.state_dict())).hash()


## Stronger property than "doesn't crash": a verb that records an
## inverse must restore the pre-verb state exactly when undone —
## modulo day_log, the event stream where undo itself is history.
func _undo_roundtrip() -> bool:
	var log_before := Game.action_log.size()
	# pick a verb that records an inverse when it succeeds; s0 is
	# taken after any non-verb setup (inject), right before the verb
	var s0 := {}
	var st: Dictionary = Game.site_state()
	var seated: Array = st["assignments"].keys()
	var rows: Array = Catalog.data["decor"]
	var cells := Game.decor_cells_free()
	match rng.randi() % 5:
		0: # seat a fresh guest
			var gid := "u%d" % gid_n
			gid_n += 1
			_inject(gid, "solo", [], false)
			var open := _open_pads()
			s0 = _snapshot()
			if not open.is_empty():
				Game.seat(gid, [open[rng.randi() % open.size()]])
		1: # serve a seated guest
			if seated.is_empty():
				return true
			s0 = _snapshot()
			var m: Array = Catalog.data["recipes"]
			Game.serve_meal(seated[rng.randi() % seated.size()],
				String(m[rng.randi() % m.size()]["id"]))
		2: # buy a decor row
			if cells.is_empty():
				return true
			s0 = _snapshot()
			var row: Dictionary = rows[rng.randi() % rows.size()]
			Game.buy_decor(String(row["id"]),
				[cells[rng.randi() % cells.size()]])
		3: # a care gesture — both undoable until Goodnight
			Game.set_phase(Game.Phase.EVENING)
			s0 = _snapshot()
			if rng.randi() % 2 == 0 or seated.is_empty():
				Game.stoke_fire()
			else:
				Game.tuck_in(String(seated[rng.randi() % seated.size()]))
		4: # re-skin a placed piece (variant inverse restores prev tag)
			var cand := []
			for i in st["decor"].size():
				for r2 in rows:
					if String(r2["id"]) == String(st["decor"][i]["id"]) \
							and not r2.get("variants", {}).is_empty():
						cand.append([i, r2])
						break
			if cand.is_empty():
				return true
			var pick2 = cand[rng.randi() % cand.size()]
			var vnames: Array = pick2[1]["variants"].keys()
			s0 = _snapshot()
			Game.buy_decor_variant(pick2[0],
				String(vnames[rng.randi() % vnames.size()]))
	if Game.action_log.size() <= log_before:
		return true                      # refused or not undoable
	Game.undo()
	return JSON.stringify(s0) == JSON.stringify(_snapshot())


func _snapshot() -> Dictionary:
	var s: Dictionary = _stable(Game.state_dict())
	s.erase("day_log")
	return s


## Clock-bearing fields change between identical runs (crew_tick reads
## unix time; ads store last-shown stamps). Strip them before hashing so
## the replay check asserts *gameplay* determinism, not the wall clock.
func _stable(state: Dictionary) -> Dictionary:
	var s: Dictionary = state.duplicate(true)
	s.erase("crew")
	s.erase("ads")
	return s


func _invariants(seed: int, step: int) -> bool:
	var ok := Game.coins >= 0
	var st: Dictionary = Game.site_state()
	for gid in st["assignments"]:
		ok = ok and st["guests"].has(gid)
		var seen := {}
		for pid in st["assignments"][gid]:
			ok = ok and st["pads"].has(pid) \
				and not seen.has(pid)
			seen[pid] = true
	ok = ok and int(Game.state_dict()["day"]) >= 0
	ok = ok and JSON.parse_string(
		JSON.stringify(Game.state_dict())) != null
	check("seed %d step %d invariants" % [seed, step], ok)
	return ok


func _verb(v: int) -> void:
	var st: Dictionary = Game.site_state()
	var seated: Array = st["assignments"].keys()
	match v:
		0: # seat a fresh guest on a random open pad
			var gid := "f%d" % gid_n
			gid_n += 1
			_inject(gid, "solo", [], false)
			var open := _open_pads()
			if not open.is_empty():
				Game.seat(gid, [open[rng.randi() % open.size()]])
		1: # unseat a random seated guest
			if not seated.is_empty():
				Game.unseat(seated[rng.randi() % seated.size()])
		2: # serve a random meal to a random seated guest
			if not seated.is_empty():
				var m: Array = Catalog.data["recipes"]
				Game.serve_meal(seated[rng.randi() % seated.size()],
					String(m[rng.randi() % m.size()]["id"]))
		3: # unserve
			if not seated.is_empty():
				Game.unserve(seated[rng.randi() % seated.size()])
		4: # buy a random decor row onto free cells (may refuse)
			var rows: Array = Catalog.data["decor"]
			var row: Dictionary = rows[rng.randi() % rows.size()]
			var cells := Game.decor_cells_free()
			if not cells.is_empty():
				Game.buy_decor(String(row["id"]),
					[cells[rng.randi() % cells.size()]])
		5:
			Game.undo()
		6: # pantry shuffle
			var ings: Array = Catalog.data["ingredients"]
			var ing := String(ings[rng.randi() % ings.size()]["id"])
			if rng.randi() % 2 == 0:
				Game.pantry_add(ing, 1 + rng.randi() % 3)
			else:
				Game.pantry_remove(ing, 1)
		7: # cook a random pantry pair (may be a dud recipe)
			var pantry: Dictionary = Game.pantry
			var have := pantry.keys()
			if have.size() >= 2:
				Game.cook(String(have[0]), String(have[1]))
		8: # save + reload mid-sequence
			Save.save_state(Game.state_dict())
			Game.load_state(Save.load_state())
		9: # full day cycle: resolve the night, then advance
			Game.set_phase(Game.Phase.EVENING)
			Game.goodnight()
			Game.new_day()
		10: # invalid ops must refuse cleanly, no corruption
			Game.seat("nobody", ["p1"])
			Game.serve_meal("nobody", "not_a_meal")
			Game.buy_decor("not_decor", [])
			Game.pantry_remove("not_an_ingredient", 5)
		11: # travel attempts (locked sites refuse)
			var sites: Array = Catalog.data["layouts"].keys()
			Game.travel_to(StringName(sites[rng.randi() % sites.size()]))
		12: # bird spotting (Field Notes)
			if Game.can_spot():
				Game.spot()
		13: # fish a known spot — fish_spots rows carry {"id","px"}
			var spts: Array = Game.fish_spots()
			if not spts.is_empty():
				Game.fish_catch(String(
					spts[rng.randi() % spts.size()]["id"]))
		14: # dog interaction (refuses pre-adoption — invalid path)
			Game.dog_pet()
		15: # care gestures — once-a-night, undoable, phase-gated
			if rng.randi() % 2 == 0:
				Game.stoke_fire()
			elif not seated.is_empty():
				Game.tuck_in(String(seated[rng.randi() % seated.size()]))
		16: # camera / fund / variant — gated verbs that may refuse
			match rng.randi() % 3:
				0:
					Game.take_photo()
				1:
					Game.donate_fund(25 + rng.randi() % 475)
				2:
					var dec: Array = st["decor"]
					if not dec.is_empty():
						var di := rng.randi() % dec.size()
						var row2 := {}
						for r2 in Catalog.data["decor"]:
							if String(r2["id"]) == String(dec[di]["id"]):
								row2 = r2
								break
						var vars: Array = row2.get("variants", {}).keys()
						if not vars.is_empty():
							Game.buy_decor_variant(di,
								String(vars[rng.randi() % vars.size()]))
		17: # invalid paths on the new verbs must refuse cleanly
			Game.take_photo()
			Game.donate_fund(-50)
			Game.donate_fund(999999)
			Game.tuck_in("ghost_guest")
			Game.buy_decor_variant(-1, "bogus")
			Game.buy_decor_variant(0, "bogus_variant")
		18: # margins + dog fetch — site/adoption gated once-a-day verbs
			Game.read_margin()
			Game.dog_fetch("forage" if rng.randi() % 2 == 0 else "fish")
			Game.dog_fetch("bogus_kind")


func _open_pads() -> Array:
	var st: Dictionary = Game.site_state()
	var occ := {}
	for gid in st["assignments"]:
		for pid in st["assignments"][gid]:
			occ[pid] = true
	var out := []
	for pid in st["pads"]:
		if st["pads"][pid].get("open", false) and not occ.has(pid):
			out.append(pid)
	return out
