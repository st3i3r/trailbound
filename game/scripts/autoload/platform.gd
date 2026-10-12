extends Node
## Platform — billing (Remove Ads), notifications, in-app review,
## back button, safe areas (GDD 21.1, 17.6).


signal back_pressed
## Android Back / gesture. Scenes decide what it means (§17.6): close
## the top sheet, or on the Camp screen ask before quitting.


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back_pressed.emit()


func is_ads_removed() -> bool:
	return false
