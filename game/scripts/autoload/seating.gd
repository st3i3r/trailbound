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
		var cause := ""
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
					if ctx["eff"].has("light"):
						tripped = true
						cause = "light"
				"light_sleeper":
					if ctx["eff"].has("music"):
						tripped = true
						cause = "music"
					elif ctx["loud"] and cause == "":
						tripped = true
						cause = "loud"
				"dog_wary":
					if ctx["eff"].has("dog"):
						tripped = true
						cause = "dog"
		var kind: String = world["trait_kinds"].get(trait_id, "need")
		if tripped and kind in ["aversion", "both"]:
			aversions += 1
		if met and kind in ["need", "both"]:
			needs_met += 1
		var d := {"trait": trait_id, "kind": kind,
			"met": met, "tripped": tripped}
		if cause != "":
			d["cause"] = cause
		detail.append(d)
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


## Reviews carry one line about the strongest term (§5.6, ≤20
## words, reviews.json). Complaints dominate, then the favourite,
## then a met need — that ordering is the "strongest" the guest
## would actually write home about.
const TRAIT_KEYS := {"chilly": "warmth", "social": "company",
	"introvert": "privacy", "nature_lover": "nature",
	"night_owl": "light", "music_lover": "music",
	"dog_lover": "dog", "kids": "play", "angler": "water",
	"shutterbug": "view", "stargazer": "stars"}

static func _comment_key(ev: Dictionary, comfort: int, meal_term: int,
		weather_term: int) -> String:
	for d in ev["detail"]:                       # aversions dominate
		if d["tripped"]:
			var c: String = d.get("cause", "")
			return c + "_bad" if c in ["music", "light", "dog"] else c
	if weather_term < 0:
		return "rain"
	if meal_term > 0:
		return "favourite"
	for d in ev["detail"]:
		if d["met"]:
			return TRAIT_KEYS.get(d["trait"], "neutral")
	if comfort > 0:
		return "comfort"
	if meal_term < 0:
		return "no_meal"
	if comfort == 0:
		return "bare"
	return "neutral"


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
	var key := _comment_key(ev, comfort, meal_term, weather_term)
	var lines: Array = world.get("comments", {}).get(key,
		["A fine night."])
	return {"id": guest.get("id", ""), "stars": stars, "fee": fee,
		"tip": Econ.tip(fee, stars), "comfort": comfort,
		"weather": weather_term, "meal": meal_term,
		"needs_met": ev["needs_met"], "aversions": ev["aversions"],
		"detail": ev["detail"], "comment_key": key,
		"comment": lines[(String(guest.get("id", "")).hash()
			+ int(world.get("day", 0))) % lines.size()]}


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
		index: int, rng: RandomNumberGenerator,
		favourites: Array) -> Dictionary:
	return {"id": "req%d" % index, "archetype": arch.get("id", ""),
		"name": arch.get("name", ""), "traits": traits,
		"loud": arch.get("loud", false), "pads": int(arch.get("pads", 1)),
		"fee": int(arch.get("fees", {}).get(site_id, 0)),
		"favourite": favourites[rng.randi() % favourites.size()] \
			if not favourites.is_empty() else ""}


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
		rng: RandomNumberGenerator, has_free_pair := false,
		favourites: Array = []) -> Array:
	var site_id: String = site.get("id", "")
	var reqs := []
	if site_day == 1:
		var i := 0
		for spec in DAY1_BOARD:
			var arch := _pick_archetype(
				{spec["archetype"]: 1}, archetypes, site_id, rng)
			reqs.append(_request(arch, site_id,
				spec["traits"].duplicate(), i, rng, favourites))
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
		reqs.append(_request(arch, site_id, traits, i, rng, favourites))

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
				var req := _request(arch, site_id, traits, reqs.size(),
					rng, favourites)
				req["elite"] = true
				reqs[reqs.size() - 1] = req
				break
	return reqs


# ------------------------------------------------------------- Daily (§10)
#
# The shared puzzle: 5 pads around a campfire at the south edge
# (Warmth only reaches the two near pads, so Chilly stays a real
# choice), a 4-item kit, 6 requests of which 5 can be seated, and
# 5 meals of 4 kinds — all seeded by hash("daily", date).

const DAILY_PADS := {
	"d1": {"cell": [0, 0], "neighbours": ["d2", "d4"]},
	"d2": {"cell": [1, 0], "neighbours": ["d1", "d3"]},
	"d3": {"cell": [2, 0], "neighbours": ["d2", "d5"]},
	"d4": {"cell": [0, 1], "neighbours": ["d1", "d5"]},
	"d5": {"cell": [2, 1], "neighbours": ["d3", "d4"]}}
const DAILY_FIRE := {"cell": [1, 2], "radius": 1}
const DAILY_SPOTS := [[0, -1], [1, -1], [2, -1], [0, 2], [2, 2], [1, 1]]


## Seeded daily puzzle. kit_pool: Pinewatch decor rows; meal_pool:
## recipes cookable at Pinewatch. Returns the static puzzle —
## scoring is daily_score() below.
static func daily_puzzle(site: Dictionary, archetypes: Array,
		kit_pool: Array, meal_pool: Array,
		rng: RandomNumberGenerator) -> Dictionary:
	var kit := []
	var bag := kit_pool.duplicate()
	for i in mini(4, bag.size()):
		kit.append(bag.pop_at(rng.randi() % bag.size()))
	var meals := []
	var mb := meal_pool.duplicate()
	for i in mini(4, mb.size()):
		meals.append({"id": mb.pop_at(rng.randi() % mb.size()),
			"price": 0})
	if meals.size() == 4:
		var dup: Dictionary = meals[rng.randi() % 4]
		meals.append(dup.duplicate())
	var favs: Array = meals.map(func(m): return m["id"])
	var requests := []
	var pool: Dictionary = site.get("trait_pool", {})
	var mix: Dictionary = site.get("archetype_mix", {})
	var i := 0
	while requests.size() < 6 and i < 40:      # §10: no families
		i += 1
		var arch := _pick_archetype(mix, archetypes,
			site.get("id", ""), rng)
		if arch.is_empty() or arch.get("id") == "family":
			continue
		requests.append(_request(arch, site["id"],
			_draw_traits(arch, pool, 2, rng),
			requests.size(), rng, favs))
	return {"pads": DAILY_PADS, "campfire": DAILY_FIRE,
		"decor_spots": DAILY_SPOTS, "kit": kit, "meals": meals,
		"requests": requests}


## A Daily world shaped like the evening world (§5 world dict).
## decor_items: [{"id","cells","effect","reach"}] — the caller
## resolves kit rows; pads have no shelter in the Daily.
static func daily_world(puzzle: Dictionary, decor_items: Array,
		occupants: Dictionary, guests: Dictionary,
		trait_kinds: Dictionary, comments: Dictionary) -> Dictionary:
	var layout := {"pads": {"spots": {}, "neighbours": {}, "tags": {}}}
	for pid in puzzle["pads"]:
		layout["pads"]["spots"][pid] = puzzle["pads"][pid]["cell"]
		layout["pads"]["neighbours"][pid] = \
			puzzle["pads"][pid]["neighbours"]
	return {"layout": layout, "campfire": {"cell": Vector2i(
			puzzle["campfire"]["cell"][0], puzzle["campfire"]["cell"][1]),
			"radius": puzzle["campfire"]["radius"]},
		"pads": {}, "occupants": occupants, "guests": guests,
		"decor": decor_items, "weather": "clear",
		"trait_kinds": trait_kinds, "comments": comments, "day": 0}
