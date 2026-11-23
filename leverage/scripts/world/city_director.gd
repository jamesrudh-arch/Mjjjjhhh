extends Node
## CityDirector - authoritative area registry + area awareness for the player.
## Areas defined in docs/world_design.md. Emits area_entered/area_exited,
## tracks discovery, supplies per-area metadata (police response, ambience,
## spawn tables, district tints).

const AREAS := {
        "old_quarter": {
                "display": "Old Quarter", "color": Color("6e4a33"),
                "police_response": 1.0, "ped_density": 1.0, "night_ped": 0.4,
                "bounds": Rect2(-450.0, -380.0, 370.0, 340.0),
                "ambience": "amb_old_quarter",
        },
        "docklands": {
                "display": "Docklands", "color": Color("3a4448"),
                "police_response": 0.8, "ped_density": 0.6, "night_ped": 0.3,
                "bounds": Rect2(-450.0, 40.0, 370.0, 380.0),
                "ambience": "amb_docklands",
        },
        "kestrel_district": {
                "display": "Kestrel Financial District", "color": Color("5a6a7e"),
                "police_response": 1.5, "ped_density": 1.1, "night_ped": 0.5,
                "bounds": Rect2(80.0, -380.0, 370.0, 340.0),
                "ambience": "amb_kestrel",
        },
        "neon_strip": {
                "display": "Neon Strip", "color": Color("d84fa0"),
                "police_response": 0.7, "ped_density": 1.3, "night_ped": 1.4,
                "bounds": Rect2(80.0, 40.0, 370.0, 380.0),
                "ambience": "amb_neon_strip",
        },
        "ironworks": {
                "display": "Ironworks", "color": Color("7a3b28"),
                "police_response": 0.6, "ped_density": 0.4, "night_ped": 0.2,
                "bounds": Rect2(-420.0, 460.0, 300.0, 300.0),
                "ambience": "amb_ironworks",
        },
        "heights": {
                "display": "The Heights", "color": Color("8a7a5a"),
                "police_response": 1.1, "ped_density": 0.3, "night_ped": 0.1,
                "bounds": Rect2(-120.0, -720.0, 420.0, 300.0),
                "ambience": "amb_heights",
        },
}

## Road graph (lanes for traffic + chase routes). Straight segment world.
const ROADS := [
        {"id": "main_cross", "a": Vector2(-450, -10), "b": Vector2(450, -10)},
        {"id": "civic_avenue", "a": Vector2(10, -720), "b": Vector2(10, 420)},
        {"id": "hill_road", "a": Vector2(-120, -420), "b": Vector2(0, -720)},
        {"id": "bridge_avenue", "a": Vector2(80, -200), "b": Vector2(450, -200)},
        {"id": "old_docks_road", "a": Vector2(-450, 30), "b": Vector2(-80, 30)},
        {"id": "iron_spine", "a": Vector2(-80, 420), "b": Vector2(-420, 460)},
        {"id": "strip_road", "a": Vector2(80, 230), "b": Vector2(450, 230)},
]

## Intersections: road id pairs + light phase (N-S green when phase < 0.5)
const INTERSECTIONS := [
        {"roads": ["main_cross", "civic_avenue"], "pos": Vector2(10, -10), "phase": 0.0},
        {"roads": ["bridge_avenue", "civic_avenue"], "pos": Vector2(10, -200), "phase": 0.25},
        {"roads": ["main_cross", "old_docks_road"], "pos": Vector2(-80, -10), "phase": 0.0},
]

var current_area := ""           # player's area id
var _phase_clock := 0.0


func _process(delta: float) -> void:
        _phase_clock = fmod(_phase_clock + delta * 0.1, 1.0)


func light_is_green(road_id: String) -> bool:
        ## Simple two-phase clock: main roads green first half.
        var is_main: bool = road_id == "main_cross" or road_id == "bridge_avenue"
        if is_main:
                return _phase_clock < 0.5
        return _phase_clock >= 0.5


## Area from world position (x, z).
func area_at(pos: Vector2) -> String:
        for id in AREAS.keys():
                var r: Rect2 = AREAS[id]["bounds"]
                if r.has_point(pos):
                        return id
        return current_area


func update_player_position(pos: Vector3) -> void:
        var id := area_at(Vector2(pos.x, pos.z))
        if id != current_area and id != "":
                var old := current_area
                current_area = id
                GameState.current_area = id
                if not GameState.visited_areas.has(id):
                        GameState.visited_areas[id] = true
                        EventBus.notification_posted.emit("New area: " + AREAS[id]["display"], "area")
                if old != "":
                        EventBus.area_exited.emit(old)
                EventBus.area_entered.emit(id)
                EventBus.ambience_area_changed.emit(id)


func area_display(id: String) -> String:
                return String(AREAS.get(id, {}).get("display", id))


func area_color(id: String) -> Color:
        return AREAS.get(id, {}).get("color", Color("444444")) as Color


func area_meta(id: String, key: String, default_val = null):
        return AREAS.get(id, {}).get(key, default_val)


func police_response_multiplier() -> float:
        return float(AREAS.get(current_area, {}).get("police_response", 1.0))


## Spawn point for patrols per area.
func patrol_anchor(area_id: String) -> Vector2:
        var r: Rect2 = AREAS.get(area_id, {}).get("bounds", Rect2(0, 0, 10, 10))
        return r.position + r.size * 0.5


## Whether position is on any road (for traffic-related queries) - tolerance 8 m.
func on_road(pos: Vector2, tol := 8.0) -> bool:
        for road in ROADS:
                if _dist_to_segment(pos, road["a"], road["b"]) <= tol:
                        return true
        return false


func nearest_road_point(pos: Vector2) -> Dictionary:
        var best := {"id": "", "point": pos, "dist": 1e9}
        for road in ROADS:
                var p := _closest_on_segment(pos, road["a"], road["b"])
                var d: float = pos.distance_to(p)
                if d < float(best["dist"]):
                        best = {"id": road["id"], "point": p, "dist": d}
        return best


func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
        return p.distance_to(_closest_on_segment(p, a, b))


func _closest_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
        var ab := b - a
        var l2 := ab.length_squared()
        if l2 < 0.001:
                return a
        var t: float = clamp((p - a).dot(ab) / l2, 0.0, 1.0)
        return a + ab * t
