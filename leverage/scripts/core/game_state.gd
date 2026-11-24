extends Node
## GameState - authoritative runtime state of the player, economy, world and story.
## All persistent values live here. Saved/loaded via SaveSystem (JSON snapshot).

const FACTIONS := ["family", "kestrel", "vetch", "police", "community"]

# ---- Player ----
var player_name := "Dez Carter"
var money: int = 250
var health: float = 100.0
var max_health: float = 100.0
var armor: float = 0.0
var max_armor: float = 100.0
var stamina: float = 100.0
var max_stamina: float = 100.0
var current_discipline := "brawler"
var unlocked_disciplines: Array = ["brawler"]
var equipped_weapon := "fists"
var equipped_outfit := "default"

# ---- Crime state ----
var wanted_level := 0            # 0..5 stars
var heat: float = 0.0            # 0..100 area heat, decays over time
var crimes_committed: int = 0

# ---- Reputation ----
# faction_id -> -100..100
var reputation := {
        "family": 10.0,
        "kestrel": 0.0,
        "vetch": 0.0,
        "police": 0.0,
        "community": 5.0,
}

# ---- Inventory / economy ----
# item_id -> count
var inventory := {}
var weapons_owned: Array = ["fists"]
var outfits_owned: Array = ["default", "jacket", "suit", "workwear", "street"]
var shop_prices: Dictionary = {}

# ---- Progression ----
var discipline_xp := {"brawler": 0, "kickboxing": 0, "grappling": 0, "drunken": 0, "weapon": 0}
var player_stats := {
        "missions_completed": 0,
        "fights_won": 0,
        "distance_walked": 0.0,
        "distance_driven": 0.0,
        "money_earned": 0,
        "money_spent": 0,
        "collectibles_found": 0,
        "side_jobs_done": 0,
        "vehicles_jacked": 0,
        "times_busted": 0,
        "encounters_won": 0,
        "encounters_seen": 0,
        "gold_medals": 0,
        "mission_medals": {},
}
var achievements: Dictionary = {}
var collectibles_found: Dictionary = {}

# ---- World / story persistence ----
var story_flags := {}                # "chapter": 1, "tommy_rescued": false...
var missions_state := {}             # mission_id -> {status, objectives[]}
var npc_relationships := {}          # npc_id -> -100..100
var npc_memory := {}                 # npc_id -> {event_key: weight}
var world_event_log: Array = []      # recent events remembered by the world
var visited_areas: Dictionary = {}
var discovered_locations: Dictionary = {}
var phone_messages: Array = []       # {from, text, time, read}
var phone_threads := {}               # from_id -> [{mine, text, hour, read}]
var phone_call_log: Array = []       # {from, outcome, time}
var gps_waypoint := Vector2.ZERO     # world-space GPS destination (map sets it)
var has_gps := false
var contacts: Array = []
var radio_station := "cinder_fm"
var playtime_seconds: float = 0.0
var current_area := "old_quarter"

# ---- Session (not saved) ----
var in_vehicle: bool = false
var in_combat: bool = false
var in_cinematic: bool = false
var in_interior: String = ""


func reputation_for(faction: String) -> float:
        return reputation.get(faction, 0.0)


func add_reputation(faction: String, delta: float) -> void:
        var old: float = reputation.get(faction, 0.0)
        reputation[faction] = clamp(old + delta, -100.0, 100.0)
        EventBus.reputation_changed.emit(faction, reputation[faction])


func relationship_for(npc_id: String) -> float:
        return npc_relationships.get(npc_id, 0.0)


func change_relationship(npc_id: String, delta: float) -> void:
        var old: float = npc_relationships.get(npc_id, 0.0)
        npc_relationships[npc_id] = clamp(old + delta, -100.0, 100.0)
        EventBus.npc_relationship_changed.emit(npc_id, npc_relationships[npc_id])


func add_money(amount: int) -> void:
        money += amount
        if amount > 0:
                player_stats["money_earned"] += amount
        else:
                player_stats["money_spent"] += -amount
        EventBus.player_money_changed.emit(money)


func add_discipline_xp(discipline_id: String, amount: int) -> void:
        if not discipline_xp.has(discipline_id):
                discipline_xp[discipline_id] = 0
        discipline_xp[discipline_id] += amount
        # Unlock milestones: new disciplines unlock through story + training.
        if discipline_xp[discipline_id] >= 100 and not unlocked_disciplines.has(discipline_id):
                if _discipline_unlockable(discipline_id):
                        unlocked_disciplines.append(discipline_id)
                        EventBus.notification_posted.emit("New discipline unlocked: %s" % discipline_id.capitalize(), "unlock")


func _discipline_unlockable(discipline_id: String) -> bool:
        # Kickboxing from Big Theo (gym), grappling from gym tier 2, drunken from Marisol's bar arc,
        # weapon discipline when first firearm is acquired.
        match discipline_id:
                "kickboxing": return story_flags.get("met_big_theo", false)
                "grappling": return story_flags.get("gym_training_2", false)
                "drunken": return story_flags.get("bar_story_arc", false)
                "weapon": return weapons_owned.size() > 1
        return false


func set_story_flag(flag: String, value) -> void:
        story_flags[flag] = value
        EventBus.story_flag_set.emit(flag, value)


func story_flag(flag: String, default_value = null):
        return story_flags.get(flag, default_value)


func remember_npc_event(npc_id: String, event_key: String, weight: float = 1.0) -> void:
        if not npc_memory.has(npc_id):
                npc_memory[npc_id] = {}
        var mem: Dictionary = npc_memory[npc_id]
        mem[event_key] = max(float(mem.get(event_key, 0.0)), weight)
        EventBus.npc_memorable_event.emit(npc_id, event_key, weight)


func npc_remembered(npc_id: String, event_key: String) -> bool:
        return npc_memory.has(npc_id) and npc_memory[npc_id].has(event_key)


func add_item(item_id: String, count: int = 1) -> void:
        inventory[item_id] = int(inventory.get(item_id, 0)) + count
        EventBus.item_acquired.emit(item_id, count)


func has_item(item_id: String) -> bool:
        return int(inventory.get(item_id, 0)) > 0


func track_stat(stat: String, amount: float = 1.0) -> void:
        player_stats[stat] = float(player_stats.get(stat, 0.0)) + amount
        EventBus.player_stat_tracked.emit(stat, amount)


func unlock_achievement(id: String) -> void:
        if not achievements.has(id):
                achievements[id] = true
                EventBus.achievement_unlocked.emit(id)


func snapshot() -> Dictionary:
        """Full serializable snapshot of game state."""
        return {
                "version": 3,
                "player_name": player_name,
                "money": money,
                "health": health,
                "armor": armor,
                "current_discipline": current_discipline,
                "unlocked_disciplines": unlocked_disciplines.duplicate(),
                "equipped_weapon": equipped_weapon,
                "equipped_outfit": equipped_outfit,
                "wanted_level": wanted_level,
                "heat": heat,
                "crimes_committed": crimes_committed,
                "reputation": reputation.duplicate(true),
                "inventory": inventory.duplicate(true),
                "weapons_owned": weapons_owned.duplicate(),
                "outfits_owned": outfits_owned.duplicate(),
                "discipline_xp": discipline_xp.duplicate(true),
                "player_stats": player_stats.duplicate(true),
                "achievements": achievements.duplicate(true),
                "collectibles_found": collectibles_found.duplicate(true),
                "story_flags": story_flags.duplicate(true),
                "missions_state": missions_state.duplicate(true),
                "npc_relationships": npc_relationships.duplicate(true),
                "npc_memory": npc_memory.duplicate(true),
                "world_event_log": world_event_log.duplicate(true),
                "visited_areas": visited_areas.duplicate(true),
                "discovered_locations": discovered_locations.duplicate(true),
                "phone_messages": phone_messages.duplicate(true),
                "phone_threads": phone_threads.duplicate(true),
                "phone_call_log": phone_call_log.duplicate(true),
                "contacts": contacts.duplicate(true),
                "radio_station": radio_station,
                "playtime_seconds": playtime_seconds,
                "current_area": current_area,
        }


func restore(data: Dictionary) -> void:
        player_name = data.get("player_name", "Dez Carter")
        money = int(data.get("money", 250))
        health = float(data.get("health", 100.0))
        armor = float(data.get("armor", 0.0))
        current_discipline = data.get("current_discipline", "brawler")
        unlocked_disciplines = data.get("unlocked_disciplines", ["brawler"])
        equipped_weapon = data.get("equipped_weapon", "fists")
        equipped_outfit = data.get("equipped_outfit", "default")
        wanted_level = int(data.get("wanted_level", 0))
        heat = float(data.get("heat", 0.0))
        crimes_committed = int(data.get("crimes_committed", 0))
        reputation = data.get("reputation", reputation)
        inventory = data.get("inventory", {})
        weapons_owned = data.get("weapons_owned", ["fists"])
        outfits_owned = data.get("outfits_owned", ["default", "jacket", "suit", "workwear", "street"])
        discipline_xp = data.get("discipline_xp", discipline_xp)
        player_stats = data.get("player_stats", player_stats)
        achievements = data.get("achievements", {})
        collectibles_found = data.get("collectibles_found", {})
        story_flags = data.get("story_flags", {})
        missions_state = data.get("missions_state", {})
        npc_relationships = data.get("npc_relationships", {})
        npc_memory = data.get("npc_memory", {})
        world_event_log = data.get("world_event_log", [])
        visited_areas = data.get("visited_areas", {})
        discovered_locations = data.get("discovered_locations", {})
        phone_messages = data.get("phone_messages", [])
        phone_threads = data.get("phone_threads", {})
        phone_call_log = data.get("phone_call_log", [])
        contacts = data.get("contacts", [])
        radio_station = data.get("radio_station", "cinder_fm")
        playtime_seconds = float(data.get("playtime_seconds", 0.0))
        current_area = data.get("current_area", "old_quarter")


func reset_for_new_game() -> void:
        """Authoritative new-game defaults."""
        player_name = "Dez Carter"
        money = 250
        health = 100.0
        armor = 0.0
        stamina = 100.0
        current_discipline = "brawler"
        unlocked_disciplines = ["brawler"]
        equipped_weapon = "fists"
        equipped_outfit = "default"
        wanted_level = 0
        heat = 0.0
        crimes_committed = 0
        reputation = {"family": 10.0, "kestrel": 0.0, "vetch": 0.0, "police": 0.0, "community": 5.0}
        inventory = {}
        weapons_owned = ["fists"]
        outfits_owned = ["default", "jacket", "suit", "workwear", "street"]
        discipline_xp = {"brawler": 0, "kickboxing": 0, "grappling": 0, "drunken": 0, "weapon": 0}
        player_stats = {
                "missions_completed": 0, "fights_won": 0, "distance_walked": 0.0,
                "distance_driven": 0.0, "money_earned": 0, "money_spent": 0,
                "collectibles_found": 0, "side_jobs_done": 0, "vehicles_jacked": 0, "times_busted": 0,
                "encounters_won": 0, "encounters_seen": 0, "gold_medals": 0, "mission_medals": {},
        }
        achievements = {}
        collectibles_found = {}
        story_flags = {"chapter": 1}
        missions_state = {}
        npc_relationships = {}
        npc_memory = {}
        world_event_log = []
        visited_areas = {}
        discovered_locations = {}
        phone_messages = []
        contacts = []
        radio_station = "cinder_fm"
        playtime_seconds = 0.0
        current_area = "old_quarter"
        in_vehicle = false
        in_combat = false
        in_interior = ""
