extends RefCounted
## Volume II restorations (§6.11) — per-site crew teams working the
## two reserved overgrown plots. The player pays for each stage;
## real time paces it under the §6.10 speed-up rules.
##
## v1's single crew (§8.4) is untouched — this is a parallel team
## map keyed by site. All state lives in site_state()["restorations"]
## so the existing save schema carries it.

var g  # the Game autoload (untyped: circular ref)


func _init(game) -> void:
	g = game


func _fresh_team() -> Dictionary:
	return {"structure": "", "stage": 0, "seconds_left": 0.0,
		"last_seen_utc": 0, "speedups_stage": 0,
		"speedups_today": 0, "speedups_day": ""}


func _state(site: StringName) -> Dictionary:
	var st: Dictionary = g.site_state(site)
	if not st.has("restorations"):
		st["restorations"] = {"team": _fresh_team(), "progress": {}}
	return st["restorations"]


func _structure(sid: StringName) -> Dictionary:
	for s in g._structures():
		if s.get("id") == sid and s.get("volume2", false):
			return s
	return {}


func restored(site: StringName, sid: StringName) -> bool:
	return sid in g.site_state(site)["restored"]


## UI list: every Vol II structure at this site with progress.
func status(site: StringName) -> Dictionary:
	var rs := _state(site)
	var list := []
	for s in g._structures():
		if not s.get("volume2", false) or s.get("site") != site:
			continue
		var done: int = rs["progress"].get(s["id"], 0)
		var total: int = s["stages"].size()
		list.append({"id": s["id"], "label": s["label"],
			"plot": s.get("plot", ""), "stages_done": done,
			"total": total, "restored": done >= total,
			"next_cost": (0 if done >= total
				else int(s["stages"][done].get("cost", 0))),
			"running": rs["team"]["structure"] == s["id"],
			"seconds_left": (rs["team"]["seconds_left"]
				if rs["team"]["structure"] == s["id"] else 0.0)})
	return {"team": rs["team"], "list": list}


func can_start(sid: StringName) -> bool:
	var s := _structure(sid)
	if s.is_empty() or not g.vol2_open():
		return false
	var site: StringName = s.get("site", &"")
	var rs := _state(site)
	var done: int = rs["progress"].get(sid, 0)
	if done >= s["stages"].size() or rs["team"]["structure"] != "":
		return false
	return g.coins >= int(s["stages"][done].get("cost", 0))


## Pay the stage's cost; that site's team starts on it (§6.11).
func start(sid: StringName) -> bool:
	if not can_start(sid):
		return false
	var s := _structure(sid)
	var site: StringName = s.get("site", &"")
	var rs := _state(site)
	var done: int = rs["progress"].get(sid, 0)
	var stage: Dictionary = s["stages"][done]
	g.coins -= int(stage.get("cost", 0))
	rs["team"]["structure"] = sid
	rs["team"]["stage"] = done
	rs["team"]["seconds_left"] = float(stage["seconds"])
	rs["team"]["last_seen_utc"] = int(Time.get_unix_time_from_system())
	rs["team"]["speedups_stage"] = 0
	return true


## §8.4 clock semantics, per team: progress = max(0, now − last
## seen); a clock set back never undoes work. Drives all three site
## teams each tick.
func tick(now := int(Time.get_unix_time_from_system())) -> void:
	for site in [&"pinewatch", &"whisper_river", &"lantern_valley"]:
		var team: Dictionary = _state(site)["team"]
		var last: int = team["last_seen_utc"]
		team["last_seen_utc"] = now
		if team["structure"] == "" or team["seconds_left"] <= 0.0:
			continue
		team["seconds_left"] = maxf(0.0,
			team["seconds_left"] - maxi(0, now - last))


## Collect a finished stage: structure progress advances; the last
## stage applies the §6.11 effect and stamps `restored`. The next
## stage waits for the player to pay — real time never blocks
## anything but these pages (§33.6).
func collect(site: StringName) -> Dictionary:
	var rs := _state(site)
	var team: Dictionary = rs["team"]
	if team["structure"] == "" or team["seconds_left"] > 0.0:
		return {}
	var s := _structure(team["structure"])
	var sid: StringName = s["id"]
	rs["progress"][sid] = int(rs["progress"].get(sid, 0)) + 1
	var finished: bool = rs["progress"][sid] >= s["stages"].size()
	team["structure"] = ""
	team["seconds_left"] = 0.0
	if finished:
		g.site_state(site)["restored"].append(sid)
		_apply_effect(sid)
		g._check_pages()                     # pages 6/7 ride on this
	return {"structure": sid, "stage": rs["progress"][sid],
		"finished": finished}


## §6.11 effects. Site-state mutations only — the world builder and
## board generator pick them up.
func _apply_effect(sid: StringName) -> void:
	var s := _structure(sid)
	var site: StringName = s.get("site", &"")
	var st: Dictionary = g.site_state(site)
	var e: Dictionary = s.get("effect", {})
	match String(e.get("kind", "")):
		"pad_tags":
			for pid in e.get("pads", []):
				var tags: Array = st["pad_tags"].get(pid, [])
				if e["tag"] not in tags:
					tags.append(e["tag"])
				st["pad_tags"][pid] = tags
		"add_pad":
			st["pads"][e["pad"]] = {"open": true,
				"shelter": e.get("shelter", "platform")}
		"aura":
			st["decor"].append({"id": sid + "_aura", "aura": true,
				"effect": e["effect"], "reach": int(e["reach"]),
				"cells": e["cells"].map(
					func(c): return Vector2i(c[0], c[1]))})
		"seats":
			st["seats"] += int(e.get("seats", 0))
			st["walk_bonus"] += int(e.get("walk_ins", 0))


## The site row with restoration mix tweaks applied — Fire Tower
## moves 10% of Couples to Photographers, Pond Dock 10% of Hikers
## to Anglers (§6.11). Called by new_day's board roll.
func site_row(row: Dictionary, site: StringName) -> Dictionary:
	var st: Dictionary = g.site_state(site)
	if st["restored"].is_empty():
		return row
	var mix: Dictionary = row.get("archetype_mix", {}).duplicate()
	var changed := false
	for s in g._structures():
		if s.get("id") not in st["restored"]:
			continue
		var m: Dictionary = s.get("effect", {}).get("mix", {})
		if m.is_empty():
			continue
		mix[m["add"]] = int(mix.get(m["add"], 0)) + int(m["weight"])
		mix[m["from"]] = maxi(0,
			int(mix.get(m["from"], 0)) - int(m["weight"]))
		changed = true
	if not changed:
		return row
	var out := row.duplicate()
	out["archetype_mix"] = mix
	return out


## §6.10 speed-ups, same caps as the v1 crew, per team.
func can_speedup(site: StringName) -> bool:
	var team: Dictionary = _state(site)["team"]
	if g.day < g.SPEEDUP_FROM_DAY or team["structure"] == "" \
			or team["seconds_left"] <= 0.0:
		return false
	var today_used: int = team["speedups_today"] \
		if team["speedups_day"] == g._today() else 0
	return team["speedups_stage"] < g.SPEEDUPS_PER_STAGE \
		and today_used < g.SPEEDUPS_PER_DAY


func speedup(site: StringName) -> float:
	if not can_speedup(site):
		return 0.0
	var team: Dictionary = _state(site)["team"]
	if team["speedups_day"] != g._today():
		team["speedups_day"] = g._today()
		team["speedups_today"] = 0
	var stage: Dictionary = _structure(
		team["structure"])["stages"][team["stage"]]
	var chunk := maxf(g.SPEEDUP_MIN_CHUNK,
		float(stage["seconds"]) / 6.0)
	team["seconds_left"] = maxf(0.0, team["seconds_left"] - chunk)
	team["speedups_stage"] += 1
	team["speedups_today"] += 1
	return chunk


func free_finish(site: StringName) -> bool:
	var team: Dictionary = _state(site)["team"]
	if team["structure"] == "" \
			or team["seconds_left"] > g.FREE_FINISH_LEFT:
		return false
	team["seconds_left"] = 0.0
	return true
