extends Node
## BAProbe - before/after comparison probe. Fixed vantage cameras, dusk forced,
## HUD hidden, world content only. Shots land in LEVERAGE_PROBE_OUT.
## Deterministic: city seed + fixed camera transforms -> identical framing
## across code changes, so the only delta is the actual visual overhaul.

const VANTAGES := [
	{"name": "v1_street", "pos": Vector3(-200, 4.5, -128), "look": Vector3(-260, 6, -80), "fov": 66.0},
	{"name": "v2_skyline", "pos": Vector3(60, 46, -160), "look": Vector3(300, 10, 40), "fov": 58.0},
	{"name": "v3_strip", "pos": Vector3(232, 5.5, 210), "look": Vector3(300, 7, 300), "fov": 66.0},
]

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("[BA] start_new_game")
	GameManager.start_new_game()
	await get_tree().create_timer(2.0).timeout
	# force dusk in BOTH runs so lighting is comparable
	TimeWeather.force_hour(17.6)
	await get_tree().create_timer(1.5).timeout
	# neutralize the game camera
	var game_cam: Camera3D = get_viewport().get_camera_3d()
	if game_cam:
		game_cam.current = false
	var out_dir := OS.get_environment("LEVERAGE_PROBE_OUT")
	if out_dir == "":
		out_dir = "res://tests/render_out"
	for v in VANTAGES:
		var cam := Camera3D.new()
		cam.fov = float(v["fov"])
		add_child(cam)
		cam.global_position = v["pos"]
		cam.look_at(v["look"], Vector3.UP)
		cam.current = true
		# let a few frames render at this vantage (shader compile + settle)
		for i in 8:
			await get_tree().process_frame
		await get_tree().create_timer(1.2).timeout
		var img: Image = get_viewport().get_texture().get_image()
		var fname := "ba_%s.png" % v["name"]
		img.save_png(out_dir + "/" + fname)
		print("[BA] SHOT ", fname, " nodes=", get_tree().get_node_count())
		cam.current = false
		cam.queue_free()
	print("[BA] done")
	get_tree().quit(0)
