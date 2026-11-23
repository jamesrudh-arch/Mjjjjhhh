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


func _ready() -> void:
        _rng.seed = 424242


func _process(_delta: float) -> void:
        var player := get_tree().get_first_node_in_group("player") as Node3D
        if player == null:
                return
        # maintain population
        _prune_far(player)
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


func _spawn_near(player: Node3D) -> void:
        # pick a road point ~90-140 m from player
        var road: Dictionary = ROADS[_rng.randi_range(0, ROADS.size() - 1)]
        var a: Vector2 = road["a"]
        var b: Vector2 = road["b"]
        var dir := (b - a).normalized()
        var length := (b - a).length()
        var t := _rng.randf()
        var p := a + dir * (t * length)
        var side: float = 4.0 if _rng.randf() < 0.5 else -4.0
        var pp := player.global_position
        var d: float = Vector2(pp.x, pp.z).distance_to(p)
        if d < 60.0 or d > 170.0:
                return
        var idx := _rng.randi_range(0, AGENT_TYPES.size() - 1)
        var agent := TrafficAgent.new()
        agent.car_glb = AGENT_TYPES[idx]
        agent.vehicle_kind = KIND_NAMES[idx]
        agent.position = Vector3(p.x + side, 0, p.y + side * 0.5)
        agent.set_meta("road_id", road["id"])
        var lane: Array = TrafficAgent.make_route_for_road(road, side)
        agent.route = lane
        agent.route_idx = 0
        add_child(agent)
        agents.append(agent)
        # visual tint
        if agent.visual:
                var mi := agent.visual.find_child("*MeshInstance*", true, false)


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
