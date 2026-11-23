class_name TrafficAgent
extends Node3D
## TrafficAgent - lightweight kinematic traffic car on the road graph.
## Follows lane segments, obeys CityDirector traffic light phases, avoids
## pedestrians/player (simple probe), reports accidents. Visual = GLB car.


const SPEED := 8.0
const BIKE_SPEED := 9.6          # bikes filter through traffic a touch faster
const BRAKE_DIST := 9.0
const BIKE_BRAKE_DIST := 7.0     # nimbler front-end stop

var car_glb := "res://assets/vehicles/sedan.glb"
var route: Array = []            # of Vector2 lane points
var route_idx := 0
var speed := SPEED
var visual: Node3D
var _stopped := false
var player_drivable := false
var vehicle_kind := "sedan"
var _t := 0.0


func _ready() -> void:
        if ResourceLoader.exists(car_glb):
                var packed: PackedScene = load(car_glb)
                visual = packed.instantiate()
                add_child(visual)
        if is_bike():
                _seat_npc_rider()


## A rider-less moving bike reads as a ghost bike: seat an NPC on traffic
## motorcycles. Rides as a child of the VISUAL so it carries over when the
## agent is jacked (the jack pulls the rider off — see Motorcycle code).
func _seat_npc_rider() -> void:
        if visual == null:
                return
        var rng := RandomNumberGenerator.new()
        rng.seed = hash(get_instance_id())
        var npc: Node3D = CharacterFactory.make_random_ped(rng)
        npc.name = "AgentRider"
        visual.add_child(npc)
        npc.position = Vector3(0, 0.52, 0.02)
        npc.rotation.y = PI
        var ap := _find_first_anim(npc)
        if ap != null and ap.has_animation("Sitting_Idle"):
                ap.play("Sitting_Idle")


static func _find_first_anim(node: Node) -> AnimationPlayer:
        if node is AnimationPlayer:
                return node
        for c in node.get_children():
                var r := _find_first_anim(c)
                if r != null:
                        return r
        return null


func is_bike() -> bool:
        return vehicle_kind == "motorcycle"


func cruise_speed() -> float:
        return BIKE_SPEED if is_bike() else SPEED


func brake_dist() -> float:
        return BIKE_BRAKE_DIST if is_bike() else BRAKE_DIST


func _process(delta: float) -> void:
        _t += delta
        if route.size() < 2:
                return
        var target: Vector2 = route[route_idx]
        var pos2 := Vector2(global_position.x, global_position.z)
        # traffic light check when close to intersection
        var speed_mult := 1.0
        if WorldEvents.is_road_closed(_road_id()) and route_idx < 2:
                speed_mult = 0.0
        # obstacle probe ahead
        if _obstacle_ahead():
                speed_mult = 0.0
        elif _near_intersection_red():
                speed_mult = 0.0
        speed = lerp(speed, cruise_speed() * speed_mult, clamp(2.5 * delta, 0, 1))
        if speed > 0.05:
                var to_t := target - pos2
                var dist := to_t.length()
                var step := speed * delta
                if dist <= step:
                        route_idx += 1
                        if route_idx >= route.size():
                                _loop_route()
                else:
                        var dir := to_t / dist
                        pos2 += dir * step
                        global_position = Vector3(pos2.x, 0, pos2.y)
                        global_rotation.y = atan2(dir.x, dir.y) + PI / 2.0


func _road_id() -> String:
        return String(get_meta("road_id") if has_meta("road_id") else "")


func _near_intersection_red() -> bool:
        var road: String = _road_id()
        if road == "":
                return false
        return not CityDirector.light_is_green(road) and speed < 4.0 and randf() < 0.2


func _obstacle_ahead() -> bool:
        var fwd := -global_transform.basis.z
        var probe: Vector3 = global_position + fwd * brake_dist()
        for node in get_tree().get_nodes_in_group("player"):
                if node is Node3D:
                        var d: Vector3 = node.global_position - global_position
                        if d.length() < brake_dist() and fwd.dot(d.normalized()) > 0.5:
                                return true
        for node in get_tree().get_nodes_in_group("pedestrian"):
                if node is Node3D and is_instance_valid(node):
                        var d: Vector3 = node.global_position - global_position
                        if d.length() < brake_dist() * 0.7 and fwd.dot(d.normalized()) > 0.6:
                                return true
        return false


func _loop_route() -> void:
        route_idx = 0
        # occasionally reverse direction
        if randf() < 0.25:
                route.reverse()


## Player jacks this car: strip agent logic, hand over to a player vehicle.
## Bikes convert to a real Motorcycle body; cars to VehiclePlayer.
func convert_to_player_vehicle() -> Node3D:
        set_process(false)
        return VehiclePlayer.create_from_agent(self, vehicle_kind)


static func make_route_for_road(road: Dictionary, side: float) -> Array:
        ## Lane offset perpendicular to road; returns Vector2 waypoints.
        var a: Vector2 = road["a"]
        var b: Vector2 = road["b"]
        var dir := (b - a).normalized()
        var perp := Vector2(-dir.y, dir.x) * side
        var pts: Array = [a + perp, b + perp]
        return pts
