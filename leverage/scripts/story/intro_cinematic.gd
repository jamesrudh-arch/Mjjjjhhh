class_name IntroCinematic
extends CanvasLayer
## IntroCinematic - the opening cinematic (letterboxed, subtitle-driven)
## with skip; then a short tutorialized entry sequence (movement, first
## fight prompts, first drive, phone). Also hosts mid-story beats.

const BEATS := [
        {"t": 0.0, "speaker": "", "text": ""},
        {"t": 1.0, "speaker": "NARRATOR", "text": "Cinder City. Population: everyone who owes somebody."},
        {"t": 5.0, "speaker": "NARRATOR", "text": "Dez Carter came home to a ransacked room and a note on the fridge."},
        {"t": 9.5, "speaker": "TOMMY (LETTER)", "text": "Dez - don't look for me. It's the Ledger. It was always going to be the Ledger."},
        {"t": 14.5, "speaker": "PHONE VOICE", "text": "Your brother works for us now. That makes you our repo-man. Welcome to leverage, Carter."},
        {"t": 20.0, "speaker": "NARRATOR", "text": "Everyone has leverage on you. Tonight, you learn who holds it."},
]

const TUTORIAL_STEPS := [
        {"id": "move", "text": "Use the left stick (or WASD) to move. Drag the right side of the screen to look around."},
        {"id": "camera", "text": "Camera follows you. Find the amber marker - Rizzo is waiting at the market."},
        {"id": "combat", "text": "When trouble starts: X = Punch, Y = Heavy Attack, A = Kick, B = Dodge. Fixed. Learn it."},
        {"id": "drive", "text": "Press B near a car to take it. Joystick steers, GAS/BRK pedals drive."},
        {"id": "phone", "text": "Tap the PHONE chip (or T) - your contacts, messages, missions, radio live there."},
]

var _root: Control
var _bars: Array = []
var _text: Label
var _speaker: Label
var _t := 0.0
var _beat_idx := 0
var _phase := "cine"                # cine -> tutorial -> done
var _step_idx := 0
var _step_t := 0.0
var _skip_hint: Label
var _finished := false


func _ready() -> void:
        layer = 30
        _build()


func _build() -> void:
        _root = Control.new()
        _root.set_anchors_preset(Control.PRESET_FULL_RECT)
        _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(_root)
        _root.add_child(LvgTheme.color_rect(Color(0, 0, 0, 0.35)))
        # letterbox bars
        for top in [true, false]:
                var bar := ColorRect.new()
                bar.color = Color(0, 0, 0, 1)
                bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
                bar.set_anchors_preset(Control.PRESET_FULL_RECT)
                bar.custom_minimum_size = Vector2(0, 148)
                if top:
                        bar.anchor_top = 0.0
                        bar.anchor_bottom = 0.12
                else:
                        bar.anchor_top = 0.88
                        bar.anchor_bottom = 1.0
                _bars.append(bar)
                _root.add_child(bar)
        _speaker = LvgTheme.make_kicker("", LvgTheme.ACCENT, 26)
        _speaker.position = Vector2(640, 860)
        _root.add_child(_speaker)
        _text = LvgTheme.make_label("", 30, LvgTheme.TEXT)
        _text.position = Vector2(640, 895)
        _text.custom_minimum_size = Vector2(1400, 90)
        _root.add_child(_text)
        _skip_hint = LvgTheme.make_label("PRESS X TO SKIP", 22, LvgTheme.TEXT_DIM)
        _skip_hint.position = Vector2(2330, 1140)
        _root.add_child(_skip_hint)


func _process(delta: float) -> void:
        if _finished:
                return
        if Input.is_action_just_pressed("action_x"):
                _finish()
                return
        if _phase == "cine":
                _t += delta
                if _beat_idx < BEATS.size():
                        var beat: Dictionary = BEATS[_beat_idx]
                        if _t >= float(beat["t"]):
                                _show_beat(beat)
                                _beat_idx += 1
                elif _t > 24.0:
                        _start_tutorial()
        elif _phase == "tutorial":
                _step_t += delta
                if _step_idx < TUTORIAL_STEPS.size():
                        var step: Dictionary = TUTORIAL_STEPS[_step_idx]
                        if _step_t > 6.0:
                                _step_idx += 1
                                _step_t = 0.0
                                if _step_idx < TUTORIAL_STEPS.size():
                                        _show_step(_step_idx)
                else:
                        _finish()
        # fade bars during tutorial
        if _phase == "tutorial":
                for b in _bars:
                        (b as ColorRect).modulate.a = lerp((b as ColorRect).modulate.a, 0.0, clamp(delta * 2, 0, 1))


func _show_beat(beat: Dictionary) -> void:
        _speaker.text = LvgTheme.tracked(String(beat["speaker"]))
        _text.text = String(beat["text"])


func _start_tutorial() -> void:
        _phase = "tutorial"
        _step_t = 0.0
        _step_idx = 0
        _show_step(0)


func _show_step(idx: int) -> void:
        var step: Dictionary = TUTORIAL_STEPS[idx]
        _speaker.text = "TUTORIAL " + str(idx + 1) + "/" + str(TUTORIAL_STEPS.size())
        _text.text = String(step["text"])
        EventBus.sfx_requested.emit("sfx_ui_click", Vector3.ZERO)
        match String(step["id"]):
                "phone":
                        EventBus.notification_posted.emit("Your phone: contacts, messages, radio.", "tutorial")


func _finish() -> void:
        if _finished:
                return
        _finished = true
        _speaker.text = ""
        _text.text = ""
        queue_free()
        EventBus.notification_posted.emit("Chapter 1: Debt First - meet Rizzo at the market", "mission")
        EventBus.music_layer_requested.emit("explore_day")


## Mid-story cinematic beats reuse this overlay.
func play_beat(beat_id: String) -> void:
        _phase = "beat"
        _t = 0.0
        match beat_id:
                "tommy_rescue":
                        _speaker.text = "TOMMY"
                        _text.text = "You actually came. I knew the streets hadn't eaten all of you."
                "ending":
                        _speaker.text = ""
                        _text.text = "The city holds its breath. Everyone has leverage on you."
        await get_tree().create_timer(4.0).timeout
        if not _finished:
                _finish()
