class_name Combatant
extends CharacterBody3D
## Combatant - shared body for enemies and named NPCs that can fight.
## Simple approach-attack AI with discipline-flavored behaviors, hit reactions,
## crime reporting (witness system), death and despawn hooks.

const BASE_SPEED := 3.4
const AGGRO_RANGE := 14.0
const ATTACK_RANGE := 1.6
const ATTACK_COOLDOWN := 1.3

var npc_id := ""                     # named-cast id, "" for generics
var display_name := "Thug"
var faction := "vetch"               # family|kestrel|vetch|police|community
var health := 60.0
var max_health := 60.0
var damage := 8.0
var discipline_id := "brawler"
var aggro := false
var is_hostile_to_player := true
var target: Node3D = null

var actor: Node3D
var anim: AnimationPlayer
var _state := "idle"                 # idle|chase|attack|hit|dead
var _t := 0.0
var _attack_cd := 0.0
var _corpse_timer := 0.0
var _mission_wave := ""
var rng := RandomNumberGenerator.new()


func setup(p_npc_id: String, p_faction: String, p_display: String, p_health: float, p_damage: float, p_discipline := "brawler") -> void:
        npc_id = p_npc_id
        faction = p_faction
        display_name = p_display
        health = p_health
        max_health = p_health
        damage = p_damage
        discipline_id = p_discipline
        if npc_id != "":
                actor = CharacterFactory.make_named(npc_id)
        else:
                actor = CharacterFactory.make_random_ped(rng)
        add_child(actor)
        anim = _find_anim(actor)
        add_to_group("combatant")
        collision_layer = 8
        collision_mask = 1 | 2 | 8
        var shape := CollisionShape3D.new()
        var cap := CapsuleShape3D.new()
        cap.radius = 0.35
        cap.height = 1.8
        shape.shape = cap
        shape.position = Vector3(0, 0.9, 0)
        add_child(shape)


func _ready() -> void:
        _play("Idle")


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


func _physics_process(delta: float) -> void:
        if _state == "dead":
                _corpse_timer += delta
                if _corpse_timer > 12.0:
                        queue_free()
                return
        if not GameManager.is_playing():
                return
        _attack_cd = max(0.0, _attack_cd - delta)
        match _state:
                "idle":
                        _tick_idle(delta)
                "chase":
                        _tick_chase(delta)
                "attack":
                        _tick_attack(delta)
                "hit":
                        _t -= delta
                        if _t <= 0.0:
                                _state = "chase" if aggro else "idle"
                                _play("Idle")


func _tick_idle(delta: float) -> void:
        var player := get_tree().get_first_node_in_group("player") as Node3D
        if player == null:
                return
        if is_hostile_to_player and global_position.distance_to(player.global_position) < AGGRO_RANGE:
                aggro = true
                _state = "chase"
                EventBus.combat_started.emit()
                _notify_nearby_allies()
        velocity.x = 0
        velocity.z = 0
        if not is_on_floor():
                velocity.y -= 9.8 * delta
        move_and_slide()


func _notify_nearby_allies() -> void:
        for c in get_tree().get_nodes_in_group("combatant"):
                if c is Combatant and c != self and not c.aggro and c.faction == faction:
                        if global_position.distance_to(c.global_position) < 10.0:
                                c.aggro = true
                                c._state = "chase"


func _tick_chase(delta: float) -> void:
        var player := get_tree().get_first_node_in_group("player") as Node3D
        if player == null:
                return
        var to_p: Vector3 = player.global_position - global_position
        to_p.y = 0
        var dist := to_p.length()
        if dist < ATTACK_RANGE:
                _state = "attack"
                _t = 0.0
                _play_idle_anim()
                velocity.x = 0
                velocity.z = 0
        else:
                var dir := to_p.normalized()
                velocity.x = dir.x * BASE_SPEED
                velocity.z = dir.z * BASE_SPEED
                rotation.y = atan2(dir.x, dir.z)
        if not is_on_floor():
                velocity.y -= 9.8 * delta
        move_and_slide()
        if dist > AGGRO_RANGE * 2.5 and _mission_wave == "":
                aggro = false
                _state = "idle"
                EventBus.combat_ended.emit()
        # locomotion anim
        if anim:
                if _state != "attack":
                        var spd: float = Vector2(velocity.x, velocity.z).length()
                        if spd > 3.0:
                                _play("Jog_Fwd")
                        elif spd > 0.5:
                                _play("Walk")
                        else:
                                _play_idle_anim()
                anim.speed_scale = clamp(Vector2(velocity.x, velocity.z).length() / BASE_SPEED, 0.7, 1.5)


func _play_idle_anim() -> void:
        var d: Dictionary = Discipline.def(discipline_id)
        _play(String(d.get("idle", "Guard_Idle")))


func _tick_attack(delta: float) -> void:
        var player := get_tree().get_first_node_in_group("player") as Node3D
        if player == null:
                return
        _t += delta
        var player_combat: CombatPlayer = null
        if player.has_node("CombatPlayer"):
                player_combat = player.get_node("CombatPlayer") as CombatPlayer
        # face player
        var to_p: Vector3 = player.global_position - global_position
        rotation.y = atan2(to_p.x, to_p.z)
        # wind-up
        if _t > 0.4 and _t < 0.5:
                pass
        # strike moment
        if _t >= 0.5 and _attack_cd <= 0.0:
                var dist: float = global_position.distance_to(player.global_position)
                if dist <= ATTACK_RANGE + 0.4:
                        # counter check first
                        if player_combat != null and player_combat.try_counter(self):
                                take_hit(10.0, player, 3.0, 0.8, "counter")
                                return
                        if player_combat != null:
                                player_combat.try_receive_hit(damage, self)
                        else:
                                (player as PlayerController).take_damage(damage, "hit")
                        EventBus.sfx_requested.emit("sfx_punch_swing", global_position)
                _attack_cd = ATTACK_COOLDOWN
                _t = 0.0
                _state = "chase"
                _play("Jog_Fwd")
        velocity.x = 0
        velocity.z = 0
        if not is_on_floor():
                velocity.y -= 9.8 * delta
        move_and_slide()


## ---------------- Hit interface ----------------
func take_hit(damage: float, attacker: Node, knockback: float, stagger: float, kind := "melee") -> void:
        if _state == "dead":
                return
        health -= damage
        EventBus.hit_landed.emit(attacker, self, damage, kind)
        # witness + crime: assaulting someone in the open
        if attacker is PlayerController:
                var witnesses: Array = NPCDirector.witnesses_of(global_position)
                if witnesses.size() > 0 or CityDirector.on_road(Vector2(global_position.x, global_position.z), 30.0):
                        EventBus.crime_committed.emit("assault", global_position, PoliceSystem.crime_severity("assault"), witnesses)
                if npc_id != "":
                        GameState.change_relationship(npc_id, -2.0)
        if knockback > 0.0:
                var dir := (global_position - (attacker as Node3D).global_position).normalized()
                velocity.x = dir.x * knockback
                velocity.z = dir.z * knockback
        if health <= 0.0:
                die(attacker)
        else:
                _state = "hit"
                _t = stagger * 0.6
                _play("Hit_Chest" if randf() > 0.4 else "Hit_Head")


func die(attacker: Node) -> void:
        _state = "dead"
        aggro = false
        _play("Death01")
        EventBus.enemy_downed.emit(self)
        if attacker is PlayerController:
                GameState.track_stat("fights_won", 0)
                GameState.add_discipline_xp(GameState.current_discipline, 5)
                EventBus.crime_committed.emit("murder" if faction == "community" else "assault_downed", global_position,
                        PoliceSystem.crime_severity("murder") if faction == "community" else 10.0,
                        NPCDirector.witnesses_of(global_position))
        EventBus.sfx_requested.emit("sfx_bodyfall", global_position)


func set_wave_id(wave: String) -> void:
        _mission_wave = wave


func wave_id() -> String:
        return _mission_wave


func health_frac() -> float:
        return clamp(health / max_health, 0.0, 1.0)
