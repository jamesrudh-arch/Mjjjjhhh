class_name PhoneUI
extends Control
## PhoneUI v2 - the phone as a living device. Threads with portraits and
## timestamps, contacts with CALL (real outgoing calls via PhoneSystem),
## call log with outcomes, missions tab with TRACK, radio tab.
## Incoming-call handling lives in the HUD banner (CallBanner) - this sheet
## shows history and lets the player initiate.

var _root: Control
var _tab := "messages"
var _body: VBoxContainer
var _scroll: ScrollContainer

const CONTACT_ORDER := ["tommy", "the_tipster", "rizzo", "marisol", "big_theo", "juno",
        "nadia", "officer_brant", "ava", "vito", "lucy_fang", "ren", "cabbie_moses", "doc_lennox"]


func _ready() -> void:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        _build()
        _refresh()


func _build() -> void:
        add_child(LvgTheme.color_rect(Color(0, 0, 0, 0.55)))
        var sheet := LvgTheme.make_panel(LvgTheme.CHARCOAL, LvgTheme.LINE)
        sheet.set_anchors_preset(Control.PRESET_CENTER)
        sheet.custom_minimum_size = Vector2(1500, 980)
        add_child(sheet)
        var v := VBoxContainer.new()
        v.add_theme_constant_override("separation", 16)
        sheet.add_child(v)
        var header := HBoxContainer.new()
        header.add_theme_constant_override("separation", 22)
        v.add_child(header)
        header.add_child(LvgTheme.make_display_label("PHONE", 60, LvgTheme.ACCENT))
        var spacer := Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        header.add_child(spacer)
        var close := LvgTheme.make_button("CLOSE")
        close.pressed.connect(func(): _close())
        header.add_child(close)
        var tabs := HBoxContainer.new()
        tabs.add_theme_constant_override("separation", 10)
        v.add_child(tabs)
        for tab in ["messages", "contacts", "call log", "missions", "radio"]:
                var b := LvgTheme.make_button(tab.to_upper())
                b.pressed.connect(func():
                        _tab = tab.replace(" ", "_")
                        _refresh())
                tabs.add_child(b)
        _scroll = ScrollContainer.new()
        _scroll.custom_minimum_size = Vector2(1440, 700)
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
                "call_log":
                        _render_call_log()
                "missions":
                        _render_missions()
                "radio":
                        _render_radio()


# ---------------------------------------------------------------- threads
func _render_messages() -> void:
        var threads: Dictionary = GameState.phone_threads
        var msg_flat: Array = GameState.phone_messages
        if threads.is_empty() and msg_flat.is_empty():
                _body.add_child(LvgTheme.make_label("No messages yet. The city will find you.", 26, LvgTheme.TEXT_DIM))
                return
        # thread rows, most recent first
        var ids: Array = threads.keys()
        var order := ids.duplicate()
        order.sort_custom(func(a, b):
                return _thread_stamp(b) > _thread_stamp(a))
        for from_id in order:
                var msgs: Array = threads[from_id]
                var unread := 0
                for m in msgs:
                        if not bool(m.get("read", false)) and not bool(m.get("mine", false)):
                                unread += 1
                var row := PanelContainer.new()
                row.add_theme_stylebox_override("panel", LvgTheme.panel_style(
                        LvgTheme.PANEL_LIFT if unread > 0 else LvgTheme.PANEL,
                        LvgTheme.ACCENT if unread > 0 else LvgTheme.LINE))
                _body.add_child(row)
                var hb := HBoxContainer.new()
                hb.add_theme_constant_override("separation", 18)
                row.add_child(hb)
                hb.add_child(_portrait(String(from_id), 74))
                var box := VBoxContainer.new()
                hb.add_child(box)
                box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                var top := HBoxContainer.new()
                box.add_child(top)
                top.add_child(LvgTheme.make_kicker(NPCDirector.cast_display(String(from_id)).to_upper(),
                        LvgTheme.ACCENT if unread > 0 else LvgTheme.TEXT_DIM))
                if unread > 0:
                        top.add_child(LvgTheme.make_label("  (%d new)" % unread, 22, LvgTheme.ACCENT))
                var last: Dictionary = msgs[msgs.size() - 1]
                top.add_child(LvgTheme.make_label("   " + String(last.get("hour", "")), 22, LvgTheme.TEXT_DIM))
                var preview: String = String(last.get("text", "")).left(86)
                box.add_child(LvgTheme.make_label(preview, 26, LvgTheme.TEXT))
                row.gui_input.connect(func(ev):
                        if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
                                _open_thread(String(from_id)))
        # legacy flat messages (old saves)
        if not msg_flat.is_empty():
                _body.add_child(LvgTheme.make_kicker("OLDER", LvgTheme.TEXT_DIM))
                for m in msg_flat:
                        _body.add_child(LvgTheme.make_label("%s: %s" % [str(m.get("from", "?")), str(m.get("text", ""))], 24, LvgTheme.TEXT_DIM))


func _thread_stamp(from_id: String) -> float:
        var msgs: Array = GameState.phone_threads.get(from_id, [])
        return float(msgs.size())


func _open_thread(from_id: String) -> void:
        for c in _body.get_children():
                c.queue_free()
        var phone := _phone()
        # header
        var hb := HBoxContainer.new()
        hb.add_theme_constant_override("separation", 18)
        _body.add_child(hb)
        var back := LvgTheme.make_button("< THREADS")
        back.pressed.connect(func():
                _tab = "messages"
                _refresh())
        hb.add_child(back)
        hb.add_child(_portrait(from_id, 64))
        hb.add_child(LvgTheme.make_kicker(NPCDirector.cast_display(from_id).to_upper(), LvgTheme.ACCENT))
        var call_b := LvgTheme.make_button("CALL")
        call_b.pressed.connect(func():
                if phone != null:
                        phone.dial(from_id))
        hb.add_child(call_b)
        # bubbles
        var msgs: Array = GameState.phone_threads.get(from_id, [])
        for m in msgs:
                var mine := bool(m.get("mine", false))
                var row := HBoxContainer.new()
                _body.add_child(row)
                if mine:
                        var sp := Control.new()
                        sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                        row.add_child(sp)
                var bubble := PanelContainer.new()
                bubble.add_theme_stylebox_override("panel", LvgTheme.panel_style(
                        LvgTheme.PANEL_LIFT if mine else LvgTheme.PANEL, LvgTheme.LINE))
                row.add_child(bubble)
                var bv := VBoxContainer.new()
                bubble.add_child(bv)
                bv.add_child(LvgTheme.make_label(String(m.get("text", "")), 24, LvgTheme.TEXT))
                bv.add_child(LvgTheme.make_label(String(m.get("hour", "")) + (" - sent" if mine else ""), 19, LvgTheme.TEXT_DIM))
        # quick replies
        if msgs.size() > 0 and not bool(msgs[msgs.size() - 1].get("mine", false)):
                var quick := HBoxContainer.new()
                quick.add_theme_constant_override("separation", 10)
                _body.add_child(quick)
                for reply in ["Got it.", "On my way.", "Leave me alone."]:
                        var b := LvgTheme.make_button(reply)
                        b.pressed.connect(func():
                                if phone != null:
                                        phone.reply(from_id, reply)
                                        _open_thread(from_id))
                        quick.add_child(b)
        if phone != null:
                phone.mark_thread_read(from_id)


# ---------------------------------------------------------------- contacts
func _render_contacts() -> void:
        var contacts := _known_contacts()
        if contacts.is_empty():
                _body.add_child(LvgTheme.make_label("Nobody yet. The story will introduce them.", 26, LvgTheme.TEXT_DIM))
                return
        for id in contacts:
                var row := HBoxContainer.new()
                row.add_theme_constant_override("separation", 20)
                row.add_child(_portrait(String(id), 84))
                var col := VBoxContainer.new()
                col.add_theme_constant_override("separation", 4)
                row.add_child(col)
                col.add_child(LvgTheme.make_kicker(NPCDirector.cast_display(String(id)).to_upper(), LvgTheme.TEXT))
                var role: String = String(NPCDirector.CAST.get(id, {}).get("role", "unknown"))
                var rel: float = GameState.relationship_for(String(id))
                var rel_txt := "warm" if rel > 20 else "cold" if rel < -20 else "neutral"
                col.add_child(LvgTheme.make_label("%s - relationship: %s" % [role, rel_txt], 22, LvgTheme.TEXT_DIM))
                var call := LvgTheme.make_button("CALL")
                call.pressed.connect(func():
                        var phone := _phone()
                        if phone != null:
                                phone.dial(String(id)))
                row.add_child(call)
                _body.add_child(row)


func _render_call_log() -> void:
        var phone := _phone()
        var log: Array = phone.call_log if phone != null else GameState.phone_call_log
        if log.is_empty():
                _body.add_child(LvgTheme.make_label("No calls yet.", 26, LvgTheme.TEXT_DIM))
                return
        _body.add_child(LvgTheme.make_kicker("CALL HISTORY", LvgTheme.ACCENT))
        for i in range(log.size() - 1, -1, -1):
                var e: Dictionary = log[i]
                var col := LvgTheme.SUCCESS if String(e["outcome"]) == "answered" else LvgTheme.DANGER if String(e["outcome"]) != "hung_up" else LvgTheme.TEXT_DIM
                var row := HBoxContainer.new()
                row.add_theme_constant_override("separation", 16)
                row.add_child(_portrait(String(e["from"]), 48))
                row.add_child(LvgTheme.make_label("%02d:00" % int(e.get("time", 8)), 22, LvgTheme.TEXT_DIM))
                row.add_child(LvgTheme.make_label(NPCDirector.cast_display(String(e["from"])), 26, LvgTheme.TEXT))
                row.add_child(LvgTheme.make_label(String(e["outcome"]).to_upper(), 24, col))
                _body.add_child(row)


func _known_contacts() -> Array:
        var out: Array = []
        for id in CONTACT_ORDER:
                if id == "tommy" and not GameState.story_flags.get("tommy_rescued", false):
                        # Tommy's number exists but he can't pick up (kidnapped) - voicemail only
                        if GameState.npc_memory.has("tommy") or GameState.story_flags.get("met_tommy", false):
                                out.append(id)
                        continue
                if GameState.npc_relationships.has(id) or GameState.npc_remembered(id, "talked_with_dez") or GameState.phone_threads.has(id):
                        out.append(id)
        return out


# ---------------------------------------------------------------- missions
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


# ---------------------------------------------------------------- helpers
func _portrait(id: String, size: int) -> TextureRect:
        var tr := TextureRect.new()
        var path := "res://assets/ui/portraits/%s.png" % id
        if ResourceLoader.exists(path):
                tr.texture = load(path)
        tr.custom_minimum_size = Vector2(size, size)
        tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        return tr

func _phone() -> PhoneSystem:
        var p := get_tree().get_first_node_in_group("phone_system")
        if p is PhoneSystem:
                return p
        return null

func _close() -> void:
        var hud_layer := get_parent()
        if hud_layer and hud_layer.has_method("_close_panels"):
                hud_layer._close_panels()
        else:
                queue_free()
