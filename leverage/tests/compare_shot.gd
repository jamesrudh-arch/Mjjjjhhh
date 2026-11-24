extends Node
## CompareShotProbe - deterministic before/after cinematography for the
## cinematic pass: same player spot on the Neon Strip, same rig yaw/pitch,
## three times of day (day / dusk / night). Tag via LEVERAGE_CMP_TAG
## (before|after), output via LEVERAGE_PROBE_OUT.

const SPOT := Vector3(250, 0.8, 238)
const YAW := -1.5708   # face +x (east, down the strip)
const PITCH := -0.14

func _ready() -> void:
        await get_tree().process_frame
        await get_tree().process_frame
        print("[CMP] start_new_game")
        GameManager.start_new_game()
        # skip the intro cinematic (same as the player pressing X)
        await get_tree().create_timer(1.2).timeout
        Input.action_press("action_x")
        await get_tree().process_frame
        Input.action_release("action_x")
        var out_dir := OS.get_environment("LEVERAGE_PROBE_OUT")
        if out_dir == "":
                out_dir = "res://tests/render_out"
        DirAccess.make_dir_recursive_absolute(out_dir)
        var tag: String = OS.get_environment("LEVERAGE_CMP_TAG")
        if tag == "":
                tag = "shot"
        # wait for the world to mount + settle (city build, state fade)
        var world: Node = null
        for i in 1200:
                await get_tree().process_frame
                world = GameManager.world
                if world != null and is_instance_valid(world) and world.get("player") != null:
                        break
        if world == null or not is_instance_valid(world):
                push_error("[CMP] world never mounted")
                get_tree().quit(1)
                return
        print("[CMP] world mounted, settling")
        var player: Node3D = world.get("player")
        player.global_position = SPOT
        var rig: Node = world.get("camera_rig")
        rig.set("yaw", YAW)
        rig.set("pitch", PITCH)
        await get_tree().create_timer(6.0).timeout
        for phase in [["day", 12.0], ["dusk", 18.5], ["night", 21.5]]:
                TimeWeather.force_hour(phase[1])
                await get_tree().create_timer(4.0).timeout
                rig.set("yaw", YAW)
                rig.set("pitch", PITCH)
                await get_tree().process_frame
                await get_tree().process_frame
                var img: Image = get_viewport().get_texture().get_image()
                var fname := "%s_%s.png" % [tag, phase[0]]
                img.save_png(out_dir + "/" + fname)
                print("[CMP] saved ", fname)
        print("[CMP] done")
        get_tree().quit(0)
