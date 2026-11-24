class_name MainMenu
extends Control
## MainMenu - Continue / New Game / Settings / Credits. Code-built UI in the
## LvgTheme language (no scene dependency - the .tscn just attaches this).

var _v: VBoxContainer
var _title: Label
var _tagline: Label
var _panel: PanelContainer
var _settings_open := false


func _ready() -> void:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        _build()
        _build_entry_fade()
        InputRouter.ui_blocking = true
        InputRouter.set_context(InputRouter.Context.MENU)
        EventBus.music_layer_requested.emit("menu")


## Cinematic menu entry: fade in from black (boot->menu and world->menu).
func _build_entry_fade() -> void:
        var veil := ColorRect.new()
        veil.name = "EntryFade"
        veil.color = Color(0, 0, 0, 1)
        veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
        veil.set_anchors_preset(Control.PRESET_FULL_RECT)
        add_child(veil)
        var tw := create_tween()
        tw.tween_property(veil, "color:a", 0.0, 0.4).set_ease(Tween.EASE_OUT)


func _build() -> void:
        var bg_path := "res://assets/ui/keyart/menu_bg_0.png"
        if ResourceLoader.exists(bg_path):
                var bg := TextureRect.new()
                bg.texture = load(bg_path)
                bg.set_anchors_preset(Control.PRESET_FULL_RECT)
                bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
                bg.modulate = Color(1, 1, 1, 0.9)
                add_child(bg)
                var scrim := ColorRect.new()
                scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
                scrim.color = Color(0.02, 0.02, 0.04, 0.42)
                add_child(scrim)
        add_child(LvgTheme.color_rect(LvgTheme.CHARCOAL))
        # faint city silhouette strip
        var strip := Control.new()
        strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        strip.custom_minimum_size = Vector2(0, 260)
        strip.draw.connect(func():
                var rng := RandomNumberGenerator.new()
                rng.seed = 77
                var x := 0.0
                while x < 2688.0:
                        var w: float = rng.randf_range(60, 180)
                        var h: float = rng.randf_range(60, 230)
                        strip.draw_rect(Rect2(x, 260.0 - h, w, h), Color("101114"))
                        if rng.randf() < 0.5:
                                strip.draw_rect(Rect2(x + w * 0.25, 260.0 - h + 18, w * 0.12, 26), Color("f0a33c") if rng.randf() < 0.25 else Color("2a2d34"))
                        x += w + rng.randf_range(4, 30)
        )
        add_child(strip)
        _title = LvgTheme.make_display_label("LEVERAGE", 190, LvgTheme.ACCENT)
        _title.position = Vector2(180, 150)
        add_child(_title)
        var rule := Control.new()
        rule.position = Vector2(190, 420)
        rule.custom_minimum_size = Vector2(700, 4)
        rule.draw.connect(func():
                rule.draw_rect(Rect2(0, 0, 700, 4), LvgTheme.ACCENT_DEEP)
                rule.draw_rect(Rect2(280, 0, 140, 4), LvgTheme.ACCENT))
        add_child(rule)
        _tagline = LvgTheme.make_label("EVERYONE HAS LEVERAGE ON YOU.", 36, LvgTheme.TEXT)
        _tagline.position = Vector2(192, 445)
        add_child(_tagline)

        _panel = LvgTheme.make_panel()
        _panel.position = Vector2(180, 620)
        add_child(_panel)
        _v = VBoxContainer.new()
        _v.add_theme_constant_override("separation", 14)
        _panel.add_child(_v)
        _add_menu_buttons()


func _add_menu_buttons() -> void:
        for c in _v.get_children():
                c.queue_free()
        var has_save: bool = SaveSystem.has_any_save()
        if has_save:
                var cont := LvgTheme.make_button("CONTINUE")
                cont.pressed.connect(func(): _continue())
                _v.add_child(cont)
        var ng := LvgTheme.make_button("NEW GAME")
        ng.pressed.connect(func(): _new_game())
        _v.add_child(ng)
        var st := LvgTheme.make_button("SETTINGS")
        st.pressed.connect(func(): _toggle_settings())
        _v.add_child(st)
        var cr := LvgTheme.make_button("CREDITS")
        cr.pressed.connect(func(): _show_credits())
        _v.add_child(cr)
        var ver := LvgTheme.make_label("v2.5.0  |  DE YOUNG GAMES  |  Mobile renderer, XOGOT-ready", 20, LvgTheme.TEXT_DIM)
        _v.add_child(ver)


func _input(event: InputEvent) -> void:
        if event.is_action_pressed("pause"):
                pass


func _new_game() -> void:
        _start(true)


func _continue() -> void:
        # best slot: newest autosave/manual
        var slot := 0
        for s in [0, 3, 2, 1]:
                if SaveSystem.slot_exists(s):
                        slot = s
                        break
        _start(false, slot)


func _start(fresh: bool, slot := 0) -> void:
        InputRouter.ui_blocking = false
        if fresh:
                GameManager.start_new_game()
        else:
                if not GameManager.continue_game(slot):
                        GameManager.start_new_game()


func _toggle_settings() -> void:
        _settings_open = not _settings_open
        for c in _v.get_children():
                c.queue_free()
        if not _settings_open:
                _add_menu_buttons()
                return
        _build_settings()


func _build_settings() -> void:
        var title := LvgTheme.make_kicker("SETTINGS", LvgTheme.ACCENT)
        _v.add_child(title)
        _add_slider("Master volume", "master_volume")
        _add_slider("Music volume", "music_volume")
        _add_slider("SFX volume", "sfx_volume")
        _add_slider("HUD scale", "hud_scale")
        _add_check("Subtitles", "subtitles")
        _add_check("Invert Y", "invert_y")
        var back := LvgTheme.make_button("BACK")
        back.pressed.connect(func(): _toggle_settings())
        _v.add_child(back)


func _add_slider(label_text: String, key: String) -> void:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 18)
        var l := LvgTheme.make_label(label_text, 24, LvgTheme.TEXT)
        row.add_child(l)
        var s := HSlider.new()
        s.min_value = 0.0
        s.max_value = 1.0 if key != "hud_scale" else 1.4
        s.step = 0.05
        s.value = float(SaveSystem.settings.get(key, 0.8))
        s.custom_minimum_size = Vector2(420, 40)
        s.value_changed.connect(func(v):
                SaveSystem.settings[key] = v
                SaveSystem.save_settings()
                EventBus.settings_changed.emit("settings"))
        row.add_child(s)
        _v.add_child(row)


func _add_check(label_text: String, key: String) -> void:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 18)
        var l := LvgTheme.make_label(label_text, 24, LvgTheme.TEXT)
        row.add_child(l)
        var c := CheckButton.new()
        c.button_pressed = bool(SaveSystem.settings.get(key, true))
        c.toggled.connect(func(v):
                SaveSystem.settings[key] = v
                SaveSystem.save_settings()
                EventBus.settings_changed.emit("settings"))
        row.add_child(c)
        _v.add_child(row)


func _show_credits() -> void:
        for c in _v.get_children():
                c.queue_free()
        var lines := [
                "LEVERAGE - Everyone has leverage on you.",
                "",
                "A DE YOUNG GAMES production",
                "",
                "Design, code, writing: DE YOUNG GAMES",
                "Character animation: Quaternius Universal Animation Library (CC0)",
                "City kits, vehicles, weapons: Quaternius packs (CC0)",
                "Fonts: Lilita One, Liberation Sans (OFL)",
                "Music + SFX: synthesized for this project",
                "",
                "Made with Godot (Mobile renderer). Runs via XOGOT on iPhone.",
        ]
        for t in lines:
                _v.add_child(LvgTheme.make_label(t, 24 if t != "" else 12, LvgTheme.TEXT_DIM if t != "" else LvgTheme.TEXT_DIM))
        var back := LvgTheme.make_button("BACK")
        back.pressed.connect(func(): _add_menu_buttons())
        _v.add_child(back)
