class_name WeaponSystem
extends Node
## WeaponSystem - player weapons: definitions, equipping (visual on hand),
## ammo, aim/fire (raycast from camera), reload, switching, armor items.
## Weapon discipline engages when a firearm is drawn.

const WEAPONS := {
        "fists": {"display": "Bare Hands", "kind": "melee", "damage": 0.0, "anim_set": "none"},
        "pistol": {"display": "P9 Sidearm", "kind": "firearm", "glb": "res://assets/weapons/pistol.glb",
                "damage": 24.0, "mag": 12, "reserve_max": 96, "rate": 0.32, "spread": 0.6, "auto": false},
        "pistol2": {"display": "Kalvin Compact", "kind": "firearm", "glb": "res://assets/weapons/pistol2.glb",
                "damage": 28.0, "mag": 8, "reserve_max": 64, "rate": 0.36, "spread": 0.5, "auto": false},
        "smg": {"display": "Vetch Ripper", "kind": "firearm", "glb": "res://assets/weapons/smg.glb",
                "damage": 14.0, "mag": 30, "reserve_max": 150, "rate": 0.11, "spread": 1.4, "auto": true},
        "rifle": {"display": "Long Ledger", "kind": "firearm", "glb": "res://assets/weapons/rifle.glb",
                "damage": 42.0, "mag": 10, "reserve_max": 60, "rate": 0.5, "spread": 0.3, "auto": false},
        "baton": {"display": "Repo Baton", "kind": "melee", "damage": 18.0, "anim_set": "none"},
}

const AMMO_ITEMS := {
        "pistol": "ammo_pistol",
        "pistol2": "ammo_pistol",
        "smg": "ammo_smg",
        "rifle": "ammo_rifle",
}

const ARMOR_ITEMS := {
        "vest": {"display": "Street Vest", "armor": 40.0, "price": 300},
        "kevlar": {"display": "Kestrel Kevlar", "armor": 100.0, "price": 750},
}

var player: PlayerController
var equipped := "fists"
var drawn := false                       # firearm holstered/drawn
var mag := 0
var reserve := 0
var _fire_cd := 0.0
var _hand_item: Node3D = null
var _combat: CombatPlayer


func _ready() -> void:
        player = get_parent() as PlayerController
        if player:
                _combat = player._combat
        equip(GameState.equipped_weapon, false)


func _process(delta: float) -> void:
        _fire_cd = max(0.0, _fire_cd - delta)


func weapon_def(id: String) -> Dictionary:
        return WEAPONS.get(id, WEAPONS["fists"])


func equip(id: String, notify := true) -> void:
        if not WEAPONS.has(id) or not GameState.weapons_owned.has(id):
                id = "fists"
        equipped = id
        GameState.equipped_weapon = id
        var def := weapon_def(id)
        mag = int(def.get("mag", 0))
        reserve = int(def.get("reserve_max", 0))
        _refresh_hand_item()
        if notify:
                EventBus.player_weapon_changed.emit(id, mag, reserve)
                EventBus.notification_posted.emit("Equipped: " + String(def["display"]), "weapon")


func _refresh_hand_item() -> void:
        if _hand_item != null and is_instance_valid(_hand_item):
                _hand_item.queue_free()
        _hand_item = null
        var def := weapon_def(equipped)
        if String(def.get("kind", "melee")) != "firearm":
                if equipped == "baton":
                        var box := BoxMesh.new()
                        box.size = Vector3(0.06, 0.55, 0.06)
                        _hand_item = CharacterFactory.attach_to_hand(player.actor, box, Vector3(0.06, 0.1, 0.06))
                return
        var glb: String = String(def.get("glb", ""))
        if glb != "" and ResourceLoader.exists(glb):
                var packed: PackedScene = load(glb)
                if packed != null:
                        var inst: Node3D = packed.instantiate()
                        inst.scale = Vector3.ONE * 0.85
                        inst.rotation_degrees = Vector3(0, 90, 0)
                        _hand_item = inst
                        var sk := player.get_node_or_null("Actor/Skeleton3D") as Node
                        # find skeleton inside actor
                        var skel := _find_skeleton(player.actor)
                        if skel:
                                skel.add_child(inst)
                        _attach_to_bone(inst, "DEF-hand.R")


func _find_skeleton(node: Node) -> Skeleton3D:
        if node.get_class() == "Skeleton3D":
                return node
        for c in node.get_children():
                var r := _find_skeleton(c)
                if r:
                        return r
        return null


func _attach_to_bone(item: Node3D, bone: String) -> void:
        var skel := _find_skeleton(player.actor)
        if skel == null:
                return
        var att := BoneAttachment3D.new()
        att.bone_name = bone
        skel.add_child(att)
        item.reparent(att)
        item.position = Vector3(0.05, 0.02, 0.05)


## Draw / holster (action Y outside combat).
func toggle_draw() -> void:
        var def := weapon_def(equipped)
        if String(def.get("kind", "melee")) != "firearm":
                return
        drawn = not drawn
        if drawn:
                if not GameState.unlocked_disciplines.has("weapon"):
                        GameState.unlocked_disciplines.append("weapon")
                        EventBus.player_discipline_changed.emit("weapon")
                GameState.current_discipline = "weapon"
                EventBus.player_discipline_changed.emit("weapon")
                _combat.set_aiming(true)
                EventBus.player_weapon_changed.emit(equipped, mag, reserve)
        else:
                GameState.current_discipline = "brawler"
                EventBus.player_discipline_changed.emit("brawler")
                _combat.set_aiming(false)


func try_fire(camera: Camera3D) -> void:
        var def := weapon_def(equipped)
        if String(def.get("kind", "")) != "firearm" or not drawn:
                return
        if _fire_cd > 0.0 or mag <= 0:
                return
        _fire_cd = float(def.get("rate", 0.3))
        mag -= 1
        player.play_anim_forced("Pistol_Shoot")
        EventBus.sfx_requested.emit("sfx_gunshot", player.global_position)
        EventBus.player_weapon_changed.emit(equipped, mag, reserve)
        # raycast from camera through center
        var from: Vector3 = camera.global_position
        var fwd := -camera.global_transform.basis.z
        var spread: float = float(def.get("spread", 0.5)) * 0.01
        fwd = fwd.rotated(Vector3.UP, randf_range(-spread, spread))
        var to: Vector3 = from + fwd * 60.0
        var params := PhysicsRayQueryParameters3D.create(from, to, 1 | 8 | 4)
        params.exclude = [player.get_rid()]
        var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(params)
        if hit.has("collider"):
                var node := hit["collider"] as Node
                if node.has_method("take_hit") and node is Combatant:
                        var mult := 1.0
                        if node.faction == "community" and (node as Combatant).npc_id != "":
                                mult = 1.0
                        (node as Combatant).take_hit(float(def.get("damage", 20.0)) * mult, player, 2.0, 0.4, "gunshot")
                        EventBus.crime_committed.emit("weapon_fire", player.global_position,
                                PoliceSystem.crime_severity("weapon_fire"), NPCDirector.witnesses_of(player.global_position))
                elif node is VehicleBody3D:
                        EventBus.crime_committed.emit("property_damage", player.global_position, 6.0, [])
                elif node.has_meta("explosive"):
                        EventBus.explosive_damaged.emit(node, float(def.get("damage", 20.0)), player)
                        EventBus.crime_committed.emit("property_damage", player.global_position, 6.0, [])
                EventBus.sfx_requested.emit("sfx_bullet_impact", (hit["position"] as Vector3))
        if mag == 0:
                EventBus.notification_posted.emit("Magazine empty - reload", "warn")


func try_reload() -> void:
        var def := weapon_def(equipped)
        if String(def.get("kind", "")) != "firearm" or not drawn:
                return
        if mag >= int(def.get("mag", 8)) or reserve <= 0:
                return
        player.play_anim_forced("Pistol_Reload")
        var need: int = int(def.get("mag", 8)) - mag
        var take: int = min(need, reserve)
        await get_tree().create_timer(1.2).timeout
        mag += take
        reserve -= take
        EventBus.player_weapon_changed.emit(equipped, mag, reserve)
        EventBus.sfx_requested.emit("sfx_reload", player.global_position)


func next_weapon() -> void:
        var owned: Array = GameState.weapons_owned
        if owned.size() < 2:
                return
        var idx: int = owned.find(equipped)
        idx = (idx + 1) % owned.size()
        equip(owned[idx])


func prev_weapon() -> void:
        var owned: Array = GameState.weapons_owned
        if owned.size() < 2:
                return
        var idx: int = owned.find(equipped)
        idx = (idx - 1 + owned.size()) % owned.size()
        equip(owned[idx])


func add_ammo(item_id: String, count: int) -> void:
        for wid in AMMO_ITEMS.keys():
                if AMMO_ITEMS[wid] == item_id and wid == equipped:
                        reserve = min(int(weapon_def(wid).get("reserve_max", 60)), reserve + count)
                        EventBus.player_weapon_changed.emit(equipped, mag, reserve)
                        return
        GameState.add_item(item_id, count)


func apply_armor(item_id: String) -> bool:
        if not ARMOR_ITEMS.has(item_id):
                return false
        GameState.armor = min(GameState.max_armor, float(ARMOR_ITEMS[item_id]["armor"]))
        EventBus.player_armor_changed.emit(GameState.armor, GameState.max_armor)
        return true
