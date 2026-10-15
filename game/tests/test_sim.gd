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


func _guest_eid(w: SimWorld, gid: String) -> int:
	for eid in w.query(["persona"]):
		if String(w.getc(eid, "persona").get("guest", "")) == gid:
			return eid
	return -1


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
	check("cast size", w1.query(["persona"]).size() >= 3)   # 2 guests + dog (+ beat)
	# spec 004-D rare beats: seeded — find a beat seed and a calm
	# seed, assert the stimulus lands only on the beat seed.
	var beat_seed := -1
	var calm_seed := -1
	for s in 60:
		var wb := SimDirector.cast_night(st, layout, s)
		var has_sky := false
		for eid in wb.query(["pos", "tags"]):
			if wb.getc(eid, "tags").get("tags", []).has("sky"):
				has_sky = true
		var has_critter := false
		for eid in wb.query(["persona"]):
			if String(wb.getc(eid, "persona").get("guest",
					"")) == "raccoon":
				has_critter = true
		if has_sky or has_critter:
			beat_seed = s if beat_seed < 0 else beat_seed
		elif calm_seed < 0:
			calm_seed = s
	check("rare beat rolls on some seeds", beat_seed >= 0)
	check("rare beat absent on calm seeds", calm_seed >= 0)
	# the court to the pond's east bank is a long walk — past the
	# shared 10s replay window, so give this world more ticks.
	# Sample every tick: the loop can head home between snapshots,
	# so a single end-of-run read misses a completed bank visit.
	var reached_bank := false
	for i in 80:
		w1.tick(0.25)
		if float(w1.getc(1, "pos")["x"]) < 420.0 or \
				String(w1.getc(1, "anim")["name"]) == "fish":
			reached_bank = true
			break
	check("angler goes to bank", reached_bank)

	# --- persona pick: seeded draw from actors.json pools ----------------
	var actors := {"archetypes": {"angler": ["angler_uncle", "bird_uncle"],
			"dog": ["bean"]},
		"fallback": {"sprite": "fb", "tint": "fff"}}
	var p1 := SimDirector.cast_night(st, layout, 42, actors)
	var p2 := SimDirector.cast_night(st, layout, 42, actors)
	check("persona drawn from pool",
		String(p1.getc(1, "persona").get("persona", "")) in
			["angler_uncle", "bird_uncle"])
	check("persona deterministic",
		p1.getc(1, "persona") == p2.getc(1, "persona"))
	check("persona sprite path",
		String(p1.getc(1, "persona")["sprite"]).begins_with(
			"characters/"))
	check("persona fallback for unmapped archetype",
		String(p1.getc(2, "persona")["sprite"]) == "fb")
	check("dog persona from dog pool",
		String(p1.getc(3, "persona").get("persona", "")) == "bean")

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
	var kid_e := _guest_eid(w4, "g1")
	check("kids bound to swing",
		String(w4.getc(kid_e, "anchor")["ref"]) == "swing")
	check("ctx lists items",
		Array(w4.ctx["items"]).has("swing"))

	# --- emit/react: dog's bark cue -> dog_wary flinch -------------------
	var st3 := {"assignments": {"g1": ["p7"]},
		"guests": {"g1": {"archetype": "camper",
			"traits": ["dog_wary"]}},
		"dog": {"met": true}, "decor": []}
	var w5 := SimDirector.cast_night(st3, layout, 9)
	var wary_e := _guest_eid(w5, "g1")
	var flinched := false
	for i in 40:
		w5.tick(0.25)
		if w5.has(wary_e, "emote"):
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
	var kid9 := _guest_eid(w9, "g1")
	var dog9 := _guest_eid(w9, "dog")
	# (the storm select lands at step 0 on every guest program now)
	check("kid program scored",
		String(w9.getc(kid9, "schedule")["steps"][1]["op"]) ==
			"respond")
	check("kid has perceive weights",
		float(w9.getc(kid9, "perceive")["weights"]["dog"]) > 0.0)
	check("dog has affordance tag",
		Array(w9.getc(dog9, "tags")["tags"]).has("dog"))

	# generality: a NEW stimulus pair with zero new code — an
	# oddity entity spawns near the patrol; the dog leaves its
	# route to investigate (respond -> goto percept -> sniff)
	w9.spawn({"pos": {"x": 600.0, "y": 340.0},
		"tags": {"tags": ["oddity"]}})
	var investigated := false
	for i in 40:
		w9.tick(0.25)
		var dp: Dictionary = w9.getc(dog9, "pos", {})
		if not dp.is_empty() and Vector2(dp["x"], dp["y"]) \
				.distance_to(Vector2(600, 340)) < 40.0:
			investigated = true
	check("dog investigates oddity", investigated)

	# --- cast-time routing: detour around blocked cells ------------------
	# (544,288) cell(8,4) -> (288,544) cell(4,8): the straight line
	# drops SW through the house/pond-edge blocked mass; the clean way
	# is the court lane west around the water — a detour is required.
	var pts := SimDirector._route(layout, Vector2(544, 288),
		Vector2(288, 544))
	var blocked := {}
	for c in layout["nav"]["blocked"]:
		blocked["%d,%d" % [c[0], c[1]]] = true
	var clean := true
	for p in pts:
		var c := SimDirector._px_cell(p)
		if blocked.has("%d,%d" % [c.x, c.y]):
			clean = false
	check("route detours blocked cells",
		pts.size() > 2 and clean, str(pts))

	# straight line, no obstacles and no road data -> fast path
	var flat := {"nav": {"blocked": []}, "pads": {"spots": {}}}
	var pts2 := SimDirector._route(flat, Vector2(224, 176),
		Vector2(352, 176))
	check("clear line fast path", pts2 == [Vector2(352, 176)])

	# road preference: gate column -> east apron exit.  The x8 descent
	# + row4 lane is the discounted route; the grass row5 detour is
	# full-cost, so A* rides the L — the picked path spends its run
	# on road cells
	var road_cells := {}
	for c in layout["nav"].get("road", []):
		road_cells["%d,%d" % [c[0], c[1]]] = true
	var pts3 := SimDirector._route(layout, Vector2(544, 288),
		Vector2(928, 288))
	var on_road := 0
	for p in pts3:
		var c := SimDirector._px_cell(p)
		if road_cells.has("%d,%d" % [c.x, c.y]):
			on_road += 1
	check("route prefers the road",
		on_road >= 4 and pts3[pts3.size() - 1] == Vector2(928, 288),
		str(pts3))

	# --- storm divert (§14): every program selects huddle in a gale ---
	var st_storm := {"assignments": {"g1": ["p7"]},
		"guests": {"g1": {"archetype": "angler"}},
		"dog": {"met": false}, "decor": [], "weather": "storm"}
	var ws := SimDirector.cast_night(st_storm, layout, 11)
	var sc_storm: Array = ws.getc(1, "schedule")["steps"]
	check("storm select first",
		String(sc_storm[0]["op"]) == "select")
	for i in 30:
		ws.tick(0.25)
	check("storm huddle (no bank run)",
		String(ws.getc(1, "anim")["name"]) == "sit")

	# --- multi-bank (§7.2): Whisper River anglers pick a real bank ----
	var wr: Dictionary = Catalog.data["layouts"]["whisper_river"]
	var st_wr := {"assignments": {"g1": ["p1"]},
		"guests": {"g1": {"archetype": "angler"}},
		"dog": {"met": false}, "decor": []}
	var w_wr := SimDirector.cast_night(st_wr, wr, 5)
	var fishes := false
	for stp in w_wr.getc(1, "schedule")["steps"]:
		if stp.get("anim", {}).get("name") == "fish" \
				or stp.get("name") == "fish":
			fishes = true
	check("whisper angler fishes", fishes)

	# --- sit_spot sockets (spec 003): placed seats spawn claims -------
	var st_sock := {"assignments": {"g1": ["p7"]},
		"guests": {"g1": {"archetype": "hiker"}},
		"dog": {"met": false},
		"decor": [{"id": "stools", "cells": [[3, 4]]}]}
	var w_sock := SimDirector.cast_night(st_sock, layout, 3)
	var n_sockets := 0
	for eid in w_sock.query(["pos", "tags"]):
		if not w_sock.has(eid, "persona") and \
				Array(w_sock.getc(eid, "tags")["tags"]) \
					.has("sit_spot"):
			n_sockets += 1
	check("stool socket spawned", n_sockets >= 1)
	# sockets are invisible: renderable = pos+persona
	check("sockets invisible to view",
		w_sock.query(["pos", "persona"]).size()
			== w_sock.query(["persona"]).size())

	# --- duet (§13.5): two couples + string lights -> await steps -----
	var st_duet := {"assignments": {"g1": ["p7"], "g2": ["p1"]},
		"guests": {"g1": {"archetype": "couple"},
			"g2": {"archetype": "couple"}},
		"dog": {"met": false},
		"decor": [{"id": "string_lights", "cells": [[4, 3]]}]}
	var w_duet := SimDirector.cast_night(st_duet, layout, 8)
	var duets := 0
	for eid in w_duet.query(["schedule"]):
		for stp in w_duet.getc(eid, "schedule")["steps"]:
			if stp.get("op") == "await":
				duets += 1
	check("couple duet awaits", duets == 2, "got %d" % duets)

	# --- queue cast (§10): unseated board guests wander by the fire ---
	var st_q := {"assignments": {"g1": ["p7"]},
		"guests": {"g1": {"archetype": "hiker"}},
		"board": [{"id": "g1", "archetype": "hiker"},
			{"id": "g9", "archetype": "photographer"}],
		"dog": {"met": false}, "decor": []}
	var w_q := SimDirector.cast_night(st_q, layout, 4)
	var queued := false
	for eid in w_q.query(["persona"]):
		if String(w_q.getc(eid, "persona").get("guest", "")) == "g9":
			queued = true
	check("queue guest wanders", queued)

	# --- day cast (§3): ambience without a board ----------------------
	var wd := SimDirector.cast_day(
		{"dog": {"met": true}, "decor": [], "weather": "clear"},
		layout, 21)
	check("day cast casts locals + dog",
		wd.query(["pos", "persona"]).size() >= 2)
	var wd2 := SimDirector.cast_day(
		{"dog": {"met": true}, "decor": [], "weather": "clear"},
		layout, 21)
	check("day cast deterministic",
		wd.query(["schedule"]).size() == wd2.query(["schedule"]).size())

	finish()
