class_name TouchControls
extends CanvasLayer
## TouchControls - the on-screen virtual gamepad. Emits the SAME canonical
## Input actions as a physical pad via Input.parse_input_event(), so
## gamepad/keyboard/touch behave identically (TDL #8). Landscape layout
## 2688x1242; buttons >= 110 px.

const BTN_SIZE := 120.0
const JOY_RADIUS := 150.0

var _root: Control
var _joy_base: Control
var _joy_knob: Control
var _joy_center := Vector2(250, 880)
var _joy_active := false
var _joy_id := -1
var _look_zone: Control
var _look_id := -1
var _look_last := Vector2.ZERO
var _buttons := {}                      # label -> TouchButton data {node, action}
var _pedal_accel: Control
var _pedal_brake: Control
var _vehicle_mode := false
var _context_explore := true
var _auto_sprint := false
var _chips := {}                       # map/phone/pause chip nodes


class TouchButton:
        extends Control
        var label := ""
        var action := ""
        var pressed := false
        var hold := false
        var on_tap: Callable = Callable()
        var _t := 0.0


func _ready() -> void:
        layer = 20
        _build()
        _watch_context()


func _build() -> void:
        _root = Control.new()
        _root.set_anchors_preset(Control.PRESET_FULL_RECT)
        add_child(_root)
        # -- virtual joystick (left zone) --
        _joy_base = Control.new()
        _joy_base.position = _joy_center - Vector2(JOY_RADIUS * 0.55, JOY_RADIUS * 0.55)
        _joy_base.custom_minimum_size = Vector2(JOY_RADIUS * 1.1, JOY_RADIUS * 1.1)
        _joy_base.mouse_filter = Control.MOUSE_FILTER_STOP
        var draw := Control.new()
        draw.set_anchors_preset(Control.PRESET_FULL_RECT)
        draw.draw.connect(func():
                var c: Vector2 = _joy_base.size / 2.0
                draw.draw_circle(c, JOY_RADIUS * 0.55, Color(0.06, 0.06, 0.07, 0.5))
                draw.draw_arc(c, JOY_RADIUS * 0.55, 0, TAU, 48, Color(0.3, 0.31, 0.36, 0.8), 3.0)
        )
        _joy_base.add_child(draw)
        _root.add_child(_joy_base)
        _joy_knob = Control.new()
        _joy_knob.custom_minimum_size = Vector2(110, 110)
        _joy_knob.position = _joy_center - Vector2(55, 55)
        var knob_draw := Control.new()
        knob_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
        knob_draw.draw.connect(func():
                var c: Vector2 = _joy_knob.size / 2.0
                draw_circle_on(knob_draw, c, 48.0, Color("f0a33c") if _joy_active else Color("3a3b41"))
        )
        _joy_knob.add_child(knob_draw)
        _root.add_child(_joy_knob)
        # -- camera look zone (right half) --
        _look_zone = Control.new()
        _look_zone.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
        _look_zone.mouse_filter = Control.MOUSE_FILTER_STOP
        _root.add_child(_look_zone)
        # -- action buttons diamond (right) --
        _add_button("X", "action_x", Vector2(1080, 860), LvgTheme.PANEL_LIFT)
        _add_button("Y", "action_y", Vector2(1180, 700), LvgTheme.PANEL_LIFT)
        _add_button("B", "action_b", Vector2(1320, 900), LvgTheme.PANEL_LIFT)
        _add_button("A", "action_a", Vector2(1180, 1040), LvgTheme.PANEL_LIFT)
        # -- top-right chips: map / phone / pause --
        _add_chip("MAP", Vector2(2200, 30), func(): InputRouter.map_pressed.emit())
        _add_chip("PHONE", Vector2(2350, 30), func(): InputRouter.phone_pressed.emit())
        _add_chip("II", Vector2(2500, 30), func(): InputRouter.pause_pressed.emit())
        # -- sprint toggle (above joystick) --
        _add_chip("RUN", Vector2(130, 640), func(): _toggle_sprint())
        # -- vehicle pedals --
        _pedal_accel = _make_pedal("GAS", Vector2(2330, 980), Color("3a5a3a"))
        _pedal_brake = _make_pedal("BRK", Vector2(2170, 1060), Color("5a3a3a"))
        _set_vehicle_mode(false)


func _toggle_sprint() -> void:
        _auto_sprint = not _auto_sprint
        InputRouter.touch_sprint(_auto_sprint)
        if _chips.has("RUN") and is_instance_valid(_chips["RUN"]):
                (_chips["RUN"] as Control).modulate = Color(1.4, 1.4, 1.4) if _auto_sprint else Color.WHITE


func draw_circle_on(ctrl: Control, c: Vector2, r: float, color: Color) -> void:
        ctrl.draw_circle(c, r, color)
        ctrl.draw_arc(c, r, 0, TAU, 40, Color(0.2, 0.2, 0.22), 4.0)


func _add_button(txt: String, action: String, pos: Vector2, color: Color) -> void:
        var b := TouchButton.new()
        b.label = txt
        b.action = action
        b.position = pos
        b.custom_minimum_size = Vector2(BTN_SIZE, BTN_SIZE)
        var bd := Control.new()
        bd.set_anchors_preset(Control.PRESET_FULL_RECT)
        bd.draw.connect(func():
                var c: Vector2 = b.size / 2.0
                var col := color if not b.pressed else Color("f0a33c")
                bd.draw_circle(c, 52.0, Color(0.07, 0.07, 0.08, 0.55))
                bd.draw_arc(c, 52.0, 0, TAU, 40, col, 5.0)
        )
        b.add_child(bd)
        var l := LvgTheme.make_display_label(txt, 40, LvgTheme.TEXT)
        l.set_anchors_preset(Control.PRESET_CENTER)
        b.add_child(l)
        _root.add_child(b)
        _buttons[txt] = b


func _add_chip(txt: String, pos: Vector2, cb: Callable) -> void:
        var b := Button.new()
        b.text = txt
        b.position = pos
        b.custom_minimum_size = Vector2(150, 64)
        var st := LvgTheme.button_style()
        b.add_theme_stylebox_override("normal", st["normal"])
        b.add_theme_stylebox_override("hover", st["hover"])
        b.add_theme_stylebox_override("pressed", st["pressed"])
        b.add_theme_font_override("font", LvgTheme.font_body_bold)
        b.add_theme_font_size_override("font_size", 26)
        b.add_theme_color_override("font_color", LvgTheme.TEXT)
        b.add_theme_color_override("font_pressed_color", Color.WHITE)
        b.pressed.connect(cb)
        _root.add_child(b)
        _chips[txt] = b


func _make_pedal(txt: String, pos: Vector2, color: Color) -> Control:
        var p := Button.new()
        p.text = txt
        p.position = pos
        p.custom_minimum_size = Vector2(170, 110)
        var st := LvgTheme.button_style()
        p.add_theme_stylebox_override("normal", st["normal"])
        p.add_theme_stylebox_override("pressed", st["pressed"])
        p.add_theme_font_override("font", LvgTheme.font_body_bold)
        p.add_theme_font_size_override("font_size", 28)
        p.add_theme_color_override("font_color", Color("d0d0d0"))
        if txt == "GAS":
                p.button_down.connect(func(): _send_axis("move_up", 1.0))
                p.button_up.connect(func(): _send_axis("move_up", 0.0))
        else:
                p.button_down.connect(func(): _send_axis("move_down", 1.0))
                p.button_up.connect(func(): _send_axis("move_down", 0.0))
        _root.add_child(p)
        return p


func _watch_context() -> void:
        set_process(true)


func _set_vehicle_mode(on: bool) -> void:
        _vehicle_mode = on
        _pedal_accel.visible = on
        _pedal_brake.visible = on
        # re-label buttons for vehicle context
        if on:
                _set_button_label("X", "HB")      # handbrake
                _set_button_label("B", "OUT")     # exit
                _set_button_label("A", "GO")      # unused in vehicle
                _set_button_label("Y", "RADIO")
        else:
                _set_button_label("X", "X")
                _set_button_label("B", "B")
                _set_button_label("A", "A")
                _set_button_label("Y", "Y")


func _set_button_label(key: String, txt: String) -> void:
        var b: TouchButton = _buttons.get(key, null)
        if b == null:
                return
        for c in b.get_children():
                if c is Label:
                        (c as Label).text = txt


func _process(_delta: float) -> void:
        # context watch
        var want_vehicle: bool = InputRouter.context == InputRouter.Context.VEHICLE
        if want_vehicle != _vehicle_mode:
                _set_vehicle_mode(want_vehicle)
        var combat: bool = InputRouter.context == InputRouter.Context.COMBAT or InputRouter.context == InputRouter.Context.AIM
        if combat != _context_explore:
                _context_explore = combat
                _style_for_context(combat)


func _style_for_context(combat: bool) -> void:
        for key in _buttons.keys():
                var b: TouchButton = _buttons[key]
                b.modulate = Color("f0a33c") if combat else Color.WHITE


func _gui_input_to_action(action: String, pressed_val: bool) -> void:
        var ev := InputEventAction.new()
        ev.action = action
        ev.pressed = pressed_val
        Input.parse_input_event(ev)


# ---------------- touch handling ----------------
func _input(event: InputEvent) -> void:
        if event is InputEventScreenTouch:
                _on_touch(event as InputEventScreenTouch)
        elif event is InputEventScreenDrag:
                _on_drag(event as InputEventScreenDrag)


func _on_touch(ev: InputEventScreenTouch) -> void:
        var pos := ev.position
        # button hit test
        for key in _buttons.keys():
                var b: TouchButton = _buttons[key]
                if b.visible and _hit(b, pos):
                        if ev.pressed and not b.pressed:
                                b.pressed = true
                                _gui_input_to_action(b.action, true)
                        elif not ev.pressed and b.pressed:
                                b.pressed = false
                                _gui_input_to_action(b.action, false)
                        return
        # joystick
        if ev.pressed and pos.distance_to(_joy_center) < JOY_RADIUS * 1.3:
                _joy_active = true
                _joy_id = ev.index
                _joy_knob.position = pos - Vector2(55, 55)
        elif not ev.pressed and ev.index == _joy_id:
                _joy_active = false
                _joy_id = -1
                _joy_knob.position = _joy_center - Vector2(55, 55)
                _emit_move(Vector2.ZERO)
        # look zone
        if ev.pressed and InputRouter.ui_blocking == false and pos.x > 1000.0 and pos.y < 900.0 and not _hit_any_button(pos):
                _look_id = ev.index
                _look_last = pos
        elif not ev.pressed and ev.index == _look_id:
                _look_id = -1


func _on_drag(ev: InputEventScreenDrag) -> void:
        var pos := ev.position
        if ev.index == _joy_id and _joy_active:
                var d := pos - _joy_center
                var clamped := d.limit_length(JOY_RADIUS * 0.55)
                _joy_knob.position = _joy_center + clamped - Vector2(55, 55)
                _emit_move(Vector2(clamped.x / (JOY_RADIUS * 0.55), -clamped.y / (JOY_RADIUS * 0.55)))
        elif ev.index == _look_id:
                var delta := pos - _look_last
                _look_last = pos
                InputRouter.touch_camera_motion(Vector2(delta.x, delta.y * 0.7))


func _emit_move(v: Vector2) -> void:
        # analog strength via action strength emulation: send move_left/right/up/down
        _send_axis("move_left", clamp(-v.x, 0.0, 1.0))
        _send_axis("move_right", clamp(v.x, 0.0, 1.0))
        _send_axis("move_up", clamp(v.y, 0.0, 1.0))
        _send_axis("move_down", clamp(-v.y, 0.0, 1.0))


func _send_axis(action: String, strength: float) -> void:
        var ev := InputEventAction.new()
        ev.action = action
        ev.strength = strength
        ev.pressed = strength > 0.05
        Input.parse_input_event(ev)


func _hit(b: Control, pos: Vector2) -> bool:
        var rect := Rect2(b.global_position, b.size * b.get_global_transform().get_scale())
        return rect.has_point(pos)


func _hit_any_button(pos: Vector2) -> bool:
        for key in _buttons.keys():
                if _hit(_buttons[key], pos):
                        return true
        for key in _chips.keys():
                if _chips[key] is Control and _hit(_chips[key], pos):
                        return true
        return false
