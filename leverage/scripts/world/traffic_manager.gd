class_name TrafficManager
extends Node3D
## TrafficManager - owns N traffic agents distributed over the road graph,
## respawning far ones near the player (density by area + time + events).

const AGENT_TYPES := [
        "res://assets/vehicles/sedan.glb",
        "res://assets/vehicles/hatch.glb",
        "res://assets/vehicles/suv.glb",
        "res://assets/vehicles/sport.glb",
        "res://assets/vehicles/taxi.glb",
]
const KIND_NAMES := ["sedan", "hatch", "suv", "sport", "taxi"]
const BIKE_GLB := "res://assets/vehicles/motorcycle.glb"
const BIKE_CHANCE := 0.14                # share of spawns that are bikes (D6)
const SEED_BIKES := 2                    # deterministic bikes present from first frame

const ROADS := [
        {"id": "main_cross", "a": Vector2(-450, -10), "b": Vector2(450, -10)},
        {"id": "civic_avenue", "a": Vector2(10, -720), "b": Vector2(10, 420)},
        {"id": "bridge_avenue", "a": Vector2(80, -200), "b": Vector2(450, -200)},
        {"id": "old_docks_road", "a": Vector2(-450, 30), "b": Vector2(-80, 30)},
        {"id": "strip_road", "a": Vector2(80, 230), "b": Vector2(450, 230)},
]

var agents: Array = []
var target_count := 14
var _rng := RandomNumberGenerator.new()
var _bikes_seeded := false


func _ready() -> void:
        _rng.seed = 424242


func _process(_delta: float) -> void:
        var player := get_tree().get_first_node_in_group("player") as Node3D
        if player == null:
                return
        # maintain population
        _prune_far(player)
        if not _bikes_seeded:
                _bikes_seeded = true
                for i in SEED_BIKES:
                        _spawn_near(player, true)
        if agents.size() < target_count:
                _spawn_near(player)


func _prune_far(player: Node3D) -> void:
        for a in agents.duplicate():
                if not is_instance_valid(a):
                        agents.erase(a)
                        continue
                if a is Node3D:
                        var d: float = player.global_position.distance_to(a.global_position)
                        if d > 240.0:
                                a.queue_free()
                                agents.erase(a)


func _spawn_near(player: Node3D, force_bike := false) -> void:
        # pick a road point ~90-140 m from player (seeded bikes use the nearest road)
        var road: Dictionary = ROADS[_rng.randi_range(0, ROADS.size() - 1)]
        if force_bike:
                road = _nearest_road(Vector2(player.global_position.x, player.global_position.z))
        var a: Vector2 = road["a"]
        var b: Vector2 = road["b"]
        var dir := (b - a).normalized()
        var length := (b - a).length()
        var t := _rng.randf()
        var p := a + dir * (t * length)
        var side: float = 4.0 if _rng.randf() < 0.5 else -4.0
        var pp := player.global_position
        var d: float = Vector2(pp.x, pp.z).distance_to(p)
        if force_bike:
                # walk the road to the point closest to ~95 m from the player
                var best_p := p
                var best_d := absf(d - 95.0)
                for s in 13:
                        var q: Vector2 = a + dir * (float(s) / 12.0) * length
                        var dq: float = absf(Vector2(pp.x, pp.z).distance_to(q) - 95.0)
                        if dq < best_d:
                                best_d = dq
                                best_p = q
                p = best_p
                d = Vector2(pp.x, pp.z).distance_to(p)
        elif d < 60.0 or d > 170.0:
                return
        var agent := TrafficAgent.new()
        if force_bike or _rng.randf() < BIKE_CHANCE:
                agent.car_glb = BIKE_GLB
                agent.vehicle_kind = "motorcycle"
        else:
                var idx := _rng.randi_range(0, AGENT_TYPES.size() - 1)
                agent.car_glb = AGENT_TYPES[idx]
                agent.vehicle_kind = KIND_NAMES[idx]
        agent.position = Vector3(p.x + side, 0, p.y + side * 0.5)
        agent.set_meta("road_id", road["id"])
        var lane: Array = TrafficAgent.make_route_for_road(road, side)
        agent.route = lane
        agent.route_idx = 0
        add_child(agent)
        agents.append(agent)


func _nearest_road(pos2: Vector2) -> Dictionary:
        var best: Dictionary = ROADS[0]
        var best_d := INF
        for r in ROADS:
                var cp := _closest_point_on_segment(pos2, r["a"], r["b"])
                var dq: float = pos2.distance_to(cp)
                if dq < best_d:
                        best_d = dq
                        best = r
        return best


static func _closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
        var ab := b - a
        if ab.length_squared() < 0.0001:
                return a
        var tt: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
        return a + ab * tt


func agent_by_proximity(pos: Vector3, radius := 3.0) -> TrafficAgent:
        var best: TrafficAgent = null
        var best_d := radius
        for a in agents:
                if is_instance_valid(a) and a is Node3D:
                        var d: float = pos.distance_to(a.global_position)
                        if d < best_d:
                                best_d = d
                                best = a
        return best
