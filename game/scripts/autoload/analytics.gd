extends Node
## Analytics — event adapter over Firebase Analytics (GDD 21.1, 25).
## No-op on desktop and in tests; the plugin lands in the Phase 0
## spike. `sink` is the injection seam: a test or the real adapter
## installs a Callable and every event routes through it; `capture`
## additionally buffers events for order/content assertions.
##
## CATALOG is the §25 event registry — logging a name outside it
## still goes through (adapters tolerate extra events) but warns in
## debug builds so a typo'd event name can't silently miss the
## marketing/retention dashboards.

const CATALOG := {
	"app_open": true, "tutorial_step": true,
	"day_start": true, "day_end": true, "site_unlock": true,
	"page_complete": true, "letter_open": true,
	"cook": true, "catch": true, "festival": true,
	"purchase_item": true, "pad_unlock": true, "dog_adopt": true,
	"gesture": true, "photo": true, "fund_donate": true,
	"margin": true, "dog_fetch": true,
	"crew_stage_start": true, "crew_stage_collect": true,
	"daily_start": true, "daily_complete": true,
	"ad_offer_shown": true, "ad_interstitial_shown": true,
	"ad_rewarded_complete": true, "ad_revenue": true,
	"consent_status": true, "notification_opt_in": true,
	"iap_remove_ads": true, "iap_restore": true,
	"review_prompt": true, "settings_change": true,
}

var sink := Callable()             # Firebase adapter installs itself
var capture := false               # tests: record without a plugin
var events: Array = []             # [{name, params}] when capture=on


func log_event(event_name: StringName, params: Dictionary = {}) -> void:
	if not CATALOG.has(event_name) and OS.is_debug_build():
		push_warning("analytics: unregistered event '%s' — add it "
			+ "to CATALOG (§25)" % event_name)
	if capture:
		events.append({"name": String(event_name),
			"params": params.duplicate(true)})
	if sink.is_valid():
		sink.call(event_name, params)


## Test helper: drained assertions read a copy, then reset.
func captured() -> Array:
	return events.duplicate(true)


func clear_capture() -> void:
	events.clear()
