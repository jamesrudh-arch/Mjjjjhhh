class_name CinematicOverlay
extends CanvasLayer
## CinematicOverlay - reusable cinematic presentation layer (P3 pass):
## - letterbox bars (slide in/out) for dialogue + story beats
## - mission/chapter title cards (Mafia/GTA-style)
## - full-screen fade for state transitions
## Built code-only (TDL #4: no .tscn, headless-testable). Layer 40 sits above HUD.

const BAR_HEIGHT := 0.11          # fraction of viewport height per bar
const CARD_HOLD := 2.6            # title card hold time
const FADE_TIME := 0.45


var _root: Control
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _card: Control
var _card_kicker: Label
var _card_title: Label
var _card_sub: Label
var _fade: ColorRect
var _t := 0.0


func _ready() -> void:
        layer = 40
        _build()
        EventBus.mission_started.connect(_on_mission_started)
        EventBus.dialogue_started.connect(func(_npc): set_letterbox(true))
        EventBus.dialogue_ended.connect(func(): set_letterbox(false))
        EventBus.cinematic_requested.connect(func(_beat): set_letterbox(true))


func _build() -> void:
        _root = Control.new()
        _root.set_anchors_preset(Control.PRESET_FULL_RECT)
        _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(_root)
        # letterbox bars
        for is_top in [true, false]:
                var bar := ColorRect.new()
                bar.color = Color(0, 0, 0, 1)
                bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
                bar.set_anchors_preset(Control.PRESET_FULL_RECT)
                if is_top:
                        bar.anchor_top = 0.0
                        bar.anchor_bottom = BAR_HEIGHT
                        _bar_top = bar
                else:
                        bar.anchor_top = 1.0 - BAR_HEIGHT
                        bar.anchor_bottom = 1.0
                        _bar_bottom = bar
                bar.modulate.a = 0.0
                _root.add_child(bar)
        # title card
        _card = Control.new()
        _card.set_anchors_preset(Control.PRESET_CENTER)
        _card.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _card.add_theme_constant_override("separation", 4)
        _root.add_child(_card)
        _card_kicker = LvgTheme.make_kicker("", LvgTheme.ACCENT, 22)
        _card_title = LvgTheme.make_label("", 54, LvgTheme.TEXT)
        _card_sub = LvgTheme.make_label("", 24, LvgTheme.TEXT_DIM)
        for l: Label in [_card_kicker, _card_title, _card_sub]:
                l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                l.position = Vector2.ZERO
                _card.add_child(l)
        _card.modulate.a = 0.0
        # state fade
        _fade = ColorRect.new()
        _fade.color = Color(0, 0, 0, 0)
        _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _fade.set_anchors_preset(Control.PRESET_FULL_RECT)
        _root.add_child(_fade)


func _process(delta: float) -> void:
        _t += delta


## ---------------- Letterbox ----------------
func set_letterbox(on: bool) -> void:
        var target := 1.0 if on else 0.0
        var tw := create_tween().set_parallel(true)
        tw.tween_property(_bar_top, "modulate:a", target, 0.4).set_ease(Tween.EASE_OUT)
        tw.tween_property(_bar_bottom, "modulate:a", target, 0.4).set_ease(Tween.EASE_OUT)


func is_letterboxed() -> bool:
        return _bar_top.modulate.a > 0.5


## ---------------- Title cards ----------------
func show_title_card(kicker: String, title: String, subtitle := "") -> void:
        _card_kicker.text = LvgTheme.tracked(kicker.to_upper())
        _card_title.text = title
        _card_sub.text = subtitle
        _card.position = Vector2(0, get_viewport().get_visible_rect().size.y * 0.42)
        _card.size = Vector2(get_viewport().get_visible_rect().size.x, 200)
        _card.modulate.a = 0.0
        EventBus.sfx_requested.emit("sfx_unlock", Vector3.ZERO)
        var tw := create_tween()
        tw.tween_property(_card, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
        tw.tween_interval(CARD_HOLD)
        tw.tween_property(_card, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
        # brief letterbox flavor under the card
        set_letterbox(true)
        tree_timer(CARD_HOLD + 0.5).timeout.connect(func(): if DialogueSystem.current_npc == "": set_letterbox(false))


## ---------------- Fade ----------------
func fade_out(time := FADE_TIME) -> void:
        var tw := create_tween()
        tw.tween_property(_fade, "color:a", 1.0, time)


func fade_in(time := FADE_TIME) -> void:
        var tw := create_tween()
        tw.tween_property(_fade, "color:a", 0.0, time)


## ---------------- Wiring ----------------
func _on_mission_started(mission_id: String) -> void:
        var m: Dictionary = MissionSystem.mission_def(mission_id)
        if m.is_empty():
                return
        show_title_card("CHAPTER %d" % int(m.get("chapter", 1)),
                        String(m.get("title", mission_id)),
                        String(m.get("briefing", "")).substr(0, 90))


func tree_timer(t: float) -> SceneTreeTimer:
        return get_tree().create_timer(t)
