extends Node
## RenderProbe - visual verification: drives the REAL game flow (boot cards ->
## main menu -> new game -> world + intro -> gameplay) under Xvfb software GL,
## capturing PNG screenshots of each stage. Sandbox "Verified" level evidence
## (Compatibility/OpenGL3 software renderer approximation of the Mobile target).

const OUT_DIR := "res://tests/render_out"

var _phase := "boot"
var _t := 0.0
var _boot: Node = null
var _menu: Node = null
var _shot_idx := 0


func _ready() -> void:
        print("RENDER PROBE: ", Engine.get_version_info().get("string", "?"))
        DirAccess.make_dir_recursive_absolute(OUT_DIR)
        _boot = (load("res://scenes/boot/boot.tscn") as PackedScene).instantiate()
        _boot._test_mode = false       # full real card timeline
        add_child(_boot)
        GameManager.go_to_state(GameManager.State.SPLASH)


func _process(delta: float) -> void:
        _t += delta
        match _phase:
                "boot":
                        if _t >= 1.4 and _shot_idx == 0:
                                _shot("01_boot_company")
                        elif _t >= 4.2 and _shot_idx == 1:
                                _shot("02_boot_title")
                        elif _t >= 6.6 and _shot_idx == 2:
                                _shot("03_boot_notice")
                        elif _t >= 10.0 and _shot_idx == 3:
                                _boot.queue_free()
                                _menu = (load("res://scenes/menus/main_menu.tscn") as PackedScene).instantiate()
                                add_child(_menu)
                                _phase = "menu"
                                _t = 0.0
                "menu":
                        if _t >= 1.0 and _shot_idx == 3:
                                _shot("04_main_menu")
                                _menu.queue_free()
                                # enter the world exactly like a real player
                                GameManager.start_new_game()
                                _phase = "intro"
                                _t = 0.0
                "intro":
                        if _t >= 3.0 and _shot_idx == 4:
                                _shot("05_intro_cinematic")
                                var w: Node = GameManager.world
                                var intro: Node = w._intro if w != null else null
                                if intro != null and is_instance_valid(intro):
                                        intro._finish()
                                _phase = "gameplay"
                                _t = 0.0
                "gameplay":
                        if _t >= 4.0 and _shot_idx == 5:
                                _shot("06_world_gameplay")
                        elif _t >= 6.5 and _shot_idx == 6:
                                _shot("07_world_gameplay_late")
                                print("RENDER PROBE COMPLETE")
                                get_tree().quit(0)


func _shot(name: String) -> void:
        _shot_idx += 1
        var img: Image = get_viewport().get_texture().get_image()
        img.save_png(OUT_DIR + "/" + name + ".png")
        print("SHOT ", name)
