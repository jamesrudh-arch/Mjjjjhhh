class_name CombatPlayer
extends Node
## CombatPlayer - the player's combat brain. Child of PlayerController.
## Fixed mapping: X=punch, Y=heavy, A=kick, B=dodge. Code-driven state machine
## per TDL #4 (testable headless). Disciplines from Discipline tables.

enum State { IDLE, ATTACK, DODGE, HITSTUN, GRAPPLE, AIM, DEAD }

const COMBO_WINDOW := 0.55          # s after recover ends chain still alive
const COUNTER_WINDOW := 0.16        # s - dodge pressed right before enemy hit
const GRAB_THROW_WINDOW := 0.9

var state: int = State.IDLE
var active: bool = false            # combat context engaged
var invulnerable: bool = false
var discipline_id := "brawler"

var _attack_def := {}               # current attack dictionary
var _attack_t := 0.0                # time inside current attack
var _chain_step := 0
var _chain_t := 0.0                 # time since chain last advanced
var _hit_done := false
var player: PlayerController
var _grabbed_target: Node = null
var _grab_t := 0.0
var _aiming := false
var _auto_dodge_roll := 0.0


func _ready() -> void:
        player = get_parent() as PlayerController
        if player:
                player._combat = self
        EventBus.player_discipline_changed.connect(func(d): discipline_id = d)
        discipline_id = GameState.current_discipline
        EventBus.combat_started.connect(func(): active = true)
        EventBus.combat_ended.connect(func(): active = false)


func _process(delta: float) -> void:
        if player == null or not GameManager.is_playing():
                return
        match state:
                State.IDLE:
                        _process_idle(delta)
                State.ATTACK:
                        _process_attack(delta)
                State.DODGE:
                        _process_dodge(delta)
                State.HITSTUN:
                        _process_hitstun(delta)
                State.GRAPPLE:
                        _process_grapple(delta)
                State.AIM:
                        _process_aim(delta)
        # chain timeout
        if state == State.IDLE and _chain_step > 0:
                _chain_t += delta
                if _chain_t > COMBO_WINDOW:
                        _chain_step = 0


func _process_idle(delta: float) -> void:
        _auto_dodge_roll = randf()
        var d: Dictionary = Discipline.def(discipline_id)
        # idle anim per discipline
        if player.anim and not player.anim.is_playing():
                player.play_anim_forced(String(d["idle"]))
        # stamina gate
        if GameState.stamina < 8.0:
                return


func _process_attack(delta: float) -> void:
        if player.anim != null:
                _attack_t += delta * max(0.1, player.anim.speed_scale)
        else:
                _attack_t += delta
        var startup: float = float(_attack_def.get("startup", 0.2))
        var active_s: float = float(_attack_def.get("active", 0.1))
        var recover: float = float(_attack_def.get("recover", 0.2))
        if not _hit_done and _attack_t >= startup:
                _resolve_hits()
                _hit_done = true
        if _attack_t >= startup + active_s + recover:
                _end_attack()


func _process_dodge(delta: float) -> void:
        var dur := 0.5
        _attack_t += delta
        if _attack_t >= dur:
                invulnerable = false
                state = State.IDLE


func _process_hitstun(delta: float) -> void:
        _attack_t += delta
        if _attack_t >= 0.4:
                state = State.IDLE


func _process_grapple(delta: float) -> void:
        _grab_t += delta
        if _grabbed_target == null or not is_instance_valid(_grabbed_target):
                state = State.IDLE
                return
        # Follow: second heavy press within window throws.
        if InputRouter and Input.is_action_just_pressed("action_y") and _grab_t <= GRAB_THROW_WINDOW:
                _do_throw()
        if _grab_t > GRAB_THROW_WINDOW and _grabbed_target != null:
                _release_grab()


func _process_aim(delta: float) -> void:
        pass  # weapon system drives aim state


## ---------------- Actions (called by world wiring from InputRouter) ------
func on_punch() -> void:
        if state == State.IDLE or (state == State.ATTACK and _chain_t < COMBO_WINDOW and _attack_t > float(_attack_def.get("recover", 0.2))):
                _start_attack(Discipline.punch_stats(_chain_step, discipline_id))
        elif state == State.IDLE and _aiming:
                _start_attack(Discipline.punch_stats(_chain_step, discipline_id))


func on_kick() -> void:
        if state == State.IDLE:
                _start_attack(Discipline.kick_stats(_chain_step, discipline_id))


func on_heavy() -> void:
        if state == State.GRAPPLE:
                return  # handled in _process_grapple
        if state != State.IDLE:
                return
        if discipline_id == "grappling":
                _start_grab()
                return
        _start_attack(Discipline.def(discipline_id)["heavy"].duplicate())


func on_dodge() -> void:
        if state == State.IDLE or state == State.ATTACK:
                var d: Dictionary = Discipline.def(discipline_id)
                var anim: String = String(d["dodge"])
                if GameState.stamina >= 14.0:
                        GameState.stamina -= 14.0
                        EventBus.player_stamina_changed.emit(GameState.stamina, GameState.max_stamina)
                        state = State.DODGE
                        invulnerable = true
                        _attack_t = 0.0
                        player.play_anim_forced(anim)
                        # dodge toward input direction
                        var dir := Vector3(-InputRouter.move_vector.y, 0, InputRouter.move_vector.x)
                        if dir.length() < 0.1:
                                dir = -player.transform.basis.z
                        player.dodge_impulse(dir.rotated(Vector3.UP, player.camera_yaw()))
                        EventBus.dodge_performed.emit(player)


## ---------------- Internals ----------------
func _start_attack(attack: Dictionary) -> void:
        if GameState.stamina < float(attack.get("stamina", 6.0)):
                return
        GameState.stamina -= float(attack.get("stamina", 6.0))
        EventBus.player_stamina_changed.emit(GameState.stamina, GameState.max_stamina)
        _attack_def = attack
        _attack_t = 0.0
        _hit_done = false
        state = State.ATTACK
        player.play_anim_forced(String(attack.get("anim", "Punch_Jab")))
        _chain_t = 0.0
        # attack magnetism: snap toward the nearest target in range so the
        # strike connects (third-person brawler standard)
        var magnet: Node3D = _nearest_combatant(float(attack.get("reach", 1.4)) + 1.3)
        if magnet != null:
                var to_m: Vector3 = magnet.global_position - player.global_position
                to_m.y = 0.0
                if to_m.length() > 0.05:
                        player.rotation.y = atan2(-to_m.x, -to_m.z)
        # drunken damage variance
        if discipline_id == "drunken":
                var v: float = float(Discipline.def("drunken")["passive"].get("wild_damage_variance", 0.3))
                _attack_def["damage"] = float(attack["damage"]) * (1.0 + randf_range(-v, v))


func _end_attack() -> void:
        state = State.IDLE
        _chain_step += 1
        if _chain_step >= Discipline.chain_length(discipline_id, "punch") and _attack_def != null and String(_attack_def.get("anim", "")).begins_with("Punch"):
                _chain_step = 0
        _chain_t = 0.0
        EventBus.combo_progressed.emit(_chain_step, discipline_id)


func _resolve_hits() -> void:
        var reach: float = float(_attack_def.get("reach", 1.4))
        var damage: float = float(_attack_def.get("damage", 10.0))
        var knockback: float = float(_attack_def.get("knockback", 2.0))
        var stagger: float = float(_attack_def.get("stagger", 0.5))
        var hit_any := false
        for node in get_tree().get_nodes_in_group("combatant"):
                if not node is Node3D or not node.is_inside_tree():
                        continue
                if node == player:
                        continue
                var forward := -player.transform.basis.z
                var origin: Vector3 = player.global_position + Vector3(0, 1.1, 0) + forward * 0.4
                if origin.distance_to(node.global_position + Vector3(0, 1.0, 0)) > reach + 0.8:
                        continue
                # forward cone check
                var to_t: Vector3 = (node.global_position - player.global_position)
                to_t.y = 0
                if to_t.length() < 0.01 or forward.dot(to_t.normalized()) < 0.35:
                        continue
                if node.has_method("take_hit"):
                        node.take_hit(damage, player, knockback, stagger, String(_attack_def.get("anim", "")))
                        hit_any = true
        if hit_any:
                GameState.track_stat("hits_landed", 1)
                GameState.add_discipline_xp(discipline_id, 2)
                EventBus.hit_landed.emit(player, null, damage, "melee")
                EventBus.sfx_requested.emit("sfx_punch_hit", player.global_position)


func _start_grab() -> void:
        var target := _nearest_grabbable()
        if target == null:
                # whiff as light grab anim
                _start_attack(Discipline.def("grappling")["heavy"].duplicate())
                return
        state = State.GRAPPLE
        _grabbed_target = target
        _grab_t = 0.0
        player.play_anim_forced("Grapple_Grab")
        if target.has_method("take_hit"):
                target.take_hit(float(Discipline.def("grappling")["heavy"]["damage"]), player, 0.0, 0.4, "Grapple_Grab")


func _nearest_grabbable() -> Node:
        return _nearest_combatant(1.6)


func _nearest_combatant(radius: float) -> Node:
        var best: Node = null
        var best_d: float = radius
        for node in get_tree().get_nodes_in_group("combatant"):
                if not node is Node3D or node == player:
                        continue
                if not node.is_inside_tree():
                        continue
                var d: float = player.global_position.distance_to(node.global_position)
                if d < best_d:
                        best_d = d
                        best = node
        return best


func _do_throw() -> void:
        var dmg: float = float(Discipline.def("grappling")["passive"].get("throw_damage", 40.0))
        player.play_anim_forced("Grapple_Throw")
        if _grabbed_target and is_instance_valid(_grabbed_target) and _grabbed_target.has_method("take_hit"):
                _grabbed_target.take_hit(dmg, player, 9.0, 1.6, "Grapple_Throw")
        _grabbed_target = null
        state = State.IDLE
        GameState.add_discipline_xp("grappling", 6)
        EventBus.sfx_requested.emit("sfx_bodyfall", player.global_position)


func _release_grab() -> void:
        _grabbed_target = null
        state = State.IDLE


## Called by enemy attacks resolving against the player.
func try_receive_hit(damage: float, attacker: Node, kind := "melee") -> void:
        if invulnerable:
                return
        # drunken passive auto-dodge
        if discipline_id == "drunken" and state == State.IDLE:
                var chance: float = float(Discipline.def("drunken")["passive"].get("auto_dodge_chance", 0.2))
                if _auto_dodge_roll < chance:
                        player.dodge_impulse(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 0.8)
                        EventBus.dodge_performed.emit(player)
                        return
        player.take_damage(damage, "hit")
        state = State.HITSTUN
        _attack_t = 0.0


## Counter check: enemies call this BEFORE applying damage; returns true if
## the player's late dodge counters the attack.
func try_counter(attacker: Node3D) -> bool:
        if state != State.DODGE or _attack_t > COUNTER_WINDOW:
                return false
        # counter!
        var d: Dictionary = Discipline.def(discipline_id)
        var mult: float = float(d.get("counter_damage_mult", 1.6))
        player.play_anim_forced(String(d["counter"]))
        state = State.ATTACK
        _attack_def = {"anim": String(d["counter"]), "damage": 18.0 * mult, "startup": 0.1,
                "active": 0.1, "recover": 0.4, "stamina": 0.0, "reach": 1.8,
                "knockback": 6.0, "stagger": 1.2}
        _attack_t = 0.0
        _hit_done = false
        _counter_target = attacker
        EventBus.counter_performed.emit(player, attacker)
        GameState.add_discipline_xp(discipline_id, 8)
        return true


var _counter_target: Node3D = null


func set_aiming(on: bool) -> void:
        _aiming = on
        if on and discipline_id == "weapon":
                state = State.AIM
                player.play_anim_forced("Pistol_Aim_Neutral")
        else:
                if state == State.AIM:
                        state = State.IDLE


func is_attacking() -> bool:
        return state == State.ATTACK or state == State.GRAPPLE
