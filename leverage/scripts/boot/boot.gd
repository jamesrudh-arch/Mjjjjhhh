extends Node
## Boot sequence: DE YOUNG GAMES animated ident -> LEVERAGE title ->
## content notice -> main menu. All cards are code-built; timing is
## frame-driven so it also runs in headless tests (auto-skip when test mode).

const CARD_COMPANY := 3.2
const CARD_TITLE := 3.0
const CARD_NOTICE := 2.2

var _t := 0.0
var _stage := 0
var _cards: Array = []
var _faders: Array = []
## initialized at instantiation so an embedding test can override it before
## the node enters the tree; the real game reads the environment here.
var _test_mode := OS.get_environment("LEVERAGE_TEST") == "1"


func _ready() -> void:
        get_window().title = "LEVERAGE"
        print_diag()
        _build()
        GameManager.go_to_state(GameManager.State.SPLASH)
        EventBus.game_booted.emit()


## One-line device diagnostics: lands in Xogot's debugger Output pane, so a
## real-device launch failure tells us exactly how far boot got.
func print_diag() -> void:
        var vi := Engine.get_version_info()
        print("[LEVERAGE v%s] boot start | Godot %s | renderer=%s | OS=%s | mem=%d MB" % [
                ProjectSettings.get_setting("application/config/version", "?"),
                vi.get("string", "?"),
                ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"),
                OS.get_name(),
                OS.get_static_memory_usage() / 1048576])


func _build() -> void:
        var root := Control.new()
        root.set_anchors_preset(Control.PRESET_FULL_RECT)
        root.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(root)

        root.add_child(LvgTheme.color_rect(LvgTheme.BLACK))

        # --- Card 1: DE YOUNG GAMES animated ident ---
        var company := Control.new()
        company.set_anchors_preset(Control.PRESET_FULL_RECT)
        company.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(company)
        var logo := DeYoungLogo.new()
        company.add_child(logo)

        # --- Card 2: LEVERAGE title ---
        var title := Control.new()
        title.set_anchors_preset(Control.PRESET_FULL_RECT)
        title.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(title)
        var v2 := VBoxContainer.new()
        v2.set_anchors_preset(Control.PRESET_CENTER)
        v2.alignment = BoxContainer.ALIGNMENT_CENTER
        v2.add_theme_constant_override("separation", 26)
        title.add_child(v2)
        var prod := LvgTheme.make_label("A  DE YOUNG GAMES  PRODUCTION", 30, LvgTheme.TEXT_DIM)
        v2.add_child(prod)
        var big := LvgTheme.make_display_label("LEVERAGE", 170, LvgTheme.ACCENT)
        v2.add_child(big)
        var rule := _amber_rule(420)
        v2.add_child(rule)
        var tag := LvgTheme.make_label("EVERYONE HAS LEVERAGE ON YOU.", 34, LvgTheme.TEXT)
        v2.add_child(tag)

        # --- Card 3: content notice ---
        var notice := Control.new()
        notice.set_anchors_preset(Control.PRESET_FULL_RECT)
        notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(notice)
        var v3 := VBoxContainer.new()
        v3.set_anchors_preset(Control.PRESET_CENTER)
        v3.alignment = BoxContainer.ALIGNMENT_CENTER
        v3.add_theme_constant_override("separation", 14)
        notice.add_child(v3)
        var n1 := LvgTheme.make_label("This is a work of fiction.", 30, LvgTheme.TEXT_DIM)
        var n2 := LvgTheme.make_label("Characters and events depicted are not real.", 30, LvgTheme.TEXT_DIM)
        var n3 := LvgTheme.make_label("Contains violence, crime themes and strong language.", 30, LvgTheme.TEXT_DIM)
        var n4 := LvgTheme.make_label("Player discretion advised.", 30, LvgTheme.TEXT)
        for n in [n1, n2, n3, n4]:
                v3.add_child(n)

        _cards = [company, title, notice]
        for c in _cards:
                c.modulate.a = 0.0


func _amber_rule(width: float) -> Control:
        var c := Control.new()
        c.custom_minimum_size = Vector2(width, 4)
        c.draw.connect(func():
                c.draw_rect(Rect2(0, 0, width, 4), LvgTheme.ACCENT_DEEP)
                c.draw_rect(Rect2(width * 0.42, 0, width * 0.16, 4), LvgTheme.ACCENT)
        )
        return c


var _sting_played := false


func _process(delta: float) -> void:
        _t += delta
        if _test_mode:
                _go_menu()
                set_process(false)
                return
        if not _sting_played:
                _sting_played = true
                EventBus.sfx_requested.emit("sfx_logo_sting", Vector3.ZERO)
        match _stage:
                0:
                        _cards[0].modulate.a = min(_t / 0.8, 1.0)
                        if _t >= CARD_COMPANY:
                                _stage = 1
                                _t = 0.0
                1:
                        _cards[0].modulate.a = 1.0 - min(_t / 0.6, 1.0)
                        _cards[1].modulate.a = min(_t / 0.8, 1.0)
                        if _t >= CARD_TITLE:
                                _stage = 2
                                _t = 0.0
                2:
                        _cards[1].modulate.a = 1.0 - min(_t / 0.6, 1.0)
                        _cards[2].modulate.a = min(_t / 0.8, 1.0)
                        if _t >= CARD_NOTICE:
                                _stage = 3
                                _t = 0.0
                3:
                        _cards[2].modulate.a = 1.0 - min(_t / 0.6, 1.0)
                        if _t >= 0.7:
                                _go_menu()
                                set_process(false)


func _go_menu() -> void:
        # only hand over the tree when boot is the root scene; embedded copies
        # (tests, previews) simply finish their timeline instead.
        if get_tree().current_scene == self:
                print("[LEVERAGE] boot cards done -> main menu")
                get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
