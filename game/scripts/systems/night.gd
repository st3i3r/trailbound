extends RefCounted
## Night — nightly settle + vignette selection (§13.4/§4). Leaf subsystem owned by Game (autoload/game.gd); holds no save state of its own (the `night` dict + `vignettes_seen` stay on Game for the save schema).
##
## Public API stays on Game as one-line delegates, so callers
## never move. All Game state is accessed via `g`.

var g  # the Game autoload (untyped: circular ref)


func _init(game) -> void:
	g = game


func goodnight() -> Dictionary:
	if g.phase != g.Phase.EVENING:
		return {}                       # settling is the evening's last act
	var st: Dictionary = g.site_state()
	var seated := []
	for gid in st["assignments"]:
		seated.append({"guest": st["guests"][gid],
			"pad_ids": st["assignments"][gid]})
	var rating_before: float = g.rating()
	# §5.5: plates served by hand ride first — a hand-served favourite
	# is the same +1 the planner would find.  Whatever is still on the
	# stove after that gets the automatic cheapest-first split.
	var left: Array = g.meals.duplicate(true)
	var open_seats := []
	var terms := {}
	for s in seated:
		var gid0: String = s["guest"]["id"]
		var mid := String(st["served"].get(gid0, ""))
		if mid == "":
			open_seats.append(s)
			continue
		terms[gid0] = 1 if mid == s["guest"].get("favourite", "") else 0
		for i in left.size():
			if String(left[i].get("id")) == mid:
				left.remove_at(i)
				break
	var plan: Dictionary = Seating.allocate_meals(left, open_seats)
	for gid in plan["terms"]:
		terms[gid] = plan["terms"][gid]
	plan["terms"] = terms
	var results := []
	var fees := 0
	var tips := 0
	var elite5 := false
	var min_stars := 6
	var fav_served := false
	var regs := []
	var cnt: Dictionary = st["counters"]
	var night := {"five_stars": 0, "stargazer_five": 0,
		"pads_filled": 0, "all5": 0, "full4": 0, "rain_full4": 0,
		"returners": 0, "wishes_met": 0, "min_stars": 6}
	var tags: Dictionary = g._world()["layout"].get(
		"pads", {}).get("tags", {})   # merged incl. §6.11 pad_tags
	for s in seated:
		var r: Dictionary = Seating.resolve_guest(s["guest"], s["pad_ids"],
			g._world(), int(plan["terms"].get(s["guest"]["id"], -1)))
		# care gesture: a tucked-in guest sleeps a little easier —
		# one star, and the tip follows the new rating
		if s["guest"]["id"] == st.get("tucked_in", "") \
				and int(r["stars"]) < 5:
			r["stars"] += 1
			r["tip"] = Econ.tip(r["fee"], r["stars"])
		results.append(r)
		fees += r["fee"]
		tips += int(round(r["tip"]))
		st["reviews"].append(r["stars"])
		if s["guest"].get("elite", false) and r["stars"] == 5:
			elite5 = true                              # §5.6: +1 walk-in tomorrow
		# journal counters (§8.1)
		cnt["guests_welcomed"] += 1
		night["pads_filled"] += s["pad_ids"].size()
		if int(plan["terms"].get(s["guest"]["id"], 0)) > 0:
			fav_served = true                  # §5.4: the favourite landed
		if s["guest"].get("regular", "") != "":
			regs.append(s["guest"]["regular"])
		var arch: String = s["guest"].get("archetype", "")
		if arch != "":
			cnt["arch_visits"][arch] = int(
				cnt["arch_visits"].get(arch, 0)) + 1
		if s["guest"].get("returning", false):
			night["returners"] += 1
		if r.get("wish_met", false):
			night["wishes_met"] += 1
		if arch == "family":
			cnt["families"] += 1
		elif arch == "angler" and s["pad_ids"].any(
				func(pid): return "water" in tags.get(pid, [])):
			cnt["anglers_water"] += 1
		var regular: String = s["guest"].get("regular", "")
		if regular != "":
			cnt["regular_visits"][regular] = int(
				cnt["regular_visits"].get(regular, 0)) + 1
		# §8.3 guestbook: the persona's first stay, keyed by archetype
		if arch != "" and arch not in g.personas_met:
			g.personas_met[arch] = s["guest"].get("name", "")
		if r["stars"] == 5:
			night["five_stars"] += 1
			if "stargazer" in s["guest"].get("traits", []):
				night["stargazer_five"] = 1
		min_stars = mini(min_stars, r["stars"])
	# a guest-less night earns no stars — keeps stars_min triggers and
	# the all5/full4 pages honest instead of matching on the sentinel
	night["min_stars"] = min_stars if not seated.is_empty() else 0
	while st["reviews"].size() > 15:
		st["reviews"].pop_front()
	# §33.3 Vol II night pages: a perfect 6+-party night (P9), a full
	# 4★+ house (W9), the rainy variant (L9).
	if not seated.is_empty():
		if min_stars >= 5:
			night["all5"] = seated.size()
		var open_count: int = st["pads"].values().filter(
			func(p): return p["open"]).size()
		var all_open_filled: bool = night["pads_filled"] >= open_count
		if all_open_filled and min_stars >= 4:
			night["full4"] = night["pads_filled"]
			if st["weather"] == "rain":
				night["rain_full4"] = night["pads_filled"]
	var gather_rep: Dictionary = g.gatherings.settle(st, seated, results)
	var gather_bonus := int(gather_rep.get("bonus", 0))
	var walk_ins: int = Econ.walk_ins(st["seats"], rating_before) \
		+ int(st["walk_bonus"])
	if st["blogger_bonus"]:
		walk_ins += 1
	if st.get("music_night", false):
		tips = int(round(tips * (1.0 + float(Platform.remote(
			"music_night_tip_bonus", g.MUSIC_NIGHT_TIP_BONUS)))))
	if st.get("fire_stoked", false):
		tips = int(round(tips * 1.1))     # care gesture: warm camp
	tips += int(night["returners"]) * 10   # familiar faces tip loyal
	var leftover: Array = plan["leftover"]
	leftover.sort_custom(
		func(a, b): return a.get("price", 0) > b.get("price", 0))
	var sold: Array = leftover.slice(0, mini(walk_ins, leftover.size()))
	var meal_sales := 0
	for m in sold:
		meal_sales += int(m.get("price", 0))
	# recipe mastery: a Practiced/Signature plate tips a little extra
	# per serving that actually reached a guest (walk-ins don't know)
	var landed := {}
	for m in g.meals:
		landed[m["id"]] = int(landed.get(m["id"], 0)) + 1
	for m in leftover:
		landed[m["id"]] = int(landed.get(m["id"], 0)) - 1
	for mid in landed:
		var tier: int = g.cook_tier(String(mid))
		if tier > 0 and int(landed[mid]) > 0:
			tips += int(landed[mid]) * (15 if tier == 2 else 6)
	g.dog_sys.eat(leftover.size() - sold.size())   # §9: stray + scraps
	st["blogger_bonus"] = elite5
	var vig: String = _pick_vignette(st, seated, night)
	st["assignments"] = {}
	st["served"] = {}
	st["guests"] = {}
	g.meals.clear()                                    # leftovers to the dog
	g.coins += fees + tips + meal_sales + gather_bonus
	var pages: Array = g._check_pages(night)
	g.set_phase(g.Phase.NIGHT)
	var best := {}
	for r in results:
		if best.is_empty() or int(r["stars"]) > int(best["stars"]):
			best = {"id": r["id"], "stars": r["stars"],
				"comment": r["comment"]}
	# §8.3 days log: one line per night, before the state clears
	g.days_log.append({"day": g.day, "site": String(g.site_id),
		"weather": st["weather"], "guests": seated.size(),
		"best": int(best.get("stars", 0)),
		"fav_served": fav_served, "regulars": regs,
		"income": fees + tips + meal_sales + gather_bonus,
		"min_stars": night["min_stars"],
		"returners": int(night["returners"]),
		"wishes_met": int(night["wishes_met"]),
		"event": st.get("event", "")})
	# §17.6: the in-app-review gate watches for the first all-5★ night
	if int(night["all5"]) > 0 and int(g.ads.get("first_all5_day", 0)) == 0:
		g.ads["first_all5_day"] = g.day
	g._log("night", {"guests": seated.size(), "income": fees + tips
		+ meal_sales + gather_bonus, "min_stars": night["min_stars"],
		"vignette": vig, "walk_ins": sold.size()})
	Analytics.log_event(&"day_end", {"day": g.day,
		"site": String(g.site_id), "guests": seated.size(),
		"income": fees + tips + meal_sales + gather_bonus,
		"min_stars": night["min_stars"], "vignette": vig})
	g.commit()                     # payout banked — phase saved as NIGHT, so a
	                             # kill mid-summary resumes already-paid
	return {"results": results, "fees": fees, "tips": tips,
		"walk_ins": sold.size(), "meal_sales": meal_sales,
		"income": fees + tips + meal_sales + gather_bonus,
		"gathering": gather_rep, "rating": g.rating(),
		"pages": pages.map(func(p): return int(p["n"])),
		"best": best, "vignette": vig}


func _pick_vignette(st: Dictionary, seated: Array,
		night: Dictionary) -> String:
	var rows: Array = Catalog.data.get("vignettes", [])
	var restored: String = st.get("vignette_restored", "")
	if restored != "":
		st["vignette_restored"] = ""
		for v in rows:
			if v.get("trigger", {}).get("crew_restored") == restored:
				g.vignettes_seen.append(v["id"])
				return v["id"]
	var world: Dictionary = g._world()
	var spots: Dictionary = world["layout"]["pads"]["spots"]
	var best_id := ""
	var best_weight := -1
	for v in rows:
		var tr: Dictionary = v.get("trigger", {})
		if tr.has("crew_restored"):
			continue
		var w := _vignette_weight(tr, seated, st, world, spots, night)
		if w < 0:
			continue                                   # not eligible
		# unseen first; then the trigger matching the most guests
		var key := w if v["id"] not in g.vignettes_seen else w - 100
		if key > best_weight:
			best_weight = key
			best_id = v["id"]
	if best_id != "":
		g.vignettes_seen.append(best_id)
	return best_id


## -1 = ineligible; otherwise how many seated guests match the
## trigger (the tiebreak §13.4 wants).
func _vignette_weight(tr: Dictionary, seated: Array, st: Dictionary,
		world: Dictionary, spots: Dictionary,
		night: Dictionary = {}) -> int:
	var meal_ids: Array = g.meals.map(func(m): return m["id"])
	var n := 0
	for s in seated:
		var gu: Dictionary = s["guest"]
		var ok := true
		if tr.has("trait"):
			ok = ok and tr["trait"] in gu.get("traits", [])
		if tr.has("archetype"):
			ok = ok and gu.get("archetype") == tr["archetype"]
		if tr.has("regular"):
			ok = ok and gu.get("regular", "") == tr["regular"]
		if tr.has("effect"):
			var hit := false
			for pid in s["pad_ids"]:
				var cell := Vector2i(spots[pid][0], spots[pid][1])
				if Seating.effects_at(cell, world).has(tr["effect"]):
					hit = true
			ok = ok and hit
		if tr.has("shelter"):                # spec 005: shelter under a seated pad
			ok = ok and s["pad_ids"].any(
				func(pid): return st["pads"].get(pid, {}).get(
					"shelter", "bare") == tr["shelter"])
		if ok:
			n += 1
	if tr.has("trait") or tr.has("archetype") or tr.has("regular") \
			or tr.has("effect") or tr.has("shelter"):
		if n == 0:
			return -1
	if tr.has("decor"):
		if not st["decor"].any(func(d): return d["id"] == tr["decor"]):
			return -1
	if tr.has("weather") and st["weather"] != tr["weather"]:
		return -1
	# §13.5: festival vignettes only play on their own night
	if tr.has("event") and String(st.get("event", "")) != tr["event"]:
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
	# spec 005 state-level triggers — the vignette reacts to what the
	# player did tonight, not just who sat where
	if tr.has("stars_min") and int(night.get("min_stars", 0)) \
			< int(tr["stars_min"]):
		return -1
	if tr.get("first_night", false) and g.site_day() != 1:
		return -1
	if tr.has("letter") and tr["letter"] not in g.letters_read:
		return -1
	if tr.has("dog"):
		var dv: Variant = tr["dog"]
		# "met" is a flag check; a number compares against bond level
		var dog_ok: bool = (bool(g.dog["met"]) if (dv is String and dv == "met") else g.dog_level() >= int(dv))
		if not dog_ok:
			return -1
	return maxi(n, 1)

