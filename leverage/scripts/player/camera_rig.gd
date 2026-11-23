class_name CameraRig
extends Node3D
## CameraRig - third-person spring-arm camera with touch/mouse orbit and
## lock-on tracking. Parent to the player; follows smoothly.

const ARM_LENGTH := 3.6
const ARM_MARGIN := 0.4
const PITCH_MIN := -1.05
const PITCH_MAX := 0.75
const SENSITIVITY := 0.0025
const LOCKON_LERP := 8.0

var yaw := 0.0
var pitch := -0.22
var spring: SpringArm3D
var camera: Camera3D
var follow_target: Node3D
var lock_target: Node3D = null
var _shake_time := 0.0
var _shake_mag := 0.0


func _ready() -> void:
        spring = SpringArm3D.new()
        spring.spring_length = ARM_LENGTH
        spring.collision_mask = 1 | 8
        spring.add_excluded_object(get_parent().get_rid()) if get_parent() is CollisionObject3D else null
        add_child(spring)
        camera = Camera3D.new()
        camera.fov = 62.0
        camera.current = true
        spring.add_child(camera)
        # slight downward default
        rotation = Vector3(pitch, yaw, 0)


func _process(delta: float) -> void:
        if follow_target == null or not is_instance_valid(follow_target):
                return
        # follow position
        var target_pos: Vector3 = follow_target.global_position + Vector3(0, 1.4, 0)
        global_position = global_position.lerp(target_pos, clamp(14.0 * delta, 0, 1))
        # orbit input
        var look: Vector2 = InputRouter.camera_delta
        if not InputRouter.ui_blocking and lock_target == null:
                yaw -= look.x * SENSITIVITY * float(SaveSystem.settings.get("camera_sensitivity", 1.0))
                pitch -= look.y * SENSITIVITY * float(SaveSystem.settings.get("camera_sensitivity", 1.0))
                if bool(SaveSystem.settings.get("invert_y", false)):
                        pitch += 2.0 * look.y * SENSITIVITY
                pitch = clamp(pitch, PITCH_MIN, PITCH_MAX)
        # lock-on aim
        if lock_target != null and is_instance_valid(lock_target):
                var to_t: Vector3 = lock_target.global_position + Vector3(0, 1.2, 0) - global_position
                var want_yaw := atan2(-to_t.x, -to_t.z)
                var want_pitch: float = clampf(asin(clampf(to_t.normalized().y, -1.0, 1.0)) * 0.8, PITCH_MIN, PITCH_MAX)
                yaw = lerp_angle(yaw, want_yaw, clamp(LOCKON_LERP * delta, 0, 1))
                pitch = lerp(pitch, -want_pitch, clamp(LOCKON_LERP * delta, 0, 1))
        rotation = Vector3(pitch, yaw, _shake(delta))


func _shake(delta: float) -> float:
        if _shake_time <= 0.0:
                return 0.0
        _shake_time -= delta
        var t: float = _shake_time / 0.25
        return sin(_shake_time * 60.0) * _shake_mag * t


func shake(mag := 0.12, time := 0.25) -> void:
        _shake_mag = mag
        _shake_time = time


func set_lock_target(target: Node3D) -> void:
        lock_target = target


func world_cam() -> Camera3D:
        return camera
