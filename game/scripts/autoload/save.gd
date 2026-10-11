extends Node
## Save — one slot at user://save.json plus user://save.bak; writes go
## to a temp file then rename (GDD 22). save_version with migrations;
## every migration gets a fixture test. Budget: <100 KB, <100 ms load.

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.bak"
const SAVE_VERSION := 1


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
	return state
