extends Node
## AudioSystem - buses, adaptive music layers, ambience switching, SFX pool,
## spatial one-shots. All audio files are original synthesized assets in
## res://assets/audio (see docs/asset_register.md for provenance).

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"

# In-vehicle radio stations -> original synthesized loops (radio_*.ogg).
const RADIO_TRACKS := {
        "cinder_fm": "radio_cinder_fm",
        "strip_wave": "radio_strip_wave",
        "iron_pulse": "radio_iron_pulse",
}

# moods -> track file basenames (wav). Tracks are layered loops; we crossfade.
const MUSIC_TRACKS := {
        "menu": "mus_menu",
        "explore_day": "mus_explore_day",
        "explore_night": "mus_explore_night",
        "tension": "mus_tension",
        "combat": "mus_combat",
        "story": "mus_story",
        "chase": "mus_chase",
        "sad": "mus_sad",
        "ending": "mus_ending",
}

var _music_players := {}      # mood -> AudioStreamPlayer
var _current_mood := ""
var _ambience_player: AudioStreamPlayer
var _radio_player: AudioStreamPlayer
var _radio_tween: Tween = null
var _radio_station := "off"    # off | cinder_fm | strip_wave | iron_pulse
var _in_vehicle := false
var _sfx_pool_2d: Array = []
var _spatial_pool: Array = []
const POOL_SIZE := 12
const SPATIAL_SIZE := 16
var _sfx_cache := {}
var _current_ambience := ""


func _ready() -> void:
        process_mode = Node.PROCESS_MODE_ALWAYS
        _setup_buses()
        _build_players()
        SaveSystem.apply_audio_settings()
        EventBus.music_layer_requested.connect(set_music_mood)
        EventBus.ambience_area_changed.connect(set_ambience_for_area)
        EventBus.sfx_requested.connect(play_spatial)
        EventBus.settings_changed.connect(func(_s): SaveSystem.apply_audio_settings())
        EventBus.radio_station_changed.connect(_on_radio_station_changed)
        EventBus.player_entered_vehicle.connect(func(_v): _on_vehicle_state(true))
        EventBus.player_exited_vehicle.connect(func(): _on_vehicle_state(false))


func _setup_buses() -> void:
        for bus_name in ["Music", "SFX", "Ambience"]:
                if AudioServer.get_bus_index(bus_name) == -1:
                        AudioServer.add_bus()
                        AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
                        AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


func _build_players() -> void:
        for mood in MUSIC_TRACKS.keys():
                var p := AudioStreamPlayer.new()
                p.name = "Music_" + mood
                p.bus = "Music"
                p.volume_db = -60.0
                add_child(p)
                var path: String = MUSIC_DIR + MUSIC_TRACKS[mood] + ".ogg"
                if ResourceLoader.exists(path):
                        p.stream = load(path)
                _music_players[mood] = p
        _ambience_player = AudioStreamPlayer.new()
        _ambience_player.name = "Ambience"
        _ambience_player.bus = "Ambience"
        add_child(_ambience_player)
        _radio_player = AudioStreamPlayer.new()
        _radio_player.name = "Radio"
        _radio_player.bus = "Music"
        _radio_player.volume_db = -60.0
        add_child(_radio_player)
        for i in POOL_SIZE:
                var p := AudioStreamPlayer.new()
                p.bus = "SFX"
                add_child(p)
                _sfx_pool_2d.append(p)
        for i in SPATIAL_SIZE:
                var p3 := AudioStreamPlayer3D.new()
                p3.bus = "SFX"
                p3.max_distance = 80.0
                p3.unit_size = 8.0
                add_child(p3)
                _spatial_pool.append(p3)


# ---------------- Music ----------------
func set_music_mood(mood: String) -> void:
        if mood == _current_mood:
                return
        var fade_time := 1.2
        var next_player: AudioStreamPlayer = _music_players.get(mood, null)
        var cur_player: AudioStreamPlayer = _music_players.get(_current_mood, null)
        if next_player == null or next_player.stream == null:
                return
        for other in _music_players.values():
                if other != next_player and other != cur_player and other.playing:
                        _tween_volume(other, -60.0, fade_time, true)
        if next_player and not next_player.playing:
                next_player.play()
        _tween_volume(next_player, 0.0, fade_time, false)
        if cur_player and cur_player != next_player:
                _tween_volume(cur_player, -60.0, fade_time, true)
        _current_mood = mood


func _tween_volume(player: AudioStreamPlayer, target_db: float, time_s: float, stop_after: bool) -> void:
        var tw := create_tween()
        tw.tween_property(player, "volume_db", target_db, time_s)
        if stop_after:
                tw.tween_callback(func():
                        if player and is_instance_valid(player):
                                player.stop())
        # NOTE: tweens on ALWAYS-process autoload keep running while paused.


# ---------------- In-vehicle radio (R23) ----------------
func _on_radio_station_changed(station_id: String) -> void:
        _radio_station = station_id
        if RADIO_TRACKS.has(station_id):
                var path: String = MUSIC_DIR + String(RADIO_TRACKS[station_id]) + ".ogg"
                if ResourceLoader.exists(path):
                        _radio_player.stream = load(path)
        _apply_radio()


func _on_vehicle_state(in_vehicle: bool) -> void:
        _in_vehicle = in_vehicle
        _apply_radio()


func _apply_radio() -> void:
        var radio_on: bool = _in_vehicle and _radio_station != "off" and _radio_player.stream != null
        # one live radio tween only - stale fade-outs must not stop a fresh tune
        if _radio_tween != null and _radio_tween.is_valid():
                _radio_tween.kill()
        _radio_tween = create_tween()
        if radio_on:
                _radio_player.play()      # restart on retune / vehicle entry (loops anyway)
                _radio_tween.tween_property(_radio_player, "volume_db", -3.0, 0.6)
                var mood_player: AudioStreamPlayer = _music_players.get(_current_mood, null)
                if mood_player and mood_player.playing:
                        _tween_volume(mood_player, -24.0, 0.6, false)   # duck mood music
        else:
                _radio_tween.tween_property(_radio_player, "volume_db", -60.0, 0.25)
                _radio_tween.tween_callback(func():
                        if not (_in_vehicle and _radio_station != "off"):
                                _radio_player.stop())
                var restore: AudioStreamPlayer = _music_players.get(_current_mood, null)
                if restore and restore.playing:
                        _tween_volume(restore, 0.0, 0.8, false)


func radio_status() -> Dictionary:
        # exposed for the headless audio.radio suite
        return {
                "station": _radio_station,
                "in_vehicle": _in_vehicle,
                "stream_loaded": _radio_player != null and _radio_player.stream != null,
                "playing": _radio_player != null and _radio_player.playing,
                "tracks": RADIO_TRACKS.keys(),
        }


# ---------------- Ambience ----------------
func set_ambience_for_area(area_id: String) -> void:
        var track := "amb_" + area_id
        if track == _current_ambience:
                return
        var path: String = SFX_DIR + track + ".ogg"
        if not ResourceLoader.exists(path):
                return
        _current_ambience = track
        _ambience_player.stream = load(path)
        if not _ambience_player.playing:
                _ambience_player.play()


# ---------------- Ambient one-shots (P1 city-life pass) ----------------
# District + time-of-day weighted street sounds, played quietly on the
# Ambience bus at randomized intervals. Skipped while combat/chase music is
# active so fights stay readable.
const AMBIENT_ONESHOTS := {
        "old_quarter": {"day": {"sfx_birds": 3.0, "sfx_chatter": 3.0, "sfx_car_passby": 2.0, "sfx_wind_gust": 1.0},
                        "night": {"sfx_distant_siren": 2.0, "sfx_wind_gust": 2.0, "sfx_car_passby": 1.0}},
        "docklands": {"day": {"sfx_car_passby": 3.0, "sfx_distant_siren": 1.0, "sfx_chatter": 1.0, "sfx_wind_gust": 2.0},
                      "night": {"sfx_distant_siren": 3.0, "sfx_wind_gust": 2.0, "sfx_car_passby": 1.0}},
        "kestrel_district": {"day": {"sfx_chatter": 3.0, "sfx_car_passby": 3.0, "sfx_city_horn": 1.0},
                             "night": {"sfx_city_horn": 2.0, "sfx_car_passby": 2.0, "sfx_chatter": 1.0}},
        "neon_strip": {"day": {"sfx_chatter": 3.0, "sfx_city_horn": 2.0, "sfx_car_passby": 2.0},
                       "night": {"sfx_chatter": 3.0, "sfx_city_horn": 2.0, "sfx_car_passby": 2.0, "sfx_distant_siren": 1.0}},
        "ironworks": {"day": {"sfx_car_passby": 2.0, "sfx_wind_gust": 2.0, "sfx_city_horn": 1.0},
                      "night": {"sfx_wind_gust": 3.0, "sfx_distant_siren": 1.0}},
        "heights": {"day": {"sfx_birds": 3.0, "sfx_wind_gust": 2.0, "sfx_chatter": 1.0},
                    "night": {"sfx_wind_gust": 3.0, "sfx_distant_siren": 1.0, "sfx_birds": 0.5}},
        "interior": {"day": {"sfx_chatter": 2.0},
                     "night": {"sfx_chatter": 1.0}},
}
const AMBIENT_MIN_GAP := 7.0
const AMBIENT_MAX_GAP := 16.0

var _amb_oneshot_player: AudioStreamPlayer
var _amb_next_t := 8.0


func _process(delta: float) -> void:
        if not GameManager.is_playing():
                return
        if _current_mood == "combat" or _current_mood == "chase":
                _amb_next_t = max(_amb_next_t, 4.0)     # hold off during fights
                return
        _amb_next_t -= delta
        if _amb_next_t <= 0.0:
                _amb_next_t = randf_range(AMBIENT_MIN_GAP, AMBIENT_MAX_GAP)
                _play_ambient_oneshot()


func _play_ambient_oneshot() -> void:
        var area: String = _current_ambience.trim_prefix("amb_")
        if not AMBIENT_ONESHOTS.has(area):
                area = "old_quarter"
        var tod: String = "night" if TimeWeather.is_night() else "day"
        var table: Dictionary = AMBIENT_ONESHOTS[area].get(tod, {})
        if table.is_empty():
                return
        var total := 0.0
        for k in table:
                total += float(table[k])
        var pick: float = randf() * total
        var chosen: String = ""
        for k in table:
                pick -= float(table[k])
                if pick <= 0.0:
                        chosen = String(k)
                        break
        if chosen == "":
                return
        var stream: AudioStream = _get_sfx(chosen)
        if stream == null:
                return
        if _amb_oneshot_player == null:
                _amb_oneshot_player = AudioStreamPlayer.new()
                _amb_oneshot_player.bus = "Ambience"
                add_child(_amb_oneshot_player)
        # quiet, distant feel: random pan would need stereo panner; volume + variance is enough
        _amb_oneshot_player.stream = stream
        _amb_oneshot_player.volume_db = randf_range(-14.0, -7.0)
        _amb_oneshot_player.play()


# ---------------- SFX ----------------
func play_sfx(sfx_id: String, volume_db: float = 0.0) -> void:
        var stream: AudioStream = _get_sfx(sfx_id)
        if stream == null:
                return
        for p in _sfx_pool_2d:
                if not p.playing:
                        p.stream = stream
                        p.volume_db = volume_db
                        p.play()
                        return


func play_spatial(sfx_id: String, position: Vector3) -> void:
        var stream: AudioStream = _get_sfx(sfx_id)
        if stream == null:
                return
        # pick nearest idle spatial player
        var best: AudioStreamPlayer3D = null
        var best_dist := 1e9
        for p3 in _spatial_pool:
                if not p3.is_inside_tree():
                        continue
                if not p3.playing:
                        p3.global_position = position
                        p3.stream = stream
                        p3.play()
                        return
                var d: float = p3.global_position.distance_to(position)
                if d < best_dist:
                        best_dist = d
                        best = p3
        if best:
                best.global_position = position
                best.stream = stream
                best.play()


func _get_sfx(sfx_id: String) -> AudioStream:
        if _sfx_cache.has(sfx_id):
                return _sfx_cache[sfx_id]
        var path: String = SFX_DIR + sfx_id + ".ogg"
        if not ResourceLoader.exists(path):
                _sfx_cache[sfx_id] = null
                return null
        var s: AudioStream = load(path)
        _sfx_cache[sfx_id] = s
        return s


# Engine loop helpers for vehicles (pitched loop handled by vehicle scripts).
func make_engine_loop() -> AudioStreamPlayer3D:
        var p := AudioStreamPlayer3D.new()
        p.bus = "SFX"
        p.max_distance = 60.0
        var path: String = SFX_DIR + "engine_loop.wav"
        if ResourceLoader.exists(path):
                p.stream = load(path)
        return p
