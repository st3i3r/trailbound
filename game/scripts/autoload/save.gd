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
## v1 -> v2: the day spines (actions, day_log), the ads block's pacing
## fields (last_rewarded_day, first_all5_day, review + consent), and
## the settings keys the mock platform layer reads all landed together
## — the fill loop below is the whole migration, but the bump makes
## the schema change visible and gives the fixture test a hook.
const SAVE_VERSION := 2


## Fresh §22 skeleton. Migrations may fill keys but never remove them,
## so every older save loads against this shape.
func default_state() -> Dictionary:
	return {
		"save_version": SAVE_VERSION, "seed": 0, "day": 0,
		"site": "pinewatch", "phase": 0, "coins": 0,
		"sites": {}, "sites_visited": {}, "pantry": {},
		"meals": [], "recipes": [], "cook_counts": {},
		"fund_total": 0,
		"gear": [], "pairs_tried": {},
		"journal": {"vignettes_seen": [], "days_log": [],
			"personas_met": {}, "letters_any": []},
		"letters": [], "dialogue": {},
		"field_notes": [], "passport": [],
		"bought_today": [], "tips_doubled": -1,
		"dog": {"name": "", "bond": 0, "met": false,
			"adopted": false, "pet_today": false},
		"daily": {"date": "", "score": -1},
		"crew": {"structure": "", "stage": 0, "seconds_left": 0.0,
			"last_seen_utc": 0, "speedups_stage": 0,
			"speedups_today": 0, "speedups_day": "", "collected": []},
		"ads": {"remove_ads": false, "last_interstitial_day": 0,
			"last_interstitial_utc": 0, "last_rewarded_utc": 0,
			"double_tips_used": false, "first_all5_day": 0,
			"reviews_shown": 0, "last_review_utc": 0},
		"actions": [],           # §6.1 day-scoped undo spine (D2.2)
		"day_log": [],           # ordered event stream for the day (D2.4)
		"settings": {
			# §17.4 — volumes are 0..3 steps (0 = muted)
			"music": 3, "ambience": 3, "sfx": 3,
			"haptics": true,
			"daily_reminder": false,
			"crew_notification": true,
			"language": "en",
			"text_size": "normal",     # normal | large (pixel-safe +2 px)
			"reduced_motion": false,
			"reduced_flashing": false,
			"assist_mode": false,
			"left_handed": false,
			"rangers_tips": true,
		},
	}


var last_json_str := ""    # last committed blob — Saved Games seam


func last_json() -> String:
	return last_json_str


func save_state(state: Dictionary) -> void:
	state["save_version"] = SAVE_VERSION
	last_json_str = JSON.stringify(state)
	var tmp := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if tmp == null:
		# full storage / permission denial — report and bail; the
		# in-memory run continues and the next beat retries
		Platform.report_nonfatal("save_write_fail",
			{"err": FileAccess.get_open_error()})
		return
	tmp.store_string(last_json_str)
	tmp.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
	if DirAccess.rename_absolute(SAVE_PATH + ".tmp",
			SAVE_PATH) != OK:
		Platform.report_nonfatal("save_rename_fail", {})


## Title-menu gate: any restorable file (main or backup) means the
## Continue button is live.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) \
		or FileAccess.file_exists(BACKUP_PATH)


## Support/QA seam (offline games have no server-side state — "send
## us your save" is the only bug-report channel that shows the bug):
## base64 of the save blob for copy-paste; import validates, migrates
## and hands back a loadable state dict.
func export_text() -> String:
	var raw := FileAccess.get_file_as_string(SAVE_PATH)
	return "" if raw.is_empty() else Marshalls.utf8_to_base64(raw)


func import_text(b64: String) -> Dictionary:
	var raw := Marshalls.base64_to_utf8(b64.strip_edges())
	var parsed: Variant = JSON.parse_string(raw) if raw != null \
		else null
	if parsed is Dictionary:
		var st: Dictionary = _migrate(parsed)
		if int(st.get("save_version", 0)) >= 1:
			return st
	Platform.report_nonfatal("save_import_bad", {})
	return {}


func load_state() -> Dictionary:
	for path in [SAVE_PATH, BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			return _migrate(parsed)
		# corrupt file — fall through to the backup, but tell the
		# crash seam so silent data loss shows up in non-fatals
		Platform.report_nonfatal("save_corrupt",
			{"file": path.get_file()})
	return {}


func _migrate(state: Dictionary) -> Dictionary:
	var version := int(state.get("save_version", 0))
	while version < SAVE_VERSION:
		version += 1
		# match version: → run migration step (§22)
		#  v1 -> v2: day spines (actions, day_log) + ads pacing +
		#  dog.adopted/met keys — all handled by the fill below.
	state["save_version"] = version
	# Fill any keys this version added since the save was written —
	# nested defaults (ads/settings/dog/crew) merge sub-keys too, so a
	# v1 ads block gains last_rewarded_day without losing its data.
	var defaults := default_state()
	for key in defaults:
		var def: Variant = defaults[key]
		if not state.has(key):
			state[key] = def
		elif def is Dictionary and state[key] is Dictionary:
			for sk in def:
				# missing, or the type drifted between versions
				# (v1 personas_met was an Array, now a Dictionary)
				if not state[key].has(sk) \
						or (def[sk] is Dictionary \
							and not (state[key][sk] is Dictionary)) \
						or (def[sk] is Array \
							and not (state[key][sk] is Array)):
					state[key][sk] = def[sk]
	return state
