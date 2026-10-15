extends RefCounted
## The dog (§9) — bond, tricks, the morning dig.
##
## Leaf subsystem owned by Game: the `dog` state dict stays on Game
## for the save schema; this object reads `g.dog` and mutates it.

var g  # the Game autoload (untyped: circular ref)


func _init(game) -> void:
	g = game


func _cfg() -> Dictionary:
	return Catalog.data.get("dog", {})


## Morning hook: reset the daily pet, then the bonus forage — a full
## pantry means the dog buries it for later (no item).
func morning() -> void:
	g.dog["pet_today"] = false
	if not g.dog["met"]:
		return
	var pool: Array = g._ingredients_of_kind("forage")
	if pool.is_empty():
		return
	var rng: RandomNumberGenerator = g._rng_for("dog")
	var pick: Dictionary = pool[rng.randi() % pool.size()]
	g.pantry_add(pick["id"], 1)


## Goodnight hook (§9): the stray appears on Pinewatch's first night
## and eats the leftovers the walk-ins didn't buy.
func eat(ate_count: int) -> void:
	if not g.dog["met"] and g.site_id == &"pinewatch" \
			and g.site_day() == 1:
		g.dog["met"] = true                      # §9: night-1 stray
	if g.dog["met"]:
		g.dog["bond"] += int(_cfg().get("bond_leftover", 1)) \
			* ate_count


## One pet per day, +bond per dog.json. Returns false once petted.
func pet() -> bool:
	if not g.dog["met"] or g.dog["pet_today"]:
		return false
	g.dog["pet_today"] = true
	g.dog["bond"] += int(_cfg().get("bond_pet", 2))
	return true


## §fetch: the directed half of the morning dig — you send him, he
## picks the pool. Forage anywhere; fish too (he swims, rod or no
## rod). Once a day, and only after he's decided the camp is home.
func can_fetch() -> bool:
	return bool(g.dog.get("adopted", false)) \
		and int(g.site_state().get("fetch_day", -1)) != g.site_day()


func fetch(kind: String) -> Dictionary:
	if kind not in ["forage", "fish"] or not can_fetch():
		return {}
	var pool: Array = g._ingredients_of_kind(kind)
	if pool.is_empty():
		return {}
	var st: Dictionary = g.site_state()
	st["fetch_day"] = g.site_day()
	var rng: RandomNumberGenerator = g._rng_for("fetch_" + kind)
	var pick: Dictionary = pool[rng.randi() % pool.size()]
	g.pantry_add(String(pick["id"]), 1)
	g.dog["bond"] += 1
	g._log("dog_fetch", {"kind": kind, "id": String(pick["id"])})
	Analytics.log_event(&"dog_fetch", {"kind": kind})
	g.touch()
	return {"id": String(pick["id"]),
		"name": String(pick.get("name", ""))}


func rename(n: String) -> void:
	if n.strip_edges() != "":
		g.dog["name"] = n


## Bond level 0-4 from the thresholds in dog.json; each level
## unlocks a cosmetic trick, the last is the đá cầu chase (§9).
func level() -> int:
	var lvl := 0
	var levels: Array = _cfg().get("levels", [])
	for i in levels.size():
		if g.dog["bond"] >= int(levels[i].get("bond", 0)):
			lvl = i
	return lvl


func trick() -> String:
	var levels: Array = _cfg().get("levels", [])
	if levels.is_empty():
		return ""
	return String(levels[level()].get("trick", ""))


## Is the Dog Bed placed here? (The dog sleeps on it — §9 — but the
## guest effect already flows through the decor, nothing to score.)
func bed_placed() -> bool:
	return g.site_state()["decor"].any(
		func(d): return d["id"] == "dog_bed")
