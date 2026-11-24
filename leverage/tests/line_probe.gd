extends Node
func _ready() -> void:
        await get_tree().process_frame
        await get_tree().process_frame
        var root := Node3D.new()
        add_child(root)
        var cb: CityBuilder = CityBuilder.new()
        root.add_child(cb)
        # build just a road + line manually
        var road: MeshInstance3D = cb.call("_road_segment", 60.0, 12.0)
        road.position = Vector3(0, 0.02, 0)
        root.add_child(road)
        var line: MeshInstance3D = cb.call("_center_line", 60.0)
        line.position = Vector3(0, 0.045, 0)
        root.add_child(line)
        var lm: StandardMaterial3D = line.get_material_override() as StandardMaterial3D
        print("[LINE] line mesh=%s mat=%s tex=%s" % [line.mesh.get_class(), lm.get_class(), lm.albedo_texture])
        var cam := Camera3D.new()
        cam.fov = 55.0
        cam.current = true
        cam.position = Vector3(18, 6.0, 18)
        root.add_child(cam)
        await get_tree().process_frame
        cam.look_at(Vector3(-10, 0, -6), Vector3.UP)
        var sun := DirectionalLight3D.new()
        sun.rotation_degrees = Vector3(-50, 30, 0)
        sun.light_energy = 1.1
        root.add_child(sun)
        var env := WorldEnvironment.new()
        var e := Environment.new()
        e.background_mode = Environment.BG_COLOR
        e.background_color = Color(0.4, 0.5, 0.6)
        env.environment = e
        root.add_child(env)
        await get_tree().create_timer(1.0).timeout
        var img := get_viewport().get_texture().get_image()
        img.save_png("/home/z/my-project/leverage/docs/evidence/session13/12_line_test.png")
        print("[LINE] saved")
        get_tree().quit()
