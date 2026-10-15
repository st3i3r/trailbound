extends Node
## Shared harness for the headless test scenes: check() tallies,
## finish() reports and quits with the failure count, _inject/_put/
## _stars are the seating fixtures every domain suite reuses.
## Exit code = number of failed checks.

var failures := 0


func check(name: String, cond: bool, detail := "") -> void:
	if not cond:
		failures += 1
		print("  XX %s %s" % [name, detail])
	else:
		print("  OK %s" % name)


func finish() -> void:
	print("=== %s ===" % ("ALL CHECKS PASS" if failures == 0
		else "%d FAILURES" % failures))
	get_tree().quit(failures)


func _inject(gid: String, arch: String, traits: Array,
		loud := false) -> Dictionary:
	var g := {"id": gid, "archetype": arch, "traits": traits,
		"loud": loud, "fee": 40, "pads": 1}
	Game.site_state()["guests"][gid] = g
	return g


func _put(item_id: String, effect: String, reach: int,
		cells: Array) -> void:
	Game.site_state()["decor"].append({"id": item_id,
		"effect": effect, "reach": reach, "cells": cells})


func _stars(gid: String, pads: Array, meal := 0) -> int:
	var g: Dictionary = Game.site_state()["guests"][gid]
	Game.site_state()["assignments"][gid] = pads
	return Seating.resolve_guest(g, pads, Game._world(), meal)["stars"]


# ------------------------------------------------- layout-relative finds
# Cells change when the map is repainted — fixtures should ask the
# layout for a cell that satisfies the property, not hardcode one.
# Pinned cells stay for tests whose claim IS the position.

func _in_ring(pid: String, radius := -1) -> bool:
	## pad sits inside the campfire's warmth ring (Chebyshev)
	var layout := Game._layout()
	var fire: Dictionary = layout["campfire"]
	var r := radius if radius >= 0 else int(fire["radius"])
	var s: Array = layout["pads"]["spots"][pid]
	return Seating.chebyshev(Vector2i(s[0], s[1]),
		Vector2i(fire["cell"][0], fire["cell"][1])) <= r


func _pads_in_ring(radius := -1) -> Array:
	## pad ids inside the fire ring, sorted for determinism
	var ids: Array = Game._layout()["pads"]["spots"].keys()
	ids.sort()
	return ids.filter(func(pid): return _in_ring(pid, radius))


func _pads_outside_ring(radius := -1) -> Array:
	## pad ids beyond the fire ring — the ones that can't grant warmth
	var ids: Array = Game._layout()["pads"]["spots"].keys()
	ids.sort()
	return ids.filter(func(pid): return not _in_ring(pid, radius))


func _pad_neighbour(pid: String) -> String:
	## first declared neighbour of a pad ("" when it has none)
	var nbs: Array = Game._layout()["pads"].get(
		"neighbours", {}).get(pid, [])
	return nbs[0] if not nbs.is_empty() else ""


func _walkable_cells() -> Array:
	return SimGrid.walk_cells(Game._layout()).keys()


func _legal_decor_cells() -> Array:
	## decor_cells that are actually placeable today — Vector2i out
	var layout := Game._layout()
	var walk := SimGrid.walk_cells(layout)
	var occ := {}
	for d in Game.site_state()["decor"]:
		for c in d["cells"]:
			occ[c] = true
	var out := []
	for c in layout.get("decor_cells", []):
		var v := Vector2i(int(c[0]), int(c[1]))
		if walk.has(v) and not occ.has(v):
			out.append(v)
	return out


func _legal_decor_pair() -> Array:
	## a legal decor cell whose +1x neighbour is also legal (2x1 items)
	var legal := _legal_decor_cells()
	for c in legal:
		var n: Vector2i = c + Vector2i(1, 0)
		if legal.has(n):
			return [c, n]
	return []


func _blocked_cell() -> Vector2i:
	## any nav.blocked cell — negative-legality fixtures
	var navb := SimGrid.blocked(Game._layout())
	return navb.keys()[0]


func _nondecor_walkable_cell() -> Vector2i:
	## walkable but not a decor cell — "not placeable" negatives
	var layout := Game._layout()
	var legal := {}
	for c in layout.get("decor_cells", []):
		legal[Vector2i(int(c[0]), int(c[1]))] = true
	var pads := {}
	for s in layout["pads"]["spots"].values():
		pads[Vector2i(int(s[0]), int(s[1]))] = true
	for c in SimGrid.walk_cells(layout).keys():
		if not legal.has(c) and not pads.has(c):
			return c
	return Vector2i(-1, -1)
