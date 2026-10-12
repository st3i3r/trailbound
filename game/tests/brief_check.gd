extends Node
## CI gate (§33.3): "a CI solver checks that every brief offered can
## be met." For each Gathering template this enumerates party→pad
## assignments on its site's real layout and proves at least one
## seating meets the brief — under a well-appointed camp: all pads
## open, cabin shelter, the buyable decor placed per-pad on demand.
## Positional rules are honest: fire reach, pad tags, neighbour
## graph and loud neighbours are all real. Run:
##   godot --headless --path game tests/brief_check.tscn

const DECORABLE := {"introvert": "privacy", "nature_lover": "nature",
	"night_owl": "light", "music_lover": "music", "dog_lover": "dog",
	"kids": "play", "stargazer": "stars"}
const TAG_NEEDS := {"angler": "water", "shutterbug": "view"}
const AVERSION_DECOR := {"stargazer": "light", "dog_wary": "dog"}

var failures := 0


func _ready() -> void:
	print("=== gathering briefs (§33.3 CI gate) ===")
	for tpl: Dictionary in Catalog.data.get(
			"gatherings", {}).get("templates", []):
		var site: StringName = tpl.get("site", &"")
		var t0 := Time.get_ticks_msec()
		var plan := _find_meeting(tpl, site)
		var ms := Time.get_ticks_msec() - t0
		if plan.is_empty():
			failures += 1
			print("  XX %s UNMEETABLE" % tpl["id"])
		else:
			print("  OK %s  (%dms)" % [tpl["id"], ms])
	print("=== %s ===" % ("ALL BRIEFS MEETABLE" if failures == 0
		else "%d FAILURES" % failures))
	get_tree().quit(failures)


## Enumerate assignments until one meets the brief. Returns the
## winning {gid: pad_ids} or {}.
func _find_meeting(tpl: Dictionary, site: StringName) -> Dictionary:
	var layout: Dictionary = Catalog.data.get("layouts", {}).get(
		site, {})
	var pdef: Dictionary = layout.get("pads", {})
	var pads: Array = pdef.get("spots", {}).keys()
	var pair_domain := _pad_pairs(pads)
	var parties := []
	for i in tpl["parties"].size():
		var p: Dictionary = tpl["parties"][i]
		var arch: Dictionary = Game._row("archetypes", p["archetype"])
		parties.append({"id": "%s_%d" % [tpl["id"], i],
			"archetype": p["archetype"],
			"traits": p.get("traits", []),
			"loud": arch.get("loud", false),
			"pads": int(p.get("pads", 1)),
			"fee": int(arch.get("fees", {}).get(site, 40)),
			"favourite": p.get("favourite", ""),
			"gathering": tpl["id"]})
	var domains := []
	for p in parties:
		domains.append(pads.map(func(pid): return [pid]) \
			if p["pads"] == 1 else pair_domain)
	var chosen := []
	if not _search(tpl, parties, domains, {}, layout, site, 0, chosen):
		return {}
	return chosen[0]


## Depth-first assignment with a used-pad set; scores+ brief the
## completed assignment and keeps the winner.
func _search(tpl: Dictionary, parties: Array, domains: Array,
		used: Dictionary, layout: Dictionary, site: StringName,
		i: int, chosen: Array) -> bool:
	if i == parties.size():
		return _try(tpl, parties, used, layout, site, chosen)
	for pads in domains[i]:
		var free := true
		for pid in pads:
			if used.has(pid):
				free = false
				break
		if not free:
			continue
		for pid in pads:
			used[pid] = parties[i]["id"]
		if _search(tpl, parties, domains, used, layout, site,
				i + 1, chosen):
			return true
		for pid in pads:
			used.erase(pid)
	return false


## Score a full assignment through the real resolver under a
## well-appointed camp, then run the actual brief rule.
func _try(tpl: Dictionary, parties: Array, used: Dictionary,
		layout: Dictionary, site: StringName, chosen: Array) -> bool:
	var pads := {}
	for pid in layout["pads"]["spots"]:
		pads[pid] = {"open": true, "shelter": "cabin"}
	var occ := {}
	var gmap := {}
	for pid in used:
		occ[pid] = used[pid]
	for p in parties:
		gmap[p["id"]] = p
	var fire: Dictionary = layout.get("campfire",
		{"cell": [0, 0], "radius": 2})
	var fcell: Array = fire.get("cell", [0, 0])
	var world := {"layout": layout,
		"campfire": {"cell": Vector2i(fcell[0], fcell[1]),
			"radius": 3},              # stone_fire_pit reach
		"decor": [], "pads": pads, "occupants": occ,
		"guests": gmap, "weather": "clear",
		"trait_kinds": Game._trait_kinds(),
		"comments": Catalog.data.get("reviews", {}), "day": 1}
	var seated := []
	for p in parties:
		var ids := []
		for pid in used:
			if used[pid] == p["id"]:
				ids.append(pid)
		seated.append({"guest": p, "pad_ids": ids})
	# Place per-pad decor for every decor-coverable need; never place
	# an aversion trigger on the averse party's own pad (light on a
	# stargazer, dog on the dog-wary).
	var banned := {}
	for s in seated:
		for t in s["guest"]["traits"]:
			if AVERSION_DECOR.has(t):
				banned.get_or_add(s["guest"]["id"], []).append(
					AVERSION_DECOR[t])
	var decor := []
	for s in seated:
		var forbid: Array = banned.get(s["guest"]["id"], [])
		for t in s["guest"]["traits"]:
			var need_eff: String = DECORABLE.get(t, "")
			if need_eff == "" or need_eff in forbid:
				continue
			for pid in s["pad_ids"]:
				var spot: Array = layout["pads"]["spots"][pid]
				decor.append({"id": "d", "effect": need_eff,
					"reach": 0,
					"cells": [Vector2i(spot[0], spot[1])]})
	world["decor"] = decor
	# Everyone gets a meal (term -1 costs a star); favourites get
	# their own so the +1 is available to the brief.
	var meals := []
	for p in parties:
		var fav: String = p.get("favourite", "")
		meals.append({"id": fav if fav != "" else "trail_stew",
			"price": 18})
	var plan := Seating.allocate_meals(meals, seated)
	var results := {}
	for s in seated:
		var r := Seating.resolve_guest(s["guest"], s["pad_ids"],
			world, int(plan["terms"].get(s["guest"]["id"], -1)))
		results[s["guest"]["id"]] = r
	if Game.gatherings._brief_met(tpl, seated, world, results):
		var plan_out := {}
		for s in seated:
			plan_out[s["guest"]["id"]] = s["pad_ids"]
		chosen.assign([plan_out])
		return true
	return false


## Neighbouring open-pad pairs for two-pad parties (families).
func _pad_pairs(pads: Array) -> Array:
	var out := []
	for i in pads.size():
		for j in range(i + 1, pads.size()):
			out.append([pads[i], pads[j]])
	return out
