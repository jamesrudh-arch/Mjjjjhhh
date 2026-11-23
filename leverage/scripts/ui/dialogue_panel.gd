class_name DialoguePanel
extends Control
## DialoguePanel - presents dialogue choices as tappable rows (also keyboard
## 1-4). Wires pick_choice into DialogueSystem.

var _node_id := ""
var _choices: Array = []
var _buttons: Array = []


func show_choices(node_id: String, choices: Array) -> void:
        _node_id = node_id
        _choices = choices


func _ready() -> void:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        _build()


func _build() -> void:
        var box := VBoxContainer.new()
        box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
        box.position = Vector2(0, -220)
        box.add_theme_constant_override("separation", 10)
        box.custom_minimum_size = Vector2(1200, 0)
        add_child(box)
        for i in _choices.size():
                var c: Dictionary = _choices[i]
                var b := LvgTheme.make_button("%d.  %s" % [i + 1, String(c.get("label", "..."))])
                var idx := i
                b.pressed.connect(func():
                        DialogueSystem.pick_choice(_node_id, idx)
                        queue_free())
                box.add_child(b)
                _buttons.append(b)


func _unhandled_input(event: InputEvent) -> void:
        if event.is_action_pressed("action_a") and _choices.size() > 0:
                DialogueSystem.pick_choice(_node_id, 0)
                queue_free()
        elif event.is_action_pressed("action_b") and _choices.size() > 1:
                DialogueSystem.pick_choice(_node_id, 1)
                queue_free()
        elif event.is_action_pressed("action_x") and _choices.size() > 2:
                DialogueSystem.pick_choice(_node_id, 2)
                queue_free()
        elif event.is_action_pressed("action_y") and _choices.size() > 3:
                DialogueSystem.pick_choice(_node_id, 3)
                queue_free()
        get_viewport().set_input_as_handled()
