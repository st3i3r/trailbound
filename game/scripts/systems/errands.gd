extends RefCounted
## Errands — §7.1 forage, §7.2 fishing, §7.3 spotting.
##
## Leaf subsystem owned by Game (see autoload/game.gd): holds no
## state of its own, mutates site/pantry state through `g`. Public
## API stays on Game as one-line delegates, so callers never see it.

var g  # the Game autoload (untyped: circular ref)


func _init(game) -> void:
	g = game


## §7.1: six seeded nodes per site day, a Goldcap ~1 day in 3.
func roll_forage() -> Array:
	var pool: Array = g._ingredients_of_kind("forage")
	var rng: RandomNumberGenerator = g._rng_for("forage")
	var fpx: Array = Catalog.data.get("layouts", {}).get(
		g.site_id, {}).get("errand_spots", {}).get("forage", [96, 72])
	var nodes := []
	var goldcap_day: bool = rng.randf() < 1.0 / 3.0 \
		and pool.any(func(i): return i.get("rare", false))
	var goldcap_slot: int = rng.randi() % 6
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
	var st: Dictionary = g.site_state()
	var got := []
	for node in st["forage_nodes"]:
		if node["id"] != node_id:
			continue
		var left := []
		for item in node["items"]:
			if g.pantry_add(item, 1) > 0:
				got.append(item)
			else:
				left.append(item)
		node["items"] = left
	return got


## §7.2: 3 catches per spot per day, +1 in rain; needs the rod.
func fish_catch(spot: String) -> String:
	if "fishing_rod" not in g.gear:
		return ""
	var st: Dictionary = g.site_state()
	var limit := 3 + (1 if st["weather"] == "rain" else 0)
	var taken := int(st["fish_taken"].get(spot, 0))
	if taken >= limit:
		return ""
	var rng: RandomNumberGenerator = g._rng_for("fish_" + spot)
	var kinds: Array = g._ingredients_of_kind("fish")
	var pick := ""
	for i in taken + 1:
		pick = kinds[rng.randi() % kinds.size()]["id"] if kinds else ""
	st["fish_taken"][spot] = taken + 1
	if g.pantry_add(pick, 1) == 0:
		st["fish_taken"][spot] = taken               # full pantry: no catch
		return ""
	var logged: Array = st["counters"]["fish_kinds"]
	if pick not in logged:
		logged.append(pick)
		g._check_pages()                             # e.g. W1 "3 kinds"
	return pick


## §7.3: the lookout, once per site day, needs the Binoculars —
## logs one bird not yet in Field Notes and reveals a bonus forage
## node. All birds logged → the node still appears.
func can_spot() -> bool:
	return "binoculars" in g.gear \
		and g.site_state()["spot_day"] != g.site_day()


func spot() -> Dictionary:
	if not can_spot():
		return {}
	var st: Dictionary = g.site_state()
	st["spot_day"] = g.site_day()
	var rng: RandomNumberGenerator = g._rng_for("bird")
	var unlogged: Array = Catalog.data.get("birds", []).filter(
		func(b): return b.get("site") == g.site_id \
			and b["id"] not in g.field_notes)
	var bird := {}
	if not unlogged.is_empty():
		bird = unlogged[rng.randi() % unlogged.size()]
		g.field_notes.append(bird["id"])
	var fpx: Array = g.site_row().get("errand_spots", {}).get(
		"forage", [96, 72])
	var pool: Array = g._ingredients_of_kind("forage")
	var items := []
	for i in 2:
		items.append(_pick_weighted(pool, rng,
			func(i2): return i2.get("rare", false)))
	st["forage_nodes"].append({"id": "fb", "items": items,
		"bonus": true,
		"px": [fpx[0] + rng.randi_range(-72, 72),
			fpx[1] + rng.randi_range(-28, 28)]})
	return {"bird": bird,
		"all_logged": _site_bird_count() <= g.field_notes.filter(
			func(b): return _bird_site(b) == g.site_id).size()}


func _bird_site(bird_id: String) -> String:
	return String(g._row("birds", bird_id).get("site", ""))


func _site_bird_count() -> int:
	return Catalog.data.get("birds", []).filter(
		func(b): return b.get("site") == g.site_id).size()
