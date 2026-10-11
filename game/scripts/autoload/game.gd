extends Node
## Game — phase state machine and day/site flow (GDD 21.1).
## Boot → Title → Morning → Prep → Evening → Night, one in-game day
## at a time, player-paced (D-02 Path B: no real-time timers).

signal phase_changed(phase: Phase)

enum Phase { BOOT, TITLE, MORNING, PREP, EVENING, NIGHT }

var phase: Phase = Phase.BOOT
var day: int = 0
var site_id: StringName = &"pinewatch"


func set_phase(next: Phase) -> void:
	if next == phase:
		return
	phase = next
	phase_changed.emit(phase)


func advance_day() -> void:
	day += 1
	set_phase(Phase.MORNING)
