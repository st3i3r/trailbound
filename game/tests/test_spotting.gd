extends "res://tests/harness.gd"
## Headless spotting checks (GDD §7.3). Run:
##   godot --headless --path game tests/test_spotting.tscn
## Exit code = number of failed checks.


func _ready() -> void:
	print("=== spotting (§7.3) ===")

	# Fresh Pinewatch morning: forage nodes rolled, spot_day unset.
	Game.field_notes = []
	Game.visit_site(&"pinewatch")
	Game.day = 0
	Game.sites_visited["pinewatch"] = 0
	Game.new_day()
	var st_sp := Game.site_state()
	check("no binoculars, no spotting", not Game.can_spot())
	Game.gear.append("binoculars")
	check("binoculars opens spotting", Game.can_spot())
	var nodes_before: int = st_sp["forage_nodes"].size()
	var sp := Game.spot()
	check("bird logged", sp.get("bird", {}).get("site", "") == "pinewatch"
		and sp["bird"]["id"] in Game.field_notes,
		"got %s" % [sp.get("bird", {})])
	check("bonus node revealed",
		st_sp["forage_nodes"].size() == nodes_before + 1
		and st_sp["forage_nodes"][-1].get("bonus", false))
	var fb_id := String(st_sp["forage_nodes"][-1]["id"]) \
		if not st_sp["forage_nodes"].is_empty() else ""
	check("bonus node gathers", fb_id != ""
		and (Game.gather(fb_id).size() > 0 or Game.pantry.size() >= 20))
	check("once per site day", Game.spot().is_empty())
	# Log the remaining three Pinewatch birds, then check the cap.
	for i in 3:
		Game.day += 1
		Game.new_day()
		sp = Game.spot()
	# field_notes now spans birds + forage + fish (§8.3) — count birds
	var bird_notes := Game.field_notes.filter(
		func(id): return Catalog.data.get("birds", []).any(
			func(b): return b["id"] == id))
	check("all site birds logged", sp.get("all_logged", false)
		and bird_notes.size() == 4,
		"got %s" % [Game.field_notes])
	check("forage finds also noted", Game.field_notes.size() > 4)
	Game.day += 1
	Game.new_day()
	sp = Game.spot()
	check("empty pool still reveals node",
		sp.get("bird", {}) == {} and sp.get("all_logged", false)
		and st_sp["forage_nodes"].any(
			func(n): return n.get("bonus", false)))
	check("field notes persist",
		Game.state_dict()["field_notes"].size() ==
			Game.field_notes.size())

	finish()
