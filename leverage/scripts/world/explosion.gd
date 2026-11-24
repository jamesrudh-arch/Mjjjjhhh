class_name Explosions
extends Node
## Explosions - pooled cinematic explosions shared by gas pumps, mission
## set-pieces and vehicle wrecks: flash light, fire burst, smoke column,
## shockwave ring, hit-stop, camera shake and radius damage.

static var _instance: Explosions = null
var _pool: Array = []
const POOL_MAX := 6


static func boom(pos: Vector3, radius := 7.0, damage := 65.0, source: Node3D = null) -> void:
        if _instance == null:
                var n := Explosions.new()
                n.name = "Explosions"
                (Engine.get_main_loop() as SceneTree).root.add_child(n)
        _instance._spawn(pos, radius, damage, source)


func _ready() -> void:
        _instance = self


func _spawn(pos: Vector3, radius: float, damage: float, source: Node3D) -> void:
        # --- fire burst (one-shot CPUParticles3D) ---
        var fire := _take()
        if fire != null:
                fire.global_position = pos
                fire.amount = 42
                fire.one_shot = true
                fire.lifetime = 0.9
                fire.explosiveness = 0.95
                fire.direction = Vector3.UP
                fire.spread = 40.0
                fire.initial_velocity_min = 6.0
                fire.initial_velocity_max = 13.0
                fire.gravity = Vector3(0, -7, 0)
                fire.scale_amount_min = 0.7
                fire.scale_amount_max = 1.9
                fire.set_color_ramp(_make_ramp(Color(1.0, 0.85, 0.35), Color(0.85, 0.22, 0.05)))
                fire.restart()
        # --- flash light ---
        var light := OmniLight3D.new()
        light.light_color = Color(1.0, 0.72, 0.35)
        light.light_energy = 6.0
        light.omni_range = radius * 3.2
        light.position = pos + Vector3(0, 1.5, 0)
        add_child(light)
        var tw := create_tween()
        tw.tween_property(light, "light_energy", 0.0, 0.45).set_ease(Tween.EASE_OUT)
        tw.tween_callback(light.queue_free)
        # --- shockwave ring ---
        var ring := MeshInstance3D.new()
        var tm := TorusMesh.new()
        tm.inner_radius = 0.35
        tm.outer_radius = 0.55
        ring.mesh = tm
        ring.position = pos + Vector3(0, 0.3, 0)
        var rm := StandardMaterial3D.new()
        rm.albedo_color = Color(1.0, 0.9, 0.7, 0.6)
        rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        rm.emission_enabled = true
        rm.emission = Color(1.0, 0.8, 0.45)
        ring.set_surface_override_material(0, rm)
        add_child(ring)
        var rt := create_tween()
        rt.set_parallel(true)
        rt.tween_property(ring, "scale", Vector3(radius * 0.55, radius * 0.55, radius * 0.55), 0.5).set_ease(Tween.EASE_OUT)
        rt.tween_property(ring, "rotation:x", PI / 2.0, 0.1)
        rt.chain().tween_property(rm, "albedo_color:a", 0.0, 0.25)
        rt.chain().tween_callback(ring.queue_free)
        # --- feel: hit-stop + shake + sfx ---
        CombatFeel.hit_stop(0.08, 0.12)
        EventBus.sfx_requested.emit("sfx_explosion", pos)
        EventBus.camera_shake_requested.emit(0.35, 0.5)
        EventBus.crime_committed.emit("explosion", pos, 30.0, [])
        # --- radius damage ---
        for c in (Engine.get_main_loop() as SceneTree).get_nodes_in_group("combatant"):
                if c is Node3D and c != source and is_instance_valid(c):
                        var d: float = (c as Node3D).global_position.distance_to(pos)
                        if d < radius and c.has_method("take_hit"):
                                (c as Node3D).take_hit(damage * (1.0 - d / radius), source, 2.6, 0.5, "explosion")
        for v in (Engine.get_main_loop() as SceneTree).get_nodes_in_group("explosive"):
                if v is Node3D and v != source and is_instance_valid(v):
                        var d: float = (v as Node3D).global_position.distance_to(pos)
                        if d < radius + 2.0 and v.has_meta("explosive_hp"):
                                _ignite(v as Node3D, source)


## Chain reaction starter: drains hp and detonates when it hits zero.
func _ignite(node: Node3D, source: Node3D) -> void:
        var hp := float(node.get_meta("explosive_hp", 30.0)) - 30.0
        if hp <= 0.0 and not node.has_meta("exploded"):
                node.set_meta("exploded", true)
                var pos := node.global_position
                if node.has_method("explode"):
                        node.call("explode", source)
                else:
                        node.queue_free()
                # small delay so chained booms read as a sequence
                (Engine.get_main_loop() as SceneTree).create_timer(randf_range(0.12, 0.35)).timeout.connect(
                        func(): if is_instance_valid(self): boom(pos, 6.0, 45.0, node))
        else:
                node.set_meta("explosive_hp", hp)


func _take() -> CPUParticles3D:
        if _pool.size() < POOL_MAX:
                var p := CPUParticles3D.new()
                var qm := QuadMesh.new()
                qm.size = Vector2(0.8, 0.8)
                var m := StandardMaterial3D.new()
                m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
                qm.material = m
                p.mesh = qm
                add_child(p)
                _pool.append(p)
                return p
        for p in _pool:
                if not p.emitting:
                        return p
        return _pool[0]


func _make_ramp(a: Color, b: Color) -> Gradient:
        var g := Gradient.new()
        g.set_color(0, Color(1, 1, 1, 1))
        g.set_color(1, Color(1, 1, 1, 0))
        g.add_point(0.25, a)
        g.add_point(0.7, b)
        return g
