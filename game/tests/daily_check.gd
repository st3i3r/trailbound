extends Node
## §10 CI sweep: solve the next N dailies, apply the deterministic
## reroll chain, bake accepted try-counts into data/daily_seeds.json.
##
##   godot --headless --path game tests/daily_check.tscn -- \
##       --from 0 --days 400 [--write]
##   godot --headless --path game tests/daily_check.tscn -- \
##       --once 2025-01-01
##
## --from/--days pick a window of days since launch so the sweep can
## be sharded across CI workers; --write merges results into
## data/daily_seeds.json (without it the run only reports).

## Per-seed acceptance is ~1-in-5 under the §10 gate; 32 tries keeps
## forced dates rare. A forced date keeps the strongest candidate of
## the chain (highest best, then widest gap), flagged in the report.
const MAX_TRIES := 32
const OUT_PATH := "res://data/daily_seeds.json"


func _parse_args() -> Dictionary:
	var a := {"from": 0, "days": 400, "write": false, "once": "",
		"out": OUT_PATH}
	var argv := OS.get_cmdline_user_args()
	var i := 0
	while i < argv.size():
		match argv[i]:
			"--from": a["from"] = int(argv[i + 1]); i += 1
			"--days": a["days"] = int(argv[i + 1]); i += 1
			"--write": a["write"] = true
			"--once": a["once"] = argv[i + 1]; i += 1
			"--out": a["out"] = argv[i + 1]; i += 1
		i += 1
	return a


func _date_of(day_n: int) -> String:
	var t := Time.get_unix_time_from_datetime_string(
		Game.DAILY_EPOCH + "T00:00:00")
	t += day_n * 86400
	return Time.get_date_string_from_unix_time(int(t))


func _solve_date(d: String, kinds: Dictionary) -> Dictionary:
	var top := {}
	var top_tries := 0
	for k in MAX_TRIES:
		var pz := Game._daily_gen(d, k)
		var r := Seating.daily_solve(pz, kinds)
		if r["accept"]:
			r["tries"] = k
			return r
		if top.is_empty() or r["best"] > top["best"] \
				or (r["best"] == top["best"]
					and r["gap"] > top["gap"]):
			top = r
			top_tries = k
	top["tries"] = top_tries
	top["forced"] = true
	return top


func _ready() -> void:
	var args := _parse_args()
	var kinds := Game._trait_kinds()
	if args["once"] != "":
		var t0 := Time.get_ticks_msec()
		var pz := Game._daily_gen(args["once"], 0)
		var r := Seating.daily_solve(pz, kinds)
		print("%s  best=%d naive=%d gap=%d accept=%s  %dms" % [
			args["once"], r["best"], r["naive"], r["gap"],
			r["accept"], Time.get_ticks_msec() - t0])
		get_tree().quit(0)
		return

	var seeds := {}
	var stats := {"solved": 0, "rerolled": 0, "forced": [],
		"best_sum": 0, "best_min": 99, "best_max": -1,
		"gap_sum": 0, "gap_min": 99}
	var worst := []
	for n in range(args["from"], args["from"] + args["days"]):
		var d := _date_of(n)
		var r := _solve_date(d, kinds)
		seeds[d] = r["tries"]
		stats["solved"] += 1
		if r["tries"] > 0:
			stats["rerolled"] += 1
		if r.get("forced", false):
			stats["forced"].append(d)
		stats["best_sum"] += r["best"]
		stats["best_min"] = mini(stats["best_min"], r["best"])
		stats["best_max"] = maxi(stats["best_max"], r["best"])
		stats["gap_sum"] += r["gap"]
		stats["gap_min"] = mini(stats["gap_min"], r["gap"])
		worst.append([r["best"], d])
		print("%s  #%d  best=%d naive=%d gap=%d tries=%d%s" % [
			d, n, r["best"], r["naive"], r["gap"], r["tries"],
			" FORCED" if r.get("forced", false) else ""])

	worst.sort()
	print("--- %d dailies ---" % stats["solved"])
	print("rerolled: %d  forced-unacceptable: %s" % [
		stats["rerolled"], stats["forced"]])
	print("best: avg %.1f  min %d  max %d" % [
		float(stats["best_sum"]) / stats["solved"],
		stats["best_min"], stats["best_max"]])
	print("gap:  avg %.1f  min %d" % [
		float(stats["gap_sum"]) / stats["solved"], stats["gap_min"]])
	print("hardest: %s" % [worst.slice(0, 5)])

	if args["write"]:
		var out: String = args["out"]
		var existing := {}
		if FileAccess.file_exists(out):
			var parsed = JSON.parse_string(
				FileAccess.get_file_as_string(out))
			if parsed is Dictionary:
				existing = parsed.get("seeds", {})
		for d in seeds:
			existing[d] = seeds[d]
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify({
			"note": "§10 CI bake: date -> accepted reroll count (tests/daily_check).",
			"seeds": existing}, "  "))
		f.close()
		print("wrote %s (%d dates)" % [out, existing.size()])
	get_tree().quit(0 if stats["forced"].is_empty() else 1)
