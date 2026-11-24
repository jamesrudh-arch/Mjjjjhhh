extends Node
## Evidence probe for v2.5 "The Living City": boots the real game flow under
## the software-GL render environment and captures PNG evidence of every new
## system: DE YOUNG ident, LEVERAGE title, menu, intro conversation (portrait),
## river + bridge + marina, train viaduct, filling station, rebuilt city at
## day/dusk/night.

const OUT_ENV := "LEVERAGE_PROBE_OUT"


func _ready() -> void:
        await get_tree().process_frame
        await get_tree().process_frame
        var out_dir := OS.get_environment(OUT_ENV)
        if out_dir == "":
                out_dir = "res://tests/render_out"
        DirAccess.make_dir_recursive_absolute(out_dir)
        print("[EV] out=", out_dir)
        # --- boot cards (real timeline) ---
        var boot: Variant = (load("res://scenes/boot/boot.tscn") as PackedScene).instantiate()
        boot._test_mode = false
        get_tree().root.add_child(boot)
        await get_tree().create_timer(2.2).timeout
        _shot(out_dir, "01_deyoung_ident")
        await get_tree().create_timer(2.4).timeout
        _shot(out_dir, "02_leverage_title")
        await get_tree().create_timer(3.4).timeout
        _shot(out_dir, "03_notice")
        boot.queue_free()
        await get_tree().process_frame

        # --- menu ---
        var menu: Variant = (load("res://scenes/menus/main_menu.tscn") as PackedScene).instantiate()
        get_tree().root.add_child(menu)
        await get_tree().create_timer(2.0).timeout
        _shot(out_dir, "04_main_menu")
        menu.queue_free()
        await get_tree().process_frame

        # --- real game: intro conversation stays unskipped ---
        print("[EV] starting new game")
        GameManager.start_new_game()
        var world: Node = null
        # time-based wait: llvmpipe frames can take hundreds of ms each
        for i in 160:
                await get_tree().create_timer(0.5).timeout
                world = GameManager.world
                if world != null and is_instance_valid(world) and world.get("player") != null:
                        break
        if world == null or not is_instance_valid(world):
                push_error("[EV] world never mounted")
                get_tree().quit(1)
                return
        print("[EV] world mounted")
        # conversation: Rizzo's first lines land ~19-23 s after the intro starts
        for i in 21:
                await get_tree().create_timer(1.0).timeout
        _shot(out_dir, "05_intro_conversation")
        # skip the rest of the intro
        Input.action_press("action_x")
        await get_tree().process_frame
        Input.action_release("action_x")
        await get_tree().create_timer(1.0).timeout
        Input.action_press("action_x")
        await get_tree().process_frame
        Input.action_release("action_x")
        await get_tree().create_timer(2.0).timeout

        var player: Node3D = world.get("player")
        var rig: Node = world.get("camera_rig")

        # --- shot set: dusk city from a rooftop-ish vantage ---
        TimeWeather.force_hour(18.6)
        _place(world, player, rig, Vector3(-64, 1.6, -60), -2.35, -0.08)
        await get_tree().create_timer(5.0).timeout
        _shot(out_dir, "06_river_bridge_dusk")

        _place(world, player, rig, Vector3(-120, 1.6, -240), -0.6, -0.22)
        await get_tree().create_timer(4.0).timeout
        _shot(out_dir, "07_old_quarter_dusk")

        # train viaduct + station with a departing train
        var train: Node = world.get("_train")
        if train:
                train.force_depart()
        _place(world, player, rig, Vector3(-300, 1.6, -318), 0.35, -0.28)
        await get_tree().create_timer(6.0).timeout
        _shot(out_dir, "08_train_station")

        # filling station
        _place(world, player, rig, Vector3(-150, 1.6, 138), 2.4, -0.1)
        await get_tree().create_timer(4.0).timeout
        _shot(out_dir, "09_gas_station")

        # neon strip at night
        TimeWeather.force_hour(21.8)
        _place(world, player, rig, Vector3(250, 1.6, 238), -1.5708, -0.1)
        await get_tree().create_timer(5.0).timeout
        _shot(out_dir, "10_neon_strip_night")

        # old quarter at night - lit windows ramp
        _place(world, player, rig, Vector3(-180, 1.6, -160), -0.9, -0.12)
        await get_tree().create_timer(4.0).timeout
        _shot(out_dir, "11_old_quarter_night")

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
