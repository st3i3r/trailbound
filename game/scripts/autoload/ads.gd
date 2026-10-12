extends Node
## Ads — UMP consent, loading, placements and pacing caps (GDD 21.1,
## 24). Mock ads on desktop; the AdMob plugin (§20) lands in Phase 0.


func request_consent() -> void:
	pass


## §24.2: interstitials at most one per 2 in-game days and ≥4 minutes
## apart, only between Sleep and Morning, from day 5.
func can_show_interstitial() -> bool:
	return false


var _rewarded_night := -1               # last in-game day the bonus ran


## §24.3: the Double-tips offer exists once per in-game day, from
## night 3 — the Night summary hides the button otherwise.
func can_double_tips(day: int) -> bool:
	return day >= 3 and _rewarded_night != day


## Desktop mock: the reward applies instantly (no AdMob here); the cap
## still records so the once-per-day rule behaves exactly like device.
func show_rewarded_night_bonus(day: int) -> void:
	_rewarded_night = day
