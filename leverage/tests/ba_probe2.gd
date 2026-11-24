extends Node
## BAProbe v2 - low-memory before/after probe for weak sandboxes.
## Boots the real world, strips runtime agents (peds/traffic/police) and UI,
## forces dusk, then shoots 3 fixed cinematic vantages. Identical behavior
## in BEFORE (v2.4.0 tree) and AFTER (overhauled tree) runs.

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
	await get_tree().create_timer(2.5).timeout
	# --- slim down for the weak sandbox (identical in before/after) ---
	TimeWeather.force_hour(17.6)
	for director_name in ["NPCDirector", "PoliceSystem", "StreetEncounters", "WorldEvents"]:
		var d := get_tree().root.get_node_or_null(director_name)
		if d:
			d.set_process(false)
			d.set_physics_process(false)
	for group in ["pedestrian", "traffic_agent", "police_units"]:
		for n in get_tree().get_nodes_in_group(group):
			n.queue_free()
	# hide UI layers for clean world shots
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			n.visible = false
	await get_tree().create_timer(1.0).timeout
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
		for i in 6:
			await get_tree().process_frame
		await get_tree().create_timer(1.0).timeout
		var img: Image = get_viewport().get_texture().get_image()
		var fname := "ba_%s.png" % v["name"]
		img.save_png(out_dir + "/" + fname)
		print("[BA] SHOT ", fname)
		cam.current = false
		cam.queue_free()
	print("[BA] done")
	get_tree().quit(0)
