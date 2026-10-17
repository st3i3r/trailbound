extends RefCounted
## Pantry — kitchen helpers (A§7.4). Leaf subsystem owned by Game (autoload/game.gd); holds no save state of its own (the `pantry` dict stays on Game for the save schema).
##
## Public API stays on Game as one-line delegates, so callers
## never move. All Game state is accessed via `g`.

var g  # the Game autoload (untyped: circular ref)


func _init(game) -> void:
	g = game


func pantry_count() -> int:
	var n := 0
	for k in g.pantry:
		n += int(g.pantry[k])
	return n


func pantry_capacity() -> int:
	return g.PANTRY_COOLER if "cooler" in g.gear else g.PANTRY_BASE


## Returns how many actually fit (§7.4: nodes keep what's left over).
func pantry_add(item_id: String, n := 1) -> int:
	var room: int = g.pantry_capacity() - g.pantry_count()
	var take: int = mini(n, room)
	if take > 0:
		g.pantry[item_id] = int(g.pantry.get(item_id, 0)) + take
	return take


## Inverse of pantry_add — used by refund inverses; returns how many
## came out (0 when the staple already went into a meal).
func pantry_remove(item_id: String, n := 1) -> int:
	var have := int(g.pantry.get(item_id, 0))
	var take: int = mini(n, have)
	if take > 0:
		g.pantry[item_id] = have - take
		if g.pantry[item_id] <= 0:
			g.pantry.erase(item_id)
	return take


func _ingredients_of_kind(kind: String, site: String = g.site_id) -> Array:
	var out: Array = []
	for i in Catalog.data.get("ingredients", []):
		if i.get("kind") == kind and site in i.get("sites", []):
			out.append(i)
	return out


## Errands delegates — §7.1–7.3 live in systems/errands.gd.


func _favourite_pool(site: String = g.site_id) -> Array:
	var rank: int = g._site_rank(site)
	var fish: Array = _ingredients_of_kind("fish", site)
	var out: Array = []
	for r in Catalog.data.get("recipes", []):
		if r.get("fallback", false) or r.has("festival"):
			continue                          # festival dishes are never craved
		if r.get("station") == "oven" and rank < 2:
			continue
		var ok: bool = true
		for ing in r.get("pair", []):
			if ing == "any_fish":
				ok = ok and not fish.is_empty()
			else:
				var row: Dictionary = g._row("ingredients", ing)
				if row.get("kind") == "staple":
					ok = ok and g._unlock_rank(
						row.get("unlock", "P1")) <= rank
				else:
					ok = ok and site in row.get("sites", [])
			if not ok:
				break
		if ok:
			out.append(r["id"])
	return out

