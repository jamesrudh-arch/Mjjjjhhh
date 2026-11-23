extends Node
## Vehicle visual probe - renders all rebuilt vehicles, 3/4 + side views.
const VEH := ["sedan", "hatch", "suv", "sport", "taxi", "cop", "motorcycle"]
var _t := 0.0
var _phase := 0
var _i := 0
var _cam: Camera3D
var _cur: Node3D

func _ready() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 25, 0)
	sun.light_energy = 1.4
	add_child(sun)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.33, 0.34, 0.33)
	g.set_material_override(gm)
	add_child(g)
	_cam = Camera3D.new()
	_cam.fov = 35
	add_child(_cam)
	_spawn()

func _spawn() -> void:
	if _i >= VEH.size():
		print("VEH PROBE COMPLETE")
		get_tree().quit(0)
		return
	var v = (load("res://assets/vehicles/%s.glb" % VEH[_i]) as PackedScene).instantiate()
	v.position = Vector3(0, 0, 0)
	add_child(v)
	_cur = v
	_phase = 0

func _process(delta: float) -> void:
	_t += delta
	if _cur == null:
		return
	match _phase:
		0:
			_cam.global_position = Vector3(-4.6, 2.1, -5.2)
			_cam.look_at(Vector3(0, 0.6, 0), Vector3.UP)
			if _t > 0.35:
				_shot(VEH[_i] + "_q34")
				_phase = 1
				_t = 0.0
		1:
			_cam.global_position = Vector3(0, 1.3, -7.5)
			_cam.look_at(Vector3(0, 0.7, 0), Vector3.UP)
			if _t > 0.3:
				_shot(VEH[_i] + "_side")
				_cur.queue_free()
				_i += 1
				_t = 0.0
				_spawn()

func _shot(nm: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://tests/render_out/veh_%s.png" % nm)
	print("SHOT veh_%s" % nm)
