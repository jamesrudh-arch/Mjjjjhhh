class_name AirUnit
extends Node3D
## AirUnit - 5-star police helicopter pursuit (v2.4.0 "Alive City").
## Kinematic orbit above the player with a tracking spotlight and blinking
## nav light; keeps reporting sightings so escaping at 5 stars needs real
## cover (the classic climax fantasy). Body is code-built (boxes/cylinders):
## an airborne silhouette + spotlight cone + rotor spin reads clearly at
## 30 m; no new asset pipeline (TDL #35). Despawns itself below level 5.

const ORBIT_RADIUS := 26.0
const ORBIT_HEIGHT := 30.0
const ORBIT_SPEED := 0.45           # rad/s around the player
const SPOT_RANGE := 90.0
const SIGHT_INTERVAL := 2.5         # seconds between pursuit sightings
const OFF_LEVEL_GRACE := 3.0        # seconds below 5 stars before leaving

var _angle := 0.0
var _rotor: Node3D
var _spot: SpotLight3D
var _nav: OmniLight3D
var _blink_t := 0.0
var _sight_accum := 0.0
var _off_level_t := 0.0


func _ready() -> void:
        _build_body()
        # owned looping rotor thump (spatial, follows the unit)
        _rotor_sfx = AudioSystem.make_looping_spatial("sfx_heli_loop", 140.0)
        if _rotor_sfx:
                add_child(_rotor_sfx)
                _rotor_sfx.play()


var _rotor_sfx: AudioStreamPlayer3D


func _build_body() -> void:
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.10, 0.12, 0.14)
        mat.metallic = 0.4
        mat.roughness = 0.55
        # fuselage
        var body := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(2.6, 1.5, 5.4)
        body.mesh = bm
        body.material_override = mat
        add_child(body)
        # tail boom + fin
        var tail := MeshInstance3D.new()
        var tm := BoxMesh.new()
        tm.size = Vector3(0.5, 0.6, 4.2)
        tail.position = Vector3(0, 0.3, -4.4)
        tail.mesh = tm
        tail.material_override = mat
        add_child(tail)
        var fin := MeshInstance3D.new()
        var fm := BoxMesh.new()
        fm.size = Vector3(0.16, 1.3, 1.1)
        fin.position = Vector3(0, 0.9, -6.2)
        fin.mesh = fm
        fin.material_override = mat
        add_child(fin)
        # main rotor (separate node so it can spin)
        _rotor = Node3D.new()
        _rotor.position = Vector3(0, 1.05, 0)
        add_child(_rotor)
        for i in 2:
                var blade := MeshInstance3D.new()
                var blade_mesh := BoxMesh.new()
                blade_mesh.size = Vector3(0.34, 0.07, 9.0)
                blade.mesh = blade_mesh
                blade.rotation.y = PI * float(i) / 2.0
                _rotor.add_child(blade)
        # tail rotor disc
        var tr := MeshInstance3D.new()
        var trm := CylinderMesh.new()
        trm.top_radius = 0.02
        trm.bottom_radius = 0.02
        trm.height = 1.3
        tr.rotation.z = PI / 2.0
        tr.position = Vector3(0.45, 0.9, -6.1)
        tr.mesh = trm
        tr.material_override = mat
        add_child(tr)
        # skids
        for s in [-1.0, 1.0]:
                var skid := MeshInstance3D.new()
                var sm := BoxMesh.new()
                sm.size = Vector3(0.12, 0.12, 3.4)
                skid.position = Vector3(0.9 * s, -1.1, 0.2)
                skid.mesh = sm
                skid.material_override = mat
                add_child(skid)
        # tracking spotlight (the pursuit fantasy: the cone on the player)
        _spot = SpotLight3D.new()
        _spot.spot_range = SPOT_RANGE
        _spot.spot_angle = 26.0
        _spot.light_energy = 4.0
        _spot.shadow_enabled = false
        _spot.position = Vector3(0, -0.7, 1.6)
        add_child(_spot)
        # blinking red nav light on the tail
        _nav = OmniLight3D.new()
        _nav.omni_range = 6.0
        _nav.light_color = Color(1.0, 0.15, 0.1)
        _nav.position = Vector3(0, 0.6, -6.0)
        add_child(_nav)


func _process(delta: float) -> void:
        # leave a few seconds after the heat drops below 5
        if GameState.wanted_level < 5:
                _off_level_t += delta
                if _off_level_t > OFF_LEVEL_GRACE:
                        queue_free()
                        return
        else:
                _off_level_t = 0.0
        var player := get_tree().get_first_node_in_group("player") as Node3D
        if player == null:
                return
        # orbit above the player
        _angle += ORBIT_SPEED * delta
        var target := player.global_position + Vector3(cos(_angle) * ORBIT_RADIUS, ORBIT_HEIGHT, sin(_angle) * ORBIT_RADIUS)
        global_position = global_position.lerp(target, clamp(delta * 1.5, 0.0, 1.0))
        # face travel direction (nose toward tangent)
        var tangent := Vector3(-sin(_angle), 0.0, cos(_angle))
        rotation.y = atan2(tangent.x, tangent.z)
        # rotor spin + nav blink
        if _rotor:
                _rotor.rotate_y(24.0 * delta)
        _blink_t += delta
        if _nav:
                _nav.visible = fmod(_blink_t, 1.0) < 0.5
        # spotlight tracks the player
        if _spot and is_inside_tree():
                _spot.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)
        # keep the pursuit hot from above
        _sight_accum += delta
        if _sight_accum >= SIGHT_INTERVAL:
                _sight_accum = 0.0
                PoliceSystem.report_sighting()


func has_spotlight() -> bool:
        return _spot != null
