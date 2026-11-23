extends Node
## WorldEvents - persistent world events (see docs/world_design.md).
## Events trigger by day/time or by story flag, alter world behaviour while
## active, and end on duration or condition. Persisted across saves.

## Definition tables kept in code (4.4-safe loading; see TDL #6 in docs).
const EVENTS := {
	"market_bust": {
		"trigger": {"type": "time", "day": 1, "hour": 10},
		"duration_h": 2.0,
		"area": "old_quarter",
		"effects": {"police_patrols": 2, "ped_density": -0.4, "market_stalls": false},
		"title": "Police raid on the Old Quarter market",
	},
	"dock_strike": {
		"trigger": {"type": "flag", "flag": "dock_strike_declared"},
		"duration_h": 6.0,
		"area": "docklands",
		"effects": {"traffic_speed": 0.6, "ped_density": 0.3, "vetch_hostile": true},
		"title": "Dock workers' strike",
	},
	"storm_warning": {
		"trigger": {"type": "weather", "weather": "storm"},
		"duration_h": 1.5,
		"area": "all",
		"effects": {"indoors_pressure": 1.0},
		"title": "Storm over Cinder City",
	},
	"neon_blackout": {
		"trigger": {"type": "flag", "flag": "blackout_sabotage_done"},
		"duration_h": 8.0,
		"area": "neon_strip",
		"effects": {"neon_lights": false, "crime_boost": 0.25},
		"title": "Neon Strip blackout",
	},
	"turf_skirmish": {
		"trigger": {"type": "rep", "faction": "family", "below": -20.0},
		"duration_h": 4.0,
		"area": "old_quarter",
		"effects": {"vetch_patrols": 3, "danger": 0.4},
		"title": "Vetch Crew moves on Old Quarter alleys",
	},
	"mayoral_parade": {
		"trigger": {"type": "time", "day": 3, "hour": 14},
		"duration_h": 1.5,
		"area": "all",
		"effects": {"main_cross_closed": true, "ped_density": 1.2, "police_patrols": 3},
		"title": "Mayoral parade closes Main Cross",
	},
}

## area id -> multiplier on event effects (events feel different by district)
const AREA_EVENT_WEIGHT := {
	"old_quarter": 1.0, "docklands": 1.0, "kestrel_district": 1.2,
	"neon_strip": 0.8, "ironworks": 0.9, "heights": 1.0,
}

var _active := {}          # event_id -> {ends_h: float}
var _fired_persistent := {}  # event_id -> true (one-shot flags/time events)
var _announced := {}       # event_id -> true (toast already shown)


func _ready() -> void:
        EventBus.story_flag_set.connect(_on_story_flag)
        EventBus.weather_changed.connect(_on_weather_changed)
        EventBus.time_hour_changed.connect(_on_hour)


func _process(_delta: float) -> void:
        var h: float = TimeWeather.get_elapsed_game_hours() + TimeWeather.day_count * 24.0
        for eid in _active.keys():
                var a: Dictionary = _active[eid]
                if h >= float(a.get("ends_h", 1e9)):
                        _end(eid)


func _on_hour(hour: int) -> void:
        for eid in EVENTS.keys():
                if _active.has(eid) or _fired_persistent.has(eid):
                        continue
                var def: Dictionary = EVENTS[eid]
                var tr: Dictionary = def.get("trigger", {})
                if tr.get("type", "") == "time":
                        var day_ok: bool = TimeWeather.day_count >= int(tr.get("day", 1))
                        var hour_ok: bool = hour == int(tr.get("hour", 0))
                        if day_ok and hour_ok:
                                _start(eid)


func _on_story_flag(flag: String, value) -> void:
        for eid in EVENTS.keys():
                if _active.has(eid) or _fired_persistent.has(eid):
                        continue
                var tr: Dictionary = EVENTS[eid].get("trigger", {})
                if tr.get("type", "") == "flag" and tr.get("flag", "") == flag and bool(value):
                        _start(eid)
                        _fired_persistent[eid] = true


func _on_weather_changed(weather_id: String) -> void:
        for eid in EVENTS.keys():
                if _active.has(eid):
                        if eid == "storm_warning" and weather_id != "storm":
                                _end(eid)
                        continue
                var tr: Dictionary = EVENTS[eid].get("trigger", {})
                if tr.get("type", "") == "weather" and tr.get("weather", "") == weather_id:
                        _start(eid)


func _on_rep_check() -> void:
        for eid in EVENTS.keys():
                if _active.has(eid) or _fired_persistent.has(eid):
                        continue
                var tr: Dictionary = EVENTS[eid].get("trigger", {})
                if tr.get("type", "") == "rep":
                        if GameState.reputation_for(tr.get("faction", "")) < float(tr.get("below", 0.0)):
                                _start(eid)
                                _fired_persistent[eid] = true


func _start(eid: String) -> void:
        var def: Dictionary = EVENTS[eid]
        var h: float = TimeWeather.get_elapsed_game_hours() + TimeWeather.day_count * 24.0
        _active[eid] = {"ends_h": h + float(def.get("duration_h", 2.0))}
        GameState.world_event_log.append(eid)
        EventBus.world_event_started.emit(eid, String(def.get("area", "all")))
        if not _announced.has(eid):
                _announced[eid] = true
                EventBus.notification_posted.emit(String(def.get("title", eid)), "world")
        _on_rep_check()


func _end(eid: String) -> void:
        _active.erase(eid)
        EventBus.world_event_ended.emit(eid)


## Queries used by the world scene + directors.
func is_active(eid: String) -> bool:
        return _active.has(eid)


func area_effects(area_id: String) -> Dictionary:
        ## Merged effects of events affecting this area ("all" hits every area).
        var out := {}
        for eid in _active.keys():
                var def: Dictionary = EVENTS[eid]
                var ev_area: String = String(def.get("area", "all"))
                if ev_area == "all" or ev_area == area_id:
                        var w: float = AREA_EVENT_WEIGHT.get(area_id, 1.0)
                        for key in def.get("effects", {}).keys():
                                var v = def["effects"][key]
                                if v is float or v is int:
                                        out[key] = float(out.get(key, 0.0)) + float(v) * w
                                else:
                                        out[key] = v
        return out


func police_modifier(area_id: String) -> int:
        return int(area_effects(area_id).get("police_patrols", 0.0))


func ped_density_modifier(area_id: String) -> float:
        return float(area_effects(area_id).get("ped_density", 0.0))


func traffic_speed_modifier(area_id: String) -> float:
        return 1.0 + float(area_effects(area_id).get("traffic_speed", 0.0))


func is_road_closed(road_id: String) -> bool:
        if road_id == "main_cross" and is_active("mayoral_parade"):
                return true
        return false


func neon_lights_on() -> bool:
        return not is_active("neon_blackout")


func crime_boost(area_id: String) -> float:
        return max(0.0, float(area_effects(area_id).get("crime_boost", 0.0)))


## Saves
func snapshot() -> Dictionary:
        return {"active": _active.duplicate(true),
                "fired": _fired_persistent.duplicate(true)}


func restore(data: Dictionary) -> void:
        _active = data.get("active", {})
        _fired_persistent = data.get("fired", {})
        for eid in _active.keys():
                EventBus.world_event_started.emit(eid, String(EVENTS.get(eid, {}).get("area", "all")))
