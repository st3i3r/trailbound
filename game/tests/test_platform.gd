extends "res://tests/harness.gd"
## Platform seam checks — §20 Remote Config surface, crash capture,
## launch attribution, §17.6 review gate, notification quiet hours,
## §25 opt-in/restore events, Play Games mock round-trip.
##   godot --headless --path game tests/test_platform.tscn


func _names(evts: Array) -> Array:
	var out := []
	for e in evts:
		out.append(String(e.get("name", "")))
	return out


func _ready() -> void:
	print("=== platform seams ===")
	Analytics.capture = true
	Analytics.clear_capture()
	Platform.remote_overrides = {}
	Platform.crash_capture = true
	Platform.crash_events = []
	Platform.achievements = {}
	Platform.cloud_blob = ""
	Platform.cloud_pushes = 0
	# prior runs persist remove_ads via restore_purchases+commit —
	# reset the entitlement the real save file may carry in
	Game.ads["remove_ads"] = false

	# remote(): override wins, fallback holds, typed values pass
	check("remote fallback when no override",
		Platform.remote("nope", 42) == 42)
	Platform.remote_overrides["ad_interstitial_from_day"] = 3
	check("remote override wins",
		int(Platform.remote("ad_interstitial_from_day", 5)) == 3)
	check("remote float passes through",
		is_equal_approx(float(Platform.remote("x", 1.5)), 1.5))

	# pacing really reads the override: day-1 gate vs day-3 override
	Game.phase = Game.Phase.MORNING
	Game.day = 1
	check("interstitial blocked before floor",
		not Ads.can_show_interstitial())
	Game.day = 5
	Game.ads["last_interstitial_day"] = 0
	Game.ads["last_interstitial_utc"] = 0
	Game.ads["last_rewarded_utc"] = 0
	Game.ads["last_rewarded_day"] = -1
	Platform.remote_overrides["ad_interstitial_from_day"] = 99
	check("remote override re-paces the gate",
		not Ads.can_show_interstitial())
	Platform.remote_overrides.erase("ad_interstitial_from_day")
	check("default floor resumes", Ads.can_show_interstitial())

	# crash capture + launch attribution
	Platform.report_nonfatal("script_error", {"where": "test"})
	check("nonfatal captured",
		Platform.crash_events.size() == 1
			and Platform.crash_events[0]["kind"] == "script_error")
	Platform.crash_capture = false
	Platform.report_nonfatal("ignored", {})
	check("capture off drops reports",
		Platform.crash_events.size() == 1)
	Platform.crash_capture = true

	# quiet hours fold into 08:00 (§24.5)
	check("quiet hours fold",
		Platform.schedule_daily_reminder(23) == 8
			and Platform.schedule_daily_reminder(0) == 8
			and Platform.schedule_daily_reminder(18) == 18)

	# opt-in + restore events land in §25 names
	Platform.note_notification_opt_in("daily_reminder", true)
	check("notification_opt_in emitted",
		"notification_opt_in" in _names(Analytics.captured()))
	Platform.restore_purchases()
	check("iap_restore emitted",
		"iap_restore" in _names(Analytics.captured()))

	# review gate: needs an all-5★ night AND min day AND cooldown
	Game.ads["first_all5_day"] = 0
	Game.day = 30
	check("review blocked without all-5★",
		not Platform.can_request_review())
	Game.ads["first_all5_day"] = 9
	Game.ads["last_review_utc"] = 0
	check("review allowed after all-5★ + floor",
		Platform.can_request_review())
	check("request stamps cooldown",
		Platform.request_review()
			and not Platform.can_request_review())

	# Play Games mock: achievements dedupe, blob round-trips
	check("achievement unlocks once",
		Platform.unlock_achievement(&"first_stamp")
			and not Platform.unlock_achievement(&"first_stamp"))
	Game.coins = 100
	Game.commit()
	check("commit pushes the cloud blob",
		Platform.cloud_pushes >= 1 and Platform.cloud_blob != "")
	check("cloud pull round-trips",
		Platform.cloud_save_pull() == Platform.cloud_blob)

	# leave the save file neutral — restore_purchases set
	# remove_ads above and commit() persists it for the next run
	Game.ads["remove_ads"] = false
	Game.commit()
	Analytics.capture = false
	finish()
