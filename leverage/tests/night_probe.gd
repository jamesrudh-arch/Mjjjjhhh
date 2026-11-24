extends Node
func _ready() -> void:
        await get_tree().process_frame
        await get_tree().process_frame
        var world: Variant = (load("res://scenes/world/world.tscn") as PackedScene).instantiate()
        get_tree().root.add_child(world)
        await get_tree().create_timer(4.0).timeout
        TimeWeather.force_hour(21.8)
        await get_tree().create_timer(3.0).timeout
        # inspect a night material
        var mats: Array = world._night_materials
        print("[NIGHT] collected mats:", mats.size())
        for e in mats.slice(0, 6):
                var m: StandardMaterial3D = e["mat"]
                print("[NIGHT] %s enabled=%s energy=%.2f emission=%s albedo=%s" % [
                        m.resource_name, m.emission_enabled, m.emission_energy_multiplier,
                        m.emission.to_html(false), m.albedo_color.to_html(false)])
        # find the LG_WindowLit material specifically
        for e in mats:
                var m: StandardMaterial3D = e["mat"]
                if m.resource_name == "LG_WindowLit":
                        print("[NIGHT] LG_WindowLit energy now:", m.emission_energy_multiplier, "emission:", m.emission)
                        break
        # camera right in front of a building with lit windows (old quarter)
        var player: Node3D = world.get("player")
        var rig: Node = world.get("camera_rig")
        player.global_position = Vector3(-240, 1.6, -108)
        rig.set("yaw", 0.8)
        rig.set("pitch", -0.05)
        await get_tree().create_timer(2.5).timeout
        var img := get_viewport().get_texture().get_image()
        img.save_png("/home/z/my-project/leverage/docs/evidence/session13/13_night_facade.png")
        print("[NIGHT] saved")
        get_tree().quit()
