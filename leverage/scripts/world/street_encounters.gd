extends Node
## StreetEncounters - emergent street-encounter director (v2.4.0 "Alive City").
## RDR2-style random encounters: during free-roam the city throws problems at
## the player (muggings to break up, deals to bust, brawls, dropped stashes).
## Pure scheduling/resolution logic + signals; the world scene instantiates
## visuals/combatants exactly like PoliceSystem unit spawning (TDL #35).

signal encounter_started(enc_id: String, position: Vector3, area_id: String)
signal encounter_ended(enc_id: String, outcome: String)

const ENCOUNTERS := {
        "street_mugging": {
                "kind": "combat", "enemies": 1, "hp": 60.0, "dmg": 8.0,
                "reward_money": [140, 260], "rep": {"family": 2.0, "police": 1.0},
                "weight": 1.0,
                "title": "A collector is shaking down a shopkeeper",
                "win_text": "Shopkeeper saved - a cut of the week's take",
        },
        "drug_deal": {
                "kind": "combat", "enemies": 2, "hp": 70.0, "dmg": 9.0,
                "reward_money": [320, 480], "rep": {"police": 2.0},
                "weight": 0.8,
                "title": "A deal is going down in the alley",
                "win_text": "Stake claimed",
        },
        "street_brawl": {
                "kind": "ambient",
                "reward_money": [0, 0], "rep": {},
                "weight": 1.2,
                "title": "Two regulars go at it outside the bar",
        },
        "dropped_stash": {
                "kind": "pickup", "heat": 9.0, "witnesses": ["ped_m1"],
                "reward_money": [90, 170], "rep": {},
                "weight": 1.0,
                "title": "Someone dropped a fat envelope",
        },
}

const COOLDOWN_S := 75.0        # min seconds between encounters
const ROLL_MIN_S := 42.0        # seconds between free-roam rolls
const ROLL_MAX_S := 70.0
const LIFETIME_S := 150.0       # unresolved encounter expires
const ABANDON_DIST := 62.0      # player walks farther away -> expired
const BASE_CHANCE := 0.38

var _rng := RandomNumberGenerator.new()
var _player_pos := Vector3.ZERO
var _player_pos_valid := false
var _cooldown := 20.0           # startup grace
var _roll_in := 45.0
var _active: Dictionary = {}     # enc_id -> {pos: Vector3, area: String, t: float}
var _encounters_won := 0
var _encounters_seen := 0


func _ready() -> void:
        _rng.randomize()
        EventBus.game_started.connect(_on_game_started)


func _on_game_started(_new_game: bool) -> void:
        # world reloads wipe spawned visuals; never carry stale encounters
        _active.clear()
        _cooldown = 20.0
        _roll_in = 45.0


func set_player_position(pos: Vector3) -> void:
        _player_pos = pos
        _player_pos_valid = true


func set_seed(s: int) -> void:
        _rng.seed = s


func _process(delta: float) -> void:
        if not GameManager.is_playing():
                return
        _cooldown = max(0.0, _cooldown - delta)
        for eid in _active.keys():
                var a: Dictionary = _active[eid]
                a["t"] = float(a.get("t", 0.0)) + delta
                var far: bool = _player_pos_valid and Vector2(_player_pos.x, _player_pos.z).distance_to(Vector2(float(a["pos"].x), float(a["pos"].z))) > ABANDON_DIST
                if float(a.get("t", 0.0)) > LIFETIME_S or far:
                        resolve(eid, "expired")
        if _active.is_empty():
                _roll_in -= delta
                if _roll_in <= 0.0:
                        _roll_in = randf_range(ROLL_MIN_S, ROLL_MAX_S)
                        if _gate_open():
                                _try_roll()


## Encounter gating: free-roam only (no mission/combat/interior/chase).
func _gate_open() -> bool:
        return MissionSystem.active_id == "" and not GameState.in_combat \
                and GameState.in_interior == "" and GameState.wanted_level == 0 \
                and GameManager.is_playing() and _player_pos_valid


## Encounter probability for the current time/area (night + crime areas roll hotter).
func _chance() -> float:
        var c := BASE_CHANCE
        c += WorldEvents.crime_boost(CityDirector.current_area)
        var h := TimeWeather.hour()
        if h >= 21 or h <= 4:
                c += 0.08
        return c


func _try_roll() -> void:
        if _cooldown > 0.0:
                return
        if _rng.randf() > _chance():
                return
        var eid := _pick()
        if eid == "":
                return
        start_encounter(eid)


## Explicit start (force_roll, story hooks, tests); bypasses chance/cooldown gates.
func start_encounter(eid: String) -> bool:
        if not ENCOUNTERS.has(eid) or _active.has(eid):
                return false
        if not _player_pos_valid:
                _player_pos = Vector3.ZERO
                _player_pos_valid = true
        var pos := _player_pos + Vector3(_rng.randf_range(-30.0, 30.0), 0.0, _rng.randf_range(18.0, 40.0))
        _active[eid] = {"pos": pos, "area": CityDirector.current_area, "t": 0.0}
        _encounters_seen += 1
        GameState.player_stats["encounters_seen"] = _encounters_seen
        _cooldown = COOLDOWN_S
        EventBus.notification_posted.emit(String(ENCOUNTERS[eid].get("title", eid)), "world")
        EventBus.sfx_requested.emit("sfx_notification", pos)
        encounter_started.emit(eid, pos, CityDirector.current_area)
        return true


## Weighted pick among encounters not currently active.
func _pick() -> String:
        var open: Array = []
        for eid in ENCOUNTERS.keys():
                if not _active.has(eid):
                        open.append(eid)
        if open.is_empty():
                return ""
        var total := 0.0
        for e in open:
                total += float(ENCOUNTERS[e].get("weight", 1.0))
        var r := _rng.randf() * total
        for e in open:
                r -= float(ENCOUNTERS[e].get("weight", 1.0))
                if r <= 0.0:
                        return String(e)
        return String(open[0])


func force_roll() -> void:
        _try_roll()


## World calls: the player reached a dropped-stash pickup.
func notify_pickup_reached() -> void:
        for eid in _active.keys():
                if String(ENCOUNTERS[eid].get("kind", "")) == "pickup":
                        resolve(eid, "grabbed")
                        return


## World calls: all combatants of a fight encounter are down.
func notify_fight_cleared() -> void:
        for eid in _active.keys():
                if String(ENCOUNTERS[eid].get("kind", "")) == "combat":
                        resolve(eid, "won")
                        return


func resolve(eid: String, outcome: String) -> void:
        if not _active.has(eid):
                return
        var a: Dictionary = _active[eid]
        _active.erase(eid)
        encounter_ended.emit(eid, outcome)
        if outcome == "won":
                _encounters_won += 1
                GameState.player_stats["encounters_won"] = _encounters_won
                _pay_reward(eid, a["pos"])
                var rep: Dictionary = ENCOUNTERS[eid].get("rep", {})
                for faction in rep.keys():
                        GameState.add_reputation(String(faction), float(rep[faction]))
        elif outcome == "grabbed":
                _encounters_won += 1
                GameState.player_stats["encounters_won"] = _encounters_won
                _pay_reward(eid, a["pos"])
                EventBus.crime_committed.emit("property_theft", a["pos"],
                        float(ENCOUNTERS[eid].get("heat", 8.0)),
                        ENCOUNTERS[eid].get("witnesses", []))


func _pay_reward(eid: String, pos: Vector3) -> void:
        var rr: Array = ENCOUNTERS[eid].get("reward_money", [0, 0])
        var money := int(randi_range(int(rr[0]), int(rr[1])))
        if money > 0:
                GameState.add_money(money)
                EventBus.notification_posted.emit("%s (+$%d)" % [String(ENCOUNTERS[eid].get("win_text", "Done")), money], "reward")
                EventBus.sfx_requested.emit("sfx_token", pos)


func active_encounters() -> Array:
        return _active.keys()


func is_active(eid: String) -> bool:
        return _active.has(eid)


func encounter_def(eid: String) -> Dictionary:
        return ENCOUNTERS.get(eid, {})


func stats() -> Dictionary:
        return {"seen": _encounters_seen, "won": _encounters_won}


## Test hook: advance the encounter clocks without waiting.
func debug_advance(delta: float) -> void:
        _cooldown = max(0.0, _cooldown - delta)
        for eid in _active.keys():
                var a: Dictionary = _active[eid]
                a["t"] = float(a.get("t", 0.0)) + delta
                if float(a.get("t", 0.0)) > LIFETIME_S:
                        resolve(eid, "expired")
