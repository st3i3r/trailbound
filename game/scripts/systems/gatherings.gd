extends RefCounted
## Gatherings (§33.3) — from Volume II the board may offer one
## Gathering a night: 3–5 parties booked together under one brief.
## Meeting it pays +25% of the Gathering's fees (§6.11), counts for
## page 8, and the first time leaves a cosmetic gift.
##
## Leaf subsystem owned by Game; parties ride the normal request
## pipeline (guests/assignments/resolve), the brief is a
## deterministic rule over the seating evaluated here.

const SHELTER_RANK := {"bare": 0, "platform": 1, "cabin": 2}

var g  # the Game autoload (untyped: circular ref)


func _init(game) -> void:
	g = game


func _cfg() -> Dictionary:
	return Catalog.data.get("gatherings", {})


func _template(gid: String) -> Dictionary:
	for t in _cfg().get("templates", []):
		if t.get("id") == gid:
			return t
	return {}


## new_day hook — a seeded offer. The Gathering's parties replace
## that many normal board cards, so a night never has more parties
## than before (§33.3); elites, regulars and the conflict pair are
## never displaced.
func maybe_offer(st: Dictionary) -> void:
	if not g.vol2_open():
		return
	var cfg := _cfg()
	var rng: RandomNumberGenerator = g._rng_for("gathering")
	if rng.randf() >= float(cfg.get("offer_chance", 0.5)):
		return
	var pool: Array = cfg.get("templates", []).filter(
		func(t): return t.get("site") == g.site_id)
	if pool.is_empty():
		return
	var tpl: Dictionary = pool[rng.randi() % pool.size()]
	var n: int = tpl["parties"].size()
	var idx := []
	for i in st["board"].size():
		var c: Dictionary = st["board"][i]
		if not c.get("elite") and c.get("regular", "") == "" \
				and c.get("gathering", "") == "":
			idx.append(i)
	if idx.size() < n:
		return
	for i in n:
		var p: Dictionary = tpl["parties"][i]
		var arch: Dictionary = g._row("archetypes", p["archetype"])
		var req := {"id": "%s_%d" % [tpl["id"], i],
			"archetype": p["archetype"],
			"name": tpl["label"],
			"traits": p["traits"].duplicate(),
			"loud": arch.get("loud", false),
			"pads": int(p.get("pads", 1)),
			"fee": int(arch.get("fees", {}).get(g.site_id, 40)),
			"gathering": tpl["id"],
			"favourite": p.get("favourite", "")}
		st["board"][idx[i]] = req


## Live status for the Evening preview (§33.3: "checks the brief
## live, like stars"). All parties seated + the rule met → payable.
func status(st: Dictionary) -> Dictionary:
	var seated := _seated(st)
	if seated.is_empty():
		return {}
	var gid: String = seated[0]["guest"].get("gathering", "")
	var tpl := _template(gid)
	var world: Dictionary = g._world()
	var results := {}
	for s in seated:
		results[s["guest"]["id"]] = Seating.resolve_guest(
			s["guest"], s["pad_ids"], world,
			int(Seating.allocate_meals(g.meals, seated)["terms"]
				.get(s["guest"]["id"], -1)))
	return {"id": gid, "label": tpl.get("label", ""),
		"text": tpl.get("brief", {}).get("text", ""),
		"seated": seated.size(),
		"total": tpl.get("parties", []).size(),
		"met": seated.size() == tpl["parties"].size() \
			and _brief_met(tpl, seated, world, results)}


func _seated(st: Dictionary) -> Array:
	var out := []
	for gid in st["assignments"]:
		var guest: Dictionary = st["guests"].get(gid, {})
		if guest.get("gathering", "") != "":
			out.append({"guest": guest,
				"pad_ids": st["assignments"][gid]})
	return out


## goodnight hook — returns {"id", "bonus", "gift"} for the report,
## bumps gatherings_met only when the brief is met (§33.3 page 8).
func settle(st: Dictionary, seated: Array,
		results: Array) -> Dictionary:
	var by_gid := {}
	for s in seated:
		if s["guest"].get("gathering", "") != "":
			by_gid[s["guest"]["id"]] = s
	if by_gid.is_empty():
		return {}
	var gid: String = seated.filter(
		func(s): return by_gid.has(s["guest"]["id"])
		)[0]["guest"]["gathering"]
	var tpl := _template(gid)
	if tpl.is_empty():
		return {}
	var rows := []
	for id2 in by_gid:
		rows.append(by_gid[id2])
	if rows.size() != tpl["parties"].size():
		return {"id": gid, "met": false}
	var results_by_id := {}
	for r in results:
		results_by_id[r["id"]] = r
	var world: Dictionary = g._world()
	if not _brief_met(tpl, rows, world, results_by_id):
		return {"id": gid, "met": false}
	var fees := 0
	for s in rows:
		fees += int(s["guest"].get("fee", 0))
	var bonus := int(round(
		fees * float(_cfg().get("bonus_pct", 0.25))))
	g.site_state()["counters"]["gatherings_met"] = int(
		g.site_state()["counters"].get("gatherings_met", 0)) + 1
	var gift := ""
	if gid not in st["gathering_gifts"]:
		st["gathering_gifts"].append(gid)
		gift = String(tpl.get("gift", ""))
	return {"id": gid, "met": true, "bonus": bonus,
		"label": tpl.get("label", ""), "gift": gift}


## The brief — a deterministic rule over the seating (§33.3). Every
## party's pads must satisfy; results carry the resolved stars.
func _brief_met(tpl: Dictionary, seated: Array, world: Dictionary,
		results: Dictionary) -> bool:
	var brief: Dictionary = tpl.get("brief", {})
	var layout: Dictionary = world["layout"]
	var nbs: Dictionary = layout["pads"].get("neighbours", {})
	match String(brief.get("kind", "")):
		"min_stars":
			for s in seated:
				if int(results.get(s["guest"]["id"],
						{}).get("stars", 0)) < int(brief.get("n", 4)):
					return false
			return true
		"within_fire":
			var fire: Dictionary = world.get("campfire", {})
			var fcell: Vector2i = fire.get("cell", Vector2i.ZERO)
			var radius := int(fire.get("radius", 2))
			for s in seated:
				for pid in s["pad_ids"]:
					var spot: Array = layout["pads"]["spots"].get(
						pid, [0, 0])
					if Seating.chebyshev(fcell,
							Vector2i(spot[0], spot[1])) > radius:
						return false
			return true
		"tag":
			if String(brief.get("weather", "")) != "" \
					and world["weather"] != brief["weather"]:
				return false
			var want: String = brief.get("tag", "")
			for s in seated:
				for pid in s["pad_ids"]:
					var tags: Array = layout["pads"].get(
						"tags", {}).get(pid, [])
					if want not in tags:
						return false
			return true
		"covered":
			for s in seated:
				for pid in s["pad_ids"]:
					var ctx := Seating._pad_ctx(pid,
						s["guest"]["id"], world)
					if not ctx["covered"]:
						return false
			return true
		"adjacent":
			var mine := {}
			for s in seated:
				for pid in s["pad_ids"]:
					mine[pid] = s["guest"]["id"]
			for s in seated:
				var has_mate := false
				for pid in s["pad_ids"]:
					for nb in nbs.get(pid, []):
						if mine.get(nb, "") != "" \
								and mine[nb] != s["guest"]["id"]:
							has_mate = true
				if not has_mate:
					return false
			return true
		"shelter":
			var want := int(SHELTER_RANK.get(brief.get("shelter"), 0))
			for s in seated:
				for pid in s["pad_ids"]:
					var ctx := Seating._pad_ctx(pid,
						s["guest"]["id"], world)
					if int(SHELTER_RANK.get(ctx["shelter"], 0)) < want:
						return false
			return true
		"meal":
			for s in seated:
				if int(results.get(s["guest"]["id"],
						{}).get("meal", 0)) < 1:
					return false
			return true
	return false
