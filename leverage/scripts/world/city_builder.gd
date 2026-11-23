class_name CityBuilder
extends Node3D
## CityBuilder v2 - procedurally constructs Cinder City from the road graph in
## CityDirector: textured roads with lane markings, curbs, sidewalks, crosswalks,
## district-styled buildings (window emission ramps at night), streetlights,
## traffic lights, trees, parked cars and street furniture. MultiMesh batching
## per prop/building type (mobile draw-call budget); static box collision.

const BUILDING_TYPES := [
	"res://assets/buildings/b_brick2.glb",
	"res://assets/buildings/b_brick3.glb",
	"res://assets/buildings/b_brick4.glb",
	"res://assets/buildings/b_brick_tan.glb",
	"res://assets/buildings/b_ware1.glb",
	"res://assets/buildings/b_ware2.glb",
	"res://assets/buildings/b_ware3.glb",
	"res://assets/buildings/b_tower1.glb",
	"res://assets/buildings/b_tower2.glb",
	"res://assets/buildings/b_tower3.glb",
	"res://assets/buildings/b_shop1.glb",
	"res://assets/buildings/b_shop2.glb",
	"res://assets/buildings/b_shop3.glb",
	"res://assets/buildings/b_house1.glb",
	"res://assets/buildings/b_house2.glb",
	"res://assets/buildings/b_house3.glb",
	"res://assets/buildings/b_bank.glb",
	"res://assets/buildings/b_hospital.glb",
	"res://assets/buildings/b_hotel.glb",
]

const AREA_BIAS := {
	"old_quarter": [0, 1, 2, 3, 10, 11, 1, 2],
	"docklands": [4, 5, 6, 0, 4, 5],
	"kestrel_district": [7, 8, 9, 16, 7, 8],
	"neon_strip": [10, 11, 12, 18, 8, 10, 12],
	"ironworks": [5, 6, 4, 5],
	"heights": [13, 14, 15, 3, 13, 14],
}

const ROAD_W := 12.0
const SIDEWALK_W := 3.4
const CURB_H := 0.16
const BLOCK_MARGIN := 24.0

var _rng := RandomNumberGenerator.new()
var _buildings: Array = []
var collectible_positions: Array = []
var shop_positions := {}
var interior_positions := {}
var lamp_positions: Array = []          # for night lights (world.gd)
var road_network: Array = []            # segments shared with traffic

# ---------------------------------------------------------------- materials (shared, textured)
var _mat_asphalt: StandardMaterial3D
var _mat_curb: StandardMaterial3D
var _mat_pavement: StandardMaterial3D
var _mat_ground: StandardMaterial3D
var _mat_crosswalk: StandardMaterial3D

func _init() -> void:
	_mat_asphalt = _tex_mat("res://assets/textures/asphalt_albedo.png",
			"res://assets/textures/asphalt_normal.png", "res://assets/textures/asphalt_rough.png", 0.96)
	_mat_curb = _tex_mat("res://assets/textures/concrete_albedo.png",
			"res://assets/textures/concrete_normal.png", "res://assets/textures/concrete_rough.png", 0.95)
	_mat_pavement = _tex_mat("res://assets/textures/pavement_albedo.png",
			"res://assets/textures/pavement_normal.png", "res://assets/textures/pavement_rough.png", 0.96)
	_mat_ground = _tex_mat("res://assets/textures/grass_albedo.png", "", "res://assets/textures/grass_rough.png", 1.0)
	_mat_crosswalk = _tex_mat("res://assets/textures/crosswalk_albedo.png",
			"", "res://assets/textures/crosswalk_rough.png", 0.95)

static func _tex_mat(albedo: String, normal: String, rough: String, rough_scale: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if ResourceLoader.exists(albedo):
		mat.albedo_texture = load(albedo)
		mat.texture_repeat = true
	if normal != "" and ResourceLoader.exists(normal):
		mat.normal_texture = load(normal)
	if ResourceLoader.exists(rough):
		mat.roughness_texture = load(rough)
	mat.roughness = rough_scale
	mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
	return mat

# ---------------------------------------------------------------- build
func build(city_root: Node3D) -> void:
	_rng.seed = 20261123
	road_network = _expanded_roads()
	_build_ground(city_root)
	_build_roads(city_root)
	_build_city_blocks(city_root)
	_build_street_props(city_root)
	_build_parked_cars(city_root)
	_place_collectibles(city_root)
	_register_anchors()

func _expanded_roads() -> Array:
	# CityDirector.ROADS are the main avenues; add the district cross streets so
	# traffic, police and GPS all share one network.
	var roads: Array = CityDirector.ROADS.duplicate()
	var cross := [
		{"id": "oq_v1", "a": Vector2(-390, -380), "b": Vector2(-390, 125)},
		{"id": "oq_v2", "a": Vector2(-260, -380), "b": Vector2(-260, 125)},
		{"id": "oq_v3", "a": Vector2(-140, -380), "b": Vector2(-140, 125)},
		{"id": "oq_h1", "a": Vector2(-450, -300), "b": Vector2(-80, -300)},
		{"id": "oq_h2", "a": Vector2(-450, -180), "b": Vector2(-80, -180)},
		{"id": "oq_h3", "a": Vector2(-450, -60), "b": Vector2(-80, -60)},
		{"id": "dk_h1", "a": Vector2(-450, 120), "b": Vector2(-80, 120)},
		{"id": "dk_h2", "a": Vector2(-450, 240), "b": Vector2(-80, 240)},
		{"id": "dk_h3", "a": Vector2(-450, 360), "b": Vector2(-80, 360)},
		{"id": "dk_v1", "a": Vector2(-390, 30), "b": Vector2(-390, 470)},
		{"id": "ke_v1", "a": Vector2(140, -380), "b": Vector2(140, 125)},
		{"id": "ke_v2", "a": Vector2(260, -380), "b": Vector2(260, 125)},
		{"id": "ke_v3", "a": Vector2(380, -380), "b": Vector2(380, 125)},
		{"id": "ke_h1", "a": Vector2(80, -300), "b": Vector2(450, -300)},
		{"id": "ke_h2", "a": Vector2(80, -160), "b": Vector2(450, -160)},
		{"id": "ns_v1", "a": Vector2(200, -12), "b": Vector2(200, 420)},
		{"id": "ns_v2", "a": Vector2(320, -12), "b": Vector2(320, 420)},
		{"id": "ns_h1", "a": Vector2(80, 120), "b": Vector2(450, 120)},
		{"id": "ns_h2", "a": Vector2(80, 360), "b": Vector2(450, 360)},
	]
	roads.append_array(cross)
	return roads

func _build_ground(root: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2400, 2400)
	pm.subdivide_depth = 4
	pm.subdivide_width = 4
	mi.mesh = pm
	var mat := _mat_ground.duplicate()
	mat.albedo_color = Color(0.62, 0.68, 0.52)
	mat.uv1_scale = Vector3(90, 90, 90)
	mi.set_material_override(mat)
	mi.position = Vector3(0, -0.06, 0)
	root.add_child(mi)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2400, 0.1, 2400)
	cs.shape = box
	cs.position = Vector3(0, -0.11, 0)
	sb.add_child(cs)
	root.add_child(sb)

func _build_roads(root: Node3D) -> void:
	# per-road: asphalt strip w/ markings texture, curbs, sidewalks
	for road in road_network:
		var a: Vector2 = road["a"]
		var b: Vector2 = road["b"]
		var dir := (b - a).normalized()
		var length := (b - a).length()
		var center := (a + b) / 2.0
		var angle := atan2(dir.y, dir.x)
		var main_road := String(road["id"]) in ["main_cross", "civic_avenue", "bridge_avenue", "strip_road", "old_docks_road", "iron_spine"]
		var w := 14.0 if main_road else ROAD_W
		# asphalt with center-line texture
		var seg := _road_segment(length, w)
		seg.position = Vector3(center.x, 0.02, center.y)
		seg.rotation.y = -angle
		root.add_child(seg)
		# curbs + sidewalks
		var perp := Vector2(-dir.y, dir.x) * (w / 2.0 + SIDEWALK_W / 2.0)
		for sx in [-1.0, 1.0]:
			var walk := _sidewalk(length)
			walk.position = Vector3(center.x + perp.x * sx, CURB_H / 2.0, center.y + perp.y * sx)
			walk.rotation.y = -angle
			root.add_child(walk)
	# crosswalks at CityDirector intersections
	for isect in CityDirector.INTERSECTIONS:
		var p: Vector2 = isect["pos"]
		for k in 4:
			var cw := _crosswalk_quad()
			var ang := k * PI / 2.0 + 0.0
			cw.position = Vector3(p.x + sin(ang) * 10.0, 0.035, p.y + cos(ang) * 10.0)
			cw.rotation.y = ang
			root.add_child(cw)

func _road_segment(length: float, w: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(length, 0.04, w)
	mi.mesh = bm
	var mat := _mat_asphalt.duplicate()
	mat.uv1_scale = Vector3(length / 8.0, w / 12.0, 1.0)
	mi.set_material_override(mat)
	return mi

func _sidewalk(length: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(length, CURB_H, SIDEWALK_W)
	mi.mesh = bm
	var mat := _mat_pavement.duplicate()
	mat.uv1_scale = Vector3(length / 2.0, SIDEWALK_W / 2.0, 1.0)
	mi.set_material_override(mat)
	return mi

func _crosswalk_quad() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(6.5, 0.02, w_of(8.0))
	mi.mesh = bm
	var mat := _mat_crosswalk.duplicate()
	mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
	mi.set_material_override(mat)
	return mi

static func w_of(v: float) -> float:
	return v

# ---------------------------------------------------------------- buildings
func _build_city_blocks(root: Node3D) -> void:
	var per_type: Dictionary = {}
	for area_id in CityDirector.AREAS.keys():
		var rect: Rect2 = CityDirector.AREAS[area_id]["bounds"]
		var bias: Array = AREA_BIAS.get(area_id, [0, 1])
		var gx := rect.position.x + BLOCK_MARGIN
		while gx < rect.position.x + rect.size.x - BLOCK_MARGIN:
			var gz := rect.position.y + BLOCK_MARGIN
			while gz < rect.position.y + rect.size.y - BLOCK_MARGIN:
				var jitter := Vector2(_rng.randf_range(-5, 5), _rng.randf_range(-5, 5))
				var p := Vector2(gx, gz) + jitter
				if not _on_road_area(p, ROAD_W / 2.0 + SIDEWALK_W + 8.0) and not _too_close(p, 22.0):
					var type_idx: int = bias[_rng.randi_range(0, bias.size() - 1)]
					var rot: float = _rng.randf_range(-0.09, 0.09)
					if _rng.randf() < 0.5:
						rot += PI / 2.0
					if not per_type.has(type_idx):
						per_type[type_idx] = []
					per_type[type_idx].append({
						"pos": p, "rot": rot, "scale": _rng.randf_range(0.92, 1.15), "area": area_id,
					})
					_buildings.append({"pos": p, "type": type_idx, "area": area_id, "rot": rot})
				gz += 38.0
			gx += 38.0
	for type_idx in per_type.keys():
		_spawn_building_multimesh(root, BUILDING_TYPES[type_idx], per_type[type_idx], type_idx)
	_add_building_collisions(root)

func _on_road_area(p: Vector2, tol: float) -> bool:
	for road in road_network:
		var a: Vector2 = road["a"]
		var b: Vector2 = road["b"]
		var closest := _closest_seg(p, a, b)
		if p.distance_to(closest) <= tol:
			return true
	return false

func _closest_seg(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.001:
		return a
	var t: float = clamp((p - a).dot(ab) / l2, 0.0, 1.0)
	return a + ab * t

func _too_close(p: Vector2, min_d: float) -> bool:
	for b in _buildings:
		if (b["pos"] as Vector2).distance_to(p) < min_d:
			return true
	return false

func _spawn_building_multimesh(root: Node3D, glb: String, items: Array, type_idx: int) -> void:
	if not ResourceLoader.exists(glb) or items.size() == 0:
		return
	var packed: PackedScene = load(glb)
	var inst: Node3D = packed.instantiate()
	var mesh_inst: MeshInstance3D = _find_type(inst, "MeshInstance3D") as MeshInstance3D
	if mesh_inst == null or mesh_inst.mesh == null:
		inst.queue_free()
		return
	var mesh: Mesh = mesh_inst.mesh
	var mm := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = items.size()
	var y_off := 0.0
	for i in items.size():
		var it: Dictionary = items[i]
		var s: float = float(it["scale"])
		var xf := Transform3D(Basis(Vector3.UP, float(it["rot"])).scaled(Vector3(s, s, s)),
				Vector3((it["pos"] as Vector2).x, y_off, (it["pos"] as Vector2).y))
		multimesh.set_instance_transform(i, xf)
	mm.multimesh = multimesh
	# keep materials from the GLB mesh (window emission etc.)
	for si in mesh.get_surface_count():
		var mat := mesh.surface_get_material(si)
		if mat != null:
			mesh_inst.mesh.surface_set_material(si, mat)
	mm.multimesh.mesh = mesh
	root.add_child(mm)
	inst.queue_free()

func _add_building_collisions(root: Node3D) -> void:
	var sb := StaticBody3D.new()
	sb.name = "BuildingCollision"
	for b in _buildings:
		var type_idx: int = b["type"]
		var size := _building_footprint(type_idx)
		var rot: float = float(b.get("rot", 0.0))
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var swap := absf(absf(rot) - PI / 2.0) < 0.4
		var sx := size.y if swap else size.x
		var sz := size.x if swap else size.y
		box.size = Vector3(sx * 1.05, 26.0, sz * 1.05)
		cs.shape = box
		var p: Vector2 = b["pos"]
		cs.position = Vector3(p.x, 13.0, p.y)
		sb.add_child(cs)
	root.add_child(sb)

const BUILDING_FOOTPRINTS := [
	Vector2(12, 12), Vector2(13, 11), Vector2(12, 12), Vector2(11, 11),
	Vector2(16, 14), Vector2(20, 15), Vector2(18, 16), Vector2(14, 14),
	Vector2(12, 12), Vector2(16, 13), Vector2(10, 10), Vector2(12, 10),
	Vector2(14, 12), Vector2(9, 9), Vector2(11, 9), Vector2(10, 10),
	Vector2(15, 15), Vector2(18, 15), Vector2(16, 14),
]

func _building_footprint(type_idx: int) -> Vector2:
	return BUILDING_FOOTPRINTS[clamp(type_idx, 0, BUILDING_FOOTPRINTS.size() - 1)]

# ---------------------------------------------------------------- street props
func _build_street_props(root: Node3D) -> void:
	# streetlights along main roads
	var lamp_glbs := ["res://assets/props/streetlight_v2.glb", "res://assets/props/streetlight_d2.glb"]
	var lamp_positions: Array = []
	for road in road_network:
		var main_road := String(road["id"]) in ["main_cross", "civic_avenue", "bridge_avenue", "strip_road", "old_docks_road", "iron_spine", "ke_h1", "ns_h1"]
		var a: Vector2 = road["a"]
		var b: Vector2 = road["b"]
		var dir := (b - a).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var length := (b - a).length()
		var t := 18.0
		while t < length - 18.0:
			var side := 1.0 if int(t / 34.0) % 2 == 0 else -1.0
			var p := a + dir * t + perp * (ROAD_W / 2.0 + 2.6) * side
			lamp_positions.append({"pos": p, "rot": atan2(dir.y, dir.x) + PI})
			t += 34.0
	# spawn lamps as multimesh (both glb variants mixed by parity)
	_spawn_prop_multimesh(root, lamp_glbs[0], lamp_positions, 0.95)
	var d_pos: Array = []
	for li in lamp_positions.size():
		if li % 3 == 0:
			d_pos.append(lamp_positions[li])
	_spawn_prop_multimesh(root, lamp_glbs[1], d_pos, 0.95)
	self.lamp_positions = lamp_positions.map(func(i): return (i["pos"] as Vector2))
	# traffic lights at intersections
	var tl_positions: Array = []
	for isect in CityDirector.INTERSECTIONS:
		var p: Vector2 = isect["pos"]
		for k in 2:
			tl_positions.append({"pos": p + Vector2(9.0 + k * 2.0, -9.0 + k * 18.0), "rot": PI})
	_spawn_prop_multimesh(root, "res://assets/props/trafficlight_v2.glb", tl_positions, 1.0)
	# trees along sidewalks + in open ground
	var tree_positions: Array = []
	for road in road_network:
		var a: Vector2 = road["a"]
		var b: Vector2 = road["b"]
		var dir := (b - a).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var length := (b - a).length()
		var t := 12.0
		while t < length - 12.0:
			var side := 1.0 if int(t / 24.0) % 2 == 0 else -1.0
			var p := a + dir * t + perp * (ROAD_W / 2.0 + SIDEWALK_W + 1.2) * side
			if not _on_road_area(p, ROAD_W / 2.0 - 2.0) and not _too_close(p, 20.0):
				tree_positions.append({"pos": p, "rot": _rng.randf_range(0, TAU), "scale": _rng.randf_range(0.85, 1.2)})
			t += 24.0
	var tree_glbs := ["res://assets/props/tree_a.glb", "res://assets/props/tree_b.glb", "res://assets/props/tree_c.glb"]
	for gi in tree_glbs.size():
		var subset: Array = []
		for ti in tree_positions.size():
			if ti % 3 == gi:
				subset.append(tree_positions[ti])
		_spawn_prop_multimesh(root, tree_glbs[gi], subset, 1.0)
	# street furniture: bins, benches, hydrants, dumpsters
	var furniture := [
		["res://assets/props/bin.glb", 0, 12.0, 0.55],
		["res://assets/props/bench.glb", 0, 28.0, 0.45],
		["res://assets/props/hydrant.glb", 0, 44.0, 0.3],
		["res://assets/props/dumpster.glb", 0, 40.0, 0.3],
		["res://assets/props/busstop.glb", 0, 90.0, 0.16],
		["res://assets/props/billboard.glb", 0, 110.0, 0.12],
		["res://assets/props/barrier.glb", 0, 60.0, 0.22],
	]
	for f in furniture:
		var positions: Array = []
		var spacing: float = f[2]
		var prob: float = float(f[3])
		for road in road_network:
			var a: Vector2 = road["a"]
			var b: Vector2 = road["b"]
			var dir := (b - a).normalized()
			var perp := Vector2(-dir.y, dir.x)
			var length := (b - a).length()
			var t := spacing * 0.5
			while t < length - 12.0:
				if _rng.randf() < prob:
					var side := 1.0 if int(t / spacing) % 2 == 0 else -1.0
					var p := a + dir * t + perp * (ROAD_W / 2.0 + SIDEWALK_W * 0.55) * side
					if not _too_close(p, 14.0) and not _on_road_area(p, ROAD_W / 2.0 - 1.5):
						positions.append({"pos": p, "rot": atan2(dir.y, dir.x) + PI / 2.0})
				t += spacing
		_spawn_prop_multimesh(root, f[0], positions, 1.0)

func _spawn_prop_multimesh(root: Node3D, glb: String, items: Array, scale_f: float) -> void:
	if not ResourceLoader.exists(glb) or items.size() == 0:
		return
	var packed: PackedScene = load(glb)
	var inst: Node3D = packed.instantiate()
	var mi: MeshInstance3D = _find_type(inst, "MeshInstance3D") as MeshInstance3D
	if mi == null or mi.mesh == null:
		inst.queue_free()
		return
	var mesh: Mesh = mi.mesh
	var mm := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = items.size()
	for i in items.size():
		var it: Dictionary = items[i]
		var s: float = float(it.get("scale", scale_f)) * scale_f
		var xf := Transform3D(Basis(Vector3.UP, float(it.get("rot", 0.0))).scaled(Vector3(s, s, s)),
				Vector3((it["pos"] as Vector2).x, 0, (it["pos"] as Vector2).y))
		multimesh.set_instance_transform(i, xf)
	mm.multimesh = multimesh
	root.add_child(mm)
	inst.queue_free()

# ---------------------------------------------------------------- parked cars
func _build_parked_cars(root: Node3D) -> void:
	var car_glbs := ["res://assets/vehicles/sedan.glb", "res://assets/vehicles/hatch.glb",
		"res://assets/vehicles/suv.glb", "res://assets/vehicles/taxi.glb", "res://assets/vehicles/sport.glb"]
	var parked_count := 0
	for road in road_network:
		var a: Vector2 = road["a"]
		var b: Vector2 = road["b"]
		var dir := (b - a).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var length := (b - a).length()
		var t := 14.0
		while t < length - 14.0 and parked_count < 400:
			if _rng.randf() < 0.5:
				var side := 1.0 if _rng.randf() < 0.5 else -1.0
				var p := a + dir * t + perp * (ROAD_W / 2.0 - 1.35) * side
				if not _on_road_area(p, ROAD_W / 2.0 - 3.0):
					var glb: String = car_glbs[_rng.randi_range(0, car_glbs.size() - 1)]
					if ResourceLoader.exists(glb):
						var car: Node3D = (load(glb) as PackedScene).instantiate()
						var yaw := atan2(dir.y, dir.x) + (PI if side < 0 else 0.0)
						car.position = Vector3(p.x, 0.02, p.y)
						car.rotation.y = -yaw
						root.add_child(car)
						parked_count += 1
			t += 13.0

# ---------------------------------------------------------------- collectibles + anchors
func _place_collectibles(root: Node3D) -> void:
	var area_ids: Array = CityDirector.AREAS.keys()
	var per_area: int = int(floor(20.0 / float(area_ids.size())))
	var remainder: int = 20 - per_area * area_ids.size()
	for ai in area_ids.size():
		var area_id: String = String(area_ids[ai])
		var rect: Rect2 = CityDirector.AREAS[area_id]["bounds"]
		var quota: int = per_area + (1 if ai < remainder else 0)
		for i in quota:
			var p := rect.position + rect.size * Vector2(_rng.randf_range(0.15, 0.85), _rng.randf_range(0.15, 0.85))
			var token := _make_token(area_id + "_" + str(i), p)
			root.add_child(token)

func _make_token(cid: String, p: Vector2) -> Node3D:
	var holder := Node3D.new()
	holder.position = Vector3(p.x, 1.0, p.y)
	holder.add_to_group("interactable")
	holder.add_to_group("collectible")
	holder.set_meta("interact_text", "Collect Cinder Token")
	holder.set_meta("collectible_id", cid)
	var mi := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.22
	cy.bottom_radius = 0.22
	cy.height = 0.06
	mi.mesh = cy
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("f0a33c")
	mat.emission_enabled = true
	mat.emission = Color("f0a33c")
	mat.emission_energy_multiplier = 0.8
	mi.set_material_override(mat)
	mi.rotation_degrees.x = 90
	holder.add_child(mi)
	return holder

func _register_anchors() -> void:
	shop_positions = {
		"pawn": Vector3(-260, 0, -80),
		"threads": Vector3(320, 0, 200),
		"quickmart": Vector3(-140, 0, -60),
	}
	interior_positions = {
		"dez_apartment": Vector3(-280, 0, -160),
		"marisol_bar": Vector3(-240, 0, -180),
		"iron_gym": Vector3(-200, 0, 560),
		"lennox_clinic": Vector3(-120, 0, 20),
		"kestrel_lobby": Vector3(240, 0, -200),
	}

## Interiors are placed on a shelf zone (x +2000) and moved in when entered.
func build_interiors(root: Node3D) -> Dictionary:
	var zones := {}
	var z := interior_positions
	zones["dez_apartment"] = _make_room(root, "dez_apartment", Vector3(2000, 0, 0), 8.0,
			{"bed": "res://assets/interiors/bed.glb", "lamp": "res://assets/interiors/lamp.glb",
				"shelf": "res://assets/interiors/shelf.glb", "tv": "res://assets/interiors/tv.glb"})
	zones["marisol_bar"] = _make_room(root, "marisol_bar", Vector3(2100, 0, 0), 14.0,
			{"table": "res://assets/interiors/table.glb", "stool": "res://assets/interiors/stool.glb",
				"shelf": "res://assets/interiors/bookcase.glb", "sofa": "res://assets/interiors/sofa.glb"})
	zones["iron_gym"] = _make_room(root, "iron_gym", Vector3(2200, 0, 0), 16.0,
			{"bag": "res://assets/interiors/lamp.glb", "shelf": "res://assets/interiors/shelf.glb"})
	zones["lennox_clinic"] = _make_room(root, "lennox_clinic", Vector3(2300, 0, 0), 12.0,
			{"bed": "res://assets/interiors/bed.glb", "plant": "res://assets/interiors/plant.glb"})
	zones["kestrel_lobby"] = _make_room(root, "kestrel_lobby", Vector3(2400, 0, 0), 20.0,
			{"sofa": "res://assets/interiors/sofa.glb", "plant": "res://assets/interiors/plant.glb",
				"lamp": "res://assets/interiors/lamp.glb"})
	return zones

func _make_room(root: Node3D, room_id: String, origin: Vector3, size: float, props: Dictionary) -> Node3D:
	var room := Node3D.new()
	room.name = "Interior_" + room_id
	room.position = origin
	root.add_child(room)
	var floor_mi := MeshInstance3D.new()
	var fmesh := BoxMesh.new()
	fmesh.size = Vector3(size, 0.2, size)
	floor_mi.mesh = fmesh
	floor_mi.position = Vector3(0, 0.1, 0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color("26282e")
	floor_mi.set_material_override(fmat)
	room.add_child(floor_mi)
	var sb := StaticBody3D.new()
	room.add_child(sb)
	var floor_cs := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(size, 0.2, size)
	floor_cs.shape = fbox
	floor_cs.position = Vector3(0, 0.1, 0)
	sb.add_child(floor_cs)
	for w in 4:
		var wall_mi := MeshInstance3D.new()
		var wm := BoxMesh.new()
		var along_x := w < 2
		wm.size = Vector3(size if along_x else 0.2, 4.0, size if not along_x else 0.2)
		wall_mi.mesh = wm
		wall_mi.position = Vector3(0, 2.0, -size / 2.0 if w == 0 else size / 2.0 if w == 1 else 0)
		if w == 2 or w == 3:
			wall_mi.position = Vector3(-size / 2.0 if w == 2 else size / 2.0, 2.0, 0)
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color("1d1f24")
		wall_mi.set_material_override(wmat)
		room.add_child(wall_mi)
		var wcs := CollisionShape3D.new()
		var wbox := BoxShape3D.new()
		wbox.size = wm.size
		wcs.shape = wbox
		wcs.position = wall_mi.position
		sb.add_child(wcs)
	var i := 0
	for key in props.keys():
		var glb: String = props[key]
		if ResourceLoader.exists(glb):
			var packed: PackedScene = load(glb)
			var inst: Node3D = packed.instantiate()
			var ang: float = (float(i) * TAU) / float(max(1, props.size()))
			inst.position = Vector3(cos(ang) * size * 0.3, 0, sin(ang) * size * 0.3)
			inst.rotation.y = ang
			room.add_child(inst)
		i += 1
	var door := Node3D.new()
	door.position = Vector3(0, 0, size / 2.0)
	door.add_to_group("interactable")
	door.set_meta("interact_text", "Leave")
	door.set_meta("interior_exit", true)
	room.add_child(door)
	return room

func _find_type(node: Node, type: String) -> Node:
	if node.get_class() == type:
		return node
	for c in node.get_children():
		var r := _find_type(c, type)
		if r:
			return r
	return null
