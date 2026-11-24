class_name CinderRiver
extends Node3D
## CinderRiver - the river that splits Cinder City in two (west: Old Quarter +
## Docklands + Ironworks, east: Kestrel + Neon Strip + Heights east bank).
## Sunken channel in the ground mesh, animated water shader, stone parapets
## with gaps at the crossings, two road bridges, a small marina with bobbing
## boats, and living fish shoals that wander and occasionally jump.
## Geometry constants are static so CityBuilder can carve the channel and
## keep buildings/props out of the water.

const CENTER_X := -46.0
const HALF_W := 18.0            # water width 36m (x -64..-28)
const BANK := 11.0              # sloped bank each side
const DEPTH := -1.6             # channel bottom (local ground space)
const WATER_Y := -0.62          # world-space water surface
const Z_MIN := -780.0
const Z_MAX := 620.0

# Parapet gaps where roads cross: [z0, z1] world-z ranges with no wall.
const PARAPET_GAPS := [
        Vector2(-19.0, 3.0),            # main_cross bridge (z=-10, road+sidewalks)
        Vector2(-566.0, -529.0),        # hill_road diagonal, west parapet
        Vector2(-652.0, -615.0),        # hill_road diagonal, east parapet
]


static func bank_y(x: float) -> float:
        ## Ground displacement profile: flat bottom, cosine banks, 0 outside.
        var d := absf(x - CENTER_X)
        if d <= HALF_W:
                return DEPTH
        if d <= HALF_W + BANK:
                var t := (d - HALF_W) / BANK
                return DEPTH * (0.5 + 0.5 * cos(PI * t))
        return 0.0


static func bank_dydx(x: float) -> float:
        ## Analytic slope of the profile (for terrain normal recompute).
        var d := absf(x - CENTER_X)
        if d <= HALF_W or d >= HALF_W + BANK:
                return 0.0
        var t := (d - HALF_W) / BANK
        var s := 1.0 if x > CENTER_X else -1.0
        return s * (-DEPTH * 0.5 * PI / BANK * sin(PI * t))


static func in_river_band(x: float, margin := 4.0) -> bool:
        return absf(x - CENTER_X) < HALF_W + BANK + margin


# ---------------------------------------------------------------- instance
var _fish: Array = []                    # fish shadow dicts
var _boats: Array = []                   # bobbing boats
var _fish_shoals := {}
var _next_jump_t := 6.0
var _water: MeshInstance3D
var _rng := RandomNumberGenerator.new()

const WATER_SHADER := "
shader_type spatial;
render_mode blend_mix, depth_draw_always, unshaded;
uniform vec3 deep_color : source_color = vec3(0.03, 0.10, 0.11);
uniform vec3 shallow_color : source_color = vec3(0.10, 0.21, 0.19);
uniform vec3 glint_color : source_color = vec3(1.0, 0.80, 0.52);
varying vec3 wpos;
void vertex() {
        wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
        float t = TIME;
        float w1 = sin(wpos.x * 0.55 + t * 0.9) * 0.5 + 0.5;
        float w2 = sin(wpos.z * 0.35 - t * 1.4 + sin(wpos.x * 0.8) * 1.5) * 0.5 + 0.5;
        float ripple = sin((wpos.x + wpos.z) * 1.7 + t * 2.2) * 0.5 + 0.5;
        vec3 col = mix(deep_color, shallow_color, clamp(w1 * 0.6 + w2 * 0.4, 0.0, 1.0) * 0.55 + ripple * 0.15);
        float g1 = pow(clamp(sin(wpos.z * 2.1 - t * 1.9) * sin(wpos.x * 1.7 + t * 0.7), 0.0, 1.0), 3.0);
        float g2 = pow(clamp(sin(wpos.z * 3.3 - t * 3.1 + 2.0) * sin(wpos.x * 2.6 - t), 0.0, 1.0), 4.0);
        col += glint_color * (g1 * 0.30 + g2 * 0.22);
        EMISSION = glint_color * (g1 * 0.45 + g2 * 0.35);
        float edge = min(UV.x, 1.0 - UV.x);
        float foam = smoothstep(0.06, 0.0, edge) * (0.5 + 0.5 * sin(wpos.z * 0.8 + t * 1.6));
        col += vec3(0.72, 0.78, 0.76) * foam * 0.30;
        ALBEDO = col;
        ALPHA = 0.86;
}
"


func _ready() -> void:
        _rng.seed = 46461
        _build_water()
        _build_riverbed()
        _build_parapets()
        _build_main_bridge()
        _build_hill_bridge()
        _build_marina()
        _build_banks_dressing()
        _spawn_fish()
        _spawn_ambience()


# ---------------------------------------------------------------- water
func _build_water() -> void:
        _water = MeshInstance3D.new()
        _water.name = "WaterSurface"
        var pm := PlaneMesh.new()
        pm.size = Vector2(HALF_W * 2.0, Z_MAX - Z_MIN)
        pm.subdivide_width = 8
        pm.subdivide_depth = 64
        _water.mesh = pm
        var mat := ShaderMaterial.new()
        var sh := Shader.new()
        sh.code = WATER_SHADER
        mat.shader = sh
        _water.set_surface_override_material(0, mat)
        _water.position = Vector3(CENTER_X, WATER_Y, (Z_MIN + Z_MAX) / 2.0)
        add_child(_water)


func _build_riverbed() -> void:
        var mi := MeshInstance3D.new()
        var pm := PlaneMesh.new()
        pm.size = Vector2(HALF_W * 2.0 + 2.0, Z_MAX - Z_MIN)
        mi.mesh = pm
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.16, 0.14, 0.10)
        mat.roughness = 1.0
        mi.set_surface_override_material(0, mat)
        mi.position = Vector3(CENTER_X, DEPTH - 0.06 + 0.03, (Z_MIN + Z_MAX) / 2.0)
        add_child(mi)


# ---------------------------------------------------------------- parapets
func _stone_mat() -> StandardMaterial3D:
        var mat := StandardMaterial3D.new()
        if ResourceLoader.exists("res://assets/textures/concrete_albedo.png"):
                mat.albedo_texture = load("res://assets/textures/concrete_albedo.png")
                mat.texture_repeat = true
        mat.albedo_color = Color(0.78, 0.74, 0.68)
        mat.roughness = 0.92
        return mat


func _build_parapets() -> void:
        var body := StaticBody3D.new()
        body.name = "RiverParapets"
        var stone := _stone_mat()
        for side in [-1.0, 1.0]:
                var px := CENTER_X + float(side) * (HALF_W + 0.55)
                var z := Z_MIN + 10.0
                while z < Z_MAX - 10.0:
                        var seg_len := 20.0
                        var gap := false
                        for g in PARAPET_GAPS:
                                if z + seg_len > g.x and z < g.y:
                                        gap = true
                                        break
                        if not gap:
                                var mi := MeshInstance3D.new()
                                var bm := BoxMesh.new()
                                bm.size = Vector3(0.7, 0.62, seg_len)
                                mi.mesh = bm
                                mi.set_surface_override_material(0, stone)
                                mi.position = Vector3(px, 0.31 - 0.06, z + seg_len / 2.0)
                                add_child(mi)
                                var cs := CollisionShape3D.new()
                                var box := BoxShape3D.new()
                                box.size = Vector3(0.9, 1.4, seg_len)
                                cs.shape = box
                                cs.position = Vector3(px, 0.55, z + seg_len / 2.0)
                                body.add_child(cs)
                        z += seg_len
        add_child(body)


# ---------------------------------------------------------------- bridges
func _bridge_railing(length: float) -> MeshInstance3D:
        var mi := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(length, 0.85, 0.22)
        mi.mesh = bm
        mi.set_surface_override_material(0, _stone_mat())
        return mi


func _bridge_pier(x: float, z: float) -> MeshInstance3D:
        var mi := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(1.5, 1.9, 3.2)
        mi.mesh = bm
        mi.set_surface_override_material(0, _stone_mat())
        mi.position = Vector3(x, -0.75, z)
        return mi


func _build_main_bridge() -> void:
        var g := Node3D.new()
        g.name = "MainBridge"
        # railings along the road edges across the channel
        for side in [-1.0, 1.0]:
                var r := _bridge_railing(48.0)
                r.position = Vector3(CENTER_X, 0.45, -10.0 + side * 8.6)
                g.add_child(r)
                # corner posts
                for cx in [-1.0, 1.0]:
                        var post := MeshInstance3D.new()
                        var bm := BoxMesh.new()
                        bm.size = Vector3(0.34, 1.15, 0.34)
                        post.mesh = bm
                        post.set_surface_override_material(0, _stone_mat())
                        post.position = Vector3(CENTER_X + cx * 23.5, 0.55, -10.0 + side * 8.6)
                        g.add_child(post)
        for px in [-58.0, -46.0, -34.0]:
                g.add_child(_bridge_pier(px, -10.0))
        # lamp posts at the four corners
        _add_lamp(g, Vector3(-66, 0, -18.4))
        _add_lamp(g, Vector3(-26, 0, -18.4))
        _add_lamp(g, Vector3(-66, 0, -1.6))
        _add_lamp(g, Vector3(-26, 0, -1.6))
        add_child(g)


func _build_hill_bridge() -> void:
        var g := Node3D.new()
        g.name = "HillBridge"
        # diagonal road (-120,-420)->(10,-720) crosses the channel around
        # (-71,-562)..(-21,-648). Railings along both road edges.
        var a := Vector2(-75.0, -552.0)
        var b := Vector2(-17.0, -658.0)
        var dir := (b - a).normalized()
        var length := (b - a).length()
        var angle := atan2(dir.y, dir.x)
        var perp := Vector2(-dir.y, dir.x)
        for side in [-1.0, 1.0]:
                var r := _bridge_railing(length)
                var mid: Vector2 = (a + b) / 2.0 + perp * 8.4 * float(side)
                r.position = Vector3(mid.x, 0.45, mid.y)
                r.rotation.y = -angle
                g.add_child(r)
        for t in [0.3, 0.7]:
                var p: Vector2 = a + (b - a) * float(t)
                g.add_child(_bridge_pier(p.x, p.y))
        add_child(g)


func _add_lamp(parent: Node3D, pos: Vector3) -> void:
        var path := "res://assets/props/streetlight_v2.glb"
        if ResourceLoader.exists(path):
                var lamp: Node3D = (load(path) as PackedScene).instantiate()
                lamp.position = pos
                parent.add_child(lamp)


# ---------------------------------------------------------------- marina
func _build_marina() -> void:
        var g := Node3D.new()
        g.name = "Marina"
        var wood := StandardMaterial3D.new()
        wood.albedo_color = Color(0.45, 0.33, 0.20)
        wood.roughness = 0.95
        # two plank docks jutting east from the west bank (Docklands side)
        for dz in [292.0, 306.0]:
                var dock := MeshInstance3D.new()
                var bm := BoxMesh.new()
                bm.size = Vector3(11.0, 0.32, 2.8)
                dock.mesh = bm
                dock.set_surface_override_material(0, wood)
                dock.position = Vector3(CENTER_X - HALF_W + 4.5, -0.30, dz)
                g.add_child(dock)
        # three small boats
        for i in 3:
                var boat := _make_boat(i)
                boat.position = Vector3(CENTER_X - HALF_W + 6.0 + i * 2.4, WATER_Y + 0.02, 288.0 + i * 8.0)
                boat.rotation.y = _rng.randf_range(-0.4, 0.4)
                g.add_child(boat)
                _boats.append({"node": boat, "phase": _rng.randf_range(0, TAU)})
        add_child(g)


func _make_boat(i: int) -> Node3D:
        var boat := Node3D.new()
        var hull_mat := StandardMaterial3D.new()
        hull_mat.albedo_color = [Color(0.75, 0.24, 0.20), Color(0.85, 0.72, 0.30), Color(0.30, 0.42, 0.55)][i % 3]
        hull_mat.roughness = 0.7
        var hull := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(3.4, 0.7, 1.25)
        hull.mesh = bm
        hull.set_surface_override_material(0, hull_mat)
        hull.position.y = 0.25
        boat.add_child(hull)
        var cabin := MeshInstance3D.new()
        var cb := BoxMesh.new()
        cb.size = Vector3(1.1, 0.55, 1.0)
        cabin.mesh = cb
        cabin.set_surface_override_material(0, hull_mat)
        cabin.position = Vector3(-0.4, 0.82, 0)
        boat.add_child(cabin)
        var mast := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = 0.03
        cm.bottom_radius = 0.05
        cm.height = 2.4
        mast.mesh = cm
        mast.position = Vector3(0.9, 1.5, 0)
        boat.add_child(mast)
        return boat


# ---------------------------------------------------------------- banks
func _build_banks_dressing() -> void:
        # riverside trees + benches on both banks (multimeshed, cheap)
        var tree_glbs := ["res://assets/props/tree_a.glb", "res://assets/props/tree_b.glb"]
        var positions: Array = []
        var z := Z_MIN + 30.0
        while z < Z_MAX - 30.0:
                if not _in_parapet_gap(z):
                        for side in [-1.0, 1.0]:
                                if _rng.randf() < 0.62:
                                        positions.append({
                                                "pos": Vector2(CENTER_X + side * (HALF_W + BANK * 0.55), z + _rng.randf_range(-6, 6)),
                                                "rot": _rng.randf_range(0, TAU), "scale": _rng.randf_range(0.8, 1.1)})
                z += 26.0
        for gi in tree_glbs.size():
                var subset: Array = []
                for pi in positions.size():
                        if pi % 2 == gi:
                                subset.append(positions[pi])
                _spawn_multimesh(tree_glbs[gi], subset, 1.0)
        # benches facing the water at a few calm spots
        var bench_path := "res://assets/props/bench.glb"
        if ResourceLoader.exists(bench_path):
                var bpos: Array = []
                for spot_z in [-300.0, -140.0, 60.0, 380.0]:
                        for side in [-1.0, 1.0]:
                                bpos.append({"pos": Vector2(CENTER_X + side * (HALF_W + 2.2), spot_z),
                                        "rot": (PI / 2.0 if side < 0 else -PI / 2.0)})
                _spawn_multimesh(bench_path, bpos, 1.0)


func _in_parapet_gap(z: float) -> bool:
        for g in PARAPET_GAPS:
                if z > g.x - 6.0 and z < g.y + 6.0:
                        return true
        return false


func _spawn_multimesh(glb: String, items: Array, scale_f: float) -> void:
        if not ResourceLoader.exists(glb) or items.is_empty():
                return
        var inst: Node3D = (load(glb) as PackedScene).instantiate()
        var mi := _find_mesh(inst)
        if mi == null or mi.mesh == null:
                inst.queue_free()
                return
        var mm := MultiMeshInstance3D.new()
        var multimesh := MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.mesh = mi.mesh
        multimesh.instance_count = items.size()
        for i in items.size():
                var it: Dictionary = items[i]
                var s: float = float(it.get("scale", 1.0)) * scale_f
                multimesh.set_instance_transform(i, Transform3D(
                        Basis(Vector3.UP, float(it.get("rot", 0.0))).scaled(Vector3(s, s, s)),
                        Vector3((it["pos"] as Vector2).x, 0, (it["pos"] as Vector2).y)))
        mm.multimesh = multimesh
        add_child(mm)
        inst.queue_free()


func _find_mesh(node: Node) -> MeshInstance3D:
        if node is MeshInstance3D:
                return node
        for c in node.get_children():
                var r := _find_mesh(c)
                if r != null:
                        return r
        return null


# ---------------------------------------------------------------- fish
func _spawn_fish() -> void:
        var g := Node3D.new()
        g.name = "FishShoals"
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.05, 0.09, 0.10, 0.62)
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        var shoal_spots := [Vector2(-52.0, -220.0), Vector2(-40.0, 80.0), Vector2(-48.0, 380.0)]
        for si in shoal_spots.size():
                var center: Vector2 = shoal_spots[si]
                _fish_shoals[si] = {"center": center, "radius": _rng.randf_range(7.0, 11.0)}
                for i in 6:
                        var mi := MeshInstance3D.new()
                        var qm := QuadMesh.new()
                        qm.size = Vector2(0.5, 0.2)
                        mi.mesh = qm
                        mi.set_surface_override_material(0, mat)
                        mi.rotation.x = -PI / 2.0
                        var p := Vector3(center.x + _rng.randf_range(-6, 6), WATER_Y - 0.06,
                                center.y + _rng.randf_range(-6, 6))
                        mi.position = p
                        g.add_child(mi)
                        _fish.append({"node": mi, "shoal": si, "dir": _rng.randf_range(0, TAU),
                                "speed": _rng.randf_range(0.35, 0.8), "jumping": false})
        add_child(g)


# ---------------------------------------------------------------- ambience
func _spawn_ambience() -> void:
        # quiet water-lap loops at the marina and the main bridge
        var stream_path := "res://assets/audio/sfx/sfx_water_lap.ogg"
        if not ResourceLoader.exists(stream_path):
                return
        var stream: AudioStream = load(stream_path)
        if stream is AudioStreamOggVorbis:
                (stream as AudioStreamOggVorbis).loop = true
        for pos in [Vector3(CENTER_X, 0, 298.0), Vector3(CENTER_X, 0, -10.0), Vector3(CENTER_X, 0, -600.0)]:
                var p := AudioStreamPlayer3D.new()
                p.stream = stream
                p.bus = "Ambience"
                p.volume_db = -14.0
                p.max_distance = 55.0
                p.unit_size = 6.0
                p.position = pos
                add_child(p)
                p.play()


# ---------------------------------------------------------------- process
func _process(delta: float) -> void:
        var t := Time.get_ticks_msec() / 1000.0
        # boats bob
        for b in _boats:
                var n: Node3D = b["node"]
                if is_instance_valid(n):
                        n.position.y = WATER_Y + 0.02 + sin(t * 1.1 + float(b["phase"])) * 0.05
                        n.rotation.z = sin(t * 0.9 + float(b["phase"])) * 0.03
        # fish wander
        for f in _fish:
                if f["jumping"] or not is_instance_valid(f["node"]):
                        continue
                var shoal: Dictionary = _fish_shoals[f["shoal"]]
                var c: Vector2 = shoal["center"]
                var n: MeshInstance3D = f["node"]
                # steer gently toward the shoal center, wander otherwise
                var to_c := Vector2(c.x - n.position.x, c.y - n.position.z)
                if to_c.length() > float(shoal["radius"]):
                        f["dir"] = lerp_angle(float(f["dir"]), atan2(to_c.y, to_c.x) , clamp(2.5 * delta, 0, 1))
                else:
                        f["dir"] += _rng.randf_range(-1.2, 1.2) * delta
                var sp: float = f["speed"]
                n.position.x += cos(float(f["dir"])) * sp * delta
                n.position.z += sin(float(f["dir"])) * sp * delta
                n.position.x = clampf(n.position.x, CENTER_X - HALF_W + 2.0, CENTER_X + HALF_W - 2.0)
                n.position.z = clampf(n.position.z, Z_MIN + 20.0, Z_MAX - 20.0)
                n.rotation.z = -float(f["dir"])   # quad rotated flat: z-rot steers
        # occasional jump
        _next_jump_t -= delta
        if _next_jump_t <= 0.0:
                _next_jump_t = _rng.randf_range(5.0, 13.0)
                _make_fish_jump()


func _make_fish_jump() -> void:
        var candidates := _fish.filter(func(f): return not f["jumping"] and is_instance_valid(f["node"]))
        if candidates.is_empty():
                return
        var f: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)]
        f["jumping"] = true
        var n: MeshInstance3D = f["node"]
        var start := n.position
        var fwd := Vector3(cos(float(f["dir"])), 0, sin(float(f["dir"]))) * 1.4
        var tw := create_tween()
        var jump_fn := func(k: float):
                if not is_instance_valid(n):
                        return
                n.position = start + fwd * k + Vector3(0, sin(PI * k) * 0.85, 0)
                n.rotation.x = -PI / 2.0 + sin(PI * k) * 1.2
        tw.tween_method(jump_fn, 0.0, 1.0, 0.55)
        tw.tween_callback(func():
                if is_instance_valid(n):
                        n.position = start + fwd
                        n.rotation.x = -PI / 2.0
                f["jumping"] = false)
        EventBus.sfx_requested.emit("sfx_splash", start)
        CombatFeel.spawn_impact(start + Vector3(0, 0.1, 0), 0.8, Vector3.UP)


# ---------------------------------------------------------------- test API
func fish_count() -> int:
        return _fish.size()


func boat_count() -> int:
        return _boats.size()


func water_present() -> bool:
        return _water != null and is_instance_valid(_water)


func bridge_count() -> int:
        var n := 0
        for c in get_children():
                if c.name.begins_with("Bridge") or c.name in ["MainBridge", "HillBridge"]:
                        n += 1
        return n
