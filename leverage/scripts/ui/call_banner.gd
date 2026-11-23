class_name CallBanner
extends Control
## CallBanner - the in-game phone ringing overlay. Appears over gameplay when
## PhoneSystem rings: caller portrait + name, pulsing ring animation,
## ANSWER / DECLINE buttons, active-call state with HANG UP. Never blocks the
## game (input passthrough on the backdrop).

var _phone: PhoneSystem
var _panel: PanelContainer
var _portrait: TextureRect
var _name: Label
var _line: Label
var _pulse := 0.0
var _answer: Button
var _decline: Button
var _hangup: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false


func bind_phone(phone: PhoneSystem) -> void:
	_phone = phone
	phone.call_ringing.connect(_on_ringing)
	phone.call_connected.connect(_on_connected)
	phone.call_ended.connect(func(_from, _outcome): _hide())


func _build() -> void:
	# top banner strip (leaves the world visible + playable below)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.position = Vector2(560, 40)
	_panel.add_theme_stylebox_override("panel", LvgTheme.panel_style(LvgTheme.PANEL_LIFT, LvgTheme.ACCENT))
	add_child(_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	_panel.add_child(hb)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(96, 96)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(_portrait)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	hb.add_child(col)
	_name = LvgTheme.make_label("INCOMING CALL", 30, LvgTheme.ACCENT, true)
	col.add_child(_name)
	_line = LvgTheme.make_label("", 22, LvgTheme.TEXT_DIM)
	col.add_child(_line)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 14)
	hb.add_child(btns)
	_answer = LvgTheme.make_button("ANSWER")
	_answer.pressed.connect(func():
		if _phone != null:
			_phone.answer())
	btns.add_child(_answer)
	_decline = LvgTheme.make_button("DECLINE")
	_decline.pressed.connect(func():
		if _phone != null:
			_phone.decline())
	btns.add_child(_decline)
	_hangup = LvgTheme.make_button("END CALL")
	_hangup.pressed.connect(func():
		if _phone != null:
			_phone.hang_up())
	btns.add_child(_hangup)
	_hangup.visible = false


func _process(delta: float) -> void:
	if not visible or _phone == null:
		return
	_pulse += delta
	if _phone.is_ringing():
		_answer.visible = true
		_decline.visible = true
		_hangup.visible = false
		_panel.modulate = Color(1.0, 1.0, 1.0, 0.75 + 0.25 * sin(_pulse * 7.0))
		_line.text = "incoming call... (%.0fs)" % maxf(0.0, 14.0 - _phone._ring_t)
	elif _phone.is_active():
		_answer.visible = false
		_decline.visible = false
		_hangup.visible = true
		_panel.modulate = Color.WHITE
		_line.text = "call in progress - subtitles below"


func _on_ringing(from_id: String, _call_id: String) -> void:
	visible = true
	_name.text = NPCDirector.cast_display(from_id).to_upper()
	_line.text = "incoming call..."
	var path := "res://assets/ui/portraits/%s.png" % from_id
	if ResourceLoader.exists(path):
		_portrait.texture = load(path)
	else:
		_portrait.texture = null


func _on_connected(from_id: String) -> void:
	_name.text = "ON CALL - " + NPCDirector.cast_display(from_id).to_upper()


func _hide() -> void:
	visible = false
