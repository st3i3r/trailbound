extends Node
## Save — one slot at user://save.json plus user://save.bak; writes go
## to a temp file then rename (GDD 22). save_version with migrations;
## every migration gets a fixture test. Budget: <100 KB, <100 ms load.
##
## State contents (§22): seed, day, site, phase, coins, per-site state,
## pantry, meals, recipes, journal, letters, dog, Daily, ad pacing,
## Remove Ads entitlement — and crew: {structure, stage, seconds_left,
## last_seen_utc, speedups_stage, speedups_today, collected: []}.

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.bak"
const SAVE_VERSION := 1


## Fresh §22 skeleton. Migrations may fill keys but never remove them,
## so every older save loads against this shape.
func default_state() -> Dictionary:
	return {
		"save_version": SAVE_VERSION, "seed": 0, "day": 0,
		"site": "pinewatch", "phase": 0, "coins": 0,
		"sites": {}, "pantry": {}, "meals": [], "recipes": [],
		"journal": {}, "letters": [],
		"dog": {"name": "", "bond": 0},
		"daily": {"date": "", "score": -1},
		"crew": {"structure": "", "stage": 0, "seconds_left": 0.0,
			"last_seen_utc": 0, "speedups_stage": 0,
			"speedups_today": 0, "speedups_day": "", "collected": []},
		"ads": {"remove_ads": false, "last_interstitial_day": 0,
			"last_interstitial_utc": 0, "double_tips_used": false},
	}


func save_state(state: Dictionary) -> void:
	state["save_version"] = SAVE_VERSION
	var tmp := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	tmp.store_string(JSON.stringify(state))
	tmp.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
	DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)


func load_state() -> Dictionary:
	for path in [SAVE_PATH, BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			return _migrate(parsed)
	return {}


func _migrate(state: Dictionary) -> Dictionary:
	var version := int(state.get("save_version", 0))
	while version < SAVE_VERSION:
		version += 1
		# match version: → run migration step (§22)
	# Fill any keys this version added since the save was written.
	for key in default_state():
		state.get_or_add(key, default_state()[key])
	return state
