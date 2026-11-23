extends Node
## GameManager - top-level game flow: boot -> splash -> menu -> intro -> playing.
## Owns the pause system, game-over and ending flow, autosave cadence, playtime.

enum State { BOOT, SPLASH, TITLE, MENU, INTRO, PLAYING, PAUSED, GAMEOVER, ENDING }

const WORLD_SCENE := "res://scenes/world/world.tscn"
const AUTOSAVE_INTERVAL := 120.0

var state: int = State.BOOT
var current_scene_id := "boot"
var _autosave_timer := 0.0
var _player_journey_log: Array = []   # recorded beats for test reports
var _fade_layer: CanvasLayer = null  # persistent state-transition fade (D15)
var _fade_rect: ColorRect = null
var _fade_tween: Tween = null

var world: Node = null


func _ready() -> void:
        process_mode = Node.PROCESS_MODE_ALWAYS
        EventBus.game_over.connect(_on_game_over)
        EventBus.save_completed.connect(func(_s): pass)
        EventBus.player_died.connect(func(): _on_game_over("death"))


func _process(delta: float) -> void:
        if state == State.PLAYING:
                GameState.playtime_seconds += delta
                GameState.track_stat("playtime", delta)
                _autosave_timer += delta
                if _autosave_ready():
                        _autosave_timer = 0.0
                        SaveSystem.autosave()


func _autosave_ready() -> bool:
        return _autosave_timer >= AUTOSAVE_INTERVAL


func go_to_state(new_state: int) -> void:
        state = new_state
        match new_state:
                State.PLAYING:
                        get_tree().paused = false
                        InputRouter.ui_blocking = false
                State.PAUSED:
                        get_tree().paused = true
                _:
                        pass


func is_playing() -> bool:
        return state == State.PLAYING


func toggle_pause() -> void:
        if state == State.PLAYING:
                go_to_state(State.PAUSED)
                EventBus.game_paused.emit(true)
        elif state == State.PAUSED:
                go_to_state(State.PLAYING)
                EventBus.game_paused.emit(false)


func start_new_game() -> void:
        GameState.reset_for_new_game()
        _record_journey("new_game", {})
        _load_world(true)


func continue_game(slot: int) -> bool:
        if not SaveSystem.load_game(slot):
                return false
        _record_journey("continue_game", {"slot": slot})
        _load_world(false)
        return true


func _load_world(fresh: bool) -> void:
        current_scene_id = "world"
        # Free the menu scene we are leaving (latent flow bug: the menu stayed in
        # the tree covering the world; the menu->game transition is now explicit).
        var cur := get_tree().current_scene
        if cur != null and cur != world and cur is MainMenu:
                cur.queue_free()
                get_tree().current_scene = null
        # Release any existing world
        if world and is_instance_valid(world):
                world.queue_free()
        var packed: PackedScene = load(WORLD_SCENE)
        if packed == null:
                push_error("World scene missing: " + WORLD_SCENE)
                return
        # cinematic entry: world arrives through a fade-in from black (D15)
        _ensure_fade_layer()
        _fade_rect.color.a = 1.0
        world = packed.instantiate()
        world.name = "World"
        get_tree().root.add_child(world)
        go_to_state(State.PLAYING)
        _fade_from_black(0.55)
        EventBus.game_started.emit(fresh)
        if fresh:
                _start_intro_sequence()
        else:
                var pos: Vector3 = SaveSystem.player_resume_position()
                if world.has_method("place_player"):
                        world.place_player(pos)
                if world.has_method("on_loaded_from_save"):
                        world.on_loaded_from_save(SaveSystem.world_data())


func _start_intro_sequence() -> void:
        # Opening cinematic overlays the world; world.gd waits for it to finish.
        if world and world.has_method("play_opening_cinematic"):
                world.play_opening_cinematic()
        _record_journey("intro_started", {})


## ---------------- State-transition fade (D15) ----------------
## GameManager owns a persistent overlay (autoload child, survives scene swaps)
## so menu->world and world->menu transitions can fade through black.
func _ensure_fade_layer() -> void:
        if _fade_layer != null and is_instance_valid(_fade_layer):
                return
        _fade_layer = CanvasLayer.new()
        _fade_layer.name = "StateFade"
        _fade_layer.layer = 60
        _fade_rect = ColorRect.new()
        _fade_rect.color = Color(0, 0, 0, 0)
        _fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
        _fade_layer.add_child(_fade_rect)
        add_child(_fade_layer)


func _fade_from_black(time := 0.55) -> void:
        _ensure_fade_layer()
        if _fade_tween != null and _fade_tween.is_valid():
                _fade_tween.kill()
        _fade_tween = _fade_layer.create_tween()
        _fade_tween.tween_property(_fade_rect, "color:a", 0.0, time).set_ease(Tween.EASE_OUT)


func fade_layer_alpha() -> float:
        if _fade_rect == null:
                return 0.0
        return _fade_rect.color.a


func return_to_menu() -> void:
        if world and is_instance_valid(world):
                world.queue_free()
        world = null
        current_scene_id = "main_menu"
        go_to_state(State.MENU)
        get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")


func reload_world_from_save() -> void:
        # Called after loading a slot from the pause menu.
        if world and is_instance_valid(world):
                var had_intro := false
                world.queue_free()
                world = null
        _load_world(false)


func _on_game_over(reason: String) -> void:
        if state != State.PLAYING:
                return
        go_to_state(State.GAMEOVER)
        EventBus.game_over.emit(reason)
        _record_journey("game_over", {"reason": reason})


func end_game(ending_id: String) -> void:
        go_to_state(State.ENDING)
        EventBus.game_ended.emit(ending_id)
        _record_journey("ending", {"ending": ending_id})


func respawn_player() -> void:
        # Arrested/died -> wake up at Lennox Clinic, lose some money ("hospital fees").
        var fee: int = int(min(300.0, float(GameState.money) * 0.15))
        GameState.add_money(-fee)
        GameState.wanted_level = 0
        GameState.heat = 0.0
        GameState.health = GameState.max_health * 0.6
        GameState.armor = 0.0
        if world and world.has_method("respawn_player_at_clinic"):
                world.respawn_player_at_clinic()
        go_to_state(State.PLAYING)


# --- journey logging (also used by headless integration tests) ---
func _record_journey(event_name: String, data: Dictionary) -> void:
        _player_journey_log.append({"event": event_name, "data": data,
                "time": GameState.playtime_seconds})
        EventBus.test_event.emit("journey." + event_name, data)


func journey_log() -> Array:
        return _player_journey_log
