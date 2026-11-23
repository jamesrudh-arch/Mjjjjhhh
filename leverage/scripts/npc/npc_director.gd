extends Node
## NPCDirector - named-cast simulation + pedestrian population planning.
## Pure logic/simulation layer (works headless). The world scene creates
## visual agents and syncs them from this director every tick.
## Cast of 16 named characters (3 virtual: dez/player, tommy/hostage until
## rescue, the_tipster/phone-only) - see docs/characters_story.md.

const CAST := {
        "dez": {"display": "Dez Carter", "spawnable": false, "role": "player"},
        "tommy": {"display": "Tommy Carter", "spawnable": false, "role": "hostage",
                "area": "docklands"},
        "the_tipster": {"display": "The Tipster", "spawnable": false, "role": "phone"},
        "marisol": {"display": "Marisol Vega", "spawnable": true,
                "role": "bar owner", "district": "old_quarter",
                "home": Vector3(-330, 0, -240), "work": Vector3(-240, 0, -180), "evening": Vector3(-240, 0, -180),
                "tint": Color("c85a4a"), "hair": "bun", "discipline": "drunken"},
        "big_theo": {"display": "Big Theo Okonjo", "spawnable": true,
                "role": "gym owner", "district": "ironworks",
                "home": Vector3(-300, 0, 520), "work": Vector3(-200, 0, 560), "evening": Vector3(-240, 0, -180),
                "tint": Color("8a6a3a"), "hat": "cap", "discipline": "kickboxing"},
        "vito": {"display": "Vito \"Ledger\" Castellane", "spawnable": true,
                "role": "Family boss", "district": "heights",
                "home": Vector3(120, 0, -620), "work": Vector3(120, 0, -620), "evening": Vector3(120, 0, -620),
                "tint": Color("3a3a4a"), "hat": "fedora", "body": "suit"},
        "rizzo": {"display": "Rizzo Bell", "spawnable": true,
                "role": "Family lieutenant", "district": "old_quarter",
                "home": Vector3(-180, 0, -120), "work": Vector3(-120, 0, -60), "evening": Vector3(-240, 0, -180),
                "tint": Color("6a4a5a"), "hat": "flatcap"},
        "ava": {"display": "Ava Kestrel", "spawnable": true,
                "role": "Kestrel executive", "district": "kestrel_district",
                "home": Vector3(300, 0, -320), "work": Vector3(240, 0, -200), "evening": Vector3(320, 0, 200),
                "tint": Color("4a5a7a"), "body": "suit"},
        "ren": {"display": "Ren Vetch", "spawnable": true,
                "role": "Vetch Crew boss", "district": "docklands",
                "home": Vector3(-380, 0, 300), "work": Vector3(-360, 0, 220), "evening": Vector3(-360, 0, 220),
                "tint": Color("5a5a3a"), "hat": "hoodie"},
        "lucy_fang": {"display": "Lucy Fang", "spawnable": true,
                "role": "Vetch enforcer", "district": "docklands",
                "home": Vector3(-360, 0, 340), "work": Vector3(-300, 0, 260), "evening": Vector3(320, 0, 200),
                "tint": Color("8a3a5a"), "hair": "ponytail"},
        "officer_brant": {"display": "Officer Brant", "spawnable": true,
                "role": "city police", "district": "old_quarter",
                "home": Vector3(-60, 0, -60), "work": Vector3(-10, 0, -10), "evening": Vector3(-60, 0, -60),
                "tint": Color("3b6fd6"), "body": "police"},
        "sergeant_oduya": {"display": "Sgt. Oduya", "spawnable": true,
                "role": "patrol sergeant", "district": "kestrel_district",
                "home": Vector3(200, 0, -120), "work": Vector3(10, 0, -10), "evening": Vector3(200, 0, -120),
                "tint": Color("2a4fb6"), "body": "police"},
        "doc_lennox": {"display": "Doc Lennox", "spawnable": true,
                "role": "clinic doctor", "district": "old_quarter",
                "home": Vector3(-150, 0, 30), "work": Vector3(-120, 0, 20), "evening": Vector3(-150, 0, 30),
                "tint": Color("d8d8d0"), "body": "coat"},
        "nadia": {"display": "Nadia Sorokin", "spawnable": true,
                "role": "pawn shop owner", "district": "old_quarter",
                "home": Vector3(-200, 0, -200), "work": Vector3(-260, 0, -80), "evening": Vector3(-240, 0, -180),
                "tint": Color("7a5a2a"), "hair": "bun"},
        "juno": {"display": "Juno Park", "spawnable": true,
                "role": "neighbor", "district": "old_quarter",
                "home": Vector3(-280, 0, -160), "work": Vector3(-160, 0, -120), "evening": Vector3(320, 0, 200),
                "tint": Color("4a7a6a"), "hair": "ponytail"},
        "cabbie_moses": {"display": "Moses Mabaso", "spawnable": true,
                "role": "taxi driver", "district": "all",
                "home": Vector3(-100, 0, 0), "work": Vector3(10, 0, -10), "evening": Vector3(10, 0, -10),
                "tint": Color("d8b83a"), "hat": "cap", "vehicle": "taxi"},
}

const FULL_RADIUS := 60.0        # full sim
const LITE_RADIUS := 150.0       # schedule-rail sim
const PEDESTRIAN_TARGET := 50    # visible ambient life around player (P1 pass; was 25)

## Named NPC runtime: id -> {pos, activity, route_from, route_to, route_t}
var _sim := {}
var _spawned_visuals := {}       # npc_id -> true (world registers visuals)
var _ped_plan: Array = []        # pending pedestrian spawn requests


func _ready() -> void:
        for id in CAST.keys():
                var c: Dictionary = CAST[id]
                if bool(c.get("spawnable", false)):
                        # start the day at the anchor correct for the current hour
                        # (game opens at 08:00 -> work anchor), so witnesses and
                        # proximity queries are valid from the first frame.
                        var start: Vector3 = _anchor_for(id, TimeWeather.hour())
                        _sim[id] = {"pos": start, "activity": "home",
                                "route_from": start, "route_to": start,
                                "route_t": 1.0, "moving": false}
        EventBus.time_hour_changed.connect(_on_hour_changed)


func _process(delta: float) -> void:
        _tick_named(delta)


func _on_hour_changed(_h: int) -> void:
        _reroute_all()


func _reroute_all() -> void:
        for id in _sim.keys():
                _reroute(id)


func _anchor_for(id: String, h: int) -> Vector3:
        var c: Dictionary = CAST.get(id, {})
        if h >= 7 and h < 18:
                return c.get("work", c.get("home", Vector3.ZERO))
        if h >= 18 and h < 23:
                return c.get("evening", c.get("home", Vector3.ZERO))
        return c.get("home", Vector3.ZERO)


func _reroute(id: String) -> void:
        var h := TimeWeather.hour()
        var target := _anchor_for(id, h)
        var s: Dictionary = _sim[id]
        if s["pos"].distance_to(target) > 2.0 and not s["moving"]:
                s["route_from"] = s["pos"]
                s["route_to"] = target
                s["route_t"] = 0.0
                s["moving"] = true


func _tick_named(delta: float) -> void:
        for id in _sim.keys():
                var s: Dictionary = _sim[id]
                if s["moving"]:
                        var speed: float = 1.6 / max(0.1, float(s["route_from"].distance_to(s["route_to"])))
                        s["route_t"] = min(1.0, float(s["route_t"]) + delta * speed)
                        s["pos"] = s["route_from"].lerp(s["route_to"], float(s["route_t"]))
                        if float(s["route_t"]) >= 1.0:
                                s["moving"] = false
                s["activity"] = _activity_label(id)


func _activity_label(id: String) -> String:
        var s: Dictionary = _sim.get(id, {})
        if bool(s.get("moving", false)):
                return "walking"
        var h := TimeWeather.hour()
        if h >= 7 and h < 18:
                return "work"
        if h >= 18 and h < 23:
                return "social"
        return "home"


## Which named NPCs should have visual agents near the player.
func named_visuals_needed(player_pos: Vector3) -> Array:
        var out: Array = []
        for id in _sim.keys():
                if player_pos.distance_to(_sim[id]["pos"]) <= FULL_RADIUS:
                        out.append(id)
        return out


func named_pos(id: String) -> Vector3:
        if _sim.has(id):
                return _sim[id]["pos"]
        var c: Dictionary = CAST.get(id, {})
        return c.get("home", Vector3.ZERO)


func named_activity(id: String) -> String:
        return String(_sim.get(id, {}).get("activity", "home"))


func cast_display(id: String) -> String:
        return String(CAST.get(id, {}).get("display", id))


func cast_meta(id: String, key: String, default_val = null):
        return CAST.get(id, {}).get(key, default_val)


## --- Pedestrian planning ---
## Returns desired pedestrian count for the player's current area/hour/weather.
func pedestrian_target_count(area_id: String) -> int:
        var base := 25
        if area_id == "":
                area_id = CityDirector.current_area
        var density: float = CityDirector.area_meta(area_id, "ped_density", 1.0)
        var night_mult: float = CityDirector.area_meta(area_id, "night_ped", 1.0)
        var mult := 1.0
        if TimeWeather.is_night():
                mult = night_mult
        mult *= 0.6 + 0.4 * TimeWeather.schedule_pressure()
        if TimeWeather.is_raining():
                mult *= 0.5
        mult *= 1.0 + WorldEvents.ped_density_modifier(area_id)
        var n := int(round(float(base) * density * mult))
        return clamp(n, 3, PEDESTRIAN_TARGET)


## Suggest a spawn position for one pedestrian around the player.
func pedestrian_spawn_point(player_pos: Vector3) -> Vector3:
        var ang := randf() * TAU
        var r := randf_range(35.0, 55.0)
        var p := player_pos + Vector3(cos(ang) * r, 0, sin(ang) * r)
        p.y = 0.0
        return p


## Pedestrian walk targets: nearest road point ± walk along road.
func pedestrian_walk_target(from: Vector3) -> Vector3:
        var rp := CityDirector.nearest_road_point(Vector2(from.x, from.z))
        var dir: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
        var t: Vector2 = rp["point"] + dir * randf_range(20.0, 80.0)
        return Vector3(t.x, 0, t.y)


## Witness logic: called on crimes; returns NPC ids within witness radius.
func witnesses_of(position: Vector3, radius := 25.0) -> Array:
        var out: Array = []
        for id in _sim.keys():
                if _sim[id]["pos"].distance_to(position) <= radius:
                        out.append(id)
        return out


## Conversational greetings depend on relationship + memory.
func greeting_for(npc_id: String) -> String:
        var rel: float = GameState.relationship_for(npc_id)
        var act := named_activity(npc_id)
        if rel > 40.0:
                return "Hey, Dez. Good to see you."
        if rel < -40.0:
                return "You've got some nerve showing up here."
        match act:
                "walking":
                        return "Can't stop, Dez."
                "work":
                        return "Make it quick, I'm on the clock."
                "social":
                        return "Pull up a chair, why don't you."
                _:
                        return "It's late, Dez."
