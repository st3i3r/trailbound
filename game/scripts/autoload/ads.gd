extends Node
## Ads — UMP consent, loading, placements and pacing caps (GDD 21.1,
## 24). Mock ads on desktop; the AdMob plugin (§20) lands in Phase 0.


func request_consent() -> void:
	pass


## §24.2: interstitials at most one per 2 in-game days and ≥4 minutes
## apart, only between Sleep and Morning, from day 5.
func can_show_interstitial() -> bool:
	return false


func show_rewarded_night_bonus() -> void:
	pass
