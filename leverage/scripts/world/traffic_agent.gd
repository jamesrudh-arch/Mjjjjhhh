class_name TrafficAgent
extends Node3D
## TrafficAgent - lightweight kinematic traffic car on the road graph.
## Follows lane segments, obeys CityDirector traffic light phases, avoids
## pedestrians/player (simple probe), reports accidents. Visual = GLB car.


const SPEED := 8.0
const BRAKE_DIST := 9.0

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
        speed = lerp(speed, SPEED * speed_mult, clamp(2.5 * delta, 0, 1))
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
        var probe: Vector3 = global_position + fwd * BRAKE_DIST
        for node in get_tree().get_nodes_in_group("player"):
                if node is Node3D:
                        var d: Vector3 = node.global_position - global_position
                        if d.length() < BRAKE_DIST and fwd.dot(d.normalized()) > 0.5:
                                return true
        for node in get_tree().get_nodes_in_group("pedestrian"):
                if node is Node3D and is_instance_valid(node):
                        var d: Vector3 = node.global_position - global_position
                        if d.length() < BRAKE_DIST * 0.7 and fwd.dot(d.normalized()) > 0.6:
                                return true
        return false


func _loop_route() -> void:
        route_idx = 0
        # occasionally reverse direction
        if randf() < 0.25:
                route.reverse()


## Player jacks this car: strip agent logic, hand over to VehiclePlayer.
func convert_to_player_vehicle() -> Node3D:
        set_process(false)
        var body := VehiclePlayer.create_from_agent(self, vehicle_kind)
        return body


static func make_route_for_road(road: Dictionary, side: float) -> Array:
        ## Lane offset perpendicular to road; returns Vector2 waypoints.
        var a: Vector2 = road["a"]
        var b: Vector2 = road["b"]
        var dir := (b - a).normalized()
        var perp := Vector2(-dir.y, dir.x) * side
        var pts: Array = [a + perp, b + perp]
        return pts
