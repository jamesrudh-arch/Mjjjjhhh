extends Node
## Character swap probe - validates realistic bodies vs UAL rig: mesh+skin swap +
## animation advance + screenshots. Sandbox "Verified" evidence.

var _cam: Camera3D
var _actors := {}
var _t := 0.0
var _phase := 0
var _chars := ["dez", "tommy", "marisol", "big_theo", "ava", "lucy_fang", "vito", "ren", "officer_brant", "doc_lennox"]

# [anim to switch to (or "" none), wait seconds before shot, shot name]
const PHASES := [
        ["", 0.4, "01_tpose"],
        ["Walk", 1.1, "02_walk"],
        ["Punch_Cross", 0.45, "03_punch"],
        ["Idle", 1.6, "04_idle"],
        ["Drunken_Sway", 1.2, "05_drunken"],
	["Idle", 0.8, "06_face"],
]

func _ready() -> void:
        _cam = Camera3D.new()
        _cam.fov = 32
        add_child(_cam)
        _cam.global_position = Vector3(2.2, 1.55, 2.9)
        _cam.look_at(Vector3(0, 1.0, -1.2), Vector3.UP)
        var sun := DirectionalLight3D.new()
        sun.rotation_degrees = Vector3(-48, 32, 0)
        sun.light_energy = 1.3
        sun.shadow_enabled = true
        add_child(sun)
        var env := Environment.new()
        var sky := Sky.new()
        sky.sky_material = ProceduralSkyMaterial.new()
        env.sky = sky
        env.background_mode = Environment.BG_SKY
        env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
        env.ambient_light_energy = 0.55
        env.tonemap_mode = Environment.TONE_MAPPER_ACES
        var we := WorldEnvironment.new()
        we.environment = env
        add_child(we)
        var g := MeshInstance3D.new()
        var pm := PlaneMesh.new()
        pm.size = Vector2(30, 30)
        g.mesh = pm
        var gm := StandardMaterial3D.new()
        gm.albedo_color = Color(0.34, 0.35, 0.33)
        g.set_material_override(gm)
        g.position = Vector3(0, -0.02, 0)
        add_child(g)
        var i := 0
        for cid in _chars:
                var a := _make_character(cid)
                a.position = Vector3(0, 0, -i * 0.95)
                add_child(a)
                _actors[cid] = a
                i += 1
        _apply_phase()

func _apply_phase() -> void:
        var ph: Array = PHASES[_phase]
        var anim_name := String(ph[0])
        if anim_name != "":
                for cid in _chars:
                        var ap := _find_anim(_actors[cid])
                        if ap and ap.has_animation(anim_name):
                                ap.play(anim_name)
                                ap.advance(float(PHASES[_phase][1]) * 0.5)

func _process(delta: float) -> void:
        _t += delta
        if _t >= float(PHASES[_phase][1]):
                _shot(String(PHASES[_phase][2]))
                _phase += 1
                _t = 0.0
                if _phase >= PHASES.size():
                        print("CHAR PROBE COMPLETE")
                        get_tree().quit(0)
                else:
                        _apply_phase()

func _make_character(cid: String) -> Node3D:
        var man := (load("res://assets/characters/ual_mannequin.glb") as PackedScene).instantiate()
        var body_path := "res://assets/characters/char_%s.glb" % cid
        if ResourceLoader.exists(body_path):
                var body := (load(body_path) as PackedScene).instantiate()
                var body_mi := _find_mesh(body, "Body") as MeshInstance3D
                var man_mi := _find_mesh(man, "Mannequin") as MeshInstance3D
                if body_mi and man_mi and body_mi.mesh:
                        man_mi.mesh = body_mi.mesh
                        if body_mi.skin:
                                man_mi.skin = body_mi.skin
                        man_mi.name = "Body"
        return man

func _find_mesh(node: Node, n: String) -> Node:
        if node is MeshInstance3D and node.name == n:
                return node
        for c in node.get_children():
                var r := _find_mesh(c, n)
                if r:
                        return r
        return null

func _find_anim(node: Node) -> AnimationPlayer:
        if node is AnimationPlayer:
                return node
        for c in node.get_children():
                var r := _find_anim(c)
                if r:
                        return r
        return null

func _shot(nm: String) -> void:
        var img: Image = get_viewport().get_texture().get_image()
        img.save_png("res://tests/render_out/char_%s.png" % nm)
        print("SHOT char_%s" % nm)
