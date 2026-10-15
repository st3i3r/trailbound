extends RefCounted
## WorldBuilder — static world construction (§5.1/§11/§16).
## SOTA split (D-ARCH-9): the scene owns live nodes + texture
## primitives (`_tex`, `_anchored`, `_cell_mask`, `_painted_map`,
## `_shadow_texture`); this owns the six build passes + the
## shadow/embed helpers. Scene passed as untyped `s`; the only
## local renamed is _add_shadow's sprite (`s` -> `sh`).


var s  # the pinewatch_test scene (untyped: mutual ref)


func _init(scene) -> void:
    s = scene


## True when the site ships a PixelLab object layer — authored art owns
## static props, so runtime sprite stand-ins stay hidden. Local twin of
## the scene's helper so this file never depends on in-flight scene work.
func painted_map() -> bool:
    return FileAccess.file_exists(
        "res://assets/%s/objects.json" % s._site_id)


func build_ground() -> void:
    ## The whole painted map render as one sprite — zones, transitions
    ## and shore rims are baked art; gameplay reads MASK instead.
    ## Sites without a baked render fall back to the mask drawn flat
    ## (UI-034 v1 dressing — a painted map replaces it when art lands).
    if s._site_id == "pinewatch":
        var gs := Sprite2D.new()
        # importer writes this PNG; a non-editor launch can serve a
        # stale ctex (no filesystem rescan) — load the file directly
        var gi := Image.load_from_file(ProjectSettings.globalize_path(
            "res://assets/pinewatch/fx/ground_sunlit.png"))
        gs.texture = ImageTexture.create_from_image(gi) \
            if gi != null else s._tex("fx/ground_sunlit")
        gs.centered = false
        s.ground = gs
        print("ground: sunlit variant (fx/ground_sunlit)")
    else:
        var gp := GroundPaint.new()
        gp.mask = s._mask
        gp.t = s.T
        s.ground = gp
        print("ground: procedural mask render (v1 dressing)")
    s.ground.name = "Ground"
    s.stage.add_child(s.ground)


func open_cell(px: float, py: float, want: int) -> bool:
    ## Scatter placement guard: the point must sit on terrain `want`
    ## (0 grass / 1 forest) and outside every pad rect — keeps decals
    ## off pond/path/pads exactly like the old _open_grass did.
    var tx: int = int(px / s.T)
    var ty: int = int(py / s.T)
    if tx < 0 or tx >= s.GW or ty < 0 or ty >= s.GH:
        return false
    if s._cell_mask(Vector2i(tx, ty)) != want:
        return false
    for r in s.pad_cells.values():
        if r.has_point(Vector2(px, py)):
            return false
    return true


func build_backdrop() -> void:
    ## Depth band over the top forest strip: pale sky fading into the
    ## dirt, then rows of darkened pines standing in front of it.  Added
    ## right after Ground so it paints above the (fully opaque) tiles —
    ## below them it could never be seen — and below everything else.
    var bd := Node2D.new()
    bd.name = "Backdrop"
    s.stage.add_child(bd)
    # overscan: the map is 640x384 but tall/wide viewports expand past
    # it — paint past both edges so the margin reads as the forest
    # continuing (deep canopy above, shadowed ground below), not void
    var ovs_top := Polygon2D.new()
    ovs_top.polygon = PackedVector2Array([
        Vector2(-80, -80), Vector2(s.GW * s.T + 80, -80),
        Vector2(s.GW * s.T + 80, 4), Vector2(-80, 4)])
    ovs_top.color = s.OVR_TOP
    bd.add_child(ovs_top)
    var ovs_bot := Polygon2D.new()
    ovs_bot.polygon = PackedVector2Array([
        Vector2(-80, s.GH * s.T - 2), Vector2(s.GW * s.T + 80, s.GH * s.T - 2),
        Vector2(s.GW * s.T + 80, s.GH * s.T + 80), Vector2(-80, s.GH * s.T + 80)])
    ovs_bot.vertex_colors = PackedColorArray(
        [s.OVR_BOT, s.OVR_BOT, s.OVR_DEEP, s.OVR_DEEP])
    bd.add_child(ovs_bot)
    # thin sky sliver first — Eastward forest edges are CANOPY, not
    # open sky; only a pale line peeks above the far tree mass.
    # Painted maps carry their own authored canopy and trees (the
    # PixelLab object layer) — sky sliver and procedural treeline
    # over them would wash/double-draw, so both stay fallback-only.
    var painted: bool = painted_map()
    if not painted:
        var sky := Polygon2D.new()
        sky.polygon = PackedVector2Array([
            Vector2(0, 0), Vector2(s.GW * s.T, 0),
            Vector2(s.GW * s.T, s.SKY_H), Vector2(0, s.SKY_H)])
        sky.vertex_colors = PackedColorArray(
            [s.SKY_TOP, s.SKY_TOP, s.SKY_BOT, s.SKY_BOT])
        bd.add_child(sky)
    var rows: Array = [] if painted else [
        {"y": 46.0,  "dx": 52.0,  "x0": -30.0, "tint": s.TREE_FAR,  "s": 0.42},
        {"y": 58.0,  "dx": 60.0,  "x0": 8.0,   "tint": s.TREE_MID,  "s": 0.50},
        {"y": 70.0,  "dx": 66.0,  "x0": -14.0, "tint": s.TREE_NEAR, "s": 0.58},
    ]
    var k := 0
    for r in rows:
        var x: float = r["x0"]
        while x < s.GW * s.T + 40.0:
            var t: Sprite2D = s._anchored("props_large", "tree_broadleaf",
                               Vector2(x, r["y"]))
            t.scale = Vector2(r["s"], r["s"])
            t.modulate = r["tint"]
            bd.add_child(t)
            x += r["dx"] * (0.85 + 0.3 * ((k * 7) % 3) / 2.0)
            k += 1


func build_scatter(rng: RandomNumberGenerator) -> void:
    s.scatter = Node2D.new()
    s.scatter.name = "Scatter"
    s.stage.add_child(s.scatter)
    # edge-clustered decals (ground recipe): DECAL_CLUSTERS is a fixed
    # list — one family per cluster, only at prop bases / shoreline /
    # treeline feet; the open-field interior stays empty because the
    # GroundTint overlay carries macro variation now.  pad_cells is
    # filled from the layout here because _build_pads only runs after us.
    if s.pad_cells.is_empty():
        var spots: Dictionary = s.layout["pads"]["spots"]
        for pid in spots:
            var c: Array = spots[pid]
            s.pad_cells[pid] = Rect2(s.origin + Vector2(c[0], c[1]) * s.CELL,
                                   Vector2(s.CELL, s.CELL))
    var placed := 0
    for spec in s.DECAL_CLUSTERS:
        var ctr := Vector2(spec[0], spec[1])
        var fam: Array = s.DECAL_FAMILIES[spec[2]]
        var want: int = spec[6]
        for i in int(spec[3]):
            # triangular offset -> denser near the centre, soft edges
            var p: Vector2 = ctr + Vector2(
                (rng.randf() + rng.randf() - 1.0) * spec[4],
                (rng.randf() + rng.randf() - 1.0) * spec[5])
            if open_cell(p.x, p.y, want):
                var d: Sprite2D = s._anchored("decals",
                                   fam[rng.randi() % fam.size()], p)
                d.modulate = s.DECAL_GROUND      # sit IN the ground wash
                s.scatter.add_child(d)
                placed += 1
    print("scatter decals: %d (%d edge clusters)"
          % [placed, s.DECAL_CLUSTERS.size()])


func build_pads(rng: RandomNumberGenerator) -> void:
    var spots: Dictionary = s.layout["pads"]["spots"]
    var open_pads: Array = s.layout["pads"]["open"]
    for pid in spots:
        var c: Array = spots[pid]
        var rect: Rect2 = Rect2(s.origin + Vector2(c[0], c[1]) * s.CELL,
                          Vector2(s.CELL, s.CELL))
        s.pad_cells[pid] = rect
        # Batch H: real ground under the bracket — an overgrown
        # weed plot while locked (the clear scatter eats it),
        # packed pitch earth once open.  Drawn BEFORE the marker
        # so the brackets stay legible on top.
        var g := Sprite2D.new()
        g.name = "ground_" + pid
        g.centered = false
        g.texture = s._tex("decals/pad_cleared" if pid in open_pads
            else "decals/" + s.PAD_OVERGROWN[
                hash(pid) % s.PAD_OVERGROWN.size()])
        g.position = rect.position
        var gw := float(g.texture.get_width())
        var gs: float = minf(1.0, s.CELL * 1.1 / gw)
        g.scale = Vector2.ONE * gs
        g.set_meta("s0", gs)
        s.pads_node.add_child(g)
        var m := Sprite2D.new()
        m.texture = s._tex("pad_open" if pid in open_pads else "pad_locked")
        m.centered = false
        m.name = "mark_" + pid
        m.position = rect.position
        s.pads_node.add_child(m)
        if not (pid in open_pads):
            var tuft: Sprite2D = s._anchored("decals", "tuft_grass_dry",
                rect.position + Vector2(8 + rng.randi() % 40,
                                        8 + rng.randi() % 40))
            tuft.name = "tuft_" + pid        # clear transform frees it
            s.pads_node.add_child(tuft)
    for pid in s.pad_cells:
        s._sync_pad_visual(pid)                # loaded saves: shelters


## PixelLab object layer (map import). Each entry becomes a Node2D
## anchored at its collider's bottom-centre — that foot point is what
## `world` y-sorts on, so actors pass in front of/behind props
## correctly. Children are added in authored drawOrder so equal-foot-y
## ties keep the editor's layering. Sites without an objects manifest
## (lantern_valley, whisper_river) simply skip.


func build_objects() -> void:
    var mpath: String = "res://assets/%s/objects.json" % s._site_id
    if not FileAccess.file_exists(mpath):
        return
    var list: Variant = JSON.parse_string(
        FileAccess.get_file_as_string(mpath))
    if not list is Array:
        return
    for o in list:
        # Image.load_from_file over load(): importer-copied PNGs carry
        # no .import metadata until the editor next scans the project
        var img := Image.load_from_file(ProjectSettings.globalize_path(
            "res://assets/%s/objects/%s" % [s._site_id, o["img"]]))
        if img == null:
            continue
        var tex := ImageTexture.create_from_image(img)
        var anchor := Node2D.new()
        anchor.position = Vector2(o["foot"][0], o["foot"][1])
        var spr: Sprite2D = Sprite2D.new()
        spr.texture = tex
        spr.centered = false
        spr.position = Vector2(o["x"], o["y"]) - anchor.position
        anchor.add_child(spr)
        s.world.add_child(anchor)


func build_props() -> void:
    var erng := RandomNumberGenerator.new()
    erng.seed = 23                     # embed jitter — fixed so the
                                       # sticker-kill is reproducible
    for p in s._props:
        var spr: Sprite2D = s._anchored(p[0], p[1], Vector2(p[2], p[3]))
        if p.size() > 4:               # organic lean on loose props
            spr.rotation_degrees = p[4]
        var sc: float = (p[5] if p.size() > 5 else 1.0) * s.WORLD_SCALE
        spr.scale = Vector2(sc, sc)
        s.world.add_child(spr)
        if p[0] == "props_large" and p[1] == "cabin":
            s._hut = spr                     # crew structure anchor (§8.4)
            spr.visible = not painted_map()   # authored house draws it
        if p[1] in s.FADEABLE:
            # fade zone = the tall art minus its footing strip —
            # an actor whose anchor lands inside is behind the prop
            var sz: Vector2 = spr.texture.get_size() * sc
            s.fade_zones.append({"s": spr, "r": Rect2(
                Vector2(p[2] - sz.x / 2.0, p[3] - sz.y),
                Vector2(sz.x, sz.y - 14.0))})
        embed_base(p, erng)
        add_shadow(p)


## Phase 5.0+5.3 — canopy/contact shadow pools. Green-brown radial
## pools centred on each prop's footprint, sun upper-left so the
## pool reads centred with a slight +X bias. Water/ground items
## and flat-lying pieces get none.


func add_shadow(p: Array) -> void:
    if p[0] in ["terrain", "decals"] or p[1] in s.SHADOW_SKIP:
        return
    var e: Dictionary = s.anchors.get(p[0] + "/" + p[1] + ".png", {})
    var tex: Texture2D = s._tex(p[0] + "/" + p[1])
    var c: Array = e.get("content",
        [0, 0, tex.get_width(), tex.get_height()])
    var sc: float = (p[5] if p.size() > 5 else 1.0) * s.WORLD_SCALE
    var ax: float = e.get("anchor_x", tex.get_width() / 2.0)
    var fw: float = (c[2] - c[0]) * sc * 1.15
    var fh: float = clamp(fw * 0.30, 8.0, 36.0)
    var cx: float = p[2] - ax * sc + (c[0] + c[2]) * 0.5 * sc
    var sh := Sprite2D.new()
    sh.texture = s._shadow_texture()
    sh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    sh.scale = Vector2(fw / 128.0, fh / 64.0)
    sh.position = Vector2(cx + 3.0, p[3] - 2.0)
    s.shadows.add_child(sh)


func embed_base(p: Array, rng: RandomNumberGenerator) -> void:
    if p[1] in s.EMBED_SKIP:
        return
    var e: Dictionary = s.anchors.get(p[0] + "/" + p[1] + ".png", {})
    var tex: Texture2D = s._tex(p[0] + "/" + p[1])
    var ax: float = e.get("anchor_x", tex.get_width() / 2.0)
    var ay: float = e.get("anchor_y", float(tex.get_height()))
    var c: Array = e.get("content",
        [0, 0, tex.get_width(), tex.get_height()])
    var sc: float = (p[5] if p.size() > 5 else 1.0) * s.WORLD_SCALE
    # prop footprint in world px (content box, not the whole canvas)
    var fx0: float = p[2] - ax * sc + c[0] * sc
    var fx1: float = p[2] - ax * sc + c[2] * sc
    var ch: float = (c[3] - c[1]) * sc
    var overlap: float = clamp(ch * 0.11, 3.0, 7.0)
    for i in 1 + rng.randi() % 3:
        var pos := Vector2(
            lerpf(fx0, fx1, 0.2 + 0.6 * rng.randf()),
            p[3] + max(1.0, 8.0 - overlap + rng.randf() * 2.0 - 1.0))
        # pos must clear the prop's own anchor y (sorts in front) and
        # land on turf — gravel pebbles allowed on the path edge, never
        # on pond / pads
        var want: int = s._cell_mask(Vector2i(int(pos.x) / s.T, int(pos.y) / s.T))
        if want == 2:
            continue
        var on_pad := false
        for r in s.pad_cells.values():
            if r.has_point(pos):
                on_pad = true
                break
        if on_pad:
            continue
        var fam_name := "tuft" if want == 0 else \
            "litter" if want == 1 else "pebble"
        var fam: Array = s.DECAL_FAMILIES[fam_name]
        s.world.add_child(s._anchored("decals",
                                  fam[rng.randi() % fam.size()], pos))


class GroundPaint:
    extends Node2D

    var mask: Array = []
    var t := 32.0

    const PAL := {"G": Color(0.42, 0.55, 0.34),
                  "D": Color(0.58, 0.47, 0.31),
                  "W": Color(0.28, 0.44, 0.50)}

    func _draw() -> void:
        var rng := RandomNumberGenerator.new()
        rng.seed = 41
        for y in mask.size():
            var row := String(mask[y])
            for x in row.length():
                var c: Color = PAL.get(row[x], PAL["G"])
                c = c.lightened(rng.randf_range(-0.035, 0.035))
                draw_rect(Rect2(x * t, y * t, t, t), c, true)
                # water reads a bank edge on its north rim
                if row[x] == "W" and (y == 0
                        or String(mask[y - 1])[x] != "W"):
                    draw_rect(Rect2(x * t, y * t, t, 5.0),
                        Color(0.15, 0.22, 0.20, 0.55), true)


