extends Node
## ClayProbe - pure-geometry evidence: renders the sedan with a flat unlit
## white material (no textures, no lighting response) so the SILHOUETTE can
## be measured objectively (mask solidity + hole count) without VLM subjectivity.

func _ready() -> void:
        var env := Environment.new()
        env.background_mode = Environment.BG_COLOR
        env.background_color = Color(0.55, 0.55, 0.55)
        env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        env.ambient_light_color = Color(1, 1, 1)
        env.ambient_light_energy = 1.0
        var we := WorldEnvironment.new()
        we.environment = env
        add_child(we)
        var root: Node3D = (load("res://assets/vehicles/sedan.glb") as PackedScene).instantiate()
        add_child(root)
        var clay := StandardMaterial3D.new()
        clay.albedo_color = Color(0.1, 0.1, 0.1)
        clay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        _override(root, clay)
        var cam := Camera3D.new()
        cam.fov = 35
        cam.global_position = Vector3(-4.6, 2.1, -5.2)
        add_child(cam)
        cam.look_at(Vector3(0, 0.6, 0), Vector3.UP)
        var cam2 := Camera3D.new()
        cam2.fov = 35
        cam2.global_position = Vector3(0, 1.3, -7.5)
        add_child(cam2)
        cam2.look_at(Vector3(0, 0.7, 0), Vector3.UP)
        await get_tree().create_timer(0.6).timeout
        cam2.current = true
        await get_tree().create_timer(0.2).timeout
        var img: Image = get_viewport().get_texture().get_image()
        img.save_png("res://tests/render_out/clay_sedan_side.png")
        print("SHOT clay_sedan_side")
        await get_tree().create_timer(0.2).timeout
        get_tree().quit(0)


func _override(n: Node, mat: Material) -> void:
        if n is MeshInstance3D:
                n.set_material_override(mat)
        for c in n.get_children():
                _override(c, mat)
