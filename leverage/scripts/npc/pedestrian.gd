class_name PedestrianAgent
extends Node3D
## PedestrianAgent - ambient pedestrian visual + simple wander/flee logic.
## Population planned by NPCDirector; pooled by PedestrianPool in world.gd.

const WALK_SPEED := 1.5
const FLEE_SPEED := 4.2
const FLEE_TIME := 6.0

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


func _tick_walk(delta: float) -> void:
        var to_t := target - global_position
        to_t.y = 0
        if to_t.length() < 1.2:
                if randf() < 0.2:
                        _state = "idle"
                        _play("Idle")
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
        if _idle_t <= 0.0:
                _state = "walk"
                _play("Walk")
                target = NPCDirector.pedestrian_walk_target(global_position)
                _idle_t = randf_range(2.0, 6.0)
        if _close_to_danger() and _flee_t <= 0.0:
                _start_flee()


var _idle_t := 2.0


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


func _start_flee() -> void:
        _state = "flee"
        _flee_t = FLEE_TIME
        _play("Jog_Fwd")


func _close_to_danger() -> bool:
        var player := get_tree().get_first_node_in_group("player") as Node3D
        if player == null:
                return false
        if GameState.in_combat and global_position.distance_to(player.global_position) < 16.0:
                return true
        if GameState.wanted_level >= 2 and global_position.distance_to(player.global_position) < 20.0:
                return true
        return false
