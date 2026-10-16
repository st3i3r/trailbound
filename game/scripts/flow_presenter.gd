extends RefCounted
## FlowPresenter — day flow + celebrations (§4/§13.4/§17.2).
## SOTA split (D-ARCH-9/10/11/12/13): the scene owns nodes,
## camera, evening/board/selection UI state and all builders;
## this owns the phase readout + transitions (status, goodnight,
## sleep, advance, morning/prep/evening starts, travel), morning
## dialogue queue, and milestone ceremonies. Scene passed as
## untyped `s`; Node APIs (`tr`, `get_tree`) route via `s`.
## Moved state: night_rating, _five_star_seen, ceremony queue +
## busy flag, dialogue queue + bubble token. `evening_open`,
## `_board_tok`, cue id and boot flag stay on the scene.


var s  # the pinewatch_test scene (untyped: mutual ref)

var night_rating := ""
var _five_star_seen := false
var _ceremony_q := []
var _ceremony_busy := false
var _dlg_queue := []
var _dlg_tok := 0


func _init(scene) -> void:
    s = scene


func status() -> void:
    var st: Dictionary = Game.site_state()
    # ranger's tips setting gates the [hint] tail; the status facts
    # themselves always show
    var hint := "   [%s]" % s.tr("tray_hint") \
        if bool(Game.settings.get("rangers_tips", true)) else ""
    s.hud.set_status(("day %d · site day %d · %s · %dc%s") % [
        Game.day, Game.site_day(), st["weather"].to_upper(), Game.coins,
        hint])
    # ambience is a live mix owned by WorldFX — the dusk + front
    # scalars crossfade day birds / night crickets / storm wash
    s.hud.set_crew_badge(Game.is_stage_ready())
    # the button is the phase action, not the phase name (§4 table:
    # Evening -> Goodnight, Night -> Sleep, Morning -> Head out)
    s.hud.set_phase(s.tr("hud_goodnight").to_upper() if s.evening_open \
        else (s.tr("hud_headout").to_upper() \
            if Game.phase == Game.Phase.PREP \
            else (s.tr("hud_prep").to_upper() \
                if Game.phase == Game.Phase.MORNING \
                else s.tr("hud_sleep").to_upper())))
    s.hud.set_rating(night_rating if night_rating else "—")
    s.hud.set_coins(s.tr("hud_coins_short") % Game.coins)
    s.hud.set_day("%s %d · %s" % [s.tr("hud_day").to_upper(), Game.day,
        s.tr("weather_" + String(st["weather"])).to_upper()],
        st["weather"])


func goodnight() -> void:
    # capture names before goodnight() clears st["guests"]
    var names := {}
    for gid in Game.site_state()["guests"]:
        names[gid] = Game.site_state()["guests"][gid].get("name", gid)
    var rep := Game.goodnight()
    night_rating = "%.1f" % rep["rating"]
    if rep["rating"] >= 4.99 and not _five_star_seen:
        _five_star_seen = true              # first-ever 5★ earns the beat
        queue_ceremony("fivestar", s.tr("cer_five"), "", "star_full")
    s.evening_open = false
    s._deselect()
    s._clear_bubbles()
    s.hud.tray.reset()
    s.hud.tray.visible = false
    status()
    # spec 005 A: tonight's vignette is a beat — the card shows in the
    # sheet and its `cue` light term grades the world behind it; clears
    # whichever way the sheet leaves (Sleep or a dimmer-dismiss)
    var vid := String(rep.get("vignette", ""))
    if vid != "":
        var vrow := vignette_row(vid)
        var cue: Dictionary = vrow.get("cue", {})
        if not cue.is_empty():
            Game.set_light_cue("vig_" + vid,
                Color(String(cue.get("col", "e8c46a"))),
                StringName(cue.get("w", "ember")))
    # UI-022: the payoff sheet — reviews with breakdowns, totals,
    # pages, forecast, Double-tips offer, Sleep
    var sheet := NightSummary.make(rep, names, Game.day,
        Game.forecast())
    sheet.sleep_pressed.connect(on_sleep)
    if vid != "":
        sheet.tree_exited.connect(
            func(): Game.clear_light_cue("vig_" + vid))
    s.panel_mgr.open(sheet)
    sheet.run_count_up.call_deferred()


func vignette_row(vid: String) -> Dictionary:
    for v in Catalog.data.get("vignettes", []):
        if v.get("id") == vid:
            return v
    return {}


## Sleep exits the night (§4 phase table): close the summary and roll
## into the next morning — same path the phase button takes.


func on_sleep() -> void:
    UIFeel.haptic("confirm")
    s.panel_mgr.close()
    advance_phase()


func advance_phase() -> void:
    if s.evening_open:
        goodnight()
    elif Game.phase == Game.Phase.MORNING:
        UIFeel.haptic("confirm")               # into the day's prep
        UIFeel.sfx("confirm")
        start_prep()
    elif Game.phase == Game.Phase.PREP:
        UIFeel.haptic("confirm")               # Head out — guests arrive
        UIFeel.sfx("confirm")
        start_evening()
    else:                                      # Night -> next Morning
        s.hud.set_report("")
        Game.advance_day()                     # set_phase(MORNING) inside
        Ads.show_interstitial()                # §24.2 pacing-gated mock
        start_morning()


## UI-023 Morning: camp is quiet — the notice board is the interactive
## object.  A "!" marker floats over the signpost until Head out.


func start_morning() -> void:
    s.evening_open = false
    s._clear_cast()                            # last night's cast is home
    s._cast_day()                              # morning ambience joins
    s._set_build(false)                          # build tools stay out
    s._clear_errands()                           # a new day re-rolls nodes
    s._sync_crew_hut()                           # day-2 crew may start here
    s._check_dog_adoption()                      # Friend bond → naming sheet
    # "!" chip over the notice board — flat glass chip; gold glyph.
    # offset places it just over the signpost's visible head — the
    # prop is mostly occluded by the chest + warden tent
    var bang := UIKit.label_for("!", UITokens.TypeRole.DISPLAY,
        UITokens.GOLD)
    bang.position = Vector2(8, -1)
    var rc: Array = s.markers.icon_chip(s.board_anchor, bang,
        Vector2(-11, -42), Vector2(22, 22))
    s._board_tok = rc[0]
    var bub: Panel = rc[1]
    # gentle bob so the marker reads alive, not painted on the prop.
    # Gate: under reduced motion/flashing a set_loops() tween at the
    # collapsed 1ms duration would be an infinite strobe — skip it.
    bub.pivot_offset = bub.size / 2.0
    if UIFeel.can_pulse():
        # bound to the chip so the loop dies when the marker releases —
        # a scene-bound loop would keep stepping a freed target
        var bob := UIFeel.apply(bub.create_tween().set_loops(), "marker")
        var bd := UIFeel.dur("marker")
        bob.tween_property(bub, "scale", Vector2(1.12, 1.12), bd)
        bob.tween_property(bub, "scale", Vector2.ONE, bd)
    check_dialogue()
    status()


## Authored light cue -> moment-bound emit term on WorldFX (spec 005).
## Single-slot in Game; we translate set/clear into track/untrack —
## "ember" warm beats, "dusk" night beats, "flat" held tints.


func start_prep() -> void:
    Game.set_phase(Game.Phase.PREP)
    s._cast_day()                              # recast over any build edits
    s._spawn_errands()
    status()


## Decal reads the node's contents at a glance; gold pops for the rare.


func start_evening() -> void:
    if s._board_tok:
        s.markers.release(s._board_tok)
        s._board_tok = 0
    s._set_build(false)                          # tools down at dusk
    s._clear_errands()                           # prep closes at dusk
    s._sync_crew_hut()                           # porch glow wakes at dusk
    Game.set_phase(Game.Phase.EVENING)
    s._spawn_board()
    s._cast_evening()                            # D4 — tonight's cast on
    status()


func on_travel(site: StringName) -> void:
    if not Game.travel_to(site):
        UIFeel.sfx("warn")
        s._hud_hint(s.tr("map_morning"))
        return
    UIFeel.sfx("confirm")
    UIFeel.haptic("confirm")
    s.panel_mgr.close()
    Transition.to_scene(s.get_tree().current_scene.scene_file_path)


func check_dialogue() -> void:
    _dlg_queue.clear()
    var when_rows := []
    var day_rows := []
    var rows: Array = Catalog.data.get("dialogue", [])
    for d in rows:
        if d.get("site", "") != String(Game.site_id):
            continue
        if Game.dialogue_seen.get(d.get("id", ""), false):
            continue
        if not s._actor_map.has(d.get("anchor", "")):
            continue
        var w: Dictionary = d.get("when", {})
        if not w.is_empty():
            if Game.dialogue_when_ok(w):
                when_rows.append(d)
        elif int(d.get("day", -1)) == Game.site_day():
            day_rows.append(d)
    _dlg_queue = when_rows + day_rows
    run_dialogue()


func run_dialogue() -> void:
    if _dlg_queue.is_empty() or _dlg_tok != 0:
        return
    var d: Dictionary = _dlg_queue.pop_front()
    var anchor: Node2D = s._actor_map[d["anchor"]]
    Game.dialogue_seen[d["id"]] = true
    _dlg_tok = DialogueBubble.say(s.markers, anchor,
        Vector2(-DialogueBubble.W / 2.0, -66), String(d.get("who", "")),
        d.get("lines", []), func(): _dlg_tok = 0; run_dialogue())


func on_crew_collected(_structure: StringName, keepsake: StringName,
		_finished: bool) -> void:
    s.hud.set_crew_badge(Game.is_stage_ready())
    s._sync_crew_hut(true)               # the cleared stage scatters off
    queue_ceremony("keepsake", s.tr("cer_keepsake"),
        keepsake_label(String(keepsake)), "keepsakes")


func on_page_completed(_site: StringName, _page: int, gift: int,
		_unlocks: Array) -> void:
    var sub: String = s.tr("cer_gift").format({"n": gift}) if gift > 0 else ""
    queue_ceremony("page", s.tr("cer_page"), sub, "journal")


## Milestones queue — a page completing on load or a keepsake landing
## the same tick as a 5★ night must never stack cards.  Held during
## boot (signals can fire inside _ready) and played one at a time.


func queue_ceremony(kind: String, title: String, sub: String,
		icon: String) -> void:
    _ceremony_q.append([kind, title, sub, icon])
    drain_ceremonies()


## spec 005 A3: ceremony kind -> authored light cue (the world grades
## while the card is up).  Warm for milestones, gold for the perfect
## night, a journal-blue for pages.


func drain_ceremonies() -> void:
    if _ceremony_busy or not s._booted or _ceremony_q.is_empty():
        return
    _ceremony_busy = true
    var c: Array = _ceremony_q.pop_front()
    var kind := String(c[0])
    # spec 005 A3: each ceremony kind grades the world while its card
    # is up — the Eastward pattern of authored light on the beat
    var cue: Dictionary = CEREMONY_CUE.get(kind, {})
    if not cue.is_empty():
        Game.set_light_cue("cer_" + kind, cue["col"], cue["w"])
    Ceremony.play(s._ceremony_layer, kind, String(c[1]),
        String(c[2]), String(c[3]),
        func() -> void:
            Game.clear_light_cue("cer_" + kind)
            _ceremony_busy = false
            drain_ceremonies())


func keepsake_label(kid: String) -> String:
    var structures: Array = Catalog.data.get("crew", {}) \
        .get("structures", [])
    for row in structures:
        for st in row.get("stages", []):
            if st.get("keepsake", {}).get("id") == kid:
                return String(st["keepsake"].get("label", kid))
    return kid


const CEREMONY_CUE := {
    "fivestar": {"col": Color("e8c46a"), "w": &"flat"},
    "keepsake": {"col": Color("c9a45c"), "w": &"flat"},
    "page":     {"col": Color("7a9ac4"), "w": &"flat"},
}
