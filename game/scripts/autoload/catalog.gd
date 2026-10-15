extends Node
## Catalog — loads and validates game/data JSON, serves items, traits,
## recipes and pages (GDD 21.1-21.2). IDs are stable snake_case; saves
## store IDs, never indexes.

const DATA_DIR := "res://data/"

## file stem -> parsed JSON (Array or Dictionary)
var data: Dictionary = {}


func _ready() -> void:
	var errors := load_all()
	errors.append_array(validate())
	for error in errors:
		push_error("Catalog: " + error)


func load_all() -> PackedStringArray:
	var errors: PackedStringArray = []
	for file in DirAccess.get_files_at(DATA_DIR):
		if not file.ends_with(".json"):
			continue
		var stem := file.get_basename()
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(DATA_DIR + file))
		if parsed == null:
			errors.append("%s: invalid JSON" % file)
			continue
		data[stem] = parsed
	data["layouts"] = {}
	for file in DirAccess.get_files_at(DATA_DIR + "layouts/"):
		if not file.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(DATA_DIR + "layouts/" + file))
		if parsed is Dictionary and parsed.has("site_id"):
			data["layouts"][parsed["site_id"]] = parsed
		elif parsed == null:
			errors.append("layouts/%s: invalid JSON" % file)
		else:
			errors.append("layouts/%s: missing site_id" % file)
	return errors


## §21.2 CI rules land here as they grow: every reference resolves,
## every unlock reachable, no page needs an item from a later page.
## Runtime mirror of tests/test_content.tscn — the scene stays the
## verbose gate, this stays the load-time guard so unchecked data can
## never reach the sim.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	var d: Dictionary = data
	if d.is_empty():
		return PackedStringArray(["catalog empty"])
	var ingredients: Array = _ids_for("ingredients")
	var recipes: Array = _ids_for("recipes")
	var decor: Array = _ids_for("decor")
	var gear: Array = _ids_for("gear")
	var archetypes: Array = _ids_for("archetypes")
	var traits: Array = _ids_for("traits")
	var regulars: Array = _ids_for("regulars")
	var festivals: Array = _ids_for("festivals")
	var crew_ids: Array = []
	for s in d.get("crew", {}).get("structures", []):
		crew_ids.append(String(s.get("id", "")))
	var site_ids: Array = (d.get("layouts", {}) as Dictionary).keys()
	# Recipes resolve.
	for r in d.get("recipes", []):
		for ing in r.get("pair", []):
			if ing != "any_fish" and ing not in ingredients:
				errors.append("recipe %s->%s" % [r.get("id", "?"), ing])
	# Festivals.
	for f in d.get("festivals", []):
		if String(f.get("site", "")) not in site_ids:
			errors.append("festival %s site" % f.get("id", "?"))
		if String(f.get("dish", "")) not in recipes:
			errors.append("festival %s dish" % f.get("id", "?"))
		var v_ok := false
		for v in d.get("vignettes", []):
			if v.get("trigger", {}).get("event", "") == f.get("id", ""):
				v_ok = true
		if not v_ok:
			errors.append("festival %s vignette" % f.get("id", "?"))
		for a in f.get("archetype_boost", {}):
			if String(a) not in archetypes:
				errors.append("festival %s boost %s" % [f.get("id", "?"), a])
		if int(f.get("site_day", 0)) < 1:
			errors.append("festival %s site_day" % f.get("id", "?"))
	# Layouts.
	for site in site_ids:
		var L: Dictionary = (d["layouts"] as Dictionary)[site]
		if (L.get("pads", {}) as Dictionary).get("spots", {}).is_empty():
			errors.append("%s pads" % site)
		if (L.get("campfire", {}) as Dictionary).get("cell") == null:
			errors.append("%s campfire" % site)
		var es: Dictionary = L.get("errand_spots", {})
		if not (es.has("forage") and es.has("lookout")):
			errors.append("%s forage+lookout" % site)
		if not (es.has("pond") or es.has("stream") \
				or not (es.get("fishing", {}) as Dictionary).is_empty()):
			errors.append("%s fishable" % site)
		if not (L.get("nav", {}) as Dictionary).has("blocked"):
			errors.append("%s nav.blocked" % site)
	# Letters + vignettes.
	var pages_per_site := {}
	for c in d.get("chapters", []):
		pages_per_site[String(c.get("id", ""))] = (c.get("pages", []) as Array).size()
	var letter_ids: Array = []
	for l in d.get("letters", []):
		letter_ids.append(String(l.get("id", "")))
		if String(l.get("site", "")) not in site_ids \
				and String(l.get("site", "")) != "any":
			errors.append("letter %s site" % l.get("id", "?"))
		var tr: Dictionary = l.get("trigger", {})
		if tr.is_empty():
			errors.append("letter %s trigger" % l.get("id", "?"))
		for k in tr:
			if String(k) not in ["morning", "event"]:
				errors.append("letter %s trigger.%s" % [l.get("id", "?"), k])
		if tr.has("morning") and int(tr["morning"]) < 1:
			errors.append("letter %s morning" % l.get("id", "?"))
		if tr.has("event"):
			var ev := String(tr["event"])
			var emitted := ["family_booked", "chapter_done",
				"fire_lit", "golden_koi", "photo_wall",
				"soggy_camp", "heat_wave", "wild_storm", "wet_streak"]
			var fund_names: Array = []
			for ft in d.get("fund", {}).get("tiers", []):
				fund_names.append(String(ft.get("event", "")))
			var ev_ok := ev in emitted or ev in fund_names \
				or (ev.begins_with("regular_done:") \
					and ev.get_slice(":", 1) in regulars) \
				or (ev.begins_with("page:") \
					and ev.get_slice(":", 1).is_valid_int() \
					and int(ev.get_slice(":", 1)) <= int(
						pages_per_site.get(String(l.get("site", "")), 0)))
			if not ev_ok:
				errors.append("letter %s event %s" % [l.get("id", "?"), ev])
		if String(l.get("site", "")) == "any" \
				and String(l.get("trigger", {}).get("event", "")) == "":
			errors.append("any-letter %s event" % l.get("id", "?"))
	if letter_ids.size() != _unique_n(letter_ids):
		errors.append("letter ids unique")
	for v in d.get("vignettes", []):
		var tr2: Dictionary = v.get("trigger", {})
		if tr2.has("decor") and String(tr2["decor"]) not in decor:
			errors.append("vignette %s decor" % v.get("id", "?"))
		if tr2.has("trait") and String(tr2["trait"]) not in traits:
			errors.append("vignette %s trait" % v.get("id", "?"))
		if tr2.has("archetype") and String(tr2["archetype"]) not in archetypes \
				and tr2["archetype"] != "family" and tr2["archetype"] != "kids":
			errors.append("vignette %s archetype" % v.get("id", "?"))
		if tr2.has("regular") and String(tr2["regular"]) not in regulars:
			errors.append("vignette %s regular" % v.get("id", "?"))
		if tr2.has("crew_restored") \
				and String(tr2["crew_restored"]) not in crew_ids:
			errors.append("vignette %s structure" % v.get("id", "?"))
		if tr2.has("event") and String(tr2["event"]) not in festivals:
			errors.append("vignette %s event" % v.get("id", "?"))
		if tr2.has("meal") and String(tr2["meal"]) not in recipes:
			errors.append("vignette %s meal" % v.get("id", "?"))
	# Chapters.
	var unlockables: Array = decor + gear + ingredients
	unlockables.append_array(["outfitter", "platform", "oven",
		"staples", "cabin"])
	var counter_keys := ["guests_welcomed", "families", "anglers_water",
		"oven_recipes", "gatherings_met", "fish_kinds"]
	var night_keys := ["five_stars", "stargazer_five", "pads_filled",
		"all5", "full4", "rain_full4", "min_stars"]
	for c in d.get("chapters", []):
		if String(c.get("id", "")) not in site_ids:
			errors.append("chapter %s site" % c.get("id", "?"))
		var pages: Array = c.get("pages", [])
		for i in pages.size():
			var p: Dictionary = pages[i]
			if int(p.get("n", -1)) != i + 1:
				errors.append("chapter %s page contiguous %d" % [c.get("id", "?"), i])
			for u in p.get("unlocks", []):
				if String(u) not in unlockables:
					errors.append("P%s unlock %s" % [p.get("n", "?"), u])
			var ch: Dictionary = p.get("check", {})
			if ch.is_empty():
				errors.append("chapter %s P%s check" % [c.get("id", "?"), p.get("n", "?")])
			for k in ch:
				if String(k) not in ["event", "restored",
						"night", "metric", "target"]:
					errors.append("chapter %s P%s check.%s" % \
						[c.get("id", "?"), p.get("n", "?"), k])
			if ch.has("restored") and String(ch["restored"]) not in crew_ids:
				errors.append("chapter %s P%s restored" % [c.get("id", "?"), p.get("n", "?")])
			if ch.has("night") and String(ch["night"]) not in night_keys:
				errors.append("chapter %s P%s night" % [c.get("id", "?"), p.get("n", "?")])
			if ch.has("metric"):
				var met := String(ch["metric"])
				var ok := met in counter_keys \
					or met in ["rating", "recipes"] \
					or (met.begins_with("regular_visits:") \
						and met.get_slice(":", 1) in regulars)
				if not ok:
					errors.append("chapter %s P%s metric %s" % \
						[c.get("id", "?"), p.get("n", "?"), met])
	# Regulars.
	for r in d.get("regulars", []):
		if String(r.get("site", "")) not in site_ids:
			errors.append("regular %s site" % r.get("id", "?"))
		if not bool(r.get("weekend_only", false)):
			if int(r.get("every", 0)) < 1:
				errors.append("regular %s cadence" % r.get("id", "?"))
			if int(r.get("offset", 0)) < 1:
				errors.append("regular %s offset" % r.get("id", "?"))
		if String(r.get("archetype", "")) not in archetypes:
			errors.append("regular %s archetype" % r.get("id", "?"))
		if String(r.get("favourite", "")) not in recipes:
			errors.append("regular %s favourite" % r.get("id", "?"))
		for t in r.get("traits", []):
			if String(t) not in traits:
				errors.append("regular %s trait %s" % [r.get("id", "?"), t])
	# Fish + ingredients.
	for f in d.get("fish", []):
		if String(f.get("site", "")) not in site_ids:
			errors.append("fish %s site" % f.get("id", "?"))
		if String(f.get("note", "")) == "":
			errors.append("fish %s note" % f.get("id", "?"))
	for gi in d.get("ingredients", []):
		if String(gi.get("kind", "")) not in ["forage", "fish", "staple"]:
			errors.append("ingredient %s kind" % gi.get("id", "?"))
	# Sites.
	for s in d.get("sites", []):
		for a in s.get("archetype_mix", {}):
			if String(a) not in archetypes:
				errors.append("%s mix %s" % [s.get("id", "?"), a])
		for t in s.get("trait_pool", {}):
			if String(t) not in traits:
				errors.append("%s pool %s" % [s.get("id", "?"), t])
	# Decor sockets / variants / E-unlocks.
	var fund_events: Array = []
	for t in d.get("fund", {}).get("tiers", []):
		fund_events.append(String(t.get("event", "")))
		if String(t.get("event", "")) == "":
			errors.append("fund tier unnamed")
		var grant := String(t.get("grant", ""))
		if grant != "" and grant not in decor:
			errors.append("fund grant %s" % grant)
	if fund_events.size() != _unique_n(fund_events):
		errors.append("fund events unique")
	for row in d.get("decor", []):
		for so in row.get("sockets", []):
			if String(so.get("kind", "")) != "sit_spot" or not so.has("px_offset"):
				errors.append("socket %s.%s" % [row.get("id", "?"), so.get("id", "?")])
		for vv in row.get("variants", {}):
			if int((row.get("variants", {}) as Dictionary)[vv]) < 0:
				errors.append("variant %s.%s price" % [row.get("id", "?"), vv])
		var un := String(row.get("unlock", ""))
		if un.begins_with("E:fund_tier") and un.get_slice(":", 1) not in fund_events:
			errors.append("decor %s E-unlock" % row.get("id", "?"))
	# Dialogue.
	var dlg_ids: Array = []
	for r in d.get("dialogue", []):
		dlg_ids.append(String(r.get("id", "")))
		if String(r.get("site", "")) not in site_ids:
			errors.append("dialogue %s site" % r.get("id", "?"))
		if String(r.get("anchor", "")) not in ["mai", "warden", "dog"]:
			errors.append("dialogue %s anchor" % r.get("id", "?"))
		if (r.get("lines", []) as Array).is_empty():
			errors.append("dialogue %s lines" % r.get("id", "?"))
		if not r.has("day") and (r.get("when", {}) as Dictionary).is_empty():
			errors.append("dialogue %s scope" % r.get("id", "?"))
		for k in r.get("when", {}):
			if String(k) not in ["last_stars_min", "last_weather",
					"served_favourite", "regular_visit",
					"first_night", "last_event", "returning_min",
					"weather_streak", "wishes_met_min"]:
				errors.append("dialogue %s when.%s" % [r.get("id", "?"), k])
	if dlg_ids.size() != _unique_n(dlg_ids):
		errors.append("dialogue ids unique")
	for site in site_ids:
		var n := 0
		for r in d.get("dialogue", []):
			if String(r.get("site", "")) == site:
				n += 1
		if n < 2:
			errors.append("%s dialogue rows" % site)
	# Photos / camera.
	var photo_ids: Array = []
	for p in d.get("photos", []):
		photo_ids.append(String(p.get("id", "")))
		if String(p.get("name", "")) == "" or String(p.get("note", "")) == "":
			errors.append("photo %s named" % p.get("id", "?"))
		if int(p.get("coins", -1)) < 0:
			errors.append("photo %s price" % p.get("id", "?"))
	if photo_ids.size() != _unique_n(photo_ids):
		errors.append("photo ids unique")
	if "camera" not in gear:
		errors.append("camera gear")
	# Wishes.
	var wish_ids: Array = []
	for w in d.get("wishes", []):
		wish_ids.append(String(w.get("id", "")))
		if String(w.get("label", "")) == "":
			errors.append("wish %s label" % w.get("id", "?"))
	if wish_ids.size() != _unique_n(wish_ids):
		errors.append("wish ids unique")
	var engine_wishes := ["fire", "quiet", "company", "solo", "water",
		"view", "lit", "sky", "together"]
	for k in engine_wishes:
		if k not in wish_ids:
			errors.append("engine wish %s" % k)
	for k in wish_ids:
		if k not in engine_wishes:
			errors.append("wish %s emitted" % k)
	# Margins.
	var margin_ids: Array = []
	for m in d.get("margins", []):
		margin_ids.append(String(m.get("id", "")))
		if String(m.get("text", "")) == "":
			errors.append("margin %s text" % m.get("id", "?"))
		var hint: Dictionary = m.get("hint", {})
		var hk := String(hint.get("kind", ""))
		if hk == "":
			continue
		if hk not in ["weather", "recipe"]:
			errors.append("margin %s hint" % m.get("id", "?"))
		if hk == "recipe":
			var pair: Array = hint.get("pair", [])
			if pair.size() != 2:
				errors.append("margin %s pair" % m.get("id", "?"))
			for ing in pair:
				if String(ing) not in ingredients:
					errors.append("margin %s pair %s" % [m.get("id", "?"), ing])
			if String(hint.get("recipe", "")) not in recipes:
				errors.append("margin %s recipe" % m.get("id", "?"))
	if margin_ids.size() != _unique_n(margin_ids):
		errors.append("margin ids unique")
	return errors


func _ids_for(list_name: String) -> Array:
	var out: Array = []
	for r in data.get(list_name, []):
		out.append(String(r.get("id", "")))
	return out


func _unique_n(ids: Array) -> int:
	var seen := {}
	for i in ids:
		seen[i] = true
	return seen.size()
