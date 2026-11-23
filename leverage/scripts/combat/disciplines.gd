class_name Discipline
extends RefCounted
## Discipline data tables for the five combat disciplines.
## AttackDef fields: anim, damage, startup/active/recover (seconds at 1.0 rate),
## stamina, reach (m), knockback, stagger, combo window, next-in-chain.
## Fixed button mapping: X=punch, Y=heavy, A=kick, B=dodge (never remapped).

const ALL := {
        "brawler": {
                "display": "Brawler",
                "idle": "Guard_Idle",
                "punch_chain": ["Punch_Jab", "Punch_Cross", "Punch_Jab"],
                "kick_chain": ["Kick_Front", "Kick_Push"],
                "heavy": {"anim": "Sword_Attack", "damage": 26.0, "startup": 0.34, "active": 0.16, "recover": 0.5,
                        "stamina": 22.0, "reach": 1.5, "knockback": 5.0, "stagger": 1.0},
                "dodge": "Roll",
                "counter": "Counter_Trip",
                "counter_damage_mult": 1.6,
                "dodge_invuln": 0.34,
                "passive": {"drift": 0.0},
                "unlock_hint": "Default discipline.",
        },
        "kickboxing": {
                "display": "Kickboxing",
                "idle": "Guard_Idle",
                "punch_chain": ["Punch_Jab", "Punch_Jab"],
                "kick_chain": ["Kick_Push", "Kick_Round", "Kick_Front"],
                "heavy": {"anim": "Kick_Round", "damage": 30.0, "startup": 0.30, "active": 0.18, "recover": 0.44,
                        "stamina": 26.0, "reach": 1.9, "knockback": 6.5, "stagger": 1.2},
                "dodge": "Roll",
                "counter": "Counter_Trip",
                "counter_damage_mult": 1.7,
                "dodge_invuln": 0.36,
                "passive": {"kick_damage_mult": 1.25, "push_kick_force": 8.0},
                "unlock_hint": "Train with Big Theo at Iron Gym.",
        },
        "grappling": {
                "display": "Grappling",
                "idle": "Guard_Idle",
                "punch_chain": ["Punch_Jab"],
                "kick_chain": ["Kick_Front"],
                "heavy": {"anim": "Grapple_Grab", "damage": 10.0, "startup": 0.26, "active": 0.2, "recover": 0.3,
                        "stamina": 18.0, "reach": 1.4, "knockback": 0.0, "stagger": 0.4, "grabs": true},
                "dodge": "Roll",
                "counter": "Counter_Trip",
                "counter_damage_mult": 2.4,
                "dodge_invuln": 0.3,
                "passive": {"throw_chain": "Grapple_Throw", "throw_damage": 48.0, "counter_master": true},
                "unlock_hint": "Big Theo, gym tier 2.",
        },
        "drunken": {
                "display": "Drunken",
                "idle": "Drunken_Idle",
                "punch_chain": ["Punch_Cross", "Drunken_Swing"],
                "kick_chain": ["Kick_Front"],
                "heavy": {"anim": "Drunken_Swing", "damage": 38.0, "startup": 0.42, "active": 0.2, "recover": 0.62,
                        "stamina": 34.0, "reach": 1.6, "knockback": 7.0, "stagger": 1.4},
                "dodge": "Drunken_Sway",
                "counter": "Counter_Trip",
                "counter_damage_mult": 1.5,
                "dodge_invuln": 0.3,
                "passive": {"auto_dodge_chance": 0.22, "wild_damage_variance": 0.4},
                "unlock_hint": "Marisol's bar arc.",
        },
        "weapon": {
                "display": "Weapon",
                "idle": "Pistol_Idle",
                "punch_chain": ["Punch_Jab", "Pistol_Shoot"],
                "kick_chain": ["Kick_Front"],
                "heavy": {"anim": "Sword_Attack", "damage": 32.0, "startup": 0.3, "active": 0.16, "recover": 0.46,
                        "stamina": 20.0, "reach": 1.7, "knockback": 5.5, "stagger": 1.1},
                "dodge": "Roll",
                "counter": "Counter_Trip",
                "counter_damage_mult": 1.6,
                "dodge_invuln": 0.34,
                "passive": {"aimed": true},
                "unlock_hint": "Acquire your first firearm.",
        },
}

## Light-attack (punch) stats per chain step; kicks per chain step.
const PUNCH_DAMAGE := 9.0
const KICK_DAMAGE := 13.0
const PUNCH_REACH := 1.35
const KICK_REACH := 1.75
const PUNCH_STAMINA := 6.0
const KICK_STAMINA := 10.0


static func def(id: String) -> Dictionary:
        return ALL.get(id, ALL["brawler"])


static func punch_stats(step: int, disc_id: String) -> Dictionary:
        var dmg := PUNCH_DAMAGE + float(step) * 2.0
        var d := def(disc_id)
        if disc_id == "kickboxing":
                dmg *= 1.05
        return {"anim": String(d["punch_chain"][clamp(step, 0, (d["punch_chain"] as Array).size() - 1)]),
                "damage": dmg, "startup": 0.14, "active": 0.1, "recover": 0.18,
                "stamina": PUNCH_STAMINA, "reach": PUNCH_REACH, "knockback": 2.2, "stagger": 0.5}


static func kick_stats(step: int, disc_id: String) -> Dictionary:
        var d := def(disc_id)
        var mult := 1.0
        if disc_id == "kickboxing":
                mult = float(d["passive"].get("kick_damage_mult", 1.0))
        return {"anim": String(d["kick_chain"][clamp(step, 0, (d["kick_chain"] as Array).size() - 1)]),
                "damage": KICK_DAMAGE * mult + float(step) * 3.0, "startup": 0.2, "active": 0.14, "recover": 0.26,
                "stamina": KICK_STAMINA, "reach": KICK_REACH, "knockback": 4.0 + float(step), "stagger": 0.8}


static func chain_length(disc_id: String, kind: String) -> int:
        var d := def(disc_id)
        return (d.get(kind + "_chain", []) as Array).size()


static func display_name(id: String) -> String:
        return String(def(id).get("display", id.capitalize()))
