extends Node
## Isolation test: which combination renders/animates correctly?
## A: char_dez standalone (own skeleton + skin + no anim)
## B: mannequin + mesh-only swap (mannequin's skin retained)
## C: mannequin + mesh + skin swap (current broken pattern)
## All three play "Walk" after 0.5s; screenshots at t=1.5s mid-stride.

var _t := 0.0
var _shot := 0

func _ready() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.4, 0.4, 0.38)
	g.set_material_override(gm)
	add_child(g)

	# A: standalone
	var a := (load("res://assets/characters/char_dez.glb") as PackedScene).instantiate()
	a.position = Vector3(0, 0, 0)
	add_child(a)
	# B: mesh-only swap
	var man_b := (load("res://assets/characters/ual_mannequin.glb") as PackedScene).instantiate()
	man_b.position = Vector3(-2.2, 0, 0)
	add_child(man_b)
	_swap_body(man_b, false)
	# C: mesh + skin swap
	var man_c := (load("res://assets/characters/ual_mannequin.glb") as PackedScene).instantiate()
	man_c.position = Vector3(2.2, 0, 0)
	add_child(man_c)
	_swap_body(man_c, true)

	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.global_position = Vector3(0, 1.35, 6.5)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)

func _swap_body(man: Node3D, with_skin: bool) -> void:
	var body := (load("res://assets/characters/char_dez.glb") as PackedScene).instantiate()
	var body_mi := _find(body, "Body")
	var man_mi := _find(man, "Mannequin")
	if body_mi and man_mi:
		man_mi.mesh = body_mi.mesh
		if with_skin and body_mi.skin:
			man_mi.skin = body_mi.skin

func _process(delta: float) -> void:
	_t += delta
	if _t > 0.5 and _shot == 0:
		for n in get_children():
			var ap := _find_anim(n)
			if ap and ap.has_animation("Walk"):
				ap.play("Walk")
				ap.advance(0.9)
		_shot = 1
	if _t > 2.0 and _shot == 1:
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("res://tests/render_out/iso_test.png")
		print("SHOT iso_test")
		get_tree().quit(0)

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
