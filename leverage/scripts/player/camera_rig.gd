class_name CameraRig
extends Node3D
## CameraRig - third-person spring-arm camera with touch/mouse orbit and
## lock-on tracking. Parent to the player; follows smoothly.

const ARM_LENGTH := 4.3
const ARM_SPRINT_EXTRA := 0.8
const ARM_MARGIN := 0.4
const PITCH_MIN := -1.05
const PITCH_MAX := 0.75
const SENSITIVITY := 0.0025
const LOCKON_LERP := 8.0
const FOLLOW_LERP := 9.5             # cinematic trailing (was 14: snappy)
const LOOKAHEAD := 0.32             # seconds of velocity lookahead
const BASE_FOV := 66.0

var yaw := 0.0
var pitch := -0.22
var spring: SpringArm3D
var camera: Camera3D
var follow_target: Node3D
var lock_target: Node3D = null
var _shake_time := 0.0
var _shake_mag := 0.0
var _shake_dur := 0.25
var _kick := 0.0            # impact pitch kick, decays
var _kick_vel := 0.0
var _fov_extra := 0.0       # transient FOV offset (slow-mo punch-in)
var _fov_target := 0.0
var sprint_fov := 0.0       # set by PlayerController (sprint speed feel)
var _breath_t := 0.0       # idle micro-sway phase


func _ready() -> void:
        spring = SpringArm3D.new()
        spring.spring_length = ARM_LENGTH
        spring.collision_mask = 1 | 8
        spring.add_excluded_object(get_parent().get_rid()) if get_parent() is CollisionObject3D else null
        add_child(spring)
        camera = Camera3D.new()
        camera.fov = BASE_FOV
        camera.current = true
        spring.add_child(camera)
        # slight downward default
        rotation = Vector3(pitch, yaw, 0)


func _process(delta: float) -> void:
        if follow_target == null or not is_instance_valid(follow_target):
                return
        # kick spring: sharp pitch jolt on impact, critically damped return
        _kick_vel += (-140.0 * _kick - 22.0 * _kick_vel) * delta
        _kick += _kick_vel * delta
        _fov_extra = lerpf(_fov_extra, _fov_target, clamp(6.0 * delta, 0.0, 1.0))
        camera.fov = BASE_FOV + _fov_extra + sprint_fov
        # sprint stretches the arm for speed feel
        var sprint_amt := clampf(sprint_fov / 6.0, 0.0, 1.0)
        spring.spring_length = lerpf(spring.spring_length, ARM_LENGTH + ARM_SPRINT_EXTRA * sprint_amt, clamp(4.0 * delta, 0.0, 1.0))
        # follow position with velocity lookahead (cinematic trailing)
        var vel := Vector3.ZERO
        if follow_target is CharacterBody3D:
                vel = (follow_target as CharacterBody3D).velocity
        var target_pos: Vector3 = follow_target.global_position + Vector3(0, 1.4, 0) + vel * LOOKAHEAD * Vector3(1, 0.25, 1)
        global_position = global_position.lerp(target_pos, clamp(FOLLOW_LERP * delta, 0, 1))
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
        # idle micro-breath keeps the frame alive even when still
        _breath_t += delta
        var breath := sin(_breath_t * 0.9) * 0.006 + sin(_breath_t * 1.7) * 0.003
        rotation = Vector3(pitch + _kick + breath, yaw, _shake(delta))


func kick(strength := 0.05) -> void:
        _kick = clamp(_kick - strength, -0.3, 0.0)
        _kick_vel = -1.2 * strength * 60.0


## Punch-in for slow-motion finishes: negative fov_offset = zoom in.
func zoom_fov(fov_offset := -6.0, hold := 0.7) -> void:
        _fov_target = fov_offset
        var tree := get_tree()
        if tree != null:
                tree.create_timer(hold, true, false, true).timeout.connect(func() -> void:
                        _fov_target = 0.0)


func _shake(delta: float) -> float:
        if _shake_time <= 0.0:
                return 0.0
        _shake_time -= delta
        var t: float = _shake_time / _shake_dur
        # two incommensurate frequencies read as impact noise, not wobble
        return (sin(_shake_time * 62.0) + 0.5 * sin(_shake_time * 149.0)) * _shake_mag * t


func shake(mag := 0.12, time := 0.25) -> void:
        _shake_mag = mag
        _shake_time = time
        _shake_dur = maxf(time, 0.05)


func set_lock_target(target: Node3D) -> void:
        lock_target = target


func world_cam() -> Camera3D:
        return camera
