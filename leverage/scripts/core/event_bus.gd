extends Node
## EventBus - central signal hub for cross-system communication.
## All systems talk through here; no direct coupling between directors.

# --- Game flow ---
signal game_booted
signal game_started(new_game: bool)
signal game_paused(paused: bool)
signal game_over(reason: String)
signal game_ended(ending_id: String)
signal scene_transition_requested(scene_id: String)

# --- Player ---
signal player_spawned(player: Node)
signal player_died
signal player_health_changed(hp: float, max_hp: float)
signal player_armor_changed(armor: float, max_armor: float)
signal player_stamina_changed(stamina: float, max_stamina: float)
signal player_money_changed(money: int)
signal reputation_changed(faction: String, value: float)
signal player_wanted_changed(wanted_level: int)
signal player_heat_changed(heat: float)
signal player_discipline_changed(discipline_id: String)
signal player_weapon_changed(weapon_id: String, ammo: int, reserve: int)
signal player_entered_vehicle(vehicle: Node)
signal player_exited_vehicle
signal player_arrested
signal player_stat_tracked(stat: String, amount: float)

# --- Combat ---
signal combat_started
signal combat_ended
signal hit_landed(attacker: Node, victim: Node, damage: float, kind: String)
signal hit_blocked(attacker: Node, victim: Node)
signal enemy_downed(enemy: Node)
signal combo_progressed(count: int, discipline_id: String)
signal counter_performed(attacker: Node, victim: Node)
signal dodge_performed(player: Node)

# --- Crime / police ---
signal crime_committed(crime_type: String, position: Vector3, severity: float, witnesses: Array)
signal police_alerted(level: int, position: Vector3)
signal police_lost_target
signal roadblock_spawned(position: Vector3)

# --- World ---
signal area_entered(area_id: String)
signal area_exited(area_id: String)
signal time_hour_changed(hour: int)
signal weather_changed(weather_id: String)
signal world_event_started(event_id: String, area_id: String)
signal world_event_ended(event_id: String)

# --- NPCs ---
signal npc_spawned(npc: Node)
signal npc_removed(npc: Node)
signal npc_memorable_event(npc_id: String, event_key: String, weight: float)
signal npc_relationship_changed(npc_id: String, delta: float)
signal dialogue_started(npc_id: String)
signal dialogue_ended(npc_id: String)
signal dialogue_choice_made(choice_id: String, tags: Dictionary)

# --- Missions / story ---
signal mission_started(mission_id: String)
signal mission_objective_completed(mission_id: String, objective_index: int)
signal mission_failed(mission_id: String, reason: String)
signal mission_completed(mission_id: String)
signal story_flag_set(flag: String, value)
signal story_beat_reached(beat_id: String)
signal choice_made(choice_id: String, consequence: Dictionary)

# --- Economy / inventory ---
signal item_purchased(item_id: String, price: int)
signal item_acquired(item_id: String, count: int)
signal item_used(item_id: String)
signal item_equipped(item_id: String)
signal outfit_changed(outfit_id: String)
signal shop_opened(shop_id: String)
signal collectible_found(collectible_id: String)

# --- UI ---
signal notification_posted(text: String, kind: String)
signal objective_displayed(title: String, description: String)
signal subtitle_show(text: String, speaker: String, duration: float)
signal subtitle_hide
signal phone_received_message(from_name: String, message: String)
signal phone_call_received(contact_id: String)
signal achievement_unlocked(achievement_id: String)
signal radio_station_changed(station_id: String)
signal settings_changed(section: String)

# --- Audio ---
signal music_layer_requested(mood: String)
signal ambience_area_changed(area_id: String)
signal sfx_requested(sfx_id: String, position: Vector3)

# --- Save system ---
signal save_completed(slot: int)
signal load_completed(slot: int)

# --- Testing hooks (used by headless test harness; harmless in release) ---
signal test_event(event_name: String, data)
