extends Node
## Cast lineup probe - lateral rows to camera, sharp 1080p, face close-ups.
## Sandbox "Verified" evidence for the rebuilt cast.

const CAST := ["dez", "tommy", "marisol", "big_theo", "ava", "lucy_fang",
	"vito", "rizzo", "ren", "officer_brant", "doc_lennox", "nadia",
	"juno", "cabbie_moses", "enemy_thug", "enemy_brute"]

const FACES := ["dez", "marisol", "big_theo", "doc_lennox"]

var _t := 0.0
var _phase := 0
var _row := []
var _cam: Camera3D
var _face_i := 0

func _ready() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.5
	add_child(sun)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 60)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.32, 0.33, 0.31)
	g.set_material_override(gm)
	add_child(g)
	var i := 0
	for cid in CAST:
		var a := _make_character(cid)
		var row := i / 8
		var col := i % 8
		var scale_f := 1.0
		if cid in ["big_theo", "enemy_brute"]:
			scale_f = 1.1
		elif cid in ["rizzo"]:
			scale_f = 1.06
		elif cid in ["tommy", "juno", "ava"]:
			scale_f = 0.96
		a.scale = Vector3.ONE * scale_f
		a.position = Vector3(col * 2.6 - 9.1 - row * 1.4, 0, -row * 3.2)
		add_child(a)
		_row.append(a)
		i += 1
	_cam = Camera3D.new()
	_cam.fov = 46
	add_child(_cam)

func _make_character(cid: String) -> Node3D:
	var man := (load("res://assets/characters/ual_mannequin.glb") as PackedScene).instantiate()
	var body_path := "res://assets/characters/char_%s.glb" % cid
	if ResourceLoader.exists(body_path):
		var body := (load(body_path) as PackedScene).instantiate()
		var body_mi := _find(body, "Body")
		var man_mi := _find(man, "Mannequin")
		if body_mi and man_mi and body_mi.mesh:
			man_mi.mesh = body_mi.mesh
			if body_mi.skin:
				man_mi.skin = body_mi.skin
	return man

func _process(delta: float) -> void:
	_t += delta
	match _phase:
		0:
			if _t > 0.3:
				for a in _row:
					var ap := _find_anim(a)
					if ap:
						ap.play("Idle")
						ap.advance(0.5)
				_phase = 1
				_t = 0.0
		1:
			_cam.global_position = Vector3(0, 2.8, 16.2)
			_cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
			if _t > 0.4:
				_shot("cast_idle")
				_phase = 2
				_t = 0.0
				for a in _row:
					var ap := _find_anim(a)
					if ap:
						ap.play("Walk")
						ap.advance(0.7)
		2:
			if _t > 0.5:
				_shot("cast_walk")
				_phase = 3
				_t = 0.0
		3:
			# face close-ups of 4 characters
			var idx := CAST.find(FACES[_face_i])
			var a: Node3D = _row[idx]
			_cam.global_position = a.global_position + Vector3(0.75, 1.62, 1.35)
			_cam.look_at(a.global_position + Vector3(0, 1.55, 0), Vector3.UP)
			if _t > 0.25:
				_shot("face_" + FACES[_face_i])
				_face_i += 1
				_t = 0.0
				if _face_i >= FACES.size():
					print("CAST PROBE COMPLETE")
					get_tree().quit(0)

func _shot(nm: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://tests/render_out/%s.png" % nm)
	print("SHOT ", nm)

func _find(n: Node, nm: String) -> Node:
	if n is MeshInstance3D and String(n.name) == nm:
		return n
	for c in n.get_children():
		var r := _find(c, nm)
		if r:
			return r
	return null

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null
