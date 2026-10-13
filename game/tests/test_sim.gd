extends "res://tests/harness.gd"
## Headless ECS checks (PLAN_gameplay D4). Run:
##   godot --headless --path game tests/test_sim.tscn
## Exit code = number of failed checks.


func _snapshot(w: SimWorld) -> Dictionary:
	var snap := {}
	for eid in w.query(["pos"]):
		var pos: Dictionary = w.getc(eid, "pos")
		var anim: Dictionary = w.getc(eid, "anim", {})
		snap[eid] = [pos["x"], pos["y"], anim.get("name", "")]
	return snap


func _ready() -> void:
	print("=== actor ECS (D4) ===")

	# --- world primitives ------------------------------------------------
	var w := SimWorld.new(7)
	var e1 := w.spawn({"pos": {"x": 0.0, "y": 0.0}})
	var e2 := w.spawn({"pos": {"x": 10.0, "y": 0.0},
		"anim": {"name": "walk", "fps": 8.0}})
	check("query subset", w.query(["pos", "anim"]) == [e2])
	check("query all pos", w.query(["pos"]).size() == 2)

	# --- schedule: goto blocks until arrival, then advances --------------
	var prog := [{"op": "anim", "name": "walk"},
		{"op": "goto", "to": [100.0, 0.0], "speed": 50.0},
		{"op": "anim", "name": "sit"}, {"op": "wait", "t": 1.0},
		{"op": "jump", "to": 0}]
	w.put(e1, "schedule", {"steps": prog, "i": 0, "wait": 0.0,
		"started": false})
	w.tick(0.5)                          # anim step -> goto starts
	check("goto started", w.has(e1, "mover"))
	check("walk anim set",
		String(w.getc(e1, "anim")["name"]) == "walk")
	w.tick(1.0)                          # 50px + 25px = 75 < 100
	var mv: Dictionary = w.getc(e1, "mover")
	check("en route", not mv["arrived"])
	w.tick(1.0)                          # +75 = 150 -> arrives, anim
	check("arrived", w.getc(e1, "mover")["arrived"])
	w.tick(0.01)
	check("sit after arrival",
		String(w.getc(e1, "anim")["name"]) == "sit")
	check("wait armed",
		float(w.getc(e1, "schedule")["wait"]) > 0.9)

	# --- life: ttl despawns ----------------------------------------------
	var e3 := w.spawn({"pos": {"x": 0.0, "y": 0.0},
		"life": {"ttl": 0.2}})
	w.tick(0.3)
	check("life despawn", not w.query(["pos"]).has(e3))

	# --- determinism: same cast + seed -> same snapshot ------------------
	var st := {"assignments": {"g1": ["p7"], "g2": ["p1"]},
		"guests": {"g1": {"archetype": "angler"},
			"g2": {"archetype": "camper"}},
		"dog": {"met": true}, "decor": []}
	var layout: Dictionary = Catalog.data["layouts"]["pinewatch"]
	var w1 := SimDirector.cast_night(st, layout, 42)
	var w2 := SimDirector.cast_night(st, layout, 42)
	for i in 40:
		w1.tick(0.25)
		w2.tick(0.25)
	check("deterministic replay",
		_snapshot(w1) == _snapshot(w2),
		str(_snapshot(w1)))
	check("cast size", w1.query(["pos"]).size() == 3)   # 2 guests + dog
	check("angler goes to bank",
		float(w1.getc(1, "pos")["x"]) < 200.0 or
		String(w1.getc(1, "anim")["name"]) == "fish")

	# --- select: item-bound branch ---------------------------------------
	var w3 := SimWorld.new(3)
	w3.ctx = {"items": ["tarp"]}
	var e4 := w3.spawn({"pos": {"x": 0.0, "y": 0.0},
		"schedule": {"steps": [
			{"op": "select", "else": 4, "branches":
				[{"item": "tarp", "goto": 2}]},
			{"op": "anim", "name": "a"},
			{"op": "anim", "name": "with_tarp"},
			{"op": "wait", "t": 9.0},
			{"op": "anim", "name": "no_tarp"},
			{"op": "wait", "t": 9.0}],
			"i": 0, "wait": 0.0, "started": false}})
	w3.tick(0.1)
	check("select picks item branch",
		String(w3.getc(e4, "anim")["name"]) == "with_tarp")

	# --- item binding: kids anchored to the placed swing -----------------
	var st2 := {"assignments": {"g1": ["p7"]},
		"guests": {"g1": {"archetype": "kids"}},
		"dog": {"met": false},
		"decor": [{"id": "swing", "cells": [[5, 5]]}]}
	var w4 := SimDirector.cast_night(st2, layout, 5)
	check("kids bound to swing",
		String(w4.getc(1, "anchor")["ref"]) == "swing")
	check("ctx lists items",
		Array(w4.ctx["items"]).has("swing"))

	# --- emit/react: dog's bark cue -> dog_wary flinch -------------------
	var st3 := {"assignments": {"g1": ["p7"]},
		"guests": {"g1": {"archetype": "camper",
			"traits": ["dog_wary"]}},
		"dog": {"met": true}, "decor": []}
	var w5 := SimDirector.cast_night(st3, layout, 9)
	var flinched := false
	for i in 40:
		w5.tick(0.25)
		if w5.has(1, "emote"):
			flinched = true
	check("dog_wary flinches at bark", flinched)

	# --- react_tag: scored proximity bands ------------------------------
	# score = fear * (1 - dist/r); dist 30/r 150/fear .8 -> .64
	var prog2 := [{"op": "react_tag", "tag": "dog", "r": 150.0,
		"fear": 0.8, "bands": [
			{"gte": 0.55, "goto": 3},
			{"else": true, "goto": 5}]},
		{"op": "anim", "name": "idle"}, {"op": "wait", "t": 9.0},
		{"op": "anim", "name": "flee"}, {"op": "wait", "t": 9.0},
		{"op": "anim", "name": "calm"}, {"op": "wait", "t": 9.0}]
	var w6 := SimWorld.new(4)
	var kid := w6.spawn({"pos": {"x": 100.0, "y": 100.0},
		"tags": {"tags": ["kid"]},
		"schedule": {"steps": prog2, "i": 0, "wait": 0.0,
			"started": false}})
	w6.spawn({"pos": {"x": 130.0, "y": 100.0},
		"tags": {"tags": ["dog"]}})
	w6.tick(0.1)
	check("close dog -> flee band",
		String(w6.getc(kid, "anim")["name"]) == "flee")

	# same program, dog beyond r -> falls through to idle
	var w7 := SimWorld.new(4)
	var kid2 := w7.spawn({"pos": {"x": 100.0, "y": 100.0},
		"schedule": {"steps": prog2.duplicate(true), "i": 0,
			"wait": 0.0, "started": false}})
	w7.spawn({"pos": {"x": 400.0, "y": 100.0},
		"tags": {"tags": ["dog"]}})
	w7.tick(0.1)
	check("far dog -> normal loop",
		String(w7.getc(kid2, "anim")["name"]) == "idle")

	# goto tag -> walks toward the tagged entity
	var w8 := SimWorld.new(4)
	var kid3 := w8.spawn({"pos": {"x": 100.0, "y": 100.0},
		"schedule": {"steps": [
			{"op": "goto", "tag": "dog", "speed": 50.0},
			{"op": "anim", "name": "arrived"},
			{"op": "wait", "t": 9.0}], "i": 0, "wait": 0.0,
			"started": false}})
	w8.spawn({"pos": {"x": 300.0, "y": 100.0},
		"tags": {"tags": ["dog"]}})
	w8.tick(1.0)
	check("goto tag approaches",
		float(w8.getc(kid3, "pos")["x"]) > 140.0)

	# director: kids + dog -> scored wrap; dog advertises tag
	var st4 := {"assignments": {"g1": ["p7"]},
		"guests": {"g1": {"archetype": "kids"}},
		"dog": {"met": true}, "decor": []}
	var w9 := SimDirector.cast_night(st4, layout, 6)
	check("kid program scored",
		String(w9.getc(1, "schedule")["steps"][0]["op"]) ==
			"react_tag")
	check("dog has affordance tag",
		Array(w9.getc(2, "tags")["tags"]).has("dog"))

	finish()
