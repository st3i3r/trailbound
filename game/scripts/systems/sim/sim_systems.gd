class_name SimSystems
extends RefCounted
## ECS systems for SimWorld (PLAN_gameplay D4). Static funcs run in
## tick order: schedule -> move -> life. Pure data only — anything
## that touches a Node lives in the view presenter, not here.


## Behavior-program driver. Step ops:
##   {"op":"goto","to":[x,y],"speed":n}  sets mover, blocks until
##                                     mover.arrived
##   {"op":"anim","name":n,"fps":f}     writes the anim comp
##   {"op":"wait","t":s}                blocks via schedule.wait
##   {"op":"emote","icon":i,"t":s}      writes a timed emote comp
##   {"op":"jump","to":i}               loops the program
static func schedule(w: SimWorld, dt: float) -> void:
	for eid in w.query(["schedule"]):
		var sc: Dictionary = w.getc(eid, "schedule")
		if sc["wait"] > 0.0:
			sc["wait"] = maxf(0.0, sc["wait"] - dt)
			continue
		# run non-blocking steps until something blocks (guard vs
		# a malformed all-jump program spinning forever)
		for guard in 8:
			var step: Dictionary = sc["steps"][sc["i"]]
			match String(step.get("op", "")):
				"goto":
					if not sc.get("started", false):
						var tgt := Vector2.ZERO
						var have := true
						if step.has("percept"):
							# navigate to a scored stimulus —
							# entities AND transient cues alike
							var pc: Dictionary = w.getc(eid,
								"percept", {}).get("by_tag", {})
							if pc.has(step["percept"]):
								tgt = pc[step["percept"]]["pos"]
							else:
								have = false
						elif step.has("tag"):
							# walk to the nearest entity advertising
							# the affordance tag (approach/pet)
							var n := _near_tag(w, eid,
								String(step["tag"]),
								float(step.get("r", 400.0)))
							if n.is_empty():
								have = false
							else:
								tgt = n["pos"]
						else:
							tgt = Vector2(float(step["to"][0]),
								float(step["to"][1]))
						if not have:
							_next(sc)
							continue
						w.put(eid, "mover", {
							"speed": float(step.get("speed", 50.0)),
							"target": tgt,
							"arrived": false})
						sc["started"] = true
					if w.getc(eid, "mover", {}).get("arrived", false):
						_next(sc)
						continue
					break
				"anim":
					w.put(eid, "anim", {
						"name": step.get("name", "idle"),
						"fps": float(step.get("fps", 6.0))})
					_next(sc)
				"wait":
					sc["wait"] = float(step.get("t", 1.0))
					_next(sc)
					break
				"emote":
					w.put(eid, "emote", {
						"icon": step.get("icon", "?"),
						"t": float(step.get("t", 1.0))})
					_next(sc)
				"jump":
					sc["i"] = int(step.get("to", 0))
					sc["started"] = false
				"select":
					# mini-BT selector: jump to the first branch
					# whose ctx condition holds, else "else"
					var to := int(step.get("else", sc["i"] + 1))
					for b in step.get("branches", []):
						if _cond(w, eid, b):
							to = int(b.get("goto", to))
							break
					sc["i"] = to
					sc["started"] = false
				"if":
					sc["i"] = int(step.get("goto", sc["i"] + 1)) \
						if _cond(w, eid, step) else sc["i"] + 1
					sc["started"] = false
				"emit":
					var p: Dictionary = w.getc(eid, "pos", {})
					w.emit(Vector2(float(p.get("x", 0.0)),
						float(p.get("y", 0.0))),
						String(step.get("cue", "")), eid,
						float(step.get("t", 2.0)),
						step.get("tags", []))
					_next(sc)
				"react":
					# consume the heard inbox latched by sys_listen
					var hd: Dictionary = w.getc(eid, "heard", {})
					var hit := String(hd.get("cue", "")) == \
						String(step.get("to", ""))
					if hit:
						w.stores.get("heard", {}).erase(eid)
						sc["i"] = int(step.get("goto",
							sc["i"] + 1))
					else:
						sc["i"] += 1
					sc["started"] = false
				"react_tag":
					# low-level poll: score = fear * (1 - dist/r)
					# vs nearest tagged entity — no perceive comp
					# needed. Prefer `respond` for persona-driven
					# reactions; this stays for scripted fixed
					# reactions inside authored programs.
					var n2: Dictionary = _near_tag(w, eid,
						String(step.get("tag", "")),
						float(step.get("r", 120.0)))
					var to2: int = sc["i"] + 1
					if not n2.is_empty():
						var score := clampf(
							float(step.get("fear", 0.5)) *
							(1.0 - float(n2["dist"]) /
								float(step.get("r", 120.0))),
							0.0, 1.0)
						for b in step.get("bands", []):
							if b.has("else") or score >= \
									float(b.get("gte", 0.0)):
								to2 = int(b.get("goto", to2))
								break
					sc["i"] = to2
					sc["started"] = false
				"respond":
					# scored response (production path): consult
					# the percept.by_tag map sys_sense built —
					# any tag in step.tags counts, best score
					# wins; bands pick the outcome branch.
					var pc: Dictionary = w.getc(eid, "percept",
						{}).get("by_tag", {})
					var to3: int = sc["i"] + 1
					var best_s := -1.0
					for t in step.get("tags", []):
						if pc.has(t) and \
								float(pc[t]["score"]) > best_s:
							best_s = float(pc[t]["score"])
					if best_s >= 0.0:
						for b in step.get("bands", []):
							if b.has("else") or best_s >= \
									float(b.get("gte", 0.0)):
								to3 = int(b.get("goto", to3))
								break
					sc["i"] = to3
					sc["started"] = false
				_:
					_next(sc)


static func _next(sc: Dictionary) -> void:
	sc["i"] += 1
	if sc["i"] >= sc["steps"].size():
		sc["i"] = sc["steps"].size() - 1
	sc["started"] = false


## Nearest entity advertising an affordance tag within r — the
## Smart-Object lookup (Sims affordances, entity scale). Returns
## {eid, dist, pos} or {} when nothing qualifies.
static func _near_tag(w: SimWorld, eid: int, tag: String,
		r: float) -> Dictionary:
	var p: Dictionary = w.getc(eid, "pos", {})
	var me := Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0)))
	var best := {}
	for other in w.query(["pos", "tags"]):
		if other == eid:
			continue
		var tags: Array = w.getc(other, "tags", {}).get("tags", [])
		if not tags.has(tag):
			continue
		var op: Dictionary = w.getc(other, "pos")
		var opv := Vector2(float(op["x"]), float(op["y"]))
		var d := me.distance_to(opv)
		if d <= r and (best.is_empty() or d < best["dist"]):
			best = {"eid": other, "dist": d, "pos": opv}
	return best


## Branch condition for select/if: ctx keys must equal, "item"
## must be in ctx.items (item-bound behavior), "anchor" matches
## the entity's anchor ref. Deterministic — state, not rng.
static func _cond(w: SimWorld, eid: int, c: Dictionary) -> bool:
	for k in c.get("ctx", {}):
		if w.ctx.get(k) != c["ctx"][k]:
			return false
	if c.has("item") and not Array(w.ctx.get("items", [])) \
			.has(String(c["item"])):
		return false
	if c.has("anchor"):
		var a: Dictionary = w.getc(eid, "anchor", {})
		if String(a.get("ref", "")) != String(c["anchor"]):
			return false
	return true


## Waypoint move: straight-line toward mover.target at mover.speed.
## The camp is open field — authored routes beat pathfinding here.
static func move(w: SimWorld, dt: float) -> void:
	for eid in w.query(["pos", "mover"]):
		var mv: Dictionary = w.getc(eid, "mover")
		if mv.get("arrived", false):
			continue
		var pos: Dictionary = w.getc(eid, "pos")
		var p := Vector2(float(pos["x"]), float(pos["y"]))
		var d: Vector2 = mv["target"] - p
		var step := float(mv["speed"]) * dt
		if d.length() <= step:
			p = mv["target"]
			mv["arrived"] = true
		else:
			p += d.normalized() * step
		pos["x"] = p.x
		pos["y"] = p.y


## Perception — the general Stimulus Registry -> Perception ->
## Scored Percept pipeline (PLAN D4), entity scale. Two channels:
##
##   transient (hearing): cues inside perceive.hear_r latch into
##     `heard` — reflex channel for `react` steps
##   continuous (sight):  EVERY stimulus — tagged entities AND
##     tagged cues — inside perceive.sight_r is scored
##       score = perceive.weights[tag] * (1 - dist/sight_r)
##     best per tag lands in `percept.by_tag` — the utility
##     channel for `respond` steps
##
## Persona is data (weights + radii), so "kid meets dog" and
## "dog investigates oddity" are the same machinery — adding an
## interaction pair is adding tags and weights, not code.
static func sense(w: SimWorld, _dt: float) -> void:
	for eid in w.query(["pos", "perceive"]):
		var per: Dictionary = w.getc(eid, "perceive")
		var p: Dictionary = w.getc(eid, "pos")
		var me := Vector2(float(p["x"]), float(p["y"]))
		var weights: Dictionary = per.get("weights", {})
		var sr := float(per.get("sight_r", 150.0))
		var hr := float(per.get("hear_r", 140.0))
		var by_tag := {}
		for c in w.cues:
			if c["src"] == eid:
				continue
			var cp: Vector2 = c["pos"]
			var d := me.distance_to(cp)
			if d <= hr:
				w.put(eid, "heard", {"cue": String(c["cue"]),
					"src": c["src"], "pos": cp, "t": 1.5})
			if d <= sr:
				_score(w, eid, by_tag, c.get("tags", [c["cue"]]),
					cp, weights, sr, c["src"], d)
		for o in w.query(["pos", "tags"]):
			if o == eid:
				continue
			var op: Dictionary = w.getc(o, "pos")
			var opv := Vector2(float(op["x"]), float(op["y"]))
			var d2 := me.distance_to(opv)
			if d2 <= sr:
				_score(w, eid, by_tag,
					w.getc(o, "tags", {}).get("tags", []),
					opv, weights, sr, o, d2)
		if by_tag.is_empty():
			w.stores.get("percept", {}).erase(eid)
		else:
			w.put(eid, "percept", {"by_tag": by_tag})


static func _score(_w: SimWorld, _eid: int, by_tag: Dictionary,
		tags: Array, pos: Vector2, weights: Dictionary,
		r: float, src: Variant, d: float) -> void:
	for t in tags:
		var wt := float(weights.get(String(t), 0.0))
		if wt <= 0.0:
			continue
		var s: float = wt * (1.0 - d / r)
		if not by_tag.has(t) or s > by_tag[t]["score"]:
			by_tag[t] = {"score": s, "pos": pos, "src": src}


## Timers: life.ttl despawns the entity; emote.t clears the icon.
static func life(w: SimWorld, dt: float) -> void:
	for eid in w.query(["life"]):
		var lf: Dictionary = w.getc(eid, "life")
		lf["ttl"] -= dt
		if lf["ttl"] <= 0.0:
			w.despawn(eid)
	for eid in w.query(["emote", "heard"]):
		for n in ["emote", "heard"]:
			var c: Dictionary = w.getc(eid, n, {})
			if c.is_empty():
				continue
			c["t"] -= dt
			if c["t"] <= 0.0:
				w.stores[n].erase(eid)
	for i in range(w.cues.size() - 1, -1, -1):
		w.cues[i]["t"] -= dt
		if w.cues[i]["t"] <= 0.0:
			w.cues.remove_at(i)
