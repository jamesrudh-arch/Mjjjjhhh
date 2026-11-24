extends Node
func _ready() -> void:
        await get_tree().process_frame
        var world: Variant = (load("res://scenes/world/world.tscn") as PackedScene).instantiate()
        get_tree().root.add_child(world)
        await get_tree().create_timer(3.0).timeout
        var n := 0
        for b in world.city._buildings:
                var ti: int = b["type"]
                # shop types: 10 b_shop1, 11 b_shop2, 12 b_shop3, 2 b_brick4, 18 b_hotel
                if ti in [2, 10, 11, 12, 18]:
                        var bp: Vector2 = b["pos"]
                        if bp.x > 80 and bp.x < 450 and bp.y > 40 and bp.y < 420:
                                print("[SHOP] type=%d pos=(%.0f, %.0f) rot=%.2f" % [ti, bp.x, bp.y, b["rot"]])
                                n += 1
                                if n >= 8: break
        get_tree().quit()
