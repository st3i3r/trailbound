extends Node
## Game — phase state machine and day/site flow (GDD 21.1).
## Boot → Title → Morning → Prep → Evening → Night, one in-game day
## at a time, player-paced. The crew clock (§8.4, D-23) also lives
## here: real-time stage progress beside the day, never feeding an
## RNG (§21.3) and never blocking the arc.

signal phase_changed(phase: Phase)
signal crew_stage_ready(structure: StringName)
signal crew_collected(structure: StringName, keepsake: StringName, finished: bool)
signal page_completed(site: StringName, page: int, gift: int, unlocks: Array)
signal letter_delivered(letter: Dictionary)
## UI seam (D2.2): the Undo button's enabled state tracks this —
## emitted whenever the day-scoped action log changes shape.
signal action_log_changed(can_undo: bool)

enum Phase { BOOT, TITLE, MORNING, PREP, EVENING, NIGHT }

# Leaf subsystems (RefCounted, scripts/systems/): state stays here
# for the save schema; behavior lives in the subsystem and public
# functions below are one-line delegates, so the API never moved.
const SysErrands := preload("res://scripts/systems/errands.gd")
const SysDog := preload("res://scripts/systems/dog.gd")
const SysDaily := preload("res://scripts/systems/daily.gd")
const SysRestore := preload("res://scripts/systems/restore.gd")
const SysGatherings := preload("res://scripts/systems/gatherings.gd")
const SysBuild := preload("res://scripts/systems/build.gd")
const SysJournal := preload("res://scripts/systems/journal.gd")
const SysCrew := preload("res://scripts/systems/crew.gd")
const SysPantry := preload("res://scripts/systems/pantry.gd")
const SysHosting := preload("res://scripts/systems/hosting.gd")
const SysNight := preload("res://scripts/systems/night.gd")

const SPEEDUP_MIN_CHUNK := 900.0   # §6.10: chunk = max(15 min, stage / 6)
const SPEEDUPS_PER_STAGE := 3
const SPEEDUPS_PER_DAY := 6
const FREE_FINISH_LEFT := 300.0    # Finish is free once ≤ 5 min remain
const SPEEDUP_FROM_DAY := 4        # offers appear from day 4 (§8.4)

var phase: Phase = Phase.BOOT
var day: int = 0
var site_id: StringName = &"pinewatch"
var sites_visited: Dictionary = {}          # site_id -> first in-game day
var letters_read: Array = []                # letter ids (§8.2 journal)
var dialogue_seen := {}                     # dialogue.json ids shown once
var vignettes_seen: Array = []              # §13.4 unseen plays first
var field_notes: Array = []                 # §7.3 logged bird ids
var dog := {"name": "Bean", "bond": 0, "met": false,
	"pet_today": false, "adopted": false}     # §9 companion
var crew: Dictionary = {}                   # §22 save shape, see _crew_reset()
var coins: int = 0                          # §6.1: one currency, starts at 0
var seed: int = 0                           # save seed feeding every stream (§21.3)
var sites: Dictionary = {}                  # site_id -> site state, see _fresh_site()
var meals: Array = []                       # cooked today; never carried over (§5.5)
var bought_today: Array = []                # refundable until Goodnight (§6.1)
var tips_doubled_day := -1                  # §24.3: in-game day the tip-double was claimed
var pantry := {}                            # ingredient id -> count (§7.4, global)
var gear: Array = []                        # owned gear ids (global, §6.7)
var recipes_cooked: Array = []              # recipe ids cooked ≥once — the book
var cook_counts := {}                       # recipe id -> times cooked (mastery)
var fund_total := 0                         # §fund: lifetime coins banked
var letters_delivered_any: Array = []       # site:"any" mail — global dedupe
var pairs_tried := {}                       # "a+b" -> recipe id | "camp_mash" | "oven_hint"
var _next_structure := 0
var _tick_accum := 0.0
var _save_dirty := false                    # verbs mark; the 1s tick flushes once
var errands: RefCounted
var dog_sys: RefCounted
var daily_sys: RefCounted
var restore: RefCounted
var gatherings: RefCounted
var build: RefCounted
var journal: RefCounted
var night_sys: RefCounted
var crew_sys: RefCounted
var pantry_sys: RefCounted
var hosting_sys: RefCounted
var passport_stamps: Array = []             # §33.5: one per scored Daily
var days_log: Array = []                    # §8.3 journal — one row/day
var personas_met := {}                      # archetype -> display name
var settings := {}                          # §17.4 — see Save.default_state
var action_log: Array = []                  # §6.1 undo spine: [{verb,params,inverse}]
var day_log: Array = []                     # §17.2 event stream: [{phase,kind,payload}]
var ads: Dictionary = {}                    # §24 pacing + entitlement (mock layer)
var _applying_inverse := false              # undo() replays without re-logging


func _ready() -> void:
	errands = SysErrands.new(self)
	dog_sys = SysDog.new(self)
	daily_sys = SysDaily.new(self)
	restore = SysRestore.new(self)
	gatherings = SysGatherings.new(self)
	build = SysBuild.new(self)
	journal = SysJournal.new(self)
	night_sys = SysNight.new(self)
	crew_sys = SysCrew.new(self)
	pantry_sys = SysPantry.new(self)
	hosting_sys = SysHosting.new(self)
	_crew_reset()
	# settings live outside the run state — read them off disk at boot
	# so prefs apply on the title screen too (UI-036). Single load:
	# the snapshot is the canonical save shape (§22).
	var saved: Dictionary = Save.load_state()
	settings = Save.default_state()["settings"]
	for k in saved.get("settings", {}):
		settings[k] = saved["settings"][k]
	ads = Save.default_state()["ads"]
	ads.merge(saved.get("ads", {}), true)
	apply_settings()
	Analytics.log_event(&"app_open", {"kind": "cold",
		"via": Platform.launch_source()})        # §25


# ------------------------------------------------------------- settings (§17.4)

const _BUS := {"music": "Music", "ambience": "Ambience", "sfx": "SFX"}


## One setter for the whole sheet: store, apply the live consumers,
## persist.  Settings persist the FULL state — the snapshot is the
## canonical save shape (§22) and a settings change is a save-worthy
## moment on mobile (user may background right after).
func setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	Analytics.log_event(&"settings_change", {"key": key})
	if key in ["daily_reminder", "crew_notification"]:
		Platform.note_notification_opt_in(
			"crew" if key == "crew_notification" else "daily_reminder",
			bool(value))
	Save.save_state(state_dict())


func apply_settings() -> void:
	UIFeel.reduced_motion = bool(settings["reduced_motion"])
	UIFeel.reduced_flashing = bool(settings["reduced_flashing"])
	UIFeel.haptics_enabled = bool(settings["haptics"])
	UIKit.text_scale = 1 if settings["text_size"] == "large" else 0
	UIKit.left_handed = bool(settings["left_handed"])
	TranslationServer.set_locale(String(settings["language"]))
	_apply_audio()


## Buses are created lazily so the mixer exists before the audio
## pass — a setting writes real volume_db today, and stems routed to
## the named bus pick it up with zero rewiring later.
func _apply_audio() -> void:
	for key in _BUS:
		var bname: String = _BUS[key]
		if AudioServer.get_bus_index(bname) < 0:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bname)
			AudioServer.set_bus_send(idx, &"Master")
		var bus := AudioServer.get_bus_index(bname)
		var step: int = clampi(int(settings.get(key, 3)), 0, 3)
		AudioServer.set_bus_mute(bus, step == 0)
		AudioServer.set_bus_volume_db(bus,
			linear_to_db(step / 3.0) if step > 0 else 0.0)


## crew.json structures in site order; read lazily so autoload order
## (Game before Catalog) can't matter.
func _structures() -> Array:
	return Catalog.data.get("crew", {}).get("structures", [])


func _process(delta: float) -> void:
	_tick_accum += delta
	if _tick_accum >= 1.0:
		_tick_accum = 0.0
		crew_tick()
		restore.tick()                           # §6.11 site teams
		if _save_dirty:
			commit()                             # coalesced verb writes (≤1/s)


## Focus modality: keys/joypad arm nav so panel opens grab a control
## and focus rings (sel_glow) mean "you can steer this"; pointer input
## disarms — taps never leave a ring behind (pressable() releases
## focus on each pointer press anyway).
func _input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed) \
			or (event is InputEventJoypadButton and event.pressed) \
			or (event is InputEventJoypadMotion \
				and absf(event.axis_value) > 0.4):
		UIFeel.nav_input = true
	elif (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		UIFeel.nav_input = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		crew_tick()                          # catch up after backgrounding
		Analytics.log_event(&"app_open", {"kind": "warm",
			"via": Platform.launch_source()})
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		commit()                             # Android may reclaim us backgrounded


## Commit-on-beat persistence: sleep is never a checkpoint — a player
## who never presses Goodnight still keeps everything (D-UI-8).  Chatty
## verbs call touch() and the 1s tick coalesces a burst into one write;
## day boundaries, focus-loss and quit paths call commit() — immediate,
## for the moments the player treats as "done".  Payload is <100KB and
## tmp+rename-atomic, so the split is about flash writes, not safety.
func touch() -> void:
	_save_dirty = true


func commit() -> void:
	Save.save_state(state_dict())
	_save_dirty = false
	Platform.cloud_save_push(Save.last_json())


## §23 budget read: ms since engine start at call time — the --bench
## flag calls this once the title screen has presented, so the number
## covers autoloads + first scene, not a warm scene-switch.
func boot_ms() -> int:
	return Time.get_ticks_msec()


# --------------------------------------------------- day spines (D2.2/D2.4)
#
# Two append-only, day-scoped streams, both serialized so a mid-day
# reload keeps them:
#   action_log — undoable verbs with pre-baked inverses (§6.1's
#     "nothing is final until Goodnight" made structural). undo()
#     reverses the newest entry whose inverse still applies.
#   day_log — one ordered {phase, kind, payload} event stream; the
#     night summary, analytics and Then/Now all read it instead of
#     re-deriving the day from scattered counters.

func _log(kind: String, payload: Dictionary = {}) -> void:
	day_log.append({"phase": int(phase), "kind": kind,
		"payload": payload})
	if day_log.size() > 240:                     # paranoia cap
		day_log.pop_front()


func _record(verb: String, params: Dictionary,
		inverse: Variant = null) -> void:
	if _applying_inverse:
		return
	action_log.append({"verb": verb, "params": params,
		"inverse": inverse})
	_refresh_bought()
	action_log_changed.emit(can_undo())


## §6.1 refund eligibility derives from the action log — buys append,
## returns consume the newest matching entry, and undo() popping a
## return makes the buy refundable again for free. `bought_today` is
## a read cache of this; nothing else may write it.
func _refresh_bought() -> void:
	var out := []
	for e in action_log:
		var p: Dictionary = e.get("params", {})
		match String(e["verb"]):
			"buy_decor":
				out.append(String(p.get("item_id", "")))
			"return_decor", "return_bought":
				var iid := String(p.get("item_id",
					p.get("expect", "")))
				var i := out.rfind(iid)
				if i >= 0:
					out.remove_at(i)
	bought_today = out


func can_undo() -> bool:
	for i in range(action_log.size() - 1, -1, -1):
		if action_log[i].get("inverse") != null:
			return true
	return false


## §6.1 undo: pops the newest entry whose inverse still applies —
## terminal entries (cook, gather, a cleared pad's spent unlock)
## are dropped, so one irreversible act can't wedge the log.
func undo() -> bool:
	var done := false
	while not action_log.is_empty():
		var e: Dictionary = action_log.pop_back()
		var inv: Variant = e.get("inverse")
		if inv == null:
			continue
		_applying_inverse = true
		var ok := _dispatch(String(inv["verb"]),
			Dictionary(inv["params"]))
		_applying_inverse = false
		if ok:
			_log("undo", {"verb": e["verb"]})
			touch()
			done = true
			break
	_refresh_bought()
	action_log_changed.emit(can_undo())
	return done


func _dispatch(verb: String, p: Dictionary) -> bool:
	match verb:
		"return_bought": return return_bought(String(p["item_id"]))
		"move_decor": return _move_checked(
			int(p["idx"]), p["cells"], String(p.get("expect", "")))
		"place_stored": return place_stored(String(p["item_id"]),
			p["cells"])
		"store_last": return _store_last(String(p["expect"]))
		"seat": return seat(String(p["guest_id"]), p["pad_ids"])
		"unseat":
			unseat(String(p["guest_id"]))
			return true
		"serve_meal": return serve_meal(String(p["guest_id"]),
			String(p["meal_id"]))
		"unserve":
			unserve(String(p["guest_id"]))
			return true
		"unlock_refund": return _unlock_refund(String(p["pad_id"]),
			int(p["price"]))
		"unclear_pad": return _unclear_pad(String(p["pad_id"]))
		"downgrade_pad": return _downgrade_pad(String(p["pad_id"]),
			int(p["price"]))
		"refund_gear": return _refund_gear(String(p["item_id"]),
			int(p["price"]))
		"refund_staple": return _refund_staple(String(p["item_id"]),
			int(p["price"]))
		"rebuy": return _rebuy(String(p["item_id"]), p["cells"],
			int(p["price"]))
		"rebuy_stored": return _rebuy_stored(String(p["item_id"]),
			int(p["price"]))
		"rebuy_pit": return _rebuy_pit(int(p["price"]))
		"cancel_music_night": return _cancel_music_night(
			int(p["price"]))
		"unstoke":
			site_state()["fire_stoked"] = false
			return true
		"untuck":
			site_state()["tucked_in"] = ""
			return true
		"unbuy_variant":
			var st_v: Dictionary = site_state()
			if int(p["idx"]) < st_v["decor"].size():
				var dd: Dictionary = st_v["decor"][int(p["idx"])]
				if String(p["prev"]) == "":
					dd.erase("variant")
				else:
					dd["variant"] = String(p["prev"])
				coins += int(p["price"])
			return true
	return false


## Inverse helpers — the half of §6.1 no public verb needs.
## Index-addressed inverses verify the item id first: a later
## removal shifts decor indices, and undoing into the wrong piece
## is worse than skipping.  Bodies live in systems/build.gd beside
## their forward verbs; _dispatch addresses them by name here.
func _move_checked(idx: int, cells: Array, expect: String) -> bool:
	return build._move_checked(idx, cells, expect)


func _store_last(item_id: String) -> bool:
	return build._store_last(item_id)


func _unlock_refund(pad_id: String, price: int) -> bool:
	return build._unlock_refund(pad_id, price)


func _unclear_pad(pad_id: String) -> bool:
	return build._unclear_pad(pad_id)


func _downgrade_pad(pad_id: String, price: int) -> bool:
	return build._downgrade_pad(pad_id, price)


func _refund_gear(item_id: String, price: int) -> bool:
	return build._refund_gear(item_id, price)


func _refund_staple(item_id: String, price: int) -> bool:
	return build._refund_staple(item_id, price)


func _rebuy(item_id: String, cells: Array, price: int) -> bool:
	return build._rebuy(item_id, cells, price)


func _rebuy_stored(item_id: String, price: int) -> bool:
	return build._rebuy_stored(item_id, price)


func _rebuy_pit(price: int) -> bool:
	return build._rebuy_pit(price)


# --------------------------------------------------- authored cues (spec 005)
## Light cues mediate between UI layers and the scene's WorldFX: a
## sheet says WHAT cue is active (a letter is open, a ceremony plays,
## tonight's vignette shows), the scene applies it via track_emit /
## untrack_emit.  Single-slot — a new cue replaces the old; clear
## releases only its own id so an early layer can't yank a later one.
## NB: distinct from the schedule-op `emit` (percept cues) — these are
## *light* terms in the grade's Σ emit×w sum.
signal light_cue_changed(cue)
var _light_cue := {}                       # {"id","col","w"} | {}


func set_light_cue(id: String, col: Color, w: StringName) -> void:
	_light_cue = {"id": id, "col": col, "w": w}
	light_cue_changed.emit(_light_cue)


func clear_light_cue(id: String) -> void:
	if _light_cue.get("id") == id:
		_light_cue = {}
		light_cue_changed.emit(_light_cue)


func set_phase(next: Phase) -> void:
	if next == phase:
		return
	phase = next
	phase_changed.emit(phase)


func advance_day() -> void:
	var st := site_state()
	if not st["assignments"].is_empty() or not meals.is_empty():
		return                          # unsettled evening work — Goodnight first
	day += 1
	visit_site(site_id)
	if day == 2:
		crew_start(&"wardens_hut")           # §8.4: Mai's van on day 2
	new_day()
	set_phase(Phase.MORNING)
	Analytics.log_event(&"day_start", {"day": day,
		"site": String(site_id)})
	commit()                                   # the rolled morning is state


func visit_site(site: StringName) -> void:
	hosting_sys.visit_site(site)


## §8.2: the morning trail map. Gated by chapter completion; re-rolls
## the day at the chosen site so the board/weather are the new site's.
func travel_to(site: StringName) -> bool:
	return hosting_sys.travel_to(site)


## §Wishes: the kinds tonight's camp can actually grant — the board never
## deals a wish the seating can't satisfy. Tags on open pads (with
## restoration grants already overlaid by _world), fire-ring and
## light coverage from effects_at, open sky on unsheltered pads, and
## `together` only while a free adjacent pair exists.
func _wish_kinds(st: Dictionary) -> Array:
	var world := _world()
	var spots: Dictionary = world["layout"]["pads"].get("spots", {})
	var tags: Dictionary = world["layout"]["pads"].get("tags", {})
	var nbrs: Dictionary = world["layout"]["pads"].get("neighbours", {})
	var open := _open_pads(st)
	var out := {}
	for pid in open:
		for t in tags.get(pid, []):
			out[t] = true
		var c: Array = spots.get(pid, [])
		if c.size() >= 2:
			var eff := Seating.effects_at(
				Vector2i(int(c[0]), int(c[1])), world)
			if eff.has("warmth"):
				out["fire"] = true
			if eff.has("light"):
				out["lit"] = true
			var shelter := String(
				st["pads"].get(pid, {}).get("shelter", "bare"))
			if shelter != "cabin" and not eff.has("cover"):
				out["sky"] = true
	for a in open:
		for b in nbrs.get(a, []):
			if b in open:
				out["together"] = true
	return out.keys()


## §12.3: regulars book about every third day at their site until
## their story ends (visit count reaching story_visits). They take a
## normal request slot; an elite card is never displaced. Regulars
## carry authored wishes (Old Ba always wants the water).
func _inject_regulars(st: Dictionary) -> void:
	var d := site_day()
	for reg: Dictionary in Catalog.data.get("regulars", []):
		if reg.get("site") != site_id:
			continue
		var rid: String = reg["id"]
		var visits: int = st["counters"]["regular_visits"].get(rid, 0)
		if visits >= int(reg.get("story_visits", 3)):
			continue                                   # story told
		var due := false
		if reg.get("weekend_only", false):
			# the Minh family: weekend visitors, and only once a
			# neighbouring pair can take them (§5.2 family rule)
			due = d % 7 in [6, 0] and _has_free_pair(st)
		else:
			var off := int(reg.get("offset", 3))
			due = d >= off and (d - off) % int(reg.get("every", 3)) == 0
		if not due:
			continue
		var req := {"id": "reg_" + rid,
			"archetype": reg["archetype"], "name": reg["name"],			"card_name": reg.get("card_name", ""),
			"traits": reg.get("traits", []).duplicate(),
			"loud": reg.get("loud", false),
			"pads": int(reg.get("pads", 1)),
			"fee": int(reg["fee"]), "regular": rid,
			"favourite": reg.get("favourite", "")}
		if String(reg.get("wish", "")) != "":
			req["wish"] = reg["wish"]
		var slotted := false
		# Front-scan: the last two cards may carry the day-6+
		# conflict pair (§5.2) — displacing them breaks the board.
		for i in st["board"].size():
			var card: Dictionary = st["board"][i]
			if not card.get("elite") and card.get("regular", "") == "":
				st["board"][i] = req
				slotted = true
				break
		if not slotted:
			st["board"].append(req)


# ------------------------------------------------------------- letters (§8.2/§13)
#
# Letters arrive in order, at most one per morning; event-triggered
# letters go first and unread ones wait in the journal.  Bodies live
# in systems/journal.gd — these stay the public surface.

func _letters_for(site := site_id) -> Array:
	return journal._letters_for(site)


func _letter_due(l: Dictionary, st: Dictionary) -> bool:
	return journal._letter_due(l, st)


func _deliver_letter(st: Dictionary) -> void:
	journal._deliver_letter(st)


func unread_letters(site := site_id) -> Array:
	return journal.unread_letters(site)


func read_letter(id: String) -> void:
	journal.read_letter(id)


func letters_for(site := site_id) -> Array:
	return journal.letters_for(site)


func letter(id: String, site := site_id) -> Dictionary:
	return journal.letter(id, site)


func dialogue_when_ok(when: Dictionary) -> bool:
	return journal.dialogue_when_ok(when)


# ------------------------------------------------------- journal UI (§8.3)

const JOURNAL_SITES := SysJournal.JOURNAL_SITES

func chapter_pages(site := site_id) -> Array:
	return journal.chapter_pages(site)


func keepsake(id: String) -> Dictionary:
	return journal.keepsake(id)


func journal_completion() -> Dictionary:
	return journal.journal_completion()


func field_notes_catalog() -> Dictionary:
	return journal.field_notes_catalog()


func _note_row(row: Dictionary) -> Dictionary:
	return journal._note_row(row)


func _field_note_rows() -> Array:
	return journal._field_note_rows()


func _note_find(id: String) -> void:
	journal._note_find(id)


func site_name(id: StringName) -> String:
	return journal.site_name(id)



# ------------------------------------------------------------- crew (§8.4)
# Bodies live in systems/crew.gd — these stay the public surface the
# UI and tests already call. `crew` + `_next_structure` stay here for
# the save schema (D-ARCH-2).

func _crew_reset() -> void:
	crew_sys.reset()


func _structure(id: StringName) -> Dictionary:
	return crew_sys._structure(id)


func _current_stage() -> Dictionary:
	return crew_sys._current_stage()


func _today() -> String:
	return crew_sys._today()


## §8.4 clock: progress = max(0, now − last seen), so a clock set back
## never undoes work (forward finishing early is accepted, §32). Runs
## while the app is closed via the same call on load.
func crew_tick(now := int(Time.get_unix_time_from_system())) -> void:
	crew_sys.tick(now)


func crew_start(structure: StringName) -> void:
	crew_sys.start(structure)


## Next structure starts itself once its site is reached and the crew
## is free (§8.4). The hut is day-2-gated instead (advance_day).
func _try_start_next() -> void:
	crew_sys.try_start_next()


## Collect a finished stage: keepsake to the journal, next stage (or
## structure) starts by itself (§8.4). Returns {} when not ready.
func crew_collect() -> Dictionary:
	return crew_sys.collect()


## Rewarded-ad speed-up (§6.10): one chunk off the stage, capped per
## stage and per calendar day, offered from day 4 (§8.4).
func crew_speedup() -> float:
	return crew_sys.speedup()


func crew_can_speedup() -> bool:
	return crew_sys.can_speedup()


## Finish is free once 5 minutes or less remain (§6.10).
func crew_free_finish() -> bool:
	return crew_sys.free_finish()

# ------------------------------------------------- Volume II (§33.3)
#
# Restorations (§6.11), Gatherings and the Trail Passport (§33.5).
# Live in systems/restore.gd + systems/gatherings.gd; state stays in
# site_state()/passport_stamps for the save schema.

func restore_status(site := site_id) -> Dictionary:
	return restore.status(site)


func restore_can_start(sid: StringName) -> bool:
	return restore.can_start(sid)


func restore_start(sid: StringName) -> bool:
	if restore.start(sid):
		touch()
		return true
	return false


func restore_collect(site := site_id) -> Dictionary:
	var rep: Dictionary = restore.collect(site)
	if not rep.is_empty():
		touch()
	return rep


func restore_can_speedup(site := site_id) -> bool:
	return restore.can_speedup(site)


func restore_speedup(site := site_id) -> float:
	var chunk: float = restore.speedup(site)
	if chunk > 0.0:
		touch()
	return chunk


func restore_free_finish(site := site_id) -> bool:
	if restore.free_finish(site):
		touch()
		return true
	return false


func restored(sid: StringName, site := site_id) -> bool:
	return restore.restored(site, sid)


## Evening preview: the offered Gathering's brief, checked live.
func gathering_status() -> Dictionary:
	return gatherings.status(site_state())


## §33.5 Trail Passport: a stamp per completed Daily; every 7 unlock
## a cosmetic. Never resets — a missed day costs nothing.
func passport_cosmetics() -> int:
	return int(passport_stamps.size() / 7)


func is_stage_ready() -> bool:
	return crew_sys.is_stage_ready()


## All three v1 structures fully collected. Vol II restorations are
## site-team work, not the v1 crew's list (§6.11).
func crew_done() -> bool:
	return crew_sys.done()


# ------------------------------------------------------------- hosting (§5)
#
# Per-site state lives in `sites[site_id]` and round-trips through the
# save's "sites" key (§22). The transient half — board, assignments,
# weather — is rebuilt every new_day; the persistent half — open pads,
# shelters, decor, seats, reviews — survives.

func site_day(site := site_id) -> int:
	return hosting_sys.site_day(site)


func site_row(site := site_id) -> Dictionary:
	return hosting_sys.site_row(site)
func site_card(site: StringName) -> Dictionary:
	return hosting_sys.site_card(site)
func site_order() -> Array:	return hosting_sys.site_order()

func _row(list_name: String, item_id: String) -> Dictionary:
	for item in Catalog.data.get(list_name, []):
		if item.get("id") == item_id:
			return item
	return {}


func site_state(site := site_id) -> Dictionary:
	return hosting_sys.site_state(site)


func _fresh_site(site: StringName) -> Dictionary:
	return hosting_sys._fresh_site(site)


func _rng_for(stream: String, site := site_id) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d|%s|%d|%s" % [seed, site, site_day(site),
		stream]).hash()
	return rng


func _open_pads(st: Dictionary) -> Array:
	var out := []
	for pid in st["pads"]:
		if st["pads"][pid]["open"]:
			out.append(pid)
	return out


## A neighbouring pair of open, unseated pads — the family gate (§5.2).
func _has_free_pair(st: Dictionary) -> bool:
	var nbs: Dictionary = Catalog.data.get("layouts", {}).get(
		site_id, {}).get("pads", {}).get("neighbours", {})
	var taken := {}
	for pad_ids in st["assignments"].values():
		for pid in pad_ids:
			taken[pid] = true
	for pid in st["pads"]:
		if not st["pads"][pid]["open"] or taken.has(pid):
			continue
		for nb in nbs.get(pid, []):
			if st["pads"].get(nb, {}).get("open", false) \
					and not taken.has(nb):
				return true
	return false


func rating(site := site_id) -> float:
	return Econ.rating(site_state(site)["reviews"])


## Recipe mastery: 5 cooks = Practiced, 15 = Signature — served plates
## tip +6/+15 at Goodnight. cook_plan surfaces the tier per craving.
func cook_tier(recipe_id: String) -> int:
	var n := int(cook_counts.get(recipe_id, 0))
	return 2 if n >= 15 else (1 if n >= 5 else 0)


## §Grandpa's Fund — the post-arc prestige sink (SOTA: sinks, never
## taxes, in a cozy economy). Coins banked forever; each tier emits a
## journal event, drops a grant decor into stored, and brings a letter
## from the wandering mailbag. Data: data/fund.json tiers.
func fund_status() -> Dictionary:
	var tiers: Array = Catalog.data.get("fund", {}).get("tiers", [])
	var next := {}
	for t in tiers:
		if fund_total < int(t["coins"]):
			next = t
			break
	return {"total": fund_total, "next": next, "tiers": tiers.size()}


func donate_fund(amount: int) -> Dictionary:
	if amount < 25 or coins < amount:
		return {}
	coins -= amount
	fund_total += amount
	var unlocked := []
	var st := site_state()
	for t in Catalog.data.get("fund", {}).get("tiers", []):
		var ev := String(t.get("event", ""))
		if fund_total < int(t["coins"]) or ev == "" \
				or st["counters"]["events"].has(ev):
			continue
		journal_event(ev)
		var grant := String(t.get("grant", ""))
		if grant != "":
			var row: Dictionary = _row("decor", grant)
			st["stored"].append({"id": grant,
				"effect": row.get("effect", ""),
				"reach": int(row.get("reach", 0))})
			unlocked.append(grant)
		unlocked.append(ev)
	_log("fund", {"amount": amount, "total": fund_total,
		"unlocked": unlocked})
	Analytics.log_event(&"fund_donate",
		{"amount": amount, "total": fund_total})
	touch()
	return {"total": fund_total, "unlocked": unlocked}


## §10/§17.3 trailhead queue: tonight's board minus the seated —
## the evening cast waits them at the trailhead and the board sheet
## reads them as "still looking for a spot".
func queue_waiting() -> Array:
	var st := site_state()
	return st["board"].filter(
		func(r): return not st["assignments"].has(r["id"]))


## §17.4 assist-mode read: tonight's cravings vs the stove —
## {craved: {recipe: n}, cooked: {recipe: n}, missing: [recipe]}.
## Pure read; the board never auto-plans.
func cook_plan() -> Dictionary:
	var st := site_state()
	var craved := {}
	var cooked := {}
	for r in st["board"]:
		var f := String(r.get("favourite", ""))
		if f != "":
			craved[f] = int(craved.get(f, 0)) + 1
	for m in meals:
		cooked[String(m["id"])] = int(cooked.get(m["id"], 0)) + 1
	var missing := []
	var mastery := {}
	for rid in craved:
		if int(cooked.get(rid, 0)) < int(craved[rid]):
			missing.append(rid)
		var tier := cook_tier(String(rid))
		if tier > 0:
			mastery[rid] = tier
	return {"craved": craved, "cooked": cooked, "missing": missing,
		"mastery": mastery}


## Morning: forecast + booking board, both deterministic per §5.2/§5.7.
## Errand tables (forage nodes, catches) seed off the same morning.
func new_day() -> void:
	var st := site_state()
	st["weather"] = _roll_weather()
	# §streaks: weather keeps count — three of a kind is a season,
	# and the camp says so (letters/dialogue hook the journal event)
	var ws: Dictionary = st["weather_streak"]
	if ws.get("kind") == st["weather"]:
		ws["days"] = int(ws.get("days", 0)) + 1
	else:
		st["weather_streak"] = {"kind": st["weather"], "days": 1}
		ws = st["weather_streak"]
	if int(ws["days"]) == 3:
		journal_event({"rain": "soggy_camp", "clear": "heat_wave",
			"storm": "wild_storm"}.get(st["weather"], "wet_streak"))
	st["assignments"] = {}
	st["served"] = {}
	st["guests"] = {}
	st["fish_taken"] = {}
	st["music_night"] = false
	st["fire_stoked"] = false
	st["tucked_in"] = ""
	bought_today = []
	action_log = []
	day_log = []
	action_log_changed.emit(false)             # new day, clean slate
	# §13.5: fixed arc dates land festival nights; the flag is day
	# state so the board, the kitchen and the vignette all see it.
	st["event"] = _festival_today()
	if st["event"] != "":
		_log("festival", {"id": st["event"]})
		Analytics.log_event(&"festival", {"id": st["event"],
			"site": String(site_id), "day": site_day()})
	# No-pressure rule: ungathered nodes persist — the forest keeps
	# offering; only a cap trims the oldest (wildlife fiction).
	st["forage_nodes"] = st.get("forage_nodes", []) \
		+ errands.roll_forage()
	if st["forage_nodes"].size() > 12:
		st["forage_nodes"] = st["forage_nodes"].slice(-12)
	dog_sys.morning()                              # §9: pet reset + dig
	if site_id == &"pinewatch" and site_day() == 1:
		journal_event("fire_lit")                # §8.1 P1: day-1 tutorial
	var srow := _attract_row(
		restore.site_row(site_row(), site_id), st)
	st["board"] = Seating.board(srow,
		Catalog.data.get("archetypes", []), site_day(), _open_pads(st),
		rating(), _rng_for("board"), _has_free_pair(st),
		_favourite_pool(), _wish_kinds(st))
	_inject_regulars(st)
	gatherings.maybe_offer(st)                     # §33.3 Vol II board
	# familiar faces (§memory): a guest whose archetype already stayed
	# twice at this site reads as a returner — badged on the card,
	# tipped a little extra at resolve
	var av: Dictionary = st["counters"]["arch_visits"]
	var wish_labels := {}
	for w in Catalog.data.get("wishes", []):
		wish_labels[String(w["id"])] = String(w.get("label", ""))
	for r in st["board"]:
		if String(r.get("regular", "")) == "" \
				and int(av.get(r.get("archetype", ""), 0)) >= 2:
			r["returning"] = true
		var wk := String(r.get("wish", ""))
		if wk != "":
			r["wish_label"] = String(wish_labels.get(wk, wk))
	if st["board"].any(func(b): return b.get("archetype") == "family") 			or int(st["counters"]["families"]) > 0:
		st["counters"]["events"]["family_booked"] = true
	_deliver_letter(st)
	for r in st["board"]:
		st["guests"][r["id"]] = r

func _roll_weather() -> String:
	return _weather_at(site_day())


## §13.5 festivals: data/festivals.json pins a festival to one
## (site, site_day). Fixed arc dates — never rolled, so forecast
## and replays agree, and the day reads as authored not random.
func _festival_today(site := site_id) -> String:
	for f in Catalog.data.get("festivals", []):
		if f.get("site") == site \
				and int(f.get("site_day", -1)) == site_day(site):
			return String(f["id"])
	return ""


## Today's festival row or {} — the board card and vignette read
## name/line off it; the kitchen reads `dish`.
func festival(site := site_id) -> Dictionary:
	var id: String = site_state(site).get("event", "")
	if id == "":
		return {}
	for f in Catalog.data.get("festivals", []):
		if f.get("id") == id:
			return f
	return {}


## spec 004 C — decor→demand (Neko Atsume / lot-traits form): every
## placed piece adds its `attract` tag as bonus weight into tonight's
## board tables — trait tags into trait_pool, archetype tags into
## archetype_mix. Per-item semantic, never more offers, and capped
## at half each base table so site identity and weather stay louder.
## Stored pieces don't pull (they're packed away); the upgraded
## campfire counts as its decor row (the big fire is a draw).
const ATTRACT_TRAIT_W := 2
const ATTRACT_ARCH_W := 10
const ATTRACT_CAP := 0.5

func _attract_row(srow: Dictionary, st: Dictionary) -> Dictionary:
	var tbonus := {}
	var pbonus := {}
	for d in st["decor"]:
		var a: Dictionary = _row("decor", d["id"]).get("attract", {})
		if a.has("trait"):
			var t := String(a["trait"])
			pbonus[t] = int(pbonus.get(t, 0)) + ATTRACT_TRAIT_W
		if a.has("archetype"):
			var k := String(a["archetype"])
			tbonus[k] = int(tbonus.get(k, 0)) + ATTRACT_ARCH_W
	if int(st.get("campfire", {}).get("radius", 0)) >= 3:
		var ca: Dictionary = _row("decor", "stone_fire_pit") \
			.get("attract", {})
		if ca.has("trait"):
			var t := String(ca["trait"])
			pbonus[t] = int(pbonus.get(t, 0)) + ATTRACT_TRAIT_W
	var out := srow.duplicate()
	_merge_attract(out, "archetype_mix", tbonus)
	_merge_attract(out, "trait_pool", pbonus)
	# §13.5: a festival night leans the board toward its themed
	# guests — same attract machinery, bigger weight budget.
	var ev := festival()
	if not ev.is_empty():
		_merge_attract(out, "archetype_mix",
			ev.get("archetype_boost", {}))
	return out


## Adds bonus weights into a copy of tbl[key], capped at ATTRACT_CAP
## of the base table's total weight; absent tags enter the table so
## a telescope at pinewatch really does bring stargazers.
func _merge_attract(out: Dictionary, key: String,
		bonus: Dictionary) -> void:
	if bonus.is_empty():
		return
	var tbl: Dictionary = out.get(key, {})
	var merged := tbl.duplicate()
	var base := 0
	for v in tbl.values():
		base += int(v)
	var bsum := 0
	for v in bonus.values():
		bsum += int(v)
	var f := minf(1.0, float(base) * ATTRACT_CAP / bsum)
	for k in bonus:
		merged[k] = int(merged.get(k, 0)) \
			+ maxi(1, int(round(float(bonus[k]) * f)))
	out[key] = merged


## The seeded roll for a given site day — shared by _roll_weather and
## forecast so a peeked forecast can never drift from the real roll.
func _weather_at(sday: int) -> String:
	if sday <= 1:                                    # §5.7: never on day 1
		return "clear"
	if site_id == &"pinewatch" and sday == 4:        # §14 scripted rain
		return "rain"
	var chance := float(site_row().get("rain_chance", 0.2))
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d|%s|%d|%s" % [seed, site_id, sday,
		"weather"]).hash()
	var w := "rain" if rng.randf() < chance else "clear"
	# Storm rides the same seeded roll's second draw — rain results
	# stay bit-identical to pre-storm saves, and a storm overrides
	# rain rather than adding a parallel event.
	if rng.randf() < float(site_row().get("storm_chance", 0.0)):
		w = "storm"
	return w


## §17.2 night summary: tomorrow's weather — the same deterministic
## roll new_day() will make, peeked one site day ahead.  Pure read,
## no state consumed (the seeded RNG is rebuilt per call).
func forecast() -> String:
	return _weather_at(site_day() + 1)


## Seating input for the pure-math layer (§5).
func _world() -> Dictionary:
	var st := site_state()
	var occ := {}
	for gid in st["assignments"]:
		for pid in st["assignments"][gid]:
			occ[pid] = gid
	var kinds := _trait_kinds()
	# §6.11 restorations can add pad tags (Fire Tower view, Pond Dock
	# water); overlay them on a private layout copy, never the shared
	# Catalog row.
	var layout: Dictionary = Catalog.data.get("layouts", {}).get(
		site_id, {})
	if not st["pad_tags"].is_empty():
		layout = layout.duplicate(true)
		var pad_tags: Dictionary = layout["pads"].get_or_add("tags", {})
		for pid in st["pad_tags"]:
			var tags: Array = pad_tags.get(pid, [])
			for t in st["pad_tags"][pid]:
				if t not in tags:
					tags.append(t)
			pad_tags[pid] = tags
	return {"layout": layout,
		"campfire": st["campfire"], "decor": st["decor"],
		"pads": st["pads"], "occupants": occ,
		"guests": st["guests"], "weather": st["weather"],
		"music_night": st.get("music_night", false),
		"trait_kinds": kinds,
		"comments": Catalog.data.get("reviews", {}),
		"day": site_day()}


func preview(guest_id: String, pad_ids: Array) -> Dictionary:
	var st := site_state()
	var guest: Dictionary = st["guests"].get(guest_id, {})
	if guest.is_empty():
		return {}
	return Seating.resolve_guest(guest, pad_ids, _world())


func can_seat(guest_id: String, pad_ids: Array) -> bool:
	var st := site_state()
	if not st["guests"].has(guest_id) or pad_ids.is_empty():
		return false
	var occupied := {}
	for gid in st["assignments"]:
		for pid in st["assignments"][gid]:
			occupied[pid] = gid
	for pid in pad_ids:
		if not st["pads"].get(pid, {}).get("open", false) \
				or occupied.has(pid):
			return false
	return true


func seat(guest_id: String, pad_ids: Array) -> bool:
	if not can_seat(guest_id, pad_ids):
		return false
	site_state()["assignments"][guest_id] = pad_ids
	_record("seat", {"guest_id": guest_id, "pad_ids": pad_ids},
		{"verb": "unseat", "params": {"guest_id": guest_id}})
	_log("seat", {"guest": guest_id, "pads": pad_ids})
	touch()
	return true


func unseat(guest_id: String) -> void:
	var st := site_state()
	if st.get("tucked_in", "") == guest_id:
		st["tucked_in"] = ""
	if not st["assignments"].has(guest_id):
		return
	var pads: Array = st["assignments"][guest_id]
	st["assignments"].erase(guest_id)
	st["served"].erase(guest_id)   # the plate goes back too
	_record("unseat", {"guest_id": guest_id},
		{"verb": "seat",
			"params": {"guest_id": guest_id, "pad_ids": pads}})
	_log("unseat", {"guest": guest_id})
	touch()


## §5.5 dinner: reserve a cooked meal for a seated guest — the plate
## only lands if the meal exists and isn't already spoken for (dupes
## count individually).  Serve the same id again to take it back via
## unserve.  Assignments are evening-only, so serving can't fire out
## of phase.
func serve_meal(guest_id: String, meal_id: String) -> bool:
	var st := site_state()
	if not st["assignments"].has(guest_id):
		return false
	var cooked := 0
	for m in meals:
		if String(m["id"]) == meal_id:
			cooked += 1
	var used := 0
	for gid in st["served"]:
		if String(st["served"][gid]) == meal_id and gid != guest_id:
			used += 1
	if used >= cooked:
		return false
	st["served"][guest_id] = meal_id
	_record("serve_meal", {"guest_id": guest_id, "meal_id": meal_id},
		{"verb": "unserve", "params": {"guest_id": guest_id}})
	touch()
	return true


func unserve(guest_id: String) -> void:
	var st := site_state()
	var mid: Variant = st["served"].get(guest_id)
	if st["served"].erase(guest_id):
		_record("unserve", {"guest_id": guest_id},
			{"verb": "serve_meal", "params": {"guest_id": guest_id,
				"meal_id": String(mid)}})
		touch()


## §Care gestures — two optional once-a-night verbs, bounded so their
## absence never reads as a loss. Stoke bumps tonight's tips a little
## (a warm camp loosens wallets); tuck-in raises one seated guest's
## stars. Both undoable until Goodnight like every evening verb.
func can_stoke_fire() -> bool:
	return phase == Phase.EVENING \
		and not bool(site_state().get("fire_stoked", false))


func stoke_fire() -> bool:
	if not can_stoke_fire():
		return false
	site_state()["fire_stoked"] = true
	_record("stoke_fire", {}, {"verb": "unstoke", "params": {}})
	_log("gesture", {"kind": "stoke_fire"})
	Analytics.log_event(&"gesture", {"kind": "stoke_fire"})
	touch()
	return true


func can_tuck_in(guest_id: String) -> bool:
	return phase == Phase.EVENING \
		and site_state()["assignments"].has(guest_id) \
		and String(site_state().get("tucked_in", "")) == ""


func tuck_in(guest_id: String) -> bool:
	if not can_tuck_in(guest_id):
		return false
	site_state()["tucked_in"] = guest_id
	_record("tuck_in", {"guest_id": guest_id},
		{"verb": "untuck", "params": {}})
	_log("gesture", {"kind": "tuck_in", "guest": guest_id})
	Analytics.log_event(&"gesture", {"kind": "tuck_in"})
	touch()
	return true


## Goodnight (§5.4–5.6): resolve every seated party, take fees + tips,
## file reviews, sell leftover meals to walk-ins, end the day.
func goodnight() -> Dictionary:
	return night_sys.goodnight()

func double_tips(tips: int) -> bool:
	if tips <= 0 or tips_doubled_day == day:
		return false
	tips_doubled_day = day
	coins += tips
	ads["last_rewarded_utc"] = int(Time.get_unix_time_from_system())
	Analytics.log_event(&"ad_rewarded_complete",
		{"placement": "double_tips"})
	touch()
	return true


## §13.5 Music Night (§17.2 evening purchase): ~150c buys tonight's
## singalong — every pad hears the music (Music Lovers cheer), the
## campfire's circle stays the loud part (Light Sleepers there lose
## a star), and tips ride +20%. Refundable until Goodnight like any
## same-day buy; the star-delta preview is just preview() re-run.
const MUSIC_NIGHT_PRICE := 150
const MUSIC_NIGHT_TIP_BONUS := 0.2


## The sticker reads what the verb charges — remote config can retune
## pacing post-launch without a reship (§24.8).
func music_night_price() -> int:
	return int(Platform.remote("music_night_price", MUSIC_NIGHT_PRICE))


func music_night_active() -> bool:
	return bool(site_state().get("music_night", false))


func buy_music_night() -> bool:
	var st := site_state()
	var price := music_night_price()
	if phase != Phase.EVENING or st.get("music_night", false) \
			or coins < price:
		return false
	coins -= price
	st["music_night"] = true
	_record("buy_music_night", {"price": price},
		{"verb": "cancel_music_night", "params": {"price": price}})
	_log("music_night", {"price": price})
	Analytics.log_event(&"purchase_item",
		{"kind": "event", "id": "music_night", "price": price})
	touch()
	return true


func _cancel_music_night(price: int) -> bool:
	var st := site_state()
	if not st.get("music_night", false):
		return false
	st["music_night"] = false
	coins += price
	touch()
	return true


# ------------------------------------------------------------- journal (§8)
#
# Each site's chapter holds five pages; a page's "check" is evaluated
# against that site's counters plus whatever happened tonight. Pages
# complete in any order, pay their gift, and register their unlocks.
# Bodies live in systems/journal.gd — these stay the public surface.

func _chapter(site := site_id) -> Dictionary:
	return journal._chapter(site)


func _goal_met(check: Dictionary, st: Dictionary,
		night: Dictionary) -> bool:
	return journal._goal_met(check, st, night)


func journal_event(name: String) -> void:
	journal.journal_event(name)


func _bump(metric: String, n := 1) -> void:
	journal._bump(metric, n)


func _check_pages(night := {}) -> Array:
	return journal._check_pages(night)


func vol2_open() -> bool:
	return journal.vol2_open()


func vol2_done() -> bool:
	return journal.vol2_done()


func page_done(page: int, site := site_id) -> bool:
	return journal.page_done(page, site)


func last_night_perfect() -> bool:
	return journal.last_night_perfect()


func chapter_done(site: StringName) -> bool:
	return journal.chapter_done(site)


func is_unlocked(unlock: String) -> bool:
	return journal.is_unlocked(unlock)


func _is_unlocked(unlock: String) -> bool:
	return journal._is_unlocked(unlock)


func site_reachable(site: StringName) -> bool:
	return journal.site_reachable(site)


func _story_done(reg_id: String) -> bool:
	return journal._story_done(reg_id)


# --- purchases (§6.1: one currency, no debt, refund until Goodnight) ---
# Verbs live in systems/build.gd; these stay the public surface the
# UI and tests already call.
func _layout(site := site_id) -> Dictionary:
	return build._layout(site)


func _decor_cell_set() -> Dictionary:
	return build._decor_cell_set()


func _decor_blocked(ignore := -1) -> Dictionary:
	return build._decor_blocked(ignore)


func _walk_cells(layout: Dictionary) -> Dictionary:
	return build._walk_cells(layout)


func _reachable_set(cells: Dictionary) -> Dictionary:
	return build._reachable_set(cells)


func _strands_any(free: Dictionary, pts: Array) -> bool:
	return build._strands_any(free, pts)


func _footprint_ok(row: Dictionary, cells: Array, ignore := -1) -> bool:
	return build._footprint_ok(row, cells, ignore)


func decor_cells_free(ignore := -1) -> Array:
	return build.decor_cells_free(ignore)


func decor_placement_ok(item_id: String, cells: Array,
		ignore := -1) -> bool:
	return build.decor_placement_ok(item_id, cells, ignore)


func fire_pit_upgraded() -> bool:
	return build.fire_pit_upgraded()


func buy_decor(item_id: String, cells: Array) -> bool:
	return build.buy_decor(item_id, cells)


func move_decor(idx: int, cells: Array) -> bool:
	return build.move_decor(idx, cells)


func store_decor(idx: int) -> bool:
	return build.store_decor(idx)


func place_stored(item_id: String, cells: Array) -> bool:
	return build.place_stored(item_id, cells)


func return_decor(idx: int) -> bool:
	return build.return_decor(idx)


## §variant: cosmetic re-skins of placed pieces — body lives in
## systems/build.gd beside the other purchase verbs; this stays the
## public surface the UI and tests already call.
func buy_decor_variant(idx: int, name: String) -> bool:
	return build.buy_decor_variant(idx, name)


func return_bought(item_id: String) -> bool:
	return build.return_bought(item_id)


func unlock_pad(pad_id: String) -> bool:
	return build.unlock_pad(pad_id)


func clear_pad(pad_id: String) -> bool:
	return build.clear_pad(pad_id)


func open_pad(pad_id: String) -> bool:
	return build.open_pad(pad_id)


func pad_unlock_price(pad_id: String) -> int:
	return build.pad_unlock_price(pad_id)


func pad_shelter_options(pad_id: String) -> Array:
	return build.pad_shelter_options(pad_id)


func upgrade_pad(pad_id: String, shelter: String) -> bool:
	return build.upgrade_pad(pad_id, shelter)


func buy_gear(item_id: String) -> bool:
	return build.buy_gear(item_id)


func buy_staple(item_id: String) -> bool:
	return build.buy_staple(item_id)

const PANTRY_BASE := 20
const PANTRY_COOLER := 30
const SITE_RANKS := {"pinewatch": 0, "whisper_river": 1,
	"lantern_valley": 2}


func _site_rank(site := site_id) -> int:
	return SITE_RANKS.get(site, 0)


func _unlock_rank(unlock: String) -> int:
	if unlock.begins_with("P"):
		return 0
	if unlock.begins_with("W"):
		return 1
	return 2


func pantry_count() -> int:
	return pantry_sys.pantry_count()


func pantry_capacity() -> int:
	return pantry_sys.pantry_capacity()


## Returns how many actually fit (§7.4: nodes keep what's left over).
func pantry_add(item_id: String, n := 1) -> int:
	return pantry_sys.pantry_add(item_id, n)


## Inverse of pantry_add — used by refund inverses; returns how many
## came out (0 when the staple already went into a meal).
func pantry_remove(item_id: String, n := 1) -> int:
	return pantry_sys.pantry_remove(item_id, n)


func _ingredients_of_kind(kind: String, site := site_id) -> Array:
	return pantry_sys._ingredients_of_kind(kind, site)


## Errands delegates — §7.1–7.3 live in systems/errands.gd.
func _roll_forage() -> Array:
	return errands.roll_forage()


func gather(node_id: String) -> Array:
	var got: Array = errands.gather(node_id)
	if not got.is_empty():
		_log("gather", {"items": got})
		touch()
	return got


func fish_catch(spot: String) -> String:
	var pick: String = errands.fish_catch(spot)
	if pick != "":
		_log("catch", {"id": pick, "spot": spot})
		Analytics.log_event(&"catch", {"id": pick})
		touch()
	return pick


## Fishable spots for this site's layout, normalized to
## [{id, px:[x,y]}] — pond (scalar), fishing (named banks) and
## stream all read the same to presenters and the sim.
func fish_spots() -> Array:
	var es: Dictionary = _layout().get("errand_spots", {})
	var out := []
	for key in ["pond", "stream"]:
		var p: Variant = es.get(key)
		if p is Array and p.size() >= 2:
			out.append({"id": key, "px": p})
	var fishing: Dictionary = es.get("fishing", {})
	var names := fishing.keys()
	names.sort()                                 # deterministic order
	for k in names:
		var p: Variant = fishing[k]
		if p is Array and p.size() >= 2:
			out.append({"id": String(k), "px": p})
	return out


## §LV signature: the valley photographs itself — one shot a day with
## the Field Camera (L2 unlock), a small print-board sale, and five
## shots finish the Photo Wall (the L4 claim) as a journal event.
func can_photo() -> bool:
	return site_id == &"lantern_valley" and "camera" in gear \
		and int(site_state().get("photo_day", -1)) != site_day()


func take_photo() -> Dictionary:
	if not can_photo():
		return {}
	var st := site_state()
	var rows: Array = Catalog.data.get("photos", [])
	if rows.is_empty():
		return {}
	var rng: RandomNumberGenerator = _rng_for("photo")
	var shot: Dictionary = rows[rng.randi() % rows.size()]
	st["photos"].append(String(shot["id"]))
	st["photo_day"] = site_day()
	var price := int(shot.get("coins", 10))
	coins += price
	_log("photo", {"id": String(shot["id"]), "coins": price})
	Analytics.log_event(&"photo", {"id": String(shot["id"])})
	if st["photos"].size() >= 5:
		journal_event("photo_wall")
	touch()
	return {"id": String(shot["id"]), "name": String(shot.get("name", "")),
		"note": String(shot.get("note", "")), "coins": price}


## §PW signature: Grandpa's margins read front-to-back, one a day,
## only at his camp — the tutorial the game never says out loud.
## Hints carry real effects: tomorrow's weather, a written-down
## recipe pair, or just his hand on the page.
func can_read_margin() -> bool:
	var st := site_state()
	return site_id == &"pinewatch" \
		and int(st.get("margin_day", -1)) != site_day() \
		and st["margins_read"].size() < \
			Catalog.data.get("margins", []).size()


func read_margin() -> Dictionary:
	if not can_read_margin():
		return {}
	var st := site_state()
	var rows: Array = Catalog.data.get("margins", [])
	var row: Dictionary = rows[st["margins_read"].size()]
	st["margins_read"].append(String(row["id"]))
	st["margin_day"] = site_day()
	var out := {"id": String(row["id"]),
		"text": String(row.get("text", ""))}
	var hint: Dictionary = row.get("hint", {})
	match String(hint.get("kind", "")):
		"weather":
			# Grandpa's knee called it in '87 — the stream knows
			out["hint"] = {"kind": "weather",
				"tomorrow": _weather_at(site_day() + 1)}
		"recipe":
			var pair: Array = hint.get("pair", [])
			var rid := String(hint.get("recipe", ""))
			if pair.size() == 2 and rid != "":
				var key := "+".join(
					[pair[0], pair[1]] if pair[0] < pair[1]
					else [pair[1], pair[0]])
				pairs_tried[key] = rid
				out["hint"] = {"kind": "recipe", "recipe": rid}
	_log("margin", {"id": String(row["id"])})
	Analytics.log_event(&"margin", {"id": String(row["id"])})
	touch()
	return out


func can_spot() -> bool:
	return errands.can_spot()


func spot() -> Dictionary:
	var rep: Dictionary = errands.spot()
	if not rep.is_empty():
		_log("spot", {"bird": String(rep.get("bird", {})
			.get("id", ""))})
		touch()
	return rep


## Recipes a guest could plausibly crave at this site (§5.2 card):
## every ingredient obtainable here, oven recipes only once Lantern
## Valley makes them possible.
func _favourite_pool(site := site_id) -> Array:
	return pantry_sys._favourite_pool(site)


func _slot(want: String, have_id: String) -> bool:
	return want == have_id or (want == "any_fish" \
		and _row("ingredients", have_id).get("kind") == "fish")


func _match_recipe(a: String, b: String) -> Dictionary:
	var ev := String(site_state().get("event", ""))
	for r in Catalog.data.get("recipes", []):
		var pair: Array = r.get("pair", [])
		if pair.size() != 2:
			continue
		# §13.5: a festival dish only cooks on its own night —
		# off-night the same pair falls through to fusion/mash.
		if r.has("festival") and String(r["festival"]) != ev:
			continue
		if (_slot(pair[0], a) and _slot(pair[1], b)) \
				or (_slot(pair[0], b) and _slot(pair[1], a)):
			return r
	return {}


## Fallback tier (spec 004, data/fusion.json): an unknown pair still
## improvises when the two ingredient *kinds* are compatible. Exact
## recipes and oven hints win first; no kind row → Camp Mash.
func _fusion_match(a: String, b: String) -> Dictionary:
	var ka := String(_row("ingredients", a).get("kind", ""))
	var kb := String(_row("ingredients", b).get("kind", ""))
	if ka == "" or kb == "":
		return {}
	for f in Catalog.data.get("fusion", []):
		var kinds: Array = f.get("kinds", [])
		if kinds.size() == 2 and ((kinds[0] == ka and kinds[1] == kb) \
				or (kinds[0] == kb and kinds[1] == ka)):
			return f
	return {}


## §7.5: pick two ingredients, cook one portion. A known pair → that
## meal; an oven pair at the campfire → hint, ingredients kept; a
## kind-compatible unknown pair → a fusion dish; else → Camp Mash.
func cook(a: String, b: String) -> Dictionary:
	var need := {}
	for x in [a, b]:
		need[x] = int(need.get(x, 0)) + 1
	for x in need:
		if int(pantry.get(x, 0)) < need[x]:
			return {"result": "missing", "missing": x}
	var key := "+".join([a, b] if a < b else [b, a])
	var r := _match_recipe(a, b)
	var fused := false
	if r.is_empty():
		r = _fusion_match(a, b)
		if r.is_empty():
			r = _row("recipes", "camp_mash")
			pairs_tried[key] = "camp_mash"
		else:
			fused = true
			pairs_tried[key] = String(r["id"])
	elif r.get("station") == "oven" and "oven" not in gear:
		pairs_tried[key] = "oven_hint"
		touch()                          # the discovery log is a write
		return {"result": "oven_hint",
			"hint": "%s needs the Camp Oven" % r.get("name", "?")}
	else:
		pairs_tried[key] = r["id"]
	for x in need:
		pantry[x] -= need[x]
		if pantry[x] <= 0:
			pantry.erase(x)
	var meal := {"id": r["id"], "price": int(r.get("price", 5))}
	meals.append(meal)
	if not fused and r["id"] not in recipes_cooked:
		recipes_cooked.append(r["id"])
	if r["id"] != "camp_mash":
		cook_counts[r["id"]] = int(cook_counts.get(r["id"], 0)) + 1
	if r.get("station") == "oven":
		_bump("oven_recipes")
	_check_pages()                                   # e.g. P3 "5 recipes"
	# meals are spent-food — the log records the act, no inverse
	_record("cook", {"a": a, "b": b, "meal": r["id"]})
	_log("cook", {"recipe": r["id"], "fused": fused})
	Analytics.log_event(&"cook", {"recipe": r["id"],
		"fused": fused})
	touch()
	return {"result": "ok", "recipe": r["id"], "meal": meal,
		"name": r.get("name", "")}


# ------------------------------------------------------------- the dog (§9)
#
# A stray who turns up on Pinewatch's first night. No needs, no
# penalties, never lost; its guest effect only ever comes from the
# Dog Bed decor item, so wandering never touches scoring.

## Dog delegates — §9 lives in systems/dog.gd; `dog` state stays
## above for the save schema.
func dog_pet() -> bool:
	if dog_sys.pet():
		touch()
		return true
	return false


func name_dog(n: String) -> void:
	dog_sys.rename(n)
	touch()


## §9 adoption: bond at Friend level (dog.json levels[2]) means the
## stray stayed — the naming sheet calls this once, then the flag
## rides the save so the prompt never repeats.
func adopt_dog(n: String) -> void:
	dog["adopted"] = true
	dog_sys.rename(n)
	_log("dog_adopt", {"name": n})
	Analytics.log_event(&"dog_adopt", {})
	touch()


func dog_adopted() -> bool:
	return bool(dog.get("adopted", false))


func dog_level() -> int:
	return dog_sys.level()


func dog_trick() -> String:
	return dog_sys.trick()


func dog_bed_placed() -> bool:
	return dog_sys.bed_placed()


func can_dog_fetch() -> bool:
	return dog_sys.can_fetch()


func dog_fetch(kind: String) -> Dictionary:
	return dog_sys.fetch(kind)


# ------------------------------------------------------------- Daily (§10)
#
# One shared puzzle per calendar day, seeded by hash("daily", date).
# One scored attempt; unlimited practice afterwards. Unlocks with
# Pinewatch letter 6 (p06).

const DAILY_EPOCH := SysDaily.EPOCH

var daily_state := {"date": "", "score": -1}      # last scored attempt


## Daily delegates — §10 lives in systems/daily.gd; `daily_state`
## stays above for the save schema.
func daily_unlocked() -> bool:
	return daily_sys.unlocked()


func _daily_date(date_str := "") -> String:
	return daily_sys.date(date_str)


func daily_n(date_str: String) -> int:
	return daily_sys.n(date_str)


func daily(date_str := "") -> Dictionary:
	return daily_sys.puzzle(date_str)


func _daily_seed(d: String, tries: int) -> int:
	return daily_sys.seed_for(d, tries)


func _daily_tries(d: String) -> int:
	return daily_sys.tries(d)


func _daily_gen(d: String, tries: int) -> Dictionary:
	return daily_sys.gen(d, tries)


func _trait_kinds() -> Dictionary:
	var kinds := {}
	for t in Catalog.data.get("traits", []):
		kinds[t["id"]] = t.get("kind", "need")
	return kinds


func daily_score(puzzle: Dictionary, assignments: Dictionary,
		placements: Dictionary, submit := false) -> Dictionary:
	var rep: Dictionary = daily_sys.score(puzzle, assignments,
		placements, submit)
	if submit:
		touch()
	return rep


func daily_share(puzzle: Dictionary, results: Array) -> String:
	return daily_sys.share(puzzle, results)


# ------------------------------------------------------------- save (§22)

func state_dict() -> Dictionary:
	crew_tick()
	return {"day": day, "site": String(site_id), "phase": phase,
		"sites_visited": sites_visited, "crew": crew.duplicate(true),
		"coins": coins, "seed": seed, "meals": meals.duplicate(true),
		"pantry": pantry.duplicate(), "gear": gear.duplicate(),
		"recipes": recipes_cooked.duplicate(),
		"cook_counts": cook_counts.duplicate(),
		"fund_total": fund_total,
		"pairs_tried": pairs_tried.duplicate(),
		"letters": letters_read.duplicate(),
		"dialogue": dialogue_seen.duplicate(),
		"journal": {"vignettes_seen": vignettes_seen.duplicate(),
			"days_log": days_log.duplicate(true),
			"personas_met": personas_met.duplicate(),
			"letters_any": letters_delivered_any.duplicate()},
		"daily": daily_state.duplicate(),
		"actions": action_log.duplicate(true),
		"day_log": day_log.duplicate(true),
		"ads": ads.duplicate(true),
		"bought_today": bought_today.duplicate(),
		"tips_doubled": tips_doubled_day,
		"dog": dog.duplicate(),
		"field_notes": field_notes.duplicate(),
		"passport": passport_stamps.duplicate(),
		"settings": settings.duplicate(true),
		"sites": _sites_to_json()}


## Vector2i cells aren't JSON-safe — flatten before saving, rebuild on
## load (§22).
func _sites_to_json() -> Dictionary:
	var out := {}
	for site in sites:
		var st: Dictionary = sites[site].duplicate(true)
		var fire: Dictionary = st["campfire"]
		st["campfire"] = {"cell": [fire["cell"].x, fire["cell"].y],
			"radius": fire["radius"]}
		var decor := []
		for d in st["decor"]:
			var item: Dictionary = d.duplicate()
			item["cells"] = d["cells"].map(
				func(c): return [c.x, c.y])
			decor.append(item)
		st["decor"] = decor
		out[site] = st
	return out


func _sites_from_json(raw: Dictionary) -> Dictionary:
	var out := {}
	for site in raw:
		var st: Dictionary = raw[site].duplicate(true)
		var fire: Dictionary = st.get("campfire", {})
		var fc: Array = fire.get("cell", [0, 0])
		st["campfire"] = {"cell": Vector2i(fc[0], fc[1]),
			"radius": int(fire.get("radius", 2))}
		for d in st.get("decor", []):
			d["cells"] = d.get("cells", []).map(
				func(c): return Vector2i(c[0], c[1]))
		out[StringName(site)] = st
	return out


## §22 map drift — a repaint can orphan placed decor: a save written
## against an older map may hold pieces on cells that are now water,
## wall, or outside the core.  st["map_rev"] stamps the layout the save
## was written against; on mismatch (or missing — pre-stamp saves) we
## re-run placement law on every placed piece and illegal ones move to
## storage, never deleted.  Restoration auras are exempt — they follow
## their restored structure, not the decor grid.
func _reconcile_map(site: StringName) -> void:
	hosting_sys._reconcile_map(site)

func load_state(state: Dictionary) -> void:
	day = int(state.get("day", day))
	site_id = StringName(state.get("site", site_id))
	phase = Phase.values()[clampi(
		int(state.get("phase", int(phase))), 0, Phase.size() - 1)]
	sites_visited = state.get("sites_visited", sites_visited)
	coins = int(state.get("coins", coins))
	seed = int(state.get("seed", seed))
	meals = state.get("meals", meals)
	pantry = state.get("pantry", pantry)
	gear = state.get("gear", gear)
	recipes_cooked = state.get("recipes", recipes_cooked)
	cook_counts = state.get("cook_counts", cook_counts)
	fund_total = int(state.get("fund_total", fund_total))
	pairs_tried = state.get("pairs_tried", pairs_tried)
	letters_read = state.get("letters", letters_read)
	dialogue_seen = state.get("dialogue", dialogue_seen)
	vignettes_seen = state.get("journal", {}).get(
		"vignettes_seen", vignettes_seen)
	days_log = state.get("journal", {}).get("days_log", days_log)
	personas_met = state.get("journal", {}).get(
		"personas_met", personas_met)
	letters_delivered_any = state.get("journal", {}).get(
		"letters_any", letters_delivered_any)
	daily_state = state.get("daily", daily_state)
	action_log = state.get("actions", action_log)
	day_log = state.get("day_log", day_log)
	ads.merge(state.get("ads", {}), true)
	bought_today = state.get("bought_today", bought_today)
	if state.has("actions"):
		_refresh_bought()            # the log is the truth (v1 saves
		# without it keep the stored list — same-day refund stands)
	tips_doubled_day = int(state.get("tips_doubled", tips_doubled_day))
	dog = state.get("dog", dog)
	field_notes = state.get("field_notes", field_notes)
	passport_stamps = state.get("passport", passport_stamps)
	if state.has("sites"):
		sites = _sites_from_json(state["sites"])
		# Only the CURRENT site reconciles here — _footprint_ok reads
		# site_state() (the current site); others reconcile lazily on
		# visit_site().  site_id was set above, so the check is honest.
		if sites.has(site_id):
			_reconcile_map(site_id)
	for k in state.get("settings", {}):
		settings[k] = state["settings"][k]
	apply_settings()
	var saved: Dictionary = state.get("crew", {})
	_crew_reset()
	for key in saved:
		crew[key] = saved[key]
	_next_structure = _next_unfinished()
	crew_tick()                    # offline progress applies on load (§8.4)
	_save_dirty = false            # a freshly loaded state is clean


## First structure not fully collected, or one past the active one.
func _next_unfinished() -> int:
	return crew_sys.next_unfinished()
