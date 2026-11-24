extends Node
func _ready() -> void:
        await get_tree().process_frame
        await get_tree().process_frame
        var world: Variant = (load("res://scenes/world/world.tscn") as PackedScene).instantiate()
        get_tree().root.add_child(world)
        await get_tree().create_timer(4.0).timeout
        TimeWeather.force_hour(21.8)
        await get_tree().create_timer(2.0).timeout
        var cam := Camera3D.new()
        cam.fov = 55.0
        cam.current = true
        world.add_child(cam)
        cam.global_position = Vector3(100, 2.2, 152)
        await get_tree().process_frame
        cam.look_at(Vector3(100, 3.4, 146), Vector3.UP)
        await get_tree().create_timer(2.0).timeout
        var img := get_viewport().get_texture().get_image()
        img.save_png("/home/z/my-project/leverage/docs/evidence/session13/14_neon_closeup.png")
        print("[NEON] saved")
        get_tree().quit()
