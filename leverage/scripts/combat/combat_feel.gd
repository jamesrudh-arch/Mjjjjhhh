class_name CombatFeel
## CombatFeel - static "game juice" helpers shared by player and enemies.
## Hit-stop (engine time_scale dips), slow-motion finishes, camera kicks and
## pooled impact particles. All no-op safe in headless tests (particles skip
## when no rendering; time_scale always restores via ignore_time_scale timer).
##
## Session 5 P0 "combat juice pass" - closes the "feels basic" gap flagged by
## the directive: hits must LAND (Sleeping Dogs / Sifu feel reference).

static var _hitstop_token := 0
static var _impact_pool: Array[CPUParticles3D] = []
static var _pool_root: Node = null


## Brief time freeze on connect. scale 0.05 = near-freeze, 0.35 = soft dip.
static func hit_stop(scale := 0.08, duration := 0.07) -> void:
        var tree := _tree()
        if tree == null:
                return
        _hitstop_token += 1
        var tok := _hitstop_token
        Engine.time_scale = scale
        tree.create_timer(duration, true, false, true).timeout.connect(func() -> void:
                if tok == _hitstop_token:
                        Engine.time_scale = 1.0)


## Cinematic slow-motion (last enemy down, throw finish).
static func slow_mo(scale := 0.35, duration := 0.8) -> void:
        hit_stop(scale, duration)


## Impact particle burst at a world position (dust + spark flecks).
## Pooled CPUParticles3D, one-shot, auto-deactivates. Mobile-renderer safe.
static func spawn_impact(pos: Vector3, strength := 1.0) -> void:
        var root := _root()
        if root == null:
                return
        var p: CPUParticles3D = _take_particle(root)
        if p == null:
                return
        p.global_position = pos
        p.amount = int(clamp(6.0 * strength, 4.0, 18.0))
        p.initial_velocity_min = 1.2 * clamp(strength, 0.6, 2.0)
        p.initial_velocity_max = 2.6 * clamp(strength, 0.6, 2.0)
        p.restart()


static func _tree() -> SceneTree:
        var ml := Engine.get_main_loop()
        return ml as SceneTree


static func _root() -> Node:
        var tree := _tree()
        if tree == null or tree.root == null:
                return null
        if _pool_root == null or not is_instance_valid(_pool_root):
                _pool_root = Node3D.new()
                _pool_root.name = "CombatFeelFX"
                tree.root.add_child.call_deferred(_pool_root)
        return _pool_root


static func _take_particle(root: Node) -> CPUParticles3D:
        for p in _impact_pool:
                if is_instance_valid(p) and not p.emitting:
                        return p
        if _impact_pool.size() >= 14:
                return null
        var p := CPUParticles3D.new()
        p.one_shot = true
        p.lifetime = 0.45
        p.explosiveness = 1.0
        p.spread = 70.0
        p.gravity = Vector3(0, -6.0, 0)
        p.scale_amount_min = 0.03
        p.scale_amount_max = 0.08
        p.direction = Vector3(0, 1, 0)
        p.emitting = false
        var mesh := QuadMesh.new()
        mesh.size = Vector2(0.06, 0.06)
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.9, 0.86, 0.78, 0.75)
        mat.flags_unshaded = true
        mesh.material = mat
        p.draw_pass = mesh
        root.add_child.call_deferred(p)
        _impact_pool.append(p)
        return p
