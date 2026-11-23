extends Node
## SaveSystem - 3 manual slots + autosave. JSON files under user://saves/.
## Persists GameState snapshot + world positions of key entities + settings.

const SAVE_DIR := "user://saves"
const SLOTS := 3
const SLOT_AUTOSAVE := 0
const VERSION := 1

var _last_world_data: Dictionary = {}
var settings := {
	"master_volume": 0.9,
	"music_volume": 0.7,
	"sfx_volume": 1.0,
	"ambience_volume": 0.8,
	"subtitles": true,
	"subtitle_size": 1.0,
	"camera_sensitivity": 1.0,
	"invert_y": false,
	"graphics_quality": "high",
	"show_minimap": true,
	"hud_scale": 1.0,
}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	_load_settings()


# ---------- Settings ----------
func _settings_path() -> String:
	return SAVE_DIR + "/settings.json"


func _load_settings() -> void:
	if FileAccess.file_exists(_settings_path()):
		var f := FileAccess.open(_settings_path(), FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				for key in parsed.keys():
					settings[key] = parsed[key]
			f.close()


func save_settings() -> void:
	var f := FileAccess.open(_settings_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "\t"))
		f.close()
	EventBus.settings_changed.emit("settings")


func apply_audio_settings() -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(float(settings.get("master_volume", 0.9))))
	var music_idx := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(music_idx, linear_to_db(float(settings.get("music_volume", 0.7))))
	var sfx_idx := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(float(settings.get("sfx_volume", 1.0))))
	var amb_idx := AudioServer.get_bus_index("Ambience")
	AudioServer.set_bus_volume_db(amb_idx, linear_to_db(float(settings.get("ambience_volume", 0.8))))


# ---------- Game saves ----------
func slot_path(slot: int) -> String:
	return SAVE_DIR + "/slot_%d.json" % slot


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or DirAccess.dir_exists_absolute(SAVE_DIR) and _slot_has_file(slot)


func _slot_has_file(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func slot_info(slot: int) -> Dictionary:
	var p := slot_path(slot)
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if not f:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary:
		var gs: Dictionary = data.get("game_state", {})
		return {
			"exists": true,
			"money": int(gs.get("money", 0)),
			"playtime": float(gs.get("playtime_seconds", 0.0)),
			"chapter": int(gs.get("story_flags", {}).get("chapter", 1)),
			"area": gs.get("current_area", "old_quarter"),
			"timestamp": data.get("timestamp", ""),
		}
	return {}


func _any_slot_used() -> bool:
	for s in range(SLOTS + 1):
		if FileAccess.file_exists(slot_path(s)):
			return true
	return false


func has_any_save() -> bool:
	return _any_slot_used()


func save_game(slot: int) -> bool:
	var payload := {
		"version": VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"game_state": GameState.snapshot(),
		"world": _last_world_data,
		"settings": settings,
	}
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if not f:
		push_error("Save failed for slot %d" % slot)
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	EventBus.save_completed.emit(slot)
	return true


func autosave() -> bool:
	capture_world_state()
	return save_game(SLOT_AUTOSAVE)


func load_game(slot: int) -> bool:
	var p := slot_path(slot)
	if not FileAccess.file_exists(p):
		return false
	var f := FileAccess.open(p, FileAccess.READ)
	if not f:
		return false
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary:
		GameState.restore(data.get("game_state", {}))
		_last_world_data = data.get("world", {})
		var st: Dictionary = data.get("settings", {})
		for key in st.keys():
			settings[key] = st[key]
		EventBus.load_completed.emit(slot)
		return true
	return false


func delete_slot(slot: int) -> void:
	var p := slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)


## Called by the world before saving: player position, active vehicles, time/weather.
func capture_world_state() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var data := {
		"time_of_day": TimeWeather.get_elapsed_game_hours() if TimeWeather != null else 8.0,
		"weather": TimeWeather.current_weather if TimeWeather != null else "clear",
	}
	if player and player is Node3D:
		data["player_pos"] = [player.global_position.x, player.global_position.y, player.global_position.z]
		data["player_rot"] = player.global_rotation.y
	_last_world_data = data


func world_data() -> Dictionary:
	return _last_world_data


func player_resume_position() -> Vector3:
	var pp = _last_world_data.get("player_pos", null)
	if pp is Array and pp.size() == 3:
		return Vector3(float(pp[0]), float(pp[1]), float(pp[2]))
	return Vector3.ZERO
