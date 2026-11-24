class_name PlayerController
extends CharacterBody3D
## PlayerController - Dez Carter. Movement, stamina, lock-on facing,
## animation driving (code-driven per TDL #4), interaction detection.
## Combat is layered on by CombatPlayer (sibling component node).

const WALK_SPEED := 2.4
const JOG_SPEED := 4.3
const SPRINT_SPEED := 6.8
const CROUCH_SPEED := 1.3
const ACCEL := 14.0
const DECEL := 18.0
const JUMP_VELOCITY := 4.6
const DODGE_IMPULSE := 7.2
const SPRINT_STAMINA_DRAIN := 9.0     # per second
const STAMINA_REGEN := 13.0           # per second (when not sprinting/dodging)
const INTERACT_RANGE := 2.6

var actor: Node3D                      # mannequin visual
var anim: AnimationPlayer
var camera_rig: Node3D                 # CameraRig
var lock_target: Node3D = null
var speed_mode := "jog"                # walk/jog/sprint/crouch
var _anim_state := "Idle"
var _frozen := false                  # cutscene/intro lock
var _facing_locked := false
var _step_t := 0.0                    # footstep phase
var _fov_extra := 0.0                 # sprint FOV kick (smoothed)

@onready var _combat: Node = null


func _ready() -> void:
        add_to_group("player")
        collision_layer = 2
        collision_mask = 1 | 8
        # capsule
        var shape := CollisionShape3D.new()
        var cap := CapsuleShape3D.new()
        cap.radius = 0.35
        cap.height = 1.8
        shape.shape = cap
        shape.position = Vector3(0, 0.9, 0)
        add_child(shape)
        # visual
        actor = CharacterFactory.make_player()
        actor.position = Vector3(0, 0.02, 0)
        add_child(actor)
        anim = _find_anim(actor)
        _play("Idle")
        EventBus.player_spawned.emit(self)
        EventBus.player_health_changed.emit(GameState.health, GameState.max_health)
        EventBus.player_stamina_changed.emit(GameState.stamina, GameState.max_stamina)


func _find_anim(node: Node) -> AnimationPlayer:
        if node is AnimationPlayer:
                return node
        for c in node.get_children():
                var r := _find_anim(c)
                if r:
                        return r
        return null


func _physics_process(delta: float) -> void:
        if _frozen or not GameManager.is_playing():
                velocity.x = 0
                velocity.z = 0
                if not is_on_floor():
                        velocity.y -= 9.8 * delta
                        move_and_slide()
                return
        # gravity
        if not is_on_floor():
                velocity.y -= 9.8 * delta
        # stamina
        _update_stamina(delta)
        # movement
        var input_vec: Vector2 = InputRouter.move_vector
        var cam_yaw: float = camera_yaw()
        var dir := Vector3(-input_vec.y, 0, input_vec.x).rotated(Vector3.UP, cam_yaw)
        var target_speed := _current_target_speed()
        var combat_mode: bool = _combat != null and _combat.active
        if combat_mode and lock_target:
                _face_lockon(delta)
        if dir.length() > 0.05:
                velocity.x = lerp(velocity.x, dir.x * target_speed, clamp(ACCEL * delta, 0, 1))
                velocity.z = lerp(velocity.z, dir.z * target_speed, clamp(ACCEL * delta, 0, 1))
                if not combat_mode:
                        _face_motion(dir, delta)
        else:
                velocity.x = lerp(velocity.x, 0.0, clamp(DECEL * delta, 0, 1))
                velocity.z = lerp(velocity.z, 0.0, clamp(DECEL * delta, 0, 1))
        var was_air := not is_on_floor()
        var prev_y := velocity.y
        move_and_slide()
        # fall damage (light)
        if was_air and is_on_floor() and prev_y < -12.0:
                take_damage((-prev_y - 12.0) * 4.0, "fall")
                _play("Jump_Land")
        # interact prompt
        _update_interact_prompt()
        # drive animation
        _drive_animation(delta)
        # police + missions + encounters track position
        PoliceSystem.set_player_position(global_position)
        MissionSystem.notify_at_position(global_position)
        StreetEncounters.set_player_position(global_position)
        # distance stats
        var planar := Vector2(velocity.x, velocity.z).length()
        if planar > 0.1:
                GameState.track_stat("distance_walked", planar * delta)
        # footstep SFX by gait (P2 movement-feel pass)
        _update_footsteps(delta, planar)
        # sprint FOV kick
        _update_fov(delta, planar)


## Footsteps: cadence scales with gait speed; pitch variance avoids
## machine-gun repetition. Only when grounded and moving.
func _update_footsteps(delta: float, planar: float) -> void:
        if planar < 0.5 or not is_on_floor():
                _step_t = 0.0
                return
        var cadence: float = clamp(planar * 0.55, 0.9, 3.4)      # steps per second
        _step_t += cadence * delta
        if _step_t >= 1.0:
                _step_t = 0.0
                EventBus.sfx_requested.emit("sfx_footstep", global_position)


## Sprint widens FOV slightly for speed feel; eases back on stop.
func _update_fov(delta: float, planar: float) -> void:
        var want := 0.0
        if speed_mode == "sprint" and planar > SPRINT_SPEED * 0.7:
                want = 6.0
        _fov_extra = lerpf(_fov_extra, want, clamp(5.0 * delta, 0.0, 1.0))
        var rig := camera_rig as CameraRig
        if rig != null and rig.world_cam() != null:
                # CameraRig owns fov (62 + own offsets); expose kick via rig
                rig.sprint_fov = _fov_extra


func camera_yaw() -> float:
        if camera_rig and is_instance_valid(camera_rig):
                return camera_rig.global_rotation.y
        return rotation.y


func _current_target_speed() -> float:
        if InputRouter.crouch_held or speed_mode == "crouch":
                return CROUCH_SPEED
        if speed_mode == "walk":
                return WALK_SPEED
        if speed_mode == "sprint":
                return SPRINT_SPEED
        return JOG_SPEED


func _update_stamina(delta: float) -> void:
        var sprinting: bool = InputRouter.is_sprinting() and speed_mode == "sprint"
        if sprinting and (velocity.length() > 0.5):
                GameState.stamina = max(0.0, GameState.stamina - SPRINT_STAMINA_DRAIN * delta)
                if GameState.stamina <= 0.0:
                        speed_mode = "jog"
        else:
                GameState.stamina = min(GameState.max_stamina, GameState.stamina + STAMINA_REGEN * delta)
        EventBus.player_stamina_changed.emit(GameState.stamina, GameState.max_stamina)


func _face_motion(dir: Vector3, delta: float) -> void:
        if _facing_locked:
                return
        var target_yaw := atan2(dir.x, dir.z)
        rotation.y = lerp_angle(rotation.y, target_yaw, clamp(10.0 * delta, 0, 1))


func _face_lockon(delta: float) -> void:
        if lock_target == null or not is_instance_valid(lock_target):
                return
        var to_t: Vector3 = lock_target.global_position - global_position
        var target_yaw := atan2(to_t.x, to_t.z)
        rotation.y = lerp_angle(rotation.y, target_yaw, clamp(12.0 * delta, 0, 1))


func _drive_animation(delta: float) -> void:
        if anim == null:
                return
        var planar := Vector2(velocity.x, velocity.z).length()
        if _combat and _combat.active:
                return  # combat component drives animations
        var next := "Idle"
        var rate := 1.0
        if not is_on_floor():
                next = "Jump"
        elif InputRouter.crouch_held:
                next = "Crouch_Idle" if planar < 0.4 else "Crouch_Fwd"
                rate = clamp(planar / CROUCH_SPEED, 0.6, 1.6)
        elif planar < 0.4:
                next = "Idle"
        elif planar < WALK_SPEED + 0.4:
                next = "Walk"
                rate = clamp(planar / WALK_SPEED, 0.7, 1.4)
        elif planar < SPRINT_SPEED - 0.5:
                next = "Jog_Fwd"
                rate = clamp(planar / JOG_SPEED, 0.7, 1.5)
        else:
                next = "Sprint"
                rate = clamp(planar / SPRINT_SPEED, 0.8, 1.6)
        if next != _anim_state:
                _play(next)
        anim.speed_scale = rate


func _play(anim_name: String) -> void:
        if anim == null:
                return
        if anim.has_animation(anim_name):
                anim.play(anim_name)
                _anim_state = anim_name
        else:
                push_warning("PlayerController: missing anim " + anim_name)


func _update_interact_prompt() -> void:
        var near := find_nearest_interactable()
        if near != _last_interactable:
                _last_interactable = near
                if near != null:
                        EventBus.subtitle_show.emit(_interact_text(near), "", 0.0)


signal interact_target_changed(target)


var _last_interactable: Node = null


func _interact_text(node: Node) -> String:
        if node.has_meta("interact_text"):
                return str(node.get_meta("interact_text"))
        return "Interact"


func find_nearest_interactable() -> Node:
        var best: Node = null
        var best_d := INTERACT_RANGE
        var space := get_world_3d().direct_space_state
        if space == null:
                return null
        for c in get_tree().get_nodes_in_group("interactable"):
                if not c is Node3D or not c.is_inside_tree():
                        continue
                var d: float = global_position.distance_to(c.global_position)
                if d < best_d:
                        best_d = d
                        best = c
        return best


## Called by InputRouter interact signal (via world wiring).
func try_interact() -> void:
        var node := find_nearest_interactable()
        if node == null:
                return
        if node.has_method("interact"):
                node.interact(self)
        elif node.has_meta("interact_text"):
                EventBus.sfx_requested.emit("sfx_ui_click", global_position)


## ---- damage / death ----
func take_damage(amount: float, kind := "hit") -> void:
        if _combat and _combat.invulnerable:
                return
        var armor_absorb: float = min(GameState.armor, amount * 0.6)
        GameState.armor = max(0.0, GameState.armor - armor_absorb)
        var hp_damage: float = amount - armor_absorb
        GameState.health = max(0.0, GameState.health - hp_damage)
        EventBus.player_health_changed.emit(GameState.health, GameState.max_health)
        EventBus.player_armor_changed.emit(GameState.armor, GameState.max_armor)
        if kind == "hit":
                _play("Hit_Chest")
        if GameState.health <= 0.0:
                die()


func heal(amount: float) -> void:
        GameState.health = min(GameState.max_health, GameState.health + amount)
        EventBus.player_health_changed.emit(GameState.health, GameState.max_health)


func die() -> void:
        _play("Death01")
        _frozen = true
        EventBus.player_died.emit()
        await get_tree().create_timer(2.6).timeout
        GameManager.respawn_player()


func dodge_impulse(dir: Vector3) -> void:
        velocity.x = dir.x * DODGE_IMPULSE
        velocity.z = dir.z * DODGE_IMPULSE


func freeze(on: bool) -> void:
        _frozen = on


func play_anim_forced(name: String) -> void:
        _play(name)
