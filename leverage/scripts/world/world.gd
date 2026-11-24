class_name World
extends Node3D
## World - the open-world scene orchestrator. Owns city geometry, player,
## traffic, pedestrians, named NPC visuals, police units, environment,
## mission entities, HUD + touch UI, intro cinematic, save/load hooks.

const PLAYER_SPAWN := Vector3(-252, 0.2, -164)   # Old Quarter corner, curb-side
const CLINIC_SPAWN := Vector3(-120, 0.2, 24)

var city: CityBuilder
var player: PlayerController
var camera_rig: CameraRig
var combat: CombatPlayer
var weapons: WeaponSystem
var traffic: TrafficManager
var hud: Node
var cinematic: Node
var touch: Node
var sun: DirectionalLight3D
var env: WorldEnvironment
var rain_particles: GPUParticles3D
var _pedestrians: Array = []
var _npc_agents := {}                  # npc_id -> NamedNpcAgent
var _police_units: Array = []
var _mission_enemies: Array = []
var _encounter_units: Array = []      # street-encounter combatants (v2.4.0)
var _encounter_peds: Array = []        # brawl pair
var _stash_node: Node3D = null        # dropped-stash pickup visual
var _markers: Array = []
var _lamp_lights: Array = []
var _night_materials: Array = []      # building materials w/ emission ramp
var _intro: Node = null
var _lightning_t := 0.0
var _lightning_flash := 0.0
var _current_interior := ""
var _interiors := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
        _rng.seed = 1111
        _build_environment()
        _build_city()
        _spawn_player()
        traffic = TrafficManager.new()
        traffic.name = "Traffic"
        add_child(traffic)
        _spawn_motorcycles()
        _setup_phone()
        hud = load("res://scripts/ui/hud.gd").new()
        hud.name = "HUD"
        add_child(hud)
        cinematic = load("res://scripts/ui/cinematic_overlay.gd").new()
        cinematic.name = "CinematicOverlay"
        add_child(cinematic)
        touch = load("res://scripts/ui/touch_controls.gd").new()
        touch.name = "TouchControls"
        add_child(touch)
        _wire_input()
        _wire_missions()
        _wire_police()
        _wire_events()
        _wire_audio()
        EventBus.area_entered.emit(GameState.current_area)
        CityDirector.update_player_position(player.global_position)


func _build_environment() -> void:
        env = WorldEnvironment.new()
        var environment := Environment.new()
        var sky := Sky.new()
        var sky_mat := ProceduralSkyMaterial.new()
        sky_mat.sky_top_color = Color("3f5a8c")
        sky_mat.sky_horizon_color = Color("9db3c8")
        sky_mat.ground_bottom_color = Color("2c2a26")
        sky_mat.ground_horizon_color = Color("8a8873")
        sky_mat.sun_angle_max = 30.0
        sky_mat.sun_curve = 0.12
        sky.sky_material = sky_mat
        environment.sky = sky
        environment.background_mode = Environment.BG_SKY
        environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
        environment.ambient_light_energy = 0.75
        environment.fog_enabled = true
        environment.fog_light_color = Color("8fa0b0")
        environment.fog_density = 0.0038
        environment.fog_sky_affect = 0.35
        environment.tonemap_mode = Environment.TONE_MAPPER_ACES
        environment.tonemap_exposure = 1.06
        env.environment = environment
        add_child(env)
        sun = DirectionalLight3D.new()
        sun.rotation_degrees = Vector3(-52, 35, 0)
        sun.light_color = Color("ffe0b0")
        sun.light_energy = 1.25
        sun.shadow_enabled = true
        sun.shadow_bias = 0.06
        add_child(sun)
        # rain particles (hidden until rain)
        rain_particles = GPUParticles3D.new()
        var mat := ParticleProcessMaterial.new()
        mat.direction = Vector3(0, -1, 0)
        mat.spread = 8.0
        mat.initial_velocity_min = 14.0
        mat.initial_velocity_max = 18.0
        mat.gravity = Vector3(0, -24, 0)
        mat.scale_min = 0.05
        mat.scale_max = 0.12
        rain_particles.process_material = mat
        var quad := QuadMesh.new()
        quad.size = Vector2(0.03, 0.35)
        var pm := StandardMaterial3D.new()
        pm.albedo_color = Color(0.6, 0.7, 0.85, 0.35)
        pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        quad.material = pm
        rain_particles.draw_pass_1 = quad
        rain_particles.amount = 900
        rain_particles.lifetime = 1.2
        rain_particles.emitting = false
        rain_particles.visible = false
        rain_particles.position = Vector3(0, 0, 0)
        add_child(rain_particles)


func _build_city() -> void:
        city = CityBuilder.new()
        city.name = "City"
        add_child(city)
        city.build(self)
        _interiors = city.build_interiors(self)
        _collect_night_materials()

func _collect_night_materials() -> void:
        # building/shop window + sign materials with baked emission: ramp by night
        for child in city.get_children():
                if child is MultiMeshInstance3D and child.multimesh != null:
                        var mesh: Mesh = child.multimesh.mesh
                        if mesh == null:
                                continue
                        for si in mesh.get_surface_count():
                                var mat := mesh.surface_get_material(si)
                                if mat is StandardMaterial3D and mat.emission_enabled:
                                        _night_materials.append({"mat": mat, "energy": mat.emission_energy_multiplier})


func _spawn_player() -> void:
        player = PlayerController.new()
        player.position = PLAYER_SPAWN
        add_child(player)
        camera_rig = CameraRig.new()
        camera_rig.name = "CameraRig"
        camera_rig.follow_target = player
        player.add_child(camera_rig)
        camera_rig.position = Vector3(0, 1.6, 0)
        combat = CombatPlayer.new()
        combat.name = "CombatPlayer"
        player.add_child(combat)
        weapons = WeaponSystem.new()
        weapons.name = "WeaponSystem"
        player.add_child(weapons)


func place_player(pos: Vector3) -> void:
        if player:
                player.global_position = pos


func on_loaded_from_save(data: Dictionary) -> void:
        var pp = data.get("player_pos", null)
        if pp is Array and pp.size() == 3:
                player.global_position = Vector3(float(pp[0]), float(pp[1]) + 0.4, float(pp[2]))
        TimeWeather.restore(data.get("time_weather", {}))


func respawn_player_at_clinic() -> void:
        player.global_position = CLINIC_SPAWN
        player.freeze(false)
        player.visible = true
        GameState.in_vehicle = false
        InputRouter.set_context(InputRouter.Context.EXPLORE)


func play_opening_cinematic() -> void:
        _intro = load("res://scripts/story/intro_cinematic.gd").new()
        _intro.name = "IntroCinematic"
        add_child(_intro)

# ---------------- phone ----------------
var _phone: PhoneSystem
var _call_banner: CallBanner

func _setup_phone() -> void:
        _phone = PhoneSystem.new()
        _phone.name = "PhoneSystem"
        _phone.add_to_group("phone_system")
        add_child(_phone)
        _call_banner = load("res://scripts/ui/call_banner.gd").new()
        _call_banner.name = "CallBanner"
        add_child(_call_banner)
        _call_banner.bind_phone(_phone)
        # story beat: the Tipster calls shortly after the intro ends.
        _phone.schedule_call("the_tipster",
                ["Carter. I know who has your brother.",
                 "The Vetch crew took him for the ledger debt. I'll tell you where - when you've done something for this city.",
                 "Check your messages. Start with the market. Rizzo's expecting you."],
                22.0, "tipster_first",
                {"message": "Vetch crew has Tommy. They want the ledger debt. Start with the market - Rizzo's expecting you.",
                 "relationship": 4.0})

func get_phone() -> PhoneSystem:
        return _phone


# ---------------- input wiring ----------------
func _wire_input() -> void:
        InputRouter.punch_pressed.connect(func():
                if combat: combat.on_punch())
        InputRouter.kick_pressed.connect(func():
                if combat: combat.on_kick())
        InputRouter.heavy_pressed.connect(func():
                if combat: combat.on_heavy())
        InputRouter.dodge_pressed.connect(func():
                if combat: combat.on_dodge())
        InputRouter.attack_pressed.connect(func():
                if combat: combat.on_punch())
        InputRouter.interact_pressed.connect(_on_interact)
        InputRouter.jump_pressed.connect(func():
                if player and player.is_on_floor():
                        player.velocity.y = 4.6
                        player.play_anim_forced("Jump_Start"))
        InputRouter.lockon_toggled.connect(_toggle_lockon)
        InputRouter.enter_exit_pressed.connect(_on_enter_exit)
        InputRouter.pause_pressed.connect(_on_pause)
        InputRouter.map_pressed.connect(func():
                if hud:
                        hud.toggle_map())
        InputRouter.phone_pressed.connect(func():
                if hud:
                        hud.toggle_phone())
        InputRouter.weapon_next_pressed.connect(func():
                if weapons:
                        weapons.next_weapon())
        InputRouter.weapon_prev_pressed.connect(func():
                if weapons:
                        weapons.prev_weapon())
        InputRouter.reload_pressed.connect(func():
                if weapons:
                        weapons.try_reload())
        InputRouter.aim_toggled.connect(func(on):
                if weapons and on:
                        weapons.toggle_draw())
        InputRouter.shoot_pressed.connect(func():
                if weapons and camera_rig:
                        weapons.try_fire(camera_rig.camera))
        InputRouter.horn_pressed.connect(_on_horn)
        InputRouter.handbrake_pressed.connect(func(): pass)


func _on_interact() -> void:
        if _current_interior != "":
                _exit_interior()
                return
        if player:
                # street-side interior doors (amber glow markers) come first
                var near: Node = player.find_nearest_interactable()
                if near != null and near.has_meta("interior_id"):
                        try_enter_interior(String(near.get_meta("interior_id")))
                        return
                player.try_interact()


func _toggle_lockon() -> void:
        if camera_rig == null:
                return
        if camera_rig.lock_target != null:
                camera_rig.set_lock_target(null)
                player.lock_target = null
                return
        var t := _nearest_combatant(18.0)
        camera_rig.set_lock_target(t)
        player.lock_target = t


func _nearest_combatant(radius: float) -> Node3D:
        var best: Node3D = null
        var best_d := radius
        for c in get_tree().get_nodes_in_group("combatant"):
                if c is Node3D and c != player and c.is_inside_tree():
                        var d: float = player.global_position.distance_to(c.global_position)
                        if d < best_d:
                                best_d = d
                                best = c
        return best


func _on_enter_exit() -> void:
        if player == null:
                return
        if GameState.in_vehicle:
                # exit current vehicle
                var v := _player_vehicle()
                if v:
                        v.exit_vehicle()
                return
        # try to jack nearest traffic car / enter player vehicle
        var node := player.find_nearest_interactable()
        if node is VehiclePlayer:
                (node as VehiclePlayer).enter(player)
                return
        var agent := traffic.agent_by_proximity(player.global_position, ENTER_RADIUS)
        if agent:
                # kind-aware: jacking a traffic bike yields a real Motorcycle body
                var body: VehiclePlayer = VehiclePlayer.create_from_agent(agent, agent.vehicle_kind)
                add_child(body)
                traffic.agents.erase(agent)
                body.enter(player)
                GameState.track_stat("vehicles_jacked", 1)
                EventBus.crime_committed.emit("vehicle_theft", player.global_position,
                        PoliceSystem.crime_severity("vehicle_theft"), NPCDirector.witnesses_of(player.global_position))
                EventBus.notification_posted.emit("Vehicle jacked", "crime")
                return
        if weapons:
                weapons.toggle_draw()


const ENTER_RADIUS := 4.0


func _player_vehicle() -> VehiclePlayer:
        for c in get_tree().get_nodes_in_group("vehicle"):
                if c is VehiclePlayer and (c as VehiclePlayer).occupied:
                        return c
        return null


func _on_pause() -> void:
        if hud and hud.has_method("toggle_pause"):
                hud.toggle_pause()


func _on_horn() -> void:
        if GameState.in_vehicle:
                EventBus.sfx_requested.emit("sfx_horn", player.global_position)


# ---------------- missions wiring ----------------
func _wire_missions() -> void:
        MissionSystem.enemies_spawn_requested.connect(_spawn_mission_enemies)
        MissionSystem.marker_requested.connect(_place_marker)
        MissionSystem.marker_cleared.connect(_clear_markers)
        MissionSystem.vehicle_spawn_requested.connect(_spawn_mission_vehicle)
        MissionSystem.cinematic_requested.connect(func(beat): _play_beat(beat))
        EventBus.enemy_downed.connect(_check_wave_cleared)
        EventBus.mission_completed.connect(func(_id): _check_after_mission())


func _spawn_mission_enemies(mission_id: String, wave: Dictionary) -> void:
        var count: int = int(wave.get("count", 3))
        var wave_id: String = String(wave.get("wave", "vetch_collectors"))
        var spawn_at := Vector3(-240, 0, -120) # default near market
        match wave_id:
                "vetch_collectors": spawn_at = Vector3(-240, 0, -120)
                "vetch_shakers": spawn_at = Vector3(-240, 0, -180)
                "vetch_street": spawn_at = Vector3(-180, 0, -120)
                "lucy_miniboss": spawn_at = Vector3(-330, 0, 550)
                "lucy_boss": spawn_at = Vector3(-340, 0, 560)
                "yard_guards": spawn_at = Vector3(-360, 0, 300)
                "meet_ambush": spawn_at = Vector3(-330, 0, 560)
                "villa_guards": spawn_at = Vector3(120, 0, -620)
                "rowdy_patrons": spawn_at = Vector3(-240, 0, -180)
                "strike_breakers": spawn_at = Vector3(-380, 0, 250)
        var is_boss: bool = wave_id == "lucy_boss"
        for i in count:
                var e := Combatant.new()
                var hp := 55.0
                var dmg := 8.0
                if is_boss:
                        hp = 240.0
                        dmg = 16.0
                elif wave_id == "lucy_miniboss":
                        hp = 90.0
                        dmg = 11.0
                elif wave_id == "villa_guards" or wave_id == "meet_ambush":
                        hp = 70.0
                        dmg = 10.0
                var boss_name := "Vetch Muscle"
                if is_boss and i == 0:
                        boss_name = "Lucy Fang"
                e.setup("", "vetch", boss_name, hp, dmg,
                        "brawler" if not is_boss else "drunken")
                e.position = spawn_at + Vector3(_rng.randf_range(-6, 6), 0.2, _rng.randf_range(-6, 6))
                e.set_wave_id(wave_id)
                add_child(e)
                _mission_enemies.append(e)
                if is_boss and i == 0 and e.actor:
                        e.display_name = "Lucy Fang"
        if is_boss:
                EventBus.notification_posted.emit("Boss: Lucy Fang", "boss")


func _check_wave_cleared(enemy: Node) -> void:
        if enemy is Combatant and String(str(enemy.get_meta("encounter_id", ""))) != "":
                # street-encounter fight: all down -> director resolves the reward
                var eid := String(str(enemy.get_meta("encounter_id", "")))
                var alive := 0
                for e in _encounter_units:
                        if is_instance_valid(e) and String(str(e.get_meta("encounter_id", ""))) == eid and (e as Combatant)._state != "dead":
                                alive += 1
                if alive == 0:
                        StreetEncounters.notify_fight_cleared()
                return
        if enemy is Combatant and (enemy as Combatant).wave_id() != "":
                var wave_id: String = (enemy as Combatant).wave_id()
                var alive := 0
                for e in _mission_enemies:
                        if is_instance_valid(e) and (e as Combatant)._state != "dead" and (e as Combatant).wave_id() == wave_id:
                                alive += 1
                _mission_enemies = _mission_enemies.filter(func(e): return is_instance_valid(e))
                if alive == 0:
                        MissionSystem.notify_enemies_cleared()
                        if wave_id == "lucy_boss":
                                GameState.set_story_flag("lucy_down", true)
        elif enemy is Combatant and (enemy as Combatant).faction == "police":
                pass


func _check_after_mission() -> void:
        pass


func _place_marker(pos: Vector3) -> void:
        _clear_markers()
        var marker := Node3D.new()
        marker.position = pos + Vector3(0, 6, 0)
        var mi := MeshInstance3D.new()
        var cyl := CylinderMesh.new()
        cyl.top_radius = 0.1
        cyl.bottom_radius = 0.4
        cyl.height = 6.0
        mi.mesh = cyl
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color("f0a33c")
        mat.emission_enabled = true
        mat.emission = Color("f0a33c")
        mat.emission_energy_multiplier = 1.2
        mi.set_material_override(mat)
        marker.add_child(mi)
        add_child(marker)
        _markers.append(marker)


func _clear_markers() -> void:
        for m in _markers:
                if is_instance_valid(m):
                        m.queue_free()
        _markers.clear()


func _spawn_motorcycles() -> void:
        # parked bikes (R13: cars AND motorcycles). Old Quarter curb by
        # Marisol's Bar + Neon Strip curb - free-roam rideables from minute one.
        for spec in [
                {"pos": Vector3(-254.6, 0.05, -157), "rot": 0.0},
                {"pos": Vector3(150, 0.4, 233), "rot": PI / 2.0},
        ]:
                var m: Motorcycle = Motorcycle.create_at(spec["pos"])
                add_child(m)
                m.rotation.y = spec["rot"]


func _spawn_mission_vehicle(spec: Dictionary) -> void:
        var kind: String = String(spec.get("vehicle", "sedan"))
        var pos: Vector3 = spec.get("pos", PLAYER_SPAWN)
        var glb := "res://assets/vehicles/sedan.glb"
        match kind:
                "suv": glb = "res://assets/vehicles/suv.glb"
                "sport": glb = "res://assets/vehicles/sport.glb"
                "taxi": glb = "res://assets/vehicles/taxi.glb"
        var v := VehiclePlayer.create(kind, glb, pos + Vector3(0, 0.5, 0))
        add_child(v)


func _play_beat(beat: String) -> void:
        # Lightweight cinematic beats reuse the intro letterbox system.
        if _intro == null:
                _intro = load("res://scripts/story/intro_cinematic.gd").new()
                add_child(_intro)
        if _intro.has_method("play_beat"):
                _intro.play_beat(beat)


# ---------------- police wiring ----------------
func _wire_police() -> void:
        PoliceSystem.unit_spawn_requested.connect(_spawn_police)
        PoliceSystem.roadblock_requested.connect(_spawn_roadblock)
        EventBus.player_arrested.connect(func(): _on_arrested())


func _spawn_police(kind: String, position: Vector3, level: int) -> void:
        if kind == "air_unit":
                var au := AirUnit.new()
                au.position = position + Vector3(0, 30, 0)
                add_child(au)
                _police_units.append(au)
                EventBus.notification_posted.emit("Air unit inbound — find cover", "crime")
                return
        var u := PoliceUnit.new()
        u.setup_police(kind, level)
        u.position = position + Vector3(_rng.randf_range(-8, 8), 0.2, _rng.randf_range(-8, 8))
        add_child(u)
        _police_units.append(u)
        if _police_units.size() > 12:
                var old: PoliceUnit = _police_units.pop_front()
                if is_instance_valid(old):
                        old.queue_free()


func _spawn_roadblock(pos: Vector3) -> void:
        # two parked cop cars + cones across the road
        for off in [-4.0, 4.0]:
                var v := VehiclePlayer.create("cop", "res://assets/vehicles/cop.glb", pos + Vector3(off, 0.4, 0))
                add_child(v)
                v.rotation.y = PI / 2.0
        for i in 5:
                var cone := Node3D.new()
                cone.position = pos + Vector3(-5.0 + i * 2.5, 0.0, 1.5)
                if ResourceLoader.exists("res://assets/props/cone.glb"):
                        var packed: PackedScene = load("res://assets/props/cone.glb")
                        cone.add_child(packed.instantiate())
                add_child(cone)
        EventBus.sfx_requested.emit("sfx_police_radio", pos)


func _on_arrested() -> void:
        _clear_police()
        GameManager.respawn_player()


func _clear_police() -> void:
        for u in _police_units:
                if is_instance_valid(u):
                        u.queue_free()
        _police_units.clear()


# ---------------- world events wiring ----------------
func _wire_events() -> void:
        EventBus.world_event_started.connect(func(eid, area):
                if eid == "neon_blackout" and city:
                        pass)
        StreetEncounters.encounter_started.connect(_spawn_encounter)
        StreetEncounters.encounter_ended.connect(_end_encounter_visuals)


func _wire_audio() -> void:
        EventBus.music_layer_requested.emit("explore_day")
        EventBus.ambience_area_changed.emit(GameState.current_area)


# ---------------- simulation ----------------
func _process(delta: float) -> void:
        if player == null:
                return
        CityDirector.update_player_position(player.global_position)
        _update_day_night(delta)
        _maintain_pedestrians(delta)
        _maintain_named_npcs()
        _maintain_police(delta)
        _maintain_collectibles()
        _maintain_encounters(delta)
        if _intro == null or not is_instance_valid(_intro):
                pass


func _update_day_night(delta: float) -> void:
        var h := TimeWeather.hour()
        var night_f := 0.0
        if h >= 20 or h < 6:
                night_f = 1.0
        elif h >= 17:
                night_f = (h - 17.0) / 3.0
        elif h < 8:
                night_f = 1.0 - (h - 6.0) / 2.0
        # sun rotation: dawn east, dusk west
        var day_t := h / 24.0
        sun.rotation_degrees = Vector3(-20.0 - (70.0 * sin(PI * clamp(day_t, 0.0, 1.0))), 35.0, 0.0)
        sun.light_energy = lerp(1.35, 0.04, night_f)
        sun.light_color = Color("fff2d8").lerp(Color("40466e"), night_f)
        var sky_mat := (env.environment.sky.sky_material as ProceduralSkyMaterial)
        sky_mat.sky_top_color = Color("3f5a8c").lerp(Color("0a0d1a"), night_f)
        sky_mat.sky_horizon_color = Color("9db3c8").lerp(Color("141827"), night_f)
        sky_mat.ground_horizon_color = Color("8a8873").lerp(Color("101014"), night_f)
        env.environment.ambient_light_energy = lerp(0.75, 0.16, night_f)
        env.environment.fog_light_color = Color("8fa0b0").lerp(Color("0d0e14"), night_f)
        # building window emission ramps up at night
        for e in _night_materials:
                var m: StandardMaterial3D = e["mat"]
                m.emission_energy_multiplier = lerp(0.25, float(e["energy"]), night_f)
        # street lamps near player at night (follow player)
        if night_f > 0.3 and _lamp_lights.is_empty():
                for i in 8:
                        var l := OmniLight3D.new()
                        l.omni_range = 15.0
                        l.light_color = Color("ffbe6e")
                        l.light_energy = 1.3
                        l.shadow_enabled = false
                        add_child(l)
                        _lamp_lights.append(l)
        if not _lamp_lights.is_empty() and city != null and player != null:
                var lp: Array = city.lamp_positions
                if lp.size() > 0:
                        # 8 nearest lamps to the player
                        var pp := Vector2(player.global_position.x, player.global_position.z)
                        var sorted := lp.duplicate()
                        sorted.sort_custom(func(a, b): return (a as Vector2).distance_to(pp) < (b as Vector2).distance_to(pp))
                        for i in _lamp_lights.size():
                                if i < sorted.size():
                                        (_lamp_lights[i] as OmniLight3D).position = Vector3((sorted[i] as Vector2).x + 1.2, 4.55, (sorted[i] as Vector2).y)
        for l in _lamp_lights:
                l.light_energy = 1.3 * night_f * (1.0 if WorldEvents.neon_lights_on() else 0.4)
        # rain
        var rain: float = TimeWeather.rain_intensity
        rain_particles.visible = rain > 0.05
        rain_particles.emitting = rain > 0.05
        rain_particles.global_position = player.global_position + Vector3(0, 14, 0)
        rain_particles.amount = int(200 + 700 * rain)
        env.environment.fog_density = lerp(0.005, 0.012, rain)
        # storm lightning (timer-driven; no await in _process)
        if TimeWeather.current_weather == "storm":
                _lightning_t -= delta
                if _lightning_t <= 0.0:
                        _lightning_t = _rng.randf_range(6.0, 16.0)
                        _lightning_flash = 0.24
                        EventBus.sfx_requested.emit("sfx_thunder", player.global_position)
        if _lightning_flash > 0.0:
                _lightning_flash -= delta
                sun.light_energy = 3.0
        elif TimeWeather.is_night():
                sun.light_energy = 0.05


func _maintain_pedestrians(_delta: float) -> void:
        # prune dead/far
        for p in _pedestrians.duplicate():
                if not is_instance_valid(p):
                        _pedestrians.erase(p)
                        continue
                var d: float = player.global_position.distance_to(p.global_position)
                if d > 130.0:
                        p.queue_free()
                        _pedestrians.erase(p)
        var want: int = NPCDirector.pedestrian_target_count(CityDirector.current_area)
        if _pedestrians.size() < want and TimeWeather.get_elapsed_game_hours() > 0.0:
                if _rng.randf() < 0.3:
                        var ped := PedestrianAgent.new()
                        ped.position = NPCDirector.pedestrian_spawn_point(player.global_position)
                        add_child(ped)
                        _pedestrians.append(ped)


func _maintain_named_npcs() -> void:
        var needed: Array = NPCDirector.named_visuals_needed(player.global_position)
        # remove agents no longer needed (unless in combat or player-locked)
        for npc_id in _npc_agents.keys():
                if not needed.has(npc_id):
                        var agent: Node = _npc_agents[npc_id]
                        if is_instance_valid(agent) and agent is Combatant:
                                if not (agent as Combatant).aggro and not _intro_running():
                                        agent.queue_free()
                                        _npc_agents.erase(npc_id)
        # spawn needed
        for npc_id in needed:
                if _npc_agents.has(npc_id):
                        var agent: Node = _npc_agents[npc_id]
                        if is_instance_valid(agent):
                                agent.global_position = NPCDirector.named_pos(npc_id)
                                continue
                        _npc_agents.erase(npc_id)
                var agent := NamedNpcAgent.new()
                agent.setup_npc(npc_id)
                agent.position = NPCDirector.named_pos(npc_id)
                add_child(agent)
                _npc_agents[npc_id] = agent


func _intro_running() -> bool:
        return _intro != null and is_instance_valid(_intro)


func _maintain_police(delta: float) -> void:
        _police_units = _police_units.filter(func(u): return is_instance_valid(u))
        var plan: Array = PoliceSystem.patrol_plan()
        var want_foot := 0
        var want_cruiser := 0
        var want_air := 0
        for p in plan:
                if String(p.get("kind", "")) == "foot_patrol":
                        want_foot = int(p.get("count", 0))
                elif String(p.get("kind", "")) == "cruiser":
                        want_cruiser = int(p.get("count", 0))
                elif String(p.get("kind", "")) == "air_unit":
                        want_air = int(p.get("count", 0))
        var foot := 0
        var air := 0
        for u in _police_units:
                if u is PoliceUnit:
                        foot += 1
                elif u is AirUnit:
                        air += 1
        if foot < want_foot and _rng.randf() < 0.02:
                var anchor := CityDirector.patrol_anchor(CityDirector.current_area)
                _spawn_police("foot_patrol", Vector3(anchor.x, 0, anchor.y), GameState.wanted_level)
        if want_cruiser > 0 and _rng.randf() < 0.01:
                _spawn_police("cruiser", player.global_position + Vector3(_rng.randf_range(-60, 60), 0, _rng.randf_range(-60, 60)), GameState.wanted_level)
        # 5-star climax: the air unit joins the pursuit
        if want_air > air and _rng.randf() < 0.03:
                _spawn_police("air_unit", player.global_position, 5)
        # remove when calm
        if GameState.wanted_level == 0 and not _police_units.is_empty():
                _clear_police()


## ---------------- street encounters (v2.4.0) ----------------
func _spawn_encounter(eid: String, pos: Vector3, _area: String) -> void:
        var def: Dictionary = StreetEncounters.encounter_def(eid)
        if def.is_empty():
                return
        match String(def.get("kind", "")):
                "combat":
                        var n := int(def.get("enemies", 1))
                        var label := "Vetch Muscle" if eid == "street_mugging" else "Dealer"
                        for i in n:
                                var e := Combatant.new()
                                e.setup("", "vetch", label, float(def.get("hp", 60.0)), float(def.get("dmg", 8.0)), "brawler")
                                e.position = pos + Vector3(_rng.randf_range(-5, 5), 0.2, _rng.randf_range(-5, 5))
                                e.set_meta("encounter_id", eid)
                                add_child(e)
                                _encounter_units.append(e)
                "ambient":
                        # two fighters going at it; they scatter when the player closes in
                        for i in 2:
                                var p := PedestrianAgent.new()
                                p.position = pos + Vector3(2.0 * float(i) - 1.0, 0, 0)
                                p.set_meta("brawler", true)
                                add_child(p)
                                _encounter_peds.append(p)
                "pickup":
                        _spawn_stash(pos)


func _spawn_stash(pos: Vector3) -> void:
        var stash := Node3D.new()
        stash.position = pos
        var box := MeshInstance3D.new()
        var m := BoxMesh.new()
        m.size = Vector3(0.5, 0.22, 0.35)
        box.mesh = m
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.9, 0.75, 0.25)
        mat.emission_enabled = true
        mat.emission = Color(0.95, 0.7, 0.2)
        mat.emission_energy_multiplier = 2.2
        box.material_override = mat
        stash.add_child(box)
        var glow := OmniLight3D.new()
        glow.omni_range = 6.0
        glow.light_color = Color(0.95, 0.7, 0.2)
        stash.add_child(glow)
        stash.add_to_group("encounter_stash")
        add_child(stash)
        _stash_node = stash


func _maintain_encounters(_delta: float) -> void:
        # dropped stash: player walks onto it
        if _stash_node != null and is_instance_valid(_stash_node) and player != null:
                if player.global_position.distance_to(_stash_node.global_position) < 2.2:
                        _stash_node.queue_free()
                        _stash_node = null
                        StreetEncounters.notify_pickup_reached()
        # brawl pair scatter when the player closes in
        for p in _encounter_peds:
                if is_instance_valid(p) and player != null:
                        if p.global_position.distance_to(player.global_position) < 6.0 and String(p._state) == "idle":
                                p._start_flee()
        _encounter_units = _encounter_units.filter(func(e): return is_instance_valid(e))
        _encounter_peds = _encounter_peds.filter(func(p): return is_instance_valid(p))


func _end_encounter_visuals(eid: String, _outcome: String) -> void:
        for e in _encounter_units:
                if is_instance_valid(e) and String(str(e.get_meta("encounter_id", ""))) == eid:
                        e.queue_free()
        _encounter_units = _encounter_units.filter(func(e): return is_instance_valid(e) and String(str(e.get_meta("encounter_id", ""))) != eid)
        if _stash_node != null and is_instance_valid(_stash_node) and not StreetEncounters.is_active("dropped_stash"):
                _stash_node.queue_free()
                _stash_node = null


func _maintain_collectibles() -> void:
        for c in get_tree().get_nodes_in_group("collectible"):
                if c is Node3D and is_instance_valid(c):
                        var d: float = player.global_position.distance_to(c.global_position)
                        if d < 1.6:
                                var cid: String = str(c.get_meta("collectible_id", ""))
                                if not GameState.collectibles_found.has(cid):
                                        GameState.collectibles_found[cid] = true
                                        GameState.player_stats["collectibles_found"] += 1
                                        GameState.add_money(60)
                                        EventBus.collectible_found.emit(cid)
                                        EventBus.notification_posted.emit("Cinder Token found (+$60)", "collect")
                                        EventBus.sfx_requested.emit("sfx_token", player.global_position)
                                        MissionSystem.notify_item_collected("token")
                                        c.queue_free()


## ---------------- Interiors ----------------
func _enter_interior(interior_id: String) -> void:
        if _interiors.has(interior_id):
                GameState.in_interior = interior_id
                _current_interior = interior_id
                var room: Node3D = _interiors[interior_id]
                _street_pos = player.global_position
                # spawn just inside the room, clear of the wall and the entry door
                var room_size: float = float(room.get_meta("room_size", 10.0))
                player.global_position = Vector3(room.position.x, 0.2,
                        room.position.z + room_size * 0.5 - 1.6)
                InputRouter.set_context(InputRouter.Context.INTERIOR)
                EventBus.ambience_area_changed.emit("interior")
                EventBus.notification_posted.emit("Entered: " + interior_id.capitalize(), "area")


var _street_pos := Vector3.ZERO


func _exit_interior() -> void:
        GameState.in_interior = ""
        _current_interior = ""
        player.global_position = _street_pos + Vector3(0, 0.3, 0)
        InputRouter.set_context(InputRouter.Context.EXPLORE)
        EventBus.ambience_area_changed.emit(CityDirector.current_area)
        EventBus.notification_posted.emit("Back to the street", "area")


## Public: interiors callable from interact nodes.
func try_enter_interior(interior_id: String) -> void:
        _enter_interior(interior_id)
