extends Node
## TimeWeather - day/night cycle + weather states for Cinder City.
## Drives ambient light color, street lights, rain particles, wet surfaces,
## NPC schedules (via hour_changed) and radio/weather reports.

const MINUTES_PER_REAL_SECOND := 1.0   # 1 real second = 1 game minute -> 24h day = 24 min
const HOURS_PER_DAY := 24.0

var _elapsed_hours := 17.4           # new game starts 17:24 day 1 - golden hour
var day_count := 1
var current_weather := "clear"
var _weather_timer := 120.0
var _weather_queue: Array = ["clear", "clear", "overcast", "clear", "rain", "clear", "overcast", "rain", "storm", "clear"]
var _weather_index := 0
var rain_intensity := 0.0            # 0..1, smooth
var _target_rain := 0.0

# Dawn / dusk / night color grading handled in WorldEnvironment (world.gd).


func _ready() -> void:
        EventBus.area_entered.connect(func(_a): pass)


func _process(delta: float) -> void:
        _advance_time(delta)
        _update_weather(delta)


func _advance_time(delta: float) -> void:
        var prev_hour := int(_elapsed_hours) % 24
        _elapsed_hours += (delta * MINUTES_PER_REAL_SECOND) / 60.0
        var new_hour := int(_elapsed_hours) % 24
        while _elapsed_hours >= HOURS_PER_DAY:
                _elapsed_hours -= HOURS_PER_DAY
                day_count += 1
        if new_hour != prev_hour:
                EventBus.time_hour_changed.emit(new_hour)


func get_elapsed_game_hours() -> float:
        return _elapsed_hours


## Dev/probe helper: jump the clock (used by the key-art capture for dusk).
func force_hour(h: float) -> void:
        var prev_hour := int(_elapsed_hours) % 24
        _elapsed_hours = h
        var new_hour := int(_elapsed_hours) % 24
        if new_hour != prev_hour:
                EventBus.time_hour_changed.emit(new_hour)


func get_clock_text() -> String:
        var h := int(_elapsed_hours) % 24
        var m := int((_elapsed_hours - floor(_elapsed_hours)) * 60.0)
        return "%02d:%02d" % [h, m]


func hour() -> int:
        return int(_elapsed_hours) % 24


func is_night() -> bool:
        var h := hour()
        return h >= 20 or h < 6


func time_of_day_id() -> String:
        var h := hour()
        if h >= 5 and h < 9: return "dawn"
        if h >= 9 and h < 17: return "day"
        if h >= 17 and h < 20: return "dusk"
        return "night"


## Multiplier used by NPCDirector for schedule pressure (rush hours).
func schedule_pressure() -> float:
        var h := hour()
        if (h >= 7 and h <= 9) or (h >= 17 and h <= 19):
                return 1.0
        if h >= 22 or h <= 5:
                return 0.25
        return 0.6


func _update_weather(delta: float) -> void:
        _weather_timer -= delta
        if _weather_timer <= 0.0:
                _next_weather()
        rain_intensity = lerp(rain_intensity, _target_rain, clamp(delta * 0.15, 0.0, 1.0))


func _next_weather() -> void:
        _weather_index = (_weather_index + 1) % _weather_queue.size()
        set_weather(_weather_queue[_weather_index])
        _weather_timer = randf_range(180.0, 420.0)


func set_weather(weather_id: String) -> void:
        current_weather = weather_id
        match weather_id:
                "rain": _target_rain = 0.8
                "storm": _target_rain = 1.0
                "overcast": _target_rain = 0.0
                _: _target_rain = 0.0
        EventBus.weather_changed.emit(weather_id)


func is_raining() -> bool:
        return rain_intensity > 0.25


## Serializable state for saves.
func snapshot() -> Dictionary:
        return {"elapsed_hours": _elapsed_hours, "day": day_count,
                "weather": current_weather, "rain": rain_intensity}


func restore(data: Dictionary) -> void:
        _elapsed_hours = float(data.get("elapsed_hours", 8.0))
        day_count = int(data.get("day", 1))
        set_weather(String(data.get("weather", "clear")))
        rain_intensity = float(data.get("rain", 0.0))
