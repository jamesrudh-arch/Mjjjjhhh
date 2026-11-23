extends Node
## MenuShotProbe - renders the main menu (new key art) once for verification.
func _ready() -> void:
        await get_tree().process_frame
        var menu: Node = (load("res://scenes/menus/main_menu.tscn") as PackedScene).instantiate()
        get_tree().root.add_child(menu)
        get_tree().current_scene = menu
        await get_tree().create_timer(1.4).timeout
        var img: Image = get_viewport().get_texture().get_image()
        var out_dir := OS.get_environment("LEVERAGE_PROBE_OUT")
        if out_dir == "":
                out_dir = "res://tests/render_out"
        img.save_png(out_dir + "/menu_new_keyart.png")
        print("SHOT menu_new_keyart")
        await get_tree().create_timer(0.2).timeout
        get_tree().quit(0)
