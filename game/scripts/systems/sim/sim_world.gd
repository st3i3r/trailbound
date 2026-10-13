class_name SimWorld
extends RefCounted
## Sim/view-split ECS world (PLAN_gameplay D4): int-id entities,
## dict component stores, systems ticked in order under one seeded
## rng. Pure data — no Nodes — so it runs headless and replays
## deterministically. Actor state is ephemeral: the Director
## rebuilds it per phase from Game state; it is never serialized.

var next_eid := 1
var stores := {}                        # comp name -> {eid: Dictionary}
var rng := RandomNumberGenerator.new()
var t := 0.0                            # sim clock, seconds
var ctx := {}                           # cast context: weather,
                                        # vignette, items — set by
                                        # the Director, read by
                                        # select/if branch ops
var cues := []                          # live stimuli [{pos, cue,
                                        # tags, src, t}] — transient
                                        # channel; tagged entities
                                        # are the continuous channel


func emit(pos: Vector2, cue: String, src: int, ttl := 2.0,
		tags: Array = []) -> void:
	cues.append({"pos": pos, "cue": cue, "src": src, "t": ttl,
		"tags": tags if not tags.is_empty() else [cue]})


func _init(seed := 1) -> void:
	rng.seed = seed


func spawn(comps: Dictionary) -> int:
	var eid := next_eid
	next_eid += 1
	for n in comps:
		put(eid, n, comps[n])
	return eid


func despawn(eid: int) -> void:
	for n in stores:
		stores[n].erase(eid)


func put(eid: int, n: StringName, data: Dictionary) -> void:
	if not stores.has(n):
		stores[n] = {}
	stores[n][eid] = data


func getc(eid: int, n: StringName, def: Variant = null) -> Variant:
	return stores.get(n, {}).get(eid, def)


func has(eid: int, n: StringName) -> bool:
	return stores.get(n, {}).has(eid)


## eids carrying every named component.
func query(names: Array) -> Array:
	var out := []
	if names.is_empty():
		return out
	for eid in stores.get(names[0], {}):
		var ok := true
		for n in names.slice(1):
			if not stores.get(n, {}).has(eid):
				ok = false
				break
		if ok:
			out.append(eid)
	return out


func tick(dt: float) -> void:
	t += dt
	SimSystems.schedule(self, dt)
	SimSystems.move(self, dt)
	SimSystems.sense(self, dt)
	SimSystems.life(self, dt)
