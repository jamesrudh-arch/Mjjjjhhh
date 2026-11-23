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
        # Release any existing world
        if world and is_instance_valid(world):
                world.queue_free()
        var packed: PackedScene = load(WORLD_SCENE)
        if packed == null:
                push_error("World scene missing: " + WORLD_SCENE)
                return
        world = packed.instantiate()
        world.name = "World"
        get_tree().root.add_child(world)
        go_to_state(State.PLAYING)
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
