extends RefCounted
## QA smoke driver (§8 harness) — extracted from pinewatch_test.gd.
## SOTA split: prod scene owns world/HUD/FX; this owns the --smoke
## choreography and drives the scene through its public tap APIs
## (scene passed as untyped `s` so prod never imports test code).


## Poll a condition each frame (cap ~4s) — tween timing varies headless.
static func frames_until(s, cond: Callable, cap := 240) -> void:
    for i in cap:
        if cond.call():
            return
        await s.get_tree().process_frame




static func run(s) -> void:
    await s.get_tree().process_frame
    s._on_back()
    await frames_until(s, func(): return s.panel_mgr.top() != null \
        and s.panel_mgr.top().modulate.a > 0.9)
    var top: Control = s.panel_mgr.top()
    print("SMOKE back -> quit panel open: ", top != null,
          " size:", top.size if top else Vector2.ZERO)
    s._on_back()
    await frames_until(s, func(): return s._quit == null)
    print("SMOKE back -> closed: ", s.panel_mgr.top() == null,
          " quit cleared:", s._quit == null)
    s._fire_near(true)
    await frames_until(s, func(): return s.fire_bubble.modulate.a > 0.9)
    print("SMOKE fire bubble a=", snappedf(s.fire_bubble.modulate.a, 0.01))
    s._fire_near(false)
    await frames_until(s, func(): return not s.fire_bubble.visible)
    print("SMOKE fire bubble hidden:", not s.fire_bubble.visible)
    # WorldFX scalars: front rolls in and the channels derive from it —
    # rain density + emission gate, nightfall darkens the composite
    s._fx.set_front(1.0, 0.2)
    await frames_until(s, func(): return s._fx.front > 0.95)
    print("SMOKE front rolled:", snappedf(s._fx.front, 0.01),
          " rain:", s._rain.emitting)
    s._fx.set_front(0.0, 0.2)
    await frames_until(s, func(): return s._fx.front < 0.05)
    print("SMOKE front cleared:", not s._rain.emitting)
    var day_lum: float = s._grade.color.r + s._grade.color.g \
        + s._grade.color.b
    s._fx.set_dusk(1.0, 0.2)
    await frames_until(s, func(): return s._fx.dusk > 0.95)
    var night_lum: float = s._grade.color.r + s._grade.color.g \
        + s._grade.color.b
    print("SMOKE dusk darkens:", night_lum < day_lum * 0.7)
    # matrix.txt rows at dusk=1: a storm must DEEPEN the night, and
    # a >1.0 profile channel is in-scatter — it can never lift it
    s._fx.set_front(1.0, 0.05, s.STORM_MUL)
    var storm_lum: float = s._grade.color.r + s._grade.color.g \
        + s._grade.color.b
    print("SMOKE storm-night darker:", storm_lum < night_lum)
    s._fx.base_color = Color(1.30, 1.20, 0.90)  # heatwave-class tint
    var heat_lum: float = s._grade.color.r + s._grade.color.g \
        + s._grade.color.b
    print("SMOKE scatter can't lift night:",
          heat_lum < night_lum * 1.1)
    print("SMOKE ember lights:", s._fire_light.energy > 0.5)
    # §5.10 jitter: the hearth breathes — two samples frames apart
    # must differ (front=1 here, so it's already in sputter mode)
    var fe0: float = s._fire_light.energy
    for i in 5:
        await s.get_tree().process_frame
    var fe1: float = s._fire_light.energy
    for i in 7:
        await s.get_tree().process_frame
    var fe2: float = s._fire_light.energy
    print("SMOKE fire flickers:", fe0 != fe1 or fe1 != fe2)
    # AmbientFX rides the same scalars — at dusk=1: fireflies up,
    # pollen washed out, moths hugging the lamps.  Ratios are set in
    # _process so the frames waited above have applied them.
    print("SMOKE ambient night:", s._amb != null
          and s._amb._flies.amount_ratio > 0.5
          and s._amb._motes.amount_ratio < 0.05)
    print("SMOKE moths on lamps:", s._amb == null
          or s._amb._moths.is_empty()
          or s._amb._moths[0]["s"].modulate.a > 0.9)
    var swayed := 0
    for n in s.scatter.get_children() + s.world.get_children() \
            + s.pads_node.get_children():
        if n is Sprite2D and n.material is ShaderMaterial:
            swayed += 1
    print("SMOKE foliage sway assigned:", swayed >= 6)
    s._fx.set_front(0.0, 0.05, s.WARM_MUL)
    s._fx.set_dusk(s._dusk_target(Game.phase), 0.05)
    # tracked overlay: storm's ripple warp rides the front scalar —
    # at front 1.0 the shader intensity lands at its profile val
    s._set_weather("storm", 0.05)
    var wv: ColorRect = s._warp if s._warp.visible else s._warp2
    var iv_raw: Variant = (wv.material as ShaderMaterial) \
        .get_shader_parameter("intensity")
    var iv: float = float(iv_raw) if iv_raw != null else -1.0
    print("SMOKE ripple tracks front:", iv > 0.9)
    s._set_weather("sunny", 0.05)
    # UI-020 tray: build -> select -> previews+strip -> seat -> unseat
    var st: Dictionary = Game.site_state()
    var board: Array = st["board"]
    print("SMOKE tray cards:", s.hud.tray._cards.size(), "of",
          board.size())
    var g0: String = board[0]["id"]
    s._tap_card(g0)
    await s.get_tree().process_frame
    print("SMOKE select:", s.selected == g0,
          " previews:", s.star_labels.size() > 0,
          " strip:", s.hud.tray.strip.visible)
    var pid0 := ""
    for pid in s.pad_cells:
        if st["pads"][pid].get("open", false) \
                and not s._pad_occupied(pid):
            pid0 = pid
            break
    s._try_seat(pid0)
    await s.get_tree().process_frame
    print("SMOKE seat:", st["assignments"].has(g0),
          " card dimmed:", s.hud.tray.is_seated(g0),
          " bubble:", s.guest_bubbles.has(g0))
    s._do_unseat(g0)
    print("SMOKE unseat:",
          not Game.site_state()["assignments"].has(g0),
          " card restored:", not s.hud.tray.is_seated(g0),
          " bubble freed:", not s.guest_bubbles.has(g0))
    s._tap_card(g0)
    s._tap_card(g0)
    print("SMOKE toggle-deselect:", s.selected == "")
    # re-seat so the night actually hosts a guest — the D-UI-8
    # letter gate needs guests_welcomed>=1, and the payout path
    # wants a real stay
    s._tap_card(g0)
    s._try_seat(pid0)
    await s.get_tree().process_frame
    print("SMOKE re-seat for night:", st["assignments"].has(g0))
    # UI-038 dinner: cook the favourite (injected — the cook path is
    # covered separately), the menu lane lights, arm + serve by hand,
    # and the plate chip lands beside the guest
    var g0_fav := String(st["guests"].get(g0, {}).get("favourite", ""))
    if g0_fav == "":
        g0_fav = "trail_stew"
        st["guests"][g0]["favourite"] = g0_fav
    if not Game.recipes_cooked.has(g0_fav):
        Game.recipes_cooked.append(g0_fav)
    Game.meals.append({"id": g0_fav, "price": 20})
    s.hud.tray.set_meals(Game.meals)
    await s.get_tree().process_frame           # lane lays out first
    var midx := Game.meals.size() - 1
    var meal_hit: bool = s.hud.tray.meal_at(
        s.hud.tray._meals[midx].get_global_rect().get_center()) == midx
    s._tap_meal(midx)
    s._serve_tap(g0)
    var st_sv: Dictionary = Game.site_state()
    print("SMOKE meal lane:", meal_hit,
          " serve:", String(st_sv["served"].get(g0, "")) == g0_fav,
          " plate:", s._served_marks.has(g0))
    s._serve_tap(g0)                            # same dish twice = unserve
    var unserved: bool = not st_sv["served"].has(g0)
    s._serve_tap(g0)                            # and back on for the night
    print("SMOKE unserve/re-serve:", unserved,
          String(st_sv["served"].get(g0, "")) == g0_fav)
    # UI-022: Goodnight -> summary sheet -> Sleep -> next morning
    var day_before := Game.day
    s._advance_phase()
    await frames_until(s, func(): return s.panel_mgr.top() != null)
    var sheet: Control = s.panel_mgr.top()
    print("SMOKE night sheet:", sheet is NightSummary)
    if sheet is NightSummary:
        # spec 005: the vignette beat lands — card in the sheet, its
        # authored light cue grading the world behind; days_log gains
        # the reactive-bark fields (fav_served/regulars)
        var vig_card: Node = sheet.find_child("VignetteCard", true, false)
        print("SMOKE vignette card:", vig_card != null,
              " cue:", String(Game._light_cue.get("id", ""))
                  .begins_with("vig_"),
              " fav served:", Game.days_log.back()
                  .get("fav_served", false))
        (sheet as NightSummary).sleep_pressed.emit()
        # the out-tween frees the sheet — the vig cue clears on
        # tree_exited, so wait for the cue itself to lift
        await frames_until(s, func(): return Game._light_cue.is_empty())
        print("SMOKE sleep -> day:", Game.day == day_before + 1,
              " closed:", s.panel_mgr.top() == null,
              " morning:", Game.phase == Game.Phase.MORNING,
              " board marker:", s._board_tok != 0,
              " cue cleared:", Game._light_cue.is_empty())
        # UI-023: booking sheet opens -> close -> Head out -> evening
        s._open_booking()
        await s.get_tree().process_frame
        print("SMOKE booking sheet:", s.panel_mgr.top() is BookingBoard)
        s.panel_mgr.close()
        # §8.4 crew hut: day-2 auto-start put the crew on the warden's
        # hut — world chip up, tap opens the sheet, a forced-ready
        # stage flips the chip to "!" and collects into new dressing
        var sid: String = s._crew_sid()
        print("SMOKE crew hut:", s._hut != null,
              " engaged:", Game.crew.get("structure", "") == sid,
              " chip:", s._hut_tok != 0,
              " debris:", s._hut_dress.get_child_count() > 0)
        var hut_hit: bool = s._hut_tap(s._hut_px())
        await s.get_tree().process_frame
        print("SMOKE crew tap:", hut_hit,
              " sheet:", s.panel_mgr.top() is CrewSheet)
        s.panel_mgr.close()
        Game.crew["seconds_left"] = 0.0
        Game.crew_tick()
        s._sync_crew_hut()
        print("SMOKE crew ready chip:", s._hut_ready)
        var got := Game.crew_collect()
        await s.get_tree().process_frame
        print("SMOKE crew collect:",
              got.get("keepsake", "") == &"grandpas_thermos",
              " cleared:", s._hut_dress.get_child_count() == 0)
        # stage 1 = the crew lives there now — kitchen smoke wakes
        print("SMOKE hut smoke on:", s._amb != null and s._amb._smoke_on)
        # the keepsake ceremony is up now — tap through it so its light
        # cue can't leak into the prep-phase checks below
        for c in s._ceremony_layer.get_children():
            c._dismiss()
        await s.get_tree().process_frame
        # UI-034: the trail map — rows read site_card; whisper_river is
        # locked behind the pinewatch journal until it completes, then a
        # morning travel verb actually moves the sim site.  The scene
        # rebuild happens through Transition.to_scene on the real path —
        # smoke round-trips the sim instead so its own coroutine lives.
        var ms := TrailMapSheet.make()
        s.panel_mgr.open(ms)
        await s.get_tree().process_frame
        print("SMOKE map sheet:", s.panel_mgr.top() is TrailMapSheet,
              " river locked:", not Game.site_reachable(&"whisper_river"))
        s.panel_mgr.close()
        Game.site_state(&"pinewatch")["pages_done"] = [1, 2, 3, 4, 5]
        print("SMOKE travel:", Game.travel_to(&"whisper_river"),
              " site:", String(Game.site_id) == "whisper_river")
        Game.travel_to(&"pinewatch")         # round-trip home — scene
                                             # keeps its pinewatch world
        print("SMOKE travel back:",
              String(Game.site_id) == "pinewatch",
              " layout:", String(s.layout.get("site_id", ""))
                  == "pinewatch")
        s._advance_phase()
        await s.get_tree().process_frame
        # §7 prep: the day's middle — errand decals spawn, a gather
        # tap feeds the pantry, gear-gated spots hint instead of
        # silently failing, the stray takes its daily pet
        print("SMOKE prep phase:", Game.phase == Game.Phase.PREP,
              " errand nodes:", s._errand_nodes.size() > 0,
              " spots:", s._errand_anchors.size() == 2)
        var fn0: Dictionary = Game.site_state()["forage_nodes"][0]
        var nid0 := String(fn0["id"])
        var pan0 := Game.pantry_count()
        var gres: String = s._prep_tap(Vector2(fn0["px"][0], fn0["px"][1]))
        print("SMOKE gather:", gres == "gathered",
              " pantry grew:", Game.pantry_count() > pan0,
              " node faded:", not s._errand_nodes.has(nid0))
        var pp: Array = s.layout["errand_spots"]["pond"]
        print("SMOKE pond locked:",
              s._prep_tap(Vector2(pp[0], pp[1])) == "locked")
        var lp: Array = s.layout["errand_spots"]["lookout"]
        print("SMOKE lookout locked:",
              s._prep_tap(Vector2(lp[0], lp[1])) == "locked")
        print("SMOKE dog pet:", s._prep_tap(s._dog_pos) == "pet",
              " pet_today:", bool(Game.dog.get("pet_today", false)))
        # §9 rounds: the idle stray now walks his waypoint ring —
        # walking swaps in the directional still, arrival swaps back
        s._dog_walk(s._actor_map["dog"])
        await s.get_tree().create_timer(0.2).timeout
        print("SMOKE dog rounds:", s._dog_walking,
              " move still:", s._dog_move.visible)
        s._actor_map["dog"].position = s._dog_pos  # settle for the tap zone
        s._dog_move.visible = false
        s._dog_walking = false
        # §9 adoption: Friend-level bond -> naming sheet -> the flag
        # and the name persist via adopt_dog
        Game.dog["bond"] = 30
        s._check_dog_adoption()
        await s.get_tree().process_frame
        await s.get_tree().process_frame
        var ads: Control = s.panel_mgr.top()
        print("SMOKE adopt sheet:", ads is AdoptSheet)
        if ads is AdoptSheet:
            (ads as AdoptSheet).named.emit("Bean")
            s.panel_mgr.close()            # emit path bypasses _confirm
        print("SMOKE adopted:", Game.dog_adopted(),
              " name:", String(Game.dog.get("name", "")) == "Bean")
        # UI-035: pad flow — locked tap opens the row, Unlock pays and
        # swaps to Clear, the transform runs then clear_pad lands
        var st_pads: Dictionary = Game.site_state()["pads"]
        var plock := ""
        for p2 in s.pad_cells:
            if not st_pads[p2].get("open", false):
                plock = p2
                break
        Game.coins += 1600
        var pad_menu_ok: bool = s._prep_tap(
            s.pad_cells[plock].get_center()) == "pad"
        var mrow: Container = s.markers.marker_control(s._pad_menu_tok)\
            .get_child(0).get_child(0)
        print("SMOKE pad menu:", pad_menu_ok,
              " lock chip:", s._pad_chips.has(plock))
        mrow.get_child(0).emit_signal("pressed")   # Unlock · {p}c
        var paid_ok: bool = st_pads[plock].get("paid", false)
        mrow = s.markers.marker_control(s._pad_menu_tok)\
            .get_child(0).get_child(0)
        mrow.get_child(0).emit_signal("pressed")   # Clear -> transform
        await s.get_tree().create_timer(0.8).timeout
        var pad_open_now: bool = st_pads[plock].get("open", false)
        print("SMOKE pad unlock:", paid_ok,
              " cleared:", pad_open_now,
              " tuft freed:", s.pads_node.get_node_or_null(
                  "tuft_" + plock) == null)
        var pd_c: Array = Game.site_state()["pages_done"]
        if 2 not in pd_c:
            pd_c.append(2)                  # platform is the P2 offer
        s._prep_tap(s.pad_cells[plock].get_center())    # now: shelter row
        var srow: Container = s.markers.marker_control(s._pad_menu_tok)\
            .get_child(0).get_child(0)
        srow.get_child(0).emit_signal("pressed")    # Platform · 100c
        print("SMOKE pad shelter:",
              st_pads[plock].get("shelter", "bare") == "platform",
              " overlay:", s._pad_shelters.has(plock))
        # UI-033: build mode — buy arms a ghost, drops charge + place,
        # move/store roundtrip through the verbs, sprite follows sim
        Game.coins += 60
        var pd_b: Array = Game.site_state()["pages_done"]
        if 1 not in pd_b:
            pd_b.append(1)                  # stools/lantern are P1
        s._set_build(true)
        s._arm_build({"id": "stools", "kind": "buy", "idx": -1})
        var fc: Array = Game.decor_cells_free()
        var c0b: Vector2i = fc[0]
        var px_a: Vector2 = s._cell_px(c0b) + Vector2(s.CELL, s.CELL) / 2.0
        var res_a: String = s._build_tap(px_a)
        var st_dec: Array = Game.site_state()["decor"]
        print("SMOKE build place:", res_a == "placed",
              " decor:", st_dec.size() == 1,
              " sprite:", s._decor_nodes.size() == 1)
        s._disarm_build()
        var didx := st_dec.size() - 1
        var c1b: Vector2i = fc[fc.size() - 1]   # a different free cell
        s._arm_build({"id": "stools", "kind": "move", "idx": didx})
        var px_b: Vector2 = s._cell_px(c1b) + Vector2(s.CELL, s.CELL) / 2.0
        var res_b: String = s._build_tap(px_b)
        print("SMOKE decor move:", res_b == "placed",
              " moved:", st_dec[didx]["cells"][0] == c1b)
        s._arm_build({"id": "stools", "kind": "stored", "idx": -1})
        var res_c: String = s._build_tap(Vector2(8, 8))   # far corner: illegal
        print("SMOKE bad drop blocked:", res_c == "blocked")
        s._disarm_build()
        var ok_st := Game.store_decor(didx)
        s._sync_decor_world()
        print("SMOKE store:", ok_st,
              " stored:", Game.site_state()["stored"].size() == 1,
              " world cleared:", s._decor_nodes.is_empty())
        s._arm_build({"id": "stools", "kind": "stored", "idx": -1})
        var res_d: String = s._build_tap(px_a)
        print("SMOKE place_stored:", res_d == "placed",
              " decor again:", st_dec.size() == 1)
        s._disarm_build()
        s._set_build(false)
        s._advance_phase()
        await s.get_tree().process_frame
        print("SMOKE head out -> evening:",
              Game.phase == Game.Phase.EVENING,
              " tray:", s.hud.tray.visible,
              " marker cleared:", s._board_tok == 0,
              " errands cleared:", s._errand_layer == null)
    # UI-036: gear opens the §17.4 sheet; a toggle applies + persists
    s.hud.settings_pressed.emit()
    await frames_until(s, func(): return s.panel_mgr.top() != null)
    var ss: Control = s.panel_mgr.top()
    print("SMOKE settings sheet:", ss is SettingsSheet)
    if ss is SettingsSheet:
        var rm0: bool = UIFeel.reduced_motion
        Game.setting("reduced_motion", not rm0)
        print("SMOKE reduced_motion applied:",
              UIFeel.reduced_motion == (not rm0),
              " persisted:", bool(Game.settings["reduced_motion"])
              == (not rm0))
        Game.setting("reduced_motion", rm0)      # restore for later steps
        s.panel_mgr.close()
    # UI-032: the supply crate — sheet opens on the gear tab, a stamp
    # unlocks a staple, the buy lands in the pantry and charges coins
    s.hud.shop_pressed.emit()
    await frames_until(s, func(): return s.panel_mgr.top() != null)
    var os: Control = s.panel_mgr.top()
    print("SMOKE outfitter sheet:", os is OutfitterSheet)
    if os is OutfitterSheet:
        Game.coins += 5
        var pd: Array = Game.site_state()["pages_done"]
        if 1 not in pd:
            pd.append(1)                       # stamp p1: bread et al
        var pan_n := Game.pantry_count()
        var coins0 := Game.coins
        var bought := Game.buy_staple("bread")
        print("SMOKE buy staple:", bought,
              " pantry:", Game.pantry_count() == pan_n + 1,
              " charged:", Game.coins == coins0 - 5)
        os._tab = "staples"
        os._rebuild()
        await s.get_tree().process_frame
        print("SMOKE staples tab rows:",
              os._v.get_child_count() > 0)
        s.panel_mgr.close()
    # UI-030: journal button opens the §8.3 sheet; tabs switch; the
    # badge mirrors unread mail; days log gains a line per goodnight
    var badge0 := Game.unread_letters().size()
    print("SMOKE journal badge:", s.hud.journal_badge.text == (
        str(badge0) if badge0 > 0 else ""))
    s.hud.journal_pressed.emit()
    await frames_until(s, func(): return s.panel_mgr.top() != null)
    var js: Control = s.panel_mgr.top()
    print("SMOKE journal sheet:", js is JournalSheet)
    if js is JournalSheet:
        var comp := Game.journal_completion()
        print("SMOKE journal completion:",
              comp["done"] >= 0 and comp["total"] > 0)
        for tab in ["chapters", "letters", "days", "then_now"]:
            js._select_tab(tab)
            await s.get_tree().process_frame
        print("SMOKE journal tabs:",
              js._content.get_child_count() > 0)
        # the gate must have opened: a welcomed guest tonight means
        # mail exists for this site forever after (unconditional —
        # the read loop below can legitimately empty on old saves)
        print("SMOKE letter delivered:",
              not Game.letters_for().is_empty())
        # spec 005: opening a letter through the UI lights the warm
        # lamp cue; the back button puts it out
        js._select_tab("letters")
        await s.get_tree().process_frame
        var row_btns: Array = js._content.find_children(
            "", "Button", true, false)
        if not row_btns.is_empty():
            row_btns[0].pressed.emit()
            await s.get_tree().process_frame
            print("SMOKE letter cue:",
                  String(Game._light_cue.get("id", "")) == "letter")
            var back: Array = js._content.find_children(
                "", "Button", true, false)
            back[0].pressed.emit()
            await s.get_tree().process_frame
            print("SMOKE letter cue cleared:",
                  Game._light_cue.is_empty())
        # D3.4: the days tab pins the Trail Daily card — locked pre-p06
        # it still names the road; the letter flips it to a live entry
        js._select_tab("days")
        await s.get_tree().process_frame
        var drows: Array = js._content.find_children(
            "", "Button", true, false)
        print("SMOKE daily card:", not drows.is_empty())
        print("SMOKE daily locked:", not Game.daily_unlocked())
        if not drows.is_empty():
            drows[0].pressed.emit()
            await frames_until(s, 
                func(): return s.panel_mgr.top() != null)
            var ds: Control = s.panel_mgr.top()
            print("SMOKE daily sheet:", ds is DailySheet)
            s.panel_mgr.close()
            await s.get_tree().process_frame
            Game.site_state(&"pinewatch")[
                "letters_delivered"].append("p06")
            js._select_tab("days")
            await s.get_tree().process_frame
            var dl: Array = js._content.find_children(
                "", "Label", true, false)
            print("SMOKE daily unlocked row:", dl.any(
                func(l): return l.text == s.tr("daily_open")))
            drows = js._content.find_children(
                "", "Button", true, false)
            drows[0].pressed.emit()
            await frames_until(s, 
                func(): return s.panel_mgr.top() != null)
            print("SMOKE daily board:",
                  s.panel_mgr.top() is DailySheet)
            s.panel_mgr.close()
            await s.get_tree().process_frame
        # read every staged unread letter — mornings deliver one each,
        # so the run can carry more than one
        var unread := Game.unread_letters()
        for l in unread:
            Game.read_letter(l["id"])
        if not unread.is_empty():
            print("SMOKE letter read:",
                  unread.all(func(l): return l["id"] in Game.letters_read))
        s.panel_mgr.close()
        await s.get_tree().process_frame
        print("SMOKE badge cleared:",
              s.hud.journal_badge.text == "")
    # spec 004: fusion tier — kind-compatible unknown pairs improvise;
    # incompatible kinds still fall to Camp Mash; fusions stay out of
    # the cookbook (recipes_cooked) but do log in pairs_tried
    for k in {"perch": 1, "bread": 1, "mushroom": 1,
            "berries": 1, "rice": 1, "coffee": 1}:
        Game.pantry[k] = int(Game.pantry.get(k, 0)) + 1
    var f1 := Game.cook("perch", "bread")     # fish+staple -> fry-up
    var f2 := Game.cook("mushroom", "berries")# forage+forage -> mix
    var f3 := Game.cook("rice", "coffee")     # staple+staple -> mash
    print("SMOKE fusion fry-up:",
          f1.get("recipe") == "improv_fryup",
          " mix:", f2.get("recipe") == "foragers_mix",
          " mash still:", f3.get("recipe") == "camp_mash")
    print("SMOKE fusion not in book:",
          "improv_fryup" not in Game.recipes_cooked,
          " tried-logged:",
          Game.pairs_tried.get("bread+perch") == "improv_fryup")
    # commit-on-beat persistence: a verb marks dirty, the 1s tick or
    # commit() flushes it — sleep is never the checkpoint (D-UI-8)
    var sav_before := FileAccess.get_modified_time(
        "user://savegame.json") \
        if FileAccess.file_exists("user://savegame.json") else 0
    Game.touch()
    print("SMOKE save verb marks dirty:", Game._save_dirty)
    Game.commit()
    var sav_after := FileAccess.get_modified_time("user://savegame.json")
    print("SMOKE save commit writes:",
          not Game._save_dirty and sav_after >= sav_before)
    s.get_tree().quit()


## Poll a condition each frame (cap ~4s) — tween timing varies headless.
