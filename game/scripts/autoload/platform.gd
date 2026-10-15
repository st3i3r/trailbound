extends Node
## Platform — billing (Remove Ads), notifications, in-app review,
## back button, safe areas (GDD 21.1, 17.6, 24). Everything is the
## mock layer until the plugins land (Phase 0 spike): verbs keep the
## real gates and persist through Game.ads, so tests exercise the
## exact rules the device build will.


signal back_pressed
## Android Back / gesture. Scenes decide what it means (§17.6): close
## the top sheet, or on the Camp screen ask before quitting.
signal close_requested
## Desktop window-close (the OS X button): auto_accept_quit is off so
## the request lands here — scenes save and quit themselves.


const REVIEW_MIN_DAY := 7            # §17.6: never prompt before day 7
const REVIEW_COOLDOWN_SEC := 90 * 86400   # Play caps prompts ~1/90d
const QUIET_FROM := 21               # notification quiet hours:
const QUIET_TO := 8                  #   21:00-08:00 local, push to 08:00

## §20 Remote Config seam: tuning values read through remote() so the
## Firebase plugin's fetched map slots in later — desktop and tests
## run on the call-site defaults (or overrides set directly below).
## Keys are snake_case dotted paths; only knobs that live in code
## (not data JSON) route here — content stays shipped (§13.2).
var remote_overrides := {}


## Live value for a tunable: Remote Config's fetched map wins, then
## the shipped default. Tests inject remote_overrides directly.
func remote(key: String, fallback: Variant) -> Variant:
	return remote_overrides.get(key, fallback)


## §25 app_open attribution: the plugin reports whether a notification
## opened this session ("daily", "crew") — mock always says direct.
## Consumed once so a warm FOCUS_IN later doesn't re-attribute.
var _launch_source: Variant = null
func launch_source() -> String:
	var s := String(_launch_source) if _launch_source != null else ""
	_launch_source = ""
	return s


## §20 Crashlytics seam: report script errors/handled faults as
## non-fatals. Desktop writes nothing; the adapter forwards
## recordException. `capture` mirrors Analytics for test assertions.
var crash_capture := false
var crash_events: Array = []
func report_nonfatal(kind: String, context := {}) -> void:
	if crash_capture:
		crash_events.append({"kind": kind,
			"context": context.duplicate(true)})


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back_pressed.emit()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		close_requested.emit()


# ---------------------------------------------------------- billing

## §24.4 Remove Ads entitlement — persisted in the save so an
## uninstall+restore (or the tester toggling it) behaves identically.
func is_ads_removed() -> bool:
	return bool(Game.ads.get("remove_ads", false))


## Mock purchase: on device this is the Billing flow's success
## callback — same state write either way.
func buy_remove_ads() -> bool:
	if is_ads_removed():
		return false
	Game.ads["remove_ads"] = true
	Game._log("purchase", {"id": "remove_ads"})
	Analytics.log_event(&"iap_remove_ads",
		{"source": "store", "result": "purchased"})
	Game.touch()
	return true


## Debug/QA: Play's restore-purchases path resolves to the same write.
func restore_purchases() -> bool:
	var had := is_ads_removed()
	var ok: bool = buy_remove_ads() if not had else true
	Analytics.log_event(&"iap_restore", {"source": "settings",
		"result": "restored" if ok and not had else "none"})
	return ok


# --------------------------------------------------- in-app review

## §17.6 review gate: only after the first all-5★ night (recorded by
## Goodnight), never before day 7, and at most once per 90 real days
## — the OS quota is stricter, but our gate keeps the mock honest.
func can_request_review() -> bool:
	var a: Dictionary = Game.ads
	if int(a.get("first_all5_day", 0)) == 0 \
			or Game.day < int(remote("review_min_day",
				REVIEW_MIN_DAY)):
		return false
	var now := int(Time.get_unix_time_from_system())
	return now - int(a.get("last_review_utc", 0)) >= REVIEW_COOLDOWN_SEC


## Mock prompt: gate + record. The plugin swaps the middle line.
func request_review() -> bool:
	if not can_request_review():
		return false
	Game.ads["last_review_utc"] = \
		int(Time.get_unix_time_from_system())
	Game.ads["reviews_shown"] = \
		int(Game.ads.get("reviews_shown", 0)) + 1
	Analytics.log_event(&"review_prompt", {"day": Game.day})
	Game.touch()
	return true


# ---------------------------------------------------- notifications

## §24.5 scheduling: quiet hours (21:00-08:00) fold any requested
## hour to 08:00 — the mock returns the landing hour; the plugin
## passes it to the OS scheduler.
func schedule_daily_reminder(hour: int) -> int:
	if hour >= QUIET_FROM or hour < QUIET_TO:
		return QUIET_TO
	return hour


## Whether a notification kind is enabled in settings (§17.4):
## "daily_reminder" and "crew" (crew_done pings) read their toggles.
func notifications_enabled(kind := "daily_reminder") -> bool:
	var key := "crew_notification" if kind == "crew" \
		else "daily_reminder"
	return bool(Game.settings.get(key, false))


## §25 notification_opt_in: the settings/sheet toggle and the first-run
## prompt both record through here — accepted or declined (§17.6).
func note_notification_opt_in(kind: String, accepted: bool) -> void:
	Analytics.log_event(&"notification_opt_in",
		{"type": kind, "accepted": accepted})


# -------------------------------------------- Play Games (v1.1)

## §17.7/§33.x adapter seam: achievements unlock keyed to content
## ids (pages, stamps, milestones); Saved Games stores the same
## save.json blob on commit. Mock stores in-memory + in Game.ads so
## saves round-trip; the GPGS plugin swaps these three functions.
var achievements: Dictionary = {}           # id -> unlock utc
var cloud_blob: String = ""                 # last uploaded save json
var cloud_pushes := 0                       # upload cadence, session-only


func unlock_achievement(id: StringName) -> bool:
	if achievements.has(id):
		return false
	achievements[id] = int(Time.get_unix_time_from_system())
	return true


## Called from Save.commit(): the plugin uploads `blob`; mock keeps
## it for round-trip tests and counts pushes for the session —
## cadence is diagnostic, not save state.
func cloud_save_push(blob: String) -> void:
	cloud_blob = blob
	cloud_pushes += 1


func cloud_save_pull() -> String:
	return cloud_blob                       # "" = no cloud save yet
