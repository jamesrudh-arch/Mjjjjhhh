class_name HUD
extends CanvasLayer
## HUD - in-game overlay: vitals, minimap, wanted stars, objective tracker,
## notifications, subtitles. Owns phone/map/pause/dialogue/shop sub-panels
## (composed lazily). Touch controls live in TouchControls (sibling).

var _root: Control
var _health_bar: ColorRect
var _stamina_bar: ColorRect
var _armor_bar: ColorRect
var _money_label: Label
var _area_label: Label
var _clock_label: Label
var _stars: Array = []
var _notif_box: VBoxContainer
var _notif_items: Array = []
var _objective_label: Label
var _gps_arrow: Label
var _gps_dist: Label
var _objective_title: Label
var _subtitle: Label
var _subtitle_speaker: Label
var _subtitle_t := 0.0
var _minimap: Control
var _panel_open := ""               # "", "phone", "map", "pause", "shop", "dialogue"
var _phone_root: Control
var _map_root: Control
var _pause_root: Control
var _shop_root: Control
var _dialogue_root: Control
var _radio_label: Label
var _combo_label: Label
var _combo_t := 0.0
var _wanted_flash := 0.0
var _star_blink := 0.0             # stars blink while police search (no LOS)
var _evaded_label: Label
var _evaded_t := 0.0


func _ready() -> void:
        layer = 10
        _build()
        _wire()


func _build() -> void:
        _root = Control.new()
        _root.set_anchors_preset(Control.PRESET_FULL_RECT)
        _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(_root)
        var scale_f: float = float(SaveSystem.settings.get("hud_scale", 1.0))
        _root.scale = Vector2(scale_f, scale_f)
        _root.set_anchors_preset(Control.PRESET_FULL_RECT)

        # --- top-left: minimap + area + clock ---
        var tl := VBoxContainer.new()
        tl.position = Vector2(28, 22)
        tl.add_theme_constant_override("separation", 6)
        _root.add_child(tl)
        _area_label = LvgTheme.make_kicker("OLD QUARTER", LvgTheme.TEXT_DIM, 24)
        tl.add_child(_area_label)
        _clock_label = LvgTheme.make_label("08:00  Day 1", 22, LvgTheme.TEXT_DIM)
        tl.add_child(_clock_label)
        _minimap = _build_minimap()
        tl.add_child(_minimap)
        _build_vitals(tl)
        _money_label = LvgTheme.make_label("$250", 30, LvgTheme.ACCENT, true)
        tl.add_child(_money_label)

        # --- wanted stars under minimap ---
        var stars_row := HBoxContainer.new()
        stars_row.add_theme_constant_override("separation", 4)
        tl.add_child(stars_row)
        for i in 5:
                var s := LvgTheme.make_display_label("*", 34, Color(LvgTheme.ACCENT.r, LvgTheme.ACCENT.g, LvgTheme.ACCENT.b, 0.16))
                stars_row.add_child(s)
                _stars.append(s)

        # --- top-right chips handled by TouchControls; objective under them ---
        _objective_title = LvgTheme.make_kicker("OBJECTIVE", LvgTheme.ACCENT, 22)
        _objective_title.position = Vector2(560, 96)
        _root.add_child(_objective_title)
        _objective_label = LvgTheme.make_label("Follow the story.", 26, LvgTheme.TEXT)
        _objective_label.position = Vector2(560, 124)
        _objective_label.custom_minimum_size = Vector2(600, 0)
        _root.add_child(_objective_label)

        # --- notifications bottom-center ---
        _notif_box = VBoxContainer.new()
        _notif_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
        _notif_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
        _notif_box.position = Vector2(700, 1050)
        _notif_box.add_theme_constant_override("separation", 8)
        _root.add_child(_notif_box)

        # --- subtitles ---
        _subtitle_speaker = LvgTheme.make_kicker("", LvgTheme.ACCENT, 24)
        _subtitle_speaker.position = Vector2(660, 980)
        _root.add_child(_subtitle_speaker)
        _subtitle = LvgTheme.make_label("", 28, LvgTheme.TEXT)
        _subtitle.position = Vector2(660, 1010)
        _subtitle.custom_minimum_size = Vector2(1000, 60)
        _root.add_child(_subtitle)

        # --- radio chip (vehicle) ---
        _radio_label = LvgTheme.make_label("RADIO: CINDER FM", 24, LvgTheme.TEXT_DIM, true)
        _radio_label.position = Vector2(28, 640)
        _radio_label.visible = false
        _root.add_child(_radio_label)

        # --- combo counter (combat) ---
        _combo_label = LvgTheme.make_display_label("", 44, LvgTheme.ACCENT)
        _combo_label.position = Vector2(1180, 300)
        _root.add_child(_combo_label)


func _build_minimap() -> Control:
        var map := Control.new()
        map.custom_minimum_size = Vector2(230, 230)
        var draw := Control.new()
        draw.set_anchors_preset(Control.PRESET_FULL_RECT)
        draw.draw.connect(func():
                var w: float = 230.0
                draw.draw_rect(Rect2(0, 0, w, w), LvgTheme.PANEL)
                draw.draw_rect(Rect2(0, 0, w, w), LvgTheme.LINE, false, 2.0)
                # roads as lines
                var player := get_tree().get_first_node_in_group("player") as Node3D
                if player == null:
                        return
                var p2 := Vector2(player.global_position.x, player.global_position.z)
                var scale_f: float = 230.0 / 900.0
                for road in CityDirector.ROADS:
                        var a: Vector2 = (road["a"] - p2) * scale_f
                        var b: Vector2 = (road["b"] - p2) * scale_f
                        draw.draw_line(Vector2(115, 115) + Vector2(a.y, a.x), Vector2(115, 115) + Vector2(b.y, b.x), Color(0.28, 0.29, 0.34), 3.0)
                # current area tint only (v2.5: full-tint overlay read as noise)
                for area_id in ([CityDirector.current_area] if CityDirector.current_area != "" else []):
                        if not CityDirector.AREAS.has(area_id):
                                continue
                        var r: Rect2 = CityDirector.AREAS[area_id]["bounds"]
                        var tl2 := Vector2(115, 115) + Vector2((r.position - p2).y, (r.position - p2).x) * scale_f
                        draw.draw_rect(Rect2(tl2, r.size * scale_f), Color(CityDirector.AREAS[area_id]["color"].r, CityDirector.AREAS[area_id]["color"].g, CityDirector.AREAS[area_id]["color"].b, 0.18))
                # player arrow
                draw.draw_circle(Vector2(115, 115), 5.0, LvgTheme.ACCENT)
                # police blips
                for u in get_tree().get_nodes_in_group("combatant"):
                        if u is PoliceUnit:
                                var up := Vector2(u.global_position.x, u.global_position.z)
                                var rel := (up - p2) * scale_f
                                if rel.length() < 110.0:
                                        draw.draw_circle(Vector2(115, 115) + Vector2(rel.y, rel.x), 3.0, LvgTheme.POLICE)
        )
        map.add_child(draw)
        return map


func _build_vitals(parent: Control) -> void:
        var box := VBoxContainer.new()
        box.add_theme_constant_override("separation", 4)
        parent.add_child(box)
        _health_bar = _bar(box, Color("d64541"), 190.0)
        _armor_bar = _bar(box, Color("3b6fd6"), 0.0)
        _stamina_bar = _bar(box, Color("e8e6e3"), 190.0)


func _bar(parent: Control, color: Color, w: float) -> ColorRect:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 0)
        parent.add_child(row)
        var bg := ColorRect.new()
        bg.color = Color(0.08, 0.08, 0.09, 0.7)
        bg.custom_minimum_size = Vector2(200, 10)
        bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(bg)
        var fill := ColorRect.new()
        fill.color = color
        fill.custom_minimum_size = Vector2(max(0.0, w), 10)
        fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bg.add_child(fill)
        return fill


func _wire() -> void:
        EventBus.player_health_changed.connect(_on_health_changed)
        EventBus.player_armor_changed.connect(_on_armor_changed)
        EventBus.player_stamina_changed.connect(_on_stamina_changed)
        EventBus.player_money_changed.connect(_on_money_changed)
        EventBus.player_wanted_changed.connect(_on_wanted_changed)
        EventBus.area_entered.connect(_on_area_entered)
        EventBus.notification_posted.connect(_post_notification)
        EventBus.objective_displayed.connect(_on_objective_displayed)
        EventBus.subtitle_show.connect(_show_subtitle)
        EventBus.subtitle_hide.connect(_on_subtitle_hide)
        EventBus.combo_progressed.connect(_on_combo_progressed)
        EventBus.player_entered_vehicle.connect(_on_vehicle_entered)
        EventBus.player_exited_vehicle.connect(_on_vehicle_exited)
        EventBus.radio_station_changed.connect(_on_radio_station_changed)
        EventBus.police_lost_target.connect(_show_evaded)


func _on_health_changed(hp: float, max_hp: float) -> void:
        if _health_bar:
                _health_bar.custom_minimum_size = Vector2(190.0 * clampf(hp / max_hp, 0.0, 1.0), 10)


func _on_armor_changed(armor: float, max_armor: float) -> void:
        if _armor_bar:
                var ratio: float = armor / max_armor if max_armor > 0.0 else 0.0
                _armor_bar.custom_minimum_size = Vector2(190.0 * clampf(ratio, 0.0, 1.0), 10)


func _on_stamina_changed(stamina: float, max_stamina: float) -> void:
        if _stamina_bar:
                _stamina_bar.custom_minimum_size = Vector2(190.0 * clampf(stamina / max_stamina, 0.0, 1.0), 10)


func _on_money_changed(money: int) -> void:
        if _money_label:
                _money_label.text = "$%d" % money


func _on_wanted_changed(wanted_level: int) -> void:
        _update_stars(wanted_level)


func _on_area_entered(area_id: String) -> void:
        if _area_label:
                _area_label.text = LvgTheme.tracked(CityDirector.area_display(area_id))


func _on_objective_displayed(title: String, description: String) -> void:
        if _objective_label:
                _objective_label.text = description
        if _objective_title:
                _objective_title.text = LvgTheme.tracked(title.to_upper())


func _on_subtitle_hide() -> void:
        _subtitle_t = 0.0


func _on_combo_progressed(count: int, discipline_id: String) -> void:
        if count > 0:
                _combo_label.text = "%d HIT %s" % [count, Discipline.display_name(discipline_id).to_upper()]
                _combo_t = 1.4


func _on_vehicle_entered(_vehicle: Node) -> void:
        if _radio_label:
                _radio_label.visible = true


func _on_vehicle_exited() -> void:
        if _radio_label:
                _radio_label.visible = false


func _on_radio_station_changed(station_id: String) -> void:
        if _radio_label:
                _radio_label.text = "RADIO: " + station_id.to_upper().replace("_", " ")


func _process(delta: float) -> void:
        if _clock_label and TimeWeather:
                _clock_label.text = "%s  Day %d" % [TimeWeather.get_clock_text(), TimeWeather.day_count]
        if _subtitle_t > 0.0:
                _subtitle_t -= delta
                if _subtitle_t <= 0.0:
                        _subtitle.text = ""
                        _subtitle_speaker.text = ""
        if _combo_t > 0.0:
                _combo_t -= delta
                _combo_label.modulate.a = clamp(_combo_t, 0.0, 1.0)
        else:
                _combo_label.text = ""
        _wanted_flash = max(0.0, _wanted_flash - delta)
        # EVADED payoff flash fades out
        if _evaded_t > 0.0:
                _evaded_t -= delta
                if _evaded_label and is_instance_valid(_evaded_label):
                        _evaded_label.modulate.a = clamp(_evaded_t, 0.0, 1.0)
                        _evaded_label.scale = Vector2.ONE * (1.0 + 0.25 * clamp(_evaded_t, 0.0, 1.0))
                        if _evaded_t <= 0.0:
                                _evaded_label.queue_free()
                                _evaded_label = null
        # stars blink while the pursuit is live but police have lost sight
        if PoliceSystem != null and PoliceSystem.is_searching() and GameState.wanted_level > 0:
                _star_blink += delta
                var on: bool = fmod(_star_blink, 0.8) < 0.45
                for i in 5:
                        if i < GameState.wanted_level:
                                (_stars[i] as Label).visible = on
        else:
                _star_blink = 0.0
                for i in 5:
                        (_stars[i] as Label).visible = true
        _cleanup_notifications(delta)
        # minimap redraw is automatic via draw signal


func _update_gps_arrow() -> void:
        if _gps_arrow == null:
                return
        var target := Vector2.INF
        var obj := MissionSystem.current_objective()
        if not obj.is_empty() and obj.has("pos"):
                var p3: Vector3 = obj["pos"]
                target = Vector2(p3.x, p3.z)
        elif GameState.has_gps:
                target = GameState.gps_waypoint
        if target == Vector2.INF:
                _gps_arrow.text = ""
                _gps_dist.text = ""
                return
        var player := get_tree().get_first_node_in_group("player") as Node3D
        if player == null:
                return
        var cam := get_viewport().get_camera_3d()
        if cam == null:
                return
        var to_t := Vector3(target.x, 0, target.y) - player.global_position
        var dist: float = to_t.length()
        var fwd := -cam.global_transform.basis.z
        var fwd_flat := Vector2(fwd.x, fwd.z).normalized()
        var to_flat := Vector2(to_t.x, to_t.z).normalized()
        var ang := fwd_flat.angle_to(to_flat)
        _gps_arrow.text = "➤"
        _gps_arrow.rotation = ang
        var off := Vector2(0, -210).rotated(ang)
        _gps_arrow.position = Vector2(960, 620) + off - Vector2(20, 20)
        _gps_dist.position = Vector2(960, 660) + off
        _gps_dist.text = "%d m" % int(dist)

func _update_stars(level: int) -> void:
        for i in 5:
                var s: Label = _stars[i]
                if i < level:
                        s.modulate.a = 1.0
                        s.add_theme_color_override("font_color", LvgTheme.ACCENT)
                else:
                        s.modulate.a = 0.16


## Evasion payoff: the escape arc ends with a visible ALL CLEAR.
func _show_evaded() -> void:
        if _root == null or _evaded_label != null:
                return
        var l := LvgTheme.make_label("WANTED LEVEL CLEARED — EVADED", 54, LvgTheme.ACCENT, true)
        l.set_anchors_preset(Control.PRESET_CENTER)
        l.position = Vector2(640, 300)
        l.scale = Vector2.ONE
        _root.add_child(l)
        _evaded_label = l
        _evaded_t = 2.2
        EventBus.sfx_requested.emit("sfx_wanted_clear", Vector3.ZERO)


func _post_notification(text: String, kind: String) -> void:
        if _notif_box == null:
                return
        var color := LvgTheme.TEXT
        match kind:
                "money": color = LvgTheme.ACCENT
                "crime": color = LvgTheme.DANGER
                "unlock": color = LvgTheme.ACCENT
                "warn": color = LvgTheme.DANGER
                "boss": color = LvgTheme.DANGER
                "collect": color = LvgTheme.ACCENT
                "reward": color = LvgTheme.ACCENT
                "mission": color = LvgTheme.TEXT
        var l := LvgTheme.make_label(text, 26, color, true)
        _notif_box.add_child(l)
        _notif_items.append({ "node": l, "t": 4.0 })


func _cleanup_notifications(delta: float) -> void:
        for it in _notif_items.duplicate():
                it["t"] = float(it["t"]) - delta
                var l: Label = it["node"]
                if not is_instance_valid(l):
                        _notif_items.erase(it)
                        continue
                if float(it["t"]) < 0.8:
                        l.modulate.a = clamp(float(it["t"]) / 0.8, 0.0, 1.0)
                if float(it["t"]) <= 0.0:
                        l.queue_free()
                        _notif_items.erase(it)


func _show_subtitle(text: String, speaker: String, duration: float) -> void:
        if not SaveSystem.settings.get("subtitles", true) and speaker != "":
                return
        _subtitle.text = text
        _subtitle_speaker.text = LvgTheme.tracked(speaker) if speaker != "" else ""
        _subtitle_t = duration if duration > 0.0 else 2.6


## ---------------- Panels ----------------
func toggle_phone() -> void:
        if _panel_open == "phone":
                _close_panels()
                return
        _close_panels()
        _panel_open = "phone"
        _phone_root = load("res://scripts/ui/phone.gd").new()
        _root.add_child(_phone_root)
        InputRouter.ui_blocking = true


func toggle_map() -> void:
        if _panel_open == "map":
                _close_panels()
                return
        _close_panels()
        _panel_open = "map"
        _map_root = load("res://scripts/ui/map_screen.gd").new()
        _root.add_child(_map_root)
        InputRouter.ui_blocking = true


func toggle_pause() -> void:
        if _panel_open == "pause":
                _close_panels()
                GameManager.go_to_state(GameManager.State.PLAYING)
                EventBus.game_paused.emit(false)
                return
        if not GameManager.is_playing():
                return
        _close_panels()
        _panel_open = "pause"
        _pause_root = load("res://scripts/ui/pause_menu.gd").new()
        _root.add_child(_pause_root)
        GameManager.go_to_state(GameManager.State.PAUSED)
        EventBus.game_paused.emit(true)
        InputRouter.ui_blocking = true


func open_shop(shop_id: String) -> void:
        _close_panels()
        _panel_open = "shop"
        _shop_root = load("res://scripts/ui/shop_screen.gd").new()
        _shop_root.setup(shop_id)
        _root.add_child(_shop_root)
        InputRouter.ui_blocking = true


func show_dialogue_choices(node_id: String, choices: Array) -> void:
        if _dialogue_root and is_instance_valid(_dialogue_root):
                _dialogue_root.queue_free()
        _dialogue_root = load("res://scripts/ui/dialogue_panel.gd").new()
        _dialogue_root.show_choices(node_id, choices)
        _root.add_child(_dialogue_root)


func _close_panels() -> void:
        for p in [_phone_root, _map_root, _pause_root, _shop_root, _dialogue_root]:
                if p != null and is_instance_valid(p):
                        p.queue_free()
        _phone_root = null
        _map_root = null
        _pause_root = null
        _shop_root = null
        _dialogue_root = null
        _panel_open = ""
        InputRouter.ui_blocking = false


func panel_open() -> String:
        return _panel_open
