extends Node
## DialogueSystem - node-based conversations with choices + tags.
## Dialogue data lives in DIALOGUES below keyed by npc_id; each node has text,
## optional speaker, optional choices [{label, next, tags}] or next id.
## Memory-aware line selection: nodes can carry 'requires' {rel_min, rel_max,
## memory: "key"} filters. Presents via EventBus.subtitle_show + UI panel.

const DIALOGUES := {
	"rizzo": {
		"nodes": {
			"start": {
				"text": "Dez. You look like a man who wants his brother back.",
				"next": "offer",
			},
			"offer": {
				"text": "The Ledger holds the debt. Work it off - starting with those Vetch rats in the market.",
				"choices": [
					{"label": "I'll clear the market.", "next": "accept", "tags": {}},
					{"label": "What's in it for me?", "next": "money", "tags": {}},
					{"label": "I'm nobody's muscle.", "next": "refuse", "tags": {"cold": true}},
				],
			},
			"money": {"text": "Four hundred. And I don't tell Vito how slow you are. Deal?", "next": "accept"},
			"accept": {"text": "Good. The market's yours to clean. Rizzo out.", "end": true},
			"refuse": {
				"text": "Nobility. Cute. The collectors hit the stalls anyway - and Tommy stays in the container.",
				"end": true, "rep": {"family": -5.0},
			},
		},
	},
	"marisol": {
		"nodes": {
			"start": {
				"text": "Dez, mi vida. Bad night to be sober.",
				"requires": {"hour_min": 18, "hour_max": 4},
				"next": "chat",
			},
			"chat": {
				"text": "Lucy Fang left a message on my cooler: 'protection or glass'. I hate both options.",
				"choices": [
					{"label": "I'll be here when they come.", "next": "thanks", "tags": {"loyal": true}},
					{"label": "Pay them, Marisol. Live.", "next": "pay", "tags": {}},
				],
			},
			"thanks": {"text": "Then the drinks are on me forever. Now let me show you how a drunk man fights - it works.", "end": true, "unlock": "drunken"},
			"pay": {"text": "A woman bleeds every month in this city anyway. Fine. But listen - the drunken way still works. Let me show you.", "end": true, "unlock": "drunken"},
		},
	},
	"big_theo": {
		"nodes": {
			"start": {
				"text": "Carter! Your hooks are wide and your hips are dead. Sit down - no, stand UP. Train.",
				"next": "train",
			},
			"train": {
				"text": "Kickboxing first: the legs are honest even when the fists lie. Then, if you live, the throws.",
				"choices": [
					{"label": "Teach me the kicks.", "next": "kick", "tags": {}},
					{"label": "Teach me the throws.", "next": "grapple", "tags": {"gym_training_2": true}},
				],
			},
			"kick": {"text": "Kickboxing is yours, then. Bag. Now. Three rounds.", "end": true, "unlock": "kickboxing"},
			"grapple": {"text": "Grapple: the art of ending conversations. Grab, break balance, earth. Practice on the dummies.", "end": true, "unlock": "grappling"},
		},
	},
	"ava": {
		"nodes": {
			"start": {
				"text": "Dez Carter. Repo-man. Brother of a debtor. You're worth more than you think - that's the problem.",
				"next": "offer",
			},
			"offer": {
				"text": "The Family keeps its real ledger in my tower's vault. Copies of it buy your brother twice over.",
				"choices": [
					{"label": "What do you want in return?", "next": "wants", "tags": {}},
					{"label": "I don't sell to corporations.", "next": "cold", "tags": {"cold": true}},
				],
			},
			"wants": {"text": "Theft. Once. After that - your leverage is simply worth less than mine. Acceptable?", "end": true},
			"cold": {"text": "Noble. The offer stays on the table - gravity tends to bring people back to it.", "end": true},
		},
	},
	"vito": {
		"nodes": {
			"start": {
				"text": "The man whose brother's debt bought my time. Sit. I count everything, Dez. It's why they call me the Ledger.",
				"next": "philosophy",
			},
			"philosophy": {
				"text": "Everyone has leverage on you. The question at the end is only ever: who do you hand it to?",
				"choices": [
					{"label": "Give it back to you.", "next": "deal", "tags": {"ending_family": true}},
					{"label": "(Say nothing.)", "next": "silence", "tags": {}},
				],
			},
			"deal": {"text": "Then take the books. Rizzo answers to you now. We're family - the word finally means something.", "end": true},
			"silence": {"text": "Quiet men die with full ledgers. Decide soon - the scrapyard meet is set.", "end": true},
		},
	},
	"nadia": {
		"nodes": {
			"start": {
				"text": "Pawn and Barrel. I buy anything you're too honest to keep and sell anything you're too dumb to want.",
				"next": "shop",
			},
			"shop": {"text": "Browse. The pistol's behind the counter. Don't make me regret my capitalism.", "end": true, "shop": "pawn"},
		},
	},
	"doc_lennox": {
		"nodes": {
			"start": {"text": "You again. Hold still - and this time try not to bleed on the magazines.", "end": true, "heal": true},
		},
	},
	"juno": {
		"nodes": {
			"start": {"text": "Dez! There's a letter under your door. Tommy's handwriting - I'd know that chicken-scratch anywhere.", "end": true},
		},
	},
	"officer_brant": {
		"nodes": {
			"start": {
				"text": "Carter. Half this precinct thinks you're the disease. I think you're a symptom. Small difference.",
				"next": "tip",
			},
			"tip": {
				"text": "Container yard, tonight. They moved your brother. That's all I'll say where they can hear me.",
				"choices": [
					{"label": "Thank you, officer.", "next": "nod", "tags": {"warm": true}},
					{"label": "Why help me?", "next": "why", "tags": {}},
				],
			},
			"nod": {"text": "Don't thank me. Make it count.", "end": true},
			"why": {"text": "Because the alternative is Oduya kicking the door with forty badges. I'd rather it be you with two hands.", "end": true},
		},
	},
	"ren": {
		"nodes": {
			"start": {"text": "The repo-man. Your brother cost me a container's worth of product. You'll cost the rest. Get off my docks.", "end": true},
		},
	},
	"lucy_fang": {
		"nodes": {
			"start": {"text": "You're the bar's new pet. Tell Marisol the price went up - because of you.", "end": true},
		},
	},
	"sergeant_oduya": {
		"nodes": {"start": {"text": "Move along, Carter. And keep those fists in your pockets this time.", "end": true}},
	},
	"cabbie_moses": {
		"nodes": {"start": {"text": "Where to, brother? Everyone's going somewhere ugly tonight - might as well ride warm.", "end": true, "fast_travel": true}},
	},
	"tommy": {
		"nodes": {"start": {"text": "Dez... you actually came. I knew the streets hadn't eaten all of you.", "end": true}},
	},
}

var current_npc := ""
var current_node := ""
var _context := {}       # runtime context for line filtering


signal dialogue_choice_presented(node_id: String, choices: Array)


func _ready() -> void:
        pass


func has_dialogue(npc_id: String) -> bool:
        return DIALOGUES.has(npc_id)


func start(npc_id: String, context := {}) -> bool:
        if not has_dialogue(npc_id):
                return false
        current_npc = npc_id
        current_node = "start"
        _context = context
        EventBus.dialogue_started.emit(npc_id)
        _present_current()
        return true


func _present_current() -> void:
        var node := _node(current_npc, current_node)
        if node.is_empty():
                end()
                return
        if not _requirements_met(node):
                # fall through to next eligible node
                if node.has("next"):
                        current_node = String(node["next"])
                        _present_current()
                        return
                end()
                return
        EventBus.subtitle_show.emit(String(node.get("text", "")), NPCDirector.cast_display(current_npc), 4.0)
        if node.has("choices"):
                dialogue_choice_presented.emit(current_node, node["choices"])


func _node(npc_id: String, node_id: String) -> Dictionary:
        var d: Dictionary = DIALOGUES.get(npc_id, {})
        var nodes: Dictionary = d.get("nodes", {})
        return nodes.get(node_id, {})


func _requirements_met(node: Dictionary) -> bool:
        var req: Dictionary = node.get("requires", {})
        if req.is_empty():
                return true
        if req.has("rel_min") and GameState.relationship_for(current_npc) < float(req["rel_min"]):
                return false
        if req.has("memory") and not GameState.npc_remembered(current_npc, String(req["memory"])):
                return false
        if req.has("flag") and not GameState.story_flag(String(req["flag"]), false):
                return false
        return true


## UI calls this when the player picks a choice.
func pick_choice(node_id: String, index: int) -> void:
        var node := _node(current_npc, node_id)
        var choices: Array = node.get("choices", [])
        if index < 0 or index >= choices.size():
                return
        var choice: Dictionary = choices[index]
        var tags: Dictionary = choice.get("tags", {})
        # Effects carried by node data
        if node.has("rep"):
                var rep: Dictionary = node["rep"]
                for f in rep.keys():
                        GameState.add_reputation(f, float(rep[f]))
        EventBus.dialogue_choice_made.emit(node_id + "#" + str(index), tags)
        if String(choice.get("next", "")) != "":
                current_node = String(choice["next"])
                _present_current()
        elif choice.has("end") or node.has("end"):
                end()
        else:
                end()


func advance() -> void:
        var node := _node(current_npc, current_node)
        if node.is_empty():
                end()
                return
        if String(node.get("next", "")) != "":
                current_node = String(node["next"])
                _present_current()
        else:
                end()


func end() -> void:
        if current_npc == "":
                return
        var node := _node(current_npc, current_node)
        # unlock / shop / heal hooks
        if node.has("unlock"):
                var disc := String(node["unlock"])
                if not GameState.unlocked_disciplines.has(disc):
                        GameState.unlocked_disciplines.append(disc)
                        EventBus.notification_posted.emit("Discipline unlocked: " + disc.capitalize(), "unlock")
        if node.has("shop"):
                EventBus.shop_opened.emit(String(node["shop"]))
        if node.has("heal"):
                GameState.health = GameState.max_health
        EventBus.dialogue_ended.emit(current_npc)
        MissionSystem.notify_talked(current_npc)
        current_npc = ""
        current_node = ""
        EventBus.subtitle_hide.emit()


## Greeting line before full dialogue (world shows it as a talk prompt).
func greeting_line(npc_id: String) -> String:
        return NPCDirector.greeting_for(npc_id)
