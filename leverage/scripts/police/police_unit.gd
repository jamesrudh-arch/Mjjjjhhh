class_name PoliceUnit
extends Combatant
## PoliceUnit - patrol officer / cruiser crew. Escalates with wanted level:
## approach, billy strikes at low levels, gunfire at 3+, arrest at range when
## player health low. Uses combat AI from Combatant with faction police.

const ARREST_HEALTH_THRESHOLD := 25.0
const GUN_AT_LEVEL := 3


func _init() -> void:
        # defaults overridden by setup()
        pass


func setup_police(unit_kind: String, level: int) -> void:
        faction = "police"
        is_hostile_to_player = true
        display_name = "Cinder City PD"
        var hp := 70.0 + 20.0 * level
        var dmg := 7.0 + 2.0 * level
        if level >= GUN_AT_LEVEL:
            dmg += 6.0
        setup("", "police", "Officer " + ("Patrol" if level < 2 else "Tactical"), hp, dmg, "brawler")
        # police visual: blue tint + cap
        if actor:
                var body_mat := StandardMaterial3D.new()
                body_mat.albedo_color = Color("2a4fb6")
                var mi := _find_type(actor, "MeshInstance3D") as MeshInstance3D
                if mi:
                        mi.set_surface_override_material(0, body_mat)
        if level >= 4:
                CharacterFactory.attach_accessory(actor, "cap", Color("1a2a66"))


func _find_type(node: Node, type: String) -> Node:
        if node.get_class() == type:
                return node
        for c in node.get_children():
                var r := _find_type(c, type)
                if r:
                        return r
        return null


func _tick_attack(delta: float) -> void:
        # arrest attempt when player weak
        var player := get_tree().get_first_node_in_group("player")
        if player is PlayerController:
                var pc := player as PlayerController
                var dist: float = global_position.distance_to(pc.global_position)
                if dist < 2.2 and GameState.health < ARREST_HEALTH_THRESHOLD and GameState.wanted_level >= 1:
                        PoliceSystem.arrest_player()
                        return
        super._tick_attack(delta)


## Police murder escalation: killing police bumps heat harder.
func die(attacker: Node) -> void:
        super.die(attacker)
        if attacker is PlayerController:
                EventBus.crime_committed.emit("murder", global_position, 70.0, NPCDirector.witnesses_of(global_position))
                GameState.add_reputation("police", -8.0)
