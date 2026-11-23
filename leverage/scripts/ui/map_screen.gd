class_name MapScreen
extends Control
## MapScreen - full-screen Cinder City map with areas, roads, player marker,
## objective marker. Drawn from CityDirector data.

const MAP_SIZE := 1600.0

var _root: Control


func _ready() -> void:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        _build()


func _build() -> void:
        add_child(LvgTheme.color_rect(Color(0, 0, 0, 0.55)))
        var sheet := LvgTheme.make_panel(LvgTheme.CHARCOAL, LvgTheme.LINE)
        sheet.set_anchors_preset(Control.PRESET_CENTER)
        sheet.custom_minimum_size = Vector2(MAP_SIZE + 140, MAP_SIZE + 240)
        add_child(sheet)
        var v := VBoxContainer.new()
        v.add_theme_constant_override("separation", 12)
        sheet.add_child(v)
        var header := HBoxContainer.new()
        header.add_theme_constant_override("separation", 24)
        v.add_child(header)
        header.add_child(LvgTheme.make_display_label("CINDER CITY", 54, LvgTheme.ACCENT))
        var spacer := Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        header.add_child(spacer)
        var close := LvgTheme.make_button("CLOSE")
        close.pressed.connect(func(): _close())
        header.add_child(close)
        var map := Control.new()
        map.custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
        v.add_child(map)
        map.draw.connect(func(): _draw_map(map))
        var hint := LvgTheme.make_label("Amber = you. Blue dots = Cinder City PD. Districts tinted by identity.", 22, LvgTheme.TEXT_DIM)
        v.add_child(hint)


func _draw_map(map: Control) -> void:
        map.draw_rect(Rect2(0, 0, MAP_SIZE, MAP_SIZE), LvgTheme.PANEL)
        map.draw_rect(Rect2(0, 0, MAP_SIZE, MAP_SIZE), LvgTheme.LINE, false, 3.0)
        var world_span := 1500.0    # world units covered
        var origin := Vector2(-750, -750)
        var s: float = MAP_SIZE / world_span
        var to_map := func(p: Vector2) -> Vector2:
                return Vector2((p.x - origin.x) * s, (p.y - origin.y) * s)
        # areas
        for area_id in CityDirector.AREAS.keys():
                var r: Rect2 = CityDirector.AREAS[area_id]["bounds"]
                var tl2: Vector2 = to_map(r.position)
                var sz := r.size * s
                var col: Color = CityDirector.AREAS[area_id]["color"]
                map.draw_rect(Rect2(tl2, sz), Color(col.r, col.g, col.b, 0.22))
                map.draw_rect(Rect2(tl2, sz), Color(col.r, col.g, col.b, 0.7), false, 2.0)
                var disp: String = CityDirector.AREAS[area_id]["display"]
                var short := disp.split(" ")[0].to_upper()
                map.draw_string(LvgTheme.font_body, tl2 + sz / 2.0 - Vector2(60, 0), short,
                        HORIZONTAL_ALIGNMENT_CENTER, -1, 30, Color(col.r, col.g, col.b, 0.9))
                if GameState.visited_areas.has(area_id):
                        pass
        # roads
        for road in CityDirector.ROADS:
                var a: Vector2 = to_map(road["a"])
                var b: Vector2 = to_map(road["b"])
                map.draw_line(a, b, Color(0.32, 0.33, 0.38), 8.0)
        # shops / interiors
        for k in ["pawn", "threads", "quickmart"]:
                var p: Vector2 = to_map(_shop_pos(k))
                map.draw_circle(p, 8.0, LvgTheme.SUCCESS)
        # police units
        var player := get_tree().get_first_node_in_group("player") as Node3D
        for u in get_tree().get_nodes_in_group("combatant"):
                if u is PoliceUnit and is_instance_valid(u):
                        var up: Vector2 = to_map(Vector2(u.global_position.x, u.global_position.z))
                        map.draw_circle(up, 5.0, LvgTheme.POLICE)
        # objective marker: first marker child in world
        var world := get_tree().get_first_node_in_group("player")
        if world != null and world.get_parent() != null:
                pass
        # player
        if player != null:
                var pp: Vector2 = to_map(Vector2(player.global_position.x, player.global_position.z))
                map.draw_circle(pp, 12.0, LvgTheme.ACCENT)
                map.draw_circle(pp, 6.0, Color(1, 1, 1))


func _shop_pos(k: String) -> Vector2:
        match k:
                "pawn": return Vector2(-260, -80)
                "threads": return Vector2(320, 200)
                "quickmart": return Vector2(-120, -60)
        return Vector2.ZERO


func _close() -> void:
        var hud_layer := get_parent()
        if hud_layer and hud_layer.has_method("_close_panels"):
                hud_layer._close_panels()
        else:
                queue_free()
