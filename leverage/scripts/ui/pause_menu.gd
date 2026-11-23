class_name PauseMenu
extends Control
## PauseMenu - resume / save (3 slots) / load / settings-lite / quit to menu.

var _root: Control


func _ready() -> void:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        _build()


func _build() -> void:
        add_child(LvgTheme.color_rect(Color(0, 0, 0, 0.6)))
        var sheet := LvgTheme.make_panel()
        sheet.set_anchors_preset(Control.PRESET_CENTER)
        sheet.custom_minimum_size = Vector2(700, 900)
        add_child(sheet)
        var v := VBoxContainer.new()
        v.add_theme_constant_override("separation", 16)
        sheet.add_child(v)
        v.add_child(LvgTheme.make_display_label("PAUSED", 72, LvgTheme.ACCENT))
        var info := LvgTheme.make_label("", 24, LvgTheme.TEXT_DIM)
        info.text = "%s  |  %s  |  Day %d  |  $%d" % [
                GameState.player_name, CityDirector.area_display(GameState.current_area),
                TimeWeather.day_count, GameState.money]
        v.add_child(info)
        var resume := LvgTheme.make_button("RESUME")
        resume.pressed.connect(func(): _resume())
        v.add_child(resume)
        v.add_child(LvgTheme.make_kicker("SAVE SLOTS", LvgTheme.TEXT_DIM))
        for slot in [1, 2, 3]:
                var row := HBoxContainer.new()
                row.add_theme_constant_override("separation", 12)
                var meta: Dictionary = SaveSystem.slot_info(slot)
                var txt := "SLOT %d" % slot
                if meta.has("exists"):
                        txt += "  -  Day %d, %s, $%d" % [int(meta.get("chapter", 1)), String(meta.get("area", "?")), int(meta.get("money", 0))]
                row.add_child(LvgTheme.make_label(txt, 24, LvgTheme.TEXT))
                var save_b := LvgTheme.make_button("SAVE")
                var s_idx := slot
                save_b.pressed.connect(func():
                        SaveSystem.capture_world_state()
                        if SaveSystem.save_game(s_idx):
                                EventBus.notification_posted.emit("Saved to slot %d" % s_idx, "save")
                                _rebuild())
                row.add_child(save_b)
                if SaveSystem.slot_exists(slot):
                        var load_b := LvgTheme.make_button("LOAD")
                        load_b.pressed.connect(func():
                                _resume()
                                if SaveSystem.load_game(s_idx):
                                        EventBus.notification_posted.emit("Loaded slot %d" % s_idx, "save")
                                        GameManager.reload_world_from_save())
                        row.add_child(load_b)
                v.add_child(row)
        var quit := LvgTheme.make_button("QUIT TO MENU")
        quit.pressed.connect(func():
                SaveSystem.capture_world_state()
                SaveSystem.autosave()
                _resume()
                GameManager.return_to_menu())
        v.add_child(quit)


func _rebuild() -> void:
        for c in get_children():
                c.queue_free()
        _build.call_deferred()


func _resume() -> void:
        var hud_layer := get_parent()
        if hud_layer and hud_layer.has_method("toggle_pause"):
                hud_layer.toggle_pause()
        else:
                queue_free()
