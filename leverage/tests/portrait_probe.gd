extends Node
## Portrait generator - renders head shots of every named character from the
## rebuilt bodies for use as phone contact portraits. Output 256x256 PNGs.

const CAST := ["dez", "tommy", "marisol", "big_theo", "vito", "rizzo", "ava", "ren",
	"lucy_fang", "officer_brant", "sergeant_oduya", "doc_lennox", "nadia", "juno",
	"cabbie_moses", "the_tipster"]
const OUT := "res://assets/ui/portraits"

var _t := 0.0
var _i := 0
var _cam: Camera3D
var _cur: Node3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 20, 0)
	sun.light_energy = 1.6
	add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 30
	add_child(_cam)
	_spawn()

func _spawn() -> void:
	if _i >= CAST.size():
		print("PORTRAITS COMPLETE")
		get_tree().quit(0)
		return
	var cid: String = CAST[_i]
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
	add_child(man)
	_cur = man
	_cam.global_position = Vector3(0.55, 1.62, 0.95)
	_cam.look_at(Vector3(0, 1.58, 0), Vector3.UP)
	_t = 0.0

func _process(delta: float) -> void:
	_t += delta
	if _t > 0.3:
		var img: Image = get_viewport().get_texture().get_image()
		if img.get_width() != 256:
			img.resize(256, 256, Image.INTERPOLATE_LANCZOS)
		img.save_png("%s/%s.png" % [OUT, CAST[_i]])
		print("PORTRAIT: ", CAST[_i])
		_cur.queue_free()
		_i += 1
		_spawn()

func _find(n: Node, nm: String) -> Node:
	if n is MeshInstance3D and String(n.name) == nm:
		return n
	for c in n.get_children():
		var r := _find(c, nm)
		if r:
			return r
	return null
