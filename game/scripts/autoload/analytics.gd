extends Node
## Analytics — event adapter over Firebase Analytics (GDD 21.1, 25).
## No-op on desktop and in tests; the plugin lands in the Phase 0 spike.


func log_event(_event_name: StringName, _params: Dictionary = {}) -> void:
	pass
