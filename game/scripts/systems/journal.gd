extends RefCounted
## Journal layer (§8/§13/§6.7): letters, Field Notes, page/chapter
## progression and the unlock ladder. Leaf subsystem — no save state
## here; everything reads/mutates `g` (the Game autoload). Public
## reads stay one-line delegates on Game so the UI never re-plumbs.

var g  # the Game autoload (untyped: circular ref)


func _init(game) -> void:
	g = game


# ------------------------------------------------------------- letters (§8.2/§13)
#
# Letters arrive in order, at most one per morning; event-triggered
# letters go first and unread ones wait in the journal.

func _letters_for(site := &"") -> Array:
	if site == &"":
		site = g.site_id
	# "any" = the wandering mailbag — delivers at whatever site is
	# current (fund-tier mail, campaign letters that don't wait home)
	return Catalog.data.get("letters", []).filter(
		func(l): return l.get("site") == site or l.get("site") == "any")


func _letter_due(l: Dictionary, st: Dictionary) -> bool:
	var tr: Dictionary = l.get("trigger", {})
	if tr.has("morning"):
		# engagement pulse — nobody writes to a campground nobody
		# visited: day-gated mail also needs a settled guest, so a
		# sleep-binge can't hoover the correspondence (§8.2). The
		# exception: a site's morning-1 letter is the *arrival*
		# greeting — it welcomes the warden, not the guests, so it
		# doesn't wait for a stay.
		return g.site_day() >= int(tr["morning"]) \
			and (int(st["counters"]["guests_welcomed"]) >= 1 \
				or int(tr["morning"]) == 1)
	var ev: String = tr.get("event", "")
	match ev:
		"family_booked":
			return st["counters"]["events"].has("family_booked")
		"chapter_done":
			return chapter_done(g.site_id)
		_:
			if ev.begins_with("regular_done:"):
				return _story_done(ev.get_slice(":", 1))
			if ev.begins_with("page:"):
				return page_done(int(ev.get_slice(":", 1)))
			# any other journal event name, at any site — fund tiers
			# and other global events travel with the warden
			for s in g.sites.values():
				if s["counters"]["events"].has(ev):
					return true
			return false
	return false


## One letter per morning, event triggers before morning triggers,
## both in written order (§8.2).
func _deliver_letter(st: Dictionary) -> void:
	var delivered: Array = st["letters_delivered"]
	for want_event in [true, false]:
		for l in _letters_for():
			var is_any := String(l.get("site", "")) == "any"
			if l["id"] in delivered \
					or (is_any and l["id"] in g.letters_delivered_any):
				continue
			if (l.get("trigger", {}).has("event")) != want_event:
				continue
			if _letter_due(l, st):
				delivered.append(l["id"])
				if is_any:
					g.letters_delivered_any.append(l["id"])
				g._log("letter_delivered", {"id": l["id"]})
				g.letter_delivered.emit(l)
				return


## Journal API: delivered-but-unread letters for this site.
func unread_letters(site := &"") -> Array:
	if site == &"":
		site = g.site_id
	var st: Dictionary = g.site_state(site)
	return _letters_for(site).filter(func(l):
		return l["id"] in st["letters_delivered"] \
			and l["id"] not in g.letters_read)


func read_letter(id: String) -> void:
	if id not in g.letters_read:
		g.letters_read.append(id)
		g._log("letter", {"id": id})
		Analytics.log_event(&"letter_open", {"id": id})
		g.touch()


## Delivered letters for a site, unread first — the journal list.
func letters_for(site := &"") -> Array:
	if site == &"":
		site = g.site_id
	var st: Dictionary = g.site_state(site)
	return _letters_for(site).filter(func(l):
		return l["id"] in st["letters_delivered"])


## One delivered letter by id (the reading view).
func letter(id: String, site := &"") -> Dictionary:
	if site == &"":
		site = g.site_id
	for l in _letters_for(site):
		if l["id"] == id:
			return l
	return {}


## spec 005: `when` blocks make a dialogue row conditional on last
## night's resolution — the morning delivery pass prefers a matching
## `when` row over a plain `day` row; unmatched rows stay silent and
## every row remains once-ever via dialogue_seen.
func dialogue_when_ok(when: Dictionary) -> bool:
	var last: Dictionary = g.days_log.back() \
		if not g.days_log.is_empty() else {}
	for k in when:
		match String(k):
			"last_stars_min":
				if int(last.get("best", 0)) < int(when[k]):
					return false
			"last_weather":
				if String(last.get("weather", "")) != String(when[k]):
					return false
			"served_favourite":
				if not bool(last.get("fav_served", false)):
					return false
			"regular_visit":
				if String(when[k]) not in last.get("regulars", []):
					return false
			"last_event":
				if String(last.get("event", "")) != String(when[k]):
					return false
			"returning_min":
				if int(last.get("returners", 0)) < int(when[k]):
					return false
			"wishes_met_min":
				if int(last.get("wishes_met", 0)) < int(when[k]):
					return false
			"weather_streak":
				# a streak is ≥3 — one wet day is weather, not a season
				var ws: Dictionary = g.site_state() \
					.get("weather_streak", {})
				if String(ws.get("kind", "")) != String(when[k]) \
						or int(ws.get("days", 0)) < 3:
					return false
			"first_night":
				var n: int = g.days_log.filter(func(d): return \
					d.get("site") == String(g.site_id)).size()
				if n != 1:
					return false
			_:
				return false
	return true


# ------------------------------------------------------- journal UI (§8.3)

const JOURNAL_SITES := [&"pinewatch", &"whisper_river", &"lantern_valley"]

func chapter_pages(site := &"") -> Array:
	if site == &"":
		site = g.site_id
	return _chapter(site).get("pages", [])


## Keepsake catalog row by id — {label, art, note_key} + who held it.
func keepsake(id: String) -> Dictionary:
	for s in g._structures():
		for stage in s.get("stages", []):
			var k: Dictionary = stage.get("keepsake", {})
			if k.get("id") == id:
				var out := k.duplicate()
				out["site"] = s["id"]
				return out
	return {}


## §8.3 cover count: collected / total over the five fill-in
## sections (chapters v1 pages, guestbook, field notes, recipes,
## keepsakes). Letters + days log don't count — they write
## themselves.
func journal_completion() -> Dictionary:
	var done := 0
	var total := 0
	for s in JOURNAL_SITES:
		var pd: Array = g.site_state(s)["pages_done"]
		done += pd.filter(func(n): return int(n) <= 5).size()
		total += 5
	var archs: Array = Catalog.data.get("archetypes", [])
	var regs: Array = Catalog.data.get("regulars", [])
	total += archs.size() + regs.size()
	done += mini(g.personas_met.size(), archs.size())
	var met_regs := {}
	for s in JOURNAL_SITES:
		var v: Dictionary = g.site_state(s)["counters"].get(
			"regular_visits", {})
		for k in v:
			met_regs[k] = true
	done += met_regs.size()
	# §8.3 Field Notes: 5 forage finds + 5 fish + 12 birds — the
	# catalog rows carry the note text; field_notes holds the ids.
	var notes := _field_note_rows()
	total += notes.size()
	done += mini(g.field_notes.size(), notes.size())
	var recipe_total: int = Catalog.data.get("recipes", []).size()
	total += recipe_total
	done += mini(g.recipes_cooked.size(), recipe_total)
	var ks_total: int = Catalog.data.get("crew", {}).get(
		"structures", []).size()
	total += ks_total
	done += mini(g.crew["collected"].size(), ks_total)
	return {"done": done, "total": total}


## Every Field Notes entry across the three catalogs — birds
## (spotting), fish (fishing, incl. the Golden Koi) and forage finds
## (first gather). The journal sheet renders this; `seen` comes
## straight off field_notes so a mid-day catch shows at once.
func field_notes_catalog() -> Dictionary:
	var out := {"birds": [], "fish": [], "forage": []}
	for row in Catalog.data.get("birds", []):
		out["birds"].append(_note_row(row))
	for row in Catalog.data.get("fish", []):
		out["fish"].append(_note_row(row))
	for row in Catalog.data.get("ingredients", []):
		if row.get("kind") == "forage" and row.has("note"):
			out["forage"].append(_note_row(row))
	return out


func _note_row(row: Dictionary) -> Dictionary:
	return {"id": row["id"], "name": row.get("name", ""),
		"site": row.get("site", row.get("sites", "")),
		"note": row.get("note", ""), "seen": row["id"] in g.field_notes}


func _field_note_rows() -> Array:
	var out: Array = Catalog.data.get("birds", []).duplicate()
	out.append_array(Catalog.data.get("fish", []))
	for i in Catalog.data.get("ingredients", []):
		if i.get("kind") == "forage" and i.has("note"):
			out.append(i)
	return out


## First-find/catch hook — errands call this so Field Notes covers
## forage + fish the same way spotting covers birds (§8.3).
func _note_find(id: String) -> void:
	if id == "" or id in g.field_notes:
		return
	for row in _field_note_rows():
		if row.get("id") == id:
			g.field_notes.append(id)
			g._log("field_note", {"id": id})
			_check_pages()
			return


## Site display name for journal headers.
func site_name(id: StringName) -> String:
	for s in Catalog.data.get("sites", []):
		if s.get("id") == id:
			return s.get("name", String(id))
	return String(id)


# ------------------------------------------------------------- journal (§8)
#
# Each site's chapter holds five pages; a page's "check" is evaluated
# against that site's counters plus whatever happened tonight. Pages
# complete in any order, pay their gift, and register their unlocks.

func _chapter(site := &"") -> Dictionary:
	if site == &"":
		site = g.site_id
	for c in Catalog.data.get("chapters", []):
		if c.get("id") == site:
			return c
	return {}


## Evaluate one page check. `night` carries same-night metrics
## (five_stars, pads_filled, stargazer_five) from Goodnight.
func _goal_met(check: Dictionary, st: Dictionary,
		night: Dictionary) -> bool:
	var cnt: Dictionary = st["counters"]
	if check.has("event"):
		return cnt["events"].has(check["event"])
	if check.has("restored"):
		return check["restored"] in st["restored"]
	if check.has("night"):
		return int(night.get(check["night"], 0)) >= int(check["target"])
	var metric: String = check.get("metric", "")
	var target := int(check.get("target", 1))
	match metric:
		"rating":
			return st["reviews"].size() >= 15 \
				and g.rating() >= float(check["target"])
		"recipes":
			return g.recipes_cooked.size() >= target
		"fish_kinds":
			return cnt["fish_kinds"].size() >= target
		_:
			if metric.begins_with("regular_visits:"):
				return int(cnt["regular_visits"].get(
					metric.get_slice(":", 1), 0)) >= target
			return int(cnt.get(metric, 0)) >= target


## External events (tutorial steps, scripted moments) — e.g.
## journal_event("fire_lit") when the player relights the campfire.
func journal_event(name: String) -> void:
	g.site_state()["counters"]["events"][name] = true
	g._log("event", {"id": name})
	Analytics.log_event(&"tutorial_step", {"step": name})
	_check_pages()


func _bump(metric: String, n := 1) -> void:
	var cnt: Dictionary = g.site_state()["counters"]
	cnt[metric] = int(cnt.get(metric, 0)) + n


## Complete every met-but-undone page for the current site; returns
## the pages finished this call so the report/UI can celebrate them.
func _check_pages(night := {}) -> Array:
	var st: Dictionary = g.site_state()
	var open2 := vol2_open()
	var done := []
	for page in _chapter().get("pages", []):
		var n := int(page["n"])
		if n in st["pages_done"]:
			continue
		if int(page.get("vol", 1)) == 2 and not open2:
			continue                               # §33.3: post-finale
		if not _goal_met(page.get("check", {}), st, night):
			continue
		st["pages_done"].append(n)
		g.coins += int(page.get("gift", 0))
		g._log("page", {"site": String(g.site_id), "n": n,
			"gift": int(page.get("gift", 0))})
		Analytics.log_event(&"page_complete", {"site": String(g.site_id),
			"page": n})
		Platform.unlock_achievement(
			StringName("page_%s_%d" % [g.site_id, n]))
		if chapter_done(g.site_id):
			Platform.unlock_achievement(
				StringName("chapter_%s" % g.site_id))
		g.page_completed.emit(g.site_id, n, int(page.get("gift", 0)),
			page.get("unlocks", []))
		done.append(page)
	# The 15th Vol II page hides grandpa's last keepsake (§33.3).
	if done.size() > 0 and vol2_done() \
			and "the_second_volume" not in g.crew["collected"]:
		g.crew["collected"].append("the_second_volume")
	return done


## §33.3: the player's own volume opens the morning after the finale
## (all three v1 chapters stamped).
func vol2_open() -> bool:
	return chapter_done(&"lantern_valley")


func vol2_done() -> bool:
	for site in [&"pinewatch", &"whisper_river", &"lantern_valley"]:
		var pd: Array = g.site_state(site)["pages_done"]
		for n in [6, 7, 8, 9, 10]:
			if n not in pd:
				return false
	return true


func page_done(page: int, site := &"") -> bool:
	if site == &"":
		site = g.site_id
	return page in g.site_state(site)["pages_done"]


## spec 005-D: the morning-after wag — last resolved night was
## all-5★ (min_stars on the days_log tail is the law).
func last_night_perfect() -> bool:
	return not g.days_log.is_empty() \
		and int(g.days_log[-1].get("min_stars", 0)) >= 5


## A chapter finishes when all five v1 pages are stamped — it opens
## the next site (§8.1). Vol II pages (6-10) don't count toward it.
func chapter_done(site: StringName) -> bool:
	return g.site_state(site)["pages_done"].filter(
		func(n): return int(n) <= 5).size() >= 5


## Unlock strings: "P3" = Pinewatch page 3, "W0" = Whisper River
## arrival (chapter 1 done), "W2" = its page 2, "L0" = chapter 2 done.
## Public read of the §6.7 unlock ladder — shop/gallery rows ask
## this instead of duplicating the letter-page rule.
func is_unlocked(unlock: String) -> bool:
	return _is_unlocked(unlock)


func _is_unlocked(unlock: String) -> bool:
	if unlock == "":
		return true
	if unlock.begins_with("S:"):
		return _story_done(unlock.get_slice(":", 1))
	if unlock.begins_with("E:"):
		# event-gated catalog rows — the grant is earned anywhere,
		# so check every site's event ledger (fund tiers, photo wall)
		for s in g.sites.values():
			if s["counters"]["events"].has(unlock.get_slice(":", 1)):
				return true
		return false
	var letter_sites := {"P": &"pinewatch", "W": &"whisper_river",
		"L": &"lantern_valley"}
	var site: StringName = letter_sites[unlock.left(1)]
	var n := int(unlock.substr(1))
	if n == 0:                                   # "arrival" unlocks
		match site:
			&"pinewatch": return true
			&"whisper_river": return chapter_done(&"pinewatch")
			&"lantern_valley": return chapter_done(&"whisper_river")
	return n in g.site_state(site)["pages_done"]


func site_reachable(site: StringName) -> bool:
	match site:
		&"pinewatch": return true
		&"whisper_river": return chapter_done(&"pinewatch")
		&"lantern_valley": return chapter_done(&"whisper_river")
	return false


## §12.3: a regular's story ends after story_visits seated stays —
## it unlocks the story gift (Hùng's Scout Pennant).
func _story_done(reg_id: String) -> bool:
	for reg: Dictionary in Catalog.data.get("regulars", []):
		if reg.get("id") == reg_id:
			var cnt: Dictionary = g.site_state(
				reg.get("site"))["counters"]
			return int(cnt["regular_visits"].get(reg_id, 0)) \
				>= int(reg.get("story_visits", 3))
	return false
