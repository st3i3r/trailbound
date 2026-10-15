extends "res://tests/harness.gd"
## Scenario-matrix runner — data-driven playthrough QA.
##
## Every file in tests/scenarios/*.json is a deterministic playtest:
## setup -> op script -> expectations, replayed headlessly against the
## REAL Game verb surface (the same calls the UI makes — never a
## privileged back door).  Design debts paid forward:
##
##   * declarative matrix (GameTest/approval-test pattern): a scenario
##     is diffable JSON — adding coverage never touches code.
##   * save roundtrip checkpoint: {"op":"save_load"} serializes and
##     reloads mid-script — the §22 spine can't silently break replay.
##   * determinism twin-run ("twice":true): the whole scenario runs a
##     second time from scratch and the canonical end-state must be
##     byte-identical — catches Time/randf/dict-order leaks like a
##     lockstep desync check.
##   * golden hash: "hash" locks the canonical end-state; --record
##     rewrites files with fresh hashes after intentional changes.
##
## Ops map 1:1 onto public verbs; a few fixture ops (inject_guest /
## inject_decor) write state directly — same as harness _inject/_put.
##
## Expect paths: coins/day/phase/meals.count/pantry.has/gear.has/
## recipes.has/fund_total resolve on Game; site.<key>[.count|.<sub>]
## reads Game.site_state(); crew.<key>/dog.<key> likewise.  Key
## suffixes >= <= > < != compare; .has checks membership.
##
## Run:  godot --headless --path game tests/test_scenario.tscn
##        [--record]  — rewrite scenario files with fresh hashes.

const SCN_DIR := "res://tests/scenarios/"

var _record := false
var _op_fail := 0
var _step := ""


func _ready() -> void:
	_record = "--record" in OS.get_cmdline_user_args()
	print("=== scenario matrix (tests/scenarios/*.json) ===")
	var files := DirAccess.get_files_at(SCN_DIR)
	files.sort()
	var ran := 0
	for f in files:
		if f.ends_with(".json"):
			_run_scenario(f)
			ran += 1
	check("scenario files found", ran > 0, SCN_DIR)
	finish()


func _run_scenario(file: String) -> void:
	var raw: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(SCN_DIR + file))
	if not raw is Dictionary:
		check(file + " parses", false, "not a Dictionary")
		return
	var scn: Dictionary = raw
	var id := String(scn.get("id", file.get_basename()))
	scn["_file"] = file
	var fails0 := failures + _op_fail
	var end1 := _play(scn, id)
	check("%s: run completes" % id, failures + _op_fail == fails0)
	if _record:
		_write_hash(scn, id, end1)
	elif scn.has("hash"):
		check("%s: golden hash" % id,
			_canon_hash(end1) == int(scn["hash"]),
			"want %s got %s" % [scn["hash"], _canon_hash(end1)])
	if scn.get("twice", false):
		var fails1 := failures + _op_fail
		var end2 := _play(scn, id)
		check("%s: deterministic replay" % id,
			_canon_state(end1) == _canon_state(end2),
			"end-state drifted between runs")
		check("%s: replay completes" % id,
			failures + _op_fail == fails1)


# One full playthrough; returns the canonical end-state Dictionary.
func _play(scn: Dictionary, id: String) -> Dictionary:
	var state := Save.default_state()
	_merge(state, _intify(scn.get("setup", {})))
	Game.load_state(state)
	Game.visit_site(StringName(scn.get("site", "pinewatch")))
	for i in (scn.get("steps", []) as Array).size():
		var step: Dictionary = scn["steps"][i]
		_step = "%s/%d:%s" % [id, i, step.get("op", "?")]
		_do(step, id)
	return Game.state_dict()


func _do(step: Dictionary, id: String) -> void:
	var op := String(step.get("op", ""))
	var ok := true
	match op:
		"new_day": Game.new_day()
		"set_phase": Game.set_phase(
			Game.Phase.get(String(step["phase"]).to_upper()))
		"advance_day": Game.advance_day()
		"goodnight": Game.goodnight()
		"undo": ok = Game.undo()
		"save_load": Game.load_state(Game.state_dict())
		"visit": Game.visit_site(StringName(step["site"]))
		"travel": ok = Game.travel_to(StringName(step["site"]))
		"seat": ok = Game.seat(_gid(step["guest"]),
			_arr(step["pads"]))
		"unseat": Game.unseat(_gid(step["guest"]))
		"serve": ok = Game.serve_meal(_gid(step["guest"]),
			_meal_id(step.get("meal", 0)))
		"cook": Game.cook(String(step["a"]), String(step["b"]))
		"buy_staple": ok = Game.buy_staple(String(step["id"]))
		"buy_decor": ok = Game.buy_decor(String(step["id"]),
			_cells(step["cells"]))
		"buy_decor_variant": ok = Game.buy_decor_variant(
			int(step["idx"]), String(step["name"]))
		"move_decor": ok = Game.move_decor(int(step["idx"]),
			_cells(step["cells"]))
		"store_decor": ok = Game.store_decor(int(step["idx"]))
		"unlock_pad": ok = Game.unlock_pad(String(step["pad"]))
		"clear_pad": ok = Game.clear_pad(String(step["pad"]))
		"buy_gear": ok = Game.buy_gear(String(step["id"]))
		"donate_fund": Game.donate_fund(int(step["amount"]))
		"crew_start": Game.crew_start(StringName(step["structure"]))
		"crew_collect": Game.crew_collect()
		"crew_tick": Game.crew_tick(int(step["now"]))
		"crew_set": Game.crew[String(step["key"])] = _intify(step.get("value"))
		"dog_pet": ok = Game.dog_pet()
		"inject_guest": _inj_guest(step)
		"inject_decor": _inj_decor(step)
		"site_set": Game.site_state()[String(step["key"])] = \
			_intify(step.get("value"))
		"expect": ok = _expect(step, id)
		"probe":
			print("    .. probe unlock(%s)=%s pantry=%d/%d row=%s pages=%s" % [
				step.get("unlock", "P1"),
				Game._is_unlocked(String(step.get("unlock", "P1"))),
				Game.pantry_count(), Game.pantry_capacity(),
				Game._row("ingredients", String(step.get("id", "tea"))),
				Game.site_state().get("pages_done")])
		"log": print("    .. %s" % step.get("msg", ""))
		_: ok = false
	if ok == bool(step.get("must_fail", false)):
		_op_fail += 1
		print("  XX %s %s" % [_step,
			"expected to fail but passed" if ok else "failed"])


func _intify(v: Variant) -> Variant:
	## JSON numbers are all float; engine state wants ints for whole
	## values — `1 in [1.0]` fails the unlock ladder otherwise.
	if v is float:
		return int(v) if v == floorf(v) else v
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _intify(v[k])
		return d
	if v is Array:
		return v.map(func(e): return _intify(e))
	return v


func _inj_guest(step: Dictionary) -> void:
	Game.site_state()["guests"][String(step["id"])] = {
		"id": String(step["id"]),
		"archetype": String(step.get("arch", "hiker")),
		"traits": step.get("traits", []),
		"loud": bool(step.get("loud", false)),
		"fee": int(step.get("fee", 40)),
		"pads": int(step.get("pads", 1)),
		"favourite": String(step.get("favourite", ""))}


func _inj_decor(step: Dictionary) -> void:
	Game.site_state()["decor"].append({"id": String(step["id"]),
		"effect": String(step.get("effect", "")),
		"reach": int(step.get("reach", 1)),
		"cells": _cells(step["cells"])})


# --- resolvers ---------------------------------------------------------------

func _gid(v: Variant) -> String:
	## "hiker" is a literal id; "#0" is the Nth guest (sorted ids).
	var s := String(v)
	var keys: Array = Game.site_state()["guests"].keys()
	keys.sort()
	if s.begins_with("#"):
		var i := int(s.trim_prefix("#"))
		return String(keys[i]) if i >= 0 and i < keys.size() else ""
	return s


func _meal_id(v: Variant) -> String:
	if v is String:
		return v
	var i := int(v)
	return String(Game.meals[i].get("id", "")) \
		if i >= 0 and i < Game.meals.size() else ""


func _cells(v: Variant) -> Array:
	var out := []
	for c in v:
		out.append(Vector2i(int(c[0]), int(c[1])))
	return out


func _arr(v: Variant) -> Array:
	return (v as Array).duplicate() if v is Array else []


# --- expectations ------------------------------------------------------------

func _expect(spec: Dictionary, id: String) -> bool:
	var all := true
	for k in spec.keys():
		if k == "op":
			continue
		var key := String(k)
		var op := "=="
		for suf in [">=", "<=", "!=", ".has", ">", "<"]:
			if key.ends_with(suf):
				op = suf; key = key.trim_suffix(suf); break
		var got: Variant = _resolve(key)
		var want: Variant = spec[k]
		var one := _compare(got, want, op)
		if not one:
			all = false
			print("  XX %s expect %s%s %s (got %s)" % [
				_step, key, op, want, got])
	return all


func _resolve(path: String) -> Variant:
	var parts := path.split(".")
	var st: Dictionary = Game.site_state()
	var view := {"site_id": String(Game.site_id),
		"coins": Game.coins, "day": Game.day,
		"phase": Game.Phase.keys()[Game.phase].to_lower(),
		"meals": Game.meals, "pantry": Game.pantry,
		"gear": Game.gear, "recipes": Game.recipes_cooked,
		"fund_total": Game.fund_total, "crew": Game.crew,
		"dog": Game.dog, "site": st}
	var cur: Variant = view
	for p in parts:
		if p == "count" and (cur is Array or cur is Dictionary):
			return cur.size()
		if cur is Dictionary and cur.has(p):
			cur = cur[p]
		else:
			return null
	return cur


func _compare(got: Variant, want: Variant, op: String) -> bool:
	match op:
		"==": return got == want
		"!=": return got != want
		">=": return got is int and got >= int(want) \
			or got is float and got >= float(want)
		"<=": return got is int and got <= int(want) \
			or got is float and got <= float(want)
		">": return got is int and got > int(want) \
			or got is float and got > float(want)
		"<": return got is int and got < int(want) \
			or got is float and got < float(want)
		".has":
			var w: Array = want if want is Array else [want]
			if got is Array:
				for x in w:
					if x not in got:
						return false
				return true
			if got is Dictionary:
				for x in w:
					if not got.has(x):
						return false
				return true
			return false
	return false


# --- canonical state + golden hash -------------------------------------------

func _canon(v: Variant) -> Variant:
	## Deterministic form: dict keys sorted, everything else verbatim —
	## JSON.stringify on it is a stable serialization for hashing.
	if v is Dictionary:
		var d := {}
		var keys: Array = v.keys()
		keys.sort()
		for k in keys:
			d[String(k)] = _canon(v[k])
		return d
	if v is Array:
		return v.map(func(e): return _canon(e))
	if v is Vector2i:
		return [v.x, v.y]
	if v is Vector2:
		return [v.x, v.y]
	if v is StringName:
		return String(v)
	return v


## Fields a correct run legitimately varies on — device-clock stamps,
## not sim state.  Stripped before comparing so twice/golden checks
## see the deterministic core (the desync-check rule: volatile
## wall-clock fields never enter the hash).
const VOLATILE := [
	["crew", "last_seen_utc"], ["ads", "last_review_utc"],
	["ads", "last_interstitial_utc"], ["ads", "last_rewarded_utc"]]


func _canon_state(state: Dictionary) -> Dictionary:
	var c: Dictionary = _canon(state)
	for path in VOLATILE:
		var d: Variant = c
		for i in path.size() - 1:
			d = d.get(path[i], {})
		if d is Dictionary:
			d.erase(path[path.size() - 1])
	return c


func _canon_hash(state: Dictionary) -> int:
	return JSON.stringify(_canon_state(state)).hash()


func _merge(dst: Dictionary, src: Dictionary) -> void:
	for k in src:
		if src[k] is Dictionary and dst.get(k) is Dictionary:
			_merge(dst[k], src[k])
		else:
			dst[k] = src[k]


func _write_hash(scn: Dictionary, id: String, state: Dictionary) -> void:
	var path := SCN_DIR + String(scn.get("_file", ""))
	scn["hash"] = _canon_hash(state)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(scn, "  ") + "\n")
		f.close()
		print("    .. %s hash -> %s" % [id, scn["hash"]])
