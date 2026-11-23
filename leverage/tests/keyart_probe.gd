extends Node
## Key art probe - captures cinematic menu backgrounds from the REAL game
## world (dusk city, lamps lit, traffic on the avenue). Saves PNGs to
## assets/ui/keyart/ for the main menu + boot title cards.

var _t := 0.0
var _phase := 0
var _cam: Camera3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/ui/keyart")
	GameManager.start_new_game()
	_cam = Camera3D.new()
	_cam.fov = 44
	add_child(_cam)
	_make_current()

func _make_current() -> void:
	# kill the player's rig camera so ours drives the viewport
	var w := GameManager.world
	if w != null and w.camera_rig != null:
		w.camera_rig.current = false
	_cam.current = true

func _process(delta: float) -> void:
	_t += delta
	var w := GameManager.world
	if w == null:
		return
	if _phase == 0:
		# dusk lighting + hide gameplay UI
		TimeWeather._elapsed_hours = 18.35
		if w.hud != null:
			w.hud.visible = false
		if w.touch != null:
			w.touch.visible = false
		if w.player != null:
			w.player.visible = false
		_make_current()
		print("world: ", w != null, " player: ", w.player != null, " cam current: ", _cam.current)
		_phase = 1
		_t = 0.0
	elif _phase == 1 and _t > 1.0:
		_shot(0)
		_phase = 2
		_t = 0.0
	elif _phase == 2 and _t > 0.5:
		_shot(1)
		_phase = 3
		_t = 0.0
	elif _phase == 3 and _t > 0.5:
		_shot(2)
		print("KEYART COMPLETE")
		get_tree().quit(0)

func _shot(idx: int) -> void:
	var w := GameManager.world
	var p := Vector3(-252, 0, -164)
	if w.player != null:
		p = w.player.global_position
	match idx:
		0:
			# low rooftop vantage down the Old Quarter avenue at dusk
			_cam.global_position = p + Vector3(14, 16, 26)
			_cam.look_at(p + Vector3(-30, 0, -60), Vector3.UP)
		1:
			# street-level: lamps + storefronts
			_cam.global_position = p + Vector3(2, 2.2, 12)
			_cam.look_at(p + Vector3(-12, 1.5, -20), Vector3.UP)
		2:
			# skyline across the district
			_cam.global_position = p + Vector3(40, 26, 60)
			_cam.look_at(p + Vector3(-60, 2, -80), Vector3.UP)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://assets/ui/keyart/menu_bg_%d.png" % idx)
	print("KEYART SHOT ", idx)
