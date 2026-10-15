extends "res://tests/harness.gd"
## Save migration + undo spine + golden replay (§22, D2.2/D2.4, §30).
## Run:
##   godot --headless --path game tests/test_save.tscn
## Exit code = number of failed checks.


## A day-1-style save as v1 wrote it: no actions/day_log, a slimmer
## ads block, fewer settings keys — everything the fill must add.
## Frozen on disk (fixtures/save_v1.json) so future schema bumps keep
## proving they can still carry this exact blob forward (§30).
func _v1_fixture() -> Dictionary:
	var f := FileAccess.open(
		"res://tests/fixtures/save_v1.json", FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func _ready() -> void:
	print("=== save: migration + undo + replay (D2.2/D2.4, §22) ===")

	# --- v1 -> v2 migration ------------------------------------------
	var v1: Dictionary = _v1_fixture()
	check("v1 fixture loads", not v1.is_empty())
	var m: Dictionary = Save._migrate(v1)
	check("migration bumps version",
		int(m["save_version"]) == Save.SAVE_VERSION)
	check("migration fills actions", m.has("actions"))
	check("migration fills day_log", m.has("day_log"))
	check("migration fills ads pacing", m["ads"].has("remove_ads")
		and m["ads"].has("first_all5_day")
		and m["ads"].has("last_review_utc"))
	check("migration fills settings", m.has("settings")
		and m["settings"].has("reduced_motion"))
	check("migration keeps old data", int(m["coins"]) == 90
		and m["sites"].has("pinewatch"))
	var m2: Dictionary = Save._migrate(_v1_fixture())
	check("migration is stable", Save._migrate(m2) == m2)
	# and the migrated blob actually loads — v1 stored personas_met as
	# an Array where the runtime now wants a Dictionary (would crash
	# on assign if the fill didn't coerce the drifted type)
	Game.load_state(Save._migrate(_v1_fixture()))
	check("migrated save loads", Game.day == 4 and Game.coins == 90
		and Game.personas_met is Dictionary)

	# --- day spine: action log + undo --------------------------------
	Game.load_state(Save.default_state())
	Game.visit_site(&"pinewatch")
	Game.sites_visited["pinewatch"] = 0
	Game.day = 0
	Game.new_day()
	Game.site_state()["pages_done"] = [1]       # P1 staples + decor live
	Game.coins = 200
	check("staple buys", Game.buy_staple("tea"))
	check("action recorded", Game.action_log.size() == 1
		and Game.action_log[0]["verb"] == "buy_staple")
	check("undo restores coins", Game.undo() and Game.coins == 200
		and not Game.pantry.has("tea"))
	check("log drained", not Game.can_undo())

	# seat/unseat round-trip through the same spine
	var st: Dictionary = Game.site_state()
	var row: Dictionary = st["board"][0]
	var gid := String(row["id"])
	var pads := Game._open_pads(st).slice(0, 1)
	check("seat records", Game.seat(gid, pads)
		and Game.action_log[-1]["verb"] == "seat")
	check("unseat via undo", Game.undo()
		and not st["assignments"].has(gid))
	check("undo keeps seating legal", Game.seat(gid, pads))

	# terminal verbs drop out of the log rather than wedge it: cook
	# records with no inverse, so one undo() pops past it and lands
	# on the seat — the newest real inverse still wins.
	Game.pantry = {"rice": 2, "mushroom": 1}
	Game.cook("rice", "mushroom")                # no inverse: terminal
	check("cook logged as terminal",
		Game.action_log[-1]["verb"] == "cook"
		and Game.action_log[-1]["inverse"] == null)
	check("undo skips terminal, undoes seat",
		Game.undo() and not st["assignments"].has(gid))

	# bought_today derives from the log: buy -> refundable, return ->
	# gone, undoing the return -> refundable again — no bookkeeping.
	var cell: Vector2i = Game.decor_cells_free()[0]
	check("decor buy refundable",
		Game.buy_decor("stools", [cell])
			and "stools" in Game.bought_today)
	check("return consumes eligibility",
		Game.return_bought("stools")
			and "stools" not in Game.bought_today)
	check("undo restores eligibility",
		Game.undo() and "stools" in Game.bought_today)
	check("undo again returns for good",
		Game.undo() and "stools" not in Game.bought_today)

	# --- golden replay: same script -> same save ---------------------
	Game.load_state(Save.default_state())
	Game.visit_site(&"pinewatch")
	Game.sites_visited["pinewatch"] = 0
	Game.day = 0
	Game.new_day()
	var day1: Dictionary = Game.state_dict()
	Game.load_state(Save.default_state())
	Game.visit_site(&"pinewatch")
	Game.sites_visited["pinewatch"] = 0
	Game.day = 0
	Game.new_day()
	var day1b: Dictionary = Game.state_dict()
	# crew ticks stamp wall-clock — exclude them from the compare
	day1.erase("crew")
	day1b.erase("crew")
	check("golden replay identical", day1 == day1b,
		"%s" % [JSON.stringify(day1).length()])

	# --- round-trip: state_dict -> save file -> load ------------------
	Game.coins = 123
	Game.action_log.append({"verb": "test", "params": {}})
	Game.day_log.append({"phase": 2, "kind": "probe",
		"payload": {"ok": true}})
	Game.ads["first_all5_day"] = 9
	var before: Dictionary = Game.state_dict()
	Save.save_state(before)
	Game.load_state(Save.load_state())
	var after: Dictionary = Game.state_dict()
	before.erase("crew")
	after.erase("crew")
	before.erase("save_version")               # stamped by save_state
	# JSON is the wire format: ints land as floats, so the honest
	# compare is before-as-JSON vs after — drift-free either way.
	var norm: Dictionary = JSON.parse_string(JSON.stringify(before))
	var norm2: Dictionary = JSON.parse_string(JSON.stringify(after))
	var diff := []
	for k in norm:
		if not norm2.has(k) or norm[k] != norm2[k]:
			diff.append(k)
	for k in norm2:
		if not norm.has(k):
			diff.append("+" + k)
	check("round-trip identical", norm == norm2, str(diff))
	check("spines survived the write", Game.action_log.size() == 1
		and Game.day_log[-1]["kind"] == "probe"
		and int(Game.ads["first_all5_day"]) == 9)

	# --- §30 device pass, headless: kill+resume at every phase -------
	# Save at each playable boundary, reload, and the phase + the
	# site/day and wallet must land exactly — Android can reclaim the
	# process at any seam.
	Game.load_state(Save.default_state())
	Game.visit_site(&"pinewatch")
	Game.sites_visited["pinewatch"] = 0
	Game.day = 0
	Game.new_day()
	var resume_ok := true
	var phases := [Game.Phase.MORNING, Game.Phase.PREP,
		Game.Phase.EVENING, Game.Phase.NIGHT]
	for ph in phases:
		Game.set_phase(ph)
		Game.coins = 555
		Save.save_state(Game.state_dict())
		Game.load_state(Save.load_state())
		if Game.phase != ph or Game.coins != 555 \
				or Game.site_id != &"pinewatch":
			resume_ok = false
	check("kill+resume holds at every phase", resume_ok)

	# --- §22 map drift: a repaint orphans placed decor ----------------
	# A save stamped with an older map_rev gets its decor re-validated
	# against today's placement law: illegal pieces return to storage
	# (never deleted), seats unwind, the move lands in day_log, and
	# restoration auras — which follow their structure, not the decor
	# grid — stay put.
	Game.load_state(Save.default_state())
	Game.visit_site(&"pinewatch")
	Game.sites_visited["pinewatch"] = 0
	Game.day = 0
	Game.new_day()
	var st2: Dictionary = Game.site_state()
	var good_cell: Vector2i = _legal_decor_cells()[0]
	Game.coins = 500
	check("drift fixture: legal buy lands",
		Game.buy_decor("stools", [good_cell]))
	var seats0: int = int(st2["seats"])
	# the ghost mirrors what a repaint orphans: it had been bought, so
	# its seat count is already folded into st2["seats"]
	st2["decor"].append({"id": "stools", "effect": "seats",
		"reach": 1, "cells": [_blocked_cell()]})
	st2["seats"] = int(st2["seats"]) + 1
	st2["decor"].append({"id": "restored_glow", "aura": true,
		"effect": "", "reach": 0, "cells": [_blocked_cell()]})
	st2["map_rev"] = "pre-repaint"
	var blob: Dictionary = Game.state_dict()
	Game.load_state(blob)
	var st3: Dictionary = Game.site_state()
	var stools_kept := false
	var aura_kept := false
	for d in st3["decor"]:
		if d["id"] == "stools" and d["cells"] == [good_cell]:
			stools_kept = true
		if d.get("aura", false):
			aura_kept = true
	var stored_meta_ok := false
	for s in st3["stored"]:
		if s["id"] == "stools" and s.get("effect", "") == "seats" \
				and int(s.get("reach", 0)) == 1:
			stored_meta_ok = true
	check("stale rev keeps legal decor", stools_kept)
	check("illegal decor returns to storage",
		st3["decor"].size() == 2
		and st3["stored"].any(func(s): return s["id"] == "stools"))
	check("stored piece keeps its metadata", stored_meta_ok)
	check("aura exempt from reconcile", aura_kept)
	check("seats unwound on the moved piece",
		int(st3["seats"]) == seats0)
	check("map_shift journaled", Game.day_log.any(
		func(e): return e.get("kind") == "map_shift"))
	check("map_rev re-stamped to current layout",
		String(st3["map_rev"]) == String(
			Game._layout().get("map_rev", ""))
		and String(st3["map_rev"]) != "pre-repaint")
	# and a same-rev save is a no-op — reconcile never touches it
	var before_decor: Array = st3["decor"].duplicate(true)
	Game.load_state(Game.state_dict())
	check("same rev is a no-op",
		Game.site_state()["decor"] == before_decor
		and Game.site_state()["stored"].size()
			== st3["stored"].size())
	# lazy path: an off-site drifted save reconciles on arrival, not at
	# load — load_state only touches the current site
	Game.load_state(Save.default_state())
	Game.visit_site(&"pinewatch")
	var w_st: Dictionary = Game.site_state(&"whisper_river")
	w_st["decor"] = [{"id": "stools", "effect": "seats",
		"reach": 1, "cells": [Vector2i(0, 3)]}]
	w_st["map_rev"] = "pre-repaint"
	Game.load_state(Game.state_dict())
	check("off-site drift untouched at load",
		String(Game.sites["whisper_river"].get("map_rev", ""))
			== "pre-repaint")
	Game.visit_site(&"whisper_river")
	check("off-site drift reconciles on arrival",
		String(Game.site_state().get("map_rev", ""))
			== String(Game._layout().get("map_rev", ""))
		and Game.site_state()["decor"].is_empty()
		and Game.site_state()["stored"].size() == 1)

	# --- §23 budget: payload <100KB, load <100ms ----------------------
	var payload := JSON.stringify(Game.state_dict())
	var t0 := Time.get_ticks_msec()
	Save.save_state(Game.state_dict())
	var write_ms := Time.get_ticks_msec() - t0
	t0 = Time.get_ticks_msec()
	Save.load_state()
	var load_ms := Time.get_ticks_msec() - t0
	check("save under 100KB", payload.length() < 100_000,
		"%d B" % payload.length())
	check("save+load under 100ms", write_ms + load_ms < 100,
		"w%d l%d" % [write_ms, load_ms])
	print("  .. bench: save %d B, write %dms, load %dms" % \
		[payload.length(), write_ms, load_ms])

	# --- growth bound: the one unbounded structure is days_log ---
	# (one row/day); a 200-day completionist save must still fit the
	# §23 budget with margin for letters/journal/passport fills
	Game.load_state(Save.default_state())
	Game.days_log = []
	for i in 200:
		Game.days_log.append({"day": i, "site": "pinewatch",
			"weather": "rain", "guests": 6, "best": 5,
			"fav_served": true, "regulars": ["hung"],
			"income": 148, "min_stars": 4, "event": ""})
	Game.letters_read = []
	for i in 24:
		Game.letters_read.append("p%02d" % i)
	Game.dialogue_seen = {}
	for i in 20:
		Game.dialogue_seen["dlg_%d" % i] = true
	Game.field_notes = []
	for i in 22:
		Game.field_notes.append("bird_%02d" % i)
	Game.personas_met = {}
	for a in Catalog.data.get("archetypes", []):
		Game.personas_met[a["id"]] = String(a.get("name", a["id"]))
	var deep := JSON.stringify(Game.state_dict()).length()
	check("200-day save under 100KB", deep < 100_000, "%d B" % deep)
	Game.load_state(Save.default_state())

	# --- corruption path: broken main falls back to .bak and files
	# a nonfatal on the crash seam instead of dying silently -------
	var good := JSON.stringify(Game.state_dict())
	var f := FileAccess.open(Save.BACKUP_PATH, FileAccess.WRITE)
	f.store_string(good)
	f.close()
	f = FileAccess.open(Save.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{{{not json")
	f.close()
	Platform.crash_capture = true
	Platform.crash_events = []
	var loaded: Dictionary = Save.load_state()
	check("corrupt main falls back to backup",
		int(loaded.get("day", -1)) == int(Game.day))
	check("corruption files a nonfatal",
		Platform.crash_events.any(
			func(e): return e["kind"] == "save_corrupt"))
	f = FileAccess.open(Save.SAVE_PATH, FileAccess.WRITE)
	f.store_string(good)
	f.close()
	Platform.crash_capture = false
	Platform.crash_events = []

	# --- support seam: export text round-trips through import ----
	var exp := Save.export_text()
	check("export non-empty", exp.length() > 100)
	var imp: Dictionary = Save.import_text(exp)
	check("import restores day+site",
		int(imp.get("day", -1)) == int(Game.day)
			and String(imp.get("site", "")) == "pinewatch")
	check("garbage import rejected",
		Save.import_text("not base64!!!").is_empty())
	check("empty import rejected",
		Save.import_text("").is_empty())

	finish()
