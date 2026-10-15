extends Node
## Ads — UMP consent, loading, placements and pacing caps (GDD 21.1,
## 24). Mock ads on desktop; the AdMob plugin (§20) lands in Phase 0
## and swaps the four show_* verbs — the gates and the save state stay.


## Consent resolves asynchronously on device; the mock answers next
## frame from the saved answer (first run = "not_required").
signal consent_ready(state: String)


const INTERSTITIAL_GAP_DAYS := 2     # ≤1 placement per 2 in-game days
const INTERSTITIAL_GAP_SEC := 240    # ≥4 real minutes between shows
const INTERSTITIAL_FROM_DAY := 5     # nothing before the fifth night


func request_consent() -> void:
	if String(Game.ads.get("consent", "")) == "":
		Game.ads["consent"] = "not_required"
		Game.touch()
	var state := String(Game.ads["consent"])
	Analytics.log_event(&"consent_status",
		{"status": state, "required": state != "not_required"})
	consent_ready.emit.call_deferred(state)


## §25 ad_offer_shown: the UI calls this when a rewarded/interstitial
## offer renders (button visible, not just gate-checked) so opt-in
## rates measure real exposure, not gate passes.
func offer_shown(placement: String) -> void:
	Analytics.log_event(&"ad_offer_shown",
		{"placement": placement, "day": Game.day})


## §25 ad_revenue: the plugin's impression-level paid event calls
## this on device; on desktop it's the mock's record seam — tests
## assert the event shape without Firebase.
func note_revenue(value_micros: int, currency: String,
		placement: String) -> void:
	Analytics.log_event(&"ad_revenue", {"value_micros": value_micros,
		"currency": currency, "placement": placement})


## §24.2: interstitials at most one per 2 in-game days and ≥4 minutes
## apart, only between Sleep and Morning, from day 5 — and never the
## day a rewarded view already ran (the reward IS the ad interaction).
func can_show_interstitial() -> bool:
	if Platform.is_ads_removed():
		return false
	if Game.day < int(Platform.remote("ad_interstitial_from_day",
			INTERSTITIAL_FROM_DAY)):
		return false
	var a: Dictionary = Game.ads
	if Game.day - int(a.get("last_interstitial_day", 0)) \
			< int(Platform.remote("ad_interstitial_gap_days",
				INTERSTITIAL_GAP_DAYS)):
		return false
	if int(Time.get_unix_time_from_system()) \
			- int(a.get("last_interstitial_utc", 0)) \
			< int(Platform.remote("ad_interstitial_gap_sec",
				INTERSTITIAL_GAP_SEC)):
		return false
	if Game.phase != Game.Phase.MORNING:
		return false                          # only Sleep -> Morning seam
	if int(a.get("last_rewarded_day", -1)) == Game.day:
		return false
	return true


## Mock placement: gate + record in one call — the scene seam is a
## single verb so the plugin slot-in doesn't re-plumb call sites.
func show_interstitial() -> bool:
	if not can_show_interstitial():
		return false
	var prev_utc := int(Game.ads.get("last_interstitial_utc", 0))
	var now := int(Time.get_unix_time_from_system())
	Game.ads["last_interstitial_day"] = Game.day
	Game.ads["last_interstitial_utc"] = now
	Game.touch()
	Analytics.log_event(&"ad_interstitial_shown", {"day": Game.day,
		"since_last_min": -1 if prev_utc == 0 \
			else int((now - prev_utc) / 60)})
	return true


## §24.3: the Double-tips offer exists once per in-game day, from
## night 3 — the Night summary hides the button otherwise.
func can_double_tips(day: int) -> bool:
	return day >= int(Platform.remote("ad_rewarded_from_day", 3)) \
		and int(Game.ads.get("last_rewarded_day", -1)) != day


## Desktop mock: the reward applies instantly (no AdMob here); the cap
## still records so the once-per-day rule behaves exactly like device.
func show_rewarded_night_bonus(day: int) -> void:
	offer_shown("night_double_tips")
	Game.ads["last_rewarded_day"] = day
	Game.ads["last_rewarded_utc"] = \
		int(Time.get_unix_time_from_system())
	Game.touch()
