extends Node
## InputRouter - the ONE authoritative input interpretation layer.
## Raw canonical actions (action_x/action_y/action_a/action_b + moves) are
## translated into gameplay semantics based on the current context.
## On-screen touch controls and gamepad buttons both emit the canonical
## actions through Input.parse_input_event(), so gamepad, keyboard and touch
## behave identically. Combat mapping is fixed: X = punch, Y = heavy, A = kick,
## B = dodge. Outside combat: A = jump, B = contextual interact/vehicle exit.

enum Context { MENU, EXPLORE, COMBAT, VEHICLE, CUTSCENE, INTERIOR, AIM }

signal punch_pressed
signal heavy_pressed
signal kick_pressed
signal dodge_pressed
signal interact_pressed
signal jump_pressed
signal attack_pressed        # explore unarmed quick strike
signal enter_exit_pressed
signal handbrake_pressed
signal horn_pressed
signal aim_toggled(on: bool)
signal shoot_pressed
signal reload_pressed
signal weapon_next_pressed
signal weapon_prev_pressed
signal block_changed(on: bool)
signal crouch_toggled
signal lockon_toggled
signal pause_pressed
signal map_pressed
signal phone_pressed
signal skip_pressed

var context: int = Context.MENU
var ui_blocking: bool = false           # menus/dialogue capture input
var move_vector: Vector2 = Vector2.ZERO # x = right, y = forward(=up)
var camera_delta: Vector2 = Vector2.ZERO
var _touch_camera_delta: Vector2 = Vector2.ZERO
var _mouse_camera_delta: Vector2 = Vector2.ZERO
var _sprint_held: bool = false
var sprint_override: bool = false       # touch auto-sprint toggle
var crouch_held: bool = false
var aim_held: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_context(new_context: int) -> void:
	if context != new_context:
		context = new_context


func _process(delta: float) -> void:
	# --- Movement vector: canonical move actions support analog strength ---
	move_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_sprint_held = Input.is_action_pressed("sprint") or sprint_override
	crouch_held = Input.is_action_pressed("crouch")
	aim_held = Input.is_action_pressed("aim")

	# --- Camera contribution ---
	camera_delta = _touch_camera_delta + _mouse_camera_delta
	_touch_camera_delta = Vector2.ZERO
	_mouse_camera_delta = Vector2.ZERO

	if ui_blocking:
		_process_menu_context()
		return

	match context:
		Context.MENU, Context.CUTSCENE:
			_process_menu_context()
		Context.EXPLORE, Context.INTERIOR:
			_process_on_foot(false)
		Context.COMBAT, Context.AIM:
			_process_on_foot(true)
		Context.VEHICLE:
			_process_vehicle()


func _process_menu_context() -> void:
	if Input.is_action_just_pressed("pause"):
		pause_pressed.emit()
	if Input.is_action_just_pressed("action_x") and context == Context.CUTSCENE:
		skip_pressed.emit()


func _process_on_foot(combat: bool) -> void:
	if Input.is_action_just_pressed("pause"):
		pause_pressed.emit()
	if Input.is_action_just_pressed("map_open"):
		map_pressed.emit()
	if Input.is_action_just_pressed("phone"):
		phone_pressed.emit()
	if Input.is_action_just_pressed("lockon"):
		lockon_toggled.emit()
	if Input.is_action_just_pressed("crouch"):
		crouch_toggled.emit()
	if Input.is_action_just_pressed("reload"):
		reload_pressed.emit()
	if Input.is_action_just_pressed("weapon_next"):
		weapon_next_pressed.emit()
	if Input.is_action_just_pressed("weapon_prev"):
		weapon_prev_pressed.emit()
	if Input.is_action_just_pressed("interact_e"):
		interact_pressed.emit()

	if combat or aim_held:
		# FIXED combat mapping: X = punch, Y = heavy, A = kick, B = dodge
		if Input.is_action_just_pressed("action_x"):
			punch_pressed.emit()
		if Input.is_action_just_pressed("action_y"):
			heavy_pressed.emit()
		if Input.is_action_just_pressed("action_a"):
			kick_pressed.emit()
		if Input.is_action_just_pressed("action_b"):
			dodge_pressed.emit()
		if Input.is_action_just_pressed("shoot") and aim_held:
			shoot_pressed.emit()
		if Input.is_action_just_pressed("action_x") and aim_held and context != Context.COMBAT:
			shoot_pressed.emit()
	else:
		# Exploration mapping: A = jump, B = interact, X = attack, Y = draw weapon
		if Input.is_action_just_pressed("action_a"):
			jump_pressed.emit()
		if Input.is_action_just_pressed("action_b") or Input.is_action_just_pressed("interact_e"):
			interact_pressed.emit()
		if Input.is_action_just_pressed("action_x"):
			attack_pressed.emit()
		if Input.is_action_just_pressed("action_y"):
			enter_exit_pressed.emit()   # holsters / readies weapon handled by PlayerWeapons
	if Input.is_action_just_pressed("horn"):
		horn_pressed.emit()


func _process_vehicle() -> void:
	if Input.is_action_just_pressed("pause"):
		pause_pressed.emit()
	if Input.is_action_just_pressed("map_open"):
		map_pressed.emit()
	if Input.is_action_just_pressed("action_b"):
		enter_exit_pressed.emit()
	if Input.is_action_just_pressed("action_x"):
		handbrake_pressed.emit()
	if Input.is_action_just_pressed("horn"):
		horn_pressed.emit()


# ---- Virtual touch control API (called by on-screen UI) ----
func touch_camera_motion(delta: Vector2) -> void:
	_touch_camera_delta += delta


func touch_sprint(on: bool) -> void:
	sprint_override = on


func is_sprinting() -> bool:
	return _sprint_held


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_camera_delta += event.relative
		get_viewport().set_input_as_handled()
