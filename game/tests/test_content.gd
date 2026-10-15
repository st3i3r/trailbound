extends "res://tests/harness.gd"
## Content lint — the §21.2 reference/consistency sweep, one scene so
## every new data file lands under the same gate. Run:
##   godot --headless --path game tests/test_content.tscn
## Exit code = number of failed checks.

var d: Dictionary


func _ids(list_name: String) -> Array:
	var out := []
	for r in d.get(list_name, []):
		out.append(String(r.get("id", "")))
	return out


func _ready() -> void:
	print("=== content lint (§21.2) ===")
	d = Catalog.data
	var ingredients := _ids("ingredients")
	var recipes := _ids("recipes")
	var decor := _ids("decor")
	var gear := _ids("gear")
	var archetypes := _ids("archetypes")
	var traits := _ids("traits")
	var regulars := _ids("regulars")
	var festivals := _ids("festivals")
	var crew_ids := []
	for s in d.get("crew", {}).get("structures", []):
		crew_ids.append(String(s.get("id", "")))
	var site_ids: Array = Catalog.data["layouts"].keys()

	# --- recipes: every pair entry resolves; festival dishes exist ----
	var bad_pairs := []
	for r in d.get("recipes", []):
		for ing in r.get("pair", []):
			if ing != "any_fish" and ing not in ingredients:
				bad_pairs.append("%s->%s" % [r["id"], ing])
	check("recipe ingredients resolve", bad_pairs.is_empty(),
		str(bad_pairs))
	var fest_dishes := []
	for r in d.get("recipes", []):
		if r.has("festival"):
			fest_dishes.append(String(r["id"]))
			check("festival dish %s refs a festival" % r["id"],
				String(r["festival"]) in festivals)
	check("festival dishes exist", fest_dishes.size() >= 2)

	# --- festivals: site + site_day valid, dish + vignette land -------
	var letters: Array = d.get("letters", [])
	for f in d.get("festivals", []):
		check("festival %s site valid" % f["id"],
			String(f["site"]) in site_ids)
		check("festival %s dish resolves" % f["id"],
			String(f.get("dish", "")) in recipes)
		var v_ok := false
		for v in d.get("vignettes", []):
			if v.get("trigger", {}).get("event", "") == f["id"]:
				v_ok = true
		check("festival %s has a vignette" % f["id"], v_ok)
		for a in f.get("archetype_boost", {}):
			check("festival %s boost archetype %s" % [f["id"], a],
				String(a) in archetypes)

	# --- Field Notes: §8.3 wants 22 = 12 birds + 5 fish + 5 forage ----
	var birds: Array = d.get("birds", [])
	var fish: Array = d.get("fish", [])
	var forage_notes := []
	for i in d.get("ingredients", []):
		if i.get("kind") == "forage" and i.has("note"):
			forage_notes.append(i["id"])
	check("12 bird notes", birds.size() == 12, "got %d" % birds.size())
	# fish count grows with sites — assert every kind is noted below
	check("fish notes exist", fish.size() >= 5,
		"got %d" % fish.size())
	check("5 forage notes", forage_notes.size() == 5,
		str(forage_notes))
	# every catchable fish has a Field Notes row (incl. Golden Koi)
	var fish_note_ids := _ids("fish")
	for i in d.get("ingredients", []):
		if i.get("kind") == "fish":
			check("fish note for %s" % i["id"],
				String(i["id"]) in fish_note_ids)
	check("golden koi noted", "golden_koi" in fish_note_ids)

	# --- layouts: pads, campfire, errands, nav -------------------------
	for site in site_ids:
		var L: Dictionary = d["layouts"][site]
		check("%s has pad spots" % site,
			not L.get("pads", {}).get("spots", {}).is_empty())
		check("%s has a campfire" % site, L.get("campfire", {})
			.get("cell") != null)
		var es: Dictionary = L.get("errand_spots", {})
		check("%s forage+lookout spots" % site,
			es.has("forage") and es.has("lookout"))
		check("%s has a fishable bank" % site,
			es.has("pond") or es.has("stream")
				or not es.get("fishing", {}).is_empty())
		check("%s nav.blocked authored" % site,
			L.get("nav", {}).has("blocked"))

	# --- letters + vignettes: every reference resolves -----------------
	var pages_per_site := {}
	for c in d.get("chapters", []):
		pages_per_site[String(c["id"])] = c.get("pages", []).size()
	var letter_ids := []
	for l in letters:
		letter_ids.append(String(l["id"]))
		check("letter %s site valid" % l["id"],
			String(l["site"]) in site_ids
			or String(l["site"]) == "any")
		# trigger vocabulary is {morning: site_day} | {event: festival}
		var tr: Dictionary = l.get("trigger", {})
		check("letter %s triggered" % l["id"], not tr.is_empty())
		for k in tr:
			check("letter %s trigger.%s known" % [l["id"], k],
				String(k) in ["morning", "event"])
		if tr.has("morning"):
			check("letter %s morning is a day" % l["id"],
				int(tr["morning"]) >= 1)
		if tr.has("event"):
			# events are journal names: engine-emitted literals,
			# fund tiers, or a regular_done:<id> / page:<n> form
			var ev := String(tr["event"])
			var emitted := ["family_booked", "chapter_done",
				"fire_lit", "golden_koi", "photo_wall",
				"soggy_camp", "heat_wave", "wild_storm", "wet_streak"]
			var fund_names := []
			for ft in d.get("fund", {}).get("tiers", []):
				fund_names.append(String(ft.get("event", "")))
			var ev_ok := ev in emitted or ev in fund_names \
				or (ev.begins_with("regular_done:")
					and ev.get_slice(":", 1) in regulars) \
				or (ev.begins_with("page:")
					and ev.get_slice(":", 1).is_valid_int()
					and int(ev.get_slice(":", 1)) <= int(
						pages_per_site.get(String(l["site"]), 0)))
			check("letter %s event %s" % [l["id"], ev], ev_ok)
	check("letter ids unique", letter_ids.size() == \
		_Unique.size_of(letter_ids))
	var meal_ids := recipes
	for v in d.get("vignettes", []):
		var tr: Dictionary = v.get("trigger", {})
		if tr.has("decor"):
			check("vignette %s decor" % v["id"],
				String(tr["decor"]) in decor)
		if tr.has("trait"):
			check("vignette %s trait" % v["id"],
				String(tr["trait"]) in traits)
		if tr.has("archetype"):
			check("vignette %s archetype" % v["id"],
				String(tr["archetype"]) in archetypes or
				tr["archetype"] == "family" or tr["archetype"] == "kids")
		if tr.has("regular"):
			check("vignette %s regular" % v["id"],
				String(tr["regular"]) in regulars)
		if tr.has("crew_restored"):
			check("vignette %s structure" % v["id"],
				String(tr["crew_restored"]) in crew_ids)
		if tr.has("event"):
			check("vignette %s event" % v["id"],
				String(tr["event"]) in festivals)
		if tr.has("meal"):
			check("vignette %s meal" % v["id"],
				String(tr["meal"]) in meal_ids)

	# --- chapters: page unlocks resolve to real content; check rows ---
	# --- use only vocabulary _goal_met understands --------------------
	var unlockables := decor + gear + ingredients
	unlockables.append_array(["outfitter", "platform", "oven",
		"staples", "cabin"])
	var counter_keys := ["guests_welcomed", "families", "anglers_water",
		"oven_recipes", "gatherings_met", "fish_kinds"]
	var night_keys := ["five_stars", "stargazer_five", "pads_filled",
		"all5", "full4", "rain_full4", "min_stars"]
	for c in d.get("chapters", []):
		check("chapter %s site valid" % c["id"],
			String(c["id"]) in site_ids)
		var pages: Array = c.get("pages", [])
		for i in pages.size():
			var p: Dictionary = pages[i]
			check("chapter %s page %d contiguous" % [c["id"], i],
				int(p.get("n", -1)) == i + 1)
			for u in p.get("unlocks", []):
				check("P%s unlock %s resolves" % \
					[p.get("n"), u],
					String(u) in unlockables)
			var ch: Dictionary = p.get("check", {})
			check("chapter %s P%s has a check" % [c["id"], p["n"]],
				not ch.is_empty())
			for k in ch:
				check("chapter %s P%s check.%s known" % \
					[c["id"], p["n"], k],
					String(k) in ["event", "restored",
						"night", "metric", "target"])
			if ch.has("restored"):
				check("chapter %s P%s restored %s" % \
					[c["id"], p["n"], ch["restored"]],
					String(ch["restored"]) in crew_ids)
			if ch.has("night"):
				check("chapter %s P%s night key %s" % \
					[c["id"], p["n"], ch["night"]],
					String(ch["night"]) in night_keys)
			if ch.has("metric"):
				var met := String(ch["metric"])
				var ok := met in counter_keys \
					or met in ["rating", "recipes"] \
					or (met.begins_with("regular_visits:")
						and met.get_slice(":", 1) in regulars)
				check("chapter %s P%s metric %s" % \
					[c["id"], p["n"], met], ok)

	# --- regulars: site + cadence + refs all resolve -------------------
	for r in d.get("regulars", []):
		check("regular %s site valid" % r["id"],
			String(r["site"]) in site_ids)
		var every := int(r.get("every", 0))
		if not bool(r.get("weekend_only", false)):
			check("regular %s has cadence" % r["id"], every >= 1)
			check("regular %s offset >= 1" % r["id"],
				int(r.get("offset", 0)) >= 1)
		check("regular %s archetype" % r["id"],
			String(r.get("archetype", "")) in archetypes)
		check("regular %s favourite is a recipe" % r["id"],
			String(r.get("favourite", "")) in recipes)
		for t in r.get("traits", []):
			check("regular %s trait %s" % [r["id"], t],
				String(t) in traits)

	# --- festivals: a real site-day ------------------------------------
	for f in d.get("festivals", []):
		check("festival %s site_day >= 1" % f["id"],
			int(f.get("site_day", 0)) >= 1)

	# --- fish + ingredients: taxonomy stays inside the consumers ------
	for f in d.get("fish", []):
		check("fish %s site valid" % f["id"],
			String(f["site"]) in site_ids)
		check("fish %s has a note" % f["id"],
			String(f.get("note", "")) != "")
	for i in d.get("ingredients", []):
		check("ingredient %s kind known" % i["id"],
			String(i.get("kind", "")) in ["forage", "fish", "staple"])

	# --- sites: archetype/trait tables only name real content -----------
	for s in d.get("sites", []):
		for a in s.get("archetype_mix", {}):
			check("%s mix archetype %s" % [s["id"], a],
				String(a) in archetypes)
		for t in s.get("trait_pool", {}):
			check("%s pool trait %s" % [s["id"], t],
				String(t) in traits)

	# --- decor sockets point at pieces the sim can seat -----------------
	for r in d.get("decor", []):
		for so in r.get("sockets", []):
			check("socket %s.%s is a sit_spot" % [r["id"], so["id"]],
				String(so.get("kind", "")) == "sit_spot"
				and so.has("px_offset"))

	# --- dialogue: §5.6 rows must name real sites/anchors, only use ---
	# --- when-keys the engine understands -----------------------------
	var dlg_ids := []
	for r in d.get("dialogue", []):
		dlg_ids.append(String(r["id"]))
		check("dialogue %s site valid" % r["id"],
			String(r["site"]) in site_ids)
		check("dialogue %s anchor valid" % r["id"],
			String(r["anchor"]) in ["mai", "warden", "dog"])
		check("dialogue %s has lines" % r["id"],
			not r.get("lines", []).is_empty())
		check("dialogue %s is day- or when-scoped" % r["id"],
			r.has("day") or not r.get("when", {}).is_empty())
		for k in r.get("when", {}):
			check("dialogue %s when.%s known" % [r["id"], k],
				String(k) in ["last_stars_min", "last_weather",
					"served_favourite", "regular_visit",
					"first_night", "last_event", "returning_min",
					"weather_streak", "wishes_met_min"])
			if k == "weather_streak":
				check("dialogue %s streak kind" % r["id"],
					String(r["when"][k]) in ["clear", "rain", "storm"])
			if k == "last_event":
				check("dialogue %s event %s" % [r["id"], r["when"][k]],
					String(r["when"][k]) in festivals)
			if k == "regular_visit":
				check("dialogue %s regular %s" % [r["id"], r["when"][k]],
					String(r["when"][k]) in regulars)
	check("dialogue ids unique", dlg_ids.size() == _Unique.size_of(dlg_ids))
	for site in site_ids:
		var n := 0
		for r in d.get("dialogue", []):
			if String(r["site"]) == site:
				n += 1
		check("%s has dialogue rows" % site, n >= 2, "got %d" % n)

	# --- photos: LV signature rows are self-contained ---------------
	var photo_ids := []
	for p in d.get("photos", []):
		photo_ids.append(String(p["id"]))
		check("photo %s named+noted" % p["id"],
			String(p.get("name", "")) != ""
			and String(p.get("note", "")) != "")
		check("photo %s priced" % p["id"], int(p.get("coins", -1)) >= 0)
	check("photo ids unique", photo_ids.size() == _Unique.size_of(photo_ids))
	check("camera gear exists", "camera" in gear)

	# --- fund: tiers ascend, events unique, grants are real decor ---
	var fund_events := []
	var prev_coins := -1
	for t in d.get("fund", {}).get("tiers", []):
		var c := int(t.get("coins", 0))
		check("fund tier %s ascends" % t.get("event", "?"), c > prev_coins)
		prev_coins = c
		fund_events.append(String(t.get("event", "")))
		check("fund tier %s named" % t["event"],
			String(t.get("event", "")) != "")
		var grant := String(t.get("grant", ""))
		if grant != "":
			check("fund grant %s is decor" % grant, grant in decor)
	check("fund events unique",
		fund_events.size() == _Unique.size_of(fund_events))

	# --- variants: cosmetic skins price sanely on real rows ---------
	for row in d.get("decor", []):
		for v in row.get("variants", {}):
			check("variant %s.%s priced" % [row["id"], v],
				int(row["variants"][v]) >= 0)
		# E:-gated rows must point at events the fund actually emits
		var un := String(row.get("unlock", ""))
		if un.begins_with("E:fund_tier"):
			check("decor %s E-unlock emitted" % row["id"],
				un.get_slice(":", 1) in fund_events)

	# --- letters may roam: "any" is a legal site for wandering mail -
	for l in d.get("letters", []):
		if String(l.get("site", "")) == "any":
			check("any-letter %s is event-triggered" % l["id"],
				String(l.get("trigger", {}).get("event", "")) != "")

	# --- wishes: the dealt kinds are exactly the engine's vocabulary,
	# --- every regular's authored wish is a real kind their home
	# --- site can satisfy --------------------------------------------
	var wish_ids := []
	for w in d.get("wishes", []):
		wish_ids.append(String(w["id"]))
		check("wish %s labelled" % w["id"],
			String(w.get("label", "")) != "")
	check("wish ids unique", wish_ids.size() == _Unique.size_of(wish_ids))
	var engine_wishes := ["fire", "quiet", "company", "solo", "water",
		"view", "lit", "sky", "together"]
	for k in engine_wishes:
		check("engine wish %s catalogued" % k, k in wish_ids)
	for k in wish_ids:
		check("catalogued wish %s emitted" % k, k in engine_wishes)
	# tag wishes are only issuable where a pad carries the tag
	var tag_wishes := {"water": false, "view": false}
	for lyt in d.get("layouts", {}).values():
		for p in lyt.get("pads", {}).get("tags", {}).keys():
			for tg in lyt["pads"]["tags"][p]:
				if String(tg) in tag_wishes:
					tag_wishes[String(tg)] = true
	for tw in tag_wishes:
		check("tag wish %s has a home" % tw, tag_wishes[tw])
	# a regular's authored wish bypasses the runtime capability gate,
	# so lint must prove their home site can always grant it — tags,
	# fire-ring coverage, open sky, an adjacent pair. `lit` is the
	# exception: it rides on placed decor, so no regular may ask for it.
	for r in d.get("regulars", []):
		var wk := String(r.get("wish", ""))
		if wk == "":
			continue
		check("regular %s wish is a kind" % r["id"], wk in wish_ids)
		var rsite := String(r.get("site", ""))
		var rlyt: Dictionary = d.get("layouts", {}).get(rsite, {})
		var rspots: Dictionary = rlyt.get("pads", {}).get("spots", {})
		var rnbrs: Dictionary = rlyt.get("pads", {}).get("neighbours", {})
		var label := "regular %s wish %s fits %s" % [r["id"], wk, rsite]
		if wk in tag_wishes:
			var has_tag := false
			for p in rlyt.get("pads", {}).get("tags", {}).keys():
				if wk in rlyt["pads"]["tags"][p]:
					has_tag = true
			check(label, has_tag)
		elif wk == "together":
			check(label, int(r.get("pads", 1)) >= 2
				and not rnbrs.is_empty())
		elif wk == "company" or wk == "solo":
			check(label, not rnbrs.is_empty())
		elif wk == "fire":
			var cf: Dictionary = rlyt.get("campfire", {})
			var cc: Array = cf.get("cell", [])
			var in_ring := false
			for p in rspots:
				var pc: Array = rspots[p]
				if cc.size() == 2 and pc.size() >= 2 \
						and maxi(absi(int(pc[0]) - int(cc[0])),
							absi(int(pc[1]) - int(cc[1]))) \
							<= int(cf.get("radius", 2)):
					in_ring = true
			check(label, in_ring)
		elif wk == "sky":
			# bare pads always exist unless the player cabins every
			# spot — an authored wish only needs the site to have pads
			check(label, not rspots.is_empty())
		elif wk == "lit":
			check(label, false)
		# quiet/fire-adjacent relational kinds are always grantable

	# --- margins: sequential rows, hints resolve to real state ------
	var margin_ids := []
	for m in d.get("margins", []):
		margin_ids.append(String(m["id"]))
		check("margin %s has text" % m["id"],
			String(m.get("text", "")) != "")
		var hint: Dictionary = m.get("hint", {})
		var hk := String(hint.get("kind", ""))
		if hk == "":
			continue
		check("margin %s hint kind" % m["id"],
			hk in ["weather", "recipe"])
		if hk == "recipe":
			var pair: Array = hint.get("pair", [])
			check("margin %s pair shaped" % m["id"], pair.size() == 2)
			for ing in pair:
				check("margin %s pair item %s" % [m["id"], ing],
					String(ing) in d.get("ingredients", []).map(
						func(i): return String(i["id"])))
			check("margin %s recipe resolves" % m["id"],
				String(hint.get("recipe", "")) in \
					d.get("recipes", []).map(
						func(r): return String(r["id"])))
	check("margin ids unique",
		margin_ids.size() == _Unique.size_of(margin_ids))

	# Runtime mirror stays in sync — Catalog.validate() is the
	# load-time guard, this scene the verbose gate (§21.2).
	var verrs: PackedStringArray = Catalog.validate()
	check("Catalog.validate() clean", verrs.is_empty(),
		str(verrs.slice(0, 3)))

	finish()


class _Unique:
	static func size_of(ids: Array) -> int:
		var seen := {}
		for i in ids:
			seen[i] = true
		return seen.size()
