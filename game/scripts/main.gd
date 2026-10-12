extends Node2D
## Phase 0 scaffold root — placeholder scene so F5 and Android installs
## have something to draw before the Pinewatch greybox (GDD 29).

@onready var phase_label: Label = $CanvasLayer/Phase


func _ready() -> void:
	Game.set_phase(Game.Phase.TITLE)
	Game.phase_changed.connect(_on_phase_changed)
	# title screen: Android Back quits (auto-accept is off in Platform)
	Platform.back_pressed.connect(get_tree().quit)
	print("Trailbound scaffold boot — catalog entries: %d" % Catalog.data.size())


func _on_phase_changed(phase: Game.Phase) -> void:
	phase_label.text = "phase: %s" % Game.Phase.keys()[phase].to_lower()
