class_name PhoneSystem
extends Node
## PhoneSystem - the living communication device. Incoming calls ring for
## real (ringtone + banner + answer/decline), calls run as dialogue with
## subtitles and consequences, declined/missed calls log and reschedule once,
## messages build per-contact threads with game-hour timestamps, and the
## story drives it: mission givers call and text as chapters progress.

signal call_ringing(from_id: String, call_id: String)
signal call_connected(from_id: String)
signal call_ended(from_id: String, outcome: String)
signal message_received(from_id: String, text: String)

enum State { IDLE, RINGING, ACTIVE }

const RING_MAX := 14.0           # seconds before a ring goes to missed
const MIN_GAP_BETWEEN_CALLS := 8.0

var state: int = State.IDLE
var current_call: Dictionary = {}    # {from, lines, on_answer:{...}, id}
var call_log: Array = []             # {from, outcome, time}
var _queue: Array = []               # pending scheduled calls
var _ring_t := 0.0
var _cooldown_t := 0.0
var _done_keys := {}                 # idempotency keys of fired calls
var _ring_player: AudioStreamPlayer3D
var _line_t := 0.0
var _line_i := 0

func _ready() -> void:
        process_priority = 40
        _ring_player = AudioStreamPlayer3D.new()
        _ring_player.unit_size = 9.0
        add_child(_ring_player)
        if EventBus.has_signal("mission_completed"):
                EventBus.mission_completed.connect(_on_mission_completed)
        if EventBus.has_signal("phone_call_received"):
                EventBus.phone_call_received.connect(func(from_id):
                        dial(from_id))

func _process(delta: float) -> void:
        if _cooldown_t > 0.0:
                _cooldown_t -= delta
        match state:
                State.RINGING:
                        _ring_t += delta
                        if _ring_t >= RING_MAX:
                                _missed()
                State.ACTIVE:
                        _tick_call(delta)
                State.IDLE:
                        _try_next_in_queue()

# ---------------------------------------------------------------- scheduling
## schedule_call: story/world code requests a call. Idempotency key prevents
## repeats across saves (persisted in GameState flags).
func schedule_call(from_id: String, lines: Array, delay_s: float,
                key := "", on_answer: Dictionary = {}, reschedule_if_missed := true) -> void:
        if key != "" and GameState.story_flags.has("call_" + key):
                return
        if key != "":
                GameState.story_flags["call_" + key] = true
        _queue.append({
                "from": from_id, "lines": lines, "delay": delay_s, "key": key,
                "on_answer": on_answer, "reschedule": reschedule_if_missed, "age": 0.0,
        })

func _try_next_in_queue() -> void:
        if _cooldown_t > 0.0:
                return
        if _queue.is_empty():
                return
        var idx := -1
        for i in _queue.size():
                if float(_queue[i]["delay"]) <= 0.0:
                        idx = i
                        break
        if idx < 0:
                for i in _queue.size():
                        _queue[i]["delay"] = float(_queue[i]["delay"]) - get_process_delta_time()
                return
        var call_d: Dictionary = _queue[idx]
        _queue.remove_at(idx)
        if _can_ring():
                ring(call_d)
        else:
                # push back a bit - never interrupt combat/cinematics
                call_d["delay"] = 4.0
                _queue.append(call_d)

func _can_ring() -> bool:
        if GameState.in_combat or GameState.in_cinematic or GameState.in_vehicle:
                return false
        return true
# ---------------------------------------------------------------- call lifecycle
func ring(call_d: Dictionary) -> void:
        state = State.RINGING
        _ring_t = 0.0
        current_call = call_d
        _play_ringtone()
        call_ringing.emit(String(call_d["from"]), String(call_d.get("key", "")))
        EventBus.subtitle_show.emit(
                "incoming call - " + NPCDirector.cast_display(String(call_d["from"])),
                "PHONE", 2.5)

func answer() -> void:
        if state != State.RINGING:
                return
        state = State.ACTIVE
        _stop_ringtone()
        _ring_t = 0.0
        _line_i = 0
        _line_t = 0.0
        call_connected.emit(String(current_call["from"]))
        call_log.append({"from": current_call["from"], "outcome": "answered",
                "time": TimeWeather.hour()})
        _advance_line(0.0)

func decline() -> void:
        if state != State.RINGING:
                return
        _stop_ringtone()
        call_log.append({"from": current_call["from"], "outcome": "declined",
                "time": TimeWeather.hour()})
        var resched: bool = bool(current_call.get("reschedule", true))
        _cooldown_t = MIN_GAP_BETWEEN_CALLS
        state = State.IDLE
        var from_id := String(current_call["from"])
        var call_d := current_call
        current_call = {}
        call_ended.emit(from_id, "declined")
        EventBus.subtitle_show.emit("Call declined. " +
                NPCDirector.cast_display(from_id) + " will try again.", "PHONE", 2.5)
        if resched:
                call_d["delay"] = 90.0
                _queue.append(call_d)

func hang_up() -> void:
        if state != State.ACTIVE:
                return
        _cooldown_t = MIN_GAP_BETWEEN_CALLS
        state = State.IDLE
        var from_id := String(current_call["from"])
        current_call = {}
        call_ended.emit(from_id, "hung_up")

func _missed() -> void:
        _stop_ringtone()
        call_log.append({"from": current_call["from"], "outcome": "missed",
                "time": TimeWeather.hour()})
        _cooldown_t = MIN_GAP_BETWEEN_CALLS
        var from_id := String(current_call["from"])
        var call_d := current_call
        current_call = {}
        state = State.IDLE
        call_ended.emit(from_id, "missed")
        # missed calls leave a voicemail-style message
        send_message(from_id, "(missed call) " + NPCDirector.cast_display(from_id) +
                " called. They left no message.")
        if bool(call_d.get("reschedule", true)):
                call_d["delay"] = 120.0
                _queue.append(call_d)

func _tick_call(delta: float) -> void:
        _line_t += delta
        if _line_t >= 3.4:
                _advance_line(delta)

func _advance_line(_delta: float) -> void:
        var lines: Array = current_call.get("lines", [])
        if _line_i >= lines.size():
                _finish_call()
                return
        var line: String = String(lines[_line_i])
        var from_id := String(current_call["from"])
        EventBus.subtitle_show.emit(line, NPCDirector.cast_display(from_id), 3.2)
        _line_i += 1
        _line_t = 0.0
        EventBus.sfx_requested.emit("sfx_notification", Vector3.ZERO)

func _finish_call() -> void:
        var from_id := String(current_call["from"])
        var on_answer: Dictionary = current_call.get("on_answer", {})
        var call_d := current_call
        state = State.IDLE
        current_call = {}
        _cooldown_t = MIN_GAP_BETWEEN_CALLS
        call_ended.emit(from_id, "completed")
        for k in on_answer.keys():
                match k:
                        "message":
                                send_message(from_id, String(on_answer[k]))
                        "flag":
                                GameState.story_flags[String(on_answer[k])] = true
                        "relationship":
                                GameState.adjust_relationship(from_id, float(on_answer[k]))
                        "mission":
                                MissionSystem.start_mission(String(on_answer[k]))
                        "waypoint":
                                EventBus.map_waypoint_set.emit(String(on_answer[k]))

## Outgoing call: contact CALL button. Voicemail unless story-defined.
func dial(from_id: String) -> void:
        if state != State.IDLE:
                return
        var lines := _outgoing_script(from_id)
        if lines.is_empty():
                send_message(from_id, "(voicemail) " + NPCDirector.cast_display(from_id) +
                                " can't talk right now.")
                return
        ring({"from": from_id, "lines": lines, "reschedule": false,
                "on_answer": {}, "key": ""})

func _outgoing_script(from_id: String) -> Array:
        match from_id:
                "rizzo":
                        return ["Dez. Good - you're alive.",
                                "When you got a minute, the market could use your hands again."]
                "big_theo":
                        return ["Gym's open, kid. Bag won't hit itself.",
                                "Come spar when you're ready."]
                "marisol":
                        return ["Bar's quiet tonight, Dez. Come by if you need to think."]
                "juno":
                        return ["Hey stranger. Still keeping out of trouble?"]
                "nadia":
                        return ["If you find anything... valuable, bring it by the shop."]
                "officer_brant":
                        return ["This better be about a crime I can't already pin on you."]
                "the_tipster":
                        return ["Information isn't free, Carter. Do something for the city first."]
        return []

# ---------------------------------------------------------------- messages
## Threads live in GameState.phone_threads: {from_id: [{mine, text, hour}]}
func send_message(from_id: String, text: String, mine := false) -> void:
        var threads: Dictionary = GameState.phone_threads
        if not threads.has(from_id):
                threads[from_id] = []
        var hour_txt := "%02d:00" % int(TimeWeather.hour())
        (threads[from_id] as Array).append({
                "mine": mine, "text": text, "hour": hour_txt,
                "read": mine,
        })
        if not mine:
                EventBus.sfx_requested.emit("sfx_notification", Vector3.ZERO)
                EventBus.notification_posted.emit(
                        NPCDirector.cast_display(from_id) + ": " + text.left(46), "message")
                message_received.emit(from_id, text)
        EventBus.phone_received_message.emit(NPCDirector.cast_display(from_id), text)

func reply(from_id: String, text: String) -> void:
        send_message(from_id, text, true)

func unread_count() -> int:
        var n := 0
        for tid in GameState.phone_threads.keys():
                for m in GameState.phone_threads[tid]:
                        if not bool(m.get("read", false)) and not bool(m.get("mine", false)):
                                n += 1
        return n

func mark_thread_read(from_id: String) -> void:
        if not GameState.phone_threads.has(from_id):
                return
        for m in GameState.phone_threads[from_id]:
                m["read"] = true

func _on_mission_completed(mission_id: String) -> void:
        # the next mission's giver calls the player with the hook line
        var def: Dictionary = MissionSystem.mission_def(mission_id)
        var next_id := String(def.get("next", ""))
        if next_id == "":
                return
        var next_def: Dictionary = MissionSystem.mission_def(next_id)
        var giver := String(next_def.get("giver", "the_tipster"))
        var lines := [
                _next_hook(next_id),
                String(next_def.get("briefing", "")),
        ]
        schedule_call(giver, lines, 6.0, "intro_" + next_id)
        send_message(giver, String(next_def.get("briefing", "")).left(120))

func _next_hook(next_id: String) -> String:
        var map := {
                "make_change": "Clean work. There's a sedan at the impound with your name on it.",
                "rendezvous": "One more job before the Family stops asking nicely.",
                "gym_introduction": "Word travels. Theo wants to see your hands.",
                "bar_night": "Marisol says you should hear this in person.",
                "kestrel_summons": "A suit called the bar asking for you by name.",
                "tower_heist": "Ava Kestrel wants a thief who owes money. That's you.",
                "turf_war": "The Vetch crew crossed a line. Time to answer it.",
                "scrapyard_lucy": "Lucy found something in the scrapyard. Something that matters.",
                "the_letter": "Tommy's letters didn't stop. Someone kept sending them.",
                "the_meet": "Both sides want the same meeting. You're the reason.",
                "rescue_tommy": "We know where they're keeping him. It's tonight or never.",
                "finale_villa": "Everyone who ever held your leash is at that villa. Finish it.",
        }
        return String(map.get(next_id, "The city needs something from you."))

# ---------------------------------------------------------------- ringtone
func _play_ringtone() -> void:
        var path := "res://assets/audio/sfx/sfx_phone_ring.ogg"
        if not ResourceLoader.exists(path):
                return
        var stream: AudioStream = load(path)
        if stream is AudioStreamOggVorbis:
                var dup := stream.duplicate() as AudioStreamOggVorbis
                dup.loop = true
                stream = dup
        _ring_player.stream = stream
        _ring_player.play()

func _stop_ringtone() -> void:
        _ring_player.stop()

func is_ringing() -> bool:
        return state == State.RINGING

func is_active() -> bool:
        return state == State.ACTIVE
