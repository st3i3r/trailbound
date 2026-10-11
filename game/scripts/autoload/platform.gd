extends Node
## Platform — billing (Remove Ads), notifications, in-app review,
## back button, safe areas (GDD 21.1, 17.6).


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		pass  # back-button behaviour lands with the UI screens (§17.6)


func is_ads_removed() -> bool:
	return false
