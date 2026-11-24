extends Node
## MissionSystem - story campaign graph (5 chapters + finale), side jobs,
## objective tracking, and consequence application. The world scene listens
## to the request signals below to create gameplay entities.

## Requests to the world (world scene connects and instantiates).
signal enemies_spawn_requested(mission_id: String, wave: Dictionary)
signal marker_requested(position: Vector3)
signal marker_cleared
signal cinematic_requested(beat_id: String)
signal vehicle_spawn_requested(spec: Dictionary)
signal pickup_spawn_requested(item_id: String, pos: Vector3, count: int)

const CAMPAIGN := {
        # ---------------- CHAPTER 1 ----------------
        "debt_first": {
                "chapter": 1, "giver": "rizzo", "title": "Debt First",
                "briefing": "Vetch collectors are squeezing the market stalls. Rizzo wants them gone - your first job.",
                "objectives": [
                        {"type": "GOTO", "pos": Vector3(-240, 0, -120), "text": "Go to the Old Quarter market"},
                        {"type": "FIGHT", "wave": "vetch_collectors", "count": 3, "text": "Clear out the Vetch collectors"},
                        {"type": "COLLECT", "item": "stall_cash", "count": 2, "pos": Vector3(-236, 0, -126), "text": "Recover the stall cash boxes they dropped"},
                        {"type": "FIGHT", "wave": "vetch_street", "count": 3, "text": "The collectors came back angry - finish it"},
                        {"type": "TALK", "npc": "rizzo", "text": "Report back to Rizzo"},
                ],
                "reward": {"money": 400, "rep": {"family": 8.0}, "flags": {"debt_first_done": true}},
                "next": "make_change",
        },
        "make_change": {
                "chapter": 1, "giver": "rizzo", "title": "Make Change",
                "briefing": "A repo'd sedan still has Nadia's collateral in the trunk. Get the car before the crushers do.",
                "objectives": [
                        {"type": "GOTO", "pos": Vector3(-300, 0, 60), "text": "Reach the Docklands impound"},
                        {"type": "DRIVE", "pos": Vector3(-120, 0, -80), "vehicle": "sedan", "text": "Drive the sedan to the Pawn & Barrel lot"},
                        {"type": "GOTO", "pos": Vector3(-180, 0, 150), "text": "Swing by Dez Depot filling station on the way"},
                        {"type": "TALK", "npc": "nadia", "text": "Talk to Nadia at the pawn shop"},
                ],
                "reward": {"money": 350, "rep": {"family": 5.0, "community": 5.0}, "flags": {"make_change_done": true}},
                "next": "rendezvous",
        },
        "rendezvous": {
                "chapter": 1, "giver": "rizzo", "title": "Rendezvous",
                "briefing": "Meet Rizzo at the docks. He's not the only one waiting.",
                "objectives": [
                        {"type": "GOTO", "pos": Vector3(-340, 0, 220), "text": "Meet Rizzo at the docks"},
                        {"type": "CHOICE", "id": "ch1_car", "prompt": "The sedan's papers are worth money to both sides. Hand it over to the Family?",
                                "options": [
                                        {"label": "Give the car to the Family", "tags": {"give_family": true}},
                                        {"label": "Keep the papers as leverage", "tags": {"keep_papers": true}},
                                ]},
                ],
                "reward": {"money": 250, "flags": {"rendezvous_done": true, "chapter": 2}},
                "next": "gym_introduction",
        },
        # ---------------- CHAPTER 2 ----------------
        "gym_introduction": {
                "chapter": 2, "giver": "big_theo", "title": "Heavy Bags",
                "briefing": "Big Theo runs the Iron Gym. He says your fists need schooling before the streets eat you.",
                "objectives": [
                        {"type": "GOTO", "pos": Vector3(-200, 0, 560), "text": "Go to Iron Gym in the Ironworks"},
                        {"type": "INTERACT", "target": "heavy_bag", "count": 3, "text": "Work the heavy bag (train kickboxing)"},
                        {"type": "FIGHT", "wave": "sparring_partner", "count": 1, "text": "Show Theo the basics land - sparring round"},
                        {"type": "TALK", "npc": "big_theo", "text": "Talk to Big Theo"},
                ],
                "reward": {"money": 150, "flags": {"met_big_theo": true, "kickboxing_unlocked": true}, "xp": {"kickboxing": 40}},
                "next": "bar_night",
        },
        "bar_night": {
                "chapter": 2, "giver": "marisol", "title": "Bar Night",
                "briefing": "Marisol's Bar, your local. Lucy Fang is coming to collect 'protection'. Marisol hates paying.",
                "objectives": [
                        {"type": "GOTO", "pos": Vector3(-240, 0, -180), "text": "Get to Marisol's Bar"},
                        {"type": "TALK", "npc": "marisol", "text": "Hear Marisol's plan before they arrive"},
                        {"type": "FIGHT", "wave": "vetch_shakers", "count": 4, "text": "Defend the bar from Lucy Fang's crew"},
                        {"type": "CHOICE", "id": "ch2_lucy", "prompt": "Lucy's crew is down. How do you leave it?",
                                "options": [
                                        {"label": "Escort Lucy out gently", "tags": {"mercy": true}},
                                        {"label": "Put Lucy in the gutter", "tags": {"brutal": true}},
                                        {"label": "Call Officer Brant on her", "tags": {"police_tip": true}},
                                ]},
                ],
                "reward": {"money": 300, "flags": {"bar_story_arc": true, "drunken_unlocked": true}, "xp": {"brawler": 30, "drunken": 20}},
                "next": "kestrel_summons",
        },
        # ---------------- CHAPTER 3 ----------------
        "kestrel_summons": {
                "chapter": 3, "giver": "ava", "title": "Clean Hands",
                "briefing": "Ava Kestrel invites you to the tower. She knows exactly what you're worth - and what you owe.",
                "objectives": [
                        {"type": "GOTO", "pos": Vector3(240, 0, -200), "text": "Go to Kestrel Tower"},
                        {"type": "TALK", "npc": "ava", "text": "Hear Ava's offer"},
                ],
                "reward": {"money": 0, "flags": {"ava_met": true}},
                "next": "tower_heist",
        },
        "tower_heist": {
                "chapter": 3, "giver": "ava", "title": "The Ledger",
                "briefing": "The Family keeps its real books in Kestrel Tower's private vault. Ava wants copies. So do you.",
                "objectives": [
                        {"type": "GOTO", "pos": Vector3(240, 0, -200), "text": "Enter Kestrel Tower"},
                        {"type": "FIGHT", "wave": "tower_security", "count": 3, "text": "Clear the lobby security"},
                        {"type": "INTERACT", "target": "vault_terminal", "count": 1, "text": "Reach the vault terminal"},
                        {"type": "CHOICE", "id": "ch3_ledger", "prompt": "You hold the Family ledger. Ava's offer was generous - but the ledger is leverage itself.",
                                "options": [
                                        {"label": "Give the ledger to Ava Kestrel", "tags": {"ledger_ava": true}},
                                        {"label": "Burn it for Kestrel's rivals", "tags": {"ledger_burned": true}},
                                        {"label": "Keep the ledger yourself", "tags": {"ledger_kept": true}},
                                ]},
                        {"type": "ESCAPE", "wanted_clear": true, "text": "Slip out before security locks down"},
                ],
                "reward": {"money": 800, "flags": {"chapter": 4, "tower_done": true}},
                "next": "turf_war",
        },
        # ---------------- CHAPTER 4 ----------------
        "turf_war": {
                "chapter": 4, "giver": "rizzo", "title": "Everything Is Collateral",
                "briefing": "The ledger leak lit the fuse. Vetch is muscling into Old Quarter alleys. Rizzo wants the streets back.",
                "objectives": [
                        {"type": "GOTO", "pos": Vector3(-180, 0, -120), "text": "Get to the Old Quarter alleys"},
                        {"type": "FIGHT", "wave": "vetch_street", "count": 5, "text": "Break the Vetch push"},
                        {"type": "GOTO", "pos": Vector3(-200, 0, 560), "text": "Return to Big Theo for grappling training"},
                        {"type": "INTERACT", "target": "grapple_dummies", "count": 2, "text": "Learn the throw (grappling)"},
                ],
                "reward": {"money": 500, "flags": {"gym_training_2": true, "grappling_unlocked": true}, "xp": {"grappling": 40}},
                "next": "scrapyard_lucy",
        },
        "scrapyard_lucy": {
                "chapter": 4, "giver": "big_theo", "title": "Lucy's Last Round",
                "briefing": "Lucy Fang calls you out to the scrapyard. This time it's personal, and she brought friends.",
                "objectives": [
                        {"type": "GOTO", "pos": Vector3(-330, 0, 560), "text": "Go to the Ironworks scrapyard"},
                        {"type": "FIGHT", "wave": "lucy_miniboss", "count": 2, "text": "Beat Lucy's seconds"},
                        {"type": "FIGHT", "wave": "lucy_boss", "count": 1, "text": "Defeat Lucy Fang"},
                ],
                "reward": {"money": 700, "rep": {"kestrel": 5.0, "vetch": -25.0}, "flags": {"lucy_down": true}},
                "next": "the_letter",
        },
        "the_letter": {
                "chapter": 4, "giver": "juno", "title": "The Letter",
                "briefing": "Juno found a letter under your door. It's Tommy's handwriting. They let him write one page.",
                "objectives": [
                        {"type": "GOTO", "pos": Vector3(-280, 0, -160), "text": "Go home to Dez's apartment"},
                        {"type": "COLLECT", "item": "tommy_letter", "count": 1, "text": "Read Tommy's letter"},
                        {"type": "TALK", "npc": "juno", "text": "Talk to Juno"},
                ],
                "reward": {"money": 0, "rep": {"community": 10.0}, "flags": {"tommy_letter_read": true, "chapter": 5}},
                "next": "the_meet",
        },
        # ---------------- CHAPTER 5 ----------------
        "the_meet": {
                "chapter": 5, "giver": "vito", "title": "Leverage",
                "briefing": "Vito calls the meet at the scrapyard. Bring the leverage. Everyone wants it. Everyone's watching.",
                "objectives": [
                        {"type": "GOTO", "pos": Vector3(-330, 0, 560), "text": "Get to the scrapyard meet"},
                        {"type": "FIGHT", "wave": "meet_ambush", "count": 4, "text": "Survive the ambush (everyone's leverage on everyone)"},
                        {"type": "TALK", "npc": "vito", "text": "Face Vito"},
                ],
                "reward": {"money": 0, "flags": {"meet_done": true}},
                "next": "rescue_tommy",
        },
        "rescue_tommy": {
                "chapter": 5, "giver": "officer_brant", "title": "The Long Night",
                "briefing": "Tommy's held at the Docklands container yard. Brant tips you the window. Get him out - loud or quiet.",
                "objectives": [
                        {"type": "GOTO", "pos": Vector3(-360, 0, 300), "text": "Reach the container yard"},
                        {"type": "FIGHT", "wave": "yard_guards", "count": 4, "text": "Clear the yard guards"},
                        {"type": "COLLECT", "item": "tommy", "count": 1, "text": "Free Tommy"},
                        {"type": "DRIVE", "pos": Vector3(-80, 0, -40), "vehicle": "any", "chase": true, "text": "Drive Tommy out of Docklands"},
                ],
                "reward": {"money": 0, "flags": {"tommy_rescued": true}},
                "next": "finale_villa",
        },
        "finale_villa": {
                "chapter": 5, "giver": "dez", "title": "Everyone Has Leverage On You",
                "briefing": "The Castellane Villa. Vito is waiting with the last ledger. The city is watching what you do with it.",
                "objectives": [
                        {"type": "GOTO", "pos": Vector3(120, 0, -620), "text": "Drive to the Castellane Villa"},
                        {"type": "FIGHT", "wave": "villa_guards", "count": 5, "text": "Fight through the villa grounds"},
                        {"type": "FIGHT", "wave": "villa_elite", "count": 3, "text": "Break Vito's last line - the ledger guard"},
                        {"type": "CHOICE", "id": "finale", "prompt": "Vito, on his knees, offers you the whole operation. The ledger is in your hand.",
                                "options": [
                                        {"label": "Kill Vito. End the Family in blood.", "tags": {"ending_blood": true}},
                                        {"label": "Take Vito's deal. Run the Family your way.", "tags": {"ending_family": true}},
                                        {"label": "Hand the ledger to Officer Brant.", "tags": {"ending_community": true}},
                                        {"label": "Give it all to Ava Kestrel.", "tags": {"ending_corp": true}},
                                ]},
                ],
                "reward": {"money": 0, "flags": {"finale_done": true}},
                "next": "",
        },
}

const SIDE_JOBS := {
        "sj_courier": {"giver": "juno", "title": "Courier Run", "objectives": [
                        {"type": "COLLECT", "item": "parcel", "count": 1, "text": "Pick up Juno's parcel"},
                        {"type": "DRIVE", "pos": Vector3(300, 0, 200), "text": "Drop it at Neon Strip"}],
                "reward": {"money": 120}},
        "sj_repo": {"giver": "nadia", "title": "Repo Man Again", "objectives": [
                        {"type": "GOTO", "pos": Vector3(200, 0, -100), "text": "Find the defaulted coupe"},
                        {"type": "DRIVE", "pos": Vector3(-260, 0, -80), "text": "Return it to Pawn & Barrel"}],
                "reward": {"money": 200}},
        "sj_bounce": {"giver": "marisol", "title": "Bouncer Shift", "objectives": [
                        {"type": "FIGHT", "wave": "rowdy_patrons", "count": 3, "text": "Throw out the rowdy patrons"}],
                "reward": {"money": 150}},
        "sj_taxi": {"giver": "cabbie_moses", "title": "Moses' Fares", "objectives": [
                        {"type": "DRIVE", "pos": Vector3(-120, 0, -60), "text": "Fare to Old Quarter"},
                        {"type": "DRIVE", "pos": Vector3(240, 0, -200), "text": "Fare to Kestrel Tower"}],
                "reward": {"money": 90}},
        "sj_pickpocket": {"giver": "the_tipster", "title": "Parade Pockets", "objectives": [
                        {"type": "COLLECT", "item": "wallet", "count": 3, "text": "Lift three wallets in the crowd"}],
                "reward": {"money": 240}},
        "sj_tags": {"giver": "the_tipster", "title": "Cinder Tokens", "objectives": [
                        {"type": "COLLECT", "item": "token", "count": 5, "text": "Find 5 Cinder Tokens"}],
                "reward": {"money": 300}},
        "sj_strike": {"giver": "officer_brant", "title": "Keep The Peace", "objectives": [
                        {"type": "FIGHT", "wave": "strike_breakers", "count": 4, "text": "Stop the strike-breakers"}],
                "reward": {"money": 180, "rep": {"community": 10.0}}},
        "sj_blackout": {"giver": "ava", "title": "Sabotage", "objectives": [
                        {"type": "GOTO", "pos": Vector3(200, 0, 260), "text": "Reach the strip substation"},
                        {"type": "INTERACT", "target": "substation", "count": 1, "text": "Cut the Neon Strip feed"}],
                "reward": {"money": 500, "flags": {"blackout_sabotage_done": true}}},
}

const ENDINGS := {
        "ending_blood": {"title": "BLOOD LEDGER", "condition": {"flag": "ending_blood"},
                "epilogue": "The Family ends with Vito. So does the peace. Oduya signs the warrant herself; Brant won't take your calls. Tommy's free - the city isn't."},
        "ending_family": {"title": "THE NEW LEDGER", "condition": {"flag": "ending_family"},
                "epilogue": "You keep the books, the crews, the debts. Rizzo takes orders now. Tommy's free, but he flinches when you raise your voice. Everyone has leverage on everyone - including you."},
        "ending_community": {"title": "CLEAN STREETS", "condition": {"flag": "ending_community"},
                "epilogue": "Brant walks the ledger into the precinct in a cardboard box. The Family burns down in paperwork. Ava keeps a copy - her leverage on you - and smiles like an old friend."},
        "ending_corp": {"title": "KESTREL CITY", "condition": {"flag": "ending_corp"},
                "epilogue": "Kestrel logos replace the Family's marks within a week. Tommy's free, the streets are safe, and every camera in Cinder City knows your face."},
}

var active_id := ""               # current mission id
var objective_index := 0
var objective_progress := 0       # count within current objective
var _active_choice := {}           # pending choice
var _history: Array = []           # completed ids
var _m_start_ms := 0               # mission medal timing
var _m_damage := 0.0               # mission medal damage taken
var _m_last_hp := -1.0             # last-seen hp for damage tracking


func _ready() -> void:
        EventBus.choice_made.connect(_on_choice_made)
        EventBus.dialogue_ended.connect(func(_n): pass)
        EventBus.player_health_changed.connect(_track_mission_damage)


func available_missions() -> Array:
        var out: Array = []
        var ch: int = int(GameState.story_flags.get("chapter", 1))
        for id in CAMPAIGN.keys():
                var m: Dictionary = CAMPAIGN[id]
                if int(m.get("chapter", 1)) > ch:
                        continue
                if _history.has(id) or id == active_id:
                        continue
                if _prereq_failed(id):
                        continue
                out.append(id)
        for id in SIDE_JOBS.keys():
                if not _history.has(id) and id != active_id:
                        out.append(id)
        return out


func _prereq_failed(_id: String) -> bool:
        return false  # linear chain via 'next' keeps prerequisites implicit


func start_mission(id: String) -> bool:
        var def: Dictionary = CAMPAIGN.get(id, SIDE_JOBS.get(id, {}))
        if def.is_empty():
                return false
        active_id = id
        objective_index = 0
        objective_progress = 0
        _active_choice = {}
        _m_start_ms = Time.get_ticks_msec()
        _m_damage = 0.0
        _m_last_hp = -1.0
        GameState.missions_state[id] = {"status": "active"}
        EventBus.mission_started.emit(id)
        _show_objective()
        _spawn_objective_entities()
        return true


func current_objective() -> Dictionary:
        var def: Dictionary = mission_def(active_id)
        var objs: Array = def.get("objectives", [])
        if objective_index < objs.size():
                return objs[objective_index]
        return {}


func mission_def(id: String) -> Dictionary:
        return CAMPAIGN.get(id, SIDE_JOBS.get(id, {}))


func _show_objective() -> void:
        var obj := current_objective()
        if not obj.is_empty():
                EventBus.objective_displayed.emit(String(obj.get("text", "")), mission_def(active_id).get("title", ""))


func _spawn_objective_entities() -> void:
        var obj := current_objective()
        if obj.is_empty():
                return
        match String(obj.get("type", "")):
                "GOTO", "DRIVE":
                        marker_requested.emit(obj.get("pos", Vector3.ZERO))
                "FIGHT":
                        enemies_spawn_requested.emit(active_id, obj)
                "COLLECT":
                        if String(obj.get("item", "")) == "token":
                                marker_requested.emit(Vector3(-240, 0, -120))
                        elif obj.has("pos"):
                                pickup_spawn_requested.emit(String(obj.get("item", "")),
                                        obj.get("pos", Vector3.ZERO), int(obj.get("count", 1)))
                                marker_requested.emit(obj.get("pos", Vector3.ZERO))
                _:
                        pass


func notify_at_position(pos: Vector3) -> void:
        ## World calls this every frame with player position.
        var obj := current_objective()
        if obj.is_empty():
                return
        if String(obj.get("type", "")) == "GOTO":
                var target: Vector3 = obj.get("pos", Vector3.ZERO)
                if pos.distance_to(target) <= 12.0:
                        advance()


func notify_interact(target_id: String) -> void:
        var obj := current_objective()
        if obj.is_empty():
                return
        if String(obj.get("type", "")) == "INTERACT" and String(obj.get("target", "")) == target_id:
                objective_progress += 1
                if objective_progress >= int(obj.get("count", 1)):
                        advance()


func notify_item_collected(item_id: String) -> void:
        var obj := current_objective()
        if obj.is_empty():
                return
        if String(obj.get("type", "")) == "COLLECT" and String(obj.get("item", "")) == item_id:
                objective_progress += 1
                if objective_progress >= int(obj.get("count", 1)):
                        advance()


func notify_talked(npc_id: String) -> void:
        var obj := current_objective()
        if obj.is_empty():
                return
        if String(obj.get("type", "")) == "TALK" and String(obj.get("npc", "")) == npc_id:
                advance()


func notify_enemies_cleared() -> void:
        var obj := current_objective()
        if obj.is_empty():
                return
        if String(obj.get("type", "")) == "FIGHT":
                advance()


func notify_vehicle_arrived() -> void:
        var obj := current_objective()
        if obj.is_empty():
                return
        if String(obj.get("type", "")) == "DRIVE":
                advance()


func notify_wanted_cleared() -> void:
        var obj := current_objective()
        if obj.is_empty():
                return
        if String(obj.get("type", "")) == "ESCAPE":
                advance()


func notify_choice_made(choice_id: String) -> void:
        var obj := current_objective()
        if obj.is_empty():
                return
        if String(obj.get("type", "")) == "CHOICE":
                advance()


func advance() -> void:
        var def: Dictionary = mission_def(active_id)
        var objs: Array = def.get("objectives", [])
        objective_index += 1
        objective_progress = 0
        marker_cleared.emit()
        if objective_index >= objs.size():
                complete_mission()
        else:
                EventBus.mission_objective_completed.emit(active_id, objective_index - 1)
                _show_objective()
                _spawn_objective_entities()


func fail_mission(reason: String) -> void:
        if active_id == "":
                return
        EventBus.mission_failed.emit(active_id, reason)
        GameState.missions_state[active_id] = {"status": "failed"}
        active_id = ""
        objective_index = 0
        marker_cleared.emit()


func complete_mission() -> void:
        var def: Dictionary = mission_def(active_id)
        if def.is_empty():
                return
        var reward: Dictionary = def.get("reward", {})
        var money: int = int(reward.get("money", 0))
        if money > 0:
                GameState.add_money(money)
        var rep: Dictionary = reward.get("rep", {})
        for faction in rep.keys():
                GameState.add_reputation(faction, float(rep[faction]))
        var flags: Dictionary = reward.get("flags", {})
        for flag in flags.keys():
                GameState.set_story_flag(flag, flags[flag])
        var xp: Dictionary = reward.get("xp", {})
        for disc in xp.keys():
                GameState.add_discipline_xp(disc, int(xp[disc]))
        GameState.player_stats["missions_completed"] += 1
        GameState.missions_state[active_id] = {"status": "completed"}
        _history.append(active_id)
        EventBus.mission_completed.emit(active_id)
        EventBus.notification_posted.emit("Mission complete: " + String(def.get("title", active_id)), "mission")
        if money > 0:
                EventBus.notification_posted.emit("+$%d" % money, "money")
        _award_medal(def)
        active_id = ""
        objective_index = 0
        marker_cleared.emit()
        var nxt: String = String(def.get("next", ""))
        if nxt != "" and CAMPAIGN.has(nxt):
                start_mission(nxt)


## Performance medals (replay value): time vs par + damage taken.
func _award_medal(def: Dictionary) -> void:
        var time_s := float(Time.get_ticks_msec() - _m_start_ms) / 1000.0
        var par := float(def.get("objectives", []).size()) * 45.0
        if par <= 0.0:
                par = 90.0
        var dmg_pct := _m_damage / maxf(GameState.max_health, 1.0)
        var medal := 1
        if time_s <= par * 0.8 and dmg_pct <= 0.15:
                medal = 3
        elif time_s <= par * 1.4 and dmg_pct <= 0.40:
                medal = 2
        var medals: Dictionary = GameState.player_stats.get("mission_medals", {})
        var best := int(medals.get(active_id, 0))
        if medal > best:
                medals[active_id] = medal
                GameState.player_stats["mission_medals"] = medals
                var names := {1: "BRONZE", 2: "SILVER", 3: "GOLD"}
                EventBus.notification_posted.emit("%s MEDAL — %s" % [names.get(medal, "BRONZE"), String(def.get("title", active_id))], "reward")
                EventBus.sfx_requested.emit("sfx_medal", Vector3.ZERO)
                if medal == 3:
                        GameState.player_stats["gold_medals"] = int(GameState.player_stats.get("gold_medals", 0)) + 1


## Damage tracking for medals (hooked in _ready).
func _track_mission_damage(hp: float, _max_hp: float) -> void:
        if active_id == "":
                _m_last_hp = hp
                return
        if _m_last_hp >= 0.0 and hp < _m_last_hp:
                _m_damage += _m_last_hp - hp
        _m_last_hp = hp


## Called by DialogueSystem when a tagged choice inside any dialogue resolves.
func _on_choice_made(choice_id: String, tags: Dictionary) -> void:
        apply_consequence(choice_id, tags)
        notify_choice_made(choice_id)


func apply_consequence(choice_id: String, tags: Dictionary) -> void:
        ## Consequences schema: flags, reputation, relationships (max 2 rep, 3 rel).
        GameState.story_flags["choice_" + choice_id] = true
        match choice_id:
                "ch1_car":
                        if tags.get("give_family", false):
                                GameState.add_reputation("family", 12.0)
                                GameState.change_relationship("rizzo", 10.0)
                                GameState.set_story_flag("car_given_family", true)
                        else:
                                GameState.add_reputation("kestrel", 10.0)
                                GameState.change_relationship("ava", 8.0)
                                GameState.set_story_flag("papers_kept", true)
                "ch2_lucy":
                        if tags.get("mercy", false):
                                GameState.change_relationship("marisol", 12.0)
                                GameState.add_reputation("community", 8.0)
                        elif tags.get("brutal", false):
                                GameState.add_reputation("vetch", -10.0)
                                GameState.change_relationship("marisol", 6.0)
                                GameState.add_reputation("family", 6.0)
                        else:
                                GameState.add_reputation("police", 12.0)
                                GameState.change_relationship("officer_brant", 15.0)
                                GameState.set_story_flag("lucy_arrested", true)
                "ch3_ledger":
                        if tags.get("ledger_ava", false):
                                GameState.add_reputation("kestrel", 20.0)
                                GameState.change_relationship("ava", 15.0)
                        elif tags.get("ledger_burned", false):
                                GameState.add_reputation("family", -15.0)
                                GameState.set_story_flag("ledger_burned", true)
                        else:
                                GameState.set_story_flag("ledger_kept", true)
                                GameState.set_story_flag("dock_strike_declared", true)
                "finale":
                        for tag in ["ending_blood", "ending_family", "ending_community", "ending_corp"]:
                                if tags.get(tag, false):
                                        GameState.set_story_flag(tag, true)
                        GameState.set_story_flag("finale_done", true)
        # NOTE: no re-emit of EventBus.choice_made here - the caller already
        # emitted it; re-emitting would recurse (_on_choice_made listener).


func resolve_ending() -> String:
        for eid in ENDINGS.keys():
                var cond: Dictionary = ENDINGS[eid].get("condition", {})
                if GameState.story_flag(String(cond.get("flag", "")), false):
                        return eid
        return ""


func ending_def(eid: String) -> Dictionary:
        return ENDINGS.get(eid, {})


func snapshot() -> Dictionary:
        return {"active": active_id, "obj": objective_index, "prog": objective_progress,
                "history": _history.duplicate()}


func restore(data: Dictionary) -> void:
        _history = data.get("history", [])
        var act: String = String(data.get("active", ""))
        if act != "" and not _history.has(act):
                start_mission(act)
                objective_index = int(data.get("obj", 0))
                objective_progress = int(data.get("prog", 0))
                _show_objective()
