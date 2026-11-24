extends Node
## Beauty shot: the three new building types alone, noon light, 12m camera.

func _ready() -> void:
        await get_tree().process_frame
        await get_tree().process_frame
        var root := Node3D.new()
        add_child(root)
        var env := WorldEnvironment.new()
        var e := Environment.new()
        var sky := Sky.new()
        var sm := ProceduralSkyMaterial.new()
        sm.sky_top_color = Color("3a5f8f")
        sm.sky_horizon_color = Color("b9cbd8")
        sky.sky_material = sm
        e.sky = sky
        e.background_mode = Environment.BG_SKY
        e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
        e.ambient_light_energy = 1.0
        e.tonemap_mode = Environment.TONE_MAPPER_ACES
        env.environment = e
        root.add_child(env)
        var sun := DirectionalLight3D.new()
        sun.rotation_degrees = Vector3(-50, 30, 0)
        sun.light_energy = 1.2
        sun.shadow_enabled = true
        root.add_child(sun)
        var cam := Camera3D.new()
        cam.fov = 55.0
        cam.current = true
        root.add_child(cam)
        var names := ["b_brick2", "b_tower1", "b_shop1", "b_house2"]
        for i in names.size():
                var b: Variant = load("res://assets/buildings/%s.gltf" % names[i])
                var inst: Node3D = (b as PackedScene).instantiate()
                inst.position = Vector3(i * 26.0 - 39.0, 0, 0)
                root.add_child(inst)
        cam.position = Vector3(0, 9, 46)
        cam.look_at(Vector3(0, 6, 0), Vector3.UP)
        await get_tree().create_timer(1.2).timeout
        var img := get_viewport().get_texture().get_image()
        img.save_png("/home/z/my-project/leverage/docs/evidence/session13/11_building_beauty.png")
        print("[BEAUTY] saved")
        # dump building positions near old quarter street for framing
        var world: Variant = (load("res://scenes/world/world.tscn") as PackedScene).instantiate()
        get_tree().root.add_child(world)
        await get_tree().create_timer(3.0).timeout
        var n := 0
        for bld in world.city._buildings:
                var bp: Vector2 = bld["pos"]
                if bp.distance_to(Vector2(-260, -120)) < 60.0:
                        print("[BLD] %s type=%s pos=%s" % ["", bld["type"], bp])
                        n += 1
                        if n >= 6: break
        get_tree().quit()
