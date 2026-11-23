extends Node
## MotionProbe - authoritative in-motion visual evidence under the REAL
## target renderer (Forward Mobile / lavapipe): drives the full real flow
## (boot -> menu -> NEW GAME via the real menu path -> intro -> gameplay),
## then captures:
##   - fade-in alpha telemetry for the menu->game transition (D15)
##   - the menu actually freed (latent flow bug fix)
##   - 4 gameplay frames over ~11 s (pedestrians in MOTION - D13)
##   - rider seated on a parked motorcycle in-world (D5)
##   - one HUD-hidden wide frame as the new menu key art source (D9)

const OUT := "res://tests/render_out"

var _phase := "boot"
var _t := 0.0
var _boot: Node = null
var _menu: Node = null
var _shots := 0
var _bike: Node = null
var _ui_hidden := false
var _keyart_prep := false


func _ready() -> void:
        print("MOTION PROBE START")
        DirAccess.make_dir_recursive_absolute(OUT)
        _boot = (load("res://scenes/boot/boot.tscn") as PackedScene).instantiate()
        _boot._test_mode = true        # fast cards; gameplay is what matters here
        add_child(_boot)
        GameManager.go_to_state(GameManager.State.SPLASH)


func _process(delta: float) -> void:
        _t += delta
        match _phase:
                "boot":
                        if _t >= 2.0 and _shots == 0:
                                _shot("m_00_boot")
                        elif _t >= 3.5:
                                _boot.queue_free()
                                _menu = (load("res://scenes/menus/main_menu.tscn") as PackedScene).instantiate()
                                # direct root child: current_scene assignment only
                                # sticks for root children (probe-fidelity fix)
                                get_tree().root.add_child(_menu)
                                get_tree().current_scene = _menu
                                _phase = "menu"
                                _t = 0.0
                "menu":
                        if _t >= 1.2 and _shots == 1:
                                _shot("m_01_menu")
                        elif _t >= 2.0:
                                # the REAL button path: menu fade + GameManager._load_world
                                print("MENU: pressing NEW GAME via real path")
                                _menu._start(true)
                                print("MENU FREED OK=", not is_instance_valid(_menu) or _menu.is_queued_for_deletion())
                                print("FADE alpha right after start=", GameManager.fade_layer_alpha())
                                _phase = "intro"
                                _t = 0.0
                "intro":
                        if _t >= 0.3 and _shots == 2:
                                _shot("m_02_world_fadein")
                                print("FADE alpha at 0.3s=", GameManager.fade_layer_alpha())
                        elif _t >= 2.5 and _shots == 3:
                                _shot("m_03_intro")
                        elif _t >= 3.5:
                                var w: Node = GameManager.world
                                var intro: Node = w._intro if w != null else null
                                if intro != null and is_instance_valid(intro):
                                        intro._finish()
                                print("FADE alpha after intro=", GameManager.fade_layer_alpha())
                                _phase = "gameplay"
                                _t = 0.0
                "gameplay":
                        if _t >= 2.0 and _shots == 4:
                                _shot("m_04_motion_a")
                        elif _t >= 5.0 and _shots == 5:
                                _shot("m_05_motion_b")
                        elif _t >= 8.0 and _shots == 6:
                                _shot("m_06_motion_c")
                        elif _t >= 11.0:
                                _phase = "rider"
                                _t = 0.0
                "rider":
                        if _t >= 0.1 and _bike == null:
                                var w: Node = GameManager.world
                                for n in get_tree().get_nodes_in_group("vehicle"):
                                        if n is Motorcycle:
                                                _bike = n
                                                break
                                if _bike != null:
                                        var player: Node = w.player
                                        player.global_position = _bike.global_position + Vector3(1.6, 0.4, 0)
                                        (_bike as Motorcycle).enter(player)
                                        print("RIDER: entered parked bike, rider=", (_bike as Motorcycle).rider != null)
                        if _t >= 2.0 and _shots == 7:
                                _shot("m_07_rider_inworld")
                        elif _t >= 4.0 and _shots == 8:
                                _shot("m_08_rider_side")
                                (_bike as Motorcycle).exit_vehicle()
                                print("RIDER: exited, rider=", (_bike as Motorcycle).rider)
                        elif _t >= 6.0:
                                _phase = "keyart"
                                _t = 0.0
                "keyart":
                        if not _keyart_prep:
                                _keyart_prep = true
                                TimeWeather.force_hour(19.5)      # dusk mood
                                var w: Node = GameManager.world
                                var phone: Node = w.get_phone()
                                if phone != null:
                                        if phone.is_ringing():
                                                phone.decline()
                                        elif phone.state == PhoneSystem.State.ACTIVE:
                                                phone.hang_up()
                                print("KEYART: dusk set, call handled")
                        if _t >= 2.2 and not _ui_hidden:
                                _ui_hidden = true
                                var w: Node = GameManager.world
                                w.hud.visible = false
                                w.touch.visible = false
                                if w._call_banner != null:
                                        w._call_banner.visible = false
                        if _t >= 3.5 and _shots == 9:
                                _shot("m_09_keyart_clean")
                                var w: Node = GameManager.world
                                w.hud.visible = true
                                w.touch.visible = true
                                if w._call_banner != null:
                                        w._call_banner.visible = true
                        if _shots == 10:
                                print("MOTION PROBE COMPLETE")
                                get_tree().quit(0)


func _shot(name: String) -> void:
        _shots += 1
        var img: Image = get_viewport().get_texture().get_image()
        img.save_png(OUT + "/" + name + ".png")
        print("SHOT ", name)
