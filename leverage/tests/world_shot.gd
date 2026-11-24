extends Node
## WorldShotProbe - renders the game world (exact NEW GAME path) for
## verification. Run with a display + Vulkan ICD; shots land in
## LEVERAGE_PROBE_OUT. Evidence that the world (HUD incl. phone UI) builds
## after the v2.3.2 parse fixes.

func _ready() -> void:
        # let the tree finish adding this probe before mounting the world
        # (add_child while root is busy silently fails - same guard as button flow)
        await get_tree().process_frame
        await get_tree().process_frame
        print("[WORLDSHOT] start_new_game via GameManager")
        GameManager.start_new_game()
        var out_dir := OS.get_environment("LEVERAGE_PROBE_OUT")
        if out_dir == "":
                out_dir = "res://tests/render_out"
        var prev := 0.0
        var n := 0
        for t in [10.0, 8.0, 12.0, 20.0]:
                await get_tree().create_timer(t).timeout
                prev += t
                n += 1
                var img: Image = get_viewport().get_texture().get_image()
                var fname := "world_%02ds.png" % int(prev)
                img.save_png(out_dir + "/" + fname)
                print("SHOT %s | state=%s | nodes=%d" % [fname, GameManager.state, get_tree().get_node_count()])
        print("[WORLDSHOT] done")
        get_tree().quit(0)
