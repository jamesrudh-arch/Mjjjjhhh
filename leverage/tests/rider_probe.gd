extends Node
## RiderProbe - visual evidence for the seated-rider feature (D5): renders a
## Motorcycle and a sedan with their REAL _spawn_rider() code path (seated
## player body, Sitting_Idle) under software GL, 3/4 + side views, saved to
## tests/render_out/ for VLM seat-fit verification.

const CASES := [
        {"kind": "motorcycle", "label": "bike"},
        {"kind": "sedan", "label": "car"},
]

var _cam: Camera3D
var _i := 0
var _phase := 0
var _t := 0.0
var _cur: Node3D = null


func _ready() -> void:
        var env := Environment.new()
        var sky := Sky.new()
        sky.sky_material = ProceduralSkyMaterial.new()
        env.sky = sky
        env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
        env.ambient_light_energy = 0.7
        env.tonemap_mode = Environment.TONE_MAPPER_ACES
        var we := WorldEnvironment.new()
        we.environment = env
        add_child(we)
        var sun := DirectionalLight3D.new()
        sun.rotation_degrees = Vector3(-42, 25, 0)
        sun.light_energy = 1.4
        add_child(sun)
        # ground: visual + collision so frozen bodies sit right
        var g := MeshInstance3D.new()
        var pm := PlaneMesh.new()
        pm.size = Vector2(60, 60)
        g.mesh = pm
        var gm := StandardMaterial3D.new()
        gm.albedo_color = Color(0.33, 0.34, 0.33)
        g.set_material_override(gm)
        add_child(g)
        var sb := StaticBody3D.new()
        var cs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = Vector3(60, 0.4, 60)
        cs.shape = bs
        cs.position = Vector3(0, -0.2, 0)
        sb.add_child(cs)
        add_child(sb)
        _cam = Camera3D.new()
        _cam.fov = 45
        add_child(_cam)
        _spawn_case()


func _spawn_case() -> void:
        if _i >= CASES.size():
                print("RIDER PROBE COMPLETE")
                get_tree().quit(0)
                return
        var case_d: Dictionary = CASES[_i]
        if String(case_d["kind"]) == "motorcycle":
                _cur = Motorcycle.create_at(Vector3.ZERO)
        else:
                _cur = VehiclePlayer.create("sedan", "res://assets/vehicles/sedan.glb", Vector3.ZERO)
        add_child(_cur)
        _cur.freeze = true        # probe: no driving sim, just visuals
        _cur._spawn_rider()
        _phase = 0
        _t = 0.0


func _process(delta: float) -> void:
        _t += delta
        if _cur == null:
                return
        var label: String = String(CASES[_i]["label"])
        match _phase:
                0:
                        _cam.global_position = Vector3(-4.2, 1.9, -4.6)
                        _cam.look_at(Vector3(0, 0.85, 0), Vector3.UP)
                        if _t > 0.45:
                                _shot("rider_%s_q34" % label)
                                _phase = 1
                                _t = 0.0
                1:
                        _cam.global_position = Vector3(0, 1.2, -6.2)
                        _cam.look_at(Vector3(0, 0.9, 0), Vector3.UP)
                        if _t > 0.3:
                                _shot("rider_%s_side" % label)
                                _cur.queue_free()
                                _i += 1
                                _t = 0.0
                                _spawn_case()


func _shot(nm: String) -> void:
        var img: Image = get_viewport().get_texture().get_image()
        img.save_png("res://tests/render_out/%s.png" % nm)
        print("SHOT %s" % nm)
