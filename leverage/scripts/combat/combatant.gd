class_name Combatant
extends CharacterBody3D
## Combatant - shared body for enemies and named NPCs that can fight.
## Session 5 "combat brain" upgrade: enemies fight like a GROUP, not a queue.
## - Attack tokens: max 2 strike at once, the rest circle and flank.
## - Telegraphed strikes (slow wind-up anim + swing SFX) so counters are
##   readable (Sifu/Sleeping Dogs reference).
## - Knockdown / get-up states, wounded retreat + shouting for help.
## - Discipline flavored range, strikes and behavior. Nobody stands still
##   eating hits (directive).
## Preserved public API: setup/take_hit/die/set_wave_id/wave_id/health_frac.

const BASE_SPEED := 3.4
const AGGRO_RANGE := 14.0
const ATTACK_RANGE := 1.6
const ATTACK_COOLDOWN := 1.3
const MAX_SIMULTANEOUS_ATTACKS := 2
const CIRCLE_RADIUS := 2.8           # preferred surround distance
const KNOCKDOWN_STAGGER := 1.15      # stagger above this can floor an enemy

## Wind-up telegraph: strike lands at TELEGRAPH_TIME into the attack state.
const TELEGRAPH_TIME := 0.5

## Discipline flavor: strike animation, reach and closing speed.
const DISCIPLINE_FLAVOR := {
        "brawler": {"anim": "Punch_Cross", "reach": 1.7, "speed": 1.0},
        "kickboxing": {"anim": "Kick_Round", "reach": 2.1, "speed": 1.05},
        "drunken": {"anim": "Drunken_Swing", "reach": 1.8, "speed": 0.9},
        "grappling": {"anim": "Punch_Jab", "reach": 1.6, "speed": 1.0},
        "weapon": {"anim": "Sword_Attack", "reach": 2.2, "speed": 1.0},
}

## Attack token registry - shared across all combatants (group discipline).
static var _attack_tokens := {}


static func take_attack_token(c) -> bool:
        if _attack_tokens.has(c):
                return true
        if _attack_tokens.size() >= MAX_SIMULTANEOUS_ATTACKS:
                return false
        _attack_tokens[c] = true
        return true


static func release_attack_token(c) -> void:
        _attack_tokens.erase(c)


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
var _state := "idle"                 # idle|chase|circle|attack|hit|knockdown|getup|retreat|dead
var _t := 0.0
var _attack_cd := 0.0
var _corpse_timer := 0.0
var _mission_wave := ""
var _circle_dir := 1.0               # individual flank direction (+1/-1)
var _strikes_since_pause := 0        # weapon users "reload" every 3rd strike
var _knockdowns_taken := 0
var rng := RandomNumberGenerator.new()


func setup(p_npc_id: String, p_faction: String, p_display: String, p_health: float, p_damage: float, p_discipline := "brawler") -> void:
        npc_id = p_npc_id
        faction = p_faction
        display_name = p_display
        health = p_health
        max_health = p_health
        damage = p_damage
        discipline_id = p_discipline
        _circle_dir = 1.0 if randf() > 0.5 else -1.0
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


func _exit_tree() -> void:
        release_attack_token(self)


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
                "circle":
                        _tick_circle(delta)
                "attack":
                        _tick_attack(delta)
                "hit":
                        _t -= delta
                        if _t <= 0.0:
                                _state = "chase" if aggro else "idle"
                                _play("Idle")
                "knockdown":
                        _tick_knockdown(delta)
                "getup":
                        _t -= delta
                        if _t <= 0.0:
                                _state = "chase" if aggro else "idle"
                                _play("Idle")
                "retreat":
                        _tick_retreat(delta)


func _player() -> Node3D:
        return get_tree().get_first_node_in_group("player") as Node3D


func _tick_idle(delta: float) -> void:
        var player := _player()
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


func _locomote_towards(point: Vector3, speed_mult: float, delta: float, face := true) -> void:
        var dir := (point - global_position)
        dir.y = 0.0
        dir = dir.normalized()
        velocity.x = dir.x * BASE_SPEED * speed_mult
        velocity.z = dir.z * BASE_SPEED * speed_mult
        if face and dir.length_squared() > 0.01:
                rotation.y = atan2(dir.x, dir.z)
        if not is_on_floor():
                velocity.y -= 9.8 * delta
        move_and_slide()
        # locomotion anim
        if anim:
                var spd: float = Vector2(velocity.x, velocity.z).length()
                if spd > 3.0:
                        _play("Jog_Fwd")
                elif spd > 0.5:
                        _play("Walk")
                else:
                        _play_idle_anim()
                anim.speed_scale = clamp(spd / BASE_SPEED, 0.7, 1.5)


func _tick_chase(delta: float) -> void:
        var player := _player()
        if player == null:
                return
        var flavor: Dictionary = DISCIPLINE_FLAVOR.get(discipline_id, DISCIPLINE_FLAVOR["brawler"])
        var reach: float = float(flavor["reach"])
        var dist: float = global_position.distance_to(player.global_position)
        # wounded fighters may back off and shout (negative reaction per directive)
        if health_frac() < 0.3 and rng.randf() < 0.35 and _state != "retreat":
                _state = "retreat"
                _t = 1.6
                _notify_nearby_allies()
                EventBus.sfx_requested.emit("sfx_radio_click", global_position)
                return
        if dist < reach + 0.2:
                if take_attack_token(self):
                        _state = "attack"
                        _t = 0.0
                        _play(String(flavor["anim"]))
                        if anim:
                                anim.speed_scale = 0.62      # slow wind-up = telegraph
                        velocity.x = 0
                        velocity.z = 0
                else:
                        _state = "circle"                    # wait your turn, flank
                        _t = 0.0
        else:
                _locomote_towards(player.global_position, float(flavor["speed"]), delta)
        if dist > AGGRO_RANGE * 2.5 and _mission_wave == "":
                aggro = false
                _state = "idle"
                EventBus.combat_ended.emit()


## Surround behavior: strafe a ring around the player, press in when a
## token frees up. Distinct per-enemy direction so a pack surrounds (包抄).
func _tick_circle(delta: float) -> void:
        var player := _player()
        if player == null:
                return
        release_attack_token(self)
        var flavor: Dictionary = DISCIPLINE_FLAVOR.get(discipline_id, DISCIPLINE_FLAVOR["brawler"])
        var to_p: Vector3 = player.global_position - global_position
        to_p.y = 0.0
        var dist := to_p.length()
        if dist > AGGRO_RANGE * 2.5 and _mission_wave == "":
                aggro = false
                _state = "idle"
                EventBus.combat_ended.emit()
                return
        if dist < float(flavor["reach"]) + 0.2 and take_attack_token(self):
                _state = "attack"
                _t = 0.0
                _play(String(flavor["anim"]))
                if anim:
                        anim.speed_scale = 0.62
                return
        # desired ring position: CIRCLE_RADIUS out, offset along the ring
        var radial := to_p.normalized()
        var tangent := Vector3(-radial.z, 0.0, radial.x) * _circle_dir
        var want: Vector3 = player.global_position + radial * CIRCLE_RADIUS + tangent * 0.8
        if dist < CIRCLE_RADIUS * 0.75:
                want = global_position - radial * 1.5 + tangent     # too close: back out
        _locomote_towards(want, 0.55, delta, false)
        # always face the player while circling
        rotation.y = atan2(to_p.x, to_p.z)
        _t += delta
        if _t > 4.0:
                _circle_dir = -_circle_dir      # switch flank side
                _t = 0.0


func _play_idle_anim() -> void:
        var d: Dictionary = Discipline.def(discipline_id)
        _play(String(d.get("idle", "Guard_Idle")))


func _tick_attack(delta: float) -> void:
        var player := _player()
        if player == null:
                release_attack_token(self)
                return
        _t += delta
        var player_combat: CombatPlayer = null
        if player.has_node("CombatPlayer"):
                player_combat = player.get_node("CombatPlayer") as CombatPlayer
        # face player
        var to_p: Vector3 = player.global_position - global_position
        rotation.y = atan2(to_p.x, to_p.z)
        var flavor: Dictionary = DISCIPLINE_FLAVOR.get(discipline_id, DISCIPLINE_FLAVOR["brawler"])
        var reach: float = float(flavor["reach"])
        # audible telegraph at wind-up start (counters become readable)
        if _t > 0.12 and _t < 0.13:
                EventBus.sfx_requested.emit("sfx_punch_swing", global_position)
        # strike moment
        if _t >= TELEGRAPH_TIME and _attack_cd <= 0.0:
                var dist: float = global_position.distance_to(player.global_position)
                if dist <= reach + 0.4:
                        # counter check first
                        if player_combat != null and player_combat.try_counter(self):
                                take_hit(10.0, player, 3.0, 0.8, "counter")
                                return
                        if player_combat != null:
                                player_combat.try_receive_hit(damage, self)
                        else:
                                (player as PlayerController).take_damage(damage, "hit")
                        if anim:
                                anim.speed_scale = 1.5          # snap the strike
                _attack_cd = ATTACK_COOLDOWN
                _strikes_since_pause += 1
                release_attack_token(self)
                # weapon users periodically pause to reload (装填)
                if discipline_id == "weapon" and _strikes_since_pause >= 3:
                        _strikes_since_pause = 0
                        _attack_cd = 2.4
                        _play("Pistol_Reload")
                else:
                        _state = "circle" if _still_surrounded(player) else "chase"
                        _t = 0.0
                        _play("Jog_Fwd")
        velocity.x = 0
        velocity.z = 0
        if not is_on_floor():
                velocity.y -= 9.8 * delta
        move_and_slide()


func _still_surrounded(player: Node3D) -> bool:
        for c in get_tree().get_nodes_in_group("combatant"):
                if c is Combatant and c != self and c.aggro:
                        if c.global_position.distance_to(player.global_position) < 8.0:
                                return true
        return false


## Wounded retreat: back away, then re-engage.
func _tick_retreat(delta: float) -> void:
        var player := _player()
        if player == null:
                _state = "chase"
                return
        _t -= delta
        var away: Vector3 = (global_position - player.global_position)
        away.y = 0.0
        _locomote_towards(global_position + away.normalized() * 2.5, 0.8, delta)
        if _t <= 0.0:
                _state = "chase"


## Knocked down: fall (Death01 clip), lie stunned, then roll back up.
func _tick_knockdown(delta: float) -> void:
        _t += delta
        if _t > 1.0 and anim and anim.is_playing():
                anim.pause()                       # hold the lying pose
        if _t > 1.9:
                _state = "getup"
                _t = 0.7
                _play("Roll")
                if anim:
                        anim.speed_scale = 1.25
        velocity.x = lerp(velocity.x, 0.0, 8.0 * delta)
        velocity.z = lerp(velocity.z, 0.0, 8.0 * delta)
        if not is_on_floor():
                velocity.y -= 9.8 * delta
        move_and_slide()


## ---------------- Hit interface ----------------
func take_hit(damage: float, attacker: Node, knockback: float, stagger: float, kind := "melee") -> void:
        if _state == "dead":
                return
        # downed/getting-up fighters take double damage (combo punish window)
        var vulnerable := _state == "knockdown" or _state == "getup"
        if vulnerable:
                damage *= 2.0
        health -= damage
        EventBus.hit_landed.emit(attacker, self, damage, kind)
        CombatFeel.spawn_impact(global_position + Vector3(0, 1.25, 0), clamp(damage / 20.0, 0.5, 1.8))
        # witness + crime: assaulting someone in the open
        if attacker is PlayerController:
                var witnesses: Array = NPCDirector.witnesses_of(global_position)
                if witnesses.size() > 0 or CityDirector.on_road(Vector2(global_position.x, global_position.z), 30.0):
                        EventBus.crime_committed.emit("assault", global_position, PoliceSystem.crime_severity("assault"), witnesses)
                if npc_id != "":
                        GameState.change_relationship(npc_id, -2.0)
        release_attack_token(self)
        if health <= 0.0:
                die(attacker)
                return
        # knockdown: heavy staggers floor lighter enemies
        if stagger >= KNOCKDOWN_STAGGER and _knockdowns_taken < 2 and rng.randf() < 0.65:
                _knockdowns_taken += 1
                _state = "knockdown"
                _t = 0.0
                _play("Death01")
                if anim:
                        anim.speed_scale = 1.3
                EventBus.sfx_requested.emit("sfx_bodyfall", global_position)
                CombatFeel.hit_stop(0.1, 0.14)
                return
        if knockback > 0.0:
                var dir := (global_position - (attacker as Node3D).global_position).normalized()
                velocity.x = dir.x * knockback
                velocity.z = dir.z * knockback
        _state = "hit"
        _t = stagger * 0.6
        _play("Hit_Chest" if randf() > 0.4 else "Hit_Head")


func die(attacker: Node) -> void:
        _state = "dead"
        aggro = false
        release_attack_token(self)
        _play("Death01")
        EventBus.enemy_downed.emit(self)
        CombatFeel.hit_stop(0.12, 0.2)
        CombatFeel.spawn_impact(global_position + Vector3(0, 0.6, 0), 1.6)
        # cinematic finish: last hostile standing in the brawl goes down slow
        if _was_last_hostile():
                CombatFeel.slow_mo(0.3, 0.7)
                var pc := _player() as PlayerController
                if pc != null and pc.camera_rig != null and is_instance_valid(pc.camera_rig):
                        var rig := pc.camera_rig as CameraRig
                        if rig != null:
                                rig.zoom_fov(-6.0, 0.6)
                                rig.shake(0.2, 0.4)
        if attacker is PlayerController:
                GameState.track_stat("fights_won", 0)
                GameState.add_discipline_xp(GameState.current_discipline, 5)
                EventBus.crime_committed.emit("murder" if faction == "community" else "assault_downed", global_position,
                        PoliceSystem.crime_severity("murder") if faction == "community" else 10.0,
                        NPCDirector.witnesses_of(global_position))
        EventBus.sfx_requested.emit("sfx_bodyfall", global_position)


func _was_last_hostile() -> bool:
        for c in get_tree().get_nodes_in_group("combatant"):
                if c is Combatant and c != self and c.is_hostile_to_player and c._state != "dead":
                        if c.aggro or c.global_position.distance_to(global_position) < 12.0:
                                return false
        return true


func set_wave_id(wave: String) -> void:
        _mission_wave = wave


func wave_id() -> String:
        return _mission_wave


func health_frac() -> float:
        return clamp(health / max_health, 0.0, 1.0)
