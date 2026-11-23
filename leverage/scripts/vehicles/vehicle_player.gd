class_name VehiclePlayer
extends VehicleBody3D
## VehiclePlayer - a drivable car built from a GLB visual on a tuned
## VehicleBody3D. Player enters via B; vehicle controls: joystick steer +
## pedals (touch), X = handbrake, B = exit. Engine audio loop via AudioSystem.

const ENGINE_FORCE := 90.0
const BRAKE_FORCE := 60.0
const MAX_STEER := 0.55
const STEER_SPEED := 3.2
const ENTER_RANGE := 3.2

var visual: Node3D
var vehicle_kind := "sedan"
var occupied := false
var driver: Node3D = null
var rider: Node3D = null                  # seated rider stand-in (D5)
var rider_anim: AnimationPlayer = null
var _steer := 0.0
var _engine_loop: AudioStreamPlayer3D
var _fuel_burn_t := 0.0


static func create(kind: String, glb: String, position: Vector3) -> VehiclePlayer:
        var v := VehiclePlayer.new()
        v.vehicle_kind = kind
        if ResourceLoader.exists(glb):
                var packed: PackedScene = load(glb)
                v.visual = packed.instantiate()
        v.position = position
        return v


static func create_from_agent(agent: TrafficAgent, kind: String) -> VehiclePlayer:
        # Bikes convert to a real Motorcycle body (D6); cars to VehiclePlayer.
        if kind == "motorcycle":
                var m := Motorcycle.new()
                m.vehicle_kind = "motorcycle"
                m.position = agent.global_position
                m.rotation = agent.global_rotation
                if agent.visual != null:
                        agent.remove_child(agent.visual)
                        var rider: Node = agent.visual.get_node_or_null("AgentRider")
                        if rider != null:
                                rider.queue_free()      # the jack pulls the NPC off
                        m.visual = agent.visual
                agent.queue_free()
                return m
        var v := VehiclePlayer.new()
        v.vehicle_kind = kind
        v.position = agent.global_position
        v.rotation = agent.global_rotation
        if agent.visual != null:
                # detach (not reparent): agent is freed and _ready re-attaches
                agent.remove_child(agent.visual)
                v.visual = agent.visual
        agent.queue_free()
        return v


func _ready() -> void:
        mass = 180.0
        # center of mass low for stability
        var com := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = Vector3(1.9, 1.0, 4.2)
        com.shape = box
        com.position = Vector3(0, 0.35, 0)
        com.name = "BodyShape"
        add_child(com)
        # wheels: front/back axle
        _add_wheel("FL", Vector3(-0.85, 0.25, -1.4), true)
        _add_wheel("FR", Vector3(0.85, 0.25, -1.4), true)
        _add_wheel("RL", Vector3(-0.85, 0.25, 1.5), false)
        _add_wheel("RR", Vector3(0.85, 0.25, 1.5), false)
        if visual and visual.get_parent() == null:
                add_child(visual)
        add_to_group("vehicle")
        add_to_group("interactable")
        set_meta("interact_text", "Drive")
        set_meta("vehicle_kind", vehicle_kind)
        _engine_loop = AudioSystem.make_engine_loop()
        add_child(_engine_loop)
        _engine_loop.unit_size = 14.0


func _add_wheel(nm: String, offset: Vector3, front: bool) -> void:
        var w := VehicleWheel3D.new()
        w.name = nm
        w.position = offset
        w.use_as_traction = not front
        w.use_as_steering = front
        w.wheel_radius = 0.33
        w.suspension_travel = 0.2
        w.wheel_roll_influence = 0.6
        w.damping_compression = 4.0
        w.damping_relaxation = 5.0
        add_child(w)


func _physics_process(delta: float) -> void:
        if not occupied:
                engine_force = 0.0
                brake = 12.0
                return
        # steering toward input
        var steer_input := InputRouter.move_vector.x
        _steer = lerp(_steer, -steer_input * MAX_STEER, clamp(STEER_SPEED * delta, 0, 1))
        steering = _steer
        # throttle from touch pedals or joystick up/down
        var throttle := -InputRouter.move_vector.y
        engine_force = throttle * ENGINE_FORCE
        # handbrake (X in vehicle)
        if InputRouter and Input.is_action_just_pressed("action_x"):
                brake = BRAKE_FORCE * 2.0
        else:
                brake = 4.0 if throttle == 0.0 else 0.0
        # engine sound pitch by speed
        if _engine_loop:
                _engine_loop.pitch_scale = clamp(0.8 + (linear_velocity.length() / 40.0), 0.8, 2.2)
                if not _engine_loop.playing:
                        _engine_loop.play()
        # stats + police speeding
        if linear_velocity.length() > 1.0:
                GameState.track_stat("distance_driven", linear_velocity.length() * delta)


func enter(player: PlayerController) -> void:
        occupied = true
        driver = player
        player.freeze(true)
        player.visible = false
        GameState.in_vehicle = true
        InputRouter.set_context(InputRouter.Context.VEHICLE)
        _spawn_rider()
        EventBus.player_entered_vehicle.emit(self)
        EventBus.sfx_requested.emit("sfx_car_door", global_position)
        if _engine_loop:
                _engine_loop.play()


func exit_vehicle() -> void:
        occupied = false
        _clear_rider()
        var player := driver
        driver = null
        GameState.in_vehicle = false
        InputRouter.set_context(InputRouter.Context.EXPLORE)
        if player and is_instance_valid(player):
                player.global_position = global_position + Vector3(2.2, 0.4, 0)
                player.visible = true
                player.freeze(false)
        EventBus.player_exited_vehicle.emit()
        EventBus.sfx_requested.emit("sfx_car_door", global_position)
        if _engine_loop:
                _engine_loop.stop()


## ---------------- Seated rider (D5) ----------------
## The player body is hidden on enter (physics stays on the vehicle); a rider
## stand-in built from the SAME character body is seated in the vehicle so
## the driver is visible in third person. Freed on exit; the real player
## controller is untouched (no per-seat mount animation needed on it).
func seat_offset() -> Vector3:
        return Vector3(-0.42, 0.20, -0.12)        # car: LHD driver seat (tuned via VLM A/B)


func seat_rotation() -> float:
        return PI        # mannequin faces +Z; vehicle forward is -Z


func _spawn_rider() -> void:
        if rider != null:
                return
        rider = CharacterFactory.make_player()
        add_child(rider)
        rider.position = seat_offset()
        rider.rotation.y = seat_rotation()
        rider_anim = _find_first_anim(rider)
        if rider_anim != null and rider_anim.has_animation("Sitting_Idle"):
                rider_anim.play("Sitting_Idle")


func _clear_rider() -> void:
        if rider != null:
                rider.queue_free()
        rider = null
        rider_anim = null


static func _find_first_anim(node: Node) -> AnimationPlayer:
        if node is AnimationPlayer:
                return node
        for c in node.get_children():
                var r := _find_first_anim(c)
                if r != null:
                        return r
        return null


## Body impacts reported by physics contacts (connected by world.gd).
func on_body_contact(body: Node, impulse: float) -> void:
        if body is PlayerController and not occupied:
                return  # handled via interact
        if body is Combatant:
                var dmg: float = clampf(impulse * 0.4, 5.0, 45.0)
                (body as Combatant).take_hit(dmg, driver if driver else self, 6.0, 1.0, "vehicle")
                EventBus.crime_committed.emit("hit_pedestrian", global_position,
                        PoliceSystem.crime_severity("hit_pedestrian"), NPCDirector.witnesses_of(global_position))
        elif body is VehicleBody3D:
                EventBus.crime_committed.emit("hit_vehicle", global_position,
                        PoliceSystem.crime_severity("hit_vehicle"), [])
        EventBus.sfx_requested.emit("sfx_car_crash", global_position)
