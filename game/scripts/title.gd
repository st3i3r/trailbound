extends Control
## Title screen (UI-011 app shell) — Eastward-style: the camp vista
## dimmed behind a deep-forest scrim, display-type logotype, and a
## glass menu column.  Continue gates on a real save file; Back quits
## straight from Title (the confirm sheet is Camp-only, §17.6).
##
## The vista is the live camp render captured HUD-free by the test
## scene (--bare --shot) — assets/pinewatch/ui/title_vista.png.

const CAMP_SCENE := "res://scenes/pinewatch_test.tscn"
const VISTA := "res://assets/pinewatch/ui/title_vista.png"

var _first_button: Button


func _ready() -> void:
    theme = UITheme.theme()
    # the .tscn root anchors full-rect — it resizes with the viewport
    # on its own (unlike CanvasLayer children, which size manually)
    Game.set_phase(Game.Phase.TITLE)
    Platform.back_pressed.connect(get_tree().quit)
    _build()
    Transition.reveal()
    _first_button.grab_focus()
    if OS.get_cmdline_args().has("--smoke"):
        Transition.snap_reveal()
        await get_tree().process_frame
        # hand off to the camp scene — it runs its own --smoke suite,
        # which is itself the proof the router landed (this node dies
        # mid-swap, so the destination makes the assertion)
        print("SMOKE title: boot ok, routing -> ", CAMP_SCENE)
        _to_camp()
        return
    if OS.get_cmdline_args().has("--shot"):
        Transition.snap_reveal()
        await get_tree().process_frame
        await get_tree().process_frame
        var img := get_viewport().get_texture().get_image()
        var err := img.save_png(
            "D:/monet/trail-bound/assets_src/cleanup/title_screen.png")
        print("title shot err:", err)
        get_tree().quit()
    if OS.get_cmdline_args().has("--quit"):
        Transition.snap_reveal()
        await get_tree().process_frame
        get_tree().quit()


func _build() -> void:
    # ------------------------------------------------ backdrop + scrim
    var vista := TextureRect.new()
    vista.name = "Vista"
    vista.texture = load(VISTA)
    vista.set_anchors_preset(Control.PRESET_FULL_RECT)
    vista.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    vista.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    vista.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(vista)

    var scrim := ColorRect.new()
    scrim.name = "Scrim"
    scrim.color = Color(0.07, 0.09, 0.05, 0.52)
    scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
    scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(scrim)

    # ------------------------------------------------ logotype block
    var logo := VBoxContainer.new()
    logo.name = "Logo"
    logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
    logo.offset_left = -160
    logo.offset_right = 160
    logo.offset_top = 46
    logo.offset_bottom = 110
    logo.alignment = BoxContainer.ALIGNMENT_CENTER
    logo.add_theme_constant_override("separation", UITokens.SP1)
    add_child(logo)

    var name_l := UIKit.label_for(tr("title").to_upper(),
        UITokens.TypeRole.DISPLAY, UITokens.PAPER)
    name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_l.add_theme_constant_override("font_spacing", 4)
    logo.add_child(name_l)

    var rule := ColorRect.new()
    rule.color = UITokens.GOLD
    rule.custom_minimum_size = Vector2(0, 1)
    rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    logo.add_child(rule)

    var tag_l := UIKit.label_for(tr("title_tag"),
        UITokens.TypeRole.CAPTION, UITokens.DIM)
    tag_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    logo.add_child(tag_l)

    # ------------------------------------------------ menu column
    var menu := VBoxContainer.new()
    menu.name = "Menu"
    # centred under the logo: 4 rows of 40px + 3 gaps needs 188 —
    # pinned so the last button clears the bottom edge (360 - 16)
    menu.set_anchors_preset(Control.PRESET_CENTER_TOP)
    menu.offset_left = -76
    menu.offset_right = 76
    menu.offset_top = 150
    menu.offset_bottom = 150 + 4 * (UITokens.MIN_TOUCH + UITokens.SP2)
    menu.alignment = BoxContainer.ALIGNMENT_CENTER
    menu.add_theme_constant_override("separation", UITokens.SP2)
    add_child(menu)

    var cont := _menu_btn(menu, tr("menu_continue"), "gold")
    cont.disabled = not Save.has_save()
    # save-load flow lands with the save-integration pass — for now
    # Continue boots the camp the same as New Game
    cont.pressed.connect(_to_camp)
    _first_button = cont if not cont.disabled else null

    var new_g := _menu_btn(menu, tr("menu_new_game"), "pill")
    new_g.pressed.connect(_to_camp)
    if _first_button == null:
        _first_button = new_g

    var settings := _menu_btn(menu, tr("menu_settings"), "pill")
    settings.disabled = true                     # settings sheet: P3

    var exit := _menu_btn(menu, tr("menu_exit"), "pill")
    exit.pressed.connect(get_tree().quit)

    # ------------------------------------------------ version stamp
    var ver := UIKit.label_for("v%s" % ProjectSettings.get_setting(
        "application/config/version", "0.0.0"),
        UITokens.TypeRole.CAPTION, UITokens.DIM)
    ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    ver.offset_left = -(UITokens.MARGIN + 60)
    ver.offset_top = -(UITokens.MARGIN + 10)
    ver.offset_right = -UITokens.MARGIN
    ver.offset_bottom = -UITokens.MARGIN
    ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    add_child(ver)


func _menu_btn(parent: Control, text: String, kind: String) -> Button:
    return UIKit.btn(parent, Vector2(152, UITokens.MIN_TOUCH), text,
        kind, Control.SIZE_SHRINK_CENTER)


func _to_camp() -> void:
    Transition.to_scene(CAMP_SCENE)
