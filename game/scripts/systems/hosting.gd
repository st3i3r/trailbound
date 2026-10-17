extends RefCounted
## Hosting — per-site state container (§5). Leaf subsystem owned by Game (autoload/game.gd); holds no save state of its own (`sites`/`sites_visited` stay on Game for the save schema).
##
## Public API stays on Game as one-line delegates, so callers
## never move. All Game state is accessed via `g`.

var g  # the Game autoload (untyped: circular ref)


func _init(game) -> void:
	g = game


func visit_site(site: StringName) -> void:
	g.site_id = site
	if g.sites.has(site):
		_reconcile_map(site)             # lazy map-drift check on
		                                 # arrival — no-op when map_rev
		                                 # still matches the layout
	if site not in g.sites_visited:
		g.sites_visited[site] = g.day
		g._try_start_next()


## §8.2: the morning trail map. Gated by chapter completion; re-rolls
## the day at the chosen site so the board/weather are the new site's.


func travel_to(site: StringName) -> bool:
	if g.phase != g.Phase.MORNING \
			or not site_state()["assignments"].is_empty():
		return false                    # the trail map is a morning act (§8.2)
	if not g.site_reachable(site):
		return false
	visit_site(site)
	g._log("travel", {"to": String(site)})
	Analytics.log_event(&"site_unlock", {"site": String(site)})
	g.new_day()
	g.commit()
	return true


## §Wishes: the kinds tonight's camp can actually grant — the board never
## deals a wish the seating can't satisfy. Tags on open pads (with
## restoration grants already overlaid by _world), fire-ring and
## light coverage from effects_at, open sky on unsheltered pads, and
## `together` only while a free adjacent pair exists.


func site_day(site: StringName = g.site_id) -> int:
	return g.day - int(g.sites_visited.get(site, g.day)) + 1


func site_row(site: StringName = g.site_id) -> Dictionary:
	for s in Catalog.data.get("sites", []):
		if s.get("id") == site:
			return s
	return {}


## Trail-map card (display read — the verb is travel_to): everything a
## map row needs, derived from the same predicates the verb checks so
## the UI can never promise a trip the sim would refuse.


func site_card(site: StringName) -> Dictionary:
	var row: Dictionary = g.site_row(site)
	if row.is_empty():
		return {}
	var pages: Array = g.site_state(site)["pages_done"]
	var done: int = pages.filter(func(n): return int(n) <= 5).size()
	return {"id": site, "name": row.get("name", site),
		"chapter": int(row.get("chapter", 0)),
		"pages_done": done, "pages_total": 5,
		"current": site == g.site_id,
		"reachable": g.site_reachable(site),
		"visited": g.sites_visited.has(site)}


func site_order() -> Array:
	var rows: Array = Catalog.data.get("sites", [])
	rows = rows.duplicate()
	rows.sort_custom(func(a, b):
		return int(a.get("chapter", 0)) < int(b.get("chapter", 0)))
	return rows.map(func(r): return StringName(r["id"]))


func site_state(site: StringName = g.site_id) -> Dictionary:
	if site not in g.sites:
		g.sites[site] = _fresh_site(site)
	if not g.sites[site].has("served"):   # saves pre-dating dinner
		g.sites[site]["served"] = {}
	return g.sites[site]


func _fresh_site(site: StringName) -> Dictionary:
	var layout: Dictionary = Catalog.data.get("layouts", {}).get(site, {})
	var pads: Dictionary = {}
	var open: Array = layout.get("pads", {}).get("open", [])
	for pid in layout.get("pads", {}).get("spots", {}):
		pads[pid] = {"open": pid in open, "shelter": "bare"}
	var fire: Dictionary = layout.get("campfire",
		{"cell": [0, 0], "radius": 2})
	var fcell: Array = fire.get("cell", [0, 0])
	return {"pads": pads, "decor": [], "stored": [],
		"map_rev": String(layout.get("map_rev", "")),
		"campfire": {"cell": Vector2i(fcell[0], fcell[1]),
			"radius": int(fire.get("radius", 2))},
		"seats": 0, "reviews": [], "weather": "clear",
		"board": [], "guests": {}, "assignments": {}, "served": {},
		"blogger_bonus": false, "forage_nodes": [], "fish_taken": {},
		"fire_stoked": false, "tucked_in": "", "photos": [],
		"photo_day": -1, "margins_read": [], "margin_day": -1,
		"fetch_day": -1,
		"weather_streak": {"kind": "", "days": 0},
		"spot_day": -1,
		"pages_done": [], "letters_delivered": [],
		"vignette_restored": "",
		"restored": [], "pad_tags": {}, "walk_bonus": 0,
		"gathering_gifts": [],
		"counters": {"guests_welcomed": 0, "families": 0,
			"anglers_water": 0, "fish_kinds": [], "oven_recipes": 0,
			"gatherings_met": 0,
			"arch_visits": {},
			"regular_visits": {}, "events": {}}}


## §21.3: every stream is seeded by save + site + site day + stream
## name, so a reload always rebuilds the same morning.


func _reconcile_map(site: StringName) -> void:
	var st: Dictionary = g.sites[site]
	var layout: Dictionary = g._layout(site)
	var rev: String = String(layout.get("map_rev", ""))
	if rev == "" or String(st.get("map_rev", "")) == rev:
		return            # unstamped layout has no opinion / already ok
	if not st.has("stored"):
		st["stored"] = []
	var moved: Array = []
	for i in range(st.get("decor", []).size() - 1, -1, -1):
		var d: Dictionary = st["decor"][i]
		var row: Dictionary = g._row("decor", String(d.get("id", "")))
		if d.get("aura", false) or (not row.is_empty()
				and g._footprint_ok(row, d["cells"], i)):
			continue
		var kept: Dictionary = {"id": d["id"], "effect": d.get("effect", ""),
			"reach": int(d.get("reach", 1))}
		if d.get("variant", "") != "":
			kept["variant"] = d["variant"]
		st["stored"].append(kept)
		st["seats"] = maxi(0, int(st.get("seats", 0))
			- int(row.get("seats", 0)))
		st["decor"].remove_at(i)
		moved.append(d["id"])
		g._log("map_shift", {"site": site, "id": d["id"]})
	if not moved.is_empty():
		print("map reconcile %s: %d decor back to storage %s" % [
			site, moved.size(), moved])
	st["map_rev"] = rev

