class_name Motorcycle
extends VehiclePlayer
## Motorcycle - the two-wheel member of the vehicle system (R13: cars AND
## motorcycles). Same B-enter/B-exit contract as cars; distinct handling:
## lighter, quicker, rolls into corners. Roll is locked on the physics body
## (arcade upright stability) and expressed visually as a lean of the mesh.
## Parked bikes are placed by World; traffic stays on four wheels by design
## (traffic AI is optimised around car corridors - see TDL #14).

const BIKE_ENGINE_FORCE := 135.0      # cars: 90
const BIKE_STEER_RATIO := 1.18         # tighter than the car ratio
const BIKE_MAX_LEAN := 0.55           # radians of visible lean at full commit

var _lean := 0.0


static func create_at(position: Vector3) -> Motorcycle:
        var m := Motorcycle.new()
        m.vehicle_kind = "motorcycle"
        if ResourceLoader.exists("res://assets/vehicles/motorcycle.glb"):
                m.visual = (load("res://assets/vehicles/motorcycle.glb") as PackedScene).instantiate()
        m.position = position
        return m


func _ready() -> void:
        mass = 95.0
        # narrow chassis, centre of mass low
        var com := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = Vector3(0.6, 1.0, 1.95)
        com.shape = box
        com.position = Vector3(0, 0.5, 0)
        com.name = "BodyShape"
        add_child(com)
        # arcade stability: physics roll locked, lean is cosmetic (TDL #14)
        axis_lock_angular_x = true
        # two wheels: front steers, rear drives
        _add_wheel("FT", Vector3(0, 0.34, -0.78), true)
        _add_wheel("RR", Vector3(0, 0.34, 0.78), false)
        if visual:
                add_child(visual)
        add_to_group("vehicle")
        add_to_group("interactable")
        set_meta("interact_text", "Ride")
        set_meta("vehicle_kind", "motorcycle")
        _engine_loop = AudioSystem.make_engine_loop()
        add_child(_engine_loop)
        _engine_loop.unit_size = 10.0


func _physics_process(delta: float) -> void:
        super._physics_process(delta)     # shared: steering lerp, pedals, audio, stats
        if not occupied:
                visual_roll_to(0.0, delta)
                return
        # bike power curve over the car force the parent applied
        var throttle := -InputRouter.move_vector.y
        engine_force = throttle * BIKE_ENGINE_FORCE
        # steering: parent lerps _steer toward the car limit; scale to bike ratio
        steering = clampf(_steer * BIKE_STEER_RATIO, -0.7, 0.7)
        # visible lean: into the steer, scaled by commit (speed)
        var speed_commit := clampf(linear_velocity.length() / 14.0, 0.0, 1.0)
        var target := clampf(-InputRouter.move_vector.x * speed_commit,
                        -BIKE_MAX_LEAN, BIKE_MAX_LEAN)
        visual_roll_to(target, delta)


func visual_roll_to(target: float, delta: float) -> void:
        _lean = lerpf(_lean, target, clampf(6.0 * delta, 0.0, 1.0))
        if visual:
                visual.rotation.z = _lean


func _bike_stats() -> Dictionary:
        # exposed for the headless journey test (keeps numbers honest, not magic)
        return {
                "mass": mass,
                "engine_force": BIKE_ENGINE_FORCE,
                "steer_ratio": BIKE_STEER_RATIO,
                "max_lean": BIKE_MAX_LEAN,
                "roll_locked": axis_lock_angular_x,
                "lean": _lean,
        }
