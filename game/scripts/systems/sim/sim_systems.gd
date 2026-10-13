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
						w.put(eid, "mover", {
							"speed": float(step.get("speed", 50.0)),
							"target": Vector2(
								float(step["to"][0]),
								float(step["to"][1])),
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
				_:
					_next(sc)


static func _next(sc: Dictionary) -> void:
	sc["i"] += 1
	if sc["i"] >= sc["steps"].size():
		sc["i"] = sc["steps"].size() - 1
	sc["started"] = false


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


## Timers: life.ttl despawns the entity; emote.t clears the icon.
static func life(w: SimWorld, dt: float) -> void:
	for eid in w.query(["life"]):
		var lf: Dictionary = w.getc(eid, "life")
		lf["ttl"] -= dt
		if lf["ttl"] <= 0.0:
			w.despawn(eid)
	for eid in w.query(["emote"]):
		var em: Dictionary = w.getc(eid, "emote")
		em["t"] -= dt
		if em["t"] <= 0.0:
			w.stores["emote"].erase(eid)
