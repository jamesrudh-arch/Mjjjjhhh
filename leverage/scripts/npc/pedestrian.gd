class_name PedestrianAgent
extends Node3D
## PedestrianAgent - ambient pedestrian visual + simple wander/flee logic.
## Population planned by NPCDirector; pooled by PedestrianPool in world.gd.

const WALK_SPEED := 1.5
const FLEE_SPEED := 4.2
const FLEE_TIME := 6.0
const COWER_CHANCE := 0.3        # some freeze in place instead of running

var actor: Node3D
var anim: AnimationPlayer
var target := Vector3.ZERO
var _state := "walk"
var _flee_t := 0.0
var _greet_cd := 0.0


func _ready() -> void:
        var rng := RandomNumberGenerator.new()
        rng.randomize()
        actor = CharacterFactory.make_random_ped(rng)
        add_child(actor)
        anim = _find_anim(actor)
        _play("Walk")
        add_to_group("pedestrian")
        target = NPCDirector.pedestrian_walk_target(global_position)


func _find_anim(node: Node) -> AnimationPlayer:
        if node is AnimationPlayer:
                return node
        for c in node.get_children():
                var r := _find_anim(c)
                if r:
                        return r
        return null


func _play(a: String) -> void:
        if anim and anim.has_animation(a):
                anim.play(a)


func _process(delta: float) -> void:
        _greet_cd = max(0.0, _greet_cd - delta)
        match _state:
                "walk":
                        _tick_walk(delta)
                "flee":
                        _tick_flee(delta)
                "idle":
                        _tick_idle(delta)
                "cower":
                        _tick_cower(delta)


func _tick_walk(delta: float) -> void:
        var to_t := target - global_position
        to_t.y = 0
        if to_t.length() < 1.2:
                if randf() < 0.25:
                        _enter_idle()
                else:
                        target = NPCDirector.pedestrian_walk_target(global_position)
                return
        var dir := to_t.normalized()
        global_position += dir * WALK_SPEED * delta
        rotation.y = atan2(dir.x, dir.z)
        if _close_to_danger() and _flee_t <= 0.0:
                _start_flee()


func _tick_idle(delta: float) -> void:
        _idle_t -= delta
        # face a nearby idle pedestrian: reads as a street conversation
        if _idle_t < 5.0:
                var buddy := _nearest_idle_ped()
                if buddy != null:
                        var to_b: Vector3 = buddy.global_position - global_position
                        to_b.y = 0.0
                        if to_b.length_squared() > 0.01:
                                rotation.y = atan2(to_b.x, to_b.z)
        if _idle_t <= 0.0:
                _state = "walk"
                _play("Walk")
                target = NPCDirector.pedestrian_walk_target(global_position)
                _idle_t = randf_range(2.0, 6.0)
        if _close_to_danger() and _flee_t <= 0.0:
                _start_flee()


var _idle_t := 2.0


## Idle variety: plain stop, chatting (face the nearest idler) or
## "on the phone" style pose (Idle_Torch reads as a raised device).
func _enter_idle() -> void:
        _state = "idle"
        _idle_t = randf_range(3.0, 8.0)
        var r := randf()
        if r < 0.55:
                _play("Idle_Talking")
        elif r < 0.75:
                _play("Idle_Torch")
        else:
                _play("Idle")


func _nearest_idle_ped() -> Node3D:
        var best: Node3D = null
        var best_d := 1.8
        for p in get_tree().get_nodes_in_group("pedestrian"):
                if p is PedestrianAgent and p != self and p._state == "idle":
                        var d: float = global_position.distance_to(p.global_position)
                        if d < best_d:
                                best_d = d
                                best = p
        return best


func _tick_flee(delta: float) -> void:
        _flee_t -= delta
        var player := get_tree().get_first_node_in_group("player") as Node3D
        if player == null:
                _state = "walk"
                return
        var away := (global_position - player.global_position)
        away.y = 0
        if away.length() < 0.01:
                away = Vector3(1, 0, 0)
        var dir := away.normalized()
        global_position += dir * FLEE_SPEED * delta
        rotation.y = atan2(dir.x, dir.z)
        if _flee_t <= 0.0:
                _state = "walk"
                _play("Walk")
                target = NPCDirector.pedestrian_walk_target(global_position)


func _start_flee(force_mode := "") -> void:
        # panic is loud: a scream sells the danger better than silent jogging
        EventBus.sfx_requested.emit("sfx_ped_scream", global_position)
        var mode := force_mode
        if mode == "":
                mode = "cower" if randf() < COWER_CHANCE else "flee"
        if mode == "cower":
                _state = "cower"
                _flee_t = FLEE_TIME * 1.5
                if anim:
                        _play("Crouch_Idle") if anim.has_animation("Crouch_Idle") else _play("Idle")
                return
        _state = "flee"
        _flee_t = FLEE_TIME
        _play("Jog_Fwd")


## Frozen-in-fear state: stays put, then recovers to walking.
func _tick_cower(delta: float) -> void:
        _flee_t -= delta
        # face away from the danger while crouched
        var player := get_tree().get_first_node_in_group("player") as Node3D
        if player != null:
                var away: Vector3 = global_position - player.global_position
                away.y = 0.0
                if away.length_squared() > 0.01:
                        rotation.y = atan2(away.x, away.z)
        if _flee_t <= 0.0:
                _state = "walk"
                _play("Walk")
                target = NPCDirector.pedestrian_walk_target(global_position)


func _close_to_danger() -> bool:
        var player := get_tree().get_first_node_in_group("player") as Node3D
        if player == null:
                return false
        if GameState.in_combat and global_position.distance_to(player.global_position) < 16.0:
                return true
        if GameState.wanted_level >= 2 and global_position.distance_to(player.global_position) < 20.0:
                return true
        return false
