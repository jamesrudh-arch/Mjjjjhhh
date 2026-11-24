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
static var _spark_pool: Array[CPUParticles3D] = []
static var _pool_root: Node = null
const POOL_MAX := 20


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


## Impact presentation: directional hit cone (dust kick + additive sparks)
## scaled by strength. dir = the direction the blow travels (hit normal).
## Pooled CPUParticles3D, one-shot, auto-deactivates. Mobile-renderer safe.
static func spawn_impact(pos: Vector3, strength := 1.0, dir := Vector3.UP) -> void:
        var root := _root()
        if root == null:
                return
        var s: float = clampf(strength, 0.6, 2.4)
        # dust: broad, tan, short-lived
        var p: CPUParticles3D = _take_particle(root, _impact_pool, _make_dust)
        if p:
                p.global_position = pos
                p.direction = dir.normalized()
                p.spread = 55.0
                p.amount = int(8.0 * s)
                p.initial_velocity_min = 1.4 * s
                p.initial_velocity_max = 3.2 * s
                p.scale_amount_min = 0.05
                p.scale_amount_max = 0.13 * s
                p.restart()
        # sparks: tight, bright, additive - the "crunch" of the hit
        var sp: CPUParticles3D = _take_particle(root, _spark_pool, _make_spark)
        if sp:
                sp.global_position = pos
                sp.direction = (dir.normalized() + Vector3(0, 0.6, 0)).normalized()
                sp.spread = 38.0
                sp.amount = int(5.0 * s)
                sp.initial_velocity_min = 2.6 * s
                sp.initial_velocity_max = 5.4 * s
                sp.scale_amount_min = 0.03
                sp.scale_amount_max = 0.07 * s
                sp.restart()


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


static func _take_particle(root: Node, pool: Array[CPUParticles3D], factory: Callable) -> CPUParticles3D:
        for p in pool:
                if is_instance_valid(p) and not p.emitting:
                        return p
        if pool.size() >= POOL_MAX:
                return null
        var p: CPUParticles3D = factory.call()
        root.add_child.call_deferred(p)
        pool.append(p)
        return p


static func _make_dust() -> CPUParticles3D:
        var p := CPUParticles3D.new()
        p.one_shot = true
        p.lifetime = 0.5
        p.explosiveness = 1.0
        p.gravity = Vector3(0, -7.0, 0)
        p.direction = Vector3(0, 1, 0)
        p.emitting = false
        var mesh := QuadMesh.new()
        mesh.size = Vector2(0.11, 0.11)
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.88, 0.82, 0.7, 0.8)
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mesh.material = mat
        p.mesh = mesh
        return p


static func _make_spark() -> CPUParticles3D:
        var p := CPUParticles3D.new()
        p.one_shot = true
        p.lifetime = 0.32
        p.explosiveness = 1.0
        p.gravity = Vector3(0, -16.0, 0)
        p.direction = Vector3(0, 1, 0)
        p.emitting = false
        var mesh := QuadMesh.new()
        mesh.size = Vector2(0.05, 0.05)
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(1.0, 0.72, 0.32, 0.95)
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
        mesh.material = mat
        p.mesh = mesh
        return p
