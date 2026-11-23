class_name CityBuilder
extends Node3D
## CityBuilder - procedurally constructs Cinder City from the road graph in
## CityDirector and building/prop GLBs. MultiMesh batching per building type
## (TDL #6: mobile draw-call budget); collision via static box shapes.

const BUILDING_TYPES := [
        "res://assets/buildings/b1story.glb",
        "res://assets/buildings/b2story.glb",
        "res://assets/buildings/b2bal.glb",
        "res://assets/buildings/b2sign.glb",
        "res://assets/buildings/b2wide.glb",
        "res://assets/buildings/b3bal.glb",
        "res://assets/buildings/b3slim.glb",
        "res://assets/buildings/bank.glb",
        "res://assets/buildings/shop.glb",
        "res://assets/buildings/hospital.glb",
        "res://assets/buildings/house.glb",
        "res://assets/buildings/house2.glb",
        "res://assets/buildings/flat.glb",
        "res://assets/buildings/flat2.glb",
]

const ROADS := [
        {"id": "main_cross", "a": Vector2(-450, -10), "b": Vector2(450, -10)},
        {"id": "civic_avenue", "a": Vector2(10, -720), "b": Vector2(10, 420)},
        {"id": "hill_road", "a": Vector2(-120, -420), "b": Vector2(0, -720)},
        {"id": "bridge_avenue", "a": Vector2(80, -200), "b": Vector2(450, -200)},
        {"id": "old_docks_road", "a": Vector2(-450, 30), "b": Vector2(-80, 30)},
        {"id": "iron_spine", "a": Vector2(-80, 420), "b": Vector2(-420, 460)},
        {"id": "strip_road", "a": Vector2(80, 230), "b": Vector2(450, 230)},
]

const ROAD_W := 12.0
const SIDEWALK_W := 3.0
const BLOCK_MARGIN := 22.0

var _rng := RandomNumberGenerator.new()
var _buildings: Array = []            # {pos, size, type_idx, area}
var collectible_positions: Array = []
var shop_positions := {}
var interior_positions := {}


func build(city_root: Node3D) -> void:
        _rng.seed = 20261123
        _build_ground(city_root)
        _build_roads(city_root)
        _build_city_blocks(city_root)
        _build_street_props(city_root)
        _place_collectibles(city_root)


func _build_ground(root: Node3D) -> void:
        var mi := MeshInstance3D.new()
        var pm := PlaneMesh.new()
        pm.size = Vector2(2400, 2400)
        mi.mesh = pm
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color("1a1b1f")
        mat.roughness = 1.0
        mi.set_material_override(mat)
        mi.position = Vector3(0, -0.05, 0)
        root.add_child(mi)
        var sb := StaticBody3D.new()
        var cs := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = Vector3(2400, 0.1, 2400)
        cs.shape = box
        cs.position = Vector3(0, -0.1, 0)
        sb.add_child(cs)
        root.add_child(sb)


func _build_roads(root: Node3D) -> void:
        var road_mat := StandardMaterial3D.new()
        road_mat.albedo_color = Color("2b2c31")
        road_mat.roughness = 0.95
        var walk_mat := StandardMaterial3D.new()
        walk_mat.albedo_color = Color("3a3b41")
        walk_mat.roughness = 1.0
        for road in ROADS:
                var a: Vector2 = road["a"]
                var b: Vector2 = road["b"]
                var dir := (b - a).normalized()
                var length := (b - a).length()
                var center := (a + b) / 2.0
                var angle := atan2(dir.y, dir.x)
                # road surface (thin box, slightly above ground)
                _add_box(root, center, angle, length, ROAD_W, 0.02, road_mat)
                # sidewalks both sides
                var perp := Vector2(-dir.y, dir.x) * (ROAD_W / 2.0 + SIDEWALK_W / 2.0)
                _add_box(root, center + perp, angle, length, SIDEWALK_W, 0.14, walk_mat)
                _add_box(root, center - perp, angle, length, SIDEWALK_W, 0.14, walk_mat)


func _add_box(root: Node3D, center2: Vector2, angle_y: float, size_along: float, size_across: float, h: float, mat: Material) -> void:
        var mi := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(size_along, h, size_across)
        mi.mesh = bm
        mi.set_material_override(mat)
        mi.position = Vector3(center2.x, h / 2.0, center2.y)
        mi.rotation.y = -angle_y
        root.add_child(mi)


func _on_road_area(p: Vector2, tol: float) -> bool:
        for road in ROADS:
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


func _build_city_blocks(root: Node3D) -> void:
        ## Grid placement per area rect, skip road strips, pick building type
        ## biased by area identity.
        var area_bias := {
                "old_quarter": [0, 1, 2, 3, 7, 10],
                "docklands": [6, 8, 12, 13],
                "kestrel_district": [5, 6, 8, 13],
                "neon_strip": [3, 2, 9, 13],
                "ironworks": [6, 12, 13, 8],
                "heights": [10, 11, 4],
        }
        var per_type: Dictionary = {}   # type_idx -> Array of {pos, rot, scale}
        for area_id in CityDirector.AREAS.keys():
                var rect: Rect2 = CityDirector.AREAS[area_id]["bounds"]
                var bias: Array = area_bias.get(area_id, [0, 1])
                var gx := rect.position.x + BLOCK_MARGIN
                while gx < rect.position.x + rect.size.x - BLOCK_MARGIN:
                        var gz := rect.position.y + BLOCK_MARGIN
                        while gz < rect.position.y + rect.size.y - BLOCK_MARGIN:
                                var jitter := Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
                                var p := Vector2(gx, gz) + jitter
                                if not _on_road_area(p, ROAD_W / 2.0 + SIDEWALK_W + 6.0) and not _too_close(p, 18.0):
                                        var type_idx: int = bias[_rng.randi_range(0, bias.size() - 1)]
                                        if not per_type.has(type_idx):
                                                per_type[type_idx] = []
                                        per_type[type_idx].append({
                                                "pos": p,
                                                "rot": _rng.randf_range(-0.12, 0.12),
                                                "scale": _rng.randf_range(0.9, 1.25),
                                                "area": area_id,
                                        })
                                        _buildings.append({"pos": p, "type": type_idx, "area": area_id})
                                gz += 34.0
                        gx += 34.0
        # MultiMesh per type
        for type_idx in per_type.keys():
                var glb: String = BUILDING_TYPES[type_idx]
                var items: Array = per_type[type_idx]
                _spawn_building_multimesh(root, glb, items)
        # Collision boxes per placed building
        _add_building_collisions(root)


func _too_close(p: Vector2, min_d: float) -> bool:
        for b in _buildings:
                if (b["pos"] as Vector2).distance_to(p) < min_d:
                        return true
        return false


func _spawn_building_multimesh(root: Node3D, glb: String, items: Array) -> void:
        if not ResourceLoader.exists(glb) or items.size() == 0:
                return
        var packed: PackedScene = load(glb)
        var inst: Node3D = packed.instantiate()
        var mesh_inst: MeshInstance3D = _find_type(inst, "MeshInstance3D") as MeshInstance3D
        if mesh_inst == null or mesh_inst.mesh == null:
                inst.queue_free()
                return
        var mesh: Mesh = mesh_inst.mesh
        var mat: Material = mesh_inst.get_active_material(0)
        var mm := MultiMeshInstance3D.new()
        var multimesh := MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.mesh = mesh
        multimesh.instance_count = items.size()
        var aabb: AABB = mesh.get_aabb()
        for i in items.size():
                var it: Dictionary = items[i]
                var s: float = float(it["scale"])
                var xf := Transform3D(Basis(Vector3.UP, float(it["rot"])).scaled(Vector3(s, s, s)),
                                Vector3((it["pos"] as Vector2).x, 0, (it["pos"] as Vector2).y))
                multimesh.set_instance_transform(i, xf)
        mm.multimesh = multimesh
        if mat:
                mm.set_material_override(mat)
        root.add_child(mm)
        inst.queue_free()


func _add_building_collisions(root: Node3D) -> void:
        var sb := StaticBody3D.new()
        sb.name = "BuildingCollision"
        for b in _buildings:
                var type_idx: int = b["type"]
                var glb: String = BUILDING_TYPES[type_idx]
                var size: Vector2 = _building_footprint(type_idx)
                var cs := CollisionShape3D.new()
                var box := BoxShape3D.new()
                var s := 16.0
                box.size = Vector3(size.x * 1.05, 30.0, size.y * 1.05)
                cs.shape = box
                var p: Vector2 = b["pos"]
                cs.position = Vector3(p.x, 15.0, p.y)
                sb.add_child(cs)
        root.add_child(sb)


const BUILDING_FOOTPRINTS := [
        Vector2(12, 12), Vector2(12, 12), Vector2(12, 10), Vector2(12, 10),
        Vector2(16, 12), Vector2(10, 15), Vector2(9, 15), Vector2(14, 14),
        Vector2(10, 10), Vector2(18, 18), Vector2(10, 10), Vector2(10, 10),
        Vector2(12, 12), Vector2(12, 12),
]


func _building_footprint(type_idx: int) -> Vector2:
        return BUILDING_FOOTPRINTS[clamp(type_idx, 0, BUILDING_FOOTPRINTS.size() - 1)]


func _build_street_props(root: Node3D) -> void:
        # streetlights every ~30 m along roads + traffic lights at intersections
        var light_glb := "res://assets/props/streetlight.glb"
        var tl_glb := "res://assets/props/trafficlight.glb"
        var lamp_positions: Array = []
        for road in ROADS:
                var a: Vector2 = road["a"]
                var b: Vector2 = road["b"]
                var dir := (b - a).normalized()
                var perp := Vector2(-dir.y, dir.x) * (ROAD_W / 2.0 + 2.0)
                var length := (b - a).length()
                var t := 20.0
                while t < length - 20.0:
                        lamp_positions.append(a + dir * t + perp)
                        t += 34.0
        _spawn_multimesh(root, light_glb, lamp_positions, 1.0)
        # traffic lights at intersections of Civic/MainCross + Civic/Bridge
        var tl_positions: Array = [Vector2(4, -24), Vector2(24, -200), Vector2(-80, -26)]
        _spawn_multimesh(root, tl_glb, tl_positions, 1.0)


func _spawn_multimesh(root: Node3D, glb: String, positions: Array, scale_f: float) -> void:
        if not ResourceLoader.exists(glb) or positions.size() == 0:
                return
        var packed: PackedScene = load(glb)
        var inst: Node3D = packed.instantiate()
        var mi: MeshInstance3D = _find_type(inst, "MeshInstance3D") as MeshInstance3D
        if mi == null or mi.mesh == null:
                inst.queue_free()
                return
        var mat: Material = mi.get_active_material(0)
        var mm := MultiMeshInstance3D.new()
        var multimesh := MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.mesh = mi.mesh
        multimesh.instance_count = positions.size()
        for i in positions.size():
                var p: Vector2 = positions[i]
                multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(scale_f, scale_f, scale_f)),
                                Vector3(p.x, 0, p.y)))
        mm.multimesh = multimesh
        if mat:
                mm.set_material_override(mat)
        root.add_child(mm)
        inst.queue_free()


func _place_collectibles(root: Node3D) -> void:
        ## 20 Cinder Tokens distributed across the 6 areas (quota per area).
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
        # Register shop/interior anchor positions (used by world.gd)
        shop_positions = {
                "pawn": Vector3(-260, 0, -80),
                "threads": Vector3(320, 0, 200),
                "quickmart": Vector3(-120, 0, -60),
        }
        interior_positions = {
                "dez_apartment": Vector3(-280, 0, -160),
                "marisol_bar": Vector3(-240, 0, -180),
                "iron_gym": Vector3(-200, 0, 560),
                "lennox_clinic": Vector3(-120, 0, 20),
                "kestrel_lobby": Vector3(240, 0, -200),
        }


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
        var light := OmniLight3D.new()
        light.omni_range = 4.0
        light.light_color = Color("f0a33c")
        light.light_energy = 0.7
        holder.add_child(light)
        return holder


func _find_type(node: Node, type: String) -> Node:
        if node.get_class() == type:
                return node
        for c in node.get_children():
                var r := _find_type(c, type)
                if r:
                        return r
        return null


## Interiors are placed on a shelf zone (x +2000) and moved in when entered.
func build_interiors(root: Node3D) -> Dictionary:
        var zones := {}
        var z := interior_positions
        # Dez's apartment
        zones["dez_apartment"] = _make_room(root, "dez_apartment", Vector3(2000, 0, 0), 8.0,
                {"bed": "res://assets/interiors/bed.glb", "lamp": "res://assets/interiors/lamp.glb",
                        "shelf": "res://assets/interiors/shelf.glb", "tv": "res://assets/interiors/tv.glb"})
        # Marisol's bar
        zones["marisol_bar"] = _make_room(root, "marisol_bar", Vector3(2100, 0, 0), 14.0,
                {"table": "res://assets/interiors/table.glb", "stool": "res://assets/interiors/stool.glb",
                        "shelf": "res://assets/interiors/bookcase.glb", "sofa": "res://assets/interiors/sofa.glb"})
        # Iron gym
        zones["iron_gym"] = _make_room(root, "iron_gym", Vector3(2200, 0, 0), 16.0,
                {"bag": "res://assets/interiors/lamp.glb", "shelf": "res://assets/interiors/shelf.glb"})
        # Lennox clinic
        zones["lennox_clinic"] = _make_room(root, "lennox_clinic", Vector3(2300, 0, 0), 12.0,
                {"bed": "res://assets/interiors/bed.glb", "plant": "res://assets/interiors/plant.glb"})
        # Kestrel lobby
        zones["kestrel_lobby"] = _make_room(root, "kestrel_lobby", Vector3(2400, 0, 0), 20.0,
                {"sofa": "res://assets/interiors/sofa.glb", "plant": "res://assets/interiors/plant.glb",
                        "lamp": "res://assets/interiors/lamp.glb"})
        return zones


func _make_room(root: Node3D, room_id: String, origin: Vector3, size: float, props: Dictionary) -> Node3D:
        var room := Node3D.new()
        room.name = "Interior_" + room_id
        room.position = origin
        root.add_child(room)
        # floor + walls via boxes
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
        # four walls
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
        # props laid around
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
        # door trigger back to street
        var door := Node3D.new()
        door.position = Vector3(0, 0, size / 2.0)
        door.add_to_group("interactable")
        door.set_meta("interact_text", "Leave")
        door.set_meta("interior_exit", true)
        room.add_child(door)
        return room
