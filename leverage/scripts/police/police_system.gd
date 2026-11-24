extends Node
## PoliceSystem - wanted levels (0-5), heat, patrols, pursuit, roadblocks,
## line-of-sight detection, arrest, and decay. Unit spawning is requested from
## the world via signals; pure logic here so tests run headless.

const HEAT_DECAY := 0.55          # per second at level 0 pressure
const SEEN_DECAY_TIME := 12.0     # seconds unseen to lose a level
const ARREST_RANGE := 2.2
const ROADBLOCK_LEVEL := 3

## spawn request -> world listens and instantiates units.
signal unit_spawn_requested(kind: String, position: Vector3, level: int)
signal unit_despawn_requested(kind: String, position: Vector3)
signal roadblock_requested(position: Vector3)
signal siren_state_changed(active: bool)

var pursuit_active := false
var _searching := false             # pursuit live but no line-of-sight (stars blink)
var _seen_timer := 0.0            # time since police had LOS
var _los_check_accum := 0.0
var _player_pos := Vector3.ZERO
var _player_pos_valid := false
var _sirens := false
var _roadblock_spots: Array = []  # positions of active roadblocks


func _ready() -> void:
        EventBus.crime_committed.connect(_on_crime)
        EventBus.player_wanted_changed.connect(func(_l): _recompute_pursuit())
        EventBus.area_entered.connect(func(_a): _recompute_pursuit())


func set_player_position(pos: Vector3) -> void:
        _player_pos = pos
        _player_pos_valid = true


func _process(delta: float) -> void:
        # Heat decay
        if GameState.heat > 0.0 and not pursuit_active:
                GameState.heat = max(0.0, GameState.heat - HEAT_DECAY * delta)
                EventBus.player_heat_changed.emit(GameState.heat)
        # Seen/lost logic
        if pursuit_active:
                _los_check_accum += delta
                if _los_check_accum >= 0.5:
                        _los_check_accum = 0.0
                        var seen := _police_have_los()
                        _searching = not seen
                        if seen:
                                _seen_timer = 0.0
                        else:
                                _seen_timer += 0.5
                                if _seen_timer >= SEEN_DECAY_TIME:
                                        _lose_level("lost sight")
        else:
                _searching = false
        # Roadblock maintenance
        if GameState.wanted_level >= ROADBLOCK_LEVEL and _roadblock_spots.size() == 0:
                _spawn_roadblock()
        if GameState.wanted_level < ROADBLOCK_LEVEL and _roadblock_spots.size() > 0:
                _clear_roadblocks()


func _on_crime(crime_type: String, position: Vector3, severity: float, witnesses: Array) -> void:
        var boost: float = severity * (1.0 + 0.35 * witnesses.size())
        boost *= 1.0 + WorldEvents.crime_boost(CityDirector.current_area)
        boost *= CityDirector.police_response_multiplier()
        GameState.heat = clamp(GameState.heat + boost, 0.0, 100.0)
        GameState.crimes_committed += 1
        _escalate_from_heat()
        for npc_id in witnesses:
                GameState.remember_npc_event(npc_id, "witnessed_crime", 1.0)
        EventBus.sfx_requested.emit("sfx_police_radio", position)
        EventBus.player_heat_changed.emit(GameState.heat)


func _escalate_from_heat() -> void:
        var lvl := GameState.wanted_level
        if GameState.heat >= 95.0 and lvl < 5:
                _set_wanted(lvl + 1, "heat")
        elif GameState.heat >= 70.0 and lvl < 4:
                _set_wanted(lvl + 1, "heat")
        elif GameState.heat >= 45.0 and lvl < 3:
                _set_wanted(lvl + 1, "heat")
        elif GameState.heat >= 25.0 and lvl < 2:
                _set_wanted(min(2, lvl + 1), "heat")
        elif GameState.heat >= 12.0 and lvl < 1:
                _set_wanted(1, "heat")


func _set_wanted(level: int, reason: String) -> void:
        level = clamp(level, 0, 5)
        if level > GameState.wanted_level:
                GameState.wanted_level = level
                EventBus.player_wanted_changed.emit(level)
                EventBus.police_alerted.emit(level, _player_pos if _player_pos_valid else Vector3.ZERO)
                if level >= 2:
                        _sirens_on(true)
        elif level < GameState.wanted_level:
                GameState.wanted_level = level
                EventBus.player_wanted_changed.emit(level)


func _recompute_pursuit() -> void:
        pursuit_active = GameState.wanted_level > 0
        _sirens_on(pursuit_active and GameState.wanted_level >= 2)


func _police_have_los() -> bool:
        ## Simplified deterministic LOS: pursuit maintained while player is
        ## outdoors and near any road or in a patrolled area; world agents
        ## refine by tagging real sight lines via report_sighting().
        if not _player_pos_valid:
                return false
        if GameState.in_interior != "":
                return false
        return CityDirector.on_road(Vector2(_player_pos.x, _player_pos.z), 60.0)


## World agents call this when a unit truly sees the player.
func report_sighting() -> void:
        _seen_timer = 0.0
        if not pursuit_active:
                pursuit_active = true


## Pursuit is live but units have no line of sight (HUD blinks the stars).
func is_searching() -> bool:
        return pursuit_active and GameState.wanted_level > 0 and _searching


## Report the player fully evaded (e.g. hidden long enough).
func report_lost() -> void:
        _lose_level("lost sight")


func _lose_level(reason: String) -> void:
        if GameState.wanted_level > 0:
                var was_pursued := pursuit_active
                _set_wanted(GameState.wanted_level - 1, reason)
                GameState.heat = clamp(GameState.heat * 0.6, 0.0, 100.0)
                _seen_timer = 0.0
                if GameState.wanted_level == 0:
                        EventBus.police_lost_target.emit()
                        _sirens_on(false)
                        if was_pursued:
                                # evasion payoff: stinger where the player is
                                EventBus.sfx_requested.emit("sfx_wanted_clear", _player_pos if _player_pos_valid else Vector3.ZERO)


## Busted: called when an officer reaches the player at low health or player surrenders.
func arrest_player() -> void:
        GameState.player_stats["times_busted"] += 1
        GameState.track_stat("times_busted", 0)
        EventBus.player_arrested.emit()
        _busted_cleanup()


func _busted_cleanup() -> void:
        GameState.wanted_level = 0
        GameState.heat = 0.0
        EventBus.player_wanted_changed.emit(0)
        _sirens_on(false)
        _clear_roadblocks()
        pursuit_active = false


func _sirens_on(on: bool) -> void:
        if _sirens == on:
                return
        _sirens = on
        siren_state_changed.emit(on)
        EventBus.music_layer_requested.emit("chase" if on else "explore_day")


func _spawn_roadblock() -> void:
        ## Ahead of player on nearest road.
        if not _player_pos_valid:
                return
        var rp := CityDirector.nearest_road_point(Vector2(_player_pos.x, _player_pos.z))
        var dir: Vector2 = (Vector2(_player_pos.x, _player_pos.z) - rp["point"])
        if dir.length() < 1.0:
                dir = Vector2(1, 0)
        dir = dir.normalized()
        var spot: Vector2 = rp["point"] + dir * 90.0
        var pos := Vector3(spot.x, 0, spot.y)
        _roadblock_spots.append(pos)
        roadblock_requested.emit(pos)
        EventBus.roadblock_spawned.emit(pos)


func _clear_roadblocks() -> void:
        for p in _roadblock_spots:
                unit_despawn_requested.emit("roadblock", p)
        _roadblock_spots.clear()


func roadblock_positions() -> Array:
        return _roadblock_spots


## Patrol spawn plan: how many patrol units per wanted level in current area.
func patrol_plan() -> Array:
        var lvl := GameState.wanted_level
        var out: Array = []
        var base := 1 + WorldEvents.police_modifier(CityDirector.current_area)
        if lvl >= 1:
                out.append({"kind": "foot_patrol", "count": base})
        if lvl >= 2:
                out.append({"kind": "cruiser", "count": base})
        if lvl >= 3:
                out.append({"kind": "interceptor", "count": 1})
        if lvl >= 4:
                out.append({"kind": "tactical", "count": 2})
        if lvl >= 5:
                out.append({"kind": "tactical", "count": 3})
                out.append({"kind": "air_unit", "count": 1})
        return out


func crime_severity(type_id: String) -> float:
        match type_id:
                "assault": return 14.0
                "weapon_fire": return 30.0
                "vehicle_theft": return 18.0
                "hit_pedestrian": return 24.0
                "hit_vehicle": return 8.0
                "property_damage": return 6.0
                "trespass": return 4.0
                "murder": return 60.0
        return 5.0


func snapshot() -> Dictionary:
        return {"roadblocks": _roadblock_spots.duplicate(true)}


func restore(data: Dictionary) -> void:
        _clear_roadblocks()
        _recompute_pursuit()
