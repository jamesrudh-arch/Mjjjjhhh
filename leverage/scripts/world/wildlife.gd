class_name Wildlife
extends Node3D
## Wildlife - the living layer of Cinder City: pigeon flocks that peck and
## scatter, gulls circling the Cinder River (with dives), rats scurrying the
## alleys at night, fireflies over the green patches after dusk and moths
## orbiting streetlights. All cheap code-built creatures with distance culling
## and a shared reaction to violence (gunfire/combat scatters everything).

const PIGEON_FLOCKS := [
        Vector2(-240, -120),        # Old Quarter market plaza
        Vector2(240, -200),         # Kestrel plaza
        Vector2(-46, 60),           # riverside promenade
        Vector2(120, -540),         # Heights park edge
]
const RAT_SPOTS := [
        Vector2(-180, -140),        # Old Quarter alleys
        Vector2(-300, 520),         # Ironworks
        Vector2(-260, 300),         # Docklands backs
]
const FIREFLY_SPOTS := [
        Vector2(120, -540),         # Heights green
        Vector2(-46, 120),          # river bank south
        Vector2(-240, -100),        # market trees
        Vector2(300, 300),          # neon strip backlot
]
const GULL_CENTERS := [
        Vector3(CinderRiver.CENTER_X, 0, -220.0),
        Vector3(CinderRiver.CENTER_X, 0, 80.0),
        Vector3(CinderRiver.CENTER_X, 0, 380.0),
]

var _pigeons: Array = []
var _gulls: Array = []
var _rats: Array = []
var _fireflies: Array = []
var _moths: Array = []
var _lamp_points: Array = []
var _rng := RandomNumberGenerator.new()
var _player: Node3D = null
var _next_gull_cry := 8.0


func _ready() -> void:
        _rng.seed = 90210
        set_process(false)


func setup(player: Node3D, lamp_positions: Array) -> void:
        _player = player
        _spawn_pigeons()
        _spawn_gulls()
        _spawn_rats()
        _spawn_fireflies()
        _pick_lamp_moths(lamp_positions)
        EventBus.combat_started.connect(_on_violence)
        EventBus.crime_committed.connect(func(_t, pos, _s, _w): _scatter_from(pos, 60.0))
        set_process(true)


# ---------------------------------------------------------------- birds
func _make_bird_body(body_col: Color, wing_col: Color, scale := 1.0) -> Dictionary:
        var bird := Node3D.new()
        var body := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(0.22, 0.12, 0.34) * scale
        body.mesh = bm
        var mat := StandardMaterial3D.new()
        mat.albedo_color = body_col
        mat.roughness = 0.9
        body.set_surface_override_material(0, mat)
        bird.add_child(body)
        var head := MeshInstance3D.new()
        var hm := BoxMesh.new()
        hm.size = Vector3(0.1, 0.09, 0.1) * scale
        head.mesh = hm
        head.set_surface_override_material(0, mat)
        head.position = Vector3(0, 0.05, 0.2) * scale
        bird.add_child(head)
        var wings: Array = []
        var wmat := StandardMaterial3D.new()
        wmat.albedo_color = wing_col
        wmat.roughness = 0.9
        for side in [-1.0, 1.0]:
                var w := MeshInstance3D.new()
                var wm := BoxMesh.new()
                wm.size = Vector3(0.34, 0.02, 0.2) * scale
                w.mesh = wm
                w.set_surface_override_material(0, wmat)
                w.position = Vector3(side * 0.2 * scale, 0.04, 0)
                bird.add_child(w)
                wings.append(w)
        return {"node": bird, "wings": wings}


func _spawn_pigeons() -> void:
        var g := Node3D.new()
        g.name = "Pigeons"
        for flock_c in PIGEON_FLOCKS:
                for i in 6:
                        var b := _make_bird_body(Color(0.42, 0.45, 0.52), Color(0.55, 0.58, 0.66), 0.9)
                        var n: Node3D = b["node"]
                        n.position = Vector3(flock_c.x + _rng.randf_range(-7, 7), 0.12,
                                flock_c.y + _rng.randf_range(-7, 7))
                        g.add_child(n)
                        _pigeons.append({"node": n, "wings": b["wings"], "home": flock_c,
                                "state": "peck", "t": _rng.randf_range(0, 3.0),
                                "dir": _rng.randf_range(0, TAU), "flap": 0.0,
                                "fly_to": Vector2.ZERO, "speed": 0.0})
        add_child(g)


func _spawn_gulls() -> void:
        var g := Node3D.new()
        g.name = "Gulls"
        for i in 8:
                var b := _make_bird_body(Color(0.92, 0.92, 0.9), Color(0.85, 0.85, 0.82), 1.35)
                var n: Node3D = b["node"]
                var c: Vector3 = GULL_CENTERS[i % GULL_CENTERS.size()]
                n.position = Vector3(c.x + _rng.randf_range(-14, 14), c.y + _rng.randf_range(9, 15),
                        c.z + _rng.randf_range(-14, 14))
                g.add_child(n)
                _gulls.append({"node": n, "wings": b["wings"], "center": c,
                        "radius": _rng.randf_range(10.0, 20.0), "height": _rng.randf_range(9.0, 15.0),
                        "phase": _rng.randf_range(0, TAU), "speed": _rng.randf_range(0.25, 0.45),
                        "dive": 0.0, "dive_dir": 1.0})
        add_child(g)


# ---------------------------------------------------------------- rats
func _spawn_rats() -> void:
        var g := Node3D.new()
        g.name = "Rats"
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.16, 0.13, 0.11)
        mat.roughness = 1.0
        for spot in RAT_SPOTS:
                for i in 4:
                        var rat := Node3D.new()
                        var body := MeshInstance3D.new()
                        var bm := BoxMesh.new()
                        bm.size = Vector3(0.10, 0.09, 0.26)
                        body.mesh = bm
                        body.set_surface_override_material(0, mat)
                        body.position.y = 0.06
                        rat.add_child(body)
                        var tail := MeshInstance3D.new()
                        var tm := BoxMesh.new()
                        tm.size = Vector3(0.02, 0.02, 0.22)
                        tail.mesh = tm
                        tail.set_surface_override_material(0, mat)
                        tail.position = Vector3(0, 0.05, -0.22)
                        rat.add_child(tail)
                        rat.position = Vector3(spot.x + _rng.randf_range(-16, 16), 0,
                                spot.y + _rng.randf_range(-16, 16))
                        g.add_child(rat)
                        _rats.append({"node": rat, "home": spot, "dir": _rng.randf_range(0, TAU),
                                "state": "scurry", "t": _rng.randf_range(0, 4.0)})
        add_child(g)


# ---------------------------------------------------------------- fireflies
func _spawn_fireflies() -> void:
        var g := Node3D.new()
        g.name = "Fireflies"
        for spot in FIREFLY_SPOTS:
                var p := GPUParticles3D.new()
                var mat := ParticleProcessMaterial.new()
                mat.direction = Vector3(0, 1, 0)
                mat.spread = 180.0
                mat.initial_velocity_min = 0.15
                mat.initial_velocity_max = 0.55
                mat.gravity = Vector3(0, 0.15, 0)
                mat.scale_min = 0.4
                mat.scale_max = 1.0
                mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
                mat.emission_box_extents = Vector3(9, 1.6, 9)
                p.process_material = mat
                var quad := QuadMesh.new()
                quad.size = Vector2(0.09, 0.09)
                var fm := StandardMaterial3D.new()
                fm.albedo_color = Color(1.0, 0.85, 0.35)
                fm.emission_enabled = true
                fm.emission = Color(1.0, 0.78, 0.3)
                fm.emission_energy_multiplier = 2.4
                fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
                quad.material = fm
                p.draw_pass_1 = quad
                p.amount = 26
                p.lifetime = 5.0
                p.position = Vector3(spot.x, 1.0, spot.y)
                p.visible = false
                g.add_child(p)
                _fireflies.append(p)
        add_child(g)


func _pick_lamp_moths(lamp_positions: Array) -> void:
        # a few moths orbiting the lamps closest to the player spawn areas
        if lamp_positions.is_empty():
                return
        var g := Node3D.new()
        g.name = "Moths"
        var chosen: Array = []
        for i in range(0, lamp_positions.size(), 17):
                chosen.append(lamp_positions[i])
                if chosen.size() >= 8:
                        break
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.75, 0.72, 0.62)
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        for lp in chosen:
                var l: Vector2 = lp
                for m in 3:
                        var moth := MeshInstance3D.new()
                        var qm := QuadMesh.new()
                        qm.size = Vector2(0.05, 0.05)
                        moth.mesh = qm
                        moth.set_surface_override_material(0, mat)
                        moth.position = Vector3(l.x + _rng.randf_range(-0.4, 0.4), 3.1 + _rng.randf_range(-0.2, 0.2),
                                l.y + _rng.randf_range(-0.4, 0.4))
                        g.add_child(moth)
                        _moths.append({"node": moth, "center": Vector3(l.x, 3.1, l.y),
                                "r": _rng.randf_range(0.25, 0.6), "phase": _rng.randf_range(0, TAU),
                                "speed": _rng.randf_range(3.0, 5.0)})
        add_child(g)


# ---------------------------------------------------------------- reactions
func _on_violence() -> void:
        if _player != null:
                _scatter_from(_player.global_position, 80.0)


func _scatter_from(pos: Vector3, radius: float) -> void:
        for p in _pigeons:
                if p["state"] == "peck" and is_instance_valid(p["node"]):
                        var n: Node3D = p["node"]
                        if n.global_position.distance_to(pos) < radius:
                                _pigeon_take_flight(p)
        for r in _rats:
                if is_instance_valid(r["node"]):
                        var n: Node3D = r["node"]
                        if n.global_position.distance_to(pos) < radius * 0.6:
                                r["state"] = "flee"
                                r["t"] = 2.5


func _pigeon_take_flight(p: Dictionary) -> void:
        p["state"] = "fly"
        p["flap"] = 0.0
        var n: Node3D = p["node"]
        var away := Vector2(n.position.x, n.position.z) - (Vector2(_player.global_position.x, _player.global_position.z) if _player else Vector2(0, 0))
        if away.length() < 0.5:
                away = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
        var target := (Vector2(n.position.x, n.position.z) + away.normalized() * _rng.randf_range(18, 30))
        target.x = clampf(target.x, -430, 430)
        target.y = clampf(target.y, -700, 450)
        p["fly_to"] = target
        p["speed"] = _rng.randf_range(5.5, 8.0)
        EventBus.sfx_requested.emit("sfx_pigeon_flutter", n.global_position)


# ---------------------------------------------------------------- process
func _process(delta: float) -> void:
        if _player == null:
                return
        var night: bool = TimeWeather.is_night()
        var pp := _player.global_position
        _update_pigeons(delta, pp)
        _update_gulls(delta)
        _update_rats(delta, pp, night)
        _update_fireflies(night, pp)
        _update_moths(delta, night, pp)
        _next_gull_cry -= delta
        if _next_gull_cry <= 0.0:
                _next_gull_cry = _rng.randf_range(9.0, 20.0)
                if _gulls.size() > 0 and not night:
                        var g0: Dictionary = _gulls[_rng.randi_range(0, _gulls.size() - 1)]
                        if is_instance_valid(g0["node"]):
                                EventBus.sfx_requested.emit("sfx_gull", (g0["node"] as Node3D).global_position)


func _update_pigeons(delta: float, pp: Vector3) -> void:
        for p in _pigeons:
                var n: Node3D = p["node"]
                if not is_instance_valid(n):
                        continue
                if n.global_position.distance_to(pp) > 130.0:
                        n.visible = false
                        continue
                n.visible = true
                match String(p["state"]):
                        "peck":
                                p["t"] -= delta
                                var bob := sin(Time.get_ticks_msec() * 0.012 + float(p["t"])) * 0.03
                                n.position.y = 0.12 + maxf(0.0, bob)
                                if _rng.randf() < 0.4 * delta:
                                        p["dir"] += _rng.randf_range(-1.5, 1.5)
                                n.position.x += cos(float(p["dir"])) * 0.4 * delta
                                n.position.z += sin(float(p["dir"])) * 0.4 * delta
                                var home: Vector2 = p["home"]
                                if Vector2(n.position.x, n.position.z).distance_to(home) > 10.0:
                                        p["dir"] = atan2(home.y - n.position.z, home.x - n.position.x)
                                n.rotation.y = -float(p["dir"]) + PI / 2.0
                                if Vector3(n.position.x, 0, n.position.z).distance_to(pp) < 3.5:
                                        _pigeon_take_flight(p)
                        "fly":
                                p["flap"] += delta * 14.0
                                var target: Vector2 = p["fly_to"]
                                var to := target - Vector2(n.position.x, n.position.z)
                                if to.length() < 1.2:
                                        p["state"] = "peck"
                                        p["home"] = target
                                        n.position.y = 0.12
                                        continue
                                var dir := atan2(to.y, to.x)
                                p["dir"] = dir
                                var sp: float = p["speed"]
                                n.position.x += cos(dir) * sp * delta
                                n.position.z += sin(dir) * sp * delta
                                var climb := clampf((30.0 - to.length()) * 0.25, 0.0, 1.0)
                                n.position.y = 0.12 + sin(PI * clampf(climb, 0, 1)) * 5.0
                                n.rotation.y = -dir + PI / 2.0
                                var wings: Array = p["wings"]
                                for wi in wings.size():
                                        var w: MeshInstance3D = wings[wi]
                                        var side := -1.0 if wi == 0 else 1.0
                                        w.rotation.z = side * sin(float(p["flap"])) * 0.9


func _update_gulls(delta: float) -> void:
        for g in _gulls:
                var n: Node3D = g["node"]
                if not is_instance_valid(n):
                        continue
                var c: Vector3 = g["center"]
                if n.global_position.distance_to(_player.global_position) > 200.0:
                        n.visible = false
                        continue
                n.visible = true
                g["phase"] = float(g["phase"]) + float(g["speed"]) * delta
                var ph: float = g["phase"]
                var r: float = g["radius"]
                var dive: float = g["dive"]
                if dive > 0.0:
                        dive -= delta * 0.55
                        if dive < 0.0:
                                dive = 0.0
                        g["dive"] = dive
                elif _rng.randf() < 0.02 * delta:
                        g["dive"] = 1.0
                var h: float = g["height"]
                var dive_k := pow(dive, 2.0) if dive > 0.0 else 0.0
                var y: float = c.y + lerp(h, 0.4, dive_k)
                var ang := ph
                var rr := r * (1.0 - 0.55 * dive)
                var px := c.x + cos(ang) * rr
                var pz := c.z + sin(ang) * rr
                n.position = Vector3(px, y, pz)
                var tangent := Vector3(-sin(ang), 0, cos(ang))
                n.rotation.y = atan2(tangent.x, tangent.z)
                var wings: Array = g["wings"]
                var flap := sin(Time.get_ticks_msec() * 0.006 + ph) * 0.55
                for wi in wings.size():
                        var w: MeshInstance3D = wings[wi]
                        var side := -1.0 if wi == 0 else 1.0
                        w.rotation.z = side * flap


func _update_rats(delta: float, pp: Vector3, night: bool) -> void:
        for r in _rats:
                var n: Node3D = r["node"]
                if not is_instance_valid(n):
                        continue
                n.visible = night and n.global_position.distance_to(pp) < 70.0
                if not n.visible:
                        continue
                var state := String(r["state"])
                if state == "flee":
                        r["t"] -= delta
                        if float(r["t"]) <= 0.0:
                                r["state"] = "scurry"
                        var away := Vector2(n.position.x, n.position.z) - Vector2(pp.x, pp.z)
                        if away.length() < 0.3:
                                away = Vector2(1, 0)
                        r["dir"] = atan2(away.y, away.x)
                else:
                        if _rng.randf() < 0.9 * delta:
                                r["dir"] += _rng.randf_range(-1.4, 1.4)
                        var home: Vector2 = r["home"]
                        if Vector2(n.position.x, n.position.z).distance_to(home) > 18.0:
                                r["dir"] = atan2(home.y - n.position.z, home.x - n.position.x)
                        if Vector3(n.position.x, 0, n.position.z).distance_to(pp) < 6.0:
                                r["state"] = "flee"
                                r["t"] = 2.0
                var sp := 4.5 if state == "flee" else 1.3
                var d: float = r["dir"]
                n.position.x += cos(d) * sp * delta
                n.position.z += sin(d) * sp * delta
                n.rotation.y = -d + PI / 2.0


func _update_fireflies(night: bool, pp: Vector3) -> void:
        for f in _fireflies:
                if not is_instance_valid(f):
                        continue
                var p := f as GPUParticles3D
                p.visible = night and p.global_position.distance_to(pp) < 90.0
                if p.visible and not p.emitting:
                        p.emitting = true
                elif not p.visible and p.emitting:
                        p.emitting = false


func _update_moths(delta: float, night: bool, pp: Vector3) -> void:
        for m in _moths:
                var n: MeshInstance3D = m["node"]
                if not is_instance_valid(n):
                        continue
                n.visible = night and n.global_position.distance_to(pp) < 60.0
                if not n.visible:
                        continue
                m["phase"] = float(m["phase"]) + float(m["speed"]) * delta
                var ph: float = m["phase"]
                var c: Vector3 = m["center"]
                var r: float = m["r"]
                n.position = Vector3(c.x + cos(ph) * r, c.y + sin(ph * 2.3) * 0.14, c.z + sin(ph) * r)


# ---------------------------------------------------------------- test API
func pigeon_count() -> int:
        return _pigeons.size()


func gull_count() -> int:
        return _gulls.size()


func rat_count() -> int:
        return _rats.size()


func firefly_count() -> int:
        return _fireflies.size()


func moth_count() -> int:
        return _moths.size()


func pigeons_scatter_from(pos: Vector3, radius: float) -> int:
        var before := 0
        for p in _pigeons:
                if p["state"] == "fly":
                        before += 1
        _scatter_from(pos, radius)
        var after := 0
        for p in _pigeons:
                if p["state"] == "fly":
                        after += 1
        return after - before
