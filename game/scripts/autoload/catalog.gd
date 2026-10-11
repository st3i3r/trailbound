extends Node
## Catalog — loads and validates game/data JSON, serves items, traits,
## recipes and pages (GDD 21.1-21.2). IDs are stable snake_case; saves
## store IDs, never indexes.

const DATA_DIR := "res://data/"

## file stem -> parsed JSON (Array or Dictionary)
var data: Dictionary = {}


func _ready() -> void:
	var errors := load_all()
	for error in errors:
		push_error("Catalog: " + error)


func load_all() -> PackedStringArray:
	var errors: PackedStringArray = []
	for file in DirAccess.get_files_at(DATA_DIR):
		if not file.ends_with(".json"):
			continue
		var stem := file.get_basename()
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(DATA_DIR + file))
		if parsed == null:
			errors.append("%s: invalid JSON" % file)
			continue
		data[stem] = parsed
	return errors


## §21.2 CI rules land here as they grow: every reference resolves,
## every unlock reachable, no page needs an item from a later page.
func validate() -> PackedStringArray:
	return []
