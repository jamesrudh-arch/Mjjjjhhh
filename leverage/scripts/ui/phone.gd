class_name PhoneUI
extends Control
## PhoneUI - full-screen phone sheet: Contacts, Messages, Missions, Radio.
## Opened from HUD (PHONE chip / T). Close via back chip.

var _root: Control
var _tab := "messages"
var _body: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        _build()
        _refresh()


func _build() -> void:
        add_child(LvgTheme.color_rect(Color(0, 0, 0, 0.55)))
        var sheet := LvgTheme.make_panel(LvgTheme.CHARCOAL, LvgTheme.LINE)
        sheet.set_anchors_preset(Control.PRESET_CENTER)
        sheet.custom_minimum_size = Vector2(1800, 1000)
        add_child(sheet)
        var v := VBoxContainer.new()
        v.add_theme_constant_override("separation", 18)
        sheet.add_child(v)
        var header := HBoxContainer.new()
        header.add_theme_constant_override("separation", 24)
        v.add_child(header)
        header.add_child(LvgTheme.make_display_label("PHONE", 64, LvgTheme.ACCENT))
        var spacer := Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        header.add_child(spacer)
        var close := LvgTheme.make_button("CLOSE")
        close.pressed.connect(func(): _close())
        header.add_child(close)
        # tabs
        var tabs := HBoxContainer.new()
        tabs.add_theme_constant_override("separation", 12)
        v.add_child(tabs)
        for tab in ["messages", "contacts", "missions", "radio"]:
                var b := LvgTheme.make_button(tab.to_upper())
                b.pressed.connect(func():
                        _tab = tab
                        _refresh())
                tabs.add_child(b)
        _scroll = ScrollContainer.new()
        _scroll.custom_minimum_size = Vector2(1700, 700)
        v.add_child(_scroll)
        _body = VBoxContainer.new()
        _body.add_theme_constant_override("separation", 12)
        _body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _scroll.add_child(_body)


func _refresh() -> void:
        for c in _body.get_children():
                c.queue_free()
        match _tab:
                "messages":
                        _render_messages()
                "contacts":
                        _render_contacts()
                "missions":
                        _render_missions()
                "radio":
                        _render_radio()


func _render_messages() -> void:
        if GameState.phone_messages.is_empty():
                _body.add_child(LvgTheme.make_label("No messages yet. The city will find you.", 26, LvgTheme.TEXT_DIM))
                return
        for m in GameState.phone_messages:
                var from: String = str(m.get("from", "?"))
                var text: String = str(m.get("text", ""))
                var read: bool = bool(m.get("read", false))
                var row := PanelContainer.new()
                row.add_theme_stylebox_override("panel", LvgTheme.panel_style(
                        LvgTheme.PANEL if read else LvgTheme.PANEL_LIFT,
                        LvgTheme.ACCENT if not read else LvgTheme.LINE))
                var box := VBoxContainer.new()
                row.add_child(box)
                box.add_child(LvgTheme.make_kicker(from.to_upper(), LvgTheme.ACCENT if not read else LvgTheme.TEXT_DIM, 22))
                box.add_child(LvgTheme.make_label(text, 26, LvgTheme.TEXT))
                _body.add_child(row)
                m["read"] = true


func _render_contacts() -> void:
        var contacts: Array = _known_contacts()
        if contacts.is_empty():
                _body.add_child(LvgTheme.make_label("Nobody yet. The story will introduce them.", 26, LvgTheme.TEXT_DIM))
                return
        for id in contacts:
                var row := HBoxContainer.new()
                row.add_theme_constant_override("separation", 20)
                row.add_child(LvgTheme.make_kicker(NPCDirector.cast_display(id).to_upper(), LvgTheme.TEXT, 26))
                var rel: float = GameState.relationship_for(id)
                var rel_txt := "warm" if rel > 20 else "cold" if rel < -20 else "neutral"
                row.add_child(LvgTheme.make_label("relationship: " + rel_txt, 24, LvgTheme.TEXT_DIM))
                var call := LvgTheme.make_button("CALL")
                call.pressed.connect(func():
                        EventBus.phone_call_received.emit(id)
                        EventBus.subtitle_show.emit("The line clicks. " + NPCDirector.cast_display(id) + " listens.", NPCDirector.cast_display(id), 3.0))
                row.add_child(call)
                _body.add_child(row)


func _known_contacts() -> Array:
        var out: Array = []
        for id in ["rizzo", "juno", "nadia", "the_tipster", "big_theo", "marisol", "officer_brant"]:
                if GameState.npc_relationships.has(id) or GameState.npc_remembered(id, "talked_with_dez") or GameState.npc_memory.has(id):
                        out.append(id)
        return out


func _render_missions() -> void:
        var active: String = MissionSystem.active_id
        if active != "":
                var def: Dictionary = MissionSystem.mission_def(active)
                _body.add_child(LvgTheme.make_kicker("ACTIVE MISSION", LvgTheme.ACCENT))
                _body.add_child(LvgTheme.make_label(String(def.get("title", active)), 34, LvgTheme.TEXT, true))
                _body.add_child(LvgTheme.make_label(String(def.get("briefing", "")), 24, LvgTheme.TEXT_DIM))
                var obj := MissionSystem.current_objective()
                _body.add_child(LvgTheme.make_label("> " + String(obj.get("text", "")), 26, LvgTheme.ACCENT, true))
        _body.add_child(LvgTheme.make_kicker("AVAILABLE", LvgTheme.TEXT_DIM))
        var avail: Array = MissionSystem.available_missions()
        for id in avail:
                var d: Dictionary = MissionSystem.mission_def(id)
                var row := HBoxContainer.new()
                row.add_theme_constant_override("separation", 16)
                row.add_child(LvgTheme.make_label(String(d.get("title", id)), 26, LvgTheme.TEXT))
                var start := LvgTheme.make_button("TRACK")
                start.pressed.connect(func():
                        if MissionSystem.start_mission(id):
                                _refresh())
                row.add_child(start)
                _body.add_child(row)


func _render_radio() -> void:
        _body.add_child(LvgTheme.make_kicker("RADIO STATIONS", LvgTheme.ACCENT))
        for st in [["cinder_fm", "CINDER FM - neo-noir, brushed drums, Moses after midnight"],
                        ["strip_wave", "STRIP WAVE - neon synthpop"],
                        ["iron_pulse", "IRON PULSE - industrial grind"]]:
                var row := HBoxContainer.new()
                row.add_theme_constant_override("separation", 20)
                var b := LvgTheme.make_button("TUNE")
                var st_id: String = st[0]
                b.pressed.connect(func():
                        GameState.radio_station = st_id
                        EventBus.radio_station_changed.emit(st_id)
                        EventBus.sfx_requested.emit("sfx_radio_click", Vector3.ZERO))
                row.add_child(b)
                row.add_child(LvgTheme.make_label(st[1], 26, LvgTheme.TEXT))
                _body.add_child(row)
        _body.add_child(LvgTheme.make_label("Radio plays inside vehicles.", 22, LvgTheme.TEXT_DIM))


func _close() -> void:
        var hud_layer := get_parent()
        if hud_layer and hud_layer.has_method("_close_panels"):
                hud_layer._close_panels()
        else:
                queue_free()
