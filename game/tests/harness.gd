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
