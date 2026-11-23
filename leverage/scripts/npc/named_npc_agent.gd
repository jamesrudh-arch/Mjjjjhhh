class_name NamedNpcAgent
extends Combatant
## NamedNpcAgent - visual agent for the 16-character story cast. Talk via
## DialogueSystem; becomes hostile only if the player attacks them.


func setup_npc(npc_id: String) -> void:
        var d := 55.0
        var dmg := 7.0
        var disc := "brawler"
        match npc_id:
                "big_theo": d = 110.0; dmg = 14.0; disc = "kickboxing"
                "lucy_fang": d = 140.0; dmg = 16.0; disc = "kickboxing"
                "vito": d = 100.0; dmg = 12.0
                "ren": d = 95.0; dmg = 13.0
                "rizzo": d = 80.0; dmg = 10.0
                "officer_brant", "sergeant_oduya": d = 90.0; dmg = 11.0; disc = "weapon"
                _: pass
        setup(npc_id, "community", NPCDirector.cast_display(npc_id), d, dmg, disc)
        is_hostile_to_player = false
        add_to_group("interactable")
        set_meta("interact_text", "Talk to " + NPCDirector.cast_display(npc_id))
        set_meta("npc_id", npc_id)
        _greeting_cd = 0.0


var _greeting_cd := 0.0


func interact(player_node: Node) -> void:
        if DialogueSystem.has_dialogue(npc_id):
                DialogueSystem.start(npc_id, {"player": player_node})
                GameState.remember_npc_event(npc_id, "talked_with_dez", 1.0)
        else:
                EventBus.subtitle_show.emit(NPCDirector.greeting_for(npc_id), NPCDirector.cast_display(npc_id), 3.0)
                MissionSystem.notify_talked(npc_id)


## Named NPCs stay near their anchor when idle (don't wander far).
func _tick_chase(delta: float) -> void:
        if not aggro:
                return
        super._tick_chase(delta)


## Attacking a named NPC makes them hostile (and remembered).
func take_hit(damage: float, attacker: Node, knockback: float, stagger: float, kind := "melee") -> void:
        if attacker is PlayerController and not aggro:
                aggro = true
                is_hostile_to_player = true
                GameState.change_relationship(npc_id, -15.0)
                GameState.remember_npc_event(npc_id, "attacked_by_dez", 2.0)
                EventBus.notification_posted.emit(NPCDirector.cast_display(npc_id) + " turns on you!", "warn")
        super.take_hit(damage, attacker, knockback, stagger, kind)
