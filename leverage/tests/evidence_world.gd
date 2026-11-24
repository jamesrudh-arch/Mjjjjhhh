extends Node
## Lean world evidence probe: skips the intro immediately, teleports to each
## v2.5 landmark, captures one frame per spot. Tuned for llvmpipe (frames can
## take seconds): minimal waits, 800x450 target.

func _ready() -> void:
        await get_tree().process_frame
        await get_tree().process_frame
        var out_dir := OS.get_environment("LEVERAGE_PROBE_OUT")
        if out_dir == "":
                out_dir = "res://tests/render_out"
        DirAccess.make_dir_recursive_absolute(out_dir)
        print("[EV] starting new game")
        GameManager.start_new_game()
        var world: Node = null
        for i in 220:
                await get_tree().create_timer(0.5).timeout
                world = GameManager.world
                if world != null and is_instance_valid(world) and world.get("player") != null:
                        break
        if world == null or not is_instance_valid(world):
                push_error("[EV] world never mounted")
                get_tree().quit(1)
                return
        print("[EV] world mounted")
        # hold X to skip the whole intro (v2.5 hold-to-skip)
        Input.action_press("action_x")
        await get_tree().create_timer(1.4).timeout
        Input.action_release("action_x")
        await get_tree().create_timer(1.5).timeout
        var player: Node3D = world.get("player")
        var rig: Node = world.get("camera_rig")

        TimeWeather.force_hour(18.6)
        _place(world, player, rig, Vector3(-72, 1.6, 60), -1.2, -0.06)
        await get_tree().create_timer(6.0).timeout
        _shot(out_dir, "05_river_bridge_dusk")

        _place(world, player, rig, Vector3(-260, 1.6, -118), 0.0, -0.06)
        # stage street life: peds on the sidewalk + traffic on the road
        var ped_script: Variant = load("res://scripts/npc/pedestrian.gd")
        for ppos in [Vector3(-254, 0, -132), Vector3(-266, 0, -128), Vector3(-255, 0, -104), Vector3(-266, 0, -142)]:
                var ped: Node3D = (ped_script as GDScript).new()
                ped.position = ppos
                world.add_child(ped)
        var traffic_mgr: Node = world.get("traffic")
        if traffic_mgr and traffic_mgr.has_method("_spawn_near"):
                traffic_mgr.call("_spawn_near", player)
                traffic_mgr.call("_spawn_near", player)
        await get_tree().create_timer(6.0).timeout
        _shot(out_dir, "06_old_quarter_dusk")

        var train: Node = world.get("_train")
        if train:
                train.force_depart()
        _place(world, player, rig, Vector3(-290, 1.6, -312), 0.0, -0.35)
        await get_tree().create_timer(2.5).timeout
        _shot(out_dir, "07_train_station")

        _place(world, player, rig, Vector3(-150, 1.6, 138), 1.8, -0.12)
        await get_tree().create_timer(2.0).timeout
        _shot(out_dir, "08_gas_station")

        TimeWeather.force_hour(21.8)
        # make sure no city event is dimming the neon for the beauty pass
        WorldEvents._active.clear()
        # staged in front of a neon-signed storefront (shop at 100,140, sign faces +z)
        _place(world, player, rig, Vector3(100, 1.6, 157), 0.0, -0.08)
        var cam2 := Camera3D.new()
        cam2.fov = 60.0
        cam2.current = true
        world.add_child(cam2)
        cam2.global_position = Vector3(100, 2.4, 153)
        await get_tree().process_frame
        cam2.look_at(Vector3(100, 3.4, 146), Vector3.UP)
        await get_tree().create_timer(2.0).timeout
        _shot(out_dir, "09_neon_strip_night")
        cam2.queue_free()
        await get_tree().process_frame

        _place(world, player, rig, Vector3(-180, 1.6, -160), 0.0, -0.10)
        await get_tree().create_timer(2.0).timeout
        _shot(out_dir, "10_old_quarter_night")

        print("[EV] done")
        get_tree().quit(0)


func _place(world: Node, player: Node3D, rig: Node, pos: Vector3, yaw: float, pitch: float) -> void:
        player.global_position = pos
        rig.set("yaw", yaw)
        rig.set("pitch", pitch)


func _shot(out_dir: String, name: String) -> void:
        var img := get_viewport().get_texture().get_image()
        img.save_png(out_dir + "/" + name + ".png")
        print("[EV] shot ", name)
