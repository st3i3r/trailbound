extends RefCounted
## Trail Daily (§10) — date-seeded shared puzzle, one scored
## attempt per day, unlimited practice, share text.
##
## Leaf subsystem owned by Game: `daily_state` stays on Game for the
## save schema; generation/scoring run through `g` so every rule is
## the game's own Seating/Catalog data.

const EPOCH := "2025-01-01"                  # N counts days since launch

var g  # the Game autoload (untyped: circular ref)


func _init(game) -> void:
	g = game


func unlocked() -> bool:
	return "p06" in g.site_state(&"pinewatch")["letters_delivered"]


func date(date_str := "") -> String:
	return date_str if date_str != "" \
		else Time.get_date_string_from_system()


func n(date_str: String) -> int:
	var a := Time.get_unix_time_from_datetime_string(
		EPOCH + "T00:00:00")
	var b := Time.get_unix_time_from_datetime_string(
		date_str + "T00:00:00")
	return int((b - a) / 86400.0)


## The seeded puzzle for a date — deterministic, so a reload shows
## the same cards, kit and meals.
func puzzle(date_str := "") -> Dictionary:
	var d := date(date_str)
	var pz := gen(d, tries(d))
	pz["date"] = d
	pz["n"] = n(d)
	pz["attempted"] = g.daily_state["date"] == d \
		and g.daily_state["score"] >= 0
	return pz


## Deterministic reroll chain (§10): attempt k>0 uses seed
## "daily|date|rk". The CI solver (tests/daily_check) bakes the
## accepted try count into data/daily_seeds.json; dates beyond the
## table fall back to the raw seed.
func seed_for(d: String, tries: int) -> int:
	var s := "daily|" + d
	if tries > 0:
		s += "|r%d" % tries
	return absi(int(s.hash()))


func tries(d: String) -> int:
	return int(Catalog.data.get("daily_seeds", {}).get(
		"seeds", {}).get(d, 0))


func gen(d: String, tries: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(d, tries)
	var skip := ["seats", "warmth_upgrade", "none"]
	var kit_pool: Array = Catalog.data.get("decor", []).filter(
		func(x): return String(x.get("unlock", "")).begins_with("P") \
			and x.get("effect") not in skip)
	return Seating.daily_puzzle(g.site_row(&"pinewatch"),
		Catalog.data.get("archetypes", []), kit_pool,
		g._favourite_pool(&"pinewatch"), rng)


## Score an attempt. assignments: {guest_id: [pad_ids]};
## placements: {kit_item_id: [Vector2i cells]}. submit=true records
## the score if today's attempt is unused (§10 one scored attempt).
func score(puzzle: Dictionary, assignments: Dictionary,
		placements: Dictionary, submit := false) -> Dictionary:
	var kit_rows := {}
	for k in puzzle["kit"]:
		kit_rows[k["id"]] = k
	var decor_items := []
	for iid in placements:
		var row: Dictionary = kit_rows.get(iid, {})
		decor_items.append({"id": iid, "cells": placements[iid],
			"effect": row.get("effect", ""),
			"reach": int(row.get("reach", 1))})
	var guests := {}
	var occupants := {}
	var seated := []
	for r in puzzle["requests"]:
		guests[r["id"]] = r
	for gid in assignments:
		if gid not in guests:
			continue
		for pid in assignments[gid]:
			occupants[pid] = gid
		seated.append({"guest": guests[gid],
			"pad_ids": assignments[gid]})
	var kinds: Dictionary = g._trait_kinds()
	var world := Seating.daily_world(puzzle, decor_items, occupants,
		guests, kinds, Catalog.data.get("reviews", {}))
	var plan := Seating.allocate_meals(puzzle["meals"], seated)
	var results := []
	var total := 0
	for s in seated:
		var rr := Seating.resolve_guest(s["guest"], s["pad_ids"],
			world, int(plan["terms"].get(s["guest"]["id"], -1)))
		results.append(rr)
		total += rr["stars"]
	if submit and puzzle.get("date") == date() \
			and g.daily_state["date"] != puzzle.get("date"):
		g.daily_state = {"date": puzzle["date"], "score": total}
		if puzzle["date"] not in g.passport_stamps:   # §33.5 stamp
			g.passport_stamps.append(puzzle["date"])
	return {"score": total, "results": results,
		"share": share(puzzle, results)}


func share(puzzle: Dictionary, results: Array) -> String:
	var row := ""
	for r in results:
		row += "★".repeat(int(r["stars"])) + " "
	return "Trailbound Daily #%d — %d/25\n%s" % [
		int(puzzle.get("n", 0)), int(
			results.reduce(func(a, x): return a + x["stars"], 0)),
		row.strip_edges()]
