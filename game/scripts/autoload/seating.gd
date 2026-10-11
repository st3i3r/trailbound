extends Node
## Seating — pure functions: the seeded evening board (§5.2), trait
## evaluation on the pad graph (§5.3), and Goodnight resolution
## (§5.4–5.6). No scene access; the same math drives tools/sim.py so
## engine and sim stay comparable.
##
## World dict (built by Game):
##   layout:    layout.json row (pad spots, neighbours, tags, campfire)
##   campfire:  {"cell": Vector2i, "radius": 2 or 3 with Stone Fire Pit}
##   decor:     [{"id":…, "effect":…, "radius":…, "cells":[Vector2i]}]
##   pads:      {pid: {"open": bool, "shelter": "bare|platform|cabin"}}
##   occupants: {pid: guest_id}   — seated guests only
##   guests:    {guest_id: request dict}
##   weather:   "clear" | "cloudy" | "rain"

const SHELTER_COMFORT := {"bare": 0, "platform": 1, "cabin": 2}

## §5.3: conflicting pairs the board must contain from day 6.
const CONFLICT_PAIRS := [["social", "introvert"],
	["night_owl", "stargazer"]]
## §14: Pinewatch's first-evening board is scripted (one trait each).
const DAY1_BOARD := [
	{"archetype": "hiker", "traits": ["chilly"]},
	{"archetype": "scout", "traits": ["social"]}]


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Effects reaching a pad cell (§5.1): an item counts when any of its
## cells is within radius of the pad cell; the campfire adds Warmth.
static func effects_at(pad_cell: Vector2i, world: Dictionary) -> Dictionary:
	var eff := {}
	for item: Dictionary in world.get("decor", []):
		var radius := int(item.get("reach", 1))
		for cell: Vector2i in item.get("cells", []):
			if chebyshev(cell, pad_cell) <= radius:
				eff[item["effect"]] = true
				break
	var fire: Dictionary = world.get("campfire", {})
	if fire and chebyshev(fire.get("cell", Vector2i.ZERO), pad_cell) \
			<= int(fire.get("radius", 2)):
		eff["warmth"] = true
	return eff


## Per-pad context: own effects, tags, shelter, and which guests sit
## on neighbouring pads (a guest never counts as its own neighbour).
static func _pad_ctx(pad_id: String, guest_id: String,
		world: Dictionary) -> Dictionary:
	var layout: Dictionary = world["layout"]
	var spots: Dictionary = layout["pads"]["spots"]
	var cell := Vector2i(spots[pad_id][0], spots[pad_id][1])
	var occupants: Dictionary = world["occupants"]
	var occupied := false
	var loud := false
	for other: String in layout["pads"]["neighbours"].get(pad_id, []):
		var who: String = occupants.get(other, "")
		if who == "" or who == guest_id:
			continue
		occupied = true
		var other_guest: Dictionary = world["guests"].get(who, {})
		if other_guest.get("loud", false):
			loud = true
	var shelter: String = world["pads"].get(pad_id, {}).get("shelter", "bare")
	var eff := effects_at(cell, world)
	return {"cell": cell, "eff": eff, "occupied": occupied,
		"loud": loud, "shelter": shelter,
		"covered": shelter == "cabin" or eff.has("cover"),
		"tags": layout["pads"].get("tags", {}).get(pad_id, [])}


## §5.3 binary checks. A need is met on ANY of the guest's pads; an
## aversion trips on ANY (§5.4 family rule). Stargazer is kind "both":
## Stars-in-range counts as a need, Light-in-range as an aversion.
static func eval_guest(guest: Dictionary, pad_ids: Array,
		world: Dictionary) -> Dictionary:
	var ctxs := pad_ids.map(
		func(pid): return _pad_ctx(pid, guest["id"], world))
	var detail := []
	var needs_met := 0
	var aversions := 0
	for trait_id: String in guest.get("traits", []):
		var met := false
		var tripped := false
		for ctx in ctxs:
			match trait_id:
				"chilly": met = met or ctx["eff"].has("warmth")
				"social": met = met or ctx["occupied"]
				"introvert": met = met or ctx["eff"].has("privacy") \
						or not ctx["occupied"]
				"nature_lover": met = met or ctx["eff"].has("nature")
				"night_owl": met = met or ctx["eff"].has("light")
				"music_lover": met = met or ctx["eff"].has("music")
				"dog_lover": met = met or ctx["eff"].has("dog")
				"kids": met = met or ctx["eff"].has("play")
				"angler": met = met or "water" in ctx["tags"]
				"shutterbug": met = met or "view" in ctx["tags"]
				"stargazer":
					met = met or ctx["eff"].has("stars")
					tripped = tripped or ctx["eff"].has("light")
				"light_sleeper":
					tripped = tripped or ctx["eff"].has("music") \
						or ctx["loud"]
				"dog_wary": tripped = tripped or ctx["eff"].has("dog")
		var kind: String = world["trait_kinds"].get(trait_id, "need")
		if tripped and kind in ["aversion", "both"]:
			aversions += 1
		if met and kind in ["need", "both"]:
			needs_met += 1
		detail.append({"trait": trait_id, "kind": kind,
			"met": met, "tripped": tripped})
	return {"needs_met": needs_met, "aversions": aversions,
		"detail": detail}


## §5.4: families use the worse of their two pads for comfort.
static func comfort_of(pad_ids: Array, world: Dictionary) -> int:
	var worst := 99
	for pid in pad_ids:
		var shelter: String = world["pads"].get(pid, {}).get("shelter", "bare")
		worst = mini(worst, SHELTER_COMFORT.get(shelter, 0))
	return worst if worst < 99 else 0


## §5.4: rain hits when the worse pad is uncovered — covered means
## every pad is under a Tarp or is a Cabin.
static func is_covered(pad_ids: Array, world: Dictionary,
		guest_id := "") -> bool:
	for pid in pad_ids:
		var ctx := _pad_ctx(pid, guest_id, world)
		if not ctx["covered"]:
			return false
	return true


## §5.4 stars + §6.4 tip for one party. meal_term: +1 favourite,
## 0 another meal, −1 no meal (§5.5).
static func resolve_guest(guest: Dictionary, pad_ids: Array,
		world: Dictionary, meal_term := 0) -> Dictionary:
	var ev := eval_guest(guest, pad_ids, world)
	var comfort := comfort_of(pad_ids, world)
	var weather_term := 0
	if world.get("weather") == "rain" \
			and not is_covered(pad_ids, world, guest.get("id", "")):
		weather_term = -1
	var stars := Econ.stars(comfort, meal_term, ev["needs_met"],
		ev["aversions"], weather_term)
	var fee := int(guest.get("fee", 0))
	return {"id": guest.get("id", ""), "stars": stars, "fee": fee,
		"tip": Econ.tip(fee, stars), "comfort": comfort,
		"weather": weather_term, "meal": meal_term,
		"needs_met": ev["needs_met"], "aversions": ev["aversions"],
		"detail": ev["detail"]}


## §5.5 meal allocation: favourites first (the only +1), then cheapest
## remaining meals to everyone else, pricier ones held back for
## walk-ins. meals: [{"id", "price"}]; seated: [{guest, pad_ids}].
## Returns {guest_id: meal_term}; leftover meal ids under "leftover".
static func allocate_meals(meals: Array,
		seated: Array) -> Dictionary:
	var terms := {}
	var left := meals.duplicate(true)
	for s in seated:
		var fav: String = s["guest"].get("favourite", "")
		var hit := -1
		for i in left.size():
			if left[i].get("id") == fav and fav != "":
				hit = i
				break
		if hit >= 0:
			terms[s["guest"]["id"]] = 1
			left.remove_at(hit)
	left.sort_custom(func(a, b): return a.get("price", 0) < b.get("price", 0))
	for s in seated:
		var gid: String = s["guest"]["id"]
		if terms.has(gid):
			continue
		terms[gid] = 0 if not left.is_empty() else -1
		if not left.is_empty():
			left.remove_at(0)
	return {"terms": terms, "leftover": left}


# ------------------------------------------------------------- board (§5.2)

static func _pick_archetype(mix: Dictionary, archetypes: Array,
		site_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	var usable := []
	for aid in mix:
		for arch in archetypes:
			if arch.get("id") == aid and site_id in arch.get("sites", []) \
					and arch.get("fees", {}).has(site_id):
				usable.append(arch)
				total += float(mix[aid])
	if usable.is_empty():
		return {}
	var roll := rng.randf() * total
	for arch in usable:
		roll -= float(mix[arch["id"]])
		if roll <= 0.0:
			return arch
	return usable.back()


## Weighted trait draw without replacement (§5.3): signature traits of
## the archetype count at double weight where the site's pool has them.
static func _draw_traits(arch: Dictionary, pool: Dictionary, count: int,
		rng: RandomNumberGenerator) -> Array:
	var bag := pool.duplicate()
	var signature: Array = arch.get("signature_traits", [])
	var out := []
	while out.size() < count and not bag.is_empty():
		var total := 0.0
		for trait_id in bag:
			total += float(bag[trait_id]) * (2.0 if trait_id in signature else 1.0)
		var roll := rng.randf() * total
		var pick := ""
		for trait_id in bag:
			roll -= float(bag[trait_id]) * (2.0 if trait_id in signature else 1.0)
			if roll <= 0.0:
				pick = trait_id
				break
		if pick == "":
			pick = bag.keys().back()
		out.append(pick)
		bag.erase(pick)
	return out


static func _request(arch: Dictionary, site_id: String, traits: Array,
		index: int) -> Dictionary:
	return {"id": "req%d" % index, "archetype": arch.get("id", ""),
		"name": arch.get("name", ""), "traits": traits,
		"loud": arch.get("loud", false), "pads": int(arch.get("pads", 1)),
		"fee": int(arch.get("fees", {}).get(site_id, 0)),
		"favourite": ""}


static func _has_conflict(board: Array) -> bool:
	for pair in CONFLICT_PAIRS:
		var seen := {}
		for req in board:
			for t in pair:
				if t in req["traits"]:
					seen[t] = true
		if seen.size() == pair.size():
			return true
	# A Loud guest beside a Light Sleeper also conflicts.
	var has_loud := false
	var has_sleeper := false
	for req in board:
		has_loud = has_loud or req["loud"]
		has_sleeper = has_sleeper or "light_sleeper" in req["traits"]
	return has_loud and has_sleeper


## §5.2 evening board, fully deterministic: the caller passes an rng
## seeded by save + site + site day (§21.3) so reloads never reroll.
static func board(site: Dictionary, archetypes: Array, site_day: int,
		open_pads: Array, rating: float,
		rng: RandomNumberGenerator, has_free_pair := false) -> Array:
	var site_id: String = site.get("id", "")
	var reqs := []
	if site_day == 1:
		var i := 0
		for spec in DAY1_BOARD:
			var arch := _pick_archetype(
				{spec["archetype"]: 1}, archetypes, site_id, rng)
			reqs.append(_request(arch, site_id,
				spec["traits"].duplicate(), i))
			i += 1
		return reqs

	var count := open_pads.size() + 1
	if site_day % 7 in [6, 0]:                     # in-game weekend
		count += 1
	var mix: Dictionary = site.get("archetype_mix", {})
	var pool: Dictionary = site.get("trait_pool", {})
	var trait_count := 1 if site_day <= 4 else 2

	# Family: about one night in three once ≥ 4 pads are open and a
	# neighbouring pair of free pads exists (§5.2).
	var family_arch := {}
	if open_pads.size() >= 4 and has_free_pair and rng.randf() < 1.0 / 3.0:
		for arch in archetypes:
			if arch.get("id") == "family" \
					and arch.get("fees", {}).has(site_id):
				family_arch = arch
	var loud_count := 0
	for i in count:
		var arch: Dictionary
		if not family_arch.is_empty():
			arch = family_arch
			family_arch = {}
		else:
			arch = _pick_archetype(mix, archetypes, site_id, rng)
		if arch.is_empty():
			continue
		var traits: Array = []
		if arch.get("id") == "family":
			traits.append("kids")
			traits += _draw_traits(arch, pool, 1, rng)
		else:
			traits = _draw_traits(arch, pool, trait_count, rng)
		if arch.get("loud", false):
			loud_count += 1
		reqs.append(_request(arch, site_id, traits, i))

	# From day 6 every board holds at least one conflicting pair (§5.2).
	if site_day >= 6 and reqs.size() >= 2 and not _has_conflict(reqs):
		for i in [reqs.size() - 2, reqs.size() - 1]:
			var t: Array = reqs[i]["traits"]
			var want := "social" if i == reqs.size() - 2 else "introvert"
			if want not in t:
				if t.is_empty():
					t.append(want)
				else:
					t[t.size() - 1] = want

	# Food Blogger: only while rating ≥ 4.5, at most one a night (§5.2).
	if rating >= 4.5 and rng.randf() < 0.25:
		for arch in archetypes:
			if arch.get("id") == "food_blogger" \
					and arch.get("fees", {}).has(site_id):
				var traits := _draw_traits(arch, pool, 3, rng)
				var has_aversion := false
				for t in traits:
					# trait kinds live in traits.json; aversion check
					# is approximated by the static list below.
					if t in ["light_sleeper", "dog_wary"]:
						has_aversion = true
				if not has_aversion and "light_sleeper" not in traits:
					traits[0] = "light_sleeper"
				var req := _request(arch, site_id, traits, reqs.size())
				req["elite"] = true
				reqs[reqs.size() - 1] = req
				break
	return reqs
