extends RefCounted
## CrewPresenter — crew structure + hut visuals (§8.4/UI-035).
## SOTA split (D-ARCH-9/10/11/12/13/14/15/16/17): the scene owns the
## frame tick, the hut node itself and its token state (`_hut_tok`,
## `_hut_ready`); this owns the crew queries and the state->view
## pass — stage art swap, porch glow, the "!" affordance chip.
## Scene passed as untyped `s`. Cross-presenter callers reach the
## scene delegates, which forward here.


const HUT_STAGES := ["cabin_s0", "cabin_s1", "cabin_s2", "cabin"]


var s  # the pinewatch_test scene (untyped: mutual ref)

var _hut_tok := 0


func _init(scene) -> void:
    s = scene


## The site's active structure id, from its crew plots (§8.4).
func crew_sid() -> String:
    var plots: Array = s.layout.get("crew_plots", [])
    for p in plots:
        if p.get("kind") == "structure":
            return String(p.get("structure", ""))
    return ""


## The structure row — {} when the id is unknown.
func crew_rows(sid: String) -> Dictionary:
    for r in Catalog.data.get("crew", {}).get("structures", []):
        if r.get("id") == sid:
            return r
    return {}


## Keepsakes already collected.  crew["stage"] only describes the
## ACTIVE structure; collected[] is the durable record.
func crew_stage(sid: String) -> int:
    var n: int = 0
    var got: Array = Game.crew.get("collected", [])
    for st in crew_rows(sid).get("stages", []):
        if got.has(st.get("keepsake", {}).get("id", "")):
            n += 1
    return n


## The hut's anchor — the same query the input presenter uses for
## its tap routing, so both views agree on where the hut sits.
func hut_px() -> Vector2:
    var plots: Array = s.layout.get("crew_plots", [])
    for p in plots:
        if p.get("kind") == "structure" and p.has("px"):
            return Vector2(p["px"][0], p["px"][1])
    return s._hut.position if s._hut != null else Vector2.ZERO


## The hut is anonymous scenery until the crew engages (day-2 start
## or any collected stage) — a "!" on a ruin the player was never
## told about reads as a bug, not a mystery.
func hut_engaged() -> bool:
    var sid: String = crew_sid()
    return sid != "" and (Game.crew.get("structure", "") == sid
        or crew_stage(sid) > 0)


## Idempotent state->view pass: debris + dim by stage, porch glow
## once restored (evening/night only), chip by work state.  The
## token state (`_hut_tok`, `_hut_ready`) stays on the scene so the
## smoke harness reads it directly.  animate=true on collect so the
## cleared stage visibly scatters before the rebuild.
func sync_crew_hut(animate := false) -> void:
    var sid: String = crew_sid()
    if s._hut == null or sid == "":
        return
    var stage: int = crew_stage(sid)
    var total: int = crew_rows(sid).get("stages", []).size()
    var restored: bool = total > 0 and stage >= total
    if s._amb != null:                      # kitchen smoke = crew
        s._amb.set_smoke(stage > 0)       # living/working in it
    # stage art swap (Batch H): the sprite itself carries the state —
    # ruin -> cleared -> roof fixed -> restored cabin.  A lit-window
    # night variant lands at dusk once the hut is whole again.
    # Painted maps: the authored house is the visual; no sprite swaps.
    var painted: bool = s._painted_map()
    if not painted:
        var day_tex: String = HUT_STAGES[
            mini(stage, HUT_STAGES.size() - 1)]
        var want: String = String(day_tex)
        if restored and Game.phase in [Game.Phase.EVENING,
                Game.Phase.NIGHT] and ResourceLoader.exists(
                s.A + "props_large/cabin_night.png"):
            want = "cabin_night"
        if ResourceLoader.exists(
                s.A + "props_large/%s.png" % want):
            s._hut.texture = s._tex("props_large/" + want)
    if s._hut_dress != null:
        var old: Node2D = s._hut_dress
        s._hut_dress = null
        if animate and not UIFeel.reduced_motion:
            var tw: Tween = old.create_tween().set_parallel()
            for c in old.get_children():
                tw.tween_property(c, "position",
                    c.position + Vector2(randf_range(-26.0, 26.0),
                        randf_range(4.0, 14.0)), 0.55) \
                    .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
                tw.tween_property(c, "modulate:a", 0.0, 0.55)
            tw.chain().tween_callback(old.queue_free)
        else:
            old.queue_free()
    s._hut_dress = Node2D.new()
    s._hut_dress.name = "CrewDress"
    s._hut_dress.position = hut_px()      # sorts with the hut itself
    s.world.add_child(s._hut_dress)
    s._hut.modulate = Color.WHITE       # sprite carries state
    if stage == 0 and not painted:
        # ruin reads through the litter on its footprint
        for spec in [["props_medium", "debris_brambles", -26, 8],
                ["props_medium", "debris_branch_pile", 20, 12],
                ["props_medium", "debris_brambles", 4, 18]]:
            var d: Node2D = s._anchored(spec[0], spec[1],
                Vector2(spec[2], spec[3]))
            s._hut_dress.add_child(d)
    elif restored:
        # the porch light: a small lantern by the door, warm pool
        var lamp: Node2D = s._anchored(
            "props_medium", "lantern_post", Vector2(34, 14))
        s._hut_dress.add_child(lamp)
        var glow: Node2D = Node2D.new()
        glow.texture = s._shadow_texture()
        glow.modulate = Color(0.95, 0.78, 0.42, 0.55)
        glow.position = Vector2(30, 16)
        glow.scale = Vector2(0.9, 0.5)
        glow.visible = Game.phase in [Game.Phase.EVENING,
            Game.Phase.NIGHT]
        s._hut_dress.add_child(glow)
    # --- affordance chip: "!" while a stage waits on the player
    var show: bool = hut_engaged() and not restored
    var ready: bool = show and Game.crew.get("structure", "") == sid \
        and Game.is_stage_ready()
    s._hut_ready = ready
    if show:
        var content: Control
        if ready:
            var bang: Control = UIKit.label_for(
                "!", UITokens.TypeRole.HEAD, UITokens.GOLD)
            bang.position = Vector2(6, -2)
            content = bang
        else:
            content = UIKit.icon_rect("crew", UITokens.DIM, 12)
            content.position = Vector2(3, 3)
        var pair: Array = s.markers.icon_chip(
            s._hut, content, Vector2(0, -88))
        if s._hut_tok:
            s.markers.release(s._hut_tok)
        s._hut_tok = int(pair[0])
    elif s._hut_tok:
        s.markers.release(s._hut_tok)
        s._hut_tok = 0
