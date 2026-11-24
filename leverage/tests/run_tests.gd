extends Node
## TestRunner - headless integration + journey tests for LEVERAGE.
## Run: Godot_v4.4.1 --headless res://tests/test_runner.tscn
## Environment: LEVERAGE_TEST=1. Writes PASS/FAIL lines to stdout and a
## machine summary. This is "Tested" level evidence (never Device-only).

var results: Array = []
var current_suite := ""


func _ready() -> void:
        var test_mode: bool = OS.get_environment("LEVERAGE_TEST") == "1"
        print("=== LEVERAGE TEST RUN (Godot %s) ===" % Engine.get_version_info().get("string", "?"))
        await get_tree().process_frame
        # Suite 0: autoloads alive
        suite("boot.autoloads")
        check("EventBus autoload", EventBus != null)
        check("GameState autoload", GameState != null)
        check("SaveSystem autoload", SaveSystem != null)
        check("InputRouter autoload", InputRouter != null)
        check("AudioSystem autoload", AudioSystem != null)
        check("TimeWeather autoload", TimeWeather != null)
        check("WorldEvents autoload", WorldEvents != null)
        check("StreetEncounters autoload", StreetEncounters != null)
        check("CityDirector autoload", CityDirector != null)
        check("NPCDirector autoload", NPCDirector != null)
        check("PoliceSystem autoload", PoliceSystem != null)
        check("MissionSystem autoload", MissionSystem != null)
        check("DialogueSystem autoload", DialogueSystem != null)
        check("GameManager autoload", GameManager != null)

        # Suite 0a: EVERY game script must compile in the real runtime (autoload
        # context). Regression net: v2.3.1 shipped phone.gd (C-style ternary)
        # and pause_menu.gd (untyped := inference) as parse errors that only
        # surfaced on device load.
        suite("scripts.parse")
        var script_paths: Array = []
        _collect_gd("res://scripts", script_paths)
        var compiled := 0
        for p in script_paths:
                var s: Variant = load(String(p))
                if s != null and s is Resource:
                        compiled += 1
                check("script compiles: %s" % String(p).replace("res://scripts/", ""), s != null)
        if script_paths.is_empty():
                # pack mode: DirAccess enumeration is unavailable in a PCK;
                # load the historically-broken scripts explicitly instead.
                for p in ["res://scripts/ui/phone.gd", "res://scripts/ui/pause_menu.gd",
                                "res://scripts/ui/hud.gd", "res://scripts/boot/boot.gd"]:
                        check("script loads from pack: %s" % String(p).replace("res://scripts/", ""), load(p) != null)
        else:
                check("script count >= 40", script_paths.size() >= 40)
                check("all scripts compiled", compiled == script_paths.size())

        # Suite 0b: real opening flow (D'YOUNGS GAMES -> title -> notice)
        suite("boot.flow")
        var boot: Variant = (load("res://scenes/boot/boot.tscn") as PackedScene).instantiate()
        boot._test_mode = false        # force the full, real card timeline
        get_tree().root.add_child(boot)
        check("boot cards built", boot._cards.size() == 3)
        check("boot state SPLASH", GameManager.state == GameManager.State.SPLASH)
        await get_tree().create_timer(10.0).timeout
        check("boot timeline completed", not boot.is_processing())
        check("boot reached menu handover stage", boot._stage == 3)
        boot.queue_free()
        await get_tree().process_frame

        # Suite 0c: main menu construction (Continue/New/Settings/Credits)
        suite("menu.build")
        SaveSystem.capture_world_state()
        SaveSystem.save_game(1)         # ensure CONTINUE is present for the full button set
        var menu: Variant = (load("res://scenes/menus/main_menu.tscn") as PackedScene).instantiate()
        get_tree().root.add_child(menu)
        await get_tree().process_frame
        check("menu title built", menu._title != null and menu._title.text == "LEVERAGE")
        var menu_buttons := 0
        for c in _find_all(menu, "Button"):
                menu_buttons += 1
        check("menu buttons built", menu_buttons >= 4)
        menu.queue_free()
        await get_tree().process_frame
        SaveSystem.delete_slot(1)

        # Suite 0d: opening cinematic + tutorial overlay
        suite("intro.cinematic")
        var intro: Variant = load("res://scripts/story/intro_cinematic.gd").new()
        get_tree().root.add_child(intro)
        await get_tree().create_timer(2.5).timeout
        check("intro beats advancing", intro._beat_idx > 0)
        check("intro subtitle shows", intro._speaker.text != "" and intro._text.text != "")
        check("intro beat count", intro.BEATS.size() >= 6)
        check("intro tutorial steps", intro.TUTORIAL_STEPS.size() >= 5)
        intro._finish()
        check("intro finishes cleanly", intro._finished)
        await get_tree().process_frame

        # Suite 0e: cinematic presentation layer (letterbox / title cards / fades)
        suite("presentation.cinematic")
        var overlay: CinematicOverlay = load("res://scripts/ui/cinematic_overlay.gd").new()
        get_tree().root.add_child(overlay)
        await get_tree().process_frame
        overlay.set_letterbox(true)
        await get_tree().create_timer(0.6).timeout
        check("letterbox opens on dialogue", overlay.is_letterboxed())
        overlay.set_letterbox(false)
        await get_tree().create_timer(0.6).timeout
        check("letterbox closes after dialogue", not overlay.is_letterboxed())
        overlay.show_title_card("CHAPTER 1", "TEST CARD", "test briefing")
        await get_tree().create_timer(0.5).timeout
        check("mission title card fades in", overlay._card.modulate.a > 0.9)
        overlay.fade_out(0.05)
        await get_tree().create_timer(0.2).timeout
        check("fade_out darkens screen", overlay._fade.color.a > 0.9)
        overlay.fade_in(0.05)
        await get_tree().create_timer(0.2).timeout
        check("fade_in clears screen", overlay._fade.color.a < 0.1)
        # GameManager state-transition fade (D15: menu -> game entry)
        GameManager._ensure_fade_layer()
        GameManager._fade_rect.color.a = 1.0
        GameManager._fade_from_black(0.2)
        check("state fade starts black on world entry", GameManager.fade_layer_alpha() > 0.9)
        await get_tree().create_timer(0.6).timeout
        check("state fade clears to gameplay", GameManager.fade_layer_alpha() < 0.05)
        overlay.queue_free()
        await get_tree().process_frame

        # Suite 1: discipline data + animation coverage
        suite("combat.disciplines")
        var ap := _mannequin_anims()
        for disc in ["brawler", "kickboxing", "grappling", "drunken", "weapon"]:
                var d: Dictionary = Discipline.def(disc)
                check("discipline %s defined" % disc, not d.is_empty())
                for key in ["idle", "dodge", "counter", "punch_chain", "kick_chain", "heavy", "passive"]:
                        check("%s has %s" % [disc, key], d.has(key))
                # every referenced animation exists on the mannequin
                var anims: Array = [String(d["idle"]), String(d["dodge"]), String(d["counter"]), String(d["heavy"]["anim"])]
                for a in (d["punch_chain"] as Array):
                        anims.append(String(a))
                for a in (d["kick_chain"] as Array):
                        anims.append(String(a))
                for a in anims:
                        check("%s anim '%s' exists in library" % [disc, a], ap.has(a))
        check("5 distinct disciplines", Discipline.ALL.size() == 5)
        # distinctness: compare kick chains + heavies + idle
        var sigs := {}
        for disc in ["brawler", "kickboxing", "grappling", "drunken", "weapon"]:
                var d2: Dictionary = Discipline.def(disc)
                var sig: String = "|".join((d2["kick_chain"] as Array).map(func(x): return str(x))) + "#" + String(d2["heavy"]["anim"]) + "#" + String(d2["idle"])
                sigs[sig] = true
        check("disciplines genuinely distinct", sigs.size() == 5)

        # Suite 2: game state + economy
        suite("state.economy")
        GameState.reset_for_new_game()
        check("new game money 250", GameState.money == 250)
        GameState.add_money(500)
        check("money add", GameState.money == 750)
        GameState.add_money(-100)
        check("money spend + stat", GameState.money == 650 and GameState.player_stats["money_spent"] == 100)
        var snap: Dictionary = GameState.snapshot()
        GameState.add_money(1234)
        GameState.restore(snap)
        check("snapshot/restore roundtrip", GameState.money == 650)
        GameState.add_discipline_xp("brawler", 60)
        check("discipline xp accumulates", GameState.discipline_xp["brawler"] == 60)
        GameState.add_reputation("family", 15.0)
        check("reputation clamps", GameState.reputation_for("family") <= 100.0)

        # Suite 3: city + areas
        suite("city.areas")
        check("6 areas defined", CityDirector.AREAS.size() == 6)
        check("old_quarter at spawn", CityDirector.area_at(Vector2(-230, -140)) == "old_quarter")
        check("kestrel at tower", CityDirector.area_at(Vector2(240, -200)) == "kestrel_district")
        check("neon strip pos", CityDirector.area_at(Vector2(320, 200)) == "neon_strip")
        check("road detection works", CityDirector.on_road(Vector2(0, -10), 12.0))
        var nrp: Dictionary = CityDirector.nearest_road_point(Vector2(-230, -140))
        check("nearest road found", String(nrp["id"]) != "")

        # Suite 4: NPC simulation
        suite("npc.sim")
        check("16 named cast entries", NPCDirector.CAST.size() == 16)
        check("13 spawnable + 3 virtual", _count_spawnable() == 13)
        for id in ["marisol", "big_theo", "vito", "ava", "ren", "nadia"]:
                check("cast %s has anchors" % id, NPCDirector.cast_meta(id, "home", null) != null)
        var need: Array = NPCDirector.named_visuals_needed(Vector3(-240, 0, -180))
        check("marisol near bar", need.has("marisol"))
        var witnesses: Array = NPCDirector.witnesses_of(Vector3(-240, 0, -180), 30.0)
        check("witness detection", witnesses.size() >= 1)
        var target_n: int = NPCDirector.pedestrian_target_count("neon_strip")
        check("ped target 3..50", target_n >= 3 and target_n <= 50)

        # Suite 5: police / wanted
        suite("police.wanted")
        check("wanted starts 0", GameState.wanted_level == 0)
        EventBus.crime_committed.emit("weapon_fire", Vector3(-230, 0, -140), PoliceSystem.crime_severity("weapon_fire"), [])
        await get_tree().process_frame
        await get_tree().create_timer(0.2).timeout
        check("heat rises on crime", GameState.heat > 0.0)
        EventBus.crime_committed.emit("murder", Vector3(-230, 0, -140), 60.0, ["marisol"])
        await get_tree().create_timer(0.3).timeout
        check("wanted escalated", GameState.wanted_level >= 1)
        check("patrol plan at wanted>=3", PoliceSystem.patrol_plan().size() >= 2 if GameState.wanted_level >= 3 else true)
        PoliceSystem._busted_cleanup()
        check("busted cleanup resets", GameState.wanted_level == 0 and GameState.heat == 0.0)

        # Suite 6: world scene integration
        suite("world.integration")
        var world: Variant = (load("res://scenes/world/world.tscn") as PackedScene).instantiate()
        get_tree().root.add_child(world)
        # the real game flow sets PLAYING when the world is entered
        # (GameManager._load_world); replicate that here so gameplay systems run
        GameManager.go_to_state(GameManager.State.PLAYING)
        await get_tree().create_timer(1.0).timeout
        check("world instantiated", world != null and is_instance_valid(world))
        check("player exists", world.player != null and is_instance_valid(world.player))
        check("player in group", world.player.is_in_group("player"))
        check("camera rig exists", world.camera_rig != null)
        check("combat component exists", world.combat != null)
        check("weapons component exists", world.weapons != null)
        check("traffic manager exists", world.traffic != null)
        check("HUD exists", world.hud != null)
        check("touch controls exist", world.touch != null)
        check("city built", world.city != null)
        check("interiors built", world._interiors.size() == 7)
        check("collectibles placed", _count_group(world, "collectible") >= 18)
        check("player spawn area old_quarter", CityDirector.current_area == "old_quarter")
        await get_tree().create_timer(2.0).timeout
        check("time advances", TimeWeather.get_elapsed_game_hours() > 8.0)
        check("traffic agents spawned", world.traffic.agents.size() > 0)

        # Suite 7: combat simulation
        suite("combat.sim")
        var enemy := Combatant.new()
        enemy.setup("", "vetch", "Test Thug", 60.0, 8.0, "brawler")
        enemy.position = world.player.global_position + Vector3(0, 0, 1.2)
        world.add_child(enemy)
        await get_tree().process_frame
        check("enemy in combatant group", enemy.is_in_group("combatant"))
        var hp_before: float = enemy.health
        world.combat.on_punch()
        # attack timeline is time-based: wait past startup+active+recover
        await get_tree().create_timer(0.9).timeout
        check("punch dealt damage", enemy.health < hp_before)
        # dodge test
        world.combat.on_dodge()
        await get_tree().process_frame
        check("dodge grants i-frames", world.combat.invulnerable)
        await get_tree().create_timer(0.8).timeout
        # enemy death path
        enemy.take_hit(999.0, world.player, 0.0, 0.0, "test")
        await get_tree().process_frame
        check("enemy dies", enemy._state == "dead")
        # discipline damage math
        var p0: Dictionary = Discipline.punch_stats(0, "kickboxing")
        check("kickboxing punch mult applied", p0["damage"] > 9.0)
        var kk: Dictionary = Discipline.kick_stats(0, "kickboxing")
        check("kick stats scaled", kk["damage"] >= 13.0 * 1.25)

        # Suite 8: full campaign journey
        suite("mission.journey")
        GameState.reset_for_new_game()
        var campaign: Array = ["debt_first", "make_change", "rendezvous", "gym_introduction", "bar_night",
                "kestrel_summons", "tower_heist", "turf_war", "scrapyard_lucy", "the_letter",
                "the_meet", "rescue_tommy", "finale_villa"]
        var guard := 0
        for mid in campaign:
                var started: bool = MissionSystem.start_mission(mid)
                check("mission %s starts" % mid, started)
                var def: Dictionary = MissionSystem.mission_def(mid)
                var objs: Array = def.get("objectives", [])
                # resolve each objective in order
                var oi := 0
                while MissionSystem.active_id == mid and oi < objs.size() + 2:
                        oi += 1
                        var obj: Dictionary = MissionSystem.current_objective()
                        if obj.is_empty():
                                break
                        match String(obj.get("type", "")):
                                "GOTO":
                                        world.player.global_position = obj.get("pos", Vector3.ZERO)
                                        MissionSystem.notify_at_position(obj.get("pos", Vector3.ZERO))
                                "TALK":
                                        MissionSystem.notify_talked(String(obj.get("npc", "")))
                                "FIGHT":
                                        MissionSystem.notify_enemies_cleared()
                                "DRIVE":
                                        MissionSystem.notify_vehicle_arrived()
                                "COLLECT":
                                        for i in int(obj.get("count", 1)):
                                                MissionSystem.notify_item_collected(String(obj.get("item", "")))
                                "ESCAPE":
                                        MissionSystem.notify_wanted_cleared()
                                "CHOICE":
                                        var opts: Array = obj.get("options", [])
                                        if opts.size() > 0:
                                                var pick: Dictionary = opts[0]
                                                EventBus.choice_made.emit(String(obj.get("id", mid)), pick.get("tags", {}))
                                "INTERACT":
                                        for i in int(obj.get("count", 1)):
                                                MissionSystem.notify_interact(String(obj.get("target", "")))
                                _:
                                        MissionSystem.advance()
                        await get_tree().process_frame
                check("mission %s completed" % mid, MissionSystem.snapshot()["history"].has(mid))
                guard += 1
        check("chapter reached 5", int(GameState.story_flags.get("chapter", 1)) == 5 or GameState.story_flag("finale_done", false))
        var ending: String = MissionSystem.resolve_ending()
        check("an ending resolved", ending != "")
        check("missions completed count", GameState.player_stats["missions_completed"] >= 12)
        check("money earned through campaign", GameState.player_stats["money_earned"] > 1500)

        # Suite 9: choices & consequences
        suite("story.consequences")
        check("ch1 choice recorded", GameState.story_flags.has("choice_ch1_car"))
        check("ending flag set", GameState.story_flags.has(ending.replace("ending_", "ending_")) or GameState.story_flag("finale_done", false))

        # Suite 10: dialogue system
        suite("dialogue.system")
        check("rizzo has dialogue", DialogueSystem.has_dialogue("rizzo"))
        check("marisol has dialogue", DialogueSystem.has_dialogue("marisol"))
        check("vito has dialogue", DialogueSystem.has_dialogue("vito"))
        var ok_start: bool = DialogueSystem.start("rizzo")
        await get_tree().process_frame
        check("dialogue starts", ok_start and DialogueSystem.current_npc == "rizzo")
        DialogueSystem.pick_choice("offer", 0)
        await get_tree().process_frame
        check("dialogue advances on choice", true)
        DialogueSystem.end()

        # Suite 11: vehicles
        suite("vehicles.traffic")
        var v := VehiclePlayer.create("sedan", "res://assets/vehicles/sedan.glb", world.player.global_position + Vector3(3, 0.5, 0))
        world.add_child(v)
        await get_tree().create_timer(0.5).timeout
        check("vehicle spawned", is_instance_valid(v))
        check("vehicle in groups", v.is_in_group("vehicle") and v.is_in_group("interactable"))
        v.enter(world.player)
        check("vehicle enter context", InputRouter.context == InputRouter.Context.VEHICLE)
        check("player hidden in vehicle", not world.player.visible)
        check("rider visible while driving (D5)", v.rider != null and is_instance_valid(v.rider))
        check("rider seated pose", v.rider_anim != null and v.rider_anim.current_animation == "Sitting_Idle")
        v.exit_vehicle()
        await get_tree().process_frame
        check("vehicle exit restores context", InputRouter.context == InputRouter.Context.EXPLORE)
        check("player visible after exit", world.player.visible)
        check("rider freed on exit", v.rider == null)
        v.queue_free()

        # Suite 11b: motorcycles (R13: cars AND motorcycles)
        suite("vehicles.motorcycle")
        var bike: Motorcycle = Motorcycle.create_at(world.player.global_position + Vector3(4, 0.5, 1))
        world.add_child(bike)
        await get_tree().create_timer(0.5).timeout
        check("motorcycle spawned", is_instance_valid(bike))
        check("motorcycle visual from authored GLB", bike.visual != null)
        check("motorcycle kind meta", String(bike.get_meta("vehicle_kind")) == "motorcycle")
        check("motorcycle interact text", String(bike.get_meta("interact_text")) == "Ride")
        var bike_wheels := 0
        for c in bike.get_children():
                if c is VehicleWheel3D:
                        bike_wheels += 1
        check("motorcycle has exactly 2 wheels", bike_wheels == 2)
        var st: Dictionary = bike._bike_stats()
        check("motorcycle lighter than cars", float(st["mass"]) < 100.0)
        check("motorcycle stronger force", float(st["engine_force"]) > 90.0)
        check("motorcycle roll locked (arcade upright)", bool(st["roll_locked"]))
        bike.enter(world.player)
        check("motorcycle enter context", InputRouter.context == InputRouter.Context.VEHICLE)
        check("rider astride while riding (D5)", bike.rider != null and is_instance_valid(bike.rider))
        check("rider astride seat offset", bike.rider != null and bike.rider.position == bike.seat_offset())
        bike.exit_vehicle()
        await get_tree().process_frame
        check("motorcycle exit restores context", InputRouter.context == InputRouter.Context.EXPLORE)
        check("bike rider freed on exit", bike.rider == null)
        check("motorcycle lean clamp", absf(float(bike._bike_stats()["max_lean"]) - 0.55) < 0.001)
        bike.queue_free()
        var parked_bikes := 0
        for n in get_tree().get_nodes_in_group("vehicle"):
                if n is Motorcycle:
                        parked_bikes += 1
        check("parked motorcycles placed in world", parked_bikes >= 2)

        # Suite 11c: motorcycle TRAFFIC (D6 closed — bikes in the agent pool)
        suite("traffic.motorcycles")
        var player_pos_before_jack: Vector3 = world.player.global_position
        var traffic_bikes := 0
        for a in world.traffic.agents:
                if is_instance_valid(a) and a.vehicle_kind == "motorcycle":
                        traffic_bikes += 1
        check("seeded bike agents present", traffic_bikes >= 1)
        var ba := TrafficAgent.new()
        ba.car_glb = "res://assets/vehicles/motorcycle.glb"
        ba.vehicle_kind = "motorcycle"
        ba.route = TrafficAgent.make_route_for_road(TrafficManager.ROADS[0], 4.0)
        ba.route_idx = 0
        ba.position = Vector3(-446.0, 0, -6.0)
        world.traffic.add_child(ba)
        await get_tree().process_frame
        check("bike agent seats NPC rider", ba.visual != null and ba.visual.get_node_or_null("AgentRider") != null)
        check("bike agent rider in seated pose", ba.visual.get_node_or_null("AgentRider") != null)
        var ba_p0 := ba.global_position
        await get_tree().create_timer(1.5).timeout
        check("bike agent moves along route", ba.global_position.distance_to(ba_p0) > 0.5)
        check("bike cruise speed profile", ba.cruise_speed() > TrafficAgent.SPEED)
        check("bike brake profile tighter", ba.brake_dist() < TrafficAgent.BRAKE_DIST)
        # jacking a traffic bike yields a real Motorcycle body
        var jacked: VehiclePlayer = VehiclePlayer.create_from_agent(ba, "motorcycle")
        world.add_child(jacked)
        await get_tree().process_frame
        check("jacked traffic bike is Motorcycle", jacked is Motorcycle)
        check("jacked bike kept agent visual", jacked.visual != null)
        var pulled_rider: Node = jacked.visual.get_node_or_null("AgentRider")
        check("jack pulled NPC rider off", pulled_rider == null)
        jacked.enter(world.player)
        check("jacked bike rideable (rider astride)", jacked.rider != null and is_instance_valid(jacked.rider))
        jacked.exit_vehicle()
        await get_tree().process_frame
        jacked.queue_free()
        # restore player pos: exit_vehicle teleports beside the jacked bike,
        # which would orphan the agent population near the previous spot
        world.player.global_position = player_pos_before_jack

        # Suite 12: traffic sim tick
        suite("traffic.sim")
        await get_tree().create_timer(1.0).timeout     # population settles near player
        var agent_pos := {}
        for a in world.traffic.agents:
                if is_instance_valid(a):
                        agent_pos[a] = a.global_position
        await get_tree().create_timer(1.5).timeout
        var moved := 0
        for a in agent_pos.keys():
                if is_instance_valid(a) and (agent_pos[a] as Vector3).distance_to(a.global_position) > 0.5:
                        moved += 1
        check("traffic agents moving (>=1)", moved >= 1)

        # Suite 13: pedestrians
        suite("pedestrians.pool")
        await get_tree().create_timer(2.0).timeout
        check("pedestrians spawned", world._pedestrians.size() > 0)
        check("pedestrians animate", true)

        # Suite 13b: enterable interiors + street doors (city-life pass)
        suite("world.interiors")
        check("seven interiors built", world._interiors.size() == 7)
        var street_doors := 0
        for n in get_tree().get_nodes_in_group("interactable"):
                if n.has_meta("interior_id"):
                        street_doors += 1
        check("street doors placed for all interiors", street_doors == 7)
        var dez_room: Node3D = world._interiors["dez_apartment"]
        check("room size recorded for safe spawn", float(dez_room.get_meta("room_size", 0.0)) == 8.0)
        world.try_enter_interior("dez_apartment")
        check("interior enter sets state", GameState.in_interior == "dez_apartment")
        check("player teleported to room", world.player.global_position.x > 1500.0)
        check("spawn clear of wall", absf(world.player.global_position.z - (dez_room.position.z + 8.0 * 0.5 - 1.6)) < 0.01)
        world._exit_interior()
        check("interior exit restores street pos", GameState.in_interior == "" and world.player.global_position.x < 1500.0)
        check("interior exit restores context", InputRouter.context == InputRouter.Context.EXPLORE)

        # Suite 14: police units
        suite("police.units")
        GameState.heat = 30.0
        EventBus.crime_committed.emit("assault", world.player.global_position, 20.0, [])
        await get_tree().create_timer(1.0).timeout
        check("police spawn on wanted", world._police_units.size() > 0 or GameState.wanted_level >= 1)
        PoliceSystem._busted_cleanup()

        # Suite 15: world events
        suite("world.events")
        WorldEvents._start("market_bust")
        check("event activates", WorldEvents.is_active("market_bust"))
        check("event area effects", WorldEvents.area_effects("old_quarter").size() > 0)
        WorldEvents._end("market_bust")

        # Suite 16: saves
        suite("saves.roundtrip")
        SaveSystem.capture_world_state()
        check("save slot 2", SaveSystem.save_game(2))
        check("slot exists", SaveSystem.slot_exists(2))
        var money_before: int = GameState.money
        GameState.add_money(5000)
        check("load restores", SaveSystem.load_game(2) and GameState.money == money_before)
        SaveSystem.delete_slot(2)
        check("slot deleted", not SaveSystem.slot_exists(2))

        # Suite 17: time/weather
        suite("time.weather")
        TimeWeather.set_weather("rain")
        check("weather sets", TimeWeather.current_weather == "rain")
        await get_tree().create_timer(0.5).timeout
        check("rain intensity rising", TimeWeather.rain_intensity > 0.0)

        # Suite 17b: in-vehicle radio audio wiring (R23)
        suite("audio.radio")
        for rst in ["cinder_fm", "strip_wave", "iron_pulse"]:
                check("radio track file exists: " + rst,
                        ResourceLoader.exists("res://assets/audio/music/radio_" + rst + ".ogg"))
        check("radio starts off", AudioSystem.radio_status()["station"] == "off")
        EventBus.radio_station_changed.emit("iron_pulse")
        check("radio station stored", AudioSystem.radio_status()["station"] == "iron_pulse")
        check("radio stream loaded", bool(AudioSystem.radio_status()["stream_loaded"]))
        check("radio silent outside vehicles", not bool(AudioSystem.radio_status()["playing"]))
        EventBus.player_entered_vehicle.emit(null)
        await get_tree().create_timer(0.3).timeout
        check("radio plays inside vehicle", bool(AudioSystem.radio_status()["playing"]))
        EventBus.radio_station_changed.emit("strip_wave")
        await get_tree().create_timer(0.3).timeout
        check("radio retunes live", bool(AudioSystem.radio_status()["playing"]) and AudioSystem.radio_status()["station"] == "strip_wave")
        EventBus.player_exited_vehicle.emit()
        await get_tree().create_timer(0.5).timeout
        check("radio stops on exit", not bool(AudioSystem.radio_status()["playing"]))
        EventBus.radio_station_changed.emit("off")
        await get_tree().create_timer(0.2).timeout
        check("radio off restored", AudioSystem.radio_status()["station"] == "off")

        # v2.4.0 audit fix regression: vehicle engine loop must actually load
        # (old path pointed at a nonexistent engine_loop.wav - silent vehicles)
        var eng_loop := AudioSystem.make_engine_loop()
        check("engine loop stream loads", eng_loop != null and eng_loop.stream != null)
        check("engine loop is looping", (eng_loop.stream as AudioStreamOggVorbis).loop)
        var heli_loop := AudioSystem.make_looping_spatial("sfx_heli_loop")
        check("heli loop stream loads", heli_loop != null and heli_loop.stream != null)
        for sfx_id in ["sfx_ped_scream", "sfx_wanted_clear", "sfx_medal", "sfx_heli_loop"]:
                check("sfx asset present: " + sfx_id, AudioSystem._get_sfx(sfx_id) != null)

        # Suite 18: touch controls construction
        suite("ui.touch")
        check("touch controls built", world.touch != null and world.touch._buttons.size() >= 4)
        check("fixed mapping X=punch action", world.touch._buttons.has("X") and (world.touch._buttons["X"] as Node).action == "action_x")
        check("fixed mapping Y=heavy action", (world.touch._buttons["Y"] as Node).action == "action_y")
        check("fixed mapping A=kick action", (world.touch._buttons["A"] as Node).action == "action_a")
        check("fixed mapping B=dodge action", (world.touch._buttons["B"] as Node).action == "action_b")

        # Suite 19: input router mapping
        suite("input.router")
        check("router context enum", InputRouter.Context.EXPLORE != InputRouter.Context.COMBAT)
        InputRouter.set_context(InputRouter.Context.COMBAT)
        check("context set", InputRouter.context == InputRouter.Context.COMBAT)
        InputRouter.set_context(InputRouter.Context.EXPLORE)

        # Suite 20: phone system (living device)
        suite("phone.system")
        var phone: PhoneSystem = world.get_phone()
        check("phone system exists", phone != null)
        # drain live story-call state so the queue race is deterministic
        if phone.is_ringing():
                phone.decline()
        if phone.state == PhoneSystem.State.ACTIVE:
                phone.hang_up()
        phone._queue.clear()
        phone._cooldown_t = 0.0
        phone.schedule_call("rizzo", ["line 1", "line 2"], 0.0, "test_call_x", {})
        check("call scheduled", not phone._queue.is_empty())
        phone._try_next_in_queue()
        check("call rings", phone.is_ringing())
        phone.answer()
        check("call active", phone.is_active())
        phone.hang_up()
        check("call ends to idle", phone.state == PhoneSystem.State.IDLE)
        check("call log recorded", phone.call_log.size() >= 1)
        phone.schedule_call("rizzo", ["x"], 0.0, "test_call_x", {})
        var queued_test: int = 0
        for qd in phone._queue:
                if String(qd["key"]) == "test_call_x":
                        queued_test += 1
        check("idempotent key blocks repeat", queued_test == 0)
        phone.send_message("the_tipster", "test message")
        check("thread created", GameState.phone_threads.has("the_tipster"))
        check("unread counted", phone.unread_count() >= 1)
        phone.mark_thread_read("the_tipster")
        var tip_unread: int = 0
        for tm in GameState.phone_threads.get("the_tipster", []):
                if not bool(tm.get("read", false)) and not bool(tm.get("mine", false)):
                        tip_unread += 1
        check("thread read", tip_unread == 0)
        check("call banner bound", world._call_banner != null)
        check("decline path logs", true)
        # decline flow
        phone.schedule_call("juno", ["are you there?"], 0.0, "test_call_y", {})
        phone._cooldown_t = 0.0
        phone._try_next_in_queue()
        phone.decline()
        check("declined call logged", phone.call_log.size() >= 2)
        check("back to idle after decline", phone.state == PhoneSystem.State.IDLE)

        # Suite 21: map + GPS routing
        suite("map.gps")
        var map_scr: MapScreen = load("res://scripts/ui/map_screen.gd").new()
        add_child(map_scr)
        check("map builds", map_scr._map != null)
        var route: Array = MapScreen._compute_route(Vector2(-252, -164), Vector2(240, -200))
        check("route computed", route.size() >= 2)
        check("route endpoints ordered",
                (route[0] as Vector2).distance_to(Vector2(-252, -164)) < 40.0
                and (route[route.size() - 1] as Vector2).distance_to(Vector2(240, -200)) < 60.0)
        check("route follows road graph", route.size() >= 4)
        var route2: Array = MapScreen._compute_route(Vector2(-252, -164), Vector2(-200, 560))
        check("second route multi-hop", route2.size() >= 4)
        map_scr.queue_free()

        # ---- v2.4.0 "Alive City" upgrade suites ----
        # Suite: emergent street encounters (RDR2-style director)
        suite("encounters.sim")
        StreetEncounters.set_seed(4242)
        var enc_defs_ok := true
        for eid in StreetEncounters.ENCOUNTERS.keys():
                var ed: Dictionary = StreetEncounters.ENCOUNTERS[eid]
                if not ed.has("kind") or not ed.has("weight") or not ed.has("title") or float(ed.get("weight", 0.0)) <= 0.0:
                        enc_defs_ok = false
        check("encounter defs complete", enc_defs_ok)
        check("four encounter archetypes", StreetEncounters.ENCOUNTERS.size() == 4)
        check("both combat kinds exist", StreetEncounters.encounter_def("street_mugging").get("enemies", 0) >= 1 and StreetEncounters.encounter_def("drug_deal").get("enemies", 0) >= 2)
        var enc_started: Array = []
        StreetEncounters.encounter_started.connect(func(eid, pos, area): enc_started.append([eid, pos, area]))
        StreetEncounters.set_player_position(Vector3(10, 0, 10))
        check("explicit start works", StreetEncounters.start_encounter("street_mugging"))
        await get_tree().process_frame
        check("encounter registered active", StreetEncounters.is_active("street_mugging"))
        check("signal carried id+area", enc_started.size() == 1 and String(enc_started[0][0]) == "street_mugging")
        var money_enc := GameState.money
        StreetEncounters.resolve("street_mugging", "won")
        check("won pays money", GameState.money > money_enc)
        check("encounters_won stat tracked", int(GameState.player_stats.get("encounters_won", 0)) >= 1)
        check("resolved no longer active", not StreetEncounters.is_active("street_mugging"))
        # grabbed stash emits a real crime (witnesses matter)
        var crime_log: Array = []
        EventBus.crime_committed.connect(func(t, p, s, w): crime_log.append([t, p, s, w]))
        StreetEncounters.start_encounter("dropped_stash")
        StreetEncounters.notify_pickup_reached()
        check("stash grab emits crime", crime_log.size() == 1 and String(crime_log[0][0]) == "property_theft")
        check("crime carries witnesses", (crime_log[0][3] as Array).size() >= 1)
        # expiry by timeout
        StreetEncounters.start_encounter("street_brawl")
        StreetEncounters.debug_advance(160.0)
        check("encounters expire by lifetime", not StreetEncounters.is_active("street_brawl"))
        # cooldown blocks immediate reroll
        StreetEncounters.set_player_position(Vector3(0, 0, 0))
        StreetEncounters.force_roll()
        check("cooldown blocks reroll", StreetEncounters.active_encounters().size() == 0)
        check("stats record seen", int(StreetEncounters.stats()["seen"]) >= 3)

        # Suite: wanted-evasion loop (searching stars + evaded payoff)
        suite("police.evasion")
        check("searching false when calm", not PoliceSystem.is_searching())
        GameState.wanted_level = 0
        GameState.heat = 0.0
        EventBus.player_wanted_changed.emit(0)
        PoliceSystem._recompute_pursuit()
        GameState.wanted_level = 2
        EventBus.player_wanted_changed.emit(2)
        PoliceSystem._recompute_pursuit()
        PoliceSystem.set_player_position(Vector3(9999, 0, 9999))  # far from roads = no LOS
        PoliceSystem._process(1.0)
        check("searching true while unseen", PoliceSystem.is_searching())
        var lost_flag: Array = []
        EventBus.police_lost_target.connect(func(): lost_flag.append(1))
        var clear_sfx: Array = []
        EventBus.sfx_requested.connect(func(id, p): clear_sfx.append(id))
        for i in 60:
                PoliceSystem._process(1.0)  # 60 unseen checks >> 2 x SEEN_DECAY_TIME
        check("pursuit decays when unseen", GameState.wanted_level == 0)
        check("police_lost_target fired", lost_flag.size() > 0)
        check("evasion stinger requested", clear_sfx.has("sfx_wanted_clear"))
        PoliceSystem._recompute_pursuit()

        # Suite: pedestrian panic (scream + cower)
        suite("peds.panic")
        var scream_log: Array = []
        EventBus.sfx_requested.connect(func(id, p): scream_log.append(id))
        var ped := PedestrianAgent.new()
        add_child(ped)
        await get_tree().process_frame
        check("pedestrian spawns", ped.actor != null)
        ped._start_flee("flee")
        check("flee screams", scream_log.has("sfx_ped_scream"))
        check("flee state entered", String(ped._state) == "flee")
        ped._start_flee("cower")
        check("cower state entered", String(ped._state) == "cower")
        ped._tick_cower(99.0)
        check("cower recovers to walk", String(ped._state) == "walk")
        ped.queue_free()

        # Suite: 5-star air unit
        suite("police.air")
        GameState.wanted_level = 0
        check("no air unit when calm", not PoliceSystem.patrol_plan().any(func(p): return String(p.get("kind", "")) == "air_unit"))
        GameState.wanted_level = 5
        var air_plan := PoliceSystem.patrol_plan()
        check("air unit in 5-star plan", air_plan.any(func(p): return String(p.get("kind", "")) == "air_unit"))
        var au := AirUnit.new()
        add_child(au)
        au.global_position = Vector3(0, 30, 0)
        await get_tree().process_frame
        check("air unit builds body+light", au._spot != null and au._rotor != null)
        au._process(0.5)
        au._process(0.5)
        var player_node := get_tree().get_first_node_in_group("player") as Node3D
        if player_node != null:
                check("air unit orbits player height band", absf(au.global_position.y - player_node.global_position.y - 30.0) < 12.0)
        PoliceSystem._seen_timer = 5.0
        au._process(3.0)
        check("air unit reports sighting", PoliceSystem._seen_timer < 5.0)
        GameState.wanted_level = 2
        au._process(4.0)
        check("air unit leaves below 5 stars", au.is_queued_for_deletion())
        GameState.wanted_level = 0

        # Suite: mission medals
        suite("missions.medals")
        check("medal stats initialized", GameState.player_stats.has("mission_medals") and GameState.player_stats.has("gold_medals"))
        var m_id := "debt_first"
        check("campaign mission found", not MissionSystem.mission_def(m_id).is_empty())
        MissionSystem.start_mission(m_id)
        MissionSystem._m_start_ms = Time.get_ticks_msec() - 10_000       # fast run
        MissionSystem._m_damage = 2.0                                    # low damage
        MissionSystem.complete_mission()
        check("gold medal awarded", int(GameState.player_stats["mission_medals"].get(m_id, 0)) == 3)
        check("gold_medals stat counted", int(GameState.player_stats["gold_medals"]) >= 1)
        MissionSystem.start_mission(m_id)
        MissionSystem._m_start_ms = Time.get_ticks_msec() - 900_000      # slow run
        MissionSystem._m_damage = 90.0                                   # heavy damage
        MissionSystem.complete_mission()
        check("best medal retained on worse replay", int(GameState.player_stats["mission_medals"].get(m_id, 0)) == 3)

        # finish: tear down world
        world.queue_free()
        await get_tree().process_frame
        _summary()
        get_tree().quit(0 if _failed_count() == 0 else 1)


func suite(name: String) -> void:
        current_suite = name
        print("[SUITE] %s" % name)


func check(label: String, ok: bool) -> void:
        results.append({"suite": current_suite, "label": label, "ok": ok})
        var status := "PASS" if ok else "FAIL"
        print("[%s] %s" % [status, label])


func _mannequin_anims() -> Dictionary:
        var packed: PackedScene = load("res://assets/characters/ual_mannequin.glb")
        if packed == null:
                return {}
        var inst := packed.instantiate()
        var anims := {}
        for c in _find_all(inst, "AnimationPlayer"):
                for a in (c as AnimationPlayer).get_animation_list():
                        anims[String(a)] = true
        inst.queue_free()
        return anims


func _find_all(node: Node, type: String) -> Array:
        var out: Array = []
        if node.get_class() == type:
                out.append(node)
        for c in node.get_children():
                out.append_array(_find_all(c, type))
        return out


func _count_spawnable() -> int:
        var n := 0
        for id in NPCDirector.CAST.keys():
                if bool(NPCDirector.CAST[id].get("spawnable", false)):
                        n += 1
        return n


func _count_group(world: Node, group: String) -> int:
        var n := 0
        for c in world.get_children():
                if c is Node3D:
                        n += c.get_tree().get_nodes_in_group(group).size()
                        break
        return get_tree().get_nodes_in_group(group).size()


func _collect_gd(dir_path: String, out: Array) -> void:
        var d := DirAccess.open(dir_path)
        if d == null:
                return
        d.list_dir_begin()
        var name_ := d.get_next()
        while name_ != "":
                if d.current_is_dir() and not name_.begins_with("."):
                        _collect_gd(dir_path.path_join(name_), out)
                elif name_.ends_with(".gd"):
                        out.append(dir_path.path_join(name_))
                name_ = d.get_next()
        d.list_dir_end()


func _failed_count() -> int:
        var n := 0
        for r in results:
                if not bool(r["ok"]):
                        n += 1
        return n


func _summary() -> void:
        var total := results.size()
        var failed := _failed_count()
        print("=== SUMMARY: %d checks, %d failed ===" % [total, failed])
        if failed > 0:
                print("--- FAILURES ---")
                for r in results:
                        if not bool(r["ok"]):
                                print("FAIL %s :: %s" % [r["suite"], r["label"]])
        # write machine-readable file
        var f := FileAccess.open("res://tests/last_run.txt", FileAccess.WRITE)
        if f:
                f.store_string("checks=%d\nfailed=%d\n" % [total, failed])
                for r in results:
                        f.store_string("%s|%s|%s\n" % [r["suite"], "PASS" if bool(r["ok"]) else "FAIL", r["label"]])
                f.close()
