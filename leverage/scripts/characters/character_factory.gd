class_name CharacterFactory
extends RefCounted
## CharacterFactory v2 - realistic human actors. The UAL mannequin scene stays
## the animation+skeleton source (57 animations); each actor's mesh+skin is
## swapped with an authored body (char_*.glb, named binds -> same skeleton).
## All CC0 + original authored bodies (see asset_register.md).

const MANNEQUIN := "res://assets/characters/ual_mannequin.glb"

const BODY_PATHS := {
	"dez": "res://assets/characters/char_dez.glb",
	"tommy": "res://assets/characters/char_tommy.glb",
	"marisol": "res://assets/characters/char_marisol.glb",
	"big_theo": "res://assets/characters/char_big_theo.glb",
	"vito": "res://assets/characters/char_vito.glb",
	"rizzo": "res://assets/characters/char_rizzo.glb",
	"ava": "res://assets/characters/char_ava.glb",
	"ren": "res://assets/characters/char_ren.glb",
	"lucy_fang": "res://assets/characters/char_lucy_fang.glb",
	"officer_brant": "res://assets/characters/char_officer_brant.glb",
	"sergeant_oduya": "res://assets/characters/char_sergeant_oduya.glb",
	"doc_lennox": "res://assets/characters/char_doc_lennox.glb",
	"nadia": "res://assets/characters/char_nadia.glb",
	"juno": "res://assets/characters/char_juno.glb",
	"cabbie_moses": "res://assets/characters/char_cabbie_moses.glb",
	"enemy_punk": "res://assets/characters/char_enemy_punk.glb",
	"enemy_thug": "res://assets/characters/char_enemy_thug.glb",
	"enemy_soldier": "res://assets/characters/char_enemy_soldier.glb",
	"enemy_brute": "res://assets/characters/char_enemy_brute.glb",
	"enemy_knifer": "res://assets/characters/char_enemy_knifer.glb",
	"ped_m1": "res://assets/characters/char_ped_m1.glb",
	"ped_m2": "res://assets/characters/char_ped_m2.glb",
	"ped_m3": "res://assets/characters/char_ped_m3.glb",
	"ped_f1": "res://assets/characters/char_ped_f1.glb",
	"ped_f2": "res://assets/characters/char_ped_f2.glb",
	"ped_f3": "res://assets/characters/char_ped_f3.glb",
	"ped_w1": "res://assets/characters/char_ped_w1.glb",
	"ped_w2": "res://assets/characters/char_ped_w2.glb",
}

const PED_POOL := ["ped_m1", "ped_m2", "ped_m3", "ped_f1", "ped_f2", "ped_f3", "ped_w1", "ped_w2"]
const ENEMY_POOL := ["enemy_punk", "enemy_thug", "enemy_soldier", "enemy_brute", "enemy_knifer"]
const ROUGH_POOL := ["ped_w1", "enemy_punk", "enemy_thug"]   # docklands/ironworks peds

## Per-actor scale for silhouette variety (uniform node scale, animation-safe).
const SCALES := {
	"big_theo": 1.08, "enemy_brute": 1.08, "rizzo": 1.05, "vito": 0.99,
	"tommy": 0.96, "juno": 0.95, "ava": 0.96, "doc_lennox": 1.01,
	"enemy_punk": 0.97, "enemy_knifer": 0.96,
}

static var _body_cache := {}   # body_id -> {mesh: Mesh, skin: Skin}


static func _body_resources(body_id: String) -> Dictionary:
	if _body_cache.has(body_id):
		return _body_cache[body_id]
	var path: String = BODY_PATHS.get(body_id, "")
	if path == "" or not ResourceLoader.exists(path):
		_body_cache[body_id] = {}
		return _body_cache[body_id]
	var packed: PackedScene = load(path)
	var inst: Node3D = packed.instantiate()
	var body_mi: MeshInstance3D = _find(inst, "Body") as MeshInstance3D
	var out := {}
	if body_mi and body_mi.mesh:
		out = {"mesh": body_mi.mesh, "skin": body_mi.skin}
	inst.queue_free()
	_body_cache[body_id] = out
	return out


## Build an actor: mannequin scene (skeleton + 57 animations) with the
## authored body mesh swapped in (named skin binds -> identical DEF-* rig).
static func make_actor(body_id: String, scale_f := 1.0) -> Node3D:
	var packed: PackedScene = load(MANNEQUIN)
	if packed == null:
		push_error("CharacterFactory: mannequin missing")
		return Node3D.new()
	var inst: Node3D = packed.instantiate()
	var res := _body_resources(body_id)
	if not res.is_empty():
		var man_mi: MeshInstance3D = _find(inst, "Mannequin") as MeshInstance3D
		if man_mi != null:
			man_mi.mesh = res["mesh"]
			if res.get("skin"):
				man_mi.skin = res["skin"]
			man_mi.name = "Body"
	scale_f *= float(SCALES.get(body_id, 1.0))
	if absf(scale_f - 1.0) > 0.001:
		inst.scale = Vector3.ONE * scale_f
	return inst


## Random tinted-scale pedestrian from the authored pool.
static func make_random_ped(rng: RandomNumberGenerator) -> Node3D:
	var pool := PED_POOL
	if rng.randf() < 0.18:
		pool = ROUGH_POOL
	var id: String = pool[rng.randi_range(0, pool.size() - 1)]
	return make_actor(id, rng.randf_range(0.97, 1.03))


## Random enemy from the enemy cast.
static func make_random_enemy(rng: RandomNumberGenerator) -> Node3D:
	return make_actor(ENEMY_POOL[rng.randi_range(0, ENEMY_POOL.size() - 1)])


## Named-cast actor: body id == npc id.
static func make_named(npc_id: String) -> Node3D:
	if BODY_PATHS.has(npc_id):
		return make_actor(npc_id)
	return make_random_ped(RandomNumberGenerator.new())


## Player actor (Dez): amber jacket signature look.
static func make_player() -> Node3D:
	return make_actor("dez")


## Accessories are baked into the authored bodies (caps, fedoras, hair).
## Kept for API compatibility; attaches only a held item to the hand.
static func attach_accessory(actor: Node3D, kind: String, color: Color) -> Node3D:
	if kind == "holster":
		return attach_to_hand(actor, null)
	return null


## Attach a held item (weapon) to the right hand.
static func attach_to_hand(actor: Node3D, mesh: Mesh, offset := Vector3(0.04, 0.02, 0.05)) -> Node3D:
	if mesh == null:
		return null
	var sk: Skeleton3D = _find_type(actor, "Skeleton3D") as Skeleton3D
	if sk == null:
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = "DEF-hand.R"
	att.name = "BoneAtt_hand"
	sk.add_child(att)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = offset
	att.add_child(mi)
	return mi


static func hand_mesh_from_glb(glb_path: String, scale_factor: float, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if ResourceLoader.exists(glb_path):
		var packed: PackedScene = load(glb_path)
		var inst: Node3D = packed.instantiate()
		var src: MeshInstance3D = _find_type(inst, "MeshInstance3D") as MeshInstance3D
		if src and src.mesh:
			mi.mesh = src.mesh
		inst.queue_free()
	mi.scale = Vector3.ONE * scale_factor
	mi.rotation_degrees = rot
	return mi


static func _find(node: Node, n: String) -> Node:
	if node is MeshInstance3D and String(node.name) == n:
		return node
	for c in node.get_children():
		var r := _find(c, n)
		if r:
			return r
	return null


static func _find_type(node: Node, type: String) -> Node:
	if node.get_class() == type:
		return node
	for c in node.get_children():
		var r := _find_type(c, type)
		if r:
			return r
	return null
