class_name IntroCinematic
extends CanvasLayer
## IntroCinematic - the opening of LEVERAGE: camera flights over the live
## city (river, bridge, market) under letterbox, then a real conversation
## between Dez and Rizzo (portraits, typewriter lines, the threatening phone
## call), the chapter card, and a short tutorialized entry sequence.
## Also hosts mid-story beats.

const BEATS := [
        # -- flight over the river --
        {"t": 0.4, "speaker": "NARRATOR", "portrait": "", "shot": 0,
                "text": "Cinder City. Population: everyone who owes somebody."},
        {"t": 4.6, "speaker": "NARRATOR", "portrait": "", "shot": 0,
                "text": "The Cinder River splits this town in two. Money on the east bank. Debt on the west."},
        # -- the ransacked room, the letter --
        {"t": 9.0, "speaker": "NARRATOR", "portrait": "", "shot": 1,
                "text": "Dez Carter came home to a ransacked room and a note on the fridge."},
        {"t": 13.4, "speaker": "TOMMY - IN A LETTER", "portrait": "", "shot": 1,
                "text": "Dez - don't look for me. It's the Ledger. It was always going to be the Ledger."},
        # -- the market conversation --
        {"t": 18.2, "speaker": "RIZZO", "portrait": "rizzo", "shot": 2,
                "text": "Dez Carter. Thought that was you limping through my market."},
        {"t": 22.4, "speaker": "DEZ", "portrait": "dez", "shot": 2,
                "text": "Rizzo. Someone tore my place apart looking for Tommy. You know anything?"},
        {"t": 27.0, "speaker": "RIZZO", "portrait": "rizzo", "shot": 2,
                "text": "The Vetch collectors came asking before you did. Your brother's debt didn't die with his job."},
        {"t": 32.0, "speaker": "DEZ", "portrait": "dez", "shot": 2,
                "text": "The Ledger. He named it in the note. What is it?"},
        {"t": 36.2, "speaker": "RIZZO", "portrait": "rizzo", "shot": 2,
                "text": "The Family's book of everyone who owes. Names. Debts. Secrets. Tommy ran numbers for Vito - until something went missing."},
        # -- the phone call --
        {"t": 42.0, "speaker": "UNKNOWN CALLER", "portrait": "", "shot": 1, "ring": true,
                "text": "Your brother works for us now, Carter. His debt is your debt. That makes you our repo-man."},
        {"t": 47.6, "speaker": "UNKNOWN CALLER", "portrait": "", "shot": 1,
                "text": "Welcome to leverage."},
        {"t": 50.6, "speaker": "DEZ", "portrait": "dez", "shot": 2,
                "text": "If they want a repo-man, I'll collect. Every name in that book."},
        {"t": 54.6, "speaker": "RIZZO", "portrait": "rizzo", "shot": 2,
                "text": "Careful, kid. Out here everyone has leverage on you too. Start small - the collectors are squeezing my stalls."},
        # -- close --
        {"t": 60.0, "speaker": "NARRATOR", "portrait": "", "shot": 3,
                "text": "Everyone has leverage on you. Tonight, you learn who holds it."},
]

const CAMERA_SHOTS := [
        {"pos": Vector3(-46, 26, -330), "look": Vector3(-46, 0, 250), "dur": 4.2},    # down the river
        {"pos": Vector3(-120, 10, -200), "look": Vector3(-46, 2, -10), "dur": 3.4},   # avenue toward the bridge
        {"pos": Vector3(-252, 5.5, -140), "look": Vector3(-240, 1.4, -120), "dur": 3.0}, # the market
        {"pos": Vector3(-252, 22, -168), "look": Vector3(-240, 0, -120), "dur": 3.6}, # rise above the market
]

const TUTORIAL_STEPS := [
        {"id": "move", "text": "Use the left stick (or WASD) to move. Drag the right side of the screen to look around."},
        {"id": "camera", "text": "Camera follows you. Find the amber marker - Rizzo is waiting at the market."},
        {"id": "combat", "text": "When trouble starts: X = Punch, Y = Heavy Attack, A = Kick, B = Dodge. Fixed. Learn it."},
        {"id": "drive", "text": "Press B near a car to take it. Joystick steers, GAS/BRK pedals drive."},
        {"id": "phone", "text": "Tap the PHONE chip (or T) - your contacts, messages, missions, radio live there."},
]

const TYPE_SPEED := 34.0          # characters per second
const BEAT_GAP := 0.9             # pause after text completes before next beat
const SKIP_HOLD := 0.7            # hold X this long to skip the whole intro

var _root: Control
var _bars: Array = []
var _text: Label
var _speaker: Label
var _portrait: TextureRect
var _portrait_frame: PanelContainer
var _t := 0.0
var _beat_idx := 0
var _phase := "cine"                # cine -> tutorial -> done
var _step_idx := 0
var _step_t := 0.0
var _skip_hint: Label
var _finished := false
var _typed := 0.0                   # chars typed so far
var _line_done := false
var _beat_done_t := 0.0
var _x_hold := 0.0                  # hold-to-skip accumulator
var _x_was_down := false
var _cine_cam: Camera3D = null
var _world_ref: Node3D = null
var _cam_look := Vector3.ZERO
var _cam_look_active := false
var _ring_played := false


func _ready() -> void:
        layer = 30
        _world_ref = get_parent() as Node3D
        _build()
        _setup_camera()
        EventBus.music_layer_requested.emit("story")


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
        # portrait (slides in for conversation beats)
        _portrait_frame = PanelContainer.new()
        _portrait_frame.position = Vector2(420, 690)
        _portrait_frame.modulate.a = 0.0
        var st := StyleBoxFlat.new()
        st.bg_color = Color(0.04, 0.05, 0.07, 0.9)
        st.border_color = LvgTheme.ACCENT
        st.border_width_bottom = 3
        st.border_width_top = 3
        st.border_width_left = 3
        st.border_width_right = 3
        st.corner_radius_top_left = 6
        st.corner_radius_bottom_left = 6
        _portrait_frame.add_theme_stylebox_override("panel", st)
        _root.add_child(_portrait_frame)
        _portrait = TextureRect.new()
        _portrait.custom_minimum_size = Vector2(190, 190)
        _portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        _portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        _portrait_frame.add_child(_portrait)
        # speaker + text
        _speaker = LvgTheme.make_kicker("", LvgTheme.ACCENT, 26)
        _speaker.position = Vector2(660, 860)
        _root.add_child(_speaker)
        _text = LvgTheme.make_label("", 30, LvgTheme.TEXT)
        _text.position = Vector2(660, 895)
        _text.custom_minimum_size = Vector2(1380, 90)
        _root.add_child(_text)
        _skip_hint = LvgTheme.make_label("TAP X = NEXT   |   HOLD X = SKIP", 22, LvgTheme.TEXT_DIM)
        _skip_hint.position = Vector2(2330, 1140)
        _root.add_child(_skip_hint)


func _setup_camera() -> void:
        # camera flights only when embedded in the real world scene
        if _world_ref == null or not (_world_ref is World):
                return
        _cine_cam = Camera3D.new()
        _cine_cam.name = "IntroCamera"
        _cine_cam.fov = 62.0
        _cine_cam.current = true
        _world_ref.add_child(_cine_cam)
        _fly_to(0, 0.1)


func _fly_to(shot_idx: int, dur: float) -> void:
        if _cine_cam == null or shot_idx >= CAMERA_SHOTS.size():
                return
        var shot: Dictionary = CAMERA_SHOTS[shot_idx]
        _cam_look = shot["look"]
        _cam_look_active = true
        var tw := create_tween()
        tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        tw.tween_property(_cine_cam, "position", shot["pos"], maxf(dur, 0.1))


func _process(delta: float) -> void:
        if _finished:
                return
        # camera flights: glide position, keep facing the shot's look point
        if _cam_look_active and _cine_cam != null and is_instance_valid(_cine_cam):
                _cine_cam.look_at(_cam_look, Vector3.UP)
        # hold X to skip the whole intro; tap X to advance
        var x_down: bool = Input.is_action_pressed("action_x")
        if x_down:
                _x_hold += delta
        else:
                _x_hold = 0.0
        if _x_hold >= SKIP_HOLD:
                _finish()
                return
        if x_down and not _x_was_down:
                # tap
                if _phase == "cine" and _line_done and _beat_idx < BEATS.size():
                        _advance_beat()
                elif _phase == "cine" and not _line_done:
                        _typed = 9999.0     # complete the line instantly
                elif _phase == "tutorial":
                        _finish()
                _x_was_down = x_down
                return
        _x_was_down = x_down
        if _phase == "cine":
                _t += delta
                if _beat_idx < BEATS.size():
                        var beat: Dictionary = BEATS[_beat_idx]
                        if _t >= float(beat["t"]):
                                _show_beat(beat)
                                _beat_idx += 1
                # typewriter
                if not _line_done and _speaker.text != "":
                        _typed += TYPE_SPEED * delta
                        var full := String(BEATS[clampi(_beat_idx - 1, 0, BEATS.size() - 1)]["text"])
                        if _typed >= full.length():
                                _typed = full.length()
                                _line_done = true
                                _beat_done_t = _t
                        _text.text = full.substr(0, int(_typed))
                elif _line_done:
                        # auto-advance a beat-gap after the line completes
                        if _t - _beat_done_t > BEAT_GAP and _beat_idx < BEATS.size():
                                _advance_beat()
                        elif _t > float(BEATS[BEATS.size() - 1]["t"]) + 5.0:
                                _start_tutorial()
                elif _beat_idx >= BEATS.size() and _t > float(BEATS[BEATS.size() - 1]["t"]) + 5.0:
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


func _advance_beat() -> void:
        # jump time to the next beat's slot
        if _beat_idx < BEATS.size():
                _t = float(BEATS[_beat_idx]["t"]) - 0.01
                _line_done = false
                _typed = 0.0


func _show_beat(beat: Dictionary) -> void:
        _speaker.text = LvgTheme.tracked(String(beat["speaker"]))
        _line_done = false
        _typed = 0.0
        _text.text = ""
        var portrait_id := String(beat.get("portrait", ""))
        if portrait_id != "":
                var path := "res://assets/ui/portraits/%s.png" % portrait_id
                if ResourceLoader.exists(path):
                        _portrait.texture = load(path)
                _portrait_frame.modulate.a = 0.0
                var tw := create_tween()
                tw.tween_property(_portrait_frame, "modulate:a", 1.0, 0.3)
        else:
                var tw := create_tween()
                tw.tween_property(_portrait_frame, "modulate:a", 0.0, 0.25)
        if bool(beat.get("ring", false)) and not _ring_played:
                _ring_played = true
                EventBus.sfx_requested.emit("sfx_phone_ring", Vector3(-240, 1, -120))
        if _cine_cam != null:
                _fly_to(int(beat.get("shot", 0)), float(CAMERA_SHOTS[int(beat.get("shot", 0))].get("dur", 3.0)))


func _start_tutorial() -> void:
        if _phase != "cine":
                return
        _phase = "tutorial"
        _step_t = 0.0
        _step_idx = 0
        _release_camera()
        _show_step(0)


func _show_step(idx: int) -> void:
        var step: Dictionary = TUTORIAL_STEPS[idx]
        _speaker.text = "TUTORIAL " + str(idx + 1) + "/" + str(TUTORIAL_STEPS.size())
        _text.text = String(step["text"])
        EventBus.sfx_requested.emit("sfx_ui_click", Vector3.ZERO)
        match String(step["id"]):
                "phone":
                        EventBus.notification_posted.emit("Your phone: contacts, messages, radio.", "tutorial")


func _release_camera() -> void:
        if _cine_cam != null and is_instance_valid(_cine_cam):
                _cine_cam.queue_free()
                _cine_cam = null
        if _world_ref is World and _world_ref.camera_rig != null:
                _world_ref.camera_rig.camera.current = true


func _finish() -> void:
        if _finished:
                return
        _finished = true
        _release_camera()
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
